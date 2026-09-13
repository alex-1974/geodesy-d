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
