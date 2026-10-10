#!/usr/bin/env python3
"""Verify seven published enum families and generate cross-compiler assertions.

Expected values are explicit and independent of the DMD JSON being read.
"""
import argparse
import csv
import json
import re
from pathlib import Path

EXPECTED = {
    "GeodesicIntersectionCoincidence": ("int", [
        ("distinct", 0), ("parallel", 1), ("antiparallel", 2)]),
    "GeodesicIntersectionEnumerationStatus": ("int", [
        ("invalid", 0), ("success", 1), ("workspaceTooSmall", 2),
        ("numericalFailure", 3)]),
    "GeodesicSegmentIntersectionKind": ("int", [
        ("invalid", 0), ("none", 1), ("point", 2), ("overlap", 3)]),
    "GeodesicSegmentNearestKind": ("int", [
        ("invalid", 0), ("start", 1), ("interior", 2), ("end", 3)]),
    "UpsHemisphere": ("ubyte", [("north", 0), ("south", 1)]),
    "UtmHemisphere": ("ubyte", [("north", 0), ("south", 1)]),
    "HelmertConvention": ("int", [
        ("positionVector", 0), ("coordinateFrame", 1)]),
}
BASE_DECO = {"int": "i", "ubyte": "h"}


def scan(node, enums):
    if isinstance(node, list):
        for item in node:
            scan(item, enums)
    elif isinstance(node, dict):
        if node.get("kind") == "enum" and node.get("name") in EXPECTED:
            name = node["name"]
            if name in enums:
                raise ValueError(f"Duplicate enum: {name}")
            enums[name] = node
        for item in node.get("members", []):
            scan(item, enums)


def value_of(text):
    text = re.sub(r"cast\s*\(\s*ubyte\s*\)", "", str(text))
    text = text.rstrip("uU")
    if not re.fullmatch(r"-?\d+", text):
        raise ValueError(f"Unrecognized enum constant representation: {text}")
    return int(text)


def verify(raw_json_dir):
    entries = {}
    for path in raw_json_dir.glob("geodesy.*.json"):
        scan(json.loads(path.read_text(encoding="utf-8")), entries)
    if set(entries) != set(EXPECTED):
        raise ValueError(f"Enum inventory mismatch: {set(entries) ^ set(EXPECTED)}")
    results, calls = [], [
        "// Generated cross-compiler enum contract assertions.",
        "module external_enum_contracts;",
        "import geodesy;", ""]
    for name, (base, expected) in sorted(EXPECTED.items()):
        node = entries[name]
        if node.get("baseDeco") != BASE_DECO[base]:
            raise ValueError(f"{name}: unexpected base type {node.get('baseDeco')}")
        actual = [(x["name"], value_of(x["value"])) for x in node["members"]
                  if x.get("kind") == "enum member"]
        if actual != expected:
            raise ValueError(f"{name}: expected {expected}, got {actual}")
        calls.append(f"static assert({name}.sizeof == {base}.sizeof);")
        for member, value in expected:
            results.append((name, member, base, value))
            calls.append(f"static assert(cast(int) {name}.{member} == {value});")
    return results, "\n".join(calls) + "\n"


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("json_dir", type=Path)
    p.add_argument("report_csv", type=Path)
    p.add_argument("consumer_d", type=Path)
    a = p.parse_args()
    rows, source = verify(a.json_dir)
    for target in (a.report_csv, a.consumer_d):
        target.parent.mkdir(parents=True, exist_ok=True)
    with a.report_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(("enum", "member", "underlying", "value"))
        w.writerows(rows)
    a.consumer_d.write_text(source, encoding="utf-8")
    print(f"PASS: {len(EXPECTED)} enum families and {len(rows)} exact public values")


if __name__ == "__main__":
    main()
