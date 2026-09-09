# Geographic/geocentric conversion — EPSG method 9602

## Status

Forward and reverse directions implemented.

## Scope

EPSG method 9602 converts between:

```text
GeodeticCoordinate
(latitude, longitude, ellipsoidal height)
```

and:

```text
GeocentricCoordinate
(X, Y, Z)
```

on the **same ellipsoid/reference frame**.

This is a coordinate conversion, not a datum transformation.

## Primary reference

**EPSG coordinate operation method 9602 — Geographic/geocentric conversions**, as specified by IOGP Report 373-07-2 / EPSG Guidance Note 7-2.

The formulas assume angles in radians and conventional geocentric axes:

- `Z` is positive along the rotation axis toward the north pole;
- `X` passes through the equator and the frame's prime meridian;
- `Y` passes through the equator at +90 degrees longitude.

Conventional EPSG geocentric systems use Greenwich as the prime meridian.

## Forward direction

For latitude `phi`, longitude `lambda`, ellipsoidal height `h`,
semi-major axis `a`, and first eccentricity squared `e²`:

```text
nu = a / sqrt(1 - e² sin²(phi))

X = (nu + h) cos(phi) cos(lambda)
Y = (nu + h) cos(phi) sin(lambda)
Z = ((1 - e²) nu + h) sin(phi)
```

where:

```text
e² = 2f - f²
```

## Reverse direction

Let:

```text
p = sqrt(X² + Y²)
b = a(1-f)
e'² = e² / (1-e²)
```

The direct EPSG/IOGP Bowring form is used as the initial latitude:

```text
q = atan2(Z*a, p*b)

phi = atan2(
    Z + e'²*b*sin³(q),
    p - e²*a*cos³(q)
)

lambda = atan2(Y, X)
```

`geodesy-d` evaluates `q` using the ratio-equivalent

```text
atan2(Z/b, p/a)
```

to avoid unnecessary large intermediate products.

The direct solution is then refined with the iterative EPSG relation:

```text
nu  = a / sqrt(1 - e² sin²(phi))
phi = atan2(Z + e²*nu*sin(phi), p)
```

A fixed maximum of eight refinement steps is used. Exact floating-point
stabilization may terminate the loop early. No global approximate-equality or
machine-epsilon comparison policy is introduced.

For height, EPSG gives:

```text
h = p / cos(phi) - nu
```

Near the rotation axis, `geodesy-d` uses the algebraically equivalent Z
equation because it is better conditioned:

```text
h = Z / sin(phi) - (1-e²)*nu
```

## Degenerate cases

### Ellipsoid centre

```text
X = Y = Z = 0
```

has no unique geodetic inverse. `tryGeocentricToGeodetic` returns `false`; the
throwing wrapper raises `GeodesyValueException`.

### Rotation axis

For:

```text
X = Y = 0
Z != 0
```

latitude is `+/- pi/2` and height is:

```text
|Z| - b
```

Longitude is mathematically indeterminate. The library returns **0 radians**
as a deterministic convention.

This convention is part of the API contract and does not imply that longitude
is physically defined at the pole.

## Units

The following values must use the same linear unit:

```text
ellipsoid axes
ellipsoidal height
X / Y / Z
```

EPSG geocentric coordinates conventionally use metres. `geodesy-d` does not
encode a linear unit in the scalar type.

## API

```d
bool tryGeodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc;

GeocentricCoordinate!T geodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid);

bool tryGeocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeodeticCoordinate!T result)
    pure nothrow @safe @nogc;

GeodeticCoordinate!T geocentricToGeodetic(T)(
    const GeocentricCoordinate!T source,
    const Ellipsoid!T ellipsoid);
```

## Initial validation

The deterministic test set contains:

1. the EPSG/IOGP WGS 84 North Sea worked example in both directions;
2. equatorial cases;
3. north- and south-axis cases;
4. explicit rejection of the ellipsoid centre;
5. a high-altitude forward/reverse round trip;
6. `float`, `double`, and `real` instantiation;
7. checked forward overflow behavior.

Published WGS 84 worked vector:

```text
latitude            53°48'33.820" N
longitude            2°07'46.380" E
ellipsoidal height  73.0 m

X = 3 771 793.968 m
Y =   140 253.342 m
Z = 5 124 304.349 m
```

Because the published Cartesian values are rounded to millimetres, the reverse
test uses tolerances compatible with those rounded inputs.

`double` remains the normative validation scalar.

## Validation status

The implementation is covered by:

- published EPSG/IOGP reference vectors;
- analytical and singularity/axis unit tests;
- PROJ smoke differential validation;
- a fixed-seed extended PROJ suite covering WGS 84, GRS 80, Airy 1830,
  a spherical ellipsoid, antimeridian-near inputs, near-polar inputs, and
  heights up to 1 billion linear units.

Further work such as GIGS vectors, benchmarks, and measured public accuracy
envelopes is useful but is not a v0.1 release blocker.
