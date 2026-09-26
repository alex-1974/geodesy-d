/**
 * Three-dimensional geodetic coordinate value type.
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
 * Example:
 * ---
 * import geodesy;
 *
 * const vienna = GeodeticCoordinate!double.fromComponents(
 *     Latitude!double.fromDegrees(48.20849),
 *     Longitude!double.fromDegrees(16.37208),
 *     171.0);
 *
 * assert(vienna.ellipsoidalHeight == 171.0);
 *
 * GeodeticCoordinate!double checked;
 * assert(!GeodeticCoordinate!double.tryFromComponents(
 *     vienna.latitude, vienna.longitude, double.nan, checked));
 * ---
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
    /** Construct from strong angular values and finite ellipsoidal height without throwing. */
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

    /** Construct a geodetic coordinate or throw when height is non-finite. */
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

    /** Geodetic latitude. */
    @property Latitude!T latitude() const pure nothrow @safe @nogc
    {
        return _latitude;
    }

    /** Geodetic longitude. */
    @property Longitude!T longitude() const pure nothrow @safe @nogc
    {
        return _longitude;
    }

    /** Ellipsoidal height in the operation's linear unit. */
    @property T ellipsoidalHeight() const pure nothrow @safe @nogc
    {
        return _ellipsoidalHeight;
    }
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
