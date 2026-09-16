/**
 * Deterministic Transverse Mercator reverse-domain boundary/property probe.
 *
 * Purpose:
 *   1. Every represented public +/-60 degree boundary point produced by
 *      geodesy-d forward() must be accepted by tryReverse().
 *   2. A represented projected point originating outside the documented
 *      longitude domain may be accepted only if, after tryReverse() clamps it
 *      to the boundary, the represented projected residual to that returned
 *      boundary point is within the public scalar accuracy budget.
 *
 * The outside projected points are generated independently with the analytic
 * spherical Transverse Mercator formulas.  This deliberately uses f = 0 to
 * isolate domain-classification semantics from ellipsoidal series error.
 *
 * This is a validation probe, not production code.
 */
module transverse_mercator_boundary_property;

import std.math : PI, asinh, atan2, cos, fabs, hypot, sin;
import std.stdio : writefln;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.projection.transverse_mercator : TransverseMercator;


private enum double radius = 6_371_000.0;
private enum double lon0Degrees = 15.0;

private immutable double[] latitudeDegrees = [
    80.0,
    85.0,
    88.0,
    89.0,
    89.9,
    89.99,
    89.999,
    89.9999,
    89.99999,
    89.999999,
];

private immutable double[] outsideDeltaDegrees = [
    60.000001,
    60.001,
    60.01,
    60.1,
    61.0,
    65.0,
];


private double accuracyBudget(T)() pure nothrow @safe @nogc
{
    static if (is(T == float))
        return 2.0;
    else
        return 0.001;
}


private ProjectedCoordinate!T sphericalOracleProjected(T)(
    const Latitude!T latitude,
    const double deltaLongitudeDegrees,
    const T k0)
{
    /*
     * Exact spherical TM with equatorial natural origin and zero false offsets:
     *
     *   q   = hypot(sin(phi), cos(phi) cos(lambda))
     *   xi  = atan2(sin(phi), cos(phi) cos(lambda))
     *   eta = asinh(cos(phi) sin(lambda) / q)
     *   E   = k0 R eta
     *   N   = k0 R xi
     *
     * The public T latitude is promoted so the independent oracle starts from
     * the same represented public latitude that reverse classification sees.
     */
    const double phi = cast(double) latitude.radians;
    const double lambda = deltaLongitudeDegrees * PI / 180.0;

    const double s = sin(phi);
    const double c = cos(phi);
    const double cl = cos(lambda);
    const double sl = sin(lambda);
    const double q = hypot(s, c * cl);

    const double xi = atan2(s, c * cl);
    const double eta = asinh(c * sl / q);

    const double representedRadius = cast(double) cast(T) radius;
    const double representedK0 = cast(double) k0;

    return ProjectedCoordinate!T.fromComponents(
        cast(T) (representedK0 * representedRadius * eta),
        cast(T) (representedK0 * representedRadius * xi));
}


private double projectedResidual(T)(
    const ProjectedCoordinate!T a,
    const ProjectedCoordinate!T b)
    pure nothrow @safe @nogc
{
    return hypot(
        cast(double) a.easting - cast(double) b.easting,
        cast(double) a.northing - cast(double) b.northing);
}


private struct Summary
{
    size_t boundaryCases;
    size_t boundaryRejected;
    size_t boundaryResidualFailures;

    size_t outsideCases;
    size_t outsideRejected;
    size_t outsideAcceptedWithinBudget;
    size_t outsideAcceptedBeyondBudget;

    size_t skippedPublicPoles;

    double worstBoundaryResidual = 0.0;
    string worstBoundaryCase;

    double worstAcceptedOutsideResidual = 0.0;
    string worstAcceptedOutsideCase;
}


private void updateWorst(
    ref double worst,
    ref string label,
    const double value,
    const string candidate)
{
    if (value > worst)
    {
        worst = value;
        label = candidate;
    }
}


private bool runScalar(T)(const T[] k0Values)
{
    Summary total;
    size_t detailedFailuresPrinted = 0;

    writefln("");
    writefln("=== %s reverse-domain boundary/property probe ===", T.stringof);
    writefln("public projected residual budget: %.12g m", accuracyBudget!T());

    foreach (const k0; k0Values)
    {
        const projection =
            TransverseMercator!T.fromParameters(
                Ellipsoid!T.fromFlattening(cast(T) radius, cast(T) 0),
                Latitude!T.fromDegrees(cast(T) 0),
                Longitude!T.fromDegrees(cast(T) lon0Degrees),
                k0,
                cast(T) 0,
                cast(T) 0);

        Summary local;

        foreach (const latitudeMagnitude; latitudeDegrees)
        {
            foreach (const latitudeSign; [-1.0, 1.0])
            {
                const nominalLatitude =
                    latitudeSign * latitudeMagnitude;

                const publicLatitude =
                    Latitude!T.fromDegrees(cast(T) nominalLatitude);

                /*
                 * Some decimal near-pole values round to the exact public pole
                 * for float. Longitude is degenerate there, so those cases are
                 * covered by the dedicated pole tests rather than this gate.
                 */
                if (fabs(cast(double) publicLatitude.degrees) >= 90.0)
                {
                    ++local.skippedPublicPoles;
                    continue;
                }

                foreach (const longitudeSign; [-1.0, 1.0])
                {
                    // --------------------------------------------------------
                    // Property 1: an actual represented +/-60 degree boundary
                    // produced by the public forward API must reverse.
                    // --------------------------------------------------------
                    const boundaryLongitudeDegrees =
                        lon0Degrees + longitudeSign * 60.0;

                    const boundaryGeographic =
                        GeographicCoordinate!T.fromComponents(
                            publicLatitude,
                            Longitude!T.fromDegrees(
                                cast(T) boundaryLongitudeDegrees));

                    ProjectedCoordinate!T boundaryProjected;
                    const bool boundaryForwardOk =
                        projection.tryForward(
                            boundaryGeographic,
                            boundaryProjected);

                    ++local.boundaryCases;

                    if (!boundaryForwardOk)
                    {
                        ++local.boundaryRejected;

                        if (detailedFailuresPrinted < 24)
                        {
                            writefln(
                                "BOUNDARY FORWARD REJECT: T=%s k0=%.17g "
                                ~ "latNom=%.9f latPublic=%.12f dlon=%+.6f",
                                T.stringof,
                                cast(double) k0,
                                nominalLatitude,
                                cast(double) publicLatitude.degrees,
                                longitudeSign * 60.0);
                            ++detailedFailuresPrinted;
                        }

                        continue;
                    }

                    GeographicCoordinate!T boundaryRecovered;
                    if (!projection.tryReverse(
                            boundaryProjected,
                            boundaryRecovered))
                    {
                        ++local.boundaryRejected;

                        if (detailedFailuresPrinted < 24)
                        {
                            writefln(
                                "BOUNDARY REVERSE REJECT: T=%s k0=%.17g "
                                ~ "latNom=%.9f latPublic=%.12f dlon=%+.6f "
                                ~ "E=%.12g N=%.12g",
                                T.stringof,
                                cast(double) k0,
                                nominalLatitude,
                                cast(double) publicLatitude.degrees,
                                longitudeSign * 60.0,
                                cast(double) boundaryProjected.easting,
                                cast(double) boundaryProjected.northing);
                            ++detailedFailuresPrinted;
                        }

                        continue;
                    }

                    const boundaryRoundTrip =
                        projection.forward(boundaryRecovered);
                    const boundaryResidual =
                        projectedResidual(
                            boundaryProjected,
                            boundaryRoundTrip);

                    if (boundaryResidual > local.worstBoundaryResidual)
                    {
                        local.worstBoundaryResidual = boundaryResidual;
                        local.worstBoundaryCase = "";
                    }

                    if (boundaryResidual > accuracyBudget!T())
                    {
                        ++local.boundaryResidualFailures;

                        if (detailedFailuresPrinted < 24)
                        {
                            writefln(
                                "BOUNDARY RESIDUAL > BUDGET: "
                                ~ "T=%s k0=%.17g latNom=%.9f "
                                ~ "latPublic=%.12f dlon=%+.6f "
                                ~ "residual=%.12g m budget=%.12g m",
                                T.stringof,
                                cast(double) k0,
                                nominalLatitude,
                                cast(double) publicLatitude.degrees,
                                longitudeSign * 60.0,
                                boundaryResidual,
                                accuracyBudget!T());
                            ++detailedFailuresPrinted;
                        }
                    }

                    // --------------------------------------------------------
                    // Property 2: independently generated outside points.
                    //
                    // If tryReverse() rejects: fine.
                    // If it accepts: it returns a clamped boundary coordinate.
                    // Forward that returned public coordinate and measure the
                    // represented E/N residual. Acceptance beyond the public
                    // budget is a false-positive domain classification.
                    // --------------------------------------------------------
                    foreach (const outsideMagnitude; outsideDeltaDegrees)
                    {
                        const outsideDelta =
                            longitudeSign * outsideMagnitude;

                        const outsideProjected =
                            sphericalOracleProjected!T(
                                publicLatitude,
                                outsideDelta,
                                k0);

                        ++local.outsideCases;

                        GeographicCoordinate!T recovered;
                        if (!projection.tryReverse(
                                outsideProjected,
                                recovered))
                        {
                            ++local.outsideRejected;
                            continue;
                        }

                        const clampedProjected =
                            projection.forward(recovered);
                        const residual =
                            projectedResidual(
                                outsideProjected,
                                clampedProjected);

                        if (residual > local.worstAcceptedOutsideResidual)
                        {
                            local.worstAcceptedOutsideResidual = residual;
                            local.worstAcceptedOutsideCase = "";
                        }

                        if (residual <= accuracyBudget!T())
                        {
                            ++local.outsideAcceptedWithinBudget;
                        }
                        else
                        {
                            ++local.outsideAcceptedBeyondBudget;

                            if (detailedFailuresPrinted < 24)
                            {
                                writefln(
                                    "OUTSIDE ACCEPTED BEYOND BUDGET: "
                                    ~ "T=%s k0=%.17g latNom=%.9f "
                                    ~ "latPublic=%.12f dlon=%+.9f "
                                    ~ "residual=%.12g m budget=%.12g m "
                                    ~ "recoveredLat=%.12f "
                                    ~ "recoveredLon=%.12f",
                                    T.stringof,
                                    cast(double) k0,
                                    nominalLatitude,
                                    cast(double) publicLatitude.degrees,
                                    outsideDelta,
                                    residual,
                                    accuracyBudget!T(),
                                    cast(double) recovered.latitude.degrees,
                                    cast(double) recovered.longitude.degrees);
                                ++detailedFailuresPrinted;
                            }
                        }
                    }
                }
            }
        }

        writefln("");
        writefln("T=%s k0=%.17g", T.stringof, cast(double) k0);
        writefln(
            "  boundary: cases=%s rejected=%s residual>bgt=%s worst=%.12g m",
            local.boundaryCases,
            local.boundaryRejected,
            local.boundaryResidualFailures,
            local.worstBoundaryResidual);
        writefln(
            "  outside: cases=%s rejected=%s accepted<=bgt=%s "
            ~ "accepted>bgt=%s worstAcceptedResidual=%.12g m",
            local.outsideCases,
            local.outsideRejected,
            local.outsideAcceptedWithinBudget,
            local.outsideAcceptedBeyondBudget,
            local.worstAcceptedOutsideResidual);
        writefln(
            "  skipped exact public poles: %s",
            local.skippedPublicPoles);

        total.boundaryCases += local.boundaryCases;
        total.boundaryRejected += local.boundaryRejected;
        total.boundaryResidualFailures += local.boundaryResidualFailures;
        total.outsideCases += local.outsideCases;
        total.outsideRejected += local.outsideRejected;
        total.outsideAcceptedWithinBudget += local.outsideAcceptedWithinBudget;
        total.outsideAcceptedBeyondBudget += local.outsideAcceptedBeyondBudget;
        total.skippedPublicPoles += local.skippedPublicPoles;

        if (local.worstBoundaryResidual > total.worstBoundaryResidual)
            total.worstBoundaryResidual = local.worstBoundaryResidual;

        if (local.worstAcceptedOutsideResidual
            > total.worstAcceptedOutsideResidual)
        {
            total.worstAcceptedOutsideResidual =
                local.worstAcceptedOutsideResidual;
        }
    }

    writefln("");
    writefln("summary %s:", T.stringof);
    writefln(
        "  boundary rejected: %s / %s",
        total.boundaryRejected,
        total.boundaryCases);
    writefln(
        "  boundary residual > budget: %s",
        total.boundaryResidualFailures);
    writefln(
        "  outside rejected: %s / %s",
        total.outsideRejected,
        total.outsideCases);
    writefln(
        "  outside accepted within budget: %s",
        total.outsideAcceptedWithinBudget);
    writefln(
        "  outside accepted beyond budget: %s",
        total.outsideAcceptedBeyondBudget);
    writefln(
        "  worst accepted outside residual: %.12g m",
        total.worstAcceptedOutsideResidual);

    const bool pass =
        total.boundaryRejected == 0
        && total.boundaryResidualFailures == 0
        && total.outsideAcceptedBeyondBudget == 0;

    writefln("RESULT %s: %s", T.stringof, pass ? "PASS" : "FAIL");
    return pass;
}


int main()
{
    const bool doublePass =
        runScalar!double([0.9, 1.0, 1.1]);

    const bool floatPass =
        runScalar!float([0.9f, 1.0f, 1.1f]);

    const bool pass = doublePass && floatPass;
    writefln("");
    writefln(
        "OVERALL RESULT: %s",
        pass ? "PASS" : "FAIL");

    return pass ? 0 : 1;
}
