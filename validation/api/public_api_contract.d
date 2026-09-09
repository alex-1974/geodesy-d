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
static assert(is(GeocentricTranslation!double));

static assert(is(PositionVectorHelmert!double ==
    Helmert7!(double, HelmertConvention.positionVector)));
static assert(is(CoordinateFrameHelmert!double ==
    Helmert7!(double, HelmertConvention.coordinateFrame)));
static assert(!is(PositionVectorHelmert!double ==
    CoordinateFrameHelmert!double));

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

    cast(void) angle;
    cast(void) normalized;
    cast(void) longitudeAngle;
    cast(void) latitudeAngle;
    cast(void) valid;
    cast(void) a; cast(void) b; cast(void) f; cast(void) invF;
    cast(void) e2; cast(void) ep2; cast(void) n;
    cast(void) inverseShift; cast(void) pvAgain;
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
    GeodesyValueException exception = new GeodesyValueException("contract");
    cast(void) angle; cast(void) geodeticAgain; cast(void) shifted;
    cast(void) pvTarget; cast(void) cfTarget; cast(void) exception;
}
