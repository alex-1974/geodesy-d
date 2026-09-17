/**
 * Direct and inverse ellipsoidal geodesic mathematics.
 *
 * The implementation contract is defined by ADR-0008.
 *
 * This initial implementation slice establishes:
 *
 * - prepared ellipsoid state;
 * - public angular canonicalization semantics;
 * - the exact spherical direct problem.
 *
 * The general oblate-ellipsoid direct and inverse kernels are added in
 * subsequent slices before this module is aggregate-exported by `geodesy`.
 */
module geodesy.geodesic;

import std.math :
    PI,
    asin,
    atan2,
    cos,
    sin;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude,
    angleFromRadiansUnchecked;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


private T pi(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) PI;
}


private T halfPi(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return pi!T / cast(T) 2;
}


private T twoPi(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) 2 * pi!T;
}


private T canonicalZero(T)(const T value)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return value == cast(T) 0
        ? cast(T) 0
        : value;
}


/**
 * Normalize an arbitrary finite angle to [-pi,+pi).
 *
 * Exact zero is canonicalized to positive mathematical zero.
 */
private T canonicalAngleRadians(T)(const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T p = pi!T;
    const T period = twoPi!T;

    T result = radians % period;

    if (result >= p)
        result -= period;
    else if (result < -p)
        result += period;

    return canonicalZero(result);
}


/**
 * Compute sine and cosine with exact values for canonical cardinal angles.
 *
 * libm is not required to return mathematical zero for cos(pi/2).
 * Exact cardinal values preserve equatorial and meridional symmetry.
 */
private void sinCosCanonicalAngle(T)(
    const T angle,
    out T sine,
    out T cosine)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T hp = halfPi!T;
    const T p = pi!T;

    if (angle == cast(T) 0)
    {
        sine = cast(T) 0;
        cosine = cast(T) 1;
    }
    else if (angle == hp)
    {
        sine = cast(T) 1;
        cosine = cast(T) 0;
    }
    else if (angle == -hp)
    {
        sine = cast(T) -1;
        cosine = cast(T) 0;
    }
    else if (angle == -p)
    {
        sine = cast(T) 0;
        cosine = cast(T) -1;
    }
    else
    {
        sine = sin(angle);
        cosine = cos(angle);
    }
}


private T canonicalLatitudeRadians(T)(const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T hp = halfPi!T;
    T result = radians;

    /*
     * Trigonometric roundoff can place an analytically polar result a
     * fraction of an ulp outside the Latitude domain.
     */
    if (result > hp)
        result = hp;
    else if (result < -hp)
        result = -hp;

    return canonicalZero(result);
}


private bool makeGeographicCoordinate(T)(
    const T latitudeRadians,
    const T longitudeRadians,
    out GeographicCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    Latitude!T latitude;
    Longitude!T longitude;

    if (!Latitude!T.tryFromRadians(
            canonicalLatitudeRadians(latitudeRadians),
            latitude))
        return false;

    if (!Longitude!T.tryFromRadians(
            canonicalAngleRadians(longitudeRadians),
            longitude))
        return false;

    result = GeographicCoordinate!T.fromComponents(
        latitude,
        longitude);

    return true;
}


/**
 * Result of a direct geodesic operation.
 *
 * `finalAzimuth` is the forward azimuth at the endpoint: the heading of
 * the same oriented geodesic continuing beyond the endpoint.
 */
struct GeodesicDirectResult(T)
if (isGeodesyScalar!T)
{
private:
    GeographicCoordinate!T _position;
    Angle!T _finalAzimuth;

    static GeodesicDirectResult fromComponents(
        const GeographicCoordinate!T position,
        const Angle!T finalAzimuth)
        pure nothrow @safe @nogc
    {
        GeodesicDirectResult result;
        result._position = position;
        result._finalAzimuth = finalAzimuth;
        return result;
    }

public:
    @property GeographicCoordinate!T position() const
        pure nothrow @safe @nogc
    {
        return _position;
    }

    @property Angle!T finalAzimuth() const
        pure nothrow @safe @nogc
    {
        return _finalAzimuth;
    }
}


/**
 * Prepared direct/inverse geodesic solver for one reference ellipsoid.
 *
 * The initial support profile is:
 *
 *     a > 0
 *     0 <= f <= 0.01
 *
 * No Earth-size restriction applies. Linear geodesic values use the same
 * unit as the ellipsoid semi-major axis.
 *
 * This first production slice implements the direct operation only for the
 * exact spherical case. The module is intentionally not aggregate-exported
 * until the general ellipsoidal implementation and mandatory validation
 * gates are complete.
 */
struct Geodesic(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;

    W _a = W.nan;
    W _f = W.nan;

public:
    /** True when this solver represents the supported ellipsoid profile. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && _ellipsoid.flattening <= cast(T) 0.01
            && isFiniteGeodesyScalar(_a)
            && _a > cast(W) 0
            && isFiniteGeodesyScalar(_f)
            && _f >= cast(W) 0
            && _f <= cast(W) 0.01;
    }


    /** True when the prepared ellipsoid is exactly spherical. */
    @property bool isSphere() const
        pure nothrow @safe @nogc
    {
        return isValid
            && _ellipsoid.flattening == cast(T) 0;
    }


    /** The ellipsoid used by this solver. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }


    /**
     * Prepare a solver without throwing.
     *
     * Returns false for an invalid ellipsoid or flattening outside the
     * initial geodesic support profile.
     */
    static bool tryFromEllipsoid(
        const Ellipsoid!T ellipsoid,
        out Geodesic result)
        pure nothrow @safe @nogc
    {
        result = Geodesic.init;

        if (!ellipsoid.isValid
            || ellipsoid.flattening > cast(T) 0.01)
            return false;

        result._ellipsoid = ellipsoid;
        result._a = cast(W) ellipsoid.semiMajorAxis;
        result._f = cast(W) ellipsoid.flattening;

        return result.isValid;
    }


    /** Prepare a solver or throw for an unsupported ellipsoid. */
    static Geodesic fromEllipsoid(
        const Ellipsoid!T ellipsoid)
        @safe
    {
        Geodesic result;

        if (!tryFromEllipsoid(ellipsoid, result))
            throw new GeodesyValueException(
                "Geodesic requires a valid ellipsoid with 0 <= f <= 0.01.");

        return result;
    }


    /**
     * Solve the direct geodesic problem without throwing.
     *
     * This initial slice implements only the exact spherical case.
     * General oblate ellipsoids deliberately return false until the Karney
     * direct kernel is added.
     */
    bool tryDirect(
        const GeographicCoordinate!T start,
        const Angle!T initialAzimuth,
        const T distance,
        out GeodesicDirectResult!T result) const
        pure nothrow @safe @nogc
    {
        result = GeodesicDirectResult!T.init;

        if (!isValid || !isFiniteGeodesyScalar(distance))
            return false;

        /*
         * This is deliberately temporary branch-local behavior.
         * The module is not yet aggregate-exported.
         */
        if (!isSphere)
            return false;

        const W latitude1 =
            canonicalZero(cast(W) start.latitude.radians);

        const W longitude1 =
            canonicalAngleRadians(
                cast(W) start.longitude.radians);

        const W azimuth1 =
            canonicalAngleRadians(
                cast(W) initialAzimuth.radians);

        const W s12 = cast(W) distance;

        if (!isFiniteGeodesyScalar(latitude1)
            || !isFiniteGeodesyScalar(longitude1)
            || !isFiniteGeodesyScalar(azimuth1)
            || !isFiniteGeodesyScalar(s12))
            return false;

        /*
         * Direct zero-distance semantics are intentionally distinct from
         * inverse coincidence semantics: preserve the supplied line
         * direction after canonicalization.
         */
        if (s12 == cast(W) 0)
        {
            GeographicCoordinate!T endpoint;

            if (!makeGeographicCoordinate(
                    cast(T) latitude1,
                    cast(T) longitude1,
                    endpoint))
                return false;

            const T finalAzimuthRadians =
                canonicalAngleRadians(
                    cast(T) azimuth1);

            result =
                GeodesicDirectResult!T.fromComponents(
                    endpoint,
                    angleFromRadiansUnchecked(
                        finalAzimuthRadians));

            return true;
        }

        W delta = s12 / _a;

        if (!isFiniteGeodesyScalar(delta))
            return false;

        /*
         * On a sphere, whole revolutions return to the same oriented
         * geodesic state. Reducing the arc before sin/cos also avoids
         * needless loss of argument-reduction accuracy for long paths.
         */
        delta = canonicalAngleRadians(delta);

        const W sinPhi1 = sin(latitude1);
        const W cosPhi1 = cos(latitude1);
        const W sinDelta = sin(delta);
        const W cosDelta = cos(delta);
        W sinAlpha1;
        W cosAlpha1;
        sinCosCanonicalAngle!W(
            azimuth1,
            sinAlpha1,
            cosAlpha1);

        if (!isFiniteGeodesyScalar(sinPhi1)
            || !isFiniteGeodesyScalar(cosPhi1)
            || !isFiniteGeodesyScalar(sinDelta)
            || !isFiniteGeodesyScalar(cosDelta)
            || !isFiniteGeodesyScalar(sinAlpha1)
            || !isFiniteGeodesyScalar(cosAlpha1))
            return false;

        W sinPhi2 =
            sinPhi1 * cosDelta
            + cosPhi1 * sinDelta * cosAlpha1;

        if (sinPhi2 > cast(W) 1)
            sinPhi2 = cast(W) 1;
        else if (sinPhi2 < cast(W) -1)
            sinPhi2 = cast(W) -1;

        const W latitude2 = asin(sinPhi2);

        const W deltaLongitude = atan2(
            sinAlpha1 * sinDelta * cosPhi1,
            cosDelta - sinPhi1 * sinPhi2);

        const W longitude2 =
            canonicalAngleRadians(
                longitude1 + deltaLongitude);

        /*
         * Forward azimuth of the same oriented great circle at point 2.
         */
        const W finalAzimuth = atan2(
            sinAlpha1 * cosPhi1,
            cosAlpha1 * cosPhi1 * cosDelta
                - sinPhi1 * sinDelta);

        if (!isFiniteGeodesyScalar(latitude2)
            || !isFiniteGeodesyScalar(longitude2)
            || !isFiniteGeodesyScalar(finalAzimuth))
            return false;

        GeographicCoordinate!T endpoint;

        if (!makeGeographicCoordinate(
                cast(T) latitude2,
                cast(T) longitude2,
                endpoint))
            return false;

        const T canonicalFinalAzimuth =
            canonicalAngleRadians(
                cast(T) finalAzimuth);

        result =
            GeodesicDirectResult!T.fromComponents(
                endpoint,
                angleFromRadiansUnchecked(
                    canonicalFinalAzimuth));

        return true;
    }
}


unittest
{
    import std.math : fabs;

    static assert(is(Geodesic!float));
    static assert(is(Geodesic!double));
    static assert(is(Geodesic!real));

    const invalid = Geodesic!double.init;
    assert(!invalid.isValid);

    Geodesic!double candidate;

    assert(!Geodesic!double.tryFromEllipsoid(
        Ellipsoid!double.init,
        candidate));

    assert(!Geodesic!double.tryFromEllipsoid(
        Ellipsoid!double.fromFlattening(
            6_378_137.0,
            0.0100001),
        candidate));

    const sphere =
        Ellipsoid!double.sphere(6_371_000.0);

    assert(Geodesic!double.tryFromEllipsoid(
        sphere,
        candidate));

    assert(candidate.isValid);
    assert(candidate.isSphere);
    assert(candidate.ellipsoid.semiMajorAxis == 6_371_000.0);

    const origin =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    GeodesicDirectResult!double result;

    assert(candidate.tryDirect(
        origin,
        Angle!double.fromDegrees(90.0),
        1_000_000.0,
        result));

    assert(fabs(result.position.latitude.degrees) < 1e-12);
    assert(
        fabs(
            result.position.longitude.degrees
                - 8.993216059187306)
        < 1e-12);
    assert(
        fabs(result.finalAzimuth.degrees - 90.0)
        < 1e-12);

    /*
     * Negative distance travels backward on the same oriented geodesic.
     * Public zero latitude is canonical positive zero.
     */
    assert(candidate.tryDirect(
        origin,
        Angle!double.fromDegrees(90.0),
        -1_000_000.0,
        result));

    assert(result.position.latitude.radians == 0.0);
    assert(
        fabs(
            result.position.longitude.degrees
                + 8.993216059187306)
        < 1e-12);
    assert(
        fabs(result.finalAzimuth.degrees - 90.0)
        < 1e-12);

    /*
     * GEO-A canonicalization:
     * +pi and -pi are represented publicly as -pi.
     */
    assert(candidate.tryDirect(
        origin,
        Angle!double.fromDegrees(180.0),
        0.0,
        result));

    assert(result.position.latitude.radians == 0.0);
    assert(result.position.longitude.radians == 0.0);
    assert(result.finalAzimuth.degrees == -180.0);

    /*
     * Signed/full-turn zero aliases become mathematical +0.
     */
    assert(candidate.tryDirect(
        origin,
        Angle!double.fromDegrees(-360.0),
        0.0,
        result));

    assert(result.finalAzimuth.radians == 0.0);

    /*
     * +180 and -180 longitudes are the same canonical start meridian.
     */
    const eastAntimeridian =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(180.0));

    const westAntimeridian =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(-180.0));

    GeodesicDirectResult!double eastResult;
    GeodesicDirectResult!double westResult;

    assert(candidate.tryDirect(
        eastAntimeridian,
        Angle!double.fromDegrees(90.0),
        50_000.0,
        eastResult));

    assert(candidate.tryDirect(
        westAntimeridian,
        Angle!double.fromDegrees(90.0),
        50_000.0,
        westResult));

    assert(
        eastResult.position.latitude.radians
            == westResult.position.latitude.radians);

    assert(
        eastResult.position.longitude.radians
            == westResult.position.longitude.radians);

    assert(
        eastResult.finalAzimuth.radians
            == westResult.finalAzimuth.radians);

    /*
     * The prepared WGS84 solver is already valid, but the general
     * ellipsoidal direct kernel is intentionally not part of this slice.
     */
    const wgs =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257223563);

    const wgsSolver =
        Geodesic!double.fromEllipsoid(wgs);

    assert(wgsSolver.isValid);
    assert(!wgsSolver.isSphere);

    assert(!wgsSolver.tryDirect(
        origin,
        Angle!double.fromDegrees(90.0),
        1_000_000.0,
        result));
}
