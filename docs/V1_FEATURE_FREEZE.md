# v1.0 Feature Freeze

Status: **Active**

The feature scope for `geodesy-d` v1.0 is frozen.

This freeze marks the transition from capability development to public-API
review and release preparation. It does **not** freeze the current API shape.

## Frozen v1 capability scope

The v1 baseline consists of the accepted functionality already integrated into
`main`, including:

- strong angular, geographic, geodetic, geocentric, projected, and local
  topocentric coordinate/value types;
- reference ellipsoids;
- EPSG 9602 geographic/geocentric conversion;
- EPSG 1031 geocentric translation;
- EPSG 1032/1033 static Helmert transformations;
- bounded generic Transverse Mercator;
- UTM policy and projection;
- conformal Transverse Mercator / UTM projection factors;
- the accepted first direct/inverse ellipsoidal geodesic slice;
- bounded EPSG 9836/9837 topocentric ENU;
- bounded EPSG method 1024 Pseudo-Mercator.

No additional capability family is required for v1.0.

## Deferred capability work

The P1 geodesic candidates remain outside the frozen v1 scope unless concrete
consumer evidence leads to an explicit decision to reopen the feature freeze:

- minimal prepared `GeodesicLine`;
- geodesic perimeter and signed-area accumulation.

The other deferred and out-of-scope capabilities listed in `ROADMAP.md`
remain deferred.

A feature-freeze exception must be explicit. The existence of a feature in
another geospatial library, a desire for API completeness, or implementation
convenience is not sufficient by itself.

## What remains changeable

This is a **feature freeze**, not an API freeze.

The forthcoming v1 public-API audit may still justify changes to existing
public API, including breaking changes, when needed to correct or improve:

- naming and API-family consistency;
- type and construction semantics;
- `.init` and default-state semantics;
- mutability and ownership boundaries;
- checked versus throwing operation contracts;
- failure and exception semantics;
- scalar, unit, precision, domain, and canonicalization contracts;
- module, aggregate-import, and visibility boundaries;
- public parameter names and named-argument compatibility;
- documentation/API mismatches.

Existing public API on the unreleased development line does not gain v1
compatibility protection merely by being present on `main`.

Accepted mathematical and numerical cores remain protected by their existing
acceptance evidence. They are not to be changed merely as part of API cleanup;
a production-core change still requires correctness, numerical, semantic,
consumer, API, or measured performance evidence.

## Path to the API freeze

The release sequence after this point is:

~~~text
feature freeze
    -> complete public-surface inventory
    -> v1 public-API audit
    -> justified API corrections
    -> final API acceptance
    -> API freeze
    -> release-readiness validation
    -> v1.0.0
~~~

The later API freeze will establish the concrete public compatibility contract
for v1. Until that gate is passed, the audit is expected to challenge the
candidate surface rather than preserve it automatically.

## Reopening the feature freeze

The feature freeze may be reopened only by an explicit repository decision
that records:

1. the concrete consumer or correctness requirement;
2. why the requirement must be satisfied before v1.0 rather than additively in
   v1.x;
3. the bounded capability being admitted;
4. the required research, acceptance, API, and validation gates.

Absent such a decision, work before v1.0 is limited to API audit/correction,
documentation, compatibility, validation, release engineering, and fixes
supported by concrete evidence.
