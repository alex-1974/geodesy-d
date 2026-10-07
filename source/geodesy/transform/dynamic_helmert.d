/**
 * Time-dependent 14-parameter EPSG Helmert transformations.
 *
 * Helmert14 stores seven convention-specific Helmert parameters at a reference
 * epoch plus their seven signed rates. Evaluation at an observation epoch
 * produces the existing static `Helmert7` parameter set and reuses its
 * validated spatial transformation kernel.
 *
 * Standards:
 *     EPSG method 1053 -- Time-dependent Position Vector transformation
 *     (geocentric).
 *     EPSG method 1056 -- Time-dependent Coordinate Frame rotation
 *     (geocentric).
 *     EPSG parameter 1047 -- Parameter reference epoch.
 *
 * Units:
 *     Base translations and translation rates use the caller-selected linear
 *     unit and that unit per year. Canonical rotations use radians and rotation
 *     rates use radians per year. Scale difference is dimensionless and its
 *     rate is dimensionless per year. The interchange factory accepts
 *     arc-seconds, arc-seconds/year, ppm, and ppm/year.
 *
 * Numerics:
 *     Each effective parameter is evaluated as P(t) = P(t0) + rate * (t - t0).
 *     Public float propagation uses double working precision; double and real
 *     retain their own working precision.
 *
 * Default:
 *     `.init` is invalid because its reference epoch is invalid.
 *
 * See_Also:
 *     `Epoch`, `Helmert7`, `PositionVectorHelmert14`,
 *     `CoordinateFrameHelmert14`
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
module geodesy.transform.dynamic_helmert;

import std.math : PI;

import geodesy.angle : Angle;
import geodesy.epoch : Epoch;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;
import geodesy.transform.helmert :
    Helmert7,
    HelmertConvention,
    PositionVectorHelmert,
    CoordinateFrameHelmert,
    tryApplyPositionVectorHelmert,
    applyPositionVectorHelmert,
    tryApplyCoordinateFrameHelmert,
    applyCoordinateFrameHelmert,
    toCoordinateFrame,
    toPositionVector;


/**
 * Fourteen time-dependent Helmert parameters with compile-time rotation
 * convention.
 *
 * The fourteen parameters are the seven static Helmert values plus seven
 * rates. The reference epoch is separate and is not counted as a fifteenth
 * transformation parameter.
 */
struct Helmert14(T, HelmertConvention convention)
if (isGeodesyScalar!T)
{
private:
    Helmert7!(T, convention) _baseParameters;
    T _translationRateX = cast(T) 0;
    T _translationRateY = cast(T) 0;
    T _translationRateZ = cast(T) 0;
    T _rotationRateX = cast(T) 0;
    T _rotationRateY = cast(T) 0;
    T _rotationRateZ = cast(T) 0;
    T _scaleDifferenceRate = cast(T) 0;
    Epoch!T _referenceEpoch;

public:
    /** Whether this dynamic parameter set has a valid reference epoch. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _referenceEpoch.isValid;
    }

    /// Example checking the default-state contract.
    @safe unittest
    {
        import geodesy;
        assert(!PositionVectorHelmert14!double.init.isValid);
    }

    /** Static seven-parameter values defined at `referenceEpoch`. */
    @property Helmert7!(T, convention) baseParameters() const
        pure nothrow @safe @nogc
    {
        return _baseParameters;
    }

    /// Example reading the base parameter set.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.baseParameters.scaleFactor == 1.0);
    }

    /** X translation rate in the caller linear unit per year. */
    @property T translationRateX() const pure nothrow @safe @nogc
    {
        return _translationRateX;
    }

    /// Example reading the X translation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0.001, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.translationRateX == 0.001);
    }

    /** Y translation rate in the caller linear unit per year. */
    @property T translationRateY() const pure nothrow @safe @nogc
    {
        return _translationRateY;
    }

    /// Example reading the Y translation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0.002, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.translationRateY == 0.002);
    }

    /** Z translation rate in the caller linear unit per year. */
    @property T translationRateZ() const pure nothrow @safe @nogc
    {
        return _translationRateZ;
    }

    /// Example reading the Z translation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0.003, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.translationRateZ == 0.003);
    }

    /** X rotation rate in radians per year. */
    @property T rotationRateX() const pure nothrow @safe @nogc
    {
        return _rotationRateX;
    }

    /// Example reading the X rotation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 1e-9, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.rotationRateX == 1e-9);
    }

    /** Y rotation rate in radians per year. */
    @property T rotationRateY() const pure nothrow @safe @nogc
    {
        return _rotationRateY;
    }

    /// Example reading the Y rotation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 2e-9, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.rotationRateY == 2e-9);
    }

    /** Z rotation rate in radians per year. */
    @property T rotationRateZ() const pure nothrow @safe @nogc
    {
        return _rotationRateZ;
    }

    /// Example reading the Z rotation rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 3e-9, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.rotationRateZ == 3e-9);
    }

    /** Dimensionless scale-difference rate per year. */
    @property T scaleDifferenceRate() const pure nothrow @safe @nogc
    {
        return _scaleDifferenceRate;
    }

    /// Example reading the scale-difference rate.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 1e-9,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.scaleDifferenceRate == 1e-9);
    }

    /** Epoch at which `baseParameters` are defined. */
    @property Epoch!T referenceEpoch() const pure nothrow @safe @nogc
    {
        return _referenceEpoch;
    }

    /// Example reading the parameter reference epoch.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2010.0));
        assert(h.referenceEpoch.decimalYear == 2010.0);
    }

    /**
     * Construct from canonical base parameters and canonical rates without
     * throwing.
     *
     * Rotation rates are radians/year and scale rate is dimensionless/year.
     * Translation rates use the same linear unit as the base translations.
     */
    static bool tryFromCanonical(
        const Helmert7!(T, convention) baseParameters,
        const T translationRateX,
        const T translationRateY,
        const T translationRateZ,
        const T rotationRateX,
        const T rotationRateY,
        const T rotationRateZ,
        const T scaleDifferenceRate,
        const Epoch!T referenceEpoch,
        out Helmert14!(T, convention) result)
        pure nothrow @safe @nogc
    {
        result = Helmert14!(T, convention).init;

        if (!referenceEpoch.isValid
            || !isFiniteGeodesyScalar(translationRateX)
            || !isFiniteGeodesyScalar(translationRateY)
            || !isFiniteGeodesyScalar(translationRateZ)
            || !isFiniteGeodesyScalar(rotationRateX)
            || !isFiniteGeodesyScalar(rotationRateY)
            || !isFiniteGeodesyScalar(rotationRateZ)
            || !isFiniteGeodesyScalar(scaleDifferenceRate))
            return false;

        result._baseParameters = baseParameters;
        result._translationRateX = translationRateX;
        result._translationRateY = translationRateY;
        result._translationRateZ = translationRateZ;
        result._rotationRateX = rotationRateX;
        result._rotationRateY = rotationRateY;
        result._rotationRateZ = rotationRateZ;
        result._scaleDifferenceRate = scaleDifferenceRate;
        result._referenceEpoch = referenceEpoch;
        return true;
    }

    /// Example checking canonical dynamic parameters without throwing.
    @safe unittest
    {
        import geodesy;
        PositionVectorHelmert14!double h;
        assert(PositionVectorHelmert14!double.tryFromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0),
            h));
        assert(h.isValid);
    }

    /** Construct from canonical base parameters and canonical rates. */
    static Helmert14!(T, convention) fromCanonical(
        const Helmert7!(T, convention) baseParameters,
        const T translationRateX,
        const T translationRateY,
        const T translationRateZ,
        const T rotationRateX,
        const T rotationRateY,
        const T rotationRateZ,
        const T scaleDifferenceRate,
        const Epoch!T referenceEpoch)
        @safe
    {
        Helmert14!(T, convention) result;
        if (!tryFromCanonical(
                baseParameters,
                translationRateX,
                translationRateY,
                translationRateZ,
                rotationRateX,
                rotationRateY,
                rotationRateZ,
                scaleDifferenceRate,
                referenceEpoch,
                result))
            throw new GeodesyValueException(
                "Dynamic Helmert rates and reference epoch must be finite and valid.");
        return result;
    }

    /// Example constructing canonical dynamic parameters.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.isValid);
    }

    /**
     * Construct from EPSG-style arc-second/ppm base values and rates without
     * throwing.
     *
     * Params use caller linear units for translations, arc-seconds for
     * rotations, ppm for scale difference, and the corresponding units per
     * year for rates.
     */
    static bool tryFromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm,
        const T translationRateX,
        const T translationRateY,
        const T translationRateZ,
        const T rotationRateXArcSeconds,
        const T rotationRateYArcSeconds,
        const T rotationRateZArcSeconds,
        const T scaleDifferenceRatePpm,
        const Epoch!T referenceEpoch,
        out Helmert14!(T, convention) result)
        pure nothrow @safe @nogc
    {
        result = Helmert14!(T, convention).init;

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

        if (!isFiniteGeodesyScalar(rotationRateXArcSeconds)
            || !isFiniteGeodesyScalar(rotationRateYArcSeconds)
            || !isFiniteGeodesyScalar(rotationRateZArcSeconds)
            || !isFiniteGeodesyScalar(scaleDifferenceRatePpm))
            return false;

        const T radiansPerArcSecond =
            cast(T) (PI / (180.0L * 3600.0L));

        const T rotationRateX =
            rotationRateXArcSeconds * radiansPerArcSecond;
        const T rotationRateY =
            rotationRateYArcSeconds * radiansPerArcSecond;
        const T rotationRateZ =
            rotationRateZArcSeconds * radiansPerArcSecond;
        const T scaleDifferenceRate =
            scaleDifferenceRatePpm * cast(T) 1.0e-6L;

        return tryFromCanonical(
            base,
            translationRateX,
            translationRateY,
            translationRateZ,
            rotationRateX,
            rotationRateY,
            rotationRateZ,
            scaleDifferenceRate,
            referenceEpoch,
            result);
    }

    /// Example constructing EPSG-style dynamic parameters without throwing.
    @safe unittest
    {
        import geodesy;
        PositionVectorHelmert14!double h;
        assert(PositionVectorHelmert14!double.tryFromArcSecondsAndPpm(
            0, 0, 0, 0, 0, 0, 0,
            0.001, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0),
            h));
        assert(h.translationRateX == 0.001);
    }

    /** Construct from EPSG-style arc-second/ppm base values and rates. */
    static Helmert14!(T, convention) fromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm,
        const T translationRateX,
        const T translationRateY,
        const T translationRateZ,
        const T rotationRateXArcSeconds,
        const T rotationRateYArcSeconds,
        const T rotationRateZArcSeconds,
        const T scaleDifferenceRatePpm,
        const Epoch!T referenceEpoch)
        @safe
    {
        Helmert14!(T, convention) result;
        if (!tryFromArcSecondsAndPpm(
                translationX,
                translationY,
                translationZ,
                rotationXArcSeconds,
                rotationYArcSeconds,
                rotationZArcSeconds,
                scaleDifferencePpm,
                translationRateX,
                translationRateY,
                translationRateZ,
                rotationRateXArcSeconds,
                rotationRateYArcSeconds,
                rotationRateZArcSeconds,
                scaleDifferenceRatePpm,
                referenceEpoch,
                result))
            throw new GeodesyValueException(
                "Dynamic Helmert parameters must be finite and representable.");
        return result;
    }

    /// Example constructing EPSG-style Position Vector parameters.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromArcSecondsAndPpm(
            0, 0, 0, 0, 0, 0, 0,
            0.001, 0.002, 0.003, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.translationRateZ == 0.003);
    }

    /**
     * Evaluate the effective static Helmert parameters at an observation epoch.
     *
     * Returns:
     *     `true` when the epoch and all propagated parameters are finite and
     *     representable in scalar type `T`; otherwise `false`.
     */
    bool tryEvaluate(
        const Epoch!T observationEpoch,
        out Helmert7!(T, convention) result) const
        pure nothrow @safe @nogc
    {
        result = Helmert7!(T, convention).init;
        if (!_referenceEpoch.isValid || !observationEpoch.isValid)
            return false;

        static if (is(T == float))
            alias W = double;
        else
            alias W = T;

        const W dt =
            cast(W) observationEpoch.decimalYear
            - cast(W) _referenceEpoch.decimalYear;

        if (!isFiniteGeodesyScalar(dt))
            return false;

        const W txW = cast(W) _baseParameters.translationX
            + cast(W) _translationRateX * dt;
        const W tyW = cast(W) _baseParameters.translationY
            + cast(W) _translationRateY * dt;
        const W tzW = cast(W) _baseParameters.translationZ
            + cast(W) _translationRateZ * dt;
        const W rxW = cast(W) _baseParameters.rotationX.radians
            + cast(W) _rotationRateX * dt;
        const W ryW = cast(W) _baseParameters.rotationY.radians
            + cast(W) _rotationRateY * dt;
        const W rzW = cast(W) _baseParameters.rotationZ.radians
            + cast(W) _rotationRateZ * dt;
        const W dsW = cast(W) _baseParameters.scaleDifference
            + cast(W) _scaleDifferenceRate * dt;

        if (!isFiniteGeodesyScalar(txW)
            || !isFiniteGeodesyScalar(tyW)
            || !isFiniteGeodesyScalar(tzW)
            || !isFiniteGeodesyScalar(rxW)
            || !isFiniteGeodesyScalar(ryW)
            || !isFiniteGeodesyScalar(rzW)
            || !isFiniteGeodesyScalar(dsW))
            return false;

        const T tx = cast(T) txW;
        const T ty = cast(T) tyW;
        const T tz = cast(T) tzW;
        const T rxValue = cast(T) rxW;
        const T ryValue = cast(T) ryW;
        const T rzValue = cast(T) rzW;
        const T ds = cast(T) dsW;

        if (!isFiniteGeodesyScalar(tx)
            || !isFiniteGeodesyScalar(ty)
            || !isFiniteGeodesyScalar(tz)
            || !isFiniteGeodesyScalar(rxValue)
            || !isFiniteGeodesyScalar(ryValue)
            || !isFiniteGeodesyScalar(rzValue)
            || !isFiniteGeodesyScalar(ds))
            return false;

        Angle!T rx;
        Angle!T ry;
        Angle!T rz;
        if (!Angle!T.tryFromRadians(rxValue, rx)
            || !Angle!T.tryFromRadians(ryValue, ry)
            || !Angle!T.tryFromRadians(rzValue, rz))
            return false;

        return Helmert7!(T, convention).tryFromCanonical(
            tx, ty, tz, rx, ry, rz, ds, result);
    }

    /// Example evaluating parameters ten years after their reference epoch.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0.001, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        PositionVectorHelmert!double effective;
        assert(h.tryEvaluate(Epoch!double.fromDecimalYear(2010.0), effective));
        assert(effective.translationX == 0.01);
    }

    /**
     * Evaluate the effective static Helmert parameters at an observation epoch.
     *
     * Throws:
     *     `GeodesyValueException` when the epoch or propagated parameters are
     *     invalid or unrepresentable.
     */
    Helmert7!(T, convention) evaluate(
        const Epoch!T observationEpoch) const @safe
    {
        Helmert7!(T, convention) result;
        if (!tryEvaluate(observationEpoch, result))
            throw new GeodesyValueException(
                "Dynamic Helmert evaluation failed for the supplied epoch.");
        return result;
    }

    /// Example evaluating a zero-rate transform.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        assert(h.evaluate(Epoch!double.fromDecimalYear(2025.0))
            == PositionVectorHelmert!double.init);
    }

    /**
     * Apply the dynamic transformation at an observation epoch without
     * throwing.
     */
    bool tryApply(
        const GeocentricCoordinate!T source,
        const Epoch!T observationEpoch,
        out GeocentricCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = GeocentricCoordinate!T.init;
        Helmert7!(T, convention) effective;
        if (!tryEvaluate(observationEpoch, effective))
            return false;

        static if (convention == HelmertConvention.positionVector)
            return tryApplyPositionVectorHelmert(source, effective, result);
        else
        {
            static assert(convention == HelmertConvention.coordinateFrame);
            return tryApplyCoordinateFrameHelmert(source, effective, result);
        }
    }

    /// Example applying a dynamic identity transform without throwing.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        const source = GeocentricCoordinate!double.fromComponents(1, 2, 3);
        GeocentricCoordinate!double target;
        assert(h.tryApply(
            source,
            Epoch!double.fromDecimalYear(2020.0),
            target));
        assert(target == source);
    }

    /**
     * Apply the dynamic transformation at an observation epoch.
     *
     * Throws:
     *     `GeodesyValueException` when parameter evaluation or spatial
     *     transformation fails.
     */
    GeocentricCoordinate!T apply(
        const GeocentricCoordinate!T source,
        const Epoch!T observationEpoch) const @safe
    {
        GeocentricCoordinate!T result;
        if (!tryApply(source, observationEpoch, result))
            throw new GeodesyValueException(
                "Dynamic Helmert transformation failed.");
        return result;
    }

    /// Example applying a dynamic Position Vector transform.
    @safe unittest
    {
        import geodesy;
        const h = PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            0.001, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0));
        const target = h.apply(
            GeocentricCoordinate!double.fromComponents(0, 0, 0),
            Epoch!double.fromDecimalYear(2010.0));
        assert(target.x == 0.01);
    }
}


/** EPSG 1053 time-dependent Position Vector parameter type. */
alias PositionVectorHelmert14(T) =
    Helmert14!(T, HelmertConvention.positionVector);

/// Example selecting the EPSG 1053 family.
@safe unittest
{
    import geodesy;
    static assert(is(PositionVectorHelmert14!double));
}


/** EPSG 1056 time-dependent Coordinate Frame parameter type. */
alias CoordinateFrameHelmert14(T) =
    Helmert14!(T, HelmertConvention.coordinateFrame);

/// Example selecting the EPSG 1056 family.
@safe unittest
{
    import geodesy;
    static assert(is(CoordinateFrameHelmert14!double));
}


/**
 * Convert dynamic Position Vector parameters to the equivalent Coordinate
 * Frame representation.
 *
 * Rotations and rotation rates are negated. Translations, translation rates,
 * scale, scale rate, and reference epoch are preserved.
 */
CoordinateFrameHelmert14!T toCoordinateFrameHelmert14(T)(
    const PositionVectorHelmert14!T source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    CoordinateFrameHelmert14!T result;
    result._baseParameters = toCoordinateFrame(source._baseParameters);
    result._translationRateX = source._translationRateX;
    result._translationRateY = source._translationRateY;
    result._translationRateZ = source._translationRateZ;
    result._rotationRateX = -source._rotationRateX;
    result._rotationRateY = -source._rotationRateY;
    result._rotationRateZ = -source._rotationRateZ;
    result._scaleDifferenceRate = source._scaleDifferenceRate;
    result._referenceEpoch = source._referenceEpoch;
    return result;
}

/// Example converting dynamic Position Vector parameters.
@safe unittest
{
    import geodesy;
    const pv = PositionVectorHelmert14!double.fromCanonical(
        PositionVectorHelmert!double.init,
        0, 0, 0, 1e-9, 2e-9, 3e-9, 0,
        Epoch!double.fromDecimalYear(2000.0));
    const cf = toCoordinateFrameHelmert14(pv);
    assert(cf.rotationRateZ == -pv.rotationRateZ);
}


/**
 * Convert dynamic Coordinate Frame parameters to the equivalent Position
 * Vector representation.
 */
PositionVectorHelmert14!T toPositionVectorHelmert14(T)(
    const CoordinateFrameHelmert14!T source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    PositionVectorHelmert14!T result;
    result._baseParameters = toPositionVector(source._baseParameters);
    result._translationRateX = source._translationRateX;
    result._translationRateY = source._translationRateY;
    result._translationRateZ = source._translationRateZ;
    result._rotationRateX = -source._rotationRateX;
    result._rotationRateY = -source._rotationRateY;
    result._rotationRateZ = -source._rotationRateZ;
    result._scaleDifferenceRate = source._scaleDifferenceRate;
    result._referenceEpoch = source._referenceEpoch;
    return result;
}

/// Example converting dynamic Coordinate Frame parameters.
@safe unittest
{
    import geodesy;
    const cf = CoordinateFrameHelmert14!double.fromCanonical(
        CoordinateFrameHelmert!double.init,
        0, 0, 0, -1e-9, -2e-9, -3e-9, 0,
        Epoch!double.fromDecimalYear(2000.0));
    const pv = toPositionVectorHelmert14(cf);
    assert(pv.rotationRateX == -cf.rotationRateX);
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    bool near(const double a, const double b, const double tol)
    {
        return fabs(a - b) <= tol;
    }

    // EPSG method 1053 worked example:
    // ITRF2008 -> GDA94 at observation epoch 2013.90, t0 = 1994.00.
    const epsg = PositionVectorHelmert14!double.fromArcSecondsAndPpm(
        -0.08468, -0.01942, +0.03201,
        +0.0004254, -0.0022578, -0.0024015,
        +0.00971,
        +0.00142, +0.00134, +0.00090,
        -0.0015461, -0.0011820, -0.0011551,
        +0.000109,
        Epoch!double.fromDecimalYear(1994.00));

    const observation = Epoch!double.fromDecimalYear(2013.90);
    const effective = epsg.evaluate(observation);

    assert(near(effective.translationX, -0.05642, 5e-6));
    assert(near(effective.translationY, +0.00725, 5e-6));
    assert(near(effective.translationZ, +0.04992, 5e-6));
    assert(near(effective.rotationX.radians, -1.471021e-7, 5e-13));
    assert(near(effective.rotationY.radians, -1.249830e-7, 5e-13));
    assert(near(effective.rotationZ.radians, -1.230844e-7, 5e-13));
    assert(near(effective.scaleDifference, 1.188e-8, 5e-12));

    const source = GeocentricCoordinate!double.fromComponents(
        -3_789_470.710,
         4_841_770.404,
        -1_690_893.952);

    const target = epsg.apply(source, observation);

    assert(near(target.x, -3_789_470.004, 0.0015));
    assert(near(target.y,  4_841_770.686, 0.0015));
    assert(near(target.z, -1_690_895.108, 0.0015));

    // Zero rates reduce exactly to the existing static family for any finite
    // observation epoch.
    const staticPv = PositionVectorHelmert!double.fromArcSecondsAndPpm(
        0.1, -0.2, 0.3, 0.004, -0.005, 0.006, 0.007);

    const zeroRate = PositionVectorHelmert14!double.fromCanonical(
        staticPv,
        0, 0, 0, 0, 0, 0, 0,
        Epoch!double.fromDecimalYear(2000.0));

    assert(zeroRate.evaluate(Epoch!double.fromDecimalYear(1900.0)) == staticPv);
    assert(zeroRate.evaluate(Epoch!double.fromDecimalYear(2100.0)) == staticPv);

    // Convention conversion preserves the represented transformation.
    const cf = toCoordinateFrameHelmert14(epsg);
    const targetCf = cf.apply(source, observation);
    assert(near(targetCf.x, target.x, 1e-9));
    assert(near(targetCf.y, target.y, 1e-9));
    assert(near(targetCf.z, target.z, 1e-9));

    const roundTrip = toPositionVectorHelmert14(cf);
    assert(roundTrip.rotationRateX == epsg.rotationRateX);
    assert(roundTrip.rotationRateY == epsg.rotationRateY);
    assert(roundTrip.rotationRateZ == epsg.rotationRateZ);

    // Scalar family compiles and evaluates for float and platform real.
    const floatDynamic = PositionVectorHelmert14!float.fromCanonical(
        PositionVectorHelmert!float.init,
        0.001f, 0, 0, 0, 0, 0, 0,
        Epoch!float.fromDecimalYear(2000.0f));
    assert(floatDynamic.evaluate(
        Epoch!float.fromDecimalYear(2010.0f)).translationX > 0.009f);

    const realDynamic = PositionVectorHelmert14!real.fromCanonical(
        PositionVectorHelmert!real.init,
        0.001L, 0, 0, 0, 0, 0, 0,
        Epoch!real.fromDecimalYear(2000.0L));
    assert(realDynamic.evaluate(
        Epoch!real.fromDecimalYear(2010.0L)).translationX > 0.009L);

    PositionVectorHelmert14!double invalid;
    assert(!PositionVectorHelmert14!double.tryFromCanonical(
        PositionVectorHelmert!double.init,
        double.nan, 0, 0, 0, 0, 0, 0,
        Epoch!double.fromDecimalYear(2000.0),
        invalid));

    assertThrown!GeodesyValueException(
        PositionVectorHelmert14!double.fromCanonical(
            PositionVectorHelmert!double.init,
            double.nan, 0, 0, 0, 0, 0, 0,
            Epoch!double.fromDecimalYear(2000.0)));
}
