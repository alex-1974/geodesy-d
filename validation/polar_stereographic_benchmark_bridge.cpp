#include <GeographicLib/PolarStereographic.hpp>
#include <proj.h>

#include <cmath>
#include <cstddef>

using GeographicLib::PolarStereographic;

extern "C" {

double ps_bench_geographiclib_forward(
    double lat,
    double lon,
    double* northing)
{
    const auto& projection = PolarStereographic::UPS();
    double x, y, gamma, k;
    projection.Forward(true, lat, lon, x, y, gamma, k);
    *northing = y + 2000000.0;
    return x + 2000000.0;
}

double ps_bench_geographiclib_reverse(
    double easting,
    double northing,
    double* lon)
{
    const auto& projection = PolarStereographic::UPS();
    double lat, glLon, gamma, k;
    projection.Reverse(
        true,
        easting - 2000000.0,
        northing - 2000000.0,
        lat,
        glLon,
        gamma,
        k);
    *lon = glLon;
    return lat;
}

double ps_bench_proj_forward(
    double lat,
    double lon,
    double* northing)
{
    PJ_CONTEXT* context = proj_context_create();
    PJ* projection = proj_create(
        context,
        "+proj=stere +lat_0=90 +lon_0=0 +k_0=0.994 "
        "+x_0=2000000 +y_0=2000000 +ellps=WGS84");

    if (!projection) {
        proj_context_destroy(context);
        *northing = std::nan("");
        return std::nan("");
    }

    PJ_COORD input = proj_coord(
        lon * M_PI / 180.0,
        lat * M_PI / 180.0,
        0,
        0);
    PJ_COORD output = proj_trans(projection, PJ_FWD, input);

    proj_destroy(projection);
    proj_context_destroy(context);

    *northing = output.xy.y;
    return output.xy.x;
}

double ps_bench_proj_reverse(
    double easting,
    double northing,
    double* lon)
{
    PJ_CONTEXT* context = proj_context_create();
    PJ* projection = proj_create(
        context,
        "+proj=stere +lat_0=90 +lon_0=0 +k_0=0.994 "
        "+x_0=2000000 +y_0=2000000 +ellps=WGS84");

    if (!projection) {
        proj_context_destroy(context);
        *lon = std::nan("");
        return std::nan("");
    }

    PJ_COORD input = proj_coord(easting, northing, 0, 0);
    PJ_COORD output = proj_trans(projection, PJ_INV, input);

    proj_destroy(projection);
    proj_context_destroy(context);

    *lon = output.lp.lam * 180.0 / M_PI;
    return output.lp.phi * 180.0 / M_PI;
}

}
