# v1 public API audit

Status: **V1-A complete — source inventory and external aggregate compile check passed**

The v1 feature freeze is active. This audit determines the concrete public API
that may later be accepted and frozen for v1.0.

V1-A is deliberately descriptive. Presence in this inventory is **not**
acceptance of a symbol, name, signature, default-state semantic, or module
boundary.

## Audit gates

~~~text
V1-A  complete public-surface inventory
V1-B  naming and API-family consistency
V1-C  .init / construction / mutability
V1-D  checked / throwing / failure semantics
V1-E  scalar / unit / canonicalization / domain contracts
V1-F  module / aggregate / visibility boundaries
V1-G  source compatibility and named arguments
V1-H  documentation versus actual API
V1-I  external consumer and compiler/platform validation
V1-J  final API-freeze and release gate
~~~

A later gate may add, rename, remove, or change candidate API before the final
API freeze when the change is justified by the audit.

## V1-B naming and API-family consistency

Status: **active — audit only**

V1-B reviews the candidate surface accepted by V1-A for naming and family
consistency. It does not change production API merely to make names visually
uniform; differences remain acceptable when they encode different semantics.

### V1-B review dimensions

~~~text
B1  checked / throwing pair names
B2  construction and factory vocabulary
B3  coordinate component and property vocabulary
B4  prepared-operation method families
B5  argument ordering across related free functions and methods
B6  transformation direction / convention naming
B7  projection parameter vocabulary
B8  result-type and accessor vocabulary
B9  type / enum / alias naming
B10 aggregate-visible conditional or validation-only declarations
~~~

The review must classify each difference as one of:

~~~text
consistent
intentional semantic specialization
candidate inconsistency
conditional/debug-only surface requiring a visibility decision
~~~

### Initial family map

The source surface already shows several strong naming families:

- checked factories generally use `tryFrom...` and throwing factories use the
  same suffix without `try`;
- checked operations generally use `try...` and throwing operations use the
  same operation name without `try`;
- coordinate accessors use domain names rather than generic tuple positions:
  `latitude/longitude`, `x/y/z`, `easting/northing`, and
  `east/north/up`;
- prepared projections use `tryForward/forward` and
  `tryReverse/reverse`;
- factor operations extend that vocabulary as
  `tryForwardFactors/forwardFactors` and
  `tryReverseFactors/reverseFactors`;
- static transformation functions use the operation name after
  `tryApply/apply`;
- projection parameter properties consistently use EPSG-style names such as
  `latitudeOfNaturalOrigin`, `longitudeOfNaturalOrigin`,
  `scaleFactorAtNaturalOrigin`, `falseEasting`, and `falseNorthing`
  where the parameter is semantically present.

### Initial items requiring explicit V1-B review

1. `GeographicCoordinate.fromComponents` has no checked
   `tryFromComponents` peer, unlike the other coordinate value types. This
   may be intentional because its components are already validated strong
   types; V1-B must classify rather than normalize it automatically.
2. `Geodesic` exposes checked `tryDirect` and `tryInverse` operations but
   no throwing `direct` / `inverse` peers. This is a family difference and
   requires a semantic/API decision.
3. UTM one-shot operations use the same checked/throwing naming family as
   prepared projections, but take the ellipsoid before the source. Argument
   ordering must be compared with conversion and transformation free
   functions before v1 freezes parameter order.
4. `GeocentricTranslation.inverse` and Helmert
   `toCoordinateFrame/toPositionVector` are conversion/inversion operations
   rather than checked/throwing pairs; their naming should be reviewed as a
   transformation family, not forced into projection vocabulary.
5. `TransverseMercator.tryReverseNewtonTrace` becomes public only under
   `GeodesyTmNewtonValidation`. V1-B records this conditional public name;
   V1-F will decide whether a validation build is allowed to alter the public
   module surface.

No item above is yet a requested production change.


### B1/B2 — checked/throwing pairs and factory vocabulary

Status: **reviewed**

The dominant construction convention is coherent:

~~~text
tryFromX(args..., out result)  -> checked, non-throwing construction
fromX(args...)                 -> throwing construction
~~~

This family is used by angular values, ellipsoids, finite coordinate values,
prepared frames/projections, UTM zone/projection values, static
transformations, and the prepared geodesic solver. `Ellipsoid.trySphere /
sphere` is an intentional noun factory rather than a `From...` spelling and
still follows the checked/throwing prefix relationship.

Classification of apparent exceptions:

- `GeographicCoordinate.fromComponents`: **intentional semantic
  specialization**. Its inputs are already domain-validating strong
  `Latitude` and `Longitude` values, so construction has no additional
  failure path. Adding `tryFromComponents` would create a checked operation
  with no condition to check.
- `GeodesicDirectResult` and `GeodesicInverseResult` component factories:
  **not public API**. They are private result-construction helpers and are
  removed from the V1-A public-member inventory.
- `ConformalProjectionFactors`: likewise exposes result accessors, not a
  public component factory.
- `Geodesic.tryDirect` / `tryInverse` without throwing peers:
  **candidate API decision**, not a naming defect by itself. These operations
  have algorithm/domain failure paths and currently expose only the checked
  form. V1-D must decide the desired failure contract; V1-B must not invent
  throwing peers before that decision.
- `tryStandardUtmZone` without a throwing `standardUtmZone`:
  **candidate API decision** for the same reason. Automatic zone selection has
  an explicit unsupported latitude region; whether a throwing convenience
  belongs in v1 is a failure-semantics question for V1-D.

For operations that already provide both forms, the naming is consistent:

~~~text
tryForward / forward
tryReverse / reverse
tryForwardFactors / forwardFactors
tryReverseFactors / reverseFactors
tryApplyGeocentricTranslation / applyGeocentricTranslation
tryApplyPositionVectorHelmert / applyPositionVectorHelmert
tryApplyCoordinateFrameHelmert / applyCoordinateFrameHelmert
tryForwardUtm / forwardUtm
tryReverseUtm / reverseUtm
~~~

**B1/B2 conclusion:** no production rename or factory rename is justified at
this gate. The two missing throwing counterparts are carried forward to V1-D
as explicit semantic decisions.


### B3/B4 — coordinate vocabulary and prepared-operation families

Status: **reviewed**

The coordinate/property vocabulary is semantically regular and intentionally
uses the terminology of each coordinate system rather than generic positional
names:

~~~text
GeographicCoordinate   latitude / longitude
GeodeticCoordinate     latitude / longitude / ellipsoidalHeight
GeocentricCoordinate   x / y / z
ProjectedCoordinate    easting / northing
TopocentricCoordinate  east / north / up
UtmCoordinate          zone / hemisphere / projected / easting / northing
~~~

Classification:

- `ellipsoidalHeight` is preferred over a generic `height`: the qualifier
  distinguishes the value from orthometric or other height systems.
- `easting/northing` versus `east/north/up` is **intentional semantic
  specialization**. The former are projected-coordinate ordinates; the latter
  are local ENU components.
- `UtmCoordinate.projected` plus convenience `easting/northing` accessors
  is consistent with UTM carrying both projection ordinates and the zone /
  hemisphere metadata required for unambiguous reverse projection.
- `Angle.radians/degrees`, `Latitude.radians/degrees/asAngle`, and
  `Longitude.radians/degrees/asAngle/normalized` form a coherent angular
  vocabulary. `normalized` is longitude-specific because canonical
  longitude wrapping is a domain operation, not a generic angle operation.

Prepared operation families are also regular:

~~~text
TransverseMercator:
    tryForward / forward
    tryReverse / reverse
    tryForwardFactors / forwardFactors
    tryReverseFactors / reverseFactors

PseudoMercator:
    tryForward / forward
    tryReverse / reverse

UtmProjection:
    tryForward / forward
    tryReverse / reverse
    tryForwardFactors / forwardFactors
    tryReverseFactors / reverseFactors

TopocentricFrame:
    tryGeocentricToTopocentric / geocentricToTopocentric
    tryTopocentricToGeocentric / topocentricToGeocentric
    tryGeodeticToTopocentric / geodeticToTopocentric
    tryTopocentricToGeodetic / topocentricToGeodetic

Geodesic:
    tryDirect
    tryInverse
~~~

The longer Topocentric method names are **intentional semantic
specialization**: unlike a projection object's unambiguous forward/reverse
direction, a `TopocentricFrame` supports two source coordinate families, so
the source and destination names prevent ambiguity.

Pseudo-Mercator intentionally has no factor methods in the accepted bounded
v1 capability; this is a feature-scope difference rather than an API-family
naming defect.

Geodesic's `direct` / `inverse` terminology is the standard distinction
between the two geodesic problems and should not be renamed to
`forward/reverse`. The absence of throwing peers remains deferred to V1-D.

**B3/B4 conclusion:** no naming correction is indicated. The public coordinate
and prepared-operation vocabularies are internally coherent, with differences
corresponding to distinct domain semantics.


### B5 — argument order and UFCS

Status: **reviewed — one candidate inconsistency**

For public free functions, argument order is source API in D for two reasons:
ordinary calls expose the order directly, and the first argument determines
the natural UFCS receiver. V1 therefore uses the following review rule:

> Where semantics permit, the first parameter of an operation-like free
> function should be the primary value being operated on, so that UFCS reads
> as a natural pipeline.

The existing conversion and transformation families follow that rule:

~~~d
source.geodeticToGeocentric(ellipsoid);
source.geocentricToGeodetic(ellipsoid);

source.applyGeocentricTranslation(translation);
source.applyPositionVectorHelmert(transform);
source.applyCoordinateFrameHelmert(transform);

transform.toCoordinateFrame();
transform.toPositionVector();

source.tryStandardUtmZone(zone, hemisphere);
~~~

Their ordinary-call forms therefore consistently place `source` first and
the context/operation value second.

The one-shot UTM family is the exception:

~~~d
forwardUtm(ellipsoid, source);
reverseUtm(ellipsoid, source);

// Current UFCS meaning:
ellipsoid.forwardUtm(source);
ellipsoid.reverseUtm(source);
~~~

This makes the reference ellipsoid, rather than the coordinate being
converted, the UFCS receiver. It also differs from the public geodetic /
geocentric conversion functions, which already use
`(source, ellipsoid)`.

**Classification:** `tryForwardUtm/forwardUtm` and
`tryReverseUtm/reverseUtm` are a **candidate API inconsistency**. The
source-first forms

~~~d
forwardUtm(source, ellipsoid);
reverseUtm(source, ellipsoid);

source.forwardUtm(ellipsoid);
source.reverseUtm(ellipsoid);
~~~

would align ordinary calls and UFCS with the rest of the free conversion /
transformation surface.

No production signature is changed at this audit step. Because parameter
order is source compatibility and named-argument API, any correction must be
made before V1-J and validated by the external consumer. V1-G must explicitly
account for the compatibility impact.

The checked variants must preserve the same receiver/order convention as
their throwing peers, with the `out result` parameter last.

**B5 conclusion:** all reviewed public free operation families are naturally
UFCS-capable. The one-shot UTM family's ellipsoid-first ordering was identified
as the exception and accepted for pre-v1 correction to source-first ordering.


### B6-B9 — transformation, projection, result, and type vocabulary

Status: **reviewed**

#### B6 transformation direction and convention naming

The static-transform vocabulary is coherent:

~~~text
GeocentricTranslation
    inverse
    tryApplyGeocentricTranslation / applyGeocentricTranslation

HelmertConvention
    positionVector
    coordinateFrame

PositionVectorHelmert<T>
CoordinateFrameHelmert<T>

toCoordinateFrame
toPositionVector

tryApplyPositionVectorHelmert / applyPositionVectorHelmert
tryApplyCoordinateFrameHelmert / applyCoordinateFrameHelmert
~~~

`inverse` denotes inversion of a translation value, while
`toCoordinateFrame/toPositionVector` convert between two Helmert convention
representations. These are distinct operations, so the different verbs are
intentional rather than inconsistent. The convention names are explicit and
avoid an ambiguous generic `Helmert` application function.

Classification: **consistent**.

#### B7 projection parameter vocabulary

Where semantically present, Transverse Mercator and UTM expose the same
parameter names:

~~~text
latitudeOfNaturalOrigin
longitudeOfNaturalOrigin
scaleFactorAtNaturalOrigin
falseEasting
falseNorthing
~~~

Pseudo-Mercator exposes:

~~~text
longitudeOfNaturalOrigin
falseEasting
falseNorthing
~~~

The missing latitude/scale properties on Pseudo-Mercator reflect its accepted
bounded parameter model rather than abbreviated naming. The existing names
use explicit geodetic/projection terminology and are preferable to shorter
but ambiguous forms such as `origin`, `scale`, `x0`, or `y0`.

Classification: **consistent with intentional capability specialization**.

#### B8 result and accessor vocabulary

Projection-factor results expose:

~~~text
meridianConvergence
pointScale
~~~

Geodesic results expose:

~~~text
GeodesicDirectResult:
    position
    finalAzimuth

GeodesicInverseResult:
    distance
    initialAzimuth
    finalAzimuth
~~~

The direct result's `position` and inverse result's `distance` describe
their respective primary outputs without leaking algorithm terminology.
`initialAzimuth/finalAzimuth` are directionally explicit. The shared
`finalAzimuth` spelling carries the same documented endpoint-forward-azimuth
semantics in both result types.

Classification: **consistent**.

#### B9 type, enum, and alias naming

Public type names consistently identify the represented domain object:
coordinate values use the `Coordinate` suffix, prepared computational
objects use domain names such as `TransverseMercator`, `PseudoMercator`,
`UtmProjection`, `TopocentricFrame`, and `Geodesic`, and result values
use the `Result` suffix where they package multiple operation outputs.

`Helmert7<T, convention>` names the seven-parameter representation, while
`PositionVectorHelmert<T>` and `CoordinateFrameHelmert<T>` provide
semantically named public aliases. `HelmertConvention.positionVector` and
`.coordinateFrame` match those aliases.

`UtmHemisphere.north/south` and `UtmZone` use domain vocabulary without
encoding representation details.

Classification: **consistent**.

**B6-B9 conclusion:** no additional rename candidate is identified. The only
current V1-B production-API correction candidate remains the one-shot UTM
argument order from B5.


### B10 — conditional / validation-only public surface

Status: **reviewed — visibility issue identified**

`geodesy.projection.transverse_mercator` conditionally declares
`TransverseMercatorNewtonTrace` when `GeodesyTmNewtonValidation` is enabled.
Inside the same version block, `TransverseMercator<T>` temporarily switches
to `public:` and exposes:

~~~d
bool tryReverseNewtonTrace(
    const ProjectedCoordinate!T source,
    out GeographicCoordinate!T result,
    out TransverseMercatorNewtonTrace trace) const
~~~

The trace records implementation-validation details such as iteration count,
convergence residual, maximum correction, intermediate `tauPrime`, and
Newton applicability. The surrounding instrumented kernels remain private.

**Classification:** **conditional/debug-only surface requiring a visibility
decision**. This is not merely a naming concern: enabling a validation version
changes the externally visible API of an aggregate-exported production module.
The trace also exposes algorithm/validation details that are not part of the
normal Transverse Mercator semantic contract.

V1-B records the names as internally coherent for their validation purpose,
but does not accept them as v1 public API. V1-F must decide the module /
visibility boundary and ensure validation instrumentation does not
accidentally enlarge the supported production surface.

### V1-B summary

~~~text
B1  checked / throwing pair names                  REVIEWED
B2  construction and factory vocabulary            REVIEWED
B3  coordinate component/property vocabulary       PASS
B4  prepared-operation method families             PASS
B5  argument ordering / UFCS                       PASS — correction verified
B6  transformation direction/convention naming     PASS
B7  projection parameter vocabulary                PASS
B8  result/accessor vocabulary                     PASS
B9  type/enum/alias naming                         PASS
B10 conditional/validation-only declarations       1 V1-F visibility issue
~~~

V1-B therefore identifies no general naming redesign. Two items leave this
gate:

1. **Pre-v1 API correction accepted and verified:** the one-shot UTM family
   is reordered from `(ellipsoid, source)` to `(source, ellipsoid)` so ordinary
   calls and UFCS align with the rest of the free conversion/transformation
   API. DMD 2.111 and LDC 1.41 each pass all 22 module unittests, and an
   external consumer using only `import geodesy;` builds and links with both
   compilers while exercising throwing and checked source-first UFCS calls.
2. **V1-F visibility issue:** prevent validation-only Transverse Mercator
   instrumentation from becoming accidental supported public surface.

The absence of throwing geodesic and automatic-UTM-zone convenience
operations remains a V1-D failure-contract decision rather than a naming
defect.






## V1-A inventory basis

The inventory is derived from the production modules publicly re-exported by
`source/geodesy/package.d`, not from the existing prose API document.

Current aggregate modules:

~~~text
geodesy.angle
geodesy.ellipsoid
geodesy.errors
geodesy.geographic
geodesy.geodesic
geodesy.geodetic
geodesy.geocentric
geodesy.topocentric
geodesy.projected
geodesy.scalar
geodesy.conversion
geodesy.projection.factors
geodesy.projection.pseudo_mercator
geodesy.projection.transverse_mercator
geodesy.projection.utm
geodesy.transform.geocentric_translation
geodesy.transform.helmert
~~~

Because D modules can expose declarations without an explicit `public`
keyword, V1-A treats non-private/non-package declarations in these aggregate
modules as candidate public surface. Package/private helpers are excluded.

## Candidate public types

### Core value and error types

~~~text
Angle<T>
Latitude<T>
Longitude<T>
Ellipsoid<T>
GeographicCoordinate<T>
GeodeticCoordinate<T>
GeocentricCoordinate<T>
ProjectedCoordinate<T>
TopocentricCoordinate<T>
TopocentricFrame<T>
GeodesyValueException
~~~

### Transformation types

~~~text
GeocentricTranslation<T>
HelmertConvention
Helmert7<T, convention>
PositionVectorHelmert<T>
CoordinateFrameHelmert<T>
~~~

### Projection types

~~~text
ConformalProjectionFactors<T>
TransverseMercator<T>
PseudoMercator<T>
UtmHemisphere
UtmZone
UtmCoordinate<T>
UtmProjection<T>
~~~

### Geodesic types

~~~text
Geodesic<T>
GeodesicDirectResult<T>
GeodesicInverseResult<T>
~~~

## Candidate aggregate free functions / templates

### Scalar and reference-ellipsoid surface

~~~text
isGeodesyScalar<T>
wgs84<T>()
~~~

### Geographic / geocentric conversion

~~~text
tryGeodeticToGeocentric
geodeticToGeocentric
tryGeocentricToGeodetic
geocentricToGeodetic
~~~

### Geocentric translation

~~~text
tryApplyGeocentricTranslation
applyGeocentricTranslation
~~~

### Helmert transformation

~~~text
tryApplyPositionVectorHelmert
applyPositionVectorHelmert
tryApplyCoordinateFrameHelmert
applyCoordinateFrameHelmert
toCoordinateFrame
toPositionVector
~~~

### UTM convenience surface

~~~text
tryStandardUtmZone
tryForwardUtm
forwardUtm
tryReverseUtm
reverseUtm
~~~

Projection and geodesic operational APIs are primarily methods on their
prepared public types and are inventoried below.

## Candidate type-member families

This section records member families for later semantic audit. It intentionally
does not yet declare them frozen.

### Angle / latitude / longitude

~~~text
Angle:
    tryFromRadians / fromRadians
    tryFromDegrees / fromDegrees
    radians
    degrees

Latitude:
    tryFromRadians / fromRadians
    tryFromDegrees / fromDegrees
    radians
    degrees
    asAngle

Longitude:
    tryFromRadians / fromRadians
    tryFromDegrees / fromDegrees
    radians
    degrees
    asAngle
    normalized
~~~

### Ellipsoid

~~~text
isValid
tryFromFlattening / fromFlattening
tryFromInverseFlattening / fromInverseFlattening
tryFromAxes / fromAxes
trySphere / sphere
semiMajorAxis
flattening
semiMinorAxis
inverseFlattening
firstEccentricitySquared
secondEccentricitySquared
thirdFlattening
~~~

### Coordinate values

~~~text
GeographicCoordinate:
    fromComponents
    latitude
    longitude

GeodeticCoordinate:
    tryFromComponents / fromComponents
    latitude
    longitude
    ellipsoidalHeight

GeocentricCoordinate:
    tryFromComponents / fromComponents
    x / y / z

ProjectedCoordinate:
    tryFromComponents / fromComponents
    easting / northing

TopocentricCoordinate:
    tryFromComponents / fromComponents
    east / north / up

UtmCoordinate:
    isValid
    tryFromComponents / fromComponents
    zone
    hemisphere
    projected
    easting
    northing
~~~

Exact signatures and default-state semantics remain subjects of V1-B through
V1-E.

### Topocentric frame

~~~text
isValid
ellipsoid
tryFromGeodeticOrigin / fromGeodeticOrigin
tryFromGeocentricOrigin / fromGeocentricOrigin
tryGeocentricToTopocentric / geocentricToTopocentric
tryTopocentricToGeocentric / topocentricToGeocentric
tryGeodeticToTopocentric / geodeticToTopocentric
tryTopocentricToGeodetic / topocentricToGeodetic
~~~

### Projection factors

`ConformalProjectionFactors<T>` is a public result value type. Its component
factory is not part of the aggregate public surface; externally produced
instances are obtained from projection factor operations. Public accessors:

~~~text
meridianConvergence
pointScale
~~~

### Transverse Mercator

~~~text
isValid
tryFromParameters / fromParameters
prepared parameter properties
tryForward / forward
tryReverse / reverse
tryForwardFactors / forwardFactors
tryReverseFactors / reverseFactors
~~~

### Pseudo-Mercator

~~~text
isValid
tryFromParameters / fromParameters
ellipsoid
longitudeOfNaturalOrigin
falseEasting
falseNorthing
tryForward / forward
tryReverse / reverse
~~~

### UTM

~~~text
UtmHemisphere:
    north
    south

UtmZone:
    isValid
    tryFromNumber / fromNumber
    number
    centralMeridianDegrees

UtmProjection:
    isValid
    checked / throwing construction
    prepared parameter properties
    tryForward / forward
    tryReverse / reverse
    tryForwardFactors / forwardFactors
    tryReverseFactors / reverseFactors
~~~

### Geodesics

~~~text
Geodesic:
    isValid
    isSphere
    tryFromEllipsoid / fromEllipsoid
    ellipsoid
    tryDirect
    tryInverse

GeodesicDirectResult:
    position
    finalAzimuth

GeodesicInverseResult:
    distance
    initialAzimuth
    finalAzimuth
~~~

### Static transformations

~~~text
GeocentricTranslation:
    checked / throwing construction
    deltaX / deltaY / deltaZ
    inverse

Helmert7:
    tryFromCanonical / fromCanonical
    tryFromArcSecondsAndPpm / fromArcSecondsAndPpm
    translationX / translationY / translationZ
    rotationX / rotationY / rotationZ
    scaleDifference
    scaleFactor
~~~

## V1-A access-control findings

The source inspection also distinguishes implementation declarations that may
look public in a textual scan but are not aggregate API:

- `angleFromRadiansUnchecked` is `package(geodesy)`;
- raw EPSG 9602 working kernels and `Epsg9602WorkingScalar` are
  `package(geodesy)`;
- projection working-scalar templates, numerical helpers, trace structures,
  series constants, and reference-case structures are private or occur inside
  private sections;
- unchecked coordinate factories occur in private sections where present.

These declarations are excluded from the candidate v1 surface.

No separate public declaration was accepted merely because it appeared in a
production source file; module/section access control remains authoritative.

## Immediate V1-A documentation discrepancy

The existing `docs/API.md` top-level “Public value types” list is not a
complete inventory of the aggregate surface. In particular, the source-derived
candidate inventory also includes public geographic/projected, projection,
UTM, and geodesic types documented elsewhere or omitted from that summary.

This is recorded as an audit finding only. V1-H will reconcile documentation
after the candidate API has passed the semantic gates; V1-A must not make prose
documentation authoritative over source.

## V1-A external aggregate compile check

An external DUB consumer using only `import geodesy;` was built against this
audit branch. The check exercised representative construction, conversion,
projection, UTM, topocentric, static transformation, geodesic, and result-value
surface through the aggregate import.

During construction of the consumer, source-signature reconciliation corrected
three assumptions in the audit/test draft without changing production code:

- `TopocentricFrame.fromGeodeticOrigin` takes `(ellipsoid, origin)`;
- `forwardUtm` and `reverseUtm` take the ellipsoid before the source;
- `ConformalProjectionFactors.fromComponents` is not public and is excluded
  from the candidate surface.

Baseline result on the audit commit lineage:

~~~text
internal unittest regression
    DMD 2.111.0: PASS — 22 modules
    LDC 1.41.0: PASS — 22 modules

external aggregate consumer
    DMD 2.111.0: PASS — build and link
    LDC 1.41.0: PASS — build and link
~~~

The check establishes aggregate accessibility for the exercised candidate
surface. It does not freeze the API and does not substitute for the broader
compatibility matrix in V1-I.

## V1-A completion criteria

V1-A may be closed only when:

1. every aggregate-exported production module has been inspected;
2. every candidate public type, enum, alias, free function/template, and
   relevant public member family is accounted for;
3. package/private implementation helpers are distinguished from public
   candidates;
4. accidental exposure is recorded for V1-F rather than silently accepted;
5. the inventory is independently compile-checked from an external
   `import geodesy;` consumer before it becomes the baseline for V1-B.

The compile check in item 5 tests existence and accessibility only. It does
not convert the candidate inventory into an API freeze.

All five V1-A criteria are satisfied. V1-A is closed; V1-B may begin.


### V1-B gate result

Status: **COMPLETE / PASS**

The naming and API-family audit is complete. The only production signature
correction identified by this gate, source-first ordering for the one-shot UTM
family, has been applied and verified with both baseline compilers and an
external aggregate-import UFCS consumer.

~~~text
Internal DMD 2.111          PASS — 22 modules
Internal LDC 1.41.0         PASS — 22 modules
External UFCS consumer DMD  PASS — build + link
External UFCS consumer LDC  PASS — build + link
~~~

The conditional Transverse Mercator Newton-validation surface is not accepted
as normal v1 public API; its visibility/boundary resolution is carried to
V1-F. Missing throwing counterparts identified in B1 remain explicit V1-D
failure-semantics decisions.

No other naming or API-family correction is required by V1-B.


## V1-C — construction, `.init`, and mutability

Status: **COMPLETE / PASS**

Review dimensions:

~~~text
C1  .init semantics for every public value type
C2  factory completeness and invariant preservation
C3  mutability and invariant escape routes
~~~

### C1 — initial-state semantics

The public value types fall into two deliberate groups.

**Naturally meaningful zero/default values**

~~~text
Angle<T>                    0 radians
Latitude<T>                 0 radians
Longitude<T>                0 radians
GeographicCoordinate<T>     (0 latitude, 0 longitude)
GeodeticCoordinate<T>       (0 latitude, 0 longitude, 0 height)
GeocentricCoordinate<T>     (0, 0, 0)
ProjectedCoordinate<T>      (0, 0)
TopocentricCoordinate<T>    (0, 0, 0)
GeocentricTranslation<T>    identity translation
Helmert7<T, convention>     identity transform
GeodesicDirectResult<T>     zero/default result value
GeodesicInverseResult<T>    canonical zero-distance-shaped result value
ConformalProjectionFactors  zero/default storage value
~~~

The coordinate and transformation defaults are legitimate domain values.
Identity defaults for translations and Helmert transforms are particularly
useful and do not violate their representation contracts.

The result/factor structs require a narrower interpretation: their `.init`
values are representable storage values, but they are normally produced as
outputs of successful operations rather than used as evidence that an
operation succeeded. No `isValid` contract currently claims otherwise.

**Intentionally invalid/preparation-required defaults**

~~~text
Ellipsoid<T>
UtmZone
UtmCoordinate<T>       (invalid because UtmZone.init is invalid)
TopocentricFrame<T>
Geodesic<T>
TransverseMercator<T>
PseudoMercator<T>
UtmProjection<T>
~~~

These types require parameters or preparation before they can represent the
supported operation/domain state. Their validity checks reject `.init`.
`UtmHemisphere.init == UtmHemisphere.north` does not make
`UtmCoordinate.init` or `UtmProjection.init` valid because their embedded
`UtmZone.init` is invalid (and prepared projection state is additionally
invalid).

This composition is sound: the enum default is a legitimate hemisphere while
the enclosing type's required zone/preparation state supplies the invalid
sentinel.

**C1 preliminary conclusion:** no contradictory `.init` state is identified.
Result/factor default semantics should nevertheless be checked against their
documentation in V1-H so users do not infer an operation-success guarantee
from a default-constructed output value.

### C2/C3 — construction and invariant preservation

Public representation fields reviewed so far are private. Construction of
validated values uses static factories or private/package unchecked helpers;
public properties are read-only accessors. Prepared objects expose
`isValid` and do not expose public setters for their parameter or derived
state.

Consequently, no direct post-construction mutation path has yet been found
that can violate a validated invariant.

Further C2 work must still verify every public factory's failure behavior,
especially whether failed `tryFrom...` calls leave their `out` result in a
well-defined invalid/default state. Detailed checked/throwing failure policy
is then owned by V1-D.


### C2 — factory invariant preservation and `out` semantics

Status: **reviewed**

All reviewed public checked factories take their destination as a D `out`
parameter. D initializes an `out` argument to the destination type's
`.init` value on function entry. Consequently, early validation failures
leave the caller-visible result at `.init` even when the variable held a
previously constructed value before the call.

The implementations fall into two safe patterns:

1. validate all input, then assign the public result once; or
2. build and validate a local `candidate`, then assign the public result
   only after all preparation succeeds.

The second pattern is used by the more complex prepared objects such as
`TopocentricFrame`, `TransverseMercator`, `PseudoMercator`, and
`UtmProjection`. It prevents partially prepared state from escaping.

`Geodesic.tryFromEllipsoid` is structurally different: it explicitly resets
`result = Geodesic.init`, then prepares directly into `result` and finally
returns `result.isValid`. If a late derived-state validity check were to fail,
the caller could therefore receive a partially populated but invalid
`Geodesic` rather than exact `.init`. This does not violate the current
boolean-success contract, but it is inconsistent with the stronger
failure-result behavior naturally provided by the other factories.

**C2 finding:** before v1, decide whether checked construction guarantees
exact `.init` on every failure. If that stronger family contract is adopted,
`Geodesic.tryFromEllipsoid` should prepare a local candidate and assign
`result` only after `candidate.isValid` succeeds. The change is
implementation-only for successful calls but makes failure-state semantics
uniform and testable.

### C3 — mutability and invariant escape routes

Status: **reviewed / PASS**

The reviewed public value types keep representation state private and expose
read-only properties. Validated/prepared state cannot be mutated through
public field assignment or setters after construction. Public operations
return new values or write separate `out` results rather than mutating the
receiver.

No public invariant escape route has been identified.



### V1-C gate result

Status: **COMPLETE / PASS**

~~~text
C1  .init semantics                         PASS
C2  factory completeness/invariant safety   PASS
C3  mutability / invariant escape routes    PASS
~~~

The public construction model is coherent:

- value types with meaningful zero/default semantics retain useful `.init`
  values;
- preparation-required types use an invalid `.init` state guarded by
  `isValid`;
- representation state is private and exposed through read-only accessors;
- validated objects cannot be invalidated through public post-construction
  mutation;
- checked `tryFrom...` factories use D `out` semantics and either
  validate-then-assign or candidate-then-commit construction.

For the v1 construction family, a failed checked construction leaves the
caller-visible `out` result in that type's `.init` state. This is a
semantic state guarantee, not necessarily an equality expression:
NaN-bearing representations such as `Geodesic.init` cannot in general be
validated with `result == T.init` because IEEE NaN is not equal to itself.

During this gate, `Geodesic.tryFromEllipsoid` was aligned with the common
candidate-then-commit pattern so late preparation failure cannot expose a
partially populated invalid solver. A regression test verifies that a
previously valid solver becomes publicly invalid/default again after failed
checked construction.

Validation after the correction:

~~~text
DMD 2.111  PASS — 22 modules
LDC 1.41   PASS — 22 modules
~~~

No further construction, `.init`, or mutability correction is required by
V1-C.


## V1-D — failure and checked/throwing semantics

Status: **COMPLETE / PASS**

Review dimensions:

~~~text
D1  checked / throwing operation pairs
D2  checked-only operations and whether a throwing peer is semantically useful
D3  failure-result state and output atomicity
D4  exception type and failure-category consistency
D5  receiver-invalid vs input-invalid behavior
~~~

### D1 — checked/throwing family inventory

The dominant public operation convention is coherent:

~~~text
tryX(..., out result)  -> bool, nothrow, result channel
X(...)                 -> value or exception
~~~

This pairing is present for validated construction, coordinate conversion,
topocentric conversion, Transverse Mercator operations and factors,
Pseudo-Mercator operations, UTM projection operations and factors, one-shot
UTM operations, geocentric translation, and Helmert application.

Two public checked-only families remain for explicit review:

~~~text
Geodesic.tryDirect / Geodesic.tryInverse
tryStandardUtmZone
~~~

### D2 — preliminary semantic distinction

These two cases are not automatically equivalent.

`Geodesic.tryDirect` and `tryInverse` are ordinary solver operations on a
prepared receiver and return a single result object. Their shape closely
matches the projection/conversion families that already provide both checked
and throwing forms. The absence of `direct` / `inverse` is therefore a
candidate API-family asymmetry.

`tryStandardUtmZone`, in contrast, is a domain-selection query with two
outputs and an expected negative answer outside the standard UTM latitude
region. Its `false` is naturally interpretable as “no standard UTM zone
exists for this coordinate,” rather than necessarily an exceptional operation
failure. A throwing `standardUtmZone` peer would also require either a new
compound result type or a different return shape because the checked form has
two outputs. This is therefore a semantic specialization, not yet evidence of
a missing API.

Detailed decisions follow after D3-D5.


### D3-D5 — failure-state, exception, and invalid-state semantics

Status: **reviewed**

**D3 output atomicity:** PASS. Public checked operations use D `out`
destinations, so caller-visible outputs are reset to their type's `.init`
state on entry. Nested checked operations preserve that behavior. Operations
that require multi-step preparation use local intermediates/candidates before
committing the final result. No public operation was found that exposes a
partially successful output after returning `false`.

**D4 exception consistency:** PASS. Throwing convenience wrappers consistently
translate checked-operation failure to `GeodesyValueException`. They do not
introduce a second public failure taxonomy for domain/preparation/numeric
failure.

**D5 invalid receiver vs invalid input:** PASS. Prepared-operation methods
treat an invalid receiver as checked failure (`false`) and their throwing
peers as `GeodesyValueException`. Domain rejection and non-representable
numeric results use the same public channels. Error strings may describe the
combined causes; callers that need branchable failure handling use the checked
form.

### D2 decision

`tryStandardUtmZone` remains intentionally checked-only. Its negative result
is a normal domain query outcome outside the standard UTM latitude region,
and its two-output shape does not naturally map to the library's value-returning
throwing-wrapper convention. No `standardUtmZone` peer is required for v1.

`Geodesic.tryDirect` and `Geodesic.tryInverse` are different: they are
ordinary operations on a prepared solver, each has a single public result
type, and their failure channels match the projection/conversion families.
For API-family consistency, v1 should add:

~~~d
GeodesicDirectResult!T direct(...);
GeodesicInverseResult!T inverse(...);
~~~

Each is a thin throwing convenience wrapper over the existing checked method
and throws `GeodesyValueException` when the solver is invalid, an input is
outside the supported finite domain, or a finite representable result cannot
be produced. No new failure category or algorithm is introduced.


### V1-D gate result

Status: **COMPLETE / PASS**

~~~text
D1  checked / throwing operation pairs      PASS
D2  checked-only semantic exceptions        PASS
D3  failure-result/output atomicity         PASS
D4  exception type consistency              PASS
D5  invalid receiver/input behavior         PASS
~~~

Accepted v1 decisions:

- `Geodesic.tryDirect` / `tryInverse` now have the throwing peers
  `direct` / `inverse`.
- The throwing peers are thin wrappers over the checked algorithms and throw
  `GeodesyValueException` on checked-operation failure.
- `tryStandardUtmZone` remains intentionally checked-only because `false`
  is a normal domain-query outcome outside the standard UTM latitude region
  and the operation naturally returns two outputs.
- Checked-operation outputs preserve the library-wide D `out` failure-state
  contract.

Validation after the geodesic API-family correction:

~~~text
DMD 2.111  PASS — 22 modules
LDC 1.41   PASS — 22 modules
~~~

No further failure-channel or checked/throwing correction is required by
V1-D.


## V1-E — scalar / unit / canonicalization / domain contracts

Status: **COMPLETE / PASS**

Review dimensions:

~~~text
E1  public scalar policy
E2  angular and linear unit contracts
E3  canonicalization and endpoint representation
E4  mathematical / projection domain boundaries
E5  cross-module contract consistency
~~~

### E1 — scalar policy

The public numerical family consistently constrains template scalar `T` with
`isGeodesyScalar!T`, which accepts exactly the unqualified built-in
floating-point types:

~~~text
float
double
real
~~~

Integral and qualified scalar types are intentionally excluded. Finite-value
validation is centralized internally through `isFiniteGeodesyScalar`.
No public value family with a conflicting scalar policy was identified in the
initial pass.

### E2 — unit model

Angular strong types store radians. Degree factories/accessors are explicit
conversion surfaces. Helmert canonical rotations use `Angle!T`; the
arc-second/ppm factory is explicitly a unit-converting convenience factory.

Linear units are deliberately not encoded in coordinate value types.
Geodetic height, geocentric coordinates, projected coordinates, topocentric
coordinates, ellipsoid axes, translations, and operation offsets must use the
same linear unit within the operation that combines them.

This is coherent for generic geodetic, conversion, projection, and transform
operations.

**UTM requires separate review.** `UtmProjection` documents a
“terrestrial-metre ellipsoid policy” and accepts only

~~~text
6,000,000 <= semi-major axis <= 7,000,000
0 < flattening <= 0.01
~~~

This numerically selects metre-scale terrestrial ellipsoids, but the type
system contains no unit metadata and therefore cannot establish that the
linear unit is actually metres. Before v1, this must be classified explicitly
as either an intentional numeric policy/precondition or a misleading unit
claim. No change is accepted yet.

### E3 — angular canonicalization

The public `Longitude!T` value domain is the closed interval
`[-pi,+pi]`; both antimeridian endpoint representations are valid values.
`Longitude.normalized` provides the unique half-open representation
`[-pi,+pi)`.

Operations that require unique longitude identity canonicalize explicitly
rather than silently narrowing the public value type. This distinction is
used consistently by UTM zone selection, geodesic mathematics, and bounded
projection seam handling.

General `Angle!T` is finite but intentionally unbounded. Latitude is the
closed geodetic interval `[-pi/2,+pi/2]`.

### E4 — domain contracts identified for detailed review

Current explicit public operation domains include:

~~~text
Geodesic prepared ellipsoid        0 <= f <= 0.01
Transverse Mercator ellipsoid      0 <= f <= 0.01
Transverse Mercator forward        |delta longitude| <= 60 degrees
Pseudo-Mercator forward latitude   [-88,+88] degrees
Automatic standard UTM latitude    [-80,+84) degrees
UTM prepared ellipsoid             metre-scale numeric a policy,
                                   0 < f <= 0.01
~~~

The next pass checks endpoint inclusivity, forward/reverse symmetry,
sphere acceptance, and whether these restrictions are mathematical,
algorithmic, or policy constraints consistently documented across modules.


### E4/E5 — domain and UTM unit-policy review

The identified boundaries separate cleanly into definition/policy and bounded
algorithm support.

#### Generic ellipsoidal operations

`Geodesic` and `TransverseMercator` accept the inclusive support profile

~~~text
0 <= f <= 0.01
~~~

so a sphere (`f == 0`) is a supported generic ellipsoid. The upper
flattening bound is an explicit library/algorithm support profile rather than
a property of `Ellipsoid!T` itself.

#### Transverse Mercator

The public bounded forward sheet accepts non-polar points through the
inclusive nominal boundary

~~~text
abs(delta longitude) <= 60 degrees
~~~

with only representation-level slack used to classify values that round
around the exact boundary. That slack does not widen the documented
mathematical domain. Reverse performs representation-aware boundary handling
against the same bounded sheet.

#### Pseudo-Mercator

The accepted forward latitude domain is explicitly inclusive:

~~~text
-88 degrees <= latitude <= +88 degrees
~~~

The bounded reverse representation is prepared from those same endpoint
latitudes. Longitude seam handling uses the principal half-open sheet while
preserving the public `Longitude` type's broader closed endpoint
representation.

#### Automatic versus explicit UTM

Automatic standard-zone selection intentionally accepts

~~~text
-80 degrees <= latitude < +84 degrees
~~~

so `-80` is included and `+84` is excluded. This is a policy boundary of
automatic standard UTM selection, not the mathematical domain of the prepared
Transverse Mercator operation.

An explicitly prepared `UtmProjection` does not reapply that automatic
latitude band. Existing tests deliberately demonstrate that an explicit zone
can forward/reverse a point at exactly +84 degrees when the bounded underlying
TM operation accepts it. This separation is coherent.

#### UTM metre convention

The UTM implementation fixes

~~~text
false easting          500000
southern false northing 10000000
~~~

These constants are metre-valued UTM parameters. Because geodesy-d's generic
coordinate and ellipsoid types intentionally carry no runtime unit metadata,
`UtmProjection` cannot infer or convert a caller's linear unit. Accepting an
ellipsoid expressed in kilometres or feet while applying these fixed numeric
offsets would silently mix units.

The current UTM precondition

~~~text
6000000 <= semi-major axis <= 7000000
0 < f <= 0.01
~~~

is therefore accepted for v1 as a deliberate **terrestrial metre-scale input
policy**, not as general unit detection. It rejects obvious unit mismatch and
restricts the convenience abstraction to the conventional terrestrial UTM
use case.

The documentation should continue to state that the ellipsoid axes supplied
to `UtmProjection` are numerically in metres. The numeric range is a guard
for that API contract, not proof of dimensional metadata.

UTM also intentionally excludes `f == 0`: the generic Transverse Mercator
implementation supports a sphere, while the UTM convenience policy accepts
supported oblate terrestrial ellipsoids only. Existing tests enforce this
distinction.

No source change is required by this review.


### E5 — cross-module canonicalization and scalar closure

Final representation-sensitive review:

- `Longitude!T` deliberately preserves both legal antimeridian spellings
  (`-pi` and `+pi`). `normalized` maps the latter to the unique
  half-open `[-pi,+pi)` representation. UTM automatic-zone selection uses
  this normalization explicitly.
- Geodesic mathematics canonicalizes equivalent antimeridian inputs internally
  and has regression coverage showing `+180` and `-180` behave
  equivalently.
- Geodesic result conventions canonicalize mathematically zero coincidence
  outputs to positive zero, with explicit `signbit` regression tests.
- Geographic pole longitude is treated as geometrically degenerate where the
  operation requires a canonical output. Transverse Mercator reverse uses its
  natural-origin longitude for the represented pole; factor operations use
  their documented canonical pole convention.
- Topocentric frame preparation intentionally differs: when a geodetic pole
  origin is supplied, its explicit longitude defines the local frame
  orientation and is therefore preserved rather than normalized away. This is
  a semantic distinction, not a canonicalization inconsistency.
- `float` public operations commonly promote internal working arithmetic to
  `double`; `double` and `real` retain their corresponding supported
  working paths where required. Public results remain scalar `T`.
- All principal public families instantiate for `real`; no v1 API was found
  that advertises the shared scalar policy while structurally excluding
  `real`.

These rules are mutually compatible: public value representation is preserved
unless an operation has a documented need for a unique representative.

### V1-E gate result

Status: **COMPLETE / PASS**

~~~text
E1  public scalar policy                         PASS
E2  angular and linear unit contracts            PASS
E3  canonicalization and endpoint representation PASS
E4  mathematical / projection domain boundaries  PASS
E5  cross-module contract consistency            PASS
~~~

No source correction is required by V1-E.

Accepted v1 contract distinctions include:

- generic linear coordinates are unit-agnostic but require operation-local
  unit consistency;
- UTM is deliberately a metre-scale convenience API because its fixed false
  offsets are metre-valued;
- generic geodesic/TM support includes spheres, while UTM convenience policy
  is restricted to supported oblate terrestrial ellipsoids;
- automatic UTM latitude policy is distinct from explicit-zone TM domain;
- closed public longitude representation and operation-specific half-open
  canonicalization coexist deliberately;
- signed-zero and pole conventions are operation semantics where geometric
  degeneracy requires a unique result.
