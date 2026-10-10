# C1 overload template constraint ownership audit

**Status: tooling ready; XPS run pending. No new constraint PASS claimed.**

The previous XPS evidence confirms all **35** DDox overloads in ten
families match DMD function nodes by exact ordered parameters and their
selected return types and attributes. However, the source DMD -X JSON
represents function templates with additional `template` wrappers,
which do not necessarily share an unambiguous relation with their
inner `function` nodes in the flattened CSV.

`tools/research/audit_overload_constraints.py` now classifies the
candidate relationship for each uniquely paired function. A
same-name template wrapper **alone** is insufficient evidence of
ownership. The script looks for a unique wrapper at the same DMD
source line as the function and preserves constraint text where
available. If no wrapper exists, or ownership cannot be established,
it emits a distinct status; it never automatically claims constraints
to be equivalent with the DDox declaration.

The resulting states are:

- `wrapper_line_pair_constraint_available`: exactly one same-line
  wrapper and nonempty DMD constraint text (candidate evidence only).
- `wrapper_line_pair_no_constraint_text`: same-line wrapper but
  absent constraint text; does not mean an unconstrained public API.
- `template_wrapper_ownership_unresolved`: function-to-wrapper
  linkage not established by source-position equality.
- `no_template_wrapper`: compiler records have no same-name
  template wrapper; review whether genuinely nontemplated.
- `function_pair_missing_or_ambiguous`: regression of the
  previously qualified parameter-based matching.

Run from the XPS repository root:

```sh
set -euo pipefail
git pull --ff-only
python3 -m unittest discover -s tools/research -p 'test_audit_overload_constraints.py'
python3 tools/research/audit_overload_constraints.py \
  build/v2-public-ddox-prototypes.csv \
  build/v2-dmd-ddox-triage.csv \
  build/v2-overload-constraint-candidates.csv
```

Follow-up: inspect each unresolved ownership case in the raw
`build/api-json-dmd` module files; compare exact normalized
constraint expressions to D source and DDox; compile positive and
negative template-instantiation consumers with both DMD and LDC.
DMD JSON may not provide sufficient metadata for every case.
**This gate deliberately does not certify the 35 constraints.**

Also outstanding for full C1: defaults, method qualifiers, all
compiler attributes, kind-aware verification of 63 nonfunction
declarations, reproducible same-clean-commit capture, consumer
overload resolution, and final freeze policy.

## XPS CSV classification — 2026-10-10

The supplied `v2-overload-constraint-candidates.csv` contains **35**
records. The exact status distribution is:

| Classification | Count |
| --- | ---: |
| `wrapper_line_pair_constraint_available` | **27** |
| `no_template_wrapper` | **8** |
| unresolved or ambiguous pairing | **0** |

Every one of the **27** same-source-line template wrapper records
reports the exact DMD constraint text `isGeodesyScalar!T`. They cover
`allGeodesicIntersections` (3), `closestGeodesicIntersection` (4),
`nextGeodesicIntersection` (4), `tryAllGeodesicIntersections` (4),
`tryClosestGeodesicIntersection` (8) and
`tryNextGeodesicIntersection` (4).

The other **8** records are two each of
`Geodesic.tryDirect`, `Geodesic.tryInverse`,
`GeodesicLine.tryArcPosition`, and
`GeodesicLine.tryPosition`. They have no separate same-name DMD
template wrapper in this flattened triage. Their enclosing aggregate
template constraints remain a separate review dimension.

**Interpretation:** This confirms traceable DMD wrapper candidates
and consistent extracted constraint strings, **not** compilation
acceptance/rejection, DDox/source constraint equivalence, or actual
template-instantiation behavior. Next verify the six declarations
against source and compile both accepted and deliberately invalid
`T` examples under DMD and LDC. In particular, a negative
`__traits(compiles, uninstantiatedTemplateName)` is not sufficient:
test concrete instantiations. Freeze remains open.
