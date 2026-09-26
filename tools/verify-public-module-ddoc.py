#!/usr/bin/env python3
"""Verify objective module-level Ddoc requirements for the public API."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = ("Authors:", "Copyright:", "License:", "Date:")
NAMED_SECTION = re.compile(r"(?m)^\s*\*?\s*[A-Za-z][A-Za-z_ ]*:\s*$")


def ddoc_prose_before_sections(doc: str) -> list[str]:
    """Return substantive unnamed Ddoc paragraphs before the first named section."""
    match = NAMED_SECTION.search(doc)
    prose = doc[: match.start()] if match else doc

    lines: list[str] = []
    for raw in prose.splitlines():
        line = re.sub(r"^\s*\*?\s?", "", raw).strip()
        if not line:
            lines.append("")
            continue
        if line.startswith("---"):
            continue
        lines.append(line)

    paragraphs = [
        " ".join(part.split())
        for part in re.split(r"\n\s*\n", "\n".join(lines))
        if part.strip()
    ]
    return [part for part in paragraphs if part and not part.startswith("import ")]


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    source_root = root / "source" / "geodesy"

    sources = sorted(
        path
        for path in source_root.rglob("*.d")
        if "internal" not in path.relative_to(source_root).parts
    )

    if not sources:
        print(f"error: no public modules found under {source_root}", file=sys.stderr)
        return 1

    failures: list[str] = []

    for path in sources:
        text = path.read_text(encoding="utf-8")
        module_match = re.search(r"(?m)^module\s+[A-Za-z_][\w.]*\s*;", text)
        if module_match is None:
            failures.append(f"{path.relative_to(root)}: missing module declaration")
            continue

        prefix = text[: module_match.start()]
        doc_match = re.search(r"/\*\*([\s\S]*?)\*/\s*$", prefix)
        if doc_match is None:
            failures.append(
                f"{path.relative_to(root)}: missing module Ddoc immediately before module declaration"
            )
            continue

        doc = doc_match.group(1)
        missing = [section for section in REQUIRED_SECTIONS if section not in doc]
        if missing:
            failures.append(
                f"{path.relative_to(root)}: missing module Ddoc sections: {', '.join(missing)}"
            )

        prose = ddoc_prose_before_sections(doc)
        if not prose:
            failures.append(
                f"{path.relative_to(root)}: missing module Ddoc summary"
            )
        elif len(prose) < 2:
            failures.append(
                f"{path.relative_to(root)}: missing substantive module Ddoc description "
                "after the summary"
            )
        elif len(prose[1]) < 80:
            failures.append(
                f"{path.relative_to(root)}: module Ddoc description is too short "
                "to explain the module role"
            )

    if failures:
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        return 1

    print(
        f"PASS: public module Ddoc contract covers {len(sources)} modules "
        f"(summary + description; {', '.join(REQUIRED_SECTIONS)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
