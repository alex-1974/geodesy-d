/**
 * Ellipsoidal nearest-point geometry for bounded geodesic segments.
 *
 * The accepted M5 #47 surface returns the nearest point on the finite shortest
 * geodesic segment A->B together with its distance from a target point.
 *
 * Supporting-line quantities are also returned explicitly:
 *
 * - `alongTrack` is signed from A in the A->B orientation;
 * - `signedCrossTrack` is positive to the right of the oriented supporting
 *   geodesic and negative to the left;
 * - `supportingFoot` is the local perpendicular intercept on that supporting
 *   geodesic.
 *
 * When the nearest bounded-segment point is an endpoint, `nearestDistance`
 * is the true endpoint distance while `signedCrossTrack` continues to refer
 * only to the supporting geodesic. The two quantities are intentionally not
 * conflated.
 *
 * The ellipsoidal kernel follows Karney's gnomonic interception construction
 * using `m12` and `M12` from the existing geodesic family. No spherical
 * cross-track shortcut is used.
 *
 * Very distant / antipodal configurations for which the local ellipsoidal
 * gnomonic construction is not defined or does not converge fail through the
 * checked API instead of claiming a globally unique infinite-line intercept.
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

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid :
    Ellipsoid;
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
    cos,
    hypot,
    sin,
    sqrt;


/**
 * Location of the nearest point on a bounded oriented geodesic segment.
 *
 * `invalid` is reserved for `.init` and checked-operation failure.
 */
enum GeodesicSegmentNearestKind
{
    invalid,
    start,
    interior,
    end
}

/// Example classifying a nearest segment point.
@safe unittest
{
    assert(GeodesicSegmentNearestKind.start
        != GeodesicSegmentNearestKind.end);
}


/**
 * Result of nearest-point evaluation on a bounded geodesic segment.
 *
 * `nearestPoint` and `nearestDistance` belong to the finite segment.
 * `supportingFoot`, `alongTrack`, and `signedCrossTrack` belong to the
 * local oriented supporting geodesic through A->B.
 *
 * `.init` is invalid.
 */
struct GeodesicSegmentNearestResult(T)
if (isGeodesyScalar!T)
{
private:
    GeographicCoordinate!T _nearestPoint;
    T _nearestDistance = T.init;
    GeodesicSegmentNearestKind _kind =
        GeodesicSegmentNearestKind.invalid;
    GeographicCoordinate!T _supportingFoot;
    T _alongTrack = T.init;
    T _signedCrossTrack = T.init;

    /** Construct a result from already validated nearest-point components. */
    static GeodesicSegmentNearestResult fromComponents(
        const GeographicCoordinate!T nearestPoint,
        const T nearestDistance,
        const GeodesicSegmentNearestKind kind,
        const GeographicCoordinate!T supportingFoot,
        const T alongTrack,
        const T signedCrossTrack)
        pure nothrow @safe @nogc
    {
        GeodesicSegmentNearestResult result;
        result._nearestPoint = nearestPoint;
        result._nearestDistance = nearestDistance;
        result._kind = kind;
        result._supportingFoot = supportingFoot;
        result._alongTrack = alongTrack;
        result._signedCrossTrack = signedCrossTrack;
        return result;
    }

public:
    /** True for a successfully computed nearest-point result. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _kind != GeodesicSegmentNearestKind.invalid
            && isFiniteGeodesyScalar(_nearestDistance)
            && _nearestDistance >= cast(T) 0
            && isFiniteGeodesyScalar(_alongTrack)
            && isFiniteGeodesyScalar(_signedCrossTrack);
    }

    /// Example checking the default invalid state.
    @safe unittest
    {
        assert(!GeodesicSegmentNearestResult!double.init.isValid);
    }

    /** True nearest point on the bounded segment. */
    @property GeographicCoordinate!T nearestPoint() const
        pure nothrow @safe @nogc
    {
        return _nearestPoint;
    }

    /// Example reading the nearest bounded-segment point.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(!result.isValid);
        cast(void) result.nearestPoint;
    }

    /** Unsigned distance from target to `nearestPoint`. */
    @property T nearestDistance() const
        pure nothrow @safe @nogc
    {
        return _nearestDistance;
    }

    /// Example reading the nearest distance.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.nearestDistance != result.nearestDistance);
    }

    /** Whether the bounded nearest point is A, interior, or B. */
    @property GeodesicSegmentNearestKind kind() const
        pure nothrow @safe @nogc
    {
        return _kind;
    }

    /// Example reading the nearest-point classification.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.kind == GeodesicSegmentNearestKind.invalid);
    }

    /**
     * Local perpendicular intercept on the oriented supporting geodesic.
     */
    @property GeographicCoordinate!T supportingFoot() const
        pure nothrow @safe @nogc
    {
        return _supportingFoot;
    }

    /// Example reading the supporting-geodesic intercept.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        cast(void) result.supportingFoot;
    }

    /**
     * Signed distance from A to `supportingFoot` along the A->B geodesic.
     *
     * Positive is forward from A toward B; negative is behind A.
     */
    @property T alongTrack() const
        pure nothrow @safe @nogc
    {
        return _alongTrack;
    }

    /// Example reading signed along-track distance.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.alongTrack != result.alongTrack);
    }

    /**
     * Signed perpendicular distance from the supporting geodesic to target.
     *
     * Positive is right of the oriented A->B track; negative is left.
     * This remains a supporting-line quantity when the bounded nearest point
     * is clamped to an endpoint.
     */
    @property T signedCrossTrack() const
        pure nothrow @safe @nogc
    {
        return _signedCrossTrack;
    }

    /// Example reading signed cross-track distance.
    @safe unittest
    {
        GeodesicSegmentNearestResult!double result;
        assert(result.signedCrossTrack != result.signedCrossTrack);
    }
}

/// Example using the nearest-result type.
@safe unittest
{
    GeodesicSegmentNearestResult!double result;
    assert(!result.isValid);
}


private template NearestWorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias NearestWorkingScalar = double;
    else
        alias NearestWorkingScalar = T;
}


private struct GnomonicXY(W)
{
    W x;
    W y;
}


/** Normalize a working angle to [-pi,+pi). */
private W wrapPi(W)(W value)
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


/**
 * Project one geographic point into Karney's local ellipsoidal gnomonic plane.
 */
private bool gnomonicForward(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T center,
    const GeographicCoordinate!T point,
    out GnomonicXY!(NearestWorkingScalar!T) xy)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = NearestWorkingScalar!T;
    xy = GnomonicXY!W.init;

    GeodesicInverseResult!T inverse;
    GeodesicQuantities!T quantities;

    if (!solver.tryInverse(
            center,
            point,
            inverse,
            quantities))
        return false;

    const W scale =
        cast(W) quantities.scale12;

    if (!isFiniteGeodesyScalar(scale)
        || !(scale > cast(W) 0))
        return false;

    const W rho =
        cast(W) quantities.reducedLength
        / scale;

    const W azimuth =
        cast(W) inverse.initialAzimuth.radians;

    xy.x = rho * sin(azimuth);
    xy.y = rho * cos(azimuth);

    return isFiniteGeodesyScalar(xy.x)
        && isFiniteGeodesyScalar(xy.y);
}


/**
 * Reverse Karney's local ellipsoidal gnomonic projection by Newton iteration.
 */
private bool gnomonicReverse(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T center,
    const GnomonicXY!(NearestWorkingScalar!T) xy,
    out GeographicCoordinate!T point)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = NearestWorkingScalar!T;

    point = GeographicCoordinate!T.init;

    const W a =
        cast(W) solver.ellipsoid.semiMajorAxis;

    if (!isFiniteGeodesyScalar(a)
        || !(a > cast(W) 0))
        return false;

    W rho =
        hypot(xy.x, xy.y);

    if (!isFiniteGeodesyScalar(rho))
        return false;

    const bool little =
        rho <= a;

    W distance =
        a * atan(rho / a);

    if (!little)
    {
        if (rho == cast(W) 0)
            return false;
        rho = cast(W) 1 / rho;
    }

    Angle!T azimuth;
    if (!Angle!T.tryFromRadians(
            cast(T) atan2(xy.x, xy.y),
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
        cast(W) 0.01
        * sqrt(W.epsilon)
        * a;

    foreach (_; 0 .. maxIterations)
    {
        GeodesicDirectResult!T position;
        GeodesicQuantities!T quantities;

        if (!line.tryPosition(
                cast(T) distance,
                position,
                quantities))
            return false;

        const W reducedLength =
            cast(W) quantities.reducedLength;

        const W scale =
            cast(W) quantities.scale12;

        const W delta =
            little
                ? (reducedLength - rho * scale) * scale
                : (rho * reducedLength - scale) * reducedLength;

        if (!isFiniteGeodesyScalar(delta))
            return false;

        distance -= delta;

        if (!isFiniteGeodesyScalar(distance))
            return false;

        if (abs(delta) < tolerance)
        {
            GeodesicDirectResult!T finalPosition;

            if (!line.tryPosition(
                    cast(T) distance,
                    finalPosition))
                return false;

            point = finalPosition.position;
            return true;
        }
    }

    return false;
}


/**
 * Solve the local perpendicular intercept on the oriented supporting geodesic.
 */
private bool localSupportingIntercept(T)(
    const Geodesic!T solver,
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    const GeographicCoordinate!T target,
    const GeodesicInverseResult!T segment,
    out GeographicCoordinate!T foot,
    out T alongTrack,
    out T signedCrossTrack)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    alias W = NearestWorkingScalar!T;

    foot = GeographicCoordinate!T.init;
    alongTrack = T.init;
    signedCrossTrack = T.init;

    GeographicCoordinate!T center =
        target;

    foreach (iteration; 0 .. 2)
    {
        GnomonicXY!W projectedStart;
        GnomonicXY!W projectedEnd;
        GnomonicXY!W projectedTarget;

        if (!gnomonicForward!T(
                solver,
                center,
                start,
                projectedStart)
            || !gnomonicForward!T(
                solver,
                center,
                end,
                projectedEnd))
            return false;

        if (iteration == 0)
        {
            projectedTarget =
                GnomonicXY!W(
                    cast(W) 0,
                    cast(W) 0);
        }
        else if (!gnomonicForward!T(
                solver,
                center,
                target,
                projectedTarget))
            return false;

        const W dx =
            projectedEnd.x - projectedStart.x;

        const W dy =
            projectedEnd.y - projectedStart.y;

        const W denominator =
            dx * dx + dy * dy;

        if (!isFiniteGeodesyScalar(denominator)
            || !(denominator > cast(W) 0))
            return false;

        const W dot =
            projectedTarget.x * dx
            + projectedTarget.y * dy;

        const W cross =
            projectedStart.x * projectedEnd.y
            - projectedStart.y * projectedEnd.x;

        const GnomonicXY!W projectedFoot =
            GnomonicXY!W(
                (dot * dx + cross * dy)
                    / denominator,
                (dot * dy - cross * dx)
                    / denominator);

        GeographicCoordinate!T nextCenter;

        if (!gnomonicReverse!T(
                solver,
                center,
                projectedFoot,
                nextCenter))
            return false;

        center =
            nextCenter;
    }

    GeodesicInverseResult!T startToFoot;

    if (!solver.tryInverse(
            start,
            center,
            startToFoot))
        return false;

    const W azimuthDelta =
        wrapPi(
            cast(W) startToFoot.initialAzimuth.radians
            - cast(W) segment.initialAzimuth.radians);

    const W signedAlong =
        cos(azimuthDelta) >= cast(W) 0
            ? cast(W) startToFoot.distance
            : -cast(W) startToFoot.distance;

    GeodesicLine!T line;

    if (!GeodesicLine!T.tryFromGeodesic(
            solver,
            start,
            segment.initialAzimuth,
            line))
        return false;

    GeodesicDirectResult!T lineAtFoot;

    if (!line.tryPosition(
            cast(T) signedAlong,
            lineAtFoot))
        return false;

    GeodesicInverseResult!T footToTarget;

    if (!solver.tryInverse(
            center,
            target,
            footToTarget))
        return false;

    W signedCross =
        cast(W) 0;

    if (footToTarget.distance != cast(T) 0)
    {
        const W sideDelta =
            wrapPi(
                cast(W) footToTarget.initialAzimuth.radians
                - cast(W) lineAtFoot.finalAzimuth.radians);

        const W side =
            sin(sideDelta);

        signedCross =
            side > cast(W) 0
                ? cast(W) footToTarget.distance
                : side < cast(W) 0
                    ? -cast(W) footToTarget.distance
                    : cast(W) 0;
    }

    const T publicAlong =
        cast(T) signedAlong;

    const T publicCross =
        cast(T) signedCross;

    if (!isFiniteGeodesyScalar(publicAlong)
        || !isFiniteGeodesyScalar(publicCross))
        return false;

    foot =
        center;

    alongTrack =
        publicAlong;

    signedCrossTrack =
        publicCross;

    return true;
}


/**
 * Find the nearest point on a bounded oriented ellipsoidal geodesic segment.
 *
 * A and B define the shortest geodesic segment and its orientation. The
 * operation first solves a local perpendicular intercept on the supporting
 * geodesic using Karney's ellipsoidal gnomonic construction, then clamps the
 * bounded nearest point to A or B when the intercept lies outside the segment.
 *
 * The returned `signedCrossTrack` is positive to the right of the oriented
 * A->B supporting geodesic and negative to the left. `alongTrack` is signed
 * from A in the A->B direction.
 *
 * A coincident A/B pair is rejected because its orientation, along-track
 * direction, and cross-track sign are undefined.
 *
 * Very distant configurations for which the local gnomonic construction is
 * over its horizon or fails to converge return `false`.
 *
 * Params:
 *     solver = Valid prepared geodesic solver.
 *     start = Segment start A.
 *     end = Segment end B.
 *     target = Geographic point whose nearest segment point is requested.
 *     result = Receives bounded nearest-point and supporting-line quantities.
 *
 * Returns:
 *     `true` on a finite converged solution; otherwise `false`. Failure
 *     resets `result` to `.init`.
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
    result =
        GeodesicSegmentNearestResult!T.init;

    if (!solver.isValid)
        return false;

    GeodesicInverseResult!T segment;

    if (!solver.tryInverse(
            start,
            end,
            segment))
        return false;

    if (segment.distance == cast(T) 0)
        return false;

    /*
     * GeographicCoordinate is a canonical value type. Exact endpoint
     * coincidence therefore needs no inverse-geodesic solve.
     */
    if (target == start)
    {
        result =
            GeodesicSegmentNearestResult!T.fromComponents(
                start,
                cast(T) 0,
                GeodesicSegmentNearestKind.start,
                start,
                cast(T) 0,
                cast(T) 0);

        return true;
    }

    if (target == end)
    {
        result =
            GeodesicSegmentNearestResult!T.fromComponents(
                end,
                cast(T) 0,
                GeodesicSegmentNearestKind.end,
                end,
                segment.distance,
                cast(T) 0);

        return true;
    }

    GeographicCoordinate!T supportingFoot;
    T alongTrack;
    T signedCrossTrack;

    if (!localSupportingIntercept(
            solver,
            start,
            end,
            target,
            segment,
            supportingFoot,
            alongTrack,
            signedCrossTrack))
        return false;

    GeographicCoordinate!T nearestPoint =
        supportingFoot;

    GeodesicSegmentNearestKind kind =
        GeodesicSegmentNearestKind.interior;

    if (alongTrack <= cast(T) 0)
    {
        nearestPoint =
            start;

        kind =
            GeodesicSegmentNearestKind.start;
    }
    else if (alongTrack >= segment.distance)
    {
        nearestPoint =
            end;

        kind =
            GeodesicSegmentNearestKind.end;
    }

    GeodesicInverseResult!T nearestInverse;

    if (!solver.tryInverse(
            nearestPoint,
            target,
            nearestInverse))
        return false;

    const T nearestDistance =
        nearestInverse.distance;

    if (!isFiniteGeodesyScalar(nearestDistance)
        || nearestDistance < cast(T) 0)
        return false;

    result =
        GeodesicSegmentNearestResult!T.fromComponents(
            nearestPoint,
            nearestDistance,
            kind,
            supportingFoot,
            alongTrack,
            signedCrossTrack);

    return result.isValid;
}

/// Example finding an interior nearest point without throwing.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257223563));

    const a =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(-20.0));

    const b =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(20.0));

    const target =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-2.0),
            Longitude!double.fromDegrees(3.0));

    GeodesicSegmentNearestResult!double result;

    assert(tryNearestPointOnSegment(
        solver,
        a,
        b,
        target,
        result));

    assert(result.isValid);
    assert(result.kind == GeodesicSegmentNearestKind.interior);
    assert(result.signedCrossTrack > 0.0);
}


/**
 * Find the nearest point on a bounded oriented ellipsoidal geodesic segment.
 *
 * This is the throwing counterpart of `tryNearestPointOnSegment`.
 *
 * Throws:
 *     `GeodesyValueException` when the solver/segment is invalid or the local
 *     ellipsoidal interception does not produce a finite converged result.
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
            "Nearest geodesic-segment point requires a valid non-degenerate "
            ~ "segment and a finite converged ellipsoidal interception.");
    }

    return result;
}

/// Example finding the nearest bounded-segment point with throwing semantics.
@safe unittest
{
    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257223563));

    const a =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(10.0));

    const b =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(12.0));

    const target =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.4),
            Longitude!double.fromDegrees(8.0));

    const result =
        nearestPointOnSegment(
            solver,
            a,
            b,
            target);

    assert(result.kind == GeodesicSegmentNearestKind.start);
}
