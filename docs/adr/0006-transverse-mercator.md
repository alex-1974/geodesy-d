# ADR-0006: Bounded Transverse Mercator for geodesy-d

- Status: Accepted
- Date: 2026-09-14
- Applies to: generic Transverse Mercator and EPSG method 9807
- Supersedes: nothing

## Context

`geodesy-d` needs a reusable Transverse Mercator implementation before UTM can
be added as a thin policy layer.

The operation belongs in `geodesy-d` because it is bounded projection
mathematics over an ellipsoid. CRS databases, operation discovery, WKT/PROJJSON,
grid resources, and general transformation pipelines remain outside this
library and belong in a future `proj-d` integration layer.

The implementation must follow the existing `geodesy-d` design:

- pure-D numerical core;
- explicit scalar semantics for `float`, `double`, and `real`;
- strong coordinate-domain types;
- allocation-free numerical hot paths;
- checked non-throwing APIs with throwing convenience wrappers where practical;
- no broad `@fastmath`;
- independent numerical validation;
- a deliberately bounded public contract rather than an unqualified claim of
  global projection accuracy.

The relevant normative coordinate-operation method is EPSG 9807, Transverse
Mercator.

EPSG 9807 parameterizes the operation with:

- latitude of natural origin;
- longitude of natural origin;
- scale factor at natural origin;
- false easting;
- false northing.

This is broader than UTM. In particular, a generic implementation must not
assume that the latitude of natural origin is zero.

At the same time, the high-quality numerical implementations studied during
research use a simpler equatorial Transverse Mercator kernel and apply the
northing of a non-equatorial origin as a constant offset. This separation is
useful and should be retained internally.

## Decision

Implement a bounded, generic Transverse Mercator operation using the
Krüger/Karney series formulation.

The public operation models EPSG 9807 semantics. The internal numerical kernel
uses an equatorial origin and is independent of UTM zoning rules.

### Public operation object

Introduce a prepared value type conceptually equivalent to:

~~~d
TransverseMercator!T
~~~

It owns the immutable projection parameters and precomputed coefficients needed
by forward and reverse operations.

Its public parameter set is:

~~~text
Ellipsoid<T>
Latitude<T>  latitudeOfNaturalOrigin
Longitude<T> longitudeOfNaturalOrigin
T            scaleFactorAtNaturalOrigin
T            falseEasting
T            falseNorthing
~~~

Construction must reject non-finite linear/scalar parameters, a non-positive
scale factor, and an invalid ellipsoid.

The type should precompute all coefficient arrays and origin-dependent
northing terms once. Repeated forward/reverse calls must not rebuild them.

### Coordinate types

Introduce a two-dimensional geographic coordinate type:

~~~d
GeographicCoordinate<T>
~~~

containing:

~~~text
Latitude<T>
Longitude<T>
~~~

Introduce a two-dimensional projected coordinate type:

~~~d
ProjectedCoordinate<T>
~~~

containing:

~~~text
easting
northing
~~~

Both linear projected components use the same linear unit as the ellipsoid
semi-major axis and the false easting/northing parameters.

`GeographicCoordinate<T>` is a two-dimensional latitude/longitude value. It
does not carry datum or CRS identity.

`ProjectedCoordinate<T>` is specifically a canonical easting/northing pair. It
does not represent an arbitrary projected-CRS axis tuple and does not carry CRS,
axis-order, or unit metadata. Those concerns remain outside `geodesy-d`.

`GeodeticCoordinate<T>` must not be used as the primary Transverse Mercator
coordinate type because its ellipsoidal height has no role in EPSG 9807.

A future EPSG 1111 Transverse Mercator 3D wrapper may preserve height unchanged,
but that is a separate operation and is not part of this ADR.

### Public API shape

The checked API should follow existing `geodesy-d` conventions:

~~~d
bool tryForward(..., out ProjectedCoordinate!T result)
bool tryReverse(..., out GeographicCoordinate!T result)
~~~

with throwing convenience wrappers:

~~~d
ProjectedCoordinate!T forward(...)
GeographicCoordinate!T reverse(...)
~~~

The checked numerical path should remain:

~~~text
pure
nothrow
@safe
@nogc
~~~

where the final implementation can establish these attributes without weakening
correctness.

### Internal mathematical decomposition

The operation is implemented as:

~~~text
geographic latitude/longitude
        ↓
longitude difference from central meridian
        ↓
equatorial Transverse Mercator kernel
        ↓
central scale
        ↓
origin northing correction
        ↓
false easting / false northing
~~~

The reverse path applies the exact inverse sequence.

This keeps EPSG method parameterization separate from the numerical series
kernel.

The latitude of natural origin is therefore not built into the core Krüger
mapping. Instead, the constructor evaluates the true northing of the natural
origin on the central meridian and stores the required constant correction.

### Numerical method

Use the Krüger series in the third flattening:

~~~text
n = f / (2 - f)
~~~

following the numerical structure described by Karney and used by mature
Transverse Mercator implementations.

The implementation should use:

- precomputed series coefficients;
- Horner evaluation for coefficient polynomials;
- Clenshaw summation for the complex trigonometric series;
- stable `hypot`/`asinh`/`atan2` forms where they avoid unnecessary overflow or
  cancellation;
- Newton iteration for the reverse conversion from conformal/isometric latitude
  to geodetic latitude;
- explicit longitude-difference normalization;
- explicit pole handling.

The source implementation must document the algebraic invariants that are not
obvious from the public API.

### Series order

Use a sixth-order series for public `float`, evaluated in `double` working
precision.

Use an eighth-order series for public `double` and `real`.

The working-scalar policy is therefore:

~~~text
public float  -> working double -> order 6
public double -> working double -> order 8
public real   -> working real   -> order 8
~~~

This policy is evidence-driven rather than selected solely from machine
precision. Differential validation against GeographicLib
`TransverseMercatorExact` showed that sixth order is not sufficient for the
documented worst-case operation domain: on the synthetic `f = 0.01` ellipsoid
at `abs(deltaLongitude) = 60 deg`, sixth order produced about 26.6 mm projected
position error near the equator. The same implementation with eighth-order
coefficients reduced the worst observed projected-position error in the
structured Exact corpus to about 0.407 mm.

`real` therefore remains eighth order even on platforms where it has only
binary64 precision. This keeps the public accuracy policy independent of
platform-specific `real` representation and avoids silently weakening the
validated series truncation bound.

The series order is an implementation decision, not a caller-selectable runtime
option in the initial API.

### Float working precision

Public `float` coordinates and projection parameters remain `float`, but the
numerical Transverse Mercator kernel is evaluated internally in `double`.

Results are rounded back to `float`.

This follows the existing precedent established for the numerically sensitive
EPSG 9602 inverse and avoids building a second, lower-accuracy single-precision
series implementation merely to preserve intermediate `float` arithmetic.

### Sphere

A spherical `Ellipsoid<T>` remains supported.

The implementation must use a mathematically valid spherical limit/path and
must not rely on ellipsoidal formulas whose constants become singular as
`f -> 0`.

The spherical path must obey the same public parameter semantics and coordinate
types as the oblate path.

### Prolate ellipsoids

Prolate ellipsoids remain outside the current `Ellipsoid<T>` domain and are
therefore outside this Transverse Mercator implementation.

No additional prolate support is introduced by this ADR.

### Supported ellipsoid shape for the series implementation

The first Transverse Mercator implementation is intentionally limited to
spherical and moderately oblate ellipsoids:

~~~text
0 <= flattening <= 0.01
~~~

This is a stricter domain than `Ellipsoid<T>` itself.

The bound keeps the initial operation in the regime for which a low-order
series in the third flattening is a well-conditioned engineering choice and
comfortably includes the terrestrial ellipsoids targeted by this project.

Construction fails for a valid `Ellipsoid<T>` whose flattening exceeds this
projection-specific bound.

The bound is not claimed to be the mathematical limit of Transverse Mercator.
It may be widened by a later ADR if independent validation justifies doing so,
or bypassed by a future exact Transverse Mercator implementation.

The validation corpus must include a synthetic ellipsoid at the `f = 0.01`
boundary in addition to the named terrestrial ellipsoids.

### Bounded projection domain

The initial public series implementation is deliberately bounded.

For non-polar points the normalized angular difference from the longitude of
natural origin must satisfy:

~~~text
abs(deltaLongitude) <= 60 degrees
~~~

Forward calls outside this domain fail through the checked API.

Reverse calls are accepted only for projected coordinates that recover to the
same supported sheet/domain, with a representation-aware boundary
classification for coordinates that are the rounded image of a valid boundary
point.

Reverse starts from represented projected coordinates. Rounding easting and
northing can therefore move the recovered longitude slightly outside the
nominal +/-60-degree boundary even when the unrounded projected point lies
exactly on it. The effect is strongest at high latitude, where longitude is
ill-conditioned because the radius of the parallel becomes small.

Within the ordinary terrestrial accuracy profile, reverse boundary
classification converts any longitude excess beyond +/-60 degrees to a local
first-order east-west distance using:

~~~text
boundaryDistance ~= N(phi) * cos(phi) * excessDeltaLongitude
~~~

where `N(phi)` is the ellipsoidal prime-vertical radius of curvature. The
represented projected input may be accepted only while this boundary distance
is within the scalar's published absolute accuracy budget:

~~~text
float:       2 m
double/real: 1 mm
~~~

An accepted representation-level excess is clamped back to the exact
+/-60-degree boundary before the public geographic result is formed. This is a
numerical classification tolerance for reverse projection; it does not widen
the public geographic domain and it does not change forward-domain semantics.
Outside the ordinary terrestrial profile, reverse retains only the ordinary
angular/representation slack and no fixed metre-based boundary guarantee is
made.

The poles are treated specially because geographic longitude is degenerate
there.

This bound is intentionally much wider than UTM and ordinary national
Transverse Mercator use.

It is a library contract, not a claim that the mathematical projection ceases
to exist at 60 degrees. For the supported flattening range it also remains
comfortably on the central-meridian side of the equatorial branch-point region.

A future exact Transverse Mercator implementation may expand this domain. It
must not silently change the semantics of the bounded series implementation.

### Longitude normalization

Longitude differences must be reduced deterministically across the
antimeridian.

The implementation must not depend on naive subtraction followed by ad-hoc
comparison because nearly opposite longitude values can lose useful low-order
information.

The exact helper design is an implementation detail, but validation must cover:

- natural origin near +180 degrees;
- natural origin near -180 degrees;
- source longitude on the opposite representation of the same meridian;
- exact and near-exact +/-180-degree differences;
- signed zero where observable in intermediate arithmetic.

### Pole semantics

At latitude +/-90 degrees the projected point is independent of source
longitude on the standard sheet.

For reverse projection of a projected pole, the returned canonical longitude
is:

~~~text
longitudeOfNaturalOrigin
~~~

This makes reverse output deterministic.

### False easting and false northing

False easting and false northing are part of the public EPSG 9807 operation
semantics.

They are applied as final translations in forward projection and removed before
the reverse numerical kernel.

They must not be embedded in the core series coefficients.

### Meridian convergence and point scale

The numerical kernel may compute meridian convergence and point scale
internally for validation and future use.

They are not part of the initial public API.

This avoids expanding the API before a concrete consumer requires these
quantities while preserving the option to add a compatible
`forwardWithFactors`/`reverseWithFactors` style API later.

### Failure semantics

Projection construction fails for:

- an invalid/uninitialized ellipsoid;
- flattening outside the projection-specific range `0 <= f <= 0.01`;
- a non-finite or non-positive scale factor;
- non-finite false easting or false northing.

The checked forward/reverse API returns `false` for:

- an invalid/uninitialized projection value;
- non-finite projected inputs;
- finite arithmetic producing a non-finite intermediate/result;
- forward inputs outside the bounded longitude domain;
- reverse results outside the bounded supported sheet/domain;
- failure of reverse Newton iteration to converge within a documented bound.

The throwing wrapper converts the same condition to `GeodesyValueException`.

Internal assertions are reserved for implementation invariants and must not be
used for malformed caller input.

### Accuracy contract

Accuracy must be established by validation before the ADR is changed from
`Proposed` to `Accepted`.

The contract has two layers because arbitrary scale factors and large false
offsets can make final scalar representation error dominate the intrinsic
projection error.

#### Intrinsic projection accuracy

For the validated geographic/ellipsoid domain, measure intrinsic projection
error as ground-equivalent error:

~~~text
groundEquivalentError =
    hypot(deltaEasting, deltaNorthing) / referencePointScale
~~~

using an independent high-accuracy reference.

The target is:

~~~text
float:
    ground-equivalent position error <= 2 m

double:
    ground-equivalent position error <= 1 mm

real:
    ground-equivalent position error <= 1 mm
~~~

For reverse transformation, the returned geographic coordinate is projected by
the independent reference and compared with the original projected input before
the same scale normalization is applied.

#### End-to-end represented-coordinate accuracy

The same absolute targets must also hold for the ordinary terrestrial
parameter profile used by UTM and national Transverse Mercator systems.

The initial validation profile is:

~~~text
semi-major axis:
    6,000,000 m <= a <= 7,000,000 m

flattening:
    0 <= f <= 0.01

scale factor:
    0.9 <= k0 <= 1.1

false easting / false northing:
    abs(offset) <= 2 * a

longitude difference:
    abs(deltaLongitude) <= 60 degrees
~~~

Construction is not restricted to the `a`, `k0`, or false-offset validation
ranges above. Outside them, the operation follows the same mathematical
semantics, but no fixed absolute metre error is promised until separately
validated.

In particular, arbitrarily large finite false offsets cannot have a scalar-
independent absolute accuracy guarantee because final `float`, `double`, or
`real` quantization eventually dominates.

Large-offset and extreme-scale stress tests therefore report both intrinsic
projection error and final output error in representational/ULP terms rather
than applying the ordinary terrestrial absolute limit blindly.

The contract concerns numerical coordinate-transformation error only. It does
not describe datum accuracy, reference-frame accuracy, observation error,
survey accuracy, GNSS accuracy, or physical-position accuracy.

The initial named validation set includes at least:

- WGS 84;
- GRS 80;
- Airy 1830;
- Bessel 1841;
- Clarke 1866;
- International 1924;
- an Earth-sized sphere;
- a synthetic oblate ellipsoid at `f = 0.01`.

No equivalent millimetre contract is implied outside the validated parameter
profile until independent evidence establishes it.

### UTM layering

UTM is not implemented in this ADR.

A later UTM layer will supply policy:

- zone number;
- zone central meridian;
- scale factor 0.9996;
- false easting 500000;
- hemisphere-dependent false northing;
- legal latitude range;
- Norway/Svalbard special-zone rules where applicable.

It must delegate projection mathematics to the verified generic Transverse
Mercator implementation.

### EPSG methods not included

This ADR does not implement:

- EPSG 9808, Transverse Mercator (South Orientated);
- EPSG 1111, Transverse Mercator 3D;
- arbitrary CRS definitions or EPSG database lookup;
- automatic operation discovery.

These may be added as explicit higher-level operations if real consumers require
them.

### Exact Transverse Mercator

A Lee/Karney exact Transverse Mercator based on elliptic functions is deferred.

It is not required for the initial UTM/national-grid use cases and would add
substantially more algorithmic and branch-cut complexity.

The exact method remains an independent validation/reference implementation and
a possible future extension when a consumer requires a substantially wider
domain.

### Floating-point optimisation policy

Broad `@fastmath` is not enabled.

FMA, explicit SIMD, algebraic reassociation, or target-specific code generation
may only be introduced after:

- correctness is established;
- an LDC release baseline exists;
- a relevant hot path is measured;
- the numerical contract is revalidated.

The scalar algorithm and data layout are optimized before architecture-specific
micro-optimisation.

## Validation evidence recorded during implementation

The numerical implementation has now passed the large independent
GeographicLib Exact corpora for public `double` and `float`, and the dedicated
spherical validation sub-gate.

For the seven applicable oblate ellipsoids, including the synthetic
`f = 0.01` boundary ellipsoid, GeographicLib 2.7
`TransverseMercatorExact` gives the following large-corpus results.

`double`, eighth-order:

~~~text
structured source points: 251853
structured forward comparisons: 251853
structured reverse comparisons: 251853
structured outside 1 mm target: 0
structured worst absolute projected error: 0.00040720961988 m
structured worst ground-equivalent error: 0.000197241839122 m

random source points: 500000
random forward comparisons: 500000
random reverse comparisons: 500000
random outside 1 mm target: 0
random worst absolute projected error: 0.00040489314832 m
random worst ground-equivalent error: 0.000185580763518 m
~~~

The same wide synthetic stress boundary with sixth-order coefficients was about
26.63 mm from the Exact reference. This is the evidence for selecting order 8
for public `double` and `real`.

Public `float` uses double working precision and sixth-order coefficients:

~~~text
structured source points: 251853
structured outside 2 m target: 0
structured worst absolute projected error: 0.996066963705 m
structured worst ground-equivalent error: 0.996106511573 m

random source points: 500000
random outside 2 m target: 0
random worst absolute projected error: 1.34535363361 m
random worst ground-equivalent error: 1.17173743512 m
~~~

The promoted double twin remains within about 0.407 mm of Exact, while almost
all public float forward outputs exactly match the correctly rounded Exact
coordinate pair. This supports the conclusion that the observed metre-scale
float maxima are dominated by binary32 coordinate representation rather than
the promoted numerical kernel.

The `f = 0` spherical sub-gate is independently complete. Eight projection
profiles were tested against direct analytic spherical Transverse Mercator
formulas.

~~~text
double structured source points: 291912
double structured outside 1 mm target: 0
double structured worst absolute error: 1.49011611938e-08 m

double random source points: 500000
double random outside 1 mm target: 0
double random worst absolute error: 1.53597653866e-08 m

float structured source points: 291912
float structured outside 2 m target: 0
float structured worst absolute error: 1.40418094005 m

float random source points: 500000
float random outside 2 m target: 0
float random worst absolute error: 1.40217080524 m
~~~

Structured spherical corpora pass under both DMD and LDC. The deterministic
random corpora were also cross-compiler checked during validation.

The analytic spherical oracle is itself independently cross-checked against
GeographicLib 2.7 `TransverseMercator` with `f = 0` and PROJ spherical `tmerc`.
GeographicLib agrees at approximately nanometre scale in both structured and
random external corpora.

PROJ 9.7.1 exposes the known upstream spherical-equator numerical instability
tracked as PROJ issue #4673. The validation harness classifies that defect
separately for affected PROJ versions instead of weakening the numerical
tolerance. It is non-gating only when GeographicLib independently satisfies the
strict oracle target. Other PROJ disagreements remain failures.

The deterministic reverse-domain boundary/property gate is also complete.

The initial implementation converted represented reverse excursions beyond
+/-60 degrees into an angular tolerance using
`N(phi) * cos(phi) * dLambda`. A dedicated property probe demonstrated that
this was not sufficient to enforce the public projected-coordinate accuracy
contract: for `float` at `k0 = 1.1`, 16 spherical near-pole outside cases were
accepted even though their represented projected distance from the returned
boundary exceeded 2 m. The worst observed residual was approximately 2.267 m,
and the result reproduced under both DMD and LDC.

Reverse boundary classification now measures the represented projected E/N
distance directly against the public +/-60-degree boundary point. The completed
DMD/LDC property gate reports:

~~~text
double boundary cases: 120
double boundary rejects: 0
double outside accepted beyond 1 mm: 0
double worst accepted outside residual: 0.000213479484405 m

float boundary cases: 108
float boundary rejects: 0
float outside accepted beyond 2 m: 0
float worst accepted outside residual: 1.39297150223 m
~~~

Acceptance of some outside source positions within those budgets is deliberate:
near the poles their represented projected coordinates are numerically
indistinguishable from the public boundary at the scalar accuracy contract.

A permanent regression covers the previously failing public-float
`k0 = 1.1`, latitude 89 deg, `deltaLongitude = +60.001 deg` case. Its
represented projected distance from the +60-degree boundary is approximately
2.2647 m and reverse therefore rejects it.

The large Exact and spherical structured/random corpora remained unchanged and
passing after this classifier change.

The public `real` numerical gate is now also complete on the validated
x86_64 Linux DMD/LDC platform. Both compilers expose `real` as a 16-byte type
with a 64-bit mantissa (`real.mant_dig = 64`) versus 53 bits for `double`.

A dedicated precision-preservation probe uses two source longitudes separated
by `2^-58` radians which collapse to the same binary64 value. The public
`TransverseMercator!real` path preserves their distinction, and the projected
difference agrees with an independent analytic spherical oracle evaluated
entirely in D `real`.

The analytic spherical `real` structured and 500000-point deterministic random
corpora pass under both DMD and LDC. The random worst absolute projected error
is approximately `6.43e-12 m`.

The ellipsoidal `real` contract gate uses GeographicLib 2.7
`TransverseMercatorExact`. The installed GeographicLib uses
`GEOGRAPHICLIB_PRECISION=2`, so its `Math::real` is binary64. It is therefore
used as a high-accuracy independent oracle for the public 1 mm contract, not as
proof of every additional bit in D's wider `real`. Production projection and
ellipsoid parameters remain full-width D `real`.

Structured Exact results:

~~~text
DMD:
  forward comparisons: 255423
  reverse comparisons: 255423
  outside 1 mm target: 0
  worst absolute projected error: 0.00040720827837546 m
  worst ground-equivalent error:  0.000197241195835044 m

LDC:
  forward comparisons: 255423
  reverse comparisons: 255423
  outside 1 mm target: 0
  worst absolute projected error: 0.000407208169236107 m
  worst ground-equivalent error:  0.000197241136467626 m
~~~

Deterministic pseudo-random Exact results over 84 projection profiles:

~~~text
DMD:
  source points: 500000
  forward comparisons: 500000
  reverse comparisons: 500000
  outside 1 mm target: 0
  worst absolute projected error: 0.000391767033195987 m
  worst ground-equivalent error:  0.000191835823482898 m

LDC:
  source points: 500000
  forward comparisons: 500000
  reverse comparisons: 500000
  outside 1 mm target: 0
  worst absolute projected error: 0.000391767043002733 m
  worst ground-equivalent error:  0.000191834013051923 m
~~~

The approximately 0.407 mm structured maximum essentially matches the
eighth-order wide-domain truncation floor already seen for `double`, while the
spherical `real` path is several orders of magnitude more accurate. This is
evidence that the wider arithmetic is preserved and that the extreme
`f = 0.01`, approximately +/-60-degree ellipsoidal maximum is limited by the
selected eighth-order series rather than scalar roundoff.

These results establish the selected `float`, `double`, `real`, spherical, and
bounded reverse-domain numerical paths on the currently validated platform.
They do **not** promote this ADR to `Accepted`. Reverse-Newton instrumentation is complete on the validated x86_64 Linux
DMD/LDC platform. Across the structured corpus and a deterministic
500000-point pseudo-random corpus per scalar, every accepted Newton-applicable
reverse case converged within at most two iterations; the production limit is
five. Failure count was zero for `float`, `double`, and `real`. The sphere path
was separately verified and requires exactly one zero-correction iteration for
every Newton-applicable point.

The reproducible LDC release performance baseline is also complete on the
controlled x86_64 Linux reference platform. A second controlled run reproduced
all recorded medians within 1.40 %, below the predeclared 3 % limit, while the
benchmark numerical preflight showed no correctness regression.

The required additional platform/architecture coverage is now complete.

The GitHub Actions platform matrix passed on Linux, Windows, and macOS across
x86_64 and AArch64 targets. It also exercised three materially different D
`real` representations: 53-bit, 64-bit, and 113-bit mantissas.

The public `double` contract remained stable on every target, including targets
without extended `real` precision. The wider-`real` precision-preservation gate
also passed on both 64-bit-mantissa and 113-bit-mantissa targets.

Together with the completed semantics, numerical-accuracy, boundary,
API/runtime, reverse-Newton, and reproducible performance gates, this satisfies
the acceptance criteria for the generic bounded Transverse Mercator design.

ADR 0006 is therefore `Accepted`.

### Multi-platform acceptance evidence

The final portability gate was executed through GitHub Actions.

~~~text
Linux x86_64 / LDC       PASS   real mantissa 64
Linux x86_64 / DMD       PASS   real mantissa 64
Linux AArch64 / LDC      PASS   real mantissa 113

Windows x86_64 / LDC     PASS   real mantissa 53
Windows AArch64 / LDC    PASS   real mantissa 53

macOS x86_64 / LDC       PASS   real mantissa 64
macOS AArch64 / LDC      PASS   real mantissa 53
~~~

This is significant for the numerical contract because D `real` is explicitly
target-dependent. The implementation succeeds when `real` aliases binary64
precision, when it uses an extended 64-bit mantissa, and when it exposes a
113-bit mantissa.

No public `double` result depends on architecture-specific extended
intermediates.

## Alternatives considered

### Direct transcription of the EPSG series

Advantages:

- closely follows the normative guidance;
- comparatively compact.

Not selected as the production numerical method because the mature
Krüger/Karney formulation provides a better studied high-accuracy series,
stable evaluation techniques, and independent reference implementations while
remaining semantically compatible with EPSG 9807.

EPSG remains normative for operation semantics.

### Fourth-order Krüger series

Advantages:

- fewer coefficients;
- slightly less arithmetic.

Rejected for the initial binary64 implementation because sixth order provides a
substantially stronger accuracy margin at negligible expected additional cost.

### Eighth order for every scalar

Advantages:

- simpler single policy;
- lower truncation error.

Rejected for public `float`: its 2 m accuracy target does not justify the extra
series terms when the kernel already evaluates in `double` working precision.

For `double` and `real`, however, eighth order is selected. Exact-reference
validation demonstrated a concrete numerical benefit at the documented
`f = 0.01`, `abs(deltaLongitude) = 60 deg` stress boundary: sixth order exceeded
the 1 mm target by more than an order of magnitude, while eighth order remained
below the target in the structured corpus.

### Evenden/Snyder approximate path

Advantages:

- fast near the central meridian;
- mature historical implementation.

Rejected from the initial design because it creates multiple numerical paths
and switching semantics before profiling has shown a need.

### PROJ-style automatic algorithm switching

Advantages:

- may improve performance near the central meridian.

Rejected initially because it adds heuristic branch selection and additional
validation burden without evidence that a scalar `geodesy-d` TM kernel needs
it.

### Poder/Engsager implementation copied directly from PROJ

Advantages:

- mature;
- sixth order;
- production proven.

Not selected as the specification.

PROJ remains a production-compatibility and same-family differential target.
Its Poder/Engsager path is sixth order, so it is not the primary accuracy oracle
for the eighth-order `double`/`real` implementation at the deliberately wide
stress boundary. GeographicLib `TransverseMercatorExact` is the primary
high-accuracy oracle there.

The implementation should follow primary mathematical provenance rather than
mechanically reproduce another library's internal API or source structure.

### GeographicLib API copied directly

Advantages:

- high quality;
- convergence and scale already exposed.

Rejected as the public API specification because `geodesy-d` should model its
own domain and current consumer requirements.

GeographicLib remains a numerical and implementation reference.

### Accept every oblate `Ellipsoid<T>` supported by the core type

Advantages:

- widest nominal genericity;
- no projection-specific constructor restriction.

Rejected for the first series implementation because the finite Krüger series
uses flattening as a small parameter and the equatorial branch-point geometry
moves substantially for highly flattened ellipsoids.

The initial `f <= 0.01` bound is deliberately conservative and can be widened
only after targeted validation.

### Exact Transverse Mercator as the only implementation

Advantages:

- much wider valid domain;
- error close to roundoff across the ellipsoid.

Deferred because the intended UTM and national-grid use cases do not require
that complexity and the exact method is significantly more expensive and
substantially more complicated.

### Use `GeodeticCoordinate<T>` and ignore height

Rejected because silently discarding an existing domain component is
semantically misleading.

### Make UTM the first projection API

Rejected because UTM is policy over Transverse Mercator, not the underlying
projection mathematics. Implementing UTM first would entangle zone rules with a
kernel that has wider independent value.

## Validation requirements

Before acceptance and release, the implementation must pass the dedicated
Transverse Mercator validation plan.

At minimum this includes:

- EPSG/IOGP worked examples;
- GeographicLib exact Transverse Mercator comparison;
- GeographicLib series comparison;
- PROJ `tmerc` comparison using a deterministic high-accuracy algorithm path;
- deterministic boundary/adversarial cases;
- multi-ellipsoid scalar-generic sweeps;
- independent forward and reverse accuracy checks;
- explicit separation of accuracy validation from self-roundtrip tests;
- compiler coverage under DMD and LDC;
- an LDC release performance baseline.

The detailed matrix is maintained in
`docs/TRANSVERSE_MERCATOR_VALIDATION_PLAN.md` until the implementation is
accepted. Stable achieved results should then be summarized in
`docs/VALIDATION.md`.

## Performance requirements

Performance optimization follows correctness.

The initial benchmark must measure forward and reverse separately under LDC
release mode.

Reference comparisons should be in-process against:

- PROJ;
- GeographicLib series;
- GeographicLib exact where useful as a cost reference.

Benchmark documentation must record:

- CPU;
- compiler and D frontend;
- LLVM version for LDC;
- dependency versions;
- build mode and relevant flags;
- affinity where controlled;
- governor/frequency/turbo state where materially relevant;
- corpus size and number of rounds.

No cause such as branch distribution, cache locality, vectorization, or Newton
iteration count may be claimed unless it was instrumented.

## Consequences

### Positive

- establishes a reusable projection kernel before UTM policy;
- preserves full EPSG 9807 parameter semantics;
- keeps CRS-engine concerns out of `geodesy-d`;
- gives a high-accuracy binary64 path with modest algorithmic complexity;
- preserves `float` API usability through double working precision;
- makes the supported series domain explicit;
- keeps projected and geographic 2D semantics type-safe;
- permits future addition of convergence/scale without forcing it into the
  initial API;
- permits a future exact-TM implementation without changing UTM policy.

### Negative

- introduces two new coordinate-domain value types;
- adds a nontrivial coefficient-generation/evaluation implementation;
- uses more arithmetic than older fourth-order or local approximate formulas;
- deliberately rejects very wide longitude separations in the initial series
  API;
- requires substantial independent validation before acceptance;
- `real` requires platform-sensitive validation because D `real` precision is
  platform dependent.

## References

- IOGP / EPSG, coordinate operation method 9807, Transverse Mercator.
- IOGP Guidance Note 7-2, Coordinate Conversions and Transformations including
  Formulas.
- L. Krüger, *Konforme Abbildung des Erdellipsoids in der Ebene*, Royal
  Prussian Geodetic Institute, New Series 52, 1912.
- Charles F. F. Karney, "Transverse Mercator with an accuracy of a few
  nanometers", Journal of Geodesy 85(8), 475-485 (2011),
  DOI 10.1007/s00190-011-0445-3, arXiv:1002.1417.
- GeographicLib, `TransverseMercator` and `TransverseMercatorExact`.
- PROJ, `tmerc` / Extended Transverse Mercator implementation and
  documentation.
