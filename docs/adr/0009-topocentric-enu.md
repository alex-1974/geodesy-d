# ADR-0009: Topocentric East/North/Up coordinates

- Status: Proposed
- Date: 2026-09-20
- Applies to: EPSG 9836 and EPSG 9837 topocentric coordinate conversions
- Depends on: ADR-0001, ADR-0002, ADR-0005
- Supersedes: nothing

## Context

The `v1.0.0` roadmap admits topocentric East/North/Up coordinates as a P0
capability.

`geodesy-d` already provides:

~~~text
GeodeticCoordinate<T>
        ↕
EPSG 9602
        ↕
GeocentricCoordinate<T>
~~~

The missing bounded operation is a local Cartesian frame tied to an ellipsoid
and a topocentric origin:

~~~text
GeodeticCoordinate<T>             GeocentricCoordinate<T>
        ↕                                  ↕
             TopocentricFrame<T>
                      ↕
             TopocentricCoordinate<T>
                  East / North / Up
~~~

This belongs in `geodesy-d` because construction and orientation of the frame
depend on the reference ellipsoid and on geodetic/geocentric Earth
coordinates.

General Euclidean geometry performed after coordinates have been converted to
the local frame remains outside `geodesy-d`.

## Normative semantics

The normative operation semantics are IOGP Report 373-07-02, EPSG Guidance
Note 7-2, December 2024:

- EPSG method 9836 — Geocentric/topocentric conversions;
- EPSG method 9837 — Geographic/topocentric conversions;
- EPSG method 9602 — Geographic/geocentric conversions, where required by
  9836/9837.

The supported topocentric setting is the ellipsoid-normal setting described by
EPSG:

~~~text
East  = U
North = V
Up    = W
~~~

The axes form a right-handed Cartesian system.

`Up` is the direction through the topocentric origin perpendicular to the
ellipsoid surface. It is not a gravity-vector or vertical-datum direction.

Gravity-based astronomical/local-horizon frames are outside this ADR.

## Decision

Introduce two public domain concepts:

~~~d
TopocentricCoordinate!T
TopocentricFrame!T
~~~

for:

~~~text
T = float | double | real
~~~

### TopocentricCoordinate

`TopocentricCoordinate!T` represents:

~~~text
east
north
up
~~~

All three values use the same linear unit as the ellipsoid and the other
coordinates participating in the operation.

The type carries no:

- CRS identifier;
- datum identifier;
- frame identifier;
- EPSG code;
- unit metadata.

Its default value is:

~~~text
East  = 0
North = 0
Up    = 0
~~~

which is a valid topocentric coordinate and represents the origin when
interpreted in a valid `TopocentricFrame`.

Construction follows the existing checked/throwing value-type pattern:

~~~d
tryFromComponents(...)
fromComponents(...)
~~~

Non-finite components are rejected.

### TopocentricFrame

`TopocentricFrame!T` is a prepared Earth/ellipsoid-dependent operation.

Its default `.init` state is invalid. There is no meaningful identity
topocentric frame independent of an ellipsoid and origin.

The prepared frame caches the topocentric origin and orientation needed for
repeated forward/reverse operations.

The implementation may cache:

- working-precision geocentric origin;
- working-precision origin latitude/longitude;
- sine/cosine orientation terms;
- other derived constants justified by implementation evidence.

Private representation is not part of the public API contract.

## Origin construction

Two public origin forms are admitted because they correspond directly to the
EPSG operation family and to real consumer use.

### Geodetic origin

Prepare a frame from:

~~~text
GeodeticCoordinate<T> origin
Ellipsoid<T> ellipsoid
~~~

Conceptual construction API:

~~~d
TopocentricFrame!T.tryFromGeodeticOrigin(...)
TopocentricFrame!T.fromGeodeticOrigin(...)
~~~

The explicit geodetic latitude and longitude define the frame orientation.

At either geographic pole the explicit origin longitude remains significant:
although all longitudes represent the same surface point at the pole, they
define different East/North orientations around the Up axis.

A geodetic polar origin must therefore retain its supplied longitude for frame
orientation rather than reconstructing longitude from its ECEF representation.

### Geocentric origin

Prepare a frame from:

~~~text
GeocentricCoordinate<T> origin
Ellipsoid<T> ellipsoid
~~~

Conceptual construction API:

~~~d
TopocentricFrame!T.tryFromGeocentricOrigin(...)
TopocentricFrame!T.fromGeocentricOrigin(...)
~~~

EPSG 9836 requires geodetic latitude and longitude of the origin to be derived
from the geocentric origin through the reverse EPSG 9602 conversion.

`geodesy-d` therefore inherits the existing EPSG 9602 reverse semantics for
this constructor.

In particular:

- geocentric `(0, 0, 0)` is rejected because no unique topocentric
  orientation can be derived;
- a non-zero origin on the geocentric rotation axis is accepted;
- on that axis, the existing EPSG 9602 canonical longitude of zero radians
  defines the deterministic East/North orientation;
- other multiply representable interior cases inherit the existing canonical
  EPSG 9602 reverse solution.

The ordinary intended topocentric use remains an origin on or near the
ellipsoid surface. Acceptance of more unusual finite origins does not imply a
stronger physical-use claim.

## EPSG 9836 mathematical decomposition

For geocentric source `(X,Y,Z)`, origin `(X0,Y0,Z0)`, origin geodetic latitude
`phi0`, and origin longitude `lambda0`:

~~~text
dX = X - X0
dY = Y - Y0
dZ = Z - Z0

East =
    -dX sin(lambda0)
    +dY cos(lambda0)

North =
    -dX sin(phi0) cos(lambda0)
    -dY sin(phi0) sin(lambda0)
    +dZ cos(phi0)

Up =
     dX cos(phi0) cos(lambda0)
    +dY cos(phi0) sin(lambda0)
    +dZ sin(phi0)
~~~

This is a translation followed by an orthonormal rotation.

The reverse uses the transpose of the rotation matrix followed by addition of
the geocentric origin.

The implementation should exploit this prepared constant orientation instead
of rebuilding trigonometric state for every point.

## EPSG 9837 decomposition

EPSG explicitly permits geographic/topocentric conversion to be expressed as:

~~~text
geodetic
    ↕ EPSG 9602
geocentric
    ↕ EPSG 9836
topocentric
~~~

This is the semantic decomposition adopted by `geodesy-d`.

It does not require public intermediate coordinate values to be materialized.

An implementation may use equivalent direct EPSG 9837 formulas or shared
working-precision EPSG 9602/9836 kernels when this is required to preserve the
public numerical contract.

The reverse operation is conceptually:

~~~text
topocentric
    ↓ inverse EPSG 9836
working-precision geocentric
    ↓ reverse EPSG 9602
geodetic
~~~

## Operational API

TOPO-A fixes the initial candidate public surface.

The module is:

~~~d
geodesy.topocentric
~~~

The two public domain types are:

~~~d
TopocentricCoordinate!T
TopocentricFrame!T
~~~

### Frame construction

~~~d
static bool tryFromGeodeticOrigin(
    const Ellipsoid!T ellipsoid,
    const GeodeticCoordinate!T origin,
    out TopocentricFrame result)
    pure nothrow @safe @nogc;

static TopocentricFrame fromGeodeticOrigin(
    const Ellipsoid!T ellipsoid,
    const GeodeticCoordinate!T origin)
    @safe;

static bool tryFromGeocentricOrigin(
    const Ellipsoid!T ellipsoid,
    const GeocentricCoordinate!T origin,
    out TopocentricFrame result)
    pure nothrow @safe @nogc;

static TopocentricFrame fromGeocentricOrigin(
    const Ellipsoid!T ellipsoid,
    const GeocentricCoordinate!T origin)
    @safe;
~~~

Public parameter names are compatibility-sensitive.

The parameter order is deliberately:

~~~text
ellipsoid
origin
result
~~~

### Frame introspection

The initial surface exposes only:

~~~d
@property bool isValid() const
    pure nothrow @safe @nogc;

@property Ellipsoid!T ellipsoid() const
    pure nothrow @safe @nogc;
~~~

Public geodetic/geocentric origin properties are deliberately deferred.

They can be added compatibly if a concrete consumer later requires frame-origin
introspection. Deferring them avoids freezing derived public-float and
canonicalization semantics unnecessarily before v1.

### Coordinate conversion

The checked operations are:

~~~d
bool tryGeocentricToTopocentric(
    const GeocentricCoordinate!T source,
    out TopocentricCoordinate!T result) const
    pure nothrow @safe @nogc;

bool tryTopocentricToGeocentric(
    const TopocentricCoordinate!T source,
    out GeocentricCoordinate!T result) const
    pure nothrow @safe @nogc;

bool tryGeodeticToTopocentric(
    const GeodeticCoordinate!T source,
    out TopocentricCoordinate!T result) const
    pure nothrow @safe @nogc;

bool tryTopocentricToGeodetic(
    const TopocentricCoordinate!T source,
    out GeodeticCoordinate!T result) const
    pure nothrow @safe @nogc;
~~~

The corresponding throwing convenience operations are:

~~~d
TopocentricCoordinate!T geocentricToTopocentric(
    const GeocentricCoordinate!T source) const
    @safe;

GeocentricCoordinate!T topocentricToGeocentric(
    const TopocentricCoordinate!T source) const
    @safe;

TopocentricCoordinate!T geodeticToTopocentric(
    const GeodeticCoordinate!T source) const
    @safe;

GeodeticCoordinate!T topocentricToGeodetic(
    const TopocentricCoordinate!T source) const
    @safe;
~~~

The explicit source/target names are intentional.

Generic overloaded `forward`, `reverse`, `transform`, or `inverse` operations
are not part of the initial surface.

The checked numerical path is required to preserve:

~~~text
pure
nothrow
@safe
@nogc
~~~

unless implementation evidence demonstrates that one of those attributes is
not valid for a particular operation.

### Internal EPSG 9602 reuse

EPSG 9837 is semantically composed from EPSG 9602 and EPSG 9836, but public
intermediate coordinate values need not be materialized.

TOPO-A permits a package/private refactor of the existing EPSG 9602 numerical
kernel so topocentric operations can retain working precision across the
composition.

This internal refactor must not alter the existing public EPSG 9602 API or its
validated behavior.

For public `float`, geodetic/topocentric conversion must not narrow an
intermediate Earth-scale ECEF value to binary32 before local subtraction or
before reverse EPSG 9602 processing.

## Scalar and working-precision policy

Public scalar preservation follows the rest of `geodesy-d`.

Initial required working precision:

~~~text
public float  -> working double -> public float
public double -> working double -> public double
public real   -> working real   -> public real
~~~

### Float geographic path

Earth-scale ECEF coordinates are poorly suited to storing small local
differences in binary32.

Near the WGS 84 semi-major axis, adjacent `float` values are separated by
approximately half a metre.

Therefore the public:

~~~text
GeodeticCoordinate<float>
    ->
TopocentricCoordinate<float>
~~~

path must not materialize an intermediate public
`GeocentricCoordinate<float>` before subtracting the origin.

Geodetic-to-topocentric and topocentric-to-geodetic float operations must
retain promoted working precision across the internal EPSG 9602/9836
composition and round only at the public output boundary.

This is a numerical implementation requirement, not a change to the public
scalar type.

### Float geocentric path

A caller-supplied:

~~~text
GeocentricCoordinate<float>
~~~

already contains binary32 quantization at Earth-scale coordinate magnitude.

Promoting those values to double before subtraction prevents further avoidable
loss but cannot reconstruct information already absent from the input.

The validation and public accuracy documentation must distinguish:

1. geographic/geodetic float input evaluated with promoted working precision;
2. caller-supplied Earth-scale geocentric float input.

No final public error envelope is selected by this ADR before validation.

## Ellipsoid domain

Topocentric conversion introduces no new flattening-series approximation.

Construction requires a valid existing `Ellipsoid!T`.

No additional `f <= 0.01` bound is introduced merely because Transverse
Mercator and geodesics use such a bound for their own algorithms.

A sphere remains supported.

The geocentric-origin constructor additionally requires that reverse EPSG 9602
can derive a valid deterministic origin orientation.

## Linear units

`geodesy-d` retains its existing unit policy.

The following quantities must use one consistent linear unit:

~~~text
ellipsoid axes
geodetic ellipsoidal height
geocentric X/Y/Z
topocentric East/North/Up
~~~

Metres are the normal EPSG convention and are used by the published worked
examples, but metres are not hard-coded into the scalar representation.

## Failure semantics

Prepared-frame construction fails when:

- the ellipsoid is invalid;
- a geocentric origin is the exact geocentre;
- derivation of required finite prepared state fails.

Checked coordinate operations fail when:

- the frame is invalid;
- arithmetic produces a non-finite or non-representable public result;
- the underlying EPSG 9602 reverse operation cannot produce a valid result for
  a topocentric-to-geodetic conversion.

Caller-facing invalid data must not be handled by assertions.

## Canonical and pole semantics

A geodetic-origin frame at a pole uses the caller-supplied longitude to define
East/North orientation.

A geocentric-origin frame on the rotation axis uses the existing deterministic
EPSG 9602 axis convention, longitude zero.

Equivalent longitude representations must produce equivalent physical frame
orientations.

Signed IEEE zero is not assigned an independent physical meaning.

Any stronger public zero-canonicalization requirement must be justified by the
validation/API gate rather than arising accidentally from implementation
details.

## Responsibility boundary

`geodesy-d` owns:

- ellipsoid-dependent topocentric frame preparation;
- EPSG 9836 geocentric/topocentric conversion;
- EPSG 9837 geographic/topocentric conversion;
- strong topocentric coordinate representation.

It does not own local Euclidean geometry such as:

- segment operations;
- polygon topology;
- local planar intersection;
- buffering;
- general vector/shape algorithms.

Those belong to `geo-d` or the consumer.

No dependency on `geo-d` is introduced merely to represent ENU coordinates.

## Validation references

Normative semantics:

- IOGP Report 373-07-02, EPSG Guidance Note 7-2, December 2024;
- EPSG method 9836;
- EPSG method 9837;
- EPSG method 9602.

Independent/interoperability references:

- GeographicLib 2.7 `LocalCartesian` / `Geocentric`;
- current stable PROJ `topocentric` and `cart` operations, with the exact
  version recorded by the validation harness.

The published EPSG WGS 84 topocentric worked example is mandatory acceptance
evidence.

## Alternatives considered

### Geodetic-origin-only public construction

Rejected as unnecessarily narrow.

EPSG 9836 itself defines geocentric/topocentric conversion from a geocentric
origin, and supporting this form is a natural consequence of the already
public `GeocentricCoordinate!T` model.

### Generic local Cartesian type shared with geo-d

Rejected.

The frame orientation is Earth/ellipsoid-dependent. Only geometry after
conversion into local Cartesian coordinates is coordinate-system-independent.

### Native-float intermediate ECEF for EPSG 9837

Rejected before implementation.

Earth-scale binary32 ECEF representation can discard the local information the
topocentric operation is intended to preserve.

### Gravity-based local vertical

Outside scope.

The initial capability implements the EPSG ellipsoid-normal setting only.

## Acceptance

TOPO-A — public contract, coordinate model, and canonical semantics — is
complete and PASS as of 2026-09-20.

TOPO-B — published EPSG 9836/9837 vectors and independent analytical rotation
invariants — is complete and PASS as of 2026-09-20.

The TOPO-B evidence is recorded in
`docs/TOPOCENTRIC_VALIDATION_PLAN.md` and the independent probes under
`research/topocentric/`.

This ADR remains `Proposed` until the remaining topocentric validation gates
have demonstrated:

- EPSG 9836 and 9837 semantic conformance;
- the published EPSG worked vector in both applicable forms;
- independent differential agreement with external implementations;
- explicit pole and geocentre behavior;
- accepted float/double/real accuracy contracts;
- compiler/platform compatibility required by the project;
- public API and runtime attribute contracts.

Only then may the ADR be promoted to `Accepted` and the topocentric public
surface be treated as release-ready.
