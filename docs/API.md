# geodesy-d public API — v0.1 baseline

## Aggregate import

```d
import geodesy;
```

`source/geodesy/package.d` is the intentional public aggregation surface.
The v0.1 API contract is compiled through this aggregate import.

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

## Public API contract

Run:

```bash
tools/validate-api.sh
```

The contract verifies externally that aggregate `import geodesy;` exposes the
intended surface, checked APIs retain their hot-path attributes, mutable
parameter leakage is rejected, package/private helpers remain inaccessible,
and Helmert convention selection cannot be omitted.

Normal CI runs the contract for DMD and LDC.
