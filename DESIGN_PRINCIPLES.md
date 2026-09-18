# geodesy-d Design Principles

This document records engineering principles specific to `geodesy-d`.

The library may be developed inside `d-geospatial-workspace`, but it remains
an independent Git repository and DUB package.

Current shared workspace principles are available locally under:

```text
.workspace/DESIGN_PRINCIPLES.md
```

They provide cross-library context. This file records the consequences that
are specifically important to `geodesy-d`.

## 1. Bounded geodetic mathematics

`geodesy-d` implements bounded mathematical operations whose semantics depend
on the Earth, a reference ellipsoid, geographic/geocentric coordinates,
reference-frame transformations, map projections, or surface geodesics.

It must not grow into a general CRS engine.

Authority databases, WKT/PROJJSON parsing, grid-resource management, automatic
operation discovery, and general CRS pipelines belong outside this library.

## 2. Strong domain semantics

Materially different concepts should use materially different public types.

Examples include:

```text
Angle
Latitude
Longitude
GeographicCoordinate
GeodeticCoordinate
GeocentricCoordinate
ProjectedCoordinate
Ellipsoid
UtmZone
UtmCoordinate
```

Units and conventions must be explicit at API boundaries.

Coordinates do not silently acquire datum, CRS, epoch, or authority metadata.

## 3. Mathematical provenance before implementation

A non-trivial numerical algorithm must have documented provenance.

Preferred hierarchy:

1. IOGP/EPSG for standardized operation semantics;
2. primary mathematical/numerical publications;
3. GeographicLib or another trusted independent implementation;
4. PROJ for interoperability and differential cross-checking.

Historical prototypes are not mathematical specifications.

## 4. Independent numerical validation

Implementation success is not acceptance.

Each substantial operation must define its validation gate before being treated
as complete.

Evidence may include:

- analytical cases;
- authoritative reference vectors;
- independently generated high-precision vectors;
- differential validation;
- adversarial and singular cases;
- deterministic random corpora;
- round-trip/property tests;
- regression cases;
- compiler and platform matrices.

Self-consistency alone is insufficient evidence for numerical correctness.

## 5. Scalar policy is explicit

Public numerical types support:

```text
float
double
real
```

`double` is the normative reference precision unless an operation-specific
contract states otherwise.

`float` is explicitly reduced precision.

D `real` is platform-dependent and therefore requires platform-sensitive
validation when wider precision is material.

Public scalar choice and internal working precision are separate design
decisions and must be documented per algorithm.

## 6. No global epsilon

There is no library-wide approximate-equality rule.

Exact mathematical domains remain exact.

Algorithmic convergence limits and validation tolerances are
operation-specific and must be justified by numerical evidence.

Machine epsilon is a representation property, not a geodetic error budget.

## 7. Correctness before performance

Priority order:

1. mathematical and semantic correctness;
2. explicit invariants and domain;
3. numerical robustness;
4. appropriate algorithm/data representation;
5. measured performance;
6. low-level optimization.

Broad `@fastmath` is prohibited unless a specific algorithm has both a measured
benefit and complete revalidation of its numerical contract.

## 8. Allocation-free checked numerical paths where practical

Hot checked numerical APIs should preserve, where the operation permits:

```text
pure
nothrow
@safe
@nogc
```

Throwing convenience wrappers may provide ergonomic error reporting separately.

Hidden allocation must not be introduced into numerical kernels without a
documented reason.

## 9. Checked public construction

Caller-supplied values must be validated by normal API mechanisms.

Assertions are for internal invariants and are not an external-input error
mechanism.

Where useful, the public pattern is:

```text
try...      checked non-throwing path
throwing    convenience path using GeodesyValueException
```

Invalid `.init` states, where unavoidable or deliberately chosen, must be
explicitly documented and detectable.

## 10. Small public API

Implementation helpers remain private/package-internal unless they represent a
stable domain concept required by real consumers.

The public API should expose geodetic concepts rather than intermediate
algorithm machinery.

Before `1.0`, incompatible improvements remain possible, but they must be
deliberate and documented.

## 11. External libraries are references, not accidental runtime dependencies

PROJ and GeographicLib are valuable validation and interoperability systems.

They must not become runtime dependencies of `geodesy-d` merely because they
are used as numerical or semantic oracles.

A bounded pure-D mathematical implementation is justified only when it provides
independent value while retaining serious external validation.

## 12. Explicit support domains

A templated algorithm is not automatically valid for every representable
input.

Every substantial operation should document:

- mathematical domain;
- supported ellipsoid domain;
- scalar policy;
- singular or ambiguous cases;
- canonical output rules;
- accuracy contract;
- convergence/failure semantics.

Bounded support is preferred to vague claims of global validity.

## 13. Canonicalization is part of semantics

Where a mathematical result has multiple equivalent representations, public
canonicalization rules must be explicit.

Examples include:

- longitude representation;
- azimuth representation;
- signed zero where externally observable;
- coincident geodesic results;
- deep-interior geocentric inverse solutions.

Canonicalization must not be introduced accidentally by implementation detail.

## 14. Regression evidence is permanent

Every numerical or semantic defect should gain a permanent deterministic
regression case.

Validator defects are also regression-worthy.

Reference-data provenance must be retained sufficiently to reproduce or audit
the evidence later.

## 15. Performance claims require controlled evidence

Performance-sensitive work should use reproducible release-mode benchmarks,
normally with LDC.

Benchmark documentation should identify relevant:

- compiler/frontend;
- CPU and platform;
- dependency versions;
- build mode;
- corpus;
- iteration/sample count;
- controlled CPU state where material.

No causal performance claim should be made from timing alone when the proposed
cause was not measured.

## 16. Cross-library boundaries

Current intended ownership is:

```text
geo-d
    coordinate-system-agnostic Euclidean geometry

geodesy-d
    Earth/ellipsoid-dependent mathematics

locationref-d
    compact/discrete geographic reference systems

imagery-d
    raster/image-engine functionality

osm-d
    OpenStreetMap data and format support

future proj-d
    broad CRS/authority/grid/operation infrastructure
```

Direct dependencies are introduced only when they represent genuine conceptual
layering and concrete consumers justify them.

Adapters are preferred when coupling would otherwise be incidental.

## 17. Consumer-driven extension

Feature count is not a maturity metric.

Extended geodesic quantities, new projection families, time-dependent frame
transformations, or other operations should be added only when their semantics,
validation burden, and consumer value are understood.

A smaller validated library is preferable to a broader partially qualified one.

## 18. Compiler support

The package declares minimum D frontend:

```text
2.111.0
```

DMD and LDC are required compiler families.

GDC is best effort unless and until explicitly promoted to the supported
matrix.

A newer workspace development compiler does not automatically raise the
published package minimum.

## 19. Documentation is part of acceptance

A substantial numerical slice is not complete until its public semantics,
mathematical provenance, validation evidence, limitations, and acceptance
status are documented.

ADRs record persistent design decisions.

Validation plans record qualification requirements.

`docs/API.md` records the public surface.

`ROADMAP.md` records current library sequencing.

## 20. Workspace context is not package content

The canonical workspace context lives under:

```text
.workspace/
```

when this repository is checked out inside `d-geospatial-workspace`.

That directory is ignored by Git and is not published as part of the package.

Repository-root documentation remains specific to `geodesy-d`.
