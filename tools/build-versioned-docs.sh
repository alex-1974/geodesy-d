#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

latest_version='v1.0.0'
versions=('v1.0.0')

work_dir="$root/build/versioned-docs"
archives_dir="$work_dir/archives"
staging_dir="$work_dir/staging"
site_dir="$work_dir/site"

rm -rf "$work_dir"
mkdir -p "$archives_dir" "$staging_dir" "$site_dir"

apply_docs_compatibility()
{
    local version="$1"
    local source_dir="$2"

    case "$version" in
        v1.0.0)
            python3 - "$source_dir/source/geodesy/ellipsoid.d" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "/** Second eccentricity squared `e'²`. */"
new = "/** Second eccentricity squared (e′²). */"

count = source.count(old)
if count != 1:
    raise SystemExit(
        f"error: expected exactly one v1.0.0 DDOX compatibility target in {path}, found {count}"
    )

source = source.replace(old, new, 1)

replacements = {
    "source/geodesy/angle.d": [
        (
            "    /** Return the unique half-open representation [-pi, +pi). */",
            "    /** Return the unique representation from -pi inclusive to +pi exclusive. */",
        ),
    ],
    "source/geodesy/geodesic.d": [
        (
            "    /** Forward azimuth at the start point, canonicalized to [-pi,+pi). */",
            "    /** Forward azimuth at the start point, canonicalized from -pi inclusive to +pi exclusive. */",
        ),
        (
            "     * Forward azimuth at the endpoint, canonicalized to [-pi,+pi).",
            "     * Forward azimuth at the endpoint, canonicalized from -pi inclusive to +pi exclusive.",
        ),
        (
            "     * endpoint. All public azimuths use GEO-A's canonical [-pi,+pi)\n"
            "     * representation.",
            "     * endpoint. All public azimuths use GEO-A's canonical half-open interval\\n"
            "     * from -pi inclusive to +pi exclusive.",
        ),
    ],
    "source/geodesy/projection/pseudo_mercator.d": [
        (
            " * principal wrapped sheet [-pi,+pi) with represented endpoint rules qualified",
            " * principal wrapped sheet from -pi inclusive to +pi exclusive, with represented endpoint rules qualified",
        ),
    ],
    "source/geodesy/projection/utm.d": [
        (
            " * Longitude is canonicalized to [-180 degrees, +180 degrees) before zone",
            " * Longitude is canonicalized from -180 degrees inclusive to +180 degrees exclusive before zone",
        ),
    ],
}

for relative, pairs in replacements.items():
    target = path.parents[2] / relative
    text = target.read_text()
    for before, after in pairs:
        found = text.count(before)
        if found != 1:
            raise SystemExit(
                f"error: expected exactly one v1.0.0 Ddoc compatibility target "
                f"in {target}: {before!r}; found {found}"
            )
        text = text.replace(before, after, 1)
    target.write_text(text)

path.write_text(source)
PY
            ;;
        *)
            ;;
    esac
}

for version in "${versions[@]}"; do
    archive_dir="$archives_dir/$version"
    source_dir="$staging_dir/$version"
    version_output="$work_dir/output/$version"
    version_site="$site_dir/$version"

    echo "=== $version ==="
    git rev-parse --verify --quiet "$version^{commit}" >/dev/null || {
        echo "error: missing release tag: $version" >&2
        exit 1
    }

    mkdir -p "$archive_dir"
    git archive "$version" | tar -x -C "$archive_dir"

    # Keep the extracted tag archive pristine. Documentation-tool compatibility
    # adjustments are applied only to a separate staging copy.
    mkdir -p "$source_dir"
    cp -a "$archive_dir/." "$source_dir/"
    apply_docs_compatibility "$version" "$source_dir"

    SOURCE_ROOT="$source_dir" TOOL_ROOT="$root" VERIFY_CONTRACTS=0 \
        OUTPUT_ROOT="$version_output" bash "$root/tools/build-docs.sh"

    mkdir -p "$version_site"
    cp -a "$version_output/build/ddox/site/." "$version_site/"
    test -f "$version_site/geodesy.html"
done

current_output="$work_dir/output/current"
SOURCE_ROOT="$root" TOOL_ROOT="$root" VERIFY_CONTRACTS=1 \
    OUTPUT_ROOT="$current_output" bash "$root/tools/build-docs.sh"
cp -a "$current_output/build/ddox/site/." "$site_dir/"

cat > "$site_dir/versions.html" <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>geodesy-d API documentation versions</title></head>
<body>
<h1>geodesy-d API documentation</h1>
<p>The root documentation follows the current <strong>main</strong> branch.</p>
<ul>
<li><a href="./geodesy.html">current main</a></li>
<li><a href="./v1.0.0/geodesy.html">v1.0.0 — latest stable release</a></li>
</ul>
</body>
</html>
EOF

test -f "$site_dir/geodesy.html"
test -f "$site_dir/v1.0.0/geodesy.html"
if cmp -s "$site_dir/geodesy.html" "$site_dir/v1.0.0/geodesy.html"; then
    echo "note: current main documentation is identical to $latest_version"
else
    echo "PASS: current main documentation is distinct from $latest_version"
fi
