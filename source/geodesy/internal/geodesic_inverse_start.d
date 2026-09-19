/**
 * Internal starting-point machinery for Karney inverse geodesics.
 *
 * This module contains:
 *
 * - the astroid solver used near antipodal singularities;
 * - the initial azimuth estimate used before Lambda12/Newton iteration.
 *
 * The implementation follows GeographicLib 2.7 for the supported
 * oblate-ellipsoid domain. Prolate ellipsoids are intentionally outside
 * this project's initial geodesic contract.
 */
module geodesy.internal.geodesic_inverse_start;

import std.math :
    PI,
    atan2,
    cos,
    exp,
    fabs,
    log,
    hypot,
    sin,
    sqrt;

import geodesy.internal.geodesic_series :
    fillGeodesicA3x,
    geodesicA3;


package(geodesy):


private W square(W)(const W value)
    pure nothrow @safe @nogc
{
    return value * value;
}


private W realCubeRoot(W)(const W value)
    pure nothrow @safe @nogc
{
    if (value == cast(W) 0)
        return value;

    const W magnitude = fabs(value);

    W root =
        exp(
            log(magnitude)
            / cast(W) 3);

    root =
        (
            cast(W) 2 * root
            + magnitude / (root * root)
        )
        / cast(W) 3;

    return value < cast(W) 0
        ? -root
        : root;
}


private void normalizePair(W)(
    ref W sine,
    ref W cosine)
    pure nothrow @safe @nogc
{
    const W magnitude = hypot(sine, cosine);

    sine /= magnitude;
    cosine /= magnitude;
}


/**
 * Solve Karney's astroid equation for its positive root.
 *
 * k^4 + 2*k^3 - (x^2 + y^2 - 1)*k^2 - 2*y^2*k - y^2 = 0
 */
W geodesicAstroid(W)(
    const W x,
    const W y)
    pure nothrow @safe @nogc
{
    const W zero = cast(W) 0;
    const W one = cast(W) 1;

    const W p = square(x);
    const W q = square(y);
    const W r = (p + q - one) / cast(W) 6;

    W k = zero;

    if (!(q == zero && r <= zero))
    {
        const W s = p * q / cast(W) 4;
        const W r2 = square(r);
        const W r3 = r * r2;
        const W discriminant =
            s * (s + cast(W) 2 * r3);

        W u = r;

        if (discriminant >= zero)
        {
            W t3 = s + r3;
            const W root = sqrt(discriminant);

            t3 += t3 < zero ? -root : root;

            const W t = realCubeRoot(t3);

            u += t + (t != zero ? r2 / t : zero);
        }
        else
        {
            const W angle =
                atan2(
                    sqrt(-discriminant),
                    -(s + r3));

            u += cast(W) 2
                * r
                * cos(angle / cast(W) 3);
        }

        const W v =
            sqrt(square(u) + q);

        const W uv =
            u < zero
            ? q / (v - u)
            : u + v;

        const W w =
            (uv - q)
            / (cast(W) 2 * v);

        k =
            uv
            / (sqrt(uv + square(w)) + w);
    }

    return k;
}


/**
 * Internal initial-estimate path selected by the inverse-start routine.
 *
 * This is diagnostic state for validation; it is not public API.
 */
enum GeodesicInverseStartKind : ubyte
{
    none,
    shortLine,
    spherical,
    antipodal,
    antipodalAstroid,
}


struct GeodesicInverseStartResult(W)
{
    /**
     * sigma12 >= 0 means the short-line solution is complete.
     * sigma12 < 0 means Newton iteration is required.
     */
    W sigma12;

    W sinAlpha1;
    W cosAlpha1;

    /**
     * Defined when sigma12 >= 0.
     */
    W sinAlpha2;
    W cosAlpha2;

    /**
     * Mean dn approximation used by the completed short-line path.
     */
    W dnm;

    GeodesicInverseStartKind kind;

    @property bool needsNewton() const
        pure nothrow @safe @nogc
    {
        return sigma12 < cast(W) 0;
    }
}


/**
 * Construct Karney's starting azimuth estimate for inverse geodesics.
 *
 * Preconditions:
 *
 * - reduced latitudes are normalized and in inverse canonical form;
 * - lambda12 is in [0, pi];
 * - f is in the supported oblate range [0, 0.01];
 * - a3x belongs to the same ellipsoid and series order.
 */
GeodesicInverseStartResult!W geodesicInverseStart(
    W,
    int order)(
    const W f,
    const W f1,
    const W ep2,
    const W n,
    const ref W[8] a3x,
    const W sinBeta1,
    const W cosBeta1,
    const W sinBeta2,
    const W cosBeta2,
    const W lambda12,
    const W sinLambda12,
    const W cosLambda12)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    const W zero = cast(W) 0;
    const W one = cast(W) 1;
    const W half = cast(W) 0.5;
    const W pi = cast(W) PI;

    const W tol0 = W.epsilon;
    const W tol1 = cast(W) 200 * tol0;
    const W tol2 = sqrt(tol0);
    const W xThreshold = cast(W) 1000 * tol2;

    const W absF = fabs(f);

    const W fForEtol =
        absF > cast(W) 0.001
        ? absF
        : cast(W) 0.001;

    const W flatteningFactor =
        one - f / cast(W) 2;

    const W etol2 =
        cast(W) 0.1
        * tol2
        / sqrt(
            fForEtol
            * flatteningFactor
            / cast(W) 2);

    W sigma12 = -one;

    const W sinBeta12 =
        sinBeta2 * cosBeta1
        - cosBeta2 * sinBeta1;

    const W cosBeta12 =
        cosBeta2 * cosBeta1
        + sinBeta2 * sinBeta1;

    const W sinBeta12a =
        sinBeta2 * cosBeta1
        + cosBeta2 * sinBeta1;

    const bool shortLine =
        cosBeta12 >= zero
        && sinBeta12 < half
        && cosBeta2 * lambda12 < half;

    W sinOmega12;
    W cosOmega12;

    W dnm = zero;

    bool usedAntipodalStart = false;
    bool usedAstroidStart = false;

    if (shortLine)
    {
        W sinBetaMean2 =
            square(sinBeta1 + sinBeta2);

        sinBetaMean2 /=
            sinBetaMean2
            + square(cosBeta1 + cosBeta2);

        dnm =
            sqrt(
                one
                + ep2 * sinBetaMean2);

        const W omega12 =
            lambda12
            / (f1 * dnm);

        sinOmega12 = sin(omega12);
        cosOmega12 = cos(omega12);
    }
    else
    {
        sinOmega12 = sinLambda12;
        cosOmega12 = cosLambda12;
    }

    W sinAlpha1 =
        cosBeta2 * sinOmega12;

    W cosAlpha1;

    if (cosOmega12 >= zero)
    {
        cosAlpha1 =
            sinBeta12
            + cosBeta2
            * sinBeta1
            * square(sinOmega12)
            / (one + cosOmega12);
    }
    else
    {
        cosAlpha1 =
            sinBeta12a
            - cosBeta2
            * sinBeta1
            * square(sinOmega12)
            / (one - cosOmega12);
    }

    const W sinSigma12 =
        hypot(
            sinAlpha1,
            cosAlpha1);

    const W cosSigma12 =
        sinBeta1 * sinBeta2
        + cosBeta1
        * cosBeta2
        * cosOmega12;

    W sinAlpha2 = zero;
    W cosAlpha2 = zero;

    if (shortLine && sinSigma12 < etol2)
    {
        sinAlpha2 =
            cosBeta1 * sinOmega12;

        cosAlpha2 =
            sinBeta12
            - cosBeta1
            * sinBeta2
            * (
                cosOmega12 >= zero
                ? square(sinOmega12)
                    / (one + cosOmega12)
                : one - cosOmega12
            );

        normalizePair(
            sinAlpha2,
            cosAlpha2);

        sigma12 =
            atan2(
                sinSigma12,
                cosSigma12);
    }
    else if (
        fabs(n) > cast(W) 0.1
        || cosSigma12 >= zero
        || sinSigma12
            >= cast(W) 6
                * fabs(n)
                * pi
                * square(cosBeta1))
    {
        /*
         * Zeroth-order spherical approximation is already suitable.
         */
    }
    else
    {
        usedAntipodalStart = true;

        const W lambda12x =
            atan2(
                -sinLambda12,
                -cosLambda12);

        const W k2 =
            square(sinBeta1)
            * ep2;

        const W root =
            sqrt(one + k2);

        const W eps =
            k2
            / (
                cast(W) 2
                * (one + root)
                + k2
            );

        const W a3 =
            geodesicA3!(W, order)(
                eps,
                a3x);

        const W lambdaScale =
            f
            * cosBeta1
            * a3
            * pi;

        const W betaScale =
            lambdaScale
            * cosBeta1;

        const W x =
            lambda12x
            / lambdaScale;

        const W y =
            sinBeta12a
            / betaScale;

        if (
            y > -tol1
            && x > -one - xThreshold)
        {
            const W candidate = -x;

            sinAlpha1 =
                candidate < one
                ? candidate
                : one;

            cosAlpha1 =
                -sqrt(
                    one
                    - square(sinAlpha1));
        }
        else
        {
            usedAstroidStart = true;

            const W k =
                geodesicAstroid(
                    x,
                    y);

            const W omega12a =
                lambdaScale
                * (
                    -x
                    * k
                    / (one + k)
                );

            sinOmega12 =
                sin(omega12a);

            cosOmega12 =
                -cos(omega12a);

            sinAlpha1 =
                cosBeta2
                * sinOmega12;

            cosAlpha1 =
                sinBeta12a
                - cosBeta2
                * sinBeta1
                * square(sinOmega12)
                / (one - cosOmega12);
        }
    }

    if (!(sinAlpha1 <= zero))
    {
        normalizePair(
            sinAlpha1,
            cosAlpha1);
    }
    else
    {
        sinAlpha1 = one;
        cosAlpha1 = zero;
    }

    const GeodesicInverseStartKind kind =
        sigma12 >= zero
            ? GeodesicInverseStartKind.shortLine
            : (
                usedAstroidStart
                    ? GeodesicInverseStartKind.antipodalAstroid
                    : (
                        usedAntipodalStart
                            ? GeodesicInverseStartKind.antipodal
                            : GeodesicInverseStartKind.spherical
                    )
            );

    return GeodesicInverseStartResult!W(
        sigma12,
        sinAlpha1,
        cosAlpha1,
        sinAlpha2,
        cosAlpha2,
        dnm,
        kind);
}


unittest
{
    import std.math :
        fabs;

    import std.meta :
        AliasSeq;

    assert(
        geodesicAstroid(
            0.5,
            0.0)
        == 0.0);

    assert(
        fabs(
            geodesicAstroid(
                2.0,
                0.0)
            - 1.0)
        < 1e-14);

    {
        enum double x = -0.7;
        enum double y = 0.2;

        const double k =
            geodesicAstroid(
                x,
                y);

        const double residual =
            square(k) * square(k)
            + 2.0
                * k
                * square(k)
            - (
                square(x)
                + square(y)
                - 1.0
            )
                * square(k)
            - 2.0
                * square(y)
                * k
            - square(y);

        assert(k >= 0.0);
        assert(fabs(residual) < 1e-13);
    }

    {
        enum double beta1 = -0.2;
        enum double beta2 = beta1 + 1e-10;
        enum double lambda12 = 1e-10;

        double[8] a3x;

        fillGeodesicA3x!(
            double,
            6)(
                0.0,
                a3x);

        const result =
            geodesicInverseStart!(
                double,
                6)(
                0.0,
                1.0,
                0.0,
                0.0,
                a3x,
                sin(beta1),
                cos(beta1),
                sin(beta2),
                cos(beta2),
                lambda12,
                sin(lambda12),
                cos(lambda12));

        assert(!result.needsNewton);
        assert(result.sigma12 >= 0.0);
        assert(result.dnm == 1.0);

        assert(
            fabs(
                square(result.sinAlpha1)
                + square(result.cosAlpha1)
                - 1.0)
            < 1e-13);

        assert(
            fabs(
                square(result.sinAlpha2)
                + square(result.cosAlpha2)
                - 1.0)
            < 1e-13);
    }

    static foreach (
        order;
        AliasSeq!(6, 7, 8))
    {
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

        enum double beta1 = -0.1;
        enum double beta2 = 0.1;

        enum double lambda12 =
            cast(double) PI
            - 0.001;

        double[8] a3x;

        fillGeodesicA3x!(
            double,
            order)(
                n,
                a3x);

        const result =
            geodesicInverseStart!(
                double,
                order)(
                f,
                f1,
                ep2,
                n,
                a3x,
                sin(beta1),
                cos(beta1),
                sin(beta2),
                cos(beta2),
                lambda12,
                sin(lambda12),
                cos(lambda12));

        assert(result.needsNewton);
        assert(result.sinAlpha1 > 0.0);

            assert(
                fabs(
                    square(result.sinAlpha1)
                    + square(result.cosAlpha1)
                    - 1.0)
                < 1e-12);
        }
    }
}
