#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"
iterations="${RHUMB_BENCH_ITERATIONS:-200000}"

for tool in "$dc" "$cxx" pkg-config; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

pkg-config --exists geographiclib || {
    echo "error: GeographicLib development package not available" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bridge_o="$tmp/rhumb-benchmark-bridge.o"
binary="$tmp/rhumb-benchmark"

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

read -r -a geographic_cflags <<<"$(pkg-config --cflags geographiclib)"

"$cxx"     -O3 -DNDEBUG -march=native -std=c++17     "${geographic_cflags[@]}"     -c "$repo/validation/rhumb_benchmark_bridge.cpp"     -o "$bridge_o"

"$dc"     -release     -enable-inlining     -O3     -mcpu=native     -I"$repo/source"     "$repo/validation/rhumb_benchmark.d"     "${sources[@]}"     "$bridge_o"     -L-lGeographicLib     -L-lstdc++     -of="$binary"

"$binary" "$iterations"
