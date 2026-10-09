# v2.0 documentation: consumer reading audit (first pass)

Status: **C1 review findings — no API freeze and no claim of complete coverage**  
Tracking: #113. Read against `develop` after #114.

## Test: four questions on every public page

Read the generated Ddoc and the entry guides as a first-time library user,
without consulting implementation files.

1. **What is it?** Can I describe the module or function in one plain sentence?
2. **When would I use it?** Is there a concrete problem or example of its use?
3. **What does it do?** What do I give it, what does it return, in which units?
4. **How do I use it?** Can I follow a short real example, including a failure
   path or a choice of checked/throwing API where relevant?

**Passing a documentation build or providing an Example is necessary but not
sufficient.** The prose and example must help a consumer make a decision.

## First-pass observations

| Location | Consumer reading | Required correction | Priority |
| --- | --- | --- | --- |
| `README.md` | Lists many capabilities, but does not start with recognizable jobs (convert a GPS position, find distance/bearing, choose UTM). The first example combines four unrelated jobs. | Lead with three plain-language use cases; separate examples into one task each. Keep the feature list as reference. | High |
| `docs/getting-started.md` geodesics | Says geodesic lines and polygon accumulation are outside scope, despite the current modules `geodesic.d` and `geodesic_polygon.d`. It also describes only spheres/oblate support, while qualified prolate geodesics have been implemented. | Correct the status and link to specific public APIs; explicitly distinguish general ellipsoid construction from each operation's supported flattening range. | **Blocker** |
| `docs/README.md` Status | Calls M4 the next planned milestone, although M4/M5 are complete on `develop`. | Update the status with separate stable-release vs development descriptions. | High |
| `docs/API.md` | Strong as a detailed v1 reference contract; it starts with freeze history and names rather than consumer tasks. | Label it clearly as a *v1 contract reference*, not a v2 newcomer guide; provide links to task-oriented guides. | Medium |
| `source/geodesy/ellipsoid.d` | Explains constraints and validity thoroughly but leads with “stored canonically as equatorial semi-axis a and flattening f.” A newcomer first needs to know why a reference ellipsoid matters, why WGS 84 is the ordinary choice, and why units must match. | Begin module/type docs with its role as the Earth-shape model; then explain WGS 84, units, and construction options; preserve exact formula/domain afterward. | Medium |
| `source/geodesy/projection/utm.d` | Opens with “policy, tagging, and prepared projection”; without UTM background, the purpose of converting latitude/longitude into metre coordinates is unclear. | Lead with the job: put a geographic position on a standard local metre grid; explain automatic zone versus fixed-zone choice in everyday language, then give the limitations. | High |
| `source/geodesy/geodesic_nearest.d` | Meaning of bounded nearest point and supporting-line quantities is precise, but assumes the reader already understands “supporting geodesic” and “gnomonic”. | Start with a concrete use: find the closest point on a route segment to a GPS position; distinguish segment distance from distance to the *extended* route in a short illustration/example. Preserve sign/domain contracts. | High |
| `source/geodesy/geodesic_intersection.d` | Technical explanation begins with Karney’s method and “bounded shortest-segment slice”. The consumer needs the simple distinction between no crossing, a crossing point and shared stretch. | Put the geometric outcome and applicability first; move implementation method to a later paragraph. Explain rejection of ambiguous paths with a simple edge case. | High |
| `source/geodesy/transform/dynamic_helmert.d` | Explains fourteen parameters and EPSG methods but not the consumer's goal. | Lead with the reason: adjust coordinates between reference frames when their relationship changes over time. Explain that a reference year and observation year are required, then units/conventions. | High |
| `docs/ddoc-style.md` | Already mandates plain English, consumer purpose, contracts and examples. | Add an explicit review gate for the four consumer questions and distinguish *syntactic example presence* from *reader comprehension*. | High |

## Concrete writing pattern

**Weak entry (representative existing wording):**

> Universal Transverse Mercator policy, tagging, and prepared projection.

**Stronger consumer opening (proposed, not yet applied):**

> Convert latitude and longitude into UTM coordinates measured in metres. Use
> the automatic operation for a position's standard UTM zone. If you are
> converting many points in one known zone, create a `UtmProjection` once and
> reuse it.

Then explain the valid latitude range, north/south hemisphere, result fields,
and what happens when a position cannot be projected.

**Nearest-point opening (proposed):**

> Find the point on a route segment that is closest to a given position.
> Supply the route's two endpoints and the position. The result gives the
> closest point and its distance; if the nearest point would fall beyond the
> segment, the result uses the nearer endpoint.

Then explain supporting-line metrics separately and precisely.

## Documentation structure for each public module and operation

Do **not** impose identical section headings on tiny getters. Use this order
when a function is non-trivial:

1. One sentence: what it does.
2. One or two sentences: when to choose it instead of a neighboring operation.
3. Inputs and output, with units and result properties.
4. A focused compiled example that resembles an actual use.
5. Important limits, invalid states and what can go wrong.
6. Technical details, standards, performance and implementation notes only
   when they help a consumer choose or rely on the operation.

Avoid copy/pasting template prose. Prefer *convert*, *measure*, *find*,
*transform*, *return*, *reject* over *provide functionality*, *implement a
slice*, *parameterize a policy*.

## Acceptance checklist for the forthcoming v2 documentation pass

- [ ] New reader can explain each public module's purpose without reading code.
- [ ] Non-trivial public functions say *when to use them*, not just their name.
- [ ] Choices among related APIs are described (checked vs throwing, prepared
      vs one-shot, geodesic vs rhumb, automatic vs explicit UTM).
- [ ] Every example represents one recognizable task and compiles.
- [ ] Units, coordinate conventions and failure cases remain exact.
- [ ] Obsolete feature-status statements are removed from entry guides.
- [ ] Generated DDox pages and entry guides agree with the current release /
      `develop` status.
- [ ] A human review applies the four questions after automated gates.

## Scope note

This is a **sample-based first pass**, not a claim that all 463 public DDox
pages were individually read. Complete the review family by family and record
each checked page/overload in the v2 API inventory.


## Implementation progress (2026-10-09)

The consumer comprehension gate is now part of `docs/ddoc-style.md`.
The entry guides and the opening Ddoc for `Ellipsoid`, UTM,
bounded nearest-point geometry, bounded intersections, and dynamic Helmert
have received a first reader-oriented edit. The individual Ddoc entries
for `tryForwardUtm`, `tryNearestPointOnSegment`, and
`tryIntersectGeodesicSegments` now explain the consumer task and result
before detailing their mathematical mechanism.

**Review status is deliberately partial:** these edits have not reviewed
every public overload or each of the 463 DDox pages. Do not mark the
four-question acceptance gate complete until the remaining public families
and result carriers have been read on rendered pages.

### Prioritized next reading batches

| Batch | Reader tasks | Status |
| --- | --- | --- |
| Core values / coordinate conversion | Choose geographic vs geodetic, select height and unit, convert XYZ both ways | Pending per-symbol review |
| Geodesic, rhumb and polygon | Choose shortest path vs constant bearing, measure polygon, use prepared line | Pending per-symbol review |
| Bounded nearest point / intersection | Understand results, crossing vs failure, extended-line metrics | Opening Ddoc reviewed; overloads pending |
| UTM and other projections | Choose grid/zone, forward and reverse, understand valid area | Opening Ddoc and automatic forward checked form reviewed; remainder pending |
| Static and time-dependent frames | Select EPSG convention, units and epoch, forward/inverse | Opening Ddoc reviewed; overloads pending |

Each completed page must record the four answers, a realistic Example,
and the explicit failure/units/domain contract. A module introduction
does not substitute for reviewing the public operations it exports.


## Core-coordinate reading pass

The module introductions for `GeographicCoordinate`, `GeodeticCoordinate`,
`GeocentricCoordinate`, and `geodesy.conversion` now start with their
distinct consumer uses:

- **Geographic:** latitude and longitude without height, for surface routes
  and map projections.
- **Geodetic:** latitude, longitude and *ellipsoidal* height, for conversion
  to or from Earth-centred coordinates. Ellipsoidal height is not automatically
  height above sea level.
- **Geocentric:** X/Y/Z from the Earth's centre, suitable for ECEF work
  and reference-frame transformations.
- **Conversion:** forward geodetic-to-XYZ and reverse XYZ-to-geodetic,
  explicitly requiring a matching reference ellipsoid.

The conversion documentation also distinguishes the checked `try*` form
from the throwing form. Existing numerical-domain, unit and geocentre
restrictions remain part of the full function comments.

**Coverage:** This is a reviewed module-entry pass plus selected conversion
operations, not a completed sign-off for every public property and overload.
Remaining detailed work includes factories, constructors, all conversion
overloads, and the rendered DDox page-by-page audit.


## Coordinate construction review

Reviewed the public construction paths for the three core coordinate types:

| Type | Construction choice | Key consumer rule |
| --- | --- | --- |
| `GeographicCoordinate` | `fromComponents(latitude, longitude)` | Use strong angles when no height is present; no ellipsoid/datum is stored. |
| `GeodeticCoordinate` | `tryFromComponents` / `fromComponents` | A height of zero is a measured/assumed ellipsoidal zero, **not** an unknown height; checked form rejects non-finite heights without throwing. |
| `GeocentricCoordinate` | `tryFromComponents` / `fromComponents` | XYZ components share one unit; choose checked or throwing handling for non-finite input. |

The public factory comments now explain **when to choose each form** before
their parameter and exception contracts. The three types intentionally differ
in their `.init` semantics: geographic (0°, 0°), geodetic (0°, 0°, height 0),
and geocentric (0, 0, 0). A valid value does not imply every operation is
defined at that value (notably, geocentric-to-geodetic conversion at the exact
geocentre fails).

This records a focused construction pass only; the remaining public getters,
overloads, and DDox pages still require individual consumer sign-off.
