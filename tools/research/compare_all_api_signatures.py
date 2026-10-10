#!/usr/bin/env python3
"""Classify every DDox prototype by DMD declaration and compare function parameters.

Usage: python3 tools/research/compare_all_api_signatures.py DDOX.csv TRIAGE.csv REPORT.csv
Statuses are explicit; non-function declarations are NOT compared as functions.
"""
import csv
import pathlib
import re
import sys
from collections import Counter, defaultdict

from compare_overload_signatures import ddox_params, dmd_params


def main(ddox_path, triage_path, report_path):
    with open(ddox_path, newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    with open(triage_path, newline="", encoding="utf-8") as f:
        triage = list(csv.DictReader(f))
    by_name = defaultdict(list)
    for item in triage:
        by_name[(item["module"], item["symbol"])].append(item)
    grouped = defaultdict(list)
    for item in ddox:
        grouped[(item["module"], item["symbol"])].append(item)

    report = []
    for key, pages in sorted(grouped.items()):
        matched = by_name.get(key, [])
        functions = [x for x in matched if x["kind"] == "function"]
        kinds = ",".join(sorted(set(x["kind"] for x in matched)))
        if not matched:
            status = "no_dmd_name_candidate"
        elif not functions:
            status = "nonfunction_requires_kind_specific_review"
        else:
            try:
                seen = Counter(ddox_params(x) for x in pages)
                compiled = Counter(dmd_params(x) for x in functions)
                status = ("parameter_multiset_match" if seen == compiled
                          else "parameter_multiset_mismatch")
            except (ValueError, TypeError, KeyError, IndexError) as exc:
                status = "unparsed_function_signature"
        for page in pages:
            report.append({
                "module": page["module"], "symbol": page["symbol"],
                "overload": page["overload"], "ddox_signature": page["signature"],
                "dmd_kinds": kinds, "ddox_family_count": len(pages),
                "dmd_function_count": len(functions), "status": status,
            })

    destination = pathlib.Path(report_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    cols = ["module", "symbol", "overload", "ddox_signature", "dmd_kinds",
            "ddox_family_count", "dmd_function_count", "status"]
    with destination.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=cols)
        writer.writeheader()
        writer.writerows(report)
    counts = Counter(x["status"] for x in report)
    print("DDox prototypes reviewed:", len(report))
    for key, count in sorted(counts.items()):
        print(key, count)
    print("Report:", destination)
    print("NOTE: Only function parameter lists are compared; no return type,")
    print("template constraints, attributes, defaults or overload resolution.")
    if len(report) != len(ddox) or counts["no_dmd_name_candidate"]:
        raise SystemExit(1)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
