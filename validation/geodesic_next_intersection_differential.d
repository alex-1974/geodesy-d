module geodesic_next_intersection_differential;

import geodesy;

import std.math : PI, abs, sin;
import std.stdio : writefln, writeln;

extern(C)
int m5_105_reference(
    double,double,double,double,double,double,
    double*,double*,int*,double*,double*);

private GeographicCoordinate!double gc(double lat, double lon)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
}

private double wrapPi(double value)
{
    const double period = 2.0 * cast(double) PI;
    value %= period;
    if (value >= cast(double) PI) value -= period;
    else if (value < -cast(double) PI) value += period;
    return value;
}

private double coordinateError(
    const GeographicCoordinate!double a,
    const GeographicCoordinate!double b)
{
    const double dlat = abs(a.latitude.radians - b.latitude.radians);
    const double dlon = abs(wrapPi(a.longitude.radians - b.longitude.radians));
    return dlat > dlon ? dlat : dlon;
}

private int coincidenceCode(
    const GeodesicIntersectionCoincidence value)
{
    final switch (value)
    {
        case GeodesicIntersectionCoincidence.distinct:
            return 0;
        case GeodesicIntersectionCoincidence.parallel:
            return 1;
        case GeodesicIntersectionCoincidence.antiparallel:
            return -1;
    }
}

private struct Case
{
    string name;
    bool sphere;
    bool equidistantAllowed;
    double lat;
    double lon;
    double aziX;
    double aziY;
}

void main()
{
    Case[] cases = [
        Case("ordinary",false,false,0,0,30,120),
        Case("equator orthogonal",false,false,0,0,0,90),
        Case("near parallel",false,false,10,20,45,45.1),
        Case("polar",false,false,82,-40,20,145),
        Case("reverse directions",false,false,-25,70,-35,140),
        Case("coincident same",false,false,0,0,90,90),
        Case("coincident reverse",false,false,0,0,90,-90),
        Case("sphere ordinary",true,false,0,0,30,120),
        Case("sphere near parallel",true,true,15,-30,60,60.1),
        Case("sphere symmetric cross",true,true,0,0,45,135),
        Case("sphere meridian/equator",true,true,0,0,0,90),
        Case("wgs84 almost symmetric",false,false,0.0001,0,45,135),
        Case("sphere coincident",true,false,0,0,90,90)
    ];

    size_t failures;

    foreach (item; cases)
    {
        const ellipsoid =
            item.sphere
                ? Ellipsoid!double.sphere(6_371_000.0)
                : wgs84!double();

        const solver =
            Geodesic!double.fromEllipsoid(ellipsoid);

        const origin =
            gc(item.lat,item.lon);

        const aziX =
            Angle!double.fromDegrees(item.aziX);

        const aziY =
            Angle!double.fromDegrees(item.aziY);

        GeodesicNextIntersectionResult!double actual;

        if (!tryNextGeodesicIntersection(
                solver,
                origin,
                aziX,
                aziY,
                actual))
        {
            writefln("FAIL %-24s public solver failed", item.name);
            ++failures;
            continue;
        }

        double rx,ry,rlat,rlon;
        int rc;

        if (!m5_105_reference(
                ellipsoid.semiMajorAxis,
                ellipsoid.flattening,
                item.lat,item.lon,item.aziX,item.aziY,
                &rx,&ry,&rc,&rlat,&rlon))
        {
            writefln("FAIL %-24s oracle failed", item.name);
            ++failures;
            continue;
        }

        const auto lineX =
            GeodesicLine!double.fromGeodesic(
                solver,origin,aziX);

        const auto lineY =
            GeodesicLine!double.fromGeodesic(
                solver,origin,aziY);

        const auto atX =
            lineX.position(actual.distanceOnFirst);

        const auto atY =
            lineY.position(actual.distanceOnSecond);

        const double crossingAngle =
            abs(wrapPi(
                atY.finalAzimuth.radians
                    - atX.finalAzimuth.radians));

        const double sinCrossing =
            abs(sin(crossingAngle));

        const double conditioning =
            ellipsoid.semiMajorAxis
            * 512.0
            * double.epsilon
            / (sinCrossing > 1e-15
                ? sinCrossing
                : 1e-15);

        const double displacementTolerance =
            conditioning > 5e-5
                ? conditioning
                : 5e-5;

        const double positionTolerance =
            displacementTolerance
            / ellipsoid.semiMajorAxis
            * 2.0;

        const double xerr =
            abs(actual.distanceOnFirst-rx);

        const double yerr =
            abs(actual.distanceOnSecond-ry);

        const double poserr =
            coordinateError(
                actual.position,
                gc(rlat,rlon));

        const double expectedRank =
            abs(rx) + abs(ry);

        const double rankError =
            abs(actual.displacementDistance - expectedRank);

        const bool sameRepresentative =
            xerr < displacementTolerance
            && yerr < displacementTolerance
            && poserr < positionTolerance;

        const bool sameMinimumRank =
            rankError < displacementTolerance * 2.0;

        const bool pass =
            actual.isValid
            && coincidenceCode(actual.coincidence) == rc
            && actual.displacementDistance > 0.0
            && (
                sameRepresentative
                || (
                    item.equidistantAllowed
                    && sameMinimumRank
                )
            );

        writefln(
            "%s %-24s dx=%.3e dy=%.3e rank=%.3e",
            pass ? "PASS" : "FAIL",
            item.name,
            xerr,
            yerr,
            rankError);

        if (!pass)
            ++failures;
    }

    const solver =
        Geodesic!double.fromEllipsoid(wgs84!double());

    const a =
        GeodesicLine!double.fromGeodesic(
            solver,
            gc(0,0),
            Angle!double.fromDegrees(30));

    const b =
        GeodesicLine!double.fromGeodesic(
            solver,
            gc(1,0),
            Angle!double.fromDegrees(120));

    GeodesicNextIntersectionResult!double invalid;

    if (tryNextGeodesicIntersection(
            solver,
            a,
            b,
            invalid)
        || invalid.isValid)
    {
        writeln("FAIL prepared lines with different origins must be rejected");
        ++failures;
    }

    if (failures)
    {
        writefln(
            "GEODESIC NEXT INTERSECTION DIFFERENTIAL FAIL: %s",
            failures);
        assert(0);
    }

    writeln("GEODESIC NEXT INTERSECTION DIFFERENTIAL PASS");
}
