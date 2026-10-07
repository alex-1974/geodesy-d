# UPS policy and coordinate-family design

Date: 2026-10-06  
Issue: #39  
Milestone: M3 — Navigation & Polar Geodesy

## Decision

Admit Universal Polar Stereographic (UPS) as a thin WGS 84 policy layer over
the already-qualified `PolarStereographic!T` kernel.

UPS does not get a second projection algorithm.

The public family is:

~~~text
PolarStereographic!T
└── UpsProjection!T
    ├── UpsHemisphere
    ├── UpsCoordinate!T
    ├── tryStandardUpsHemisphere
    ├── tryForwardUps / forwardUps
    └── tryReverseUps / reverseUps
~~~

MGRS remains outside this issue.

## Authoritative projection parameters

EPSG WGS 84 / UPS North (E,N), EPSG:5041, and WGS 84 / UPS South (E,N),
EPSG:5042, use Polar Stereographic variant A (EPSG method 9810) on WGS 84.

Both aspects use:

~~~text
longitude of natural origin = 0 degrees
scale factor at natural origin = 0.994
false easting = 2,000,000 m
false northing = 2,000,000 m
~~~

The latitude of natural origin is +90 degrees for north and -90 degrees for
south.

The geodesy-d UPS family uses the Easting/Northing axis order represented by
EPSG:5041 and EPSG:5042. The alternative EPSG:32661 / EPSG:32761 CRS
definitions use Northing/Easting axis order and are not separate mathematical
projections.

## WGS 84 only

Unlike generic `PolarStereographic!T`, UPS is a named global grid policy.
The public UPS layer therefore fixes the ellipsoid to WGS 84 and linear units
to metres.

There is intentionally no ellipsoid parameter on `UpsProjection`,
`forwardUps`, or `reverseUps`.

Consumers requiring another ellipsoid or another polar stereographic CRS must
use `PolarStereographic!T` directly.

## Standard UTM/UPS transition

The existing geodesy-d automatic UTM policy accepts:

~~~text
-80 degrees <= latitude < +84 degrees
~~~

Standard automatic UPS selection is defined as its exact complement:

~~~text
south UPS: -90 degrees <= latitude < -80 degrees
north UPS: +84 degrees <= latitude <= +90 degrees
~~~

Thus:

- -80 degrees belongs to automatic UTM;
- +84 degrees belongs to automatic UPS;
- there is no gap and no double assignment in automatic policy.

This matches the standard UTM/UPS selection used by reference systems such as
GeographicLib.

## Explicit UPS overlap

The military UTM/UPS grids deliberately provide a one-degree overlap around
the UTM/UPS transition. Positions may legally be represented in UPS down to:

~~~text
north UPS: latitude >= +83.5 degrees
south UPS: latitude <= -79.5 degrees
~~~

`UpsProjection!T` is the explicit prepared UPS operation and admits this
overlap. It does not silently re-run standard automatic UTM/UPS selection.

This mirrors the existing distinction in `UtmProjection!T`: an explicit
prepared projection is allowed where the grid representation is legal even
when it is not the standard automatic choice.

## Tagged coordinate and reverse safety

UPS has no numeric zone, but reverse projection still requires the polar
aspect. `UpsCoordinate!T` therefore stores:

~~~text
UpsHemisphere hemisphere
ProjectedCoordinate!T projected
~~~

The hemisphere tag is semantic state, not inferred from easting/northing.

For represented UPS coordinates the family uses the established
GeographicLib UTM/UPS reverse-admission rectangles:

~~~text
north: easting  [1,200,000 m, 2,800,000 m]
       northing [1,200,000 m, 2,800,000 m]

south: easting  [  700,000 m, 3,300,000 m]
       northing [  700,000 m, 3,300,000 m]
~~~

These ranges are deliberately representation-policy bounds, not mathematical
bounds of generic Polar Stereographic. Reverse additionally requires the
recovered latitude to remain in the explicit legal UPS overlap domain.

The generic `PolarStereographic!T` remains available for callers needing a
larger mathematical domain.

## Responsibility boundary

UPS owns:

- fixed WGS 84 ellipsoid;
- north/south UPS aspect;
- fixed natural-origin longitude, scale, and false offsets;
- standard automatic UTM/UPS cutover;
- explicit UPS overlap policy;
- tagged UPS coordinate representation;
- metre-valued represented-coordinate admission;
- factor delegation to Polar Stereographic.

UPS does not own:

- MGRS letters or grid-square encoding;
- CRS database lookup;
- WKT / PROJJSON;
- EPSG authority discovery;
- arbitrary polar stereographic parameterization;
- arbitrary ellipsoids.

## Validation plan

The implementation gate must cover:

1. EPSG 5041 / 5042 parameter invariants;
2. EPSG 9810 published north example (73 N, 44 E) as kernel inheritance;
3. standard cutovers at -80 and +84 degrees;
4. explicit overlap at -79.5 and +83.5 degrees;
5. north/south tagged reverse;
6. represented E/N range boundaries;
7. convergence and scale delegation;
8. differential comparison with PROJ and GeographicLib UTM/UPS;
9. `float`, `double`, and `real`;
10. controlled DMD/LDC and platform matrices.

## Performance

UPS policy must remain a thin wrapper.

A prepared `UpsProjection!T` performs no per-call ellipsoid or projection
parameter setup. Hot forward/reverse/factor work delegates to the prepared
`PolarStereographic!T` state.

No broad fast-math policy is admitted.
