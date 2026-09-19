#!/usr/bin/env bash
set -euo pipefail

repo="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
    pwd
)"

bench="$repo/benchmarks/geodesic-reference"

dc="${DC:-ldc2}"
cxx="${CXX:-g++}"
cpu="${GEODESIC_BENCH_CPU:-2}"

for tool in "$dc" "$cxx" pkg-config taskset; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

pkg-config --exists geographiclib || {
    echo "error: GeographicLib development package not available" >&2
    exit 2
}

[[ -r "$bench/source/app.d" ]] || {
    echo "error: missing $bench/source/app.d" >&2
    exit 2
}

[[ -r "$bench/source/geodesic_reference_bridge.cpp" ]] || {
    echo "error: missing geodesic reference bridge" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bridge_o="$tmp/geodesic_reference_bridge.o"

binary="${GEODESIC_BENCH_BINARY:-$tmp/geodesy-d-geodesic-reference}"

mkdir -p "$(dirname "$binary")"

d_flags=(
    -release
    -enable-inlining
    -O3
    -mcpu=native
)

if [[ "${GEODESIC_BENCH_PROFILE_DEBUG:-0}" == 1 ]]; then
    d_flags+=(-g)
fi

mapfile -t geodesy_sources < <(
    find "$repo/source/geodesy" \
        -type f \
        -name '*.d' \
        -print |
    sort
)

read -r -a geographic_cflags <<<"$(
    pkg-config --cflags geographiclib
)"

echo '=== Geodesic benchmark environment ==='
printf 'date:               %s\n' \
    "$(date --iso-8601=seconds)"

printf 'geodesy-d commit:   %s\n' \
    "$(git -C "$repo" rev-parse HEAD)"

printf 'branch:             %s\n' \
    "$(git -C "$repo" branch --show-current)"

cpu_model="$(
    LC_ALL=C lscpu |
        awk -F: '/Model name/ {
            gsub(/^[ \t]+/, "", $2)
            print $2
            exit
        }'
)"

printf 'CPU:                %s\n' "$cpu_model"
printf 'kernel:             %s\n' "$(uname -srmo)"
printf 'compiler:           %s\n' "$("$dc" --version | sed -n '1p')"
printf 'D frontend / LLVM:  %s\n' \
    "$("$dc" --version | sed -n '2,3p' | tr '\n' ' ')"
printf 'C++ compiler:       %s\n' \
    "$("$cxx" --version | sed -n '1p')"
printf 'GeographicLib:      %s\n' \
    "$(pkg-config --modversion geographiclib)"
printf 'PROJ:               %s\n' \
    "$(pkg-config --modversion proj)"
printf 'build flags D:      %s\n' \
    "${d_flags[*]}"
printf 'build flags C++:    %s\n' \
    '-O3 -DNDEBUG -march=native -std=c++17'
printf 'CPU affinity:       logical CPU %s\n' "$cpu"

thread_siblings="$(
    cat \
        "/sys/devices/system/cpu/cpu${cpu}/topology/thread_siblings_list" \
        2>/dev/null ||
    echo unavailable
)"

printf 'thread siblings:    %s\n' "$thread_siblings"

governor="$(
    cat \
        "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor" \
        2>/dev/null ||
    echo unavailable
)"

no_turbo="$(
    cat \
        /sys/devices/system/cpu/intel_pstate/no_turbo \
        2>/dev/null ||
    echo unavailable
)"

scaling_min="$(
    cat         "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_min_freq"         2>/dev/null ||
    echo unavailable
)"

scaling_max="$(
    cat         "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq"         2>/dev/null ||
    echo unavailable
)"

printf 'governor:           %s\n' "$governor"
printf 'scaling min kHz:    %s\n' "$scaling_min"
printf 'scaling max kHz:    %s\n' "$scaling_max"
printf 'intel no_turbo:     %s\n' "$no_turbo"

if [[ "${GEODESIC_BENCH_REQUIRE_CONTROLLED:-0}" == 1 ]]; then
    [[ "$governor" == performance ]] || {
        echo "error: controlled run requires governor=performance (observed '$governor')" >&2
        exit 3
    }

    [[ "$no_turbo" == 1 ]] || {
        echo "error: controlled run requires intel_pstate no_turbo=1 (observed '$no_turbo')" >&2
        exit 3
    }

    if [[ "${GEODESIC_BENCH_REQUIRE_ISOLATED_CPU:-0}" == 1 \
        && "$thread_siblings" != "$cpu" ]]; then
        echo "error: isolated run requires only logical CPU $cpu in thread_siblings_list" >&2
        echo "       observed thread siblings=$thread_siblings" >&2
        exit 3
    fi

    if [[ "${GEODESIC_BENCH_REQUIRE_FIXED_FREQ:-0}" == 1         && "$scaling_min" != "$scaling_max" ]]; then
        echo "error: fixed-frequency run requires scaling_min_freq == scaling_max_freq" >&2
        echo "       observed min=$scaling_min max=$scaling_max" >&2
        exit 3
    fi
elif [[ "$governor" != performance ]]; then
    echo "warning: governor is '$governor'; development run only, not controlled baseline." >&2
fi

echo
echo '=== compiling GeographicLib/PROJ bridge ==='

"$cxx" \
    -O3 \
    -DNDEBUG \
    -march=native \
    -std=c++17 \
    "${geographic_cflags[@]}" \
    -c \
    "$bench/source/geodesic_reference_bridge.cpp" \
    -o "$bridge_o"

echo '=== compiling D benchmark ==='

"$dc" \
    "${d_flags[@]}" \
    -I"$repo/source" \
    "$bench/source/app.d" \
    "${geodesy_sources[@]}" \
    "$bridge_o" \
    -L-lGeographicLib \
    -L-lproj \
    -L-lstdc++ \
    -of="$binary"

echo

if [[ "${GEODESIC_BENCH_BUILD_ONLY:-0}" == 1 ]]; then
    echo "=== build only ==="
    echo "binary: $binary"
    exit 0
fi

runs="${GEODESIC_BENCH_RUNS:-1}"

[[ "$runs" =~ ^[1-9][0-9]*$ ]] || {
    echo "error: GEODESIC_BENCH_RUNS must be a positive integer" >&2
    exit 2
}

for ((run = 1; run <= runs; ++run)); do
    echo "=== running on logical CPU $cpu: process run $run/$runs ==="
    taskset -c "$cpu" "$binary" "$@"

    if ((run < runs)); then
        echo
    fi
done
