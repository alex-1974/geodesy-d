# v2.1.0 release readiness — qualification ledger

Status: **candidate preparation only — no v2.1 tag or release**.
Baseline stable release: `v2.0.0` on `main`.

## Admitted scope

1. **#116 Equal Earth (EPSG 1078)**: private polynomial kernel PR #136
   merged as `3543faa386806aa40caa9db9e4480740fb9104eb`, public projection
   and consumer qualification PR #137 merged as
   `fcaf233c77220b63c58021d609b6659d70a286d7`.
2. **#17 DMD/LDC toolchain alignment**: existing pinned six-compiler release
   gate retained. Research and read-only sibling CI inventory merged via
   PR #138 as `bdaea5ade5729e1c7f1103cad8fce3e1fbef7fe0`.
3. Excluded: physical geodesy / gravity and geoid (#49/#50), unrelated
   projections or other repositories' code.

## Evidence already obtained

- PR #137 latest pre-merge head `b8efe7c03d72f5527098aaf8cdda0388e1ad203d`:
  **13 of 13 triggered workflows passed**, including API documentation,
  numerical differential tests, M3, platform matrices and the six-compiler
  **Equal Earth external consumer**.
- Public `import geodesy;` includes `EqualEarth!float`,
  `EqualEarth!double`, `EqualEarth!real`.
- PROJ 9.5.1 fixed-vector qualification includes spherical and WGS 84 models;
  tests also cover the equatorial origin, antimeridian, poles, invalid inverse
  map footprint and round trips.
- **Precision limitation:** implementation uses `double` working precision
  even for public `real`; no extra `real` internal precision claimed.
- Fast `develop` CI intentionally tests minimum and latest surveillance;
  pinned release gates use DMD 2.111.0/2.112.1/2.113.0 and
  LDC 1.41.0/1.42.0/1.43.0.
- PR #138 docs merge passed CI, DDox and the Equal Earth consumer workflow.

## Gates required *before* release

- [ ] Confirm the new `develop` merge commit and all post-merge workflows
      are green, without counting PR-only runs as post-merge results.
- [ ] Perform explicit public API and numerical behaviour review, including
      Equal Earth units, pole/antimeridian conventions, `real` precision
      statement, and unsupported prolate flattening.
- [ ] Confirm safety/attribute and allocation/codegen evidence for checked
      paths; run/review an Equal Earth release-mode benchmark (no unmeasured
      performance claim).
- [ ] Complete the bounded #17 acceptance for `geodesy-d`; separately track
      any workspace-wide work without modifying sibling repositories.
- [ ] Freeze feature set and then API with annotated checkpoints according
      to workspace Git policy; verify clean `develop` state.
- [ ] Run the **release-candidate** six-compiler release/consumer gate and
      all release qualification workflows on the exact candidate SHA.
- [ ] Audit final Ddoc pages, root import and standalone consumers, check
      `CHANGELOG.md` and migration/release documentation.
- [ ] Only after successful evidence: promote the exact candidate to
      `release/2.1` / `main`, tag `v2.1.0`, publish and confirm DUB
      registry consumer.

## Repository write boundary

All commits, branches, workflows, issues, and PRs for this work remain
**inside `alex-1974/geodesy-d` only**. Other workspace repositories
may be inspected read-only; their workflows, issues and files must not
be changed as part of this release.

## Status caution

An issue checklist may still be open after code merge when release gates
remain. Do not mark #116 or #17 fully closed simply because CI for an
implementation PR was green. No release tag or release branch is created
by this readiness document.
