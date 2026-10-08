/**
 * Reference ellipsoid value type, construction, and derived parameters.
 *
 * Ellipsoid makes the reference surface an explicit value instead of hidden
 * global state. It supports spherical and oblate models, preserves the
 * caller-selected linear unit of the semi-major axis, and deliberately gives
 * `.init` an invalid state so accidental default construction cannot silently
 * select a plausible Earth model.
 *
 * Domain:
 *     General ellipsoid construction accepts finite `a > 0` and
 *     `0 <= f < 1`. Individual numerical operations may intentionally impose
 *     narrower documented domains.
 *
 * Units:
 *     Axis values retain the caller-selected linear unit. Operations combining
 *     coordinates or heights with an ellipsoid require compatible linear units.
 *
 * Performance:
 *     Construction and derived-parameter access require no allocation.
 *
 * See_Also:
 *     `wgs84`, `GeodeticCoordinate`, `Geodesic`,
 *     `TransverseMercator`
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
module geodesy.ellipsoid;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


/**
 * A spherical or oblate reference ellipsoid stored canonically as semi-major
 * axis `a` and flattening `f`.
 *
 * The semi-major axis defines the caller-selected linear unit. Operations
 * combining an ellipsoid with heights or Cartesian coordinates require those
 * values to use the same linear unit. `Ellipsoid.init` is intentionally
 * invalid so accidental default construction cannot silently select a
 * plausible Earth model.
 *
 * General construction accepts finite `a > 0` and `0 <= f < 1`.
 * `fromInverseFlattening` requires a finite inverse flattening greater than
 * one; construct spheres explicitly with `sphere`.
 *
 * Checked factories return `false` for invalid parameters. Their throwing
 * peers throw `GeodesyValueException`. Derived properties do not allocate.
 *
 */
struct Ellipsoid(T)
if (isGeodesyScalar!T)
{
private:
    /*
     * `.init` is intentionally invalid.
     *
     * A silently valid default ellipsoid is dangerous: accidental default
     * construction could otherwise produce finite, plausible, but physically
     * meaningless geodetic results. All public factories construct valid
     * ellipsoids explicitly.
     */
    T _semiMajorAxis = T.nan;
    T _flattening = T.nan;

    /** Construct an ellipsoid from already validated canonical axis/flattening values. */
static Ellipsoid fromCanonicalUnchecked(const T semiMajorAxis, const T flattening)
        pure nothrow @safe @nogc
    {
        Ellipsoid result;
        result._semiMajorAxis = semiMajorAxis;
        result._flattening = flattening;
        return result;
    }

public:
    /**
     * True when this value represents a finite rotational ellipsoid.
     * Negative flattening denotes a prolate ellipsoid.
     *
     * In particular, `Ellipsoid!T.init.isValid` is false.
     */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return isFiniteGeodesyScalar(_semiMajorAxis)
            && _semiMajorAxis > cast(T) 0
            && isFiniteGeodesyScalar(_flattening)
            && _flattening > cast(T) -1
            && _flattening < cast(T) 1;
    }

    /// Example checking whether an ellipsoid was explicitly constructed.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().isValid);
        assert(!Ellipsoid!double.init.isValid);
    }

    /**
     * Construct from semi-major axis and flattening without throwing.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis in the caller-selected linear unit.
     *     flattening = Finite flattening in the interval -1 < f < 1.
     *     result = Receives the constructed ellipsoid on success.
     *
     * Returns:
     *     `true` on success; `false` for invalid parameters. On failure
     *     `result` is initialized to `.init` on entry and has no guaranteed value on failure.
     */
    static bool tryFromFlattening(
        const T semiMajorAxis,
        const T flattening,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(semiMajorAxis) || semiMajorAxis <= 0)
            return false;
        if (!isFiniteGeodesyScalar(flattening) || flattening <= -1 || flattening >= 1)
            return false;

        result = fromCanonicalUnchecked(semiMajorAxis, flattening);
        return true;
    }

    /// Example checking ellipsoid construction from flattening.
    @safe unittest
    {
        import geodesy;
        Ellipsoid!double ellipsoid;
        assert(Ellipsoid!double.tryFromFlattening(
            6_378_137.0, 1.0 / 298.257223563, ellipsoid));
        assert(ellipsoid.isValid);
    }

    /**
     * Construct from semi-major axis and flattening or throw on invalid parameters.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis in the caller-selected linear unit.
     *     flattening = Finite flattening in the interval 0 <= f < 1.
     *
     * Returns:
     *     The constructed rotational ellipsoid.
     *
     * Throws:
     *     `GeodesyValueException` for invalid parameters.
     */
    static Ellipsoid fromFlattening(const T semiMajorAxis, const T flattening)
        @safe
    {
        Ellipsoid result;
        if (!tryFromFlattening(semiMajorAxis, flattening, result))
            throw new GeodesyValueException(
                "Ellipsoid requires finite a > 0 and finite flattening -1 < f < 1.");
        return result;
    }

    /// Example constructing an ellipsoid from flattening.
    @safe unittest
    {
        import geodesy;
        const ellipsoid = Ellipsoid!double.fromFlattening(
            6_378_137.0, 1.0 / 298.257223563);
        assert(ellipsoid.isValid);
    }

    /**
     * Construct from semi-major axis and inverse flattening without throwing.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis in the caller-selected linear unit.
     *     inverseFlattening = Finite inverse flattening less than zero for prolate ellipsoids or greater than one for oblate ellipsoids.
     *     result = Receives the constructed ellipsoid on success.
     *
     * Returns:
     *     `true` on success; `false` for invalid parameters. Spheres are
     *     intentionally not represented by infinite inverse flattening; use
     *     `trySphere`. On failure `result` is initialized to `.init` on entry and has no guaranteed value on failure.
     */
    static bool tryFromInverseFlattening(
        const T semiMajorAxis,
        const T inverseFlattening,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(inverseFlattening)
            || inverseFlattening == 0
            || (inverseFlattening > 0 && inverseFlattening <= 1))
            return false;
        return tryFromFlattening(
            semiMajorAxis,
            cast(T) 1 / inverseFlattening,
            result);
    }

    /// Example checking construction from inverse flattening.
    @safe unittest
    {
        import geodesy;
        Ellipsoid!double ellipsoid;
        assert(Ellipsoid!double.tryFromInverseFlattening(
            6_378_137.0, 298.257223563, ellipsoid));
        assert(ellipsoid.inverseFlattening > 298.0);
    }

    /**
     * Construct from semi-major axis and inverse flattening or throw on invalid parameters.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis in the caller-selected linear unit.
     *     inverseFlattening = Finite inverse flattening greater than one.
     *
     * Returns:
     *     The constructed rotational ellipsoid.
     *
     * Throws:
     *     `GeodesyValueException` for invalid parameters. Use `sphere` for a sphere.
     */
    static Ellipsoid fromInverseFlattening(
        const T semiMajorAxis,
        const T inverseFlattening)
        @safe
    {
        Ellipsoid result;
        if (!tryFromInverseFlattening(semiMajorAxis, inverseFlattening, result))
            throw new GeodesyValueException(
                "Inverse flattening must be finite and either negative or greater than 1; use sphere(radius) for a sphere.");
        return result;
    }

    /// Example constructing WGS 84 from inverse flattening.
    @safe unittest
    {
        import geodesy;
        const ellipsoid = Ellipsoid!double.fromInverseFlattening(
            6_378_137.0, 298.257223563);
        assert(ellipsoid.semiMajorAxis == 6_378_137.0);
    }

    /**
     * Construct from semi-major and semi-minor axes without throwing.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis.
     *     semiMinorAxis = Finite positive polar semi-axis in the same linear unit. Values greater than `semiMajorAxis` construct a prolate ellipsoid.
     *     result = Receives the constructed ellipsoid on success.
     *
     * Returns:
     *     `true` on success; `false` for invalid axes. Equal axes construct
     *     a sphere. On failure `result` is initialized to `.init` on entry and has no guaranteed value on failure.
     */
    static bool tryFromAxes(
        const T semiMajorAxis,
        const T semiMinorAxis,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(semiMajorAxis) || semiMajorAxis <= 0)
            return false;
        if (!isFiniteGeodesyScalar(semiMinorAxis) || semiMinorAxis <= 0)
            return false;

        const T flattening = (semiMajorAxis - semiMinorAxis) / semiMajorAxis;
        return tryFromFlattening(semiMajorAxis, flattening, result);
    }

    /// Example checking construction from semi-major and semi-minor axes.
    @safe unittest
    {
        import geodesy;
        Ellipsoid!double ellipsoid;
        assert(Ellipsoid!double.tryFromAxes(
            6_378_137.0, 6_356_752.314245, ellipsoid));
        assert(ellipsoid.semiMinorAxis < ellipsoid.semiMajorAxis);
    }

    /**
     * Construct from semi-major and semi-minor axes or throw on invalid parameters.
     *
     * Params:
     *     semiMajorAxis = Finite positive semi-major axis.
     *     semiMinorAxis = Finite positive semi-minor axis in the same linear unit,
     *         with semiMinorAxis <= semiMajorAxis.
     *
     * Returns:
     *     The constructed rotational ellipsoid.
     *
     * Throws:
     *     `GeodesyValueException` for invalid axes.
     */
    static Ellipsoid fromAxes(const T semiMajorAxis, const T semiMinorAxis)
        @safe
    {
        Ellipsoid result;
        if (!tryFromAxes(semiMajorAxis, semiMinorAxis, result))
            throw new GeodesyValueException(
                "Ellipsoid axes must be finite with a > 0, b > 0, and -1 < (a-b)/a < 1.");
        return result;
    }

    /// Example constructing an ellipsoid from its axes.
    @safe unittest
    {
        import geodesy;
        const ellipsoid = Ellipsoid!double.fromAxes(
            6_378_137.0, 6_356_752.314245);
        assert(ellipsoid.isValid);
    }

    /**
     * Construct a sphere without throwing; radius must be finite and positive.
     *
     * Params:
     *     radius = Finite positive radius in the caller-selected linear unit.
     *     result = Receives the constructed sphere on success.
     *
     * Returns:
     *     `true` on success; `false` for a non-positive or non-finite radius.
     *     On failure `result` is initialized to `.init` on entry and has no guaranteed value on failure.
     */
    static bool trySphere(const T radius, out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        return tryFromFlattening(radius, cast(T) 0, result);
    }

    /// Example checking spherical construction without throwing.
    @safe unittest
    {
        import geodesy;
        Ellipsoid!double sphere;
        assert(Ellipsoid!double.trySphere(6_371_000.0, sphere));
        assert(sphere.flattening == 0.0);
    }

    /**
     * Construct a sphere or throw when the radius is invalid.
     *
     * Params:
     *     radius = Finite positive radius in the caller-selected linear unit.
     *
     * Returns:
     *     The constructed sphere with zero flattening.
     *
     * Throws:
     *     `GeodesyValueException` for a non-positive or non-finite radius.
     */
    static Ellipsoid sphere(const T radius)
        @safe
    {
        Ellipsoid result;
        if (!trySphere(radius, result))
            throw new GeodesyValueException("Sphere radius must be finite and greater than zero.");
        return result;
    }

    /// Example constructing a spherical Earth model.
    @safe unittest
    {
        import geodesy;
        const sphere = Ellipsoid!double.sphere(6_371_000.0);
        assert(sphere.semiMajorAxis == sphere.semiMinorAxis);
    }

    /** Canonical equatorial semi-axis `a` in the ellipsoid linear unit.
     *
     * The historic `semiMajorAxis` name is retained for API compatibility.
     * For prolate ellipsoids `a` is geometrically the smaller semi-axis.
     */
    @property T semiMajorAxis() const pure nothrow @safe @nogc
    {
        return _semiMajorAxis;
    }

    /** Equatorial radius alias for the canonical semi-axis `a`. */
    @property T equatorialRadius() const pure nothrow @safe @nogc
    {
        return _semiMajorAxis;
    }

    /// Example reading the semi-major axis.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().semiMajorAxis == 6_378_137.0);
    }

    /** Flattening `f`. */
    @property T flattening() const pure nothrow @safe @nogc
    {
        return _flattening;
    }

    /// Example reading flattening.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().flattening > 0.0);
    }

    /** Derived polar semi-axis `b = a(1-f)`.
     *
     * The historic `semiMinorAxis` name is retained for API compatibility.
     * For prolate ellipsoids `b > a`.
     */
    @property T semiMinorAxis() const pure nothrow @safe @nogc
    {
        return _semiMajorAxis * (cast(T) 1 - _flattening);
    }

    /** Polar radius alias for the derived semi-axis `b = a(1-f)`. */
    @property T polarRadius() const pure nothrow @safe @nogc
    {
        return semiMinorAxis;
    }

    /// Example reading the derived semi-minor axis.
    @safe unittest
    {
        import geodesy;
        const earth = wgs84!double();
        assert(earth.semiMinorAxis < earth.semiMajorAxis);
    }

    /** Derived inverse flattening `1/f`; infinity for a sphere. */
    @property T inverseFlattening() const pure nothrow @safe @nogc
    {
        return _flattening == 0 ? T.infinity : cast(T) 1 / _flattening;
    }

    /// Example reading inverse flattening.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().inverseFlattening > 298.0);
    }

    /** Signed first eccentricity squared `e² = f(2-f)`; negative for prolate ellipsoids. */
    @property T firstEccentricitySquared() const pure nothrow @safe @nogc
    {
        return _flattening * (cast(T) 2 - _flattening);
    }

    /// Example reading first eccentricity squared.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().firstEccentricitySquared > 0.0);
    }

    /** Signed second eccentricity squared (e′²); negative for prolate ellipsoids. */
    @property T secondEccentricitySquared() const pure nothrow @safe @nogc
    {
        const T e2 = firstEccentricitySquared;
        return e2 / (cast(T) 1 - e2);
    }

    /// Example reading second eccentricity squared.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().secondEccentricitySquared > 0.0);
    }

    /** Signed third flattening `n = f/(2-f)`. */
    @property T thirdFlattening() const pure nothrow @safe @nogc
    {
        return _flattening / (cast(T) 2 - _flattening);
    }

    /// Example reading the third flattening.
    @safe unittest
    {
        import geodesy;
        assert(wgs84!double().thirdFlattening > 0.0);
    }
}

/// Prolate rotational ellipsoids are representable independently of geodesic admission.
@safe unittest
{
    import geodesy;

    const prolate = Ellipsoid!double.fromFlattening(
        6_378_137.0,
        -0.01);

    assert(prolate.isValid);
    assert(prolate.flattening < 0.0);
    assert(prolate.polarRadius > prolate.equatorialRadius);
    assert(prolate.semiMinorAxis > prolate.semiMajorAxis);
    assert(prolate.firstEccentricitySquared < 0.0);
    assert(prolate.secondEccentricitySquared < 0.0);
    assert(prolate.thirdFlattening < 0.0);

    const fromInverse = Ellipsoid!double.fromInverseFlattening(
        6_378_137.0,
        -100.0);

    assert(fromInverse.flattening == -0.01);

    const fromAxes = Ellipsoid!double.fromAxes(
        6_378_137.0,
        6_441_918.37);

    assert(fromAxes.flattening < 0.0);
}

/// Example constructing Earth and spherical ellipsoids.
@safe unittest
{
    import geodesy;
    
    const earth = wgs84!double();
    assert(earth.isValid);
    assert(earth.semiMajorAxis == 6_378_137.0);
    
    const sphere = Ellipsoid!double.sphere(6_371_000.0);
    assert(sphere.flattening == 0.0);
    assert(sphere.semiMinorAxis == sphere.semiMajorAxis);
    
    assert(!Ellipsoid!double.init.isValid);
    
}


/**
 * WGS 84 reference ellipsoid, parameterized to the requested floating-point
 * scalar.
 *
 * The semi-major axis is 6,378,137 metres and the inverse flattening is
 * 298.257223563. Therefore values combined with this supplied ellipsoid use
 * metres for their linear coordinates.
 *
 * Returns:
 *     A valid WGS 84 `Ellipsoid!T`.
 */
Ellipsoid!T wgs84(T = double)() pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    // EPSG ellipsoid 7030 / WGS 84: a = 6378137 m, 1/f = 298.257223563.
    return Ellipsoid!T.fromCanonicalUnchecked(
        cast(T) 6_378_137.0,
        cast(T) (1.0L / 298.257223563L));
}

/// Example obtaining the supplied WGS 84 ellipsoid.
@safe unittest
{
    import geodesy;
    const earth = wgs84!double();
    assert(earth.semiMajorAxis == 6_378_137.0);
}

unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    static assert(is(Ellipsoid!float));
    static assert(is(Ellipsoid!double));
    static assert(is(Ellipsoid!real));

    const invalid = Ellipsoid!double.init;
    assert(!invalid.isValid);
    assert(invalid.semiMajorAxis != invalid.semiMajorAxis);
    assert(invalid.flattening != invalid.flattening);

    const earth = wgs84!double();
    assert(earth.isValid);
    assert(earth.semiMajorAxis == 6_378_137.0);
    assert(fabs(earth.inverseFlattening - 298.257223563) < 1e-10);
    assert(fabs(earth.semiMinorAxis - 6_356_752.314245179) < 1e-6);

    const sphere = Ellipsoid!double.sphere(6_371_000.0);
    assert(sphere.isValid);
    assert(sphere.flattening == 0);
    assert(sphere.semiMinorAxis == sphere.semiMajorAxis);
    assert(sphere.inverseFlattening == double.infinity);

    Ellipsoid!double candidate;
    assert(!Ellipsoid!double.tryFromFlattening(0.0, 0.1, candidate));
    assert(!Ellipsoid!double.tryFromFlattening(1.0, 1.0, candidate));
    assert(!Ellipsoid!double.tryFromInverseFlattening(1.0, double.infinity, candidate));
    assertThrown!GeodesyValueException(Ellipsoid!double.fromAxes(1.0, 2.0));
}
