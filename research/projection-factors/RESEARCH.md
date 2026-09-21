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

## Forward implementation-prototype gate — PASS

The private forward D prototype has passed its differential and compiler
characterization gate.

Established by the prototype:

1. the existing forward coordinate computation remains unchanged;
2. convergence and point scale can be derived from the same alpha-series
   Clenshaw family used by the accepted forward TM kernel;
3. the derivative prototype agrees closely with GeographicLib Exact for
   ordinary Earth ellipsoids;
4. the spherical case agrees with an independent closed-form oracle near
   floating-point precision;
5. the synthetic `f = 0.01` case remains an explicit high-flattening
   characterization point;
6. DMD and LDC differ only by a few ULP over the deterministic 12486-case
   corpus;
7. the research implementation remains version-gated and package-internal.

This gate establishes numerical viability. It does not select a public result
type, public method name, or final acceptance tolerance.

## Reverse-factor research gate

The next research question is how factors should be obtained for a represented
projected input passed to the reverse TM operation.

Three candidate paths must be distinguished:

~~~text
A. represented projected input
   -> public reverse result
   -> factor evaluation at the narrowed public geographic value

B. represented projected input
   -> reverse kernel
   -> existing pole and sheet-boundary policy
   -> post-policy working-precision latitude and longitude difference
   -> the same factor kernel used by forward

C. represented projected input
   -> direct differentiation/inversion of the reverse beta-series
~~~

The first hypothesis to test is B.

It preserves the existing represented-input reverse semantics while avoiding
an unnecessary public-scalar geographic narrowing before factor evaluation.
It would also permit forward and reverse to share one factor kernel rather
than duplicate the factor mathematics.

Path C is not justified merely for mathematical symmetry. It should be
investigated only if measurement shows that factors evaluated at the internal
working-precision inverse point fail the required reverse accuracy or
semantics.

The reverse prototype must therefore determine:

1. the exact working state available after `reverseKernel`;
2. whether existing boundary and represented-value handling changes that
   working point before public return;
3. the error of path B against an independent oracle for the same represented
   projected input;
4. the additional error introduced by path A, especially for `float`;
5. whether any observed error requires path C.

## Reverse candidate B — double characterization PASS

Candidate B was evaluated with the same deterministic six-profile corpus used
for the forward prototype:

~~~text
2081 cases/profile
12486 total cases
DMD 2.111.0
LDC 1.41.0
~~~

For each geographic corpus point, geodesy-d first produced the represented
`ProjectedCoordinate!double`. That exact represented E/N pair was then:

1. reversed by the research candidate B path;
2. evaluated with the shared post-policy working-point factor kernel;
3. independently reversed by GeographicLib Exact for comparison.

For positive flattening the reverse oracle uses `TransverseMercatorProj -r`.
The projection's latitude-of-natural-origin northing offset is restored before
calling the GeographicLib reverse operation. The spherical profile continues
to use the independent closed-form spherical oracle.

Representative DMD maxima for candidate B are:

| profile | max `|delta gamma|` | max relative `|delta k|` |
|---|---:|---:|
| WGS84, `k0 = 0.9996` | `1.886713008047991e-12 deg` | `5.6284316100194865e-14` |
| WGS84, `k0 = 0.9` | `1.8978152382942426e-12 deg` | `5.6286221558812851e-14` |
| WGS84, `k0 = 1.1` | `1.8967050152696174e-12 deg` | `5.5742339709792568e-14` |
| Airy 1830 | `2.4780177909633494e-12 deg` | `5.3867801756085609e-14` |
| sphere | `5.6843418860808015e-14 deg` | `6.0578418947633963e-16` |
| synthetic `f = 0.01` | `3.9257173511941801e-08 deg` | `1.1596813266592617e-09` |

The global worst case therefore remains the deliberate synthetic
high-flattening profile, at essentially the same magnitude already observed in
the forward characterization.

Candidate A was also measured:

~~~text
represented E/N
-> public reverse GeographicCoordinate<double>
-> forward factor evaluation
~~~

For `double`, A and B are numerically almost indistinguishable over this
corpus. The DMD global A/B maxima are:

~~~text
max |delta gamma|       = 2.1316282072803006e-14 deg
max relative |delta k|  = 4.7243152193565324e-16
~~~

The corresponding LDC maxima remain of the same scale:

~~~text
max |delta gamma|       = 2.1316282072803006e-14 deg
max relative |delta k|  = 5.0522804713848751e-16
~~~

The public reverse geographic position also remains extremely close to the
independent reverse oracle for the ordinary ellipsoid profiles. The synthetic
`f = 0.01` case shows the expected larger, but still small, reverse-position
difference.

This double-precision evidence supports candidate B and provides no numerical
reason to implement candidate C, the separate differentiation/inversion of the
reverse beta-series.

### Remaining reverse questions

The current corpus starts from geographic points projected by geodesy-d and
then evaluates the exact same represented projected coordinates independently.
It therefore validates reverse factors at represented round-trip points, but
does not yet exhaust all possible externally supplied represented projected
inputs.

The next reverse characterization must cover:

1. `float`, where public geographic narrowing may be materially
   larger;
2. A versus B for the same represented float E/N input;
3. independently represented projected inputs rather than only geodesy-d
   forward products;
4. explicit represented +/-60-degree boundary cases;
5. rejected just-outside-domain cases;
6. poles once PF-A selects the convergence convention.

Only if these measurements expose a deficiency in the shared working-point
factor kernel should candidate C be reopened.

## Current research conclusion

Projection factors remain a natural additive extension of the accepted
Transverse Mercator implementation.

Forward numerical viability is established, and reverse candidate B has now
passed its initial double-precision characterization.

The evidence currently supports one shared working-precision factor kernel fed
by the post-policy working coordinates of either the forward or reverse path.
A separate reverse beta-series factor implementation is not justified by the
double-precision measurements.

Float represented-value behavior, independent projected inputs, sheet
boundaries, and pole semantics remain open research questions.

The public API remains unfrozen.
