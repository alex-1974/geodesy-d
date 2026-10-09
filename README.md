# geodesy-d

`geodesy-d` is a lightweight pure-D library for geodetic mathematics.

It provides reusable types and operations for working with positions on and
around a reference ellipsoid, including coordinate conversion, map
projections, reference-frame transformations, geodesics, UTM, and local
topocentric coordinates.

The library is designed around a small, explicit numerical core:

- **pure D and dependency-light** — no PROJ or GeographicLib runtime dependency
  for the provided operations;
- **strongly typed** — latitude, longitude, angles, coordinates, ellipsoids,
  projections, frames, and transformations keep different domains explicit;
- **safety-oriented** — checked APIs use `@safe`, `nothrow`, `pure`, and
  `@nogc` where the operation permits it, with deliberate valid/invalid
  default-state semantics;
- **performance-conscious** — reusable prepared projections, frames, and
  geodesic solvers avoid repeated setup, and documented numerical hot paths
  avoid hidden allocation;
- **numerically validated** — non-trivial operations are checked against
  authoritative reference material and independent implementations.

## What can I do with it?

Convert a geographic position into Earth-centred XYZ coordinates or into
UTM easting and northing. Measure the shortest surface distance and bearing
between two positions, find the nearest point on a route, or convert
coordinates between reference frames. Choose the operation that matches
the coordinate data and reference model you have.

Start with the [guided examples](docs/getting-started.md). The first example
below shows several operations together; for a single task, follow the
corresponding section of the guide.

## What can I do with it?

Convert geographic positions into Earth-centred XYZ or UTM coordinates.
Measure the shortest surface distance and bearing between places, find
the closest point on a route segment, or transform coordinates between
reference frames.

Start with the [guided examples](docs/getting-started.md). The combined
example below shows several operations; the guide introduces them separately.

## What it provides

- strong angle, latitude, and longitude types;
- reference ellipsoids including WGS 84;
- geographic/geodetic and geocentric (ECEF) coordinates;
- geographic ↔ geocentric conversion;
- geocentric translations;
- static 7-parameter Helmert transformations;
- strong decimal-year epoch semantics and dynamic 14-parameter Helmert transformations;
- static Molodensky-Badekas transformations with Position Vector / Coordinate Frame conventions;
- Transverse Mercator;
- Pseudo-Mercator;
- UTM forward and reverse projection;
- bounded Polar Stereographic projection;
- UPS policy and tagged coordinates over Polar Stereographic;
- Lambert Conformal Conic 2SP;
- Lambert Azimuthal Equal Area;
- meridian convergence and point scale for Transverse Mercator, UTM, Polar
  Stereographic, and Lambert Conformal Conic;
- direct and inverse ellipsoidal geodesics;
- ellipsoidal rhumb direct/inverse navigation and prepared `RhumbLine`;
- reduced length, geodesic scales, and signed geodesic area quantities;
- prepared `GeodesicLine` evaluation for repeated positions;
- streaming ellipsoidal polygon perimeter and signed-area measurement;
- local East/North/Up topocentric coordinates.

Public numerical types support `float`, `double`, and platform `real`.

## Installation

Add the package to a DUB project:

~~~sh
dub add geodesy-d
~~~

Import the public API:

~~~d
import geodesy;
~~~

## Example

The following example creates a WGS 84 position in Vienna, converts it to ECEF, projects it to UTM, and computes both geodesic and rhumb navigation to another position.

~~~d
import geodesy;
import std.stdio : writeln;

void main()
{
    const earth = wgs84!double();

    const vienna =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(48.20849),
            Longitude!double.fromDegrees(16.37208)
        );

    const graz =
        GeographicCoordinate!double.fromComponents(
            Latitude!double.fromDegrees(47.07071),
            Longitude!double.fromDegrees(15.43950)
        );

    const ecef =
        geodeticToGeocentric(
            GeodeticCoordinate!double.fromComponents(
                vienna.latitude,
                vienna.longitude,
                171.0
            ),
            earth
        );

    const utm = forwardUtm(vienna, earth);

    const geodesic = Geodesic!double.fromEllipsoid(earth);
    const route = geodesic.inverse(vienna, graz);

    const rhumb = Rhumb!double.fromEllipsoid(earth);
    const rhumbRoute = rhumb.inverse(vienna, graz);

    writeln("ECEF: ", ecef.x, ", ", ecef.y, ", ", ecef.z);
    writeln(
        "UTM zone ", utm.zone.number,
        ": ", utm.easting, ", ", utm.northing
    );
    writeln("Vienna–Graz geodesic distance: ", route.distance, " m");
    writeln(
        "Vienna–Graz rhumb distance/bearing: ",
        rhumbRoute.distance, " m / ",
        rhumbRoute.bearing.degrees, " deg"
    );
}
~~~

## Status

**Current stable feature release: v1.2.0.**

v1.2.0 completes M3 — Navigation & Polar Geodesy. The current `develop` line
has since completed M4 — Reference Frames and M5 — Advanced Ellipsoidal
Geometry, including the qualified prolate geodesic domain.

The next release target is **v2.0.0**, planned primarily as a consolidation and
API-stabilization release rather than another breadth milestone. Physical
geodesy / gravity work remains research-only for now and is not part of the
initial v2.0 scope.

## Documentation

- [Public API](docs/API.md)
- [v1.2.0 release notes](docs/V1_2_RELEASE_NOTES.md)
- [M3 integration and performance evidence](docs/M3_INTEGRATION_GATE.md)
- [M4 reference-frame integration evidence](docs/M4_INTEGRATION_GATE.md)
- [Geodesic feature matrix](docs/GEODESIC_FEATURE_MATRIX.md)
- [Roadmap](ROADMAP.md)
- [Changelog](CHANGELOG.md)
- [Detailed documentation](docs/README.md)

## Research and validation evidence

Detailed experiments, benchmark fixtures, exploratory probes, raw acceptance
evidence, and historical research are kept in the companion repository
`alex-1974/geodesy-d-research`.

The production package keeps the source, active regression/validation gates,
user and maintainer documentation, and small tools needed to qualify releases.
Normal DUB consumers therefore do not need to download the research corpus.

## License

MIT — see [LICENSE](LICENSE).
