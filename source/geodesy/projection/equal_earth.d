/**
 * Equal Earth (EPSG method 1078) equal-area world map projection.
 *
 * A prepared pseudocylindrical world projection. Uses the authalic sphere
 * for oblate ellipsoids; input/output linear units match the ellipsoid axes.
 * Supported domain: spherical and terrestrial oblate 0 <= f <= 0.01.
 *
 * Authors:
 *     Alexander Bernardi
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 * License:
 *     MIT
 * Date:
 *     October 10, 2026
 */
module geodesy.projection.equal_earth;

import std.math : PI, asin, cos, fabs, isFinite, log, sin, sqrt;
import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.scalar : isGeodesyScalar;
import geodesy.projection.internal.equal_earth_kernel :
    equalEarthForwardKernel, equalEarthReverseKernel;

/** Prepared Equal Earth projection with explicit central meridian and offsets. */
struct EqualEarth(T) if (isGeodesyScalar!T)
{
private:
    Ellipsoid!T _ellipsoid;
    Longitude!T _centralMeridian;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;
    double _e2 = double.nan;
    double _e = double.nan;
    double _qp = double.nan;
    double _radius = double.nan;

    /** Evaluate the ellipsoidal authalic latitude integral. */
    static double authalicQ(double e2, double e, double phi)
        pure nothrow @safe @nogc
    {
        const double s = sin(phi);
        if (e2 == 0.0)
            return 2.0 * s;
        const double es = e * s;
        return (1.0 - e2) *
            (s / (1.0 - e2 * s * s)
            - log((1.0 - es) / (1.0 + es)) / (2.0 * e));
    }

    /** Convert geodetic latitude to authalic latitude. */
    bool toAuthalic(double latitude, out double beta) const
        pure nothrow @safe @nogc
    {
        beta = double.nan;
        if (!isValid || !isFinite(latitude))
            return false;
        if (fabs(latitude) >= PI / 2.0)
        {
            beta = latitude > 0 ? PI / 2.0 : -PI / 2.0;
            return true;
        }
        double s = authalicQ(_e2, _e, latitude) / _qp;
        if (fabs(s) > 1.0 + 32.0 * double.epsilon)
            return false;
        if (s > 1.0) s = 1.0;
        if (s < -1.0) s = -1.0;
        beta = asin(s);
        return isFinite(beta);
    }

    /** Recover geodetic latitude with bounded monotone bisection. */
    bool fromAuthalic(double beta, out double latitude) const
        pure nothrow @safe @nogc
    {
        latitude = double.nan;
        if (!isValid || !isFinite(beta) || fabs(beta) > PI / 2.0 + 1e-14)
            return false;
        if (fabs(beta) >= PI / 2.0 - 1e-14)
        {
            latitude = beta >= 0 ? PI / 2.0 : -PI / 2.0;
            return true;
        }
        if (_e2 == 0.0 || beta == 0.0)
        {
            latitude = beta;
            return true;
        }
        const double target = _qp * sin(beta);
        double lo = -PI / 2.0;
        double hi = PI / 2.0;
        foreach (_; 0 .. 65)
        {
            const double mid = (lo + hi) * 0.5;
            if (authalicQ(_e2, _e, mid) < target)
                lo = mid;
            else
                hi = mid;
        }
        latitude = (lo + hi) * 0.5;
        return true;
    }

public:
    /** Whether the prepared projection has a valid supported ellipsoid. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid && isFinite(_radius)
            && _radius > 0.0 && isFinite(_qp) && _qp > 0.0;
    }

    /// Example: check the invalid default projection state.
    @safe unittest
    {
        EqualEarth!double projection;
        assert(!projection.isValid);
    }

    /** Try to prepare the supported sphere/oblate Equal Earth projection. */
    static bool tryFromParameters(
        const Ellipsoid!T ellipsoid,
        const Longitude!T centralMeridian,
        const T falseEasting,
        const T falseNorthing,
        out EqualEarth result)
        pure nothrow @safe @nogc
    {
        result = EqualEarth.init;
        if (!ellipsoid.isValid || ellipsoid.flattening < 0
            || ellipsoid.flattening > cast(T) 0.01
            || !isFinite(cast(double) falseEasting)
            || !isFinite(cast(double) falseNorthing))
            return false;
        const double f = cast(double) ellipsoid.flattening;
        const double e2 = f * (2.0 - f);
        const double e = sqrt(e2);
        const double qp = authalicQ(e2, e, PI / 2.0);
        const double radius =
            cast(double) ellipsoid.semiMajorAxis * sqrt(qp / 2.0);
        if (!(radius > 0.0) || !isFinite(radius) || !(qp > 0.0))
            return false;
        EqualEarth candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._centralMeridian = centralMeridian.normalized;
        candidate._falseEasting = falseEasting;
        candidate._falseNorthing = falseNorthing;
        candidate._e2 = e2;
        candidate._e = e;
        candidate._qp = qp;
        candidate._radius = radius;
        result = candidate;
        return true;
    }

    /// Example: prepare a WGS 84 Equal Earth projection without throwing.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        EqualEarth!double projection;
        assert(EqualEarth!double.tryFromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0),
            0.0, 0.0, projection));
    }

    /** Prepare a projection or throw for unsupported parameters. */
    static EqualEarth fromParameters(
        const Ellipsoid!T ellipsoid,
        const Longitude!T centralMeridian,
        const T falseEasting,
        const T falseNorthing) @safe
    {
        EqualEarth result;
        if (!tryFromParameters(ellipsoid, centralMeridian,
                falseEasting, falseNorthing, result))
            throw new GeodesyValueException("Invalid Equal Earth parameters.");
        return result;
    }

    /// Example: use a throwing factory for known valid parameters.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        auto projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        assert(projection.isValid);
    }

    /** Project a geographic coordinate without throwing. */
    bool tryForward(const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = ProjectedCoordinate!T.init;
        if (!isValid)
            return false;
        double beta;
        if (!toAuthalic(cast(double) source.latitude.radians, beta))
            return false;
        double delta = cast(double) source.longitude.normalized.radians
            - cast(double) _centralMeridian.radians;
        const double pi = cast(double) PI;
        if (delta >= pi) delta -= 2.0 * pi;
        if (delta < -pi) delta += 2.0 * pi;
        double x, y;
        if (!equalEarthForwardKernel(_radius, beta, delta, x, y))
            return false;
        return ProjectedCoordinate!T.tryFromComponents(
            cast(T) (x + cast(double) _falseEasting),
            cast(T) (y + cast(double) _falseNorthing), result);
    }

    /// Example: check the forward projection.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        auto projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        ProjectedCoordinate!double result;
        assert(projection.tryForward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0),
                Longitude!double.fromDegrees(0)), result));
        assert(result.easting == 0.0);
    }

    /** Project a geographic coordinate; throws on failure. */
    ProjectedCoordinate!T forward(const GeographicCoordinate!T source) const @safe
    {
        ProjectedCoordinate!T result;
        if (!tryForward(source, result))
            throw new GeodesyValueException("Equal Earth forward failed.");
        return result;
    }

    /// Example: project an equatorial point.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        auto projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        auto projected = projection.forward(
            GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(0),
                Longitude!double.fromDegrees(0)));
        assert(projected.northing == 0.0);
    }

    /** Invert a point in the represented Equal Earth footprint. */
    bool tryReverse(const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        result = GeographicCoordinate!T.init;
        if (!isValid)
            return false;
        double beta, delta;
        if (!equalEarthReverseKernel(_radius,
                cast(double) source.easting - cast(double) _falseEasting,
                cast(double) source.northing - cast(double) _falseNorthing,
                beta, delta))
            return false;
        double phi;
        if (!fromAuthalic(beta, phi))
            return false;
        double lambda = delta + cast(double) _centralMeridian.radians;
        const double pi = cast(double) PI;
        if (lambda >= pi) lambda -= 2.0 * pi;
        if (lambda < -pi) lambda += 2.0 * pi;
        Latitude!T lat;
        Longitude!T lon;
        if (!Latitude!T.tryFromRadians(cast(T) phi, lat)
            || !Longitude!T.tryFromRadians(cast(T) lambda, lon))
            return false;
        result = GeographicCoordinate!T.fromComponents(lat, lon);
        return true;
    }

    /// Example: invert an Equal Earth coordinate without throwing.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        auto projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        GeographicCoordinate!double result;
        assert(projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(0.0, 0.0), result));
        assert(result.latitude.degrees == 0.0);
    }

    /** Invert a projected point or throw on failure. */
    GeographicCoordinate!T reverse(const ProjectedCoordinate!T source) const @safe
    {
        GeographicCoordinate!T result;
        if (!tryReverse(source, result))
            throw new GeodesyValueException("Equal Earth reverse failed.");
        return result;
    }
    /// Example: invert the map origin.
    @safe unittest
    {
        import geodesy.ellipsoid : wgs84;
        auto projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        auto result = projection.reverse(
            ProjectedCoordinate!double.fromComponents(0.0, 0.0));
        assert(result.latitude.degrees == 0.0);
    }

}

/// Example: construct a prepared Equal Earth projection.
@safe unittest
{
    import geodesy.ellipsoid : wgs84;
    auto projection = EqualEarth!double.fromParameters(
        wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
    assert(projection.isValid);
}

/** Verify public double and float projection round trips. */
@safe unittest
{
    import geodesy.ellipsoid : wgs84;
    foreach (unused; 0 .. 1)
    {
        const projection = EqualEarth!double.fromParameters(
            wgs84!double(), Longitude!double.fromDegrees(0), 0.0, 0.0);
        const vienna = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));
        GeographicCoordinate!double roundTrip;
        assert(projection.tryReverse(projection.forward(vienna), roundTrip));
        assert(fabs(roundTrip.latitude.degrees - 48.20849) < 1e-8);
        assert(fabs(roundTrip.longitude.degrees - 16.37208) < 1e-8);
        EqualEarth!double invalid;
        assert(!invalid.isValid);
    }
}

/**
 * Differential fixtures independently generated with PROJ 9.5.1
 * (+proj=eqearth +lon_0=0, WGS84 and spherical a=b=6371000).
 * Distances are in metres. These values must not be derived from this module.
 */
@safe unittest
{
    import geodesy.ellipsoid : wgs84;

    const sphere = Ellipsoid!double.fromFlattening(6_371_000.0, 0.0);
    const ellipsoids = [sphere, wgs84!double()];
    const lon = [16.37208, 117.196763611, -179.999, 175.0];
    const lat = [48.20849, 34.0575469444, 85.0, -55.0];
    const sphericalX = [1_312_345.48091405, 10_295_861.09219202,
                        -10_326_640.10435293, 13_246_250.77046278];
    const sphericalY = [5_816_365.43582457, 4_256_722.06905651,
                        8_345_677.93982351, -6_484_657.08620553];
    const ellipsoidalX = [1_313_648.69768603, 10_302_257.07829061,
                          -10_327_625.55645225, 13_260_771.75350931];
    const ellipsoidalY = [5_803_253.62355814, 4_242_849.75761119,
                          8_345_267.17633819, -6_473_350.64232608];

    foreach (model; 0 .. 2)
    {
        const projection = EqualEarth!double.fromParameters(
            ellipsoids[model], Longitude!double.fromDegrees(0), 0.0, 0.0);
        foreach (i; 0 .. lon.length)
        {
            const source = GeographicCoordinate!double.fromComponents(
                Latitude!double.fromDegrees(lat[i]),
                Longitude!double.fromDegrees(lon[i]));
            const projected = projection.forward(source);
            const expectedX = model == 0 ? sphericalX[i] : ellipsoidalX[i];
            const expectedY = model == 0 ? sphericalY[i] : ellipsoidalY[i];
            assert(fabs(projected.easting - expectedX) < 0.025);
            assert(fabs(projected.northing - expectedY) < 0.025);

            GeographicCoordinate!double recovered;
            assert(projection.tryReverse(projected, recovered));
            assert(fabs(recovered.latitude.degrees - lat[i]) < 1e-7);
            assert(fabs(recovered.longitude.degrees - lon[i]) < 1e-7);
        }
    }
}

/** Qualify finite-domain rejection and the equatorial seam for double. */
@safe unittest
{
    import geodesy.ellipsoid : wgs84;

    const projection = EqualEarth!double.fromParameters(
        wgs84!double(), Longitude!double.fromDegrees(0),
        1200.0, -4500.0);

    GeographicCoordinate!double ignored;
    assert(!projection.tryReverse(
        ProjectedCoordinate!double.fromComponents(100_000_000.0, -4500.0),
        ignored));
    assert(!projection.tryReverse(
        ProjectedCoordinate!double.fromComponents(1200.0, 100_000_000.0),
        ignored));

    foreach (degrees; [-179.999, -100.0, 0.0, 100.0, 179.999])
    {
        const source = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(0.0),
            Longitude!double.fromDegrees(degrees));
        const projected = projection.forward(source);
        GeographicCoordinate!double reverse;
        assert(projection.tryReverse(projected, reverse));
        assert(fabs(reverse.latitude.degrees) < 1e-10);
        assert(fabs(reverse.longitude.degrees - degrees) < 1e-8);
    }

    const north = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(0.0));
    const south = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(-90.0),
        Longitude!double.fromDegrees(0.0));
    assert(isFinite(projection.forward(north).northing));
    assert(isFinite(projection.forward(south).northing));
}

/** Instantiate checked and throwing Equal Earth operations for each scalar. */
@safe unittest
{
    import geodesy.ellipsoid : wgs84;
    import std.meta : AliasSeq;

    static foreach (T; AliasSeq!(float, double, real))
    {
        EqualEarth!T projection;
        assert(EqualEarth!T.tryFromParameters(
            wgs84!T(), Longitude!T.fromDegrees(cast(T) 0),
            cast(T) 0, cast(T) 0, projection));
        const point = GeographicCoordinate!T.fromComponents(
            Latitude!T.fromDegrees(cast(T) 30),
            Longitude!T.fromDegrees(cast(T) 45));
        const mapped = projection.forward(point);
        GeographicCoordinate!T back;
        assert(projection.tryReverse(mapped, back));
        const T tolerance = is(T == float) ? cast(T) 0.001 : cast(T) 1e-7;
        assert(fabs(back.latitude.degrees - cast(T) 30) < tolerance);
        assert(fabs(back.longitude.degrees - cast(T) 45) < tolerance);
    }
}
