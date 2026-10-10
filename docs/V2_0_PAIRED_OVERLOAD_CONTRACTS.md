# v2.0 overload contracts: selected return types and attributes

Added `tools/research/audit_paired_overloads.py` to extend the
**35/35 uniquely paired** DDox/DMD overload declarations beyond the
previous parameter-only audit. The tool pairs by exact normalized
parameter tuples, then compares each pair's return-type spelling and
a selected set of function attributes using the established
`audit_function_contracts.py` parser. It does **not** pair by file
order or merely by symbol name.

The report CSV contains per-overload DMD source line, normalized
pairing status, return/attribute status and the compared values.
Missing or ambiguous parameters, opaque function types and detectable
differences have distinct states. All template constraints are
explicitly marked `pending`: the DMD triage stores constraints on
template wrappers, not necessarily function nodes. Receiver
qualifiers, default argument expressions, all attribute categories
and compiler overload resolution are likewise not established by
this tool.

## XPS validation

```sh
set -euo pipefail
git pull --ff-only
python3 -m unittest discover -s tools/research -p 'test_audit_paired_overloads.py'
python3 tools/research/audit_paired_overloads.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-paired-overload-contracts.csv
```

No XPS run has yet confirmed the new tool's result counts. Do not
mark this as a complete API-contract PASS before inspecting the
per-overload CSV. The 63 nonfunction declarations also await full
kind-specific verification. C1 feature/API freeze remains open.
