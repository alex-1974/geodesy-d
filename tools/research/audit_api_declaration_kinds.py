#!/usr/bin/env python3
"""Audit DDox prototype kinds against DMD JSON triage without guessing opaque types.

Usage:
  python3 tools/research/audit_api_declaration_kinds.py DDOX.csv TRIAGE.csv OUT.csv

No declaration is considered fully verified solely by matching its name.
"""
import csv
import json
import pathlib
import re
import sys
from collections import Counter, defaultdict


def squash(value):
    return re.sub(r"\\s+", "", value)


def check(ddox, candidates):
    signature = ddox["signature"].strip()
    kinds = {row["kind"] for row in candidates}
    if not candidates:
        return "missing_dmd_candidate", ""
    if "function" in kinds:
        functions = [row for row in candidates if row["kind"] == "function"]
        opaque = []
        for fun in functions:
            parameters = json.loads(fun["parameters"])
            for param in parameters:
                if "deco" in param and not param.get("type"):
                    opaque.append(param.get("name", "<unnamed>"))
        if opaque:
            return "opaque_dmd_parameter_type", ",".join(sorted(set(opaque)))
        return "function_pending_full_contract", ""
    if signature.startswith("struct ") and "struct" in kinds:
        wrappers = [row for row in candidates if row["kind"] == "template"]
        constraints = {squash(w["constraint"]) for w in wrappers if w["constraint"]}
        ddox_constraint = re.search(r"\\bif\\s*\\((.*?)\\)\\s*;", signature)
        if ddox_constraint and constraints:
            if squash(ddox_constraint.group(1)) not in constraints:
                return "struct_template_constraint_difference", " | ".join(sorted(constraints))
        return "struct_kind_matched_constraints_pending" if not ddox_constraint else "struct_kind_constraint_matched", ""
    if signature.startswith("alias ") and "alias" in kinds:
        target = signature.split("=", 1)[1].rsplit(";", 1)[0] if "=" in signature else ""
        compiler_targets = [row["type"] for row in candidates if row["kind"] == "alias"]
        if target and compiler_targets and squash(target) not in {squash(x) for x in compiler_targets}:
            return "alias_target_difference", " | ".join(compiler_targets)
        return "alias_target_matched" if target and compiler_targets else "alias_target_unverified", ""
    if signature.startswith("enum ") and "enum" in kinds:
        return "enum_kind_matched_members_pending", ""
    if signature.startswith("class ") and "class" in kinds:
        return "class_kind_matched_base_pending", ""
    if signature.startswith("this ") and "constructor" in kinds:
        return "constructor_parameters_pending", ""
    if "template" in kinds:
        return "template_declaration_pending", ""
    return "kind_not_resolved", ",".join(sorted(kinds))


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    with open(sys.argv[1], encoding="utf-8", newline="") as f:
        ddox = list(csv.DictReader(f))
    with open(sys.argv[2], encoding="utf-8", newline="") as f:
        dmd = list(csv.DictReader(f))
    lookup = defaultdict(list)
    for row in dmd:
        lookup[row["module"], row["symbol"]].append(row)
    rows = []
    for row in ddox:
        candidates = lookup[row["module"], row["symbol"]]
        status, detail = check(row, candidates)
        rows.append({"module": row["module"], "symbol": row["symbol"],
                     "overload": row["overload"], "status": status,
                     "detail": detail, "ddox_signature": row["signature"]})
    out = pathlib.Path(sys.argv[3])
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print("Prototype rows:", len(rows))
    for key, count in sorted(Counter(row["status"] for row in rows).items()):
        print(f"{key}: {count}")
    print("Report:", out)
    if any(row["status"] == "missing_dmd_candidate" for row in rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
