/**
 * Universal Transverse Mercator policy, coordinate tagging, and projection.
 * 
 * Numerical projection is delegated to the accepted bounded
 * `TransverseMercator!T` implementation. This module owns UTM zone,
 * hemisphere, fixed-parameter, and standard automatic-zone policy.
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


private bool isValidHemisphere(const UtmHemisphere hemisphere)
    pure nothrow @safe @nogc
{
    return hemisphere == UtmHemisphere.north
        || hemisphere == UtmHemisphere.south;
}


private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
}


/*
 * Use the same operation ordering as Latitude/Longitude.fromDegrees:
 *
 *     (degrees / 180) * PI
 *
 * Integer policy boundaries therefore compare consistently with values
 * constructed from the corresponding exact integral degree value.
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
 * Example:
 * ---
 * import geodesy;
 *
 * const zone33 = UtmZone.fromNumber(33);
 * assert(zone33.isValid);
 * assert(zone33.centralMeridianDegrees == 15);
 *
 * UtmZone checked;
 * assert(!UtmZone.tryFromNumber(61, checked));
 * ---
 */
struct UtmZone
{
private:
    ubyte _number = 0;

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

        /**
     * Construct a UTM zone number without throwing.
     *
     * Params:
     *     number = Zone number in the closed interval [1,60].
     *     result = Receives the zone on success.
     *
     * Returns:
     *     `true` for a valid zone number; otherwise `false`. On failure
     *     `result` remains unchanged.
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

        /**
     * Construct a UTM zone number.
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

    /** Zone number in the closed interval [1, 60] for a valid value. */
    @property uint number() const
        pure nothrow @safe @nogc
    {
        return _number;
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
}


/**
 * Projected UTM coordinate carrying zone and north/south false-northing
 * convention for unambiguous reverse projection.
 *
 * Easting and northing are always metres. The value carries no datum, CRS
 * identifier, EPSG code, MGRS latitude band, height, or axis metadata.
 * `.init` is invalid because its zone is invalid.
 *
 * Example:
 * ---
 * import geodesy;
 *
 * const coordinate = UtmCoordinate!double.fromComponents(
 *     UtmZone.fromNumber(33),
 *     UtmHemisphere.north,
 *     500_000.0,
 *     5_340_000.0);
 *
 * assert(coordinate.isValid);
 * assert(coordinate.zone.number == 33);
 * assert(coordinate.easting == 500_000.0);
 * ---
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
     *     failure `result` remains unchanged.
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

    /** UTM zone. */
    @property UtmZone zone() const
        pure nothrow @safe @nogc
    {
        return _zone;
    }

    /** North/south false-northing convention. */
    @property UtmHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /** Untagged projected coordinate in metres. */
    @property ProjectedCoordinate!T projected() const
        pure nothrow @safe @nogc
    {
        return _projected;
    }

    /** Easting in metres. */
    @property T easting() const
        pure nothrow @safe @nogc
    {
        return _projected.easting;
    }

    /** Northing in metres. */
    @property T northing() const
        pure nothrow @safe @nogc
    {
        return _projected.northing;
    }
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
 * Example:
 * ---
 * import geodesy;
 *
 * const vienna = GeographicCoordinate!double.fromComponents(
 *     Latitude!double.fromDegrees(48.20849),
 *     Longitude!double.fromDegrees(16.37208));
 *
 * UtmZone zone;
 * UtmHemisphere hemisphere;
 * assert(tryStandardUtmZone(vienna, zone, hemisphere));
 * assert(zone.number == 33);
 * assert(hemisphere == UtmHemisphere.north);
 * ---
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


private T utmFalseEasting(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) 500_000;
}


private T utmFalseNorthing(T)(
    const UtmHemisphere hemisphere)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return hemisphere == UtmHemisphere.south
        ? cast(T) 10_000_000
        : cast(T) 0;
}


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
 * Example:
 * ---
 * import geodesy;
 *
 * const projection = UtmProjection!double.fromZone(
 *     wgs84!double(),
 *     UtmZone.fromNumber(33),
 *     UtmHemisphere.north);
 *
 * const vienna = GeographicCoordinate!double.fromComponents(
 *     Latitude!double.fromDegrees(48.20849),
 *     Longitude!double.fromDegrees(16.37208));
 *
 * const xy = projection.forward(vienna);
 * const back = projection.reverse(xy);
 * assert(back.latitude.degrees > 48.0);
 * ---
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
     *     succeed; otherwise `false`. On failure `result` remains unchanged.
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

    /** Projection ellipsoid. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }

    /** Explicit UTM zone. */
    @property UtmZone zone() const
        pure nothrow @safe @nogc
    {
        return _zone;
    }

    /** Explicit north/south false-northing convention. */
    @property UtmHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /** Fixed UTM latitude of natural origin: zero degrees. */
    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.latitudeOfNaturalOrigin;
    }

    /** Zone central meridian. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.longitudeOfNaturalOrigin;
    }

    /** Fixed UTM natural-origin scale factor: 0.9996. */
    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.scaleFactorAtNaturalOrigin;
    }

    /** Fixed UTM false easting: 500000 metres. */
    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _transverseMercator.falseEasting;
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
     *     succeeds; otherwise `false`. On failure `result` remains unchanged.
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

    /**
     * Compute conformal projection factors for a geographic coordinate in this
     * explicit UTM zone.
     *
     * Factor mathematics and the bounded longitude domain are delegated to the
     * prepared Transverse Mercator projection. The automatic UTM latitude band
     * is not imposed.
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

    /** Throwing convenience wrapper for `tryForwardFactors`. */
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

    /**
     * Reverse a coordinate in this explicit UTM zone.
     *
     * The standard automatic UTM latitude band is not imposed here. The
     * explicit zone and hemisphere define a fixed Transverse Mercator
     * projection, subject to the bounded generic projection domain.
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

    /**
     * Compute conformal projection factors for a represented coordinate in
     * this explicit UTM zone.
     *
     * Reverse acceptance, representation-aware boundary handling, pole
     * convention, and factor mathematics are delegated to the prepared
     * Transverse Mercator projection.
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

    /** Throwing convenience wrapper for `tryReverseFactors`. */
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
}


/**
 * Project a geographic coordinate using standard automatic UTM zone and
 * hemisphere policy.
 *
 * The accepted automatic latitude domain is -80 degrees inclusive to +84
 * degrees exclusive. Zone selection applies the Norway and Svalbard
 * exceptions. This convenience operation prepares the selected zone per call;
 * bulk callers in a known zone should reuse `UtmProjection!T`.
 *
 * Params:
 *     source = Geographic source coordinate.
 *     ellipsoid = Supported terrestrial oblate ellipsoid in metres.
 *     result = Receives tagged UTM zone, hemisphere, easting, and northing.
 *
 * Returns:
 *     `true` when automatic policy selection and projection succeed.
 *
 * Example:
 * ---
 * import geodesy;
 *
 * const vienna = GeographicCoordinate!double.fromComponents(
 *     Latitude!double.fromDegrees(48.20849),
 *     Longitude!double.fromDegrees(16.37208));
 *
 * const utm = vienna.forwardUtm(wgs84!double());
 * assert(utm.zone.number == 33);
 * assert(utm.hemisphere == UtmHemisphere.north);
 *
 * const back = utm.reverseUtm(wgs84!double());
 * assert(back.latitude.degrees > 48.0);
 * ---
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
