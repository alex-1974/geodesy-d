# M3.1 Polar Stereographic research and admission record

Status: research baseline for issue #38  
Branch: `research/m3-polar-stereographic`  
Stable input baseline: `geodesy-d v1.1.0`

## Decision summary

Admit a prepared, bounded `PolarStereographic!T` mathematical projection
family as the first M3 kernel.

The primary public parameter contract is **EPSG method 9810 — Polar
Stereographic (variant A)**:

- ellipsoid;
- latitude of natural origin, restricted to exactly +90 or -90 degrees;
- longitude of natural origin;
- positive scale factor at natural origin;
- false easting;
- false northing.

**EPSG method 9829 — Polar Stereographic (variant B)** is not a separate
mathematical kernel. Its standard-parallel parameterization is converted to an
equivalent scale factor at the natural origin and then evaluated by the same
variant-A kernel. A variant-B construction factory is therefore admissible
without duplicating forward/reverse mathematics.

UPS remains outside this issue. Issue #39 will own WGS 84 UPS policy and
coordinate semantics over the accepted kernel.

## Reference hierarchy

### Normative parameter and coordinate-operation semantics

1. EPSG Guidance Note 7-2 / EPSG method 9810, Polar Stereographic (variant A).
2. EPSG method 9829, Polar Stereographic (variant B), for conversion of a
   standard parallel to the equivalent natural-origin scale.
3. EPSG WGS 84 / UPS North conversion (EPSG:5041) as the principal UPS
   parameter cross-check.

Relevant EPSG semantics:

- variant A requires latitude of natural origin to be +90 or -90 degrees;
- north and south aspects use different northing signs;
- variant B first derives the variant-A natural-origin scale and then uses the
  same forward/reverse formulas.

### Independent implementation references

- PROJ `stere` and Polar Stereographic conversion constructors;
- PROJ `ups` for later #39 policy validation;
- GeographicLib `PolarStereographic`;
- GeographicLib `UTMUPS` for later #39 boundary/policy comparison.

### Numerical formulation reference

GeographicLib's current `PolarStereographic` implementation uses a stable
conformal-latitude formulation in terms of

```text
tau  = tan(phi)
tau' = tan(conformal latitude)
```

and evaluates the radial distance without the cancellation-prone direct
`tan(pi/4 - phi/2)` form near the pole.

That formulation is preferred for the production kernel. EPSG formulas remain
the public semantic reference; implementation algebra may use an equivalent
numerically stronger formulation.

## Mathematical model

Let

```text
a   = ellipsoid semi-major axis
f   = flattening
e²  = f (2 - f)
e   = sqrt(e²)
k0  = scale factor at the natural origin
lambda0 = longitude of natural origin
```

For the admitted v1-compatible ellipsoid domain the first implementation
inherits the existing spherical/oblate policy:

```text
a > 0
0 <= f <= 0.01
```

Prolate support remains issue #69 and must not be introduced accidentally by
this M3 slice merely because a reference implementation supports it.

### Stable conformal-latitude form

For an input latitude reflected into the selected polar aspect,

```text
tau     = tan(phi)
secphi  = hypot(1, tau)
sigma   = sinh(e * atanh(e * tau / secphi))
tauPrime = tau * hypot(1, sigma) - sigma * secphi
```

Define the prepared ellipsoid constant

```text
c = (1 - f) * exp(e * atanh(e))
R = 2 * k0 * a / c
```

Then

```text
rho = R / (hypot(1, tauPrime) + tauPrime)   when tauPrime >= 0
rho = R * (hypot(1, tauPrime) - tauPrime)   when tauPrime < 0
```

with the exact selected pole mapped to `rho = 0`.

This is algebraically equivalent to EPSG 9810 and reproduces its published UPS
example.

### Forward orientation

Let `dlon = longitude - longitudeOfNaturalOrigin`, normalized using the same
compensated principal-longitude policy already used by Transverse Mercator.

Both aspects use

```text
x = falseEasting + rho * sin(dlon)
```

North aspect:

```text
y = falseNorthing - rho * cos(dlon)
```

South aspect:

```text
y = falseNorthing + rho * cos(dlon)
```

This matches EPSG 9810.

### Reverse

After removing false offsets,

```text
rho = hypot(x, y)
```

The production reverse should use the stable inverse conformal-latitude
iteration already proven conceptually in the existing Transverse Mercator
implementation instead of depending solely on the finite EPSG inverse series.

At `rho == 0` the geographic point is exactly the selected pole. Longitude is
geometrically indeterminate there; the canonical public result shall be the
configured longitude of natural origin.

For nonzero radius:

north aspect:

```text
dlon = atan2(x, -y)
```

south aspect:

```text
dlon = atan2(x,  y)
```

The final public longitude is canonicalized to the library interval
`[-pi,+pi)`.

## Variant B parameterization

EPSG 9829 supplies a latitude of standard parallel `latF` instead of `k0`.

Compute, following EPSG 9829,

```text
mF = cos(latF) / sqrt(1 - e² sin²(latF))
```

and the corresponding conformal radial term `tF`, then

```text
k0 = mF * sqrt((1+e)^(1+e) * (1-e)^(1-e)) / (2*tF)
```

The resulting prepared state is exactly the same state used for variant A.

Recommended public direction:

```d
PolarStereographic!T.tryFromParameters(...)
PolarStereographic!T.fromParameters(...)

PolarStereographic!T.tryFromStandardParallel(...)
PolarStereographic!T.fromStandardParallel(...)
```

The standard-parallel factories are additive construction syntax, not a second
projection implementation.

## Public type and API direction

Use a prepared value object consistent with existing projection families:

```d
struct PolarStereographic(T)
if (isGeodesyScalar!T)
```

Do **not** add a UPS-specific hemisphere enum to this mathematical kernel.

The selected aspect is encoded by the required
`Latitude!T latitudeOfNaturalOrigin`, which must equal +90 or -90 degrees.
This mirrors EPSG 9810 directly and avoids coupling the generic projection to
UTM/UPS policy.

Prepared state should expose read-only:

```text
ellipsoid
latitudeOfNaturalOrigin
longitudeOfNaturalOrigin
scaleFactorAtNaturalOrigin
falseEasting
falseNorthing
```

Operations:

```text
tryForward / forward
tryReverse / reverse
tryForwardFactors / forwardFactors
tryReverseFactors / reverseFactors
```

Checked operations should target:

```text
pure nothrow @safe @nogc
```

Throwing conveniences remain `@safe` and use `GeodesyValueException`.

`PolarStereographic!T.init` should be invalid, consistent with
`TransverseMercator!T`, `PseudoMercator!T`, and prepared coordinate
operations.

## Conformal factors

Polar Stereographic is conformal, so the existing

```d
ConformalProjectionFactors!T
```

is the correct public result carrier.

The GeographicLib formulation gives point scale

```text
k = (rho / a) * secphi * sqrt((1 - e²) + e² / secphi²)
```

with the exact pole taking `k = k0`.

Meridian convergence is the bearing of grid north clockwise from true north,
matching the existing `ConformalProjectionFactors` convention.

For a longitude difference `dlon`:

```text
north: gamma =  dlon
south: gamma = -dlon
```

subject to the library's canonical angle interval.

This lets #38 reuse the established factor type without broadening that type.

## Bounded-domain policy

The generic projection should be deliberately polar rather than advertise a
global stereographic map.

Initial admitted forward domain:

```text
north aspect: latitude in [0, +90 degrees]
south aspect: latitude in [-90 degrees, 0]
all finite canonical longitudes
```

Reasons:

- it covers the complete selected geographic hemisphere;
- it includes UPS and the ordinary Arctic/Antarctic use cases;
- it excludes the opposite-pole singularity by construction;
- it avoids an arbitrary latitude such as 60, 70, or 71 degrees in the generic
  mathematical kernel;
- UPS-specific latitude limits remain policy for #39.

A later evidence-backed extension across the equator is possible without
changing the mathematical representation.

Reverse inputs are accepted only when the recovered latitude lies in the
selected admitted hemisphere and the projected input is finite.

This domain is intentionally broader than standard UPS but narrower than the
formal global stereographic mapping.

## Singular and canonical behavior

### Selected pole

Forward:

- selected pole maps exactly to false easting/false northing;
- longitude does not affect the projected coordinate.

Reverse at the false origin:

- latitude is exactly the selected pole;
- canonical longitude is `longitudeOfNaturalOrigin`;
- convergence is zero under that canonical longitude;
- point scale is exactly `k0`.

### Equator

The equator is included as the closed far boundary of the initial generic
domain. It is finite and useful as a deterministic represented-domain limit.

### Opposite hemisphere and opposite pole

Rejected by the checked API under the initial bounded contract. No infinity or
huge projected coordinate is exposed as a successful public result.

### Longitude branch

Use the existing compensated longitude-difference and canonical-addition policy
from Transverse Mercator rather than direct subtraction/addition. This keeps
antimeridian representation behavior consistent across projections.

## Scalar policy

Match the mature projection policy:

```text
float  -> double working precision -> float public result
double -> double working precision
real   -> real working precision
```

No series-order selection is required for the preferred stable formulation.

All transcendental work remains allocation-free.

## Internal-code reuse

The existing Transverse Mercator implementation already contains stable
conformal latitude helpers conceptually equivalent to what Polar
Stereographic requires.

Do not immediately refactor the stable TM hot path merely to remove textual
duplication.

Implementation sequence:

1. land Polar Stereographic with locally scoped helpers and differential tests;
2. prove bit/numerical behavior and benchmark both kernels;
3. only then consider extracting a small
   `geodesy.internal.conformal_latitude` helper if it reduces maintenance
   without changing generated hot-path code.

D templates can keep helper specialization compile-time and allocation-free,
but reuse is subordinate to regression risk and measured code generation.

## Independent reference vectors

### EPSG 9810 published example

WGS 84 / UPS North parameters:

```text
lat0 = +90 deg
lon0 = 0 deg
k0   = 0.994
FE   = 2,000,000 m
FN   = 2,000,000 m
```

Input:

```text
lat = 73 deg
lon = 44 deg
```

Expected EPSG result:

```text
E = 3,320,416.75 m
N =   632,668.43 m
```

The stable tau/tau-prime formulation independently reproduces approximately:

```text
rho = 1,900,814.563693 m
E   = 3,320,416.747360 m
N   =   632,668.431272 m
```

### EPSG 9829 published example

WGS 84, south aspect:

```text
standard parallel = -71 deg
longitude origin  = 70 deg
FE                 = 6,000,000 m
FN                 = 6,000,000 m
```

Input:

```text
lat = -75 deg
lon = 120 deg
```

EPSG gives:

```text
k0 = 0.97276901
E  = 7,255,380.79 m
N  = 7,053,389.56 m
```

Independent evaluation of the EPSG parameter conversion gives:

```text
k0 = 0.9727690128917972
E  = 7,255,380.793258 m
N  = 7,053,389.560610 m
```

These two cases should become permanent exact/reference regressions.

## Validation program

### PS-A — API and invariants

- construction for north and south variant A;
- variant-B standard-parallel factory;
- invalid `.init`;
- reject non-polar natural origin;
- reject non-finite or non-positive scale;
- reject invalid false offsets;
- preserve ellipsoid/unit semantics;
- aggregate import contract.

### PS-B — analytic and EPSG references

- sphere cases;
- selected pole;
- equator boundary;
- central meridian;
- 90-degree longitude offsets;
- EPSG 9810 example;
- EPSG 9829 example reduced to the same kernel.

### PS-C — PROJ differential corpus

Generate deterministic and randomized north/south corpora across:

- latitude boundary;
- near-pole points;
- antimeridian and branch-boundary longitudes;
- several natural-origin longitudes;
- several valid scale factors and false offsets;
- WGS 84, GRS 80, Airy 1830, and sphere where reference tooling permits.

Validate both forward and reverse.

### PS-D — GeographicLib differential corpus

Use GeographicLib `PolarStereographic` as a second independent oracle for:

- forward/reverse;
- convergence;
- point scale;
- pole handling;
- difficult near-pole inputs.

Do not use GeographicLib's broader prolate domain as an implicit public-domain
extension.

### PS-E — scalar and representation tests

- `float` promoted working precision;
- `double`;
- platform `real`;
- exact branch/canonical longitude cases;
- representable false-origin/pole case;
- reverse round trips at the domain boundary.

### PS-F — compiler/platform gate

At minimum:

- DMD and LDC normal CI;
- controlled six-compiler release-style matrix;
- Linux / Windows / macOS;
- platform-`real` differential tests where wider than `double`.

### PS-G — performance qualification

Benchmark prepared forward/reverse/factor operations separately.

Compare against:

- equivalent PROJ operation when practical;
- GeographicLib `PolarStereographic`;
- internal D debug/release compiler families as already done for mature kernels.

Performance work follows profiling. No broad `@fastmath`.

## Performance expectations

Polar Stereographic should be materially simpler than Transverse Mercator:

- no Krueger coefficient arrays;
- no Clenshaw series;
- small prepared state;
- one conformal-latitude transform plus basic trigonometry per forward point;
- bounded reverse Newton iteration.

The expected implementation should therefore be a strong candidate for a very
small, allocation-free prepared kernel.

The performance target is not merely "faster than PROJ". The target is a
production-quality D kernel competitive with high-quality native
implementations while preserving the checked API and numerical contract.

## UPS boundary for issue #39

Do not bake the following into `PolarStereographic!T`:

- WGS 84-only policy;
- `k0 = 0.994`;
- 2,000,000 m false easting/northing;
- UTM/UPS automatic selection;
- standard latitude cutovers;
- UPS coordinate-range restrictions;
- MGRS policy.

Those belong to #39.

For cross-checking, EPSG:5041 specifies UPS North using EPSG 9810 with

```text
lat0 = +90 deg
lon0 = 0 deg
k0   = 0.994
FE   = 2,000,000 m
FN   = 2,000,000 m
```

and GeographicLib's automatic UTM/UPS policy selects UPS outside the ordinary
UTM interval `[-80 deg, 84 deg)`, while allowing a wider forced-UPS overlap
internally. That distinction reinforces keeping projection mathematics and
grid policy separate.

## Admission result

**ADMIT.**

Implement one prepared `PolarStereographic!T` core with EPSG 9810 public
semantics, optional EPSG 9829 construction by conversion to the same prepared
state, conformal factors through `ConformalProjectionFactors!T`, and the
bounded same-hemisphere domain above.

Proceed next to implementation/validation on
`research/m3-polar-stereographic`. Do not begin #39 UPS implementation until
the #38 kernel and its differential evidence are accepted.
