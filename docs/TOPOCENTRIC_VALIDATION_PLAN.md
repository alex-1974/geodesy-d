# Topocentric ENU validation plan

- Status: Draft acceptance specification
- Date: 2026-09-20
- Applies to: ADR-0009
- Intended methods: EPSG 9836 and EPSG 9837

## Purpose

This document defines the evidence required before the topocentric ENU
capability may be accepted into the public `geodesy-d` surface.

It is written before production implementation so that implementation choices
cannot redefine the success criteria.

The validation program must establish separately:

1. EPSG 9836 geocentric/topocentric semantics;
2. EPSG 9837 geographic/topocentric semantics;
3. forward and reverse numerical accuracy;
4. deterministic origin, pole, and failure semantics;
5. scalar-specific representation behavior;
6. public API/runtime attributes;
7. compiler and platform behavior.

Self-roundtrip checks are useful regressions but are not independent accuracy
evidence.

## Acceptance gates

Use the following staged gates:

~~~text
TOPO-A  contract, coordinate model, and canonical semantics             PASS
TOPO-B  EPSG worked vectors and analytical invariants                   PASS
TOPO-C  PROJ differential/interoperability validation                   PASS
TOPO-D  GeographicLib LocalCartesian differential validation            PASS
TOPO-E  adversarial origins, poles, float representation, failure       PASS
TOPO-F  public API/runtime contract                                     PASS
TOPO-G  compiler/platform/real-width coverage                           PENDING
~~~

TOPO-A was completed on 2026-09-20. Its accepted candidate public surface is
recorded in:

~~~text
research/topocentric/api_surface.md
docs/adr/0009-topocentric-enu.md
~~~

ADR-0009 remains Proposed until all remaining required gates pass.

## Reference hierarchy

### A. Normative semantics

Use:

~~~text
IOGP Report 373-07-02
EPSG Guidance Note 7-2
December 2024

EPSG 9602
EPSG 9836
EPSG 9837
~~~

This reference is normative for:

- East/North/Up orientation;
- right-handed axis convention;
- ellipsoid-normal Up;
- origin interpretation;
- forward/reverse operation semantics;
- published worked examples.

### B. Analytical reference

EPSG 9836 is a translation followed by an orthonormal rotation.

Use independently coded analytical checks for:

- frame origin;
- equatorial frames;
- axis-aligned origins;
- cardinal displacements;
- matrix orthonormality;
- determinant `+1`;
- inverse equal to transpose;
- preservation of Euclidean norm by the rotation.

These checks must not call the production rotation helper.

### C. PROJ interoperability reference

Use a current stable PROJ release and record its exact version.

Validate:

~~~text
+proj=topocentric
~~~

against EPSG 9836 and:

~~~text
+proj=pipeline
+step +proj=cart
+step +proj=topocentric
~~~

against EPSG 9837.

PROJ is an interoperability oracle, not a runtime dependency.

### D. GeographicLib reference

Use GeographicLib 2.7 `LocalCartesian` for an independent
geodetic/topocentric implementation comparison.

Record the exact library version and build configuration.

Because GeographicLib and the intended implementation both ultimately use
geocentric coordinates and an orthonormal local rotation, agreement is strong
implementation evidence but does not replace EPSG normative vectors and
analytical invariants.

## Mandatory EPSG worked example

Use the current Guidance Note 7-2 WGS 84 example.

### EPSG 9836 origin

~~~text
X0 = 3652755.3058 m
Y0 =  319574.6799 m
Z0 = 5201547.3536 m

a   = 6378137.0 m
1/f = 298.257223563
~~~

Derived origin orientation:

~~~text
phi0    = 0.9599310885 rad
lambda0 = 0.0872664625 rad
~~~

Source:

~~~text
X = 3771793.968 m
Y =  140253.342 m
Z = 5124304.349 m
~~~

Expected:

~~~text
East  / U = -189013.869 m
North / V = -128642.040 m
Up    / W =   -4220.171 m
~~~

Validate both forward and reverse, using tolerances consistent with the
rounding of the published values.

### EPSG 9837 origin and source

Origin:

~~~text
latitude  = 55 degrees north
longitude = 5 degrees east
height    = 200 m
~~~

Source:

~~~text
latitude  = 53 deg 48 min 33.82 sec north
longitude =  2 deg 07 min 46.38 sec east
height    = 73 m
~~~

Expected ENU is the same published triplet above.

Validate forward and reverse.

## TOPO-B achieved evidence

TOPO-B completed successfully on 2026-09-20.

Committed research probes:

~~~text
research/topocentric/epsg_reference_probe.d
research/topocentric/analytical_rotation_probe.d
~~~

Both probes are deliberately independent of the production `geodesy-d`
implementation.

The EPSG reference probe directly evaluates the published WGS 84 EPSG
9836/9837 worked case using an independent EPSG 9602 forward formula, an
ordinary-position research-only reverse conversion, and explicit EPSG 9836
rotation formulas.

The probe passed under both DMD and LDC with identical reported results.

### EPSG 9602 preparation

The independently calculated geocentric coordinates reproduce the published
rounded values.

Maximum observed absolute differences:

~~~text
origin ECEF:  0.000011131 m
source ECEF:  0.000358218 m
~~~

These are within the millimetre rounding of the published coordinates.

### EPSG 9836

Forward geocentric -> topocentric maximum component difference from the
published ENU result:

~~~text
0.000305420 m
~~~

Reverse topocentric -> geocentric maximum component difference from the
published rounded source ECEF coordinate:

~~~text
0.000358404 m
~~~

The reverse comparison starts from the published ENU values rounded to
millimetres, so this residual is consistent with source rounding.

### EPSG 9837

Forward geographic -> topocentric maximum component difference from the
published ENU result:

~~~text
0.000241598 m
~~~

Reverse topocentric -> geographic differences from the published source
coordinate are:

~~~text
latitude:   3.031137e-11 rad
longitude:  4.020775e-11 rad
height:     0.000241983 m
~~~

These are comfortably inside the tolerances selected from the precision of
the published source values.

### Analytical rotation invariants

The independent analytical probe tested the EPSG 9836 ENU rotation for the
Cartesian product:

~~~text
latitudes:
    -90, -80, -45, 0, 45, 80, 90 degrees

longitudes:
    -180, -90, -1, 0, 1, 90, 180 degrees
~~~

For all 49 orientations it verified:

~~~text
R * transpose(R) = I
transpose(R) * R = I
det(R) = +1
Euclidean norm preservation
transpose(R) is the numerical inverse
~~~

Additional analytical cases verified:

- East/North/Up axis signs at the equator;
- explicit longitude-dependent East/North orientation at the north pole;
- unchanged polar Up direction;
- frame origin mapping exactly to ENU zero.

The analytical probe passed under both DMD and LDC.

### TOPO-B conclusion

TOPO-B is PASS.

The normative worked vectors, forward/reverse signs, handedness, and
orthonormal rotation semantics are sufficiently established to proceed to
independent implementation differential validation.

No production implementation is implied by this gate.

## TOPO-C PROJ interoperability differential

The external PROJ oracle was independently qualified before production
topocentric implementation. The implemented public `geodesy-d` topocentric
API has now also been differentially validated against that oracle and against
independently coded analytical ECEF/ENU mathematics.

Status:

~~~text
PROJ oracle qualification     PASS
geodesy-d differential        PASS
TOPO-C overall                PASS
~~~

### Oracle environment

The qualified local reference executable is:

~~~text
cct: Rel. 9.7.1, December 1st, 2025
~~~

The committed qualification harness is:

~~~text
research/topocentric/validate_proj_oracle.py
~~~

Deterministic PRNG seed:

~~~text
0x544F504F5F50524F
~~~

The exact PROJ version is recorded as evidence for this validation run.
A later release-validation run may use another explicitly recorded PROJ
version, but must not silently substitute an unknown oracle version.

### Qualification corpus

The corpus covers:

~~~text
ellipsoids:
    WGS 84
    GRS 80
    Airy 1830
    sphere, radius 6371000 m

origins:
    equator / Greenwich
    Vienna-like mid-latitude
    Sydney-like southern latitude
    antimeridian-near origin
    high northern latitude
~~~

Source points combine:

- a structured latitude/longitude/height matrix;
- a deterministic global random corpus;
- deterministic local points around each origin.

Total evaluated cases:

~~~text
EPSG 9836: 17040
EPSG 9837: 17040
~~~

Each method is exercised in both forward and reverse directions.

Exact poles and deliberately pathological/deep-interior cases remain assigned
to TOPO-E rather than being conflated with this interoperability gate.

### Independent reference comparison

The harness compares PROJ EPSG 9836/9837 behavior against independently coded
geodetic/ECEF and ENU research mathematics.

Observed global maxima:

~~~text
EPSG 9836 forward:
    3.725290298462e-09 m

EPSG 9836 reverse:
    6.519258022308e-09 m

EPSG 9837 forward:
    5.580659490079e-09 m
~~~

These values show nanometre-scale agreement between PROJ's topocentric
operation and the independent reference over the qualification corpus.

### Reverse EPSG 9837 oracle floor

The geographic reverse path additionally includes PROJ's ECEF-to-geodetic
`cart -I` operation.

Observed EPSG 9837 reverse maxima were:

~~~text
latitude:
    1.337481306703e-11 rad

longitude:
    5.062616992291e-14 rad

height:
    9.956931171473e-05 m
~~~

The isolated PROJ `cart -I` baseline over the same source ECEF coordinates was:

~~~text
latitude:
    1.337444102772e-11 rad

longitude:
    4.440892098501e-16 rad

height:
    9.956744906958e-05 m
~~~

The approximately 0.1 mm reverse-geographic floor is therefore attributable
to the PROJ geocentric-to-geodetic inverse rather than to the topocentric
rotation itself.

### Paired pipeline-delta test

Aggregate maxima are not sufficient to prove that the topocentric stage adds
negligible error because unrelated cases may produce those maxima.

The final qualification therefore compares, for every individual case, the
complete inverse EPSG 9837 result with the isolated `cart -I` result for the
same exact ECEF source coordinate.

Maximum paired differences were:

~~~text
latitude:
    7.440786129085e-16 rad

longitude:
    5.062616992291e-14 rad

height:
    6.519258022308e-09 m
~~~

This establishes that the topocentric portion contributes only
floating-point-scale additional error relative to the underlying PROJ
geographic inverse.

### Qualification thresholds

The committed oracle-qualification limits are intentionally not public
`geodesy-d` accuracy contracts.

They are:

~~~text
topocentric-only linear comparison:
    <= 1e-6 m

reverse EPSG 9837 absolute sanity ceilings:
    latitude  <= 2e-11 rad
    longitude <= 1e-12 rad
    height    <= 2e-4 m

paired EPSG 9837 versus isolated cart-inverse delta:
    latitude  <= 1e-13 rad
    longitude <= 1e-12 rad
    height    <= 1e-6 m
~~~

The distinction between absolute oracle accuracy and paired pipeline delta is
deliberate. A looser geographic reverse bound must not conceal a defect in the
topocentric operation itself.

### Production differential corpus

The production differential harness is:

~~~text
research/topocentric/geodesy_topocentric_probe.d
research/topocentric/validate_geodesy_vs_proj.py
~~~

The D probe imports only public `geodesy` modules and exercises the public
`TopocentricFrame` API. The Python driver compares its results with PROJ and
with independently coded analytical reference mathematics.

The deterministic corpus uses the same four ellipsoids and five representative
origins as the qualified oracle. It executes:

~~~text
EPSG 9836 forward:   100000 cases
EPSG 9836 reverse:   100000 cases
EPSG 9837 forward:   100000 cases
EPSG 9837 reverse:   100000 cases
~~~

The reverse corpus is generated independently in ENU space rather than by
feeding forward results back into the inverse. Structured and random reverse
vectors range from millimetres through hundreds of kilometres, including
500 km components.

Recorded environment for the acceptance run:

~~~text
PROJ:
    cct 9.7.1

DMD:
    DMD64 D Compiler v2.111.0

LDC:
    LDC 1.41.0

forward seed:
    0x121814101B191409

reverse seed:
    0x060A06101B191409
~~~

DMD and LDC produced identical reported maxima and worst-case witnesses.

Observed maxima were:

~~~text
EPSG 9836 forward
    geodesy-d vs PROJ:
        6.519258022308e-09 m
    geodesy-d vs analytical:
        6.519258022308e-09 m

EPSG 9836 reverse
    geodesy-d vs PROJ:
        1.862645149231e-09 m
    geodesy-d vs analytical:
        1.862645149231e-09 m

EPSG 9837 forward
    geodesy-d vs PROJ:
        8.371898729820e-09 m
    geodesy-d vs analytical:
        5.820766091347e-09 m

EPSG 9837 reverse
    geodesy-d reconstructed-ECEF residual:
        8.870847523212e-08 m
~~~

The direct reverse-geographic comparison against PROJ reached:

~~~text
latitude:
    4.390929427613e-10 rad

longitude:
    1.776356839400e-15 rad

height:
    2.884217072278e-03 m
~~~

These values are not used as `geodesy-d` acceptance limits because the same
corpus demonstrated that they are dominated by PROJ's geocentric-to-geodetic
inverse.

For the exact same reverse target ECEF coordinates:

~~~text
PROJ complete EPSG 9837 inverse ECEF residual:
    3.868382424116e-03 m

isolated PROJ cart-inverse ECEF residual:
    3.868382424116e-03 m
~~~

The paired complete-pipeline versus isolated-cart differences were only:

~~~text
latitude:
    4.960524086057e-16 rad

longitude:
    1.776356839400e-15 rad

height:
    4.656612873077e-09 m
~~~

This pointwise attribution establishes that the millimetre-scale direct
geographic difference is due to PROJ's `cart -I` stage, not to its
topocentric rotation.

The committed TOPO-C acceptance limits are validation gates rather than public
accuracy guarantees:

~~~text
EPSG 9836 forward:
    geodesy-d vs PROJ        <= 1e-6 m
    geodesy-d vs analytical  <= 1e-6 m

EPSG 9836 reverse:
    geodesy-d vs PROJ        <= 1e-6 m
    geodesy-d vs analytical  <= 1e-6 m

EPSG 9837 forward:
    geodesy-d vs PROJ        <= 1e-6 m
    geodesy-d vs analytical  <= 1e-6 m

EPSG 9837 reverse:
    geodesy-d reconstructed-ECEF residual
        <= 1e-6 m

PROJ pipeline attribution:
    latitude   <= 1e-13 rad
    longitude  <= 1e-12 rad
    height     <= 1e-6 m
~~~

Direct EPSG 9837 reverse `geodesy-d` versus PROJ latitude/longitude/height
differences remain reported diagnostics but are deliberately not acceptance
criteria.

### TOPO-C status

The PROJ reference system is qualified and the implemented public
`TopocentricFrame` API has passed the deterministic production differential
corpus with both DMD and LDC.

TOPO-C is therefore PASS.


## TOPO-D GeographicLib LocalCartesian differential

TOPO-D completed successfully on 2026-09-20.

This gate uses GeographicLib 2.7 `LocalCartesian` as a second external
implementation reference for the geographic/topocentric path corresponding
to EPSG 9837.

GeographicLib is validation infrastructure only. The production `geodesy-d`
library does not link to or require GeographicLib.

Because GeographicLib `LocalCartesian` and `geodesy-d` both ultimately use
geocentric coordinates plus an orthonormal local rotation, this is strong
implementation evidence but not mathematically independent evidence.
Normative EPSG vectors and the independent analytical checks from TOPO-B
remain separate acceptance layers.

### TOPO-D harness

Committed research programs:

~~~text
research/topocentric/geographiclib_localcartesian_probe.cpp
research/topocentric/validate_geodesy_vs_geographiclib.py
~~~

The C++ probe constructs a GeographicLib `Geocentric` object explicitly for
each tested ellipsoid and prepares a `LocalCartesian` frame from the supplied
geodetic origin.

The Python driver compares:

~~~text
geodesy-d public TopocentricFrame API
GeographicLib 2.7 LocalCartesian
independently coded analytical ECEF/ENU reference mathematics
~~~

### TOPO-D corpus

The deterministic corpus deliberately reuses the TOPO-C ellipsoids, origins,
case counts, and seeds so that the two external implementation gates are
directly comparable.

~~~text
ellipsoids:
    WGS 84
    GRS 80
    Airy 1830
    sphere, radius 6371000 m

origins:
    equator / Greenwich
    Vienna-like mid-latitude
    Sydney-like southern latitude
    antimeridian-near origin
    high northern latitude

forward cases/profile:
    5000

reverse cases/profile:
    5000

total forward cases:
    100000

total independently generated reverse ENU cases:
    100000

forward seed:
    0x121814101B191409

reverse seed:
    0x060A06101B191409
~~~

The reverse corpus is generated directly in ENU space rather than by feeding
forward results back into the reverse operation.

### TOPO-D environment

The accepted runs used:

~~~text
GeographicLib:
    2.7-1

C++ compiler:
    g++ 15.2.0

DMD:
    DMD64 D Compiler v2.111.0

LDC:
    LDC 1.41.0
~~~

DMD and LDC produced identical reported maxima and identical worst-case
witnesses.

### TOPO-D observed maxima

Forward:

~~~text
geodesy-d vs GeographicLib:
    7.450580596924e-09 m

geodesy-d vs analytical:
    5.820766091347e-09 m

GeographicLib vs analytical:
    5.587935447693e-09 m
~~~

Independent reverse ENU corpus:

~~~text
geodesy-d vs GeographicLib latitude:
    1.506759191140e-14 rad

geodesy-d vs GeographicLib longitude:
    7.105427357601e-14 rad

geodesy-d vs GeographicLib height:
    5.456968210638e-09 m

geodesy-d reconstructed-ECEF residual:
    8.870847523212e-08 m

GeographicLib reconstructed-ECEF residual:
    4.656612873077e-09 m
~~~

Unlike the PROJ EPSG 9837 reverse comparison, this GeographicLib comparison
does not exhibit a millimetre-scale geocentric-to-geodetic reference floor.

### TOPO-D acceptance limits

The committed limits are research/release validation gates, not public
accuracy guarantees:

~~~text
forward geodesy-d vs GeographicLib:
    <= 1e-6 m

forward geodesy-d vs analytical:
    <= 1e-6 m

forward GeographicLib vs analytical:
    <= 1e-6 m

reverse geodesy-d vs GeographicLib:
    latitude  <= 1e-12 rad
    longitude <= 1e-12 rad
    height    <= 1e-6 m

reverse reconstructed-ECEF residual:
    geodesy-d      <= 1e-6 m
    GeographicLib  <= 1e-6 m
~~~

All eight criteria pass under both DMD and LDC.

### TOPO-D status

TOPO-D is PASS.

The public geographic/topocentric implementation has therefore been checked
against both PROJ interoperability behavior and GeographicLib
`LocalCartesian`, in addition to the normative and analytical evidence from
TOPO-B.


## TOPO-E adversarial and failure validation

TOPO-E completed successfully on 2026-09-20.

This gate executes the adversarial and failure semantics frozen before
implementation in
`research/topocentric/preimplementation_contract.md`.

The dedicated research probe is:

~~~text
research/topocentric/topo_e_contract_probe.d
~~~

The probe intentionally exercises the public `geodesy-d` topocentric API.
Existing production unittests and negative compile-time API tests provide
additional evidence where the frozen contract concerns implementation details
or public immutability.

### TOPO-E compiler runs

The complete probe was built and executed under:

~~~text
DMD:
    DMD64 D Compiler v2.111.0

LDC:
    LDC 1.41.0
~~~

Both compiler runs completed successfully with identical output.

Each run executed:

~~~text
889 contract checks
~~~

### TOPO-E covered behavior

The executed contract includes:

- `TopocentricCoordinate.init` and finite construction for
  `float`, `double`, and `real`;
- systematic NaN and positive/negative infinity rejection in East, North,
  and Up for all three supported scalars;
- checked and throwing failure behavior;
- `TopocentricFrame.init` rejection for all supported scalars;
- all four checked and throwing conversions on invalid frames;
- invalid ellipsoid rejection through both frame-construction paths;
- exact geocentre rejection;
- a complete 9 x 9 geodetic-origin matrix for each supported scalar,
  covering the frozen latitude and longitude domain;
- exact north- and south-pole orientation;
- physical equivalence of `+180` and `-180` meridian orientation, while the
  existing production unittest separately verifies that supplied polar
  longitude is not implicitly canonicalized during frame preparation;
- north and south geocentric rotation-axis origins for all supported scalars,
  inheriting canonical EPSG 9602 longitude zero;
- deep-interior geocentric origin behavior inherited from the existing
  EPSG 9602 canonical inverse;
- spherical ellipsoid support through geodetic- and geocentric-origin
  construction, EPSG 9836 forward/reverse, EPSG 9837 forward/reverse, and
  both poles;
- antimeridian continuity and equivalent `+180` / `-180` geometry;
- finite-arithmetic failure handling for `float`, `double`, and `real`;
- the direct reverse EPSG 9837 `float` path retaining working ECEF precision
  until the final public narrowing.

### Float representation evidence

Forward `GeodeticCoordinate<float>` composition was already protected by a
production regression test demonstrating that introducing an Earth-scale
`GeocentricCoordinate<float>` intermediate materially changes local ENU
results.

TOPO-E adds the corresponding reverse-path check.

For four deterministic `TopocentricCoordinate<float>` cases, the direct
reverse EPSG 9837 result is exactly the final `float` narrowing of the same
calculation performed with represented public inputs in the promoted
`double` working scalar.

The probe also deliberately materializes the forbidden reverse intermediate:

~~~text
TopocentricCoordinate<float>
    -> GeocentricCoordinate<float>
    -> geodetic
~~~

Compared with the promoted working-ECEF path, the largest observed binary32
ECEF component quantization was:

~~~text
0.233677798 m
~~~

This diagnostic is not a public accuracy guarantee. It demonstrates why the
working-precision rule is required and keeps caller-input representation error
separate from kernel error.

### TOPO-E status

TOPO-E is PASS.

No production-code correction was required by the adversarial gate.

## Coordinate value-type gate

For `TopocentricCoordinate!T`, verify for:

~~~text
float
double
real
~~~

that:

- finite East/North/Up values are accepted;
- NaN and infinities are rejected;
- `.init` is `(0,0,0)`;
- the type carries no CRS/frame/datum/unit metadata;
- read-only component access matches the established coordinate-type pattern.

## Frame-construction gate

### Geodetic origins

At minimum use:

~~~text
latitude:
    -90
    -89.999999
    -80
    -45
     0
    +45
    +80
    +89.999999
    +90 deg

longitude:
    -180
    -179.999999
    -90
    -1
     0
    +1
    +90
    +179.999999
    +180 deg
~~~

Test representative combinations rather than only one meridian.

At exact poles, repeat the same physical origin using multiple explicit
longitudes and prove:

- Up is unchanged;
- East/North rotate according to the supplied longitude;
- reverse operations preserve the frame's chosen orientation.

### Geocentric origins

Include:

- ordinary WGS 84 surface-near origins;
- equatorial axis-aligned origins;
- north and south rotation-axis origins;
- origins generated from multiple terrestrial ellipsoids;
- exact `(0,0,0)` rejection.

A non-zero rotation-axis origin must inherit the existing EPSG 9602
longitude-zero convention.

## Ellipsoid matrix

At minimum validate:

~~~text
WGS 84
GRS 80
Airy 1830
Bessel 1841
Clarke 1866
International 1924
Earth-sized sphere
synthetic valid oblate ellipsoid
~~~

The topocentric operation must not introduce an arbitrary `f <= 0.01`
restriction unless validation discovers a concrete numerical reason.

Record the actual supported `Ellipsoid!T` domain at acceptance.

## Height and distance profiles

### Ordinary terrestrial profile

Initially validate origins and geodetic source points over at least:

~~~text
origin ellipsoidal height:
    -20 km through +100 km

source ellipsoidal height:
    -20 km through +100 km
~~~

This is an accuracy-validation profile, not automatically a construction
restriction.

### Local displacement profile

Exercise local ENU magnitudes spanning:

~~~text
millimetres
centimetres
metres
tens/hundreds of metres
kilometres
hundreds of kilometres
~~~

Include displacements dominated individually by East, North, and Up as well as
mixed directions.

### Wider robustness profile

Add finite high-altitude and long-baseline cases to distinguish the validated
ordinary accuracy envelope from broader arithmetic robustness.

No stronger physical-use interpretation should be inferred from those stress
cases.

## Analytical invariants

For the prepared rotation matrix `R` verify independently:

~~~text
R * transpose(R) = I
transpose(R) * R = I
det(R) = +1
~~~

within scalar-appropriate numerical tolerances.

For arbitrary finite displacement vector `d`:

~~~text
norm(R * d) == norm(d)
~~~

within expected floating-point error.

For source equal to origin:

~~~text
East  = 0
North = 0
Up    = 0
~~~

subject only to the eventual documented signed-zero convention.

Reverse of an independently generated ENU displacement must equal application
of the transposed reference matrix plus origin.

## Cardinal-direction cases

Construct analytical cases at the equator and selected mid-latitudes where
ECEF displacement directions can be chosen to represent pure:

~~~text
East
North
Up
~~~

Verify sign and handedness explicitly.

These tests guard against common:

- axis swaps;
- ENU/NEU confusion;
- transpose errors;
- sign errors.

## Antimeridian and longitude representation

Use geodetic origins around:

~~~text
-180 deg
+180 deg
-179.999999 deg
+179.999999 deg
~~~

and nearby source points represented on both sides of the longitude boundary.

Equivalent longitude representations must yield equivalent physical frame
orientation and coordinate results.

## Pole semantics

### Geodetic-origin pole

For both poles, prepare frames using multiple longitudes.

Verify that explicit longitude determines rotation of the East/North axes.

### Geocentric-origin pole

Construct the same physical axis origin only from `(X0,Y0,Z0)`.

Verify that frame orientation follows the existing EPSG 9602 canonical
longitude-zero convention.

Do not silently equate these two construction semantics: a geodetic polar
origin carries an explicit orientation parameter that pure axis ECEF
coordinates do not contain.

## Float representation gate

This is a mandatory acceptance gate.

Near Earth radius, binary32 ECEF coordinate spacing is of decimetre/metre
scale, while topocentric applications commonly require much smaller local
differences.

Validate separately:

### A. Geodetic float path

~~~text
GeodeticCoordinate<float>
    ->
TopocentricCoordinate<float>
~~~

The kernel must use promoted working precision without materializing an
intermediate public `GeocentricCoordinate<float>`.

Compare against a double/high-precision reference evaluated from the same
represented public float input values.

Measure final ENU error after only the public output rounding.

### B. Geocentric float path

~~~text
GeocentricCoordinate<float>
    ->
TopocentricCoordinate<float>
~~~

Quantize source and origin to actual public binary32 ECEF values before
reference comparison.

Report separately:

- error relative to the represented float ECEF inputs;
- loss relative to the unquantized physical source coordinates.

The latter is an input-representation limitation, not kernel error.

### C. Reverse paths

Perform the corresponding distinction for:

~~~text
Topocentric<float> -> Geocentric<float>
Topocentric<float> -> Geodetic<float>
~~~

The geodetic reverse path must not unnecessarily narrow an internal
working-precision ECEF result before EPSG 9602 reverse conversion.

Do not select the public float accuracy envelope until these measurements are
complete.

## Scalar policy gate

Required public instantiations:

~~~text
float
double
real
~~~

Validate that implementation working precision is:

~~~text
float  -> double
double -> double
real   -> real
~~~

unless later evidence justifies a documented change.

For `real`, record:

~~~text
real.sizeof
real.mant_dig
real.epsilon
compiler
target architecture
~~~

Wider `real` must not be silently narrowed to double in the production kernel.

## Deterministic differential corpus

Use a committed deterministic generator.

The corpus must vary:

- ellipsoid;
- origin latitude;
- origin longitude;
- origin height;
- local source displacement;
- source height;
- antimeridian representation;
- pole proximity.

Include both:

~~~text
geodetic <-> topocentric
geocentric <-> topocentric
~~~

paths.

Initial target for `double`:

~~~text
>= 100000 forward cases per public path
>= 100000 reverse cases per public path
~~~

The exact corpus size may be revised based on measured execution cost, but
boundary/adversarial cases remain mandatory regardless of random corpus size.

Use a fixed documented PRNG and seed.

## Independent reverse corpus

Do not generate the entire reverse test set by calling the production forward
operation.

Obtain reverse inputs from:

- EPSG worked values;
- independently evaluated analytical rotations;
- PROJ;
- GeographicLib where applicable;
- directly generated ENU displacement vectors.

This prevents a self-consistent forward/reverse defect from passing unnoticed.

## Self-roundtrip regression

Maintain:

~~~text
geodetic
    -> geodesy-d topocentric
    -> geodesy-d geodetic

geocentric
    -> geodesy-d topocentric
    -> geodesy-d geocentric
~~~

but report these separately from independent accuracy evidence.

## Failure and overflow probes

Test:

- invalid `TopocentricFrame.init`;
- invalid `Ellipsoid.init`;
- exact geocentric origin `(0,0,0)`;
- largest practical finite coordinate magnitudes;
- arithmetic overflow where representable inputs produce non-finite derived
  values;
- invalid/non-finite `TopocentricCoordinate` construction.

Checked APIs must return `false` rather than assert or throw.

Throwing convenience APIs, if accepted, must throw `GeodesyValueException`.

## API/runtime contract

Compile the public surface only through:

~~~d
import geodesy;
~~~

Verify the accepted public API under DMD and LDC.

Required checked hot-path attributes, where accepted by implementation:

~~~text
pure
nothrow
@safe
@nogc
~~~

Negative compile tests should protect any package/private working-precision
helpers from accidental export.

Named public parameters are compatibility-sensitive under the project's
existing named-argument contract.

### TOPO-F achieved evidence

TOPO-F completed successfully on 2026-09-20.

The aggregate consumer surface now exports `TopocentricCoordinate!T` and
`TopocentricFrame!T` through:

~~~d
import geodesy;
~~~

The permanent positive API contract verifies:

- `TopocentricCoordinate` and `TopocentricFrame` for `float`, `double`, and
  `real`;
- checked coordinate construction;
- both geodetic-origin and geocentric-origin frame construction;
- frame validity and ellipsoid introspection;
- all four checked conversion directions inside
  `pure nothrow @safe @nogc`;
- all four throwing conversion directions inside `@safe`.

The permanent named-argument contract freezes the accepted topocentric
parameter names for coordinate construction, both frame constructors, and all
four checked and throwing conversion methods.

Topocentric rejection contracts are also exercised from the aggregate consumer
surface and continue to reject:

- direct coordinate-component mutation;
- the private unchecked coordinate factory;
- frame ellipsoid mutation;
- access to internal prepared frame state.

The existing package-boundary contract continues to reject the internal
EPSG 9602 working-precision helper.

The complete API contract passed under both DMD and LDC. The ordinary library
test suite also passed under both compilers with 20 modules, and the
documentation contract generated 22 Ddoc module files successfully.

No production numerical algorithm was changed as part of TOPO-F.

## Compiler/platform gate

At minimum:

- minimum supported D frontend 2.111.0;
- current DMD;
- current LDC.

Hosted platform validation must cover Linux, Windows, and macOS where the
project's existing numerical matrix supports them.

`real` width and precision must be recorded per platform.

If platform `real` is wider than double, the differential corpus must exercise
that wider arithmetic rather than silently validating only double behavior.

## Performance policy

No performance optimization is required before correctness acceptance.

After TOPO-A through the numerical/API gates pass, establish a reproducible
baseline only if a concrete consumer or profile shows the operation to be
performance relevant.

The prepared frame should naturally avoid recomputing invariant origin
trigonometry per point, but no further low-level optimization is accepted from
assumption alone.

## Acceptance decision

The capability is release-ready only when:

~~~text
TOPO-A PASS
AND TOPO-B PASS
AND TOPO-C PASS
AND TOPO-D PASS
AND TOPO-E PASS
AND TOPO-F PASS
AND TOPO-G PASS
~~~

At that point:

1. record achieved accuracy envelopes rather than planned ones;
2. update ADR-0009 from Proposed to Accepted;
3. update `docs/API.md`, `docs/REFERENCES.md`, and release-facing documentation;
4. add the new documents to the documentation contract;
5. only then treat the public topocentric surface as part of the pre-v1
   compatibility baseline.
