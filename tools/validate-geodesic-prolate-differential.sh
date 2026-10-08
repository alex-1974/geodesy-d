#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
geographiclib_root="${GEOGRAPHICLIB_ROOT:?set GEOGRAPHICLIB_ROOT}"
dc="${DC:-ldc2}"
cxx="${CXX:-g++}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for source in   geodesic_prolate_geographiclib_oracle   geodesic_nearest_geographiclib_oracle   geodesic_closest_intersection_geographiclib_oracle   geodesic_next_intersection_geographiclib_oracle   geodesic_all_intersection_geographiclib_oracle
do
  "$cxx" -O2 -std=c++17     -I"$geographiclib_root/include"     -c "$root/validation/${source}.cpp"     -o "$tmp/${source}.o"
done

"$dc"   -release   -O   -i   -I"$root/source"   "$root/validation/geodesic_prolate_differential.d"   "$tmp/geodesic_prolate_geographiclib_oracle.o"   "$tmp/geodesic_nearest_geographiclib_oracle.o"   "$tmp/geodesic_closest_intersection_geographiclib_oracle.o"   "$tmp/geodesic_next_intersection_geographiclib_oracle.o"   "$tmp/geodesic_all_intersection_geographiclib_oracle.o"   -L-L"$geographiclib_root/lib"   -L-lGeographicLib   -L-lstdc++   -of="$tmp/geodesic-prolate-differential"

LD_LIBRARY_PATH="$geographiclib_root/lib:${LD_LIBRARY_PATH:-}"   stdbuf -oL -eL "$tmp/geodesic-prolate-differential"
