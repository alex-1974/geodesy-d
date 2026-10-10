#!/usr/bin/env python3
"""Pair DDox overloads with compiler functions, compare selected returns/attrs.

Full receiver qualifiers, defaults, template constraints and consumer
overload resolution are explicitly out of scope.
"""
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path
from compare_overload_signatures import ddox_params, dmd_params
from audit_function_contracts import signature_parts, ddox_return, type_parts, norm


def audit(ddox, triage):
    groups, functions = defaultdict(list), defaultdict(list)
    for row in ddox:
        groups[row["module"], row["symbol"]].append(row)
    for row in triage:
        if row["kind"] == "function":
            functions[row["module"], row["symbol"]].append(row)
    output = []
    for key, pages in sorted(groups.items()):
        if len(pages) <= 1:
            continue
        available = defaultdict(list)
        for func in functions[key]:
            available[dmd_params(func)].append(func)
        for page in pages:
            options = available[ddox_params(page)]
            row = {"module": key[0], "symbol": key[1],
                   "overload": page["overload"], "dmd_line": "",
                   "parameters": "missing_or_ambiguous",
                   "return_type": "unresolved", "selected_attributes": "unresolved",
                   "ddox_return": "", "dmd_return": "",
                   "ddox_attributes": "", "dmd_attributes": "",
                   "template_constraints": "pending"}
            if len(options) == 1:
                func = options.pop()
                row["parameters"] = "unique_match"
                row["dmd_line"] = func.get("line", "")
                signature, attrs = signature_parts(page["signature"])
                dr = ddox_return(signature, page["symbol"])
                ct = type_parts(func.get("type", ""))
                row["ddox_return"] = dr or ""
                row["ddox_attributes"] = " ".join(sorted(attrs))
                if dr is not None and ct is not None:
                    ret, cattrs = ct
                    row["dmd_return"] = ret
                    row["dmd_attributes"] = " ".join(sorted(cattrs))
                    row["return_type"] = ("selected_match" if norm(dr) == norm(ret)
                                          else "difference")
                    row["selected_attributes"] = ("selected_match" if attrs == cattrs
                                                  else "difference")
            output.append(row)
        if any(available.values()):
            raise ValueError(f"unpaired compiler declarations: {key!r}")
    return output


def main(ddox_path, triage_path, report_path):
    with open(ddox_path, newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    with open(triage_path, newline="", encoding="utf-8") as f:
        triage = list(csv.DictReader(f))
    rows = audit(ddox, triage)
    dest = Path(report_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print("Overloaded prototypes:", len(rows))
    for field in ("parameters", "return_type", "selected_attributes",
                  "template_constraints"):
        print(field, dict(sorted(Counter(x[field] for x in rows).items())))
    if len(rows) != 35 or any(
        r["parameters"] != "unique_match"
        or r["return_type"] == "difference"
        or r["selected_attributes"] == "difference"
        for r in rows
    ):
        raise SystemExit("FAIL: inspect overload contract report")
    print("PASS: parameter pairing and selected contracts; constraints still pending")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
