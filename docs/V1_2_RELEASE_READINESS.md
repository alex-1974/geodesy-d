# geodesy-d v1.2.0 release readiness

Status: **RELEASE CANDIDATE PREPARATION**

Tracking issue: #90.

Stable input baseline:

`v1.1.0` -> `250b8359219378773ceaad897c3fb96c0cb0ff65`

M3 completion baseline on `develop`:

`8e47b8c4cc0339fbda71a9f19e03ca9fb535de72`

Feature-freeze basis after release-metadata preparation:

`d6f49b500b15616ca396ee612fef95896405b526`

Required immutable checkpoint:

`freeze/feature-1.2.0` -> exact feature-freeze basis

## R1 — release scope

v1.2.0 is the additive M3 feature release.

Included:

- Rhumb / RhumbLine;
- Polar Stereographic;
- UPS;
- Lambert Conformal Conic 2SP;
- Lambert Azimuthal Equal Area;
- all associated public API, documentation, numerical validation, codegen,
  platform, external-consumer, and performance evidence.

Excluded:

- M4 dynamic-reference-frame work;
- M5 advanced ellipsoidal geometry;
- prolate ellipsoids;
- deferred projection families from #40;
- CRS database / authority / WKT / PROJJSON / MGRS responsibilities.

## R2 — M3 integration acceptance

- [x] #37 Rhumb/RhumbLine complete;
- [x] #38 Polar Stereographic complete;
- [x] #39 UPS complete;
- [x] #40 projection admission audit complete;
- [x] #83 LCC 2SP complete;
- [x] #84 LAEA complete;
- [x] #74 M3 integration gate complete;
- [x] controlled M3 performance baseline recorded;
- [x] aggregate six-compiler M3 release/consumer gate passed.

## R3 — feature freeze and API gate

Required before tagging:

- [x] declare exact v1.2.0 release-candidate head feature-frozen;
- [ ] no new public feature after freeze except explicit release-blocking fix;
- [ ] aggregate `import geodesy;` API contract passes on final candidate;
- [ ] strict public DDox/API-example audit passes on final candidate;
- [ ] frozen v1 public source contract remains source-compatible;
- [ ] all v1.2 aggregate exports are deliberate.

## R4 — post-freeze documentation polish

Run after the exact feature-freeze basis is declared and before the final RC
matrix.

- [ ] README release-facing overview polished;
- [ ] `docs/API.md` reconciled with all v1.2 aggregate exports;
- [ ] public module/type/function Ddoc reviewed for reader-first wording;
- [ ] compiler-checked examples reviewed for clarity and representative usage;
- [ ] terminology across Rhumb, Polar Stereographic, UPS, LCC and LAEA made
  consistent;
- [ ] stale pre-M3 status/release wording removed;
- [ ] README/API/research/validation/release-note cross-links reviewed;
- [ ] generated GitHub Pages/DDox output inspected;
- [ ] CHANGELOG and release notes polished for final publication;
- [ ] documentation-only pass introduces no public API/semantic change.

Any source correction required by this pass must rerun the affected release
gates.

## R5 — final numerical/compiler/platform gate

Required on the exact final release-candidate head:

- [ ] CI PASS;
- [ ] M3 aggregate integration gate PASS;
- [ ] PROJ differential validation PASS;
- [ ] Rhumb differential validation PASS;
- [ ] Polar Stereographic differential validation PASS;
- [ ] UPS differential validation PASS;
- [ ] LCC differential validation PASS;
- [ ] LAEA differential validation PASS;
- [ ] Geodesic platform matrix PASS;
- [ ] Transverse Mercator platform matrix PASS;
- [ ] UTM platform matrix PASS;
- [ ] Topocentric platform matrix PASS;
- [ ] Polar Stereographic platform matrix PASS;
- [ ] UPS platform matrix PASS;
- [ ] Rhumb platform matrix PASS;
- [ ] LCC platform matrix PASS;
- [ ] LAEA platform matrix PASS;
- [ ] controlled DMD 2.111.0 / 2.112.1 / 2.113.0 release/consumer lanes PASS;
- [ ] controlled LDC 1.41.0 / 1.42.0 / 1.43.0 release/consumer lanes PASS.

## R6 — release metadata

- [x] v1.2.0 release notes drafted;
- [x] v1.2.0 CHANGELOG entry drafted;
- [ ] release-facing README/ROADMAP/API references audited;
- [ ] final release candidate commit recorded;
- [ ] release date finalized.

## R7 — promotion and publication

After the exact candidate passes:

- [ ] merge release candidate to `develop` if release metadata is prepared in
  a release branch;
- [ ] promote exact release commit to `main`;
- [ ] verify `main` commit SHA;
- [ ] create annotated signed tag `v1.2.0` on the exact release commit;
- [ ] verify tag target;
- [ ] publish GitHub Release using `docs/V1_2_RELEASE_NOTES.md`;
- [ ] verify GitHub Release metadata;
- [ ] verify fresh external DUB consumer against exact `==1.2.0`;
- [ ] synchronize release state back to `develop`;
- [ ] close #90.

## Release rule

Do not move the v1.2.0 tag after publication. If a post-publication defect is
found, prepare a patch release rather than rewriting the release.


## Feature-freeze checkpoint verification

- tag object: `b66cfdae0a1cd4d786e01dbb548c6627701b9fd9`;
- tag: `freeze/feature-1.2.0`;
- peeled commit: `d6f49b500b15616ca396ee612fef95896405b526`;
- release branch derived from the same feature set.
