# geodesy-d v1.1.0 release notes

`geodesy-d` v1.1.0 completes the first additive post-v1 geodesic milestone
while preserving the frozen v1 source contract.

## Added

### Advanced geodesic quantities

`GeodesicQuantities!T` adds the principal differential and area quantities for
accepted direct/inverse geodesic operations:

~~~text
reducedLength  m12
scale12        M12
scale21        M21
signedArea     S12
~~~

The existing v1 direct/inverse result types and ordinary operations remain
unchanged. Advanced quantities are available through additive checked overloads.

### Prepared GeodesicLine

`GeodesicLine!T` prepares one oriented geodesic from a solver, start point, and
initial azimuth, then evaluates repeated distance positions without rebuilding
line-dependent state for every call.

The accepted repeated-position benchmark on the controlled XPS workload measured
approximately:

~~~text
repeated Geodesic.tryDirect        357.482910 ns/op
prepared GeodesicLine.tryPosition  182.426453 ns/op
speedup                             1.960x
~~~

The v1.1 line surface is deliberately distance-mode only.

### Ellipsoidal polygon measurement

`GeodesicPolygonAccumulator!T` and `GeodesicPolygonResult!T` provide
streaming geodesic perimeter and canonical signed ellipsoidal area.

The accumulator:

- stores only the first/current vertex and compensated sums;
- closes the polygon during `compute`;
- is antimeridian- and pole-safe;
- defines positive area for counterclockwise traversal;
- handles self-intersections algebraically;
- does not own polygon topology.

Ring validity, holes, containment, overlay, and geometry ownership remain in
`geo-d` or higher-level consumers.

## Validation

The v1.1 geodesic additions were validated with:

- independent GeographicLib 2.7 direct/inverse quantity comparison;
- independent GeographicLib 2.7 distance-mode GeodesicLine comparison;
- independent GeographicLib 2.7 PolygonArea comparison;
- durable antimeridian, pole, winding-reversal, and nearly-degenerate polygon
  regressions;
- DMD/LDC compiler validation;
- Linux, Windows, and macOS platform validation;
- platform-`real` coverage where wider than `double`;
- aggregate external-consumer API contracts.

## Compatibility

v1.1.0 is additive over the frozen v1 line.

There are no intended breaking changes to existing v1.0.x public names,
signatures, argument order, parameter names, scalar policy, unit policy, or
failure channels.

## Deliberately deferred

v1.1.0 does not attempt GeographicLib/PROJ feature parity.

Deferred or separately planned capabilities include:

- arc-mode `GeodesicLine` positions;
- longitude-unrolled line output;
- advanced line-position quantities;
- prolate ellipsoids;
- geodesic intersections;
- nearest/cross-track/along-track operations;
- rhumb lines;
- polygon topology.

See `docs/GEODESIC_FEATURE_MATRIX.md` and `ROADMAP.md` for admission
decisions and later milestones.
