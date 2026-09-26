# geodesy-d Ddoc Style Guide

**Status:** Draft  
**Scope:** Public API documentation for `geodesy-d`

## 1. Purpose

Public Ddoc is part of the `geodesy-d` API contract.

A caller should be able to understand a public declaration without reading its implementation. Documentation must describe, where applicable:

- semantic meaning;
- accepted scalar and geometric/geodetic domain;
- units and unit relationships;
- construction and `.init` semantics;
- checked versus throwing failure semantics;
- supported ellipsoid or projection domain;
- boundary and singular cases;
- non-finite input behaviour;
- allocation behaviour;
- asymptotic complexity where meaningful;
- numerical guarantees and convergence limits;
- and realistic package-level usage.

## 2. Scope

This guide applies to every public symbol reachable through:

```d
import geodesy;
```

It also applies to public members of exported types.

Package-private and internal implementation symbols do not require the complete public-API format, although non-obvious internal invariants should still be documented.

## 3. General style

Documentation is written in English.

The first paragraph should state what the symbol means to a caller. Prefer observable semantics over implementation narrative.

For geodetic operations, state units and domains explicitly. Callers must not need to infer whether a value is in radians, degrees, metres, arc-seconds, parts per million, ellipsoid units, or another linear unit.

## 4. Module metadata

Every public module included in generated API documentation must have module-level Ddoc immediately preceding its `module` declaration.

Required sections:

```text
Authors:
Copyright:
License:
Date:
```

Standard form:

```d
Authors:
    Alexander Bernardi

Copyright:
    Copyright © 2026 Alexander Bernardi

License:
    MIT

Date:
    September 26, 2026
```

`Date:` records the current revision date of the module documentation and should change when the public contract documentation is materially revised.

## 5. Public types

Public types should document, where relevant:

- represented geodetic or mathematical concept;
- supported scalar types;
- units;
- validity invariants;
- `.init` state;
- canonicalization;
- equality semantics where non-obvious;
- valid degenerate states;
- non-finite-value policy;
- ownership or allocation behaviour.

Coordinates must state whether datum, CRS, or ellipsoid identity is embedded. In `geodesy-d`, coordinate value types generally do not embed CRS or datum metadata.

## 6. Units

Unit contracts are part of the API.

Examples include:

- `Angle`, `Latitude`, and `Longitude` store radians canonically;
- ellipsoid semi-major/minor axes use one caller-selected linear unit;
- geodetic height and geocentric coordinates must use the same linear unit as the associated ellipsoid;
- WGS 84 supplied by the library is metre-valued;
- Helmert EPSG-style constructors use arc-seconds and parts per million where documented;
- UTM fixed offsets are metre-valued.

When an operation is unit-agnostic, state the relationship explicitly rather than merely saying "same unit".

## 7. Domains and canonicalization

Document accepted domains explicitly.

Important examples include:

- latitude;
- longitude and its canonical half-open representation;
- ellipsoid flattening;
- Transverse Mercator longitude-distance bounds;
- Pseudo-Mercator latitude bounds;
- standard automatic UTM latitude band;
- explicit UTM zone/hemisphere semantics;
- geodesic supported flattening domain.

Do not rely only on template constraints or implementation checks.

## 8. Parameters, returns, and exceptions

Use Ddoc sections where they add semantic value:

```text
Params:
Returns:
Throws:
```

`Params:` should describe parameter meaning, units, or domain when not obvious.

`Returns:` should describe success values and checked-operation failure semantics.

`Throws:` should name `GeodesyValueException` and the conditions that cause it.

Avoid ceremonial duplication for trivial field accessors where the declaration and summary are already sufficient.

## 9. Checked and throwing APIs

Checked `try...` APIs must document every supported reason for returning `false`.

Where an `out` parameter has a defined failure state, document it.

Throwing convenience peers must document that they represent the same semantic operation and use `GeodesyValueException` on failure.

If an API intentionally has only a checked form or only a throwing form, document that choice where it matters.

## 10. Non-finite values and singular cases

Distinguish among:

- NaN;
- positive and negative infinity;
- finite values;
- mathematically singular but representable states.

Relevant singular cases include the geocentre, poles, antimeridian representations, coincident geodesic endpoints, invalid/default prepared projections, and projection-domain boundaries.

Tests verify these contracts; Ddoc must state user-visible behaviour.

## 11. Numerical guarantees

Numerical documentation should distinguish among:

- exact algebraic transformations;
- floating-point approximations;
- iterative convergence;
- promoted working precision;
- bounded-domain approximations;
- externally validated accuracy.

Do not claim generic "precision" without naming the operation, scalar type, domain, and validation basis.

There is no library-wide epsilon.

## 12. Allocation and complexity

State allocation behaviour for computationally meaningful APIs where it matters.

Preferred wording:

```text
No allocation is performed.
```

or:

```text
This operation may allocate temporary storage.
```

Document asymptotic complexity for non-trivial algorithms when it is informative to callers.

## 13. Examples

Examples should be executable documented unittests and should normally use:

```d
import geodesy;
```

Examples should demonstrate realistic public usage, not exhaustive regression cases.

A public declaration may either:

- have its own rendered `Example`; or
- be deliberately covered by a type or API-family example.

This classification is tracked in `docs/public-api-example-audit.md`.

## 14. Tests are not documentation

Behaviour intended as part of the public contract must not exist only in tests.

In particular, document:

- `.init` semantics;
- units;
- scalar domains;
- accepted coordinate and ellipsoid domains;
- canonicalization;
- checked failure conditions;
- exception conditions;
- singular and boundary cases;
- numerical guarantees.

## 15. ADRs and validation plans

ADRs explain persistent design decisions.

Validation plans document numerical evidence and acceptance gates.

Ddoc states the resulting caller-visible contract. It should link conceptually to those documents without duplicating their full rationale.

## 16. Definition of done

A public API family is documentation-complete when a caller can determine, where applicable:

- what it means;
- what units it uses;
- what domain it accepts;
- what `.init` means;
- how checked and throwing forms fail;
- what happens at boundaries and singularities;
- whether non-finite values are accepted;
- whether it allocates;
- what numerical guarantee applies;
- and how to use it through `import geodesy;`.

Completeness is judged by semantic coverage, not comment length.
