#!/usr/bin/env python3
"""Verify objective module-level Ddoc requirements for the public API."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REQUIRED_SECTIONS = ("Authors:", "Copyright:", "License:", "Date:")


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

    if failures:
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        return 1

    print(
        f"PASS: public module Ddoc contract covers {len(sources)} modules "
        f"({', '.join(REQUIRED_SECTIONS)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
