# geodesy-d

`geodesy-d` is a pure-D library for geodetic mathematics: positions on or relative to the Earth, reference ellipsoids, geocentric coordinates, frame transformations, map-projection mathematics, and related numerical operations.

It is intentionally smaller than a complete CRS engine. The library provides well-defined mathematical building blocks without requiring the PROJ runtime for those bounded operations.

## Status

**v0.1 release preparation.**

The intended v0.1 public baseline is implemented and under release audit. It
contains strong angular/coordinate value types, reference ellipsoids, EPSG 9602
bidirectional geographic/geocentric conversion, EPSG 1031 geocentric
translation, and EPSG 1032/1033 static 7-parameter Helmert transformations.

The API is documented and validated, but Semantic Versioning stability begins
only when the repository is tagged `v0.1.0`.

## Responsibility boundary

`geodesy-d` owns mathematics whose meaning depends on the Earth, a reference ellipsoid, geographic/geocentric coordinates, frame transformations, or a map projection.

Examples:

```text
Angle / Latitude / Longitude
Ellipsoid
GeodeticCoordinate
GeocentricCoordinate (ECEF terminology)
geodetic ↔ geocentric conversion
Helmert transformations
Transverse Mercator
UTM
ellipsoidal geodesics
```

It does **not** own:

```text
general Euclidean geometry / polygon topology     -> geo-d
MGRS / Geohash / Open Location Code              -> georef-d
EPSG database / WKT / PROJJSON / grid resources  -> proj-d
```

A projected result may later be adapted to a `geo-d` point, but `geodesy-d` does not require `geo-d` merely to represent projected coordinates.

## v0.1 implemented baseline

The v0.1 baseline contains:

```text
Angle / Latitude / Longitude
Ellipsoid
GeodeticCoordinate
GeocentricCoordinate
EPSG 9602  geodetic <-> geocentric
EPSG 1031  geocentric translations
EPSG 1033  Position Vector Helmert 7P
EPSG 1032  Coordinate Frame Helmert 7P
```

Projection mathematics and ellipsoidal geodesics remain later milestones and
are not v0.1 release blockers.

## Current and planned layering

A tentative module layout is:

```text
source/geodesy/
├── package.d
├── scalar.d
├── errors.d
├── angle.d
├── ellipsoid.d
├── geodetic.d
├── geocentric.d
├── conversion.d
├── transform/
│   ├── geocentric_translation.d # EPSG 1031
│   └── helmert.d                 # EPSG 1032 / 1033
├── projection/
│   ├── transverse_mercator.d     # later
│   └── utm.d                     # later
└── geodesic/
    └── ...                       # later
```

The layout is not an API commitment. Modules should be added only when a real implementation requires them.

## Design principles

The workspace-wide `DESIGN_PRINCIPLES.md` applies unchanged. For `geodesy-d`, several consequences are especially important:

- semantic value types are preferred over naked numeric tuples;
- materially different coordinate domains must not be implicitly interchangeable;
- units and angle conventions must be explicit at API boundaries;
- hidden allocation is avoided in the numerical core;
- `@safe`, `@nogc`, `nothrow`, `pure`, and CTFE compatibility are design targets where the algorithm and D implementation permit them;
- broad `@fastmath` is not a project policy;
- numerical accuracy and convergence behavior must be documented per operation;
- mature external systems should be reused where their full infrastructure is required, while bounded pure-D mathematical kernels remain legitimate when they provide independent value.

## Numerical and validation policy

Every non-trivial geodetic operation should be backed by authoritative or trusted reference material and by reference vectors.

Expected validation layers:

1. exact/simple analytical cases where available;
2. published or authoritative reference vectors;
3. forward/inverse round trips;
4. boundary and near-degenerate cases;
5. randomized cross-validation against a trusted independent implementation where practical;
6. regression tests for every discovered numerical defect.

For Earth-coordinate operations, important edge cases include poles, equator, longitude boundaries, zero/large heights, and values close to algorithmic singularities.

The numerical core is floating-point-generic. `float`, `double`, and `real` are supported instantiations, but `double` is the normative reference precision. `float` is explicitly reduced precision; `real` has no portable precision guarantee beyond `double`. Tolerances are algorithm-specific rather than derived from one global machine-epsilon comparison rule.


## Linear-unit policy

`geodesy-d` does not introduce a `Length<T>` wrapper in v0.1. Ellipsoid axes, ellipsoidal height, projected coordinates, and geocentric Cartesian coordinates use scalar linear values. Mathematical operations that combine them require all participating linear values to use the same unit.

This keeps the numerical kernel independent of a unit framework while preserving an explicit operation-level unit contract. Metres are the normal geodetic convention and the unit used by the initial reference data, but the core value types do not hard-code metres into their representation.

`GeocentricCoordinate.init` is the geocentre `(0, 0, 0)` and is representable; an inverse geocentric-to-geodetic operation may reject or specially handle it because longitude/latitude are not uniquely defined there.

## Dependency policy

The numerical core should begin with the D standard library only unless a dependency is justified by a concrete requirement.

`geodesy-d` must not depend on PROJ. `proj-d` is a separate native-integration library for the complete CRS/authority ecosystem.

A future dependency on `geo-d` is not assumed. Prefer small native geodetic value types and explicit adapters until a real consumer proves that direct coupling is beneficial.

## Historical prototype

The earlier repository `alex-1974/coordinate` explored several of the same domains in pure D, including latitude/longitude types, ECEF, UTM/MGRS, datum/ellipsoid data, geodetic conversions, and frame transformations.

It is treated only as a historical design and test-case source. `geodesy-d` will not continue, fork, or transplant its implementation. Algorithms must be re-derived from primary or authoritative references and independently implemented under the current project design and licensing rules.

## Documentation

- `docs/API.md` — v0.1 public API baseline.
- `docs/VALIDATION.md` — compiler and independent PROJ validation policy.
- `docs/V0_1_READINESS.md` — release gate checklist.
- `docs/REFERENCES.md` — reference hierarchy and validation sources.
- `docs/adr/0001-scope-and-boundaries.md` — responsibility boundary.
- `docs/adr/0002-core-type-and-unit-model.md` — core type/unit model.
- `docs/adr/0003-helmert-rotation-conventions.md` — EPSG 1032/1033 convention model.
- `docs/adr/0004-invalid-ellipsoid-default-state.md` — `Ellipsoid.init` semantics.
- `docs/operations/geographic-geocentric.md` — EPSG 9602.
- `docs/operations/geocentric-translation.md` — EPSG 1031.
- `docs/operations/helmert-7p.md` — EPSG 1032/1033.

The workspace `ROADMAP.md` remains the authoritative project roadmap.


## Release readiness

The v0.1 release gate is tracked in `docs/V0_1_READINESS.md`.


## Compiler compatibility

`geodesy-d` v0.1 declares D frontend **2.111.0** as the minimum supported
frontend. CI also tests current DMD and LDC. A newer workspace development
baseline does not imply that consumers must use that newer frontend.
