# UTM validation plan

**Status:** Planned  
**Branch:** `feature/utm`  
**Depends on:** ADR-0006, ADR-0007

## Purpose

This document defines the acceptance evidence required for the
`geodesy-d` Universal Transverse Mercator policy layer.

UTM is not a new projection kernel.

The accepted generic `TransverseMercator!T` implementation remains responsible
for the numerical projection mathematics.

UTM validation therefore concentrates on:

- policy correctness;
- parameter wiring;
- zone selection;
- boundary semantics;
- coordinate tagging;
- scalar preservation;
- delegation to the accepted TM implementation;
- compatibility with independent reference implementations;
- cross-platform behavior.

The UTM layer must not be accepted merely because its own forward and reverse
operations round-trip.

Independent and structural evidence is required.

## Scope

The validation target includes:

~~~text
UtmZone
UtmHemisphere
UtmCoordinate<T>
UtmProjection<T>

standard automatic UTM zone selection
automatic forward UTM
tagged reverse UTM
~~~

It excludes:

~~~text
UPS
MGRS
CRS lookup
EPSG projected-CRS resolution
datum transformation
axis-order policy
text parsing and formatting
height
geoid models
~~~

## Normative policy under test

### Zone set

Valid zones are exactly:

~~~text
1 .. 60
~~~

The central meridian for zone `z` is:

~~~text
lambda0 = 6 * z - 183 degrees
~~~

Examples:

~~~text
zone 1  -> -177 degrees
zone 30 ->   -3 degrees
zone 31 ->    3 degrees
zone 60 ->  177 degrees
~~~

### Fixed UTM Transverse Mercator parameters

~~~text
latitude of natural origin       0 degrees
scale factor                     0.9996
false easting                    500000 m
false northing, north            0 m
false northing, south            10000000 m
~~~

### Supported ellipsoid profile

The UTM layer accepts only terrestrial oblate ellipsoids expressed numerically
in metres:

~~~text
6,000,000 m <= semi-major axis <= 7,000,000 m
0 < flattening <= 0.01
~~~

A sphere is not a supported UTM ellipsoid.

This is intentionally narrower than the generic ellipsoid and Transverse
Mercator contracts.

### Automatic standard geographic region

Automatic standard-zone selection accepts:

~~~text
-80 degrees <= latitude < 84 degrees
~~~

Outside that interval it fails.

There is no implicit UPS fallback.

### Automatic hemisphere

~~~text
latitude >= 0 -> north
latitude <  0 -> south
~~~

Latitude zero therefore belongs to the northern convention during automatic
selection.

### Longitude normalization

Standard zone selection first canonicalizes longitude to:

~~~text
[-180 degrees, +180 degrees)
~~~

Thus both represented antimeridians map consistently:

~~~text
-180 degrees -> -180 degrees -> zone 1
+180 degrees -> -180 degrees -> zone 1
~~~

### Ordinary zone rule

For normalized longitude `lon`:

~~~text
zone = floor((lon + 180) / 6) + 1
~~~

before application of the Norway and Svalbard exceptions.

Ordinary longitude intervals are lower-closed and upper-open.

Examples:

~~~text
zone 1:  [-180, -174)
zone 2:  [-174, -168)
...
zone 31: [0, 6)
...
zone 60: [174, 180)
~~~

#### Norway exception

For:

~~~text
56 <= latitude < 64
3  <= longitude < 12
~~~

the standard zone is:

~~~text
32
~~~

#### Svalbard exceptions

For:

~~~text
72 <= latitude < 84
~~~

use:

~~~text
 0 <= longitude <  9  -> zone 31
 9 <= longitude < 21  -> zone 33
21 <= longitude < 33  -> zone 35
33 <= longitude < 42  -> zone 37
~~~

Outside those longitude intervals, ordinary zoning applies.

All policy intervals are lower-closed and upper-open.

## Existing evidence inherited from Transverse Mercator

Do not repeat the complete ADR-0006 numerical-validation program.

The UTM implementation inherits a numerical kernel which already has accepted
evidence for:

- EPSG 9807 semantics;
- `float`, `double`, and `real`;
- structured GeographicLib Exact comparison;
- deterministic pseudo-random GeographicLib Exact comparison;
- independent analytic spherical validation;
- represented reverse-boundary behavior;
- wider-than-double `real` arithmetic;
- reverse Newton convergence;
- checked `pure nothrow @safe @nogc` hot paths;
- controlled LDC release performance;
- Linux, Windows and macOS;
- x86_64 and AArch64;
- 53-, 64-, and 113-bit `real` mantissa configurations.

UTM acceptance must prove that the policy layer correctly preserves and
specializes these guarantees.

It does not need to re-establish the Krüger/Karney series mathematics.

## Independent references

### PROJ

Use PROJ `utm` as a direct external UTM reference.

Representative operation:

~~~text
+proj=utm +zone=<1..60> [+south] +ellps=<ellipsoid>
~~~

Also compare selected cases against explicitly parameterized PROJ Transverse
Mercator:

~~~text
+proj=tmerc
+lat_0=0
+lon_0=(6*zone-183)
+k_0=0.9996
+x_0=500000
+y_0=(0 or 10000000)
~~~

Where deterministic high-accuracy selection is relevant, force PROJ's
high-accuracy Transverse Mercator path rather than an automatic approximate
alternative.

### GeographicLib

Use GeographicLib UTM/UPS functionality as an independent reference for:

- standard zone assignment;
- hemisphere assignment;
- Norway exception;
- Svalbard exceptions;
- WGS 84 UTM forward values;
- WGS 84 UTM reverse values;
- explicitly selected neighboring zones where practical.

GeographicLib may select UPS outside the standard UTM latitude region.

That does not change the `geodesy-d` contract.

For such inputs:

~~~text
GeographicLib -> may return UPS
geodesy-d UTM -> must reject
~~~

### Generic geodesy-d Transverse Mercator

Use `TransverseMercator!T` as a structural equivalence reference for UTM
parameter wiring.

This is not an independent numerical oracle.

Its purpose is to prove that the UTM layer delegates to the already accepted TM
implementation with exactly the intended parameters.

## Determinism

All generated corpora must be reproducible.

Pseudo-random validation must record:

- seed;
- sample count;
- scalar type;
- ellipsoid;
- test mode;
- failure count;
- worst observed case.

Boundary validation should prefer explicit neighboring represented values rather
than random sampling.

## Acceptance gates

### Gate UTM-A — zone and policy semantics

#### Goal

Verify UTM policy independently of projection accuracy.

#### Zone construction

Test:

~~~text
0         reject

1         accept
2         accept
...
59        accept
60        accept

61        reject
uint.max  reject
~~~

`UtmZone.init` must be invalid.

For every zone from 1 through 60 verify:

~~~text
centralMeridianDegrees == 6 * zone - 183
~~~

#### Ordinary longitude boundaries

For every ordinary 6-degree zone boundary test:

~~~text
boundary - represented epsilon
boundary exactly
boundary + represented epsilon
~~~

The exact boundary belongs to the eastern zone.

Example:

~~~text
just below -174 -> zone 1
exactly -174    -> zone 2
just above -174 -> zone 2
~~~

The tests must account for representation differences between:

~~~text
float
double
real
~~~

rather than assuming one fixed decimal epsilon is representable for every
scalar.

#### Antimeridian

Verify:

~~~text
longitude -180 -> zone 1
longitude +180 -> normalized -180 -> zone 1
~~~

Also verify that the greatest represented longitudes below +180 remain in
zone 60.

#### Latitude limits

Verify automatic policy around the lower boundary:

~~~text
latitude < -80       reject
latitude = -80       accept
latitude just > -80  accept
~~~

Verify automatic policy around the upper boundary:

~~~text
latitude just < 84   accept
latitude = 84        reject
latitude > 84        reject
~~~

#### Equator

Verify:

~~~text
latitude < 0 -> south
latitude = 0 -> north
latitude > 0 -> north
~~~

#### Norway exception

Verify the entire boundary rectangle:

~~~text
56 <= latitude < 64
3  <= longitude < 12
~~~

Canonical accepted examples include:

~~~text
latitude 56, longitude 3
latitude immediately below 64, longitude immediately below 12
~~~

Test immediately outside each edge:

~~~text
latitude below 56
latitude at or above 64
longitude below 3
longitude at or above 12
~~~

Those points must fall back to the ordinary zone rule.

#### Svalbard exceptions

Inside:

~~~text
72 <= latitude < 84
~~~

verify:

~~~text
[0, 9)   -> zone 31
[9, 21)  -> zone 33
[21, 33) -> zone 35
[33, 42) -> zone 37
~~~

Explicitly test longitude boundaries:

~~~text
0
9
21
33
42
~~~

with values:

~~~text
immediately below
exactly on boundary
immediately above
~~~

Also test latitude:

~~~text
just below 72
exactly 72
just below 84
exactly 84
~~~

Outside the Svalbard latitude band the ordinary zoning rule must apply.

#### PASS criteria

UTM-A passes when:

~~~text
zone construction failures       = 0
central-meridian failures        = 0
ordinary-boundary failures       = 0
antimeridian failures            = 0
latitude-boundary failures       = 0
hemisphere failures              = 0
Norway-policy failures           = 0
Svalbard-policy failures         = 0
~~~

### UTM-A measured evidence

UTM-A is complete.

The pure UTM policy implementation was validated independently with both
supported local compiler families:

~~~text
compiler          checks    failures    result

DMD 2.111.x        2702         0       PASS
LDC 1.41.x         2702         0       PASS
~~~

The validation covers all public scalar families:

~~~text
float
double
real
~~~

Measured policy coverage includes:

- construction and rejection behavior for `UtmZone`;
- all 60 zone numbers and all 60 central meridians;
- structural validity of `UtmCoordinate!T`;
- ordinary six-degree zone boundaries;
- represented values immediately on both sides of every ordinary boundary;
- `-180` and `+180` antimeridian canonicalization;
- represented values immediately inside the antimeridian;
- the lower `-80 degree` UTM latitude boundary;
- the upper open `84 degree` UTM latitude boundary;
- automatic north/south hemisphere selection around the equator;
- Norway exception boundaries;
- Svalbard exception boundaries;
- represented neighboring values around all exception boundaries.

An initial validator version applied `nextDown` / `nextUp` to degree values
before conversion to radians. That test construction was invalid for the
stored-coordinate contract because the subsequent degree-to-radian conversion
can round a neighboring degree value back onto the exact represented radian
boundary.

The validator was corrected to:

1. construct the exact policy boundary through the public degree-to-radian
   representation;
2. obtain adjacent represented values with `nextDown` / `nextUp` in the stored
   radian domain;
3. construct the test coordinate directly from those radian values.

After that correction both compilers produced identical zero-failure results.

The ordinary project unit-test suite also remained green on both DMD and LDC:

~~~text
12 modules passed unittests
~~~

Therefore:

~~~text
UTM-A  zone and policy semantics    PASS
~~~

### Gate UTM-B — parameterization and TM delegation

#### Goal

Prove that UTM is only a policy specialization of the accepted generic
Transverse Mercator operation.

#### All zones

For every:

~~~text
zone 1 .. 60
~~~

and both:

~~~text
north
south
~~~

construct `UtmProjection!double`.

Verify effective parameters:

~~~text
latitude of natural origin = 0 degrees
longitude of natural origin = 6 * zone - 183 degrees
scale factor = 0.9996
false easting = 500000 m
false northing north = 0 m
false northing south = 10000000 m
~~~

#### Central-meridian invariants

For every zone at:

~~~text
latitude = 0
longitude = central meridian
~~~

the northern convention must produce:

~~~text
easting  = 500000 m
northing = 0 m
~~~

The southern convention must produce:

~~~text
easting  = 500000 m
northing = 10000000 m
~~~

subject only to the public scalar's representational precision.

#### Generic-TM forward equivalence

Construct:

~~~text
UtmProjection<T>
~~~

and separately:

~~~text
TransverseMercator<T>
~~~

with exactly the corresponding UTM parameters.

For representative points in each zone compare the forward results.

Required scalars:

~~~text
float
double
real
~~~

Because both paths use the same production TM operation and same represented
parameters, exact equality is preferred.

If a compiler or target prevents bitwise identity despite semantically
identical evaluation, characterize the difference and require it to remain far
below the public scalar accuracy budget.

#### Generic-TM reverse equivalence

Perform the equivalent comparison for reverse projection.

UTM policy must not alter a valid generic-TM result except for its own
documented geographic latitude restriction.

#### Neighboring-zone delegation

Select representative points deliberately projected in:

~~~text
standard zone
western neighboring zone
eastern neighboring zone
~~~

where the bounded TM longitude contract accepts the source.

The UTM projection must delegate normally rather than forcing the automatic
zone.

#### Ellipsoid policy

Reject:

~~~text
Ellipsoid.init
sphere, f = 0
a below 6,000,000 m
a above 7,000,000 m
f above 0.01
non-finite or otherwise invalid ellipsoid states
~~~

Test the exact accepted profile boundaries.

Accept representative terrestrial ellipsoids inside the profile, including:

~~~text
WGS 84
GRS 80
Airy 1830
Bessel 1841
International 1924
synthetic f = 0.01 boundary
~~~

#### PASS criteria

UTM-B passes with zero failures for:

~~~text
fixed parameter construction
all 60 central meridians
both hemisphere conventions
forward TM equivalence
reverse TM equivalence
neighboring-zone delegation
ellipsoid-profile enforcement
~~~

### UTM-B measured evidence

UTM-B is complete.

The prepared UTM projection and its delegation to the accepted generic
Transverse Mercator implementation were validated with both local compiler
families:

~~~text
compiler          checks    failures    result

DMD 2.111.x       15918         0       PASS
LDC 1.41.x        15918         0       PASS
~~~

The validation covers all public scalar families:

~~~text
float
double
real
~~~

Measured coverage includes:

- construction of every zone from 1 through 60;
- both north and south false-northing conventions;
- all 120 zone/hemisphere parameter combinations;
- exact zone central meridians;
- fixed latitude of natural origin at zero;
- fixed scale factor 0.9996;
- fixed false easting of 500000 m;
- false northing of 0 m in the north;
- false northing of 10000000 m in the south;
- projected natural-origin invariants for all zones and hemispheres;
- exact forward delegation equivalence with `TransverseMercator!T`;
- exact reverse delegation equivalence with `TransverseMercator!T`;
- explicit neighboring-zone operation;
- rejection of invalid zones and hemisphere values;
- rejection of spherical ellipsoids;
- rejection outside the terrestrial metre profile;
- acceptance of the exact supported profile boundaries;
- representative WGS 84, GRS 80, Airy 1830, Bessel 1841 and
  International 1924 ellipsoids.

For the delegation checks, UTM and generic Transverse Mercator were prepared
from the same represented parameters. The validator therefore required exact
equality of forward projected components and reverse geographic components,
not merely tolerance-based agreement.

The explicit neighboring-zone checks confirmed that `UtmProjection!T` does not
recompute or replace the caller-selected zone.

After UTM-B implementation, the earlier policy gate remained unchanged:

~~~text
UTM-A / DMD    2702 checks    0 failures    PASS
UTM-A / LDC    2702 checks    0 failures    PASS
~~~

The normal project unit-test suite also remained green:

~~~text
DMD    12 modules passed unittests
LDC    12 modules passed unittests
~~~

Therefore:

~~~text
UTM-B  parameterization and TM delegation    PASS
~~~

### Gate UTM-C — independent differential validation

#### Goal

Verify UTM policy semantics and prepared-projection numerics against
independent mature implementations.

UTM-C is deliberately split into two complementary sub-gates:

~~~text
UTM-C1  authoritative semantic cross-check
UTM-C2  represented-model numerical differential cross-check
~~~

#### UTM-C1 — authoritative semantic cross-check

GeographicLib UTM/UPS is used as the independent reference for standard-zone
and explicit-zone semantics.

The deterministic corpus covers:

- the standard latitude interval `[-80, 84)`;
- values immediately below and above the standard latitude boundaries;
- all ordinary UTM zone behavior needed by the policy layer;
- the antimeridian;
- Norway;
- Svalbard;
- the equator;
- explicit-zone operation outside the automatic standard latitude band;
- explicit-zone operation near the inherited bounded-TM longitude limit;
- ellipsoid-policy differences.

The semantic comparison distinguishes projection semantics from
GeographicLib UTM/UPS coordinate-envelope policy.

In particular, the following intentional differences are part of the
geodesy-d contract:

- mathematical latitude zero is canonicalized to the northern hemisphere;
  GeographicLib distinguishes signed `-0.0` and assigns it south;
- `UtmProjection!T` does not impose GeographicLib UTM/UPS/MGRS-derived
  projected-coordinate legality windows;
- the geodesy-d Earth-size ellipsoid restriction is a defensive
  unit/profile policy, not a normative UTM requirement.

#### UTM-C2 — represented-model numerical differential cross-check

PROJ Transverse Mercator is used as the numerical differential oracle.

For every comparison, PROJ is parameterized with the mathematical model
actually represented by the public scalar `T`:

- represented semi-major axis;
- represented flattening;
- represented central meridian;
- represented scale factor;
- represented false easting;
- represented false northing;
- the geographic source point derived from the stored angular radians.

This representation rule is especially important for `float`.

The external oracle must interpret the angular values actually stored by
`Latitude!float` and `Longitude!float`. It must not call the public
`.degrees` property and then treat that additionally rounded float-degree
value as the reference coordinate.

The correct oracle conversion is conceptually:

~~~text
stored T radians
    -> promote to double
    -> convert radians to degrees in double
    -> external reference
~~~

A separately rounded `float` degree value is not equivalent to the value
consumed internally by `TransverseMercator!float`.

The numerical corpus covers:

- all 60 UTM zones;
- both false-northing conventions;
- WGS 84;
- GRS 80;
- International 1924;
- Airy 1830;
- `float`;
- `double`;
- `real`;
- ordinary in-zone points;
- cross-equator use;
- explicit operation outside the standard automatic latitude band;
- neighboring-zone use;
- wide explicit longitude differences within the bounded generic-TM
  contract.

Forward comparison uses projected-coordinate distance.

Reverse comparison starts from independently generated PROJ projected
coordinates and measures the recovered represented geographic position.
It is therefore not a geodesy-d self-round-trip test.

#### Canonical PROJ UTM comparison

A canonical PROJ `+proj=utm` comparison is useful diagnostic evidence, but it
is not the scalar-accuracy gate for `float`.

Canonical PROJ UTM parameters are represented in PROJ's working precision,
whereas `UtmProjection!float` intentionally exposes a public float model.
Comparing those directly therefore includes parameter-representation
differences in addition to implementation error.

The mandatory C2 numerical gate instead compares the same represented
mathematical model on both sides.

#### Accuracy targets

Within the supported profile, inherit the accepted generic-TM targets:

~~~text
float forward          <= 2 m
float reverse          <= 4 m represented-position envelope

double forward         <= 1 mm
double reverse         <= 2 mm represented-position envelope

real forward           <= 1 mm
real reverse           <= 2 mm represented-position envelope
~~~

Binary64 external oracles do not independently establish wider-than-binary64
`real` precision.

ADR-0006 and its wider-`real` validation remain the numerical basis for that
additional precision claim.

#### PASS criteria

UTM-C passes when:

~~~text
semantic mismatches inside comparison scope = 0
unexpected rejection                       = 0
unexpected acceptance                      = 0
numerical comparisons outside target       = 0
non-finite reference/error values           = 0
~~~

### Gate UTM-D — boundary and reversibility properties

#### Automatic forward properties

For every accepted automatic source:

~~~text
result.zone == standard selected zone
result.hemisphere == standard selected hemisphere
result.easting is finite
result.northing is finite
~~~

#### Automatic round trip

For deterministic structured and pseudo-random corpora:

~~~text
GeographicCoordinate
    -> tryForwardUtm
    -> UtmCoordinate
    -> tryReverseUtm
    -> GeographicCoordinate
~~~

must remain within the inherited scalar accuracy target.

Round-trip evidence is supporting evidence only.

It does not replace independent references.

#### Explicit prepared round trip

For every representative zone and both hemisphere conventions:

~~~text
GeographicCoordinate
    -> UtmProjection.tryForward
    -> ProjectedCoordinate
    -> UtmProjection.tryReverse
    -> GeographicCoordinate
~~~

must remain inside the accepted scalar error envelope.

#### Reverse latitude limits

Construct projected coordinates corresponding to represented geographic
latitudes around:

~~~text
-80 degrees
+84 degrees
~~~

For tagged or explicitly prepared UTM reverse operations, the standard
automatic latitude band is not reapplied.

`UtmProjection!T.tryReverse()` and `tryReverseUtm()` use the explicitly stored
zone and hemisphere and delegate to the corresponding bounded generic
Transverse Mercator operation.

The reverse operation must not:

- recompute the automatic standard zone;
- switch hemisphere from the recovered latitude;
- reject a result merely because its latitude lies outside `[-80, 84)`.

The `[-80, 84)` interval remains a requirement of automatic standard-zone
selection and automatic forward projection only.


#### Preserve explicitly selected zone

A coordinate deliberately produced in a neighboring zone must be reversed using
that same selected zone.

The implementation must not:

~~~text
reverse coordinate
-> recompute automatic standard zone
-> silently change zone
~~~

#### Preserve explicitly selected hemisphere convention

Reverse projection uses the selected false-northing convention.

It must not replace the source hemisphere tag based on the sign of the returned
latitude.

#### Deterministic random corpus

Use an automatic-zone corpus over:

~~~text
latitude  [-80, 84)
longitude [-180, 180)
~~~

Suggested initial size:

~~~text
100000 points per scalar
~~~

with a fixed seed.

The corpus should report:

~~~text
accepted points
rejected points
forward failures
reverse failures
worst round-trip residual
worst source point
~~~

#### PASS criteria

UTM-D passes with zero semantic/property failures inside the supported domain.

### Gate UTM-E — scalar, API and runtime properties

#### Public scalars

Exercise the complete checked API for:

~~~text
float
double
real
~~~

#### Compile-time checked hot path

Create a validation caller declared:

~~~d
pure nothrow @safe @nogc
~~~

and exercise:

- `UtmZone.tryFromNumber`;
- `UtmZone.isValid`;
- zone properties;
- `UtmCoordinate` checked construction;
- coordinate properties;
- standard-zone selection;
- `UtmProjection.tryFromZone`;
- projection properties;
- `UtmProjection.tryForward`;
- `UtmProjection.tryReverse`;
- automatic `tryForwardUtm`;
- tagged `tryReverseUtm`.

Failure to compile from this caller fails the gate.

This is the primary evidence that the checked operational path does not hide GC
allocation.

#### Throwing wrappers

Test convenience wrappers separately for:

- valid construction;
- invalid zone;
- unsupported ellipsoid;
- invalid automatic geographic domain;
- failed forward operation;
- failed reverse operation.

Throwing wrappers must remain `@safe`.

They are not required to be `nothrow` or `@nogc`.

#### `real` precision preservation

UTM must not narrow `real` through `double` before reaching the accepted TM
operation.

On targets where:

~~~text
real.mant_dig > double.mant_dig
~~~

construct two `real` geographic inputs that are distinguishable as `real` but
collapse to the same `double`.

The UTM prepared path must preserve the distinction whenever the underlying TM
path preserves it.

The existing platform matrix currently provides targets with:

~~~text
real mantissa 53
real mantissa 64
real mantissa 113
~~~

#### Repeated-operation stability

Use a deterministic repeated-operation probe to detect:

- mutable prepared coefficients;
- stale output after failed checked calls;
- accidental state corruption;
- invalid `.init` acceptance;
- repeated reconstruction mistakes;
- zone corruption;
- hemisphere corruption.

Suggested initial count:

~~~text
100000 operations per scalar
~~~

#### PASS criteria

UTM-E passes when all checked API, scalar-preservation and repeated-operation
tests complete with zero failures.

### Gate UTM-F — platform and compiler coverage

#### Goal

Verify that the UTM policy layer preserves the portability already demonstrated
by generic Transverse Mercator.

Extend the existing GitHub Actions platform matrix instead of creating an
independent CI architecture.

#### Required configurations

At minimum retain blocking coverage for:

~~~text
Linux   x86_64   LDC
Linux   AArch64  LDC
Windows x86_64   LDC
macOS   AArch64  LDC
Linux   x86_64   DMD
~~~

Continue exercising the already successful additional targets where practical:

~~~text
macOS   x86_64   LDC
Windows AArch64  LDC
~~~

#### Platform-sensitive `real`

The UTM tests should continue to cover all available target `real` forms:

~~~text
53-bit mantissa
64-bit mantissa
113-bit mantissa
~~~

The same public UTM policy must hold on each.

#### PASS criteria

UTM-F passes when:

- the required CI matrix is green;
- the UTM policy tests execute on every blocking target;
- no undocumented architecture-specific numerical workaround is required;
- differing `real` precision is handled according to the generic scalar
  contract.

## Performance treatment

No separate numerical performance gate equivalent to the generic TM benchmark
is required for initial UTM acceptance.

The reason is architectural:

- UTM introduces no new projection kernel;
- generic TM already has a controlled performance baseline;
- zone arithmetic is small relative to projection evaluation;
- repeated operation uses a prepared `UtmProjection!T`.

Implementation review must nevertheless verify:

~~~text
UtmProjection construction
    -> constructs underlying TransverseMercator once

repeated forward/reverse
    -> reuses prepared operation
~~~

The automatic one-shot convenience function may prepare a projection per call.

It is not the normative bulk path.

If profiling in a real consumer later shows significant policy overhead, create
a dedicated UTM benchmark before optimizing.

## Suggested validation structure

Keep validation code outside the production module.

Suggested files:

~~~text
validation/
    utm_policy_validation.d
    utm_parameterization_validation.d
    utm_reference_crosscheck.d
    utm_boundary_property.d
    utm_api_runtime_validation.d

tools/
    validate-utm-policy.sh
    validate-utm-parameterization.sh
    validate-utm-reference.sh
    validate-utm-boundary.sh
    validate-utm-api-runtime.sh
~~~

Do not copy the large generic TM validators merely to rename them.

Test only the new UTM policy and delegation surface.

## Implementation sequence

### U0 — types and pure policy

Implement:

~~~text
UtmZone
UtmHemisphere
UtmCoordinate
standard zone selection
~~~

No projection delegation yet.

Target:

~~~text
UTM-A PASS
~~~

### U1 — prepared projection

Implement:

~~~text
UtmProjection
fixed UTM parameterization
ellipsoid profile
delegation to TransverseMercator
~~~

Target:

~~~text
UTM-B PASS
~~~

### U2 — convenience operations

Implement:

~~~text
tryForwardUtm
forwardUtm
tryReverseUtm
reverseUtm
~~~

Target:

~~~text
UTM-D PASS
UTM-E PASS
~~~

### U3 — independent references

Add PROJ and GeographicLib differential validation.

Target:

~~~text
UTM-C PASS
~~~

### U4 — CI portability

Integrate UTM tests into the existing platform matrix.

Target:

~~~text
UTM-F PASS
~~~

### U5 — acceptance

When UTM-A through UTM-F pass:

1. record measured evidence in this document;
2. update public API documentation;
3. update reference documentation;
4. update roadmap/release documentation where appropriate;
5. change ADR-0007 from `Proposed` to `Accepted`;
6. merge only with required CI green.

## Acceptance matrix

Current status:

~~~text
UTM-A  zone and policy semantics              PASS
UTM-B  parameterization and TM delegation     PASS
UTM-C  independent differential validation    PASS
UTM-D  boundary/reversibility properties      PASS
UTM-E  scalar/API/runtime properties          PASS
UTM-F  platform/compiler coverage             OPEN
~~~

ADR-0007 remains `Proposed` while any mandatory acceptance gate is open.

## Release interpretation

Passing all mandatory UTM gates establishes:

- correct bounded UTM policy;
- correct standard zone assignment;
- correct Norway and Svalbard handling;
- correct north/south false-northing policy;
- correct fixed Transverse Mercator parameterization;
- correct tagged coordinate reversal;
- explicit neighboring-zone capability;
- preservation of the accepted TM scalar contract;
- independent reference compatibility;
- multi-platform operation.

It does not establish:

- UPS support;
- MGRS support;
- complete CRS identity;
- implicit WGS 84 datum semantics;
- authority-code lookup;
- global projection-family selection;
- arbitrary planetary UTM semantics.

Those claims require separate design and validation.

## References

- ADR-0006:
  `docs/adr/0006-transverse-mercator.md`
- ADR-0007:
  `docs/adr/0007-utm-policy.md`
- generic TM validation:
  `docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md`
- PROJ Universal Transverse Mercator:
  https://proj.org/en/stable/operations/projections/utm.html
- PROJ Transverse Mercator:
  https://proj.org/en/stable/operations/projections/tmerc.html
- GeographicLib UTM/UPS:
  https://geographiclib.sourceforge.io/

External implementations are evidence sources.

They are not copied as the implementation specification for `geodesy-d`.

## UTM-C result — independent reference validation

UTM-C was executed as two independent reference gates.

### UTM-C1 — semantic reference

Reference implementation:

~~~text
GeographicLib 2.7
~~~

Validation sources:

~~~text
validation/utm_geographiclib_oracle.cpp
validation/utm_reference_semantics.d
tools/validate-utm-reference-semantics.sh
~~~

Local results:

~~~text
DMD:
  checks=80
  failures=0
  PASS

LDC:
  checks=80
  failures=0
  PASS
~~~

Confirmed semantics include:

- standard automatic UTM latitude region `[-80, 84)`;
- `+180 degrees` normalization to `-180 degrees`, hence zone 1;
- Norway exception boundaries;
- Svalbard exception boundaries;
- explicit fixed-zone operation outside the automatic standard latitude
  band;
- explicit hemisphere selection as a false-northing convention.

The following intentional differences were confirmed and retained:

1. GeographicLib assigns signed latitude `-0.0` to the southern hemisphere;
   geodesy-d canonical mathematical zero uses the northern convention.

2. GeographicLib UTM/UPS applies additional projected-coordinate legality
   windows. For example, its UTM/UPS layer rejects a sufficiently high
   explicit-zone northing near `89 degrees N`, while geodesy-d
   `UtmProjection!T` continues to expose the underlying bounded fixed-zone
   Transverse Mercator operation.

3. PROJ accepts ellipsoidal UTM parameterizations outside terrestrial
   Earth-size ranges. geodesy-d deliberately applies an Earth-size safety
   policy because its current coordinate types do not encode linear-unit
   metadata while UTM false offsets are defined in metres.

### UTM-C2 — numerical reference

Reference implementation:

~~~text
PROJ cct 9.7.1
~~~

Validation sources:

~~~text
validation/utm_proj_crosscheck.d
tools/validate-utm-proj.sh
~~~

Corpus dimensions:

~~~text
60 zones
x 2 hemisphere conventions
x 4 ellipsoids
= 480 prepared projection configurations

11 geographic cases per configuration
3 public scalar types

per scalar:
  forward comparisons = 5280
  reverse comparisons = 5280

total numerical differential comparisons = 31680
~~~

Both DMD and LDC produced the same reported worst cases.

Measured worst results:

~~~text
float:
  forward = 0.94856211 m
    WGS84, zone 45, south convention, lat=85, lon=96

  reverse = 1.25987045 m
    International1924, zone 6, south convention, lat=45, lon=-112

double:
  forward = 5.60730443e-09 m
  reverse = 4.53028094e-09 m

real:
  forward = 5.03689695e-09 m
  reverse = 4.53010267e-09 m
~~~

All comparisons remained inside their configured envelopes.

During validation, an apparent approximately 2 m float discrepancy was
traced to the validation oracle performing an additional float
radians-to-degrees rounding step.

The production projection was unchanged.

The corrected oracle converts the stored public-scalar radians to double
before converting to degrees, matching the value actually consumed by the
generic Transverse Mercator kernel.

Result:

~~~text
UTM-C1 PASS
UTM-C2 PASS
UTM-C  PASS
~~~

## UTM-E result — API/runtime contract

UTM-E validates the checked UTM operational surface and runtime semantics.

The following checked operations are exercised from a caller declared:

~~~d
pure nothrow @safe @nogc
~~~

Covered operations include:

- checked `UtmZone` construction and properties;
- `tryStandardUtmZone`;
- checked `UtmProjection!T` construction and properties;
- prepared `tryForward` and `tryReverse`;
- checked `UtmCoordinate!T` construction and properties;
- automatic `tryForwardUtm`;
- tagged `tryReverseUtm`.

Throwing convenience wrappers are validated separately for `@safe`
compilation and correct exception behavior.

Runtime validation also covers:

- default-invalid zone, projection, and tagged-coordinate values;
- invalid zone numbers;
- UTM ellipsoid-policy rejection;
- automatic rejection at the open `84 degree` standard-UTM boundary;
- explicit prepared projection acceptance at `84 degrees`;
- inherited bounded Transverse Mercator domain rejection;
- throwing failure semantics;
- exact represented determinism.

Determinism was tested with 100,000 repetitions for each public scalar type
for both the prepared path and automatic/tagged path.

Local results:

~~~text
DMD:
  float   PASS
  double  PASS
  real    PASS

LDC:
  float   PASS
  double  PASS
  real    PASS
~~~

Each scalar completed:

~~~text
100000 prepared + automatic deterministic repetitions
~~~

with exact repeated public-scalar outputs.

Result:

~~~text
UTM-E PASS
~~~
