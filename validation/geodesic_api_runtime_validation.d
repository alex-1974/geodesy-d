module geodesic_api_runtime_validation;

/*
 * GEO-F — geodesic API and runtime validation.
 *
 * The complete checked Geodesic operational surface is exercised from a
 * function declared:
 *
 *     pure nothrow @safe @nogc
 *
 * Compilation therefore proves the required attributes and the absence of GC
 * allocation for:
 *
 * - checked solver construction;
 * - solver properties;
 * - checked direct;
 * - checked inverse;
 * - direct-result accessors;
 * - inverse-result accessors.
 *
 * Throwing convenience construction is tested separately for @safe
 * compilation and exact GeodesyValueException behaviour.
 */

import std.meta : AliasSeq;
import std.stdio : writefln, writeln;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult,
    GeodesicQuantities;
import geodesy.geographic : GeographicCoordinate;


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
 * Merely instantiating this function proves that every operation called here
 * is usable from a pure/nothrow/@safe/@nogc caller.
 */
private bool operationalTrySurface(T)(
    const Ellipsoid!T ellipsoid,
    const GeographicCoordinate!T directStart,
    const Angle!T initialAzimuth,
    const T directDistance,
    const GeographicCoordinate!T inverseStart,
    const GeographicCoordinate!T inverseEnd,
    out GeodesicDirectResult!T directResult,
    out GeodesicQuantities!T directQuantities,
    out GeodesicInverseResult!T inverseResult,
    out GeodesicQuantities!T inverseQuantities)
    pure nothrow @safe @nogc
{
    Geodesic!T solver;

    if (!Geodesic!T.tryFromEllipsoid(
            ellipsoid,
            solver))
        return false;

    if (!solver.isValid
        || solver.isSphere)
        return false;

    const copiedEllipsoid =
        solver.ellipsoid;

    if (copiedEllipsoid != ellipsoid)
        return false;

    if (!solver.tryDirect(
            directStart,
            initialAzimuth,
            directDistance,
            directResult,
            directQuantities))
        return false;

    /*
     * Exercise every direct-result public accessor in the checked caller.
     */
    const directPosition =
        directResult.position;

    const directLatitude =
        directPosition.latitude;

    const directLongitude =
        directPosition.longitude;

    const directFinalAzimuth =
        directResult.finalAzimuth;

    if (directLatitude.radians != directLatitude.radians
        || directLongitude.radians != directLongitude.radians
        || directFinalAzimuth.radians != directFinalAzimuth.radians)
        return false;

    const directReducedLength =
        directQuantities.reducedLength;

    const directScale12 =
        directQuantities.scale12;

    const directScale21 =
        directQuantities.scale21;

    const directSignedArea =
        directQuantities.signedArea;

    if (
        directReducedLength != directReducedLength
        || directScale12 != directScale12
        || directScale21 != directScale21
        || directSignedArea != directSignedArea
    )
        return false;

    if (!solver.tryInverse(
            inverseStart,
            inverseEnd,
            inverseResult,
            inverseQuantities))
        return false;

    /*
     * Exercise every inverse-result and advanced-quantity public accessor in
     * the checked caller.
     */
    const inverseDistance =
        inverseResult.distance;

    const inverseInitialAzimuth =
        inverseResult.initialAzimuth;

    const inverseFinalAzimuth =
        inverseResult.finalAzimuth;

    const reducedLength =
        inverseQuantities.reducedLength;

    const scale12 =
        inverseQuantities.scale12;

    const scale21 =
        inverseQuantities.scale21;

    const signedArea =
        inverseQuantities.signedArea;

    return inverseDistance > cast(T) 0
        && inverseInitialAzimuth.radians
            == inverseInitialAzimuth.radians
        && inverseFinalAzimuth.radians
            == inverseFinalAzimuth.radians
        && reducedLength == reducedLength
        && scale12 == scale12
        && scale21 == scale21
        && signedArea == signedArea;
}


/*
 * Successful throwing convenience construction must remain @safe.
 *
 * This intentionally is neither nothrow nor @nogc because failure allocates
 * GeodesyValueException.
 */
private void throwingSurfaceCompiles(T)(
    const Ellipsoid!T ellipsoid)
    @safe
{
    const solver =
        Geodesic!T.fromEllipsoid(
            ellipsoid);

    assert(solver.isValid);
}


/*
 * The throwing convenience constructor must reject unsupported ellipsoids with
 * the library-specific GeodesyValueException, not an unrelated exception.
 */
private void expectConstructorValueException(T)(
    const Ellipsoid!T ellipsoid)
    @safe
{
    bool caughtExpected = false;

    try
    {
        const unused =
            Geodesic!T.fromEllipsoid(
                ellipsoid);

        cast(void) unused;
    }
    catch (GeodesyValueException)
    {
        caughtExpected = true;
    }

    assert(caughtExpected);
}


private void assertDirectInit(T)(
    const GeodesicDirectResult!T result)
{
    assert(result.position.latitude.radians == cast(T) 0);
    assert(result.position.longitude.radians == cast(T) 0);
    assert(result.finalAzimuth.radians == cast(T) 0);
}


private void assertInverseInit(T)(
    const GeodesicInverseResult!T result)
{
    assert(result.distance == cast(T) 0);
    assert(result.initialAzimuth.radians == cast(T) 0);
    assert(result.finalAzimuth.radians == cast(T) 0);
}


private void assertQuantitiesInit(T)(
    const GeodesicQuantities!T quantities)
{
    assert(quantities.reducedLength == cast(T) 0);
    assert(quantities.scale12 == cast(T) 0);
    assert(quantities.scale21 == cast(T) 0);
    assert(quantities.signedArea == cast(T) 0);
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

    const directStart =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) -30.0L),
            Longitude!T.fromDegrees(
                cast(T) 15.0L));

    const initialAzimuth =
        Angle!T.fromDegrees(
            cast(T) 37.0L);

    const T directDistance =
        cast(T) 4_000_000.0L;

    const inverseStart =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) -30.0L),
            Longitude!T.fromDegrees(
                cast(T) 15.0L));

    const inverseEnd =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 42.0L),
            Longitude!T.fromDegrees(
                cast(T) 120.0L));

    const solver =
        Geodesic!T.fromEllipsoid(
            ellipsoid);

    assert(solver.isValid);
    assert(!solver.isSphere);
    assert(solver.ellipsoid == ellipsoid);

    GeodesicDirectResult!T baselineDirect;

    assert(solver.tryDirect(
        directStart,
        initialAzimuth,
        directDistance,
        baselineDirect));

    GeodesicDirectResult!T advancedDirect;
    GeodesicQuantities!T baselineDirectQuantities;

    assert(solver.tryDirect(
        directStart,
        initialAzimuth,
        directDistance,
        advancedDirect,
        baselineDirectQuantities));

    assert(
        advancedDirect.position.latitude.radians
        == baselineDirect.position.latitude.radians);

    assert(
        advancedDirect.position.longitude.radians
        == baselineDirect.position.longitude.radians);

    assert(
        advancedDirect.finalAzimuth.radians
        == baselineDirect.finalAzimuth.radians);

    GeodesicInverseResult!T baselineInverse;

    assert(solver.tryInverse(
        inverseStart,
        inverseEnd,
        baselineInverse));

    GeodesicInverseResult!T advancedInverse;
    GeodesicQuantities!T baselineQuantities;

    assert(solver.tryInverse(
        inverseStart,
        inverseEnd,
        advancedInverse,
        baselineQuantities));

    assert(advancedInverse.distance == baselineInverse.distance);
    assert(
        advancedInverse.initialAzimuth.radians
        == baselineInverse.initialAzimuth.radians);
    assert(
        advancedInverse.finalAzimuth.radians
        == baselineInverse.finalAzimuth.radians);

    /*
     * Instantiate and execute the complete checked surface probe for T.
     */
    GeodesicDirectResult!T hotDirect;
    GeodesicQuantities!T hotDirectQuantities;
    GeodesicInverseResult!T hotInverse;
    GeodesicQuantities!T hotQuantities;

    assert(operationalTrySurface!T(
        ellipsoid,
        directStart,
        initialAzimuth,
        directDistance,
        inverseStart,
        inverseEnd,
        hotDirect,
        hotDirectQuantities,
        hotInverse,
        hotQuantities));

    assert(
        hotDirect.position.latitude.radians
        == baselineDirect.position.latitude.radians);

    assert(
        hotDirect.position.longitude.radians
        == baselineDirect.position.longitude.radians);

    assert(
        hotDirect.finalAzimuth.radians
        == baselineDirect.finalAzimuth.radians);

    assert(
        hotDirectQuantities.reducedLength
        == baselineDirectQuantities.reducedLength);

    assert(
        hotDirectQuantities.scale12
        == baselineDirectQuantities.scale12);

    assert(
        hotDirectQuantities.scale21
        == baselineDirectQuantities.scale21);

    assert(
        hotDirectQuantities.signedArea
        == baselineDirectQuantities.signedArea);

    assert(
        hotInverse.distance
        == baselineInverse.distance);

    assert(
        hotInverse.initialAzimuth.radians
        == baselineInverse.initialAzimuth.radians);

    assert(
        hotInverse.finalAzimuth.radians
        == baselineInverse.finalAzimuth.radians);

    assert(
        hotQuantities.reducedLength
        == baselineQuantities.reducedLength);

    assert(
        hotQuantities.scale12
        == baselineQuantities.scale12);

    assert(
        hotQuantities.scale21
        == baselineQuantities.scale21);

    assert(
        hotQuantities.signedArea
        == baselineQuantities.signedArea);

    /*
     * Successful throwing convenience construction remains @safe.
     */
    throwingSurfaceCompiles!T(
        ellipsoid);

    /*
     * Deterministic runtime stress.
     *
     * The GEO-F contract requires at least 100000 direct and 100000 inverse
     * checked calls per public scalar. Exact represented-output equality is
     * required for identical repeated inputs.
     */
    enum size_t repeatCount = 100_000;

    foreach (_; 0 .. repeatCount)
    {
        GeodesicDirectResult!T directResult;

        assert(solver.tryDirect(
            directStart,
            initialAzimuth,
            directDistance,
            directResult));

        assert(
            directResult.position.latitude.radians
            == baselineDirect.position.latitude.radians);

        assert(
            directResult.position.longitude.radians
            == baselineDirect.position.longitude.radians);

        assert(
            directResult.finalAzimuth.radians
            == baselineDirect.finalAzimuth.radians);

        GeodesicInverseResult!T inverseResult;

        assert(solver.tryInverse(
            inverseStart,
            inverseEnd,
            inverseResult));

        assert(
            inverseResult.distance
            == baselineInverse.distance);

        assert(
            inverseResult.initialAzimuth.radians
            == baselineInverse.initialAzimuth.radians);

        assert(
            inverseResult.finalAzimuth.radians
            == baselineInverse.finalAzimuth.radians);
    }

    /*
     * Default-invalid solver semantics.
     *
     * Both checked operations must fail and must clear a previously successful
     * result rather than leaving stale data that could be mistaken for success.
     */
    const invalidSolver =
        Geodesic!T.init;

    assert(!invalidSolver.isValid);
    assert(!invalidSolver.isSphere);

    GeodesicDirectResult!T invalidDirect =
        baselineDirect;

    assert(!invalidSolver.tryDirect(
        directStart,
        initialAzimuth,
        directDistance,
        invalidDirect));

    assertDirectInit(invalidDirect);

    invalidDirect =
        baselineDirect;

    GeodesicQuantities!T invalidDirectQuantities =
        baselineDirectQuantities;

    assert(!invalidSolver.tryDirect(
        directStart,
        initialAzimuth,
        directDistance,
        invalidDirect,
        invalidDirectQuantities));

    assertDirectInit(invalidDirect);
    assertQuantitiesInit(invalidDirectQuantities);

    GeodesicInverseResult!T invalidInverse =
        baselineInverse;

    assert(!invalidSolver.tryInverse(
        inverseStart,
        inverseEnd,
        invalidInverse));

    assertInverseInit(invalidInverse);

    invalidInverse =
        baselineInverse;

    GeodesicQuantities!T invalidQuantities =
        baselineQuantities;

    assert(!invalidSolver.tryInverse(
        inverseStart,
        inverseEnd,
        invalidInverse,
        invalidQuantities));

    assertInverseInit(invalidInverse);
    assertQuantitiesInit(invalidQuantities);

    /*
     * Checked constructor failure must also clear a previously valid prepared
     * solver.
     */
    Geodesic!T candidate =
        solver;

    assert(!Geodesic!T.tryFromEllipsoid(
        Ellipsoid!T.init,
        candidate));

    assert(!candidate.isValid);

    const tooFlat =
        Ellipsoid!T.fromFlattening(
            a,
            cast(T) 0.02L);

    candidate = solver;

    assert(!Geodesic!T.tryFromEllipsoid(
        tooFlat,
        candidate));

    assert(!candidate.isValid);

    /*
     * Non-finite direct distances are rejected, with the out result reset to
     * .init every time.
     */
    static foreach (badDistance; AliasSeq!(
        T.nan,
        T.infinity,
        -T.infinity))
    {
        {
            GeodesicDirectResult!T badResult =
                baselineDirect;

            assert(!solver.tryDirect(
                directStart,
                initialAzimuth,
                badDistance,
                badResult));

            assertDirectInit(badResult);
        }
    }

    /*
     * Throwing constructor failure must report GeodesyValueException.
     */
    expectConstructorValueException!T(
        Ellipsoid!T.init);

    expectConstructorValueException!T(
        tooFlat);

    writefln(
        "%s: PASS "
        ~ "(checked API pure/nothrow/@safe/@nogc, "
        ~ "invalid/result-reset semantics, GeodesyValueException, "
        ~ "%s direct + %s inverse deterministic repetitions)",
        scalarName!T,
        repeatCount,
        repeatCount);
}


void main()
{
    writeln("GEO-F geodesic API/runtime validation");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: GEO-F PASS");
}
