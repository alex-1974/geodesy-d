/**
 * Bounded EPSG 1024 Popular Visualisation Pseudo-Mercator projection.
 *
 * The public operation retains its source ellipsoid for semantic identity, but
 * the coordinate equations use only the ellipsoid semi-major axis as required
 * by EPSG method 1024.
 */
module geodesy.projection.pseudo_mercator;

import std.math :
    PI,
    asinh,
    atan,
    atan2,
    copysign,
    expm1,
    fabs,
    nextDown,
    nextUp,
    sinh,
    tan;

import geodesy.angle :
    Latitude,
    Longitude;

import geodesy.ellipsoid :
    Ellipsoid;

import geodesy.errors :
    GeodesyValueException;

import geodesy.geographic :
    GeographicCoordinate;

import geodesy.projected :
    ProjectedCoordinate;

import geodesy.scalar :
    isGeodesyScalar;


/*
 * Numerical provenance
 * --------------------
 *
 * The forward/reverse formulas follow EPSG coordinate operation method 1024.
 * The represented-domain, scalar, and endpoint rules are the qualified
 * PM-B through PM-G0 geodesy-d research decisions.
 */


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
}


private T pi(T)()
    pure nothrow @safe @nogc
{
    return cast(T) PI;
}


private void twoSum(T)(
    const T a,
    const T b,
    out T sum,
    out T residual)
    pure nothrow @safe @nogc
{
    sum = a + b;

    const T z =
        sum - a;

    residual =
        (a - (sum - z))
        + (b - z);
}


private T canonicalPublicRadians(T)(
    const T radians)
    pure nothrow @safe @nogc
{
    const T p =
        pi!T;

    const T twoP =
        cast(T) 2 * p;

    T result =
        radians;

    if (result >= p)
        result -= twoP;
    else if (result < -p)
        result += twoP;

    if (result >= p)
        result -= twoP;
    else if (result < -p)
        result += twoP;

    return result == cast(T) 0
        ? cast(T) 0
        : result;
}


private WorkingScalar!T workingCanonicalLongitude(T)(
    const T radians)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    const T canonical =
        canonicalPublicRadians(
            radians);

    const T publicPi =
        pi!T;

    /*
     * Preserve exact public cardinal semantics while widening.
     */
    if (canonical == cast(T) 0)
        return cast(W) 0;

    if (canonical == -publicPi)
        return -pi!W;

    const T halfPublicPi =
        publicPi / cast(T) 2;

    if (canonical == halfPublicPi)
        return pi!W / cast(W) 2;

    if (canonical == -halfPublicPi)
        return -pi!W / cast(W) 2;

    return cast(W) canonical;
}


private void twoPiSplit(T)(
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    static if (is(W == double))
    {
        /*
         * Prepare the binary64 split in D real precision.
         */
        const real twoPiPrepared =
            cast(real) 2 * PI;

        high =
            cast(W) twoPiPrepared;

        low =
            cast(W) (
                twoPiPrepared
                - cast(real) high);
    }
    else static if (is(W == real))
    {
        /*
         * Qualified x86 extended-real split of mathematical 2*pi.
         */
        high =
            cast(W)
                6.2831853071795864770256179188123724088654853403568267822265625L;

        low =
            cast(W)
                -1.0033115225336664047114654160661514027667331538436718742758200274393034931576586e-19L;
    }
    else
    {
        static assert(
            false,
            "Unexpected Pseudo-Mercator working scalar.");
    }
}


private void normalizeExpansion(T)(
    const WorkingScalar!T highInput,
    const WorkingScalar!T lowInput,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    twoSum(
        highInput,
        lowInput,
        high,
        low);
}


private void addSplitPeriodParts(T)(
    const WorkingScalar!T sum,
    const WorkingScalar!T residual,
    const int periodSign,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    W periodHigh;
    W periodLow;

    twoPiSplit!T(
        periodHigh,
        periodLow);

    const W signedHigh =
        periodSign > 0
            ? periodHigh
            : -periodHigh;

    const W signedLow =
        periodSign > 0
            ? periodLow
            : -periodLow;

    W major;
    W majorResidual;

    twoSum(
        sum,
        signedHigh,
        major,
        majorResidual);

    W minor;
    W minorResidual;

    twoSum(
        residual,
        signedLow,
        minor,
        minorResidual);

    W combined;
    W combinedResidual;

    twoSum(
        major,
        minor,
        combined,
        combinedResidual);

    W tailA;
    W tailB;

    twoSum(
        majorResidual,
        combinedResidual,
        tailA,
        tailB);

    W tailC;
    W tailD;

    twoSum(
        tailA,
        minorResidual,
        tailC,
        tailD);

    W firstHigh;
    W firstLow;

    twoSum(
        combined,
        tailC,
        firstHigh,
        firstLow);

    const W finalLow =
        firstLow
        + tailB
        + tailD;

    normalizeExpansion!T(
        firstHigh,
        finalLow,
        high,
        low);
}


private void longitudeDifferenceParts(T)(
    const T longitude,
    const T longitude0,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    const W source =
        workingCanonicalLongitude!T(
            longitude);

    const W origin =
        workingCanonicalLongitude!T(
            longitude0);

    W sum;
    W residual;

    twoSum(
        source,
        -origin,
        sum,
        residual);

    const W p =
        pi!W;

    if (sum > p
        || (sum == p
            && residual >= cast(W) 0))
    {
        addSplitPeriodParts!T(
            sum,
            residual,
            -1,
            high,
            low);

        return;
    }

    if (sum < -p
        || (sum == -p
            && residual < cast(W) 0))
    {
        addSplitPeriodParts!T(
            sum,
            residual,
            +1,
            high,
            low);

        return;
    }

    normalizeExpansion!T(
        sum,
        residual,
        high,
        low);
}


private void splitProductOperand(T)(
    const WorkingScalar!T value,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    W splitter;

    static if (is(W == double))
    {
        splitter =
            cast(W) 134217729.0;
    }
    else static if (is(W == real))
    {
        splitter =
            cast(W) 4294967297.0L;
    }
    else
    {
        static assert(
            false,
            "Unexpected Pseudo-Mercator working scalar.");
    }

    const W scaled =
        splitter * value;

    high =
        scaled
        - (scaled - value);

    low =
        value - high;
}


private void twoProduct(T)(
    const WorkingScalar!T a,
    const WorkingScalar!T b,
    out WorkingScalar!T product,
    out WorkingScalar!T residual)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    product =
        a * b;

    W aHigh;
    W aLow;
    W bHigh;
    W bLow;

    splitProductOperand!T(
        a,
        aHigh,
        aLow);

    splitProductOperand!T(
        b,
        bHigh,
        bLow);

    residual =
        (
            (
                aHigh * bHigh
                - product
            )
            + aHigh * bLow
            + aLow * bHigh
        )
        + aLow * bLow;
}


private WorkingScalar!T affineProductSum(T)(
    const WorkingScalar!T scale,
    const WorkingScalar!T value,
    const WorkingScalar!T offset)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    W product;
    W productResidual;

    twoProduct!T(
        scale,
        value,
        product,
        productResidual);

    W sum;
    W sumResidual;

    twoSum(
        offset,
        product,
        sum,
        sumResidual);

    W tail;
    W tailResidual;

    twoSum(
        sumResidual,
        productResidual,
        tail,
        tailResidual);

    W result;
    W resultResidual;

    twoSum(
        sum,
        tail,
        result,
        resultResidual);

    return result
        + (
            resultResidual
            + tailResidual
        );
}


private WorkingScalar!T eastingFromLongitudeDifference(T)(
    const WorkingScalar!T semiMajorAxis,
    const WorkingScalar!T falseEasting,
    const WorkingScalar!T deltaHigh,
    const WorkingScalar!T deltaLow)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    W mainProduct;
    W mainProductResidual;

    twoProduct!T(
        semiMajorAxis,
        deltaHigh,
        mainProduct,
        mainProductResidual);

    W lowProduct;
    W lowProductResidual;

    twoProduct!T(
        semiMajorAxis,
        deltaLow,
        lowProduct,
        lowProductResidual);

    W mainSum;
    W mainSumResidual;

    twoSum(
        falseEasting,
        mainProduct,
        mainSum,
        mainSumResidual);

    W tail0;
    W tail0Residual;

    twoSum(
        mainProductResidual,
        lowProduct,
        tail0,
        tail0Residual);

    W tail1;
    W tail1Residual;

    twoSum(
        tail0,
        lowProductResidual,
        tail1,
        tail1Residual);

    W tail2;
    W tail2Residual;

    twoSum(
        mainSumResidual,
        tail1,
        tail2,
        tail2Residual);

    const W remaining =
        tail0Residual
        + tail1Residual
        + tail2Residual;

    W result;
    W resultResidual;

    twoSum(
        mainSum,
        tail2,
        result,
        resultResidual);

    return result
        + (
            resultResidual
            + remaining
        );
}


private void quotientExpansion(T)(
    const WorkingScalar!T numerator,
    const WorkingScalar!T denominator,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    const W quotient =
        numerator / denominator;

    W product;
    W productResidual;

    twoProduct!T(
        denominator,
        quotient,
        product,
        productResidual);

    const W remainder =
        (
            numerator
            - product
        )
        - productResidual;

    const W correction =
        remainder / denominator;

    twoSum(
        quotient,
        correction,
        high,
        low);
}


private WorkingScalar!T addLongitudeParts(T)(
    const T longitude0,
    const WorkingScalar!T deltaHigh,
    const WorkingScalar!T deltaLow)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    const W origin =
        workingCanonicalLongitude!T(
            longitude0);

    W main;
    W mainResidual;

    twoSum(
        origin,
        deltaHigh,
        main,
        mainResidual);

    W tail;
    W tailResidual;

    twoSum(
        mainResidual,
        deltaLow,
        tail,
        tailResidual);

    W sum;
    W sumResidual;

    twoSum(
        main,
        tail,
        sum,
        sumResidual);

    W high;
    W low;

    normalizeExpansion!T(
        sum,
        sumResidual
            + tailResidual,
        high,
        low);

    const W p =
        pi!W;

    int periodSign = 0;

    if (high > p
        || (high == p
            && low >= cast(W) 0))
    {
        periodSign = -1;
    }
    else if (high < -p
        || (high == -p
            && low < cast(W) 0))
    {
        periodSign = 1;
    }

    if (periodSign != 0)
    {
        W wrappedHigh;
        W wrappedLow;

        addSplitPeriodParts!T(
            high,
            low,
            periodSign,
            wrappedHigh,
            wrappedLow);

        high =
            wrappedHigh;

        low =
            wrappedLow;
    }

    return high + low;
}


private WorkingScalar!T addLongitude(T)(
    const T longitude0,
    const WorkingScalar!T delta)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    const W origin =
        workingCanonicalLongitude!T(
            longitude0);

    W sum;
    W residual;

    twoSum(
        origin,
        delta,
        sum,
        residual);

    const W p =
        pi!W;

    int periodSign = 0;

    if (sum > p
        || (sum == p
            && residual >= cast(W) 0))
    {
        periodSign = -1;
    }
    else if (sum < -p
        || (sum == -p
            && residual < cast(W) 0))
    {
        periodSign = 1;
    }

    W high;
    W low;

    if (periodSign == 0)
    {
        normalizeExpansion!T(
            sum,
            residual,
            high,
            low);
    }
    else
    {
        addSplitPeriodParts!T(
            sum,
            residual,
            periodSign,
            high,
            low);
    }

    return high + low;
}


private bool validPublicLongitude(T)(
    const T radians)
    pure nothrow @safe @nogc
{
    return isFiniteScalar(
            radians)
        && radians >= -pi!T
        && radians <= pi!T;
}


private bool legalPositiveLongitudeDifference(T)(
    const WorkingScalar!T high,
    const WorkingScalar!T low)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    if (high > cast(W) 0)
        return true;

    if (high < cast(W) 0)
        return false;

    return low >= cast(W) 0;
}


private bool findRepresentedEastMaximum(T)(
    const T longitude0,
    const T semiMajorAxis,
    const T falseEasting,
    out T representedEasting,
    out WorkingScalar!T legalDelta,
    out T legalLongitude)
    pure nothrow @safe @nogc
{
    alias W = WorkingScalar!T;

    representedEasting =
        T.nan;

    legalDelta =
        -W.infinity;

    legalLongitude =
        T.nan;

    const T canonicalOrigin =
        canonicalPublicRadians!T(
            longitude0);

    const T publicPi =
        pi!T;

    W deltaHigh;
    W deltaLow;

    if (canonicalOrigin == -publicPi)
    {
        legalLongitude =
            nextDown(
                cast(T) 0);

        longitudeDifferenceParts!T(
            legalLongitude,
            longitude0,
            deltaHigh,
            deltaLow);

        if (!legalPositiveLongitudeDifference!T(
                deltaHigh,
                deltaLow))
        {
            return false;
        }

        const T successor =
            nextUp(
                legalLongitude);

        W successorHigh;
        W successorLow;

        longitudeDifferenceParts!T(
            successor,
            longitude0,
            successorHigh,
            successorLow);

        if (legalPositiveLongitudeDifference!T(
                successorHigh,
                successorLow))
        {
            return false;
        }
    }
    else
    {
        T lower;
        T upper;

        if (canonicalOrigin <= cast(T) 0)
        {
            lower =
                canonicalOrigin;

            upper =
                publicPi;
        }
        else
        {
            lower =
                -publicPi;

            upper =
                cast(T) 0;
        }

        W lowerHigh;
        W lowerLow;

        longitudeDifferenceParts!T(
            lower,
            longitude0,
            lowerHigh,
            lowerLow);

        if (!legalPositiveLongitudeDifference!T(
                lowerHigh,
                lowerLow))
        {
            return false;
        }

        W upperHigh;
        W upperLow;

        longitudeDifferenceParts!T(
            upper,
            longitude0,
            upperHigh,
            upperLow);

        if (legalPositiveLongitudeDifference!T(
                upperHigh,
                upperLow))
        {
            return false;
        }

        while (nextUp(lower) != upper)
        {
            T middle =
                lower
                + (upper - lower)
                    / cast(T) 2;

            if (!(middle > lower))
            {
                middle =
                    nextUp(
                        lower);
            }

            if (!(middle < upper))
            {
                middle =
                    nextDown(
                        upper);
            }

            W middleHigh;
            W middleLow;

            longitudeDifferenceParts!T(
                middle,
                longitude0,
                middleHigh,
                middleLow);

            if (legalPositiveLongitudeDifference!T(
                    middleHigh,
                    middleLow))
            {
                lower =
                    middle;
            }
            else
            {
                upper =
                    middle;
            }
        }

        legalLongitude =
            lower;

        longitudeDifferenceParts!T(
            legalLongitude,
            longitude0,
            deltaHigh,
            deltaLow);

        if (!legalPositiveLongitudeDifference!T(
                deltaHigh,
                deltaLow))
        {
            return false;
        }

        W successorHigh;
        W successorLow;

        longitudeDifferenceParts!T(
            upper,
            longitude0,
            successorHigh,
            successorLow);

        if (legalPositiveLongitudeDifference!T(
                successorHigh,
                successorLow))
        {
            return false;
        }
    }

    const W easting =
        eastingFromLongitudeDifference!T(
            cast(W) semiMajorAxis,
            cast(W) falseEasting,
            deltaHigh,
            deltaLow);

    const T publicEasting =
        cast(T) easting;

    if (!isFiniteScalar(
            publicEasting))
    {
        return false;
    }

    representedEasting =
        publicEasting;

    legalDelta =
        deltaHigh
        + deltaLow;

    return true;
}


/**
 * Prepared bounded Pseudo-Mercator operation with EPSG 1024 parameters.
 *
 * The forward latitude domain is [-88 degrees,+88 degrees]. Longitude uses the
 * principal wrapped sheet from -pi inclusive to +pi exclusive, with represented endpoint rules qualified
 * by PM-G0.
 */
struct PseudoMercator(T)
if (isGeodesyScalar!T)
{
private:
    alias W =
        WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    Longitude!T _longitudeOfNaturalOrigin;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;

    W _a = W.nan;
    W _falseEastingWorking = W.nan;
    W _falseNorthingWorking = W.nan;

    Latitude!T _southLatitude;
    Latitude!T _northLatitude;

    T _southNorthingBoundary = T.nan;
    T _northNorthingBoundary = T.nan;
    T _westEastingBoundary = T.nan;
    T _eastLegalMaximum = T.nan;
    T _eastLegalLongitude = T.nan;

public:
    /** True when the prepared operation contains valid supported parameters. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && isFiniteScalar(_falseEasting)
            && isFiniteScalar(_falseNorthing)
            && isFiniteScalar(_a)
            && _a > cast(W) 0
            && isFiniteScalar(_falseEastingWorking)
            && isFiniteScalar(_falseNorthingWorking)
            && isFiniteScalar(_southNorthingBoundary)
            && isFiniteScalar(_northNorthingBoundary)
            && _southNorthingBoundary < _northNorthingBoundary
            && isFiniteScalar(_westEastingBoundary)
            && isFiniteScalar(_eastLegalMaximum)
            && _westEastingBoundary <= _eastLegalMaximum
            && validPublicLongitude(_eastLegalLongitude);
    }


    /**
     * Prepare a Pseudo-Mercator operation without throwing.
     *
     * Flattening is retained as source-ellipsoid state but does not enter the
     * coordinate equations.
     */
    static bool tryFromParameters(
        const Ellipsoid!T ellipsoid,
        const Longitude!T longitudeOfNaturalOrigin,
        const T falseEasting,
        const T falseNorthing,
        out PseudoMercator result)
        pure nothrow @safe @nogc
    {
        if (!ellipsoid.isValid
            || !isFiniteScalar(falseEasting)
            || !isFiniteScalar(falseNorthing))
        {
            return false;
        }

        PseudoMercator candidate;

        candidate._ellipsoid =
            ellipsoid;

        candidate._longitudeOfNaturalOrigin =
            longitudeOfNaturalOrigin;

        candidate._falseEasting =
            falseEasting;

        candidate._falseNorthing =
            falseNorthing;

        candidate._a =
            cast(W) ellipsoid.semiMajorAxis;

        candidate._falseEastingWorking =
            cast(W) falseEasting;

        candidate._falseNorthingWorking =
            cast(W) falseNorthing;

        if (!isFiniteScalar(candidate._a)
            || !(candidate._a > cast(W) 0)
            || !isFiniteScalar(candidate._falseEastingWorking)
            || !isFiniteScalar(candidate._falseNorthingWorking))
        {
            return false;
        }

        Latitude!T northLatitude;
        Latitude!T southLatitude;

        if (!Latitude!T.tryFromDegrees(
                cast(T) 88,
                northLatitude)
            || !Latitude!T.tryFromDegrees(
                cast(T) -88,
                southLatitude))
        {
            return false;
        }

        candidate._northLatitude =
            northLatitude;

        candidate._southLatitude =
            southLatitude;

        T northBoundary;
        T southBoundary;

        static if (is(T == double))
        {
            const real northQExtended =
                asinh(
                    tan(
                        cast(real)
                            northLatitude.radians));

            const real southQExtended =
                asinh(
                    tan(
                        cast(real)
                            southLatitude.radians));

            northBoundary =
                cast(T)
                    affineProductSum!real(
                        cast(real)
                            candidate._a,
                        northQExtended,
                        cast(real)
                            candidate._falseNorthingWorking);

            southBoundary =
                cast(T)
                    affineProductSum!real(
                        cast(real)
                            candidate._a,
                        southQExtended,
                        cast(real)
                            candidate._falseNorthingWorking);
        }
        else
        {
            const W northQ =
                asinh(
                    tan(
                        cast(W)
                            northLatitude.radians));

            const W southQ =
                asinh(
                    tan(
                        cast(W)
                            southLatitude.radians));

            northBoundary =
                cast(T)
                    affineProductSum!T(
                        candidate._a,
                        northQ,
                        candidate._falseNorthingWorking);

            southBoundary =
                cast(T)
                    affineProductSum!T(
                        candidate._a,
                        southQ,
                        candidate._falseNorthingWorking);
        }

        if (!isFiniteScalar(northBoundary)
            || !isFiniteScalar(southBoundary)
            || !(southBoundary < northBoundary))
        {
            return false;
        }

        candidate._northNorthingBoundary =
            northBoundary;

        candidate._southNorthingBoundary =
            southBoundary;

        candidate._westEastingBoundary =
            cast(T) (
                candidate._falseEastingWorking
                - candidate._a * pi!W);

        if (!isFiniteScalar(
                candidate._westEastingBoundary))
        {
            return false;
        }

        W eastLegalDelta;

        if (!findRepresentedEastMaximum!T(
                longitudeOfNaturalOrigin.radians,
                ellipsoid.semiMajorAxis,
                falseEasting,
                candidate._eastLegalMaximum,
                eastLegalDelta,
                candidate._eastLegalLongitude))
        {
            return false;
        }

        if (!candidate.isValid)
            return false;

        result =
            candidate;

        return true;
    }


    /** Prepare a Pseudo-Mercator operation or throw on invalid parameters. */
    static PseudoMercator fromParameters(
        const Ellipsoid!T ellipsoid,
        const Longitude!T longitudeOfNaturalOrigin,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        PseudoMercator result;

        if (!tryFromParameters(
                ellipsoid,
                longitudeOfNaturalOrigin,
                falseEasting,
                falseNorthing,
                result))
        {
            throw new GeodesyValueException(
                "Pseudo-Mercator requires a valid ellipsoid and finite false offsets.");
        }

        return result;
    }


    /** Source ellipsoid retained by the operation. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }


    /** Longitude of natural origin. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfNaturalOrigin;
    }


    /** False easting in the ellipsoid linear unit. */
    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _falseEasting;
    }


    /** False northing in the ellipsoid linear unit. */
    @property T falseNorthing() const
        pure nothrow @safe @nogc
    {
        return _falseNorthing;
    }


    /** Project a geographic coordinate on the bounded Pseudo-Mercator sheet. */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result =
            ProjectedCoordinate!T.init;

        if (!isValid)
            return false;

        const T latitudePublic =
            source.latitude.radians;

        if (latitudePublic < _southLatitude.radians
            || latitudePublic > _northLatitude.radians)
        {
            return false;
        }

        W deltaLongitudeHigh;
        W deltaLongitudeLow;

        longitudeDifferenceParts!T(
            source.longitude.radians,
            _longitudeOfNaturalOrigin.radians,
            deltaLongitudeHigh,
            deltaLongitudeLow);

        const W easting =
            eastingFromLongitudeDifference!T(
                _a,
                _falseEastingWorking,
                deltaLongitudeHigh,
                deltaLongitudeLow);

        W northing;

        static if (is(T == double))
        {
            const real qExtended =
                asinh(
                    tan(
                        cast(real)
                            source.latitude.radians));

            northing =
                cast(W)
                    affineProductSum!real(
                        cast(real) _a,
                        qExtended,
                        cast(real)
                            _falseNorthingWorking);
        }
        else
        {
            const W q =
                asinh(
                    tan(
                        cast(W)
                            latitudePublic));

            northing =
                affineProductSum!T(
                    _a,
                    q,
                    _falseNorthingWorking);
        }

        if (!isFiniteScalar(easting)
            || !isFiniteScalar(northing))
        {
            return false;
        }

        return ProjectedCoordinate!T
            .tryFromComponents(
                cast(T) easting,
                cast(T) northing,
                result);
    }


    /** Throwing convenience wrapper for \`tryForward\`. */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(
                source,
                result))
        {
            throw new GeodesyValueException(
                "Pseudo-Mercator forward projection failed or the point lies "
                ~ "outside the supported [-88,+88] degree latitude domain.");
        }

        return result;
    }


    /** Reverse a projected coordinate from the bounded represented sheet. */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result =
            GeographicCoordinate!T.init;

        if (!isValid)
            return false;

        if (source.northing < _southNorthingBoundary
            || source.northing > _northNorthingBoundary)
        {
            return false;
        }

        const W deltaNumerator =
            cast(W) source.easting
            - _falseEastingWorking;

        W deltaLongitude =
            deltaNumerator / _a;

        if (!isFiniteScalar(
                deltaLongitude))
        {
            return false;
        }

        const W p =
            pi!W;

        W deltaLongitudeHigh =
            deltaLongitude;

        W deltaLongitudeLow =
            cast(W) 0;

        bool useCompensatedLongitude =
            false;

        bool usePreparedEastLongitude =
            false;

        if (source.easting == _westEastingBoundary)
        {
            deltaLongitude =
                -p;
        }
        else if (source.easting == _eastLegalMaximum)
        {
            usePreparedEastLongitude =
                true;
        }
        else if (deltaLongitude >= -p
            && deltaLongitude < p)
        {
            quotientExpansion!T(
                deltaNumerator,
                _a,
                deltaLongitudeHigh,
                deltaLongitudeLow);

            useCompensatedLongitude =
                true;
        }
        else
        {
            return false;
        }

        Latitude!T latitude;

        if (source.northing == _northNorthingBoundary)
        {
            latitude =
                _northLatitude;
        }
        else if (source.northing == _southNorthingBoundary)
        {
            latitude =
                _southLatitude;
        }
        else
        {
            const W northingNumerator =
                cast(W) source.northing
                - _falseNorthingWorking;

            const W q =
                northingNumerator / _a;

            if (!isFiniteScalar(q))
                return false;

            T latitudeRadians;

            static if (is(T == double))
            {
                const real qExtended =
                    (
                        cast(real)
                            source.northing
                        - cast(real)
                            _falseNorthingWorking
                    )
                    / cast(real)
                        _a;

                if (!isFiniteScalar(qExtended))
                    return false;

                const real phiExtended =
                    atan(
                        sinh(
                            qExtended));

                if (!isFiniteScalar(phiExtended))
                    return false;

                latitudeRadians =
                    cast(T)
                        phiExtended;
            }
            else static if (is(T == real))
            {
                const real magnitude =
                    fabs(q);

                const real u =
                    expm1(
                        magnitude);

                const real phiMagnitude =
                    cast(real) 2
                    * atan2(
                        u,
                        u + cast(real) 2);

                const real phiReal =
                    copysign(
                        phiMagnitude,
                        q);

                if (!isFiniteScalar(phiReal))
                    return false;

                W qProduct;
                W qProductResidual;

                twoProduct!T(
                    _a,
                    q,
                    qProduct,
                    qProductResidual);

                const W qRemainder =
                    (
                        northingNumerator
                        - qProduct
                    )
                    - qProductResidual;

                const real qResidual =
                    qRemainder / _a;

                if (qResidual == cast(real) 0)
                {
                    latitudeRadians =
                        phiReal;
                }
                else
                {
                    const real expMagnitude =
                        u + cast(real) 1;

                    const real sechQ =
                        (
                            cast(real) 2
                            * expMagnitude
                        )
                        / (
                            expMagnitude
                            * expMagnitude
                            + cast(real) 1
                        );

                    const real latitudeCorrection =
                        qResidual
                        * sechQ;

                    const real correctedPhiReal =
                        phiReal
                        + latitudeCorrection;

                    if (!isFiniteScalar(
                            correctedPhiReal))
                    {
                        return false;
                    }

                    latitudeRadians =
                        correctedPhiReal;
                }
            }
            else
            {
                const W phi =
                    atan(
                        sinh(
                            q));

                if (!isFiniteScalar(phi))
                    return false;

                latitudeRadians =
                    cast(T)
                        phi;
            }

            if (!Latitude!T.tryFromRadians(
                    latitudeRadians,
                    latitude))
            {
                return false;
            }
        }

        Longitude!T longitude;

        if (usePreparedEastLongitude)
        {
            if (!Longitude!T.tryFromRadians(
                    _eastLegalLongitude,
                    longitude))
            {
                return false;
            }
        }
        else
        {
            const W longitudeWorking =
                useCompensatedLongitude
                    ? addLongitudeParts!T(
                        _longitudeOfNaturalOrigin.radians,
                        deltaLongitudeHigh,
                        deltaLongitudeLow)
                    : addLongitude!T(
                        _longitudeOfNaturalOrigin.radians,
                        deltaLongitude);

            if (!isFiniteScalar(
                    longitudeWorking))
            {
                return false;
            }

            const T longitudePublic =
                canonicalPublicRadians!T(
                    cast(T)
                        longitudeWorking);

            if (!Longitude!T.tryFromRadians(
                    longitudePublic,
                    longitude))
            {
                return false;
            }
        }

        longitude =
            longitude.normalized;

        result =
            GeographicCoordinate!T
                .fromComponents(
                    latitude,
                    longitude);

        return true;
    }


    /** Throwing convenience wrapper for \`tryReverse\`. */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(
                source,
                result))
        {
            throw new GeodesyValueException(
                "Pseudo-Mercator reverse projection failed or the point lies "
                ~ "outside the supported represented sheet.");
        }

        return result;
    }
}


unittest
{
    import std.exception :
        assertThrown;

    import std.math :
        fabs,
        nextDown;

    static assert(is(PseudoMercator!float));
    static assert(is(PseudoMercator!double));
    static assert(is(PseudoMercator!real));

    const invalid =
        PseudoMercator!double.init;

    assert(!invalid.isValid);

    ProjectedCoordinate!double invalidProjected;

    assert(!invalid.tryForward(
        GeographicCoordinate!double.init,
        invalidProjected));

    assertThrown!GeodesyValueException(
        invalid.forward(
            GeographicCoordinate!double.init));

    const earth =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257223563);

    const lon0 =
        Longitude!double.fromDegrees(
            0.0);

    const projection =
        PseudoMercator!double.fromParameters(
            earth,
            lon0,
            500_000.0,
            1_250_000.0);

    assert(projection.isValid);
    assert(projection.ellipsoid.semiMajorAxis == earth.semiMajorAxis);
    assert(projection.ellipsoid.flattening == earth.flattening);
    assert(projection.longitudeOfNaturalOrigin.radians == lon0.radians);
    assert(projection.falseEasting == 500_000.0);
    assert(projection.falseNorthing == 1_250_000.0);

    const origin =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            lon0);

    const projectedOrigin =
        projection.forward(
            origin);

    assert(projectedOrigin.easting == 500_000.0);
    assert(projectedOrigin.northing == 1_250_000.0);

    const source =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));

    const projected =
        projection.forward(
            source);

    const roundTrip =
        projection.reverse(
            projected);

    assert(fabs(
        roundTrip.latitude.radians
            - source.latitude.radians) < 2e-15);

    assert(fabs(
        roundTrip.longitude.radians
            - source.longitude.radians) < 2e-15);

    const northBoundary =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(88.0),
            lon0);

    assert(projection.tryForward(
        northBoundary,
        invalidProjected));

    const northOutside =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(88.0001),
            lon0);

    assert(!projection.tryForward(
        northOutside,
        invalidProjected));

    const sphere =
        Ellipsoid!double.sphere(
            earth.semiMajorAxis);

    const sphereProjection =
        PseudoMercator!double.fromParameters(
            sphere,
            lon0,
            500_000.0,
            1_250_000.0);

    const sphereProjected =
        sphereProjection.forward(
            source);

    assert(sphereProjected.easting == projected.easting);
    assert(sphereProjected.northing == projected.northing);

    const seamProjection =
        PseudoMercator!double.fromParameters(
            earth,
            Longitude!double.fromDegrees(180.0),
            500_000.0,
            1_250_000.0);

    const seamLongitude =
        Longitude!double.fromRadians(
            nextDown(
                cast(double) 0));

    const seamSource =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            seamLongitude);

    const seamProjected =
        seamProjection.forward(
            seamSource);

    const seamRoundTrip =
        seamProjection.reverse(
            seamProjected);

    assert(
        seamRoundTrip.longitude.radians
            == seamLongitude.radians);
}
