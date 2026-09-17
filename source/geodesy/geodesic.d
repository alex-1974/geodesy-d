/**
 * Direct and inverse ellipsoidal geodesic mathematics.
 *
 * The implementation contract is defined by ADR-0008.
 *
 * The current implementation provides:
 *
 * - prepared ellipsoid state;
 * - public angular canonicalization semantics;
 * - an analytical spherical direct path;
 * - the Karney series direct solution for supported oblate ellipsoids.
 *
 * The inverse kernel is added in a subsequent slice before this module is
 * aggregate-exported by `geodesy`.
 */
module geodesy.geodesic;

import std.math :
    PI,
    asin,
    atan2,
    cos,
    hypot,
    sin,
    sqrt;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude,
    angleFromRadiansUnchecked;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.internal.geodesic_series :
    fillGeodesicA3x,
    fillGeodesicC1,
    fillGeodesicC1p,
    fillGeodesicC3,
    fillGeodesicC3x,
    geodesicA1m1,
    geodesicA3,
    geodesicSeriesOrderFor,
    geodesicSinCosSeries;
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
 * The direct operation supports the exact sphere and the full initial
 * oblate-ellipsoid profile. The module remains intentionally outside the
 * aggregate export until the inverse solver and its validation gates are
 * complete.
 */
struct Geodesic(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;

    W _a = W.nan;
    W _f = W.nan;
    W _f1 = W.nan;
    W _b = W.nan;
    W _e2 = W.nan;
    W _ep2 = W.nan;
    W _n = W.nan;

    W[8] _a3x;
    W[28] _c3x;


    bool tryDirectEllipsoid(
        const W latitude1,
        const W longitude1,
        const W azimuth1,
        const W s12,
        out GeodesicDirectResult!T result) const
        pure nothrow @safe @nogc
    {
        enum int order = geodesicSeriesOrderFor!T;

        W sinPhi1;
        W cosPhi1;
        W sinAlpha1;
        W cosAlpha1;

        sinCosCanonicalAngle!W(
            latitude1,
            sinPhi1,
            cosPhi1);

        sinCosCanonicalAngle!W(
            azimuth1,
            sinAlpha1,
            cosAlpha1);

        if (!isFiniteGeodesyScalar(sinPhi1)
            || !isFiniteGeodesyScalar(cosPhi1)
            || !isFiniteGeodesyScalar(sinAlpha1)
            || !isFiniteGeodesyScalar(cosAlpha1))
            return false;

        /*
         * Reduced latitude beta1:
         *
         *     tan(beta1) = (1 - f) tan(phi1)
         *
         * Normalize explicitly.  At a pole retain a tiny positive
         * cosine so sigma/omega quadrants remain well defined.
         */
        W sinBeta1 = _f1 * sinPhi1;
        W cosBeta1 = cosPhi1;

        const W betaNorm =
            hypot(sinBeta1, cosBeta1);

        if (!isFiniteGeodesyScalar(betaNorm)
            || betaNorm == cast(W) 0)
            return false;

        sinBeta1 /= betaNorm;
        cosBeta1 /= betaNorm;

        const W tiny = sqrt(W.min_normal);

        if (cosBeta1 < tiny)
            cosBeta1 = tiny;

        /*
         * Clairaut constant:
         *
         *     sin(alpha0) = sin(alpha1) cos(beta1)
         */
        const W sinAlpha0 =
            sinAlpha1 * cosBeta1;

        const W cosAlpha0 =
            hypot(
                cosAlpha1,
                sinAlpha1 * sinBeta1);

        W sinSigma1 = sinBeta1;
        W cosSigma1 =
            sinBeta1 != cast(W) 0
                || cosAlpha1 != cast(W) 0
                ? cosBeta1 * cosAlpha1
                : cast(W) 1;

        const W sigmaNorm =
            hypot(sinSigma1, cosSigma1);

        if (!isFiniteGeodesyScalar(sigmaNorm)
            || sigmaNorm == cast(W) 0)
            return false;

        sinSigma1 /= sigmaNorm;
        cosSigma1 /= sigmaNorm;

        /*
         * omega1 need not be normalized independently.
         */
        const W sinOmega1 =
            sinAlpha0 * sinBeta1;

        const W cosOmega1 =
            sinBeta1 != cast(W) 0
                || cosAlpha1 != cast(W) 0
                ? cosBeta1 * cosAlpha1
                : cast(W) 1;

        const W k2 =
            cosAlpha0 * cosAlpha0 * _ep2;

        const W root =
            sqrt(cast(W) 1 + k2);

        const W eps =
            k2
            / (
                cast(W) 2
                * (cast(W) 1 + root)
                + k2);

        if (!isFiniteGeodesyScalar(k2)
            || !isFiniteGeodesyScalar(root)
            || !isFiniteGeodesyScalar(eps))
            return false;

        const W a1m1 =
            geodesicA1m1!(W, order)(eps);

        W[9] c1;
        W[9] c1p;

        fillGeodesicC1!(W, order)(
            eps,
            c1);

        fillGeodesicC1p!(W, order)(
            eps,
            c1p);

        const W b11 =
            geodesicSinCosSeries!W(
                true,
                sinSigma1,
                cosSigma1,
                c1,
                order);

        const W sinB11 = sin(b11);
        const W cosB11 = cos(b11);

        /*
         * tau1 = sigma1 + B1(sigma1)
         */
        const W sinTau1 =
            sinSigma1 * cosB11
            + cosSigma1 * sinB11;

        const W cosTau1 =
            cosSigma1 * cosB11
            - sinSigma1 * sinB11;

        const W denominator =
            _b * (cast(W) 1 + a1m1);

        if (!isFiniteGeodesyScalar(denominator)
            || denominator == cast(W) 0)
            return false;

        const W tau12 = s12 / denominator;

        if (!isFiniteGeodesyScalar(tau12))
            return false;

        const W sinTau12 = sin(tau12);
        const W cosTau12 = cos(tau12);

        const W b12 =
            -geodesicSinCosSeries!W(
                true,
                sinTau1 * cosTau12
                    + cosTau1 * sinTau12,
                cosTau1 * cosTau12
                    - sinTau1 * sinTau12,
                c1p,
                order);

        /*
         * Invert the distance series.  The support profile is
         * 0 <= f <= 0.01, so GeographicLib's >0.01 Newton
         * correction is deliberately unnecessary here.
         */
        const W sigma12 =
            tau12 - (b12 - b11);

        const W sinSigma12 = sin(sigma12);
        const W cosSigma12 = cos(sigma12);

        W sinSigma2 =
            sinSigma1 * cosSigma12
            + cosSigma1 * sinSigma12;

        W cosSigma2 =
            cosSigma1 * cosSigma12
            - sinSigma1 * sinSigma12;

        W sinBeta2 =
            cosAlpha0 * sinSigma2;

        W cosBeta2 =
            hypot(
                sinAlpha0,
                cosAlpha0 * cosSigma2);

        if (cosBeta2 == cast(W) 0)
        {
            cosBeta2 = tiny;
            cosSigma2 = tiny;
        }

        const W sinAlpha2 = sinAlpha0;
        const W cosAlpha2 =
            cosAlpha0 * cosSigma2;

        const W latitude2 =
            atan2(
                sinBeta2,
                _f1 * cosBeta2);

        /*
         * Auxiliary-sphere longitude difference.
         */
        const W sinOmega2 =
            sinAlpha0 * sinSigma2;

        const W cosOmega2 =
            cosSigma2;

        const W omega12 =
            atan2(
                sinOmega2 * cosOmega1
                    - cosOmega2 * sinOmega1,
                cosOmega2 * cosOmega1
                    + sinOmega2 * sinOmega1);

        W[9] c3;

        fillGeodesicC3!(W, order)(
            eps,
            _c3x,
            c3);

        const W a3 =
            geodesicA3!(W, order)(
                eps,
                _a3x);

        const W a3c =
            -_f * sinAlpha0 * a3;

        const W b31 =
            geodesicSinCosSeries!W(
                true,
                sinSigma1,
                cosSigma1,
                c3,
                order - 1);

        const W b32 =
            geodesicSinCosSeries!W(
                true,
                sinSigma2,
                cosSigma2,
                c3,
                order - 1);

        const W lambda12 =
            omega12
            + a3c
                * (
                    sigma12
                    + (b32 - b31));

        const W longitude2 =
            canonicalAngleRadians(
                longitude1 + lambda12);

        const W finalAzimuth =
            atan2(
                sinAlpha2,
                cosAlpha2);

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
            && _f <= cast(W) 0.01
            && isFiniteGeodesyScalar(_f1)
            && _f1 > cast(W) 0
            && isFiniteGeodesyScalar(_b)
            && _b > cast(W) 0
            && isFiniteGeodesyScalar(_e2)
            && _e2 >= cast(W) 0
            && isFiniteGeodesyScalar(_ep2)
            && _ep2 >= cast(W) 0
            && isFiniteGeodesyScalar(_n)
            && _n >= cast(W) 0;
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

        result._f1 = cast(W) 1 - result._f;
        result._b = result._a * result._f1;

        result._e2 =
            result._f
            * (cast(W) 2 - result._f);

        result._ep2 =
            result._e2
            / (result._f1 * result._f1);

        result._n =
            result._f
            / (cast(W) 2 - result._f);

        enum int order = geodesicSeriesOrderFor!T;

        fillGeodesicA3x!(W, order)(
            result._n,
            result._a3x);

        fillGeodesicC3x!(W, order)(
            result._n,
            result._c3x);

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
     * The spherical case is analytical.  Supported oblate ellipsoids use
     * the Karney distance-series formulation prepared by this solver.
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

        /*
         * At an exact pole the spherical closed form has an atan2(0, 0)
         * longitude degeneracy.  The supplied pole longitude is part of
         * the local azimuth frame under GEO-A, so use the line
         * formulation here.  Its positive-tiny reduced-latitude cosine
         * preserves that frame consistently.
         *
         * Zero distance has already been handled above and therefore
         * retains its distinct public semantics.
         */
        const W hp = halfPi!W;

        if (!isSphere
            || latitude1 == hp
            || latitude1 == -hp)
            return tryDirectEllipsoid(
                latitude1,
                longitude1,
                azimuth1,
                s12,
                result);

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

        /*
         * Algebraically cancel the common cos(phi1) factor from the
         * standard great-circle longitude formula.  This avoids severe
         * cancellation in
         *
         *     cos(delta) - sin(phi1) * sin(phi2)
         *
         * near either pole.  Exact pole starts have already been routed
         * through the line formulation above.
         */
        const W deltaLongitude = atan2(
            sinAlpha1 * sinDelta,
            cosPhi1 * cosDelta
                - sinPhi1 * sinDelta * cosAlpha1);

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

    const edgeEllipsoid =
        Ellipsoid!double.fromFlattening(
            7_000_000.0,
            0.01);

    const edgeSolver =
        Geodesic!double.fromEllipsoid(
            edgeEllipsoid);

    assert(edgeSolver.isValid);
    assert(!edgeSolver.isSphere);

    /*
     * The equator is an exact geodesic.  Its longitude increment is
     * distance / a, independent of flattening.
     */
    assert(wgsSolver.tryDirect(
        origin,
        Angle!double.fromDegrees(90.0),
        1_000_000.0,
        result));

    assert(result.position.latitude.radians == 0.0);
    assert(
        fabs(
            result.position.longitude.radians
                - 1_000_000.0 / 6_378_137.0)
        < 2e-15);
    assert(
        fabs(result.finalAzimuth.degrees - 90.0)
        < 1e-12);

    /*
     * Negative distance follows the same oriented geodesic backward.
     */
    assert(wgsSolver.tryDirect(
        origin,
        Angle!double.fromDegrees(90.0),
        -1_000_000.0,
        result));

    assert(result.position.latitude.radians == 0.0);
    assert(
        fabs(
            result.position.longitude.radians
                + 1_000_000.0 / 6_378_137.0)
        < 2e-15);
    assert(
        fabs(result.finalAzimuth.degrees - 90.0)
        < 1e-12);

    /*
     * A north-going meridian retains its longitude and azimuth.
     */
    assert(wgsSolver.tryDirect(
        origin,
        Angle!double.fromDegrees(0.0),
        1_000_000.0,
        result));

    assert(result.position.latitude.degrees > 0.0);
    assert(result.position.longitude.radians == 0.0);
    assert(result.finalAzimuth.radians == 0.0);

    /*
     * Canonically equivalent antimeridian starts remain equivalent on an
     * ellipsoid too.
     */
    assert(wgsSolver.tryDirect(
        eastAntimeridian,
        Angle!double.fromDegrees(90.0),
        50_000.0,
        eastResult));

    assert(wgsSolver.tryDirect(
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
     * The inclusive upper flattening bound is executable.
     */
    assert(edgeSolver.tryDirect(
        origin,
        Angle!double.fromDegrees(45.0),
        1_000_000.0,
        result));
}
