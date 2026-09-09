# 7-parameter Helmert transformations

## Status

Architecture fixed in ADR-0003. Numerical implementation pending.

## EPSG methods

The initial static Helmert implementation will cover:

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

but **do not use the same signs for the rotation parameters**.

See:

```text
docs/adr/0003-helmert-rotation-conventions.md
```

for the normative `geodesy-d` type and unit model.

## Planned public types

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

## Canonical units

```text
translations       same linear unit as X/Y/Z
rotations          radians through Angle<T>
scale difference   dimensionless fraction
```

Explicit arc-second + ppm factories are planned for interchange with common
EPSG parameter representations.

## Validation plan

The implementation should initially include:

1. EPSG 1033 WGS 72 -> WGS 84 worked example;
2. the equivalent EPSG 1032 example with rotation signs reversed;
3. proof that convention conversion gives the same transformed coordinate;
4. identity transform via `.init`;
5. pure translation equivalence with EPSG 1031 when rotations and scale are
   zero;
6. pure scale cases;
7. independent X/Y/Z rotation-sign tests;
8. `float`, `double`, and `real` instantiation;
9. non-finite parameter rejection;
10. arithmetic overflow/non-finite result handling;
11. later differential tests against PROJ.

## Deferred

Not part of the first implementation:

- inverse API;
- exact finite-angle Helmert;
- time-dependent / 14-parameter Helmert;
- Molodensky-Badekas;
- CRS lookup or automatic operation selection.
