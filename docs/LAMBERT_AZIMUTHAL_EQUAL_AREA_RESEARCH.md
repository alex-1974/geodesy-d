# Lambert Azimuthal Equal Area research and admission

Date: 2026-10-06  
Issue: #84  
Family: ellipsoidal Lambert Azimuthal Equal Area

## Decision

Implement a dedicated prepared `LambertAzimuthalEqualArea!T` projection.

The initial public API is mathematical only. It does not hard-code EPSG:3035
or provide CRS authority lookup.

## Interoperability motivation

EPSG:3035 ETRS89-extended / LAEA Europe is the primary admitted
interoperability case. It uses GRS80 with:

- latitude of projection centre: 52 degrees;
- longitude of projection centre: 10 degrees;
- false easting: 4,321,000 m;
- false northing: 3,210,000 m.

Its scope is pan-European statistical/equal-area analysis.

## Mathematical kernel

For eccentricity squared `e2`, eccentricity `e`, and latitude `phi`:

~~~text
q(phi) =
  (1 - e2) *
  [
      sin(phi) / (1 - e2 sin^2(phi))
      - 1/(2e) * ln((1 - e sin(phi)) / (1 + e sin(phi)))
  ]
~~~

For a sphere, the continuous limit is:

~~~text
q(phi) = 2 sin(phi)
qp = 2
~~~

The authalic latitude is:

~~~text
beta = asin(q / qp)
Rq = a * sqrt(qp / 2)
~~~

For an oblique/equatorial centre `beta0`:

~~~text
m0 = cos(phi0) / sqrt(1 - e2 sin^2(phi0))
D  = m0 / (sqrt(qp/2) * cos(beta0))

den = 1 + sin(beta0) sin(beta)
          + cos(beta0) cos(beta) cos(deltaLon)

B = Rq * sqrt(2 / den)

E = EF + B * D * cos(beta) * sin(deltaLon)
N = NF + B / D *
         (cos(beta0) sin(beta)
          - sin(beta0) cos(beta) cos(deltaLon))
~~~

Polar centres use the algebraically simpler limiting form:

North:
~~~text
r = a * sqrt(qp - q)
E = EF + r sin(deltaLon)
N = NF - r cos(deltaLon)
~~~

South:
~~~text
r = a * sqrt(qp + q)
E = EF + r sin(deltaLon)
N = NF + r cos(deltaLon)
~~~

## Reverse

For oblique/equatorial centres, normalize projected coordinates by the prepared
`D`, compute radial distance `rho`, then:

~~~text
Ce = 2 asin(rho / (2 Rq))
beta = asin(
    cos(Ce) sin(beta0)
    + y' sin(Ce) cos(beta0) / rho
)

deltaLon = atan2(
    x' sin(Ce),
    rho cos(beta0) cos(Ce)
      - y' sin(beta0) sin(Ce)
)
~~~

For polar centres, `q` follows directly from squared radius.

Authalic latitude is inverted with Newton on `q(phi)`, using:

~~~text
dq/dphi =
  2 (1 - e2) cos(phi)
  / (1 - e2 sin^2(phi))^2
~~~

A spherical/authalic initial estimate is used.

## Domain and singularities

Accepted ellipsoid domain:

~~~text
a > 0
0 <= f <= 0.01
finite false easting/northing
valid projection-centre latitude/longitude
~~~

All centre latitudes from -90 through +90 are supported.

The projection centre is represented exactly as false easting/northing and
reverse canonicalizes it to the prepared centre longitude.

The exact authalic antipode is a directional singularity of forward LAEA.
The initial checked API rejects it rather than choosing an arbitrary boundary
direction. The oblique/equatorial kernel classifies only an ulp-scaled
machine-roundoff neighbourhood of the mathematically zero forward denominator
as that same singular point. This handles independently converted equivalent
degree/radian inputs without creating a geographic epsilon band.

Reverse accepts the open represented disk and rejects the exact antipodal
boundary and points beyond it. This deliberately gives a one-to-one public
mapping.

## Longitude semantics

Forward uses the existing canonical shortest longitude difference in
`[-pi,+pi)`.

Reverse returns canonical longitude. At the projection centre longitude is
indeterminate and is canonicalized to the prepared centre longitude.

## Scalar policy

Established geodesy-d policy:

~~~text
float  -> double working precision -> float public result
double -> double
real   -> real
~~~

Exact centre/pole/cardinal representations are recognized at the public scalar
boundary where required.

## Public API

~~~d
LambertAzimuthalEqualArea!T

tryFromParameters(...)
fromParameters(...)

tryForward(...)
forward(...)

tryReverse(...)
reverse(...)
~~~

No conformal factor type is reused: LAEA is equal-area, not conformal. A future
general distortion tensor/factor API requires separate design evidence.

## Validation

Required:

- independent PROJ differential validation;
- PROJ 9.4 ellipsoidal reverse comparison accounts for its auxiliary-latitude
  series approximation floor (~1.4e-8 degree observed for EPSG:3035), while
  geodesy-d's direct Newton inversion and own roundtrip are qualified more
  strictly;
- explicit EPSG:3035 GRS80 parameter regression;
- WGS84, GRS80, sphere, and an additional oblate ellipsoid;
- oblique, equatorial, north-polar, and south-polar centres;
- centre and near-centre cases;
- high latitude;
- antimeridian;
- near-antipodal cases, with separately qualified latitude/longitude
  roundtrip tolerances because directional longitude conditioning degrades
  faster than latitude as the antipodal singularity is approached;
- exact antipode rejection;
- reverse represented-disk boundary rejection;
- float/double/real;
- controlled DMD/LDC matrix;
- Linux/Windows/macOS x86_64/AArch64.

## Performance

Prepared state caches:

- eccentricity squared/eccentricity;
- `qp`;
- authalic radius `Rq`;
- centre authalic sine/cosine;
- oblique/equatorial scaling `D`.

Forward is non-iterative. Reverse has one small Newton solve for authalic
latitude.

Checked hot paths remain allocation-free, `@safe`, `nothrow`, and `@nogc`.

## References

- EPSG:3035 ETRS89-extended / LAEA Europe.
- IOGP/EPSG Lambert Azimuthal Equal Area method guidance.
- PROJ `laea` implementation and documentation.
