#!/usr/bin/env python3
"""Map template constraints for overloaded D function declarations.

Never infer a matching constraint merely from a same-name template:
the template's source line and the function's line must be tied together.
Produces per-overload evidence and explicit unresolved outcomes.
"""
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

from compare_overload_signatures import ddox_params, dmd_params


def classify(ddox_rows, dmd_rows):
    grouped = defaultdict(list)
    compiler = defaultdict(list)
    for row in ddox_rows:
        grouped[row["module"], row["symbol"]].append(row)
    for row in dmd_rows:
        compiler[row["module"], row["symbol"]].append(row)
    result = []
    for key, pages in sorted(grouped.items()):
        if len(pages) <= 1:
            continue
        functions = defaultdict(list)
        wrappers = [r for r in compiler[key] if r["kind"] == "template"]
        for row in compiler[key]:
            if row["kind"] == "function":
                functions[dmd_params(row)].append(row)
        for page in pages:
            param_key = ddox_params(page)
            options = functions[param_key]
            state = "function_pair_missing_or_ambiguous"
            fun_line = ""
            constraint = ""
            wrapper_count = 0
            if len(options) == 1:
                function = options.pop()
                fun_line = function.get("line", "")
                # A source-position equality is strong evidence of template
                # ownership when DMD emits the wrapper and function there.
                # It must NOT be generalized to mere name equality.
                same_line = [w for w in wrappers if w.get("line", "")
                             and w["line"] == fun_line]
                wrapper_count = len(same_line)
                if len(same_line) == 1:
                    constraint = same_line[0].get("constraint", "")
                    state = ("wrapper_line_pair_constraint_available" if constraint
                             else "wrapper_line_pair_no_constraint_text")
                elif not wrappers:
                    state = "no_template_wrapper"
                else:
                    state = "template_wrapper_ownership_unresolved"
            result.append({
                "module": key[0], "symbol": key[1], "overload": page["overload"],
                "dmd_function_line": fun_line, "same_line_wrappers": wrapper_count,
                "dmd_constraint": constraint, "status": state,
                "ddox_signature": page["signature"]})
    return result


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    with open(sys.argv[1], newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    with open(sys.argv[2], newline="", encoding="utf-8") as f:
        dmd = list(csv.DictReader(f))
    rows = classify(ddox, dmd)
    output = Path(sys.argv[3])
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print("Overload constraint candidates:", len(rows))
    for status, count in sorted(Counter(r["status"] for r in rows).items()):
        print(f"{status}: {count}")
    print("Report:", output)
    if len(rows) != 35 or any(
        r["status"] == "function_pair_missing_or_ambiguous" for r in rows
    ):
        raise SystemExit("ERROR: parameter pairing regression")
    print("NOTE: same-line wrappers are only candidate evidence; "
          "DDox constraint equivalence and compiler instantiation pending.")


if __name__ == "__main__":
    main()
