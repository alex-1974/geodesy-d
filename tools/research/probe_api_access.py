#!/usr/bin/env python3
"""Compile external D consumer accessibility probes for triaged declarations.

Never equate a successful name lookup with full signature compatibility.
Usage:
 python3 tools/research/probe_api_access.py build/v2-dmd-ddox-triage.csv build/api-access-probes.csv --compiler dmd
 python3 tools/research/probe_api_access.py build/v2-dmd-ddox-triage.csv build/api-access-probes-ldc.csv --compiler ldc2

By default probe only qualified, module-level types and aliases not covered by
DDox, prioritizing previously ambiguous names. --all additionally probes other
simple module-level names; nested methods and templates are deliberately skipped.
"""
import argparse
import csv
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
IDENT = re.compile(r"^[A-Za-z_][A-Za-z_0-9]*$")


def candidates(rows, all_names=False):
    seen = set()
    for row in rows:
        name, module = row["symbol"], row["module"]
        if "." in name or not IDENT.fullmatch(name):
            continue
        if row["kind"] not in ({"struct", "class", "interface", "enum", "alias", "template"}
                              if not all_names else
                              {"struct", "class", "interface", "enum", "alias", "template", "function", "variable"}):
            continue
        if row.get("ddox_page_name_match") == "yes" and not all_names:
            continue
        if row.get("wrapper_or_generated_review") == "yes" and row["kind"] != "template":
            continue
        key = module, name
        if key not in seen:
            seen.add(key)
            yield row


def probe(compiler, module, name, timeout):
    # Fully qualified, type-or-symbol existence lookup in an external module.
    # Compile-time __traits(compiles) catches accessibility and substitution
    # failures without running the candidate or constructing its values.
    source = ("module api_access_probe;\n"
              f"import {module};\n"
              f"enum bool accessible = __traits(compiles, {module}.{name});\n"
              "static assert(accessible || !accessible);\n"
              "void main() {}\n")
    with tempfile.TemporaryDirectory(prefix="geodesy-api-probe-") as d:
        path = pathlib.Path(d) / "probe.d"
        path.write_text(source, encoding="utf-8")
        cmd = [compiler, "-o-", f"-I{ROOT / 'source'}", str(path)]
        proc = subprocess.run(cmd, cwd=d, capture_output=True, text=True,
                              timeout=timeout)
        if proc.returncode:
            return "compiler_error", (proc.stderr or proc.stdout)[-1200:]
        # This first-stage probe compiles either boolean result. Resolve result
        # with two mutually exclusive static assertions in separate compilation.
        true_source = source.replace("static assert(accessible || !accessible);",
                                     'static assert(accessible, "inaccessible");')
        path.write_text(true_source, encoding="utf-8")
        yes = subprocess.run(cmd, cwd=d, capture_output=True, text=True,
                             timeout=timeout)
        if yes.returncode == 0:
            return "accessible_lookup", ""
        return "inaccessible_or_nonexpression", (yes.stderr or yes.stdout)[-1200:]


def control_probe(compiler, expression, expected, timeout):
    """Check that the harness can recognize known-accessible symbols."""
    with tempfile.TemporaryDirectory(prefix="geodesy-api-control-") as d:
        path = pathlib.Path(d) / "control.d"
        path.write_text(
            "module api_access_control;\n"
            "import geodesy;\n"
            f'enum bool works = __traits(compiles, {expression});\n'
            f'static assert(works == {str(expected).lower()}, "control mismatch");\n',
            encoding="utf-8")
        p = subprocess.run(
            [compiler, "-o-", f"-I{ROOT / 'source'}", str(path)],
            cwd=d, text=True, capture_output=True, timeout=timeout)
        if p.returncode:
            raise RuntimeError(
                f"{compiler} control failed: {expression}: "
                f"{(p.stderr or p.stdout)[-1500:]}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("triage_csv", type=pathlib.Path)
    p.add_argument("report_csv", type=pathlib.Path)
    p.add_argument("--compiler", default="dmd")
    p.add_argument("--timeout", type=int, default=30)
    p.add_argument("--all", action="store_true")
    args = p.parse_args()
    # Reject a false-negative-only harness before interpreting a single candidate.
    control_probe(args.compiler, "geodesy.GeodeticCoordinate!double", True, args.timeout)
    control_probe(args.compiler, "geodesy.GeocentricCoordinate!double", True, args.timeout)
    # Negative visibility control is an explicitly private repository struct.
    control_probe(args.compiler,
                  "geodesy.geodesic.GeodesicLineRawPosition!double",
                  False, args.timeout)
    # Public type-template instantiations are valid expressions here.
    control_probe(args.compiler, "geodesy.Angle!double", True, args.timeout)
    print("PASS: public and private accessibility controls")
    rows = list(csv.DictReader(args.triage_csv.open(newline="", encoding="utf-8")))
    selected = list(candidates(rows, args.all))
    args.report_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.report_csv.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["module", "symbol", "kind", "line",
                                         "ddox_page_name_match", "source_visibility_hint",
                                         "compiler", "result", "diagnostic"])
        w.writeheader()
        for row in selected:
            result, diagnostic = probe(args.compiler, row["module"], row["symbol"],
                                       args.timeout)
            w.writerow({k: row.get(k, "") for k in
                        ["module", "symbol", "kind", "line",
                         "ddox_page_name_match", "source_visibility_hint"]} |
                       {"compiler": args.compiler, "result": result,
                        "diagnostic": diagnostic})
            print(row["module"], row["symbol"], result)
    print(f"Wrote {len(selected)} external lookup probes to {args.report_csv}")


if __name__ == "__main__":
    main()
