# Ellipsoidal Rhumb / RhumbLine research and admission

Date: 2026-10-06  
Issue: #37  
Milestone: M3 — Navigation & Polar Geodesy

## Decision

Admit an independent loxodromic family:

~~~d
Rhumb!T
RhumbLine!T
RhumbInverseResult!T
RhumbDirectResult!T
~~~

Rhumb behavior is not exposed through `Geodesic!T`.

The initial public family covers distance, constant bearing, direct endpoint,
and prepared repeated positions. Rhumb-polygon area is deliberately outside
#37.

## Mathematical model

Let the ellipsoid have semi-major axis `a`, flattening `f`, and

~~~text
e² = f (2 - f)
~~~

For geodetic latitude `phi`, define the isometric latitude

~~~text
psi(phi) = asinh(tan(phi))
           - e * atanh(e * sin(phi))
~~~

for the admitted oblate/spherical domain.

Define the meridian distance from the equator

~~~text
M(phi) = integral(0..phi)
         a (1 - e²) / (1 - e² sin²(t))^(3/2) dt
~~~

and the local east-west radius

~~~text
Q(phi) = N(phi) cos(phi)
N(phi) = a / sqrt(1 - e² sin²(phi))
~~~

A rhumb is straight in `(psi, lambda)` coordinates. For two ordinary
non-polar endpoints:

~~~text
dpsi = psi2 - psi1
dlambda = shortest signed longitude difference

D = (M2 - M1) / dpsi
    with the continuous limit Q(phi) when dpsi -> 0

bearing  = atan2(dlambda, dpsi)
distance = hypot(dlambda, dpsi) * D
~~~

`D` is positive because `M` and `psi` are monotone in latitude.

For direct evaluation with signed distance `s` and bearing `alpha`:

~~~text
dM = s cos(alpha)
M2 = M1 + dM
phi2 = inverseMeridianDistance(M2)

D = dM / (psi2 - psi1)
    with the continuous east-west limit Q(phi1)

dlambda = s sin(alpha) / D
lambda2 = normalize(lambda1 + dlambda)
~~~

This formulation is equivalent to the rectifying/isometric auxiliary-latitude
form used by GeographicLib, but it avoids introducing the much larger
auxiliary-latitude framework solely for the non-area #37 scope.

## Meridian-distance implementation

The runtime kernel evaluates the meridian integral by a fixed power series in
`e²`:

~~~text
(1 - e² sin²(phi))^(-3/2)
  = sum(c_k e^(2k) sin^(2k)(phi))

c_0 = 1
c_k = c_(k-1) * (2k + 1) / (2k)
~~~

The integrals

~~~text
I_k(phi) = integral(0..phi) sin^(2k)(t) dt
~~~

use the stable recurrence

~~~text
I_0 = phi
I_k = (2k - 1)/(2k) I_(k-1)
      - sin^(2k-1)(phi) cos(phi)/(2k)
~~~

The production kernel retains enough fixed terms that truncation is
negligible across the admitted `0 <= f <= 0.01` domain relative to public
`double` precision targets. The loop has static small bounds, allocates
nothing, and is suitable for compiler unrolling.

The inverse meridian step uses Newton iteration with the exact meridional
radius as derivative and a rectifying-radius initial estimate.

## Supported ellipsoid domain

Initial admission matches the conservative projection/navigation policy:

~~~text
a > 0
0 <= f <= 0.01
~~~

Spheres are admitted.

Prolate ellipsoids are not silently admitted here. Workspace issue #69 owns
the broader prolate policy and should be resolved consistently across
families before Rhumb expands that domain.

## Scalar policy

As elsewhere in geodesy-d:

~~~text
float  -> double working precision -> float result
double -> double
real   -> real
~~~

Exact public cardinal values are recognized before widening, so `float`
poles and antimeridians do not drift when promoted to double work precision.

## Inverse semantics

The inverse operation returns:

~~~d
RhumbInverseResult!T {
    distance;
    bearing;
}
~~~

The shortest rhumb is selected by canonical longitude difference.

For endpoints on opposite meridians, the exact tie is resolved east-going,
matching GeographicLib: `dlambda = +pi`.

Coincident endpoints return canonical positive zero distance and bearing.

Pole semantics:

- identical poles are coincident regardless of stored longitude;
- an inverse with exactly one polar endpoint has the meridional distance and
  the limiting north/south bearing; polar longitude is ignored;
- opposite poles use the limiting meridional rhumb.

## Direct semantics

Direct distance is signed, matching the existing geodesic philosophy and
GeographicLib RhumbLine behavior.

Zero distance preserves the start coordinate.

For nonzero direct operations, an exact polar start is rejected because
constant-bearing longitude is not uniquely defined at the pole.

If a nonzero direct step reaches or crosses a pole, checked direct/line
position returns `false`; the throwing form raises `GeodesyValueException`.
This is intentional because `GeographicCoordinate!T` requires a finite,
defined longitude. It is stricter and more explicit than returning a NaN
longitude.

## RhumbLine

`RhumbLine!T` stores:

- prepared Rhumb ellipsoid state;
- canonical start coordinate;
- canonical constant bearing;
- start meridian distance;
- start isometric latitude;
- sine/cosine of bearing.

Repeated `position(distance)` calls therefore avoid rebuilding the solver
and re-evaluating the start auxiliary state.

## Longitude semantics

Public longitudes remain canonical in the existing geodesy-d interval
`[-pi,+pi)`.

The inverse uses the shortest signed longitude difference. The opposite-
meridian tie is east-going.

The initial #37 API does not expose longitude unrolling. A future additive
line option can add it if a concrete navigation consumer needs wrap count.

## Independent validation

The implementation must be checked against GeographicLib `Rhumb` /
`RhumbLine` for:

- WGS 84 and several additional oblate ellipsoids;
- sphere;
- ordinary direct/inverse cases;
- east-west and meridional limits;
- coincident points;
- antimeridian and exact opposite-meridian tie;
- high latitude / near-pole cases;
- signed direct distance;
- prepared line positions.

The geodesy-d stricter pole-crossing direct policy is validated as policy,
not differential equality.

## Qualification

Before #37 closes:

- `float/double/real` scalar qualification;
- controlled DMD 2.111.0 / 2.112.1 / 2.113.0;
- controlled LDC 1.41.0 / 1.42.0 / 1.43.0;
- Linux x86_64/AArch64, Windows x86_64, macOS x86_64/AArch64;
- release codegen probes for inverse, direct, and prepared-line position;
- local performance characterization against GeographicLib;
- DDox/public-example audit.

## Performance target

The hot path must remain allocation-free and `@nogc`.

The implementation should exploit D templates and fixed-order compile-time
specialization rather than mechanically translating the GeographicLib C++
auxiliary-latitude framework.

Performance comparison is against prepared GeographicLib Rhumb/RhumbLine
operations on controlled hardware. Hosted CI timings are smoke-only.
