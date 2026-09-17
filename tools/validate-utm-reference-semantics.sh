#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

for tool in "$dc" c++ proj; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool '$tool' not found" >&2
        exit 2
    fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

oracle="$tmp/utm-geographiclib-oracle"

echo "Compiling GeographicLib UTM oracle..."

c++ \
    -std=c++17 \
    "$repo/validation/utm_geographiclib_oracle.cpp" \
    -lGeographicLib \
    -o "$oracle"

sources=()

while IFS= read -r source; do
    sources+=("$source")
done < <(
    find "$repo/source/geodesy" \
        -type f \
        -name '*.d' \
        -print \
        | sort
)

if [[ "${#sources[@]}" -eq 0 ]]; then
    echo "error: no geodesy-d source modules found" >&2
    exit 2
fi

binary="$tmp/utm-reference-semantics"

echo
echo "Compiling UTM-C1 semantic validation with $dc..."

"$dc" \
    -I"$repo/source" \
    "$repo/validation/utm_reference_semantics.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running UTM-C1 semantic validation with $dc..."

"$binary" "$oracle"
