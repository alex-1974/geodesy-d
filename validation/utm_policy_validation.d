module utm_policy_validation;

import std.format : format;
import std.math : nextDown, nextUp;
import std.stdio : writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projection.utm :
    UtmCoordinate,
    UtmHemisphere,
    UtmZone,
    tryStandardUtmZone;


private size_t checks;
private size_t failures;


private void expect(const bool condition, const string label)
{
    ++checks;

    if (!condition)
    {
        ++failures;
        writeln("FAIL: ", label);
    }
}


private GeographicCoordinate!T pointDegrees(T)(
    const T latitudeDegrees,
    const T longitudeDegrees)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(latitudeDegrees),
        Longitude!T.fromDegrees(longitudeDegrees));
}


private GeographicCoordinate!T pointRadians(T)(
    const T latitudeRadians,
    const T longitudeRadians)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromRadians(latitudeRadians),
        Longitude!T.fromRadians(longitudeRadians));
}


private T latitudeRadians(T)(const T degrees)
{
    return Latitude!T.fromDegrees(degrees).radians;
}


private T longitudeRadians(T)(const T degrees)
{
    return Longitude!T.fromDegrees(degrees).radians;
}


private void expectSource(T)(
    const GeographicCoordinate!T source,
    const uint expectedZone,
    const UtmHemisphere expectedHemisphere,
    const string label)
{
    UtmZone zone;
    UtmHemisphere hemisphere;

    const bool ok =
        tryStandardUtmZone(source, zone, hemisphere);

    expect(ok, label ~ ": accepted");

    if (!ok)
        return;

    expect(
        zone.number == expectedZone,
        format(
            "%s: zone expected %s, got %s",
            label,
            expectedZone,
            zone.number));

    expect(
        hemisphere == expectedHemisphere,
        format(
            "%s: hemisphere expected %s, got %s",
            label,
            expectedHemisphere,
            hemisphere));
}


private void expectSelectionDegrees(T)(
    const T latitudeDegrees,
    const T longitudeDegrees,
    const uint expectedZone,
    const UtmHemisphere expectedHemisphere,
    const string label)
{
    expectSource!T(
        pointDegrees!T(latitudeDegrees, longitudeDegrees),
        expectedZone,
        expectedHemisphere,
        label);
}


private void expectSelectionRadians(T)(
    const T latitudeRadiansValue,
    const T longitudeRadiansValue,
    const uint expectedZone,
    const UtmHemisphere expectedHemisphere,
    const string label)
{
    expectSource!T(
        pointRadians!T(
            latitudeRadiansValue,
            longitudeRadiansValue),
        expectedZone,
        expectedHemisphere,
        label);
}


private void expectRejectedSource(T)(
    const GeographicCoordinate!T source,
    const string label)
{
    UtmZone zone;
    UtmHemisphere hemisphere;

    const bool ok =
        tryStandardUtmZone(source, zone, hemisphere);

    expect(!ok, label ~ ": rejected");
}


private void expectRejectedDegrees(T)(
    const T latitudeDegrees,
    const T longitudeDegrees,
    const string label)
{
    expectRejectedSource!T(
        pointDegrees!T(latitudeDegrees, longitudeDegrees),
        label);
}


private void expectRejectedRadians(T)(
    const T latitudeRadiansValue,
    const T longitudeRadiansValue,
    const string label)
{
    expectRejectedSource!T(
        pointRadians!T(
            latitudeRadiansValue,
            longitudeRadiansValue),
        label);
}


private void validateZoneType()
{
    writeln("UTM-A zone type");

    const initial = UtmZone.init;

    expect(!initial.isValid, "UtmZone.init invalid");
    expect(initial.number == 0, "UtmZone.init number sentinel");

    UtmZone zone;

    expect(!UtmZone.tryFromNumber(0, zone), "zone 0 rejected");
    expect(!UtmZone.tryFromNumber(61, zone), "zone 61 rejected");
    expect(
        !UtmZone.tryFromNumber(uint.max, zone),
        "uint.max rejected");

    foreach (number; 1 .. 61)
    {
        const uint zoneNumber = cast(uint) number;

        UtmZone current;

        expect(
            UtmZone.tryFromNumber(zoneNumber, current),
            format("zone %s accepted", zoneNumber));

        expect(
            current.isValid,
            format("zone %s valid", zoneNumber));

        expect(
            current.number == zoneNumber,
            format("zone %s number", zoneNumber));

        const int expectedCentralMeridian =
            6 * cast(int) zoneNumber - 183;

        expect(
            current.centralMeridianDegrees
                == expectedCentralMeridian,
            format(
                "zone %s central meridian expected %s, got %s",
                zoneNumber,
                expectedCentralMeridian,
                current.centralMeridianDegrees));
    }
}


private void validateCoordinateType(T)()
{
    writeln("UTM-A coordinate type ", T.stringof);

    const zone = UtmZone.fromNumber(33);

    UtmCoordinate!T coordinate;

    expect(
        UtmCoordinate!T.tryFromComponents(
            zone,
            UtmHemisphere.north,
            cast(T) 500_000,
            cast(T) 5_340_000,
            coordinate),
        T.stringof ~ " valid coordinate accepted");

    expect(
        coordinate.isValid,
        T.stringof ~ " coordinate valid");

    expect(
        coordinate.zone.number == 33,
        T.stringof ~ " coordinate zone");

    expect(
        coordinate.hemisphere == UtmHemisphere.north,
        T.stringof ~ " coordinate hemisphere");

    expect(
        coordinate.easting == cast(T) 500_000,
        T.stringof ~ " coordinate easting");

    expect(
        coordinate.northing == cast(T) 5_340_000,
        T.stringof ~ " coordinate northing");

    expect(
        !UtmCoordinate!T.init.isValid,
        T.stringof ~ " coordinate init invalid");

    UtmCoordinate!T rejected;

    expect(
        !UtmCoordinate!T.tryFromComponents(
            UtmZone.init,
            UtmHemisphere.north,
            cast(T) 0,
            cast(T) 0,
            rejected),
        T.stringof ~ " invalid zone rejected");

    expect(
        !UtmCoordinate!T.tryFromComponents(
            zone,
            cast(UtmHemisphere) 255,
            cast(T) 0,
            cast(T) 0,
            rejected),
        T.stringof ~ " invalid hemisphere rejected");

    expect(
        !UtmCoordinate!T.tryFromComponents(
            zone,
            UtmHemisphere.north,
            T.nan,
            cast(T) 0,
            rejected),
        T.stringof ~ " NaN easting rejected");

    expect(
        !UtmCoordinate!T.tryFromComponents(
            zone,
            UtmHemisphere.north,
            cast(T) 0,
            T.infinity,
            rejected),
        T.stringof ~ " infinite northing rejected");
}


private void validateScalarPolicy(T)()
{
    writeln("UTM-A standard policy ", T.stringof);

    const T zeroLatitude =
        latitudeRadians!T(cast(T) 0);

    /*
     * Every central meridian selects its own ordinary zone at the equator.
     */
    foreach (number; 1 .. 61)
    {
        const uint zoneNumber = cast(uint) number;

        const int centralMeridian =
            6 * cast(int) zoneNumber - 183;

        expectSelectionDegrees!T(
            cast(T) 0,
            cast(T) centralMeridian,
            zoneNumber,
            UtmHemisphere.north,
            format(
                "%s zone %s central meridian",
                T.stringof,
                zoneNumber));
    }

    /*
     * Ordinary boundaries.
     *
     * IMPORTANT:
     * The represented neighbours are taken after conversion to the canonical
     * stored unit, radians. Applying nextDown/nextUp in degrees and converting
     * afterwards can round back onto the exact boundary.
     */
    foreach (eastZone; 2 .. 61)
    {
        const uint expectedEast = cast(uint) eastZone;
        const uint expectedWest = expectedEast - 1;

        const int boundaryDegrees =
            -180 + 6 * cast(int) expectedWest;

        const T boundaryRadians =
            longitudeRadians!T(cast(T) boundaryDegrees);

        expectSelectionRadians!T(
            zeroLatitude,
            nextDown(boundaryRadians),
            expectedWest,
            UtmHemisphere.north,
            format(
                "%s boundary %s stored west-neighbor",
                T.stringof,
                boundaryDegrees));

        expectSelectionRadians!T(
            zeroLatitude,
            boundaryRadians,
            expectedEast,
            UtmHemisphere.north,
            format(
                "%s boundary %s exact",
                T.stringof,
                boundaryDegrees));

        expectSelectionRadians!T(
            zeroLatitude,
            nextUp(boundaryRadians),
            expectedEast,
            UtmHemisphere.north,
            format(
                "%s boundary %s stored east-neighbor",
                T.stringof,
                boundaryDegrees));
    }

    /*
     * Antimeridian canonicalization.
     */
    expectSelectionDegrees!T(
        cast(T) 0,
        cast(T) -180,
        1,
        UtmHemisphere.north,
        T.stringof ~ " -180 antimeridian");

    expectSelectionDegrees!T(
        cast(T) 0,
        cast(T) 180,
        1,
        UtmHemisphere.north,
        T.stringof ~ " +180 canonical antimeridian");

    const T plus180 =
        longitudeRadians!T(cast(T) 180);

    const T minus180 =
        longitudeRadians!T(cast(T) -180);

    expectSelectionRadians!T(
        zeroLatitude,
        nextDown(plus180),
        60,
        UtmHemisphere.north,
        T.stringof ~ " stored immediately below +180");

    expectSelectionRadians!T(
        zeroLatitude,
        nextUp(minus180),
        1,
        UtmHemisphere.north,
        T.stringof ~ " stored immediately above -180");

    /*
     * Standard UTM latitude boundaries.
     */
    const T lon15 =
        longitudeRadians!T(cast(T) 15);

    const T southLimit =
        latitudeRadians!T(cast(T) -80);

    const T northLimit =
        latitudeRadians!T(cast(T) 84);

    expectRejectedRadians!T(
        nextDown(southLimit),
        lon15,
        T.stringof ~ " stored immediately below -80");

    expectSelectionRadians!T(
        southLimit,
        lon15,
        33,
        UtmHemisphere.south,
        T.stringof ~ " exactly -80");

    expectSelectionRadians!T(
        nextUp(southLimit),
        lon15,
        33,
        UtmHemisphere.south,
        T.stringof ~ " stored immediately above -80");

    expectSelectionRadians!T(
        nextDown(northLimit),
        lon15,
        33,
        UtmHemisphere.north,
        T.stringof ~ " stored immediately below +84");

    expectRejectedRadians!T(
        northLimit,
        lon15,
        T.stringof ~ " exactly +84");

    expectRejectedRadians!T(
        nextUp(northLimit),
        lon15,
        T.stringof ~ " stored immediately above +84");

    /*
     * Hemisphere convention.
     */
    expectSelectionDegrees!T(
        cast(T) -1,
        cast(T) 15,
        33,
        UtmHemisphere.south,
        T.stringof ~ " south hemisphere");

    expectSelectionDegrees!T(
        cast(T) 0,
        cast(T) 15,
        33,
        UtmHemisphere.north,
        T.stringof ~ " equator north convention");

    expectSelectionDegrees!T(
        cast(T) 1,
        cast(T) 15,
        33,
        UtmHemisphere.north,
        T.stringof ~ " north hemisphere");

    /*
     * Norway.
     */
    const T lat56 =
        latitudeRadians!T(cast(T) 56);

    const T lat64 =
        latitudeRadians!T(cast(T) 64);

    const T lat60 =
        latitudeRadians!T(cast(T) 60);

    const T lon3 =
        longitudeRadians!T(cast(T) 3);

    const T lon12 =
        longitudeRadians!T(cast(T) 12);

    expectSelectionRadians!T(
        lat56,
        lon3,
        32,
        UtmHemisphere.north,
        T.stringof ~ " Norway southwest boundary");

    expectSelectionRadians!T(
        nextDown(lat64),
        nextDown(lon12),
        32,
        UtmHemisphere.north,
        T.stringof ~ " Norway northeast stored interior");

    expectSelectionRadians!T(
        nextDown(lat56),
        lon3,
        31,
        UtmHemisphere.north,
        T.stringof ~ " Norway stored below latitude band");

    expectSelectionRadians!T(
        lat64,
        lon3,
        31,
        UtmHemisphere.north,
        T.stringof ~ " Norway upper latitude boundary");

    expectSelectionRadians!T(
        lat60,
        nextDown(lon3),
        31,
        UtmHemisphere.north,
        T.stringof ~ " Norway stored west outside");

    expectSelectionRadians!T(
        lat60,
        lon3,
        32,
        UtmHemisphere.north,
        T.stringof ~ " Norway west exact");

    expectSelectionRadians!T(
        lat60,
        nextDown(lon12),
        32,
        UtmHemisphere.north,
        T.stringof ~ " Norway stored east interior");

    expectSelectionRadians!T(
        lat60,
        lon12,
        33,
        UtmHemisphere.north,
        T.stringof ~ " Norway east exact");

    /*
     * Svalbard.
     */
    const T lat72 =
        latitudeRadians!T(cast(T) 72);

    const T lat75 =
        latitudeRadians!T(cast(T) 75);

    const T lon0 =
        longitudeRadians!T(cast(T) 0);

    const T lon9 =
        longitudeRadians!T(cast(T) 9);

    const T lon21 =
        longitudeRadians!T(cast(T) 21);

    const T lon33 =
        longitudeRadians!T(cast(T) 33);

    const T lon42 =
        longitudeRadians!T(cast(T) 42);

    expectSelectionRadians!T(
        lat75,
        nextDown(lon0),
        30,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored immediately west of 0");

    expectSelectionRadians!T(
        lat75,
        lon0,
        31,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard 0 exact");

    expectSelectionRadians!T(
        lat75,
        nextDown(lon9),
        31,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored below 9");

    expectSelectionRadians!T(
        lat75,
        lon9,
        33,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard 9 exact");

    expectSelectionRadians!T(
        lat75,
        nextDown(lon21),
        33,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored below 21");

    expectSelectionRadians!T(
        lat75,
        lon21,
        35,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard 21 exact");

    expectSelectionRadians!T(
        lat75,
        nextDown(lon33),
        35,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored below 33");

    expectSelectionRadians!T(
        lat75,
        lon33,
        37,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard 33 exact");

    expectSelectionRadians!T(
        lat75,
        nextDown(lon42),
        37,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored below 42");

    expectSelectionRadians!T(
        lat75,
        lon42,
        38,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard 42 exact");

    /*
     * Svalbard latitude activation.
     *
     * Longitude 10 is ordinary zone 32 and special zone 33.
     */
    const T lon10 =
        longitudeRadians!T(cast(T) 10);

    expectSelectionRadians!T(
        nextDown(lat72),
        lon10,
        32,
        UtmHemisphere.north,
        T.stringof ~ " stored below Svalbard latitude band");

    expectSelectionRadians!T(
        lat72,
        lon10,
        33,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard latitude 72 exact");

    expectSelectionRadians!T(
        nextDown(northLimit),
        lon10,
        33,
        UtmHemisphere.north,
        T.stringof ~ " Svalbard stored immediately below 84");

    expectRejectedRadians!T(
        northLimit,
        lon10,
        T.stringof ~ " Svalbard latitude 84 rejected");
}


int main()
{
    writeln("UTM-A policy validation");
    writeln("=======================");

    validateZoneType();

    validateCoordinateType!float();
    validateCoordinateType!double();
    validateCoordinateType!real();

    validateScalarPolicy!float();
    validateScalarPolicy!double();
    validateScalarPolicy!real();

    writeln;
    writeln("checks=", checks);
    writeln("failures=", failures);

    if (failures == 0)
    {
        writeln("RESULT: UTM-A PASS");
        return 0;
    }

    writeln("RESULT: UTM-A FAIL");
    return 1;
}
