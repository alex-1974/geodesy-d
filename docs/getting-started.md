# Getting started with geodesy-d

`geodesy-d` is a dependency-light pure-D library for geodetic mathematics.

The supported package-level import is:

```d
import geodesy;
```

Applications should normally use that package module rather than depend on implementation modules.

## Installation

Create or enter a DUB project and add the released package:

```sh
dub init my-geodesy-app
cd my-geodesy-app
dub add geodesy-d
```

Then build with either supported compiler family:

```sh
dub build --compiler=dmd
dub build --compiler=ldc2
```

The minimum supported D frontend version is 2.111.0.

## Minimal geographic/geocentric example

```d
import geodesy;

void main()
{
    const earth = wgs84!double();

    const geographic =
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208),
            171.0
        );

    const ecef =
        geodeticToGeocentric(
            geographic,
            earth
        );

    const roundTrip =
        geocentricToGeodetic(
            ecef,
            earth
        );

    assert(roundTrip.latitude.degrees > 48.0);
    assert(roundTrip.longitude.degrees > 16.0);
}
```

The ellipsoid axes, ellipsoidal height, and geocentric coordinates must use the same linear unit. The supplied WGS 84 ellipsoid is metre-valued.

## Angles and geographic coordinates

```d
import geodesy;

auto latitude =
    Latitude!double.fromDegrees(48.0);

auto longitude =
    Longitude!double.fromDegrees(16.0);

auto coordinate =
    GeographicCoordinate!double.fromComponents(
        latitude,
        longitude
    );
```

Angles are stored canonically in radians. `Latitude` enforces the geodetic latitude domain. `Longitude` accepts the closed public input interval and exposes `normalized` for its unique half-open representation.

## Ellipsoids

```d
import geodesy;

auto earth = wgs84!double();

assert(earth.isValid);
```

`Ellipsoid.init` is intentionally invalid.

General ellipsoid construction supports semi-major axis with flattening, inverse flattening, semi-minor axis, and spheres where the operation family permits them.

## Checked and throwing operations

Many numerical operations have two layers.

Checked form:

```d
import geodesy;

GeocentricCoordinate!double ecef;

const ok =
    tryGeodeticToGeocentric(
        GeodeticCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.0),
            Longitude!double.fromDegrees(16.0),
            200.0
        ),
        wgs84!double(),
        ecef
    );

assert(ok);
```

Throwing convenience form:

```d
auto ecef =
    geodeticToGeocentric(
        coordinate,
        ellipsoid
    );
```

Throwing forms use `GeodesyValueException` when the documented operation cannot produce a valid result.

## Automatic UTM

```d
import geodesy;

const earth = wgs84!double();

const source =
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.20849),
        Longitude!double.fromDegrees(16.37208)
    );

const utm =
    source.forwardUtm(earth);

const roundTrip =
    utm.reverseUtm(earth);
```

Automatic standard UTM selects the standard zone and hemisphere according to the documented UTM policy.

The automatic latitude band is bounded. Explicitly prepared UTM projections are fixed Transverse Mercator projections and do not reapply automatic-zone policy.

## Explicit UTM projection

```d
import geodesy;

const earth = wgs84!double();

const projection =
    UtmProjection!double.fromZone(
        earth,
        UtmZone.fromNumber(33),
        UtmHemisphere.north
    );

const source =
    GeographicCoordinate!double.fromComponents(
        Latitude!double.fromDegrees(48.0),
        Longitude!double.fromDegrees(16.0)
    );

const projected =
    projection.forward(source);

const reversed =
    projection.reverse(projected);
```

Prepared projections should be reused for repeated work in one zone.

## Transverse Mercator

`TransverseMercator!T` represents a bounded generic Transverse Mercator operation.

Its public contract includes an ellipsoid, latitude and longitude of natural origin, scale factor, false easting, false northing, and a bounded longitude-distance domain.

Use UTM when standard UTM policy is wanted; use `TransverseMercator` for an explicitly parameterized projection.

## Pseudo-Mercator

`PseudoMercator!T` implements the bounded EPSG 1024 operation.

The forward latitude domain is intentionally bounded. It is not a generic ellipsoidal Mercator implementation.

## Geocentric translation

```d
import geodesy;

const translation =
    GeocentricTranslation!double(
        1.0,
        2.0,
        3.0
    );
```

The translation parameters use the same linear unit as the geocentric coordinates. `GeocentricTranslation.init` is the identity transformation.

## Helmert transformations

`geodesy-d` supports both static EPSG seven-parameter conventions:

- Position Vector;
- Coordinate Frame.

The convention is explicit in the type/API. There is no implicit default convention.

EPSG-style constructors use arc-seconds for rotations and parts per million for scale difference where documented.

## Topocentric East/North/Up

`TopocentricFrame!T` represents a prepared local East-North-Up frame.

A frame may be prepared from a geodetic or geocentric origin and supports forward and reverse topocentric conversion.

`Up` follows the ellipsoid-normal direction at the origin.

## Ellipsoidal geodesics

```d
import geodesy;

const solver =
    Geodesic!double(
        wgs84!double()
    );
```

The geodesic API provides prepared direct and inverse operations on spheres and supported oblate ellipsoids.

The current public support domain is documented with the API; unsupported extensions such as geodesic lines and polygon accumulation are outside the present scope.

## Scalar model

Public scalar types are:

```text
float
double
real
```

`double` is the normative reference precision. `float` is reduced precision and may use promoted working precision internally. D `real` is supported, but its precision is platform-dependent.

## Numerical model

There is no library-wide epsilon.

Tolerance, iteration, and convergence policies belong to the specific operation.

Numerical validation is documented under:

```text
docs/VALIDATION.md
docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md
docs/UTM_VALIDATION_PLAN.md
docs/GEODESIC_VALIDATION_PLAN.md
docs/TOPOCENTRIC_VALIDATION_PLAN.md
```

## Where to go next

Use:

- `README.md` for the package overview;
- `docs/API.md` for the public API baseline;
- `docs/ddoc-style.md` for public documentation rules;
- `docs/public-api-example-audit.md` for executable-example coverage;
- `docs/operations/` for operation-specific notes;
- `docs/adr/` for architectural decisions.
