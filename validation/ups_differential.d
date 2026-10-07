/**
 * Independent UPS differential validation.
 *
 * PROJ validates the fixed EPSG 5041/5042 parameterization. GeographicLib
 * UTMUPS validates explicit UPS projection, standard UTM/UPS selection,
 * reverse behavior, convergence, scale, and represented coordinate ranges.
 */
module ups_differential;

import std.conv : to;
import std.format : format;
import std.math : fabs, sqrt;
import std.process : executeShell;
import std.stdio : writeln;
import std.string : split, strip;

import geodesy;

private enum double positionTolerance = 0.0001;
private enum double angularTolerance = 1e-9;
private enum double factorTolerance = 2e-12;

private struct Reference
{
    double first;
    double second;
    double gamma;
    double scale;
    int zone;
    bool north;
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private double normalizeLongitude(double lon)
{
    while (lon >= 180.0)
        lon -= 360.0;
    while (lon < -180.0)
        lon += 360.0;
    return lon;
}

private double longitudeError(double a, double b)
{
    return fabs(normalizeLongitude(a - b));
}

private Reference runGl(
    const string oracle,
    const string direction,
    const double a,
    const double b,
    const bool north = true)
{
    string command;

    if (direction == "reverse")
        command = format(
            "%s reverse %s %.17g %.17g",
            oracle,
            north ? "1" : "0",
            a,
            b);
    else
        command = format(
            "%s %s %.17g %.17g",
            oracle,
            direction,
            a,
            b);

    const output = executeShell(command);
    if (output.status != 0)
        throw new Exception("GeographicLib oracle failed: " ~ output.output);

    const fields = output.output.strip.split;
    require(fields.length >= 2 && fields[0] == "OK",
        "unexpected GeographicLib output: " ~ output.output);

    Reference result;

    if (direction == "standard")
    {
        result.zone = fields[1].to!int;
        return result;
    }

    if (direction == "forward")
    {
        require(fields.length == 7, "unexpected GeographicLib forward output");
        result.zone = fields[1].to!int;
        result.north = fields[2].to!int != 0;
        result.first = fields[3].to!double;
        result.second = fields[4].to!double;
        result.gamma = fields[5].to!double;
        result.scale = fields[6].to!double;
        return result;
    }

    require(fields.length == 5, "unexpected GeographicLib reverse output");
    result.first = fields[1].to!double;
    result.second = fields[2].to!double;
    result.gamma = fields[3].to!double;
    result.scale = fields[4].to!double;
    return result;
}

private ProjectedCoordinate!double runProj(
    const bool north,
    const double latitude,
    const double longitude)
{
    const string operation = format(
        "+proj=pipeline "
        ~ "+step +proj=unitconvert +xy_in=deg +xy_out=rad "
        ~ "+step +proj=stere +lat_0=%s +lon_0=0 +k_0=0.994 "
        ~ "+x_0=2000000 +y_0=2000000 +ellps=WGS84",
        north ? "90" : "-90");

    const string command = format(
        "printf '%%.17g %%.17g 0 0\\n' %.17g %.17g | cct -d 14 %s",
        longitude,
        latitude,
        operation);

    const output = executeShell(command);
    if (output.status != 0)
        throw new Exception("PROJ cct failed: " ~ output.output);

    const fields = output.output.strip.split;
    require(fields.length >= 2, "unexpected PROJ output");

    return ProjectedCoordinate!double.fromComponents(
        fields[0].to!double,
        fields[1].to!double);
}

private void comparePosition(
    const string label,
    const ProjectedCoordinate!double actual,
    const double easting,
    const double northing)
{
    const double de = actual.easting - easting;
    const double dn = actual.northing - northing;
    const double error = sqrt(de * de + dn * dn);

    require(error <= positionTolerance,
        format("%s position error %.17g m", label, error));
}

private void validateStandardSelection(const string oracle)
{
    struct Case
    {
        double lat;
        bool ups;
        UpsHemisphere hemisphere;
    }

    const Case[] cases = [
        Case(-90.0, true, UpsHemisphere.south),
        Case(-80.000001, true, UpsHemisphere.south),
        Case(-80.0, false, UpsHemisphere.south),
        Case(0.0, false, UpsHemisphere.north),
        Case(83.999999, false, UpsHemisphere.north),
        Case(84.0, true, UpsHemisphere.north),
        Case(90.0, true, UpsHemisphere.north),
    ];

    foreach (item; cases)
    {
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(item.lat),
            Longitude!double.fromDegrees(15.0));

        UpsHemisphere hemisphere;
        const bool ours = tryStandardUpsHemisphere(point, hemisphere);
        const Reference gl = runGl(oracle, "standard", item.lat, 15.0);

        require(ours == item.ups,
            format("standard UPS selection mismatch at lat %.9g", item.lat));
        require((gl.zone == 0) == item.ups,
            format("GeographicLib standard selection mismatch at lat %.9g", item.lat));

        if (item.ups)
            require(hemisphere == item.hemisphere,
                "UPS hemisphere mismatch");
    }
}

private void validatePoint(
    const string oracle,
    const bool north,
    const double latitude,
    const double longitude)
{
    const UpsHemisphere hemisphere =
        north ? UpsHemisphere.north : UpsHemisphere.south;

    const projection =
        UpsProjection!double.fromHemisphere(hemisphere);

    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(latitude),
        Longitude!double.fromDegrees(longitude));

    const ours = projection.forward(point);
    const factors = projection.forwardFactors(point);

    const Reference gl =
        runGl(oracle, "forward", latitude, longitude);

    require(gl.zone == 0, "GeographicLib explicit UPS did not return zone 0");
    require(gl.north == north, "GeographicLib UPS hemisphere mismatch");

    comparePosition(
        format("GeographicLib forward lat=%.9g lon=%.9g", latitude, longitude),
        ours,
        gl.first,
        gl.second);

    const auto proj = runProj(north, latitude, longitude);
    comparePosition(
        format("PROJ forward lat=%.9g lon=%.9g", latitude, longitude),
        ours,
        proj.easting,
        proj.northing);

    if (fabs(latitude) < 90.0)
    {
        require(
            fabs(factors.meridianConvergence.degrees - gl.gamma)
                <= angularTolerance,
            "UPS convergence mismatch");
    }
    else
    {
        require(factors.meridianConvergence.degrees == 0.0,
            "UPS pole convergence is not canonical zero");
    }

    require(
        fabs(factors.pointScale - gl.scale) <= factorTolerance,
        "UPS point-scale mismatch");

    const Reference glReverse = runGl(
        oracle,
        "reverse",
        gl.first,
        gl.second,
        north);

    GeographicCoordinate!double recovered;
    require(
        projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(gl.first, gl.second),
            recovered),
        "geodesy-d rejected GeographicLib UPS coordinate");

    require(
        fabs(recovered.latitude.degrees - glReverse.first)
            <= angularTolerance,
        "UPS reverse latitude mismatch");

    if (fabs(latitude) < 90.0)
        require(
            longitudeError(
                recovered.longitude.degrees,
                glReverse.second) <= angularTolerance,
            "UPS reverse longitude mismatch");

    const auto reverseFactors = projection.reverseFactors(
        ProjectedCoordinate!double.fromComponents(gl.first, gl.second));

    if (fabs(latitude) < 90.0)
        require(
            fabs(
                reverseFactors.meridianConvergence.degrees
                    - glReverse.gamma) <= angularTolerance,
            "UPS reverse convergence mismatch");

    require(
        fabs(reverseFactors.pointScale - glReverse.scale)
            <= factorTolerance,
        "UPS reverse scale mismatch");
}

void main(string[] args)
{
    if (args.length != 2)
        throw new Exception("usage: ups_differential GEOGRAPHICLIB_ORACLE");

    const string oracle = args[1];

    validateStandardSelection(oracle);

    validatePoint(oracle, true, 83.5, 0.0);
    validatePoint(oracle, true, 84.0, 45.0);
    validatePoint(oracle, true, 85.0, -135.0);
    validatePoint(oracle, true, 89.999, 179.5);
    validatePoint(oracle, true, 90.0, 123.0);

    validatePoint(oracle, false, -79.5, 0.0);
    validatePoint(oracle, false, -80.000001, 45.0);
    validatePoint(oracle, false, -85.0, -135.0);
    validatePoint(oracle, false, -89.999, 179.5);
    validatePoint(oracle, false, -90.0, 123.0);

    writeln("PASS: UPS PROJ + GeographicLib differential validation");
}
