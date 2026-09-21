module named_arguments_contract;

import geodesy;


/*
 * Public parameter names are source compatibility in D because callers may
 * use named arguments. This file deliberately exercises every public callable
 * in the current aggregate API that accepts one or more arguments.
 *
 * Parameterless properties and operations are outside this contract.
 */
private void checkedNamedArgumentContract()
    pure nothrow @safe @nogc
{
    Angle!double angleRadians;
    Angle!double.tryFromRadians(
        radians: 0.25,
        result: angleRadians);

    Angle!double angleDegrees;
    Angle!double.tryFromDegrees(
        degrees: 1.0,
        result: angleDegrees);

    Latitude!double latitudeRadians;
    Latitude!double.tryFromRadians(
        radians: 0.5,
        result: latitudeRadians);

    Latitude!double latitude;
    Latitude!double.tryFromDegrees(
        degrees: 48.0,
        result: latitude);

    Longitude!double longitudeRadians;
    Longitude!double.tryFromRadians(
        radians: 0.25,
        result: longitudeRadians);

    Longitude!double longitude;
    Longitude!double.tryFromDegrees(
        degrees: 16.0,
        result: longitude);

    Ellipsoid!double flatteningEllipsoid;
    Ellipsoid!double.tryFromFlattening(
        semiMajorAxis: 6_378_137.0,
        flattening: 1.0 / 298.257223563,
        result: flatteningEllipsoid);

    Ellipsoid!double ellipsoid;
    Ellipsoid!double.tryFromInverseFlattening(
        semiMajorAxis: 6_378_137.0,
        inverseFlattening: 298.257223563,
        result: ellipsoid);

    Ellipsoid!double axesEllipsoid;
    Ellipsoid!double.tryFromAxes(
        semiMajorAxis: 6_378_137.0,
        semiMinorAxis: 6_356_752.314245,
        result: axesEllipsoid);

    Ellipsoid!double sphereEllipsoid;
    Ellipsoid!double.trySphere(
        radius: 6_371_000.0,
        result: sphereEllipsoid);

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

    GeocentricCoordinate!double convertedGeocentric;
    tryGeodeticToGeocentric(
        source: geodetic,
        ellipsoid: ellipsoid,
        result: convertedGeocentric);

    GeodeticCoordinate!double convertedGeodetic;
    tryGeocentricToGeodetic(
        source: convertedGeocentric,
        ellipsoid: ellipsoid,
        result: convertedGeodetic);

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

    PositionVectorHelmert!double pvCanonical;
    PositionVectorHelmert!double.tryFromCanonical(
        translationX: 1.0,
        translationY: 2.0,
        translationZ: 3.0,
        rotationX: Angle!double.init,
        rotationY: Angle!double.init,
        rotationZ: angleRadians,
        scaleDifference: 1.0e-6,
        result: pvCanonical);

    CoordinateFrameHelmert!double cfCanonical;
    CoordinateFrameHelmert!double.tryFromCanonical(
        translationX: 1.0,
        translationY: 2.0,
        translationZ: 3.0,
        rotationX: Angle!double.init,
        rotationY: Angle!double.init,
        rotationZ: angleRadians,
        scaleDifference: 1.0e-6,
        result: cfCanonical);

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

    CoordinateFrameHelmert!double cf;
    CoordinateFrameHelmert!double.tryFromArcSecondsAndPpm(
        translationX: 1.0,
        translationY: 2.0,
        translationZ: 3.0,
        rotationXArcSeconds: 0.1,
        rotationYArcSeconds: 0.2,
        rotationZArcSeconds: 0.3,
        scaleDifferencePpm: 0.4,
        result: cf);

    GeocentricCoordinate!double pvTarget;
    tryApplyPositionVectorHelmert(
        source: geocentric,
        transform: pv,
        result: pvTarget);

    GeocentricCoordinate!double cfTarget;
    tryApplyCoordinateFrameHelmert(
        source: geocentric,
        transform: cf,
        result: cfTarget);

    const convertedCf =
        toCoordinateFrame(
            source: pvCanonical);

    const convertedPv =
        toPositionVector(
            source: cfCanonical);

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

    ConformalProjectionFactors!double tmForwardFactors;
    tm.tryForwardFactors(
        source: projectionSource,
        result: tmForwardFactors);

    GeographicCoordinate!double tmReversed;
    tm.tryReverse(
        source: tmProjected,
        result: tmReversed);

    ConformalProjectionFactors!double tmReverseFactors;
    tm.tryReverseFactors(
        source: tmProjected,
        result: tmReverseFactors);

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

    ProjectedCoordinate!double utmProjected;
    utm.tryForward(
        source: projectionSource,
        result: utmProjected);

    GeographicCoordinate!double utmReversed;
    utm.tryReverse(
        source: utmProjected,
        result: utmReversed);

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
        initialAzimuth: angleDegrees,
        distance: 1_000.0,
        result: direct);

    GeodesicInverseResult!double inverse;
    geodesic.tryInverse(
        start: projectionSource,
        end: geographic,
        result: inverse);

    TopocentricCoordinate!double topocentricCoordinate;

    TopocentricCoordinate!double.tryFromComponents(
        east: 1.0,
        north: 2.0,
        up: 3.0,
        result: topocentricCoordinate);

    TopocentricFrame!double topocentricGeodeticFrame;

    TopocentricFrame!double.tryFromGeodeticOrigin(
        ellipsoid: ellipsoid,
        origin: geodetic,
        result: topocentricGeodeticFrame);

    TopocentricFrame!double topocentricGeocentricFrame;

    TopocentricFrame!double.tryFromGeocentricOrigin(
        ellipsoid: ellipsoid,
        origin: convertedGeocentric,
        result: topocentricGeocentricFrame);

    TopocentricCoordinate!double localFromGeodetic;

    topocentricGeodeticFrame.tryGeodeticToTopocentric(
        source: geodetic,
        result: localFromGeodetic);

    GeodeticCoordinate!double topocentricGeodeticResult;

    topocentricGeodeticFrame.tryTopocentricToGeodetic(
        source: topocentricCoordinate,
        result: topocentricGeodeticResult);

    TopocentricCoordinate!double localFromGeocentric;

    topocentricGeocentricFrame.tryGeocentricToTopocentric(
        source: convertedGeocentric,
        result: localFromGeocentric);

    GeocentricCoordinate!double topocentricGeocentricResult;

    topocentricGeocentricFrame.tryTopocentricToGeocentric(
        source: topocentricCoordinate,
        result: topocentricGeocentricResult);

    cast(void) localFromGeodetic;
    cast(void) topocentricGeodeticResult;
    cast(void) localFromGeocentric;
    cast(void) topocentricGeocentricResult;

    cast(void) latitudeRadians;
    cast(void) longitudeRadians;
    cast(void) flatteningEllipsoid;
    cast(void) axesEllipsoid;
    cast(void) sphereEllipsoid;
    cast(void) projected;
    cast(void) convertedGeodetic;
    cast(void) translated;
    cast(void) pvTarget;
    cast(void) cfTarget;
    cast(void) convertedCf;
    cast(void) convertedPv;
    cast(void) tmForwardFactors;
    cast(void) tmReversed;
    cast(void) tmReverseFactors;
    cast(void) tagged;
    cast(void) utmReversed;
    cast(void) selectedZone;
    cast(void) selectedHemisphere;
    cast(void) automaticReversed;
    cast(void) direct;
    cast(void) inverse;
}


private void throwingNamedArgumentContract()
    @safe
{
    const angleRadians =
        Angle!double.fromRadians(
            radians: 0.25);

    const angleDegrees =
        Angle!double.fromDegrees(
            degrees: 1.0);

    const latitudeRadians =
        Latitude!double.fromRadians(
            radians: 0.5);

    const latitude =
        Latitude!double.fromDegrees(
            degrees: 48.0);

    const longitudeRadians =
        Longitude!double.fromRadians(
            radians: 0.25);

    const longitude =
        Longitude!double.fromDegrees(
            degrees: 16.0);

    const flatteningEllipsoid =
        Ellipsoid!double.fromFlattening(
            semiMajorAxis: 6_378_137.0,
            flattening: 1.0 / 298.257223563);

    const ellipsoid =
        Ellipsoid!double.fromInverseFlattening(
            semiMajorAxis: 6_378_137.0,
            inverseFlattening: 298.257223563);

    const axesEllipsoid =
        Ellipsoid!double.fromAxes(
            semiMajorAxis: 6_378_137.0,
            semiMinorAxis: 6_356_752.314245);

    const sphereEllipsoid =
        Ellipsoid!double.sphere(
            radius: 6_371_000.0);

    const source =
        GeographicCoordinate!double.fromComponents(
            latitude: latitude,
            longitude: longitude);

    const geodetic =
        GeodeticCoordinate!double.fromComponents(
            latitude: latitude,
            longitude: longitude,
            ellipsoidalHeight: 100.0);

    const geocentric =
        GeocentricCoordinate!double.fromComponents(
            x: 1.0,
            y: 2.0,
            z: 3.0);

    const projected =
        ProjectedCoordinate!double.fromComponents(
            easting: 500_000.0,
            northing: 5_300_000.0);

    const convertedGeocentric =
        geodeticToGeocentric(
            source: geodetic,
            ellipsoid: ellipsoid);

    const convertedGeodetic =
        geocentricToGeodetic(
            source: convertedGeocentric,
            ellipsoid: ellipsoid);

    const translation =
        GeocentricTranslation!double.fromComponents(
            deltaX: 1.0,
            deltaY: 2.0,
            deltaZ: 3.0);

    const shifted =
        applyGeocentricTranslation(
            source: geocentric,
            translation: translation);

    const pvCanonical =
        PositionVectorHelmert!double.fromCanonical(
            translationX: 1.0,
            translationY: 2.0,
            translationZ: 3.0,
            rotationX: Angle!double.init,
            rotationY: Angle!double.init,
            rotationZ: angleRadians,
            scaleDifference: 1.0e-6);

    const cfCanonical =
        CoordinateFrameHelmert!double.fromCanonical(
            translationX: 1.0,
            translationY: 2.0,
            translationZ: 3.0,
            rotationX: Angle!double.init,
            rotationY: Angle!double.init,
            rotationZ: angleRadians,
            scaleDifference: 1.0e-6);

    const pv =
        PositionVectorHelmert!double.fromArcSecondsAndPpm(
            translationX: 1.0,
            translationY: 2.0,
            translationZ: 3.0,
            rotationXArcSeconds: 0.1,
            rotationYArcSeconds: 0.2,
            rotationZArcSeconds: 0.3,
            scaleDifferencePpm: 0.4);

    const cf =
        CoordinateFrameHelmert!double.fromArcSecondsAndPpm(
            translationX: 1.0,
            translationY: 2.0,
            translationZ: 3.0,
            rotationXArcSeconds: 0.1,
            rotationYArcSeconds: 0.2,
            rotationZArcSeconds: 0.3,
            scaleDifferencePpm: 0.4);

    const pvTarget =
        applyPositionVectorHelmert(
            source: geocentric,
            transform: pv);

    const cfTarget =
        applyCoordinateFrameHelmert(
            source: geocentric,
            transform: cf);

    const convertedCf =
        toCoordinateFrame(
            source: pvCanonical);

    const convertedPv =
        toPositionVector(
            source: cfCanonical);

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

    const tmForwardFactors =
        tm.forwardFactors(
            source: source);

    const tmReverseFactors =
        tm.reverseFactors(
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

    const utmReverse =
        utm.reverse(
            source: utmForward);

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

    const topocentricCoordinate =
        TopocentricCoordinate!double.fromComponents(
            east: 1.0,
            north: 2.0,
            up: 3.0);

    const topocentricGeodeticFrame =
        TopocentricFrame!double.fromGeodeticOrigin(
            ellipsoid: ellipsoid,
            origin: geodetic);

    const topocentricGeocentricFrame =
        TopocentricFrame!double.fromGeocentricOrigin(
            ellipsoid: ellipsoid,
            origin: convertedGeocentric);

    const localFromGeodetic =
        topocentricGeodeticFrame.geodeticToTopocentric(
            source: geodetic);

    const topocentricGeodeticResult =
        topocentricGeodeticFrame.topocentricToGeodetic(
            source: topocentricCoordinate);

    const localFromGeocentric =
        topocentricGeocentricFrame.geocentricToTopocentric(
            source: convertedGeocentric);

    const topocentricGeocentricResult =
        topocentricGeocentricFrame.topocentricToGeocentric(
            source: topocentricCoordinate);

    cast(void) localFromGeodetic;
    cast(void) topocentricGeodeticResult;
    cast(void) localFromGeocentric;
    cast(void) topocentricGeocentricResult;

    const geodesic =
        Geodesic!double.fromEllipsoid(
            ellipsoid: ellipsoid);

    cast(void) angleDegrees;
    cast(void) latitudeRadians;
    cast(void) longitudeRadians;
    cast(void) flatteningEllipsoid;
    cast(void) axesEllipsoid;
    cast(void) sphereEllipsoid;
    cast(void) projected;
    cast(void) convertedGeodetic;
    cast(void) shifted;
    cast(void) pvTarget;
    cast(void) cfTarget;
    cast(void) convertedCf;
    cast(void) convertedPv;
    cast(void) tmReverse;
    cast(void) tmForwardFactors;
    cast(void) tmReverseFactors;
    cast(void) utmReverse;
    cast(void) tagged;
    cast(void) autoReverse;
    cast(void) geodesic;
}
