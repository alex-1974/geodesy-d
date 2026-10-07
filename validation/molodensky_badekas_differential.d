module validation.molodensky_badekas_differential;

import std.stdio : writefln;

import geodesy;

void main()
{
    const source = GeocentricCoordinate!double.fromComponents(
         2_550_408.965,
        -5_749_912.266,
         1_054_891.114);

    const cf = CoordinateFrameMolodenskyBadekas!double
        .fromArcSecondsAndPpm(
            -270.933, +115.599, -360.226,
            -5.266, -1.238, +2.381,
            -5.109,
             2_464_351.59,
            -5_783_466.61,
               974_809.81);

    const cfTarget = cf.apply(source);
    writefln("cf %.12f %.12f %.12f",
        cfTarget.x, cfTarget.y, cfTarget.z);

    const pv = toPositionVectorMolodenskyBadekas(cf);
    const pvTarget = pv.apply(source);
    writefln("pv %.12f %.12f %.12f",
        pvTarget.x, pvTarget.y, pvTarget.z);
}
