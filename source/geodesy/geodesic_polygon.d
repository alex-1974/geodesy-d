/**
 * Streaming ellipsoidal polygon perimeter and signed-area accumulation.
 *
 * This module provides mathematical measurement only. It does not define
 * polygon geometry ownership, ring validity, hole semantics, containment,
 * overlay, or topology; those responsibilities belong to geometry layers such
 * as geo-d or to consumers.
 *
 * Polygon edges are shortest geodesics between consecutive geographic
 * vertices. The closing edge from the last vertex back to the first is
 * included when results are computed. Signed area is positive for
 * counterclockwise traversal and canonicalized to (-A/2, A/2], where A is the
 * full ellipsoid surface area. Self-intersections are accumulated
 * algebraically.
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
 *     October 5, 2026
 */
module geodesy.geodesic_polygon;

import std.math :
    PI;

import geodesy.ellipsoid :
    Ellipsoid;

import geodesy.errors :
    GeodesyValueException;

import geodesy.geodesic :
    Geodesic,
    GeodesicInverseResult,
    GeodesicQuantities;

import geodesy.geographic :
    GeographicCoordinate;

import geodesy.internal.geodesic_area :
    geodesicAuthalicRadiusSquared;

import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;


/** Working scalar for accumulation; float promotes to double. */
private template PolygonWorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias PolygonWorkingScalar = double;
    else
        alias PolygonWorkingScalar = T;
}


/** Small compensated streaming sum for perimeter and area terms. */
private struct CompensatedSum(W)
{
    W _sum;
    W _correction;

    void add(const W value)
        pure nothrow @safe @nogc
    {
        const W next =
            _sum + value;

        const W virtualValue =
            next - _sum;

        const W error =
            (_sum - (next - virtualValue))
            + (value - virtualValue);

        _sum = next;
        _correction += error;
    }

    @property W value() const
        pure nothrow @safe @nogc
    {
        return _sum + _correction;
    }
}


/** Canonicalize a finite angle to [-pi,+pi). */
private W canonicalAngle(W)(const W value)
    pure nothrow @safe @nogc
{
    const W piValue = cast(W) PI;
    const W period = cast(W) 2 * piValue;

    W result = value % period;

    if (result >= piValue)
        result -= period;
    else if (result < -piValue)
        result += period;

    return result == cast(W) 0
        ? cast(W) 0
        : result;
}


/**
 * Count a prime-meridian transit for one shortest-geodesic edge.
 *
 * This is the radian form of the parity rule used by GeographicLib's polygon
 * area reduction. Only parity matters to final area normalization.
 */
private int primeMeridianTransit(W)(
    const W longitude1,
    const W longitude2)
    pure nothrow @safe @nogc
{
    const W lon1 =
        canonicalAngle(longitude1);

    const W lon2 =
        canonicalAngle(longitude2);

    const W delta =
        canonicalAngle(lon2 - lon1);

    if (
        delta > cast(W) 0
        && (
            (lon1 < cast(W) 0 && lon2 >= cast(W) 0)
            || (lon1 > cast(W) 0 && lon2 == cast(W) 0)
        )
    )
        return 1;

    if (
        delta < cast(W) 0
        && lon1 >= cast(W) 0
        && lon2 < cast(W) 0
    )
        return -1;

    return 0;
}


/**
 * Normalize accumulated edge area to canonical signed polygon area.
 *
 * Edge S12 sums use the clockwise sense. Public polygon area uses the more
 * conventional counterclockwise-positive sense.
 */
private W canonicalPolygonArea(W)(
    W area,
    const long crossings,
    const W ellipsoidArea)
    pure nothrow @safe @nogc
{
    const W half =
        ellipsoidArea / cast(W) 2;

    area %= ellipsoidArea;

    if (area > half)
        area -= ellipsoidArea;
    else if (area <= -half)
        area += ellipsoidArea;

    if ((crossings & 1L) != 0)
        area +=
            area < cast(W) 0
                ? half
                : -half;

    area = -area;

    if (area > half)
        area -= ellipsoidArea;
    else if (area <= -half)
        area += ellipsoidArea;

    return area == cast(W) 0
        ? cast(W) 0
        : area;
}


/**
 * Result of computing a closed geodesic polygon.
 */
struct GeodesicPolygonResult(T)
if (isGeodesyScalar!T)
{
private:
    size_t _pointCount;
    T _perimeter;
    T _signedArea;

    static GeodesicPolygonResult fromComponents(
        const size_t pointCount,
        const T perimeter,
        const T signedArea)
        pure nothrow @safe @nogc
    {
        GeodesicPolygonResult result;
        result._pointCount = pointCount;
        result._perimeter = perimeter;
        result._signedArea = signedArea;
        return result;
    }

public:
    /** Number of vertices supplied to the accumulator. */
    @property size_t pointCount() const
        pure nothrow @safe @nogc
    {
        return _pointCount;
    }

    /// Example reading the result point count.
    @safe unittest
    {
        GeodesicPolygonResult!double result;
        assert(result.pointCount == 0);
    }

    /** Closed geodesic perimeter in the ellipsoid linear unit. */
    @property T perimeter() const
        pure nothrow @safe @nogc
    {
        return _perimeter;
    }

    /// Example reading the closed polygon perimeter.
    @safe unittest
    {
        GeodesicPolygonResult!double result;
        assert(result.perimeter == 0.0);
    }

    /**
     * Canonical signed area in square ellipsoid units.
     *
     * Positive area denotes counterclockwise traversal. The result lies in
     * (-A/2, A/2], where A is the complete ellipsoid surface area.
     */
    @property T signedArea() const
        pure nothrow @safe @nogc
    {
        return _signedArea;
    }

    /// Example reading the canonical signed polygon area.
    @safe unittest
    {
        GeodesicPolygonResult!double result;
        assert(result.signedArea == 0.0);
    }
}


/**
 * Streaming accumulator for one closed ellipsoidal geodesic polygon.
 *
 * Vertices are retained only as the first and most recent points; no dynamic
 * vertex storage is used. Every vertex after the first contributes the
 * shortest inverse-geodesic edge from the previous point. Calling
 * `tryCompute` / `compute` is non-mutating and adds the closing edge from
 * the current point back to the first point.
 *
 * `.init` is invalid. Prepare from a valid `Geodesic!T`.
 */
struct GeodesicPolygonAccumulator(T)
if (isGeodesyScalar!T)
{
private:
    alias W = PolygonWorkingScalar!T;

    Geodesic!T _solver;
    bool _valid;
    size_t _pointCount;
    GeographicCoordinate!T _first;
    GeographicCoordinate!T _previous;
    CompensatedSum!W _perimeter;
    CompensatedSum!W _area;
    long _crossings;
    W _ellipsoidArea = W.nan;

    bool edge(
        const GeographicCoordinate!T from,
        const GeographicCoordinate!T to,
        out W distance,
        out W area,
        out int crossing) const
        pure nothrow @safe @nogc
    {
        distance = cast(W) 0;
        area = cast(W) 0;
        crossing = 0;

        GeodesicInverseResult!T inverse;
        GeodesicQuantities!T quantities;

        if (!_solver.tryInverse(
                from,
                to,
                inverse,
                quantities))
            return false;

        distance =
            cast(W) inverse.distance;

        area =
            cast(W) quantities.signedArea;

        crossing =
            primeMeridianTransit!W(
                cast(W) from.longitude.radians,
                cast(W) to.longitude.radians);

        return isFiniteGeodesyScalar(distance)
            && isFiniteGeodesyScalar(area);
    }

public:
    /** True when this accumulator has a valid prepared geodesic solver. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _valid;
    }

    /// Example checking accumulator validity.
    @safe unittest
    {
        assert(!GeodesicPolygonAccumulator!double.init.isValid);
    }

    /** Number of vertices currently accumulated. */
    @property size_t pointCount() const
        pure nothrow @safe @nogc
    {
        return _pointCount;
    }

    /// Example reading the current vertex count.
    @safe unittest
    {
        GeodesicPolygonAccumulator!double accumulator;
        assert(accumulator.pointCount == 0);
    }

    /**
     * Prepare an empty polygon accumulator without throwing.
     */
    static bool tryFromGeodesic(
        const Geodesic!T solver,
        out GeodesicPolygonAccumulator result)
        pure nothrow @safe @nogc
    {
        result =
            GeodesicPolygonAccumulator.init;

        if (!solver.isValid)
            return false;

        const Ellipsoid!T ellipsoid =
            solver.ellipsoid;

        const W a =
            cast(W) ellipsoid.semiMajorAxis;

        const W b =
            cast(W) ellipsoid.semiMinorAxis;

        const W e2 =
            cast(W) ellipsoid.firstEccentricitySquared;

        const W authalicRadiusSquared =
            geodesicAuthalicRadiusSquared(
                a,
                b,
                e2);

        const W ellipsoidArea =
            cast(W) 4
            * cast(W) PI
            * authalicRadiusSquared;

        if (!isFiniteGeodesyScalar(ellipsoidArea)
            || ellipsoidArea <= cast(W) 0)
            return false;

        GeodesicPolygonAccumulator candidate;
        candidate._solver = solver;
        candidate._ellipsoidArea = ellipsoidArea;
        candidate._valid = true;

        result = candidate;
        return true;
    }

    /// Example preparing an empty accumulator without throwing.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.fromFlattening(
                    6_378_137.0,
                    1.0 / 298.257223563));

        GeodesicPolygonAccumulator!double accumulator;

        assert(
            GeodesicPolygonAccumulator!double.tryFromGeodesic(
                solver,
                accumulator));

        assert(accumulator.isValid);
    }

    /** Prepare an empty polygon accumulator. */
    static GeodesicPolygonAccumulator fromGeodesic(
        const Geodesic!T solver)
        @safe
    {
        GeodesicPolygonAccumulator result;

        if (!tryFromGeodesic(
                solver,
                result))
        {
            throw new GeodesyValueException(
                "GeodesicPolygonAccumulator requires a valid geodesic solver.");
        }

        return result;
    }

    /// Example preparing an accumulator with throwing failure semantics.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.sphere(
                    6_371_000.0));

        const accumulator =
            GeodesicPolygonAccumulator!double.fromGeodesic(
                solver);

        assert(accumulator.isValid);
    }

    /**
     * Add one ordered geographic vertex without throwing.
     *
     * The operation is transactional: on numerical failure the accumulator is
     * unchanged.
     */
    bool tryAddPoint(
        const GeographicCoordinate!T point)
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        if (_pointCount == 0)
        {
            _first = point;
            _previous = point;
            _pointCount = 1;
            return true;
        }

        W distance;
        W area;
        int crossing;

        if (!edge(
                _previous,
                point,
                distance,
                area,
                crossing))
            return false;

        _perimeter.add(distance);
        _area.add(area);
        _crossings += crossing;
        _previous = point;
        ++_pointCount;

        return true;
    }

    /// Example incrementally adding polygon vertices.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.sphere(
                    6_371_000.0));

        auto accumulator =
            GeodesicPolygonAccumulator!double.fromGeodesic(
                solver);

        assert(
            accumulator.tryAddPoint(
                GeographicCoordinate!double.fromComponents(
                    Latitude!double.fromDegrees(0.0),
                    Longitude!double.fromDegrees(0.0))));

        assert(accumulator.pointCount == 1);
    }

    /** Add one ordered geographic vertex. */
    void addPoint(
        const GeographicCoordinate!T point)
        @safe
    {
        if (!tryAddPoint(point))
        {
            throw new GeodesyValueException(
                "Geodesic polygon vertex requires a valid accumulator and finite representable geodesic edge.");
        }
    }

    /// Example adding a vertex with throwing failure semantics.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.sphere(
                    6_371_000.0));

        auto accumulator =
            GeodesicPolygonAccumulator!double.fromGeodesic(
                solver);

        accumulator.addPoint(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0.0),
                Longitude!double.fromDegrees(0.0)));

        assert(accumulator.pointCount == 1);
    }

    /**
     * Compute the closed perimeter and canonical signed area without mutating
     * the accumulator.
     */
    bool tryCompute(
        out GeodesicPolygonResult!T result) const
        pure nothrow @safe @nogc
    {
        result =
            GeodesicPolygonResult!T.init;

        if (!isValid)
            return false;

        if (_pointCount < 2)
        {
            result =
                GeodesicPolygonResult!T.fromComponents(
                    _pointCount,
                    cast(T) 0,
                    cast(T) 0);
            return true;
        }

        W closingDistance;
        W closingArea;
        int closingCrossing;

        if (!edge(
                _previous,
                _first,
                closingDistance,
                closingArea,
                closingCrossing))
            return false;

        CompensatedSum!W perimeter =
            _perimeter;

        perimeter.add(
            closingDistance);

        CompensatedSum!W area =
            _area;

        area.add(
            closingArea);

        const W perimeterValue =
            perimeter.value;

        const W areaValue =
            canonicalPolygonArea!W(
                area.value,
                _crossings + closingCrossing,
                _ellipsoidArea);

        const T publicPerimeter =
            cast(T) perimeterValue;

        const T publicArea =
            cast(T) areaValue;

        if (!isFiniteGeodesyScalar(publicPerimeter)
            || !isFiniteGeodesyScalar(publicArea))
            return false;

        result =
            GeodesicPolygonResult!T.fromComponents(
                _pointCount,
                publicPerimeter == cast(T) 0
                    ? cast(T) 0
                    : publicPerimeter,
                publicArea == cast(T) 0
                    ? cast(T) 0
                    : publicArea);

        return true;
    }

    /// Example computing a closed polygon without mutating the accumulator.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.sphere(
                    6_371_000.0));

        auto accumulator =
            GeodesicPolygonAccumulator!double.fromGeodesic(
                solver);

        accumulator.addPoint(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0.0),
                Longitude!double.fromDegrees(0.0)));

        accumulator.addPoint(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0.0),
                Longitude!double.fromDegrees(1.0)));

        accumulator.addPoint(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(1.0),
                Longitude!double.fromDegrees(0.0)));

        GeodesicPolygonResult!double result;

        assert(accumulator.tryCompute(result));
        assert(result.pointCount == 3);
        assert(result.perimeter > 0.0);
        assert(result.signedArea > 0.0);
        assert(accumulator.pointCount == 3);
    }

    /** Compute the closed perimeter and canonical signed area. */
    GeodesicPolygonResult!T compute() const
        @safe
    {
        GeodesicPolygonResult!T result;

        if (!tryCompute(result))
        {
            throw new GeodesyValueException(
                "Geodesic polygon computation requires a valid accumulator and finite representable closing edge.");
        }

        return result;
    }

    /// Example computing a closed polygon with throwing failure semantics.
    @safe unittest
    {
        const solver =
            Geodesic!double.fromEllipsoid(
                Ellipsoid!double.sphere(
                    6_371_000.0));

        auto accumulator =
            GeodesicPolygonAccumulator!double.fromGeodesic(
                solver);

        accumulator.addPoint(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0.0),
                Longitude!double.fromDegrees(0.0)));

        const result =
            accumulator.compute();

        assert(result.pointCount == 1);
        assert(result.perimeter == 0.0);
        assert(result.signedArea == 0.0);
    }
}


@safe unittest
{
    import std.math : fabs;

    const solver =
        Geodesic!double.fromEllipsoid(
            Ellipsoid!double.sphere(
                6_371_000.0));

    auto ccw =
        GeodesicPolygonAccumulator!double.fromGeodesic(
            solver);

    auto cw =
        GeodesicPolygonAccumulator!double.fromGeodesic(
            solver);

    const p0 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(0.0));

    const p1 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(1.0));

    const p2 =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(1.0),
            Longitude!double.fromDegrees(0.0));

    ccw.addPoint(p0);
    ccw.addPoint(p1);
    ccw.addPoint(p2);

    cw.addPoint(p0);
    cw.addPoint(p2);
    cw.addPoint(p1);

    const ccwResult =
        ccw.compute();

    const cwResult =
        cw.compute();

    assert(ccwResult.perimeter > 0.0);
    assert(
        fabs(
            ccwResult.perimeter
                - cwResult.perimeter)
        < 1.0e-8);

    assert(ccwResult.signedArea > 0.0);
    assert(cwResult.signedArea < 0.0);

    assert(
        fabs(
            ccwResult.signedArea
                + cwResult.signedArea)
        < 1.0e-3);
}
