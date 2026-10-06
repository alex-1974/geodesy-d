#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"
cxx="${CXX:-c++}"

for tool in "$dc" "$cxx" cct; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool '$tool' not found" >&2
        exit 2
    fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

if [[ "${#sources[@]}" -eq 0 ]]; then
    echo "error: no geodesy-d source modules found" >&2
    exit 2
fi

oracle="$tmp/polar-stereographic-geographiclib-oracle"
driver="$tmp/polar-stereographic-differential"

echo "Building GeographicLib Polar Stereographic oracle..."
"$cxx"     -std=c++17     -O2     "$repo/validation/polar_stereographic_geographiclib_oracle.cpp"     -lGeographicLib     -o "$oracle"

echo "Building geodesy-d Polar Stereographic differential driver with $dc..."
"$dc"     -I"$repo/source"     "$repo/validation/polar_stereographic_differential.d"     "${sources[@]}"     -of="$driver"

echo
echo "Reference versions:"
cct --version
if command -v GeographicLib-config >/dev/null 2>&1; then
    GeographicLib-config --version || true
fi

echo
echo "Running PS-C / PS-D differential validation..."
"$driver" "$oracle"
