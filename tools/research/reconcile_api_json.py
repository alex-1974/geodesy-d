#!/usr/bin/env python3
"""Classify DMD -X declaration candidates against public DDox pages.

This produces a conservative TRIAGE, not a definitive D visibility proof.
Use: python3 tools/research/reconcile_api_json.py JSON_DIR DDox.csv REPORT.csv
"""
import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

KINDS = {"function", "template", "struct", "class", "interface",
         "enum", "enum member", "alias", "variable", "constructor"}
TEST_NAME = re.compile(r"^__(?:unittest|lambda|foreach|ctor|dtor|postblit)")
PRIVATE_NAME = re.compile(r"^_")
DIRECT_ACCESS = re.compile(r"\\b(private|package(?:\\([^)]*\\))?|protected|public|export)\\s+(?=(?:struct|class|interface|enum|alias|template)\\b)")
ACCESS_BLOCK = re.compile(r"^\\s*(private|package(?:\\([^)]*\\))?|protected|public|export)\\s*:\\s*(?://.*)?$")


def source_visibility(source, line, name):
    """Conservative lexical hint; brace-scoped D access requires manual review."""
    try:
        line = int(line)  # DMD JSON supplies source positions as strings.
    except (TypeError, ValueError):
        return "unknown", "invalid_source_location"
    if line < 1 or line > len(source):
        return "unknown", "missing_source_location"
    text = source[line - 1]
    # DMD line numbers can point to a Ddoc or template wrapper, not the declaration.
    vicinity = "\\n".join(source[max(0, line - 3):min(len(source), line + 2)])
    match = DIRECT_ACCESS.search(text)
    if match:
        return match.group(1), "explicit_declaration"
    if name and name in vicinity:
        prefix = text.split(name, 1)[0] if name in text else ""
        match = DIRECT_ACCESS.search(prefix)
        if match:
            return match.group(1), "explicit_declaration"
    # A colon clause is informative only within its lexical scope. We intentionally
    # do not resolve braces, mixins or conditional compilation here.
    if any(ACCESS_BLOCK.match(x) for x in source[:line]):
        return "unknown", "access_block_requires_parser"
    return "unknown", "lexical_scope_unverified"


def walk(node, module, ancestors=(), inherited="public"):
    if isinstance(node, list):
        for child in node:
            yield from walk(child, module, ancestors, inherited)
        return
    if not isinstance(node, dict):
        return
    kind = node.get("kind", "")
    name = node.get("name", "")
    explicit = node.get("protection", "")
    effective = explicit or inherited
    if kind in KINDS:
        path = ancestors + ((name,) if name else ())
        if kind == "template" and node.get("members"):
            # DMD models a template's like-named aggregate twice.
            identity = path
        else:
            identity = tuple(x for i,x in enumerate(path)
                             if i == 0 or x != path[i-1])
        flags = []
        if effective != "public":
            flags.append("nonpublic_scope")
        if TEST_NAME.match(name):
            flags.append("compiler_or_test_generated")
        if PRIVATE_NAME.match(name) and not TEST_NAME.match(name):
            flags.append("underscore_name_review")
        if kind == "variable":
            flags.append("variable_review")
        if explicit == "":
            flags.append("inherited_visibility_review")
        yield {
            "module": module, "symbol": ".".join(identity), "kind": kind,
            "line": node.get("line", ""), "protection": effective,
            "explicit_protection": explicit,
            "type": node.get("type", ""), "constraint": node.get("constraint", ""),
            "parameters": json.dumps(node.get("parameters", []), sort_keys=True),
            "triage": ",".join(flags) or "public_candidate",
        }
    next_path = ancestors + ((name,) if kind in {"template", "struct", "class", "interface", "enum"} and name else ())
    for child in node.get("members", []):
        yield from walk(child, module, next_path, effective)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("json_dir", type=Path)
    p.add_argument("ddox_csv", type=Path)
    p.add_argument("report_csv", type=Path)
    a = p.parse_args()
    manifest = json.loads((a.json_dir / "manifest.json").read_text())
    entries = manifest["public_modules"]
    ddox = list(csv.DictReader(a.ddox_csv.open(newline="", encoding="utf-8")))
    ddox_names = {(r["module"], r["symbol"]) for r in ddox}
    prototypes = Counter((r["module"], r["symbol"]) for r in ddox)
    rows = []
    for item in entries:
        name = item["module"]
        data = json.loads((a.json_dir / item["json"]).read_text())
        source = (Path(__file__).resolve().parents[2] / item["source"]).read_text(encoding="utf-8").splitlines()
        for row in walk(data, name):
            symbol_leaf = row["symbol"].split(".")[-1]
            visibility, evidence = source_visibility(source, row["line"], symbol_leaf)
            row["source_visibility_hint"] = visibility
            row["source_visibility_evidence"] = evidence
            rows.append(row)
    for row in rows:
        row["ddox_prototype_count"] = prototypes.get((row["module"], row["symbol"]), 0)
        row["wrapper_or_generated_review"] = "yes" if (row["kind"] == "template" or "compiler_or_test_generated" in row["triage"]) else "no"
        row["ddox_page_name_match"] = "yes" if (
            row["module"], row["symbol"]) in ddox_names else "no"
    a.report_csv.parent.mkdir(parents=True, exist_ok=True)
    with a.report_csv.open("w", newline="", encoding="utf-8") as f:
        cols = ["module", "symbol", "kind", "line", "protection",
                "explicit_protection", "type", "constraint", "parameters",
                "triage", "ddox_page_name_match", "ddox_prototype_count",
                "wrapper_or_generated_review", "source_visibility_hint",
                "source_visibility_evidence"]
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print("Raw DMD candidate records:", len(rows))
    print("DDox prototypes:", len(ddox))
    print("Conservative triage: neither unmatched names nor underscore names")
    print("alone prove public exposure, omissions, or incompatibility.")
    print("DDox symbol pages:", len(ddox_names))
    print("DDox overloaded page count:", sum(v > 1 for v in prototypes.values()))
    print("Explicit source visibility evidence:", sum(r["source_visibility_evidence"] == "explicit_declaration" for r in rows))
    print("All other lexical access hints are UNKNOWN, not PUBLIC.")
    print("Report:", a.report_csv)


if __name__ == "__main__":
    main()
