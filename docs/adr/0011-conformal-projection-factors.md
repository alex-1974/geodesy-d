# ADR-0011: Conformal projection factors

## Context

`geodesy-d` already provides bounded Transverse Mercator and UTM projection operations.

ADR-0006 deliberately excluded meridian convergence and point scale from the initial public Transverse Mercator API. It allowed the numerical kernel to compute these quantities internally and deferred their public exposure until a concrete requirement and sufficient numerical evidence existed.

That evidence now exists.

Dedicated projection-factor research has established:

- forward Transverse Mercator meridian convergence and point scale against independent reference implementations;
- reverse factor evaluation using the accepted post-policy working-precision geographic point;
- the preferred reverse architecture, candidate B;
- `float` behavior for both geodesy-d-generated and independently generated projected inputs;
- representation-aware reverse behavior at the nominal +/-60 degree sheet boundary;
- exact parity between reverse-domain acceptance and reverse-factor acceptance;
- the canonical geographic-pole convention;
- identical observed behavior under DMD and LDC for the dedicated research probes.

The public API can therefore expose these quantities without making their numerical or semantic definition speculative.

## Decision

### Public factor value type

Introduce:

~~~d
module geodesy.projection.factors;

struct ConformalProjectionFactors(T)
if (isGeodesyScalar!T)
{
private:
    Angle!T _meridianConvergence;
    T _pointScale = 0;

package(geodesy):
    static ConformalProjectionFactors fromComponents(
        const Angle!T meridianConvergence,
        const T pointScale)
        pure nothrow @safe @nogc;

public:
    @property Angle!T meridianConvergence() const
        pure nothrow @safe @nogc;

    @property T pointScale() const
        pure nothrow @safe @nogc;
}
~~~

The type is named `ConformalProjectionFactors`, not merely
`ProjectionFactors`.

A single direction-independent point scale is appropriate for a conformal
projection. A future non-conformal projection may require separate meridional,
parallel or principal scales, angular distortion, Tissot quantities or a local
Jacobian.

The present type must not imply that those more general projection properties
can always be represented by one scalar scale factor.

### Meridian convergence

`meridianConvergence` is represented as `Angle!T`.

It is not exposed as a raw scalar in radians.

This follows the existing public unit model in which angular values such as
geodesic azimuths and Helmert rotations use `Angle!T`.

For ordinary non-polar Transverse Mercator points, the stored value is the
normalized meridian convergence produced by the validated numerical kernel.

Its sign convention is part of the public API:

~~~text
meridianConvergence =
    bearing of grid north measured clockwise from true north

positive = clockwise rotation from true north to grid north
negative = counter-clockwise rotation from true north to grid north
~~~

This is also the convention used by the GeographicLib reference oracle against
which the Transverse Mercator factor implementation was validated.

### Point scale

`pointScale` is a dimensionless `T`.

For a valid conformal projection-factor result:

~~~text
pointScale > 0
~~~

`ConformalProjectionFactors!T.init` has `pointScale == 0` and therefore does
not represent a successfully computed factor result.

No public `isValid` property is introduced initially. The type is an operation
result rather than an independently user-constructed domain object.

### Construction

The component constructor is package-visible rather than public.

Callers receive factor values from projection operations. They do not need to
construct arbitrary `ConformalProjectionFactors` instances.

This follows the result-type pattern already used by geodesic operation
results.

## Transverse Mercator API

`TransverseMercator!T` gains four public operations:

~~~d
bool tryForwardFactors(
    const GeographicCoordinate!T source,
    out ConformalProjectionFactors!T result) const
    pure nothrow @safe @nogc;

ConformalProjectionFactors!T forwardFactors(
    const GeographicCoordinate!T source) const
    @safe;

bool tryReverseFactors(
    const ProjectedCoordinate!T source,
    out ConformalProjectionFactors!T result) const
    pure nothrow @safe @nogc;

ConformalProjectionFactors!T reverseFactors(
    const ProjectedCoordinate!T source) const
    @safe;
~~~

The checked and throwing forms follow the existing `tryForward` / `forward`
and `tryReverse` / `reverse` API convention.

### Forward-domain semantics

`tryForwardFactors()` has the same accepted source domain as
`tryForward()`.

For a non-polar input:

~~~text
abs(delta longitude) <= 60 degrees
~~~

subject to the same representation-aware boundary handling already defined by
Transverse Mercator.

A point rejected by `tryForward()` must not be accepted merely because only
factors were requested.

### Reverse-domain semantics

`tryReverseFactors()` has the same represented projected-coordinate
acceptance semantics as `tryReverse()`.

Public `tryReverse()` remains authoritative for:

- invalid projection state;
- non-finite input;
- represented-pole handling;
- reverse numerical validity;
- supported-sheet classification;
- representation-aware boundary excursions.

If an otherwise reconstructed point lies slightly beyond the nominal
+/-60 degree longitude boundary but public reverse policy accepts and clamps
the represented projected coordinate to the boundary, reverse factors are
evaluated at that same post-policy boundary point.

Factors must not be evaluated at a raw reconstructed longitude which public
reverse semantics have replaced by the canonical boundary.

### Reverse numerical architecture

The validated reverse architecture is candidate B:

~~~text
represented projected E/N
        |
        v
public reverse acceptance policy
        |
        v
working-precision reverse point
        |
        v
post-policy pole/boundary semantics
        |
        v
factor evaluation in working precision
        |
        v
public ConformalProjectionFactors<T>
~~~

The public reverse coordinate is not rounded to `T` and then promoted again
for internal factor evaluation.

This avoids measurable loss for `float` while preserving exactly the public
reverse-domain semantics.

A separate direct differentiation of the reverse beta series is not required
by the available numerical evidence.

## Geographic-pole convention

Longitude is degenerate at either geographic pole.

Different longitudes approaching the same pole give different limiting
meridian-convergence values even though they describe the same geographic pole
and project to the same Transverse Mercator E/N point.

`geodesy-d` therefore defines a canonical pole convention:

~~~text
north geographic pole:
    meridianConvergence = 0
    pointScale          = k0

south geographic pole:
    meridianConvergence = 0
    pointScale          = k0
~~~

where `k0` is the scale factor at the natural origin.

The source longitude is ignored.

`meridianConvergence == 0` at the exact pole is an API convention associated
with the canonical central-meridian representation. It does not assert that
true north has a unique tangent direction at the pole.

This convention preserves:

~~~text
forwardFactors(any longitude at a pole)
    ==
reverseFactors(the represented projected pole)
~~~

and is consistent with the existing public rule that forward pole E/N is
longitude-independent while reverse canonicalizes pole longitude to the
central meridian.

## UTM API

`UtmProjection!T` exposes the same four factor operations:

~~~d
bool tryForwardFactors(
    const GeographicCoordinate!T source,
    out ConformalProjectionFactors!T result) const
    pure nothrow @safe @nogc;

ConformalProjectionFactors!T forwardFactors(
    const GeographicCoordinate!T source) const
    @safe;

bool tryReverseFactors(
    const ProjectedCoordinate!T source,
    out ConformalProjectionFactors!T result) const
    pure nothrow @safe @nogc;

ConformalProjectionFactors!T reverseFactors(
    const ProjectedCoordinate!T source) const
    @safe;
~~~

`UtmProjection` remains a policy layer over its prepared bounded Transverse
Mercator operation.

These methods delegate their numerical and domain semantics to the contained
Transverse Mercator instance just as the existing forward and reverse
coordinate operations do.

No separate UTM factor mathematics is introduced.

## Automatic UTM convenience functions

Free functions analogous to:

~~~d
UtmProjection.tryForwardFactors(...)
UtmProjection.tryReverseFactors(...)
~~~

are deferred.

The explicit prepared `UtmProjection!T` API has a direct use case and requires
no new zone-selection semantics.

Automatic factor convenience functions should be added only when a concrete
consumer requires them.

## Combined coordinate-and-factor operations

Operations such as:

~~~d
forwardWithFactors(...)
reverseWithFactors(...)
~~~

are not introduced in this API revision.

Coordinate projection and factor evaluation share substantial intermediate
state, so combined operations may later avoid duplicated computation.

However, no current consumer requires such a public surface.

The production implementation should avoid architectural choices that prevent
a later efficient combined operation, but no speculative public method is
added now.

## Public module surface

Add:

~~~text
source/geodesy/projection/factors.d
~~~

with module:

~~~d
module geodesy.projection.factors;
~~~

The aggregate `geodesy` module publicly imports this factor module.

`ConformalProjectionFactors!T` is therefore a first-class public geodesy-d
value type rather than a nested Transverse Mercator implementation detail.

## Research-to-production transition

The public implementation reuses the numerically validated factor kernel and
semantics established under `ProjectionFactorResearch`.

Research-only entry points remain version-gated while the production API is
being validated.

They must not become public accidentally.

After the public implementation has independent API and regression coverage,
obsolete research entry points may be removed in a separate cleanup change.

Research probes and their recorded evidence may remain as validation and
provenance material.

## Failure semantics

The checked factor methods return `false` under the same relevant conditions
as their corresponding coordinate operations.

The throwing wrappers convert failure to `GeodesyValueException`.

A failed checked call does not return a partially valid factor result.

Because the result argument is an `out` parameter, unsuccessful calls retain
the type's default initialized state.

Factor methods do not silently enlarge the supported coordinate domain.

## Validation requirements

Before the public API is accepted, the implementation must demonstrate:

- DMD and LDC unit-test success;
- normal release-build success under DMD and LDC;
- public API contract coverage for the new type and methods;
- no `ProjectionFactorResearch` symbol leakage into normal builds;
- forward-factor agreement with the established independent reference corpus;
- reverse-factor agreement with the established independent reference corpus;
- the independent binary32 projected-input validation;
- representation-aware +/-60 degree boundary acceptance parity;
- the PF-A pole convention for sphere and WGS84 under both `float` and
  `double`;
- UTM factor delegation equivalence with the underlying prepared Transverse
  Mercator operation;
- documentation of units, sign convention, pole semantics and failure
  semantics.

The existing Transverse Mercator coordinate-validation gates must remain
unchanged and passing.

## Alternatives considered

### Public raw scalar outputs

Example:

~~~d
bool tryForwardFactors(
    GeographicCoordinate!T source,
    out T convergenceRadians,
    out T pointScale);
~~~

Rejected.

The two quantities form one logical operation result, and exposing convergence
as a raw scalar weakens the existing strong angular-unit model.

### Generic `ProjectionFactors<T>`

Rejected for the current two-component type.

A single `pointScale` is specifically appropriate to a conformal projection.
A generic name would imply an adequate model for non-conformal projections,
where local scale can depend on direction.

A future general projection differential/factor model remains possible without
changing this conformal type.

### Transverse-Mercator-specific factor type

Example:

~~~text
TransverseMercatorFactors<T>
~~~

Rejected.

Meridian convergence plus one isotropic point scale are not unique to
Transverse Mercator. UTM already needs exactly the same value model, and other
conformal projections may do so later.

### Copy the GeographicLib API directly

Rejected.

GeographicLib remains an important numerical reference, but geodesy-d defines
its own value types, bounded domain, failure policy and canonical geographic
pole behavior.

### Longitude-dependent forward pole convergence

Rejected.

Such a value describes an approach-direction limit rather than a unique
property of the represented pole.

It would also allow several source coordinates that project to identical E/N
to produce different factors while reverse factors for that same projected
point require a canonical longitude.

### Only provide combined coordinate-and-factor methods

Rejected.

It would force callers that require only factors to request an unnecessary
coordinate result and would prematurely enlarge the operation-result API.

Combined methods remain a possible later optimization-oriented addition.

## Consequences

### Positive

- exposes independently validated projection factors;
- retains strong angular typing;
- makes conformal semantics explicit in the result type;
- gives forward and reverse factor operations symmetric APIs;
- preserves existing Transverse Mercator domain behavior;
- gives represented boundary points one consistent coordinate/factor policy;
- makes pole behavior deterministic and direction-independent;
- gives UTM factors without duplicating projection mathematics;
- leaves room for a later general non-conformal projection differential model;
- leaves room for efficient combined coordinate-and-factor operations when a
  concrete consumer requires them.

### Negative

- adds one public value type and four methods to each prepared conformal
  projection surface;
- requires a new public module and API-contract coverage;
- callers needing both coordinates and factors may initially perform duplicated
  work;
- the canonical exact-pole convergence differs deliberately from a
  longitude-dependent forward limiting convention used by some external
  implementations.

## Relationship to earlier decisions

ADR-0006 remains correct: projection factors were deliberately excluded from
the initial bounded Transverse Mercator public API until there was a concrete
reason and sufficient validation.

ADR-0011 is the later compatible extension anticipated by that decision.

ADR-0007 remains correct: UTM is a policy layer over bounded Transverse
Mercator. UTM factor operations therefore delegate to the same underlying
projection rather than defining separate factor mathematics.