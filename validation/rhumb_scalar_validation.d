module rhumb_scalar_validation;

import std.meta : AliasSeq;
import std.stdio : writeln;

import geodesy;

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private T absT(T)(T value)
{
    return value < 0 ? -value : value;
}

private T angularTolerance(T)()
{
    static if (is(T == float))
        return cast(T) 8e-5;
    else static if (is(T == double))
        return cast(T) 2e-10;
    else
        return cast(T) 2e-12;
}

private void validateScalar(T)()
{
    const solver = Rhumb!T.fromEllipsoid(wgs84!T());

    const start = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 48.20849),
        Longitude!T.fromDegrees(cast(T) 16.37208));
    const end = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 47.07071),
        Longitude!T.fromDegrees(cast(T) 15.43950));

    const inverse = solver.inverse(start, end);
    require(inverse.distance > cast(T) 0, "inverse distance not positive");

    const direct = solver.direct(
        start,
        inverse.bearing,
        inverse.distance);

    require(
        absT(direct.position.latitude.degrees - end.latitude.degrees)
            <= angularTolerance!T(),
        "direct latitude roundtrip failed");

    require(
        absT(direct.position.longitude.degrees - end.longitude.degrees)
            <= angularTolerance!T(),
        "direct longitude roundtrip failed");

    const line = solver.line(start, inverse.bearing);
    const linePosition = line.position(inverse.distance);

    require(
        absT(linePosition.position.latitude.degrees - end.latitude.degrees)
            <= angularTolerance!T(),
        "line latitude roundtrip failed");

    const equator0 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 0),
        Longitude!T.fromDegrees(cast(T) 0));
    const equator180 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 0),
        Longitude!T.fromDegrees(cast(T) 180));

    const tie = solver.inverse(equator0, equator180);
    require(
        absT(tie.bearing.degrees - cast(T) 90)
            <= angularTolerance!T(),
        "opposite-meridian east-going tie failed");

    const pole1 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 20));
    const pole2 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) -140));

    const poleCoincident = solver.inverse(pole1, pole2);
    require(poleCoincident.distance == cast(T) 0,
        "pole coincidence distance not zero");
    require(poleCoincident.bearing.radians == cast(T) 0,
        "pole coincidence bearing not zero");

    RhumbDirectResult!T invalidDirect;
    require(!solver.tryDirect(
        pole1,
        Angle!T.fromDegrees(cast(T) 180),
        cast(T) 1_000,
        invalidDirect),
        "nonzero direct from pole accepted");

    const eastWest = solver.direct(
        start,
        Angle!T.fromDegrees(cast(T) 90),
        cast(T) 10_000);
    require(
        absT(eastWest.position.latitude.degrees - start.latitude.degrees)
            <= angularTolerance!T(),
        "east-west latitude drift");

    const backward = solver.direct(
        start,
        Angle!T.fromDegrees(cast(T) 45),
        cast(T) -100_000);
    require(
        backward.position.latitude.radians
            < start.latitude.radians,
        "signed negative distance did not move backward");
}

void main()
{
    static foreach (T; AliasSeq!(float, double, real))
        validateScalar!T();

    writeln("PASS: Rhumb scalar / representation qualification");
    writeln("float mantissa bits:  ", float.mant_dig);
    writeln("double mantissa bits: ", double.mant_dig);
    writeln("real mantissa bits:   ", real.mant_dig);
}
