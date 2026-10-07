# geodesy-d Roadmap

`geodesy-d` is a dependency-light pure-D library for bounded geodetic
mathematics.

This roadmap describes the current post-v1 development line. Historical
pre-v1 planning remains available in git history rather than being carried
forward as active roadmap text.

## Current stable baseline

The released stable line is:

~~~text
v1.2.0
~~~

v1.2.0 completed M3 — Navigation & Polar Geodesy and was published on
2026-10-07. It preserves the frozen v1 source contract. M4 — Reference Frames
is complete on `develop`; the next planned development milestone is M5 —
Advanced Ellipsoidal Geometry.

The frozen v1 API already provides:

- strong angular, geographic, geodetic, geocentric, projected, UTM, and
  topocentric coordinate/value types;
- reference ellipsoids;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032/1033 static Helmert transformations;
- bounded Transverse Mercator;
- UTM policy/projection;
- bounded EPSG method 1024 Pseudo-Mercator;
- conformal projection factors for Transverse Mercator and UTM;
- prepared direct/inverse ellipsoidal geodesics;
- EPSG 9836/9837 topocentric ENU conversions.

The v1 compatibility baseline remains authoritative. Post-v1 work should be
additive unless a separately justified breaking-change process is started.

## v1.2.0 qualification record

The completed v1.2.0 release qualification is recorded in
`docs/V1_2_RELEASE_READINESS.md`.

Immutable stabilization checkpoints:

- `freeze/feature-1.2.0` — v1.2 feature set;
- `freeze/api-1.2.0` — audited caller-visible v1.2 API contract.

## Development principles

Post-v1 work follows these rules:

1. stabilize the released baseline before adding breadth;
2. complete existing mathematical families before adding unrelated new ones;
3. admit new public capability only with consumer, interoperability, numerical,
   or research evidence;
4. keep `geodesy-d` focused on mathematical geodesy rather than CRS databases,
   file formats, or application policy;
5. preserve independent numerical validation and multi-compiler/platform
   evidence;
6. require profiling before performance changes;
7. prefer small prepared mathematical kernels over monolithic convenience APIs.

No milestone number implies a promised release date.

Milestones express the preferred development sequence, not a hard dependency
graph. Evidence from real consumers may justify advancing an item from a later
milestone without admitting the entire milestone.

A capability is not admitted merely because GeographicLib, PROJ, or another
reference implementation exposes it. New public abstractions should either
complete an existing mathematical family or have concrete consumer,
interoperability, numerical, or research justification.

---

# M1 — Post-v1 Baseline

**Goal:** finish v1 stabilization before new public capability families are
merged.

Tracking issue:

- #45 — post-v1 baseline, documentation, toolchain, and consumer audits.

Existing work included in this milestone:

- #32 — v1.0.1 release preparation and documentation sign-off;
- #17 — controlled DMD/LDC compiler/toolchain matrix;
- #18 — Phobos 2.111 two-argument `hypot` correctness audit.

Exit criteria:

- v1.0.1 released and verified from a fresh external DUB consumer;
- release-facing README/API/ROADMAP documentation is internally coherent;
- minimum-compiler correctness questions are resolved;
- controlled compiler policy is accepted;
- no known open v1 correctness defect remains;
- a clean numerical/performance baseline exists before feature work begins.

M1 is intentionally feature-conservative.

## M1.1 — v1.0.1 Hotfix

The v1.0.1 patch is a narrow correctness/documentation release over the frozen
v1 API.

Included:

- Transverse Mercator reverse-boundary unit invariance;
- Phobos/DMD 2.111 two-argument `hypot` correctness workaround in the
  geodesic core;
- corrected public `out`-parameter failure semantics;
- v1.0.1 documentation-quality hardening and strict DDox gates.

It introduces no new public capability family.

---

# M2 — Geodesic Core Completion

**Status:** completed and released in **v1.1.0**.

The first post-v1 feature milestone completes the existing Karney-family
geodesic core instead of starting unrelated new families. "Core completion"
means the admitted direct/inverse, differential-quantity, prepared-line, and
ellipsoidal measurement primitives; it does not imply that every possible
ellipsoidal path operation is complete.

Issues:

- #33 — expose reduced length `m12`, geodesic scales `M12`/`M21`, and
  geodesic area contribution `S12`;
- #34 — add prepared `GeodesicLine!T` for efficient repeated positions;
- #35 — add ellipsoidal polygon perimeter/signed-area accumulator;
- #36 — define the complete-family API and validation gate for v1.1.

Expected family:

~~~text
Geodesic
├── direct / inverse
├── reduced length m12
├── geodesic scales M12 / M21
├── area contribution S12
├── GeodesicLine
└── perimeter / signed-area accumulation
~~~

The area accumulator is mathematical measurement only. Polygon topology,
ring validity, holes, containment, overlay, and geometry ownership remain in
`geo-d` or higher-level consumers.

M2 explicitly does **not** include geodesic intersections, nearest-point
queries, rhumb lines, or prolate ellipsoids.

The post-M2 reference-library comparison and admission decisions are recorded in
`docs/GEODESIC_FEATURE_MATRIX.md`. Reference parity is not a release goal:
differences are classified as retained, deferred, planned, rejected convenience,
or workspace-boundary responsibilities.

---

# M3 — Navigation & Polar Geodesy

**Status:** completed.

**Goal:** complete the principal navigation/polar families after the geodesic
core is mature, unless concrete consumer evidence justifies advancing an
individual item earlier.

Tracking issue:

- #74 — M3 Navigation & Polar Geodesy integration gate.

Preferred order:

1. #38 — establish and accept the bounded Polar Stereographic kernel;
2. #39 — add UPS as a semantic/policy layer over that accepted kernel;
3. #37 — research and admit the independent Rhumb/RhumbLine family;
4. #40 — complete the consumer-driven admission audit for further projections.

Rhumb research may proceed independently of the Polar Stereographic/UPS chain,
but UPS must not duplicate or precede the accepted Polar Stereographic
mathematics.

Issues:

- #37 — ellipsoidal `Rhumb!T` / `RhumbLine!T`;
- #38 — bounded Polar Stereographic projection;
- #39 — UPS policy and coordinate family over Polar Stereographic;
- #40 — consumer-driven audit of additional projection families.

Target structure:

~~~text
navigation / projection
├── Rhumb / RhumbLine
├── Polar Stereographic
└── UPS
~~~

Polar Stereographic, UPS, and Rhumb/RhumbLine form the intended M3 core.

The M3 core issues #37/#38/#39/#40 are complete. The two projection families
admitted by #40, #83 LCC 2SP and #84 LAEA, are also complete.

The aggregate six-compiler release/consumer gate and controlled local
performance baseline are complete. Final evidence is recorded in
`docs/M3_INTEGRATION_GATE.md` and tracking issue #74.

Additional projections are research/admission candidates rather than automatic
scope. The #40 admission audit is recorded in
`docs/ADDITIONAL_PROJECTION_ADMISSION_AUDIT.md`.

Audit outcome:

- #83 — Lambert Conformal Conic 2SP: admitted from concrete Austria and
  pan-European interoperability evidence;
- #84 — Lambert Azimuthal Equal Area: admitted from EPSG:3035 pan-European
  equal-area/statistical interoperability;
- Albers Equal Area: deferred pending a concrete conic equal-area consumer;
- Azimuthal Equidistant: deferred pending a projection-plane consumer;
- generic/Oblique Stereographic: deferred despite national-CRS relevance,
  pending a concrete consumer;
- Oblique Mercator: deferred pending a corridor/oblique-region consumer.

Admission remains evidence-driven. A reference library exposing a projection
is not sufficient reason to implement it.

---

# M4 — Reference Frames

**Status:** completed.

**Goal:** extend the current static datum/reference-frame mathematics to modern
time-dependent transformations.

M4 is complete on `develop`. Dynamic Helmert is implemented as the primary
capability. Direct Molodensky was researched and deferred because the existing
geodetic -> geocentric -> translation/Helmert -> geodetic composition already
covers the stronger path and no concrete consumer requires EPSG 9604/9605
method reproduction. Molodensky-Badekas was admitted and implemented as a
local-origin Helmert-family transformation that reuses the existing
`Helmert7` spatial kernel.

Preferred order:

1. #41 — freeze epoch and temporal-parameter semantics;
2. #42 — implement the dynamic 14-parameter Helmert family on that contract;
3. #43 / #44 — research admission only after the dynamic Helmert core is stable.

Issues:

- #41 — epoch and temporal-parameter semantics;
- #42 — dynamic 14-parameter Helmert transformation;
- #43 — research/admit Molodensky transformation;
- #44 — research/admit Molodensky-Badekas transformation.

The accepted temporal design is recorded in `docs/M4_EPOCH_SEMANTICS.md`.
It keeps observation epochs explicit at operation boundaries and does not add
temporal metadata to the existing coordinate value types.

The final M4 decisions and qualification evidence are recorded in
`docs/M4_INTEGRATION_GATE.md`.

Closure outcome:

- #41 — completed: strong epoch and temporal-parameter semantics;
- #42 — completed: dynamic 14-parameter Helmert, EPSG 1053/1056;
- #43 — deferred/not planned: direct Molodensky pending a concrete need;
- #44 — completed: Molodensky-Badekas, EPSG 1034/1061, implemented through
  prepared reuse of the existing static Helmert kernel.

Primary target:

~~~text
Dynamic Helmert
├── X / Y / Z
├── Rx / Ry / Rz
├── scale
├── dX/dt / dY/dt / dZ/dt
├── dRx/dt / dRy/dt / dRz/dt
├── dScale/dt
└── reference epoch
~~~

The existing compile-time-explicit Helmert convention remains a core design
constraint.

This milestone owns mathematical reference-frame transformations. It does not
own CRS databases, operation discovery, plate-motion grids, or general
transformation pipelines.

---

# M5 — Advanced Ellipsoidal Geometry

**Status:** active.

**Goal:** add higher-order geodetic geometry only after the line/differential
geodesic primitives from M2 are stable.

Preferred order:

1. #68 — complete the prepared `GeodesicLine` capabilities needed by higher-
   order line geometry: arc-mode positions, longitude unrolling, and advanced
   position quantities without regressing the lean distance-only hot path;
2. #47 — nearest point, cross-track, and along-track quantities, establishing
   M5 ambiguity/result semantics on infinite lines and bounded segments;
3. #46 — robust geodesic intersection, using the prepared-line and result-
   semantics groundwork from #68/#47;
4. #48 — admit geodesic circles/loci only if #46/#47 or a concrete consumer
   demonstrates value beyond repeated `Geodesic.direct` calls.

#69 — prolate ellipsoid support is a separate numerical-domain admission track.
It may be researched in parallel but does not block the oblate/spherical M5
geometry sequence because admitting negative flattening would broaden the
library-wide `Ellipsoid!T` contract.

Issues:

- #46 — robust geodesic intersection;
- #47 — nearest point, cross-track, and along-track quantities;
- #48 — evaluate geodesic circles and related locus operations;
- #68 — evaluate advanced `GeodesicLine` capabilities (arc mode, longitude
  unrolling, advanced line quantities);
- #69 — research admission of prolate ellipsoid support.

These are ellipsoidal mathematical operations.

They do not transfer general topology responsibility from `geo-d` to
`geodesy-d`.

Research must explicitly address ambiguity and multiplicity on a closed
ellipsoid, especially for antipodal, nearly parallel, or coincident
configurations.

---

# M6 — Physical Geodesy Research

**Goal:** decide how far `geodesy-d` should extend from geometrical geodesy
into physical geodesy. This milestone is research-first; it may conclude that
some data-driven capabilities belong in a separate package rather than in
`geodesy-d`.

Issues:

- #49 — reference-ellipsoid normal gravity;
- #50 — gravity/geoid model interface and package-boundary research.

The smallest self-contained candidate is normal gravity tied to a reference
ellipsoid.

Large external models such as global/regional gravity or geoid datasets should
not be embedded into the core package merely for convenience. M6 must determine
the boundary between:

~~~text
geodesy-d mathematical kernels
external model interpolation
dataset/model distribution
~~~

A separate future package may be the correct owner for model data and
interpolation.

---

# Long-term library shape

The intended conceptual family is:

~~~text
geodesy
├── coordinates
│   ├── angular
│   ├── geographic / geodetic
│   ├── geocentric
│   ├── projected
│   └── topocentric
│
├── ellipsoid
│
├── geodesic
│   ├── direct / inverse
│   ├── differential quantities
│   ├── GeodesicLine
│   ├── perimeter / area accumulation
│   └── advanced ellipsoidal geometry
│
├── navigation
│   └── rhumb / RhumbLine
│
├── projection
│   ├── Transverse Mercator
│   ├── UTM
│   ├── Pseudo-Mercator
│   ├── Polar Stereographic
│   ├── UPS
│   └── selected consumer-justified projections
│
├── transform
│   ├── geocentric translation
│   ├── static Helmert
│   ├── dynamic Helmert
│   ├── Molodensky-Badekas
│   └── direct Molodensky, deferred unless future evidence admits it
│
└── physical
    ├── normal gravity, if admitted
    └── model interfaces or separate package boundary
~~~

This is an architectural target, not a commitment that every candidate will be
implemented.

---

# Responsibility boundary

`geodesy-d` owns mathematical operations whose semantics depend on the Earth,
a reference ellipsoid, geodetic/geographic/geocentric/topocentric coordinates,
reference frames, map-projection mathematics, or ellipsoidal paths.

It deliberately does not own:

~~~text
general Euclidean geometry / polygon topology     -> geo-d
CRS database / authority lookup / WKT / PROJJSON -> proj-d or future CRS layer
MGRS / Geohash / Open Location Code              -> location-reference layer
grid/model dataset distribution                  -> separate data/model package
raster/image/tile infrastructure                  -> raster/imagery stack
OpenStreetMap data models and file formats        -> osm-d
~~~

The goal is not to reproduce PROJ or GeographicLib feature-for-feature.
The goal is a coherent, well-validated D geodetic mathematics library with
clear ownership boundaries and performance appropriate for production use.
