# Lambert Conformal Conic 2SP research and admission

Date: 2026-10-06  
Issue: #83  
Method: EPSG 9802 — Lambert Conic Conformal (2SP)

## Decision

Implement a dedicated prepared `LambertConformalConic!T` family for the
regular EPSG 9802 two-standard-parallel method.

Initial scope does not include:

- LCC 1SP;
- EPSG 9803 Belgium;
- Michigan/vendor scale-factor variants;
- CRS lookup or hard-coded EPSG presets;
- datum transformations.

The generic mathematical kernel is the public capability. EPSG:31287 and
EPSG:3034 are validation/interoperability parameter sets, not public presets.

## Interoperability motivation

The family is admitted because it closes concrete European interoperability
gaps.

### EPSG:31287 — MGI / Austria Lambert

Uses EPSG 9802 with Bessel 1841:

- latitude of false origin: 47.5 degrees;
- longitude of false origin: 13.3333333333333 degrees;
- first standard parallel: 49 degrees;
- second standard parallel: 46 degrees;
- false easting: 400000 m;
- false northing: 400000 m.

### EPSG:3034 — ETRS89-extended / LCC Europe

Uses EPSG 9802 with GRS80:

- latitude of false origin: 52 degrees;
- longitude of false origin: 10 degrees;
- first standard parallel: 35 degrees;
- second standard parallel: 65 degrees;
- false easting: 4000000 m;
- false northing: 2800000 m.

## Mathematical kernel

For ellipsoid semi-major axis `a`, eccentricity `e`, latitude `phi`:

~~~text
m(phi) = cos(phi) / sqrt(1 - e^2 sin^2(phi))

psi(phi) = asinh(tan(phi)) - e atanh(e sin(phi))
t(phi) = exp(-psi(phi))
~~~

For standard parallels `phi1`, `phi2`:

~~~text
n = log(m1 / m2) / log(t1 / t2)
F = m1 / (n * t1^n)

rho(phi) = a F t(phi)^n
rho0 = rho(phi0)
theta = n * normalized(lon - lon0)

E = EF + rho sin(theta)
N = NF + rho0 - rho cos(theta)
~~~

The implementation evaluates `t^n` as `exp(n * logT)`, avoiding an
unnecessary positive-domain `pow` and making the logarithmic structure
explicit.

For reverse:

~~~text
dy = rho0 - (N - NF)
dx = E - EF
rho = hypot(dx, dy)

if n < 0:
    rho = -rho
    dx = -dx
    dy = -dy

theta = atan2(dx, dy)
deltaLon = theta / n

logT = log(rho / (a F)) / n
psi = -logT
phi = inverseIsometricLatitude(psi)
~~~

Inverse isometric latitude uses Newton iteration with exact derivative

~~~text
d psi / d phi =
    (1 - e^2) /
    (cos(phi) * (1 - e^2 sin^2(phi)))
~~~

and a spherical initial estimate.

## Parameter domain

Initial admission matches the conservative projection policy:

~~~text
a > 0
0 <= f <= 0.01
-90 < phi1 < +90
-90 < phi2 < +90
phi1 != phi2
phi1 + phi2 != 0
finite false easting/northing
~~~

The two standard parallels must be genuinely distinct. Equal standard
parallels are a tangent/1SP limit and are deliberately outside the initial
EPSG-9802-only API.

The signs of `phi1` and `phi2` need not be identical, but their sum must
not be zero and the derived cone constant `n` must be finite and nonzero.

## Pole semantics

The pole on the cone-apex side is represented exactly by `rho = 0`:

- north pole when `n > 0`;
- south pole when `n < 0`.

At the apex, longitude is physically indeterminate. Reverse canonicalizes the
longitude to the longitude of false origin.

The opposite pole is a true singularity and is rejected by checked forward.

A false origin at the opposite singular pole is rejected at construction.

## Longitude semantics

Forward uses the existing canonical shortest longitude difference in
`[-pi,+pi)`.

This chooses one represented branch of the conic projection.

Reverse rejects coordinates whose recovered `deltaLon` lies outside that
represented branch. Exact branch-boundary representation is handled
consistently with the public canonical longitude convention rather than by a
broad angular epsilon.

Longitude unrolling is not part of the initial family.

## Projection factors

LCC is conformal, so the existing `ConformalProjectionFactors!T` applies.

For a geographic point:

~~~text
gamma = theta = n * deltaLon
k = n * rho / (a * m(phi))
~~~

The signs of `n` and `rho` match, giving positive point scale.

At each standard parallel, point scale is 1 within numerical representation.

At the cone apex the scale limit is not generally finite, so factors at the
exact apex are rejected in the initial API.

## Scalar policy

Use the established geodesy-d policy:

~~~text
float  -> double working precision -> float public result
double -> double
real   -> real
~~~

Exact public poles and canonical longitude boundaries are recognized before
widening where representation matters.

## Validation

Required independent qualification:

- PROJ LCC forward/reverse differential corpus;
- EPSG:31287 Austria Lambert parameter set;
- EPSG:3034 Europe LCC parameter set;
- Bessel 1841, GRS80, WGS84, sphere and an additional oblate ellipsoid;
- northern and southern cones;
- standard parallels;
- false origin;
- antimeridian branch;
- cone apex and opposite-pole rejection;
- near-centre and high-latitude cases;
- forward/reverse projection factors;
- float/double/real;
- controlled DMD/LDC matrix;
- Linux/Windows/macOS x86_64/AArch64.

## Performance

The prepared object caches:

- eccentricity;
- cone constant `n`;
- `F`;
- `rho0`.

Forward and factors then require no iterative solve. Reverse has one small
Newton solve for isometric latitude.

Hot checked paths are allocation-free, `@safe`, `nothrow`, and `@nogc`.

The release qualification records codegen probes and a local performance
characterization against PROJ; hosted CI timing remains smoke-only.

## References

- EPSG method 9802 / IOGP Guidance Note 7-2.
- EPSG:31287 MGI / Austria Lambert.
- EPSG:3034 ETRS89-extended / LCC Europe.
- PROJ Lambert Conformal Conic implementation/documentation.
