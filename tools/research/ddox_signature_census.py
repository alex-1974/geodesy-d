#!/usr/bin/env python3
"""Inventory public DDox prototypes, preserving overloads within symbol pages.

Usage:
  python3 tools/research/ddox_signature_census.py SITE_DIR OUTPUT.csv

Requires BeautifulSoup 4 (python3-bs4). The input must be a generated,
public-only DDox site; this does not substitute for compiler/visibility audit.
"""
import csv
import sys
from pathlib import Path
from bs4 import BeautifulSoup


def census(site):
    records = []
    for path in sorted((site / "geodesy").rglob("*.html")):
        page = path.relative_to(site).as_posix()
        document = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
        prototypes = document.select("#main-contents .prototype .single-prototype")
        title = document.title.get_text(" ", strip=True) if document.title else ""
        for ordinal, prototype in enumerate(prototypes, 1):
            signature = " ".join(prototype.get_text(" ", strip=True).split())
            records.append({
                "module": ".".join(path.relative_to(site).parts[:-1]),
                "symbol": path.stem,
                "page": page,
                "overload": ordinal,
                "page_title": title,
                "signature": signature,
            })
    return records


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    site, destination = Path(sys.argv[1]), Path(sys.argv[2])
    if not (site / "geodesy").is_dir():
        raise SystemExit("not a generated DDox site: missing geodesy directory")
    records = census(site)
    if not records:
        raise SystemExit("no public DDox prototypes found")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)
    pages = len({item["page"] for item in records})
    modules = len({item["module"] for item in records})
    print(f"Public DDox snapshot: {len(records)} prototypes, "
          f"{pages} pages, {modules} modules -> {destination}")
    print("Note: does not count undocumented declarations or inspect "
          "template/overload resolution; not an API-freeze sign-off.")


if __name__ == "__main__":
    main()
