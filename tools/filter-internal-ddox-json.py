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


def internal_symbols(source_root: Path) -> set[str]:
    result: set[str] = set()

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
        aggregate_stack: list[tuple[int, str]] = []
        visibility_by_depth: dict[int, str] = {}

        for line in lines:
            stripped = line.strip()

            section = SECTION_RE.match(line)
            if section:
                visibility_by_depth[depth] = section.group(1)

            aggregate = AGGREGATE_RE.match(line)
            pending_aggregate = aggregate.group(1) if aggregate else None

            declaration = DECL_RE.match(line)
            if declaration:
                explicit = declaration.group("explicit")
                visibility = explicit if explicit is not None else visibility_by_depth.get(depth)

                if is_internal_visibility(visibility):
                    aggregate_names = [name for _, name in aggregate_stack]
                    fq = ".".join([module, *aggregate_names, declaration.group("name")])
                    result.add(fq)

            old_depth = depth
            depth += brace_delta(line)

            if pending_aggregate is not None and depth > old_depth:
                aggregate_stack.append((depth, pending_aggregate))

            while aggregate_stack and aggregate_stack[-1][0] > depth:
                aggregate_stack.pop()

            for d in list(visibility_by_depth):
                if d > depth:
                    del visibility_by_depth[d]

    return result


def child_qualified(parent: str | None, name: str) -> str:
    if parent is None:
        return name
    if name.startswith(parent + "."):
        return name
    return parent + "." + name


def canonical_symbol_name(name: str) -> str:
    """Normalize DMD/DDox symbol spellings for source-visibility matching."""
    name = re.sub(r"!([^)]*)", "", name)
    name = re.sub(r"(?<=[A-Za-z0-9_])([^)]*)", "", name)
    name = re.sub(r"s+", "", name)
    return name.strip(".")


def matches_internal(parent: str | None, name: str, internal: set[str]) -> bool:
    candidates = {canonical_symbol_name(name)}
    if parent:
        candidates.add(canonical_symbol_name(child_qualified(parent, name)))

    for candidate in candidates:
        if candidate in internal:
            return True

        candidate_parts = candidate.split(".")
        for symbol in internal:
            symbol_parts = symbol.split(".")
            if (
                len(candidate_parts) >= len(symbol_parts)
                and candidate_parts[-len(symbol_parts):] == symbol_parts
            ):
                return True

    return False


def filter_members(node, parent: str | None, internal: set[str]) -> int:
    removed = 0

    if isinstance(node, list):
        kept = []
        for item in node:
            item_name = item.get("name") if isinstance(item, dict) else None

            if (
                parent
                and isinstance(item_name, str)
                and matches_internal(parent, item_name, internal)
            ):
                removed += 1
                continue

            removed += filter_members(item, parent, internal)
            kept.append(item)

        node[:] = kept
        return removed

    if not isinstance(node, dict):
        return 0

    name = node.get("name")
    current = parent
    if isinstance(name, str) and name:
        current = canonical_symbol_name(child_qualified(parent, name))

    for key in list(node):
        value = node[key]

        if isinstance(value, dict):
            child_name = value.get("name")
            if (
                current
                and isinstance(child_name, str)
                and matches_internal(current, child_name, internal)
            ):
                del node[key]
                removed += 1
                continue

            removed += filter_members(value, current, internal)

        elif isinstance(value, list):
            removed += filter_members(value, current, internal)

    return removed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove source-private/package aggregate members from DMD JSON before DDox."
    )
    parser.add_argument("json_file", type=Path)
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()

    internal = internal_symbols(args.source_root)
    data = json.loads(args.json_file.read_text())
    removed = filter_members(data, None, internal)

    args.json_file.write_text(json.dumps(data, separators=(",", ":")))

    print(
        f"PASS: source-aware DDox filter removed {removed} internal aggregate members "
        f"from {len(internal)} internal declarations"
    )


if __name__ == "__main__":
    main()
