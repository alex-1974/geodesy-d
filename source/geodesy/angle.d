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
    /**
     * Construct from radians without throwing.
     *
     * Params:
     *     radians = Finite angle in radians.
     *     result = Receives the constructed angle on success.
     *
     * Returns:
     *     `true` on success; `false` for NaN or infinity. On failure
     *     `result` remains unchanged.
     */
    static bool tryFromRadians(const T radians, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians))
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /**
     * Construct from degrees without throwing.
     *
     * Params:
     *     degrees = Finite angle in degrees.
     *     result = Receives the constructed angle on success.
     *
     * Returns:
     *     `true` on success; `false` for NaN, infinity, or when conversion
     *     to scalar `T` does not produce a finite radian value. On failure
     *     `result` remains unchanged.
     */
    static bool tryFromDegrees(const T degrees, out Angle result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees))
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /**
     * Construct from radians.
     *
     * Params:
     *     radians = Finite angle in radians.
     *
     * Returns:
     *     The constructed angle.
     *
     * Throws:
     *     `GeodesyValueException` for NaN or infinity.
     */
    static Angle fromRadians(const T radians)
        @safe
    {
        Angle result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Angle must be finite.");
        return result;
    }

    /**
     * Construct from degrees.
     *
     * Params:
     *     degrees = Finite angle in degrees.
     *
     * Returns:
     *     The constructed angle.
     *
     * Throws:
     *     `GeodesyValueException` for NaN, infinity, or an unrepresentable
     *     radian conversion in scalar `T`.
     */
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

/// Example using an angle with checked and throwing construction.
@safe unittest
{
    import geodesy;
    
    const quarterTurn = Angle!double.fromDegrees(90.0);
    assert(quarterTurn.degrees == 90.0);
    
    Angle!double checked;
    assert(Angle!double.tryFromRadians(0.5, checked));
    assert(!Angle!double.tryFromRadians(double.nan, checked));
    
}


/**
 * Geodetic latitude in the closed interval [-pi/2, +pi/2] radians.
 *
 * The equivalent degree domain is [-90,+90]. `.init` is the equator.
 * Checked factories return `false` for non-finite or out-of-domain input;
 * throwing factories throw `GeodesyValueException` for the same inputs.
 *
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
    /**
     * Construct a latitude from radians without throwing.
     *
     * Params:
     *     radians = Latitude in the closed interval [-pi/2,+pi/2].
     *     result = Receives the constructed latitude on success.
     *
     * Returns:
     *     `true` on success; `false` for non-finite or out-of-domain input.
     *     On failure `result` remains unchanged.
     */
    static bool tryFromRadians(const T radians, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -halfPi!T || radians > halfPi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /**
     * Construct a latitude from degrees without throwing.
     *
     * Params:
     *     degrees = Latitude in the closed interval [-90,+90] degrees.
     *     result = Receives the constructed latitude on success.
     *
     * Returns:
     *     `true` on success; `false` for non-finite or out-of-domain input.
     *     On failure `result` remains unchanged.
     */
    static bool tryFromDegrees(const T degrees, out Latitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -90 || degrees > cast(T) 90)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /**
     * Construct a latitude from radians.
     *
     * Params:
     *     radians = Latitude in the closed interval [-pi/2,+pi/2].
     *
     * Returns:
     *     The constructed latitude.
     *
     * Throws:
     *     `GeodesyValueException` for non-finite or out-of-domain input.
     */
    static Latitude fromRadians(const T radians)
        @safe
    {
        Latitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Latitude must be finite and within [-pi/2, +pi/2].");
        return result;
    }

    /**
     * Construct a latitude from degrees.
     *
     * Params:
     *     degrees = Latitude in the closed interval [-90,+90] degrees.
     *
     * Returns:
     *     The constructed latitude.
     *
     * Throws:
     *     `GeodesyValueException` for non-finite or out-of-domain input.
     */
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

/// Example constructing and validating a latitude.
@safe unittest
{
    import geodesy;
    
    const vienna = Latitude!double.fromDegrees(48.20849);
    assert(vienna.degrees > 48.0);
    
    Latitude!double checked;
    assert(!Latitude!double.tryFromDegrees(90.0001, checked));
    
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
    /**
     * Construct a longitude from radians without throwing.
     *
     * Params:
     *     radians = Longitude in the closed interval [-pi,+pi].
     *     result = Receives the constructed longitude on success.
     *
     * Returns:
     *     `true` on success; `false` for non-finite or out-of-domain input.
     *     Both antimeridian endpoints are accepted. On failure `result`
     *     remains unchanged.
     */
    static bool tryFromRadians(const T radians, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(radians) || radians < -pi!T || radians > pi!T)
            return false;
        result = fromRadiansUnchecked(radians);
        return true;
    }

    /**
     * Construct a longitude from degrees without throwing.
     *
     * Params:
     *     degrees = Longitude in the closed interval [-180,+180] degrees.
     *     result = Receives the constructed longitude on success.
     *
     * Returns:
     *     `true` on success; `false` for non-finite or out-of-domain input.
     *     Both antimeridian endpoints are accepted. On failure `result`
     *     remains unchanged.
     */
    static bool tryFromDegrees(const T degrees, out Longitude result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(degrees) || degrees < cast(T) -180 || degrees > cast(T) 180)
            return false;
        return tryFromRadians(degreesToRadians(degrees), result);
    }

    /**
     * Construct a longitude from radians.
     *
     * Params:
     *     radians = Longitude in the closed interval [-pi,+pi].
     *
     * Returns:
     *     The constructed longitude; both antimeridian endpoints are preserved.
     *
     * Throws:
     *     `GeodesyValueException` for non-finite or out-of-domain input.
     */
    static Longitude fromRadians(const T radians)
        @safe
    {
        Longitude result;
        if (!tryFromRadians(radians, result))
            throw new GeodesyValueException("Longitude must be finite and within [-pi, +pi].");
        return result;
    }

    /**
     * Construct a longitude from degrees.
     *
     * Params:
     *     degrees = Longitude in the closed interval [-180,+180] degrees.
     *
     * Returns:
     *     The constructed longitude; both antimeridian endpoints are preserved.
     *
     * Throws:
     *     `GeodesyValueException` for non-finite or out-of-domain input.
     */
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

/// Example constructing and normalizing a longitude.
@safe unittest
{
    import geodesy;
    
    const eastAntimeridian = Longitude!double.fromDegrees(180.0);
    assert(eastAntimeridian.degrees == 180.0);
    assert(eastAntimeridian.normalized.degrees == -180.0);
    
    Longitude!double checked;
    assert(!Longitude!double.tryFromDegrees(181.0, checked));
    
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
