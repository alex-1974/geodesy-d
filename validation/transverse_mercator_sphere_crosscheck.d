/**
 * Deterministic spherical Transverse Mercator validation against an
 * independent analytic oracle.
 *
 * The production implementation uses the Krueger/Karney ellipsoidal series
 * with an exact n = 0 spherical limit.  This harness does not use that series.
 * It evaluates the closed-form spherical Transverse Mercator equations
 * directly and therefore provides an independent f = 0 validation path.
 *
 * Primary formulas:
 *   PROJ tmerc spherical forward/inverse definition.
 *
 * Public-domain contract under test:
 *   abs(deltaLongitude) <= 60 degrees
 *   float  ground-equivalent error <= 2 m
 *   double ground-equivalent error <= 1 mm
 */
module transverse_mercator_sphere_crosscheck;

import std.conv : to;
import std.format : format;
import std.math : PI, asinh, atan2, cos, fabs, isFinite, sin, sinh, sqrt;
import std.stdio : writefln, writeln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private enum double doubleTargetMetres = 1.0e-3;
private enum double floatTargetMetres = 2.0;
private enum ulong randomCorpusSeed = 0x544D5F5350484552UL; // "TM_SPHER"


private struct SourceSpec
{
    string name;
    double radius;
    double latitudeOfNaturalOrigin;
    double longitudeOfNaturalOrigin;
    double scaleFactorAtNaturalOrigin;
    double falseEasting;
    double falseNorthing;
}


private struct OracleSpec
{
    double radius;
    double latitudeOfNaturalOriginRadians;
    double longitudeOfNaturalOriginRadians;
    double scaleFactorAtNaturalOrigin;
    double falseEasting;
    double falseNorthing;
}


private struct SourcePoint
{
    double latitude;
    double deltaLongitude;
}


private struct OracleProjected
{
    double easting;
    double northing;
    double scale;
}


private struct Metrics
{
    size_t forwardComparisons;
    size_t reverseComparisons;
    size_t failures;

    double worstAbsoluteError;
    string worstAbsoluteLabel;

    double worstGroundEquivalentError;
    string worstGroundEquivalentLabel;
}


private struct FloatFailureDiagnostics
{
    size_t forwardPublicPole;
    size_t forwardNonPole;
    size_t reversePublicPoleSource;
    size_t reverseNonPoleSource;

    size_t reverseNonPoleRejected;
    size_t reverseNonPoleResidual;
}


private struct DoubleContext
{
    TransverseMercator!double projection;
    OracleSpec oracle;
}


private struct FloatContext
{
    TransverseMercator!float projection;
    OracleSpec oracle;
}


private double sq(const double x)
{
    return x * x;
}


private double hypot2(const double x, const double y)
{
    return sqrt(x * x + y * y);
}


private double degreesFromRadians(const double radians)
{
    return radians * (180.0 / PI);
}


private double normalizeRadians(double value)
{
    const double twoPi = 2.0 * PI;

    while (value >= PI)
        value -= twoPi;

    while (value < -PI)
        value += twoPi;

    return value;
}

private double normalizeDegrees(double value)
{
    while (value >= 180.0)
        value -= 360.0;

    while (value < -180.0)
        value += 360.0;

    return value;
}


private int doublePoleSign(const Latitude!double latitude)
{
    const north =
        Latitude!double.fromDegrees(90.0);
    const south =
        Latitude!double.fromDegrees(-90.0);

    if (latitude.radians == north.radians)
        return 1;

    if (latitude.radians == south.radians)
        return -1;

    return 0;
}


private int floatPoleSign(const Latitude!float latitude)
{
    const north =
        Latitude!float.fromDegrees(90.0f);
    const south =
        Latitude!float.fromDegrees(-90.0f);

    if (latitude.radians == north.radians)
        return 1;

    if (latitude.radians == south.radians)
        return -1;

    return 0;
}


/*
 * Independent closed-form spherical Transverse Mercator.
 *
 * Let lambda be longitude relative to the central meridian.
 *
 *   q   = hypot(sin(phi), cos(phi) cos(lambda))
 *   xi  = atan2(sin(phi), cos(phi) cos(lambda))
 *   eta = asinh(cos(phi) sin(lambda) / q)
 *
 *   E = FE + k0 R eta
 *   N = FN + k0 R (xi - phi0)
 *
 * The conformal point scale on the sphere is:
 *
 *   k = k0 / q
 *
 * This form is algebraically equivalent to the usual tan(phi) equations but
 * remains well behaved at the geographic poles.
 */
private OracleProjected sphereForward(
    const OracleSpec spec,
    const double latitudeRadians,
    const double longitudeRadians,
    const bool clampRepresentedBoundary,
    const int poleSign = 0)
{
    double deltaLongitude =
        normalizeRadians(
            longitudeRadians
            - spec.longitudeOfNaturalOriginRadians);

    if (clampRepresentedBoundary)
    {
        const double maxDelta = PI / 3.0;

        if (fabs(deltaLongitude) > maxDelta)
            deltaLongitude =
                deltaLongitude < 0.0
                    ? -maxDelta
                    : maxDelta;
    }

    /*
     * Public Latitude!T represents +/-90 degrees with a rounded T-radian
     * value.  For float in particular, cos(storedRadians) is not zero and can
     * even have the opposite sign from the mathematical one.  The production
     * TM deliberately treats the public pole as an exact geographic pole, so
     * the independent oracle must apply the same public-coordinate semantic
     * before evaluating its otherwise closed-form equations.
     */
    if (poleSign != 0)
    {
        const double poleLatitude =
            poleSign < 0
                ? -PI / 2.0
                : PI / 2.0;

        return OracleProjected(
            spec.falseEasting,
            spec.falseNorthing
                + spec.scaleFactorAtNaturalOrigin
                    * spec.radius
                    * (
                        poleLatitude
                        - spec.latitudeOfNaturalOriginRadians),
            spec.scaleFactorAtNaturalOrigin);
    }

    const double sinLatitude = sin(latitudeRadians);
    const double cosLatitude = cos(latitudeRadians);
    const double sinDelta = sin(deltaLongitude);
    const double cosDelta = cos(deltaLongitude);

    const double q =
        hypot2(
            sinLatitude,
            cosLatitude * cosDelta);

    const double xi =
        atan2(
            sinLatitude,
            cosLatitude * cosDelta);

    const double eta =
        asinh(
            cosLatitude * sinDelta / q);

    return OracleProjected(
        spec.falseEasting
            + spec.scaleFactorAtNaturalOrigin
                * spec.radius
                * eta,
        spec.falseNorthing
            + spec.scaleFactorAtNaturalOrigin
                * spec.radius
                * (
                    xi
                    - spec.latitudeOfNaturalOriginRadians),
        spec.scaleFactorAtNaturalOrigin / q);
}


private SourcePoint sphereReverse(
    const OracleSpec spec,
    const double easting,
    const double northing)
{
    const double denominator =
        spec.scaleFactorAtNaturalOrigin
            * spec.radius;

    const double eta =
        (easting - spec.falseEasting)
            / denominator;

    const double xi =
        (northing - spec.falseNorthing)
            / denominator
            + spec.latitudeOfNaturalOriginRadians;

    const double sinhEta = sinh(eta);

    const double latitude =
        atan2(
            sin(xi),
            hypot2(
                sinhEta,
                cos(xi)));

    const double deltaLongitude =
        atan2(
            sinhEta,
            cos(xi));

    const double longitude =
        normalizeRadians(
            spec.longitudeOfNaturalOriginRadians
            + deltaLongitude);

    return SourcePoint(
        degreesFromRadians(latitude),
        degreesFromRadians(longitude));
}


private DoubleContext makeDoubleContext(const SourceSpec source)
{
    const double radius = source.radius;
    const double scaleFactor = source.scaleFactorAtNaturalOrigin;
    const double falseEasting = source.falseEasting;
    const double falseNorthing = source.falseNorthing;

    const latitudeOfNaturalOrigin =
        Latitude!double.fromDegrees(
            source.latitudeOfNaturalOrigin);

    const longitudeOfNaturalOrigin =
        Longitude!double.fromDegrees(
            source.longitudeOfNaturalOrigin);

    return DoubleContext(
        TransverseMercator!double.fromParameters(
            Ellipsoid!double.fromFlattening(
                radius,
                0.0),
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            scaleFactor,
            falseEasting,
            falseNorthing),
        OracleSpec(
            radius,
            latitudeOfNaturalOrigin.radians,
            longitudeOfNaturalOrigin.radians,
            scaleFactor,
            falseEasting,
            falseNorthing));
}


private FloatContext makeFloatContext(const SourceSpec source)
{
    const float radius = cast(float) source.radius;
    const float scaleFactor =
        cast(float) source.scaleFactorAtNaturalOrigin;
    const float falseEasting =
        cast(float) source.falseEasting;
    const float falseNorthing =
        cast(float) source.falseNorthing;

    const latitudeOfNaturalOrigin =
        Latitude!float.fromDegrees(
            cast(float) source.latitudeOfNaturalOrigin);

    const longitudeOfNaturalOrigin =
        Longitude!float.fromDegrees(
            cast(float) source.longitudeOfNaturalOrigin);

    return FloatContext(
        TransverseMercator!float.fromParameters(
            Ellipsoid!float.fromFlattening(
                radius,
                0.0f),
            latitudeOfNaturalOrigin,
            longitudeOfNaturalOrigin,
            scaleFactor,
            falseEasting,
            falseNorthing),
        OracleSpec(
            cast(double) radius,
            cast(double) latitudeOfNaturalOrigin.radians,
            cast(double) longitudeOfNaturalOrigin.radians,
            cast(double) scaleFactor,
            cast(double) falseEasting,
            cast(double) falseNorthing));
}


private SourceSpec[] sourceSpecs()
{
    return [
        SourceSpec(
            "Sphere-R6378137-equatorial",
            6_378_137.0,
            0.0, 15.0, 1.0, 0.0, 0.0),

        SourceSpec(
            "Sphere-R6371000-OSGB-origin",
            6_371_000.0,
            49.0, -2.0, 0.9996, 500_000.0, 0.0),

        SourceSpec(
            "Sphere-R6378137-antimeridian-north",
            6_378_137.0,
            -35.0, 179.75, 0.9999, -2_000_000.0, 3_000_000.0),

        SourceSpec(
            "Sphere-R6371000-high-north-origin",
            6_371_000.0,
            80.0, -179.75, 1.1,
            12_742_000.0, -12_742_000.0),

        SourceSpec(
            "Sphere-R6371000-high-south-origin",
            6_371_000.0,
            -80.0, 123.0, 0.9,
            -12_742_000.0, 12_742_000.0),

        SourceSpec(
            "Sphere-R6000000-profile-min",
            6_000_000.0,
            0.0, 0.0, 0.9,
            -12_000_000.0, 12_000_000.0),

        SourceSpec(
            "Sphere-R7000000-profile-max",
            7_000_000.0,
            35.0, -123.0, 1.1,
            14_000_000.0, -14_000_000.0),

        SourceSpec(
            "Sphere-R6378137-UTM-like",
            6_378_137.0,
            0.0, -123.0, 0.9996,
            500_000.0, 10_000_000.0),
    ];
}


private Metrics makeMetrics()
{
    Metrics metrics = Metrics.init;

    /*
     * D floating-point .init is NaN.  Explicit zero initialization is required
     * for running maxima; otherwise every `value > maximum` comparison is
     * false and a validator can print NaN while appearing to pass.
     */
    metrics.worstAbsoluteError = 0.0;
    metrics.worstGroundEquivalentError = 0.0;

    return metrics;
}


private void recordComparison(
    const string label,
    const double actualEasting,
    const double actualNorthing,
    const double referenceEasting,
    const double referenceNorthing,
    const double referenceScale,
    const double targetMetres,
    ref Metrics metrics)
{
    if (!isFinite(actualEasting)
        || !isFinite(actualNorthing)
        || !isFinite(referenceEasting)
        || !isFinite(referenceNorthing)
        || !isFinite(referenceScale)
        || !(referenceScale > 0.0))
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "NON-FINITE REFERENCE/RESULT: %s "
                ~ "actual=(%.17g, %.17g) reference=(%.17g, %.17g) "
                ~ "scale=%.17g",
                label,
                actualEasting,
                actualNorthing,
                referenceEasting,
                referenceNorthing,
                referenceScale);

        return;
    }

    const double deltaEasting =
        actualEasting - referenceEasting;
    const double deltaNorthing =
        actualNorthing - referenceNorthing;

    const double absoluteError =
        hypot2(deltaEasting, deltaNorthing);

    const double groundEquivalentError =
        absoluteError / referenceScale;

    if (!isFinite(absoluteError)
        || !isFinite(groundEquivalentError))
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "NON-FINITE ERROR: %s abs=%.17g ground=%.17g",
                label,
                absoluteError,
                groundEquivalentError);

        return;
    }

    if (absoluteError > metrics.worstAbsoluteError)
    {
        metrics.worstAbsoluteError = absoluteError;
        metrics.worstAbsoluteLabel = label;
    }

    if (groundEquivalentError
        > metrics.worstGroundEquivalentError)
    {
        metrics.worstGroundEquivalentError =
            groundEquivalentError;
        metrics.worstGroundEquivalentLabel = label;
    }

    if (absoluteError > targetMetres
        || groundEquivalentError > targetMetres)
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s abs=%.12g m ground=%.12g m",
                label,
                absoluteError,
                groundEquivalentError);
    }
}


private void validateDoublePoint(
    const SourceSpec source,
    const DoubleContext context,
    const SourcePoint point,
    const size_t index,
    ref Metrics metrics)
{
    const double sourceLongitude =
        normalizeDegrees(
            source.longitudeOfNaturalOrigin
            + point.deltaLongitude);

    const latitude =
        Latitude!double.fromDegrees(point.latitude);

    const longitude =
        Longitude!double.fromDegrees(sourceLongitude);

    const geographic =
        GeographicCoordinate!double.fromComponents(
            latitude,
            longitude);

    const reference =
        sphereForward(
            context.oracle,
            latitude.radians,
            longitude.radians,
            true,
            doublePoleSign(latitude));

    ProjectedCoordinate!double projected;

    if (!context.projection.tryForward(
        geographic,
        projected))
    {
        ++metrics.forwardComparisons;
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] double forward rejected",
                source.name,
                index);

        return;
    }

    ++metrics.forwardComparisons;

    recordComparison(
        format(
            "%s point[%s] lat=%.12f dlon=%.12f double forward",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        projected.easting,
        projected.northing,
        reference.easting,
        reference.northing,
        reference.scale,
        doubleTargetMetres,
        metrics);

    const representedProjected =
        ProjectedCoordinate!double.fromComponents(
            reference.easting,
            reference.northing);

    GeographicCoordinate!double recovered;

    ++metrics.reverseComparisons;

    if (!context.projection.tryReverse(
        representedProjected,
        recovered))
    {
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] double reverse rejected",
                source.name,
                index);

        return;
    }

    const reverseReference =
        sphereForward(
            context.oracle,
            recovered.latitude.radians,
            recovered.longitude.radians,
            false,
            doublePoleSign(recovered.latitude));

    recordComparison(
        format(
            "%s point[%s] lat=%.12f dlon=%.12f double reverse",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        reverseReference.easting,
        reverseReference.northing,
        representedProjected.easting,
        representedProjected.northing,
        reverseReference.scale,
        doubleTargetMetres,
        metrics);
}


private void validateFloatPoint(
    const SourceSpec source,
    const FloatContext context,
    const SourcePoint point,
    const size_t index,
    ref Metrics metrics,
    ref FloatFailureDiagnostics diagnostics)
{
    const float sourceLongitudeDegrees =
        cast(float) normalizeDegrees(
            source.longitudeOfNaturalOrigin
            + point.deltaLongitude);

    const latitude =
        Latitude!float.fromDegrees(
            cast(float) point.latitude);

    const int sourcePoleSign =
        floatPoleSign(latitude);

    const longitude =
        Longitude!float.fromDegrees(
            sourceLongitudeDegrees);

    const geographic =
        GeographicCoordinate!float.fromComponents(
            latitude,
            longitude);

    const reference =
        sphereForward(
            context.oracle,
            cast(double) latitude.radians,
            cast(double) longitude.radians,
            true,
            sourcePoleSign);

    ProjectedCoordinate!float projected;

    if (!context.projection.tryForward(
        geographic,
        projected))
    {
        ++metrics.forwardComparisons;
        ++metrics.failures;

        if (sourcePoleSign != 0)
            ++diagnostics.forwardPublicPole;
        else
            ++diagnostics.forwardNonPole;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] float forward rejected",
                source.name,
                index);

        return;
    }

    ++metrics.forwardComparisons;

    const size_t failuresBeforeForwardComparison =
        metrics.failures;

    recordComparison(
        format(
            "%s point[%s] lat=%.12f dlon=%.12f float forward",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        cast(double) projected.easting,
        cast(double) projected.northing,
        reference.easting,
        reference.northing,
        reference.scale,
        floatTargetMetres,
        metrics);

    if (metrics.failures != failuresBeforeForwardComparison)
    {
        if (sourcePoleSign != 0)
            ++diagnostics.forwardPublicPole;
        else
            ++diagnostics.forwardNonPole;
    }

    const float inputEasting =
        cast(float) reference.easting;
    const float inputNorthing =
        cast(float) reference.northing;

    const representedProjected =
        ProjectedCoordinate!float.fromComponents(
            inputEasting,
            inputNorthing);

    GeographicCoordinate!float recovered;

    ++metrics.reverseComparisons;

    if (!context.projection.tryReverse(
        representedProjected,
        recovered))
    {
        ++metrics.failures;

        if (sourcePoleSign != 0)
            ++diagnostics.reversePublicPoleSource;
        else
        {
            ++diagnostics.reverseNonPoleSource;
            ++diagnostics.reverseNonPoleRejected;

        }

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s point[%s] float reverse rejected",
                source.name,
                index);

        return;
    }

    const reverseReference =
        sphereForward(
            context.oracle,
            cast(double) recovered.latitude.radians,
            cast(double) recovered.longitude.radians,
            false,
            floatPoleSign(recovered.latitude));

    const size_t failuresBeforeReverseComparison =
        metrics.failures;

    recordComparison(
        format(
            "%s point[%s] lat=%.12f dlon=%.12f float reverse",
            source.name,
            index,
            point.latitude,
            point.deltaLongitude),
        reverseReference.easting,
        reverseReference.northing,
        cast(double) representedProjected.easting,
        cast(double) representedProjected.northing,
        reverseReference.scale,
        floatTargetMetres,
        metrics);

    if (metrics.failures != failuresBeforeReverseComparison)
    {
        if (sourcePoleSign != 0)
            ++diagnostics.reversePublicPoleSource;
        else
        {
            ++diagnostics.reverseNonPoleSource;
            ++diagnostics.reverseNonPoleResidual;

        }
    }
}


private void validateOracleSelfConsistency()
{
    foreach (source; sourceSpecs())
    {
        const context = makeDoubleContext(source);

        foreach (point; [
            SourcePoint(-90.0, -60.0),
            SourcePoint(-89.999999, 60.0),
            SourcePoint(-45.0, -35.0),
            SourcePoint(0.0, -60.0),
            SourcePoint(0.0, 0.0),
            SourcePoint(45.0, 35.0),
            SourcePoint(89.999999, -60.0),
            SourcePoint(90.0, 60.0),
        ])
        {
            const longitudeDegrees =
                normalizeDegrees(
                    source.longitudeOfNaturalOrigin
                    + point.deltaLongitude);

            const latitude =
                Latitude!double.fromDegrees(point.latitude);

            const longitude =
                Longitude!double.fromDegrees(longitudeDegrees);

            const projected =
                sphereForward(
                    context.oracle,
                    latitude.radians,
                    longitude.radians,
                    true,
                    doublePoleSign(latitude));

            const recovered =
                sphereReverse(
                    context.oracle,
                    projected.easting,
                    projected.northing);

            const recoveredLatitude =
                Latitude!double.fromDegrees(
                    recovered.latitude);

            const recoveredLongitude =
                Longitude!double.fromDegrees(
                    recovered.deltaLongitude);

            const projectedAgain =
                sphereForward(
                    context.oracle,
                    recoveredLatitude.radians,
                    recoveredLongitude.radians,
                    false,
                    doublePoleSign(recoveredLatitude));

            const residual =
                hypot2(
                    projectedAgain.easting - projected.easting,
                    projectedAgain.northing - projected.northing);

            if (residual > 1.0e-7)
                throw new Exception(
                    format(
                        "analytic sphere oracle self-check failed for %s "
                        ~ "lat=%.12f dlon=%.12f residual=%.12g m",
                        source.name,
                        point.latitude,
                        point.deltaLongitude,
                        residual));
        }
    }
}


private void printMetrics(
    const string suite,
    const double targetMetres,
    const Metrics metrics)
{
    writeln;
    writefln("suite: %s", suite);
    writefln(
        "forward comparisons: %s",
        metrics.forwardComparisons);
    writefln(
        "reverse comparisons: %s",
        metrics.reverseComparisons);
    writefln(
        "outside %.12g m target: %s",
        targetMetres,
        metrics.failures);
    writefln(
        "worst absolute projected error: %.12g m",
        metrics.worstAbsoluteError);
    writefln(
        "worst absolute case: %s",
        metrics.worstAbsoluteLabel);
    writefln(
        "worst ground-equivalent error: %.12g m",
        metrics.worstGroundEquivalentError);
    writefln(
        "worst ground-equivalent case: %s",
        metrics.worstGroundEquivalentLabel);
    writefln(
        "RESULT: %s",
        metrics.failures == 0 ? "PASS" : "FAIL");
}


private void printFloatFailureDiagnostics(
    const FloatFailureDiagnostics diagnostics)
{
    writeln;
    writeln("float failure classification:");
    writefln(
        "forward / public pole: %s",
        diagnostics.forwardPublicPole);
    writefln(
        "forward / non-pole: %s",
        diagnostics.forwardNonPole);
    writefln(
        "reverse / public-pole source: %s",
        diagnostics.reversePublicPoleSource);
    writefln(
        "reverse / non-pole source: %s",
        diagnostics.reverseNonPoleSource);
    writefln(
        "  reverse non-pole rejected: %s",
        diagnostics.reverseNonPoleRejected);
    writefln(
        "  reverse non-pole residual > target: %s",
        diagnostics.reverseNonPoleResidual);
    writefln(
        "classified failures total: %s",
        diagnostics.forwardPublicPole
            + diagnostics.forwardNonPole
            + diagnostics.reversePublicPoleSource
            + diagnostics.reverseNonPoleSource);
}


private void runStructuredDouble()
{
    Metrics metrics = makeMetrics();
    size_t index;

    foreach (source; sourceSpecs())
    {
        const context = makeDoubleContext(source);

        foreach (latitudeIndex; -90 .. 91)
        {
            const double latitude =
                cast(double) latitudeIndex;

            foreach (deltaIndex; -100 .. 101)
            {
                const double deltaLongitude =
                    cast(double) deltaIndex * 0.6;

                validateDoublePoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics);
            }
        }

        foreach (latitude; [
            -89.999999, -89.999, -85.0, -80.0,
            -1.0e-9, -0.0, 0.0, 1.0e-9,
            80.0, 85.0, 89.999, 89.999999])
        {
            foreach (deltaLongitude; [
                -60.0, -59.999999, -3.0, -1.0e-9,
                0.0, 1.0e-9, 3.0, 59.999999, 60.0])
            {
                validateDoublePoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics);
            }
        }

        writefln(
            "completed %-36s %s source points",
            source.name ~ ":",
            index);
    }

    printMetrics(
        "large structured analytic spherical TM double corpus",
        doubleTargetMetres,
        metrics);

    if (metrics.failures != 0)
        throw new Exception("double spherical TM structured validation failed");
}


private void runStructuredFloat()
{
    Metrics metrics = makeMetrics();
    FloatFailureDiagnostics diagnostics = FloatFailureDiagnostics.init;
    size_t index;

    foreach (source; sourceSpecs())
    {
        const context = makeFloatContext(source);

        foreach (latitudeIndex; -90 .. 91)
        {
            const double latitude =
                cast(double) latitudeIndex;

            foreach (deltaIndex; -100 .. 101)
            {
                const double deltaLongitude =
                    cast(double) deltaIndex * 0.6;

                validateFloatPoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics,
                    diagnostics);
            }
        }

        foreach (latitude; [
            -89.999999, -89.999, -85.0, -80.0,
            -1.0e-9, -0.0, 0.0, 1.0e-9,
            80.0, 85.0, 89.999, 89.999999])
        {
            foreach (deltaLongitude; [
                -60.0, -59.999999, -3.0, -1.0e-9,
                0.0, 1.0e-9, 3.0, 59.999999, 60.0])
            {
                validateFloatPoint(
                    source,
                    context,
                    SourcePoint(
                        latitude,
                        deltaLongitude),
                    index++,
                    metrics,
                    diagnostics);
            }
        }

        writefln(
            "completed %-36s %s float source points",
            source.name ~ ":",
            index);
    }

    printFloatFailureDiagnostics(diagnostics);

    printMetrics(
        "large structured analytic spherical TM float corpus",
        floatTargetMetres,
        metrics);

    if (metrics.failures != 0)
        throw new Exception("float spherical TM structured validation failed");
}


private struct SplitMix64
{
    ulong state;

    ulong next()
    {
        state += 0x9E3779B97F4A7C15UL;

        ulong z = state;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }

    double unit()
    {
        return cast(double) (next() >> 11)
            * (1.0 / 9_007_199_254_740_992.0);
    }
}


private SourcePoint randomPoint(ref SplitMix64 rng)
{
    return SourcePoint(
        -90.0 + 180.0 * rng.unit(),
        -60.0 + 120.0 * rng.unit());
}


private void runRandomDouble(const size_t count)
{
    Metrics metrics = makeMetrics();
    auto rng = SplitMix64(randomCorpusSeed);
    const specs = sourceSpecs();

    DoubleContext[] contexts;
    contexts.reserve(specs.length);

    foreach (source; specs)
        contexts ~= makeDoubleContext(source);

    foreach (index; 0 .. count)
    {
        const profileIndex = index % specs.length;
        const source = specs[profileIndex];
        const context = contexts[profileIndex];

        validateDoublePoint(
            source,
            context,
            randomPoint(rng),
            index,
            metrics);
    }

    writefln(
        "deterministic sphere random corpus seed: 0x%016X",
        randomCorpusSeed);
    writefln("projection profiles: %s", specs.length);
    writefln("requested source points: %s", count);

    printMetrics(
        "deterministic pseudo-random analytic spherical TM double corpus",
        doubleTargetMetres,
        metrics);

    if (metrics.failures != 0)
        throw new Exception("double spherical TM random validation failed");
}


private void runRandomFloat(const size_t count)
{
    Metrics metrics = makeMetrics();
    FloatFailureDiagnostics diagnostics = FloatFailureDiagnostics.init;
    auto rng = SplitMix64(randomCorpusSeed);
    const specs = sourceSpecs();

    FloatContext[] contexts;
    contexts.reserve(specs.length);

    foreach (source; specs)
        contexts ~= makeFloatContext(source);

    foreach (index; 0 .. count)
    {
        const profileIndex = index % specs.length;
        const source = specs[profileIndex];
        const context = contexts[profileIndex];

        validateFloatPoint(
            source,
            context,
            randomPoint(rng),
            index,
            metrics,
            diagnostics);
    }

    writefln(
        "deterministic sphere random corpus seed: 0x%016X",
        randomCorpusSeed);
    writefln("projection profiles: %s", specs.length);
    writefln("requested float source points: %s", count);

    printFloatFailureDiagnostics(diagnostics);

    printMetrics(
        "deterministic pseudo-random analytic spherical TM float corpus",
        floatTargetMetres,
        metrics);

    if (metrics.failures != 0)
        throw new Exception("float spherical TM random validation failed");
}


private void usage()
{
    writeln(
        "usage: transverse_mercator_sphere_crosscheck "
        ~ "--structured");
    writeln(
        "   or: transverse_mercator_sphere_crosscheck "
        ~ "--random COUNT");
    writeln(
        "   or: transverse_mercator_sphere_crosscheck "
        ~ "--float-structured");
    writeln(
        "   or: transverse_mercator_sphere_crosscheck "
        ~ "--float-random COUNT");
}


int main(string[] args)
{
    validateOracleSelfConsistency();

    if (args.length == 2
        && args[1] == "--structured")
    {
        runStructuredDouble();
        return 0;
    }

    if (args.length == 3
        && args[1] == "--random")
    {
        const count = args[2].to!size_t;

        if (count == 0)
        {
            usage();
            return 2;
        }

        runRandomDouble(count);
        return 0;
    }

    if (args.length == 2
        && args[1] == "--float-structured")
    {
        runStructuredFloat();
        return 0;
    }

    if (args.length == 3
        && args[1] == "--float-random")
    {
        const count = args[2].to!size_t;

        if (count == 0)
        {
            usage();
            return 2;
        }

        runRandomFloat(count);
        return 0;
    }

    usage();
    return 2;
}
