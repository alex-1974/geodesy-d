# geodesy-d v1.0 release readiness

Status: **IN PROGRESS**

This document defines the release-readiness gate after the completed v1
feature freeze and public-API freeze. It is separate from API design:
`docs/V1_API_AUDIT.md` is authoritative for the frozen public contract.

No tag or release is authorized merely by completing an individual item below.

## R1 — frozen-contract baseline

- [x] v1 feature scope frozen.
- [x] V1-A through V1-I public-API audit gates passed.
- [x] V1-J final public-API freeze passed.
- [x] no open API-audit blocker recorded.

## R2 — package metadata and package contents

- [x] package name: `geodesy-d`.
- [x] MIT license declared.
- [x] minimum D frontend: `>=2.111.0`.
- [x] audit the actual DUB registry package contents using a fresh local-cache
  fetch of `geodesy-d@0.2.0` with DUB 1.40.0.
- [x] confirm release-facing package description and metadata.
- [x] accept the current registry snapshot policy for v1: the fetched package
  includes repository development material such as `research/`, `validation/`,
  `benchmarks/`, `tools/`, and documentation, while `sourcePaths "source"`
  keeps the consumer build surface restricted to production sources. The
  observed 0.2.0 fetch was about 2 MiB. This is packaging overhead, not a
  correctness or API blocker, and does not justify an unproven manifest
  filtering mechanism immediately before v1.
- [ ] verify a fresh consumer against the actual published `v1.0.0` registry
  package after publication; this is a post-publish verification item and does
  not precede creation of the tag/package.

## R3 — release-facing documentation

Current audit findings:

The initial documentation audit found stale pre-freeze status wording in
`docs/README.md`, `ROADMAP.md`, and `docs/API.md`. Those release-facing
statements have been reconciled to describe a frozen v1 release candidate
without claiming that `v1.0.0` is already tagged.

An initial tree-filter check incorrectly reported `CHANGELOG.md` absent. A
full repository-tree check confirmed that it is present and already records
0.1.x, 0.2.0, and unreleased post-0.2 work. The readiness audit corrects that
finding rather than preserving it.

Required before v1.0.0:

- [x] reconcile README/docs status with the frozen v1 scope.
- [x] reconcile ROADMAP release-policy wording for the v1 release candidate.
- [x] remove stale “unreleased” wording from the frozen v1 API reference.
- [x] verify existing `CHANGELOG.md` and prepare its v1.0.0 release-candidate entry.
- [x] prepare concise v1.0.0 release notes in `docs/V1_RELEASE_NOTES.md`.

## R4 — normal compiler and release-build gate

Required:

~~~text
DMD 2.111.0  unit tests
DMD latest   unit tests
LDC latest   unit tests
release build
public API contract
documentation contract
~~~

Local release-candidate validation on commit
`ca017a265c40004f56d8dababdec10d7cf32a325`:

~~~text
DMD 2.111.0 unit tests     PASS — 22 modules
LDC unit tests             PASS — 22 modules
DMD release build          PASS
LDC release build          PASS
public API contract        PASS
documentation contract     PASS — 24 Ddoc module files
working tree               CLEAN
~~~

The API-contract rerun followed correction of a stale validation call site that
still used the pre-V1-B UTM argument order; production API code was not changed.

The normal GitHub Actions CI already defines the hosted compiler matrix. Hosted
CI, PROJ differential validation, geodesic platform validation, and topocentric
platform validation passed on candidate
`16332a3d5221db89f5a1edd1341d4a0ed0a98a5d`.

The same candidate exposed two stale validation harnesses, not production-code
defects:

- `validation/utm_boundary_property.d` still used the pre-V1-B ellipsoid-first
  UTM free-function argument order.
- `validation/transverse_mercator_newton_validation.d` lived outside the
  `geodesy.projection` package after V1-F intentionally made Newton
  instrumentation package-internal.

Production API/library code was unchanged. The harness corrections landed in
`509d2cf8f6eb0e190167fe9bc609c668bd5f92eb` and
`ce730656b591b0ae03b38c98b59d0d1749c17bd4`.

Local validation on `ce730656b591b0ae03b38c98b59d0d1749c17bd4` passed:

~~~text
TM Newton structured / DMD 2.111.0   PASS
TM Newton structured / LDC           PASS
UTM boundary/property / DMD 2.111.0  PASS — 7,986 checks, 0 failures
UTM boundary/property / LDC          PASS — 7,986 checks, 0 failures
working tree                         CLEAN
~~~

The corrected TM hosted matrix subsequently passed on the corrected branch.
A second stale UTM-only validation call site was then found in
`validation/utm_api_runtime_validation.d`; all 13 remaining ellipsoid-first
checked/throwing UTM calls were migrated to the frozen source-first API in
`dabb607973502a93b7c7737e0f4890a6ff9e2476`. Local DMD 2.111.0 and LDC
UTM API/runtime validation both passed for float, double, and real, including
100,000 deterministic prepared/automatic repetitions per scalar.

The final UTM hosted matrix run `36236723775` passed on exactly
`dabb607973502a93b7c7737e0f4890a6ff9e2476`.

## R5 — supported platform matrix

The non-experimental v1 platform evidence is represented by the accepted
operation-specific hosted workflows:

~~~text
Linux x86_64
Linux AArch64
Windows x86_64
macOS AArch64
macOS x86_64
~~~

with LDC 1.41.0, plus the accepted DMD 2.111.0 Linux baseline and current
compiler coverage where defined.

Windows/AArch64 remains experimental/informational and is not a v1 release
blocker.

Before tagging:

- [x] run/confirm the required hosted platform workflows across the release
  candidate sequence; production source was unchanged by the validation-harness
  corrections.
- [x] confirm all required matrix jobs pass. Windows/AArch64 remains explicitly
  experimental/informational and is not used to waive a required target.

## R6 — independent numerical validation

The accepted validation programs remain part of release evidence, not runtime
dependencies.

Before tagging:

- [x] confirm required PROJ/differential validation on candidate `16332a3...`.
- [x] confirm Transverse Mercator validation on the corrected branch after
  `ce730656...`; hosted TM platform matrix PASS.
- [x] confirm UTM validation on `dabb607...`; hosted run `36236723775`
  PASS.
- [x] confirm topocentric validation on candidate `16332a3...`.
- [x] confirm geodesic validation on candidate `16332a3...`.
- [x] retain run/commit provenance for the release decision: the original
  hosted validation set is tied to `16332a3...`; TM harness correction to
  `ce730656...`; final UTM matrix run `36236723775` to
  `dabb607973502a93b7c7737e0f4890a6ff9e2476`.

## R7 — clean external consumer

The API audit already passed path-based external consumers with DMD 2.111 and
LDC, including aggregate imports, named arguments, direct module imports,
debug/release builds, and execution.

Release readiness additionally requires:

- [ ] build from the package artifact/registry candidate rather than the local
  repository path.
- [ ] exercise `import geodesy;` from a fresh consumer.
- [ ] run with the minimum frontend.
- [ ] run with LDC/current supported toolchain.

## R8 — repository and release hygiene

Before tagging:

- [ ] working tree/release commit is clean and reproducible.
- [ ] no release-only generated artifacts are accidentally tracked.
- [ ] release-facing links and documentation paths resolve.
- [ ] version/release notes agree on `v1.0.0`.
- [x] corrected validation candidate recorded as `dabb607973502a93b7c7737e0f4890a6ff9e2476`; final tag SHA remains contingent on remaining release-readiness documentation/hygiene commits.
- [ ] tag `v1.0.0` only after all mandatory gates pass.
- [ ] verify the published DUB package from a fresh consumer after publication (post-publish verification; also tracked by R2/R7).

## Release decision

Current decision: **NOT YET READY TO TAG**.

The public API is frozen and R1 through R6 are complete for the pre-tag
release-readiness sequence. Remaining pre-tag work is the clean external
consumer/release-artifact path in R7 and final repository/release hygiene in
R8. The actual tag/release remains a separate explicit action. Post-publish
registry verification remains intentionally deferred until a v1.0.0 package
exists.
