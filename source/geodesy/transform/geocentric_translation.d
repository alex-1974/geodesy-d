/** EPSG method 1031: Geocentric translations (geocentric domain). */
module geodesy.transform.geocentric_translation;

import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;


/**
 * Translation parameters from a source geocentric frame to a target
 * geocentric frame.
 *
 * All three values use the same linear unit as the source and target
 * geocentric coordinates.
 *
 * `.init` is the identity transformation.
 */
struct GeocentricTranslation(T)
if (isGeodesyScalar!T)
{
private:
    T _deltaX = cast(T) 0;
    T _deltaY = cast(T) 0;
    T _deltaZ = cast(T) 0;

public:
    /** X-axis translation in the coordinate linear unit. */
    @property T deltaX() const pure nothrow @safe @nogc
    {
        return _deltaX;
    }

    /** Y-axis translation in the coordinate linear unit. */
    @property T deltaY() const pure nothrow @safe @nogc
    {
        return _deltaY;
    }

    /** Z-axis translation in the coordinate linear unit. */
    @property T deltaZ() const pure nothrow @safe @nogc
    {
        return _deltaZ;
    }

    /**
     * Checked non-throwing construction.
     *
     * Returns false when any parameter is NaN or infinite.
     */
    static bool tryFromComponents(
        const T deltaX,
        const T deltaY,
        const T deltaZ,
        out GeocentricTranslation!T result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(deltaX)
            || !isFiniteGeodesyScalar(deltaY)
            || !isFiniteGeodesyScalar(deltaZ))
            return false;

        result._deltaX = deltaX;
        result._deltaY = deltaY;
        result._deltaZ = deltaZ;
        return true;
    }

    /** Throwing convenience constructor. */
    static GeocentricTranslation!T fromComponents(
        const T deltaX,
        const T deltaY,
        const T deltaZ)
        @safe
    {
        GeocentricTranslation!T result;
        if (!tryFromComponents(deltaX, deltaY, deltaZ, result))
            throw new GeodesyValueException(
                "Geocentric translation parameters must be finite.");
        return result;
    }

    /**
     * Return the exact inverse parameterization.
     *
     * EPSG method 1031 is reversible by changing the signs of dX/dY/dZ.
     */
    GeocentricTranslation!T inverse() const
        pure nothrow @safe @nogc
    {
        GeocentricTranslation!T result;
        result._deltaX = -_deltaX;
        result._deltaY = -_deltaY;
        result._deltaZ = -_deltaZ;
        return result;
    }
}


/**
 * Apply EPSG method 1031:
 *
 *   Xt = Xs + dX
 *   Yt = Ys + dY
 *   Zt = Zs + dZ
 *
 * Returns false only if finite inputs overflow to a non-finite result in T.
 */
bool tryApplyGeocentricTranslation(T)(
    const GeocentricCoordinate!T source,
    const GeocentricTranslation!T translation,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return GeocentricCoordinate!T.tryFromComponents(
        source.x + translation.deltaX,
        source.y + translation.deltaY,
        source.z + translation.deltaZ,
        result);
}


/** Throwing convenience wrapper for `tryApplyGeocentricTranslation`. */
GeocentricCoordinate!T applyGeocentricTranslation(T)(
    const GeocentricCoordinate!T source,
    const GeocentricTranslation!T translation)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryApplyGeocentricTranslation(source, translation, result))
        throw new GeodesyValueException(
            "Geocentric translation produced a non-finite result.");
    return result;
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    bool near(const double actual, const double expected, const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // EPSG Guidance Note 7-2 / method 1031 worked North Sea example.
    const source = GeocentricCoordinate!double.fromComponents(
        3_771_793.97,
          140_253.34,
        5_124_304.35);

    const shift = GeocentricTranslation!double.fromComponents(
         84.87,
         96.49,
        116.95);

    const target = applyGeocentricTranslation(source, shift);

    assert(near(target.x, 3_771_878.84, 1e-9));
    assert(near(target.y,   140_349.83, 1e-9));
    assert(near(target.z, 5_124_421.30, 1e-9));

    // EPSG reversibility rule: change the signs of all three translations.
    const recovered = applyGeocentricTranslation(target, shift.inverse());

    assert(near(recovered.x, source.x, 1e-9));
    assert(near(recovered.y, source.y, 1e-9));
    assert(near(recovered.z, source.z, 1e-9));

    // The default parameter value is deliberately the identity transform.
    const identity = applyGeocentricTranslation(
        source,
        GeocentricTranslation!double.init);
    assert(identity == source);

    // Generic instantiation.
    const floatTarget = applyGeocentricTranslation(
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f),
        GeocentricTranslation!float.fromComponents(4.0f, 5.0f, 6.0f));
    assert(floatTarget == GeocentricCoordinate!float.fromComponents(
        5.0f, 7.0f, 9.0f));

    const realTarget = applyGeocentricTranslation(
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L),
        GeocentricTranslation!real.fromComponents(4.0L, 5.0L, 6.0L));
    assert(realTarget == GeocentricCoordinate!real.fromComponents(
        5.0L, 7.0L, 9.0L));

    // Checked parameter validation.
    GeocentricTranslation!double invalidTranslation;
    assert(!GeocentricTranslation!double.tryFromComponents(
        double.nan, 0.0, 0.0, invalidTranslation));
    assertThrown!GeodesyValueException(
        GeocentricTranslation!double.fromComponents(
            double.nan, 0.0, 0.0));

    // Finite values may still overflow during application.
    const huge = GeocentricCoordinate!double.fromComponents(
        double.max, 0.0, 0.0);
    const positive = GeocentricTranslation!double.fromComponents(
        double.max, 0.0, 0.0);
    GeocentricCoordinate!double candidate;
    assert(!tryApplyGeocentricTranslation(
        huge, positive, candidate));
    assertThrown!GeodesyValueException(
        applyGeocentricTranslation(huge, positive));
}
