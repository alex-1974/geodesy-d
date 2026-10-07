/**
 * PS-G release-codegen probe.
 *
 * Validation support only.  The exported C symbols give compiler/codegen
 * inspection a stable surface without adding library API.
 */
module polar_stereographic_codegen_probe;

import geodesy;

private PolarStereographic!double northProjection()
    @safe
{
    return PolarStereographic!double.fromParameters(
        wgs84!double(),
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0),
        0.994,
        2_000_000.0,
        2_000_000.0);
}

extern(C) double probe_ps_forward_easting(
    double latitudeDegrees,
    double longitudeDegrees)
    @safe
{
    const projection = northProjection();
    const result = projection.forward(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitudeDegrees),
            Longitude!double.fromDegrees(longitudeDegrees)));
    return result.easting;
}

extern(C) double probe_ps_reverse_latitude(
    double easting,
    double northing)
    @safe
{
    const projection = northProjection();
    const result = projection.reverse(
        ProjectedCoordinate!double.fromComponents(easting, northing));
    return result.latitude.degrees;
}

extern(C) double probe_ps_forward_scale(
    double latitudeDegrees,
    double longitudeDegrees)
    @safe
{
    const projection = northProjection();
    const result = projection.forwardFactors(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitudeDegrees),
            Longitude!double.fromDegrees(longitudeDegrees)));
    return result.pointScale;
}
