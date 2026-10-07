# Dynamic Helmert validation

Status: **M4 implementation qualification for issue #42**

## Scope

This document defines the acceptance program for the additive time-dependent
Helmert family:

~~~text
Epoch<T>
Helmert14<T, convention>
PositionVectorHelmert14<T>
CoordinateFrameHelmert14<T>
~~~

The implementation covers the geocentric forms of:

- EPSG 1053 — Time-dependent Position Vector transformation;
- EPSG 1056 — Time-dependent Coordinate Frame rotation.

The temporal contract is defined in `docs/M4_EPOCH_SEMANTICS.md`.

## Authoritative semantics

For each of the seven Helmert parameters:

~~~text
P(t) = P(t0) + dP/dt * (t - t0)
~~~

where `t0` is the parameter reference epoch and `t` is the observation
epoch.

Canonical units are:

~~~text
translation             caller linear unit
translation rate        caller linear unit / year
rotation                radians
rotation rate           radians / year
scale difference        dimensionless
scale-difference rate   dimensionless / year
epoch                    decimal year
~~~

The EPSG interchange factory accepts rotations in arc-seconds, rotation rates
in arc-seconds/year, scale difference in ppm, and scale rate in ppm/year.

Position Vector and Coordinate Frame representations describe the same physical
transformation when both the rotation parameters and the rotation-rate
parameters are negated.

## EPSG 1053 worked example

The source test uses the EPSG Guidance Note 7-2 / method 1053 example:

~~~text
ITRF2008 -> GDA94
observation epoch = 2013.90
parameter reference epoch = 1994.00

source:
X = -3789470.710 m
Y =  4841770.404 m
Z = -1690893.952 m

base:
tX = -0.08468 m
tY = -0.01942 m
tZ = +0.03201 m
rX = +0.0004254 arcsec
rY = -0.0022578 arcsec
rZ = -0.0024015 arcsec
dS = +0.00971 ppm

rates:
dtX = +0.00142 m/year
dtY = +0.00134 m/year
dtZ = +0.00090 m/year
drX = -0.0015461 arcsec/year
drY = -0.0011820 arcsec/year
drZ = -0.0011551 arcsec/year
ddS = +0.000109 ppm/year
~~~

The published time-adjusted values are approximately:

~~~text
tX' = -0.05642 m
tY' = +0.00725 m
tZ' = +0.04992 m
rX' = -1.471021e-7 rad
rY' = -1.249830e-7 rad
rZ' = -1.230844e-7 rad
dS' = +0.01188 ppm
~~~

and the published target coordinate is:

~~~text
X = -3789470.004 m
Y =  4841770.686 m
Z = -1690895.108 m
~~~

These values are asserted directly by the module unit tests.

## Independent differential validation

`tools/validate-dynamic-helmert-differential.sh` builds the D probe and
evaluates the same coordinate/parameter set with PROJ's kinematic
`+proj=helmert` implementation.

Two representations are checked independently:

1. Position Vector with the EPSG 1053 rotation/rate signs;
2. Coordinate Frame with both rotation and rotation-rate signs negated.

The D and PROJ geocentric outputs must agree within the validator's micrometre
budget, and the two D convention representations must agree with each other.

The CI gate runs this differential validation with:

- DMD 2.111.0;
- LDC 1.41.0.

## Scalar policy

The public family supports:

~~~text
float
double
real
~~~

Rate propagation uses:

~~~text
float  -> double working precision -> float effective parameters
double -> double working precision
real   -> platform real working precision
~~~

The unit tests instantiate and evaluate all three scalar families.

## Static-kernel regression

When all seven rates are zero, `evaluate(observationEpoch)` must return the
stored static `Helmert7` parameters exactly for every finite observation
epoch.

Dynamic spatial application delegates to the existing convention-specific
static Helmert kernels. This prevents a second implementation of the EPSG
small-angle matrix from diverging from the accepted v1 behavior.

## Default and failure behavior

`Epoch<T>.init` is invalid.

`Helmert14<T, convention>.init` is invalid because its reference epoch is
invalid.

Checked construction/evaluation/application returns `false` for invalid
epochs, non-finite rates, non-finite propagated values, or unrepresentable
results. Throwing convenience methods report the corresponding failure with
`GeodesyValueException`.

No epoch or parameter is silently clamped.

## Non-goals

This gate does not qualify:

- geographic 2D/3D convenience wrappers around the geocentric method;
- CRS databases or operation discovery;
- plate-motion or deformation grids;
- calendar/time-scale conversion;
- leap-second handling;
- exact finite-angle Helmert rotations.

## References

- EPSG Guidance Note 7-2 (IOGP Report 373-07-02).
- EPSG method 1053 — Time-dependent Position Vector transformation
  (geocentric).
- EPSG method 1056 — Time-dependent Coordinate Frame rotation (geocentric).
- EPSG parameter 1047 — Parameter reference epoch.
- PROJ Helmert transformation documentation — kinematic parameters,
  `t_epoch`, observation time, and convention mapping.
