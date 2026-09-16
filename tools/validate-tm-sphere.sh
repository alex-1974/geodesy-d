#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

case "${1:-}" in
    --structured|--float-structured)
        [[ "$#" -eq 1 ]] || {
            echo "unexpected arguments" >&2
            exit 2
        }
        ;;
    --random|--float-random)
        [[ "$#" -eq 2 && "${2:-}" =~ ^[1-9][0-9]*$ ]] || {
            echo "COUNT must be a positive integer" >&2
            exit 2
        }
        ;;
    *)
        echo "usage: tools/validate-tm-sphere.sh --structured" >&2
        echo "   or: tools/validate-tm-sphere.sh --random COUNT" >&2
        echo "   or: tools/validate-tm-sphere.sh --float-structured" >&2
        echo "   or: tools/validate-tm-sphere.sh --float-random COUNT" >&2
        exit 2
        ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

binary="$tmp/transverse_mercator_sphere_crosscheck"

echo "Compiling analytic spherical TM corpus probe with $dc..."

"$dc" \
    -i \
    -I="$repo/source" \
    "$repo/validation/transverse_mercator_sphere_crosscheck.d" \
    -of="$binary"

echo
case "$1" in
    --structured)
        echo "Running structured geodesy-d double spherical TM corpus against analytic oracle..."
        ;;
    --random)
        echo "Running deterministic pseudo-random geodesy-d double spherical TM corpus against analytic oracle..."
        ;;
    --float-structured)
        echo "Running structured geodesy-d float spherical TM corpus against analytic oracle..."
        ;;
    --float-random)
        echo "Running deterministic pseudo-random geodesy-d float spherical TM corpus against analytic oracle..."
        ;;
esac

"$binary" "$@"
