# Transverse Mercator / UTM projection factors research

Status: GeographicLib factor oracle characterized; no public API accepted

Date: 2026-09-20

Applies to:

- accepted `TransverseMercator!T`;
- accepted `UtmProjection!T`;
- P0 v1.0 projection-factor capability.

## Scope

The admitted capability is deliberately narrow:

- meridian convergence;
- point scale.

It is not a general cartographic-factor framework and does not add:

- CRS metadata;
- authority lookup;
- Tissot indicatrices;
- arbitrary projection derivatives;
- angular distortion APIs;
- area scale APIs;
- automatic operation discovery.

Those are not required by the current `geodesy-d` scope.

## Existing contract

ADR-0006 deliberately deferred convergence and point scale from the first
public Transverse Mercator API while keeping an additive future API possible.

The existing public methods remain:

~~~text
tryForward / forward
tryReverse / reverse
~~~

They must remain source-compatible.

Projection factors therefore require an additive API.

## Primary references

Normative projection semantics:

- IOGP / EPSG Guidance Note 7-2;
- EPSG method 9807, Transverse Mercator.

Numerical/method reference:

- Charles F. F. Karney,
  "Transverse Mercator with an accuracy of a few nanometers",
  Journal of Geodesy 85(8), 475-485 (2011).

Independent implementation references:

- GeographicLib `TransverseMercator`;
- GeographicLib `TransverseMercatorExact`;
- PROJ `proj_factors()` / `PJ_FACTORS`.

External implementations are validation and research evidence, not the
`geodesy-d` public API specification.

## Semantic quantities

### Meridian convergence

Candidate semantic contract:

~~~text
meridianConvergence
~~~

is the signed angle from true north to grid north, positive clockwise.

The public D representation should use:

~~~text
Angle!T
~~~

rather than naked degrees or radians.

The canonical representation should follow the library's existing canonical
angle policy unless research identifies a projection-specific reason not to.

### Point scale

Candidate semantic contract:

~~~text
pointScale
~~~

is the local dimensionless linear scale of the conformal Transverse Mercator
projection.

It includes the configured scale factor at natural origin.

For a valid point it must be finite and positive.

At the central meridian the expected scale is the configured central scale
subject to the mathematical TM semantics.

### Conformality

Transverse Mercator is conformal.

Consequently there is one local point-scale quantity for the admitted API.
A separate meridional and parallel scale pair is not justified for this
bounded slice.

## Numerical implementation direction

Do not implement convergence and scale as an unrelated second numerical
algorithm.

The existing implementation already evaluates the Krueger alpha/beta series
with a complex Clenshaw recurrence.

The reference implementation evaluates, alongside that series, the derivative

~~~text
dzeta / dzeta'
~~~

or its reverse equivalent.

The derivative supplies:

- the additional rotation contributing to meridian convergence;
- the additional magnitude contributing to point scale.

The preferred implementation direction is therefore:

~~~text
existing TM kernel
    +
same-series derivative evaluation
    ->
coordinate + convergence + scale
~~~

This should share the same:

- series order;
- alpha/beta coefficients;
- working scalar;
- domain checks;
- pole handling;
- forward/reverse sheet semantics.

A separate finite-difference derivative is not the preferred production
algorithm.

## False offsets and latitude-of-origin shift

Research hypothesis to verify:

- false easting does not change convergence or point scale;
- false northing does not change convergence or point scale;
- subtracting the projected latitude-of-origin ordinate is a translation and
  therefore does not alter local convergence or scale.

The factors belong to the local projection differential, not to final grid
translations.

This must be verified rather than assumed in the accepted contract.

## Scalar policy

Initial candidate policy follows accepted Transverse Mercator:

~~~text
public float  -> working double
public double -> working double
public real   -> working real
~~~

Factors must be computed in working precision and narrowed only at the public
result boundary.

`real` validation must continue to exercise genuinely wider arithmetic on
platforms where `real` is wider than `double`.

## API design questions

No API is frozen yet.

### Candidate A — operation result types

Possible additive surface:

~~~d
TransverseMercatorForwardResult!T
TransverseMercatorReverseResult!T
~~~

with result properties conceptually containing:

~~~text
coordinate
meridianConvergence
pointScale
~~~

and methods:

~~~text
tryForwardWithFactors / forwardWithFactors
tryReverseWithFactors / reverseWithFactors
~~~

Advantages:

- one numerical pass;
- follows the existing geodesic result-type precedent;
- factors remain associated with the point at which they were evaluated;
- existing `forward` / `reverse` remain unchanged.

Questions:

- whether two result types are preferable to a shared factor value type;
- how UTM should expose the same factors without unnecessary duplication.

### Candidate B — shared factor value plus coordinate result

Possible factor type:

~~~d
TransverseMercatorFactors!T
~~~

with:

~~~text
meridianConvergence
pointScale
~~~

The coordinate and factor value could then be returned through a composite
operation result.

Advantages:

- UTM can reuse exactly the same factor semantics;
- factor data has one named representation.

Cost:

- potentially one additional public type.

### Rejected initial direction — generic projection factors

Do not start with:

~~~text
ProjectionFactors
CartographicFactors
~~~

covering arbitrary projections.

That would freeze a general abstraction before a second projection family has
demonstrated compatible semantics.

## UTM relationship

`UtmProjection!T` is a policy/preparation layer over `TransverseMercator!T`.

Its factors should therefore be numerically identical to the underlying TM
operation for the represented UTM parameters.

The research gate must determine the smallest additive UTM API.

Possible requirements include:

~~~text
prepared UtmProjection forward with factors
prepared UtmProjection reverse with factors
~~~

Automatic zone-selection helpers should not automatically receive new result
types unless a concrete use case requires factors from those helpers.

## Existing validation infrastructure to reuse

The repository already contains factor-capable external reference paths.

`validation/transverse_mercator_exact_corpus.d` invokes GeographicLib
`TransverseMercatorProj` in batch mode. Its output contains:

~~~text
easting
northing
meridian convergence
point scale
~~~

The existing corpus already parses the fourth field as reference point scale
for ground-equivalent projected-position diagnostics. The convergence field is
currently not consumed.

This means PF-C should extend the existing Exact-oracle path rather than create
an unrelated GeographicLib harness.

`benchmarks/tm-reference/source/tm_reference_bridge.cpp` already owns prepared
GeographicLib series/exact and PROJ reference objects. Its current public bridge
functions request only coordinates even though the GeographicLib forward and
reverse APIs can return convergence and scale. That bridge is a natural later
benchmark/reference extension once the research contract is stable.

`validation/utm_geographiclib_oracle.cpp` likewise already asks
`UTMUPS::Forward` for both `gamma` and `scale`; it currently omits them from
the textual result. PF-E should extend that existing oracle instead of adding a
second UTM reference implementation.

## Validation plan

The acceptance program should contain at least:

### PF-A — semantics and API

Freeze:

- convergence sign convention;
- angle canonicalization;
- point-scale semantics;
- default-state semantics;
- public type names;
- named public parameters;
- checked/throwing API;
- UTM delegation policy.

### PF-B — analytical invariants

At minimum:

- central meridian convergence;
- central-meridian scale;
- equatorial symmetry;
- north/south symmetry where mathematically applicable;
- east/west sign behavior of convergence;
- false-offset invariance;
- latitude-of-origin translation invariance;
- forward/reverse factor agreement at the same represented point.

### PF-C — GeographicLib differential

Compare against:

~~~text
TransverseMercator
TransverseMercatorExact
~~~

for:

- projected coordinate;
- meridian convergence;
- point scale.

Use both structured and deterministic pseudo-random corpora across the already
accepted TM domain.

### PF-D — PROJ interoperability

Use PROJ factor output as an independent interoperability check.

For conformal TM verify the relevant PROJ scale quantities agree with the
single admitted `pointScale` semantics.

### PF-E — UTM equivalence

For representative zones, hemispheres and boundaries:

~~~text
UtmProjection factors == equivalent TransverseMercator factors
~~~

within the scalar representation contract.

### PF-F — adversarial/scalar contract

Cover:

- poles;
- +/-60 degree accepted TM longitude boundary;
- sphere;
- f = 0.01 stress ellipsoid;
- public float;
- double;
- platform real;
- invalid prepared values;
- non-finite inputs.

### PF-G — API/runtime and platform gate

Validate:

- DMD minimum frontend;
- current DMD;
- current LDC;
- Linux;
- Windows;
- macOS;
- platform `real` width;
- public API and named-argument compatibility.

## GeographicLib factor-oracle characterization — PASS

Reference environment:

~~~text
GeographicLib 2.7
TransverseMercatorProj
default exact implementation
~~~

Inspection of the GeographicLib tool confirms that
`TransverseMercatorProj` defaults to its exact Transverse Mercator
implementation. The `-s` option explicitly selects the series
implementation.

The initial factor characterization therefore uses an independent exact
numerical oracle rather than the same finite Krueger series family as the
production `geodesy-d` implementation.

The deterministic characterization completed:

~~~text
checks = 72
result = PASS
~~~

Verified invariants:

- meridian convergence is zero on the central meridian;
- point scale on the central meridian equals the configured natural-origin
  scale factor;
- meridian convergence is zero on the equator over the tested bounded
  longitude domain;
- east/west reflection reverses the sign of convergence and preserves point
  scale;
- north/south reflection reverses the sign of convergence and preserves point
  scale;
- changing the natural-origin scale factor leaves convergence unchanged;
- changing the natural-origin scale factor multiplies point scale by the same
  factor.

Representative WGS84 results for:

~~~text
longitude of natural origin = 15 deg
k0 = 0.9996
~~~

are:

~~~text
case              latitude       longitude      convergence deg        point scale
Vienna-like       48.20849000    16.37208000     1.02307584594874      0.99972767498448933
UTM +3 deg        45.00000000    18.00000000     2.12229971657824      1.000287497978489
wide +35 deg      45.00000000    50.00000000    26.3561335642748       1.0938020810076099
wide +55 deg      80.00000000    70.00000000    54.5869300801021       1.0098680665648081
boundary +60 deg  45.00000000    75.00000000    50.8250140307947       1.264145470136337
~~~

The `+60 degree` case is particularly important because it lies on the
accepted bounded Transverse Mercator longitude-domain boundary and still
produces finite convergence and point scale.

These results characterize the oracle and sign convention. They do not yet
define the final `geodesy-d` numerical acceptance tolerances.

### Spherical-oracle exception

GeographicLib 2.7 `TransverseMercatorExact` requires strictly positive
flattening and therefore does not support the exact spherical limit `f = 0`.

The projection-factor differential prototype consequently uses two independent
reference paths:

~~~text
f > 0    GeographicLib TransverseMercatorExact
f = 0    closed-form spherical Transverse Mercator factors
~~~

For the sphere, with geographic latitude `phi`, longitude difference `lambda`
from the central meridian, and central scale `k0`, the research oracle uses:

~~~text
gamma = atan2(sin(lambda) * sin(phi), cos(lambda))

k = k0 / sqrt(
        1 - (cos(phi) * sin(lambda))^2
    )
~~~

False easting, false northing, and the latitude-of-natural-origin northing
translation do not alter these local differential factors.

The GeographicLib series implementation remains useful as a separate
same-family interoperability reference for the sphere, but it is not used as
the independent spherical oracle for this prototype.

### Forward derivative prototype — reproduced results

The private D forward-factor prototype was reproduced on 2026-09-20 with:

~~~text
GeographicLib TransverseMercatorProj 2.7
DMD 2.111.0
LDC 1.41.0, DMD frontend 2.111.0
~~~

The DMD and LDC probes were built from the same source state with
`ProjectionFactorResearch` enabled.

The deterministic differential corpus contains:

~~~text
6 projection profiles
81 structured points/profile
2000 seeded random points/profile
2081 cases/profile
12486 total cases
~~~

Profiles cover:

~~~text
WGS84, UTM-like k0 = 0.9996
WGS84, k0 = 0.9
WGS84, k0 = 1.1
Airy 1830
sphere
synthetic flattening f = 0.01
~~~

For positive flattening, GeographicLib Exact remains the independent oracle.
For the sphere, the closed-form spherical Transverse Mercator factor formulas
described above are used.

After correcting the research harness to compute wrapped angular differences
with `math.remainder(actual - reference, 360.0)` rather than first adding
180 degrees, the reproduced oracle maxima are:

| profile | max `|delta gamma|` | max relative `|delta k|` |
|---|---:|---:|
| WGS84, `k0 = 0.9996` | `1.8891554987021664e-12 deg` | `5.6064455490428346e-14` |
| WGS84, `k0 = 0.9` | `1.8891554987021664e-12 deg` | `5.6042029708232178e-14` |
| WGS84, `k0 = 1.1` | `1.8891554987021664e-12 deg` | `5.5942133042085597e-14` |
| Airy 1830 | `2.4993340730361524e-12 deg` | `5.3208196020296701e-14` |
| sphere | `2.1316282072803006e-14 deg` | approximately `6.4e-16` to `6.8e-16` |
| synthetic `f = 0.01` | `3.9324120626460513e-08 deg` | `1.161586612780204e-09` |

The global oracle worst cases remain the synthetic `f = 0.01` profile:

~~~text
max |delta gamma| = 3.9324120626460513e-08 deg
max |delta k|     = 2.3990778252880318e-09
max relative
    |delta k|     = 1.161586612780204e-09
~~~

The ordinary Earth ellipsoids remain several orders of magnitude closer to the
Exact oracle. The synthetic high-flattening case therefore remains an explicit
characterization point and must not be hidden by selecting tolerances only from
WGS84 behavior.

A direct point-for-point DMD/LDC comparison over the same 12486 cases found:

~~~text
gamma bit differences = 1749 / 12486
scale bit differences = 4274 / 12486

max |DMD - LDC gamma| = 2.1316282072803006e-14 deg
max gamma ULP distance = 5

max |DMD - LDC k| = 1.3322676295501878e-15
max relative |DMD - LDC k| = 8.7071374358997978e-16
max scale ULP distance = 6
~~~

The bitwise differences are small and consistent with ordinary
compiler/backend or math-library rounding variation. They provide no evidence
of a compiler-dependent factor algorithm.

The angle-error helper itself required a research-harness precision correction.
The previous form added 180 degrees before subtraction from 180 degrees and
could therefore lose differences around `1e-14` degrees through floating-point
rounding. The corrected form wraps the small difference directly with
`math.remainder`.

These measurements establish the numerical viability and compiler stability of
the private forward derivative prototype. They are characterization evidence,
not final public projection-factor acceptance tolerances and not a public API
decision.

### Existing Exact-corpus opportunity

The existing
`validation/transverse_mercator_exact_corpus.d` already consumes
`TransverseMercatorProj` output.

That output has four relevant fields:

~~~text
field 0  easting
field 1  northing
field 2  meridian convergence
field 3  point scale
~~~

The current validation already parses field 3 as the reference point scale for
ground-equivalent coordinate-error diagnostics. Field 2 is currently unused.

PF-C should therefore extend the existing exact corpus to compare convergence
and point scale rather than introduce a second GeographicLib batch harness.

The existing UTM oracle has a similar opportunity:
`UTMUPS::Forward` already computes `gamma` and `scale`, although the current
text protocol emits only zone, hemisphere, easting, and northing.

## Private implementation-prototype gate

The next step is a non-public D prototype of the projection-factor
calculation.

The prototype should:

1. preserve the existing coordinate computation unchanged;
2. evaluate the derivative of the same alpha-series Clenshaw recurrence used
   by the forward TM kernel;
3. derive convergence and point scale from the Gauss-Schreiber quantities plus
   that derivative;
4. compare the resulting factors against the GeographicLib exact oracle;
5. avoid freezing public result types or method names.

Only after this differential prototype has passed should PF-A select the
public API shape.

## Initial research conclusion

Projection factors are a natural additive extension of the existing accepted
Transverse Mercator kernel.

Current evidence favors computing them in the same forward/reverse numerical
pass via the derivative of the existing Krueger series.

The public API is not yet frozen.

The next research step is to prototype the derivative computation privately and
compare it against GeographicLib and PROJ before selecting the final result
types.
