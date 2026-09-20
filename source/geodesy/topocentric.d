/** Local topocentric East/North/Up coordinate types and operations. */
module geodesy.topocentric;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;


/**
 * A local topocentric Cartesian coordinate `(east, north, up)`.
 *
 * The type represents linear components only. It does not carry an origin,
 * ellipsoid, CRS, datum, or linear-unit tag. Interpretation requires a
 * separately prepared topocentric frame.
 *
 * `(0, 0, 0)` is a valid coordinate and is the `.init` value.
 */
struct TopocentricCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    T _east = 0;
    T _north = 0;
    T _up = 0;

    static TopocentricCoordinate fromComponentsUnchecked(
        const T east,
        const T north,
        const T up)
        pure nothrow @safe @nogc
    {
        TopocentricCoordinate result;
        result._east = east;
        result._north = north;
        result._up = up;
        return result;
    }

public:
    /** Construct from finite East/North/Up components without throwing. */
    static bool tryFromComponents(
        const T east,
        const T north,
        const T up,
        out TopocentricCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(east)
            || !isFiniteGeodesyScalar(north)
            || !isFiniteGeodesyScalar(up))
            return false;

        result =
            fromComponentsUnchecked(
                east,
                north,
                up);

        return true;
    }

    /**
     * Construct from East/North/Up components.
     *
     * Throws `GeodesyValueException` when any component is non-finite.
     */
    static TopocentricCoordinate fromComponents(
        const T east,
        const T north,
        const T up)
        @safe
    {
        TopocentricCoordinate result;

        if (!tryFromComponents(
            east,
            north,
            up,
            result))
        {
            throw new GeodesyValueException(
                "Topocentric coordinate components must be finite.");
        }

        return result;
    }

    /** East component in the frame linear unit. */
    @property T east() const
        pure nothrow @safe @nogc
    {
        return _east;
    }

    /** North component in the frame linear unit. */
    @property T north() const
        pure nothrow @safe @nogc
    {
        return _north;
    }

    /** Up component in the frame linear unit. */
    @property T up() const
        pure nothrow @safe @nogc
    {
        return _up;
    }
}


unittest
{
    import std.exception : assertThrown;

    static assert(is(TopocentricCoordinate!float));
    static assert(is(TopocentricCoordinate!double));
    static assert(is(TopocentricCoordinate!real));

    const zero =
        TopocentricCoordinate!double.init;

    assert(zero.east == 0.0);
    assert(zero.north == 0.0);
    assert(zero.up == 0.0);

    TopocentricCoordinate!double checked;

    assert(
        TopocentricCoordinate!double.tryFromComponents(
            1.0,
            -2.0,
            3.0,
            checked));

    assert(checked.east == 1.0);
    assert(checked.north == -2.0);
    assert(checked.up == 3.0);

    TopocentricCoordinate!double invalid;

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            double.nan,
            0.0,
            0.0,
            invalid));

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            0.0,
            double.infinity,
            0.0,
            invalid));

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            0.0,
            0.0,
            -double.infinity,
            invalid));

    assertThrown!GeodesyValueException(
        TopocentricCoordinate!double.fromComponents(
            double.nan,
            0.0,
            0.0));

    assertThrown!GeodesyValueException(
        TopocentricCoordinate!double.fromComponents(
            0.0,
            double.infinity,
            0.0));

    const floatCoordinate =
        TopocentricCoordinate!float.fromComponents(
            1.0f,
            2.0f,
            3.0f);

    assert(floatCoordinate.east == 1.0f);
    assert(floatCoordinate.north == 2.0f);
    assert(floatCoordinate.up == 3.0f);

    const realCoordinate =
        TopocentricCoordinate!real.fromComponents(
            1.0L,
            2.0L,
            3.0L);

    assert(realCoordinate.east == 1.0L);
    assert(realCoordinate.north == 2.0L);
    assert(realCoordinate.up == 3.0L);
}
