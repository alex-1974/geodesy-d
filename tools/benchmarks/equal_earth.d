// Equal Earth release-mode throughput probe. Measure forward and reverse separately.
// Four distinct inputs avoid benchmarking a single invariant projection result.
module equal_earth_benchmark;

import geodesy;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.stdio : writeln;

void main()
{
    const projection = EqualEarth!double.fromParameters(
        wgs84!double(), Longitude!double.fromDegrees(0.0), 0.0, 0.0);

    enum size_t iterations = 1_000_000;
    GeographicCoordinate!double[4] inputs;
    inputs[0] = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    inputs[1] = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-33.8688),
        Longitude!double.fromDegrees(151.2093));
    inputs[2] = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(40.7128),
        Longitude!double.fromDegrees(-74.0060));
    inputs[3] = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-12.0464),
        Longitude!double.fromDegrees(-77.0428));

    ProjectedCoordinate!double[4] mapped;
    foreach (i; 0 .. inputs.length)
        assert(projection.tryForward(inputs[i], mapped[i]));

    double forwardChecksum = 0.0;
    auto forwardTimer = StopWatch(AutoStart.yes);
    foreach (i; 0 .. iterations)
    {
        ProjectedCoordinate!double value;
        if (!projection.tryForward(inputs[i % inputs.length], value))
            assert(0);
        forwardChecksum += value.easting;
    }
    forwardTimer.stop();

    double reverseChecksum = 0.0;
    auto reverseTimer = StopWatch(AutoStart.yes);
    foreach (i; 0 .. iterations)
    {
        GeographicCoordinate!double value;
        if (!projection.tryReverse(mapped[i % mapped.length], value))
            assert(0);
        reverseChecksum += value.latitude.radians;
    }
    reverseTimer.stop();

    writeln("mode=forward operations=", iterations,
        " elapsed_seconds=", forwardTimer.peek.total!"hnsecs" / 10_000_000.0,
        " checksum=", forwardChecksum);
    writeln("mode=reverse operations=", iterations,
        " elapsed_seconds=", reverseTimer.peek.total!"hnsecs" / 10_000_000.0,
        " checksum=", reverseChecksum);
}
