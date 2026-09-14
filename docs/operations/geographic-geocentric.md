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

The reverse transformation is implemented as a hybrid numerical kernel rather
than as the former Bowring-plus-iteration sequence.

For ordinary non-degenerate oblate positions, `geodesy-d` uses the homogeneous
reduced-latitude Halley formulation described by Fukushima (2006).

At most two Halley updates are attempted. After each update the candidate is
accepted only when its scale-independent algebraic defect satisfies:

~~~text
defect <= 64 * working_epsilon * a
~~~

where `a` is the semi-major axis.

The factor 64 is a validated implementation bound for this algorithm. It is not
a library-wide approximate-equality policy.

If the fast candidate is not accepted, the conversion falls back to an oblate
specialization of the extended Vermeille formulation used by GeographicLib's
`Geocentric` implementation.

The robust branch follows the cancellation-avoiding algebra and branch
structure used by Karney, including:

- stable evaluation of the real cubic root;
- the three-real-root branch;
- cancellation-safe evaluation where direct `u + v` would be unstable;
- protection against small negative intermediate values caused only by
  roundoff;
- an analytic solution for the degenerate equatorial evolute.

For interior Cartesian points for which several geodetic normals exist, the
reverse transformation selects the nearest-ellipsoid,
minimum-absolute-height solution. This matches GeographicLib's canonical
solution on the supported oblate domain.

The exact equatorial interior/evolute region is routed directly to the robust
analytic branch. In that region a non-canonical equatorial normal can also have
zero Halley algebraic defect, so the defect alone cannot select the required
solution.

Extremely distant finite coordinates use a scaled asymptotic branch to avoid
avoidable intermediate overflow.

### Working precision

The public scalar type is preserved.

~~~text
float  -> double working precision -> float result
double -> double working precision -> double result
real   -> real working precision   -> real result
~~~

Direct single-precision evaluation was rejected because it is insufficient for
numerically sensitive Earth-scale interior and cusp cases.

### Numerical accuracy

A conservative public numerical-accuracy contract is defined for the validated
terrestrial domain:

~~~text
ellipsoids:
    WGS 84
    GRS 80
    Airy 1830

latitude:
    full legal range [-90 deg, +90 deg]

ellipsoidal height:
    -20 km through +100 km
~~~

Within that domain:

~~~text
float:
    represented Cartesian position <= 2 m
    ellipsoidal height             <= 0.1 m

double:
    represented Cartesian position <= 1 mm

real:
    represented Cartesian position <= 1 mm
~~~

Here, represented Cartesian position means the ECEF point obtained by applying
the forward transformation to the returned geodetic coordinate on the same
ellipsoid.

These limits describe numerical coordinate-conversion error. They do not
describe datum, reference-frame, measurement, survey, GNSS, or physical
position accuracy.

Outside the validated terrestrial domain, the documented robust and canonical
inverse semantics still apply, but the same absolute accuracy envelope is not
claimed.

See ADR-0005 for the algorithm-selection rationale, rejected alternatives,
validation evidence, and performance measurements.


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
