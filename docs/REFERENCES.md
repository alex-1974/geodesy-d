# geodesy-d reference and validation policy

`geodesy-d` implements numerical geodetic operations. Correctness therefore depends not only on code review but on a traceable relationship between each implementation, its mathematical definition, and independent reference results.

## Reference hierarchy

Use the strongest available source for each operation.

### 1. IOGP / EPSG

Primary source for standardized coordinate-operation methods, parameter meanings, units, sign conventions, and worked examples.

Expected uses include:

- geographic ↔ geocentric conversion;
- geocentric translations;
- Helmert transformation conventions;
- map-projection method definitions where standardized by EPSG.

For each implemented EPSG method, documentation should record the method name/code, parameter definitions, and the exact source revision used for validation.

### 2. Primary numerical publications

Use original or authoritative algorithm papers where the numerical method matters beyond the formal EPSG method description.

Examples include Charles F. F. Karney's work for accurate geodesics and Transverse Mercator algorithms.

### 3. GeographicLib

Use as a trusted independent numerical reference where it implements the same mathematical problem, especially direct/inverse ellipsoidal geodesics and related difficult cases.

The goal is cross-validation, not source-code transplantation.

### 4. PROJ

Use as an independent interoperability and numerical cross-check for operations also supported by PROJ.

PROJ is not a runtime dependency of `geodesy-d`. It is a valuable oracle for generated test vectors and differential testing, subject to documenting the PROJ version and operation parameters used.

### 5. Additional authoritative standards

Use other standards or national/international geodetic sources when they define an operation that is not adequately covered above.


## Implemented operation: EPSG 9602

The first numerical operation is the bidirectional geographic/geocentric conversion (EPSG method 9602).

IOGP's current publication library continues to list Report 373-07-2 as the formula reference for EPSG coordinate conversions and transformations. The regression vectors used here are traceable to the publicly accessible December 2024 report, while method identities, parameter semantics, and Helmert convention behavior are additionally cross-checked against the current EPSG/PROJ ecosystem.

See `docs/operations/geographic-geocentric.md` for the operation-level contract and test vector.

## Implemented operation: EPSG 9836 / 9837 topocentric conversions

The pre-v1 roadmap admits a bounded topocentric East/North/Up capability.

Normative semantics are taken from:

~~~text
IOGP Report 373-07-02
EPSG Guidance Note 7-2
December 2024

EPSG method 9836 — Geocentric/topocentric conversions
EPSG method 9837 — Geographic/topocentric conversions
EPSG method 9602 — Geographic/geocentric conversions
~~~

EPSG 9836 defines a right-handed local Cartesian frame:

~~~text
U = East
V = North
W = Up
~~~

where `Up` is normal to the ellipsoid at the topocentric origin.

EPSG 9837 is treated as the semantic composition:

~~~text
geographic/geodetic
    ↕ EPSG 9602
geocentric
    ↕ EPSG 9836
topocentric
~~~

The mandatory acceptance vector is the published WGS 84 worked example with:

~~~text
origin:
    latitude  = 55 deg N
    longitude = 5 deg E
    height    = 200 m

source:
    latitude  = 53 deg 48 min 33.820 sec N
    longitude =  2 deg 07 min 46.380 sec E
    height    = 73 m

expected topocentric:
    East  = -189013.869 m
    North = -128642.040 m
    Up    =   -4220.171 m
~~~

The equivalent EPSG 9836 geocentric-origin example uses:

~~~text
X0 = 3652755.3058 m
Y0 =  319574.6799 m
Z0 = 5201547.3536 m
~~~

with source:

~~~text
X = 3771793.968 m
Y =  140253.342 m
Z = 5124304.349 m
~~~

and the same expected East/North/Up result.

Independent implementation references for the research and validation program
are:

~~~text
GeographicLib 2.7
    LocalCartesian
    Geocentric

PROJ
    topocentric
    cart + topocentric pipeline
~~~

The exact PROJ version used for differential validation must be recorded by the
validation harness rather than assumed by this document.

PROJ and GeographicLib are validation/research references only and are not
runtime dependencies.

See:

~~~text
docs/adr/0009-topocentric-enu.md
docs/TOPOCENTRIC_VALIDATION_PLAN.md
~~~

ADR-0009 is Accepted. The complete TOPO-A through TOPO-G acceptance program
passed on 2026-09-20, including EPSG worked vectors, PROJ and GeographicLib
differential validation, adversarial/failure semantics, aggregate API
validation, and hosted compiler/platform/`real`-width coverage.

## Historical `coordinate` repository

The repository `alex-1974/coordinate` is a historical pure-D prototype and may be inspected for:

- problem decomposition;
- API lessons;
- edge cases worth testing;
- algorithms/features previously considered useful;
- historical test vectors whose provenance can be independently verified.

It is **not** an authoritative mathematical source and is not an implementation source for `geodesy-d`.

No code should be copied from it into `geodesy-d`.

## Per-operation documentation

Every substantial numerical operation should document:

```text
operation name
mathematical/reference source
source revision/version/date
input domain and units
output domain and units
algorithm/series/order used
known singularities or undefined cases
convergence criterion, if iterative
expected/observed accuracy
reference test vectors
independent cross-validation target and version
```

## Test-vector classes

A mature operation should normally have several kinds of tests.

### Authoritative examples

Worked examples from EPSG/IOGP or primary references should be reproduced to documented tolerances.

### Simple analytical cases

Examples where the expected answer is exact or obvious, such as selected axis/equator cases.

### Boundary cases

Depending on the operation:

- poles;
- equator;
- longitude wrap boundary;
- very small and very large ellipsoidal height;
- near-antipodal geodesics;
- projection central meridian and zone edges;
- degenerate or undefined inputs.

### Round trips

For inverse pairs:

```text
A -> B -> A
B -> A -> B
```

Round-trip tolerances must be derived from the operation's intended numerical accuracy, not selected arbitrarily to make tests pass.

### Differential/randomized tests

Generate many valid inputs and compare with an independent trusted implementation such as PROJ or GeographicLib.

Randomized tests must record enough information to reproduce failures. Any discovered failure becomes a permanent deterministic regression test.

## Tolerances

Avoid a universal epsilon.

Tolerance is operation-specific and should account for:

- physical units;
- floating-point scalar;
- conditioning of the operation;
- reference accuracy;
- documented algorithmic truncation/error bounds.

Prefer absolute tolerances for quantities naturally bounded near zero, relative tolerances where scale varies significantly, and combined criteria where justified.

`T.epsilon` is a representation property, not a universal geodetic tolerance. It must not be used by itself to widen mathematically exact domain boundaries or to define a library-wide approximate ordering relation. Where long sums or series materially accumulate rounding error, compensated summation should be considered before simply increasing scalar precision.

## Fast-math policy

`@fastmath` or compiler options that relax IEEE behavior are not enabled globally for numerical geodesy.

They may be considered for a particular algorithm only when:

1. benchmarks demonstrate material benefit;
2. the resulting numerical behavior is characterized;
3. authoritative/reference and randomized tests show the required accuracy is preserved;
4. the decision is documented.


## EPSG 9602 reverse numerical methods

The current reverse geographic/geocentric implementation uses a hybrid of a
fast Fukushima/Halley path and a robust extended Vermeille/Karney fallback.

### Fukushima 2006

Primary reference for the fast path:

Toshio Fukushima,
"Transformation from Cartesian to geodetic coordinates accelerated by
Halley's method",
Journal of Geodesy 79, 689-693 (2006).

DOI:

~~~text
10.1007/s00190-006-0023-2
~~~

`geodesy-d` uses the homogeneous reduced-latitude Halley formulation as the
ordinary-position fast path.

The implementation does not use Fukushima's method as the sole inverse.
Candidates are accepted only after checking a scale-independent algebraic
defect, and difficult cases fall back to the robust branch.

### Vermeille 2002

Primary reference for the direct algebraic inverse:

H. Vermeille,
"Direct transformation from geocentric coordinates to geodetic coordinates",
Journal of Geodesy 76, 451-454 (2002).

DOI:

~~~text
10.1007/s00190-002-0273-6
~~~

The production fallback is not a literal implementation of the original
formula alone. It uses the stabilized extended formulation described below.

### Karney / GeographicLib

Charles F. F. Karney's GeographicLib `Geocentric` implementation is the
numerical reference for the extended and stabilized Vermeille branch used by
the robust fallback.

The geodesy-d implementation follows the relevant oblate-spheroid numerical
structure, including:

- the real-discriminant and three-real-root branches;
- cancellation-avoiding cubic-root algebra;
- stable evaluation of `u + v`;
- the degenerate equatorial-evolute solution;
- the canonical nearest-ellipsoid solution for multiply representable
  deep-interior Cartesian points.

The implementation reference used during development and validation was:

~~~text
GeographicLib 2.7
Geocentric::IntReverse
~~~

GeographicLib is an independent validation and algorithm-provenance reference.
It is not a build or runtime dependency of `geodesy-d`.

### Relationship to EPSG method 9602

EPSG/IOGP remains normative for:

- the coordinate-operation identity;
- coordinate meanings;
- ellipsoid parameter semantics;
- units;
- axis conventions;
- the forward geographic-to-geocentric equations.

Fukushima, Vermeille, and Karney are numerical-method references for computing
the reverse EPSG 9602 operation robustly and efficiently.

ADR-0005 records why this hybrid was selected and which alternatives were
rejected.

Numerically significant algorithms must also be identified in public API
documentation. ADRs document why an implementation was selected; API/Ddoc
documents what mathematical method the current implementation uses.


## Ellipsoidal geodesics

### Karney 2013

Primary mathematical reference for the direct and inverse geodesic algorithms:

Charles F. F. Karney,
"Algorithms for geodesics",
Journal of Geodesy 87, 43-55 (2013).

DOI:

```text
10.1007/s00190-012-0578-z
```

The geodesy-d implementation follows the Karney algorithm family: the
auxiliary-sphere formulation, series expansions, robust inverse starting
strategy, and safeguarded Newton/bracketing solution.

Vincenty's direct/inverse algorithms are not the production basis.

### GeographicLib implementation reference

GeographicLib is used in two distinct roles:

1. `Geodesic` is an implementation/provenance reference for coefficient
   structure, special cases, inverse starting logic, and numerical safeguards.
2. `GeodesicExact` is the preferred independent differential oracle because it
   solves the same geodesic problem with a numerically distinct
   elliptic-integral formulation.

The implementation/reference source pinned during this development slice was:

```text
GeographicLib 2.7
source commit:
475cbde5b8528a6294dfeb054bc177d90be9f7bb
```

The production library does not link to or require GeographicLib.

Committed research validators include:

```text
research/geodesics/validate_direct.py
research/geodesics/validate_inverse_solver.py
research/geodesics/validate_inverse_dispatch.py
research/geodesics/validate_public_inverse.py
```

The current exact-oracle evidence and remaining acceptance gates are recorded
in `docs/GEODESIC_VALIDATION_PLAN.md`.

### PROJ interoperability role

PROJ is an interoperability reference for the geodesic surface, but its
geodesic implementation shares Karney/GeographicLib lineage and therefore is
not treated as a mathematically independent oracle.

The dedicated GEO-D geodesic interoperability gate remains part of the
acceptance program and must be recorded separately from GeographicLib Exact
validation.

## Geocentric frame transformations

- EPSG method 1031 — Geocentric translations (geocentric domain)
- EPSG method 1033 — Position Vector transformation (geocentric domain)
- EPSG method 1032 — Coordinate Frame rotation (geocentric domain)

The EPSG/IOGP parameter sign conventions are normative for these APIs.


### Helmert convention policy

ADR-0003 makes the EPSG 1032 Coordinate Frame and EPSG 1033 Position Vector rotation conventions distinct at the type level. PROJ Helmert documentation is used as an independent cross-validation source for convention conversion and parameter interchange behavior.


### EPSG 1033 reference vector

The initial Position Vector implementation is validated against the IOGP Guidance Note 7-2 WGS 72 -> WGS 84 worked example (EPSG transformation 1238).


### EPSG 1032 equivalence vector

The Coordinate Frame implementation is validated with the same WGS 72 -> WGS 84 worked case as EPSG 1033, using the EPSG rule that the three rotations change sign while translations and scale remain unchanged.


## PROJ differential validation

PROJ/cct is used only as an independent validation oracle. The initial deterministic differential matrix covers EPSG 9602, 1031, 1032 and 1033. PROJ is not a geodesy-d runtime or build dependency.
