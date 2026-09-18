# ADR-0008: Direct and inverse ellipsoidal geodesics

- Status: Proposed
- Date: 2026-09-17
- Implementation status: public direct/inverse slice complete as of 2026-09-18;
  remaining acceptance gates are tracked in `docs/GEODESIC_VALIDATION_PLAN.md`
- Applies to: direct and inverse geodesic calculations on a reference ellipsoid
- Depends on: ADR-0001, ADR-0002
- Supersedes: nothing

## Context

`geodesy-d` now provides independently validated geodetic coordinate,
reference-frame, Transverse Mercator, and UTM mathematics.

The classical direct and inverse ellipsoidal geodesic problems are now
implemented as a public `geodesy-d` capability:

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

Validation has retained this mapping. In particular, x86-64 extended
`real` with `mant_dig == 64` uses order 7, while public `float` is evaluated in
double working precision.

The mapping must not be weakened without an explicit decision and renewed
validation.

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

The implemented checked surface is:

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

Throwing `direct(...)` and `inverse(...)` convenience operations are not
part of the initial public geodesic surface.

The prepared solver retains the existing throwing `fromEllipsoid(...)`
construction convenience, while numerical direct/inverse operations are
exposed through their checked `try...` forms. A later convenience layer may be
added only if a concrete consumer justifies it.

GEO-A validated the public names and result layout implemented above.

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

## Angular canonicalization

GeographicLib and PROJ deliberately preserve some IEEE and endpoint
distinctions such as:

~~~text
+0 versus -0
+180 degrees versus -180 degrees
+540 degrees versus -540 degrees
~~~

GEO-A research demonstrated that these distinctions can affect returned
azimuths even when the represented mathematical direction or surface point
is equivalent.

geodesy-d deliberately does not expose those representation details as
public geodesic semantics.

Before entering the numerical kernel:

- latitude zero is canonicalized to positive mathematical zero;
- longitude zero is canonicalized to positive mathematical zero;
- longitude is normalized to `[-pi, +pi)`;
- input azimuth is normalized to `[-pi, +pi)`;
- exact angular zero is canonicalized to positive mathematical zero.

Therefore:

~~~text
+pi azimuth      -> -pi
-pi azimuth      -> -pi
+3*pi azimuth    -> -pi
-3*pi azimuth    -> -pi

+2*pi azimuth    -> +0
-2*pi azimuth    -> +0
~~~

Public outputs follow the same convention:

~~~text
longitude: [-pi, +pi)
azimuth:   [-pi, +pi)
exact zero: +0
~~~

Returned latitude zero is likewise canonicalized to positive mathematical
zero.

The sign bit of IEEE zero is not part of the public contract.

## Longitude semantics

Public geographic results use the existing `Longitude!T` representation.

Longitude unrolling is not part of the first API because an unrolled
longitude cannot be represented by `Longitude!T`.

A future geodesic-line or extended-result API may expose unrolled longitude
separately if required.

## Azimuth semantics

Input azimuth is an arbitrary finite `Angle!T`.

The solver canonicalizes it according to the angular rules above before
numerical evaluation.

The first API reuses `Angle!T`.

A dedicated `Azimuth!T` type is deliberately not introduced yet.

Such a type should only be added when multiple independent APIs demonstrate
that azimuth-specific semantic behavior deserves a reusable abstraction.

## Pole semantics

Pole calculations are valid.

Azimuth at a pole is understood by the standard limiting convention: keep
longitude fixed and approach the pole along latitude.

Consequently, the longitude component supplied for a pole remains relevant
to the directional reference frame for a non-coincident geodesic.

The solver must therefore not globally replace pole longitude with zero.

This is distinct from positional identity: all longitudes at one pole
represent the same surface point.

If both inverse endpoints represent that same pole, the points are
coincident and the coincident-point rule below applies.

For paths between distinct points involving a pole, the normalized supplied
pole longitude participates in the limiting azimuth convention.

For opposite poles the shortest geodesic is not unique. The non-unique
inverse rule below applies.

## Coincident and non-unique inverse solutions

### Coincident surface points

Coincidence is a geometric property, not merely scalar component equality.

Coincident points include:

- equal latitude and equivalent longitude;
- `+pi` and `-pi` longitude aliases;
- any two coordinates at the north pole;
- any two coordinates at the south pole.

GEO-A research showed that GeographicLib and PROJ intentionally return
representation-dependent azimuths for these cases.

Examples included zero-distance inverse results with azimuths such as:

~~~text
0 degrees
180 degrees
-180 degrees
57 degrees
-123 degrees
~~~

depending only on signed zero, antimeridian representation, or the arbitrary
longitude attached to a pole.

geodesy-d deliberately does not expose that behavior.

For coincident surface points, inverse returns exactly:

~~~text
distance       = +0
initialAzimuth = +0
finalAzimuth   = +0
~~~

This is a documented semantic divergence from GeographicLib and PROJ.

### Zero-distance direct problem

Direct distance zero is different from the inverse coincident-point case.

A direct operation includes an explicitly supplied geodesic direction.

Therefore for:

~~~text
distance == 0
~~~

the result is:

- the canonicalized start position;
- the canonicalized supplied initial azimuth as `finalAzimuth`.

Thus a zero-distance direct operation preserves the specified line
direction even though the endpoint position is unchanged.

### Non-unique shortest geodesics

Some distinct endpoint pairs admit multiple shortest geodesics.

Important cases include:

- opposite poles;
- antipodal points on a sphere;
- selected antipodal configurations on an oblate ellipsoid.

`tryInverse` must succeed for these cases.

The returned distance is the shortest geodesic distance and is normative.

The returned azimuth pair identifies one deterministic shortest geodesic,
but the public API does not claim that the selected azimuth pair is the only
geometrically valid solution.

Validation of genuinely non-unique cases therefore must not require equality
with one arbitrary oracle azimuth pair.

Instead it must verify:

- the shortest distance against the independent oracle;
- deterministic output for identical canonical inputs;
- canonical public angle representation;
- that the returned azimuth pair describes a valid shortest geodesic, for
  example by independent direct reconstruction where appropriate.

Equivalent input representations are canonicalized before solution.

This prevents `+pi/-pi` aliases and signed-zero differences from selecting
different public results merely because of IEEE representation.

The solver is not required to enumerate all shortest geodesics.

## Signed zero

IEEE signed zero is an internal numerical detail only.

At public geodesic boundaries:

~~~text
angular -0 -> +0
linear  -0 -> +0
~~~

whenever the mathematical result is exactly zero.

Internal signed zero may still be used temporarily where useful for stable
numerical branch selection, but it must not leak into public result
semantics.

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

## Acceptance status

GEO-A research resolved the initial edge-semantics questions, and the production
implementation now demonstrates those semantics through the public API:

- coincident-point behavior;
- non-unique antipodal behavior;
- signed-zero treatment;
- azimuth canonicalization;
- antimeridian canonicalization;
- negative direct distance;
- pole limiting semantics;
- final public names and result-type layout.

The direct and inverse implementation, inverse dispatch/canonicalization, public
`float`/`double`/`real` API, and aggregate `import geodesy;` export are complete.

Independent GeographicLib 2.7 `GeodesicExact` differential harnesses also
provide strong GEO-C and adversarial inverse evidence. However, implementation
completion is intentionally distinct from ADR acceptance.

The remaining acceptance program includes the gates still marked OPEN or
PARTIAL in `docs/GEODESIC_VALIDATION_PLAN.md`, notably authoritative external
reference vectors, PROJ interoperability, the full API/runtime stress contract,
and the portable compiler/platform matrix.

ADR-0008 therefore remains `Proposed` until every mandatory validation-plan
gate is `PASS`.
