module lambert_azimuthal_equal_area_benchmark;

import core.time : MonoTime;
import std.conv : to;
import std.stdio : writefln, writeln;

import geodesy;

extern(C) int laea_bench_proj_init();
extern(C) void laea_bench_proj_destroy();
extern(C) double laea_bench_proj_forward(
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
            -80.0
            + 160.0
                * cast(double)((i * 37) % corpusSize)
                / corpusSize;

        values[i].longitude =
            -179.0
            + 358.0
                * cast(double)((i * 73) % corpusSize)
                / corpusSize;
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
        LambertAzimuthalEqualArea!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(52.0),
            Longitude!double.fromDegrees(10.0),
            4_321_000.0,
            3_210_000.0);

    const corpus = makeCorpus();

    writeln("Lambert Azimuthal Equal Area performance characterization");
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

        checksum +=
            projected.easting * 1e-9
            + projected.northing * 1e-10;
    }

    auto stop = MonoTime.currTime;

    report(
        "geodesy-d forward",
        elapsedNs(start, stop),
        iterations,
        checksum);

    if (!laea_bench_proj_init())
        throw new Exception("PROJ benchmark initialization failed");

    scope(exit)
        laea_bench_proj_destroy();

    checksum = 0.0;
    start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const point = corpus[i % corpusSize];
        double northing;

        const double easting =
            laea_bench_proj_forward(
                point.latitude,
                point.longitude,
                &northing);

        checksum +=
            easting * 1e-9
            + northing * 1e-10;
    }

    stop = MonoTime.currTime;

    report(
        "PROJ forward",
        elapsedNs(start, stop),
        iterations,
        checksum);
}
