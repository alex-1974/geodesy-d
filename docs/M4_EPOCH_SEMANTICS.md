# M4 epoch and temporal-parameter semantics

Status: **PROPOSED CONTRACT FOR ISSUE #41**

## Purpose

Define the smallest time model required by geodesy-d for time-dependent
reference-frame transformations before implementing the dynamic 14-parameter
Helmert family in issue #42.

This document defines temporal semantics only. It does not add a CRS database,
coordinate-operation discovery, plate-motion models, leap-second handling, or
a general time library.

## Normative model

The primary geocentric methods are:

- EPSG 1053 — Time-dependent Position Vector transformation (geocentric);
- EPSG 1056 — Time-dependent Coordinate Frame rotation (geocentric).

Their static counterparts already implemented by geodesy-d are:

- EPSG 1033 — Position Vector transformation (geocentric);
- EPSG 1032 — Coordinate Frame rotation (geocentric).

EPSG 1053/1056 first evaluate seven transformation parameters at the required
coordinate epoch and then apply the corresponding static seven-parameter
Helmert transformation.

For every parameter `P`:

~~~text
P(t) = P(t0) + dP/dt * (t - t0)
~~~

where:

- `t0` is the parameter reference epoch;
- `t` is the observation/coordinate epoch;
- `P(t0)` is the parameter value at the reference epoch;
- `dP/dt` is its signed rate of change.

EPSG parameter 1047 is **Parameter reference epoch**.

PROJ uses the same model for kinematic Helmert transformations through
`t_epoch`, with coordinate/observation time supplied separately.

## Epoch representation

### Decision: introduce a strong epoch value

The public API SHOULD use a dedicated:

~~~d
Epoch!T
~~~

rather than accepting an unlabelled floating scalar wherever an epoch is
required.

The strong type exists to prevent accidental substitution of:

- a duration for an epoch;
- a coordinate value for an epoch;
- an arbitrary scalar whose temporal interpretation is unknown.

The initial semantic representation is **decimal year**.

Suggested surface:

~~~d
struct Epoch(T)
if (isGeodesyScalar!T)
{
    static bool tryFromDecimalYear(T value, out Epoch!T result)
        pure nothrow @safe @nogc;

    static Epoch!T fromDecimalYear(T value)
        @safe;

    @property T decimalYear() const
        pure nothrow @safe @nogc;

    T yearsSince(const Epoch!T reference) const
        pure nothrow @safe @nogc;
}
~~~

Exact naming remains subject to API review, but the semantic distinction should
not be weakened to raw `T` parameters.

### Validation

An epoch must be finite.

No arbitrary modern-year range should be imposed by the mathematical library.
Historic and future frame definitions may legitimately use epochs outside an
application-specific range.

`.init` SHOULD be invalid if this can be implemented cleanly and portably for
all supported scalars. An accidental default epoch must not silently mean year
zero.

## Meaning of decimal year

For M4, decimal year is a **geodetic parameter coordinate**, not a civil
calendar conversion API.

The library does not infer UTC, TAI, GPS time, leap seconds, month lengths, or
calendar dates from a decimal-year value.

The dynamic Helmert calculation depends only on the difference:

~~~text
deltaYears = observationEpoch - parameterReferenceEpoch
~~~

expressed in the same year unit used by the transformation parameter rates.

EPSG transformation records encode the parameter reference epoch using the
EPSG year unit. Rate parameters are expressed per year.

The first implementation therefore SHOULD preserve decimal-year values as
given and compute their difference directly. Calendar/time-scale conversion
belongs outside geodesy-d unless a later independently justified capability is
admitted.

## Reference epoch versus observation epoch

These are different concepts and MUST remain different API roles.

### Parameter reference epoch

Stored in the dynamic transformation object.

It identifies the epoch at which the base seven transformation parameters are
defined.

### Observation / coordinate epoch

Supplied when evaluating or applying the dynamic transformation.

It identifies the epoch for which the seven transformation parameters must be
propagated.

A dynamic transformation must not silently use its reference epoch as the
observation epoch.

## Temporal metadata ownership

### Decision: do not add epoch state to existing coordinate value types

The existing:

~~~text
GeographicCoordinate
GeodeticCoordinate
GeocentricCoordinate
ProjectedCoordinate
TopocentricCoordinate
~~~

remain pure spatial values.

Adding epoch storage to them would:

- change the frozen v1 meaning and layout of widely used types;
- couple ordinary static mathematics to dynamic-reference-frame metadata;
- make coordinates carry incomplete CRS/reference-frame identity while still
  not being full CRS objects.

For #42 the observation epoch SHOULD therefore be an explicit operation
argument.

Example shape:

~~~d
dynamicTransform.apply(source, observationEpoch)
~~~

or checked equivalent.

A future separate wrapper such as a coordinate-with-metadata object may be
researched independently if real consumers require it. It is not required for
M4 dynamic Helmert mathematics.

## Dynamic Helmert object model

### Decision: prepare dynamic state, evaluate to static state

The dynamic object SHOULD store:

- seven Helmert parameters at the reference epoch;
- seven signed parameter rates;
- parameter reference epoch;
- compile-time Helmert rotation convention.

At an observation epoch it computes the seven propagated parameters and
produces or internally applies the existing convention-specific `Helmert7`
kernel.

Conceptually:

~~~text
Dynamic Helmert parameters + reference epoch
                    |
                    | evaluate(observation epoch)
                    v
         static Helmert7 at epoch
                    |
                    v
          existing static kernel
~~~

This preserves one implementation of the EPSG small-angle spatial Helmert
mathematics and confines time propagation to a narrow layer.

## Convention handling

The existing compile-time convention rule remains authoritative.

Dynamic Position Vector and Dynamic Coordinate Frame forms must be distinct at
the type/API level exactly as their static counterparts are.

Converting between conventions negates:

- rotation parameters;
- rotation-rate parameters.

It does not negate:

- translations;
- translation rates;
- scale difference;
- scale-difference rate;
- reference epoch.

This matches the relationship between EPSG 1053 and EPSG 1056.

## Canonical rate units

The internal/canonical representation SHOULD mirror the existing static
`Helmert7` representation:

~~~text
translation rate       caller linear unit / year
rotation rate          radians / year
scale-difference rate  dimensionless / year
~~~

An EPSG-style interchange factory SHOULD accept:

~~~text
translation rates      caller linear unit / year
rotation rates         arc-seconds / year
scale rate             ppm / year
reference epoch        decimal year
~~~

The public documentation must state that the linear translation unit must match
the geocentric coordinate/translation unit, just as for the current static
Helmert family.

## Scalar and working-precision policy

Supported public scalars remain:

~~~text
float
double
real
~~~

The temporal model itself is linear and does not justify a separate scalar
family.

For public `float`, dynamic parameter propagation SHOULD be evaluated in at
least double working precision before constructing/applying the static
effective parameters. This avoids losing small annual rates when they are
combined with Earth-scale work or epochs near 2000.

For `double`, use double working precision.

For `real`, retain platform `real` precision.

The implementation work in #42 must verify this policy with scalar-specific
reference cases before it becomes normative.

## Failure model

Checked construction/evaluation should fail for:

- non-finite epoch values;
- non-finite canonical/interchange parameters;
- non-finite propagated parameters;
- unrepresentable conversion from interchange units;
- non-finite `deltaYears`.

Throwing convenience APIs should map the same caller-visible failures to
`GeodesyValueException`, following the existing library pattern.

No hidden clamping of epochs or propagated parameters is allowed.

## Static compatibility

The existing static public types and operations remain unchanged.

When all seven rates are zero:

~~~text
DynamicHelmert.evaluate(any finite epoch)
    ==
base Helmert7 at the parameter reference epoch
~~~

subject only to the existing scalar representation rules.

This zero-rate equivalence is a required regression property for #42.

The dynamic implementation should reuse the static Helmert kernel rather than
fork the spatial equations.

## Geographic-domain methods

EPSG also defines geographic 2D/3D time-dependent Position Vector and
Coordinate Frame methods as compositions around the geocentric operation.

For initial M4 scope, geodesy-d SHOULD implement the geocentric mathematical
kernel first.

Geographic 3D composition can already be expressed explicitly as:

~~~text
geodetic
  -> EPSG 9602 geocentric
  -> dynamic geocentric Helmert
  -> EPSG 9602 geodetic
~~~

No separate geographic dynamic-Helmert public family is required for #42 unless
consumer evidence demonstrates that the convenience surface is worth the
additional permanent API.

## Explicit non-goals

Issue #41 does not admit:

- UTC/TAI/GPS time conversion;
- leap-second tables;
- calendar date to decimal-year conversion;
- velocity fields;
- plate-motion models;
- deformation grids;
- CRS/database lookup;
- automatic coordinate-operation discovery;
- epoch metadata added to existing coordinate structs.

## API direction for #42

Recommended conceptual family:

~~~text
Epoch<T>

DynamicHelmert14<T, convention>
├── parameters at reference epoch
├── seven rates
├── referenceEpoch
├── evaluate(observationEpoch) -> Helmert7<T, convention>
└── apply(source, observationEpoch)

PositionVectorHelmert14<T>
CoordinateFrameHelmert14<T>
~~~

The exact public names must pass the normal API audit before merge. In
particular, the project should decide whether the explicit number `14` or the
word `Dynamic` gives the clearest family name without implying that the
reference epoch is one of the fourteen transformation parameters.

## Acceptance for issue #41

- temporal model documented: **yes**;
- epoch/rate units and sign roles unambiguous: **yes**;
- reference epoch separated from observation epoch: **yes**;
- existing coordinate value types remain unchanged: **yes**;
- compatibility path from static Helmert documented: **yes**;
- initial API direction defined: **yes**.

Implementation and final public naming remain work for #42.

## References

- EPSG Guidance Note 7-2, dynamic Helmert methods.
- EPSG method 1053 — Time-dependent Position Vector transformation
  (geocentric).
- EPSG method 1056 — Time-dependent Coordinate Frame rotation (geocentric).
- EPSG parameter 1040–1046 — rates of change of translations, rotations, and
  scale difference.
- EPSG parameter 1047 — Parameter reference epoch.
- PROJ Helmert transformation documentation, kinematic parameter propagation
  and `t_epoch`.
- PROJ time-dependent transformation documentation.
