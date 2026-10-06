# geodesy-d v1.2.0 public API audit

Status: **COMPLETE — API FREEZE CANDIDATE**

Tracking issue: #90.

Feature-freeze checkpoint:

`freeze/feature-1.2.0` -> `d6f49b500b15616ca396ee612fef95896405b526`

## Purpose

This audit verifies that the additive v1.2 public surface is intentional,
coherent with the frozen v1 source contract, documented, and suitable to freeze
before final release hardening.

No API redesign is introduced by this audit.

## Aggregate import

`import geodesy;` intentionally exports the existing v1/v1.1 families plus:

- `Rhumb!T`;
- `RhumbLine!T`;
- `RhumbDirectResult!T`;
- `RhumbInverseResult!T`;
- `PolarStereographic!T`;
- `UpsHemisphere`;
- `UpsCoordinate!T`;
- `UpsProjection!T`;
- Lambert Conformal Conic 2SP through `LambertConformalConic!T`;
- Lambert Azimuthal Equal Area through `LambertAzimuthalEqualArea!T`.

The additions are implemented in dedicated public modules and re-exported by
`source/geodesy/package.d`.

## Compatibility

The v1.2 surface is additive.

The audit found no need to change existing:

- public names;
- signatures;
- parameter order;
- supported parameter names;
- checked/throwing failure channels;
- scalar policy;
- unit policy;
- existing `.init` semantics;
- existing operation domains.

The frozen v1 and additive v1.1 contracts remain intact.

## Scalar and working-precision policy

All M3 numerical families support:

~~~text
float | double | real
~~~

Public `float` paths use promoted double working precision where documented.
`double` uses double and platform `real` retains its wider precision where
available.

## Failure and default-state semantics

Prepared numerical objects use detectably invalid `.init` states where
preparation is required:

- `Rhumb!T.init`;
- `RhumbLine!T.init`;
- `PolarStereographic!T.init`;
- `UpsProjection!T.init`;
- `UpsCoordinate!T.init`;
- `LambertConformalConic!T.init`;
- `LambertAzimuthalEqualArea!T.init`.

Checked operations return `false` for invalid prepared state, invalid
parameters, unsupported domain/singularities, or failed numerical recovery.
Throwing peers report those failures through `GeodesyValueException`.

## Family-specific decisions

### Rhumb / RhumbLine

- distinct from geodesic mathematics;
- shortest-wrap inverse semantics;
- east-going exact opposite-meridian tie;
- signed-distance direct operation;
- canonical longitude output;
- nonzero direct/line pole crossing excluded because longitude becomes
  indeterminate;
- prolate support deferred.

### Polar Stereographic

- bounded north/south mathematical kernel;
- EPSG 9810 variant A primary semantics;
- EPSG 9829 variant B construction through equivalent pole scale;
- exact selected pole maps to false origin;
- conformal factors use `ConformalProjectionFactors!T`.

### UPS

- WGS 84 policy layer over Polar Stereographic;
- standard automatic transition complements UTM;
- explicit overlap policy is public and documented;
- tagged coordinate carries hemisphere required for reverse interpretation;
- no duplicated stereographic mathematics.

### Lambert Conformal Conic 2SP

- genuine EPSG 9802 two-standard-parallel form;
- equal standard parallels rejected rather than creating an implicit 1SP API;
- conformal factors use `ConformalProjectionFactors!T`;
- authority-backed validation includes EPSG:31287 and EPSG:3034.

### Lambert Azimuthal Equal Area

- all four centre modes supported;
- exact authalic antipode excluded;
- reverse accepts the open represented disk;
- equal-area family deliberately exposes no conformal-factor result;
- authority-backed validation includes EPSG:3035.

## Documentation/example audit

The five M3 families have:

- module-level Ddoc;
- public type Ddoc;
- checked/throwing construction and operation documentation;
- public property documentation;
- executable unittests/examples;
- type/family-level examples suitable for rendered DDox pages.

The release polish additionally reconciles:

- root README;
- aggregate package Ddoc;
- `docs/API.md`;
- release notes;
- M3 research/validation cross-links.

## Boundary audit

v1.2 does not admit:

- CRS authority lookup/database APIs;
- WKT/PROJJSON;
- automatic coordinate-operation discovery;
- transformation grids;
- MGRS;
- deferred projection families from #40;
- M4 dynamic reference-frame APIs.

These remain outside the v1.2 public contract.

## API-freeze decision

The audited v1.2 public surface is suitable for API freeze.

After the immutable `freeze/api-1.2.0` checkpoint is created, implementation,
tests, comments, Ddoc, user documentation, CI, packaging and release metadata
may continue only while preserving this caller-visible contract.

Any release-blocking public API change requires explicitly reopening the API
freeze, rerunning the affected API/consumer/semantic gates, and creating a new
immutable API-freeze checkpoint rather than moving the existing tag.
