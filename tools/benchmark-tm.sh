#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$repo/benchmarks/tm-reference"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"
cpu="${TM_BENCH_CPU:-2}"

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

[[ -r "$bench/source/app.d" ]] || {
    echo "error: missing $bench/source/app.d" >&2
    exit 2
}
[[ -r "$bench/source/tm_reference_bridge.cpp" ]] || {
    echo "error: missing $bench/source/tm_reference_bridge.cpp" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
bridge_o="$tmp/tm_reference_bridge.o"
binary="$tmp/geodesy-d-tm-reference"

mapfile -t geodesy_sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

read -r -a proj_cflags <<<"$(pkg-config --cflags proj)"
read -r -a geographic_cflags <<<"$(pkg-config --cflags geographiclib)"

echo '=== TM-F environment ==='
printf 'date:               %s\n' "$(date --iso-8601=seconds)"
printf 'geodesy-d commit:   %s\n' "$(git -C "$repo" rev-parse HEAD)"
cpu_model="$(
    LC_ALL=C lscpu |
        awk -F: '/Model name/ {
            gsub(/^[ \\t]+/, "", $2)
            print $2
            exit
        }'
)"

if [[ -z "$cpu_model" ]]; then
    cpu_model="$(
        awk -F: '/model name/ {
            gsub(/^[ \\t]+/, "", $2)
            print $2
            exit
        }' /proc/cpuinfo
    )"
fi

printf 'CPU:                %s\n' "$cpu_model"
printf 'kernel:             %s\n' "$(uname -srmo)"
printf 'compiler:           %s\n' "$("$dc" --version | sed -n '1p')"
printf 'D frontend / LLVM:  %s\n' "$("$dc" --version | sed -n '2,3p' | tr '\n' ' ')"
printf 'C++ compiler:       %s\n' "$("$cxx" --version | sed -n '1p')"
printf 'PROJ:               %s\n' "$(pkg-config --modversion proj)"
printf 'GeographicLib:      %s\n' "$(pkg-config --modversion geographiclib)"
printf 'build flags D:      %s\n' '-release -enable-inlining -O3 -mcpu=native'
printf 'build flags C++:    %s\n' '-O3 -DNDEBUG -march=native -std=c++17'
printf 'CPU affinity:       logical CPU %s\n' "$cpu"

governor="$(cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor" 2>/dev/null || echo unavailable)"
no_turbo="$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo unavailable)"
printf 'governor:           %s\n' "$governor"

scaling_driver="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_driver"         2>/dev/null ||
    echo unavailable
)"

scaling_min="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_min_freq"         2>/dev/null ||
    echo unavailable
)"

scaling_max="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_max_freq"         2>/dev/null ||
    echo unavailable
)"

cpuinfo_max="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/cpuinfo_max_freq"         2>/dev/null ||
    echo unavailable
)"

intel_pstate_status="$(
    cat /sys/devices/system/cpu/intel_pstate/status         2>/dev/null ||
    echo unavailable
)"

printf 'scaling driver:     %s\n' "$scaling_driver"
printf 'intel_pstate:       %s\n' "$intel_pstate_status"
printf 'scaling min kHz:    %s\n' "$scaling_min"
printf 'scaling max kHz:    %s\n' "$scaling_max"
printf 'cpuinfo max kHz:    %s\n' "$cpuinfo_max"
printf 'intel no_turbo:     %s\n' "$no_turbo"

if [[ "${TM_BENCH_REQUIRE_CONTROLLED:-0}" == 1 ]]; then
    [[ "$governor" == performance ]] || {
        echo "error: controlled run requires governor=performance (observed '$governor')" >&2
        exit 3
    }
    [[ "$no_turbo" == 1 ]] || {
        echo "error: controlled run requires intel_pstate no_turbo=1 (observed '$no_turbo')" >&2
        exit 3
    }
    if [[ "${TM_BENCH_REQUIRE_FIXED_FREQ:-0}" == 1         && "$scaling_min" != "$scaling_max" ]]; then
        echo "error: fixed-frequency run requires scaling_min_freq == scaling_max_freq" >&2
        echo "       observed min=$scaling_min max=$scaling_max" >&2
        exit 3
    fi
elif [[ "$governor" != performance ]]; then
    echo "warning: governor is '$governor'; development run only, not controlled TM-F baseline." >&2
fi

echo
echo '=== compiling C++ reference bridge ==='
"$cxx" \
    -O3 -DNDEBUG -march=native -std=c++17 \
    "${proj_cflags[@]}" \
    "${geographic_cflags[@]}" \
    -c "$bench/source/tm_reference_bridge.cpp" \
    -o "$bridge_o"

echo '=== compiling D benchmark ==='
"$dc" \
    -release \
    -enable-inlining \
    -O3 \
    -mcpu=native \
    -I"$repo/source" \
    "$bench/source/app.d" \
    "${geodesy_sources[@]}" \
    "$bridge_o" \
    -L-lGeographicLib \
    -L-lproj \
    -L-lstdc++ \
    -of="$binary"

echo
echo "=== running on logical CPU $cpu ==="
taskset -c "$cpu" "$binary"
