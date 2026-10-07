# geodesy-d

`geodesy-d` is a pure-D library for geodetic mathematics: positions on or relative to the Earth, reference ellipsoids, geocentric coordinates, frame transformations, map-projection mathematics, and related numerical operations.

It is intentionally smaller than a complete CRS engine. The library provides well-defined mathematical building blocks without requiring the PROJ runtime for those bounded operations.

## Status

**Stable v1 line — v1.2.0 released. M3 Navigation & Polar Geodesy is complete.**

`geodesy-d v1.0.0` was released on September 26, 2026. The frozen v1 public
API includes the accepted coordinate, transformation, projection, geodesic,
and topocentric families documented below.

v1.2.0 is the current published stable feature release. It completes M3
Navigation & Polar Geodesy while preserving the frozen v1 source-compatibility
baseline. The next planned development milestone is M4 — Reference Frames.

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
Transverse Mercator / Pseudo-Mercator
UTM / Polar Stereographic / UPS
Lambert Conformal Conic 2SP / Lambert Azimuthal Equal Area
ellipsoidal geodesics
rhumb / RhumbLine navigation
```

It does **not** own:

```text
general Euclidean geometry / polygon topology     -> geo-d
MGRS / Geohash / Open Location Code              -> locationref-d
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

Projection mathematics and ellipsoidal geodesics were intentionally not
v0.1 release blockers.

## Frozen v1 implementation

The frozen v1 surface additionally contains:

```text
bounded generic Transverse Mercator
UTM policy/projection layer
direct and inverse ellipsoidal geodesics
EPSG 9836/9837 topocentric East/North/Up conversions
```

The geodesic slice is publicly exported, implementation-complete, and
accepted under ADR-0008. GEO-A through GEO-G are complete in
`docs/GEODESIC_VALIDATION_PLAN.md`.

The topocentric slice is publicly exported and accepted under ADR-0009.
TOPO-A through TOPO-G are complete in
`docs/TOPOCENTRIC_VALIDATION_PLAN.md`.

## Current and planned layering

A tentative module layout is:

```text
source/geodesy/
├── package.d
├── scalar.d
├── errors.d
├── angle.d
├── ellipsoid.d
├── epoch.d                       # decimal-year geodetic epoch
├── geodetic.d
├── geocentric.d
├── topocentric.d                  # EPSG 9836 / 9837
├── conversion.d
├── transform/
│   ├── geocentric_translation.d # EPSG 1031
│   ├── helmert.d                 # EPSG 1032 / 1033
│   └── dynamic_helmert.d         # EPSG 1053 / 1056
├── projection/
│   ├── factors.d                 # conformal convergence / scale
│   ├── transverse_mercator.d     # implemented
│   ├── pseudo_mercator.d         # implemented
│   ├── utm.d                     # implemented
│   ├── polar_stereographic.d     # implemented
│   ├── ups.d                     # implemented
│   ├── lambert_conformal_conic.d # implemented 2SP
│   └── lambert_azimuthal_equal_area.d # implemented
├── geodesic.d                    # direct/inverse + quantities/line
├── geodesic_polygon.d            # perimeter / signed area
└── rhumb.d                       # rhumb / RhumbLine
```

The layout is not an API commitment. Modules should be added only when a real implementation requires them.

## Design principles

The current shared workspace principles are available locally under
`.workspace/DESIGN_PRINCIPLES.md`. The repository-level
`DESIGN_PRINCIPLES.md` records the additional principles specific to
`geodesy-d`.

Several consequences are especially important:

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

- `docs/API.md` — frozen v1 public API reference.
- `docs/VALIDATION.md` — compiler and independent PROJ validation policy.
- `docs/V1_2_RELEASE_READINESS.md` — current v1.2.0 release qualification.
- `docs/V1_2_API_AUDIT.md` — v1.2 public API freeze audit.
- `docs/M3_INTEGRATION_GATE.md` — M3 aggregate validation/performance closure.
- `docs/M4_EPOCH_SEMANTICS.md` — epoch/rate model for dynamic reference-frame transformations.
- `docs/DYNAMIC_HELMERT_VALIDATION.md` — EPSG 1053/1056 and PROJ validation contract.
- `docs/REFERENCES.md` — reference hierarchy and validation sources.
- `docs/adr/0001-scope-and-boundaries.md` — responsibility boundary.
- `docs/adr/0002-core-type-and-unit-model.md` — core type/unit model.
- `docs/adr/0003-helmert-rotation-conventions.md` — EPSG 1032/1033 convention model.
- `docs/adr/0004-invalid-ellipsoid-default-state.md` — `Ellipsoid.init` semantics.
- `docs/adr/0006-transverse-mercator.md` — bounded Transverse Mercator.
- `docs/adr/0007-utm-policy.md` — UTM policy.
- `docs/adr/0008-ellipsoidal-geodesics.md` — direct/inverse geodesic contract.
- `docs/adr/0009-topocentric-enu.md` — EPSG 9836/9837 topocentric ENU contract.
- `docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md` — Transverse Mercator validation.
- `docs/UTM_VALIDATION_PLAN.md` — UTM validation.
- `docs/GEODESIC_VALIDATION_PLAN.md` — geodesic acceptance program and evidence.
- `docs/GEODESIC_FEATURE_MATRIX.md` — post-M2 capability audit against GeographicLib/PROJ and admission decisions.
- `docs/RHUMB_RESEARCH.md` — rhumb/RhumbLine numerical and semantic contract.
- `docs/POLAR_STEREOGRAPHIC_RESEARCH.md` — Polar Stereographic research and accepted contract.
- `docs/ADDITIONAL_PROJECTION_ADMISSION_AUDIT.md` — LCC/LAEA admission evidence.
- `docs/TOPOCENTRIC_VALIDATION_PLAN.md` — topocentric acceptance program and evidence.
- `docs/operations/geographic-geocentric.md` — EPSG 9602.
- `docs/operations/geocentric-translation.md` — EPSG 1031.
- `docs/operations/helmert-7p.md` — EPSG 1032/1033.

The repository-level `ROADMAP.md` is authoritative for `geodesy-d`.
The workspace-wide coordination roadmap is available locally as
`.workspace/ROADMAP.md`.


## Release readiness

The completed v1.0.0 release record is `docs/V1_RELEASE_READINESS.md`.
The completed v1.0.1 patch record is `docs/V1_0_1_RELEASE_READINESS.md`.
The completed v1.1.0 release record is `docs/V1_1_RELEASE_READINESS.md`.
The completed M3 integration record is issue #74. The v1.2.0 release record is
`docs/V1_2_RELEASE_READINESS.md`; post-v1.2 work follows the repository roadmap.


## Compiler compatibility

`geodesy-d` declares D frontend **2.111.0** as the minimum supported
frontend. CI also tests current DMD and LDC. A newer workspace development
baseline does not imply that consumers must use that newer frontend.


### M4 reference-frame transformation research

- [Molodensky-Badekas](MOLODENSKY_BADEKAS.md) — EPSG 1034/1061 semantics,
  Helmert-kernel reuse, reversibility boundary, and independent validation.
