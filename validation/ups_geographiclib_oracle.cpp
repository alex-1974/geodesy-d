#include <GeographicLib/UTMUPS.hpp>

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

using GeographicLib::UTMUPS;

static double parseDouble(const char* text)
{
    char* end = nullptr;
    const double value = std::strtod(text, &end);
    if (!end || *end != '\0')
        throw std::runtime_error(
            std::string("invalid floating-point argument: ") + text);
    return value;
}

int main(int argc, char** argv)
{
    try
    {
        std::cout << std::setprecision(17);

        if (argc == 5 && std::string(argv[1]) == "standard")
        {
            const double lat = parseDouble(argv[2]);
            const double lon = parseDouble(argv[3]);
            const int zone = UTMUPS::StandardZone(lat, lon);
            std::cout << "OK\t" << zone << '\n';
            return 0;
        }

        if (argc == 5 && std::string(argv[1]) == "forward")
        {
            const double lat = parseDouble(argv[2]);
            const double lon = parseDouble(argv[3]);

            int zone;
            bool northp;
            double x, y, gamma, k;

            UTMUPS::Forward(
                lat,
                lon,
                zone,
                northp,
                x,
                y,
                gamma,
                k,
                UTMUPS::UPS,
                false);

            std::cout << "OK\t"
                      << zone << '\t'
                      << (northp ? 1 : 0) << '\t'
                      << x << '\t'
                      << y << '\t'
                      << gamma << '\t'
                      << k << '\n';
            return 0;
        }

        if (argc == 6 && std::string(argv[1]) == "reverse")
        {
            const bool northp = std::string(argv[2]) == "1";
            const double x = parseDouble(argv[3]);
            const double y = parseDouble(argv[4]);

            double lat, lon, gamma, k;

            UTMUPS::Reverse(
                UTMUPS::UPS,
                northp,
                x,
                y,
                lat,
                lon,
                gamma,
                k,
                false);

            std::cout << "OK\t"
                      << lat << '\t'
                      << lon << '\t'
                      << gamma << '\t'
                      << k << '\n';
            return 0;
        }

        throw std::runtime_error(
            "usage: oracle standard LAT LON X | "
            "forward LAT LON X | reverse NORTHP E N X");
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << '\n';
        return 2;
    }
}
