/** Geodetic coordinate value type. */
module geodesy.geodetic;

import geodesy.angle : Latitude, Longitude;
import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;

/**
 * A geodetic position represented by geodetic latitude, longitude, and
 * ellipsoidal height.
 *
 * The linear unit of `ellipsoidalHeight` is not encoded in the type. When a
 * coordinate is used with an ellipsoid, height and ellipsoid axes must use the
 * same linear unit.
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

    @property Latitude!T latitude() const pure nothrow @safe @nogc
    {
        return _latitude;
    }

    @property Longitude!T longitude() const pure nothrow @safe @nogc
    {
        return _longitude;
    }

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
