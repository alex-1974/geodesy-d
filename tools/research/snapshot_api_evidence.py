#!/usr/bin/env python3
"""Record source/manifest consistency and SHA256 of generated C1 audit evidence."""
import argparse
import csv
import hashlib
import json
import pathlib
import subprocess


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[2])
    p.add_argument("--output", type=pathlib.Path, default=pathlib.Path("build/v2-evidence-manifest.json"))
    a = p.parse_args()
    root = a.root.resolve()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root,
                                     text=True).strip()
    # Generated build/ files are deliberately untracked and must not cause
    # false dirty-source failures. Reject *all* other source changes.
    tracked = subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=no"],
        cwd=root, text=True).strip()
    untracked = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"],
        cwd=root, text=True).splitlines()
    unexpected = [p for p in untracked if not p.startswith("build/")]
    changes = tracked + ("\n" + "\n".join(unexpected) if unexpected else "")
    compiler_manifest_path = root / "build/api-json-dmd/manifest.json"
    compiler_manifest = json.loads(compiler_manifest_path.read_text(encoding="utf-8"))
    if compiler_manifest.get("source_commit") != commit:
        raise SystemExit("ERROR: DMD JSON captured at different source commit")
    if changes:
        raise SystemExit("ERROR: tracked or untracked source changes: " + changes[:800])
    names = ["v2-public-ddox-prototypes.csv", "v2-dmd-ddox-triage.csv",
             "v2-overload-pairing.csv", "v2-paired-overload-contracts.csv",
             "v2-overload-constraint-candidates.csv", "v2-defaults-receivers.csv",
             "v2-enum-contracts.csv"]
    evidence = []
    for name in names:
        path = root / "build" / name
        with path.open(encoding="utf-8", newline="") as f:
            count = sum(1 for _ in csv.DictReader(f))
        evidence.append({"file": name, "sha256": sha256(path), "rows": count})
    if [x["rows"] for x in evidence[:3]] != [488, 1914, 35]:
        raise SystemExit("ERROR: unexpected 488/1914/35 snapshot dimensions")
    record = {
        "source_commit": commit,
        "clean_worktree": True,
        "dmd_version": compiler_manifest["version"],
        "dmd_public_module_count": len(compiler_manifest["public_modules"]),
        "dmd_manifest_sha256": sha256(compiler_manifest_path),
        "evidence": evidence,
        "warning": "Research evidence, not exhaustive semantic or API-freeze certification.",
    }
    target = (root / a.output).resolve() if not a.output.is_absolute() else a.output
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: clean same-commit snapshot {commit} -> {target}")


if __name__ == "__main__":
    main()
