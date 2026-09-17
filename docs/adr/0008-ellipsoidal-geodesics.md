# ADR-0008: Direct and inverse ellipsoidal geodesics

- Status: Proposed
- Date: 2026-09-17
- Applies to: direct and inverse geodesic calculations on a reference ellipsoid
- Depends on: ADR-0001, ADR-0002
- Supersedes: nothing

## Context

`geodesy-d` now provides independently validated geodetic coordinate,
reference-frame, Transverse Mercator, and UTM mathematics.

The next mathematical capability is the solution of the classical
ellipsoidal geodesic problems:

~~~text
direct problem

start position
    + initial azimuth
    + distance
        ->
end position
    + forward azimuth at the end point


inverse problem

start position
    + end position
        ->
shortest surface distance
    + initial azimuth
    + forward azimuth at the end point
~~~

The implementation must remain useful independently of PROJ or
GeographicLib at runtime.

It must also remain robust at the cases where simpler classical
implementations, especially Vincenty-style inverse iteration, are known to
be problematic:

- nearly antipodal points;
- exactly antipodal or otherwise non-unique configurations;
- poles;
- coincident points;
- very short geodesics;
- equatorial and meridional geodesics;
- longitude discontinuities.

## Primary numerical reference

The primary mathematical reference is:

Charles F. F. Karney,
"Algorithms for geodesics",
Journal of Geodesy 87, 43-55 (2013),
DOI 10.1007/s00190-012-0578-z.

The GeographicLib geodesic addenda are also normative research input where
they correct or refine implementation details from the published paper.

The implementation strategy follows Karney's auxiliary-sphere formulation,
series expansions, robust inverse starting strategy, and safeguarded inverse
iteration.

The implementation must not be based on Vincenty's direct or inverse
algorithms.

Vincenty may be used only as historical or comparative material.

## Independent reference implementations

Validation roles are intentionally separated.

### GeographicLib `Geodesic`

The current GeographicLib `Geodesic` implementation is a primary
implementation reference for:

- algorithm structure;
- series coefficients;
- special-case handling;
- inverse starting strategy;
- convergence safeguards;
- angle semantics.

It must not be the sole numerical evidence for geodesy-d because the
geodesy-d implementation is expected to follow the same Karney family of
algorithms.

### GeographicLib `GeodesicExact`

`GeodesicExact` uses a different elliptic-integral formulation and is the
preferred differential oracle for the ordinary supported ellipsoid profile.

It therefore provides stronger independent numerical evidence than comparing
only against the ordinary GeographicLib series implementation.

### PROJ

PROJ provides an interoperability oracle.

Its geodesic implementation also derives from Karney/GeographicLib work, so
agreement with PROJ is useful but is not considered mathematically
independent evidence by itself.

### High-precision reference data

Published GeographicLib geodesic test data and other high-precision vectors
may be used to validate wide `real` implementations without reducing the
reference to binary64 precision.

## Decision

Implement a prepared geodesic solver parameterized by the public scalar
type:

~~~d
Geodesic!T
~~~

where:

~~~text
T = float
  | double
  | real
~~~

The first accepted implementation covers only the direct and inverse
geodesic problems.

Geodesic lines, polygon area accumulation, arc-mode direct operations,
reduced length, geodesic scale, longitude unrolling, and other extended
quantities are deferred.

## Coordinate model

Direct and inverse geodesic problems operate on the ellipsoid surface.

The existing:

~~~d
GeographicCoordinate!T
~~~

is therefore the canonical input and output position type.

`GeodeticCoordinate!T` is not used because ellipsoidal height is not part of
the surface-geodesic problem.

No datum or CRS identifier is embedded in the coordinate or solver.

The caller remains responsible for using coordinates and an ellipsoid that
belong to the same geodetic frame.

## Prepared solver

`Geodesic!T` represents a geodesic solver prepared for one reference
ellipsoid.

Conceptually:

~~~d
struct Geodesic(T)
if (isGeodesyScalar!T)
~~~

Construction should follow the existing checked/throwing API pattern:

~~~d
static bool tryFromEllipsoid(
    const Ellipsoid!T ellipsoid,
    out Geodesic result)
    pure nothrow @safe @nogc;

static Geodesic fromEllipsoid(
    const Ellipsoid!T ellipsoid)
    @safe;
~~~

Expensive coefficient generation should occur during solver construction
rather than on every direct or inverse operation.

`Geodesic.init` should be invalid unless a compelling implementation reason
justifies an identity-like state. No such reason is currently known.

## Ellipsoid support profile

The first implementation supports oblate ellipsoids and spheres within:

~~~text
a > 0
0 <= f <= 0.01
~~~

where `a` is the semi-major axis and `f` is flattening.

A sphere is explicitly supported.

There is no Earth-size restriction.

The linear unit of all returned distances is the same unit used by the
ellipsoid semi-major axis.

For example:

~~~text
a expressed in metres     -> distances in metres
a expressed in kilometres -> distances in kilometres
~~~

The type system does not encode that unit.

Prolate ellipsoids are outside the initial contract because the current
`Ellipsoid!T` model is defined for the existing non-negative flattening
policy.

Supporting prolate ellipsoids later requires an explicit review of the
ellipsoid model and is not part of this ADR.

## Scalar and working-precision policy

Public scalar preservation follows the rest of geodesy-d.

The initial working-precision and series-order policy is:

~~~text
public float
    working scalar: double
    series order:   6

public double
    working scalar: double
    series order:   6

public real, mant_dig == 53
    working scalar: real
    series order:   6

public real, mant_dig == 64
    working scalar: real
    series order:   7

public real, mant_dig == 113
    working scalar: real
    series order:   8
~~~

The `float` policy deliberately differs from a native-float GeographicLib
configuration.

Public float inputs are first represented as float and are then promoted to
double working precision. This is consistent with the accepted
Transverse Mercator scalar policy.

The validation program may tighten this mapping before ADR acceptance if
measured evidence shows a better mapping.

It must not reduce the documented accuracy contract without an explicit
decision.

## Direct result

The initial result type is conceptually:

~~~d
struct GeodesicDirectResult(T)
{
    GeographicCoordinate!T position;
    Angle!T finalAzimuth;
}
~~~

`finalAzimuth` is the forward azimuth at point 2: the heading of the same
geodesic continuing beyond point 2.

It is not the back azimuth from point 2 to point 1.

## Inverse result

The initial inverse result type is conceptually:

~~~d
struct GeodesicInverseResult(T)
{
    T distance;
    Angle!T initialAzimuth;
    Angle!T finalAzimuth;
}
~~~

`distance` is the shortest geodesic distance between the two positions.

Both azimuths describe the selected forward direction from point 1 toward
point 2 and its continuation at point 2.

## Operational API

The expected checked surface is conceptually:

~~~d
bool tryDirect(
    GeographicCoordinate!T start,
    Angle!T initialAzimuth,
    T distance,
    out GeodesicDirectResult!T result)
    const pure nothrow @safe @nogc;

bool tryInverse(
    GeographicCoordinate!T start,
    GeographicCoordinate!T end,
    out GeodesicInverseResult!T result)
    const pure nothrow @safe @nogc;
~~~

Throwing convenience operations should mirror these as:

~~~d
direct(...)
inverse(...)
~~~

using `GeodesyValueException` for invalid solver state, non-finite scalar
inputs, or a numerical failure that the checked API reports as `false`.

Exact public naming is not accepted until GEO-A validates the API contract.

## Direct-distance semantics

A finite direct distance may be positive, zero, or negative.

Negative distance means travelling along the same geodesic in the opposite
signed direction.

The implementation may mathematically evaluate distances longer than a
half-circumference.

However the initial fixed accuracy guarantee applies only to the ordinary
profile:

~~~text
abs(distance) <= pi * a
0 <= f <= 0.01
~~~

This covers the distance scale required by the shortest inverse problem.

Results outside that ordinary direct-distance profile may still be
supported, but no fixed absolute or scale-relative guarantee is implied
until separately validated.

Repeated-point generation along very long or repeatedly wrapping geodesics
belongs to a future `GeodesicLine` capability.

## Longitude semantics

Public geographic results use the existing `Longitude!T` representation.

Returned longitudes are canonicalized to the library's half-open normalized
form:

~~~text
[-pi, +pi)
~~~

Longitude unrolling is not part of the first API because an unrolled
longitude cannot be represented by `Longitude!T`.

A future geodesic-line or extended-result API may expose unrolled longitude
separately if required.

## Azimuth semantics

Input azimuth is an arbitrary finite `Angle!T`.

The solver normalizes it internally.

Returned azimuths are canonicalized to:

~~~text
[-pi, +pi)
~~~

The first API reuses `Angle!T`.

A dedicated `Azimuth!T` type is deliberately not introduced yet.

Such a type should only be added when multiple independent APIs demonstrate
that azimuth-specific semantic behavior deserves a reusable abstraction.

## Pole semantics

Pole calculations are valid.

Azimuth at a pole is understood by the standard limiting convention: keep
longitude fixed and approach the pole along latitude.

GEO-A must freeze exact public behavior for:

- north pole;
- south pole;
- pole-to-pole paths;
- paths beginning or ending at a pole.

## Coincident and non-unique inverse solutions

The inverse distance is uniquely defined even when the geodesic itself is
not unique.

Important non-unique cases include:

- coincident points;
- opposite poles;
- antipodal points on a sphere;
- selected antipodal or near-antipodal configurations on an ellipsoid.

`tryInverse` must not fail merely because more than one shortest geodesic
exists.

It must return:

- the shortest distance;
- one deterministic canonical azimuth pair.

The exact tie-breaking convention for non-unique azimuths is not fixed by
this Proposed ADR.

GEO-A must probe authoritative implementations and analytical symmetries and
then record a deterministic geodesy-d convention before implementation is
accepted.

Tests for genuinely non-unique cases must not incorrectly require one
arbitrary oracle azimuth when multiple azimuth pairs are mathematically
valid.

## Signed zero

IEEE signed zero must not accidentally become undocumented public policy.

Internal use of signed zero is permitted where needed for stable branch
selection or limiting calculations.

GEO-A must determine which public zero-valued azimuth and longitude results
are canonicalized to mathematical zero and where sign carries a necessary
directional convention.

Any retained signed-zero behavior must be documented explicitly.

## Inverse numerical strategy

The inverse implementation must include the robust Karney strategy rather
than an unguarded Newton iteration.

This includes, where applicable:

- special treatment of meridional and equatorial cases;
- short-line handling;
- robust longitude-difference evaluation;
- antipodal starting estimates;
- the astroid construction used near the antipodal singular region;
- Newton iteration using the appropriate derivative/reduced-length
  relationship;
- safeguarded bracketing/bisection fallback;
- a finite iteration bound;
- explicit non-convergence reporting.

Iteration behavior is part of validation evidence.

Round-trip success alone is not sufficient evidence for inverse robustness.

## Numerical implementation rules

The implementation should follow the numerical practices already accepted
elsewhere in geodesy-d where applicable:

- explicit working precision;
- no broad `@fastmath`;
- stable angle reduction;
- compensated arithmetic where materially useful;
- Horner evaluation for polynomial coefficient generation/evaluation;
- Clenshaw summation for trigonometric series where appropriate;
- finite iteration bounds;
- no hidden allocation in the numerical core.

## Initial accuracy contract

Accuracy is expressed relative to the ellipsoid scale because the
`Ellipsoid!T` linear unit is not encoded in the type.

For the ordinary profile, the provisional acceptance ceilings are:

~~~text
float

    endpoint surface error / a <= 1e-6
    inverse distance error / a <= 1e-6

double

    endpoint surface error / a <= 2e-10
    inverse distance error / a <= 2e-10

real

    portable endpoint surface error / a <= 2e-10
    portable inverse distance error / a <= 2e-10
~~~

For an Earth-sized ellipsoid this corresponds approximately to:

~~~text
float   <= several metres
double  <= about 1.3 mm
real    <= about 1.3 mm portable guarantee
~~~

These are acceptance ceilings, not expected typical errors.

The validation program should tighten them if the measured corpus supports a
materially stronger stable guarantee.

Wider `real` implementations should preserve their additional precision
internally even though the portable public guarantee cannot assume more than
binary64-class precision.

## Degenerate azimuth accuracy

Azimuth error is not meaningful where the geodesic direction is
mathematically non-unique or ill-conditioned.

Azimuth differential tests must therefore classify cases before applying a
scalar angular tolerance.

Distance and endpoint correctness remain testable in such cases.

## Deferred functionality

The first implementation deliberately excludes:

- `GeodesicLine`;
- repeated positions along one prepared line;
- arc-length direct mode;
- longitude unrolling;
- reduced length;
- geodesic scales;
- area under a geodesic;
- polygon area accumulation;
- geodesic intersection;
- nearest-point-on-geodesic operations;
- rhumb lines;
- prolate ellipsoids.

These may be added later only when a concrete consumer justifies them.

## Validation requirement

This ADR cannot become `Accepted` until all mandatory gates in
`docs/GEODESIC_VALIDATION_PLAN.md` pass.

The implementation must not be accepted merely because direct followed by
inverse, or inverse followed by direct, round-trips.

Independent numerical evidence and adversarial convergence evidence are
mandatory.

## Consequences

This decision gives geodesy-d a complete robust surface-distance primitive
without pulling in a CRS database or native geospatial runtime.

It also creates a foundation for later:

- geodesic lines;
- geographic measurement;
- geodesic polygon operations;
- higher-level GIS algorithms.

Those capabilities remain separate future decisions.

## Open items before acceptance

GEO-A must resolve and document:

1. exact coincident-point azimuth convention;
2. exact antipodal tie-breaking convention;
3. signed-zero treatment at public boundaries;
4. exact canonical azimuth interval endpoint behavior;
5. behavior for direct distances outside the ordinary accuracy profile;
6. final public names and result-type layout.

These are contract questions, not implementation details.
