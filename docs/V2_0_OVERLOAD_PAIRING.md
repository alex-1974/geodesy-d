# v2.0 overload pairing — C1 qualification

The prior DDox/DMD inventory contains 35 documented prototypes across
ten overloaded symbol families. `tools/research/overload_pairing.py`
matches DDox declarations to compiler `function` records using
their **complete ordered parameter tuples**, including type,
storage class and parameter name. It does not trust input ordering
and does not mistake DMD template-wrapper records for functions.

An offline run against the previously uploaded DDox and DMD triage
CSVs returned:

```text
Overload pairing: unique_parameter_match=35
PASS: all 35 DDox overloads uniquely paired by ordered parameter list
```

Two local Python fixture tests passed: reversed DMD overload order
and detection of ambiguous duplicate compiler declarations. The
matching test was performed locally on the CSV snapshots; XPS
confirmation on the branch is still required.

## XPS reproduction

```sh
python3 -m unittest discover -s tools/research -p 'test_overload_pairing.py'
python3 tools/research/overload_pairing.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-overload-pairing.csv
```

The result contains each DDox overload's DMD source-line candidate
and normalized parameter key, making it possible to pair return type
and attributes **without relying on declaration ordering**.

This is **not** a final function contract, compiler overload-resolution
or visibility proof. Full return type/attribute comparisons for all
35 paired overloads, consumer compilations of the twelve opaque DMD
functions, remaining nonfunction checks and same-head clean snapshot
manifest verification are pending. Do not set freeze tags.

## XPS CSV verification (2026-10-10)

The uploaded `v2-overload-pairing.csv` was independently inspected: **35 rows** across **ten** documented overload families; all 35 statuses are `unique_parameter_match`. There are zero ambiguous or missing parameter matches, zero duplicate `(module, symbol, overload)` rows, and every row supplies a DMD source line. This confirms the **parameter-based pairing gate** on XPS evidence. The CSV does not report execution of the external DMD/LDC consumer fixture and does not validate return types, attributes, template constraints or runtime overload resolution. No freeze is authorized.
