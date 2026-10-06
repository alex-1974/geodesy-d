#include <GeographicLib/Rhumb.hpp>

#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

using GeographicLib::Rhumb;

static double parseDouble(const char* text)
{
    char* end = nullptr;
    const double value = std::strtod(text, &end);
    if (!end || *end != '\0')
        throw std::runtime_error("invalid floating-point argument");
    return value;
}

int main(int argc, char** argv)
{
    try
    {
        if (argc < 5)
            throw std::runtime_error(
                "usage: oracle inverse|direct|line A F ...");

        const std::string mode = argv[1];
        const double a = parseDouble(argv[2]);
        const double f = parseDouble(argv[3]);
        const Rhumb rhumb(a, f, true);

        std::cout << std::setprecision(17);

        if (mode == "inverse" && argc == 8)
        {
            const double lat1 = parseDouble(argv[4]);
            const double lon1 = parseDouble(argv[5]);
            const double lat2 = parseDouble(argv[6]);
            const double lon2 = parseDouble(argv[7]);

            double distance, bearing;
            rhumb.Inverse(lat1, lon1, lat2, lon2, distance, bearing);

            std::cout << "OK\t"
                      << distance << '\t'
                      << bearing << '\n';
            return 0;
        }

        if ((mode == "direct" || mode == "line") && argc == 8)
        {
            const double lat1 = parseDouble(argv[4]);
            const double lon1 = parseDouble(argv[5]);
            const double bearing = parseDouble(argv[6]);
            const double distance = parseDouble(argv[7]);

            double lat2, lon2;

            if (mode == "direct")
                rhumb.Direct(lat1, lon1, bearing, distance, lat2, lon2);
            else
                rhumb.Line(lat1, lon1, bearing).Position(
                    distance, lat2, lon2);

            std::cout << "OK\t"
                      << lat2 << '\t'
                      << lon2 << '\n';
            return 0;
        }

        throw std::runtime_error("invalid oracle arguments");
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << '\n';
        return 2;
    }
}
