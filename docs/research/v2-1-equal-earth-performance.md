# Equal Earth v2.1 performance qualification

Status: benchmark source added; **no performance measurements have been made**
and no claim of C++/PROJ parity is justified.

## Reproducibility

Run on the target machine using the versioned compilers and record CPU,
operating system, release flags, compiler version, linker and run count.
Do not compare a debug D build against a release C++ build.

From the geodesy-d repository root (a writable build directory is needed):

```bash
mkdir -p build/equal-earth-bench

dmd-2.111.0 -O -release -inline -i -Isource \
  -of=build/equal-earth-bench/dmd \
  tools/benchmarks/equal_earth.d
./build/equal-earth-bench/dmd

ldc-1.41.0 -O3 -release -i -Isource \
  -of=build/equal-earth-bench/ldc \
  tools/benchmarks/equal_earth.d
./build/equal-earth-bench/ldc
```

Run each binary several times on an otherwise idle host and report the
median and dispersion, not one lucky run. The tool reports **separate**
forward and reverse operation counts, elapsed wall-clock seconds and
checksums. It cycles through four geographic test coordinates rather than
repeating one invariant input. Both modes exercise the public checked API.

Calculate operations per second per mode as `operations / elapsed_seconds`.
Do not combine both modes into one throughput number. Beware of compiler
optimizations and warm-up effects, and validate the checksums between builds.
The probe is intended for comparison, not a certified microbenchmark.

This is a baseline harness, **not** an allocation proof or an optimization
comparison. For codegen qualification, inspect symbols and generated
assembly with the actual target compiler and release flags; distinguish
checked hot-path operations from construction and error-throwing peers.

## Acceptance not yet established

- Compiler-specific release assembly inspection and allocation review.
- Repeated local timings on the intended XPS hardware.
- Independent PROJ/C++ comparison under equivalent optimization flags.
- A documented measurement report with full provenance.

Checked Equal Earth functions and the internal kernels declare
`pure nothrow @safe @nogc`; this is a compile-time attribute contract,
not by itself a proof that the complete program makes no allocations.
