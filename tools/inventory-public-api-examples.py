#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


TITLE_RE = re.compile(r"<title>(?P<title>.*?)</title>", re.IGNORECASE | re.DOTALL)


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inventory public geodesy-d DDox symbol pages and rendered Examples."
    )
    parser.add_argument(
        "site",
        nargs="?",
        default="build/ddox/site",
        type=Path,
    )
    return parser.parse_args()


def public_module_pages(site: Path) -> set[Path]:
    pages = {
        site / "geodesy.html",
    }

    source_root = Path("source/geodesy")

    if not source_root.is_dir():
        fail("source/geodesy is missing")

    for source in source_root.rglob("*.d"):
        relative = source.relative_to(source_root)

        if "internal" in relative.parts:
            continue

        if relative.name == "package.d":
            continue

        module = relative.with_suffix("")
        pages.add(site / "geodesy" / module.with_suffix(".html"))

    return pages


def display_name(site: Path, page: Path) -> str:
    relative = page.relative_to(site).with_suffix("")
    parts = relative.parts

    if not parts or parts[0] != "geodesy":
        return str(relative)

    return ".".join(parts)


def main() -> None:
    args = parse_arguments()
    site = args.site

    if not site.is_dir():
        fail(f"DDox site is missing: {site}")

    excluded = {
        site / "index.html",
        *public_module_pages(site),
    }

    pages = sorted(
        page
        for page in site.rglob("*.html")
        if page not in excluded
    )

    if not pages:
        fail("no public DDox symbol pages found")

    existing = 0

    print("| DDox page | Example |")
    print("| --- | --- |")

    for page in pages:
        html = page.read_text(errors="replace")
        has_example = ">Example<" in html
        existing += int(has_example)

        print(
            f"| `{display_name(site, page)}` "
            f"| {'yes' if has_example else 'no'} |"
        )

    print()
    print(
        f"TOTAL {len(pages)} public symbol pages; "
        f"{existing} render Example; "
        f"{len(pages) - existing} do not"
    )


if __name__ == "__main__":
    main()
