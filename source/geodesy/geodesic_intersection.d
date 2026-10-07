/**
 * Robust ellipsoidal intersection for bounded geodesic segments.
 *
 * This module implements the bounded shortest-segment slice of Karney's
 * geodesic-intersection method. Two endpoint pairs define oriented shortest
 * geodesic segments. A successful operation returns one geometric result:
 *
 * - `none`: the finite segments have no common point;
 * - `point`: the finite segments share exactly one point;
 * - `overlap`: coincident supporting geodesics overlap over a non-zero
 *   bounded interval.
 *
 * Coincident segments expose the actual geographic endpoints of the bounded
 * overlap. GeographicLib's internal displacement/mode representation is not
 * leaked through the public API.
 *
 * The solver uses prepared `GeodesicLine` values and Karney's iterative local
 * spherical correction. It does not project the problem into an ordinary
 * planar CRS.
 *
 * Endpoint pairs must define non-degenerate, unambiguous shortest geodesics.
 * Exact antipodes and Karney's oblate equal-and-opposite-latitude
 * multiple-shortest-geodesic case are rejected by the checked operation.
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 *
 * Date:
 *     October 7, 2026
 */
module geodesy.geodesic_intersection;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid :
    wgs84;
import geodesy.errors :
    GeodesyValueException;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult,
    GeodesicLine,
    GeodesicQuantities;
import geodesy.geographic :
    GeographicCoordinate;
import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;

import std.math :
    PI,
    abs,
    atan2,
    atanh,
    cos,
    copysign,
    pow,
    sin,
    sqrt;


/**
 * Geometric result kind for two bounded geodesic segments.
 *
 * `invalid` is reserved for `.init` and checked-operation failure.
 */
enum GeodesicSegmentIntersectionKind
{
    invalid,
    none,
    point,
    overlap
}

/// Example distinguishing point and overlap intersections.
@safe unittest
{
    assert(GeodesicSegmentIntersectionKind.point
        != GeodesicSegmentIntersectionKind.overlap);
}


/**
 * Result of intersecting two bounded shortest ellipsoidal geodesic segments.
 *
 * For `none`, no point properties are meaningful.
 * For `point`, `firstPoint == secondPoint`.
 * For `overlap`, the two points are the endpoints of the common bounded
 * interval, ordered along the first input segment.
 *
 * `.init` is invalid.
 */
struct GeodesicSegmentIntersectionResult(T)
if (isGeodesyScalar!T)
{
private:
    GeodesicSegmentIntersectionKind _kind =
        GeodesicSegmentIntersectionKind.invalid;
    GeographicCoordinate!T _firstPoint;
    GeographicCoordinate!T _secondPoint;

    /** Construct a result from already validated geometric components. */
    static GeodesicSegmentIntersectionResult fromComponents(
        const GeodesicSegmentIntersectionKind kind,
        const GeographicCoordinate!T firstPoint,
        const GeographicCoordinate!T secondPoint)
        pure nothrow @safe @nogc
    {
        GeodesicSegmentIntersectionResult result;
        result._kind = kind;
        result._firstPoint = firstPoint;
        result._secondPoint = secondPoint;
        return result;
    }

    /** Construct a valid no-intersection result. */
    static GeodesicSegmentIntersectionResult noIntersection()
        pure nothrow @safe @nogc
    {
        GeodesicSegmentIntersectionResult result;
        result._kind = GeodesicSegmentIntersectionKind.none;
        return result;
    }

public:
    /** True when the operation produced a valid geometric result. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _kind != GeodesicSegmentIntersectionKind.invalid;
    }

    /// Example checking the default invalid state.
    @safe unittest
    {
        assert(!GeodesicSegmentIntersectionResult!double.init.isValid);
    }

    /** Geometric intersection classification. */
    @property GeodesicSegmentIntersectionKind kind() const
        pure nothrow @safe @nogc
    {
        return _kind;
    }

    /// Example reading the default result kind.
    @safe unittest
    {
        GeodesicSegmentIntersectionResult!double result;
        assert(result.kind == GeodesicSegmentIntersectionKind.invalid);
    }

    /**
     * Point intersection or first overlap endpoint.
     *
     * Meaningful only for `point` and `overlap`.
     */
    @property GeographicCoordinate!T firstPoint() const
        pure nothrow @safe @nogc
    {
        return _firstPoint;
    }

    /// Example reading the first point from an invalid result.
    @safe unittest
    {
        GeodesicSegmentIntersectionResult!double result;
        cast(void) result.firstPoint;
    }

    /**
     * Point intersection or second overlap endpoint.
     *
     * For `point`, this equals `firstPoint`. For `overlap`, endpoints are
     * ordered in the direction of the first input segment.
     */
    @property GeographicCoordinate!T secondPoint() const
        pure nothrow @safe @nogc
    {
        return _secondPoint;
    }

    /// Example reading the second point from an invalid result.
    @safe unittest
    {
        GeodesicSegmentIntersectionResult!double result;
        cast(void) result.secondPoint;
    }
}

/// Example using the bounded segment-intersection result type.
@safe unittest
{
    GeodesicSegmentIntersectionResult!double result;
    assert(!result.isValid);
    assert(result.kind == GeodesicSegmentIntersectionKind.invalid);
}


private template IntersectionWorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias IntersectionWorkingScalar = double;
    else
        alias IntersectionWorkingScalar = T;
}


private struct IntersectionDisplacement(W)
{
    W x;
    W y;
    int coincidence;
}


private struct PreparedSegment(T)
if (isGeodesyScalar!T)
{
    T length;
    GeodesicLine!T line;
}


/** Normalize a working angle to [-pi,+pi). */
private W wrapIntersectionPi(W)(W value)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    const W pi = cast(W) PI;
    const W period = cast(W) 2 * pi;

    value %= period;

    if (value >= pi)
        value -= period;
    else if (value < -pi)
        value += period;

    return value == cast(W) 0
        ? cast(W) 0
        : value;
}


/** Return whether two canonical coordinates are exactly antipodal. */
private bool areExactAntipodes(T)(
    const GeographicCoordinate!T first,
    const GeographicCoordinate!T second)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    const W latitudeSum =
        cast(W) first.latitude.radians
        + cast(W) second.latitude.radians;

    const W longitudeDifference =
        abs(
            wrapIntersectionPi!W(
                cast(W) second.longitude.radians
                - cast(W) first.longitude.radians));

    return latitudeSum == cast(W) 0
        && longitudeDifference == cast(W) PI;
}


/**
 * Detect the oblate inverse-geodesic symmetry that yields two equally short
 * geodesics.
 *
 * GeographicLib documents this case for lat1 == -lat2 away from the poles:
 * the solution is unique only when the two endpoint forward azimuths are
 * equal. Exact antipodes and coincident points are handled separately.
 */
private bool hasAmbiguousShortestGeodesic(T)(
    const GeographicCoordinate!T first,
    const GeographicCoordinate!T second,
    const GeodesicInverseResult!T inverse)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    const W latitude1 =
        cast(W) first.latitude.radians;

    const W latitude2 =
        cast(W) second.latitude.radians;

    if (latitude1 + latitude2 != cast(W) 0)
        return false;

    const W halfPi =
        cast(W) PI / cast(W) 2;

    if (abs(latitude1) == halfPi
        || abs(latitude2) == halfPi)
        return true;

    const W azimuthDifference =
        abs(
            wrapIntersectionPi!W(
                cast(W) inverse.finalAzimuth.radians
                - cast(W) inverse.initialAzimuth.radians));

    const W tolerance =
        cast(W) 64 * W.epsilon;

    return azimuthDifference > tolerance;
}


/** Error-free transform for one floating-point sum. */
private W intersectionTwoSum(W)(
    const W u,
    const W v,
    out W error)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    const W sum = u + v;
    const W up = sum - v;
    const W vpp = sum - up;
    const W du = up - u;
    const W dv = vpp - v;
    error = sum != cast(W) 0 ? -(du + dv) : sum;
    return sum;
}

/** Compensated canonical difference y-x in radians. */
private W intersectionAngleDiff(W)(
    const W x,
    const W y,
    out W error)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    const W period = cast(W) 2 * cast(W) PI;
    W difference = intersectionTwoSum!W((-x) % period, y % period, error);
    W correction;
    difference = intersectionTwoSum!W(difference % period, error, correction);
    error = correction;
    if (difference > cast(W) PI)
        difference -= period;
    else if (difference < -cast(W) PI)
        difference += period;
    if (difference == cast(W) 0 || abs(difference) == cast(W) PI)
        difference = copysign(difference, error == cast(W) 0 ? y - x : -error);
    return difference;
}

/** Evaluate sin/cos of a reduced angle plus a small correction. */
private void intersectionSinCosCorrected(W)(
    const W angle,
    const W correction,
    out W sine,
    out W cosine)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    const W s = sin(angle);
    const W c = cos(angle);
    const W se = sin(correction);
    const W ce = cos(correction);
    sine = s * ce + c * se;
    cosine = c * ce - s * se;
}

/**
 * Compute the authalic-radius scale used by Karney's local spherical update.
 */
private bool tryAuthalicRadius(T)(
    const Geodesic!T solver,
    out IntersectionWorkingScalar!T radius)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    radius = W.nan;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;
    const W f =
        cast(W) solver.ellipsoid.flattening;

    if (!isFiniteGeodesyScalar(a)
        || !(a > cast(W) 0)
        || !isFiniteGeodesyScalar(f))
        return false;

    const W e2 =
        f * (cast(W) 2 - f);

    if (e2 == cast(W) 0)
    {
        radius = a;
        return true;
    }

    if (!(e2 > cast(W) 0)
        || !(e2 < cast(W) 1))
        return false;

    const W e =
        sqrt(e2);

    const W radiusSquared =
        a * a
        * cast(W) 0.5
        * (
            cast(W) 1
            + (cast(W) 1 - e2) / e * atanh(e));

    if (!isFiniteGeodesyScalar(radiusSquared)
        || !(radiusSquared > cast(W) 0))
        return false;

    radius =
        sqrt(radiusSquared);

    return isFiniteGeodesyScalar(radius)
        && radius > cast(W) 0;
}


/**
 * Perform Karney's iterative local spherical correction from one seed.
 */
private bool tryBasicIntersection(T)(
    const Geodesic!T solver,
    const PreparedSegment!T first,
    const PreparedSegment!T second,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) seed,
    out IntersectionDisplacement!(IntersectionWorkingScalar!T) result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    result =
        seed;

    const W epsilon =
        cast(W) 3 * W.epsilon;

    const W tolerance =
        cast(W) PI
        * authalicRadius
        * pow(
            W.epsilon,
            cast(W) 0.75);

    enum size_t maxIterations = 100;

    foreach (_; 0 .. maxIterations)
    {
        GeodesicDirectResult!T firstPosition;
        GeodesicDirectResult!T secondPosition;

        if (!first.line.tryPosition(
                cast(T) result.x,
                firstPosition)
            || !second.line.tryPosition(
                cast(T) result.y,
                secondPosition))
            return false;

        GeodesicInverseResult!T inverse;

        if (!solver.tryInverse(
                firstPosition.position,
                secondPosition.position,
                inverse))
            return false;

        const W separation =
            cast(W) inverse.distance;

        const W sphericalArc =
            separation / authalicRadius;

        if (!isFiniteGeodesyScalar(sphericalArc))
            return false;

        const W sinSeparation =
            sin(sphericalArc);

        const W cosSeparation =
            cos(sphericalArc);

        W firstError;
        W secondError;

        const W firstAngle =
            intersectionAngleDiff!W(
                cast(W) firstPosition.finalAzimuth.radians,
                cast(W) inverse.initialAzimuth.radians,
                firstError);

        const W secondAngle =
            intersectionAngleDiff!W(
                cast(W) secondPosition.finalAzimuth.radians,
                cast(W) inverse.finalAzimuth.radians,
                secondError);

        W orientationError;

        const W orientationDifference =
            intersectionAngleDiff!W(
                firstAngle,
                secondAngle,
                orientationError);

        const W sign =
            copysign(
                cast(W) 1,
                orientationDifference + orientationError + secondError - firstError);

        W sinFirst;
        W cosFirst;
        W sinSecond;
        W cosSecond;

        intersectionSinCosCorrected!W(
            sign * firstAngle,
            sign * firstError,
            sinFirst,
            cosFirst);

        intersectionSinCosCorrected!W(
            sign * secondAngle,
            sign * secondError,
            sinSecond,
            cosSecond);

        W deltaFirst;
        W deltaSecond;
        int coincidence = 0;

        if (separation
            <= epsilon * authalicRadius)
        {
            deltaFirst =
                cast(W) 0;

            deltaSecond =
                cast(W) 0;

            if (abs(sinFirst - sinSecond) <= epsilon
                && abs(cosFirst - cosSecond) <= epsilon)
            {
                coincidence = 1;
            }
            else if (
                abs(sinFirst + sinSecond) <= epsilon
                && abs(cosFirst + cosSecond) <= epsilon)
            {
                coincidence = -1;
            }
        }
        else if (abs(sinFirst) <= epsilon
            && abs(sinSecond) <= epsilon)
        {
            coincidence =
                cosFirst * cosSecond > cast(W) 0
                    ? 1
                    : -1;

            deltaFirst =
                cosFirst * separation / cast(W) 2;

            deltaSecond =
                -cosSecond * separation / cast(W) 2;
        }
        else
        {
            deltaFirst =
                authalicRadius
                * atan2(
                    sinSecond * sinSeparation,
                    sinSecond * cosFirst * cosSeparation
                        - cosSecond * sinFirst);

            deltaSecond =
                authalicRadius
                * atan2(
                    sinFirst * sinSeparation,
                    -sinFirst * cosSecond * cosSeparation
                        + cosFirst * sinSecond);
        }

        if (!isFiniteGeodesyScalar(deltaFirst)
            || !isFiniteGeodesyScalar(deltaSecond))
            return false;

        result.x +=
            deltaFirst;

        result.y +=
            deltaSecond;

        result.coincidence =
            coincidence;

        if (!isFiniteGeodesyScalar(result.x)
            || !isFiniteGeodesyScalar(result.y))
            return false;

        if (coincidence != 0
            || abs(deltaFirst) + abs(deltaSecond) <= tolerance)
            return true;
    }

    return false;
}


/** Test one signed displacement against a finite segment with tolerance. */
private bool displacementInSegment(W)(
    const W value,
    const W length,
    const W tolerance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    return value >= -tolerance
        && value <= length + tolerance;
}


/**
 * Convert one converged displacement result into bounded geometry.
 */
private bool tryClassifyBoundedIntersection(T)(
    const Geodesic!T solver,
    const PreparedSegment!T first,
    const PreparedSegment!T second,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) point,
    out GeodesicSegmentIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    result =
        GeodesicSegmentIntersectionResult!T.noIntersection();

    const W firstLength =
        cast(W) first.length;

    const W secondLength =
        cast(W) second.length;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    /*
     * Unit-scaled boundary tolerance. This is only for classifying a
     * converged displacement exactly at a finite endpoint; it is not the
     * nonlinear solver convergence tolerance.
     */
    const W boundaryTolerance =
        a * cast(W) 64 * W.epsilon;

    if (point.coincidence == 0)
    {
        if (!displacementInSegment(
                point.x,
                firstLength,
                boundaryTolerance)
            || !displacementInSegment(
                point.y,
                secondLength,
                boundaryTolerance))
            return true;

        W firstDistance =
            point.x;

        if (firstDistance < cast(W) 0)
            firstDistance = cast(W) 0;
        else if (firstDistance > firstLength)
            firstDistance = firstLength;

        GeodesicDirectResult!T position;

        if (!first.line.tryPosition(
                cast(T) firstDistance,
                position))
            return false;

        result =
            GeodesicSegmentIntersectionResult!T.fromComponents(
                GeodesicSegmentIntersectionKind.point,
                position.position,
                position.position);

        return true;
    }

    if (point.coincidence != 1
        && point.coincidence != -1)
        return false;

    const W orientation =
        cast(W) point.coincidence;

    const W mappedStart =
        point.x
        + orientation
            * (cast(W) 0 - point.y);

    const W mappedEnd =
        point.x
        + orientation
            * (secondLength - point.y);

    const W mappedLow =
        mappedStart < mappedEnd
            ? mappedStart
            : mappedEnd;

    const W mappedHigh =
        mappedStart > mappedEnd
            ? mappedStart
            : mappedEnd;

    W low =
        mappedLow > cast(W) 0
            ? mappedLow
            : cast(W) 0;

    W high =
        mappedHigh < firstLength
            ? mappedHigh
            : firstLength;

    if (high < low - boundaryTolerance)
        return true;

    if (low < cast(W) 0)
        low = cast(W) 0;

    if (high > firstLength)
        high = firstLength;

    if (abs(high - low) <= boundaryTolerance)
    {
        const W midpoint =
            (low + high) / cast(W) 2;

        GeodesicDirectResult!T position;

        if (!first.line.tryPosition(
                cast(T) midpoint,
                position))
            return false;

        result =
            GeodesicSegmentIntersectionResult!T.fromComponents(
                GeodesicSegmentIntersectionKind.point,
                position.position,
                position.position);

        return true;
    }

    GeodesicDirectResult!T firstEndpoint;
    GeodesicDirectResult!T secondEndpoint;

    if (!first.line.tryPosition(
            cast(T) low,
            firstEndpoint)
        || !first.line.tryPosition(
            cast(T) high,
            secondEndpoint))
        return false;

    result =
        GeodesicSegmentIntersectionResult!T.fromComponents(
            GeodesicSegmentIntersectionKind.overlap,
            firstEndpoint.position,
            secondEndpoint.position);

    return true;
}


/**
 * Intersect two bounded shortest ellipsoidal geodesic segments without throwing.
 *
 * Each endpoint pair defines one oriented finite segment. Valid disjoint
 * segments are a successful operation and return `kind == none`.
 *
 * Exact coincident endpoints are rejected as degenerate segments. Exact
 * antipodes and detected equal-and-opposite-latitude multiple-shortest
 * solutions are rejected because the shortest geodesic is not unique.
 *
 * Params:
 *     solver = Valid prepared geodesic solver.
 *     firstStart = First segment start.
 *     firstEnd = First segment end.
 *     secondStart = Second segment start.
 *     secondEnd = Second segment end.
 *     result = Receives `none`, `point`, or `overlap`.
 *
 * Returns:
 *     `true` when the bounded intersection problem was evaluated
 *     successfully, including the geometrically disjoint case. Returns
 *     `false` for invalid/degenerate/ambiguous segment input or numerical
 *     non-convergence. On failure `result` is `.init`.
 */
bool tryIntersectGeodesicSegments(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T firstStart,
    const GeographicCoordinate!T firstEnd,
    const GeographicCoordinate!T secondStart,
    const GeographicCoordinate!T secondEnd,
    out GeodesicSegmentIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    result =
        GeodesicSegmentIntersectionResult!T.init;

    if (!solver.isValid)
        return false;

    if (firstStart == firstEnd
        || secondStart == secondEnd)
        return false;

    if (areExactAntipodes(
            firstStart,
            firstEnd)
        || areExactAntipodes(
            secondStart,
            secondEnd))
        return false;

    GeodesicInverseResult!T firstInverse;
    GeodesicInverseResult!T secondInverse;

    if (!solver.tryInverse(
            firstStart,
            firstEnd,
            firstInverse)
        || !solver.tryInverse(
            secondStart,
            secondEnd,
            secondInverse))
        return false;

    if (!(firstInverse.distance > cast(T) 0)
        || !(secondInverse.distance > cast(T) 0))
        return false;

    if (hasAmbiguousShortestGeodesic!T(
            firstStart,
            firstEnd,
            firstInverse)
        || hasAmbiguousShortestGeodesic!T(
            secondStart,
            secondEnd,
            secondInverse))
        return false;

    GeodesicLine!T firstLine;
    GeodesicLine!T secondLine;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            firstStart,
            firstInverse.initialAzimuth,
            firstLine)
        || !GeodesicLine!T.tryFromGeodesic(
            solver,
            secondStart,
            secondInverse.initialAzimuth,
            secondLine))
        return false;

    const PreparedSegment!T first =
        PreparedSegment!T(
            firstInverse.distance,
            firstLine);

    const PreparedSegment!T second =
        PreparedSegment!T(
            secondInverse.distance,
            secondLine);

    W authalicRadius;

    if (!tryAuthalicRadius!T(
            solver,
            authalicRadius))
        return false;

    const W firstLength =
        cast(W) first.length;

    const W secondLength =
        cast(W) second.length;

    const IntersectionDisplacement!W[5] seeds =
    [
        IntersectionDisplacement!W(
            firstLength / cast(W) 2,
            secondLength / cast(W) 2,
            0),
        IntersectionDisplacement!W(
            cast(W) 0,
            cast(W) 0,
            0),
        IntersectionDisplacement!W(
            firstLength,
            cast(W) 0,
            0),
        IntersectionDisplacement!W(
            cast(W) 0,
            secondLength,
            0),
        IntersectionDisplacement!W(
            firstLength,
            secondLength,
            0)
    ];

    foreach (index, seed; seeds)
    {
        IntersectionDisplacement!W point;

        if (!tryBasicIntersection!T(
                solver,
                first,
                second,
                authalicRadius,
                seed,
                point))
            continue;

        GeodesicSegmentIntersectionResult!T candidate;

        if (!tryClassifyBoundedIntersection!T(
                solver,
                first,
                second,
                point,
                candidate))
            return false;

        if (candidate.kind
            == GeodesicSegmentIntersectionKind.overlap)
        {
            result =
                candidate;
            return true;
        }

        if (candidate.kind
            == GeodesicSegmentIntersectionKind.point)
        {
            result =
                candidate;
            return true;
        }

        /*
         * After the midpoint seed, use a metric lower bound before paying for
         * the four conservative corner seeds. If the segments shared a point
         * P, the triangle inequality would require
         *
         *   distance(firstStart, secondStart)
         *       <= firstLength + secondLength.
         *
         * A strict violation therefore proves the bounded segments disjoint.
         * Keep a unit-scaled numerical margin so this remains a one-sided
         * rejection only.
         */
        if (index == 0)
        {
            GeodesicInverseResult!T startSeparation;

            if (!solver.tryInverse(
                    firstStart,
                    secondStart,
                    startSeparation))
                return false;

            const W rejectionMargin =
                cast(W) solver.ellipsoid.semiMajorAxis
                * cast(W) 128
                * W.epsilon;

            if (cast(W) startSeparation.distance
                > firstLength + secondLength + rejectionMargin)
            {
                result =
                    GeodesicSegmentIntersectionResult!T.noIntersection();

                return true;
            }
        }
    }

    result =
        GeodesicSegmentIntersectionResult!T.noIntersection();

    return true;
}

/// Example finding one ordinary bounded-segment crossing.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            wgs84!double());

    const firstStart =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(-10.0));

    const firstEnd =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(10.0));

    const secondStart =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-10.0),
            Longitude!double.fromDegrees(0.0));

    const secondEnd =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(10.0),
            Longitude!double.fromDegrees(0.0));

    GeodesicSegmentIntersectionResult!double result;

    assert(tryIntersectGeodesicSegments(
        solver,
        firstStart,
        firstEnd,
        secondStart,
        secondEnd,
        result));

    assert(result.kind
        == GeodesicSegmentIntersectionKind.point);
}


/**
 * Intersect two bounded shortest ellipsoidal geodesic segments.
 *
 * This is the throwing counterpart of `tryIntersectGeodesicSegments`.
 *
 * Throws:
 *     `GeodesyValueException` for invalid/degenerate/ambiguous segment input
 *     or numerical non-convergence. A valid disjoint pair does not throw and
 *     returns `kind == none`.
 */
GeodesicSegmentIntersectionResult!T intersectGeodesicSegments(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T firstStart,
    const GeographicCoordinate!T firstEnd,
    const GeographicCoordinate!T secondStart,
    const GeographicCoordinate!T secondEnd)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicSegmentIntersectionResult!T result;

    if (!tryIntersectGeodesicSegments(
            solver,
            firstStart,
            firstEnd,
            secondStart,
            secondEnd,
            result))
    {
        throw new GeodesyValueException(
            "Geodesic segment intersection requires valid non-degenerate "
            ~ "segments with unambiguous shortest geodesics and a finite "
            ~ "converged ellipsoidal solution.");
    }

    return result;
}

/// Example returning a valid no-intersection result without throwing.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            wgs84!double());

    const firstStart =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(-10.0));

    const firstEnd =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(-5.0));

    const secondStart =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(10.0),
            Longitude!double.fromDegrees(5.0));

    const secondEnd =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(10.0),
            Longitude!double.fromDegrees(10.0));

    const result =
        intersectGeodesicSegments(
            solver,
            firstStart,
            firstEnd,
            secondStart,
            secondEnd);

    assert(result.kind
        == GeodesicSegmentIntersectionKind.none);
}
