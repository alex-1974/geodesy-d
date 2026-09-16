#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v "$dc" >/dev/null 2>&1; then
    echo "error: D compiler '$dc' not found in PATH" >&2
    exit 2
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

binary="$tmp/utm-boundary-property"

echo "Compiling UTM-D boundary/property validation with $dc..."

"$dc" \
    -I"$repo/source" \
    "$repo/validation/utm_boundary_property.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running UTM-D boundary/property validation with $dc..."

"$binary"
