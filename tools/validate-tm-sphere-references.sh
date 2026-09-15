#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$repo/validation/transverse_mercator_sphere_reference_crosscheck.py"

if [[ ! -f "$validator" ]]; then
    echo "ERROR: missing $validator" >&2
    exit 2
fi

if [[ $# -eq 1 && "$1" == "--structured" ]]; then
    exec python3 "$validator" --structured
elif [[ $# -eq 2 && "$1" == "--random" ]]; then
    exec python3 "$validator" --random "$2"
else
    echo "usage: tools/validate-tm-sphere-references.sh --structured" >&2
    echo "   or: tools/validate-tm-sphere-references.sh --random COUNT" >&2
    exit 2
fi
