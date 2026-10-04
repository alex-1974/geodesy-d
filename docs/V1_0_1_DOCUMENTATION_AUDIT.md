# geodesy-d v1.0.1 documentation audit

Status: **RELEASE-CONTENT DECISIONS COMPLETE — SOURCE QUALITY AUDIT OPEN**

This document records the documentation decisions made during v1.0.1 release
preparation. It is not normative public API documentation.

## 1. ROADMAP.md

Decision: the roadmap is a current planning document.

The stale pre-v1 plan has been replaced with a post-v1 milestone structure.
Historical planning remains in git history.

The active sequence is:

~~~text
M1    Post-v1 Baseline
M1.1  v1.0.1 Hotfix
M2    Geodesic Core Completion
M3    Navigation & Polar Geodesy
M4    Reference Frames
M5    Advanced Ellipsoidal Geometry
M6    Physical Geodesy Research
~~~

Milestones express preferred development order, not a hard dependency graph.

## 2. docs/V1_RELEASE_READINESS.md

Decision: retain the file as the historical v1.0.0 release record and update it
to the actual final post-publish state.

The record now states that v1.0.0 was released and that post-publish DUB
registry/external-consumer verification completed successfully. It is not the
active checklist for v1.0.1.

## 3. docs/V1_RELEASE_NOTES.md

Decision: keep the v1.0.0 release notes historical.

Later patch releases receive their own release notes rather than rewriting the
v1.0.0 note.

v1.0.1 therefore uses:

~~~text
docs/V1_0_1_RELEASE_NOTES.md
~~~

## 4. docs/API.md

Decision: `docs/API.md` documents the stable v1 API baseline, not an exact
v1.0.0 implementation snapshot.

Compatible v1.x patch/minor work may correct defects or add compatible public
capability while preserving the frozen v1 source-compatibility baseline.

Stale pre-v1/v0.1 framing has been removed.

## 5. README.md

Decision: README is the repository entry page, not a technical design or
validation document.

It is intentionally limited to:

- what `geodesy-d` is;
- a concise capability list;
- a short design teaser;
- installation;
- one representative public-API example;
- links to detailed documentation;
- license.

The teaser may state supported, verifiable characteristics such as
dependency-light pure D, strong typing, safety-oriented checked APIs,
performance-conscious prepared numerical objects, and independent numerical
validation. Broad unqualified claims such as “high-performance” or
“ownership-safe” are avoided unless separately demonstrated and defined.

## 6. CHANGELOG.md

Decision: the v1.0.1 entry contains patch-release material only:

- Transverse Mercator reverse-boundary unit-invariance correctness fix;
- correction of public Ddoc for D `out` failure semantics;
- explicit statement that the frozen v1 public source contract is preserved.

Before tagging, `Unreleased` must be converted to `1.0.1` with the actual
release date.

## 7. Old documentation PRs

PR #25 and PR #26 were not merged directly because both predated current main.

Their still-valid content was incorporated into PR #32 and both PRs were closed
as superseded.

## 8. Documentation sign-off

The release-facing content decisions are complete:

1. ROADMAP is current-only planning: **yes**.
2. v1.0.0 readiness is a completed historical release record: **yes**.
3. `docs/API.md` targets the stable v1 API line: **yes**.
4. release notes remain per-release historical documents: **yes**.
5. README contains only entry-page information and a concise, supportable
   project teaser; detailed validation/toolchain material stays in dedicated
   documents.

Release-content decisions are complete, but documentation quality is not yet
signed off.

The remaining source-level work is tracked by issue #52 and
`docs/V1_0_1_DOCUMENTATION_QUALITY_AUDIT.md`. It includes:

- reader-first public Ddoc review;
- a rendered compiler-checked Example for every public DDox symbol page;
- internal non-trivial function documentation;
- rationale comments for important implementation decisions;
- human review of the generated DDox site;
- final strict documentation tooling.

This work is a v1.0.1 release blocker, not merely a mechanical formatting
check.
