# geodesy-d v1.2.0 release notes

`geodesy-d` v1.2.0 completes M3 — Navigation & Polar Geodesy while
preserving the frozen v1 source contract.

## Added

### Rhumb / RhumbLine

`Rhumb!T` and `RhumbLine!T` add ellipsoidal loxodromic navigation as a
distinct family from geodesics.

The public surface provides:

- inverse rhumb distance and constant bearing;
- direct endpoint from start, bearing, and signed distance;
- prepared repeated positions through `RhumbLine!T`;
- explicit pole, antimeridian, shortest-wrap, and canonical-longitude
  semantics.

The admitted implementation supports spheres and oblate ellipsoids with
`0 <= f <= 0.01`.

### Polar Stereographic

`PolarStereographic!T` provides a bounded prepared ellipsoidal Polar
Stereographic kernel.

The implementation supports:

- north and south aspects;
- EPSG 9810 variant-A semantics;
- EPSG 9829 variant-B construction through the equivalent natural-origin
  scale;
- forward/reverse projection;
- conformal meridian convergence and point scale.

### UPS

UPS is implemented as a thin WGS 84 policy layer over
`PolarStereographic!T`, analogous to UTM over Transverse Mercator.

The public family includes:

- `UpsHemisphere`;
- `UpsCoordinate!T`;
- `UpsProjection!T`;
- standard automatic UPS selection;
- prepared and one-shot checked/throwing forward/reverse operations.

The automatic UTM/UPS transition and explicit overlap policy are documented
and validated against independent reference implementations.

### Lambert Conformal Conic 2SP

`LambertConformalConic!T` adds a bounded ellipsoidal EPSG 9802 two-standard-
parallel family.

Independent qualification includes the authority-backed parameter sets for:

- EPSG:31287 — MGI / Austria Lambert;
- EPSG:3034 — ETRS89-extended / LCC Europe.

The public family includes forward/reverse projection and conformal factors.

### Lambert Azimuthal Equal Area

`LambertAzimuthalEqualArea!T` adds a bounded ellipsoidal equal-area family
with oblique, equatorial, north-polar, and south-polar projection centres.

Independent qualification includes EPSG:3035 — ETRS89-extended / LAEA Europe.

The exact authalic antipode is treated as a directional singularity and the
reverse operation uses an explicit open represented-disk policy.

## Validation

The M3 additions were qualified with:

- independent GeographicLib validation for Rhumb/RhumbLine;
- independent PROJ and GeographicLib validation for Polar Stereographic;
- independent PROJ and GeographicLib UTMUPS validation for UPS;
- independent PROJ validation for LCC 2SP and LAEA;
- explicit EPSG:31287, EPSG:3034, and EPSG:3035 parameter coverage;
- float/double/real scalar validation;
- controlled DMD 2.111.0 / 2.112.1 / 2.113.0;
- controlled LDC 1.41.0 / 1.42.0 / 1.43.0;
- Linux, Windows, and macOS x86_64/AArch64 platform qualification where
  supported;
- strict API/DDox validation;
- fresh external DUB consumer gates.

## Performance

The controlled M3 baseline was recorded on the development XPS with CPU
affinity pinned, governor `performance`, Intel turbo disabled, LDC 1.41.0,
PROJ 9.7.1, GeographicLib 2.7, and 1,000,000 iterations per family.

Headline results:

~~~text
Rhumb inverse
  geodesy-d       493.380 ns/op
  GeographicLib   787.373 ns/op

RhumbLine position
  geodesy-d       555.932 ns/op
  GeographicLib   910.429 ns/op

Polar Stereographic forward
  geodesy-d       247.239 ns/op
  GeographicLib   276.990 ns/op

Polar Stereographic reverse
  geodesy-d       486.406 ns/op
  GeographicLib   521.538 ns/op

LCC 2SP forward
  geodesy-d       269.521 ns/op
  PROJ             186.192 ns/op

LAEA forward
  geodesy-d       163.193 ns/op
  PROJ             180.018 ns/op
~~~

LCC 2SP remains the only material performance gap and is retained as a future
optimization target rather than a correctness or release blocker.

## Compatibility

v1.2.0 is additive over the frozen v1 line.

There are no intended breaking changes to existing public names, signatures,
argument order, parameter names, scalar policy, unit policy, checked/throwing
failure channels, or existing operation domains.

## Deliberately deferred

v1.2.0 does not include:

- dynamic 14-parameter Helmert transformations;
- Molodensky / Molodensky-Badekas;
- arc-mode and longitude-unrolled GeodesicLine extensions;
- prolate ellipsoid support;
- geodesic intersections;
- nearest/cross-track/along-track operations;
- Albers Equal Area;
- Azimuthal Equidistant;
- generic/Oblique Stereographic;
- Oblique Mercator;
- CRS authority databases, WKT/PROJJSON, transformation discovery, or MGRS.

See `ROADMAP.md`, `docs/M3_INTEGRATION_GATE.md`, and
`docs/ADDITIONAL_PROJECTION_ADMISSION_AUDIT.md` for the detailed admission
record.
