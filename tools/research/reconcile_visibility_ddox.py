#!/usr/bin/env python3
"""Triage compiler-reflected module-level declarations against DDox pages.

A name is only "documented_name" when its (implementation module, unqualified
symbol) matches a published DDox page. This is NOT proof of full public
accessibility, overload agreement, or package-root reexport resolution.
"""
import argparse
import csv
from collections import Counter
from pathlib import Path


def reconcile(reflected, ddox):
    documented = {(r["module"], r["symbol"]) for r in ddox}
    rows = []
    for entry in reflected:
        module, name, protection = (entry[k] for k in ("module", "name", "protection"))
        if protection != "public":
            status = "nonpublic_declared"
        elif name == "object":
            # D's implicit object module appears in allMembers of each module.
            # It is not a declaration of geodesy-d itself.
            status = "implicit_object_import"
        elif module == "geodesy" and name == "geodesy":
            # The root module's self-name is not an API declaration.
            status = "root_module_self_name"
        elif module == "geodesy":
            status = "root_member_requires_reexport_review"
        elif (module, name) in documented:
            status = "documented_name"
        else:
            status = "public_name_requires_review"
        rows.append(dict(module=module, name=name, protection=protection, status=status))
    return sorted(rows, key=lambda r: (r["module"], r["name"], r["protection"]))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("visibility_csv", type=Path)
    p.add_argument("ddox_csv", type=Path)
    p.add_argument("report_csv", type=Path)
    args = p.parse_args()
    with args.visibility_csv.open(newline="", encoding="utf-8") as f:
        reflected = list(csv.DictReader(f))
    with args.ddox_csv.open(newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    rows = reconcile(reflected, ddox)
    if len(rows) != len(reflected):
        raise SystemExit("lost visibility rows")
    args.report_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.report_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["module", "name", "protection", "status"])
        writer.writeheader()
        writer.writerows(rows)
    counts = dict(sorted(Counter(r["status"] for r in rows).items()))
    print("Visibility/DDox name-only triage:", counts)
    print("PASS: wrote conservative public-surface review queue to", args.report_csv)
    print("NOTE: public_name_requires_review does not imply unintended accessibility.")
    unexpected = [row for row in rows if row["status"] in
                  ("public_name_requires_review", "root_member_requires_reexport_review")]
    if unexpected:
        raise SystemExit("unclassified public module-level names: " +
                         ", ".join(r["module"] + "." + r["name"] for r in unexpected))
    for row in rows:
        if row["status"] in ("public_name_requires_review",
                             "root_member_requires_reexport_review"):
            print("REVIEW: {module}.{name} [{status}]".format(**row))



if __name__ == "__main__":
    main()
