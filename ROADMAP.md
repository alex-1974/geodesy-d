# geodesy-d Roadmap

`geodesy-d` is a dependency-light pure-D library for bounded geodetic
mathematics.

This roadmap describes the current post-v1 development line. Historical
pre-v1 planning remains available in git history rather than being carried
forward as active roadmap text.

## Current stable baseline

The released stable line is:

~~~text
v1.0.0
~~~

A narrow v1.0.1 correctness/documentation patch is in release preparation.

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

---

# M2 — Complete Geodesic Family

**Release intent:** primary **v1.1 candidate**.

The first post-v1 feature milestone completes the existing Karney-family
geodesic core instead of starting unrelated new families.

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

---

# M3 — Navigation & Polar Geodesy

**Goal:** complete the principal navigation/polar families after the geodesic
core is mature.

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

Additional projections are research/admission candidates rather than automatic
scope. Candidate families include:

- Lambert Conformal Conic;
- Albers Equal Area;
- Lambert Azimuthal Equal Area;
- Azimuthal Equidistant;
- Stereographic;
- Oblique Mercator.

A projection is admitted only when a real consumer, workspace need,
interoperability gap, or strong research case exists.

---

# M4 — Reference Frames

**Goal:** extend the current static datum/reference-frame mathematics to modern
time-dependent transformations.

Issues:

- #41 — epoch and temporal-parameter semantics;
- #42 — dynamic 14-parameter Helmert transformation;
- #43 — research/admit Molodensky transformation;
- #44 — research/admit Molodensky-Badekas transformation.

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

**Goal:** add higher-order geodetic geometry only after the line/differential
geodesic primitives from M2 are stable.

Issues:

- #46 — robust geodesic intersection;
- #47 — nearest point, cross-track, and along-track quantities;
- #48 — evaluate geodesic circles and related locus operations.

These are ellipsoidal mathematical operations.

They do not transfer general topology responsibility from `geo-d` to
`geodesy-d`.

Research must explicitly address ambiguity and multiplicity on a closed
ellipsoid, especially for antipodal, nearly parallel, or coincident
configurations.

---

# M6 — Physical Geodesy

**Goal:** decide how far `geodesy-d` should extend from geometrical geodesy
into physical geodesy.

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
│   ├── rhumb
│   └── advanced ellipsoidal geometry
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
│   ├── Molodensky
│   └── Molodensky-Badekas
│
└── physical
    ├── normal gravity
    └── model interfaces if admitted
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
