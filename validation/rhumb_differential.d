module rhumb_differential;

import std.conv : to;
import std.format : format;
import std.math : fabs;
import std.process : executeShell;
import std.stdio : writeln;
import std.string : split, strip;

import geodesy;

private enum double distanceTolerance = 0.02;
private enum double angularTolerance = 2e-8;

private struct Reference
{
    double first;
    double second;
}

private double normalizeDegrees(double value)
{
    while (value >= 180.0) value -= 360.0;
    while (value < -180.0) value += 360.0;
    return value;
}

private double longitudeError(double a, double b)
{
    return fabs(normalizeDegrees(a - b));
}

private Reference runOracle(
    string oracle,
    string mode,
    double a,
    double f,
    double p1,
    double p2,
    double p3,
    double p4)
{
    const output = executeShell(format(
        "%s %s %.17g %.17g %.17g %.17g %.17g %.17g",
        oracle, mode, a, f, p1, p2, p3, p4));

    if (output.status != 0)
        throw new Exception("GeographicLib Rhumb oracle failed: " ~ output.output);

    const fields = output.output.strip.split;
    if (fields.length != 3 || fields[0] != "OK")
        throw new Exception("unexpected Rhumb oracle output: " ~ output.output);

    return Reference(fields[1].to!double, fields[2].to!double);
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private void validatePair(
    string oracle,
    Ellipsoid!double ellipsoid,
    double lat1,
    double lon1,
    double lat2,
    double lon2)
{
    const solver = Rhumb!double.fromEllipsoid(ellipsoid);
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat1),
        Longitude!double.fromDegrees(lon1));
    const end = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat2),
        Longitude!double.fromDegrees(lon2));

    const ours = solver.inverse(start, end);
    const ref = runOracle(
        oracle,
        "inverse",
        ellipsoid.semiMajorAxis,
        ellipsoid.flattening,
        lat1, lon1, lat2, lon2);

    require(
        fabs(ours.distance - ref.first) <= distanceTolerance,
        format("inverse distance mismatch %.12g/%.12g -> %.12g/%.12g: %.17g",
            lat1, lon1, lat2, lon2, ours.distance - ref.first));

    require(
        fabs(normalizeDegrees(ours.bearing.degrees - ref.second))
            <= angularTolerance,
        "inverse bearing mismatch");

    const direct = solver.direct(
        start,
        ours.bearing,
        ours.distance);

    require(
        fabs(direct.position.latitude.degrees - lat2) <= angularTolerance,
        "direct latitude roundtrip mismatch");
    require(
        longitudeError(direct.position.longitude.degrees, lon2)
            <= angularTolerance,
        "direct longitude roundtrip mismatch");

    const refDirect = runOracle(
        oracle,
        "direct",
        ellipsoid.semiMajorAxis,
        ellipsoid.flattening,
        lat1, lon1, ref.second, ref.first);

    require(
        fabs(direct.position.latitude.degrees - refDirect.first)
            <= angularTolerance,
        "direct latitude oracle mismatch");
    require(
        longitudeError(direct.position.longitude.degrees, refDirect.second)
            <= angularTolerance,
        "direct longitude oracle mismatch");

    const line = solver.line(start, ours.bearing);
    const lineResult = line.position(ours.distance);
    const refLine = runOracle(
        oracle,
        "line",
        ellipsoid.semiMajorAxis,
        ellipsoid.flattening,
        lat1, lon1, ref.second, ref.first);

    require(
        fabs(lineResult.position.latitude.degrees - refLine.first)
            <= angularTolerance,
        "line latitude oracle mismatch");
    require(
        longitudeError(lineResult.position.longitude.degrees, refLine.second)
            <= angularTolerance,
        "line longitude oracle mismatch");
}

void main(string[] args)
{
    if (args.length != 2)
        throw new Exception("usage: rhumb_differential GEOGRAPHICLIB_ORACLE");

    const oracle = args[1];

    const Ellipsoid!double[] ellipsoids = [
        wgs84!double(),
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0, 298.257222101),
        Ellipsoid!double.fromInverseFlattening(
            6_377_563.396, 299.3249646),
        Ellipsoid!double.sphere(6_371_000.0),
    ];

    foreach (ellipsoid; ellipsoids)
    {
        validatePair(oracle, ellipsoid, 48.20849, 16.37208, 35.6762, 139.6503);
        validatePair(oracle, ellipsoid, 10.0, 170.0, 10.0, -170.0);
        validatePair(oracle, ellipsoid, -40.0, -20.0, 30.0, -20.0);
        validatePair(oracle, ellipsoid, 80.0, 15.0, 89.0, 179.0);
        validatePair(oracle, ellipsoid, -75.0, 179.0, -82.0, -179.0);
        validatePair(oracle, ellipsoid, 0.0, 0.0, 0.0, 180.0);
    }

    // Signed direct distance and prepared-line direction.
    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(50.0),
        Longitude!double.fromDegrees(10.0));
    const bearing = Angle!double.fromDegrees(33.0);
    const ours = solver.direct(start, bearing, -2_000_000.0);
    const ref = runOracle(
        oracle, "direct",
        6_378_137.0, 1.0 / 298.257223563,
        50.0, 10.0, 33.0, -2_000_000.0);

    require(
        fabs(ours.position.latitude.degrees - ref.first) <= angularTolerance,
        "negative-distance direct latitude mismatch");
    require(
        longitudeError(ours.position.longitude.degrees, ref.second)
            <= angularTolerance,
        "negative-distance direct longitude mismatch");

    writeln("PASS: Rhumb / RhumbLine GeographicLib differential validation");
}
