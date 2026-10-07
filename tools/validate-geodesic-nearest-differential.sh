#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
geographiclib_root="${GEOGRAPHICLIB_ROOT:?set GEOGRAPHICLIB_ROOT}"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$cxx"   -O2   -std=c++17   -I"$geographiclib_root/include"   -c "$root/validation/geodesic_nearest_geographiclib_oracle.cpp"   -o "$tmp/oracle.o"

"$dc"   -release   -O   -i   -I"$root/source"   "$root/validation/geodesic_nearest_differential.d"   "$tmp/oracle.o"   -L-L"$geographiclib_root/lib"   -L-lGeographicLib   -L-lstdc++   -of="$tmp/geodesic-nearest-differential"

LD_LIBRARY_PATH="$geographiclib_root/lib:${LD_LIBRARY_PATH:-}"   stdbuf -oL -eL "$tmp/geodesic-nearest-differential"
