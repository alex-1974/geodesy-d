# geodesy-d v2.0.0 — release notes (candidate)

Status: **release candidate documentation, not yet published**.
The v2.0 API-freeze tag `freeze/api-2.0.0` resolves to
`97e82950bc76ade0073f2ceb39beef127fbe3b2e`.
Final release qualification and the `v2.0.0` tag remain outstanding.

## Overview

v2.0 consolidates the already implemented public geodetic mathematics after
v1.2.0. It freezes an intentional aggregate `import geodesy;` API with strong
coordinate and angle types, checked/throwing operations, prepared reusable
solvers, and explicit domain and unit contracts. There is no new capability
family added after the feature freeze.

## Notable post-v1.2.0 additions

- Ellipsoids with qualified **prolate** flattening and explicit equatorial
  versus polar radius aliases.
- Prolate-capable ellipsoidal geodesic operations within the documented
  admitted flattening interval, including advanced quantities, polygon
  accumulation and bounded nearest/intersection operations.
- Documentation and failure-state clarifications for checked coordinate
  factories and selected projection operations.

M4 reference-frame transforms, M5 bounded geodesic geometry and the M3
navigation/projection families were completed in the development line before
v2.0's feature freeze. The previously released v1.2.0 includes the M3 families;
do not describe them as newly introduced in v2.0.

## Compatibility and migration

The public API freeze followed C1/C5 audits of compiler-visible module and
own aggregate declarations, external root-import consumers and checked
failure-state contracts. The reviewed source API did **not** require a
breaking signature rename or removal. Migration instructions are in
[docs/V2_0_MIGRATION.md](V2_0_MIGRATION.md); the historical v1 public
contract remains in [docs/API.md](API.md).

The type-specific domain restrictions remain material: a prolate ellipsoid
being constructible does not imply every projection supports it.

## Recorded qualification

- M3 six-compiler + external DUB consumer + docs: runs
  [38069845425](https://github.com/alex-1974/geodesy-d/actions/runs/38069845425)
  and [38071227862](https://github.com/alex-1974/geodesy-d/actions/runs/38071227862),
  seven jobs each PASS on API-freeze SHA
  `97e82950bc76ade0073f2ceb39beef127fbe3b2e`.
- Independent prolate GeographicLib, dynamic Helmert PROJ and
  Molodensky-Badekas PROJ: runs 38056746778, 38056748277, 38056749859
  passed on the earlier feature-frozen development source.
- Controlled XPS M3 benchmarks documented in
  [docs/V2_0_NUMERICAL_PERFORMANCE_CHECKPOINT.md](V2_0_NUMERICAL_PERFORMANCE_CHECKPOINT.md).
  The LCC forward benchmark was slower than PROJ in this environment; no
  unmeasured performance improvement is claimed.

**Do not treat previous qualifying commits as proof of the final release
commit.** C9 requires exact-commit ordinary CI, platform and independent
oracle checks, generated DDox inspection, and a fresh external consumer.

## Release publication checklist

- [ ] Confirm the final exact release-candidate SHA and all C9 gates.
- [ ] Inspect generated DDox and packaged/source documentation.
- [ ] Promote the qualified candidate to `main` without introducing changes.
- [ ] Create and verify annotated `v2.0.0` tag.
- [ ] Publish a GitHub release from these verified notes.
- [ ] Confirm DUB registry resolution and clean external consumer.
- [ ] Synchronize the release result to `develop`.
