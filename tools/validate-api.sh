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

compile() {
    local source="$1"
    local object="$2"
    "$dc" -I="$repo/source" -c "$source" -of="$object"
}

echo "Public API positive contract ($dc)..."
compile "$repo/validation/api/public_api_contract.d" "$tmp/public_api_contract.o"

expect_rejected() {
    local source="$1"
    local label="$2"
    local log="$tmp/$(basename "$source").log"
    if compile "$source" "$tmp/rejected.o" >"$log" 2>&1; then
        echo "FAIL: API boundary unexpectedly accepted: $label" >&2
        cat "$log" >&2
        exit 1
    fi
    echo "PASS reject: $label"
}

expect_rejected "$repo/validation/api/reject_translation_mutation.d" \
    "GeocentricTranslation mutation"
expect_rejected "$repo/validation/api/reject_internal_finite_helper.d" \
    "package-internal finite helper"
expect_rejected "$repo/validation/api/reject_unchecked_angle_factory.d" \
    "private unchecked Angle factory"
expect_rejected "$repo/validation/api/reject_internal_angle_helper.d" \
    "package-internal Angle helper"
expect_rejected "$repo/validation/api/reject_implicit_helmert_convention.d" \
    "Helmert7 without explicit convention"

echo "PASS: public API contract"
