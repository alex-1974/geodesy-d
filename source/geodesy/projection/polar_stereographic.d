/**
 * Bounded EPSG 9810 Polar Stereographic projection.
 *
 * This module provides a prepared north- or south-polar stereographic
 * projection with explicit ellipsoid, polar natural origin, central scale,
 * and false offsets.
 *
 * Standards:
 *     Public parameter semantics follow EPSG method 9810 -- Polar
 *     Stereographic (variant A).
 *
 * Domain:
 *     The initial geodesy-d contract covers the selected geographic
 *     hemisphere including the equator and selected pole. UPS-specific
 *     latitude and coordinate-range policy is deliberately not part of this
 *     mathematical kernel.
 *
 * Units:
 *     False easting, false northing, projected coordinates, and ellipsoid axes
 *     use the same caller-selected linear unit. Scale is dimensionless.
 *
 * Numerics:
 *     Uses a stable conformal-latitude tau/tau-prime formulation equivalent
 *     to EPSG 9810. Public float uses double working precision.
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 */
module geodesy.projection.polar_stereographic;

import std.math :
    PI,
    atan,
    atan2,
    atanh,
    cos,
    exp,
    fabs,
    sin,
    sinh,
    sqrt,
    tan;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.scalar : isGeodesyScalar;


/** Working precision used by the Polar Stereographic kernel. */
private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


/** Return whether a scalar is neither NaN nor infinity. */
private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
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


/** Stable two-dimensional norm. */
private T hypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T hi = ax >= ay ? ax : ay;
    const T lo = ax >= ay ? ay : ax;

    if (hi == cast(T) 0)
        return cast(T) 0;

    const T ratio = lo / hi;
    return hi * sqrt(cast(T) 1 + ratio * ratio);
}


/** Normalize a finite angle to [-pi,+pi). */
private T normalizeRadians(T)(const T radians)
    pure nothrow @safe @nogc
{
    const T p = pi!T;
    const T twoP = cast(T) 2 * p;
    T result = radians;

    while (result >= p)
        result -= twoP;
    while (result < -p)
        result += twoP;

    return result == cast(T) 0
        ? cast(T) 0
        : result;
}


/** Compute an error-free floating-point sum decomposition. */
private void twoSum(T)(
    const T a,
    const T b,
    out T sum,
    out T residual)
    pure nothrow @safe @nogc
{
    sum = a + b;
    const T z = sum - a;
    residual = (a - (sum - z)) + (b - z);
}


/** Compensated longitude difference on the principal sheet. */
private T longitudeDifference(T)(
    const T longitude,
    const T longitude0)
    pure nothrow @safe @nogc
{
    T sum;
    T residual;
    twoSum(longitude, -longitude0, sum, residual);

    const T p = pi!T;
    const T twoP = cast(T) 2 * p;

    if (sum > p || (sum == p && residual >= cast(T) 0))
        sum -= twoP;
    else if (sum < -p || (sum == -p && residual < cast(T) 0))
        sum += twoP;

    return normalizeRadians(sum + residual);
}


/** Compensated longitude addition followed by canonicalization. */
private T addLongitude(T)(
    const T longitude0,
    const T delta)
    pure nothrow @safe @nogc
{
    T sum;
    T residual;
    twoSum(longitude0, delta, sum, residual);
    return normalizeRadians(sum + residual);
}


/** Conformal-latitude eccentricity term. */
private T eccentricityTerm(T)(
    const T x,
    const T eccentricity)
    pure nothrow @safe @nogc
{
    if (eccentricity == cast(T) 0)
        return cast(T) 0;

    return eccentricity * atanh(eccentricity * x);
}


/** Convert geodetic tau=tan(phi) to conformal tau-prime. */
private T conformalTau(T)(
    const T tau,
    const T eccentricity)
    pure nothrow @safe @nogc
{
    if (!isFiniteScalar(tau))
        return tau;

    const T secphi = hypot2(cast(T) 1, tau);
    const T sigma =
        sinh(eccentricityTerm(tau / secphi, eccentricity));

    return hypot2(cast(T) 1, sigma) * tau
        - sigma * secphi;
}


/** Recover geodetic tau from conformal tau-prime. */
private bool geodeticTau(T)(
    const T tauPrime,
    const T eccentricity,
    out T tau)
    pure nothrow @safe @nogc
{
    enum int maxIterations = 5;

    const T e2m =
        cast(T) 1 - eccentricity * eccentricity;

    if (!(e2m > cast(T) 0))
        return false;

    const T tolerance =
        sqrt(T.epsilon) / cast(T) 10;

    tau = tauPrime / e2m;

    if (!isFiniteScalar(tau))
        return false;

    foreach (_; 0 .. maxIterations)
    {
        const T tauPrimeApprox =
            conformalTau(tau, eccentricity);

        const T denominator =
            e2m
            * hypot2(cast(T) 1, tau)
            * hypot2(cast(T) 1, tauPrimeApprox);

        if (!(denominator > cast(T) 0)
            || !isFiniteScalar(denominator))
            return false;

        const T deltaTau =
            (tauPrime - tauPrimeApprox)
            * (cast(T) 1 + e2m * tau * tau)
            / denominator;

        if (!isFiniteScalar(deltaTau))
            return false;

        tau += deltaTau;

        if (!isFiniteScalar(tau))
            return false;

        const T scale =
            fabs(tauPrime) > cast(T) 1
                ? fabs(tauPrime)
                : cast(T) 1;

        if (fabs(deltaTau) < tolerance * scale)
            return true;
    }

    return fabs(
        tauPrime - conformalTau(tau, eccentricity))
        < sqrt(T.epsilon)
            * (fabs(tauPrime) > cast(T) 1
                ? fabs(tauPrime)
                : cast(T) 1);
}


/**
 * Prepared bounded EPSG 9810 Polar Stereographic projection.
 *
 * The latitude of natural origin must be exactly +90 or -90 degrees and
 * selects the north or south aspect. The admitted ellipsoid domain is
 * spherical/oblate with 0 <= flattening <= 0.01.
 *
 * `.init` is intentionally invalid.
 */
struct PolarStereographic(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    Latitude!T _latitudeOfNaturalOrigin;
    Longitude!T _longitudeOfNaturalOrigin;
    T _scaleFactorAtNaturalOrigin = T.nan;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;

    W _eccentricity = W.nan;
    W _radiusFactor = W.nan;

    @property bool northAspect() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfNaturalOrigin.radians > cast(T) 0;
    }

public:
    /** Return whether this prepared projection is valid. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && (_latitudeOfNaturalOrigin.radians == halfPi!T
                || _latitudeOfNaturalOrigin.radians == -halfPi!T)
            && isFiniteScalar(_scaleFactorAtNaturalOrigin)
            && _scaleFactorAtNaturalOrigin > cast(T) 0
            && isFiniteScalar(_falseEasting)
            && isFiniteScalar(_falseNorthing)
            && isFiniteScalar(_radiusFactor)
            && _radiusFactor > cast(W) 0;
    }


    /**
     * Construct a bounded EPSG 9810 projection without throwing.
     */
    static bool tryFromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfNaturalOrigin,
        const Longitude!T longitudeOfNaturalOrigin,
        const T scaleFactorAtNaturalOrigin,
        const T falseEasting,
        const T falseNorthing,
        out PolarStereographic result)
        pure nothrow @safe @nogc
    {
        result = PolarStereographic.init;

        if (!ellipsoid.isValid)
            return false;

        if (ellipsoid.flattening > cast(T) 0.01)
            return false;

        if (latitudeOfNaturalOrigin.radians != halfPi!T
            && latitudeOfNaturalOrigin.radians != -halfPi!T)
            return false;

        if (!isFiniteScalar(scaleFactorAtNaturalOrigin)
            || !(scaleFactorAtNaturalOrigin > cast(T) 0))
            return false;

        if (!isFiniteScalar(falseEasting)
            || !isFiniteScalar(falseNorthing))
            return false;

        const W f = cast(W) ellipsoid.flattening;
        const W e2 = f * (cast(W) 2 - f);
        const W e = sqrt(e2);

        const W c =
            (cast(W) 1 - f)
            * exp(eccentricityTerm(cast(W) 1, e));

        const W radiusFactor =
            cast(W) 2
            * cast(W) scaleFactorAtNaturalOrigin
            * cast(W) ellipsoid.semiMajorAxis
            / c;

        if (!isFiniteScalar(radiusFactor)
            || !(radiusFactor > cast(W) 0))
            return false;

        result._ellipsoid = ellipsoid;
        result._latitudeOfNaturalOrigin = latitudeOfNaturalOrigin;
        result._longitudeOfNaturalOrigin = longitudeOfNaturalOrigin.normalized;
        result._scaleFactorAtNaturalOrigin = scaleFactorAtNaturalOrigin;
        result._falseEasting = falseEasting;
        result._falseNorthing = falseNorthing;
        result._eccentricity = e;
        result._radiusFactor = radiusFactor;

        return true;
    }


    /** Construct a bounded EPSG 9810 projection or throw. */
    static PolarStereographic fromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfNaturalOrigin,
        const Longitude!T longitudeOfNaturalOrigin,
        const T scaleFactorAtNaturalOrigin,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        PolarStereographic result;

        if (!tryFromParameters(
                ellipsoid,
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                scaleFactorAtNaturalOrigin,
                falseEasting,
                falseNorthing,
                result))
            throw new GeodesyValueException(
                "Polar Stereographic requires a valid spherical/oblate "
                ~ "ellipsoid with f <= 0.01, polar natural origin, "
                ~ "finite positive scale, and finite false offsets.");

        return result;
    }


    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }


    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfNaturalOrigin;
    }


    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfNaturalOrigin;
    }


    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _scaleFactorAtNaturalOrigin;
    }


    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _falseEasting;
    }


    @property T falseNorthing() const
        pure nothrow @safe @nogc
    {
        return _falseNorthing;
    }


    /** Project a geographic coordinate without throwing. */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = ProjectedCoordinate!T.init;

        if (!isValid)
            return false;

        const bool north = northAspect;
        const T publicLatitude = source.latitude.radians;

        if ((north && publicLatitude < cast(T) 0)
            || (!north && publicLatitude > cast(T) 0))
            return false;

        alias W = WorkingScalar!T;

        const W phi =
            north
                ? cast(W) publicLatitude
                : -cast(W) publicLatitude;

        W rho;

        if (phi == halfPi!W)
        {
            rho = cast(W) 0;
        }
        else
        {
            const W tau = tan(phi);
            const W tauPrime =
                conformalTau(tau, _eccentricity);

            const W h =
                hypot2(cast(W) 1, tauPrime);

            rho =
                tauPrime >= cast(W) 0
                    ? _radiusFactor / (h + tauPrime)
                    : _radiusFactor * (h - tauPrime);
        }

        const W deltaLongitude =
            longitudeDifference(
                cast(W) source.longitude.normalized.radians,
                cast(W) _longitudeOfNaturalOrigin.radians);

        const W x =
            cast(W) _falseEasting
            + rho * sin(deltaLongitude);

        const W y =
            cast(W) _falseNorthing
            + (north
                ? -rho * cos(deltaLongitude)
                : rho * cos(deltaLongitude));

        if (!isFiniteScalar(x) || !isFiniteScalar(y))
            return false;

        return ProjectedCoordinate!T.tryFromComponents(
            cast(T) x,
            cast(T) y,
            result);
    }


    /** Project a geographic coordinate or throw. */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(source, result))
            throw new GeodesyValueException(
                "Polar Stereographic forward input is outside the "
                ~ "prepared projection domain.");

        return result;
    }


    /** Reverse a projected coordinate without throwing. */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = GeographicCoordinate!T.init;

        if (!isValid)
            return false;

        alias W = WorkingScalar!T;

        const W dx =
            cast(W) source.easting
            - cast(W) _falseEasting;

        const W dy =
            cast(W) source.northing
            - cast(W) _falseNorthing;

        if (!isFiniteScalar(dx) || !isFiniteScalar(dy))
            return false;

        const W rho = hypot2(dx, dy);
        const bool north = northAspect;

        W latitudeRadians;
        W longitudeRadians;

        if (rho == cast(W) 0)
        {
            latitudeRadians =
                north ? halfPi!W : -halfPi!W;

            longitudeRadians =
                cast(W) _longitudeOfNaturalOrigin.radians;
        }
        else
        {
            const W t =
                rho / _radiusFactor;

            if (!(t > cast(W) 0)
                || !isFiniteScalar(t))
                return false;

            const W tauPrime =
                (cast(W) 1 / t - t)
                / cast(W) 2;

            W tau;
            if (!geodeticTau(
                    tauPrime,
                    _eccentricity,
                    tau))
                return false;

            if (tau < cast(W) 0)
                return false;

            const W latitudeAbs =
                atan(tau);

            latitudeRadians =
                north ? latitudeAbs : -latitudeAbs;

            const W deltaLongitude =
                atan2(
                    dx,
                    north ? -dy : dy);

            longitudeRadians =
                addLongitude(
                    cast(W) _longitudeOfNaturalOrigin.radians,
                    deltaLongitude);
        }

        Latitude!T latitude;
        Longitude!T longitude;

        if (!Latitude!T.tryFromRadians(
                cast(T) latitudeRadians,
                latitude))
            return false;

        if (!Longitude!T.tryFromRadians(
                cast(T) normalizeRadians(longitudeRadians),
                longitude))
            return false;

        result =
            GeographicCoordinate!T.fromComponents(
                latitude,
                longitude);

        return true;
    }


    /** Reverse a projected coordinate or throw. */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(source, result))
            throw new GeodesyValueException(
                "Polar Stereographic reverse input is outside the "
                ~ "prepared projection domain.");

        return result;
    }
}


@safe unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    import geodesy;

    static assert(is(PolarStereographic!float));
    static assert(is(PolarStereographic!double));
    static assert(is(PolarStereographic!real));

    assert(!PolarStereographic!double.init.isValid);

    PolarStereographic!double candidate;

    assert(!PolarStereographic!double.tryFromParameters(
        wgs84!double(),
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0),
        0.994,
        2_000_000.0,
        2_000_000.0,
        candidate));

    assert(!PolarStereographic!double.tryFromParameters(
        wgs84!double(),
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0),
        0.0,
        2_000_000.0,
        2_000_000.0,
        candidate));

    const north =
        PolarStereographic!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0),
            0.994,
            2_000_000.0,
            2_000_000.0);

    assert(north.isValid);
    assert(north.scaleFactorAtNaturalOrigin == 0.994);

    const epsgPoint =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(73.0),
            Longitude!double.fromDegrees(44.0));

    const projected =
        north.forward(epsgPoint);

    assert(fabs(projected.easting - 3_320_416.75) < 0.01);
    assert(fabs(projected.northing - 632_668.43) < 0.01);

    const roundTrip =
        north.reverse(projected);

    assert(fabs(roundTrip.latitude.degrees - 73.0) < 1e-10);
    assert(fabs(roundTrip.longitude.degrees - 44.0) < 1e-10);

    const pole =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(123.0));

    const projectedPole =
        north.forward(pole);

    assert(projectedPole.easting == 2_000_000.0);
    assert(projectedPole.northing == 2_000_000.0);

    const reversePole =
        north.reverse(projectedPole);

    assert(reversePole.latitude.degrees == 90.0);
    assert(reversePole.longitude.degrees == 0.0);

    const south =
        PolarStereographic!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(-90.0),
            Longitude!double.fromDegrees(70.0),
            0.9727690128917972,
            6_000_000.0,
            6_000_000.0);

    const southPoint =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-75.0),
            Longitude!double.fromDegrees(120.0));

    const southProjected =
        south.forward(southPoint);

    assert(fabs(southProjected.easting - 7_255_380.79) < 0.01);
    assert(fabs(southProjected.northing - 7_053_389.56) < 0.01);

    assertThrown!GeodesyValueException(
        north.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(-1.0),
                Longitude!double.fromDegrees(0.0))));
}
