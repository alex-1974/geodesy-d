# v2.0 full DDox prototype triage

Status: **Implemented, pending XPS execution and manual sign-off**.

`tools/research/compare_all_api_signatures.py` processes **all**
DDox prototype rows, groups by `(module, symbol)`, and finds the
matching compiler JSON declarations from the existing DMD triage CSV.

It distinguishes:
- `parameter_multiset_match`: DMD and DDox **function parameter
  multisets only** match (also for overload groups).
- `parameter_multiset_mismatch`: function parameter mismatch.
- `unparsed_function_signature`: DDox declaration could not
  be parsed with the current intentionally limited parser.
- `nonfunction_requires_kind_specific_review`: DDox type, alias,
  enum, etc. must not be compared as a function.
- `no_dmd_name_candidate`: no matching DMD declaration by name.

Run on the XPS:

```sh
python3 -m py_compile tools/research/compare_all_api_signatures.py
python3 tools/research/compare_all_api_signatures.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-full-api-signature-triage.csv
```

The classifier reuses `compare_overload_signatures.py`; it does not
assert that all 488 DDox rows are callable functions. **Do not
interpret a parameter match as a complete API signature match.**
Return types, qualifiers, `pure`, `nothrow`, `@safe`, `@nogc`,
template constraints, default expressions, visibility and actual
overload resolution are *not covered*.

The DMD snapshot and DDox archive were originally created at
different commits. Regenerate both on the same pinned source commit
before accepting this evidence for the feature/API freeze gate.
