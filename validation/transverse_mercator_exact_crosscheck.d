/**
 * Differential validation of geodesy-d Transverse Mercator against
 * GeographicLib TransverseMercatorExact via the TransverseMercatorProj tool.
 *
 * This file is not part of the library source tree. GeographicLib is an
 * external validation oracle only and remains no geodesy-d dependency.
 */
module transverse_mercator_exact_crosscheck;

import std.conv : to;
import std.format : format;
import std.math : isFinite, sqrt;
import std.process : executeShell;
import std.stdio : writefln, writeln;
import std.string : split, strip;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid, wgs84;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private struct ExactPoint
{
    double easting;
    double northing;
}


private struct ProjectionSpec
{
    string name;
    Ellipsoid!double ellipsoid;
    double latitudeOfNaturalOrigin;
    double longitudeOfNaturalOrigin;
    double scaleFactorAtNaturalOrigin;
    double falseEasting;
    double falseNorthing;
}


private struct Metrics
{
    size_t checks;
    size_t failures;
    double worstNormalizedError;
    double worstAbsoluteError;
    string worstLabel;
}


private ExactPoint runExactCoreForward(
    const ProjectionSpec spec,
    const double latitudeDegrees,
    const double longitudeDegrees)
{
    /*
     * TransverseMercatorProj uses TransverseMercatorExact by default.
     * Its natural-origin latitude is the equator; EPSG 9807 lat0 is handled
     * below by subtracting the exact northing of (lat0, lon0).
     *
     * GeographicLib's DMS angle parser does not accept exponential notation:
     * the letter E is an east-hemisphere designator.  Geographic coordinates
     * are therefore emitted in fixed decimal form instead of `%g`; this is
     * essential for reverse results extremely close to zero latitude.
     *
     * -p 12 gives picometre-format decimal output; actual algorithmic
     * accuracy is of course limited by binary64 roundoff.
     */
    const command = format(
        "printf '%%s %%s\\n' '%.17f' '%.17f' | "
        ~ "TransverseMercatorProj "
        ~ "-l '%.17g' -k '%.17g' -e '%.17g' '%.17g' -p 12",
        latitudeDegrees,
        longitudeDegrees,
        spec.longitudeOfNaturalOrigin,
        spec.scaleFactorAtNaturalOrigin,
        spec.ellipsoid.semiMajorAxis,
        spec.ellipsoid.flattening);

    const output = executeShell(command);

    if (output.status != 0)
        throw new Exception(
            format(
                "TransverseMercatorProj failed (status %s): %s\\n%s",
                output.status,
                command,
                output.output));

    const fields = output.output.strip.split;
    if (fields.length < 2)
        throw new Exception(
            "unexpected TransverseMercatorProj output: "
            ~ output.output);

    if (fields[0].length >= 6 && fields[0][0 .. 6] == "ERROR:")
        throw new Exception(output.output.strip);

    try
    {
        return ExactPoint(
            fields[0].to!double,
            fields[1].to!double);
    }
    catch (Exception error)
    {
        throw new Exception(
            format(
                "non-numeric GeographicLib output for command:\\n%s\\n"
                ~ "output:\\n%s",
                command,
                output.output));
    }
}


private ExactPoint exactProjected(
    const ProjectionSpec spec,
    const ExactPoint exactOrigin,
    const double latitudeDegrees,
    const double longitudeDegrees)
{
    const core = runExactCoreForward(
        spec,
        latitudeDegrees,
        longitudeDegrees);

    return ExactPoint(
        spec.falseEasting + core.easting,
        spec.falseNorthing
            + core.northing
            - exactOrigin.northing);
}


private void recordProjectedComparison(
    const string label,
    const double actualEasting,
    const double actualNorthing,
    const ExactPoint reference,
    const double tolerance,
    ref Metrics metrics)
{
    if (!isFinite(actualEasting)
        || !isFinite(actualNorthing)
        || !isFinite(reference.easting)
        || !isFinite(reference.northing))
        throw new Exception(
            label ~ ": non-finite projected comparison value");

    const double deltaEasting =
        actualEasting - reference.easting;
    const double deltaNorthing =
        actualNorthing - reference.northing;
    const double error =
        sqrt(deltaEasting * deltaEasting
            + deltaNorthing * deltaNorthing);
    const double normalized =
        tolerance > 0.0 ? error / tolerance : error;

    ++metrics.checks;

    if (normalized > metrics.worstNormalizedError)
    {
        metrics.worstNormalizedError = normalized;
        metrics.worstAbsoluteError = error;
        metrics.worstLabel = label;
    }

    if (error > tolerance)
    {
        ++metrics.failures;

        // Keep output useful for large matrices without flooding the terminal.
        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s: dE=%.17g dN=%.17g "
                ~ "positionError=%.17g m (%.6f x tolerance)",
                label,
                deltaEasting,
                deltaNorthing,
                error,
                normalized);
    }
}


private void validatePoint(
    const ProjectionSpec spec,
    const ExactPoint exactOrigin,
    const TransverseMercator!double projection,
    const double latitudeDegrees,
    const double longitudeDegrees,
    const double tolerance,
    ref Metrics metrics)
{
    const label = format(
        "%s lat=%.12g lon=%.12g",
        spec.name,
        latitudeDegrees,
        longitudeDegrees);

    const geographic =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(latitudeDegrees),
            Longitude!double.fromDegrees(longitudeDegrees));

    const exactForward =
        exactProjected(
            spec,
            exactOrigin,
            latitudeDegrees,
            longitudeDegrees);

    const oursForward = projection.forward(geographic);

    recordProjectedComparison(
        label ~ " forward",
        oursForward.easting,
        oursForward.northing,
        exactForward,
        tolerance,
        metrics);

    /*
     * Independent reverse metric:
     *
     * 1. GeographicLib Exact creates the projected input.
     * 2. geodesy-d reverses that exact coordinate.
     * 3. GeographicLib Exact projects geodesy-d's recovered geographic value.
     * 4. Compare represented projected positions.
     *
     * geodesy-d's own forward path is not used here.
     */
    GeographicCoordinate!double oursReverse;
    if (!projection.tryReverse(
            ProjectedCoordinate!double.fromComponents(
                exactForward.easting,
                exactForward.northing),
            oursReverse))
    {
        ++metrics.checks;
        ++metrics.failures;

        if (metrics.failures <= 12)
            writefln(
                "OUTSIDE TARGET: %s reverse rejected exact input "
                ~ "E=%.17g N=%.17g",
                label,
                exactForward.easting,
                exactForward.northing);

        return;
    }

    const representedByExact =
        exactProjected(
            spec,
            exactOrigin,
            oursReverse.latitude.degrees,
            oursReverse.longitude.degrees);

    const double reverseDeltaE =
        representedByExact.easting - exactForward.easting;
    const double reverseDeltaN =
        representedByExact.northing - exactForward.northing;
    const double reverseExactError =
        sqrt(reverseDeltaE * reverseDeltaE
            + reverseDeltaN * reverseDeltaN);

    if (reverseExactError > tolerance)
    {
        const selfForward = projection.forward(oursReverse);
        const double selfDeltaE =
            selfForward.easting - exactForward.easting;
        const double selfDeltaN =
            selfForward.northing - exactForward.northing;
        const double selfResidual =
            sqrt(selfDeltaE * selfDeltaE
                + selfDeltaN * selfDeltaN);

        writefln(
            "REVERSE DIAGNOSTIC: %s; recovered lat=%.17g lon=%.17g "
            ~ "deltaLon=%.17g deg; "
            ~ "geodesy-forward residual to Exact input=%.17g m",
            label,
            oursReverse.latitude.degrees,
            oursReverse.longitude.degrees,
            oursReverse.longitude.degrees
                - spec.longitudeOfNaturalOrigin,
            selfResidual);
    }

    recordProjectedComparison(
        label ~ " reverse represented position",
        representedByExact.easting,
        representedByExact.northing,
        exactForward,
        tolerance,
        metrics);
}


private TransverseMercator!double makeProjection(
    const ProjectionSpec spec)
{
    return TransverseMercator!double.fromParameters(
        spec.ellipsoid,
        Latitude!double.fromDegrees(
            spec.latitudeOfNaturalOrigin),
        Longitude!double.fromDegrees(
            spec.longitudeOfNaturalOrigin),
        spec.scaleFactorAtNaturalOrigin,
        spec.falseEasting,
        spec.falseNorthing);
}


private ExactPoint makeExactOrigin(
    const ProjectionSpec spec)
{
    return runExactCoreForward(
        spec,
        spec.latitudeOfNaturalOrigin,
        spec.longitudeOfNaturalOrigin);
}


private void validateSmoke(ref Metrics metrics)
{
    const ProjectionSpec wgs = ProjectionSpec(
        "WGS84",
        wgs84!double(),
        0.0,
        15.0,
        0.9996,
        500_000.0,
        0.0);

    const wgsProjection = makeProjection(wgs);
    const wgsOrigin = makeExactOrigin(wgs);

    const double[2][] wgsCases = [
        [  0.0,  15.0],
        [  0.0,  12.0],
        [ 45.0,  18.0],
        [ 45.0,  50.0],  // +35 deg
        [ 80.0,  70.0],  // +55 deg
        [ 45.0,  75.0],  // +60 deg
        [-45.0, -45.0],  // -60 deg
    ];

    foreach (test; wgsCases)
        validatePoint(
            wgs,
            wgsOrigin,
            wgsProjection,
            test[0],
            test[1],
            1.0e-3,
            metrics);

    const ProjectionSpec airy = ProjectionSpec(
        "Airy1830 non-zero lat0",
        Ellipsoid!double.fromInverseFlattening(
            6_377_563.396,
            299.3249646),
        49.0,
        -2.0,
        0.9996012717,
        400_000.0,
        -100_000.0);

    validatePoint(
        airy,
        makeExactOrigin(airy),
        makeProjection(airy),
        50.5,
        0.5,
        1.0e-3,
        metrics);

    const ProjectionSpec antimeridian = ProjectionSpec(
        "WGS84 antimeridian",
        wgs84!double(),
        0.0,
        179.75,
        1.0,
        0.0,
        0.0);

    validatePoint(
        antimeridian,
        makeExactOrigin(antimeridian),
        makeProjection(antimeridian),
        20.0,
        -179.75,
        1.0e-3,
        metrics);

    /*
     * Critical ADR-0006 stress profile.  This is the point family which
     * separates a genuine geodesy-d inverse defect from the common limitations
     * of two different sixth-order series implementations.
     */
    const ProjectionSpec synthetic = ProjectionSpec(
        "Synthetic f=0.01",
        Ellipsoid!double.fromFlattening(
            6_378_137.0,
            0.01),
        49.0,
        15.0,
        0.9996,
        500_000.0,
        0.0);

    const syntheticProjection = makeProjection(synthetic);
    const syntheticOrigin = makeExactOrigin(synthetic);

    const double[2][] stressCases = [
        [-45.0, -45.0],
        [ -1.0, -45.0], // PROJ differential reverse worst case found so far
        [  0.0, -45.0],
        [  1.0, -45.0],
        [ 45.0, -45.0],
        [ -1.0,  75.0],
        [  0.0,  75.0],
        [  1.0,  75.0],
    ];

    foreach (test; stressCases)
        validatePoint(
            synthetic,
            syntheticOrigin,
            syntheticProjection,
            test[0],
            test[1],
            1.0e-3,
            metrics);
}


private void validateExtended(ref Metrics metrics)
{
    const ProjectionSpec[] specs = [
        ProjectionSpec(
            "WGS84",
            wgs84!double(),
            0.0, 15.0, 1.0, 0.0, 0.0),
        ProjectionSpec(
            "GRS80",
            Ellipsoid!double.fromInverseFlattening(
                6_378_137.0,
                298.257222101),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),
        ProjectionSpec(
            "Airy1830",
            Ellipsoid!double.fromInverseFlattening(
                6_377_563.396,
                299.3249646),
            -35.0, 15.0, 0.9999, -2_000_000.0, 3_000_000.0),
        ProjectionSpec(
            "Bessel1841",
            Ellipsoid!double.fromInverseFlattening(
                6_377_397.155,
                299.1528128),
            0.0, 15.0, 1.0, 0.0, 0.0),
        ProjectionSpec(
            "Clarke1866",
            Ellipsoid!double.fromAxes(
                6_378_206.4,
                6_356_583.8),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),
        ProjectionSpec(
            "International1924",
            Ellipsoid!double.fromInverseFlattening(
                6_378_388.0,
                297.0),
            -35.0, 15.0, 0.9999, -2_000_000.0, 3_000_000.0),
        ProjectionSpec(
            "Synthetic f=0.01",
            Ellipsoid!double.fromFlattening(
                6_378_137.0,
                0.01),
            49.0, 15.0, 0.9996, 500_000.0, 0.0),
    ];

    const double[] latitudes = [
        -85.0,
        -80.0,
        -45.0,
        -1.0,
        0.0,
        1.0,
        45.0,
        80.0,
        85.0,
    ];

    const double[] deltaLongitudes = [
        -60.0,
        -55.0,
        -35.0,
        -3.0,
        0.0,
        3.0,
        35.0,
        55.0,
        60.0,
    ];

    foreach (spec; specs)
    {
        const projection = makeProjection(spec);
        const exactOrigin = makeExactOrigin(spec);

        foreach (latitude; latitudes)
        {
            foreach (deltaLongitude; deltaLongitudes)
            {
                validatePoint(
                    spec,
                    exactOrigin,
                    projection,
                    latitude,
                    spec.longitudeOfNaturalOrigin + deltaLongitude,
                    1.0e-3,
                    metrics);
            }
        }
    }
}


int main(string[] args)
{
    bool extended = false;

    if (args.length == 2 && args[1] == "--extended")
        extended = true;
    else if (args.length != 1)
    {
        writeln(
            "usage: transverse-mercator-exact-crosscheck [--extended]");
        return 2;
    }

    const versionOutput =
        executeShell("TransverseMercatorProj --version");

    if (versionOutput.status != 0)
    {
        writeln(
            "FAIL: TransverseMercatorProj --version failed");
        return 2;
    }

    writefln(
        "GeographicLib exact reference: %s",
        versionOutput.output.strip);

    Metrics metrics = Metrics(0, 0, 0.0, 0.0, "");

    try
    {
        validateSmoke(metrics);

        if (extended)
            validateExtended(metrics);
    }
    catch (Exception error)
    {
        writefln(
            "FAIL: validation infrastructure/reference error: %s",
            error.msg);
        return 2;
    }

    writefln(
        "suite: %s",
        extended
            ? "extended GeographicLib Exact EPSG9807 suite"
            : "GeographicLib Exact EPSG9807 smoke/stress suite");

    writefln(
        "comparisons: %s",
        metrics.checks);

    writefln(
        "outside 1 mm target: %s",
        metrics.failures);

    writefln(
        "worst absolute projected error: %.12g m",
        metrics.worstAbsoluteError);

    writefln(
        "worst normalized error: %.6f of 1 mm target",
        metrics.worstNormalizedError);

    writefln(
        "worst case: %s",
        metrics.worstLabel);

    if (metrics.failures != 0)
    {
        writeln("RESULT: FAIL");
        return 1;
    }

    writeln("RESULT: PASS");
    return 0;
}
