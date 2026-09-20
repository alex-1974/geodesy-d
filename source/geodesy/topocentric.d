/** Local topocentric East/North/Up coordinate types and operations. */
module geodesy.topocentric;

import std.math : cos, sin;

import geodesy.conversion :
    Epsg9602WorkingScalar,
    tryEpsg9602ForwardWorking,
    tryEpsg9602ReverseWorking;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.geodetic : GeodeticCoordinate;
import geodesy.scalar :
    isFiniteGeodesyScalar,
    isGeodesyScalar;


/**
 * A local topocentric Cartesian coordinate `(east, north, up)`.
 *
 * The type represents linear components only. It does not carry an origin,
 * ellipsoid, CRS, datum, or linear-unit tag. Interpretation requires a
 * separately prepared topocentric frame.
 *
 * `(0, 0, 0)` is a valid coordinate and is the `.init` value.
 */
struct TopocentricCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    T _east = 0;
    T _north = 0;
    T _up = 0;

    static TopocentricCoordinate fromComponentsUnchecked(
        const T east,
        const T north,
        const T up)
        pure nothrow @safe @nogc
    {
        TopocentricCoordinate result;
        result._east = east;
        result._north = north;
        result._up = up;
        return result;
    }

public:
    /** Construct from finite East/North/Up components without throwing. */
    static bool tryFromComponents(
        const T east,
        const T north,
        const T up,
        out TopocentricCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!isFiniteGeodesyScalar(east)
            || !isFiniteGeodesyScalar(north)
            || !isFiniteGeodesyScalar(up))
            return false;

        result =
            fromComponentsUnchecked(
                east,
                north,
                up);

        return true;
    }

    /**
     * Construct from East/North/Up components.
     *
     * Throws `GeodesyValueException` when any component is non-finite.
     */
    static TopocentricCoordinate fromComponents(
        const T east,
        const T north,
        const T up)
        @safe
    {
        TopocentricCoordinate result;

        if (!tryFromComponents(
            east,
            north,
            up,
            result))
        {
            throw new GeodesyValueException(
                "Topocentric coordinate components must be finite.");
        }

        return result;
    }

    /** East component in the frame linear unit. */
    @property T east() const
        pure nothrow @safe @nogc
    {
        return _east;
    }

    /** North component in the frame linear unit. */
    @property T north() const
        pure nothrow @safe @nogc
    {
        return _north;
    }

    /** Up component in the frame linear unit. */
    @property T up() const
        pure nothrow @safe @nogc
    {
        return _up;
    }
}


/**
 * A prepared local East/North/Up frame.
 *
 * The frame binds an ellipsoid, a geocentric origin, and the orientation
 * derived from the origin's geodetic latitude and longitude.
 *
 * `.init` is deliberately invalid. A frame must be prepared explicitly from
 * either a geodetic or geocentric origin before it can be used.
 *
 * The prepared numerical state uses `Epsg9602WorkingScalar!T`:
 *
 * - `float`  -> `double`
 * - `double` -> `double`
 * - `real`   -> `real`
 *
 * This prevents composed float operations from materializing Earth-scale
 * ECEF intermediates in binary32 before local subtraction.
 */
struct TopocentricFrame(T)
if (isGeodesyScalar!T)
{
private:
    alias W = Epsg9602WorkingScalar!T;

    Ellipsoid!T _ellipsoid;
    bool _valid = false;

    W _originX = 0;
    W _originY = 0;
    W _originZ = 0;

    W _sinLatitude = 0;
    W _cosLatitude = 0;
    W _sinLongitude = 0;
    W _cosLongitude = 0;

    /*
     * Working-precision forward EPSG 9836 rotation.
     *
     * Inputs and outputs remain in W.  In particular, a composed float path
     * may reach this helper with double-precision ECEF values without first
     * materializing GeocentricCoordinate!float.
     */
    bool tryWorkingGeocentricToTopocentric(
        const W x,
        const W y,
        const W z,
        out W east,
        out W north,
        out W up) const
        pure nothrow @safe @nogc
    {
        if (!_valid || !_ellipsoid.isValid)
            return false;

        const W dx =
            x - _originX;

        const W dy =
            y - _originY;

        const W dz =
            z - _originZ;

        east =
            -dx * _sinLongitude
            + dy * _cosLongitude;

        north =
            -dx * _sinLatitude * _cosLongitude
            - dy * _sinLatitude * _sinLongitude
            + dz * _cosLatitude;

        up =
            dx * _cosLatitude * _cosLongitude
            + dy * _cosLatitude * _sinLongitude
            + dz * _sinLatitude;

        return isFiniteGeodesyScalar(east)
            && isFiniteGeodesyScalar(north)
            && isFiniteGeodesyScalar(up);
    }

    /*
     * Working-precision reverse EPSG 9836 rotation.
     *
     * The transpose of the orthonormal forward rotation is applied before
     * restoring the prepared working-precision ECEF origin.
     */
    bool tryWorkingTopocentricToGeocentric(
        const W east,
        const W north,
        const W up,
        out W x,
        out W y,
        out W z) const
        pure nothrow @safe @nogc
    {
        if (!_valid || !_ellipsoid.isValid)
            return false;

        x =
            _originX
            - east * _sinLongitude
            - north * _sinLatitude * _cosLongitude
            + up * _cosLatitude * _cosLongitude;

        y =
            _originY
            + east * _cosLongitude
            - north * _sinLatitude * _sinLongitude
            + up * _cosLatitude * _sinLongitude;

        z =
            _originZ
            + north * _cosLatitude
            + up * _sinLatitude;

        return isFiniteGeodesyScalar(x)
            && isFiniteGeodesyScalar(y)
            && isFiniteGeodesyScalar(z);
    }

public:
    /**
     * True when this frame has been explicitly prepared from a valid origin.
     *
     * In particular, `TopocentricFrame!T.init.isValid` is false.
     */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _valid
            && _ellipsoid.isValid;
    }

    /**
     * Ellipsoid associated with the frame.
     *
     * For an invalid `.init` frame this returns `Ellipsoid!T.init`.
     */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /**
     * Prepare a frame from a geodetic origin without throwing.
     *
     * At either geographic pole, the explicitly supplied longitude defines
     * the East/North orientation and is therefore used directly rather than
     * being reconstructed from ECEF.
     */
    static bool tryFromGeodeticOrigin(
        const Ellipsoid!T ellipsoid,
        const GeodeticCoordinate!T origin,
        out TopocentricFrame result)
        pure nothrow @safe @nogc
    {
        if (!ellipsoid.isValid)
            return false;

        const W latitude =
            cast(W) origin.latitude.radians;

        const W longitude =
            cast(W) origin.longitude.radians;

        W originX;
        W originY;
        W originZ;

        if (!tryEpsg9602ForwardWorking!W(
            latitude,
            longitude,
            cast(W) origin.ellipsoidalHeight,
            cast(W) ellipsoid.semiMajorAxis,
            cast(W) ellipsoid.flattening,
            originX,
            originY,
            originZ))
            return false;

        TopocentricFrame candidate;

        candidate._ellipsoid = ellipsoid;
        candidate._originX = originX;
        candidate._originY = originY;
        candidate._originZ = originZ;

        candidate._sinLatitude = sin(latitude);
        candidate._cosLatitude = cos(latitude);
        candidate._sinLongitude = sin(longitude);
        candidate._cosLongitude = cos(longitude);

        if (!isFiniteGeodesyScalar(candidate._sinLatitude)
            || !isFiniteGeodesyScalar(candidate._cosLatitude)
            || !isFiniteGeodesyScalar(candidate._sinLongitude)
            || !isFiniteGeodesyScalar(candidate._cosLongitude))
            return false;

        candidate._valid = true;
        result = candidate;
        return true;
    }

    /**
     * Prepare a frame from a geodetic origin.
     *
     * Throws `GeodesyValueException` if the ellipsoid is invalid or a finite
     * prepared frame cannot be produced.
     */
    static TopocentricFrame fromGeodeticOrigin(
        const Ellipsoid!T ellipsoid,
        const GeodeticCoordinate!T origin)
        @safe
    {
        TopocentricFrame result;

        if (!tryFromGeodeticOrigin(
            ellipsoid,
            origin,
            result))
        {
            throw new GeodesyValueException(
                "Topocentric frame requires a valid ellipsoid and a finite geodetic origin.");
        }

        return result;
    }

    /**
     * Prepare a frame from a geocentric origin without throwing.
     *
     * The supplied represented X/Y/Z values are retained as the prepared
     * frame origin after promotion to the working scalar. They are not
     * reconstructed from the derived geodetic coordinate.
     *
     * Orientation is obtained through the existing canonical reverse EPSG
     * 9602 semantics. Consequently:
     *
     * - the exact geocentre `(0,0,0)` is rejected;
     * - a non-zero point on the rotation axis is accepted;
     * - rotation-axis longitude is canonically zero;
     * - deep-interior origins inherit the existing EPSG 9602 canonical
     *   nearest-ellipsoid/min-|h| solution.
     */
    static bool tryFromGeocentricOrigin(
        const Ellipsoid!T ellipsoid,
        const GeocentricCoordinate!T origin,
        out TopocentricFrame result)
        pure nothrow @safe @nogc
    {
        if (!ellipsoid.isValid)
            return false;

        const W originX =
            cast(W) origin.x;
        const W originY =
            cast(W) origin.y;
        const W originZ =
            cast(W) origin.z;

        W latitude;
        W longitude;
        W height;

        if (!tryEpsg9602ReverseWorking!W(
            originX,
            originY,
            originZ,
            cast(W) ellipsoid.semiMajorAxis,
            cast(W) ellipsoid.flattening,
            latitude,
            longitude,
            height))
            return false;

        cast(void) height;

        TopocentricFrame candidate;

        candidate._ellipsoid = ellipsoid;

        /*
         * Preserve exactly the represented caller-supplied ECEF origin after
         * promotion. Do not round-trip it through geodetic coordinates.
         */
        candidate._originX = originX;
        candidate._originY = originY;
        candidate._originZ = originZ;

        candidate._sinLatitude = sin(latitude);
        candidate._cosLatitude = cos(latitude);
        candidate._sinLongitude = sin(longitude);
        candidate._cosLongitude = cos(longitude);

        if (!isFiniteGeodesyScalar(candidate._sinLatitude)
            || !isFiniteGeodesyScalar(candidate._cosLatitude)
            || !isFiniteGeodesyScalar(candidate._sinLongitude)
            || !isFiniteGeodesyScalar(candidate._cosLongitude))
            return false;

        candidate._valid = true;
        result = candidate;
        return true;
    }

    /**
     * Prepare a frame from a geocentric origin.
     *
     * Throws `GeodesyValueException` if the ellipsoid is invalid, the origin
     * is the exact geocentre, or a finite prepared frame cannot be produced.
     */
    static TopocentricFrame fromGeocentricOrigin(
        const Ellipsoid!T ellipsoid,
        const GeocentricCoordinate!T origin)
        @safe
    {
        TopocentricFrame result;

        if (!tryFromGeocentricOrigin(
            ellipsoid,
            origin,
            result))
        {
            throw new GeodesyValueException(
                "Topocentric frame requires a valid ellipsoid and a defined finite geocentric origin.");
        }

        return result;
    }

    /**
     * Convert geocentric Cartesian coordinates to local East/North/Up.
     *
     * Implements EPSG coordinate operation method 9836.
     *
     * Subtraction from the Earth-scale frame origin is performed in the
     * frame's prepared working scalar before any narrowing to public scalar T.
     */
    bool tryGeocentricToTopocentric(
        const GeocentricCoordinate!T source,
        out TopocentricCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        W east;
        W north;
        W up;

        if (!tryWorkingGeocentricToTopocentric(
            cast(W) source.x,
            cast(W) source.y,
            cast(W) source.z,
            east,
            north,
            up))
            return false;

        return TopocentricCoordinate!T.tryFromComponents(
            cast(T) east,
            cast(T) north,
            cast(T) up,
            result);
    }

    /**
     * Convert geocentric Cartesian coordinates to local East/North/Up.
     *
     * Throws `GeodesyValueException` when the frame is invalid or no finite
     * public result can be represented.
     */
    TopocentricCoordinate!T geocentricToTopocentric(
        const GeocentricCoordinate!T source) const
        @safe
    {
        TopocentricCoordinate!T result;

        if (!tryGeocentricToTopocentric(
            source,
            result))
        {
            throw new GeodesyValueException(
                "Geocentric to topocentric conversion requires a valid frame and a finite representable result.");
        }

        return result;
    }

    /**
     * Convert local East/North/Up to geocentric Cartesian coordinates.
     *
     * Implements the reverse direction of EPSG method 9836. Because the
     * forward rotation is orthonormal, the reverse uses its transpose and then
     * restores the prepared geocentric origin.
     */
    bool tryTopocentricToGeocentric(
        const TopocentricCoordinate!T source,
        out GeocentricCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        W x;
        W y;
        W z;

        if (!tryWorkingTopocentricToGeocentric(
            cast(W) source.east,
            cast(W) source.north,
            cast(W) source.up,
            x,
            y,
            z))
            return false;

        return GeocentricCoordinate!T.tryFromComponents(
            cast(T) x,
            cast(T) y,
            cast(T) z,
            result);
    }

    /**
     * Convert local East/North/Up to geocentric Cartesian coordinates.
     *
     * Throws `GeodesyValueException` when the frame is invalid or no finite
     * public result can be represented.
     */
    GeocentricCoordinate!T topocentricToGeocentric(
        const TopocentricCoordinate!T source) const
        @safe
    {
        GeocentricCoordinate!T result;

        if (!tryTopocentricToGeocentric(
            source,
            result))
        {
            throw new GeodesyValueException(
                "Topocentric to geocentric conversion requires a valid frame and a finite representable result.");
        }

        return result;
    }
}


unittest
{
    import std.exception : assertThrown;

    static assert(is(TopocentricCoordinate!float));
    static assert(is(TopocentricCoordinate!double));
    static assert(is(TopocentricCoordinate!real));

    const zero =
        TopocentricCoordinate!double.init;

    assert(zero.east == 0.0);
    assert(zero.north == 0.0);
    assert(zero.up == 0.0);

    TopocentricCoordinate!double checked;

    assert(
        TopocentricCoordinate!double.tryFromComponents(
            1.0,
            -2.0,
            3.0,
            checked));

    assert(checked.east == 1.0);
    assert(checked.north == -2.0);
    assert(checked.up == 3.0);

    TopocentricCoordinate!double invalid;

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            double.nan,
            0.0,
            0.0,
            invalid));

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            0.0,
            double.infinity,
            0.0,
            invalid));

    assert(
        !TopocentricCoordinate!double.tryFromComponents(
            0.0,
            0.0,
            -double.infinity,
            invalid));

    assertThrown!GeodesyValueException(
        TopocentricCoordinate!double.fromComponents(
            double.nan,
            0.0,
            0.0));

    assertThrown!GeodesyValueException(
        TopocentricCoordinate!double.fromComponents(
            0.0,
            double.infinity,
            0.0));

    const floatCoordinate =
        TopocentricCoordinate!float.fromComponents(
            1.0f,
            2.0f,
            3.0f);

    assert(floatCoordinate.east == 1.0f);
    assert(floatCoordinate.north == 2.0f);
    assert(floatCoordinate.up == 3.0f);

    const realCoordinate =
        TopocentricCoordinate!real.fromComponents(
            1.0L,
            2.0L,
            3.0L);

    assert(realCoordinate.east == 1.0L);
    assert(realCoordinate.north == 2.0L);
    assert(realCoordinate.up == 3.0L);
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs, sin;

    import geodesy.angle : Latitude, Longitude;
    import geodesy.ellipsoid : wgs84;

    static assert(is(TopocentricFrame!float));
    static assert(is(TopocentricFrame!double));
    static assert(is(TopocentricFrame!real));

    /*
     * Prepared working precision is an implementation requirement needed by
     * composed topocentric float paths.
     */
    static assert(
        is(typeof(TopocentricFrame!float.init._originX) == double));
    static assert(
        is(typeof(TopocentricFrame!double.init._originX) == double));
    static assert(
        is(typeof(TopocentricFrame!real.init._originX) == real));

    const invalid =
        TopocentricFrame!double.init;

    assert(!invalid.isValid);
    assert(!invalid.ellipsoid.isValid);

    const earth =
        wgs84!double();

    const vienna =
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208),
            171.0);

    const frame =
        TopocentricFrame!double.fromGeodeticOrigin(
            earth,
            vienna);

    assert(frame.isValid);
    assert(frame.ellipsoid.semiMajorAxis
        == earth.semiMajorAxis);
    assert(frame.ellipsoid.flattening
        == earth.flattening);

    /*
     * Geodetic pole orientation:
     * retain the supplied longitude directly rather than deriving an
     * indeterminate longitude from ECEF.
     */
    const northPoleLongitude =
        Longitude!double.fromDegrees(90.0);

    const northPole =
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            northPoleLongitude,
            0.0);

    const poleFrame =
        TopocentricFrame!double.fromGeodeticOrigin(
            earth,
            northPole);

    assert(poleFrame.isValid);
    assert(fabs(poleFrame._sinLatitude - 1.0) < 1e-15);
    assert(fabs(poleFrame._cosLatitude) < 1e-15);
    assert(fabs(poleFrame._sinLongitude - 1.0) < 1e-15);
    assert(fabs(poleFrame._cosLongitude) < 1e-15);

    /*
     * +180 degrees is valid in Longitude and is intentionally not passed
     * through Longitude.normalized during geodetic frame preparation.
     */
    const eastAntimeridian =
        Longitude!double.fromDegrees(180.0);

    const antimeridianPole =
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(90.0),
            eastAntimeridian,
            0.0);

    const antimeridianPoleFrame =
        TopocentricFrame!double.fromGeodeticOrigin(
            earth,
            antimeridianPole);

    assert(
        antimeridianPoleFrame._sinLongitude
        == sin(eastAntimeridian.radians));

    /*
     * Geocentric rotation axis inherits the existing EPSG 9602 canonical
     * longitude == 0 convention.
     */
    const northAxis =
        GeocentricCoordinate!double.fromComponents(
            0.0,
            0.0,
            earth.semiMinorAxis + 100.0);

    const northAxisFrame =
        TopocentricFrame!double.fromGeocentricOrigin(
            earth,
            northAxis);

    assert(northAxisFrame.isValid);
    assert(northAxisFrame._sinLongitude == 0.0);
    assert(northAxisFrame._cosLongitude == 1.0);
    assert(fabs(northAxisFrame._sinLatitude - 1.0) < 1e-15);
    assert(fabs(northAxisFrame._cosLatitude) < 1e-15);

    const southAxis =
        GeocentricCoordinate!double.fromComponents(
            0.0,
            0.0,
            -(earth.semiMinorAxis + 100.0));

    const southAxisFrame =
        TopocentricFrame!double.fromGeocentricOrigin(
            earth,
            southAxis);

    assert(southAxisFrame.isValid);
    assert(southAxisFrame._sinLongitude == 0.0);
    assert(southAxisFrame._cosLongitude == 1.0);
    assert(fabs(southAxisFrame._sinLatitude + 1.0) < 1e-15);

    /*
     * Exact centre is rejected because reverse EPSG 9602 has no unique
     * latitude/longitude there.
     */
    TopocentricFrame!double centreFrame;

    assert(
        !TopocentricFrame!double.tryFromGeocentricOrigin(
            earth,
            GeocentricCoordinate!double.init,
            centreFrame));

    assertThrown!GeodesyValueException(
        TopocentricFrame!double.fromGeocentricOrigin(
            earth,
            GeocentricCoordinate!double.init));

    /*
     * Invalid ellipsoid is rejected by both construction paths.
     */
    const invalidEllipsoid =
        Ellipsoid!double.init;

    TopocentricFrame!double invalidFrame;

    assert(
        !TopocentricFrame!double.tryFromGeodeticOrigin(
            invalidEllipsoid,
            vienna,
            invalidFrame));

    assert(
        !TopocentricFrame!double.tryFromGeocentricOrigin(
            invalidEllipsoid,
            northAxis,
            invalidFrame));

    assertThrown!GeodesyValueException(
        TopocentricFrame!double.fromGeodeticOrigin(
            invalidEllipsoid,
            vienna));

    assertThrown!GeodesyValueException(
        TopocentricFrame!double.fromGeocentricOrigin(
            invalidEllipsoid,
            northAxis));

    /*
     * A caller-supplied GeocentricCoordinate<float> has already undergone
     * binary32 ECEF quantization. The prepared state must preserve those
     * represented values exactly after promotion to double.
     */
    const floatOrigin =
        GeocentricCoordinate!float.fromComponents(
            6_378_100.5f,
            123.25f,
            -456.75f);

    const floatFrame =
        TopocentricFrame!float.fromGeocentricOrigin(
            wgs84!float(),
            floatOrigin);

    assert(floatFrame.isValid);
    assert(floatFrame._originX == cast(double) floatOrigin.x);
    assert(floatFrame._originY == cast(double) floatOrigin.y);
    assert(floatFrame._originZ == cast(double) floatOrigin.z);
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    import geodesy.ellipsoid : wgs84;

    bool near(
        const double actual,
        const double expected,
        const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    /*
     * EPSG Guidance Note 7-2 / method 9836 worked WGS 84 example.
     */
    const origin =
        GeocentricCoordinate!double.fromComponents(
            3_652_755.3058,
              319_574.6799,
            5_201_547.3536);

    const frame =
        TopocentricFrame!double.fromGeocentricOrigin(
            wgs84!double(),
            origin);

    const source =
        GeocentricCoordinate!double.fromComponents(
            3_771_793.968,
              140_253.342,
            5_124_304.349);

    const local =
        frame.geocentricToTopocentric(
            source);

    assert(near(
        local.east,
        -189_013.869,
        0.001));

    assert(near(
        local.north,
        -128_642.040,
        0.001));

    assert(near(
        local.up,
        -4_220.171,
        0.001));

    /*
     * Reverse the published ENU values. Both source and local EPSG values are
     * rounded, so the comparison remains at the published millimetre scale.
     */
    const publishedLocal =
        TopocentricCoordinate!double.fromComponents(
            -189_013.869,
            -128_642.040,
              -4_220.171);

    const reversed =
        frame.topocentricToGeocentric(
            publishedLocal);

    assert(near(
        reversed.x,
        3_771_793.968,
        0.001));

    assert(near(
        reversed.y,
        140_253.342,
        0.001));

    assert(near(
        reversed.z,
        5_124_304.349,
        0.001));

    /*
     * The frame origin itself maps exactly to local zero because the
     * represented origin is retained in the prepared working state.
     */
    const zero =
        frame.geocentricToTopocentric(
            origin);

    assert(zero.east == 0.0);
    assert(zero.north == 0.0);
    assert(zero.up == 0.0);

    /*
     * Invalid prepared state must never silently produce plausible output.
     */
    const invalidFrame =
        TopocentricFrame!double.init;

    TopocentricCoordinate!double invalidLocal;

    assert(
        !invalidFrame.tryGeocentricToTopocentric(
            source,
            invalidLocal));

    GeocentricCoordinate!double invalidGeocentric;

    assert(
        !invalidFrame.tryTopocentricToGeocentric(
            publishedLocal,
            invalidGeocentric));

    assertThrown!GeodesyValueException(
        invalidFrame.geocentricToTopocentric(
            source));

    assertThrown!GeodesyValueException(
        invalidFrame.topocentricToGeocentric(
            publishedLocal));

    /*
     * Caller-supplied float ECEF values have already been quantized, but
     * origin subtraction must still occur after promotion to double.
     *
     * Using the exact same represented X/Y/Z value as the frame origin must
     * therefore map exactly to local zero.
     */
    const floatOrigin =
        GeocentricCoordinate!float.fromComponents(
            6_378_100.5f,
            123.25f,
            -456.75f);

    const floatFrame =
        TopocentricFrame!float.fromGeocentricOrigin(
            wgs84!float(),
            floatOrigin);

    const floatZero =
        floatFrame.geocentricToTopocentric(
            floatOrigin);

    assert(floatZero.east == 0.0f);
    assert(floatZero.north == 0.0f);
    assert(floatZero.up == 0.0f);
}
