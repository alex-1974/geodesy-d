# Contributing to geodesy-d

`geodesy-d` is a small pure-D numerical library. Contributions should preserve
its narrow responsibility boundary and explicit numerical contracts.

## Before changing an algorithm

Document the mathematical source and method identity first. Prefer, in order:

1. IOGP/EPSG method definitions;
2. primary numerical publications;
3. GeographicLib or another trusted independent numerical implementation;
4. PROJ as an independent interoperability/cross-validation target.

Do not copy implementation code from the historical `coordinate` prototype.

## Local gates

Run from the `geodesy-d` repository root:

```bash
dub test --force
dub test --compiler=ldc2 --force
dub build --compiler=ldc2 --build=release --force
DC=dmd  tools/validate-api.sh
DC=ldc2 tools/validate-api.sh
tools/validate-proj.sh
tools/validate-proj.sh --extended
tools/validate-docs.sh
```

The PROJ checks are validation-only; PROJ must not become a library dependency.

## API changes

For public API changes:

- update `docs/API.md`;
- update `validation/api/public_api_contract.d`;
- add a negative compile test when an encapsulation boundary is involved;
- update an ADR when the change alters an accepted design decision;
- record user-visible changes in `CHANGELOG.md`.

## Numerical changes

Every numerical defect should gain a regression vector. Tolerances are
operation-specific; do not introduce a global machine-epsilon equality policy.

Keep `@safe`, `@nogc`, `nothrow`, and `pure` on checked hot paths where the
operation contract permits them. Do not enable broad `@fastmath` without a
separate measured accuracy/performance justification.

## Compiler baseline

The workspace baseline for v0.1 is D frontend **2.112.1**. DMD and LDC are
required CI compilers; GDC is best effort.
