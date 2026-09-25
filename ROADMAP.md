# geodesy-d Roadmap

`geodesy-d` is a dependency-light pure-D library for bounded geodetic
mathematics.

The roadmap is library-specific. Cross-library planning for the surrounding
workspace is available locally under `.workspace/ROADMAP.md`.

## Current state

The released line is:

```text
v0.2.0
```

The released baseline provides:

- strong angular and geographic/geocentric coordinate types;
- reference ellipsoids;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032/1033 static Helmert transformations;
- bounded generic Transverse Mercator implementation;
- UTM policy and projection layer;
- first public direct/inverse ellipsoidal geodesic slice.

The geodesic implementation is code-complete for its current first-slice API,
and the technical acceptance program defined by ADR-0008 is complete. PR #10
integrated the accepted slice into `main`; PR #11 subsequently synchronized
the D language-practice documentation and public API compatibility contracts.

ADR-0008 is now:

```text
Status: Accepted
```

The accepted scope is the validated first direct/inverse public slice. Deferred
geodesic capabilities remain future work and require their own consumer or
research justification.

The first post-v0.2 P0 capability is also complete:

```text
topocentric ENU    ACCEPTED
ADR-0009           Accepted
TOPO-A .. TOPO-G   PASS
```

The bounded EPSG 9836/9837 topocentric surface is now integrated into `main`.

Transverse Mercator / UTM projection factors are accepted under ADR-0011.
The next admitted P0 research slice is Pseudo-Mercator.

## Geodesic acceptance state

The authoritative status is maintained in
`docs/GEODESIC_VALIDATION_PLAN.md`.

Current state after GEO-G:

```text
GEO-A  contract and analytical semantics             PASS
GEO-B  authoritative reference vectors               PASS
GEO-C  GeographicLib Exact differential validation   PASS
GEO-D  PROJ interoperability                         PASS
GEO-E  adversarial inverse/convergence                PASS
GEO-F  API/runtime contract                           PASS
GEO-G  platform/compiler/real-width coverage          PASS
```

The mathematical production core should not be changed merely to continue the
validation program. A core change is justified only when new evidence exposes a
correctness, numerical, semantic, API, or performance defect.

## Post-v0.2 sequence

The `v0.2.0` baseline completes the first admitted projection/geodesic sequence:
bounded Transverse Mercator, UTM policy, and the first validated direct/inverse
ellipsoidal geodesic slice.

Work toward `v1.0.0` follows the workspace rule of depth before breadth and
research before new abstractions.

Current P0 state:

```text
topocentric ENU                         ACCEPTED
Transverse Mercator / UTM factors      ACCEPTED
Pseudo-Mercator                         ACTIVE — PM-G2 API/RUNTIME
```

Continue in this order:

1. research and qualify the remaining admitted P0 v1.0 capability slices
   defined below;
2. for each remaining P0 slice, define the mathematical method, public semantics,
   supported domain, scalar policy, failure semantics, independent validation,
   and API shape before implementation is accepted;
3. evaluate the two P1 geodesic extensions only against concrete consumer
   requirements;
4. after the accepted pre-v1 capability work is complete, perform a full
   public-API, documentation, compatibility, and release-readiness audit before
   freezing the v1 surface;
5. require any further optimization work to begin from fresh profiling or
   concrete consumer evidence.

Existing accepted numerical cores must not be changed merely to expand scope.
A production-core change still requires correctness, numerical, semantic, API,
consumer, or measured performance evidence.

## v1.0 target scope

The goal for `v1.0.0` is a small but practically useful stable library for
bounded Earth- and ellipsoid-dependent mathematics. Feature count is not a
maturity metric, but the stable baseline should cover the common coordinate,
projection, and geodesic building blocks expected by real consumers.

The following three capability slices are admitted P0 work before the v1 API
freeze.

### P0 — topocentric ENU — accepted

This capability was accepted on 2026-09-20 under ADR-0009 after completion of
TOPO-A through TOPO-G and is integrated into `main`.

The accepted implementation provides a prepared local topocentric
East/North/Up frame with forward and reverse
conversion between Earth-fixed/geodetic coordinates and local ENU
coordinates.

The intended ownership boundary is:

- `geodesy-d` owns construction and transformation of the Earth-dependent
  topocentric frame;
- local Euclidean geometry performed after conversion to ENU belongs to
  `geo-d` or to the consumer;
- `geodesy-d` must not acquire a dependency on `geo-d` merely to represent or
  transform ENU coordinates.

The accepted contract fixes the relevant EPSG semantics, origin and
orientation conventions, singular cases, scalar policy, and independent
validation evidence. See ADR-0009 and
`docs/TOPOCENTRIC_VALIDATION_PLAN.md`.

### P0 — Transverse Mercator / UTM projection factors — accepted 2026-09-21

This capability is accepted under ADR-0011.

The implemented additive API provides:

- `ConformalProjectionFactors!T`;
- meridian convergence as `Angle!T`;
- dimensionless isotropic point scale;
- checked and throwing forward-factor operations on `TransverseMercator!T`;
- checked and throwing reverse-factor operations on `TransverseMercator!T`;
- the same four operations on prepared `UtmProjection!T` objects by exact
  delegation to their underlying bounded Transverse Mercator operation.

The existing coordinate forward/reverse API remains unchanged.

Reverse factors use the same post-policy represented geographic point as public
reverse projection, including representation-aware +/-60-degree boundary
handling and the canonical pole convention defined by ADR-0011.

Automatic UTM zone-selection helpers do not gain separate factor operations.
Broader non-conformal projection differentials and CRS-level factor discovery
remain outside this accepted slice.

### P0 — Pseudo-Mercator

Add a bounded forward/reverse Pseudo-Mercator mathematical kernel suitable for
the projection used by common web maps.

`geodesy-d` owns only the projection mathematics and its numerical/domain
contract.

It does not own:

- EPSG authority lookup or CRS objects;
- axis/unit metadata;
- automatic operation discovery;
- WKT or PROJJSON;
- zoom levels;
- XYZ/TMS tile addressing;
- tile bounds, URLs, caches, or raster handling.

Those remain responsibilities of `proj-d`, `imagery-d`, or higher-level
consumers as appropriate.

The public name is now accepted as `PseudoMercator`. PM-F rejects a
`WebMercator` alias for the initial API; CRS and tile-policy naming remain
outside this mathematical projection type.

PM-A through PM-E are complete. Method semantics, represented domain,
scalar-specific numerical paths, independent forward/reverse differential
evidence, controlled compiler behaviour, and the current research performance
boundary are qualified.

PM-F is complete. The accepted public surface is recorded in
`research/pseudo-mercator/PM_F_PUBLIC_API.md`.

PM-G is now the active gate.

PM-G0 production endpoint qualification is complete. The selected endpoint is
derived from the actual principal branch by finite public-lattice bisection,
with the prepared legal public east longitude retained as the authoritative
exact reverse identity. The durable gate passes 8682 origins and 51975 endpoint
round-trip checks with zero failures across the controlled six-compiler matrix.

PM-G1 production module extraction is complete. The production module
`geodesy.projection.pseudo_mercator` implements the accepted PM-F surface and
qualified PM-E/PM-G0 semantics. Baseline module and full-repository tests pass
under DMD 2.111.0 and LDC 1.41.0.

PM-G2 public API / aggregate / runtime contract validation is active.

Subsequent PM-G gates validate production-to-research equivalence,
production-to-research equivalence, the full controlled DMD/LDC matrix, and
platform / release / regression boundaries before Pseudo-Mercator is marked
accepted.

### P1 — consumer-confirmed geodesic extensions

Two geodesic extensions are legitimate `geodesy-d` functionality but are not
automatic v1 blockers:

- a minimal prepared `GeodesicLine` for repeated distance-based positions on
  one geodesic;
- geodesic perimeter and signed-area accumulation for a sequence of geographic
  points/edges.

They should be included before `v1.0.0` only when a concrete consumer
demonstrates that the capability is needed before the API freeze. Otherwise
they remain suitable additive `1.x` work.

A geodesic area accumulator owns ellipsoidal measurement only. It must not grow
into a polygon topology model. Ring validity, holes, overlay, containment,
intersection topology, and general polygon representation belong to `geo-d`
or higher-level consumers.

`GeodesicLine`, if admitted before v1, should initially remain the smallest
consumer-justified distance-mode slice. Arc mode, longitude unrolling, reduced
length, geodesic scales, and other advanced quantities are separate extensions.

### v1.0 capability non-goals

The following are not required merely to reach `v1.0.0`:

- arc-mode geodesic direct operation;
- longitude unrolling;
- public reduced length;
- `M12` / `M21` geodesic scales;
- geodesic intersections;
- geodesic nearest-point operations;
- rhumb lines;
- prolate ellipsoids;
- UPS or additional projection families;
- time-dependent / 14-parameter frame transformations.

These may be valid future `geodesy-d` work, but each requires its own consumer
or research justification and acceptance contract.

The following remain outside the `geodesy-d` domain regardless of the release
milestone:

- general Euclidean geometry and polygon topology;
- MGRS, Geohash, and Open Location Code;
- CRS databases, WKT/PROJJSON, transformation grids, and operation discovery;
- raster/image processing and web-map tile infrastructure;
- OpenStreetMap data models and file formats.

After the accepted pre-v1 capability slices are complete, the final v1 gate is
API stability rather than further breadth: every public symbol, public
parameter name where source compatibility matters, default-state semantic,
error/failure contract, scalar policy, canonicalization rule, and supported
domain must be consciously accepted as part of the stable v1 contract.

## v0.2.0 numerical surfaces

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

The accepted direct/inverse slice intentionally does not include the advanced
geodesic capabilities listed below:

~~~text
arc-mode direct
longitude unrolling
public reduced length
M12/M21 geodesic scales
geodesic intersections
geodesic nearest-point operations
rhumb lines
prolate ellipsoids
~~~

These are not missing requirements of the current acceptance program and are
not v1.0 blockers.

`GeodesicLine` and geodesic perimeter/signed-area accumulation are treated
separately as P1 consumer-confirmed candidates in the v1.0 target scope above.
They are not automatically admitted merely because GeographicLib or another
reference implementation exposes analogous functionality.

Any advanced geodesic extension must be separately specified and independently
validated before acceptance.

## Responsibility boundary

`geodesy-d` owns bounded mathematics whose semantics depend on:

- the Earth or a reference ellipsoid;
- geographic, geodetic, geocentric, or local topocentric coordinates;
- reference-frame transformations;
- explicitly selected map-projection mathematics and projection factors;
- ellipsoidal geodesics and ellipsoidal measurement along geodesic paths.

The boundary is mathematical rather than application-specific.

For local topocentric work, `geodesy-d` owns Earth/ECEF/geodetic to ENU frame
construction and transformation. Once coordinates are represented in a local
Euclidean frame, general geometry operations belong to `geo-d` or the
consumer.

For geodesic area/perimeter work, `geodesy-d` may own ellipsoidal accumulation
over an ordered sequence of geographic points or geodesic edges. It does not
own polygon topology, ring validity, hole semantics, overlay, containment, or
general polygon modelling.

For projections, `geodesy-d` may own a bounded mathematical projection kernel,
its inverse, and operation-specific factors. It does not own CRS identifiers,
authority databases, CRS metadata, WKT/PROJJSON, grid-resource management, or
automatic coordinate-operation discovery.

Pseudo-Mercator projection mathematics may therefore belong here, while
slippy-map zoom/tile addressing, tile storage, URLs, caches, and raster
processing do not.

The cross-library ownership remains:

~~~text
general Euclidean geometry / topology              -> geo-d
MGRS / Geohash / Open Location Code                -> locationref-d
EPSG database / WKT / PROJJSON / grids / discovery -> future proj-d
raster / image / tile-engine processing            -> imagery-d
OpenStreetMap data and formats                     -> osm-d
~~~

The numerical core has no requirement to depend on `geo-d`, `imagery-d`, or
`osm-d`.

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

`v0.2.0` is the released compatibility baseline.

The planned path to `v1.0.0` is deliberately bounded:

1. qualify and accept the remaining P0 capability slices;
2. admit P1 capability only when concrete consumer evidence justifies it;
3. reconcile release-facing documentation and permanent API contracts;
4. perform an explicit v1 public-API freeze and readiness audit;
5. validate the complete frozen surface across the supported compiler and
   platform matrix before tagging.

Post-v0.2 functionality is not considered release-ready merely because its
implementation exists. Each major numerical slice must satisfy its own
documented acceptance contract.

`v1.0.0` does not require every conceivable geodetic feature. No additional
feature family is required merely to make the library larger.

## Workspace context

When this repository is developed inside `d-geospatial-workspace`, current
shared architecture and research context is exposed locally under:

```text
.workspace/
```

Those files are not part of the `geodesy-d` repository or DUB package.

The repository-level roadmap remains specific to `geodesy-d`.
