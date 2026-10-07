module geodesic_closest_intersection_differential;

import geodesy;
import std.math : PI, abs, sin;
import std.stdio : writefln, writeln;

extern(C) int m5_104_reference(
    double,double,double,double,double,double,double,double,double,double,
    double*,double*,int*,double*,double*);

private double wrapPi(double value)
{
    const double period = 2.0 * cast(double) PI;
    value %= period;
    if (value >= cast(double) PI) value -= period;
    else if (value < -cast(double) PI) value += period;
    return value;
}

private GeographicCoordinate!double gc(double lat, double lon)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
}

private double coordinateError(
    const GeographicCoordinate!double a,
    const GeographicCoordinate!double b)
{
    const double dlat = abs(a.latitude.radians - b.latitude.radians);
    const double dlon = abs(wrapPi(a.longitude.radians - b.longitude.radians));
    return dlat > dlon ? dlat : dlon;
}

private struct Case
{
    string name;
    bool sphere;
    double latX,lonX,aziX;
    double latY,lonY,aziY;
    double p0x,p0y;
}

void main()
{
    Case[] cases = [
        Case("ordinary",false,0,-20,45,10,20,-60,0,0),
        Case("offset",false,0,-20,45,10,20,-60,2.5e6,-1.0e6),
        Case("antimeridian",false,15,175,80,-20,-175,10,0,0),
        Case("polar",false,80,-60,20,82,50,-80,0,0),
        Case("near parallel",false,10,-30,85,10.1,-30,85.1,0,0),
        Case("coincident same",false,0,0,90,0,10,90,1.0e6,-2.0e6),
        Case("coincident reverse",false,0,0,90,0,10,-90,-2.0e6,1.0e6),
        Case("sphere ordinary",true,0,-20,45,10,20,-60,0,0),
        Case("sphere offset",true,25,-40,70,-10,80,-20,3.0e6,2.0e6),
        Case("large offset",false,-20,-120,30,35,80,-110,1.5e7,-1.1e7),
        Case("reverse x",false,0,-20,225,10,20,-60,0,0),
        Case("reverse y",false,0,-20,45,10,20,120,0,0),
        Case("near coincident",false,5,-40,80,5.00001,-40.00001,80.00001,0,0),
        Case("coincident same shifted",false,0,0,90,0,10,90,8.0e6,3.0e6),
        Case("coincident reverse shifted",false,0,0,90,0,10,-90,8.0e6,-3.0e6),
        Case("polar offset",false,88,-160,40,86,30,-100,-6.0e6,4.0e6)
    ];

    size_t failures;

    foreach (item; cases)
    {
        const ellipsoid = item.sphere
            ? Ellipsoid!double.sphere(6_371_000.0)
            : wgs84!double();
        const solver = Geodesic!double.fromEllipsoid(ellipsoid);
        const startX = gc(item.latX,item.lonX);
        const startY = gc(item.latY,item.lonY);
        const aziX = Angle!double.fromDegrees(item.aziX);
        const aziY = Angle!double.fromDegrees(item.aziY);
        GeodesicClosestIntersectionResult!double actual;
        if (!tryClosestGeodesicIntersection(
                solver,startX,aziX,startY,aziY,item.p0x,item.p0y,actual))
        {
            writefln("FAIL %-24s public solver failed",item.name);
            ++failures;
            continue;
        }

        double rx,ry,rlat,rlon;
        int rc;
        if (!m5_104_reference(
                ellipsoid.semiMajorAxis,ellipsoid.flattening,
                item.latX,item.lonX,item.aziX,
                item.latY,item.lonY,item.aziY,
                item.p0x,item.p0y,&rx,&ry,&rc,&rlat,&rlon))
        {
            writefln("FAIL %-24s oracle failed",item.name);
            ++failures;
            continue;
        }

        const auto lineX = GeodesicLine!double.fromGeodesic(solver,startX,aziX);
        const auto lineY = GeodesicLine!double.fromGeodesic(solver,startY,aziY);
        const auto atX = lineX.position(actual.distanceOnFirst);
        const auto atY = lineY.position(actual.distanceOnSecond);
        const double crossingAngle = abs(wrapPi(
            atY.finalAzimuth.radians - atX.finalAzimuth.radians));
        const double sinCrossing = abs(sin(crossingAngle));
        const double conditioningFloor =
            ellipsoid.semiMajorAxis * 512.0 * double.epsilon
            / (sinCrossing > 1e-15 ? sinCrossing : 1e-15);
        const double displacementTolerance =
            conditioningFloor > 2e-5 ? conditioningFloor : 2e-5;
        const double positionTolerance =
            displacementTolerance / ellipsoid.semiMajorAxis * 2.0;

        const int ac =
            actual.coincidence == GeodesicIntersectionCoincidence.parallel ? 1 :
            actual.coincidence == GeodesicIntersectionCoincidence.antiparallel ? -1 : 0;
        const bool pass =
            actual.isValid
            && abs(actual.distanceOnFirst-rx) < displacementTolerance
            && abs(actual.distanceOnSecond-ry) < displacementTolerance
            && coordinateError(actual.position,gc(rlat,rlon)) < positionTolerance
            && ac == rc;

        writefln("%s %-24s dx=%.3e dy=%.3e",
            pass?"PASS":"FAIL",item.name,
            abs(actual.distanceOnFirst-rx),
            abs(actual.distanceOnSecond-ry));
        if (!pass) ++failures;
    }

    if (failures)
    {
        writefln("GEODESIC CLOSEST INTERSECTION DIFFERENTIAL FAIL: %s",failures);
        assert(0);
    }
    writeln("GEODESIC CLOSEST INTERSECTION DIFFERENTIAL PASS");
}
