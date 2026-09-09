/** Geographic/geocentric coordinate conversions. */
module geodesy.conversion;

import std.math : cos, sin, sqrt;

import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.geodetic : GeodeticCoordinate;
import geodesy.scalar : isGeodesyScalar;

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

/**
 * Throwing convenience wrapper for `tryGeodeticToGeocentric`.
 */
GeocentricCoordinate!T geodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryGeodeticToGeocentric(source, ellipsoid, result))
        throw new GeodesyValueException(
            "Geodetic to geocentric conversion produced a non-finite result.");
    return result;
}

unittest
{
    import std.math : fabs;
    import std.exception : assertThrown;

    import geodesy.angle : Latitude, Longitude;
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

    // Exact/simple axis case: equator, Greenwich meridian, zero height.
    const equator = GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(0.0),
        0.0);
    const equatorXyz = geodeticToGeocentric(equator, wgs84!double());
    assert(equatorXyz.x == wgs84!double().semiMajorAxis);
    assert(equatorXyz.y == 0.0);
    assert(equatorXyz.z == 0.0);

    // Pole case: transverse components collapse to zero within FP rounding;
    // Z equals the semi-minor axis at zero ellipsoidal height.
    const northPole = GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0),
        0.0);
    const poleXyz = geodeticToGeocentric(northPole, wgs84!double());
    assert(fabs(poleXyz.x) < 1e-8);
    assert(fabs(poleXyz.y) < 1e-8);
    assert(near(poleXyz.z, wgs84!double().semiMinorAxis, 1e-8));

    // The generic implementation must instantiate for float and real too.
    const unitFloat = geodeticToGeocentric(
        GeodeticCoordinate!float.init,
        Ellipsoid!float.sphere(1.0f));
    assert(unitFloat.x == 1.0f && unitFloat.y == 0.0f && unitFloat.z == 0.0f);

    const unitReal = geodeticToGeocentric(
        GeodeticCoordinate!real.init,
        Ellipsoid!real.sphere(1.0L));
    assert(unitReal.x == 1.0L && unitReal.y == 0.0L && unitReal.z == 0.0L);

    // Finite inputs can still overflow a finite scalar representation.
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
