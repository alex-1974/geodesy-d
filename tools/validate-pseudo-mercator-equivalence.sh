#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

command -v "$dc" >/dev/null 2>&1 || {
    echo "error: D compiler '$dc' not found in PATH" >&2
    exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

research="$tmp/research-driver"
production="$tmp/production-driver"

case "$(basename "$dc")" in
    ldc*)
        version_flag="--d-version=PseudoMercatorDifferential"
        ;;
    *)
        version_flag="-version=PseudoMercatorDifferential"
        ;;
esac

echo "Compiling PM-G3A research driver with $dc..."
"$dc" \
    -preview=in \
    -wi \
    -O \
    -release \
    "$version_flag" \
    -I"$repo/source" \
    "$repo/research/pseudo-mercator/pm_e1_kernel_probe.d" \
    "$repo/source/geodesy/errors.d" \
    -of="$research"

echo "Compiling PM-G3A production driver with $dc..."
"$dc" \
    -preview=in \
    -wi \
    -O \
    -release \
    -i \
    -I"$repo/source" \
    "$repo/validation/pseudo_mercator_differential_driver.d" \
    -of="$production"

echo
echo "=== FORWARD: RESEARCH ==="
python3 "$repo/research/pseudo-mercator/validate_pm_e1c1_forward.py" \
    --driver "$research" \
    --write-input "$tmp/forward-research.in" \
    --write-output "$tmp/forward-research.out" \
    > "$tmp/forward-research.report"
cat "$tmp/forward-research.report"

echo
echo "=== FORWARD: PRODUCTION ==="
python3 "$repo/research/pseudo-mercator/validate_pm_e1c1_forward.py" \
    --driver "$production" \
    --write-input "$tmp/forward-production.in" \
    --write-output "$tmp/forward-production.out" \
    > "$tmp/forward-production.report"
cat "$tmp/forward-production.report"

cmp "$tmp/forward-research.in" "$tmp/forward-production.in"
cmp "$tmp/forward-research.out" "$tmp/forward-production.out"
cmp "$tmp/forward-research.report" "$tmp/forward-production.report"

echo "PASS: forward corpus/output/report byte-identical"

echo
echo "=== REVERSE: RESEARCH ==="
python3 "$repo/research/pseudo-mercator/validate_pm_e1c1_reverse.py" \
    --driver "$research" \
    --write-input "$tmp/reverse-research.in" \
    --write-output "$tmp/reverse-research.out" \
    > "$tmp/reverse-research.report"
cat "$tmp/reverse-research.report"

echo
echo "=== REVERSE: PRODUCTION ==="
python3 "$repo/research/pseudo-mercator/validate_pm_e1c1_reverse.py" \
    --driver "$production" \
    --write-input "$tmp/reverse-production.in" \
    --write-output "$tmp/reverse-production.out" \
    > "$tmp/reverse-production.report"
cat "$tmp/reverse-production.report"

cmp "$tmp/reverse-research.in" "$tmp/reverse-production.in"

sed -E 's/\teastDelta=[^\t]*//' \
    "$tmp/reverse-research.out" \
    > "$tmp/reverse-research.normalized.out"

cp "$tmp/reverse-production.out" \
    "$tmp/reverse-production.normalized.out"

cmp \
    "$tmp/reverse-research.normalized.out" \
    "$tmp/reverse-production.normalized.out"

cmp \
    "$tmp/reverse-research.report" \
    "$tmp/reverse-production.report"

echo "PASS: reverse corpus/output/report equivalent"
echo
echo "RESULT: PM-G3A PASS ($dc)"
