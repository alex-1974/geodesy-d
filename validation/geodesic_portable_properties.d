module geodesic_portable_properties;

/*
 * GEO-G portable core reference/property gate.
 *
 * Independent Exact/PROJ differential gates remain dedicated Linux evidence.
 * This validator instead uses analytical sphere cases and representation-local
 * mathematical properties which require no external runtime and therefore run
 * identically across the mandatory CI matrix.
 */

import std.math :
    PI,
    fabs;
import std.stdio :
    writefln,
    writeln;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult;
import geodesy.geographic : GeographicCoordinate;


private T pi(T)()
{
    return cast(T) PI;
}


private T angularTolerance(T)()
{
    static if (T.mant_dig <= 24)
        return cast(T) 8e-6L;
    else
        return cast(T) 5e-12L;
}


private T normalizedLinearTolerance(T)()
{
    static if (T.mant_dig <= 24)
        return cast(T) 8e-6L;
    else
        return cast(T) 5e-12L;
}


private T normalizedAngleDifference(T)(
    T value)
{
    const T p = pi!T;
    const T twoP = cast(T) 2 * p;

    value %= twoP;

    if (value >= p)
        value -= twoP;
    else if (value < -p)
        value += twoP;

    return value;
}


private GeographicCoordinate!T pointDegrees(T)(
    const T latitude,
    const T longitude)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(latitude),
        Longitude!T.fromDegrees(longitude));
}


private string scalarName(T)()
{
    static if (is(T == float))
        return "float";
    else static if (is(T == double))
        return "double";
    else static if (is(T == real))
        return "real";
    else
        return T.stringof;
}


private void validateScalar(T)()
{
    const T sphereRadius =
        cast(T) 6_371_000.0L;

    const sphere =
        Geodesic!T.fromEllipsoid(
            Ellipsoid!T.sphere(
                sphereRadius));

    const equator0 =
        pointDegrees!T(
            cast(T) 0,
            cast(T) 0);

    const equator90 =
        pointDegrees!T(
            cast(T) 0,
            cast(T) 90);

    /*
     * Analytical great-circle quarter circumference.
     */
    GeodesicInverseResult!T sphereInverse;

    assert(sphere.tryInverse(
        equator0,
        equator90,
        sphereInverse));

    assert(
        fabs(
            sphereInverse.distance / sphereRadius
            - pi!T / cast(T) 2)
        <= normalizedLinearTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                sphereInverse.initialAzimuth.radians
                - pi!T / cast(T) 2))
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                sphereInverse.finalAzimuth.radians
                - pi!T / cast(T) 2))
        <= angularTolerance!T);

    GeodesicDirectResult!T sphereDirect;

    assert(sphere.tryDirect(
        equator0,
        Angle!T.fromDegrees(cast(T) 90),
        sphereRadius * pi!T / cast(T) 2,
        sphereDirect));

    assert(
        fabs(
            sphereDirect.position.latitude.radians)
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                sphereDirect.position.longitude.radians
                - pi!T / cast(T) 2))
        <= angularTolerance!T);

    /*
     * General oblate direct/inverse closure.
     */
    const T f =
        cast(T) (1.0L / 298.257223563L);

    const T a =
        cast(T) 6_378_137.0L;

    const ellipsoid =
        Ellipsoid!T.fromFlattening(
            a,
            f);

    const solver =
        Geodesic!T.fromEllipsoid(
            ellipsoid);

    const start =
        pointDegrees!T(
            cast(T) -30,
            cast(T) 15);

    const end =
        pointDegrees!T(
            cast(T) 42,
            cast(T) 120);

    GeodesicInverseResult!T inverse;

    assert(solver.tryInverse(
        start,
        end,
        inverse));

    GeodesicDirectResult!T closure;

    assert(solver.tryDirect(
        start,
        inverse.initialAzimuth,
        inverse.distance,
        closure));

    assert(
        fabs(
            closure.position.latitude.radians
            - end.latitude.radians)
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                closure.position.longitude.radians
                - end.longitude.radians))
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                closure.finalAzimuth.radians
                - inverse.finalAzimuth.radians))
        <= angularTolerance!T);

    /*
     * Reversal symmetry of shortest distance for a unique ordinary case.
     */
    GeodesicInverseResult!T reverse;

    assert(solver.tryInverse(
        end,
        start,
        reverse));

    assert(
        fabs(
            inverse.distance / a
            - reverse.distance / a)
        <= normalizedLinearTolerance!T);

    /*
     * Scale invariance: same flattening and angular endpoints, different a.
     * Normalized distance and angular outputs must be invariant.
     */
    const unitSolver =
        Geodesic!T.fromEllipsoid(
            Ellipsoid!T.fromFlattening(
                cast(T) 1,
                f));

    GeodesicInverseResult!T unitInverse;

    assert(unitSolver.tryInverse(
        start,
        end,
        unitInverse));

    assert(
        fabs(
            inverse.distance / a
            - unitInverse.distance)
        <= normalizedLinearTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                inverse.initialAzimuth.radians
                - unitInverse.initialAzimuth.radians))
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                inverse.finalAzimuth.radians
                - unitInverse.finalAzimuth.radians))
        <= angularTolerance!T);

    /*
     * Sphere longitude-shift symmetry.
     */
    const sphereA =
        pointDegrees!T(
            cast(T) 10,
            cast(T) 20);

    const sphereB =
        pointDegrees!T(
            cast(T) -25,
            cast(T) 70);

    const shiftedA =
        pointDegrees!T(
            cast(T) 10,
            cast(T) 50);

    const shiftedB =
        pointDegrees!T(
            cast(T) -25,
            cast(T) 100);

    GeodesicInverseResult!T baseShift;
    GeodesicInverseResult!T translatedShift;

    assert(sphere.tryInverse(
        sphereA,
        sphereB,
        baseShift));

    assert(sphere.tryInverse(
        shiftedA,
        shiftedB,
        translatedShift));

    assert(
        fabs(
            baseShift.distance / sphereRadius
            - translatedShift.distance / sphereRadius)
        <= normalizedLinearTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                baseShift.initialAzimuth.radians
                - translatedShift.initialAzimuth.radians))
        <= angularTolerance!T);

    assert(
        fabs(
            normalizedAngleDifference(
                baseShift.finalAzimuth.radians
                - translatedShift.finalAzimuth.radians))
        <= angularTolerance!T);

    writefln(
        "%s: PASS",
        scalarName!T);
}


void main()
{
    writeln("GEO-G portable geodesic reference/property gate");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: GEO-G PORTABLE PROPERTY PASS");
}
