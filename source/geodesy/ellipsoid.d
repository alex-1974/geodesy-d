/** Reference ellipsoid value type and derived parameters. */
module geodesy.ellipsoid;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


/** A spherical or oblate reference ellipsoid stored canonically as (a, f). */
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
     * True when this value represents a supported spherical or oblate
     * ellipsoid.
     *
     * In particular, `Ellipsoid!T.init.isValid` is false.
     */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return isFiniteGeodesyScalar(_semiMajorAxis)
            && _semiMajorAxis > cast(T) 0
            && isFiniteGeodesyScalar(_flattening)
            && _flattening >= cast(T) 0
            && _flattening < cast(T) 1;
    }

    /** Construct from semi-major axis and flattening without throwing. */
    static bool tryFromFlattening(
        const T semiMajorAxis,
        const T flattening,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(semiMajorAxis) || semiMajorAxis <= 0)
            return false;
        if (!isFiniteGeodesyScalar(flattening) || flattening < 0 || flattening >= 1)
            return false;

        result = fromCanonicalUnchecked(semiMajorAxis, flattening);
        return true;
    }

    /** Construct from semi-major axis and flattening or throw on invalid parameters. */
    static Ellipsoid fromFlattening(const T semiMajorAxis, const T flattening)
        @safe
    {
        Ellipsoid result;
        if (!tryFromFlattening(semiMajorAxis, flattening, result))
            throw new GeodesyValueException(
                "Ellipsoid requires finite a > 0 and finite flattening 0 <= f < 1.");
        return result;
    }

    /** Construct from semi-major axis and inverse flattening without throwing. */
    static bool tryFromInverseFlattening(
        const T semiMajorAxis,
        const T inverseFlattening,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(inverseFlattening) || inverseFlattening <= 1)
            return false;
        return tryFromFlattening(
            semiMajorAxis,
            cast(T) 1 / inverseFlattening,
            result);
    }

    /** Construct from semi-major axis and inverse flattening or throw on invalid parameters. */
    static Ellipsoid fromInverseFlattening(
        const T semiMajorAxis,
        const T inverseFlattening)
        @safe
    {
        Ellipsoid result;
        if (!tryFromInverseFlattening(semiMajorAxis, inverseFlattening, result))
            throw new GeodesyValueException(
                "Inverse flattening must be finite and greater than 1; use sphere(radius) for a sphere.");
        return result;
    }

    /** Construct from semi-major and semi-minor axes without throwing. */
    static bool tryFromAxes(
        const T semiMajorAxis,
        const T semiMinorAxis,
        out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(semiMajorAxis) || semiMajorAxis <= 0)
            return false;
        if (!isFiniteGeodesyScalar(semiMinorAxis) || semiMinorAxis <= 0 || semiMinorAxis > semiMajorAxis)
            return false;

        const T flattening = (semiMajorAxis - semiMinorAxis) / semiMajorAxis;
        return tryFromFlattening(semiMajorAxis, flattening, result);
    }

    /** Construct from semi-major and semi-minor axes or throw on invalid parameters. */
    static Ellipsoid fromAxes(const T semiMajorAxis, const T semiMinorAxis)
        @safe
    {
        Ellipsoid result;
        if (!tryFromAxes(semiMajorAxis, semiMinorAxis, result))
            throw new GeodesyValueException(
                "Ellipsoid axes must be finite with a > 0 and 0 < b <= a.");
        return result;
    }

    /** Construct a sphere without throwing; radius must be finite and positive. */
    static bool trySphere(const T radius, out Ellipsoid result)
        pure nothrow @safe @nogc
    {
        return tryFromFlattening(radius, cast(T) 0, result);
    }

    /** Construct a sphere or throw when the radius is invalid. */
    static Ellipsoid sphere(const T radius)
        @safe
    {
        Ellipsoid result;
        if (!trySphere(radius, result))
            throw new GeodesyValueException("Sphere radius must be finite and greater than zero.");
        return result;
    }

    /** Semi-major axis `a` in the ellipsoid linear unit. */
    @property T semiMajorAxis() const pure nothrow @safe @nogc
    {
        return _semiMajorAxis;
    }

    /** Flattening `f`. */
    @property T flattening() const pure nothrow @safe @nogc
    {
        return _flattening;
    }

    /** Derived semi-minor axis `b = a(1-f)`. */
    @property T semiMinorAxis() const pure nothrow @safe @nogc
    {
        return _semiMajorAxis * (cast(T) 1 - _flattening);
    }

    /** Derived inverse flattening `1/f`; infinity for a sphere. */
    @property T inverseFlattening() const pure nothrow @safe @nogc
    {
        return _flattening == 0 ? T.infinity : cast(T) 1 / _flattening;
    }

    /** First eccentricity squared `e²`. */
    @property T firstEccentricitySquared() const pure nothrow @safe @nogc
    {
        return _flattening * (cast(T) 2 - _flattening);
    }

    /** Second eccentricity squared `e'²`. */
    @property T secondEccentricitySquared() const pure nothrow @safe @nogc
    {
        const T e2 = firstEccentricitySquared;
        return e2 / (cast(T) 1 - e2);
    }

    /** Third flattening `n = f/(2-f)`. */
    @property T thirdFlattening() const pure nothrow @safe @nogc
    {
        return _flattening / (cast(T) 2 - _flattening);
    }
}

/** WGS 84 reference ellipsoid, parameterized to the requested floating-point scalar. */
Ellipsoid!T wgs84(T = double)() pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    // EPSG ellipsoid 7030 / WGS 84: a = 6378137 m, 1/f = 298.257223563.
    return Ellipsoid!T.fromCanonicalUnchecked(
        cast(T) 6_378_137.0,
        cast(T) (1.0L / 298.257223563L));
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
