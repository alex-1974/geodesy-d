# Changelog

All notable changes to `geodesy-d` will be documented here.

The project follows Semantic Versioning from the first tagged public release.

## [Unreleased]

### Added

- Prepared Karney-family `Geodesic!T` solver for direct and inverse surface
  geodesics on spheres and supported oblate ellipsoids (`0 <= f <= 0.01`).
- Public `GeodesicDirectResult!T` and `GeodesicInverseResult!T` APIs for
  `float`, `double`, and platform `real`, exported through `import geodesy;`.
- Robust inverse handling for coincident, meridional, equatorial, short-line,
  near-antipodal, antipodal, polar, and general Newton/bracketed cases.
- Canonical public geodesic angle semantics using `[-pi,+pi)`, including
  canonical positive zero and representation-independent coincident inverse
  results.
- GeographicLib 2.7 `GeodesicExact` differential research harnesses for direct,
  canonical inverse-dispatch, and public inverse validation.
- ADR-0008 and the ellipsoidal geodesic validation plan.
- Bounded generic Transverse Mercator projection for `float`, `double`, and
  platform `real`.
- Universal Transverse Mercator policy layer with strong zone and hemisphere
  types, prepared projections, tagged coordinates, automatic standard-zone
  forward projection, and explicit tagged reverse projection.
- Standard Norway and Svalbard UTM zone exceptions.
- Independent Transverse Mercator validation against exact GeographicLib
  references and PROJ.
- Independent UTM semantic validation against GeographicLib and represented-
  model numerical differential validation against PROJ 9.7.1.
- Multi-platform Transverse Mercator and UTM validation matrices covering
  Linux, Windows, and macOS with DMD and LDC where supported.
- ADR-0006 for bounded Transverse Mercator and ADR-0007 for UTM policy.

## [0.1.1] - 2026-09-13

### Fixed

- Replace the inherited `d-geospatial` workspace README with the
  package-specific `geodesy-d` README used by GitHub and the DUB registry.

## [0.1.0] - 2026-09-09

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
