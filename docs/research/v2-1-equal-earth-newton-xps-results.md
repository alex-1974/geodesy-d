# Equal Earth inverse authalic latitude — XPS qualification (2026-10-11)

Status: measured final safeguarded Newton implementation, prior to PR #143 merge.
Scope: `geodesy-d` only.

## Compared commits

- Baseline: `e95f8a6751bacb11f2d2448b265e0cf0dfc83e84` (65-step bisection).
- Candidate: `eb6729944be5963c6253a047befbab274c5552a3`
  (bounded Newton, maximum 24 attempts, retaining a 65-step bisection fallback).

Machine: user Dell XPS 15, Ubuntu x86-64. Compiler:
DMD 2.111.0 (`-O -release -inline -i`) and
LDC 1.41.0, DMD frontend 2.111.0 / LLVM 20.1.5
(`-O3 -release -i`). Both builds use `-Isource`.
Seven interleaved runs per compiler/variant, one million operations per
reported direction. Source: XPS terminal transcript supplied 2026-10-11.

## Median wall times (ms per 1,000,000 calls)

| Operation | Compiler | Bisection | Newton + fallback | Baseline / candidate |
| --- | --- | ---: | ---: | ---: |
| Forward | DMD 2.111.0 | 282.423 | 286.625 | 0.985x |
| Forward | LDC 1.41.0 | 200.926 | 208.653 | 0.963x |
| Reverse | DMD 2.111.0 | 5805.940 | 1369.620 | **4.239x** |
| Reverse | LDC 1.41.0 | 4597.010 | 1224.040 | **3.756x** |

For the representative four-coordinate benchmark, reverse wall-time
reduction is approximately 76.4% (DMD) and 73.4% (LDC).
Forward behavior is not an optimization target in this change.

All runs printed `forward checksum=2.63674e+11` and
`reverse checksum=187649`; the `-release` benchmark contains actual
runtime success checks and four-coordinate forward/reverse preflight.
Printed checksums are rounded and are **not** proof of bitwise equality
or global numerical equivalence.

## Numerical/platform evidence

- First candidate without the bisection fallback passed its original ten
  workflows but the expanded polar/antimeridian grid then failed on
  macOS AArch64 and Windows AArch64 with LDC 1.41.0 at inverse preflight.
- Preserving the bounded bisection fallback resolved those failures:
  **10/10 triggered CI workflows PASS** for candidate
  `eb6729944be5963c6253a047befbab274c5552a3`,
  including platform matrices, the existing PROJ differential gate,
  API documentation and Equal Earth external consumer.
- The expanded grid includes 75 combinations of latitudes and longitudes,
  notably near both geographic poles and the antimeridian.

## Limits and next qualification

- Hardware provenance (CPU model / clocks / thermal state) was not
  captured; timings are local performance evidence, not a universal speed
  guarantee.
- The benchmark's four locations are not a worst-case inverse corpus.
  Broader error distributions and the frequency of entering the fallback
  should be measured separately.
- No independent codegen assembly inspection or direct PROJ/C++ performance
  comparison is implied by these results.
- Release-gate qualification and feature/API freeze for v2.1 remain pending.
