#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cpu="${M3_BENCH_CPU:-2}"
iterations="${M3_BENCH_ITERATIONS:-1000000}"
output="${M3_BENCH_OUTPUT:-$repo/build/m3-benchmark-baseline.txt}"

for tool in taskset git ldc2 g++ pkg-config; do
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

governor="$(
    cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"         2>/dev/null || echo unavailable
)"
no_turbo="$(
    cat /sys/devices/system/cpu/intel_pstate/no_turbo         2>/dev/null || echo unavailable
)"

[[ "$governor" == performance ]] || {
    echo "error: M3 baseline requires governor=performance; got '$governor'" >&2
    exit 3
}

[[ "$no_turbo" == 1 ]] || {
    echo "error: M3 baseline requires intel_pstate no_turbo=1; got '$no_turbo'" >&2
    exit 3
}

mkdir -p "$(dirname "$output")"

{
    echo "=== geodesy-d M3 controlled performance baseline ==="
    printf 'date:             %s\n' "$(date --iso-8601=seconds)"
    printf 'commit:           %s\n' "$(git -C "$repo" rev-parse HEAD)"
    printf 'branch:           %s\n' "$(git -C "$repo" branch --show-current)"
    printf 'kernel:           %s\n' "$(uname -srmo)"
    printf 'CPU:              %s\n' "$(lscpu | sed -n 's/^Model name:[[:space:]]*//p' | head -n1)"
    printf 'logical CPU:      %s\n' "$cpu"
    printf 'governor:         %s\n' "$governor"
    printf 'intel no_turbo:   %s\n' "$no_turbo"
    printf 'LDC:              %s\n' "$(ldc2 --version | sed -n '1p')"
    printf 'C++:              %s\n' "$(g++ --version | sed -n '1p')"
    printf 'PROJ:             %s\n' "$(pkg-config --modversion proj)"
    printf 'GeographicLib:    %s\n' "$(pkg-config --modversion geographiclib)"
    printf 'iterations/family:%s\n' "$iterations"
    echo

    echo "=== Rhumb / RhumbLine ==="
    RHUMB_BENCH_ITERATIONS="$iterations"         taskset -c "$cpu" bash "$repo/tools/benchmark-rhumb.sh"
    echo

    echo "=== Polar Stereographic ==="
    PS_BENCH_CPU="$cpu"     PS_BENCH_ITERATIONS="$iterations"     PS_BENCH_REQUIRE_CONTROLLED=1         bash "$repo/tools/benchmark-polar-stereographic.sh"
    echo

    echo "=== Lambert Conformal Conic 2SP ==="
    LCC_BENCH_ITERATIONS="$iterations"         taskset -c "$cpu" bash "$repo/tools/benchmark-lambert-conformal-conic.sh"
    echo

    echo "=== Lambert Azimuthal Equal Area ==="
    LAEA_BENCH_ITERATIONS="$iterations"         taskset -c "$cpu" bash "$repo/tools/benchmark-lambert-azimuthal-equal-area.sh"
    echo
} | tee "$output"

echo
echo "M3 controlled baseline written to:"
echo "  $output"
