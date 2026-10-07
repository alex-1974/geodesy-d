#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DC="${DC:-dmd}"
BUILD_DIR="$ROOT/build/dynamic-helmert-validation"
mkdir -p "$BUILD_DIR"

"$DC" -i -Isource   validation/dynamic_helmert_differential.d   -of="$BUILD_DIR/dynamic-helmert-differential"

"$BUILD_DIR/dynamic-helmert-differential" > "$BUILD_DIR/d.out"

SOURCE="-3789470.710 4841770.404 -1690893.952 2013.90"

printf '%s\n' "$SOURCE" | cct -d 12   +proj=helmert   +x=-0.08468 +y=-0.01942 +z=0.03201   +rx=0.0004254 +ry=-0.0022578 +rz=-0.0024015 +s=0.00971   +dx=0.00142 +dy=0.00134 +dz=0.00090   +drx=-0.0015461 +dry=-0.0011820 +drz=-0.0011551 +ds=0.000109   +t_epoch=1994.00 +convention=position_vector   > "$BUILD_DIR/proj-pv.out"

printf '%s\n' "$SOURCE" | cct -d 12   +proj=helmert   +x=-0.08468 +y=-0.01942 +z=0.03201   +rx=-0.0004254 +ry=0.0022578 +rz=0.0024015 +s=0.00971   +dx=0.00142 +dy=0.00134 +dz=0.00090   +drx=0.0015461 +dry=0.0011820 +drz=0.0011551 +ds=0.000109   +t_epoch=1994.00 +convention=coordinate_frame   > "$BUILD_DIR/proj-cf.out"

python3 - "$BUILD_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

d = {}
for line in (root / "d.out").read_text().splitlines():
    key, x, y, z = line.split()
    d[key] = tuple(map(float, (x, y, z)))

def proj(path):
    parts = Path(path).read_text().split()
    return tuple(map(float, parts[:3]))

refs = {
    "pv": proj(root / "proj-pv.out"),
    "cf": proj(root / "proj-cf.out"),
}

tol = 2e-6
for key in ("pv", "cf"):
    err = max(abs(a - b) for a, b in zip(d[key], refs[key]))
    print(f"{key}: max |D-PROJ| = {err:.3e} m")
    if err > tol:
        raise SystemExit(
            f"dynamic Helmert differential mismatch for {key}: {err} > {tol}")

pv_cf = max(abs(a - b) for a, b in zip(d["pv"], d["cf"]))
print(f"convention-equivalence max diff = {pv_cf:.3e} m")
if pv_cf > 1e-9:
    raise SystemExit("Position Vector / Coordinate Frame equivalence failed")

print("PASS: dynamic Helmert differential validation")
PY
