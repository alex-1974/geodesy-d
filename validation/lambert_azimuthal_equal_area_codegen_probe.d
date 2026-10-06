module lambert_azimuthal_equal_area_codegen_probe;

import geodesy;

private LambertAzimuthalEqualArea!double projection()
    @safe
{
    return LambertAzimuthalEqualArea!double.fromParameters(
        wgs84!double(),
        Latitude!double.fromDegrees(52.0),
        Longitude!double.fromDegrees(10.0),
        4_321_000.0,
        3_210_000.0);
}

extern(C) double probe_laea_forward_easting(
    double latitude,
    double longitude)
    @safe
{
    return projection().forward(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitude),
            Longitude!double.fromDegrees(longitude))).easting;
}

extern(C) double probe_laea_forward_northing(
    double latitude,
    double longitude)
    @safe
{
    return projection().forward(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitude),
            Longitude!double.fromDegrees(longitude))).northing;
}

extern(C) double probe_laea_reverse_latitude(
    double easting,
    double northing)
    @safe
{
    return projection().reverse(
        ProjectedCoordinate!double.fromComponents(
            easting,
            northing)).latitude.degrees;
}
