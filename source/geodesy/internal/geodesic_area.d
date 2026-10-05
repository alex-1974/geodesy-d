/**
 * Internal Karney geodesic signed-area evaluation.
 *
 * This module evaluates S12 from an already solved canonical geodesic state.
 * C4 preparation is deliberately supplied by the caller so ordinary geodesic
 * operations do not carry the area-series storage cost.
 *
 * The formulation follows GeographicLib 2.7 Geodesic::GenInverse.
 */
module geodesy.internal.geodesic_area;

import std.math :
    atan2,
    atanh,
    sqrt;

import geodesy.internal.geodesic_area_series :
    fillGeodesicC4;

import geodesy.internal.geodesic_series :
    geodesicSinCosSeries;

import geodesy.internal.hypot_compat :
    stableHypot2;


package(geodesy):


/**
 * Compute the authalic-radius-squared factor used by Karney's S12 formula.
 *
 * The supported geodesy-d ellipsoid domain is spherical or oblate, so e2 is
 * non-negative.
 */
W geodesicAuthalicRadiusSquared(W)(
    const W a,
    const W b,
    const W e2)
    pure nothrow @safe @nogc
{
    if (e2 == cast(W) 0)
        return a * a;

    const W e =
        sqrt(e2);

    return (
        a * a
        + b * b
            * atanh(e)
            / e
    ) / cast(W) 2;
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


/**
 * Evaluate signed area S12 for a canonical solved geodesic state.
 *
 * Params:
 *   a = ellipsoid semi-major axis.
 *   e2 = first eccentricity squared.
 *   ep2 = second eccentricity squared.
 *   authalicRadiusSquared = precomputed authalic radius squared.
 *   c4x = prepared ellipsoid-dependent C4 polynomial table.
 *   sinBeta1, cosBeta1 = reduced latitude at point 1.
 *   sinBeta2, cosBeta2 = reduced latitude at point 2.
 *   sinAlpha1, cosAlpha1 = canonical forward azimuth at point 1.
 *   sinAlpha2, cosAlpha2 = canonical forward azimuth at point 2.
 *   meridian = whether the canonical solution lies on a meridian.
 *   sinOmega12, cosOmega12 = omega12 pair when the non-meridian stable
 *       half-angle branch is available.
 *   orientationSign = product of inverse-dispatch swap/longitude/latitude
 *       restoration signs; must be +1 or -1.
 *
 * Returns:
 *   Signed area in the square of the semi-major-axis linear unit.
 */
W geodesicSignedArea(
    W,
    int order)(
    const W a,
    const W e2,
    const W ep2,
    const W authalicRadiusSquared,
    const ref W[36] c4x,
    const W sinBeta1,
    const W cosBeta1,
    const W sinBeta2,
    const W cosBeta2,
    const W sinAlpha1,
    const W cosAlpha1,
    const W sinAlpha2,
    const W cosAlpha2,
    const bool meridian,
    const W sinOmega12,
    const W cosOmega12,
    const int orientationSign)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    assert(
        orientationSign == 1
        || orientationSign == -1);

    const W zero =
        cast(W) 0;

    const W one =
        cast(W) 1;

    const W sinAlpha0 =
        sinAlpha1
        * cosBeta1;

    const W cosAlpha0 =
        stableHypot2(
            cosAlpha1,
            sinAlpha1 * sinBeta1);

    W area =
        zero;

    if (
        cosAlpha0 != zero
        && sinAlpha0 != zero)
    {
        W sinSigma1 =
            sinBeta1;

        W cosSigma1 =
            cosAlpha1
            * cosBeta1;

        W sinSigma2 =
            sinBeta2;

        W cosSigma2 =
            cosAlpha2
            * cosBeta2;

        normalizePair(
            sinSigma1,
            cosSigma1);

        normalizePair(
            sinSigma2,
            cosSigma2);

        const W k2 =
            cosAlpha0
            * cosAlpha0
            * ep2;

        const W eps =
            k2
            / (
                cast(W) 2
                * (
                    one
                    + sqrt(one + k2)
                )
                + k2
            );

        const W a4 =
            a * a
            * cosAlpha0
            * sinAlpha0
            * e2;

        W[9] c4;

        fillGeodesicC4!(
            W,
            order)(
                eps,
                c4x,
                c4);

        const W b41 =
            geodesicSinCosSeries!W(
                false,
                sinSigma1,
                cosSigma1,
                c4,
                order);

        const W b42 =
            geodesicSinCosSeries!W(
                false,
                sinSigma2,
                cosSigma2,
                c4,
                order);

        area =
            a4
            * (b42 - b41);
    }

    W alpha12;

    if (
        !meridian
        && cosOmega12 > cast(W) -0.7071
        && sinBeta2 - sinBeta1 < cast(W) 1.75)
    {
        const W deltaOmega =
            one
            + cosOmega12;

        const W deltaBeta1 =
            one
            + cosBeta1;

        const W deltaBeta2 =
            one
            + cosBeta2;

        alpha12 =
            cast(W) 2
            * atan2(
                sinOmega12
                    * (
                        sinBeta1 * deltaBeta2
                        + sinBeta2 * deltaBeta1
                    ),
                deltaOmega
                    * (
                        sinBeta1 * sinBeta2
                        + deltaBeta1 * deltaBeta2
                    ));
    }
    else
    {
        W sinAlpha12 =
            sinAlpha2 * cosAlpha1
            - cosAlpha2 * sinAlpha1;

        W cosAlpha12 =
            cosAlpha2 * cosAlpha1
            + sinAlpha2 * sinAlpha1;

        if (
            sinAlpha12 == zero
            && cosAlpha12 < zero)
        {
            sinAlpha12 =
                sqrt(W.min_normal)
                * cosAlpha1;

            cosAlpha12 =
                -one;
        }

        alpha12 =
            atan2(
                sinAlpha12,
                cosAlpha12);
    }

    area +=
        authalicRadiusSquared
        * alpha12;

    area *=
        cast(W) orientationSign;

    return area == zero
        ? zero
        : area;
}


unittest
{
    import std.math :
        cos,
        sin;

    enum double radius =
        6_371_000.0;

    assert(
        geodesicAuthalicRadiusSquared(
            radius,
            radius,
            0.0)
        == radius * radius);

    double[36] c4x;

    /*
     * Equatorial spherical segment: alpha is constant eastward and the
     * geodesic bounds zero signed area with the equator.
     */
    const equator =
        geodesicSignedArea!(
            double,
            6)(
                radius,
                0.0,
                0.0,
                radius * radius,
                c4x,
                0.0,
                1.0,
                0.0,
                1.0,
                1.0,
                0.0,
                1.0,
                0.0,
                false,
                sin(0.5),
                cos(0.5),
                1);

    assert(equator == 0.0);

    /*
     * A spherical meridian segment likewise contributes zero area.
     */
    const meridian =
        geodesicSignedArea!(
            double,
            6)(
                radius,
                0.0,
                0.0,
                radius * radius,
                c4x,
                sin(-0.3),
                cos(-0.3),
                sin(0.4),
                cos(0.4),
                0.0,
                1.0,
                0.0,
                1.0,
                true,
                0.0,
                1.0,
                1);

    assert(meridian == 0.0);
}
