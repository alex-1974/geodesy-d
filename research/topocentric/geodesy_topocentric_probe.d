/**
 * Batch probe for differential validation of the public topocentric API.
 *
 * This program intentionally imports only public geodesy modules. It does not
 * access package/private working kernels.
 *
 * Invocation:
 *
 *   geodesy_topocentric_probe OP a f origin1 origin2 origin3
 *
 * OP:
 *   9836f  origin = X0 Y0 Z0; input  = X Y Z;       output = E N U
 *   9836r  origin = X0 Y0 Z0; input  = E N U;       output = X Y Z
 *   9837f  origin = lat lon h; input = lat lon h;   output = E N U
 *   9837r  origin = lat lon h; input = E N U;       output = lat lon h
 *
 * Angles at the process boundary are degrees.
 */
module geodesy_topocentric_probe;

import std.conv : to;
import std.stdio : stdin, stderr, writefln;
import std.string : split, strip;

import geodesy.angle :
    Latitude,
    Longitude;
import geodesy.ellipsoid :
    Ellipsoid;
import geodesy.geocentric :
    GeocentricCoordinate;
import geodesy.geodetic :
    GeodeticCoordinate;
import geodesy.topocentric :
    TopocentricCoordinate,
    TopocentricFrame;


private bool parseTriple(
    const string line,
    out double a,
    out double b,
    out double c)
{
    const fields = line.strip.split;

    if (fields.length != 3)
        return false;

    try
    {
        a = fields[0].to!double;
        b = fields[1].to!double;
        c = fields[2].to!double;
    }
    catch (Exception)
    {
        return false;
    }

    return true;
}


int main(string[] args)
{
    if (args.length != 7)
    {
        stderr.writefln(
            "usage: %s OP a f origin1 origin2 origin3",
            args[0]);
        return 2;
    }

    const operation = args[1];

    double semiMajorAxis;
    double flattening;
    double origin1;
    double origin2;
    double origin3;

    try
    {
        semiMajorAxis = args[2].to!double;
        flattening = args[3].to!double;
        origin1 = args[4].to!double;
        origin2 = args[5].to!double;
        origin3 = args[6].to!double;
    }
    catch (Exception)
    {
        stderr.writefln(
            "invalid command-line numeric argument");
        return 2;
    }

    Ellipsoid!double ellipsoid;

    if (!Ellipsoid!double.tryFromFlattening(
        semiMajorAxis,
        flattening,
        ellipsoid))
    {
        stderr.writefln("invalid ellipsoid");
        return 3;
    }

    TopocentricFrame!double frame;

    if (operation == "9836f"
        || operation == "9836r")
    {
        GeocentricCoordinate!double origin;

        if (!GeocentricCoordinate!double.tryFromComponents(
                origin1,
                origin2,
                origin3,
                origin)
            || !TopocentricFrame!double.tryFromGeocentricOrigin(
                ellipsoid,
                origin,
                frame))
        {
            stderr.writefln(
                "failed to prepare geocentric-origin frame");
            return 3;
        }
    }
    else if (operation == "9837f"
        || operation == "9837r")
    {
        Latitude!double latitude;
        Longitude!double longitude;
        GeodeticCoordinate!double origin;

        if (!Latitude!double.tryFromDegrees(
                origin1,
                latitude)
            || !Longitude!double.tryFromDegrees(
                origin2,
                longitude)
            || !GeodeticCoordinate!double.tryFromComponents(
                latitude,
                longitude,
                origin3,
                origin)
            || !TopocentricFrame!double.tryFromGeodeticOrigin(
                ellipsoid,
                origin,
                frame))
        {
            stderr.writefln(
                "failed to prepare geodetic-origin frame");
            return 3;
        }
    }
    else
    {
        stderr.writefln(
            "unknown operation: %s",
            operation);
        return 2;
    }

    size_t row = 0;

    foreach (line; stdin.byLineCopy())
    {
        ++row;

        if (line.strip.length == 0)
            continue;

        double a;
        double b;
        double c;

        if (!parseTriple(
            line,
            a,
            b,
            c))
        {
            stderr.writefln(
                "invalid input row %s",
                row);
            return 4;
        }

        if (operation == "9836f")
        {
            GeocentricCoordinate!double source;
            TopocentricCoordinate!double result;

            if (!GeocentricCoordinate!double.tryFromComponents(
                    a,
                    b,
                    c,
                    source)
                || !frame.tryGeocentricToTopocentric(
                    source,
                    result))
            {
                stderr.writefln(
                    "9836 forward failed at row %s",
                    row);
                return 5;
            }

            writefln(
                "%.17g %.17g %.17g",
                result.east,
                result.north,
                result.up);
        }
        else if (operation == "9836r")
        {
            TopocentricCoordinate!double source;
            GeocentricCoordinate!double result;

            if (!TopocentricCoordinate!double.tryFromComponents(
                    a,
                    b,
                    c,
                    source)
                || !frame.tryTopocentricToGeocentric(
                    source,
                    result))
            {
                stderr.writefln(
                    "9836 reverse failed at row %s",
                    row);
                return 5;
            }

            writefln(
                "%.17g %.17g %.17g",
                result.x,
                result.y,
                result.z);
        }
        else if (operation == "9837f")
        {
            Latitude!double latitude;
            Longitude!double longitude;
            GeodeticCoordinate!double source;
            TopocentricCoordinate!double result;

            if (!Latitude!double.tryFromDegrees(
                    a,
                    latitude)
                || !Longitude!double.tryFromDegrees(
                    b,
                    longitude)
                || !GeodeticCoordinate!double.tryFromComponents(
                    latitude,
                    longitude,
                    c,
                    source)
                || !frame.tryGeodeticToTopocentric(
                    source,
                    result))
            {
                stderr.writefln(
                    "9837 forward failed at row %s",
                    row);
                return 5;
            }

            writefln(
                "%.17g %.17g %.17g",
                result.east,
                result.north,
                result.up);
        }
        else
        {
            TopocentricCoordinate!double source;
            GeodeticCoordinate!double result;

            if (!TopocentricCoordinate!double.tryFromComponents(
                    a,
                    b,
                    c,
                    source)
                || !frame.tryTopocentricToGeodetic(
                    source,
                    result))
            {
                stderr.writefln(
                    "9837 reverse failed at row %s",
                    row);
                return 5;
            }

            writefln(
                "%.17g %.17g %.17g",
                result.latitude.degrees,
                result.longitude.degrees,
                result.ellipsoidalHeight);
        }
    }

    return 0;
}
