module reject_unchecked_topocentric_factory;

import geodesy;

enum leaked =
    TopocentricCoordinate!double.fromComponentsUnchecked(
        1.0,
        2.0,
        3.0);
