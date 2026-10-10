# C1 declaration-kind audit — next validation gate

The full XPS CSV captured 488 DDox prototypes: 423 parameter-list matches, two UTM mismatch reports and 63 nonfunction records requiring a kind-aware review.

## UTM cases: opaque compiler types, not verified equivalence

`UtmZone.fromNumber` and `UtmZone.tryFromNumber` render `const(uint) number` in DDox. Source declares `const uint number`. Yet the DMD JSON triage stores that parameter as `{"deco":"xk","name":"number"}`, **without an explicit `type` field**. The earlier signature comparator reconstructs parameters only from `type` and `storageClass`, so its two reported mismatches cannot establish API disagreement. Likewise, source spelling alone does not validate all compiler signature details. Do not silently normalize `xk` to `const(uint)` without independent evidence.

## Kind-aware classification

Added `tools/research/audit_api_declaration_kinds.py`. It emits explicit statuses for:

- function records with opaque DMD parameter types;
- struct and class declaration kinds;
- templated struct constraint comparisons where DMD supplies constraints;
- alias target comparisons where DMD supplies target spelling;
- enum kinds whose members require separate review;
- constructors and unclassified template declarations.

This is **classification evidence**, not complete structural equality. In particular, constructor defaults, enum values, base classes, inherited/public aggregate members, template defaults and compiled instantiations need follow-up.

Run:

```sh
python3 -m py_compile tools/research/audit_api_declaration_kinds.py
python3 tools/research/audit_api_declaration_kinds.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-api-declaration-kind-audit.csv
```

Re-run DMD JSON, DDox, and all reports on the **same pinned commit** before the final C1 decision. No release freeze is authorized from current snapshots.
