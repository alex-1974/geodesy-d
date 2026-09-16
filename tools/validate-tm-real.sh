#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

if ! command -v "$dc" >/dev/null 2>&1; then
    echo "error: D compiler '$dc' not found in PATH" >&2
    exit 2
fi

case "${1:-}" in
    --platform|--precision|--boundary|--sphere-structured|--exact-structured)
        if [[ "$#" -ne 1 ]]; then
            echo "error: unexpected extra arguments" >&2
            exit 2
        fi
        mode_args=("$1")
        ;;
    --sphere-random|--exact-random)
        if [[ "$#" -ne 2 || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
            echo "error: $1 requires a positive COUNT" >&2
            exit 2
        fi
        mode_args=("$1" "$2")
        ;;
    *)
        cat >&2 <<'USAGE'
usage:
  tools/validate-tm-real.sh --platform
  tools/validate-tm-real.sh --precision
  tools/validate-tm-real.sh --boundary
  tools/validate-tm-real.sh --sphere-structured
  tools/validate-tm-real.sh --sphere-random COUNT
  tools/validate-tm-real.sh --exact-structured
  tools/validate-tm-real.sh --exact-random COUNT

Set DC=ldc2 to cross-check with LDC.
USAGE
        exit 2
        ;;
esac

if [[ "${mode_args[0]}" == --exact-* ]] \
    && ! command -v TransverseMercatorProj >/dev/null 2>&1; then
    echo "error: GeographicLib TransverseMercatorProj not found in PATH" >&2
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

binary="$tmp/transverse-mercator-real-validation"

echo "Compiling TM real validation with $dc..."
"$dc" \
    -I"$repo/source" \
    "$repo/validation/transverse_mercator_real_validation.d" \
    "${sources[@]}" \
    -of="$binary"

echo
echo "Running TM real validation: ${mode_args[*]}"
"$binary" --work-dir "$tmp" "${mode_args[@]}"
