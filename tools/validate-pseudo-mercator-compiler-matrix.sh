#!/usr/bin/env bash

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

compilers=(
    dmd-2.111.0
    dmd-2.112.1
    dmd-2.113.0
    ldc-1.41.0
    ldc-1.42.0
    ldc-1.43.0
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

matrix_failures=0

run_logged()
{
    local compiler="$1"
    local label="$2"
    local log="$3"
    shift 3

    echo
    echo "=== $compiler :: $label ==="

    "$@" >"$log" 2>&1
    local status=$?

    if [[ "$status" -eq 0 ]]; then
        echo "PASS: $label"
    else
        echo "FAIL: $label (status=$status)"
        echo "--- log tail ---"
        tail -80 "$log" || true
        matrix_failures=$((matrix_failures + 1))
    fi

    return 0
}

echo "PM-G4 Pseudo-Mercator controlled compiler matrix"
echo

for compiler in "${compilers[@]}"; do
    echo
    echo "============================================================"
    echo "COMPILER: $compiler"
    echo "============================================================"

    if ! command -v "$compiler" >/dev/null 2>&1; then
        echo "FAIL: compiler not found: $compiler"
        matrix_failures=$((matrix_failures + 1))
        continue
    fi

    "$compiler" --version | head -4 || true

    api_log="$tmp/$compiler-api.log"
    runtime_log="$tmp/$compiler-runtime.log"
    equivalence_log="$tmp/$compiler-equivalence.log"
    dub_log="$tmp/$compiler-dub.log"

    run_logged         "$compiler"         "public API contracts"         "$api_log"         env DC="$compiler"         "$repo/tools/validate-api.sh"

    if grep -q '^PASS: public API contract$' "$api_log"; then
        echo "  API result: PASS"
    fi

    run_logged         "$compiler"         "PM-G2 API/runtime contract"         "$runtime_log"         env DC="$compiler"         "$repo/tools/validate-pseudo-mercator-api-runtime.sh"

    grep -E         '^(float: PASS|double: PASS|real: PASS|RESULT: PASS)$'         "$runtime_log"         | sed 's/^/  /'         || true

    run_logged         "$compiler"         "PM-G3 production/research equivalence"         "$equivalence_log"         env DC="$compiler"         "$repo/tools/validate-pseudo-mercator-equivalence.sh"

    grep -E         '^(PASS: forward corpus/output/report byte-identical|PASS: reverse corpus/output/report equivalent|RESULT: PM-G3A PASS)'         "$equivalence_log"         | sed 's/^/  /'         || true

    run_logged         "$compiler"         "full repository dub test"         "$dub_log"         dub test         --compiler="$compiler"

    grep -E         '[0-9]+ modules passed unittests|^All unit tests have been run successfully'         "$dub_log"         | tail -3         | sed 's/^/  /'         || true
done

echo
echo "============================================================"
echo "PM-G4 MATRIX SUMMARY"
echo "============================================================"
echo "controlled compilers: ${#compilers[@]}"
echo "failed checks:        $matrix_failures"

if [[ "$matrix_failures" -ne 0 ]]; then
    echo "RESULT: PM-G4 FAIL"
    exit 1
fi

echo "RESULT: PM-G4 PASS"
