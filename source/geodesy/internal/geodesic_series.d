/**
 * Internal Karney geodesic series support.
 *
 * Generated from GeographicLib 2.7 (`r2.7`) source commit:
 *
 *     475cbde5b8528a6294dfeb054bc177d90be9f7bb
 *
 * Coefficient provenance:
 *
 *     src/Geodesic.cpp
 *
 * GeographicLib is Copyright Charles Karney and distributed under the
 * MIT/X11 license.
 *
 * Do not edit the coefficient arrays manually. Regenerate them with:
 *
 *     research/geodesics/generate_direct_series_module.py
 */
module geodesy.internal.geodesic_series;

import geodesy.scalar : isGeodesyScalar;


package(geodesy):


template geodesicSeriesOrderFor(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float) || is(T == double))
        enum int geodesicSeriesOrderFor = 6;
    else static if (T.mant_dig <= 53)
        enum int geodesicSeriesOrderFor = 6;
    else static if (T.mant_dig <= 64)
        enum int geodesicSeriesOrderFor = 7;
    else
        enum int geodesicSeriesOrderFor = 8;
}


private immutable long[5] a1Order6 = [
    1, 4, 64, 0, 256,
];

private immutable long[5] a1Order7 = [
    1, 4, 64, 0, 256,
];

private immutable long[6] a1Order8 = [
    25, 64, 256, 4096, 0, 16384,
];

private immutable long[18] c1Order6 = [
    -1, 6, -16, 32, -9, 64, -128, 2048, 9, -16, 768, 3, -5, 512, -7, 1280, -7, 2048,
];

private immutable long[23] c1Order7 = [
    19, -64, 384, -1024, 2048, -9, 64, -128, 2048, -9, 72, -128, 6144, 3, -5, 512, 35, -56,
    10240, -7, 2048, -33, 14336,
];

private immutable long[28] c1Order8 = [
    19, -64, 384, -1024, 2048, 7, -18, 128, -256, 4096, -9, 72, -128, 6144, -11, 96, -160,
    16384, 35, -56, 10240, 9, -14, 4096, -33, 14336, -429, 262144,
];

private immutable long[18] c1pOrder6 = [
    205, -432, 768, 1536, 4005, -4736, 3840, 12288, -225, 116, 384, -7173, 2695, 7680,
    3467, 7680, 38081, 61440,
];

private immutable long[23] c1pOrder7 = [
    -4879, 9840, -20736, 36864, 73728, 4005, -4736, 3840, 12288, 8703, -7200, 3712, 12288,
    -7173, 2695, 7680, -141115, 41604, 92160, 38081, 61440, 459485, 516096,
];

private immutable long[28] c1pOrder8 = [
    -4879, 9840, -20736, 36864, 73728, -86171, 120150, -142080, 115200, 368640, 8703,
    -7200, 3712, 12288, 1082857, -688608, 258720, 737280, -141115, 41604, 92160, -2200311,
    533134, 860160, 459485, 516096, 109167851, 82575360,
];

private immutable long[5] a2Order6 = [
    -11, -28, -192, 0, 256,
];

private immutable long[5] a2Order7 = [
    -11, -28, -192, 0, 256,
];

private immutable long[6] a2Order8 = [
    -375, -704, -1792, -12288, 0, 16384,
];

private immutable long[18] c2Order6 = [
    1, 2, 16, 32, 35, 64, 384, 2048, 15, 80, 768, 7, 35, 512, 63, 1280, 77, 2048,
];

private immutable long[23] c2Order7 = [
    41, 64, 128, 1024, 2048, 35, 64, 384, 2048, 69, 120, 640, 6144, 7, 35, 512, 105, 504,
    10240, 77, 2048, 429, 14336,
];

private immutable long[28] c2Order8 = [
    41, 64, 128, 1024, 2048, 47, 70, 128, 768, 4096, 69, 120, 640, 6144, 133, 224, 1120,
    16384, 105, 504, 10240, 33, 154, 4096, 429, 14336, 6435, 262144,
];

private immutable long[18] a3Order6 = [
    -3, 128, -2, -3, 64, -1, -3, -1, 16, 3, -1, -2, 8, 1, -1, 2, 1, 1,
];

private immutable long[23] a3Order7 = [
    -5, 256, -5, -3, 128, -10, -2, -3, 64, 5, -1, -3, -1, 16, 3, -1, -2, 8, 1, -1, 2, 1, 1,
];

private immutable long[28] a3Order8 = [
    -25, 2048, -15, -20, 1024, -5, -10, -6, 256, -5, -20, -4, -6, 128, 5, -1, -3, -1, 16,
    3, -1, -2, 8, 1, -1, 2, 1, 1,
];

private immutable long[45] c3Order6 = [
    3, 128, 2, 5, 128, -1, 3, 3, 64, -1, 0, 1, 8, -1, 1, 4, 5, 256, 1, 3, 128, -3, -2, 3,
    64, 1, -3, 2, 32, 7, 512, -10, 9, 384, 5, -9, 5, 192, 7, 512, -14, 7, 512, 21, 2560,
];

private immutable long[69] c3Order7 = [
    21, 1024, 11, 12, 512, 2, 2, 5, 128, -5, -1, 3, 3, 64, -1, 0, 1, 8, -1, 1, 4, 27, 2048,
    1, 5, 256, -9, 2, 6, 256, 2, -3, -2, 3, 64, 1, -3, 2, 32, 3, 256, -4, 21, 1536, -6,
    -10, 9, 384, -1, 5, -9, 5, 192, 9, 1024, -10, 7, 512, 10, -14, 7, 512, 9, 1024, -45,
    21, 2560, 11, 2048,
];

private immutable long[98] c3Order8 = [
    243, 16384, 10, 21, 1024, 3, 11, 12, 512, -2, 2, 2, 5, 128, -5, -1, 3, 3, 64, -1, 0, 1,
    8, -1, 1, 4, 187, 16384, 69, 108, 8192, -2, 1, 5, 256, -6, -9, 2, 6, 256, 2, -3, -2, 3,
    64, 1, -3, 2, 32, 139, 16384, -1, 12, 1024, -77, -8, 42, 3072, 10, -6, -10, 9, 384, -1,
    5, -9, 5, 192, 127, 16384, -43, 72, 8192, -7, -40, 28, 2048, -7, 20, -28, 14, 1024, 99,
    16384, -15, 9, 1024, 75, -90, 42, 5120, 99, 16384, -99, 44, 8192, 429, 114688,
];


private W polynomialFromIntegers(W, size_t N)(
    const ref long[N] coefficients,
    const size_t offset,
    const int degree,
    const W x)
    pure nothrow @safe @nogc
{
    W result = cast(W) coefficients[offset];

    foreach (i; 1 .. degree + 1)
        result =
            result * x
            + cast(W) coefficients[offset + i];

    return result;
}


private W rationalPolynomial(W, size_t N)(
    const ref long[N] coefficients,
    const size_t offset,
    const int degree,
    const W x)
    pure nothrow @safe @nogc
{
    return polynomialFromIntegers!W(
            coefficients,
            offset,
            degree,
            x)
        / cast(W) coefficients[offset + degree + 1];
}


private W polynomialFromScalars(W, size_t N)(
    const ref W[N] coefficients,
    const size_t offset,
    const int degree,
    const W x)
    pure nothrow @safe @nogc
{
    W result = coefficients[offset];

    foreach (i; 1 .. degree + 1)
        result =
            result * x
            + coefficients[offset + i];

    return result;
}


private W a1FromCoefficients(W, size_t N)(
    const W eps,
    const int order,
    const ref long[N] coefficients)
    pure nothrow @safe @nogc
{
    const int degree = order / 2;
    const W eps2 = eps * eps;

    const W t = rationalPolynomial!W(
        coefficients,
        0,
        degree,
        eps2);

    return (t + eps) / (cast(W) 1 - eps);
}


W geodesicA1m1(W, int order)(const W eps)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        return a1FromCoefficients!W(
            eps,
            order,
            a1Order6);
    else static if (order == 7)
        return a1FromCoefficients!W(
            eps,
            order,
            a1Order7);
    else
        return a1FromCoefficients!W(
            eps,
            order,
            a1Order8);
}


private W a2FromCoefficients(W, size_t N)(
    const W eps,
    const int order,
    const ref long[N] coefficients)
    pure nothrow @safe @nogc
{
    const int degree = order / 2;
    const W eps2 = eps * eps;

    const W t = rationalPolynomial!W(
        coefficients,
        0,
        degree,
        eps2);

    return (t - eps) / (cast(W) 1 + eps);
}


W geodesicA2m1(W, int order)(const W eps)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        return a2FromCoefficients!W(
            eps,
            order,
            a2Order6);
    else static if (order == 7)
        return a2FromCoefficients!W(
            eps,
            order,
            a2Order7);
    else
        return a2FromCoefficients!W(
            eps,
            order,
            a2Order8);
}


private void fillCSeriesLike(W, size_t N)(
    const W eps,
    const int order,
    const ref long[N] coefficients,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    result[] = cast(W) 0;

    const W eps2 = eps * eps;
    W multiplier = eps;
    size_t offset = 0;

    for (int l = 1; l <= order; ++l)
    {
        const int degree = (order - l) / 2;

        result[l] =
            multiplier
            * rationalPolynomial!W(
                coefficients,
                offset,
                degree,
                eps2);

        offset += cast(size_t) degree + 2;
        multiplier *= eps;
    }
}


void fillGeodesicC1(W, int order)(
    const W eps,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        fillCSeriesLike!W(
            eps,
            order,
            c1Order6,
            result);
    else static if (order == 7)
        fillCSeriesLike!W(
            eps,
            order,
            c1Order7,
            result);
    else
        fillCSeriesLike!W(
            eps,
            order,
            c1Order8,
            result);
}


void fillGeodesicC1p(W, int order)(
    const W eps,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        fillCSeriesLike!W(
            eps,
            order,
            c1pOrder6,
            result);
    else static if (order == 7)
        fillCSeriesLike!W(
            eps,
            order,
            c1pOrder7,
            result);
    else
        fillCSeriesLike!W(
            eps,
            order,
            c1pOrder8,
            result);
}


void fillGeodesicC2(W, int order)(
    const W eps,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        fillCSeriesLike!W(
            eps,
            order,
            c2Order6,
            result);
    else static if (order == 7)
        fillCSeriesLike!W(
            eps,
            order,
            c2Order7,
            result);
    else
        fillCSeriesLike!W(
            eps,
            order,
            c2Order8,
            result);
}


private void fillA3FromCoefficients(W, size_t N)(
    const W n,
    const int order,
    const ref long[N] coefficients,
    ref W[8] result)
    pure nothrow @safe @nogc
{
    result[] = cast(W) 0;

    size_t offset = 0;
    size_t index = 0;

    for (int j = order - 1; j >= 0; --j)
    {
        const int left = order - j - 1;
        const int degree = left < j ? left : j;

        result[index++] =
            rationalPolynomial!W(
                coefficients,
                offset,
                degree,
                n);

        offset += cast(size_t) degree + 2;
    }
}


void fillGeodesicA3x(W, int order)(
    const W n,
    ref W[8] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        fillA3FromCoefficients!W(
            n,
            order,
            a3Order6,
            result);
    else static if (order == 7)
        fillA3FromCoefficients!W(
            n,
            order,
            a3Order7,
            result);
    else
        fillA3FromCoefficients!W(
            n,
            order,
            a3Order8,
            result);
}


private void fillC3xFromCoefficients(W, size_t N)(
    const W n,
    const int order,
    const ref long[N] coefficients,
    ref W[28] result)
    pure nothrow @safe @nogc
{
    result[] = cast(W) 0;

    size_t offset = 0;
    size_t index = 0;

    for (int l = 1; l < order; ++l)
    {
        for (int j = order - 1; j >= l; --j)
        {
            const int left = order - j - 1;
            const int degree = left < j ? left : j;

            result[index++] =
                rationalPolynomial!W(
                    coefficients,
                    offset,
                    degree,
                    n);

            offset += cast(size_t) degree + 2;
        }
    }
}


void fillGeodesicC3x(W, int order)(
    const W n,
    ref W[28] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    static if (order == 6)
        fillC3xFromCoefficients!W(
            n,
            order,
            c3Order6,
            result);
    else static if (order == 7)
        fillC3xFromCoefficients!W(
            n,
            order,
            c3Order7,
            result);
    else
        fillC3xFromCoefficients!W(
            n,
            order,
            c3Order8,
            result);
}


W geodesicA3(W, int order)(
    const W eps,
    const ref W[8] a3x)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    return polynomialFromScalars!W(
        a3x,
        0,
        order - 1,
        eps);
}


void fillGeodesicC3(W, int order)(
    const W eps,
    const ref W[28] c3x,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    static assert(order >= 6 && order <= 8);

    result[] = cast(W) 0;

    W multiplier = cast(W) 1;
    size_t offset = 0;

    for (int l = 1; l < order; ++l)
    {
        const int degree = order - l - 1;

        multiplier *= eps;

        result[l] =
            multiplier
            * polynomialFromScalars!W(
                c3x,
                offset,
                degree,
                eps);

        offset += cast(size_t) degree + 1;
    }
}


W geodesicSinCosSeries(W)(
    const bool sineSeries,
    const W sinX,
    const W cosX,
    const ref W[9] coefficients,
    int terms)
    pure nothrow @safe @nogc
{
    int index = terms + (sineSeries ? 1 : 0);

    const W recurrence =
        cast(W) 2
        * (cosX - sinX)
        * (cosX + sinX);

    W y0 =
        (terms & 1) != 0
            ? coefficients[--index]
            : cast(W) 0;

    W y1 = cast(W) 0;

    terms /= 2;

    while (terms-- > 0)
    {
        y1 =
            recurrence * y0
            - y1
            + coefficients[--index];

        y0 =
            recurrence * y1
            - y0
            + coefficients[--index];
    }

    return sineSeries
        ? cast(W) 2 * sinX * cosX * y0
        : cosX * (y0 - y1);
}


unittest
{
    assert(geodesicA2m1!(double, 6)(0.0) == 0.0);
    assert(geodesicA2m1!(double, 7)(0.0) == 0.0);
    assert(geodesicA2m1!(double, 8)(0.0) == 0.0);

    double[9] c2Order6Test;
    double[9] c2Order7Test;
    double[9] c2Order8Test;

    fillGeodesicC2!(double, 6)(
        0.0,
        c2Order6Test);

    fillGeodesicC2!(double, 7)(
        0.0,
        c2Order7Test);

    fillGeodesicC2!(double, 8)(
        0.0,
        c2Order8Test);

    foreach (value; c2Order6Test)
        assert(value == 0.0);

    foreach (value; c2Order7Test)
        assert(value == 0.0);

    foreach (value; c2Order8Test)
        assert(value == 0.0);
}


unittest
{
    static assert(geodesicSeriesOrderFor!float == 6);
    static assert(geodesicSeriesOrderFor!double == 6);

    static if (real.mant_dig <= 53)
        static assert(geodesicSeriesOrderFor!real == 6);
    else static if (real.mant_dig <= 64)
        static assert(geodesicSeriesOrderFor!real == 7);
    else
        static assert(geodesicSeriesOrderFor!real == 8);

    enum int order = 6;

    assert(geodesicA1m1!(double, order)(0.0) == 0.0);

    double[9] c1;
    double[9] c1p;

    fillGeodesicC1!(double, order)(0.0, c1);
    fillGeodesicC1p!(double, order)(0.0, c1p);

    foreach (value; c1)
        assert(value == 0.0);

    foreach (value; c1p)
        assert(value == 0.0);

    double[8] a3x;
    double[28] c3x;
    double[9] c3;

    fillGeodesicA3x!(double, order)(0.0, a3x);
    fillGeodesicC3x!(double, order)(0.0, c3x);

    assert(
        geodesicA3!(double, order)(
            0.0,
            a3x)
        == 1.0);

    fillGeodesicC3!(double, order)(
        0.0,
        c3x,
        c3);

    foreach (value; c3)
        assert(value == 0.0);

    double[9] c1Order7Test;
    double[9] c1pOrder7Test;
    double[8] a3xOrder7Test;
    double[28] c3xOrder7Test;
    double[9] c3Order7Test;

    assert(geodesicA1m1!(double, 7)(0.0) == 0.0);
    fillGeodesicC1!(double, 7)(0.0, c1Order7Test);
    fillGeodesicC1p!(double, 7)(0.0, c1pOrder7Test);
    fillGeodesicA3x!(double, 7)(0.0, a3xOrder7Test);
    fillGeodesicC3x!(double, 7)(0.0, c3xOrder7Test);
    assert(
        geodesicA3!(double, 7)(
            0.0,
            a3xOrder7Test)
        == 1.0);
    fillGeodesicC3!(double, 7)(
        0.0,
        c3xOrder7Test,
        c3Order7Test);

    double[9] c1Order8Test;
    double[9] c1pOrder8Test;
    double[8] a3xOrder8Test;
    double[28] c3xOrder8Test;
    double[9] c3Order8Test;

    assert(geodesicA1m1!(double, 8)(0.0) == 0.0);
    fillGeodesicC1!(double, 8)(0.0, c1Order8Test);
    fillGeodesicC1p!(double, 8)(0.0, c1pOrder8Test);
    fillGeodesicA3x!(double, 8)(0.0, a3xOrder8Test);
    fillGeodesicC3x!(double, 8)(0.0, c3xOrder8Test);
    assert(
        geodesicA3!(double, 8)(
            0.0,
            a3xOrder8Test)
        == 1.0);
    fillGeodesicC3!(double, 8)(
        0.0,
        c3xOrder8Test,
        c3Order8Test);

    double[9] simple;
    simple[1] = 2.0;

    assert(
        geodesicSinCosSeries(
            true,
            0.5,
            0.5,
            simple,
            1)
        == 1.0);
}
