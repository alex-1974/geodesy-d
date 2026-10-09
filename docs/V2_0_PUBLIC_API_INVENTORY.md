# v2.0 public API inventory and reconciliation

Status: **C1 — inventory in progress; not a freeze**  
Tracking issue: [#113](https://github.com/alex-1974/geodesy-d/issues/113)  
Baseline: `develop` after merge of PR #114 (`d8b4303410ef7cc51657a031485afdf7dcd553a8`).

## Scope and evidence

The public entrypoint is `source/geodesy/package.d` (`module geodesy;`).
It explicitly re-exports 28 modules. These are the scope of the v2.0 API
review, including public declarations, templates, overloads and methods within
their public types. Internal modules are implementation details, not a new
public API commitment. The existing
[`docs/public-api-example-audit.md`](public-api-example-audit.md)
enumerates **463** public DDox symbol pages with rendered examples at this
baseline; this is an example-coverage inventory, **not** a complete signature,
overload, or semantic-contract inventory.

### Exported module families

| Family | Modules | Review emphasis |
| --- | --- | --- |
| Scalars / angles | `geodesy.scalar`, `geodesy.angle` | scalar eligibility, radians/degrees, normalization and bounds |
| Geodetic model and value types | `geodesy.ellipsoid`, `geodesy.epoch`, `geodesy.errors`, `geodesy.geographic`, `geodesy.geodetic`, `geodesy.geocentric`, `geodesy.topocentric`, `geodesy.projected` | factory pairs, invalid `.init`, units, finite input policy |
| Coordinate conversion | `geodesy.conversion` | operation direction, checked/throwing symmetry |
| Surface paths / geometry | `geodesy.geodesic`, `geodesy.geodesic_intersection`, `geodesy.geodesic_nearest`, `geodesy.geodesic_polygon`, `geodesy.rhumb` | prepared/one-shot, bounded geometry, results, convergence and domain |
| Projection factors and projections | `geodesy.projection.factors`, `geodesy.projection.lambert_azimuthal_equal_area`, `geodesy.projection.lambert_conformal_conic`, `geodesy.projection.polar_stereographic`, `geodesy.projection.pseudo_mercator`, `geodesy.projection.transverse_mercator`, `geodesy.projection.ups`, `geodesy.projection.utm` | preparation, accuracy domain, coordinate units, variants and factors |
| Datum/frame transformations | `geodesy.transform.geocentric_translation`, `geodesy.transform.helmert`, `geodesy.transform.dynamic_helmert`, `geodesy.transform.molodensky_badekas` | EPSG conventions, epoch, sign/order, checked failure |

**Count:** 2 + 8 + 1 + 5 + 8 + 4 = 28 public modules.

## Per-declaration inventory schema

Capture a record for **every public declaration and overload**, not just each
DDox page. A review record must identify:

| Field | Required assessment |
| --- | --- |
| `module / qualified symbol / overload` | exact public name and callable signature, template constraints, UFCS shape |
| `role / family` | type, enum, constructor, factory, checked/throwing function, prepared operation, property |
| `scalar / attributes` | float/double/real availability and `pure`, `nothrow`, `@safe`, `@nogc` contract |
| `units / angular conventions` | input/output linear units, degrees vs radians, azimuth wrapping and signs |
| `domain` | sphere, oblate, qualified prolate range, poles, antimeridian, degeneracy |
| `failure / validity` | `try*` false/out semantics; throwing exception; `.init` validity |
| `state / performance` | prepared vs one-shot, allocation, workspace ownership, repeatability |
| `oracle / testing` | analytical properties, EPSG, PROJ, GeographicLib, independent differential gates |
| `coverage / decision` | documentation example, consumer test, keep/rename/deprecate/correct, rationale |

A DDox symbol page may represent multiple D overloads. Consequently the
example audit cannot be used as a substitute for the signature-level census.
All decisions that change public behavior require explicit migration notes,
targeted negative/consumer tests and a separately reviewed change.

## First verified reconciliation candidates

### Bounded geodesic nearest point — former draft PR #101

The current `geodesy.geodesic_nearest` module already exports
`GeodesicSegmentNearestKind`, `GeodesicSegmentNearestResult!T`,
`tryNearestPointOnSegment` and `nearestPointOnSegment`.
The checked free function is solver-first, `pure nothrow @safe @nogc`,
returns `bool` and writes an `out` result. The throwing peer is `@safe`.
The result separates bounded nearest point/distance from supporting-line
intercept, signed along-track and signed cross-track quantities, and invalid
default state. PR #101 proposed the earlier
`GeodesicSegmentNearestLocation` naming; **do not merge or transplant that
stale public shape**. Check whether any independent regressions in the old PR
are missing before closing it as superseded.

### Internal geodesic lengths — former draft PR #57

Current `geodesy.internal.geodesic_lengths` already parameterizes
`geodesicLengths` with a compile-time `uint outputs` mask; distance and
reduced-length work are selectively instantiated. This satisfies the core
architectural intent of draft PR #57 without changing the public API. Any
remaining micro-optimization must be measured on current `develop`, not
integrated through the divergent prototype branch.

## Review sequence

1. Generate a reproducible declaration-and-overload census from precisely
   these exported modules, recording commit/compiler version. Review D
   overload resolution and public visibility manually; DDox page count alone
   is insufficient.
2. Record checked/throwing, prepared/one-shot and result-carrier symmetry;
   flag true omissions separately from intentionally asymmetric families.
3. Audit angular/linear units, ellipsoid domain boundaries, nonfinite inputs,
   `.init` and `out` failure states with negative/consumer tests.
4. Reconcile archived draft experiments and existing evidence without
   reintroducing stale implementations. Track decisions in issue #113.
5. Only after the C1 census and scope triage, proceed to the feature-freeze
   checkpoint described in `V2_0_CONSOLIDATION_PLAN.md`.

## Current status

- [x] Confirm canonical root export and enumerate 28 public modules.
- [x] Cross-reference 463-page DDox example-coverage audit.
- [x] Compare draft PRs #101 and #57 to the current implementation.
- [ ] Exact public symbol + overload signature census.
- [ ] Family-by-family semantic contract audit and decisions.
- [ ] Feature freeze and API freeze — **not yet authorized**.
