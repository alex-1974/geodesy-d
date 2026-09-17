module utm_proj_crosscheck;

/*
 * UTM-C2 — represented-model numerical differential validation against PROJ.
 *
 * PROJ Transverse Mercator is an external validation oracle only. It is not a
 * geodesy-d build or runtime dependency.
 *
 * Coverage:
 *
 * - all 60 UTM zones;
 * - north and south false-northing conventions;
 * - WGS84, GRS80, International 1924 and Airy 1830;
 * - float, double and real public scalar paths;
 * - ordinary, neighboring-zone, cross-equator and wide-delta-longitude
 *   explicit-zone cases;
 * - forward differential comparison;
 * - reverse validation from independently generated PROJ coordinates.
 *
 * UTM-C1 owns zoning/policy semantics. This file owns numerical
 * compatibility of the prepared fixed-zone projection.
 */

import std.conv : to;
import std.format : format;
import std.math : PI, cos, isFinite, sqrt;
import std.process : executeShell;
import std.stdio : writefln, writeln;
import std.string : split, splitLines, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.utm :
    UtmHemisphere,
    UtmProjection,
    UtmZone;


private struct EllipsoidCase
{
    string name;
    double a;
    double inverseFlattening;
    string projParameters;
}


private struct GeographicCase
{
    double latitude;
    double deltaLongitude;
    string name;
}


private struct ProjPoint
{
    double easting;
    double northing;
}


private struct Metrics
{
    size_t forwardChecks;
    size_t reverseChecks;

    double worstForwardError = 0.0;
    string worstForwardLabel;

    double worstReverseError = 0.0;
    string worstReverseLabel;
}


private string scalarName(T)()
{
    static if (is(T == float))
        return "float";
    else static if (is(T == double))
        return "double";
    else static if (is(T == real))
        return "real";
    else
        return T.stringof;
}


private double forwardTolerance(T)()
{
    static if (is(T == float))
        return 2.0;
    else
        return 1.0e-3;
}


private double reverseTolerance(T)()
{
    /*
     * Reverse begins with a PROJ double projected coordinate represented
     * in public scalar T. For float this input quantization alone can be
     * about one metre at UTM northing magnitudes, so use the established
     * two-operation 4 m envelope.
     */
    static if (is(T == float))
        return 4.0;
    else
        return 2.0e-3;
}


private double normalizeLongitudeDegrees(double longitude)
{
    while (longitude < -180.0)
        longitude += 360.0;

    while (longitude >= 180.0)
        longitude -= 360.0;

    return longitude;
}


private double longitudeDifferenceRadians(
    const double firstDegrees,
    const double secondDegrees)
{
    double delta =
        firstDegrees - secondDegrees;

    while (delta < -180.0)
        delta += 360.0;

    while (delta >= 180.0)
        delta -= 360.0;

    return delta * PI / 180.0;
}


private string representedProjOperation(T)(
    const EllipsoidCase ellipsoidCase,
    const int zoneNumber,
    const UtmHemisphere hemisphere)
{
    /*
     * Match the mathematical model actually represented by the public
     * scalar T.
     *
     * UtmProjection!T is a fixed Transverse Mercator specialization.
     * For float in particular, the ellipsoid parameters, central
     * meridian and scale factor are represented in float before the
     * projection is evaluated. Feeding canonical double UTM constants to
     * PROJ would therefore compare two slightly different mathematical
     * models rather than two implementations of the same model.
     */
    const ellipsoid =
        ellipsoidFor!T(
            ellipsoidCase);

    const centralMeridian =
        Longitude!T.fromDegrees(
            cast(T)
            (6.0 * zoneNumber - 183.0));

    const centralMeridianDegrees =
        degreesFromRepresentedRadians(
            centralMeridian.radians);

    const scaleFactor =
        cast(double)
        cast(T) 0.9996;

    const falseEasting =
        cast(double)
        cast(T) 500_000.0;

    const falseNorthing =
        hemisphere == UtmHemisphere.south
            ? cast(double) cast(T) 10_000_000.0
            : 0.0;

    const semiMajorAxis =
        cast(double)
        ellipsoid.semiMajorAxis;

    const flattening =
        cast(double)
        ellipsoid.flattening;

    return format(
        "+proj=pipeline "
        ~ "+step +proj=unitconvert +xy_in=deg +xy_out=rad "
        ~ "+step +proj=tmerc +algo=poder_engsager "
        ~ "+lat_0=0 "
        ~ "+lon_0=%.17g "
        ~ "+k_0=%.17g "
        ~ "+x_0=%.17g "
        ~ "+y_0=%.17g "
        ~ "+a=%.17g "
        ~ "+f=%.17g",
        centralMeridianDegrees,
        scaleFactor,
        falseEasting,
        falseNorthing,
        semiMajorAxis,
        flattening);
}


private ProjPoint[] runProjBatch(
    const string operation,
    const double[] longitudes,
    const double[] latitudes)
{
    if (longitudes.length != latitudes.length)
        throw new Exception(
            "internal error: PROJ batch coordinate lengths differ");

    string input;

    foreach (index; 0 .. longitudes.length)
    {
        input ~= format(
            "%.17g %.17g 0 0\n",
            longitudes[index],
            latitudes[index]);
    }

    /*
     * Input contains only generated numeric text, so single-quoting it for
     * printf is deterministic and shell-safe.
     */
    const command =
        format(
            "printf '%%s' '%s' | cct -d 12 %s",
            input,
            operation);

    const output =
        executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "PROJ cct failed (status %s):\n%s\n%s",
                output.status,
                command,
                output.output));

    const text =
        output.output.strip;

    if (text.length == 0)
        throw new Exception(
            "PROJ cct returned empty output");

    const lines =
        text.splitLines;

    if (lines.length != longitudes.length)
        throw new Exception(
            format(
                "PROJ output line count mismatch: expected %s got %s\n%s",
                longitudes.length,
                lines.length,
                output.output));

    ProjPoint[] result;
    result.length = lines.length;

    foreach (index, line; lines)
    {
        const fields =
            line.strip.split;

        if (fields.length < 2)
            throw new Exception(
                "unexpected PROJ output line: " ~ line);

        result[index] =
            ProjPoint(
                fields[0].to!double,
                fields[1].to!double);

        if (!isFinite(result[index].easting)
            || !isFinite(result[index].northing))
            throw new Exception(
                "non-finite PROJ reference coordinate: " ~ line);
    }

    return result;
}


private Ellipsoid!T ellipsoidFor(T)(
    const EllipsoidCase test)
{
    return Ellipsoid!T.fromInverseFlattening(
        cast(T) test.a,
        cast(T) test.inverseFlattening);
}


private GeographicCoordinate!T sourceFor(T)(
    const double latitude,
    const double longitude)
{
    return GeographicCoordinate!T.fromComponents(
        Latitude!T.fromDegrees(
            cast(T) latitude),
        Longitude!T.fromDegrees(
            cast(T) longitude));
}


private double degreesFromRepresentedRadians(T)(
    const T radians)
{
    /*
     * The public angular types store radians in scalar T. The TM kernel
     * promotes those stored radians directly to its working scalar.
     *
     * Therefore the external oracle must interpret exactly those stored
     * radians. Calling `.degrees` here would perform radians->degrees in T
     * and introduce an additional float rounding step which the production
     * projection never sees.
     */
    return cast(double) radians
        * (180.0 / cast(double) PI);
}


private double representedLatitudeDegrees(T)(
    const double latitude)
{
    const source =
        Latitude!T.fromDegrees(
            cast(T) latitude);

    return degreesFromRepresentedRadians(
        source.radians);
}


private double representedLongitudeDegrees(T)(
    const double longitude)
{
    const source =
        Longitude!T.fromDegrees(
            cast(T) longitude);

    return degreesFromRepresentedRadians(
        source.radians);
}


private void updateForward(
    T)(
    const string label,
    const double error,
    ref Metrics metrics)
{
    if (!isFinite(error))
        throw new Exception(
            label ~ " forward produced non-finite error");

    ++metrics.forwardChecks;

    if (error > metrics.worstForwardError)
    {
        metrics.worstForwardError = error;
        metrics.worstForwardLabel = label;
    }

    const tolerance =
        forwardTolerance!T();

    if (error > tolerance)
        throw new Exception(
            format(
                "%s forward error %.17g m exceeds %.17g m",
                label,
                error,
                tolerance));
}


private void updateReverse(
    T)(
    const string label,
    const double error,
    ref Metrics metrics)
{
    if (!isFinite(error))
        throw new Exception(
            label ~ " reverse produced non-finite error");

    ++metrics.reverseChecks;

    if (error > metrics.worstReverseError)
    {
        metrics.worstReverseError = error;
        metrics.worstReverseLabel = label;
    }

    const tolerance =
        reverseTolerance!T();

    if (error > tolerance)
        throw new Exception(
            format(
                "%s reverse ground residual %.17g m exceeds %.17g m",
                label,
                error,
                tolerance));
}


private void validateScalarPoint(
    T)(
    const EllipsoidCase ellipsoidCase,
    const int zoneNumber,
    const UtmHemisphere hemisphere,
    const double nominalLatitude,
    const double nominalLongitude,
    const ProjPoint reference,
    ref Metrics metrics)
{
    const ellipsoid =
        ellipsoidFor!T(
            ellipsoidCase);

    const zone =
        UtmZone.fromNumber(
            zoneNumber);

    const projection =
        UtmProjection!T.fromZone(
            ellipsoid,
            zone,
            hemisphere);

    const source =
        sourceFor!T(
            nominalLatitude,
            nominalLongitude);

    ProjectedCoordinate!T oursForward;

    if (!projection.tryForward(
            source,
            oursForward))
        throw new Exception(
            format(
                "%s zone=%s hemisphere=%s lat=%.17g lon=%.17g "
                ~ "geodesy-d forward rejected reference-domain point",
                scalarName!T,
                zoneNumber,
                hemisphere,
                nominalLatitude,
                nominalLongitude));

    const double deltaEasting =
        cast(double) oursForward.easting
        - reference.easting;

    const double deltaNorthing =
        cast(double) oursForward.northing
        - reference.northing;

    const double forwardError =
        sqrt(
            deltaEasting * deltaEasting
            + deltaNorthing * deltaNorthing);

    const label =
        format(
            "%s %s zone=%s hemisphere=%s lat=%.9g lon=%.9g",
            scalarName!T,
            ellipsoidCase.name,
            zoneNumber,
            hemisphere,
            nominalLatitude,
            nominalLongitude);

    updateForward!T(
        label,
        forwardError,
        metrics);

    /*
     * Reverse differential:
     *
     * PROJ independently generated reference E/N. Represent that
     * coordinate in public scalar T and reverse it with geodesy-d.
     * Compare with the represented geographic source, not with a
     * geodesy-d self-forward result.
     */
    const reverseSource =
        ProjectedCoordinate!T.fromComponents(
            cast(T) reference.easting,
            cast(T) reference.northing);

    GeographicCoordinate!T recovered;

    if (!projection.tryReverse(
            reverseSource,
            recovered))
        throw new Exception(
            label
            ~ " geodesy-d reverse rejected PROJ coordinate");

    const double sourceLatitudeRadians =
        cast(double) source.latitude.radians;

    const double recoveredLatitudeRadians =
        cast(double) recovered.latitude.radians;

    const double deltaLatitude =
        recoveredLatitudeRadians
        - sourceLatitudeRadians;

    const double sourceLongitudeDegrees =
        cast(double) source.longitude.degrees;

    const double recoveredLongitudeDegrees =
        cast(double) recovered.longitude.degrees;

    const double deltaLongitude =
        longitudeDifferenceRadians(
            recoveredLongitudeDegrees,
            sourceLongitudeDegrees);

    const double horizontalLongitude =
        cos(sourceLatitudeRadians)
        * deltaLongitude;

    const double a =
        cast(double) ellipsoidCase.a;

    const double reverseGroundResidual =
        a
        * sqrt(
            deltaLatitude * deltaLatitude
            + horizontalLongitude * horizontalLongitude);

    updateReverse!T(
        label,
        reverseGroundResidual,
        metrics);
}


private void validateScalarConfiguration(T)(
    const EllipsoidCase ellipsoidCase,
    const int zoneNumber,
    const UtmHemisphere hemisphere,
    const GeographicCase[] cases,
    ref Metrics metrics)
{
    const double centralMeridian =
        6.0 * zoneNumber - 183.0;

    double[] nominalLatitudes;
    double[] nominalLongitudes;

    double[] referenceLatitudes;
    double[] referenceLongitudes;

    foreach (test; cases)
    {
        const nominalLatitude =
            test.latitude;

        const nominalLongitude =
            normalizeLongitudeDegrees(
                centralMeridian
                + test.deltaLongitude);

        nominalLatitudes ~=
            nominalLatitude;

        nominalLongitudes ~=
            nominalLongitude;

        /*
         * PROJ receives the geographic coordinate represented by the
         * same public scalar T used by geodesy-d.
         */
        referenceLatitudes ~=
            representedLatitudeDegrees!T(
                nominalLatitude);

        referenceLongitudes ~=
            representedLongitudeDegrees!T(
                nominalLongitude);
    }

    const operation =
        representedProjOperation!T(
            ellipsoidCase,
            zoneNumber,
            hemisphere);

    const references =
        runProjBatch(
            operation,
            referenceLongitudes,
            referenceLatitudes);

    foreach (index; 0 .. cases.length)
    {
        validateScalarPoint!T(
            ellipsoidCase,
            zoneNumber,
            hemisphere,
            nominalLatitudes[index],
            nominalLongitudes[index],
            references[index],
            metrics);
    }
}


private void validateConfiguration(
    const EllipsoidCase ellipsoidCase,
    const int zoneNumber,
    const UtmHemisphere hemisphere,
    const GeographicCase[] cases,
    ref Metrics floatMetrics,
    ref Metrics doubleMetrics,
    ref Metrics realMetrics)
{
    validateScalarConfiguration!float(
        ellipsoidCase,
        zoneNumber,
        hemisphere,
        cases,
        floatMetrics);

    validateScalarConfiguration!double(
        ellipsoidCase,
        zoneNumber,
        hemisphere,
        cases,
        doubleMetrics);

    validateScalarConfiguration!real(
        ellipsoidCase,
        zoneNumber,
        hemisphere,
        cases,
        realMetrics);
}


private void printMetrics(
    T)(
    const Metrics metrics)
{
    writefln(
        "%s: forward=%s reverse=%s",
        scalarName!T,
        metrics.forwardChecks,
        metrics.reverseChecks);

    writefln(
        "  worst forward=%.9g m (%s / %.9g m tolerance)",
        metrics.worstForwardError,
        metrics.worstForwardLabel,
        forwardTolerance!T());

    writefln(
        "  worst reverse=%.9g m (%s / %.9g m tolerance)",
        metrics.worstReverseError,
        metrics.worstReverseLabel,
        reverseTolerance!T());
}


void main()
{
    const versionOutput =
        executeShell("cct --version");

    if (versionOutput.status != 0)
        throw new Exception(
            "cct --version failed");

    writefln(
        "UTM-C2 PROJ represented-model differential validation");
    writeln(
        "=============================================");
    writefln(
        "PROJ reference: %s",
        versionOutput.output.strip);

    const ellipsoids = [
        EllipsoidCase(
            "WGS84",
            6_378_137.0,
            298.257223563,
            "+ellps=WGS84"),

        EllipsoidCase(
            "GRS80",
            6_378_137.0,
            298.257222101,
            "+ellps=GRS80"),

        EllipsoidCase(
            "International1924",
            6_378_388.0,
            297.0,
            "+ellps=intl"),

        EllipsoidCase(
            "Airy1830",
            6_377_563.396,
            299.3249646,
            "+ellps=airy"),
    ];

    /*
     * These are explicit-zone cases. They deliberately include points
     * outside the automatic standard UTM latitude band and well outside
     * the ordinary 6 degree zone width.
     *
     * ±55 degrees remains comfortably inside geodesy-d's bounded
     * ±60-degree generic TM contract while avoiding a represented exact
     * boundary classification issue.
     */
    const cases = [
        GeographicCase(  0.0,   0.0, "equator center"),
        GeographicCase( 48.0,   3.0, "north ordinary"),
        GeographicCase(-48.0,  -3.0, "south ordinary"),
        GeographicCase( 83.0,   3.0, "north standard high"),
        GeographicCase(-79.0,  -3.0, "south standard high"),
        GeographicCase( 85.0,   9.0, "north explicit outside standard"),
        GeographicCase(-85.0,  -9.0, "south explicit outside standard"),
        GeographicCase( 45.0,  35.0, "positive neighboring wide"),
        GeographicCase(-45.0, -35.0, "negative neighboring wide"),
        GeographicCase( 80.0,  55.0, "positive wide domain"),
        GeographicCase(-80.0, -55.0, "negative wide domain"),
    ];

    Metrics floatMetrics;
    Metrics doubleMetrics;
    Metrics realMetrics;

    size_t configurations;

    foreach (ellipsoidCase; ellipsoids)
    {
        foreach (zoneNumber; 1 .. 61)
        {
            foreach (hemisphere;
                [
                    UtmHemisphere.north,
                    UtmHemisphere.south,
                ])
            {
                validateConfiguration(
                    ellipsoidCase,
                    zoneNumber,
                    hemisphere,
                    cases,
                    floatMetrics,
                    doubleMetrics,
                    realMetrics);

                ++configurations;
            }
        }
    }

    writeln;
    writefln(
        "configurations=%s",
        configurations);

    writefln(
        "nominal geographic cases/configuration=%s",
        cases.length);

    writeln;

    printMetrics!float(
        floatMetrics);

    printMetrics!double(
        doubleMetrics);

    printMetrics!real(
        realMetrics);

    writeln;
    writeln("RESULT: UTM-C2 PASS");
}
