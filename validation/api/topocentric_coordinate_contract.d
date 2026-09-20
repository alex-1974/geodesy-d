module topocentric_coordinate_contract;

import geodesy.topocentric :
    TopocentricCoordinate;


static assert(is(TopocentricCoordinate!float));
static assert(is(TopocentricCoordinate!double));
static assert(is(TopocentricCoordinate!real));


private void checkedTopocentricCoordinateContract()
    pure nothrow @safe @nogc
{
    TopocentricCoordinate!double coordinate;

    const bool success =
        TopocentricCoordinate!double.tryFromComponents(
            east: 1.0,
            north: 2.0,
            up: 3.0,
            result: coordinate);

    const east = coordinate.east;
    const north = coordinate.north;
    const up = coordinate.up;

    const zero =
        TopocentricCoordinate!double.init;

    cast(void) success;
    cast(void) east;
    cast(void) north;
    cast(void) up;
    cast(void) zero;
}


private void throwingTopocentricCoordinateContract()
    @safe
{
    const coordinate =
        TopocentricCoordinate!double.fromComponents(
            east: 1.0,
            north: 2.0,
            up: 3.0);

    cast(void) coordinate;
}
