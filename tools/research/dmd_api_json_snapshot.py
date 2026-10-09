#!/usr/bin/env python3
"""Capture compiler-generated DMD JSON for every root-exported module.

Run from repository root:
  python3 tools/research/dmd_api_json_snapshot.py --compiler dmd
  python3 tools/research/dmd_api_json_snapshot.py --compiler dmd --out build/api-json-2.113

DMD -X output is compiler-generated, but this is a raw evidence set,
NOT by itself a compiler-verified declaration/overload or visibility audit.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EXPORTS = ROOT / "source/geodesy/package.d"
IMPORT_RE = re.compile(r"^\s*public\s+import\s+(geodesy(?:\.[\w]+)+)\s*;", re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", default="dmd")
    parser.add_argument("--out", type=Path, default=ROOT / "build/api-json-dmd")
    args = parser.parse_args()
    exports = IMPORT_RE.findall(EXPORTS.read_text(encoding="utf-8"))
    if len(exports) != 28 or len(set(exports)) != len(exports):
        raise SystemExit(f"unexpected root public imports: {len(exports)}")
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=True)
    version = subprocess.run([args.compiler, "--version"], capture_output=True,
                             text=True, check=True).stdout.strip()
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                            capture_output=True, text=True, check=True).stdout.strip()
    entries = []
    for module in exports:
        src = ROOT / "source" / (module.replace(".", "/") + ".d")
        if not src.is_file():
            raise SystemExit(f"missing public source: {src}")
        dest = output / (module + ".json")
        cmd = [args.compiler, "-o-", "-X", f"-Xf={dest}",
               f"-I={ROOT / 'source'}", str(src)]
        subprocess.run(cmd, cwd=ROOT, check=True)
        payload = json.loads(dest.read_text(encoding="utf-8"))
        entries.append({"module": module, "source": str(src.relative_to(ROOT)),
                        "json": dest.name, "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
                        "json_top_type": type(payload).__name__})
    manifest = {"source_commit": commit, "compiler": args.compiler,
                "version": version, "public_modules": entries,
                "warning": "Raw DMD -X JSON is not a complete accessibility audit."}
    target = output / "manifest.json"
    target.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: recorded {len(entries)} root-exported module JSON files")
    print(f"Manifest: {target}")
    print("NEXT: compare declaration/member visibility, aliases and template constraints against DDox.")


if __name__ == "__main__":
    main()
