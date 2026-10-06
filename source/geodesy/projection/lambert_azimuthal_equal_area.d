/**
 * Bounded ellipsoidal Lambert Azimuthal Equal Area projection.
 *
 * This module implements a prepared mathematical LAEA kernel for spherical
 * and oblate ellipsoids. The public family deliberately does not embed CRS
 * authority lookup or EPSG presets.
 *
 * Standards:
 *     The mathematical family follows ellipsoidal Lambert Azimuthal Equal
 *     Area semantics. Authority-backed validation includes EPSG:3035
 *     (ETRS89-extended / LAEA Europe).
 *
 * Domain:
 *     Oblique, equatorial, north-polar, and south-polar projection centres
 *     are supported. The exact authalic antipode is a directional
 *     singularity and is excluded; reverse accepts the open represented disk.
 *
 * Units:
 *     False easting, false northing, projected coordinates, and ellipsoid
 *     axes use the same caller-selected linear unit.
 *
 * Numerics:
 *     Public float uses double working precision. Checked hot paths are pure,
 *     nothrow, @safe, and @nogc.
 *
 * Equal-area semantics:
 *     LAEA is not conformal and therefore deliberately does not expose
 *     ConformalProjectionFactors.
 *
 * See_Also:
 *     GeographicCoordinate, ProjectedCoordinate, LambertConformalConic
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
module geodesy.projection.lambert_azimuthal_equal_area;

import std.math :
    PI,
    asin,
    atan2,
    cos,
    fabs,
    log,
    sin,
    sqrt;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


private enum LaeaMode
{
    northPolar,
    southPolar,
    equatorial,
    oblique
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


/** Return the canonical shortest longitude difference. */
private T longitudeDifference(T)(
    const T longitude,
    const T origin)
    pure nothrow @safe @nogc
{
    return canonicalAngleRadians(longitude - origin);
}


/** Lift public latitude to working precision while preserving cardinal values. */
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


/** Lift canonical public longitude to working precision. */
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


/** Compute a stable two-argument hypotenuse. */
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


/** Evaluate sine/cosine with exact public cardinal values. */
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


/** Clamp only machine-roundoff excursions beyond the closed unit interval. */
private bool clampUnitRoundoff(T)(
    const T value,
    out T clamped)
    pure nothrow @safe @nogc
{
    clamped = value;

    if (value >= cast(T) -1
        && value <= cast(T) 1)
        return true;

    const T excess =
        value > cast(T) 1
            ? value - cast(T) 1
            : -cast(T) 1 - value;

    if (excess > cast(T) 32 * T.epsilon)
        return false;

    clamped =
        value > cast(T) 0
            ? cast(T) 1
            : cast(T) -1;

    return true;
}


/** Ellipsoidal authalic q(phi), including the spherical limit. */
private T authalicQ(T)(
    const T e2,
    const T eccentricity,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    if (e2 == cast(T) 0)
        return cast(T) 2 * sine;

    const T es =
        eccentricity * sine;

    const T denominator =
        cast(T) 1 - e2 * sine * sine;

    return (cast(T) 1 - e2)
        * (
            sine / denominator
            - log(
                (cast(T) 1 - es)
                / (cast(T) 1 + es))
                / (cast(T) 2 * eccentricity)
        );
}


/** Exact derivative dq/dphi on the open latitude interval. */
private T authalicQDerivative(T)(
    const T e2,
    const T latitude)
    pure nothrow @safe @nogc
{
    T sine;
    T cosine;
    sinCosLatitude(latitude, sine, cosine);

    const T denominator =
        cast(T) 1 - e2 * sine * sine;

    return cast(T) 2
        * (cast(T) 1 - e2)
        * cosine
        / (denominator * denominator);
}


/** Recover geodetic latitude from finite authalic q. */
private bool inverseAuthalicQ(T)(
    const T e2,
    const T eccentricity,
    const T qp,
    const T targetQ,
    out T latitude)
    pure nothrow @safe @nogc
{
    latitude = T.nan;

    if (!isFiniteGeodesyScalar(targetQ)
        || !isFiniteGeodesyScalar(qp)
        || !(qp > cast(T) 0))
        return false;

    T ratio;
    if (!clampUnitRoundoff(targetQ / qp, ratio))
        return false;

    if (ratio == cast(T) 1)
    {
        latitude = halfPi!T;
        return true;
    }

    if (ratio == cast(T) -1)
    {
        latitude = -halfPi!T;
        return true;
    }

    T phi = asin(ratio);

    foreach (_; 0 .. 14)
    {
        const T q =
            authalicQ(e2, eccentricity, phi);

        const T derivative =
            authalicQDerivative(e2, phi);

        if (!isFiniteGeodesyScalar(q)
            || !isFiniteGeodesyScalar(derivative)
            || !(derivative > cast(T) 0))
            return false;

        const T correction =
            (q - targetQ) / derivative;

        phi -= correction;

        if (phi <= -halfPi!T
            || phi >= halfPi!T)
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
        authalicQ(e2, eccentricity, phi)
        - targetQ;

    if (fabs(residual)
        > cast(T) 64 * T.epsilon
            * (cast(T) 1 + fabs(targetQ)))
        return false;

    latitude = phi;
    return true;
}


/**
 * Prepared ellipsoidal Lambert Azimuthal Equal Area projection.
 *
 * All projection-centre latitudes are supported. The exact antipode is
 * deliberately excluded from the represented public domain.
 *
 * `.init` is intentionally invalid.
 */
struct LambertAzimuthalEqualArea(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    Latitude!T _latitudeOfProjectionCentre;
    Longitude!T _longitudeOfProjectionCentre;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;

    LaeaMode _mode;
    W _a = W.nan;
    W _e2 = W.nan;
    W _e = W.nan;
    W _qp = W.nan;
    W _rq = W.nan;
    W _sinBeta0 = W.nan;
    W _cosBeta0 = W.nan;
    W _d = W.nan;

    /** Detect a public input that is exactly representable as the prepared antipode. */
    bool sourceIsExactAntipode(
        const GeographicCoordinate!T source) const
        pure nothrow @safe @nogc
    {
        const T sourceLatitude = source.latitude.radians;
        const T centreLatitude =
            _latitudeOfProjectionCentre.radians;

        if (_mode == LaeaMode.northPolar)
            return sourceLatitude == -halfPi!T;

        if (_mode == LaeaMode.southPolar)
            return sourceLatitude == halfPi!T;

        if (sourceLatitude != -centreLatitude)
            return false;

        const T delta =
            longitudeDifference(
                source.longitude.normalized.radians,
                _longitudeOfProjectionCentre.radians);

        return delta == -pi!T;
    }


    /** Evaluate forward LAEA in working precision. */
    bool forwardWorking(
        const GeographicCoordinate!T source,
        out W easting,
        out W northing) const
        pure nothrow @safe @nogc
    {
        easting = W.nan;
        northing = W.nan;

        if (!isValid
            || sourceIsExactAntipode(source))
            return false;

        const W latitude =
            workingLatitudeRadians!T(
                source.latitude.radians);

        const W longitude =
            workingLongitudeRadians!T(
                source.longitude.normalized.radians);

        const W centreLongitude =
            workingLongitudeRadians!T(
                _longitudeOfProjectionCentre.radians);

        const W deltaLongitude =
            longitudeDifference(
                longitude,
                centreLongitude);

        if (source.latitude.radians
                == _latitudeOfProjectionCentre.radians
            && deltaLongitude == cast(W) 0)
        {
            easting = cast(W) _falseEasting;
            northing = cast(W) _falseNorthing;
            return true;
        }

        const W q =
            authalicQ(_e2, _e, latitude);

        W sinBeta;
        if (!clampUnitRoundoff(q / _qp, sinBeta))
            return false;

        const W cosBeta =
            sqrt(
                (cast(W) 1 - sinBeta)
                * (cast(W) 1 + sinBeta));

        const W sinLon = sin(deltaLongitude);
        const W cosLon = cos(deltaLongitude);

        final switch (_mode)
        {
            case LaeaMode.northPolar:
            {
                W radialSquared =
                    _a * _a * (_qp - q);

                if (radialSquared < cast(W) 0)
                {
                    if (-radialSquared
                        > cast(W) 64 * W.epsilon
                            * _a * _a * _qp)
                        return false;
                    radialSquared = cast(W) 0;
                }

                const W radius =
                    sqrt(radialSquared);

                easting =
                    cast(W) _falseEasting
                    + radius * sinLon;

                northing =
                    cast(W) _falseNorthing
                    - radius * cosLon;

                return isFiniteGeodesyScalar(easting)
                    && isFiniteGeodesyScalar(northing);
            }

            case LaeaMode.southPolar:
            {
                W radialSquared =
                    _a * _a * (_qp + q);

                if (radialSquared < cast(W) 0)
                {
                    if (-radialSquared
                        > cast(W) 64 * W.epsilon
                            * _a * _a * _qp)
                        return false;
                    radialSquared = cast(W) 0;
                }

                const W radius =
                    sqrt(radialSquared);

                easting =
                    cast(W) _falseEasting
                    + radius * sinLon;

                northing =
                    cast(W) _falseNorthing
                    + radius * cosLon;

                return isFiniteGeodesyScalar(easting)
                    && isFiniteGeodesyScalar(northing);
            }

            case LaeaMode.equatorial:
            case LaeaMode.oblique:
            {
                const W denominator =
                    cast(W) 1
                    + _sinBeta0 * sinBeta
                    + _cosBeta0 * cosBeta * cosLon;

                /*
                 * At the authalic antipode the denominator is exactly zero.
                 * Independently converted public angles can leave a tiny
                 * positive roundoff residue, so classify only the
                 * machine-roundoff neighbourhood of zero as singular.
                 */
                if (!isFiniteGeodesyScalar(denominator)
                    || denominator
                        <= cast(W) 64 * W.epsilon)
                    return false;

                const W b =
                    _rq
                    * sqrt(cast(W) 2 / denominator);

                easting =
                    cast(W) _falseEasting
                    + b * _d * cosBeta * sinLon;

                northing =
                    cast(W) _falseNorthing
                    + b / _d
                        * (
                            _cosBeta0 * sinBeta
                            - _sinBeta0 * cosBeta * cosLon
                        );

                return isFiniteGeodesyScalar(easting)
                    && isFiniteGeodesyScalar(northing);
            }
        }
    }


    /** Evaluate reverse LAEA in working precision. */
    bool reverseWorking(
        const ProjectedCoordinate!T source,
        out W latitude,
        out W longitude) const
        pure nothrow @safe @nogc
    {
        latitude = W.nan;
        longitude = W.nan;

        if (!isValid)
            return false;

        const W dx =
            cast(W) source.easting
            - cast(W) _falseEasting;

        const W dy =
            cast(W) source.northing
            - cast(W) _falseNorthing;

        if (!isFiniteGeodesyScalar(dx)
            || !isFiniteGeodesyScalar(dy))
            return false;

        const W centreLongitude =
            workingLongitudeRadians!T(
                _longitudeOfProjectionCentre.radians);

        if (source.easting == _falseEasting
            && source.northing == _falseNorthing)
        {
            latitude =
                workingLatitudeRadians!T(
                    _latitudeOfProjectionCentre.radians);

            longitude = centreLongitude;
            return true;
        }

        W targetQ;
        W deltaLongitude;

        final switch (_mode)
        {
            case LaeaMode.northPolar:
            {
                const W radiusSquared =
                    dx * dx + dy * dy;

                const W maxRadiusSquared =
                    cast(W) 2 * _a * _a * _qp;

                if (!(radiusSquared < maxRadiusSquared))
                    return false;

                targetQ =
                    _qp - radiusSquared / (_a * _a);

                deltaLongitude =
                    atan2(dx, -dy);
                break;
            }

            case LaeaMode.southPolar:
            {
                const W radiusSquared =
                    dx * dx + dy * dy;

                const W maxRadiusSquared =
                    cast(W) 2 * _a * _a * _qp;

                if (!(radiusSquared < maxRadiusSquared))
                    return false;

                targetQ =
                    radiusSquared / (_a * _a) - _qp;

                deltaLongitude =
                    atan2(dx, dy);
                break;
            }

            case LaeaMode.equatorial:
            case LaeaMode.oblique:
            {
                const W x =
                    dx / _d;

                const W y =
                    dy * _d;

                const W rho =
                    hypot2(x, y);

                const W diameter =
                    cast(W) 2 * _rq;

                if (!(rho < diameter))
                    return false;

                const W halfRatio =
                    rho / diameter;

                W boundedHalfRatio;
                if (!clampUnitRoundoff(
                        halfRatio,
                        boundedHalfRatio))
                    return false;

                const W ce =
                    cast(W) 2
                    * asin(boundedHalfRatio);

                const W sinCe = sin(ce);
                const W cosCe = cos(ce);

                W sinBeta =
                    cosCe * _sinBeta0
                    + y * sinCe * _cosBeta0 / rho;

                if (!clampUnitRoundoff(
                        sinBeta,
                        sinBeta))
                    return false;

                targetQ =
                    _qp * sinBeta;

                const W numerator =
                    x * sinCe;

                const W denominator =
                    rho * _cosBeta0 * cosCe
                    - y * _sinBeta0 * sinCe;

                deltaLongitude =
                    atan2(numerator, denominator);
                break;
            }
        }

        if (!inverseAuthalicQ(
                _e2,
                _e,
                _qp,
                targetQ,
                latitude))
            return false;

        longitude =
            canonicalAngleRadians(
                centreLongitude + deltaLongitude);

        return isFiniteGeodesyScalar(longitude);
    }

public:
    /** True when this value contains supported prepared LAEA state. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && _ellipsoid.flattening <= cast(T) 0.01
            && isFiniteGeodesyScalar(_falseEasting)
            && isFiniteGeodesyScalar(_falseNorthing)
            && isFiniteGeodesyScalar(_a)
            && _a > cast(W) 0
            && isFiniteGeodesyScalar(_e2)
            && _e2 >= cast(W) 0
            && isFiniteGeodesyScalar(_qp)
            && _qp > cast(W) 0
            && isFiniteGeodesyScalar(_rq)
            && _rq > cast(W) 0
            && isFiniteGeodesyScalar(_sinBeta0)
            && isFiniteGeodesyScalar(_cosBeta0)
            && isFiniteGeodesyScalar(_d)
            && _d > cast(W) 0;
    }

    /// Example checking prepared LAEA state.
    @safe unittest
    {
        import geodesy;
        assert(!LambertAzimuthalEqualArea!double.init.isValid);
    }


    /** Prepare a Lambert Azimuthal Equal Area projection without throwing. */
    static bool tryFromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfProjectionCentre,
        const Longitude!T longitudeOfProjectionCentre,
        const T falseEasting,
        const T falseNorthing,
        out LambertAzimuthalEqualArea result)
        pure nothrow @safe @nogc
    {
        result = LambertAzimuthalEqualArea.init;

        if (!ellipsoid.isValid
            || ellipsoid.flattening > cast(T) 0.01
            || !isFiniteGeodesyScalar(falseEasting)
            || !isFiniteGeodesyScalar(falseNorthing))
            return false;

        const W a =
            cast(W) ellipsoid.semiMajorAxis;

        const W f =
            cast(W) ellipsoid.flattening;

        const W e2 =
            f * (cast(W) 2 - f);

        const W e = sqrt(e2);

        const W qp =
            authalicQ(
                e2,
                e,
                halfPi!W);

        if (!isFiniteGeodesyScalar(qp)
            || !(qp > cast(W) 0))
            return false;

        const W rq =
            a * sqrt(qp / cast(W) 2);

        if (!isFiniteGeodesyScalar(rq)
            || !(rq > cast(W) 0))
            return false;

        const T centrePublic =
            latitudeOfProjectionCentre.radians;

        LaeaMode mode;

        if (centrePublic == halfPi!T)
            mode = LaeaMode.northPolar;
        else if (centrePublic == -halfPi!T)
            mode = LaeaMode.southPolar;
        else if (centrePublic == cast(T) 0)
            mode = LaeaMode.equatorial;
        else
            mode = LaeaMode.oblique;

        const W phi0 =
            workingLatitudeRadians!T(
                centrePublic);

        const W q0 =
            authalicQ(e2, e, phi0);

        W sinBeta0;
        if (!clampUnitRoundoff(
                q0 / qp,
                sinBeta0))
            return false;

        const W cosBeta0 =
            sqrt(
                (cast(W) 1 - sinBeta0)
                * (cast(W) 1 + sinBeta0));

        W d = cast(W) 1;

        if (mode == LaeaMode.equatorial
            || mode == LaeaMode.oblique)
        {
            W sinPhi0;
            W cosPhi0;
            sinCosLatitude(
                phi0,
                sinPhi0,
                cosPhi0);

            const W m0 =
                cosPhi0
                / sqrt(
                    cast(W) 1
                    - e2 * sinPhi0 * sinPhi0);

            const W rqNormalized =
                sqrt(qp / cast(W) 2);

            const W denominator =
                rqNormalized * cosBeta0;

            if (!(denominator > cast(W) 0))
                return false;

            d = m0 / denominator;

            if (!isFiniteGeodesyScalar(d)
                || !(d > cast(W) 0))
                return false;
        }

        LambertAzimuthalEqualArea candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._latitudeOfProjectionCentre =
            latitudeOfProjectionCentre;
        candidate._longitudeOfProjectionCentre =
            longitudeOfProjectionCentre.normalized;
        candidate._falseEasting = falseEasting;
        candidate._falseNorthing = falseNorthing;
        candidate._mode = mode;
        candidate._a = a;
        candidate._e2 = e2;
        candidate._e = e;
        candidate._qp = qp;
        candidate._rq = rq;
        candidate._sinBeta0 = sinBeta0;
        candidate._cosBeta0 = cosBeta0;
        candidate._d = d;

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }

    /// Example preparing EPSG:3035-style parameters without throwing.
    @safe unittest
    {
        import geodesy;
        const grs80 = Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257222101);
        LambertAzimuthalEqualArea!double projection;
        assert(LambertAzimuthalEqualArea!double.tryFromParameters(
            grs80,
            Latitude!double.fromDegrees(52.0),
            Longitude!double.fromDegrees(10.0),
            4_321_000.0,
            3_210_000.0,
            projection));
    }


    /** Prepare a Lambert Azimuthal Equal Area projection or throw. */
    static LambertAzimuthalEqualArea fromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfProjectionCentre,
        const Longitude!T longitudeOfProjectionCentre,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        LambertAzimuthalEqualArea result;

        if (!tryFromParameters(
                ellipsoid,
                latitudeOfProjectionCentre,
                longitudeOfProjectionCentre,
                falseEasting,
                falseNorthing,
                result))
            throw new GeodesyValueException(
                "Lambert Azimuthal Equal Area requires a supported ellipsoid, "
                ~ "valid projection centre, and finite false offsets.");

        return result;
    }

    /// Example preparing a Lambert Azimuthal Equal Area projection.
    @safe unittest
    {
        import geodesy;
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                4_321_000.0,
                3_210_000.0);
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
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 0.0);
        assert(projection.ellipsoid.semiMajorAxis == 6_378_137.0);
    }


    /** Latitude of projection centre. */
    @property Latitude!T latitudeOfProjectionCentre() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfProjectionCentre;
    }

    /// Example reading latitude of projection centre.
    @safe unittest
    {
        import geodesy;
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 0.0);
        assert(
            projection.latitudeOfProjectionCentre.radians
                == Latitude!double.fromDegrees(52.0).radians);
    }


    /** Longitude of projection centre. */
    @property Longitude!T longitudeOfProjectionCentre() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfProjectionCentre;
    }

    /// Example reading longitude of projection centre.
    @safe unittest
    {
        import geodesy;
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 0.0);
        assert(
            projection.longitudeOfProjectionCentre.radians
                == Longitude!double.fromDegrees(10.0).radians);
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
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                4_321_000.0, 0.0);
        assert(projection.falseEasting == 4_321_000.0);
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
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 3_210_000.0);
        assert(projection.falseNorthing == 3_210_000.0);
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

        if (!forwardWorking(
                source,
                easting,
                northing))
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
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                4_321_000.0,
                3_210_000.0);
        ProjectedCoordinate!double projected;
        assert(projection.tryForward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(48.20849),
                Longitude!double.fromDegrees(16.37208)),
            projected));
    }


    /** Project a geographic coordinate or throw. */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(source, result))
            throw new GeodesyValueException(
                "Lambert Azimuthal Equal Area forward input is outside the "
                ~ "prepared represented domain.");

        return result;
    }

    /// Example projecting Vienna in an EPSG:3035-style projection.
    @safe unittest
    {
        import geodesy;
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                4_321_000.0,
                3_210_000.0);
        const projected = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(48.20849),
                Longitude!double.fromDegrees(16.37208)));
        assert(projected.easting > 4_000_000.0);
    }


    /** Reverse a projected coordinate without throwing. */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = GeographicCoordinate!T.init;

        W latitude;
        W longitude;

        if (!reverseWorking(
                source,
                latitude,
                longitude))
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
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 0.0);
        const source = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        GeographicCoordinate!double recovered;
        assert(projection.tryReverse(
            projection.forward(source),
            recovered));
    }


    /** Reverse a projected coordinate or throw. */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(source, result))
            throw new GeodesyValueException(
                "Lambert Azimuthal Equal Area reverse input is outside the "
                ~ "prepared represented domain.");

        return result;
    }

    /// Example round-tripping a Lambert Azimuthal Equal Area point.
    @safe unittest
    {
        import geodesy;
        const projection =
            LambertAzimuthalEqualArea!double.fromParameters(
                wgs84!double(),
                Latitude!double.fromDegrees(52.0),
                Longitude!double.fromDegrees(10.0),
                0.0, 0.0);
        const source = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const recovered = projection.reverse(
            projection.forward(source));
        assert(recovered.latitude.degrees > 48.208);
    }
}

/// Example using LambertAzimuthalEqualArea.
@safe unittest
{
    import geodesy;
    const projection =
        LambertAzimuthalEqualArea!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(52.0),
            Longitude!double.fromDegrees(10.0),
            0.0, 0.0);
    assert(projection.isValid);
}


@safe unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    import geodesy;

    static assert(is(LambertAzimuthalEqualArea!float));
    static assert(is(LambertAzimuthalEqualArea!double));
    static assert(is(LambertAzimuthalEqualArea!real));

    assert(!LambertAzimuthalEqualArea!double.init.isValid);

    const projection =
        LambertAzimuthalEqualArea!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(52.0),
            Longitude!double.fromDegrees(10.0),
            4_321_000.0,
            3_210_000.0);

    const centre = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(52.0),
        Longitude!double.fromDegrees(10.0));

    const projectedCentre =
        projection.forward(centre);

    assert(projectedCentre.easting == 4_321_000.0);
    assert(projectedCentre.northing == 3_210_000.0);

    const recoveredCentre =
        projection.reverse(projectedCentre);

    assert(
        recoveredCentre.latitude.radians
            == projection.latitudeOfProjectionCentre.radians);
    assert(
        recoveredCentre.longitude.radians
            == projection.longitudeOfProjectionCentre.radians);

    const source = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));

    const recovered =
        projection.reverse(
            projection.forward(source));

    assert(fabs(
        recovered.latitude.radians
            - source.latitude.radians) < 3e-12);

    assert(fabs(
        canonicalAngleRadians(
            recovered.longitude.radians
                - source.longitude.radians)) < 3e-12);

    const antipode =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-52.0),
            Longitude!double.fromDegrees(-170.0));

    ProjectedCoordinate!double ignored;
    assert(!projection.tryForward(
        antipode,
        ignored));

    assertThrown!GeodesyValueException(
        projection.forward(antipode));

    const north =
        LambertAzimuthalEqualArea!double.fromParameters(
            wgs84!double(),
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(20.0),
            0.0, 0.0);

    const northCentre =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            Longitude!double.fromDegrees(123.0));

    const northProjected =
        north.forward(northCentre);

    assert(northProjected.easting == 0.0);
    assert(northProjected.northing == 0.0);

    const northRecovered =
        north.reverse(northProjected);

    assert(
        northRecovered.latitude.radians
            == Latitude!double.fromDegrees(90.0).radians);
    assert(
        northRecovered.longitude.radians
            == Longitude!double.fromDegrees(20.0).radians);
}
