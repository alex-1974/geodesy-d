module geodesy.projection.transverse_mercator_newton_validation;

import std.conv : to;
import std.math : fabs, isFinite;
import std.stdio : writefln, writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator :
    TransverseMercator,
    TransverseMercatorNewtonTrace;

enum ulong randomSeed = 0x544D5F4E4557544FUL; // "TM_NEWTO"

private struct ProjectionSpec
{
    string name;
    real a;
    real f;
    real latitudeOfNaturalOrigin;
    real longitudeOfNaturalOrigin;
    real k0;
    real falseEasting;
    real falseNorthing;
}

private ProjectionSpec[] mandatorySpecs()
{
    return [
        ProjectionSpec("WGS84", 6_378_137.0L,
            1.0L / 298.257223563L, 0.0L, 15.0L,
            0.9996L, 500_000.0L, 0.0L),
        ProjectionSpec("GRS80", 6_378_137.0L,
            1.0L / 298.257222101L, -20.0L, 15.0L,
            1.0L, 0.0L, 0.0L),
        ProjectionSpec("Airy1830", 6_377_563.396L,
            1.0L / 299.3249646L, 49.0L, 15.0L,
            0.9996012717L, 400_000.0L, -100_000.0L),
        ProjectionSpec("Bessel1841", 6_377_397.155L,
            1.0L / 299.1528128L, 10.0L, 15.0L,
            1.0L, 250_000.0L, 300_000.0L),
        ProjectionSpec("Clarke1866", 6_378_206.4L,
            1.0L / 294.9786982L, -15.0L, 15.0L,
            0.9999L, -300_000.0L, 200_000.0L),
        ProjectionSpec("International1924", 6_378_388.0L,
            1.0L / 297.0L, 30.0L, 15.0L,
            1.0001L, 100_000.0L, -500_000.0L),
        ProjectionSpec("Sphere-R6371000", 6_371_000.0L,
            0.0L, 0.0L, 15.0L,
            1.0L, 0.0L, 0.0L),
        ProjectionSpec("SyntheticF001", 6_378_137.0L,
            0.01L, 49.0L, 15.0L,
            0.9996L, 500_000.0L, 0.0L),
    ];
}

private TransverseMercator!T makeProjection(T)(
    const ProjectionSpec spec)
{
    return TransverseMercator!T.fromParameters(
        Ellipsoid!T.fromFlattening(
            cast(T) spec.a,
            cast(T) spec.f),
        Latitude!T.fromDegrees(
            cast(T) spec.latitudeOfNaturalOrigin),
        Longitude!T.fromDegrees(
            cast(T) spec.longitudeOfNaturalOrigin),
        cast(T) spec.k0,
        cast(T) spec.falseEasting,
        cast(T) spec.falseNorthing);
}

private string scalarName(T)()
{
    static if (is(T == float))
        return "float";
    else static if (is(T == double))
        return "double";
    else static if (is(T == real))
        return "real";
    else
        return T.stringof;
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

    real unitReal()
    {
        return cast(real) next()
            / 18_446_744_073_709_551_616.0L;
    }
}

private struct Stats
{
    ulong sourcePoints;
    ulong applicable;
    ulong bypassed;
    ulong failures;
    ulong[6] iterationHistogram;

    real worstResidual = 0.0L;
    real worstScaledResidual = 0.0L;
    real largestCorrection = 0.0L;

    string worstResidualProfile;
    real worstResidualLatitude;
    real worstResidualDeltaLongitude;

    string worstScaledProfile;
    real worstScaledLatitude;
    real worstScaledDeltaLongitude;

    string largestCorrectionProfile;
    real largestCorrectionLatitude;
    real largestCorrectionDeltaLongitude;
}

private void recordFailure(
    ref Stats stats,
    const string profile,
    const real latitude,
    const real deltaLongitude,
    const string reason)
{
    ++stats.failures;

    if (stats.failures <= 12)
    {
        writefln(
            "FAIL: profile=%s lat=%.18g dlon=%.18g: %s",
            profile,
            latitude,
            deltaLongitude,
            reason);
    }
}

private void observeCase(T)(
    ref Stats stats,
    const ProjectionSpec spec,
    const TransverseMercator!T projection,
    const real latitude,
    const real deltaLongitude)
{
    ++stats.sourcePoints;

    const source =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) latitude),
            Longitude!T.fromDegrees(
                cast(T) (
                    spec.longitudeOfNaturalOrigin
                    + deltaLongitude)));

    ProjectedCoordinate!T projected;

    if (!projection.tryForward(source, projected))
    {
        recordFailure(
            stats,
            spec.name,
            latitude,
            deltaLongitude,
            "tryForward rejected supported source");
        return;
    }

    GeographicCoordinate!T recovered;
    TransverseMercatorNewtonTrace trace;

    if (!projection.tryReverseNewtonTrace(
            projected,
            recovered,
            trace))
    {
        recordFailure(
            stats,
            spec.name,
            latitude,
            deltaLongitude,
            "instrumented accepted-point reverse failed");
        return;
    }

    if (!trace.newtonApplicable)
    {
        ++stats.bypassed;
        return;
    }

    ++stats.applicable;

    if (!trace.converged)
    {
        recordFailure(
            stats,
            spec.name,
            latitude,
            deltaLongitude,
            "Newton did not converge");
        return;
    }

    if (trace.iterations < 0 || trace.iterations > 5)
    {
        recordFailure(
            stats,
            spec.name,
            latitude,
            deltaLongitude,
            "iteration count outside production [0,5] bound");
        return;
    }

    if (!isFinite(trace.convergenceResidual)
        || !isFinite(trace.maximumCorrection)
        || !isFinite(trace.tauPrime))
    {
        recordFailure(
            stats,
            spec.name,
            latitude,
            deltaLongitude,
            "non-finite Newton diagnostic");
        return;
    }

    ++stats.iterationHistogram[trace.iterations];

    const real scale =
        fabs(trace.tauPrime) > 1.0L
            ? fabs(trace.tauPrime)
            : 1.0L;

    const real scaledResidual =
        trace.convergenceResidual / scale;

    if (stats.applicable == 1
        || trace.convergenceResidual > stats.worstResidual)
    {
        stats.worstResidual = trace.convergenceResidual;
        stats.worstResidualProfile = spec.name;
        stats.worstResidualLatitude = latitude;
        stats.worstResidualDeltaLongitude = deltaLongitude;
    }

    if (stats.applicable == 1
        || scaledResidual > stats.worstScaledResidual)
    {
        stats.worstScaledResidual = scaledResidual;
        stats.worstScaledProfile = spec.name;
        stats.worstScaledLatitude = latitude;
        stats.worstScaledDeltaLongitude = deltaLongitude;
    }

    if (stats.applicable == 1
        || trace.maximumCorrection > stats.largestCorrection)
    {
        stats.largestCorrection = trace.maximumCorrection;
        stats.largestCorrectionProfile = spec.name;
        stats.largestCorrectionLatitude = latitude;
        stats.largestCorrectionDeltaLongitude = deltaLongitude;
    }
}

private void printStats(
    const string suite,
    const string scalar,
    const Stats stats)
{
    writeln;
    writefln("suite: %s", suite);
    writefln("scalar: %s", scalar);
    writefln("source points: %s", stats.sourcePoints);
    writefln("Newton-applicable points: %s", stats.applicable);
    writefln("Newton-bypassed pole points: %s", stats.bypassed);

    writeln("iteration histogram:");
    foreach (i; 0 .. stats.iterationHistogram.length)
        writefln("  %s: %s", i, stats.iterationHistogram[i]);

    writefln("failures: %s", stats.failures);

    writefln(
        "worst convergence residual: %.21g",
        stats.worstResidual);
    writefln(
        "  case: %s lat=%.18g dlon=%.18g",
        stats.worstResidualProfile,
        stats.worstResidualLatitude,
        stats.worstResidualDeltaLongitude);

    writefln(
        "worst scaled residual: %.21g",
        stats.worstScaledResidual);
    writefln(
        "  case: %s lat=%.18g dlon=%.18g",
        stats.worstScaledProfile,
        stats.worstScaledLatitude,
        stats.worstScaledDeltaLongitude);

    writefln(
        "largest Newton correction: %.21g",
        stats.largestCorrection);
    writefln(
        "  case: %s lat=%.18g dlon=%.18g",
        stats.largestCorrectionProfile,
        stats.largestCorrectionLatitude,
        stats.largestCorrectionDeltaLongitude);

    writeln(stats.failures == 0 ? "RESULT: PASS" : "RESULT: FAIL");
}

private Stats runStructured(T)()
{
    Stats stats;

    foreach (const spec; mandatorySpecs())
    {
        const projection = makeProjection!T(spec);

        for (int latitude = -90; latitude <= 90; latitude += 2)
        {
            for (int deltaLongitude = -60;
                 deltaLongitude <= 60;
                 deltaLongitude += 5)
            {
                observeCase!T(
                    stats,
                    spec,
                    projection,
                    cast(real) latitude,
                    cast(real) deltaLongitude);
            }
        }

        foreach (latitude; [
            -90.0L,
            -89.999999L,
            -89.0L,
            -80.0L,
            -45.0L,
            -1.0e-9L,
            0.0L,
            1.0e-9L,
            45.0L,
            80.0L,
            89.0L,
            89.999999L,
            90.0L,
        ])
        {
            foreach (deltaLongitude; [
                -60.0L,
                -59.999999L,
                -55.0L,
                -35.0L,
                -3.0L,
                0.0L,
                3.0L,
                35.0L,
                55.0L,
                59.999999L,
                60.0L,
            ])
            {
                observeCase!T(
                    stats,
                    spec,
                    projection,
                    latitude,
                    deltaLongitude);
            }
        }
    }

    return stats;
}

private Stats runRandom(T)(const size_t pointCount)
{
    Stats stats;
    auto specs = mandatorySpecs();

    TransverseMercator!T[] projections;
    projections.reserve(specs.length);

    foreach (const spec; specs)
        projections ~= makeProjection!T(spec);

    SplitMix64 rng;
    rng.state = randomSeed;

    foreach (i; 0 .. pointCount)
    {
        const size_t profileIndex = i % specs.length;

        const real latitude =
            -90.0L + 180.0L * rng.unitReal();
        const real deltaLongitude =
            -60.0L + 120.0L * rng.unitReal();

        observeCase!T(
            stats,
            specs[profileIndex],
            projections[profileIndex],
            latitude,
            deltaLongitude);
    }

    return stats;
}

private bool runStructuredAll()
{
    bool ok = true;

    foreach (dummy; 0 .. 1)
    {
        const stats = runStructured!float();
        printStats("structured reverse Newton corpus", "float", stats);
        ok = ok && stats.failures == 0;
    }

    foreach (dummy; 0 .. 1)
    {
        const stats = runStructured!double();
        printStats("structured reverse Newton corpus", "double", stats);
        ok = ok && stats.failures == 0;
    }

    foreach (dummy; 0 .. 1)
    {
        const stats = runStructured!real();
        printStats("structured reverse Newton corpus", "real", stats);
        ok = ok && stats.failures == 0;
    }

    return ok;
}

private bool runRandomAll(const size_t pointCount)
{
    bool ok = true;

    writefln(
        "deterministic Newton random corpus seed: 0x%016X",
        randomSeed);
    writefln(
        "requested source points per scalar: %s",
        pointCount);
    writeln("mandatory projection profiles: 8");

    foreach (dummy; 0 .. 1)
    {
        const stats = runRandom!float(pointCount);
        printStats(
            "deterministic pseudo-random reverse Newton corpus",
            "float",
            stats);
        ok = ok && stats.failures == 0;
    }

    foreach (dummy; 0 .. 1)
    {
        const stats = runRandom!double(pointCount);
        printStats(
            "deterministic pseudo-random reverse Newton corpus",
            "double",
            stats);
        ok = ok && stats.failures == 0;
    }

    foreach (dummy; 0 .. 1)
    {
        const stats = runRandom!real(pointCount);
        printStats(
            "deterministic pseudo-random reverse Newton corpus",
            "real",
            stats);
        ok = ok && stats.failures == 0;
    }

    return ok;
}


private Stats runSphereStructured(T)()
{
    Stats stats;
    const spec = mandatorySpecs()[6];
    const projection = makeProjection!T(spec);

    for (int latitude = -90; latitude <= 90; latitude += 2)
    {
        for (int deltaLongitude = -60;
             deltaLongitude <= 60;
             deltaLongitude += 5)
        {
            observeCase!T(
                stats,
                spec,
                projection,
                cast(real) latitude,
                cast(real) deltaLongitude);
        }
    }

    foreach (latitude; [
        -90.0L,
        -89.999999L,
        -89.0L,
        -80.0L,
        -45.0L,
        -1.0e-9L,
        0.0L,
        1.0e-9L,
        45.0L,
        80.0L,
        89.0L,
        89.999999L,
        90.0L,
    ])
    {
        foreach (deltaLongitude; [
            -60.0L,
            -59.999999L,
            -55.0L,
            -35.0L,
            -3.0L,
            0.0L,
            3.0L,
            35.0L,
            55.0L,
            59.999999L,
            60.0L,
        ])
        {
            observeCase!T(
                stats,
                spec,
                projection,
                latitude,
                deltaLongitude);
        }
    }

    return stats;
}


private bool runSphereStructuredAll()
{
    bool ok = true;

    {
        const stats = runSphereStructured!float();
        printStats(
            "structured spherical reverse Newton corpus",
            "float",
            stats);
        ok = ok && stats.failures == 0;
    }

    {
        const stats = runSphereStructured!double();
        printStats(
            "structured spherical reverse Newton corpus",
            "double",
            stats);
        ok = ok && stats.failures == 0;
    }

    {
        const stats = runSphereStructured!real();
        printStats(
            "structured spherical reverse Newton corpus",
            "real",
            stats);
        ok = ok && stats.failures == 0;
    }

    return ok;
}


void main(string[] args)
{
    if (args.length == 2 && args[1] == "--sphere-structured")
    {
        if (!runSphereStructuredAll())
            throw new Exception(
                "structured spherical Newton validation failed");

        writeln;
        writeln("OVERALL RESULT: PASS");
        return;
    }

    if (args.length == 2 && args[1] == "--structured")
    {
        if (!runStructuredAll())
            throw new Exception(
                "structured Newton validation failed");

        writeln;
        writeln("OVERALL RESULT: PASS");
        return;
    }

    if (args.length == 3 && args[1] == "--random")
    {
        const size_t pointCount = to!size_t(args[2]);

        if (!runRandomAll(pointCount))
            throw new Exception(
                "random Newton validation failed");

        writeln;
        writeln("OVERALL RESULT: PASS");
        return;
    }

    writeln("usage:");
    writeln(
        "  transverse-mercator-newton-validation --sphere-structured");
    writeln(
        "  transverse-mercator-newton-validation --structured");
    writeln(
        "  transverse-mercator-newton-validation --random COUNT");
    throw new Exception("invalid arguments");
}
