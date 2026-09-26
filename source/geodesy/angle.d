/**
 * Strong angular and geographic angular-coordinate value types.
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

/**
 * A finite angle stored canonically in radians.
 *
 * `.init` represents zero radians. Construction accepts `float`, `double`,
 * or `real`; checked factories reject non-finite input without throwing,
 * while throwing factories report the same failure with
 * `GeodesyValueException`.
 *
 * No allocation is performed by checked construction or value access.
 *
 * Example:
 * ---
 * import geodesy;
 *
 * const quarterTurn = Angle!double.fromDegrees(90.0);
 * assert(quarterTurn.degrees == 90.0);
 *
 * Angle!double checked;
 * assert(Angle!double.tryFromRadians(0.5, checked));
 * assert(!Angle!double.tryFromRadians(double.nan, checked));
 * ---
 */
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
    /** Construct from radians without throwing; returns false for non-finite input. */
    static bool tryFromRadians(const T radians, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians))
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /** Construct from degrees without throwing; returns false for non-finite input. */
    static bool tryFromDegrees(const T degrees, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees))
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /** Construct from radians or throw `GeodesyValueException` for non-finite input. */
    static Angle fromRadians(const T radians)
        @safe
    {
        Angle result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Angle must be finite.");
        return result;
    }

    /** Construct from degrees or throw `GeodesyValueException` for non-finite input. */
    static Angle fromDegrees(const T degrees)
        @safe
    {
        Angle result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Angle must be finite.");
        return result;
    }

    /** Angle value in canonical radians. */
    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    /** Angle value converted to degrees. */
    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }
}

/**
 * Geodetic latitude in the closed interval [-pi/2, +pi/2] radians.
 *
 * The equivalent degree domain is [-90,+90]. `.init` is the equator.
 * Checked factories return `false` for non-finite or out-of-domain input;
 * throwing factories throw `GeodesyValueException` for the same inputs.
 *
 * Example:
 * ---
 * import geodesy;
 *
 * const vienna = Latitude!double.fromDegrees(48.20849);
 * assert(vienna.degrees > 48.0);
 *
 * Latitude!double checked;
 * assert(!Latitude!double.tryFromDegrees(90.0001, checked));
 * ---
 */
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
    /** Construct from radians; returns false outside [-pi/2,+pi/2] or for non-finite input. */
    static bool tryFromRadians(const T radians, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -halfPi!T || radians > halfPi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /** Construct from degrees; returns false outside [-90,+90] or for non-finite input. */
    static bool tryFromDegrees(const T degrees, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -90 || degrees > cast(T) 90)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /** Construct from radians or throw when outside the latitude domain. */
    static Latitude fromRadians(const T radians)
        @safe
    {
        Latitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Latitude must be finite and within [-pi/2, +pi/2].");
        return result;
    }

    /** Construct from degrees or throw when outside the latitude domain. */
    static Latitude fromDegrees(const T degrees)
        @safe
    {
        Latitude result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Latitude must be finite and within [-90, +90] degrees.");
        return result;
    }

    /** Latitude in radians. */
    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    /** Latitude in degrees. */
    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }

    /** Return the same angular value as a general `Angle!T`. */
    @property Angle!T asAngle() const pure nothrow @safe @nogc
    {
        return Angle!T.fromRadiansUnchecked(_radians);
    }
}

/**
 * Geodetic longitude in the closed interval [-pi,+pi] radians.
 *
 * The equivalent degree domain is [-180,+180]. Both antimeridian endpoint
 * representations are accepted by construction. `normalized` maps the
 * positive endpoint to the unique half-open representation from -pi
 * inclusive to +pi exclusive. `.init` is the prime meridian.
 *
 * Checked factories return `false` for non-finite or out-of-domain input;
 * throwing factories throw `GeodesyValueException` for the same inputs.
 *
 * Example:
 * ---
 * import geodesy;
 *
 * const eastAntimeridian = Longitude!double.fromDegrees(180.0);
 * assert(eastAntimeridian.degrees == 180.0);
 * assert(eastAntimeridian.normalized.degrees == -180.0);
 *
 * Longitude!double checked;
 * assert(!Longitude!double.tryFromDegrees(181.0, checked));
 * ---
 */
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
    /** Construct from radians; returns false outside [-pi,+pi] or for non-finite input. */
    static bool tryFromRadians(const T radians, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -pi!T || radians > pi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /** Construct from degrees; returns false outside [-180,+180] or for non-finite input. */
    static bool tryFromDegrees(const T degrees, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -180 || degrees > cast(T) 180)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /** Construct from radians or throw when outside the longitude domain. */
    static Longitude fromRadians(const T radians)
        @safe
    {
        Longitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Longitude must be finite and within [-pi, +pi].");
        return result;
    }

    /** Construct from degrees or throw when outside the longitude domain. */
    static Longitude fromDegrees(const T degrees)
        @safe
    {
        Longitude result;
        if (!tryFromDegrees(degrees, result))
            throw new GeodesyValueException("Longitude must be finite and within [-180, +180] degrees.");
        return result;
    }

    /** Longitude in radians. */
    @property T radians() const pure nothrow @safe @nogc
    {
        return _radians;
    }

    /** Longitude in degrees. */
    @property T degrees() const pure nothrow @safe @nogc
    {
        return radiansToDegrees(_radians);
    }

    /** Return the same angular value as a general `Angle!T`. */
    @property Angle!T asAngle() const pure nothrow @safe @nogc
    {
        return Angle!T.fromRadiansUnchecked(_radians);
    }

    /** Return the unique representation from -pi inclusive to +pi exclusive. */
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
