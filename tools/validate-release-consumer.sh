#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/source"

cat > "$TMP/dub.sdl" <<EOF
name "geodesy-d-release-consumer"
description "External release-candidate consumer for geodesy-d."
targetType "executable"
sourcePaths "source"
dependency "geodesy-d" path="$ROOT"
EOF

cat > "$TMP/source/app.d" <<'EOF'
import geodesy;
import std.stdio : writeln;

int main()
{
    const earth = wgs84!double();

    const vienna =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208));

    const graz =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(47.07071),
            Longitude!double.fromDegrees(15.43950));

    const linz =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.30694),
            Longitude!double.fromDegrees(14.28583));

    const solver =
        Geodesic!double.fromEllipsoid(earth);

    GeodesicInverseResult!double inverse;
    GeodesicQuantities!double quantities;

    if (!solver.tryInverse(
            vienna,
            graz,
            inverse,
            quantities))
        return 1;

    auto line =
        GeodesicLine!double.fromGeodesic(
            solver,
            vienna,
            inverse.initialAzimuth);

    const position10 =
        line.position(10_000.0);

    const position25 =
        line.position(25_000.0);

    auto polygon =
        GeodesicPolygonAccumulator!double.fromGeodesic(
            solver);

    polygon.addPoint(vienna);
    polygon.addPoint(graz);
    polygon.addPoint(linz);

    const measurement =
        polygon.compute();

    if (inverse.distance <= 0.0
        || quantities.scale12 != quantities.scale12
        || quantities.scale21 != quantities.scale21
        || position10.position.latitude.radians
            != position10.position.latitude.radians
        || position25.position.longitude.radians
            != position25.position.longitude.radians
        || measurement.pointCount != 3
        || measurement.perimeter <= 0.0
        || measurement.signedArea
            != measurement.signedArea)
        return 2;

    writeln(
        "release consumer PASS: distance=", inverse.distance,
        " perimeter=", measurement.perimeter,
        " area=", measurement.signedArea);

    return 0;
}
EOF

cd "$TMP"

echo "=== DEBUG CONSUMER ==="
dub run --compiler="$DC" --build=debug --force

echo "=== RELEASE CONSUMER ==="
dub run --compiler="$DC" --build=release --force

echo "RESULT: EXTERNAL RELEASE CONSUMER PASS"
