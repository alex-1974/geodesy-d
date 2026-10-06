# geodesy-d v1.1.0 release readiness

Status: **RELEASE METADATA FINALIZATION**

This checklist is specific to v1.1.0. It follows the completed v1.0.0 and
v1.0.1 release records and preserves the frozen v1 compatibility baseline.

Tracking issue: #71.

## R1 — release scope

v1.1.0 is the first additive feature release after v1.0.x.

Included:

- `GeodesicQuantities!T` with reduced length `m12`, geodesic scales
  `M12/M21`, and signed segment area `S12`;
- additive checked direct/inverse quantity overloads;
- prepared `GeodesicLine!T` for repeated distance positions;
- streaming `GeodesicPolygonAccumulator!T` and
  `GeodesicPolygonResult!T`;
- documentation, validation, regression, and performance evidence required by
  the completed M2 gate.

Excluded:

- arc-mode `GeodesicLine` positions;
- longitude-unrolled line output;
- advanced line-position quantities;
- prolate ellipsoids;
- geodesic intersections;
- nearest/cross-track/along-track queries;
- rhumb lines;
- polygon topology, holes, containment, and overlay.

The exclusion list is tracked by `docs/GEODESIC_FEATURE_MATRIX.md` and the
post-v1.1 roadmap. None of those items is a v1.1 release blocker.

## R2 — feature freeze and API gate

Required before tagging:

- [x] M2 issues #33, #34, #35, and integration gate #36 complete;
- [x] post-M2 capability audit merged;
- [x] declare the v1.1 release candidate feature-frozen;
- [x] confirm no new public capability is added after freeze except an explicit
  release-blocking correction;
- [x] run the aggregate public API contract on the final candidate;
- [x] confirm the v1.0 frozen public surface remains source compatible;
- [x] confirm all v1.1 aggregate exports are deliberate.

The expected additive geodesic family is:

~~~text
Geodesic!T
├── GeodesicQuantities!T
├── GeodesicLine!T
├── GeodesicPolygonAccumulator!T
└── GeodesicPolygonResult!T
~~~

## R3 — numerical and semantic acceptance

Accepted M2 evidence already includes:

- [x] independent GeographicLib 2.7 validation for advanced direct/inverse
  quantities;
- [x] independent GeographicLib 2.7 distance-mode `GeodesicLine` oracle;
- [x] independent GeographicLib 2.7 PolygonArea oracle;
- [x] antimeridian, pole, winding, nearly-degenerate, sphere, flattening-boundary,
  and scaled-ellipsoid polygon evidence;
- [x] DMD/LDC and platform-`real` validation during M2 integration;
- [x] checked `pure nothrow @safe @nogc` hot-path contracts where specified.

Required on the final release candidate:

- [x] Geodesic platform matrix PASS;
- [x] PROJ differential validation PASS;
- [x] Transverse Mercator platform matrix PASS;
- [x] UTM platform matrix PASS where release policy requires it;
- [x] Topocentric platform matrix PASS;
- [x] no new numerical regression introduced by release-only changes.

## R4 — performance gate

Accepted prepared-line evidence:

~~~text
repeated Geodesic.tryDirect        357.482910 ns/op
prepared GeodesicLine.tryPosition  182.426453 ns/op
speedup                             1.960x
latency reduction                   48.97 %
~~~

Required before tagging:

- [x] accepted M2 line-performance qualification retained in
  `docs/PERFORMANCE.md`;
- [x] confirm no release-prep change touches the qualified numerical hot paths,
  or rerun the relevant benchmark if it does;
- [x] record any intentional release-candidate performance reruns — none required; release-prep changes do not touch qualified hot paths.

v1.1 does not require a new benchmark merely because documentation or release
metadata changes.

## R5 — documentation

Required before tagging:

- [x] `README.md` describes the v1.1 geodesic family accurately;
- [x] `docs/API.md` describes the complete additive v1.1 family;
- [x] `docs/GEODESIC_FEATURE_MATRIX.md` clearly separates shipped, deferred,
  planned, and boundary capabilities;
- [x] API documentation/DDox workflow PASS on the final candidate;
- [x] release-facing Markdown links pass repository validation;
- [x] `docs/V1_1_RELEASE_NOTES.md` finalized;
- [x] `CHANGELOG.md` finalized for v1.1.0.

## R6 — controlled compiler matrix

The release candidate must pass the workspace-controlled compiler set:

~~~text
DMD 2.111.0
DMD 2.112.1
DMD 2.113.0
LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
~~~

Required:

- [x] unit tests pass under all six controlled compilers;
- [x] release build passes under all six controlled compilers;
- [x] aggregate public API contract passes where the harness supports it;
- [x] candidate commit and toolchain versions are recorded.

## R7 — external consumer

Before tagging, a fresh consumer outside the repository/workspace must:

- [x] resolve the release candidate without an unintended registry/path mix;
- [x] compile using only public imports;
- [x] exercise representative v1 baseline functionality;
- [x] exercise `GeodesicQuantities!T`;
- [x] exercise repeated `GeodesicLine!T` positions;
- [x] exercise `GeodesicPolygonAccumulator!T`;
- [x] build, link, and run in debug and release configurations;
- [x] pass with the minimum DMD baseline and the selected LDC baseline;
- [x] pass the complete controlled compiler matrix.

The consumer should not import internal/package modules.

## R8 — repository and release hygiene

Before tagging:

- [ ] final release commit is on the intended release branch;
- [x] candidate is synchronized with the accepted `develop` feature state;
- [x] no release-only generated/build artifacts are tracked;
- [x] no accidental research corpus has returned to the production package;
- [x] release-facing status wording is internally consistent;
- [x] package metadata remains correct;
- [x] final candidate SHA is recorded;
- [x] required hosted gates are tied to that exact SHA.

## R9 — tag and publication

After R1 through R8 are complete:

- [x] convert the changelog Unreleased section to
  `[1.1.0] - 2026-10-06`;
- [ ] finalize release notes;
- [ ] create tag `v1.1.0` from the accepted release commit;
- [ ] publish the GitHub release;
- [ ] confirm DUB registry publication.

## R10 — post-publish verification

From a fresh environment:

- [ ] resolve `geodesy-d` exactly to `1.1.0` with no local path override;
- [ ] build/link/run an aggregate-import consumer;
- [ ] build/link/run representative v1.1 geodesic usage;
- [ ] verify with DMD and LDC in debug and release mode;
- [ ] record the published package/version evidence;
- [ ] mark issue #71 complete.

## Release decision

Current decision: **FEATURE-FROZEN — RELEASE CANDIDATE QUALIFICATION IN PROGRESS**.

The M2 feature family is complete and feature-frozen at develop commit
`eb96b3c9f7278655e2f7986d6135fccc59a0abef`. No new public capability is
admitted after this point except an explicit release-blocking correction.
The remaining work is release qualification, metadata finalization,
tag/publication, and post-publish verification.


## Qualified release candidate evidence

Exact release-candidate head:

`83d589c4e357ac7fd60ba6e2b5b9583978fefccd`

All release-relevant hosted gates passed on that exact head:

~~~text
CI                                   PASS
API documentation                    PASS
PROJ differential validation         PASS
Geodesic platform matrix             PASS
UTM platform matrix                  PASS
Transverse Mercator platform matrix  PASS
Topocentric platform matrix          PASS
Release compiler and consumer gate   PASS
~~~

The controlled release gate passed all six pinned compilers:

~~~text
DMD 2.111.0
DMD 2.112.1
DMD 2.113.0
LDC 1.41.0
LDC 1.42.0
LDC 1.43.0
~~~

For every compiler the gate completed unit tests, release build, public API
contract validation, and the external DUB consumer in debug and release mode.
The consumer exercises v1 baseline use plus `GeodesicQuantities!T`, repeated
`GeodesicLine!T` positions, and `GeodesicPolygonAccumulator!T`.

The only failed release-gate attempt before this head was infrastructural:
the consumer script lacked an executable file mode when created through the
GitHub Contents API. The workflow was corrected to invoke it through `bash`;
no production source changed.

This candidate is therefore technically qualified for merge to `main`.
Tagging, publication, and post-publish registry verification remain separate
release actions.
