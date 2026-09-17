module utm_boundary_property;

import std.format : format;
import std.math : PI, cos, fabs, sqrt;
import std.stdio : writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.utm :
    UtmCoordinate,
    UtmHemisphere,
    UtmProjection,
    UtmZone,
    tryForwardUtm,
    tryReverseUtm,
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


private GeographicCoordinate!T point(T)(
    const T latitudeDegrees,
    const T longitudeDegrees)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(latitudeDegrees),
        Longitude!T.fromDegrees(longitudeDegrees));
}


private T normalizeDeltaLongitude(T)(T delta)
{
    const T pi = cast(T) PI;
    const T twoPi = cast(T) 2 * pi;

    while (delta >= pi)
        delta -= twoPi;

    while (delta < -pi)
        delta += twoPi;

    return delta;
}


private real groundResidualMetres(T)(
    const Ellipsoid!T ellipsoid,
    const GeographicCoordinate!T expected,
    const GeographicCoordinate!T actual)
{
    const real a =
        cast(real) ellipsoid.semiMajorAxis;

    const real latitude =
        cast(real) expected.latitude.radians;

    const real dLatitude =
        cast(real) actual.latitude.radians
        - cast(real) expected.latitude.radians;

    const real dLongitude =
        cast(real) normalizeDeltaLongitude!T(
            actual.longitude.radians
            - expected.longitude.radians);

    const real north =
        a * dLatitude;

    const real east =
        a * cos(latitude) * dLongitude;

    return sqrt(north * north + east * east);
}


private real scalarBudget(T)()
{
    /*
     * Accepted one-operation numerical contract inherited from generic TM.
     */
    static if (is(T == float))
        return 2.0L;
    else
        return 0.001L;
}


private real roundTripBudget(T)()
{
    /*
     * A forward/reverse round trip contains two independently rounded
     * projection operations. The one-operation reference budget therefore
     * must not be reused unchanged as a round-trip bound.
     */
    return 2.0L * scalarBudget!T();
}


private void validateAutomaticProperties(T)()
{
    writeln("UTM-D automatic properties ", T.stringof);

    const ellipsoid = wgs84!T();

    static immutable real[18] latitudes = [
        -80.0L,
        -79.0L,
        -60.0L,
        -20.0L,
        -0.1L,
        0.0L,
        0.1L,
        20.0L,
        55.0L,
        56.0L,
        63.0L,
        64.0L,
        71.0L,
        72.0L,
        75.0L,
        80.0L,
        83.0L,
        83.9L,
    ];

    static immutable real[24] longitudes = [
        -180.0L,
        -174.0L,
        -120.0L,
        -6.0L,
        -0.1L,
        0.0L,
        2.9L,
        3.0L,
        5.9L,
        6.0L,
        8.9L,
        9.0L,
        10.0L,
        11.9L,
        12.0L,
        20.9L,
        21.0L,
        32.9L,
        33.0L,
        41.9L,
        42.0L,
        126.0L,
        174.0L,
        179.9L,
    ];

    foreach (latitudeRaw; latitudes)
    {
        foreach (longitudeRaw; longitudes)
        {
            const auto source = point!T(
                cast(T) latitudeRaw,
                cast(T) longitudeRaw);

            UtmZone expectedZone;
            UtmHemisphere expectedHemisphere;

            const bool policyOk =
                tryStandardUtmZone(
                    source,
                    expectedZone,
                    expectedHemisphere);

            UtmCoordinate!T projected;

            const bool forwardOk =
                tryForwardUtm(
                    ellipsoid,
                    source,
                    projected);

            const string prefix = format(
                "%s lat=%s lon=%s",
                T.stringof,
                latitudeRaw,
                longitudeRaw);

            expect(
                forwardOk == policyOk,
                prefix ~ " forward/policy status");

            if (!forwardOk)
                continue;

            expect(
                projected.isValid,
                prefix ~ " tagged coordinate valid");

            expect(
                projected.zone.number
                    == expectedZone.number,
                prefix ~ " standard zone preserved");

            expect(
                projected.hemisphere
                    == expectedHemisphere,
                prefix ~ " standard hemisphere preserved");

            GeographicCoordinate!T reversed;

            expect(
                tryReverseUtm(
                    ellipsoid,
                    projected,
                    reversed),
                prefix ~ " reverse accepted");

            if (!tryReverseUtm(
                    ellipsoid,
                    projected,
                    reversed))
                continue;

            const real residual =
                groundResidualMetres(
                    ellipsoid,
                    source,
                    reversed);

            expect(
                residual <= roundTripBudget!T(),
                format(
                    "%s round-trip residual %s m <= %s m",
                    prefix,
                    residual,
                    roundTripBudget!T()));
        }
    }
}


private void validateLatitudeSemantics(T)()
{
    writeln("UTM-D latitude semantics ", T.stringof);

    const ellipsoid = wgs84!T();

    /*
     * Automatic standard UTM selection owns the conventional
     * lower-closed, upper-open latitude band.
     */
    struct AutomaticCase
    {
        T latitudeDegrees;
        bool expectedAccepted;
        string label;
    }

    const automaticCases = [
        AutomaticCase(
            cast(T) -80.0001,
            false,
            "below -80"),
        AutomaticCase(
            cast(T) -80,
            true,
            "exact -80"),
        AutomaticCase(
            cast(T) -79.9999,
            true,
            "above -80"),
        AutomaticCase(
            cast(T) 83.9999,
            true,
            "below 84"),
        AutomaticCase(
            cast(T) 84,
            false,
            "exact 84"),
        AutomaticCase(
            cast(T) 84.0001,
            false,
            "above 84"),
    ];

    foreach (test; automaticCases)
    {
        const auto source =
            point!T(
                test.latitudeDegrees,
                cast(T) 15);

        UtmCoordinate!T projected;

        expect(
            tryForwardUtm(
                ellipsoid,
                source,
                projected)
                == test.expectedAccepted,
            T.stringof
                ~ " automatic "
                ~ test.label);
    }

    /*
     * An explicitly selected UTM zone is the fixed Transverse Mercator
     * projection and is not clipped to the automatic standard band.
     *
     * Use the central meridian so all samples are well inside the bounded
     * generic-TM longitude domain.
     */
    const zone =
        UtmZone.fromNumber(33);

    const projection =
        UtmProjection!T.fromZone(
            ellipsoid,
            zone,
            UtmHemisphere.north);

    static immutable real[6] explicitLatitudes = [
        -85.0L,
        -80.0L,
        -79.0L,
        83.0L,
        84.0L,
        85.0L,
    ];

    foreach (latitudeRaw; explicitLatitudes)
    {
        const auto source =
            point!T(
                cast(T) latitudeRaw,
                cast(T) 15);

        ProjectedCoordinate!T projected;

        const string prefix = format(
            "%s explicit lat=%s",
            T.stringof,
            latitudeRaw);

        expect(
            projection.tryForward(
                source,
                projected),
            prefix ~ " forward");

        if (!projection.tryForward(
                source,
                projected))
            continue;

        GeographicCoordinate!T reversed;

        expect(
            projection.tryReverse(
                projected,
                reversed),
            prefix ~ " reverse");

        if (!projection.tryReverse(
                projected,
                reversed))
            continue;

        const real residual =
            groundResidualMetres(
                ellipsoid,
                source,
                reversed);

        expect(
            residual <= roundTripBudget!T(),
            format(
                "%s residual %s m <= %s m",
                prefix,
                residual,
                roundTripBudget!T()));
    }
}


private void validateExplicitZonePreservation(T)()
{
    writeln("UTM-D explicit zone preservation ", T.stringof);

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

        ProjectedCoordinate!T raw;

        expect(
            projection.tryForward(
                source,
                raw),
            format(
                "%s zone %s explicit forward",
                T.stringof,
                zoneNumber));

        if (!projection.tryForward(
                source,
                raw))
            continue;

        UtmCoordinate!T tagged;

        expect(
            UtmCoordinate!T.tryFromComponents(
                zone,
                UtmHemisphere.north,
                raw.easting,
                raw.northing,
                tagged),
            format(
                "%s zone %s tagged",
                T.stringof,
                zoneNumber));

        GeographicCoordinate!T reversed;

        expect(
            tryReverseUtm(
                ellipsoid,
                tagged,
                reversed),
            format(
                "%s zone %s tagged reverse",
                T.stringof,
                zoneNumber));

        if (!tryReverseUtm(
                ellipsoid,
                tagged,
                reversed))
            continue;

        const real residual =
            groundResidualMetres(
                ellipsoid,
                source,
                reversed);

        expect(
            residual <= roundTripBudget!T(),
            format(
                "%s zone %s explicit residual %s m",
                T.stringof,
                zoneNumber,
                residual));

        /*
         * The tag must remain the caller-selected zone. Reverse must not
         * mutate or recompute it.
         */
        expect(
            tagged.zone.number == zoneNumber,
            format(
                "%s zone %s tag preserved",
                T.stringof,
                zoneNumber));
    }
}


private void validateHemisphereOverride(T)()
{
    writeln("UTM-D hemisphere override ", T.stringof);

    const ellipsoid = wgs84!T();
    const zone = UtmZone.fromNumber(33);

    static immutable real[3] latitudes = [
        -10.0L,
        0.0L,
        10.0L,
    ];

    foreach (hemisphere; [
        UtmHemisphere.north,
        UtmHemisphere.south])
    {
        const projection =
            UtmProjection!T.fromZone(
                ellipsoid,
                zone,
                hemisphere);

        foreach (latitudeRaw; latitudes)
        {
            const source =
                point!T(
                    cast(T) latitudeRaw,
                    cast(T) 15);

            ProjectedCoordinate!T raw;

            const string prefix = format(
                "%s hemisphere=%s lat=%s",
                T.stringof,
                hemisphere,
                latitudeRaw);

            expect(
                projection.tryForward(
                    source,
                    raw),
                prefix ~ " forward");

            if (!projection.tryForward(
                    source,
                    raw))
                continue;

            UtmCoordinate!T tagged;

            expect(
                UtmCoordinate!T.tryFromComponents(
                    zone,
                    hemisphere,
                    raw.easting,
                    raw.northing,
                    tagged),
                prefix ~ " tagged");

            GeographicCoordinate!T reversed;

            expect(
                tryReverseUtm(
                    ellipsoid,
                    tagged,
                    reversed),
                prefix ~ " reverse");

            if (!tryReverseUtm(
                    ellipsoid,
                    tagged,
                    reversed))
                continue;

            const real residual =
                groundResidualMetres(
                    ellipsoid,
                    source,
                    reversed);

            expect(
                residual <= roundTripBudget!T(),
                format(
                    "%s residual %s m",
                    prefix,
                    residual));

            expect(
                tagged.hemisphere == hemisphere,
                prefix ~ " hemisphere tag preserved");
        }
    }
}


private ulong rngState =
    0x5f3759df12345678UL;


private ulong nextRandom()
{
    rngState =
        rngState * 6364136223846793005UL
        + 1442695040888963407UL;

    return rngState;
}


private real unitRandom()
{
    return cast(real) (
        nextRandom() >> 11)
        / cast(real) (1UL << 53);
}


private void validateRandomRoundTrip(T)()
{
    enum size_t sampleCount = 100_000;

    writeln(
        "UTM-D random round-trip ",
        T.stringof,
        " samples=",
        sampleCount);

    const ellipsoid = wgs84!T();

    size_t localFailures;
    real worstResidual = 0.0L;
    real worstLatitude = 0.0L;
    real worstLongitude = 0.0L;

    foreach (_; 0 .. sampleCount)
    {
        /*
         * Stay one tiny deterministic margin inside the half-open upper bound
         * so generation itself does not depend on endpoint rounding.
         */
        const real latitude =
            -80.0L
            + unitRandom() * 163.999L;

        const real longitude =
            -180.0L
            + unitRandom() * 360.0L;

        const auto source =
            point!T(
                cast(T) latitude,
                cast(T) longitude);

        UtmCoordinate!T projected;

        if (!tryForwardUtm(
                ellipsoid,
                source,
                projected))
        {
            ++localFailures;
            continue;
        }

        GeographicCoordinate!T reversed;

        if (!tryReverseUtm(
                ellipsoid,
                projected,
                reversed))
        {
            ++localFailures;
            continue;
        }

        const real residual =
            groundResidualMetres(
                ellipsoid,
                source,
                reversed);

        if (residual > worstResidual)
        {
            worstResidual = residual;
            worstLatitude = latitude;
            worstLongitude = longitude;
        }

        if (residual > roundTripBudget!T())
            ++localFailures;
    }

    writeln(
        "  worst=",
        worstResidual,
        " m at lat=",
        worstLatitude,
        " lon=",
        worstLongitude,
        " failures=",
        localFailures);

    expect(
        localFailures == 0,
        T.stringof ~ " random round-trip failures == 0");
}


int main()
{
    writeln("UTM-D boundary/property validation");
    writeln("==================================");

    validateAutomaticProperties!float();
    validateAutomaticProperties!double();
    validateAutomaticProperties!real();

    validateLatitudeSemantics!float();
    validateLatitudeSemantics!double();
    validateLatitudeSemantics!real();

    validateExplicitZonePreservation!float();
    validateExplicitZonePreservation!double();
    validateExplicitZonePreservation!real();

    validateHemisphereOverride!float();
    validateHemisphereOverride!double();
    validateHemisphereOverride!real();

    /*
     * Reset the deterministic generator before each scalar so every public
     * scalar sees the same geographic corpus.
     */
    rngState = 0x5f3759df12345678UL;
    validateRandomRoundTrip!float();

    rngState = 0x5f3759df12345678UL;
    validateRandomRoundTrip!double();

    rngState = 0x5f3759df12345678UL;
    validateRandomRoundTrip!real();

    writeln;
    writeln("checks=", checks);
    writeln("failures=", failures);

    if (failures == 0)
    {
        writeln("RESULT: UTM-D PASS");
        return 0;
    }

    writeln("RESULT: UTM-D FAIL");
    return 1;
}
