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

### Gate UTM-C — independent differential validation

#### Goal

Verify complete UTM behavior against independent mature implementations.

#### PROJ direct UTM comparison

For every zone 1 through 60 compare geodesy-d with PROJ `utm`.

Each zone should include representative points at:

~~~text
central meridian
ordinary western portion
ordinary eastern portion
northern latitude
southern latitude
high northern latitude where valid
high southern latitude where valid
~~~

Run both forward and reverse comparisons.

#### PROJ explicit-TM comparison

For selected zones also compare UTM output against an explicit PROJ `tmerc`
operation using:

~~~text
lat_0 = 0
lon_0 = zone central meridian
k_0 = 0.9996
x_0 = 500000
y_0 = 0 or 10000000
~~~

This separately checks UTM parameter wiring.

#### Norway and Svalbard

Include external-reference points:

- safely inside every special region;
- exactly on every policy boundary;
- immediately outside every policy boundary.

Verify both:

~~~text
selected zone
projected coordinate
~~~

#### Neighboring zones

For representative points explicitly select:

~~~text
standard zone
west neighbor
east neighbor
~~~

where the bounded generic TM domain permits them.

Compare with matching explicit-zone PROJ or GeographicLib operations.

Automatic `tryForwardUtm` must still choose only the standard zone.

#### Hemisphere override

Explicitly test:

~~~text
negative latitude with northern convention
positive latitude with southern convention
equator with northern convention
equator with southern convention
~~~

These are explicit projection-policy tests, not automatic-zone tests.

Verify false-northing behavior against matching external parameterization.

#### GeographicLib zone selection

Compare standard-zone selection with GeographicLib across a deterministic corpus
covering:

- all 60 ordinary zones;
- northern and southern hemispheres;
- equator;
- antimeridian;
- Norway;
- Svalbard;
- values close to -80 degrees;
- values close to +84 degrees.

For points outside the UTM latitude region, document the expected difference:

~~~text
GeographicLib may choose UPS
geodesy-d UTM rejects
~~~

#### Accuracy targets

Within the supported UTM profile inherit the accepted TM accuracy targets:

~~~text
float   <= 2 m
double  <= 1 mm
real    <= 1 mm
~~~

Use ground-equivalent error where angular reverse error becomes poorly
conditioned.

Binary64 external oracles do not independently prove wider-than-binary64
`real` accuracy.

The ADR-0006 wider-`real` evidence remains the numerical basis for that path.

#### PASS criteria

UTM-C passes when:

~~~text
zone-selection mismatches          = 0
reference errors outside target    = 0
unexpected rejection               = 0
unexpected acceptance              = 0
~~~

inside the defined comparison scope.

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

The UTM layer must reject reverse results outside:

~~~text
[-80, 84)
~~~

even if the underlying generic Transverse Mercator can mathematically return
them.

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

Initial state:

~~~text
UTM-A  zone and policy semantics              PASS
UTM-B  parameterization and TM delegation     OPEN
UTM-C  independent differential validation    OPEN
UTM-D  boundary/reversibility properties      OPEN
UTM-E  scalar/API/runtime properties          OPEN
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
