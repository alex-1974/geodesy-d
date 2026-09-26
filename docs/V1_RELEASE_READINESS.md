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
- [ ] audit DUB package contents for unintended research/validation/repository files. Repository inspection shows extensive `research/`, `validation/`, `tools/`, `docs/`, and CI content; the actual DUB package artifact still needs inspection rather than assuming repository presence equals publication.
- [ ] verify a clean packaged/fetched consumer rather than only a path dependency.
- [x] confirm release-facing package description and metadata.

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
- [ ] prepare concise v1.0.0 release notes.

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

The normal GitHub Actions CI already defines this matrix. The release candidate
must have a green run on the exact candidate commit.

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

- [ ] run/confirm the required hosted platform workflows on the release
  candidate commit.
- [ ] confirm no required matrix job is skipped or allowed to fail.

## R6 — independent numerical validation

The accepted validation programs remain part of release evidence, not runtime
dependencies.

Before tagging:

- [ ] confirm required PROJ/differential validation on the release candidate.
- [ ] confirm Transverse Mercator validation.
- [ ] confirm UTM validation.
- [ ] confirm topocentric validation.
- [ ] confirm geodesic validation.
- [ ] retain exact run/commit provenance for the release decision.

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
- [ ] final candidate commit SHA is recorded.
- [ ] tag `v1.0.0` only after all mandatory gates pass.
- [ ] verify the published DUB package from a fresh consumer after publication.

## Release decision

Current decision: **NOT YET READY TO TAG**.

The public API is frozen, but release-facing documentation/package hygiene and
candidate-commit validation remain open. These tasks must preserve the frozen
v1 public contract unless a concrete correctness or compatibility defect
requires an explicit freeze-reopening decision.
