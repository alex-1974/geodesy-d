#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DC="${DC:-dmd}"
BUILD_DIR="$ROOT/build/molodensky-badekas-validation"
mkdir -p "$BUILD_DIR"

"$DC" -i -Isource \
  validation/molodensky_badekas_differential.d \
  -of="$BUILD_DIR/molodensky-badekas-differential"

"$BUILD_DIR/molodensky-badekas-differential" > "$BUILD_DIR/d.out"

SOURCE="2550408.965 -5749912.266 1054891.114"

printf '%s\n' "$SOURCE" | cct -d 12 \
  +proj=molobadekas +convention=coordinate_frame \
  +x=-270.933 +y=115.599 +z=-360.226 \
  +rx=-5.266 +ry=-1.238 +rz=2.381 +s=-5.109 \
  +px=2464351.59 +py=-5783466.61 +pz=974809.81 \
  > "$BUILD_DIR/proj-cf.out"

printf '%s\n' "$SOURCE" | cct -d 12 \
  +proj=molobadekas +convention=position_vector \
  +x=-270.933 +y=115.599 +z=-360.226 \
  +rx=5.266 +ry=1.238 +rz=-2.381 +s=-5.109 \
  +px=2464351.59 +py=-5783466.61 +pz=974809.81 \
  > "$BUILD_DIR/proj-pv.out"

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
    "cf": proj(root / "proj-cf.out"),
    "pv": proj(root / "proj-pv.out"),
}

tol = 2e-6
for key in ("cf", "pv"):
    err = max(abs(a - b) for a, b in zip(d[key], refs[key]))
    print(f"{key}: max |D-PROJ| = {err:.3e} m")
    if err > tol:
        raise SystemExit(
            f"Molodensky-Badekas differential mismatch for {key}: {err} > {tol}")

pv_cf = max(abs(a - b) for a, b in zip(d["pv"], d["cf"]))
print(f"convention-equivalence max diff = {pv_cf:.3e} m")
if pv_cf > 1e-9:
    raise SystemExit("Position Vector / Coordinate Frame equivalence failed")

epsg = (2550138.467, -5749799.862, 1054530.826)
epsg_err = max(abs(a - b) for a, b in zip(d["cf"], epsg))
print(f"EPSG rounded-vector max diff = {epsg_err:.3e} m")
if epsg_err > 1.5e-3:
    raise SystemExit("EPSG Guidance Note worked-vector check failed")

print("PASS: Molodensky-Badekas differential validation")
PY
