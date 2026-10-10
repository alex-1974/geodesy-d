#!/usr/bin/env python3
"""Compare DDox overload parameter multisets with DMD function JSON triage."""
import csv
import json
import re
import sys
from collections import Counter, defaultdict


def normalized(s):
    return re.sub(r"\s+", "", s)


def parts(text):
    result = []
    start = depth = 0
    for i, char in enumerate(text):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            result.append(text[start:i].strip())
            start = i + 1
    if text[start:].strip():
        result.append(text[start:].strip())
    return result


def ddox_params(row):
    signature = row["signature"]
    name = re.escape(row["symbol"].split(".")[-1])
    match = re.search(r"\b" + name + r"\s*(?:\(\s*T\s*\)\s*)?\(", signature)
    if match is None:
        raise ValueError(signature)
    start = match.end()
    depth = 1
    for i in range(start, len(signature)):
        if signature[i] == "(":
            depth += 1
        elif signature[i] == ")":
            depth -= 1
            if depth == 0:
                return tuple(normalized(x.split("=", 1)[0])
                             for x in parts(signature[start:i]))
    raise ValueError("Unbalanced declaration: " + signature)


def dmd_params(row):
    return tuple(normalized(" ".join(p.get("storageClass", [])) + " " +
                            p.get("type", "") + " " + p.get("name", ""))
                 for p in json.loads(row["parameters"]))


def main(ddox_path, triage_path):
    with open(ddox_path, newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    with open(triage_path, newline="", encoding="utf-8") as f:
        triage = list(csv.DictReader(f))
    groups = defaultdict(list)
    for row in ddox:
        groups[row["module"], row["symbol"]].append(row)
    overloaded = {key: rows for key, rows in groups.items() if len(rows) > 1}
    passed = 0
    for (module, symbol), rows in sorted(overloaded.items()):
        expected = Counter(dmd_params(x) for x in triage
                           if x["module"] == module and
                           x["symbol"] == symbol and x["kind"] == "function")
        observed = Counter(ddox_params(x) for x in rows)
        same = expected == observed
        print(("PASS" if same else "FAIL"), module, symbol,
              "DDox:", len(rows), "DMD:", sum(expected.values()))
        passed += same
    print("Matched families:", passed, "of", len(overloaded))
    if passed != len(overloaded):
        raise SystemExit(1)
    print("NOTE: Default expressions, return types, constraints, "
          "attributes and compiler resolution are not checked.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(*sys.argv[1:])
