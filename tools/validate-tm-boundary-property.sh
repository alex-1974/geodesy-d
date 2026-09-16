#!/usr/bin/env bash
set -euo pipefail

DC="${DC:-dmd}"
SOURCE="validation/transverse_mercator_boundary_property.d"

if [[ ! -f "$SOURCE" ]]; then
    echo "missing $SOURCE" >&2
    exit 2
fi

case "$(basename "$DC")" in
    ldc2|ldc)
        OUT="${TMPDIR:-/tmp}/geodesy-tm-boundary-ldc"
        "$DC" -i -Isource -O3 -release \
            "$SOURCE" -of="$OUT"
        ;;
    *)
        OUT="${TMPDIR:-/tmp}/geodesy-tm-boundary-dmd"
        "$DC" -i -Isource -O -release \
            "$SOURCE" -of="$OUT"
        ;;
esac

"$OUT"
