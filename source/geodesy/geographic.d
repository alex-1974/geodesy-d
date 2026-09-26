/**
 * Two-dimensional geographic latitude/longitude coordinate value type.
 *
 * GeographicCoordinate is the height-free position used by surface geodesics
 * and map projections. It composes the strong latitude and longitude types
 * without embedding datum, CRS, axis-order, or ellipsoid identity, keeping
 * those operation-specific semantics explicit at API boundaries.
 *
 * Units:
 *     Angular representation and canonicalization are owned by `Latitude`
 *     and `Longitude`.
 *
 * Performance:
 *     Construction and value access require no allocation.
 *
 * See_Also:
 *     `Latitude`, `Longitude`, `GeodeticCoordinate`, `Geodesic`,
 *     `TransverseMercator`
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
module geodesy.geographic;

import geodesy.angle : Latitude, Longitude;
import geodesy.scalar : isGeodesyScalar;


/**
 * A two-dimensional geographic position represented by strong geodetic
 * latitude and longitude values.
 *
 * This value does not carry datum, CRS, axis-order, ellipsoid, or height
 * semantics. The contained angular types enforce their own finite domains.
 * `.init` represents latitude zero and longitude zero.
 *
 * Construction and access perform no allocation.
 *
 */
struct GeographicCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    Latitude!T _latitude;
    Longitude!T _longitude;

public:
    /** Construct from strong latitude and longitude values. */
    static GeographicCoordinate fromComponents(
        const Latitude!T latitude,
        const Longitude!T longitude)
        pure nothrow @safe @nogc
    {
        GeographicCoordinate result;
        result._latitude = latitude;
        result._longitude = longitude;
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
}

/// Example constructing a geographic coordinate.
@safe unittest
{
    import geodesy;
    
    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    
    assert(vienna.latitude.degrees > 48.0);
    assert(vienna.longitude.degrees > 16.0);
    
}



unittest
{
    static assert(is(GeographicCoordinate!float));
    static assert(is(GeographicCoordinate!double));
    static assert(is(GeographicCoordinate!real));

    const latitude = Latitude!double.fromDegrees(48.20849);
    const longitude = Longitude!double.fromDegrees(16.37208);
    const vienna = GeographicCoordinate!double.fromComponents(latitude, longitude);

    assert(vienna.latitude.radians == latitude.radians);
    assert(vienna.longitude.radians == longitude.radians);

    const zero = GeographicCoordinate!double.init;
    assert(zero.latitude.radians == 0.0);
    assert(zero.longitude.radians == 0.0);
}
