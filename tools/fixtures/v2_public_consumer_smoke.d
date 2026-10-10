// External-style smoke consumer for the documented package root.
// Compile-only: checks representative API usage without binding to internals.
module v2_public_consumer_smoke;

import geodesy;

void exercisePublicAPI()
{
    const earth = wgs84!double();

    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    const graz = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(47.07071),
        Longitude!double.fromDegrees(15.43950));

    // Common 2D mapping and navigation paths.
    const utm = forwardUtm(vienna, earth);
    const geodesic = Geodesic!double.fromEllipsoid(earth);
    const route = geodesic.inverse(vienna, graz);
    const rhumb = Rhumb!double.fromEllipsoid(earth);
    const rhumbRoute = rhumb.inverse(vienna, graz);

    // Explicit 3D coordinate conversion and checked/throwing symmetry.
    const position = GeodeticCoordinate!double.fromComponents(
        vienna.latitude, vienna.longitude, 171.0);
    GeocentricCoordinate!double checkedECEF;
    const ok = tryGeodeticToGeocentric(position, earth, checkedECEF);
    const throwingECEF = geodeticToGeocentric(position, earth);

    assert(ok);
    assert(utm.easting > 0);
    assert(route.distance > 0);
    assert(rhumbRoute.distance > 0);
    assert(throwingECEF.x == checkedECEF.x);
}
