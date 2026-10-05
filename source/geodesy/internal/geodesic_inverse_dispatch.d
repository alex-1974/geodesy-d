/**
 * Internal dispatch and canonicalization for inverse geodesics.
 *
 * This layer mirrors the symmetry reduction used by GeographicLib 2.7:
 *
 * - compute the longitude difference with a compensated residual;
 * - reduce the problem to the canonical inverse domain;
 * - prepare reduced latitudes with pole protection and symmetry repair;
 * - dispatch meridional, equatorial, and general canonical paths;
 * - restore endpoint order and signs.
 *
 * Public strong-type construction and throwing/non-throwing API semantics are
 * deliberately handled by geodesy.geodesic.
 */
module geodesy.internal.geodesic_inverse_dispatch;

import geodesy.internal.geodesic_inverse_start :
    GeodesicInverseStartKind;

import geodesy.internal.hypot_compat : stableHypot2;
import std.math :
    PI,
    atan2,
    copysign,
    cos,
    fabs,

    signbit,
    sin,
    sqrt;

import geodesy.internal.geodesic_area :
    geodesicAuthalicRadiusSquared,
    geodesicSignedArea;

import geodesy.internal.geodesic_area_series :
    fillGeodesicC4x;

import geodesy.internal.geodesic_inverse_solver :
    geodesicCanonicalInverse;

import geodesy.internal.geodesic_lengths :
    geodesicLengthDistance,
    geodesicLengthReducedLength,
    geodesicLengthScales,
    geodesicLengths;


package(geodesy):


/*
 * Internal compile-time inverse output capabilities.
 *
 * These are deliberately not a public runtime output mask.
 */
enum uint geodesicInverseReducedLength =
    1u << 0;

enum uint geodesicInverseScales =
    1u << 1;

enum uint geodesicInverseArea =
    1u << 2;


/** Internal path selected by inverse dispatch. */
enum GeodesicInverseDispatchKind : ubyte
{
    coincidence,
    meridian,
    equator,
    generalShort,
    generalNewton,
}


/** Internal inverse result in working-scalar units and radians. */
struct GeodesicInverseDispatchResult(W)
{
    W distance;
    W reducedLength;
    W scale12;
    W scale21;
    W initialAzimuth;
    W finalAzimuth;
    W sigma12;
    W signedArea;

    uint iterations;

    GeodesicInverseDispatchKind kind;

    GeodesicInverseStartKind startKind;

    uint bracketMidpointCount;

    bool converged;
}


/** Return pi in the working scalar. */
private W pi(W)()
    pure nothrow @safe @nogc
{
    return cast(W) PI;
}


/** Return pi/2 in the working scalar. */
private W halfPi(W)()
    pure nothrow @safe @nogc
{
    return pi!W / cast(W) 2;
}


/** Return 2*pi in the working scalar. */
private W twoPi(W)()
    pure nothrow @safe @nogc
{
    return cast(W) 2 * pi!W;
}


/** Replace either signed floating zero with canonical positive zero. */
private W canonicalZero(W)(
    const W value)
    pure nothrow @safe @nogc
{
    return value == cast(W) 0
        ? cast(W) 0
        : value;
}


/** Canonicalize a finite angle to the half-open interval [-pi,+pi). */
private W canonicalAngle(W)(
    const W value)
    pure nothrow @safe @nogc
{
    const W p =
        pi!W;

    const W period =
        twoPi!W;

    W result =
        value % period;

    if (result >= p)
        result -= period;
    else if (result < -p)
        result += period;

    return canonicalZero(result);
}


/**
 * Error-free transform for a + b.
 *
 * This is the same TwoSum identity already used by the Transverse Mercator
 * implementation.  It is duplicated here intentionally to keep internal
 * geodesic numerics independent of projection modules.
 */
private void twoSum(W)(
    const W a,
    const W b,
    out W sum,
    out W residual)
    pure nothrow @safe @nogc
{
    sum =
        a + b;

    const W z =
        sum - a;

    residual =
        (a - (sum - z))
        + (b - z);
}


/**
 * GeographicLib-style angular rounding, expressed in radians.
 *
 * GeographicLib uses z = 1/16 degree.  The equivalent radial constant is
 * pi/2880.  The z - (z - |x|) construction intentionally rounds extremely
 * small angles to signed zero while leaving ordinary values unchanged.
 */
private W angleRound(W)(
    const W value)
    pure nothrow @safe @nogc
{
    const W z =
        pi!W
        / cast(W) 2880;

    W magnitude =
        fabs(value);

    const W difference =
        z - magnitude;

    if (difference > cast(W) 0)
        magnitude =
            z - difference;

    return copysign(
        magnitude,
        value);
}


/**
 * Compensated longitude difference.
 *
 * Inputs are finite canonical longitudes.  The returned main value lies in
 * [-pi,+pi], with `residual` carrying the small correction discarded by the
 * rounded main value.  Boundary signs follow GeographicLib AngDiff semantics.
 */
private W longitudeDifference(W)(
    const W longitude1,
    const W longitude2,
    out W residual)
    pure nothrow @safe @nogc
{
    W difference;

    twoSum(
        longitude2,
        -longitude1,
        difference,
        residual);

    const W p =
        pi!W;

    const W period =
        twoPi!W;

    if (
        difference > p
        || (
            difference == p
            && residual > cast(W) 0
        ))
    {
        W reduced;
        W reductionResidual;

        twoSum(
            difference,
            -period,
            reduced,
            reductionResidual);

        difference =
            reduced;

        residual +=
            reductionResidual;
    }
    else if (
        difference < -p
        || (
            difference == -p
            && residual < cast(W) 0
        ))
    {
        W reduced;
        W reductionResidual;

        twoSum(
            difference,
            period,
            reduced,
            reductionResidual);

        difference =
            reduced;

        residual +=
            reductionResidual;
    }

    /*
     * Fold the accumulated correction back into a normalized TwoSum pair.
     */
    {
        W normalized;
        W correction;

        twoSum(
            difference,
            residual,
            normalized,
            correction);

        difference =
            normalized;

        residual =
            correction;
    }

    /*
     * GeographicLib fixes signs at 0 and +/-pi using the exact-difference
     * direction represented by the correction when present.
     */
    if (
        difference == cast(W) 0
        || fabs(difference) == p)
    {
        difference =
            copysign(
                difference,
                residual == cast(W) 0
                    ? longitude2 - longitude1
                    : -residual);
    }

    return difference;
}


/**
 * Compute sin/cos(lambda + correction) while retaining cardinal exactness.
 *
 * lambda is in [0,pi].  The base angle is reduced to the nearest quadrant
 * before the residual is added, mirroring GeographicLib sincosde.
 */
private void sinCosLongitudeDifference(W)(
    const W lambda,
    const W correction,
    out W sine,
    out W cosine)
    pure nothrow @safe @nogc
{
    const W p =
        pi!W;

    const W hp =
        halfPi!W;

    const W qp =
        p / cast(W) 4;

    int quadrant;

    if (lambda <= qp)
        quadrant = 0;
    else if (lambda < cast(W) 3 * qp)
        quadrant = 1;
    else
        quadrant = 2;

    W reduced =
        lambda
        - cast(W) quadrant * hp;

    /*
     * Keep the correction visible even when it is too small to affect lambda
     * itself.
     */
    reduced =
        angleRound(
            reduced
            + correction);

    W s;
    W c;

    if (reduced == cast(W) 0)
    {
        s =
            copysign(
                cast(W) 0,
                reduced);

        c =
            cast(W) 1;
    }
    else if (fabs(reduced) == qp)
    {
        c =
            sqrt(cast(W) 0.5);

        s =
            copysign(
                c,
                reduced);
    }
    else
    {
        s =
            sin(reduced);

        c =
            cos(reduced);
    }

    switch (quadrant)
    {
        case 0:
            sine = s;
            cosine = c;
            break;

        case 1:
            sine = c;
            cosine = -s;
            break;

        case 2:
            sine = -s;
            cosine = -c;
            break;

        default:
            assert(0);
    }

    /*
     * Canonical positive cosine zero matches GeographicLib's +0 adjustment.
     */
    if (cosine == cast(W) 0)
        cosine =
            cast(W) 0;
}


/**
 * Compute sine and cosine of a canonical latitude with exact cardinal values
 * at zero and the poles.
 */
private void sinCosLatitude(W)(
    const W latitude,
    out W sine,
    out W cosine)
    pure nothrow @safe @nogc
{
    const W hp =
        halfPi!W;

    if (latitude == cast(W) 0)
    {
        sine =
            copysign(
                cast(W) 0,
                latitude);

        cosine =
            cast(W) 1;
    }
    else if (latitude == hp)
    {
        sine =
            cast(W) 1;

        cosine =
            cast(W) 0;
    }
    else if (latitude == -hp)
    {
        sine =
            cast(W) -1;

        cosine =
            cast(W) 0;
    }
    else
    {
        sine =
            sin(latitude);

        cosine =
            cos(latitude);
    }
}


/** Normalize a sine/cosine-style pair to unit Euclidean magnitude. */
private void normalizePair(W)(
    ref W sine,
    ref W cosine)
    pure nothrow @safe @nogc
{
    const W magnitude =
        stableHypot2(
            sine,
            cosine);

    sine /=
        magnitude;

    cosine /=
        magnitude;
}


/** Swap two working-scalar values in place. */
private void swapValues(W)(
    ref W a,
    ref W b)
    pure nothrow @safe @nogc
{
    const W temporary =
        a;

    a =
        b;

    b =
        temporary;
}


/**
 * Dispatch a finite inverse geodesic problem.
 *
 * Preconditions:
 *
 * - latitude1/latitude2 lie in [-pi/2,+pi/2];
 * - longitude1/longitude2 are finite canonical longitude values;
 * - a > 0;
 * - 0 <= f <= 0.01;
 * - all prepared ellipsoid fields and coefficient arrays match a/f/order.
 */
GeodesicInverseDispatchResult!W geodesicInverseDispatch(
    W,
    int order,
    uint outputs = 0)(
    const W a,
    const W f,
    const W f1,
    const W b,
    const W ep2,
    const W n,
    const ref W[8] a3x,
    const ref W[28] c3x,
    W latitude1,
    const W longitude1,
    W latitude2,
    const W longitude2)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    static assert(
        (
            outputs
            & ~(
                geodesicInverseReducedLength
                | geodesicInverseScales
                | geodesicInverseArea
            )
        ) == 0,
        "unsupported inverse geodesic output capability");

    enum bool calculateReducedLength =
        (outputs & geodesicInverseReducedLength) != 0;

    enum bool calculateScales =
        (outputs & geodesicInverseScales) != 0;

    enum bool calculateArea =
        (outputs & geodesicInverseArea) != 0;

    enum uint canonicalLengthOutputs =
        geodesicLengthDistance
        | (
            calculateReducedLength
                ? geodesicLengthReducedLength
                : 0
        )
        | (
            calculateScales
                ? geodesicLengthScales
                : 0
        );

    const W zero =
        cast(W) 0;

    const W one =
        cast(W) 1;

    const W p =
        pi!W;

    const W hp =
        halfPi!W;

    const W tiny =
        sqrt(W.min_normal);

    const W tolerance0 =
        W.epsilon;

    const W tolerance2 =
        sqrt(tolerance0);

    W longitudeResidual;

    W longitude12 =
        longitudeDifference(
            longitude1,
            longitude2,
            longitudeResidual);

    int longitudeSign =
        signbit(longitude12)
            ? -1
            : 1;

    longitude12 *=
        cast(W) longitudeSign;

    longitudeResidual *=
        cast(W) longitudeSign;

    W sinLongitude12;
    W cosLongitude12;

    sinCosLongitudeDifference(
        longitude12,
        longitudeResidual,
        sinLongitude12,
        cosLongitude12);

    const W supplementaryLongitude12 =
        (p - longitude12)
        - longitudeResidual;

    latitude1 =
        angleRound(latitude1);

    latitude2 =
        angleRound(latitude2);

    /*
     * Put the endpoint with larger |latitude| first.
     */
    int swapSign =
        fabs(latitude1) < fabs(latitude2)
            ? -1
            : 1;

    if (swapSign < 0)
    {
        longitudeSign *=
            -1;

        swapValues(
            latitude1,
            latitude2);
    }

    /*
     * Force latitude1 <= -0.  signbit matters for exact zero.
     */
    const int latitudeSign =
        signbit(latitude1)
            ? 1
            : -1;

    latitude1 *=
        cast(W) latitudeSign;

    latitude2 *=
        cast(W) latitudeSign;

    W sinPhi1;
    W cosPhi1;
    W sinPhi2;
    W cosPhi2;

    sinCosLatitude(
        latitude1,
        sinPhi1,
        cosPhi1);

    sinCosLatitude(
        latitude2,
        sinPhi2,
        cosPhi2);

    W sinBeta1 =
        f1 * sinPhi1;

    W cosBeta1 =
        cosPhi1;

    W sinBeta2 =
        f1 * sinPhi2;

    W cosBeta2 =
        cosPhi2;

    normalizePair(
        sinBeta1,
        cosBeta1);

    normalizePair(
        sinBeta2,
        cosBeta2);

    if (cosBeta1 < tiny)
        cosBeta1 =
            tiny;

    if (cosBeta2 < tiny)
        cosBeta2 =
            tiny;

    /*
     * Preserve exact beta symmetry in the numerically sensitive comparison
     * selected by Lambda12.
     */
    if (cosBeta1 < -sinBeta1)
    {
        if (cosBeta2 == cosBeta1)
            sinBeta2 =
                copysign(
                    sinBeta1,
                    sinBeta2);
    }
    else
    {
        if (fabs(sinBeta2) == -sinBeta1)
            cosBeta2 =
                cosBeta1;
    }

    const W dn1 =
        sqrt(
            one
            + ep2
                * sinBeta1
                * sinBeta1);

    const W dn2 =
        sqrt(
            one
            + ep2
                * sinBeta2
                * sinBeta2);

    W distance =
        zero;

    W sigma12 =
        zero;

    W sinAlpha1 =
        zero;

    W cosAlpha1 =
        one;

    W sinAlpha2 =
        zero;

    W cosAlpha2 =
        one;

    W sinOmega12 =
        zero;

    W cosOmega12 =
        one;

    W reducedLength =
        zero;

    W scale12 =
        zero;

    W scale21 =
        zero;

    W signedArea =
        zero;

    uint iterations =
        0;

    GeodesicInverseDispatchKind kind =
        GeodesicInverseDispatchKind.meridian;

    GeodesicInverseStartKind startKind =
        GeodesicInverseStartKind.none;

    uint bracketMidpointCount =
        0;

    bool converged =
        true;

    bool meridian =
        latitude1 == -hp
        || sinLongitude12 == zero;

    if (meridian)
    {
        /*
         * The geodesic might lie on one full meridian.
         */
        cosAlpha1 =
            cosLongitude12;

        sinAlpha1 =
            sinLongitude12;

        cosAlpha2 =
            one;

        sinAlpha2 =
            zero;

        const W sinSigma1 =
            sinBeta1;

        const W cosSigma1 =
            cosAlpha1
            * cosBeta1;

        const W sinSigma2 =
            sinBeta2;

        const W cosSigma2 =
            cosAlpha2
            * cosBeta2;

        W cross =
            cosSigma1 * sinSigma2
            - sinSigma1 * cosSigma2;

        if (cross < zero)
            cross =
                zero;

        sigma12 =
            atan2(
                cross + zero,
                cosSigma1 * cosSigma2
                    + sinSigma1 * sinSigma2);

        enum uint meridianLengthOutputs =
            geodesicLengthDistance
            | geodesicLengthReducedLength
            | (
                calculateScales
                    ? geodesicLengthScales
                    : 0
            );

        const lengths =
            geodesicLengths!(
                W,
                order,
                meridianLengthOutputs)(
                    n,
                    ep2,
                    sigma12,
                    sinSigma1,
                    cosSigma1,
                    dn1,
                    cosBeta1,
                    sinSigma2,
                    cosSigma2,
                    dn2,
                    cosBeta2);

        W s12b =
            lengths.s12b;

        W m12b =
            lengths.m12b;

        /*
         * For the supported oblate-only domain this branch is accepted.  Keep
         * GeographicLib's guard nevertheless so the invariant remains local
         * if the support domain is widened later.
         */
        if (
            sigma12 < tolerance2
            || m12b >= zero)
        {
            if (
                sigma12
                    < cast(W) 3 * tiny
                || (
                    sigma12 < tolerance0
                    && (
                        s12b < zero
                        || m12b < zero
                    )
                ))
            {
                sigma12 =
                    zero;

                s12b =
                    zero;
            }

            distance =
                b * s12b;

            static if (calculateReducedLength)
            {
                reducedLength =
                    b * m12b;
            }

            static if (calculateScales)
            {
                scale12 =
                    lengths.M12;

                scale21 =
                    lengths.M21;
            }

            kind =
                GeodesicInverseDispatchKind.meridian;
        }
        else
        {
            meridian =
                false;
        }
    }

    if (
        !meridian
        && sinBeta1 == zero
        && (
            f <= zero
            || supplementaryLongitude12
                >= f * p
        ))
    {
        /*
         * Exact equatorial geodesic.
         */
        cosAlpha1 =
            zero;

        sinAlpha1 =
            one;

        cosAlpha2 =
            zero;

        sinAlpha2 =
            one;

        distance =
            a * longitude12;

        sigma12 =
            longitude12
            / f1;

        static if (calculateReducedLength)
        {
            reducedLength =
                b * sin(sigma12);
        }

        static if (calculateScales)
        {
            const W scale =
                cos(sigma12);

            scale12 =
                scale;

            scale21 =
                scale;
        }

        sinOmega12 =
            sin(sigma12);

        cosOmega12 =
            cos(sigma12);

        kind =
            GeodesicInverseDispatchKind.equator;
    }
    else if (!meridian)
    {
        const general =
            geodesicCanonicalInverse!(
                W,
                order,
                canonicalLengthOutputs)(
                    f,
                    f1,
                    ep2,
                    n,
                    a3x,
                    c3x,
                    sinBeta1,
                    cosBeta1,
                    dn1,
                    sinBeta2,
                    cosBeta2,
                    dn2,
                    longitude12,
                    sinLongitude12,
                    cosLongitude12);

        distance =
            b * general.s12b;

        static if (calculateReducedLength)
        {
            reducedLength =
                b * general.m12b;
        }

        static if (calculateScales)
        {
            scale12 =
                general.M12;

            scale21 =
                general.M21;
        }

        sigma12 =
            general.sigma12;

        sinAlpha1 =
            general.sinAlpha1;

        cosAlpha1 =
            general.cosAlpha1;

        sinAlpha2 =
            general.sinAlpha2;

        cosAlpha2 =
            general.cosAlpha2;

        sinOmega12 =
            general.sinOmega12;

        cosOmega12 =
            general.cosOmega12;

        iterations =
            general.iterations;

        startKind =
            general.startKind;

        bracketMidpointCount =
            general.bracketMidpointCount;

        converged =
            general.converged;

        kind =
            general.shortLine
                ? GeodesicInverseDispatchKind.generalShort
                : GeodesicInverseDispatchKind.generalNewton;
    }

    static if (calculateArea)
    {
        if (distance != zero)
        {
            const W e2 =
                f
                * (cast(W) 2 - f);

            W[36] c4x;

            fillGeodesicC4x!(
                W,
                order)(
                    n,
                    c4x);

            const W authalicRadiusSquared =
                geodesicAuthalicRadiusSquared(
                    a,
                    b,
                    e2);

            signedArea =
                geodesicSignedArea!(
                    W,
                    order)(
                        a,
                        e2,
                        ep2,
                        authalicRadiusSquared,
                        c4x,
                        sinBeta1,
                        cosBeta1,
                        sinBeta2,
                        cosBeta2,
                        sinAlpha1,
                        cosAlpha1,
                        sinAlpha2,
                        cosAlpha2,
                        meridian,
                        sinOmega12,
                        cosOmega12,
                        swapSign
                            * longitudeSign
                            * latitudeSign);
        }
    }

    /*
     * Restore the original endpoint order and signs.
     */
    if (swapSign < 0)
    {
        swapValues(
            sinAlpha1,
            sinAlpha2);

        swapValues(
            cosAlpha1,
            cosAlpha2);

        static if (calculateScales)
        {
            swapValues(
                scale12,
                scale21);
        }
    }

    sinAlpha1 *=
        cast(W) (
            swapSign
            * longitudeSign
        );

    cosAlpha1 *=
        cast(W) (
            swapSign
            * latitudeSign
        );

    sinAlpha2 *=
        cast(W) (
            swapSign
            * longitudeSign
        );

    cosAlpha2 *=
        cast(W) (
            swapSign
            * latitudeSign
        );

    distance =
        canonicalZero(distance);

    /*
     * GEO-A inverse coincidence semantics deliberately choose a unique public
     * result even though azimuth is geometrically indeterminate.
     */
    if (distance == zero)
    {
        return GeodesicInverseDispatchResult!W(
            zero,
            zero,
            calculateScales ? one : zero,
            calculateScales ? one : zero,
            zero,
            zero,
            zero,
            zero,
            0,
            GeodesicInverseDispatchKind.coincidence,
            GeodesicInverseStartKind.none,
            0,
            true);
    }

    const W initialAzimuth =
        canonicalAngle(
            atan2(
                sinAlpha1,
                cosAlpha1));

    const W finalAzimuth =
        canonicalAngle(
            atan2(
                sinAlpha2,
                cosAlpha2));

    return GeodesicInverseDispatchResult!W(
        distance,
        reducedLength,
        scale12,
        scale21,
        initialAzimuth,
        finalAzimuth,
        sigma12,
        signedArea,
        iterations,
        kind,
        startKind,
        bracketMidpointCount,
        converged);
}


unittest
{
    import std.math :
        PI,
        fabs;

    import std.meta :
        AliasSeq;

    import geodesy.internal.geodesic_series :
        fillGeodesicA3x,
        fillGeodesicC3x;

    struct Prepared
    {
        double a;
        double f;
        double f1;
        double b;
        double ep2;
        double n;
        double[8] a3x;
        double[28] c3x;
    }

    Prepared prepare(
        const double a,
        const double f,
        const int order)
    {
        Prepared result;

        result.a =
            a;

        result.f =
            f;

        result.f1 =
            1.0 - f;

        result.b =
            a * result.f1;

        const double e2 =
            f * (2.0 - f);

        result.ep2 =
            e2
            / (
                result.f1
                * result.f1
            );

        result.n =
            f / (2.0 - f);

        switch (order)
        {
            case 6:
                fillGeodesicA3x!(
                    double,
                    6)(
                        result.n,
                        result.a3x);

                fillGeodesicC3x!(
                    double,
                    6)(
                        result.n,
                        result.c3x);
                break;

            case 7:
                fillGeodesicA3x!(
                    double,
                    7)(
                        result.n,
                        result.a3x);

                fillGeodesicC3x!(
                    double,
                    7)(
                        result.n,
                        result.c3x);
                break;

            case 8:
                fillGeodesicA3x!(
                    double,
                    8)(
                        result.n,
                        result.a3x);

                fillGeodesicC3x!(
                    double,
                    8)(
                        result.n,
                        result.c3x);
                break;

            default:
                assert(0);
        }

        return result;
    }

    /*
     * GEO-A coincidence is uniquely all +0.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.4,
                    1.2,
                    0.4,
                    1.2);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.coincidence);

        assert(result.distance == 0.0);
        assert(result.initialAzimuth == 0.0);
        assert(result.finalAzimuth == 0.0);

        assert(
            !signbit(result.distance));

        assert(
            !signbit(result.initialAzimuth));

        assert(
            !signbit(result.finalAzimuth));
    }

    /*
     * +/-pi longitude spellings represent the same meridian and therefore the
     * same point for equal latitude.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.3,
                    cast(double) PI,
                    0.3,
                    -cast(double) PI);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.coincidence);
    }

    /*
     * All longitudes at one geographic pole are coincident.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const hp =
            cast(double) PI / 2.0;

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    hp,
                    -2.0,
                    hp,
                    1.0);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.coincidence);

        assert(result.distance == 0.0);
        assert(result.initialAzimuth == 0.0);
        assert(result.finalAzimuth == 0.0);
    }

    /*
     * Equatorial branch: distance is exactly a * delta-lambda and both forward
     * azimuths point east in canonical orientation.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.0,
                    0.0,
                    0.0,
                    1.0);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.equator);

        assert(
            fabs(
                result.distance
                - state.a)
            < 1e-6);

        assert(
            fabs(
                result.initialAzimuth
                - cast(double) PI / 2.0)
            < 1e-15);

        assert(
            fabs(
                result.finalAzimuth
                - cast(double) PI / 2.0)
            < 1e-15);
    }

    /*
     * Ordinary meridian.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    -0.4,
                    0.7,
                    0.2,
                    0.7);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.meridian);

        assert(result.distance > 0.0);

        assert(
            fabs(result.initialAzimuth)
            < 1e-15);

        assert(
            fabs(result.finalAzimuth)
            < 1e-15);
    }

    /*
     * Representative general WGS84 problem.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const result =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    -0.7,
                    0.0,
                    0.25,
                    1.5);

        assert(
            result.kind
                == GeodesicInverseDispatchKind.generalNewton
            || result.kind
                == GeodesicInverseDispatchKind.generalShort);

        assert(result.distance > 0.0);
        assert(result.sigma12 > 0.0);
    }

    /*
     * Reversal symmetry for an unambiguous general geodesic:
     *
     * inverse(B,A).azi1 == inverse(A,B).azi2 + pi
     * inverse(B,A).azi2 == inverse(A,B).azi1 + pi
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const forward =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    -0.55,
                    -0.3,
                    0.2,
                    1.1);

        const reverse =
            geodesicInverseDispatch!(
                double,
                6)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.2,
                    1.1,
                    -0.55,
                    -0.3);

        assert(
            fabs(
                forward.distance
                - reverse.distance)
            < 1e-7);

        assert(
            fabs(
                canonicalAngle(
                    reverse.initialAzimuth
                    - (
                        forward.finalAzimuth
                        + cast(double) PI
                    )))
            < 2e-14);

        assert(
            fabs(
                canonicalAngle(
                    reverse.finalAzimuth
                    - (
                        forward.initialAzimuth
                        + cast(double) PI
                    )))
            < 2e-14);
    }

    /*
     * Explicit area capability: coincidence and equatorial geodesics have
     * canonical zero signed area.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const coincident =
            geodesicInverseDispatch!(
                double,
                6,
                geodesicInverseArea)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.4,
                    1.2,
                    0.4,
                    1.2);

        assert(coincident.signedArea == 0.0);
        assert(!signbit(coincident.signedArea));

        const equator =
            geodesicInverseDispatch!(
                double,
                6,
                geodesicInverseArea)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.0,
                    0.0,
                    0.0,
                    1.0);

        assert(equator.signedArea == 0.0);
        assert(!signbit(equator.signedArea));
    }

    /*
     * Signed area is antisymmetric when the oriented geodesic endpoints are
     * reversed.
     */
    {
        const state =
            prepare(
                6_378_137.0,
                1.0 / 298.257223563,
                6);

        const forward =
            geodesicInverseDispatch!(
                double,
                6,
                geodesicInverseArea)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    -0.55,
                    -0.3,
                    0.2,
                    1.1);

        const reverse =
            geodesicInverseDispatch!(
                double,
                6,
                geodesicInverseArea)(
                    state.a,
                    state.f,
                    state.f1,
                    state.b,
                    state.ep2,
                    state.n,
                    state.a3x,
                    state.c3x,
                    0.2,
                    1.1,
                    -0.55,
                    -0.3);

        assert(forward.signedArea != 0.0);

        const double scale =
            fabs(forward.signedArea) > 1.0
                ? fabs(forward.signedArea)
                : 1.0;

        assert(
            fabs(
                forward.signedArea
                + reverse.signedArea)
            <= 32.0
                * double.epsilon
                * scale);
    }

    /*
     * Instantiate all supported series orders through the dispatcher.
     */
    static foreach (
        order;
        AliasSeq!(6, 7, 8))
    {
        {
            const state =
                prepare(
                    7_000_000.0,
                    0.005,
                    order);

            const result =
                geodesicInverseDispatch!(
                    double,
                    order)(
                        state.a,
                        state.f,
                        state.f1,
                        state.b,
                        state.ep2,
                        state.n,
                        state.a3x,
                        state.c3x,
                        -0.45,
                        -0.2,
                        0.1,
                        1.05);

            assert(result.distance > 0.0);
        }
    }
}
