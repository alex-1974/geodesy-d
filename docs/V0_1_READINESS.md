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
- [ ] First remote GitHub Actions run observed green.

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

- [ ] review every public symbol exported by `geodesy.package`;
- [ ] verify naming consistency;
- [ ] verify `const` use;
- [ ] verify `pure`, `nothrow`, `@safe`, and `@nogc` claims;
- [ ] check that package-internal helpers are not accidentally re-exported;
- [ ] check that no API exposes ambiguous rotation/scale units;
- [ ] check Ddoc comments for every public symbol.

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

- [ ] verify `docs/README.md` describes the actual v0.1 scope;
- [ ] verify `docs/REFERENCES.md` contains the normative references used;
- [ ] verify `docs/VALIDATION.md` matches the implemented validator;
- [ ] verify ADR-0001/0002/0003 remain consistent with code;
- [ ] remove obsolete "next step" wording left over from implementation
      sequencing.

### 5. Release metadata

- [ ] decide whether to add a library-specific `CHANGELOG.md` before v0.1;
- [ ] confirm MIT license/copyright text;
- [ ] confirm DUB package metadata;
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
