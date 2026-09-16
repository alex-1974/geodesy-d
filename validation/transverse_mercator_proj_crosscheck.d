/**
 * Differential validation of geodesy-d Transverse Mercator against PROJ `cct`.
 *
 * This is an external validation probe, not part of the library source tree.
 * PROJ is a validation oracle only and remains no build/runtime dependency.
 */
module transverse_mercator_proj_crosscheck;

import std.conv : to;
import std.format : format;
import std.math : isFinite, sqrt;
import std.process : executeShell;
import std.stdio : writefln, writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private struct ProjPoint
{
    double easting;
    double northing;
}


private struct Metrics
{
    size_t checks;
    double worstNormalizedError;
    double worstAbsoluteError;
    string worstLabel;
}


private ProjPoint runProjForward(
    const string operation,
    const double longitudeDegrees,
    const double latitudeDegrees)
{
    const command = format(
        "printf '%%s %%s 0 0\\n' '%.17g' '%.17g' | cct -d 12 %s",
        longitudeDegrees,
        latitudeDegrees,
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
    if (fields.length < 2)
        throw new Exception(
            "unexpected cct output: " ~ output.output);

    try
    {
        return ProjPoint(
            fields[0].to!double,
            fields[1].to!double);
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


private string projOperation(
    const string ellipsoidParameters,
    const double latitudeOfNaturalOrigin,
    const double longitudeOfNaturalOrigin,
    const double scaleFactorAtNaturalOrigin,
    const double falseEasting,
    const double falseNorthing)
{
    /*
     * Geographic coordinates enter cct in degrees. The unit conversion is
     * explicit so the tmerc step receives radians.
     *
     * `poder_engsager` forces PROJ's deterministic high-accuracy extended
     * Transverse Mercator implementation rather than an approximate/auto path.
     */
    return format(
        "+proj=pipeline "
        ~ "+step +proj=unitconvert +xy_in=deg +xy_out=rad "
        ~ "+step +proj=tmerc +algo=poder_engsager "
        ~ "+lat_0=%.17g +lon_0=%.17g +k_0=%.17g "
        ~ "+x_0=%.17g +y_0=%.17g %s",
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        scaleFactorAtNaturalOrigin,
        falseEasting,
        falseNorthing,
        ellipsoidParameters);
}


private void requireProjectedNear(
    const string label,
    const double actualEasting,
    const double actualNorthing,
    const ProjPoint reference,
    const double tolerance,
    ref Metrics metrics)
{
    if (!isFinite(actualEasting)
        || !isFinite(actualNorthing)
        || !isFinite(reference.easting)
        || !isFinite(reference.northing))
        throw new Exception(
            label ~ ": non-finite projected comparison value");

    const double deltaEasting =
        actualEasting - reference.easting;
    const double deltaNorthing =
        actualNorthing - reference.northing;
    const double error =
        sqrt(deltaEasting * deltaEasting
            + deltaNorthing * deltaNorthing);

    if (!isFinite(error))
        throw new Exception(
            label ~ ": non-finite projected error");

    const double normalized =
        tolerance > 0.0 ? error / tolerance : error;

    ++metrics.checks;

    if (normalized > metrics.worstNormalizedError)
    {
        metrics.worstNormalizedError = normalized;
        metrics.worstAbsoluteError = error;
        metrics.worstLabel = label;
    }

    if (error > tolerance)
        throw new Exception(
            format(
                "%s: dE=%.17g dN=%.17g "
                ~ "positionError=%.17g tolerance=%.17g",
                label,
                deltaEasting,
                deltaNorthing,
                error,
                tolerance));
}


private string reverseFailureDiagnostic(
    const TransverseMercator!double projection,
    const string operation,
    const double latitudeDegrees,
    const double longitudeDegrees)
{
    const double centerLongitude =
        projection.longitudeOfNaturalOrigin.degrees;
    const double rawDelta =
        longitudeDegrees - centerLongitude;

    /*
     * First distinguish a general inverse failure from a boundary-classifying
     * failure caused by an independently generated projected coordinate.
     */
    const source =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitudeDegrees),
            Longitude!double.fromDegrees(longitudeDegrees));

    const selfProjected = projection.forward(source);
    GeographicCoordinate!double selfReverse;
    const bool selfAccepted =
        projection.tryReverse(selfProjected, selfReverse);

    const double inwardDirection =
        rawDelta < 0.0 ? 1.0 : -1.0;

    const double[] insetsDegrees = [
        1.0e-12,
        1.0e-11,
        1.0e-10,
        1.0e-9,
        1.0e-8,
        1.0e-7,
        1.0e-6,
    ];

    foreach (const inset; insetsDegrees)
    {
        const double candidateLongitude =
            longitudeDegrees + inwardDirection * inset;

        const candidateProjected =
            runProjForward(
                operation,
                candidateLongitude,
                latitudeDegrees);

        GeographicCoordinate!double recovered;
        const bool accepted =
            projection.tryReverse(
                ProjectedCoordinate!double.fromComponents(
                    candidateProjected.easting,
                    candidateProjected.northing),
                recovered);

        if (accepted)
            return format(
                "self-forward reverse accepted=%s; "
                ~ "first accepted PROJ inward inset=%.17g deg",
                selfAccepted,
                inset);
    }

    return format(
        "self-forward reverse accepted=%s; "
        ~ "no PROJ inward inset through 1e-6 deg was accepted",
        selfAccepted);
}


private void validatePoint(
    const string label,
    const TransverseMercator!double projection,
    const string operation,
    const double latitudeDegrees,
    const double longitudeDegrees,
    const double tolerance,
    ref Metrics metrics)
{
    const geographic =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitudeDegrees),
            Longitude!double.fromDegrees(longitudeDegrees));

    /*
     * Forward differential validation:
     * geodesy-d and PROJ start from the same geographic coordinate.
     */
    const oursForward = projection.forward(geographic);
    const projForward = runProjForward(
        operation,
        longitudeDegrees,
        latitudeDegrees);

    requireProjectedNear(
        label ~ " forward",
        oursForward.easting,
        oursForward.northing,
        projForward,
        tolerance,
        metrics);

    /*
     * Reverse differential validation without self-roundtrip:
     *
     *  1. PROJ independently creates the projected input.
     *  2. geodesy-d reverses that projected coordinate.
     *  3. PROJ independently forwards geodesy-d's returned geographic value.
     *  4. The represented projected positions are compared.
     *
     * geodesy-d's forward operation is not used for this reverse metric.
     */
    GeographicCoordinate!double oursReverse;
    if (!projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(
                projForward.easting,
                projForward.northing),
            oursReverse))
        throw new Exception(
            format(
                "%s reverse failed: source lat=%.17g lon=%.17g; "
                ~ "PROJ E=%.17g N=%.17g; %s",
                label,
                latitudeDegrees,
                longitudeDegrees,
                projForward.easting,
                projForward.northing,
                reverseFailureDiagnostic(
                    projection,
                    operation,
                    latitudeDegrees,
                    longitudeDegrees)));

    const representedByProj =
        runProjForward(
            operation,
            oursReverse.longitude.degrees,
            oursReverse.latitude.degrees);

    requireProjectedNear(
        label ~ " reverse represented position",
        representedByProj.easting,
        representedByProj.northing,
        projForward,
        tolerance,
        metrics);
}


private void validateSmoke(ref Metrics metrics)
{
    struct GeographicCase
    {
        double latitude;
        double longitude;
    }

    const wgsProjection =
        TransverseMercator!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(15.0),
            0.9996,
            500_000.0,
            0.0);

    const wgsOperation =
        projOperation(
            "+a=6378137 +rf=298.257223563",
            0.0,
            15.0,
            0.9996,
            500_000.0,
            0.0);

    const wgsCases = [
        GeographicCase(  0.0,  15.0),
        GeographicCase(  0.0,  12.0),
        GeographicCase(  0.0,  18.0),
        GeographicCase( 45.0,  12.0),
        GeographicCase( 45.0,  18.0),
        GeographicCase( 80.0,  15.0),
        GeographicCase( 45.0,  50.0),  // +35 deg
        GeographicCase( 45.0, -20.0),  // -35 deg
        GeographicCase( 80.0,  70.0),  // +55 deg
        GeographicCase(-80.0, -40.0),  // -55 deg
        GeographicCase( 45.0,  75.0),  // +60 deg boundary
        GeographicCase(-45.0, -45.0),  // -60 deg boundary
    ];

    foreach (index, test; wgsCases)
        validatePoint(
            format("EPSG9807 WGS84 smoke case %s", index),
            wgsProjection,
            wgsOperation,
            test.latitude,
            test.longitude,
            1.0e-4, // 0.1 mm smoke gate
            metrics);

    // Non-zero latitude of natural origin and false offsets.
    const airy =
        Ellipsoid!double.fromInverseFlattening(
            6_377_563.396,
            299.3249646);

    const britishGrid =
        TransverseMercator!double.fromParameters(
            airy,
            Latitude!double.fromDegrees(49.0),
            Longitude!double.fromDegrees(-2.0),
            0.9996012717,
            400_000.0,
            -100_000.0);

    const britishOperation =
        projOperation(
            "+a=6377563.396 +rf=299.3249646",
            49.0,
            -2.0,
            0.9996012717,
            400_000.0,
            -100_000.0);

    validatePoint(
        "EPSG9807 Airy non-zero natural origin",
        britishGrid,
        britishOperation,
        50.5,
        0.5,
        1.0e-4,
        metrics);

    // Antimeridian-adjacent natural origin.
    const antimeridianProjection =
        TransverseMercator!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(179.75),
            1.0,
            0.0,
            0.0);

    const antimeridianOperation =
        projOperation(
            "+a=6378137 +rf=298.257223563",
            0.0,
            179.75,
            1.0,
            0.0,
            0.0);

    validatePoint(
        "EPSG9807 antimeridian normalization",
        antimeridianProjection,
        antimeridianOperation,
        20.0,
        -179.75,
        1.0e-4,
        metrics);

    // Spherical limit.
    const sphereProjection =
        TransverseMercator!double.fromParameters(
            Ellipsoid!double.sphere(6_371_000.0),
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0),
            1.0,
            0.0,
            0.0);

    const sphereOperation =
        projOperation(
            "+a=6371000 +b=6371000",
            0.0,
            0.0,
            1.0,
            0.0,
            0.0);

    validatePoint(
        "EPSG9807 spherical limit",
        sphereProjection,
        sphereOperation,
        45.0,
        35.0,
        1.0e-4,
        metrics);

    // ADR-0006 projection-specific flattening boundary.
    const boundaryEllipsoid =
        Ellipsoid!double.fromFlattening(
            6_378_137.0,
            0.01);

    const boundaryProjection =
        TransverseMercator!double.fromParameters(
            boundaryEllipsoid,
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(15.0),
            1.0,
            0.0,
            0.0);

    const boundaryOperation =
        projOperation(
            "+a=6378137 +f=0.01",
            0.0,
            15.0,
            1.0,
            0.0,
            0.0);

    validatePoint(
        "EPSG9807 f=0.01 boundary ellipsoid",
        boundaryProjection,
        boundaryOperation,
        80.0,
        70.0,
        1.0e-3,
        metrics);
}


private void validateExtended(ref Metrics metrics)
{
    struct EllipsoidCase
    {
        string name;
        Ellipsoid!double ellipsoid;
        string projParameters;
    }

    const ellipsoids = [
        EllipsoidCase(
            "WGS84",
            wgs84!double(),
            "+a=6378137 +rf=298.257223563"),
        EllipsoidCase(
            "GRS80",
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257222101),
            "+a=6378137 +rf=298.257222101"),
        EllipsoidCase(
            "Airy1830",
            Ellipsoid!double.fromInverseFlattening(
                6_377_563.396,
                299.3249646),
            "+a=6377563.396 +rf=299.3249646"),
        EllipsoidCase(
            "Bessel1841",
            Ellipsoid!double.fromInverseFlattening(
                6_377_397.155,
                299.1528128),
            "+a=6377397.155 +rf=299.1528128"),
        EllipsoidCase(
            "Clarke1866",
            Ellipsoid!double.fromAxes(
                6_378_206.4,
                6_356_583.8),
            "+a=6378206.4 +b=6356583.8"),
        EllipsoidCase(
            "International1924",
            Ellipsoid!double.fromInverseFlattening(
                6_378_388.0,
                297.0),
            "+a=6378388 +rf=297"),
        EllipsoidCase(
            "Sphere6371km",
            Ellipsoid!double.sphere(6_371_000.0),
            "+a=6371000 +b=6371000"),
        EllipsoidCase(
            "SyntheticF001",
            Ellipsoid!double.fromFlattening(
                6_378_137.0,
                0.01),
            "+a=6378137 +f=0.01"),
    ];

    const latitudes = [
        -85.0,
        -80.0,
        -45.0,
        -1.0,
        0.0,
        1.0,
        45.0,
        80.0,
        85.0,
    ];

    const deltaLongitudes = [
        -60.0,
        -55.0,
        -35.0,
        -3.0,
        0.0,
        3.0,
        35.0,
        55.0,
        60.0,
    ];

    foreach (ellipsoidIndex, ellipsoidCase; ellipsoids)
    {
        double latitudeOfNaturalOrigin;
        double scaleFactor;
        double falseEasting;
        double falseNorthing;

        final switch (ellipsoidIndex % 3)
        {
            case 0:
                latitudeOfNaturalOrigin = 0.0;
                scaleFactor = 1.0;
                falseEasting = 0.0;
                falseNorthing = 0.0;
                break;

            case 1:
                latitudeOfNaturalOrigin = 49.0;
                scaleFactor = 0.9996;
                falseEasting = 500_000.0;
                falseNorthing = 0.0;
                break;

            case 2:
                latitudeOfNaturalOrigin = -35.0;
                scaleFactor = 0.9999;
                falseEasting = -2_000_000.0;
                falseNorthing = 3_000_000.0;
                break;
        }

        const double longitudeOfNaturalOrigin = 15.0;

        const projection =
            TransverseMercator!double.fromParameters(
                ellipsoidCase.ellipsoid,
                Latitude!double.fromDegrees(
                    latitudeOfNaturalOrigin),
                Longitude!double.fromDegrees(
                    longitudeOfNaturalOrigin),
                scaleFactor,
                falseEasting,
                falseNorthing);

        const operation =
            projOperation(
                ellipsoidCase.projParameters,
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                scaleFactor,
                falseEasting,
                falseNorthing);

        foreach (latitudeIndex, latitude; latitudes)
        {
            foreach (deltaIndex, deltaLongitude; deltaLongitudes)
            {
                const double longitude =
                    longitudeOfNaturalOrigin + deltaLongitude;

                /*
                 * PROJ's Poder/Engsager path is sixth order.  The production
                 * geodesy-d double path is eighth order after Exact-reference
                 * validation showed that sixth order exceeds the 1 mm target
                 * on the synthetic f=0.01 wide-domain stress cases.
                 *
                 * Keep a tight 1 mm compatibility tolerance for all ordinary
                 * reference ellipsoids and the sphere.  For SyntheticF001 use
                 * a 5 cm same-family compatibility envelope: this is not an
                 * accuracy contract; GeographicLib Exact is the accuracy
                 * oracle for these stress points.
                 */
                const double compatibilityTolerance =
                    ellipsoidCase.name == "SyntheticF001"
                        ? 5.0e-2
                        : 1.0e-3;

                validatePoint(
                    format(
                        "generated EPSG9807 %s lat[%s] dlon[%s]",
                        ellipsoidCase.name,
                        latitudeIndex,
                        deltaIndex),
                    projection,
                    operation,
                    latitude,
                    longitude,
                    compatibilityTolerance,
                    metrics);
            }
        }
    }
}


int main(string[] args)
{
    bool extended = false;

    if (args.length == 2 && args[1] == "--extended")
        extended = true;
    else if (args.length != 1)
    {
        writeln("usage: transverse-mercator-proj-crosscheck [--extended]");
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

    Metrics metrics = Metrics(0, 0.0, 0.0, "");

    try
    {
        validateSmoke(metrics);

        if (extended)
            validateExtended(metrics);
    }
    catch (Exception error)
    {
        writefln(
            "FAIL after %s projected-position comparisons: %s",
            metrics.checks,
            error.msg);

        if (metrics.worstLabel.length != 0)
            writefln(
                "worst prior case: %s; %.9g m; %.6f of tolerance",
                metrics.worstLabel,
                metrics.worstAbsoluteError,
                metrics.worstNormalizedError);

        return 1;
    }

    writefln(
        "suite: %s",
        extended
            ? "extended deterministic EPSG9807 compatibility suite"
            : "EPSG9807 smoke differential suite");

    if (extended)
        writeln(
            "note: SyntheticF001 uses a 0.05 m PROJ order-6 compatibility "
            ~ "envelope; GeographicLib Exact is the accuracy oracle");

    writefln(
        "PASS: %s geodesy-d vs PROJ projected-position comparisons",
        metrics.checks);

    writefln(
        "worst absolute projected error: %.9g m",
        metrics.worstAbsoluteError);

    writefln(
        "worst normalized error: %.6f of configured tolerance",
        metrics.worstNormalizedError);

    writefln(
        "worst case: %s",
        metrics.worstLabel);

    return 0;
}
