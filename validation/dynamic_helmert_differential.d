module validation.dynamic_helmert_differential;

import std.stdio : writefln;

import geodesy;

void main()
{
    const source = GeocentricCoordinate!double.fromComponents(
        -3_789_470.710,
         4_841_770.404,
        -1_690_893.952);
    const epoch = Epoch!double.fromDecimalYear(2013.90);
    const referenceEpoch = Epoch!double.fromDecimalYear(1994.00);

    const pv = PositionVectorHelmert14!double.fromArcSecondsAndPpm(
        -0.08468, -0.01942, +0.03201,
        +0.0004254, -0.0022578, -0.0024015,
        +0.00971,
        +0.00142, +0.00134, +0.00090,
        -0.0015461, -0.0011820, -0.0011551,
        +0.000109,
        referenceEpoch);

    const pvTarget = pv.apply(source, epoch);
    writefln("pv %.12f %.12f %.12f",
        pvTarget.x, pvTarget.y, pvTarget.z);

    const cf = toCoordinateFrameHelmert14(pv);
    const cfTarget = cf.apply(source, epoch);
    writefln("cf %.12f %.12f %.12f",
        cfTarget.x, cfTarget.y, cfTarget.z);
}
