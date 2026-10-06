# geodesy-d v1.1.0 release readiness

Status: **RELEASE CANDIDATE PREPARATION**

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
- [ ] declare the v1.1 release candidate feature-frozen;
- [ ] confirm no new public capability is added after freeze except an explicit
  release-blocking correction;
- [ ] run the aggregate public API contract on the final candidate;
- [ ] confirm the v1.0 frozen public surface remains source compatible;
- [ ] confirm all v1.1 aggregate exports are deliberate.

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

- [ ] Geodesic platform matrix PASS;
- [ ] PROJ differential validation PASS;
- [ ] Transverse Mercator platform matrix PASS;
- [ ] UTM platform matrix PASS where release policy requires it;
- [ ] Topocentric platform matrix PASS;
- [ ] no new numerical regression introduced by release-only changes.

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
- [ ] confirm no release-prep change touches the qualified numerical hot paths,
  or rerun the relevant benchmark if it does;
- [ ] record any intentional release-candidate performance reruns.

v1.1 does not require a new benchmark merely because documentation or release
metadata changes.

## R5 — documentation

Required before tagging:

- [ ] `README.md` describes the v1.1 geodesic family accurately;
- [ ] `docs/API.md` describes the complete additive v1.1 family;
- [ ] `docs/GEODESIC_FEATURE_MATRIX.md` clearly separates shipped, deferred,
  planned, and boundary capabilities;
- [ ] API documentation/DDox workflow PASS on the final candidate;
- [ ] release-facing Markdown links pass repository validation;
- [ ] `docs/V1_1_RELEASE_NOTES.md` finalized;
- [ ] `CHANGELOG.md` finalized for v1.1.0.

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

- [ ] unit tests pass under all six controlled compilers;
- [ ] release build passes under all six controlled compilers;
- [ ] aggregate public API contract passes where the harness supports it;
- [ ] candidate commit and toolchain versions are recorded.

## R7 — external consumer

Before tagging, a fresh consumer outside the repository/workspace must:

- [ ] resolve the release candidate without an unintended registry/path mix;
- [ ] compile using only public imports;
- [ ] exercise representative v1 baseline functionality;
- [ ] exercise `GeodesicQuantities!T`;
- [ ] exercise repeated `GeodesicLine!T` positions;
- [ ] exercise `GeodesicPolygonAccumulator!T`;
- [ ] build, link, and run in debug and release configurations;
- [ ] pass with the minimum DMD baseline and the selected LDC baseline;
- [ ] preferably pass the complete controlled compiler matrix.

The consumer should not import internal/package modules.

## R8 — repository and release hygiene

Before tagging:

- [ ] final release commit is on the intended release branch;
- [ ] candidate is synchronized with the accepted `develop` feature state;
- [ ] no release-only generated/build artifacts are tracked;
- [ ] no accidental research corpus has returned to the production package;
- [ ] release-facing status wording is internally consistent;
- [ ] package metadata remains correct;
- [ ] final candidate SHA is recorded;
- [ ] required hosted gates are tied to that exact SHA.

## R9 — tag and publication

After R1 through R8 are complete:

- [ ] convert the changelog Unreleased section to
  `[1.1.0] - YYYY-MM-DD`;
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

Current decision: **NOT YET RELEASED — RELEASE CANDIDATE PREPARATION**.

The M2 feature family is complete. The remaining work is release qualification,
metadata finalization, tag/publication, and post-publish verification.
