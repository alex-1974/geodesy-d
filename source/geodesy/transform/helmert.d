/**
 * Static 7-parameter Helmert transformations in the geocentric domain.
 *
 * The public type model makes the EPSG rotation convention a compile-time
 * property. EPSG 1033 Position Vector and EPSG 1032 Coordinate Frame
 * share the same parameter model while retaining distinct conventions.
 */
module geodesy.transform.helmert;

import std.math : PI;

import geodesy.angle : Angle, angleFromRadiansUnchecked;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;


/** EPSG Helmert rotation convention. */
enum HelmertConvention
{
    positionVector,
    coordinateFrame
}


/**
 * Seven source-to-target Helmert parameters.
 *
 * Canonical storage:
 *
 * - translations: same linear unit as geocentric X/Y/Z;
 * - rotations: radians through `Angle!T`;
 * - scale difference: dimensionless fraction, so scale factor M = 1 + dS.
 *
 * `.init` is the identity transformation.
 */
struct Helmert7(T, HelmertConvention convention)
if (isGeodesyScalar!T)
{
private:
    T _translationX = cast(T) 0;
    T _translationY = cast(T) 0;
    T _translationZ = cast(T) 0;

    Angle!T _rotationX;
    Angle!T _rotationY;
    Angle!T _rotationZ;

    T _scaleDifference = cast(T) 0;

public:
    /** X-axis translation. */
    @property T translationX() const pure nothrow @safe @nogc
    {
        return _translationX;
    }

    /** Y-axis translation. */
    @property T translationY() const pure nothrow @safe @nogc
    {
        return _translationY;
    }

    /** Z-axis translation. */
    @property T translationZ() const pure nothrow @safe @nogc
    {
        return _translationZ;
    }

    /** X-axis rotation, canonically stored in radians. */
    @property Angle!T rotationX() const pure nothrow @safe @nogc
    {
        return _rotationX;
    }

    /** Y-axis rotation, canonically stored in radians. */
    @property Angle!T rotationY() const pure nothrow @safe @nogc
    {
        return _rotationY;
    }

    /** Z-axis rotation, canonically stored in radians. */
    @property Angle!T rotationZ() const pure nothrow @safe @nogc
    {
        return _rotationZ;
    }

    /** Dimensionless scale difference dS. */
    @property T scaleDifference() const pure nothrow @safe @nogc
    {
        return _scaleDifference;
    }

    /** Multiplication factor M = 1 + dS. */
    @property T scaleFactor() const pure nothrow @safe @nogc
    {
        return cast(T) 1 + _scaleDifference;
    }

    /**
     * Checked construction from canonical units.
     *
     * Rotation arguments are already valid finite `Angle!T` values.
     * Returns false when a translation or scale difference is NaN/infinite.
     */
    static bool tryFromCanonical(
        const T translationX,
        const T translationY,
        const T translationZ,
        const Angle!T rotationX,
        const Angle!T rotationY,
        const Angle!T rotationZ,
        const T scaleDifference,
        out Helmert7!(T, convention) result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(translationX)
            || !isFiniteGeodesyScalar(translationY)
            || !isFiniteGeodesyScalar(translationZ)
            || !isFiniteGeodesyScalar(scaleDifference))
            return false;

        result._translationX = translationX;
        result._translationY = translationY;
        result._translationZ = translationZ;
        result._rotationX = rotationX;
        result._rotationY = rotationY;
        result._rotationZ = rotationZ;
        result._scaleDifference = scaleDifference;
        return true;
    }

    /** Throwing convenience factory from canonical units. */
    static Helmert7!(T, convention) fromCanonical(
        const T translationX,
        const T translationY,
        const T translationZ,
        const Angle!T rotationX,
        const Angle!T rotationY,
        const Angle!T rotationZ,
        const T scaleDifference)
        @safe
    {
        Helmert7!(T, convention) result;
        if (!tryFromCanonical(
                translationX,
                translationY,
                translationZ,
                rotationX,
                rotationY,
                rotationZ,
                scaleDifference,
                result))
            throw new GeodesyValueException(
                "Helmert translations and scale difference must be finite.");
        return result;
    }

    /**
     * Checked factory for the common EPSG interchange representation.
     *
     * Rotations are supplied in arc-seconds and scale difference in ppm.
     * They are converted to canonical radians and a dimensionless fraction.
     */
    static bool tryFromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm,
        out Helmert7!(T, convention) result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(translationX)
            || !isFiniteGeodesyScalar(translationY)
            || !isFiniteGeodesyScalar(translationZ)
            || !isFiniteGeodesyScalar(rotationXArcSeconds)
            || !isFiniteGeodesyScalar(rotationYArcSeconds)
            || !isFiniteGeodesyScalar(rotationZArcSeconds)
            || !isFiniteGeodesyScalar(scaleDifferencePpm))
            return false;

        const T radiansPerArcSecond =
            cast(T) (PI / (180.0L * 3600.0L));

        Angle!T rotationX;
        Angle!T rotationY;
        Angle!T rotationZ;

        if (!Angle!T.tryFromRadians(
                rotationXArcSeconds * radiansPerArcSecond, rotationX)
            || !Angle!T.tryFromRadians(
                rotationYArcSeconds * radiansPerArcSecond, rotationY)
            || !Angle!T.tryFromRadians(
                rotationZArcSeconds * radiansPerArcSecond, rotationZ))
            return false;

        const T scaleDifference =
            scaleDifferencePpm * cast(T) 1.0e-6L;

        if (!isFiniteGeodesyScalar(scaleDifference))
            return false;

        return tryFromCanonical(
            translationX,
            translationY,
            translationZ,
            rotationX,
            rotationY,
            rotationZ,
            scaleDifference,
            result);
    }

    /** Throwing EPSG-style arc-second/ppm factory. */
    static Helmert7!(T, convention) fromArcSecondsAndPpm(
        const T translationX,
        const T translationY,
        const T translationZ,
        const T rotationXArcSeconds,
        const T rotationYArcSeconds,
        const T rotationZArcSeconds,
        const T scaleDifferencePpm)
        @safe
    {
        Helmert7!(T, convention) result;
        if (!tryFromArcSecondsAndPpm(
                translationX,
                translationY,
                translationZ,
                rotationXArcSeconds,
                rotationYArcSeconds,
                rotationZArcSeconds,
                scaleDifferencePpm,
                result))
            throw new GeodesyValueException(
                "Helmert parameters must be finite and representable.");
        return result;
    }
}


/** EPSG 1033 parameter type. */
alias PositionVectorHelmert(T) =
    Helmert7!(T, HelmertConvention.positionVector);


/** EPSG 1032 Coordinate Frame parameter type. */
alias CoordinateFrameHelmert(T) =
    Helmert7!(T, HelmertConvention.coordinateFrame);


/**
 * Private EPSG 1033 Position Vector kernel.
 *
 * EPSG small-angle matrix:
 *
 *   Xt = tX + M * ( Xs - rZ*Ys + rY*Zs )
 *   Yt = tY + M * ( rZ*Xs + Ys - rX*Zs )
 *   Zt = tZ + M * (-rY*Xs + rX*Ys + Zs )
 */
private bool tryApplyPositionVectorKernel(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.positionVector) transform,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T x = source.x;
    const T y = source.y;
    const T z = source.z;

    const T rx = transform.rotationX.radians;
    const T ry = transform.rotationY.radians;
    const T rz = transform.rotationZ.radians;
    const T m = transform.scaleFactor;

    if (!isFiniteGeodesyScalar(m))
        return false;

    const T targetX = transform.translationX
        + m * (x - rz * y + ry * z);

    const T targetY = transform.translationY
        + m * (rz * x + y - rx * z);

    const T targetZ = transform.translationZ
        + m * (-ry * x + rx * y + z);

    return GeocentricCoordinate!T.tryFromComponents(
        targetX, targetY, targetZ, result);
}


/**
 * Apply EPSG method 1033 — Position Vector transformation
 * (geocentric domain).
 *
 * Returns false when finite parameters/intermediate arithmetic produce a
 * non-finite target coordinate in scalar type T.
 */
bool tryApplyPositionVectorHelmert(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.positionVector) transform,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryApplyPositionVectorKernel(source, transform, result);
}


/** Throwing convenience wrapper for EPSG 1033. */
GeocentricCoordinate!T applyPositionVectorHelmert(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.positionVector) transform)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryApplyPositionVectorHelmert(source, transform, result))
        throw new GeodesyValueException(
            "Position Vector Helmert transformation produced a non-finite result.");
    return result;
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    import geodesy.transform.geocentric_translation :
        GeocentricTranslation,
        applyGeocentricTranslation;

    bool near(const double actual, const double expected, const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // EPSG Guidance Note 7-2 / method 1033:
    // WGS 72 -> WGS 84, transformation code 1238.
    const source = GeocentricCoordinate!double.fromComponents(
        3_657_660.66,
          255_768.55,
        5_201_382.11);

    const wgs72ToWgs84 =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            0.0,
            0.0,
            4.5,
            0.0,
            0.0,
            0.554,
            0.219);

    const target =
        applyPositionVectorHelmert(source, wgs72ToWgs84);

    // Published EPSG output is rounded to centimetres.
    assert(near(target.x, 3_657_660.78, 0.01));
    assert(near(target.y,   255_778.43, 0.01));
    assert(near(target.z, 5_201_387.75, 0.01));

    // Factory unit conversion: 0.554 arc-second -> EPSG quoted radians;
    // 0.219 ppm -> 0.000000219 dimensionless.
    assert(near(
        wgs72ToWgs84.rotationZ.radians,
        0.000002685868,
        5e-13));
    assert(near(
        wgs72ToWgs84.scaleDifference,
        0.000000219,
        1e-18));
    assert(near(
        wgs72ToWgs84.scaleFactor,
        1.000000219,
        1e-15));

    // `.init` is the identity transformation.
    const identity = applyPositionVectorHelmert(
        source,
        PositionVectorHelmert!double.init);
    assert(identity == source);

    // With zero rotations and zero scale difference, EPSG 1033 reduces
    // exactly to EPSG 1031 translation.
    const shift7 =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            84.87, 96.49, 116.95,
            0.0, 0.0, 0.0,
            0.0);

    const shift3 =
        GeocentricTranslation!double.fromComponents(
            84.87, 96.49, 116.95);

    const via7 = applyPositionVectorHelmert(source, shift7);
    const via3 = applyGeocentricTranslation(source, shift3);
    assert(via7 == via3);

    // Pure scale.
    const scaled =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            1.0); // +1 ppm

    const unitSource =
        GeocentricCoordinate!double.fromComponents(
            1_000_000.0, 2_000_000.0, 3_000_000.0);

    const unitTarget =
        applyPositionVectorHelmert(unitSource, scaled);

    assert(near(unitTarget.x, 1_000_001.0, 1e-9));
    assert(near(unitTarget.y, 2_000_002.0, 1e-9));
    assert(near(unitTarget.z, 3_000_003.0, 1e-9));

    // Positive Position Vector rZ rotates +X toward +Y in the linearized
    // EPSG matrix.
    const zRotation =
        PositionVectorHelmert!double.fromCanonical(
            0.0, 0.0, 0.0,
            Angle!double.init,
            Angle!double.init,
            Angle!double.fromRadians(1.0e-6),
            0.0);

    const xAxis =
        GeocentricCoordinate!double.fromComponents(
            1_000_000.0, 0.0, 0.0);

    const rotated =
        applyPositionVectorHelmert(xAxis, zRotation);

    assert(near(rotated.x, 1_000_000.0, 1e-9));
    assert(near(rotated.y, 1.0, 1e-12));
    assert(near(rotated.z, 0.0, 1e-12));

    // Generic scalar instantiation.
    const floatIdentity = applyPositionVectorHelmert(
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f),
        PositionVectorHelmert!float.init);
    assert(floatIdentity ==
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f));

    const realIdentity = applyPositionVectorHelmert(
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L),
        PositionVectorHelmert!real.init);
    assert(realIdentity ==
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L));

    // Invalid parameters are rejected by construction.
    PositionVectorHelmert!double invalid;
    assert(!PositionVectorHelmert!double.tryFromArcSecondsAndPpm(
        double.nan,
        0.0, 0.0,
        0.0, 0.0, 0.0,
        0.0,
        invalid));

    assertThrown!GeodesyValueException(
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            double.nan,
            0.0, 0.0,
            0.0, 0.0, 0.0,
            0.0));

    // Finite values may still overflow during application.
    const hugeSource =
        GeocentricCoordinate!double.fromComponents(
            double.max, double.max, double.max);

    const hugeScale =
        PositionVectorHelmert!double.fromCanonical(
            0.0, 0.0, 0.0,
            Angle!double.init,
            Angle!double.init,
            Angle!double.init,
            double.max);

    GeocentricCoordinate!double candidate;
    assert(!tryApplyPositionVectorHelmert(
        hugeSource, hugeScale, candidate));

    assertThrown!GeodesyValueException(
        applyPositionVectorHelmert(
            hugeSource, hugeScale));
}


/**
 * Convert an EPSG 1033 Position Vector parameter set into the equivalent
 * EPSG 1032 Coordinate Frame parameter set.
 *
 * Translations and scale difference are preserved. All three rotations are
 * negated. The represented source-to-target transformation is unchanged.
 */
CoordinateFrameHelmert!T toCoordinateFrame(T)(
    const Helmert7!(T, HelmertConvention.positionVector) source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    CoordinateFrameHelmert!T result;
    result._translationX = source._translationX;
    result._translationY = source._translationY;
    result._translationZ = source._translationZ;
    result._rotationX = angleFromRadiansUnchecked!T(-source._rotationX.radians);
    result._rotationY = angleFromRadiansUnchecked!T(-source._rotationY.radians);
    result._rotationZ = angleFromRadiansUnchecked!T(-source._rotationZ.radians);
    result._scaleDifference = source._scaleDifference;
    return result;
}


/**
 * Convert an EPSG 1032 Coordinate Frame parameter set into the equivalent
 * EPSG 1033 Position Vector parameter set.
 *
 * Translations and scale difference are preserved. All three rotations are
 * negated.
 */
PositionVectorHelmert!T toPositionVector(T)(
    const Helmert7!(T, HelmertConvention.coordinateFrame) source)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    PositionVectorHelmert!T result;
    result._translationX = source._translationX;
    result._translationY = source._translationY;
    result._translationZ = source._translationZ;
    result._rotationX = angleFromRadiansUnchecked!T(-source._rotationX.radians);
    result._rotationY = angleFromRadiansUnchecked!T(-source._rotationY.radians);
    result._rotationZ = angleFromRadiansUnchecked!T(-source._rotationZ.radians);
    result._scaleDifference = source._scaleDifference;
    return result;
}


/**
 * Private EPSG 1032 Coordinate Frame kernel.
 *
 * EPSG small-angle matrix:
 *
 *   Xt = tX + M * ( Xs + rZ*Ys - rY*Zs )
 *   Yt = tY + M * (-rZ*Xs + Ys + rX*Zs )
 *   Zt = tZ + M * ( rY*Xs - rX*Ys + Zs )
 */
private bool tryApplyCoordinateFrameKernel(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.coordinateFrame) transform,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T x = source.x;
    const T y = source.y;
    const T z = source.z;

    const T rx = transform.rotationX.radians;
    const T ry = transform.rotationY.radians;
    const T rz = transform.rotationZ.radians;
    const T m = transform.scaleFactor;

    if (!isFiniteGeodesyScalar(m))
        return false;

    const T targetX = transform.translationX
        + m * (x + rz * y - ry * z);

    const T targetY = transform.translationY
        + m * (-rz * x + y + rx * z);

    const T targetZ = transform.translationZ
        + m * (ry * x - rx * y + z);

    return GeocentricCoordinate!T.tryFromComponents(
        targetX, targetY, targetZ, result);
}


/**
 * Apply EPSG method 1032 — Coordinate Frame rotation
 * (geocentric domain).
 *
 * Returns false when finite parameters/intermediate arithmetic produce a
 * non-finite target coordinate in scalar type T.
 */
bool tryApplyCoordinateFrameHelmert(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.coordinateFrame) transform,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return tryApplyCoordinateFrameKernel(source, transform, result);
}


/** Throwing convenience wrapper for EPSG 1032. */
GeocentricCoordinate!T applyCoordinateFrameHelmert(T)(
    const GeocentricCoordinate!T source,
    const Helmert7!(T, HelmertConvention.coordinateFrame) transform)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryApplyCoordinateFrameHelmert(source, transform, result))
        throw new GeodesyValueException(
            "Coordinate Frame Helmert transformation produced a non-finite result.");
    return result;
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    bool nearCf(
        const double actual,
        const double expected,
        const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // Same WGS 72 -> WGS 84 transformation as the EPSG 1033 worked example,
    // expressed in the EPSG 1032 Coordinate Frame convention.
    //
    // EPSG explicitly changes only the rotation sign:
    //   Position Vector rZ  = +0.554 arcsec
    //   Coordinate Frame rZ = -0.554 arcsec
    const source = GeocentricCoordinate!double.fromComponents(
        3_657_660.66,
          255_768.55,
        5_201_382.11);

    const coordinateFrame =
        CoordinateFrameHelmert!double.fromArcSecondsAndPpm(
            0.0,
            0.0,
            4.5,
            0.0,
            0.0,
            -0.554,
            0.219);

    const target =
        applyCoordinateFrameHelmert(source, coordinateFrame);

    // Same published target as EPSG 1033, rounded to centimetres.
    assert(nearCf(target.x, 3_657_660.78, 0.01));
    assert(nearCf(target.y,   255_778.43, 0.01));
    assert(nearCf(target.z, 5_201_387.75, 0.01));

    // Equivalent Position Vector parameterization.
    const positionVector =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            0.0,
            0.0,
            4.5,
            0.0,
            0.0,
            +0.554,
            0.219);

    const convertedCf = toCoordinateFrame(positionVector);

    assert(convertedCf.translationX == positionVector.translationX);
    assert(convertedCf.translationY == positionVector.translationY);
    assert(convertedCf.translationZ == positionVector.translationZ);
    assert(convertedCf.scaleDifference == positionVector.scaleDifference);
    assert(convertedCf.rotationX.radians == -positionVector.rotationX.radians);
    assert(convertedCf.rotationY.radians == -positionVector.rotationY.radians);
    assert(convertedCf.rotationZ.radians == -positionVector.rotationZ.radians);

    const viaPv =
        applyPositionVectorHelmert(source, positionVector);
    const viaConvertedCf =
        applyCoordinateFrameHelmert(source, convertedCf);

    // The conversion changes representation, not the physical transform.
    assert(nearCf(viaPv.x, viaConvertedCf.x, 1e-9));
    assert(nearCf(viaPv.y, viaConvertedCf.y, 1e-9));
    assert(nearCf(viaPv.z, viaConvertedCf.z, 1e-9));

    const roundTripPv = toPositionVector(convertedCf);
    assert(roundTripPv.translationX == positionVector.translationX);
    assert(roundTripPv.translationY == positionVector.translationY);
    assert(roundTripPv.translationZ == positionVector.translationZ);
    assert(roundTripPv.rotationX.radians == positionVector.rotationX.radians);
    assert(roundTripPv.rotationY.radians == positionVector.rotationY.radians);
    assert(roundTripPv.rotationZ.radians == positionVector.rotationZ.radians);
    assert(roundTripPv.scaleDifference == positionVector.scaleDifference);

    // `.init` is also the identity for the Coordinate Frame specialization.
    const identity = applyCoordinateFrameHelmert(
        source,
        CoordinateFrameHelmert!double.init);
    assert(identity == source);

    // Positive Coordinate Frame rZ has the opposite effect to positive
    // Position Vector rZ: +X moves toward -Y in the linearized matrix.
    const zRotation =
        CoordinateFrameHelmert!double.fromCanonical(
            0.0, 0.0, 0.0,
            Angle!double.init,
            Angle!double.init,
            Angle!double.fromRadians(1.0e-6),
            0.0);

    const xAxis =
        GeocentricCoordinate!double.fromComponents(
            1_000_000.0, 0.0, 0.0);

    const rotated =
        applyCoordinateFrameHelmert(xAxis, zRotation);

    assert(nearCf(rotated.x, 1_000_000.0, 1e-9));
    assert(nearCf(rotated.y, -1.0, 1e-12));
    assert(nearCf(rotated.z, 0.0, 1e-12));

    // Generic scalar instantiation.
    const floatIdentity = applyCoordinateFrameHelmert(
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f),
        CoordinateFrameHelmert!float.init);
    assert(floatIdentity ==
        GeocentricCoordinate!float.fromComponents(1.0f, 2.0f, 3.0f));

    const realIdentity = applyCoordinateFrameHelmert(
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L),
        CoordinateFrameHelmert!real.init);
    assert(realIdentity ==
        GeocentricCoordinate!real.fromComponents(1.0L, 2.0L, 3.0L));

    // Finite parameters may still overflow during application.
    const hugeSource =
        GeocentricCoordinate!double.fromComponents(
            double.max, double.max, double.max);

    const hugeScale =
        CoordinateFrameHelmert!double.fromCanonical(
            0.0, 0.0, 0.0,
            Angle!double.init,
            Angle!double.init,
            Angle!double.init,
            double.max);

    GeocentricCoordinate!double candidate;
    assert(!tryApplyCoordinateFrameHelmert(
        hugeSource, hugeScale, candidate));

    assertThrown!GeodesyValueException(
        applyCoordinateFrameHelmert(
            hugeSource, hugeScale));
}
