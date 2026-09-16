/** Two-dimensional geographic coordinate value type. */
module geodesy.geographic;

import geodesy.angle : Latitude, Longitude;
import geodesy.scalar : isGeodesyScalar;


/**
 * A two-dimensional geographic position represented by geodetic latitude and
 * longitude.
 *
 * This value does not carry datum, CRS, axis-order, or height semantics.
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
