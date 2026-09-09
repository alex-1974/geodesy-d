/** Strong angular and geographic angular-coordinate value types. */
module geodesy.angle;

import std.math : PI;
import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


private T pi(T)() pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) PI;
}

private T halfPi(T)() pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return pi!T / cast(T) 2;
}

private T degreesToRadians(T)(const T degrees) pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return (degrees / cast(T) 180) * pi!T;
}

private T radiansToDegrees(T)(const T radians) pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return (radians / pi!T) * cast(T) 180;
}

/** A finite angle stored canonically in radians. */
struct Angle(T)
if (isGeodesyScalar!T)
{
private:
    T _radians = 0;

    static Angle fromRadiansUnchecked(const T radians) pure nothrow @safe @nogc
    {
        Angle result;
        result._radians = radians;
        return result;
    }

public:
    static bool tryFromRadians(const T radians, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians))
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    static bool tryFromDegrees(const T degrees, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees))
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    static Angle fromRadians(const T radians)
        @safe
    {
        Angle result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Angle must be finite.");
        return result;
    }

    static Angle fromDegrees(const T degrees)
        @safe
    {
        Angle result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Angle must be finite.");
        return result;
    }

    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }
}

/** Geodetic latitude in the closed interval [-pi/2, +pi/2]. */
struct Latitude(T)
if (isGeodesyScalar!T)
{
private:
    T _radians = 0;

    static Latitude fromRadiansUnchecked(const T radians) pure nothrow @safe @nogc
    {
        Latitude result;
        result._radians = radians;
        return result;
    }

public:
    static bool tryFromRadians(const T radians, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -halfPi!T || radians > halfPi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    static bool tryFromDegrees(const T degrees, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -90 || degrees > cast(T) 90)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    static Latitude fromRadians(const T radians)
        @safe
    {
        Latitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Latitude must be finite and within [-pi/2, +pi/2].");
        return result;
    }

    static Latitude fromDegrees(const T degrees)
        @safe
    {
        Latitude result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Latitude must be finite and within [-90, +90] degrees.");
        return result;
    }

    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }

    @property Angle!T asAngle() const pure nothrow @safe @nogc
    {
        return Angle!T.fromRadiansUnchecked(_radians);
    }
}

/** Geodetic longitude in the closed interval [-pi, +pi]. */
struct Longitude(T)
if (isGeodesyScalar!T)
{
private:
    T _radians = 0;

    static Longitude fromRadiansUnchecked(const T radians) pure nothrow @safe @nogc
    {
        Longitude result;
        result._radians = radians;
        return result;
    }

public:
    static bool tryFromRadians(const T radians, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -pi!T || radians > pi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    static bool tryFromDegrees(const T degrees, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -180 || degrees > cast(T) 180)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    static Longitude fromRadians(const T radians)
        @safe
    {
        Longitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Longitude must be finite and within [-pi, +pi].");
        return result;
    }

    static Longitude fromDegrees(const T degrees)
        @safe
    {
        Longitude result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Longitude must be finite and within [-180, +180] degrees.");
        return result;
    }

    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }

    @property Angle!T asAngle() const pure nothrow @safe @nogc
    {
        return Angle!T.fromRadiansUnchecked(_radians);
    }

    /** Return the unique half-open representation [-pi, +pi). */
    @property Longitude normalized() const pure nothrow @safe @nogc
    {
        if (_radians >= pi!T)
            return fromRadiansUnchecked(-pi!T);
        return fromRadiansUnchecked(_radians);
    }
}


/**
 * Internal construction helper for geodesy implementation modules.
 *
 * The caller must already have established that `radians` is finite.
 */
package(geodesy) Angle!T angleFromRadiansUnchecked(T)(const T radians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return Angle!T.fromRadiansUnchecked(radians);
}


unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    static assert(is(Angle!float));
    static assert(is(Angle!double));
    static assert(is(Angle!real));
    static assert(is(Latitude!float));
    static assert(is(Longitude!real));

    auto latitude = Latitude!double.fromDegrees(48.20849);
    auto longitude = Longitude!double.fromDegrees(16.37208);
    assert(fabs(latitude.degrees - 48.20849) < 1e-12);
    assert(fabs(longitude.degrees - 16.37208) < 1e-12);

    Latitude!double candidate;
    assert(!Latitude!double.tryFromDegrees(90.0001, candidate));
    assert(!Latitude!double.tryFromRadians(double.nan, candidate));
    assertThrown!GeodesyValueException(Latitude!double.fromDegrees(91.0));

    auto eastAntimeridian = Longitude!double.fromDegrees(180.0);
    assert(eastAntimeridian.degrees > 0);
    assert(eastAntimeridian.normalized.degrees < 0);

    Longitude!double invalidLongitude;
    assert(!Longitude!double.tryFromDegrees(181.0, invalidLongitude));
}
