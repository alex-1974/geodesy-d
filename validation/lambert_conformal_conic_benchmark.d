module lambert_conformal_conic_benchmark;

import core.time : MonoTime;
import std.conv : to;
import std.stdio : writefln, writeln;

import geodesy;

extern(C) int lcc_bench_proj_init();
extern(C) void lcc_bench_proj_destroy();
extern(C) double lcc_bench_proj_forward(
    double latitudeDegrees,
    double longitudeDegrees,
    double* northing);

private enum size_t corpusSize = 1024;

private struct Point
{
    double latitude;
    double longitude;
}

private Point[corpusSize] makeCorpus()
{
    Point[corpusSize] values;

    foreach (i; 0 .. corpusSize)
    {
        values[i].latitude =
            5.0 + 70.0 * cast(double)((i * 37) % corpusSize) / corpusSize;

        values[i].longitude =
            -179.0 + 358.0 * cast(double)((i * 73) % corpusSize) / corpusSize;
    }

    return values;
}

private ulong elapsedNs(MonoTime start, MonoTime stop)
{
    return cast(ulong)(stop - start).total!"nsecs";
}

private void report(
    string label,
    ulong elapsed,
    size_t operations,
    double checksum)
{
    writefln(
        "%-28s %12.3f ns/op  checksum=%.17g",
        label,
        cast(double) elapsed / operations,
        checksum);
}

void main(string[] args)
{
    size_t iterations = 200_000;

    if (args.length > 1)
        iterations = args[1].to!size_t;

    if (iterations < corpusSize)
        iterations = corpusSize;

    const projection =
        LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0,
            0.0);

    const corpus = makeCorpus();

    writeln("Lambert Conformal Conic performance characterization");
    writeln("iterations=", iterations);
    writeln();

    double checksum = 0.0;

    auto start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const point = corpus[i % corpusSize];

        const projected = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(point.latitude),
                Longitude!double.fromDegrees(point.longitude)));

        checksum += projected.easting * 1e-9 + projected.northing * 1e-10;
    }

    auto stop = MonoTime.currTime;

    report(
        "geodesy-d forward",
        elapsedNs(start, stop),
        iterations,
        checksum);

    if (!lcc_bench_proj_init())
        throw new Exception("PROJ benchmark initialization failed");

    scope(exit)
        lcc_bench_proj_destroy();

    checksum = 0.0;

    start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const point = corpus[i % corpusSize];

        double northing;

        const double easting =
            lcc_bench_proj_forward(
                point.latitude,
                point.longitude,
                &northing);

        checksum += easting * 1e-9 + northing * 1e-10;
    }

    stop = MonoTime.currTime;

    report(
        "PROJ forward",
        elapsedNs(start, stop),
        iterations,
        checksum);
}
