module utm_api_runtime_validation;

/*
 * UTM-E — API and runtime validation.
 *
 * The complete checked UTM operational surface is exercised from a function
 * declared:
 *
 *     pure nothrow @safe @nogc
 *
 * Compilation therefore proves the required attributes and allocation
 * behaviour for:
 *
 * - UtmZone checked construction/properties;
 * - standard automatic zone selection;
 * - UtmProjection checked construction/properties;
 * - prepared forward/reverse;
 * - UtmCoordinate checked construction/properties;
 * - automatic tagged forward;
 * - tagged reverse.
 *
 * Throwing convenience APIs are tested separately for @safe compilation and
 * correct exception behaviour. They are intentionally outside the nothrow
 * and @nogc contract because failure paths allocate exceptions.
 */

import std.stdio : writefln, writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.utm :
    UtmCoordinate,
    UtmHemisphere,
    UtmProjection,
    UtmZone,
    forwardUtm,
    reverseUtm,
    tryForwardUtm,
    tryReverseUtm,
    tryStandardUtmZone;


private string scalarName(T)()
{
    static if (is(T == float))
        return "float";
    else static if (is(T == double))
        return "double";
    else static if (is(T == real))
        return "real";
    else
        return T.stringof;
}


/*
 * Compile-time checked-operational-surface probe.
 *
 * If any operation called here loses pure/nothrow/@safe/@nogc, this
 * validator fails to compile.
 */
private bool operationalTrySurface(T)(
    const Ellipsoid!T ellipsoid,
    const GeographicCoordinate!T source,
    out ProjectedCoordinate!T preparedProjected,
    out GeographicCoordinate!T preparedRecovered,
    out UtmCoordinate!T automaticProjected,
    out GeographicCoordinate!T automaticRecovered)
    pure nothrow @safe @nogc
{
    UtmZone zone;

    if (!UtmZone.tryFromNumber(
            33,
            zone))
        return false;

    if (!zone.isValid
        || zone.number != 33
        || zone.centralMeridianDegrees != 15)
        return false;

    UtmZone standardZone;
    UtmHemisphere standardHemisphere;

    if (!tryStandardUtmZone(
            source,
            standardZone,
            standardHemisphere))
        return false;

    if (standardZone.number != 33
        || standardHemisphere != UtmHemisphere.north)
        return false;

    UtmProjection!T projection;

    if (!UtmProjection!T.tryFromZone(
            ellipsoid,
            zone,
            UtmHemisphere.north,
            projection))
        return false;

    if (!projection.isValid)
        return false;

    /*
     * Exercise all defining prepared-projection properties inside the checked
     * caller.
     */
    const copiedEllipsoid =
        projection.ellipsoid;

    const copiedZone =
        projection.zone;

    const copiedHemisphere =
        projection.hemisphere;

    const copiedLatitudeOfNaturalOrigin =
        projection.latitudeOfNaturalOrigin;

    const copiedLongitudeOfNaturalOrigin =
        projection.longitudeOfNaturalOrigin;

    const copiedScaleFactor =
        projection.scaleFactorAtNaturalOrigin;

    const copiedFalseEasting =
        projection.falseEasting;

    const copiedFalseNorthing =
        projection.falseNorthing;

    if (copiedEllipsoid != ellipsoid
        || copiedZone.number != 33
        || copiedHemisphere != UtmHemisphere.north
        || copiedLatitudeOfNaturalOrigin.radians != cast(T) 0
        || copiedLongitudeOfNaturalOrigin.radians
            != source.longitude.radians
        || copiedScaleFactor != cast(T) 0.9996L
        || copiedFalseEasting != cast(T) 500_000
        || copiedFalseNorthing != cast(T) 0)
        return false;

    /*
     * Prepared raw operation.
     */
    if (!projection.tryForward(
            source,
            preparedProjected))
        return false;

    if (!projection.tryReverse(
            preparedProjected,
            preparedRecovered))
        return false;

    /*
     * Checked tagged-coordinate construction.
     */
    UtmCoordinate!T manualTagged;

    if (!UtmCoordinate!T.tryFromComponents(
            zone,
            UtmHemisphere.north,
            preparedProjected.easting,
            preparedProjected.northing,
            manualTagged))
        return false;

    if (!manualTagged.isValid
        || manualTagged.zone.number != 33
        || manualTagged.hemisphere != UtmHemisphere.north
        || manualTagged.projected.easting
            != preparedProjected.easting
        || manualTagged.projected.northing
            != preparedProjected.northing)
        return false;

    GeographicCoordinate!T manualRecovered;

    if (!tryReverseUtm(
            ellipsoid,
            manualTagged,
            manualRecovered))
        return false;

    if (manualRecovered.latitude.radians
            != preparedRecovered.latitude.radians
        || manualRecovered.longitude.radians
            != preparedRecovered.longitude.radians)
        return false;

    /*
     * Automatic standard-zone operation.
     */
    if (!tryForwardUtm(
            ellipsoid,
            source,
            automaticProjected))
        return false;

    if (!automaticProjected.isValid
        || automaticProjected.zone.number != 33
        || automaticProjected.hemisphere
            != UtmHemisphere.north
        || automaticProjected.projected.easting
            != preparedProjected.easting
        || automaticProjected.projected.northing
            != preparedProjected.northing)
        return false;

    if (!tryReverseUtm(
            ellipsoid,
            automaticProjected,
            automaticRecovered))
        return false;

    return automaticRecovered.latitude.radians
            == preparedRecovered.latitude.radians
        && automaticRecovered.longitude.radians
            == preparedRecovered.longitude.radians;
}


/*
 * @safe compile probe for the throwing convenience surface.
 *
 * This intentionally is neither nothrow nor @nogc.
 */
private void throwingSurfaceCompiles(T)(
    const Ellipsoid!T ellipsoid,
    const GeographicCoordinate!T source)
    @safe
{
    const zone =
        UtmZone.fromNumber(33);

    const projection =
        UtmProjection!T.fromZone(
            ellipsoid,
            zone,
            UtmHemisphere.north);

    const raw =
        projection.forward(source);

    const recovered =
        projection.reverse(raw);

    const tagged =
        forwardUtm(
            ellipsoid,
            source);

    const taggedRecovered =
        reverseUtm(
            ellipsoid,
            tagged);

    /*
     * Keep results live.
     */
    assert(raw.easting == raw.easting);
    assert(recovered.latitude == recovered.latitude);
    assert(tagged.isValid);
    assert(taggedRecovered.longitude
        == taggedRecovered.longitude);
}


private void validateScalar(T)()
{
    const T a =
        cast(T) 6_378_137.0L;

    const T f =
        cast(T) (1.0L / 298.257223563L);

    const ellipsoid =
        Ellipsoid!T.fromFlattening(
            a,
            f);

    const source =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 48.0L),
            Longitude!T.fromDegrees(
                cast(T) 15.0L));

    const zone =
        UtmZone.fromNumber(33);

    const projection =
        UtmProjection!T.fromZone(
            ellipsoid,
            zone,
            UtmHemisphere.north);

    ProjectedCoordinate!T baselinePrepared;

    assert(projection.tryForward(
        source,
        baselinePrepared));

    GeographicCoordinate!T baselinePreparedRecovered;

    assert(projection.tryReverse(
        baselinePrepared,
        baselinePreparedRecovered));

    UtmCoordinate!T baselineAutomatic;

    assert(tryForwardUtm(
        ellipsoid,
        source,
        baselineAutomatic));

    GeographicCoordinate!T baselineAutomaticRecovered;

    assert(tryReverseUtm(
        ellipsoid,
        baselineAutomatic,
        baselineAutomaticRecovered));

    /*
     * Instantiate and execute the pure/nothrow/@safe/@nogc probe.
     */
    ProjectedCoordinate!T hotPrepared;
    GeographicCoordinate!T hotPreparedRecovered;
    UtmCoordinate!T hotAutomatic;
    GeographicCoordinate!T hotAutomaticRecovered;

    assert(operationalTrySurface!T(
        ellipsoid,
        source,
        hotPrepared,
        hotPreparedRecovered,
        hotAutomatic,
        hotAutomaticRecovered));

    assert(hotPrepared.easting
        == baselinePrepared.easting);

    assert(hotPrepared.northing
        == baselinePrepared.northing);

    assert(hotPreparedRecovered.latitude.radians
        == baselinePreparedRecovered.latitude.radians);

    assert(hotPreparedRecovered.longitude.radians
        == baselinePreparedRecovered.longitude.radians);

    assert(hotAutomatic.zone.number
        == baselineAutomatic.zone.number);

    assert(hotAutomatic.hemisphere
        == baselineAutomatic.hemisphere);

    assert(hotAutomatic.projected.easting
        == baselineAutomatic.projected.easting);

    assert(hotAutomatic.projected.northing
        == baselineAutomatic.projected.northing);

    assert(hotAutomaticRecovered.latitude.radians
        == baselineAutomaticRecovered.latitude.radians);

    assert(hotAutomaticRecovered.longitude.radians
        == baselineAutomaticRecovered.longitude.radians);

    /*
     * Successful throwing API surface must remain @safe.
     */
    throwingSurfaceCompiles!T(
        ellipsoid,
        source);

    /*
     * Determinism.
     *
     * Repeated prepared and automatic/tagged operations must return exactly
     * identical represented public-scalar results.
     */
    enum size_t repeatCount = 100_000;

    foreach (_; 0 .. repeatCount)
    {
        ProjectedCoordinate!T prepared;

        assert(projection.tryForward(
            source,
            prepared));

        assert(prepared.easting
            == baselinePrepared.easting);

        assert(prepared.northing
            == baselinePrepared.northing);

        GeographicCoordinate!T preparedRecovered;

        assert(projection.tryReverse(
            baselinePrepared,
            preparedRecovered));

        assert(preparedRecovered.latitude.radians
            == baselinePreparedRecovered.latitude.radians);

        assert(preparedRecovered.longitude.radians
            == baselinePreparedRecovered.longitude.radians);

        UtmCoordinate!T automatic;

        assert(tryForwardUtm(
            ellipsoid,
            source,
            automatic));

        assert(automatic.zone.number
            == baselineAutomatic.zone.number);

        assert(automatic.hemisphere
            == baselineAutomatic.hemisphere);

        assert(automatic.projected.easting
            == baselineAutomatic.projected.easting);

        assert(automatic.projected.northing
            == baselineAutomatic.projected.northing);

        GeographicCoordinate!T automaticRecovered;

        assert(tryReverseUtm(
            ellipsoid,
            automatic,
            automaticRecovered));

        assert(automaticRecovered.latitude.radians
            == baselineAutomaticRecovered.latitude.radians);

        assert(automaticRecovered.longitude.radians
            == baselineAutomaticRecovered.longitude.radians);
    }

    /*
     * Default-invalid semantics.
     */
    const invalidZone =
        UtmZone.init;

    assert(!invalidZone.isValid);

    UtmZone zoneCandidate;

    assert(!UtmZone.tryFromNumber(
        0,
        zoneCandidate));

    assert(!UtmZone.tryFromNumber(
        61,
        zoneCandidate));

    const invalidProjection =
        UtmProjection!T.init;

    assert(!invalidProjection.isValid);

    ProjectedCoordinate!T invalidProjected;

    assert(!invalidProjection.tryForward(
        source,
        invalidProjected));

    GeographicCoordinate!T invalidRecovered;

    assert(!invalidProjection.tryReverse(
        baselinePrepared,
        invalidRecovered));

    const invalidTagged =
        UtmCoordinate!T.init;

    assert(!invalidTagged.isValid);

    assert(!tryReverseUtm(
        ellipsoid,
        invalidTagged,
        invalidRecovered));

    /*
     * UTM construction policy rejects a sphere even though generic TM supports
     * the spherical case.
     */
    const sphere =
        Ellipsoid!T.sphere(a);

    UtmProjection!T projectionCandidate;

    assert(!UtmProjection!T.tryFromZone(
        sphere,
        zone,
        UtmHemisphere.north,
        projectionCandidate));

    /*
     * Automatic policy: exact 84 degrees is outside standard UTM selection.
     */
    const automaticOutside =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 84.0L),
            Longitude!T.fromDegrees(
                cast(T) 15.0L));

    UtmCoordinate!T outsideTagged;

    assert(!tryForwardUtm(
        ellipsoid,
        automaticOutside,
        outsideTagged));

    /*
     * Explicit prepared projection is not clipped to that automatic band.
     */
    ProjectedCoordinate!T explicit84;

    assert(projection.tryForward(
        automaticOutside,
        explicit84));

    /*
     * Prepared generic-TM domain remains authoritative. Zone 33 has central
     * meridian 15 degrees, so longitude 75.001 degrees lies beyond +60.
     */
    const outsideTm =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 10.0L),
            Longitude!T.fromDegrees(
                cast(T) 75.001L));

    ProjectedCoordinate!T outsideRaw;

    assert(!projection.tryForward(
        outsideTm,
        outsideRaw));

    /*
     * Throwing failure semantics.
     */
    bool zoneThrew = false;

    try
    {
        const unused =
            UtmZone.fromNumber(0);
    }
    catch (Exception)
    {
        zoneThrew = true;
    }

    assert(zoneThrew);

    bool projectionThrew = false;

    try
    {
        const unused =
            UtmProjection!T.fromZone(
                sphere,
                zone,
                UtmHemisphere.north);
    }
    catch (Exception)
    {
        projectionThrew = true;
    }

    assert(projectionThrew);

    bool automaticForwardThrew = false;

    try
    {
        const unused =
            forwardUtm(
                ellipsoid,
                automaticOutside);
    }
    catch (Exception)
    {
        automaticForwardThrew = true;
    }

    assert(automaticForwardThrew);

    bool taggedReverseThrew = false;

    try
    {
        const unused =
            reverseUtm(
                ellipsoid,
                invalidTagged);
    }
    catch (Exception)
    {
        taggedReverseThrew = true;
    }

    assert(taggedReverseThrew);

    bool preparedForwardThrew = false;

    try
    {
        const unused =
            projection.forward(
                outsideTm);
    }
    catch (Exception)
    {
        preparedForwardThrew = true;
    }

    assert(preparedForwardThrew);

    writefln(
        "%s: PASS "
        ~ "(checked API attributes/@nogc, invalid inputs, throwing semantics, "
        ~ "%s prepared + automatic deterministic repetitions)",
        scalarName!T,
        repeatCount);
}


void main()
{
    writeln("UTM-E API/runtime validation");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: UTM-E PASS");
}
