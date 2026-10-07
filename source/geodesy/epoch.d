/**
 * Strong decimal-year epoch value for time-dependent geodetic operations.
 *
 * Epoch keeps a finite decimal-year coordinate distinct from raw numerical
 * scalars. It does not interpret civil calendars, time scales, leap seconds,
 * or clock time.
 *
 * Units:
 *     Decimal year. Dynamic operations subtract finite epoch values in their
 *     own checked evaluation path.
 *
 * Default:
 *     `.init` is invalid so an omitted epoch cannot silently become year zero.
 *
 * See_Also:
 *     `Helmert14`
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
module geodesy.epoch;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;


/**
 * Finite geodetic epoch represented as a decimal year.
 *
 * The value is intentionally only a numerical epoch coordinate. Calendar and
 * time-scale conversion belong outside this type.
 */
struct Epoch(T)
if (isGeodesyScalar!T)
{
private:
    T _decimalYear = cast(T) 0;
    bool _valid = false;

public:
    /** Whether this value contains a valid finite epoch. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _valid;
    }

    /** Decimal-year representation. */
    @property T decimalYear() const pure nothrow @safe @nogc
    {
        return _decimalYear;
    }

    /**
     * Construct a finite decimal-year epoch without throwing.
     *
     * Params:
     *     value = Finite decimal year.
     *     result = Receives the epoch on success.
     *
     * Returns:
     *     `true` for finite input; otherwise `false`. On entry `result`
     *     is reset to invalid `.init`.
     */
    static bool tryFromDecimalYear(
        const T value,
        out Epoch!T result)
        pure nothrow @safe @nogc
    {
        result = Epoch!T.init;
        if (!isFiniteGeodesyScalar(value))
            return false;

        result._decimalYear = value;
        result._valid = true;
        return true;
    }

    /**
     * Construct a finite decimal-year epoch.
     *
     * Throws:
     *     `GeodesyValueException` when `value` is not finite.
     */
    static Epoch!T fromDecimalYear(const T value) @safe
    {
        Epoch!T result;
        if (!tryFromDecimalYear(value, result))
            throw new GeodesyValueException(
                "Epoch decimal year must be finite.");
        return result;
    }
}

/// Example constructing and comparing epochs.
@safe unittest
{
    import geodesy;

    const reference = Epoch!double.fromDecimalYear(2010.0);
    const observation = Epoch!double.fromDecimalYear(2025.25);

    assert(reference.isValid);
    assert(observation.decimalYear == 2025.25);
    assert(!Epoch!double.init.isValid);
}

unittest
{
    import std.exception : assertThrown;

    Epoch!double epoch;
    assert(!Epoch!double.tryFromDecimalYear(double.nan, epoch));
    assert(!epoch.isValid);

    assertThrown!GeodesyValueException(
        Epoch!double.fromDecimalYear(double.infinity));

    static assert(__traits(compiles, Epoch!float.fromDecimalYear(2000.0f)));
    static assert(__traits(compiles, Epoch!real.fromDecimalYear(2000.0L)));
}
