module geodesic_all_intersection_differential;

import geodesy;

import std.math : abs;
import std.stdio : writefln, writeln;

extern(C)
int m5_106_reference(
    double,double,
    double,double,double,
    double,double,double,
    double,double,double,
    size_t,
    size_t*,
    double*,double*,int*);

private struct Case
{
    string name;
    bool sphere;
    double latX, lonX, aziX;
    double latY, lonY, aziY;
    double p0x, p0y, radius;
}

private GeographicCoordinate!double gc(double lat, double lon)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
}

private GeodesicIntersectionCoincidence mapCoincidence(int value)
{
    return value > 0
        ? GeodesicIntersectionCoincidence.parallel
        : value < 0
            ? GeodesicIntersectionCoincidence.antiparallel
            : GeodesicIntersectionCoincidence.distinct;
}

private bool runCase(const Case item)
{
    const ellipsoid =
        item.sphere
            ? Ellipsoid!double.sphere(6_371_000.0)
            : wgs84!double();

    const solver =
        Geodesic!double.fromEllipsoid(ellipsoid);

    GeodesicIntersectionSolver!double intersector;

    if (!GeodesicIntersectionSolver!double.tryFromGeodesic(
            solver,
            intersector))
    {
        writefln("FAIL %-31s prepare", item.name);
        return false;
    }

    GeodesicLine!double firstLine;
    GeodesicLine!double secondLine;

    if (!GeodesicLine!double.tryFromGeodesic(
            solver,
            gc(item.latX,item.lonX),
            Angle!double.fromDegrees(item.aziX),
            firstLine)
        || !GeodesicLine!double.tryFromGeodesic(
            solver,
            gc(item.latY,item.lonY),
            Angle!double.fromDegrees(item.aziY),
            secondLine))
    {
        writefln("FAIL %-31s lines", item.name);
        return false;
    }

    GeodesicIntersectionWorkspaceEntry!double[64] starts;
    bool[64] skip;
    GeodesicIntersectionWorkspaceEntry!double[128] found;
    GeodesicIntersectionWorkspaceEntry!double[64] centers;
    GeodesicIntersectionWorkspace!double workspace;

    if (!GeodesicIntersectionWorkspace!double.tryFromStorage(
            starts[],
            skip[],
            found[],
            centers[],
            workspace))
    {
        writefln("FAIL %-31s workspace", item.name);
        return false;
    }

    GeodesicIntersectionPoint!double[64] actual;
    GeodesicIntersectionEnumeration enumeration;

    if (!tryAllGeodesicIntersections(
            intersector,
            firstLine,
            secondLine,
            item.radius,
            item.p0x,
            item.p0y,
            actual[],
            workspace,
            enumeration))
    {
        writefln(
            "FAIL %-31s enumerate status=%s tiles=%s found=%s",
            item.name,
            enumeration.status,
            enumeration.requiredTiles,
            enumeration.minimumFoundCapacity);
        return false;
    }

    double[64] xs;
    double[64] ys;
    int[64] cs;
    size_t expectedCount;

    const int rc =
        m5_106_reference(
            ellipsoid.semiMajorAxis,
            ellipsoid.flattening,
            item.latX,item.lonX,item.aziX,
            item.latY,item.lonY,item.aziY,
            item.p0x,item.p0y,item.radius,
            64,
            &expectedCount,
            xs.ptr,ys.ptr,cs.ptr);

    if (rc != 1
        || enumeration.total != expectedCount
        || enumeration.written != expectedCount
        || enumeration.truncated)
    {
        writefln(
            "FAIL %-31s count total=%s expected=%s rc=%s",
            item.name,
            enumeration.total,
            expectedCount,
            rc);
        return false;
    }

    bool[64] matched;
    double maxError = 0.0;

    foreach (point; actual[0 .. enumeration.written])
    {
        size_t bestIndex = size_t.max;
        double bestError = double.infinity;

        foreach (i; 0 .. expectedCount)
        {
            if (matched[i]
                || point.coincidence != mapCoincidence(cs[i]))
                continue;

            const double error =
                abs(point.distanceOnFirst - xs[i])
                + abs(point.distanceOnSecond - ys[i]);

            if (error < bestError)
            {
                bestError = error;
                bestIndex = i;
            }
        }

        const double tolerance =
            2e-4 > 128.0 * double.epsilon
                * (1.0 + point.referenceDistance)
                ? 2e-4
                : 128.0 * double.epsilon
                    * (1.0 + point.referenceDistance);

        if (bestIndex == size_t.max
            || bestError > tolerance)
        {
            writefln(
                "FAIL %-31s unmatched err=%.3e",
                item.name,
                bestError);
            return false;
        }

        matched[bestIndex] = true;

        if (bestError > maxError)
            maxError = bestError;
    }

    GeodesicIntersectionEnumeration countOnly;

    if (!tryAllGeodesicIntersections(
            intersector,
            firstLine,
            secondLine,
            item.radius,
            item.p0x,
            item.p0y,
            cast(GeodesicIntersectionPoint!double[]) null,
            workspace,
            countOnly)
        || countOnly.total != expectedCount
        || countOnly.written != 0
        || countOnly.truncated != (expectedCount != 0))
    {
        writefln("FAIL %-31s count query", item.name);
        return false;
    }

    GeodesicIntersectionPoint!double[2] prefix;
    GeodesicIntersectionEnumeration shortResult;

    if (!tryAllGeodesicIntersections(
            intersector,
            firstLine,
            secondLine,
            item.radius,
            item.p0x,
            item.p0y,
            prefix[],
            workspace,
            shortResult))
    {
        writefln("FAIL %-31s truncation call", item.name);
        return false;
    }

    const size_t expectedWritten =
        expectedCount < prefix.length
            ? expectedCount
            : prefix.length;

    if (shortResult.total != expectedCount
        || shortResult.written != expectedWritten
        || shortResult.truncated != (expectedWritten < expectedCount))
    {
        writefln("FAIL %-31s truncation metadata", item.name);
        return false;
    }

    foreach (i; 0 .. expectedWritten)
    {
        if (prefix[i].distanceOnFirst
                != actual[i].distanceOnFirst
            || prefix[i].distanceOnSecond
                != actual[i].distanceOnSecond
            || prefix[i].coincidence
                != actual[i].coincidence)
        {
            writefln("FAIL %-31s truncation prefix", item.name);
            return false;
        }
    }

    writefln(
        "PASS %-31s total=%3s max_l1_err=%.3e",
        item.name,
        expectedCount,
        maxError);

    return true;
}

void main()
{
    Case[] cases = [
        Case("wgs84_ordinary",false,
            0,-20,45, 10,20,-60, 0,0,50_000_000),
        Case("wgs84_symmetric_origin",false,
            0,0,45, 0,0,135, 0,0,50_000_000),
        Case("wgs84_near_parallel",false,
            10,20,45, 11,21,45.1, 0,0,70_000_000),
        Case("wgs84_polar",false,
            82,-40,20, 80,100,145, 0,0,50_000_000),
        Case("wgs84_reverse",false,
            -25,70,-35, 5,-110,145,
            1_000_000,-500_000,50_000_000),
        Case("wgs84_coincident_parallel",false,
            0,0,90, 0,0,90, 0,0,50_000_000),
        Case("wgs84_coincident_antiparallel",false,
            0,0,90, 0,0,-90, 0,0,50_000_000),
        Case("sphere_ordinary",true,
            0,-20,45, 10,20,-60, 0,0,50_000_000),
        Case("sphere_near_parallel",true,
            15,-30,60, 16,-29,60.1, 0,0,70_000_000),
        Case("sphere_symmetric_origin",true,
            0,0,45, 0,0,135, 0,0,50_000_000),
        Case("sphere_coincident_parallel",true,
            0,0,90, 0,0,90, 0,0,50_000_000),
        Case("wgs84_boundary_outside",false,
            0,0,30, 0,0,120,
            0,0,39_924_025.252815932),
        Case("wgs84_boundary_inside",false,
            0,0,30, 0,0,120,
            0,0,40_042_530.068560898)
    ];

    size_t failures;

    foreach (item; cases)
    {
        if (!runCase(item))
            ++failures;
    }

    if (failures)
    {
        writefln(
            "GEODESIC ALL INTERSECTION DIFFERENTIAL FAIL: %s",
            failures);
        assert(0);
    }

    writeln("GEODESIC ALL INTERSECTION DIFFERENTIAL PASS");
}
