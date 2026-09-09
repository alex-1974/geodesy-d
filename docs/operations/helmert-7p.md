# 7-parameter Helmert transformations

## Status

- Parameter/type model implemented.
- EPSG 1033 Position Vector implemented.
- EPSG 1032 Coordinate Frame pending.

The normative design is ADR-0003:

```text
docs/adr/0003-helmert-rotation-conventions.md
```

## EPSG methods

The static Helmert layer covers:

```text
EPSG 1033  Position Vector transformation (geocentric domain)
EPSG 1032  Coordinate Frame rotation (geocentric domain)
```

Both methods use:

```text
3 translations
3 rotations
1 scale difference
```

but use opposite signs for the rotation terms.

## Public type model

```d
enum HelmertConvention
{
    positionVector,
    coordinateFrame
}

struct Helmert7(T, HelmertConvention convention);

alias PositionVectorHelmert(T) =
    Helmert7!(T, HelmertConvention.positionVector);

alias CoordinateFrameHelmert(T) =
    Helmert7!(T, HelmertConvention.coordinateFrame);
```

There is intentionally no default convention.

`PositionVectorHelmert!T` and `CoordinateFrameHelmert!T` are distinct D types.

## Canonical units

```text
translations       same linear unit as X/Y/Z
rotations          Angle<T>, canonically radians
scale difference   dimensionless fraction dS
scale factor       M = 1 + dS
```

For EPSG-style parameter input an explicit factory is provided:

```d
fromArcSecondsAndPpm(...)
```

with:

```text
radians = arc-seconds * pi / (180 * 3600)
dS      = ppm * 1e-6
```

All raw floating parameters must be finite.

`.init` is the identity transform:

```text
translations = 0
rotations    = 0
dS           = 0
M            = 1
```

## EPSG 1033 — Position Vector

Implemented API:

```d
bool tryApplyPositionVectorHelmert(T)(
    const GeocentricCoordinate!T source,
    const PositionVectorHelmert!T transform,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc;

GeocentricCoordinate!T applyPositionVectorHelmert(T)(
    const GeocentricCoordinate!T source,
    const PositionVectorHelmert!T transform);
```

Formula:

```text
Xt = tX + M * ( Xs - rZ*Ys + rY*Zs )
Yt = tY + M * ( rZ*Xs + Ys - rX*Zs )
Zt = tZ + M * (-rY*Xs + rX*Ys + Zs )
```

where rotations are in radians and:

```text
M = 1 + dS
```

This is the EPSG small-angle Position Vector matrix. It is not silently
replaced by a finite-angle rotation matrix.

## EPSG 1033 reference test

IOGP Guidance Note 7-2 gives the WGS 72 -> WGS 84 transformation
(EPSG transformation 1238):

```text
tX = 0.000 m
tY = 0.000 m
tZ = +4.5 m

rX = 0.000 arcsec
rY = 0.000 arcsec
rZ = +0.554 arcsec
   = +0.000002685868 rad

dS = +0.219 ppm
M  = 1.000000219
```

Input:

```text
X = 3 657 660.66 m
Y =   255 768.55 m
Z = 5 201 382.11 m
```

Published result:

```text
X = 3 657 660.78 m
Y =   255 778.43 m
Z = 5 201 387.75 m
```

The published result is rounded to centimetres, and the deterministic unit
test uses a matching tolerance.

## Additional validation

The initial implementation also tests:

1. identity semantics of `.init`;
2. reduction to EPSG 1031 when rotation and scale are zero;
3. pure scale;
4. positive Position Vector `rZ` sign behavior;
5. `float`, `double`, and `real`;
6. non-finite parameter rejection;
7. arithmetic overflow/non-finite result handling.

`double` remains the normative validation scalar.

## EPSG 1032 — next step

Coordinate Frame will use the same parameter storage but the opposite
rotation-term signs:

```text
Xt = tX + M * ( Xs + rZ*Ys - rY*Zs )
Yt = tY + M * (-rZ*Xs + Ys + rX*Zs )
Zt = tZ + M * ( rY*Xs - rX*Ys + Zs )
```

The convention conversion will be explicit and will negate only `rX/rY/rZ`.

## Deferred

Not part of the initial static implementation:

- inverse API;
- exact finite-angle Helmert;
- time-dependent / 14-parameter Helmert;
- Molodensky-Badekas;
- CRS lookup or automatic operation selection.
