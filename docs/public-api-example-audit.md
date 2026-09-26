# Public API Example Audit

**Status:** initial audit framework  
**Baseline:** post-v1 development branch `audit/v1-public-api`

## Purpose

This audit tracks executable Ddoc example coverage for the public `geodesy-d` API.

Each public DDox symbol page should be classified as one of:

- **existing** — a documented `unittest` renders as an `Example`;
- **add** — the declaration should receive its own executable example;
- **family** — a dedicated example would add little value and the declaration is deliberately covered by a named type or API-family example.

Examples should normally compile through:

```d
import geodesy;
```

The goal is systematic user-facing coverage without mechanically duplicating examples for trivial accessors, enum values, aliases, or tightly related checked/throwing peers.

## Audit families

The public surface is organized into these documentation families:

| Family | Representative public surface | Initial state |
| --- | --- | --- |
| scalar policy | `isGeodesyScalar`, finite-scalar policy | audit required |
| angles | `Angle`, `Latitude`, `Longitude` | audit required |
| ellipsoid | `Ellipsoid`, `wgs84` | audit required |
| geographic/geodetic values | `GeographicCoordinate`, `GeodeticCoordinate` | audit required |
| Cartesian values | `GeocentricCoordinate`, `ProjectedCoordinate`, `TopocentricCoordinate` | audit required |
| conversion | geographic/geocentric checked and throwing operations | audit required |
| geocentric translation | EPSG 1031 family | audit required |
| Helmert | EPSG 1032 / 1033 families | audit required |
| Transverse Mercator | prepared projection, forward/reverse, factors | audit required |
| Pseudo-Mercator | prepared projection and bounded policy | audit required |
| UTM | zones, hemispheres, prepared/automatic/tagged operations | audit required |
| geodesics | prepared solver, direct/inverse results and operations | audit required |
| topocentric | prepared ENU frame and conversions | audit required |
| errors | `GeodesyValueException` | usually family-covered |

## Coverage policy

Dedicated examples are expected for:

- primary public value types;
- primary prepared-operation types;
- non-trivial constructors/factories where usage is not obvious;
- principal numerical operations;
- operations whose checked failure semantics are important;
- domain-policy helpers such as automatic UTM selection.

Family coverage is normally appropriate for:

- trivial property accessors;
- enum members;
- direct field-style getters;
- throwing peers already demonstrated beside their checked operation;
- result accessors already demonstrated by the producing operation.

## Geodesy-specific example requirements

Examples should make important domain semantics visible:

- radians versus degrees;
- linear-unit consistency;
- invalid `.init` where applicable;
- checked versus throwing behaviour;
- geographic domain boundaries;
- explicit versus automatic UTM policy;
- prepared-operation reuse;
- frame/convention explicitness;
- singular cases where instructional value is high.

Regression and differential-validation tests remain ordinary unittests rather than documentation examples.

## Completion criteria

The audit is complete when:

1. every public DDox symbol page is classified;
2. no declaration remains classified as **add**;
3. every **existing** declaration renders an `Example`;
4. every **family** declaration names the owning example family;
5. examples compile through the public package surface where practical;
6. a verifier checks the inventory against generated DDox output;
7. the documentation build fails when a public page appears without classification or an expected example disappears.

The detailed per-symbol table will be populated from the generated post-v1 DDox surface rather than guessed from source declarations.
