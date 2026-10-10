#!/usr/bin/env python3
"""Conservative DDox/DMD function contract audit (return types and attributes).

Only reports verified matches where DMD supplies a textual function type.
Opaque DMD types, constructors, templates and ambiguous overload pairings
are recorded as unresolved, not silently accepted.
"""
import csv
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ATTRS = ("pure", "nothrow", "@nogc", "@safe", "@trusted", "@system",
         "@property", "ref", "scope", "return")
MODES = {"static", "abstract", "final", "override", "synchronized", "deprecated"}
FUNCTION_TYPE = re.compile(r"^(.*?)\((.*)\\)$")


def norm(s):
    return re.sub(r"\s+", "", s).replace("const(uint)", "constuint")


def signature_parts(ddox):
    # Strip trailing semicolon; input already classified as a function.
    text = ddox.strip().rstrip(";").strip()
    attr = frozenset(x for x in ATTRS if re.search(
        r"(?<![A-Za-z_])" + re.escape(x) + r"(?![A-Za-z_])", text))
    # DDox can include a return type and call with generic names.
    # The return token immediately precedes the leaf symbol.
    return text, attr


def type_parts(dmd):
    raw = dmd.strip()
    if not raw:
        return None
    attr = frozenset(x for x in ATTRS if re.search(
        r"(?<![A-Za-z_])" + re.escape(x) + r"(?![A-Za-z_])", raw))
    m = FUNCTION_TYPE.match(raw)
    if not m:
        return None
    prefix = m.group(1)
    # Extract rightmost type token after qualifiers; simple scalar/template returns.
    tokens = prefix.split()
    qualifiers = {"const", "immutable", "shared", "inout"} | set(ATTRS)
    returns = [x for x in tokens if x not in qualifiers]
    if len(returns) != 1:
        return None
    return returns[0], attr


def ddox_return(text, symbol):
    leaf = re.escape(symbol.split(".")[-1])
    # Avoid treating a constructor as returning the class type.
    m = re.search(r"^\s*(.*?)\b" + leaf + r"\s*\(", text)
    if not m:
        return None
    pre = [x for x in m.group(1).strip().split()
           if x not in MODES and x not in ATTRS]
    return pre[-1] if len(pre) == 1 else None


def run(ddox_file, triage_file, output):
    with open(ddox_file, newline="", encoding="utf-8") as f:
        ddox = list(csv.DictReader(f))
    with open(triage_file, newline="", encoding="utf-8") as f:
        triage = list(csv.DictReader(f))
    by_key = defaultdict(list)
    for r in triage:
        if r["kind"] == "function":
            by_key[r["module"], r["symbol"]].append(r)
    groups = defaultdict(list)
    for row in ddox:
        groups[row["module"], row["symbol"]].append(row)
    out = []
    for (module, symbol), pages in sorted(groups.items()):
        funs = by_key.get((module, symbol), [])
        for row in pages:
            text, dattr = signature_parts(row["signature"])
            dret = ddox_return(text, symbol) if funs else None
            candidates = [type_parts(f["type"]) for f in funs]
            candidates = [c for c in candidates if c is not None]
            if not funs:
                state = "nonfunction_separate_review"
            elif len(pages) != 1 or len(funs) != 1:
                state = "overload_pairing_pending"
            elif not candidates or dret is None:
                state = "opaque_or_complex_type_review"
            else:
                creturn, cattr = candidates[0]
                # The DMD prefix includes method-level 'const', which DDox
                # places after parentheses. Both are scanned globally.
                state = ("return_and_attributes_match" if
                         norm(dret) == norm(creturn) and
                         dattr == cattr else "return_or_attribute_difference")
            out.append({"module": module, "symbol": symbol,
                        "overload": row["overload"], "status": state,
                        "ddox_return": dret or "",
                        "dmd_function_types": " | ".join(f["type"] for f in funs),
                        "ddox_attributes": " ".join(sorted(dattr)),
                        "ddox_signature": row["signature"]})
    p = Path(output)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=out[0].keys())
        w.writeheader()
        w.writerows(out)
    counts = Counter(r["status"] for r in out)
    print("DDox rows:", len(out))
    for k, v in sorted(counts.items()):
        print(k, v)
    print("Report:", p)
    if len(out) != len(ddox):
        raise SystemExit(1)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    run(*sys.argv[1:])
