module rhumb_benchmark;

import core.time : MonoTime;
import std.conv : to;
import std.stdio : writefln, writeln;

import geodesy;

extern(C) double rhumb_bench_geographiclib_inverse(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double* bearing);

extern(C) double rhumb_bench_geographiclib_direct(
    double lat,
    double lon,
    double bearing,
    double distance,
    double* lon2);

private enum size_t corpusSize = 1024;

private struct Pair
{
    double lat1;
    double lon1;
    double lat2;
    double lon2;
}

private Pair[corpusSize] makeCorpus()
{
    Pair[corpusSize] values;
    foreach (i; 0 .. corpusSize)
    {
        const double u = cast(double)i / corpusSize;
        values[i].lat1 = -75.0 + 150.0 * u;
        values[i].lat2 = -70.0 + 140.0 * cast(double)((i * 37) % corpusSize) / corpusSize;
        values[i].lon1 = -179.0 + 358.0 * cast(double)((i * 73) % corpusSize) / corpusSize;
        values[i].lon2 = -179.0 + 358.0 * cast(double)((i * 151) % corpusSize) / corpusSize;
    }
    return values;
}

private ulong elapsedNs(MonoTime start, MonoTime stop)
{
    return cast(ulong)(stop - start).total!"nsecs";
}

private void report(string label, ulong elapsed, size_t operations, double checksum)
{
    writefln("%-30s %12.3f ns/op  checksum=%.17g",
        label,
        cast(double)elapsed / operations,
        checksum);
}

void main(string[] args)
{
    size_t iterations = 200_000;
    if (args.length > 1)
        iterations = args[1].to!size_t;
    if (iterations < corpusSize)
        iterations = corpusSize;

    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    const corpus = makeCorpus();

    writeln("Rhumb PS-G-style performance characterization");
    writeln("iterations=", iterations);
    writeln();

    double checksum = 0.0;
    auto start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const p = corpus[i % corpusSize];
        const r = solver.inverse(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(p.lat1),
                Longitude!double.fromDegrees(p.lon1)),
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(p.lat2),
                Longitude!double.fromDegrees(p.lon2)));
        checksum += r.distance * 1e-9 + r.bearing.degrees * 1e-6;
    }
    auto stop = MonoTime.currTime;
    report("geodesy-d inverse", elapsedNs(start, stop), iterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const p = corpus[i % corpusSize];
        double bearing;
        const double distance = rhumb_bench_geographiclib_inverse(
            p.lat1, p.lon1, p.lat2, p.lon2, &bearing);
        checksum += distance * 1e-9 + bearing * 1e-6;
    }
    stop = MonoTime.currTime;
    report("GeographicLib inverse", elapsedNs(start, stop), iterations, checksum);

    const auto base = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0));
    const auto line = solver.line(base, Angle!double.fromDegrees(73.0));

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const double distance = 10.0 + cast(double)(i % corpusSize) * 1000.0;
        const auto r = line.position(distance);
        checksum += r.position.latitude.degrees * 1e-3
            + r.position.longitude.degrees * 1e-6;
    }
    stop = MonoTime.currTime;
    report("geodesy-d line position", elapsedNs(start, stop), iterations, checksum);

    checksum = 0.0;
    start = MonoTime.currTime;
    foreach (i; 0 .. iterations)
    {
        const double distance = 10.0 + cast(double)(i % corpusSize) * 1000.0;
        double lon2;
        const double lat2 = rhumb_bench_geographiclib_direct(
            48.0, 16.0, 73.0, distance, &lon2);
        checksum += lat2 * 1e-3 + lon2 * 1e-6;
    }
    stop = MonoTime.currTime;
    report("GeographicLib direct", elapsedNs(start, stop), iterations, checksum);
}
