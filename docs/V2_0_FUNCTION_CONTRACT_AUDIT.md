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


## XPS CSV evaluation (2026-10-10)

The uploaded `v2-function-contract-audit.csv` includes 488 DDox
rows. The first selected-return/attribute checker reports:

| Status | Rows |
| --- | ---: |
| `return_and_selected_attributes_match` | 252 |
| `opaque_or_complex_type_review` | 138 |
| `nonfunction_separate_review` | 63 |
| `overload_pairing_pending` | 35 |
| `return_or_selected_attribute_difference` | 0 |

**Do not mistake 0 differences for full agreement.** The 252 matches
reflect the limited parsing implemented by this script, not complete
semantic signature equivalence. In the 138 unresolved function
records, **126** have no parsed DDox return token and **12**
have no readable DMD function type in the report. Examples of
DDox-return parser limitations include templated returns such as
`Angle!T`, `Ellipsoid!T`, `GeographicCoordinate!T` and
`GeodesicDirectResult!T`; zero DMD type tokens occur in some
`GeodesicIntersectionEnumeration` properties. The 35 overloaded
prototype records still need unambiguous parameter-key pairing.

Next: improve DDox return-type recognition for templated and
qualified types; explicitly pair overloaded function records using
the already validated parameter comparison; inspect unparseable DMD
type records; then test return/attribute/receiver qualifiers with
DMD and LDC. Retain a separate kind-aware gate for the 63
nonfunction rows. Rebuild all inputs on a single pinned commit
before sign-off.

## Return-token parser improvement

The parser was extended to recognize DDox return types whose template suffixes are separated by spaces, for example `Angle !T` and `GeodeticCoordinate !T`. A dedicated fixture verifies `Latitude.asAngle`. The initial 252-match/138-opaque results predate this change; **no new match count is claimed** until XPS reruns the regression tests and the full audit. The report remains partial: overload pairing, receiver qualifiers, default arguments and full template constraints require separate gates.


## Same-head XPS rerun and return-template parser (2026-10-10)

The newly supplied `v2-function-contract-audit(1).csv`, produced after
rebuilding DDox and DMD JSON in the same working tree, reports **488**
DDox rows:

| Status | Count |
| --- | ---: |
| `return_and_selected_attributes_match` | 364 |
| `opaque_or_complex_type_review` | 26 |
| `overload_pairing_pending` | 35 |
| `nonfunction_separate_review` | 63 |
| `return_or_selected_attribute_difference` | 0 |

The 26 unresolved function rows divide into **12 cases with an empty
DMD function type**, notably seven
`GeodesicIntersectionEnumeration` and five `UtmZone` members, and
**14 templated-return DDox parsing cases**, notably
`Helmert7`, `Helmert14`, `MolodenskyBadekas10` and their
conversion functions.

The parser was further amended to accept comma-separated template
return arguments (e.g. `Helmert7 !(T,convention)`), with a regression
fixture. **No new counts are asserted until an XPS rerun.**
The 35 overloaded function rows remain unpaired and the 63
nonfunction rows remain outside this report's scope.

The new CSV supplies improved same-working-tree input consistency,
but the resulting CSV alone does **not** prove that the manifest and
DDox inputs were tied to a pinned, clean Git commit. Record a commit
SHA, source cleanliness, capture manifests and hashes before release
qualification. Do not promote the 364 partial selected-attribute
matches to complete API contract certification.
