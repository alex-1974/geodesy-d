/**
 * UPS scalar/policy qualification for float, double, and real.
 */
module ups_policy_validation;

import std.meta : AliasSeq;
import geodesy;

private void require(bool condition, string message)
{
    if (!condition)
        throw new Exception(message);
}

private T tolerance(T)()
{
    static if (is(T == float))
        return cast(T) 5e-5;
    else
        return cast(T) 2e-10;
}

private void validate(T)()
{
    UpsHemisphere hemisphere;

    const south80 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -80),
        Longitude!T.fromDegrees(cast(T) 0));
    require(!tryStandardUpsHemisphere(south80, hemisphere),
        "-80 must remain automatic UTM");

    const north84 = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 84),
        Longitude!T.fromDegrees(cast(T) 0));
    require(tryStandardUpsHemisphere(north84, hemisphere),
        "+84 must select automatic UPS");
    require(hemisphere == UpsHemisphere.north,
        "+84 must select north UPS");

    const north = UpsProjection!T.fromHemisphere(UpsHemisphere.north);
    const northOverlap = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 83.5),
        Longitude!T.fromDegrees(cast(T) 30));

    ProjectedCoordinate!T xy;
    require(north.tryForward(northOverlap, xy),
        "north overlap boundary rejected");

    const northBack = north.reverse(xy);
    require(
        northBack.latitude.degrees
            >= cast(T) 83.5 - tolerance!T(),
        "north overlap reverse escaped policy");

    const northFactors = north.forwardFactors(northOverlap);
    require(northFactors.pointScale > cast(T) 0,
        "north UPS factors invalid");

    const south = UpsProjection!T.fromHemisphere(UpsHemisphere.south);
    const southOverlap = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) -79.5),
        Longitude!T.fromDegrees(cast(T) -30));

    require(south.tryForward(southOverlap, xy),
        "south overlap boundary rejected");

    const southBack = south.reverse(xy);
    require(
        southBack.latitude.degrees
            <= cast(T) -79.5 + tolerance!T(),
        "south overlap reverse escaped policy");

    const northPole = GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(cast(T) 90),
        Longitude!T.fromDegrees(cast(T) 120));
    const pole = north.forward(northPole);
    require(pole.easting == cast(T) 2_000_000,
        "UPS pole false easting not exact");
    require(pole.northing == cast(T) 2_000_000,
        "UPS pole false northing not exact");

    const poleBack = north.reverse(pole);
    require(
        poleBack.longitude.radians
            == north.longitudeOfNaturalOrigin.radians,
        "UPS pole longitude not canonical");

    const tagged = forwardUps(north84);
    require(tagged.hemisphere == UpsHemisphere.north,
        "automatic tagged UPS hemisphere wrong");

    const autoBack = reverseUps(tagged);
    require(
        autoBack.latitude.degrees
            >= cast(T) 84 - tolerance!T(),
        "automatic UPS reverse failed");

    UpsCoordinate!T coordinate;
    require(UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.north,
        cast(T) 1_200_000,
        cast(T) 2_800_000,
        coordinate),
        "north range boundary rejected");

    require(!UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.north,
        cast(T) 1_199_999,
        cast(T) 2_000_000,
        coordinate),
        "north below-range coordinate accepted");

    require(UpsCoordinate!T.tryFromComponents(
        UpsHemisphere.south,
        cast(T) 700_000,
        cast(T) 3_300_000,
        coordinate),
        "south range boundary rejected");
}

void main()
{
    static foreach (T; AliasSeq!(float, double, real))
        validate!T();
}
