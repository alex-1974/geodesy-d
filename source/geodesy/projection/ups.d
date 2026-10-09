/**
 * Convert positions in the polar regions to standard UPS metre coordinates.
 *
 * UPS is the standard polar companion to UTM. Use automatic UPS for positions
 * beyond the normal UTM latitude band, or prepare `UpsProjection` when
 * working repeatedly in one polar hemisphere. The result includes north/south
 * tagging; the underlying mathematics comes from Polar Stereographic.
 *
 * Standards:
 *     EPSG:5041 / EPSG:5042 use EPSG method 9810 on WGS 84 with
 *     longitude of natural origin 0 degrees, scale 0.994, false easting
 *     2000000 m, and false northing 2000000 m.
 *
 * Domain:
 *     Standard automatic UPS selection is latitude < -80 degrees or
 *     latitude >= +84 degrees, complementing geodesy-d automatic UTM.
 *     Explicit prepared UPS admits the documented one-degree grid overlap:
 *     south latitude <= -79.5 degrees and north latitude >= +83.5 degrees.
 *
 * Units:
 *     UPS coordinates are metres.  The ellipsoid is fixed to WGS 84.
 *
 * See_Also:
 *     PolarStereographic, UtmProjection, UpsCoordinate, UpsProjection
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
 *     October 6, 2026
 */
module geodesy.projection.ups;

import std.math : PI;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.factors : ConformalProjectionFactors;
import geodesy.projection.polar_stereographic : PolarStereographic;
import geodesy.scalar : isGeodesyScalar;


/** North/south UPS polar aspect. */
enum UpsHemisphere : ubyte
{
    north,
    south,
}

/// Example selecting a UPS hemisphere.
@safe unittest
{
    import geodesy;
    enum hemisphere = UpsHemisphere.north;
    assert(hemisphere != UpsHemisphere.south);
}


/** Return whether a hemisphere value is a public UPS aspect. */
private bool isValidHemisphere(const UpsHemisphere hemisphere)
    pure nothrow @safe @nogc
{
    return hemisphere == UpsHemisphere.north
        || hemisphere == UpsHemisphere.south;
}


/** Return whether a scalar is neither NaN nor infinity. */
private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
}


/** Convert decimal degrees using the public angle operation ordering. */
private T degreesToRadians(T)(const T degrees)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return (degrees / cast(T) 180) * cast(T) PI;
}


/** Fixed UPS natural-origin scale factor. */
private T upsScaleFactor(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) 0.994L;
}


/** Fixed UPS false easting/northing in metres. */
private T upsFalseOffset(T)()
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    return cast(T) 2_000_000;
}


/** Return whether latitude lies in the explicit legal UPS overlap domain. */
private bool isLegalUpsLatitude(T)(
    const Latitude!T latitude,
    const UpsHemisphere hemisphere)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!isValidHemisphere(hemisphere))
        return false;

    const T value = latitude.radians;
    const T northLimit =
        degreesToRadians!T(cast(T) 83.5L);
    const T southLimit =
        degreesToRadians!T(cast(T) -79.5L);

    return hemisphere == UpsHemisphere.north
        ? value >= northLimit
        : value <= southLimit;
}


/** Return the represented UPS coordinate interval for one hemisphere. */
private void upsCoordinateInterval(T)(
    const UpsHemisphere hemisphere,
    out T minimum,
    out T maximum)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (hemisphere == UpsHemisphere.north)
    {
        minimum = cast(T) 1_200_000;
        maximum = cast(T) 2_800_000;
    }
    else
    {
        minimum = cast(T) 700_000;
        maximum = cast(T) 3_300_000;
    }
}


/** Return whether represented E/N lies in the admitted UPS rectangle. */
private bool isLegalUpsCoordinate(T)(
    const UpsHemisphere hemisphere,
    const T easting,
    const T northing)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!isValidHemisphere(hemisphere)
        || !isFiniteScalar(easting)
        || !isFiniteScalar(northing))
        return false;

    T minimum;
    T maximum;
    upsCoordinateInterval!T(hemisphere, minimum, maximum);

    return easting >= minimum
        && easting <= maximum
        && northing >= minimum
        && northing <= maximum;
}


/**
 * Select the standard automatic UPS hemisphere for a geographic coordinate.
 *
 * Standard UPS is the exact complement of geodesy-d automatic UTM:
 *
 *     south UPS: latitude < -80 degrees
 *     north UPS: latitude >= +84 degrees
 *
 * Therefore -80 degrees remains UTM while +84 degrees is UPS.
 */
bool tryStandardUpsHemisphere(T)(
    const GeographicCoordinate!T source,
    out UpsHemisphere hemisphere)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T latitude = source.latitude.radians;
    const T southCutover =
        degreesToRadians!T(cast(T) -80);
    const T northCutover =
        degreesToRadians!T(cast(T) 84);

    if (latitude < southCutover)
    {
        hemisphere = UpsHemisphere.south;
        return true;
    }

    if (latitude >= northCutover)
    {
        hemisphere = UpsHemisphere.north;
        return true;
    }

    return false;
}

/// Example selecting standard UPS at 85 degrees north.
@safe unittest
{
    import geodesy;
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(85.0),
        Longitude!double.fromDegrees(20.0));
    UpsHemisphere hemisphere;
    assert(tryStandardUpsHemisphere(point, hemisphere));
    assert(hemisphere == UpsHemisphere.north);
}


/**
 * Tagged UPS coordinate carrying the polar aspect required for reverse use.
 *
 * Easting and northing are metres.  The represented coordinate rectangle is:
 *
 *     north: [1200000, 2800000] on each axis
 *     south: [ 700000, 3300000] on each axis
 *
 * `.init` is invalid.
 */
struct UpsCoordinate(T)
if (isGeodesyScalar!T)
{
private:
    UpsHemisphere _hemisphere = UpsHemisphere.north;
    ProjectedCoordinate!T _projected;

public:
    /** True when this tagged coordinate satisfies the UPS representation policy. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return isLegalUpsCoordinate(
            _hemisphere,
            _projected.easting,
            _projected.northing);
    }

    /// Example checking a tagged UPS coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north, 2_000_000.0, 2_000_000.0);
        assert(coordinate.isValid);
        assert(!UpsCoordinate!double.init.isValid);
    }


    /** Construct a tagged UPS coordinate without throwing. */
    static bool tryFromComponents(
        const UpsHemisphere hemisphere,
        const T easting,
        const T northing,
        out UpsCoordinate result)
        pure nothrow @safe @nogc
    {
        result = UpsCoordinate.init;

        if (!isLegalUpsCoordinate(
                hemisphere,
                easting,
                northing))
            return false;

        ProjectedCoordinate!T projected;
        if (!ProjectedCoordinate!T.tryFromComponents(
                easting,
                northing,
                projected))
            return false;

        result._hemisphere = hemisphere;
        result._projected = projected;
        return true;
    }

    /// Example checking UPS coordinate construction.
    @safe unittest
    {
        import geodesy;
        UpsCoordinate!double coordinate;
        assert(UpsCoordinate!double.tryFromComponents(
            UpsHemisphere.south,
            2_000_000.0,
            2_000_000.0,
            coordinate));
        assert(coordinate.hemisphere == UpsHemisphere.south);
    }


    /** Construct a tagged UPS coordinate or throw. */
    static UpsCoordinate fromComponents(
        const UpsHemisphere hemisphere,
        const T easting,
        const T northing)
        @safe
    {
        UpsCoordinate result;
        if (!tryFromComponents(
                hemisphere,
                easting,
                northing,
                result))
        {
            throw new GeodesyValueException(
                "UPS coordinate requires a valid hemisphere and represented "
                ~ "easting/northing within the admitted UPS metre range.");
        }

        return result;
    }

    /// Example constructing a tagged UPS coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north,
            2_100_000.0,
            1_900_000.0);
        assert(coordinate.easting == 2_100_000.0);
    }


    /** UPS polar aspect. */
    @property UpsHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /// Example reading the UPS hemisphere.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north, 2_000_000.0, 2_000_000.0);
        assert(coordinate.hemisphere == UpsHemisphere.north);
    }


    /** Untagged projected coordinate in metres. */
    @property ProjectedCoordinate!T projected() const
        pure nothrow @safe @nogc
    {
        return _projected;
    }

    /// Example reading the projected UPS coordinate.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north, 2_100_000.0, 1_900_000.0);
        assert(coordinate.projected.northing == 1_900_000.0);
    }


    /** Easting in metres. */
    @property T easting() const
        pure nothrow @safe @nogc
    {
        return _projected.easting;
    }

    /// Example reading UPS easting.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north, 2_100_000.0, 1_900_000.0);
        assert(coordinate.easting == 2_100_000.0);
    }


    /** Northing in metres. */
    @property T northing() const
        pure nothrow @safe @nogc
    {
        return _projected.northing;
    }

    /// Example reading UPS northing.
    @safe unittest
    {
        import geodesy;
        const coordinate = UpsCoordinate!double.fromComponents(
            UpsHemisphere.north, 2_100_000.0, 1_900_000.0);
        assert(coordinate.northing == 1_900_000.0);
    }
}

/// Example using a tagged UPS coordinate.
@safe unittest
{
    import geodesy;
    const coordinate = UpsCoordinate!double.fromComponents(
        UpsHemisphere.north,
        2_100_000.0,
        1_900_000.0);
    assert(coordinate.isValid);
    assert(coordinate.hemisphere == UpsHemisphere.north);
}


/**
 * Prepared UPS projection for one explicit polar aspect.
 *
 * The projection is fixed to WGS 84, longitude of natural origin zero,
 * scale factor 0.994, and false easting/northing 2000000 metres.
 *
 * Explicit prepared use admits the UPS overlap domain:
 *
 *     north: latitude >= +83.5 degrees
 *     south: latitude <= -79.5 degrees
 */
struct UpsProjection(T)
if (isGeodesyScalar!T)
{
private:
    UpsHemisphere _hemisphere = UpsHemisphere.north;
    PolarStereographic!T _polarStereographic;

public:
    /** True when this value represents a prepared UPS projection. */
    @property bool isValid() const
        pure nothrow @safe @nogc
    {
        return isValidHemisphere(_hemisphere)
            && _polarStereographic.isValid
            && _polarStereographic.scaleFactorAtNaturalOrigin
                == upsScaleFactor!T()
            && _polarStereographic.falseEasting
                == upsFalseOffset!T()
            && _polarStereographic.falseNorthing
                == upsFalseOffset!T();
    }

    /// Example checking a prepared UPS projection.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.north).isValid);
        assert(!UpsProjection!double.init.isValid);
    }


    /** Prepare the standard UPS grid for one hemisphere without throwing.
     *
     * Select north or south explicitly; the WGS 84 ellipsoid, scale
     * and false offsets are fixed by UPS rather than supplied by the caller. */
    static bool tryFromHemisphere(
        const UpsHemisphere hemisphere,
        out UpsProjection result)
        pure nothrow @safe @nogc
    {
        result = UpsProjection.init;

        if (!isValidHemisphere(hemisphere))
            return false;

        Latitude!T latitudeOfNaturalOrigin;
        Longitude!T longitudeOfNaturalOrigin;

        if (!Latitude!T.tryFromDegrees(
                hemisphere == UpsHemisphere.north
                    ? cast(T) 90
                    : cast(T) -90,
                latitudeOfNaturalOrigin)
            || !Longitude!T.tryFromDegrees(
                cast(T) 0,
                longitudeOfNaturalOrigin))
            return false;

        PolarStereographic!T polarStereographic;
        if (!PolarStereographic!T.tryFromParameters(
                wgs84!T(),
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                upsScaleFactor!T(),
                upsFalseOffset!T(),
                upsFalseOffset!T(),
                polarStereographic))
            return false;

        UpsProjection candidate;
        candidate._hemisphere = hemisphere;
        candidate._polarStereographic = polarStereographic;

        if (!candidate.isValid)
            return false;

        result = candidate;
        return true;
    }

    /// Example preparing UPS without throwing.
    @safe unittest
    {
        import geodesy;
        UpsProjection!double projection;
        assert(UpsProjection!double.tryFromHemisphere(
            UpsHemisphere.south, projection));
        assert(projection.hemisphere == UpsHemisphere.south);
    }


    /** Prepare the standard UPS grid for the chosen hemisphere.
     *
     * Use `tryFromHemisphere` if an invalid hemisphere should return
     * `false` instead of throwing. */
    static UpsProjection fromHemisphere(
        const UpsHemisphere hemisphere)
        @safe
    {
        UpsProjection result;

        if (!tryFromHemisphere(hemisphere, result))
            throw new GeodesyValueException(
                "UPS requires a valid north or south polar aspect.");

        return result;
    }

    /// Example preparing north UPS.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        assert(projection.hemisphere == UpsHemisphere.north);
    }


    /** Fixed WGS 84 ellipsoid used by UPS. */
    @property Ellipsoid!T ellipsoid() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.ellipsoid;
    }

    /// Example reading the UPS ellipsoid.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        assert(projection.ellipsoid.semiMajorAxis == 6_378_137.0);
    }


    /** Explicit UPS polar aspect. */
    @property UpsHemisphere hemisphere() const
        pure nothrow @safe @nogc
    {
        return _hemisphere;
    }

    /// Example reading the UPS aspect.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.south).hemisphere == UpsHemisphere.south);
    }


    /** Fixed UPS polar latitude of natural origin. */
    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.latitudeOfNaturalOrigin;
    }

    /// Example reading the UPS latitude of natural origin.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.north).latitudeOfNaturalOrigin.degrees == 90.0);
    }


    /** Fixed UPS longitude of natural origin: zero degrees. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.longitudeOfNaturalOrigin;
    }

    /// Example reading the UPS longitude of natural origin.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.north).longitudeOfNaturalOrigin.degrees == 0.0);
    }


    /** Fixed UPS natural-origin scale: 0.994. */
    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.scaleFactorAtNaturalOrigin;
    }

    /// Example reading the UPS scale factor.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.north).scaleFactorAtNaturalOrigin == 0.994);
    }


    /** Fixed UPS false easting: 2000000 metres. */
    @property T falseEasting() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.falseEasting;
    }

    /// Example reading UPS false easting.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.north).falseEasting == 2_000_000.0);
    }


    /** Fixed UPS false northing: 2000000 metres. */
    @property T falseNorthing() const
        pure nothrow @safe @nogc
    {
        return _polarStereographic.falseNorthing;
    }

    /// Example reading UPS false northing.
    @safe unittest
    {
        import geodesy;
        assert(UpsProjection!double.fromHemisphere(
            UpsHemisphere.south).falseNorthing == 2_000_000.0);
    }


    /** Project within the explicit legal UPS overlap domain without throwing. */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid
            || !isLegalUpsLatitude(
                source.latitude,
                _hemisphere))
            return false;

        ProjectedCoordinate!T candidate;
        if (!_polarStereographic.tryForward(
                source,
                candidate))
            return false;

        if (!isLegalUpsCoordinate(
                _hemisphere,
                candidate.easting,
                candidate.northing))
            return false;

        result = candidate;
        return true;
    }

    /// Example projecting in prepared north UPS.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        ProjectedCoordinate!double result;
        assert(projection.tryForward(point, result));
        assert(result.easting > 1_200_000.0);
    }


    /** Convert a position in the chosen polar hemisphere to UPS metres.
     *
     * Use this when you have already selected a UPS hemisphere and want
     * its standard grid coordinates. The prepared projection also admits
     * the documented overlap with UTM; use `tryForward` for checked input.
     */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;

        if (!tryForward(source, result))
            throw new GeodesyValueException(
                "UPS forward projection failed because the source is outside "
                ~ "the explicit legal UPS overlap or represented grid range.");

        return result;
    }

    /// Example projecting in prepared south UPS.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.south);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-85.0),
            Longitude!double.fromDegrees(20.0));
        assert(projection.forward(point).northing > 700_000.0);
    }


    /** Compute conformal factors in the explicit legal UPS domain. */
    bool tryForwardFactors(
        const GeographicCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        if (!isValid
            || !isLegalUpsLatitude(
                source.latitude,
                _hemisphere))
            return false;

        return _polarStereographic.tryForwardFactors(
            source,
            result);
    }

    /// Example checking UPS factors without throwing.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        ConformalProjectionFactors!double factors;
        assert(projection.tryForwardFactors(point, factors));
        assert(factors.pointScale > 0.0);
    }


    /** Compute conformal factors in the explicit legal UPS domain or throw. */
    ConformalProjectionFactors!T forwardFactors(
        const GeographicCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryForwardFactors(source, result))
            throw new GeodesyValueException(
                "UPS forward factor evaluation failed outside the explicit "
                ~ "legal UPS overlap.");

        return result;
    }

    /// Example computing UPS factors.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        assert(projection.forwardFactors(point).pointScale > 0.0);
    }


    /** Convert UPS easting and northing back to latitude and longitude.
     *
     * This checked form returns `false` for grid coordinates outside the
     * valid represented UPS region.
     */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid
            || !isLegalUpsCoordinate(
                _hemisphere,
                source.easting,
                source.northing))
            return false;

        GeographicCoordinate!T candidate;
        if (!_polarStereographic.tryReverse(
                source,
                candidate))
            return false;

        if (!isLegalUpsLatitude(
                candidate.latitude,
                _hemisphere))
        {
            /*
             * The explicit UPS overlap limits are closed public-policy
             * boundaries.  On a wider public scalar (notably AArch64 real),
             * reverse projection of an exactly represented legal boundary
             * point can recover a latitude infinitesimally outside the policy
             * interval even though forward projection of the legal boundary
             * collapses to the exact same ProjectedCoordinate!T.
             *
             * Do not introduce an angular epsilon.  Accept only when the
             * represented source is exactly equal to the projection of the
             * legal boundary at the recovered longitude; then the legal public
             * boundary representative wins.
             */
            const T boundaryDegrees =
                _hemisphere == UpsHemisphere.north
                    ? cast(T) 83.5L
                    : cast(T) -79.5L;

            Latitude!T boundaryLatitude;
            if (!Latitude!T.tryFromDegrees(
                    boundaryDegrees,
                    boundaryLatitude))
                return false;

            const GeographicCoordinate!T boundaryPoint =
                GeographicCoordinate!T.fromComponents(
                    boundaryLatitude,
                    candidate.longitude);

            ProjectedCoordinate!T boundaryProjected;
            if (!_polarStereographic.tryForward(
                    boundaryPoint,
                    boundaryProjected)
                || boundaryProjected.easting != source.easting
                || boundaryProjected.northing != source.northing)
                return false;

            candidate =
                GeographicCoordinate!T.fromComponents(
                    boundaryLatitude,
                    candidate.longitude);
        }

        result = candidate;
        return true;
    }

    /// Example reversing a prepared UPS coordinate.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        GeographicCoordinate!double result;
        assert(projection.tryReverse(projection.forward(point), result));
        assert(result.latitude.degrees > 84.0);
    }


    /** Convert UPS grid coordinates back into a geographic position.
     *
     * Use `tryReverse` when invalid coordinates should not throw.
     */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;

        if (!tryReverse(source, result))
            throw new GeodesyValueException(
                "UPS reverse projection failed because the represented "
                ~ "coordinate or recovered latitude is outside UPS policy.");

        return result;
    }

    /// Example reversing a south UPS coordinate.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.south);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(-85.0),
            Longitude!double.fromDegrees(20.0));
        assert(projection.reverse(
            projection.forward(point)).latitude.degrees < -84.0);
    }


    /** Compute reverse factors for an admitted represented UPS coordinate. */
    bool tryReverseFactors(
        const ProjectedCoordinate!T source,
        out ConformalProjectionFactors!T result) const
        pure nothrow @safe @nogc
    {
        result = ConformalProjectionFactors!T.init;

        if (!isValid
            || !isLegalUpsCoordinate(
                _hemisphere,
                source.easting,
                source.northing))
            return false;

        GeographicCoordinate!T geographic;
        if (!tryReverse(source, geographic))
            return false;

        return _polarStereographic.tryReverseFactors(
            source,
            result);
    }

    /// Example checking reverse UPS factors.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        ConformalProjectionFactors!double factors;
        assert(projection.tryReverseFactors(
            projection.forward(point), factors));
        assert(factors.pointScale > 0.0);
    }


    /** Compute reverse factors for an admitted represented UPS coordinate or throw. */
    ConformalProjectionFactors!T reverseFactors(
        const ProjectedCoordinate!T source) const
        @safe
    {
        ConformalProjectionFactors!T result;

        if (!tryReverseFactors(source, result))
            throw new GeodesyValueException(
                "UPS reverse factor evaluation failed outside represented "
                ~ "UPS policy.");

        return result;
    }

    /// Example computing reverse UPS factors.
    @safe unittest
    {
        import geodesy;
        const projection = UpsProjection!double.fromHemisphere(
            UpsHemisphere.north);
        const point = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(85.0),
            Longitude!double.fromDegrees(20.0));
        assert(projection.reverseFactors(
            projection.forward(point)).pointScale > 0.0);
    }
}

/// Example using a prepared UPS projection.
@safe unittest
{
    import geodesy;
    const projection = UpsProjection!double.fromHemisphere(
        UpsHemisphere.north);
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(85.0),
        Longitude!double.fromDegrees(20.0));
    const projected = projection.forward(point);
    assert(projected.easting > 1_200_000.0);
}


/**
 * Project a geographic coordinate using standard automatic UPS policy.
 *
 * Automatic UPS is selected only outside standard automatic UTM:
 *
 *     latitude < -80 degrees or latitude >= +84 degrees.
 */
bool tryForwardUps(T)(
    const GeographicCoordinate!T source,
    out UpsCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    result = UpsCoordinate!T.init;

    UpsHemisphere hemisphere;
    if (!tryStandardUpsHemisphere(
            source,
            hemisphere))
        return false;

    UpsProjection!T projection;
    if (!UpsProjection!T.tryFromHemisphere(
            hemisphere,
            projection))
        return false;

    ProjectedCoordinate!T projected;
    if (!projection.tryForward(
            source,
            projected))
        return false;

    return UpsCoordinate!T.tryFromComponents(
        hemisphere,
        projected.easting,
        projected.northing,
        result);
}

/// Example projecting automatically to UPS.
@safe unittest
{
    import geodesy;
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(85.0),
        Longitude!double.fromDegrees(20.0));
    UpsCoordinate!double result;
    assert(tryForwardUps(point, result));
    assert(result.hemisphere == UpsHemisphere.north);
}


/** Automatic UPS forward projection with throwing failure semantics. */
UpsCoordinate!T forwardUps(T)(
    const GeographicCoordinate!T source)
    @safe
if (isGeodesyScalar!T)
{
    UpsCoordinate!T result;

    if (!tryForwardUps(source, result))
        throw new GeodesyValueException(
            "Automatic UPS forward projection requires latitude < -80 "
            ~ "degrees or latitude >= +84 degrees.");

    return result;
}

/// Example using automatic UPS forward projection.
@safe unittest
{
    import geodesy;
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-85.0),
        Longitude!double.fromDegrees(20.0));
    assert(forwardUps(point).hemisphere == UpsHemisphere.south);
}


/** Reverse a tagged UPS coordinate using its stored polar aspect. */
bool tryReverseUps(T)(
    const UpsCoordinate!T source,
    out GeographicCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!source.isValid)
        return false;

    UpsProjection!T projection;
    if (!UpsProjection!T.tryFromHemisphere(
            source.hemisphere,
            projection))
        return false;

    return projection.tryReverse(
        source.projected,
        result);
}

/// Example reversing a tagged UPS coordinate without throwing.
@safe unittest
{
    import geodesy;
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(85.0),
        Longitude!double.fromDegrees(20.0));
    const ups = forwardUps(point);
    GeographicCoordinate!double result;
    assert(tryReverseUps(ups, result));
    assert(result.latitude.degrees > 84.0);
}


/** Reverse a tagged UPS coordinate or throw. */
GeographicCoordinate!T reverseUps(T)(
    const UpsCoordinate!T source)
    @safe
if (isGeodesyScalar!T)
{
    GeographicCoordinate!T result;

    if (!tryReverseUps(source, result))
        throw new GeodesyValueException(
            "UPS reverse projection requires a valid tagged represented "
            ~ "UPS coordinate.");

    return result;
}

/// Example reversing an automatically projected UPS coordinate.
@safe unittest
{
    import geodesy;
    const point = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-85.0),
        Longitude!double.fromDegrees(20.0));
    const result = reverseUps(forwardUps(point));
    assert(result.latitude.degrees < -84.0);
}


unittest
{
    import std.exception : assertThrown;

    static assert(is(UpsCoordinate!float));
    static assert(is(UpsCoordinate!double));
    static assert(is(UpsCoordinate!real));

    static assert(is(UpsProjection!float));
    static assert(is(UpsProjection!double));
    static assert(is(UpsProjection!real));

    UpsHemisphere hemisphere;

    const south80 = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-80.0),
        Longitude!double.fromDegrees(0.0));
    assert(!tryStandardUpsHemisphere(south80, hemisphere));

    const southBelow80 = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-80.000001),
        Longitude!double.fromDegrees(0.0));
    assert(tryStandardUpsHemisphere(southBelow80, hemisphere));
    assert(hemisphere == UpsHemisphere.south);

    const north84 = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(84.0),
        Longitude!double.fromDegrees(0.0));
    assert(tryStandardUpsHemisphere(north84, hemisphere));
    assert(hemisphere == UpsHemisphere.north);

    const northBelow84 = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(83.999999),
        Longitude!double.fromDegrees(0.0));
    assert(!tryStandardUpsHemisphere(northBelow84, hemisphere));

    const north = UpsProjection!double.fromHemisphere(
        UpsHemisphere.north);
    const northOverlap = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(83.5),
        Longitude!double.fromDegrees(0.0));
    const northOutside = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(83.499),
        Longitude!double.fromDegrees(0.0));

    ProjectedCoordinate!double projected;
    assert(north.tryForward(northOverlap, projected));
    assert(!north.tryForward(northOutside, projected));

    const south = UpsProjection!double.fromHemisphere(
        UpsHemisphere.south);
    const southOverlap = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-79.5),
        Longitude!double.fromDegrees(0.0));
    const southOutside = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-79.499),
        Longitude!double.fromDegrees(0.0));

    assert(south.tryForward(southOverlap, projected));
    assert(!south.tryForward(southOutside, projected));

    UpsCoordinate!double coordinate;
    assert(UpsCoordinate!double.tryFromComponents(
        UpsHemisphere.north,
        1_200_000.0,
        2_800_000.0,
        coordinate));
    assert(!UpsCoordinate!double.tryFromComponents(
        UpsHemisphere.north,
        1_199_999.0,
        2_000_000.0,
        coordinate));
    assert(UpsCoordinate!double.tryFromComponents(
        UpsHemisphere.south,
        700_000.0,
        3_300_000.0,
        coordinate));
    assert(!UpsCoordinate!double.tryFromComponents(
        UpsHemisphere.south,
        3_300_001.0,
        2_000_000.0,
        coordinate));

    const epsgPoint = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(73.0),
        Longitude!double.fromDegrees(44.0));

    // Generic Polar Stereographic accepts the EPSG method example, while UPS
    // policy correctly rejects it as outside explicit UPS grid overlap.
    assert(!north.tryForward(epsgPoint, projected));

    assertThrown!GeodesyValueException(
        forwardUps(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0.0),
                Longitude!double.fromDegrees(0.0))));
}
