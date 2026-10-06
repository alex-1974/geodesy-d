module lambert_conformal_conic_scalar_validation;

import std.meta : AliasSeq;
import std.stdio : writeln;

import geodesy;

private T absT(T)(T value)
{
    return value < 0 ? -value : value;
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private T angularTolerance(T)()
{
    static if (is(T == float))
        return cast(T) 1e-4;
    else static if (is(T == double))
        return cast(T) 3e-10;
    else
        return cast(T) 3e-12;
}

private void validateScalar(T)()
{
    const ellipsoid = Ellipsoid!T.fromFlattening(
        cast(T) 6_378_137.0,
        cast(T) (1.0 / 298.257223563));

    const projection =
        LambertConformalConic!T.fromTwoStandardParallels(
            ellipsoid,
            Latitude!T.fromDegrees(cast(T) 40),
            Longitude!T.fromDegrees(cast(T) -96),
            Latitude!T.fromDegrees(cast(T) 33),
            Latitude!T.fromDegrees(cast(T) 45),
            cast(T) 0,
            cast(T) 0);

    require(projection.isValid, "projection invalid");

    const source = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 35),
        Longitude!T.fromDegrees(cast(T) -75));

    const projected = projection.forward(source);
    const recovered = projection.reverse(projected);

    require(
        absT(recovered.latitude.degrees - source.latitude.degrees)
            <= angularTolerance!T(),
        "latitude roundtrip failed");

    require(
        absT(recovered.longitude.degrees - source.longitude.degrees)
            <= angularTolerance!T(),
        "longitude roundtrip failed");

    const firstStandard = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 33),
        Longitude!T.fromDegrees(cast(T) -90));

    const secondStandard = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 45),
        Longitude!T.fromDegrees(cast(T) -100));

    const factors1 = projection.forwardFactors(firstStandard);
    const factors2 = projection.forwardFactors(secondStandard);

    static if (is(T == float))
        enum T scaleTolerance = cast(T) 3e-6;
    else
        enum T scaleTolerance = cast(T) 2e-12;

    require(
        absT(factors1.pointScale - cast(T) 1) <= scaleTolerance,
        "first standard parallel scale failed");
    require(
        absT(factors2.pointScale - cast(T) 1) <= scaleTolerance,
        "second standard parallel scale failed");

    const northPole = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 120));

    const apex = projection.forward(northPole);
    const apexBack = projection.reverse(apex);

    require(apexBack.latitude.degrees == cast(T) 90,
        "apex latitude not canonical");
    require(
        apexBack.longitude.radians
            == projection.longitudeOfFalseOrigin.radians,
        "apex longitude not canonical");

    ProjectedCoordinate!T ignored;
    require(
        !projection.tryForward(
            GeographicCoordinate!T.fromComponents(
                Latitude!T.fromDegrees(cast(T) -90),
                Longitude!T.fromDegrees(cast(T) 0)),
            ignored),
        "opposite pole accepted");

    const scaled = LambertConformalConic!T.fromTwoStandardParallels(
        Ellipsoid!T.fromFlattening(
            cast(T) 6_378.137,
            cast(T) (1.0 / 298.257223563)),
        Latitude!T.fromDegrees(cast(T) 40),
        Longitude!T.fromDegrees(cast(T) -96),
        Latitude!T.fromDegrees(cast(T) 33),
        Latitude!T.fromDegrees(cast(T) 45),
        cast(T) 0,
        cast(T) 0);

    const scaledProjected = scaled.forward(source);

    static if (is(T == float))
        enum T linearTolerance = cast(T) 0.05;
    else
        enum T linearTolerance = cast(T) 1e-8;

    require(
        absT(scaledProjected.easting - projected.easting / cast(T) 1000)
            <= linearTolerance,
        "unit scaling easting failed");
    require(
        absT(scaledProjected.northing - projected.northing / cast(T) 1000)
            <= linearTolerance,
        "unit scaling northing failed");

    static if (is(T == real))
    {
        static if (real.mant_dig > double.mant_dig)
        {
            const real tiny = 0x1p-48L;
            const auto wide = GeographicCoordinate!real.fromComponents(
                Latitude!real.fromDegrees(35.0L + tiny),
                Longitude!real.fromDegrees(-75.0L + tiny));
            const auto base = GeographicCoordinate!real.fromComponents(
                Latitude!real.fromDegrees(35.0L),
                Longitude!real.fromDegrees(-75.0L));

            const auto wideProjected = projection.forward(wide);
            const auto baseProjected = projection.forward(base);

            require(
                wideProjected.easting != baseProjected.easting
                    || wideProjected.northing != baseProjected.northing,
                "wide real precision collapsed to double");
        }
    }
}

void main()
{
    static foreach (T; AliasSeq!(float, double, real))
        validateScalar!T();

    writeln("PASS: Lambert Conformal Conic scalar qualification");
    writeln("float mantissa bits:  ", float.mant_dig);
    writeln("double mantissa bits: ", double.mant_dig);
    writeln("real mantissa bits:   ", real.mant_dig);
}
