# ADR-0002: Core type, angle, scalar and ellipsoid model

- **Status:** Accepted
- **Date:** 2026-09-09

## Context

The first `geodesy-d` implementation requires value types for angles, geographic coordinates, reference ellipsoids, and geocentric coordinates.

The historical `coordinate` prototype already used separate latitude and longitude structs, but also exposed their underlying numbers through `alias this`, mixed `float`, `double`, and `real`, normalized some values implicitly, and represented ellipsoid parameters in forms that were easy to confuse.

The new API preserves the useful semantic separation while making units, validity, precision, and conversions explicit.

IOGP/EPSG terminology distinguishes geodetic latitude, longitude, and ellipsoidal height from geocentric Cartesian coordinates `(X,Y,Z)`. The core follows that terminology and keeps coordinate values separate from the ellipsoid used by a conversion.

## Decision

### 1. Strong semantic angle and coordinate types

The core distinguishes at least:

```text
Angle<T>
Latitude<T>
Longitude<T>
GeodeticCoordinate<T>
GeocentricCoordinate<T>
Ellipsoid<T>
```

`Latitude` and `Longitude` are not aliases for `T` and do not implicitly convert to raw numeric values.

The API makes the angular unit explicit at construction boundaries. Preferred construction style:

```d
Latitude!double.fromDegrees(48.20849)
Longitude!double.fromDegrees(16.37208)
Angle!double.fromRadians(x)
```

A naked numeric constructor with ambiguous angular units is not part of the primary public API.

### 2. Canonical internal angle representation

`Angle<T>`, `Latitude<T>`, and `Longitude<T>` store their angular value in **radians**.

Public degree-based construction and access remain available through explicitly named functions such as `fromDegrees` and `degrees`.

### 3. Latitude validity and longitude normalization are distinct concepts

A valid latitude is in the closed interval:

```text
[-π/2, +π/2]
```

A valid longitude is in the closed interval:

```text
[-π, +π]
```

Both `-π` and `+π` are valid representations of the antimeridian. Construction preserves the supplied valid endpoint and does not silently rewrite it.

When an algorithm or caller requires a unique normalized longitude representation, normalization is explicit and produces the half-open interval:

```text
[-π, +π)
```

Thus `+π` normalizes to `-π`, but only when normalization is explicitly requested.

Values outside the valid longitude interval are not implicitly wrapped during ordinary construction.

### 4. Floating-point scalar model

The core is **generic over D floating-point scalar types**. `double` is the **normative reference precision** for numerical validation and documented accuracy claims.

Policy:

- public core types and numerical kernels are templated on `T` with a floating-point constraint;
- `float`, `double`, and `real` are supported instantiations;
- `double` is the normative reference type for authoritative test vectors, published tolerances, and compatibility guarantees;
- `float` is explicitly a reduced-precision option for memory-sensitive or throughput-oriented workloads and must not be presented as numerically equivalent to `double`;
- `real` is supported but carries no portable promise of precision beyond `double`, because its precision and representation are platform-dependent in D;
- algorithms should normally compute in `T` rather than silently promote all intermediates to `real`;
- mixed-scalar operations do not perform implicit conversions.

Supporting several floating-point types does not imply that they provide equal geodetic precision. Precision requirements are documented per algorithm and scalar where they materially differ.

### 5. Latitude and Longitude store `T` directly

`Latitude<T>` and `Longitude<T>` each store their own scalar radian value directly rather than embedding an `Angle<T>` member.

Rationale:

- the domain invariants differ from those of a general angle;
- the value layout stays trivial and transparent;
- there is no need to expose generic angle operations accidentally through containment/delegation;
- duplication is limited to one scalar field.

Explicit conversion to a general `Angle<T>` may be provided where useful.

### 6. Checked construction and error semantics

Public value construction must validate external values. Contracts or assertions are never the sole validation mechanism for caller-supplied data.

The core provides two checked construction styles:

```text
tryFromRadians / tryFromDegrees
    no-throw path suitable for allocation-free code

fromRadians / fromDegrees
    convenience path that reports invalid input with a geodesy value error
```

The exact function signatures are an implementation detail, but the intended semantics are:

- the `try...` path is suitable for `nothrow` / `@nogc` code and does not allocate merely to report failure;
- the convenience `from...` path may throw a library-specific value exception;
- unchecked construction is package/private and may be used only after validity has already been established;
- internal assertions may protect invariants but do not replace external validation.

### 7. Non-finite values are not valid core coordinates

`NaN`, `+∞`, and `-∞` are rejected by public construction of:

```text
Angle
Latitude
Longitude
GeodeticCoordinate
GeocentricCoordinate
Ellipsoid
```

Algorithms may use non-finite intermediate values internally only where mathematically justified, but such values are not valid public coordinate states.

An ellipsoidal height may be negative; it must nevertheless be finite.

### 8. Canonical ellipsoid representation

`Ellipsoid<T>` stores one unambiguous canonical pair:

```text
semi-major axis a
flattening f
```

The initial supported physical domain is spherical or oblate:

```text
a > 0
0 <= f < 1
```

Alternative standard parameterizations use named factories:

```text
fromFlattening(a, f)
fromInverseFlattening(a, invF)
fromAxes(a, b)
sphere(radius)
```

`fromInverseFlattening` requires a finite valid inverse flattening; a sphere is created explicitly with `sphere(radius)` or equivalent axes rather than by passing infinity.

Derived properties are computed from the canonical state:

```text
semiMinorAxis
inverseFlattening
firstEccentricitySquared
secondEccentricitySquared
thirdFlattening
```

Public names avoid ambiguous single-letter APIs where confusion between eccentricity, eccentricity squared, flattening, and inverse flattening is realistic.

Reference ellipsoids such as WGS 84 may be supplied as named immutable/compile-time constants once their exact parameters and source are documented.

### 9. Geodetic coordinate meaning

`GeodeticCoordinate<T>` represents:

```text
geodetic latitude
longitude
ellipsoidal height
```

Height means **ellipsoidal height**, not orthometric height, geoid height, mean-sea-level height, or an unspecified altitude.

Accuracy metadata, datum identifiers, CRS identifiers, timestamps, and provenance do not belong in this core value type.

### 10. Geocentric coordinate naming and units

The canonical public type name is:

```text
GeocentricCoordinate<T>
```

It represents Earth-centred Cartesian coordinates `(x, y, z)`.

`ECEF` remains useful domain terminology in documentation and search terms, but no second public synonym/alias is introduced in v0.1 unless a concrete interoperability need appears.

For a geographic ↔ geocentric conversion, `(x, y, z)`, ellipsoidal height, and the ellipsoid axes use the same linear unit. The initial library examples and reference constants use metres, but the mathematical kernel does not attach a global unit registry to each coordinate value.

### 11. Coordinate values do not embed datum/CRS objects

Coordinates and the mathematical model used to transform them remain separate arguments where practical:

```text
geodeticToGeocentric(coordinate, ellipsoid)
```

rather than embedding a mutable datum/CRS catalogue entry into every coordinate value.

This keeps the core small, transparent, and independent of EPSG/authority infrastructure.

### 12. Cross-scalar conversion is explicit

There are no implicit conversions between, for example:

```text
Latitude<float>
Latitude<double>
Latitude<real>
```

v0.1 does not require a dedicated cross-scalar conversion API. A caller may explicitly extract the scalar value and reconstruct the destination type through the normal checked API.

A future conversion helper may be added when a real use case justifies it; narrowing conversions must never silently lose validity through overflow or non-finite results.

### 13. Floating-point comparison and tolerance policy

There is no global geodetic "approximately equal" rule based only on `T.epsilon`.

In particular:

- exact domain limits such as the valid latitude interval are validated against their mathematically defined boundaries rather than widened by a generic epsilon helper;
- algorithmic convergence criteria and test tolerances are operation-specific;
- comparisons near zero may require an absolute tolerance, while scale-dependent quantities may require relative or combined criteria;
- machine epsilon describes floating-point representation and is not by itself a physical or geodetic error budget;
- compensated summation (for example Kahan/Neumaier-style techniques) may be used where accumulated rounding error matters, based on the numerical needs of the algorithm;
- broad `@fastmath` is not enabled for the numerical core unless an algorithm-specific benchmark and accuracy analysis justify it.

The historical `mathematics.floating` prototype is useful as an exploration of generic floating-point helpers and compensated summation, but its global `equal`/`ltE`/`gtE` style is not adopted as domain validation policy.


### 14. Linear coordinates use a shared scalar-unit contract in v0.1

v0.1 does not introduce a separate `Length<T>` type. `Ellipsoid<T>` axes, `GeodeticCoordinate<T>.ellipsoidalHeight`, and `GeocentricCoordinate<T>` X/Y/Z components are stored as `T`.

Operations that combine these values require them to use the same linear unit. The unit is therefore an operation-level contract rather than encoded into each scalar type. Metres are the normative unit for the initial authoritative geodetic reference vectors, but the mathematical value types themselves are not intrinsically metre-only.

This decision may be revisited only if real cross-library use demonstrates that a strong length/unit type prevents material errors without imposing disproportionate interoperability or generic-programming cost.

### 15. Geodetic and geocentric coordinates are checked value types

`GeodeticCoordinate<T>` contains `Latitude<T>`, `Longitude<T>`, and finite ellipsoidal height. `GeocentricCoordinate<T>` contains finite Cartesian X/Y/Z components. Neither embeds an ellipsoid, datum, CRS, epoch, or accuracy metadata.

The geocentre `(0, 0, 0)` is a valid representable Cartesian coordinate. A geocentric-to-geodetic conversion may nevertheless report that the inverse position is undefined/non-unique at that point; representability and operation-domain validity are distinct concerns.

Both types expose checked throwing factories and `try...` construction paths, consistent with the other core value types.

## Consequences

- unit mistakes become visible at API boundaries;
- latitude and longitude cannot be accidentally treated as interchangeable naked numbers;
- geodetic formulae get a consistent internal angular representation;
- the valid antimeridian endpoint is preserved unless explicit normalization is requested;
- ellipsoid parameters have one canonical interpretation;
- public coordinate values cannot silently carry `NaN`/infinity sentinels;
- the API remains floating-point-generic while `double` provides the normative geodetic reference precision;
- `GeocentricCoordinate` follows standard geodetic terminology while documentation can still mention ECEF;
- allocation-free/no-throw validation remains possible without making unsafe construction public;
- coordinate structs remain compact value types without attached metadata/catalogue state.

## Alternatives considered

### Raw doubles everywhere

Rejected because it loses semantic and unit safety.

### Latitude/Longitude with `alias this`

Rejected because implicit conversion defeats the purpose of strong domain types.

### Store degrees internally

Rejected because the mathematical kernels predominantly operate in radians. Explicit degree construction/access remains available.

### Silently normalize longitude during construction

Rejected because validation and normalization are different operations. A valid `+180°` input should not be changed merely by constructing a value.

### Exception-only construction

Rejected because the numerical core should retain an allocation-free, `nothrow` validation path.

### Assertion-only validation

Rejected because assertions/contracts are not an adequate parser or external-input validation boundary.

### Guarantee every D floating-point scalar in v0.1

Rejected because numerical guarantees must follow testing rather than template syntax.

### `ECEF` as the sole canonical type name

Not chosen because IOGP/EPSG consistently use the more general geocentric Cartesian terminology for the coordinate domain. ECEF remains recognizable documentation terminology.

### Embed datum/CRS metadata in each coordinate

Rejected for the core because it couples value representation to authority/catalogue infrastructure and repeats the scope problems of the historical prototype.
