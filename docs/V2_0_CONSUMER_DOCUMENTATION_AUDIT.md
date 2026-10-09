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


## Angle and route-choice reading pass

The opening Ddoc for `geodesy.angle`, `geodesy.geodesic`, and
`geodesy.rhumb` now begins with the caller's task rather than numerical
implementation details.

| Consumer choice | Answer conveyed by the documentation |
| --- | --- |
| `Angle` vs `Latitude` vs `Longitude` | General angles/bearings are distinct from north/south and east/west positions; construct explicitly from degrees or radians. |
| Geodesic inverse vs direct | With two positions, calculate shortest surface distance and azimuths; with a start position, azimuth and distance, find the destination. |
| Rhumb vs geodesic | Use rhumb for a constant compass bearing; use geodesic for a shortest surface route. |
| Repeated calculations | Reuse a prepared solver/line where supported rather than rebuilding state on each call. |

**Scope:** module-entry review completed for these three modules. Their public
factory methods, direct/inverse overloads, result carriers and associated
DDox pages still require page-level, four-question review. The existing
geodesic and rhumb domain limits and pole policies remain intact.


## Angle factories and route operations — function-level pass

Reviewed and revised the public `Angle.fromDegrees`,
`Angle.tryFromDegrees`, `Latitude.fromDegrees`, and
`Longitude.fromDegrees` documentation. Consumers now see why they
would choose a general angle, latitude or longitude and how the input
bounds differ. Existing exception and domain contracts remain.

Reviewed and revised the checked geodesic and rhumb direct/inverse
operation summaries. The consumer-facing descriptions now start with
their tasks: two positions to distance/bearings, or start/bearing/distance
to destination. The checked operations retain their domain and
non-throwing failure semantics; the geodesic result's final azimuth
remains a **forward** bearing, not a back bearing.

This is a focused function-level pass, not certification of all
overloads, angle factories or result carriers. Each remaining DDox
symbol page still needs a four-question reader review.


## Geodesic and rhumb result reading pass

Reviewed the public result types `GeodesicDirectResult`,
`GeodesicInverseResult`, `RhumbDirectResult` and `RhumbInverseResult`,
including the principal exposed properties.

| Result | Practical reader answer |
| --- | --- |
| Geodesic direct | `position` is the destination; `finalAzimuth` is the forward travel direction *at* the destination, not a return bearing. |
| Geodesic inverse | `distance` is shortest ellipsoidal surface distance; `initialAzimuth` leaves the start; `finalAzimuth` is forward direction at arrival. |
| Rhumb direct | `position` is the destination after travelling on a constant-bearing route. |
| Rhumb inverse | `distance` is the length of that constant-bearing route; `bearing` is the heading maintained along it. |

The Ddoc now foregrounds these meanings, the unit relationship to the
ellipsoid (metres with WGS 84) and the `Angle.degrees` accessor where
relevant. Existing angular canonicalization and coincident-point behavior
remain documented.

**Review boundary:** explanatory Ddoc was revised; this does not yet
certify all overloads or generated DDox pages against the four consumer
questions. Those remain in the full public API review queue.


## Prepared lines and polygon measurement — consumer pass

Reviewed and updated the public introductions for `GeodesicLine`,
`GeodesicLineUnrolledResult`, `RhumbLine`,
`GeodesicPolygonAccumulator`, `GeodesicPolygonResult` and the
`geodesic_polygon` module.

- A prepared line makes sense when the start, direction and ellipsoid stay
  fixed while the consumer requests multiple positions.
- `GeodesicLine` can evaluate distance- or arc-based positions;
  `RhumbLine` follows a constant bearing.
- An unrolled geodesic longitude keeps complete turns, which is useful for
  antimeridian crossing or paths around the Earth.
- A polygon accumulator accepts ordered vertices and adds the closing edge
  when computing perimeter and signed area; it is not a geometry-topology
  validator.
- Perimeter uses the ellipsoid's length unit; area uses its square.
  The polygon's traversal direction determines its signed area.

**Not complete:** method-by-method review of all line evaluation overloads,
polygon edge/point methods, exception contracts and compiled DDox examples
remains open. Avoid claiming that these modules have passed their full
four-question consumer gate until those checks are recorded.


## Prepared operations — method-level reading pass

Reviewed and improved the checked method descriptions for
`GeodesicLine.tryPosition`, `tryArcPosition`,
`tryPositionUnrolled`, `tryArcPositionUnrolled`,
`RhumbLine.tryPosition` and the polygon operations
`tryAddPoint`, `addPoint`, `tryCompute`, `compute`.
The `RhumbLine.position` throwing convenience method was also revised.

Consumer decisions highlighted:

- Use **distance-based line positions** for offsets in metres when using
  WGS 84; arc positions instead take an auxiliary-sphere `Angle`.
- Use **unrolled longitude** only when crossing the antimeridian or preserving
  complete turns matters.
- Negative distances move backward along the selected oriented line.
- Polygon vertices are added in boundary order. Failed checked addition
  does not change the accumulator.
- Polygon `compute` closes the polygon automatically without changing its
  stored state. Checked and throwing methods offer distinct failure handling.

This records a focused method-reading pass, **not** a full DDox-page
certification. Overloads, examples, and remaining prepared methods need
further review.


## Projection-family introductions — consumer reading pass

Revised opening Ddoc for six public projection modules:
`transverse_mercator`, `polar_stereographic`, `ups`,
`lambert_conformal_conic`, `lambert_azimuthal_equal_area`, and
`pseudo_mercator`.

| Consumer task | Projection choice |
| --- | --- |
| Standard UTM zone and local metre grid | Automatic `forwardUtm` or prepared `UtmProjection`. |
| Custom transverse grid with specified central meridian | `TransverseMercator`. |
| Standard WGS 84 polar grid | UPS, with its fixed metre-valued parameters. |
| Custom polar map grid | `PolarStereographic`. |
| Conic grid that preserves local angles | Two-standard-parallel `LambertConformalConic`. |
| Flat grid that preserves area | `LambertAzimuthalEqualArea`, not a conformal projection. |
| Coordinates for a standard web map | `PseudoMercator`, not a distance/area measurement substitute. |

The opening comments now lead with the mapping problem and alternative
choice. Existing EPSG methods, domains, parameters, units, and numerical
constraints remain in the technical sections.

**Coverage is partial:** public constructors, factors, forward/reverse
overloads, and rendered DDox pages need individual consumer checks before
these modules can be marked complete.


## Projection forward/reverse method reading pass

The descriptions for projected-coordinate conversion have received a
function-level Consumer review in `TransverseMercator`,
`PolarStereographic`, `UpsProjection`,
`LambertConformalConic`, `LambertAzimuthalEqualArea` and
`PseudoMercator`.

Each description now begins with the caller's question: converting a
geographic position into the selected grid, or recovering latitude and
longitude from grid coordinates. It distinguishes ordinary throwing
convenience calls from checked `try*` methods where those methods exist.

The existing domain notes remain decisive: Transverse Mercator has a
bounded central-meridian range; UPS uses polar latitude/representation
rules; LAEA's inverse requires a position inside its supported disk; and
Pseudo-Mercator is not a distance or area measurement substitute.

**Next:** Review each projection's parameters and factory contracts,
factor outputs and individual DDox examples. This pass does not certify
every overload or public symbol page.


## Projection configuration and factors — selected method pass

Reviewed and revised the consumer introductions to
`ConformalProjectionFactors`, the checked Transverse Mercator
parameter factory, the checked/throwing Lambert Conformal Conic
two-standard-parallel factories, and checked/throwing `UtmZone`
number factories.

- **Configure from an existing coordinate-system definition:** the natural
  or false origin, scale, parallels and offsets are prescribed parameters,
  not arbitrary numbers to tune by eye.
- **Keep units consistent:** false eastings/northings use the same linear
  unit as the ellipsoid, while scale is dimensionless.
- **Understand local factors:** `pointScale` is the local scale relative to
  the ground; `meridianConvergence` is the clockwise angular difference
  from true north to grid north under this library's convention.
- **Choose failure handling:** checked factories report invalid inputs
  without exceptions; throwing factories provide convenient setup for
  known-good definitions.

The reviewed comments keep the existing domain constraints, including
distinct non-polar Lambert standard parallels and valid UTM zone numbers.

**Partial coverage only.** Remaining projection factories, every factor
overload, and rendered examples require their own four-question review.


## Remaining projection factories and reference-frame entrypoint

The consumer-focused introductions were revised for the
`PolarStereographic` scale-at-pole and standard-parallel factories,
`LambertAzimuthalEqualArea` parameter factories, and
`UpsProjection` hemisphere factories.

The reader can now distinguish:

- a **custom polar grid** with supplied ellipsoid, scale and false offsets;
- polar stereographic **variant B**, configured from a standard parallel;
- an **equal-area map** centred on supplied geographic coordinates;
- **UPS**, whose WGS 84 parameters are fixed and only the hemisphere
  is selected by the consumer.

Also revised the `helmert` module entrypoint: a static `Helmert7`
converts Earth-centred XYZ coordinates using published translations,
rotations and scale; Position Vector and Coordinate Frame conventions
must not be mixed.

**Remaining:** full factory overload and failure-condition review,
individual factor APIs, Helmert7/14 constructors and operation results,
and generated DDox consumer checks. No numerical or API behavior changed.


## Helmert14 epoch and rate method reading pass

Revised the consumer introductions to the checked `Helmert14`
canonical and EPSG-style factories, evaluation at an observation epoch
and checked dynamic application. The docs now introduce the practical
question before mathematical details: which reference epoch the published
parameters belong to, which observation epoch to transform at, and what
units each rate uses.

The distinction between static `Helmert7` parameters and dynamic
`Helmert14` parameters remains explicit. Canonical rotations/rates use
radians and radians/year, while the interchange factory accepts arc-seconds
and arc-seconds/year; scale is dimensionless canonically and ppm in the
interchange form. Input geocentric XYZ coordinates and translation values
must share a linear unit.

**Open:** line-by-line review of static Helmert operation overloads,
throwing convenience methods, coordinate-frame-specific examples, and
generated DDox pages. The changes are documentation-only.


## Helmert7 static factory and application reading pass

Reviewed and revised the Ddoc introductions for static Helmert
`tryFromCanonical` / `fromCanonical`, plus
`tryApplyPositionVectorHelmert` and
`tryApplyCoordinateFrameHelmert`.

The consumer-facing explanation now emphasizes: published source-to-target
transformation direction, the difference between Position Vector and
Coordinate Frame rotation conventions, checked versus throwing factory
behavior, and canonical angle/scale units. Existing parameter lists and
failure contracts were retained.

The checked application functions accept geocentric XYZ and a
convention-specific `Helmert7`; they do not silently reverse the
transformation or convert convention-specific rotation signs.

**Still open:** review of EPSG interchange constructors,
`applyPositionVectorHelmert`/`applyCoordinateFrameHelmert`
throwing forms, inverse direction decisions and DDox examples.


## Helmert interchange and throwing operations — consumer pass

Reviewed and revised the Helmert7 EPSG interchange factories
(`tryFromArcSecondsAndPpm` / `fromArcSecondsAndPpm`)
and both throwing source-to-target operations
(`applyPositionVectorHelmert` / `applyCoordinateFrameHelmert`).
The public descriptions distinguish the rotation convention, transformation
direction and units used by published parameters.

For dynamic Helmert14, revised the throwing construction factories
(`fromCanonical` and `fromArcSecondsAndPpm`), epoch evaluation
(`evaluate`), and transformation (`apply`). The reference epoch fixes the
published parameter values; the observation epoch determines how the yearly
rates are propagated. The checked alternatives remain named alongside
throwing convenience methods.

**Scope:** Ddoc wording only. Exact exception, numeric and type contracts
remain authoritative. Generated DDox review, fully compilable new consumer
examples and complete public-method coverage are still pending.


## Local-pivot transformation and coordinate conversion reading pass

Revised the `molodensky_badekas` module introduction and its checked
EPSG interchange constructor, `tryApply` and throwing `apply` comments.
The consumer now sees that published Molodensky-Badekas parameters include
a three-dimensional evaluation point, unlike an ordinary seven-parameter
Helmert transform. Translation/evaluation-point coordinates must use the
same linear unit as source XYZ; published rotation and scale inputs use
arc-seconds and ppm.

Clarified the `conversion` module introduction: geodetic ↔ geocentric
conversions change the **representation** of coordinates on the supplied
ellipsoid; they do **not** change reference frames or datums. Heights are
ellipsoidal, not heights above mean sea level. Existing checked/throwing
conversions and special handling of the exact geocentre were retained.

**Remaining:** individual Molodensky-Badekas canonical constructors,
properties and throwing factory; transformation-chain consumer examples;
all remaining symbol pages and generated DDox checks. This review
changed documentation only.


## Molodensky-Badekas constructors and complete frame-workflow example

Revised the public constructor descriptions for
`MolodenskyBadekas10.tryFromCanonical`, `fromCanonical`, and
`fromArcSecondsAndPpm`. The reader now sees when a source-frame XYZ
evaluation point is needed, how the published rotation convention is
selected, and how checked construction differs from throwing construction.

Expanded `docs/getting-started.md` with a full task-oriented sequence:
geodetic coordinate -> Earth-centred XYZ -> convention-specific Helmert7
source-to-target transformation -> geodetic coordinate in the target frame.
All sample transformation parameters are explicitly identified as
illustrative **not real datum-transformation parameters**. The sample also
makes the source/target ellipsoid distinction explicit.

**Validation status:** the example was built from existing public API
signatures but has not yet been independently compiled in this pass.
Full rendered DDox and CI checks remain required.


## DDox evidence and documentation gate: first verification pass

A source-level Ddoc formatting defect was found and corrected in
`source/geodesy/transform/molodensky_badekas.d`: six unnecessary
backslash-escapes around inline-code backticks in three comment lines.
This is a rendering-quality correction, not a contract change.

The new end-to-end Helmert example in `docs/getting-started.md` has
been checked against its public entrypoint signatures
(`GeodeticCoordinate.fromComponents`,
`geodeticToGeocentric`,
`PositionVectorHelmert.fromArcSecondsAndPpm`,
`applyPositionVectorHelmert`,
`geocentricToGeodetic`). **Signature review is not a compiler run.**

### Evidence required before marking the documentation complete

1. Compile and execute the getting-started example with both baseline
   DMD and LDC as a real consumer of `import geodesy;`.
2. Execute the repository's public-symbol Example coverage and
   Ddoc/DDox build gates on the **exact review commit**.
3. Open the generated pages for the modified symbols, verifying
   correct Example ownership, visible inline code and paragraph layout.
4. Read the generated pages without source access and record explicit
   pass/fail for the four consumer questions per public symbol.
5. Check the exact-head CI status; queued checks do **not** count as
   successful checks.

**Current qualification:** the source-level correction is committed,
but the compiled example, renderer inspection and full CI acceptance
have not been independently observed in this pass. The existing
symbol-example inventory tracks structural coverage, not reader clarity.


## Exact-head GitHub Actions and documentation gate inventory (2026-10-09)

Inspected GitHub Actions on commit `398db769`. The API reported
140 check runs; the first 100 checked entries were **queued**. Workflow
runs for the commit, including `CI` and `API documentation`, were also
queued. **No pass or fail conclusion can be drawn from this state.**

Verified the repository's actual documentation commands rather than
guessing the gate names:

- `.github/workflows/ci.yml` invokes `dub test --force` and
  `tools/validate-docs.sh` under its documentation-contract step.
- `.github/workflows/pages.yml` invokes
  `bash tools/build-versioned-docs.sh` and publishes the generated site
  from `build/versioned-docs/site`.
- `tools/validate-docs.sh` checks documented file presence, release
  contracts, and obsolete wording, among additional repository-specific
  requirements. It does not, by itself, replace a human DDox-page reading.

**Remaining evidence:** run both commands and compile the getting-started
consumer example with DMD and LDC; inspect the generated symbol pages for
example attachment and rendering. Mark those gates PASS only after a
recorded successful run on the reviewed commit. This section records a
CI-queue observation, **not** a CI failure.


## Executable example shape and environment limitation

Rechecked the new Helmert workflow in `docs/getting-started.md` and wrapped
its declarations in a complete `void main()` program with `import geodesy;`.
The former top-level declarations were not a self-contained runnable D
program. The public API calls remain unchanged.

A local toolchain check in the review environment found **neither `dmd`
nor `ldc2` available**; no local compiler result is claimed. GitHub Actions
for the prior reviewed commit also remained queued, not passed. Once a
compiler environment is available, the whole fenced program should be
compiled with both baseline compilers and checked in a consumer DUB project.

**Do not mark this example or PR documentation gate PASS on the strength
of signature inspection or structural fixes alone.**


## XPS local release-documentation gate evidence — 2026-10-09

**Verified source:** XPS terminal transcript for checkout
`79de38bea8073a27b65f553db75beac647c30e1f`
(reported DUB package `1.2.0+commit.197.g79de38b`).

| Executed command/gate | Observed outcome |
| --- | --- |
| `dub test --compiler=dmd` | **PASS:** 37 modules passed unittests |
| `dub test --compiler=ldc2` | **PASS:** 37 modules passed unittests |
| `bash tools/validate-docs.sh` | **PASS:** 38 Ddoc module files generated; documentation/release metadata contract |
| `bash tools/build-versioned-docs.sh` | **PASS:** v1.0.0 archive plus current public-only DDox generated |
| Current public-module Ddoc contract | **PASS:** 29 modules |
| Public API example audit | **PASS:** 463 public symbol pages, 463 compiled examples, `add=0`, `family=0` |
| Current/v1.0.0 site separation | **PASS** |

The transcript confirms source-aware stripping of 269 internal
declarations from 265 source-internal declarations for the current site.
Generated current-site entrypoint:
`build/versioned-docs/output/current/build/ddox/site/index.html`.

**Evidence boundary:** the example audit proves the repository's
compiled per-symbol Example gate, not that every example has been
visually inspected or that all 463 pages pass the human consumer
comprehension test. The standalone Getting Started Helmert example
still needs a separate explicit DMD/LDC consumer compilation. These
results apply to commit `79de38b`; any subsequent docs change
requires revalidation before release sign-off. GitHub Actions
completion remains a separate gate.
