module geodesic_segment_intersection_differential;

import geodesy;

import std.math : PI, abs;
import std.stdio : writefln, writeln;

extern(C)
int m5_46_reference(
    double,double,double,double,double,double,double,double,
    int*,double*,double*,double*,double*);

private double wrapPi(double x)
{
    const double tau = 2.0 * cast(double) PI;
    x %= tau;
    if (x >= cast(double) PI) x -= tau;
    if (x < -cast(double) PI) x += tau;
    return x;
}

private GeographicCoordinate!double gc(double lat, double lon)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
}

private double coordinateError(
    const GeographicCoordinate!double actual,
    const GeographicCoordinate!double expected)
{
    const double latitudeError =
        abs(actual.latitude.radians - expected.latitude.radians);

    const double longitudeError =
        abs(wrapPi(
            actual.longitude.radians
                - expected.longitude.radians));

    return latitudeError > longitudeError
        ? latitudeError
        : longitudeError;
}

private int referenceKind(
    const GeodesicSegmentIntersectionKind kind)
{
    final switch (kind)
    {
        case GeodesicSegmentIntersectionKind.invalid:
            return -1;
        case GeodesicSegmentIntersectionKind.none:
            return 0;
        case GeodesicSegmentIntersectionKind.point:
            return 1;
        case GeodesicSegmentIntersectionKind.overlap:
            return 2;
    }
}

private struct Case
{
    string name;
    double a1lat,a1lon,a2lat,a2lon;
    double b1lat,b1lon,b2lat,b2lon;
}

void main()
{
    const solver =
        Geodesic!double.fromEllipsoid(
            wgs84!double());

    Case[] cases = [
        Case("crossing",0,-10,0,10,-10,0,10,0),
        Case("shared endpoint",0,-10,0,0,0,0,10,0),
        Case("separate",0,-10,0,-5,10,5,10,10),
        Case("overlap same",0,-10,0,10,0,-5,0,15),
        Case("overlap reverse",0,-10,0,10,0,15,0,-5),
        Case("contained",0,-10,0,10,0,-5,0,5),
        Case("coincident disjoint",0,-10,0,-5,0,5,0,10),
        Case("antimeridian",0,170,0,-170,-10,180,10,180),
        Case("oblique",35,-20,55,30,50,-15,30,25),
        Case("near parallel",10,-30,10,30,10.1,-30,10.1,30),
        Case("tiny angle cross",0,-40,0,40,-0.001,-40,0.001,40),
        Case("near start cross",0,0,0,20,-10,0.000001,10,0.000001),
        Case("near end cross",0,0,0,20,-10,19.999999,10,19.999999),
        Case("polar cross",84,-60,84,60,82,0,89,0),
        Case("long oblique",-55,-150,55,20,50,-120,-45,50),
        Case("reversed first",0,10,0,-10,-10,0,10,0),
        Case("reversed second",0,-10,0,10,10,0,-10,0),
        Case("almost coincident none",0,-20,0,20,0.000001,-20,0.000001,20)
    ];

    size_t failures = 0;

    foreach (item; cases)
    {
        const a0 = gc(item.a1lat,item.a1lon);
        const a1 = gc(item.a2lat,item.a2lon);
        const b0 = gc(item.b1lat,item.b1lon);
        const b1 = gc(item.b2lat,item.b2lon);

        GeodesicSegmentIntersectionResult!double actual;

        if (!tryIntersectGeodesicSegments(
                solver,
                a0,
                a1,
                b0,
                b1,
                actual))
        {
            writefln("FAIL %-22s public solver failed", item.name);
            ++failures;
            continue;
        }

        int expectedKind;
        double lat0,lon0,lat1,lon1;

        const int oracleOk =
            m5_46_reference(
                item.a1lat,item.a1lon,item.a2lat,item.a2lon,
                item.b1lat,item.b1lon,item.b2lat,item.b2lon,
                &expectedKind,
                &lat0,&lon0,&lat1,&lon1);

        if (!oracleOk)
        {
            writefln("FAIL %-22s oracle failed", item.name);
            ++failures;
            continue;
        }

        bool pass =
            actual.isValid
            && referenceKind(actual.kind) == expectedKind;

        if (pass && expectedKind == 1)
        {
            const auto expected = gc(lat0,lon0);
            pass =
                coordinateError(
                    actual.firstPoint,
                    expected) < 3.0e-11
                && coordinateError(
                    actual.secondPoint,
                    expected) < 3.0e-11;
        }
        else if (pass && expectedKind == 2)
        {
            const auto expected0 = gc(lat0,lon0);
            const auto expected1 = gc(lat1,lon1);

            const bool sameOrder =
                coordinateError(
                    actual.firstPoint,
                    expected0) < 3.0e-11
                && coordinateError(
                    actual.secondPoint,
                    expected1) < 3.0e-11;

            const bool reverseOrder =
                coordinateError(
                    actual.firstPoint,
                    expected1) < 3.0e-11
                && coordinateError(
                    actual.secondPoint,
                    expected0) < 3.0e-11;

            pass = sameOrder || reverseOrder;
        }

        writefln(
            "%s %-22s actual=%s expected=%s",
            pass ? "PASS" : "FAIL",
            item.name,
            actual.kind,
            expectedKind);

        if (!pass)
            ++failures;
    }

    const duplicate =
        gc(5.0, 6.0);

    const targetA =
        gc(7.0, 8.0);

    const targetB =
        gc(9.0, 10.0);

    GeodesicSegmentIntersectionResult!double invalid;

    if (tryIntersectGeodesicSegments(
            solver,
            duplicate,
            duplicate,
            targetA,
            targetB,
            invalid)
        || invalid.isValid)
    {
        writeln("FAIL degenerate segment should be rejected");
        ++failures;
    }

    const antipodeA = gc(0.0, 0.0);
    const antipodeB = gc(0.0, 180.0);

    if (tryIntersectGeodesicSegments(
            solver,
            antipodeA,
            antipodeB,
            targetA,
            targetB,
            invalid)
        || invalid.isValid)
    {
        writeln("FAIL exact antipodal segment should be rejected");
        ++failures;
    }

    /*
     * GeographicLib documents equal-and-opposite endpoint latitudes as a
     * multiple-shortest-geodesic case when the two returned azimuths differ.
     * Intersect::Segment itself can still return one representative solution,
     * but its contract warns that the segment result is only well-defined for
     * unique shortest geodesics. geodesy-d rejects this input explicitly.
     */
    const ambiguousA0 = gc(5.0, -170.0);
    const ambiguousA1 = gc(-5.0, 5.0);

    if (tryIntersectGeodesicSegments(
            solver,
            ambiguousA0,
            ambiguousA1,
            targetA,
            targetB,
            invalid)
        || invalid.isValid)
    {
        writeln("FAIL ambiguous shortest segment should be rejected");
        ++failures;
    }

    if (failures)
    {
        writefln(
            "GEODESIC SEGMENT INTERSECTION DIFFERENTIAL FAIL: %s case(s)",
            failures);
        assert(0);
    }

    writeln("GEODESIC SEGMENT INTERSECTION DIFFERENTIAL PASS");
}
