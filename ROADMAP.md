# geodesy-d Roadmap

`geodesy-d` is a dependency-light pure-D library for bounded geodetic
mathematics.

The roadmap is library-specific. Cross-library planning for the surrounding
workspace is available locally under `.workspace/ROADMAP.md`.

## Current state

`v1.0.0` was released on 2026-09-26 and is the stable compatibility baseline.
Its public API is frozen by the completed v1 audit and release-readiness
program. The annotated release tag is immutable; development on `main` is now
post-v1 work.

The v1 baseline provides:

- strong angular and geographic/geocentric coordinate types;
- reference ellipsoids;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032/1033 static Helmert transformations;
- bounded Transverse Mercator and UTM projection mathematics;
- Transverse Mercator / UTM conformal projection factors;
- bounded Pseudo-Mercator;
- prepared topocentric ENU transformations;
- validated direct/inverse ellipsoidal geodesics.

The release is published through GitHub and the DUB registry. Fresh external
registry consumers have built, linked, and executed `geodesy-d 1.0.0` with
both DMD and LDC, including representative UTM forward/reverse API use.

## Post-v1 development policy

Post-v1 work follows four rules:

1. preserve the frozen v1 source and semantic contract throughout compatible
   `1.x` development;
2. prefer additive, consumer-justified capability over speculative breadth;
3. require correctness, numerical, semantic, consumer, or measured performance
   evidence before changing an accepted numerical core;
4. keep CRS databases, operation discovery, general Euclidean geometry,
   raster/image processing, and application policy outside `geodesy-d`.

Compatible additive API may ship in `1.x`. A change that breaks the frozen v1
contract requires an explicit compatibility/versioning decision and normally
belongs to a future `2.0`.

## Post-v1 milestones

### M1 — Post-v1 Baseline

**Goal:** establish the clean development baseline after the v1.0.0 release.

Scope:

- record v1.0.0 as the stable released baseline across release-facing docs;
- close post-publish registry and external-consumer verification;
- make `main` explicitly the post-v1 development line;
- retain the frozen v1 contract as the compatibility reference;
- document the `1.x` compatibility/versioning policy;
- remove or reconcile stale pre-v1 planning language without rewriting
  historical acceptance evidence.

Exit criterion:

> Repository status, release documentation, and development policy consistently
> describe v1.0.0 as released and `main` as post-v1 development.

### M2 — Gap & Consumer Audit

**Goal:** determine what geodesy-d should add next from concrete library and
consumer needs rather than feature enumeration.

Audit inputs:

- existing deferred items and research in this repository;
- real requirements from `geo-d`, `geo3-d`, `raster-d`, `imagery-d`,
  `osm-d`, the planned editor, and future `proj-d` / `locationref-d`
  boundaries;
- gaps exposed by external use of the frozen v1 API;
- numerical edge cases and performance evidence from the v1 validation suite.

Classify findings as:

- additive public API candidate;
- numerical/algorithmic improvement;
- performance opportunity;
- validation or platform-coverage improvement;
- documentation/ergonomics improvement;
- interoperability requirement;
- explicitly out of scope.

Candidate capabilities already deferred from pre-v1 work include a minimal
prepared `GeodesicLine` and geodesic perimeter/signed-area accumulation.
They are candidates, not commitments: admission requires consumer or research
justification and a bounded acceptance contract.

Exit criterion:

> A prioritized, evidence-backed backlog identifies the bounded scope proposed
> for v1.1 and records deferred/out-of-scope work separately.

### M3 — v1.1 Development

**Goal:** implement and validate the additive scope admitted by M2 while
preserving the frozen v1 contract.

For each admitted numerical/API slice:

1. define ownership and consumer need;
2. define mathematical method and references;
3. define public semantics, units, domains, scalar policy, failure semantics,
   canonicalization, and compatibility constraints;
4. implement the smallest useful bounded slice;
5. validate against authoritative vectors and, where practical, an independent
   implementation;
6. add regression and adversarial cases;
7. validate DMD and LDC plus material platform-dependent behaviour;
8. benchmark only after correctness is established;
9. document the public API and provide compiled examples;
10. rerun the frozen-v1 compatibility contract before acceptance.

Exit criterion:

> The admitted v1.1 scope is complete, independently validated, documented,
> source-compatible with v1.0.0, and release-ready.

## Performance and numerical work

The v1.0.0 release establishes the semantic baseline for optimization. Future
performance work must compare equivalent behaviour and preserve that baseline.

Initial performance work should:

- establish reproducible DMD 2.111 and LDC 1.41 baselines;
- identify hot paths through profiling or concrete consumers;
- compare equivalent work with checksums, warm-up, repeated balanced runs, and
  reported median/spread;
- introduce compiler/version-specific implementations only for reproducible
  gains with identical semantics and a portable reference path.

Numerical research should continue to stress the accepted domains, especially
poles, the antimeridian, nearly antipodal geodesics, TM/UTM boundaries, and
`float`/`double`/`real` behaviour. New evidence may justify implementation
changes, but accepted cores are not rewritten merely for novelty.

## Deferred geodesic capabilities

The accepted direct/inverse slice intentionally leaves advanced capabilities
for separately justified future work:

~~~text
prepared GeodesicLine
geodesic perimeter / signed-area accumulation
arc-mode direct
longitude unrolling
public reduced length
M12/M21 geodesic scales
geodesic intersections
geodesic nearest-point operations
rhumb lines
prolate ellipsoids
~~~

A geodesic area accumulator may own ellipsoidal measurement over an ordered
sequence of geographic points or edges. Polygon topology, ring validity,
holes, overlay, containment, and general polygon representation remain outside
this library.

## Responsibility boundary

`geodesy-d` owns bounded mathematics whose semantics depend on:

- the Earth or a reference ellipsoid;
- geographic, geodetic, geocentric, or local topocentric coordinates;
- reference-frame transformations;
- explicitly selected map-projection mathematics and projection factors;
- ellipsoidal geodesics and ellipsoidal measurement along geodesic paths.

The cross-library ownership remains:

~~~text
general Euclidean geometry / topology              -> geo-d
MGRS / Geohash / Open Location Code                -> locationref-d
EPSG database / WKT / PROJJSON / grids / discovery -> future proj-d
raster / image / tile-engine processing            -> imagery-d
OpenStreetMap data and formats                     -> osm-d
~~~

Adapters are preferred over unnecessary cross-library coupling. A dependency
on another workspace library is justified only when it reflects genuine
conceptual layering required by concrete consumers.

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

`v1.0.0` is the stable compatibility baseline.

For the `1.x` line:

- additive API is permitted when it preserves the frozen v1 contract;
- implementation, validation, documentation, and performance work may evolve
  without weakening documented semantics;
- public parameter names, overload shapes, default-state semantics,
  error/failure contracts, scalar policy, canonicalization, and supported
  domains remain compatibility-sensitive;
- breaking changes require an explicit versioning decision and are not folded
  casually into a minor release.

The next release target is not defined by feature count. M2 determines the
evidence-backed v1.1 scope; M3 implements only the capabilities admitted there.

## Workspace context

When this repository is developed inside `d-geospatial-workspace`, current
shared architecture and research context is exposed locally under:

~~~text
.workspace/
~~~

Those files are not part of the `geodesy-d` repository or DUB package.
The repository-level roadmap remains specific to `geodesy-d`.
