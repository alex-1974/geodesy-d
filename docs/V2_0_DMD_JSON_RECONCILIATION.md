# v2.0 DMD JSON vs DDox: first candidate-level reconciliation

## Evidence

User-provided `geodesy-v2-api-json.tar.gz` includes a manifest and **28**
DMD JSON module records. All recorded SHA-256 digests match the extracted
bytes. Compiler: **DMD 2.111.0**. Source commit:
`9aaeee64bdf9fb82f57b398a45d6e35d8a2447a3`.
The previously provided public DDox CSV contains **488 rendered prototypes**
on **463 symbol pages**.

A first recursive DMD JSON traversal propagating scope visibility yields
**1,011 candidate records**: 497 function, 289 variable, 114 template, 56
struct, 27 enum-member, 19 alias, 7 enum, 1 class and 1 constructor records.

**These are candidate source declarations, not 1,011 independently
callable public API functions.** The DMD tree includes template wrapper
and enclosed struct records, nested variables, properties, and records
which require visibility verification. The 497 function records must
not be compared directly with 488 DDox prototypes: the latter includes
types, aliases and overloaded presentations, and a single public
template may generate more than one form.

### First name-level check

Normalizing duplicated DMD template-wrapper scopes such as
`Helmert7.Helmert7.fromCanonical` to
`Helmert7.fromCanonical`, the comparison found **no DDox page names
missing from the DMD JSON candidate set** (463/463 page identifiers
resolve at this coarse level). This is an encouraging consistency check,
**not** proof of exact overload or declaration identity.

### Outstanding checks

1. Derive correct effective visibility across nested D scopes, including
   default protection and template/aggregate wrappers.
2. Distinguish compiler-synthesized, internal, alias and nested data
   declarations from independently consumer-addressable API symbols.
3. Reconcile each of the **488 DDox signatures** against exact compiler
   function types, template parameters, constraints, attributes and
   overload/UFCS behavior; investigate discrepancies rather than infer
   equivalence from a matching name.
4. Perform fresh DMD/LDC package consumer tests, including the standalone
   Helmert Getting Started example.
5. Re-run the snapshot on the current PR head and confirm pinned source
   state before C1 sign-off or any freeze tag.

No production API or numerical behavior was changed. This is a partial
C1 research finding; **feature freeze and API freeze remain unapproved**.


## Conservative triage utility

`tools/research/reconcile_api_json.py` now writes a per-declaration CSV
with raw DMD kind, type, constraint, template parameters, effective/inherited
protection **estimate**, and a same-name DDox page flag:

```sh
python3 tools/research/reconcile_api_json.py \
    build/api-json-dmd \
    build/v2-public-ddox-prototypes.csv \
    build/v2-dmd-ddox-triage.csv
```

Important limitations: DMD JSON may omit `protection` on declarations
inside a D `private:` block. Inheriting the JSON parent protection is
therefore **not reliable proof of public accessibility**. All such records
are flagged `inherited_visibility_review`. `_name` is a coding
convention, **not** a D visibility modifier. The script flags underscore
symbols for review instead of silently excluding them. DMD also emits
generated `__unittest` declarations, template/aggregate wrappers and
variables that must not be naively counted as published APIs.

The generated CSV is a triage aid; a reviewer must inspect the original
protection regions and compile negative/positive external consumer probes
for doubtful names. Name matching does not establish signature, overload,
template-constraint, attribute or UFCS compatibility. Do not declare C1
complete from CSV totals.


## XPS triage CSV evaluation (2026-10-09)

The user-provided `v2-dmd-ddox-triage.csv` and
`v2-public-ddox-prototypes.csv` were read as generated data.

- **1,914 DMD triage rows**: 1,183 functions, 309 templates, 297
  variables, 57 structs, 30 aliases, 27 enum values, nine enums,
  one class and one constructor.
- Protection *estimate*: 1,519 public, 385 private, ten package.
  This estimate is not source-verified (see the `private:` limitation).
- **598 triage rows** match a DDox page identifier; **1,316** do not.
  These are per-DMD-node counts, not 598 distinct documented APIs
  or 1,316 documentation defects.
- The 488 rendered DDox prototypes remain distributed over 463 pages.
- Of 214 unflagged `public_candidate` rows, **36** have no matching
  DDox *page identifier*. They consist of **27 enum values** and
  **nine structures**. Enum values can belong to a documented enum
  page rather than owning their own pages.

Nine structs to review against source protection and package exposure:
`GeodesicLineRawPosition`, `IntersectionDisplacement`,
`PreparedSegment`, `GnomonicXY`, `CompensatedSum`,
`ReverseSolution`, `HalleyState`, `ComplexPair`,
`TransverseMercator.TmForwardWorkingResult`.

**Critical correction to the previous first-pass count:**
The new triage CSV contains 1,914 rows, versus the earlier reported
1,011 raw candidate records. These different traversals/counting
policies must be reconciled before any exact compiler declaration census
claim. No public API growth is inferred from the difference.

### Next objective

Check the nine structs' lexical protection in source code (including
`private:` and `package:` sections), and perform external import
positive/negative probes for any ambiguous struct. Resolve enum-value
page ownership separately. Then compare actual overload signatures
rather than name-match flags. The feature freeze remains **not approved**.


### Source verification of the nine suspect structs

Checked all nine declarations against the corresponding source on
`audit/v2.0-signature-census`. **All nine are explicitly declared
`private struct`**, including the nested
`TransverseMercator.TmForwardWorkingResult`. None is therefore a
missing public DDox page.

This confirms a concrete false-positive class in the triage script:
DMD JSON `protection` inheritance from the surrounding scope is not a
substitute for reading lexical `private` modifiers. The 27 enum values
are separate from their documented parent-enum pages and are not
independently missing type pages.

The remaining work is a source-aware privacy classifier and exact
prototype/overload reconciliation; do not count the nine private types
as public API.


## Source-visibility and overload triage — next iteration

The triage script now adds `source_visibility_hint` and
`source_visibility_evidence` by consulting source lines at the DMD
reported declaration location. An explicit `private struct` or
`package(...) struct` modifier is preserved as evidence. Colon access
regions, braces, mixins and conditional compilation are **not**
resolved by this lexical check and intentionally remain `unknown`.

The report separately labels generated/test records and template
wrappers and attaches `ddox_prototype_count` to matched symbol names.
Multiple DDox prototypes can now be prioritized for exact source-level
signature audit. **Do not interpret matched counts as signature
equivalence**: type spelling, parameters, constraints, attributes,
overload sets and UFCS availability still require a compiler-backed
comparison. A D lexer/parser and external positive/negative compile
probes remain necessary for authoritative accessibility.

To rerun after fetching this PR branch:

```sh
python3 tools/research/reconcile_api_json.py \
  build/api-json-dmd \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv
```

The expected initial 1,914 DMD candidate records are evidence from
the previously supplied CSV, **not** a claim that this updated script
has executed successfully on the XPS yet. Feature/API freeze remains
open pending review.


## XPS run: string-valued source-line regression (2026-10-09)

The XPS successfully generated 1,914 DMD triage rows, matched 463 DDox
page names and counted 488 DDox prototypes (10 pages with multiple
prototypes). Yet `Explicit source visibility evidence: 0` was a
**tool defect**, not evidence of absent public declarations.

Inspection of the uploaded CSV confirmed that `line` is read back as
a string (for example `"82"`), while the lexical source checker only
accepted Python integers. All 1,914 rows therefore fell through to
`lexical_scope_unverified`; no source-based protection evaluation was
actually performed in that run.

Fixed the checker to convert source-line strings to integers, with
explicit handling for malformed and out-of-range positions. The
previous `source_visibility_hint`/`source_visibility_evidence`
columns must be discarded and regenerated before they are used for
API decisions. This does not change the 488-prototype DDox census.
