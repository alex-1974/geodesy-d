/**
 * Ellipsoidal rhumb-line (loxodrome) direct/inverse solver and prepared line.
 *
 * A rhumb line follows constant bearing.  The family is intentionally
 * distinct from geodesics and is formulated from isometric latitude,
 * meridian distance, and their stable divided difference.
 *
 * Domain:
 *     Spherical and oblate ellipsoids with 0 <= f <= 0.01.
 *
 * Units:
 *     Distances use the same linear unit as the ellipsoid semi-major axis.
 *     Angles are represented by the existing geodesy angle value types.
 *
 * Numerics:
 *     Public float uses double working precision. Double and real retain their
 *     own precision. The hot paths are allocation-free, pure, nothrow,
 *     @safe, and @nogc.
 *
 * Pole policy:
 *     Inverse operations admit poles with limiting meridional semantics.
 *     Nonzero direct/line operations starting at, reaching, or crossing a
 *     pole are rejected because longitude is indeterminate there.
 *
 * See_Also:
 *     Geodesic, GeographicCoordinate, Ellipsoid
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
module geodesy.rhumb;

import std.math :
    PI,
    asinh,
    atanh,
    atan2,
    cos,
    fabs,
    sin,
    sqrt;

import geodesy.angle : Angle, Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


/** Working precision policy shared with the numerical families. */
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
    return value == cast(T) 0
        ? cast(T) 0
        : value;
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


/**
 * Shortest signed longitude difference with east-going opposite-meridian tie.
 */
private T shortestLongitudeDifference(T)(
    const T longitude1,
    const T longitude2)
    pure nothrow @safe @nogc
{
    T result =
        canonicalAngleRadians(longitude2 - longitude1);

    if (result == -pi!T)
        result = pi!T;

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


/** Canonicalize public angle in T before widening. */
private WorkingScalar!T workingCanonicalAngleRadians(T)(
    const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = WorkingScalar!T;

    const T canonical =
        canonicalAngleRadians(radians);

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


/** Stable two-argument hypotenuse without relying on std.math.hypot ABI. */
private T stableHypot2(T)(const T x, const T y)
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


/** Sine/cosine with exact public cardinal semantics. */
private void sinCosLatitude(T)(
    const T latitude,
    out T sine,
    out T cosine)
    pure nothrow @safe @nogc
{
    const T hp = halfPi!T;

    if (latitude == cast(T) 0)
    {
        sine = cast(T) 0;
        cosine = cast(T) 1;
        return;
    }

    if (latitude == hp)
    {
        sine = cast(T) 1;
        cosine = cast(T) 0;
        return;
    }

    if (latitude == -hp)
    {
        sine = cast(T) -1;
        cosine = cast(T) 0;
        return;
    }

    sine = sin(latitude);
    cosine = cos(latitude);
}


/** Meridian distance from the equator using a fixed e² power expansion. */
private T meridianDistance(T)(
    const T a,
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    T integral = latitude;
    T sum = integral;

    T coefficient = cast(T) 1;
    T ePower = cast(T) 1;
    T oddSinPower = sine;

    enum int order = 12;

    static foreach (k; 1 .. order + 1)
    {{
        enum T numerator = cast(T) (2 * k + 1);
        enum T denominator = cast(T) (2 * k);

        integral =
            cast(T) (2 * k - 1)
                / denominator
                * integral
            - oddSinPower
                * cosine
                / denominator;

        coefficient *= numerator / denominator;
        ePower *= e2;

        sum += coefficient * ePower * integral;
        oddSinPower *= sine * sine;
    }}

    return a * (cast(T) 1 - e2) * sum;
}


/** Exact derivative dM/dphi. */
private T meridionalRadius(T)(
    const T a,
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    const T denominator =
        cast(T) 1 - e2 * sine * sine;

    return a * (cast(T) 1 - e2)
        / (denominator * sqrt(denominator));
}


/** Continuous east-west limit dM/dpsi = N cos(phi). */
private T localEastWestRadius(T)(
    const T a,
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    return a * cosine
        / sqrt(cast(T) 1 - e2 * sine * sine);
}


/** Isometric latitude for a non-polar geodetic latitude. */
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

    if (eccentricity == cast(T) 0)
        return asinh(tangent);

    return asinh(tangent)
        - eccentricity
            * atanh(eccentricity * sine);
}


/**
 * Stable divided difference dM/dpsi. Inputs are ordinary non-polar latitudes.
 */
private T meridianPerIsometric(T)(
    const T a,
    const T e2,
    const T eccentricity,
    const T latitude1,
    const T latitude2,
    const T meridian1,
    const T meridian2,
    const T psi1,
    const T psi2)
    pure nothrow @safe @nogc
{
    const T dpsi = psi2 - psi1;
    const T scale =
        cast(T) 1
        + (fabs(psi1) > fabs(psi2)
            ? fabs(psi1)
            : fabs(psi2));

    const T threshold =
        cast(T) 16 * sqrt(T.epsilon) * scale;

    if (fabs(dpsi) <= threshold)
    {
        const T midpoint =
            (latitude1 + latitude2) / cast(T) 2;

        return localEastWestRadius(
            a,
            e2,
            midpoint);
    }

    return (meridian2 - meridian1) / dpsi;
}


/** Invert meridian distance on the open geographic latitude interval. */
private bool inverseMeridianDistance(T)(
    const T a,
    const T e2,
    const T rectifyingRadius,
    const T poleDistance,
    const T target,
    out T latitude)
    pure nothrow @safe @nogc
{
    latitude = T.nan;

    if (!isFiniteGeodesyScalar(target)
        || fabs(target) >= poleDistance)
        return false;

    T phi = target / rectifyingRadius;

    const T hp = halfPi!T;
    if (phi >= hp)
        phi = hp - sqrt(T.epsilon);
    else if (phi <= -hp)
        phi = -hp + sqrt(T.epsilon);

    foreach (_; 0 .. 12)
    {
        const T value =
            meridianDistance(a, e2, phi);
        const T derivative =
            meridionalRadius(a, e2, phi);

        if (!isFiniteGeodesyScalar(value)
            || !isFiniteGeodesyScalar(derivative)
            || !(derivative > cast(T) 0))
            return false;

        const T correction =
            (value - target) / derivative;

        phi -= correction;

        if (fabs(correction)
            <= cast(T) 8 * T.epsilon
                * (cast(T) 1 + fabs(phi)))
        {
            latitude = phi;
            return isFiniteGeodesyScalar(latitude)
                && latitude > -hp
                && latitude < hp;
        }
    }

    const T residual =
        meridianDistance(a, e2, phi) - target;

    if (fabs(residual)
        > cast(T) 64 * T.epsilon
            * (cast(T) 1 + fabs(target)))
        return false;

    latitude = phi;
    return latitude > -hp && latitude < hp;
}


/** Build a geographic coordinate from finite canonical radians. */
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
            latitudeRadians,
            latitude)
        || !Longitude!T.tryFromRadians(
            canonicalAngleRadians(longitudeRadians),
            longitude))
        return false;

    result =
        GeographicCoordinate!T.fromComponents(
            latitude,
            longitude);

    return true;
}


/** Result of a direct rhumb operation. */
struct RhumbDirectResult(T)
if (isGeodesyScalar!T)
{
private:
    GeographicCoordinate!T _position;

    /** Construct an internal direct result from an accepted endpoint. */
    static RhumbDirectResult fromPosition(
        const GeographicCoordinate!T position)
        pure nothrow @safe @nogc
    {
        RhumbDirectResult result;
        result._position = position;
        return result;
    }

public:
    /** Endpoint of the direct rhumb operation. */
    @property GeographicCoordinate!T position() const
        pure nothrow @safe @nogc
    {
        return _position;
    }

    /// Example reading a rhumb direct endpoint.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const result = solver.direct(
            start,
            Angle!double.fromDegrees(90.0),
            1_000.0);
        assert(result.position.longitude.degrees > 16.37208);
    }
}

/// Example using a RhumbDirectResult.
@safe unittest
{
    import geodesy;
    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    const result = solver.direct(
        start,
        Angle!double.fromDegrees(90.0),
        1_000.0);
    assert(result.position.longitude.degrees > 16.37208);
}


/** Result of a shortest inverse rhumb operation. */
struct RhumbInverseResult(T)
if (isGeodesyScalar!T)
{
private:
    T _distance = 0;
    Angle!T _bearing;

    /** Construct an internal inverse result from accepted public values. */
    static RhumbInverseResult fromComponents(
        const T distance,
        const Angle!T bearing)
        pure nothrow @safe @nogc
    {
        RhumbInverseResult result;
        result._distance = distance;
        result._bearing = bearing;
        return result;
    }

public:
    /** Shortest rhumb distance in the ellipsoid semi-major-axis unit. */
    @property T distance() const
        pure nothrow @safe @nogc
    {
        return _distance;
    }

    /// Example reading inverse rhumb distance.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const end = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(47.07071),
            Longitude!double.fromDegrees(15.43950));
        assert(solver.inverse(start, end).distance > 0.0);
    }

    /** Constant rhumb bearing in the canonical half-open interval from -pi inclusive to +pi exclusive. */
    @property Angle!T bearing() const
        pure nothrow @safe @nogc
    {
        return _bearing;
    }

    /// Example reading inverse rhumb bearing.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));
        const end = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(10.0));
        assert(solver.inverse(start, end).bearing.degrees == 90.0);
    }
}

/// Example using a RhumbInverseResult.
@safe unittest
{
    import geodesy;
    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    const end = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(47.07071),
        Longitude!double.fromDegrees(15.43950));
    const result = solver.inverse(start, end);
    assert(result.distance > 0.0);
}


/**
 * Prepared ellipsoidal rhumb solver.
 *
 * The solver is immutable after construction and may be reused across direct,
 * inverse, and line-preparation operations. `.init` is invalid.
 */
struct Rhumb(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    W _a = W.nan;
    W _f = W.nan;
    W _e2 = W.nan;
    W _e = W.nan;
    W _poleDistance = W.nan;
    W _rectifyingRadius = W.nan;

    /** Evaluate a direct position from already prepared start/bearing state. */
    bool tryDirectPrepared(
        const W latitude1,
        const W longitude1,
        const W meridian1,
        const W psi1,
        const W sinBearing,
        const W cosBearing,
        const W distance,
        out RhumbDirectResult!T result) const
        pure nothrow @safe @nogc
    {
        result = RhumbDirectResult!T.init;

        if (!isValid
            || !isFiniteGeodesyScalar(distance))
            return false;

        if (distance == cast(W) 0)
        {
            GeographicCoordinate!T endpoint;
            if (!makeGeographicCoordinate(
                    cast(T) latitude1,
                    cast(T) longitude1,
                    endpoint))
                return false;

            result =
                RhumbDirectResult!T.fromPosition(
                    endpoint);
            return true;
        }

        const W hp = halfPi!W;

        if (latitude1 == hp || latitude1 == -hp)
            return false;

        const W deltaMeridian =
            distance * cosBearing;

        const W targetMeridian =
            meridian1 + deltaMeridian;

        W latitude2;
        if (!inverseMeridianDistance(
                _a,
                _e2,
                _rectifyingRadius,
                _poleDistance,
                targetMeridian,
                latitude2))
            return false;

        const W meridian2 =
            meridianDistance(
                _a,
                _e2,
                latitude2);

        const W psi2 =
            isometricLatitude(
                _e,
                latitude2);

        if (!isFiniteGeodesyScalar(psi2))
            return false;

        W scale;

        if (deltaMeridian == cast(W) 0)
        {
            scale =
                localEastWestRadius(
                    _a,
                    _e2,
                    latitude1);
        }
        else
        {
            scale =
                meridianPerIsometric(
                    _a,
                    _e2,
                    _e,
                    latitude1,
                    latitude2,
                    meridian1,
                    meridian2,
                    psi1,
                    psi2);
        }

        if (!isFiniteGeodesyScalar(scale)
            || !(scale > cast(W) 0))
            return false;

        const W deltaLongitude =
            distance * sinBearing / scale;

        if (!isFiniteGeodesyScalar(deltaLongitude))
            return false;

        GeographicCoordinate!T endpoint;

        if (!makeGeographicCoordinate(
                cast(T) latitude2,
                cast(T) canonicalAngleRadians(
                    longitude1 + deltaLongitude),
                endpoint))
            return false;

        result =
            RhumbDirectResult!T.fromPosition(
                endpoint);

        return true;
    }

public:
    /** True when this solver contains supported prepared ellipsoid state. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && _ellipsoid.flattening >= cast(T) 0
            && _ellipsoid.flattening <= cast(T) 0.01L
            && isFiniteGeodesyScalar(_a)
            && _a > cast(W) 0
            && isFiniteGeodesyScalar(_e2)
            && _e2 >= cast(W) 0
            && isFiniteGeodesyScalar(_poleDistance)
            && _poleDistance > cast(W) 0
            && isFiniteGeodesyScalar(_rectifyingRadius)
            && _rectifyingRadius > cast(W) 0;
    }

    /// Example checking a prepared Rhumb solver.
    @safe unittest
    {
        import geodesy;
        assert(Rhumb!double.fromEllipsoid(wgs84!double()).isValid);
        assert(!Rhumb!double.init.isValid);
    }


    /** Prepare a rhumb solver without throwing. */
    static bool tryFromEllipsoid(
        const Ellipsoid!T ellipsoid,
        out Rhumb result)
        pure nothrow @safe @nogc
    {
        result = Rhumb.init;

        if (!ellipsoid.isValid
            || ellipsoid.flattening < cast(T) 0
            || ellipsoid.flattening > cast(T) 0.01L)
            return false;

        const W a =
            cast(W) ellipsoid.semiMajorAxis;
        const W f =
            cast(W) ellipsoid.flattening;
        const W e2 =
            f * (cast(W) 2 - f);
        const W e =
            sqrt(e2);

        const W poleDistance =
            meridianDistance(
                a,
                e2,
                halfPi!W);

        const W rectifyingRadius =
            poleDistance / halfPi!W;

        if (!isFiniteGeodesyScalar(poleDistance)
            || !(poleDistance > cast(W) 0)
            || !isFiniteGeodesyScalar(rectifyingRadius)
            || !(rectifyingRadius > cast(W) 0))
            return false;

        Rhumb candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._a = a;
        candidate._f = f;
        candidate._e2 = e2;
        candidate._e = e;
        candidate._poleDistance = poleDistance;
        candidate._rectifyingRadius = rectifyingRadius;

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }

    /// Example preparing a Rhumb solver without throwing.
    @safe unittest
    {
        import geodesy;
        Rhumb!double solver;
        assert(Rhumb!double.tryFromEllipsoid(
            wgs84!double(),
            solver));
    }


    /** Prepare a rhumb solver or throw. */
    static Rhumb fromEllipsoid(
        const Ellipsoid!T ellipsoid)
        @safe
    {
        Rhumb result;

        if (!tryFromEllipsoid(
                ellipsoid,
                result))
            throw new GeodesyValueException(
                "Rhumb requires a valid spherical/oblate ellipsoid with "
                ~ "0 <= flattening <= 0.01.");

        return result;
    }

    /// Example preparing a WGS 84 Rhumb solver.
    @safe unittest
    {
        import geodesy;
        const solver =
            Rhumb!double.fromEllipsoid(
                wgs84!double());
        assert(solver.ellipsoid.flattening > 0.0);
    }


    /** Solver ellipsoid. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /// Example reading the rhumb ellipsoid.
    @safe unittest
    {
        import geodesy;
        assert(Rhumb!double.fromEllipsoid(
            wgs84!double()).ellipsoid.semiMajorAxis == 6_378_137.0);
    }


    /** Solve the shortest inverse rhumb problem without throwing. */
    bool tryInverse(
        const GeographicCoordinate!T start,
        const GeographicCoordinate!T end,
        out RhumbInverseResult!T result) const
        pure nothrow @safe @nogc
    {
        result = RhumbInverseResult!T.init;

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

        if (!isFiniteGeodesyScalar(latitude1)
            || !isFiniteGeodesyScalar(longitude1)
            || !isFiniteGeodesyScalar(latitude2)
            || !isFiniteGeodesyScalar(longitude2))
            return false;

        const W hp = halfPi!W;
        const bool pole1 =
            latitude1 == hp || latitude1 == -hp;
        const bool pole2 =
            latitude2 == hp || latitude2 == -hp;

        /*
         * Every stored longitude denotes the same physical point at an exact
         * pole. Identical poles are therefore coincident.
         */
        if (latitude1 == latitude2
            && (pole1
                || longitude1 == longitude2))
        {
            Angle!T bearing;
            if (!Angle!T.tryFromRadians(
                    cast(T) 0,
                    bearing))
                return false;

            result =
                RhumbInverseResult!T.fromComponents(
                    cast(T) 0,
                    bearing);
            return true;
        }

        const W meridian1 =
            meridianDistance(
                _a,
                _e2,
                latitude1);
        const W meridian2 =
            meridianDistance(
                _a,
                _e2,
                latitude2);

        if (pole1 || pole2)
        {
            const W distance =
                fabs(meridian2 - meridian1);

            const W bearingRadians =
                latitude2 > latitude1
                    ? cast(W) 0
                    : -pi!W;

            Angle!T bearing;
            if (!Angle!T.tryFromRadians(
                    cast(T) bearingRadians,
                    bearing))
                return false;

            result =
                RhumbInverseResult!T.fromComponents(
                    canonicalZero(cast(T) distance),
                    bearing);
            return true;
        }

        const W psi1 =
            isometricLatitude(
                _e,
                latitude1);
        const W psi2 =
            isometricLatitude(
                _e,
                latitude2);

        const W deltaPsi =
            psi2 - psi1;
        const W deltaLongitude =
            shortestLongitudeDifference(
                longitude1,
                longitude2);

        const W scale =
            meridianPerIsometric(
                _a,
                _e2,
                _e,
                latitude1,
                latitude2,
                meridian1,
                meridian2,
                psi1,
                psi2);

        const W distance =
            stableHypot2(
                deltaLongitude,
                deltaPsi)
            * scale;

        const W bearingRadians =
            atan2(
                deltaLongitude,
                deltaPsi);

        if (!isFiniteGeodesyScalar(distance)
            || distance < cast(W) 0
            || !isFiniteGeodesyScalar(bearingRadians))
            return false;

        const T publicBearing =
            canonicalAngleRadians(
                cast(T) bearingRadians);

        Angle!T bearing;
        if (!Angle!T.tryFromRadians(
                publicBearing,
                bearing))
            return false;

        result =
            RhumbInverseResult!T.fromComponents(
                canonicalZero(cast(T) distance),
                bearing);

        return true;
    }

    /// Example solving an inverse rhumb without throwing.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const end = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(47.07071),
            Longitude!double.fromDegrees(15.43950));
        RhumbInverseResult!double result;
        assert(solver.tryInverse(start, end, result));
        assert(result.distance > 0.0);
    }


    /** Solve the shortest inverse rhumb problem or throw. */
    RhumbInverseResult!T inverse(
        const GeographicCoordinate!T start,
        const GeographicCoordinate!T end) const
        @safe
    {
        RhumbInverseResult!T result;

        if (!tryInverse(
                start,
                end,
                result))
            throw new GeodesyValueException(
                "Rhumb inverse requires a valid solver and finite "
                ~ "representable endpoints.");

        return result;
    }

    /// Example solving an inverse rhumb.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));
        const end = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(10.0));
        assert(solver.inverse(start, end).bearing.degrees == 90.0);
    }


    /** Solve a signed-distance direct rhumb problem without throwing. */
    bool tryDirect(
        const GeographicCoordinate!T start,
        const Angle!T bearing,
        const T distance,
        out RhumbDirectResult!T result) const
        pure nothrow @safe @nogc
    {
        result = RhumbDirectResult!T.init;

        if (!isValid
            || !isFiniteGeodesyScalar(distance))
            return false;

        const W latitude1 =
            workingLatitudeRadians!T(
                start.latitude.radians);
        const W longitude1 =
            workingCanonicalAngleRadians!T(
                start.longitude.radians);
        const W bearingRadians =
            workingCanonicalAngleRadians!T(
                bearing.radians);
        const W s12 =
            cast(W) distance;

        if (!isFiniteGeodesyScalar(latitude1)
            || !isFiniteGeodesyScalar(longitude1)
            || !isFiniteGeodesyScalar(bearingRadians)
            || !isFiniteGeodesyScalar(s12))
            return false;

        const W meridian1 =
            meridianDistance(
                _a,
                _e2,
                latitude1);

        const W hp = halfPi!W;
        W psi1 = W.nan;

        if (latitude1 != hp
            && latitude1 != -hp)
        {
            psi1 =
                isometricLatitude(
                    _e,
                    latitude1);
        }

        W sinBearing =
            sin(bearingRadians);
        W cosBearing =
            cos(bearingRadians);

        if (bearingRadians == cast(W) 0)
        {
            sinBearing = cast(W) 0;
            cosBearing = cast(W) 1;
        }
        else if (bearingRadians == halfPi!W)
        {
            sinBearing = cast(W) 1;
            cosBearing = cast(W) 0;
        }
        else if (bearingRadians == -halfPi!W)
        {
            sinBearing = cast(W) -1;
            cosBearing = cast(W) 0;
        }
        else if (bearingRadians == -pi!W)
        {
            sinBearing = cast(W) 0;
            cosBearing = cast(W) -1;
        }

        return tryDirectPrepared(
            latitude1,
            longitude1,
            meridian1,
            psi1,
            sinBearing,
            cosBearing,
            s12,
            result);
    }

    /// Example solving a direct rhumb without throwing.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        RhumbDirectResult!double result;
        assert(solver.tryDirect(
            start,
            Angle!double.fromDegrees(90.0),
            1_000.0,
            result));
    }


    /** Solve a signed-distance direct rhumb problem or throw. */
    RhumbDirectResult!T direct(
        const GeographicCoordinate!T start,
        const Angle!T bearing,
        const T distance) const
        @safe
    {
        RhumbDirectResult!T result;

        if (!tryDirect(
                start,
                bearing,
                distance,
                result))
            throw new GeodesyValueException(
                "Rhumb direct requires a valid solver, finite inputs, and a "
                ~ "non-pole-crossing result with defined longitude.");

        return result;
    }

    /// Example solving a direct rhumb.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(solver.direct(
            start,
            Angle!double.fromDegrees(0.0),
            1_000.0).position.latitude.degrees > 48.20849);
    }


    /** Prepare a reusable constant-bearing rhumb line without throwing. */
    bool tryLine(
        const GeographicCoordinate!T start,
        const Angle!T bearing,
        out RhumbLine!T result) const
        pure nothrow @safe @nogc
    {
        return RhumbLine!T.tryFromRhumb(
            this,
            start,
            bearing,
            result);
    }

    /// Example preparing a rhumb line without throwing.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        RhumbLine!double line;
        assert(solver.tryLine(
            start,
            Angle!double.fromDegrees(73.0),
            line));
    }


    /** Prepare a reusable constant-bearing rhumb line or throw. */
    RhumbLine!T line(
        const GeographicCoordinate!T start,
        const Angle!T bearing) const
        @safe
    {
        RhumbLine!T result;

        if (!tryLine(
                start,
                bearing,
                result))
            throw new GeodesyValueException(
                "Rhumb line requires a valid solver, finite bearing, and a "
                ~ "non-polar start coordinate.");

        return result;
    }

    /// Example preparing a reusable rhumb line.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(solver.line(
            start,
            Angle!double.fromDegrees(73.0)).isValid);
    }
}

/// Example using a Rhumb solver.
@safe unittest
{
    import geodesy;
    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    assert(solver.isValid);
}


/**
 * Prepared constant-bearing rhumb line for repeated distance positions.
 *
 * Start auxiliary state and bearing sine/cosine are prepared once. `.init`
 * is invalid.
 */
struct RhumbLine(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    bool _valid;
    Rhumb!T _solver;
    GeographicCoordinate!T _start;
    Angle!T _bearing;
    W _latitude1 = W.nan;
    W _longitude1 = W.nan;
    W _meridian1 = W.nan;
    W _psi1 = W.nan;
    W _sinBearing = W.nan;
    W _cosBearing = W.nan;

public:
    /** True when this line has reusable finite prepared state. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _valid
            && _solver.isValid
            && isFiniteGeodesyScalar(_latitude1)
            && isFiniteGeodesyScalar(_longitude1)
            && isFiniteGeodesyScalar(_meridian1)
            && isFiniteGeodesyScalar(_psi1)
            && isFiniteGeodesyScalar(_sinBearing)
            && isFiniteGeodesyScalar(_cosBearing);
    }

    /// Example checking a prepared RhumbLine.
    @safe unittest
    {
        assert(!RhumbLine!double.init.isValid);
    }


    /** Prepare from an existing solver without throwing. */
    static bool tryFromRhumb(
        const Rhumb!T solver,
        const GeographicCoordinate!T start,
        const Angle!T bearing,
        out RhumbLine result)
        pure nothrow @safe @nogc
    {
        result = RhumbLine.init;

        if (!solver.isValid)
            return false;

        const W latitude1 =
            workingLatitudeRadians!T(
                start.latitude.radians);
        const W longitude1 =
            workingCanonicalAngleRadians!T(
                start.longitude.radians);
        const W bearingRadians =
            workingCanonicalAngleRadians!T(
                bearing.radians);

        if (!isFiniteGeodesyScalar(latitude1)
            || !isFiniteGeodesyScalar(longitude1)
            || !isFiniteGeodesyScalar(bearingRadians)
            || latitude1 == halfPi!W
            || latitude1 == -halfPi!W)
            return false;

        const W meridian1 =
            meridianDistance(
                solver._a,
                solver._e2,
                latitude1);
        const W psi1 =
            isometricLatitude(
                solver._e,
                latitude1);

        W sinBearing =
            sin(bearingRadians);
        W cosBearing =
            cos(bearingRadians);

        if (bearingRadians == cast(W) 0)
        {
            sinBearing = cast(W) 0;
            cosBearing = cast(W) 1;
        }
        else if (bearingRadians == halfPi!W)
        {
            sinBearing = cast(W) 1;
            cosBearing = cast(W) 0;
        }
        else if (bearingRadians == -halfPi!W)
        {
            sinBearing = cast(W) -1;
            cosBearing = cast(W) 0;
        }
        else if (bearingRadians == -pi!W)
        {
            sinBearing = cast(W) 0;
            cosBearing = cast(W) -1;
        }

        if (!isFiniteGeodesyScalar(meridian1)
            || !isFiniteGeodesyScalar(psi1)
            || !isFiniteGeodesyScalar(sinBearing)
            || !isFiniteGeodesyScalar(cosBearing))
            return false;

        RhumbLine candidate;
        candidate._solver = solver;
        candidate._start = start;
        candidate._bearing = bearing;
        candidate._latitude1 = latitude1;
        candidate._longitude1 = longitude1;
        candidate._meridian1 = meridian1;
        candidate._psi1 = psi1;
        candidate._sinBearing = sinBearing;
        candidate._cosBearing = cosBearing;
        candidate._valid = true;

        result = candidate;
        return true;
    }

    /// Example preparing RhumbLine directly.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        RhumbLine!double line;
        assert(RhumbLine!double.tryFromRhumb(
            solver,
            start,
            Angle!double.fromDegrees(73.0),
            line));
    }


    /** Prepare from an existing solver or throw. */
    static RhumbLine fromRhumb(
        const Rhumb!T solver,
        const GeographicCoordinate!T start,
        const Angle!T bearing)
        @safe
    {
        RhumbLine result;

        if (!tryFromRhumb(
                solver,
                start,
                bearing,
                result))
            throw new GeodesyValueException(
                "RhumbLine requires a valid Rhumb solver, finite bearing, "
                ~ "and a non-polar start coordinate.");

        return result;
    }

    /// Example constructing a RhumbLine.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(RhumbLine!double.fromRhumb(
            solver,
            start,
            Angle!double.fromDegrees(73.0)).isValid);
    }


    /** Prepared start coordinate. */
    @property GeographicCoordinate!T start() const
        pure nothrow @safe @nogc
    {
        return _start;
    }

    /// Example reading RhumbLine start.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));
        assert(solver.line(
            start,
            Angle!double.fromDegrees(45.0)).start.latitude.degrees == 48.0);
    }


    /** Constant canonical bearing. */
    @property Angle!T bearing() const
        pure nothrow @safe @nogc
    {
        return _bearing;
    }

    /// Example reading RhumbLine bearing.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));
        assert(solver.line(
            start,
            Angle!double.fromDegrees(45.0)).bearing.degrees == 45.0);
    }


    /** Evaluate a signed distance along this prepared line without throwing. */
    bool tryPosition(
        const T distance,
        out RhumbDirectResult!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        return _solver.tryDirectPrepared(
            _latitude1,
            _longitude1,
            _meridian1,
            _psi1,
            _sinBearing,
            _cosBearing,
            cast(W) distance,
            result);
    }

    /// Example evaluating a prepared RhumbLine.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        RhumbDirectResult!double result;
        assert(solver.line(
            start,
            Angle!double.fromDegrees(73.0)).tryPosition(
                1_000.0,
                result));
    }


    /** Evaluate a signed distance along this prepared line or throw. */
    RhumbDirectResult!T position(
        const T distance) const
        @safe
    {
        RhumbDirectResult!T result;

        if (!tryPosition(
                distance,
                result))
            throw new GeodesyValueException(
                "RhumbLine position requires a valid line, finite distance, "
                ~ "and a non-pole-crossing result.");

        return result;
    }

    /// Example evaluating a prepared RhumbLine position.
    @safe unittest
    {
        import geodesy;
        const solver = Rhumb!double.fromEllipsoid(wgs84!double());
        const start = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(solver.line(
            start,
            Angle!double.fromDegrees(73.0)).position(
                1_000.0).position.longitude.degrees > 16.37208);
    }
}

/// Example using RhumbLine.
@safe unittest
{
    import geodesy;
    const solver = Rhumb!double.fromEllipsoid(wgs84!double());
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0));
    assert(solver.line(
        start,
        Angle!double.fromDegrees(45.0)).isValid);
}


unittest
{
    import std.exception : assertThrown;

    const sphere =
        Rhumb!double.fromEllipsoid(
            Ellipsoid!double.sphere(6_371_000.0));

    const equator0 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    const equator90 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(90.0));

    const quarter =
        sphere.inverse(
            equator0,
            equator90);

    assert(fabs(
        quarter.distance
            - 6_371_000.0 * PI / 2) < 1e-7);
    assert(quarter.bearing.degrees == 90.0);

    const opposite =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(180.0));

    const tie =
        sphere.inverse(
            equator0,
            opposite);

    assert(tie.bearing.degrees == 90.0);

    const wgs =
        Rhumb!double.fromEllipsoid(
            wgs84!double());

    const vienna =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));

    const graz =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(47.07071),
            Longitude!double.fromDegrees(15.43950));

    const inverse =
        wgs.inverse(vienna, graz);

    const direct =
        wgs.direct(
            vienna,
            inverse.bearing,
            inverse.distance);

    assert(fabs(
        direct.position.latitude.radians
            - graz.latitude.radians) < 2e-11);

    assert(fabs(
        canonicalAngleRadians(
            direct.position.longitude.radians
                - graz.longitude.radians)) < 2e-11);

    const line =
        wgs.line(
            vienna,
            inverse.bearing);

    const lineResult =
        line.position(
            inverse.distance);

    assert(fabs(
        lineResult.position.latitude.radians
            - direct.position.latitude.radians) < 2e-14);

    const northPole =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(120.0));

    const northPoleSame =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(-20.0));

    const poleCoincident =
        wgs.inverse(
            northPole,
            northPoleSame);

    assert(poleCoincident.distance == 0.0);
    assert(poleCoincident.bearing.radians == 0.0);

    RhumbDirectResult!double invalidDirect;
    assert(!wgs.tryDirect(
        northPole,
        Angle!double.fromDegrees(180.0),
        1_000.0,
        invalidDirect));

    assertThrown!GeodesyValueException(
        wgs.direct(
            northPole,
            Angle!double.fromDegrees(180.0),
            1_000.0));
}
