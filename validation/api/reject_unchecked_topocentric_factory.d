module reject_unchecked_topocentric_factory;

import geodesy.topocentric :
    TopocentricCoordinate;

enum leaked =
    TopocentricCoordinate!double.fromComponentsUnchecked(
        1.0,
        2.0,
        3.0);
