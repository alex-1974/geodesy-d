module validation.dynamic_helmert_scalar_validation;

import std.math : fabs;
import std.stdio : writeln;

import geodesy;

private void checkScalar(T)(const T tolerance)
{
    const refEpoch = Epoch!T.fromDecimalYear(cast(T) 2000);
    const obsEpoch = Epoch!T.fromDecimalYear(cast(T) 2020);

    const base = PositionVectorHelmert!T.fromCanonical(
        cast(T) 1,
        cast(T) -2,
        cast(T) 3,
        Angle!T.fromRadians(cast(T) 1e-6),
        Angle!T.fromRadians(cast(T) -2e-6),
        Angle!T.fromRadians(cast(T) 3e-6),
        cast(T) 4e-6);

    const dynamic = PositionVectorHelmert14!T.fromCanonical(
        base,
        cast(T) 0.001,
        cast(T) -0.002,
        cast(T) 0.003,
        cast(T) 1e-9,
        cast(T) -2e-9,
        cast(T) 3e-9,
        cast(T) 4e-10,
        refEpoch);

    const effective = dynamic.evaluate(obsEpoch);

    assert(fabs(effective.translationX - cast(T) 1.02) <= tolerance);
    assert(fabs(effective.translationY - cast(T) -2.04) <= tolerance);
    assert(fabs(effective.translationZ - cast(T) 3.06) <= tolerance);

    const expectedRx = cast(T) (1e-6 + 20e-9);
    const expectedRy = cast(T) (-2e-6 - 40e-9);
    const expectedRz = cast(T) (3e-6 + 60e-9);
    const expectedDs = cast(T) (4e-6 + 8e-9);

    assert(fabs(effective.rotationX.radians - expectedRx) <= tolerance);
    assert(fabs(effective.rotationY.radians - expectedRy) <= tolerance);
    assert(fabs(effective.rotationZ.radians - expectedRz) <= tolerance);
    assert(fabs(effective.scaleDifference - expectedDs) <= tolerance);

    const cf = toCoordinateFrameHelmert14(dynamic);
    const pvAgain = toPositionVectorHelmert14(cf);

    assert(pvAgain.translationRateX == dynamic.translationRateX);
    assert(pvAgain.translationRateY == dynamic.translationRateY);
    assert(pvAgain.translationRateZ == dynamic.translationRateZ);
    assert(pvAgain.rotationRateX == dynamic.rotationRateX);
    assert(pvAgain.rotationRateY == dynamic.rotationRateY);
    assert(pvAgain.rotationRateZ == dynamic.rotationRateZ);
    assert(pvAgain.scaleDifferenceRate == dynamic.scaleDifferenceRate);
    assert(pvAgain.referenceEpoch.decimalYear == dynamic.referenceEpoch.decimalYear);
}

void main()
{
    checkScalar!float(2e-6f);
    checkScalar!double(1e-12);
    checkScalar!real(1e-12L);

    writeln("dynamic Helmert scalar/platform validation PASS");
}
