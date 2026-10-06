/**
 * Scalar policy shared by geodesy-d numerical value types and operations.
 *
 * Public numerical APIs support the built-in floating types float, double,
 * and real. An API's scalar type does not require identical internal working
 * precision: numerically sensitive float operations may use double arithmetic
 * and convert back at the public boundary.
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

/// Example checking the public scalar policy.
unittest
{
    import geodesy;
    static assert(isGeodesyScalar!float);
    static assert(isGeodesyScalar!double);
    static assert(isGeodesyScalar!real);
    static assert(!isGeodesyScalar!int);
}

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
