#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"
cxx="${CXX:-c++}"

for tool in "$dc" "$cxx" cct; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

oracle="$tmp/ups-geographiclib-oracle"
driver="$tmp/ups-differential"

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

"$cxx"     -std=c++17     -O2     "$repo/validation/ups_geographiclib_oracle.cpp"     -lGeographicLib     -o "$oracle"

"$dc"     -I"$repo/source"     "$repo/validation/ups_differential.d"     "${sources[@]}"     -of="$driver"

echo "=== references ==="
cct --version

echo
echo "=== UPS differential validation ==="
"$driver" "$oracle"
