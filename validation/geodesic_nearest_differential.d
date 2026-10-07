module geodesic_nearest_differential;

import geodesy;
import std.math : PI, abs;
import std.stdio : writefln, writeln;

extern(C)
int geodesic_nearest_reference(
    double a, double f,
    double latA, double lonA,
    double latB, double lonB,
    double latC, double lonC,
    double* footLat, double* footLon,
    double* alongTrack, double* signedCrossTrack,
    double* nearestLat, double* nearestLon,
    double* nearestDistance, int* location);

private double wrapPi(double x)
{
    const double tau = 2.0 * cast(double) PI;
    x %= tau;
    if (x >= cast(double) PI) x -= tau;
    if (x < -cast(double) PI) x += tau;
    return x;
}

private struct Case
{
    string name;
    double latA, lonA, latB, lonB, latC, lonC;
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

    size_t failures;

    foreach (item; cases)
    {
        const a = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(item.latA),
            Longitude!double.fromDegrees(item.lonA));
        const b = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(item.latB),
            Longitude!double.fromDegrees(item.lonB));
        const c = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(item.latC),
            Longitude!double.fromDegrees(item.lonC));

        GeodesicSegmentNearestResult!double actual;

        if (!solver.tryNearestPointOnSegment(a, b, c, actual))
        {
            writefln("FAIL %-18s production solver failed", item.name);
            ++failures;
            continue;
        }

        double footLat, footLon, along, cross;
        double nearestLat, nearestLon, nearestDistance;
        int location;

        if (!geodesic_nearest_reference(
                solver.ellipsoid.semiMajorAxis,
                solver.ellipsoid.flattening,
                a.latitude.radians, a.longitude.radians,
                b.latitude.radians, b.longitude.radians,
                c.latitude.radians, c.longitude.radians,
                &footLat, &footLon, &along, &cross,
                &nearestLat, &nearestLon, &nearestDistance, &location))
        {
            writefln("FAIL %-18s GeographicLib failed", item.name);
            ++failures;
            continue;
        }

        const double footLatErr =
            abs(actual.intercept.latitude.radians - footLat);
        const double footLonErr =
            abs(wrapPi(actual.intercept.longitude.radians - footLon));
        const double alongErr =
            abs(actual.alongTrackDistance - along);
        const double crossErr =
            abs(actual.signedCrossTrackDistance - cross);
        const double nearestLatErr =
            abs(actual.nearestPoint.latitude.radians - nearestLat);
        const double nearestLonErr =
            abs(wrapPi(actual.nearestPoint.longitude.radians - nearestLon));
        const double nearestDistanceErr =
            abs(actual.nearestDistance - nearestDistance);

        const bool pass =
            footLatErr < 2e-12
            && footLonErr < 2e-12
            && alongErr < 2e-5
            && crossErr < 2e-5
            && nearestLatErr < 2e-12
            && nearestLonErr < 2e-12
            && nearestDistanceErr < 2e-5
            && cast(int) actual.location == location;

        writefln(
            "%s %-18s foot=(%.2e,%.2e) along=%.3e cross=%.3e "
            ~ "nearest=(%.2e,%.2e,%.3e) location=%s",
            pass ? "PASS" : "FAIL",
            item.name,
            footLatErr, footLonErr, alongErr, crossErr,
            nearestLatErr, nearestLonErr, nearestDistanceErr,
            actual.location);

        if (!pass)
            ++failures;
    }

    const point =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));

    GeodesicSegmentNearestResult!double degenerate;
    if (solver.tryNearestPointOnSegment(point, point, point, degenerate))
    {
        writeln("FAIL degenerate segment accepted");
        ++failures;
    }

    if (failures != 0)
    {
        writefln("GEODESIC NEAREST DIFFERENTIAL FAIL: %s case(s)", failures);
        assert(0);
    }

    writeln("GEODESIC NEAREST DIFFERENTIAL PASS");
}
