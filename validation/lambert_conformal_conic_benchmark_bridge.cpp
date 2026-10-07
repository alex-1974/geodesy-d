#include <proj.h>

#include <cmath>
#include <cstdlib>

namespace {
PJ_CONTEXT* ctx = nullptr;
PJ* projection = nullptr;
}

extern "C" {

int lcc_bench_proj_init()
{
    ctx = proj_context_create();
    if (!ctx)
        return 0;

    projection = proj_create(
        ctx,
        "+proj=lcc +a=6378137 +rf=298.257223563 "
        "+lat_0=40 +lon_0=-96 +lat_1=33 +lat_2=45");

    return projection ? 1 : 0;
}

void lcc_bench_proj_destroy()
{
    if (projection)
        proj_destroy(projection);
    projection = nullptr;

    if (ctx)
        proj_context_destroy(ctx);
    ctx = nullptr;
}

double lcc_bench_proj_forward(
    double latitudeDegrees,
    double longitudeDegrees,
    double* northing)
{
    PJ_COORD input = proj_coord(
        longitudeDegrees * M_PI / 180.0,
        latitudeDegrees * M_PI / 180.0,
        0.0,
        0.0);

    const PJ_COORD output =
        proj_trans(projection, PJ_FWD, input);

    *northing = output.xy.y;
    return output.xy.x;
}

}
