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
import std.math : fabs, isFinite, sqrt;
import std.path : buildPath;
import std.process : executeShell;
import std.stdio : File, writefln, writeln;
import std.string : indexOf, split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private enum double targetMetres = 1.0e-3;

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


private void printResult(
    const string suiteName,
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
        "outside 1 mm target: %s",
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


private void usage()
{
    writeln(
        "usage: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --structured");
    writeln(
        "   or: transverse-mercator-exact-corpus "
        ~ "--work-dir DIR --random COUNT");
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
            metrics);

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
            metrics);

        return metrics.failures == 0 ? 0 : 1;
    }

    usage();
    return 2;
}
