/**
 * PS-E scalar and representation qualification.
 *
 * This executable is validation support code, not library API.
 */
module polar_stereographic_scalar_validation;

import std.math : fabs;
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
        return cast(T) 5e-5;
    else static if (is(T == double))
        return cast(T) 2e-10;
    else
        return cast(T) 2e-12;
}

private T linearTolerance(T)(T scale)
{
    static if (is(T == float))
        return cast(T) 32 * T.epsilon * (scale > 1 ? scale : 1);
    else
        return cast(T) 64 * T.epsilon * (scale > 1 ? scale : 1);
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
    const auto ellipsoid = Ellipsoid!T.fromFlattening(a, f);

    const north = PolarStereographic!T.fromParameters(
        ellipsoid,
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 30),
        cast(T) 0.994,
        cast(T) 2_000_000,
        cast(T) 2_000_000);

    const south = PolarStereographic!T.fromStandardParallel(
        ellipsoid,
        Latitude!T.fromDegrees(cast(T) -71),
        Longitude!T.fromDegrees(cast(T) 70),
        cast(T) 6_000_000,
        cast(T) 6_000_000);

    require(north.isValid, "north projection invalid");
    require(south.isValid, "south projection invalid");

    // Ordinary selected-hemisphere point.
    const source = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 73),
        Longitude!T.fromDegrees(cast(T) 44));

    const projected = north.forward(source);
    const recovered = north.reverse(projected);

    require(
        absT(recovered.latitude.degrees - source.latitude.degrees)
            <= angularTolerance!T(),
        "ordinary latitude round-trip failed");

    require(
        absT(recovered.longitude.degrees - source.longitude.degrees)
            <= angularTolerance!T(),
        "ordinary longitude round-trip failed");

    const forwardFactors = north.forwardFactors(source);
    const reverseFactors = north.reverseFactors(projected);

    require(
        absT(forwardFactors.pointScale - reverseFactors.pointScale)
            <= cast(T) 128 * T.epsilon,
        "ordinary factor round-trip failed");

    // Exact selected pole: E/N, longitude, gamma, and k are canonical.
    const pole = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 123));

    const projectedPole = north.forward(pole);
    const recoveredPole = north.reverse(projectedPole);
    const poleFactors = north.forwardFactors(pole);
    const reversePoleFactors = north.reverseFactors(projectedPole);

    require(projectedPole.easting == cast(T) 2_000_000,
        "pole easting not exact");
    require(projectedPole.northing == cast(T) 2_000_000,
        "pole northing not exact");
    require(recoveredPole.latitude.degrees == cast(T) 90,
        "pole latitude not exact");
    require(recoveredPole.longitude.degrees == cast(T) 30,
        "pole longitude not canonical");
    require(poleFactors.meridianConvergence.degrees == cast(T) 0,
        "forward pole gamma not canonical");
    require(reversePoleFactors.meridianConvergence.degrees == cast(T) 0,
        "reverse pole gamma not canonical");
    require(poleFactors.pointScale == cast(T) 0.994,
        "forward pole scale not exact");
    require(reversePoleFactors.pointScale == cast(T) 0.994,
        "reverse pole scale not exact");

    // Closed equator boundary.
    const equator = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 0),
        Longitude!T.fromDegrees(cast(T) -149.5));

    const projectedEquator = north.forward(equator);
    const recoveredEquator = north.reverse(projectedEquator);

    require(
        absT(recoveredEquator.latitude.degrees)
            <= angularTolerance!T(),
        "equator latitude recovery failed");

    // A one-ULP represented E/N perturbation at the closed equator boundary
    // must remain classified as the boundary, not the opposite hemisphere.
    const T representedStep =
        cast(T) 8 * T.epsilon
        * (absT(projectedEquator.easting)
            + absT(projectedEquator.northing)
            + cast(T) 6_378_137);

    ProjectedCoordinate!T representedEquator;
    require(
        ProjectedCoordinate!T.tryFromComponents(
            projectedEquator.easting + representedStep,
            projectedEquator.northing,
            representedEquator),
        "represented equator coordinate construction failed");

    GeographicCoordinate!T representedRecovered;
    require(
        north.tryReverse(representedEquator, representedRecovered),
        "represented equator boundary rejected");

    require(
        representedRecovered.latitude.degrees
            >= -angularTolerance!T(),
        "represented equator crossed into opposite hemisphere");

    // Opposite hemisphere remains outside the public domain.
    ProjectedCoordinate!T ignoredProjected;
    require(
        !north.tryForward(
            GeographicCoordinate!T.fromComponents(
                Latitude!T.fromDegrees(cast(T) -1),
                Longitude!T.fromDegrees(cast(T) 30)),
            ignoredProjected),
        "opposite hemisphere accepted");

    // Antimeridian-near longitude difference.
    const antimeridian = PolarStereographic!T.fromParameters(
        ellipsoid,
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 179.75),
        cast(T) 0.997,
        cast(T) -400_000,
        cast(T) 700_000);

    const antiSource = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 80),
        Longitude!T.fromDegrees(cast(T) -179.75));

    const antiProjected = antimeridian.forward(antiSource);
    const antiRecovered = antimeridian.reverse(antiProjected);

    require(
        absT(antiRecovered.latitude.degrees - antiSource.latitude.degrees)
            <= angularTolerance!T(),
        "antimeridian latitude failed");

    require(
        absT(antiRecovered.longitude.degrees - antiSource.longitude.degrees)
            <= angularTolerance!T(),
        "antimeridian longitude failed");

    // Near-pole reverse factors exercise the preserved-tau path.
    const nearPole = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 89.999),
        Longitude!T.fromDegrees(cast(T) 47));

    const nearProjected = north.forward(nearPole);
    const nearForwardFactors = north.forwardFactors(nearPole);
    const nearReverseFactors = north.reverseFactors(nearProjected);

    const T factorTol =
        static if (is(T == float))
            cast(T) 4e-5;
        else
            cast(T) 5e-11;

    require(
        absT(
            nearForwardFactors.pointScale
                - nearReverseFactors.pointScale)
            <= factorTol,
        "near-pole reverse scale failed");

    // Variant B must map its standard parallel to scale 1.
    const standardParallel = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -71),
        Longitude!T.fromDegrees(cast(T) 70));

    const standardFactors = south.forwardFactors(standardParallel);
    require(
        absT(standardFactors.pointScale - cast(T) 1)
            <= cast(T) 256 * T.epsilon,
        "variant-B standard parallel scale is not 1");

    // Unit scaling: changing all linear quantities by the same factor must
    // scale E/N and offsets but leave angular/factor results unchanged.
    const T unitScale = cast(T) 0.001;
    const scaledEllipsoid = Ellipsoid!T.fromFlattening(
        a * unitScale, f);

    const scaled = PolarStereographic!T.fromParameters(
        scaledEllipsoid,
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 30),
        cast(T) 0.994,
        cast(T) 2_000_000 * unitScale,
        cast(T) 2_000_000 * unitScale);

    const scaledProjected = scaled.forward(source);
    const scaledFactors = scaled.forwardFactors(source);

    const T linScale =
        absT(projected.easting)
        + absT(projected.northing)
        + cast(T) 1;

    require(
        absT(scaledProjected.easting - projected.easting * unitScale)
            <= linearTolerance!T(linScale) * unitScale,
        "unit-scaled easting failed");

    require(
        absT(scaledProjected.northing - projected.northing * unitScale)
            <= linearTolerance!T(linScale) * unitScale,
        "unit-scaled northing failed");

    require(
        absT(scaledFactors.pointScale - forwardFactors.pointScale)
            <= cast(T) 128 * T.epsilon,
        "unit-scaled point scale changed");

    require(
        absT(
            scaledFactors.meridianConvergence.degrees
                - forwardFactors.meridianConvergence.degrees)
            <= angularTolerance!T(),
        "unit-scaled convergence changed");

    static if (is(T == real))
    {
        static if (real.mant_dig > double.mant_dig)
        {
            // Preserve information that exists only in wide real.
            const real tiny = 0x1p-60L;
            const auto widePoint = GeographicCoordinate!real.fromComponents(
                Latitude!real.fromDegrees(80.0L + tiny),
                Longitude!real.fromDegrees(44.0L + tiny));

            const auto wideProjected = north.forward(widePoint);
            const auto baseProjected = north.forward(
                GeographicCoordinate!real.fromComponents(
                    Latitude!real.fromDegrees(80.0L),
                    Longitude!real.fromDegrees(44.0L)));

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

    writeln("PASS: Polar Stereographic PS-E scalar/representation qualification");
    writeln("float mantissa bits:  ", float.mant_dig);
    writeln("double mantissa bits: ", double.mant_dig);
    writeln("real mantissa bits:   ", real.mant_dig);
}
