/**
 * Three-dimensional geodetic coordinate value type.
 *
 * A geodetic coordinate combines strong latitude and longitude values with a
 * finite ellipsoidal height. Datum, CRS, ellipsoid identity, epoch, and unit
 * metadata are deliberately not embedded; operations that need those concepts
 * receive them explicitly.
 *
 * Units:
 *     Latitude and longitude use the strong angular types. Ellipsoidal height
 *     uses a caller-selected linear unit and must match the associated
 *     ellipsoid where an operation combines them.
 *
 * Performance:
 *     Checked construction and value access require no allocation.
 *
 * See_Also:
 *     `GeographicCoordinate`, `GeocentricCoordinate`, `Ellipsoid`
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
 *     September 26, 2026
 */
module geodesy.geodetic;

import geodesy.angle : Latitude, Longitude;
import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;

/**
 * A geodetic position represented by strong latitude and longitude values and
 * finite ellipsoidal height.
 *
 * The linear unit of `ellipsoidalHeight` is not encoded in the type. When
 * used with an ellipsoid, the height and ellipsoid axes must use the same
 * linear unit. No datum, CRS, or ellipsoid identity is embedded.
 *
 * `.init` represents latitude zero, longitude zero, and zero ellipsoidal
 * height. Checked construction returns `false` for non-finite height;
 * throwing construction reports the same failure with
 * `GeodesyValueException`.
 *
 */
struct GeodeticCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    Latitude!T _latitude;
    Longitude!T _longitude;
    T _ellipsoidalHeight = 0;

    static GeodeticCoordinate fromComponentsUnchecked(
        const Latitude!T latitude,
        const Longitude!T longitude,
        const T ellipsoidalHeight)
        pure nothrow @safe @nogc
    {
        GeodeticCoordinate result;
        result._latitude = latitude;
        result._longitude = longitude;
        result._ellipsoidalHeight = ellipsoidalHeight;
        return result;
    }

public:
    /**
     * Construct from strong angular values and finite ellipsoidal height
     * without throwing.
     *
     * Params:
     *     latitude = Geodetic latitude.
     *     longitude = Geodetic longitude.
     *     ellipsoidalHeight = Finite height in the caller-selected linear unit.
     *     result = Receives the constructed coordinate on success.
     *
     * Returns:
     *     `true` on success; `false` when `ellipsoidalHeight` is NaN or
     *     infinite. On failure `result` is initialized to `.init` on entry and has no guaranteed value on failure.
     */
    static bool tryFromComponents(
        const Latitude!T latitude,
        const Longitude!T longitude,
        const T ellipsoidalHeight,
        out GeodeticCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(ellipsoidalHeight))
            return false;

        result = fromComponentsUnchecked(latitude, longitude, ellipsoidalHeight);
        return true;
    }

    /// Example checking a geodetic coordinate without throwing.
    @safe unittest
    {
        import geodesy;
        GeodeticCoordinate!double point;
        assert(GeodeticCoordinate!double.tryFromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0),
            171.0,
            point));
        assert(point.ellipsoidalHeight == 171.0);
    }

    /**
     * Construct a geodetic coordinate.
     *
     * Params:
     *     latitude = Geodetic latitude.
     *     longitude = Geodetic longitude.
     *     ellipsoidalHeight = Finite height in the caller-selected linear unit.
     *
     * Returns:
     *     The constructed coordinate.
     *
     * Throws:
     *     `GeodesyValueException` when `ellipsoidalHeight` is NaN or infinite.
     */
    static GeodeticCoordinate fromComponents(
        const Latitude!T latitude,
        const Longitude!T longitude,
        const T ellipsoidalHeight = 0)
        @safe
    {
        GeodeticCoordinate result;
        if (!tryFromComponents(latitude, longitude, ellipsoidalHeight, result))
            throw new GeodesyValueException("Ellipsoidal height must be finite.");
        return result;
    }

    /// Example constructing a geodetic coordinate.
    @safe unittest
    {
        import geodesy;
        const point = GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0),
            171.0);
        assert(point.ellipsoidalHeight == 171.0);
    }

    /** Geodetic latitude. */
    @property Latitude!T latitude() const pure nothrow @safe @nogc
    {
        return _latitude;
    }

    /// Example reading geodetic latitude.
    @safe unittest
    {
        import geodesy;
        const point = GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));
        assert(point.latitude.degrees == 48.0);
    }

    /** Geodetic longitude. */
    @property Longitude!T longitude() const pure nothrow @safe @nogc
    {
        return _longitude;
    }

    /// Example reading geodetic longitude.
    @safe unittest
    {
        import geodesy;
        const point = GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));
        assert(point.longitude.degrees == 16.0);
    }

    /** Ellipsoidal height in the operation's linear unit. */
    @property T ellipsoidalHeight() const pure nothrow @safe @nogc
    {
        return _ellipsoidalHeight;
    }

    /// Example reading ellipsoidal height.
    @safe unittest
    {
        import geodesy;
        const point = GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0),
            171.0);
        assert(point.ellipsoidalHeight == 171.0);
    }
}

/// Example constructing and validating a geodetic coordinate.
@safe unittest
{
    import geodesy;
    
    const vienna = GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208),
        171.0);
    
    assert(vienna.ellipsoidalHeight == 171.0);
    
    GeodeticCoordinate!double checked;
    assert(!GeodeticCoordinate!double.tryFromComponents(
        vienna.latitude, vienna.longitude, double.nan, checked));
    
}


unittest
{
    import std.exception : assertThrown;

    static assert(is(GeodeticCoordinate!float));
    static assert(is(GeodeticCoordinate!double));
    static assert(is(GeodeticCoordinate!real));

    const latitude = Latitude!double.fromDegrees(48.20849);
    const longitude = Longitude!double.fromDegrees(16.37208);
    const vienna = GeodeticCoordinate!double.fromComponents(latitude, longitude, 171.0);

    assert(vienna.latitude.degrees == latitude.degrees);
    assert(vienna.longitude.degrees == longitude.degrees);
    assert(vienna.ellipsoidalHeight == 171.0);

    const zero = GeodeticCoordinate!double.init;
    assert(zero.latitude.radians == 0.0);
    assert(zero.longitude.radians == 0.0);
    assert(zero.ellipsoidalHeight == 0.0);

    GeodeticCoordinate!double candidate;
    assert(!GeodeticCoordinate!double.tryFromComponents(
        latitude, longitude, double.nan, candidate));
    assertThrown!GeodesyValueException(
        GeodeticCoordinate!double.fromComponents(latitude, longitude, double.infinity));
}
