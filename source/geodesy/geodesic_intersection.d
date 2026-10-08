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
    Ellipsoid,
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
    atan,
    atan2,
    ceil,
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

    if (!(e2 > cast(W) -1)
        || !(e2 < cast(W) 1))
        return false;

    const W e =
        sqrt(abs(e2));

    const W factor =
        e2 > cast(W) 0
            ? atanh(e) / e
            : atan(e) / e;

    const W radiusSquared =
        a * a
        * cast(W) 0.5
        * (
            cast(W) 1
            + (cast(W) 1 - e2) * factor);

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

/** Derive closest-search spacing and tolerance for supported rotational ellipsoids. */
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
    const W meridionalHalf =
        cast(W) PI * a * (cast(W) 1 - f);
    t1 = meridionalHalf;
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
    W polarSemiConjugate;

    if (!tryIntersectionConjugateFromOrigin!T(
            line,
            tolerance,
            initial,
            true,
            polarSemiConjugate))
        return false;

    if (f < cast(W) 0)
    {
        t1 =
            cast(W) 2 * polarSemiConjugate;

        d1 =
            meridionalHalf / cast(W) 2;

        return isFiniteGeodesyScalar(t1)
            && isFiniteGeodesyScalar(d1)
            && t1 > cast(W) 0
            && d1 > cast(W) 0;
    }

    d1 =
        polarSemiConjugate;

    return true;
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

/** Find the closest intersection using already prepared family state. */
private bool tryClosestGeodesicIntersectionPrepared(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T referenceOnFirst,
    const T referenceOnSecond,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionWorkingScalar!T t1,
    const IntersectionWorkingScalar!T d1,
    const IntersectionWorkingScalar!T delta,
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

    const GeodesicIntersectionCoincidence coincidence =
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

/**
 * Find the closest intersection of two prepared oriented geodesics.
 *
 * This one-shot overload preserves the established API. Repeated callers can
 * prepare `GeodesicIntersectionSolver` once and use the matching overload.
 */
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

    if (!solver.isValid)
        return false;

    W authalicRadius;

    if (!tryAuthalicRadius!T(solver, authalicRadius))
        return false;

    W t1;
    W d1;
    W delta;

    if (!tryClosestIntersectionSpacing!T(
            solver, authalicRadius, t1, d1, delta))
        return false;

    return tryClosestGeodesicIntersectionPrepared!T(
        solver,
        firstLine,
        secondLine,
        referenceOnFirst,
        referenceOnSecond,
        authalicRadius,
        t1,
        d1,
        delta,
        result);
}

/** Find the closest intersection using reusable intersection-family state. */
bool tryClosestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T referenceOnFirst,
    const T referenceOnSecond,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result = GeodesicClosestIntersectionResult!T.init;

    if (!intersector._valid)
        return false;

    return tryClosestGeodesicIntersectionPrepared!T(
        intersector._solver,
        firstLine,
        secondLine,
        referenceOnFirst,
        referenceOnSecond,
        intersector._authalicRadius,
        intersector._closestT1,
        intersector._closestD1,
        intersector._closestDelta,
        result);
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

/** Zero-reference overload using reusable intersection-family state. */
bool tryClosestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryClosestGeodesicIntersection(
        intersector, firstLine, secondLine, cast(T) 0, cast(T) 0, result);
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

/** Construct lines and find the closest intersection using reusable family state. */
bool tryClosestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
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

    if (!intersector._valid)
        return false;

    GeodesicLine!T firstLine;
    GeodesicLine!T secondLine;

    if (!GeodesicLine!T.tryFromGeodesic(
            intersector._solver, firstStart, firstAzimuth, firstLine)
        || !GeodesicLine!T.tryFromGeodesic(
            intersector._solver, secondStart, secondAzimuth, secondLine))
        return false;

    return tryClosestGeodesicIntersection(
        intersector,
        firstLine,
        secondLine,
        referenceOnFirst,
        referenceOnSecond,
        result);
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

/** Zero-reference origin/azimuth overload using reusable family state. */
bool tryClosestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeographicCoordinate!T firstStart,
    const Angle!T firstAzimuth,
    const GeographicCoordinate!T secondStart,
    const Angle!T secondAzimuth,
    out GeodesicClosestIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryClosestGeodesicIntersection(
        intersector,
        firstStart,
        firstAzimuth,
        secondStart,
        secondAzimuth,
        cast(T) 0,
        cast(T) 0,
        result);
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

/** Throwing prepared-state closest intersection for prepared lines. */
GeodesicClosestIntersectionResult!T closestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T referenceOnFirst = cast(T) 0,
    const T referenceOnSecond = cast(T) 0)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicClosestIntersectionResult!T result;

    if (!tryClosestGeodesicIntersection(
            intersector,
            firstLine,
            secondLine,
            referenceOnFirst,
            referenceOnSecond,
            result))
        throw new GeodesyValueException(
            "Closest geodesic intersection failed for the supplied prepared "
            ~ "intersection state, lines, or reference.");

    return result;
}

/** Throwing prepared-state closest intersection for line definitions. */
GeodesicClosestIntersectionResult!T closestGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
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
            intersector,
            firstStart,
            firstAzimuth,
            secondStart,
            secondAzimuth,
            referenceOnFirst,
            referenceOnSecond,
            result))
        throw new GeodesyValueException(
            "Closest geodesic intersection failed for the supplied prepared "
            ~ "intersection state, line definitions, or reference.");

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



/**
 * One enumerated intersection of two oriented geodesics.
 *
 * Distances are signed displacements from the two line origins.
 * referenceDistance is the L1 rank relative to the caller reference pair.
 *
 * .init is invalid.
 */
struct GeodesicIntersectionPoint(T)
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

    /** Construct a validated enumerated intersection point. */
    static GeodesicIntersectionPoint fromComponents(
        const GeographicCoordinate!T position,
        const T distanceOnFirst,
        const T distanceOnSecond,
        const T referenceDistance,
        const GeodesicIntersectionCoincidence coincidence)
        pure nothrow @safe @nogc
    {
        GeodesicIntersectionPoint result;
        result._valid = true;
        result._position = position;
        result._distanceOnFirst = distanceOnFirst;
        result._distanceOnSecond = distanceOnSecond;
        result._referenceDistance = referenceDistance;
        result._coincidence = coincidence;
        return result;
    }

public:
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _valid;
    }

    /// Example checking the default invalid point state.
    @safe unittest
    {
        assert(!GeodesicIntersectionPoint!double.init.isValid);
    }

    @property GeographicCoordinate!T position() const
        pure nothrow @safe @nogc
    {
        return _position;
    }

    /// Example reading the default position.
    @safe unittest
    {
        GeodesicIntersectionPoint!double point;
        cast(void) point.position;
    }

    @property T distanceOnFirst() const pure nothrow @safe @nogc
    {
        return _distanceOnFirst;
    }

    /// Example reading the first signed displacement.
    @safe unittest
    {
        GeodesicIntersectionPoint!double point;
        cast(void) point.distanceOnFirst;
    }

    @property T distanceOnSecond() const pure nothrow @safe @nogc
    {
        return _distanceOnSecond;
    }

    /// Example reading the second signed displacement.
    @safe unittest
    {
        GeodesicIntersectionPoint!double point;
        cast(void) point.distanceOnSecond;
    }

    @property T referenceDistance() const pure nothrow @safe @nogc
    {
        return _referenceDistance;
    }

    /// Example reading the L1 rank.
    @safe unittest
    {
        GeodesicIntersectionPoint!double point;
        cast(void) point.referenceDistance;
    }

    @property GeodesicIntersectionCoincidence coincidence() const
        pure nothrow @safe @nogc
    {
        return _coincidence;
    }

    /// Example reading the default coincidence classification.
    @safe unittest
    {
        GeodesicIntersectionPoint!double point;
        assert(point.coincidence
            == GeodesicIntersectionCoincidence.distinct);
    }
}

/// Example using the all-intersection point type.
@safe unittest
{
    GeodesicIntersectionPoint!double point;
    assert(!point.isValid);
}


/** Checked enumeration status for all-intersection queries. */
enum GeodesicIntersectionEnumerationStatus
{
    invalid,
    success,
    workspaceTooSmall,
    numericalFailure
}

/// Example distinguishing success from insufficient workspace.
@safe unittest
{
    assert(GeodesicIntersectionEnumerationStatus.success
        != GeodesicIntersectionEnumerationStatus.workspaceTooSmall);
}


/**
 * Metadata produced by an all-intersection enumeration.
 *
 * Short output storage is a successful query with truncated == true.
 * Short workspace storage is reported separately as workspaceTooSmall.
 */
struct GeodesicIntersectionEnumeration
{
private:
    GeodesicIntersectionEnumerationStatus _status =
        GeodesicIntersectionEnumerationStatus.invalid;
    size_t _written;
    size_t _total;
    bool _truncated;
    size_t _requiredTiles;
    size_t _minimumFoundCapacity;

public:
    @property GeodesicIntersectionEnumerationStatus status() const
        pure nothrow @safe @nogc
    {
        return _status;
    }

    /// Example reading the default status.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(value.status
            == GeodesicIntersectionEnumerationStatus.invalid);
    }

    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _status == GeodesicIntersectionEnumerationStatus.success;
    }

    /// Example checking the default invalid enumeration.
    @safe unittest
    {
        assert(!GeodesicIntersectionEnumeration.init.isValid);
    }

    @property size_t written() const pure nothrow @safe @nogc
    {
        return _written;
    }

    /// Example reading the written count.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(value.written == 0);
    }

    @property size_t total() const pure nothrow @safe @nogc
    {
        return _total;
    }

    /// Example reading the total count.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(value.total == 0);
    }

    @property bool truncated() const pure nothrow @safe @nogc
    {
        return _truncated;
    }

    /// Example reading truncation metadata.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(!value.truncated);
    }

    @property size_t requiredTiles() const pure nothrow @safe @nogc
    {
        return _requiredTiles;
    }

    /// Example reading the required tile count.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(value.requiredTiles == 0);
    }

    @property size_t minimumFoundCapacity() const
        pure nothrow @safe @nogc
    {
        return _minimumFoundCapacity;
    }

    /// Example reading the observed result-workspace requirement.
    @safe unittest
    {
        GeodesicIntersectionEnumeration value;
        assert(value.minimumFoundCapacity == 0);
    }
}

/// Example using enumeration metadata.
@safe unittest
{
    GeodesicIntersectionEnumeration value;
    assert(!value.isValid);
}


/**
 * Opaque caller-owned scratch entry for all-intersection enumeration.
 *
 * Applications allocate arrays of this type but should not interpret their
 * contents.
 */
struct GeodesicIntersectionWorkspaceEntry(T)
if (isGeodesyScalar!T)
{
private:
    alias W = IntersectionWorkingScalar!T;
    W _x = W.nan;
    W _y = W.nan;
    int _coincidence;
}

/// Example allocating opaque workspace entries.
@safe unittest
{
    GeodesicIntersectionWorkspaceEntry!double[4] entries;
    assert(entries.length == 4);
}


/**
 * Caller-owned reusable scratch storage for all-intersection enumeration.
 *
 * No allocation is performed by the enumeration core.
 */
struct GeodesicIntersectionWorkspace(T)
if (isGeodesyScalar!T)
{
private:
    GeodesicIntersectionWorkspaceEntry!T[] _starts;
    bool[] _skip;
    GeodesicIntersectionWorkspaceEntry!T[] _found;
    GeodesicIntersectionWorkspaceEntry!T[] _coincidentCenters;

public:
    static bool tryFromStorage(
        GeodesicIntersectionWorkspaceEntry!T[] starts,
        bool[] skip,
        GeodesicIntersectionWorkspaceEntry!T[] found,
        GeodesicIntersectionWorkspaceEntry!T[] coincidentCenters,
        out GeodesicIntersectionWorkspace result)
        pure nothrow @safe @nogc
    {
        result = GeodesicIntersectionWorkspace.init;

        if (starts.length != skip.length
            || starts.length == 0
            || found.length == 0
            || coincidentCenters.length == 0)
            return false;

        result._starts = starts;
        result._skip = skip;
        result._found = found;
        result._coincidentCenters = coincidentCenters;
        return true;
    }

    /// Example preparing caller-owned workspace.
    @safe unittest
    {
        GeodesicIntersectionWorkspaceEntry!double[4] starts;
        bool[4] skip;
        GeodesicIntersectionWorkspaceEntry!double[8] found;
        GeodesicIntersectionWorkspaceEntry!double[4] centers;
        GeodesicIntersectionWorkspace!double workspace;

        assert(GeodesicIntersectionWorkspace!double.tryFromStorage(
            starts[], skip[], found[], centers[], workspace));
    }

    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _starts.length != 0
            && _starts.length == _skip.length
            && _found.length != 0
            && _coincidentCenters.length != 0;
    }

    /// Example checking the default invalid workspace.
    @safe unittest
    {
        assert(!GeodesicIntersectionWorkspace!double.init.isValid);
    }
}

/// Example using the workspace type.
@safe unittest
{
    GeodesicIntersectionWorkspace!double workspace;
    assert(!workspace.isValid);
}


/**
 * Prepared ellipsoid-dependent state for repeated geodesic intersections.
 *
 * Construction performs the invariant setup required by the intersection
 * family once. In particular, ellipsoid-dependent next-intersection spacing is prepared
 * here instead of being recomputed for every pair of lines.
 *
 * The prepared value is immutable-by-convention after construction and can be
 * reused across independent line pairs. One-shot overloads remain available
 * for occasional calls and use the same mathematical kernels.
 *
 * .init is invalid.
 */
struct GeodesicIntersectionSolver(T)
if (isGeodesyScalar!T)
{
private:
    alias W = IntersectionWorkingScalar!T;

    bool _valid;
    Geodesic!T _solver;
    W _authalicRadius = W.nan;

    W _closestT1 = W.nan;
    W _closestD1 = W.nan;
    W _closestDelta = W.nan;

    W _nextT1 = W.nan;
    W _nextD2 = W.nan;
    W _nextDelta = W.nan;
    W _halfCircumference = W.nan;

    W _allT1 = W.nan;
    W _allD3 = W.nan;
    W _allDelta = W.nan;

public:
    /**
     * Prepare reusable invariant state for the oriented-intersection family.
     *
     * Closest and next-intersection searches share the same geodesic solver
     * and authalic scale. Their ellipsoid-dependent seed spacings are derived
     * once here and reused by every prepared operation.
     */
    static bool tryFromGeodesic(
        const Geodesic!T solver,
        out GeodesicIntersectionSolver result)
        pure nothrow @safe @nogc
    {
        result = GeodesicIntersectionSolver.init;

        if (!solver.isValid)
            return false;

        W authalicRadius;

        if (!tryAuthalicRadius!T(
                solver,
                authalicRadius))
            return false;

        W closestT1;
        W closestD1;
        W closestDelta;

        if (!tryClosestIntersectionSpacing!T(
                solver,
                authalicRadius,
                closestT1,
                closestD1,
                closestDelta))
            return false;

        W nextT1;
        W nextD2;
        W nextDelta;
        W halfCircumference;

        if (!tryNextIntersectionSpacing!T(
                solver,
                authalicRadius,
                nextT1,
                nextD2,
                nextDelta,
                halfCircumference))
            return false;

        result._solver = solver;
        result._authalicRadius = authalicRadius;

        result._closestT1 = closestT1;
        result._closestD1 = closestD1;
        result._closestDelta = closestDelta;

        result._nextT1 = nextT1;
        result._nextD2 = nextD2;
        result._nextDelta = nextDelta;
        result._halfCircumference = halfCircumference;

        const W flattening =
            cast(W) solver.ellipsoid.flattening;

        W allT4 =
            nextT1;

        if (flattening < cast(W) 0
            && !tryIntersectionPolarBound!T(
                solver,
                authalicRadius,
                allT4))
            return false;

        result._allT1 = nextT1;
        result._allDelta = nextDelta;
        result._allD3 = allT4 - nextDelta;

        if (!(result._allD3 > cast(W) 0))
            return false;

        result._valid = true;
        return true;
    }

    /// Example preparing reusable intersection-family state.
    @safe unittest
    {
        const solver = Geodesic!double.fromEllipsoid(wgs84!double());
        GeodesicIntersectionSolver!double prepared;

        assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
            solver, prepared));
        assert(prepared.isValid);
    }

    /** True when invariant intersection-family setup was prepared successfully. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _valid;
    }

    /// Example preparing the intersection family for a qualified prolate ellipsoid.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.fromFlattening(
                    6_378_137.0,
                    -0.01));

        GeodesicIntersectionSolver!double prepared;

        assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
            solver,
            prepared));
        assert(prepared.isValid);
    }

    /// Example checking the default invalid prepared state.
    @safe unittest
    {
        assert(!GeodesicIntersectionSolver!double.init.isValid);
    }
}


/// Example using reusable intersection-family state.
@safe unittest
{
    GeodesicIntersectionSolver!double prepared;
    assert(!prepared.isValid);
}


// Prepared state is valid and preserves closest-search results.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());

    GeodesicIntersectionSolver!double intersector;
    assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
        solver, intersector));
    assert(intersector.isValid);

    const firstStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(-20.0));
    const secondStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(20.0));

    GeodesicClosestIntersectionResult!double oneShot;
    GeodesicClosestIntersectionResult!double prepared;

    assert(tryClosestGeodesicIntersection(
        solver,
        firstStart,
        Angle!double.fromDegrees(45.0),
        secondStart,
        Angle!double.fromDegrees(-60.0),
        oneShot));

    assert(tryClosestGeodesicIntersection(
        intersector,
        firstStart,
        Angle!double.fromDegrees(45.0),
        secondStart,
        Angle!double.fromDegrees(-60.0),
        prepared));

    assert(prepared.position == oneShot.position);
    assert(prepared.distanceOnFirst == oneShot.distanceOnFirst);
    assert(prepared.distanceOnSecond == oneShot.distanceOnSecond);
    assert(prepared.referenceDistance == oneShot.referenceDistance);
    assert(prepared.coincidence == oneShot.coincidence);
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


/** Compute the polar semi-conjugate distance from a selected latitude. */
private bool tryIntersectionDistPolar(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionWorkingScalar!T latitudeDegrees,
    out IntersectionWorkingScalar!T distance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    Latitude!T latitude;
    Longitude!T longitude;
    Angle!T azimuth;

    if (!Latitude!T.tryFromRadians(
            cast(T) (
                latitudeDegrees
                * cast(W) PI
                / cast(W) 180),
            latitude)
        || !Longitude!T.tryFromRadians(
            cast(T) 0,
            longitude)
        || !Angle!T.tryFromRadians(
            cast(T) 0,
            azimuth))
        return false;

    const auto origin =
        GeographicCoordinate!T.fromComponents(
            latitude,
            longitude);

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
        d * pow(
            W.epsilon,
            cast(W) 0.75);

    const W f =
        cast(W) solver.ellipsoid.flattening;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    const W initial =
        (cast(W) 1 + f / cast(W) 2)
        * a
        * cast(W) PI
        / cast(W) 2;

    return tryIntersectionConjugateFromOrigin!T(
        line,
        tolerance,
        initial,
        true,
        distance);
}


/** Derive GeographicLib's polar tiling bound used for prolate All searches. */
private bool tryIntersectionPolarBound(T)(
    const Geodesic!T solver,
    const IntersectionWorkingScalar!T authalicRadius,
    out IntersectionWorkingScalar!T distance)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    W lat0 = cast(W) 63;
    W lat1 = cast(W) 65;
    W lat2 = cast(W) 64;

    W s0;
    W s1;
    W s2;

    if (!tryIntersectionDistPolar!T(
            solver, authalicRadius, lat0, s0)
        || !tryIntersectionDistPolar!T(
            solver, authalicRadius, lat1, s1)
        || !tryIntersectionDistPolar!T(
            solver, authalicRadius, lat2, s2))
        return false;

    W best =
        s2;

    const W f =
        cast(W) solver.ellipsoid.flattening;

    foreach (_; 0 .. 10)
    {
        const W denominator =
            (lat1 - lat0) * s2
            + (lat0 - lat2) * s1
            + (lat2 - lat1) * s0;

        if (!(denominator < cast(W) 0
            || denominator > cast(W) 0))
            break;

        const W nextLatitude =
            (
                (lat1 - lat0) * (lat1 + lat0) * s2
                + (lat0 - lat2) * (lat0 + lat2) * s1
                + (lat2 - lat1) * (lat2 + lat1) * s0
            )
            / (
                cast(W) 2 * denominator);

        lat0 = lat1;
        s0 = s1;
        lat1 = lat2;
        s1 = s2;
        lat2 = nextLatitude;

        if (!tryIntersectionDistPolar!T(
                solver,
                authalicRadius,
                lat2,
                s2))
            return false;

        const bool improves =
            f < cast(W) 0
                ? s2 < best
                : s2 > best;

        if (improves)
            best = s2;
    }

    distance =
        cast(W) 2 * best;

    return isFiniteGeodesyScalar(distance)
        && distance > cast(W) 0;
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
    else if (f < cast(W) 0)
    {
        Latitude!T poleLatitude;
        Longitude!T zeroLongitude;
        Latitude!T zeroLatitude;

        if (!Latitude!T.tryFromRadians(
                cast(T) (cast(W) PI / cast(W) 2),
                poleLatitude)
            || !Latitude!T.tryFromRadians(
                cast(T) 0,
                zeroLatitude)
            || !Longitude!T.tryFromRadians(
                cast(T) 0,
                zeroLongitude))
            return false;

        const auto equator =
            GeographicCoordinate!T.fromComponents(
                zeroLatitude,
                zeroLongitude);

        const auto pole =
            GeographicCoordinate!T.fromComponents(
                poleLatitude,
                zeroLongitude);

        GeodesicInverseResult!T meridian;

        if (!solver.tryInverse(
                equator,
                pole,
                meridian))
            return false;

        t3 =
            cast(W) 2
            * cast(W) meridian.distance;

        W polarSemiConjugate;

        if (!tryIntersectionDistPolar!T(
                solver,
                authalicRadius,
                cast(W) 90,
                polarSemiConjugate))
            return false;

        t1 =
            cast(W) 2
            * polarSemiConjugate;
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
private bool tryNextGeodesicIntersectionPrepared(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionWorkingScalar!T t1,
    const IntersectionWorkingScalar!T d2,
    const IntersectionWorkingScalar!T delta,
    const IntersectionWorkingScalar!T d,
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



/**
 * Find the next closest intersection after a known common-origin crossing.
 *
 * This one-shot overload preserves the existing API and computes invariant
 * ellipsoid spacing for the call. Repeated callers should use the prepared
 * GeodesicIntersectionSolver overload.
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

    result = GeodesicNextIntersectionResult!T.init;

    if (!solver.isValid)
        return false;

    W authalicRadius;

    if (!tryAuthalicRadius!T(
            solver,
            authalicRadius))
        return false;

    W t1;
    W d2;
    W delta;
    W halfCircumference;

    if (!tryNextIntersectionSpacing!T(
            solver,
            authalicRadius,
            t1,
            d2,
            delta,
            halfCircumference))
        return false;

    return tryNextGeodesicIntersectionPrepared!T(
        solver,
        firstLine,
        secondLine,
        authalicRadius,
        t1,
        d2,
        delta,
        halfCircumference,
        result);
}


/**
 * Find the next intersection using ellipsoid-dependent prepared state.
 *
 * Preparation cost is excluded from the repeated operation while the
 * mathematical result and line-origin validation remain identical to the
 * one-shot overload.
 */
bool tryNextGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    out GeodesicNextIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result = GeodesicNextIntersectionResult!T.init;

    if (!intersector._valid)
        return false;

    return tryNextGeodesicIntersectionPrepared!T(
        intersector._solver,
        firstLine,
        secondLine,
        intersector._authalicRadius,
        intersector._nextT1,
        intersector._nextD2,
        intersector._nextDelta,
        intersector._halfCircumference,
        result);
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


/** Construct common-origin lines and find the next crossing using reusable family state. */
bool tryNextGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeographicCoordinate!T knownIntersection,
    const Angle!T firstAzimuth,
    const Angle!T secondAzimuth,
    out GeodesicNextIntersectionResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result = GeodesicNextIntersectionResult!T.init;

    if (!intersector._valid)
        return false;

    GeodesicLine!T firstLine;
    GeodesicLine!T secondLine;

    if (!GeodesicLine!T.tryFromGeodesic(
            intersector._solver,
            knownIntersection,
            firstAzimuth,
            firstLine)
        || !GeodesicLine!T.tryFromGeodesic(
            intersector._solver,
            knownIntersection,
            secondAzimuth,
            secondLine))
        return false;

    return tryNextGeodesicIntersection(
        intersector,
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


/** Throwing prepared-state next-intersection operation for prepared lines. */
GeodesicNextIntersectionResult!T nextGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicNextIntersectionResult!T result;

    if (!tryNextGeodesicIntersection(
            intersector,
            firstLine,
            secondLine,
            result))
    {
        throw new GeodesyValueException(
            "Next geodesic intersection requires valid prepared intersection "
            ~ "state and lines sharing the same known geographic origin.");
    }

    return result;
}

/** Throwing prepared-state next-intersection operation for a known crossing. */
GeodesicNextIntersectionResult!T nextGeodesicIntersection(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeographicCoordinate!T knownIntersection,
    const Angle!T firstAzimuth,
    const Angle!T secondAzimuth)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicNextIntersectionResult!T result;

    if (!tryNextGeodesicIntersection(
            intersector,
            knownIntersection,
            firstAzimuth,
            secondAzimuth,
            result))
    {
        throw new GeodesyValueException(
            "Next geodesic intersection requires valid prepared intersection "
            ~ "state, a valid known crossing, and valid azimuths.");
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


/** Compare two workspace entries using the family duplicate tolerance. */
private bool allIntersectionEntryEqual(T)(
    const GeodesicIntersectionWorkspaceEntry!T first,
    const GeodesicIntersectionWorkspaceEntry!T second,
    const IntersectionWorkingScalar!T delta)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    return abs(first._x - second._x)
        + abs(first._y - second._y)
        <= delta;
}


/** Convert one internal displacement into opaque workspace storage. */
private GeodesicIntersectionWorkspaceEntry!T allIntersectionEntry(T)(
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) point)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    GeodesicIntersectionWorkspaceEntry!T result;
    result._x = point.x;
    result._y = point.y;
    result._coincidence = point.coincidence;
    return result;
}


private IntersectionDisplacement!(IntersectionWorkingScalar!T)
allIntersectionPoint(T)(
    const GeodesicIntersectionWorkspaceEntry!T entry)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    return IntersectionDisplacement!W(
        entry._x,
        entry._y,
        entry._coincidence);
}


/** Return whether a workspace prefix already contains an equivalent point. */
private bool allIntersectionContains(T)(
    const GeodesicIntersectionWorkspaceEntry!T[] values,
    const size_t count,
    const GeodesicIntersectionWorkspaceEntry!T value,
    const IntersectionWorkingScalar!T delta)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    foreach (i; 0 .. count)
    {
        if (allIntersectionEntryEqual!T(
                values[i],
                value,
                delta))
            return true;
    }

    return false;
}


/** Append one workspace entry when caller-provided capacity permits it. */
private bool appendAllIntersectionEntry(T)(
    GeodesicIntersectionWorkspaceEntry!T[] values,
    ref size_t count,
    const GeodesicIntersectionWorkspaceEntry!T value)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (count >= values.length)
        return false;

    values[count++] = value;
    return true;
}


/** Remove stored points belonging to one normalized coincident line. */
private void removeAllCoincidentLine(T)(
    GeodesicIntersectionWorkspaceEntry!T[] values,
    ref size_t count,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) reference,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) normalized,
    const int coincidence,
    const IntersectionWorkingScalar!T delta)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    size_t outIndex;

    foreach (i; 0 .. count)
    {
        auto point = allIntersectionPoint!T(values[i]);
        point.coincidence = coincidence;
        point = fixClosestCoincident!W(reference, point);

        if (intersectionL1!W(point, normalized) > delta)
            values[outIndex++] = values[i];
    }

    count = outIndex;
}


/** Compare two entries by L1 rank and deterministic displacement tie-breaks. */
private bool allIntersectionLess(T)(
    const GeodesicIntersectionWorkspaceEntry!T first,
    const GeodesicIntersectionWorkspaceEntry!T second,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) reference)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;
    const auto a = allIntersectionPoint!T(first);
    const auto b = allIntersectionPoint!T(second);
    const W da = intersectionL1!W(a, reference);
    const W db = intersectionL1!W(b, reference);

    if (da != db)
        return da < db;
    if (a.x != b.x)
        return a.x < b.x;
    return a.y < b.y;
}


/** Sort the retained result prefix in canonical all-intersection order. */
private void sortAllIntersections(T)(
    GeodesicIntersectionWorkspaceEntry!T[] values,
    const size_t count,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) reference)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    foreach (i; 1 .. count)
    {
        const auto value = values[i];
        size_t j = i;

        while (j > 0
            && allIntersectionLess!T(
                value,
                values[j - 1],
                reference))
        {
            values[j] = values[j - 1];
            --j;
        }

        values[j] = value;
    }
}


/** Mark later tile seeds covered by a converged intersection neighborhood. */
private void updateAllIntersectionSkip(T)(
    bool[] skip,
    const GeodesicIntersectionWorkspaceEntry!T[] starts,
    const size_t from,
    const IntersectionDisplacement!(IntersectionWorkingScalar!T) point,
    const IntersectionWorkingScalar!T threshold)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    foreach (i; from .. starts.length)
    {
        if (!skip[i]
            && intersectionL1!W(
                point,
                allIntersectionPoint!T(starts[i]))
                < threshold)
            skip[i] = true;
    }
}


/** Enumerate all intersections using already prepared family state. */
private bool tryAllGeodesicIntersectionsPrepared(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const IntersectionWorkingScalar!T authalicRadius,
    const IntersectionWorkingScalar!T t1,
    const IntersectionWorkingScalar!T d3,
    const IntersectionWorkingScalar!T delta,
    const IntersectionWorkingScalar!T halfCircumference,
    const T maxDisplacement,
    const T referenceOnFirst,
    const T referenceOnSecond,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace,
    out GeodesicIntersectionEnumeration enumeration)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = IntersectionWorkingScalar!T;

    enumeration = GeodesicIntersectionEnumeration.init;

    if (!solver.isValid
        || !firstLine.isValid
        || !secondLine.isValid
        || !workspace.isValid
        || !isFiniteGeodesyScalar(maxDisplacement)
        || !isFiniteGeodesyScalar(referenceOnFirst)
        || !isFiniteGeodesyScalar(referenceOnSecond)
        || maxDisplacement < cast(T) 0)
        return false;

    const IntersectionDisplacement!W reference =
        IntersectionDisplacement!W(
            cast(W) referenceOnFirst,
            cast(W) referenceOnSecond,
            0);

    const W radius =
        cast(W) maxDisplacement;

    const W expanded =
        radius + delta;

    size_t tiles =
        cast(size_t) ceil(expanded / d3);

    if (tiles == 0)
        tiles = 1;

    const size_t requiredTiles =
        tiles * tiles + (tiles - 1) % 2;

    enumeration._requiredTiles = requiredTiles;

    if (workspace._starts.length < requiredTiles
        || workspace._skip.length < requiredTiles)
    {
        enumeration._status =
            GeodesicIntersectionEnumerationStatus.workspaceTooSmall;
        return false;
    }

    const size_t n = tiles - 1;
    const W spacing =
        expanded / cast(W) tiles;

    size_t startCount;
    workspace._starts[startCount++] =
        allIntersectionEntry!T(reference);

    for (long i = -cast(long) n;
         i <= cast(long) n;
         i += 2)
    {
        for (long j = -cast(long) n;
             j <= cast(long) n;
             j += 2)
        {
            if (i == 0 && j == 0)
                continue;

            const auto seed =
                IntersectionDisplacement!W(
                    reference.x
                        + spacing
                            * cast(W) (i + j)
                            / cast(W) 2,
                    reference.y
                        + spacing
                            * cast(W) (i - j)
                            / cast(W) 2,
                    0);

            workspace._starts[startCount++] =
                allIntersectionEntry!T(seed);
        }
    }

    if (startCount != requiredTiles)
    {
        enumeration._status =
            GeodesicIntersectionEnumerationStatus.numericalFailure;
        return false;
    }

    foreach (i; 0 .. requiredTiles)
        workspace._skip[i] = false;

    const PreparedSegment!T first =
        PreparedSegment!T(cast(T) 0, firstLine);

    const PreparedSegment!T second =
        PreparedSegment!T(cast(T) 0, secondLine);

    size_t foundCount;
    size_t coincidentCount;
    int coincidenceOrientation;

    const W skipThreshold =
        cast(W) 2 * t1 - spacing - delta;

    foreach (k; 0 .. requiredTiles)
    {
        if (workspace._skip[k])
            continue;

        IntersectionDisplacement!W candidate;

        if (!tryBasicIntersection!T(
                solver,
                first,
                second,
                authalicRadius,
                allIntersectionPoint!T(
                    workspace._starts[k]),
                candidate))
        {
            enumeration._status =
                GeodesicIntersectionEnumerationStatus.numericalFailure;
            return false;
        }

        auto candidateEntry =
            allIntersectionEntry!T(candidate);

        if (allIntersectionContains!T(
                workspace._found,
                foundCount,
                candidateEntry,
                delta))
            continue;

        if (coincidenceOrientation != 0)
        {
            auto normalizedCandidate = candidate;
            normalizedCandidate.coincidence =
                coincidenceOrientation;

            normalizedCandidate =
                fixClosestCoincident!W(
                    reference,
                    normalizedCandidate);

            if (allIntersectionContains!T(
                    workspace._coincidentCenters,
                    coincidentCount,
                    allIntersectionEntry!T(
                        normalizedCandidate),
                    delta))
                continue;
        }

        if (candidate.coincidence != 0)
        {
            coincidenceOrientation =
                candidate.coincidence;

            candidate =
                fixClosestCoincident!W(
                    reference,
                    candidate);

            candidateEntry =
                allIntersectionEntry!T(candidate);

            if (!appendAllIntersectionEntry!T(
                    workspace._coincidentCenters,
                    coincidentCount,
                    candidateEntry))
            {
                enumeration._minimumFoundCapacity =
                    coincidentCount + 1;
                enumeration._status =
                    GeodesicIntersectionEnumerationStatus.workspaceTooSmall;
                return false;
            }

            removeAllCoincidentLine!T(
                workspace._found,
                foundCount,
                reference,
                candidate,
                coincidenceOrientation,
                delta);

            const W s0 = candidate.x;
            GeodesicDirectResult!T position;
            GeodesicQuantities!T quantities;

            if (!firstLine.tryPosition(
                    cast(T) s0,
                    position,
                    quantities))
            {
                enumeration._status =
                    GeodesicIntersectionEnumerationStatus.numericalFailure;
                return false;
            }

            foreach (sign; [-1, 1])
            {
                W sa = cast(W) 0;
                IntersectionDisplacement!W conjugatePoint;

                do
                {
                    W absoluteDistance;

                    if (!tryIntersectionConjugateDistance!T(
                            firstLine,
                            halfCircumference
                                * pow(
                                    W.epsilon,
                                    cast(W) 0.75),
                            s0 + sa
                                + cast(W) sign
                                    * halfCircumference,
                            false,
                            cast(W) quantities.reducedLength,
                            cast(W) quantities.scale12,
                            cast(W) quantities.scale21,
                            absoluteDistance))
                    {
                        enumeration._status =
                            GeodesicIntersectionEnumerationStatus.numericalFailure;
                        return false;
                    }

                    sa =
                        absoluteDistance - s0;

                    conjugatePoint =
                        IntersectionDisplacement!W(
                            candidate.x + sa,
                            candidate.y
                                + cast(W) coincidenceOrientation
                                    * sa,
                            coincidenceOrientation);

                    const auto conjugateEntry =
                        allIntersectionEntry!T(
                            conjugatePoint);

                    if (!allIntersectionContains!T(
                            workspace._found,
                            foundCount,
                            conjugateEntry,
                            delta))
                    {
                        if (!appendAllIntersectionEntry!T(
                                workspace._found,
                                foundCount,
                                conjugateEntry))
                        {
                            enumeration._minimumFoundCapacity =
                                foundCount + 1;
                            enumeration._status =
                                GeodesicIntersectionEnumerationStatus.workspaceTooSmall;
                            return false;
                        }
                    }

                    updateAllIntersectionSkip!T(
                        workspace._skip[0 .. requiredTiles],
                        workspace._starts[0 .. requiredTiles],
                        k + 1,
                        conjugatePoint,
                        skipThreshold);
                }
                while (intersectionL1!W(
                    conjugatePoint,
                    reference) <= expanded);
            }
        }

        candidateEntry =
            allIntersectionEntry!T(candidate);

        if (!allIntersectionContains!T(
                workspace._found,
                foundCount,
                candidateEntry,
                delta))
        {
            if (!appendAllIntersectionEntry!T(
                    workspace._found,
                    foundCount,
                    candidateEntry))
            {
                enumeration._minimumFoundCapacity =
                    foundCount + 1;
                enumeration._status =
                    GeodesicIntersectionEnumerationStatus.workspaceTooSmall;
                return false;
            }
        }

        updateAllIntersectionSkip!T(
            workspace._skip[0 .. requiredTiles],
            workspace._starts[0 .. requiredTiles],
            k + 1,
            candidate,
            skipThreshold);
    }

    size_t retainedCount;

    foreach (i; 0 .. foundCount)
    {
        const auto point =
            allIntersectionPoint!T(
                workspace._found[i]);

        if (intersectionL1!W(
                point,
                reference) <= radius)
            workspace._found[retainedCount++] =
                workspace._found[i];
    }

    foundCount = retainedCount;

    sortAllIntersections!T(
        workspace._found,
        foundCount,
        reference);

    const size_t written =
        output.length < foundCount
            ? output.length
            : foundCount;

    foreach (i; 0 .. written)
    {
        const auto point =
            allIntersectionPoint!T(
                workspace._found[i]);

        GeodesicDirectResult!T position;

        if (!firstLine.tryPosition(
                cast(T) point.x,
                position))
        {
            enumeration._status =
                GeodesicIntersectionEnumerationStatus.numericalFailure;
            return false;
        }

        const GeodesicIntersectionCoincidence coincidence =
            point.coincidence > 0
                ? GeodesicIntersectionCoincidence.parallel
                : point.coincidence < 0
                    ? GeodesicIntersectionCoincidence.antiparallel
                    : GeodesicIntersectionCoincidence.distinct;

        output[i] =
            GeodesicIntersectionPoint!T.fromComponents(
                position.position,
                cast(T) point.x,
                cast(T) point.y,
                cast(T) intersectionL1!W(
                    point,
                    reference),
                coincidence);
    }

    enumeration._written = written;
    enumeration._total = foundCount;
    enumeration._truncated =
        written < foundCount;
    enumeration._minimumFoundCapacity =
        foundCount;
    enumeration._status =
        GeodesicIntersectionEnumerationStatus.success;

    return true;
}


/**
 * Enumerate all intersections within an L1 displacement radius.
 *
 * The core path is allocation-free. Output storage may be shorter than the
 * result set; in that case the canonical prefix is written and truncated is
 * true. Workspace storage must be sufficient to compute the exact total.
 */
bool tryAllGeodesicIntersections(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    const T referenceOnFirst,
    const T referenceOnSecond,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace,
    out GeodesicIntersectionEnumeration enumeration)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!intersector._valid)
    {
        enumeration = GeodesicIntersectionEnumeration.init;
        return false;
    }

    return tryAllGeodesicIntersectionsPrepared!T(
        intersector._solver,
        firstLine,
        secondLine,
        intersector._authalicRadius,
        intersector._allT1,
        intersector._allD3,
        intersector._allDelta,
        intersector._halfCircumference,
        maxDisplacement,
        referenceOnFirst,
        referenceOnSecond,
        output,
        workspace,
        enumeration);
}


/** One-shot all-intersection enumeration using the same mathematical kernel. */
bool tryAllGeodesicIntersections(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    const T referenceOnFirst,
    const T referenceOnSecond,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace,
    out GeodesicIntersectionEnumeration enumeration)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    GeodesicIntersectionSolver!T intersector;

    if (!GeodesicIntersectionSolver!T.tryFromGeodesic(
            solver,
            intersector))
    {
        enumeration = GeodesicIntersectionEnumeration.init;
        return false;
    }

    return tryAllGeodesicIntersections(
        intersector,
        firstLine,
        secondLine,
        maxDisplacement,
        referenceOnFirst,
        referenceOnSecond,
        output,
        workspace,
        enumeration);
}


/** Zero-reference overload using prepared state. */
bool tryAllGeodesicIntersections(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace,
    out GeodesicIntersectionEnumeration enumeration)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryAllGeodesicIntersections(
        intersector,
        firstLine,
        secondLine,
        maxDisplacement,
        cast(T) 0,
        cast(T) 0,
        output,
        workspace,
        enumeration);
}



/** Zero-reference one-shot overload. */
bool tryAllGeodesicIntersections(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace,
    out GeodesicIntersectionEnumeration enumeration)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryAllGeodesicIntersections(
        solver,
        firstLine,
        secondLine,
        maxDisplacement,
        cast(T) 0,
        cast(T) 0,
        output,
        workspace,
        enumeration);
}


/** Throwing prepared-state zero-reference all-intersection enumeration. */
GeodesicIntersectionEnumeration allGeodesicIntersections(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace)
    @safe
if (isGeodesyScalar!T)
{
    return allGeodesicIntersections(
        intersector,
        firstLine,
        secondLine,
        maxDisplacement,
        cast(T) 0,
        cast(T) 0,
        output,
        workspace);
}


/** Throwing one-shot all-intersection enumeration. */
GeodesicIntersectionEnumeration allGeodesicIntersections(T)(
    const Geodesic!T solver,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    const T referenceOnFirst,
    const T referenceOnSecond,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicIntersectionEnumeration enumeration;

    if (!tryAllGeodesicIntersections(
            solver,
            firstLine,
            secondLine,
            maxDisplacement,
            referenceOnFirst,
            referenceOnSecond,
            output,
            workspace,
            enumeration))
    {
        throw new GeodesyValueException(
            "All geodesic intersections require a valid solver, valid lines, "
            ~ "a non-negative finite displacement radius, and sufficient "
            ~ "caller-owned workspace.");
    }

    return enumeration;
}



/// Example enumerating intersections without throwing.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());
    GeodesicIntersectionSolver!double intersector;
    assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
        solver, intersector));

    const firstStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0));
    const secondStart = firstStart;

    GeodesicLine!double firstLine;
    GeodesicLine!double secondLine;

    assert(GeodesicLine!double.tryFromGeodesic(
        solver, firstStart, Angle!double.fromDegrees(30.0), firstLine));
    assert(GeodesicLine!double.tryFromGeodesic(
        solver, secondStart, Angle!double.fromDegrees(120.0), secondLine));

    GeodesicIntersectionWorkspaceEntry!double[16] starts;
    bool[16] skip;
    GeodesicIntersectionWorkspaceEntry!double[32] found;
    GeodesicIntersectionWorkspaceEntry!double[16] centers;
    GeodesicIntersectionWorkspace!double workspace;

    assert(GeodesicIntersectionWorkspace!double.tryFromStorage(
        starts[], skip[], found[], centers[], workspace));

    GeodesicIntersectionPoint!double[8] output;
    GeodesicIntersectionEnumeration enumeration;

    assert(tryAllGeodesicIntersections(
        intersector,
        firstLine,
        secondLine,
        1_000_000.0,
        output[],
        workspace,
        enumeration));

    assert(enumeration.isValid);
    assert(enumeration.total >= 1);
}


/** Throwing prepared-state all-intersection enumeration. */
GeodesicIntersectionEnumeration allGeodesicIntersections(T)(
    const GeodesicIntersectionSolver!T intersector,
    const GeodesicLine!T firstLine,
    const GeodesicLine!T secondLine,
    const T maxDisplacement,
    const T referenceOnFirst,
    const T referenceOnSecond,
    GeodesicIntersectionPoint!T[] output,
    ref GeodesicIntersectionWorkspace!T workspace)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicIntersectionEnumeration enumeration;

    if (!tryAllGeodesicIntersections(
            intersector,
            firstLine,
            secondLine,
            maxDisplacement,
            referenceOnFirst,
            referenceOnSecond,
            output,
            workspace,
            enumeration))
    {
        throw new GeodesyValueException(
            "All geodesic intersections require valid prepared state, "
            ~ "valid lines, a non-negative finite displacement radius, "
            ~ "and sufficient caller-owned workspace.");
    }

    return enumeration;
}



/// Example using the throwing all-intersection convenience.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());
    GeodesicIntersectionSolver!double intersector;
    assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
        solver, intersector));

    const origin = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0));

    GeodesicLine!double firstLine;
    GeodesicLine!double secondLine;

    assert(GeodesicLine!double.tryFromGeodesic(
        solver, origin, Angle!double.fromDegrees(30.0), firstLine));
    assert(GeodesicLine!double.tryFromGeodesic(
        solver, origin, Angle!double.fromDegrees(120.0), secondLine));

    GeodesicIntersectionWorkspaceEntry!double[16] starts;
    bool[16] skip;
    GeodesicIntersectionWorkspaceEntry!double[32] found;
    GeodesicIntersectionWorkspaceEntry!double[16] centers;
    GeodesicIntersectionWorkspace!double workspace;

    assert(GeodesicIntersectionWorkspace!double.tryFromStorage(
        starts[], skip[], found[], centers[], workspace));

    GeodesicIntersectionPoint!double[8] output;

    const enumeration = allGeodesicIntersections(
        intersector,
        firstLine,
        secondLine,
        1_000_000.0,
        output[],
        workspace);

    assert(enumeration.isValid);
}


// Prepared throwing conveniences preserve the one-shot #104/#105 results.
@safe unittest
{
    const solver = Geodesic!double.fromEllipsoid(wgs84!double());

    GeodesicIntersectionSolver!double intersector;
    assert(GeodesicIntersectionSolver!double.tryFromGeodesic(
        solver, intersector));

    const firstStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(-20.0));
    const secondStart = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(20.0));

    const closestOneShot = closestGeodesicIntersection(
        solver,
        firstStart,
        Angle!double.fromDegrees(45.0),
        secondStart,
        Angle!double.fromDegrees(-60.0));

    const closestPrepared = closestGeodesicIntersection(
        intersector,
        firstStart,
        Angle!double.fromDegrees(45.0),
        secondStart,
        Angle!double.fromDegrees(-60.0));

    assert(closestPrepared.position == closestOneShot.position);
    assert(closestPrepared.distanceOnFirst == closestOneShot.distanceOnFirst);
    assert(closestPrepared.distanceOnSecond == closestOneShot.distanceOnSecond);
    assert(closestPrepared.referenceDistance == closestOneShot.referenceDistance);
    assert(closestPrepared.coincidence == closestOneShot.coincidence);

    const known = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0));

    const nextOneShot = nextGeodesicIntersection(
        solver,
        known,
        Angle!double.fromDegrees(30.0),
        Angle!double.fromDegrees(120.0));

    const nextPrepared = nextGeodesicIntersection(
        intersector,
        known,
        Angle!double.fromDegrees(30.0),
        Angle!double.fromDegrees(120.0));

    assert(nextPrepared.position == nextOneShot.position);
    assert(nextPrepared.distanceOnFirst == nextOneShot.distanceOnFirst);
    assert(nextPrepared.distanceOnSecond == nextOneShot.distanceOnSecond);
    assert(nextPrepared.displacementDistance == nextOneShot.displacementDistance);
    assert(nextPrepared.coincidence == nextOneShot.coincidence);
}
