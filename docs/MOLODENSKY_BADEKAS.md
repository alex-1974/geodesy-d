# Molodensky-Badekas

## Status

**ADMITTED for M4.**

This document records the admitted static geocentric Molodensky-Badekas
contract. It does not add CRS lookup, operation discovery, or a transformation
pipeline.

## Normative methods

The public geocentric family represents:

| Convention | EPSG method |
|---|---:|
| Position Vector | 1061 |
| Coordinate Frame | 1034 |

EPSG geographic-domain methods are compositions around this geocentric kernel;
they do not require duplicate Molodensky-Badekas mathematics in `geodesy-d`.

## Mathematical model

For source Cartesian coordinate `x`, evaluation point `p`, translation
`t`, scale factor `M`, and the convention-specific small-angle rotation
matrix `R`:

~~~text
y = p + t + M R (x - p)
~~~

For fixed parameters this is algebraically:

~~~text
y = M R x + (p + t - M R p)
~~~

The implementation therefore derives the equivalent existing `Helmert7`
parameter set once during construction and reuses the qualified Helmert kernel
for every application.

When `p = (0,0,0)`, the prepared equivalent Helmert parameters are exactly the
original seven parameters.

## Units

Canonical:

~~~text
translation       caller geocentric linear unit
evaluation point  caller geocentric linear unit
rotation          radians (Angle<T>)
scale difference  dimensionless
~~~

EPSG interchange factory:

~~~text
translation       caller geocentric linear unit
evaluation point  caller geocentric linear unit
rotation          arc-seconds
scale difference  ppm
~~~

The linear unit must match the `GeocentricCoordinate` values being transformed.

## Rotation conventions

The rotation convention is a compile-time parameter, matching the existing
Helmert family.

Equivalent Position Vector and Coordinate Frame parameterizations have opposite
rotation signs. Translations, scale difference, and evaluation-point ordinates
are unchanged.

## Reverse transformation

No automatic `inverse()` operation is provided.

EPSG defines the evaluation point coordinates in the source Cartesian CRS. The
point with identical numeric ordinates in the target CRS is not, in general,
the point required by the exact reverse transformation. Practical legacy
applications may approximate reversal by changing parameter signs, but that is
not promoted as an exact `geodesy-d` contract.

## Validation

The production unit tests include the EPSG/IOGP La Canoa -> REGVEN worked case:

~~~text
source:
X =  2550408.965 m
Y = -5749912.266 m
Z =  1054891.114 m

Coordinate Frame parameters:
tX = -270.933 m
tY = +115.599 m
tZ = -360.226 m
rX = -5.266 arcsec
rY = -1.238 arcsec
rZ = +2.381 arcsec
dS = -5.109 ppm

evaluation point:
Xp =  2464351.59 m
Yp = -5783466.61 m
Zp =   974809.81 m

published target:
X =  2550138.467 m
Y = -5749799.862 m
Z =  1054530.826 m
~~~

The independent differential gate runs the same case against PROJ
`+proj=molobadekas` in both Coordinate Frame and Position Vector convention.

Acceptance checks:

- D versus PROJ for both conventions;
- Position Vector / Coordinate Frame equivalence;
- published EPSG rounded vector;
- exact zero-evaluation-point reduction to Helmert7;
- float/double/real public instantiation;
- non-finite construction failure;
- aggregate public API compilation.

## Sources

- IOGP, *Geomatics Guidance Note 7, part 2 — Coordinate Conversions and
  Transformations including Formulas*.
- EPSG method 1034 — Molodensky-Badekas (Coordinate Frame, geocentric domain).
- EPSG method 1061 — Molodensky-Badekas (Position Vector, geocentric domain).
- PROJ — `molobadekas` transformation documentation.
