# Geocentric translation — EPSG method 1031

## Status

Implemented.

## Scope

EPSG method **1031 — Geocentric translations (geocentric domain)** transforms
Cartesian geocentric coordinates from a source reference frame to a target
reference frame using three translations.

It operates only on geocentric coordinates. Conversion between geodetic and
geocentric coordinates is a separate EPSG method (9602).

## Formula

For source coordinates `(Xs, Ys, Zs)` and source-to-target translation
parameters `(dX, dY, dZ)`:

```text
Xt = Xs + dX
Yt = Ys + dY
Zt = Zs + dZ
```

The inverse is obtained by changing the signs of all three translation
parameters:

```text
(-dX, -dY, -dZ)
```

This reversibility rule is explicitly encoded by
`GeocentricTranslation.inverse()`.

## Units

`Xs/Ys/Zs`, `Xt/Yt/Zt`, and `dX/dY/dZ` must all use the same linear unit.

`geodesy-d` does not attach a unit object to the scalar values. The unit
contract is therefore explicit in the operation API and documentation.

## API

```d
struct GeocentricTranslation(T)
{
    T deltaX;
    T deltaY;
    T deltaZ;

    static bool tryFromComponents(...);
    static GeocentricTranslation!T fromComponents(...);

    GeocentricTranslation!T inverse() const;
}

bool tryApplyGeocentricTranslation(T)(
    const GeocentricCoordinate!T source,
    const GeocentricTranslation!T translation,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc;

GeocentricCoordinate!T applyGeocentricTranslation(T)(
    const GeocentricCoordinate!T source,
    const GeocentricTranslation!T translation);
```

`GeocentricTranslation!T.init` is intentionally the identity transformation.

## Validation

The initial deterministic test set includes the EPSG/IOGP North Sea worked
example:

```text
source:
X = 3 771 793.97 m
Y =   140 253.34 m
Z = 5 124 304.35 m

translation:
dX =  84.87 m
dY =  96.49 m
dZ = 116.95 m

target:
X = 3 771 878.84 m
Y =   140 349.83 m
Z = 5 124 421.30 m
```

Tests also cover:

- inverse parameter sign reversal;
- identity transformation;
- `float`, `double`, and `real`;
- non-finite parameter rejection;
- arithmetic overflow.

`double` remains the normative validation scalar.

## Relationship to Helmert transformations

This operation is deliberately implemented independently of the 7-parameter
Helmert transformations.

The next layer adds:

- EPSG 1033 — Position Vector transformation (geocentric domain);
- EPSG 1032 — Coordinate Frame rotation (geocentric domain).

Those methods add rotations and scale while preserving the same translation
parameter semantics.

Keeping EPSG 1031 separate gives the translation component an independently
testable contract and avoids hiding a simple exact operation inside a larger
Helmert abstraction.
