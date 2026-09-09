# ADR-0004: Invalid default state for `Ellipsoid<T>`

- Status: Accepted
- Date: 2026-09-09
- Amends: ADR-0002

## Context

D structs always have an `.init` value.

For `Angle<T>`, `Latitude<T>`, `Longitude<T>`, and the coordinate structs, a
useful valid zero/default value exists.

For `Ellipsoid<T>`, there is no neutral physical default.

The first implementation used:

```text
a = 1
f = 0
```

so that `Ellipsoid<T>.init` was a valid unit sphere.

That has an undesirable failure mode: an accidentally default-initialized
ellipsoid can flow through geodetic algorithms and return finite, numerically
plausible values that are nevertheless physically meaningless.

Using WGS 84 as the default would be worse because it would silently embed an
Earth/reference-frame assumption into a generic mathematical value type.

## Decision

`Ellipsoid<T>.init` is an explicitly **invalid sentinel**.

Canonical default storage is:

```d
semiMajorAxis = T.nan
flattening    = T.nan
```

The public type provides:

```d
@property bool isValid() const
    pure nothrow @safe @nogc;
```

A valid ellipsoid satisfies:

```text
semiMajorAxis finite
semiMajorAxis > 0
flattening finite
0 <= flattening < 1
```

All supported constructors/factories continue to create valid values:

```text
fromFlattening
fromInverseFlattening
fromAxes
sphere
wgs84
```

Operations that require an ellipsoid must validate `isValid` before using its
derived parameters.

For checked operations:

```text
invalid ellipsoid -> false
```

For throwing convenience wrappers:

```text
invalid ellipsoid -> GeodesyValueException
```

## Scope of the sentinel

The invalid `.init` state is a construction/error sentinel, not a physical
ellipsoid and not a normal mathematical value.

Derived property access on an invalid ellipsoid is not an operation contract
for v0.1. Callers that may possess a default-initialized `Ellipsoid<T>` must
check `isValid` or pass it to a checked operation.

This is a deliberate exception to ADR-0002's general preference that public
coordinate/value states themselves be finite and valid. The exception exists
because D struct default initialization cannot be disabled and because a
silently valid default ellipsoid is judged more dangerous than an explicitly
detectable invalid state.

## Consequences

### Positive

- Accidental default initialization fails detectably.
- No implicit WGS 84 assumption is introduced.
- No arbitrary unit sphere is treated as physically meaningful.
- Checked numerical operations reject the sentinel before calculation.
- `.init` semantics are explicit and testable.

### Negative

- `Ellipsoid<T>` is one public value type whose `.init` is intentionally
  invalid.
- Callers storing default ellipsoids must use `isValid`.
- Derived properties can yield NaN when called directly on the invalid sentinel.

The fail-fast behavior is preferred over silently producing plausible but
incorrect geodetic results.
