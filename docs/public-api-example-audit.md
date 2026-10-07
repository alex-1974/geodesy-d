# Public API Example Audit

**Status:** strict per-symbol coverage  
**Baseline:** v1.2 API-freeze contract (`freeze/api-1.2.0`)

## Purpose

This audit tracks executable Ddoc example coverage for the public `geodesy-d` API.

Every public DDox symbol page is classified as **existing** only when a
documented, compiler-checked `unittest` renders as an `Example` on that exact
page.

The older `family` classification is no longer accepted. Even small public
properties and convenience peers have their own concise example so generated
documentation never requires the reader to hunt for another symbol's example.

Examples should normally compile through:

```d
import geodesy;
```

The goal is systematic user-facing coverage without mechanically duplicating examples for trivial accessors, enum values, aliases, or tightly related checked/throwing peers.

## Audit families

The public surface is organized into these documentation families:

| Family | Representative public surface | Initial state |
| --- | --- | --- |
| scalar policy | `isGeodesyScalar`, finite-scalar policy | existing |
| angles | `Angle`, `Latitude`, `Longitude` | existing |
| ellipsoid | `Ellipsoid`, `wgs84` | existing |
| geographic/geodetic values | `GeographicCoordinate`, `GeodeticCoordinate` | existing |
| Cartesian values | `GeocentricCoordinate`, `ProjectedCoordinate`, `TopocentricCoordinate` | existing |
| conversion | geographic/geocentric checked and throwing operations | existing |
| geocentric translation | EPSG 1031 family | existing |
| Helmert | EPSG 1032 / 1033 families | existing |
| dynamic Helmert | `Epoch`, EPSG 1053 / 1056 families | existing |
| Molodensky-Badekas | EPSG 1034 / 1061 local-origin Helmert family | existing |
| Transverse Mercator | prepared projection, forward/reverse, factors | existing |
| Pseudo-Mercator | prepared projection and bounded policy | existing |
| UTM | zones, hemispheres, prepared/automatic/tagged operations | existing |
| Polar Stereographic | prepared north/south projection and conformal factors | existing |
| UPS | tagged coordinates, standard selection, prepared/automatic operations | existing |
| Lambert Conformal Conic | prepared EPSG 9802 2SP projection and factors | existing |
| Lambert Azimuthal Equal Area | prepared equal-area projection | existing |
| Rhumb navigation | `Rhumb`, results, and prepared `RhumbLine` | existing |
| geodesics | prepared solver, direct/inverse results and operations | existing |
| topocentric | prepared ENU frame and conversions | existing |
| errors | `GeodesyValueException` | usually family-covered |

## Coverage policy

Dedicated examples are expected for:

- primary public value types;
- primary prepared-operation types;
- non-trivial constructors/factories where usage is not obvious;
- principal numerical operations;
- operations whose checked failure semantics are important;
- domain-policy helpers such as automatic UTM selection.

Family coverage is normally appropriate for:

- trivial property accessors;
- enum members;
- direct field-style getters;
- throwing peers already demonstrated beside their checked operation;
- result accessors already demonstrated by the producing operation.

## Geodesy-specific example requirements

Examples should make important domain semantics visible:

- radians versus degrees;
- linear-unit consistency;
- invalid `.init` where applicable;
- checked versus throwing behaviour;
- geographic domain boundaries;
- explicit versus automatic UTM/UPS policy;
- rhumb versus geodesic path semantics;
- projection singularities and bounded-domain behavior;
- prepared-operation reuse;
- frame/convention explicitness;
- singular cases where instructional value is high.

Regression and differential-validation tests remain ordinary unittests rather than documentation examples.

## Completion criteria

The audit is complete when:

1. every public DDox symbol page is classified;
2. no declaration remains classified as **add**;
3. every declaration is classified **existing** and renders an `Example`;
4. no `family` or `add` classification remains;
5. examples compile through the public package surface where practical;
6. every **existing** example is implemented as a documented `unittest`, so the same example is compiler-checked and rendered by DDox;
7. legacy inline `Example:` code blocks are rejected in public source modules;
8. a verifier checks the source example count and inventory against generated DDox output;
9. the documentation build fails when a public page appears without classification, an expected example disappears, or rendered and compiled example coverage diverge.


## Per-symbol classification

| DDox page | Status | Owning family |
| --- | --- | --- |
| `geodesy.angle.Angle.degrees` | existing | angles |
| `geodesy.angle.Angle.fromDegrees` | existing | angles |
| `geodesy.angle.Angle.fromRadians` | existing | angles |
| `geodesy.angle.Angle` | existing | angles |
| `geodesy.angle.Angle.radians` | existing | angles |
| `geodesy.angle.Angle.tryFromDegrees` | existing | angles |
| `geodesy.angle.Angle.tryFromRadians` | existing | angles |
| `geodesy.angle.Latitude.asAngle` | existing | angles |
| `geodesy.angle.Latitude.degrees` | existing | angles |
| `geodesy.angle.Latitude.fromDegrees` | existing | angles |
| `geodesy.angle.Latitude.fromRadians` | existing | angles |
| `geodesy.angle.Latitude` | existing | angles |
| `geodesy.angle.Latitude.radians` | existing | angles |
| `geodesy.angle.Latitude.tryFromDegrees` | existing | angles |
| `geodesy.angle.Latitude.tryFromRadians` | existing | angles |
| `geodesy.angle.Longitude.asAngle` | existing | angles |
| `geodesy.angle.Longitude.degrees` | existing | angles |
| `geodesy.angle.Longitude.fromDegrees` | existing | angles |
| `geodesy.angle.Longitude.fromRadians` | existing | angles |
| `geodesy.angle.Longitude` | existing | angles |
| `geodesy.angle.Longitude.normalized` | existing | angles |
| `geodesy.angle.Longitude.radians` | existing | angles |
| `geodesy.angle.Longitude.tryFromDegrees` | existing | angles |
| `geodesy.angle.Longitude.tryFromRadians` | existing | angles |
| `geodesy.conversion.geocentricToGeodetic` | existing | conversion |
| `geodesy.conversion.geodeticToGeocentric` | existing | conversion |
| `geodesy.conversion.tryGeocentricToGeodetic` | existing | conversion |
| `geodesy.conversion.tryGeodeticToGeocentric` | existing | conversion |
| `geodesy.ellipsoid.Ellipsoid.firstEccentricitySquared` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.flattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromAxes` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromInverseFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.inverseFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.isValid` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.secondEccentricitySquared` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.semiMajorAxis` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.semiMinorAxis` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.sphere` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.thirdFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromAxes` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromInverseFlattening` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.trySphere` | existing | ellipsoid |
| `geodesy.ellipsoid.wgs84` | existing | ellipsoid |
| `geodesy.errors.GeodesyValueException` | existing | errors |
| `geodesy.errors.GeodesyValueException.this` | existing | errors |
| `geodesy.geocentric.GeocentricCoordinate.fromComponents` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.tryFromComponents` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.x` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.y` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.z` | existing | Cartesian values |
| `geodesy.geodesic.Geodesic.direct` | existing | geodesics |
| `geodesy.geodesic.Geodesic.ellipsoid` | existing | geodesics |
| `geodesy.geodesic.Geodesic.fromEllipsoid` | existing | geodesics |
| `geodesy.geodesic.Geodesic` | existing | geodesics |
| `geodesy.geodesic.Geodesic.inverse` | existing | geodesics |
| `geodesy.geodesic.Geodesic.isSphere` | existing | geodesics |
| `geodesy.geodesic.Geodesic.isValid` | existing | geodesics |
| `geodesy.geodesic.Geodesic.tryDirect` | existing | geodesics |
| `geodesy.geodesic.Geodesic.tryFromEllipsoid` | existing | geodesics |
| `geodesy.geodesic.Geodesic.tryInverse` | existing | geodesics |
| `geodesy.geodesic.GeodesicDirectResult` | existing | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.distance` | existing | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.finalAzimuth` | existing | geodesics |
| `geodesy.geodesic.GeodesicInverseResult` | existing | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.initialAzimuth` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.fromGeodesic` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.isValid` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.position` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.tryFromGeodesic` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.tryPosition` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.tryArcPosition` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.arcPosition` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.tryPositionUnrolled` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.positionUnrolled` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.tryArcPositionUnrolled` | existing | geodesics |
| `geodesy.geodesic.GeodesicLine.arcPositionUnrolled` | existing | geodesics |
| `geodesy.geodesic.GeodesicLineUnrolledResult` | existing | geodesics |
| `geodesy.geodesic.GeodesicLineUnrolledResult.latitude` | existing | geodesics |
| `geodesy.geodesic.GeodesicLineUnrolledResult.unrolledLongitude` | existing | geodesics |
| `geodesy.geodesic.GeodesicLineUnrolledResult.finalAzimuth` | existing | geodesics |
| `geodesy.geodesic.GeodesicQuantities` | existing | geodesics |
| `geodesy.geodesic.GeodesicQuantities.reducedLength` | existing | geodesics |
| `geodesy.geodesic.GeodesicQuantities.scale12` | existing | geodesics |
| `geodesy.geodesic.GeodesicQuantities.scale21` | existing | geodesics |
| `geodesy.geodesic.GeodesicQuantities.signedArea` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestKind` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.isValid` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.nearestPoint` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.nearestDistance` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.kind` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.supportingFoot` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.alongTrack` | existing | geodesics |
| `geodesy.geodesic_nearest.GeodesicSegmentNearestResult.signedCrossTrack` | existing | geodesics |
| `geodesy.geodesic_nearest.tryNearestPointOnSegment` | existing | geodesics |
| `geodesy.geodesic_nearest.nearestPointOnSegment` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionKind` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionResult` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionResult.isValid` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionResult.kind` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionResult.firstPoint` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicSegmentIntersectionResult.secondPoint` | existing | geodesics |
| `geodesy.geodesic_intersection.tryIntersectGeodesicSegments` | existing | geodesics |
| `geodesy.geodesic_intersection.intersectGeodesicSegments` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicIntersectionCoincidence` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.isValid` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.position` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.distanceOnFirst` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.distanceOnSecond` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.referenceDistance` | existing | geodesics |
| `geodesy.geodesic_intersection.GeodesicClosestIntersectionResult.coincidence` | existing | geodesics |
| `geodesy.geodesic_intersection.tryClosestGeodesicIntersection` | existing | geodesics |
| `geodesy.geodesic_intersection.closestGeodesicIntersection` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.addPoint` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.compute` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.fromGeodesic` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.isValid` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.pointCount` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.tryAddPoint` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.tryCompute` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonAccumulator.tryFromGeodesic` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonResult` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonResult.perimeter` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonResult.pointCount` | existing | geodesics |
| `geodesy.geodesic_polygon.GeodesicPolygonResult.signedArea` | existing | geodesics |
| `geodesy.geodetic.GeodeticCoordinate.ellipsoidalHeight` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.fromComponents` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.latitude` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.longitude` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.tryFromComponents` | existing | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.fromComponents` | existing | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate` | existing | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.latitude` | existing | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.longitude` | existing | geographic/geodetic values |
| `geodesy.projected.ProjectedCoordinate.easting` | existing | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.fromComponents` | existing | Cartesian values |
| `geodesy.projected.ProjectedCoordinate` | existing | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.northing` | existing | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.tryFromComponents` | existing | Cartesian values |
| `geodesy.projection.factors.ConformalProjectionFactors` | existing | Transverse Mercator |
| `geodesy.projection.factors.ConformalProjectionFactors.meridianConvergence` | existing | Transverse Mercator |
| `geodesy.projection.factors.ConformalProjectionFactors.pointScale` | existing | Transverse Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.ellipsoid` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.falseEasting` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.falseNorthing` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.forward` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.fromParameters` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.isValid` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.longitudeOfNaturalOrigin` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.reverse` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryForward` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryFromParameters` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryReverse` | existing | Pseudo-Mercator |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.isValid` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.tryFromParameters` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.fromParameters` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.ellipsoid` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.latitudeOfProjectionCentre` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.longitudeOfProjectionCentre` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.falseEasting` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.falseNorthing` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.tryForward` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.forward` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.tryReverse` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_azimuthal_equal_area.LambertAzimuthalEqualArea.reverse` | existing | Lambert Azimuthal Equal Area |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.isValid` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.tryFromTwoStandardParallels` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.fromTwoStandardParallels` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.ellipsoid` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.latitudeOfFalseOrigin` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.longitudeOfFalseOrigin` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.firstStandardParallel` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.secondStandardParallel` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.falseEasting` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.falseNorthing` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.tryForward` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.forward` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.tryReverse` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.reverse` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.tryForwardFactors` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.forwardFactors` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.tryReverseFactors` | existing | Lambert Conformal Conic |
| `geodesy.projection.lambert_conformal_conic.LambertConformalConic.reverseFactors` | existing | Lambert Conformal Conic |
| `geodesy.projection.polar_stereographic.PolarStereographic` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.ellipsoid` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.falseEasting` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.falseNorthing` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.forward` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.fromParameters` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.isValid` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.latitudeOfNaturalOrigin` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.longitudeOfNaturalOrigin` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.reverse` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.scaleFactorAtNaturalOrigin` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryForward` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryFromParameters` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryReverse` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.forwardFactors` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.fromStandardParallel` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.reverseFactors` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryForwardFactors` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryFromStandardParallel` | existing | Polar Stereographic |
| `geodesy.projection.polar_stereographic.PolarStereographic.tryReverseFactors` | existing | Polar Stereographic |
| `geodesy.projection.transverse_mercator.TransverseMercator.ellipsoid` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.falseEasting` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.falseNorthing` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.forward` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.forwardFactors` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.fromParameters` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.isValid` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.latitudeOfNaturalOrigin` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.longitudeOfNaturalOrigin` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.reverse` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.reverseFactors` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.scaleFactorAtNaturalOrigin` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryForward` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryForwardFactors` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryFromParameters` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryReverse` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryReverseFactors` | existing | Transverse Mercator |
| `geodesy.projection.utm.UtmCoordinate.easting` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.fromComponents` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.hemisphere` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.isValid` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.northing` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.projected` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.tryFromComponents` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.zone` | existing | UTM |
| `geodesy.projection.utm.UtmHemisphere` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.ellipsoid` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.falseEasting` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.falseNorthing` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.forward` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.forwardFactors` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.fromZone` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.hemisphere` | existing | UTM |
| `geodesy.projection.utm.UtmProjection` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.isValid` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.latitudeOfNaturalOrigin` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.longitudeOfNaturalOrigin` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.reverse` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.reverseFactors` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.scaleFactorAtNaturalOrigin` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.tryForward` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.tryForwardFactors` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.tryFromZone` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.tryReverse` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.tryReverseFactors` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.zone` | existing | UTM |
| `geodesy.projection.utm.UtmZone.centralMeridianDegrees` | existing | UTM |
| `geodesy.projection.utm.UtmZone.fromNumber` | existing | UTM |
| `geodesy.projection.utm.UtmZone` | existing | UTM |
| `geodesy.projection.utm.UtmZone.isValid` | existing | UTM |
| `geodesy.projection.utm.UtmZone.number` | existing | UTM |
| `geodesy.projection.utm.UtmZone.tryFromNumber` | existing | UTM |
| `geodesy.projection.ups.UpsCoordinate` | existing | UPS |
| `geodesy.projection.ups.UpsHemisphere` | existing | UPS |
| `geodesy.projection.ups.UpsProjection` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.easting` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.fromComponents` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.hemisphere` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.isValid` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.northing` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.projected` | existing | UPS |
| `geodesy.projection.ups.UpsCoordinate.tryFromComponents` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.ellipsoid` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.falseEasting` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.falseNorthing` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.forward` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.forwardFactors` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.fromHemisphere` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.hemisphere` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.isValid` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.latitudeOfNaturalOrigin` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.longitudeOfNaturalOrigin` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.reverse` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.reverseFactors` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.scaleFactorAtNaturalOrigin` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.tryForward` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.tryForwardFactors` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.tryFromHemisphere` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.tryReverse` | existing | UPS |
| `geodesy.projection.ups.UpsProjection.tryReverseFactors` | existing | UPS |
| `geodesy.projection.ups.forwardUps` | existing | UPS |
| `geodesy.projection.ups.reverseUps` | existing | UPS |
| `geodesy.projection.ups.tryForwardUps` | existing | UPS |
| `geodesy.projection.ups.tryReverseUps` | existing | UPS |
| `geodesy.projection.ups.tryStandardUpsHemisphere` | existing | UPS |
| `geodesy.projection.utm.forwardUtm` | existing | UTM |
| `geodesy.projection.utm.reverseUtm` | existing | UTM |
| `geodesy.projection.utm.tryForwardUtm` | existing | UTM |
| `geodesy.projection.utm.tryReverseUtm` | existing | UTM |
| `geodesy.projection.utm.tryStandardUtmZone` | existing | UTM |
| `geodesy.rhumb.Rhumb` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.ellipsoid` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.fromEllipsoid` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.isValid` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.inverse` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.line` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.tryDirect` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.tryFromEllipsoid` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.tryInverse` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.tryLine` | existing | Rhumb |
| `geodesy.rhumb.Rhumb.direct` | existing | Rhumb |
| `geodesy.rhumb.RhumbDirectResult` | existing | Rhumb |
| `geodesy.rhumb.RhumbDirectResult.position` | existing | Rhumb |
| `geodesy.rhumb.RhumbInverseResult` | existing | Rhumb |
| `geodesy.rhumb.RhumbInverseResult.bearing` | existing | Rhumb |
| `geodesy.rhumb.RhumbInverseResult.distance` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.bearing` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.fromRhumb` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.isValid` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.position` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.start` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.tryFromRhumb` | existing | Rhumb |
| `geodesy.rhumb.RhumbLine.tryPosition` | existing | Rhumb |
| `geodesy.scalar.isGeodesyScalar` | existing | scalar policy |
| `geodesy.topocentric.TopocentricCoordinate.east` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.fromComponents` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.north` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.tryFromComponents` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.up` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.ellipsoid` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.fromGeocentricOrigin` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.fromGeodeticOrigin` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.geocentricToTopocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.geodeticToTopocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.isValid` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.topocentricToGeocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.topocentricToGeodetic` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryFromGeocentricOrigin` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryFromGeodeticOrigin` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryGeocentricToTopocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryGeodeticToTopocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryTopocentricToGeocentric` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryTopocentricToGeodetic` | existing | topocentric |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaX` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaY` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaZ` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.fromComponents` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.inverse` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.tryFromComponents` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.applyGeocentricTranslation` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.tryApplyGeocentricTranslation` | existing | geocentric translation |
| `geodesy.transform.helmert.CoordinateFrameHelmert` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.fromArcSecondsAndPpm` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.fromCanonical` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationX` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationY` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationZ` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.scaleDifference` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.scaleFactor` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.translationX` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.translationY` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.translationZ` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.tryFromArcSecondsAndPpm` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.tryFromCanonical` | existing | Helmert |
| `geodesy.transform.helmert.HelmertConvention` | existing | Helmert |
| `geodesy.transform.helmert.PositionVectorHelmert` | existing | Helmert |
| `geodesy.transform.helmert.applyCoordinateFrameHelmert` | existing | Helmert |
| `geodesy.transform.helmert.applyPositionVectorHelmert` | existing | Helmert |
| `geodesy.transform.helmert.toCoordinateFrame` | existing | Helmert |
| `geodesy.transform.helmert.toPositionVector` | existing | Helmert |
| `geodesy.transform.helmert.tryApplyCoordinateFrameHelmert` | existing | Helmert |
| `geodesy.transform.helmert.tryApplyPositionVectorHelmert` | existing | Helmert |

| `geodesy.epoch.Epoch` | existing | dynamic Helmert |
| `geodesy.epoch.Epoch.decimalYear` | existing | dynamic Helmert |
| `geodesy.epoch.Epoch.fromDecimalYear` | existing | dynamic Helmert |
| `geodesy.epoch.Epoch.isValid` | existing | dynamic Helmert |
| `geodesy.epoch.Epoch.tryFromDecimalYear` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.CoordinateFrameHelmert14` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.apply` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.baseParameters` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.evaluate` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.fromArcSecondsAndPpm` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.fromCanonical` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.isValid` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.referenceEpoch` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.rotationRateX` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.rotationRateY` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.rotationRateZ` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.scaleDifferenceRate` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.translationRateX` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.translationRateY` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.translationRateZ` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.tryApply` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.tryEvaluate` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.tryFromArcSecondsAndPpm` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.Helmert14.tryFromCanonical` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.PositionVectorHelmert14` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.toCoordinateFrameHelmert14` | existing | dynamic Helmert |
| `geodesy.transform.dynamic_helmert.toPositionVectorHelmert14` | existing | dynamic Helmert |

| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.baseParameters` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.evaluationPointX` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.evaluationPointY` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.evaluationPointZ` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.equivalentHelmert` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.tryFromCanonical` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.fromCanonical` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.tryFromArcSecondsAndPpm` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.fromArcSecondsAndPpm` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.tryApply` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.MolodenskyBadekas10.apply` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.PositionVectorMolodenskyBadekas` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.CoordinateFrameMolodenskyBadekas` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.toCoordinateFrameMolodenskyBadekas` | existing | Molodensky-Badekas |
| `geodesy.transform.molodensky_badekas.toPositionVectorMolodenskyBadekas` | existing | Molodensky-Badekas |
