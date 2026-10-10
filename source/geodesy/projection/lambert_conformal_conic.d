/**
 * Project geographic positions onto a conic map that preserves local angles.
 *
 * Use Lambert Conformal Conic when your map uses two standard parallels,
 * such as the grid definitions used for Austria Lambert or LCC Europe.
 * Supply the specified ellipsoid, origin, two parallels and grid offsets.
 * The prepared projection converts in both directions and reports local
 * scale and meridian convergence.
 *
 * This implementation supports spherical and oblate ellipsoids with
 * 0 <= flattening <= 0.01 and requires two distinct non-polar parallels.
 *
 * Standards:
 *     Public parameter semantics follow EPSG method 9802 -- Lambert Conic
 *     Conformal (2SP). Authority-backed validation includes EPSG:31287
 *     (MGI / Austria Lambert) and EPSG:3034 (ETRS89-extended / LCC Europe).
 *
 * Domain:
 *     Standard parallels must be finite, distinct, non-polar, and must not
 *     form the degenerate opposite-parallel case. The public v1.2 family is
 *     deliberately 2SP; equal parallels are not silently treated as 1SP.
 *
 * Units:
 *     False easting, false northing, projected coordinates, and ellipsoid
 *     axes use the same caller-selected linear unit. Conformal point scale is
 *     dimensionless and meridian convergence is an Angle.
 *
 * Numerics:
 *     Public float uses double working precision. Checked hot paths are pure,
 *     nothrow, @safe, and @nogc.
 *
 * See_Also:
 *     ConformalProjectionFactors, TransverseMercator, PolarStereographic
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
 *     October 6, 2026
 */
module geodesy.projection.lambert_conformal_conic;

import std.math :
    PI,
    asinh,
    atanh,
    atan,
    atan2,
    cos,
    exp,
    fabs,
    log,
    sin,
    sqrt,
    tan;

import geodesy.angle : Angle, Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.factors : ConformalProjectionFactors;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


/** Return pi in scalar type T. */
private T pi(T)()
    pure nothrow @safe @nogc
{
    return cast(T) PI;
}


/** Return pi/2 in scalar type T. */
private T halfPi(T)()
    pure nothrow @safe @nogc
{
    return pi!T / cast(T) 2;
}


/** Return 2*pi in scalar type T. */
private T twoPi(T)()
    pure nothrow @safe @nogc
{
    return cast(T) 2 * pi!T;
}


/** Canonicalize either signed zero to positive zero. */
private T canonicalZero(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == cast(T) 0 ? cast(T) 0 : value;
}


/** Canonicalize finite radians to [-pi,+pi). */
private T canonicalAngleRadians(T)(const T radians)
    pure nothrow @safe @nogc
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


/** Lift public latitude while preserving exact cardinal representation. */
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


/** Lift canonical public longitude while preserving exact cardinal values. */
private WorkingScalar!T workingLongitudeRadians(T)(
    const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = WorkingScalar!T;
    const T canonical = canonicalAngleRadians(radians);

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


/** Canonical shortest longitude difference in [-pi,+pi). */
private T longitudeDifference(T)(
    const T longitude,
    const T origin)
    pure nothrow @safe @nogc
{
    return canonicalAngleRadians(longitude - origin);
}


/** Stable two-argument hypotenuse. */
private T hypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T high = ax > ay ? ax : ay;
    const T low = ax > ay ? ay : ax;

    if (high == cast(T) 0)
        return cast(T) 0;

    const T ratio = low / high;
    return high * sqrt(cast(T) 1 + ratio * ratio);
}


/** Exact sine/cosine for public cardinal latitudes. */
private void sinCosLatitude(T)(
    const T latitude,
    out T sine,
    out T cosine)
    pure nothrow @safe @nogc
{
    if (latitude == cast(T) 0)
    {
        sine = cast(T) 0;
        cosine = cast(T) 1;
        return;
    }

    if (latitude == halfPi!T)
    {
        sine = cast(T) 1;
        cosine = cast(T) 0;
        return;
    }

    if (latitude == -halfPi!T)
    {
        sine = cast(T) -1;
        cosine = cast(T) 0;
        return;
    }

    sine = sin(latitude);
    cosine = cos(latitude);
}


/** Ellipsoidal conformal m(phi) term. */
private T conformalM(T)(
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    const T denominator =
        sqrt(cast(T) 1 - e2 * sine * sine);

    return cosine / denominator;
}


/** Ellipsoidal isometric latitude. */
private T isometricLatitude(T)(
    const T eccentricity,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    if (cosine == cast(T) 0)
        return latitude > cast(T) 0
            ? T.infinity
            : -T.infinity;

    const T tangent = sine / cosine;
    T result = asinh(tangent);

    if (eccentricity != cast(T) 0)
        result -= eccentricity
            * atanh(eccentricity * sine);

    return result;
}


/** Exact derivative d(psi)/d(phi) for isometric latitude. */
private T isometricDerivative(T)(
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    if (cosine == cast(T) 0)
        return T.infinity;

    return (cast(T) 1 - e2)
        / (cosine
            * (cast(T) 1 - e2 * sine * sine));
}


/** Invert finite isometric latitude on the open pole interval. */
private bool inverseIsometricLatitude(T)(
    const T e2,
    const T psi,
    out T latitude)
    pure nothrow @safe @nogc
{
    latitude = T.nan;

    if (!isFiniteGeodesyScalar(psi))
        return false;

    T phi =
        cast(T) 2 * atan(exp(psi))
        - halfPi!T;

    foreach (_; 0 .. 12)
    {
        const T value =
            isometricLatitude(sqrt(e2), phi);

        const T derivative =
            isometricDerivative(e2, phi);

        if (!isFiniteGeodesyScalar(value)
            || !isFiniteGeodesyScalar(derivative)
            || !(derivative > cast(T) 0))
            return false;

        const T correction =
            (value - psi) / derivative;

        phi -= correction;

        if (phi <= -halfPi!T || phi >= halfPi!T)
            return false;

        if (fabs(correction)
            <= cast(T) 8 * T.epsilon
                * (cast(T) 1 + fabs(phi)))
        {
            latitude = phi;
            return true;
        }
    }

    const T residual =
        isometricLatitude(sqrt(e2), phi) - psi;

    if (fabs(residual)
        > cast(T) 64 * T.epsilon
            * (cast(T) 1 + fabs(psi)))
        return false;

    latitude = phi;
    return true;
}


/**
 * Prepared EPSG 9802 Lambert Conformal Conic (2SP) projection.
 *
 * `.init` is intentionally invalid.
 */
struct LambertConformalConic(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    Latitude!T _latitudeOfFalseOrigin;
    Longitude!T _longitudeOfFalseOrigin;
    Latitude!T _firstStandardParallel;
    Latitude!T _secondStandardParallel;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;
    T _apexNorthing = T.nan;

    W _a = W.nan;
    W _e2 = W.nan;
    W _e = W.nan;
    W _n = W.nan;
    W _fConstant = W.nan;
    W _rho0 = W.nan;

    /**
     * Compute signed rho for an accepted latitude.
     *
     * Internal precondition: the caller has verified isValid.
     * forwardWorking is the sole caller and performs that check.
     */
    bool rhoForLatitude(
        const W latitude,
        out W rho) const
        pure nothrow @safe @nogc
    {
        rho = W.nan;

        const W hp = halfPi!W;

        if (latitude == hp)
        {
            if (_n <= cast(W) 0)
                return false;

            rho = cast(W) 0;
            return true;
        }

        if (latitude == -hp)
        {
            if (_n >= cast(W) 0)
                return false;

            rho = cast(W) 0;
            return true;
        }

        const W psi =
            isometricLatitude(
                _e,
                latitude);

        if (!isFiniteGeodesyScalar(psi))
            return false;

        const W exponent =
            -_n * psi;

        const W radialFactor =
            exp(exponent);

        if (!isFiniteGeodesyScalar(radialFactor)
            || !(radialFactor > cast(W) 0))
            return false;

        rho =
            _a * _fConstant * radialFactor;

        return isFiniteGeodesyScalar(rho)
            && rho * _n > cast(W) 0;
    }


    /** Compute projected working coordinates and reusable forward state. */
    bool forwardWorking(
        const GeographicCoordinate!T source,
        out W easting,
        out W northing,
        out W latitude,
        out W deltaLongitude,
        out W rho) const
        pure nothrow @safe @nogc
    {
        easting = W.nan;
        northing = W.nan;
        latitude = W.nan;
        deltaLongitude = W.nan;
        rho = W.nan;

        if (!isValid)
            return false;

        latitude =
            workingLatitudeRadians!T(
                source.latitude.radians);

        const W longitude =
            workingLongitudeRadians!T(
                source.longitude.radians);

        const W originLongitude =
            workingLongitudeRadians!T(
                _longitudeOfFalseOrigin.radians);

        if (!isFiniteGeodesyScalar(latitude)
            || !isFiniteGeodesyScalar(longitude)
            || !isFiniteGeodesyScalar(originLongitude))
            return false;

        if (!rhoForLatitude(latitude, rho))
            return false;

        deltaLongitude =
            longitudeDifference(
                longitude,
                originLongitude);

        const W theta =
            _n * deltaLongitude;

        if (rho == cast(W) 0)
        {
            easting = cast(W) _falseEasting;
            northing = cast(W) _apexNorthing;
        }
        else
        {
            easting =
                cast(W) _falseEasting
                + rho * sin(theta);

            northing =
                cast(W) _falseNorthing
                + _rho0
                - rho * cos(theta);
        }

        return isFiniteGeodesyScalar(easting)
            && isFiniteGeodesyScalar(northing);
    }


    /** Recover accepted geographic working state from a projected point. */
    bool reverseWorking(
        const ProjectedCoordinate!T source,
        out W latitude,
        out W longitude,
        out W rho) const
        pure nothrow @safe @nogc
    {
        latitude = W.nan;
        longitude = W.nan;
        rho = W.nan;

        if (!isValid)
            return false;

        W dx =
            cast(W) source.easting
            - cast(W) _falseEasting;

        W dy =
            _rho0
            - (cast(W) source.northing
                - cast(W) _falseNorthing);

        if (!isFiniteGeodesyScalar(dx)
            || !isFiniteGeodesyScalar(dy))
            return false;

        if (source.easting == _falseEasting
            && source.northing == _apexNorthing)
        {
            rho = cast(W) 0;
            latitude =
                _n > cast(W) 0
                    ? halfPi!W
                    : -halfPi!W;

            longitude =
                workingLongitudeRadians!T(
                    _longitudeOfFalseOrigin.radians);

            return true;
        }

        rho = hypot2(dx, dy);

        if (rho == cast(W) 0)
        {
            latitude =
                _n > cast(W) 0
                    ? halfPi!W
                    : -halfPi!W;

            longitude =
                workingLongitudeRadians!T(
                    _longitudeOfFalseOrigin.radians);

            return true;
        }

        if (_n < cast(W) 0)
        {
            rho = -rho;
            dx = -dx;
            dy = -dy;
        }

        const W ratio =
            rho / (_a * _fConstant);

        if (!isFiniteGeodesyScalar(ratio)
            || !(ratio > cast(W) 0))
            return false;

        const W logT =
            log(ratio) / _n;

        const W psi =
            -logT;

        if (!inverseIsometricLatitude(
                _e2,
                psi,
                latitude))
            return false;

        W deltaLongitude =
            atan2(dx, dy) / _n;

        const W p = pi!W;

        if (deltaLongitude < -p
            || deltaLongitude >= p)
            return false;

        const W originLongitude =
            workingLongitudeRadians!T(
                _longitudeOfFalseOrigin.radians);

        longitude =
            canonicalAngleRadians(
                originLongitude + deltaLongitude);

        return isFiniteGeodesyScalar(longitude);
    }

public:
    /** True when this value contains supported prepared EPSG 9802 state. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && _ellipsoid.flattening >= cast(T) 0
            && _ellipsoid.flattening <= cast(T) 0.01
            && isFiniteGeodesyScalar(_falseEasting)
            && isFiniteGeodesyScalar(_falseNorthing)
            && isFiniteGeodesyScalar(_apexNorthing)
            && isFiniteGeodesyScalar(_a)
            && _a > cast(W) 0
            && isFiniteGeodesyScalar(_e2)
            && _e2 >= cast(W) 0
            && isFiniteGeodesyScalar(_n)
            && _n != cast(W) 0
            && isFiniteGeodesyScalar(_fConstant)
            && _fConstant * _n > cast(W) 0
            && isFiniteGeodesyScalar(_rho0);
    }

    /// Example checking prepared LCC state.
    @safe unittest
    {
        import geodesy;
        assert(!LambertConformalConic!double.init.isValid);
    }


    /**
     * Set up a two-standard-parallel conic map without throwing.
     *
     * Use the parameters from the coordinate system you want to reproduce:
     * ellipsoid, latitude and longitude of false origin, the two standard
     * parallels, and false easting/northing. The parallels control the map's
     * scale; they must be distinct and neither may be a pole. The offsets
     * use the ellipsoid's linear unit. Returns `false` for unsupported
     * parameters instead of raising an exception.
     */
    static bool tryFromTwoStandardParallels(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfFalseOrigin,
        const Longitude!T longitudeOfFalseOrigin,
        const Latitude!T firstStandardParallel,
        const Latitude!T secondStandardParallel,
        const T falseEasting,
        const T falseNorthing,
        out LambertConformalConic result)
        pure nothrow @safe @nogc
    {
        result = LambertConformalConic.init;

        if (!ellipsoid.isValid
            || ellipsoid.flattening < cast(T) 0
            || ellipsoid.flattening > cast(T) 0.01
            || !isFiniteGeodesyScalar(falseEasting)
            || !isFiniteGeodesyScalar(falseNorthing))
            return false;

        const T hp = halfPi!T;
        const T p1Public =
            firstStandardParallel.radians;
        const T p2Public =
            secondStandardParallel.radians;

        if (p1Public <= -hp || p1Public >= hp
            || p2Public <= -hp || p2Public >= hp
            || p1Public == p2Public
            || p1Public + p2Public == cast(T) 0)
            return false;

        const W a =
            cast(W) ellipsoid.semiMajorAxis;

        const W f =
            cast(W) ellipsoid.flattening;

        const W e2 =
            f * (cast(W) 2 - f);

        const W e =
            sqrt(e2);

        const W p1 =
            workingLatitudeRadians!T(p1Public);

        const W p2 =
            workingLatitudeRadians!T(p2Public);

        const W m1 = conformalM(e2, p1);
        const W m2 = conformalM(e2, p2);

        const W psi1 =
            isometricLatitude(e, p1);

        const W psi2 =
            isometricLatitude(e, p2);

        if (!isFiniteGeodesyScalar(m1)
            || !isFiniteGeodesyScalar(m2)
            || !(m1 > cast(W) 0)
            || !(m2 > cast(W) 0)
            || !isFiniteGeodesyScalar(psi1)
            || !isFiniteGeodesyScalar(psi2))
            return false;

        /*
         * log(t1/t2) = psi2 - psi1 because t = exp(-psi).
         * This avoids separately materializing t1/t2.
         */
        const W denominator =
            psi2 - psi1;

        if (denominator == cast(W) 0)
            return false;

        const W n =
            log(m1 / m2) / denominator;

        if (!isFiniteGeodesyScalar(n)
            || n == cast(W) 0)
            return false;

        /*
         * F = m1 / (n * t1^n)
         *   = m1 * exp(n * psi1) / n.
         */
        const W fConstant =
            m1 * exp(n * psi1) / n;

        if (!isFiniteGeodesyScalar(fConstant)
            || fConstant * n <= cast(W) 0)
            return false;

        const W phi0 =
            workingLatitudeRadians!T(
                latitudeOfFalseOrigin.radians);

        W rho0;

        if (phi0 == halfPi!W)
        {
            if (n <= cast(W) 0)
                return false;
            rho0 = cast(W) 0;
        }
        else if (phi0 == -halfPi!W)
        {
            if (n >= cast(W) 0)
                return false;
            rho0 = cast(W) 0;
        }
        else
        {
            const W psi0 =
                isometricLatitude(e, phi0);

            if (!isFiniteGeodesyScalar(psi0))
                return false;

            rho0 =
                a * fConstant * exp(-n * psi0);

            if (!isFiniteGeodesyScalar(rho0)
                || rho0 * n <= cast(W) 0)
                return false;
        }

        LambertConformalConic candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._latitudeOfFalseOrigin = latitudeOfFalseOrigin;
        candidate._longitudeOfFalseOrigin =
            longitudeOfFalseOrigin.normalized;
        candidate._firstStandardParallel =
            firstStandardParallel;
        candidate._secondStandardParallel =
            secondStandardParallel;
        candidate._falseEasting = falseEasting;
        candidate._falseNorthing = falseNorthing;
        candidate._apexNorthing =
            cast(T) (cast(W) falseNorthing + rho0);
        candidate._a = a;
        candidate._e2 = e2;
        candidate._e = e;
        candidate._n = n;
        candidate._fConstant = fConstant;
        candidate._rho0 = rho0;

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }

    /// Example preparing Austria Lambert parameters without throwing.
    @safe unittest
    {
        import geodesy;
        LambertConformalConic!double projection;
        assert(LambertConformalConic!double.tryFromTwoStandardParallels(
            Ellipsoid!double.fromInverseFlattening(
                6_377_397.155,
                299.1528128),
            Latitude!double.fromDegrees(47.5),
            Longitude!double.fromDegrees(13.3333333333333),
            Latitude!double.fromDegrees(49.0),
            Latitude!double.fromDegrees(46.0),
            400_000.0,
            400_000.0,
            projection));
    }


    /** Set up a conic map from its two standard parallels and grid parameters.
     *
     * Use this when invalid configuration should raise an exception.
     * Use `tryFromTwoStandardParallels` when you want to check the
     * parameters without throwing.
     */
    static LambertConformalConic fromTwoStandardParallels(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfFalseOrigin,
        const Longitude!T longitudeOfFalseOrigin,
        const Latitude!T firstStandardParallel,
        const Latitude!T secondStandardParallel,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        LambertConformalConic result;

        if (!tryFromTwoStandardParallels(
                ellipsoid,
                latitudeOfFalseOrigin,
                longitudeOfFalseOrigin,
                firstStandardParallel,
                secondStandardParallel,
                falseEasting,
                falseNorthing,
                result))
            throw new GeodesyValueException(
                "Lambert Conformal Conic 2SP requires a supported ellipsoid, "
                ~ "two distinct non-polar standard parallels, finite false "
                ~ "offsets, and a non-singular false origin.");

        return result;
    }

    /// Example preparing the Europe LCC parameter family.
    @safe unittest
    {
        import geodesy;
        const grs80 = Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257222101);
        const projection =
            LambertConformalConic!double.fromTwoStandardParallels(
                grs80,
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                Latitude!double.fromDegrees(35.0),
                Latitude!double.fromDegrees(65.0),
                4_000_000.0,
                2_800_000.0);
        assert(projection.isValid);
    }


    /** Prepared ellipsoid. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /// Example reading the prepared ellipsoid.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.ellipsoid.semiMajorAxis == 6_378_137.0);
    }


    /** Latitude of false origin. */
    @property Latitude!T latitudeOfFalseOrigin() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfFalseOrigin;
    }

    /// Example reading latitude of false origin.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.latitudeOfFalseOrigin.degrees == 40.0);
    }


    /** Longitude of false origin. */
    @property Longitude!T longitudeOfFalseOrigin() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfFalseOrigin;
    }

    /// Example reading longitude of false origin.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(10.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.longitudeOfFalseOrigin.degrees == 10.0);
    }


    /** First standard parallel. */
    @property Latitude!T firstStandardParallel() const
        pure nothrow @safe @nogc
    {
        return _firstStandardParallel;
    }

    /// Example reading first standard parallel.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.firstStandardParallel.degrees == 33.0);
    }


    /** Second standard parallel. */
    @property Latitude!T secondStandardParallel() const
        pure nothrow @safe @nogc
    {
        return _secondStandardParallel;
    }

    /// Example reading second standard parallel.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.secondStandardParallel.degrees == 45.0);
    }


    /** False easting in the ellipsoid linear unit. */
    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _falseEasting;
    }

    /// Example reading false easting.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            500_000.0, 0.0);
        assert(p.falseEasting == 500_000.0);
    }


    /** False northing in the ellipsoid linear unit. */
    @property T falseNorthing() const
        pure nothrow @safe @nogc
    {
        return _falseNorthing;
    }

    /// Example reading false northing.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(0.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 200_000.0);
        assert(p.falseNorthing == 200_000.0);
    }


    /** Project a geographic coordinate without throwing. */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = ProjectedCoordinate!T.init;

        W easting;
        W northing;
        W latitude;
        W deltaLongitude;
        W rho;

        if (!forwardWorking(
                source,
                easting,
                northing,
                latitude,
                deltaLongitude,
                rho))
            return false;

        return ProjectedCoordinate!T.tryFromComponents(
            cast(T) easting,
            cast(T) northing,
            result);
    }

    /// Example projecting a geographic coordinate without throwing.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        ProjectedCoordinate!double projected;
        assert(p.tryForward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(35.0),
                Longitude!double.fromDegrees(-75.0)),
            projected));
    }


    /** Convert latitude and longitude to this conic map's grid coordinates.
     *
     * The result contains easting and northing in the ellipsoid's length
     * unit. Use `tryForward` to handle an unsupported position without an
     * exception.
     */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(source, result))
            throw new GeodesyValueException(
                "Lambert Conformal Conic forward input is outside the "
                ~ "prepared represented domain.");

        return result;
    }

    /// Example projecting a geographic coordinate.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(35.0),
                Longitude!double.fromDegrees(-75.0))).easting > 0.0);
    }


    /** Convert this conic grid's easting and northing to latitude and longitude.
     *
     * Returns `false` when the input cannot be reversed in the supported
     * domain; use `reverse` when an exception is preferred.
     */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = GeographicCoordinate!T.init;

        W latitude;
        W longitude;
        W rho;

        if (!reverseWorking(
                source,
                latitude,
                longitude,
                rho))
            return false;

        Latitude!T publicLatitude;
        Longitude!T publicLongitude;

        if (!Latitude!T.tryFromRadians(
                cast(T) latitude,
                publicLatitude)
            || !Longitude!T.tryFromRadians(
                cast(T) longitude,
                publicLongitude))
            return false;

        result =
            GeographicCoordinate!T.fromComponents(
                publicLatitude,
                publicLongitude);

        return true;
    }

    /// Example reversing a projected coordinate without throwing.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        const source = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(35.0),
            Longitude!double.fromDegrees(-75.0));
        const projected = p.forward(source);
        GeographicCoordinate!double restored;
        assert(p.tryReverse(projected, restored));
    }


    /** Convert grid coordinates back to a geographic position.
     *
     * Use `tryReverse` to handle invalid projected input without throwing.
     */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(source, result))
            throw new GeodesyValueException(
                "Lambert Conformal Conic reverse input is outside the "
                ~ "prepared represented domain.");

        return result;
    }

    /// Example reversing a projected coordinate.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        const source = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(35.0),
            Longitude!double.fromDegrees(-75.0));
        const restored = p.reverse(p.forward(source));
        assert(restored.latitude.degrees > 34.999999);
    }


    /** Compute convergence and point scale without throwing. */
    bool tryForwardFactors(
        const GeographicCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        W easting;
        W northing;
        W latitude;
        W deltaLongitude;
        W rho;

        if (!forwardWorking(
                source,
                easting,
                northing,
                latitude,
                deltaLongitude,
                rho))
            return false;

        if (rho == cast(W) 0)
            return false;

        const W m =
            conformalM(
                _e2,
                latitude);

        if (!isFiniteGeodesyScalar(m)
            || !(m > cast(W) 0))
            return false;

        const W scale =
            _n * rho / (_a * m);

        const W convergence =
            _n * deltaLongitude;

        if (!isFiniteGeodesyScalar(scale)
            || !(scale > cast(W) 0)
            || !isFiniteGeodesyScalar(convergence))
            return false;

        Angle!T angle;
        if (!Angle!T.tryFromRadians(
                canonicalAngleRadians(
                    cast(T) convergence),
                angle))
            return false;

        result =
            ConformalProjectionFactors!T.fromComponents(
                angle,
                cast(T) scale);

        return true;
    }

    /// Example obtaining LCC factors without throwing.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        ConformalProjectionFactors!double factors;
        assert(p.tryForwardFactors(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(33.0),
                Longitude!double.fromDegrees(-90.0)),
            factors));
        assert(factors.pointScale > 0.999999);
    }


    /** Compute convergence and point scale or throw. */
    ConformalProjectionFactors!T forwardFactors(
        const GeographicCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryForwardFactors(source, result))
            throw new GeodesyValueException(
                "Lambert Conformal Conic factor input is outside the "
                ~ "prepared represented domain.");

        return result;
    }

    /// Example obtaining LCC factors.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        assert(p.forwardFactors(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(33.0),
                Longitude!double.fromDegrees(-90.0))).pointScale > 0.999999);
    }


    /** Compute factors at a projected coordinate without throwing. */
    bool tryReverseFactors(
        const ProjectedCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        W latitude;
        W longitude;
        W rho;

        if (!reverseWorking(
                source,
                latitude,
                longitude,
                rho)
            || rho == cast(W) 0)
            return false;

        const W originLongitude =
            workingLongitudeRadians!T(
                _longitudeOfFalseOrigin.radians);

        const W deltaLongitude =
            longitudeDifference(
                longitude,
                originLongitude);

        const W m =
            conformalM(
                _e2,
                latitude);

        if (!isFiniteGeodesyScalar(m)
            || !(m > cast(W) 0))
            return false;

        const W scale =
            _n * rho / (_a * m);

        const W convergence =
            _n * deltaLongitude;

        if (!isFiniteGeodesyScalar(scale)
            || !(scale > cast(W) 0))
            return false;

        Angle!T angle;
        if (!Angle!T.tryFromRadians(
                canonicalAngleRadians(
                    cast(T) convergence),
                angle))
            return false;

        result =
            ConformalProjectionFactors!T.fromComponents(
                angle,
                cast(T) scale);

        return true;
    }

    /// Example obtaining reverse LCC factors without throwing.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(35.0),
            Longitude!double.fromDegrees(-75.0));
        ConformalProjectionFactors!double factors;
        assert(p.tryReverseFactors(p.forward(point), factors));
    }


    /** Compute factors at a projected coordinate or throw. */
    ConformalProjectionFactors!T reverseFactors(
        const ProjectedCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryReverseFactors(source, result))
            throw new GeodesyValueException(
                "Lambert Conformal Conic reverse-factor input is outside "
                ~ "the prepared represented domain.");

        return result;
    }

    /// Example obtaining reverse LCC factors.
    @safe unittest
    {
        import geodesy;
        const p = LambertConformalConic!double.fromTwoStandardParallels(
            wgs84!double(),
            Latitude!double.fromDegrees(40.0),
            Longitude!double.fromDegrees(-96.0),
            Latitude!double.fromDegrees(33.0),
            Latitude!double.fromDegrees(45.0),
            0.0, 0.0);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(35.0),
            Longitude!double.fromDegrees(-75.0));
        assert(p.reverseFactors(p.forward(point)).pointScale > 0.0);
    }
}

/// Example using LambertConformalConic.
@safe unittest
{
    import geodesy;
    const p = LambertConformalConic!double.fromTwoStandardParallels(
        wgs84!double(),
        Latitude!double.fromDegrees(40.0),
        Longitude!double.fromDegrees(-96.0),
        Latitude!double.fromDegrees(33.0),
        Latitude!double.fromDegrees(45.0),
        0.0, 0.0);
    assert(p.isValid);
}


@safe unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    import geodesy;

    static assert(is(LambertConformalConic!float));
    static assert(is(LambertConformalConic!double));
    static assert(is(LambertConformalConic!real));

    assert(!LambertConformalConic!double.init.isValid);

    LambertConformalConic!double invalid;

    assert(!LambertConformalConic!double.tryFromTwoStandardParallels(
        wgs84!double(),
        Latitude!double.fromDegrees(40.0),
        Longitude!double.fromDegrees(0.0),
        Latitude!double.fromDegrees(33.0),
        Latitude!double.fromDegrees(33.0),
        0.0, 0.0,
        invalid));

    assert(!LambertConformalConic!double.tryFromTwoStandardParallels(
        wgs84!double(),
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0),
        Latitude!double.fromDegrees(30.0),
        Latitude!double.fromDegrees(-30.0),
        0.0, 0.0,
        invalid));

    const p = LambertConformalConic!double.fromTwoStandardParallels(
        wgs84!double(),
        Latitude!double.fromDegrees(40.0),
        Longitude!double.fromDegrees(-96.0),
        Latitude!double.fromDegrees(33.0),
        Latitude!double.fromDegrees(45.0),
        0.0, 0.0);

    const source = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(35.0),
        Longitude!double.fromDegrees(-75.0));

    const projected = p.forward(source);
    const restored = p.reverse(projected);

    assert(fabs(restored.latitude.radians - source.latitude.radians) < 2e-12);
    assert(fabs(
        canonicalAngleRadians(
            restored.longitude.radians
                - source.longitude.radians)) < 2e-12);

    const standard = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(33.0),
        Longitude!double.fromDegrees(-90.0));

    assert(fabs(
        p.forwardFactors(standard).pointScale - 1.0) < 2e-12);

    const northPole = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(120.0));

    const apex = p.forward(northPole);
    assert(fabs(apex.easting) < 1e-10);

    const apexBack = p.reverse(apex);
    assert(apexBack.latitude.degrees == 90.0);
    assert(apexBack.longitude.degrees == -96.0);

    const southPole = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-90.0),
        Longitude!double.fromDegrees(0.0));

    ProjectedCoordinate!double rejected;
    assert(!p.tryForward(southPole, rejected));

    assertThrown!GeodesyValueException(
        p.forward(southPole));
}
