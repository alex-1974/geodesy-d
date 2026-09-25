module reject_pseudo_mercator_conformal_factors;

import geodesy;

void main()
{
    const ellipsoid =
        Ellipsoid!double.sphere(
            6_378_137.0);

    const projection =
        PseudoMercator!double.fromParameters(
            ellipsoid,
            Longitude!double.init,
            0.0,
            0.0);

    const source =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.init,
            Longitude!double.init);

    auto factors =
        projection.forwardFactors(
            source);

    cast(void) factors;
}
