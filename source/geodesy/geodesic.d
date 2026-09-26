/**
 * Robust direct and inverse ellipsoidal geodesics on a prepared ellipsoid.
 *
 * The module solves the classical surface-geodesic problems with a
 * Karney-family auxiliary-sphere/series implementation rather than
 * Vincenty-style inverse iteration. The design explicitly covers difficult
 * configurations such as nearly antipodal points, poles, coincident points,
 * very short paths, and longitude discontinuities within its documented
 * ellipsoid domain.
 *
 * Domain:
 *     Prepared solvers support `a > 0` and `0 <= f <= 0.01`, including
 *     spheres. Positions are surface `GeographicCoordinate` values; no datum
 *     or CRS identity is embedded.
 *
 * Units:
 *     Returned distances use the same linear unit as the ellipsoid semi-major
 *     axis. Azimuths use strong `Angle` values.
 *
 * Numerics:
 *     The implementation follows Karney's geodesic formulation with
 *     scalar-dependent working precision and series order. Public float
 *     calculations use promoted double working precision.
 *
 * Performance:
 *     `Geodesic` prepares reusable ellipsoid-dependent coefficients once for
 *     repeated direct and inverse operations. Checked numerical operations are
 *     allocation-free.
 *
 * Validation:
 *     Accepted through analytical/special-case tests, deterministic corpora,
 *     published/high-precision reference data, and differential comparison
 *     with GeographicLib geodesic implementations and PROJ as appropriate.
 *
 * See_Also:
 *     `Geodesic`, `GeodesicDirectResult`, `GeodesicInverseResult`,
 *     `GeographicCoordinate`
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 *
 * Date:
 *     September 26, 2026
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
import geodesy.internal.geodesic_inverse_dispatch :
    geodesicInverseDispatch;
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
 * Lift a public latitude into the working scalar without losing exact
 * cardinal semantics at 0 and the geographic poles.
 *
 * This matters for `float`: float(pi/2) widened to double is not exactly
 * double(pi/2).
 */
private WorkingScalar!T workingLatitudeRadians(T)(
    const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = WorkingScalar!T;

    if (radians == cast(T) 0)
        return cast(W) 0;

    if (radians == halfPi!T)
        return halfPi!W;

    if (radians == -halfPi!T)
        return -halfPi!W;

    return cast(W) radians;
}


/**
 * Canonicalize an arbitrary public angle in T first, then lift it into W
 * while preserving exact cardinal values.
 *
 * Public scalar semantics own the representation boundary. In particular,
 * float(+pi) and float(-pi) must denote the same canonical -pi meridian even
 * though widening float(pi) to double no longer equals double(pi).
 */
private WorkingScalar!T workingCanonicalAngleRadians(T)(
    const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = WorkingScalar!T;

    const T canonical =
        canonicalAngleRadians!T(
            radians);

    if (canonical == cast(T) 0)
        return cast(W) 0;

    if (canonical == halfPi!T)
        return halfPi!W;

    if (canonical == -halfPi!T)
        return -halfPi!W;

    if (canonical == -pi!T)
        return -pi!W;

    return cast(W) canonical;
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
 * `position` is the endpoint. `finalAzimuth` is the forward azimuth at
 * that endpoint: the heading of the same oriented geodesic if continued
 * beyond the endpoint. It is not a back azimuth.
 *
 * Azimuths use the public canonical angle interval from -pi inclusive to +pi
 * exclusive.
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
 * Result of an inverse geodesic operation.
 *
 * `distance` is the shortest geodesic distance and uses the same linear unit
 * as the solver ellipsoid semi-major axis. `initialAzimuth` is the forward
 * azimuth at the start; `finalAzimuth` is the forward azimuth of the same
 * oriented geodesic at the endpoint, not the back azimuth.
 *
 * Both azimuths are canonicalized from -pi inclusive to +pi exclusive.
 * Coincident endpoints have the unique canonical result distance +0,
 * initial azimuth +0, final azimuth +0.
 */
struct GeodesicInverseResult(T)
if (isGeodesyScalar!T)
{
private:
    T _distance = 0;
    Angle!T _initialAzimuth;
    Angle!T _finalAzimuth;

    static GeodesicInverseResult fromComponents(
        const T distance,
        const Angle!T initialAzimuth,
        const Angle!T finalAzimuth)
        pure nothrow @safe @nogc
    {
        GeodesicInverseResult result;
        result._distance = distance;
        result._initialAzimuth = initialAzimuth;
        result._finalAzimuth = finalAzimuth;
        return result;
    }

public:
    /**
     * Shortest geodesic distance in the same linear unit as the ellipsoid
     * semi-major axis.
     */
    @property T distance() const
        pure nothrow @safe @nogc
    {
        return _distance;
    }

    /** Forward azimuth at the start point, canonicalized from -pi inclusive to +pi exclusive. */
    @property Angle!T initialAzimuth() const
        pure nothrow @safe @nogc
    {
        return _initialAzimuth;
    }

    /**
     * Forward azimuth at the endpoint, canonicalized from -pi inclusive to +pi exclusive.
     *
     * This is not the back azimuth.
     */
    @property Angle!T finalAzimuth() const
        pure nothrow @safe @nogc
    {
        return _finalAzimuth;
    }
}


/**
 * Prepared direct/inverse geodesic solver for one reference ellipsoid.
 *
 * Supported ellipsoids satisfy `a > 0` and `0 <= f <= 0.01`; no Earth-size
 * restriction applies. Linear distances use the same unit as the ellipsoid
 * semi-major axis. Exact spheres and supported oblate ellipsoids are handled.
 *
 * `.init` is invalid. Prepare a solver once and reuse it for multiple direct
 * or inverse operations.
 *
 * Direct operations accept finite signed distance. Negative distance follows
 * the same oriented geodesic backward. Inverse operations return the shortest
 * geodesic and canonical coincident-point semantics.
 *
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
     * Prepare a reusable direct/inverse solver without throwing.
     *
     * Params:
     *     ellipsoid = Valid spherical or oblate ellipsoid with
     *         0 <= f <= 0.01. Its semi-major axis defines the distance unit.
     *     result = Receives the prepared solver on success.
     *
     * Returns:
     *     `true` when the ellipsoid and all derived solver coefficients are
     *     finite and supported; otherwise `false`. A failed attempt leaves
     *     `result` as `Geodesic!T.init`, even when it was previously valid.
     */
    static bool tryFromEllipsoid(
        const Ellipsoid!T ellipsoid,
        out Geodesic result)
        pure nothrow @safe @nogc
    {
        if (!ellipsoid.isValid
            || ellipsoid.flattening > cast(T) 0.01)
            return false;

        Geodesic candidate;

        candidate._ellipsoid = ellipsoid;
        candidate._a = cast(W) ellipsoid.semiMajorAxis;
        candidate._f = cast(W) ellipsoid.flattening;

        candidate._f1 = cast(W) 1 - candidate._f;
        candidate._b = candidate._a * candidate._f1;

        candidate._e2 =
            candidate._f
            * (cast(W) 2 - candidate._f);

        candidate._ep2 =
            candidate._e2
            / (candidate._f1 * candidate._f1);

        candidate._n =
            candidate._f
            / (cast(W) 2 - candidate._f);

        enum int order = geodesicSeriesOrderFor!T;

        fillGeodesicA3x!(W, order)(
            candidate._n,
            candidate._a3x);

        fillGeodesicC3x!(W, order)(
            candidate._n,
            candidate._c3x);

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }


        /**
     * Prepare a reusable direct/inverse solver.
     *
     * Params:
     *     ellipsoid = Valid spherical or oblate ellipsoid with
     *         0 <= f <= 0.01.
     *
     * Returns:
     *     The prepared solver; distances use the ellipsoid semi-major-axis unit.
     *
     * Throws:
     *     `GeodesyValueException` for an invalid or unsupported ellipsoid.
     */
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
     * Starting from `start`, follow `initialAzimuth` for signed `distance`.
     * Negative distance follows the same oriented geodesic backward. Returned
     * longitude and final forward azimuth use the canonical interval from -pi
     * inclusive to +pi exclusive. At zero distance the supplied oriented line
     * is retained rather than applying inverse coincidence semantics.
     *
     * Params:
     *     start = Geographic start position.
     *     initialAzimuth = Initial forward azimuth; finite arbitrary-turn
     *         values are canonicalized by the solver.
     *     distance = Finite signed distance in the ellipsoid linear unit.
     *     result = Receives endpoint and final forward azimuth.
     *
     * Returns:
     *     `true` when the prepared solver is valid and a finite representable
     *     result is produced; otherwise `false`. Before validation,
     *     `result` is reset to `GeodesicDirectResult!T.init`.
     *
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
            workingLatitudeRadians!T(
                start.latitude.radians);

        const W longitude1 =
            workingCanonicalAngleRadians!T(
                start.longitude.radians);

        const W azimuth1 =
            workingCanonicalAngleRadians!T(
                initialAzimuth.radians);

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

    /// Example using bool tryDirect( const GeographicCoordinate!T start, const Angle!T initialAzimuth, const T .
    @safe unittest
    {
        import geodesy;
        
        const solver = Geodesic!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        
        GeodesicDirectResult!double result;
        assert(solver.tryDirect(
            start, Angle!double.fromDegrees(90.0), 1_000.0, result));
        assert(result.position.longitude.degrees > 16.37208);
    }



        /**
     * Solve the direct geodesic problem with throwing failure semantics.
     *
     * Params:
     *     start = Geographic start position.
     *     initialAzimuth = Initial forward azimuth.
     *     distance = Finite signed distance in the ellipsoid linear unit.
     *
     * Returns:
     *     Endpoint and final forward azimuth using canonical public angles.
     *
     * Throws:
     *     `GeodesyValueException` when the solver is invalid or no finite
     *     representable direct solution can be produced.
     */
    GeodesicDirectResult!T direct(
        const GeographicCoordinate!T start,
        const Angle!T initialAzimuth,
        const T distance) const
        @safe
    {
        GeodesicDirectResult!T result;

        if (!tryDirect(
                start,
                initialAzimuth,
                distance,
                result))
        {
            throw new GeodesyValueException(
                "Direct geodesic solution requires a valid solver, finite "
                ~ "inputs, and a finite representable result.");
        }

        return result;
    }


        /**
     * Solve the shortest inverse geodesic problem without throwing.
     *
     * The final azimuth is the forward heading of the same oriented geodesic
     * continuing beyond the endpoint, not the back azimuth. Coincident
     * endpoints return canonical positive-zero distance and azimuths.
     * Distance uses the ellipsoid linear unit; azimuths use the canonical
     * interval from -pi inclusive to +pi exclusive.
     *
     * Params:
     *     start = Geographic start position.
     *     end = Geographic endpoint.
     *     result = Receives distance, initial azimuth, and final azimuth.
     *
     * Returns:
     *     `true` when the prepared solver is valid and a finite representable
     *     shortest-geodesic solution is produced; otherwise `false`. Before
     *     validation, `result` is reset to `GeodesicInverseResult!T.init`.
     *
     */
    bool tryInverse(
        const GeographicCoordinate!T start,
        const GeographicCoordinate!T end,
        out GeodesicInverseResult!T result) const
        pure nothrow @safe @nogc
    {
        result =
            GeodesicInverseResult!T.init;

        if (!isValid)
            return false;

        const W latitude1 =
            workingLatitudeRadians!T(
                start.latitude.radians);

        const W longitude1 =
            workingCanonicalAngleRadians!T(
                start.longitude.radians);

        const W latitude2 =
            workingLatitudeRadians!T(
                end.latitude.radians);

        const W longitude2 =
            workingCanonicalAngleRadians!T(
                end.longitude.radians);

        if (
            !isFiniteGeodesyScalar(latitude1)
            || !isFiniteGeodesyScalar(longitude1)
            || !isFiniteGeodesyScalar(latitude2)
            || !isFiniteGeodesyScalar(longitude2)
        )
            return false;

        enum int order =
            geodesicSeriesOrderFor!T;

        const inverse =
            geodesicInverseDispatch!(
                W,
                order)(
                    _a,
                    _f,
                    _f1,
                    _b,
                    _ep2,
                    _n,
                    _a3x,
                    _c3x,
                    latitude1,
                    longitude1,
                    latitude2,
                    longitude2);

        const T distance =
            canonicalZero(
                cast(T) inverse.distance);

        const T initialAzimuth =
            canonicalAngleRadians(
                cast(T) inverse.initialAzimuth);

        const T finalAzimuth =
            canonicalAngleRadians(
                cast(T) inverse.finalAzimuth);

        if (
            !isFiniteGeodesyScalar(distance)
            || distance < cast(T) 0
            || !isFiniteGeodesyScalar(initialAzimuth)
            || !isFiniteGeodesyScalar(finalAzimuth)
        )
            return false;

        result =
            GeodesicInverseResult!T.fromComponents(
                distance,
                angleFromRadiansUnchecked(
                    initialAzimuth),
                angleFromRadiansUnchecked(
                    finalAzimuth));

        return true;
    }

    /// Example using bool tryInverse( const GeographicCoordinate!T start, const GeographicCoordinate!T end, out.
    @safe unittest
    {
        import geodesy;
        
        const solver = Geodesic!double.fromEllipsoid(wgs84!double());
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const newYork = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(40.7128),
            Longitude!double.fromDegrees(-74.0060));
        
        GeodesicInverseResult!double result;
        assert(solver.tryInverse(vienna, newYork, result));
        assert(result.distance > 6_000_000.0);
        assert(result.distance < 7_000_000.0);
    }



        /**
     * Solve the shortest inverse geodesic problem with throwing semantics.
     *
     * Params:
     *     start = Geographic start position.
     *     end = Geographic endpoint.
     *
     * Returns:
     *     Distance plus initial and final forward azimuths.
     *
     * Throws:
     *     `GeodesyValueException` when the solver is invalid or no finite
     *     representable inverse solution can be produced.
     */
    GeodesicInverseResult!T inverse(
        const GeographicCoordinate!T start,
        const GeographicCoordinate!T end) const
        @safe
    {
        GeodesicInverseResult!T result;

        if (!tryInverse(
                start,
                end,
                result))
        {
            throw new GeodesyValueException(
                "Inverse geodesic solution requires a valid solver, finite "
                ~ "inputs, and a finite representable result.");
        }

        return result;
    }
}

/// Example using struct Geodesic(T) if (isGeodesyScalar!T).
@safe unittest
{
    import geodesy;
    
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());
    
    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    
    const newYork = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(40.7128),
        Longitude!double.fromDegrees(-74.0060));
    
    const inverse = solver.inverse(vienna, newYork);
    const direct = solver.direct(
        vienna, inverse.initialAzimuth, inverse.distance);
    
    assert(inverse.distance > 0.0);
    assert(direct.position.latitude.degrees < 41.0);
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

    // A failed checked construction resets the out result to exact .init,
    // even when the caller passes a previously valid solver.
    assert(!Geodesic!double.tryFromEllipsoid(
        Ellipsoid!double.init,
        candidate));
    assert(!candidate.isValid);
    assert(!candidate.ellipsoid.isValid);

    assert(Geodesic!double.tryFromEllipsoid(
        sphere,
        candidate));

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


unittest
{
    import std.exception : assertThrown;

    const ellipsoid =
        Ellipsoid!double.fromFlattening(
            6_378_137.0,
            1.0 / 298.257223563);
    const solver = Geodesic!double.fromEllipsoid(ellipsoid);

    const start =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));

    const end =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(40.7128),
            Longitude!double.fromDegrees(-74.0060));

    const directResult = solver.direct(
        start,
        Angle!double.fromDegrees(90.0),
        1_000.0);
    assert(directResult.position.latitude.radians
        == directResult.position.latitude.radians);

    const inverseResult = solver.inverse(start, end);
    assert(inverseResult.distance >= 0.0);

    const invalid = Geodesic!double.init;

    assertThrown!GeodesyValueException(
        invalid.direct(
            start,
            Angle!double.fromDegrees(90.0),
            1_000.0));

    assertThrown!GeodesyValueException(
        invalid.inverse(start, end));
}



unittest
{
    import std.math :
        PI,
        fabs,
        signbit;
    import std.meta : AliasSeq;

    /*
     * Public inverse API: representative WGS84 path.
     */
    const wgs84 =
        Ellipsoid!double.fromFlattening(
            6_378_137.0,
            1.0 / 298.257223563);

    const solver =
        Geodesic!double.fromEllipsoid(wgs84);

    const vienna =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));

    const newYork =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(40.7128),
            Longitude!double.fromDegrees(-74.0060));

    GeodesicInverseResult!double inverse;

    assert(
        solver.tryInverse(
            vienna,
            newYork,
            inverse));

    assert(inverse.distance > 6_000_000.0);
    assert(inverse.distance < 7_000_000.0);

    assert(
        inverse.initialAzimuth.radians
            >= -cast(double) PI
        && inverse.initialAzimuth.radians
            < cast(double) PI);

    assert(
        inverse.finalAzimuth.radians
            >= -cast(double) PI
        && inverse.finalAzimuth.radians
            < cast(double) PI);

    /*
     * Direct/inverse closure through the public APIs.
     */
    GeodesicDirectResult!double direct;

    assert(
        solver.tryDirect(
            vienna,
            inverse.initialAzimuth,
            inverse.distance,
            direct));

    assert(
        fabs(
            direct.position.latitude.radians
            - newYork.latitude.radians)
        < 2e-13);

    double longitudeError =
        direct.position.longitude.radians
        - newYork.longitude.radians;

    if (longitudeError >= cast(double) PI)
        longitudeError -= cast(double) 2 * PI;
    else if (longitudeError < -cast(double) PI)
        longitudeError += cast(double) 2 * PI;

    assert(
        fabs(longitudeError)
        < 2e-13);

    assert(
        fabs(
            canonicalAngleRadians(
                direct.finalAzimuth.radians
                - inverse.finalAzimuth.radians))
        < 2e-13);

    /*
     * GEO-A coincidence: all outputs are canonical positive zero.
     */
    GeodesicInverseResult!double coincident;

    assert(
        solver.tryInverse(
            vienna,
            vienna,
            coincident));

    assert(coincident.distance == 0.0);
    assert(coincident.initialAzimuth.radians == 0.0);
    assert(coincident.finalAzimuth.radians == 0.0);

    assert(!signbit(coincident.distance));
    assert(!signbit(coincident.initialAzimuth.radians));
    assert(!signbit(coincident.finalAzimuth.radians));

    /*
     * +pi and -pi are the same public start/end meridian.
     */
    const eastAntimeridian =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(20.0),
            Longitude!double.fromDegrees(180.0));

    const westAntimeridian =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(20.0),
            Longitude!double.fromDegrees(-180.0));

    GeodesicInverseResult!double antimeridianCoincidence;

    assert(
        solver.tryInverse(
            eastAntimeridian,
            westAntimeridian,
            antimeridianCoincidence));

    assert(antimeridianCoincidence.distance == 0.0);
    assert(antimeridianCoincidence.initialAzimuth.radians == 0.0);
    assert(antimeridianCoincidence.finalAzimuth.radians == 0.0);

    /*
     * Public float cardinal semantics survive widening to the double working
     * scalar: +/-180 degrees are the same meridian.
     */
    {
        const floatSolver =
            Geodesic!float.fromEllipsoid(
                Ellipsoid!float.sphere(
                    6_371_000.0f));

        const east =
            GeographicCoordinate!float.fromComponents(
                Latitude!float.fromDegrees(20.0f),
                Longitude!float.fromDegrees(180.0f));

        const west =
            GeographicCoordinate!float.fromComponents(
                Latitude!float.fromDegrees(20.0f),
                Longitude!float.fromDegrees(-180.0f));

        GeodesicInverseResult!float sameMeridian;

        assert(
            floatSolver.tryInverse(
                east,
                west,
                sameMeridian));

        assert(sameMeridian.distance == 0.0f);
        assert(sameMeridian.initialAzimuth.radians == 0.0f);
        assert(sameMeridian.finalAzimuth.radians == 0.0f);

        const northPoleEast =
            GeographicCoordinate!float.fromComponents(
                Latitude!float.fromDegrees(90.0f),
                Longitude!float.fromDegrees(45.0f));

        const northPoleWest =
            GeographicCoordinate!float.fromComponents(
                Latitude!float.fromDegrees(90.0f),
                Longitude!float.fromDegrees(-135.0f));

        GeodesicInverseResult!float samePole;

        assert(
            floatSolver.tryInverse(
                northPoleEast,
                northPoleWest,
                samePole));

        assert(samePole.distance == 0.0f);
        assert(samePole.initialAzimuth.radians == 0.0f);
        assert(samePole.finalAzimuth.radians == 0.0f);

        GeodesicDirectResult!float poleDirect;

        assert(
            floatSolver.tryDirect(
                northPoleEast,
                Angle!float.fromDegrees(0.0f),
                1000.0f,
                poleDirect));

        assert(
            isFiniteGeodesyScalar(
                poleDirect.position.latitude.radians));

        assert(
            isFiniteGeodesyScalar(
                poleDirect.position.longitude.radians));

        assert(
            isFiniteGeodesyScalar(
                poleDirect.finalAzimuth.radians));
    }

    /*
     * Sphere equator: exact quarter circumference and eastward azimuth.
     */
    const sphereSolver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.sphere(
                6_371_000.0));

    const equator0 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    const equator90 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(90.0));

    GeodesicInverseResult!double equator;

    assert(
        sphereSolver.tryInverse(
            equator0,
            equator90,
            equator));

    assert(
        fabs(
            equator.distance
            - 6_371_000.0
                * cast(double) PI
                / 2.0)
        < 1e-8);

    assert(
        fabs(
            equator.initialAzimuth.radians
            - cast(double) PI / 2.0)
        < 1e-15);

    assert(
        fabs(
            equator.finalAzimuth.radians
            - cast(double) PI / 2.0)
        < 1e-15);

    /*
     * Invalid prepared solver follows tryDirect's false/result-init pattern.
     */
    GeodesicInverseResult!double invalidResult;

    assert(
        !Geodesic!double.init.tryInverse(
            vienna,
            newYork,
            invalidResult));

    assert(invalidResult.distance == 0.0);
    assert(invalidResult.initialAzimuth.radians == 0.0);
    assert(invalidResult.finalAzimuth.radians == 0.0);

    /*
     * Instantiate the public API for every supported scalar family.
     */
    static foreach (
        Scalar;
        AliasSeq!(float, double, real))
    {
        {
            const ellipsoid =
                Ellipsoid!Scalar.fromFlattening(
                    cast(Scalar) 6_378_137.0,
                    cast(Scalar) (
                        1.0 / 298.257223563
                    ));

            const typedSolver =
                Geodesic!Scalar.fromEllipsoid(
                    ellipsoid);

            const start =
                GeographicCoordinate!Scalar.fromComponents(
                    Latitude!Scalar.fromDegrees(
                        cast(Scalar) -30),
                    Longitude!Scalar.fromDegrees(
                        cast(Scalar) 15));

            const end =
                GeographicCoordinate!Scalar.fromComponents(
                    Latitude!Scalar.fromDegrees(
                        cast(Scalar) 42),
                    Longitude!Scalar.fromDegrees(
                        cast(Scalar) 120));

            GeodesicInverseResult!Scalar typedResult;

            assert(
                typedSolver.tryInverse(
                    start,
                    end,
                    typedResult));

            assert(
                typedResult.distance
                    > cast(Scalar) 0);
        }
    }
}
