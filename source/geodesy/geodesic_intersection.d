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

/** Relationship of coincident oriented geodesics. */
enum GeodesicIntersectionCoincidence
{
    distinct,
    parallel,
    antiparallel
}

/// Example distinguishing ordinary and coincident line intersections.
@safe unittest
{
    assert(GeodesicIntersectionCoincidence.distinct
        != GeodesicIntersectionCoincidence.parallel);
}

/** Result of the globally closest intersection of two oriented geodesics. */
struct GeodesicClosestIntersectionResult(T)
if (isGeodesyScalar!T)
{
private:
    bool _valid;
    GeographicCoordinate!T _position;
    T _distanceOnFirst = T.nan;
    T _distanceOnSecond = T.nan;
    T _referenceDistance = T.nan;
    GeodesicIntersectionCoincidence _coincidence =
        GeodesicIntersectionCoincidence.distinct;

    /** Construct a validated closest-intersection result. */
    static GeodesicClosestIntersectionResult fromComponents(
        const GeographicCoordinate!T position,
        const T distanceOnFirst,
        const T distanceOnSecond,
        const T referenceDistance,
        const GeodesicIntersectionCoincidence coincidence)
        pure nothrow @safe @nogc
    {
        GeodesicClosestIntersectionResult result;
        result._valid = true;
        result._position = position;
        result._distanceOnFirst = distanceOnFirst;
        result._distanceOnSecond = distanceOnSecond;
        result._referenceDistance = referenceDistance;
        result._coincidence = coincidence;
        return result;
    }

public:
    /** True when the result was produced by a successful closest search. */
    @property bool isValid() const pure nothrow @safe @nogc { return _valid; }

    /// Example checking the default invalid state.
    @safe unittest
    {
        assert(!GeodesicClosestIntersectionResult!double.init.isValid);
    }
    /** Geographic position of the selected intersection representative. */
    @property GeographicCoordinate!T position() const pure nothrow @safe @nogc { return _position; }

    /// Example reading the default position value.
    @safe unittest
    {
        GeodesicClosestIntersectionResult!double result;
        cast(void) result.position;
    }
    /** Signed distance from the first oriented line origin. */
    @property T distanceOnFirst() const pure nothrow @safe @nogc { return _distanceOnFirst; }

    /// Example reading the first signed displacement.
    @safe unittest
    {
        GeodesicClosestIntersectionResult!double result;
        cast(void) result.distanceOnFirst;
    }
    /** Signed distance from the second oriented line origin. */
    @property T distanceOnSecond() const pure nothrow @safe @nogc { return _distanceOnSecond; }

    /// Example reading the second signed displacement.
    @safe unittest
    {
        GeodesicClosestIntersectionResult!double result;
        cast(void) result.distanceOnSecond;
    }
    /** L1 displacement-space distance to the caller reference pair. */
    @property T referenceDistance() const pure nothrow @safe @nogc { return _referenceDistance; }

    /// Example reading the closest-ranking distance.
    @safe unittest
    {
        GeodesicClosestIntersectionResult!double result;
        cast(void) result.referenceDistance;
    }
    /** Coincidence relationship of the two supporting oriented geodesics. */
    @property GeodesicIntersectionCoincidence coincidence() const pure nothrow @safe @nogc { return _coincidence; }

    /// Example reading the default coincidence classification.
    @safe unittest
    {
        GeodesicClosestIntersectionResult!double result;
        assert(result.coincidence == GeodesicIntersectionCoincidence.distinct);
    }
}

/// Example using the closest-intersection result type.
@safe unittest
{
    GeodesicClosestIntersectionResult!double result;
    assert(!result.isValid);
    assert(result.coincidence
        == GeodesicIntersectionCoincidence.distinct);
}

/** L1 distance between two signed displacement pairs. */
private W intersectionL1(W)(
    const IntersectionDisplacement!W first,
    const IntersectionDisplacement!W second)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    return abs(first.x - second.x) + abs(first.y - second.y);
}

/** Normalize a coincident-line representative around the reference pair. */
private IntersectionDisplacement!W fixClosestCoincident(W)(
    const IntersectionDisplacement!W reference,
    const IntersectionDisplacement!W point)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    if (point.coincidence == 0)
        return point;
    const W orientation = cast(W) point.coincidence;
    const W shift =
        (reference.x + orientation * reference.y
            - point.x - orientation * point.y) / cast(W) 2;
    return IntersectionDisplacement!W(
        point.x + shift,
        point.y + orientation * shift,
        point.coincidence);
}

/** Solve the semi-conjugate distance used by global closest seeding. */
private bool tryIntersectionConjugateDistance(T)(
    const GeodesicLine!T line,
    const IntersectionWorkingScalar!T tolerance,
    const IntersectionWorkingScalar!T initial,
    const bool semi,
    const IntersectionWorkingScalar!T baseReducedLength,
    const IntersectionWorkingScalar!T baseScale12,
    const IntersectionWorkingScalar!T baseScale21,
    out IntersectionWorkingScalar!T distance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    W current = initial;

    foreach (_; 0 .. 100)
    {
        GeodesicDirectResult!T position;
        GeodesicQuantities!T quantities;

        if (!line.tryPosition(cast(T) current, position, quantities))
            return false;

        const W m13 = cast(W) quantities.reducedLength;
        const W M13 = cast(W) quantities.scale12;
        const W M31 = cast(W) quantities.scale21;

        const W m23 =
            m13 * baseScale12
            - baseReducedLength * M13;

        const W M23 =
            M13 * baseScale21
            + (
                baseReducedLength == cast(W) 0
                    ? cast(W) 0
                    : (cast(W) 1 - baseScale12 * baseScale21)
                        * m13 / baseReducedLength
            );

        const W M32 =
            M31 * baseScale12
            + (
                m13 == cast(W) 0
                    ? cast(W) 0
                    : (cast(W) 1 - M13 * M31)
                        * baseReducedLength / m13
            );

        const W denominator =
            semi
                ? cast(W) 1 - M23 * M32
                : M32;

        if (!isFiniteGeodesyScalar(denominator)
            || denominator == cast(W) 0)
            return false;

        const W delta =
            semi
                ? m23 * M23 / denominator
                : -m23 / denominator;

        if (!isFiniteGeodesyScalar(delta))
            return false;

        current += delta;

        if (!isFiniteGeodesyScalar(current))
            return false;

        if (abs(delta) <= tolerance)
        {
            distance = current;
            return true;
        }
    }

    return false;
}


/** Solve conjugacy relative to the line origin. */
private bool tryIntersectionConjugateFromOrigin(T)(
    const GeodesicLine!T line,
    const IntersectionWorkingScalar!T tolerance,
    const IntersectionWorkingScalar!T initial,
    const bool semi,
    out IntersectionWorkingScalar!T distance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    return tryIntersectionConjugateDistance!T(
        line,
        tolerance,
        initial,
        semi,
        cast(W) 0,
        cast(W) 1,
        cast(W) 1,
        distance);
}

/** Derive closest-search spacing and tolerance for sphere/oblate ellipsoids. */
private bool tryClosestIntersectionSpacing(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    out IntersectionWorkingScalar!T t1,
    out IntersectionWorkingScalar!T d1,
    out IntersectionWorkingScalar!T delta)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    const W a = cast(W) solver.ellipsoid.semiMajorAxis;
    const W f = cast(W) solver.ellipsoid.flattening;
    const W d = cast(W) PI * authalicRadius;
    t1 = cast(W) PI * a * (cast(W) 1 - f);
    delta = d * pow(W.epsilon, cast(W) 0.2);
    if (f == cast(W) 0)
    {
        d1 = cast(W) PI * a / cast(W) 2;
        return true;
    }
    Latitude!T poleLatitude;
    Longitude!T poleLongitude;
    Angle!T poleAzimuth;
    if (!Latitude!T.tryFromRadians(
            cast(T) (cast(W) PI / cast(W) 2), poleLatitude)
        || !Longitude!T.tryFromRadians(cast(T) 0, poleLongitude)
        || !Angle!T.tryFromRadians(cast(T) 0, poleAzimuth))
        return false;
    const auto pole = GeographicCoordinate!T.fromComponents(
        poleLatitude, poleLongitude);
    GeodesicLine!T line;
    if (!GeodesicLine!T.tryFromGeodesic(
            solver, pole, poleAzimuth, line))
        return false;
    const W tolerance = d * pow(W.epsilon, cast(W) 0.75);
    const W initial =
        (cast(W) 1 + f / cast(W) 2) * a * cast(W) PI / cast(W) 2;
    return tryIntersectionConjugateFromOrigin!T(
        line, tolerance, initial, true, d1);
}

/** Compare two closest candidates with deterministic displacement tie-breaks. */
private bool closestIntersectionBetter(W)(
    const IntersectionDisplacement!W candidate,
    const IntersectionDisplacement!W best,
    const IntersectionDisplacement!W reference)
    pure nothrow @safe @nogc
if (isGeodesyScalar!W)
{
    const W dc = intersectionL1!W(candidate, reference);
    const W db = intersectionL1!W(best, reference);
    if (dc != db) return dc < db;
    if (candidate.x != best.x) return candidate.x < best.x;
    return candidate.y < best.y;
}

/** Find the closest intersection of two prepared oriented geodesics. */
bool tryClosestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T referenceOnFirst,
    const T referenceOnSecond,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    result = GeodesicClosestIntersectionResult!T.init;
    if (!solver.isValid || !firstLine.isValid || !secondLine.isValid
        || !isFiniteGeodesyScalar(referenceOnFirst)
        || !isFiniteGeodesyScalar(referenceOnSecond))
        return false;
    W authalicRadius;
    if (!tryAuthalicRadius!T(solver, authalicRadius))
        return false;
    W t1, d1, delta;
    if (!tryClosestIntersectionSpacing!T(
            solver, authalicRadius, t1, d1, delta))
        return false;
    const PreparedSegment!T first = PreparedSegment!T(cast(T) 0, firstLine);
    const PreparedSegment!T second = PreparedSegment!T(cast(T) 0, secondLine);
    const IntersectionDisplacement!W reference =
        IntersectionDisplacement!W(
            cast(W) referenceOnFirst, cast(W) referenceOnSecond, 0);
    const int[5] xs = [0, 1, -1, 0, 0];
    const int[5] ys = [0, 0, 0, 1, -1];
    bool[5] skip;
    bool haveBest;
    IntersectionDisplacement!W best;
    foreach (n; 0 .. 5)
    {
        if (skip[n]) continue;
        IntersectionDisplacement!W candidate;
        if (!tryBasicIntersection!T(
                solver, first, second, authalicRadius,
                IntersectionDisplacement!W(
                    reference.x + cast(W) xs[n] * d1,
                    reference.y + cast(W) ys[n] * d1, 0),
                candidate))
            return false;
        candidate = fixClosestCoincident!W(reference, candidate);
        if (haveBest && intersectionL1!W(best, candidate) <= delta)
            continue;
        if (intersectionL1!W(candidate, reference) < t1)
        {
            best = candidate;
            haveBest = true;
            break;
        }
        if (!haveBest || closestIntersectionBetter!W(candidate, best, reference))
        {
            best = candidate;
            haveBest = true;
        }
        foreach (m; n + 1 .. 5)
        {
            const auto seed = IntersectionDisplacement!W(
                reference.x + cast(W) xs[m] * d1,
                reference.y + cast(W) ys[m] * d1, 0);
            if (intersectionL1!W(candidate, seed)
                < cast(W) 2 * t1 - d1 - delta)
                skip[m] = true;
        }
    }
    if (!haveBest)
        return false;
    GeodesicDirectResult!T position;
    if (!firstLine.tryPosition(cast(T) best.x, position))
        return false;
    GeodesicIntersectionCoincidence coincidence =
        best.coincidence > 0
            ? GeodesicIntersectionCoincidence.parallel
            : best.coincidence < 0
                ? GeodesicIntersectionCoincidence.antiparallel
                : GeodesicIntersectionCoincidence.distinct;
    result = GeodesicClosestIntersectionResult!T.fromComponents(
        position.position,
        cast(T) best.x,
        cast(T) best.y,
        cast(T) intersectionL1!W(best, reference),
        coincidence);
    return true;
}

/** Zero-reference prepared-line overload. */
bool tryClosestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryClosestGeodesicIntersection(
        solver, firstLine, secondLine, cast(T) 0, cast(T) 0, result);
}

/** Construct lines from origins and azimuths and find the closest intersection. */
bool tryClosestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T firstStart,
    const Angle!T firstAzimuth,
    const GeographicCoordinate!T secondStart,
    const Angle!T secondAzimuth,
    const T referenceOnFirst,
    const T referenceOnSecond,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result = GeodesicClosestIntersectionResult!T.init;
    GeodesicLine!T firstLine;
    GeodesicLine!T secondLine;
    if (!GeodesicLine!T.tryFromGeodesic(
            solver, firstStart, firstAzimuth, firstLine)
        || !GeodesicLine!T.tryFromGeodesic(
            solver, secondStart, secondAzimuth, secondLine))
        return false;
    return tryClosestGeodesicIntersection(
        solver, firstLine, secondLine,
        referenceOnFirst, referenceOnSecond, result);
}

/** Zero-reference origin/azimuth overload. */
bool tryClosestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T firstStart,
    const Angle!T firstAzimuth,
    const GeographicCoordinate!T secondStart,
    const Angle!T secondAzimuth,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryClosestGeodesicIntersection(
        solver, firstStart, firstAzimuth, secondStart, secondAzimuth,
        cast(T) 0, cast(T) 0, result);
}

/// Example checking the closest intersection of two oriented geodesics without throwing.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());

    const firstStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(-20.0));

    const secondStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(20.0));

    GeodesicClosestIntersectionResult!double result;

    assert(tryClosestGeodesicIntersection(
        solver,
        firstStart,
        Angle!double.fromDegrees(45.0),
        secondStart,
        Angle!double.fromDegrees(-60.0),
        result));

    assert(result.isValid);
}

/** Throwing prepared-line closest intersection. */
GeodesicClosestIntersectionResult!T closestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T referenceOnFirst = cast(T) 0,
    const T referenceOnSecond = cast(T) 0)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicClosestIntersectionResult!T result;
    if (!tryClosestGeodesicIntersection(
            solver, firstLine, secondLine,
            referenceOnFirst, referenceOnSecond, result))
        throw new GeodesyValueException(
            "Closest geodesic intersection failed for the supplied lines or reference.");
    return result;
}

/** Throwing origin/azimuth closest intersection. */
GeodesicClosestIntersectionResult!T closestGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T firstStart,
    const Angle!T firstAzimuth,
    const GeographicCoordinate!T secondStart,
    const Angle!T secondAzimuth,
    const T referenceOnFirst = cast(T) 0,
    const T referenceOnSecond = cast(T) 0)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicClosestIntersectionResult!T result;
    if (!tryClosestGeodesicIntersection(
            solver, firstStart, firstAzimuth, secondStart, secondAzimuth,
            referenceOnFirst, referenceOnSecond, result))
        throw new GeodesyValueException(
            "Closest geodesic intersection failed for the supplied line definitions or reference.");
    return result;
}

/// Example finding the closest intersection of two oriented geodesics.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());
    const firstStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(-20.0));
    const secondStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(20.0));
    const result = closestGeodesicIntersection(
        solver, firstStart, Angle!double.fromDegrees(45.0),
        secondStart, Angle!double.fromDegrees(-60.0));
    assert(result.isValid);
    assert(result.coincidence == GeodesicIntersectionCoincidence.distinct);
}


/**
 * Result of the next intersection after a known common-origin crossing.
 *
 * The two signed distances are measured from the known intersection along the
 * oriented input geodesics. displacementDistance is the L1 ranking value
 * abs(x) + abs(y).
 *
 * If multiple next intersections have the same minimum rank, this operation
 * returns one deterministic representative but does not claim uniqueness.
 * Use the future all-intersections API (#106) when all tied solutions are
 * required.
 *
 * .init is invalid.
 */
struct GeodesicNextIntersectionResult(T)
if (isGeodesyScalar!T)
{
private:
    bool _valid;
    GeographicCoordinate!T _position;
    T _distanceOnFirst = T.nan;
    T _distanceOnSecond = T.nan;
    T _displacementDistance = T.nan;
    GeodesicIntersectionCoincidence _coincidence =
        GeodesicIntersectionCoincidence.distinct;

    /** Construct a validated next-intersection result. */
    static GeodesicNextIntersectionResult fromComponents(
        const GeographicCoordinate!T position,
        const T distanceOnFirst,
        const T distanceOnSecond,
        const T displacementDistance,
        const GeodesicIntersectionCoincidence coincidence)
        pure nothrow @safe @nogc
    {
        GeodesicNextIntersectionResult result;
        result._valid = true;
        result._position = position;
        result._distanceOnFirst = distanceOnFirst;
        result._distanceOnSecond = distanceOnSecond;
        result._displacementDistance = displacementDistance;
        result._coincidence = coincidence;
        return result;
    }

public:
    /** True when the next-intersection search succeeded. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _valid;
    }

    /// Example checking the default invalid state.
    @safe unittest
    {
        assert(!GeodesicNextIntersectionResult!double.init.isValid);
    }

    /** Geographic position of the selected next intersection. */
    @property GeographicCoordinate!T position() const
        pure nothrow @safe @nogc
    {
        return _position;
    }

    /// Example reading the default position value.
    @safe unittest
    {
        GeodesicNextIntersectionResult!double result;
        cast(void) result.position;
    }

    /** Signed distance from the known crossing along the first geodesic. */
    @property T distanceOnFirst() const pure nothrow @safe @nogc
    {
        return _distanceOnFirst;
    }

    /// Example reading the first signed displacement.
    @safe unittest
    {
        GeodesicNextIntersectionResult!double result;
        cast(void) result.distanceOnFirst;
    }

    /** Signed distance from the known crossing along the second geodesic. */
    @property T distanceOnSecond() const pure nothrow @safe @nogc
    {
        return _distanceOnSecond;
    }

    /// Example reading the second signed displacement.
    @safe unittest
    {
        GeodesicNextIntersectionResult!double result;
        cast(void) result.distanceOnSecond;
    }

    /** Minimum nonzero L1 displacement rank. */
    @property T displacementDistance() const pure nothrow @safe @nogc
    {
        return _displacementDistance;
    }

    /// Example reading the next-intersection ranking distance.
    @safe unittest
    {
        GeodesicNextIntersectionResult!double result;
        cast(void) result.displacementDistance;
    }

    /** Coincidence relationship of the two supporting geodesics. */
    @property GeodesicIntersectionCoincidence coincidence() const
        pure nothrow @safe @nogc
    {
        return _coincidence;
    }

    /// Example reading the default coincidence classification.
    @safe unittest
    {
        GeodesicNextIntersectionResult!double result;
        assert(result.coincidence
            == GeodesicIntersectionCoincidence.distinct);
    }
}

/// Example using the next-intersection result type.
@safe unittest
{
    GeodesicNextIntersectionResult!double result;
    assert(!result.isValid);
}


/** Build a zero-valued geographic origin without throwing. */
private bool tryIntersectionZeroCoordinate(T)(
    out GeographicCoordinate!T coordinate)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    Latitude!T latitude;
    Longitude!T longitude;

    if (!Latitude!T.tryFromRadians(cast(T) 0, latitude)
        || !Longitude!T.tryFromRadians(cast(T) 0, longitude))
        return false;

    coordinate =
        GeographicCoordinate!T.fromComponents(
            latitude,
            longitude);

    return true;
}


/** Compute one conjugate distance and the asymmetry used by distoblique. */
private bool tryIntersectionConjDist(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionWorkingScalar!T azimuthRadians,
    out IntersectionWorkingScalar!T distance,
    out IntersectionWorkingScalar!T asymmetry)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    GeographicCoordinate!T origin;
    Angle!T azimuth;

    if (!tryIntersectionZeroCoordinate!T(origin)
        || !Angle!T.tryFromRadians(
            cast(T) azimuthRadians,
            azimuth))
        return false;

    GeodesicLine!T line;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            origin,
            azimuth,
            line))
        return false;

    const W d =
        cast(W) PI * authalicRadius;

    const W tolerance =
        d * pow(W.epsilon, cast(W) 0.75);

    W conjugate;

    if (!tryIntersectionConjugateFromOrigin!T(
            line,
            tolerance,
            d,
            false,
            conjugate))
        return false;

    const PreparedSegment!T prepared =
        PreparedSegment!T(cast(T) 0, line);

    IntersectionDisplacement!W crossing;

    if (!tryBasicIntersection!T(
            solver,
            prepared,
            prepared,
            authalicRadius,
            IntersectionDisplacement!W(
                conjugate / cast(W) 2,
                -cast(W) 3 * conjugate / cast(W) 2,
                0),
            crossing))
        return false;

    distance = conjugate;
    asymmetry =
        abs(crossing.x)
        + abs(crossing.y)
        - cast(W) 2 * conjugate;

    return isFiniteGeodesyScalar(distance)
        && isFiniteGeodesyScalar(asymmetry);
}


/** Derive Karney's oblique minimum conjugate spacing for oblate ellipsoids. */
private bool tryIntersectionDistOblique(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    out IntersectionWorkingScalar!T distance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    const W degreesToRadians =
        cast(W) PI / cast(W) 180;

    W azimuth0 =
        cast(W) 46 * degreesToRadians;

    W azimuth1 =
        cast(W) 44 * degreesToRadians;

    W distance0;
    W asymmetry0;
    W distance1;
    W asymmetry1;

    if (!tryIntersectionConjDist!T(
            solver,
            authalicRadius,
            azimuth0,
            distance0,
            asymmetry0)
        || !tryIntersectionConjDist!T(
            solver,
            authalicRadius,
            azimuth1,
            distance1,
            asymmetry1))
        return false;

    W bestDistance =
        distance1;

    W bestError =
        abs(asymmetry1);

    foreach (_; 0 .. 10)
    {
        if (asymmetry1 == asymmetry0)
            break;

        const W nextAzimuth =
            (
                azimuth0 * asymmetry1
                - azimuth1 * asymmetry0
            )
            / (asymmetry1 - asymmetry0);

        azimuth0 = azimuth1;
        distance0 = distance1;
        asymmetry0 = asymmetry1;
        azimuth1 = nextAzimuth;

        if (!tryIntersectionConjDist!T(
                solver,
                authalicRadius,
                azimuth1,
                distance1,
                asymmetry1))
            return false;

        if (abs(asymmetry1) < bestError)
        {
            bestError = abs(asymmetry1);
            bestDistance = distance1;

            if (asymmetry1 == cast(W) 0)
                break;
        }
    }

    distance = bestDistance;

    return isFiniteGeodesyScalar(distance)
        && distance > cast(W) 0;
}


/** Derive seed spacing and comparison tolerance for the Next search. */
private bool tryNextIntersectionSpacing(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    out IntersectionWorkingScalar!T t1,
    out IntersectionWorkingScalar!T d2,
    out IntersectionWorkingScalar!T delta,
    out IntersectionWorkingScalar!T halfCircumference)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    const W f =
        cast(W) solver.ellipsoid.flattening;

    halfCircumference =
        cast(W) PI * authalicRadius;

    t1 =
        cast(W) PI
        * a
        * (cast(W) 1 - f);

    delta =
        halfCircumference
        * pow(
            W.epsilon,
            cast(W) 0.2);

    W t3;

    if (f == cast(W) 0)
    {
        t3 = halfCircumference;
    }
    else
    {
        if (!tryIntersectionDistOblique!T(
                solver,
                authalicRadius,
                t3))
            return false;
    }

    d2 =
        cast(W) 2 * t3 / cast(W) 3;

    return isFiniteGeodesyScalar(t1)
        && isFiniteGeodesyScalar(d2)
        && isFiniteGeodesyScalar(delta)
        && d2 > cast(W) 0
        && d2 < cast(W) 2 * t1;
}


/** Validate that two prepared lines share the known intersection at distance zero. */
private bool preparedLinesShareOrigin(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    GeodesicDirectResult!T firstOrigin;
    GeodesicDirectResult!T secondOrigin;

    if (!firstLine.tryPosition(
            cast(T) 0,
            firstOrigin)
        || !secondLine.tryPosition(
            cast(T) 0,
            secondOrigin))
        return false;

    if (firstOrigin.position
        == secondOrigin.position)
        return true;

    GeodesicInverseResult!T separation;

    if (!solver.tryInverse(
            firstOrigin.position,
            secondOrigin.position,
            separation))
        return false;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    return cast(W) separation.distance
        <= cast(W) 3 * W.epsilon * a;
}


/**
 * Find the next closest intersection after a known common-origin crossing.
 *
 * The prepared lines must share their distance-zero geographic origin. The
 * known crossing at (0,0) is excluded. The returned solution minimizes
 * abs(x)+abs(y) among the remaining intersections.
 *
 * Equidistant minima are possible and this operation returns one representative
 * without asserting uniqueness.
 */
bool tryNextGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    out GeodesicNextIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    result =
        GeodesicNextIntersectionResult!T.init;

    if (!solver.isValid
        || !firstLine.isValid
        || !secondLine.isValid
        || !preparedLinesShareOrigin!T(
            solver,
            firstLine,
            secondLine))
        return false;

    W authalicRadius;

    if (!tryAuthalicRadius!T(
            solver,
            authalicRadius))
        return false;

    W t1;
    W d2;
    W delta;
    W d;

    if (!tryNextIntersectionSpacing!T(
            solver,
            authalicRadius,
            t1,
            d2,
            delta,
            d))
        return false;

    const PreparedSegment!T first =
        PreparedSegment!T(
            cast(T) 0,
            firstLine);

    const PreparedSegment!T second =
        PreparedSegment!T(
            cast(T) 0,
            secondLine);

    const int[8] xSeed =
        [-1, -1, 1, 1, -2, 0, 2, 0];

    const int[8] ySeed =
        [-1, 1, -1, 1, 0, 2, 0, -2];

    bool[8] skip;

    const IntersectionDisplacement!W zero =
        IntersectionDisplacement!W(
            cast(W) 0,
            cast(W) 0,
            0);

    bool haveBest;
    IntersectionDisplacement!W best;

    foreach (n; 0 .. 8)
    {
        if (skip[n])
            continue;

        IntersectionDisplacement!W candidate;

        if (!tryBasicIntersection!T(
                solver,
                first,
                second,
                authalicRadius,
                IntersectionDisplacement!W(
                    cast(W) xSeed[n] * d2,
                    cast(W) ySeed[n] * d2,
                    0),
                candidate))
            return false;

        candidate =
            fixClosestCoincident!W(
                zero,
                candidate);

        const bool atKnownOrigin =
            intersectionL1!W(
                candidate,
                zero) <= delta;

        if (candidate.coincidence == 0
            && atKnownOrigin)
            continue;

        if (candidate.coincidence != 0
            && atKnownOrigin)
        {
            foreach (sign; [-1, 1])
            {
                W conjugate;

                if (!tryIntersectionConjugateFromOrigin!T(
                        firstLine,
                        d * pow(W.epsilon, cast(W) 0.75),
                        cast(W) sign * d,
                        false,
                        conjugate))
                    return false;

                const IntersectionDisplacement!W discrete =
                    IntersectionDisplacement!W(
                        conjugate,
                        cast(W) candidate.coincidence
                            * conjugate,
                        candidate.coincidence);

                if (!haveBest
                    || intersectionL1!W(
                        discrete,
                        zero)
                        < intersectionL1!W(
                            best,
                            zero))
                {
                    best = discrete;
                    haveBest = true;
                }
            }
        }
        else if (!haveBest
            || intersectionL1!W(
                candidate,
                zero)
                < intersectionL1!W(
                    best,
                    zero))
        {
            best = candidate;
            haveBest = true;
        }

        foreach (sign; [-1, 0, 1])
        {
            if ((candidate.coincidence == 0
                    && sign != 0)
                || (atKnownOrigin
                    && sign == 0))
                continue;

            const IntersectionDisplacement!W shifted =
                candidate.coincidence != 0
                    ? IntersectionDisplacement!W(
                        candidate.x
                            + cast(W) sign * d2,
                        candidate.y
                            + cast(W) candidate.coincidence
                                * cast(W) sign
                                * d2,
                        candidate.coincidence)
                    : candidate;

            foreach (m; n + 1 .. 8)
            {
                const IntersectionDisplacement!W seed =
                    IntersectionDisplacement!W(
                        cast(W) xSeed[m] * d2,
                        cast(W) ySeed[m] * d2,
                        0);

                if (intersectionL1!W(
                        shifted,
                        seed)
                    < cast(W) 2 * t1
                        - d2
                        - delta)
                {
                    skip[m] = true;
                }
            }
        }
    }

    if (!haveBest)
        return false;

    GeodesicDirectResult!T position;

    if (!firstLine.tryPosition(
            cast(T) best.x,
            position))
        return false;

    const GeodesicIntersectionCoincidence coincidence =
        best.coincidence > 0
            ? GeodesicIntersectionCoincidence.parallel
            : best.coincidence < 0
                ? GeodesicIntersectionCoincidence.antiparallel
                : GeodesicIntersectionCoincidence.distinct;

    result =
        GeodesicNextIntersectionResult!T.fromComponents(
            position.position,
            cast(T) best.x,
            cast(T) best.y,
            cast(T) intersectionL1!W(
                best,
                zero),
            coincidence);

    return true;
}


/** Construct two common-origin oriented geodesics and find their next crossing. */
bool tryNextGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T knownIntersection,
    const Angle!T firstAzimuth,
    const Angle!T secondAzimuth,
    out GeodesicNextIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result =
        GeodesicNextIntersectionResult!T.init;

    GeodesicLine!T firstLine;
    GeodesicLine!T secondLine;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            knownIntersection,
            firstAzimuth,
            firstLine)
        || !GeodesicLine!T.tryFromGeodesic(
            solver,
            knownIntersection,
            secondAzimuth,
            secondLine))
        return false;

    return tryNextGeodesicIntersection(
        solver,
        firstLine,
        secondLine,
        result);
}


/// Example finding the next intersection without throwing.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            wgs84!double());

    const known =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    GeodesicNextIntersectionResult!double result;

    assert(tryNextGeodesicIntersection(
        solver,
        known,
        Angle!double.fromDegrees(30.0),
        Angle!double.fromDegrees(120.0),
        result));

    assert(result.isValid);
    assert(result.displacementDistance > 0.0);
}


/** Throwing prepared-line next-intersection operation. */
GeodesicNextIntersectionResult!T nextGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicNextIntersectionResult!T result;

    if (!tryNextGeodesicIntersection(
            solver,
            firstLine,
            secondLine,
            result))
    {
        throw new GeodesyValueException(
            "Next geodesic intersection requires valid prepared lines "
            ~ "sharing the same known geographic origin and a converged "
            ~ "supported spherical or oblate solution.");
    }

    return result;
}


/** Throwing common-origin/azimuth next-intersection operation. */
GeodesicNextIntersectionResult!T nextGeodesicIntersection(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T knownIntersection,
    const Angle!T firstAzimuth,
    const Angle!T secondAzimuth)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicNextIntersectionResult!T result;

    if (!tryNextGeodesicIntersection(
            solver,
            knownIntersection,
            firstAzimuth,
            secondAzimuth,
            result))
    {
        throw new GeodesyValueException(
            "Next geodesic intersection requires a valid known crossing, "
            ~ "valid azimuths, and a converged supported spherical or "
            ~ "oblate solution.");
    }

    return result;
}


/// Example finding the next intersection with the throwing convenience API.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            wgs84!double());

    const known =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    const result =
        nextGeodesicIntersection(
            solver,
            known,
            Angle!double.fromDegrees(30.0),
            Angle!double.fromDegrees(120.0));

    assert(result.isValid);
}
