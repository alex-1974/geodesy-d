# ADR-0010: Height and vertical-reference semantics

**Status:** Accepted, amended for the stable v1 API
**Date:** 2026-09-21
**Amended:** 2026-10-05
**Project:** `geodesy-d`
**Decision scope:** public coordinate/value semantics, vertical-reference architecture, future compatibility
**Consumer:** terrain support for the planned OSM editor

## Context and motivation

`geodesy-d` models geodetic mathematics and Earth-related coordinate semantics.
The fundamental distinctions concerning height and vertical reference were
identified before the v1 API was stabilized. The architecture remains
applicable after the v1 release, but compatibility requirements now constrain
changes to the published public surface.

In particular, the stable v1 API retains the source-compatible zero-height
default of `GeodeticCoordinate<T>.fromComponents`. This amendment distinguishes
that compatibility constraint from the longer-term semantic architecture and
records removal of the default argument as a possible future major-version
change rather than a v1.x change.

A concrete consumer now requires this distinction.

The planned OSM editor is expected to use external terrain data such as:

- SRTM;
- Copernicus DEM;
- national digital terrain/elevation models;
- LiDAR-derived products;
- other raster or sampled elevation sources.

Expected uses include:

- obtaining an elevation at a geographic position;
- calculating elevation profiles along OSM geometries;
- checking the plausibility of waterway flow direction;
- calculating gradients and slopes;
- displaying terrain and contour layers;
- comparing or combining terrain sources using different vertical references.

Raster storage, raster formats and terrain-source orchestration do not belong in `geodesy-d`. They do, however, expose a geodetic requirement: a numerical vertical coordinate is not meaningful enough for geodetic use unless its height semantics and reference are known.

A permanently public model such as

```d
struct Position
{
    double latitude;
    double longitude;
    double height;
}
```

would conflate materially different concepts and would make later introduction of vertical reference systems unnecessarily disruptive.

The workspace design principles require materially different domain concepts to remain distinguishable and conversions between them to be explicit. `geodesy-d` is already defined as the library owning Earth-, ellipsoid-, geographic/geocentric-coordinate and reference-frame semantics, while complete CRS databases and general transformation infrastructure remain outside its bounded mathematical core.
This ADR therefore establishes the semantic architecture required for height without committing `geodesy-d` to a complete vertical-CRS or geoid-transformation implementation.

---

## Terminology

### Horizontal geographic position

A **horizontal geographic position** identifies a position on or relative to the Earth using a two-dimensional geographic coordinate system, normally latitude and longitude.

Conceptually:

```text
horizontal geographic position
    = latitude + longitude
```

It does not implicitly contain a height.

The horizontal position and vertical coordinate are separate semantic concepts even when an external interchange format stores them together.

---

### Ellipsoidal height

**Ellipsoidal height**, conventionally denoted `h`, is height measured relative to a reference ellipsoid.

It is part of the coordinate tuple of a three-dimensional geodetic/geographic coordinate system.

It is not, for the purposes of this architecture, treated as a value belonging to an independent vertical CRS.

Consequently:

```text
latitude + longitude + ellipsoidal height
```

forms a geodetic three-dimensional position whose components belong to one geodetic reference model.

A type representing ellipsoidal height MUST NOT be interchangeable with a type representing a gravity-related height merely because both are expressed in metres.

---

### Gravity-related height

A **gravity-related height** is a vertical coordinate defined through a gravity-related vertical reference system.

The term is intentionally broader than orthometric height.

A gravity-related height requires sufficient vertical-reference information to establish what its numerical value means.

Examples of reference systems encountered by consumers may include national height systems or global geoid-based height systems.

Two equal numerical gravity-related heights using different vertical references MUST NOT be assumed to identify the same physical level.

---

### Orthometric height

**Orthometric height**, conventionally denoted `H`, is a particular form of gravity-related height associated with a gravity/equipotential reference.

The API MUST NOT use `orthometric height` as an indiscriminate synonym for every non-ellipsoidal elevation value.

Where the distinction matters, the more general concept `gravity-related height` SHOULD be used unless the stronger orthometric semantics are actually known.

---

### Elevation

**Elevation** is treated as a contextual or application-level term rather than the fundamental geodetic type.

Datasets and applications frequently use `elevation` loosely for values that may be:

- ellipsoidal heights;
- gravity-related heights;
- orthometric heights;
- heights in a local engineering system;
- relative heights;
- or values whose reference is unknown.

A generic name such as `Elevation` therefore MUST NOT silently imply a specific vertical datum or height type.

An API dealing with externally supplied elevation values SHOULD either establish their semantics explicitly or represent the fact that those semantics are not known.

---

### Vertical reference frame / vertical datum

A **vertical reference frame** establishes the reference from which a gravity-related vertical coordinate is measured.

External standards and datasets may use terminology such as `vertical datum`, `vertical reference frame`, or closely related historical terminology.

`geodesy-d` SHOULD use terminology consistent with contemporary geodetic standards where practical while still permitting external identifiers and metadata using established names.

A vertical reference is not merely a display label. It is part of the meaning of a vertical coordinate.

---

### Vertical CRS

A **vertical coordinate reference system** combines a vertical reference frame with a one-dimensional vertical coordinate system.

For this architecture, a vertical CRS applies to gravity-related height or depth semantics.

Ellipsoidal height MUST NOT be represented as though it were an ordinary independent vertical CRS.

---

### Geographic 3D CRS

A **geographic 3D CRS** contains latitude, longitude and ellipsoidal height as one three-dimensional geodetic coordinate tuple.

This distinction is fundamental:

```text
geographic 3D
    latitude
    longitude
    ellipsoidal height
```

is not semantically equivalent to:

```text
compound reference
    horizontal geographic/projected position
    +
    gravity-related vertical coordinate
```

---

### Compound CRS

A **compound CRS** combines two or more independent component reference systems.

Of particular interest to terrain consumers is the combination:

```text
horizontal 2D CRS
+
vertical CRS
```

`geodesy-d` does not need to implement a general Compound-CRS engine now, but its value types and APIs MUST NOT prevent such a representation from being introduced or provided by an interoperability layer later.

---

### Vertical transformation

A **vertical transformation** converts a vertical coordinate from one reference semantics to another.

Such a transformation may depend on:

- horizontal position;
- source reference;
- target reference;
- an interpolation/geographic reference;
- a geoid or correction model;
- grids or other external resources;
- epoch or dynamic-reference information in future cases.

It MUST therefore not be modelled as though an isolated scalar height always contains enough information for conversion.

---

## Existing API assessment

The repository audit required by this ADR has established that the current
public coordinate model does not already conflate the relevant vertical
semantics.

The existing public types have distinct domains:

```text
GeographicCoordinate<T>
    latitude + longitude
    no height component

GeodeticCoordinate<T>
    latitude + longitude + ellipsoidal height

GeocentricCoordinate<T>
    Earth-centred Cartesian X/Y/Z

ProjectedCoordinate<T>
    easting + northing

TopocentricCoordinate<T>
    local East/North/Up within a prepared topocentric frame
```

`GeographicCoordinate<T>` is deliberately two-dimensional and carries no
height semantics.

`GeodeticCoordinate<T>` already names and documents its third component as
`ellipsoidalHeight`. Its scalar storage follows ADR-0002's operation-level
linear-unit contract. The surrounding coordinate type, property name,
constructor parameter and geographic/geocentric conversion contract establish
the height semantics explicitly even though the stored value itself remains
the scalar `T`.

`GeocentricCoordinate<T>.z` is an Earth-centred Cartesian ordinate. It is not
a height value.

`TopocentricCoordinate<T>.up` is a local Cartesian Up component relative to a
prepared topocentric frame. It is not an orthometric, gravity-related or
Vertical-CRS height merely because it has a vertical direction.

`ProjectedCoordinate<T>` remains two-dimensional.

The existing geographic/geocentric conversion surface therefore already
preserves the distinction between ellipsoidal height and Cartesian Z.

No current public type represents gravity-related height or a vertical
reference. Such concepts must not later be introduced by reusing
`GeodeticCoordinate<T>.ellipsoidalHeight`, `GeocentricCoordinate<T>.z`, or
`TopocentricCoordinate<T>.up`.

The audit identified one API convenience that requires an explicit semantic
contract: the throwing `GeodeticCoordinate<T>.fromComponents` factory permits
the ellipsoidal-height argument to be omitted and then uses zero.

The stable v1 API retains this form for source compatibility. An omitted
argument denotes an actual ellipsoidal height of zero in the same linear unit
used by the associated ellipsoid axes. It does not denote unknown or absent
height, gravity-related height, or a vertical-CRS ordinate.

A caller that means a horizontal two-dimensional position SHOULD construct
`GeographicCoordinate<T>` instead of using the zero-height convenience form.

Removing the default argument would reject source accepted by the stable v1
API. Such removal is therefore reserved as a candidate breaking change for a
future major release rather than a v1.x change.

This compatibility rule does not introduce a new height wrapper and does not
change the meaning, representation, `.init` value, unit contract, or conversion
semantics of `GeodeticCoordinate<T>`.

No additional public height or vertical-reference type is required by the
current consumer at this stage.

---

## Decision

### 1. Height semantics are part of the type/domain contract

Public `geodesy-d` APIs MUST distinguish materially different height semantics.

In particular, the architecture MUST allow at least the distinction between:

```text
ellipsoidal height

and

gravity-related height
```

These concepts MUST NOT become permanently represented only as an undocumented primitive such as:

```d
double height;
```

where callers cannot determine the meaning of the value from the type or surrounding contract.

This does not require every internal numerical kernel to wrap every scalar in a rich value type. Raw scalar representation MAY be used internally where appropriate.

The public semantic boundary remains explicit.

---

### 2. Horizontal geographic position remains independently representable

A two-dimensional geographic position MUST remain representable without manufacturing a height.

Conceptually:

```d
GeographicPosition!T
```

or an equivalent existing/project-approved name represents only the horizontal geographic position.

The API MUST NOT require callers to supply a meaningless `0`, `NaN`, or arbitrary height merely to express latitude and longitude.

---

### 3. Geodetic 3D position is composition, not an untyped third ordinate

A geodetic three-dimensional position SHOULD conceptually be constructed from:

```text
horizontal geographic position
+
ellipsoidal height
```

For example, subject to the project's final naming conventions:

```d
struct GeodeticPosition3(T)
{
    GeographicPosition!T horizontal;
    EllipsoidalHeight!T height;
}
```

This example establishes semantic structure, not final public spelling.

The representation SHOULD make it difficult to accidentally substitute gravity-related elevation data for ellipsoidal height.

---

### 4. Ellipsoidal and gravity-related heights are distinct concepts

The API MUST NOT provide an implicit conversion between ellipsoidal height and gravity-related height.

In particular, APIs SHOULD reject designs equivalent to:

```d
alias Height = double;
```

when that type is expected to cover both concepts.

An explicit transformation is required because conversion generally depends on more than the source scalar value.

---

### 5. A gravity-related vertical coordinate requires a vertical reference

A referenced gravity-related height conceptually consists of:

```text
height value
+
vertical reference semantics
```

The exact representation remains to be decided.

Possible future shapes include:

```d
struct GravityRelatedHeight(T)
{
    T metres;
}

struct ReferencedVerticalCoordinate(T)
{
    GravityRelatedHeight!T value;
    VerticalReferenceId reference;
}
```

or a stronger type parameter/reference-bound representation.

The ADR does not freeze either design.

The important invariant is:

> A referenced gravity-related coordinate must make its reference recoverable from the surrounding API contract.

The reference MAY belong to:

- the value;
- a containing coordinate;
- a dataset/view;
- a transformation context;
- or another explicit owner of the shared reference metadata.

It does not have to be duplicated for every scalar sample.

---

### 6. Bulk terrain data must not require per-sample CRS objects

Semantic correctness MUST NOT force an inefficient physical representation.

For a DEM with millions of samples, the natural arrangement may be:

```text
dataset/view metadata
    horizontal reference
    vertical reference

sample storage
    float[]
    double[]
    or another numeric representation
```

rather than:

```text
millions of individually reference-tagged objects
```

The distinction between semantic contract and storage layout is deliberate.

An adapter or raster view MAY establish that all contained scalar values share a particular vertical reference.

---

### 7. Unknown vertical semantics must remain representable as unknown

External data occasionally lacks reliable vertical-reference metadata.

The library MUST NOT silently assign a default reference such as WGS 84, EGM96, EGM2008 or any national datum merely to make such a value usable.

Where support for incompletely referenced data becomes necessary, the state SHOULD be explicit, for example through concepts equivalent to:

```text
unreferenced vertical value

unknown vertical reference

externally asserted reference
```

The final representation remains open.

An unknown reference is semantically different from a known default reference.

---

### 8. CRS/reference identifiers do not imply a CRS database

`geodesy-d` MAY provide or accept lightweight identification of geodetic and vertical references.

Such identification might eventually support authority/code pairs such as:

```text
authority = "EPSG"
code      = ...
```

but an identifier is not a definition and does not imply that `geodesy-d` can resolve it.

The presence of a CRS/reference identifier MUST NOT expand `geodesy-d` into responsibility for:

- an EPSG database;
- arbitrary CRS parsing;
- WKT parsing;
- PROJJSON parsing;
- automatic coordinate-operation discovery;
- transformation-grid discovery or downloading.

These remain responsibilities of a future CRS/interoperability layer such as `proj-d`, where justified.

---

### 9. Horizontal and vertical reference metadata must remain separable

The architecture MUST permit independent identification of:

```text
horizontal reference
vertical reference
```

because terrain datasets commonly associate a horizontal CRS with a distinct vertical CRS.

It MUST also remain possible to represent a geographic 3D CRS whose ellipsoidal height is intrinsic to the geodetic 3D coordinate tuple rather than artificially decomposed into an unrelated vertical CRS.

The API therefore MUST NOT assume:

```text
every Z coordinate -> Vertical CRS
```

---

### 10. Future Compound-CRS integration must remain possible

No complete Compound-CRS model is required by this ADR.

However, APIs introduced now MUST avoid assumptions that would prevent a later representation equivalent to:

```text
horizontal CRS
+
vertical CRS
```

or interoperability with external Compound-CRS representations.

General CRS composition, validation, parsing and operation discovery are expected to belong above the bounded `geodesy-d` mathematical core.

---

### 11. Vertical transformations are operations involving context

A future transformation between vertical references MUST be modelled as an operation with the information required by the transformation.

The architecture SHOULD expect a conceptual signature such as:

```text
transformVertical(
    horizontalPosition,
    sourceVerticalCoordinate,
    sourceReference,
    targetReference,
    transformationContext)
```

rather than:

```d
height.toOtherDatum();
```

The actual API is explicitly deferred.

This preserves room for transformations requiring:

- geoid models;
- correction grids;
- interpolation CRS information;
- horizontal transformations;
- external resources;
- accuracy metadata;
- dynamic/epoch-aware information.

PROJ's current operation model demonstrates why this separation matters: Compound-CRS transformations may require a vertical operation together with horizontal operations to and from the interpolation CRS.

---

### 12. No implicit geoid model is associated with an ellipsoid

A reference ellipsoid does not by itself define an orthometric or other gravity-related height system.

The API MUST NOT imply relationships such as:

```text
WGS84 ellipsoid
    => EGM96

or

WGS84 ellipsoid
    => EGM2008
```

as automatic consequences.

Geoid/gravity models and vertical reference systems remain separate semantic objects.

---

### 13. Geodetic 3D is distinct from Euclidean 3D geometry

A geodetic coordinate containing:

```text
latitude
longitude
height
```

MUST NOT be represented as or implicitly treated as an ordinary Euclidean `Point3`.

`geo3-d` is intended to represent coordinate-system-agnostic Euclidean 3D geometry. `geodesy-d` represents Earth-dependent geodetic semantics.

The existing workspace geometry-family design explicitly separates `geo-d` and future `geo3-d` as Euclidean geometry libraries.

Consequently:

```text
GeodeticPosition3
```

and:

```text
geo3.Point3
```

belong to different domains even if both eventually contain three numeric components.

Conversion between a geodetic position and an Earth-centred Cartesian/geocentric representation is a geodetic operation, not an ordinary geometry cast.

---

## API guidelines

The following are binding design guidelines even though individual public names are not yet frozen.

### Prefer explicit semantic boundaries

Distinct semantics do not require every scalar to have a dedicated wrapper
when the surrounding public type already fixes its meaning unambiguously.

In particular, the existing:

```text
GeodeticCoordinate<T>.ellipsoidalHeight
```

may remain scalar `T` under ADR-0002 because the coordinate domain, property
name, constructors and conversion operations explicitly define the value as
ellipsoidal height.

Future APIs that expose standalone vertical values from materially different
domains must preserve their distinction through strong value types, explicit
containing types, reference-bearing contexts, or another equally explicit
contract.

An undifferentiated abstraction equivalent to:

```d
Height!T
```

must not be used where it would erase the distinction between ellipsoidal and
gravity-related height.

Types such as `EllipsoidalHeight<T>` or `GravityRelatedHeight<T>` remain
possible future designs when a concrete consumer or operation requires
standalone height values. This ADR does not introduce or require either type
now.

---

### Do not encode reference systems in field names

Avoid representations such as:

```d
double egm2008Height;
double wgs84Height;
```

as the fundamental abstraction.

Specific references are data/metadata, not distinct structural fields.

---

### Do not create false defaults

Types containing reference information MUST have deliberate `.init` semantics.

The implementation MUST NOT make `.init` silently mean:

```text
WGS 84
EGM96
EGM2008
EPSG:4326
or another convenient reference
```

unless a future API explicitly establishes such a default as part of its contract.

This follows the workspace D practice that `.init` semantics for public value types must be designed deliberately rather than accidentally inherited.

---

### Preserve explicit units

Initial public height semantics SHOULD use an explicit and documented unit policy.

The current expectation is metres for core geodetic mathematical values unless the surrounding `geodesy-d` scalar/unit architecture establishes another mechanism.

External unit conversion belongs at explicit conversion or interoperability boundaries.

A numerical value in feet MUST NOT become indistinguishable from a value in metres.

---

### Avoid implicit semantic conversions

Conversions that change:

- height type;
- vertical reference;
- horizontal reference;
- coordinate-system meaning;

MUST be explicit.

Pure representation-preserving operations may remain lightweight.

---

### Keep identifiers separate from resolved definitions

A future API SHOULD distinguish conceptually between:

```text
reference identifier
```

and:

```text
resolved reference definition
```

An authority/code pair is sufficient for identity/interchange in some contexts but not sufficient to execute arbitrary transformations.

---

### Allow metadata to live at the correct granularity

The API MUST permit references to apply at dataset/view/collection level when many values share the same semantics.

Do not force redundant metadata into every coordinate purely for type-theoretical uniformity.

---

### Use terminology deliberately

Public Ddoc SHOULD distinguish at least:

```text
ellipsoidal height
gravity-related height
orthometric height
vertical reference
vertical CRS
geographic 3D CRS
compound CRS
```

where applicable.

`altitude`, `elevation`, `height`, and `z` SHOULD NOT be used interchangeably in public geodetic contracts.

---

## Non-goals

This ADR does **not** require implementation of any of the following.

### Geoid models

No immediate implementation of:

- EGM96;
- EGM2008;
- national geoids;
- quasi-geoid models;
- local correction surfaces.

is required.

---

### Vertical transformation engine

`geodesy-d` is not required by this ADR to perform arbitrary transformations between vertical reference systems.

---

### EPSG database

No embedded EPSG registry or database is introduced.

`geodesy-d` does not need to resolve arbitrary EPSG codes.

---

### WKT or PROJJSON

Parsing, serialization or general semantic evaluation of:

- WKT1;
- WKT2;
- PROJ strings;
- PROJJSON;

is outside this decision.

---

### General CRS operation discovery

Selecting transformations automatically based on source CRS, target CRS, area of use, accuracy and available resources remains outside the bounded mathematical scope of `geodesy-d`.

A future PROJ integration is the natural candidate for this responsibility.

---

### Transformation-grid management

Downloading, caching, locating, versioning and loading vertical correction grids is not introduced here.

---

### Raster support

`geodesy-d` does not become responsible for:

- GeoTIFF;
- HGT;
- DTED;
- DEM raster storage;
- interpolation over raster samples;
- raster pyramids;
- tiles;
- terrain rendering.

Those capabilities belong in raster/imagery and interoperability layers.

---

### Terrain algorithms

The following are consumers of height semantics, not responsibilities created by this ADR:

- contour generation;
- slope analysis;
- aspect calculation;
- flow-direction inference;
- drainage modelling;
- terrain shading;
- OSM waterway validation.

---

### Complete ISO 19111 object model

This ADR borrows established geodetic distinctions from the CRS standards but does not require `geodesy-d` to reproduce the complete ISO 19111 object hierarchy.

The smallest domain model sufficient for `geodesy-d` remains preferred.

---

## Consequences

### Positive

The design prevents a generic `double height` from becoming an accidental long-term API commitment.

Terrain consumers can distinguish incompatible elevation sources before numerical processing.

Geodetic 3D semantics remain separate from Euclidean 3D geometry.

Future vertical-reference and Compound-CRS support can be added without replacing the fundamental position model.

Efficient raster storage remains possible because reference metadata need not be repeated per sample.

A future `proj-d` can integrate richer CRS and transformation capabilities without forcing those responsibilities into `geodesy-d`.

---

### Costs

The API will contain more semantic types than a simple `(lat, lon, z)` representation.

Callers importing externally ambiguous data may be required to state that ambiguity explicitly.

Conversions that were superficially convenient may require explicit operations.

Naming and ownership boundaries around reference identifiers require additional
design before such identifiers are introduced into the public API.

These costs are accepted because confusing different vertical coordinate semantics can produce numerically plausible but geodetically incorrect results.

---

## Compatibility requirement

Any new or modified API containing a vertical ordinate MUST be audited for
explicit semantics. Relevant concepts or fields include approximately:

```text
height
altitude
elevation
z
position3
coordinate3
geographic3
geodetic3
```

as well as conversions between:

```text
geographic
geocentric
projected
Cartesian
```

The audit must determine whether each vertical component has explicit semantics
and must not silently reinterpret an existing public component.

For the stable v1 API, source compatibility constrains corrections to already
published signatures. Existing behavior with an explicit, documented meaning
MUST remain compatible throughout v1.x unless a separate compatibility policy
permits otherwise.

New v1.x APIs MUST NOT introduce ambiguous height semantics merely for
convenience. If removal or reinterpretation of an existing v1 signature is
desirable for semantic clarity, that change SHOULD be recorded as a candidate
for a future major release.

Accordingly, the v1 two-argument
`GeodeticCoordinate<T>.fromComponents(latitude, longitude)` form remains
source-compatible and denotes ellipsoidal height zero. Removing that default
argument is a candidate major-version change.

---

## Open questions

### Q1 — Exact public type names

Candidates include concepts such as:

```text
EllipsoidalHeight
GravityRelatedHeight
OrthometricHeight
GeodeticPosition3
GeographicPosition
VerticalReferenceId
CrsId
```

The final vocabulary must be reconciled with the current `geodesy-d` public naming system before adoption.

No name in this ADR's illustrative code is automatically frozen.

---

### Q2 — Is `OrthometricHeight` a public type?

Possible designs include:

```text
GravityRelatedHeight only
```

with the reference carrying the stronger interpretation, or:

```text
GravityRelatedHeight
OrthometricHeight
```

as separate semantic types.

The decision should follow concrete operations and consumers rather than taxonomic completeness.

---

### Q3 — How should references be represented?

Candidate approaches include:

1. opaque authority/code identifiers;
2. small strongly typed reference identifiers;
3. lightweight resolved definitions for built-in bounded cases;
4. reference metadata owned entirely by a higher CRS layer.

The chosen design must preserve `geodesy-d` independence from a CRS database.

---

### Q4 — Should `geodesy-d` define a generic `CrsId`?

A unified identifier could simplify metadata exchange, but risks implying that `geodesy-d` owns general CRS infrastructure.

An alternative is to expose only the minimal reference concepts required by its own domain and let `proj-d` own general CRS identification.

This requires an explicit design decision before introducing a public identifier hierarchy.

---

### Q5 — How is an unreferenced external elevation represented?

Possible approaches include:

- a distinct unreferenced type;
- optional reference metadata;
- a tagged state;
- keeping raw data outside `geodesy-d` until reference semantics are established.

The design should make accidental treatment as referenced data difficult without making ingestion unnecessarily cumbersome.

---

### Q6 — Static versus dynamic vertical reference frames

Modern reference systems may be dynamic and epoch-dependent.

The first implementation need not solve this problem, but reference identifiers and position types SHOULD avoid assumptions that permanently rule out epoch information.

Whether epoch belongs to coordinates, frames, transformation contexts or higher-level CRS metadata remains open.

---

### Q7 — Tide systems and other geophysical metadata

Some vertical models distinguish tide conventions and related geophysical assumptions.

The minimum amount of such metadata that belongs in `geodesy-d`, rather than a resolved CRS/model definition, requires later research.

No generic metadata bag should be added pre-emptively.

---

### Q8 — Geoid-model API boundary

If a bounded pure-D geoid model is ever implemented, it is not yet decided whether it belongs:

- directly in `geodesy-d`;
- in a specialised companion library;
- behind an adapter;
- or solely through future PROJ integration.

That decision requires a concrete consumer, model-data strategy and numerical validation plan.

---

### Q9 — Relationship to geocentric coordinates

A geographic 3D coordinate with ellipsoidal height naturally participates in conversion to and from Earth-centred Earth-fixed/geocentric Cartesian coordinates.

The project should verify that existing and planned geocentric conversion APIs preserve the height semantics established here.

A geocentric Cartesian coordinate remains geodetic/Earth-referenced and must not be confused with arbitrary `geo3-d` Euclidean geometry merely because both use Cartesian triples.

---

### Q10 — Scalar and storage policy

The semantic types must coexist with:

- scalar genericity where already supported;
- efficient bulk calculations;
- raster values commonly stored as `float`;
- calculations potentially performed in `double`.

The public semantic representation and optimized internal/bulk representation need not be identical.

Any precision conversion must follow the normal `geodesy-d` numerical contract.

---

### Q11 — Compound-CRS ownership

A future Compound-CRS abstraction may belong more naturally to `proj-d` than to `geodesy-d`.

`geodesy-d` therefore needs only enough architecture to interoperate with such a concept without owning the complete model.

The exact adapter boundary remains open.

---

## Acceptance verification

The original acceptance gate for this ADR was completed on 2026-09-21.
The compatibility aspects were amended on 2026-10-05 after stabilization of
the v1 public API.

The repository audit establishes that:

1. `GeographicCoordinate<T>` is an explicit two-dimensional geographic
   coordinate without height semantics;
2. `GeodeticCoordinate<T>` defines its third component explicitly as
   ellipsoidal height;
3. `GeocentricCoordinate<T>.z` is an Earth-centred Cartesian ordinate rather
   than a height;
4. `TopocentricCoordinate<T>.up` is a local Cartesian Up component rather than
   a gravity-related or Vertical-CRS height;
5. no current public type represents gravity-related height or a vertical
   reference;
6. the stable v1
   `GeodeticCoordinate<T>.fromComponents(latitude, longitude)` form remains
   valid and denotes ellipsoidal height zero.

The existing geographic/geocentric and topocentric contracts remain
consistent with this decision.

The v1 compatibility amendment deliberately does not add a negative compile
probe rejecting the two-argument `GeodeticCoordinate<T>.fromComponents` form,
because that form is part of the stable v1 source surface. Removing its default
ellipsoidal-height argument is reserved as a candidate breaking change for a
future major release.

No new standalone height, vertical-reference, CRS, geoid or vertical-
transformation type is required by the current consumer.

If a later consumer introduces standalone gravity-related or referenced
vertical values, that work requires a new bounded API/design step rather than
silently extending the meaning of an existing scalar component.

---

## Decision summary

`geodesy-d` will treat height as geodetic information with explicit semantics rather than as an anonymous third numeric coordinate.

The architecture will preserve these distinctions:

```text
horizontal geographic position
    != height

ellipsoidal height
    != gravity-related height

geographic 3D position
    != horizontal 2D + vertical CRS

geodetic 3D
    != Euclidean 3D geometry

reference identifier
    != complete CRS definition

height value
    != sufficient information for arbitrary vertical transformation
```

No complete vertical-reference implementation is required now.

The immediate requirement is architectural:

> **Do not freeze an ambiguous vertical ordinate into the public API. Preserve enough semantic structure that vertical references, Compound CRS and position-dependent vertical transformations can be added later without redesigning the fundamental coordinate model.**

## Standards and implementation references

The terminology and separation used by this ADR follow the modern CRS model represented by ISO 19111/WKT2 and PROJ.

WKT2 distinguishes ellipsoidal height `h` in a three-dimensional ellipsoidal coordinate system from gravity-related height `H` in a vertical CRS, and defines Compound CRS as combinations of independent component CRSs.

PROJ's ISO-19111 model states explicitly that ellipsoidal heights are not represented by a Vertical CRS but occur as part of a geographic 3D coordinate tuple.

PROJ also demonstrates that transformations involving Compound CRS may require coordinated horizontal and vertical operations rather than an isolated scalar-height conversion.

The workspace's existing architecture already places general CRS definitions, operation discovery, transformation pipelines and grids outside the bounded `geodesy-d` mathematical core.
