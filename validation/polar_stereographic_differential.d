/**
 * PS-C / PS-D differential validation for Polar Stereographic.
 *
 * PROJ validates forward projected positions and independently generated
 * reverse inputs. GeographicLib independently validates forward/reverse,
 * meridian convergence, point scale, and variant-B standard-parallel scaling.
 */
module polar_stereographic_differential;

import std.conv : to;
import std.format : format;
import std.math : fabs, isFinite, sqrt;
import std.process : executeShell;
import std.stdio : writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.polar_stereographic : PolarStereographic;

private enum double positionTolerance = 0.0001;   // 0.1 mm
private enum double angularTolerance = 1.0e-9;    // degrees
private enum double factorTolerance = 2.0e-12;
private enum double k0Tolerance = 2.0e-14;

private struct Reference
{
    double first;
    double second;
    double gamma;
    double scale;
    double centralScale;
}

private struct Config
{
    string label;
    bool variantB;
    double a;
    double f;
    double parameter; // k0 for A, signed standard parallel for B
    bool north;
    double lon0;
    double falseEasting;
    double falseNorthing;
}

private struct Metrics
{
    size_t projForward;
    size_t projReverse;
    size_t geographicLibForward;
    size_t geographicLibReverse;
    size_t factorChecks;
    double worstPosition;
    double worstAngular;
    double worstFactor;
    string worstLabel;
}

private double normalizeLongitude(double lon)
{
    while (lon >= 180.0)
        lon -= 360.0;
    while (lon < -180.0)
        lon += 360.0;
    return lon == 0.0 ? 0.0 : lon;
}

private double longitudeError(double actual, double expected)
{
    return fabs(normalizeLongitude(actual - expected));
}

private string ellipsoidArgs(const Config config)
{
    if (config.f == 0.0)
        return format("+a=%.17g +b=%.17g", config.a, config.a);

    return format("+a=%.17g +rf=%.17g",
        config.a, 1.0 / config.f);
}

private string projForwardOperation(const Config config)
{
    const double lat0 = config.north ? 90.0 : -90.0;
    const string scaleArg = config.variantB
        ? format("+lat_ts=%.17g", config.parameter)
        : format("+k_0=%.17g", config.parameter);

    return format(
        "+proj=pipeline "
        ~ "+step +proj=unitconvert +xy_in=deg +xy_out=rad "
        ~ "+step +proj=stere +lat_0=%.17g +lon_0=%.17g %s "
        ~ "+x_0=%.17g +y_0=%.17g %s",
        lat0,
        config.lon0,
        scaleArg,
        config.falseEasting,
        config.falseNorthing,
        ellipsoidArgs(config));
}

private string projReverseOperation(const Config config)
{
    const double lat0 = config.north ? 90.0 : -90.0;
    const string scaleArg = config.variantB
        ? format("+lat_ts=%.17g", config.parameter)
        : format("+k_0=%.17g", config.parameter);

    return format(
        "+proj=pipeline "
        ~ "+step +inv +proj=stere +lat_0=%.17g +lon_0=%.17g %s "
        ~ "+x_0=%.17g +y_0=%.17g %s "
        ~ "+step +proj=unitconvert +xy_in=rad +xy_out=deg",
        lat0,
        config.lon0,
        scaleArg,
        config.falseEasting,
        config.falseNorthing,
        ellipsoidArgs(config));
}

private Reference runCct(
    const string operation,
    const double first,
    const double second)
{
    const command = format(
        "printf '%%.17g %%.17g 0 0\\n' %.17g %.17g | cct -d 14 %s",
        first, second, operation);

    const output = executeShell(command);
    if (output.status != 0)
        throw new Exception("cct failed: " ~ output.output);

    const fields = output.output.strip.split;
    if (fields.length < 2)
        throw new Exception("unexpected cct output: " ~ output.output);

    return Reference(fields[0].to!double, fields[1].to!double);
}

private Reference runGeographicLib(
    const string oracle,
    const Config config,
    const string direction,
    const double first,
    const double second)
{
    const command = format(
        "%s %s %s %.17g %.17g %.17g %s %.17g %.17g %.17g %.17g %.17g",
        oracle,
        config.variantB ? "b" : "a",
        direction,
        config.a,
        config.f,
        config.parameter,
        config.north ? "1" : "0",
        config.lon0,
        config.falseEasting,
        config.falseNorthing,
        first,
        second);

    const output = executeShell(command);
    if (output.status != 0)
        throw new Exception("GeographicLib oracle failed: " ~ output.output);

    const fields = output.output.strip.split;
    if (fields.length != 6 || fields[0] != "OK")
        throw new Exception("unexpected GeographicLib output: " ~ output.output);

    return Reference(
        fields[1].to!double,
        fields[2].to!double,
        fields[3].to!double,
        fields[4].to!double,
        fields[5].to!double);
}

private void recordPosition(
    const string label,
    const double a1,
    const double a2,
    const double b1,
    const double b2,
    ref Metrics metrics)
{
    const double d1 = a1 - b1;
    const double d2 = a2 - b2;
    const double error = sqrt(d1 * d1 + d2 * d2);

    if (!isFinite(error) || error > positionTolerance)
        throw new Exception(format(
            "%s position error %.17g > %.17g; d1=%.17g d2=%.17g",
            label, error, positionTolerance, d1, d2));

    if (error > metrics.worstPosition)
    {
        metrics.worstPosition = error;
        metrics.worstLabel = label;
    }
}

private void recordAngular(
    const string label,
    const double actual,
    const double expected,
    const bool longitude,
    ref Metrics metrics)
{
    const double error = longitude
        ? longitudeError(actual, expected)
        : fabs(actual - expected);

    if (!isFinite(error) || error > angularTolerance)
        throw new Exception(format(
            "%s angular error %.17g > %.17g; actual=%.17g expected=%.17g",
            label, error, angularTolerance, actual, expected));

    if (error > metrics.worstAngular)
    {
        metrics.worstAngular = error;
        metrics.worstLabel = label;
    }
}

private void recordFactor(
    const string label,
    const double actual,
    const double expected,
    ref Metrics metrics)
{
    const double error = fabs(actual - expected);

    if (!isFinite(error) || error > factorTolerance)
        throw new Exception(format(
            "%s factor error %.17g > %.17g; actual=%.17g expected=%.17g",
            label, error, factorTolerance, actual, expected));

    if (error > metrics.worstFactor)
    {
        metrics.worstFactor = error;
        metrics.worstLabel = label;
    }
}

private PolarStereographic!double prepare(const Config config)
{
    const ellipsoid = Ellipsoid!double.fromFlattening(config.a, config.f);
    const lon0 = Longitude!double.fromDegrees(config.lon0);

    if (config.variantB)
        return PolarStereographic!double.fromStandardParallel(
            ellipsoid,
            Latitude!double.fromDegrees(config.parameter),
            lon0,
            config.falseEasting,
            config.falseNorthing);

    return PolarStereographic!double.fromParameters(
        ellipsoid,
        Latitude!double.fromDegrees(config.north ? 90.0 : -90.0),
        lon0,
        config.parameter,
        config.falseEasting,
        config.falseNorthing);
}

private void validatePoint(
    const string oracle,
    const Config config,
    const PolarStereographic!double projection,
    const double latitude,
    const double longitude,
    ref Metrics metrics)
{
    const string label = format(
        "%s lat=%.12g lon=%.12g", config.label, latitude, longitude);

    const geographic = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(latitude),
        Longitude!double.fromDegrees(normalizeLongitude(longitude)));

    const ours = projection.forward(geographic);
    const oursFactors = projection.forwardFactors(geographic);

    // PS-C: PROJ forward differential.
    const proj = runCct(
        projForwardOperation(config),
        longitude,
        latitude);

    recordPosition(
        label ~ " PROJ forward",
        ours.easting,
        ours.northing,
        proj.first,
        proj.second,
        metrics);
    ++metrics.projForward;

    // PS-C: reverse from independently generated PROJ E/N.
    GeographicCoordinate!double recoveredProj;
    if (!projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(
                proj.first, proj.second),
            recoveredProj))
        throw new Exception(label ~ " reverse rejected PROJ coordinate");

    recordAngular(
        label ~ " PROJ reverse latitude",
        recoveredProj.latitude.degrees,
        latitude,
        false,
        metrics);

    if (fabs(latitude) < 90.0)
    {
        const representedByProj = runCct(
            projForwardOperation(config),
            recoveredProj.longitude.degrees,
            recoveredProj.latitude.degrees);

        recordPosition(
            label ~ " PROJ reverse represented position",
            representedByProj.first,
            representedByProj.second,
            proj.first,
            proj.second,
            metrics);
    }
    ++metrics.projReverse;

    // Also exercise PROJ's independent reverse direction.
    const projReverse = runCct(
        projReverseOperation(config),
        proj.first,
        proj.second);
    recordAngular(
        label ~ " PROJ own inverse latitude",
        projReverse.second,
        latitude,
        false,
        metrics);
    if (fabs(latitude) < 90.0)
    {
        const projOwnRepresented = runCct(
            projForwardOperation(config),
            projReverse.first,
            projReverse.second);

        recordPosition(
            label ~ " PROJ own inverse represented position",
            projOwnRepresented.first,
            projOwnRepresented.second,
            proj.first,
            proj.second,
            metrics);
    }

    // PS-D: GeographicLib forward positions + factors.
    const gl = runGeographicLib(
        oracle, config, "forward", latitude, longitude);

    recordPosition(
        label ~ " GeographicLib forward",
        ours.easting,
        ours.northing,
        gl.first,
        gl.second,
        metrics);
    ++metrics.geographicLibForward;

    const expectedGamma = fabs(latitude) == 90.0 ? 0.0 : gl.gamma;
    recordAngular(
        label ~ " GeographicLib gamma",
        oursFactors.meridianConvergence.degrees,
        expectedGamma,
        true,
        metrics);
    recordFactor(
        label ~ " GeographicLib scale",
        oursFactors.pointScale,
        gl.scale,
        metrics);
    metrics.factorChecks += 2;

    if (config.variantB
        && fabs(projection.scaleFactorAtNaturalOrigin - gl.centralScale) > k0Tolerance)
        throw new Exception(format(
            "%s derived k0 mismatch ours=%.17g GeographicLib=%.17g",
            label,
            projection.scaleFactorAtNaturalOrigin,
            gl.centralScale));

    // PS-D: reverse and reverse factors from independently generated GL E/N.
    const independentProjected = ProjectedCoordinate!double.fromComponents(
        gl.first, gl.second);

    GeographicCoordinate!double recoveredGl;
    if (!projection.tryReverse(independentProjected, recoveredGl))
        throw new Exception(label ~ " reverse rejected GeographicLib coordinate");

    recordAngular(
        label ~ " GeographicLib reverse latitude",
        recoveredGl.latitude.degrees,
        latitude,
        false,
        metrics);
    if (fabs(latitude) < 90.0)
    {
        const representedByGl = runGeographicLib(
            oracle,
            config,
            "forward",
            recoveredGl.latitude.degrees,
            recoveredGl.longitude.degrees);

        recordPosition(
            label ~ " GeographicLib reverse represented position",
            representedByGl.first,
            representedByGl.second,
            gl.first,
            gl.second,
            metrics);
    }
    ++metrics.geographicLibReverse;

    // Query GeographicLib reverse on the exact same represented E/N before
    // comparing reverse factors.  Near the pole, E/N rounding can correspond
    // to a measurably different local scale even when angular recovery is
    // excellent; forward factors at the pre-rounded source are therefore not
    // the correct reverse-factor oracle.
    const glReverse = runGeographicLib(
        oracle, config, "reverse", gl.first, gl.second);

    const reverseFactors = projection.reverseFactors(independentProjected);
    const expectedReverseGamma =
        fabs(glReverse.first) == 90.0 ? 0.0 : glReverse.gamma;
    recordAngular(
        label ~ " GeographicLib reverse gamma",
        reverseFactors.meridianConvergence.degrees,
        expectedReverseGamma,
        true,
        metrics);
    recordFactor(
        label ~ " GeographicLib reverse scale",
        reverseFactors.pointScale,
        glReverse.scale,
        metrics);
    metrics.factorChecks += 2;

    recordAngular(
        label ~ " GeographicLib own reverse latitude",
        glReverse.first,
        latitude,
        false,
        metrics);
    if (fabs(latitude) < 90.0)
    {
        const glOwnRepresented = runGeographicLib(
            oracle,
            config,
            "forward",
            glReverse.first,
            glReverse.second);

        recordPosition(
            label ~ " GeographicLib own reverse represented position",
            glOwnRepresented.first,
            glOwnRepresented.second,
            gl.first,
            gl.second,
            metrics);
    }
}

private void validateConfig(
    const string oracle,
    const Config config,
    ref Metrics metrics)
{
    const projection = prepare(config);

    const double sign = config.north ? 1.0 : -1.0;
    const double[] absoluteLatitudes = [
        0.0,
        0.000001,
        1.0,
        15.0,
        45.0,
        70.0,
        80.0,
        85.0,
        89.0,
        89.999999,
        90.0,
    ];

    const double[] longitudeOffsets = [
        0.0,
        0.000001,
        -0.000001,
        1.0,
        -17.0,
        45.0,
        -90.0,
        135.0,
        179.5,
    ];

    foreach (i, absLatitude; absoluteLatitudes)
    {
        // Nine longitude directions are distributed deterministically instead
        // of forming a full Cartesian product; this keeps CI fast while every
        // configuration covers all difficult latitude classes and longitudes.
        foreach (j; 0 .. 3)
        {
            const size_t index =
                (i * 3 + j * 4) % longitudeOffsets.length;

            validatePoint(
                oracle,
                config,
                projection,
                sign * absLatitude,
                normalizeLongitude(config.lon0 + longitudeOffsets[index]),
                metrics);
        }
    }
}

int main(string[] args)
{
    if (args.length != 2)
    {
        writeln("usage: polar_stereographic_differential GEOGRAPHICLIB_ORACLE");
        return 2;
    }

    const Config[] configs = [
        Config("A WGS84 north", false,
            6_378_137.0, 1.0 / 298.257223563,
            0.994, true, 0.0, 2_000_000.0, 2_000_000.0),

        Config("A WGS84 south shifted", false,
            6_378_137.0, 1.0 / 298.257223563,
            0.997, false, 30.0, -500_000.0, 800_000.0),

        Config("A GRS80 north", false,
            6_378_137.0, 1.0 / 298.257222101,
            1.003, true, -45.0, 123_456.0, -654_321.0),

        Config("A sphere south", false,
            6_371_000.0, 0.0,
            1.0, false, 120.0, 0.0, 0.0),

        Config("B WGS84 south EPSG example", true,
            6_378_137.0, 1.0 / 298.257223563,
            -71.0, false, 70.0, 6_000_000.0, 6_000_000.0),

        Config("B WGS84 north", true,
            6_378_137.0, 1.0 / 298.257223563,
            70.0, true, -30.0, 500_000.0, 700_000.0),

        Config("B Airy south", true,
            6_377_563.396, 1.0 / 299.3249646,
            -80.0, false, 15.0, -1_000_000.0, 2_500_000.0),

        Config("B sphere north", true,
            6_371_000.0, 0.0,
            75.0, true, 150.0, 0.0, 0.0),
    ];

    Metrics metrics;

    foreach (config; configs)
        validateConfig(args[1], config, metrics);

    writeln("PASS: Polar Stereographic PS-C / PS-D differential validation");
    writeln("  configurations: ", configs.length);
    writeln("  PROJ forward cases: ", metrics.projForward);
    writeln("  PROJ reverse cases: ", metrics.projReverse);
    writeln("  GeographicLib forward cases: ", metrics.geographicLibForward);
    writeln("  GeographicLib reverse cases: ", metrics.geographicLibReverse);
    writeln("  factor comparisons: ", metrics.factorChecks);
    writeln("  worst projected error [linear units]: ", metrics.worstPosition);
    writeln("  worst angular error [deg]: ", metrics.worstAngular);
    writeln("  worst factor error: ", metrics.worstFactor);
    writeln("  worst label: ", metrics.worstLabel);

    return 0;
}
