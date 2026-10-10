# v2.0 overloaded prototype parameter reconciliation

Status: **C1 parameter-list audit**, not final API sign-off.

Using the uploaded `v2-public-ddox-prototypes.csv` and
`v2-dmd-ddox-triage(3).csv`, all ten multi-prototype symbol families
were compared by the **unordered multiset of ordered parameter
lists**. Each parameter was compared by normalized storage qualifiers,
type spelling and name. DMD duplicate template-wrapper nodes were
excluded by selecting records of kind `function`.

**Result: 10/10 overloaded families pass parameter-list comparison;
35 DDox prototypes match 35 DMD function records.**

The comparison initially flagged `closestGeodesicIntersection`:
DDox presents `= cast(T) 0` defaults for reference-position arguments
in four overloads; the DMD JSON parameter objects do not include those
default expressions. Ignoring default *expressions* gives exact
parameter-list equivalence. **The defaults themselves remain subject
to a separate source-level check.**

This audit does NOT certify all attributes, `if` constraints, actual
template instantiations, return types, overload resolution, UFCS or
compiler accessibility. It also does not certify the remaining
453 one-prototype DDox pages. Before sign-off, repeat both captures
at a single pinned source commit.

The reproducible comparison tool is
`tools/research/compare_overload_signatures.py`.
