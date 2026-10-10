# v2.0 numerical and performance qualification: bounded execution plan

Status: **pre-release planning**, not a release qualification or freeze sign-off.

## Principle

Reuse established M3/M4/M5 and public API gates. Do not reproduce completed
research or invent release performance numbers from hosted CI. Add or repair
tests only when there is a specific regression, missing boundary, or known
consumer failure.

## Existing evidence and reusable gates

| Area | Existing starting point | v2 action |
| --- | --- | --- |
| General numerical tests | `dub test --force` in regular CI | Rerun on exact release candidate. |
| Public API | `tools/validate-api.sh` and v2 package-root smoke | Rerun on exact release candidate. |
| Six compilers + fresh DUB consumer | `.github/workflows/m3-integration.yml` | Reuse its manually dispatchable gate on v2 candidate; record run IDs. |
| Independent numerical oracles | `docs/VALIDATION.md` and family-specific validators | Verify covered families and rerun applicable validators on candidate. |
| M3 performance | `tools/benchmark-m3.sh` and `docs/M3_INTEGRATION_GATE.md` | Run on controlled machine; compare with its pinned historical baseline. |
| M4 transforms | `docs/M4_INTEGRATION_GATE.md` | Carry forward accepted reference-frame evidence; rerun affected regressions. |

## Minimal execution order

1. **Pin candidate commit and compiler versions.** Record full SHA, operating
   system, compiler and DUB versions; do not reuse historic PASS as proof of a
   new commit.
2. **Re-run ordinary and six-compiler gates.** Any failure is a release blocker
   until classified. The existing six-compiler workflow is *not* automatically
   triggered by arbitrary v2 changes; dispatch it explicitly and retain links.
3. **Numerical review by risk, not test count.** Check existing coverage for
   poles, antimeridian, near-antipodal geodesics, sphere/prolate boundaries,
   projection accepted-domain limits, epoch/reference semantics and
   float/double/platform-real. Add focused regressions only for an identified
   hole. Use existing independent reference vectors and oracles.
4. **Performance on controlled hardware.** Preserve recorded governor, turbo,
   CPU affinity, compiler, dependency versions and exact commit. Start with M3
   public hot paths; compare prepared/one-shot variants only where existing
   fixtures support it. Investigate only material, repeatable regressions.
5. **Release checkpoint.** Keep a compact evidence table with exact command,
   run/artifact, SHA, result and blocker disposition.

## Commands to run on a qualifying checkout

```bash
git rev-parse HEAD
dub test --force --compiler=dmd
dub test --force --compiler=ldc2
dub build --build=release --force --compiler=ldc2
DC=dmd tools/validate-api.sh
DC=ldc2 tools/validate-api.sh

# Controlled development machine only, when prerequisites and CPU controls pass:
M3_BENCH_CPU=2 M3_BENCH_ITERATIONS=1000000 bash tools/benchmark-m3.sh
```

These commands are execution instructions, **not recorded PASS results**.
Benchmark measurements are only comparable when run under the documented
controlled settings. Do not represent a hosted runner as the stable XPS
benchmark baseline.

## Evidence checkpoint — 2026-10-10 (non-release candidate)

Recorded `develop` commit: `216ac3ac09ef3ea32f4063ec50fcf04b83f769a6`.

| Check | Evidence | Result | Limitation |
| --- | --- | --- | --- |
| Six DMD/LDC compiler + fresh DUB consumer jobs, aggregate docs | [M3 integration run 38054313106](https://github.com/alex-1974/geodesy-d/actions/runs/38054313106), manual dispatch on `develop` | Seven jobs PASS | Establishes this commit, not a future RC. |
| Controlled XPS M3 performance | Local `build/m3-v2-develop-baseline.txt`; LDC 1.41.0, CPU 2, governor=performance, no_turbo=1, 1M iterations | Measurements recorded | Retain local raw file; not a general cross-machine speed guarantee. |
| LCC forward repeat | Three controlled runs on `develop`: 269.389 / 265.007 / 260.461 ns/op; PROJ: 201.620 / 178.961 / 175.882 ns/op | Median 265.007 vs 178.961 ns/op; PROJ faster | Only three samples, runtime noise, benchmark-level comparison. |
| LCC validation-only experiment | [PR #123](https://github.com/alex-1974/geodesy-d/pull/123), six LCC measurements: 245.042, 245.037, 297.354, 272.381, 272.309, 269.829 ns/op | CI green; experiment closed without merge | No repeatable speed benefit established. |

### Release-specific outstanding evidence

The following differential workflows already exist and support manual dispatch.
Their **successful historical runs are not evidence for this exact candidate**
unless the run explicitly names the pinned commit:

- `geodesic-prolate-validation.yml` — GeographicLib comparison;
- `dynamic-helmert-validation.yml` — EPSG/PROJ reference-frame comparison;
- `molodensky-badekas-validation.yml` — EPSG/PROJ reference-frame comparison.

Check the other family workflows and their exact triggering source SHA before
declaring all independent numerical release-oracle gates PASS. The benchmark
result does not substitute for differential accuracy validation.

There is no measured benefit supporting further speculative LCC micro-optimizations.
Keep `develop` unchanged until a concrete failure or profiled hot spot warrants
code changes.

## Current limits

- This plan does not assert fresh six-compiler, cross-platform or
  independent-oracle PASS on the v2 release candidate.
- M3 and M4 historic evidence cannot establish that subsequent code remained
  numerically or performance-equivalent.
- C1/C5 API decisions and a release-candidate pin remain separate work.
- No feature freeze, API freeze, release branch or v2 tag is authorized here.

Related: `docs/V2_0_CONSOLIDATION_PLAN.md`, `docs/VALIDATION.md`,
`docs/M3_INTEGRATION_GATE.md`, `docs/M4_INTEGRATION_GATE.md`.
