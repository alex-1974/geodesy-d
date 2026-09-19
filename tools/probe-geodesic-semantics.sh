#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cxx="${CXX:-g++}"

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

src="$repo/research/geodesics/semantic_probe.cpp"
exe="$build_dir/geodesic-semantic-probe"

common=(
    -std=c++17
    -O2
    -Wall
    -Wextra
    -Wpedantic
    "$src"
    -lGeographicLib
)

echo '=== GeographicLib ==='
if command -v GeodSolve >/dev/null 2>&1; then
    GeodSolve --version || true
else
    echo 'GeodSolve not found; continuing with linked library.'
fi

echo
echo '=== PROJ ==='

proj_enabled=0

if command -v pkg-config >/dev/null 2>&1 \
    && pkg-config --exists proj \
    && printf '%s\n' \
        '#include <geodesic.h>' \
        'int main() {' \
        '  geod_geodesic g;' \
        '  geod_init(&g, 6378137.0, 1.0 / 298.257223563);' \
        '  return 0;' \
        '}' \
        | "$cxx" \
            -std=c++17 \
            -x c++ - \
            $(pkg-config --cflags --libs proj) \
            -o "$build_dir/proj-geodesic-check" \
            >/dev/null 2>&1
then
    proj_enabled=1
    echo "PROJ $(pkg-config --modversion proj): geodesic C API enabled"
else
    if command -v pkg-config >/dev/null 2>&1 \
        && pkg-config --exists proj
    then
        echo "PROJ $(pkg-config --modversion proj): geodesic C API not linkable"
    else
        echo 'PROJ pkg-config metadata unavailable'
    fi
fi

echo
echo '=== compile semantic probe ==='

if [[ "$proj_enabled" -eq 1 ]]; then
    "$cxx" \
        "${common[@]}" \
        -DHAVE_PROJ_GEODESIC \
        $(pkg-config --cflags --libs proj) \
        -o "$exe"
else
    "$cxx" \
        "${common[@]}" \
        -o "$exe"
fi

echo 'PASS: semantic probe compiled'

echo
echo '=== run semantic probe ==='

"$exe"
