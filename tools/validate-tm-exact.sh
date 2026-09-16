#!/usr/bin/env bash
set -euo pipefail

# Optional Transverse Mercator validation against GeographicLib Exact.
#
# GeographicLib is an external validation oracle only. It is not a geodesy-d
# build or runtime dependency.
#
# Usage:
#   tools/validate-tm-exact.sh
#   tools/validate-tm-exact.sh --extended
#   DC=ldc2 tools/validate-tm-exact.sh --extended

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v TransverseMercatorProj >/dev/null 2>&1; then
    echo "error: GeographicLib TransverseMercatorProj not found in PATH" >&2
    echo "Install/build GeographicLib command-line tools before running this optional gate." >&2
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

binary="$tmp/transverse-mercator-exact-crosscheck"

echo "Compiling GeographicLib Exact TM validation probe with $dc..."
"$dc" \
    -I"$repo/source" \
    "$repo/validation/transverse_mercator_exact_crosscheck.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running geodesy-d Transverse Mercator validation against GeographicLib Exact..."
"$binary" "$@"
