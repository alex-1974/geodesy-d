#include <GeographicLib/Rhumb.hpp>

extern "C" {

double rhumb_bench_geographiclib_inverse(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double* bearing)
{
    const auto& rh = GeographicLib::Rhumb::WGS84();
    double distance, azi;
    rh.Inverse(lat1, lon1, lat2, lon2, distance, azi);
    *bearing = azi;
    return distance;
}

double rhumb_bench_geographiclib_direct(
    double lat,
    double lon,
    double bearing,
    double distance,
    double* lon2)
{
    const auto& rh = GeographicLib::Rhumb::WGS84();
    double lat2, outLon;
    rh.Direct(lat, lon, bearing, distance, lat2, outLon);
    *lon2 = outLon;
    return lat2;
}

}
