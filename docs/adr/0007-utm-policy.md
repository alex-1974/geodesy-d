# ADR-0007: UTM as a policy layer over bounded Transverse Mercator

- Status: Accepted
- Date: 2026-09-16
- Applies to: Universal Transverse Mercator policy and coordinate tagging
- Depends on: ADR-0006
- Supersedes: nothing

## Context

`geodesy-d` now provides an accepted, independently validated implementation of
generic bounded Transverse Mercator through:

~~~d
TransverseMercator!T
~~~

ADR-0006 deliberately kept UTM zoning and other CRS policy outside that
numerical kernel.

UTM should now be added without introducing a second projection
implementation.

The purpose of the UTM layer is to provide:

- UTM zone semantics;
- standard automatic zone selection;
- Norway and Svalbard zone exceptions;
- hemisphere and false-northing policy;
- the fixed UTM Transverse Mercator parameters;
- a zone-tagged projected coordinate;
- explicit-zone forward and reverse operations;
- convenient automatic standard-zone forward projection.

It must not become:

- a CRS database;
- an EPSG-code resolver;
- a datum registry;
- an MGRS implementation;
- a UPS implementation;
- a coordinate-format parser;
- a second Transverse Mercator numerical kernel.

Those concerns either belong in later focused geodesy functionality or in the
future `proj-d` CRS/discovery/integration layer.

## Reference model

UTM divides the Earth into 60 longitudinal zones.

The ordinary zone width is 6 degrees. Zones are numbered eastward beginning at
the antimeridian.

For zone `z` in `[1, 60]`, the central meridian is:

~~~text
lambda0 = 6 * z - 183 degrees
~~~

The UTM Transverse Mercator parameters are:

~~~text
latitude of natural origin     0 degrees
longitude of natural origin    zone central meridian
scale factor at natural origin 0.9996
false easting                  500000 m
false northing, north          0 m
false northing, south          10000000 m
~~~

UTM uses an ellipsoidal Transverse Mercator.

The standard UTM latitude region used by this library is:

~~~text
-80 degrees <= latitude < 84 degrees
~~~

The lower boundary is closed and the upper boundary is open.

UPS is deliberately not part of this ADR.

## Resolved semantic boundaries

Independent comparison with GeographicLib and PROJ resolved several policy
boundaries which are part of this ADR.

### Automatic standard-zone policy

Automatic standard UTM selection applies only to:

~~~text
-80 degrees <= latitude < 84 degrees
~~~

The lower boundary is closed and the upper boundary is open.

Longitude is normalized to the half-open interval:

~~~text
[-180 degrees, 180 degrees)
~~~

Therefore `+180 degrees` canonicalizes to `-180 degrees` and automatic
selection returns zone 1.

Norway and Svalbard exception rules use their defined half-open endpoint
policy and are part of automatic standard-zone selection.

Mathematical latitude zero selects the northern hemisphere convention.

This deliberately differs from GeographicLib for IEEE signed `-0.0`:
GeographicLib observes the sign bit and may select the southern convention,
whereas geodesy-d treats zero as the mathematical value zero.

### Explicit prepared projection policy

`UtmProjection!T` is a prepared fixed-zone Transverse Mercator operation.

Explicitly selecting a zone does not reapply automatic standard-zone policy.

In particular, prepared forward and reverse operations:

- preserve the selected zone;
- preserve the selected hemisphere/false-northing convention;
- do not recompute a standard zone from the geographic result;
- do not switch hemisphere from the sign of latitude;
- do not reject a coordinate merely because the represented geographic
  latitude lies outside `[-80, 84)`.

The inherited bounded generic Transverse Mercator longitude-domain contract
remains authoritative.

The hemisphere value is therefore a coordinate-system convention, not a
latitude classifier.

A northern convention may be used south of the equator and a southern
convention may be used north of the equator when explicitly requested.

### Projected-coordinate envelope

GeographicLib UTM/UPS applies additional legal easting/northing windows
designed for closed UTM/UPS operation and related MGRS conventions.

`UtmProjection!T` deliberately does not adopt those windows.

This library layer is a fixed-zone projection wrapper, not a UTM/UPS or MGRS
coordinate-envelope validator.

Such constraints may be introduced later by a distinct standards/profile
layer if required.

### Ellipsoid and linear-unit policy

UTM is not intrinsically WGS 84-specific.

The current geodesy-d UTM layer nevertheless requires an ellipsoidal,
terrestrial-sized reference ellipsoid inside its documented support profile.

In particular, the Earth-size restriction is a library safety policy, not a
normative UTM rule.

The reason is that `Ellipsoid!T` currently stores the semi-major axis in an
implicit linear unit while UTM false easting and false northing are fixed in
metres.

Rejecting obviously non-terrestrial axis magnitudes prevents silently
combining kilometre-like or otherwise incompatible axis values with
metre-defined UTM offsets.

Sphere rejection and the flattening support limit likewise belong to the
current geodesy-d UTM/TM support contract; they are not claims about the
abstract definition of UTM.

## Decision

Implement UTM as a thin, explicit policy layer over
`TransverseMercator!T`.

The implementation belongs in:

~~~text
source/geodesy/projection/utm.d
~~~

No projection series, inverse iteration, coefficient generation, or other
Transverse Mercator mathematics may be duplicated in the UTM module.

All numerical projection work is delegated to the implementation accepted by
ADR-0006.

## Public types

### `UtmZone`

Introduce a strong zone-number type:

~~~d
struct UtmZone
~~~

Its valid values are exactly:

~~~text
1 .. 60
~~~

`.init` is invalid.

The expected construction surface is conceptually:

~~~d
static bool tryFromNumber(uint number, out UtmZone result)
    pure nothrow @safe @nogc;

static UtmZone fromNumber(uint number)
    @safe;

@property bool isValid() const
    pure nothrow @safe @nogc;

@property uint number() const
    pure nothrow @safe @nogc;

@property int centralMeridianDegrees() const
    pure nothrow @safe @nogc;
~~~

The central-meridian value is an exact integral number of degrees and therefore
does not need a floating-point scalar type in `UtmZone`.

### `UtmHemisphere`

Introduce:

~~~d
enum UtmHemisphere : ubyte
{
    north,
    south
}
~~~

The hemisphere value selects the UTM false-northing convention.

For the standard automatic policy:

~~~text
latitude >= 0 -> north
latitude <  0 -> south
~~~

Thus latitude zero is assigned to the northern hemisphere.

An explicitly prepared UTM projection may deliberately use either hemisphere.
This permits controlled cross-equator and externally specified
coordinate-system usage without applying automatic hemisphere policy.

The hemisphere therefore selects the coordinate convention; it is not by
itself proof that the geographic latitude has the same sign.

### `UtmCoordinate!T`

Introduce a tagged UTM projected coordinate:

~~~d
struct UtmCoordinate(T)
~~~

containing:

~~~text
UtmZone
UtmHemisphere
ProjectedCoordinate<T>
~~~

It provides at least:

~~~d
@property bool isValid() const
    pure nothrow @safe @nogc;

@property UtmZone zone() const
    pure nothrow @safe @nogc;

@property UtmHemisphere hemisphere() const
    pure nothrow @safe @nogc;

@property ProjectedCoordinate!T projected() const
    pure nothrow @safe @nogc;

@property T easting() const
    pure nothrow @safe @nogc;

@property T northing() const
    pure nothrow @safe @nogc;
~~~

and checked construction from zone, hemisphere, easting and northing.

`UtmCoordinate!T.init` is invalid because its zone is invalid.

`UtmCoordinate!T` carries no datum, CRS identifier, EPSG code, axis metadata,
height, MGRS band, or formatting information.

Its easting and northing are always interpreted as metres.

Structural validity means:

- valid zone;
- recognized hemisphere value;
- finite easting;
- finite northing.

It does not assert that the coordinate was produced by the standard automatic
zone-selection policy.

This distinction is necessary because neighboring UTM zones and explicitly
selected hemispheres are legitimate operational use cases.

## Prepared projection object

Introduce:

~~~d
UtmProjection!T
~~~

A prepared projection owns:

- the ellipsoid;
- UTM zone;
- hemisphere;
- a prepared `TransverseMercator!T`.

Construction precomputes the underlying Transverse Mercator once.

Repeated `tryForward()` and `tryReverse()` calls must reuse that prepared
operation.

The conceptual construction surface is:

~~~d
static bool tryFromZone(
    Ellipsoid!T ellipsoid,
    UtmZone zone,
    UtmHemisphere hemisphere,
    out UtmProjection result)
    pure nothrow @safe @nogc;

static UtmProjection fromZone(
    Ellipsoid!T ellipsoid,
    UtmZone zone,
    UtmHemisphere hemisphere)
    @safe;
~~~

The operational surface is:

~~~d
bool tryForward(
    GeographicCoordinate!T source,
    out ProjectedCoordinate!T result)
    const pure nothrow @safe @nogc;

bool tryReverse(
    ProjectedCoordinate!T source,
    out GeographicCoordinate!T result)
    const pure nothrow @safe @nogc;
~~~

Throwing convenience wrappers may mirror the established
`TransverseMercator!T` API style.

The prepared object should expose read-only properties for its defining policy,
including:

~~~text
ellipsoid
zone
hemisphere
longitude of natural origin
scale factor at natural origin
false easting
false northing
~~~

The underlying `TransverseMercator!T` object remains an implementation detail.

## Ellipsoid and linear-unit contract

UTM has fixed offsets expressed in metres.

`geodesy-d` does not encode a linear unit in `Ellipsoid!T`.

For this reason, UTM construction deliberately accepts only Earth-sized
ellipsoid parameters expressed numerically in metres:

~~~text
6,000,000 m <= semi-major axis <= 7,000,000 m
0 < flattening <= 0.01
~~~

This has several consequences.

A sphere is rejected.

An ellipsoid whose semi-major axis is supplied in kilometres is rejected.

Ordinary terrestrial historical and modern reference ellipsoids remain within
the supported range.

The restriction also keeps UTM completely inside the ordinary-profile
Transverse Mercator accuracy envelope validated by ADR-0006.

The generic `Ellipsoid!T` and `TransverseMercator!T` types remain broader;
this restriction belongs specifically to UTM policy.

## Geographic domain

### Automatic standard UTM

Automatic UTM selection accepts geographic coordinates only when:

~~~text
-80 degrees <= latitude < 84 degrees
~~~

Outside this range, automatic UTM selection fails.

There is no implicit fallback to UPS.

### Explicit UTM projection

An explicitly constructed `UtmProjection!T` represents one fixed UTM
Transverse Mercator parameterization selected by the caller.

The standard automatic UTM latitude interval:

~~~text
-80 degrees <= latitude < 84 degrees
~~~

does **not** constrain this prepared explicit projection. That interval belongs
to automatic standard UTM/UPS selection.

An explicit projection therefore does not require:

- the selected zone to be the standard automatic zone for the point;
- the selected hemisphere to match the sign of the latitude;
- the geographic latitude to lie inside the automatic standard UTM band.

This supports neighboring-zone use, explicit hemisphere conventions and
externally specified projected coordinate systems without silently recomputing
policy from each point.

The existing bounded `TransverseMercator!T` domain remains authoritative.
In particular, an explicitly selected zone that places a source farther than
the supported Transverse Mercator longitude distance from its central meridian
may fail.

This separation follows the reference-model distinction between standard zone
selection and an explicitly selected UTM zone: the former applies the
`[-80, 84)` automatic UTM band, while the latter is a fixed Transverse
Mercator operation.

## Longitude canonicalization

`Longitude!T` admits both `-180 degrees` and `+180 degrees`.

UTM standard-zone selection first uses the canonical
`Longitude.normalized` representation:

~~~text
[-180 degrees, +180 degrees)
~~~

Therefore:

~~~text
-180 degrees -> zone 1
+180 degrees -> normalized -180 degrees -> zone 1
~~~

This removes an otherwise ambiguous antimeridian boundary case.

Ordinary zone intervals are lower-closed and upper-open.

For example:

~~~text
zone 1:  [-180, -174)
zone 2:  [-174, -168)
...
zone 31: [0, 6)
...
zone 60: [174, 180)
~~~

## Standard zone selection

For a normalized longitude `lon`, the ordinary zone is:

~~~text
floor((lon + 180) / 6) + 1
~~~

with the Norway and Svalbard exceptions below.

### Norway exception

For:

~~~text
56 <= latitude < 64
3  <= longitude < 12
~~~

the standard zone is:

~~~text
32
~~~

### Svalbard exceptions

For:

~~~text
72 <= latitude < 84
~~~

use:

~~~text
 0 <= longitude <  9  -> zone 31
 9 <= longitude < 21  -> zone 33
21 <= longitude < 33  -> zone 35
33 <= longitude < 42  -> zone 37
~~~

Outside these exception intervals, ordinary 6-degree zoning applies.

All tests are lower-closed and upper-open.

## Standard-zone API

Provide a checked, allocation-free operation conceptually equivalent to:

~~~d
bool tryStandardUtmZone(T)(
    GeographicCoordinate!T source,
    out UtmZone zone,
    out UtmHemisphere hemisphere)
    pure nothrow @safe @nogc;
~~~

It:

1. rejects latitude outside the standard UTM region;
2. normalizes longitude;
3. applies ordinary zoning;
4. applies Norway/Svalbard exceptions;
5. derives hemisphere from latitude.

A throwing convenience wrapper may also be provided.

## Automatic forward convenience API

Provide a convenience operation conceptually equivalent to:

~~~d
bool tryForwardUtm(T)(
    Ellipsoid!T ellipsoid,
    GeographicCoordinate!T source,
    out UtmCoordinate!T result)
    pure nothrow @safe @nogc;
~~~

It performs standard zone and hemisphere selection and then delegates to a
prepared UTM projection.

A throwing wrapper may also be provided.

This convenience path may prepare a projection for the selected zone on each
call.

It is intended for isolated or heterogeneous geographic points.

Consumers processing many points in one known zone should use
`UtmProjection!T` directly so coefficient preparation occurs once.

No hidden global cache is introduced.

## Tagged reverse convenience API

Provide a reverse convenience operation conceptually equivalent to:

~~~d
bool tryReverseUtm(T)(
    Ellipsoid!T ellipsoid,
    UtmCoordinate!T source,
    out GeographicCoordinate!T result)
    pure nothrow @safe @nogc;
~~~

It constructs the explicitly tagged zone/hemisphere projection and delegates to
the generic Transverse Mercator reverse operation.

It does not reassign the returned location to its automatic standard zone.

This is essential for reversibility of coordinates deliberately represented in
neighboring zones.

## Fixed UTM parameterization

For zone `z` and hemisphere `h`, construct the underlying
`TransverseMercator!T` with:

~~~text
latitudeOfNaturalOrigin  = 0 degrees
longitudeOfNaturalOrigin = 6 * z - 183 degrees
scaleFactorAtNaturalOrigin = 0.9996
falseEasting             = 500000 m

falseNorthing =
    0 m          when h == north
    10000000 m   when h == south
~~~

No UTM-specific projection formula is permitted.

## Error and checked-operation semantics

The non-throwing API remains primary for hot paths.

Expected invalid cases return `false`, including:

- invalid zone;
- invalid hemisphere representation;
- invalid or unsupported ellipsoid;
- spherical ellipsoid;
- ellipsoid outside the UTM metre/Earth-size profile;
- automatic source outside the standard UTM latitude region;
- underlying bounded Transverse Mercator rejection.

Throwing convenience APIs use the existing `GeodesyValueException`.

No ordinary invalid-input path requires a new exception hierarchy.

## Scalar policy

UTM supports the same public scalar families as Transverse Mercator:

~~~text
float
double
real
~~~

No UTM computation may silently narrow a public scalar before delegation.

Zone arithmetic itself is exact integer arithmetic where possible.

Fixed constants are converted directly to the requested public scalar.

The numerical accuracy contract is inherited from the accepted generic
Transverse Mercator implementation.

Within the UTM ellipsoid and geographic profile:

~~~text
float   <= 2 m
double  <= 1 mm
real    <= 1 mm
~~~

subject to the representation limits already documented by ADR-0006.

## Allocation and attributes

The checked prepared hot path is required to remain callable from:

~~~d
pure nothrow @safe @nogc
~~~

This includes:

- zone construction;
- standard-zone selection;
- prepared UTM construction;
- prepared forward;
- prepared reverse;
- automatic checked forward;
- tagged checked reverse.

Throwing convenience wrappers are `@safe` but are not required to be
`nothrow` or `@nogc`.

## Performance policy

UTM introduces policy arithmetic and delegation, not a new numerical kernel.

No independent requirement is introduced to outperform PROJ or GeographicLib.

The normative Transverse Mercator performance baseline remains the one recorded
for ADR-0006.

The performance-sensitive UTM design requirement is architectural:

~~~text
prepare UtmProjection once
    -> prepare TransverseMercator once
    -> reuse for repeated forward/reverse operations
~~~

An automatic per-point convenience function is not the normative bulk path.

Do not introduce:

- a second TM fast path;
- automatic approximate projection selection;
- global mutable caches;
- SIMD-specific UTM code;
- broad fast-math flags.

Any future optimization requires measurement first.

## CRS and datum boundaries

UTM zone and hemisphere do not uniquely identify a CRS.

The same UTM zone can be used with multiple datums and ellipsoids.

Therefore `geodesy-d` must not infer or manufacture EPSG projected-CRS codes
such as WGS 84 / UTM zone identifiers from `UtmCoordinate!T`.

EPSG authority lookup, CRS identity, datum selection and operation discovery
belong in `proj-d`.

Likewise, `UtmCoordinate!T` does not imply WGS 84.

The ellipsoid is always explicit at the projection-operation boundary.

## MGRS and UPS boundaries

MGRS is not represented by `UtmZone`, `UtmHemisphere`, or `UtmCoordinate`.

In particular:

- the letters C through X are MGRS latitude bands, not UTM hemispheres;
- MGRS 100 km square lettering is out of scope;
- precision/truncation rules are out of scope.

UPS is also out of scope.

A coordinate outside the automatic UTM latitude region fails rather than
silently switching projection family.

If UPS or MGRS are later added, they require separate design and validation.

## Alternatives considered

### Implement UTM formulas independently

Rejected.

UTM is a policy specialization of Transverse Mercator. A second numerical
implementation would duplicate difficult projection mathematics and create a
new independent correctness burden.

### Hard-code WGS 84

Rejected.

UTM zoning and projection parameters are not inherently equivalent to WGS 84.
Real projected CRSs use UTM with other terrestrial reference systems and
ellipsoids.

The ellipsoid therefore remains explicit.

### Infer EPSG 326xx / 327xx codes

Rejected.

Those identifiers specifically encode WGS 84 projected CRSs. Zone and
hemisphere alone are insufficient to establish CRS identity.

### Store only easting and northing

Rejected for automatic UTM results.

Without zone and hemisphere, a UTM coordinate cannot be reversed
unambiguously.

The generic untagged `ProjectedCoordinate!T` remains appropriate inside an
already prepared `UtmProjection!T`.

### Require every point to use its automatic standard zone

Rejected.

Neighboring-zone representation is a legitimate operation and is supported by
mature reference implementations.

Standard-zone selection is therefore one policy operation, while explicit
`UtmProjection!T` remains available.

### Permit automatic UPS fallback

Rejected.

It would silently change projection families and expand this ADR substantially.

Out-of-range automatic UTM input is rejected explicitly.

### Permit arbitrary ellipsoid units

Rejected.

UTM false origins are defined in metres, while `Ellipsoid!T` does not encode a
linear unit.

The bounded Earth-sized metre profile makes the unit expectation explicit and
keeps the implementation inside the already validated fixed-metre accuracy
contract.

### Encode an MGRS latitude-band letter in `UtmCoordinate`

Rejected.

A latitude-band letter is an MGRS/grid-designation concept and must not be
confused with the north/south UTM false-northing convention.

## Validation requirement

Acceptance required the requirements in `docs/UTM_VALIDATION_PLAN.md`
to pass. That validation program is complete and this ADR is `Accepted`.

Validation must demonstrate:

- all 60 zones;
- exact central-meridian mapping;
- standard half-open zone boundaries;
- antimeridian canonicalization;
- Norway exception;
- Svalbard exceptions;
- standard latitude boundaries;
- north/south false-northing behavior;
- explicit neighboring-zone use;
- explicit hemisphere override behavior;
- equivalence to the accepted generic TM parameterization;
- differential agreement with external UTM references;
- `float`, `double`, and `real`;
- checked API attributes and allocation behavior;
- supported CI platforms/architectures.

No acceptance claim is based solely on round-trip self-consistency.

## Consequences

### Positive

- no duplicated projection mathematics;
- UTM policy remains small and reviewable;
- CRS concerns remain outside `geodesy-d`;
- bulk users can reuse a prepared operation;
- zone/hemisphere information is preserved where needed;
- standard automatic zoning is deterministic;
- neighboring-zone use remains possible;
- existing TM accuracy and performance evidence remains relevant.

### Costs

- automatic convenience projection must prepare an operation per selected zone;
- callers must provide an explicit ellipsoid;
- callers needing UPS or MGRS require later functionality;
- the metre-based ellipsoid contract must be documented prominently;
- tagged UTM coordinates still do not identify a complete CRS.

## References

Primary operational/reference material used for this decision:

- PROJ, Universal Transverse Mercator:
  https://proj.org/en/stable/operations/projections/utm.html
- PROJ, Transverse Mercator:
  https://proj.org/en/stable/operations/projections/tmerc.html
- PROJ EUREF tutorial, UTM parameter relationship to TM:
  https://proj.org/en/stable/tutorials/EUREF2019/exercises/projections3.html
- GeographicLib `UTMUPS` documentation/source, standard-zone semantics,
  Norway/Svalbard handling and explicit-zone operation:
  https://geographiclib.sourceforge.io/
- EPSG method 9807 semantics are inherited through ADR-0006.

External implementations are validation references and evidence, not the
specification for geodesy-d implementation structure.
