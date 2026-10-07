module lambert_azimuthal_equal_area_differential;

import std.conv : to;
import std.format : format;
import std.math : fabs;
import std.process : executeShell;
import std.stdio : writeln;
import std.string : split, strip;

import geodesy;

private enum double linearTolerance = 0.04;
/*
 * PROJ 9.4 reverses ellipsoidal authalic latitude through its prepared
 * auxiliary-latitude series. geodesy-d solves q(phi) directly with Newton.
 * The independent reverse comparison therefore admits the measured
 * reference-series floor (~1.4e-8 degree in EPSG:3035 cases), while the
 * geodesy-d self-roundtrip below retains the stricter tolerance.
 */
private enum double projReverseAngularTolerance = 2e-8;
private enum double ownRoundTripAngularTolerance = 5e-9;
private enum double nearAntipodeLatitudeRoundTripTolerance = 1e-8;
private enum double nearAntipodeLongitudeRoundTripTolerance = 1e-7;

private struct Config
{
    string name;
    double a;
    double f;
    double lat0;
    double lon0;
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
        "+proj=laea %s +lat_0=%.17g +lon_0=%.17g "
        ~ "+x_0=%.17g +y_0=%.17g",
        ellipsoid,
        c.lat0,
        c.lon0,
        c.falseEasting,
        c.falseNorthing);
}

private Pair runProj(
    const Config c,
    bool inverse,
    double first,
    double second)
{
    const command = format(
        "printf '%%.17g %%.17g\\n' %.17g %.17g | proj %s -f '%%.12f' %s",
        first,
        second,
        inverse ? "-I" : "",
        projDefinition(c));

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception("PROJ failed: " ~ output.output);

    const fields = output.output.strip.split;

    if (fields.length < 2)
        throw new Exception("unexpected PROJ output: " ~ output.output);

    return Pair(
        fields[0].to!double,
        fields[1].to!double);
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private Ellipsoid!double makeEllipsoid(const Config c)
{
    if (c.f == 0.0)
        return Ellipsoid!double.sphere(c.a);

    return Ellipsoid!double.fromFlattening(c.a, c.f);
}

private LambertAzimuthalEqualArea!double prepare(
    const Config c)
{
    return LambertAzimuthalEqualArea!double.fromParameters(
        makeEllipsoid(c),
        Latitude!double.fromDegrees(c.lat0),
        Longitude!double.fromDegrees(c.lon0),
        c.falseEasting,
        c.falseNorthing);
}

private bool exactAntipode(
    const Config c,
    double latitude,
    double longitude)
{
    if (fabs(fabs(c.lat0) - 90.0) < 1e-14)
        return latitude == -c.lat0;

    return latitude == -c.lat0
        && normalizeDegrees(longitude - c.lon0) == -180.0;
}

private void validatePoint(
    const Config c,
    const LambertAzimuthalEqualArea!double projection,
    double latitude,
    double longitude,
    bool nearAntipode = false)
{
    if (exactAntipode(c, latitude, longitude))
        return;

    const source =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitude),
            Longitude!double.fromDegrees(longitude));

    const ours = projection.forward(source);
    const expected =
        runProj(c, false, longitude, latitude);

    require(
        fabs(ours.easting - expected.first)
            <= linearTolerance,
        format(
            "%s forward easting mismatch at %.12g %.12g: %.17g",
            c.name,
            latitude,
            longitude,
            ours.easting - expected.first));

    require(
        fabs(ours.northing - expected.second)
            <= linearTolerance,
        format(
            "%s forward northing mismatch at %.12g %.12g: %.17g",
            c.name,
            latitude,
            longitude,
            ours.northing - expected.second));

    const independentProjected =
        ProjectedCoordinate!double.fromComponents(
            expected.first,
            expected.second);

    GeographicCoordinate!double recovered;
    require(
        projection.tryReverse(
            independentProjected,
            recovered),
        c.name ~ " reverse rejected PROJ coordinate");

    const expectedReverse =
        runProj(
            c,
            true,
            expected.first,
            expected.second);

    require(
        fabs(
            recovered.latitude.degrees
                - expectedReverse.second)
            <= projReverseAngularTolerance,
        format(
            "%s reverse latitude mismatch: %.17g",
            c.name,
            recovered.latitude.degrees
                - expectedReverse.second));

    require(
        fabs(
            normalizeDegrees(
                recovered.longitude.degrees
                    - expectedReverse.first))
            <= projReverseAngularTolerance,
        format(
            "%s reverse longitude mismatch: %.17g",
            c.name,
            normalizeDegrees(
                recovered.longitude.degrees
                    - expectedReverse.first)));

    const roundTrip =
        projection.reverse(ours);

    const double ownLatError =
        roundTrip.latitude.degrees - latitude;

    const double ownLatitudeTolerance =
        nearAntipode
            ? nearAntipodeLatitudeRoundTripTolerance
            : ownRoundTripAngularTolerance;

    require(
        fabs(ownLatError)
            <= ownLatitudeTolerance,
        format(
            "%s own latitude roundtrip mismatch at %.12g %.12g: %.17g",
            c.name,
            latitude,
            longitude,
            ownLatError));

    if (fabs(latitude) < 90.0)
    {
        const double ownLonError =
            normalizeDegrees(
                roundTrip.longitude.degrees - longitude);

        const double ownLongitudeTolerance =
            nearAntipode
                ? nearAntipodeLongitudeRoundTripTolerance
                : ownRoundTripAngularTolerance;

        require(
            fabs(ownLonError)
                <= ownLongitudeTolerance,
            format(
                "%s own longitude roundtrip mismatch at %.12g %.12g: %.17g",
                c.name,
                latitude,
                longitude,
                ownLonError));
    }
}

void main()
{
    const Config[] configs = [
        Config(
            "EPSG 3035 Europe LAEA",
            6_378_137.0,
            1.0 / 298.257222101,
            52.0,
            10.0,
            4_321_000.0,
            3_210_000.0),

        Config(
            "WGS84 oblique south",
            6_378_137.0,
            1.0 / 298.257223563,
            -35.0,
            135.0,
            800_000.0,
            -250_000.0),

        Config(
            "sphere equatorial",
            6_371_000.0,
            0.0,
            0.0,
            -30.0,
            0.0,
            0.0),

        Config(
            "WGS84 north polar",
            6_378_137.0,
            1.0 / 298.257223563,
            90.0,
            20.0,
            2_000_000.0,
            2_000_000.0),

        Config(
            "Airy south polar",
            6_377_563.396,
            1.0 / 299.3249646,
            -90.0,
            -45.0,
            -1_000_000.0,
            3_000_000.0),
    ];

    foreach (c; configs)
    {
        const projection = prepare(c);

        const double[] latitudes = [
            c.lat0,
            c.lat0 == 90.0 ? 80.0
                : c.lat0 == -90.0 ? -80.0
                : 0.0,
            c.lat0 == 90.0 ? 45.0
                : c.lat0 == -90.0 ? -45.0
                : 25.0,
            c.lat0 == 90.0 ? 5.0
                : c.lat0 == -90.0 ? -5.0
                : -25.0,
            c.lat0 > 0.0 ? -70.0 : 70.0,
            c.lat0 > 0.0 ? -85.0 : 85.0,
        ];

        const double[] longitudeOffsets = [
            0.0,
            0.000001,
            -0.000001,
            5.0,
            -17.0,
            45.0,
            -90.0,
            135.0,
            175.0,
        ];

        foreach (i, latitude; latitudes)
        {
            if (latitude < -90.0 || latitude > 90.0)
                continue;

            foreach (j; 0 .. 3)
            {
                const size_t k =
                    (i * 3 + j * 4)
                    % longitudeOffsets.length;

                validatePoint(
                    c,
                    projection,
                    latitude,
                    normalizeDegrees(
                        c.lon0
                        + longitudeOffsets[k]));
            }
        }

        if (fabs(c.lat0) < 90.0)
        {
            const double nearAntiLatitude =
                -c.lat0 + (c.lat0 >= 0.0 ? 0.05 : -0.05);

            validatePoint(
                c,
                projection,
                nearAntiLatitude,
                normalizeDegrees(c.lon0 + 179.5),
                true);
        }
    }

    writeln("PASS: Lambert Azimuthal Equal Area PROJ differential validation");
    writeln("  configurations: ", configs.length);
    writeln("  EPSG:3035 Europe LAEA covered");
    writeln("  oblique/equatorial/north-polar/south-polar modes covered");
}
