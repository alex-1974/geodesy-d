module lambert_azimuthal_equal_area_scalar_validation;

import std.meta : AliasSeq;
import std.stdio : writeln;

import geodesy;

private T absT(T)(T value)
{
    return value < 0 ? -value : value;
}

private T angularTolerance(T)()
{
    static if (is(T == float))
        return cast(T) 1.5e-4;
    else static if (is(T == double))
        return cast(T) 5e-10;
    else
        return cast(T) 5e-12;
}

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private void validateScalar(T)()
{
    const T a = cast(T) 6_378_137.0;
    const T f = cast(T) (1.0 / 298.257223563);

    const ellipsoid =
        Ellipsoid!T.fromFlattening(a, f);

    const oblique =
        LambertAzimuthalEqualArea!T.fromParameters(
            ellipsoid,
            Latitude!T.fromDegrees(cast(T) 52),
            Longitude!T.fromDegrees(cast(T) 10),
            cast(T) 4_321_000,
            cast(T) 3_210_000);

    require(oblique.isValid, "oblique projection invalid");

    const source =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 48.20849),
            Longitude!T.fromDegrees(cast(T) 16.37208));

    const projected = oblique.forward(source);
    const recovered = oblique.reverse(projected);

    require(
        absT(
            recovered.latitude.degrees
                - source.latitude.degrees)
            <= angularTolerance!T(),
        "oblique latitude roundtrip failed");

    require(
        absT(
            recovered.longitude.degrees
                - source.longitude.degrees)
            <= angularTolerance!T(),
        "oblique longitude roundtrip failed");

    const centre =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 52),
            Longitude!T.fromDegrees(cast(T) 10));

    const projectedCentre = oblique.forward(centre);

    require(
        projectedCentre.easting == cast(T) 4_321_000,
        "centre easting not exact");

    require(
        projectedCentre.northing == cast(T) 3_210_000,
        "centre northing not exact");

    const recoveredCentre =
        oblique.reverse(projectedCentre);

    require(
        recoveredCentre.latitude.radians
            == oblique.latitudeOfProjectionCentre.radians,
        "centre latitude not canonical");

    require(
        recoveredCentre.longitude.radians
            == oblique.longitudeOfProjectionCentre.radians,
        "centre longitude not canonical");

    ProjectedCoordinate!T ignored;

    require(
        !oblique.tryForward(
            GeographicCoordinate!T.fromComponents(
                Latitude!T.fromDegrees(cast(T) -52),
                Longitude!T.fromDegrees(cast(T) -170)),
            ignored),
        "exact antipode accepted");

    const equatorial =
        LambertAzimuthalEqualArea!T.fromParameters(
            ellipsoid,
            Latitude!T.fromDegrees(cast(T) 0),
            Longitude!T.fromDegrees(cast(T) 30),
            cast(T) 0,
            cast(T) 0);

    const eqSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 20),
            Longitude!T.fromDegrees(cast(T) 75));

    const eqRecovered =
        equatorial.reverse(
            equatorial.forward(eqSource));

    require(
        absT(
            eqRecovered.latitude.degrees
                - eqSource.latitude.degrees)
            <= angularTolerance!T(),
        "equatorial latitude roundtrip failed");

    const north =
        LambertAzimuthalEqualArea!T.fromParameters(
            ellipsoid,
            Latitude!T.fromDegrees(cast(T) 90),
            Longitude!T.fromDegrees(cast(T) 20),
            cast(T) 2_000_000,
            cast(T) 2_000_000);

    const northSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 70),
            Longitude!T.fromDegrees(cast(T) 55));

    const northRecovered =
        north.reverse(
            north.forward(northSource));

    require(
        absT(
            northRecovered.latitude.degrees
                - northSource.latitude.degrees)
            <= angularTolerance!T(),
        "north-polar latitude roundtrip failed");

    require(
        absT(
            northRecovered.longitude.degrees
                - northSource.longitude.degrees)
            <= angularTolerance!T(),
        "north-polar longitude roundtrip failed");

    const south =
        LambertAzimuthalEqualArea!T.fromParameters(
            ellipsoid,
            Latitude!T.fromDegrees(cast(T) -90),
            Longitude!T.fromDegrees(cast(T) -45),
            cast(T) -1_000_000,
            cast(T) 3_000_000);

    const southSource =
        GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) -65),
            Longitude!T.fromDegrees(cast(T) -20));

    const southRecovered =
        south.reverse(
            south.forward(southSource));

    require(
        absT(
            southRecovered.latitude.degrees
                - southSource.latitude.degrees)
            <= angularTolerance!T(),
        "south-polar latitude roundtrip failed");

    const unitScale = cast(T) 0.001;

    const scaled =
        LambertAzimuthalEqualArea!T.fromParameters(
            Ellipsoid!T.fromFlattening(
                a * unitScale,
                f),
            Latitude!T.fromDegrees(cast(T) 52),
            Longitude!T.fromDegrees(cast(T) 10),
            cast(T) 4_321_000 * unitScale,
            cast(T) 3_210_000 * unitScale);

    const scaledProjected =
        scaled.forward(source);

    static if (is(T == float))
        enum T linearTolerance = cast(T) 0.05;
    else
        enum T linearTolerance = cast(T) 1e-8;

    require(
        absT(
            scaledProjected.easting
                - projected.easting * unitScale)
            <= linearTolerance,
        "unit-scaled easting failed");

    require(
        absT(
            scaledProjected.northing
                - projected.northing * unitScale)
            <= linearTolerance,
        "unit-scaled northing failed");

    static if (is(T == real))
    {
        static if (real.mant_dig > double.mant_dig)
        {
            const real tiny = 0x1p-48L;

            const auto wide =
                GeographicCoordinate!real.fromComponents(
                    Latitude!real.fromDegrees(48.0L + tiny),
                    Longitude!real.fromDegrees(16.0L + tiny));

            const auto base =
                GeographicCoordinate!real.fromComponents(
                    Latitude!real.fromDegrees(48.0L),
                    Longitude!real.fromDegrees(16.0L));

            const auto wideProjected =
                oblique.forward(wide);

            const auto baseProjected =
                oblique.forward(base);

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

    writeln("PASS: Lambert Azimuthal Equal Area scalar qualification");
    writeln("float mantissa bits:  ", float.mant_dig);
    writeln("double mantissa bits: ", double.mant_dig);
    writeln("real mantissa bits:   ", real.mant_dig);
}
