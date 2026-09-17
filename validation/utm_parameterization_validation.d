module utm_parameterization_validation;

import std.format : format;
import std.stdio : writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;
import geodesy.projection.utm :
    UtmHemisphere,
    UtmProjection,
    UtmZone;


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


private T wrappedLongitudeDegrees(T)(
    T degrees)
{
    while (degrees < cast(T) -180)
        degrees += cast(T) 360;

    while (degrees > cast(T) 180)
        degrees -= cast(T) 360;

    return degrees;
}


private GeographicCoordinate!T point(T)(
    const T latitudeDegrees,
    const T longitudeDegrees)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(latitudeDegrees),
        Longitude!T.fromDegrees(longitudeDegrees));
}


private void validateParameters(T)()
{
    writeln("UTM-B parameters ", T.stringof);

    const ellipsoid = wgs84!T();

    foreach (zoneNumberRaw; 1 .. 61)
    {
        const uint zoneNumber =
            cast(uint) zoneNumberRaw;

        const zone =
            UtmZone.fromNumber(zoneNumber);

        foreach (hemisphere; [
            UtmHemisphere.north,
            UtmHemisphere.south])
        {
            UtmProjection!T projection;

            const bool ok =
                UtmProjection!T.tryFromZone(
                    ellipsoid,
                    zone,
                    hemisphere,
                    projection);

            const string prefix = format(
                "%s zone %s hemisphere %s",
                T.stringof,
                zoneNumber,
                hemisphere);

            expect(ok, prefix ~ " construction");

            if (!ok)
                continue;

            expect(
                projection.isValid,
                prefix ~ " isValid");

            expect(
                projection.zone.number == zoneNumber,
                prefix ~ " zone");

            expect(
                projection.hemisphere == hemisphere,
                prefix ~ " hemisphere");

            const auto expectedLat0 =
                Latitude!T.fromDegrees(cast(T) 0);

            const auto expectedLon0 =
                Longitude!T.fromDegrees(
                    cast(T) zone.centralMeridianDegrees);

            expect(
                projection.latitudeOfNaturalOrigin.radians
                    == expectedLat0.radians,
                prefix ~ " lat0");

            expect(
                projection.longitudeOfNaturalOrigin.radians
                    == expectedLon0.radians,
                prefix ~ " lon0");

            expect(
                projection.scaleFactorAtNaturalOrigin
                    == cast(T) 0.9996L,
                prefix ~ " k0");

            expect(
                projection.falseEasting
                    == cast(T) 500_000,
                prefix ~ " false easting");

            const T expectedFalseNorthing =
                hemisphere == UtmHemisphere.south
                    ? cast(T) 10_000_000
                    : cast(T) 0;

            expect(
                projection.falseNorthing
                    == expectedFalseNorthing,
                prefix ~ " false northing");

            const auto origin =
                GeographicCoordinate!T.fromComponents(
                    expectedLat0,
                    expectedLon0);

            ProjectedCoordinate!T projectedOrigin;

            expect(
                projection.tryForward(
                    origin,
                    projectedOrigin),
                prefix ~ " origin forward");

            expect(
                projectedOrigin.easting
                    == cast(T) 500_000,
                prefix ~ " origin easting");

            expect(
                projectedOrigin.northing
                    == expectedFalseNorthing,
                prefix ~ " origin northing");
        }
    }
}


private void validateDelegation(T)()
{
    writeln("UTM-B TM delegation ", T.stringof);

    const ellipsoid = wgs84!T();

    static immutable T[4] latitudeSamples = [
        cast(T) -40,
        cast(T) -20,
        cast(T) 20,
        cast(T) 60,
    ];

    static immutable T[4] longitudeOffsets = [
        cast(T) -2.5L,
        cast(T) -0.5L,
        cast(T) 0.5L,
        cast(T) 2.5L,
    ];

    foreach (zoneNumberRaw; 1 .. 61)
    {
        const uint zoneNumber =
            cast(uint) zoneNumberRaw;

        const zone =
            UtmZone.fromNumber(zoneNumber);

        foreach (hemisphere; [
            UtmHemisphere.north,
            UtmHemisphere.south])
        {
            const projection =
                UtmProjection!T.fromZone(
                    ellipsoid,
                    zone,
                    hemisphere);

            const generic =
                TransverseMercator!T.fromParameters(
                    projection.ellipsoid,
                    projection.latitudeOfNaturalOrigin,
                    projection.longitudeOfNaturalOrigin,
                    projection.scaleFactorAtNaturalOrigin,
                    projection.falseEasting,
                    projection.falseNorthing);

            foreach (index; 0 .. latitudeSamples.length)
            {
                const T latitudeDegrees =
                    latitudeSamples[index];

                const T longitudeDegrees =
                    wrappedLongitudeDegrees!T(
                        cast(T) zone.centralMeridianDegrees
                        + longitudeOffsets[index]);

                const source =
                    point!T(
                        latitudeDegrees,
                        longitudeDegrees);

                ProjectedCoordinate!T utmProjected;
                ProjectedCoordinate!T tmProjected;

                const bool utmOk =
                    projection.tryForward(
                        source,
                        utmProjected);

                const bool tmOk =
                    generic.tryForward(
                        source,
                        tmProjected);

                const string prefix = format(
                    "%s zone %s hemisphere %s sample %s",
                    T.stringof,
                    zoneNumber,
                    hemisphere,
                    index);

                expect(
                    utmOk == tmOk,
                    prefix ~ " forward status");

                expect(
                    utmOk,
                    prefix ~ " forward accepted");

                if (!utmOk || !tmOk)
                    continue;

                expect(
                    utmProjected.easting
                        == tmProjected.easting,
                    prefix ~ " exact easting delegation");

                expect(
                    utmProjected.northing
                        == tmProjected.northing,
                    prefix ~ " exact northing delegation");

                GeographicCoordinate!T utmReverse;
                GeographicCoordinate!T tmReverse;

                const bool utmReverseOk =
                    projection.tryReverse(
                        utmProjected,
                        utmReverse);

                const bool tmReverseOk =
                    generic.tryReverse(
                        tmProjected,
                        tmReverse);

                expect(
                    utmReverseOk == tmReverseOk,
                    prefix ~ " reverse status");

                expect(
                    utmReverseOk,
                    prefix ~ " reverse accepted");

                if (!utmReverseOk || !tmReverseOk)
                    continue;

                expect(
                    utmReverse.latitude.radians
                        == tmReverse.latitude.radians,
                    prefix ~ " exact reverse latitude delegation");

                expect(
                    utmReverse.longitude.radians
                        == tmReverse.longitude.radians,
                    prefix ~ " exact reverse longitude delegation");
            }
        }
    }
}


private void validateNeighboringZones(T)()
{
    writeln("UTM-B neighboring zones ", T.stringof);

    const ellipsoid = wgs84!T();
    const source = point!T(
        cast(T) 48,
        cast(T) 15);

    foreach (zoneNumber; [32u, 33u, 34u])
    {
        const zone =
            UtmZone.fromNumber(zoneNumber);

        const projection =
            UtmProjection!T.fromZone(
                ellipsoid,
                zone,
                UtmHemisphere.north);

        const generic =
            TransverseMercator!T.fromParameters(
                projection.ellipsoid,
                projection.latitudeOfNaturalOrigin,
                projection.longitudeOfNaturalOrigin,
                projection.scaleFactorAtNaturalOrigin,
                projection.falseEasting,
                projection.falseNorthing);

        ProjectedCoordinate!T utmProjected;
        ProjectedCoordinate!T tmProjected;

        const bool utmOk =
            projection.tryForward(
                source,
                utmProjected);

        const bool tmOk =
            generic.tryForward(
                source,
                tmProjected);

        const string prefix = format(
            "%s explicit neighboring zone %s",
            T.stringof,
            zoneNumber);

        expect(utmOk, prefix ~ " accepted");
        expect(utmOk == tmOk, prefix ~ " status equivalence");

        if (utmOk && tmOk)
        {
            expect(
                utmProjected.easting
                    == tmProjected.easting,
                prefix ~ " easting equivalence");

            expect(
                utmProjected.northing
                    == tmProjected.northing,
                prefix ~ " northing equivalence");
        }
    }
}


private void expectEllipsoidAccepted(T)(
    const Ellipsoid!T ellipsoid,
    const string label)
{
    UtmProjection!T projection;

    expect(
        UtmProjection!T.tryFromZone(
            ellipsoid,
            UtmZone.fromNumber(33),
            UtmHemisphere.north,
            projection),
        T.stringof ~ " " ~ label ~ " accepted");
}


private void expectEllipsoidRejected(T)(
    const Ellipsoid!T ellipsoid,
    const string label)
{
    UtmProjection!T projection;

    expect(
        !UtmProjection!T.tryFromZone(
            ellipsoid,
            UtmZone.fromNumber(33),
            UtmHemisphere.north,
            projection),
        T.stringof ~ " " ~ label ~ " rejected");
}


private void validateEllipsoidPolicy(T)()
{
    writeln("UTM-B ellipsoid policy ", T.stringof);

    expectEllipsoidRejected!T(
        Ellipsoid!T.init,
        "Ellipsoid.init");

    expectEllipsoidRejected!T(
        Ellipsoid!T.sphere(
            cast(T) 6_378_137),
        "sphere");

    expectEllipsoidRejected!T(
        Ellipsoid!T.fromFlattening(
            cast(T) 5_999_999,
            cast(T) (1.0L / 300.0L)),
        "a below profile");

    expectEllipsoidRejected!T(
        Ellipsoid!T.fromFlattening(
            cast(T) 7_000_001,
            cast(T) (1.0L / 300.0L)),
        "a above profile");

    expectEllipsoidRejected!T(
        Ellipsoid!T.fromFlattening(
            cast(T) 6_378_137,
            cast(T) 0.0101L),
        "flattening above profile");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromFlattening(
            cast(T) 6_000_000,
            cast(T) (1.0L / 300.0L)),
        "lower a boundary");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromFlattening(
            cast(T) 7_000_000,
            cast(T) 0.01L),
        "upper a/f boundary");

    expectEllipsoidAccepted!T(
        wgs84!T(),
        "WGS 84");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromInverseFlattening(
            cast(T) 6_378_137,
            cast(T) 298.257222101L),
        "GRS 80");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromInverseFlattening(
            cast(T) 6_377_563.396L,
            cast(T) 299.3249646L),
        "Airy 1830");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromInverseFlattening(
            cast(T) 6_377_397.155L,
            cast(T) 299.1528128L),
        "Bessel 1841");

    expectEllipsoidAccepted!T(
        Ellipsoid!T.fromInverseFlattening(
            cast(T) 6_378_388,
            cast(T) 297),
        "International 1924");

    UtmProjection!T projection;

    expect(
        !UtmProjection!T.tryFromZone(
            wgs84!T(),
            UtmZone.init,
            UtmHemisphere.north,
            projection),
        T.stringof ~ " invalid zone rejected");

    expect(
        !UtmProjection!T.tryFromZone(
            wgs84!T(),
            UtmZone.fromNumber(33),
            cast(UtmHemisphere) 255,
            projection),
        T.stringof ~ " invalid hemisphere rejected");
}


int main()
{
    writeln("UTM-B parameterization validation");
    writeln("===============================");

    validateParameters!float();
    validateParameters!double();
    validateParameters!real();

    validateDelegation!float();
    validateDelegation!double();
    validateDelegation!real();

    validateNeighboringZones!float();
    validateNeighboringZones!double();
    validateNeighboringZones!real();

    validateEllipsoidPolicy!float();
    validateEllipsoidPolicy!double();
    validateEllipsoidPolicy!real();

    writeln;
    writeln("checks=", checks);
    writeln("failures=", failures);

    if (failures == 0)
    {
        writeln("RESULT: UTM-B PASS");
        return 0;
    }

    writeln("RESULT: UTM-B FAIL");
    return 1;
}
