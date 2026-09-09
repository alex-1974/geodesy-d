# Changelog

All notable changes to `geodesy-d` will be documented here.

The project follows Semantic Versioning from the first tagged public release.

## [Unreleased]

### Added

- Strong `Angle`, `Latitude`, and `Longitude` value types.
- `Ellipsoid`, `GeodeticCoordinate`, and `GeocentricCoordinate`.
- EPSG 9602 geographic/geocentric conversion in both directions.
- EPSG 1031 geocentric translations.
- EPSG 1033 Position Vector and EPSG 1032 Coordinate Frame 7-parameter
  Helmert transformations with compile-time-explicit convention semantics.
- DMD/LDC compiler gates and release build CI.
- Public API compile contract.
- PROJ smoke and fixed-seed extended differential validation.
- ADRs for scope, type/unit semantics, Helmert conventions, and invalid
  `Ellipsoid.init` semantics.

### Changed

- `Ellipsoid.init` is an invalid sentinel rather than an arbitrary unit sphere.
- `GeocentricTranslation` parameters are read-only after checked construction.

### Validation

At the v0.1 release-audit stage, the local extended suite passes 2037 scalar
comparisons against PROJ 9.7.1, in addition to published EPSG/IOGP reference
vectors and DMD/LDC unit tests.
