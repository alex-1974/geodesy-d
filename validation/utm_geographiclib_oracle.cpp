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

static int parseInt(const char* text)
{
    char* end = nullptr;
    const long value = std::strtol(text, &end, 10);

    if (!end || *end != '\0')
        throw std::runtime_error(
            std::string("invalid integer argument: ") + text);

    return static_cast<int>(value);
}

static void forward(
    const double latitude,
    const double longitude,
    const int setzone)
{
    try
    {
        int zone;
        bool north;
        double easting;
        double northing;
        double gamma;
        double scale;

        UTMUPS::Forward(
            latitude,
            longitude,
            zone,
            north,
            easting,
            northing,
            gamma,
            scale,
            setzone);

        std::cout
            << "OK\t"
            << zone << '\t'
            << (north ? 1 : 0) << '\t'
            << std::setprecision(17)
            << easting << '\t'
            << northing
            << '\n';
    }
    catch (const std::exception&)
    {
        std::cout << "REJECT\n";
    }
}

int main(int argc, char** argv)
{
    try
    {
        if (argc < 4)
            throw std::runtime_error(
                "usage: oracle standard LAT LON | "
                "oracle explicit LAT LON ZONE");

        const std::string mode = argv[1];

        const double latitude =
            parseDouble(argv[2]);

        const double longitude =
            parseDouble(argv[3]);

        if (mode == "standard")
        {
            if (argc != 4)
                throw std::runtime_error(
                    "standard expects LAT LON");

            forward(
                latitude,
                longitude,
                UTMUPS::STANDARD);

            return 0;
        }

        if (mode == "explicit")
        {
            if (argc != 5)
                throw std::runtime_error(
                    "explicit expects LAT LON ZONE");

            forward(
                latitude,
                longitude,
                parseInt(argv[4]));

            return 0;
        }

        throw std::runtime_error(
            "unknown mode: " + mode);
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << '\n';
        return 2;
    }
}
