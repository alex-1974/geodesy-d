# geodesy-d v1.0.1 release readiness

Status: **PRE-RELEASE — RELEASE CONTENT AGREED; DOCUMENTATION QUALITY GATE OPEN**

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
  merged through PR #31.

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
- [ ] complete issue #52 and
  `docs/V1_0_1_DOCUMENTATION_QUALITY_AUDIT.md`: public Ddoc, per-symbol DDox
  examples, internal-function documentation, decision comments, and generated
  DDox human review;
- [ ] run the final Markdown/Ddoc/DDox documentation checks after remediation.

The documentation review is a release blocker by policy for v1.0.1.

## R6 — remaining repository state

Current non-v1.0.1 work must be classified before release:

- issue #17 — controlled DMD/LDC toolchain matrix;
- issue #18 — Phobos 2.111 two-argument `hypot` correctness audit.

Documentation PR #25 and roadmap PR #26 have been superseded by PR #32 and
closed.

Issue #17 may be resolved by the final controlled compiler-matrix release gate
or explicitly deferred with justification. Issue #18 requires a correctness
classification because v1 supports frontend 2.111.0 and the geodesic
implementation uses the affected `hypot` family.

## R7 — final release gate

After documentation sign-off:

- [ ] synchronize the release branch with current `main`;
- [ ] run the complete required hosted CI/platform/numerical gates on the final
  release candidate;
- [ ] run the controlled compiler matrix required by repository/workspace
  policy, or record an explicit justified exception;
- [ ] run a clean external DUB consumer against the release candidate;
- [ ] confirm clean repository/release metadata;
- [ ] convert the changelog `Unreleased` section into `1.0.1` with the actual
  release date;
- [x] create v1.0.1 release notes;
- [ ] tag `v1.0.1`;
- [ ] publish/release;
- [ ] verify the published DUB package from a fresh external consumer.

## Release decision

Current decision: **DO NOT TAG YET**.

The release-facing document structure and wording decisions have been agreed,
but source documentation quality is not yet signed off. Issue #52 is a release
blocker and requires a reader-first review of public Ddoc, a rendered
compiler-checked example for every public DDox symbol page, internal-function
documentation, rationale comments for important implementation decisions, and
human review of the generated DDox site.

Remaining blockers also include resolution/classification of outstanding
release-relevant repository state (especially #18) and the final
validation/tag/publish sequence.
