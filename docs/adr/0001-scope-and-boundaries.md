# ADR-0001: Scope and architectural boundaries of geodesy-d

- **Status:** Accepted
- **Date:** 2026-09-09

## Context

The `d-geospatial` workspace separates general geometry, geodetic mathematics, geographic reference encodings, and full CRS infrastructure into independent libraries.

An earlier pure-D prototype (`coordinate`) combined geographic coordinates, ECEF, UTM/MGRS, datum and ellipsoid catalogues, geocodes, parsing, and transformation algorithms in one package. That prototype demonstrated that useful geodetic mathematics can be implemented in D, but it also showed the cost of mixing several separate domains into one library.

At the same time, PROJ provides a mature and much broader CRS/transformation ecosystem. Requiring PROJ for every bounded mathematical operation would make small pure-D use cases unnecessarily dependent on a native C/C++ runtime and on infrastructure they may not need. Reimplementing the complete PROJ ecosystem in D would be equally undesirable.

## Decision

`geodesy-d` provides **pure-D mathematical types and algorithms whose semantics depend on the Earth, a reference ellipsoid, geographic or geocentric coordinates, frame transformations, or map projections**.

The initial core is limited to:

```text
Angle
Latitude
Longitude
Ellipsoid
GeodeticCoordinate
GeocentricCoordinate / ECEF
geodetic ↔ geocentric conversion
```

Later additions may include, when justified and independently verified:

```text
geocentric translations
Helmert transformations
Transverse Mercator
UTM
direct/inverse ellipsoidal geodesics
other bounded geodetic operations
```

`geodesy-d` does **not** own:

- general-purpose Euclidean geometry, polygon topology, clipping, or spatial predicates (`geo-d`);
- MGRS, Geohash, Open Location Code / Plus Codes, or similar compact/discrete geographic reference systems (`georef-d`);
- EPSG/authority databases, CRS discovery, WKT/PROJJSON parsing, grid-resource management, or automatic transformation-path selection (`proj-d` / PROJ);
- application, rendering, GUI, logging, or storage frameworks.

UTM belongs to `geodesy-d` because it is a standardized application of map-projection mathematics. MGRS belongs to `georef-d` because it is a discrete reference/coding system built on UTM.

A projected coordinate may be adapted to a `geo-d` point, but the initial `geodesy-d` core does not depend on `geo-d`. Direct coupling may be introduced later only if real consumers demonstrate a clear benefit over explicit adapters.

## Consequences

### Positive

- bounded geodetic operations can be used in pure D without the PROJ runtime;
- the numerical core can target D-specific properties such as `@safe`, `@nogc`, `nothrow`, `pure`, and CTFE where feasible;
- the public API can model geodetic semantics explicitly instead of exposing raw numeric tuples;
- the library remains small enough for independent numerical validation;
- PROJ can still be used through `proj-d` when full CRS/authority/grid infrastructure is required;
- `georef-d` gets a clean mathematical dependency for MGRS without pulling geocoding concerns into the geodetic core.

### Negative / trade-offs

- some mathematical operations will overlap in capability with PROJ or GeographicLib;
- maintaining a pure-D implementation requires strong reference-vector and cross-validation discipline;
- users needing arbitrary CRS transformations will still need `proj-d`/PROJ;
- adapters may be required between `geodesy-d`, `geo-d`, and external coordinate types.

## Rejected alternatives

### Put all spatial coordinate functionality into geo-d

Rejected because Euclidean geometry and Earth-dependent geodesy have different semantics, numerical assumptions, and consumers. `geo-d` must remain coordinate-system agnostic.

### Use PROJ exclusively for all geodetic mathematics

Rejected as a global rule. PROJ is appropriate for complete CRS infrastructure, but bounded and well-specified mathematical kernels can provide independent value as pure D.

### Reimplement PROJ completely in D

Rejected. Authority databases, WKT/PROJJSON, transformation discovery, grids, and the full catalogue of operations are outside the intended scope.

### Keep MGRS, Geohash and Plus Codes inside geodesy-d

Rejected because these are reference/coding systems rather than the mathematical geodetic core. They belong to `georef-d`.

## Follow-up

ADR-0002 defines the proposed core type, angle/unit, scalar, and ellipsoid semantics before implementation begins.
