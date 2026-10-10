# v2.1.0 DMD/LDC toolchain alignment checkpoint

Status: **existing six-compiler release matrix qualified; policy/documentation
reconciliation for #17**, not a compiler upgrade.

## Controlled workspace baseline

| Family | Minimum / baseline | Other qualified releases |
| --- | --- | --- |
| DMD | 2.111.0 | 2.112.1, 2.113.0 |
| LDC | 1.41.0 | 1.42.0, 1.43.0 |

Keep DMD 2.112.0 available only as a local diagnostic comparison point.

The controlled local compilers are under `~/dlang`, with explicit versioned
commands; Ubuntu distribution compiler builds must not be assumed bit-for-bit
equivalent to the official release builds. Pin DUB 1.40.0 for local benchmark
comparison where compiler identity is the independent variable.

## Repository CI audit on v2.0.0

- `.github/workflows/ci.yml`: deliberately fast develop gate using
  `dmd-2.111.0`, `dmd-latest` and `ldc-latest`. These floating
  `latest` entries are *compatibility surveillance*, not reproducible
  baseline labels.
- `.github/workflows/release-compiler-consumer.yml`: the full *versioned*
  three-DMD/three-LDC matrix above, with unit tests, release build,
  `tools/validate-api.sh` and fresh external DUB consumer.
- `.github/workflows/m3-integration.yml`: the same six-version matrix
  plus documentation contract.
- `tools/validate-release-consumer.sh`: uses the `DC` compiler selected
  by the workflow. No locally installed compiler path is embedded in
  the public package.
- v2.0.0 exact-candidate release validation: 28/28 workflows PASS at
  `49766c6926440d17e2cd3c1d1379655523288bb7`; consumer gate
  `38071931294` passed for all six versions.

## Decision for v2.1.0

**Retain the fast floating latest compiler surveillance in develop CI and
the complete pinned six-compiler release matrix.** Replacing `latest`
with a fixed version would remove early compiler-regression detection;
making every develop commit execute all release platforms would increase
cost without a demonstrated need.

Instead, treat baseline and surveillance as two explicitly distinct
jobs/purposes in documentation and qualification evidence. Any
compiler-specific workaround must state the exact compiler and affected
versions, include a minimal reproducer, and be checked against both
families. Do not infer performance from matching D frontend versions,
because LDC's LLVM backend version and build origin differ.

## Remaining workspace acceptance

#17 concerns **cross-repository** consistency; this single-repository
audit is not by itself proof every workspace library uses the same
versioned matrix. Verify other repositories separately before closing
#17 on that basis. Avoid changing unrelated repositories in the
geodesy-d v2.1 implementation PR.
