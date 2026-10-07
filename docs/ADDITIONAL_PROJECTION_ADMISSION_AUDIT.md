# M3 additional-projection admission audit

Date: 2026-10-06  
Issue: #40  
Milestone: M3 — Navigation & Polar Geodesy

## Purpose

This document decides which projection families should follow the current
geodesy-d projection baseline.

The decision is deliberately not based on reference-library feature parity.
A family is admitted only when there is a concrete consumer, workspace need,
interoperability gap, or sufficiently strong numerical/research reason.

Current implemented projection/navigation baseline:

- bounded Transverse Mercator;
- UTM;
- bounded Pseudo-Mercator;
- Polar Stereographic;
- UPS;
- Rhumb / RhumbLine.

The current workspace consumer repositories searched for an explicit
projection-specific dependency did not expose an existing direct requirement
for one of the six candidate families. Therefore any admission below is based
on an independently useful interoperability gap, not on a manufactured
consumer claim.

## Decision summary

| Candidate | Decision | Priority | Primary reason |
| --- | --- | ---: | --- |
| Lambert Conformal Conic | **ADMIT, 2SP first** | 1 | EPSG:31287 Austria Lambert and EPSG:3034 Europe LCC; concrete European interoperability gap |
| Lambert Azimuthal Equal Area | **ADMIT** | 2 | EPSG:3035 ETRS89 / LAEA Europe; pan-European equal-area/statistical interoperability |
| Stereographic | **DEFER** | 3 | Important national CRS use such as EPSG:28992, but no current workspace consumer and existing Polar Stereographic covers only the polar aspect |
| Azimuthal Equidistant | **DEFER** | 4 | useful radial-distance map property, but no current projection consumer; geodesic core already answers distance/bearing questions directly |
| Albers Equal Area | **DEFER** | 5 | valid equal-area conic family but no current workspace/European interoperability gap stronger than admitted LAEA |
| Oblique Mercator | **DEFER** | 6 | specialized corridor-oriented use, high parameter/numerical complexity, no current consumer |

No candidate is rejected permanently. "Defer" means there is not enough
evidence to justify implementation now.

---

# 1. Lambert Conformal Conic

## Decision

**ADMIT — implement EPSG Lambert Conic Conformal (2SP) first.**

One-standard-parallel and vendor-specific variants are not admitted by this
audit. They can be additive follow-up work if a real CRS/consumer requires
them.

## Consumer / interoperability evidence

Two concrete authority-defined European uses make this more than a generic
projection wishlist item.

### EPSG:31287 — MGI / Austria Lambert

EPSG:31287 uses:

- method: Lambert Conic Conformal (2SP), EPSG method 9802;
- ellipsoid: Bessel 1841;
- latitude of false origin: 47.5 degrees;
- longitude of false origin: 13 degrees 20 minutes east;
- first standard parallel: 49 degrees;
- second standard parallel: 46 degrees;
- false easting/northing: 400000 m;
- scope: topographic mapping at medium and small scale in Austria.

This is a concrete legacy/national-data interoperability requirement.

### EPSG:3034 — ETRS89-extended / LCC Europe

EPSG:3034 uses the same EPSG 9802 method with GRS80 and is defined for
pan-European conformal mapping. EPSG describes it for conformal mapping at
1:500,000 and smaller, with UTM used for larger-scale conformal mapping.

Together, EPSG:31287 and EPSG:3034 provide a stronger admission case than
"PROJ implements LCC".

Sources:

- https://epsg.io/31287
- https://epsg.io/3034
- https://proj.org/en/stable/operations/projections/lcc.html

## Mathematical / parameter complexity

The admitted 2SP kernel requires:

- ellipsoid;
- latitude and longitude of false origin;
- first and second standard parallels;
- false easting and false northing.

The ellipsoidal forward kernel is standard conic-conformal mathematics based
on meridional/isometric latitude functions. Reverse requires stable inversion
of the conformal latitude.

This is moderate complexity, but lower risk than Oblique Mercator and well
suited to a prepared immutable projection object.

## Overlap with existing kernels

Useful reusable ideas exist, but the mathematical kernel is independent:

- scalar policy and angle canonicalization from existing projections;
- conformal-latitude machinery conceptually overlaps Polar Stereographic;
- projection-factor result type may be reusable if meridian convergence and
  point scale are admitted;
- projected coordinate and checked/throwing API patterns are directly reusable.

Do not make LCC a mode of Transverse Mercator or Polar Stereographic.

## Expected API shape

~~~d
LambertConformalConic!T

tryFromTwoStandardParallels(...)
fromTwoStandardParallels(...)

tryForward(...)
forward(...)

tryReverse(...)
reverse(...)

tryForwardFactors(...)
forwardFactors(...)

tryReverseFactors(...)
reverseFactors(...)
~~~

Parameter properties should expose the accepted EPSG semantics explicitly.

## Validation references

Required:

- PROJ differential validation across sphere and multiple oblate ellipsoids;
- EPSG method 9802 examples / authoritative vectors where available;
- EPSG:31287 and EPSG:3034 parameter-set regression vectors;
- float/double/real;
- controlled DMD/LDC matrix and platform-real qualification.

## Performance / implementation risk

**Moderate.**

Expected hot path is compact and allocation-free. Primary risks are:

- near-degenerate standard-parallel combinations;
- sign/orientation behavior across hemispheres;
- reverse conformal-latitude inversion;
- exact tangent/symmetric cases;
- numerical continuity when the two standard parallels approach each other.

The initial implementation should reject degenerate parameter combinations
rather than silently reinterpret them as a 1SP method.

---

# 2. Lambert Azimuthal Equal Area

## Decision

**ADMIT — second implementation priority after LCC 2SP.**

## Consumer / interoperability evidence

EPSG:3035 ETRS89-extended / LAEA Europe is a concrete, authority-defined
pan-European projection with scope "Statistical analysis".

EPSG explicitly contrasts the European roles:

- LAEA / EPSG:3035 for statistical applications;
- LCC / EPSG:3034 for conformal small-scale mapping;
- UTM for conformal larger-scale mapping.

The current library has conformal projections but no equal-area projection.
LAEA therefore closes a genuine capability class as well as an interoperability
gap.

Sources:

- https://epsg.io/3035
- https://proj.org/en/stable/operations/projections/laea.html

## Mathematical / parameter complexity

Expected public parameters:

- ellipsoid;
- latitude of projection centre;
- longitude of projection centre;
- false easting;
- false northing.

Ellipsoidal LAEA uses authalic latitude / authalic-radius machinery. Reverse
requires stable inverse authalic latitude.

## Overlap with existing kernels

No current equal-area kernel exists.

Reusable infrastructure:

- scalar and cardinal-angle semantics;
- projected coordinate and factory conventions;
- bounded checked/throwing APIs;
- platform/scalar qualification infrastructure.

The authalic-latitude machinery should be isolated internally because it may
also become useful for future equal-area research, but it should not be made
public merely in anticipation of Albers.

## Expected API shape

~~~d
LambertAzimuthalEqualArea!T

tryFromParameters(...)
fromParameters(...)

tryForward(...)
forward(...)

tryReverse(...)
reverse(...)
~~~

Projection factors should only be added when the semantics and consumer need
are clear; equal-area does not imply conformal scalar point scale.

## Validation references

Required:

- PROJ differential validation;
- EPSG:3035 regression vectors;
- sphere plus GRS80/WGS84 and additional oblate ellipsoids;
- centre, antipodal/near-antipodal, equatorial and high-latitude cases;
- float/double/real and controlled compiler/platform matrix.

## Performance / implementation risk

**Moderate.**

Main risks:

- antipodal singularity;
- inverse authalic latitude;
- loss of significance close to the projection centre;
- represented-domain policy at the far-side boundary.

---

# 3. Stereographic

## Decision

**DEFER.**

This audit distinguishes generic/oblique stereographic from the already
implemented Polar Stereographic.

## Evidence

There is real interoperability relevance. For example EPSG:28992
Amersfoort / RD New uses EPSG method 9809 Oblique Stereographic for Dutch
topographic and engineering mapping.

Source:

- https://epsg.io/28992

However, no present workspace consumer requires RD New or another oblique
stereographic CRS. Implementing it solely because a notable national CRS
exists would weaken the admission rule.

## Complexity / overlap

There is conceptual overlap with Polar Stereographic, but not enough to expose
generic stereographic as a simple parameter switch. Oblique ellipsoidal
stereographic uses a different conformal-sphere construction and deserves a
separate reviewed kernel.

Revisit when a national-CRS or map-view consumer requires it.

---

# 4. Azimuthal Equidistant

## Decision

**DEFER.**

PROJ exposes spherical and ellipsoidal forward/inverse forms.

Source:

- https://proj.org/en/stable/operations/projections/aeqd.html

## Consumer analysis

The projection is attractive for:

- range maps;
- radio/coverage maps;
- aviation/navigation displays;
- "distance from this centre" visualizations.

But the current workspace has no projection consumer requiring such a map
plane. For mathematical distance/bearing questions, geodesy-d already has a
strong ellipsoidal Geodesic family, so projection admission is not required to
answer those calculations.

## Implementation note

If admitted later, the ellipsoidal form should investigate direct reuse of the
Geodesic inverse/direct kernel rather than independently reproducing geodesic
mathematics.

---

# 5. Albers Equal Area

## Decision

**DEFER.**

PROJ supplies spherical and ellipsoidal Albers Equal Area.

Source:

- https://proj.org/en/stable/operations/projections/aea.html

## Consumer analysis

Albers is a useful equal-area conic projection for broad east-west regions,
but there is no current workspace requirement and no identified European
interoperability gap stronger than EPSG:3035 LAEA.

Admitting LAEA first gives the library an equal-area capability with a concrete
pan-European standard case. Albers should wait for a consumer requiring a conic
equal-area property or a specific CRS.

## Future overlap

If later admitted, internal authalic functions proven by LAEA may be reusable.
This potential reuse is not itself a reason to implement Albers.

---

# 6. Oblique Mercator

## Decision

**DEFER.**

PROJ documents ellipsoidal Oblique Mercator as useful for regions whose main
extent is neither north-south nor east-west and notes a reasonable-accuracy
region near the oblique central line.

Source:

- https://proj.org/en/stable/operations/projections/omerc.html

## Consumer analysis

Typical uses are specialized corridor/oblique-region mapping. No current
workspace consumer requires it.

## Complexity / risk

This is the highest-risk candidate in the audit:

- multiple ways to define the central line;
- non-trivial azimuth/origin parameter policy;
- skew-coordinate rectification;
- far-from-centre ambiguity in some ellipsoidal configurations;
- substantial interoperability surface between Hotine variants.

It should only be admitted against a specific CRS or consumer test corpus.

---

# Admission outcome

## Implement next

1. **Lambert Conformal Conic 2SP** — implementation issue #83
   - concrete Austria and pan-European conformal interoperability;
   - complements UTM at broader European mapping scales;
   - first follow-up implementation issue.

2. **Lambert Azimuthal Equal Area** — implementation issue #84
   - concrete EPSG:3035 pan-European statistical/equal-area interoperability;
   - first equal-area family in geodesy-d;
   - second follow-up implementation issue.

## Keep deferred

- Oblique Stereographic / generic Stereographic;
- Azimuthal Equidistant;
- Albers Equal Area;
- Oblique Mercator.

A deferred family must be reopened by new evidence, not by feature-parity
pressure.

# Architectural consequences

The admitted kernels remain mathematical projections only.

They do not move these responsibilities into geodesy-d:

- EPSG database lookup;
- CRS authority identifiers as a database;
- WKT / PROJJSON parsing;
- datum-operation discovery;
- grid-shift data;
- application map-policy selection.

A future CRS/proj layer may build authority-backed presets such as EPSG:31287,
EPSG:3034, and EPSG:3035 over the generic mathematical kernels.

# M3 consequence

Issue #40 is an **admission audit**, not an implementation queue.

Once this document and its follow-up issues are merged, #40 is complete.
M3 core remains:

- Polar Stereographic — complete;
- UPS — complete;
- Rhumb / RhumbLine — complete;
- additional projection admission audit — complete.

The admitted LCC/LAEA implementations are additive follow-up projection work
and should not retroactively make M3 core incomplete.
