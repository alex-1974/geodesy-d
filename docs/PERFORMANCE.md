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

Future algorithms, including Transverse Mercator, UTM and ellipsoidal
geodesics, must acquire benchmarks as part of their implementation.

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
