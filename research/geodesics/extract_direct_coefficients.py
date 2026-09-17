#!/usr/bin/env python3

from pathlib import Path
import re
import sys


if len(sys.argv) != 2:
    raise SystemExit(
        "usage: extract_direct_coefficients.py "
        "/path/to/geographiclib-r2.7"
    )

root = Path(sys.argv[1])
source = root / "src" / "Geodesic.cpp"

if not source.is_file():
    raise SystemExit(f"not found: {source}")

text = source.read_text()


FUNCTIONS = (
    "A1m1f",
    "C1f",
    "C1pf",
    "A3coeff",
    "C3coeff",
    "A3f",
    "C3f",
)


def extract_function(name: str) -> str:
    marker = f"Geodesic::{name}"
    pos = text.find(marker)

    if pos < 0:
        raise RuntimeError(f"function not found: {marker}")

    start = text.rfind("\n", 0, pos) + 1
    brace = text.find("{", pos)

    if brace < 0:
        raise RuntimeError(f"opening brace not found: {marker}")

    depth = 0

    for i in range(brace, len(text)):
        ch = text[i]

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1

            if depth == 0:
                return text[start:i + 1]

    raise RuntimeError(f"unterminated function: {marker}")


def extract_order_branch(function: str, order: int) -> str | None:
    patterns = (
        rf"#(?:if|elif)\s+GEOGRAPHICLIB_GEODESIC_ORDER\s*==\s*{order}\b",
        rf"#(?:if|elif)\s+GEOGRAPHICLIB_GEODESIC_ORDER/2\s*==\s*{order // 2}\b",
    )

    starts = []

    for pattern in patterns:
        m = re.search(pattern, function)
        if m:
            starts.append(m)

    if not starts:
        return None

    m = min(starts, key=lambda x: x.start())
    tail = function[m.end():]

    end = re.search(r"(?m)^#(?:elif|else|endif)\b", tail)

    if not end:
        raise RuntimeError("preprocessor branch end not found")

    return tail[:end.start()].strip()


print("# GeographicLib r2.7 geodesic direct coefficient extraction")
print(f"# source: {source}")
print()

for name in FUNCTIONS:
    function = extract_function(name)

    print("=" * 78)
    print(name)
    print("=" * 78)

    if name in {"A3f", "C3f"}:
        print(function)
        print()
        continue

    for order in (6, 7, 8):
        branch = extract_order_branch(function, order)

        print(f"--- order {order} ---")

        if branch is None:
            print("NO DISTINCT BRANCH")
        else:
            print(branch)

        print()
