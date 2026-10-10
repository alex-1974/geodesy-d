# Migrating from geodesy-d v1.x to v2.0

Status: **pre-release guidance for the feature-frozen v2.0 branch**.
The v2 public API is **not frozen**; verify final signatures against the
released tag before upgrading. The historical v1 source contract remains
documented in [API.md](API.md).

## What stays familiar

- `import geodesy;` remains the intended public import.
- Supported scalars remain `float`, `double` and `real`, with `double`
  the general reference choice.
- Keep using `Latitude!T` and `Longitude!T` factories for angles.
- Use `GeographicCoordinate!T` for latitude/longitude **without height** and
  `GeodeticCoordinate!T` for latitude/longitude **with ellipsoidal height**.
- Keep ellipsoid axes, projected distances, XYZ and ellipsoidal heights in the
  **same linear unit** wherever operations combine them.
- Checked `try*` functions return success/failure and write an `out` result;
  throwing peers report invalid input with `GeodesyValueException`.
  A failed `out` call does **not** preserve the prior caller value.

## Additional operations on the v2 development line

The planned v2 consolidation covers the capabilities already implemented after
v1: dynamic reference-frame transforms, static Molodensky-Badekas, expanded
geodesic quantities/line/polygon/bounded geometry, prolate-qualified geodesics,
rhumb navigation and additional projections (including UTM, UPS, polar
stereographic, LCC and LAEA). Select an operation by **domain and purpose**,
not by assuming that every projection or geodesic supports all ellipsoid shapes.

- **Navigation:** geodesic for a shortest surface path; rhumb for a constant
  bearing. Prepared lines/solvers amortize repeated calculations.
- **Reference frames:** static Helmert for time-independent parameters;
  dynamic Helmert requires reference and observation epochs. Use the required
  EPSG rotation convention explicitly.
- **Projected coordinates:** projected easting/northing do not by themselves
  encode a CRS or datum. UTM's automatically selected zone differs from an
  explicit prepared zone.
- **Failure states:** check the boolean before using a checked result. Some
  carrier `.init` values are valid coordinate origins, while prepared
  operation and result carriers may use an invalid default state; consult
  the specific type contract.

## Upgrade checklist

1. Compile the current application against the candidate with
   `import geodesy;` and the supported DMD/LDC versions.
2. Confirm angular conventions, ellipsoid and linear units, epochs, and
   supported projection/geodesic domains at each call site.
3. Check that every failed `try*` return is handled before reading an
   `out` result. Do not rely on retaining a previous output value.
4. Run domain-boundary regressions relevant to the application (poles,
   antimeridian, near-antipodal paths, projection limits and epochs).
5. Review final v2 release notes for **actual** breaking changes; this
   pre-release guide does not assert that any specific signature has changed.

## Current qualification

The feature-set checkpoint is `freeze/feature-2.0.0` on
`01d2bbc1822d99ef711d5d78487597b76e650211`. API stabilization occurs
on `release/2.0`. Passing development CI and previous oracle runs does not
replace final validation on the exact released candidate.
