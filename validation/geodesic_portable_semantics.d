module geodesic_portable_semantics;

/*
 * GEO-G portable GEO-A semantic gate.
 *
 * This validator is intentionally self-contained and has no external geodesy
 * dependency. It freezes the representation-sensitive public semantics which
 * must remain identical on every mandatory platform/compiler target.
 */

import std.math :
    PI,
    fabs,
    signbit;
import std.stdio :
    writefln,
    writeln;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult;
import geodesy.geographic : GeographicCoordinate;


private T pi(T)()
{
    return cast(T) PI;
}


private T normalizedTolerance(T)()
{
    static if (T.mant_dig <= 24)
        return cast(T) 4e-6L;
    else
        return cast(T) 2e-12L;
}


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


private void validateScalar(T)()
{
    const T radius = cast(T) 6_371_000.0L;

    const solver =
        Geodesic!T.fromEllipsoid(
            Ellipsoid!T.sphere(radius));

    const zero =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 0),
            Longitude!T.fromDegrees(cast(T) 0));

    const eastAntimeridian =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 0),
            Longitude!T.fromDegrees(cast(T) 180));

    const westAntimeridian =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 0),
            Longitude!T.fromDegrees(cast(T) -180));

    /*
     * Signed/antimeridian representation aliases are one coincident surface
     * point and must return the GEO-A canonical (+0,+0,+0) inverse result.
     */
    GeodesicInverseResult!T coincidence;

    assert(solver.tryInverse(
        eastAntimeridian,
        westAntimeridian,
        coincidence));

    assert(coincidence.distance == cast(T) 0);
    assert(coincidence.initialAzimuth.radians == cast(T) 0);
    assert(coincidence.finalAzimuth.radians == cast(T) 0);

    assert(!signbit(coincidence.distance));
    assert(!signbit(coincidence.initialAzimuth.radians));
    assert(!signbit(coincidence.finalAzimuth.radians));

    /*
     * All longitudes at an exact pole denote the same surface point.
     */
    const northPoleEast =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 90),
            Longitude!T.fromDegrees(cast(T) 45));

    const northPoleWest =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 90),
            Longitude!T.fromDegrees(cast(T) -135));

    GeodesicInverseResult!T poleCoincidence;

    assert(solver.tryInverse(
        northPoleEast,
        northPoleWest,
        poleCoincidence));

    assert(poleCoincidence.distance == cast(T) 0);
    assert(poleCoincidence.initialAzimuth.radians == cast(T) 0);
    assert(poleCoincidence.finalAzimuth.radians == cast(T) 0);

    /*
     * Zero-distance direct semantics are deliberately different: preserve the
     * supplied oriented line after canonicalizing the public representation.
     */
    const start =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 10),
            Longitude!T.fromDegrees(cast(T) 180));

    GeodesicDirectResult!T zeroDirect;

    assert(solver.tryDirect(
        start,
        Angle!T.fromDegrees(cast(T) 180),
        cast(T) 0,
        zeroDirect));

    assert(
        zeroDirect.position.latitude.radians
        == start.latitude.radians);

    assert(
        zeroDirect.position.longitude.radians
        == -pi!T);

    assert(
        zeroDirect.finalAzimuth.radians
        == -pi!T);

    /*
     * Full-turn/signed-zero azimuth aliases canonicalize to positive zero.
     */
    GeodesicDirectResult!T fullTurn;

    assert(solver.tryDirect(
        zero,
        Angle!T.fromDegrees(cast(T) -360),
        cast(T) 0,
        fullTurn));

    assert(fullTurn.finalAzimuth.radians == cast(T) 0);
    assert(!signbit(fullTurn.finalAzimuth.radians));

    /*
     * Negative direct distance travels backwards on the same oriented
     * geodesic.
     */
    const quarter =
        radius * pi!T / cast(T) 2;

    GeodesicDirectResult!T backwards;

    assert(solver.tryDirect(
        zero,
        Angle!T.fromDegrees(cast(T) 90),
        -quarter,
        backwards));

    assert(
        fabs(
            backwards.position.latitude.radians)
        <= normalizedTolerance!T);

    assert(
        fabs(
            backwards.position.longitude.radians
            + pi!T / cast(T) 2)
        <= normalizedTolerance!T);

    assert(
        fabs(
            backwards.finalAzimuth.radians
            - pi!T / cast(T) 2)
        <= normalizedTolerance!T);

    /*
     * Exact antipodes have non-unique shortest geodesics. GEO-A makes the
     * distance normative while requiring any returned azimuths to remain
     * canonical.
     */
    GeodesicInverseResult!T antipodal;

    assert(solver.tryInverse(
        zero,
        eastAntimeridian,
        antipodal));

    assert(
        fabs(
            antipodal.distance / radius
            - pi!T)
        <= normalizedTolerance!T);

    assert(
        antipodal.initialAzimuth.radians >= -pi!T
        && antipodal.initialAzimuth.radians < pi!T);

    assert(
        antipodal.finalAzimuth.radians >= -pi!T
        && antipodal.finalAzimuth.radians < pi!T);

    /*
     * A non-zero direct operation from an exact pole must remain finite; the
     * supplied pole longitude defines the local azimuth frame.
     */
    GeodesicDirectResult!T poleDirect;

    assert(solver.tryDirect(
        northPoleEast,
        Angle!T.fromDegrees(cast(T) 0),
        cast(T) 1000,
        poleDirect));

    assert(
        poleDirect.position.latitude.radians
        == poleDirect.position.latitude.radians);

    assert(
        poleDirect.position.longitude.radians
        == poleDirect.position.longitude.radians);

    assert(
        poleDirect.finalAzimuth.radians
        == poleDirect.finalAzimuth.radians);

    writefln(
        "%s: PASS",
        scalarName!T);
}


void main()
{
    writeln("GEO-G portable GEO-A semantic gate");

    validateScalar!float();
    validateScalar!double();
    validateScalar!real();

    writeln("RESULT: GEO-A PORTABLE PASS");
}
