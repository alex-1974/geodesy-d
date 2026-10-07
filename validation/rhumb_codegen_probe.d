module rhumb_codegen_probe;

import geodesy;

private Rhumb!double solver() @safe
{
    return Rhumb!double.fromEllipsoid(wgs84!double());
}

extern(C) double probe_rhumb_inverse_distance(
    double lat1,
    double lon1,
    double lat2,
    double lon2)
    @safe
{
    const result = solver().inverse(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(lat1),
            Longitude!double.fromDegrees(lon1)),
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(lat2),
            Longitude!double.fromDegrees(lon2)));
    return result.distance;
}

extern(C) double probe_rhumb_direct_latitude(
    double lat,
    double lon,
    double bearing,
    double distance)
    @safe
{
    const result = solver().direct(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(lat),
            Longitude!double.fromDegrees(lon)),
        Angle!double.fromDegrees(bearing),
        distance);
    return result.position.latitude.degrees;
}

extern(C) double probe_rhumb_line_longitude(
    double lat,
    double lon,
    double bearing,
    double distance)
    @safe
{
    const start = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(lat),
        Longitude!double.fromDegrees(lon));
    const line = solver().line(
        start,
        Angle!double.fromDegrees(bearing));
    return line.position(distance).position.longitude.degrees;
}
