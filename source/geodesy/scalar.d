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
