module transverse_mercator_real_validation;

/*
 * TM-D validation for public D `real`.
 *
 * This validator deliberately separates two reference roles:
 *
 * 1. GeographicLib TransverseMercatorProj from the system installation is
 *    binary64 (GEOGRAPHICLIB_PRECISION=2 on the reference development host).
 *    It is used as an independent Exact-TM oracle for the public 1 mm
 *    contract, with binary64-compatible source inputs.
 *
 * 2. The spherical oracle below is evaluated entirely in D `real`.  It is
 *    used to exercise the wider-than-double arithmetic path without reducing
 *    inputs or oracle values to binary64.
 *
 * A separate precision-preservation probe verifies that TransverseMercator!real
 * distinguishes source longitudes which collapse to the same `double`.
 */

import std.conv : to;
import std.file : exists, remove;
import std.format : format;
import std.math :
    PI,
    asinh,
    atan2,
    cos,
    fabs,
    isFinite,
    sin,
    sinh,
    sqrt;
import std.process : executeShell;
import std.stdio : File, writefln, writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;

private enum real targetMetres = 1.0e-3L;
private enum ulong randomSeed = 0x544D5F5245414C31UL; // "TM_REAL1"


private struct ProjectionSpec
{
    string name;
    real a;
    real f;
    real latitudeOfNaturalOrigin;
    real longitudeOfNaturalOrigin;
    real scaleFactorAtNaturalOrigin;
    real falseEasting;
    real falseNorthing;
}


private struct SourcePoint
{
    real latitude;
    real deltaLongitude;
}


private struct OracleSpec
{
    real radius;
    real latitudeOfNaturalOriginRadians;
    real longitudeOfNaturalOriginRadians;
    real scaleFactorAtNaturalOrigin;
    real falseEasting;
    real falseNorthing;
}


private struct OracleProjected
{
    real easting;
    real northing;
    real scale;
}


private struct RealContext
{
    TransverseMercator!real projection;
    OracleSpec oracle;
}


private struct ReferencePoint
{
    real easting;
    real northing;
    real scale;
    bool reverseAccepted;
}


private struct Metrics
{
    size_t forwardComparisons;
    size_t reverseComparisons;
    size_t failures;

    real worstAbsoluteError;
    string worstAbsoluteCase;

    real worstGroundEquivalentError;
    string worstGroundEquivalentCase;
}


private Metrics makeMetrics()
{
    return Metrics(
        0,
        0,
        0,
        0.0L,
        "",
        0.0L,
        "");
}


private real sq(const real x)
{
    return x * x;
}


private real hypot2(const real x, const real y)
{
    return sqrt(sq(x) + sq(y));
}


private real degreesFromRadians(const real radians)
{
    return radians * (180.0L / cast(real) PI);
}


private real normalizeRadians(real value)
{
    const real pi = cast(real) PI;
    const real twoPi = 2.0L * pi;

    while (value > pi)
        value -= twoPi;
    while (value < -pi)
        value += twoPi;

    return value;
}


private real normalizeDegrees(real value)
{
    while (value > 180.0L)
        value -= 360.0L;
    while (value < -180.0L)
        value += 360.0L;

    return value;
}


private int realPoleSign(const Latitude!real latitude)
{
    const north = Latitude!real.fromDegrees(90.0L);
    const south = Latitude!real.fromDegrees(-90.0L);

    if (latitude == north)
        return 1;
    if (latitude == south)
        return -1;

    return 0;
}


private void recordComparison(
    const string label,
    const bool forward,
    const real actualEasting,
    const real actualNorthing,
    const real referenceEasting,
    const real referenceNorthing,
    const real referenceScale,
    ref Metrics metrics)
{
    if (forward)
        ++metrics.forwardComparisons;
    else
        ++metrics.reverseComparisons;

    const real deltaEasting =
        actualEasting - referenceEasting;
    const real deltaNorthing =
        actualNorthing - referenceNorthing;

    const real absoluteError =
        hypot2(deltaEasting, deltaNorthing);

    const real groundEquivalentError =
        referenceScale > 0.0L
            ? absoluteError / referenceScale
            : real.infinity;

    if (absoluteError > metrics.worstAbsoluteError)
    {
        metrics.worstAbsoluteError = absoluteError;
        metrics.worstAbsoluteCase = label;
    }

    if (groundEquivalentError > metrics.worstGroundEquivalentError)
    {
        metrics.worstGroundEquivalentError = groundEquivalentError;
        metrics.worstGroundEquivalentCase = label;
    }

    if (!(isFinite(absoluteError)
            && isFinite(groundEquivalentError))
        || absoluteError > targetMetres
        || groundEquivalentError > targetMetres)
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s abs=%.15g m ground=%.15g m",
                label,
                absoluteError,
                groundEquivalentError);
    }
}


private void printMetrics(
    const string suite,
    const Metrics metrics)
{
    writeln;
    writefln("suite: %s", suite);
    writefln(
        "forward comparisons: %s",
        metrics.forwardComparisons);
    writefln(
        "reverse comparisons: %s",
        metrics.reverseComparisons);
    writefln(
        "outside 0.001 m target: %s",
        metrics.failures);
    writefln(
        "worst absolute projected error: %.15g m",
        metrics.worstAbsoluteError);
    writefln(
        "worst absolute case: %s",
        metrics.worstAbsoluteCase);
    writefln(
        "worst ground-equivalent error: %.15g m",
        metrics.worstGroundEquivalentError);
    writefln(
        "worst ground-equivalent case: %s",
        metrics.worstGroundEquivalentCase);
    writefln(
        "RESULT: %s",
        metrics.failures == 0 ? "PASS" : "FAIL");
}


/*
 * Independent closed-form spherical Transverse Mercator evaluated in real.
 *
 *   q   = hypot(sin(phi), cos(phi) cos(lambda))
 *   xi  = atan2(sin(phi), cos(phi) cos(lambda))
 *   eta = asinh(cos(phi) sin(lambda) / q)
 *
 *   E = FE + k0 R eta
 *   N = FN + k0 R (xi - phi0)
 *   k = k0 / q
 */
private OracleProjected sphereForward(
    const OracleSpec spec,
    const real latitudeRadians,
    const real longitudeRadians,
    const bool clampRepresentedBoundary,
    const int poleSign = 0)
{
    real deltaLongitude =
        normalizeRadians(
            longitudeRadians
            - spec.longitudeOfNaturalOriginRadians);

    if (clampRepresentedBoundary)
    {
        const real maxDelta = cast(real) PI / 3.0L;

        if (fabs(deltaLongitude) > maxDelta)
            deltaLongitude =
                deltaLongitude < 0.0L
                    ? -maxDelta
                    : maxDelta;
    }

    if (poleSign != 0)
    {
        const real poleLatitude =
            poleSign < 0
                ? -cast(real) PI / 2.0L
                : cast(real) PI / 2.0L;

        return OracleProjected(
            spec.falseEasting,
            spec.falseNorthing
                + spec.scaleFactorAtNaturalOrigin
                    * spec.radius
                    * (
                        poleLatitude
                        - spec.latitudeOfNaturalOriginRadians),
            spec.scaleFactorAtNaturalOrigin);
    }

    const real sinLatitude = sin(latitudeRadians);
    const real cosLatitude = cos(latitudeRadians);
    const real sinDelta = sin(deltaLongitude);
    const real cosDelta = cos(deltaLongitude);

    const real q =
        hypot2(
            sinLatitude,
            cosLatitude * cosDelta);

    const real xi =
        atan2(
            sinLatitude,
            cosLatitude * cosDelta);

    const real eta =
        asinh(
            cosLatitude * sinDelta / q);

    return OracleProjected(
        spec.falseEasting
            + spec.scaleFactorAtNaturalOrigin
                * spec.radius
                * eta,
        spec.falseNorthing
            + spec.scaleFactorAtNaturalOrigin
                * spec.radius
                * (
                    xi
                    - spec.latitudeOfNaturalOriginRadians),
        spec.scaleFactorAtNaturalOrigin / q);
}


private RealContext makeSphereContext(const ProjectionSpec source)
{
    const latitudeOfNaturalOrigin =
        Latitude!real.fromDegrees(
            source.latitudeOfNaturalOrigin);

    const longitudeOfNaturalOrigin =
        Longitude!real.fromDegrees(
            source.longitudeOfNaturalOrigin);

    return RealContext(
        TransverseMercator!real.fromParameters(
            Ellipsoid!real.fromFlattening(
                source.a,
                0.0L),
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            source.scaleFactorAtNaturalOrigin,
            source.falseEasting,
            source.falseNorthing),
        OracleSpec(
            source.a,
            latitudeOfNaturalOrigin.radians,
            longitudeOfNaturalOrigin.radians,
            source.scaleFactorAtNaturalOrigin,
            source.falseEasting,
            source.falseNorthing));
}


private ProjectionSpec[] sphereSpecs()
{
    return [
        ProjectionSpec(
            "Sphere-R6378137-equatorial",
            6_378_137.0L,
            0.0L,
            0.0L, 15.0L, 1.0L, 0.0L, 0.0L),

        ProjectionSpec(
            "Sphere-R6371000-OSGB-origin",
            6_371_000.0L,
            0.0L,
            49.0L, -2.0L, 0.9996L, 500_000.0L, 0.0L),

        ProjectionSpec(
            "Sphere-R6378137-antimeridian-north",
            6_378_137.0L,
            0.0L,
            -35.0L, 179.75L, 0.9999L, -2_000_000.0L, 3_000_000.0L),

        ProjectionSpec(
            "Sphere-R6371000-high-north-origin",
            6_371_000.0L,
            0.0L,
            80.0L, 15.0L, 1.0L, 0.0L, 0.0L),

        ProjectionSpec(
            "Sphere-R6371000-high-south-origin",
            6_371_000.0L,
            0.0L,
            -80.0L, 15.0L, 1.0L, 0.0L, 0.0L),

        ProjectionSpec(
            "Sphere-R6000000-profile-min",
            6_000_000.0L,
            0.0L,
            20.0L, -120.0L, 0.9L, -12_000_000.0L, 12_000_000.0L),

        ProjectionSpec(
            "Sphere-R7000000-profile-max",
            7_000_000.0L,
            0.0L,
            -20.0L, 120.0L, 1.1L, 14_000_000.0L, -14_000_000.0L),

        ProjectionSpec(
            "Sphere-R6378137-UTM-like",
            6_378_137.0L,
            0.0L,
            0.0L, -177.0L, 0.9996L, 500_000.0L, 10_000_000.0L),
    ];
}


private void validateSpherePoint(
    const ProjectionSpec source,
    const RealContext context,
    const SourcePoint point,
    const size_t index,
    ref Metrics metrics)
{
    const real sourceLongitude =
        normalizeDegrees(
            source.longitudeOfNaturalOrigin
            + point.deltaLongitude);

    const latitude =
        Latitude!real.fromDegrees(point.latitude);

    const longitude =
        Longitude!real.fromDegrees(sourceLongitude);

    const geographic =
        GeographicCoordinate!real.fromComponents(
            latitude,
            longitude);

    const reference =
        sphereForward(
            context.oracle,
            latitude.radians,
            longitude.radians,
            true,
            realPoleSign(latitude));

    ProjectedCoordinate!real projected;

    if (!context.projection.tryForward(
            geographic,
            projected))
    {
        ++metrics.forwardComparisons;
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] real forward rejected",
                source.name,
                index);

        return;
    }

    recordComparison(
        format(
            "%s point[%s] lat=%.18g dlon=%.18g real forward",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        true,
        projected.easting,
        projected.northing,
        reference.easting,
        reference.northing,
        reference.scale,
        metrics);

    const representedProjected =
        ProjectedCoordinate!real.fromComponents(
            reference.easting,
            reference.northing);

    GeographicCoordinate!real recovered;

    if (!context.projection.tryReverse(
            representedProjected,
            recovered))
    {
        ++metrics.reverseComparisons;
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] real reverse rejected",
                source.name,
                index);

        return;
    }

    const reverseReference =
        sphereForward(
            context.oracle,
            recovered.latitude.radians,
            recovered.longitude.radians,
            false,
            realPoleSign(recovered.latitude));

    recordComparison(
        format(
            "%s point[%s] lat=%.18g dlon=%.18g real reverse",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        false,
        reverseReference.easting,
        reverseReference.northing,
        representedProjected.easting,
        representedProjected.northing,
        reverseReference.scale,
        metrics);
}


private struct SplitMix64
{
    ulong state;

    ulong next()
    {
        state += 0x9E3779B97F4A7C15UL;

        ulong z = state;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }

    /*
     * Full-width real fraction.  On the validated x86_64 platform real has a
     * 64-bit mantissa, so unlike the existing double generator this does not
     * intentionally discard the low 11 random bits.
     */
    real unitReal()
    {
        return cast(real) next()
            * (1.0L / 18_446_744_073_709_551_616.0L);
    }

    /*
     * Binary64-compatible fraction for the GeographicLib Exact contract gate.
     * Both the D production point and the external reference receive the same
     * 53-bit source value.
     */
    real unitBinary64()
    {
        const double value =
            cast(double) (next() >> 11)
                * (1.0 / 9_007_199_254_740_992.0);

        return cast(real) value;
    }
}


private SourcePoint randomSpherePoint(ref SplitMix64 rng)
{
    return SourcePoint(
        -90.0L + 180.0L * rng.unitReal(),
        -60.0L + 120.0L * rng.unitReal());
}


private SourcePoint randomExactPoint(ref SplitMix64 rng)
{
    return SourcePoint(
        -90.0L + 180.0L * rng.unitBinary64(),
        -60.0L + 120.0L * rng.unitBinary64());
}


private void runSphereStructured()
{
    Metrics metrics = makeMetrics();
    size_t index;

    foreach (source; sphereSpecs())
    {
        const context = makeSphereContext(source);

        foreach (latitudeIndex; -90 .. 91)
        {
            const real latitude =
                cast(real) latitudeIndex;

            foreach (deltaIndex; -100 .. 101)
            {
                const real deltaLongitude =
                    cast(real) deltaIndex * 0.6L;

                validateSpherePoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics);
            }
        }

        foreach (latitude; [
            -89.999999999999L,
            -89.999999L,
            -89.999L,
            -85.0L,
            -80.0L,
            -1.0e-12L,
            -0.0L,
            0.0L,
            1.0e-12L,
            80.0L,
            85.0L,
            89.999L,
            89.999999L,
            89.999999999999L])
        {
            foreach (deltaLongitude; [
                -60.0L,
                -59.999999999999L,
                -59.999999L,
                -3.0L,
                -1.0e-12L,
                0.0L,
                1.0e-12L,
                3.0L,
                59.999999L,
                59.999999999999L,
                60.0L])
            {
                validateSpherePoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics);
            }
        }

        writefln(
            "completed %-36s %s real source points",
            source.name ~ ":",
            index);
    }

    printMetrics(
        "large structured analytic spherical TM real corpus",
        metrics);

    if (metrics.failures != 0)
        throw new Exception(
            "real spherical TM structured validation failed");
}


private void runSphereRandom(const size_t count)
{
    Metrics metrics = makeMetrics();
    auto rng = SplitMix64(randomSeed);
    const specs = sphereSpecs();

    RealContext[] contexts;
    contexts.reserve(specs.length);

    foreach (source; specs)
        contexts ~= makeSphereContext(source);

    foreach (index; 0 .. count)
    {
        const profileIndex = index % specs.length;

        validateSpherePoint(
            specs[profileIndex],
            contexts[profileIndex],
            randomSpherePoint(rng),
            index,
            metrics);
    }

    writefln(
        "deterministic real sphere random corpus seed: 0x%016X",
        randomSeed);
    writefln("projection profiles: %s", specs.length);
    writefln("requested source points: %s", count);

    printMetrics(
        "deterministic pseudo-random analytic spherical TM real corpus",
        metrics);

    if (metrics.failures != 0)
        throw new Exception(
            "real spherical TM random validation failed");
}


private string quoteShell(const string value)
{
    import std.string : indexOf;

    if (value.indexOf('\'') >= 0)
        throw new Exception(
            "unsupported apostrophe in validation path");

    return "'" ~ value ~ "'";
}


private ProjectionSpec[] exactBaseSpecs()
{
    return [
        ProjectionSpec(
            "WGS84",
            6_378_137.0L,
            1.0L / 298.257223563L,
            0.0L, 15.0L, 1.0L, 0.0L, 0.0L),

        ProjectionSpec(
            "GRS80",
            6_378_137.0L,
            1.0L / 298.257222101L,
            49.0L, 15.0L, 0.9996L, 500_000.0L, 0.0L),

        ProjectionSpec(
            "Airy1830",
            6_377_563.396L,
            1.0L / 299.3249646L,
            -35.0L, 15.0L, 0.9999L, -2_000_000.0L, 3_000_000.0L),

        ProjectionSpec(
            "Bessel1841",
            6_377_397.155L,
            1.0L / 299.1528128L,
            0.0L, 15.0L, 1.0L, 0.0L, 0.0L),

        ProjectionSpec(
            "Clarke1866",
            6_378_206.4L,
            (6_378_206.4L - 6_356_583.8L) / 6_378_206.4L,
            49.0L, 15.0L, 0.9996L, 500_000.0L, 0.0L),

        ProjectionSpec(
            "International1924",
            6_378_388.0L,
            1.0L / 297.0L,
            -35.0L, 15.0L, 0.9999L, -2_000_000.0L, 3_000_000.0L),

        ProjectionSpec(
            "SyntheticF001",
            6_378_137.0L,
            0.01L,
            49.0L, 15.0L, 0.9996L, 500_000.0L, 0.0L),
    ];
}


private TransverseMercator!real makeExactProjection(
    const ProjectionSpec spec)
{
    /*
     * Exercise the actual public real path with its real-valued parameters.
     *
     * The installed GeographicLib Exact oracle is binary64, so runExactBatch()
     * necessarily narrows the corresponding reference parameters to double.
     * Do not mirror that narrowing here: at the documented f = 0.01 boundary,
     * round-tripping 0.01L through double produces a real value slightly above
     * 0.01L and would turn a valid public-real parameter into an invalid one.
     *
     * The resulting reference-parameter quantization is many orders of
     * magnitude below the public 1 mm contract and is part of the explicitly
     * documented binary64-oracle limitation of this sub-gate.
     */
    return TransverseMercator!real.fromParameters(
        Ellipsoid!real.fromFlattening(
            spec.a,
            spec.f),
        Latitude!real.fromDegrees(
            spec.latitudeOfNaturalOrigin),
        Longitude!real.fromDegrees(
            spec.longitudeOfNaturalOrigin),
        spec.scaleFactorAtNaturalOrigin,
        spec.falseEasting,
        spec.falseNorthing);
}


private real exactOriginNorthing(
    const ProjectionSpec spec)
{
    const command = format(
        "printf '%%s %%s\\n' '%.17f' '%.17f' | "
        ~ "TransverseMercatorProj "
        ~ "-l '%.17f' -k '%.17f' -e '%.17f' '%.17f' -p 12",
        cast(double) spec.latitudeOfNaturalOrigin,
        cast(double) spec.longitudeOfNaturalOrigin,
        cast(double) spec.longitudeOfNaturalOrigin,
        cast(double) spec.scaleFactorAtNaturalOrigin,
        cast(double) spec.a,
        cast(double) spec.f);

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "TransverseMercatorProj origin query failed for %s: %s",
                spec.name,
                output.output));

    const fields = output.output.strip.split;

    if (fields.length < 2)
        throw new Exception(
            format(
                "unexpected GeographicLib origin output for %s: %s",
                spec.name,
                output.output));

    return fields[1].to!real;
}


private void runExactBatch(
    const ProjectionSpec spec,
    const string inputPath,
    const string outputPath)
{
    const command = format(
        "TransverseMercatorProj "
        ~ "-l %.17f -k %.17f -e %.17f %.17f -p 12 "
        ~ "--input-file %s --output-file %s",
        cast(double) spec.longitudeOfNaturalOrigin,
        cast(double) spec.scaleFactorAtNaturalOrigin,
        cast(double) spec.a,
        cast(double) spec.f,
        quoteShell(inputPath),
        quoteShell(outputPath));

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "TransverseMercatorProj batch failed for %s: %s",
                spec.name,
                output.output));
}


private void writeExactPoints(
    const string path,
    const ProjectionSpec spec,
    const SourcePoint[] points)
{
    auto file = File(path, "w");

    foreach (const point; points)
    {
        const real longitude =
            normalizeDegrees(
                spec.longitudeOfNaturalOrigin
                + point.deltaLongitude);

        /*
         * Exact contract mode intentionally gives GeographicLib and the D
         * production path the same binary64-compatible decimal source point.
         */
        file.writefln(
            "%.17f %.17f",
            cast(double) point.latitude,
            cast(double) longitude);
    }
}


private void validateExactSpec(
    const ProjectionSpec spec,
    const SourcePoint[] points,
    const string workDirectory,
    const size_t specIndex,
    ref Metrics metrics)
{
    const projection = makeExactProjection(spec);
    const originNorthing = exactOriginNorthing(spec);

    const forwardInput =
        format(
            "%s/real-exact-forward-%s.in",
            workDirectory,
            specIndex);
    const forwardOutput =
        format(
            "%s/real-exact-forward-%s.out",
            workDirectory,
            specIndex);
    const reverseInput =
        format(
            "%s/real-exact-reverse-%s.in",
            workDirectory,
            specIndex);
    const reverseOutput =
        format(
            "%s/real-exact-reverse-%s.out",
            workDirectory,
            specIndex);

    scope(exit)
    {
        foreach (path; [
            forwardInput,
            forwardOutput,
            reverseInput,
            reverseOutput])
        {
            if (exists(path))
                remove(path);
        }
    }

    writeExactPoints(
        forwardInput,
        spec,
        points);
    runExactBatch(
        spec,
        forwardInput,
        forwardOutput);

    ReferencePoint[] references;
    references.length = points.length;

    auto reverseFile = File(reverseInput, "w");
    auto forwardReferenceFile = File(forwardOutput, "r");

    size_t index;

    foreach (line; forwardReferenceFile.byLine())
    {
        if (index >= points.length)
            throw new Exception(
                format(
                    "too many GeographicLib forward rows for %s",
                    spec.name));

        const fields = line.to!string.strip.split;

        if (fields.length < 4)
            throw new Exception(
                format(
                    "invalid GeographicLib forward row for %s: %s",
                    spec.name,
                    line.to!string));

        const point = points[index];

        const real referenceEasting =
            spec.falseEasting
            + fields[0].to!real;

        const real referenceNorthing =
            spec.falseNorthing
            + fields[1].to!real
            - originNorthing;

        const real referenceScale =
            fields[3].to!real;

        const real longitude =
            normalizeDegrees(
                spec.longitudeOfNaturalOrigin
                + point.deltaLongitude);

        /*
         * Recreate the binary64-compatible source exactly as it was formatted
         * for the external oracle.
         */
        const real latitudeForBoth =
            cast(real) cast(double) point.latitude;
        const real longitudeForBoth =
            cast(real) cast(double) longitude;

        const geographic =
            GeographicCoordinate!real.fromComponents(
                Latitude!real.fromDegrees(
                    latitudeForBoth),
                Longitude!real.fromDegrees(
                    longitudeForBoth));

        const oursForward =
            projection.forward(geographic);

        recordComparison(
            format(
                "%s point[%s] lat=%.17f dlon=%.17f real forward",
                spec.name,
                index,
                cast(double) latitudeForBoth,
                cast(double) point.deltaLongitude),
            true,
            oursForward.easting,
            oursForward.northing,
            referenceEasting,
            referenceNorthing,
            referenceScale,
            metrics);

        GeographicCoordinate!real recovered;

        const reverseAccepted =
            projection.tryReverse(
                ProjectedCoordinate!real.fromComponents(
                    referenceEasting,
                    referenceNorthing),
                recovered);

        references[index] =
            ReferencePoint(
                referenceEasting,
                referenceNorthing,
                referenceScale,
                reverseAccepted);

        if (reverseAccepted)
        {
            reverseFile.writefln(
                "%.17f %.17f",
                cast(double) recovered.latitude.degrees,
                cast(double) recovered.longitude.degrees);
        }
        else
        {
            ++metrics.reverseComparisons;
            ++metrics.failures;

            if (metrics.failures <= 12)
                writefln(
                    "OUTSIDE TARGET: %s point[%s] real reverse rejected "
                    ~ "Exact projected coordinate",
                    spec.name,
                    index);

            reverseFile.writefln(
                "%.17f %.17f",
                cast(double) latitudeForBoth,
                cast(double) longitudeForBoth);
        }

        ++index;
    }

    reverseFile.close();
    forwardReferenceFile.close();

    if (index != points.length)
        throw new Exception(
            format(
                "GeographicLib forward row count mismatch for %s: %s vs %s",
                spec.name,
                index,
                points.length));

    runExactBatch(
        spec,
        reverseInput,
        reverseOutput);

    auto reverseReferenceFile = File(reverseOutput, "r");
    index = 0;

    foreach (line; reverseReferenceFile.byLine())
    {
        if (index >= references.length)
            throw new Exception(
                format(
                    "too many GeographicLib reverse rows for %s",
                    spec.name));

        const fields = line.to!string.strip.split;

        if (fields.length < 4)
            throw new Exception(
                format(
                    "invalid GeographicLib reverse row for %s: %s",
                    spec.name,
                    line.to!string));

        const reference = references[index];

        if (reference.reverseAccepted)
        {
            const real recoveredReferenceEasting =
                spec.falseEasting
                + fields[0].to!real;

            const real recoveredReferenceNorthing =
                spec.falseNorthing
                + fields[1].to!real
                - originNorthing;

            const real recoveredScale =
                fields[3].to!real;

            recordComparison(
                format(
                    "%s point[%s] real reverse",
                    spec.name,
                    index),
                false,
                recoveredReferenceEasting,
                recoveredReferenceNorthing,
                reference.easting,
                reference.northing,
                recoveredScale,
                metrics);
        }

        ++index;
    }

    reverseReferenceFile.close();

    if (index != references.length)
        throw new Exception(
            format(
                "GeographicLib reverse row count mismatch for %s: %s vs %s",
                spec.name,
                index,
                references.length));
}


private SourcePoint[] structuredExactPoints()
{
    SourcePoint[] points;
    points.reserve(40_000);

    foreach (latitudeIndex; -90 .. 91)
    {
        const real latitude =
            cast(real) latitudeIndex;

        foreach (deltaIndex; -100 .. 101)
        {
            const real deltaLongitude =
                cast(real) deltaIndex * 0.6L;

            points ~=
                SourcePoint(
                    cast(real) cast(double) latitude,
                    cast(real) cast(double) deltaLongitude);
        }
    }

    foreach (latitude; [
        -89.999999L,
        -89.999L,
        -85.0L,
        -80.0L,
        -1.0e-9L,
        -0.0L,
        0.0L,
        1.0e-9L,
        80.0L,
        85.0L,
        89.999L,
        89.999999L])
    {
        foreach (deltaLongitude; [
            -60.0L,
            -59.999999L,
            -3.0L,
            -1.0e-9L,
            0.0L,
            1.0e-9L,
            3.0L,
            59.999999L,
            60.0L])
        {
            points ~=
                SourcePoint(
                    cast(real) cast(double) latitude,
                    cast(real) cast(double) deltaLongitude);
        }
    }

    return points;
}


private ProjectionSpec randomExactProfile(
    const ProjectionSpec base,
    const size_t ellipsoidIndex,
    const size_t profileIndex)
{
    auto rng =
        SplitMix64(
            randomSeed
            ^ (cast(ulong) ellipsoidIndex << 32)
            ^ cast(ulong) profileIndex
            ^ 0x4558414354UL);

    /*
     * Keep the ellipsoid itself on the actual public-real path.
     * In particular, narrowing f = 0.01L through binary64 produces a value
     * slightly above the documented real upper bound after widening again.
     *
     * Random projection-origin/offset parameters below remain deliberately
     * binary64-compatible because the external Exact oracle is binary64.
     */
    const real a = base.a;
    const real f = base.f;

    return ProjectionSpec(
        format(
            "%s-R%02d",
            base.name,
            profileIndex),
        a,
        f,
        cast(real) cast(double)(
            -70.0L + 140.0L * rng.unitBinary64()),
        cast(real) cast(double)(
            -180.0L + 360.0L * rng.unitBinary64()),
        cast(real) cast(double)(
            0.9L + 0.2L * rng.unitBinary64()),
        cast(real) cast(double)(
            (-2.0L + 4.0L * rng.unitBinary64()) * a),
        cast(real) cast(double)(
            (-2.0L + 4.0L * rng.unitBinary64()) * a));
}


private void runExactStructured(
    const string workDirectory)
{
    Metrics metrics = makeMetrics();
    const points = structuredExactPoints();

    foreach (specIndex, spec; exactBaseSpecs())
    {
        validateExactSpec(
            spec,
            points,
            workDirectory,
            specIndex,
            metrics);

        writefln(
            "completed %-24s %s real source points",
            spec.name ~ ":",
            points.length);
    }

    printMetrics(
        "large structured GeographicLib Exact real contract corpus",
        metrics);

    if (metrics.failures != 0)
        throw new Exception(
            "real GeographicLib Exact structured validation failed");
}


private void runExactRandom(
    const string workDirectory,
    const size_t requestedCount)
{
    enum size_t profilesPerEllipsoid = 12;

    Metrics metrics = makeMetrics();
    const bases = exactBaseSpecs();

    const size_t totalProfiles =
        bases.length * profilesPerEllipsoid;
    const size_t pointsPerProfile =
        requestedCount / totalProfiles;
    const size_t remainder =
        requestedCount % totalProfiles;

    size_t globalProfileIndex;

    foreach (ellipsoidIndex, base; bases)
    {
        foreach (profileIndex; 0 .. profilesPerEllipsoid)
        {
            const size_t pointCount =
                pointsPerProfile
                + (globalProfileIndex < remainder ? 1 : 0);

            const spec =
                randomExactProfile(
                    base,
                    ellipsoidIndex,
                    profileIndex);

            auto rng =
                SplitMix64(
                    randomSeed
                    ^ (cast(ulong) ellipsoidIndex << 40)
                    ^ (cast(ulong) profileIndex << 8)
                    ^ 0x504F494E54UL);

            SourcePoint[] points;
            points.reserve(pointCount);

            foreach (_; 0 .. pointCount)
                points ~= randomExactPoint(rng);

            validateExactSpec(
                spec,
                points,
                workDirectory,
                globalProfileIndex,
                metrics);

            writefln(
                "completed %-24s %s real source points",
                spec.name ~ ":",
                pointCount);

            ++globalProfileIndex;
        }
    }

    writefln(
        "deterministic real Exact random corpus seed: 0x%016X",
        randomSeed);
    writefln(
        "projection profiles: %s (%s per ellipsoid)",
        totalProfiles,
        profilesPerEllipsoid);
    writefln(
        "requested source points: %s",
        requestedCount);

    printMetrics(
        "deterministic pseudo-random GeographicLib Exact real contract corpus",
        metrics);

    if (metrics.failures != 0)
        throw new Exception(
            "real GeographicLib Exact random validation failed");
}


private void runBoundaryProperty()
{
    const real radius = 6_371_000.0L;
    const real lon0Degrees = 15.0L;
    const real[] latitudes = [
        80.0L,
        85.0L,
        88.0L,
        89.0L,
        89.9L,
        89.99L,
        89.999L,
        89.9999L,
        89.99999L,
        89.999999L,
        89.9999999L,
        89.99999999L,
    ];
    const real[] outsideDeltas = [
        60.000000001L,
        60.000001L,
        60.001L,
        60.01L,
        60.1L,
        61.0L,
        65.0L,
    ];

    size_t boundaryCases;
    size_t boundaryRejected;
    size_t boundaryResidualBeyondBudget;
    real worstBoundaryResidual = 0.0L;
    size_t outsideCases;
    size_t outsideRejected;
    size_t outsideAcceptedWithinBudget;
    size_t outsideAcceptedBeyondBudget;

    real worstAcceptedOutsideResidual = 0.0L;

    foreach (k0; [0.9L, 1.0L, 1.1L])
    {
        const projection =
            TransverseMercator!real.fromParameters(
                Ellipsoid!real.fromFlattening(
                    radius,
                    0.0L),
                Latitude!real.fromDegrees(0.0L),
                Longitude!real.fromDegrees(lon0Degrees),
                k0,
                0.0L,
                0.0L);

        foreach (latitudeMagnitude; latitudes)
        {
            foreach (latitudeSign; [-1.0L, 1.0L])
            {
                const latitude =
                    Latitude!real.fromDegrees(
                        latitudeSign * latitudeMagnitude);

                if (fabs(latitude.degrees) >= 90.0L)
                    continue;

                foreach (longitudeSign; [-1.0L, 1.0L])
                {
                    ++boundaryCases;

                    const boundaryLongitude =
                        Longitude!real.fromDegrees(
                            normalizeDegrees(
                                lon0Degrees
                                + longitudeSign * 60.0L));

                    const boundaryGeographic =
                        GeographicCoordinate!real.fromComponents(
                            latitude,
                            boundaryLongitude);

                    ProjectedCoordinate!real boundaryProjected;

                    if (!projection.tryForward(
                            boundaryGeographic,
                            boundaryProjected))
                    {
                        ++boundaryRejected;
                        continue;
                    }

                    GeographicCoordinate!real boundaryRecovered;

                    if (!projection.tryReverse(
                            boundaryProjected,
                            boundaryRecovered))
                    {
                        ++boundaryRejected;
                    }
                    else
                    {
                        const boundaryRoundTrip =
                            projection.forward(boundaryRecovered);

                        const real boundaryResidual =
                            hypot2(
                                boundaryProjected.easting
                                    - boundaryRoundTrip.easting,
                                boundaryProjected.northing
                                    - boundaryRoundTrip.northing);

                        if (boundaryResidual > worstBoundaryResidual)
                            worstBoundaryResidual = boundaryResidual;

                        if (boundaryResidual > targetMetres)
                            ++boundaryResidualBeyondBudget;
                    }

                    foreach (outsideMagnitude; outsideDeltas)
                    {
                        ++outsideCases;

                        const real outsideDelta =
                            longitudeSign * outsideMagnitude;

                        /*
                         * Independent spherical oracle in real, not a call to
                         * production forward outside its public domain.
                         */
                        const context =
                            makeSphereContext(
                                ProjectionSpec(
                                    "boundary",
                                    radius,
                                    0.0L,
                                    0.0L,
                                    lon0Degrees,
                                    k0,
                                    0.0L,
                                    0.0L));

                        const outsideLongitude =
                            Longitude!real.fromDegrees(
                                normalizeDegrees(
                                    lon0Degrees
                                    + outsideDelta));

                        const outsideProjectedOracle =
                            sphereForward(
                                context.oracle,
                                latitude.radians,
                                outsideLongitude.radians,
                                false);

                        const outsideProjected =
                            ProjectedCoordinate!real.fromComponents(
                                outsideProjectedOracle.easting,
                                outsideProjectedOracle.northing);

                        GeographicCoordinate!real recovered;

                        if (!projection.tryReverse(
                                outsideProjected,
                                recovered))
                        {
                            ++outsideRejected;
                            continue;
                        }

                        const returned =
                            projection.forward(recovered);

                        const real residual =
                            hypot2(
                                outsideProjected.easting
                                    - returned.easting,
                                outsideProjected.northing
                                    - returned.northing);

                        if (residual > worstAcceptedOutsideResidual)
                            worstAcceptedOutsideResidual = residual;

                        if (residual <= targetMetres)
                            ++outsideAcceptedWithinBudget;
                        else
                        {
                            ++outsideAcceptedBeyondBudget;

                            if (outsideAcceptedBeyondBudget <= 12)
                                writefln(
                                    "OUTSIDE ACCEPTED BEYOND BUDGET: "
                                    ~ "k0=%.18g lat=%.18g "
                                    ~ "dlon=%+.18g residual=%.18g m",
                                    k0,
                                    latitude.degrees,
                                    outsideDelta,
                                    residual);
                        }
                    }
                }
            }
        }
    }

    writeln;
    writeln("real reverse-domain boundary/property probe:");
    writefln(
        "  boundary cases: %s",
        boundaryCases);
    writefln(
        "  boundary rejected: %s",
        boundaryRejected);
    writefln(
        "  boundary residual > budget: %s",
        boundaryResidualBeyondBudget);
    writefln(
        "  worst boundary residual: %.18g m",
        worstBoundaryResidual);
    writefln(
        "  outside cases: %s",
        outsideCases);
    writefln(
        "  outside rejected: %s",
        outsideRejected);
    writefln(
        "  outside accepted within budget: %s",
        outsideAcceptedWithinBudget);
    writefln(
        "  outside accepted beyond budget: %s",
        outsideAcceptedBeyondBudget);
    writefln(
        "  worst accepted outside residual: %.18g m",
        worstAcceptedOutsideResidual);

    const bool pass =
        boundaryRejected == 0
        && boundaryResidualBeyondBudget == 0
        && outsideAcceptedBeyondBudget == 0;

    writefln(
        "RESULT: %s",
        pass ? "PASS" : "FAIL");

    if (!pass)
        throw new Exception(
            "real reverse boundary/property validation failed");
}


private void runPrecisionPreservation()
{
    if (real.mant_dig <= double.mant_dig)
    {
        writeln;
        writeln("real wider-than-double precision preservation:");
        writeln("  RESULT: SKIP (real is not wider than double on this platform)");
        return;
    }

    const projection =
        TransverseMercator!real.fromParameters(
            Ellipsoid!real.fromFlattening(
                6_378_137.0L,
                0.0L),
            Latitude!real.fromDegrees(0.0L),
            Longitude!real.fromDegrees(0.0L),
            1.0L,
            0.0L,
            0.0L);

    const latitude =
        Latitude!real.fromRadians(0.0L);

    /*
     * 0.25 rad is exactly representable in binary.  The perturbation 2^-58 is
     * far below one binary64 ULP at 0.25, but well above one x87-extended ULP.
     */
    const real longitudeARadians = 0.25L;
    const real perturbation = 0x1p-58L;
    const real longitudeBRadians =
        longitudeARadians + perturbation;

    const longitudeA =
        Longitude!real.fromRadians(
            longitudeARadians);
    const longitudeB =
        Longitude!real.fromRadians(
            longitudeBRadians);

    const bool collapsesToSameDouble =
        cast(double) longitudeA.radians
        == cast(double) longitudeB.radians;

    const pointA =
        GeographicCoordinate!real.fromComponents(
            latitude,
            longitudeA);
    const pointB =
        GeographicCoordinate!real.fromComponents(
            latitude,
            longitudeB);

    const projectedA =
        projection.forward(pointA);
    const projectedB =
        projection.forward(pointB);

    const real productionDeltaEasting =
        projectedB.easting
        - projectedA.easting;
    const real productionDeltaNorthing =
        projectedB.northing
        - projectedA.northing;

    const context =
        makeSphereContext(
            ProjectionSpec(
                "precision-preservation",
                6_378_137.0L,
                0.0L,
                0.0L,
                0.0L,
                1.0L,
                0.0L,
                0.0L));

    const oracleA =
        sphereForward(
            context.oracle,
            latitude.radians,
            longitudeA.radians,
            false);
    const oracleB =
        sphereForward(
            context.oracle,
            latitude.radians,
            longitudeB.radians,
            false);

    const real oracleDeltaEasting =
        oracleB.easting
        - oracleA.easting;
    const real oracleDeltaNorthing =
        oracleB.northing
        - oracleA.northing;

    const real differentialResidual =
        hypot2(
            productionDeltaEasting
                - oracleDeltaEasting,
            productionDeltaNorthing
                - oracleDeltaNorthing);

    const bool productionDistinguishes =
        projectedA.easting != projectedB.easting
        || projectedA.northing != projectedB.northing;

    /*
     * This is a preservation probe, not the public metre-accuracy gate.  The
     * expected differential is only around 1e-11 m.  Requiring the production
     * differential to agree with the independent real spherical differential
     * to 1e-12 m still leaves comfortable room for transcendental rounding.
     */
    const bool differentialAgrees =
        differentialResidual <= 1.0e-12L;

    writeln;
    writeln("real wider-than-double precision preservation:");
    writefln(
        "  real.mant_dig: %s",
        real.mant_dig);
    writefln(
        "  double.mant_dig: %s",
        double.mant_dig);
    writefln(
        "  perturbation radians: %.21g",
        perturbation);
    writefln(
        "  cast(double) inputs equal: %s",
        collapsesToSameDouble);
    writefln(
        "  production dE: %.21g m",
        productionDeltaEasting);
    writefln(
        "  production dN: %.21g m",
        productionDeltaNorthing);
    writefln(
        "  oracle dE: %.21g m",
        oracleDeltaEasting);
    writefln(
        "  oracle dN: %.21g m",
        oracleDeltaNorthing);
    writefln(
        "  differential residual: %.21g m",
        differentialResidual);
    writefln(
        "  production distinguishes inputs: %s",
        productionDistinguishes);

    const bool pass =
        collapsesToSameDouble
        && productionDistinguishes
        && differentialAgrees;

    writefln(
        "RESULT: %s",
        pass ? "PASS" : "FAIL");

    if (!pass)
        throw new Exception(
            "real wider-than-double precision preservation failed");
}


private void printPlatform()
{
    writeln("D real platform properties:");
    writefln("  real.sizeof    = %s", real.sizeof);
    writefln("  real.mant_dig  = %s", real.mant_dig);
    writefln("  real.dig       = %s", real.dig);
    writefln("  real.epsilon   = %.21g", real.epsilon);
    writefln("  real.min_exp   = %s", real.min_exp);
    writefln("  real.max_exp   = %s", real.max_exp);
    writefln("  double.sizeof  = %s", double.sizeof);
    writefln("  double.mant_dig= %s", double.mant_dig);
    writefln(
        "  real wider than double = %s",
        real.mant_dig > double.mant_dig);
}


private void usage()
{
    writeln(
        "usage: transverse-mercator-real-validation "
        ~ "--work-dir DIR --platform");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --precision");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --boundary");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --sphere-structured");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --sphere-random COUNT");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --exact-structured");
    writeln(
        "   or: transverse-mercator-real-validation "
        ~ "--work-dir DIR --exact-random COUNT");
}


int main(string[] args)
{
    if ((args.length != 4 && args.length != 5)
        || args[1] != "--work-dir")
    {
        usage();
        return 2;
    }

    const workDirectory = args[2];
    const mode = args[3];

    try
    {
        if (mode == "--platform"
            && args.length == 4)
        {
            printPlatform();
            return 0;
        }

        if (mode == "--precision"
            && args.length == 4)
        {
            printPlatform();
            runPrecisionPreservation();
            return 0;
        }

        if (mode == "--boundary"
            && args.length == 4)
        {
            printPlatform();
            runBoundaryProperty();
            return 0;
        }

        if (mode == "--sphere-structured"
            && args.length == 4)
        {
            printPlatform();
            runSphereStructured();
            return 0;
        }

        if (mode == "--sphere-random"
            && args.length == 5)
        {
            const count = args[4].to!size_t;

            if (count == 0)
                throw new Exception(
                    "sphere random COUNT must be greater than zero");

            printPlatform();
            runSphereRandom(count);
            return 0;
        }

        if (mode == "--exact-structured"
            && args.length == 4)
        {
            const versionOutput =
                executeShell(
                    "TransverseMercatorProj --version");

            if (versionOutput.status != 0)
                throw new Exception(
                    "TransverseMercatorProj --version failed");

            writefln(
                "GeographicLib exact reference: %s",
                versionOutput.output.strip);
            writeln(
                "reference precision role: binary64 contract oracle; "
                ~ "production parameters remain full-width real; "
                ~ "not a full-width real oracle");

            printPlatform();
            runExactStructured(workDirectory);
            return 0;
        }

        if (mode == "--exact-random"
            && args.length == 5)
        {
            const count = args[4].to!size_t;

            if (count == 0)
                throw new Exception(
                    "Exact random COUNT must be greater than zero");

            const versionOutput =
                executeShell(
                    "TransverseMercatorProj --version");

            if (versionOutput.status != 0)
                throw new Exception(
                    "TransverseMercatorProj --version failed");

            writefln(
                "GeographicLib exact reference: %s",
                versionOutput.output.strip);
            writeln(
                "reference precision role: binary64 contract oracle; "
                ~ "production parameters remain full-width real; "
                ~ "not a full-width real oracle");

            printPlatform();
            runExactRandom(
                workDirectory,
                count);
            return 0;
        }
    }
    catch (Exception error)
    {
        writefln("FAIL: %s", error.msg);
        return 1;
    }

    usage();
    return 2;
}
