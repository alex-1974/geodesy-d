#!/usr/bin/env python3
"""Generate external compile-only checks for 63 nonfunction DDox declarations.

This is *structural* consumer coverage. Enum member values, visibility of
undocumented symbols and full alias/constructor contracts remain separate.
"""
import csv
from collections import Counter
from pathlib import Path
import sys

ALIASES = {
    "CoordinateFrameHelmert14": "Helmert14!(T, HelmertConvention.coordinateFrame)",
    "PositionVectorHelmert14": "Helmert14!(T, HelmertConvention.positionVector)",
    "CoordinateFrameHelmert": "Helmert7!(T, HelmertConvention.coordinateFrame)",
    "PositionVectorHelmert": "Helmert7!(T, HelmertConvention.positionVector)",
    "CoordinateFrameMolodenskyBadekas":
        "MolodenskyBadekas10!(T, HelmertConvention.coordinateFrame)",
    "PositionVectorMolodenskyBadekas":
        "MolodenskyBadekas10!(T, HelmertConvention.positionVector)",
}
CONVENTION_AGGREGATES = {"Helmert7", "Helmert14", "MolodenskyBadekas10"}


def generate(rows):
    signatures = {r["symbol"]: r["signature"] for r in rows}
    counts = Counter()
    for row in rows:
        s = row["signature"]
        if s.startswith("struct ") and " (T" in s:
            counts["struct_template"] += 1
        elif s.startswith("alias "):
            counts["alias"] += 1
        elif s.startswith("enum ") and "{ ... }" in s:
            counts["enum"] += 1
        elif s.startswith("struct "):
            counts["plain_struct"] += 1
        elif s.startswith("class "):
            counts["class"] += 1
        elif s.startswith("this "):
            counts["constructor"] += 1
        elif s.startswith("enum isGeodesyScalar"):
            counts["scalar_policy"] += 1
    expected = Counter(struct_template=45, alias=6, enum=7,
                       plain_struct=2, **{"class": 1},
                       constructor=1, scalar_policy=1)
    if counts != expected:
        raise ValueError(f"Unexpected public nonfunction inventory: {counts}")
    code = [
        "// Generated public nonfunction compile probes; never execute.",
        "module external_nonfunction_api;",
        "import geodesy;", "",
    ]
    for row in rows:
        s = row["signature"]
        name = row["symbol"]
        if s.startswith("struct ") and " (T" in s:
            if "if ( isGeodesyScalar ! T )" not in s:
                raise ValueError(f"Unexpected struct constraint: {s}")
            for scalar in ("float", "double", "real"):
                t = (f"{name}!({scalar}, HelmertConvention.positionVector)"
                     if name in CONVENTION_AGGREGATES else f"{name}!{scalar}")
                code.append(f"static assert(__traits(compiles, {t}));")
            negative = (f"{name}!(int, HelmertConvention.positionVector)"
                        if name in CONVENTION_AGGREGATES else f"{name}!int")
            code.append(f"static assert(!__traits(compiles, {negative}));")
        elif s.startswith("alias "):
            if name not in ALIASES:
                raise ValueError(f"Unexpected alias: {s}")
            code.append(f"static assert(is({name}!double == "
                        + ALIASES[name].replace("T", "double") + "));")
        elif s.startswith("enum ") and "{ ... }" in s:
            code.append(f"static assert(is(typeof({name}.init) == {name}));")
        elif s.startswith("struct "):
            code.append(f"static assert(__traits(compiles, {name}.init));")
        elif s.startswith("class "):
            code.append("static assert(is(GeodesyValueException : Exception));")
        elif s.startswith("this "):
            code.append("void checkExceptionConstructor() { "
                        "auto ex = new GeodesyValueException(\"test\"); }")
        elif s.startswith("enum isGeodesyScalar"):
            code.extend([
                "static assert(isGeodesyScalar!float);",
                "static assert(isGeodesyScalar!double);",
                "static assert(isGeodesyScalar!real);",
                "static assert(!isGeodesyScalar!int);",
            ])
    code.append("")
    code.append("// Structural checks only: not a full compatibility certificate.")
    return "\n".join(code) + "\n"


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    with open(sys.argv[1], newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    code = generate(rows)
    target = Path(sys.argv[2])
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(code, encoding="utf-8")
    print(f"PASS: generated structural consumer for {len(rows)} DDox records")


if __name__ == "__main__":
    main()
