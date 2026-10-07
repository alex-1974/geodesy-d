#include <GeographicLib/PolarStereographic.hpp>

#include <cmath>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

using GeographicLib::PolarStereographic;

static double parseDouble(const char* text)
{
    char* end = nullptr;
    const double value = std::strtod(text, &end);
    if (!end || *end != '\0')
        throw std::runtime_error(std::string("invalid floating-point argument: ") + text);
    return value;
}

static double normalizeLongitude(double lon)
{
    while (lon >= 180.0) lon -= 360.0;
    while (lon < -180.0) lon += 360.0;
    return lon == 0.0 ? 0.0 : lon;
}

static PolarStereographic makeProjection(
    const std::string& mode,
    const double a,
    const double f,
    const double parameter)
{
    if (mode == "a")
        return PolarStereographic(a, f, parameter);

    if (mode == "b")
    {
        PolarStereographic projection(a, f, 1.0);
        projection.SetScale(std::fabs(parameter), 1.0);
        return projection;
    }

    throw std::runtime_error("mode must be 'a' or 'b'");
}

int main(int argc, char** argv)
{
    try
    {
        if (argc != 12)
            throw std::runtime_error(
                "usage: oracle MODE forward|reverse A F PARAM NORTHP LON0 FE FN V1 V2");

        const std::string mode = argv[1];
        const std::string direction = argv[2];
        const double a = parseDouble(argv[3]);
        const double f = parseDouble(argv[4]);
        const double parameter = parseDouble(argv[5]);
        const bool northp = std::string(argv[6]) == "1";
        const double lon0 = parseDouble(argv[7]);
        const double fe = parseDouble(argv[8]);
        const double fn = parseDouble(argv[9]);
        const double v1 = parseDouble(argv[10]);
        const double v2 = parseDouble(argv[11]);

        PolarStereographic projection =
            makeProjection(mode, a, f, parameter);

        std::cout << std::setprecision(17);

        if (direction == "forward")
        {
            const double lat = v1;
            const double lon = v2;
            double x, y, gamma, k;
            projection.Forward(
                northp,
                lat,
                normalizeLongitude(lon - lon0),
                x,
                y,
                gamma,
                k);

            std::cout << "OK\t"
                      << x + fe << '\t'
                      << y + fn << '\t'
                      << gamma << '\t'
                      << k << '\t'
                      << projection.CentralScale()
                      << '\n';
            return 0;
        }

        if (direction == "reverse")
        {
            const double easting = v1;
            const double northing = v2;
            double lat, lon, gamma, k;
            projection.Reverse(
                northp,
                easting - fe,
                northing - fn,
                lat,
                lon,
                gamma,
                k);

            std::cout << "OK\t"
                      << lat << '\t'
                      << normalizeLongitude(lon + lon0) << '\t'
                      << gamma << '\t'
                      << k << '\t'
                      << projection.CentralScale()
                      << '\n';
            return 0;
        }

        throw std::runtime_error("direction must be forward or reverse");
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << '\n';
        return 2;
    }
}
