// Release-mode Equal Earth baseline; deterministic, no heap in measured loop.
// Build e.g. dmd -O -release -inline -i -Isource -of=bench tools/benchmarks/equal_earth.d
module equal_earth_benchmark;
import geodesy;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.stdio : writeln;

void main()
{
    auto projection = EqualEarth!double.fromParameters(
        wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
    enum size_t iterations = 1_000_000;
    const input = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    auto output = projection.forward(input);
    double checksum = 0;
    auto timer = StopWatch(AutoStart.yes);
    foreach (i; 0 .. iterations)
    {
        ProjectedCoordinate!double mapped;
        if (!projection.tryForward(input, mapped))
            assert(0);
        checksum += mapped.easting;
        GeographicCoordinate!double restored;
        if (!projection.tryReverse(output, restored))
            assert(0);
        checksum += restored.latitude.radians;
    }
    timer.stop();
    writeln("operations=", iterations * 2,
            " elapsed_seconds=", timer.peek.total!"hnsecs" / 10_000_000.0,
            " checksum=", checksum);
}
