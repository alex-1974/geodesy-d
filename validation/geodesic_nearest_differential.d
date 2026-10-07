module geodesic_nearest_differential;

import geodesy;

import std.math : PI, abs;
import std.stdio : writefln, writeln;

extern(C)
int m5_47_reference(
    double a,
    double f,
    double latA,
    double lonA,
    double latB,
    double lonB,
    double latC,
    double lonC,
    double* footLat,
    double* footLon,
    double* alongTrack,
    double* signedCrossTrack,
    double* segmentNearestLat,
    double* segmentNearestLon,
    double* segmentNearestDistance,
    int* segmentClass);

private double wrapPi(double x)
{
    const double tau = 2.0 * cast(double) PI;
    x %= tau;
    if (x >= cast(double) PI) x -= tau;
    if (x < -cast(double) PI) x += tau;
    return x;
}

private int referenceKind(const GeodesicSegmentNearestKind kind)
{
    final switch (kind)
    {
        case GeodesicSegmentNearestKind.invalid:
            return -1;
        case GeodesicSegmentNearestKind.start:
            return 1;
        case GeodesicSegmentNearestKind.interior:
            return 0;
        case GeodesicSegmentNearestKind.end:
            return 2;
    }
}

private struct Case
{
    string name;
    double latA;
    double lonA;
    double latB;
    double lonB;
    double latC;
    double lonC;
}

void main()
{
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257223563));

    Case[] cases = [
        Case("ordinary interior", 48.0, 10.0, 48.0, 20.0, 49.2, 15.0),
        Case("right side", 40.0, -75.0, 42.0, -60.0, 38.0, -66.0),
        Case("before start", 48.0, 10.0, 48.0, 12.0, 48.4, 8.0),
        Case("after end", 48.0, 10.0, 48.0, 12.0, 47.7, 14.0),
        Case("antimeridian", 15.0, 175.0, 18.0, -175.0, 20.0, 179.0),
        Case("near equator", 0.0, -20.0, 0.0, 20.0, -2.0, 3.0),
        Case("on track", 0.0, -20.0, 0.0, 20.0, 0.0, 3.0),
        Case("at start", 10.0, 10.0, 12.0, 20.0, 10.0, 10.0),
        Case("at end", 10.0, 10.0, 12.0, 20.0, 12.0, 20.0),
        Case("reversed track", 42.0, -60.0, 40.0, -75.0, 38.0, -66.0),
    ];

    size_t failures = 0;

    foreach (item; cases)
    {
        const a =
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(item.latA),
                Longitude!double.fromDegrees(item.lonA));

        const b =
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(item.latB),
                Longitude!double.fromDegrees(item.lonB));

        const target =
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(item.latC),
                Longitude!double.fromDegrees(item.lonC));

        GeodesicSegmentNearestResult!double actual;

        if (!tryNearestPointOnSegment(
                solver,
                a,
                b,
                target,
                actual))
        {
            writefln("FAIL %-18s public solver failed", item.name);
            ++failures;
            continue;
        }

        double rFootLat;
        double rFootLon;
        double rAlong;
        double rCross;
        double rNearestLat;
        double rNearestLon;
        double rNearestDistance;
        int rKind;

        const int ok =
            m5_47_reference(
                solver.ellipsoid.semiMajorAxis,
                solver.ellipsoid.flattening,
                a.latitude.radians,
                a.longitude.radians,
                b.latitude.radians,
                b.longitude.radians,
                target.latitude.radians,
                target.longitude.radians,
                &rFootLat,
                &rFootLon,
                &rAlong,
                &rCross,
                &rNearestLat,
                &rNearestLon,
                &rNearestDistance,
                &rKind);

        if (!ok)
        {
            writefln("FAIL %-18s GeographicLib oracle failed", item.name);
            ++failures;
            continue;
        }

        const double footLatError =
            abs(actual.supportingFoot.latitude.radians - rFootLat);

        const double footLonError =
            abs(wrapPi(
                actual.supportingFoot.longitude.radians
                    - rFootLon));

        const double nearestLatError =
            abs(actual.nearestPoint.latitude.radians - rNearestLat);

        const double nearestLonError =
            abs(wrapPi(
                actual.nearestPoint.longitude.radians
                    - rNearestLon));

        const double alongError =
            abs(actual.alongTrack - rAlong);

        const double crossError =
            abs(actual.signedCrossTrack - rCross);

        const double distanceError =
            abs(actual.nearestDistance - rNearestDistance);

        const bool pass =
            actual.isValid
            && footLatError < 2.0e-12
            && footLonError < 2.0e-12
            && nearestLatError < 2.0e-12
            && nearestLonError < 2.0e-12
            && alongError < 2.0e-5
            && crossError < 2.0e-5
            && distanceError < 2.0e-5
            && referenceKind(actual.kind) == rKind;

        writefln(
            "%s %-18s foot=(%.2e,%.2e) nearest=(%.2e,%.2e) "
            ~ "along=%.3e cross=%.3e distance=%.3e kind=%s",
            pass ? "PASS" : "FAIL",
            item.name,
            footLatError,
            footLonError,
            nearestLatError,
            nearestLonError,
            alongError,
            crossError,
            distanceError,
            actual.kind);

        if (!pass)
            ++failures;
    }

    const duplicate =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(5.0),
            Longitude!double.fromDegrees(6.0));

    const target =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(7.0),
            Longitude!double.fromDegrees(8.0));

    GeodesicSegmentNearestResult!double invalidResult;

    if (tryNearestPointOnSegment(
            solver,
            duplicate,
            duplicate,
            target,
            invalidResult)
        || invalidResult.isValid)
    {
        writeln("FAIL degenerate segment should be rejected");
        ++failures;
    }

    if (failures != 0)
    {
        writefln(
            "GEODESIC NEAREST DIFFERENTIAL FAIL: %s case(s)",
            failures);
        assert(0);
    }

    writeln("GEODESIC NEAREST DIFFERENTIAL PASS");
}
