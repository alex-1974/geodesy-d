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

static assert(is(TopocentricCoordinate!float));
static assert(is(TopocentricCoordinate!double));
static assert(is(TopocentricCoordinate!real));
static assert(is(TopocentricFrame!float));
static assert(is(TopocentricFrame!double));
static assert(is(TopocentricFrame!real));

static assert(is(GeocentricTranslation!double));
static assert(is(ProjectedCoordinate!double));

static assert(is(ConformalProjectionFactors!float));
static assert(is(ConformalProjectionFactors!double));
static assert(is(ConformalProjectionFactors!real));

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

static assert(is(PositionVectorHelmert!double ==
    Helmert7!(double, HelmertConvention.positionVector)));
static assert(is(CoordinateFrameHelmert!double ==
    Helmert7!(double, HelmertConvention.coordinateFrame)));
static assert(!is(PositionVectorHelmert!double ==
    CoordinateFrameHelmert!double));

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

    GeographicCoordinate!double utmReversed;
    utm.tryReverse(utmProjected, utmReversed);

    UtmZone selectedZone;
    UtmHemisphere selectedHemisphere;
    tryStandardUtmZone(
        source,
        selectedZone,
        selectedHemisphere);

    UtmCoordinate!double automatic;
    tryForwardUtm(
        ellipsoid,
        source,
        automatic);

    GeographicCoordinate!double automaticReversed;
    tryReverseUtm(
        ellipsoid,
        automatic,
        automaticReversed);

    cast(void) projectedCoordinate;
    cast(void) factorConvergence;
    cast(void) factorScale;
    cast(void) tmReversed;
    cast(void) tagged;
    cast(void) utmReversed;
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
    auto geodesic = Geodesic!double.fromEllipsoid(ellipsoid);
    GeodesyValueException exception = new GeodesyValueException("contract");
    cast(void) angle; cast(void) geodeticAgain; cast(void) shifted;
    cast(void) pvTarget; cast(void) cfTarget; cast(void) geodesic;
    cast(void) exception;
}
