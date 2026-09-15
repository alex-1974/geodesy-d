# Transverse Mercator validation plan

- Status: Active validation specification
- Date: 2026-09-14
- Evidence updated: 2026-09-15
- Applies to: ADR-0006
- Intended implementation: generic EPSG 9807 Transverse Mercator

## Purpose

This document defines the evidence required before the Transverse Mercator
implementation can be considered accepted.

It is deliberately written before production code so that implementation
choices cannot silently redefine the success criteria.

Validation has four separate goals:

1. verify EPSG 9807 operation semantics;
2. verify forward numerical accuracy;
3. verify reverse numerical accuracy independently of the implementation's own
   forward path;
4. establish deterministic domain/failure behaviour and a reproducible
   performance baseline.

Self-roundtrip tests are useful regression tests but are not accepted as
independent accuracy evidence.

## Reference hierarchy

Use the following hierarchy.

### A. Normative semantics

IOGP / EPSG method 9807 is normative for:

- parameter meaning;
- natural origin;
- central meridian;
- scale factor;
- false easting;
- false northing;
- forward/reverse operation semantics;
- published worked examples.

### B. Independent high-accuracy numerical reference

Use GeographicLib `TransverseMercatorExact` for independent projected-position
validation of oblate ellipsoids inside the bounded `geodesy-d` domain.

This is preferred as the primary numerical oracle because it does not use the
same finite Krüger series as the implementation under test.

`TransverseMercatorExact` does not directly support the spherical limit. Sphere
validation therefore uses an independent analytic spherical Transverse Mercator
formula, cross-checked against PROJ's spherical path and GeographicLib's series
implementation, which treats the sphere exactly.

### C. Independent production implementation

Use current PROJ `tmerc` with an explicitly selected high-accuracy deterministic
algorithm path.

Do not rely on environment-dependent automatic algorithm selection for the
canonical differential corpus.

### D. Same-family implementation reference

Use GeographicLib `TransverseMercator` to compare:

- sixth-order Krüger behaviour;
- longitude/backside conventions where applicable;
- reverse Newton behaviour;
- convergence toward difficult domain edges.

Agreement with a same-family implementation is useful but does not replace
comparison with an independent exact reference.

## Public accuracy targets

These are release targets, not assumed results.

Validation separates intrinsic projection error from final scalar
representation error.

### Intrinsic ground-equivalent target

Within the validated geographic/ellipsoid domain:

~~~text
float:
    ground-equivalent position error <= 2 m

double:
    ground-equivalent position error <= 1 mm

real:
    ground-equivalent position error <= 1 mm
~~~

For a geographic input `g`:

~~~text
p_test = geodesy-d.forward(g)
p_ref  = independent_reference.forward(g)

projectedError = hypot(
    p_test.easting  - p_ref.easting,
    p_test.northing - p_ref.northing)

groundEquivalentError = projectedError / k_ref
~~~

where `k_ref` is the independent reference point scale.

The intrinsic corpus primarily uses zero false offsets. Non-zero scale factors
are retained so the scale normalization itself is exercised.

### Reverse intrinsic metric

For a projected input `p`:

~~~text
g_test = geodesy-d.reverse(p)
p_repr = independent_reference.forward(g_test)

projectedError = hypot(
    p_repr.easting  - p.easting,
    p_repr.northing - p.northing)

groundEquivalentError = projectedError / k_ref
~~~

This deliberately does not call `geodesy-d.forward`, avoiding a
self-consistent forward/reverse pair from masking a common defect.

### End-to-end ordinary-terrestrial target

The same absolute targets must also hold without removing false offsets for the
ordinary validation profile:

~~~text
6,000,000 m <= a <= 7,000,000 m
0 <= f <= 0.01
0.9 <= k0 <= 1.1
abs(falseEasting)  <= 2 * a
abs(falseNorthing) <= 2 * a
abs(deltaLongitude) <= 60 deg
~~~

### Representation stress outside the ordinary profile

Construction may permit larger finite scale factors and false offsets.

For stress cases outside the ordinary profile, do not apply a fixed metre limit
blindly. Record:

- intrinsic ground-equivalent error;
- final easting error in absolute units and ulps;
- final northing error in absolute units and ulps;
- output magnitude.

This distinguishes projection-algorithm error from unavoidable scalar
quantization at very large coordinate magnitudes.

### Optional angular diagnostics

Record, but do not use as the sole public contract:

- latitude difference in radians;
- longitude difference after normalized angular subtraction;
- approximate surface displacement.

These are diagnostic aids for localizing failures.

## Validated ellipsoid set

The mandatory terrestrial set is:

~~~text
WGS 84
GRS 80
Airy 1830
Bessel 1841
Clarke 1866
International 1924
Earth-sized sphere
synthetic oblate ellipsoid with f = 0.01
~~~

For each reference ellipsoid record:

- semi-major axis;
- flattening or inverse flattening;
- provenance;
- reference-library construction parameters.

If validation later includes deliberately extreme oblate ellipsoids, report them
as robustness experiments separately from the public terrestrial accuracy
contract.

## Scalar matrix

Every semantic and deterministic regression case must be instantiated for:

~~~text
float
double
real
~~~

Additional requirements:

### float

Confirm at compile time and by a targeted regression test that the numerical
kernel uses `double` working precision.

Validate final public `float` values after rounding back from the double kernel.

### double

This is the normative reference precision for the initial release.

The production `double` path uses eighth-order Krüger coefficients. The
sixth-order A/B build remains a validation tool for quantifying truncation
behaviour, not a supported production mode.

### real

Record:

~~~text
real.sizeof
real.mant_dig
real.epsilon
compiler
target architecture
~~~

The production `real` path uses eighth-order Krüger coefficients regardless of
whether the platform `real` is wider than `double`.

If `real` is not wider than `double`, it must behave as a separate public
instantiation but no stronger precision claim is inferred.

If `real` is wider, validate the wider arithmetic separately. In both cases run
an A/B comparison against an order-6 validation build when investigating series
truncation. Order 8 is retained because structured Exact-reference validation
demonstrated a concrete improvement at the public `f = 0.01`,
`abs(deltaLongitude) = 60 deg` boundary.

## Parameter-semantic matrix

### Natural origin

At minimum:

~~~text
lat0 =   0 deg
lat0 =  49 deg       # OSGB-like
lat0 = -35 deg
lat0 =  80 deg
lat0 = -80 deg
~~~

For each origin, test source points:

- exactly at the natural origin;
- on the central meridian north/south of the origin;
- on the equator where legal;
- near each pole.

Expected invariant:

~~~text
forward(lat0, lon0) == (falseEasting, falseNorthing)
~~~

within the scalar's representational tolerance.

### Central meridian

At minimum:

~~~text
lon0 =    0 deg
lon0 =   15 deg
lon0 = -123 deg
lon0 =  179.75 deg
lon0 = -179.75 deg
~~~

Include equivalent longitudes represented on opposite sides of the
antimeridian.

### Scale factor

At minimum:

~~~text
k0 = 1.0
k0 = 0.9996
k0 = 0.9996012717
k0 = 0.9999
k0 = 1.0001
~~~

Invalid cases:

~~~text
k0 = 0
k0 < 0
k0 = NaN
k0 = +/-inf
~~~

must be rejected at construction.

### False easting / northing

At minimum:

~~~text
(0, 0)
(500000, 0)
(500000, 10000000)
(400000, -100000)
(-2000000, 3000000)
~~~

Also include two classes of translation stress:

1. ordinary-profile offsets with `abs(offset) <= 2 * a`, which remain subject to
   the public absolute accuracy target;
2. much larger finite offsets, for which final error is reported in both
   absolute units and ulps and is not forced under the ordinary-profile metre
   bound.

The translated and untranslated projection must differ only by the configured
constant offsets, subject to scalar arithmetic and final representation.

## Geographic-domain matrix

### Latitude

Deterministic values:

~~~text
-90
-89.999999
-85
-80
-60
-45
-1
-0
+0
+1
+45
+60
+80
+85
+89.999999
+90
degrees
~~~

### Longitude difference from central meridian

Deterministic values:

~~~text
-60
-59.999999
-45
-35
-10
-3
-1
-1e-9
-0
+0
+1e-9
+1
+3
+10
+35
+45
+59.999999
+60
degrees
~~~

Explicit failure probes:

~~~text
-60 deg - 1 ulp-like angular step
+60 deg + 1 ulp-like angular step
-60.000001 deg
+60.000001 deg
-75 deg
+75 deg
-90 deg
+90 deg
~~~

The exact boundary-construction helper should use the scalar representation
rather than decimal literals alone where the distinction matters.

### Domain-boundary invariant

For geographic forward input and non-polar points, the nominal domain remains:

~~~text
abs(normalized_delta_lon) <= 60 deg -> accepted, if arithmetic remains finite
abs(normalized_delta_lon) >  60 deg -> rejected, apart from representation-level angular slack
~~~

Reverse requires a separate representation-aware boundary test because its input
is an easting/northing pair that may already have been rounded. A projected
coordinate obtained by rounding a mathematically valid +/-60-degree boundary
point may recover to a longitude slightly beyond +/-60 degrees, especially near
the poles.

Within the ordinary terrestrial profile, classify only that reverse excess with:

~~~text
boundaryDistance ~= N(phi) * cos(phi) * excessDeltaLongitude
~~~

and accept it only while the distance is within the scalar accuracy budget
(2 m for `float`, 1 mm for `double`/`real`). Accepted excess is clamped to the
exact boundary. This tolerance is not a wider geographic domain.

Validation must therefore include both:

- exact/inside/outside geographic forward boundary probes;
- independently projected and rounded reverse boundary probes, including high
  latitudes where longitude is ill-conditioned.

The constructor's `f <= 0.01` bound is tested independently; the longitude
boundary is not used as a substitute for ellipsoid-shape validation.

At the geographic poles the implementation uses its documented canonical pole
semantics.

## Pole matrix

Test both poles with many source longitudes:

~~~text
-180
-179
-90
-1
0
1
90
179
180
degrees
~~~

Forward projected position must be independent of source longitude within the
documented numerical tolerance.

Reverse projection of the canonical projected pole must return:

~~~text
latitude  = +/-90 deg
longitude = longitudeOfNaturalOrigin
~~~

Test this for multiple `lon0` values including near the antimeridian.

## Antimeridian and angular-normalization matrix

Use origins:

~~~text
lon0 = +179.75 deg
lon0 = -179.75 deg
~~~

Pair them with source longitudes crossing the representation boundary, for
example:

~~~text
+179.75  -> -179.75
-179.75  -> +179.75
+179.999 -> -179.999
-179.999 -> +179.999
+180     -> -180
-180     -> +180
~~~

Verify that semantically equivalent angular positions project consistently and
that the normalized longitude difference chooses the intended standard sheet.

Where D preserves signed zero through the relevant math functions, include
regression checks preventing accidental sign-dependent quadrant changes.

## EPSG/IOGP worked examples

Include every directly applicable published EPSG/IOGP Transverse Mercator
worked example that can be reproduced with the supported type/domain model.

At minimum include the published British National Grid style EPSG 9807 example
with non-zero latitude of natural origin.

For each example record:

- source document/version;
- method code;
- ellipsoid;
- source coordinate;
- all five operation parameters;
- expected projected coordinate;
- source rounding precision;
- test tolerance justified by the published rounding.

Normative examples test semantics and formula interpretation. They are not used
alone to establish sub-millimetre numerical accuracy.

## UTM-like corpus

Although UTM policy is a later slice, the generic kernel must be validated in
the range it will serve.

For every 6-degree zone-equivalent offset:

~~~text
delta lon = -3, -2, -1, 0, +1, +2, +3 deg
~~~

combine with latitudes:

~~~text
-80, -72, -60, -45, -30, -1, 0, +1, +30, +45, +60, +72, +84 deg
~~~

Use:

~~~text
WGS 84
k0 = 0.9996
false easting = 500000
false northing = 0 and 10000000
~~~

This is a projection-kernel validation corpus only. It does not test UTM zone
selection rules.

## Wider TM corpus

For each mandatory terrestrial ellipsoid combine representative latitudes with:

~~~text
abs(delta lon) =
    0
    3
    10
    20
    35
    45
    55
    60 deg
~~~

This corpus is essential for detecting truncation-error growth that UTM-only
tests would not expose.

## Deterministic structured sweep

For `double`, create a reproducible Cartesian product or stratified deterministic
sweep covering at least:

~~~text
ellipsoids:  all mandatory terrestrial set plus synthetic f = 0.01
latitudes:   dense near equator, high latitude, near poles
delta lon:   dense near 0, 3, 35, 55, 60 deg
lat0:        0 plus representative non-zero origins
k0:          1 and 0.9996 plus at least one non-UTM value
offsets:     zero plus representative false E/N
~~~

Target size:

~~~text
>= 250000 forward cases
>= 250000 reverse cases
~~~

The exact generation rule must be committed so failures are reproducible.

Current achieved Exact-reference corpus (2026-09-15):

~~~text
applicable oblate ellipsoids: 7
source points:                251853
forward comparisons/scalar:  251853
reverse comparisons/scalar:  251853
scalars completed:            float, double
compilers:                    DMD, LDC
~~~

The same deterministic source set is used for the DMD/LDC compiler cross-check.
Sphere remains a separate analytic/reference gate because GeographicLib Exact is
not available for `f = 0`.

## Deterministic pseudo-random corpus

Use a fixed documented PRNG algorithm and seed.

For each mandatory ellipsoid generate geographic cases with:

~~~text
latitude:       stratified over [-90, +90]
delta longitude: stratified over [-60, +60]
lat0:           stratified over a representative legal range
lon0:           full longitude range
k0:             representative bounded engineering range around 1
false E/N:      representative finite range
~~~

Do not rely on a language/library PRNG whose sequence may change without
documenting that dependency.

Recommended initial size for `double`:

~~~text
>= 500000 points
~~~

Float and real may use smaller deterministic subsets if runtime becomes
significant, provided all adversarial/boundary cases remain exhaustive.

Current achieved Exact-reference corpus (2026-09-15):

~~~text
PRNG:                        SplitMix64
seed:                        0x544D5F4558414354
projection profiles:         84
source points/scalar:         500000
forward comparisons/scalar:  500000
reverse comparisons/scalar:  500000
scalars completed:            float, double
compilers:                    DMD, LDC
~~~

`float` was therefore validated with the full 500,000-point deterministic
corpus rather than a reduced subset.

## Reverse projected-space corpus

Do not derive the entire reverse corpus solely by calling `geodesy-d.forward`.

Build reverse test points from independent reference projections of the
geographic corpus.

Additionally include direct projected-space perturbations around:

- central meridian;
- natural origin;
- equator;
- projected poles;
- +/-60-degree longitude-domain boundary images.

This prevents the reverse validator from inheriting assumptions from the
implementation under test.

## Self-roundtrip regression suite

Maintain both:

~~~text
geographic -> geodesy-d forward -> geodesy-d reverse
projected  -> geodesy-d reverse -> geodesy-d forward
~~~

These tests are expected to be tight and useful for regression detection.

However, their results must be reported separately from independent accuracy
tests and must never be the sole basis for the public accuracy contract.

## Reference-differential requirements

### GeographicLib exact

Primary numerical oracle for oblate ellipsoids.

For every applicable case inside the supported standard sheet:

- build an equivalent ellipsoid and central scale;
- account for `lat0` with the same mathematically defined northing shift;
- apply identical false offsets;
- compare projected coordinates and reference point scale.

GeographicLib Exact is not used for the spherical case because its exact
elliptic-function formulation is singular in the spherical limit.

Record reference-library version and build precision.

### Sphere oracle

Validate `f = 0` independently with:

- direct analytic spherical Transverse Mercator formulas in the validation
  harness;
- PROJ's spherical `tmerc` path;
- GeographicLib `TransverseMercator`, which treats the sphere exactly.

At least two of these references must agree before a sphere discrepancy is
attributed to `geodesy-d`.

### GeographicLib series

Use as a same-family differential oracle.

Differences from the exact reference are useful for:

- establishing expected sixth-order truncation behaviour;
- diagnosing coefficient/sign/order bugs;
- comparing edge behaviour.

Do not simply copy GeographicLib expected outputs into committed unit tests
without recording how they were generated.

### PROJ

Use explicit `tmerc` operation parameters matching EPSG 9807.

Select the Poder/Engsager path explicitly where the installed version provides
algorithm selection.

Treat PROJ as a production-compatibility and same-family differential oracle,
not as the primary accuracy oracle for the order-8 `double`/`real` path. The
Poder/Engsager implementation is sixth order; at the synthetic `f = 0.01`,
`abs(deltaLongitude) = 60 deg` stress boundary its expected truncation differs
from GeographicLib Exact and from the eighth-order `geodesy-d` result by
centimetres.

Therefore:

- ordinary/reference-profile PROJ differences may retain tight compatibility
  tolerances;
- deliberately wide `f = 0.01` cases must be reported as same-family
  truncation diagnostics or use a separately documented compatibility envelope;
- a disagreement with PROJ at those stress points is not an accuracy failure
  when the GeographicLib Exact gate passes.

Record:

- PROJ version;
- operation string/creation method;
- ellipsoid parameters;
- any axis/unit normalization performed by the harness.

The harness must compare mathematical coordinates, not CLI-formatted text.

## Coefficient verification

Before relying on large differential corpora, verify generated/precomputed
series coefficients independently.

At minimum:

- compare compile-time/generated coefficients against checked canonical tables
  for order 6 and order 8;
- verify that `float` selects order 6 and `double`/`real` select order 8;
- test `n = 0` sphere limiting behaviour;
- test small `n` continuity.

A coefficient-table error can otherwise produce widespread correlated failures
that are harder to diagnose.

## Reverse Newton validation

Instrument a validation-only build or harness to record:

- iteration count;
- convergence residual;
- maximum correction;
- failure count.

Test especially:

- equator;
- near-pole latitudes;
- +/-60-degree longitude boundary;
- all mandatory ellipsoids;
- sphere path separately.

The production code need not expose iteration counts.

No performance explanation may cite Newton iteration distribution unless this
instrumentation was actually run.

## Non-finite and invalid-input tests

Projection construction must reject as applicable:

~~~text
invalid Ellipsoid<T>.init
flattening > 0.01
NaN scale
+/-inf scale
scale <= 0
NaN false easting/northing
+/-inf false easting/northing
~~~

Explicit constructor-boundary probes:

~~~text
f = 0
f = next representable below 0.01
f = 0.01
f = next representable above 0.01
f = 0.02
f = 0.1
~~~

Projected reverse input must reject:

~~~text
NaN easting/northing
+/-inf easting/northing
~~~

Geographic strong types already reject invalid latitude/longitude values; tests
should still verify integration with the projection API.

Finite intermediate overflow must return failure rather than silently emit a
valid-looking coordinate.

## Allocation and attributes

Compile-time tests should establish the intended API attributes where feasible:

~~~text
@safe
@nogc
pure
nothrow   # checked path
~~~

Runtime allocation instrumentation is optional if compile-time `@nogc` proves
the hot path cannot allocate through the GC.

Prepared projection construction may perform only work explicitly allowed by
its documented API; forward/reverse kernels must not allocate.

## Compiler matrix

Mandatory functional validation:

~~~text
DMD supported baseline
DMD current CI version
LDC supported baseline
LDC current CI version
~~~

Normative performance and strongest numerical corpus:

~~~text
LDC release
~~~

Run a representative numerical subset under DMD to detect compiler-specific
floating-point issues.

For wider `real`, ensure the CI matrix includes at least one target where
`real.mant_dig > double.mant_dig` if the project claims that path as supported.

## Platform matrix

At minimum, before a stable release:

- x86_64 Linux;
- one additional CI platform/architecture available to the project.

If `real` precision differs by platform, record validation results separately.

The public double contract must not depend on extended intermediates that happen
to exist on one architecture.

## Current structured-reference evidence

The large GeographicLib 2.7 `TransverseMercatorExact` corpora are now complete
for public `double` and `float` on the seven applicable oblate ellipsoids. DMD
and LDC evaluate the same deterministic input sets and report identical maxima.

### Double, order 8

Structured corpus:

~~~text
source points: 251853
forward comparisons: 251853
reverse comparisons: 251853
outside 0.001 m target: 0
worst absolute projected error: 0.00040720961988 m
worst ground-equivalent error: 0.000197241839122 m
worst case: SyntheticF001 point[17889], latitude = 0 deg,
            deltaLongitude = -60 deg, forward
~~~

Deterministic pseudo-random corpus:

~~~text
source points: 500000
forward comparisons: 500000
reverse comparisons: 500000
outside 0.001 m target: 0
worst absolute projected error: 0.00040489314832 m
worst ground-equivalent error: 0.000185580763518 m
worst case: SyntheticF001-R09 point[1892],
            latitude = 2.073008485 deg,
            deltaLongitude = 59.962000211 deg, forward
~~~

The order-6 A/B build at the wide synthetic boundary showed approximately
26.63 mm projected-position error against Exact. This continues to justify
order 8 for `double`/`real`.

### Float, double working precision, order 6

Structured corpus:

~~~text
source points: 251853
forward comparisons: 251853
reverse comparisons: 251853
outside 2 m target: 0
worst absolute projected error: 0.996066963705 m
worst ground-equivalent error: 0.996106511573 m
worst case: International1924 point[35813],
            latitude = 89.000001338 deg,
            deltaLongitude = -39.000002793 deg, forward
~~~

Deterministic pseudo-random corpus:

~~~text
source points: 500000
forward comparisons: 500000
reverse comparisons: 500000
outside 2 m target: 0
worst absolute projected error: 1.34535363361 m
worst ground-equivalent error: 1.17173743512 m
~~~

Public float validation is based on the actual stored float radians and scalar
parameters. In the structured corpus, 251,839 / 251,853 forward outputs
(99.994441%) exactly matched the correctly rounded Exact easting/northing pair;
in the random corpus the count was 499,931 / 500,000 (99.986200%). The promoted
represented-input double twin stayed within 0.000407213345174 m of Exact in the
structured corpus and 0.000404895849976 m in the random corpus. This is strong
evidence that the observed metre-scale maxima are dominated by binary32 output
representation rather than the promoted numerical kernel.

A dedicated diagnostic identified 43 high-latitude reverse boundary rejects in
the pre-fix structured float run. All had ellipsoidal parallel-distance overrun
<= 0.413757256467 m and projected-input quantization <= 0.491420437651 m. The
production reverse classifier now evaluates that representation-level boundary
excursion in physical distance; the post-fix structured corpus has zero
failures and the representative WGS 84 case is retained as a unit regression.

### PROJ compatibility

PROJ 9.7.1 smoke compatibility remains at nanometre scale in the tested
ordinary cases. Its sixth-order Poder/Engsager path differs from order-8
`geodesy-d` by about 26 mm at the synthetic wide-domain stress boundary; this is
treated as expected same-family truncation rather than a failure of the Exact
accuracy gate.

### Remaining work

The large structured/random Exact-reference sub-gates are complete for `double`
and `float`, but TM validation is not yet complete. Outstanding mandatory work
includes:

- independent spherical Transverse Mercator oracle and cross-checks;
- `real` validation with recorded platform/compiler precision properties;
- remaining deterministic boundary/property and runtime/API gates;
- reverse-Newton instrumentation required by this plan;
- reproducible LDC release performance baseline;
- required additional platform/architecture coverage before stable release.

## Acceptance gates

### Gate TM-A — semantics

PASS requires:

- EPSG 9807 natural-origin semantics correct;
- false offsets correct;
- scale factor correct;
- antimeridian normalization deterministic;
- pole canonical semantics correct;
- bounded-domain acceptance/rejection correct;
- `f = 0.01` accepted and values above it rejected;
- ordinary-profile versus representation-stress accuracy reporting separated.

### Gate TM-B — double numerical accuracy

Current status: **large Exact structured/random sub-gates PASS** for the seven
applicable oblate ellipsoids under both DMD and LDC. Full TM-B remains open until
the separate sphere oracle and the remaining deterministic boundary requirements
in this plan are complete.

PASS requires:

~~~text
all mandatory ellipsoids
all deterministic boundary cases
structured corpus
pseudo-random corpus
forward intrinsic ground-equivalent error <= 1 mm
reverse intrinsic ground-equivalent error <= 1 mm
ordinary-profile end-to-end error <= 1 mm
failures = 0 inside supported domain
~~~

### Gate TM-C — float numerical accuracy

Current status: **large Exact structured/random sub-gates PASS** under DMD and
LDC with zero cases outside the 2 m target. Full TM-C remains open until sphere
and the remaining scalar-generic deterministic/runtime requirements are
complete.

PASS requires:

~~~text
double working precision confirmed
forward intrinsic ground-equivalent error <= 2 m
reverse intrinsic ground-equivalent error <= 2 m
ordinary-profile end-to-end error <= 2 m
failures = 0 inside supported domain
~~~

### Gate TM-D — real numerical accuracy

Current status: **not yet run** for the required recorded `real` platform
properties and Exact corpus.

PASS requires:

~~~text
series order selection confirmed for actual real precision
forward intrinsic ground-equivalent error <= 1 mm
reverse intrinsic ground-equivalent error <= 1 mm
ordinary-profile end-to-end error <= 1 mm
failures = 0 inside supported domain
~~~

For `real`, additionally compare the order-8 path against the exact reference
and record the achieved maximum error. On wider-than-double platforms, record
whether the wider arithmetic improves the binary64 result or is limited by
series truncation/reference precision.

### Gate TM-E — API and runtime properties

PASS requires:

- checked API attribute tests;
- invalid-input tests;
- zero hidden GC allocation on forward/reverse;
- deterministic repeated results;
- DMD/LDC build and test pass.

### Gate TM-F — performance baseline

This gate records evidence; it is not a requirement to beat every reference.

PASS requires a reproducible LDC release benchmark with no correctness
regression.

## Performance benchmark design

Benchmark separately:

~~~text
forward
reverse
~~~

for corpora:

~~~text
UTM-like        abs(delta lon) <= 3 deg
ordinary TM     mixed 0..35 deg
wide TM         mixed 35..60 deg
~~~

Scalars:

~~~text
float public API
double public API
real public API
~~~

References:

~~~text
GeographicLib series
GeographicLib exact
PROJ tmerc high-accuracy path
~~~

Use in-process calls.

Do not include:

- process startup;
- CLI parsing;
- text formatting;
- file I/O;
- CRS database lookup.

Record:

~~~text
date
CPU
OS/kernel
compiler
D frontend
LLVM
PROJ version
GeographicLib version
build flags
CPU affinity
governor
turbo/frequency state
corpus size
round count
median or selected statistic
~~~

Report both absolute `ns/op` and same-process relative ratios.

Potential optimizations to investigate only after baseline:

- coefficient storage/layout;
- Horner form;
- Clenshaw implementation shape;
- common-subexpression reuse;
- stable sin/cos pairing;
- optional FMA only after numerical revalidation;
- bulk/autovectorized API only if a real consumer needs it.

Do not add an Evenden/Snyder fast path, explicit SIMD, or auto algorithm
selection merely to improve a microbenchmark before profiling demonstrates a
need.

## Test-data provenance

Every committed external reference vector must record:

- source project/document;
- version/date;
- license or redistribution status;
- generation command or method where applicable.

Large third-party corpora should remain outside Git unless redistribution and
repository-size costs are justified.

A small representative regression subset may be committed with provenance.

## Result reporting

When implementation validation is complete, record at minimum:

~~~text
case count per scalar
case count per ellipsoid
forward maximum intrinsic ground-equivalent error
reverse maximum intrinsic ground-equivalent error
ordinary-profile end-to-end maximum error
large-offset maximum error in ulps
worst-case input for each maximum
failure count
domain-rejection count
reference versions
compiler/platform
~~~

Keep exact worst cases, not only rounded summary numbers.

If a tighter public contract is considered, it must be justified by a broad
validation envelope rather than by the finite observed maximum alone.

## Promotion after validation

When all mandatory gates pass:

1. change ADR-0006 from `Proposed` to `Accepted`;
2. summarize achieved accuracy in `docs/VALIDATION.md`;
3. document algorithm provenance and domain in public Ddoc;
4. document measured cost in `docs/PERFORMANCE.md`;
5. add the projection surface to `docs/API.md`;
6. only then begin the UTM policy slice.
