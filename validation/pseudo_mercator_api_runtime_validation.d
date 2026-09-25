module pseudo_mercator_api_runtime_validation;

/*
 * PM-G2 — Pseudo-Mercator API/runtime contract validation.
 */

import std.math :
    nextDown,
    nextUp;

import std.stdio :
    writefln,
    writeln;

import geodesy.angle :
    Latitude,
    Longitude;

import geodesy.ellipsoid :
    Ellipsoid;

import geodesy.geographic :
    GeographicCoordinate;

import geodesy.projected :
    ProjectedCoordinate;

import geodesy.projection.pseudo_mercator :
    PseudoMercator;


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


private bool operationalTrySurface(T)(
    const Ellipsoid!T ellipsoid,
    const Longitude!T longitudeOfNaturalOrigin,
    const T falseEasting,
    const T falseNorthing,
    const GeographicCoordinate!T forwardSource,
    const ProjectedCoordinate!T reverseSource,
    out ProjectedCoordinate!T projected,
    out GeographicCoordinate!T geographic)
    pure nothrow @safe @nogc
{
    PseudoMercator!T projection;

    if (!PseudoMercator!T.tryFromParameters(
            ellipsoid,
            longitudeOfNaturalOrigin,
            falseEasting,
            falseNorthing,
            projection))
        return false;

    if (!projection.isValid)
        return false;

    const copiedEllipsoid =
        projection.ellipsoid;

    const copiedLongitude =
        projection.longitudeOfNaturalOrigin;

    const copiedFalseEasting =
        projection.falseEasting;

    const copiedFalseNorthing =
        projection.falseNorthing;

    if (!projection.tryForward(
            forwardSource,
            projected))
        return false;

    if (!projection.tryReverse(
            reverseSource,
            geographic))
        return false;

    cast(void) copiedEllipsoid;
    cast(void) copiedLongitude;
    cast(void) copiedFalseEasting;
    cast(void) copiedFalseNorthing;

    return true;
}


private void validateScalar(T)()
{
    const ellipsoid =
        Ellipsoid!T.fromInverseFlattening(
            cast(T) 6_378_137.0L,
            cast(T) 298.257223563L);

    const sphere =
        Ellipsoid!T.sphere(
            ellipsoid.semiMajorAxis);

    const longitude0 =
        Longitude!T.fromDegrees(
            cast(T) 15.0L);

    const falseEasting =
        cast(T) 500_000.0L;

    const falseNorthing =
        cast(T) 1_250_000.0L;

    const projection =
        PseudoMercator!T.fromParameters(
            ellipsoid,
            longitude0,
            falseEasting,
            falseNorthing);

    assert(projection.isValid);
    assert(projection.ellipsoid.semiMajorAxis == ellipsoid.semiMajorAxis);
    assert(projection.ellipsoid.flattening == ellipsoid.flattening);
    assert(projection.longitudeOfNaturalOrigin.radians == longitude0.radians);
    assert(projection.falseEasting == falseEasting);
    assert(projection.falseNorthing == falseNorthing);

    const invalid =
        PseudoMercator!T.init;

    assert(!invalid.isValid);

    ProjectedCoordinate!T checkedProjected;

    const zeroSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.init,
            longitude0);

    assert(!invalid.tryForward(
        zeroSource,
        checkedProjected));

    bool invalidForwardThrew = false;

    try
    {
        cast(void) invalid.forward(
            zeroSource);
    }
    catch (Exception)
    {
        invalidForwardThrew = true;
    }

    assert(invalidForwardThrew);

    const ordinarySource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 48.20849L),
            Longitude!T.fromDegrees(
                cast(T) 16.37208L));

    const ordinaryProjected =
        projection.forward(
            ordinarySource);

    const ordinaryReverse =
        projection.reverse(
            ordinaryProjected);

    ProjectedCoordinate!T contractProjected;
    GeographicCoordinate!T contractGeographic;

    assert(operationalTrySurface!T(
        ellipsoid,
        longitude0,
        falseEasting,
        falseNorthing,
        ordinarySource,
        ordinaryProjected,
        contractProjected,
        contractGeographic));

    const sphereProjection =
        PseudoMercator!T.fromParameters(
            sphere,
            longitude0,
            falseEasting,
            falseNorthing);

    const sphereProjected =
        sphereProjection.forward(
            ordinarySource);

    assert(sphereProjected.easting == ordinaryProjected.easting);
    assert(sphereProjected.northing == ordinaryProjected.northing);

    const northSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) 88),
            longitude0);

    const southSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(
                cast(T) -88),
            longitude0);

    const northProjected =
        projection.forward(
            northSource);

    const southProjected =
        projection.forward(
            southSource);

    assert(projection.reverse(
        northProjected).latitude.radians
        == northSource.latitude.radians);

    assert(projection.reverse(
        southProjected).latitude.radians
        == southSource.latitude.radians);

    Latitude!T northOutsideLatitude;

    assert(Latitude!T.tryFromDegrees(
        cast(T) 88.0001L,
        northOutsideLatitude));

    const northOutsideSource =
        GeographicCoordinate!T.fromComponents(
            northOutsideLatitude,
            longitude0);

    assert(!projection.tryForward(
        northOutsideSource,
        checkedProjected));

    bool forwardDomainThrew = false;

    try
    {
        cast(void) projection.forward(
            northOutsideSource);
    }
    catch (Exception)
    {
        forwardDomainThrew = true;
    }

    assert(forwardDomainThrew);

    ProjectedCoordinate!T outsideNorthing;

    assert(ProjectedCoordinate!T.tryFromComponents(
        northProjected.easting,
        nextUp(
            northProjected.northing),
        outsideNorthing));

    GeographicCoordinate!T rejectedGeographic;

    assert(!projection.tryReverse(
        outsideNorthing,
        rejectedGeographic));

    bool reverseDomainThrew = false;

    try
    {
        cast(void) projection.reverse(
            outsideNorthing);
    }
    catch (Exception)
    {
        reverseDomainThrew = true;
    }

    assert(reverseDomainThrew);

    const seamProjection =
        PseudoMercator!T.fromParameters(
            ellipsoid,
            Longitude!T.fromDegrees(
                cast(T) 180),
            falseEasting,
            falseNorthing);

    const seamLongitude =
        Longitude!T.fromRadians(
            nextDown(
                cast(T) 0));

    const seamSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.init,
            seamLongitude);

    const seamProjected =
        seamProjection.forward(
            seamSource);

    const seamReverse =
        seamProjection.reverse(
            seamProjected);

    assert(
        seamReverse.longitude.radians
        == seamLongitude.radians);

    assert(
        seamProjection.forward(
            seamReverse).easting
        == seamProjected.easting);

    const eastOutsideValue =
        nextUp(
            seamProjected.easting);

    if (eastOutsideValue != T.infinity)
    {
        ProjectedCoordinate!T eastOutside;

        assert(ProjectedCoordinate!T.tryFromComponents(
            eastOutsideValue,
            seamProjected.northing,
            eastOutside));

        assert(!seamProjection.tryReverse(
            eastOutside,
            rejectedGeographic));
    }

    cast(void) ordinaryReverse;

    writefln(
        "%s: PASS "
        ~ "(checked attributes, default/failure semantics, "
        ~ "flattening independence, represented boundaries, PM-G0 seam)",
        scalarName!T);
}


void main()
{
    writeln("PM-G2 Pseudo-Mercator API/runtime validation");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: PASS");
}
