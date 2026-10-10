#!/usr/bin/env python3
"""Conservative function defaults, receiver-const and scalar constraint audit.

This is an exact-information check: opaque DMD types are unresolved.
"""
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

from compare_overload_signatures import ddox_params, dmd_params, parts


def normalize(value):
    return re.sub(r"\s+", "", value or "")


def call_parts(signature, symbol):
    leaf = re.escape(symbol.split(".")[-1])
    m = re.search(r"\b" + leaf + r"\s*(?:\(\s*T\s*\)\s*)?\(", signature)
    if not m:
        raise ValueError(f"Unrecognized DDox call: {signature}")
    depth, start = 1, m.end()
    for i in range(start, len(signature)):
        if signature[i] == "(":
            depth += 1
        elif signature[i] == ")":
            depth -= 1
            if depth == 0:
                return parts(signature[start:i]), signature[i + 1:]
    raise ValueError(f"Unbalanced DDox declaration: {signature}")


def audit(documents, compiler):
    groups, functions, wrappers = defaultdict(list), defaultdict(list), defaultdict(list)
    for r in documents:
        groups[r["module"], r["symbol"]].append(r)
    for r in compiler:
        key = (r["module"], r["symbol"])
        if r["kind"] == "function":
            functions[key].append(r)
        elif r["kind"] == "template":
            wrappers[key].append(r)
    rows = []
    for key, pages in sorted(groups.items()):
        candidate = functions[key]
        if not candidate:
            continue
        by_params = defaultdict(list)
        for r in candidate:
            by_params[dmd_params(r)].append(r)
        for doc in pages:
            status = "unpaired"
            selected = []
            if len(pages) == len(candidate) == 1:
                selected = candidate
            else:
                selected = by_params[ddox_params(doc)]
            if len(selected) != 1:
                rows.append(dict(module=key[0], symbol=key[1],
                                 overload=doc["overload"],
                                 pair="ambiguous_or_missing",
                                 defaults="unresolved", receiver_const="unresolved",
                                 wrapper_constraint="unresolved"))
                continue
            dmd = selected[0]
            arguments, suffix = call_parts(doc["signature"], doc["symbol"])
            dmd_arguments = json.loads(dmd["parameters"])
            if len(arguments) != len(dmd_arguments):
                defaults = "parameter_count_difference"
            else:
                defaults = "match"
                for arg, p in zip(arguments, dmd_arguments):
                    expected = normalize(arg.split("=", 1)[1]) if "=" in arg else ""
                    actual = normalize(p.get("default", ""))
                    if expected != actual:
                        defaults = "difference"
                        break
            dmd_type = dmd.get("type", "")
            if not dmd_type:
                const = "opaque_dmd_function_type"
            else:
                ddox_const = bool(re.search(r"\bconst\b", suffix))
                dmd_const = bool(re.match(r"^\s*const\b", dmd_type))
                const = "match" if ddox_const == dmd_const else "difference"
            declaration_constraint = normalize(
                re.search(r"\bif\s*\((.*)\)\s*;", suffix).group(1)
            ) if re.search(r"\bif\s*\((.*)\)\s*;", suffix) else ""
            same_line = [w for w in wrappers[key] if
                         w.get("line") and w["line"] == dmd.get("line")]
            if len(same_line) == 1:
                extracted = normalize(same_line[0].get("constraint", ""))
                constraint = ("match" if extracted == declaration_constraint
                              else "difference")
            elif declaration_constraint:
                constraint = "wrapper_not_found"
            else:
                constraint = "not_function_template"
            rows.append(dict(module=key[0], symbol=key[1],
                             overload=doc["overload"], pair="unique",
                             defaults=defaults, receiver_const=const,
                             wrapper_constraint=constraint))
    return rows


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    with open(sys.argv[1], encoding="utf-8", newline="") as f:
        ddox = list(csv.DictReader(f))
    with open(sys.argv[2], encoding="utf-8", newline="") as f:
        dmd = list(csv.DictReader(f))
    rows = audit(ddox, dmd)
    dest = Path(sys.argv[3])
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", encoding="utf-8", newline="") as f:
        fields = ["module", "symbol", "overload", "pair", "defaults",
                  "receiver_const", "wrapper_constraint"]
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print("Audited function prototypes:", len(rows))
    for field in ("pair", "defaults", "receiver_const", "wrapper_constraint"):
        print(field, dict(sorted(Counter(r[field] for r in rows).items())))
    if len(rows) != 425 or any(
        r["pair"] != "unique" or r["defaults"] in ("difference", "parameter_count_difference")
        or r["receiver_const"] == "difference"
        or r["wrapper_constraint"] == "difference" for r in rows
    ):
        raise SystemExit("FAIL: inspect defaults/receiver/constraint differences")
    print("PASS: no detected defaults, receiver-const or wrapper-constraint differences")
    print("NOTE: opaque types, missing wrappers and full template behavior still pending.")


if __name__ == "__main__":
    main()
