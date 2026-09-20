# geodesy-d

`geodesy-d` is a dependency-light pure-D library for geodetic mathematics.

It provides strong angular and coordinate types, reference ellipsoids,
geographic/geocentric conversion, and static datum/frame transformations
without requiring the PROJ runtime.

The library deliberately focuses on bounded mathematical operations. It is not
a CRS database or a replacement for the complete PROJ ecosystem.

## Status

The `v0.2.0` release line provides:

- strong `Angle`, `Latitude`, and `Longitude` value types;
- reference ellipsoids;
- geodetic coordinates;
- geocentric/ECEF coordinates;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1033 Position Vector 7-parameter Helmert transformations;
- EPSG 1032 Coordinate Frame 7-parameter Helmert transformations;
- bounded generic `TransverseMercator!T`;
- Universal Transverse Mercator zone and hemisphere policy;
- prepared `UtmProjection!T`;
- tagged `UtmCoordinate!T`;
- automatic standard-zone UTM forward projection;
- explicit-zone and tagged reverse UTM operations;
- prepared direct/inverse ellipsoidal `Geodesic!T` solver;
- EPSG 9836 geocentric/topocentric East-North-Up conversion;
- EPSG 9837 geodetic/topocentric East-North-Up conversion through prepared
  `TopocentricFrame!T`.

The public numerical operations are independently validated against appropriate
authoritative references and mature external implementations including
EPSG/IOGP reference material, GeographicLib, and PROJ.

## Installation

Add `geodesy-d` to a DUB project:

~~~sh
dub add geodesy-d
~~~

Then import the package-level public API:

~~~d
import geodesy;
~~~

DMD and LDC are supported.

The minimum supported D frontend version is:

~~~text
2.111.0
~~~

## Basic usage

~~~d
import geodesy;

void main()
{
    const latitude =
        Latitude!double.fromDegrees(48.20849);

    const longitude =
        Longitude!double.fromDegrees(16.37208);

    const position =
        GeodeticCoordinate!double.fromComponents(
            latitude,
            longitude,
            171.0
        );

    const earth = wgs84!double();

    const ecef =
        geodeticToGeocentric(position, earth);

    const roundTrip =
        geocentricToGeodetic(ecef, earth);

    assert(roundTrip.latitude.degrees > 48.0);
    assert(roundTrip.longitude.degrees > 16.0);
}
~~~

The ellipsoid axes, ellipsoidal height, and geocentric Cartesian coordinates
must use the same linear unit. Metres are the normal geodetic convention and
the unit used by the supplied WGS 84 reference ellipsoid.

## Core value types

### Angles

~~~text
Angle!T
Latitude!T
Longitude!T
~~~

Angles are stored canonically in radians.

Construction is explicit:

~~~d
auto angle = Angle!double.fromDegrees(45.0);
auto latitude = Latitude!double.fromDegrees(48.0);
auto longitude = Longitude!double.fromDegrees(16.0);
~~~

`Latitude` enforces the geodetic latitude domain.

`Longitude` accepts the closed interval `[-180°, +180°]` and provides
`normalized` for the unique half-open representation.

### Ellipsoids

~~~text
Ellipsoid!T
~~~

Supported construction forms include:

- semi-major axis and flattening;
- semi-major axis and inverse flattening;
- semi-major and semi-minor axes;
- spheres.

WGS 84 is provided through:

~~~d
auto earth = wgs84!double();
~~~

`Ellipsoid.init` is intentionally invalid. Accidental default construction must
not silently create a plausible but physically meaningless Earth model.

### Coordinates

~~~text
GeodeticCoordinate!T
GeocentricCoordinate!T
TopocentricCoordinate!T
~~~

A geodetic coordinate contains:

~~~text
latitude
longitude
ellipsoidal height
~~~

A geocentric coordinate contains Cartesian:

~~~text
X
Y
Z
~~~

No datum or CRS identifier is embedded in either coordinate type.

## Geographic/geocentric conversion

`geodesy-d` implements EPSG method 9602 in both directions:

~~~text
tryGeodeticToGeocentric
geodeticToGeocentric

tryGeocentricToGeodetic
geocentricToGeodetic
~~~

The `try...` operations are suitable for non-throwing numerical code.

The throwing convenience operations raise `GeodesyValueException` when their
operation cannot produce a valid result.

The geocentre `(0, 0, 0)` is representable as a geocentric coordinate but has
no unique inverse geodetic coordinate.

## Topocentric East/North/Up coordinates

The accepted topocentric API provides:

~~~text
TopocentricCoordinate!T
TopocentricFrame!T
~~~

A prepared frame may use either a geodetic or geocentric origin and implements
EPSG 9836 and EPSG 9837 in both directions.

The local axes are:

~~~text
East
North
Up
~~~

where `Up` is the ellipsoid-normal direction at the origin.

The operation supports `float`, `double`, and platform `real`. Public `float`
uses promoted working precision internally where Earth-scale ECEF
intermediates would otherwise destroy local information.

The full TOPO-A through TOPO-G validation program is recorded in
`docs/TOPOCENTRIC_VALIDATION_PLAN.md`.

## Geocentric translation

EPSG method 1031 is represented by:

~~~text
GeocentricTranslation!T
~~~

and applied with:

~~~text
tryApplyGeocentricTranslation
applyGeocentricTranslation
~~~

`GeocentricTranslation.init` is the identity transformation.

Its exact inverse negates the three translation parameters.

## Helmert transformations

The public API supports both EPSG static 7-parameter Helmert conventions:

~~~text
EPSG 1033  Position Vector
EPSG 1032  Coordinate Frame
~~~

Public types include:

~~~text
Helmert7
PositionVectorHelmert
CoordinateFrameHelmert
HelmertConvention
~~~

The convention is compile-time explicit; there is deliberately no default
Helmert convention.

Canonical rotation values are `Angle!T` values in radians.

The EPSG-style construction interface accepts rotations in arc-seconds and
scale difference in parts per million.

No 7-parameter inverse shortcut is currently exposed.

## Scalar model

The public geodetic scalar types are:

~~~text
float
double
real
~~~

`double` is the normative reference precision.

`float` is explicitly reduced precision.

D's `real` type is supported, but its precision is platform-dependent.

## Error model

Checked construction and numerical APIs generally use two layers.

Non-throwing construction:

~~~text
tryFrom...
try...
~~~

These operations are designed for numerical code and, where applicable, retain:

~~~text
pure
nothrow
@safe
@nogc
~~~

Throwing convenience factories and operations provide a simpler interface and
use `GeodesyValueException` for invalid values or failed operations.

## Numerical policy

There is no library-wide epsilon controlling numerical decisions.

Tolerance and convergence requirements belong to the individual algorithm.

Non-trivial geodetic operations are validated using combinations of:

- analytical cases;
- published EPSG/IOGP reference vectors;
- forward/inverse round trips;
- boundary and singular cases;
- randomized comparison against independent implementations;
- regression cases for discovered numerical defects.

PROJ is used as an independent validation oracle only. It is not a runtime
dependency.

## Validation

The v0.2.0 release is validated with:

- DMD and LDC;
- the public API compile contract;
- published EPSG/IOGP reference vectors;
- GeographicLib 2.7 reference and differential validation;
- PROJ 9.7.1 differential validation;
- multi-platform validation matrices for Transverse Mercator, UTM, and
  ellipsoidal geodesics.

The original v0.1 extended fixed-seed differential suite passed:

~~~text
2037 / 2037 scalar comparisons
~~~

against PROJ 9.7.1 and remains part of the regression history.

PROJ and GeographicLib remain independent validation infrastructure rather
than runtime dependencies of the library.

## Responsibility boundary

`geodesy-d` owns mathematical operations whose semantics depend on the Earth,
a reference ellipsoid, geographic/geocentric coordinates, reference-frame
transformations, or map-projection mathematics.

It deliberately does not own:

~~~text
general Euclidean geometry / polygon topology     -> geo-d
MGRS / Geohash / Open Location Code              -> locationref-d
EPSG database / WKT / PROJJSON / grid resources  -> proj-d
~~~

Coordinates do not embed CRS or datum metadata.

`geodesy-d` therefore remains useful independently of a complete CRS engine.

## Ellipsoidal geodesics

`geodesy-d` now provides a prepared `Geodesic!T` solver for direct and inverse
surface geodesics on spheres and supported oblate ellipsoids:

~~~text
a > 0
0 <= f <= 0.01
~~~

The public surface includes:

~~~d
Geodesic!T
GeodesicDirectResult!T
GeodesicInverseResult!T

tryDirect(...)
tryInverse(...)
~~~

for `float`, `double`, and platform `real`.

The implementation follows the Karney geodesic algorithm family and does not
require GeographicLib or PROJ at runtime. GeographicLib 2.7
`GeodesicExact` is used as an independent numerical oracle in the research
validation harnesses.

Public geodesic semantics canonicalize longitude and azimuth to `[-pi,+pi)`.
Coincident inverse endpoints return canonical `(+0,+0,+0)` for distance,
initial azimuth, and final azimuth.

The first public slice intentionally does not include `GeodesicLine`, reduced
length, geodesic scales, geodesic area, polygon accumulation, longitude
unrolling, or prolate ellipsoids. See ADR-0008 and the geodesic validation plan
for the exact support and acceptance contract.

## Future scope

Extended geodesic operations remain future work and should be added only when
a concrete consumer justifies them.

Broader CRS discovery, authority databases, UPS/MGRS policy, transformation
grids, and coordinate-reference metadata remain outside the current projection
layer and retain their documented cross-library responsibility boundaries.

## Building

Run the test suite with DMD:

~~~sh
dub test --compiler=dmd --force
~~~

Run it with LDC:

~~~sh
dub test --compiler=ldc2 --force
~~~

Build the release configuration:

~~~sh
dub build --build=release --compiler=ldc2 --force
~~~

## Documentation

The public API baseline is documented in:

~~~text
docs/API.md
~~~

Numerical validation policy and evidence are documented in:

~~~text
docs/VALIDATION.md
docs/V0_1_READINESS.md
docs/REFERENCES.md
docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md
docs/UTM_VALIDATION_PLAN.md
docs/GEODESIC_VALIDATION_PLAN.md
~~~

Operation-specific documentation is available under:

~~~text
docs/operations/
~~~

Architecture decisions are maintained under:

~~~text
docs/adr/
~~~

The more detailed development and architecture overview remains in:

~~~text
docs/README.md
~~~

When developed inside `d-geospatial-workspace`, current shared workspace
context is available locally under `.workspace/`.

That directory is not part of the `geodesy-d` repository or published DUB
package.

## License

`geodesy-d` is licensed under the MIT License.

See `LICENSE`.
