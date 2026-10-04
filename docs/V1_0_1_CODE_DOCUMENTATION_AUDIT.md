# geodesy-d v1.0.1 code documentation audit

Status: **DECISION-COMMENT REVIEW COMPLETE; AUTOMATED DDOC GATES PENDING**

This audit records the human review of internal documentation and implementation
rationale required by the v1.0.1 documentation-quality gate.

It does not replace compiler, Ddoc, or DDox checks.

## Review rule

A comment earns its place when it preserves information that is not obvious
from the next statement. For non-obvious numerical code, the source must
preserve why a choice exists: precision, representation, boundary policy,
singular-case handling, numerical stability, compatibility, or performance.

Comments that merely narrate syntax do not count as decision documentation.

## Angle and strong-value types

Reviewed: source/geodesy/angle.d, ellipsoid.d, geodetic.d, geocentric.d, and projected.d.

Confirmed rationale:
- latitude/longitude domains and canonical longitude representation are stated;
- unchecked factories are limited to already validated values;
- invalid/default ellipsoid semantics are documented in code and ADR-0004;
- units and strong-type boundaries are caller-visible.

Result: **PASS**.

## EPSG 9602 geographic/geocentric conversion

Reviewed: source/geodesy/conversion.d and ADR-0005.

Confirmed rationale:
- public float reverse conversion uses wider working precision for sensitive Earth-scale cases;
- ordinary Fukushima/Halley and robust interior fallback paths are distinguished;
- the exact geocentre is rejected because no unique geodetic inverse exists;
- homogeneous Halley state is retained without unnecessary normalization;
- the local cube-root implementation explains its supported-toolchain rationale;
- internal working-precision composition is separated from the public scalar contract.

Result: **PASS**.

## Ellipsoidal geodesics

Reviewed: geodesic.d, all source/geodesy/internal/geodesic_*.d modules,
source/geodesy/internal/hypot_compat.d, and ADR-0008.

Confirmed rationale:
- Karney-family direct/inverse machinery is identified rather than presented as unexplained algebra;
- public float working-precision promotion is explicit;
- exact cardinal-angle handling explains why raw libm values are not always sufficient;
- pole protection and canonical-zero behavior are explained where branch semantics depend on them;
- compensated longitude arithmetic records why low-order residuals are retained;
- safeguarded inverse/Newton and near-antipodal start machinery have function contracts;
- fixed series-order helpers are documented by mathematical role;
- the Phobos/frontend 2.111 hypot workaround states the defect and scale-first replacement.

Result: **PASS**.

## Transverse Mercator and projection factors

Reviewed: transverse_mercator.d, factors.d, ADR-0006, and ADR-0011.

Confirmed rationale:
- working-precision and fixed series-order choices are explicit;
- compensated longitude arithmetic preserves representation-side information;
- inverse conformal-latitude iteration documents convergence/failure meaning;
- represented poles have a deliberate canonical reverse policy;
- reverse-boundary slack is separated from the mathematical domain;
- the v1 linear boundary budget explains its unit-invariant scaling;
- represented excursions are accepted only within the public linear error budget;
- factor evaluation uses the accepted working point rather than an unnecessarily rounded intermediate.

Result: **PASS**.

## Pseudo-Mercator

Reviewed: source/geodesy/projection/pseudo_mercator.d.

Confirmed rationale:
- the bounded latitude domain and principal wrapped sheet are public policy;
- compensated longitude/product arithmetic explains represented-boundary handling;
- the east-most legal represented value is searched explicitly rather than assuming exact +pi representation;
- reverse latitude boundaries preserve the represented forward sheet.

Result: **PASS**.

## UTM

Reviewed: source/geodesy/projection/utm.d and ADR-0007.

Confirmed rationale:
- UTM is a policy layer over the prepared Transverse Mercator kernel;
- zone boundaries use the same integral-degree conversion order as public angle construction;
- binary search avoids radians-to-degrees/floor rounding at exact zone boundaries;
- Norway and Svalbard exceptions remain explicit policy;
- prepared-zone operations do not silently re-run automatic zone selection.

Result: **PASS**.

## Topocentric ENU

Reviewed: source/geodesy/topocentric.d and ADR-0009.

Confirmed rationale:
- a frame prepares origin and orientation once for repeated conversion;
- public float composition retains wider working ECEF intermediates;
- geodetic pole longitude intentionally defines ENU orientation;
- the geocentre is rejected because its orientation is not unique;
- working-precision forward/reverse rotations state their input/output contract.

Result: **PASS**.

## Static Helmert and geocentric translation

Reviewed: geocentric_translation.d, helmert.d, and ADR-0003.

Confirmed rationale:
- Position Vector versus Coordinate Frame convention is compile-time explicit;
- there is no silent default convention;
- convention conversion negates rotations while preserving translations and scale;
- checked and throwing peers represent the same operation;
- translation identity/default behavior is explicit.

Result: **PASS**.

## Internal function Ddoc

The source has been remediated so private/package numerical helpers have Ddoc,
including previously undocumented series, projection-compensation, unchecked
factory, and working-precision helpers.

tools/verify-internal-ddoc.py turns this convention into a build contract.

Result: **PENDING AUTOMATED RUN**.

## Public examples and prose

Every public DDox symbol has been given a dedicated documented unittest in
source, and the audit inventory now requires per-symbol coverage.

The final claim is deferred until generated DDox proves that all 211 examples
render on their intended symbol pages.

Result: **PENDING DDOX RUN**.

## Release conclusion

The human decision-comment review is complete.

v1.0.1 documentation quality remains blocked until the internal-Ddoc verifier
passes, the strict 211/211 DDox example verifier passes, generated DDox is
inspected, and any compiler/DDox failures are corrected.
