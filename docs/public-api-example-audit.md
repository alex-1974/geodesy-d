# Public API Example Audit

**Status:** complete  
**Baseline:** post-v1 development branch `audit/v1-public-api`

## Purpose

This audit tracks executable Ddoc example coverage for the public `geodesy-d` API.

Each public DDox symbol page should be classified as one of:

- **existing** — a documented `unittest` renders as an `Example`;
- **add** — the declaration should receive its own executable example;
- **family** — a dedicated example would add little value and the declaration is deliberately covered by a named type or API-family example.

Examples should normally compile through:

```d
import geodesy;
```

The goal is systematic user-facing coverage without mechanically duplicating examples for trivial accessors, enum values, aliases, or tightly related checked/throwing peers.

## Audit families

The public surface is organized into these documentation families:

| Family | Representative public surface | Initial state |
| --- | --- | --- |
| scalar policy | `isGeodesyScalar`, finite-scalar policy | audit required |
| angles | `Angle`, `Latitude`, `Longitude` | audit required |
| ellipsoid | `Ellipsoid`, `wgs84` | audit required |
| geographic/geodetic values | `GeographicCoordinate`, `GeodeticCoordinate` | audit required |
| Cartesian values | `GeocentricCoordinate`, `ProjectedCoordinate`, `TopocentricCoordinate` | audit required |
| conversion | geographic/geocentric checked and throwing operations | audit required |
| geocentric translation | EPSG 1031 family | audit required |
| Helmert | EPSG 1032 / 1033 families | audit required |
| Transverse Mercator | prepared projection, forward/reverse, factors | audit required |
| Pseudo-Mercator | prepared projection and bounded policy | audit required |
| UTM | zones, hemispheres, prepared/automatic/tagged operations | audit required |
| geodesics | prepared solver, direct/inverse results and operations | audit required |
| topocentric | prepared ENU frame and conversions | audit required |
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
- explicit versus automatic UTM policy;
- prepared-operation reuse;
- frame/convention explicitness;
- singular cases where instructional value is high.

Regression and differential-validation tests remain ordinary unittests rather than documentation examples.

## Completion criteria

The audit is complete when:

1. every public DDox symbol page is classified;
2. no declaration remains classified as **add**;
3. every **existing** declaration renders an `Example`;
4. every **family** declaration names the owning example family;
5. examples compile through the public package surface where practical;
6. every **existing** example is implemented as a documented `unittest`, so the same example is compiler-checked and rendered by DDox;
7. legacy inline `Example:` code blocks are rejected in public source modules;
8. a verifier checks the source example count and inventory against generated DDox output;
9. the documentation build fails when a public page appears without classification, an expected example disappears, or rendered and compiled example coverage diverge.


## Per-symbol classification

| DDox page | Status | Owning family |
| --- | --- | --- |
| `geodesy.angle.Angle.degrees` | family | angles |
| `geodesy.angle.Angle.fromDegrees` | family | angles |
| `geodesy.angle.Angle.fromRadians` | family | angles |
| `geodesy.angle.Angle` | existing | angles |
| `geodesy.angle.Angle.radians` | family | angles |
| `geodesy.angle.Angle.tryFromDegrees` | family | angles |
| `geodesy.angle.Angle.tryFromRadians` | family | angles |
| `geodesy.angle.Latitude.asAngle` | family | angles |
| `geodesy.angle.Latitude.degrees` | family | angles |
| `geodesy.angle.Latitude.fromDegrees` | family | angles |
| `geodesy.angle.Latitude.fromRadians` | family | angles |
| `geodesy.angle.Latitude` | existing | angles |
| `geodesy.angle.Latitude.radians` | family | angles |
| `geodesy.angle.Latitude.tryFromDegrees` | family | angles |
| `geodesy.angle.Latitude.tryFromRadians` | family | angles |
| `geodesy.angle.Longitude.asAngle` | family | angles |
| `geodesy.angle.Longitude.degrees` | family | angles |
| `geodesy.angle.Longitude.fromDegrees` | family | angles |
| `geodesy.angle.Longitude.fromRadians` | family | angles |
| `geodesy.angle.Longitude` | existing | angles |
| `geodesy.angle.Longitude.normalized` | family | angles |
| `geodesy.angle.Longitude.radians` | family | angles |
| `geodesy.angle.Longitude.tryFromDegrees` | family | angles |
| `geodesy.angle.Longitude.tryFromRadians` | family | angles |
| `geodesy.conversion.geocentricToGeodetic` | family | conversion |
| `geodesy.conversion.geodeticToGeocentric` | family | conversion |
| `geodesy.conversion.tryGeocentricToGeodetic` | existing | conversion |
| `geodesy.conversion.tryGeodeticToGeocentric` | existing | conversion |
| `geodesy.ellipsoid.Ellipsoid.firstEccentricitySquared` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.flattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromAxes` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.fromInverseFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid` | existing | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.inverseFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.isValid` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.secondEccentricitySquared` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.semiMajorAxis` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.semiMinorAxis` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.sphere` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.thirdFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromAxes` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.tryFromInverseFlattening` | family | ellipsoid |
| `geodesy.ellipsoid.Ellipsoid.trySphere` | family | ellipsoid |
| `geodesy.ellipsoid.wgs84` | family | ellipsoid |
| `geodesy.errors.GeodesyValueException` | family | errors |
| `geodesy.errors.GeodesyValueException.this` | family | errors |
| `geodesy.geocentric.GeocentricCoordinate.fromComponents` | family | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate` | existing | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.tryFromComponents` | family | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.x` | family | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.y` | family | Cartesian values |
| `geodesy.geocentric.GeocentricCoordinate.z` | family | Cartesian values |
| `geodesy.geodesic.Geodesic.direct` | family | geodesics |
| `geodesy.geodesic.Geodesic.ellipsoid` | family | geodesics |
| `geodesy.geodesic.Geodesic.fromEllipsoid` | family | geodesics |
| `geodesy.geodesic.Geodesic` | existing | geodesics |
| `geodesy.geodesic.Geodesic.inverse` | family | geodesics |
| `geodesy.geodesic.Geodesic.isSphere` | family | geodesics |
| `geodesy.geodesic.Geodesic.isValid` | family | geodesics |
| `geodesy.geodesic.Geodesic.tryDirect` | existing | geodesics |
| `geodesy.geodesic.Geodesic.tryFromEllipsoid` | family | geodesics |
| `geodesy.geodesic.Geodesic.tryInverse` | existing | geodesics |
| `geodesy.geodesic.GeodesicDirectResult` | family | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.distance` | family | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.finalAzimuth` | family | geodesics |
| `geodesy.geodesic.GeodesicInverseResult` | family | geodesics |
| `geodesy.geodesic.GeodesicInverseResult.initialAzimuth` | family | geodesics |
| `geodesy.geodetic.GeodeticCoordinate.ellipsoidalHeight` | family | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.fromComponents` | family | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate` | existing | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.latitude` | family | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.longitude` | family | geographic/geodetic values |
| `geodesy.geodetic.GeodeticCoordinate.tryFromComponents` | family | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.fromComponents` | family | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate` | existing | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.latitude` | family | geographic/geodetic values |
| `geodesy.geographic.GeographicCoordinate.longitude` | family | geographic/geodetic values |
| `geodesy.projected.ProjectedCoordinate.easting` | family | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.fromComponents` | family | Cartesian values |
| `geodesy.projected.ProjectedCoordinate` | existing | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.northing` | family | Cartesian values |
| `geodesy.projected.ProjectedCoordinate.tryFromComponents` | family | Cartesian values |
| `geodesy.projection.factors.ConformalProjectionFactors` | family | Transverse Mercator |
| `geodesy.projection.factors.ConformalProjectionFactors.meridianConvergence` | family | Transverse Mercator |
| `geodesy.projection.factors.ConformalProjectionFactors.pointScale` | family | Transverse Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.ellipsoid` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.falseEasting` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.falseNorthing` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.forward` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.fromParameters` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator` | existing | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.isValid` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.longitudeOfNaturalOrigin` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.reverse` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryForward` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryFromParameters` | family | Pseudo-Mercator |
| `geodesy.projection.pseudo_mercator.PseudoMercator.tryReverse` | family | Pseudo-Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.ellipsoid` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.falseEasting` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.falseNorthing` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.forward` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.forwardFactors` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.fromParameters` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator` | existing | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.isValid` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.latitudeOfNaturalOrigin` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.longitudeOfNaturalOrigin` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.reverse` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.reverseFactors` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.scaleFactorAtNaturalOrigin` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryForward` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryForwardFactors` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryFromParameters` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryReverse` | family | Transverse Mercator |
| `geodesy.projection.transverse_mercator.TransverseMercator.tryReverseFactors` | family | Transverse Mercator |
| `geodesy.projection.utm.UtmCoordinate.easting` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.fromComponents` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.hemisphere` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate` | existing | UTM |
| `geodesy.projection.utm.UtmCoordinate.isValid` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.northing` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.projected` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.tryFromComponents` | family | UTM |
| `geodesy.projection.utm.UtmCoordinate.zone` | family | UTM |
| `geodesy.projection.utm.UtmHemisphere` | family | UTM |
| `geodesy.projection.utm.UtmProjection.ellipsoid` | family | UTM |
| `geodesy.projection.utm.UtmProjection.falseEasting` | family | UTM |
| `geodesy.projection.utm.UtmProjection.falseNorthing` | family | UTM |
| `geodesy.projection.utm.UtmProjection.forward` | family | UTM |
| `geodesy.projection.utm.UtmProjection.forwardFactors` | family | UTM |
| `geodesy.projection.utm.UtmProjection.fromZone` | family | UTM |
| `geodesy.projection.utm.UtmProjection.hemisphere` | family | UTM |
| `geodesy.projection.utm.UtmProjection` | existing | UTM |
| `geodesy.projection.utm.UtmProjection.isValid` | family | UTM |
| `geodesy.projection.utm.UtmProjection.latitudeOfNaturalOrigin` | family | UTM |
| `geodesy.projection.utm.UtmProjection.longitudeOfNaturalOrigin` | family | UTM |
| `geodesy.projection.utm.UtmProjection.reverse` | family | UTM |
| `geodesy.projection.utm.UtmProjection.reverseFactors` | family | UTM |
| `geodesy.projection.utm.UtmProjection.scaleFactorAtNaturalOrigin` | family | UTM |
| `geodesy.projection.utm.UtmProjection.tryForward` | family | UTM |
| `geodesy.projection.utm.UtmProjection.tryForwardFactors` | family | UTM |
| `geodesy.projection.utm.UtmProjection.tryFromZone` | family | UTM |
| `geodesy.projection.utm.UtmProjection.tryReverse` | family | UTM |
| `geodesy.projection.utm.UtmProjection.tryReverseFactors` | family | UTM |
| `geodesy.projection.utm.UtmProjection.zone` | family | UTM |
| `geodesy.projection.utm.UtmZone.centralMeridianDegrees` | family | UTM |
| `geodesy.projection.utm.UtmZone.fromNumber` | family | UTM |
| `geodesy.projection.utm.UtmZone` | existing | UTM |
| `geodesy.projection.utm.UtmZone.isValid` | family | UTM |
| `geodesy.projection.utm.UtmZone.number` | family | UTM |
| `geodesy.projection.utm.UtmZone.tryFromNumber` | family | UTM |
| `geodesy.projection.utm.forwardUtm` | family | UTM |
| `geodesy.projection.utm.reverseUtm` | family | UTM |
| `geodesy.projection.utm.tryForwardUtm` | existing | UTM |
| `geodesy.projection.utm.tryReverseUtm` | family | UTM |
| `geodesy.projection.utm.tryStandardUtmZone` | existing | UTM |
| `geodesy.scalar.isGeodesyScalar` | family | scalar policy |
| `geodesy.topocentric.TopocentricCoordinate.east` | family | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.fromComponents` | family | topocentric |
| `geodesy.topocentric.TopocentricCoordinate` | existing | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.north` | family | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.tryFromComponents` | family | topocentric |
| `geodesy.topocentric.TopocentricCoordinate.up` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.ellipsoid` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.fromGeocentricOrigin` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.fromGeodeticOrigin` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.geocentricToTopocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.geodeticToTopocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame` | existing | topocentric |
| `geodesy.topocentric.TopocentricFrame.isValid` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.topocentricToGeocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.topocentricToGeodetic` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryFromGeocentricOrigin` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryFromGeodeticOrigin` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryGeocentricToTopocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryGeodeticToTopocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryTopocentricToGeocentric` | family | topocentric |
| `geodesy.topocentric.TopocentricFrame.tryTopocentricToGeodetic` | family | topocentric |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaX` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaY` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.deltaZ` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.fromComponents` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation` | existing | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.inverse` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.GeocentricTranslation.tryFromComponents` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.applyGeocentricTranslation` | family | geocentric translation |
| `geodesy.transform.geocentric_translation.tryApplyGeocentricTranslation` | family | geocentric translation |
| `geodesy.transform.helmert.CoordinateFrameHelmert` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.fromArcSecondsAndPpm` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.fromCanonical` | family | Helmert |
| `geodesy.transform.helmert.Helmert7` | existing | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationX` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationY` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.rotationZ` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.scaleDifference` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.scaleFactor` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.translationX` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.translationY` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.translationZ` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.tryFromArcSecondsAndPpm` | family | Helmert |
| `geodesy.transform.helmert.Helmert7.tryFromCanonical` | family | Helmert |
| `geodesy.transform.helmert.HelmertConvention` | family | Helmert |
| `geodesy.transform.helmert.PositionVectorHelmert` | family | Helmert |
| `geodesy.transform.helmert.applyCoordinateFrameHelmert` | family | Helmert |
| `geodesy.transform.helmert.applyPositionVectorHelmert` | family | Helmert |
| `geodesy.transform.helmert.toCoordinateFrame` | family | Helmert |
| `geodesy.transform.helmert.toPositionVector` | family | Helmert |
| `geodesy.transform.helmert.tryApplyCoordinateFrameHelmert` | family | Helmert |
| `geodesy.transform.helmert.tryApplyPositionVectorHelmert` | family | Helmert |
