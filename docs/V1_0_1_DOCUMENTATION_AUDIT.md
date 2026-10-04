# geodesy-d v1.0.1 documentation audit

Status: **DRAFT FOR DISCUSSION**

This document records documentation questions that should be resolved before
v1.0.1. It is not itself normative public API documentation.

## 1. ROADMAP.md is materially stale

The current roadmap still presents `v0.2.0` as the released line and describes
work toward `v1.0.0`, even though v1.0.0 was released on 2026-09-26.

A post-v1 rewrite already exists in PR #26, but that branch predates subsequent
main changes and should not be merged mechanically.

Decision required:

- replace the old pre-v1 roadmap with a compact post-v1 roadmap;
- retain the old planning text only in git history rather than in the current
  roadmap;
- define current milestones around post-v1 baseline cleanup, consumer/gap
  audit, and evidence-driven v1.1 work.

Recommended direction: adopt the structure of PR #26 after rebasing its content
conceptually onto current main.

## 2. docs/V1_RELEASE_READINESS.md is historically valuable but temporally stale

The document still says:

~~~text
Status: PRE-TAG READY
Current decision: PRE-TAG GATES COMPLETE; FINAL TAG ACTION NOT YET AUTHORIZED
~~~

That was correct immediately before v1.0.0, but is false as a statement of
current repository state.

Decision required:

- preserve it as an immutable historical release record and change only its
  heading/status framing to make that explicit; or
- replace it with a post-publish-complete historical record based on PR #25.

Recommended direction: retain the file as a v1.0.0 historical record, update
its status to released/post-publish verified, and avoid using it as the active
v1.0.1 checklist. The new `V1_0_1_RELEASE_READINESS.md` should be authoritative
for the patch release.

## 3. docs/V1_RELEASE_NOTES.md

The v1.0.0 release notes are valid historical release notes.

Decision required:

- keep them immutable apart from clearly historical framing; or
- add a small navigation pointer to the changelog / later releases.

Recommended direction: keep the actual v1.0.0 content immutable. Do not rewrite
historical release notes to describe v1.0.1.

## 4. docs/API.md version/status framing

The detailed API content should remain authoritative for the frozen v1 API, but
introductory language should not imply an unreleased or pre-freeze state.

Review required:

- release/version labels;
- references to “current unreleased development line” or similar wording;
- distinction between “frozen v1 API” and “exact v1.0.0 implementation state”;
- failure semantics now corrected in source Ddoc.

Recommended direction: describe the document as the stable v1 API baseline,
not as a v1.0.0 snapshot. Patch releases may correct implementation and
documentation defects without changing that API baseline.

## 5. README.md

The README is already much closer to current reality than ROADMAP.md, but the
release-facing pass should verify:

- v1.0.0/v1.x status wording;
- minimum frontend 2.111.0;
- public feature list matches the frozen v1 surface;
- documentation links point to current documents;
- wording around validation does not overclaim the exact compiler matrix;
- responsibility boundaries remain aligned with the workspace.

Recommended direction: make the README describe the stable v1 line, not one
specific patch version except where installation/version examples require it.

## 6. CHANGELOG.md

The v1.0.1 `Unreleased` draft should contain only patch-release material:

- TM boundary unit-invariance correctness fix;
- corrected public `out` failure-semantics documentation.

Before release, convert `Unreleased` to `1.0.1` with the actual date.

No v1.1 roadmap or toolchain work should be mixed into the patch changelog.

## 7. Old open documentation PRs

PR #25 and PR #26 both predate the current main history.

Recommended handling:

- do not merge them directly;
- reuse their validated content where still correct;
- close them as superseded once equivalent current-main documentation changes
  are merged.

## 8. Documentation sign-off questions

Before v1.0.1, explicitly agree on:

1. Is `ROADMAP.md` a current planning document only, with old plans left to git
   history?
2. Should v1.0.0 readiness be kept as a historical record or rewritten to its
   final post-publish state?
3. Should `docs/API.md` target the entire stable v1 API line rather than a
   specific patch release?
4. Should release notes remain immutable per release, with later fixes only in
   new release notes and CHANGELOG?
5. How much validation/toolchain detail belongs in README versus dedicated
   validation/readiness documents?

No final release should occur until these questions are resolved.
