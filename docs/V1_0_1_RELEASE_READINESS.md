# geodesy-d v1.0.1 release readiness

Status: **PRE-RELEASE — DOCUMENTATION GATE COMPLETE; FINAL VALIDATION OPEN**

This checklist is specific to v1.0.1. It does not replace the historical
v1.0.0 release-readiness record.

No v1.0.1 tag or release is authorized until every mandatory item below is
complete and the release-facing documentation has been reviewed explicitly.

## R1 — scope

v1.0.1 is a narrow compatibility/correctness release.

Included:

- Transverse Mercator reverse-boundary unit invariance, tracked by #27 and
  merged through PR #29;
- correction of public Ddoc for D `out` failure semantics, tracked by #28 and
  merged through PR #31;
- Phobos/DMD 2.111 two-argument `hypot` correctness fix, tracked by #18 and
  merged through PR #51;
- documentation-quality hardening through PR #53 and DDox visibility fix
  through PR #54.

Excluded:

- new v1.1 capabilities;
- new public API;
- unrelated numerical or performance experiments;
- workspace-wide toolchain changes.

## R2 — frozen API

- [x] no frozen public v1 symbol added, removed, or renamed by the v1.0.1 fixes;
- [x] no public signature, argument order, parameter name, or failure channel
  changed;
- [x] checked `out` documentation now reflects D semantics rather than changing
  runtime behavior.

## R3 — numerical correctness

TM unit-invariance hotfix final merge:

~~~text
PR #29
merge c57c8f00891aecd367d62e9d9dc0061f7f2e8b34
~~~

Required evidence:

- [x] metre/kilometre boundary regression present;
- [x] CI PASS;
- [x] API documentation PASS;
- [x] PROJ differential validation PASS;
- [x] Transverse Mercator platform matrix PASS;
- [x] UTM platform matrix PASS;
- [x] Geodesic platform matrix PASS;
- [x] Topocentric platform matrix PASS.

The final hotfix normalization preserves the accepted v1 terrestrial boundary
tolerance envelope and avoids the transient float-boundary regression found
during PR review.

## R4 — documentation correction

Public `out` semantics correction final merge:

~~~text
PR #31
merge c262fc85b1e04f1e0eb882665c3d6331833763c0
~~~

Evidence:

- [x] 34 incorrect public Ddoc statements corrected;
- [x] 11 public source modules audited and updated;
- [x] CI PASS;
- [x] API documentation PASS;
- [x] all operation-specific platform matrices PASS;
- [x] no runtime/API change introduced.

## R5 — release-facing documentation

Mandatory before tagging:

- [x] review and approve the v1.0.1 changelog wording;
- [x] simplify README as the repository entry page and review its public
  positioning;
- [x] frame `docs/API.md` as the stable v1 API baseline;
- [x] replace stale pre-v1 `ROADMAP.md` planning with the agreed post-v1
  milestone structure;
- [x] retain `docs/V1_RELEASE_READINESS.md` as a completed historical v1.0.0
  release record;
- [x] keep `docs/V1_RELEASE_NOTES.md` as the historical v1.0.0 release notes;
- [x] prepare `docs/V1_0_1_RELEASE_NOTES.md`;
- [x] complete issue #52, including human visual review of the generated DDox
  site;
- [x] public Ddoc, 211/211 own DDox examples, internal-function Ddoc,
  decision-comment review, source-aware public-only filtering, and strict
  documentation tooling complete;
- [x] final Ddoc/DDox documentation workflow green on `main` after PR #54.

The documentation-quality gate is complete for v1.0.1.

## R6 — remaining repository state

Release-relevant repository state is classified:

- issue #17 — controlled DMD/LDC toolchain matrix: deferred as broader
  workspace/M1 standardization; not a v1.0.1 patch-release blocker;
- issue #18 — Phobos 2.111 two-argument `hypot` correctness audit: resolved
  by PR #51.

Documentation PR #25 and roadmap PR #26 have been superseded by PR #32 and
closed.

Issue #17 remains open for the broader controlled-toolchain acceptance work.
The v1.0.1 candidate still must pass the repository's required compiler and
platform gates. Issue #18 is no longer a blocker.

## R7 — final release gate

After documentation sign-off:

- [x] synchronize the release branch with current `main`;
- [x] confirm the complete required hosted CI/platform/numerical evidence for
  the final candidate: the full PROJ/TM/UTM/geodesic/topocentric matrix passed
  on `5714fe7772dc409de489b3eb7ac9e4f8d484f5e1`, and no production source has
  changed since that commit; current PR #32 CI and API documentation are also
  green;
- [x] run the controlled six-compiler matrix required by repository/workspace
  policy (DMD 2.111.0/2.112.1/2.113.0 and LDC 1.41.0/1.42.0/1.43.0): all six
  passed 24-module unit tests and release builds on candidate
  `d919125f6858f46bfed1f57d926e1cb1ca84a4a1`;
- [x] run a clean external DUB consumer against the release candidate: the
  representative aggregate-import/UTM/geodesic consumer built, linked, and ran
  successfully in both debug and release mode with all six controlled
  compilers;
- [ ] confirm clean repository/release metadata;
- [ ] convert the changelog `Unreleased` section into `1.0.1` with the actual
  release date;
- [x] create v1.0.1 release notes;
- [ ] tag `v1.0.1`;
- [ ] publish/release;
- [ ] verify the published DUB package from a fresh external consumer.

## Release decision

Current decision: **DO NOT TAG YET**.

The release-facing document structure and full documentation-quality gate are
complete. Issue #52 is closed after automated verification and maintainer visual
review of the generated DDox site.

Issue #18 is resolved. Issue #17 is explicitly deferred from the patch-release
scope. The hosted numerical/platform evidence, controlled six-compiler matrix, and
clean external consumer gate are complete. The production source is identical
to the fully green `5714fe7...` candidate, and the current documentation-only
PR head passes CI and API documentation. The remaining pre-tag work is final
release metadata/repository confirmation, including converting the changelog
section to v1.0.1 with the release date. Tagging and publication remain
separate explicit actions.
