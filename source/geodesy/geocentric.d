/** Geocentric Cartesian coordinate value type. */
module geodesy.geocentric;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;

/**
 * A geocentric Cartesian coordinate `(x, y, z)`.
 *
 * The type does not encode a CRS, datum, ellipsoid, or linear unit. When used
 * with an ellipsoid, all three components and the ellipsoid axes must use the
 * same linear unit.
 *
 * `(0, 0, 0)` is representable. Whether a mathematical operation is defined
 * at the geocentre is the responsibility of that operation.
 */
struct GeocentricCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    T _x = 0;
    T _y = 0;
    T _z = 0;

    static GeocentricCoordinate fromComponentsUnchecked(
        const T x,
        const T y,
        const T z)
        pure nothrow @safe @nogc
    {
        GeocentricCoordinate result;
        result._x = x;
        result._y = y;
        result._z = z;
        return result;
    }

public:
    /** Construct from finite X/Y/Z components without throwing. */
    static bool tryFromComponents(
        const T x,
        const T y,
        const T z,
        out GeocentricCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(x)
            || !isFiniteGeodesyScalar(y)
            || !isFiniteGeodesyScalar(z))
            return false;

        result = fromComponentsUnchecked(x, y, z);
        return true;
    }

    /** Construct from X/Y/Z or throw when any component is non-finite. */
    static GeocentricCoordinate fromComponents(const T x, const T y, const T z)
        @safe
    {
        GeocentricCoordinate result;
        if (!tryFromComponents(x, y, z, result))
            throw new GeodesyValueException("Geocentric coordinate components must be finite.");
        return result;
    }

    /** Geocentric X component. */
    @property T x() const pure nothrow @safe @nogc { return _x; }
    /** Geocentric Y component. */
    @property T y() const pure nothrow @safe @nogc { return _y; }
    /** Geocentric Z component. */
    @property T z() const pure nothrow @safe @nogc { return _z; }
}

unittest
{
    import std.exception : assertThrown;

    static assert(is(GeocentricCoordinate!float));
    static assert(is(GeocentricCoordinate!double));
    static assert(is(GeocentricCoordinate!real));

    const p = GeocentricCoordinate!double.fromComponents(
        4_085_000.0, 1_260_000.0, 4_717_000.0);
    assert(p.x == 4_085_000.0);
    assert(p.y == 1_260_000.0);
    assert(p.z == 4_717_000.0);

    const origin = GeocentricCoordinate!double.init;
    assert(origin.x == 0.0 && origin.y == 0.0 && origin.z == 0.0);

    GeocentricCoordinate!double candidate;
    assert(!GeocentricCoordinate!double.tryFromComponents(
        0.0, double.nan, 0.0, candidate));
    assertThrown!GeodesyValueException(
        GeocentricCoordinate!double.fromComponents(0.0, 0.0, double.infinity));
}
