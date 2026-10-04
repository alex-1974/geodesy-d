# geodesy-d v1.0.1 release readiness

Status: **PRE-RELEASE — DOCUMENTATION SIGN-OFF REQUIRED**

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

- [ ] review and approve the v1.0.1 changelog wording;
- [ ] review README release/status wording;
- [ ] review `docs/API.md` introductory status/version wording;
- [ ] replace or reframe stale `ROADMAP.md` pre-v1 planning;
- [ ] decide how `docs/V1_RELEASE_READINESS.md` should be retained as a
  historical v1.0.0 record;
- [ ] decide whether `docs/V1_RELEASE_NOTES.md` remains an immutable historical
  v1.0.0 note or gains a pointer to later patch releases;
- [ ] prepare concise v1.0.1 release notes;
- [ ] run Markdown/Ddoc documentation checks after the approved edits.

The documentation review is a release blocker by policy for v1.0.1.

## R6 — remaining repository state

Current non-v1.0.1 work must be classified before release:

- issue #17 — controlled DMD/LDC toolchain matrix;
- issue #18 — Phobos 2.111 two-argument `hypot` correctness audit;
- PR #25 — historical v1.0.0 post-publish verification update;
- PR #26 — post-v1 roadmap rewrite.

These are not automatically v1.0.1 blockers. Each must either be integrated,
explicitly deferred, or documented as unrelated to the patch release.

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
- [ ] create v1.0.1 release notes;
- [ ] tag `v1.0.1`;
- [ ] publish/release;
- [ ] verify the published DUB package from a fresh external consumer.

## Release decision

Current decision: **DO NOT TAG**.

The two intended v1.0.1 fixes are merged and validated. Release-facing
documentation remains intentionally under review.
