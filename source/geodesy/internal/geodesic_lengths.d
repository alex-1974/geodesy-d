/**
 * Internal Karney geodesic length-series evaluation.
 *
 * This module evaluates the quantities needed by the inverse geodesic
 * solver:
 *
 * - distance divided by the polar semi-axis b;
 * - reduced length divided by b;
 * - the secular reduced-length coefficient m0;
 * - geodesic scales M12 and M21.
 *
 * The formulas follow GeographicLib 2.7 Geodesic::Lengths.  Output
 * selection is a compile-time concern so callers pay only for the quantity
 * families they instantiate.
 */
module geodesy.internal.geodesic_lengths;

import geodesy.internal.geodesic_series :
    fillGeodesicC1,
    fillGeodesicC2,
    geodesicA1m1,
    geodesicA2m1,
    geodesicSinCosSeries;


package(geodesy):


/*
 * Compile-time output capabilities for geodesicLengths.
 *
 * These are deliberately internal implementation constants, not a public
 * runtime mask API.  They allow the D compiler to erase unused quantity
 * families with static if.
 */
enum uint geodesicLengthDistance =
    1u << 0;

enum uint geodesicLengthReducedLength =
    1u << 1;

enum uint geodesicLengthScales =
    1u << 2;


struct GeodesicLengthsResult(W)
{
    /// Geodesic distance divided by b. Zero when not requested.
    W s12b;

    /// Reduced length divided by b.
    W m12b;

    /// Secular reduced-length coefficient.
    W m0;

    /// Forward geodesic scale from point 1 to point 2.
    W M12;

    /// Reverse geodesic scale from point 2 to point 1.
    W M21;
}


/**
 * Evaluate Karney's I1/I2 length series.
 *
 * Params:
 *   eps = Karney epsilon for the geodesic.
 *   ep2 = second eccentricity squared.
 *   sigma12 = sigma2 - sigma1.
 *   sinSigma1 = sin(sigma1).
 *   cosSigma1 = cos(sigma1).
 *   dn1 = sqrt(1 + ep2 * sin(beta1)^2).
 *   cosBeta1 = cos(beta1).
 *   sinSigma2 = sin(sigma2).
 *   cosSigma2 = cos(sigma2).
 *   dn2 = sqrt(1 + ep2 * sin(beta2)^2).
 *   cosBeta2 = cos(beta2).
 *
 * Template Params:
 *   W = working floating-point type.
 *   order = Karney series order, 6 through 8.
 *   outputs = bitwise combination of the internal compile-time
 *       geodesicLength* capability constants.
 */
GeodesicLengthsResult!W geodesicLengths(
    W,
    int order,
    uint outputs)(
    const W eps,
    const W ep2,
    const W sigma12,
    const W sinSigma1,
    const W cosSigma1,
    const W dn1,
    const W cosBeta1,
    const W sinSigma2,
    const W cosSigma2,
    const W dn2,
    const W cosBeta2)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    enum bool calculateDistance =
        (outputs & geodesicLengthDistance) != 0;

    enum bool calculateReducedLength =
        (outputs & geodesicLengthReducedLength) != 0;

    enum bool calculateScales =
        (outputs & geodesicLengthScales) != 0;

    static assert(
        (
            outputs
            & ~(
                geodesicLengthDistance
                | geodesicLengthReducedLength
                | geodesicLengthScales
            )
        ) == 0,
        "unsupported geodesic length output capability");

    W[9] c1;
    W[9] c2;

    W a1 =
        cast(W) 0;

    W a2 =
        cast(W) 0;

    W m0 =
        cast(W) 0;

    static if (
        calculateDistance
        || calculateReducedLength
        || calculateScales)
    {
        const W a1m1 =
            geodesicA1m1!(W, order)(eps);

        fillGeodesicC1!(W, order)(
            eps,
            c1);

        a1 =
            cast(W) 1
            + a1m1;

        static if (
            calculateReducedLength
            || calculateScales)
        {
            const W a2m1 =
                geodesicA2m1!(W, order)(eps);

            fillGeodesicC2!(W, order)(
                eps,
                c2);

            a2 =
                cast(W) 1
                + a2m1;

            m0 =
                a1m1
                - a2m1;
        }
    }

    W s12b =
        cast(W) 0;

    W j12 =
        cast(W) 0;

    static if (calculateDistance)
    {
        const W b1 =
            geodesicSinCosSeries(
                true,
                sinSigma2,
                cosSigma2,
                c1,
                order)
            - geodesicSinCosSeries(
                true,
                sinSigma1,
                cosSigma1,
                c1,
                order);

        s12b =
            a1 * (sigma12 + b1);

        static if (
            calculateReducedLength
            || calculateScales)
        {
            const W b2 =
                geodesicSinCosSeries(
                    true,
                    sinSigma2,
                    cosSigma2,
                    c2,
                    order)
                - geodesicSinCosSeries(
                    true,
                    sinSigma1,
                    cosSigma1,
                    c2,
                    order);

            j12 =
                m0 * sigma12
                + (a1 * b1 - a2 * b2);
        }
    }
    else static if (
        calculateReducedLength
        || calculateScales)
    {
        /*
         * When distance is not required, combine A1*C1 - A2*C2
         * first. This is the reduced-length/geodesic-scale-only path used by
         * the inverse Newton derivative and future selected-output callers.
         */
        W[9] combined;

        foreach (l; 1 .. order + 1)
            combined[l] =
                a1 * c1[l]
                - a2 * c2[l];

        j12 =
            m0 * sigma12
            + (
                geodesicSinCosSeries(
                    true,
                    sinSigma2,
                    cosSigma2,
                    combined,
                    order)
                - geodesicSinCosSeries(
                    true,
                    sinSigma1,
                    cosSigma1,
                    combined,
                    order)
            );
    }

    W m12b =
        cast(W) 0;

    static if (calculateReducedLength)
    {
        /*
         * Parentheses around the first two products are intentional.
         * They preserve accurate cancellation for coincident points.
         */
        m12b =
            dn2 * (cosSigma1 * sinSigma2)
            - dn1 * (sinSigma1 * cosSigma2)
            - cosSigma1 * cosSigma2 * j12;
    }

    W M12 =
        cast(W) 0;

    W M21 =
        cast(W) 0;

    static if (calculateScales)
    {
        const W cosSigma12 =
            cosSigma1 * cosSigma2
            + sinSigma1 * sinSigma2;

        const W t =
            ep2
            * (cosBeta1 - cosBeta2)
            * (cosBeta1 + cosBeta2)
            / (dn1 + dn2);

        M12 =
            cosSigma12
            + (
                t * sinSigma2
                - cosSigma2 * j12
            ) * sinSigma1
                / dn1;

        M21 =
            cosSigma12
            - (
                t * sinSigma1
                - cosSigma1 * j12
            ) * sinSigma2
                / dn2;
    }

    return GeodesicLengthsResult!W(
        s12b,
        m12b,
        m0,
        M12,
        M21);
}

unittest
{
    import std.math : cos, sin;

    /*
     * On a sphere eps = 0:
     *
     *     A1 = A2 = 1
     *     C1 = C2 = 0
     *     m0 = J12 = 0
     *
     * and therefore
     *
     *     s12 / b = sigma12
     *     m12 / b = sin(sigma12).
     */
    enum double sigma1 = 0.4;
    enum double sigma12 = 0.75;
    enum double sigma2 = sigma1 + sigma12;

    const withDistance =
        geodesicLengths!(double, 6, geodesicLengthDistance | geodesicLengthReducedLength | geodesicLengthScales)(
            0.0,
            0.0,
            sigma12,
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1),
            sin(sigma2),
            cos(sigma2),
            1.0,
            cos(sigma2));

    assert(
        withDistance.s12b > sigma12 - 1e-14
        && withDistance.s12b < sigma12 + 1e-14);

    assert(
        withDistance.m12b > sin(sigma12) - 1e-14
        && withDistance.m12b < sin(sigma12) + 1e-14);

    assert(withDistance.m0 == 0.0);

    assert(
        withDistance.M12 > cos(sigma12) - 1e-14
        && withDistance.M12 < cos(sigma12) + 1e-14);

    assert(
        withDistance.M21 > cos(sigma12) - 1e-14
        && withDistance.M21 < cos(sigma12) + 1e-14);

    const reducedOnly =
        geodesicLengths!(double, 6, geodesicLengthReducedLength)(
            0.0,
            0.0,
            sigma12,
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1),
            sin(sigma2),
            cos(sigma2),
            1.0,
            cos(sigma2));

    assert(reducedOnly.s12b == 0.0);

    assert(
        reducedOnly.m12b > sin(sigma12) - 1e-14
        && reducedOnly.m12b < sin(sigma12) + 1e-14);

    assert(reducedOnly.m0 == 0.0);
    assert(reducedOnly.M12 == 0.0);
    assert(reducedOnly.M21 == 0.0);

    const coincident =
        geodesicLengths!(double, 6, geodesicLengthDistance | geodesicLengthReducedLength | geodesicLengthScales)(
            0.0,
            0.0,
            0.0,
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1),
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1));

    assert(coincident.s12b == 0.0);
    assert(coincident.m12b == 0.0);
    assert(coincident.m0 == 0.0);
    assert(coincident.M12 == 1.0);
    assert(coincident.M21 == 1.0);

    /*
     * Compile and smoke-test the higher precision policies too.
     */
    const order7 =
        geodesicLengths!(double, 7, geodesicLengthDistance | geodesicLengthReducedLength | geodesicLengthScales)(
            0.0,
            0.0,
            sigma12,
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1),
            sin(sigma2),
            cos(sigma2),
            1.0,
            cos(sigma2));

    const order8 =
        geodesicLengths!(double, 8, geodesicLengthDistance | geodesicLengthReducedLength | geodesicLengthScales)(
            0.0,
            0.0,
            sigma12,
            sin(sigma1),
            cos(sigma1),
            1.0,
            cos(sigma1),
            sin(sigma2),
            cos(sigma2),
            1.0,
            cos(sigma2));

    assert(
        order7.s12b > sigma12 - 1e-14
        && order7.s12b < sigma12 + 1e-14);

    assert(
        order8.s12b > sigma12 - 1e-14
        && order8.s12b < sigma12 + 1e-14);

    assert(
        order7.m12b > sin(sigma12) - 1e-14
        && order7.m12b < sin(sigma12) + 1e-14);

    assert(
        order8.m12b > sin(sigma12) - 1e-14
        && order8.m12b < sin(sigma12) + 1e-14);

    assert(
        order7.M12 > cos(sigma12) - 1e-14
        && order7.M12 < cos(sigma12) + 1e-14);

    assert(
        order7.M21 > cos(sigma12) - 1e-14
        && order7.M21 < cos(sigma12) + 1e-14);

    assert(
        order8.M12 > cos(sigma12) - 1e-14
        && order8.M12 < cos(sigma12) + 1e-14);

    assert(
        order8.M21 > cos(sigma12) - 1e-14
        && order8.M21 < cos(sigma12) + 1e-14);
}
