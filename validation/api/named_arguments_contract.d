module named_arguments_contract;

import geodesy;


private void checkedNamedArgumentContract()
    pure nothrow @safe @nogc
{
    Angle!double angle;
    Angle!double.tryFromDegrees(
        degrees: 1.0,
        result: angle);

    Latitude!double latitude;
    Latitude!double.tryFromDegrees(
        degrees: 48.0,
        result: latitude);

    Longitude!double longitude;
    Longitude!double.tryFromDegrees(
        degrees: 16.0,
        result: longitude);

    Ellipsoid!double ellipsoid;
    Ellipsoid!double.tryFromInverseFlattening(
        semiMajorAxis: 6_378_137.0,
        inverseFlattening: 298.257223563,
        result: ellipsoid);

    const geographic =
        GeographicCoordinate!double.fromComponents(
            latitude: latitude,
            longitude: longitude);

    GeodeticCoordinate!double geodetic;
    GeodeticCoordinate!double.tryFromComponents(
        latitude: latitude,
        longitude: longitude,
        ellipsoidalHeight: 100.0,
        result: geodetic);

    GeocentricCoordinate!double geocentric;
    GeocentricCoordinate!double.tryFromComponents(
        x: 1.0,
        y: 2.0,
        z: 3.0,
        result: geocentric);

    ProjectedCoordinate!double projected;
    ProjectedCoordinate!double.tryFromComponents(
        easting: 500_000.0,
        northing: 5_300_000.0,
        result: projected);

    GeocentricTranslation!double translation;
    GeocentricTranslation!double.tryFromComponents(
        deltaX: 4.0,
        deltaY: 5.0,
        deltaZ: 6.0,
        result: translation);

    GeocentricCoordinate!double translated;
    tryApplyGeocentricTranslation(
        source: geocentric,
        translation: translation,
        result: translated);

    PositionVectorHelmert!double pv;
    PositionVectorHelmert!double.tryFromArcSecondsAndPpm(
        translationX: 1.0,
        translationY: 2.0,
        translationZ: 3.0,
        rotationXArcSeconds: 0.1,
        rotationYArcSeconds: 0.2,
        rotationZArcSeconds: 0.3,
        scaleDifferencePpm: 0.4,
        result: pv);

    GeocentricCoordinate!double pvTarget;
    tryApplyPositionVectorHelmert(
        source: geocentric,
        transform: pv,
        result: pvTarget);

    Latitude!double latitude0;
    Longitude!double longitude15;
    Latitude!double.tryFromDegrees(
        degrees: 0.0,
        result: latitude0);
    Longitude!double.tryFromDegrees(
        degrees: 15.0,
        result: longitude15);

    TransverseMercator!double tm;
    TransverseMercator!double.tryFromParameters(
        ellipsoid: ellipsoid,
        latitudeOfNaturalOrigin: latitude0,
        longitudeOfNaturalOrigin: longitude15,
        scaleFactorAtNaturalOrigin: 0.9996,
        falseEasting: 500_000.0,
        falseNorthing: 0.0,
        result: tm);

    const projectionSource =
        GeographicCoordinate!double.fromComponents(
            latitude: latitude0,
            longitude: longitude15);

    ProjectedCoordinate!double tmProjected;
    tm.tryForward(
        source: projectionSource,
        result: tmProjected);

    GeographicCoordinate!double tmReversed;
    tm.tryReverse(
        source: tmProjected,
        result: tmReversed);

    UtmZone zone;
    UtmZone.tryFromNumber(
        number: 33,
        result: zone);

    UtmCoordinate!double tagged;
    UtmCoordinate!double.tryFromComponents(
        zone: zone,
        hemisphere: UtmHemisphere.north,
        easting: 500_000.0,
        northing: 5_300_000.0,
        result: tagged);

    UtmProjection!double utm;
    UtmProjection!double.tryFromZone(
        ellipsoid: ellipsoid,
        zone: zone,
        hemisphere: UtmHemisphere.north,
        result: utm);

    UtmZone selectedZone;
    UtmHemisphere selectedHemisphere;
    tryStandardUtmZone(
        source: projectionSource,
        zone: selectedZone,
        hemisphere: selectedHemisphere);

    UtmCoordinate!double automatic;
    tryForwardUtm(
        ellipsoid: ellipsoid,
        source: projectionSource,
        result: automatic);

    GeographicCoordinate!double automaticReversed;
    tryReverseUtm(
        ellipsoid: ellipsoid,
        source: automatic,
        result: automaticReversed);

    Geodesic!double geodesic;
    Geodesic!double.tryFromEllipsoid(
        ellipsoid: ellipsoid,
        result: geodesic);

    GeodesicDirectResult!double direct;
    geodesic.tryDirect(
        start: projectionSource,
        initialAzimuth: angle,
        distance: 1_000.0,
        result: direct);

    GeodesicInverseResult!double inverse;
    geodesic.tryInverse(
        start: projectionSource,
        end: geographic,
        result: inverse);

    cast(void) projected;
    cast(void) translated;
    cast(void) pvTarget;
    cast(void) tmReversed;
    cast(void) tagged;
    cast(void) selectedZone;
    cast(void) selectedHemisphere;
    cast(void) automaticReversed;
    cast(void) direct;
    cast(void) inverse;
}


private void throwingNamedArgumentContract()
    @safe
{
    const latitude =
        Latitude!double.fromDegrees(
            degrees: 48.0);

    const longitude =
        Longitude!double.fromDegrees(
            degrees: 16.0);

    const ellipsoid =
        Ellipsoid!double.fromInverseFlattening(
            semiMajorAxis: 6_378_137.0,
            inverseFlattening: 298.257223563);

    const source =
        GeographicCoordinate!double.fromComponents(
            latitude: latitude,
            longitude: longitude);

    const projected =
        ProjectedCoordinate!double.fromComponents(
            easting: 500_000.0,
            northing: 5_300_000.0);

    const translation =
        GeocentricTranslation!double.fromComponents(
            deltaX: 1.0,
            deltaY: 2.0,
            deltaZ: 3.0);

    const geocentric =
        GeocentricCoordinate!double.fromComponents(
            x: 1.0,
            y: 2.0,
            z: 3.0);

    const shifted =
        applyGeocentricTranslation(
            source: geocentric,
            translation: translation);

    const tm =
        TransverseMercator!double.fromParameters(
            ellipsoid: ellipsoid,
            latitudeOfNaturalOrigin:
                Latitude!double.fromDegrees(degrees: 0.0),
            longitudeOfNaturalOrigin:
                Longitude!double.fromDegrees(degrees: 15.0),
            scaleFactorAtNaturalOrigin: 0.9996,
            falseEasting: 500_000.0,
            falseNorthing: 0.0);

    const tmForward =
        tm.forward(
            source: source);

    const tmReverse =
        tm.reverse(
            source: tmForward);

    const zone =
        UtmZone.fromNumber(
            number: 33);

    const utm =
        UtmProjection!double.fromZone(
            ellipsoid: ellipsoid,
            zone: zone,
            hemisphere: UtmHemisphere.north);

    const utmForward =
        utm.forward(
            source: source);

    const tagged =
        UtmCoordinate!double.fromComponents(
            zone: zone,
            hemisphere: UtmHemisphere.north,
            easting: utmForward.easting,
            northing: utmForward.northing);

    const autoForward =
        forwardUtm(
            ellipsoid: ellipsoid,
            source: source);

    const autoReverse =
        reverseUtm(
            ellipsoid: ellipsoid,
            source: autoForward);

    const geodesic =
        Geodesic!double.fromEllipsoid(
            ellipsoid: ellipsoid);

    cast(void) projected;
    cast(void) shifted;
    cast(void) tmReverse;
    cast(void) tagged;
    cast(void) autoReverse;
    cast(void) geodesic;
}
