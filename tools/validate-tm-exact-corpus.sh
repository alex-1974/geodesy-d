#!/usr/bin/env bash
set -euo pipefail

# Large batched Transverse Mercator validation against GeographicLib Exact.
#
# The wrapper compiles the D harness and uses a single GeographicLib process
# per projection batch, avoiding the process-per-point cost of the smoke
# validator.
#
# Usage:
#   tools/validate-tm-exact-corpus.sh --structured
#   tools/validate-tm-exact-corpus.sh --random 500000
#   DC=ldc2 tools/validate-tm-exact-corpus.sh --structured
#   DC=ldc2 tools/validate-tm-exact-corpus.sh --random 500000
#   tools/validate-tm-exact-corpus.sh --float-structured
#   tools/validate-tm-exact-corpus.sh --float-random 500000

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v TransverseMercatorProj >/dev/null 2>&1; then
    echo "error: GeographicLib TransverseMercatorProj not found in PATH" >&2
    exit 2
fi

if ! command -v "$dc" >/dev/null 2>&1; then
    echo "error: D compiler '$dc' not found in PATH" >&2
    exit 2
fi

if [[ "$#" -eq 1 && "$1" == "--structured" ]]; then
    mode_args=(--structured)
elif [[ "$#" -eq 2 && "$1" == "--random" && "$2" =~ ^[1-9][0-9]*$ ]]; then
    mode_args=(--random "$2")
elif [[ "$#" -eq 1 && "$1" == "--float-structured" ]]; then
    mode_args=(--float-structured)
elif [[ "$#" -eq 2 && "$1" == "--float-random" && "$2" =~ ^[1-9][0-9]*$ ]]; then
    mode_args=(--float-random "$2")
else
    echo "usage: tools/validate-tm-exact-corpus.sh --structured" >&2
    echo "   or: tools/validate-tm-exact-corpus.sh --random COUNT" >&2
    echo "   or: tools/validate-tm-exact-corpus.sh --float-structured" >&2
    echo "   or: tools/validate-tm-exact-corpus.sh --float-random COUNT" >&2
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

binary="$tmp/transverse-mercator-exact-corpus"

echo "Compiling large GeographicLib Exact TM corpus probe with $dc..."
"$dc" \
    -I"$repo/source" \
    "$repo/validation/transverse_mercator_exact_corpus.d" \
    "${sources[@]}" \
    -of="$binary"

echo
case "${mode_args[0]}" in
    --structured)
        echo "Running large structured geodesy-d double TM corpus against GeographicLib Exact..."
        ;;
    --random)
        echo "Running deterministic pseudo-random geodesy-d double TM corpus against GeographicLib Exact..."
        ;;
    --float-structured)
        echo "Running large structured geodesy-d float TM corpus against GeographicLib Exact..."
        ;;
    --float-random)
        echo "Running deterministic pseudo-random geodesy-d float TM corpus against GeographicLib Exact..."
        ;;
esac

"$binary" --work-dir "$tmp" "${mode_args[@]}"
