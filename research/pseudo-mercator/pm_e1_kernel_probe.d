/**
 * PM-E1B — complete research Pseudo-Mercator kernel.
 *
 * Research-only.
 *
 * Composes the already accepted pieces:
 *
 *   PM-B   q   = asinh(tan(phi))
 *   PM-C   phi = atan(sinh(q))
 *   PM-D   latitude/domain and [-pi,+pi) longitude policy
 *   PM-E1A represented easting endpoint policy
 *
 * This file is not production API.
 */
module pm_e1_kernel_probe;

import geodesy.angle :
    Latitude,
    Longitude;

import geodesy.geographic :
    GeographicCoordinate;

import geodesy.projected :
    ProjectedCoordinate;

import geodesy.scalar :
    isGeodesyScalar;

import std.math :
    PI,
    asinh,
    atan,
    fabs,
    isFinite,
    nextDown,
    nextUp,
    sinh,
    tan;

import std.conv :
    to;

import std.stdio :
    readln,
    writefln,
    writeln;

import std.string :
    split,
    strip;


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


private T pi(T)()
{
    return cast(T) PI;
}


private void twoSum(T)(
    const T a,
    const T b,
    out T sum,
    out T residual)
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


private WorkingScalar!T normalizeWorking(T)(
    WorkingScalar!T radians)
{
    alias W = WorkingScalar!T;

    const W p =
        pi!W;

    const W twoP =
        cast(W) 2 * p;

    if (radians >= p)
        radians -= twoP;
    else if (radians < -p)
        radians += twoP;

    if (radians >= p)
        radians -= twoP;
    else if (radians < -p)
        radians += twoP;

    return radians == cast(W) 0
        ? cast(W) 0
        : radians;
}


private void twoPiSplit(T)(
    out WorkingScalar!T high,
    out WorkingScalar!T low)
{
    alias W = WorkingScalar!T;

    static if (is(W == double))
    {
        /*
         * Use real as the preparation precision for the double split.
         *
         * high + low approximates mathematical 2*pi much more closely
         * than high alone.
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
         * 64-bit-significand x87-real split of mathematical 2*pi.
         *
         * high is nearest representable real.
         * low carries the residual that cannot be represented in high.
         *
         * Research-only constants for PM-E1C1.
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
            "Unexpected WorkingScalar");
    }
}


private void normalizeExpansion(T)(
    const WorkingScalar!T highInput,
    const WorkingScalar!T lowInput,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
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

    /*
     * Form an expansion for:
     *
     *     sum + residual
     *         + signedHigh + signedLow
     *
     * without immediately collapsing it back to one W.
     */
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

    /*
     * PM-D tie classification remains unchanged.
     *
     * Only the representation of the resulting principal delta changes:
     * it remains a two-term expansion for the forward linear operation.
     */
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

    /*
     * The subtraction itself is already an error-free twoSum expansion.
     * Keep it instead of collapsing sum + residual.
     */
    normalizeExpansion!T(
        sum,
        residual,
        high,
        low);
}


private WorkingScalar!T longitudeDifference(T)(
    const T longitude,
    const T longitude0)
{
    alias W = WorkingScalar!T;

    W high;
    W low;

    longitudeDifferenceParts!T(
        longitude,
        longitude0,
        high,
        low);

    /*
     * Existing consumers that require one W retain their old-shaped
     * interface. Forward easting uses the expansion directly below.
     */
    return high + low;
}


private void splitProductOperand(T)(
    const WorkingScalar!T value,
    out WorkingScalar!T high,
    out WorkingScalar!T low)
{
    alias W = WorkingScalar!T;

    W splitter;

    static if (is(W == double))
    {
        /*
         * p = 53 significant bits.
         *
         * splitter = 2^ceil(p/2) + 1
         *          = 2^27 + 1
         */
        splitter =
            cast(W) 134217729.0;
    }
    else static if (is(W == real))
    {
        /*
         * x86 extended real has p = 64 significant bits.
         *
         * splitter = 2^32 + 1
         */
        splitter =
            cast(W) 4294967297.0L;
    }
    else
    {
        static assert(
            false,
            "Unexpected WorkingScalar");
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
{
    alias W = WorkingScalar!T;

    /*
     * Dekker/Veltkamp error-free product.
     *
     * Research preconditions for this experiment:
     *
     * - finite operands;
     * - no product overflow;
     * - no underflow-sensitive case in the PM-E1C1 corpus;
     * - default round-to-nearest arithmetic.
     *
     * No FMA is used.
     */
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
{
    alias W = WorkingScalar!T;

    /*
     * Error-free product plus compensated addition.
     *
     * Research-only PM-E1C1 experiment for:
     *
     *     offset + scale * value
     *
     * Uses the already validated non-FMA twoProduct path.
     */
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
{
    alias W = WorkingScalar!T;

    /*
     * Keep both product rounding residuals.
     *
     * Exact target:
     *
     *   FE + a * (deltaHigh + deltaLow)
     */
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

    /*
     * First combine the dominant terms exactly with twoSum.
     */
    W mainSum;
    W mainSumResidual;

    twoSum(
        falseEasting,
        mainProduct,
        mainSum,
        mainSumResidual);

    /*
     * Collect all terms below the dominant mainSum.
     */
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

    /*
     * Fold the compact residual expansion back only at the final WorkingScalar
     * result boundary.
     */
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


private WorkingScalar!T addLongitude(T)(
    const T longitude0,
    const WorkingScalar!T delta)
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

    return normalizeWorking!T(
        sum + residual);
}


private bool validPublicLongitude(T)(
    const T radians)
{
    return isFinite(
            radians)
        && radians >= -pi!T
        && radians <= pi!T;
}


/*
 * Research-only characterization helper inherited from PM-E1A.
 *
 * This must not be mistaken for a production preparation algorithm.
 */
private bool findRepresentedEastMaximum(T)(
    const T longitude0,
    const T semiMajorAxis,
    const T falseEasting,
    out T representedEasting,
    out WorkingScalar!T legalDelta,
    out T legalLongitude)
{
    alias W = WorkingScalar!T;

    enum size_t searchRadius =
        4096;

    const W p =
        pi!W;

    const W origin =
        workingCanonicalLongitude!T(
            longitude0);

    const W twoP =
        cast(W) 2 * p;

    W opposite =
        origin + p;

    if (opposite >= p)
        opposite -= twoP;
    else if (opposite < -p)
        opposite += twoP;

    T centre =
        cast(T) opposite;

    const T publicPi =
        pi!T;

    if (!validPublicLongitude(
            centre))
    {
        centre =
            centre > cast(T) 0
                ? publicPi
                : -publicPi;
    }

    bool found = false;

    representedEasting =
        T.nan;

    legalDelta =
        -W.infinity;

    legalLongitude =
        T.nan;

    size_t bestDistance =
        size_t.max;


    void consider(
        const T candidate,
        const size_t distance)
    {
        if (!validPublicLongitude(
                candidate))
            return;

        W deltaHigh;
        W deltaLow;

        longitudeDifferenceParts!T(
            candidate,
            longitude0,
            deltaHigh,
            deltaLow);

        const W delta =
            deltaHigh
            + deltaLow;

        if (!(delta >= cast(W) 0)
            || !(delta < p))
            return;

        if (!found
            || delta > legalDelta)
        {
            const W easting =
                eastingFromLongitudeDifference!T(
                    cast(W) semiMajorAxis,
                    cast(W) falseEasting,
                    deltaHigh,
                    deltaLow);

            const T publicEasting =
                cast(T) easting;

            if (!isFinite(
                    publicEasting))
                return;

            found = true;

            legalDelta =
                delta;

            legalLongitude =
                candidate;

            representedEasting =
                publicEasting;

            bestDistance =
                distance;
        }
    }


    void scan(
        const T scanCentre)
    {
        consider(
            scanCentre,
            0);

        T lower =
            scanCentre;

        T upper =
            scanCentre;

        foreach (distance;
            1 .. searchRadius + 1)
        {
            lower =
                nextDown(lower);

            upper =
                nextUp(upper);

            consider(
                lower,
                distance);

            consider(
                upper,
                distance);
        }
    }


    scan(
        centre);

    if (centre == -publicPi)
        scan(publicPi);
    else if (centre == publicPi)
        scan(-publicPi);

    return found
        && bestDistance < searchRadius;
}


private struct ResearchPseudoMercator(T)
if (isGeodesyScalar!T)
{
    alias W =
        WorkingScalar!T;

private:

    bool _valid;

    T _semiMajorAxis;
    Longitude!T _longitudeOfNaturalOrigin;
    T _falseEasting;
    T _falseNorthing;

    W _a;
    W _falseEastingWorking;
    W _falseNorthingWorking;

    Latitude!T _southLatitude;
    Latitude!T _northLatitude;

    T _southNorthingBoundary;
    T _northNorthingBoundary;

    T _westEastingBoundary;

    T _eastLegalMaximum;
    W _eastLegalDelta;
    T _eastLegalLongitude;

public:

    static bool tryPrepare(
        const T semiMajorAxis,
        const Longitude!T longitudeOfNaturalOrigin,
        const T falseEasting,
        const T falseNorthing,
        out ResearchPseudoMercator result)
    {
        result =
            ResearchPseudoMercator.init;

        if (!isFinite(
                semiMajorAxis)
            || !(semiMajorAxis > cast(T) 0)
            || !isFinite(
                falseEasting)
            || !isFinite(
                falseNorthing))
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

        result._semiMajorAxis =
            semiMajorAxis;

        result._longitudeOfNaturalOrigin =
            longitudeOfNaturalOrigin;

        result._falseEasting =
            falseEasting;

        result._falseNorthing =
            falseNorthing;

        result._a =
            cast(W) semiMajorAxis;

        result._falseEastingWorking =
            cast(W) falseEasting;

        result._falseNorthingWorking =
            cast(W) falseNorthing;

        result._northLatitude =
            northLatitude;

        result._southLatitude =
            southLatitude;

        T northBoundary;
        T southBoundary;

        static if (is(T == double))
        {
            /*
             * PM-E1C1:
             *
             * Boundary anchors must be produced by the same numerical
             * forward path as ordinary represented double latitudes.
             *
             * Do not first round q to double and widen afterwards.
             */
            const real northPhiExtended =
                cast(real)
                    northLatitude.radians;

            const real southPhiExtended =
                cast(real)
                    southLatitude.radians;

            const real northQExtended =
                asinh(
                    tan(
                        northPhiExtended));

            const real southQExtended =
                asinh(
                    tan(
                        southPhiExtended));

            northBoundary =
                cast(T)
                    affineProductSum!real(
                        cast(real)
                            result._a,
                        northQExtended,
                        cast(real)
                            result._falseNorthingWorking);

            southBoundary =
                cast(T)
                    affineProductSum!real(
                        cast(real)
                            result._a,
                        southQExtended,
                        cast(real)
                            result._falseNorthingWorking);
        }
        else
        {
            const W northPhi =
                cast(W)
                    northLatitude.radians;

            const W southPhi =
                cast(W)
                    southLatitude.radians;

            const W northQ =
                asinh(
                    tan(
                        northPhi));

            const W southQ =
                asinh(
                    tan(
                        southPhi));

            northBoundary =
                cast(T)
                    affineProductSum!T(
                        result._a,
                        northQ,
                        result._falseNorthingWorking);

            southBoundary =
                cast(T)
                    affineProductSum!T(
                        result._a,
                        southQ,
                        result._falseNorthingWorking);
        }

        if (!isFinite(
                northBoundary)
            || !isFinite(
                southBoundary)
            || !(southBoundary
                < northBoundary))
        {
            return false;
        }

        result._northNorthingBoundary =
            northBoundary;

        result._southNorthingBoundary =
            southBoundary;

        result._westEastingBoundary =
            cast(T) (
                result._falseEastingWorking
                - result._a * pi!W);

        if (!isFinite(
                result._westEastingBoundary))
        {
            return false;
        }

        if (!findRepresentedEastMaximum!T(
                longitudeOfNaturalOrigin.radians,
                semiMajorAxis,
                falseEasting,
                result._eastLegalMaximum,
                result._eastLegalDelta,
                result._eastLegalLongitude))
        {
            return false;
        }

        result._valid =
            true;

        return true;
    }


    @property bool isValid() const
    {
        return _valid;
    }


    @property T southNorthingBoundary() const
    {
        return _southNorthingBoundary;
    }


    @property T northNorthingBoundary() const
    {
        return _northNorthingBoundary;
    }


    @property T westEastingBoundary() const
    {
        return _westEastingBoundary;
    }


    @property T eastLegalMaximum() const
    {
        return _eastLegalMaximum;
    }


    @property W eastLegalDelta() const
    {
        return _eastLegalDelta;
    }


    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
    {
        result =
            ProjectedCoordinate!T.init;

        if (!_valid)
            return false;

        const T latitudePublic =
            source.latitude.radians;

        if (latitudePublic
                < _southLatitude.radians
            || latitudePublic
                > _northLatitude.radians)
        {
            return false;
        }

        const W phi =
            cast(W)
                latitudePublic;

        W deltaLongitudeHigh;
        W deltaLongitudeLow;

        longitudeDifferenceParts!T(
            source.longitude.radians,
            _longitudeOfNaturalOrigin.radians,
            deltaLongitudeHigh,
            deltaLongitudeLow);

        const W deltaLongitude =
            deltaLongitudeHigh
            + deltaLongitudeLow;

        const W q =
            asinh(
                tan(
                    phi));

        const W easting =
            eastingFromLongitudeDifference!T(
                _a,
                _falseEastingWorking,
                deltaLongitudeHigh,
                deltaLongitudeLow);

        W northing;

        static if (is(T == double))
        {
            /*
             * PM-E1C1 research experiment:
             *
             * Preserve more than binary64 precision across the complete
             * q -> affine-Northing chain.
             *
             * The public latitude remains exactly the represented double
             * input.  Only the internal evaluation is widened to real.
             */
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
            northing =
                affineProductSum!T(
                    _a,
                    q,
                    _falseNorthingWorking);
        }

        if (!isFinite(
                easting)
            || !isFinite(
                northing))
        {
            return false;
        }

        return ProjectedCoordinate!T
            .tryFromComponents(
                cast(T) easting,
                cast(T) northing,
                result);
    }


    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
    {
        result =
            GeographicCoordinate!T.init;

        if (!_valid)
            return false;

        /*
         * PM-D northing classification occurs before R2.
         */
        if (source.northing
                < _southNorthingBoundary
            || source.northing
                > _northNorthingBoundary)
        {
            return false;
        }

        W deltaLongitude =
            (
                cast(W) source.easting
                - _falseEastingWorking
            ) / _a;

        if (!isFinite(
                deltaLongitude))
        {
            return false;
        }

        const W p =
            pi!W;

        /*
         * PM-E1A easting classifier.
         */
        if (deltaLongitude >= -p
            && deltaLongitude < p)
        {
            // Ordinary represented point.
        }
        else if (source.easting
            == _westEastingBoundary)
        {
            deltaLongitude =
                -p;
        }
        else if (source.easting
            == _eastLegalMaximum)
        {
            deltaLongitude =
                _eastLegalDelta;
        }
        else
        {
            return false;
        }

        Latitude!T latitude;

        if (source.northing
            == _northNorthingBoundary)
        {
            latitude =
                _northLatitude;
        }
        else if (source.northing
            == _southNorthingBoundary)
        {
            latitude =
                _southLatitude;
        }
        else
        {
            const W q =
                (
                    cast(W) source.northing
                    - _falseNorthingWorking
                ) / _a;

            if (!isFinite(
                    q))
            {
                return false;
            }

            const W phi =
                atan(
                    sinh(
                        q));

            if (!isFinite(
                    phi)
                || !Latitude!T.tryFromRadians(
                    cast(T) phi,
                    latitude))
            {
                return false;
            }
        }

        const W longitudeWorking =
            addLongitude!T(
                _longitudeOfNaturalOrigin.radians,
                deltaLongitude);

        if (!isFinite(
                longitudeWorking))
        {
            return false;
        }

        const T longitudePublic =
            canonicalPublicRadians!T(
                cast(T)
                    longitudeWorking);

        Longitude!T longitude;

        if (!Longitude!T.tryFromRadians(
                longitudePublic,
                longitude))
        {
            return false;
        }

        /*
         * Enforce the unique public reverse representation.
         */
        longitude =
            longitude.normalized;

        result =
            GeographicCoordinate!T
                .fromComponents(
                    latitude,
                    longitude);

        return true;
    }
}


private bool makeGeographic(T)(
    const real latitudeDegrees,
    const real longitudeDegrees,
    out GeographicCoordinate!T result)
{
    Latitude!T latitude;
    Longitude!T longitude;

    if (!Latitude!T.tryFromDegrees(
            cast(T) latitudeDegrees,
            latitude)
        || !Longitude!T.tryFromDegrees(
            cast(T) longitudeDegrees,
            longitude))
    {
        result =
            GeographicCoordinate!T.init;

        return false;
    }

    result =
        GeographicCoordinate!T
            .fromComponents(
                latitude,
                longitude);

    return true;
}


private WorkingScalar!T angularError(T)(
    const T actual,
    const T expected)
{
    alias W =
        WorkingScalar!T;

    W difference =
        cast(W) actual
        - cast(W) expected;

    const W p =
        pi!W;

    const W twoP =
        cast(W) 2 * p;

    if (difference >= p)
        difference -= twoP;
    else if (difference < -p)
        difference += twoP;

    return fabs(
        difference);
}


private void check(
    const bool condition,
    const string scalarName,
    const string profileName,
    const string label,
    ref size_t failures)
{
    if (condition)
        return;

    ++failures;

    writefln(
        "FAIL\t%s\t%s\t%s",
        scalarName,
        profileName,
        label);
}


private void probeProfile(T)(
    const string scalarName,
    const string profileName,
    const real longitude0Degrees,
    const T semiMajorAxis,
    const T falseEasting,
    const T falseNorthing,
    ref size_t failures)
{
    alias W =
        WorkingScalar!T;

    Longitude!T longitude0;

    const bool originOk =
        Longitude!T.tryFromDegrees(
            cast(T) longitude0Degrees,
            longitude0);

    check(
        originOk,
        scalarName,
        profileName,
        "construct_origin",
        failures);

    if (!originOk)
        return;

    ResearchPseudoMercator!T projection;

    const bool prepared =
        ResearchPseudoMercator!T
            .tryPrepare(
                semiMajorAxis,
                longitude0,
                falseEasting,
                falseNorthing,
                projection);

    check(
        prepared,
        scalarName,
        profileName,
        "prepare",
        failures);

    if (!prepared)
        return;

    /*
     * Exact forward latitude boundaries.
     */
    GeographicCoordinate!T northSource;
    GeographicCoordinate!T southSource;

    Latitude!T northLatitude;
    Latitude!T southLatitude;

    const bool northLatOk =
        Latitude!T.tryFromDegrees(
            cast(T) 88,
            northLatitude);

    const bool southLatOk =
        Latitude!T.tryFromDegrees(
            cast(T) -88,
            southLatitude);

    check(
        northLatOk && southLatOk,
        scalarName,
        profileName,
        "construct_latitude_boundaries",
        failures);

    if (!(northLatOk && southLatOk))
        return;

    northSource =
        GeographicCoordinate!T
            .fromComponents(
                northLatitude,
                longitude0);

    southSource =
        GeographicCoordinate!T
            .fromComponents(
                southLatitude,
                longitude0);

    ProjectedCoordinate!T northProjected;
    ProjectedCoordinate!T southProjected;

    check(
        projection.tryForward(
            northSource,
            northProjected),
        scalarName,
        profileName,
        "forward_north_88",
        failures);

    check(
        projection.tryForward(
            southSource,
            southProjected),
        scalarName,
        profileName,
        "forward_south_88",
        failures);

    if (projection.tryForward(
            northSource,
            northProjected))
    {
        check(
            northProjected.northing
                == projection
                    .northNorthingBoundary,
            scalarName,
            profileName,
            "north_boundary_anchor",
            failures);
    }

    if (projection.tryForward(
            southSource,
            southProjected))
    {
        check(
            southProjected.northing
                == projection
                    .southNorthingBoundary,
            scalarName,
            profileName,
            "south_boundary_anchor",
            failures);
    }

    /*
     * First represented public latitude outside +/-88 must reject.
     */
    Latitude!T outsideNorthLatitude;
    Latitude!T outsideSouthLatitude;

    const bool outsideNorthConstructed =
        Latitude!T.tryFromRadians(
            nextUp(
                northLatitude.radians),
            outsideNorthLatitude);

    const bool outsideSouthConstructed =
        Latitude!T.tryFromRadians(
            nextDown(
                southLatitude.radians),
            outsideSouthLatitude);

    check(
        outsideNorthConstructed,
        scalarName,
        profileName,
        "construct_latitude_north_outside",
        failures);

    check(
        outsideSouthConstructed,
        scalarName,
        profileName,
        "construct_latitude_south_outside",
        failures);

    if (outsideNorthConstructed)
    {
        const outsideNorth =
            GeographicCoordinate!T
                .fromComponents(
                    outsideNorthLatitude,
                    longitude0);

        ProjectedCoordinate!T ignored;

        check(
            !projection.tryForward(
                outsideNorth,
                ignored),
            scalarName,
            profileName,
            "reject_latitude_north_outside",
            failures);
    }

    if (outsideSouthConstructed)
    {
        const outsideSouth =
            GeographicCoordinate!T
                .fromComponents(
                    outsideSouthLatitude,
                    longitude0);

        ProjectedCoordinate!T ignored;

        check(
            !projection.tryForward(
                outsideSouth,
                ignored),
            scalarName,
            profileName,
            "reject_latitude_south_outside",
            failures);
    }

    /*
     * Reverse northing represented boundaries and nextOutside.
     */
    const T centreEasting =
        falseEasting;

    ProjectedCoordinate!T projected;

    GeographicCoordinate!T geographic;

    if (ProjectedCoordinate!T.tryFromComponents(
            centreEasting,
            projection.northNorthingBoundary,
            projected))
    {
        check(
            projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reverse_north_boundary",
            failures);

        if (projection.tryReverse(
                projected,
                geographic))
        {
            check(
                geographic.latitude.radians
                    == northLatitude.radians,
                scalarName,
                profileName,
                "reverse_north_boundary_exact",
                failures);
        }
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            centreEasting,
            projection.southNorthingBoundary,
            projected))
    {
        check(
            projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reverse_south_boundary",
            failures);

        if (projection.tryReverse(
                projected,
                geographic))
        {
            check(
                geographic.latitude.radians
                    == southLatitude.radians,
                scalarName,
                profileName,
                "reverse_south_boundary_exact",
                failures);
        }
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            centreEasting,
            nextUp(
                projection
                    .northNorthingBoundary),
            projected))
    {
        check(
            !projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reject_northing_next_outside",
            failures);
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            centreEasting,
            nextDown(
                projection
                    .southNorthingBoundary),
            projected))
    {
        check(
            !projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reject_south_northing_next_outside",
            failures);
    }

    /*
     * Reverse easting boundaries and nextOutside.
     */
    const T centreNorthing =
        falseNorthing;

    if (ProjectedCoordinate!T.tryFromComponents(
            projection.westEastingBoundary,
            centreNorthing,
            projected))
    {
        check(
            projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reverse_west_easting_boundary",
            failures);

        if (projection.tryReverse(
                projected,
                geographic))
        {
            check(
                geographic.longitude.radians
                    < pi!T,
                scalarName,
                profileName,
                "west_reverse_canonical_longitude",
                failures);
        }
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            nextDown(
                projection
                    .westEastingBoundary),
            centreNorthing,
            projected))
    {
        check(
            !projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reject_west_easting_next_outside",
            failures);
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            projection.eastLegalMaximum,
            centreNorthing,
            projected))
    {
        check(
            projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reverse_east_legal_maximum",
            failures);

        if (projection.tryReverse(
                projected,
                geographic))
        {
            check(
                geographic.longitude.radians
                    < pi!T,
                scalarName,
                profileName,
                "east_reverse_canonical_longitude",
                failures);
        }
    }

    if (ProjectedCoordinate!T.tryFromComponents(
            nextUp(
                projection
                    .eastLegalMaximum),
            centreNorthing,
            projected))
    {
        check(
            !projection.tryReverse(
                projected,
                geographic),
            scalarName,
            profileName,
            "reject_east_easting_next_outside",
            failures);
    }

    /*
     * Exact +pi tie control at zero central meridian.
     */
    if (longitude0Degrees == 0.0L)
    {
        GeographicCoordinate!T east180;
        GeographicCoordinate!T west180;

        const bool eastOk =
            makeGeographic!T(
                0.0L,
                180.0L,
                east180);

        const bool westOk =
            makeGeographic!T(
                0.0L,
                -180.0L,
                west180);

        check(
            eastOk && westOk,
            scalarName,
            profileName,
            "construct_antimeridian_tie",
            failures);

        if (eastOk && westOk)
        {
            ProjectedCoordinate!T eastProjected;
            ProjectedCoordinate!T westProjected;

            const bool eastForward =
                projection.tryForward(
                    east180,
                    eastProjected);

            const bool westForward =
                projection.tryForward(
                    west180,
                    westProjected);

            check(
                eastForward && westForward,
                scalarName,
                profileName,
                "forward_antimeridian_tie",
                failures);

            if (eastForward && westForward)
            {
                check(
                    eastProjected.easting
                        == westProjected.easting
                    && eastProjected.northing
                        == westProjected.northing,
                    scalarName,
                    profileName,
                    "plus_pi_tie_matches_minus_pi",
                    failures);

                check(
                    eastProjected.easting
                        == projection
                            .westEastingBoundary,
                    scalarName,
                    profileName,
                    "plus_pi_tie_uses_west_sheet_edge",
                    failures);
            }
        }
    }

    /*
     * Representative complete forward/reverse corpus.
     *
     * Numerical accuracy is characterized more strictly in PM-E1C.
     * E1B requires accepted finite round trips and records their maxima.
     */
    const real[8] latitudeDegrees =
    [
        0.0L,
        45.0L,
        -45.0L,
        80.0L,
        85.0511287798066L,
        88.0L,
        -88.0L,
        12.345L
    ];

    const real[8] longitudeDegrees =
    [
        0.0L,
        12.5L,
        -37.0L,
        179.75L,
        -179.75L,
        170.0L,
        -170.0L,
        90.0L
    ];

    W maxLatitudeError =
        cast(W) 0;

    W maxLongitudeError =
        cast(W) 0;

    size_t roundTrips;

    foreach (i; 0 .. latitudeDegrees.length)
    {
        GeographicCoordinate!T source;

        const bool sourceOk =
            makeGeographic!T(
                latitudeDegrees[i],
                longitudeDegrees[i],
                source);

        check(
            sourceOk,
            scalarName,
            profileName,
            "construct_roundtrip_source",
            failures);

        if (!sourceOk)
            continue;

        ProjectedCoordinate!T forward;

        const bool forwardOk =
            projection.tryForward(
                source,
                forward);

        check(
            forwardOk,
            scalarName,
            profileName,
            "roundtrip_forward",
            failures);

        if (!forwardOk)
            continue;

        GeographicCoordinate!T reverse;

        const bool reverseOk =
            projection.tryReverse(
                forward,
                reverse);

        check(
            reverseOk,
            scalarName,
            profileName,
            "roundtrip_reverse",
            failures);

        if (!reverseOk)
            continue;

        ++roundTrips;

        const W latitudeError =
            fabs(
                cast(W)
                    reverse.latitude.radians
                - cast(W)
                    source.latitude.radians);

        const W longitudeError =
            angularError!T(
                reverse.longitude.radians,
                source.longitude
                    .normalized.radians);

        if (latitudeError
            > maxLatitudeError)
        {
            maxLatitudeError =
                latitudeError;
        }

        if (longitudeError
            > maxLongitudeError)
        {
            maxLongitudeError =
                longitudeError;
        }

        check(
            isFinite(
                latitudeError)
            && isFinite(
                longitudeError),
            scalarName,
            profileName,
            "roundtrip_finite_error",
            failures);

        check(
            reverse.longitude.radians
                < pi!T,
            scalarName,
            profileName,
            "roundtrip_canonical_longitude",
            failures);
    }

    writefln(
        "SUMMARY\t%s\t%s\t"
        ~ "roundtrips=%u\t"
        ~ "max_lat_rad=%.40g\t"
        ~ "max_lon_rad=%.40g\t"
        ~ "southN=%.40g\t"
        ~ "northN=%.40g\t"
        ~ "westE=%.40g\t"
        ~ "eastE=%.40g",
        scalarName,
        profileName,
        roundTrips,
        maxLatitudeError,
        maxLongitudeError,
        projection.southNorthingBoundary,
        projection.northNorthingBoundary,
        projection.westEastingBoundary,
        projection.eastLegalMaximum);
}


private void probeScalar(T)(
    const string scalarName,
    ref size_t failures)
{
    probeProfile!T(
        scalarName,
        "unit_lon0_0",
        0.0L,
        cast(T) 1,
        cast(T) 0,
        cast(T) 0,
        failures);

    probeProfile!T(
        scalarName,
        "wgs84_lon0_0",
        0.0L,
        cast(T) 6_378_137,
        cast(T) 0,
        cast(T) 0,
        failures);

    probeProfile!T(
        scalarName,
        "wgs84_offset_lon0_170",
        170.0L,
        cast(T) 6_378_137,
        cast(T) 500_000,
        cast(T) -2_000_000,
        failures);

    probeProfile!T(
        scalarName,
        "wgs84_offset_lon0_minus170",
        -170.0L,
        cast(T) 6_378_137,
        cast(T) -250_000,
        cast(T) 1_250_000,
        failures);

    probeProfile!T(
        scalarName,
        "wgs84_offset_lon0_179_75",
        179.75L,
        cast(T) 6_378_137,
        cast(T) 500_000,
        cast(T) -2_000_000,
        failures);

    probeProfile!T(
        scalarName,
        "wgs84_offset_lon0_minus179_75",
        -179.75L,
        cast(T) 6_378_137,
        cast(T) -250_000,
        cast(T) 1_250_000,
        failures);
}


version (PseudoMercatorDifferential)
{
    /*
     * PM-E1C machine-readable driver.
     *
     * Input records are whitespace-separated.
     *
     * B:
     *   B id scalar a lon0_deg FE FN
     *
     * F:
     *   F id scalar a lon0_deg FE FN lat_deg lon_deg
     *
     * R:
     *   R id scalar a lon0_deg FE FN easting northing
     *
     * scalar is one of:
     *
     *   float
     *   double
     *   real
     *
     * Every OK record echoes the represented public scalar inputs that
     * actually entered the D kernel.  PM-E1C can therefore separate:
     *
     * - decimal-input representation error;
     * - projection arithmetic error;
     * - projected-coordinate representation error.
     */
    private bool prepareDifferential(T)(
        const string[] fields,
        out ResearchPseudoMercator!T projection,
        out T semiMajorAxis,
        out Longitude!T longitude0,
        out T falseEasting,
        out T falseNorthing)
    {
        semiMajorAxis =
            fields[3].to!T;

        falseEasting =
            fields[5].to!T;

        falseNorthing =
            fields[6].to!T;

        if (!Longitude!T.tryFromDegrees(
                fields[4].to!T,
                longitude0))
        {
            return false;
        }

        return ResearchPseudoMercator!T
            .tryPrepare(
                semiMajorAxis,
                longitude0,
                falseEasting,
                falseNorthing,
                projection);
    }


    private void differentialBoundary(T)(
        const string[] fields,
        const string scalarName)
    {
        if (fields.length != 7)
        {
            writefln(
                "ERROR\t%s\tB\t%s\tfields=%u",
                fields.length >= 2 ? fields[1] : "?",
                scalarName,
                fields.length);

            return;
        }

        ResearchPseudoMercator!T projection;
        T semiMajorAxis;
        Longitude!T longitude0;
        T falseEasting;
        T falseNorthing;

        if (!prepareDifferential!T(
                fields,
                projection,
                semiMajorAxis,
                longitude0,
                falseEasting,
                falseNorthing))
        {
            writefln(
                "REJECT\t%s\tB\t%s\tprepare",
                fields[1],
                scalarName);

            return;
        }

        writefln(
            "BOK\t%s\t%s\t"
            ~ "a=%.40g\t"
            ~ "lon0_rad=%.40g\t"
            ~ "fe=%.40g\t"
            ~ "fn=%.40g\t"
            ~ "southN=%.40g\t"
            ~ "northN=%.40g\t"
            ~ "westE=%.40g\t"
            ~ "eastE=%.40g\t"
            ~ "eastDelta=%.40g",
            fields[1],
            scalarName,
            semiMajorAxis,
            longitude0.radians,
            falseEasting,
            falseNorthing,
            projection.southNorthingBoundary,
            projection.northNorthingBoundary,
            projection.westEastingBoundary,
            projection.eastLegalMaximum,
            projection.eastLegalDelta);
    }


    private void differentialForward(T)(
        const string[] fields,
        const string scalarName)
    {
        if (fields.length != 9)
        {
            writefln(
                "ERROR\t%s\tF\t%s\tfields=%u",
                fields.length >= 2 ? fields[1] : "?",
                scalarName,
                fields.length);

            return;
        }

        ResearchPseudoMercator!T projection;
        T semiMajorAxis;
        Longitude!T longitude0;
        T falseEasting;
        T falseNorthing;

        if (!prepareDifferential!T(
                fields,
                projection,
                semiMajorAxis,
                longitude0,
                falseEasting,
                falseNorthing))
        {
            writefln(
                "REJECT\t%s\tF\t%s\tprepare",
                fields[1],
                scalarName);

            return;
        }

        Latitude!T latitude;
        Longitude!T longitude;

        if (!Latitude!T.tryFromDegrees(
                fields[7].to!T,
                latitude)
            || !Longitude!T.tryFromDegrees(
                fields[8].to!T,
                longitude))
        {
            writefln(
                "REJECT\t%s\tF\t%s\tinput",
                fields[1],
                scalarName);

            return;
        }

        const source =
            GeographicCoordinate!T
                .fromComponents(
                    latitude,
                    longitude);

        ProjectedCoordinate!T projected;

        if (!projection.tryForward(
                source,
                projected))
        {
            writefln(
                "REJECT\t%s\tF\t%s\tdomain",
                fields[1],
                scalarName);

            return;
        }

        writefln(
            "FOK\t%s\t%s\t"
            ~ "a=%.40g\t"
            ~ "lon0_rad=%.40g\t"
            ~ "fe=%.40g\t"
            ~ "fn=%.40g\t"
            ~ "lat_rad=%.40g\t"
            ~ "lon_rad=%.40g\t"
            ~ "e=%.40g\t"
            ~ "n=%.40g",
            fields[1],
            scalarName,
            semiMajorAxis,
            longitude0.radians,
            falseEasting,
            falseNorthing,
            latitude.radians,
            longitude.radians,
            projected.easting,
            projected.northing);
    }


    private void differentialReverse(T)(
        const string[] fields,
        const string scalarName)
    {
        if (fields.length != 9)
        {
            writefln(
                "ERROR\t%s\tR\t%s\tfields=%u",
                fields.length >= 2 ? fields[1] : "?",
                scalarName,
                fields.length);

            return;
        }

        ResearchPseudoMercator!T projection;
        T semiMajorAxis;
        Longitude!T longitude0;
        T falseEasting;
        T falseNorthing;

        if (!prepareDifferential!T(
                fields,
                projection,
                semiMajorAxis,
                longitude0,
                falseEasting,
                falseNorthing))
        {
            writefln(
                "REJECT\t%s\tR\t%s\tprepare",
                fields[1],
                scalarName);

            return;
        }

        const T easting =
            fields[7].to!T;

        const T northing =
            fields[8].to!T;

        ProjectedCoordinate!T source;

        if (!ProjectedCoordinate!T
                .tryFromComponents(
                    easting,
                    northing,
                    source))
        {
            writefln(
                "REJECT\t%s\tR\t%s\tinput",
                fields[1],
                scalarName);

            return;
        }

        GeographicCoordinate!T geographic;

        if (!projection.tryReverse(
                source,
                geographic))
        {
            writefln(
                "REJECT\t%s\tR\t%s\tdomain",
                fields[1],
                scalarName);

            return;
        }

        writefln(
            "ROK\t%s\t%s\t"
            ~ "a=%.40g\t"
            ~ "lon0_rad=%.40g\t"
            ~ "fe=%.40g\t"
            ~ "fn=%.40g\t"
            ~ "e=%.40g\t"
            ~ "n=%.40g\t"
            ~ "lat_rad=%.40g\t"
            ~ "lon_rad=%.40g",
            fields[1],
            scalarName,
            semiMajorAxis,
            longitude0.radians,
            falseEasting,
            falseNorthing,
            easting,
            northing,
            geographic.latitude.radians,
            geographic.longitude.radians);
    }


    private void dispatchDifferential(T)(
        const string[] fields,
        const string scalarName)
    {
        if (fields[0] == "B")
        {
            differentialBoundary!T(
                fields,
                scalarName);

            return;
        }

        if (fields[0] == "F")
        {
            differentialForward!T(
                fields,
                scalarName);

            return;
        }

        if (fields[0] == "R")
        {
            differentialReverse!T(
                fields,
                scalarName);

            return;
        }

        writefln(
            "ERROR\t%s\t%s\t%s\tunknown-command",
            fields.length >= 2 ? fields[1] : "?",
            fields[0],
            scalarName);
    }


    void main()
    {
        string line;

        while ((line = readln()) !is null)
        {
            const stripped =
                line.strip;

            if (stripped.length == 0
                || stripped[0] == '#')
            {
                continue;
            }

            const fields =
                stripped.split;

            if (fields.length < 3)
            {
                writefln(
                    "ERROR\t?\t?\t?\tfields=%u",
                    fields.length);

                continue;
            }

            const scalarName =
                fields[2];

            if (scalarName == "float")
            {
                dispatchDifferential!float(
                    fields,
                    scalarName);
            }
            else if (scalarName == "double")
            {
                dispatchDifferential!double(
                    fields,
                    scalarName);
            }
            else if (scalarName == "real")
            {
                dispatchDifferential!real(
                    fields,
                    scalarName);
            }
            else
            {
                writefln(
                    "ERROR\t%s\t%s\t%s\tunknown-scalar",
                    fields[1],
                    fields[0],
                    scalarName);
            }
        }
    }
}
else
{
    void main()
    {
        writeln(
            "# PM-E1B complete research kernel probe");

        size_t failures;

        probeScalar!float(
            "float",
            failures);

        probeScalar!double(
            "double",
            failures);

        probeScalar!real(
            "real",
            failures);

        writefln(
            "RESULT\tfailures=%u",
            failures);

        if (failures != 0)
            throw new Exception(
                "PM-E1B research kernel probe failed.");
    }
}
