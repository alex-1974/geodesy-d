# M4 — Reference Frames integration gate

Date: 2026-10-07  
Stable input baseline: v1.2.0  
Final M4 implementation baseline on `develop`:

~~~text
5535cbb5cff722badc455180dce5aaf7b1a93e65
~~~

## Scope and closure decision

M4 is complete.

The milestone contains four issues and has no open issue remaining:

- #41 — epoch and temporal-parameter semantics — completed;
- #42 — dynamic 14-parameter Helmert — completed;
- #43 — direct Molodensky admission research — deferred / not planned;
- #44 — Molodensky-Badekas admission and implementation — completed.

The milestone is therefore closed from the repository-engineering perspective.
The GitHub milestone metadata may be closed separately as an administrative
action; it carries no remaining implementation work.

## #41 — epoch semantics

M4 introduced `Epoch!T` as a strong decimal-year value.

Accepted semantics:

- parameter reference epoch and observation epoch are distinct;
- epochs remain outside the existing spatial coordinate value types;
- dynamic Helmert parameters propagate linearly with `t - t0`;
- `.init` is invalid for an epoch;
- calendar, leap-second, time-scale, plate-motion, CRS-database and operation-
  discovery responsibilities remain outside this contract.

The detailed decision is recorded in `docs/M4_EPOCH_SEMANTICS.md`.

## #42 — dynamic Helmert

The public family is:

~~~text
Helmert14!(T, convention)
PositionVectorHelmert14!T
CoordinateFrameHelmert14!T
~~~

The convention remains compile-time explicit.

Seven base parameters plus seven signed rates are defined at a separate
reference epoch. Evaluation at an observation epoch produces the existing
`Helmert7` representation and reuses its static spatial kernel.

Qualified interoperability methods:

- EPSG 1053 — Time-dependent Position Vector transformation;
- EPSG 1056 — Time-dependent Coordinate Frame rotation;
- EPSG 1047 — parameter reference epoch.

Validation includes the EPSG worked vector, independent PROJ differential
checks, zero-rate exact regression to the static Helmert family, controlled
DMD/LDC coverage and cross-platform `real` coverage.

Implementation merge on `develop` before M4 closure:

~~~text
2555e6cc4ba094038969830c393cb2724e535cc0
~~~

## #43 — direct Molodensky

Decision: **deferred / not planned for M4**.

EPSG 9604 and 9605 remain valid interoperability methods, but their direct
geographic-coordinate approximation does not currently justify a permanent
`geodesy-d` public family.

The existing composition:

~~~text
geodetic
-> geocentric
-> geocentric translation / Helmert
-> geodetic
~~~

already provides the stronger numerical path.

Re-admission requires at least one concrete trigger:

1. exact EPSG 9604/9605 numerical reproduction for a real consumer;
2. a supported legacy datum workflow not acceptably represented by the
   existing geocentric composition;
3. measured consumer-visible performance value for a direct geographic kernel
   with an acceptable accuracy/domain contract.

The defer decision is intentionally retained as research evidence rather than
being treated as unfinished work.

## #44 — Molodensky-Badekas

Decision: **admitted and implemented**.

The public geocentric family is:

~~~text
MolodenskyBadekas10!(T, convention)
PositionVectorMolodenskyBadekas!T
CoordinateFrameMolodenskyBadekas!T
~~~

Qualified methods:

- EPSG 1061 — Position Vector, geocentric domain;
- EPSG 1034 — Coordinate Frame, geocentric domain.

For fixed evaluation point `p`, translation `t`, scale `M`, rotation
matrix `R`, and source coordinate `x`:

~~~text
y = p + t + M R (x - p)
  = M R x + (p + t - M R p)
~~~

The implementation therefore prepares the algebraically equivalent
`Helmert7` once and delegates the point hot path to the existing qualified
Helmert kernel. There is no duplicate rotation-matrix implementation.

Important laws:

- evaluation point `p = 0` reduces exactly to `Helmert7`;
- Position Vector / Coordinate Frame conversion negates rotations only;
- translations, scale and evaluation point are preserved across convention
  conversion;
- no generic exact `inverse()` is exposed because the evaluation point belongs
  to the forward source Cartesian CRS.

Independent validation includes:

- EPSG/IOGP La Canoa -> REGVEN worked example;
- PROJ `+proj=molobadekas` differential validation in both conventions;
- DMD 2.111.0 and LDC 1.41.0 baseline differential lanes;
- aggregate six-compiler consumer/release gate;
- public API and DDox per-symbol example audit.

Implementation merge on `develop`:

~~~text
5535cbb5cff722badc455180dce5aaf7b1a93e65
~~~

## Final exact-head qualification

PR #97 was qualified on exact head:

~~~text
e1e250261731864e76c90026f6734daf93c31794
~~~

All workflows triggered on that head completed successfully:

- CI;
- API documentation;
- Molodensky-Badekas differential validation;
- PROJ differential validation;
- M3 integration / compiler-consumer gate;
- Dynamic Helmert platform matrix;
- Geodesic platform matrix;
- Topocentric platform matrix;
- Transverse Mercator platform matrix;
- UTM platform matrix.

## Public API boundary after M4

M4 adds mathematical reference-frame transformation capability only.

`geodesy-d` still does not own:

- CRS or EPSG authority databases;
- WKT or PROJJSON parsing/serialization;
- coordinate-operation discovery;
- arbitrary transformation pipelines;
- deformation/plate-motion grids;
- calendar/time-scale/leap-second infrastructure;
- model or dataset distribution.

Those remain responsibilities of future CRS/operation/model layers where
justified.

## M4 closure checklist

- [x] #41 temporal semantics accepted and documented;
- [x] #42 dynamic Helmert implemented and independently validated;
- [x] #43 direct Molodensky admission decision recorded;
- [x] #44 Molodensky-Badekas admitted, implemented and independently validated;
- [x] static Helmert reuse preserved;
- [x] aggregate public API updated;
- [x] strict DDox public-example contract passed;
- [x] DMD/LDC compiler-consumer gate passed;
- [x] relevant cross-platform regression matrices passed;
- [x] exact-head qualification recorded;
- [x] repository responsibility boundary preserved;
- [x] ROADMAP changed from M4 active to M4 completed.

## Next milestone

The next planned development milestone is **M5 — Advanced Ellipsoidal
Geometry**.

M5 remains research-first for operations with ambiguity or multiplicity on a
closed ellipsoid. Existing issues #46, #47, #48, #68 and #69 should be
re-evaluated in their documented order/evidence context rather than admitted
merely for reference-library parity.
