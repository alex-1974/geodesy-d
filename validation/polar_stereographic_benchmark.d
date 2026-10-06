/**
 * PS-G local performance characterization.
 *
 * The benchmark is intentionally not a CI timing gate.  Run it on controlled
 * hardware through tools/benchmark-polar-stereographic.sh.
 */
module polar_stereographic_benchmark;

import core.time : MonoTime;
import std.conv : to;
import std.format : writefln;
import std.math : fabs;
import std.stdio : writeln;

import geodesy;

extern(C) double ps_bench_geographiclib_forward(
    double lat,
    double lon,
    double* northing);

extern(C) double ps_bench_geographiclib_reverse(
    double easting,
    double northing,
    double* lon);

extern(C) double ps_bench_proj_forward(
    double lat,
    double lon,
    double* northing);

extern(C) double ps_bench_proj_reverse(
    double easting,
    double northing,
    double* lon);

private enum size_t corpusSize = 1024;

private struct Input
{
    double lat;
    double lon;
}

private Input[corpusSize] makeCorpus()
{
    Input[corpusSize] values;

    foreach (i; 0 .. corpusSize)
    {
        const double u = cast(double) i / cast(double) corpusSize;
        values[i].lat = 65.0 + 24.999 * u;
        values[i].lon = -179.0 + 358.0 * (
            cast(double) ((i * 73) % corpusSize)
                / cast(double) corpusSize);
    }

    return values;
}

private ulong elapsedNs(MonoTime start, MonoTime stop)
{
    return cast(ulong) (stop - start).total!"nsecs";
}

private void report(
    string label,
    ulong elapsed,
    size_t operations,
    double checksum)
{
    const double nsPerOperation =
        cast(double) elapsed / cast(double) operations;

    writefln(
        "%-30s %12.3f ns/op  checksum=%.17g",
        label,
        nsPerOperation,
        checksum);
}

void main(string[] args)
{
    size_t iterations = 200_000;
    if (args.length > 1)
        iterations = args[1].to!size_t;

    if (iterations < corpusSize)
        iterations = corpusSize;

    const auto projection = PolarStereographic!double.fromParameters(
        wgs84!double(),
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0),
        0.994,
        2_000_000.0,
        2_000_000.0);

    const auto corpus = makeCorpus();

    ProjectedCoordinate!double[corpusSize] projected;
    foreach (i, input; corpus)
    {
        projected[i] = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(input.lat),
                Longitude!double.fromDegrees(input.lon)));
    }

    writeln("Polar Stereographic PS-G performance characterization");
    writeln("iterations=", iterations);
    writeln();

    double checksum = 0.0;
    auto start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const auto input = corpus[i % corpusSize];
        const auto result = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(input.lat),
                Longitude!double.fromDegrees(input.lon)));
        checksum += result.easting * 1e-9 + result.northing * 1e-12;
    }
    auto stop = MonoTime.currTime;
    report("geodesy-d forward", elapsedNs(start, stop), iterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const auto input = projected[i % corpusSize];
        const auto result = projection.reverse(input);
        checksum += result.latitude.degrees * 1e-3
            + result.longitude.degrees * 1e-6;
    }
    stop = MonoTime.currTime;
    report("geodesy-d reverse", elapsedNs(start, stop), iterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const auto input = corpus[i % corpusSize];
        double northing;
        const double easting =
            ps_bench_geographiclib_forward(input.lat, input.lon, &northing);
        checksum += easting * 1e-9 + northing * 1e-12;
    }
    stop = MonoTime.currTime;
    report("GeographicLib forward", elapsedNs(start, stop), iterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const auto input = projected[i % corpusSize];
        double lon;
        const double lat = ps_bench_geographiclib_reverse(
            input.easting,
            input.northing,
            &lon);
        checksum += lat * 1e-3 + lon * 1e-6;
    }
    stop = MonoTime.currTime;
    report("GeographicLib reverse", elapsedNs(start, stop), iterations, checksum);

    /*
     * PROJ context/projection construction is intentionally included here.
     * This characterizes the naïve one-shot API and is not directly
     * comparable to prepared geodesy-d/GeographicLib hot paths.  It is kept
     * as a useful upper-level consumer reference.
     */
    const size_t projIterations =
        iterations > 20_000 ? 20_000 : iterations;

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. projIterations)
    {
        const auto input = corpus[i % corpusSize];
        double northing;
        const double easting =
            ps_bench_proj_forward(input.lat, input.lon, &northing);
        checksum += easting * 1e-9 + northing * 1e-12;
    }
    stop = MonoTime.currTime;
    report("PROJ one-shot forward", elapsedNs(start, stop), projIterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. projIterations)
    {
        const auto input = projected[i % corpusSize];
        double lon;
        const double lat = ps_bench_proj_reverse(
            input.easting,
            input.northing,
            &lon);
        checksum += lat * 1e-3 + lon * 1e-6;
    }
    stop = MonoTime.currTime;
    report("PROJ one-shot reverse", elapsedNs(start, stop), projIterations, checksum);

    // Keep references observably live under aggressive optimization.
    if (fabs(checksum) == double.infinity)
        writeln("unreachable");
}
