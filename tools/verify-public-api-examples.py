#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


ROW_RE = re.compile(
    r"^\| `(?P<page>geodesy(?:\.[A-Za-z0-9_]+)+)` "
    r"\| (?P<status>existing|add|family) "
    r"\| (?P<family>[^|]+?) \|$"
)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify geodesy-d public DDox example coverage."
    )
    parser.add_argument("site", type=Path)
    parser.add_argument("audit", type=Path)
    parser.add_argument(
        "--source-root",
        type=Path,
        default=Path("."),
        help="source tree whose documented unittests back rendered examples",
    )
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="fail while any public page remains classified as add",
    )
    parser.add_argument(
        "--require-own-example",
        action="store_true",
        help=(
            "fail unless every public DDox symbol page is classified as "
            "existing and renders its own documented unittest Example"
        ),
    )
    return parser.parse_args()


def public_module_pages(site: Path) -> set[Path]:
    pages = {site / "geodesy.html"}
    source_root = Path("source/geodesy")

    for source in source_root.rglob("*.d"):
        relative = source.relative_to(source_root)
        if "internal" in relative.parts or relative.name == "package.d":
            continue
        pages.add(site / "geodesy" / relative.with_suffix(".html"))

    return pages


def page_name(site: Path, page: Path) -> str:
    relative = page.relative_to(site).with_suffix("")
    return ".".join(relative.parts)


def rendered_pages(site: Path) -> dict[str, Path]:
    excluded = {site / "index.html", *public_module_pages(site)}
    return {
        page_name(site, page): page
        for page in site.rglob("*.html")
        if page not in excluded
    }


def audit_rows(audit: Path) -> dict[str, tuple[str, str]]:
    rows: dict[str, tuple[str, str]] = {}

    for line in audit.read_text().splitlines():
        match = ROW_RE.match(line)
        if not match:
            continue

        page = match.group("page")
        if page in rows:
            fail(f"duplicate audit row: {page}")

        rows[page] = (
            match.group("status"),
            match.group("family").strip(),
        )

    return rows


def documented_unittest_count(source_root: Path) -> int:
    source_dir = source_root / "source" / "geodesy"
    if not source_dir.is_dir():
        fail(f"public source tree is missing: {source_dir}")

    count = 0
    inline_example = re.compile(r"^[ \t]*\*[ \t]+Example:[ \t]*$", re.MULTILINE)
    documented_unittest = re.compile(
        r"^[ \t]*///[^\n]*\n"
        r"(?:[ \t]*@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?[ \t]+)*"
        r"unittest\b",
        re.MULTILINE,
    )

    for source in sorted(source_dir.rglob("*.d")):
        relative = source.relative_to(source_dir)
        if "internal" in relative.parts:
            continue

        text = source.read_text()
        if inline_example.search(text):
            fail(f"legacy inline Example block remains in public source: {source}")
        count += len(documented_unittest.findall(text))

    return count


def main() -> None:
    args = parse_arguments()

    if not args.site.is_dir():
        fail(f"DDox site is missing: {args.site}")
    if not args.audit.is_file():
        fail(f"audit file is missing: {args.audit}")

    pages = rendered_pages(args.site)
    rows = audit_rows(args.audit)
    compiled_examples = documented_unittest_count(args.source_root)

    missing = sorted(set(pages) - set(rows))
    stale = sorted(set(rows) - set(pages))

    if missing:
        fail(
            "public DDox pages missing from audit:\n  "
            + "\n  ".join(missing)
        )
    if stale:
        fail(
            "audit rows without public DDox pages:\n  "
            + "\n  ".join(stale)
        )

    counts = {"existing": 0, "add": 0, "family": 0}

    for name, page in sorted(pages.items()):
        status, family = rows[name]
        counts[status] += 1

        if not family:
            fail(f"audit row has no owning family: {name}")

        html = page.read_text(errors="replace")
        has_example = ">Example<" in html

        if status == "existing" and not has_example:
            fail(f"expected rendered Example is missing: {name}")

    # Rendered HTML is checked per symbol above. A symbol can legitimately
    # own multiple documented unittests, so do not require one-to-one counts.
    # Still require at least as many source examples as covered symbol pages.
    if compiled_examples < counts["existing"]:
        fail(
            "fewer documented unittests than covered public symbols: "
            f"{compiled_examples} documented unittests, "
            f"{counts['existing']} existing audit rows"
        )

    if args.require_complete and counts["add"]:
        fail(
            f"{counts['add']} public pages still require dedicated examples"
        )

    if args.require_own_example:
        incomplete = counts["add"] + counts["family"]
        if incomplete:
            fail(
                f"{incomplete} public pages do not yet have their own "
                "rendered documented-unittest Example "
                f"(add={counts['add']}, family={counts['family']})"
            )

    print(
        "PASS: public API example audit covers "
        f"{len(pages)} pages "
        f"(existing={counts['existing']} compiled, "
        f"add={counts['add']}, family={counts['family']})"
    )


if __name__ == "__main__":
    main()
