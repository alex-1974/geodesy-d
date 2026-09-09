# geodesy-d v0.1 readiness

## Purpose

This document defines the release gate for the first public `geodesy-d`
baseline.

It is intentionally a **readiness checklist**, not a historical project log and
not a roadmap for every future geodesy feature.

The v0.1 objective is a small, coherent, independently useful pure-D core with
well-defined semantics and independently validated numerical behavior.

## Proposed v0.1 scope

### Core value types

- `Angle<T>`
- `Latitude<T>`
- `Longitude<T>`
- `Ellipsoid<T>`
- `GeodeticCoordinate<T>`
- `GeocentricCoordinate<T>`

Supported scalar types:

```text
float
double
real
```

`double` is the normative reference precision.

### Coordinate conversion

- EPSG 9602 — geographic/geocentric conversion
  - geodetic -> geocentric
  - geocentric -> geodetic

### Static geocentric frame transformations

- EPSG 1031 — geocentric translations
- EPSG 1033 — Position Vector Helmert
- EPSG 1032 — Coordinate Frame Helmert

The two Helmert rotation conventions are distinct in the type/API model.

### Explicitly outside v0.1

The following are not release blockers:

- inverse API for 7-parameter Helmert;
- exact finite-angle Helmert;
- time-dependent / 14-parameter Helmert;
- Molodensky or Molodensky-Badekas;
- Transverse Mercator;
- UTM;
- ellipsoidal direct/inverse geodesics;
- MGRS, Geohash, Plus Codes;
- EPSG database / CRS lookup;
- WKT / PROJJSON;
- transformation grids;
- automatic coordinate-operation selection.

Those belong to later milestones or other libraries.

## Completed release gates

### Architecture

- [x] Pure-D bounded mathematical scope defined.
- [x] `geo-d`, `geodesy-d`, `georef-d`, and `proj-d` responsibilities separated.
- [x] Core type/unit model accepted in ADR-0002.
- [x] Helmert convention model accepted in ADR-0003.
- [x] No mandatory dependency on PROJ or another native geospatial library.
- [x] No CRS/datum database embedded in core coordinate values.

### API semantics

- [x] Strong latitude/longitude types; no `alias this`.
- [x] Canonical angle storage in radians.
- [x] Explicit degree/radian factories.
- [x] Latitude range is checked.
- [x] Longitude endpoint and normalization semantics are explicit.
- [x] Geodetic height is explicitly ellipsoidal height.
- [x] Geocentric X/Y/Z and ellipsoid axes share an explicit same-linear-unit
      contract.
- [x] Helmert rotation convention is compile-time explicit.
- [x] `.init` identity semantics are explicit for transformation parameter
      structs.
- [x] Checked non-throwing APIs use the intended `pure nothrow @safe @nogc`
      contract where applicable.
- [x] Throwing convenience APIs use `GeodesyValueException`.

### Numerical implementation

- [x] EPSG 9602 forward.
- [x] EPSG 9602 reverse.
- [x] EPSG 1031.
- [x] EPSG 1033.
- [x] EPSG 1032.
- [x] Rotation-convention equivalence test.
- [x] Explicit handling of geocentric centre singularity.
- [x] Explicit deterministic longitude convention on the rotation axis.
- [x] No global machine-epsilon approximate-equality policy.
- [x] No broad `@fastmath`.


### Minimum supported D frontend

The v0.1 package minimum is:

```text
D frontend >= 2.111.0
```

This is evidence-based rather than aspirational: the v0.1 documentation/API
audit was executed successfully with local DMD 2.111.0 before the DUB package
gate was aligned.

The normal CI also retains current DMD and LDC jobs. The exact
`dmd-2.111.0` job exists specifically to prevent accidental use of newer
language features from silently raising the package minimum.

This package minimum is distinct from a newer workspace development baseline.

### Compiler validation

Local development gate:

```bash
dub test --force
dub test --compiler=ldc2 --force
dub build --compiler=ldc2 --build=release --force
```

Current observed local status before this document:

- [x] DMD unit tests pass.
- [x] LDC unit tests pass.
- [x] LDC release build passes.

CI definitions:

- [x] GitHub Actions DMD gate added.
- [x] GitHub Actions LDC gate added.
- [x] GitHub Actions release build added.
- [ ] First remote GitHub Actions run observed green, including dmd-2.111.0.

### Independent numerical validation

PROJ is used as a validation oracle only.

Current observed local validation with:

```text
PROJ/cct 9.7.1
```

Smoke suite:

```text
117 / 117 comparisons PASS
worst normalized error = 0.000384
```

Extended fixed-seed suite:

```text
2037 / 2037 comparisons PASS
worst normalized error = 0.276913
```

Coverage includes:

- WGS 84;
- GRS 80;
- Airy 1830;
- spherical ellipsoid;
- antimeridian-near inputs;
- near-polar inputs;
- negative and very large heights;
- generated EPSG 1031 translations;
- generated EPSG 1032 and 1033 seven-parameter transformations.

Release checklist:

- [x] Published EPSG/IOGP reference vectors.
- [x] Independent PROJ smoke differential validation.
- [x] Independent fixed-seed extended differential validation.
- [x] Non-finite validator outputs explicitly fail.
- [x] PROJ version is printed in validation logs.
- [x] Separate GitHub Actions PROJ workflow added.
- [ ] First remote GitHub Actions PROJ extended run observed green.

## Remaining v0.1 blockers

### 1. `Ellipsoid.init` semantics

- [x] Resolved in ADR-0004.

`Ellipsoid!T.init` is an intentionally invalid NaN sentinel. Public factories
create valid ellipsoids, `isValid` exposes the state explicitly, and checked
EPSG 9602 operations reject an invalid ellipsoid before calculation.


### 2. Public API audit

Before tagging:

- [x] review every public symbol exported by `geodesy.package`;
- [x] verify naming consistency;
- [x] verify `const` use;
- [x] verify `pure`, `nothrow`, `@safe`, and `@nogc` claims;
- [x] check that package-internal helpers are not accidentally re-exported;
- [x] check that no API exposes ambiguous rotation/scale units;
- [x] check Ddoc comments for every public symbol.

### Public API compile contract

- [x] external aggregate-import contract added;
- [x] negative compile tests protect encapsulation/internal helpers;
- [x] DMD/LDC CI step defined.

The canonical v0.1 surface is documented in `docs/API.md`.

### 3. Validate CI remotely

Local YAML creation is not sufficient.

Before release:

- [ ] push the CI workflows;
- [ ] observe DMD job green;
- [ ] observe LDC job green;
- [ ] observe PROJ extended job green;
- [ ] fix runner-specific assumptions if any appear.

The PROJ workflow is deliberately separate from the normal compiler gate.
It runs:

- manually via `workflow_dispatch`;
- weekly;
- on pull requests touching numerical/validation code.

### 4. Release-facing documentation audit

- [x] verify `docs/README.md` describes the actual v0.1 scope;
- [x] verify `docs/REFERENCES.md` contains the normative references used;
- [x] verify `docs/VALIDATION.md` matches the implemented validator;
- [x] verify ADR-0001/0002/0003/0004 remain consistent with code;
- [x] remove obsolete "next step" wording left over from implementation
      sequencing.

### Documentation contract

- [x] Ddoc generated from all public source modules;
- [x] release-facing documentation stale-wording check added;
- [x] required documentation/repository files checked in `tools/validate-docs.sh`;
- [x] DMD documentation gate added to CI.

### 5. Release metadata

- [x] add library-specific `CHANGELOG.md`;
- [x] confirm MIT license/copyright text;
- [x] confirm DUB package metadata and package minimum D frontend >=2.111.0;
- [ ] create and verify Git tag `v0.1.0`.

## Non-blocking quality improvements

These are desirable but should not delay v0.1 unless an audit reveals a real
problem:

- GDC best-effort compile test;
- macOS compile test;
- Windows compile test;
- D-Scanner / style tooling;
- benchmark suite;
- randomized validation beyond the fixed-seed corpus;
- more published external reference vectors;
- exact measured public accuracy envelopes.

## Release decision

`v0.1.0` is ready to tag when:

```text
Ellipsoid.init semantics accepted (ADR-0004)
AND public API audit complete
AND documentation audit complete
AND remote DMD/LDC CI green
AND remote PROJ extended validation green
AND release metadata checked
```

No additional geodetic operation is required to satisfy that gate.
