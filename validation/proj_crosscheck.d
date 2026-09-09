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
import geodesy.ellipsoid : Ellipsoid, wgs84;
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



/**
 * Small deterministic generator used only by the validation harness.
 *
 * SplitMix64 is implemented locally rather than using a library RNG so the
 * generated validation vectors remain stable across Phobos/compiler versions.
 */
private struct SplitMix64
{
    ulong state;

    ulong nextU64()
    {
        state += 0x9E3779B97F4A7C15UL;
        ulong z = state;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }

    double unit()
    {
        // Top 53 bits mapped exactly onto [0, 1).
        return cast(double)(nextU64() >> 11)
            * (1.0 / 9_007_199_254_740_992.0);
    }

    double between(const double low, const double high)
    {
        return low + (high - low) * unit();
    }
}


private double generatedLinearTolerance(
    const double actual,
    const double reference)
{
    const double aa = fabs(actual);
    const double ar = fabs(reference);
    const double scale = aa >= ar ? aa : ar;

    // Absolute floor plus a small magnitude-dependent term for coordinates
    // extending well beyond ordinary terrestrial radii.
    return 2.0e-5 + scale * 5.0e-13;
}


private void validateGeneratedGeographicGeocentric(
    ref size_t checks,
    ref double worstNormalizedError)
{
    struct EllipsoidCase
    {
        string name;
        Ellipsoid!double ellipsoid;
        string projOperation;
    }

    const ellipsoids = [
        EllipsoidCase(
            "WGS84",
            wgs84!double(),
            "+proj=cart +ellps=WGS84"),
        EllipsoidCase(
            "GRS80",
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257222101),
            "+proj=cart +a=6378137 +rf=298.257222101"),
        EllipsoidCase(
            "Airy1830",
            Ellipsoid!double.fromAxes(
                6_377_563.396,
                6_356_256.910),
            "+proj=cart +a=6377563.396 +b=6356256.910"),
        EllipsoidCase(
            "Sphere6371km",
            Ellipsoid!double.sphere(6_371_000.0),
            "+proj=cart +a=6371000 +b=6371000"),
    ];

    SplitMix64 rng = SplitMix64(0xD6E0_9602_A17E_2026UL);

    enum casesPerEllipsoid = 48;

    foreach (ellipsoidIndex, ellipsoidCase; ellipsoids)
    {
        foreach (i; 0 .. casesPerEllipsoid)
        {
            double longitude = rng.between(-180.0, 180.0);
            double latitude = rng.between(-89.95, 89.95);

            // Regularly force antimeridian and near-polar stress cases while
            // keeping longitude mathematically defined.
            if (i % 12 == 0)
                longitude = (i % 24 == 0) ? 179.999999 : -179.999999;

            if (i % 16 == 0)
                latitude = (i % 32 == 0) ? 89.999999 : -89.999999;

            double height;
            final switch (i % 4)
            {
                case 0:
                    height = rng.between(-1_000.0, 10_000.0);
                    break;
                case 1:
                    height = rng.between(10_000.0, 1_000_000.0);
                    break;
                case 2:
                    height = rng.between(1_000_000.0, 42_000_000.0);
                    break;
                case 3:
                    height = rng.between(42_000_000.0, 1_000_000_000.0);
                    break;
            }

            const source =
                GeodeticCoordinate!double.fromComponents(
                    Latitude!double.fromDegrees(latitude),
                    Longitude!double.fromDegrees(longitude),
                    height);

            const oursForward =
                geodeticToGeocentric(
                    source,
                    ellipsoidCase.ellipsoid);

            const projForward =
                runCct(
                    ellipsoidCase.projOperation,
                    false,
                    longitude,
                    latitude,
                    height);

            const prefix = format(
                "generated EPSG9602 %s case %s ",
                ellipsoidCase.name,
                i);

            requireNear(
                prefix ~ "forward X",
                oursForward.x,
                projForward.a,
                generatedLinearTolerance(oursForward.x, projForward.a),
                checks,
                worstNormalizedError);

            requireNear(
                prefix ~ "forward Y",
                oursForward.y,
                projForward.b,
                generatedLinearTolerance(oursForward.y, projForward.b),
                checks,
                worstNormalizedError);

            requireNear(
                prefix ~ "forward Z",
                oursForward.z,
                projForward.c,
                generatedLinearTolerance(oursForward.z, projForward.c),
                checks,
                worstNormalizedError);

            // Independent inverse input is generated by PROJ forward cart.
            const projCartesian =
                GeocentricCoordinate!double.fromComponents(
                    projForward.a,
                    projForward.b,
                    projForward.c);

            const oursInverse =
                geocentricToGeodetic(
                    projCartesian,
                    ellipsoidCase.ellipsoid);

            requireNear(
                prefix ~ "inverse longitude",
                oursInverse.longitude.degrees,
                longitude,
                1.0e-9,
                checks,
                worstNormalizedError);

            requireNear(
                prefix ~ "inverse latitude",
                oursInverse.latitude.degrees,
                latitude,
                1.0e-9,
                checks,
                worstNormalizedError);

            const heightTolerance =
                5.0e-5 + fabs(height) * 2.0e-12;

            requireNear(
                prefix ~ "inverse height",
                oursInverse.ellipsoidalHeight,
                height,
                heightTolerance,
                checks,
                worstNormalizedError);
        }
    }
}


private void validateGeneratedGeocentricTranslation(
    ref size_t checks,
    ref double worstNormalizedError)
{
    SplitMix64 rng = SplitMix64(0xD6E0_1031_A17E_2026UL);

    enum generatedCases = 64;

    foreach (i; 0 .. generatedCases)
    {
        const source =
            GeocentricCoordinate!double.fromComponents(
                rng.between(-100_000_000.0, 100_000_000.0),
                rng.between(-100_000_000.0, 100_000_000.0),
                rng.between(-100_000_000.0, 100_000_000.0));

        const dx = rng.between(-1_000.0, 1_000.0);
        const dy = rng.between(-1_000.0, 1_000.0);
        const dz = rng.between(-1_000.0, 1_000.0);

        const transform =
            GeocentricTranslation!double.fromComponents(
                dx, dy, dz);

        const operation = format(
            "+proj=helmert +x=%.17g +y=%.17g +z=%.17g",
            dx, dy, dz);

        const ours =
            applyGeocentricTranslation(source, transform);

        const proj =
            runCct(
                operation,
                false,
                source.x,
                source.y,
                source.z);

        const prefix =
            format("generated EPSG1031 case %s ", i);

        requireNear(
            prefix ~ "X",
            ours.x,
            proj.a,
            generatedLinearTolerance(ours.x, proj.a),
            checks,
            worstNormalizedError);

        requireNear(
            prefix ~ "Y",
            ours.y,
            proj.b,
            generatedLinearTolerance(ours.y, proj.b),
            checks,
            worstNormalizedError);

        requireNear(
            prefix ~ "Z",
            ours.z,
            proj.c,
            generatedLinearTolerance(ours.z, proj.c),
            checks,
            worstNormalizedError);
    }
}


private void validateGeneratedHelmert(
    ref size_t checks,
    ref double worstNormalizedError)
{
    SplitMix64 rng = SplitMix64(0xD6E0_1033_A17E_2026UL);

    enum generatedCases = 64;

    foreach (i; 0 .. generatedCases)
    {
        const source =
            GeocentricCoordinate!double.fromComponents(
                rng.between(-100_000_000.0, 100_000_000.0),
                rng.between(-100_000_000.0, 100_000_000.0),
                rng.between(-100_000_000.0, 100_000_000.0));

        const tx = rng.between(-500.0, 500.0);
        const ty = rng.between(-500.0, 500.0);
        const tz = rng.between(-500.0, 500.0);

        const rx = rng.between(-5.0, 5.0);
        const ry = rng.between(-5.0, 5.0);
        const rz = rng.between(-5.0, 5.0);

        const scalePpm = rng.between(-25.0, 25.0);

        const pv =
            PositionVectorHelmert!double.fromArcSecondsAndPpm(
                tx, ty, tz,
                rx, ry, rz,
                scalePpm);

        const cf =
            CoordinateFrameHelmert!double.fromArcSecondsAndPpm(
                tx, ty, tz,
                -rx, -ry, -rz,
                scalePpm);

        const pvOperation = format(
            "+proj=helmert "
            ~ "+x=%.17g +y=%.17g +z=%.17g "
            ~ "+rx=%.17g +ry=%.17g +rz=%.17g "
            ~ "+s=%.17g +convention=position_vector",
            tx, ty, tz,
            rx, ry, rz,
            scalePpm);

        const cfOperation = format(
            "+proj=helmert "
            ~ "+x=%.17g +y=%.17g +z=%.17g "
            ~ "+rx=%.17g +ry=%.17g +rz=%.17g "
            ~ "+s=%.17g +convention=coordinate_frame",
            tx, ty, tz,
            -rx, -ry, -rz,
            scalePpm);

        const oursPv =
            applyPositionVectorHelmert(source, pv);
        const oursCf =
            applyCoordinateFrameHelmert(source, cf);

        const projPv =
            runCct(
                pvOperation,
                false,
                source.x,
                source.y,
                source.z);

        const projCf =
            runCct(
                cfOperation,
                false,
                source.x,
                source.y,
                source.z);

        const prefixPv =
            format("generated EPSG1033 case %s ", i);
        const prefixCf =
            format("generated EPSG1032 case %s ", i);

        requireNear(
            prefixPv ~ "X",
            oursPv.x,
            projPv.a,
            generatedLinearTolerance(oursPv.x, projPv.a),
            checks,
            worstNormalizedError);
        requireNear(
            prefixPv ~ "Y",
            oursPv.y,
            projPv.b,
            generatedLinearTolerance(oursPv.y, projPv.b),
            checks,
            worstNormalizedError);
        requireNear(
            prefixPv ~ "Z",
            oursPv.z,
            projPv.c,
            generatedLinearTolerance(oursPv.z, projPv.c),
            checks,
            worstNormalizedError);

        requireNear(
            prefixCf ~ "X",
            oursCf.x,
            projCf.a,
            generatedLinearTolerance(oursCf.x, projCf.a),
            checks,
            worstNormalizedError);
        requireNear(
            prefixCf ~ "Y",
            oursCf.y,
            projCf.b,
            generatedLinearTolerance(oursCf.y, projCf.b),
            checks,
            worstNormalizedError);
        requireNear(
            prefixCf ~ "Z",
            oursCf.z,
            projCf.c,
            generatedLinearTolerance(oursCf.z, projCf.c),
            checks,
            worstNormalizedError);

        // Independent convention-equivalence property.
        requireNear(
            prefixPv ~ "vs Coordinate Frame X",
            oursPv.x,
            oursCf.x,
            1.0e-9,
            checks,
            worstNormalizedError);
        requireNear(
            prefixPv ~ "vs Coordinate Frame Y",
            oursPv.y,
            oursCf.y,
            1.0e-9,
            checks,
            worstNormalizedError);
        requireNear(
            prefixPv ~ "vs Coordinate Frame Z",
            oursPv.z,
            oursCf.z,
            1.0e-9,
            checks,
            worstNormalizedError);
    }
}


int main(string[] args)
{

    bool extended = false;

    if (args.length == 2 && args[1] == "--extended")
        extended = true;
    else if (args.length != 1)
    {
        writeln("usage: proj-crosscheck [--extended]");
        return 2;
    }


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


        if (extended)
        {
            validateGeneratedGeographicGeocentric(
                checks,
                worstNormalizedError);

            validateGeneratedGeocentricTranslation(
                checks,
                worstNormalizedError);

            validateGeneratedHelmert(
                checks,
                worstNormalizedError);
        }
    }
    catch (Exception error)
    {
        writefln("FAIL after %s comparisons: %s", checks, error.msg);
        return 1;
    }

    writefln(
        "suite: %s",
        extended ? "extended fixed-seed differential suite" : "smoke differential suite");

    writefln(
        "PASS: %s geodesy-d vs PROJ scalar comparisons",
        checks);
    writefln(
        "worst normalized error: %.6f of configured tolerance",
        worstNormalizedError);

    return 0;
}
