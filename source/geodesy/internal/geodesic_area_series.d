/**
 * Internal Karney geodesic area-series support.
 *
 * Generated from GeographicLib 2.7 source commit:
 *
 *     475cbde5b8528a6294dfeb054bc177d90be9f7bb
 *
 * Coefficient provenance:
 *
 *     src/Geodesic.cpp, Geodesic::C4coeff / Geodesic::C4f
 *
 * GeographicLib is Copyright Charles Karney and distributed under the
 * MIT/X11 license.
 *
 * Do not edit the coefficient arrays manually. Regenerate them with:
 *
 *     research/geodesics/generate_area_series_module.py
 */
module geodesy.internal.geodesic_area_series;


package(geodesy):


private immutable long[77] c4Order6 = [
    97, 15015, 1088, 156, 45045, -224, -4784, 1573, 45045, -10656, 14144, -4576, -858,
    45045, 64, 624, -4576, 6864, -3003, 15015, 100, 208, 572, 3432, -12012, 30030, 45045,
    1, 9009, -2944, 468, 135135, 5792, 1040, -1287, 135135, 5952, -11648, 9152, -2574,
    135135, -64, -624, 4576, -6864, 3003, 135135, 8, 10725, 1856, -936, 225225, -8448,
    4992, -1144, 225225, -1440, 4160, -4576, 1716, 225225, -136, 63063, 1024, -208, 105105,
    3584, -3328, 1144, 315315, -128, 135135, -2560, 832, 405405, 128, 99099,
];

private immutable long[112] c4Order7 = [
    10, 9009, -464, 291, 45045, -4480, 1088, 156, 45045, 10736, -224, -4784, 1573, 45045,
    1664, -10656, 14144, -4576, -858, 45045, 16, 64, 624, -4576, 6864, -3003, 15015, 56,
    100, 208, 572, 3432, -12012, 30030, 45045, 10, 9009, 112, 15, 135135, 3840, -2944, 468,
    135135, -10704, 5792, 1040, -1287, 135135, -768, 5952, -11648, 9152, -2574, 135135,
    -16, -64, -624, 4576, -6864, 3003, 135135, -4, 25025, -1664, 168, 225225, 1664, 1856,
    -936, 225225, 6784, -8448, 4992, -1144, 225225, 128, -1440, 4160, -4576, 1716, 225225,
    64, 315315, 1792, -680, 315315, -2048, 1024, -208, 105105, -1792, 3584, -3328, 1144,
    315315, -512, 405405, 2048, -384, 405405, 3072, -2560, 832, 405405, -256, 495495,
    -2048, 640, 495495, 512, 585585,
];

private immutable long[156] c4Order8 = [
    193, 85085, 4192, 850, 765765, 20960, -7888, 4947, 765765, 12480, -76160, 18496, 2652,
    765765, -154048, 182512, -3808, -81328, 26741, 765765, 3232, 28288, -181152, 240448,
    -77792, -14586, 765765, 96, 272, 1088, 10608, -77792, 116688, -51051, 255255, 588, 952,
    1700, 3536, 9724, 58344, -204204, 510510, 765765, 349, 2297295, -1472, 510, 459459,
    -39840, 1904, 255, 2297295, 52608, 65280, -50048, 7956, 2297295, 103744, -181968,
    98464, 17680, -21879, 2297295, -1344, -13056, 101184, -198016, 155584, -43758, 2297295,
    -96, -272, -1088, -10608, 77792, -116688, 51051, 2297295, 464, 1276275, -928, -612,
    3828825, 64256, -28288, 2856, 3828825, -126528, 28288, 31552, -15912, 3828825, -41472,
    115328, -143616, 84864, -19448, 3828825, 160, 2176, -24480, 70720, -77792, 29172,
    3828825, -16, 97461, -16384, 1088, 5360355, -2560, 30464, -11560, 5360355, 35840,
    -34816, 17408, -3536, 1786785, 7168, -30464, 60928, -56576, 19448, 5360355, 128,
    2297295, 26624, -8704, 6891885, -77824, 34816, -6528, 6891885, -32256, 52224, -43520,
    14144, 6891885, -6784, 8423415, 24576, -4352, 8423415, 45056, -34816, 10880, 8423415,
    -1024, 3318315, -28672, 8704, 9954945, 1024, 1640925,
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


private void fillC4xFromCoefficients(
    W,
    int order,
    size_t N)(
    const W n,
    const ref long[N] coefficients,
    ref W[36] result)
    pure nothrow @safe @nogc
{
    result[] =
        cast(W) 0;

    size_t inputOffset =
        0;

    size_t outputIndex =
        0;

    foreach (l; 0 .. order)
    {
        for (int j = order - 1; j >= l; --j)
        {
            const int degree =
                order - j - 1;

            result[outputIndex++] =
                polynomialFromIntegers!W(
                    coefficients,
                    inputOffset,
                    degree,
                    n)
                / cast(W) coefficients[
                    inputOffset
                    + cast(size_t) degree
                    + 1];

            inputOffset +=
                cast(size_t) degree
                + 2;
        }
    }
}


/** Prepare the ellipsoid-dependent C4 polynomial table. */
void fillGeodesicC4x(W, int order)(
    const W n,
    ref W[36] result)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    static if (order == 6)
        fillC4xFromCoefficients!(
            W,
            order)(
                n,
                c4Order6,
                result);
    else static if (order == 7)
        fillC4xFromCoefficients!(
            W,
            order)(
                n,
                c4Order7,
                result);
    else
        fillC4xFromCoefficients!(
            W,
            order)(
                n,
                c4Order8,
                result);
}


/** Evaluate the C4 area-series coefficients for one geodesic epsilon. */
void fillGeodesicC4(W, int order)(
    const W eps,
    const ref W[36] c4x,
    ref W[9] result)
    pure nothrow @safe @nogc
{
    static assert(
        order >= 6 && order <= 8,
        "unsupported geodesic series order");

    result[] =
        cast(W) 0;

    W multiplier =
        cast(W) 1;

    size_t offset =
        0;

    foreach (l; 0 .. order)
    {
        const int degree =
            order - cast(int) l - 1;

        result[l] =
            multiplier
            * polynomialFromScalars!W(
                c4x,
                offset,
                degree,
                eps);

        offset +=
            cast(size_t) degree
            + 1;

        multiplier *=
            eps;
    }
}


unittest
{
    double[36] c4x;
    double[9] c4;

    fillGeodesicC4x!(
        double,
        6)(
            0.0,
            c4x);

    fillGeodesicC4!(
        double,
        6)(
            0.0,
            c4x,
            c4);

    assert(c4[0] == c4[0]);

    foreach (value; c4[1 .. 6])
        assert(value == 0.0);

    double[36] order7;
    double[36] order8;

    fillGeodesicC4x!(
        double,
        7)(
            0.001,
            order7);

    fillGeodesicC4x!(
        double,
        8)(
            0.001,
            order8);

    foreach (value; order7)
        assert(value == value);

    foreach (value; order8)
        assert(value == value);
}
