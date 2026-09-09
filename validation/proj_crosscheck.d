/**
 * Differential validation of geodesy-d against the external PROJ `cct`
 * executable.
 *
 * This file is not part of the library source tree and is compiled only by
 * tools/validate-proj.sh.
 */
module proj_crosscheck;

import std.conv : to;
import std.format : format;
import std.math : fabs, isFinite;
import std.process : executeShell;
import std.stdio : writefln, writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.conversion :
    geocentricToGeodetic,
    geodeticToGeocentric;
import geodesy.ellipsoid : wgs84;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.geodetic : GeodeticCoordinate;
import geodesy.transform.geocentric_translation :
    GeocentricTranslation,
    applyGeocentricTranslation;
import geodesy.transform.helmert :
    CoordinateFrameHelmert,
    PositionVectorHelmert,
    applyCoordinateFrameHelmert,
    applyPositionVectorHelmert;


private struct Triple
{
    double a;
    double b;
    double c;
}


private Triple runCct(
    const string operation,
    const bool inverse,
    const double a,
    const double b,
    const double c)
{
    /*
     * Keep printf's format string fixed. Numeric values are passed as
     * separate quoted arguments, so a leading minus sign can never be
     * interpreted as a printf option.
     *
     * `%%s` is required because std.format.format consumes percent
     * placeholders before the command reaches the shell.
     */
    const command = format(
        "printf '%%s %%s %%s 0\\n' '%.17g' '%.17g' '%.17g' | "
        ~ "cct -d 12 %s %s",
        a,
        b,
        c,
        inverse ? "-I" : "",
        operation);

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "cct failed (status %s): %s\\n%s",
                output.status,
                command,
                output.output));

    const fields = output.output.strip.split;
    if (fields.length < 3)
        throw new Exception(
            "unexpected cct output: " ~ output.output);

    try
    {
        return Triple(
            fields[0].to!double,
            fields[1].to!double,
            fields[2].to!double);
    }
    catch (Exception error)
    {
        throw new Exception(
            format(
                "non-numeric cct output for command:\\n%s\\noutput:\\n%s",
                command,
                output.output));
    }
}


private void requireNear(
    const string label,
    const double actual,
    const double reference,
    const double tolerance,
    ref size_t checks,
    ref double worstNormalizedError)
{
    if (!isFinite(actual) || !isFinite(reference))
        throw new Exception(
            format(
                "%s: non-finite comparison value: actual=%.17g reference=%.17g",
                label,
                actual,
                reference));

    const error = fabs(actual - reference);
    const normalized =
        tolerance > 0.0 ? error / tolerance : error;

    if (!isFinite(error) || !isFinite(normalized))
        throw new Exception(
            format(
                "%s: non-finite validation error: error=%.17g normalized=%.17g",
                label,
                error,
                normalized));

    if (normalized > worstNormalizedError)
        worstNormalizedError = normalized;

    ++checks;

    if (error > tolerance)
        throw new Exception(
            format(
                "%s: actual=%.17g reference=%.17g "
                ~ "error=%.17g tolerance=%.17g",
                label,
                actual,
                reference,
                error,
                tolerance));
}


private void validateGeographicGeocentric(
    ref size_t checks,
    ref double worstNormalizedError)
{
    struct GeoCase
    {
        double longitudeDegrees;
        double latitudeDegrees;
        double height;
    }

    const cases = [
        GeoCase(0.0, 0.0, 0.0),
        GeoCase(16.3738, 48.2082, 171.0),
        GeoCase(-122.4194, 37.7749, 30.0),
        GeoCase(151.2093, -33.8688, 5.0),
        GeoCase(179.999, 10.0, 0.0),
        GeoCase(-179.999, -10.0, 1_234.5),
        GeoCase(45.0, 80.0, -250.0),
        GeoCase(-75.0, -80.0, 8_500.0),
        GeoCase(12.0, 89.999, 10.0),
        GeoCase(-33.0, -89.999, 100_000.0),
        GeoCase(90.0, 45.0, 1_000_000.0),
        GeoCase(-90.0, -45.0, 35_786_000.0),
    ];

    const cartOperation = "+proj=cart +ellps=WGS84";

    foreach (index, test; cases)
    {
        const geodetic =
            GeodeticCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(test.latitudeDegrees),
                Longitude!double.fromDegrees(test.longitudeDegrees),
                test.height);

        /*
         * Forward differential validation:
         * both implementations start from the same geodetic coordinate.
         */
        const oursForward = geodeticToGeocentric(
            geodetic,
            wgs84!double());

        const projForward = runCct(
            cartOperation,
            false,
            test.longitudeDegrees,
            test.latitudeDegrees,
            test.height);

        const forwardPrefix =
            format("EPSG9602 forward case %s ", index);

        requireNear(
            forwardPrefix ~ "X",
            oursForward.x,
            projForward.a,
            2.0e-5,
            checks,
            worstNormalizedError);

        requireNear(
            forwardPrefix ~ "Y",
            oursForward.y,
            projForward.b,
            2.0e-5,
            checks,
            worstNormalizedError);

        requireNear(
            forwardPrefix ~ "Z",
            oursForward.z,
            projForward.c,
            2.0e-5,
            checks,
            worstNormalizedError);

        /*
         * Inverse differential validation:
         * use the Cartesian coordinate independently produced by PROJ as
         * input to geodesy-d's inverse, then compare with the known source
         * geodetic vector.
         *
         * This avoids treating PROJ's direct Bowring inverse as a
         * higher-accuracy oracle at large ellipsoidal heights.
         */
        const projCartesian =
            GeocentricCoordinate!double.fromComponents(
                projForward.a,
                projForward.b,
                projForward.c);

        const oursInverse = geocentricToGeodetic(
            projCartesian,
            wgs84!double());

        const inversePrefix =
            format("EPSG9602 inverse-from-PROJ case %s ", index);

        requireNear(
            inversePrefix ~ "longitude",
            oursInverse.longitude.degrees,
            test.longitudeDegrees,
            5.0e-10,
            checks,
            worstNormalizedError);

        requireNear(
            inversePrefix ~ "latitude",
            oursInverse.latitude.degrees,
            test.latitudeDegrees,
            5.0e-10,
            checks,
            worstNormalizedError);

        requireNear(
            inversePrefix ~ "height",
            oursInverse.ellipsoidalHeight,
            test.height,
            5.0e-5,
            checks,
            worstNormalizedError);
    }
}


private void validateGeocentricTranslation(
    ref size_t checks,
    ref double worstNormalizedError)
{
    const shift =
        GeocentricTranslation!double.fromComponents(
            84.87,
            96.49,
            116.95);

    const operation =
        "+proj=helmert "
        ~ "+x=84.87 +y=96.49 +z=116.95";

    const sources = [
        Triple(3_771_793.97, 140_253.34, 5_124_304.35),
        Triple(1.0, 2.0, 3.0),
        Triple(-4_000_000.0, 2_500_000.0, 3_900_000.0),
        Triple(6_378_137.0, 0.0, 0.0),
        Triple(0.0, -6_378_137.0, 100.0),
    ];

    foreach (index, source; sources)
    {
        const coordinate =
            GeocentricCoordinate!double.fromComponents(
                source.a,
                source.b,
                source.c);

        const ours =
            applyGeocentricTranslation(coordinate, shift);

        const proj =
            runCct(
                operation,
                false,
                source.a,
                source.b,
                source.c);

        const prefix = format("EPSG1031 case %s ", index);

        requireNear(
            prefix ~ "X", ours.x, proj.a, 2.0e-8,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Y", ours.y, proj.b, 2.0e-8,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Z", ours.z, proj.c, 2.0e-8,
            checks, worstNormalizedError);
    }
}


private void validatePositionVector(
    ref size_t checks,
    ref double worstNormalizedError)
{
    const transform =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            1.25,
            -2.5,
            4.75,
            0.35,
            -0.21,
            0.61,
            0.42);

    const operation =
        "+proj=helmert "
        ~ "+x=1.25 +y=-2.5 +z=4.75 "
        ~ "+rx=0.35 +ry=-0.21 +rz=0.61 "
        ~ "+s=0.42 +convention=position_vector";

    const sources = [
        Triple(3_657_660.66, 255_768.55, 5_201_382.11),
        Triple(1_000_000.0, 2_000_000.0, 3_000_000.0),
        Triple(-4_500_000.0, 1_200_000.0, 4_300_000.0),
        Triple(6_000_000.0, -2_000_000.0, 500_000.0),
        Triple(-100_000.0, -6_300_000.0, 900_000.0),
    ];

    foreach (index, source; sources)
    {
        const coordinate =
            GeocentricCoordinate!double.fromComponents(
                source.a,
                source.b,
                source.c);

        const ours =
            applyPositionVectorHelmert(coordinate, transform);

        const proj =
            runCct(
                operation,
                false,
                source.a,
                source.b,
                source.c);

        const prefix = format("EPSG1033 case %s ", index);

        requireNear(
            prefix ~ "X", ours.x, proj.a, 3.0e-6,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Y", ours.y, proj.b, 3.0e-6,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Z", ours.z, proj.c, 3.0e-6,
            checks, worstNormalizedError);
    }
}


private void validateCoordinateFrame(
    ref size_t checks,
    ref double worstNormalizedError)
{
    /*
     * Same represented source-to-target transformation as the Position Vector
     * set above, expressed in Coordinate Frame convention by reversing all
     * three rotation signs.
     */
    const transform =
        CoordinateFrameHelmert!double.fromArcSecondsAndPpm(
            1.25,
            -2.5,
            4.75,
            -0.35,
            0.21,
            -0.61,
            0.42);

    const operation =
        "+proj=helmert "
        ~ "+x=1.25 +y=-2.5 +z=4.75 "
        ~ "+rx=-0.35 +ry=0.21 +rz=-0.61 "
        ~ "+s=0.42 +convention=coordinate_frame";

    const sources = [
        Triple(3_657_660.66, 255_768.55, 5_201_382.11),
        Triple(1_000_000.0, 2_000_000.0, 3_000_000.0),
        Triple(-4_500_000.0, 1_200_000.0, 4_300_000.0),
        Triple(6_000_000.0, -2_000_000.0, 500_000.0),
        Triple(-100_000.0, -6_300_000.0, 900_000.0),
    ];

    foreach (index, source; sources)
    {
        const coordinate =
            GeocentricCoordinate!double.fromComponents(
                source.a,
                source.b,
                source.c);

        const ours =
            applyCoordinateFrameHelmert(coordinate, transform);

        const proj =
            runCct(
                operation,
                false,
                source.a,
                source.b,
                source.c);

        const prefix = format("EPSG1032 case %s ", index);

        requireNear(
            prefix ~ "X", ours.x, proj.a, 3.0e-6,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Y", ours.y, proj.b, 3.0e-6,
            checks, worstNormalizedError);
        requireNear(
            prefix ~ "Z", ours.z, proj.c, 3.0e-6,
            checks, worstNormalizedError);
    }
}


int main()
{
    const versionOutput = executeShell("cct --version");
    if (versionOutput.status != 0)
    {
        writeln("FAIL: cct --version failed");
        return 2;
    }

    writefln(
        "PROJ reference: %s",
        versionOutput.output.strip);

    size_t checks = 0;
    double worstNormalizedError = 0.0;

    try
    {
        validateGeographicGeocentric(
            checks,
            worstNormalizedError);

        validateGeocentricTranslation(
            checks,
            worstNormalizedError);

        validatePositionVector(
            checks,
            worstNormalizedError);

        validateCoordinateFrame(
            checks,
            worstNormalizedError);
    }
    catch (Exception error)
    {
        writefln("FAIL after %s comparisons: %s", checks, error.msg);
        return 1;
    }

    writefln(
        "PASS: %s geodesy-d vs PROJ scalar comparisons",
        checks);
    writefln(
        "worst normalized error: %.6f of configured tolerance",
        worstNormalizedError);

    return 0;
}
