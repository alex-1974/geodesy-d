/**
 * Convert geographic positions to UTM coordinates measured in metres.
 *
 * UTM divides most of the world into numbered zones with local eastings and
 * northings. Use automatic UTM conversion when you want the standard zone
 * for a position. Use a prepared `UtmProjection` when you already know the
 * zone and need to convert many positions consistently within it.
 *
 * The module chooses zones and labels coordinates; Transverse Mercator
 * performs the underlying projection.
 *
 * Standards:
 *     UTM semantics follow the conventional EPSG/IOGP Transverse Mercator
 *     operation model and the documented UTM zone/hemisphere policy.
 *
 * Domain:
 *     Zones are 1 through 60. Automatic standard-zone forward projection uses
 *     the documented UTM latitude band; explicit prepared-zone operations do
 *     not silently reapply automatic zone selection.
 *
 * Units:
 *     UTM easting, northing, false offsets, and supported ellipsoid axes are
 *     metre-valued by public policy.
 *
 * Numerics:
 *     Coordinate and factor mathematics delegate to the validated prepared
 *     `TransverseMercator` implementation; this module adds UTM policy rather
 *     than a second projection algorithm.
 *
 * Performance:
 *     `UtmProjection` reuses prepared Transverse Mercator state across
 *     repeated operations. Checked numerical paths are allocation-free.
 *
 * Validation:
 *     Policy, parameterization, boundaries, runtime API, PROJ differential
 *     behaviour, and GeographicLib oracle cases are covered by dedicated
 *     deterministic validators.
 *
 * See_Also:
 *     `UtmZone`, `UtmCoordinate`, `UtmProjection`,
 *     `TransverseMercator`
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 *
 * Date:
 *     September 26, 2026
 */
module geodesy.projection.utm;

import std.math : PI;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.factors : ConformalProjectionFactors;
import geodesy.projection.transverse_mercator : TransverseMercator;
import geodesy.scalar : isGeodesyScalar;


/** North/south UTM false-northing convention. */
enum UtmHemisphere : ubyte
{
    north,
    south,
}

/// Example selecting the UTM false-northing convention.
unittest
{
    import geodesy;
    enum hemisphere = UtmHemisphere.north;
    assert(hemisphere != UtmHemisphere.south);
}


/** Return whether a hemisphere value is one of the two public UTM conventions. */
private bool isValidHemisphere(const UtmHemisphere hemisphere)
    pure nothrow @safe @nogc
{
    return hemisphere == UtmHemisphere.north
        || hemisphere == UtmHemisphere.south;
}


/** Return whether a scalar is neither NaN nor infinity. */
private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
}


/**
 * Convert an integral UTM policy boundary from degrees to radians.
 *
 * Uses the same operation ordering as `Latitude/Longitude.fromDegrees`:
 *
 *     (degrees / 180) * PI
 *
 * Matching operation order keeps exact policy boundaries consistent with
 * public values constructed from the same integral degree.
 */
private T integralDegreesToRadians(T)(const int degrees)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return (cast(T) degrees / cast(T) 180) * cast(T) PI;
}


/**
 * Strong UTM zone number.
 *
 * Valid zones are exactly 1 through 60; `.init` is intentionally invalid.
 * The zone central meridian is available in integral degrees.
 *
 */
struct UtmZone
{
private:
    ubyte _number = 0;

    /** Construct a UTM zone from a number already validated to lie in [1,60]. */
static UtmZone fromNumberUnchecked(const uint number)
        pure nothrow @safe @nogc
    {
        UtmZone result;
        result._number = cast(ubyte) number;
        return result;
    }

public:
    /** True when this value represents one of the 60 UTM zones. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _number >= 1 && _number <= 60;
    }

    /// Example checking a UTM zone.
    @safe unittest
    {
        import geodesy;
        assert(UtmZone.fromNumber(33).isValid);
        assert(!UtmZone.init.isValid);
    }

        /**
     * Read a UTM zone number from input data without throwing.
     *
     * Standard UTM zones are numbered 1 through 60. Use this checked
     * factory when a supplied number may fall outside that range.
     *
     * Params:
     *     number = Zone number in the closed interval [1,60].
     *     result = Receives the zone on success.
     *
     * Returns:
     *     `true` for a valid zone number; otherwise `false`. On failure
     *     `result` remains `.init` on failure.
     */
    static bool tryFromNumber(
        const uint number,
        out UtmZone result)
        pure nothrow @safe @nogc
    {
        if (number < 1 || number > 60)
            return false;

        result = fromNumberUnchecked(number);
        return true;
    }

    /// Example checking a UTM zone number without throwing.
    @safe unittest
    {
        import geodesy;
        UtmZone zone;
        assert(UtmZone.tryFromNumber(33, zone));
        assert(zone.number == 33);
    }

        /**
     * Make a UTM zone from its number (1 through 60).
     *
     * Use this when the zone is known and an invalid number should raise
     * an exception. Use `tryFromNumber` to check uncertain input.
     *
     * Params:
     *     number = Zone number in the closed interval [1,60].
     *
     * Returns:
     *     The constructed zone.
     *
     * Throws:
     *     `GeodesyValueException` outside [1,60].
     */
    static UtmZone fromNumber(const uint number)
        @safe
    {
        UtmZone result;
        if (!tryFromNumber(number, result))
            throw new GeodesyValueException(
                "UTM zone number must be within [1, 60].");

        return result;
    }

    /// Example constructing UTM zone 33.
    @safe unittest
    {
        import geodesy;
        const zone = UtmZone.fromNumber(33);
        assert(zone.number == 33);
    }

    /** Zone number in the closed interval [1, 60] for a valid value. */
    @property uint number() const
        pure nothrow @safe @nogc
    {
        return _number;
    }

    /// Example reading a UTM zone number.
    @safe unittest
    {
        import geodesy;
        assert(UtmZone.fromNumber(33).number == 33);
    }

    /**
     * Central meridian in integral degrees.
     *
     * For a valid zone:
     *
     *     lambda0 = 6 * zone - 183 degrees
     */
    @property int centralMeridianDegrees() const
        pure nothrow @safe @nogc
    {
        return 6 * cast(int) _number - 183;
    }

    /// Example reading the zone central meridian.
    @safe unittest
    {
        import geodesy;
        assert(UtmZone.fromNumber(33).centralMeridianDegrees == 15);
    }
}

/// Example using struct UtmZone.
@safe unittest
{
    import geodesy;
    
    const zone33 = UtmZone.fromNumber(33);
    assert(zone33.isValid);
    assert(zone33.centralMeridianDegrees == 15);
    
    UtmZone checked;
    assert(!UtmZone.tryFromNumber(61, checked));
}



/**
 * Projected UTM coordinate carrying zone and north/south false-northing
 * convention for unambiguous reverse projection.
 *
 * Easting and northing are always metres. The value carries no datum, CRS
 * identifier, EPSG code, MGRS latitude band, height, or axis metadata.
 * `.init` is invalid because its zone is invalid.
 *
 */
struct UtmCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    UtmZone _zone;
    UtmHemisphere _hemisphere = UtmHemisphere.north;
    ProjectedCoordinate!T _projected;

public:
    /** True when the coordinate is structurally valid. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return _zone.isValid
            && isValidHemisphere(_hemisphere)
            && isFiniteScalar(_projected.easting)
            && isFiniteScalar(_projected.northing);
    }

    /// Example checking a tagged UTM coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north, 500_000.0, 5_340_000.0);
        assert(coordinate.isValid);
    }

        /**
     * Construct a tagged UTM coordinate without throwing.
     *
     * Params:
     *     zone = Valid UTM zone.
     *     hemisphere = North/south false-northing convention.
     *     easting = Finite easting in metres.
     *     northing = Finite northing in metres.
     *     result = Receives the tagged coordinate on success.
     *
     * Returns:
     *     `true` for structurally valid input; otherwise `false`. On
     *     failure `result` remains `.init`.
     */
    static bool tryFromComponents(
        const UtmZone zone,
        const UtmHemisphere hemisphere,
        const T easting,
        const T northing,
        out UtmCoordinate result)
        pure nothrow @safe @nogc
    {
        if (!zone.isValid || !isValidHemisphere(hemisphere))
            return false;

        ProjectedCoordinate!T projected;
        if (!ProjectedCoordinate!T.tryFromComponents(
                easting,
                northing,
                projected))
            return false;

        result._zone = zone;
        result._hemisphere = hemisphere;
        result._projected = projected;
        return true;
    }

    /// Example checking a tagged UTM coordinate without throwing.
    @safe unittest
    {
        import geodesy;
        UtmCoordinate!double coordinate;
        assert(UtmCoordinate!double.tryFromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0, coordinate));
        assert(coordinate.isValid);
    }

        /**
     * Construct a tagged UTM coordinate.
     *
     * Params:
     *     zone = Valid UTM zone.
     *     hemisphere = North/south false-northing convention.
     *     easting = Finite easting in metres.
     *     northing = Finite northing in metres.
     *
     * Returns:
     *     The tagged UTM coordinate.
     *
     * Throws:
     *     `GeodesyValueException` for an invalid zone or hemisphere, or
     *     non-finite easting/northing.
     */
    static UtmCoordinate fromComponents(
        const UtmZone zone,
        const UtmHemisphere hemisphere,
        const T easting,
        const T northing)
        @safe
    {
        UtmCoordinate result;
        if (!tryFromComponents(
                zone,
                hemisphere,
                easting,
                northing,
                result))
        {
            throw new GeodesyValueException(
                "UTM coordinate requires a valid zone, hemisphere, "
                ~ "and finite easting/northing.");
        }

        return result;
    }

    /// Example constructing a tagged UTM coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.easting == 500_000.0);
    }

    /** UTM zone. */
    @property UtmZone zone() const
        pure nothrow @safe @nogc
    {
        return _zone;
    }

    /// Example reading the zone.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.zone.number == 33);
    }

    /** North/south false-northing convention. */
    @property UtmHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /// Example reading the hemisphere.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.hemisphere == UtmHemisphere.north);
    }

    /** Untagged projected coordinate in metres. */
    @property ProjectedCoordinate!T projected() const
        pure nothrow @safe @nogc
    {
        return _projected;
    }

    /// Example reading the projected coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.projected.easting == 500_000.0);
    }

    /** Easting in metres. */
    @property T easting() const
        pure nothrow @safe @nogc
    {
        return _projected.easting;
    }

    /// Example reading the easting.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.easting == 500_000.0);
    }

    /** Northing in metres. */
    @property T northing() const
        pure nothrow @safe @nogc
    {
        return _projected.northing;
    }

    /// Example reading the northing.
    @safe unittest
    {
        import geodesy;
        const coordinate = UtmCoordinate!double.fromComponents(
            UtmZone.fromNumber(33), UtmHemisphere.north,
            500_000.0, 5_340_000.0);
        assert(coordinate.northing == 5_340_000.0);
    }
}

/// Example using struct UtmCoordinate(T) if (isGeodesyScalar!T).
@safe unittest
{
    import geodesy;
    
    const coordinate = UtmCoordinate!double.fromComponents(
        UtmZone.fromNumber(33),
        UtmHemisphere.north,
        500_000.0,
        5_340_000.0);
    
    assert(coordinate.isValid);
    assert(coordinate.zone.number == 33);
    assert(coordinate.easting == 500_000.0);
}



/*
 * Return the ordinary six-degree UTM zone for a longitude already normalized
 * to [-pi, +pi).
 *
 * Binary search avoids both:
 *
 * - a 59-comparison linear scan;
 * - converting stored radians back to decimal degrees and then depending on
 *   a potentially rounded division/floor operation at exact zone boundaries.
 */
/**
 * Return the ordinary six-degree UTM zone for a canonical longitude.
 *
 * Binary search uses exact integral-degree boundaries and deliberately avoids
 * converting radians back to decimal degrees.
 */
private UtmZone ordinaryUtmZone(T)(const T longitudeRadians)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    uint low = 1;
    uint high = 60;

    while (low < high)
    {
        const uint mid = low + (high - low) / 2;

        /*
         * Boundary between zone mid and mid + 1:
         *
         * zone 1/2  -> -174 degrees
         * zone 30/31 -> 0 degrees
         * zone 59/60 -> 174 degrees
         */
        const int boundaryDegrees =
            -180 + 6 * cast(int) mid;

        const T boundary =
            integralDegreesToRadians!T(boundaryDegrees);

        if (longitudeRadians < boundary)
            high = mid;
        else
            low = mid + 1;
    }

    return UtmZone.fromNumberUnchecked(low);
}


/**
 * Select the standard UTM zone and hemisphere for a geographic coordinate.
 *
 * The automatic latitude domain is -80 degrees inclusive to +84 degrees
 * exclusive. Longitude is canonicalized to the principal half-open interval
 * before zone selection. Norway and Svalbard exceptions are applied.
 * Latitude zero uses the northern false-northing convention.
 *
 * Params:
 *     source = Geographic coordinate used for automatic policy selection.
 *     zone = Receives the selected UTM zone.
 *     hemisphere = Receives the north/south false-northing convention.
 *
 * Returns:
 *     `true` inside the standard automatic UTM latitude domain; `false`
 *     outside it.
 *
 */
bool tryStandardUtmZone(T)(
    const GeographicCoordinate!T source,
    out UtmZone zone,
    out UtmHemisphere hemisphere)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T latitude = source.latitude.radians;

    const T southLimit = integralDegreesToRadians!T(-80);
    const T northLimit = integralDegreesToRadians!T(84);

    if (latitude < southLimit || latitude >= northLimit)
        return false;

    const T longitude = source.longitude.normalized.radians;

    UtmZone selected = ordinaryUtmZone!T(longitude);

    /*
     * Norway:
     *
     * 56 <= latitude < 64
     *  3 <= longitude < 12
     *      -> zone 32
     */
    const T lat56 = integralDegreesToRadians!T(56);
    const T lat64 = integralDegreesToRadians!T(64);
    const T lon3 = integralDegreesToRadians!T(3);
    const T lon12 = integralDegreesToRadians!T(12);

    if (latitude >= lat56
        && latitude < lat64
        && longitude >= lon3
        && longitude < lon12)
    {
        selected = UtmZone.fromNumberUnchecked(32);
    }
    else
    {
        /*
         * Svalbard:
         *
         * 72 <= latitude < 84
         *
         *  0 <= lon <  9 -> 31
         *  9 <= lon < 21 -> 33
         * 21 <= lon < 33 -> 35
         * 33 <= lon < 42 -> 37
         */
        const T lat72 = integralDegreesToRadians!T(72);

        if (latitude >= lat72)
        {
            const T lon0 = cast(T) 0;
            const T lon9 = integralDegreesToRadians!T(9);
            const T lon21 = integralDegreesToRadians!T(21);
            const T lon33 = integralDegreesToRadians!T(33);
            const T lon42 = integralDegreesToRadians!T(42);

            if (longitude >= lon0 && longitude < lon9)
                selected = UtmZone.fromNumberUnchecked(31);
            else if (longitude >= lon9 && longitude < lon21)
                selected = UtmZone.fromNumberUnchecked(33);
            else if (longitude >= lon21 && longitude < lon33)
                selected = UtmZone.fromNumberUnchecked(35);
            else if (longitude >= lon33 && longitude < lon42)
                selected = UtmZone.fromNumberUnchecked(37);
        }
    }

    zone = selected;
    hemisphere = latitude < cast(T) 0
        ? UtmHemisphere.south
        : UtmHemisphere.north;

    return true;
}

/// Example using bool tryStandardUtmZone(T)( const GeographicCoordinate!T source, out UtmZone zone, out UtmHemisphere hemisph.
@safe unittest
{
    import geodesy;
    
    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    
    UtmZone zone;
    UtmHemisphere hemisphere;
    assert(tryStandardUtmZone(vienna, zone, hemisphere));
    assert(zone.number == 33);
    assert(hemisphere == UtmHemisphere.north);
}




/** Return the fixed UTM central scale factor 0.9996 in scalar type T. */
private T utmScaleFactor(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    /*
     * Start from a real literal so `real` is not deliberately narrowed
     * through binary64 before conversion to the requested public scalar.
     */
    return cast(T) 0.9996L;
}


/** Return the fixed UTM false easting of 500000 metres in scalar type T. */
private T utmFalseEasting(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) 500_000;
}


/** Return the UTM false northing for the requested hemisphere in scalar type T. */
private T utmFalseNorthing(T)(
    const UtmHemisphere hemisphere)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return hemisphere == UtmHemisphere.south
        ? cast(T) 10_000_000
        : cast(T) 0;
}


/**
 * Return whether an ellipsoid satisfies the metre-valued terrestrial profile
 * required by the public UTM policy layer.
 */
private bool isSupportedUtmEllipsoid(T)(
    const Ellipsoid!T ellipsoid)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return ellipsoid.isValid
        && ellipsoid.semiMajorAxis >= cast(T) 6_000_000
        && ellipsoid.semiMajorAxis <= cast(T) 7_000_000
        && ellipsoid.flattening > cast(T) 0
        && ellipsoid.flattening <= cast(T) 0.01L;
}


/**
 * Prepared Universal Transverse Mercator projection for one explicit zone and
 * north/south false-northing convention.
 *
 * Mathematics is delegated to `TransverseMercator!T`; this wrapper adds the
 * fixed UTM parameters, zone/hemisphere state, and terrestrial-metre
 * ellipsoid policy. Accepted ellipsoids have numerically metre-valued
 * semi-major axes in [6,000,000,7,000,000] and `0 < f <= 0.01`.
 *
 * Explicit-zone use does not reapply the automatic -80/+84 latitude band and
 * does not recompute zone or hemisphere from each source point. Reuse this
 * prepared type for bulk work in a known zone.
 *
 */
struct UtmProjection(T)
if (isGeodesyScalar!T)
{
private:
    Ellipsoid!T _ellipsoid;
    UtmZone _zone;
    UtmHemisphere _hemisphere = UtmHemisphere.north;
    TransverseMercator!T _transverseMercator;


    /*
     * Test whether a represented projected coordinate is exactly the public
     * representation of a particular legal UTM latitude at the longitude
     * recovered by generic Transverse Mercator reverse.
     *
     * This deliberately uses equality in ProjectedCoordinate<T>, not an
     * angular or metric epsilon. If an illegal mathematical boundary point
     * and a legal adjacent point collapse to the same public E/N pair, they
     * are numerically indistinguishable at scalar T and the legal UTM
     * representative wins.
     */
public:
    /** True when this value represents a supported prepared UTM projection. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return isSupportedUtmEllipsoid(_ellipsoid)
            && _zone.isValid
            && isValidHemisphere(_hemisphere)
            && _transverseMercator.isValid;
    }

    /// Example checking a prepared UTM projection.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.isValid);
    }

        /**
     * Prepare an explicit UTM zone without throwing.
     *
     * The ellipsoid is interpreted in metres and must satisfy
     * 6,000,000 <= a <= 7,000,000 and 0 < f <= 0.01. Spheres are therefore
     * intentionally excluded from UTM policy.
     *
     * Params:
     *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
     *     zone = Valid explicit UTM zone.
     *     hemisphere = North/south false-northing convention.
     *     result = Receives the prepared projection on success.
     *
     * Returns:
     *     `true` when policy parameters and delegated TM preparation
     *     succeed; otherwise `false`. On failure `result` remains `.init`.
     */
    static bool tryFromZone(
        const Ellipsoid!T ellipsoid,
        const UtmZone zone,
        const UtmHemisphere hemisphere,
        out UtmProjection result)
        pure nothrow @safe @nogc
    {
        if (!isSupportedUtmEllipsoid(ellipsoid)
            || !zone.isValid
            || !isValidHemisphere(hemisphere))
            return false;

        Latitude!T latitudeOfNaturalOrigin;
        Longitude!T longitudeOfNaturalOrigin;

        if (!Latitude!T.tryFromDegrees(
                cast(T) 0,
                latitudeOfNaturalOrigin)
            || !Longitude!T.tryFromDegrees(
                cast(T) zone.centralMeridianDegrees,
                longitudeOfNaturalOrigin))
            return false;

        TransverseMercator!T transverseMercator;

        if (!TransverseMercator!T.tryFromParameters(
                ellipsoid,
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                utmScaleFactor!T(),
                utmFalseEasting!T(),
                utmFalseNorthing!T(hemisphere),
                transverseMercator))
            return false;

        UtmProjection candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._zone = zone;
        candidate._hemisphere = hemisphere;
        candidate._transverseMercator = transverseMercator;

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }

    /// Example preparing UTM without throwing.
    @safe unittest
    {
        import geodesy;
        UtmProjection!double projection;
        assert(UtmProjection!double.tryFromZone(
            wgs84!double(), UtmZone.fromNumber(33),
            UtmHemisphere.north, projection));
        assert(projection.isValid);
    }

        /**
     * Prepare an explicit UTM zone.
     *
     * Params:
     *     ellipsoid = Supported terrestrial oblate ellipsoid in metres with
     *         6,000,000 <= a <= 7,000,000 and 0 < f <= 0.01.
     *     zone = Valid explicit UTM zone.
     *     hemisphere = North/south false-northing convention.
     *
     * Returns:
     *     The prepared UTM projection.
     *
     * Throws:
     *     `GeodesyValueException` for unsupported ellipsoid, zone, or
     *     hemisphere parameters.
     */
    static UtmProjection fromZone(
        const Ellipsoid!T ellipsoid,
        const UtmZone zone,
        const UtmHemisphere hemisphere)
        @safe
    {
        UtmProjection result;

        if (!tryFromZone(
                ellipsoid,
                zone,
                hemisphere,
                result))
        {
            throw new GeodesyValueException(
                "UTM requires zone 1..60, a valid hemisphere, and an "
                ~ "oblate terrestrial ellipsoid in metres with "
                ~ "6000000 <= a <= 7000000 and 0 < f <= 0.01.");
        }

        return result;
    }

    /// Example preparing UTM zone 33 north.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.zone.number == 33);
    }

    /** Projection ellipsoid. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /// Example reading the ellipsoid.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.ellipsoid.semiMajorAxis == 6_378_137.0);
    }

    /** Explicit UTM zone. */
    @property UtmZone zone() const
        pure nothrow @safe @nogc
    {
        return _zone;
    }

    /// Example reading the zone.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.zone.number == 33);
    }

    /** Explicit north/south false-northing convention. */
    @property UtmHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /// Example reading the hemisphere.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.hemisphere == UtmHemisphere.north);
    }

    /** Fixed UTM latitude of natural origin: zero degrees. */
    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.latitudeOfNaturalOrigin;
    }

    /// Example reading the latitude of natural origin.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.latitudeOfNaturalOrigin.degrees == 0.0);
    }

    /** Zone central meridian. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.longitudeOfNaturalOrigin;
    }

    /// Example reading the longitude of natural origin.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.longitudeOfNaturalOrigin.degrees == 15.0);
    }

    /** Fixed UTM natural-origin scale factor: 0.9996. */
    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.scaleFactorAtNaturalOrigin;
    }

    /// Example reading the scale factor at natural origin.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.scaleFactorAtNaturalOrigin == 0.9996);
    }

    /** Fixed UTM false easting: 500000 metres. */
    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.falseEasting;
    }

    /// Example reading the false easting.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.falseEasting == 500_000.0);
    }

    /**
     * UTM false northing in metres.
     *
     * North: 0
     * South: 10000000
     */
    @property T falseNorthing() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.falseNorthing;
    }

    /// Example reading the false northing.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        assert(projection.falseNorthing == 0.0);
    }

        /**
     * Project a geographic coordinate in this explicit UTM zone.
     *
     * The automatic -80/+84 degree UTM latitude band is not reapplied and
     * zone/hemisphere are not recomputed. The delegated bounded Transverse
     * Mercator domain remains authoritative.
     *
     * Params:
     *     source = Geographic source coordinate.
     *     result = Receives easting and northing in metres on success.
     *
     * Returns:
     *     `true` when this projection is valid and delegated TM projection
     *     succeeds; otherwise `false`. The `out` result is initialized on entry;
     *     do not use its value if projection fails.
     */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        return _transverseMercator.tryForward(
            source,
            result);
    }

    /// Example projecting in a prepared UTM zone without throwing.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        ProjectedCoordinate!double result;
        assert(projection.tryForward(vienna, result));
        assert(result.easting > 0.0);
    }

        /**
     * Project a geographic coordinate in this explicit UTM zone.
     *
     * Params:
     *     source = Geographic source coordinate.
     *
     * Returns:
     *     Easting and northing in metres.
     *
     * Throws:
     *     `GeodesyValueException` when the prepared projection is invalid or
     *     the source lies outside the delegated bounded TM domain.
     */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(source, result))
        {
            throw new GeodesyValueException(
                "UTM forward projection failed because the prepared "
                ~ "projection is invalid or the source lies outside the "
                ~ "bounded Transverse Mercator domain.");
        }

        return result;
    }

    /// Example projecting in a prepared UTM zone.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const result = projection.forward(vienna);
        assert(result.northing > 0.0);
    }

        /**
     * Evaluate conformal projection factors at a geographic source position.
     *
     * Params:
     *     source = Geographic position interpreted in this explicit UTM zone.
     *     result = Receives meridian convergence and point scale on success.
     *
     * Returns:
     *     `true` when this projection is valid and delegated TM factor
     *     evaluation succeeds; otherwise `false`. On failure `result` is
     *     reset to `ConformalProjectionFactors!T.init`.
     */
    bool tryForwardFactors(
        const GeographicCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        return _transverseMercator.tryForwardFactors(
            source,
            result);
    }

    /// Example computing UTM factors without throwing.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        ConformalProjectionFactors!double factors;
        assert(projection.tryForwardFactors(vienna, factors));
        assert(factors.pointScale > 0.0);
    }

        /**
     * Evaluate conformal projection factors at a geographic source position.
     *
     * Params:
     *     source = Geographic position interpreted in this explicit UTM zone.
     *
     * Returns:
     *     Meridian convergence and point scale.
     *
     * Throws:
     *     `GeodesyValueException` when factor evaluation is unsupported.
     */
    ConformalProjectionFactors!T forwardFactors(
        const GeographicCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryForwardFactors(source, result))
        {
            throw new GeodesyValueException(
                "UTM forward factor evaluation failed because the prepared "
                ~ "projection is invalid or the source lies outside the "
                ~ "bounded Transverse Mercator domain.");
        }

        return result;
    }

    /// Example computing UTM factors.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(projection.forwardFactors(vienna).pointScale > 0.0);
    }

        /**
     * Reverse a coordinate in this explicit UTM zone without throwing.
     *
     * The automatic UTM latitude band, zone selection, and hemisphere
     * selection are not reapplied.
     *
     * Params:
     *     source = Projected easting and northing in metres.
     *     result = Receives the geographic coordinate on success.
     *
     * Returns:
     *     `true` when this projection is valid and delegated bounded TM
     *     reverse succeeds; otherwise `false`. The `out` result is initialized
     *     on entry; do not use its value if reverse projection fails.
     */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        return _transverseMercator.tryReverse(
            source,
            result);
    }

    /// Example reversing a prepared UTM coordinate without throwing.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        GeographicCoordinate!double result;
        assert(projection.tryReverse(projection.forward(vienna), result));
        assert(result.latitude.degrees > 48.0);
    }

        /**
     * Reverse a coordinate in this explicit UTM zone.
     *
     * Params:
     *     source = Projected easting and northing in metres.
     *
     * Returns:
     *     The corresponding geographic coordinate without automatic zone or
     *     hemisphere reassignment.
     *
     * Throws:
     *     `GeodesyValueException` when the prepared projection is invalid or
     *     the coordinate lies outside the delegated bounded TM domain.
     */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(source, result))
        {
            throw new GeodesyValueException(
                "UTM reverse projection failed because the prepared "
                ~ "projection is invalid or the coordinate lies outside "
                ~ "the bounded Transverse Mercator domain.");
        }

        return result;
    }

    /// Example reversing a prepared UTM coordinate.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const result = projection.reverse(projection.forward(vienna));
        assert(result.longitude.degrees > 16.0);
    }

        /**
     * Evaluate conformal factors at a represented projected coordinate.
     *
     * Params:
     *     source = Projected easting and northing in metres.
     *     result = Receives meridian convergence and point scale on success.
     *
     * Returns:
     *     `true` when this projection is valid and delegated reverse-factor
     *     evaluation succeeds; otherwise `false`. On failure `result` is
     *     reset to `ConformalProjectionFactors!T.init`.
     */
    bool tryReverseFactors(
        const ProjectedCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        return _transverseMercator.tryReverseFactors(
            source,
            result);
    }

    /// Example computing UTM reverse factors without throwing.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        const projected = projection.forward(vienna);
        ConformalProjectionFactors!double factors;
        assert(projection.tryReverseFactors(projected, factors));
        assert(factors.pointScale > 0.0);
    }

        /**
     * Evaluate conformal factors at a represented projected coordinate.
     *
     * Params:
     *     source = Projected easting and northing in metres.
     *
     * Returns:
     *     Meridian convergence and point scale.
     *
     * Throws:
     *     `GeodesyValueException` when reverse factor evaluation is unsupported.
     */
    ConformalProjectionFactors!T reverseFactors(
        const ProjectedCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryReverseFactors(source, result))
        {
            throw new GeodesyValueException(
                "UTM reverse factor evaluation failed because the prepared "
                ~ "projection is invalid or the coordinate lies outside the "
                ~ "bounded Transverse Mercator domain.");
        }

        return result;
    }

    /// Example computing UTM reverse factors.
    @safe unittest
    {
        import geodesy;
        const projection = UtmProjection!double.fromZone(
            wgs84!double(), UtmZone.fromNumber(33), UtmHemisphere.north);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        assert(projection.reverseFactors(projection.forward(vienna)).pointScale > 0.0);
    }
}

/// Example using struct UtmProjection(T) if (isGeodesyScalar!T).
@safe unittest
{
    import geodesy;
    
    const projection = UtmProjection!double.fromZone(
        wgs84!double(),
        UtmZone.fromNumber(33),
        UtmHemisphere.north);
    
    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    
    const xy = projection.forward(vienna);
    const back = projection.reverse(xy);
    assert(back.latitude.degrees > 48.0);
}



/**
 * Convert latitude and longitude to UTM easting and northing in metres.
 *
 * The function chooses the standard UTM zone and hemisphere for this position
 * and returns both with the projected coordinates. Use it for individual
 * positions when you do not know the zone in advance. For many positions
 * in one fixed zone, prepare and reuse `UtmProjection!T` instead.
 *
 * Automatic conversion accepts latitudes from -80 degrees inclusive to
 * +84 degrees exclusive and applies the Norway and Svalbard zone exceptions.
 *
 * Params:
 *     source = Geographic source coordinate.
 *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
 *     result = Receives tagged UTM zone, hemisphere, easting, and northing.
 *
 * Returns:
 *     `true` when automatic policy selection and projection succeed.
 *
 */
bool tryForwardUtm(T)(
    const GeographicCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out UtmCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    UtmZone zone;
    UtmHemisphere hemisphere;

    if (!tryStandardUtmZone(
            source,
            zone,
            hemisphere))
        return false;

    UtmProjection!T projection;

    if (!UtmProjection!T.tryFromZone(
            ellipsoid,
            zone,
            hemisphere,
            projection))
        return false;

    ProjectedCoordinate!T projected;

    if (!projection.tryForward(
            source,
            projected))
        return false;

    UtmCoordinate!T candidate;

    if (!UtmCoordinate!T.tryFromComponents(
            zone,
            hemisphere,
            projected.easting,
            projected.northing,
            candidate))
        return false;

    result = candidate;
    return true;
}

/// Example using bool tryForwardUtm(T)( const GeographicCoordinate!T source, const Ellipsoid!T ellipsoid, out UtmCoordinate!T.
@safe unittest
{
    import geodesy;
    
    const vienna = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208));
    
    const utm = vienna.forwardUtm(wgs84!double());
    assert(utm.zone.number == 33);
    assert(utm.hemisphere == UtmHemisphere.north);
    
    const back = utm.reverseUtm(wgs84!double());
    assert(back.latitude.degrees > 48.0);
}



/**
 * Automatic UTM forward projection with throwing failure semantics.
 *
 * Params:
 *     source = Geographic source coordinate in the standard automatic UTM
 *         latitude band (-80 degrees inclusive to +84 degrees exclusive).
 *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
 *
 * Returns:
 *     Tagged UTM zone, hemisphere, easting, and northing.
 *
 * Throws:
 *     `GeodesyValueException` when automatic policy selection or projection
 *     fails.
 */
UtmCoordinate!T forwardUtm(T)(
    const GeographicCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    UtmCoordinate!T result;

    if (!tryForwardUtm(
            source,
            ellipsoid,
            result))
    {
        throw new GeodesyValueException(
            "Automatic UTM forward projection failed because the ellipsoid "
            ~ "or geographic coordinate is outside the supported UTM policy.");
    }

    return result;
}

/// Example projecting with automatic UTM zone selection.
@safe unittest
{
    import geodesy;
    const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
    const utm = forwardUtm(vienna, wgs84!double());
    assert(utm.zone.number == 33);
}


/**
 * Reverse a tagged UTM coordinate using its explicit zone and hemisphere.
 *
 * The result is not automatically reassigned to another zone or hemisphere.
 *
 * Params:
 *     source = Structurally valid tagged UTM coordinate in metres.
 *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
 *     result = Receives the geographic coordinate on success.
 *
 * Returns:
 *     `true` when explicit-zone preparation and delegated reverse TM
 *     projection succeed; otherwise `false`. On failure `result` remains
 *     unchanged.
 */
bool tryReverseUtm(T)(
    const UtmCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeographicCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!source.isValid)
        return false;

    UtmProjection!T projection;

    if (!UtmProjection!T.tryFromZone(
            ellipsoid,
            source.zone,
            source.hemisphere,
            projection))
        return false;

    GeographicCoordinate!T candidate;

    if (!projection.tryReverse(
            source.projected,
            candidate))
        return false;

    result = candidate;
    return true;
}

/// Example reversing a tagged UTM coordinate without throwing.
@safe unittest
{
    import geodesy;
    const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
    const utm = forwardUtm(vienna, wgs84!double());
    GeographicCoordinate!double result;
    assert(tryReverseUtm(utm, wgs84!double(), result));
    assert(result.latitude.degrees > 48.0);
}


/**
 * Reverse a tagged UTM coordinate using its explicit zone and hemisphere.
 *
 * Params:
 *     source = Structurally valid tagged UTM coordinate in metres.
 *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
 *
 * Returns:
 *     The corresponding geographic coordinate without automatic zone or
 *     hemisphere reassignment.
 *
 * Throws:
 *     `GeodesyValueException` when the tagged coordinate, ellipsoid, or
 *     delegated bounded TM reverse operation is invalid.
 */
GeographicCoordinate!T reverseUtm(T)(
    const UtmCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeographicCoordinate!T result;

    if (!tryReverseUtm(
            source,
            ellipsoid,
            result))
    {
        throw new GeodesyValueException(
            "UTM reverse projection failed because the ellipsoid, tagged "
            ~ "coordinate, or bounded TM domain is invalid.");
    }

    return result;
}

/// Example reversing a tagged UTM coordinate.
@safe unittest
{
    import geodesy;
    const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
    const utm = forwardUtm(vienna, wgs84!double());
    const result = reverseUtm(utm, wgs84!double());
    assert(result.longitude.degrees > 16.0);
}

unittest
{
    import std.exception : assertThrown;

    const invalidZone = UtmZone.init;
    assert(!invalidZone.isValid);
    assert(invalidZone.number == 0);

    const zone1 = UtmZone.fromNumber(1);
    const zone31 = UtmZone.fromNumber(31);
    const zone60 = UtmZone.fromNumber(60);

    assert(zone1.centralMeridianDegrees == -177);
    assert(zone31.centralMeridianDegrees == 3);
    assert(zone60.centralMeridianDegrees == 177);

    UtmZone candidate;
    assert(!UtmZone.tryFromNumber(0, candidate));
    assert(!UtmZone.tryFromNumber(61, candidate));

    assertThrown!GeodesyValueException(UtmZone.fromNumber(0));
    assertThrown!GeodesyValueException(UtmZone.fromNumber(61));

    static assert(is(UtmCoordinate!float));
    static assert(is(UtmCoordinate!double));
    static assert(is(UtmCoordinate!real));

    const coordinate = UtmCoordinate!double.fromComponents(
        UtmZone.fromNumber(33),
        UtmHemisphere.north,
        500_000.0,
        5_340_000.0);

    assert(coordinate.isValid);
    assert(coordinate.zone.number == 33);
    assert(coordinate.hemisphere == UtmHemisphere.north);
    assert(coordinate.easting == 500_000.0);
    assert(coordinate.northing == 5_340_000.0);

    assert(!UtmCoordinate!double.init.isValid);

    UtmCoordinate!double invalidCoordinate;

    assert(!UtmCoordinate!double.tryFromComponents(
        UtmZone.init,
        UtmHemisphere.north,
        500_000.0,
        0.0,
        invalidCoordinate));

    assert(!UtmCoordinate!double.tryFromComponents(
        zone31,
        cast(UtmHemisphere) 255,
        500_000.0,
        0.0,
        invalidCoordinate));

    assert(!UtmCoordinate!double.tryFromComponents(
        zone31,
        UtmHemisphere.north,
        double.nan,
        0.0,
        invalidCoordinate));

    assertThrown!GeodesyValueException(
        UtmCoordinate!double.fromComponents(
            UtmZone.init,
            UtmHemisphere.north,
            0.0,
            0.0));
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    import geodesy.ellipsoid : wgs84;

    static assert(is(UtmProjection!float));
    static assert(is(UtmProjection!double));
    static assert(is(UtmProjection!real));

    assert(!UtmProjection!double.init.isValid);

    const ellipsoid = wgs84!double();
    const zone33 = UtmZone.fromNumber(33);

    const north = UtmProjection!double.fromZone(
        ellipsoid,
        zone33,
        UtmHemisphere.north);

    const south = UtmProjection!double.fromZone(
        ellipsoid,
        zone33,
        UtmHemisphere.south);

    assert(north.isValid);
    assert(south.isValid);

    assert(north.zone.number == 33);
    assert(north.hemisphere == UtmHemisphere.north);
    assert(north.latitudeOfNaturalOrigin.degrees == 0.0);
    assert(fabs(north.longitudeOfNaturalOrigin.degrees - 15.0) < 1e-12);
    assert(north.scaleFactorAtNaturalOrigin == 0.9996);
    assert(north.falseEasting == 500_000.0);
    assert(north.falseNorthing == 0.0);
    assert(south.falseNorthing == 10_000_000.0);

    const origin = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(15.0));

    const northOrigin = north.forward(origin);
    const southOrigin = south.forward(origin);

    assert(northOrigin.easting == 500_000.0);
    assert(northOrigin.northing == 0.0);
    assert(southOrigin.easting == 500_000.0);
    assert(southOrigin.northing == 10_000_000.0);

    /*
     * UTM factor evaluation is a policy wrapper around the exactly equivalent
     * prepared Transverse Mercator operation. No separate UTM factor
     * mathematics is permitted.
     */
    const equivalentNorthTm =
        TransverseMercator!double.fromParameters(
            ellipsoid,
            north.latitudeOfNaturalOrigin,
            north.longitudeOfNaturalOrigin,
            north.scaleFactorAtNaturalOrigin,
            north.falseEasting,
            north.falseNorthing);

    ConformalProjectionFactors!double northForwardFactorsChecked;
    assert(north.tryForwardFactors(
        origin,
        northForwardFactorsChecked));

    const northForwardFactors =
        north.forwardFactors(origin);

    const tmForwardFactors =
        equivalentNorthTm.forwardFactors(origin);

    assert(
        northForwardFactorsChecked.meridianConvergence.radians
            == tmForwardFactors.meridianConvergence.radians);
    assert(
        northForwardFactorsChecked.pointScale
            == tmForwardFactors.pointScale);
    assert(
        northForwardFactors.meridianConvergence.radians
            == tmForwardFactors.meridianConvergence.radians);
    assert(
        northForwardFactors.pointScale
            == tmForwardFactors.pointScale);

    ConformalProjectionFactors!double northReverseFactorsChecked;
    assert(north.tryReverseFactors(
        northOrigin,
        northReverseFactorsChecked));

    const northReverseFactors =
        north.reverseFactors(northOrigin);

    const tmReverseFactors =
        equivalentNorthTm.reverseFactors(northOrigin);

    assert(
        northReverseFactorsChecked.meridianConvergence.radians
            == tmReverseFactors.meridianConvergence.radians);
    assert(
        northReverseFactorsChecked.pointScale
            == tmReverseFactors.pointScale);
    assert(
        northReverseFactors.meridianConvergence.radians
            == tmReverseFactors.meridianConvergence.radians);
    assert(
        northReverseFactors.pointScale
            == tmReverseFactors.pointScale);

    /*
     * The same delegation identity must hold at binary32 precision.
     */
    const ellipsoidFloat = wgs84!float();

    const northFloat =
        UtmProjection!float.fromZone(
            ellipsoidFloat,
            zone33,
            UtmHemisphere.north);

    const sourceFloat =
        GeographicCoordinate!float.fromComponents(
            Latitude!float.fromDegrees(48.0f),
            Longitude!float.fromDegrees(16.0f));

    const projectedFloat =
        northFloat.forward(sourceFloat);

    const equivalentFloatTm =
        TransverseMercator!float.fromParameters(
            ellipsoidFloat,
            northFloat.latitudeOfNaturalOrigin,
            northFloat.longitudeOfNaturalOrigin,
            northFloat.scaleFactorAtNaturalOrigin,
            northFloat.falseEasting,
            northFloat.falseNorthing);

    const utmForwardFactorsFloat =
        northFloat.forwardFactors(sourceFloat);

    const tmForwardFactorsFloat =
        equivalentFloatTm.forwardFactors(sourceFloat);

    assert(
        utmForwardFactorsFloat.meridianConvergence.radians
            == tmForwardFactorsFloat.meridianConvergence.radians);
    assert(
        utmForwardFactorsFloat.pointScale
            == tmForwardFactorsFloat.pointScale);

    const utmReverseFactorsFloat =
        northFloat.reverseFactors(projectedFloat);

    const tmReverseFactorsFloat =
        equivalentFloatTm.reverseFactors(projectedFloat);

    assert(
        utmReverseFactorsFloat.meridianConvergence.radians
            == tmReverseFactorsFloat.meridianConvergence.radians);
    assert(
        utmReverseFactorsFloat.pointScale
            == tmReverseFactorsFloat.pointScale);

    /*
     * The standard automatic UTM band ends at 84 degrees, but an explicitly
     * prepared zone remains the corresponding fixed Transverse Mercator
     * projection.
     */
    ProjectedCoordinate!double projected84;

    const explicit84 = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(84.0),
        Longitude!double.fromDegrees(15.0));

    assert(north.tryForward(explicit84, projected84));

    GeographicCoordinate!double reversed84;
    assert(north.tryReverse(projected84, reversed84));

    assert(fabs(
        reversed84.latitude.radians
        - explicit84.latitude.radians) < 1e-12);

    assert(fabs(
        reversed84.longitude.radians
        - explicit84.longitude.radians) < 1e-12);

    UtmProjection!double invalid;

    ConformalProjectionFactors!double invalidForwardFactors;
    assert(!invalid.tryForwardFactors(
        origin,
        invalidForwardFactors));

    ConformalProjectionFactors!double invalidReverseFactors;
    assert(!invalid.tryReverseFactors(
        northOrigin,
        invalidReverseFactors));

    assertThrown!GeodesyValueException(
        invalid.forwardFactors(origin));

    assertThrown!GeodesyValueException(
        invalid.reverseFactors(northOrigin));

    assert(!UtmProjection!double.tryFromZone(
        Ellipsoid!double.sphere(6_378_137.0),
        zone33,
        UtmHemisphere.north,
        invalid));

    assertThrown!GeodesyValueException(
        UtmProjection!double.fromZone(
            Ellipsoid!double.sphere(6_378_137.0),
            zone33,
            UtmHemisphere.north));
}
