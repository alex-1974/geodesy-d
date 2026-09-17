#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

for tool in "$dc" cct; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool '$tool' not found" >&2
        exit 2
    fi
done

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

binary="$tmp/utm-proj-crosscheck"

echo "Compiling UTM-C2 PROJ validation with $dc..."

"$dc" \
    -I"$repo/source" \
    "$repo/validation/utm_proj_crosscheck.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running UTM-C2 PROJ validation with $dc..."

"$binary"
