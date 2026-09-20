module topocentric_frame_contract;

import geodesy.angle :
    Latitude,
    Longitude;
import geodesy.ellipsoid :
    Ellipsoid;
import geodesy.geocentric :
    GeocentricCoordinate;
import geodesy.geodetic :
    GeodeticCoordinate;
import geodesy.topocentric :
    TopocentricFrame;


static assert(is(TopocentricFrame!float));
static assert(is(TopocentricFrame!double));
static assert(is(TopocentricFrame!real));


private void checkedTopocentricFrameContract()
    pure nothrow @safe @nogc
{
    Ellipsoid!double ellipsoid;

    Ellipsoid!double.tryFromInverseFlattening(
        semiMajorAxis: 6_378_137.0,
        inverseFlattening: 298.257223563,
        result: ellipsoid);

    Latitude!double latitude;
    Latitude!double.tryFromDegrees(
        degrees: 48.0,
        result: latitude);

    Longitude!double longitude;
    Longitude!double.tryFromDegrees(
        degrees: 16.0,
        result: longitude);

    GeodeticCoordinate!double geodeticOrigin;

    GeodeticCoordinate!double.tryFromComponents(
        latitude: latitude,
        longitude: longitude,
        ellipsoidalHeight: 100.0,
        result: geodeticOrigin);

    GeocentricCoordinate!double geocentricOrigin;

    GeocentricCoordinate!double.tryFromComponents(
        x: 4_085_000.0,
        y: 1_260_000.0,
        z: 4_717_000.0,
        result: geocentricOrigin);

    TopocentricFrame!double geodeticFrame;

    const geodeticSuccess =
        TopocentricFrame!double.tryFromGeodeticOrigin(
            ellipsoid: ellipsoid,
            origin: geodeticOrigin,
            result: geodeticFrame);

    TopocentricFrame!double geocentricFrame;

    const geocentricSuccess =
        TopocentricFrame!double.tryFromGeocentricOrigin(
            ellipsoid: ellipsoid,
            origin: geocentricOrigin,
            result: geocentricFrame);

    const valid =
        geodeticFrame.isValid;

    const frameEllipsoid =
        geodeticFrame.ellipsoid;

    const invalid =
        TopocentricFrame!double.init;

    cast(void) geodeticSuccess;
    cast(void) geocentricSuccess;
    cast(void) valid;
    cast(void) frameEllipsoid;
    cast(void) invalid;
}


private void throwingTopocentricFrameContract()
    @safe
{
    const ellipsoid =
        Ellipsoid!double.fromInverseFlattening(
            semiMajorAxis: 6_378_137.0,
            inverseFlattening: 298.257223563);

    const geodeticOrigin =
        GeodeticCoordinate!double.fromComponents(
            latitude:
                Latitude!double.fromDegrees(
                    degrees: 48.0),
            longitude:
                Longitude!double.fromDegrees(
                    degrees: 16.0),
            ellipsoidalHeight: 100.0);

    const geocentricOrigin =
        GeocentricCoordinate!double.fromComponents(
            x: 4_085_000.0,
            y: 1_260_000.0,
            z: 4_717_000.0);

    const geodeticFrame =
        TopocentricFrame!double.fromGeodeticOrigin(
            ellipsoid: ellipsoid,
            origin: geodeticOrigin);

    const geocentricFrame =
        TopocentricFrame!double.fromGeocentricOrigin(
            ellipsoid: ellipsoid,
            origin: geocentricOrigin);

    cast(void) geodeticFrame;
    cast(void) geocentricFrame;
}
