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
Epoch<T>
Helmert14<T, convention>
PositionVectorHelmert14<T>
CoordinateFrameHelmert14<T>
```

`HelmertConvention` is public and has no default. `Epoch<T>.init` and
`Helmert14<T, convention>.init` are invalid.

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


## EPSG 1053 / 1056 — additive M4 dynamic Helmert

The M4 reference-frame line adds a strong epoch value and a time-dependent
14-parameter Helmert family:

~~~text
Epoch<T>
Helmert14<T, convention>
PositionVectorHelmert14<T>
CoordinateFrameHelmert14<T>
~~~

The fourteen transformation parameters are the seven static Helmert values
plus seven signed rates. The parameter reference epoch is stored separately
and is not counted as a fifteenth transformation parameter.

`Epoch<T>` stores a finite decimal year. It does not perform calendar,
UTC/TAI/GPS, or leap-second conversion. `.init` is invalid.

A dynamic transform stores:

~~~text
baseParameters       Helmert7<T, convention>
translationRateX/Y/Z linear-unit / year
rotationRateX/Y/Z    radians / year
scaleDifferenceRate  dimensionless / year
referenceEpoch       Epoch<T>
~~~

The EPSG-style construction surface accepts base rotations in arc-seconds,
rotation rates in arc-seconds/year, base scale in ppm, and scale rate in
ppm/year.

At observation epoch `t`, each parameter is evaluated as:

~~~text
P(t) = P(t0) + rate * (t - t0)
~~~

where `t0` is the stored parameter reference epoch. Evaluation returns the
existing convention-specific `Helmert7<T, convention>`, and spatial
application reuses the existing EPSG 1032/1033 kernel.

The prepared API exposes:

~~~text
tryEvaluate / evaluate
tryApply    / apply
~~~

Position Vector and Coordinate Frame remain distinct compile-time types.
`toCoordinateFrameHelmert14` and `toPositionVectorHelmert14` negate both
rotation parameters and rotation rates while preserving translations,
translation rates, scale, scale rate, and reference epoch.

Public `float` rate propagation uses double working precision.
`double` uses double and `real` retains platform-real precision.

Zero rates are required to evaluate exactly to the stored static
`Helmert7` parameter set for every finite observation epoch.

See `docs/M4_EPOCH_SEMANTICS.md` and
`docs/DYNAMIC_HELMERT_VALIDATION.md`.

## Molodensky-Badekas — additive M4 reference-frame surface

The aggregate API exports the static geocentric Molodensky-Badekas family:

~~~text
MolodenskyBadekas10<T, convention>
PositionVectorMolodenskyBadekas<T>
CoordinateFrameMolodenskyBadekas<T>
~~~

The two convention-specific aliases correspond to EPSG methods 1061 (Position
Vector, geocentric domain) and 1034 (Coordinate Frame, geocentric domain).

Construction follows the Helmert unit policy. Canonical construction accepts an
existing convention-specific `Helmert7` plus the three source-geocentric
evaluation-point ordinates. The EPSG interchange factory accepts translations
and evaluation-point ordinates in the caller's geocentric linear unit,
rotations in arc-seconds, and scale difference in ppm.

Prepared values expose:

~~~text
baseParameters
evaluationPointX / evaluationPointY / evaluationPointZ
equivalentHelmert
tryApply / apply
~~~

The implementation does not duplicate the Helmert spatial matrix. It prepares
the algebraically equivalent `Helmert7` once and delegates each coordinate
application to the existing EPSG 1032/1033 kernel.

`toCoordinateFrameMolodenskyBadekas` and
`toPositionVectorMolodenskyBadekas` negate only the rotations while
preserving translations, scale, and evaluation point. A zero evaluation point
reduces exactly to the existing Helmert7 family.

`.init` is the identity transformation. No `inverse()` convenience API is
provided because the EPSG evaluation point belongs to the forward source
Cartesian CRS; reusing the same ten values in reverse is not, in general, the
exact mathematical inverse.

Independent validation uses the EPSG La Canoa -> REGVEN worked vector and PROJ
`+proj=molobadekas` for both rotation conventions.

See `docs/MOLODENSKY_BADEKAS.md`.

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

The released v1.1 line adds advanced quantities without changing the frozen v1
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

The released v1.1 line completes the admitted geodesic family with two prepared
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
rules. M5 extends the prepared line additively without changing the existing
distance-position contract:

~~~text
GeodesicLine.tryArcPosition / arcPosition
GeodesicLine.tryPositionUnrolled / positionUnrolled
GeodesicLine.tryArcPositionUnrolled / arcPositionUnrolled
GeodesicLineUnrolledResult<T>
~~~

Arc input is the signed auxiliary-sphere arc `sigma12` carried as
`Angle<T>`. It is not an ellipsoidal distance. The ordinary distance and arc
position methods return canonical `GeographicCoordinate<T>` longitude.

The explicit unrolled methods instead return
`GeodesicLineUnrolledResult<T>`, whose `unrolledLongitude` is an unrestricted
finite `Angle<T>`. The difference from the accepted input longitude retains
the number and direction of complete ellipsoid encirclements. It is
intentionally not represented by `Longitude<T>`, whose domain remains
[-pi,+pi].

These additions reuse the existing prepared line state; they do not enlarge
the `GeodesicLine<T>` object.

Advanced prepared-line segment quantities use additive checked overloads that
mirror the existing advanced direct-geodesic contract:

~~~d
bool tryPosition(
    T distance,
    out GeodesicDirectResult!T result,
    out GeodesicQuantities!T quantities) const;

bool tryArcPosition(
    Angle!T arc,
    out GeodesicDirectResult!T result,
    out GeodesicQuantities!T quantities) const;
~~~

Only these overloads compute `m12`, `M12`, `M21`, and `S12`. The ordinary
distance/arc position paths do not prepare or evaluate the additional C2/C4
series state.

M5 also adds bounded nearest-point geometry for oriented geodesic segments:

~~~text
tryNearestPointOnSegment / nearestPointOnSegment
GeodesicSegmentNearestResult<T>
GeodesicSegmentNearestKind
~~~

A and B define the shortest geodesic segment and its A->B orientation. The
result separates bounded-segment quantities from supporting-geodesic
quantities:

~~~text
nearestPoint / nearestDistance   finite segment
kind                             start | interior | end
supportingFoot                   local perpendicular intercept
alongTrack                       signed from A in A->B direction
signedCrossTrack                 right-positive, left-negative
~~~

For endpoint-clamped results, `nearestDistance` is the true target-to-endpoint
distance. `signedCrossTrack` remains the perpendicular distance to the local
supporting geodesic and is therefore not substituted for the endpoint distance.

The implementation uses Karney's ellipsoidal gnomonic interception
construction from the existing geodesic reduced length and scale quantities.
It does not use spherical great-circle cross-track formulae. Degenerate A==B
segments are rejected because orientation and signed track quantities are
undefined. Very distant / antipodal configurations outside the local
gnomonic-convergence domain fail through the checked API rather than claiming
global infinite-line uniqueness.

M5 bounded geodesic-segment intersection is exposed separately:

~~~text
tryIntersectGeodesicSegments / intersectGeodesicSegments
GeodesicSegmentIntersectionResult<T>
GeodesicSegmentIntersectionKind
~~~

Each endpoint pair defines one bounded shortest ellipsoidal geodesic segment.
A successful operation returns exactly one geometric classification:

~~~text
none      finite segments share no point
point     exactly one common point
overlap   coincident supporting geodesics share a non-zero bounded interval
~~~

For `point`, `firstPoint == secondPoint`. For `overlap`, the two result
points are the actual geographic overlap endpoints, ordered along the first
input segment. GeographicLib's internal displacement/mode codes are not part of
the public D API.

A checked call returning `true` with `kind == none` is a successful
geometric result. `false` is reserved for invalid, degenerate, ambiguous, or
non-converged input. Exact antipodal endpoint pairs are rejected because the
shortest connecting geodesic is not unique.

The implementation follows Karney's iterative ellipsoidal geodesic-intersection
method with prepared `GeodesicLine` values and a bounded midpoint/corner seed
strategy independently qualified against GeographicLib 2.7. It does not use a
planar projection shortcut.

Polygon area is positive for counterclockwise traversal and is canonicalized
to `(-A/2, A/2]`, where `A` is the full ellipsoid area.
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

## Additive v1.2 navigation and projection families

v1.2 extends the frozen v1 line with five additive public families. Existing
v1.0/v1.1 names, call shapes, parameter names, scalar policy, failure channels,
and operation domains remain unchanged.

### Rhumb / RhumbLine

The aggregate API exports:

~~~text
Rhumb<T>
RhumbLine<T>
RhumbDirectResult<T>
RhumbInverseResult<T>
~~~

`Rhumb<T>` is a prepared ellipsoidal loxodrome solver. Construction follows
the checked/throwing factory pattern:

~~~text
Rhumb.tryFromEllipsoid / fromEllipsoid
~~~

The operational surface provides checked/throwing direct and inverse pairs.
Inverse returns shortest-wrap rhumb distance and constant bearing. Direct
accepts signed distance. Exact opposite-meridian inverse ties choose the
east-going solution.

`RhumbLine<T>` prepares one start point and bearing for repeated positions.
It is distinct from `GeodesicLine<T>`; rhumb and geodesic mathematics remain
separate public families.

Supported scalar and ellipsoid policy is:

~~~text
T = float | double | real
a > 0
0 <= f <= 0.01
~~~

Public `float` uses double working precision. Longitudes are canonicalized to
`[-pi,+pi)`. Prolate ellipsoids and longitude-unrolled output are not part of
the v1.2 contract.

See `docs/RHUMB_RESEARCH.md` for the numerical and singularity policy.

### Polar Stereographic

The aggregate API exports:

~~~text
PolarStereographic<T>
~~~

The prepared projection provides checked/throwing construction, forward,
reverse, and conformal-factor operations.

The primary public semantics follow bounded ellipsoidal Polar Stereographic
with EPSG 9810 variant-A parameterization. EPSG 9829 variant-B construction is
represented through the equivalent natural-origin scale.

North and south aspects are both supported. The exact pole maps to the false
origin. Public `float` uses double working precision.

Projection factors use the existing:

~~~text
ConformalProjectionFactors<T>
~~~

result type.

See `docs/POLAR_STEREOGRAPHIC_RESEARCH.md` for domain, aspect, pole, and
validation details.

### UPS

UPS is a WGS 84 policy and tagged-coordinate layer over the accepted
`PolarStereographic<T>` kernel.

The aggregate API exports:

~~~text
UpsHemisphere
UpsCoordinate<T>
UpsProjection<T>
tryStandardUps...
forward/reverse UPS helpers
~~~

Automatic UTM/UPS selection uses the standard transition policy:

~~~text
south: latitude < -80 deg -> UPS
north: latitude >= +84 deg -> UPS
~~~

Explicit overlap handling is supported around the transition bands. UPS owns
policy and coordinate semantics; it does not duplicate Polar Stereographic
mathematics.

See `docs/UPS_POLICY.md` for the accepted range and overlap contract.

### Lambert Conformal Conic 2SP

The aggregate API exports:

~~~text
LambertConformalConic<T>
~~~

The v1.2 family is the genuine two-standard-parallel ellipsoidal form
corresponding to EPSG method 9802. Equal standard parallels are deliberately
rejected rather than silently treated as a 1SP tangent limit.

Prepared operations expose checked/throwing forward and reverse projection plus
conformal factors through `ConformalProjectionFactors<T>`.

Independent validation includes authority-backed parameter sets for:

- EPSG:31287 — MGI / Austria Lambert;
- EPSG:3034 — ETRS89-extended / LCC Europe.

See `docs/LAMBERT_CONFORMAL_CONIC_RESEARCH.md`.

### Lambert Azimuthal Equal Area

The aggregate API exports:

~~~text
LambertAzimuthalEqualArea<T>
~~~

The prepared ellipsoidal family supports oblique, equatorial, north-polar, and
south-polar projection centres, with checked/throwing forward and reverse
operations.

The exact projection centre canonicalizes to false easting/northing. The exact
authalic antipode is a directional singularity and is rejected. Reverse
projection accepts the open represented disk and rejects the antipodal
boundary and points beyond it.

LAEA is equal-area, not conformal; it therefore deliberately does not expose
`ConformalProjectionFactors<T>`.

Independent validation includes EPSG:3035 — ETRS89-extended / LAEA Europe.

See `docs/LAMBERT_AZIMUTHAL_EQUAL_AREA_RESEARCH.md`.

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
