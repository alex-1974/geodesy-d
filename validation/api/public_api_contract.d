module public_api_contract;

import geodesy;

static assert(isGeodesyScalar!float);
static assert(isGeodesyScalar!double);
static assert(isGeodesyScalar!real);
static assert(!isGeodesyScalar!int);

static assert(is(Angle!double));
static assert(is(Latitude!double));
static assert(is(Longitude!double));
static assert(is(Ellipsoid!double));
static assert(is(GeodeticCoordinate!double));
static assert(is(GeocentricCoordinate!double));

private enum v1ZeroHeightGeodetic =
    GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0));

static assert(v1ZeroHeightGeodetic.ellipsoidalHeight == 0.0);

static assert(is(TopocentricCoordinate!float));
static assert(is(TopocentricCoordinate!double));
static assert(is(TopocentricCoordinate!real));
static assert(is(TopocentricFrame!float));
static assert(is(TopocentricFrame!double));
static assert(is(TopocentricFrame!real));

static assert(is(GeocentricTranslation!double));
static assert(is(Epoch!float));
static assert(is(Epoch!double));
static assert(is(Epoch!real));
static assert(is(ProjectedCoordinate!double));

static assert(is(ConformalProjectionFactors!float));
static assert(is(ConformalProjectionFactors!double));
static assert(is(ConformalProjectionFactors!real));

static assert(is(PseudoMercator!float));
static assert(is(PseudoMercator!double));
static assert(is(PseudoMercator!real));

static assert(is(TransverseMercator!double));
static assert(is(UtmZone));
static assert(is(UtmCoordinate!double));
static assert(is(UtmProjection!double));
static assert(is(typeof(UtmHemisphere.north) == UtmHemisphere));
static assert(UtmHemisphere.init == UtmHemisphere.north);
static assert(is(Geodesic!float));
static assert(is(Geodesic!double));
static assert(is(Geodesic!real));
static assert(is(GeodesicDirectResult!double));
static assert(is(GeodesicInverseResult!double));
static assert(is(GeodesicQuantities!double));
static assert(is(GeodesicLine!double));
static assert(is(GeodesicLineUnrolledResult!double));
static assert(is(GeodesicPolygonAccumulator!double));
static assert(is(GeodesicPolygonResult!double));

static assert(is(PositionVectorHelmert!double ==
    Helmert7!(double, HelmertConvention.positionVector)));
static assert(is(CoordinateFrameHelmert!double ==
    Helmert7!(double, HelmertConvention.coordinateFrame)));
static assert(!is(PositionVectorHelmert!double ==
    CoordinateFrameHelmert!double));
static assert(is(PositionVectorHelmert14!double ==
    Helmert14!(double, HelmertConvention.positionVector)));
static assert(is(CoordinateFrameHelmert14!double ==
    Helmert14!(double, HelmertConvention.coordinateFrame)));
static assert(!is(PositionVectorHelmert14!double ==
    CoordinateFrameHelmert14!double));

static assert(is(PositionVectorMolodenskyBadekas!double ==
    MolodenskyBadekas10!(double, HelmertConvention.positionVector)));
static assert(is(CoordinateFrameMolodenskyBadekas!double ==
    MolodenskyBadekas10!(double, HelmertConvention.coordinateFrame)));
static assert(!is(PositionVectorMolodenskyBadekas!double ==
    CoordinateFrameMolodenskyBadekas!double));

private void topocentricCheckedApiContract()
    pure nothrow @safe @nogc
{
    Ellipsoid!double ellipsoid;

    Ellipsoid!double.tryFromInverseFlattening(
        6_378_137.0,
        298.257223563,
        ellipsoid);

    Latitude!double latitude;
    Longitude!double longitude;

    Latitude!double.tryFromDegrees(
        48.0,
        latitude);

    Longitude!double.tryFromDegrees(
        16.0,
        longitude);

    GeodeticCoordinate!double geodeticOrigin;

    GeodeticCoordinate!double.tryFromComponents(
        latitude,
        longitude,
        100.0,
        geodeticOrigin);

    GeocentricCoordinate!double geocentricOrigin;

    tryGeodeticToGeocentric(
        geodeticOrigin,
        ellipsoid,
        geocentricOrigin);

    TopocentricCoordinate!double coordinate;

    TopocentricCoordinate!double.tryFromComponents(
        1.0,
        2.0,
        3.0,
        coordinate);

    const east = coordinate.east;
    const north = coordinate.north;
    const up = coordinate.up;

    TopocentricFrame!double geodeticFrame;

    TopocentricFrame!double.tryFromGeodeticOrigin(
        ellipsoid,
        geodeticOrigin,
        geodeticFrame);

    TopocentricFrame!double geocentricFrame;

    TopocentricFrame!double.tryFromGeocentricOrigin(
        ellipsoid,
        geocentricOrigin,
        geocentricFrame);

    const valid =
        geodeticFrame.isValid;

    const frameEllipsoid =
        geodeticFrame.ellipsoid;

    TopocentricCoordinate!double geodeticLocal;

    geodeticFrame.tryGeodeticToTopocentric(
        geodeticOrigin,
        geodeticLocal);

    GeodeticCoordinate!double geodeticResult;

    geodeticFrame.tryTopocentricToGeodetic(
        geodeticLocal,
        geodeticResult);

    TopocentricCoordinate!double geocentricLocal;

    geocentricFrame.tryGeocentricToTopocentric(
        geocentricOrigin,
        geocentricLocal);

    GeocentricCoordinate!double geocentricResult;

    geocentricFrame.tryTopocentricToGeocentric(
        geocentricLocal,
        geocentricResult);

    cast(void) east;
    cast(void) north;
    cast(void) up;
    cast(void) valid;
    cast(void) frameEllipsoid;
    cast(void) geodeticResult;
    cast(void) geocentricResult;
}


private void topocentricThrowingApiContract()
    @safe
{
    const ellipsoid =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257223563);

    const geodetic =
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0),
            100.0);

    const geocentric =
        geodeticToGeocentric(
            geodetic,
            ellipsoid);

    const topocentric =
        TopocentricCoordinate!double.fromComponents(
            1.0,
            2.0,
            3.0);

    const geodeticFrame =
        TopocentricFrame!double.fromGeodeticOrigin(
            ellipsoid,
            geodetic);

    const geocentricFrame =
        TopocentricFrame!double.fromGeocentricOrigin(
            ellipsoid,
            geocentric);

    const a =
        geodeticFrame.geodeticToTopocentric(
            geodetic);

    const b =
        geodeticFrame.topocentricToGeodetic(
            topocentric);

    const c =
        geocentricFrame.geocentricToTopocentric(
            geocentric);

    const d =
        geocentricFrame.topocentricToGeocentric(
            topocentric);

    cast(void) a;
    cast(void) b;
    cast(void) c;
    cast(void) d;
}


private void checkedApiContract()
    pure nothrow @safe @nogc
{
    Angle!double angle;
    Latitude!double latitude;
    Longitude!double longitude;

    Angle!double.tryFromRadians(0.25, angle);
    Latitude!double.tryFromDegrees(48.0, latitude);
    Longitude!double.tryFromDegrees(16.0, longitude);

    auto normalized = longitude.normalized;
    auto longitudeAngle = longitude.asAngle;
    auto latitudeAngle = latitude.asAngle;

    Ellipsoid!double ellipsoid;
    Ellipsoid!double.trySphere(6_371_000.0, ellipsoid);
    const valid = ellipsoid.isValid;

    auto a = ellipsoid.semiMajorAxis;
    auto b = ellipsoid.semiMinorAxis;
    auto f = ellipsoid.flattening;
    auto invF = ellipsoid.inverseFlattening;
    auto e2 = ellipsoid.firstEccentricitySquared;
    auto ep2 = ellipsoid.secondEccentricitySquared;
    auto n = ellipsoid.thirdFlattening;

    GeodeticCoordinate!double geodetic;
    GeodeticCoordinate!double.tryFromComponents(
        latitude, longitude, 100.0, geodetic);

    GeocentricCoordinate!double geocentric;
    GeocentricCoordinate!double.tryFromComponents(
        1.0, 2.0, 3.0, geocentric);

    GeocentricCoordinate!double forward;
    tryGeodeticToGeocentric(geodetic, ellipsoid, forward);

    GeodeticCoordinate!double reverse;
    tryGeocentricToGeodetic(forward, ellipsoid, reverse);

    GeocentricTranslation!double shift;
    GeocentricTranslation!double.tryFromComponents(1.0, 2.0, 3.0, shift);
    auto inverseShift = shift.inverse();

    GeocentricCoordinate!double translated;
    tryApplyGeocentricTranslation(geocentric, shift, translated);

    PositionVectorHelmert!double pv;
    PositionVectorHelmert!double.tryFromArcSecondsAndPpm(
        1.0, 2.0, 3.0, 0.1, 0.2, 0.3, 0.4, pv);

    CoordinateFrameHelmert!double cf = toCoordinateFrame(pv);
    auto pvAgain = toPositionVector(cf);

    GeocentricCoordinate!double pvTarget;
    tryApplyPositionVectorHelmert(geocentric, pv, pvTarget);

    GeocentricCoordinate!double cfTarget;
    tryApplyCoordinateFrameHelmert(geocentric, cf, cfTarget);

    Epoch!double referenceEpoch;
    Epoch!double.tryFromDecimalYear(2000.0, referenceEpoch);

    Epoch!double observationEpoch;
    Epoch!double.tryFromDecimalYear(2020.0, observationEpoch);

    PositionVectorHelmert14!double dynamicPv;
    PositionVectorHelmert14!double.tryFromCanonical(
        pv,
        0.001, 0.002, 0.003,
        1e-9, 2e-9, 3e-9,
        1e-10,
        referenceEpoch,
        dynamicPv);

    PositionVectorHelmert!double evaluatedPv;
    dynamicPv.tryEvaluate(observationEpoch, evaluatedPv);

    GeocentricCoordinate!double dynamicTarget;
    dynamicPv.tryApply(geocentric, observationEpoch, dynamicTarget);

    const dynamicCf = toCoordinateFrameHelmert14(dynamicPv);
    const dynamicPvAgain = toPositionVectorHelmert14(dynamicCf);

    PositionVectorMolodenskyBadekas!double mbPv;
    PositionVectorMolodenskyBadekas!double.tryFromArcSecondsAndPpm(
        -270.933, 115.599, -360.226,
        5.266, 1.238, -2.381, -5.109,
        2_464_351.59, -5_783_466.61, 974_809.81,
        mbPv);

    const mbCf = toCoordinateFrameMolodenskyBadekas(mbPv);
    const mbPvAgain = toPositionVectorMolodenskyBadekas(mbCf);

    GeocentricCoordinate!double mbTarget;
    mbPv.tryApply(geocentric, mbTarget);

    const mbBase = mbPv.baseParameters;
    const mbEquivalent = mbPv.equivalentHelmert;
    const mbPx = mbPv.evaluationPointX;
    const mbPy = mbPv.evaluationPointY;
    const mbPz = mbPv.evaluationPointZ;

    Geodesic!double geodesic;

    Geodesic!double.tryFromEllipsoid(
        ellipsoid,
        geodesic);

    const geodesicValid =
        geodesic.isValid;

    const geodesicSphere =
        geodesic.isSphere;

    const geodesicEllipsoid =
        geodesic.ellipsoid;

    const geographicStart =
        GeographicCoordinate!double.fromComponents(
            latitude,
            longitude);

    const geographicEnd =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.init,
            Longitude!double.init);

    GeodesicDirectResult!double directResult;

    geodesic.tryDirect(
        geographicStart,
        angle,
        1000.0,
        directResult);

    const directPosition =
        directResult.position;

    const directFinalAzimuth =
        directResult.finalAzimuth;

    GeodesicInverseResult!double inverseResult;

    geodesic.tryInverse(
        geographicStart,
        geographicEnd,
        inverseResult);

    const inverseDistance =
        inverseResult.distance;

    const inverseInitialAzimuth =
        inverseResult.initialAzimuth;

    const inverseFinalAzimuth =
        inverseResult.finalAzimuth;

    cast(void) geodesicValid;
    cast(void) geodesicSphere;
    cast(void) geodesicEllipsoid;
    cast(void) directPosition;
    cast(void) directFinalAzimuth;
    cast(void) inverseDistance;
    cast(void) inverseInitialAzimuth;
    cast(void) inverseFinalAzimuth;

    cast(void) angle;
    cast(void) normalized;
    cast(void) longitudeAngle;
    cast(void) latitudeAngle;
    cast(void) valid;
    cast(void) a; cast(void) b; cast(void) f; cast(void) invF;
    cast(void) e2; cast(void) ep2; cast(void) n;
    cast(void) inverseShift; cast(void) pvAgain;
    cast(void) evaluatedPv; cast(void) dynamicTarget; cast(void) dynamicPvAgain;
    cast(void) mbCf; cast(void) mbPvAgain; cast(void) mbTarget;
    cast(void) mbBase; cast(void) mbEquivalent;
    cast(void) mbPx; cast(void) mbPy; cast(void) mbPz;
}


private void geodesicM2CheckedApiContract()
    pure nothrow @safe @nogc
{
    Ellipsoid!double ellipsoid;
    Ellipsoid!double.tryFromInverseFlattening(
        6_378_137.0,
        298.257223563,
        ellipsoid);

    Geodesic!double solver;
    Geodesic!double.tryFromEllipsoid(
        ellipsoid,
        solver);

    Latitude!double latitude48;
    Latitude!double latitude49;
    Longitude!double longitude16;
    Longitude!double longitude17;
    Latitude!double.tryFromDegrees(48.0, latitude48);
    Latitude!double.tryFromDegrees(49.0, latitude49);
    Longitude!double.tryFromDegrees(16.0, longitude16);
    Longitude!double.tryFromDegrees(17.0, longitude17);

    const start =
        GeographicCoordinate!double.fromComponents(
            latitude48,
            longitude16);

    Angle!double azimuth;
    Angle!double.tryFromDegrees(
        60.0,
        azimuth);

    Angle!double arcOne;
    Angle!double.tryFromDegrees(
        1.0,
        arcOne);

    Angle!double arc361;
    Angle!double.tryFromDegrees(
        361.0,
        arc361);

    GeodesicLine!double line;
    GeodesicLine!double.tryFromGeodesic(
        solver,
        start,
        azimuth,
        line);

    GeodesicDirectResult!double position10;
    GeodesicDirectResult!double position25;

    line.tryPosition(
        10_000.0,
        position10);

    line.tryPosition(
        25_000.0,
        position25);

    GeodesicDirectResult!double advancedDistancePosition;
    GeodesicQuantities!double distanceQuantities;

    line.tryPosition(
        25_000.0,
        advancedDistancePosition,
        distanceQuantities);

    GeodesicDirectResult!double arcPosition;
    line.tryArcPosition(
        arcOne,
        arcPosition);

    GeodesicDirectResult!double advancedArcPosition;
    GeodesicQuantities!double arcQuantities;

    line.tryArcPosition(
        arcOne,
        advancedArcPosition,
        arcQuantities);

    GeodesicLineUnrolledResult!double unrolledDistance;
    line.tryPositionUnrolled(
        50_000.0,
        unrolledDistance);

    GeodesicLineUnrolledResult!double unrolledArc;
    line.tryArcPositionUnrolled(
        arc361,
        unrolledArc);

    const unrolledLatitude =
        unrolledArc.latitude;
    const unrolledLongitude =
        unrolledArc.unrolledLongitude;
    const unrolledAzimuth =
        unrolledArc.finalAzimuth;

    GeodesicPolygonAccumulator!double polygon;
    GeodesicPolygonAccumulator!double.tryFromGeodesic(
        solver,
        polygon);

    polygon.tryAddPoint(start);
    polygon.tryAddPoint(
        GeographicCoordinate!double.fromComponents(
            latitude48,
            longitude17));
    polygon.tryAddPoint(
        GeographicCoordinate!double.fromComponents(
            latitude49,
            longitude16));

    GeodesicPolygonResult!double measurement;
    polygon.tryCompute(measurement);

    const perimeter = measurement.perimeter;
    const signedArea = measurement.signedArea;

    cast(void) position10;
    cast(void) position25;
    cast(void) advancedDistancePosition;
    cast(void) distanceQuantities;
    cast(void) arcPosition;
    cast(void) advancedArcPosition;
    cast(void) arcQuantities;
    cast(void) unrolledDistance;
    cast(void) unrolledLatitude;
    cast(void) unrolledLongitude;
    cast(void) unrolledAzimuth;
    cast(void) perimeter;
    cast(void) signedArea;
}


private void geodesicM2ThrowingApiContract()
    @safe
{
    auto ellipsoid =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257223563);

    auto solver =
        Geodesic!double.fromEllipsoid(
            ellipsoid);

    auto start =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0));

    auto line =
        GeodesicLine!double.fromGeodesic(
            solver,
            start,
            Angle!double.fromDegrees(60.0));

    auto position =
        line.position(10_000.0);

    auto arcPosition =
        line.arcPosition(
            Angle!double.fromDegrees(1.0));

    auto unrolledPosition =
        line.positionUnrolled(10_000.0);

    auto unrolledArc =
        line.arcPositionUnrolled(
            Angle!double.fromDegrees(361.0));

    auto polygon =
        GeodesicPolygonAccumulator!double.fromGeodesic(
            solver);

    polygon.addPoint(start);
    polygon.addPoint(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(17.0)));
    polygon.addPoint(
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(49.0),
            Longitude!double.fromDegrees(16.0)));

    auto measurement =
        polygon.compute();

    cast(void) position;
    cast(void) arcPosition;
    cast(void) unrolledPosition;
    cast(void) unrolledArc;
    cast(void) measurement;
}


private void projectionApiContract()
    pure nothrow @safe @nogc
{
    Ellipsoid!double ellipsoid;
    Ellipsoid!double.tryFromInverseFlattening(
        6_378_137.0,
        298.257223563,
        ellipsoid);

    Latitude!double latitude0;
    Longitude!double longitude15;
    Latitude!double.tryFromDegrees(0.0, latitude0);
    Longitude!double.tryFromDegrees(15.0, longitude15);

    const source =
        GeographicCoordinate!double.fromComponents(
            latitude0,
            longitude15);

    ProjectedCoordinate!double projectedCoordinate;
    ProjectedCoordinate!double.tryFromComponents(
        500_000.0,
        0.0,
        projectedCoordinate);

    ConformalProjectionFactors!double factors;

    static assert(
        is(typeof(factors.meridianConvergence) == Angle!double));
    static assert(
        is(typeof(factors.pointScale) == double));

    const factorConvergence =
        factors.meridianConvergence;
    const factorScale =
        factors.pointScale;

    PseudoMercator!double pseudoMercator;
    PseudoMercator!double.tryFromParameters(
        ellipsoid,
        longitude15,
        500_000.0,
        1_000_000.0,
        pseudoMercator);

    const pseudoMercatorValid =
        pseudoMercator.isValid;

    const pseudoMercatorEllipsoid =
        pseudoMercator.ellipsoid;

    const pseudoMercatorLongitude0 =
        pseudoMercator.longitudeOfNaturalOrigin;

    const pseudoMercatorFalseEasting =
        pseudoMercator.falseEasting;

    const pseudoMercatorFalseNorthing =
        pseudoMercator.falseNorthing;

    ProjectedCoordinate!double pseudoMercatorProjected;
    pseudoMercator.tryForward(
        source,
        pseudoMercatorProjected);

    GeographicCoordinate!double pseudoMercatorReversed;
    pseudoMercator.tryReverse(
        pseudoMercatorProjected,
        pseudoMercatorReversed);

    TransverseMercator!double tm;
    TransverseMercator!double.tryFromParameters(
        ellipsoid,
        latitude0,
        longitude15,
        0.9996,
        500_000.0,
        0.0,
        tm);

    ProjectedCoordinate!double tmProjected;
    tm.tryForward(source, tmProjected);

    ConformalProjectionFactors!double tmForwardFactors;
    tm.tryForwardFactors(
        source,
        tmForwardFactors);

    GeographicCoordinate!double tmReversed;
    tm.tryReverse(tmProjected, tmReversed);

    ConformalProjectionFactors!double tmReverseFactors;
    tm.tryReverseFactors(
        tmProjected,
        tmReverseFactors);

    UtmZone zone;
    UtmZone.tryFromNumber(33, zone);

    UtmCoordinate!double tagged;
    UtmCoordinate!double.tryFromComponents(
        zone,
        UtmHemisphere.north,
        500_000.0,
        0.0,
        tagged);

    UtmProjection!double utm;
    UtmProjection!double.tryFromZone(
        ellipsoid,
        zone,
        UtmHemisphere.north,
        utm);

    ProjectedCoordinate!double utmProjected;
    utm.tryForward(source, utmProjected);

    ConformalProjectionFactors!double utmForwardFactors;
    utm.tryForwardFactors(
        source,
        utmForwardFactors);

    GeographicCoordinate!double utmReversed;
    utm.tryReverse(utmProjected, utmReversed);

    ConformalProjectionFactors!double utmReverseFactors;
    utm.tryReverseFactors(
        utmProjected,
        utmReverseFactors);

    UtmZone selectedZone;
    UtmHemisphere selectedHemisphere;
    tryStandardUtmZone(
        source,
        selectedZone,
        selectedHemisphere);

    UtmCoordinate!double automatic;
    tryForwardUtm(
        source,
        ellipsoid,
        automatic);

    GeographicCoordinate!double automaticReversed;
    tryReverseUtm(
        automatic,
        ellipsoid,
        automaticReversed);

    cast(void) projectedCoordinate;
    cast(void) pseudoMercatorValid;
    cast(void) pseudoMercatorEllipsoid;
    cast(void) pseudoMercatorLongitude0;
    cast(void) pseudoMercatorFalseEasting;
    cast(void) pseudoMercatorFalseNorthing;
    cast(void) pseudoMercatorReversed;
    cast(void) factorConvergence;
    cast(void) factorScale;
    cast(void) tmReversed;
    cast(void) tagged;
    cast(void) utmForwardFactors;
    cast(void) utmReversed;
    cast(void) utmReverseFactors;
    cast(void) selectedZone;
    cast(void) selectedHemisphere;
    cast(void) automaticReversed;
}


private void throwingApiContract()
    @safe
{
    auto angle = Angle!double.fromDegrees(1.0);
    auto latitude = Latitude!double.fromDegrees(48.0);
    auto longitude = Longitude!double.fromDegrees(16.0);
    auto ellipsoid = Ellipsoid!double.fromInverseFlattening(
        6_378_137.0, 298.257223563);
    auto geodetic = GeodeticCoordinate!double.fromComponents(
        latitude, longitude, 100.0);
    auto geocentric = geodeticToGeocentric(geodetic, ellipsoid);
    auto geodeticAgain = geocentricToGeodetic(geocentric, ellipsoid);
    auto shift = GeocentricTranslation!double.fromComponents(1.0, 2.0, 3.0);
    auto shifted = applyGeocentricTranslation(geocentric, shift);
    auto pv = PositionVectorHelmert!double.fromArcSecondsAndPpm(
        1.0, 2.0, 3.0, 0.1, 0.2, 0.3, 0.4);
    auto pvTarget = applyPositionVectorHelmert(geocentric, pv);
    auto cf = toCoordinateFrame(pv);
    auto cfTarget = applyCoordinateFrameHelmert(geocentric, cf);

    auto referenceEpoch = Epoch!double.fromDecimalYear(2000.0);
    auto observationEpoch = Epoch!double.fromDecimalYear(2020.0);
    auto dynamicPv = PositionVectorHelmert14!double.fromCanonical(
        pv,
        0.001, 0.002, 0.003,
        1e-9, 2e-9, 3e-9,
        1e-10,
        referenceEpoch);
    auto evaluatedPv = dynamicPv.evaluate(observationEpoch);
    auto dynamicTarget = dynamicPv.apply(geocentric, observationEpoch);

    auto pseudoMercator =
        PseudoMercator!double.fromParameters(
            ellipsoid,
            longitude,
            500_000.0,
            1_000_000.0);

    auto pseudoProjected =
        pseudoMercator.forward(
            GeographicCoordinate!double.fromComponents(
                latitude,
                longitude));

    auto pseudoReversed =
        pseudoMercator.reverse(
            pseudoProjected);

    auto geodesic = Geodesic!double.fromEllipsoid(ellipsoid);
    GeodesyValueException exception = new GeodesyValueException("contract");
    cast(void) angle; cast(void) geodeticAgain; cast(void) shifted;
    cast(void) pvTarget; cast(void) cfTarget;
    cast(void) evaluatedPv; cast(void) dynamicTarget;
    cast(void) pseudoReversed;
    cast(void) geodesic;
    cast(void) exception;
}
