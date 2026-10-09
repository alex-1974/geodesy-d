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
