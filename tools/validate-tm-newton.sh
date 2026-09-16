#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v "$dc" >/dev/null 2>&1; then
    echo "error: D compiler '$dc' not found in PATH" >&2
    exit 2
fi

if [[ "$#" -lt 1 ]]; then
    echo "usage: $0 --structured | --random COUNT" >&2
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

case "$(basename "$dc")" in
    ldc|ldc2|ldc2-*)
        version_arg="--d-version=GeodesyTmNewtonValidation"
        ;;
    *)
        version_arg="-version=GeodesyTmNewtonValidation"
        ;;
esac

binary="$tmp/transverse-mercator-newton-validation"

echo "Compiling TM Newton validation with $dc..."
"$dc" \
    "$version_arg" \
    -I"$repo/source" \
    "$repo/validation/transverse_mercator_newton_validation.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running TM Newton validation with $dc: $*"
"$binary" "$@"
