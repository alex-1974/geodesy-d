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
