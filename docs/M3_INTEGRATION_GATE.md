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
- [x] controlled local M3 performance baseline recorded;
- [x] final #74 evidence summary recorded;
- [x] ROADMAP changed from M3 active to M3 completed;
- [x] #74 closed.

## Release decision

No release version is assigned by this gate.

After M3 closure, the next decision is whether the coherent M3 feature set
should enter a new feature-release cycle (for example v1.2.0) or whether
development should proceed to M4 before release preparation.


## Controlled baseline result

Recorded on the controlled development machine against:

`ced06d5c7d04e390de4c8af582c47ce08c590989`

Environment:

- Intel Core i7-9750H;
- Linux 6.17.0-22-generic x86_64;
- logical CPU 2;
- governor `performance`;
- Intel turbo disabled;
- LDC 1.41.0;
- g++ 15.2.0;
- PROJ 9.7.1;
- GeographicLib 2.7;
- 1,000,000 iterations per family.

Measured results:

| Family / operation | geodesy-d | Reference | Ratio D/reference | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Rhumb inverse | 493.380 ns/op | GeographicLib 787.373 ns/op | 0.627x | geodesy-d ~37.3% faster |
| Rhumb line position | 555.932 ns/op | GeographicLib direct 910.429 ns/op | 0.611x | geodesy-d ~38.9% faster |
| Polar Stereographic forward | 247.239 ns/op | GeographicLib 276.990 ns/op | 0.893x | geodesy-d ~10.7% faster |
| Polar Stereographic reverse | 486.406 ns/op | GeographicLib 521.538 ns/op | 0.933x | geodesy-d ~6.7% faster |
| LCC 2SP forward | 269.521 ns/op | PROJ 186.192 ns/op | 1.448x | geodesy-d ~44.8% slower |
| LAEA forward | 163.193 ns/op | PROJ 180.018 ns/op | 0.907x | geodesy-d ~9.3% faster |

The Polar Stereographic PROJ one-shot timings are intentionally not used as
the primary comparison because one-shot setup cost dominates and is not
equivalent to the prepared geodesy-d/GeographicLib path.

The M3 performance requirement is satisfied: all admitted hot paths now have a
controlled reproducible baseline. LCC 2SP remains the only material
performance gap and should be treated as a future optimization target rather
than a blocker for M3 correctness/integration closure.
