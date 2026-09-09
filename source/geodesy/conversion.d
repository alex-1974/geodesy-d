/** Geographic/geocentric coordinate conversions. */
module geodesy.conversion;

import std.math : atan2, cos, fabs, sin, sqrt;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.geodetic : GeodeticCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;


/**
 * Stable two-dimensional Euclidean norm.
 *
 * Avoids the avoidable intermediate overflow of sqrt(x*x + y*y).
 */
private T hypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T hi = ax >= ay ? ax : ay;
    const T lo = ax >= ay ? ay : ax;

    if (hi == cast(T) 0)
        return cast(T) 0;

    const T ratio = lo / hi;
    return hi * sqrt(cast(T) 1 + ratio * ratio);
}


/**
 * Convert a geodetic coordinate to geocentric Cartesian coordinates.
 *
 * Implements the forward direction of EPSG coordinate operation method 9602
 * (Geographic/geocentric conversions).
 *
 * The longitude is interpreted relative to the prime meridian defining the
 * geocentric X axis. For conventional EPSG geocentric systems this is the
 * Greenwich prime meridian.
 *
 * The ellipsoidal height and the ellipsoid axes must use the same linear unit.
 * The returned X/Y/Z components use that same unit.
 *
 * Returns false only when finite input values overflow or otherwise produce a
 * non-finite Cartesian result in scalar type T.
 */
bool tryGeodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!ellipsoid.isValid)
        return false;

    const T phi = source.latitude.radians;
    const T lambda = source.longitude.radians;
    const T h = source.ellipsoidalHeight;

    const T sinPhi = sin(phi);
    const T cosPhi = cos(phi);
    const T sinLambda = sin(lambda);
    const T cosLambda = cos(lambda);

    const T e2 = ellipsoid.firstEccentricitySquared;
    const T nu = ellipsoid.semiMajorAxis
        / sqrt(cast(T) 1 - e2 * sinPhi * sinPhi);

    const T radial = nu + h;
    const T x = radial * cosPhi * cosLambda;
    const T y = radial * cosPhi * sinLambda;
    const T z = ((cast(T) 1 - e2) * nu + h) * sinPhi;

    return GeocentricCoordinate!T.tryFromComponents(x, y, z, result);
}


/** Throwing convenience wrapper for `tryGeodeticToGeocentric`. */
GeocentricCoordinate!T geodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryGeodeticToGeocentric(source, ellipsoid, result))
        throw new GeodesyValueException(
            "Geodetic to geocentric conversion requires a valid ellipsoid and a finite representable result.");
    return result;
}


/**
 * Convert geocentric Cartesian coordinates to a geodetic coordinate.
 *
 * Implements the reverse direction of EPSG coordinate operation method 9602.
 *
 * The initial latitude is the direct Bowring form given by EPSG/IOGP. It is
 * then refined with the iterative EPSG relation
 *
 *   phi = atan2(Z + e² * nu * sin(phi), p)
 *
 * for a fixed number of iterations. A fixed iteration count deliberately
 * avoids introducing a library-wide floating-point equality/tolerance policy.
 *
 * The Earth/ellipsoid centre (0, 0, 0) has no unique geodetic latitude,
 * longitude, or ellipsoidal height and therefore returns false.
 *
 * On the rotation axis (X == 0 && Y == 0, Z != 0), longitude is
 * indeterminate. This implementation returns longitude 0 by convention,
 * latitude +/- pi/2, and height |Z| - b.
 *
 * The input X/Y/Z and ellipsoid axes must use the same linear unit. The
 * returned ellipsoidal height uses that same unit.
 */
bool tryGeocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeodeticCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!ellipsoid.isValid)
        return false;

    const T zero = cast(T) 0;
    const T one = cast(T) 1;

    const T x = source.x;
    const T y = source.y;
    const T z = source.z;

    const T a = ellipsoid.semiMajorAxis;
    const T b = ellipsoid.semiMinorAxis;
    const T e2 = ellipsoid.firstEccentricitySquared;
    const T oneMinusE2 = one - e2;

    const T p = hypot2(x, y);
    if (!isFiniteGeodesyScalar(p))
        return false;

    // The ellipsoid centre has no unique inverse geodetic coordinate.
    if (p == zero && z == zero)
        return false;

    Latitude!T latitude;
    Longitude!T longitude;

    // Rotation axis: longitude is arbitrary. Choose zero deterministically.
    if (p == zero)
    {
        const T phi = atan2(z, p); // exactly +/-pi/2 for finite non-zero z
        const T height = fabs(z) - b;

        if (!Latitude!T.tryFromRadians(phi, latitude))
            return false;
        if (!Longitude!T.tryFromRadians(zero, longitude))
            return false;

        return GeodeticCoordinate!T.tryFromComponents(
            latitude, longitude, height, result);
    }

    const T lambda = atan2(y, x);
    if (!Longitude!T.tryFromRadians(lambda, longitude))
        return false;

    /*
     * EPSG/IOGP direct reverse seed (Bowring):
     *
     *   q   = atan2(Z*a, p*b)
     *   phi = atan2(Z + e'²*b*sin³q,
     *               p - e²*a*cos³q)
     *
     * q is evaluated as atan2(Z/b, p/a), which has the same ratio but avoids
     * the unnecessary products Z*a and p*b.
     */
    const T secondEccentricitySquared = e2 / oneMinusE2;
    const T q = atan2(z / b, p / a);
    const T sinQ = sin(q);
    const T cosQ = cos(q);

    T phi = atan2(
        z + secondEccentricitySquared * b * sinQ * sinQ * sinQ,
        p - e2 * a * cosQ * cosQ * cosQ);

    if (!isFiniteGeodesyScalar(phi))
        return false;

    /*
     * Refine the EPSG iterative relation. Eight iterations are bounded,
     * allocation-free, and more than sufficient for normal terrestrial
     * ellipsoids when seeded by the direct Bowring expression.
     *
     * Exact stabilization may terminate early without defining an approximate
     * floating-point equality policy.
     */
    foreach (_; 0 .. 8)
    {
        const T sinPhi = sin(phi);
        const T nu = a / sqrt(one - e2 * sinPhi * sinPhi);
        const T nextPhi = atan2(z + e2 * nu * sinPhi, p);

        if (!isFiniteGeodesyScalar(nextPhi))
            return false;

        if (nextPhi == phi)
            break;

        phi = nextPhi;
    }

    if (!Latitude!T.tryFromRadians(phi, latitude))
        return false;

    const T sinPhi = sin(phi);
    const T cosPhi = cos(phi);
    const T nu = a / sqrt(one - e2 * sinPhi * sinPhi);

    /*
     * EPSG gives h = p/cos(phi) - nu.
     * Near a pole cos(phi) approaches zero; the algebraically equivalent
     * Z equation is better conditioned there:
     *
     *   h = Z/sin(phi) - (1-e²)*nu
     */
    T height;
    if (fabs(cosPhi) >= fabs(sinPhi))
        height = p / cosPhi - nu;
    else
        height = z / sinPhi - oneMinusE2 * nu;

    if (!isFiniteGeodesyScalar(height))
        return false;

    return GeodeticCoordinate!T.tryFromComponents(
        latitude, longitude, height, result);
}


/** Throwing convenience wrapper for `tryGeocentricToGeodetic`. */
GeodeticCoordinate!T geocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeodeticCoordinate!T result;
    if (!tryGeocentricToGeodetic(source, ellipsoid, result))
        throw new GeodesyValueException(
            "Geocentric to geodetic conversion requires a valid ellipsoid and a defined finite representable result.");
    return result;
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    import geodesy.ellipsoid : wgs84;

    bool near(const double actual, const double expected, const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // EPSG Guidance Note 7-2 / method 9602 worked WGS 84 example.
    const latitude = Latitude!double.fromDegrees(
        53.0 + 48.0 / 60.0 + 33.82 / 3600.0);
    const longitude = Longitude!double.fromDegrees(
        2.0 + 7.0 / 60.0 + 46.38 / 3600.0);
    const source = GeodeticCoordinate!double.fromComponents(
        latitude, longitude, 73.0);

    const xyz = geodeticToGeocentric(source, wgs84!double());
    assert(near(xyz.x, 3_771_793.968, 0.001));
    assert(near(xyz.y,   140_253.342, 0.001));
    assert(near(xyz.z, 5_124_304.349, 0.001));

    // Reverse the rounded EPSG example coordinates.
    const epsgXyz = GeocentricCoordinate!double.fromComponents(
        3_771_793.968,
          140_253.342,
        5_124_304.349);
    const epsgGeo = geocentricToGeodetic(epsgXyz, wgs84!double());

    assert(near(
        epsgGeo.latitude.degrees,
        53.0 + 48.0 / 60.0 + 33.82 / 3600.0,
        1e-8));
    assert(near(
        epsgGeo.longitude.degrees,
        2.0 + 7.0 / 60.0 + 46.38 / 3600.0,
        1e-8));
    // EPSG Cartesian input is rounded to millimetres.
    assert(near(epsgGeo.ellipsoidalHeight, 73.0, 0.001));

    // Equator, prime meridian, positive height.
    const equatorXyz = GeocentricCoordinate!double.fromComponents(
        wgs84!double().semiMajorAxis + 250.0,
        0.0,
        0.0);
    const equatorGeo = geocentricToGeodetic(equatorXyz, wgs84!double());
    assert(equatorGeo.latitude.radians == 0.0);
    assert(equatorGeo.longitude.radians == 0.0);
    assert(near(equatorGeo.ellipsoidalHeight, 250.0, 1e-9));

    // Rotation axis: longitude is indeterminate and standardized here to zero.
    const northAxis = GeocentricCoordinate!double.fromComponents(
        0.0,
        0.0,
        wgs84!double().semiMinorAxis + 100.0);
    const northGeo = geocentricToGeodetic(northAxis, wgs84!double());
    assert(near(northGeo.latitude.degrees, 90.0, 1e-12));
    assert(northGeo.longitude.radians == 0.0);
    assert(near(northGeo.ellipsoidalHeight, 100.0, 1e-9));

    const southAxis = GeocentricCoordinate!double.fromComponents(
        0.0,
        0.0,
        -(wgs84!double().semiMinorAxis + 100.0));
    const southGeo = geocentricToGeodetic(southAxis, wgs84!double());
    assert(near(southGeo.latitude.degrees, -90.0, 1e-12));
    assert(southGeo.longitude.radians == 0.0);
    assert(near(southGeo.ellipsoidalHeight, 100.0, 1e-9));

    // A default-initialized ellipsoid is deliberately invalid and must be
    // rejected before any conversion mathematics is attempted.
    const invalidEllipsoid = Ellipsoid!double.init;

    GeocentricCoordinate!double invalidForward;
    assert(!tryGeodeticToGeocentric(
        source, invalidEllipsoid, invalidForward));
    assertThrown!GeodesyValueException(
        geodeticToGeocentric(source, invalidEllipsoid));

    GeodeticCoordinate!double invalidReverse;
    assert(!tryGeocentricToGeodetic(
        epsgXyz, invalidEllipsoid, invalidReverse));
    assertThrown!GeodesyValueException(
        geocentricToGeodetic(epsgXyz, invalidEllipsoid));

    // The exact ellipsoid centre is not uniquely invertible.
    const centre = GeocentricCoordinate!double.init;
    GeodeticCoordinate!double centreResult;
    assert(!tryGeocentricToGeodetic(
        centre, wgs84!double(), centreResult));
    assertThrown!GeodesyValueException(
        geocentricToGeodetic(centre, wgs84!double()));

    // High-altitude round trip exercises the iterative refinement beyond the
    // accuracy of the direct Bowring seed alone.
    const high = GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(44.987654321),
        Longitude!double.fromDegrees(35.432198765),
        1_000_000.0);
    const highXyz = geodeticToGeocentric(high, wgs84!double());
    const highBack = geocentricToGeodetic(highXyz, wgs84!double());

    assert(near(
        highBack.latitude.radians,
        high.latitude.radians,
        1e-13));
    assert(near(
        highBack.longitude.radians,
        high.longitude.radians,
        1e-13));
    assert(near(
        highBack.ellipsoidalHeight,
        high.ellipsoidalHeight,
        1e-6));

    // Generic instantiation for reduced-precision float and platform real.
    const floatSphere = Ellipsoid!float.sphere(1.0f);
    const floatGeo = geocentricToGeodetic(
        GeocentricCoordinate!float.fromComponents(2.0f, 0.0f, 0.0f),
        floatSphere);
    assert(floatGeo.latitude.radians == 0.0f);
    assert(floatGeo.longitude.radians == 0.0f);
    assert(floatGeo.ellipsoidalHeight == 1.0f);

    const realSphere = Ellipsoid!real.sphere(1.0L);
    const realGeo = geocentricToGeodetic(
        GeocentricCoordinate!real.fromComponents(2.0L, 0.0L, 0.0L),
        realSphere);
    assert(realGeo.latitude.radians == 0.0L);
    assert(realGeo.longitude.radians == 0.0L);
    assert(realGeo.ellipsoidalHeight == 1.0L);

    // Finite geodetic inputs can still overflow during the forward direction.
    const huge = GeodeticCoordinate!double.fromComponents(
        Latitude!double.init,
        Longitude!double.init,
        double.max);
    const hugeSphere = Ellipsoid!double.sphere(double.max);
    GeocentricCoordinate!double candidate;
    assert(!tryGeodeticToGeocentric(huge, hugeSphere, candidate));
    assertThrown!GeodesyValueException(
        geodeticToGeocentric(huge, hugeSphere));
}
