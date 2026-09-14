/** Geographic/geocentric coordinate conversions. */
module geodesy.conversion;

import std.math : atan2, cos, fabs, frexp, ldexp, sin, sqrt;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geocentric : GeocentricCoordinate;
import geodesy.geodetic : GeodeticCoordinate;
import geodesy.scalar : isFiniteGeodesyScalar, isGeodesyScalar;


/**
 * Stable two-dimensional Euclidean norm.
 *
 * Avoids the avoidable intermediate overflow of sqrt(x*x + y*y).
 */
private T hypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T ax = fabs(x);
    const T ay = fabs(y);
    const T hi = ax >= ay ? ax : ay;
    const T lo = ax >= ay ? ay : ax;

    if (hi == cast(T) 0)
        return cast(T) 0;

    const T ratio = lo / hi;
    return hi * sqrt(cast(T) 1 + ratio * ratio);
}


/**
 * Convert a geodetic coordinate to geocentric Cartesian coordinates.
 *
 * Implements the forward direction of EPSG coordinate operation method 9602
 * (Geographic/geocentric conversions).
 *
 * The longitude is interpreted relative to the prime meridian defining the
 * geocentric X axis. For conventional EPSG geocentric systems this is the
 * Greenwich prime meridian.
 *
 * The ellipsoidal height and the ellipsoid axes must use the same linear unit.
 * The returned X/Y/Z components use that same unit.
 *
 * Returns false only when finite input values overflow or otherwise produce a
 * non-finite Cartesian result in scalar type T.
 */
bool tryGeodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!ellipsoid.isValid)
        return false;

    const T phi = source.latitude.radians;
    const T lambda = source.longitude.radians;
    const T h = source.ellipsoidalHeight;

    const T sinPhi = sin(phi);
    const T cosPhi = cos(phi);
    const T sinLambda = sin(lambda);
    const T cosLambda = cos(lambda);

    const T e2 = ellipsoid.firstEccentricitySquared;
    const T nu = ellipsoid.semiMajorAxis
        / sqrt(cast(T) 1 - e2 * sinPhi * sinPhi);

    const T radial = nu + h;
    const T x = radial * cosPhi * cosLambda;
    const T y = radial * cosPhi * sinLambda;
    const T z = ((cast(T) 1 - e2) * nu + h) * sinPhi;

    return GeocentricCoordinate!T.tryFromComponents(x, y, z, result);
}


/** Throwing convenience wrapper for `tryGeodeticToGeocentric`. */
GeocentricCoordinate!T geodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeocentricCoordinate!T result;
    if (!tryGeodeticToGeocentric(source, ellipsoid, result))
        throw new GeodesyValueException(
            "Geodetic to geocentric conversion requires a valid ellipsoid and a finite representable result.");
    return result;
}


/*
 * Working precision for the inverse transformation.
 *
 * Single precision is insufficient for the numerically sensitive interior
 * branches at Earth scale. Preserve the public float API while performing
 * the inverse kernel in double precision.
 */
private template ReverseWorkingScalar(T)
{
    static if (is(T == float))
        alias ReverseWorkingScalar = double;
    else
        alias ReverseWorkingScalar = T;
}


private struct ReverseSolution(T)
{
    T latitude;
    T longitude;
    T height;
}


private struct HalleyState(T)
{
    T sn;
    T cn;
    T an;
    T an2;
}


/*
 * One Fukushima/Halley update in homogeneous reduced-latitude coordinates.
 *
 * sn/cn are homogeneous coordinates; avoiding their normalization keeps the
 * update free of trigonometric functions.
 */
private bool halleyStep(T)(
    const T horizontal,
    const T absZ,
    const T oneMinusF,
    const T c,
    ref HalleyState!T state)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zc = oneMinusF * absZ;
    const T an3 = state.an2 * state.an;
    const T csncn = c * state.sn * state.cn;

    const T bn =
        cast(T) 1.5
        * csncn
        * ((horizontal * state.sn - zc * state.cn) * state.an
            - csncn);

    const T sn =
        (zc * an3 + c * state.sn * state.sn * state.sn)
        * an3
        - bn * state.sn;

    const T cn =
        (horizontal * an3 - c * state.cn * state.cn * state.cn)
        * an3
        - bn * state.cn;

    if (!isFiniteGeodesyScalar(sn) || !isFiniteGeodesyScalar(cn))
        return false;

    const T an2 = cn * cn + sn * sn;
    if (!(an2 > cast(T) 0) || !isFiniteGeodesyScalar(an2))
        return false;

    const T an = sqrt(an2);
    if (!isFiniteGeodesyScalar(an))
        return false;

    state.sn = sn;
    state.cn = cn;
    state.an2 = an2;
    state.an = an;
    return true;
}


/*
 * Algebraic residual of the homogeneous Fukushima equation.
 *
 * Division by an² makes the residual have the ellipsoid linear unit while
 * remaining invariant under homogeneous rescaling of sn/cn.
 */
private T halleyDefect(T)(
    const T horizontal,
    const T absZ,
    const T oneMinusF,
    const T c,
    const HalleyState!T state)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zc = oneMinusF * absZ;

    return fabs(
        ((horizontal * state.sn - zc * state.cn) * state.an
            - c * state.sn * state.cn)
        / state.an2);
}


/* Convert an accepted homogeneous Halley state to latitude and height. */
private bool finishHalley(T)(
    const T horizontal,
    const T z,
    const T semiMajorAxis,
    const T eccentricitySquared,
    const T oneMinusF,
    const HalleyState!T state,
    out T latitude,
    out T height)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zero = cast(T) 0;
    const T absZ = fabs(z);
    const T cc = oneMinusF * state.cn;

    const T denominatorSquared =
        state.an2 - eccentricitySquared * state.cn * state.cn;

    if (!(denominatorSquared > zero)
        || !isFiniteGeodesyScalar(denominatorSquared))
        return false;

    const T denominator = sqrt(denominatorSquared);

    height =
        (horizontal * cc
            + absZ * state.sn
            - semiMajorAxis * oneMinusF * state.an)
        / denominator;

    const T latitudeAbs = atan2(state.sn, cc);
    latitude = z < zero ? -latitudeAbs : latitudeAbs;

    return isFiniteGeodesyScalar(latitude)
        && isFiniteGeodesyScalar(height);
}


/*
 * Real cube root usable from pure geodetic kernels.
 *
 * Phobos cbrt is not pure in the supported compiler toolchain.  Decompose the
 * magnitude as m * 2^e with 0.5 <= m < 1, approximate cbrt(m) linearly, then
 * apply Halley refinement.  The exponent is split into a multiple of three
 * and a remainder, avoiding exp/log and retaining the full floating-point
 * exponent range.
 */
private T realCubeRoot(T)(const T x)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zero = cast(T) 0;

    if (x == zero)
        return x;

    const bool negative = x < zero;
    const T magnitude = negative ? -x : x;

    int exponent;
    const T mantissa = frexp(magnitude, exponent);

    /*
     * D integer division truncates toward zero.  Convert to floor division so
     * remainder is always 0, 1, or 2:
     *
     *   exponent = 3 * exponentThird + exponentRemainder
     */
    int exponentThird = exponent / 3;
    int exponentRemainder = exponent - 3 * exponentThird;

    if (exponentRemainder < 0)
    {
        exponentRemainder += 3;
        --exponentThird;
    }

    /*
     * Secant approximation to cbrt(m) on [0.5, 1].
     * Maximum initial relative error is about 1.32%.
     */
    T root =
        cast(T) 0.58740105196819947475L
        + cast(T) 0.41259894803180052525L * mantissa;

    /*
     * Halley iteration for y^3 = m:
     *
     *   y' = y * (y^3 + 2m) / (2y^3 + m)
     *
     * Cubic convergence makes two steps sufficient for double precision from
     * the approximation above.  Use a third step for extended-precision real.
     */
    static if (T.mant_dig <= double.mant_dig)
        enum iterations = 2;
    else
        enum iterations = 3;

    foreach (_; 0 .. iterations)
    {
        const T rootCubed = root * root * root;

        root *=
            (rootCubed + cast(T) 2 * mantissa)
            / (cast(T) 2 * rootCubed + mantissa);
    }

    /*
     * Restore the exponent remainder using exact precomputed real constants:
     *
     *   2^(1/3), 2^(2/3)
     */
    if (exponentRemainder == 1)
    {
        root *= cast(T)
            1.2599210498948731647672106072782283505702514647015L;
    }
    else if (exponentRemainder == 2)
    {
        root *= cast(T)
            1.5874010519681994747517056392723082603914933278999L;
    }

    root = ldexp(root, exponentThird);

    return negative ? -root : root;
}


/*
 * Robust oblate reverse solution.
 *
 * This is the oblate specialization of the extended Vermeille formulation
 * used by GeographicLib's Geocentric::IntReverse.  The branch structure and
 * cancellation-avoiding algebra follow Charles F. F. Karney's implementation
 * (GeographicLib 2.7, MIT/X11), while prolate-spheroid and rotation-matrix
 * functionality are intentionally outside geodesy-d's scope.
 */
private bool reverseOblateRobust(T)(
    const T horizontal,
    const T z,
    const T semiMajorAxis,
    const T eccentricitySquared,
    const T oneMinusEccentricitySquared,
    out T latitude,
    out T height)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zero = cast(T) 0;
    const T one = cast(T) 1;
    const T two = cast(T) 2;
    const T three = cast(T) 3;
    const T four = cast(T) 4;
    const T six = cast(T) 6;

    const T e4 =
        eccentricitySquared * eccentricitySquared;

    const T horizontalScaled =
        horizontal / semiMajorAxis;
    const T zScaled =
        z / semiMajorAxis;

    const T p =
        horizontalScaled * horizontalScaled;

    const T q =
        oneMinusEccentricitySquared
        * zScaled * zScaled;

    const T r =
        (p + q - e4) / six;

    /*
     * The general formula degenerates at k == 0 on the oblate equatorial
     * evolute.  Take the analytic limit there.  This also selects the
     * canonical nearest-ellipsoid/min-|h| solution when several geodetic
     * normals exist.
     */
    if (e4 * q == zero && r <= zero)
    {
        const T zz =
            sqrt((e4 - p) / oneMinusEccentricitySquared);
        const T xx =
            sqrt(p);
        const T hNorm =
            hypot2(zz, xx);

        if (!(hNorm > zero) || !isFiniteGeodesyScalar(hNorm))
            return false;

        T sinPhi = zz / hNorm;
        const T cosPhi = xx / hNorm;

        if (z < zero)
            sinPhi = -sinPhi;

        latitude = atan2(sinPhi, cosPhi);

        height =
            -semiMajorAxis
            * oneMinusEccentricitySquared
            * hNorm
            / eccentricitySquared;

        return isFiniteGeodesyScalar(latitude)
            && isFiniteGeodesyScalar(height);
    }

    const T S =
        e4 * p * q / four;

    const T r2 = r * r;
    const T r3 = r * r2;
    const T disc =
        S * (two * r3 + S);

    T u = r;

    if (disc >= zero)
    {
        const T rootDisc = sqrt(disc);

        T T3 = S + r3;

        /*
         * Select the sign maximizing |T3|.  This avoids cancellation without
         * changing the resulting real root.
         */
        T3 += T3 < zero ? -rootDisc : rootDisc;

        const T root = realCubeRoot(T3);

        u += root
            + (root != zero ? r2 / root : zero);
    }
    else
    {
        const T angle =
            atan2(
                sqrt(-disc),
                -(S + r3));

        /*
         * Three real cube roots exist here.  This branch chooses the root
         * avoiding the cancellation of the direct cubic expression.
         */
        u += two * r * cos(angle / three);
    }

    const T v =
        sqrt(u * u + e4 * q);

    if (!(v > zero) || !isFiniteGeodesyScalar(v))
        return false;

    /*
     * u + v suffers cancellation for u < 0.  Use the equivalent quotient
     * in that case.
     */
    const T uv =
        u < zero
        ? e4 * q / (v - u)
        : u + v;

    if (!(uv > zero) || !isFiniteGeodesyScalar(uv))
        return false;

    T w =
        eccentricitySquared
        * (uv - q)
        / (two * v);

    // Roundoff may make the theoretically non-negative value slightly < 0.
    if (w < zero)
        w = zero;

    /*
     * Rearranged to avoid subtraction in the original expression for k.
     */
    const T k =
        uv
        / (sqrt(uv + w * w) + w);

    if (!(k > zero) || !isFiniteGeodesyScalar(k))
        return false;

    const T k2 =
        k + eccentricitySquared;

    const T d =
        k * horizontal / k2;

    const T zOverK =
        z / k;
    const T rOverK2 =
        horizontal / k2;

    const T hNorm =
        hypot2(zOverK, rOverK2);

    if (!(hNorm > zero) || !isFiniteGeodesyScalar(hNorm))
        return false;

    const T sinPhi =
        zOverK / hNorm;
    const T cosPhi =
        rOverK2 / hNorm;

    latitude =
        atan2(sinPhi, cosPhi);

    height =
        (one - oneMinusEccentricitySquared / k)
        * hypot2(d, z);

    return isFiniteGeodesyScalar(latitude)
        && isFiniteGeodesyScalar(height);
}


/*
 * Core inverse kernel in its selected working scalar.
 */
private bool tryReverseWorking(T)(
    const T x,
    const T y,
    const T z,
    const T semiMajorAxis,
    const T flattening,
    out ReverseSolution!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    const T zero = cast(T) 0;
    const T one = cast(T) 1;
    const T two = cast(T) 2;

    const T oneMinusF =
        one - flattening;

    const T semiMinorAxis =
        semiMajorAxis * oneMinusF;

    const T eccentricitySquared =
        flattening * (two - flattening);

    const T oneMinusEccentricitySquared =
        oneMinusF * oneMinusF;

    const T e4 =
        eccentricitySquared * eccentricitySquared;

    const T horizontal =
        hypot2(x, y);

    /*
     * The exact centre has no unique geodetic inverse.
     */
    if (horizontal == zero && z == zero)
        return false;

    /*
     * Rotation axis. Longitude is indeterminate; choose zero.
     */
    if (horizontal == zero)
    {
        result.latitude =
            atan2(z, horizontal);
        result.longitude = zero;
        result.height =
            fabs(z) - semiMinorAxis;

        return isFiniteGeodesyScalar(result.latitude)
            && isFiniteGeodesyScalar(result.height);
    }

    result.longitude =
        atan2(y, x);

    if (!isFiniteGeodesyScalar(result.longitude))
        return false;

    const T centreDistance =
        hypot2(horizontal, z);

    /*
     * Very distant coordinates are scaled before deriving latitude.  This
     * mirrors the overflow-avoidance strategy of the robust reference
     * algorithm.  The Earth is negligible at this scale, so centre distance
     * is an adequate height approximation.
     */
    const T maxRadius =
        two * semiMajorAxis / T.epsilon;

    if (centreDistance > maxRadius)
    {
        const T half = cast(T) 0.5;
        const T halfX = x * half;
        const T halfY = y * half;
        const T halfZ = z * half;

        const T halfHorizontal =
            hypot2(halfX, halfY);
        const T halfDistance =
            hypot2(halfHorizontal, halfZ);

        if (!(halfDistance > zero)
            || !isFiniteGeodesyScalar(halfDistance)
            || !isFiniteGeodesyScalar(centreDistance))
            return false;

        result.latitude =
            atan2(halfZ, halfHorizontal);
        result.height =
            centreDistance;

        return isFiniteGeodesyScalar(result.latitude)
            && isFiniteGeodesyScalar(result.height);
    }

    /*
     * Sphere: the inverse is analytic.
     */
    if (eccentricitySquared == zero)
    {
        if (!(centreDistance > zero)
            || !isFiniteGeodesyScalar(centreDistance))
            return false;

        result.latitude =
            atan2(z, horizontal);
        result.height =
            centreDistance - semiMajorAxis;

        return isFiniteGeodesyScalar(result.latitude)
            && isFiniteGeodesyScalar(result.height);
    }

    /*
     * Exact equatorial interior/evolute case.
     *
     * Halley's algebraic defect is also exactly zero for the non-canonical
     * equatorial normal here, so it cannot be used to select the nearest
     * ellipsoid solution. Route directly to the robust analytic branch.
     *
     * For z == 0, r <= 0 in the Vermeille formulation is equivalent to
     * horizontal <= a * e².
     */
    if (z == zero
        && horizontal <= semiMajorAxis * eccentricitySquared)
    {
        return reverseOblateRobust(
            horizontal,
            z,
            semiMajorAxis,
            eccentricitySquared,
            oneMinusEccentricitySquared,
            result.latitude,
            result.height);
    }

    /*
     * Fukushima 2006 homogeneous Halley iteration.
     *
     * Initial homogeneous coordinates correspond to the zero-height solution.
     * The fast path attempts at most two Halley updates.  Each candidate is
     * accepted only when its scale-independent algebraic defect is within a
     * conservative working-precision bound.
     */
    const T absZ =
        fabs(z);

    HalleyState!T state;
    state.sn = absZ;
    state.cn = oneMinusF * horizontal;
    state.an2 =
        state.cn * state.cn
        + state.sn * state.sn;

    if (state.an2 > zero
        && isFiniteGeodesyScalar(state.an2))
    {
        state.an =
            sqrt(state.an2);

        if (isFiniteGeodesyScalar(state.an))
        {
            const T c =
                semiMajorAxis * eccentricitySquared;

            const T defectLimit =
                cast(T) 64
                * T.epsilon
                * semiMajorAxis;

            foreach (_; 0 .. 2)
            {
                if (!halleyStep(
                    horizontal,
                    absZ,
                    oneMinusF,
                    c,
                    state))
                    break;

                const T defect =
                    halleyDefect(
                        horizontal,
                        absZ,
                        oneMinusF,
                        c,
                        state);

                if (isFiniteGeodesyScalar(defect)
                    && defect <= defectLimit)
                {
                    if (finishHalley(
                        horizontal,
                        z,
                        semiMajorAxis,
                        eccentricitySquared,
                        oneMinusF,
                        state,
                        result.latitude,
                        result.height))
                        return true;

                    break;
                }
            }
        }
    }

    /*
     * Difficult interior/cusp cases fall back to the complete robust oblate
     * solution.
     */
    return reverseOblateRobust(
        horizontal,
        z,
        semiMajorAxis,
        eccentricitySquared,
        oneMinusEccentricitySquared,
        result.latitude,
        result.height);
}


/**
 * Convert geocentric Cartesian coordinates to a geodetic coordinate.
 *
 * Implements the reverse transformation represented by EPSG coordinate
 * operation method 9602 (Geographic/geocentric conversions).
 *
 * The inverse uses a hybrid numerical algorithm:
 *
 * $(UL
 *   $(LI Ordinary non-degenerate oblate cases use the homogeneous
 *        Halley-accelerated Cartesian-to-geodetic formulation described by
 *        Fukushima (2006). At most two Halley updates are attempted.)
 *   $(LI A scale-independent algebraic defect determines whether a Halley
 *        candidate is accepted; difficult cases are not forced through the
 *        fast path.)
 *   $(LI Rejected, multiple-root, cusp/evolute, and other difficult oblate
 *        cases use an extended Vermeille closed-form solution with the
 *        cancellation-avoiding branch choices used by Karney's
 *        GeographicLib implementation.)
 *   $(LI Spherical, rotation-axis, and very distant finite coordinates use
 *        dedicated analytic or scaled paths.)
 * )
 *
 * For deep-interior points where several geodetic normal-coordinate
 * representations exist, the robust branch selects the canonical
 * nearest-ellipsoid solution (equivalently the solution minimizing |h|).
 *
 * The exact ellipsoid centre (0, 0, 0) has no unique geodetic latitude,
 * longitude, or ellipsoidal height and therefore returns false.
 *
 * On the rotation axis (X == 0 && Y == 0, Z != 0), longitude is
 * indeterminate. This implementation returns longitude 0 by convention.
 *
 * `float` inputs retain a `float` public result but the numerically sensitive
 * inverse kernel is evaluated in `double` working precision. `double` and
 * `real` are evaluated in their own scalar type.
 *
 * Numerical accuracy contract for the validated terrestrial domain:
 *
 * - ellipsoids: WGS 84, GRS 80, and Airy 1830;
 * - latitude: the full legal range;
 * - ellipsoidal height: -20 km through +100 km.
 *
 * Within that domain, `float` results reproduce the represented Cartesian
 * position within 2 m and ellipsoidal height within 0.1 m.
 *
 * `double` and `real` results reproduce the represented Cartesian position
 * within 1 mm.
 *
 * Here, represented Cartesian position means the ECEF coordinate obtained by
 * applying the forward conversion to the returned geodetic coordinate on the
 * same ellipsoid.
 *
 * These limits describe numerical coordinate-conversion error only. They do
 * not describe datum, reference-frame, observation, survey, GNSS, or physical
 * position accuracy.
 *
 * Outside the validated terrestrial domain, the documented robust and
 * canonical inverse semantics still apply, but the same absolute accuracy
 * envelope is not claimed.
 *
 * The input X/Y/Z and ellipsoid axes must use the same linear unit. The
 * returned ellipsoidal height uses that same unit.
 *
 * References:
 * - T. Fukushima, "Transformation from Cartesian to geodetic coordinates
 *   accelerated by Halley's method", Journal of Geodesy 79 (2006),
 *   DOI 10.1007/s00190-006-0023-2.
 * - H. Vermeille, direct transformation from geocentric to geodetic
 *   coordinates.
 * - C. F. F. Karney, GeographicLib `Geocentric`, extended/stabilized
 *   Vermeille inverse formulation.
 */
bool tryGeocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeodeticCoordinate!T result)
    pure nothrow @safe @nogc
if (isGeodesyScalar!T)
{
    if (!ellipsoid.isValid)
        return false;

    alias W = ReverseWorkingScalar!T;

    ReverseSolution!W working;

    if (!tryReverseWorking(
        cast(W) source.x,
        cast(W) source.y,
        cast(W) source.z,
        cast(W) ellipsoid.semiMajorAxis,
        cast(W) ellipsoid.flattening,
        working))
        return false;

    const T phi =
        cast(T) working.latitude;
    const T lambda =
        cast(T) working.longitude;
    const T height =
        cast(T) working.height;

    if (!isFiniteGeodesyScalar(phi)
        || !isFiniteGeodesyScalar(lambda)
        || !isFiniteGeodesyScalar(height))
        return false;

    Latitude!T latitude;
    Longitude!T longitude;

    if (!Latitude!T.tryFromRadians(phi, latitude))
        return false;
    if (!Longitude!T.tryFromRadians(lambda, longitude))
        return false;

    return GeodeticCoordinate!T.tryFromComponents(
        latitude,
        longitude,
        height,
        result);
}


/** Throwing convenience wrapper for `tryGeocentricToGeodetic`. */
GeodeticCoordinate!T geocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid)
    @safe
if (isGeodesyScalar!T)
{
    GeodeticCoordinate!T result;
    if (!tryGeocentricToGeodetic(source, ellipsoid, result))
        throw new GeodesyValueException(
            "Geocentric to geodetic conversion requires a valid ellipsoid and a defined finite representable result.");
    return result;
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    import geodesy.ellipsoid : wgs84;

    bool near(const double actual, const double expected, const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    // EPSG Guidance Note 7-2 / method 9602 worked WGS 84 example.
    const latitude = Latitude!double.fromDegrees(
        53.0 + 48.0 / 60.0 + 33.82 / 3600.0);
    const longitude = Longitude!double.fromDegrees(
        2.0 + 7.0 / 60.0 + 46.38 / 3600.0);
    const source = GeodeticCoordinate!double.fromComponents(
        latitude, longitude, 73.0);

    const xyz = geodeticToGeocentric(source, wgs84!double());
    assert(near(xyz.x, 3_771_793.968, 0.001));
    assert(near(xyz.y,   140_253.342, 0.001));
    assert(near(xyz.z, 5_124_304.349, 0.001));

    // Reverse the rounded EPSG example coordinates.
    const epsgXyz = GeocentricCoordinate!double.fromComponents(
        3_771_793.968,
          140_253.342,
        5_124_304.349);
    const epsgGeo = geocentricToGeodetic(epsgXyz, wgs84!double());

    assert(near(
        epsgGeo.latitude.degrees,
        53.0 + 48.0 / 60.0 + 33.82 / 3600.0,
        1e-8));
    assert(near(
        epsgGeo.longitude.degrees,
        2.0 + 7.0 / 60.0 + 46.38 / 3600.0,
        1e-8));
    // EPSG Cartesian input is rounded to millimetres.
    assert(near(epsgGeo.ellipsoidalHeight, 73.0, 0.001));

    // Equator, prime meridian, positive height.
    const equatorXyz = GeocentricCoordinate!double.fromComponents(
        wgs84!double().semiMajorAxis + 250.0,
        0.0,
        0.0);
    const equatorGeo = geocentricToGeodetic(equatorXyz, wgs84!double());
    assert(equatorGeo.latitude.radians == 0.0);
    assert(equatorGeo.longitude.radians == 0.0);
    assert(near(equatorGeo.ellipsoidalHeight, 250.0, 1e-9));

    // Rotation axis: longitude is indeterminate and standardized here to zero.
    const northAxis = GeocentricCoordinate!double.fromComponents(
        0.0,
        0.0,
        wgs84!double().semiMinorAxis + 100.0);
    const northGeo = geocentricToGeodetic(northAxis, wgs84!double());
    assert(near(northGeo.latitude.degrees, 90.0, 1e-12));
    assert(northGeo.longitude.radians == 0.0);
    assert(near(northGeo.ellipsoidalHeight, 100.0, 1e-9));

    const southAxis = GeocentricCoordinate!double.fromComponents(
        0.0,
        0.0,
        -(wgs84!double().semiMinorAxis + 100.0));
    const southGeo = geocentricToGeodetic(southAxis, wgs84!double());
    assert(near(southGeo.latitude.degrees, -90.0, 1e-12));
    assert(southGeo.longitude.radians == 0.0);
    assert(near(southGeo.ellipsoidalHeight, 100.0, 1e-9));

    // A default-initialized ellipsoid is deliberately invalid and must be
    // rejected before any conversion mathematics is attempted.
    const invalidEllipsoid = Ellipsoid!double.init;

    GeocentricCoordinate!double invalidForward;
    assert(!tryGeodeticToGeocentric(
        source, invalidEllipsoid, invalidForward));
    assertThrown!GeodesyValueException(
        geodeticToGeocentric(source, invalidEllipsoid));

    GeodeticCoordinate!double invalidReverse;
    assert(!tryGeocentricToGeodetic(
        epsgXyz, invalidEllipsoid, invalidReverse));
    assertThrown!GeodesyValueException(
        geocentricToGeodetic(epsgXyz, invalidEllipsoid));

    // The exact ellipsoid centre is not uniquely invertible.
    const centre = GeocentricCoordinate!double.init;
    GeodeticCoordinate!double centreResult;
    assert(!tryGeocentricToGeodetic(
        centre, wgs84!double(), centreResult));
    assertThrown!GeodesyValueException(
        geocentricToGeodetic(centre, wgs84!double()));

    // High-altitude round trip exercises reverse conversion well above the
    // ordinary terrestrial height range.
    const high = GeodeticCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(44.987654321),
        Longitude!double.fromDegrees(35.432198765),
        1_000_000.0);
    const highXyz = geodeticToGeocentric(high, wgs84!double());
    const highBack = geocentricToGeodetic(highXyz, wgs84!double());

    assert(near(
        highBack.latitude.radians,
        high.latitude.radians,
        1e-13));
    assert(near(
        highBack.longitude.radians,
        high.longitude.radians,
        1e-13));
    assert(near(
        highBack.ellipsoidalHeight,
        high.ellipsoidalHeight,
        1e-6));

    // Generic instantiation for reduced-precision float and platform real.
    const floatSphere = Ellipsoid!float.sphere(1.0f);
    const floatGeo = geocentricToGeodetic(
        GeocentricCoordinate!float.fromComponents(2.0f, 0.0f, 0.0f),
        floatSphere);
    assert(floatGeo.latitude.radians == 0.0f);
    assert(floatGeo.longitude.radians == 0.0f);
    assert(floatGeo.ellipsoidalHeight == 1.0f);

    const realSphere = Ellipsoid!real.sphere(1.0L);
    const realGeo = geocentricToGeodetic(
        GeocentricCoordinate!real.fromComponents(2.0L, 0.0L, 0.0L),
        realSphere);
    assert(realGeo.latitude.radians == 0.0L);
    assert(realGeo.longitude.radians == 0.0L);
    assert(realGeo.ellipsoidalHeight == 1.0L);

    // Finite geodetic inputs can still overflow during the forward direction.
    const huge = GeodeticCoordinate!double.fromComponents(
        Latitude!double.init,
        Longitude!double.init,
        double.max);
    const hugeSphere = Ellipsoid!double.sphere(double.max);
    GeocentricCoordinate!double candidate;
    assert(!tryGeodeticToGeocentric(huge, hugeSphere, candidate));
    assertThrown!GeodesyValueException(
        geodeticToGeocentric(huge, hugeSphere));
}



/*
 * GeographicLib/PROJ upstream reverse-regression vectors.
 *
 * These tests intentionally complement the EPSG and property-style tests
 * above with independently maintained corner cases from established
 * geodetic libraries.
 *
 * Sources:
 * - GeographicLib 2.7 tests/CMakeLists.txt, CartConvert0
 * - GeographicLib Geocentric documentation, WGS84 evolute conditioning
 * - PROJ test/gie/more_builtins.gie, +proj=cart section
 *
 * GeographicLib's adjacent CartConvert1 case uses a prolate ellipsoid and is
 * intentionally outside geodesy-d's spherical/oblate ellipsoid model.
 *
 * PROJ defines an arbitrary inverse result at the exact ellipsoid centre;
 * geodesy-d deliberately returns false because the geodetic inverse there is
 * not unique.
 */
unittest
{
    import std.math : fabs;

    import geodesy.ellipsoid : wgs84;

    bool near(
        const double actual,
        const double expected,
        const double tolerance)
    {
        return fabs(actual - expected) <= tolerance;
    }

    double reverseResidual(
        const GeocentricCoordinate!double source,
        const Ellipsoid!double ellipsoid,
        out GeodeticCoordinate!double geo)
    {
        /*
         * Do not put the call itself inside assert: assertions may be elided
         * by release builds, while the operation under test must not be.
         */
        const bool success =
            tryGeocentricToGeodetic(
                source,
                ellipsoid,
                geo);

        assert(success);

        const back =
            geodeticToGeocentric(
                geo,
                ellipsoid);

        return hypot2(
            hypot2(
                source.x - back.x,
                source.y - back.y),
            source.z - back.z);
    }

    /*
     * GeographicLib 2.7 CartConvert0:
     *
     *   a   = 6.4e6
     *   f   = 1/100
     *   XYZ = (10e3, 0, 1e3)
     *
     * Upstream expected:
     *   latitude  = 85.57... deg
     *   longitude = 0
     *   height    = -6334614... m
     *
     * This is a deep-interior oblate case exercising the robust branch.
     */
    const geographicLibEllipsoid =
        Ellipsoid!double.fromFlattening(
            6_400_000.0,
            1.0 / 100.0);

    const geographicLibXyz =
        GeocentricCoordinate!double.fromComponents(
            10_000.0,
            0.0,
            1_000.0);

    GeodeticCoordinate!double geographicLibGeo;

    const geographicLibResidual =
        reverseResidual(
            geographicLibXyz,
            geographicLibEllipsoid,
            geographicLibGeo);

    assert(
        geographicLibGeo.latitude.degrees >= 85.570
        && geographicLibGeo.latitude.degrees < 85.580);

    assert(
        near(
            geographicLibGeo.longitude.degrees,
            0.0,
            1e-12));

    assert(
        geographicLibGeo.ellipsoidalHeight >= -6_334_615.0
        && geographicLibGeo.ellipsoidalHeight < -6_334_614.0);

    assert(geographicLibResidual <= 1e-6);

    /*
     * GeographicLib's neighboring CartConvert1 regression is prolate
     * (f = -1/100). Verify that the model boundary remains explicit.
     */
    Ellipsoid!double prolateCandidate;

    const bool acceptedProlate =
        Ellipsoid!double.tryFromFlattening(
            6_400_000.0,
            -1.0 / 100.0,
            prolateCandidate);

    assert(!acceptedProlate);

    /*
     * GeographicLib documents the WGS84 equatorial evolute cusp at
     *
     *   p = a * e², z = 0.
     *
     * Around this point the inverse problem is extraordinarily ill
     * conditioned. Nanometre changes in ECEF can produce arcsecond-scale
     * changes in geodetic latitude.
     */
    const wgs = wgs84!double();

    const double cusp =
        wgs.semiMajorAxis
        * wgs.firstEccentricitySquared;

    enum double oneNanometre = 1e-9;

    GeodeticCoordinate!double exactCuspGeo;

    const exactCuspResidual =
        reverseResidual(
            GeocentricCoordinate!double.fromComponents(
                cusp,
                0.0,
                0.0),
            wgs,
            exactCuspGeo);

    assert(
        fabs(exactCuspGeo.latitude.degrees)
        <= 1e-12);

    assert(exactCuspResidual <= 1e-6);

    GeodeticCoordinate!double radialCuspGeo;

    const radialCuspResidual =
        reverseResidual(
            GeocentricCoordinate!double.fromComponents(
                cusp - oneNanometre,
                0.0,
                0.0),
            wgs,
            radialCuspGeo);

    const double radialArcseconds =
        fabs(radialCuspGeo.latitude.degrees)
        * 3600.0;

    // GeographicLib documentation gives approximately 0.04 arcsecond.
    assert(
        radialArcseconds >= 0.02
        && radialArcseconds <= 0.06);

    assert(radialCuspResidual <= 1e-6);

    GeodeticCoordinate!double northCuspGeo;

    const northCuspResidual =
        reverseResidual(
            GeocentricCoordinate!double.fromComponents(
                cusp,
                0.0,
                oneNanometre),
            wgs,
            northCuspGeo);

    const double northArcseconds =
        northCuspGeo.latitude.degrees
        * 3600.0;

    // GeographicLib documentation gives approximately +7.45 arcseconds.
    assert(
        northArcseconds >= 7.0
        && northArcseconds <= 8.0);

    assert(northCuspResidual <= 1e-6);

    GeodeticCoordinate!double southCuspGeo;

    const southCuspResidual =
        reverseResidual(
            GeocentricCoordinate!double.fromComponents(
                cusp,
                0.0,
                -oneNanometre),
            wgs,
            southCuspGeo);

    const double southArcseconds =
        southCuspGeo.latitude.degrees
        * 3600.0;

    assert(
        southArcseconds <= -7.0
        && southArcseconds >= -8.0);

    assert(
        near(
            northArcseconds,
            -southArcseconds,
            1e-9));

    assert(southCuspResidual <= 1e-6);

    /*
     * PROJ 9.7.1 handwritten +proj=cart GRS80 corner cases.
     *
     * Upstream tolerance is 0.001 mm.
     */
    const grs80 =
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257222101);

    enum double grs80A = 6_378_137.0;
    enum double grs80B = 6_356_752.314140347;

    struct ProjCartCase
    {
        double x;
        double y;
        double z;
        double latitudeDegrees;
        double longitudeDegrees;
    }

    const ProjCartCase[] projCases = [
        ProjCartCase(
             grs80A, 0.0, 0.0,
             0.0, 0.0),

        ProjCartCase(
             0.0, 0.0, grs80B,
             90.0, 0.0),

        ProjCartCase(
             0.0, 0.0, -grs80B,
             -90.0, 0.0),

        ProjCartCase(
             0.0, grs80A, 0.0,
             0.0, 90.0),

        ProjCartCase(
             0.0, -grs80A, 0.0,
             0.0, -90.0),

        ProjCartCase(
             -grs80A, 0.0, 0.0,
             0.0, 180.0)
    ];

    foreach (testCase; projCases)
    {
        const xyz =
            GeocentricCoordinate!double.fromComponents(
                testCase.x,
                testCase.y,
                testCase.z);

        GeodeticCoordinate!double geo;

        const r =
            reverseResidual(
                xyz,
                grs80,
                geo);

        assert(
            near(
                geo.latitude.degrees,
                testCase.latitudeDegrees,
                1e-10));

        if (fabs(testCase.longitudeDegrees) == 180.0)
        {
            assert(
                near(
                    fabs(geo.longitude.degrees),
                    180.0,
                    1e-10));
        }
        else
        {
            assert(
                near(
                    geo.longitude.degrees,
                    testCase.longitudeDegrees,
                    1e-10));
        }

        assert(
            near(
                geo.ellipsoidalHeight,
                0.0,
                1e-6));

        assert(r <= 1e-6);
    }

    /*
     * Intentional semantic difference from PROJ:
     * the exact centre has no unique inverse in geodesy-d.
     */
    GeodeticCoordinate!double centreGeo;

    const bool centreAccepted =
        tryGeocentricToGeodetic(
            GeocentricCoordinate!double.init,
            grs80,
            centreGeo);

    assert(!centreAccepted);

    /*
     * PROJ documented GRS80 Cartesian example. The published Cartesian
     * coordinates are rounded, so use tolerances reflecting that source data.
     */
    const projDocumentedXyz =
        GeocentricCoordinate!double.fromComponents(
            4_272_922.1553,
            1_368_283.0597,
            4_518_261.3501);

    GeodeticCoordinate!double projDocumentedGeo;

    const projDocumentedResidual =
        reverseResidual(
            projDocumentedXyz,
            grs80,
            projDocumentedGeo);

    assert(
        near(
            projDocumentedGeo.longitude.degrees,
            17.7562015132,
            1e-8));

    assert(
        near(
            projDocumentedGeo.latitude.degrees,
            45.3935192042,
            1e-8));

    assert(
        near(
            projDocumentedGeo.ellipsoidalHeight,
            133.12,
            0.001));

    assert(projDocumentedResidual <= 1e-6);
}


/*
 * Verify the internal pure cube-root replacement used by the robust
 * Vermeille branch against the platform's std.math.cbrt reference.
 *
 * The production helper exists because Phobos cbrt is not pure in the
 * supported compiler toolchain; this test ensures that preserving the API's
 * purity does not sacrifice cube-root accuracy over a wide exponent range.
 */
unittest
{
    import std.math : cbrt, fabs;

    const double[] samples = [
        -1e300,
        -1e200,
        -1e100,
        -1e-100,
        -1e-200,
        -1e-300,
        -8.0,
        -1.0,
        -0.125,
         0.0,
         0.125,
         1.0,
         8.0,
         1e-300,
         1e-200,
         1e-100,
         1e100,
         1e200,
         1e300
    ];

    foreach (x; samples)
    {
        const double expected =
            cbrt(x);

        const double actual =
            realCubeRoot(x);

        if (expected == 0.0)
        {
            assert(actual == expected);
        }
        else
        {
            const double relativeError =
                fabs((actual - expected) / expected);

            assert(
                relativeError
                <= 16.0 * double.epsilon);
        }
    }

    const real[] realSamples = [
        -1e300L,
        -8.0L,
        -1.0L,
        -1e-300L,
         1e-300L,
         1.0L,
         8.0L,
         1e300L
    ];

    foreach (x; realSamples)
    {
        const real expected =
            cbrt(x);

        const real actual =
            realCubeRoot(x);

        const real relativeError =
            fabs((actual - expected) / expected);

        assert(
            relativeError
            <= cast(real) 32 * real.epsilon);
    }
}
