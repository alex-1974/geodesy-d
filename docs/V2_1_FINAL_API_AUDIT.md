# v2.1.0 final API and release-gate audit

Status: **release candidate under qualification**, not a release sign-off.

## API review (source review, 2026-10-11)

Reviewed `source/geodesy/projection/equal_earth.d`,
`source/geodesy/projection/internal/equal_earth_kernel.d` and
`docs/API.md` on `develop`.

- Public prepared `EqualEarth!T`: `float`, `double`, `real`.
  Internals use **double** for all three. No extended `real` precision
  guarantee.
- Supported ellipsoid range: sphere through terrestrial **oblate**
  `0 <= flattening <= 0.01`. Prolate input is rejected at the
  checked factory.
- Parameters: explicit central meridian, false easting/northing, and
  ellipsoid axis linear units; no implicit CRS database or unit conversion.
- Longitude is canonicalized into a half-open range at the antimeridian.
  This is a representation decision, not an exact preservation of
  input longitude spelling.
- `tryFromParameters`, `tryForward`, `tryReverse` are declared
  `pure nothrow @safe @nogc`; throwing peers use
  `GeodesyValueException`. Checked `out` values are reset on entry,
  so callers must not rely on prior contents on failure.
- Public `import geodesy;` export and standalone six-compiler
  consumer have passed PR qualification. No additional public API
  introduced by inverse Newton optimization.
- Inverse polynomial has a bounded 72-step loop; inverse authalic
  latitude uses safeguarded Newton with a 65-step bisection fallback.
  Expanded polar and antimeridian grid plus ARM64 platform tests pass.

This is a **source/API contract review**, not a proof of exhaustive
floating-point behavior or allocation-free machine code.

## Evidence and remaining gates

- PR #143 head `41dcf1ac9141261218e9cd64f2e39b6f499e64bf`:
  **10/10 triggered workflows PASS**.
- XPS measured reverse median speedup: **4.24x DMD 2.111.0**,
  **3.76x LDC 1.41.0**, on the specified four-location corpus.
- PR #144 documentation head `4f5b35162fb3898ef8aea97788ec10c437e6298c`:
  **3/3 triggered workflows PASS**.
- Pinned six-compiler `release-compiler-consumer.yml` runs on
  pull requests targeting `main`; these are separate from routine
  `develop` CI. This candidate PR must establish qualification of
  the **actual candidate SHA**.
- **Open**: inspect DMD/LDC release assembly and characterize allocation
  behavior of the complete checked call chain. Declarations of
  `@nogc` establish a compiler-enforced GC allocation constraint,
  but are not an independent assembly inspection of all runtime calls.
- **Open**: exact release-candidate GitHub Actions, freeze checkpoints,
  publication, registry consumer and workspace-wide issue #17 acceptance.

Do not publish a release or assert freeze completion while these gates
remain unverified. Any follow-up actions must modify **geodesy-d only**.
