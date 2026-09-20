module reject_topocentric_coordinate_mutation;

import geodesy;

void main()
{
    auto coordinate =
        TopocentricCoordinate!double.fromComponents(
            1.0,
            2.0,
            3.0);

    coordinate.east = 4.0;
}
