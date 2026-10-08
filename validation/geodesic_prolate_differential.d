module geodesic_prolate_differential;

import geodesy;

import std.math : PI, abs;
import std.stdio : stderr, writefln, writeln;

extern(C) int r69_direct_quantities(
    double,double,double,double,double,double,
    double*,double*,double*,double*,double*,double*,double*);

extern(C) int r69_inverse_quantities(
    double,double,double,double,double,double,
    double*,double*,double*,double*,double*,double*,double*);

extern(C) int r69_polygon(
    double,double,
    const double*,const double*,size_t,
    double*,double*);

extern(C) int m5_47_reference(
    double,double,
    double,double,double,double,double,double,
    double*,double*,double*,double*,
    double*,double*,double*,int*);

extern(C) int m5_104_reference(
    double,double,
    double,double,double,
    double,double,double,
    double,double,
    double*,double*,int*,double*,double*);

extern(C) int m5_105_reference(
    double,double,double,double,double,double,
    double*,double*,int*,double*,double*);

extern(C) int m5_106_reference(
    double,double,
    double,double,double,
    double,double,double,
    double,double,double,
    size_t,size_t*,
    double*,double*,int*);

private GeographicCoordinate!double gc(double lat, double lon)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
}

private double angleDelta(double a, double b)
{
    double d = a - b;
    while (d >= 180.0) d -= 360.0;
    while (d < -180.0) d += 360.0;
    return abs(d);
}

private int coincidenceCode(GeodesicIntersectionCoincidence value)
{
    final switch (value)
    {
        case GeodesicIntersectionCoincidence.distinct: return 0;
        case GeodesicIntersectionCoincidence.parallel: return 1;
        case GeodesicIntersectionCoincidence.antiparallel: return -1;
    }
}

private bool closeArea(double actual, double expected)
{
    const double scale = abs(expected) > 1.0 ? abs(expected) : 1.0;
    return abs(actual - expected) <= 2.0e-12 * scale + 0.05;
}

private bool validateDirectInverse(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a, f));

    struct DirectCase { double lat,lon,azi,s; }
    DirectCase[] directCases = [
        DirectCase(12.5,-33,47,2_500_000),
        DirectCase(82,15,170,1_800_000),
        DirectCase(-35,70,-40,19_000_000)
    ];

    foreach (tc; directCases)
    {
        GeodesicDirectResult!double actual;
        GeodesicQuantities!double q;

        if (!solver.tryDirect(
                gc(tc.lat,tc.lon),
                Angle!double.fromDegrees(tc.azi),
                tc.s,
                actual,
                q))
            return false;

        double lat2,lon2,azi2,m12,M12,M21,S12;

        if (!r69_direct_quantities(
                a,f,tc.lat,tc.lon,tc.azi,tc.s,
                &lat2,&lon2,&azi2,
                &m12,&M12,&M21,&S12))
            return false;

        const double dLat = abs(actual.position.latitude.degrees-lat2);
        const double dLon = angleDelta(actual.position.longitude.degrees,lon2);
        const double dAzi = angleDelta(actual.finalAzimuth.degrees,azi2);
        const double dReduced = abs(q.reducedLength-m12);
        const double dScale12 = abs(q.scale12-M12);
        const double dScale21 = abs(q.scale21-M21);
        const double dArea = abs(q.signedArea-S12);

        if (dLat > 2e-9
            || dLon > 2e-9
            || dAzi > 2e-9
            || dReduced > 3e-5
            || dScale12 > 3e-12
            || dScale21 > 3e-12
            || !closeArea(q.signedArea,S12))
        {
            stderr.writefln(
                "DIRECT mismatch f=%.12g lat=%.12g lon=%.12g azi=%.12g s=%.12g "
                ~ "dlat=%.12g dlon=%.12g dazi=%.12g dm12=%.12g dM12=%.12g dM21=%.12g dS12=%.12g",
                f, tc.lat, tc.lon, tc.azi, tc.s,
                dLat, dLon, dAzi, dReduced, dScale12, dScale21, dArea);
            return false;
        }
    }

    struct InverseCase { double lat1,lon1,lat2,lon2; }
    InverseCase[] inverseCases = [
        InverseCase(10,20,-25,130),
        InverseCase(88,-40,80,135),
        InverseCase(0.01,0,-0.01,179.999),
        InverseCase(15,10,-14.999,-169.999)
    ];

    foreach (tc; inverseCases)
    {
        GeodesicInverseResult!double actual;
        GeodesicQuantities!double q;

        if (!solver.tryInverse(
                gc(tc.lat1,tc.lon1),
                gc(tc.lat2,tc.lon2),
                actual,
                q))
            return false;

        double s12,azi1,azi2,m12,M12,M21,S12;

        if (!r69_inverse_quantities(
                a,f,tc.lat1,tc.lon1,tc.lat2,tc.lon2,
                &s12,&azi1,&azi2,
                &m12,&M12,&M21,&S12))
            return false;

        const double dDistance = abs(actual.distance-s12);
        const double dAzi1 = angleDelta(actual.initialAzimuth.degrees,azi1);
        const double dAzi2 = angleDelta(actual.finalAzimuth.degrees,azi2);
        const double dReduced = abs(q.reducedLength-m12);
        const double dScale12 = abs(q.scale12-M12);
        const double dScale21 = abs(q.scale21-M21);
        const double dArea = abs(q.signedArea-S12);

        if (dDistance > 3e-5
            || dAzi1 > 3e-9
            || dAzi2 > 3e-9
            || dReduced > 3e-5
            || dScale12 > 3e-12
            || dScale21 > 3e-12
            || !closeArea(q.signedArea,S12))
        {
            stderr.writefln(
                "INVERSE mismatch f=%.12g lat1=%.12g lon1=%.12g lat2=%.12g lon2=%.12g "
                ~ "ds=%.12g dazi1=%.12g dazi2=%.12g dm12=%.12g dM12=%.12g dM21=%.12g dS12=%.12g",
                f, tc.lat1, tc.lon1, tc.lat2, tc.lon2,
                dDistance, dAzi1, dAzi2, dReduced, dScale12, dScale21, dArea);
            return false;
        }
    }

    return true;
}

private bool validatePolygon(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a,f));

    double[4] lats = [5.0, 5.0, 25.0, 25.0];
    double[4] lons = [-20.0, 30.0, 30.0, -20.0];

    auto polygon =
        GeodesicPolygonAccumulator!double.fromGeodesic(solver);

    foreach (i; 0 .. lats.length)
        if (!polygon.tryAddPoint(gc(lats[i],lons[i])))
            return false;

    GeodesicPolygonResult!double actual;
    if (!polygon.tryCompute(actual))
        return false;

    double perimeter;
    double area;

    if (!r69_polygon(
            a,f,lats.ptr,lons.ptr,lats.length,
            &perimeter,&area))
        return false;

    return abs(actual.perimeter-perimeter) < 1e-4
        && closeArea(actual.signedArea,area);
}

private bool validateNearest(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a,f));

    const start = gc(0,-20);
    const end = gc(0,20);
    const target = gc(10,0);

    GeodesicSegmentNearestResult!double actual;
    if (!tryNearestPointOnSegment(
            solver,start,end,target,actual))
        return false;

    double footLat,footLon,along,cross;
    double nearLat,nearLon,nearDistance;
    int klass;

    if (!m5_47_reference(
            a,f,
            start.latitude.radians,start.longitude.radians,
            end.latitude.radians,end.longitude.radians,
            target.latitude.radians,target.longitude.radians,
            &footLat,&footLon,&along,&cross,
            &nearLat,&nearLon,&nearDistance,&klass))
        return false;

    return actual.isValid
        && abs(actual.supportingFoot.latitude.radians-footLat) < 3e-12
        && abs(actual.supportingFoot.longitude.radians-footLon) < 3e-12
        && abs(actual.alongTrack-along) < 3e-5
        && abs(actual.signedCrossTrack-cross) < 3e-5
        && abs(actual.nearestDistance-nearDistance) < 3e-5;
}

private bool validateClosest(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a,f));

    GeodesicClosestIntersectionResult!double actual;

    if (!tryClosestGeodesicIntersection(
            solver,
            gc(0,-20),Angle!double.fromDegrees(45),
            gc(10,20),Angle!double.fromDegrees(-60),
            8_000_000.0,-4_000_000.0,
            actual))
        return false;

    double x,y,lat,lon;
    int c;

    if (!m5_104_reference(
            a,f,
            0,-20,45,
            10,20,-60,
            8_000_000,-4_000_000,
            &x,&y,&c,&lat,&lon))
        return false;

    return abs(actual.distanceOnFirst-x) < 2e-4
        && abs(actual.distanceOnSecond-y) < 2e-4
        && coincidenceCode(actual.coincidence) == c;
}

private bool validateNext(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a,f));

    GeodesicNextIntersectionResult!double actual;

    if (!tryNextGeodesicIntersection(
            solver,
            gc(12,-40),
            Angle!double.fromDegrees(17),
            Angle!double.fromDegrees(133),
            actual))
        return false;

    double x,y,lat,lon;
    int c;

    if (!m5_105_reference(
            a,f,12,-40,17,133,
            &x,&y,&c,&lat,&lon))
        return false;

    const double actualRank =
        abs(actual.distanceOnFirst)
        + abs(actual.distanceOnSecond);

    const double oracleRank =
        abs(x) + abs(y);

    return abs(actualRank-oracleRank) < 4e-4
        && coincidenceCode(actual.coincidence) == c;
}

private bool validateAll(double f)
{
    enum double a = 6_378_137.0;
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromFlattening(a,f));

    GeodesicIntersectionSolver!double intersector;

    if (!GeodesicIntersectionSolver!double.tryFromGeodesic(
            solver,intersector))
        return false;

    GeodesicLine!double first;
    GeodesicLine!double second;

    if (!GeodesicLine!double.tryFromGeodesic(
            solver,gc(0,-20),Angle!double.fromDegrees(45),first)
        || !GeodesicLine!double.tryFromGeodesic(
            solver,gc(10,20),Angle!double.fromDegrees(-60),second))
        return false;

    GeodesicIntersectionWorkspaceEntry!double[64] starts;
    bool[64] skip;
    GeodesicIntersectionWorkspaceEntry!double[128] found;
    GeodesicIntersectionWorkspaceEntry!double[64] centers;
    GeodesicIntersectionWorkspace!double workspace;

    if (!GeodesicIntersectionWorkspace!double.tryFromStorage(
            starts[],skip[],found[],centers[],workspace))
        return false;

    GeodesicIntersectionPoint!double[64] actual;
    GeodesicIntersectionEnumeration enumeration;

    if (!tryAllGeodesicIntersections(
            intersector,first,second,
            40_000_000.0,
            actual[],
            workspace,
            enumeration))
        return false;

    double[64] xs;
    double[64] ys;
    int[64] cs;
    size_t count;

    const int rc =
        m5_106_reference(
            a,f,
            0,-20,45,
            10,20,-60,
            0,0,40_000_000,
            xs.length,&count,
            xs.ptr,ys.ptr,cs.ptr);

    if (rc != 1 || count != enumeration.total)
        return false;

    foreach (i; 0 .. count)
    {
        if (abs(actual[i].distanceOnFirst-xs[i]) > 2e-4
            || abs(actual[i].distanceOnSecond-ys[i]) > 2e-4
            || coincidenceCode(actual[i].coincidence) != cs[i])
            return false;
    }

    return true;
}

int main()
{
    double[] flattenings = [
        -1.0 / 300.0,
        -0.01
    ];

    size_t failures;

    foreach (f; flattenings)
    {
        const bool directInverse = validateDirectInverse(f);
        const bool polygon = validatePolygon(f);
        const bool nearest = validateNearest(f);
        const bool closest = validateClosest(f);
        const bool next = validateNext(f);
        const bool all = validateAll(f);

        writefln(
            "%s f=%.12g direct_inverse=%s polygon=%s nearest=%s closest=%s next=%s all=%s",
            directInverse && polygon && nearest && closest && next && all
                ? "PASS"
                : "FAIL",
            f,
            directInverse,
            polygon,
            nearest,
            closest,
            next,
            all);

        if (!(directInverse && polygon && nearest && closest && next && all))
            ++failures;
    }

    if (failures)
    {
        stderr.writefln(
            "GEODESIC PROLATE DIFFERENTIAL FAIL: %s flattening case(s)",
            failures);
        return 1;
    }

    writeln("GEODESIC PROLATE DIFFERENTIAL PASS");
    return 0;
}
