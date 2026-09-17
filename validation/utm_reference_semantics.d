module utm_reference_semantics;

/*
 * UTM-C1 — authoritative semantic validation.
 *
 * GeographicLib is used as the independent oracle for:
 *
 * - standard UTM/UPS latitude selection;
 * - antimeridian zone selection;
 * - Norway and Svalbard exceptions;
 * - hemisphere selection;
 * - explicit-zone acceptance and the 60 degree TM distance limit.
 *
 * PROJ is used to classify ellipsoid-policy agreement/divergence.
 *
 * Neither external implementation is a build/runtime dependency of
 * geodesy-d. They are validation-only dependencies.
 */

import std.conv : to;
import std.format : format;
import std.process : executeShell;
import std.stdio : writefln, writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.utm :
    UtmHemisphere,
    UtmProjection,
    UtmZone,
    tryStandardUtmZone;


private size_t checks;
private size_t failures;


private void expect(
    const bool condition,
    const string label)
{
    ++checks;

    if (!condition)
    {
        ++failures;
        writeln("FAIL: ", label);
    }
}


private struct ReferenceResult
{
    bool accepted;
    int zone;
    bool north;
    double easting;
    double northing;
}


private ReferenceResult runReference(
    const string oracle,
    const string mode,
    const string latitude,
    const string longitude,
    const int zone = 0)
{
    string command;

    if (mode == "standard")
    {
        command = format(
            "%s standard %s %s",
            oracle,
            latitude,
            longitude);
    }
    else
    {
        command = format(
            "%s explicit %s %s %s",
            oracle,
            latitude,
            longitude,
            zone);
    }

    const output =
        executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "GeographicLib oracle failed: %s\n%s",
                command,
                output.output));

    const text =
        output.output.strip;

    if (text == "REJECT")
        return ReferenceResult(false);

    const fields =
        text.split;

    if (fields.length != 5
        || fields[0] != "OK")
        throw new Exception(
            "unexpected GeographicLib oracle output: "
            ~ output.output);

    return ReferenceResult(
        true,
        fields[1].to!int,
        fields[2].to!int != 0,
        fields[3].to!double,
        fields[4].to!double);
}


private ReferenceResult runStandard(
    const string oracle,
    const double latitude,
    const double longitude)
{
    return runReference(
        oracle,
        "standard",
        format("%.17g", latitude),
        format("%.17g", longitude));
}


private GeographicCoordinate!double point(
    const double latitude,
    const double longitude)
{
    return GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(latitude),
        Longitude!double.fromDegrees(longitude));
}


private void validateStandardPolicy(
    const string oracle)
{
    writeln("UTM-C1 GeographicLib standard policy");

    struct Case
    {
        double latitude;
        double longitude;
        string label;
    }

    const cases = [
        Case(-80.000001, 15, "below -80"),
        Case(-80.0,      15, "exact -80"),
        Case(83.999999,  15, "below 84"),
        Case(84.0,       15, "exact 84"),

        Case(0.0, -180.0, "antimeridian -180"),
        Case(0.0,  180.0, "antimeridian +180"),

        Case(55.999999, 3, "Norway below 56"),
        Case(56.0,      3, "Norway exact 56"),
        Case(63.999999, 3, "Norway below 64"),
        Case(64.0,      3, "Norway exact 64"),

        Case(71.999999, 9, "Svalbard below 72"),

        Case(72.0,  0.0,       "Svalbard 0"),
        Case(72.0,  8.999999,  "Svalbard below 9"),
        Case(72.0,  9.0,       "Svalbard exact 9"),
        Case(72.0, 20.999999,  "Svalbard below 21"),
        Case(72.0, 21.0,       "Svalbard exact 21"),
        Case(72.0, 32.999999,  "Svalbard below 33"),
        Case(72.0, 33.0,       "Svalbard exact 33"),
        Case(72.0, 41.999999,  "Svalbard below 42"),
        Case(72.0, 42.0,       "Svalbard exact 42"),
    ];

    foreach (test; cases)
    {
        const reference =
            runStandard(
                oracle,
                test.latitude,
                test.longitude);

        UtmZone oursZone;
        UtmHemisphere oursHemisphere;

        const oursAccepted =
            tryStandardUtmZone(
                point(
                    test.latitude,
                    test.longitude),
                oursZone,
                oursHemisphere);

        const referenceIsUtm =
            reference.accepted
            && reference.zone >= 1
            && reference.zone <= 60;

        expect(
            oursAccepted == referenceIsUtm,
            test.label ~ " acceptance");

        if (!oursAccepted
            || !referenceIsUtm)
            continue;

        expect(
            oursZone.number == reference.zone,
            format(
                "%s zone ours=%s reference=%s",
                test.label,
                oursZone.number,
                reference.zone));

        expect(
            (oursHemisphere == UtmHemisphere.north)
                == reference.north,
            test.label ~ " hemisphere");
    }
}


private void validateSignedZeroPolicy(
    const string oracle)
{
    writeln("UTM-C1 signed-zero policy");

    /*
     * GeographicLib deliberately uses signbit(latitude), so -0.0 selects
     * the southern hemisphere.
     *
     * geodesy-d deliberately canonicalizes mathematical latitude zero to
     * north. This is a documented policy divergence rather than a
     * numerical discrepancy.
     */
    const reference =
        runReference(
            oracle,
            "standard",
            "-0",
            "15");

    expect(
        reference.accepted,
        "GeographicLib -0 accepted");

    expect(
        reference.zone == 33,
        "GeographicLib -0 zone 33");

    expect(
        !reference.north,
        "GeographicLib -0 selects south");

    const source =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-0.0),
            Longitude!double.fromDegrees(15.0));

    UtmZone zone;
    UtmHemisphere hemisphere;

    expect(
        tryStandardUtmZone(
            source,
            zone,
            hemisphere),
        "geodesy-d -0 accepted");

    expect(
        zone.number == 33,
        "geodesy-d -0 zone 33");

    expect(
        hemisphere == UtmHemisphere.north,
        "geodesy-d canonical zero selects north");

    writeln(
        "  documented divergence: "
        ~ "GeographicLib -0 -> south; geodesy-d zero -> north");
}


private void validateExplicitZoneSemantics(
    const string oracle)
{
    writeln("UTM-C1 explicit zone semantics");

    const ellipsoid =
        wgs84!double();

    const zone =
        UtmZone.fromNumber(33);

    const projection =
        UtmProjection!double.fromZone(
            ellipsoid,
            zone,
            UtmHemisphere.north);

    struct Case
    {
        double latitude;
        double longitude;
        bool referenceExpectedAccepted;
        string label;
    }

    const cases = [
        Case(84.0,   15.0, true,  "explicit 84"),
        Case(85.0,   15.0, true,  "explicit 85"),
        Case(48.0,    9.0, true,  "neighboring zone"),
        Case(10.0, 75.001, false, "outside +60 TM domain"),
    ];

    foreach (test; cases)
    {
        const reference =
            runReference(
                oracle,
                "explicit",
                format("%.17g", test.latitude),
                format("%.17g", test.longitude),
                33);

        expect(
            reference.accepted
                == test.referenceExpectedAccepted,
            test.label ~ " GeographicLib expected state");

        ProjectedCoordinate!double projected;

        const oursAccepted =
            projection.tryForward(
                point(
                    test.latitude,
                    test.longitude),
                projected);

        expect(
            oursAccepted == reference.accepted,
            test.label ~ " geodesy-d/GeographicLib acceptance");
    }

/*
 * GeographicLib UTMUPS additionally constrains legal projected
 * coordinates with CheckCoords(). At sufficiently high northern
 * latitudes an explicitly selected UTM zone can therefore be rejected
 * even though the underlying fixed Transverse Mercator projection is
 * mathematically valid.
 *
 * geodesy-d deliberately does not adopt this UTMUPS/MGRS-oriented
 * projected-coordinate legality window. UtmProjection remains a thin
 * fixed-zone wrapper over the bounded generic TM implementation.
 */
const reference89 =
    runReference(
        oracle,
        "explicit",
        "89",
        "15",
        33);

expect(
    !reference89.accepted,
    "explicit 89 GeographicLib UTMUPS coordinate-window rejection");

ProjectedCoordinate!double projected89;

expect(
    projection.tryForward(
        point(89.0, 15.0),
        projected89),
    "explicit 89 geodesy-d fixed-TM acceptance");

writeln(
    "  documented divergence: GeographicLib UTMUPS projected-"
    ~ "coordinate window rejects 89N; geodesy-d fixed TM accepts");
}




private bool projAccepts(
    const string ellipsoidParameters)
{
    const command = format(
        "printf '15 48\\n' | "
        ~ "proj +proj=utm +zone=33 %s "
        ~ ">/dev/null 2>&1",
        ellipsoidParameters);

    return executeShell(command).status == 0;
}


private void validateEllipsoidPolicy()
{
    writeln("UTM-C1 ellipsoid policy");

    const zone =
        UtmZone.fromNumber(33);

    UtmProjection!double projection;

    const grs80 =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257222101);

    expect(
        projAccepts("+ellps=GRS80"),
        "PROJ accepts GRS80 UTM");

    expect(
        UtmProjection!double.tryFromZone(
            grs80,
            zone,
            UtmHemisphere.north,
            projection),
        "geodesy-d accepts GRS80 UTM");

    const sphere =
        Ellipsoid!double.sphere(
            6_371_000.0);

    expect(
        !projAccepts("+R=6371000"),
        "PROJ rejects spherical UTM");

    expect(
        !UtmProjection!double.tryFromZone(
            sphere,
            zone,
            UtmHemisphere.north,
            projection),
        "geodesy-d rejects spherical UTM");

    /*
     * PROJ accepts arbitrary ellipsoid sizes. geodesy-d deliberately adds
     * an Earth-size/metre safety profile because Ellipsoid.a carries no
     * unit metadata while UTM false offsets are fixed in metres.
     */
    const large =
        Ellipsoid!double.fromInverseFlattening(
            8_000_000.0,
            300.0);

    expect(
        projAccepts("+a=8000000 +rf=300"),
        "PROJ accepts a=8000000");

    expect(
        !UtmProjection!double.tryFromZone(
            large,
            zone,
            UtmHemisphere.north,
            projection),
        "geodesy-d rejects a=8000000 safety-policy case");

    const kilometreScale =
        Ellipsoid!double.fromInverseFlattening(
            6_378.137,
            298.257223563);

    expect(
        projAccepts(
            "+a=6378.137 +rf=298.257223563"),
        "PROJ accepts kilometre-scale a");

    expect(
        !UtmProjection!double.tryFromZone(
            kilometreScale,
            zone,
            UtmHemisphere.north,
            projection),
        "geodesy-d rejects kilometre-scale unit-mistake case");

    writeln(
        "  documented divergence: Earth-size restriction is "
        ~ "geodesy-d safety policy, not UTM standard policy");
}


void main(string[] args)
{
    if (args.length != 2)
        throw new Exception(
            "usage: utm-reference-semantics "
            ~ "<GeographicLib oracle>");

    writeln("UTM-C1 authoritative semantic validation");
    writeln("========================================");

    validateStandardPolicy(args[1]);
    validateSignedZeroPolicy(args[1]);
    validateExplicitZoneSemantics(args[1]);
    validateEllipsoidPolicy();

    writeln;
    writefln(
        "checks=%s",
        checks);

    writefln(
        "failures=%s",
        failures);

    if (failures == 0)
    {
        writeln("RESULT: UTM-C1 PASS");
        return;
    }

    writeln("RESULT: UTM-C1 FAIL");
    throw new Exception(
        format(
            "UTM-C1 failed with %s failures",
            failures));
}
