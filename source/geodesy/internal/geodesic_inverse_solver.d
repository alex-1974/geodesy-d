/**
 * Internal canonical inverse solver for Karney geodesics.
 *
 * This module solves the canonical, non-meridional, non-equatorial inverse
 * problem.  It owns the safeguarded Newton iteration and bracketing logic,
 * while public-coordinate canonicalization and special-case dispatch remain
 * outside this layer.
 *
 * The implementation follows GeographicLib 2.7.
 */
module geodesy.internal.geodesic_inverse_solver;

import std.math :
    PI,
    cos,
    fabs,
    hypot,
    sin,
    sqrt;

import geodesy.internal.geodesic_inverse_start :
    GeodesicInverseStartKind,
    geodesicInverseStart;

import geodesy.internal.geodesic_lambda12 :
    GeodesicLambda12Result,
    geodesicLambda12;

import geodesy.internal.geodesic_lengths :
    geodesicLengths;


package(geodesy):


private void normalizePair(W)(
    ref W sine,
    ref W cosine)
    pure nothrow @safe @nogc
{
    const W magnitude =
        hypot(
            sine,
            cosine);

    sine /= magnitude;
    cosine /= magnitude;
}


/**
 * Result of the canonical inverse solver.
 *
 * Linear quantities remain normalized by the polar semiaxis b.
 */
struct GeodesicCanonicalInverseResult(W)
{
    W s12b;

    W sigma12;

    W sinAlpha1;
    W cosAlpha1;

    W sinAlpha2;
    W cosAlpha2;

    W eps;
    W deltaOmega12;

    uint iterations;

    bool shortLine;

    GeodesicInverseStartKind startKind;

    uint bracketMidpointCount;

    bool converged;
}


/**
 * Solve a canonical inverse problem that has already been classified as
 * neither meridional nor equatorial.
 *
 * Preconditions:
 *
 * - beta1/beta2 are in GeographicLib's canonical inverse domain;
 * - lambda12 is in [0, pi];
 * - dn1/dn2 correspond to the supplied reduced latitudes;
 * - 0 <= f <= 0.01;
 * - a3x/c3x belong to the same ellipsoid and series order.
 */
GeodesicCanonicalInverseResult!W geodesicCanonicalInverse(
    W,
    int order)(
    const W f,
    const W f1,
    const W ep2,
    const W n,
    const ref W[8] a3x,
    const ref W[28] c3x,
    const W sinBeta1,
    const W cosBeta1,
    const W dn1,
    const W sinBeta2,
    const W cosBeta2,
    const W dn2,
    const W lambda12,
    const W sinLambda12,
    const W cosLambda12)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    enum uint maxNewtonIterations = 20;
    enum uint maxIterations =
        maxNewtonIterations
        + W.mant_dig
        + 10;

    const W zero =
        cast(W) 0;

    const W one =
        cast(W) 1;

    const W pi =
        cast(W) PI;

    const W tiny =
        sqrt(W.min_normal);

    const W tol0 =
        W.epsilon;

    const W toleranceBracket =
        tol0;

    auto start =
        geodesicInverseStart!(
            W,
            order)(
                f,
                f1,
                ep2,
                n,
                a3x,
                sinBeta1,
                cosBeta1,
                sinBeta2,
                cosBeta2,
                lambda12,
                sinLambda12,
                cosLambda12);

    W sinAlpha1 =
        start.sinAlpha1;

    W cosAlpha1 =
        start.cosAlpha1;

    if (!start.needsNewton)
    {
        return GeodesicCanonicalInverseResult!W(
            start.sigma12
                * start.dnm,
            start.sigma12,
            sinAlpha1,
            cosAlpha1,
            start.sinAlpha2,
            start.cosAlpha2,
            zero,
            zero,
            0,
            true,
            start.kind,
            0,
            true);
    }

    W sinAlpha1Lower =
        tiny;

    W cosAlpha1Lower =
        one;

    W sinAlpha1Upper =
        tiny;

    W cosAlpha1Upper =
        -one;

    bool tripNewton =
        false;

    bool tripBracket =
        false;

    uint iteration =
        0;

    uint bracketMidpointCount =
        0;

    bool converged =
        false;

    GeodesicLambda12Result!W current;

    for (;; ++iteration)
    {
        W derivative =
            zero;

        if (iteration < maxNewtonIterations)
        {
            current =
                geodesicLambda12!(
                    W,
                    order,
                    true)(
                        f,
                        f1,
                        ep2,
                        a3x,
                        c3x,
                        sinBeta1,
                        cosBeta1,
                        dn1,
                        sinBeta2,
                        cosBeta2,
                        dn2,
                        sinAlpha1,
                        cosAlpha1,
                        sinLambda12,
                        cosLambda12);

            derivative =
                current.derivative;
        }
        else
        {
            current =
                geodesicLambda12!(
                    W,
                    order,
                    false)(
                        f,
                        f1,
                        ep2,
                        a3x,
                        c3x,
                        sinBeta1,
                        cosBeta1,
                        dn1,
                        sinBeta2,
                        cosBeta2,
                        dn2,
                        sinAlpha1,
                        cosAlpha1,
                        sinLambda12,
                        cosLambda12);
        }

        const W residual =
            current.lambdaResidual;

        const bool residualAccepted =
            !(
                fabs(residual)
                >= (
                    tripNewton
                    ? cast(W) 8
                    : one
                )
                    * tol0
            );

        if (
            tripBracket
            || residualAccepted
            || iteration == maxIterations)
        {
            converged =
                tripBracket
                || residualAccepted;

            break;
        }

        /*
         * Shrink the root bracket whenever the new point establishes a
         * stronger lower or upper bound.
         */
        if (
            residual > zero
            && (
                iteration > maxNewtonIterations
                || cosAlpha1 / sinAlpha1
                    > cosAlpha1Upper / sinAlpha1Upper
            ))
        {
            sinAlpha1Upper =
                sinAlpha1;

            cosAlpha1Upper =
                cosAlpha1;
        }
        else if (
            residual < zero
            && (
                iteration > maxNewtonIterations
                || cosAlpha1 / sinAlpha1
                    < cosAlpha1Lower / sinAlpha1Lower
            ))
        {
            sinAlpha1Lower =
                sinAlpha1;

            cosAlpha1Lower =
                cosAlpha1;
        }

        /*
         * Use Newton while the derivative has the correct sign and the
         * proposed azimuth remains in the legal interval (0, pi).
         */
        if (
            iteration < maxNewtonIterations
            && derivative > zero)
        {
            const W deltaAlpha1 =
                -residual
                / derivative;

            if (fabs(deltaAlpha1) < pi)
            {
                const W sinDeltaAlpha1 =
                    sin(deltaAlpha1);

                const W cosDeltaAlpha1 =
                    cos(deltaAlpha1);

                const W newSinAlpha1 =
                    sinAlpha1
                        * cosDeltaAlpha1
                    + cosAlpha1
                        * sinDeltaAlpha1;

                if (newSinAlpha1 > zero)
                {
                    cosAlpha1 =
                        cosAlpha1
                            * cosDeltaAlpha1
                        - sinAlpha1
                            * sinDeltaAlpha1;

                    sinAlpha1 =
                        newSinAlpha1;

                    normalizePair(
                        sinAlpha1,
                        cosAlpha1);

                    tripNewton =
                        fabs(residual)
                        <= cast(W) 16
                            * tol0;

                    continue;
                }
            }
        }

        /*
         * Newton was unsuitable.  Continue with the midpoint of the current
         * bracket.
         */
        ++bracketMidpointCount;

        sinAlpha1 =
            (
                sinAlpha1Lower
                + sinAlpha1Upper
            )
            / cast(W) 2;

        cosAlpha1 =
            (
                cosAlpha1Lower
                + cosAlpha1Upper
            )
            / cast(W) 2;

        normalizePair(
            sinAlpha1,
            cosAlpha1);

        tripNewton =
            false;

        tripBracket =
            (
                fabs(
                    sinAlpha1Lower
                    - sinAlpha1)
                + (
                    cosAlpha1Lower
                    - cosAlpha1
                )
                < toleranceBracket
            )
            || (
                fabs(
                    sinAlpha1
                    - sinAlpha1Upper)
                + (
                    cosAlpha1
                    - cosAlpha1Upper
                )
                < toleranceBracket
            );
    }

    /*
     * Re-evaluate the final accepted azimuth if the loop terminated directly
     * after a bracket midpoint update at the iteration limit.
     *
     * In the ordinary convergence path, current already corresponds exactly
     * to sinAlpha1/cosAlpha1.
     */
    if (
        iteration > maxIterations)
    {
        current =
            geodesicLambda12!(
                W,
                order,
                false)(
                    f,
                    f1,
                    ep2,
                    a3x,
                    c3x,
                    sinBeta1,
                    cosBeta1,
                    dn1,
                    sinBeta2,
                    cosBeta2,
                    dn2,
                    sinAlpha1,
                    cosAlpha1,
                    sinLambda12,
                    cosLambda12);
    }

    const lengths =
        geodesicLengths!(
            W,
            order,
            true)(
                current.eps,
                current.sigma12,
                current.sinSigma1,
                current.cosSigma1,
                dn1,
                current.sinSigma2,
                current.cosSigma2,
                dn2);

    return GeodesicCanonicalInverseResult!W(
        lengths.s12b,
        current.sigma12,
        sinAlpha1,
        cosAlpha1,
        current.sinAlpha2,
        current.cosAlpha2,
        current.eps,
        current.deltaOmega12,
        iteration,
        false,
        start.kind,
        bracketMidpointCount,
        converged);
}


unittest
{
    import std.math :
        PI,
        cos,
        fabs,
        sin,
        sqrt;

    import std.meta :
        AliasSeq;

    import geodesy.internal.geodesic_series :
        fillGeodesicA3x,
        fillGeodesicC3x;

    /*
     * Representative WGS84 canonical problem.
     *
     * The final Lambda12 residual should be at machine precision and the
     * returned azimuth pairs should remain normalized.
     */
    {
        enum double f =
            1.0 / 298.257223563;

        enum double f1 =
            1.0 - f;

        enum double e2 =
            f * (2.0 - f);

        enum double ep2 =
            e2 / (f1 * f1);

        enum double n =
            f / (2.0 - f);

        enum double beta1 =
            -0.7;

        enum double beta2 =
            0.25;

        enum double lambda12 =
            1.5;

        const double sinBeta1 =
            sin(beta1);

        const double cosBeta1 =
            cos(beta1);

        const double sinBeta2 =
            sin(beta2);

        const double cosBeta2 =
            cos(beta2);

        const double dn1 =
            sqrt(
                1.0
                + ep2
                * sinBeta1
                * sinBeta1);

        const double dn2 =
            sqrt(
                1.0
                + ep2
                * sinBeta2
                * sinBeta2);

        double[8] a3x;
        double[28] c3x;

        fillGeodesicA3x!(
            double,
            6)(
                n,
                a3x);

        fillGeodesicC3x!(
            double,
            6)(
                n,
                c3x);

        const result =
            geodesicCanonicalInverse!(
                double,
                6)(
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
                    lambda12,
                    sin(lambda12),
                    cos(lambda12));

        assert(!result.shortLine);
        assert(result.s12b > 0.0);
        assert(result.sigma12 >= 0.0);
        assert(result.sigma12 <= cast(double) PI);

        assert(
            fabs(
                result.sinAlpha1 * result.sinAlpha1
                + result.cosAlpha1 * result.cosAlpha1
                - 1.0)
            < 1e-13);

        assert(
            fabs(
                result.sinAlpha2 * result.sinAlpha2
                + result.cosAlpha2 * result.cosAlpha2
                - 1.0)
            < 1e-13);

        const check =
            geodesicLambda12!(
                double,
                6,
                false)(
                    f,
                    f1,
                    ep2,
                    a3x,
                    c3x,
                    sinBeta1,
                    cosBeta1,
                    dn1,
                    sinBeta2,
                    cosBeta2,
                    dn2,
                    result.sinAlpha1,
                    result.cosAlpha1,
                    sin(lambda12),
                    cos(lambda12));

        assert(
            fabs(check.lambdaResidual)
            < 1e-13);
    }

    /*
     * A short non-equatorial line should be completed directly by
     * InverseStart without entering Newton.
     */
    {
        enum double f =
            1.0 / 298.257223563;

        enum double f1 =
            1.0 - f;

        enum double e2 =
            f * (2.0 - f);

        enum double ep2 =
            e2 / (f1 * f1);

        enum double n =
            f / (2.0 - f);

        enum double beta1 =
            -0.2;

        enum double beta2 =
            beta1 + 1e-10;

        enum double lambda12 =
            1e-10;

        const double sinBeta1 =
            sin(beta1);

        const double cosBeta1 =
            cos(beta1);

        const double sinBeta2 =
            sin(beta2);

        const double cosBeta2 =
            cos(beta2);

        const double dn1 =
            sqrt(
                1.0
                + ep2
                * sinBeta1
                * sinBeta1);

        const double dn2 =
            sqrt(
                1.0
                + ep2
                * sinBeta2
                * sinBeta2);

        double[8] a3x;
        double[28] c3x;

        fillGeodesicA3x!(
            double,
            6)(
                n,
                a3x);

        fillGeodesicC3x!(
            double,
            6)(
                n,
                c3x);

        const result =
            geodesicCanonicalInverse!(
                double,
                6)(
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
                    lambda12,
                    sin(lambda12),
                    cos(lambda12));

        assert(result.shortLine);
        assert(result.iterations == 0);
        assert(result.s12b >= 0.0);
    }

    /*
     * Near-antipodal canonical case: exercise Astroid start + safeguarded
     * Newton.  This is the branch the inverse solver is primarily intended
     * to protect.
     */
    {
        enum double f =
            1.0 / 298.257223563;

        enum double f1 =
            1.0 - f;

        enum double e2 =
            f * (2.0 - f);

        enum double ep2 =
            e2 / (f1 * f1);

        enum double n =
            f / (2.0 - f);

        enum double beta1 =
            -0.1;

        enum double beta2 =
            0.1;

        enum double lambda12 =
            cast(double) PI
            - 0.001;

        const double sinBeta1 =
            sin(beta1);

        const double cosBeta1 =
            cos(beta1);

        const double sinBeta2 =
            sin(beta2);

        const double cosBeta2 =
            cos(beta2);

        const double dn1 =
            sqrt(
                1.0
                + ep2
                * sinBeta1
                * sinBeta1);

        const double dn2 =
            sqrt(
                1.0
                + ep2
                * sinBeta2
                * sinBeta2);

        double[8] a3x;
        double[28] c3x;

        fillGeodesicA3x!(
            double,
            6)(
                n,
                a3x);

        fillGeodesicC3x!(
            double,
            6)(
                n,
                c3x);

        const result =
            geodesicCanonicalInverse!(
                double,
                6)(
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
                    lambda12,
                    sin(lambda12),
                    cos(lambda12));

        assert(!result.shortLine);
        assert(result.s12b > 0.0);

        const check =
            geodesicLambda12!(
                double,
                6,
                false)(
                    f,
                    f1,
                    ep2,
                    a3x,
                    c3x,
                    sinBeta1,
                    cosBeta1,
                    dn1,
                    sinBeta2,
                    cosBeta2,
                    dn2,
                    result.sinAlpha1,
                    result.cosAlpha1,
                    sin(lambda12),
                    cos(lambda12));

        assert(
            fabs(check.lambdaResidual)
            < 1e-13);
    }

    /*
     * Compile and exercise all supported series orders.
     */
    static foreach (
        order;
        AliasSeq!(6, 7, 8))
    {
        {
            enum double f =
                0.005;

            enum double f1 =
                1.0 - f;

            enum double e2 =
                f * (2.0 - f);

            enum double ep2 =
                e2 / (f1 * f1);

            enum double n =
                f / (2.0 - f);

            enum double beta1 =
                -0.45;

            enum double beta2 =
                0.1;

            enum double lambda12 =
                1.25;

            const double sinBeta1 =
                sin(beta1);

            const double cosBeta1 =
                cos(beta1);

            const double sinBeta2 =
                sin(beta2);

            const double cosBeta2 =
                cos(beta2);

            const double dn1 =
                sqrt(
                    1.0
                    + ep2
                    * sinBeta1
                    * sinBeta1);

            const double dn2 =
                sqrt(
                    1.0
                    + ep2
                    * sinBeta2
                    * sinBeta2);

            double[8] a3x;
            double[28] c3x;

            fillGeodesicA3x!(
                double,
                order)(
                    n,
                    a3x);

            fillGeodesicC3x!(
                double,
                order)(
                    n,
                    c3x);

            const result =
                geodesicCanonicalInverse!(
                    double,
                    order)(
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
                        lambda12,
                        sin(lambda12),
                        cos(lambda12));

            assert(result.s12b > 0.0);
            assert(result.sigma12 >= 0.0);
            assert(result.sigma12 <= cast(double) PI);
        }
    }
}
