#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"
iterations="${LCC_BENCH_ITERATIONS:-200000}"

for tool in "$dc" "$cxx" pkg-config; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

pkg-config --exists proj || {
    echo "error: PROJ development package not available" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bridge_o="$tmp/lcc-benchmark-bridge.o"
binary="$tmp/lcc-benchmark"

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

read -r -a proj_cflags <<<"$(pkg-config --cflags proj)"

"$cxx"     -O3 -DNDEBUG -march=native -std=c++17     "${proj_cflags[@]}"     -c "$repo/validation/lambert_conformal_conic_benchmark_bridge.cpp"     -o "$bridge_o"

"$dc"     -release     -enable-inlining     -O3     -mcpu=native     -I"$repo/source"     "$repo/validation/lambert_conformal_conic_benchmark.d"     "${sources[@]}"     "$bridge_o"     -L-lproj     -L-lstdc++     -of="$binary"

"$binary" "$iterations"
