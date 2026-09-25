# v1 public API audit

Status: **V1-A active — inventory only**

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

The coordinate types expose their accepted construction/property families,
including strong geographic components and finite linear components. Exact
signatures and default-state semantics remain subjects of V1-B through V1-E.

~~~text
GeographicCoordinate
GeodeticCoordinate
GeocentricCoordinate
ProjectedCoordinate
TopocentricCoordinate
UtmCoordinate
~~~

### Topocentric frame

~~~text
isValid
tryFromGeodeticOrigin / fromGeodeticOrigin
tryFromGeocentricOrigin / fromGeocentricOrigin
tryGeocentricToTopocentric / geocentricToTopocentric
tryTopocentricToGeocentric / topocentricToGeocentric
tryGeodeticToTopocentric / geodeticToTopocentric
tryTopocentricToGeodetic / topocentricToGeodetic
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
UtmZone:
    checked / throwing construction and zone value access

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
    tryFromEllipsoid / fromEllipsoid
    ellipsoid
    tryDirect
    tryInverse

GeodesicDirectResult:
    result construction/accessors for position and final azimuth

GeodesicInverseResult:
    result construction/accessors for distance, initial azimuth, final azimuth
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

## Immediate V1-A documentation discrepancy

The existing `docs/API.md` top-level “Public value types” list is not a
complete inventory of the aggregate surface. In particular, the source-derived
candidate inventory also includes public geographic/projected, projection,
UTM, and geodesic types documented elsewhere or omitted from that summary.

This is recorded as an audit finding only. V1-H will reconcile documentation
after the candidate API has passed the semantic gates; V1-A must not make prose
documentation authoritative over source.

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

The compile check in item 5 should test existence and accessibility only. It
must not convert the candidate inventory into an API freeze.
