# Validation strategy

## Purpose

`geodesy-d` implements bounded geodetic mathematics independently in D.

Correctness therefore should not rely only on tests derived from the same
formulas as the implementation.

Validation uses three complementary layers:

1. **normative published reference vectors** from EPSG/IOGP;
2. **internal property/edge-case tests** through `dub test`;
3. **differential cross-validation against PROJ** as an independent
   implementation.

PROJ is a validation oracle only. It is not a `geodesy-d` build dependency,
runtime dependency, or implementation backend.

## Normal compiler gate

The normal library gate remains:

```bash
dub test
dub test --compiler=ldc2
dub build --compiler=ldc2 --build=release
```

These tests require only D/Phobos.

## Optional PROJ differential gate

When PROJ command-line tools are installed:

```bash
tools/validate-proj.sh
```

The script:

1. locates the repository independently of the current working directory;
2. compiles `validation/proj_crosscheck.d` against the local library sources;
3. invokes the installed PROJ `cct` executable;
4. compares `double` results operation-by-operation;
5. fails on the first difference outside the configured tolerance.

The compiler can be selected explicitly:

```bash
DC=dmd  tools/validate-proj.sh
DC=ldc2 tools/validate-proj.sh
```

## Initial differential matrix

### EPSG 9602

Forward geodetic → geocentric conversion is compared directly with PROJ/cct.

For the inverse direction, PROJ independently generates the Cartesian input
from each known geodetic test vector; `geodesy-d` then converts that PROJ
Cartesian result back to geodetic coordinates and is compared with the known
source vector.

PROJ's own `cart` inverse is deliberately not treated as a high-precision
oracle here. Its implementation uses a direct Bowring inverse, and measurable
differences appear at large ellipsoidal heights. The differential gate therefore
uses PROJ as the independent forward generator of the Cartesian test vector.

The deterministic WGS 84 points cover:

- both hemispheres;
- equator;
- antimeridian vicinity;
- near-polar positions;
- negative height;
- ordinary terrestrial height;
- 100 km height;
- 1,000 km height;
- geostationary-scale height.

Exact poles are already unit-tested internally. They are deliberately excluded
from longitude cross-implementation comparison because longitude is
mathematically indeterminate on the rotation axis and implementations may
choose different deterministic conventions.

### EPSG 1031

Geocentric translation is compared with PROJ's Helmert operator configured
with translations only.

### EPSG 1033

Position Vector Helmert is checked with non-zero:

- X/Y/Z translations;
- X/Y/Z rotations;
- scale difference;

over several geocentric vectors with different signs and axis dominance.

### EPSG 1032

Coordinate Frame is checked with the physically equivalent rotation parameters
of opposite sign.

This validates both the numerical matrix and the convention mapping.

## Tolerances

The differential test does not use one universal geodetic tolerance.

Initial `double` tolerances are operation/output specific:

```text
EPSG 9602 forward X/Y/Z       20 micrometres
EPSG 9602 inverse lon/lat     5e-10 degrees
EPSG 9602 inverse height      50 micrometres
EPSG 1031 X/Y/Z               20 nanometres
EPSG 1032/1033 X/Y/Z           3 micrometres
```

These are validation thresholds, not public API accuracy promises.

They may be tightened or adjusted only from measured cross-validation data and
with the reason documented.

## Reproducibility

The validator prints:

```text
PROJ reference: <cct version>
PASS: <N> geodesy-d vs PROJ scalar comparisons
worst normalized error: <fraction of tolerance>
```

The PROJ version is therefore recorded in CI/log output.

The initial matrix is deterministic. A broader generated/stochastic differential
suite may be added later, but it should use a fixed seed or persist failing
vectors so every regression remains reproducible.

## Sources

Primary normative source:

- IOGP Report 373-07-2 / EPSG Guidance Note 7-2.

Independent implementation:

- PROJ `cct`;
- PROJ `cart`;
- PROJ `helmert`.

PROJ explicitly models geodetic transformations as pipelines of elementary
operations and requires the Helmert rotation convention to be declared when
rotational parameters are used.

## Extended fixed-seed differential suite

The fast default gate remains:

```bash
tools/validate-proj.sh
```

For a broader deterministic validation run:

```bash
tools/validate-proj.sh --extended
```

The extended suite uses a locally implemented SplitMix64 generator with fixed
seeds. This avoids relying on a Phobos RNG implementation detail and keeps the
generated vectors reproducible across compiler/library upgrades.

### Generated EPSG 9602 matrix

Four ellipsoid models are exercised:

```text
WGS 84
GRS 80
Airy 1830
sphere, R = 6 371 000 m
```

PROJ receives the same ellipsoid parameters through `+ellps`, `+a`/`+rf`, or
`+a`/`+b`.

For each ellipsoid, 48 generated geodetic vectors cover:

- both longitude hemispheres;
- explicit antimeridian-near cases;
- ordinary and near-polar latitudes;
- heights from -1 km to 1 billion metres.

Forward XYZ is compared directly to PROJ.

For the inverse direction, PROJ independently generates XYZ from the known
geodetic vector and `geodesy-d` must recover the known source.

### Generated EPSG 1031 matrix

64 generated geocentric vectors use:

```text
X/Y/Z:  +/- 100 000 km
dX/dY/dZ: +/- 1 km
```

and are compared with PROJ Helmert translation-only operations.

### Generated EPSG 1032 / 1033 matrix

64 generated 7-parameter transformations exercise:

```text
X/Y/Z:       +/- 100 000 km
translations +/- 500 m
rotations    +/- 5 arcsec on every axis
scale        +/- 25 ppm
```

Every vector is evaluated as both:

```text
EPSG 1033 Position Vector
EPSG 1032 Coordinate Frame
```

with the three Coordinate Frame rotation signs reversed.

The suite checks both implementations independently against PROJ and also
checks that the two convention-specific `geodesy-d` parameterizations produce
the same physical target coordinate.

### Extended tolerances

The generated matrix uses operation-specific absolute floors plus a small
magnitude-dependent term for very large coordinates:

```text
linear XYZ: 20 micrometres + 5e-13 * coordinate magnitude
inverse angular: 1e-9 degrees
inverse height: 50 micrometres + 2e-12 * |height|
```

These remain validation thresholds, not API accuracy guarantees.

### Reproducibility

The fixed seeds are part of the validator source and should not be changed
casually. If a seed changes, that change should be treated like changing a
reference-vector corpus and called out in review.
