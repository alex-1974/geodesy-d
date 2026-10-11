# Equal Earth v2.1 release-mode codegen inspection

This is a **reproducible inspection recipe**, not an assertion that a
machine-code audit has already passed. It supplements the compiler-checked
`pure nothrow @safe @nogc` contract on the public checked path.

## Candidate and compiler provenance

Review the exact `release/2.1` candidate commit and record the full SHA.
Run separately for the pinned baseline DMD 2.111.0 and LDC 1.41.0, both
official controlled distributions (not the Ubuntu-packaged substitutes).
Do not change the source or introduce `-boundscheck=off` solely for this gate.

## Reproducible codegen build

From the repository root:

```bash
(
    set -euo pipefail
    mkdir -p build/equal-earth-codegen
    git rev-parse HEAD
    dmd-2.111.0 --version | head -n 1
    ldc-1.41.0 --version | head -n 3

    dmd-2.111.0 -O -release -inline -c -i -Isource \
        -of=build/equal-earth-codegen/equal-earth-dmd.o \
        tools/benchmarks/equal_earth.d

    ldc-1.41.0 -O3 -release -c -i -Isource \
        -of=build/equal-earth-codegen/equal-earth-ldc.o \
        tools/benchmarks/equal_earth.d

    for compiler in dmd ldc; do
        object="build/equal-earth-codegen/equal-earth-${compiler}.o"
        nm -C "${object}" > "build/equal-earth-codegen/${compiler}.nm.txt"
        objdump -drC "${object}" > "build/equal-earth-codegen/${compiler}.asm.txt"
        echo "${compiler}: object bytes=$(wc -c < "${object}")"
        echo "${compiler}: disassembly lines=$(wc -l < "build/equal-earth-codegen/${compiler}.asm.txt")"
    done
)
```

Record the compiler/linker target, CPU, assembler tool version and build
flags. Do not interpret library/runtime symbols from the *entire object*
as calls on the checked hot path: the benchmark also contains startup,
output and exception paths.

## Audit acceptance checklist

1. Compile and verify that the *public* checked methods and private kernels
   still have compiler-enforced `pure nothrow @safe @nogc` attributes.
2. Disassemble the actual checked forward and reverse kernels / call graph
   with each compiler; classify the runtime math-library calls
   (`sin`, `cos`, `asin`, `log`) and the inverse iteration/fallback.
3. Look for allocation symbols or heap/runtime calls **reachable from the
   checked call path**, distinguishing them from benchmark harness code,
   throwing convenience peers and Phobos/runtime initialization.
4. If attribution is ambiguous, compile an isolated `extern(C)` wrapper
   around the checked operations or capture perf call graphs; do not claim
   `no allocation` solely because `nm` returned no `gc_malloc` substring.
5. Record the per-compiler findings and attach the inspection evidence.
   A passing `@nogc` signature proves D GC allocation is disallowed in
   that function, **not** the absence of every C/runtime allocator.
6. Reconfirm release-mode correctness and the existing XPS throughput data.

## Current status

**Open**: target XPS assembly artifacts and per-symbol inspection were not
supplied. The project has demonstrated qualified checked API attributes,
13/13 GitHub release-candidate workflows on
`5acfd4861886b099e412060965b9298cd86cc6fd`, and a measured
Newton reverse speedup. This does **not** close the independent codegen
audit gate or authorize publishing `v2.1.0`.

No other workspace repository is modified by this recipe.

## Submitted XPS disassembly inspection (2026-10-11)

Archive: `equal-earth-codegen.tar.gz` supplied by the developer, containing
`dmd.asm.txt`, `dmd.nm.txt`, `ldc.asm.txt`, and `ldc.nm.txt`.
No raw `.o` files, compiler-version transcript or runtime allocation trace
were included, so compiler version provenance follows the proposed command,
not independent metadata in the archive.

The archive provides 55,803 DMD disassembly lines, 34,910 LDC
lines, and 937/977 symbol-table lines. Sections were isolated by
`Disassembly of section` headings and their relocation records inspected;
searching the entire object for allocation symbols would incorrectly mix
benchmark harness, formatting, exceptions and checked kernels.

| Checked-path function | DMD direct relocation observations | LDC direct relocation observations |
| --- | --- | --- |
| `tryForward` | `toAuthalic`, forward kernel, `ProjectedCoordinate.tryFromComponents` | `toAuthalic`; trigonometry inlined from forward kernel (`sin`, `asin`, `cos`) |
| `tryReverse` | reverse kernel, `fromAuthalic`, checked latitude/longitude factories | reverse kernel, `fromAuthalic` (latitude/longitude conversion optimized inline) |
| `fromAuthalic` | `authalicQ` | `sin`, `logImpl` (authalic expression partially inlined) |
| `toAuthalic` | `authalicQ`, `atan2Asm` | `sin`, `logImpl`, `asin` |
| Equal Earth forward kernel | `atan2Asm` | `sin`, `asin`, `cos` |
| Equal Earth reverse kernel | two `atan2Asm` relocations | `asin`, `sin`, `cos`, `asin` |

Neither compiler's **isolated checked-path source sections** has a direct
`gc_malloc`, `gc_qalloc` or `_d_allocclass` relocation. The full object
**does** contain allocator symbols: DMD lists unresolved `gc_malloc` and
`gc_qalloc`; LDC additionally lists `_d_allocclass`. These symbols cannot
be assigned to the checked hot path based on the global symbol table.

**Qualified conclusion:** compiler-checked `@nogc` attributes remain in
public checked signatures, and this source-section relocation inspection
found no direct GC allocator calls from the Equal Earth checked functions.
The two compilers produce materially different inlining and math-helper
calls. This is **not** proof that all math-helper transitive paths avoid
non-GC/C allocation, or that the linked executable never allocates.

**Additional evidence needed for a fully closed strict allocation gate:**
compiler-version transcript, exact git SHA of generated objects, raw object
files or isolated linked wrapper, and inspection of reachable math-helper
calls or a targeted allocation trace. In particular, `@nogc` alone cannot
establish absence of allocation by external C libraries. Do not claim a
full end-to-end allocation-free proof on the supplied archive alone.
