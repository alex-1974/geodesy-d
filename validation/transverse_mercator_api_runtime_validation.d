module transverse_mercator_api_runtime_validation;

/*
 * TM-E — API and runtime validation.
 *
 * The non-throwing operational surface is deliberately exercised from a
 * function declared `pure nothrow @safe @nogc`.  If tryFromParameters(),
 * isValid/properties, tryForward(), or tryReverse() lose any required
 * attribute or acquire a GC allocation, this validator fails to compile.
 *
 * The convenience constructors/wrappers are tested separately for @safe
 * compilation and correct throwing behaviour.  They are intentionally not
 * part of the @nogc contract because their failure paths allocate exceptions.
 */

import std.stdio : writefln, writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


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
 * Compile-time contract probe.
 *
 * Merely instantiating this function proves that every operation called here
 * is usable from a pure/nothrow/@safe/@nogc caller.
 */
private bool operationalTrySurface(T)(
    const Ellipsoid!T ellipsoid,
    const Latitude!T latitudeOfNaturalOrigin,
    const Longitude!T longitudeOfNaturalOrigin,
    const T scaleFactorAtNaturalOrigin,
    const T falseEasting,
    const T falseNorthing,
    const GeographicCoordinate!T forwardSource,
    const ProjectedCoordinate!T reverseSource,
    out ProjectedCoordinate!T projected,
    out GeographicCoordinate!T geographic)
    pure nothrow @safe @nogc
{
    TransverseMercator!T projection;

    if (!TransverseMercator!T.tryFromParameters(
            ellipsoid,
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            scaleFactorAtNaturalOrigin,
            falseEasting,
            falseNorthing,
            projection))
        return false;

    if (!projection.isValid)
        return false;

    // Exercise every public non-throwing property inside the same contract.
    const copiedEllipsoid = projection.ellipsoid;
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
        || copiedLatitudeOfNaturalOrigin != latitudeOfNaturalOrigin
        || copiedLongitudeOfNaturalOrigin != longitudeOfNaturalOrigin
        || copiedScaleFactor != scaleFactorAtNaturalOrigin
        || copiedFalseEasting != falseEasting
        || copiedFalseNorthing != falseNorthing)
        return false;

    if (!projection.tryForward(
            forwardSource,
            projected))
        return false;

    return projection.tryReverse(
        reverseSource,
        geographic);
}


/*
 * @safe compile probe for the throwing convenience surface.
 *
 * This is intentionally neither nothrow nor @nogc.
 */
private void throwingSurfaceCompiles(T)(
    const Ellipsoid!T ellipsoid,
    const Latitude!T latitudeOfNaturalOrigin,
    const Longitude!T longitudeOfNaturalOrigin,
    const T scaleFactorAtNaturalOrigin,
    const T falseEasting,
    const T falseNorthing,
    const GeographicCoordinate!T source)
    @safe
{
    const projection =
        TransverseMercator!T.fromParameters(
            ellipsoid,
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            scaleFactorAtNaturalOrigin,
            falseEasting,
            falseNorthing);

    const projected =
        projection.forward(source);

    const recovered =
        projection.reverse(projected);

    // Force both values to remain semantically live.
    assert(projected.easting == projected.easting);
    assert(recovered.latitude == recovered.latitude);
}


private void expectConstructorThrow(T)(
    const Ellipsoid!T ellipsoid,
    const Latitude!T latitudeOfNaturalOrigin,
    const Longitude!T longitudeOfNaturalOrigin,
    const T scaleFactorAtNaturalOrigin,
    const T falseEasting,
    const T falseNorthing)
    @safe
{
    bool threw = false;

    try
    {
        const unused =
            TransverseMercator!T.fromParameters(
                ellipsoid,
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                scaleFactorAtNaturalOrigin,
                falseEasting,
                falseNorthing);
    }
    catch (Exception)
    {
        threw = true;
    }

    assert(threw);
}


private void validateScalar(T)()
{
    const T a = cast(T) 6_378_137.0L;
    const T f = cast(T) (1.0L / 298.257223563L);

    const ellipsoid =
        Ellipsoid!T.fromFlattening(
            a,
            f);

    const latitudeOfNaturalOrigin =
        Latitude!T.fromDegrees(
            cast(T) 0.0L);

    const longitudeOfNaturalOrigin =
        Longitude!T.fromDegrees(
            cast(T) 15.0L);

    const T k0 = cast(T) 0.9996L;
    const T falseEasting = cast(T) 500_000.0L;
    const T falseNorthing = cast(T) 0.0L;

    const source =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 45.0L),
            Longitude!T.fromDegrees(
                cast(T) 20.0L));

    /*
     * Build an ordinary valid projection first; its projected output then
     * becomes the reverseSource passed through the compile-time hotpath probe.
     */
    const projection =
        TransverseMercator!T.fromParameters(
            ellipsoid,
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            k0,
            falseEasting,
            falseNorthing);

    ProjectedCoordinate!T baselineProjected;
    assert(projection.tryForward(
        source,
        baselineProjected));

    GeographicCoordinate!T baselineRecovered;
    assert(projection.tryReverse(
        baselineProjected,
        baselineRecovered));

    /*
     * Instantiate and execute the pure/nothrow/@safe/@nogc probe for T.
     * Compilation of this call is itself the attribute/allocation test.
     */
    ProjectedCoordinate!T hotProjected;
    GeographicCoordinate!T hotRecovered;

    assert(operationalTrySurface!T(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        falseNorthing,
        source,
        baselineProjected,
        hotProjected,
        hotRecovered));

    assert(hotProjected.easting
        == baselineProjected.easting);
    assert(hotProjected.northing
        == baselineProjected.northing);
    assert(hotRecovered.latitude.radians
        == baselineRecovered.latitude.radians);
    assert(hotRecovered.longitude.radians
        == baselineRecovered.longitude.radians);

    /*
     * Compile and execute the successful throwing convenience surface.  This
     * proves that constructor/forward/reverse remain @safe.
     */
    throwingSurfaceCompiles!T(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        falseNorthing,
        source);

    /*
     * Determinism: identical input to the prepared operation must produce
     * exactly identical represented public-scalar outputs on every repetition.
     */
    enum size_t repeatCount = 100_000;

    foreach (_; 0 .. repeatCount)
    {
        ProjectedCoordinate!T projected;
        assert(projection.tryForward(
            source,
            projected));

        assert(projected.easting
            == baselineProjected.easting);
        assert(projected.northing
            == baselineProjected.northing);

        GeographicCoordinate!T recovered;
        assert(projection.tryReverse(
            baselineProjected,
            recovered));

        assert(recovered.latitude.radians
            == baselineRecovered.latitude.radians);
        assert(recovered.longitude.radians
            == baselineRecovered.longitude.radians);
    }

    /*
     * A default-initialized TM is deliberately invalid and both operational
     * directions must fail without throwing.
     */
    const invalidProjection =
        TransverseMercator!T.init;

    assert(!invalidProjection.isValid);

    ProjectedCoordinate!T invalidProjectedResult;
    assert(!invalidProjection.tryForward(
        source,
        invalidProjectedResult));

    GeographicCoordinate!T invalidGeographicResult;
    assert(!invalidProjection.tryReverse(
        baselineProjected,
        invalidGeographicResult));

    /*
     * Parameter rejection.  Ellipsoid!T itself permits f=0.02; TM narrows the
     * supported projection domain to f <= 0.01.
     */
    const tooFlat =
        Ellipsoid!T.fromFlattening(
            a,
            cast(T) 0.02L);

    TransverseMercator!T candidate;

    assert(!TransverseMercator!T.tryFromParameters(
        Ellipsoid!T.init,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        tooFlat,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        cast(T) 0,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        cast(T) -1,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        T.nan,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        T.infinity,
        falseEasting,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        T.nan,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        T.infinity,
        falseNorthing,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        T.nan,
        candidate));

    assert(!TransverseMercator!T.tryFromParameters(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        -T.infinity,
        candidate));

    // Throwing constructor must expose invalid parameters as an exception.
    expectConstructorThrow!T(
        tooFlat,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        falseEasting,
        falseNorthing);

    expectConstructorThrow!T(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        cast(T) 0,
        falseEasting,
        falseNorthing);

    expectConstructorThrow!T(
        ellipsoid,
        latitudeOfNaturalOrigin,
        longitudeOfNaturalOrigin,
        k0,
        T.nan,
        falseNorthing);

    /*
     * Forward domain: non-polar delta-longitude beyond 60 degrees must be
     * rejected by tryForward and must throw through forward().
     */
    const outsideForwardSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 10.0L),
            Longitude!T.fromDegrees(
                cast(T) 75.001L));

    ProjectedCoordinate!T outsideForwardProjected;
    assert(!projection.tryForward(
        outsideForwardSource,
        outsideForwardProjected));

    bool forwardThrew = false;

    try
    {
        const unused =
            projection.forward(
                outsideForwardSource);
    }
    catch (Exception)
    {
        forwardThrew = true;
    }

    assert(forwardThrew);

    /*
     * Reverse domain: this analytic-sphere regression point represents
     * lat=89 deg, lon0=15 deg, delta-lon=+60.001 deg, k0=1.1,
     * R=6371000 m.  It is about 2.26 m from the represented +60 degree
     * boundary, safely outside both the 2 m float budget and the 1 mm
     * double/real budgets.
     */
    const boundaryProjection =
        TransverseMercator!T.fromParameters(
            Ellipsoid!T.fromFlattening(
                cast(T) 6_371_000.0L,
                cast(T) 0.0L),
            Latitude!T.fromDegrees(
                cast(T) 0.0L),
            Longitude!T.fromDegrees(
                cast(T) 15.0L),
            cast(T) 1.1L,
            cast(T) 0.0L,
            cast(T) 0.0L);

    const outsideReverseSource =
        ProjectedCoordinate!T.fromComponents(
            cast(T) 105_931.0078125L,
            cast(T) 10_947_138.0L);

    GeographicCoordinate!T outsideReverseRecovered;

    assert(!boundaryProjection.tryReverse(
        outsideReverseSource,
        outsideReverseRecovered));

    bool reverseThrew = false;

    try
    {
        const unused =
            boundaryProjection.reverse(
                outsideReverseSource);
    }
    catch (Exception)
    {
        reverseThrew = true;
    }

    assert(reverseThrew);

    writefln(
        "%s: PASS "
        ~ "(try API attributes/@nogc, invalid inputs, throwing semantics, "
        ~ "%s deterministic repetitions)",
        scalarName!T,
        repeatCount);
}


void main()
{
    writeln("TM-E API/runtime validation");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: PASS");
}
