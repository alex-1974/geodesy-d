#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

command -v "$dc" >/dev/null 2>&1 || {
    echo "error: D compiler '$dc' not found" >&2
    exit 2
}

command -v proj >/dev/null 2>&1 || {
    echo "error: PROJ executable not found" >&2
    exit 2
}

"$dc"     -i     -I"$repo/source"     -run "$repo/validation/lambert_azimuthal_equal_area_differential.d"
