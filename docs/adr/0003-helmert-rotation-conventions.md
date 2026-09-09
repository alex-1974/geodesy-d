# ADR-0003: Helmert rotation conventions and parameter model

- Status: Accepted
- Date: 2026-09-09

## Context

`geodesy-d` now implements:

- EPSG 9602 — geographic/geocentric conversion;
- EPSG 1031 — geocentric translations.

The next frame-transformation layer is the simplified 7-parameter Helmert
transformation in geocentric coordinates.

EPSG defines two methods with identical translation and scale semantics but
opposite definitions of the rotation parameters:

- EPSG 1033 — Position Vector transformation (geocentric domain);
- EPSG 1032 — Coordinate Frame rotation (geocentric domain).

The distinction is not cosmetic. Supplying rotation parameters defined in one
convention to the other method changes the result.

The two parameter sets can represent the same physical transformation only
when the signs of all three rotation parameters are reversed.

## Decision

### 1. Rotation convention is part of the type

The convention SHALL NOT be represented by:

- a string;
- an unchecked Boolean;
- a runtime default;
- documentation alone.

The planned public model is:

```d
enum HelmertConvention
{
    positionVector,
    coordinateFrame
}

struct Helmert7(T, HelmertConvention convention)
if (isGeodesyScalar!T)
{
    // parameters
}

alias PositionVectorHelmert(T) =
    Helmert7!(T, HelmertConvention.positionVector);

alias CoordinateFrameHelmert(T) =
    Helmert7!(T, HelmertConvention.coordinateFrame);
```

The template parameter has **no default**.

Consequently:

```text
PositionVectorHelmert!double
```

and:

```text
CoordinateFrameHelmert!double
```

are different D types even though their stored parameter dimensions are the
same.

This prevents a convention from being silently omitted at construction time.

### 2. EPSG 1033 and 1032 are separate semantic APIs over shared machinery

The numerical implementation may share one private/internal kernel, selected at
compile time from the convention type.

The public API must preserve the EPSG distinction.

A generic runtime call such as:

```text
helmert(parameters, "position_vector")
```

is explicitly rejected as the core API design.

### 3. Canonical parameter representation

The seven source-to-target parameters are:

```text
tX, tY, tZ
rX, rY, rZ
dS
```

Canonical storage SHALL use:

- translations: scalar `T`, in the same linear unit as the geocentric
  coordinates;
- rotations: `Angle!T`, canonically stored in radians by `Angle`;
- scale difference `dS`: dimensionless scalar fraction.

The multiplication factor is derived as:

```text
M = 1 + dS
```

No separate mutable `M` value is stored.

EPSG parameter sets commonly publish:

- rotations in arc-seconds;
- scale difference in parts per million.

Those are input/output representations, not the canonical storage model.

Explicitly named convenience factories may therefore be provided, for example:

```text
fromArcSecondsAndPpm(...)
```

with:

```text
rotationRadians = arcSeconds * pi / (180 * 3600)
dS = ppm * 1e-6
```

Unnamed factories that make the rotation or scale unit ambiguous are not
allowed.

### 4. `.init` is the identity transformation

All translation, rotation, and scale-difference parameters SHALL default
explicitly to zero.

Thus:

```text
Helmert7!(T, convention).init
```

must represent:

```text
tX = tY = tZ = 0
rX = rY = rZ = 0
dS = 0
M = 1
```

This requirement is explicit because D floating-point fields otherwise default
to NaN when no field initializer is supplied.

### 5. Position Vector formula — EPSG 1033

For source vector `(Xs, Ys, Zs)`:

```text
Xt = tX + M * ( Xs - rZ*Ys + rY*Zs )
Yt = tY + M * ( rZ*Xs + Ys - rX*Zs )
Zt = tZ + M * (-rY*Xs + rX*Ys + Zs )
```

where rotations are in radians.

A positive EPSG Position Vector rotation is defined according to the EPSG 1033
position-vector convention.

### 6. Coordinate Frame formula — EPSG 1032

For the same parameter names:

```text
Xt = tX + M * ( Xs + rZ*Ys - rY*Zs )
Yt = tY + M * (-rZ*Xs + Ys + rX*Zs )
Zt = tZ + M * ( rY*Xs - rX*Ys + Zs )
```

The difference from EPSG 1033 is solely the signs of the rotation terms.

### 7. Convention conversion is explicit and negates rotations only

Explicit conversion helpers may be provided:

```text
toCoordinateFrame(PositionVectorHelmert)
toPositionVector(CoordinateFrameHelmert)
```

They preserve:

```text
tX, tY, tZ, dS
```

and negate:

```text
rX, rY, rZ
```

This conversion changes the **parameter convention**, not the represented
source-to-target transformation.

No reinterpret-cast or zero-cost relabelling of unchanged rotation values is
allowed.

### 8. EPSG simplified Helmert remains distinct from exact 3D rotation

EPSG 1032 and 1033 use the conventional small-angle linearized rotation
matrices.

The initial `geodesy-d` implementation SHALL implement those EPSG methods as
specified.

A full finite-angle/exact rotation implementation, if later justified, must be
a separately documented operation or mode. It must not silently replace the
EPSG 1032/1033 equations under the same API contract.

### 9. No 7-parameter `inverse()` shortcut in the initial API

EPSG 1031 translation has an exact inverse represented simply by negating
`tX/tY/tZ`.

That property is not carried over blindly to the simplified 7-parameter
Helmert model.

For:

```text
target = translation + M * A * source
```

the mathematical inverse requires inversion of the scale and rotation matrix.
For the linearized rotation matrix, simply negating all seven parameters is not
the exact algebraic inverse.

Therefore the initial 7-parameter API SHALL NOT expose an `inverse()` method
whose implementation merely negates the parameters.

Inverse transformation semantics will be designed separately, with reference
tests, after the forward EPSG 1032/1033 methods are implemented.

### 10. Kinematic Helmert is out of this step

Parameter rates and epochs are not part of the initial 7-parameter type.

A future time-dependent transformation may add:

```text
d(tX)/dt, d(tY)/dt, d(tZ)/dt
d(rX)/dt, d(rY)/dt, d(rZ)/dt
d(dS)/dt
reference epoch
coordinate epoch
```

as a distinct model.

The static `Helmert7` type must not accumulate optional epoch/rate state merely
to anticipate that future feature.

## Consequences

### Positive

- Rotation convention cannot be omitted accidentally.
- EPSG 1032 and 1033 remain discoverable in the public type model.
- The same numerical kernel can still be reused internally.
- Canonical radians and dimensionless scale remove unit ambiguity from the
  mathematical core.
- EPSG-style arc-second/ppm input remains ergonomic through explicitly named
  factories.
- `.init` has useful identity semantics.
- Exact and linearized Helmert transformations cannot be silently conflated.
- An inaccurate inverse shortcut is avoided.

### Negative

- Two convention-specific types are visible to users.
- Importers from EPSG/PROJ/WKT parameter sets must explicitly choose the
  correct convention.
- Inverse transformation requires a later design step instead of a trivial
  `.inverse()` convenience method.

These costs are intentional because the rotation-convention ambiguity is one
of the principal practical failure modes of 7-parameter datum transformations.

## References

Primary:

- EPSG coordinate operation method 1033 — Position Vector transformation
  (geocentric domain).
- EPSG coordinate operation method 1032 — Coordinate Frame rotation
  (geocentric domain).
- IOGP Report 373-07-2 / EPSG Guidance Note 7-2.

Cross-validation:

- PROJ Helmert transformation documentation.

PROJ likewise requires an explicit convention when rotational parameters are
present and documents that conversion between the two conventions is performed
by negating the rotation parameters.
