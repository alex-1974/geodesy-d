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
echo "Named-argument source compatibility ($dc)..."
compile "$repo/validation/api/named_arguments_contract.d" "$tmp/named_arguments_contract.o"

echo "Topocentric coordinate module contract ($dc)..."
compile "$repo/validation/api/topocentric_coordinate_contract.d" \
    "$tmp/topocentric_coordinate_contract.o"

echo "Topocentric frame module contract ($dc)..."
compile "$repo/validation/api/topocentric_frame_contract.d" \
    "$tmp/topocentric_frame_contract.o"

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
expect_rejected "$repo/validation/api/reject_internal_epsg9602_working_helper.d" \
    "package-internal EPSG 9602 working helper"
expect_rejected "$repo/validation/api/reject_topocentric_coordinate_mutation.d" \
    "TopocentricCoordinate component mutation"
expect_rejected "$repo/validation/api/reject_unchecked_topocentric_factory.d" \
    "private unchecked TopocentricCoordinate factory"
expect_rejected "$repo/validation/api/reject_topocentric_frame_mutation.d" \
    "TopocentricFrame ellipsoid mutation"
expect_rejected "$repo/validation/api/reject_topocentric_frame_internal_state.d" \
    "TopocentricFrame internal prepared state"
expect_rejected "$repo/validation/api/reject_unchecked_angle_factory.d" \
    "private unchecked Angle factory"
expect_rejected "$repo/validation/api/reject_internal_angle_helper.d" \
    "package-internal Angle helper"
expect_rejected "$repo/validation/api/reject_conformal_projection_factors_factory.d" \
    "package-internal ConformalProjectionFactors factory"

expect_rejected "$repo/validation/api/reject_tm_research_forward_factors.d" \
    "research-only TM forward factors"
expect_rejected "$repo/validation/api/reject_tm_research_reverse_factors.d" \
    "research-only TM reverse factors"
expect_rejected "$repo/validation/api/reject_pseudo_mercator_webmercator_alias.d" \
    "Pseudo-Mercator WebMercator alias"
expect_rejected "$repo/validation/api/reject_pseudo_mercator_conformal_factors.d" \
    "Pseudo-Mercator conformal factor surface"
expect_rejected "$repo/validation/api/reject_implicit_helmert_convention.d" \
    "Helmert7 without explicit convention"

echo "PASS: public API contract"
