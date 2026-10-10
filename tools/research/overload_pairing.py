#!/usr/bin/env python3
"""Pair DDox overloads with DMD function declarations by exact parameters.

This is a pairing audit, not a complete return/attribute or visibility audit.
"""
import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

from compare_overload_signatures import ddox_params, dmd_params


def pair(ddox_rows, dmd_rows):
    groups = defaultdict(list)
    compiler = defaultdict(list)
    for row in ddox_rows:
        groups[row["module"], row["symbol"]].append(row)
    for row in dmd_rows:
        if row["kind"] == "function":
            compiler[row["module"], row["symbol"]].append(row)
    result = []
    for key, pages in sorted(groups.items()):
        if len(pages) <= 1:
            continue
        available = defaultdict(list)
        for item in compiler[key]:
            available[dmd_params(item)].append(item)
        for ddox in pages:
            params = ddox_params(ddox)
            options = available[params]
            if not options:
                status, line, count = "missing_parameter_match", "", 0
            elif len(options) != 1:
                status, line, count = "ambiguous_parameter_match", "", len(options)
            else:
                match = options.pop()
                status, line, count = "unique_parameter_match", match.get("line", ""), 1
            result.append({
                "module": key[0], "symbol": key[1], "overload": ddox["overload"],
                "status": status, "dmd_source_line": line, "candidate_count": count,
                "normalized_parameter_key": json.dumps(params, ensure_ascii=False),
                "ddox_signature": ddox["signature"]})
        for leftovers in available.values():
            if leftovers:
                result.append({"module": key[0], "symbol": key[1], "overload": "",
                               "status": "unmatched_dmd_function", "dmd_source_line": "",
                               "candidate_count": len(leftovers),
                               "normalized_parameter_key": "", "ddox_signature": ""})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ddox_csv", type=Path)
    parser.add_argument("triage_csv", type=Path)
    parser.add_argument("report_csv", type=Path)
    args = parser.parse_args()
    with args.ddox_csv.open(encoding="utf-8", newline="") as f:
        ddox = list(csv.DictReader(f))
    with args.triage_csv.open(encoding="utf-8", newline="") as f:
        dmd = list(csv.DictReader(f))
    records = pair(ddox, dmd)
    args.report_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.report_csv.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "module", "symbol", "overload", "status", "dmd_source_line",
            "candidate_count", "normalized_parameter_key", "ddox_signature"])
        writer.writeheader()
        writer.writerows(records)
    counts = Counter(row["status"] for row in records)
    print("Overload pairing:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print("Output:", args.report_csv)
    if len(records) != 35 or counts != Counter({"unique_parameter_match": 35}):
        raise SystemExit("ERROR: overload pairing requires review")
    print("PASS: all 35 DDox overloads uniquely paired by ordered parameter list")


if __name__ == "__main__":
    main()
