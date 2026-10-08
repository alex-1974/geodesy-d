#include <GeographicLib/Geodesic.hpp>
#include <GeographicLib/PolygonArea.hpp>

#include <cmath>
#include <cstddef>

extern "C"
int r69_direct_quantities(
    double a,
    double f,
    double lat1,
    double lon1,
    double azi1,
    double s12,
    double* lat2,
    double* lon2,
    double* azi2,
    double* m12,
    double* M12,
    double* M21,
    double* S12)
{
    if (!lat2 || !lon2 || !azi2 || !m12 || !M12 || !M21 || !S12)
        return 0;

    try {
        const GeographicLib::Geodesic geod(a, f);
        geod.Direct(
            lat1, lon1, azi1, s12,
            *lat2, *lon2, *azi2,
            *m12, *M12, *M21, *S12);

        return std::isfinite(*lat2)
            && std::isfinite(*lon2)
            && std::isfinite(*azi2)
            && std::isfinite(*m12)
            && std::isfinite(*M12)
            && std::isfinite(*M21)
            && std::isfinite(*S12);
    } catch (...) {
        return 0;
    }
}

extern "C"
int r69_inverse_quantities(
    double a,
    double f,
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double* s12,
    double* azi1,
    double* azi2,
    double* m12,
    double* M12,
    double* M21,
    double* S12)
{
    if (!s12 || !azi1 || !azi2 || !m12 || !M12 || !M21 || !S12)
        return 0;

    try {
        const GeographicLib::Geodesic geod(a, f);
        geod.Inverse(
            lat1, lon1, lat2, lon2,
            *s12, *azi1, *azi2,
            *m12, *M12, *M21, *S12);

        return std::isfinite(*s12)
            && std::isfinite(*azi1)
            && std::isfinite(*azi2)
            && std::isfinite(*m12)
            && std::isfinite(*M12)
            && std::isfinite(*M21)
            && std::isfinite(*S12);
    } catch (...) {
        return 0;
    }
}

extern "C"
int r69_polygon(
    double a,
    double f,
    const double* lats,
    const double* lons,
    std::size_t count,
    double* perimeter,
    double* area)
{
    if (!lats || !lons || !perimeter || !area || count == 0)
        return 0;

    try {
        const GeographicLib::Geodesic geod(a, f);
        GeographicLib::PolygonArea polygon(geod, false);

        for (std::size_t i = 0; i < count; ++i)
            polygon.AddPoint(lats[i], lons[i]);

        const auto n =
            polygon.Compute(false, true, *perimeter, *area);

        return n == count
            && std::isfinite(*perimeter)
            && std::isfinite(*area);
    } catch (...) {
        return 0;
    }
}
