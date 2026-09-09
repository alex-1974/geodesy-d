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

Current IOGP publication metadata identifies Report 373-07-2 as version 74, July 2026. The initial worked-example regression vector is the WGS 84 North Sea example that is also present in the publicly accessible December 2024 edition. Before a stable release, revalidate the method text and worked vector against the exact current publication revision.

See `docs/operations/geographic-geocentric.md` for the operation-level contract and test vector.

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
