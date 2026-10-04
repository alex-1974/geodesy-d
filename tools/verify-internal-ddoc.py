#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path("source/geodesy")

DECL_RE = re.compile(
    r"^\s*(?:(?P<explicit>private|package(?:\([^)]*\))?)\s+)?"
    r"(?:(?:static|final|const|pure|nothrow|@safe|@nogc)\s+)*"
    r"(?P<return>[A-Za-z_][A-Za-z0-9_!.]*(?:\[[^\]]*\])?)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:!\([^)]*\))?\s*\("
)

SECTION_RE = re.compile(
    r"^\s*(?P<visibility>private|public|protected|package(?:\([^)]*\))?)\s*:\s*$"
)


def has_ddoc(lines: list[str], declaration_index: int) -> bool:
    i = declaration_index - 1
    while i >= 0 and not lines[i].strip():
        i -= 1

    if i < 0:
        return False

    if lines[i].lstrip().startswith("///"):
        return True

    if lines[i].strip().endswith("*/"):
        while i >= 0:
            if "/**" in lines[i]:
                return True
            if "/*" in lines[i]:
                return False
            i -= 1

    return False


def brace_delta(line: str) -> int:
    # Good enough for declaration-oriented D source in this repository.
    # Braces inside line comments are ignored.
    code = line.split("//", 1)[0]
    return code.count("{") - code.count("}")


def audit_file(path: Path) -> list[str]:
    lines = path.read_text().splitlines()
    failures: list[str] = []

    depth = 0
    module_package = False
    section_visibility: dict[int, str] = {}

    for index, line in enumerate(lines):
        stripped = line.strip()

        section = SECTION_RE.match(line)
        if section:
            visibility = section.group("visibility")
            if depth == 0 and visibility.startswith("package"):
                module_package = True
            else:
                section_visibility[depth] = visibility

        match = DECL_RE.match(line)
        if match:
            explicit = match.group("explicit")
            name = match.group("name")

            visibility = explicit
            if visibility is None:
                active_depths = [d for d in section_visibility if d <= depth]
                if active_depths:
                    visibility = section_visibility[max(active_depths)]
                elif module_package:
                    visibility = "package"

            internal = visibility is not None and (
                visibility == "private" or visibility.startswith("package")
            )

            if internal and not has_ddoc(lines, index):
                failures.append(
                    f"{path}:{index + 1}: internal function {name} lacks Ddoc"
                )

        depth += brace_delta(line)
        if depth < 0:
            depth = 0

        for d in list(section_visibility):
            if d > depth:
                del section_visibility[d]

    return failures


def main() -> None:
    if not ROOT.is_dir():
        print(f"error: missing source tree: {ROOT}", file=sys.stderr)
        raise SystemExit(1)

    failures: list[str] = []
    for path in sorted(ROOT.rglob("*.d")):
        failures.extend(audit_file(path))

    if failures:
        print("FAIL: internal Ddoc contract", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        raise SystemExit(1)

    print("PASS: every private/package function has adjacent Ddoc")


if __name__ == "__main__":
    main()
