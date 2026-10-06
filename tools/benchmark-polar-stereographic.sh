#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"
cpu="${PS_BENCH_CPU:-2}"
iterations="${PS_BENCH_ITERATIONS:-200000}"

for tool in "$dc" "$cxx" pkg-config taskset; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

pkg-config --exists proj || {
    echo "error: PROJ development package not available" >&2
    exit 2
}

pkg-config --exists geographiclib || {
    echo "error: GeographicLib development package not available" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bridge_o="$tmp/polar-stereographic-benchmark-bridge.o"
binary="$tmp/polar-stereographic-benchmark"

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

read -r -a proj_cflags <<<"$(pkg-config --cflags proj)"
read -r -a geographic_cflags <<<"$(pkg-config --cflags geographiclib)"

echo '=== Polar Stereographic PS-G environment ==='
printf 'date:               %s\n' "$(date --iso-8601=seconds)"
printf 'geodesy-d commit:   %s\n' "$(git -C "$repo" rev-parse HEAD)"
printf 'branch:             %s\n' "$(git -C "$repo" branch --show-current)"
printf 'compiler:           %s\n' "$("$dc" --version | sed -n '1p')"
printf 'C++ compiler:       %s\n' "$("$cxx" --version | sed -n '1p')"
printf 'PROJ:               %s\n' "$(pkg-config --modversion proj)"
printf 'GeographicLib:      %s\n' "$(pkg-config --modversion geographiclib)"
printf 'CPU affinity:       logical CPU %s\n' "$cpu"
printf 'iterations:         %s\n' "$iterations"

governor="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"         2>/dev/null || echo unavailable
)"
no_turbo="$(
    cat /sys/devices/system/cpu/intel_pstate/no_turbo         2>/dev/null || echo unavailable
)"

printf 'governor:           %s\n' "$governor"
printf 'intel no_turbo:     %s\n' "$no_turbo"

if [[ "${PS_BENCH_REQUIRE_CONTROLLED:-0}" == 1 ]]; then
    [[ "$governor" == performance ]] || {
        echo "error: controlled run requires governor=performance" >&2
        exit 3
    }

    [[ "$no_turbo" == 1 ]] || {
        echo "error: controlled run requires intel_pstate no_turbo=1" >&2
        exit 3
    }
elif [[ "$governor" != performance ]]; then
    echo "warning: uncontrolled development run; do not record as PS-G baseline." >&2
fi

echo
echo '=== compiling C++ reference bridge ==='
"$cxx"     -O3 -DNDEBUG -march=native -std=c++17     "${proj_cflags[@]}"     "${geographic_cflags[@]}"     -c "$repo/validation/polar_stereographic_benchmark_bridge.cpp"     -o "$bridge_o"

echo '=== compiling D benchmark ==='
"$dc"     -release     -enable-inlining     -O3     -mcpu=native     -I"$repo/source"     "$repo/validation/polar_stereographic_benchmark.d"     "${sources[@]}"     "$bridge_o"     -L-lGeographicLib     -L-lproj     -L-lstdc++     -of="$binary"

echo
echo "=== running on logical CPU $cpu ==="
taskset -c "$cpu" "$binary" "$iterations"
