/**
 * Large deterministic Transverse Mercator differential validation against
 * GeographicLib TransverseMercatorExact.
 *
 * GeographicLib is an external validation oracle only.  To keep large corpora
 * practical, this harness batches all coordinates for one projection through a
 * single TransverseMercatorProj process instead of spawning one process per
 * point.
 */
module transverse_mercator_exact_corpus;

import std.conv : to;
import std.file : exists, remove;
import std.format : format;
import std.math : PI, fabs, isFinite, sqrt;
import std.path : buildPath;
import std.process : executeShell;
import std.stdio : File, writefln, writeln;
import std.string : indexOf, split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private enum double doubleTargetMetres = 1.0e-3;
private enum double floatTargetMetres = 2.0;

private enum ulong randomCorpusSeed = 0x544D5F4558414354UL; // "TM_EXACT"
private enum size_t randomProfilesPerEllipsoid = 12;


private struct ProjectionSpec
{
    string name;
    Ellipsoid!double ellipsoid;
    double latitudeOfNaturalOrigin;
    double longitudeOfNaturalOrigin;
    double scaleFactorAtNaturalOrigin;
    double falseEasting;
    double falseNorthing;
}


private struct SourcePoint
{
    double latitude;
    double longitude;
}


private struct ReferencePoint
{
    double latitude;
    double longitude;
    double easting;
    double northing;
    double scale;
    bool reverseAccepted;
}


private struct Metrics
{
    size_t forwardComparisons;
    size_t reverseComparisons;
    size_t failures;

    double worstAbsoluteError;
    string worstAbsoluteLabel;

    double worstGroundEquivalentError;
    string worstGroundEquivalentLabel;
}


private struct FloatDiagnostics
{
    size_t forwardSamples;
    size_t forwardExactlyRoundedSamples;

    double worstForwardRepresentationFloor;
    string worstForwardRepresentationFloorLabel;

    double worstForwardRepresentationFloorGroundEquivalent;
    string worstForwardRepresentationFloorGroundEquivalentLabel;

    double worstForwardDistanceFromCorrectlyRoundedExact;
    string worstForwardDistanceFromCorrectlyRoundedExactLabel;

    double worstReversePublicRoundTripResidual;
    string worstReversePublicRoundTripResidualLabel;

    double worstDoubleTwinExactError;
    string worstDoubleTwinExactErrorLabel;

    double worstFloatVsRoundedDoubleTwin;
    string worstFloatVsRoundedDoubleTwinLabel;

    double worstFloatVsRoundedExactDeltaEasting;
    double worstFloatVsRoundedExactDeltaNorthing;
    double worstFloatVsRoundedExactExactEasting;
    double worstFloatVsRoundedExactExactNorthing;
    float worstFloatVsRoundedExactRoundedEasting;
    float worstFloatVsRoundedExactRoundedNorthing;
    float worstFloatVsRoundedExactActualEasting;
    float worstFloatVsRoundedExactActualNorthing;
}


private string quoteShell(const string value)
{
    // Paths are created by mktemp in the wrapper script.  Reject the only
    // character which would break the deliberately simple single-quote shell
    // quoting used below.
    if (value.indexOf('\'') >= 0)
        throw new Exception("unsupported apostrophe in validation path");

    return "'" ~ value ~ "'";
}


private double exactOriginNorthing(
    const ProjectionSpec spec)
{
    /*
     * Fixed decimal angle formatting is intentional: GeographicLib's DMS
     * parser does not accept scientific notation for geographic angles.
     */
    const command = format(
        "printf '%%s %%s\\n' '%.17f' '%.17f' | "
        ~ "TransverseMercatorProj "
        ~ "-l '%.17f' -k '%.17f' -e '%.17f' '%.17f' -p 12",
        spec.latitudeOfNaturalOrigin,
        spec.longitudeOfNaturalOrigin,
        spec.longitudeOfNaturalOrigin,
        spec.scaleFactorAtNaturalOrigin,
        spec.ellipsoid.semiMajorAxis,
        spec.ellipsoid.flattening);

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

    return fields[1].to!double;
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
        spec.longitudeOfNaturalOrigin,
        spec.scaleFactorAtNaturalOrigin,
        spec.ellipsoid.semiMajorAxis,
        spec.ellipsoid.flattening,
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


private void writePoints(
    const string path,
    const SourcePoint[] points)
{
    auto file = File(path, "w");

    foreach (const point; points)
        file.writefln("%.17f %.17f", point.latitude, point.longitude);
}


private double normalizedLongitudeDifference(
    const double longitude,
    const double longitudeOfNaturalOrigin)
{
    double delta =
        longitude - longitudeOfNaturalOrigin;

    if (delta > 180.0)
        delta -= 360.0;
    else if (delta < -180.0)
        delta += 360.0;

    return delta;
}


private void recordComparison(
    const string label,
    const bool isForward,
    const double actualEasting,
    const double actualNorthing,
    const double referenceEasting,
    const double referenceNorthing,
    const double referenceScale,
    const double targetMetres,
    ref Metrics metrics)
{
    const deltaEasting = actualEasting - referenceEasting;
    const deltaNorthing = actualNorthing - referenceNorthing;
    const absoluteError =
        sqrt(deltaEasting * deltaEasting
            + deltaNorthing * deltaNorthing);

    const groundEquivalentError =
        absoluteError / referenceScale;

    if (isForward)
        ++metrics.forwardComparisons;
    else
        ++metrics.reverseComparisons;

    if (absoluteError > metrics.worstAbsoluteError)
    {
        metrics.worstAbsoluteError = absoluteError;
        metrics.worstAbsoluteLabel = label;
    }

    if (groundEquivalentError > metrics.worstGroundEquivalentError)
    {
        metrics.worstGroundEquivalentError = groundEquivalentError;
        metrics.worstGroundEquivalentLabel = label;
    }

    /*
     * Every generated projection profile is inside the ADR ordinary-terrestrial
     * envelope, so both the intrinsic ground-equivalent metric and the
     * represented projected-coordinate metric must remain within 1 mm.
     */
    if (absoluteError > targetMetres
        || groundEquivalentError > targetMetres)
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s: absolute=%.12g m "
                ~ "groundEquivalent=%.12g m scale=%.12g",
                label,
                absoluteError,
                groundEquivalentError,
                referenceScale);
    }
}


private TransverseMercator!double makeProjection(
    const ProjectionSpec spec)
{
    return TransverseMercator!double.fromParameters(
        spec.ellipsoid,
        Latitude!double.fromDegrees(
            spec.latitudeOfNaturalOrigin),
        Longitude!double.fromDegrees(
            spec.longitudeOfNaturalOrigin),
        spec.scaleFactorAtNaturalOrigin,
        spec.falseEasting,
        spec.falseNorthing);
}


private ProjectionSpec[] projectionSpecs()
{
    return [
        ProjectionSpec(
            "WGS84",
            wgs84!double(),
            0.0, 15.0, 1.0, 0.0, 0.0),

        ProjectionSpec(
            "GRS80",
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257222101),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),

        ProjectionSpec(
            "Airy1830",
            Ellipsoid!double.fromInverseFlattening(
                6_377_563.396,
                299.3249646),
            -35.0, 15.0, 0.9999, -2_000_000.0, 3_000_000.0),

        ProjectionSpec(
            "Bessel1841",
            Ellipsoid!double.fromInverseFlattening(
                6_377_397.155,
                299.1528128),
            0.0, 15.0, 1.0, 0.0, 0.0),

        ProjectionSpec(
            "Clarke1866",
            Ellipsoid!double.fromAxes(
                6_378_206.4,
                6_356_583.8),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),

        ProjectionSpec(
            "International1924",
            Ellipsoid!double.fromInverseFlattening(
                6_378_388.0,
                297.0),
            -35.0, 15.0, 0.9999, -2_000_000.0, 3_000_000.0),

        ProjectionSpec(
            "SyntheticF001",
            Ellipsoid!double.fromFlattening(
                6_378_137.0,
                0.01),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),
    ];
}


private double degreesFromRepresentedFloatRadians(
    const float radians)
{
    return cast(double) radians
        * (180.0 / cast(double) PI);
}


private ProjectionSpec representedFloatSpec(
    const ProjectionSpec spec)
{
    /*
     * TransverseMercator!float promotes the public angle's stored radians to
     * double working precision.  The Exact oracle must therefore reference
     * those same represented float-radian values, not a separately rounded
     * float degree value.
     */
    const float a =
        cast(float) spec.ellipsoid.semiMajorAxis;
    const float f =
        cast(float) spec.ellipsoid.flattening;

    const latitudeOfNaturalOrigin =
        Latitude!float.fromDegrees(
            cast(float) spec.latitudeOfNaturalOrigin);
    const longitudeOfNaturalOrigin =
        Longitude!float.fromDegrees(
            cast(float) spec.longitudeOfNaturalOrigin);

    const float scaleFactorAtNaturalOrigin =
        cast(float) spec.scaleFactorAtNaturalOrigin;
    const float falseEasting =
        cast(float) spec.falseEasting;
    const float falseNorthing =
        cast(float) spec.falseNorthing;

    return ProjectionSpec(
        spec.name,
        Ellipsoid!double.fromFlattening(
            cast(double) a,
            cast(double) f),
        degreesFromRepresentedFloatRadians(
            latitudeOfNaturalOrigin.radians),
        degreesFromRepresentedFloatRadians(
            longitudeOfNaturalOrigin.radians),
        cast(double) scaleFactorAtNaturalOrigin,
        cast(double) falseEasting,
        cast(double) falseNorthing);
}


private TransverseMercator!float makeFloatProjection(
    const ProjectionSpec representedSpec)
{
    return TransverseMercator!float.fromParameters(
        Ellipsoid!float.fromFlattening(
            cast(float) representedSpec.ellipsoid.semiMajorAxis,
            cast(float) representedSpec.ellipsoid.flattening),
        Latitude!float.fromDegrees(
            cast(float) representedSpec.latitudeOfNaturalOrigin),
        Longitude!float.fromDegrees(
            cast(float) representedSpec.longitudeOfNaturalOrigin),
        cast(float) representedSpec.scaleFactorAtNaturalOrigin,
        cast(float) representedSpec.falseEasting,
        cast(float) representedSpec.falseNorthing);
}


private TransverseMercator!double makeFloatRepresentedDoubleTwin(
    const ProjectionSpec sourceSpec)
{
    /*
     * Reproduce exactly the public float projection parameters, then promote
     * those represented values to double without a degree round trip.
     *
     * This is a diagnostic twin, not a public API path.
     */
    const float a =
        cast(float) sourceSpec.ellipsoid.semiMajorAxis;
    const float f =
        cast(float) sourceSpec.ellipsoid.flattening;

    const latitudeOfNaturalOrigin =
        Latitude!float.fromDegrees(
            cast(float) sourceSpec.latitudeOfNaturalOrigin);
    const longitudeOfNaturalOrigin =
        Longitude!float.fromDegrees(
            cast(float) sourceSpec.longitudeOfNaturalOrigin);

    const float scaleFactorAtNaturalOrigin =
        cast(float) sourceSpec.scaleFactorAtNaturalOrigin;
    const float falseEasting =
        cast(float) sourceSpec.falseEasting;
    const float falseNorthing =
        cast(float) sourceSpec.falseNorthing;

    return TransverseMercator!double.fromParameters(
        Ellipsoid!double.fromFlattening(
            cast(double) a,
            cast(double) f),
        Latitude!double.fromRadians(
            cast(double) latitudeOfNaturalOrigin.radians),
        Longitude!double.fromRadians(
            cast(double) longitudeOfNaturalOrigin.radians),
        cast(double) scaleFactorAtNaturalOrigin,
        cast(double) falseEasting,
        cast(double) falseNorthing);
}


private SourcePoint[] representedFloatPoints(
    const SourcePoint[] points,
    const ProjectionSpec sourceSpec)
{
    SourcePoint[] represented;
    represented.length = points.length;

    /*
     * The public float projection consumes angles stored in float radians.
     * A nominal +/-60 degree source point can therefore land a fraction of a
     * float ULP outside the mathematical boundary after degree->radian
     * conversion.  The production kernel deliberately accepts such a
     * representation-level overrun within its float boundary slack and clamps
     * the working longitude difference to exactly +/-60 degrees.
     *
     * The Exact oracle must model that effective point rather than evaluate
     * the raw, slightly-outside represented longitude.
     */
    const longitudeOfNaturalOrigin =
        Longitude!float.fromDegrees(
            cast(float) sourceSpec.longitudeOfNaturalOrigin);

    const double originRadians =
        cast(double) longitudeOfNaturalOrigin.radians;
    const double piValue = cast(double) PI;
    const double twoPi = 2.0 * piValue;
    const double maxDelta = piValue / 3.0;

    foreach (index, point; points)
    {
        const latitude =
            Latitude!float.fromDegrees(
                cast(float) point.latitude);
        const longitude =
            Longitude!float.fromDegrees(
                cast(float) point.longitude);

        double representedLongitudeRadians =
            cast(double) longitude.radians;

        double deltaRadians =
            representedLongitudeRadians - originRadians;

        if (deltaRadians >= piValue)
            deltaRadians -= twoPi;
        else if (deltaRadians < -piValue)
            deltaRadians += twoPi;

        if (fabs(deltaRadians) > maxDelta)
        {
            deltaRadians =
                deltaRadians < 0.0
                    ? -maxDelta
                    : maxDelta;

            representedLongitudeRadians =
                originRadians + deltaRadians;

            if (representedLongitudeRadians >= piValue)
                representedLongitudeRadians -= twoPi;
            else if (representedLongitudeRadians < -piValue)
                representedLongitudeRadians += twoPi;
        }

        represented[index] =
            SourcePoint(
                degreesFromRepresentedFloatRadians(
                    latitude.radians),
                representedLongitudeRadians
                    * (180.0 / piValue));
    }

    return represented;
}


private SourcePoint[] structuredPoints(
    const ProjectionSpec spec)
{
    /*
     * 179 integer latitudes (-89..+89) x 201 longitude offsets
     * (-60..+60 in 0.6 degree steps) = 35,979 points/spec.
     *
     * Seven ellipsoids therefore produce 251,853 independent forward inputs
     * and the same number of independent reverse inputs (>250k each).
     */
    SourcePoint[] points;
    points.length = 179 * 201;
    size_t pointIndex = 0;

    foreach (latitudeInteger; -89 .. 90)
    {
        const double latitude = cast(double) latitudeInteger;

        foreach (deltaIndex; 0 .. 201)
        {
            const double deltaLongitude =
                -60.0 + cast(double) deltaIndex * 0.6;

            points[pointIndex++] =
                SourcePoint(
                    latitude,
                    spec.longitudeOfNaturalOrigin + deltaLongitude);
        }
    }

    assert(pointIndex == points.length);

    return points;
}


private ulong splitMix64(ref ulong state)
{
    state += 0x9E3779B97F4A7C15UL;

    ulong z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;

    return z ^ (z >> 31);
}


private double unitRandom(ref ulong state)
{
    // Exactly 53 random mantissa bits in [0, 1).
    return cast(double) (splitMix64(state) >> 11)
        / 9_007_199_254_740_992.0;
}


private ulong profileSeed(
    const size_t ellipsoidIndex,
    const size_t profileIndex,
    const ulong domainTag)
{
    /*
     * Derive each profile/point stream independently so changing the requested
     * corpus size does not silently change later projection parameters.
     */
    ulong state =
        randomCorpusSeed
        ^ domainTag
        ^ (cast(ulong) ellipsoidIndex * 0xD1B54A32D192ED03UL)
        ^ (cast(ulong) profileIndex * 0x94D049BB133111EBUL);

    // Diffuse the tuple before the first consumer draw.
    return splitMix64(state);
}


private ProjectionSpec randomProjectionSpec(
    const ProjectionSpec base,
    const size_t ellipsoidIndex,
    const size_t profileIndex)
{
    ulong state =
        profileSeed(
            ellipsoidIndex,
            profileIndex,
            0x50524F46494C4553UL); // "PROFILES"

    const double a = base.ellipsoid.semiMajorAxis;
    const double profileCount =
        cast(double) randomProfilesPerEllipsoid;
    const double profile =
        cast(double) profileIndex;

    /*
     * Jittered strata cover the full representative parameter envelope for
     * every ellipsoid.  Permuted stratum indices avoid locking all parameters
     * to the same monotonic profile ordering.
     */
    const double lat0Fraction =
        (profile + unitRandom(state)) / profileCount;

    const size_t lonStratum =
        (profileIndex * 5 + ellipsoidIndex)
        % randomProfilesPerEllipsoid;
    const double lon0Fraction =
        (cast(double) lonStratum + unitRandom(state))
        / profileCount;

    const size_t scaleStratum =
        (profileIndex * 7 + ellipsoidIndex * 3)
        % randomProfilesPerEllipsoid;
    const double scaleFraction =
        (cast(double) scaleStratum + unitRandom(state))
        / profileCount;

    const size_t eastingStratum =
        (profileIndex * 11 + ellipsoidIndex * 5)
        % randomProfilesPerEllipsoid;
    const double eastingFraction =
        (cast(double) eastingStratum + unitRandom(state))
        / profileCount;

    const size_t northingStratum =
        (profileIndex * 5 + ellipsoidIndex * 7 + 3)
        % randomProfilesPerEllipsoid;
    const double northingFraction =
        (cast(double) northingStratum + unitRandom(state))
        / profileCount;

    return ProjectionSpec(
        format(
            "%s-R%02d",
            base.name,
            profileIndex),
        base.ellipsoid,

        // Representative non-polar natural origins.
        -80.0 + lat0Fraction * 160.0,

        // Full normalized longitude range.
        -180.0 + lon0Fraction * 360.0,

        // ADR ordinary terrestrial scale-factor envelope.
        0.9 + scaleFraction * 0.2,

        // ADR ordinary terrestrial representation envelope: abs(offset) <= 2a.
        -2.0 * a + eastingFraction * 4.0 * a,
        -2.0 * a + northingFraction * 4.0 * a);
}


private SourcePoint[] randomPoints(
    const ProjectionSpec spec,
    const size_t count,
    const size_t ellipsoidIndex,
    const size_t profileIndex)
{
    SourcePoint[] points;
    points.length = count;

    ulong state =
        profileSeed(
            ellipsoidIndex,
            profileIndex,
            0x504F494E54535452UL); // "POINTSTR"

    /*
     * Jittered deterministic strata:
     *
     * latitude      180 one-degree strata over [-90, +90)
     * delta lon     240 half-degree strata over [-60, +60)
     *
     * The coprime multiplier decorrelates the two stratum cycles.  Jitter is
     * SplitMix64 with a fixed documented seed, so every failure is exactly
     * reproducible without relying on a language-runtime PRNG.
     */
    foreach (pointIndex; 0 .. count)
    {
        const size_t latitudeStratum =
            pointIndex % 180;

        const size_t longitudeStratum =
            (pointIndex * 73
                + profileIndex * 29
                + ellipsoidIndex * 17)
            % 240;

        const double latitude =
            -90.0
            + cast(double) latitudeStratum
            + unitRandom(state);

        const double deltaLongitude =
            -60.0
            + (cast(double) longitudeStratum
                + unitRandom(state)) * 0.5;

        double longitude =
            spec.longitudeOfNaturalOrigin + deltaLongitude;

        if (longitude > 180.0)
            longitude -= 360.0;
        else if (longitude < -180.0)
            longitude += 360.0;

        points[pointIndex] =
            SourcePoint(
                latitude,
                longitude);
    }

    return points;
}


private void validateSpec(
    const ProjectionSpec spec,
    const SourcePoint[] points,
    const string workDirectory,
    const size_t specIndex,
    ref Metrics metrics)
{
    const projection = makeProjection(spec);
    const originNorthing = exactOriginNorthing(spec);

    const prefix =
        buildPath(
            workDirectory,
            format("tm-exact-corpus-%s", specIndex));

    const forwardInput = prefix ~ "-forward.in";
    const forwardOutput = prefix ~ "-forward.out";
    const reverseInput = prefix ~ "-reverse.in";
    const reverseOutput = prefix ~ "-reverse.out";

    scope (exit)
    {
        foreach (path; [
            forwardInput,
            forwardOutput,
            reverseInput,
            reverseOutput,
        ])
        {
            if (exists(path))
                remove(path);
        }
    }

    writePoints(forwardInput, points);
    runExactBatch(spec, forwardInput, forwardOutput);

    ReferencePoint[] references;
    references.length = points.length;

    auto reverseFile = File(reverseInput, "w");
    auto forwardReferenceFile = File(forwardOutput, "r");

    size_t index = 0;

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

        const referenceEasting =
            spec.falseEasting + fields[0].to!double;
        const referenceNorthing =
            spec.falseNorthing
            + fields[1].to!double
            - originNorthing;
        const referenceScale = fields[3].to!double;

        if (!(isFinite(referenceScale) && referenceScale > 0.0))
            throw new Exception(
                format(
                    "invalid GeographicLib point scale for %s point %s",
                    spec.name,
                    index));

        const geographic =
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(point.latitude),
                Longitude!double.fromDegrees(point.longitude));

        const oursForward = projection.forward(geographic);

        const label = format(
            "%s point[%s] lat=%.9f dlon=%.9f forward",
            spec.name,
            index,
            point.latitude,
            normalizedLongitudeDifference(
                point.longitude,
                spec.longitudeOfNaturalOrigin));

        recordComparison(
            label,
            true,
            oursForward.easting,
            oursForward.northing,
            referenceEasting,
            referenceNorthing,
            referenceScale,
            doubleTargetMetres,
            metrics);

        GeographicCoordinate!double recovered;

        const reverseAccepted =
            projection.tryReverse(
                ProjectedCoordinate!double.fromComponents(
                    referenceEasting,
                    referenceNorthing),
                recovered);

        references[index] =
            ReferencePoint(
                point.latitude,
                point.longitude,
                referenceEasting,
                referenceNorthing,
                referenceScale,
                reverseAccepted);

        if (reverseAccepted)
        {
            /*
             * Fixed decimal formatting is again mandatory for the
             * GeographicLib DMS parser near zero latitude/longitude.
             */
            reverseFile.writefln(
                "%.17f %.17f",
                recovered.latitude.degrees,
                recovered.longitude.degrees);
        }
        else
        {
            ++metrics.reverseComparisons;
            ++metrics.failures;

            if (metrics.failures <= 12)
                writefln(
                    "OUTSIDE TARGET: %s point[%s] reverse rejected "
                    ~ "Exact projected coordinate",
                    spec.name,
                    index);

            // Maintain one output row per input row for the batch parser.
            reverseFile.writefln(
                "%.17f %.17f",
                point.latitude,
                point.longitude);
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

    runExactBatch(spec, reverseInput, reverseOutput);

    auto reverseReferenceFile = File(reverseOutput, "r");
    index = 0;

    foreach (line; reverseReferenceFile.byLine())
    {
        if (index >= references.length)
            throw new Exception(
                format(
                    "too many GeographicLib reverse-residual rows for %s",
                    spec.name));

        const fields = line.to!string.strip.split;

        if (fields.length < 2)
            throw new Exception(
                format(
                    "invalid GeographicLib reverse-residual row for %s: %s",
                    spec.name,
                    line.to!string));

        const reference = references[index];

        if (reference.reverseAccepted)
        {
            const representedEasting =
                spec.falseEasting + fields[0].to!double;
            const representedNorthing =
                spec.falseNorthing
                + fields[1].to!double
                - originNorthing;

            const label = format(
                "%s point[%s] lat=%.9f dlon=%.9f reverse",
                spec.name,
                index,
                reference.latitude,
                normalizedLongitudeDifference(
                    reference.longitude,
                    spec.longitudeOfNaturalOrigin));

            recordComparison(
                label,
                false,
                representedEasting,
                representedNorthing,
                reference.easting,
                reference.northing,
                reference.scale,
                doubleTargetMetres,
                metrics);
        }

        ++index;
    }

    reverseReferenceFile.close();

    if (index != references.length)
        throw new Exception(
            format(
                "GeographicLib reverse-residual row count mismatch for %s: "
                ~ "%s vs %s",
                spec.name,
                index,
                references.length));

    writefln(
        "completed %-20s %s source points",
        spec.name ~ ":",
        points.length);
}


private void recordFloatForwardDiagnostics(
    const string label,
    const ProjectedCoordinate!float oursForward,
    const ProjectedCoordinate!double doubleTwinForward,
    const double exactEasting,
    const double exactNorthing,
    const double referenceScale,
    ref FloatDiagnostics diagnostics)
{
    const float roundedExactEasting =
        cast(float) exactEasting;
    const float roundedExactNorthing =
        cast(float) exactNorthing;

    const double representationDeltaEasting =
        cast(double) roundedExactEasting - exactEasting;
    const double representationDeltaNorthing =
        cast(double) roundedExactNorthing - exactNorthing;

    const double representationFloor =
        sqrt(
            representationDeltaEasting * representationDeltaEasting
            + representationDeltaNorthing * representationDeltaNorthing);

    const double representationFloorGroundEquivalent =
        representationFloor / referenceScale;

    const double roundedResidualEasting =
        cast(double) oursForward.easting
        - cast(double) roundedExactEasting;
    const double roundedResidualNorthing =
        cast(double) oursForward.northing
        - cast(double) roundedExactNorthing;

    const double distanceFromCorrectlyRoundedExact =
        sqrt(
            roundedResidualEasting * roundedResidualEasting
            + roundedResidualNorthing * roundedResidualNorthing);

    const double doubleTwinDeltaEasting =
        doubleTwinForward.easting - exactEasting;
    const double doubleTwinDeltaNorthing =
        doubleTwinForward.northing - exactNorthing;
    const double doubleTwinExactError =
        sqrt(
            doubleTwinDeltaEasting * doubleTwinDeltaEasting
            + doubleTwinDeltaNorthing * doubleTwinDeltaNorthing);

    const float roundedDoubleTwinEasting =
        cast(float) doubleTwinForward.easting;
    const float roundedDoubleTwinNorthing =
        cast(float) doubleTwinForward.northing;

    const double floatVsRoundedDoubleTwinDeltaEasting =
        cast(double) oursForward.easting
        - cast(double) roundedDoubleTwinEasting;
    const double floatVsRoundedDoubleTwinDeltaNorthing =
        cast(double) oursForward.northing
        - cast(double) roundedDoubleTwinNorthing;
    const double floatVsRoundedDoubleTwin =
        sqrt(
            floatVsRoundedDoubleTwinDeltaEasting
                * floatVsRoundedDoubleTwinDeltaEasting
            + floatVsRoundedDoubleTwinDeltaNorthing
                * floatVsRoundedDoubleTwinDeltaNorthing);

    ++diagnostics.forwardSamples;

    if (oursForward.easting == roundedExactEasting
        && oursForward.northing == roundedExactNorthing)
        ++diagnostics.forwardExactlyRoundedSamples;

    if (representationFloor
        > diagnostics.worstForwardRepresentationFloor)
    {
        diagnostics.worstForwardRepresentationFloor =
            representationFloor;
        diagnostics.worstForwardRepresentationFloorLabel =
            label;
    }

    if (representationFloorGroundEquivalent
        > diagnostics.worstForwardRepresentationFloorGroundEquivalent)
    {
        diagnostics.worstForwardRepresentationFloorGroundEquivalent =
            representationFloorGroundEquivalent;
        diagnostics.worstForwardRepresentationFloorGroundEquivalentLabel =
            label;
    }

    if (distanceFromCorrectlyRoundedExact
        > diagnostics.worstForwardDistanceFromCorrectlyRoundedExact)
    {
        diagnostics.worstForwardDistanceFromCorrectlyRoundedExact =
            distanceFromCorrectlyRoundedExact;
        diagnostics.worstForwardDistanceFromCorrectlyRoundedExactLabel =
            label;

        diagnostics.worstFloatVsRoundedExactDeltaEasting =
            roundedResidualEasting;
        diagnostics.worstFloatVsRoundedExactDeltaNorthing =
            roundedResidualNorthing;
        diagnostics.worstFloatVsRoundedExactExactEasting =
            exactEasting;
        diagnostics.worstFloatVsRoundedExactExactNorthing =
            exactNorthing;
        diagnostics.worstFloatVsRoundedExactRoundedEasting =
            roundedExactEasting;
        diagnostics.worstFloatVsRoundedExactRoundedNorthing =
            roundedExactNorthing;
        diagnostics.worstFloatVsRoundedExactActualEasting =
            oursForward.easting;
        diagnostics.worstFloatVsRoundedExactActualNorthing =
            oursForward.northing;
    }

    if (doubleTwinExactError
        > diagnostics.worstDoubleTwinExactError)
    {
        diagnostics.worstDoubleTwinExactError =
            doubleTwinExactError;
        diagnostics.worstDoubleTwinExactErrorLabel =
            label;
    }

    if (floatVsRoundedDoubleTwin
        > diagnostics.worstFloatVsRoundedDoubleTwin)
    {
        diagnostics.worstFloatVsRoundedDoubleTwin =
            floatVsRoundedDoubleTwin;
        diagnostics.worstFloatVsRoundedDoubleTwinLabel =
            label;
    }
}


private void recordFloatReverseDiagnostics(
    const string label,
    const TransverseMercator!float projection,
    const GeographicCoordinate!float recovered,
    const float inputEasting,
    const float inputNorthing,
    ref FloatDiagnostics diagnostics)
{
    /*
     * This is deliberately a public-representation round trip:
     * represented float projected input -> float geographic output ->
     * represented float projected output.
     *
     * It does not prove exact inverse accuracy; it tells us whether a large
     * Exact residual is already forced by the public float representations or
     * whether the implementation also fails to reproduce its own represented
     * input.
     */
    const roundTrip = projection.forward(recovered);

    const double deltaEasting =
        cast(double) roundTrip.easting
        - cast(double) inputEasting;
    const double deltaNorthing =
        cast(double) roundTrip.northing
        - cast(double) inputNorthing;

    const double residual =
        sqrt(
            deltaEasting * deltaEasting
            + deltaNorthing * deltaNorthing);

    if (residual > diagnostics.worstReversePublicRoundTripResidual)
    {
        diagnostics.worstReversePublicRoundTripResidual =
            residual;
        diagnostics.worstReversePublicRoundTripResidualLabel =
            label;
    }
}


private void validateSpecFloat(
    const ProjectionSpec sourceSpec,
    const SourcePoint[] sourcePoints,
    const string workDirectory,
    const size_t specIndex,
    ref Metrics metrics,
    ref FloatDiagnostics diagnostics)
{
    const spec = representedFloatSpec(sourceSpec);

    /*
     * Construct the public float projection directly from the original caller
     * parameters.  Do not reconstruct it from `spec`: that would perform a
     * second degrees -> float -> radians quantization after `spec` has already
     * been derived from represented float radians.
     */
    const projection = makeFloatProjection(sourceSpec);

    // The double twin and GeographicLib use the effective represented values.
    const doubleTwinProjection = makeFloatRepresentedDoubleTwin(sourceSpec);

    const oraclePoints = representedFloatPoints(sourcePoints, sourceSpec);
    const originNorthing = exactOriginNorthing(spec);

    const prefix =
        buildPath(
            workDirectory,
            format("tm-exact-float-corpus-%s", specIndex));

    const forwardInput = prefix ~ "-forward.in";
    const forwardOutput = prefix ~ "-forward.out";
    const reverseInput = prefix ~ "-reverse.in";
    const reverseOutput = prefix ~ "-reverse.out";

    scope (exit)
    {
        foreach (path; [
            forwardInput,
            forwardOutput,
            reverseInput,
            reverseOutput,
        ])
        {
            if (exists(path))
                remove(path);
        }
    }

    writePoints(forwardInput, oraclePoints);
    runExactBatch(spec, forwardInput, forwardOutput);

    ReferencePoint[] references;
    references.length = sourcePoints.length;

    auto reverseFile = File(reverseInput, "w");
    auto forwardReferenceFile = File(forwardOutput, "r");

    size_t index = 0;

    foreach (line; forwardReferenceFile.byLine())
    {
        if (index >= sourcePoints.length)
            throw new Exception(
                format(
                    "too many GeographicLib float forward rows for %s",
                    spec.name));

        const fields = line.to!string.strip.split;

        if (fields.length < 4)
            throw new Exception(
                format(
                    "invalid GeographicLib float forward row for %s: %s",
                    spec.name,
                    line.to!string));

        const sourcePoint = sourcePoints[index];
        const point = oraclePoints[index];

        const exactEasting =
            spec.falseEasting + fields[0].to!double;
        const exactNorthing =
            spec.falseNorthing
            + fields[1].to!double
            - originNorthing;
        const referenceScale = fields[3].to!double;

        if (!(isFinite(referenceScale) && referenceScale > 0.0))
            throw new Exception(
                format(
                    "invalid GeographicLib float point scale for %s point %s",
                    spec.name,
                    index));

        const geographic =
            GeographicCoordinate!float.fromComponents(
                Latitude!float.fromDegrees(
                    cast(float) sourcePoint.latitude),
                Longitude!float.fromDegrees(
                    cast(float) sourcePoint.longitude));

        const doubleTwinGeographic =
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(point.latitude),
                Longitude!double.fromDegrees(point.longitude));

        ProjectedCoordinate!float oursForward;

        if (!projection.tryForward(geographic, oursForward))
        {
            const representedLongitudeOfNaturalOrigin =
                Longitude!float.fromDegrees(
                    cast(float) sourceSpec.longitudeOfNaturalOrigin);

            double deltaRadians =
                cast(double) geographic.longitude.radians
                - cast(double) representedLongitudeOfNaturalOrigin.radians;

            const double piValue = cast(double) PI;
            const double twoPi = 2.0 * piValue;

            if (deltaRadians >= piValue)
                deltaRadians -= twoPi;
            else if (deltaRadians < -piValue)
                deltaRadians += twoPi;

            const double maxDelta = piValue / 3.0;
            const double boundaryOverrun =
                fabs(deltaRadians) - maxDelta;

            const double approximateNaturalScale =
                cast(double) cast(float) sourceSpec.ellipsoid.semiMajorAxis
                * cast(double) cast(float)
                    sourceSpec.scaleFactorAtNaturalOrigin;

            const double approximateGroundOverrun =
                boundaryOverrun > 0.0
                    ? boundaryOverrun * approximateNaturalScale
                    : 0.0;

            ProjectedCoordinate!double doubleTwinProjected;
            const bool doubleTwinAccepted =
                doubleTwinProjection.tryForward(
                    doubleTwinGeographic,
                    doubleTwinProjected);

            throw new Exception(
                format(
                    "float forward rejected: %s point[%s] "
                    ~ "source=(%.12f, %.12f deg) "
                    ~ "represented=(%.12f, %.12f deg) "
                    ~ "lon0Represented=%.12f deg "
                    ~ "delta=%.15g rad / %.12f deg "
                    ~ "boundaryOverrun=%.15g rad (~%.9f m) "
                    ~ "doubleTwinAccepted=%s",
                    sourceSpec.name,
                    index,
                    sourcePoint.latitude,
                    sourcePoint.longitude,
                    point.latitude,
                    point.longitude,
                    degreesFromRepresentedFloatRadians(
                        representedLongitudeOfNaturalOrigin.radians),
                    deltaRadians,
                    deltaRadians * (180.0 / piValue),
                    boundaryOverrun,
                    approximateGroundOverrun,
                    doubleTwinAccepted));
        }

        ProjectedCoordinate!double doubleTwinForward;

        if (!doubleTwinProjection.tryForward(
                doubleTwinGeographic,
                doubleTwinForward))
        {
            const representedLongitudeOfNaturalOrigin =
                Longitude!float.fromDegrees(
                    cast(float) sourceSpec.longitudeOfNaturalOrigin);

            double deltaRadians =
                cast(double) geographic.longitude.radians
                - cast(double) representedLongitudeOfNaturalOrigin.radians;

            const double piValue = cast(double) PI;
            const double twoPi = 2.0 * piValue;

            if (deltaRadians >= piValue)
                deltaRadians -= twoPi;
            else if (deltaRadians < -piValue)
                deltaRadians += twoPi;

            throw new Exception(
                format(
                    "represented-input double twin rejected: %s point[%s] "
                    ~ "source=(%.12f, %.12f deg) "
                    ~ "represented=(%.12f, %.12f deg) "
                    ~ "delta=%.15g rad / %.12f deg",
                    sourceSpec.name,
                    index,
                    sourcePoint.latitude,
                    sourcePoint.longitude,
                    point.latitude,
                    point.longitude,
                    deltaRadians,
                    deltaRadians * (180.0 / piValue)));
        }

        const label = format(
            "%s point[%s] lat=%.9f dlon=%.9f float forward",
            spec.name,
            index,
            point.latitude,
            normalizedLongitudeDifference(
                point.longitude,
                spec.longitudeOfNaturalOrigin));

        recordFloatForwardDiagnostics(
            label,
            oursForward,
            doubleTwinForward,
            exactEasting,
            exactNorthing,
            referenceScale,
            diagnostics);

        recordComparison(
            label,
            true,
            cast(double) oursForward.easting,
            cast(double) oursForward.northing,
            exactEasting,
            exactNorthing,
            referenceScale,
            floatTargetMetres,
            metrics);

        /*
         * Reverse accepts float projected coordinates.  Quantize the independent
         * Exact coordinate to that public input representation first, then judge
         * the recovered location against that represented projected position.
         */
        const float reverseInputEasting =
            cast(float) exactEasting;
        const float reverseInputNorthing =
            cast(float) exactNorthing;

        GeographicCoordinate!float recovered;

        const reverseAccepted =
            projection.tryReverse(
                ProjectedCoordinate!float.fromComponents(
                    reverseInputEasting,
                    reverseInputNorthing),
                recovered);

        if (reverseAccepted)
        {
            const reverseLabel = format(
                "%s point[%s] lat=%.9f dlon=%.9f float reverse public round trip",
                spec.name,
                index,
                point.latitude,
                normalizedLongitudeDifference(
                    point.longitude,
                    spec.longitudeOfNaturalOrigin));

            recordFloatReverseDiagnostics(
                reverseLabel,
                projection,
                recovered,
                reverseInputEasting,
                reverseInputNorthing,
                diagnostics);
        }

        references[index] =
            ReferencePoint(
                point.latitude,
                point.longitude,
                cast(double) reverseInputEasting,
                cast(double) reverseInputNorthing,
                referenceScale,
                reverseAccepted);

        if (reverseAccepted)
        {
            reverseFile.writefln(
                "%.17f %.17f",
                degreesFromRepresentedFloatRadians(
                    recovered.latitude.radians),
                degreesFromRepresentedFloatRadians(
                    recovered.longitude.radians));
        }
        else
        {
            ++metrics.reverseComparisons;
            ++metrics.failures;

            if (metrics.failures <= 12)
                writefln(
                    "OUTSIDE TARGET: %s point[%s] float reverse rejected "
                    ~ "represented Exact projected coordinate",
                    spec.name,
                    index);

            reverseFile.writefln(
                "%.17f %.17f",
                point.latitude,
                point.longitude);
        }

        ++index;
    }

    reverseFile.close();
    forwardReferenceFile.close();

    if (index != sourcePoints.length)
        throw new Exception(
            format(
                "GeographicLib float forward row count mismatch for %s: %s vs %s",
                spec.name,
                index,
                sourcePoints.length));

    runExactBatch(spec, reverseInput, reverseOutput);

    auto reverseReferenceFile = File(reverseOutput, "r");
    index = 0;

    foreach (line; reverseReferenceFile.byLine())
    {
        if (index >= references.length)
            throw new Exception(
                format(
                    "too many GeographicLib float reverse-residual rows for %s",
                    spec.name));

        const fields = line.to!string.strip.split;

        if (fields.length < 2)
            throw new Exception(
                format(
                    "invalid GeographicLib float reverse-residual row for %s: %s",
                    spec.name,
                    line.to!string));

        const reference = references[index];

        if (reference.reverseAccepted)
        {
            const representedEasting =
                spec.falseEasting + fields[0].to!double;
            const representedNorthing =
                spec.falseNorthing
                + fields[1].to!double
                - originNorthing;

            const label = format(
                "%s point[%s] lat=%.9f dlon=%.9f float reverse",
                spec.name,
                index,
                reference.latitude,
                normalizedLongitudeDifference(
                    reference.longitude,
                    spec.longitudeOfNaturalOrigin));

            recordComparison(
                label,
                false,
                representedEasting,
                representedNorthing,
                reference.easting,
                reference.northing,
                reference.scale,
                floatTargetMetres,
                metrics);
        }

        ++index;
    }

    reverseReferenceFile.close();

    if (index != references.length)
        throw new Exception(
            format(
                "GeographicLib float reverse-residual row count mismatch "
                ~ "for %s: %s vs %s",
                spec.name,
                index,
                references.length));

    writefln(
        "completed %-20s %s float source points",
        spec.name ~ ":",
        sourcePoints.length);
}


private void printResult(
    const string suiteName,
    const double targetMetres,
    const Metrics metrics)
{
    writeln();
    writefln("suite: %s", suiteName);
    writefln(
        "forward comparisons: %s",
        metrics.forwardComparisons);
    writefln(
        "reverse comparisons: %s",
        metrics.reverseComparisons);
    writefln(
        "outside %.9g m target: %s",
        targetMetres,
        metrics.failures);
    writefln(
        "worst absolute projected error: %.12g m",
        metrics.worstAbsoluteError);
    writefln(
        "worst absolute case: %s",
        metrics.worstAbsoluteLabel);
    writefln(
        "worst ground-equivalent error: %.12g m",
        metrics.worstGroundEquivalentError);
    writefln(
        "worst ground-equivalent case: %s",
        metrics.worstGroundEquivalentLabel);
    writeln(metrics.failures == 0 ? "RESULT: PASS" : "RESULT: FAIL");
}


private void printFloatDiagnostics(
    const FloatDiagnostics diagnostics)
{
    writeln();
    writeln("float representation diagnostics:");
    writefln(
        "forward samples: %s",
        diagnostics.forwardSamples);
    writefln(
        "forward exactly equal to correctly rounded Exact E/N: %s (%.6f%%)",
        diagnostics.forwardExactlyRoundedSamples,
        diagnostics.forwardSamples == 0
            ? 0.0
            : 100.0
                * cast(double) diagnostics.forwardExactlyRoundedSamples
                / cast(double) diagnostics.forwardSamples);
    writefln(
        "worst unavoidable forward E/N representation floor: %.12g m",
        diagnostics.worstForwardRepresentationFloor);
    writefln(
        "representation-floor case: %s",
        diagnostics.worstForwardRepresentationFloorLabel);
    writefln(
        "worst unavoidable forward ground-equivalent representation floor: "
        ~ "%.12g m",
        diagnostics.worstForwardRepresentationFloorGroundEquivalent);
    writefln(
        "ground-equivalent representation-floor case: %s",
        diagnostics.worstForwardRepresentationFloorGroundEquivalentLabel);
    writefln(
        "worst forward distance from correctly rounded Exact float E/N: "
        ~ "%.12g m",
        diagnostics.worstForwardDistanceFromCorrectlyRoundedExact);
    writefln(
        "correct-rounding residual case: %s",
        diagnostics.worstForwardDistanceFromCorrectlyRoundedExactLabel);
    writefln(
        "worst public float reverse->forward represented residual: %.12g m",
        diagnostics.worstReversePublicRoundTripResidual);
    writefln(
        "public reverse round-trip case: %s",
        diagnostics.worstReversePublicRoundTripResidualLabel);

    writefln(
        "worst represented-input double twin vs Exact: %.12g m",
        diagnostics.worstDoubleTwinExactError);
    writefln(
        "double-twin Exact case: %s",
        diagnostics.worstDoubleTwinExactErrorLabel);

    writefln(
        "worst float output vs correctly rounded double twin: %.12g m",
        diagnostics.worstFloatVsRoundedDoubleTwin);
    writefln(
        "float-vs-double-twin case: %s",
        diagnostics.worstFloatVsRoundedDoubleTwinLabel);

    writefln(
        "worst correctly-rounded-Exact residual components: "
        ~ "dE=%.12g m dN=%.12g m",
        diagnostics.worstFloatVsRoundedExactDeltaEasting,
        diagnostics.worstFloatVsRoundedExactDeltaNorthing);
    writefln(
        "  Exact E/N: %.12g %.12g",
        diagnostics.worstFloatVsRoundedExactExactEasting,
        diagnostics.worstFloatVsRoundedExactExactNorthing);
    writefln(
        "  rounded Exact float E/N: %.9g %.9g",
        diagnostics.worstFloatVsRoundedExactRoundedEasting,
        diagnostics.worstFloatVsRoundedExactRoundedNorthing);
    writefln(
        "  actual float E/N: %.9g %.9g",
        diagnostics.worstFloatVsRoundedExactActualEasting,
        diagnostics.worstFloatVsRoundedExactActualNorthing);

}


private void usage()
{
    writeln(
        "usage: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --structured");
    writeln(
        "   or: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --random COUNT");
    writeln(
        "   or: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --float-structured");
    writeln(
        "   or: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --float-random COUNT");
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

    const versionOutput =
        executeShell("TransverseMercatorProj --version");

    if (versionOutput.status != 0)
    {
        writeln("FAIL: TransverseMercatorProj --version failed");
        return 2;
    }

    writefln(
        "GeographicLib exact reference: %s",
        versionOutput.output.strip);

    auto specs = projectionSpecs();
    Metrics metrics = Metrics(0, 0, 0, 0.0, "", 0.0, "");
    FloatDiagnostics floatDiagnostics = FloatDiagnostics.init;

    /*
     * D floating-point .init is NaN.  Max-accumulator diagnostics must start
     * at a finite baseline or every `value > worst` comparison is false.
     * Counters and labels can keep their normal .init values.
     */
    floatDiagnostics.worstForwardRepresentationFloor = 0.0;
    floatDiagnostics.worstForwardRepresentationFloorGroundEquivalent = 0.0;
    floatDiagnostics.worstForwardDistanceFromCorrectlyRoundedExact = 0.0;
    floatDiagnostics.worstReversePublicRoundTripResidual = 0.0;
    floatDiagnostics.worstDoubleTwinExactError = 0.0;
    floatDiagnostics.worstFloatVsRoundedDoubleTwin = 0.0;

    floatDiagnostics.worstFloatVsRoundedExactDeltaEasting = 0.0;
    floatDiagnostics.worstFloatVsRoundedExactDeltaNorthing = 0.0;
    floatDiagnostics.worstFloatVsRoundedExactExactEasting = 0.0;
    floatDiagnostics.worstFloatVsRoundedExactExactNorthing = 0.0;
    floatDiagnostics.worstFloatVsRoundedExactRoundedEasting = 0.0f;
    floatDiagnostics.worstFloatVsRoundedExactRoundedNorthing = 0.0f;
    floatDiagnostics.worstFloatVsRoundedExactActualEasting = 0.0f;
    floatDiagnostics.worstFloatVsRoundedExactActualNorthing = 0.0f;

    if (mode == "--structured")
    {
        foreach (specIndex, spec; specs)
        {
            const points = structuredPoints(spec);

            try
                validateSpec(
                    spec,
                    points,
                    workDirectory,
                    specIndex,
                    metrics);
            catch (Exception error)
            {
                writefln(
                    "FAIL: %s",
                    error.msg);
                return 2;
            }
        }

        printResult(
            "large structured GeographicLib Exact double corpus",
            doubleTargetMetres,
            metrics);

        return metrics.failures == 0 ? 0 : 1;
    }

    if (mode == "--float-structured" && args.length == 4)
    {
        foreach (specIndex, spec; specs)
        {
            const points = structuredPoints(spec);

            try
                validateSpecFloat(
                    spec,
                    points,
                    workDirectory,
                    specIndex,
                    metrics,
                    floatDiagnostics);
            catch (Exception error)
            {
                writefln(
                    "FAIL: %s",
                    error.msg);
                return 2;
            }
        }

        printResult(
            "large structured GeographicLib Exact float corpus",
            floatTargetMetres,
            metrics);
        printFloatDiagnostics(floatDiagnostics);

        return metrics.failures == 0 ? 0 : 1;
    }

    if (mode == "--random" && args.length == 5)
    {
        size_t requestedCount;

        try
            requestedCount = args[4].to!size_t;
        catch (Exception)
        {
            writeln("FAIL: random COUNT must be a positive integer");
            return 2;
        }

        if (requestedCount == 0)
        {
            writeln("FAIL: random COUNT must be greater than zero");
            return 2;
        }

        const size_t totalProfiles =
            specs.length * randomProfilesPerEllipsoid;

        const size_t pointsPerProfile =
            requestedCount / totalProfiles;
        const size_t remainder =
            requestedCount % totalProfiles;

        writefln(
            "deterministic random corpus seed: 0x%016X",
            randomCorpusSeed);
        writefln(
            "projection profiles: %s (%s per ellipsoid)",
            totalProfiles,
            randomProfilesPerEllipsoid);
        writefln(
            "requested source points: %s",
            requestedCount);

        size_t globalProfileIndex = 0;

        foreach (ellipsoidIndex, baseSpec; specs)
        {
            foreach (profileIndex; 0 .. randomProfilesPerEllipsoid)
            {
                const pointCount =
                    pointsPerProfile
                    + (globalProfileIndex < remainder ? 1 : 0);

                const spec =
                    randomProjectionSpec(
                        baseSpec,
                        ellipsoidIndex,
                        profileIndex);

                const points =
                    randomPoints(
                        spec,
                        pointCount,
                        ellipsoidIndex,
                        profileIndex);

                try
                    validateSpec(
                        spec,
                        points,
                        workDirectory,
                        globalProfileIndex,
                        metrics);
                catch (Exception error)
                {
                    writefln(
                        "FAIL: %s",
                        error.msg);
                    return 2;
                }

                ++globalProfileIndex;
            }
        }

        printResult(
            "deterministic pseudo-random GeographicLib Exact double corpus",
            doubleTargetMetres,
            metrics);

        return metrics.failures == 0 ? 0 : 1;
    }

    if (mode == "--float-random" && args.length == 5)
    {
        size_t requestedCount;

        try
            requestedCount = args[4].to!size_t;
        catch (Exception)
        {
            writeln("FAIL: float random COUNT must be a positive integer");
            return 2;
        }

        if (requestedCount == 0)
        {
            writeln("FAIL: float random COUNT must be greater than zero");
            return 2;
        }

        const size_t totalProfiles =
            specs.length * randomProfilesPerEllipsoid;

        const size_t pointsPerProfile =
            requestedCount / totalProfiles;
        const size_t remainder =
            requestedCount % totalProfiles;

        writefln(
            "deterministic float random corpus seed: 0x%016X",
            randomCorpusSeed);
        writefln(
            "projection profiles: %s (%s per ellipsoid)",
            totalProfiles,
            randomProfilesPerEllipsoid);
        writefln(
            "requested float source points: %s",
            requestedCount);

        size_t globalProfileIndex = 0;

        foreach (ellipsoidIndex, baseSpec; specs)
        {
            foreach (profileIndex; 0 .. randomProfilesPerEllipsoid)
            {
                const pointCount =
                    pointsPerProfile
                    + (globalProfileIndex < remainder ? 1 : 0);

                const spec =
                    randomProjectionSpec(
                        baseSpec,
                        ellipsoidIndex,
                        profileIndex);

                const points =
                    randomPoints(
                        spec,
                        pointCount,
                        ellipsoidIndex,
                        profileIndex);

                try
                    validateSpecFloat(
                        spec,
                        points,
                        workDirectory,
                        globalProfileIndex,
                        metrics,
                        floatDiagnostics);
                catch (Exception error)
                {
                    writefln(
                        "FAIL: %s",
                        error.msg);
                    return 2;
                }

                ++globalProfileIndex;
            }
        }

        printResult(
            "deterministic pseudo-random GeographicLib Exact float corpus",
            floatTargetMetres,
            metrics);
        printFloatDiagnostics(floatDiagnostics);

        return metrics.failures == 0 ? 0 : 1;
    }

    usage();
    return 2;
}
