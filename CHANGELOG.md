# Changelog

All notable changes to `geodesy-d` will be documented here.

The project follows Semantic Versioning from the first tagged public release.

## [Unreleased]

## [1.0.0] - 2026-09-26

### Added

- Public `TopocentricCoordinate!T` and prepared `TopocentricFrame!T` for
  `float`, `double`, and platform `real`.
- EPSG 9836 geocentric/topocentric East-North-Up conversion in both directions.
- EPSG 9837 geodetic/topocentric conversion in both directions using shared
  working-precision EPSG 9602/9836 kernels.
- Geodetic-origin and geocentric-origin frame construction with explicit pole,
  rotation-axis, geocentre, and canonical interior semantics.
- ADR-0009 and the topocentric validation program.
- Public `ConformalProjectionFactors!T` result type with strong
  `Angle!T` meridian convergence and dimensionless point scale.
- Checked and throwing conformal-factor operations on prepared
  `TransverseMercator!T` and `UtmProjection!T` projections.
- ADR-0011 defining conformal projection-factor semantics, reverse
  representation policy, pole convention, and UTM delegation.

### Changed

- Added bounded EPSG method 1024 `PseudoMercator!T` with checked/throwing
  construction and forward/reverse operations.
- Completed the explicit v1 public-API audit and froze names, signatures,
  parameter names/order, module boundaries, default-state semantics, failure
  channels, scalar/unit/domain contracts, and aggregate exports.

### Validation

- Completed TOPO-A through TOPO-G.
- Reproduced the published EPSG/IOGP 9836/9837 worked vectors.
- Completed deterministic 100,000-case-per-public-path differential validation
  against PROJ and independent GeographicLib `LocalCartesian` validation.
- Completed adversarial/failure, public API/runtime, DMD/LDC, hosted
  Linux/Windows/macOS, and platform-`real` validation.
- Exercised the complete PROJ differential corpus with `real` on every hosted
  target where `real` is wider than `double`, including Linux AArch64 with a
  113-bit mantissa.
- Validated Transverse Mercator meridian convergence and point scale against
  GeographicLib and the independent analytic spherical model under DMD and LDC.
- Validated reverse factors at the accepted post-policy working point for
  `double` and `float`, including independently generated binary32 projected
  inputs and representation-aware +/-60-degree boundary behavior.
- Confirmed exact UTM-to-Transverse-Mercator factor delegation for prepared
  projections and compile-time exclusion of `ProjectionFactorResearch` entry
  points from normal public builds.

## [0.2.0] - 2026-09-19

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
- Reproducible geodesic profiling and same-process GeographicLib/PROJ
  reference benchmarking, including explicit CPU/SMT environment reporting.

### Changed

- Reconciled repository documentation with `d-geospatial-workspace` after the
  workspace reorganization.
- Replaced the inherited workspace roadmap and design-principles snapshot with
  `geodesy-d`-specific project documents.
- Clarified the package minimum D frontend as 2.111.0 independently of the
  surrounding workspace toolchain.
- Recorded current sibling-library boundaries without changing the
  `geodesy-d` numerical or public-API scope.
- Specialized fixed-order geodesic C1, C1p, and C2 series evaluation at
  compile time without changing the accepted numerical semantics.

### Validation

- Completed the GEO-A through GEO-G geodesic acceptance program.
- Validated the accepted geodesic slice across Linux, Windows, and macOS with
  DMD and LDC where supported.
- Retained independent differential validation against GeographicLib 2.7 and
  PROJ 9.7.1.
- Confirmed the geodesic series specialization with identical numerical
  preflight output and controlled paired A/B measurements.

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
