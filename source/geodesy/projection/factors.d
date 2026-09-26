/**
 * Local meridian-convergence and point-scale results for conformal projections.
 *
 * The module gives projection factors their own strong result type instead of
 * returning unrelated raw scalars. The current public producers are prepared
 * Transverse Mercator and UTM operations; the type deliberately does not claim
 * to model the more general distortion quantities required by non-conformal
 * projections.
 *
 * Units:
 *     Meridian convergence is an `Angle`; point scale is dimensionless.
 *
 * Numerics:
 *     Reverse factors are evaluated at the accepted post-policy
 *     working-precision geographic point rather than after unnecessary public
 *     scalar rounding. Exact geographic poles use the documented canonical
 *     convergence convention.
 *
 * Validation:
 *     Factor semantics were independently checked against GeographicLib,
 *     analytic spherical references, binary32 projected-input cases, boundary
 *     policy tests, and DMD/LDC agreement before promotion to the public API.
 *
 * See_Also:
 *     `TransverseMercator`, `UtmProjection`
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
module geodesy.projection.factors;

import geodesy.angle : Angle;
import geodesy.scalar : isGeodesyScalar;


/**
 * Meridian convergence and isotropic point scale of a conformal projection.
 *
 * `meridianConvergence` is the bearing of grid north measured clockwise
 * from true north. Positive values therefore denote a clockwise rotation
 * from true north to grid north.
 *
 * `pointScale` is dimensionless and strictly positive for a successfully
 * computed result.
 *
 * The default-initialized value has `pointScale == 0` and therefore does not
 * represent a successfully computed factor result.
 */
struct ConformalProjectionFactors(T)
if (isGeodesyScalar!T)
{
private:
    Angle!T _meridianConvergence;
    T _pointScale = 0;

package(geodesy):
    static ConformalProjectionFactors fromComponents(
        const Angle!T meridianConvergence,
        const T pointScale)
        pure nothrow @safe @nogc
    {
        ConformalProjectionFactors result;
        result._meridianConvergence = meridianConvergence;
        result._pointScale = pointScale;
        return result;
    }

public:
    /** Meridian convergence as a strongly typed angle. */
    @property Angle!T meridianConvergence() const
        pure nothrow @safe @nogc
    {
        return _meridianConvergence;
    }

    /** Dimensionless isotropic point scale. */
    @property T pointScale() const
        pure nothrow @safe @nogc
    {
        return _pointScale;
    }
}


@safe unittest
{
    static assert(is(ConformalProjectionFactors!float));
    static assert(is(ConformalProjectionFactors!double));
    static assert(is(ConformalProjectionFactors!real));

    const factors =
        ConformalProjectionFactors!double.fromComponents(
            Angle!double.fromDegrees(1.5),
            0.9996);

    assert(factors.meridianConvergence.degrees == 1.5);
    assert(factors.pointScale == 0.9996);

    const empty = ConformalProjectionFactors!double.init;
    assert(empty.meridianConvergence.radians == 0.0);
    assert(empty.pointScale == 0.0);
}
