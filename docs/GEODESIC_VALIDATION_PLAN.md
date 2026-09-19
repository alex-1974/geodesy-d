# Ellipsoidal geodesic validation plan

- Status: In progress
- Branch: `research/geodesics`
- Depends on: ADR-0008
- Target: direct and inverse ellipsoidal geodesics

## Purpose

This document defines the evidence required before the geodesy-d direct and
inverse ellipsoidal geodesic implementation can be considered accepted.

The implemented solver follows the Karney geodesic algorithm family.

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

Exact public cardinal values are a special case. A public `float` value
representing `0`, `+/-pi/2`, or `+/-pi` is interpreted according to the
library's exact public cardinal semantics before conversion to the oracle.
This prevents widening artifacts such as `float(pi)` from being mistaken for a
longitude slightly beyond mathematical `pi`.

This rule is inherited from the Transverse Mercator validation experience and
was strengthened during public geodesic validation.

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

GEO-A is PASS: the production solver and public API demonstrate these
semantics under both DMD and LDC, including coincident pole/antimeridian aliases
and canonical positive-zero results.

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


### GEO-B validation result

GEO-B is PASS.

The authoritative-reference gate is backed by three permanent validator
families, all passing under both DMD and LDC on the validated Linux x86-64
environment:

1. `research/geodesics/validate_reference_vectors.py`
   - 33 deterministic WGS84 rows selected from GeographicLib's official
     500,000-row `GeodTest.dat` high-precision corpus;
   - ordinary short/regional/intercontinental, near-antipodal, very-short,
     near-polar, opposite-pole, nearly-meridional, nearly-equatorial, and
     vertex-near cases;
   - analytical sphere cases and published GeographicLib examples;
   - decimal reference strings are parsed directly into D `real`.

2. `research/geodesics/validate_f001_reference_vectors.py`
   - 26 high-precision boundary-ellipsoid cases: 12 direct and 14 inverse;
   - `a = 7000000`, `f = 0.01`;
   - generated with GeographicLib 2.7 `GeodesicExact`,
     `GEOGRAPHICLIB_PRECISION=5`, and `GEOGRAPHICLIB_DIGITS=512`;
   - GeographicLib source pinned to commit
     `475cbde5b8528a6294dfeb054bc177d90be9f7bb`.

3. `research/geodesics/validate_regression_vectors.py`
   - 11 explicit historical GeographicLib geodesic regressions;
   - includes short-line, endpoint-at-pole, backwards-from-pole negative
     distance, near-antipodal roundoff/symmetry, signed-zero, antimeridian,
     NGS non-convergence, and directed-rounding cases;
   - expected values regenerated with the same qualified 512-bit MPFR
     `GeodesicExact` oracle.

Observed worst errors across the three reference families remain far below the
provisional `double`/wide-`real` ceilings:

~~~text
WGS84 official subset
    double
        max direct position angle       7.31102e-16 rad
        max direct tangent angle        7.86885e-16 rad
        max inverse normalized distance 1.00131e-15
        max inverse closure angle       9.09301e-16 rad

    real (x86-64, mant_dig == 64, order 7)
        max direct position angle       5.50571e-19 rad
        max direct tangent angle        6.22707e-19 rad
        max inverse normalized distance 2.85191e-19
        max inverse closure angle       4.32199e-19 rad

f = 0.01 MPFR Exact subset
    double
        max direct position angle       4.62367e-16 rad
        max direct tangent angle        5.24446e-16 rad
        max inverse normalized distance 5.74411e-16
        max inverse closure angle       7.41716e-16 rad

    real (x86-64, mant_dig == 64, order 7)
        max direct position angle       6.92241e-19 rad
        max direct tangent angle        6.61719e-19 rad
        max inverse normalized distance 5.19711e-19
        max inverse closure angle       1.51813e-18 rad

documented GeographicLib regressions
    double
        max direct position angle       4.41679e-17 rad
        max direct tangent angle        1.73724e-16 rad
        max inverse normalized distance 6.43962e-16
        max inverse closure angle       7.03120e-16 rad

    real (x86-64, mant_dig == 64, order 7)
        max direct position angle       1.10010e-19 rad
        max direct tangent angle        3.63652e-19 rad
        max inverse normalized distance 2.85191e-19
        max inverse closure angle       3.42068e-19 rad
~~~

The reference datasets and provenance files are committed, so normal GEO-B
validation does not require GeographicLib or MPFR at runtime. MPFR is needed
only to regenerate the synthetic high-precision reference data.

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

### GEO-C acceptance result

GEO-C is **PASS** as of the acceptance run at
`2026-09-18T23:54:41Z`.

The accepted public-API differential corpus contains, per public scalar,
`40150` Direct and `40160` Inverse comparisons across ten ellipsoid/scale
profiles and was passed under both DMD and LDC.

The bulk gate is complemented by a wide-`real` qualification against a
512-bit MPFR GeographicLib `GeodesicExact` oracle.  That qualification uses
inputs which are not preserved by a binary64 round trip and also passed under
both DMD and LDC.

Inverse direction comparison is conditioning-aware: ordinary cases use
absolute Earth-fixed tangent direction, very short cases use a transverse
`(s/a) * direction_error` metric, and deliberately near-antipodal cases use an
antipodal-defect-weighted direction metric.  Distance and endpoint closure
remain independently validated.

The exact toolchain, validator/oracle hashes, corpus sizes, observed maxima,
and acceptance-log hash are recorded in
`research/geodesics/data/GEO_C_PROVENANCE.md`.

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

### GEO-D acceptance result

GEO-D is **PASS**.

The accepted interoperability run used PROJ 9.7.1 through its double-based
geodesic C API as an external validation dependency only. PROJ remains absent
from the `geodesy-d` DUB, build, link, runtime, and production-source
dependency surface.

The accepted harness uses exact IEEE-754 binary64 bit-pattern input transport
and radians. For public `real`, interoperability inputs are deliberately
restricted to the exact binary64 subset:

~~~text
binary64 bits -> double -> exact widening to D real
~~~

A full transport audit covered 128063 unique binary64 values per compiler with
zero mismatches. Wider-than-binary64 `real` precision remains GEO-C evidence.

The public-real maximum-flattening profile uses
`nextDown(binary64(0.01))`, because exact widening of `binary64(0.01)` is
slightly greater than the more precise real-valued `f <= 0.01` boundary. The
same represented flattening is supplied to PROJ; no production tolerance or
support contract changes.

The deterministic full run used seed `0x47454F44`, eight ellipsoid profiles,
2000 generated cases plus six fixed cases per profile and operation, and all
three public scalar models under both DMD and LDC:

~~~text
per compiler:
    48144 Direct public-API cases
    48144 Inverse public-API cases
    96288 total

DMD + LDC:
    192576 public-API differential cases
~~~

Coverage includes sphere, WGS84, GRS80, International 1924, Airy 1830,
`f = 0.005`, the supported maximum-flattening profile, unit scale, ordinary,
short, polar, dateline, long-direct, and difficult near-antipodal cases.

The comparison uses endpoint position, Earth-fixed tangent direction, inverse
distance, and conditioned short/near-antipodal direction metrics. Coincident
and geometrically non-unique inverse azimuths are not treated as normative
PROJ equality requirements.

The accepted execution and provenance are committed as:

~~~text
research/geodesics/data/geod_acceptance_20260919T084049Z.log
research/geodesics/data/GEO_D_PROVENANCE.md
~~~

Acceptance log SHA-256:

~~~text
f45eedd052cc210e54cb696c852dee104b51167e952ab5165bd978045d279d0a
~~~

PROJ serves here as an interoperability oracle rather than an independent
mathematical oracle. GEO-B and GEO-C retain the independent numerical-evidence
role.

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

### GEO-E acceptance result

GEO-E is **PASS**.

The production inverse solver now exposes internal validation diagnostics for
start classification, dispatcher classification, Newton iteration count,
bracket-midpoint safeguarding, and explicit convergence status. These
diagnostics do not change the public geodesic API.

The accepted deterministic adversarial corpus uses seed `0x47454F45`, six
profiles, all three public scalar models, and 2000 cases per required
adversarial class. The resulting population is 16007 cases per scalar/profile,
or 288126 cases per compiler. Every payload is executed twice identically.

DMD and LDC produced identical global path coverage and identical observed
solver maxima. The accepted full run directly exercised:

~~~text
dispatcher:
    coincidence       6684
    meridian         14742
    equator             18
    generalShort     11852
    generalNewton   254830

start:
    none              21444
    shortLine         11852
    spherical        206849
    antipodal         24322
    antipodalAstroid  23659
~~~

The worst accepted convergence behavior was:

~~~text
max solver iterations:       12
max bracket midpoint count:  10
non-convergence:              0
deterministic mismatches:     0
~~~

The same large adversarial corpus was then compared directly against
`GeographicLib::GeodesicExact`. There are 288126 exact-oracle comparisons per
compiler and 576252 across DMD + LDC.

Accepted global maxima:

~~~text
normalized inverse distance error
    3.1478910906506436e-15

exact-direct endpoint closure angle
    3.0324792329808581e-15 rad

well-conditioned final forward azimuth error
    1.6651835466063858e-10 rad
~~~

The production limits remain unchanged:

~~~text
maxNewtonIterations = 20
maxIterations = 20 + W.mant_dig + 10
~~~

The observed maximum of 12 iterations stays below the primary Newton window of
20; the mantissa-dependent total bound retains an additional defensive margin
for safeguarded fallback.

Accepted evidence:

~~~text
research/geodesics/data/geoe_acceptance_20260919T092706Z.log
SHA-256:
9c2c714bf613f301201d5c74302699e26718a6e7a12c48a1287af7133c261aad

research/geodesics/data/geoe_exact_acceptance_20260919T094714Z.log
SHA-256:
f67ca368e02b9afc73c1ff88bb24b0a21d4f84b3683792cd243db71231454883

research/geodesics/data/GEO_E_PROVENANCE.md
~~~

The exact-oracle acceptance timestamp is `20260919T094714Z`.

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

## Current validation evidence

The implementation-stage reference run on 2026-09-18 produced the following
committed/reproducible evidence with GeographicLib 2.7 `GeodesicExact`:

~~~text
direct differential validator
    1526 deterministic double cases
    max normalized endpoint error     7.2278158967109059e-15
    max final azimuth error            2.9267092107734656e-14 rad

inverse dispatcher validator
    2352 deterministic cases
    all five dispatcher classes exercised:
        coincidence
        meridian
        equator
        general short line
        general Newton
    max normalized distance error      4.992850577423269e-11
    max exact-direct closure           2.7849784688640372e-15 rad
    max solver iterations              5

public inverse validator
    2352 cases per public scalar
    7056 total public-API cases

    float
        max normalized distance error  1.5689076873612841e-7
        max exact-direct closure       1.5689076931157901e-7 rad
        max Earth-fixed tangent error  2.0112855299844871e-7 rad

    double
        max normalized distance error  4.9988735373318605e-11
        max exact-direct closure       2.4279387088187486e-15 rad
        max Earth-fixed tangent error  2.4696224302280499e-15 rad

    real (x86-64, mant_dig == 64, order 7)
        max normalized distance error  4.9988735373318605e-11
        max exact-direct closure       2.1801050582500446e-15 rad
        max Earth-fixed tangent error  2.2206195148221764e-15 rad
~~~

The public inverse validator uses Earth-fixed 3D tangent direction as the
normative endpoint-direction metric. Raw local azimuth remains diagnostic
because azimuth coordinates become ill-conditioned close to a geographic pole.

The same reference run also passed:

- all current library unit tests under DMD and LDC (`19 modules`);
- an aggregate consumer compiled with DMD and LDC using only `import geodesy;`;
- the public GEO-A cardinal and coincident-point semantics;
- `git diff --check`.

These results are strong implementation evidence but do not waive validation
requirements that have not yet been executed.

## Acceptance matrix

Current status:

~~~text
GEO-A  contract and analytical semantics             PASS
GEO-B  authoritative reference vectors               PASS
GEO-C  GeographicLib Exact differential validation   PASS
GEO-D  PROJ interoperability                         PASS
GEO-E  adversarial inverse/convergence                PASS
GEO-F  API/runtime contract                          PARTIAL
GEO-G  platform/compiler/real-width coverage          PARTIAL
~~~

Status rationale:

- GEO-B passes the authoritative-reference requirement with the official
  GeographicLib WGS84 high-precision subset, a 512-bit MPFR
  `GeodesicExact` corpus at `f = 0.01`, explicit documented GeographicLib
  regression cases, analytical sphere cases, and published examples; all
  permanent GEO-B validators pass under DMD and LDC.
- GEO-C passes the accepted Exact/MPFR differential gate.
- GEO-D passes the PROJ public-API interoperability gate.
- GEO-E passes the adversarial/convergence gate with explicit internal
  instrumentation, direct bracket-midpoint observations, zero unexpected
  non-convergence, deterministic repeat behavior, and identical-corpus
  `GeographicLib::GeodesicExact` agreement.
- GEO-F has the checked public API, attributes, invalid-state behavior, unit
  tests, and aggregate compile contract; the specified large deterministic
  runtime-stress workload remains open.
- GEO-G currently has Linux x86-64 DMD/LDC evidence. The broader portable matrix
  and additional `real` widths remain open.

ADR-0008 remains `Proposed` until every mandatory gate is `PASS`.

## Immediate next step

GEO-A through GEO-E are complete.

The remaining mandatory work should proceed without changing the validated
mathematical core unless new evidence exposes a defect:

1. GEO-F deterministic runtime/API stress and allocation/attribute checks;
2. GEO-G portable compiler/platform and `real`-width coverage;
3. only after every mandatory gate is PASS, decide whether ADR-0008 may move
   from `Proposed` to `Accepted`.
