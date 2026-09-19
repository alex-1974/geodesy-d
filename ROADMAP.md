# geodesy-d Roadmap

`geodesy-d` is a dependency-light pure-D library for bounded geodetic
mathematics.

The roadmap is library-specific. Cross-library planning for the surrounding
workspace is available locally under `.workspace/ROADMAP.md`.

## Current state

The released line is:

```text
v0.1.1
```

The released baseline provides:

- strong angular and geographic/geocentric coordinate types;
- reference ellipsoids;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032/1033 static Helmert transformations.

The current `main` branch additionally contains the accepted but unreleased:

- bounded generic Transverse Mercator implementation;
- UTM policy and projection layer.

The current `research/geodesics` development branch additionally contains the
first public direct/inverse ellipsoidal geodesic slice.

That geodesic implementation is code-complete for its current first-slice API,
but the broader acceptance program defined by ADR-0008 is not yet complete.

ADR-0008 therefore remains:

```text
Status: Proposed
```

## Geodesic acceptance state

The authoritative status is maintained in
`docs/GEODESIC_VALIDATION_PLAN.md`.

Current state after GEO-D:

```text
GEO-A  contract and analytical semantics             PASS
GEO-B  authoritative reference vectors               PASS
GEO-C  GeographicLib Exact differential validation   PASS
GEO-D  PROJ interoperability                         PASS
GEO-E  adversarial inverse/convergence                PARTIAL
GEO-F  API/runtime contract                           PARTIAL
GEO-G  platform/compiler/real-width coverage          PARTIAL
```

The mathematical production core should not be changed merely to continue the
validation program. A core change is justified only when new evidence exposes a
correctness, numerical, semantic, API, or performance defect.

## Immediate sequence

Resume geodesic qualification in this order:

1. close GEO-E instrumentation and adversarial/convergence coverage;
2. complete GEO-F deterministic runtime/API stress;
3. complete GEO-G portable compiler/platform and `real`-width coverage;
4. only after every mandatory gate is PASS, decide whether ADR-0008 may move
   from `Proposed` to `Accepted`;
5. treat branch publication, integration into `main`, and release planning as
   explicit project decisions rather than automatic consequences of validation.

## Existing accepted post-v0.1 work

### EPSG 9602 reverse

The reverse geographic/geocentric conversion uses the accepted hybrid
Fukushima/Halley plus extended Vermeille/Karney strategy.

Its numerical semantics, terrestrial accuracy envelope, and performance
evidence are recorded in ADR-0005 and the validation documentation.

### Transverse Mercator

ADR-0006 is accepted.

The implementation provides a bounded generic Transverse Mercator operation
with explicit scalar, ellipsoid, domain, and accuracy contracts.

### UTM

ADR-0007 is accepted.

UTM remains a policy layer over the generic Transverse Mercator implementation.
It does not own MGRS, CRS discovery, or authority-database functionality.

## Deferred geodesic capabilities

The first direct/inverse slice intentionally does not include:

```text
GeodesicLine
arc-mode direct
longitude unrolling
public reduced length
M12/M21 geodesic scales
geodesic area
polygon accumulation
geodesic intersections
geodesic nearest-point operations
rhumb lines
prolate ellipsoids
```

These are not missing requirements of the current acceptance program.

They should be added only when a concrete consumer justifies a separately
specified and independently validated extension.

## Responsibility boundary

`geodesy-d` owns bounded mathematics whose semantics depend on:

- the Earth or a reference ellipsoid;
- geographic or geocentric coordinates;
- reference-frame transformations;
- map-projection mathematics;
- ellipsoidal geodesics.

It does not own:

```text
general Euclidean geometry / topology              -> geo-d
MGRS / Geohash / Open Location Code                -> locationref-d
EPSG database / WKT / PROJJSON / grids / discovery -> future proj-d
raster or image processing                         -> imagery-d
OpenStreetMap data and formats                     -> osm-d
```

The numerical geodesic core has no requirement to depend on `geo-d`,
`imagery-d`, or `osm-d`.

Adapters are preferred over unnecessary cross-library coupling.

## Numerical-development rules

For every substantial numerical extension:

1. identify the mathematical method and primary reference;
2. define public semantics and supported domain;
3. establish scalar policy;
4. define failure and canonicalization semantics;
5. implement the smallest bounded slice;
6. validate against authoritative vectors;
7. cross-check against a numerically independent implementation where
   practical;
8. add regression cases for every discovered defect;
9. validate DMD and LDC;
10. add multi-platform coverage when platform-dependent `real` behaviour is
    material;
11. benchmark only after correctness is established.

Broad `@fastmath` is not a library policy.

## Release policy

`v0.1.x` remains the released compatibility baseline.

Post-v0.1 functionality is not considered release-ready merely because its
implementation exists. Each major numerical slice must satisfy its own
documented acceptance contract.

No new feature milestone is required merely to make the library larger.

## Workspace context

When this repository is developed inside `d-geospatial-workspace`, current
shared architecture and research context is exposed locally under:

```text
.workspace/
```

Those files are not part of the `geodesy-d` repository or DUB package.

The repository-level roadmap remains specific to `geodesy-d`.
