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

## What it provides

- strong angle, latitude, and longitude types;
- reference ellipsoids including WGS 84;
- geographic/geodetic and geocentric (ECEF) coordinates;
- geographic ↔ geocentric conversion;
- geocentric translations;
- static 7-parameter Helmert transformations;
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
        rhumbRoute.azimuth.degrees, " deg"
    );
}
~~~

## Documentation

- [Public API](docs/API.md)
- [v1.2.0 release notes](docs/V1_2_RELEASE_NOTES.md)
- [M3 integration and performance evidence](docs/M3_INTEGRATION_GATE.md)
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
