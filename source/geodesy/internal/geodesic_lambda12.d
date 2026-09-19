/**
 * Internal Lambda12 evaluation for Karney inverse geodesics.
 *
 * This module evaluates the inverse Newton residual
 *
 *     lambda12(alpha1) - lambda12_target
 *
 * together with the auxiliary-sphere state needed by the final inverse
 * solution.  When requested, it also evaluates the Newton derivative using
 * the reduced-length kernel.
 *
 * The implementation follows GeographicLib 2.7 for the supported oblate
 * ellipsoid domain.
 */
module geodesy.internal.geodesic_lambda12;

import std.math :
    atan2,
    fabs,
    hypot,
    sqrt;

import geodesy.internal.geodesic_lengths :
    geodesicLengths;

import geodesy.internal.geodesic_series :
    fillGeodesicC3,
    geodesicA3,
    geodesicSinCosSeries;


package(geodesy):


private W square(W)(const W value)
    pure nothrow @safe @nogc
{
    return value * value;
}


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
 * Result of one Lambda12 evaluation.
 */
struct GeodesicLambda12Result(W)
{
    /**
     * Newton residual:
     *
     * lambda12(alpha1) - lambda12_target.
     */
    W lambdaResidual;

    W sinAlpha2;
    W cosAlpha2;

    W sigma12;

    W sinSigma1;
    W cosSigma1;
    W sinSigma2;
    W cosSigma2;

    W eps;

    /**
     * Ellipsoidal correction omega12 - lambda12.
     */
    W deltaOmega12;

    /**
     * d(lambdaResidual) / d(alpha1).
     *
     * Zero when the derivative was not requested.
     */
    W derivative;
}


/**
 * Evaluate Karney's Lambda12 function.
 *
 * Template Params:
 *   W = working floating-point type.
 *   order = Karney series order, 6 through 8.
 *   calculateDerivative = whether the Newton derivative is required.
 *
 * Params:
 *   f = flattening.
 *   f1 = 1 - f.
 *   ep2 = second eccentricity squared.
 *   a3x = prepared A3 polynomial coefficients.
 *   c3x = prepared C3 polynomial coefficients.
 *   sinBeta1, cosBeta1 = reduced latitude of point 1.
 *   dn1 = sqrt(1 + ep2 * sinBeta1^2).
 *   sinBeta2, cosBeta2 = reduced latitude of point 2.
 *   dn2 = sqrt(1 + ep2 * sinBeta2^2).
 *   sinAlpha1, cosAlpha1 = current Newton azimuth estimate.
 *   sinLambdaTarget, cosLambdaTarget = target lambda12.
 */
GeodesicLambda12Result!W geodesicLambda12(
    W,
    int order,
    bool calculateDerivative)(
    const W f,
    const W f1,
    const W ep2,
    const ref W[8] a3x,
    const ref W[28] c3x,
    const W sinBeta1,
    const W cosBeta1,
    const W dn1,
    const W sinBeta2,
    const W cosBeta2,
    const W dn2,
    W sinAlpha1,
    W cosAlpha1,
    const W sinLambdaTarget,
    const W cosLambdaTarget)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    const W zero =
        cast(W) 0;

    const W one =
        cast(W) 1;

    const W tiny =
        sqrt(W.min_normal);

    /*
     * Break the equatorial-line degeneracy.  The inverse driver handles the
     * equatorial solution before Lambda12 is reached.
     */
    if (
        sinBeta1 == zero
        && cosAlpha1 == zero)
    {
        cosAlpha1 =
            -tiny;
    }

    /*
     * sin(alpha1) * cos(beta1) = sin(alpha0).
     */
    const W sinAlpha0 =
        sinAlpha1
        * cosBeta1;

    const W cosAlpha0 =
        hypot(
            cosAlpha1,
            sinAlpha1 * sinBeta1);

    /*
     * sigma1 and omega1.
     */
    W sinSigma1 =
        sinBeta1;

    W cosSigma1 =
        cosAlpha1
        * cosBeta1;

    const W sinOmega1 =
        sinAlpha0
        * sinBeta1;

    const W cosOmega1 =
        cosSigma1;

    normalizePair(
        sinSigma1,
        cosSigma1);

    /*
     * Enforce the same symmetry used by GeographicLib when
     * abs(beta2) == -beta1.
     */
    W sinAlpha2 =
        cosBeta2 != cosBeta1
        ? sinAlpha0 / cosBeta2
        : sinAlpha1;

    W cosAlpha2;

    if (
        cosBeta2 != cosBeta1
        || fabs(sinBeta2) != -sinBeta1)
    {
        const W correction =
            cosBeta1 < -sinBeta1
            ? (
                cosBeta2 - cosBeta1
            ) * (
                cosBeta1 + cosBeta2
            )
            : (
                sinBeta1 - sinBeta2
            ) * (
                sinBeta1 + sinBeta2
            );

        cosAlpha2 =
            sqrt(
                square(
                    cosAlpha1
                    * cosBeta1)
                + correction)
            / cosBeta2;
    }
    else
    {
        cosAlpha2 =
            fabs(cosAlpha1);
    }

    /*
     * sigma2 and omega2.
     */
    W sinSigma2 =
        sinBeta2;

    W cosSigma2 =
        cosAlpha2
        * cosBeta2;

    const W sinOmega2 =
        sinAlpha0
        * sinBeta2;

    const W cosOmega2 =
        cosSigma2;

    normalizePair(
        sinSigma2,
        cosSigma2);

    /*
     * sigma12 = sigma2 - sigma1, constrained to [0, pi].
     */
    const W sinSigmaDifference =
        cosSigma1 * sinSigma2
        - sinSigma1 * cosSigma2;

    const W sinSigma12 =
        sinSigmaDifference > zero
        ? sinSigmaDifference
        : zero;

    const W cosSigma12 =
        cosSigma1 * cosSigma2
        + sinSigma1 * sinSigma2;

    const W sigma12 =
        atan2(
            sinSigma12,
            cosSigma12);

    /*
     * omega12 = omega2 - omega1, constrained to [0, pi].
     *
     * omega vectors intentionally remain unnormalized, matching the
     * GeographicLib formulation.
     */
    const W sinOmegaDifference =
        cosOmega1 * sinOmega2
        - sinOmega1 * cosOmega2;

    const W sinOmega12 =
        sinOmegaDifference > zero
        ? sinOmegaDifference
        : zero;

    const W cosOmega12 =
        cosOmega1 * cosOmega2
        + sinOmega1 * sinOmega2;

    /*
     * eta = omega12 - lambda12_target.
     */
    const W eta =
        atan2(
            sinOmega12 * cosLambdaTarget
                - cosOmega12 * sinLambdaTarget,
            cosOmega12 * cosLambdaTarget
                + sinOmega12 * sinLambdaTarget);

    /*
     * Karney epsilon for this geodesic.
     */
    const W k2 =
        square(cosAlpha0)
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

    W[9] c3;

    fillGeodesicC3!(
        W,
        order)(
            eps,
            c3x,
            c3);

    const W b312 =
        geodesicSinCosSeries(
            true,
            sinSigma2,
            cosSigma2,
            c3,
            order - 1)
        - geodesicSinCosSeries(
            true,
            sinSigma1,
            cosSigma1,
            c3,
            order - 1);

    const W deltaOmega12 =
        -f
        * geodesicA3!(W, order)(
            eps,
            a3x)
        * sinAlpha0
        * (sigma12 + b312);

    const W lambdaResidual =
        eta
        + deltaOmega12;

    W derivative =
        zero;

    static if (calculateDerivative)
    {
        if (cosAlpha2 == zero)
        {
            derivative =
                -cast(W) 2
                * f1
                * dn1
                / sinBeta1;
        }
        else
        {
            const lengths =
                geodesicLengths!(
                    W,
                    order,
                    false)(
                        eps,
                        sigma12,
                        sinSigma1,
                        cosSigma1,
                        dn1,
                        sinSigma2,
                        cosSigma2,
                        dn2);

            derivative =
                lengths.m12b
                * f1
                / (
                    cosAlpha2
                    * cosBeta2
                );
        }
    }

    return GeodesicLambda12Result!W(
        lambdaResidual,
        sinAlpha2,
        cosAlpha2,
        sigma12,
        sinSigma1,
        cosSigma1,
        sinSigma2,
        cosSigma2,
        eps,
        deltaOmega12,
        derivative);
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
     * On a sphere, deltaOmega12 is identically zero.
     */
    {
        double[8] a3x;
        double[28] c3x;

        fillGeodesicA3x!(
            double,
            6)(
                0.0,
                a3x);

        fillGeodesicC3x!(
            double,
            6)(
                0.0,
                c3x);

        enum double beta1 = -0.3;
        enum double beta2 = 0.1;
        enum double alpha1 = 1.0;
        enum double lambdaTarget = 0.8;

        const result =
            geodesicLambda12!(
                double,
                6,
                true)(
                    0.0,
                    1.0,
                    0.0,
                    a3x,
                    c3x,
                    sin(beta1),
                    cos(beta1),
                    1.0,
                    sin(beta2),
                    cos(beta2),
                    1.0,
                    sin(alpha1),
                    cos(alpha1),
                    sin(lambdaTarget),
                    cos(lambdaTarget));

        assert(result.eps == 0.0);
        assert(result.deltaOmega12 == 0.0);
        assert(result.sigma12 >= 0.0);
        assert(result.sigma12 <= cast(double) PI);

        assert(
            fabs(
                square(result.sinSigma1)
                + square(result.cosSigma1)
                - 1.0)
            < 1e-14);

        assert(
            fabs(
                square(result.sinSigma2)
                + square(result.cosSigma2)
                - 1.0)
            < 1e-14);
    }

    /*
     * Compare the analytic Newton derivative with a central finite
     * difference for a representative WGS84 canonical configuration.
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

        enum double beta1 = -0.6;
        enum double beta2 = 0.2;
        enum double alpha1 = 1.1;
        enum double lambdaTarget = 1.4;

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
                * square(sinBeta1));

        const double dn2 =
            sqrt(
                1.0
                + ep2
                * square(sinBeta2));

        const exact =
            geodesicLambda12!(
                double,
                6,
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
                    sin(alpha1),
                    cos(alpha1),
                    sin(lambdaTarget),
                    cos(lambdaTarget));

        enum double h =
            1e-7;

        const plus =
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
                    sin(alpha1 + h),
                    cos(alpha1 + h),
                    sin(lambdaTarget),
                    cos(lambdaTarget));

        const minus =
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
                    sin(alpha1 - h),
                    cos(alpha1 - h),
                    sin(lambdaTarget),
                    cos(lambdaTarget));

        const double numericalDerivative =
            (
                plus.lambdaResidual
                - minus.lambdaResidual
            )
            / (2.0 * h);

        assert(exact.derivative > 0.0);

        assert(
            fabs(
                exact.derivative
                - numericalDerivative)
            < 5e-8);
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
                -0.4;

            enum double beta2 =
                0.15;

            enum double alpha1 =
                0.9;

            enum double lambdaTarget =
                1.2;

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

            const double sinBeta1 =
                sin(beta1);

            const double sinBeta2 =
                sin(beta2);

            const double dn1 =
                sqrt(
                    1.0
                    + ep2
                    * square(sinBeta1));

            const double dn2 =
                sqrt(
                    1.0
                    + ep2
                    * square(sinBeta2));

            const result =
                geodesicLambda12!(
                    double,
                    order,
                    true)(
                        f,
                        f1,
                        ep2,
                        a3x,
                        c3x,
                        sinBeta1,
                        cos(beta1),
                        dn1,
                        sinBeta2,
                        cos(beta2),
                        dn2,
                        sin(alpha1),
                        cos(alpha1),
                        sin(lambdaTarget),
                        cos(lambdaTarget));

            assert(
                result.sigma12
                >= 0.0);

            assert(
                result.sigma12
                <= cast(double) PI);

            assert(
                result.derivative
                > 0.0);
        }
    }
}
