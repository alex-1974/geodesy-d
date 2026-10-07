#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"
cxx="${CXX:-c++}"

for tool in "$dc" "$cxx"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: required tool '$tool' not found" >&2
        exit 2
    }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

oracle="$tmp/rhumb-geographiclib-oracle"
driver="$tmp/rhumb-differential"

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

"$cxx"     -std=c++17     -O2     "$repo/validation/rhumb_geographiclib_oracle.cpp"     -lGeographicLib     -o "$oracle"

"$dc"     -I"$repo/source"     "$repo/validation/rhumb_differential.d"     "${sources[@]}"     -of="$driver"

"$driver" "$oracle"
