/**
 * Private Equal Earth (EPSG 1078) polynomial kernel.
 *
 * Inputs use authalic latitude in radians, authalic radius and a canonical
 * longitude offset. This module intentionally does not select a public
 * ellipsoid, coordinate representation or API contract.
 *
 * The forward map is x = R dLambda cos(theta)/(sqrt(3)/2 * F'(theta)),
 * y = R F(theta), where theta = asin(sqrt(3)/2 sin(beta)).
 */
module geodesy.projection.internal.equal_earth_kernel;

import std.math : asin, cos, fabs, sin, sqrt;

private enum double a1 = 1.340264;
private enum double a2 = -0.081106;
private enum double a3 = 0.000893;
private enum double a4 = 0.003796;
private enum double k = 0.8660254037844386467637231707529361834714;

/** Evaluate the Equal Earth meridional polynomial F(theta). */
private double polynomial(double t)
    pure nothrow @safe @nogc
{
    const double t2 = t * t;
    const double t6 = t2 * t2 * t2;
    return t * (a1 + a2 * t2 + t6 * (a3 + a4 * t2));
}

/** Evaluate the derivative F'(theta) needed by both directions. */
private double derivative(double t)
    pure nothrow @safe @nogc
{
    const double t2 = t * t;
    const double t6 = t2 * t2 * t2;
    return a1 + 3.0 * a2 * t2 + t6 * (7.0 * a3 + 9.0 * a4 * t2);
}

/** Calculate the spherical/authalic forward kernel (no false offsets). */
package bool equalEarthForwardKernel(
    double radius,
    double beta,
    double deltaLongitude,
    out double x,
    out double y)
    pure nothrow @safe @nogc
{
    x = double.nan;
    y = double.nan;
    if (!(radius > 0.0) || radius != radius
        || fabs(beta) > 1.57079632679489661923
        || beta != beta
        || fabs(deltaLongitude) > 3.14159265358979323846
        || deltaLongitude != deltaLongitude)
        return false;

    const double theta = asin(k * sin(beta));
    const double d = derivative(theta);
    if (!(d > 0.0))
        return false;

    x = radius * deltaLongitude * cos(theta) / (k * d);
    y = radius * polynomial(theta);
    return x == x && y == y;
}

/**
 * Invert the bounded Equal Earth polynomial for a represented world map.
 * Reject points outside the curved map footprint, not just its y-range.
 */
package bool equalEarthReverseKernel(
    double radius,
    double x,
    double y,
    out double beta,
    out double deltaLongitude)
    pure nothrow @safe @nogc
{
    beta = double.nan;
    deltaLongitude = double.nan;

    if (!(radius > 0.0) || radius != radius
        || x != x || y != y)
        return false;

    const double tMax = asin(k);
    const double limit = polynomial(tMax);
    const double target = y / radius;
    if (!(fabs(target) <= limit))
        return false;

    double low = -tMax;
    double high = tMax;
    double t = target == 0.0 ? 0.0 : tMax * target / limit;
    foreach (iteration; 0 .. 72)
    {
        const double residual = polynomial(t) - target;
        if (residual > 0.0)
            high = t;
        else
            low = t;
        const double trial = t - residual / derivative(t);
        if (trial > low && trial < high)
            t = trial;
        else
            t = (low + high) * 0.5;
    }

    double sineBeta = sin(t) / k;
    if (sineBeta > 1.0)
    {
        if (sineBeta - 1.0 > 32.0 * double.epsilon)
            return false;
        sineBeta = 1.0;
    }
    else if (sineBeta < -1.0)
    {
        if (-1.0 - sineBeta > 32.0 * double.epsilon)
            return false;
        sineBeta = -1.0;
    }

    const double lon = (x / radius) * k * derivative(t) / cos(t);
    if (!(fabs(lon) <= 3.14159265358979323846 + 1e-13))
        return false;

    beta = asin(sineBeta);
    deltaLongitude = lon;
    return beta == beta && lon == lon;
}

@safe unittest
{
    import std.math : PI;

    double x, y;
    assert(equalEarthForwardKernel(1.0, 0.0, 0.0, x, y));
    assert(x == 0.0 && y == 0.0);

    assert(equalEarthForwardKernel(1.0, 0.0, PI, x, y));
    double beta, longitude;
    assert(equalEarthReverseKernel(1.0, x, y, beta, longitude));
    assert(fabs(beta) < 1e-12);
    assert(fabs(longitude - PI) < 1e-12);

    foreach (latitude; [-1.3, -0.7, 0.0, 0.7, 1.3])
        foreach (delta; [-3.0, -1.0, 0.0, 1.0, 3.0])
        {
            assert(equalEarthForwardKernel(6_371_000.0,
                latitude, delta, x, y));
            assert(equalEarthReverseKernel(6_371_000.0,
                x, y, beta, longitude));
            assert(fabs(beta - latitude) < 1e-12);
            assert(fabs(longitude - delta) < 1e-12);
        }

    assert(!equalEarthReverseKernel(1.0, 100.0, 0.0, beta, longitude));
    assert(!equalEarthForwardKernel(-1.0, 0.0, 0.0, x, y));
}
