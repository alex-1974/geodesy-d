# geodesy-d public API

This document defines the stable public **v1 API baseline** for `geodesy-d`.

The baseline was frozen for v1.0.0 and remains authoritative across compatible
v1.x releases. Patch releases may correct implementation or documentation
defects without changing this public source contract.

Historical pre-v1 API evolution remains available in git history and release
records rather than being treated as the current contract.

## Aggregate import

```d
import geodesy;
```

`source/geodesy/package.d` is the intentional public aggregation surface.
The frozen v1 API contract is compiled through this aggregate import. New
public modules or symbols may be added in compatible v1.x releases only after
their implementation, API, documentation, and validation gates have passed.

## Public scalar policy

```d
isGeodesyScalar!T
```

Supported scalars are `float`, `double`, and `real`. `double` is the normative
reference precision. The finite-value helper remains package-internal.

## Public value types

```text
Angle<T>
Latitude<T>
Longitude<T>
Ellipsoid<T>
GeographicCoordinate<T>
GeodeticCoordinate<T>
GeocentricCoordinate<T>
TopocentricCoordinate<T>
TopocentricFrame<T>
GeocentricTranslation<T>
Helmert7<T, convention>
PositionVectorHelmert<T>
CoordinateFrameHelmert<T>
```

`HelmertConvention` is public and has no default.

`GeocentricTranslation` exposes `deltaX/Y/Z` as read-only properties so a
validated value cannot later be mutated into a NaN/Infinity state.

## Coordinate semantics

`GeographicCoordinate<T>` represents a two-dimensional geographic position
with latitude and longitude and carries no height semantics.

`GeodeticCoordinate<T>` represents latitude, longitude, and ellipsoidal height.
Its linear unit is caller-selected and must be consistent with the associated
ellipsoid where an operation combines them.

The throwing
`GeodeticCoordinate<T>.fromComponents(latitude, longitude, ellipsoidalHeight)`
factory retains a v1 convenience default of zero for `ellipsoidalHeight`.
Omitting that argument denotes an actual ellipsoidal height of zero; it does
not denote unknown or absent height. Use `GeographicCoordinate<T>` when the
position has no height semantics.

## Construction pattern

Checked factories use `tryFrom...` and are intended for
`pure nothrow @safe @nogc` code. Throwing convenience factories are `@safe`
and use `GeodesyValueException` for invalid input.

Unchecked construction helpers are implementation-only.

## EPSG 9602

```text
tryGeodeticToGeocentric
geodeticToGeocentric
tryGeocentricToGeodetic
geocentricToGeodetic
```

### EPSG 9602 reverse precision policy

The public scalar type of the reverse geographic/geocentric conversion is
preserved.

Internally, working precision is selected as follows:

~~~text
float  -> double working precision -> float result
double -> double working precision -> double result
real   -> real working precision   -> real result
~~~

The promotion of public `float` input to `double` working precision is
intentional. Direct single-precision evaluation was found insufficient for
numerically sensitive Earth-scale interior and evolute cases.

The reverse implementation uses:

- a Fukushima/Halley fast path for ordinary oblate positions;
- an extended Vermeille/Karney robust fallback for difficult positions;
- dedicated analytic handling for selected degenerate cases.

For multiply representable deep-interior Cartesian points, the inverse selects
the nearest-ellipsoid, minimum-absolute-height solution.

The exact ellipsoid centre remains undefined and is rejected by the checked
API.

For the validated terrestrial domain:

~~~text
ellipsoids:
    WGS 84
    GRS 80
    Airy 1830

latitude:
    full legal range [-90 deg, +90 deg]

ellipsoidal height:
    -20 km through +100 km
~~~

the conservative public numerical contract is:

~~~text
float:
    represented Cartesian position <= 2 m
    ellipsoidal height             <= 0.1 m

double and real:
    represented Cartesian position <= 1 mm
~~~

Represented Cartesian position means the ECEF coordinate obtained by applying
the forward conversion to the returned geodetic coordinate on the same
ellipsoid.

These limits describe numerical coordinate-conversion error only. They do not
describe datum, reference-frame, observation, survey, GNSS, or physical
position accuracy.

Outside the validated terrestrial domain, the documented robust and canonical
inverse semantics still apply, but the same absolute accuracy envelope is not
claimed.

See ADR-0005 and `docs/operations/geographic-geocentric.md` for algorithmic and
validation details.


## EPSG 9836 / 9837 topocentric ENU — frozen v1 surface

The frozen v1 surface exports:

~~~text
TopocentricCoordinate<T>
TopocentricFrame<T>
~~~

for `T = float | double | real`.

`TopocentricCoordinate<T>` stores read-only:

~~~text
east
north
up
~~~

and `.init` is the valid local zero coordinate.

`TopocentricFrame<T>.init` is intentionally invalid. A frame is prepared from
either a geodetic or geocentric origin:

~~~text
tryFromGeodeticOrigin / fromGeodeticOrigin
tryFromGeocentricOrigin / fromGeocentricOrigin
~~~

The explicit conversion surface is:

~~~text
tryGeocentricToTopocentric / geocentricToTopocentric
tryTopocentricToGeocentric / topocentricToGeocentric

tryGeodeticToTopocentric / geodeticToTopocentric
tryTopocentricToGeodetic / topocentricToGeodetic
~~~

Generic `forward`, `reverse`, `transform`, and `inverse` names are deliberately
not part of the topocentric public surface.

Checked operations are `pure nothrow @safe @nogc`; throwing convenience
operations are `@safe` and report invalid caller input through
`GeodesyValueException`.

Working precision is:

~~~text
float  -> double
double -> double
real   -> real
~~~

The geographic/topocentric `float` path retains promoted ECEF working
precision across the internal EPSG 9602/9836 composition rather than
materializing an Earth-scale public `GeocentricCoordinate<float>` intermediate.

Pole orientation, geocentric rotation-axis behavior, geocentre rejection,
deep-interior canonical semantics, and scalar/platform behavior are fixed by
ADR-0009 and the accepted validation program.

See ADR-0009 and `docs/TOPOCENTRIC_VALIDATION_PLAN.md`.

## EPSG 1031

```text
GeocentricTranslation
tryApplyGeocentricTranslation
applyGeocentricTranslation
```

`.init` is identity. `inverse()` is exact and negates all translations.

## EPSG 1032 / 1033

```text
HelmertConvention
Helmert7
PositionVectorHelmert
CoordinateFrameHelmert
tryApplyPositionVectorHelmert
applyPositionVectorHelmert
tryApplyCoordinateFrameHelmert
applyCoordinateFrameHelmert
toCoordinateFrame
toPositionVector
```

Canonical rotations are `Angle<T>` in radians. Scale difference is a
dimensionless fraction. The EPSG-style factory accepts arc-seconds and ppm.

`toCoordinateFrame` and `toPositionVector` are
`pure nothrow @safe @nogc`. No 7-parameter `inverse()` shortcut is part of the frozen v1 surface.

## Conformal projection factors — frozen v1 surface

The aggregate public API exports:

~~~text
ConformalProjectionFactors<T>
~~~

A successfully computed value exposes:

~~~text
meridianConvergence : Angle<T>
pointScale          : T
~~~

`meridianConvergence` is the bearing of grid north measured clockwise from true
north. Positive values therefore represent a clockwise rotation from true north
to grid north.

`pointScale` is the dimensionless isotropic local scale of the conformal
projection and is strictly positive for a successfully computed result.

`ConformalProjectionFactors<T>.init` has `pointScale == 0` and is intentionally
not a successfully computed result. Arbitrary public construction is not
provided.

See ADR-0011 for reverse representation policy, the exact-pole convention, and
the rationale for using a conformal-specific result type.

## Transverse Mercator — frozen v1 surface

The frozen v1 surface exports the accepted bounded generic Transverse
Mercator operation:

~~~text
TransverseMercator<T>
~~~

Construction uses `tryFromParameters` / `fromParameters`, and prepared
operations expose checked/throwing `tryForward` / `forward` and
`tryReverse` / `reverse` pairs.

Prepared projections additionally expose:

~~~text
tryForwardFactors / forwardFactors
tryReverseFactors / reverseFactors
~~~

The factor operations use the same bounded domain and representation-aware
reverse policy as the corresponding coordinate operations.

`TransverseMercator<T>.init` is intentionally invalid.

See ADR-0006 and `docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md` for the accepted
domain, numerical, scalar, and platform contract.

## Pseudo-Mercator — frozen v1 surface

The aggregate public API exports the accepted bounded EPSG method 1024 operation:

~~~text
PseudoMercator<T>
~~~

for `T = float | double | real`.

Construction uses:

~~~text
tryFromParameters / fromParameters
~~~

with the parameters:

~~~text
Ellipsoid<T>
Longitude<T> longitudeOfNaturalOrigin
T falseEasting
T falseNorthing
~~~

A prepared operation exposes read-only `ellipsoid`,
`longitudeOfNaturalOrigin`, `falseEasting`, and `falseNorthing`
properties together with:

~~~text
tryForward / forward
tryReverse / reverse
~~~

`PseudoMercator<T>.init` is intentionally invalid. Checked construction and
projection operations are `pure nothrow @safe @nogc`; throwing convenience
operations report invalid parameters, failed operations, or points outside the
supported domain through `GeodesyValueException`.

The forward latitude domain is the closed interval [-88 deg,+88 deg].
Longitude uses the principal wrapped sheet [-pi,+pi) with the accepted
representation-aware east-endpoint policy. Reverse northing limits are derived
from the represented forward values at the two latitude boundaries.

The complete source `Ellipsoid<T>` is retained as semantic state, while EPSG
method 1024 coordinate equations depend only on its semi-major axis. Flattening
therefore does not affect projected coordinates.

The frozen v1 public surface deliberately does not provide a `WebMercator`
alias, latitude-of-natural-origin or scale-factor parameters, conformal
projection factors, one-shot free forward/reverse helpers, CRS/EPSG lookup, or
web-map tile/zoom/XYZ/TMS policy.

The PM-A through PM-G5 research and acceptance evidence is retained under
`../geodesy-d-research/research/pseudo-mercator/`.

## UTM — frozen v1 surface

The UTM layer exports:

~~~text
UtmZone
UtmHemisphere
UtmCoordinate<T>
UtmProjection<T>

tryStandardUtmZone
tryForwardUtm / forwardUtm
tryReverseUtm / reverseUtm
~~~

`UtmZone.init` is intentionally invalid.

`UtmProjection<T>.init` and `UtmCoordinate<T>.init` are structurally invalid
because they contain an invalid default zone.

`UtmHemisphere.init` is intentionally `UtmHemisphere.north`. The enum's first
member is therefore part of the public default-state contract and must not be
reordered casually.

Prepared `UtmProjection<T>` values additionally expose:

~~~text
tryForwardFactors / forwardFactors
tryReverseFactors / reverseFactors
~~~

These operations delegate factor mathematics and reverse boundary/pole semantics
to the prepared underlying `TransverseMercator<T>`. No separate UTM factor
formula is defined.

See ADR-0007, ADR-0011, and `docs/UTM_VALIDATION_PLAN.md` for the accepted policy,
parameterization, boundary, and platform contract.

## Ellipsoidal geodesics — frozen v1 surface

The frozen v1 surface exports the geodesic API through the aggregate:

```d
import geodesy;
```

Public types:

```text
Geodesic<T>
GeodesicDirectResult<T>
GeodesicInverseResult<T>
```

Prepared solver construction follows the checked/throwing factory pattern:

```d
static bool Geodesic!T.tryFromEllipsoid(
    const Ellipsoid!T ellipsoid,
    out Geodesic!T result)
    pure nothrow @safe @nogc;

static Geodesic!T Geodesic!T.fromEllipsoid(
    const Ellipsoid!T ellipsoid)
    @safe;
```

The operational surface follows the library's checked/throwing operation pattern:

```d
bool tryDirect(
    const GeographicCoordinate!T start,
    const Angle!T initialAzimuth,
    const T distance,
    out GeodesicDirectResult!T result) const
    pure nothrow @safe @nogc;

bool tryInverse(
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    out GeodesicInverseResult!T result) const
    pure nothrow @safe @nogc;

GeodesicDirectResult!T direct(
    const GeographicCoordinate!T start,
    const Angle!T initialAzimuth,
    const T distance) const
    @safe;

GeodesicInverseResult!T inverse(
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end) const
    @safe;
```

`GeodesicDirectResult!T` contains the endpoint position and the forward azimuth
of the same oriented geodesic at that endpoint.

`GeodesicInverseResult!T` contains:

```text
distance
initialAzimuth
finalAzimuth
```

where `finalAzimuth` is the forward direction of the selected oriented
geodesic continuing beyond the endpoint, not the back azimuth.

Initial support profile:

```text
a > 0
0 <= f <= 0.01
T = float | double | real
```

Linear results use the same unit as the ellipsoid semi-major axis.

Public longitude and azimuth results are canonicalized to `[-pi,+pi)`.
Coincident inverse surface points return exactly:

```text
distance       = +0
initialAzimuth = +0
finalAzimuth   = +0
```

Public `float` geodesics use double working precision. `double` uses order-6
Karney series. Platform `real` selects order 6, 7, or 8 according to its
mantissa width; on the validated Linux x86-64 environment
`real.mant_dig == 64`, so order 7 is used.

The frozen v1 geodesic surface does not expose `GeodesicLine`, reduced
length, geodesic scales, area, longitude unrolling, polygon accumulation, or
prolate ellipsoids.

### Additive v1.1 geodesic quantities

The v1.1 candidate adds advanced quantities without changing the frozen v1
result types or ordinary direct/inverse signatures.

The shared quantity value type is:

```d
GeodesicQuantities!T
```

with:

```text
reducedLength  m12   same linear unit as ellipsoid a
scale12        M12   dimensionless
scale21        M21   dimensionless
signedArea     S12   square of the ellipsoid linear unit
```

The first additive operation is the checked inverse overload:

```d
bool tryInverse(
    const GeographicCoordinate!T start,
    const GeographicCoordinate!T end,
    out GeodesicInverseResult!T result,
    out GeodesicQuantities!T quantities) const
    pure nothrow @safe @nogc;
```

The existing v1 overload remains unchanged and does not compute advanced
quantities.

`S12` is an oriented area contribution and changes sign when the segment
orientation is reversed. `M12` and `M21` describe opposite geodesic-scale
directions. Coincident endpoints use the canonical advanced values:

```text
m12 = 0
M12 = 1
M21 = 1
S12 = 0
```

The public API deliberately does not expose a GeographicLib-style runtime
output mask. Quantity selection remains an internal compile-time
specialization concern.

The matching checked direct overload is:

```d
bool tryDirect(
    const GeographicCoordinate!T start,
    const Angle!T initialAzimuth,
    const T distance,
    out GeodesicDirectResult!T result,
    out GeodesicQuantities!T quantities) const
    pure nothrow @safe @nogc;
```

Direct quantities follow the orientation of the signed-distance segment.
Negative distance therefore evaluates the same prepared oriented line in the
opposite signed direction. Zero distance preserves the supplied direct-line
azimuth and returns canonical advanced values:

```text
m12 = 0
M12 = 1
M21 = 1
S12 = 0
```

Compatible post-v1 additions do not alter the v1.0 direct/inverse contract.

### Complete v1.1 geodesic family

The v1.1 candidate completes the admitted geodesic family with two prepared
measurement abstractions in addition to the advanced direct/inverse quantities:

~~~text
GeodesicQuantities<T>
GeodesicLine<T>
GeodesicPolygonAccumulator<T>
GeodesicPolygonResult<T>
~~~

All four are deliberately exported by the aggregate `import geodesy;`.
They are additive to the frozen v1 direct/inverse surface.

The naming pattern remains consistent with the rest of the library:

~~~text
checked construction / operation    tryFrom... / try...
throwing convenience                from... / operation
~~~

For the prepared line this gives:

~~~text
GeodesicLine.tryFromGeodesic / fromGeodesic
GeodesicLine.tryPosition     / position
~~~

For polygon measurement this gives:

~~~text
GeodesicPolygonAccumulator.tryFromGeodesic / fromGeodesic
GeodesicPolygonAccumulator.tryAddPoint      / addPoint
GeodesicPolygonAccumulator.tryCompute       / compute
~~~

Checked line and polygon operations are `pure nothrow @safe @nogc`.
Throwing convenience operations are `@safe` and report invalid input or
failed numerical operations with `GeodesyValueException`.

`GeodesicLine<T>.init` and `GeodesicPolygonAccumulator<T>.init` are
intentionally invalid prepared states. `GeodesicPolygonResult<T>.init` is
the canonical empty result with zero point count, perimeter, and signed area.

Line position results retain the v1 longitude and azimuth canonicalization
rules. Polygon area is positive for counterclockwise traversal and is
canonicalized to `(-A/2, A/2]`, where `A` is the full ellipsoid area.
Polygon measurement stores only the first and current vertex plus compensated
sums; ring validity, holes, containment, overlay, topology, and geometry
ownership remain outside `geodesy-d`.

#### Consumer example — repeated positions on one geodesic

Prepare the line once when many distances share the same solver, start point,
and initial azimuth:

~~~d
import geodesy;

auto ellipsoid =
    Ellipsoid!double.fromInverseFlattening(
        6_378_137.0,
        298.257223563);

auto solver =
    Geodesic!double.fromEllipsoid(
        ellipsoid);

auto start =
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0));

auto line =
    GeodesicLine!double.fromGeodesic(
        solver,
        start,
        Angle!double.fromDegrees(60.0));

foreach (distance; [10_000.0, 25_000.0, 50_000.0])
{
    auto position = line.position(distance);
    // use position.position / position.finalAzimuth
}
~~~

The prepared line caches line-dependent auxiliary-sphere and series state.
Repeated positions therefore avoid rebuilding that state for every distance.

#### Consumer example — ellipsoidal polygon measurement

The accumulator measures an ordered closed geodesic polygon without becoming a
general polygon-geometry type:

~~~d
import geodesy;

auto solver =
    Geodesic!double.fromEllipsoid(
        Ellipsoid!double.fromInverseFlattening(
            6_378_137.0,
            298.257223563));

auto polygon =
    GeodesicPolygonAccumulator!double.fromGeodesic(
        solver);

polygon.addPoint(
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0)));

polygon.addPoint(
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(17.0)));

polygon.addPoint(
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(49.0),
        Longitude!double.fromDegrees(16.0)));

auto measurement = polygon.compute();

// measurement.perimeter  -> solver linear unit
// measurement.signedArea -> square solver unit, CCW positive
~~~

The closing edge is included by `compute()`; callers do not repeat the first
vertex merely to close the measurement.

See ADR-0008 and `docs/GEODESIC_VALIDATION_PLAN.md` for the accepted
numerical, canonicalization, and validation contract.

## Public API contract

Run:

```bash
tools/validate-api.sh
```

The frozen v1 contract verifies externally that aggregate `import geodesy;`
exposes its intended baseline surface, checked APIs retain their hot-path
attributes, mutable parameter leakage is rejected, package/private helpers
remain inaccessible, and Helmert convention selection cannot be omitted.

The permanent aggregate contract also compiles a named-argument compatibility
surface under DMD and LDC. Public parameter names are therefore treated as
source compatibility within the stable v1 API line.

The current geodesic aggregate surface is part of the permanent public API
contract and is compile-checked under DMD and LDC using only `import geodesy;`.
GEO-F additionally validates the checked geodesic API/runtime contract, and the
hosted GEO-G matrix repeats the public API contract across the accepted
platform/compiler matrix.

The accepted topocentric aggregate surface is likewise part of the permanent
public API contract. TOPO-F validates its aggregate API and runtime attributes;
TOPO-G repeats the contract across the accepted compiler/platform matrix and
executes the differential corpus with platform `real` wherever it is wider than
`double`.

Normal CI runs the aggregate contract for DMD and LDC.
