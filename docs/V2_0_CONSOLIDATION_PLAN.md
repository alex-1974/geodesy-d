# geodesy-d v2.0.0 consolidation plan

Status: **FEATURE + API FROZEN — C8/C9 final release qualification**

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
- [ ] identify stale v1/v1.2/M4/M5 wording;
- [ ] identify any unresolved feature-scope question before freezing the v2 set.

This is a pre-freeze inventory and scope reconciliation. It may identify likely
API problems, but the final compatibility/API audit occurs after the release
baseline and performance/numerical qualification.

## C2 — feature freeze

- [x] create immutable `freeze/feature-2.0.0` checkpoint;
- [x] cut `release/2.0` from the feature-freeze commit;
- [x] admit no new capability family after this point (policy active);
- [ ] continue stabilization work allowed by the workspace release contract:
      correctness fixes, regression tests, validation, performance work, API
      corrections discovered by the audit, documentation, CI, and packaging.

Feature checkpoint: `01d2bbc1822d99ef711d5d78487597b76e650211`.
The annotated `freeze/feature-2.0.0` tag resolves to this SHA; `release/2.0`
was created from the same commit. This records the feature boundary, **not**
an API or release qualification freeze.

## C3 — release baseline

- [ ] record the exact frozen feature-set commit/checkpoint;
- [ ] record supported compiler/toolchain state;
- [ ] record complete ordinary test result;
- [ ] record aggregate public API/export inventory;
- [ ] record package/import smoke result;
- [ ] record relevant independent-consumer result;
- [ ] record performance baselines for performance-relevant families.

## C4 — numerical, domain, performance, and codegen qualification

Numerical/domain coverage:

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

Performance/codegen coverage:

- [ ] identify public hot paths;
- [ ] record DMD/LDC baselines against the frozen feature-set baseline;
- [ ] compare prepared and one-shot variants where both exist;
- [ ] record preparation cost and break-even where meaningful;
- [ ] verify no hidden allocation/GC in documented hot paths;
- [ ] investigate only material regressions;
- [ ] preserve reproducible benchmark environment metadata.

## C5 — full v2 public API audit

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
- [ ] aggregate exports are intentional;
- [ ] supported named-argument forms and claimed attributes are compile-checked;
- [ ] external consumer compilation covers the intended public surface.

## C6 — v2 API correction window

- [ ] resolve approved naming inconsistencies;
- [ ] resolve approved signature/result-type inconsistencies;
- [ ] remove/deprecate only APIs whose continued support would damage the v2
      contract;
- [ ] add migration notes for every intentional breaking change;
- [ ] rerun affected API/consumer/semantic gates after each public correction.

Any breaking correction must be justified as a long-term v2 improvement rather
than cleanup for its own sake.

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
