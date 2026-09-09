#!/usr/bin/env bash
set -euo pipefail

# Optional differential validation against an installed PROJ/cct.
#
# PROJ is an external validation oracle only. It is not a geodesy-d build or
# runtime dependency.
#
# Usage:
#   tools/validate-proj.sh
#   tools/validate-proj.sh --extended
#   DC=dmd tools/validate-proj.sh --extended
#
# Run this script from anywhere; it resolves the repository root itself.

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v cct >/dev/null 2>&1; then
    echo "error: PROJ cct executable not found in PATH" >&2
    echo "This optional validation gate requires PROJ command-line tools." >&2
    exit 2
fi

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

binary="$tmp/proj-crosscheck"

echo "Compiling PROJ cross-validation probe with $dc..."
"$dc" \
    -I"$repo/source" \
    "$repo/validation/proj_crosscheck.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running geodesy-d differential validation against PROJ..."
"$binary" "$@"
