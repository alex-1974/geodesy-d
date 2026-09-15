/** Canonical two-dimensional projected coordinate value type. */
module geodesy.projected;

import geodesy.errors : GeodesyValueException;
import geodesy.scalar : isGeodesyScalar, isFiniteGeodesyScalar;


/**
 * A canonical projected coordinate represented as easting and northing.
 *
 * The linear unit is not encoded in the type. Both components must use the
 * same linear unit as the projection operation that consumes or produced the
 * value.
 *
 * This value deliberately carries no CRS, axis-order, or unit metadata.
 */
struct ProjectedCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    T _easting = 0;
    T _northing = 0;

public:
    /** Construct from finite easting and northing without throwing. */
    static bool tryFromComponents(
        const T easting,
        const T northing,
        out ProjectedCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(easting)
            || !isFiniteGeodesyScalar(northing))
            return false;

        result._easting = easting;
        result._northing = northing;
        return true;
    }

    /** Construct from finite easting and northing or throw. */
    static ProjectedCoordinate fromComponents(
        const T easting,
        const T northing)
        @safe
    {
        ProjectedCoordinate result;
        if (!tryFromComponents(easting, northing, result))
            throw new GeodesyValueException(
                "Projected coordinate components must be finite.");
        return result;
    }

    /** Easting in the operation's linear unit. */
    @property T easting() const pure nothrow @safe @nogc
    {
        return _easting;
    }

    /** Northing in the operation's linear unit. */
    @property T northing() const pure nothrow @safe @nogc
    {
        return _northing;
    }
}


unittest
{
    import std.exception : assertThrown;

    static assert(is(ProjectedCoordinate!float));
    static assert(is(ProjectedCoordinate!double));
    static assert(is(ProjectedCoordinate!real));

    const p = ProjectedCoordinate!double.fromComponents(500_000.0, 5_340_000.0);
    assert(p.easting == 500_000.0);
    assert(p.northing == 5_340_000.0);

    ProjectedCoordinate!double candidate;
    assert(!ProjectedCoordinate!double.tryFromComponents(
        double.nan, 0.0, candidate));
    assert(!ProjectedCoordinate!double.tryFromComponents(
        0.0, double.infinity, candidate));

    assertThrown!GeodesyValueException(
        ProjectedCoordinate!double.fromComponents(double.nan, 0.0));
}
