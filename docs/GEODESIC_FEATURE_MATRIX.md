# Geodesic feature matrix

## Purpose

This document audits the public ellipsoidal-path surface of `geodesy-d`
against GeographicLib and PROJ after completion of the M2 v1.1 geodesic
family.

It is a scope and admission document, not a requirement to reproduce either
reference implementation feature-for-feature.

The comparison answers four separate questions:

1. what `geodesy-d` already provides;
2. what comparable GeographicLib / PROJ geodesic surfaces provide;
3. which differences are deliberate library-boundary decisions;
4. which remaining differences are plausible future additions and under what
   evidence they should be admitted.

The authoritative `geodesy-d` API remains `docs/API.md` and the repository
roadmap remains `ROADMAP.md`.

## Reference baseline

The audit uses the following external reference surfaces:

- GeographicLib geodesic family:
  `Geodesic`, `GeodesicLine`, polygon-area accumulation, and the general
  geodesic outputs exposed by the GeographicLib C geodesic library;
- PROJ geodesic support, including its direct/inverse API and the
  GeographicLib-derived geodesic C routines incorporated by PROJ.

Reference documentation:

- https://geographiclib.sourceforge.io/geod.html
- https://geographiclib.sourceforge.io/html/C/library.html
- https://geographiclib.sourceforge.io/html/C/geodesic_8h.html
- https://proj.org/en/stable/geodesic.html
- https://proj.org/en/stable/development/reference/functions.html

The comparison is semantic. Different names or API shapes are not treated as
missing functionality when the mathematical operation is already present.

## Status legend

~~~text
YES       public production capability exists in geodesy-d
PARTIAL   core operation exists but a broader reference surface is omitted
DEFER     plausible future capability; no current release requirement
PLANNED   already represented by an open roadmap issue
BOUNDARY  deliberately belongs outside geodesy-d
REJECT    no current justification for adding the reference surface
~~~

## Core geodesic matrix

| Capability | geodesy-d v1.1 | GeographicLib / PROJ reference | Decision |
|---|---|---|---|
| Ellipsoidal direct problem | YES — `Geodesic.tryDirect/direct` | GeographicLib and PROJ provide direct geodesic evaluation | Retain |
| Ellipsoidal inverse problem | YES — `Geodesic.tryInverse/inverse` | GeographicLib and PROJ provide inverse geodesic evaluation | Retain |
| Sphere specialization | YES | Supported by zero flattening | Retain |
| Oblate ellipsoid | YES, bounded public domain | Supported | Retain |
| Prolate ellipsoid | NO | GeographicLib/PROJ accept negative flattening | DEFER; requires independent research and a public-domain decision |
| Reduced length `m12` | YES — `GeodesicQuantities.reducedLength` | General GeographicLib geodesic outputs provide it | Retain |
| Geodesic scales `M12/M21` | YES | General GeographicLib geodesic outputs provide them | Retain |
| Signed segment area `S12` | YES | General GeographicLib geodesic outputs provide it | Retain |
| Runtime output mask/capability mask | NO | GeographicLib exposes output/capability masks | REJECT as public model unless a consumer proves a need; compile-time specialization is preferred |
| Auxiliary-sphere arc `a12` result | NO public carrier | GeographicLib general routines expose it | DEFER; not required by current consumers |
| Arc-mode direct input | NO | GeographicLib general direct/line routines support arc mode | DEFER; candidate with advanced line capabilities |
| Longitude unrolling | NO | GeographicLib general routines support long-unroll behavior | DEFER; candidate with advanced line capabilities |
| Repeated distance positions on prepared line | YES — `GeodesicLine.tryPosition/position` | GeographicLib `GeodesicLine`; PROJ/geod can generate intermediate points | Retain |
| Repeated arc positions on prepared line | NO | GeographicLib line general-position surface supports arc mode | DEFER |
| Advanced quantities from prepared line position | NO | GeographicLib line general-position surface can return `m12/M12/M21/S12` | DEFER |
| Construct line from start + azimuth | YES | Supported | Retain |
| Construct line from inverse endpoints | NO convenience constructor | GeographicLib offers inverse-line preparation | REJECT as duplicate convenience unless profiling/consumer evidence shows value |
| Store/set a distinguished point-3 distance/arc on line | NO | GeographicLib C line surface supports set-distance/set-arc state | REJECT unless a concrete consumer needs mutable reference-point state |
| Distance-mode negative line position | YES | Supported | Retain |

## Polygon and path-measurement matrix

| Capability | geodesy-d v1.1 | GeographicLib reference | Decision |
|---|---|---|---|
| Streaming polygon vertices | YES — `GeodesicPolygonAccumulator` | PolygonArea supports progressive accumulation | Retain |
| Closed geodesic perimeter | YES | Supported | Retain |
| Signed ellipsoidal area | YES, CCW positive | Supported | Retain |
| Antimeridian-safe area normalization | YES | Supported | Retain |
| Pole-safe area normalization | YES | Supported | Retain |
| Algebraic self-intersection area | YES | Supported | Retain |
| Compensated accumulation | YES | Reference implementations use enhanced accumulation precision | Retain |
| Dynamic vertex storage required | NO | Reference surfaces do not require caller-side storage for streaming mode | Retain |
| Polyline/perimeter-only mode | NO | GeographicLib PolygonArea has a polyline mode | DEFER; admit only with concrete consumer evidence |
| Add edge by azimuth + distance | NO | GeographicLib PolygonArea exposes edge addition | DEFER; convenience, not missing mathematical kernel |
| Test tentative point without mutation | NO | GeographicLib exposes TestPoint-style operations | REJECT for now; caller can copy accumulator value and evaluate |
| Test tentative edge without mutation | NO | GeographicLib exposes TestEdge-style operations | REJECT for now |
| Clear/reset existing accumulator | NO dedicated method | GeographicLib PolygonArea can be cleared | REJECT for now; assign/recreate prepared value unless profiling proves reset has value |
| Polygon topology, holes, ring validity, containment, overlay | BOUNDARY | Not part of the geodesic accumulator core | BOUNDARY -> `geo-d` / consumer geometry layer |

## Advanced ellipsoidal geometry

These capabilities are not part of the v1.1 core and should not be inferred
from the term "complete geodesic family".

| Capability | Current status | Admission path |
|---|---|---|
| Robust geodesic/geodesic-line intersection | PLANNED | M5 issue #46 |
| Nearest point on geodesic / segment | PLANNED | M5 issue #47 |
| Cross-track / along-track quantities | PLANNED | M5 issue #47 |
| Geodesic circles / loci | PLANNED research-first | M5 issue #48 |
| Rhumb direct/inverse | PLANNED as separate family | M3 issue #37 |
| Prepared RhumbLine | PLANNED as separate family | M3 issue #37 |

Rhumb lines are intentionally not methods on `Geodesic!T`: they are a
different mathematical family.

## Capabilities intentionally not imported from GeographicLib/PROJ

### Runtime output masks

GeographicLib's general geodesic routines expose runtime masks/capabilities so
one API can select many output combinations.

`geodesy-d` does not adopt that public pattern. Where the caller's required
capability is statically known, compile-time semantic specialization is
preferred. The public API should expose meaningful operations and result
types rather than a bitmask protocol unless a real consumer demonstrates that
runtime output selection is necessary.

### Mutable prepared-line reference point

Reference implementations expose operations that attach a point-3 distance or
arc to a prepared geodesic line.

That is not currently useful enough to justify mutable state in
`GeodesicLine!T`. A caller can evaluate a position and keep the returned
value explicitly.

### Polygon tentative-operation helpers

`TestPoint` / `TestEdge` style helpers are convenient in interactive
algorithms, but the D accumulator is a value type. Copying the accumulator,
adding a candidate, and computing the result already expresses the operation
without expanding the permanent API.

This decision should be revisited only if profiling shows that copy/evaluate is
materially expensive in a real consumer.

## Candidate: advanced GeodesicLine slice

The most coherent unimplemented extension of the existing M2 family is not a
new geodesic solver. It is a bounded extension of prepared-line capabilities:

~~~text
GeodesicLine
├── distance position                  implemented
├── arc-mode position                  candidate
├── advanced position quantities       candidate
└── longitude-unrolled position        candidate
~~~

These three capabilities share the same prepared line state and correspond to
one mathematical/API family. They should therefore be researched together
rather than added piecemeal.

Admission requires:

- a concrete consumer or interoperability reason;
- semantics specified before API design;
- no public runtime output-mask requirement unless proven necessary;
- GeographicLib differential validation;
- DMD/LDC and platform-`real` gates;
- repeated-position performance comparison against the current distance-only
  line so that broader capability does not silently degrade the lean hot path.

## Candidate: prolate ellipsoids

GeographicLib/PROJ allow negative flattening and therefore support prolate
ellipsoids. The current `geodesy-d` public geodesic contract is deliberately
bounded to the accepted oblate/spherical domain.

Prolate support is not a v1.1 omission defect. It would broaden the solver
domain and must therefore be treated as new numerical scope.

Before admission:

1. audit all public `Ellipsoid!T` invariants and constructors;
2. identify every geodesic branch that assumes non-negative flattening;
3. establish an independent prolate corpus including difficult inverse cases;
4. compare series order and convergence behavior across `float/double/real`;
5. benchmark any additional branching or specialization;
6. decide whether the wider ellipsoid semantics belong library-wide or only in
   selected operations.

Until then the status is DEFER.

## Cross-library boundary matrix

The broader GeographicLib and PROJ products contain many capabilities that are
useful references but are not automatically `geodesy-d` responsibilities.

| Reference capability | geodesy-d policy |
|---|---|
| CRS database / authority lookup / operation discovery | BOUNDARY -> `proj-d` or future CRS layer |
| WKT / PROJJSON parsing | BOUNDARY |
| Grid-resource management | BOUNDARY |
| MGRS | BOUNDARY -> location-reference layer |
| Geoid/gravity datasets | research/package-boundary decision in M6 |
| Magnetic field models | BOUNDARY unless a separate physical-geodesy package is justified |
| General polygon topology / overlay | BOUNDARY -> `geo-d` |
| Raster / tiles | BOUNDARY -> raster/imagery stack |

## Release conclusion for v1.1

The v1.1 geodesic milestone is feature-complete for its declared scope.

No item marked DEFER, PLANNED, BOUNDARY, or REJECT in this audit is a blocker
for the v1.1 release candidate.

The release-relevant public family is:

~~~text
Geodesic!T
├── direct / inverse
├── GeodesicQuantities!T
│   ├── reducedLength
│   ├── scale12
│   ├── scale21
│   └── signedArea
├── GeodesicLine!T
│   └── repeated distance positions
└── GeodesicPolygonAccumulator!T
    ├── perimeter
    └── canonical signed area
~~~

The next feature work should therefore follow the roadmap rather than filling
reference-library differences mechanically:

1. v1.1 release qualification;
2. M3 `Rhumb/RhumbLine`, Polar Stereographic, and UPS;
3. M5 advanced ellipsoidal geometry when its prerequisite research is mature;
4. advanced `GeodesicLine` and prolate support only if separately admitted.

## Maintenance rule

Update this matrix whenever one of the following occurs:

- a public geodesic/path capability is added or removed;
- GeographicLib/PROJ behavior is used to justify a new admission;
- a DEFER item receives concrete consumer evidence;
- an ownership boundary moves between workspace libraries.

Reference-library feature growth alone is not sufficient reason to expand
`geodesy-d`.
