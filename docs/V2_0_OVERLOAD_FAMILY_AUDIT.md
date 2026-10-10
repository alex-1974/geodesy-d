# v2.0 overloaded API families: DMD/DDox inventory cross-check

Status: **C1 count-level reconciliation only — exact signature audit remains open**.

The supplied DDox CSV and XPS DMD triage CSV were compared by
`(module, symbol, declaration kind)`, preserving separate overloads.
The ten multiply documented DDox symbol pages contain **35 rendered
prototypes** and corresponding **35 DMD function records**:

| Family | DDox prototypes | DMD function records | DMD template wrappers |
| --- | ---: | ---: | ---: |
| `Geodesic.tryDirect` | 2 | 2 | 0 |
| `Geodesic.tryInverse` | 2 | 2 | 0 |
| `GeodesicLine.tryArcPosition` | 2 | 2 | 0 |
| `GeodesicLine.tryPosition` | 2 | 2 | 0 |
| `allGeodesicIntersections` | 3 | 3 | 3 |
| `closestGeodesicIntersection` | 4 | 4 | 4 |
| `nextGeodesicIntersection` | 4 | 4 | 4 |
| `tryAllGeodesicIntersections` | 4 | 4 | 4 |
| `tryClosestGeodesicIntersection` | 8 | 8 | 8 |
| `tryNextGeodesicIntersection` | 4 | 4 | 4 |
| **Total** | **35** | **35** | **27** |

**Interpretation:** The 27 additional DMD template records are
wrappers for function templates. They must not be counted as callable
overloads, and raw DMD node totals cannot be compared directly with
DDox prototype totals.

**What this confirms:** No overload-*count* discrepancy within these
ten families in the provided snapshots.

**What it does not confirm:** Exact parameter order/mode/type,
template constraints, scalar instantiations, qualifiers, `pure`,
`nothrow`, `@safe`, `@nogc`, UFCS lookup or actual consumer
accessibility. These require a parameter-by-parameter comparison,
compiler signatures, and positive/negative consumer tests.
The other 453 single-prototype pages also await such checks.

The XPS DMD manifest predates later documentation-only commits.
Before certifying a fixed API baseline, regenerate DMD JSON and
DDox CSV against the **same pinned commit** and rerun the comparison.
This report does **not** authorize feature freeze or API freeze.
