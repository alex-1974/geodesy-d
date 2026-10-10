#!/usr/bin/env python3
"""Compile-only D reflection of members of public aggregate declarations.

Uses compiler getMember/allMembers/getProtection for top-level public types.
This is a declared-member inventory, NOT a proof of external callability,
instantiated template contracts, or inherited/mixin member completeness.
"""
import argparse
import csv
from pathlib import Path

from compiler_visibility_census import (
    PACKAGE, exported_modules, parse_records, run_census,
)

MARKER = "__GEODESY_AGG__"


def generate(modules):
    out = ["module geodesy_aggregate_probe;"]
    for i, module in enumerate(modules):
        out.append(f"import m{i} = {module};")
    for i, module in enumerate(modules):
        out += [
            f"static foreach (tname; __traits(allMembers, m{i})) {{",
            "  static if (tname != \"object\" &&",
            f"    __traits(compiles, __traits(getMember, m{i}, tname))) {{",
            f"    alias T = __traits(getMember, m{i}, tname);",
            "    static if (__traits(compiles, __traits(allMembers, T)) &&",
            "      __traits(compiles, __traits(getProtection, T)) &&",
            "      __traits(getProtection, T) == \"public\" &&",
            "      (is(T == struct) || is(T == class) || is(T == union) || is(T == interface))) {",
            "      static foreach (memberName; __traits(allMembers, T)) {",
            "        static if (__traits(compiles,",
            "          __traits(getProtection, __traits(getMember, T, memberName)))) {",
            f'          pragma(msg, "{MARKER}\\t{module}\\t" ~ tname ~',
            '            "\\t" ~ memberName ~ "\\t" ~',
            "            __traits(getProtection, __traits(getMember, T, memberName)));",
            "        } else {",
            f'          pragma(msg, "{MARKER}\\t{module}\\t" ~ tname ~',
            '            "\\t" ~ memberName ~ "\\tunresolved");',
            "        }",
            "      }",
            "    }",
            "  }",
            "}",
        ]
    return "\n".join(out) + "\n"


def parse(text):
    import re
    pattern = re.compile(
        re.escape(MARKER) +
        r"\t(?P<module>[^\t\r\n]+)\t(?P<type>[^\t\r\n]+)" +
        r"\t(?P<member>[^\t\r\n]+)\t(?P<protection>[^\t\r\n]+)"
    )
    return sorted((m.groupdict() for m in pattern.finditer(text)),
                  key=lambda r: (r["module"], r["type"], r["member"], r["protection"]))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--compiler", default="dmd")
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--source-output", type=Path)
    args = p.parse_args()
    modules = exported_modules(PACKAGE.read_text(encoding="utf-8"))
    source = generate(modules)
    if args.source_output:
        args.source_output.parent.mkdir(parents=True, exist_ok=True)
        args.source_output.write_text(source)
    # Reuse compiler invocation; parse its output with aggregate-specific marker.
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory(prefix="geodesy-aggregate-") as tmp:
        f = Path(tmp) / "probe.d"
        f.write_text(source)
        result = subprocess.run([args.compiler, "-o-", "-Isource", str(f)],
                                capture_output=True, text=True,
                                cwd=PACKAGE.parents[2])
    log = result.stdout + "\n" + result.stderr
    if result.returncode:
        raise SystemExit(f"compiler failed ({result.returncode}):\n" + log[-4000:])
    rows = parse(log)
    if not rows:
        raise SystemExit("no aggregate-member records emitted")
    if any(r["protection"] == "unresolved" for r in rows):
        raise SystemExit("aggregate-member protection could not be resolved")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["module", "type", "member", "protection"])
        writer.writeheader()
        writer.writerows(rows)
    print(f"PASS: reflected {len(rows)} public-aggregate member entries")
    print(f"Report: {args.output}")


if __name__ == "__main__":
    main()
