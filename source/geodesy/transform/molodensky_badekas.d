/**
 * Convert Earth-centred XYZ coordinates between frames using a local pivot.
 *
 * Use Molodensky-Badekas when a published reference-frame conversion
 * supplies seven Helmert-like parameters plus an evaluation point
 * (Xp, Yp, Zp). The evaluation point acts as the local centre for the
 * rotation and scale. Use Helmert7 instead when no evaluation point is
 * part of the published transformation.
 *
 * Standards:
 *     EPSG method 1061 -- Position Vector, geocentric domain.
 *     EPSG method 1034 -- Coordinate Frame, geocentric domain.
 *
 * Architecture:
 *     Construction derives the mathematically equivalent existing Helmert7
 *     source-to-target transform once. Per-coordinate application delegates to
 *     the qualified Helmert kernel; no second spatial rotation matrix exists.
 *
 * Units:
 *     Translations and evaluation-point ordinates use the geocentric coordinate
 *     linear unit. Canonical rotations use radians through Angle!T and scale
 *     difference is dimensionless. The EPSG interchange factory accepts
 *     arc-seconds and parts per million.
 *
 * Reversibility:
 *     No inverse convenience API is exposed. The evaluation point belongs to
 *     the forward source Cartesian CRS, so the same ten parameter values are
 *     not in general an exact reverse transformation.
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
 *     October 7, 2026
 */
module geodesy.transform.molodensky_badekas;

import geodesy.angle : Angle;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;
import geodesy.transform.helmert :
    Helmert7,
    HelmertConvention,
    PositionVectorHelmert,
    CoordinateFrameHelmert,
    tryApplyPositionVectorHelmert,
    tryApplyCoordinateFrameHelmert,
    toCoordinateFrame,
    toPositionVector;


/**
 * Ten source-to-target Molodensky-Badekas parameters with rotation convention
 * encoded in the type.
 *
 * The first seven parameters retain the existing Helmert7 semantics. The
 * additional three values are the source-geocentric coordinates of the
 * evaluation point about which rotation and scale are applied.
 *
 * \`.init\` is the identity transformation: Helmert identity parameters and an
 * evaluation point at the geocentric origin.
 */
struct MolodenskyBadekas10(T, HelmertConvention convention)
if (isGeodesyScalar!T)
{
private:
    Helmert7!(T, convention) _baseParameters;
    T _evaluationPointX = cast(T) 0;
    T _evaluationPointY = cast(T) 0;
    T _evaluationPointZ = cast(T) 0;
    Helmert7!(T, convention) _equivalentHelmert;

public:
    /** Original seven convention-specific Helmert-family parameters. */
    @property Helmert7!(T, convention) baseParameters() const
        pure nothrow @safe @nogc
    {
        return _baseParameters;
    }

    /// Example reading the base Helmert-family parameters.
    @safe unittest
    {
        import geodesy;
        assert(PositionVectorMolodenskyBadekas!double.init
            .baseParameters == PositionVectorHelmert!double.init);
    }

    /** Source-geocentric X ordinate of the evaluation point. */
    @property T evaluationPointX() const pure nothrow @safe @nogc
    {
        return _evaluationPointX;
    }

    /// Example reading the X evaluation-point ordinate.
    @safe unittest
    {
        import geodesy;
        assert(PositionVectorMolodenskyBadekas!double.init.evaluationPointX == 0.0);
    }

    /** Source-geocentric Y ordinate of the evaluation point. */
    @property T evaluationPointY() const pure nothrow @safe @nogc
    {
        return _evaluationPointY;
    }

    /// Example reading the Y evaluation-point ordinate.
    @safe unittest
    {
        import geodesy;
        assert(PositionVectorMolodenskyBadekas!double.init.evaluationPointY == 0.0);
    }

    /** Source-geocentric Z ordinate of the evaluation point. */
    @property T evaluationPointZ() const pure nothrow @safe @nogc
    {
        return _evaluationPointZ;
    }

    /// Example reading the Z evaluation-point ordinate.
    @safe unittest
    {
        import geodesy;
        assert(PositionVectorMolodenskyBadekas!double.init.evaluationPointZ == 0.0);
    }

    /**
     * Equivalent forward Helmert7 transform.
     *
     * For fixed P, t, M and R:
     *
     * ---
     * p + t + M R (x - p)
     * = M R x + (p + t - M R p)
     * ---
     */
    @property Helmert7!(T, convention) equivalentHelmert() const
        pure nothrow @safe @nogc
    {
        return _equivalentHelmert;
    }

    /// Example reading the prepared equivalent Helmert transform.
    @safe unittest
    {
        import geodesy;
        assert(PositionVectorMolodenskyBadekas!double.init
            .equivalentHelmert == PositionVectorHelmert!double.init);
    }

    /**
     * Prepare a local-pivot transformation from an existing Helmert7 parameter set.
     *
     * Use this factory when the published Molodensky-Badekas operation
     * supplies a convention-specific set of seven parameters plus three
     * source-frame XYZ coordinates for its evaluation point. These pivot
     * coordinates must use the same length unit as source XYZ. On failure
     * return `false` instead of throwing.
     *
     * Params:
     *     baseParameters = Convention-specific Helmert-family parameters.
     *     evaluationPointX = Finite source-geocentric X ordinate.
     *     evaluationPointY = Finite source-geocentric Y ordinate.
     *     evaluationPointZ = Finite source-geocentric Z ordinate.
     *     result = Receives the prepared transform on success.
     *
     * Returns:
     *     \`true\` when the evaluation point and derived equivalent Helmert
     *     parameters are finite and representable; otherwise \`false\`.
     */
    static bool tryFromCanonical(
        const Helmert7!(T, convention) baseParameters,
        const T evaluationPointX,
        const T evaluationPointY,
        const T evaluationPointZ,
        out MolodenskyBadekas10!(T, convention) result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(evaluationPointX)
            || !isFiniteGeodesyScalar(evaluationPointY)
            || !isFiniteGeodesyScalar(evaluationPointZ))
            return false;

        GeocentricCoordinate!T pivot;
        if (!GeocentricCoordinate!T.tryFromComponents(
                evaluationPointX,
                evaluationPointY,
                evaluationPointZ,
                pivot))
            return false;

        Helmert7!(T, convention) rotationScale;
        if (!Helmert7!(T, convention).tryFromCanonical(
                cast(T) 0,
                cast(T) 0,
                cast(T) 0,
                baseParameters.rotationX,
                baseParameters.rotationY,
                baseParameters.rotationZ,
                baseParameters.scaleDifference,
                rotationScale))
            return false;

        GeocentricCoordinate!T transformedPivot;
        static if (convention == HelmertConvention.positionVector)
        {
            if (!tryApplyPositionVectorHelmert(
                    pivot, rotationScale, transformedPivot))
                return false;
        }
        else
        {
            static assert(convention == HelmertConvention.coordinateFrame);
            if (!tryApplyCoordinateFrameHelmert(
                    pivot, rotationScale, transformedPivot))
                return false;
        }

        const T equivalentTranslationX =
            baseParameters.translationX
            + evaluationPointX
            - transformedPivot.x;
        const T equivalentTranslationY =
            baseParameters.translationY
            + evaluationPointY
            - transformedPivot.y;
        const T equivalentTranslationZ =
            baseParameters.translationZ
            + evaluationPointZ
            - transformedPivot.z;

        Helmert7!(T, convention) equivalent;
        if (!Helmert7!(T, convention).tryFromCanonical(
                equivalentTranslationX,
                equivalentTranslationY,
                equivalentTranslationZ,
                baseParameters.rotationX,
                baseParameters.rotationY,
                baseParameters.rotationZ,
                baseParameters.scaleDifference,
                equivalent))
            return false;

        result._baseParameters = baseParameters;
        result._evaluationPointX = evaluationPointX;
        result._evaluationPointY = evaluationPointY;
        result._evaluationPointZ = evaluationPointZ;
        result._equivalentHelmert = equivalent;
        return true;
    }

    /// Example checking canonical construction without throwing.
    @safe unittest
    {
        import geodesy;
        PositionVectorMolodenskyBadekas!double transform;
        assert(PositionVectorMolodenskyBadekas!double.tryFromCanonical(
            PositionVectorHelmert!double.init,
            1.0, 2.0, 3.0,
            transform));
        assert(transform.evaluationPointY == 2.0);
    }

    /** Prepare a local-pivot transform from seven parameters and an XYZ pivot.
     *
     * Use the checked `tryFromCanonical` alternative when an invalid
     * pivot or non-representable derived transform should not throw.
     */
    static MolodenskyBadekas10!(T, convention) fromCanonical(
        const Helmert7!(T, convention) baseParameters,
        const T evaluationPointX,
        const T evaluationPointY,
        const T evaluationPointZ)
        @safe
    {
        MolodenskyBadekas10!(T, convention) result;
        if (!tryFromCanonical(
                baseParameters,
                evaluationPointX,
                evaluationPointY,
                evaluationPointZ,
                result))
            throw new GeodesyValueException(
                "Molodensky-Badekas parameters must be finite and representable.");
        return result;
    }

    /// Example constructing canonical Position Vector parameters.
    @safe unittest
    {
        import geodesy;
        const transform = PositionVectorMolodenskyBadekas!double.fromCanonical(
            PositionVectorHelmert!double.init,
            1.0, 2.0, 3.0);
        assert(transform.evaluationPointZ == 3.0);
    }

    /**
     * Prepare a local-pivot frame transformation from published EPSG units.
     *
     * Use the translation, rotation, scale and evaluation-point values
     * from the same published transformation. Rotations use arc-seconds,
     * scale uses ppm, and the evaluation-point XYZ values use the same
     * linear unit as the source coordinates. This checked form returns
     * `false` for unsupported values.
     *
     * Translation and evaluation-point inputs use the same linear unit as the
     * geocentric coordinates to which the prepared transform will be applied.
     */
    static bool tryFromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm,
        const T evaluationPointX,
        const T evaluationPointY,
        const T evaluationPointZ,
        out MolodenskyBadekas10!(T, convention) result)
        pure nothrow @safe @nogc
    {
        Helmert7!(T, convention) base;
        if (!Helmert7!(T, convention).tryFromArcSecondsAndPpm(
                translationX,
                translationY,
                translationZ,
                rotationXArcSeconds,
                rotationYArcSeconds,
                rotationZArcSeconds,
                scaleDifferencePpm,
                base))
            return false;

        return tryFromCanonical(
            base,
            evaluationPointX,
            evaluationPointY,
            evaluationPointZ,
            result);
    }

    /// Example checking EPSG-unit construction without throwing.
    @safe unittest
    {
        import geodesy;
        PositionVectorMolodenskyBadekas!double transform;
        assert(PositionVectorMolodenskyBadekas!double.tryFromArcSecondsAndPpm(
            1.0, 2.0, 3.0,
            0.1, 0.2, 0.3,
            0.4,
            4.0, 5.0, 6.0,
            transform));
        assert(transform.baseParameters.translationX == 1.0);
    }

    /** Prepare the local-pivot transform from published EPSG-style parameters.
     *
     * Rotations are in arc-seconds, scale difference is in ppm, and all
     * translations and evaluation-point coordinates use the source XYZ
     * length unit. Use `tryFromArcSecondsAndPpm` for checked construction.
     */
    static MolodenskyBadekas10!(T, convention) fromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm,
        const T evaluationPointX,
        const T evaluationPointY,
        const T evaluationPointZ)
        @safe
    {
        MolodenskyBadekas10!(T, convention) result;
        if (!tryFromArcSecondsAndPpm(
                translationX,
                translationY,
                translationZ,
                rotationXArcSeconds,
                rotationYArcSeconds,
                rotationZArcSeconds,
                scaleDifferencePpm,
                evaluationPointX,
                evaluationPointY,
                evaluationPointZ,
                result))
            throw new GeodesyValueException(
                "Molodensky-Badekas parameters must be finite and representable.");
        return result;
    }

    /// Example constructing EPSG-style Position Vector parameters.
    @safe unittest
    {
        import geodesy;
        const transform =
            PositionVectorMolodenskyBadekas!double.fromArcSecondsAndPpm(
                1.0, 2.0, 3.0,
                0.1, 0.2, 0.3,
                0.4,
                4.0, 5.0, 6.0);
        assert(transform.evaluationPointX == 4.0);
    }

    /** Convert source geocentric XYZ to target-frame XYZ without throwing.
     *
     * This uses the already prepared local-pivot transformation in its
     * published forward direction. Returns `false` if the target cannot
     * be represented in the selected scalar type.
     */
    bool tryApply(
        const GeocentricCoordinate!T source,
        out GeocentricCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        static if (convention == HelmertConvention.positionVector)
            return tryApplyPositionVectorHelmert(
                source, _equivalentHelmert, result);
        else
        {
            static assert(convention == HelmertConvention.coordinateFrame);
            return tryApplyCoordinateFrameHelmert(
                source, _equivalentHelmert, result);
        }
    }

    /// Example applying the identity transform without throwing.
    @safe unittest
    {
        import geodesy;
        const source = GeocentricCoordinate!double.fromComponents(1.0, 2.0, 3.0);
        GeocentricCoordinate!double target;
        assert(PositionVectorMolodenskyBadekas!double.init.tryApply(source, target));
        assert(target == source);
    }

    /** Convert geocentric XYZ using this prepared local-pivot transform.
     *
     * Use `tryApply` instead when invalid arithmetic should return
     * `false` rather than raising an exception.
     */
    GeocentricCoordinate!T apply(
        const GeocentricCoordinate!T source) const
        @safe
    {
        GeocentricCoordinate!T result;
        if (!tryApply(source, result))
            throw new GeodesyValueException(
                "Molodensky-Badekas transformation produced a non-finite result.");
        return result;
    }

    /// Example applying the identity transform.
    @safe unittest
    {
        import geodesy;
        const source = GeocentricCoordinate!double.fromComponents(1.0, 2.0, 3.0);
        assert(PositionVectorMolodenskyBadekas!double.init.apply(source) == source);
    }
}

/// Example using the generic convention-parameterized family.
@safe unittest
{
    import geodesy;
    static assert(is(MolodenskyBadekas10!(
        double, HelmertConvention.positionVector)));
}


/** EPSG 1061 Position Vector parameter type. */
alias PositionVectorMolodenskyBadekas(T) =
    MolodenskyBadekas10!(T, HelmertConvention.positionVector);

/// Example selecting EPSG 1061 Position Vector semantics.
@safe unittest
{
    import geodesy;
    static assert(is(PositionVectorMolodenskyBadekas!double));
}


/** EPSG 1034 Coordinate Frame parameter type. */
alias CoordinateFrameMolodenskyBadekas(T) =
    MolodenskyBadekas10!(T, HelmertConvention.coordinateFrame);

/// Example selecting EPSG 1034 Coordinate Frame semantics.
@safe unittest
{
    import geodesy;
    static assert(is(CoordinateFrameMolodenskyBadekas!double));
}


/**
 * Convert Position Vector parameters to the equivalent Coordinate Frame
 * representation without changing the represented forward transformation.
 *
 * Only rotations change sign. Translations, scale, and evaluation point remain
 * unchanged.
 */
MolodenskyBadekas10!(T, HelmertConvention.coordinateFrame)
toCoordinateFrameMolodenskyBadekas(T)(
    const MolodenskyBadekas10!(
        T, HelmertConvention.positionVector) source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    MolodenskyBadekas10!(
        T, HelmertConvention.coordinateFrame) result;

    const base = toCoordinateFrame(source.baseParameters);
    const bool ok =
        MolodenskyBadekas10!(
            T, HelmertConvention.coordinateFrame).tryFromCanonical(
                base,
                source.evaluationPointX,
                source.evaluationPointY,
                source.evaluationPointZ,
                result);

    assert(ok);
    return result;
}

/// Example converting Position Vector parameters to Coordinate Frame.
@safe unittest
{
    import geodesy;
    const pv = PositionVectorMolodenskyBadekas!double.fromArcSecondsAndPpm(
        0, 0, 0, 0.1, 0.2, 0.3, 0, 1, 2, 3);
    const cf = toCoordinateFrameMolodenskyBadekas(pv);
    assert(cf.baseParameters.rotationX.radians
        == -pv.baseParameters.rotationX.radians);
}


/**
 * Convert Coordinate Frame parameters to the equivalent Position Vector
 * representation without changing the represented forward transformation.
 */
MolodenskyBadekas10!(T, HelmertConvention.positionVector)
toPositionVectorMolodenskyBadekas(T)(
    const MolodenskyBadekas10!(
        T, HelmertConvention.coordinateFrame) source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    MolodenskyBadekas10!(
        T, HelmertConvention.positionVector) result;

    const base = toPositionVector(source.baseParameters);
    const bool ok =
        MolodenskyBadekas10!(
            T, HelmertConvention.positionVector).tryFromCanonical(
                base,
                source.evaluationPointX,
                source.evaluationPointY,
                source.evaluationPointZ,
                result);

    assert(ok);
    return result;
}

/// Example converting Coordinate Frame parameters to Position Vector.
@safe unittest
{
    import geodesy;
    const cf = CoordinateFrameMolodenskyBadekas!double.fromArcSecondsAndPpm(
        0, 0, 0, -0.1, -0.2, -0.3, 0, 1, 2, 3);
    const pv = toPositionVectorMolodenskyBadekas(cf);
    assert(pv.baseParameters.rotationZ.radians
        == -cf.baseParameters.rotationZ.radians);
}


@safe unittest
{
    import std.math : fabs;

    bool near(
        const double actual,
        const double expected,
        const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // EPSG Guidance Note 7-2: La Canoa -> REGVEN.
    const source = GeocentricCoordinate!double.fromComponents(
         2_550_408.965,
        -5_749_912.266,
         1_054_891.114);

    const cf = CoordinateFrameMolodenskyBadekas!double
        .fromArcSecondsAndPpm(
            -270.933,
            +115.599,
            -360.226,
            -5.266,
            -1.238,
            +2.381,
            -5.109,
             2_464_351.59,
            -5_783_466.61,
               974_809.81);

    const target = cf.apply(source);

    assert(near(target.x,  2_550_138.467, 0.020));
    assert(near(target.y, -5_749_799.862, 0.020));
    assert(near(target.z,  1_054_530.826, 0.020));

    // Equivalent Position Vector representation negates only rotations.
    const pv = toPositionVectorMolodenskyBadekas(cf);
    const targetPv = pv.apply(source);
    assert(near(targetPv.x, target.x, 1e-9));
    assert(near(targetPv.y, target.y, 1e-9));
    assert(near(targetPv.z, target.z, 1e-9));

    assert(pv.evaluationPointX == cf.evaluationPointX);
    assert(pv.evaluationPointY == cf.evaluationPointY);
    assert(pv.evaluationPointZ == cf.evaluationPointZ);
    assert(pv.baseParameters.translationX == cf.baseParameters.translationX);
    assert(pv.baseParameters.scaleDifference == cf.baseParameters.scaleDifference);
    assert(pv.baseParameters.rotationX.radians
        == -cf.baseParameters.rotationX.radians);

    // A zero evaluation point reduces exactly to the existing Helmert family.
    const helmert = PositionVectorHelmert!double.fromArcSecondsAndPpm(
        1.0, 2.0, 3.0, 0.1, -0.2, 0.3, 0.4);
    const zeroPoint =
        PositionVectorMolodenskyBadekas!double.fromCanonical(
            helmert, 0.0, 0.0, 0.0);

    assert(zeroPoint.equivalentHelmert == helmert);

    GeocentricCoordinate!double helmertTarget;
    assert(tryApplyPositionVectorHelmert(
        source, helmert, helmertTarget));
    const zeroPointTarget = zeroPoint.apply(source);
    assert(zeroPointTarget == helmertTarget);

    // Public scalar family and identity default.
    static assert(is(PositionVectorMolodenskyBadekas!float));
    static assert(is(PositionVectorMolodenskyBadekas!double));
    static assert(is(PositionVectorMolodenskyBadekas!real));

    const floatSource =
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f);
    assert(PositionVectorMolodenskyBadekas!float.init.apply(floatSource)
        == floatSource);

    const realSource =
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L);
    assert(PositionVectorMolodenskyBadekas!real.init.apply(realSource)
        == realSource);

    PositionVectorMolodenskyBadekas!double invalid;
    assert(!PositionVectorMolodenskyBadekas!double.tryFromArcSecondsAndPpm(
        0, 0, 0, 0, 0, 0, 0,
        double.nan, 0, 0,
        invalid));
}
