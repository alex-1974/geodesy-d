module lambert_conformal_conic_differential;

import std.conv : to;
import std.format : format;
import std.math : fabs;
import std.process : executeShell;
import std.stdio : writeln;
import std.string : split, strip;

import geodesy;

private enum double linearTolerance = 0.03;
private enum double angularTolerance = 3e-9;

private struct Config
{
    string name;
    double a;
    double f;
    double lat0;
    double lon0;
    double lat1;
    double lat2;
    double falseEasting;
    double falseNorthing;
}

private struct Pair
{
    double first;
    double second;
}

private double normalizeDegrees(double value)
{
    while (value >= 180.0) value -= 360.0;
    while (value < -180.0) value += 360.0;
    return value;
}

private string projDefinition(const Config c)
{
    string ellipsoid;

    if (c.f == 0.0)
        ellipsoid = format("+R=%.17g", c.a);
    else
        ellipsoid = format("+a=%.17g +rf=%.17g", c.a, 1.0 / c.f);

    return format(
        "+proj=lcc %s +lat_0=%.17g +lon_0=%.17g "
        ~ "+lat_1=%.17g +lat_2=%.17g +x_0=%.17g +y_0=%.17g",
        ellipsoid,
        c.lat0, c.lon0, c.lat1, c.lat2,
        c.falseEasting, c.falseNorthing);
}

private Pair runProj(
    const Config c,
    bool inverse,
    double first,
    double second)
{
    const command = format(
        "printf '%%.17g %%.17g\\n' %.17g %.17g | proj %s -f '%%.12f' %s",
        first, second,
        inverse ? "-I" : "",
        projDefinition(c));

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception("PROJ failed: " ~ output.output);

    const fields = output.output.strip.split;
    if (fields.length < 2)
        throw new Exception("unexpected PROJ output: " ~ output.output);

    return Pair(fields[0].to!double, fields[1].to!double);
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private Ellipsoid!double ellipsoid(const Config c)
{
    if (c.f == 0.0)
        return Ellipsoid!double.sphere(c.a);

    return Ellipsoid!double.fromFlattening(c.a, c.f);
}

private LambertConformalConic!double prepare(const Config c)
{
    return LambertConformalConic!double.fromTwoStandardParallels(
        ellipsoid(c),
        Latitude!double.fromDegrees(c.lat0),
        Longitude!double.fromDegrees(c.lon0),
        Latitude!double.fromDegrees(c.lat1),
        Latitude!double.fromDegrees(c.lat2),
        c.falseEasting,
        c.falseNorthing);
}

private void validatePoint(
    const Config c,
    const LambertConformalConic!double projection,
    double latitude,
    double longitude)
{
    const source = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(latitude),
        Longitude!double.fromDegrees(longitude));

    const ours = projection.forward(source);
    const expected = runProj(c, false, longitude, latitude);

    require(
        fabs(ours.easting - expected.first) <= linearTolerance,
        format("%s forward easting mismatch at %.12g %.12g: %.17g",
            c.name, latitude, longitude, ours.easting - expected.first));

    require(
        fabs(ours.northing - expected.second) <= linearTolerance,
        format("%s forward northing mismatch at %.12g %.12g: %.17g",
            c.name, latitude, longitude, ours.northing - expected.second));

    const recovered = projection.reverse(
        ProjectedCoordinate!double.fromComponents(
            expected.first,
            expected.second));

    const expectedReverse = runProj(
        c, true, expected.first, expected.second);

    require(
        fabs(recovered.latitude.degrees - expectedReverse.second)
            <= angularTolerance,
        format("%s reverse latitude mismatch", c.name));

    require(
        fabs(normalizeDegrees(
            recovered.longitude.degrees - expectedReverse.first))
            <= angularTolerance,
        format("%s reverse longitude mismatch", c.name));

    const roundTrip = projection.reverse(ours);

    require(
        fabs(roundTrip.latitude.degrees - latitude)
            <= angularTolerance,
        format("%s own latitude roundtrip mismatch", c.name));

    require(
        fabs(normalizeDegrees(roundTrip.longitude.degrees - longitude))
            <= angularTolerance,
        format("%s own longitude roundtrip mismatch", c.name));
}

void main()
{
    const Config[] configs = [
        Config(
            "EPSG 31287 Austria Lambert",
            6_377_397.155,
            1.0 / 299.1528128,
            47.5,
            13.3333333333333,
            49.0,
            46.0,
            400_000.0,
            400_000.0),
        Config(
            "EPSG 3034 Europe LCC",
            6_378_137.0,
            1.0 / 298.257222101,
            52.0,
            10.0,
            35.0,
            65.0,
            4_000_000.0,
            2_800_000.0),
        Config(
            "WGS84 north",
            6_378_137.0,
            1.0 / 298.257223563,
            40.0,
            -96.0,
            33.0,
            45.0,
            0.0,
            0.0),
        Config(
            "sphere north",
            6_371_000.0,
            0.0,
            30.0,
            20.0,
            20.0,
            50.0,
            100_000.0,
            -300_000.0),
        Config(
            "WGS84 south",
            6_378_137.0,
            1.0 / 298.257223563,
            -32.0,
            135.0,
            -18.0,
            -36.0,
            2_000_000.0,
            1_000_000.0),
    ];

    foreach (c; configs)
    {
        const projection = prepare(c);

        const double[] latitudes = [
            c.lat0,
            c.lat1,
            c.lat2,
            (c.lat1 + c.lat2) / 2.0,
            c.lat0 > 0 ? 5.0 : -5.0,
            c.lat0 > 0 ? 75.0 : -75.0,
            c.lat0 > 0 ? 89.0 : -89.0,
        ];

        const double[] longitudeOffsets = [
            0.0, 0.000001, -0.000001,
            5.0, -17.0, 45.0, -90.0, 135.0, 179.0,
        ];

        foreach (i, latitude; latitudes)
        {
            foreach (j; 0 .. 3)
            {
                const size_t k =
                    (i * 3 + j * 4) % longitudeOffsets.length;

                validatePoint(
                    c,
                    projection,
                    latitude,
                    normalizeDegrees(c.lon0 + longitudeOffsets[k]));
            }
        }

        const standard1 = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(c.lat1),
            Longitude!double.fromDegrees(c.lon0 + 3.0));
        const standard2 = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(c.lat2),
            Longitude!double.fromDegrees(c.lon0 - 4.0));

        require(
            fabs(projection.forwardFactors(standard1).pointScale - 1.0)
                <= 2e-12,
            c.name ~ " first standard parallel scale mismatch");

        require(
            fabs(projection.forwardFactors(standard2).pointScale - 1.0)
                <= 2e-12,
            c.name ~ " second standard parallel scale mismatch");
    }

    writeln("PASS: Lambert Conformal Conic 2SP PROJ differential validation");
    writeln("  configurations: ", configs.length);
    writeln("  EPSG:31287 Austria Lambert covered");
    writeln("  EPSG:3034 Europe LCC covered");
}
