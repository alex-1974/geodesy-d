/**
 * Bounded generic Transverse Mercator projection.
 *
 * The public parameter semantics follow EPSG coordinate operation method 9807.
 */
module geodesy.projection.transverse_mercator;

import std.math :
    PI, asinh, atan, atan2, atanh, cos, cosh, exp, fabs, sin, sinh, sqrt;

import geodesy.angle : Latitude, Longitude;
import geodesy.ellipsoid : Ellipsoid;
import geodesy.errors : GeodesyValueException;
import geodesy.geographic : GeographicCoordinate;
import geodesy.projected : ProjectedCoordinate;
import geodesy.scalar : isGeodesyScalar;


/*
 * Numerical provenance
 * --------------------
 *
 * The conformal/rectifying-latitude decomposition, Krueger series
 * coefficients, and Clenshaw evaluation follow:
 *
 *   Charles F. F. Karney,
 *   "Transverse Mercator with an accuracy of a few nanometers",
 *   Journal of Geodesy 85(8), 475-485 (2011).
 *
 * Coefficient tables are cross-checked against GeographicLib's
 * TransverseMercator implementation (MIT/X11). The public API, bounded domain,
 * EPSG 9807 parameter handling, scalar policy, and failure semantics are
 * geodesy-d decisions documented by ADR-0006.
 */


private template WorkingScalar(T)
if (isGeodesyScalar!T)
{
    static if (is(T == float))
        alias WorkingScalar = double;
    else
        alias WorkingScalar = T;
}


private template seriesOrderFor(T)
if (isGeodesyScalar!T)
{
    /*
     * float keeps the sixth-order series while evaluating in double working
     * precision.  double and real use eighth order because the documented
     * bounded domain extends far beyond the UTM-near-central-meridian regime
     * where sixth order is nanometre-class.
     */
    enum int seriesOrderFor = is(T == float) ? 6 : 8;
}


private bool isFiniteScalar(T)(const T value)
    pure nothrow @safe @nogc
{
    return value == value
        && value != T.infinity
        && value != -T.infinity;
}


private T pi(T)() pure nothrow @safe @nogc
{
    return cast(T) PI;
}


private T halfPi(T)() pure nothrow @safe @nogc
{
    return pi!T / cast(T) 2;
}


private T maxLongitudeDifference(T)() pure nothrow @safe @nogc
{
    return pi!T / cast(T) 3;
}


private T hypot2(T)(const T x, const T y)
    pure nothrow @safe @nogc
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


private void twoSum(T)(
    const T a,
    const T b,
    out T sum,
    out T residual)
    pure nothrow @safe @nogc
{
    sum = a + b;
    const T z = sum - a;
    residual = (a - (sum - z)) + (b - z);
}


private T normalizeRadians(T)(const T radians)
    pure nothrow @safe @nogc
{
    const T p = pi!T;
    const T twoP = cast(T) 2 * p;
    T result = radians;

    if (result >= p)
        result -= twoP;
    else if (result < -p)
        result += twoP;

    /*
     * Callers feed sums/differences of canonical longitudes, so a single
     * correction is sufficient. Preserve a unique half-open [-pi,+pi)
     * representation.
     */
    if (result >= p)
        result -= twoP;
    else if (result < -p)
        result += twoP;

    return result;
}


private T longitudeDifference(T)(
    const T longitude,
    const T longitudeOfNaturalOrigin)
    pure nothrow @safe @nogc
{
    T sum;
    T residual;
    twoSum(longitude, -longitudeOfNaturalOrigin, sum, residual);

    const T p = pi!T;
    const T twoP = cast(T) 2 * p;

    if (sum > p || (sum == p && residual >= cast(T) 0))
        sum -= twoP;
    else if (sum < -p || (sum == -p && residual < cast(T) 0))
        sum += twoP;

    return normalizeRadians(sum + residual);
}


private T addLongitude(T)(
    const T longitudeOfNaturalOrigin,
    const T deltaLongitude)
    pure nothrow @safe @nogc
{
    T sum;
    T residual;
    twoSum(longitudeOfNaturalOrigin, deltaLongitude, sum, residual);
    return normalizeRadians(sum + residual);
}


private T eccentricityTerm(T)(const T x, const T eccentricity)
    pure nothrow @safe @nogc
{
    if (eccentricity == cast(T) 0)
        return cast(T) 0;
    return eccentricity * atanh(eccentricity * x);
}


private T conformalTau(T)(
    const T tau,
    const T eccentricity)
    pure nothrow @safe @nogc
{
    if (!isFiniteScalar(tau))
        return tau;

    const T tau1 = hypot2(cast(T) 1, tau);
    const T sigma = sinh(eccentricityTerm(tau / tau1, eccentricity));

    return hypot2(cast(T) 1, sigma) * tau - sigma * tau1;
}


private bool geodeticTau(T)(
    const T tauPrime,
    const T eccentricity,
    out T tau)
    pure nothrow @safe @nogc
{
    enum int maxIterations = 5;

    const T epsilon = T.epsilon;
    const T e2m = cast(T) 1 - eccentricity * eccentricity;
    const T tolerance = sqrt(epsilon) / cast(T) 10;
    const T tauMax = cast(T) 2 / sqrt(epsilon);

    if (!(e2m > cast(T) 0))
        return false;

    tau = fabs(tauPrime) > cast(T) 70
        ? tauPrime * exp(eccentricityTerm(cast(T) 1, eccentricity))
        : tauPrime / e2m;

    if (!isFiniteScalar(tau))
        return false;

    const T scaledTolerance =
        tolerance * (fabs(tauPrime) > cast(T) 1
            ? fabs(tauPrime)
            : cast(T) 1);

    if (!(fabs(tau) < tauMax))
        return true;

    foreach (_; 0 .. maxIterations)
    {
        const T tauPrimeApprox = conformalTau(tau, eccentricity);
        const T denominator =
            e2m * hypot2(cast(T) 1, tau)
                * hypot2(cast(T) 1, tauPrimeApprox);

        if (!(denominator > cast(T) 0) || !isFiniteScalar(denominator))
            return false;

        const T deltaTau =
            (tauPrime - tauPrimeApprox)
            * (cast(T) 1 + e2m * tau * tau)
            / denominator;

        if (!isFiniteScalar(deltaTau))
            return false;

        tau += deltaTau;

        if (!isFiniteScalar(tau))
            return false;

        if (!(fabs(deltaTau) >= scaledTolerance))
            return true;
    }

    return false;
}


private struct ComplexPair(T)
{
    T re = 0;
    T im = 0;
}


private ComplexPair!T pairSub(T)(
    const ComplexPair!T a,
    const ComplexPair!T b)
    pure nothrow @safe @nogc
{
    return ComplexPair!T(a.re - b.re, a.im - b.im);
}


private ComplexPair!T pairMul(T)(
    const ComplexPair!T a,
    const ComplexPair!T b)
    pure nothrow @safe @nogc
{
    return ComplexPair!T(
        a.re * b.re - a.im * b.im,
        a.re * b.im + a.im * b.re);
}


private ComplexPair!T pairWithRealAdded(T)(
    const ComplexPair!T value,
    const T realPart)
    pure nothrow @safe @nogc
{
    return ComplexPair!T(value.re + realPart, value.im);
}


/**
 * Prepared bounded Transverse Mercator operation with EPSG 9807 parameters.
 *
 * The first implementation supports spherical and moderately oblate
 * ellipsoids with `0 <= f <= 0.01`. Non-polar forward inputs are restricted to
 * `abs(delta longitude) <= 60 degrees`.
 *
 * `float` uses `double` working precision with sixth-order Krueger series.
 * `double` and `real` use eighth-order series to support the bounded
 * wide-domain accuracy contract.
 */
struct TransverseMercator(T)
if (isGeodesyScalar!T)
{
private:
    alias W = WorkingScalar!T;
    enum int seriesOrder = seriesOrderFor!T;

    Ellipsoid!T _ellipsoid;
    Latitude!T _latitudeOfNaturalOrigin;
    Longitude!T _longitudeOfNaturalOrigin;
    T _scaleFactorAtNaturalOrigin = T.nan;
    T _falseEasting = T.nan;
    T _falseNorthing = T.nan;

    W _eccentricity = W.nan;
    W _a1 = W.nan;
    W _originXi = W.nan;
    W[9] _alpha;
    W[9] _beta;

    static W evaluateB1(const W n)
        pure nothrow @safe @nogc
    {
        const W n2 = n * n;

        static if (seriesOrder == 6)
        {
            return (((n2 + cast(W) 4) * n2 + cast(W) 64) * n2
                + cast(W) 256)
                / (cast(W) 256 * (cast(W) 1 + n));
        }
        else
        {
            static assert(seriesOrder == 8);
            return ((((cast(W) 25 * n2 + cast(W) 64) * n2
                + cast(W) 256) * n2 + cast(W) 4096) * n2
                + cast(W) 16384)
                / (cast(W) 16384 * (cast(W) 1 + n));
        }
    }


    static void fillCoefficients(
        const W n,
        ref W[9] alpha,
        ref W[9] beta)
        pure nothrow @safe @nogc
    {
        W nPower = n;

        static if (seriesOrder == 6)
        {
            alpha[1] = nPower
                * (((((cast(W) 31564 * n - cast(W) 66675) * n
                    + cast(W) 34440) * n + cast(W) 47250) * n
                    - cast(W) 100800) * n + cast(W) 75600)
                / cast(W) 151200;
            nPower *= n;

            alpha[2] = nPower
                * ((((-cast(W) 1983433 * n + cast(W) 863232) * n
                    + cast(W) 748608) * n - cast(W) 1161216) * n
                    + cast(W) 524160)
                / cast(W) 1935360;
            nPower *= n;

            alpha[3] = nPower
                * (((cast(W) 670412 * n + cast(W) 406647) * n
                    - cast(W) 533952) * n + cast(W) 184464)
                / cast(W) 725760;
            nPower *= n;

            alpha[4] = nPower
                * ((cast(W) 6601661 * n - cast(W) 7732800) * n
                    + cast(W) 2230245)
                / cast(W) 7257600;
            nPower *= n;

            alpha[5] = nPower
                * (-cast(W) 13675556 * n + cast(W) 3438171)
                / cast(W) 7983360;
            nPower *= n;

            alpha[6] = nPower
                * cast(W) 212378941
                / cast(W) 319334400;

            nPower = n;

            beta[1] = nPower
                * (((((cast(W) 384796 * n - cast(W) 382725) * n
                    - cast(W) 6720) * n + cast(W) 932400) * n
                    - cast(W) 1612800) * n + cast(W) 1209600)
                / cast(W) 2419200;
            nPower *= n;

            beta[2] = nPower
                * ((((-cast(W) 1118711 * n + cast(W) 1695744) * n
                    - cast(W) 1174656) * n + cast(W) 258048) * n
                    + cast(W) 80640)
                / cast(W) 3870720;
            nPower *= n;

            beta[3] = nPower
                * (((cast(W) 22276 * n - cast(W) 16929) * n
                    - cast(W) 15984) * n + cast(W) 12852)
                / cast(W) 362880;
            nPower *= n;

            beta[4] = nPower
                * ((-cast(W) 830251 * n - cast(W) 158400) * n
                    + cast(W) 197865)
                / cast(W) 7257600;
            nPower *= n;

            beta[5] = nPower
                * (-cast(W) 435388 * n + cast(W) 453717)
                / cast(W) 15966720;
            nPower *= n;

            beta[6] = nPower
                * cast(W) 20648693
                / cast(W) 638668800;
        }
        else
        {
            static assert(seriesOrder == 8);

            alpha[1] = nPower
                * (((((((-cast(W) 75900428 * n + cast(W) 37884525) * n
                    + cast(W) 42422016) * n - cast(W) 89611200) * n
                    + cast(W) 46287360) * n + cast(W) 63504000) * n
                    - cast(W) 135475200) * n + cast(W) 101606400)
                / cast(W) 203212800;
            nPower *= n;

            alpha[2] = nPower
                * ((((((cast(W) 148003883 * n + cast(W) 83274912) * n
                    - cast(W) 178508970) * n + cast(W) 77690880) * n
                    + cast(W) 67374720) * n - cast(W) 104509440) * n
                    + cast(W) 47174400)
                / cast(W) 174182400;
            nPower *= n;

            alpha[3] = nPower
                * (((((cast(W) 318729724 * n - cast(W) 738126169) * n
                    + cast(W) 294981280) * n + cast(W) 178924680) * n
                    - cast(W) 234938880) * n + cast(W) 81164160)
                / cast(W) 319334400;
            nPower *= n;

            alpha[4] = nPower
                * ((((-cast(W) 40176129013L * n
                    + cast(W) 14967552000L) * n
                    + cast(W) 6971354016L) * n
                    - cast(W) 8165836800L) * n
                    + cast(W) 2355138720L)
                / cast(W) 7664025600L;
            nPower *= n;

            alpha[5] = nPower
                * (((cast(W) 10421654396L * n
                    + cast(W) 3997835751L) * n
                    - cast(W) 4266773472L) * n
                    + cast(W) 1072709352L)
                / cast(W) 2490808320L;
            nPower *= n;

            alpha[6] = nPower
                * ((cast(W) 175214326799L * n
                    - cast(W) 171950693600L) * n
                    + cast(W) 38652967262L)
                / cast(W) 58118860800L;
            nPower *= n;

            alpha[7] = nPower
                * (-cast(W) 67039739596L * n
                    + cast(W) 13700311101L)
                / cast(W) 12454041600L;
            nPower *= n;

            alpha[8] = nPower
                * cast(W) 1424729850961L
                / cast(W) 743921418240L;

            nPower = n;

            beta[1] = nPower
                * (((((((cast(W) 31777436 * n - cast(W) 37845269) * n
                    + cast(W) 43097152) * n - cast(W) 42865200) * n
                    - cast(W) 752640) * n + cast(W) 104428800) * n
                    - cast(W) 180633600) * n + cast(W) 135475200)
                / cast(W) 270950400;
            nPower *= n;

            beta[2] = nPower
                * ((((((cast(W) 24749483 * n + cast(W) 14930208) * n
                    - cast(W) 100683990) * n + cast(W) 152616960) * n
                    - cast(W) 105719040) * n + cast(W) 23224320) * n
                    + cast(W) 7257600)
                / cast(W) 348364800;
            nPower *= n;

            beta[3] = nPower
                * (((((-cast(W) 232468668 * n + cast(W) 101880889) * n
                    + cast(W) 39205760) * n - cast(W) 29795040) * n
                    - cast(W) 28131840) * n + cast(W) 22619520)
                / cast(W) 638668800;
            nPower *= n;

            beta[4] = nPower
                * ((((cast(W) 324154477 * n
                    + cast(W) 1433121792L) * n
                    - cast(W) 876745056) * n
                    - cast(W) 167270400) * n
                    + cast(W) 208945440)
                / cast(W) 7664025600L;
            nPower *= n;

            beta[5] = nPower
                * (((cast(W) 457888660 * n
                    - cast(W) 312227409) * n
                    - cast(W) 67920528) * n
                    + cast(W) 70779852)
                / cast(W) 2490808320L;
            nPower *= n;

            beta[6] = nPower
                * ((-cast(W) 19841813847L * n
                    - cast(W) 3665348512L) * n
                    + cast(W) 3758062126L)
                / cast(W) 116237721600L;
            nPower *= n;

            beta[7] = nPower
                * (-cast(W) 1989295244L * n
                    + cast(W) 1979471673L)
                / cast(W) 49816166400L;
            nPower *= n;

            beta[8] = nPower
                * cast(W) 191773887257L
                / cast(W) 3719607091200L;
        }
    }


    bool applyForwardSeries(
        const W xiPrime,
        const W etaPrime,
        out W xi,
        out W eta) const
        pure nothrow @safe @nogc
    {
        const W c0 = cos(cast(W) 2 * xiPrime);
        const W ch0 = cosh(cast(W) 2 * etaPrime);
        const W s0 = sin(cast(W) 2 * xiPrime);
        const W sh0 = sinh(cast(W) 2 * etaPrime);

        if (!isFiniteScalar(c0) || !isFiniteScalar(ch0)
            || !isFiniteScalar(s0) || !isFiniteScalar(sh0))
            return false;

        const ComplexPair!W recurrence =
            ComplexPair!W(cast(W) 2 * c0 * ch0,
                          -cast(W) 2 * s0 * sh0);

        ComplexPair!W b1;
        ComplexPair!W b2;

        for (int k = seriesOrder; k >= 1; --k)
        {
            ComplexPair!W next =
                pairSub(pairMul(recurrence, b1), b2);
            next = pairWithRealAdded(next, _alpha[k]);
            b2 = b1;
            b1 = next;
        }

        const ComplexPair!W sin2ZetaPrime =
            ComplexPair!W(s0 * ch0, c0 * sh0);
        const ComplexPair!W correction =
            pairMul(sin2ZetaPrime, b1);

        xi = xiPrime + correction.re;
        eta = etaPrime + correction.im;

        return isFiniteScalar(xi) && isFiniteScalar(eta);
    }


    bool applyReverseSeries(
        const W xi,
        const W eta,
        out W xiPrime,
        out W etaPrime) const
        pure nothrow @safe @nogc
    {
        const W c0 = cos(cast(W) 2 * xi);
        const W ch0 = cosh(cast(W) 2 * eta);
        const W s0 = sin(cast(W) 2 * xi);
        const W sh0 = sinh(cast(W) 2 * eta);

        if (!isFiniteScalar(c0) || !isFiniteScalar(ch0)
            || !isFiniteScalar(s0) || !isFiniteScalar(sh0))
            return false;

        const ComplexPair!W recurrence =
            ComplexPair!W(cast(W) 2 * c0 * ch0,
                          -cast(W) 2 * s0 * sh0);

        ComplexPair!W b1;
        ComplexPair!W b2;

        for (int k = seriesOrder; k >= 1; --k)
        {
            ComplexPair!W next =
                pairSub(pairMul(recurrence, b1), b2);
            next = pairWithRealAdded(next, -_beta[k]);
            b2 = b1;
            b1 = next;
        }

        const ComplexPair!W sin2Zeta =
            ComplexPair!W(s0 * ch0, c0 * sh0);
        const ComplexPair!W correction =
            pairMul(sin2Zeta, b1);

        xiPrime = xi + correction.re;
        etaPrime = eta + correction.im;

        return isFiniteScalar(xiPrime) && isFiniteScalar(etaPrime);
    }


    bool forwardKernel(
        const W latitude,
        const W deltaLongitude,
        out W xi,
        out W eta) const
        pure nothrow @safe @nogc
    {
        const W poleTolerance =
            cast(W) 8 * W.epsilon
                * (halfPi!W > cast(W) 1 ? halfPi!W : cast(W) 1);

        if (fabs(fabs(latitude) - halfPi!W) <= poleTolerance)
        {
            xi = latitude < cast(W) 0 ? -halfPi!W : halfPi!W;
            eta = cast(W) 0;
            return true;
        }

        const W sinPhi = sin(latitude);
        const W cosPhi = cos(latitude);
        const W sinLambda = sin(deltaLongitude);
        const W cosLambda = cos(deltaLongitude);

        if (!isFiniteScalar(sinPhi) || !isFiniteScalar(cosPhi)
            || !isFiniteScalar(sinLambda) || !isFiniteScalar(cosLambda)
            || cosPhi == cast(W) 0)
            return false;

        const W tau = sinPhi / cosPhi;
        const W tauPrime = conformalTau(tau, _eccentricity);
        const W denominator = hypot2(tauPrime, cosLambda);

        if (!(denominator > cast(W) 0) || !isFiniteScalar(denominator))
            return false;

        const W xiPrime = atan2(tauPrime, cosLambda);
        const W etaPrime = asinh(sinLambda / denominator);

        if (!isFiniteScalar(xiPrime) || !isFiniteScalar(etaPrime))
            return false;

        return applyForwardSeries(xiPrime, etaPrime, xi, eta);
    }


    bool reverseKernel(
        const W xi,
        const W eta,
        out W latitude,
        out W deltaLongitude) const
        pure nothrow @safe @nogc
    {
        const W poleTolerance =
            cast(W) 64 * W.epsilon
                * (fabs(xi) > cast(W) 1 ? fabs(xi) : cast(W) 1);

        if (eta == cast(W) 0
            && fabs(fabs(xi) - halfPi!W) <= poleTolerance)
        {
            latitude = xi < cast(W) 0 ? -halfPi!W : halfPi!W;
            deltaLongitude = cast(W) 0;
            return true;
        }

        W xiPrime;
        W etaPrime;
        if (!applyReverseSeries(xi, eta, xiPrime, etaPrime))
            return false;

        const W sinhEtaPrime = sinh(etaPrime);
        W cosXiPrime = cos(xiPrime);

        if (!isFiniteScalar(sinhEtaPrime) || !isFiniteScalar(cosXiPrime))
            return false;

        if (cosXiPrime < cast(W) 0)
            cosXiPrime = cast(W) 0;

        const W r = hypot2(sinhEtaPrime, cosXiPrime);

        if (r == cast(W) 0)
        {
            latitude = xiPrime < cast(W) 0 ? -halfPi!W : halfPi!W;
            deltaLongitude = cast(W) 0;
            return true;
        }

        deltaLongitude = atan2(sinhEtaPrime, cosXiPrime);

        const W tauPrime = sin(xiPrime) / r;
        W tau;
        if (!geodeticTau(tauPrime, _eccentricity, tau))
            return false;

        latitude = atan(tau);

        return isFiniteScalar(latitude)
            && isFiniteScalar(deltaLongitude);
    }



    W longitudeDomainSlack() const
        pure nothrow @safe @nogc
    {
        const W maxDelta = maxLongitudeDifference!W;

        /*
         * Baseline representational slack: enough for independently rounded
         * public scalar longitudes to land on the nominal boundary without
         * materially widening it.
         */
        W slack =
            cast(W) 2 * cast(W) T.epsilon
                * (maxDelta > cast(W) 1 ? maxDelta : cast(W) 1);

        /*
         * Inside the ordinary terrestrial validation profile, the public
         * accuracy contract gives a stronger and more meaningful numerical
         * indistinguishability scale than raw machine epsilon.
         *
         * A recovered longitude that exceeds +/-60 degrees by less than the
         * corresponding projected-position error budget is classified as the
         * boundary itself and clamped there. This is needed because the
         * finite forward/reverse series are not bitwise inverse operations,
         * especially at the validated f=0.01 stress boundary.
         *
         * Outside this profile there is deliberately no fixed metre accuracy
         * promise, so only the representational slack above is used.
         */
        const W a = cast(W) _ellipsoid.semiMajorAxis;
        const W k0 = cast(W) _scaleFactorAtNaturalOrigin;
        const W falseEasting = cast(W) _falseEasting;
        const W falseNorthing = cast(W) _falseNorthing;

        const bool ordinaryTerrestrialProfile =
            a >= cast(W) 6_000_000
            && a <= cast(W) 7_000_000
            && k0 >= cast(W) 0.9
            && k0 <= cast(W) 1.1
            && fabs(falseEasting) <= cast(W) 2 * a
            && fabs(falseNorthing) <= cast(W) 2 * a;

        if (ordinaryTerrestrialProfile)
        {
            static if (is(T == float))
                enum W linearBudget = cast(W) 2.0;
            else
                enum W linearBudget = cast(W) 0.001;

            const W naturalScale = _a1 * k0;

            if (naturalScale > cast(W) 0 && isFiniteScalar(naturalScale))
            {
                const W contractSlack = linearBudget / naturalScale;
                if (contractSlack > slack)
                    slack = contractSlack;
            }
        }

        return slack;
    }


public:
    /** True when the prepared operation contains valid supported parameters. */
    @property bool isValid() const pure nothrow @safe @nogc
    {
        return _ellipsoid.isValid
            && _ellipsoid.flattening <= cast(T) 0.01
            && isFiniteScalar(_scaleFactorAtNaturalOrigin)
            && _scaleFactorAtNaturalOrigin > cast(T) 0
            && isFiniteScalar(_falseEasting)
            && isFiniteScalar(_falseNorthing)
            && isFiniteScalar(_eccentricity)
            && isFiniteScalar(_a1)
            && _a1 > cast(W) 0
            && isFiniteScalar(_originXi);
    }


    /**
     * Prepare a Transverse Mercator operation without throwing.
     *
     * Returns false for an invalid ellipsoid, flattening above 0.01, a
     * non-positive/non-finite scale factor, non-finite false offsets, or
     * non-representable derived constants.
     */
    static bool tryFromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfNaturalOrigin,
        const Longitude!T longitudeOfNaturalOrigin,
        const T scaleFactorAtNaturalOrigin,
        const T falseEasting,
        const T falseNorthing,
        out TransverseMercator result)
        pure nothrow @safe @nogc
    {
        if (!ellipsoid.isValid
            || ellipsoid.flattening > cast(T) 0.01
            || !isFiniteScalar(scaleFactorAtNaturalOrigin)
            || !(scaleFactorAtNaturalOrigin > cast(T) 0)
            || !isFiniteScalar(falseEasting)
            || !isFiniteScalar(falseNorthing))
            return false;

        TransverseMercator candidate;
        candidate._ellipsoid = ellipsoid;
        candidate._latitudeOfNaturalOrigin = latitudeOfNaturalOrigin;
        candidate._longitudeOfNaturalOrigin = longitudeOfNaturalOrigin;
        candidate._scaleFactorAtNaturalOrigin = scaleFactorAtNaturalOrigin;
        candidate._falseEasting = falseEasting;
        candidate._falseNorthing = falseNorthing;

        const W flattening = cast(W) ellipsoid.flattening;
        const W e2 = flattening * (cast(W) 2 - flattening);
        candidate._eccentricity = sqrt(e2);

        const W n = flattening / (cast(W) 2 - flattening);
        const W b1 = evaluateB1(n);
        candidate._a1 = cast(W) ellipsoid.semiMajorAxis * b1;

        if (!isFiniteScalar(candidate._eccentricity)
            || !isFiniteScalar(candidate._a1)
            || !(candidate._a1 > cast(W) 0))
            return false;

        fillCoefficients(n, candidate._alpha, candidate._beta);

        W originEta;
        if (!candidate.forwardKernel(
                cast(W) latitudeOfNaturalOrigin.radians,
                cast(W) 0,
                candidate._originXi,
                originEta))
            return false;

        if (!isFiniteScalar(candidate._originXi)
            || !isFiniteScalar(originEta)
            || fabs(originEta) > cast(W) 64 * W.epsilon)
            return false;

        result = candidate;
        return true;
    }


    /** Prepare a Transverse Mercator operation or throw on invalid parameters. */
    static TransverseMercator fromParameters(
        const Ellipsoid!T ellipsoid,
        const Latitude!T latitudeOfNaturalOrigin,
        const Longitude!T longitudeOfNaturalOrigin,
        const T scaleFactorAtNaturalOrigin,
        const T falseEasting,
        const T falseNorthing)
        @safe
    {
        TransverseMercator result;
        if (!tryFromParameters(
                ellipsoid,
                latitudeOfNaturalOrigin,
                longitudeOfNaturalOrigin,
                scaleFactorAtNaturalOrigin,
                falseEasting,
                falseNorthing,
                result))
            throw new GeodesyValueException(
                "Transverse Mercator requires a valid ellipsoid with 0 <= f <= 0.01, "
                ~ "finite k0 > 0, and finite false offsets.");

        return result;
    }


    /** Projection ellipsoid. */
    @property Ellipsoid!T ellipsoid() const pure nothrow @safe @nogc
    {
        return _ellipsoid;
    }


    /** EPSG 8801 latitude of natural origin. */
    @property Latitude!T latitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _latitudeOfNaturalOrigin;
    }


    /** EPSG 8802 longitude of natural origin. */
    @property Longitude!T longitudeOfNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _longitudeOfNaturalOrigin;
    }


    /** EPSG 8805 scale factor at natural origin. */
    @property T scaleFactorAtNaturalOrigin() const
        pure nothrow @safe @nogc
    {
        return _scaleFactorAtNaturalOrigin;
    }


    /** EPSG 8806 false easting. */
    @property T falseEasting() const pure nothrow @safe @nogc
    {
        return _falseEasting;
    }


    /** EPSG 8807 false northing. */
    @property T falseNorthing() const pure nothrow @safe @nogc
    {
        return _falseNorthing;
    }


    /**
     * Project a geographic coordinate.
     *
     * Non-polar inputs outside `abs(delta longitude) <= 60 degrees` are
     * rejected. Geographic poles are independent of source longitude.
     */
    bool tryForward(
        const GeographicCoordinate!T source,
        out ProjectedCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        const W latitude = cast(W) source.latitude.radians;
        W deltaLongitude = cast(W) 0;

        const W poleTolerance =
            cast(W) 8 * W.epsilon
                * (halfPi!W > cast(W) 1 ? halfPi!W : cast(W) 1);
        const bool isPole =
            fabs(fabs(latitude) - halfPi!W) <= poleTolerance;

        if (!isPole)
        {
            deltaLongitude = longitudeDifference(
                cast(W) source.longitude.radians,
                cast(W) _longitudeOfNaturalOrigin.radians);

            const W maxDelta = maxLongitudeDifference!W;
            const W domainSlack = longitudeDomainSlack();

            if (fabs(deltaLongitude) > maxDelta + domainSlack)
                return false;

            /*
             * Latitude/longitude strong types store radians. A source and
             * central meridian that were independently converted from exact
             * degree values can therefore straddle the nominal +/-60 degree
             * boundary by a few ulps. Treat that representational noise as the
             * boundary itself, but do not widen the documented domain.
             */
            if (fabs(deltaLongitude) > maxDelta)
                deltaLongitude =
                    deltaLongitude < cast(W) 0 ? -maxDelta : maxDelta;
        }

        W xi;
        W eta;
        if (!forwardKernel(latitude, deltaLongitude, xi, eta))
            return false;

        const W scale =
            _a1 * cast(W) _scaleFactorAtNaturalOrigin;

        const W easting =
            cast(W) _falseEasting + scale * eta;
        const W northing =
            cast(W) _falseNorthing
                + scale * (xi - _originXi);

        if (!isFiniteScalar(easting) || !isFiniteScalar(northing))
            return false;

        return ProjectedCoordinate!T.tryFromComponents(
            cast(T) easting,
            cast(T) northing,
            result);
    }


    /** Throwing convenience wrapper for `tryForward`. */
    ProjectedCoordinate!T forward(
        const GeographicCoordinate!T source) const
        @safe
    {
        ProjectedCoordinate!T result;
        if (!tryForward(source, result))
            throw new GeodesyValueException(
                "Transverse Mercator forward projection failed or the point "
                ~ "lies outside the supported +/-60 degree longitude domain.");
        return result;
    }


    /**
     * Reverse a projected coordinate.
     *
     * The result is rejected if it belongs outside the supported standard
     * sheet/domain.
     */
    bool tryReverse(
        const ProjectedCoordinate!T source,
        out GeographicCoordinate!T result) const
        pure nothrow @safe @nogc
    {
        if (!isValid)
            return false;

        const W scale =
            _a1 * cast(W) _scaleFactorAtNaturalOrigin;

        if (!(scale > cast(W) 0) || !isFiniteScalar(scale))
            return false;

        const W eta =
            (cast(W) source.easting - cast(W) _falseEasting) / scale;
        const W xi =
            (cast(W) source.northing - cast(W) _falseNorthing) / scale
            + _originXi;

        if (!isFiniteScalar(xi) || !isFiniteScalar(eta))
            return false;

        W latitude;
        W deltaLongitude;
        if (!reverseKernel(xi, eta, latitude, deltaLongitude))
            return false;

        const W poleTolerance =
            cast(W) 64 * W.epsilon
                * (halfPi!W > cast(W) 1 ? halfPi!W : cast(W) 1);
        const bool isPole =
            fabs(fabs(latitude) - halfPi!W) <= poleTolerance;

        if (isPole)
        {
            latitude = latitude < cast(W) 0
                ? -halfPi!W
                : halfPi!W;
            deltaLongitude = cast(W) 0;
        }
        else
        {
            const W maxDelta = maxLongitudeDifference!W;
            const W domainSlack = longitudeDomainSlack();

            if (fabs(deltaLongitude) > maxDelta + domainSlack)
                return false;

            if (fabs(deltaLongitude) > maxDelta)
                deltaLongitude =
                    deltaLongitude < cast(W) 0 ? -maxDelta : maxDelta;
        }

        const W longitude = addLongitude(
            cast(W) _longitudeOfNaturalOrigin.radians,
            deltaLongitude);

        Latitude!T latitudeValue;
        Longitude!T longitudeValue;

        if (!Latitude!T.tryFromRadians(cast(T) latitude, latitudeValue)
            || !Longitude!T.tryFromRadians(cast(T) longitude, longitudeValue))
            return false;

        result = GeographicCoordinate!T.fromComponents(
            latitudeValue,
            longitudeValue);
        return true;
    }


    /** Throwing convenience wrapper for `tryReverse`. */
    GeographicCoordinate!T reverse(
        const ProjectedCoordinate!T source) const
        @safe
    {
        GeographicCoordinate!T result;
        if (!tryReverse(source, result))
            throw new GeodesyValueException(
                "Transverse Mercator reverse projection failed or the point "
                ~ "lies outside the supported standard sheet/domain.");
        return result;
    }
}


unittest
{
    import std.exception : assertThrown;
    import std.math : fabs;

    static assert(is(TransverseMercator!float));
    static assert(is(TransverseMercator!double));
    static assert(is(TransverseMercator!real));

    static assert(seriesOrderFor!float == 6);
    static assert(seriesOrderFor!double == 8);
    static assert(seriesOrderFor!real == 8);

    const invalid = TransverseMercator!double.init;
    assert(!invalid.isValid);

    const wgs84 = Ellipsoid!double.fromInverseFlattening(
        6_378_137.0,
        298.257223563);

    const lat0 = Latitude!double.fromDegrees(0.0);
    const lon0 = Longitude!double.fromDegrees(15.0);

    const utmLike = TransverseMercator!double.fromParameters(
        wgs84, lat0, lon0, 0.9996, 500_000.0, 0.0);

    assert(utmLike.isValid);

    const naturalOrigin = GeographicCoordinate!double.fromComponents(lat0, lon0);
    const projectedOrigin = utmLike.forward(naturalOrigin);

    assert(fabs(projectedOrigin.easting - 500_000.0) < 1e-9);
    assert(fabs(projectedOrigin.northing) < 1e-9);

    const roundTrip = utmLike.reverse(projectedOrigin);
    assert(fabs(roundTrip.latitude.degrees) < 1e-12);
    assert(fabs(roundTrip.longitude.degrees - 15.0) < 1e-12);

    /*
     * EPSG 9807 worked example:
     * Airy 1830, British National Grid parameters.
     *
     * Published rounded result:
     *   E = 577274.99 m
     *   N =  69740.50 m
     */
    const airy1830 = Ellipsoid!double.fromInverseFlattening(
        6_377_563.396,
        299.3249646);

    const britishGrid = TransverseMercator!double.fromParameters(
        airy1830,
        Latitude!double.fromDegrees(49.0),
        Longitude!double.fromDegrees(-2.0),
        0.9996012717,
        400_000.0,
        -100_000.0);

    const epsgSource = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(50.5),
        Longitude!double.fromDegrees(0.5));

    const epsgProjected = britishGrid.forward(epsgSource);

    assert(fabs(epsgProjected.easting - 577_274.99) < 0.02);
    assert(fabs(epsgProjected.northing - 69_740.50) < 0.02);

    const epsgReverse = britishGrid.reverse(epsgProjected);
    assert(fabs(epsgReverse.latitude.degrees - 50.5) < 1e-10);
    assert(fabs(epsgReverse.longitude.degrees - 0.5) < 1e-10);

    // Longitude domain boundary.
    ProjectedCoordinate!double projected;
    const onBoundary = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(75.0)); // lon0 15 + 60
    assert(utmLike.tryForward(onBoundary, projected));

    const outsideBoundary = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(10.0),
        Longitude!double.fromDegrees(75.000001));
    assert(!utmLike.tryForward(outsideBoundary, projected));

    // Antimeridian normalization: -179.75 is +0.5 deg from +179.75.
    const antiMeridian = TransverseMercator!double.fromParameters(
        wgs84,
        Latitude!double.fromDegrees(0.0),
        Longitude!double.fromDegrees(179.75),
        1.0,
        0.0,
        0.0);

    const across = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(20.0),
        Longitude!double.fromDegrees(-179.75));

    const acrossProjected = antiMeridian.forward(across);
    const acrossReverse = antiMeridian.reverse(acrossProjected);

    assert(fabs(acrossReverse.latitude.degrees - 20.0) < 1e-10);
    assert(fabs(acrossReverse.longitude.degrees + 179.75) < 1e-10);

    // Pole longitude is degenerate; reverse canonicalizes it to lon0.
    const northPole = GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(90.0),
        Longitude!double.fromDegrees(-120.0));

    const projectedPole = utmLike.forward(northPole);
    const reversedPole = utmLike.reverse(projectedPole);

    assert(reversedPole.latitude.degrees == 90.0);
    assert(fabs(reversedPole.longitude.degrees - 15.0) < 1e-12);

    /*
     * Independent PROJ smoke vectors.
     *
     * Generated with pyproj 3.7.2 / PROJ 9.5.1 using:
     *
     *   +proj=tmerc +lat_0=0 +lon_0=15 +k=0.9996
     *   +x_0=500000 +y_0=0 +ellps=WGS84
     *
     * These are deliberately not self-roundtrip expectations. They cover the
     * central meridian, UTM-like +/-3 degrees, wider 35/55 degree offsets, and
     * the documented +60 degree boundary at low, mid, high, and southern
     * latitudes.
     */
    struct ProjReferenceCase
    {
        double latitudeDegrees;
        double longitudeDegrees;
        double easting;
        double northing;
    }

    const ProjReferenceCase[] projReferenceCases = [
        ProjReferenceCase(  0.0, 15.0,  500000.000000001746,        0.000000000000),
        ProjReferenceCase(  0.0, 12.0,  166021.443080541620,        0.000000000000),
        ProjReferenceCase(  0.0, 18.0,  833978.556919462280,        0.000000000000),

        ProjReferenceCase( 45.0, 15.0,  500000.000000001281,  4982950.400226552039),
        ProjReferenceCase( 45.0, 12.0,  263553.973898793454,  4987329.504698913544),
        ProjReferenceCase( 45.0, 18.0,  736446.026101209340,  4987329.504698913544),

        ProjReferenceCase( 80.0, 15.0,  500000.000000000291,  8881585.815988095477),
        ProjReferenceCase( 80.0, 12.0,  441867.784867201233,  8883084.955948302522),
        ProjReferenceCase( 80.0, 18.0,  558132.215132799465,  8883084.955948302522),

        ProjReferenceCase(  0.0, 50.0, 4664389.626846205443,        0.000000000000),
        ProjReferenceCase( 45.0, 50.0, 3248234.418058108538,  5616013.493153987452),
        ProjReferenceCase( 80.0, 50.0, 1139202.406108835712,  9080426.460095437244),

        ProjReferenceCase(  0.0, 70.0, 7873391.649043293670,        0.000000000000),
        ProjReferenceCase( 45.0, 70.0, 4723038.118970839307,  6674180.829577799886),
        ProjReferenceCase( 80.0, 70.0, 1416060.557045064168,  9353247.184040974826),

        ProjReferenceCase(  0.0, 75.0, 8919730.233713800088,        0.000000000000),
        ProjReferenceCase( 45.0, 75.0, 5050976.864025287330,  7039204.455768080428),
        ProjReferenceCase( 80.0, 75.0, 1469262.805167234968,  9435492.848205996677),

        ProjReferenceCase(-45.0, 75.0, 5050976.864025287330, -7039204.455768080428),
        ProjReferenceCase(-80.0, 70.0, 1416060.557045064168, -9353247.184040974826),
    ];

    foreach (const refCase; projReferenceCases)
    {
        const geographic = GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(refCase.latitudeDegrees),
            Longitude!double.fromDegrees(refCase.longitudeDegrees));

        const actualProjected = utmLike.forward(geographic);

        // 0.1 mm: intentionally tighter than the proposed 1 mm public target.
        assert(fabs(actualProjected.easting - refCase.easting) < 0.0001);
        assert(fabs(actualProjected.northing - refCase.northing) < 0.0001);

        const actualGeographic = utmLike.reverse(
            ProjectedCoordinate!double.fromComponents(
                refCase.easting,
                refCase.northing));

        assert(fabs(actualGeographic.latitude.degrees
            - refCase.latitudeDegrees) < 1e-10);
        assert(fabs(actualGeographic.longitude.degrees
            - refCase.longitudeDegrees) < 1e-10);
    }

    /*
     * Regression: at the validated f=0.01 / +/-60 degree stress boundary,
     * the finite reverse series can recover a longitude a few micrometres
     * ground-equivalent outside the nominal sheet. That must classify as the
     * boundary rather than fail.
     *
     * The projected coordinate below is independently produced by PROJ 9.7.1
     * (`poder_engsager`) for lat=-45 deg, lon=-45 deg with:
     *   a=6378137, f=0.01, lat0=49, lon0=15,
     *   k0=0.9996, FE=500000, FN=0.
     */
    const boundaryEllipsoid =
        Ellipsoid!double.fromFlattening(6_378_137.0, 0.01);

    const boundaryProjection =
        TransverseMercator!double.fromParameters(
            boundaryEllipsoid,
            Latitude!double.fromDegrees(49.0),
            Longitude!double.fromDegrees(15.0),
            0.9996,
            500_000.0,
            0.0);

    const boundaryProjected =
        ProjectedCoordinate!double.fromComponents(
            -4_064_935.6141685639,
            -12_378_431.863114327);

    GeographicCoordinate!double boundaryRecovered;
    assert(boundaryProjection.tryReverse(
        boundaryProjected,
        boundaryRecovered));

    assert(fabs(boundaryRecovered.latitude.degrees + 45.0) < 1e-9);
    assert(fabs(boundaryRecovered.longitude.degrees + 45.0) < 1e-9);

    // Projection-specific flattening bound.
    const tooFlat = Ellipsoid!double.fromFlattening(6_378_137.0, 0.02);
    TransverseMercator!double candidate;
    assert(!TransverseMercator!double.tryFromParameters(
        tooFlat, lat0, lon0, 1.0, 0.0, 0.0, candidate));

    assertThrown!GeodesyValueException(
        TransverseMercator!double.fromParameters(
            tooFlat, lat0, lon0, 1.0, 0.0, 0.0));
}
