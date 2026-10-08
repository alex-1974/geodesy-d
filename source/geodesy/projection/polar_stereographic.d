/**
 * Bounded EPSG 9810 Polar Stereographic projection.
 *
 * Project geographic coordinates around either pole with a prepared
 * stereographic operation. The parameters make the ellipsoid, polar natural
 * origin, central scale, and false offsets explicit.
 *
 * Standards:
 *     Public parameter semantics follow EPSG method 9810 -- Polar
 *     Stereographic (variant A).
 *
 * Domain:
 *     The projection covers the selected geographic hemisphere, including the
 *     equator and selected pole. UPS adds its own latitude and represented-
 *     coordinate policy on top of this mathematical kernel.
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
 *
 * Date:
 *     October 6, 2026
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

import geodesy.angle : Angle, Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.factors : ConformalProjectionFactors;
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

    /*
     * Reverse factors near the selected pole are sensitive to relative error
     * in tau even when the recovered latitude is already angularly excellent.
     * Iterate to near working-scalar precision rather than a sqrt(epsilon)
     * latitude-only stopping threshold.
     */
    const T tolerance =
        cast(T) 8 * T.epsilon;

    /*
     * Near the pole tau' is asymptotically
     * exp(-e*atanh(e)) * tau.  Starting Newton from tau'/e2m there loses
     * significant relative accuracy before the first correction because both
     * tau and tau' are very large.  Use the asymptotic inverse for the polar
     * region, matching the stable strategy used by GeographicLib.
     */
    tau =
        fabs(tauPrime) > cast(T) 70
            ? tauPrime
                * exp(eccentricityTerm(cast(T) 1, eccentricity))
            : tauPrime / e2m;

    if (!isFiniteScalar(tau))
        return false;

    const T tauMax =
        cast(T) 2 / sqrt(T.epsilon);

    if (!(fabs(tau) < tauMax))
        return true;

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
        <= cast(T) 16 * T.epsilon
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


    /** Return radial distance for a selected-hemisphere absolute latitude. */
    bool radialDistance(
        const W latitudeAbs,
        out W rho) const
        pure nothrow @safe @nogc
    {
        rho = W.nan;

        if (latitudeAbs < cast(W) 0
            || latitudeAbs > halfPi!W)
            return false;

        if (latitudeAbs == halfPi!W)
        {
            rho = cast(W) 0;
            return true;
        }

        const W tau = tan(latitudeAbs);
        const W tauPrime =
            conformalTau(tau, _eccentricity);

        const W h =
            hypot2(cast(W) 1, tauPrime);

        rho =
            tauPrime >= cast(W) 0
                ? _radiusFactor / (h + tauPrime)
                : _radiusFactor * (h - tauPrime);

        return isFiniteScalar(rho)
            && rho >= cast(W) 0;
    }


    /** Recover an accepted geographic point in working precision. */
    bool reverseKernel(
        const ProjectedCoordinate!T source,
        out W latitudeRadians,
        out W longitudeRadians,
        out W rho,
        out W tauAbs) const
        pure nothrow @safe @nogc
    {
        latitudeRadians = W.nan;
        longitudeRadians = W.nan;
        rho = W.nan;
        tauAbs = W.nan;

        if (!isValid)
            return false;

        const W dx =
            cast(W) source.easting
            - cast(W) _falseEasting;

        const W dy =
            cast(W) source.northing
            - cast(W) _falseNorthing;

        if (!isFiniteScalar(dx) || !isFiniteScalar(dy))
            return false;

        rho = hypot2(dx, dy);
        const bool north = northAspect;

        if (rho == cast(W) 0)
        {
            latitudeRadians =
                north ? halfPi!W : -halfPi!W;
            longitudeRadians =
                cast(W) _longitudeOfNaturalOrigin.radians;
            tauAbs = W.infinity;
            return true;
        }

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
        {
            /*
             * The equator is the closed outer boundary of the admitted
             * selected-hemisphere domain.  An independently generated
             * ProjectedCoordinate!T can round a mathematical equator point a
             * tiny radial distance outside that boundary.  Classify only the
             * excursion that is indistinguishable at the public scalar's
             * represented E/N precision as the equator itself.
             *
             * The budget scales with the represented linear magnitudes and is
             * therefore invariant under a consistent change of linear unit.
             */
            const W representationScale =
                fabs(cast(W) source.easting)
                + fabs(cast(W) source.northing)
                + fabs(cast(W) _falseEasting)
                + fabs(cast(W) _falseNorthing)
                + _radiusFactor
                + cast(W) _ellipsoid.semiMajorAxis;

            const W equatorSlack =
                cast(W) 4
                * cast(W) T.epsilon
                * (representationScale > cast(W) 1
                    ? representationScale
                    : cast(W) 1);

            if (rho <= _radiusFactor + equatorSlack)
                tau = cast(W) 0;
            else
                return false;
        }

        tauAbs = tau;

        const W latitudeAbs =
            atan(tauAbs);

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

        return isFiniteScalar(latitudeRadians)
            && isFiniteScalar(longitudeRadians);
    }


    /** Build factors from preserved geodetic tau without angle round-tripping. */
    bool factorsAtTau(
        const W longitudeRadians,
        const W rho,
        const W tauAbs,
        const bool atPole,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        const W deltaLongitude =
            longitudeDifference(
                longitudeRadians,
                cast(W) _longitudeOfNaturalOrigin.radians);

        W pointScale;

        if (atPole)
        {
            pointScale =
                cast(W) _scaleFactorAtNaturalOrigin;
        }
        else
        {
            const W secphi =
                hypot2(cast(W) 1, tauAbs);
            const W e2 =
                _eccentricity * _eccentricity;
            const W scaleTerm =
                sqrt(
                    (cast(W) 1 - e2)
                    + e2 / (secphi * secphi));

            pointScale =
                rho
                / cast(W) _ellipsoid.semiMajorAxis
                * secphi
                * scaleTerm;
        }

        if (!isFiniteScalar(pointScale)
            || !(pointScale > cast(W) 0))
            return false;

        const W gamma =
            atPole
                ? cast(W) 0
                : (northAspect
                    ? deltaLongitude
                    : -deltaLongitude);

        Angle!T convergence;
        if (!Angle!T.tryFromRadians(
                cast(T) normalizeRadians(gamma),
                convergence))
            return false;

        result =
            ConformalProjectionFactors!T.fromComponents(
                convergence,
                cast(T) pointScale);

        return result.pointScale > cast(T) 0
            && isFiniteScalar(result.pointScale);
    }


    /** Build conformal factors at an accepted working-precision point. */
    bool factorsAt(
        const W latitudeRadians,
        const W longitudeRadians,
        const W rho,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        const W latitudeAbs =
            fabs(latitudeRadians);
        const bool atPole =
            latitudeAbs == halfPi!W;
        const W tauAbs =
            atPole
                ? W.infinity
                : tan(latitudeAbs);

        return factorsAtTau(
            longitudeRadians,
            rho,
            tauAbs,
            atPole,
            result);
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

    /// Example checking whether a Polar Stereographic projection was prepared.
    @safe unittest
    {
        import geodesy;
        assert(!PolarStereographic!double.init.isValid);
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 0.0);
        assert(projection.isValid);
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

        if (ellipsoid.flattening < cast(T) 0
            || ellipsoid.flattening > cast(T) 0.01)
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

    /// Example checking Polar Stereographic construction without throwing.
    @safe unittest
    {
        import geodesy;
        PolarStereographic!double projection;
        assert(PolarStereographic!double.tryFromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0, projection));
        assert(projection.isValid);
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

    /// Example constructing a north-polar EPSG 9810 projection.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        assert(projection.isValid);
    }


    /**
     * Construct EPSG 9829 Polar Stereographic variant B without throwing.
     *
     * The non-zero standard parallel selects the polar aspect. Its scale is
     * converted to the equivalent EPSG 9810 scale factor at the natural
     * origin; forward/reverse mathematics therefore remain one shared kernel.
     */
    static bool tryFromStandardParallel(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfStandardParallel,
        const Longitude!T longitudeOfOrigin,
        const T falseEasting,
        const T falseNorthing,
        out PolarStereographic result)
        pure nothrow @safe @nogc
    {
        result = PolarStereographic.init;

        if (!ellipsoid.isValid
            || ellipsoid.flattening > cast(T) 0.01
            || !isFiniteScalar(falseEasting)
            || !isFiniteScalar(falseNorthing))
            return false;

        const T publicLatitude =
            latitudeOfStandardParallel.radians;

        if (publicLatitude == cast(T) 0
            || publicLatitude == halfPi!T
            || publicLatitude == -halfPi!T)
            return false;

        const W latitudeAbs =
            fabs(cast(W) publicLatitude);
        const W f =
            cast(W) ellipsoid.flattening;
        const W e2 =
            f * (cast(W) 2 - f);
        const W e =
            sqrt(e2);

        const W sinPhi =
            sin(latitudeAbs);
        const W cosPhi =
            cos(latitudeAbs);

        const W m =
            cosPhi
            / sqrt(
                cast(W) 1
                - e2 * sinPhi * sinPhi);

        const W tau =
            tan(latitudeAbs);
        const W tauPrime =
            conformalTau(tau, e);
        const W t =
            cast(W) 1
            / (hypot2(cast(W) 1, tauPrime) + tauPrime);

        const W cConstant =
            (cast(W) 1 - f)
            * exp(eccentricityTerm(cast(W) 1, e));

        const W k0 =
            m * cConstant
            / (cast(W) 2 * t);

        if (!isFiniteScalar(k0)
            || !(k0 > cast(W) 0))
            return false;

        Latitude!T polarOrigin;
        if (!Latitude!T.tryFromRadians(
                publicLatitude > cast(T) 0
                    ? halfPi!T
                    : -halfPi!T,
                polarOrigin))
            return false;

        return tryFromParameters(
            ellipsoid,
            polarOrigin,
            longitudeOfOrigin,
            cast(T) k0,
            falseEasting,
            falseNorthing,
            result);
    }

    /// Example preparing EPSG 9829 from a southern standard parallel.
    @safe unittest
    {
        import geodesy;
        PolarStereographic!double projection;
        assert(PolarStereographic!double.tryFromStandardParallel(
            wgs84!double(),
            Latitude!double.fromDegrees(-71.0),
            Longitude!double.fromDegrees(70.0),
            6_000_000.0,
            6_000_000.0,
            projection));
        assert(projection.latitudeOfNaturalOrigin.degrees == -90.0);
    }


    /** Construct EPSG 9829 Polar Stereographic variant B or throw. */
    static PolarStereographic fromStandardParallel(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfStandardParallel,
        const Longitude!T longitudeOfOrigin,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        PolarStereographic result;

        if (!tryFromStandardParallel(
                ellipsoid,
                latitudeOfStandardParallel,
                longitudeOfOrigin,
                falseEasting,
                falseNorthing,
                result))
            throw new GeodesyValueException(
                "Polar Stereographic variant B requires a valid "
                ~ "spherical/oblate ellipsoid with f <= 0.01, a finite "
                ~ "non-zero non-polar standard parallel, and finite false "
                ~ "offsets.");

        return result;
    }

    /// Example constructing EPSG 9829 Polar Stereographic variant B.
    @safe unittest
    {
        import geodesy;
        const projection =
            PolarStereographic!double.fromStandardParallel(
                wgs84!double(),
                Latitude!double.fromDegrees(-71.0),
                Longitude!double.fromDegrees(70.0),
                6_000_000.0,
                6_000_000.0);
        assert(projection.scaleFactorAtNaturalOrigin > 0.97);
    }


    /** Reference ellipsoid used by this prepared projection. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /// Example reading the prepared reference ellipsoid.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 0.0);
        assert(projection.ellipsoid.semiMajorAxis == 6_378_137.0);
    }


    /** Polar latitude of natural origin selecting the north or south aspect. */
    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfNaturalOrigin;
    }

    /// Example reading the selected polar natural origin.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(-90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 0.0);
        assert(projection.latitudeOfNaturalOrigin.degrees == -90.0);
    }


    /** Longitude of natural origin defining the projection meridian. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfNaturalOrigin;
    }

    /// Example reading the longitude of natural origin.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(30.0), 0.994, 0.0, 0.0);
        assert(projection.longitudeOfNaturalOrigin.degrees == 30.0);
    }


    /** Dimensionless scale factor at the selected natural origin pole. */
    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _scaleFactorAtNaturalOrigin;
    }

    /// Example reading the natural-origin scale factor.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 0.0);
        assert(projection.scaleFactorAtNaturalOrigin == 0.994);
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
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 2_000_000.0, 0.0);
        assert(projection.falseEasting == 2_000_000.0);
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
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 2_000_000.0);
        assert(projection.falseNorthing == 2_000_000.0);
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

        const bool atSelectedPole =
            publicLatitude
                == (north ? halfPi!T : -halfPi!T);

        const W phi =
            atSelectedPole
                ? halfPi!W
                : (north
                    ? cast(W) publicLatitude
                    : -cast(W) publicLatitude);

        W rho;
        if (!radialDistance(phi, rho))
            return false;

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

    /// Example checking a Polar Stereographic forward projection.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        ProjectedCoordinate!double result;
        assert(projection.tryForward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(73.0),
                Longitude!double.fromDegrees(44.0)), result));
        assert(result.easting > 3_000_000.0);
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

    /// Example projecting a geographic point with the throwing convenience API.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        const result = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(73.0),
                Longitude!double.fromDegrees(44.0)));
        assert(result.northing < 2_000_000.0);
    }


    /** Compute convergence and point scale for a geographic point without throwing. */
    bool tryForwardFactors(
        const GeographicCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        if (!isValid)
            return false;

        const bool north = northAspect;
        const T publicLatitude =
            source.latitude.radians;

        if ((north && publicLatitude < cast(T) 0)
            || (!north && publicLatitude > cast(T) 0))
            return false;

        const bool atSelectedPole =
            publicLatitude
                == (north ? halfPi!T : -halfPi!T);

        const W latitudeAbs =
            atSelectedPole
                ? halfPi!W
                : fabs(cast(W) publicLatitude);

        W rho;
        if (!radialDistance(latitudeAbs, rho))
            return false;

        const W factorLatitude =
            atSelectedPole
                ? (north ? halfPi!W : -halfPi!W)
                : cast(W) publicLatitude;

        return factorsAt(
            factorLatitude,
            cast(W) source.longitude.normalized.radians,
            rho,
            result);
    }

    /// Example checking Polar Stereographic convergence and scale.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        ConformalProjectionFactors!double factors;
        assert(projection.tryForwardFactors(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(73.0),
                Longitude!double.fromDegrees(44.0)),
            factors));
        assert(factors.pointScale > 0.994);
    }


    /** Compute convergence and point scale for a geographic point or throw. */
    ConformalProjectionFactors!T forwardFactors(
        const GeographicCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryForwardFactors(source, result))
            throw new GeodesyValueException(
                "Polar Stereographic factor input is outside the "
                ~ "prepared projection domain.");

        return result;
    }

    /// Example obtaining Polar Stereographic factors.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994, 0.0, 0.0);
        const factors = projection.forwardFactors(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(80.0),
                Longitude!double.fromDegrees(20.0)));
        assert(factors.meridianConvergence.degrees > 19.9);
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

        W latitudeRadians;
        W longitudeRadians;
        W rho;
        W tauAbs;

        if (!reverseKernel(
                source,
                latitudeRadians,
                longitudeRadians,
                rho,
                tauAbs))
            return false;

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

    /// Example checking a Polar Stereographic reverse projection.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        GeographicCoordinate!double result;
        assert(projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(
                3_320_416.74736, 632_668.43127), result));
        assert(result.latitude.degrees > 72.9);
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

    /// Example reversing a projected point with the throwing convenience API.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        const result = projection.reverse(
            ProjectedCoordinate!double.fromComponents(
                3_320_416.74736, 632_668.43127));
        assert(result.longitude.degrees > 43.9);
    }


    /** Compute factors at a projected point without throwing. */
    bool tryReverseFactors(
        const ProjectedCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        W latitudeRadians;
        W longitudeRadians;
        W rho;
        W tauAbs;

        if (!reverseKernel(
                source,
                latitudeRadians,
                longitudeRadians,
                rho,
                tauAbs))
            return false;

        return factorsAtTau(
            longitudeRadians,
            rho,
            tauAbs,
            rho == cast(W) 0,
            result);
    }

    /// Example checking factors from a projected Polar Stereographic point.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        ConformalProjectionFactors!double factors;
        assert(projection.tryReverseFactors(
            ProjectedCoordinate!double.fromComponents(
                3_320_416.74736, 632_668.43127),
            factors));
        assert(factors.pointScale > 0.994);
    }


    /** Compute factors at a projected point or throw. */
    ConformalProjectionFactors!T reverseFactors(
        const ProjectedCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryReverseFactors(source, result))
            throw new GeodesyValueException(
                "Polar Stereographic reverse-factor input is outside the "
                ~ "prepared projection domain.");

        return result;
    }

    /// Example obtaining factors from a projected Polar Stereographic point.
    @safe unittest
    {
        import geodesy;
        const projection = PolarStereographic!double.fromParameters(
            wgs84!double(), Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(0.0), 0.994,
            2_000_000.0, 2_000_000.0);
        const factors = projection.reverseFactors(
            ProjectedCoordinate!double.fromComponents(
                3_320_416.74736, 632_668.43127));
        assert(factors.meridianConvergence.degrees > 43.9);
    }
}

/// Example preparing and using a bounded Polar Stereographic projection.
@safe unittest
{
    import geodesy;
    const projection = PolarStereographic!double.fromParameters(
        wgs84!double(), Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0), 0.994,
        2_000_000.0, 2_000_000.0);
    const projected = projection.forward(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(73.0),
            Longitude!double.fromDegrees(44.0)));
    assert(projected.easting > 3_000_000.0);
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

    const southVariantB =
        PolarStereographic!double.fromStandardParallel(
            wgs84!double(),
            Latitude!double.fromDegrees(-71.0),
            Longitude!double.fromDegrees(70.0),
            6_000_000.0,
            6_000_000.0);

    assert(fabs(
        southVariantB.scaleFactorAtNaturalOrigin
            - 0.9727690128917972) < 1e-14);

    const southVariantBProjected =
        southVariantB.forward(southPoint);

    assert(fabs(
        southVariantBProjected.easting
            - 7_255_380.793258) < 0.001);
    assert(fabs(
        southVariantBProjected.northing
            - 7_053_389.560610) < 0.001);

    const northFactors =
        north.forwardFactors(epsgPoint);
    const northReverseFactors =
        north.reverseFactors(projected);

    assert(fabs(
        northFactors.meridianConvergence.degrees
            - 44.0) < 1e-12);
    assert(fabs(
        northReverseFactors.meridianConvergence.degrees
            - 44.0) < 1e-10);
    assert(fabs(
        northFactors.pointScale
            - northReverseFactors.pointScale) < 1e-12);
    assert(northFactors.pointScale > 0.994);

    const poleFactors =
        north.forwardFactors(pole);
    const poleReverseFactors =
        north.reverseFactors(projectedPole);

    assert(poleFactors.meridianConvergence.degrees == 0.0);
    assert(poleReverseFactors.meridianConvergence.degrees == 0.0);
    assert(poleFactors.pointScale == 0.994);
    assert(poleReverseFactors.pointScale == 0.994);

    const southFactors =
        southVariantB.forwardFactors(southPoint);
    assert(fabs(
        southFactors.meridianConvergence.degrees
            + 50.0) < 1e-12);
    assert(southFactors.pointScale > 0.0);

    assert(!PolarStereographic!double.tryFromStandardParallel(
        wgs84!double(),
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0),
        0.0,
        0.0,
        candidate));

    assertThrown!GeodesyValueException(
        north.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(-1.0),
                Longitude!double.fromDegrees(0.0))));
}
