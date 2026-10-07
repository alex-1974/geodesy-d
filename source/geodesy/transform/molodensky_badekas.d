/**
 * Static 10-parameter EPSG Molodensky-Badekas transformations in geocentric
 * coordinates.
 *
 * Molodensky-Badekas is a local-origin member of the Helmert family. Rotation
 * and scale act on Cartesian coordinates relative to an evaluation point
 * P=(Xp,Yp,Zp), after which the evaluation point and translations are restored.
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

    /** Source-geocentric X ordinate of the evaluation point. */
    @property T evaluationPointX() const pure nothrow @safe @nogc
    {
        return _evaluationPointX;
    }

    /** Source-geocentric Y ordinate of the evaluation point. */
    @property T evaluationPointY() const pure nothrow @safe @nogc
    {
        return _evaluationPointY;
    }

    /** Source-geocentric Z ordinate of the evaluation point. */
    @property T evaluationPointZ() const pure nothrow @safe @nogc
    {
        return _evaluationPointZ;
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

    /**
     * Construct from canonical parameters without throwing.
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

    /** Construct from canonical parameters. */
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

    /**
     * Construct from EPSG arc-second/ppm units without throwing.
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

    /** Construct from EPSG arc-second/ppm units. */
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

    /** Apply the prepared forward transformation without throwing. */
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

    /** Apply the prepared forward transformation. */
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
}


/** EPSG 1061 Position Vector parameter type. */
alias PositionVectorMolodenskyBadekas(T) =
    MolodenskyBadekas10!(T, HelmertConvention.positionVector);


/** EPSG 1034 Coordinate Frame parameter type. */
alias CoordinateFrameMolodenskyBadekas(T) =
    MolodenskyBadekas10!(T, HelmertConvention.coordinateFrame);


/**
 * Convert Position Vector parameters to the equivalent Coordinate Frame
 * representation without changing the represented forward transformation.
 *
 * Only rotations change sign. Translations, scale, and evaluation point remain
 * unchanged.
 */
CoordinateFrameMolodenskyBadekas!T
toCoordinateFrameMolodenskyBadekas(T)(
    const PositionVectorMolodenskyBadekas!T source)
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


/**
 * Convert Coordinate Frame parameters to the equivalent Position Vector
 * representation without changing the represented forward transformation.
 */
PositionVectorMolodenskyBadekas!T
toPositionVectorMolodenskyBadekas(T)(
    const CoordinateFrameMolodenskyBadekas!T source)
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
