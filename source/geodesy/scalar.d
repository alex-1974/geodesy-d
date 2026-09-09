/** Scalar policy shared by geodesy-d numerical value types. */
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
