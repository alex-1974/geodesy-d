/**
 * Internal stable two-dimensional Euclidean norm.
 *
 * This helper avoids the Phobos 2.111 two-argument hypot defect for
 * sufficiently tiny/subnormal operands while retaining overflow-safe scaling.
 */
module geodesy.internal.hypot_compat;

import std.math : fabs, sqrt;

import geodesy.scalar : isGeodesyScalar;

package(geodesy):


/**
 * Return sqrt(x*x + y*y) without avoidable intermediate overflow/underflow.
 *
 * The larger magnitude is factored out before squaring. This also preserves
 * an axis-aligned smallest-positive subnormal instead of triggering the
 * affected Phobos 2.111 hypot scaling path.
 */
T stableHypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T hi = ax >= ay ? ax : ay;
    const T lo = ax >= ay ? ay : ax;

    if (hi == cast(T) 0)
        return cast(T) 0;

    const T ratio = lo / hi;
    return hi * sqrt(cast(T) 1 + ratio * ratio);
}


unittest
{
    enum double smallest = 0x1p-1074;

    assert(stableHypot2(smallest, 0.0) == smallest);
    assert(stableHypot2(0.0, smallest) == smallest);
    assert(stableHypot2(3.0, 4.0) == 5.0);

    const double large = double.max / 2.0;
    const double norm = stableHypot2(large, large);
    assert(norm > large);
    assert(norm < double.infinity);
}
