# v2.0 full public prototype triage — XPS report

The user-provided `v2-full-api-signature-triage.csv` has **488**
DDox prototype rows. Results from the current parameter-only
classifier:

| Classification | Rows |
| --- | ---: |
| `parameter_multiset_match` | 423 |
| `parameter_multiset_mismatch` | 2 |
| `nonfunction_requires_kind_specific_review` | 63 |
| Missing name candidate or unparsed function | 0 |

The two mismatches both belong to `geodesy.projection.utm`:
`UtmZone.fromNumber` and `UtmZone.tryFromNumber`.
Their DDox signatures render `const(uint) number`; source inspection
confirms the corresponding parameter declaration is written
`const uint number`. This is a **representation-normalization
candidate**, not yet a proven semantic API disagreement. Test
the DMD JSON parameter encoding and adjust the normalization only
with equivalence evidence.

The 63 nonfunction rows include 45 `struct,template`, six
`alias,template`, seven `enum`, two `struct`, one
`class`, one `constructor`, and one `template,variable`
(`isGeodesyScalar`). These require type, constraint, alias target,
enum member and constructor-specific checks.

Parameter-only comparison cannot certify return types, method
qualifiers, attributes, default argument expressions, constraints,
actual overload resolution or accessibility. The input DMD JSON
and DDox were not regenerated on an identical commit; final
qualification requires a same-head rerun.

Next action: verify normalization for `const uint` versus
`const(uint)`, perform nonfunction declaration comparison, then
check all 425 function signatures for return/attribute/constraint
fidelity and consumer compileability. Feature/API freeze remains open.
