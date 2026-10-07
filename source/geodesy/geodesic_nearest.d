/**
 * Ellipsoidal nearest-point geometry for bounded geodesic segments.
 *
 * The public operation finds the nearest point from a geographic target to the
 * shortest geodesic segment from A to B. Internally it uses Karney's
 * ellipsoidal gnomonic interception method, expressed entirely through the
 * existing Geodesic and GeodesicLine differential quantities.
 *
 * The supporting-geodesic intercept and the bounded-segment nearest point are
 * intentionally reported separately. Cross-track distance is positive on the
 * right of the oriented A -> B geodesic and negative on the left. Along-track
 * distance is signed from A in the A -> B direction.
 *
 * Degenerate segments with A == B are rejected because their orientation is
 * undefined. The checked operation also returns false when the local
 * ellipsoidal gnomonic construction is outside its supported horizon or fails
 * to converge. No global uniqueness claim is made for an indefinitely
 * extended geodesic on the closed ellipsoid.
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
module geodesy.geodesic_nearest;

import std.math :
    PI,
    abs,
    atan,
    atan2,
    cos,
    hypot,
    sin,
    sqrt;

import geodesy.angle : Angle;
import geodesy.errors : GeodesyValueException;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult,
    GeodesicLine,
    GeodesicQuantities;
import geodesy.geographic : GeographicCoordinate;
import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;

private template NearestWorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias NearestWorkingScalar = double;
    else
        alias NearestWorkingScalar = T;
}

private W wrapPi(W)(W value)
    pure nothrow @safe @nogc
{
    const W p = cast(W) PI;
    const W period = cast(W) 2 * p;

    value %= period;

    if (value >= p)
        value -= period;
    else if (value < -p)
        value += period;

    return value == cast(W) 0
        ? cast(W) 0
        : value;
}

private struct GnomonicPoint(W)
{
    W x;
    W y;
}

/**
 * Location of the bounded-segment nearest point.
 *
 * invalid is the .init value. Successful operations return start, interior,
 * or end.
 */
enum GeodesicSegmentNearestLocation : ubyte
{
    invalid,
    start,
    interior,
    end
}

/// Example classifying an interior nearest point.
@safe unittest
{
    const location =
        GeodesicSegmentNearestLocation.interior;
    assert(location != GeodesicSegmentNearestLocation.invalid);
}

/**
 * Result of nearest-point evaluation against one bounded geodesic segment.
 *
 * intercept is the local perpendicular foot on the oriented supporting
 * geodesic. nearestPoint is the actual nearest point on the bounded segment.
 * They are equal for an interior result and differ when endpoint clamping is
 * required.
 *
 * Distances use the ellipsoid linear unit. alongTrackDistance is signed and
 * unclamped. signedCrossTrackDistance is positive right of A -> B and negative
 * left. segmentAlongTrackDistance is clamped to the segment. nearestDistance
 * is always unsigned.
 *
 * .init is invalid.
 */
struct GeodesicSegmentNearestResult(T)
if (isGeodesyScalar!T)
{
private:
    bool _valid;
    GeographicCoordinate!T _intercept;
    GeographicCoordinate!T _nearestPoint;
    T _nearestDistance;
    T _alongTrackDistance;
    T _signedCrossTrackDistance;
    T _segmentAlongTrackDistance;
    T _segmentLength;
    GeodesicSegmentNearestLocation _location;

    static GeodesicSegmentNearestResult fromComponents(
        const GeographicCoordinate!T intercept,
        const GeographicCoordinate!T nearestPoint,
        const T nearestDistance,
        const T alongTrackDistance,
        const T signedCrossTrackDistance,
        const T segmentAlongTrackDistance,
        const T segmentLength,
        const GeodesicSegmentNearestLocation location)
        pure nothrow @safe @nogc
    {
        GeodesicSegmentNearestResult result;
        result._valid = true;
        result._intercept = intercept;
        result._nearestPoint = nearestPoint;
        result._nearestDistance = nearestDistance;
        result._alongTrackDistance = alongTrackDistance;
        result._signedCrossTrackDistance = signedCrossTrackDistance;
        result._segmentAlongTrackDistance = segmentAlongTrackDistance;
        result._segmentLength = segmentLength;
        result._location = location;
        return result;
    }

public:
    /** True when this value is a successfully computed result. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _valid;
    }

    /// Example checking the invalid default result.
    @safe unittest
    {
        assert(!GeodesicSegmentNearestResult!double.init.isValid);
    }

    /** Local perpendicular foot on the oriented supporting geodesic. */
    @property GeographicCoordinate!T intercept() const
        pure nothrow @safe @nogc
    {
        return _intercept;
    }

    /// Example reading the intercept carrier.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.intercept.latitude.radians == 0.0);
    }

    /** Actual nearest point on the bounded segment after endpoint clamping. */
    @property GeographicCoordinate!T nearestPoint() const
        pure nothrow @safe @nogc
    {
        return _nearestPoint;
    }

    /// Example reading the bounded nearest-point carrier.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.nearestPoint.longitude.radians == 0.0);
    }

    /** Unsigned target-to-nearest-point geodesic distance. */
    @property T nearestDistance() const pure nothrow @safe @nogc
    {
        return _nearestDistance;
    }

    /// Example reading the nearest distance.
    @safe unittest
    {
        assert(GeodesicSegmentNearestResult!double.init.nearestDistance == 0.0);
    }

    /** Signed distance from A to the supporting-geodesic intercept. */
    @property T alongTrackDistance() const pure nothrow @safe @nogc
    {
        return _alongTrackDistance;
    }

    /// Example reading signed along-track distance.
    @safe unittest
    {
        assert(GeodesicSegmentNearestResult!double.init.alongTrackDistance == 0.0);
    }

    /** Signed supporting-geodesic offset; right positive and left negative. */
    @property T signedCrossTrackDistance() const pure nothrow @safe @nogc
    {
        return _signedCrossTrackDistance;
    }

    /// Example reading signed cross-track distance.
    @safe unittest
    {
        assert(
            GeodesicSegmentNearestResult!double.init.signedCrossTrackDistance
                == 0.0);
    }

    /** Along-segment distance after clamping to the segment endpoints. */
    @property T segmentAlongTrackDistance() const pure nothrow @safe @nogc
    {
        return _segmentAlongTrackDistance;
    }

    /// Example reading clamped along-track distance.
    @safe unittest
    {
        assert(
            GeodesicSegmentNearestResult!double.init.segmentAlongTrackDistance
                == 0.0);
    }

    /** Total shortest-geodesic segment length from A to B. */
    @property T segmentLength() const pure nothrow @safe @nogc
    {
        return _segmentLength;
    }

    /// Example reading the segment length carrier.
    @safe unittest
    {
        assert(GeodesicSegmentNearestResult!double.init.segmentLength == 0.0);
    }

    /** Whether the bounded nearest point is A, interior, or B. */
    @property GeodesicSegmentNearestLocation location() const
        pure nothrow @safe @nogc
    {
        return _location;
    }

    /// Example reading the default invalid location.
    @safe unittest
    {
        assert(
            GeodesicSegmentNearestResult!double.init.location
                == GeodesicSegmentNearestLocation.invalid);
    }
}

/// Example naming the public nearest-point result family.
@safe unittest
{
    static assert(is(GeodesicSegmentNearestResult!float));
    static assert(is(GeodesicSegmentNearestResult!double));
    static assert(is(GeodesicSegmentNearestResult!real));
}

private bool gnomonicForward(T, W)(
    const Geodesic!T solver,
    const GeographicCoordinate!T center,
    const GeographicCoordinate!T point,
    out GnomonicPoint!W result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T && isGeodesyScalar!W)
{
    result = GnomonicPoint!W.init;

    GeodesicInverseResult!T inverse;
    GeodesicQuantities!T quantities;

    if (!solver.tryInverse(center, point, inverse, quantities))
        return false;

    const W scale = cast(W) quantities.scale12;

    if (!isFiniteGeodesyScalar(scale)
        || scale <= cast(W) 0)
        return false;

    const W rho =
        cast(W) quantities.reducedLength / scale;

    const W azimuth =
        cast(W) inverse.initialAzimuth.radians;

    const W x = rho * sin(azimuth);
    const W y = rho * cos(azimuth);

    if (!isFiniteGeodesyScalar(x)
        || !isFiniteGeodesyScalar(y))
        return false;

    result.x = x;
    result.y = y;
    return true;
}

private bool gnomonicReverse(T, W)(
    const Geodesic!T solver,
    const GeographicCoordinate!T center,
    const GnomonicPoint!W projected,
    out GeographicCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T && isGeodesyScalar!W)
{
    result = GeographicCoordinate!T.init;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    W rho =
        hypot(projected.x, projected.y);

    if (!isFiniteGeodesyScalar(a)
        || a <= cast(W) 0
        || !isFiniteGeodesyScalar(rho))
        return false;

    const bool little = rho <= a;

    W s = a * atan(rho / a);

    if (!little)
    {
        if (rho == cast(W) 0)
            return false;
        rho = cast(W) 1 / rho;
    }

    Angle!T azimuth;

    if (!Angle!T.tryFromRadians(
            cast(T) atan2(projected.x, projected.y),
            azimuth))
        return false;

    GeodesicLine!T line;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            center,
            azimuth,
            line))
        return false;

    enum size_t maxIterations = 20;

    const W tolerance =
        cast(W) 0.01 * sqrt(W.epsilon) * a;

    foreach (_; 0 .. maxIterations)
    {
        const T publicDistance = cast(T) s;

        if (!isFiniteGeodesyScalar(publicDistance))
            return false;

        GeodesicDirectResult!T position;
        GeodesicQuantities!T quantities;

        if (!line.tryPosition(
                publicDistance,
                position,
                quantities))
            return false;

        const W m =
            cast(W) quantities.reducedLength;

        const W scale =
            cast(W) quantities.scale12;

        if (!isFiniteGeodesyScalar(m)
            || !isFiniteGeodesyScalar(scale))
            return false;

        const W ds =
            little
                ? (m - rho * scale) * scale
                : (rho * m - scale) * m;

        if (!isFiniteGeodesyScalar(ds))
            return false;

        s -= ds;

        if (abs(ds) < tolerance)
        {
            const T finalDistance = cast(T) s;

            if (!isFiniteGeodesyScalar(finalDistance))
                return false;

            GeodesicDirectResult!T finalPosition;

            if (!line.tryPosition(finalDistance, finalPosition))
                return false;

            result = finalPosition.position;
            return true;
        }
    }

    return false;
}

private bool interceptionStep(T, W, bool firstStep)(
    const Geodesic!T solver,
    const GeographicCoordinate!T center,
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    const GeographicCoordinate!T target,
    out GeographicCoordinate!T nextCenter)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T && isGeodesyScalar!W)
{
    nextCenter = GeographicCoordinate!T.init;

    GnomonicPoint!W projectedStart;
    GnomonicPoint!W projectedEnd;
    GnomonicPoint!W projectedTarget;

    if (!gnomonicForward!(T, W)(
            solver, center, start, projectedStart))
        return false;

    if (!gnomonicForward!(T, W)(
            solver, center, end, projectedEnd))
        return false;

    static if (firstStep)
    {
        projectedTarget = GnomonicPoint!W.init;
    }
    else
    {
        if (!gnomonicForward!(T, W)(
                solver, center, target, projectedTarget))
            return false;
    }

    const W dx = projectedEnd.x - projectedStart.x;
    const W dy = projectedEnd.y - projectedStart.y;
    const W denominator = dx * dx + dy * dy;

    if (!isFiniteGeodesyScalar(denominator)
        || denominator <= cast(W) 0)
        return false;

    const W dot =
        projectedTarget.x * dx
        + projectedTarget.y * dy;

    const W cross =
        projectedStart.x * projectedEnd.y
        - projectedStart.y * projectedEnd.x;

    GnomonicPoint!W projectedFoot;

    projectedFoot.x =
        (dot * dx + cross * dy) / denominator;

    projectedFoot.y =
        (dot * dy - cross * dx) / denominator;

    return gnomonicReverse!(T, W)(
        solver,
        center,
        projectedFoot,
        nextCenter);
}

private bool supportingIntercept(T, W)(
    const Geodesic!T solver,
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    const GeographicCoordinate!T target,
    out GeographicCoordinate!T intercept)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T && isGeodesyScalar!W)
{
    intercept = GeographicCoordinate!T.init;

    GeographicCoordinate!T firstCenter;

    if (!interceptionStep!(T, W, true)(
            solver,
            target,
            start,
            end,
            target,
            firstCenter))
        return false;

    GeographicCoordinate!T secondCenter;

    if (!interceptionStep!(T, W, false)(
            solver,
            firstCenter,
            start,
            end,
            target,
            secondCenter))
        return false;

    intercept = secondCenter;
    return true;
}

/**
 * Find the nearest point from a target to a bounded ellipsoidal geodesic
 * segment without throwing.
 *
 * start and end define the shortest geodesic segment A -> B. Degenerate
 * A == B input is rejected because the oriented supporting geodesic is
 * undefined. Exact target equality with A or B is handled deterministically.
 *
 * Returns true when a finite local intercept and bounded nearest-point result
 * are produced; otherwise false. result is reset to .init on entry.
 */
bool tryNearestPointOnSegment(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    const GeographicCoordinate!T target,
    out GeodesicSegmentNearestResult!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = NearestWorkingScalar!T;

    result = GeodesicSegmentNearestResult!T.init;

    if (!solver.isValid)
        return false;

    GeodesicInverseResult!T segment;

    if (!solver.tryInverse(start, end, segment)
        || segment.distance <= cast(T) 0)
        return false;

    GeodesicInverseResult!T startTarget;

    if (!solver.tryInverse(start, target, startTarget))
        return false;

    if (startTarget.distance == cast(T) 0)
    {
        result =
            GeodesicSegmentNearestResult!T.fromComponents(
                start,
                start,
                cast(T) 0,
                cast(T) 0,
                cast(T) 0,
                cast(T) 0,
                segment.distance,
                GeodesicSegmentNearestLocation.start);
        return true;
    }

    GeodesicInverseResult!T endTarget;

    if (!solver.tryInverse(end, target, endTarget))
        return false;

    if (endTarget.distance == cast(T) 0)
    {
        result =
            GeodesicSegmentNearestResult!T.fromComponents(
                end,
                end,
                cast(T) 0,
                segment.distance,
                cast(T) 0,
                segment.distance,
                segment.distance,
                GeodesicSegmentNearestLocation.end);
        return true;
    }

    GeographicCoordinate!T intercept;

    if (!supportingIntercept!(T, W)(
            solver,
            start,
            end,
            target,
            intercept))
        return false;

    GeodesicInverseResult!T startIntercept;

    if (!solver.tryInverse(
            start,
            intercept,
            startIntercept))
        return false;

    const W azimuthDelta =
        wrapPi!W(
            cast(W) startIntercept.initialAzimuth.radians
            - cast(W) segment.initialAzimuth.radians);

    const W signedAlong =
        cos(azimuthDelta) >= cast(W) 0
            ? cast(W) startIntercept.distance
            : -cast(W) startIntercept.distance;

    const T alongTrackDistance = cast(T) signedAlong;

    if (!isFiniteGeodesyScalar(alongTrackDistance))
        return false;

    GeodesicLine!T line;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            start,
            segment.initialAzimuth,
            line))
        return false;

    GeodesicDirectResult!T tangentPosition;

    if (!line.tryPosition(
            alongTrackDistance,
            tangentPosition))
        return false;

    GeodesicInverseResult!T interceptTarget;

    if (!solver.tryInverse(
            intercept,
            target,
            interceptTarget))
        return false;

    T signedCrossTrackDistance = cast(T) 0;

    if (interceptTarget.distance != cast(T) 0)
    {
        const W targetDelta =
            wrapPi!W(
                cast(W) interceptTarget.initialAzimuth.radians
                - cast(W) tangentPosition.finalAzimuth.radians);

        const W side = sin(targetDelta);

        if (side > cast(W) 0)
            signedCrossTrackDistance = interceptTarget.distance;
        else if (side < cast(W) 0)
            signedCrossTrackDistance = -interceptTarget.distance;
    }

    GeographicCoordinate!T nearestPoint = intercept;
    T segmentAlongTrackDistance = alongTrackDistance;
    GeodesicSegmentNearestLocation location =
        GeodesicSegmentNearestLocation.interior;

    if (alongTrackDistance <= cast(T) 0)
    {
        nearestPoint = start;
        segmentAlongTrackDistance = cast(T) 0;
        location = GeodesicSegmentNearestLocation.start;
    }
    else if (alongTrackDistance >= segment.distance)
    {
        nearestPoint = end;
        segmentAlongTrackDistance = segment.distance;
        location = GeodesicSegmentNearestLocation.end;
    }

    GeodesicInverseResult!T nearestTarget;

    if (!solver.tryInverse(
            nearestPoint,
            target,
            nearestTarget))
        return false;

    if (!isFiniteGeodesyScalar(nearestTarget.distance)
        || nearestTarget.distance < cast(T) 0
        || !isFiniteGeodesyScalar(signedCrossTrackDistance)
        || !isFiniteGeodesyScalar(segmentAlongTrackDistance))
        return false;

    result =
        GeodesicSegmentNearestResult!T.fromComponents(
            intercept,
            nearestPoint,
            nearestTarget.distance,
            alongTrackDistance,
            signedCrossTrackDistance,
            segmentAlongTrackDistance,
            segment.distance,
            location);

    return true;
}

/// Example finding an interior nearest point without throwing.
@safe unittest
{
    import geodesy;

    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257223563));

    const start =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(10.0));

    const end =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(20.0));

    const target =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(49.2),
            Longitude!double.fromDegrees(15.0));

    GeographicCoordinate!double diagnosticIntercept;
    assert(
        supportingIntercept!(double, double)(
            solver,
            start,
            end,
            target,
            diagnosticIntercept));

    GeodesicSegmentNearestResult!double result;

    assert(
        solver.tryNearestPointOnSegment(
            start,
            end,
            target,
            result));

    assert(
        result.location
            == GeodesicSegmentNearestLocation.interior);
    assert(result.nearestDistance > 0.0);
}

/**
 * Find the nearest point from a target to a bounded ellipsoidal geodesic
 * segment.
 *
 * This is the throwing companion to tryNearestPointOnSegment.
 *
 * Throws:
 *     GeodesyValueException for an invalid solver, a degenerate segment, an
 *     unsupported local interception geometry, non-convergence, or a
 *     non-finite/unrepresentable result.
 */
GeodesicSegmentNearestResult!T nearestPointOnSegment(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    const GeographicCoordinate!T target)
    @safe
if (isGeodesyScalar!T)
{
    GeodesicSegmentNearestResult!T result;

    if (!tryNearestPointOnSegment(
            solver,
            start,
            end,
            target,
            result))
    {
        throw new GeodesyValueException(
            "Nearest point on geodesic segment requires a valid non-degenerate "
            ~ "segment and a convergent local ellipsoidal interception.");
    }

    return result;
}

/// Example finding an endpoint-clamped nearest point.
@safe unittest
{
    import geodesy;

    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257223563));

    const start =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(10.0));

    const end =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(12.0));

    const target =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.4),
            Longitude!double.fromDegrees(8.0));

    const result =
        solver.nearestPointOnSegment(
            start,
            end,
            target);

    assert(
        result.location
            == GeodesicSegmentNearestLocation.start);
    assert(result.nearestDistance > 0.0);
}
