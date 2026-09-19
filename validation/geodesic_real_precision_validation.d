module geodesic_real_precision_validation;

/*
 * GEO-G D `real` precision-preservation gate.
 *
 * On targets where real is wider than double, prove that the public real path
 * preserves distinctions which collapse at the binary64 boundary. Direct and
 * inverse probes deliberately exercise the non-spherical ellipsoidal kernels.
 */

import std.math : fabs;
import std.stdio :
    writefln,
    writeln;

import geodesy.angle :
    Angle,
    Latitude,
    Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.geodesic :
    Geodesic,
    GeodesicDirectResult,
    GeodesicInverseResult;
import geodesy.geographic : GeographicCoordinate;


private ulong binary64Bits(
    const real value)
{
    /*
     * D permits excess floating-point precision and may optimize a plain
     * cast-and-compare without forcing binary64 storage.  Writing the cast
     * value into the double member of a union and reading its ulong member
     * compares the actual 8-byte object representation instead.
     */
    union DoubleBits
    {
        double value;
        ulong bits;
    }

    DoubleBits represented;
    represented.value = cast(double) value;
    return represented.bits;
}


private GeographicCoordinate!real pointRadians(
    const real latitude,
    const real longitude)
{
    return GeographicCoordinate!real.fromComponents(
        Latitude!real.fromRadians(latitude),
        Longitude!real.fromRadians(longitude));
}


void main()
{
    writeln("GEO-G geodesic real precision preservation");

    writefln("double.sizeof=%s", double.sizeof);
    writefln("double.mant_dig=%s", double.mant_dig);
    writefln("real.sizeof=%s", real.sizeof);
    writefln("real.alignof=%s", real.alignof);
    writefln("real.mant_dig=%s", real.mant_dig);

    if (real.mant_dig <= double.mant_dig)
    {
        writeln(
            "RESULT: PASS (real has no precision beyond double on this target)");
        return;
    }

    const solver =
        Geodesic!real.fromEllipsoid(
            Ellipsoid!real.fromFlattening(
                6_378_137.0L,
                1.0L / 298.257223563L));

    /*
     * Direct: the distances differ in real but collapse to one double.
     * The non-equatorial, non-meridional path exercises the ellipsoidal direct
     * series rather than a sphere/cardinal shortcut.
     */
    const real directDistanceA =
        1_000_000.0L;

    const real directPerturbation =
        0x1p-40L;

    const real directDistanceB =
        directDistanceA
        + directPerturbation;

    const bool directCollapsesToDouble =
        binary64Bits(directDistanceA)
        == binary64Bits(directDistanceB);

    const directStart =
        pointRadians(
            0.31L,
            -0.47L);

    const directAzimuth =
        Angle!real.fromRadians(
            0.73L);

    GeodesicDirectResult!real directA;
    GeodesicDirectResult!real directB;

    assert(solver.tryDirect(
        directStart,
        directAzimuth,
        directDistanceA,
        directA));

    assert(solver.tryDirect(
        directStart,
        directAzimuth,
        directDistanceB,
        directB));

    const bool directDistinguishes =
        directA.position.latitude.radians
            != directB.position.latitude.radians
        || directA.position.longitude.radians
            != directB.position.longitude.radians
        || directA.finalAzimuth.radians
            != directB.finalAzimuth.radians;

    /*
     * Inverse: endpoint longitudes differ in real but collapse to one double.
     * This ordinary unique path exercises the general ellipsoidal inverse
     * machinery.
     */
    const real inverseLongitudeA =
        0.25L;

    const real inversePerturbation =
        0x1p-58L;

    const real inverseLongitudeB =
        inverseLongitudeA
        + inversePerturbation;

    const bool inverseCollapsesToDouble =
        binary64Bits(inverseLongitudeA)
        == binary64Bits(inverseLongitudeB);

    const inverseStart =
        pointRadians(
            -0.30L,
            -0.40L);

    const inverseEndA =
        pointRadians(
            0.40L,
            inverseLongitudeA);

    const inverseEndB =
        pointRadians(
            0.40L,
            inverseLongitudeB);

    GeodesicInverseResult!real inverseA;
    GeodesicInverseResult!real inverseB;

    assert(solver.tryInverse(
        inverseStart,
        inverseEndA,
        inverseA));

    assert(solver.tryInverse(
        inverseStart,
        inverseEndB,
        inverseB));

    const bool inverseDistinguishes =
        inverseA.distance != inverseB.distance
        || inverseA.initialAzimuth.radians
            != inverseB.initialAzimuth.radians
        || inverseA.finalAzimuth.radians
            != inverseB.finalAzimuth.radians;

    writefln(
        "direct perturbation=%.21g",
        directPerturbation);

    writefln(
        "direct binary64 representation equal=%s",
        directCollapsesToDouble);

    writefln(
        "direct output distinguishes=%s",
        directDistinguishes);

    writefln(
        "direct dlat=%.21g",
        directB.position.latitude.radians
            - directA.position.latitude.radians);

    writefln(
        "direct dlon=%.21g",
        directB.position.longitude.radians
            - directA.position.longitude.radians);

    writefln(
        "inverse perturbation=%.21g",
        inversePerturbation);

    writefln(
        "inverse binary64 representation equal=%s",
        inverseCollapsesToDouble);

    writefln(
        "inverse output distinguishes=%s",
        inverseDistinguishes);

    writefln(
        "inverse ddistance=%.21g",
        inverseB.distance
            - inverseA.distance);

    writefln(
        "inverse dazi1=%.21g",
        inverseB.initialAzimuth.radians
            - inverseA.initialAzimuth.radians);

    const bool pass =
        directCollapsesToDouble
        && directDistinguishes
        && inverseCollapsesToDouble
        && inverseDistinguishes;

    assert(pass);

    writeln("RESULT: GEO-G REAL PRECISION PASS");
}
