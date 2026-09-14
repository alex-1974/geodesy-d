# ADR-0005: Hybrid geocentric-to-geodetic inverse

- Status: Accepted
- Date: 2026-09-14
- Applies to: EPSG method 9602 reverse direction

## Context

The reverse geographic/geocentric conversion is straightforward for ordinary
terrestrial positions but becomes numerically difficult close to and inside an
oblate ellipsoid.

In particular:

- the inverse is ill-conditioned near the equatorial evolute cusp;
- multiple geodetic normals may represent the same interior Cartesian point;
- the exact ellipsoid centre has no unique geodetic inverse;
- a fast surface-oriented method is not sufficient by itself for a general
  geodetic library.

The previous implementation used the direct EPSG/Bowring latitude expression
followed by iterative refinement. It was adequate for ordinary positions but
was substantially slower than desired and did not provide an explicit
canonical solution policy for multiply representable deep-interior points.

The replacement must preserve:

- `pure nothrow @safe @nogc` for the checked API;
- `float`, `double`, and `real` public scalar support;
- spherical and oblate ellipsoids;
- deterministic rotation-axis behaviour;
- explicit rejection of the exact ellipsoid centre;
- numerical correctness before performance.

Prolate ellipsoids remain outside the current `Ellipsoid<T>` domain.

## Decision

Use a hybrid reverse kernel.

### Working precision

Public `float` input and output remain `float`, but the numerically sensitive
inverse kernel is evaluated internally in `double`.

`double` and `real` use their native scalar type as working precision.

Direct single-precision evaluation was rejected because Earth-scale interior
and cusp cases lose too much information in intermediate arithmetic.

### Fast path: Fukushima/Halley

Ordinary non-degenerate oblate positions use the homogeneous reduced-latitude
Halley formulation described by Toshio Fukushima.

At most two Halley updates are attempted.

After each update the candidate is accepted only when the scale-independent
algebraic defect satisfies:

~~~text
defect <= 64 * epsilon * a
~~~

where `epsilon` is the working scalar's machine epsilon and `a` is the
semi-major axis.

The factor 64 is a validated implementation bound. It is not a library-wide
floating-point comparison policy.

### Robust fallback: extended Vermeille/Karney

Difficult positions fall back to a complete algebraic oblate inverse based on
Vermeille's direct solution with the stabilized branch structure and
cancellation-avoiding algebra used by Charles F. F. Karney's GeographicLib
`Geocentric` implementation.

The robust branch includes:

- stable real-cubic evaluation;
- the three-real-root branch;
- cancellation-safe evaluation of `u + v`;
- protection against small negative values created only by roundoff;
- the analytic degenerate equatorial-evolute branch;
- scaling for extremely distant finite coordinates.

The implementation is specialized to spherical and oblate ellipsoids because
`Ellipsoid<T>` deliberately supports `0 <= f < 1`.

### Canonical deep-interior solution

Where several geodetic normals represent the same Cartesian point, the inverse
selects the nearest-ellipsoid, minimum-absolute-height solution.

This agrees with GeographicLib's canonical solution for the supported oblate
domain.

The exact centre:

~~~text
X = Y = Z = 0
~~~

has no unique inverse and remains rejected.

The exact equatorial interior/evolute region is routed directly to the robust
analytic branch. In this region the Halley algebraic defect can also be zero
for a non-canonical equatorial normal and therefore cannot by itself determine
the required solution.

### Special analytic cases

The kernel handles directly:

- the rotation axis;
- spherical ellipsoids;
- extremely distant finite coordinates.

### Floating-point optimisation policy

Broad `@fastmath` is not enabled.

Arithmetic transformations that weaken required IEEE behaviour are not
accepted merely to improve benchmark results.

## Alternatives considered

### EPSG/Bowring plus iteration

Advantages:

- comparatively simple;
- familiar;
- previously implemented.

Rejected as the production reverse kernel because it is substantially slower
for ordinary bulk use and does not by itself define the desired canonical
deep-interior semantics.

### Fukushima 1999 quartic/Newton formulation

A prototype was fast for ordinary positions but failed near the WGS 84
equatorial evolute cusp.

Rejected.

### Fixed Fukushima/Halley only

Very fast for ordinary terrestrial positions, but difficult interior and cusp
cases require a robust solution.

Rejected as a complete inverse.

### Robust Vermeille/Karney for every point

Numerically attractive and provides the desired interior semantics, but pays
the complete algebraic cost for every ordinary surface point.

Rejected as the sole path. Retained as the fallback and canonical
difficult-domain solution.

## Validation

The hybrid implementation was validated against:

- EPSG/IOGP method 9602 reference data;
- GeographicLib 2.7 `CartConvert0`;
- GeographicLib's documented WGS 84 evolute-conditioning examples;
- PROJ 9.7.1 `+proj=cart` axis cases;
- the documented PROJ GRS 80 Cartesian example;
- deterministic cusp and deep-interior sweeps;
- deterministic scalar-generic tests for `double` and `real`;
- a dedicated terrestrial `float` accuracy corpus.

Selected difficult-domain results:

~~~text
GeographicLib CartConvert0:
    ECEF round-trip residual = 1.14e-9 m

WGS 84 cusp, radial displacement -1 nm:
    latitude = 0.044807356 arcsec
    documented magnitude approximately 0.04 arcsec

WGS 84 cusp, Z displacement +1 nm:
    latitude = 7.451998626 arcsec
    documented magnitude approximately 7.45 arcsec

2527-point multi-scale cusp sweep:
    failures = 0
    points above 1 micrometre residual = 0
    worst residual = 3.49e-9 m
~~~

The broader scalar validation produced no failed inverse operations and no
configured scaled-residual-limit violations.

For `double`, the worst ECEF round-trip residual in the broad adversarial suite
was approximately:

~~~text
3.35e-6 m
~~~

For `real`, it was approximately:

~~~text
1.49e-9 m
~~~

### Public float validation

The terrestrial float corpus covered:

~~~text
ellipsoids:
    WGS 84
    GRS 80
    Airy 1830

latitude:
    full legal range

ellipsoidal height:
    -20 km through +100 km

cases:
    752178
~~~

Observed maxima were:

~~~text
ECEF round-trip error:       0.771 m
horizontal position error:   0.760 m
ellipsoidal-height error:    0.003906 m
~~~

This supports a deliberately conservative public terrestrial contract of:

~~~text
float:
    represented Cartesian position <= 2 m
    ellipsoidal height             <= 0.1 m

double and real:
    represented Cartesian position <= 1 mm
~~~

These limits describe numerical coordinate-transformation error. They do not
describe datum, reference-frame, observation, survey, GNSS, or physical
position accuracy.

## Performance

LDC release builds are the normative performance configuration.

The controlled final benchmark used:

~~~text
date:               2026-09-14
CPU:                Intel Core i7-9750H
compiler:           LDC 1.41.0
D frontend:         2.111.0
LLVM:               19.1.7
PROJ:               9.7.1
GeographicLib:      2.7
CPU affinity:       logical CPU 2
intel_pstate:       performance governor
Turbo:              disabled
maximum frequency:  2.6 GHz
corpus size:        250000 operations
rounds:             21
~~~

Reported `ns/op` values are bulk-throughput measurements, not true
single-operation dependency-chain latency.

### Surface-normal corpus

~~~text
geodesy-d             162.740 ns/op
previous Bowring      376.096 ns/op
PROJ 9.7.1            154.018 ns/op
GeographicLib 2.7     283.868 ns/op
~~~

### Full terrestrial corpus

~~~text
geodesy-d             162.871 ns/op
previous Bowring      436.999 ns/op
PROJ 9.7.1            153.488 ns/op
GeographicLib 2.7     283.107 ns/op
~~~

For ordinary terrestrial data, this corresponds approximately to:

~~~text
2.31x to 2.68x faster than the previous Bowring implementation
1.74x faster than GeographicLib 2.7 in this benchmark
about 6% slower than PROJ 9.7.1
~~~

Difficult-domain measurements were:

~~~text
extended-normal:
    geodesy-d          330.407 ns/op
    GeographicLib      283.392 ns/op

interior-cusp:
    geodesy-d          335.641 ns/op
    GeographicLib      285.192 ns/op

equatorial-degenerate:
    geodesy-d          155.537 ns/op
    GeographicLib      158.059 ns/op
~~~

The public `float` API uses double working precision but measured:

~~~text
float API             171.330 ns/op
double API            169.454 ns/op
float / double          1.011x
~~~

The higher working precision therefore costs approximately one percent in this
benchmark.

Absolute timing is hardware- and operating-state-dependent. Earlier same-machine
runs produced substantially lower absolute times while preserving nearly the
same geodesy-d/Bowring and geodesy-d/GeographicLib ratios. Their CPU frequency
state was not recorded during the timed sections, so those runs are not used as
the controlled absolute reference.

Same-machine, same-process relative measurements are therefore the stronger
performance result.

## Consequences

### Positive

- substantially faster ordinary EPSG 9602 reverse conversion;
- robust behaviour at and around the evolute;
- robust behaviour deep inside the ellipsoid;
- explicit canonical semantics for multiply representable interior points;
- useful public `float` support without unstable direct single-precision
  intermediate arithmetic;
- no external runtime dependency.

### Negative

- considerably more implementation complexity than Bowring iteration;
- difficult positions may perform Halley work before taking the robust
  fallback;
- numerical-method provenance must be maintained when the kernel changes.

## References

- IOGP / EPSG coordinate operation method 9602.
- Toshio Fukushima, "Transformation from Cartesian to geodetic coordinates
  accelerated by Halley's method", Journal of Geodesy 79, 689-693 (2006),
  DOI 10.1007/s00190-006-0023-2.
- H. Vermeille, "Direct transformation from geocentric coordinates to geodetic
  coordinates", Journal of Geodesy 76, 451-454 (2002),
  DOI 10.1007/s00190-002-0273-6.
- Charles F. F. Karney, GeographicLib 2.7, `Geocentric`.
