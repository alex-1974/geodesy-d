# Pseudo-Mercator research

Status: PM-E1C0 complete — PM-E1C1 next

## Goal

Qualify the smallest bounded Pseudo-Mercator mathematical projection kernel
needed by geodesy-d consumers before any public API or production
implementation is accepted.

The target method is EPSG coordinate operation method 1024,
Popular Visualisation Pseudo-Mercator.

This research does not define a CRS database, EPSG lookup layer, web-tile
scheme, zoom model, imagery cache, or map renderer.

## Authoritative semantic baseline

Primary references:

- IOGP Publication 373-7-2, Guidance Note 7 part 2,
  section 3.2.1.2, Popular Visualisation Pseudo-Mercator;
- EPSG coordinate operation method 1024;
- EPSG projected CRS 3857 as the principal real-world consumer profile;
- IOGP Publication 373-23, Web Mercator;
- PROJ `webmerc` as an independent production implementation;
- OGC WebMercatorQuad only for demonstrating the ownership boundary between
  projection mathematics and tile-matrix policy.

For ellipsoidal latitude phi and longitude lambda, EPSG method 1024 uses the
semi-major axis a as the radius in the spherical-form equations:

    E = FE + a * (lambda - lambda0)
    N = FN + a * ln(tan(pi/4 + phi/2))

The reverse operation derives:

    D = (FN - N) / a
    phi = pi/2 - 2 * atan(exp(D))
    lambda = (E - FE) / a + lambda0

The latitude of natural origin is not used by the method equations. EPSG
includes the parameter for completeness in CRS labelling, but it must have the
value zero.

The method is not conformal when ellipsoidal geographic coordinates are used.
Meridional and parallel scale differ. Therefore
ConformalProjectionFactors!T is not applicable to this projection.

## Method, CRS, and tile-policy separation

Three concepts must remain distinct:

1. EPSG method 1024 is projection mathematics.
2. EPSG:3857 is a concrete WGS 84 projected CRS using that method.
3. WebMercatorQuad / slippy-map bounds and zoom/tile addressing are consumer
   policy layered on projected coordinates.

In particular, the approximately 85.0511287798 degree WebMercatorQuad latitude
cutoff is not automatically the domain of the geodesy-d projection kernel.

No XYZ/TMS tile addressing, zoom level, pixel size, tile extent, tile URL, or
raster concern belongs in this research slice.

## PM-D domain decision

PM-D adopts the represented closed forward latitude domain:

    -88 degrees <= phi <= +88 degrees

The geographic poles are outside the supported method domain.

The normalized northing boundary is derived from the represented public
+/-88-degree forward points. Reverse must classify projected northing against
those represented forward boundaries before inverse-latitude rounding can hide
an out-of-domain input.

The approximately +/-85.06-degree EPSG:3857 area of use and the approximately
+/-85.0511287798-degree WebMercatorQuad cutoff remain CRS/consumer policy and
are not geodesy-d kernel limits.

See `PM_D_DOMAIN_POLICY.md`.


## PM-D longitude policy decision

Pseudo-Mercator uses the existing geodesy-d principal longitude convention:

    -pi <= deltaLambda < +pi

An exact represented +pi tie canonicalizes to -pi.

The mathematical principal easting sheet is therefore:

    FE - a*pi <= E < FE + a*pi

The open east boundary must not be pre-rounded to public scalar T and used as a
raw comparison limit. PM-D demonstrated a `float`/WGS84 representation
collision where a legal east-side point and the excluded mathematical +pi
boundary round to the same public easting.

Reverse therefore classifies the longitude difference reconstructed from the
represented easting in working precision.

If a legal point and an excluded mathematical boundary are indistinguishable
after public scalar rounding, the legal represented value remains accepted.

Reverse longitude output is canonicalized to `[-pi,+pi)`.

Bit-identical recovery of every independently rounded public longitude is not a
PM-D requirement; numerical round-trip accuracy is validated by PM-E.

See `PM_D_DOMAIN_POLICY.md`.


## Numerical candidates

Forward northing candidates to compare include at minimum:

    F1 = log(tan(pi/4 + phi/2))
    F2 = asinh(tan(phi))

They are analytically equivalent inside the open-pole domain but need not have
identical floating-point behaviour.

Inverse candidates must include the literal EPSG exponential form and at least
one overflow-safe formulation. Research must characterize when a finite
projected northing rounds to an exact represented pole for float, double, and
real.

Production code must not be selected solely because a formula is shorter or is
used by another implementation.

## Parameterization question

The coordinate equations depend on:

- semi-major axis a from the ellipsoid of the source geographic CRS;
- longitude of natural origin lambda0;
- false easting FE;
- false northing FN.

The semi-major axis is therefore projection input state derived from the
ellipsoid, not an EPSG method parameter analogous to lambda0, FE, or FN.

Flattening does not enter the forward/reverse coordinate equations, although
the source coordinates are ellipsoidal and flattening matters to distortion
properties.

Research must decide whether the public prepared projection accepts a complete
Ellipsoid!T or only the minimum radius-like state. The answer must follow
geodesy-d ownership and API consistency rather than implementation convenience.

The unused zero latitude-of-natural-origin parameter must not become public
state without a concrete interoperability reason.

## Working public-name question

`PseudoMercator` is the current research working name because it describes the
EPSG projection method without implying ownership of WebMercatorQuad tile
policy or a fixed EPSG:3857 CRS.

`WebMercator` remains a candidate only if the API-design gate demonstrates that
the narrower consumer meaning is preferable.

No alias is admitted during research.

## Validation profiles

The validation program must cover at least:

- the published EPSG/IOGP method example;
- WGS 84 / EPSG:3857-like zero-origin cases;
- non-zero longitude of natural origin;
- non-zero false easting and northing;
- spherical and ellipsoidal Earth models sharing the same semi-major axis;
- at least one synthetic ellipsoid with a different semi-major axis;
- equator and central meridian;
- antimeridian and wrap-around cases;
- northern and southern high latitudes;
- domain/boundary probes;
- float, double, and real where the platform provides a wider real;
- DMD and LDC.

PROJ `+proj=webmerc` is an interoperability oracle, not the only oracle.
An independent high-precision analytic implementation is required.

## Research gates

PM-A — semantic contract and ownership boundary
    Freeze the method identity, non-goals, reference sources, and unresolved
    questions. No production API.

PM-B — numerical forward study — PASS
    `asinh(tan(phi))` accepted as the portable forward numerical candidate
    after DMD/LDC, high-precision oracle, alternative-form and backend
    characterization. See `PM_B_FORWARD_RESULTS.md`.

PM-C — numerical reverse and round-trip study — PASS
    `atan(sinh(q))` accepted as the portable reverse numerical candidate.
    Forward/reverse round trips and scalar representability limits are
    characterized in `PM_C_REVERSE_ROUNDTRIP_RESULTS.md`.

PM-D — domain and longitude-policy gate — PASS
    +/-88 degrees accepted as the represented closed latitude boundary.
    Principal longitude difference is [-pi,+pi), projected northing is checked
    against represented forward boundaries, and easting uses working-precision
    principal-sheet classification. See `PM_D_DOMAIN_POLICY.md`.

PM-E — independent differential validation — ACTIVE
    PM-E0 PASS: local PROJ `webmerc` is qualified as a numerical differential
    reference over the shared supported domain. Exact +pi endpoint policy is
    intentionally treated separately from numerical agreement.
    See `PM_E0_PROJ_QUALIFICATION.md`.

    PM-E1A PASS: represented easting-domain behaviour is characterized.
    Working-precision classification is primary; exact represented west and
    legal-east endpoint anchors handle the remaining rounding collisions
    without general domain slack. See `PM_E1A_EASTING_DOMAIN_RESULTS.md`.

    PM-E1B PASS: the complete D research kernel composes the accepted
    PM-B/PM-C formulas with the PM-D/PM-E1A domain classifiers. The
    deterministic 18-profile / 144-round-trip corpus has zero failures and
    byte-identical DMD/LDC output. See `PM_E1B_KERNEL_RESULTS.md`.

    PM-E1C0 PASS: the accepted PM-E1B kernel now has a versioned
    machine-readable differential driver. Normal E1B behaviour remains
    byte-identical across DMD/LDC; the driver smoke corpus is also
    byte-identical and preserves the +pi -> -pi principal-sheet tie.
    See `PM_E1C0_DIFFERENTIAL_DRIVER.md`.

    PM-E1C1 NEXT: run representation-aware differential validation against
    the high-precision analytical oracle and, for compatible double cases,
    the PM-E0-qualified PROJ `webmerc` implementation.

PM-F — public API gate
    Only after PM-A through PM-E, resolve the public type name,
    parameterization, checked/throwing operations, default-state semantics,
    and documentation contract.

PM-G — production/platform acceptance
    Implement only the accepted PM-F surface, then validate API isolation,
    DMD/LDC, release builds, supported platforms, and regression boundaries.

## Explicit non-goals for this slice

- no CRS registry or EPSG lookup;
- no EPSG:3857 CRS object;
- no automatic CRS conversion pipeline;
- no WKT or PROJJSON;
- no WebMercatorQuad object;
- no XYZ/TMS addressing;
- no zoom levels or pixel coordinates;
- no tile clipping policy;
- no imagery/raster dependency;
- no projection-factor API;
- no general Jacobian/Tissot abstraction;
- no performance optimization before correctness and API acceptance.

## PM-A exit criteria

PM-A is complete when:

- authoritative semantics are reproducibly documented;
- method / CRS / tile-policy ownership is explicit;
- the non-conformal nature of EPSG:1024 is recorded;
- the domain question remains explicit rather than being silently answered by
  the WebMercatorQuad cutoff;
- numerical candidates and validation oracles are identified;
- no production API or implementation has been introduced.
