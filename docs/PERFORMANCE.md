# geodesy-d performance policy

## Purpose

Performance is a quality property of `geodesy-d`, but numerical correctness
takes precedence over raw speed.

Performance work follows this order:

1. establish correctness and numerical behaviour;
2. establish a reproducible performance baseline;
3. identify meaningful costs;
4. optimise only where measurement justifies it;
5. revalidate numerical behaviour after optimisation.

No performance claim should be made without a reproducible measurement.

## Primary compiler

LDC release builds are the normative performance configuration.

DMD remains a supported compiler and benchmark code should compile with it, but
DMD results are not the primary optimisation target.

## Benchmark layers

Benchmarks distinguish:

- bulk throughput and amortized time per operation;
- true dependency-chain latency where specifically implemented;
- compiler/build configuration;
- algorithm-specific comparison against independent implementations.

The initial benchmark harness measures bulk throughput. Its reported `ns/op`
value is total bulk execution time divided by the number of operations; it
must not be described as true single-operation latency.

The initial benchmark set covers:

- EPSG 9602 geodetic -> geocentric;
- EPSG 9602 geocentric -> geodetic;
- EPSG 1031 geocentric translation;
- EPSG 1033 Position Vector Helmert;
- EPSG 1032 Coordinate Frame Helmert.

Performance-sensitive algorithms should acquire reproducible benchmark
baselines as part of integration and release readiness. An operation-specific
validation plan may explicitly make performance non-gating for initial
correctness acceptance. In that case, no performance claim or optimisation is
accepted until an appropriate baseline exists.

## Measurement rules

Input construction and fixture generation must occur outside timed sections.

Timed kernels must:

- operate on already prepared input;
- avoid I/O;
- avoid unrelated parsing or formatting;
- expose a result to a sink so useful computation cannot be discarded;
- use enough operations per sample to make timer overhead negligible.

Each benchmark should report at least:

- number of operations;
- total elapsed time;
- nanoseconds per operation;
- throughput in million operations per second.

Repeated measurements are preferred over one-shot measurements.

Harness-floor measurements may be reported to show the cost of input access
and result fingerprinting. They are contextual measurements and must not be
blindly subtracted from kernel timings.

## Scalars

`double` is the normative benchmark scalar because it is the normative
reference precision of the library.

`float` and `real` may be benchmarked separately where their behaviour is
relevant.

## Reference implementations

External implementations are benchmark references, not runtime dependencies.

Comparisons must measure equivalent mathematical kernels in-process where
practical.

For example:

- geodesy-d EPSG 9602 versus the corresponding PROJ C API operation;
- future geodesics versus GeographicLib.

Command-line process startup, text parsing and other unrelated overhead must not
be included in kernel comparisons.

## Reproducibility

A reported benchmark should record:

- geodesy-d commit;
- CPU;
- operating system;
- compiler and compiler version;
- D frontend version;
- build configuration;
- sample count;
- repetition count.

Machine-to-machine absolute timing comparisons should be treated cautiously.

Performance regressions should primarily be evaluated on the same machine and
toolchain.

## EPSG 9602 hybrid reverse benchmark

The hybrid reverse kernel introduced by ADR-0005 was benchmarked against:

- the previous geodesy-d Bowring/iterative implementation;
- PROJ 9.7.1;
- GeographicLib 2.7.

The external implementations are benchmark references only. They are not
`geodesy-d` build or runtime dependencies.

### Controlled reference environment

The final reference run used:

~~~text
date:               2026-09-14
CPU:                Intel Core i7-9750H
compiler:           LDC 1.41.0
D frontend:         2.111.0
LLVM:               19.1.7
build:              release, -mcpu=native
PROJ:               9.7.1
GeographicLib:      2.7
CPU affinity:       logical CPU 2
SMT sibling:        logical CPU 8
intel_pstate:       performance governor
Turbo:              disabled
maximum frequency:  2.6 GHz
operations:         250000 per corpus
rounds:             21
~~~

Inputs were prepared before timing.

Each round rotated implementation order to avoid assigning systematic
frequency, cache, or thermal effects to one implementation.

The reported `ns/op` values are bulk-throughput measurements. They must not be
interpreted as true single-operation dependency-chain latency.

### Surface-normal corpus

Ordinary geodetic positions with ellipsoidal heights from -1 km through
+10 km:

~~~text
implementation          median ns/op    p25       p75
geodesy-d                   162.740     162.587   163.229
Bowring baseline            376.096     375.586   376.777
PROJ 9.7.1                  154.018     153.478   154.264
GeographicLib 2.7           283.868     283.557   284.394
~~~

Relative to the current hybrid:

~~~text
current / Bowring        = 0.433x
current / PROJ           = 1.057x
current / GeographicLib  = 0.573x
~~~

Thus the hybrid is approximately:

~~~text
2.31x faster than the previous Bowring implementation
1.74x faster than GeographicLib 2.7
5.7% slower than PROJ 9.7.1
~~~

### Full terrestrial corpus

The public terrestrial validation height domain, from -20 km through +100 km:

~~~text
implementation          median ns/op    p25       p75
geodesy-d                   162.871     162.487   163.394
Bowring baseline            436.999     435.868   437.696
PROJ 9.7.1                  153.488     153.306   154.343
GeographicLib 2.7           283.107     282.520   284.296
~~~

Relative to the current hybrid:

~~~text
current / Bowring        = 0.373x
current / PROJ           = 1.061x
current / GeographicLib  = 0.575x
~~~

Thus the hybrid is approximately:

~~~text
2.68x faster than the previous Bowring implementation
1.74x faster than GeographicLib 2.7
6.1% slower than PROJ 9.7.1
~~~

### Extended-normal corpus

A wider height range exercises positions outside the normal terrestrial
contract:

~~~text
implementation          median ns/op    p25       p75
geodesy-d                   330.407     330.241   330.547
Bowring baseline            497.098     496.913   497.586
PROJ 9.7.1                  153.418     153.136   153.520
GeographicLib 2.7           283.392     283.274   283.820
~~~

The extended-normal corpus is substantially more expensive for the hybrid than
the ordinary terrestrial corpora. The benchmark does not instrument path
selection, so no specific branch is identified as the cause of that increase.

### Interior-cusp corpus

The difficult near-evolute and deep-interior corpus produced:

~~~text
implementation          median ns/op    p25       p75
geodesy-d                   335.641     335.239   336.451
Bowring baseline            942.072     940.660   944.358
PROJ 9.7.1                  154.662     154.315   155.329
GeographicLib 2.7           285.192     284.442   286.213
~~~

This corpus is intentionally outside the ordinary surface-performance target.

It is also semantically significant: the geodesy-d and GeographicLib result
checksums agree to the precision printed by the benchmark, while Bowring and
PROJ produce different aggregate checksums. This is consistent with the
separately validated differences in deep-interior inverse semantics.

### Equatorial-degenerate corpus

Exact equatorial interior positions with:

~~~text
Z = 0
horizontal <= a * e^2
~~~

are routed directly to the analytic degenerate branch.

The measured result was:

~~~text
implementation          median ns/op    p25       p75
geodesy-d                   155.537     154.486   155.954
Bowring baseline            649.485     646.158   651.633
PROJ 9.7.1                  122.811     121.834   123.283
GeographicLib 2.7           158.059     156.983   158.850
~~~

This is not a measurement of the complete generic robust fallback. It measures
the dedicated analytic equatorial-degenerate branch.

### Float working-precision cost

The public `float` inverse uses `double` internally.

To isolate the cost of that policy, `float` and `double` were benchmarked on
the same float-quantized ECEF information in alternating measurement order.

~~~text
float API:
    median = 171.330 ns/op
    p25    = 170.612 ns/op
    p75    = 171.733 ns/op

double API:
    median = 169.454 ns/op
    p25    = 168.860 ns/op
    p75    = 169.619 ns/op

float / double = 1.011x
~~~

The double-working-precision policy therefore adds approximately one percent
to public float reverse-conversion cost in this benchmark.

### CPU-frequency sensitivity

Earlier same-machine runs produced substantially lower absolute times while
preserving nearly the same ratios against the Bowring baseline and GeographicLib.
The CPU frequency state was not recorded during those timed sections, so those
runs are not used as the controlled absolute reference.

The controlled reference run above deliberately used:

~~~text
intel_pstate no_turbo = 1
maximum frequency     = 2.6 GHz
~~~

Absolute `ns/op` values are therefore hardware- and frequency-state-specific.

The primary performance conclusion is the relative same-process comparison,
not the absolute nanosecond value.


## Transverse Mercator performance baseline

The generic Transverse Mercator implementation was benchmarked after completion
of the mandatory numerical, boundary, scalar, API/runtime, and reverse-Newton
validation gates.

The benchmark implementation is in:

~~~text
benchmarks/tm-reference/
tools/benchmark-tm.sh
~~~

It measures bulk throughput through the public projection API. Reported
`ns/op` values are amortized bulk-throughput measurements, not isolated
single-operation dependency-chain latency.

### Controlled environment

The controlled reference run used:

~~~text
date:               2026-09-16
geodesy-d commit:   53e133a439491bd3e3d7439e5357d51131b33303
CPU:                Intel Core i7-9750H
logical CPU:        5
SMT sibling:        logical CPU 11, offline
compiler:           LDC 1.41.0
D frontend:         2.111.0
LLVM:               19.1.7
C++ compiler:       GCC 15.2.0
PROJ:               9.7.1
GeographicLib:      2.7
D build:            release, -O3, -mcpu=native
C++ build:          -O3 -DNDEBUG -march=native -std=c++17
intel_pstate:       active
governor:           performance
minimum frequency:  2.6 GHz
maximum frequency:  2.6 GHz
Turbo:              disabled
samples/corpus:     16384
timed rounds:       21
~~~

CPU 5 was chosen because its SMT sibling, logical CPU 11, was offline. This
avoids simultaneous sibling-thread execution on the benchmarked physical core.

The CPU frequency was fixed at 2.6 GHz for the controlled measurement and the
previous CPU-frequency state was restored after the benchmark.

### Corpora

Three deterministic corpora were measured:

~~~text
UTM-like:     abs(delta longitude) <= 3 degrees
ordinary TM:  abs(delta longitude) <= 35 degrees
wide TM:      35 <= abs(delta longitude) <= 60 degrees
~~~

The benchmark projection was WGS 84 with:

~~~text
latitude of natural origin:   0 degrees
longitude of natural origin: 15 degrees
scale factor:                 0.9996
false easting:                500000 m
false northing:               0 m
~~~

Input construction and reverse-fixture generation occurred before timed
sections.

### Native geodesy-d throughput

Controlled-run medians were:

~~~text
scalar   corpus       forward ns/op   reverse ns/op

float    UTM-like          405.988        626.843
float    ordinary          429.553        645.959
float    wide              445.630        662.488

double   UTM-like          414.105        641.479
double   ordinary          436.700        658.618
double   wide              453.107        675.439

real     UTM-like         1045.038       1437.952
real     ordinary         1084.998       1457.428
real     wide             1206.018       1509.851
~~~

`double` remains the normative performance scalar. The `float` and `real`
measurements characterize the public scalar-specific API paths.

### Same-process binary64 reference comparison

The binary64 comparison used the same prepared coordinates and measured:

- geodesy-d `double`;
- GeographicLib 2.7 `TransverseMercator`;
- GeographicLib 2.7 `TransverseMercatorExact`;
- PROJ 9.7.1 `tmerc` with `+algo=poder_engsager`.

The controlled-run medians were:

~~~text
UTM-like forward:
    geodesy-d              413.849 ns/op
    GeographicLib Series   558.875 ns/op   1.350x geodesy-d
    GeographicLib Exact   4109.821 ns/op   9.931x geodesy-d
    PROJ                   257.251 ns/op   0.622x geodesy-d

UTM-like reverse:
    geodesy-d              640.778 ns/op
    GeographicLib Series   702.197 ns/op   1.096x geodesy-d
    GeographicLib Exact   3602.722 ns/op   5.622x geodesy-d
    PROJ                   301.300 ns/op   0.470x geodesy-d

ordinary forward:
    geodesy-d              436.707 ns/op
    GeographicLib Series   593.372 ns/op   1.359x geodesy-d
    GeographicLib Exact   4552.808 ns/op  10.425x geodesy-d
    PROJ                   274.615 ns/op   0.629x geodesy-d

ordinary reverse:
    geodesy-d              657.837 ns/op
    GeographicLib Series   716.095 ns/op   1.089x geodesy-d
    GeographicLib Exact   4181.439 ns/op   6.356x geodesy-d
    PROJ                   316.309 ns/op   0.481x geodesy-d

wide forward:
    geodesy-d              452.966 ns/op
    GeographicLib Series   622.223 ns/op   1.374x geodesy-d
    GeographicLib Exact   4811.298 ns/op  10.622x geodesy-d
    PROJ                   284.985 ns/op   0.629x geodesy-d

wide reverse:
    geodesy-d              674.213 ns/op
    GeographicLib Series   742.279 ns/op   1.101x geodesy-d
    GeographicLib Exact   4701.941 ns/op   6.974x geodesy-d
    PROJ                   319.690 ns/op   0.474x geodesy-d
~~~

These ratios compare public in-process hot paths. They are performance evidence,
not an API or numerical-quality ranking.

### Numerical preflight

Before timing, the reference harness compares all implementations on the
prepared benchmark coordinates.

For geodesy-d versus GeographicLib Exact, maximum observed errors in the
controlled run were:

~~~text
corpus       forward projected error   reverse ground error

UTM-like          9.31322575e-09 m        7.08935191e-09 m
ordinary          7.46511833e-09 m        7.19805980e-09 m
wide              2.04467200e-08 m        6.56011237e-09 m
~~~

The preflight is only a benchmark sanity check. The normative numerical
accuracy evidence remains the dedicated Transverse Mercator validation suite.

### Reproducibility

A second independently timed run was executed under the same controlled
CPU/compiler/frequency configuration.

Across all native scalar/corpus/direction medians and all same-process
reference medians, the largest absolute run-to-run median difference was:

~~~text
1.40 %
~~~

The worst case was:

~~~text
native double ordinary reverse
run 1: 658.618 ns/op
run 2: 667.828 ns/op
delta: +1.40 %
~~~

All measured median differences were below the predeclared 3 % reproducibility
threshold.

The geodesy-d medians inside the same-process binary64 reference comparison
were especially stable:

~~~text
UTM-like forward:   +0.18 %
UTM-like reverse:   +0.18 %
ordinary forward:   +0.06 %
ordinary reverse:   +0.28 %
wide forward:       -0.03 %
wide reverse:       +0.20 %
~~~

Together with the tightly clustered within-run quartiles in the controlled
measurement, this establishes the reproducible LDC release performance
baseline required by Gate TM-F.


## Ellipsoidal Geodesic performance

The public ellipsoidal geodesic implementation was benchmarked after completion
of the direct/inverse numerical and API validation work.

The benchmark implementation is in:

~~~text
benchmarks/geodesic-reference/
tools/benchmark-geodesic.sh
~~~

It measures bulk throughput through a prepared `Geodesic!double` solver and
compares the public hot paths in-process against:

- GeographicLib 2.7 `Geodesic`;
- PROJ 9.7.1 geodesic API.

The external implementations are benchmark references only. They are not
`geodesy-d` build or runtime dependencies.

Reported `ns/op` values are amortized bulk-throughput measurements, not true
single-operation dependency-chain latency.

### Corpora

The direct benchmark contains:

~~~text
ordinary-global
short
long
~~~

The inverse benchmark contains:

~~~text
ordinary-global
short
meridional
equatorial
polar
near-antipodal
~~~

These corpora intentionally exercise materially different public paths and are
reported separately rather than collapsed into one aggregate timing.

### Numerical preflight

Every prepared corpus is checked against GeographicLib and PROJ before timing.

The canonical pre-static and optimized binaries produced identical numerical
preflight output.

Representative maxima include:

~~~text
direct ordinary vs GeographicLib:
    latitude:   6.661e-16 rad
    longitude:  1.044e-14 rad
    azimuth:    9.548e-15 rad

inverse ordinary vs GeographicLib:
    distance:   7.451e-09 m
    azimuth 1:  8.882e-15 rad
    azimuth 2:  9.326e-15 rad

inverse near-antipodal vs GeographicLib:
    distance:   7.451e-09 m
    azimuth 1:  8.206e-14 rad
    azimuth 2:  8.260e-14 rad
~~~

The short inverse corpus has an approximately `9.309e-10 rad` maximum azimuth
difference in this benchmark.

The preflight is a benchmark sanity check. Normative correctness evidence
remains in the dedicated geodesic validation suite.

### PROJ 9.7.1 inverse azimuth units

PROJ 9.7.1 requires special handling in the inverse benchmark adapter.

`proj_geod()` inverse azimuth outputs originate from `geod_inverse()` and are
degrees, while `proj_geod_direct()` converts its angular outputs to radians.

The benchmark therefore converts inverse azimuth outputs only during numerical
preflight and leaves the native timed PROJ kernel unchanged.

The second `geod_inverse()` azimuth is the forward azimuth at the second point,
matching `geodesy-d` `finalAzimuth` semantics.

### Pre-optimization baseline

The original geodesic baseline production source is commit:

~~~text
9d86d8d
~~~

Commit `8cffde4` added the isolated profiling harness without changing
production source and was used to rebuild the canonical pre-static comparison
binary.

An earlier five-process baseline recorded the following process-median values:

~~~text
corpus                     geodesy-d    GeographicLib 2.7    PROJ 9.7.1
                            ns/op        ns/op                  ns/op

DIRECT ordinary-global       612.506       673.340               673.755
DIRECT short                 570.593       628.510               627.692
DIRECT long                  616.345       675.824               675.983

INVERSE ordinary-global     1701.593      1885.352              1836.823
INVERSE short                940.979      1030.463              1023.346
INVERSE meridional           344.659       486.218               466.864
INVERSE equatorial           161.212       267.261               277.289
INVERSE polar                396.533       482.092               468.097
INVERSE near-antipodal      1294.141      1331.201              1309.589
~~~

That historical run recorded logical CPU 5, `performance` governor, fixed
2.6 GHz limits and Turbo disabled. Its SMT sibling state was not captured in
the benchmark log and must therefore not be treated as independently verified.

The later canonical paired comparison below supersedes that evidence for
optimization assessment.

### Profiling

An isolated `INVERSE / ordinary-global` profiling mode was added after the
baseline.

The initial profile identified the dominant costs as:

~~~text
geodesicLambda12
fillCSeriesLike
atan/atan2
geodesicLengths
geodesicCanonicalInverse
~~~

The profile showed that repeated construction/evaluation of fixed-order
coefficient series was a substantial avoidable cost.

### Accepted optimization — fixed-order C series

Commit:

~~~text
9d30331
~~~

specializes the fixed-order geodesic C-series evaluation at compile time while
preserving the arithmetic ordering of the existing formulas.

The change includes compile-time specialization of the integer-polynomial
evaluation and fixed-order C1/C1p/C2 coefficient filling.

DMD and LDC unit tests passed after the change, and benchmark numerical
preflight remained unchanged.

A controlled isolated ordinary-inverse profile previously showed approximately:

~~~text
cycles:       -13.8 %
instructions: -27.8 %
branches:     -36.0 %
~~~

The former `fillCSeriesLike` hotspot disappeared from the optimized profile.

### Canonical paired A/B measurement

The final optimization comparison was run on 2026-09-19.

Production-source relationship:

~~~text
baseline production:         9d86d8d
baseline/profile harness:    8cffde4

optimized production:        9d30331
benchmark instrumentation:   42f7ae0
~~~

The harness commits do not change the corresponding production source.

Environment:

~~~text
CPU:                Intel Core i7-9750H
logical CPU:        5
thread_siblings:    5
compiler:           LDC 1.41.0
D frontend:         2.111.0
LLVM:               19.1.7
C++ compiler:       GCC 15.2.0
GeographicLib:      2.7
PROJ:               9.7.1
D build:            release, -O3, -mcpu=native
C++ build:          -O3 -DNDEBUG -march=native -std=c++17
governor:           performance
minimum frequency:  2.6 GHz
maximum frequency:  2.6 GHz
Turbo:              disabled
samples/corpus:     16384
timed rounds:       21
paired processes:   5 baseline + 5 optimized
~~~

The process order alternated baseline/optimized.

Before every process, the measurement verified:

~~~text
thread_siblings_list == 5
governor             == performance
minimum frequency    == 2.6 GHz
maximum frequency    == 2.6 GHz
intel no_turbo       == 1
~~~

Each process additionally had to satisfy predeclared runtime health gates:

~~~text
task-clock / wall time >= 0.995
0.995 <= cycles / ref-cycles <= 1.005
CPU migrations == 0
core thermal-throttle delta == 0
package thermal-throttle delta == 0
~~~

All ten measured processes passed.

Observed `cycles / ref-cycles` was `1.000754` in every measured process.

The numerical preflight was identical between baseline and optimized binaries.

Median-of-five process medians:

~~~text
corpus                           baseline    optimized      delta
                                 ns/op       ns/op

DIRECT ordinary-global           608.472      561.945      -7.65 %
DIRECT short                     566.058      522.546      -7.69 %
DIRECT long                      612.372      567.560      -7.32 %

INVERSE ordinary-global         1677.600     1449.591     -13.59 %
INVERSE short                    933.496      810.291     -13.20 %
INVERSE meridional               342.285      284.711     -16.82 %
INVERSE equatorial               159.137      157.428      -1.07 %
INVERSE polar                    392.847      331.702     -15.56 %
INVERSE near-antipodal          1274.683     1121.863     -11.99 %
~~~

Paired-median deltas independently gave:

~~~text
DIRECT ordinary-global           -7.66 %
DIRECT short                     -7.87 %
DIRECT long                      -7.96 %

INVERSE ordinary-global        -13.55 %
INVERSE short                  -13.30 %
INVERSE meridional             -16.82 %
INVERSE equatorial              -1.49 %
INVERSE polar                  -15.58 %
INVERSE near-antipodal         -12.16 %
~~~

The external-reference paired medians remained within approximately
`-0.02 % .. +1.60 %` for GeographicLib and `-0.01 % .. +0.88 %` for PROJ.

The optimization therefore produces a broad and reproducible reduction in
`geodesy-d` execution time under the controlled same-machine workload. The
equatorial inverse path shows only a small measured change.

These measurements are evidence for this machine, toolchain, build
configuration and benchmark corpus. They are not a general performance ranking
of geodesic implementations.

### Rejected optimization experiments

Two subsequent experiments were not accepted.

#### Additional A1/A2/A3/C3 source specialization

Further compile-time specialization of A1, A2, A3 and C3 source expressions
passed DMD/LDC tests but produced no performance-relevant LDC machine-code
change.

The experiment was rejected because it added implementation complexity without
measurable generated-code benefit.

#### Reduced-latitude normalization without `hypot`

A bounded inverse-dispatch experiment replaced the robust reduced-latitude
`hypot` normalization with direct `sqrt(x*x + y*y)` evaluation.

LLVM produced materially smaller code and combined the two normalizations into
packed-double SIMD operations.

An isolated ordinary-inverse measurement showed:

~~~text
instructions: approximately -0.67 %
branches:     approximately -0.96 %
cycles:       no stable improvement
~~~

The full benchmark matrix additionally showed a reproducible approximately
5 % regression in the equatorial inverse corpus and a smaller polar regression.

The experiment was therefore rejected despite its simpler generated code.

### Measurement disturbance note

One attempted post-optimization five-process run exhibited a transient
machine-wide approximately twofold timing slowdown affecting `geodesy-d`,
GeographicLib and PROJ simultaneously.

The cause was not instrumented during that occurrence, so no thermal,
frequency or scheduling cause is claimed.

That run is non-canonical and is not included in the reported optimization
results.

Subsequent instrumented runs verified stable effective cycle rate, essentially
full task/wall CPU occupancy, zero CPU migrations and no increase in thermal
throttle counters.

### Current optimization boundary

After the accepted fixed-order series specialization, the remaining dominant
profile costs are primarily:

~~~text
geodesicLambda12
atan/atan2
geodesicLengths
geodesicCanonicalInverse
sin/cos
normalization / hypot
~~~

The low-risk structural series opportunity has therefore been addressed.

Further changes in these remaining kernels would alter or closely interact with
numerically sensitive trigonometric, normalization or solver arithmetic.
No additional production optimization is justified before a new profile or a
concrete consumer demonstrates a material need.

## Pseudo-Mercator PM-E1C1 reverse research benchmark

PM-E1C1B includes a research-only performance qualification for the
extended-precision `real` reverse-latitude specialization.

Correctness and numerical selection were completed before this performance
comparison.

The measured question is deliberately narrow:

~~~text
baseline:
    selected R6 reverse-latitude evaluation
    without quotient-residual correction

selected:
    same R6 evaluation
    plus the optimized quotient-residual correction
~~~

The correction reconstructs the residual of the already-computed quotient and
uses the R6 `expm1(abs(q))` intermediate to obtain `sech(q)` without an
additional transcendental evaluation.

### Reproducible harness

The benchmark kernel is part of the Pseudo-Mercator research probe:

~~~text
research/pseudo-mercator/pm_e1_kernel_probe.d
~~~

and is enabled only with:

~~~text
PseudoMercatorReverseBenchmark
~~~

The controlled compiler-matrix runner is:

~~~text
research/pseudo-mercator/benchmark_pm_e1c1_reverse.py
~~~

Typical invocation:

~~~sh
python3 research/pseudo-mercator/benchmark_pm_e1c1_reverse.py
~~~

The runner:

- uses explicit project-controlled compiler names;
- builds DMD and LDC separately;
- uses release/optimized compilation;
- pins each process to one logical CPU;
- prepares the corpus before the timed region;
- runs 21 repetitions per profile;
- alternates baseline-selected and selected-baseline execution order;
- records raw process output under `/tmp` by default;
- verifies that every timed reverse operation succeeds.

The two qualifying profiles are:

~~~text
wgs84_zero:
    a       = 6378137
    lon0    = 0 degrees
    FE      = 0
    FN      = 0

offset_p170:
    a       = 6378137
    lon0    = +170 degrees
    FE      = +500000
    FN      = -2000000
~~~

Each measured result contains:

~~~text
32768 prepared projected coordinates
8 measured passes
262144 reverse operations per timing
21 repetitions
~~~

The qualifying durable run on 2026-09-25 used:

~~~text
Linux 6.17.0-22-generic x86_64
logical benchmark CPU: 0

DMD 2.111.0
DMD 2.112.1
DMD 2.113.0

LDC 1.41.0   frontend 2.111.0   LLVM 20.1.5
LDC 1.42.0   frontend 2.112.1   LLVM 21.1.8
LDC 1.43.0   frontend 2.113.0   LLVM 22.1.8
~~~

All six compiler configurations built and completed both profiles.

Each compiler output contained:

~~~text
META rows:     2
RESULT rows:  42
FAIL rows:     0
SINK rows:     1
~~~

### Selected-correction overhead

Median paired overhead of the selected residual correction:

~~~text
compiler       offset_p170    wgs84_zero

DMD 2.111.0      +12.867 %      +16.407 %
DMD 2.112.1      +14.587 %      +16.135 %
DMD 2.113.0      +12.538 %      +15.165 %

LDC 1.41.0        +3.028 %       +3.963 %
LDC 1.42.0        +4.520 %       +6.089 %
LDC 1.43.0        +5.705 %       +5.100 %
~~~

LDC release builds are the normative project performance configuration.

The selected correction therefore adds approximately three to six percent in
the qualified LDC workload.

The correction is retained because the broad exact `real` corpus improves from
an observed four-ULP worst case without the correction to three ULP with the
selected correction, while avoiding the much larger cost of the rejected
full-quotient-expansion / additional-`cosh` implementation.

No compiler-specific numerical path is introduced.

### DMD 2.112.x diagnostic observation

The durable matrix independently reproduces the previously isolated DMD
2.112.1 absolute-performance anomaly.

Baseline medians from the durable runner:

~~~text
compiler          wgs84_zero    offset_p170
                  ns/op         ns/op

DMD 2.111.0        372.319       440.637
DMD 2.112.1        380.271      1399.867
DMD 2.113.0        367.675       448.730
~~~

The separate four-version diagnostic additionally measured DMD 2.112.0 and
established the compiler boundary:

~~~text
DMD 2.111.0    normal
DMD 2.112.0    slow
DMD 2.112.1    slow
DMD 2.113.0    normal
~~~

Factor isolation showed that the DMD 2.112.x slowdown is not specific to
longitude wrapping and is not caused by the quotient-residual correction.

Non-zero false Easting, non-zero false Northing, or non-zero longitude of
natural origin were independently sufficient to expose the slowdown in the
diagnostic corpus.

The observation is therefore treated as a DMD 2.112.x toolchain regression in
this research workload rather than as a Pseudo-Mercator algorithm defect.

No geodesy-d workaround is justified:

- numerical output is unchanged;
- the selected correction is not the root cause;
- DMD 2.113.0 no longer exhibits the regression;
- LDC is the normative performance compiler.

The complete numerical rationale, exact-corpus distribution and candidate
selection are documented in:

~~~text
research/pseudo-mercator/PM_E1C1_REVERSE_RESULTS.md
~~~

## CI

Normal CI should verify that benchmark code still builds.

Shared GitHub runners should not initially enforce absolute timing thresholds,
because machine variation makes such gates unreliable.

Performance-regression thresholds may be introduced later after measurement of
normal run-to-run variance on controlled hardware.

## Optimisation policy

Broad `@fastmath` is not a default project policy.

Numerical transformations must not trade away documented correctness or
accuracy merely to improve benchmark results.

Any optimisation that changes arithmetic structure must be revalidated against
the operation's numerical reference suite.
