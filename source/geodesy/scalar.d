/**
 * Scalar policy shared by geodesy-d numerical value types and operations.
 *
 * The public numerical surface deliberately supports the built-in floating
 * scalar types float, double, and real. Public scalar choice does not force
 * every algorithm to use that same type internally: numerically sensitive
 * float operations may promote working arithmetic to double while preserving
 * float at the public boundary.
 *
 * Numerics:
 *     Double is the normative reference precision unless an operation-specific
 *     contract states otherwise. Real is platform-dependent. There is no
 *     library-wide epsilon; convergence and validation tolerances belong to
 *     individual algorithms.
 *
 * See_Also:
 *     Operation-specific `Numerics:` and `Validation:` documentation.
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
module geodesy.scalar;

/**
 * True for the supported built-in floating-point scalar types.
 *
 * Qualified scalar types are intentionally excluded: value types own mutable
 * storage during checked construction and expose constness at the aggregate
 * level instead.
 */
enum bool isGeodesyScalar(T) =
    is(T == float) || is(T == double) || is(T == real);

unittest
{
    static assert(isGeodesyScalar!float);
    static assert(isGeodesyScalar!double);
    static assert(isGeodesyScalar!real);
    static assert(!isGeodesyScalar!int);
    static assert(!isGeodesyScalar!(const double));
}

/** Return true if a supported scalar is finite. Internal package helper. */
package bool isFiniteGeodesyScalar(T)(const T value) pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return value == value && value != T.infinity && value != -T.infinity;
}

unittest
{
    assert(isFiniteGeodesyScalar(0.0));
    assert(!isFiniteGeodesyScalar(double.nan));
    assert(!isFiniteGeodesyScalar(double.infinity));
}
