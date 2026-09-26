#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

latest_version='v1.0.0'
versions=('v1.0.0')

work_dir="$root/build/versioned-docs"
sources_dir="$work_dir/sources"
site_dir="$work_dir/site"

rm -rf "$work_dir"
mkdir -p "$sources_dir" "$site_dir"

for version in "${versions[@]}"; do
    source_dir="$sources_dir/$version"
    version_site="$site_dir/$version"

    echo "=== $version ==="
    git rev-parse --verify --quiet "$version^{commit}" >/dev/null || {
        echo "error: missing release tag: $version" >&2
        exit 1
    }

    mkdir -p "$source_dir"
    git archive "$version" | tar -x -C "$source_dir"

    (
        cd "$source_dir"
        bash "$root/tools/build-docs.sh"
    )

    mkdir -p "$version_site"
    cp -a "$source_dir/build/ddox/site/." "$version_site/"
    test -f "$version_site/geodesy.html"
done

latest_site="$site_dir/$latest_version"
cp -a "$latest_site/." "$site_dir/"

cat > "$site_dir/versions.html" <<EOF
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>geodesy-d API documentation versions</title></head>
<body>
<h1>geodesy-d API documentation</h1>
<p>The root documentation follows the current stable release: <strong>${latest_version}</strong>.</p>
<ul>
<li><a href="./geodesy.html">${latest_version} — latest stable</a></li>
<li><a href="./v1.0.0/geodesy.html">v1.0.0</a></li>
</ul>
</body>
</html>
EOF

test -f "$site_dir/geodesy.html"
test -f "$site_dir/v1.0.0/geodesy.html"
cmp "$site_dir/geodesy.html" "$site_dir/v1.0.0/geodesy.html"
echo "PASS: root documentation matches v1.0.0"
