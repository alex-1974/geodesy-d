# Ellipsoidal geodesic validation plan

- Status: Planned
- Branch: `research/geodesics`
- Depends on: ADR-0008
- Target: direct and inverse ellipsoidal geodesics

## Purpose

This document defines the evidence required before the geodesy-d direct and
inverse ellipsoidal geodesic implementation can be considered accepted.

The intended implementation follows the Karney geodesic algorithm family.

Validation must therefore demonstrate more than self-consistency.

In particular:

~~~text
direct -> inverse round trip
inverse -> direct round trip
~~~

is useful property evidence but is not an independent numerical oracle.

The acceptance program requires:

- analytical and semantic tests;
- authoritative reference cases;
- a numerically distinct GeographicLib exact oracle;
- PROJ interoperability comparison;
- adversarial inverse convergence testing;
- API/runtime contract testing;
- compiler/platform testing.

## Scope

Initial validation covers:

~~~text
Geodesic!T

GeodesicDirectResult!T
GeodesicInverseResult!T

direct distance problem
inverse shortest-geodesic problem
~~~

for:

~~~text
T = float
  | double
  | real
~~~

It excludes:

~~~text
GeodesicLine
arc-mode direct solution
longitude unrolling
reduced length
geodesic scale
geodesic area
polygon area
geodesic intersection
rhumb lines
prolate ellipsoids
~~~

## Normative support profile

Initial ellipsoid profile:

~~~text
a > 0
0 <= f <= 0.01
~~~

Sphere:

~~~text
f == 0
~~~

is mandatory.

No Earth-size restriction applies.

All linear outputs use the same unit as `a`.

## Ordinary direct-distance accuracy profile

Fixed acceptance accuracy applies to:

~~~text
abs(distance) <= pi * a
0 <= f <= 0.01
~~~

Longer finite direct distances may be evaluated, but are outside the first
fixed-accuracy profile unless later validation explicitly extends it.

## Scalar model

Expected implementation mapping:

~~~text
public float
    working double
    order 6

public double
    working double
    order 6

public real / mant_dig 53
    working real
    order 6

public real / mant_dig 64
    working real
    order 7

public real / mant_dig 113
    working real
    order 8
~~~

The validation suite must record the actual `real.mant_dig` on every
platform.

## Oracle representation rule

Reference generation must begin from the exact value represented by the
public scalar input.

This is especially important for `float`.

The correct oracle conversion is conceptually:

~~~text
public float angle
    -> stored float radians
    -> promote radians to double
    -> convert promoted radians to oracle degrees
~~~

The validation harness must not perform:

~~~text
stored float radians
    -> float degrees
    -> double oracle input
~~~

because that introduces an additional rounding step not present in the
production operation.

This rule is inherited from the Transverse Mercator validation experience.

## Error metrics

### Inverse distance

For inverse distance:

~~~text
normalized_distance_error =
    abs(candidate_distance - reference_distance) / a
~~~

This metric is independent of the caller's chosen linear unit.

### Direct endpoint

Endpoint error is measured as surface separation between the candidate
endpoint and the reference endpoint on the same ellipsoid.

The reference/oracle inverse solution should be used to compute that
separation.

Then:

~~~text
normalized_endpoint_error =
    endpoint_surface_separation / a
~~~

Simple latitude/longitude component subtraction is not the acceptance
metric.

### Azimuth

Azimuth error uses the shortest normalized angular difference.

Azimuth comparison is applied only when the selected geodesic direction is
mathematically unique and sufficiently well-conditioned.

Coincident and genuinely non-unique antipodal cases must be classified
separately.

## Provisional acceptance ceilings

### float

~~~text
normalized inverse distance error <= 1e-6
normalized direct endpoint error  <= 1e-6
~~~

### double

~~~text
normalized inverse distance error <= 2e-10
normalized direct endpoint error  <= 2e-10
~~~

### real

Portable requirement:

~~~text
normalized inverse distance error <= 2e-10
normalized direct endpoint error  <= 2e-10
~~~

Wider `real` platforms must additionally demonstrate that the implementation
does not collapse all calculations to binary64 working precision.

These ceilings may be tightened before acceptance.

Loosening them requires explicit review and recorded justification.

## GEO-A — contract and analytical semantics

Purpose:

Freeze the public mathematical semantics before production implementation is
accepted.

Required categories include:

### Construction

- valid sphere;
- valid WGS84-like ellipsoid;
- flattening exactly `0.01`;
- invalid ellipsoid;
- invalid solver default state;
- scale independence of the ellipsoid linear unit.

### Direct analytical cases

- zero distance;
- positive equatorial distance;
- negative equatorial distance;
- north-going meridian;
- south-going meridian;
- antimeridian crossing;
- north-pole start;
- south-pole start;
- endpoint at a pole;
- spherical great-circle cases.

### Inverse analytical cases

- same point;
- same longitude;
- same latitude on the equator;
- antimeridian-separated points;
- pole-to-point;
- pole-to-pole;
- spherical antipodes;
- ellipsoidal near-antipodes.

### Canonicalization

GEO-A must freeze:

- longitude output interval;
- azimuth output interval;
- `+pi` versus `-pi` canonical endpoint;
- signed-zero behavior;
- coincident-point azimuth convention;
- non-unique antipodal tie-breaking convention.

### Negative distance

Direct negative distance is mandatory.

Its semantics must be verified independently rather than inferred only from
positive-distance symmetry.

GEO-A passes only when all public semantic questions in ADR-0008 are
resolved.

## GEO-A semantic research result

The pre-implementation semantic probe was executed on 2026-09-17 against:

~~~text
GeographicLib 2.7
GeographicLib::Geodesic
GeographicLib::GeodesicExact
PROJ 9.7.1 geodesic C API
~~~

All three implementations agreed on ordinary and difficult numerical
semantics in the sampled cases.

The probe also demonstrated that several degenerate azimuth results are
representation-dependent rather than geometrically unique.

Observed examples included:

- coincident `(0,+0)` returning `180/180` azimuths;
- an equivalent signed-zero coincidence returning `0/0`;
- `+180/-180` longitude aliases selecting opposite signed azimuth endpoints;
- same-pole coincident points returning azimuths derived from arbitrary pole
  longitude differences;
- exact antipodal cases selecting different but valid azimuth pairs
  depending on `+180/-180` and signed-zero representation;
- `+180`, `-180`, `+540`, and `-540` direct azimuth inputs preserving
  different endpoint representations despite equivalent direction;
- negative direct distance operating correctly along the signed geodesic;
- antimeridian start aliases producing identical endpoint positions.

GEO-A therefore freezes a geodesy-d-specific canonical public contract:

~~~text
longitude output      [-pi, +pi)
azimuth output        [-pi, +pi)
exact public zero     +0
+pi angular alias     -> -pi
signed-zero aliases   -> mathematical zero
~~~

Inverse coincident surface points return:

~~~text
distance       = +0
initialAzimuth = +0
finalAzimuth   = +0
~~~

A direct zero-distance operation instead preserves the canonicalized supplied
line direction.

For non-unique shortest geodesics, distance is normative and the returned
azimuth pair identifies one deterministic valid shortest geodesic.

GEO-A remains an implementation gate until the geodesy-d production solver
demonstrates these semantics.

## GEO-B — authoritative reference vectors

Purpose:

Compare against externally generated, authoritative or high-precision
geodesic vectors.

Required sources should include:

- published Karney examples where suitable;
- GeographicLib high-precision geodesic test data;
- explicit regression cases documented by the GeographicLib project;
- hand-derived spherical cases.

The corpus must include ordinary and difficult cases.

Minimum categories:

~~~text
ordinary short
ordinary regional
intercontinental
equatorial
meridional
polar
near-antipodal
exact or mathematically ambiguous antipodal
very short
sphere
f near 0.01
~~~

Reference vectors must retain enough decimal precision that a wide `real`
test is not silently reduced to binary64 reference quality.

## GEO-C — GeographicLib Exact differential validation

Purpose:

Use a numerically distinct implementation as the primary differential
oracle.

Preferred oracle:

~~~text
GeographicLib::GeodesicExact
~~~

Required scalar validation:

~~~text
float
double
real
~~~

Required ellipsoids include at least:

- sphere;
- WGS84;
- GRS80-like ellipsoid;
- International-1924-like ellipsoid;
- Airy-like ellipsoid;
- synthetic ellipsoid with f close to 0.01.

No Earth-size requirement should be built into the candidate implementation.

At least one scaled ellipsoid should therefore be tested to prove unit/scale
independence.

Suggested scale examples:

~~~text
a ~ 6.4e6
a ~ 6378
a ~ 1
a ~ 8e6
~~~

Distances and error tolerances must be normalized by `a`.

### Corpus

GEO-C should contain:

- structured deterministic cases;
- fixed-seed random cases;
- targeted near-singular cases.

The final accepted corpus should contain at least several tens of thousands
of direct and inverse comparisons per public scalar.

### Direct validation

Compare:

- endpoint surface separation;
- final azimuth where unique.

### Inverse validation

Compare:

- shortest distance;
- initial azimuth where unique;
- final forward azimuth where unique.

GEO-C passes only when every ordinary-profile comparison stays within the
accepted scalar budget.

## GEO-D — PROJ interoperability

Purpose:

Demonstrate compatibility with another major geospatial implementation.

PROJ is an interoperability oracle, not the sole independent numerical
oracle.

The test must use represented public-scalar inputs exactly.

Required coverage:

- float;
- double;
- real;
- direct;
- inverse;
- sphere where supported by the selected PROJ interface;
- multiple ellipsoids;
- difficult near-antipodal cases.

Any semantic difference between PROJ and geodesy-d must be recorded rather
than hidden by the test harness.

## GEO-E — adversarial inverse and convergence validation

Purpose:

Prove that the inverse solver is robust in the region where simple iterative
geodesic algorithms commonly fail.

The production inverse solver must expose test-only instrumentation sufficient
to record:

- initial-case classification;
- whether special short/meridional/equatorial handling was used;
- whether the antipodal starting strategy was used;
- Newton iteration count;
- whether bracket/bisection safeguarding was used;
- whether convergence succeeded.

Production API users do not need to see this instrumentation.

Required adversarial classes:

~~~text
nearly coincident
nearly polar
near-equatorial
near-meridional
longitude difference near pi
latitude2 near -latitude1
oblate near-antipodal astroid region
exact ambiguous antipodal cases
f close to 0
f close to 0.01
~~~

The corpus should densely sample around the antipodal transition rather than
rely only on random global points.

Acceptance requires:

- no unexpected non-convergence;
- finite bounded iteration counts;
- agreement with the independent oracle;
- deterministic behavior for repeated identical input.

The final production iteration limit must be justified by observed evidence
plus explicit safety margin.

## GEO-F — API and runtime contract

Purpose:

Verify that the public checked surface obeys geodesy-d's runtime and
allocation policy.

The complete checked operational surface should compile from:

~~~text
pure
nothrow
@safe
@nogc
~~~

where the final API design permits those attributes.

Required checks:

- solver checked construction;
- solver properties;
- checked direct;
- checked inverse;
- result accessors;
- invalid default solver;
- non-finite direct distance rejection;
- invalid result path leaves no false success;
- deterministic repeated execution;
- no allocation in checked numerical operations.

Throwing convenience operations are validated separately for:

~~~text
@safe
~~~

and correct `GeodesyValueException` behavior.

Runtime stress should include at least:

~~~text
100000 deterministic direct calls per scalar
100000 deterministic inverse calls per scalar
~~~

or an equivalent workload justified by measured runtime.

## GEO-G — platform/compiler and real-width validation

Mandatory portable matrix should follow the accepted TM/UTM platform policy
where runners remain available.

Target coverage:

~~~text
Linux x86_64 / LDC
Linux AArch64 / LDC
Windows x86_64 / LDC
macOS AArch64 / LDC
macOS x86_64 / LDC
Linux x86_64 / DMD
~~~

Windows AArch64 may remain informational while the toolchain is considered
experimental by project policy.

Each mandatory platform should run:

- library unit tests;
- GEO-A semantic gate;
- core reference/property gate suitable for portable CI;
- GEO-F API/runtime gate.

External GeographicLib Exact and PROJ differential gates may remain
dedicated Linux reference jobs if portable dependency availability would
otherwise weaken or complicate the core matrix.

### `real`

The project should preserve evidence for:

~~~text
mant_dig == 53
mant_dig == 64
mant_dig == 113
~~~

where practical.

A platform with wider `real` must demonstrate that intermediate calculations
retain wider precision.

## Property tests

Property testing supplements independent reference comparison.

Useful properties include:

### Direct/inverse consistency

For non-degenerate cases:

~~~text
direct(start, azi1, distance) -> end

inverse(start, end)
    -> distance approximately abs(input distance)
~~~

subject to shortest-path semantics.

Distances beyond the shortest-path domain must not be used naively for this
property.

### Reversal symmetry

For unique inverse cases:

~~~text
distance(A, B) == distance(B, A)
~~~

with the appropriate relationship between forward azimuths.

### Scale invariance

Scaling:

~~~text
a
distance
~~~

by the same positive factor must leave angular outputs unchanged and scale
linear outputs by that factor within scalar accuracy.

### Sphere properties

On a sphere:

- great-circle analytical results;
- rotational symmetry;
- longitude-shift symmetry;
- antipodal non-uniqueness.

## Regression policy

Every discovered numerical or semantic defect must add a permanent
regression case.

Regression cases should record:

- original input;
- public scalar;
- ellipsoid;
- failure mode;
- corrected expectation;
- source/reference where relevant.

Validator defects are also regression-worthy.

An apparent production failure caused by extra oracle rounding must not be
recorded as a production numerical defect.

## Performance

Performance is supporting evidence, not a mandatory acceptance gate for the
first direct/inverse implementation.

After correctness acceptance, a benchmark may compare:

- prepared `Geodesic!T` direct;
- prepared `Geodesic!T` inverse;
- GeographicLib;
- PROJ where a meaningful in-process API comparison is available.

CLI process startup must not be used as the numerical-kernel benchmark.

## Acceptance matrix

Initial status:

~~~text
GEO-A  contract and analytical semantics             OPEN (contract frozen)
GEO-B  authoritative reference vectors               OPEN
GEO-C  GeographicLib Exact differential validation   OPEN
GEO-D  PROJ interoperability                         OPEN
GEO-E  adversarial inverse/convergence                OPEN
GEO-F  API/runtime contract                          OPEN
GEO-G  platform/compiler/real-width coverage          OPEN
~~~

ADR-0008 remains `Proposed` until every mandatory gate is `PASS`.

## Immediate next step

GEO-A pre-implementation semantic research is complete and its public
contract is frozen in ADR-0008.

The next step is to create the initial production `Geodesic!T` implementation
and the executable GEO-A validation gate.

Implementation should begin with:

- prepared ellipsoid state and coefficient generation;
- canonical angular input/output helpers;
- direct solution;
- inverse special cases and robust general solution;
- explicit test-only inverse iteration instrumentation.

GEO-A becomes `PASS` only when the production implementation satisfies the
frozen semantics under both DMD and LDC.
