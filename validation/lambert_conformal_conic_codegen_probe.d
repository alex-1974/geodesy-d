module lambert_conformal_conic_codegen_probe;

import geodesy;

private LambertConformalConic!double projection() @safe
{
    return LambertConformalConic!double.fromTwoStandardParallels(
        wgs84!double(),
        Latitude!double.fromDegrees(40.0),
        Longitude!double.fromDegrees(-96.0),
        Latitude!double.fromDegrees(33.0),
        Latitude!double.fromDegrees(45.0),
        0.0,
        0.0);
}

extern(C) double probe_lcc_forward_easting(
    double latitude,
    double longitude)
    @safe
{
    return projection().forward(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitude),
            Longitude!double.fromDegrees(longitude))).easting;
}

extern(C) double probe_lcc_reverse_latitude(
    double easting,
    double northing)
    @safe
{
    return projection().reverse(
        ProjectedCoordinate!double.fromComponents(
            easting,
            northing)).latitude.degrees;
}

extern(C) double probe_lcc_forward_scale(
    double latitude,
    double longitude)
    @safe
{
    return projection().forwardFactors(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitude),
            Longitude!double.fromDegrees(longitude))).pointScale;
}
