# v2.1.0 Equal Earth — mathematical and API research checkpoint

Status: **research, no implementation/API admitted yet**. Tracks #116.

## Authority and purpose

EPSG coordinate operation method **1078**, Equal Earth, is a global
equal-area *pseudocylindrical* projection. It is not Lambert Azimuthal Equal
Area and does not preserve local angles. It is appropriate for thematic
world maps, not a default local OSM editing projection.

Primary authorities:

- [EPSG method 1078](https://epsg.io/1078-method) (transcription of IOGP
  Guidance Note 7-2; normative guidance note should be checked for final
  precision and conventions).
- [PROJ eqearth](https://proj.org/en/stable/operations/projections/eqearth.html)
  (independent implementation, both spherical and ellipsoidal cases).
- Šavrič, Patterson & Jenny (2018), *The Equal Earth map projection*.

## Forward equations (radians)

Let `a` be the ellipsoid equatorial radius, `e²` eccentricity squared,
`φ` geodetic latitude and `λ - λ₀` canonical longitude difference. Use
the **authalic latitude** `β` and authalic radius `Rq`:

- sphere: `β = φ; Rq = a`;
- oblate ellipsoid: `sin β = q(φ)/qp; Rq = a sqrt(qp/2)`, with the
  standard ellipsoidal authalic integral `q` and `qp = q(π/2)`.

Use `θ = asin((sqrt(3)/2) sin β)` and the coefficients

```text
A1 = 1.340264
A2 = -0.081106
A3 = 0.000893
A4 = 0.003796

P(θ)  = A1 + A2 θ² + θ⁶ (A3 + A4 θ²)
P'(θ) = A1 + 3 A2 θ² + θ⁶ (7 A3 + 9 A4 θ²)

E = FE + Rq * (λ - λ₀) cos θ / ((sqrt(3)/2) P'(θ))
N = FN + Rq * θ P(θ)
```

Do **not** confuse `P'(θ)` with a conformal scale factor. It is the
derivative of `θ P(θ)`; Equal Earth has no conformal-factors API.

## Inverse design

1. Normalize `y = (N-FN)/Rq`; reject non-finite and demonstrably
   unrepresentable coordinates.
2. Solve `θ P(θ) = y` on the closed valid `θ` interval corresponding
   to `β ∈ [-π/2,+π/2]`. Use a safeguarded Newton/bisection procedure,
   with a fixed maximum number of iterations and precision-dependent
   convergence tolerance, instead of relying on an unbounded Newton iteration.
3. Recover `sin β = 2 sin θ/sqrt(3)`; clamp **only roundoff**, and
   reject material excess.
4. Recover geodetic `φ` by inverting the ellipsoidal authalic integral
   (spherical case is the identity). Compare iterative and coefficient
   inverse methods before choosing. LAEA already has relevant bounded
   authalic utility code, but do not export its private helpers solely for
   convenience.
5. Recover `λ - λ₀` from
   `(sqrt(3)/2) (E-FE) P'(θ)/(Rq cos θ)`.
   Validate the represented world-map footprint, not merely the rectangular
   bounding box; establish the exact antimeridian/edge convention.

At `±90°`, the Equal Earth edges remain finite; check round-trip
representation of longitude at the poles independently of latitude.

## Public contract to reconcile against existing projections

- `EqualEarth!T` (float/double/real); prepared reusable value type.
- `tryFromParameters` / `fromParameters`, checked `tryForward` /
  `tryReverse`, throwing `forward` / `reverse`.
- Strong `GeographicCoordinate!T` and `ProjectedCoordinate!T`;
  explicit central meridian, false easting/northing, and caller-selected
  consistent linear unit.
- Default `.init`, checked failure output, domain errors, and
  `@safe pure nothrow @nogc` attributes follow the accepted sibling
  projection *after signature audit*, not guessed names.
- Sphere + terrestrial oblate ellipsoids in scope. Prolate ellipsoid
  support excluded until independently qualified.
- No CRS/database dependencies or automatic projection selection.

## Numerical qualification matrix

- Published EPSG 1078 WGS 84 worked example:
  `λ₀=-90°`, `φ=34°03'27.169" N`,
  `λ=117°11'48.349" W`, `FE=FN=0`:
  `E=-2390749.042m`, `N=4242849.758m` (published rounding).
- Sphere: analytical equator/origin, poles, antimeridian, extreme
  longitudes and central meridian offsets.
- WGS 84: published example; cross-hemisphere and near-pole cases;
  round trips forward/inverse and inverse/forward; invalid/default state.
- Independent PROJ `+proj=eqearth` vectors, with exactly recorded PROJ
  version, units, parameters, input axis order and precision.
- Float promoted working precision, double, and platform real; DMD/LDC;
  negative compile tests for invalid API use where meaningful.
- Release-mode prepared versus one-shot performance and no unexpected GC.
- Public root `import geodesy;` and an independent DUB consumer.

## Admission boundary

Before implementation: pin the proposed factory signatures against LAEA/LCC
and the shared error/result carriers; record exact angle handling and valid
inverse footprint. Before root export: pass numerical tests, differential
oracles, generated documentation and external consumer compilation.
