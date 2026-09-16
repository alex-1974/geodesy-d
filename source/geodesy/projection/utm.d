/**
 * Universal Transverse Mercator policy types and standard zone selection.
 *
 * Numerical projection is deliberately not implemented here yet. UTM
 * projection delegation is added only after the pure policy gate has passed.
 */
module geodesy.projection.utm;

import std.math : PI;

import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
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
 * Valid zones are exactly 1 through 60. `.init` is intentionally invalid.
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

    /** Construct from a zone number without throwing. */
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

    /** Construct from a zone number or throw for values outside 1 through 60. */
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
 * Projected UTM coordinate carrying the zone and false-northing convention
 * required for unambiguous reverse projection.
 *
 * Easting and northing are in metres.
 *
 * This value carries no datum, CRS identifier, EPSG code, MGRS latitude band,
 * height, or axis metadata.
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

    /** Construct a tagged UTM coordinate without throwing. */
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

    /** Construct a tagged UTM coordinate or throw on invalid input. */
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
 * The accepted automatic UTM latitude region is:
 *
 *     -80 degrees <= latitude < 84 degrees
 *
 * Longitude is canonicalized to [-180 degrees, +180 degrees) before zone
 * selection. Norway and Svalbard exceptions are applied.
 *
 * Latitude zero uses the northern false-northing convention.
 *
 * Returns false outside the standard UTM latitude region.
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
