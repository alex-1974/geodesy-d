#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re


MODULE_RE = re.compile(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_.]*)\s*;")
AGGREGATE_RE = re.compile(
    r"^\s*(?:(?:private|package(?:\([^)]*\))?|public|protected)\s+)?"
    r"(?:struct|class|union|interface)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
SECTION_RE = re.compile(
    r"^\s*(private|public|protected|package(?:\([^)]*\))?)\s*:\s*$"
)
DECL_RE = re.compile(
    r"^\s*(?:(?P<explicit>private|package(?:\([^)]*\))?|public|protected)\s+)?"
    r"(?:(?:static|final|const|pure|nothrow|@safe|@nogc)\s+)*"
    r"(?P<return>[A-Za-z_][A-Za-z0-9_!.]*(?:\[[^\]]*\])?)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:!\([^)]*\))?\s*\("
)


def brace_delta(line: str) -> int:
    code = line.split("//", 1)[0]
    return code.count("{") - code.count("}")


def is_internal_visibility(value: str | None) -> bool:
    return value == "private" or (value is not None and value.startswith("package"))


def internal_declarations(source_root: Path) -> set[tuple[str, int]]:
    result: set[tuple[str, int]] = set()

    for path in sorted((source_root / "source" / "geodesy").rglob("*.d")):
        if "/internal/" in path.as_posix():
            continue

        lines = path.read_text().splitlines()
        module = None
        for line in lines:
            match = MODULE_RE.match(line)
            if match:
                module = match.group(1)
                break
        if module is None:
            continue

        depth = 0
        visibility_by_depth: dict[int, str] = {}

        for index, line in enumerate(lines):
            section = SECTION_RE.match(line)
            if section:
                visibility_by_depth[depth] = section.group(1)

            declaration = DECL_RE.match(line)
            if declaration:
                explicit = declaration.group("explicit")
                visibility = (
                    explicit
                    if explicit is not None
                    else visibility_by_depth.get(depth)
                )

                if is_internal_visibility(visibility):
                    result.add((module, index + 1))

            depth += brace_delta(line)

            for d in list(visibility_by_depth):
                if d > depth:
                    del visibility_by_depth[d]

    return result


def module_name(node) -> str | None:
    if not isinstance(node, dict):
        return None
    name = node.get("name")
    if isinstance(name, str) and name.startswith("geodesy"):
        return name
    return None


def filter_internal_declarations(
    node,
    module: str | None,
    internal: set[tuple[str, int]],
) -> int:
    removed = 0

    if isinstance(node, list):
        kept = []
        for item in node:
            item_module = module_name(item) or module
            item_line = item.get("line") if isinstance(item, dict) else None

            if (
                item_module is not None
                and isinstance(item_line, int)
                and (item_module, item_line) in internal
            ):
                removed += 1
                continue

            removed += filter_internal_declarations(
                item,
                item_module,
                internal,
            )
            kept.append(item)

        node[:] = kept
        return removed

    if not isinstance(node, dict):
        return 0

    current_module = module_name(node) or module

    for key in list(node):
        value = node[key]

        if isinstance(value, dict):
            value_module = module_name(value) or current_module
            value_line = value.get("line")

            if (
                value_module is not None
                and isinstance(value_line, int)
                and (value_module, value_line) in internal
            ):
                del node[key]
                removed += 1
                continue

            removed += filter_internal_declarations(
                value,
                value_module,
                internal,
            )

        elif isinstance(value, list):
            removed += filter_internal_declarations(
                value,
                current_module,
                internal,
            )

    return removed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove source-private/package aggregate members from DMD JSON before DDox."
    )
    parser.add_argument("json_file", type=Path)
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()

    internal = internal_declarations(args.source_root)
    data = json.loads(args.json_file.read_text())
    removed = filter_internal_declarations(data, None, internal)

    args.json_file.write_text(json.dumps(data, separators=(",", ":")))

    print(
        f"PASS: source-aware DDox filter removed {removed} internal declarations "
        f"from {len(internal)} source-internal declarations"
    )


if __name__ == "__main__":
    main()
