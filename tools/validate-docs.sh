#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dc="${DC:-dmd}"

required=(
  README.md
  ROADMAP.md
  DESIGN_PRINCIPLES.md
  CHANGELOG.md
  CONTRIBUTING.md
  LICENSE
  docs/README.md
  docs/API.md
  docs/REFERENCES.md
  docs/VALIDATION.md
  docs/V0_1_READINESS.md
  docs/adr/0001-scope-and-boundaries.md
  docs/adr/0002-core-type-and-unit-model.md
  docs/adr/0003-helmert-rotation-conventions.md
  docs/adr/0004-invalid-ellipsoid-default-state.md
  docs/operations/geographic-geocentric.md
  docs/operations/geocentric-translation.md
  docs/operations/helmert-7p.md
)

for f in "${required[@]}"; do
  [[ -f "$repo/$f" ]] || { echo "FAIL missing documentation file: $f" >&2; exit 1; }
done

grep -Eq '^[[:space:]]*toolchainRequirements[[:space:]]+frontend=">=[0-9]+\.[0-9]+(\.[0-9]+)?"' "$repo/dub.sdl" || {
  echo "FAIL: dub.sdl does not declare a minimum D frontend" >&2
  exit 1
}

grep -q 'toolchainRequirements frontend=">=2.111.0"' "$repo/dub.sdl" || {
  echo "FAIL: dub.sdl package minimum is not frontend >=2.111.0" >&2
  exit 1
}

grep -q '^MIT License' "$repo/LICENSE" || {
  echo "FAIL: LICENSE is not the expected MIT license text" >&2
  exit 1
}

# Implementation-sequencing wording that would be misleading in the v0.1
# release-facing documentation.
if grep -RniE \
  'Frame transformations follow next|The next layer adds:|## Still pending|No stable public API exists yet|Initial implementation phase' \
  "$repo/docs/README.md" "$repo/docs/operations"; then
  echo "FAIL: stale implementation-sequencing wording remains" >&2
  exit 1
fi

# Canonical public API document must mention every aggregate-import family.
for symbol in \
  Angle Latitude Longitude Ellipsoid GeodeticCoordinate GeocentricCoordinate \
  GeocentricTranslation HelmertConvention Helmert7 PositionVectorHelmert \
  CoordinateFrameHelmert tryGeodeticToGeocentric geocentricToGeodetic \
  tryApplyGeocentricTranslation tryApplyPositionVectorHelmert \
  tryApplyCoordinateFrameHelmert toCoordinateFrame toPositionVector; do
  grep -q "$symbol" "$repo/docs/API.md" || {
    echo "FAIL: docs/API.md does not mention public symbol family: $symbol" >&2
    exit 1
  }
done

if command -v "$dc" >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/ddoc" "$tmp/obj"

  echo "Generating Ddoc with $dc..."
  while IFS= read -r source; do
    base="$(basename "$source" .d)"
    "$dc" \
      -I="$repo/source" \
      -c \
      -D \
      -Dd"$tmp/ddoc" \
      -of="$tmp/obj/${base}.o" \
      "$source"
  done < <(find "$repo/source/geodesy" -type f -name '*.d' -print | sort)

  count="$(find "$tmp/ddoc" -type f -name '*.html' | wc -l)"
  [[ "$count" -gt 0 ]] || {
    echo "FAIL: Ddoc produced no HTML output" >&2
    exit 1
  }
  echo "PASS: Ddoc generated $count module files"
fi

echo "PASS: documentation/release metadata contract"
