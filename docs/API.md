# geodesy-d public API

The tagged `v0.1.0` surface remains the historical release baseline. This
document also records public APIs added on the current unreleased development
line when their implementation surface has stabilized.

## Aggregate import

```d
import geodesy;
```

`source/geodesy/package.d` is the intentional public aggregation surface.
The tagged v0.1 API contract is compiled through this aggregate import, and
post-v0.1 public modules are added here only after their implementation gate has
passed.

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


## EPSG 9836 / 9837 topocentric ENU — current unreleased accepted surface

The current development line exports:

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
`pure nothrow @safe @nogc`. No 7-parameter `inverse()` shortcut is exposed in
v0.1.

## Conformal projection factors — current unreleased accepted surface

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

## Transverse Mercator — current unreleased accepted surface

The current development line exports the accepted bounded generic Transverse
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

## Pseudo-Mercator — current unreleased accepted surface

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

The initial public surface deliberately does not provide a `WebMercator`
alias, latitude-of-natural-origin or scale-factor parameters, conformal
projection factors, one-shot free forward/reverse helpers, CRS/EPSG lookup, or
web-map tile/zoom/XYZ/TMS policy.

The PM-A through PM-G5 research and acceptance evidence is retained under
`research/pseudo-mercator/`.

## UTM — current unreleased accepted surface

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

## Ellipsoidal geodesics — current unreleased surface

The current development line exports the geodesic API through the aggregate:

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

The first slice does not expose `GeodesicLine`, reduced length, geodesic
scales, area, longitude unrolling, polygon accumulation, or prolate ellipsoids.

See ADR-0008 and `docs/GEODESIC_VALIDATION_PLAN.md` for the accepted
numerical, canonicalization, and validation contract.

## Public API contract

Run:

```bash
tools/validate-api.sh
```

The tagged v0.1 contract verifies externally that aggregate
`import geodesy;` exposes its intended baseline surface, checked APIs retain
their hot-path attributes, mutable parameter leakage is rejected,
package/private helpers remain inaccessible, and Helmert convention selection
cannot be omitted.

The permanent aggregate contract also compiles a named-argument compatibility
surface under DMD and LDC. Public parameter names are therefore treated as
source compatibility for the current stabilized API.

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
