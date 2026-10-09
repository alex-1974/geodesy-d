# geodesy-d v2.0.0 consolidation plan

Status: **PLANNING**

## Goal

v2.0.0 is a consolidation and API-stabilization release over the completed
post-v1 development line. It is not primarily a feature-expansion milestone.

The release should establish the long-lived v2 public contract for the
capabilities already implemented through M5 and the qualified prolate geodesic
domain.

## Scope

Included:

- M4 reference-frame family;
- M5 advanced ellipsoidal geometry;
- qualified prolate geodesic support;
- public API/family consistency audit;
- naming and result-type audit;
- checked/throwing/prepared API symmetry;
- default-state and failure-channel audit;
- unit/angle/domain contract audit;
- numerical regression hardening;
- performance/codegen baselines;
- rendered DDox/API example audit;
- six-compiler release matrix;
- hosted platform validation;
- external oracle validation;
- fresh external DUB consumer validation.

Excluded initially:

- physical-geodesy feature implementation;
- gravity/geoid model data;
- new projection families without consumer evidence;
- CRS database / WKT / PROJJSON / operation discovery;
- parity-driven feature additions.

## C1 — inventory and reconciliation

- [ ] reconcile README, ROADMAP, CHANGELOG, docs/API.md and module Ddoc;
- [ ] record exact current develop baseline;
- [ ] inventory every aggregate export from `import geodesy;`;
- [ ] inventory every prepared type and result type;
- [ ] inventory checked/throwing operation pairs;
- [ ] inventory public aliases and historical compatibility names;
- [ ] identify stale v1/v1.2/M4/M5 wording.

## C2 — v2 API audit

For every public family:

- [ ] naming is internally consistent;
- [ ] parameter names/order are deliberate;
- [ ] units are explicit and consistent;
- [ ] angle conventions are explicit;
- [ ] `.init` validity semantics are deliberate;
- [ ] checked APIs have predictable failure state;
- [ ] throwing peers map failures consistently;
- [ ] prepared vs one-shot ownership is coherent;
- [ ] result carriers contain only durable public semantics;
- [ ] aggregate exports are intentional.

Any breaking correction must be justified as a long-term v2 improvement rather
than cleanup for its own sake.

## C3 — numerical/domain audit

- [ ] sphere boundaries;
- [ ] oblate domain boundaries;
- [ ] qualified prolate domain boundaries;
- [ ] poles and antimeridian;
- [ ] near-antipodal geodesics;
- [ ] degenerate/ambiguous intersections;
- [ ] projection accepted-domain boundaries;
- [ ] transformation epoch/reference semantics;
- [ ] float/double/platform-real behavior;
- [ ] independent oracle coverage retained for every non-trivial family.

## C4 — feature freeze and release baseline

- [ ] create immutable `freeze/feature-2.0.0` checkpoint;
- [ ] cut a `release/2.0` stabilization branch from the same exact commit if a
      dedicated stabilization branch is used;
- [ ] admit no new feature family after this point;
- [ ] record the exact frozen feature-set commit and supported toolchain state;
- [ ] record ordinary tests, aggregate API/export inventory, package/import
      smoke, independent-consumer status, and relevant performance baselines;
- [ ] continue stabilization work allowed by the workspace release contract:
      correctness fixes, regression tests, validation, performance work, API
      corrections discovered by the audit, documentation, CI, and packaging.

## C5 — performance, numerical, and codegen qualification

- [ ] identify public hot paths;
- [ ] record DMD/LDC baselines against the frozen feature-set baseline;
- [ ] compare prepared and one-shot variants where both exist;
- [ ] record preparation cost and break-even where meaningful;
- [ ] verify no hidden allocation/GC in documented hot paths;
- [ ] investigate only material regressions;
- [ ] preserve reproducible benchmark environment metadata;
- [ ] complete numerical/domain regression qualification before final API freeze.

## C6 — v2 API audit and correction window

- [ ] complete the full public API audit on the frozen feature set;
- [ ] resolve approved naming inconsistencies;
- [ ] resolve approved signature/result-type inconsistencies;
- [ ] remove/deprecate only APIs whose continued support would damage the v2
      contract;
- [ ] add migration notes for every intentional breaking change;
- [ ] rerun API/consumer/semantic gates after each public correction.

## C7 — API freeze

- [ ] complete final public API audit;
- [ ] create immutable `freeze/api-2.0.0` checkpoint;
- [ ] no caller-visible API changes after freeze without reopening the gate.

## C8 — documentation polish

- [ ] public module summaries and descriptions;
- [ ] public type/function/property Ddoc;
- [ ] compiler-checked examples;
- [ ] docs/API.md;
- [ ] migration guide from v1.x to v2.0;
- [ ] release notes;
- [ ] rendered DDox inspection;
- [ ] terminology consistency across all families.

## C9 — final qualification

On the exact release-candidate head:

- [ ] normal CI PASS;
- [ ] DMD 2.111.0 / 2.112.1 / 2.113.0 PASS;
- [ ] LDC 1.41.0 / 1.42.0 / 1.43.0 PASS;
- [ ] required Linux/Windows/macOS/AArch64 platform gates PASS;
- [ ] PROJ/GeographicLib differential gates PASS;
- [ ] geodesic/prolate/intersection gates PASS;
- [ ] projection gates PASS;
- [ ] transformation gates PASS;
- [ ] DDox/public-example gate PASS;
- [ ] fresh external DUB consumer PASS.

## C10 — release

- [ ] record exact RC commit;
- [ ] promote exact qualified commit to `main`;
- [ ] tag `v2.0.0`;
- [ ] publish release notes;
- [ ] verify DUB registry resolution;
- [ ] verify fresh external consumer from registry;
- [ ] synchronize release state back to `develop`.

## Release principle

v2.0.0 succeeds if the existing library becomes easier to understand, safer to
depend on, more internally consistent, and better qualified — even if it adds
no new capability family.
