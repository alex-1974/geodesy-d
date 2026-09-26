# geodesy-d v1.0.0 release notes

Release date: **2026-09-26**

`geodesy-d` v1.0.0 establishes the first frozen public API for the
dependency-light pure-D geodetic mathematics library. The v1 contract was
reviewed explicitly for naming, construction and `.init` semantics, failure
channels, scalar and unit policy, operation domains, module boundaries, named
arguments, aggregate exports, and external source compatibility.

## Public v1 scope

The v1 baseline includes:

- strong `Angle!T`, `Latitude!T`, and `Longitude!T` value types;
- reference ellipsoids and geographic/geocentric coordinate types;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032 Coordinate Frame and EPSG 1033 Position Vector static Helmert
  transformations;
- bounded generic `TransverseMercator!T`;
- bounded EPSG method 1024 `PseudoMercator!T`;
- UTM zone/hemisphere policy, prepared `UtmProjection!T`, tagged
  `UtmCoordinate!T`, automatic standard-zone forward projection, and tagged
  reverse projection;
- conformal meridian-convergence and point-scale factors for prepared
  Transverse Mercator and UTM projections;
- prepared direct/inverse ellipsoidal `Geodesic!T` operations;
- EPSG 9836 geocentric/topocentric and EPSG 9837 geodetic/topocentric
  East-North-Up conversion through `TopocentricFrame!T`.

Public numerical scalar types are `float`, `double`, and platform `real`.
The minimum supported D frontend is 2.111.0.

## Compatibility baseline

v1.0.0 freezes the reviewed public source contract, including public names,
signatures, overload shapes, argument order and parameter names, checked and
throwing operation families, default-state semantics, scalar/unit/domain
contracts, public module boundaries, and `import geodesy;` aggregate exports.

D named-argument compatibility is therefore part of the v1 source contract.
Future breaking changes to this baseline require an explicit compatibility and
versioning decision.

## Validation

The v1 implementation has been validated with DMD and LDC and with hosted
Linux x86_64, Linux AArch64, Windows x86_64, macOS AArch64, and macOS x86_64
coverage where defined by the operation-specific matrices. Windows/AArch64
remains experimental/informational.

Validation includes published EPSG/IOGP reference vectors, independent
GeographicLib and PROJ differential checks, analytical and spherical reference
models, boundary and singular cases, randomized/property validation,
platform-`real` characterization, public API compile contracts, and external
consumer builds.

PROJ and GeographicLib are validation infrastructure only; neither is a
runtime dependency.

## Scope boundary

v1 deliberately provides bounded mathematical operations rather than a full
CRS engine. It does not provide an EPSG database, WKT/PROJJSON handling, grid
resources, general CRS pipelines, MGRS/Geohash/Open Location Code policy, or
general Euclidean geometry/topology.

The library remains MIT licensed and dependency-light.

## Upgrade notes from v0.x

The v1 audit intentionally finalized the one-shot UTM free-function family in
source-first order:

~~~d
tryForwardUtm(source, ellipsoid, result)
forwardUtm(source, ellipsoid)
tryReverseUtm(source, ellipsoid, result)
reverseUtm(source, ellipsoid)
~~~

Throwing `Geodesic.direct` and `Geodesic.inverse` peers are part of the
frozen v1 surface. Transverse Mercator validation instrumentation is
package-internal and is not public API.

Consumers moving from v0.x should compile against v1 rather than assume source
compatibility with pre-freeze development call shapes.

For the detailed historical change record, see `CHANGELOG.md`. The frozen
contract is documented in `docs/API.md` and the completed audit in
`docs/V1_API_AUDIT.md`.
