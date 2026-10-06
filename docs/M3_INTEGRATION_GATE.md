# M3 — Navigation & Polar Geodesy integration gate

Date: 2026-10-06  
Tracking issue: #74  
Stable input baseline: v1.1.0

## Scope admitted into M3

Core:

- #38 — Polar Stereographic;
- #39 — UPS;
- #37 — Rhumb / RhumbLine;
- #40 — additional-projection admission audit.

Additional families admitted by #40 and completed before the integration gate:

- #83 — Lambert Conformal Conic 2SP;
- #84 — Lambert Azimuthal Equal Area.

The admission of #83/#84 does not retroactively change the definition of the
M3 core. They are additive projection follow-ups completed before M3 closure.

## Integration baseline

The integration branch starts from `develop` commit:

~~~text
29933dfeb80ae5b21ea58e46a62e45c1ecd8e022
~~~

This is the merge commit of PR #87 and therefore contains all admitted M3 work.

## Aggregate public API

The package surface `import geodesy;` exports:

- `Rhumb!T` / `RhumbLine!T`;
- `PolarStereographic!T`;
- UPS policy and coordinate family;
- `LambertConformalConic!T`;
- `LambertAzimuthalEqualArea!T`.

The API remains additive to the v1 compatibility baseline. CRS authority
databases, WKT/PROJJSON, transformation discovery, MGRS and datum/grid
pipelines remain outside geodesy-d.

## Numerical qualification already completed

Each admitted family has durable independent validation:

- Polar Stereographic: PROJ + GeographicLib;
- UPS: PROJ + GeographicLib UTMUPS;
- Rhumb/RhumbLine: GeographicLib;
- LCC 2SP: PROJ with EPSG:31287 and EPSG:3034 parameter sets;
- LAEA: PROJ with EPSG:3035 parameter set.

The individual family gates also cover float/double/real and the controlled
DMD/LDC matrix.

## M3 aggregate compiler / consumer gate

`.github/workflows/m3-integration.yml` reruns the aggregate package on:

- DMD 2.111.0;
- DMD 2.112.1;
- DMD 2.113.0;
- LDC 1.41.0;
- LDC 1.42.0;
- LDC 1.43.0.

Every lane runs:

1. library unittests;
2. release build;
3. aggregate public API contract;
4. a fresh external DUB consumer.

The workflow also runs the aggregate documentation contract under DMD 2.113.0.

This supplements, rather than replaces, the already-qualified per-family
Linux/Windows/macOS x86_64/AArch64 matrices.

## Controlled performance baseline

Hosted-runner benchmark smoke is not accepted as a performance baseline.

The final M3 baseline must be produced on the controlled development machine
with:

~~~bash
M3_BENCH_CPU=2 M3_BENCH_ITERATIONS=1000000 \
    bash tools/benchmark-m3.sh
~~~

The wrapper refuses to record a baseline unless:

- CPU governor is `performance`;
- Intel turbo is disabled;
- LDC, the C++ compiler, PROJ, and GeographicLib are available.

It records commit/toolchain/environment metadata and runs the prepared/hot-path
benchmarks for:

- Rhumb / RhumbLine;
- Polar Stereographic;
- Lambert Conformal Conic 2SP;
- Lambert Azimuthal Equal Area.

The generated result belongs under `build/` and is evidence, not a committed
source artifact. The measured result and ratios should be summarized in #74
before the final M3 closure.

## M3 closure checklist

- [x] #38 Polar Stereographic accepted and merged;
- [x] #39 UPS accepted and merged;
- [x] #37 Rhumb/RhumbLine accepted and merged;
- [x] #40 additional-projection admission audit completed;
- [x] #83 LCC 2SP admitted follow-up accepted and merged;
- [x] #84 LAEA admitted follow-up accepted and merged;
- [x] aggregate `import geodesy;` surface reviewed;
- [x] independent numerical validation is durable per family;
- [x] public API / DDox / research documentation exists for admitted families;
- [x] six-compiler aggregate release/consumer gate defined;
- [x] fresh external consumer gate defined before the next feature release;
- [ ] M3 aggregate integration workflow passes on its final head;
- [ ] controlled local M3 performance baseline recorded;
- [ ] final #74 evidence summary recorded;
- [ ] ROADMAP changed from M3 active to M3 completed;
- [ ] #74 closed.

## Release decision

No release version is assigned by this gate.

After M3 closure, the next decision is whether the coherent M3 feature set
should enter a new feature-release cycle (for example v1.2.0) or whether
development should proceed to M4 before release preparation.
