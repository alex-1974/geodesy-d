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

mapfile -t sources < <(
    find "$repo/source/geodesy" -type f -name '*.d' -print | sort
)

if [[ "${#sources[@]}" -eq 0 ]]; then
    echo "error: no geodesy-d source modules found" >&2
    exit 2
fi

binary="$tmp/transverse-mercator-api-runtime-validation"

echo "Compiling TM-E API/runtime validation with $dc..."
"$dc" \
    -I"$repo/source" \
    "$repo/validation/transverse_mercator_api_runtime_validation.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running TM-E API/runtime validation with $dc..."
"$binary"
