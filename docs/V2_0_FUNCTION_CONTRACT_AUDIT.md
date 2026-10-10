# v2.0 function return and attribute audit

Status: **Research tool implemented; execution and compiler qualification pending**.

The previous XPS reports classify **425** DDox rows as functions:
423 function parameter-list matches and two UTM cases with DMD
`deco` but no readable parameter `type`. A total of 63 DDox
rows are not functions.

New script `tools/research/audit_function_contracts.py` compares
readable DMD function-type return tokens with DDox return tokens and
the selected function attributes `pure`, `nothrow`, `@nogc`,
`@safe`, `@trusted`, `@system`, `@property`, `ref`,
`scope`, and `return`.

The audit explicitly separates:

- `return_and_selected_attributes_match`;
- `return_or_selected_attribute_difference`;
- `opaque_or_complex_type_review`;
- `overload_pairing_pending`: DMD/DDox overloads require **parameter-
  keyed pairing**, not array order;
- `nonfunction_separate_review`.

It **does not certify** `const`/other method receiver qualifiers,
return type aliases, aggregate member inherited visibility, all
storage classes, template constraints, default expressions, or actual
DMD/LDC overload resolution. Even a successful selected-attribute
match is therefore not a full API contract match.

Run on XPS:

```sh
git pull --ff-only
python3 -m py_compile tools/research/audit_function_contracts.py
python3 tools/research/audit_function_contracts.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-function-contract-audit.csv
```

After inspecting the result, complete overload parameter-key pairing,
explicitly evaluate `const`/method qualifiers and default
arguments, and classify the 63 nonfunction records including enum
members, exception class base/constructor, and
`isGeodesyScalar`. The two UTM cases with opaque `deco` must not
be silently marked verified.

**Reproducibility:** all DMD JSON and DDox snapshots must be
regenerated on the same pinned commit before sign-off. No feature-
or API-freeze tag is authorized at this stage.
