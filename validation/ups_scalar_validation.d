/**
 * UPS scalar / boundary qualification.
 *
 * Validation support only.
 */
module ups_scalar_validation;

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
        return cast(T) 5e-5;
    else static if (is(T == double))
        return cast(T) 2e-10;
    else
        return cast(T) 2e-12;
}

private void validateScalar(T)()
{
    UpsHemisphere hemisphere;

    const south80 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -80),
        Longitude!T.fromDegrees(cast(T) 0));
    require(!tryStandardUpsHemisphere(south80, hemisphere),
        "-80 must remain standard UTM");

    const southUps = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -85),
        Longitude!T.fromDegrees(cast(T) 30));
    require(tryStandardUpsHemisphere(southUps, hemisphere),
        "south UPS standard selection failed");
    require(hemisphere == UpsHemisphere.south,
        "south UPS hemisphere mismatch");

    const north84 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 84),
        Longitude!T.fromDegrees(cast(T) 0));
    require(tryStandardUpsHemisphere(north84, hemisphere),
        "+84 must select standard UPS");
    require(hemisphere == UpsHemisphere.north,
        "north UPS hemisphere mismatch");

    const north = UpsProjection!T.fromHemisphere(UpsHemisphere.north);
    const northOverlap = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 83.5),
        Longitude!T.fromDegrees(cast(T) 10));

    const projected = north.forward(northOverlap);
    const recovered = north.reverse(projected);

    require(
        absT(recovered.latitude.degrees - northOverlap.latitude.degrees)
            <= angularTolerance!T(),
        "north overlap round-trip failed");

    const south = UpsProjection!T.fromHemisphere(UpsHemisphere.south);
    const southOverlap = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -79.5),
        Longitude!T.fromDegrees(cast(T) -10));

    const southProjected = south.forward(southOverlap);
    const southRecovered = south.reverse(southProjected);

    require(
        absT(southRecovered.latitude.degrees - southOverlap.latitude.degrees)
            <= angularTolerance!T(),
        "south overlap round-trip failed");

    // Exact poles must survive float->working-precision promotion.
    const northPole = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 120));

    const northPoleProjected = north.forward(northPole);
    const northPoleRecovered = north.reverse(northPoleProjected);

    require(
        northPoleProjected.easting == cast(T) 2_000_000
            && northPoleProjected.northing == cast(T) 2_000_000,
        "north pole false origin mismatch");

    require(
        northPoleRecovered.latitude.radians
            == north.latitudeOfNaturalOrigin.radians,
        "north pole latitude not canonical");

    require(
        northPoleRecovered.longitude.radians
            == north.longitudeOfNaturalOrigin.radians,
        "north pole longitude not canonical");

    const poleFactors = north.forwardFactors(northPole);
    require(
        poleFactors.meridianConvergence.degrees == cast(T) 0,
        "north pole convergence not canonical");
    require(
        poleFactors.pointScale == north.scaleFactorAtNaturalOrigin,
        "north pole scale mismatch");

    // Automatic tagged family.
    const tagged = forwardUps(north84);
    require(tagged.isValid, "tagged UPS coordinate invalid");
    require(tagged.hemisphere == UpsHemisphere.north,
        "tagged UPS hemisphere mismatch");

    const taggedBack = reverseUps(tagged);
    require(
        absT(taggedBack.latitude.degrees - north84.latitude.degrees)
            <= angularTolerance!T(),
        "tagged UPS reverse failed");

    // Represented coordinate range policy.
    UpsCoordinate!T coordinate;
    require(UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.north,
        cast(T) 1_200_000,
        cast(T) 2_800_000,
        coordinate), "north coordinate boundary rejected");
    require(!UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.north,
        cast(T) 1_199_999,
        cast(T) 2_000_000,
        coordinate), "north coordinate below range accepted");

    require(UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.south,
        cast(T) 700_000,
        cast(T) 3_300_000,
        coordinate), "south coordinate boundary rejected");
    require(!UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.south,
        cast(T) 3_300_001,
        cast(T) 2_000_000,
        coordinate), "south coordinate above range accepted");
}

void main()
{
    static foreach (T; AliasSeq!(float, double, real))
        validateScalar!T();

    writeln("PASS: UPS scalar / boundary qualification");
    writeln("float mantissa bits:  ", float.mant_dig);
    writeln("double mantissa bits: ", double.mant_dig);
    writeln("real mantissa bits:   ", real.mant_dig);
}
