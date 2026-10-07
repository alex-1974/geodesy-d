/**
 * Public package API for dependency-light, pure-D geodetic mathematics.
 *
 * Import this module for geodesy-d's supported public API: strong geodetic
 * value types, coordinate conversions, map projections, surface paths, and
 * static reference-frame transformations.
 *
 * ---
 * import geodesy;
 * ---
 *
 * Public numerical APIs support float, double, and real. Numerically sensitive
 * float operations may use double working precision while preserving float at
 * the public boundary. Checked numerical paths avoid allocation where the
 * operation permits it. Prepared solvers, projections, and frames retain
 * reusable state for repeated work.
 *
 * Each numerical family documents its supported domain and precision policy.
 * The library has no global epsilon or broad fast-math mode.
 *
 * geodesy-d is a mathematical geodesy library, not a general CRS engine. It
 * does not provide authority lookup, WKT/PROJJSON parsing, grid management, or
 * automatic operation discovery. PROJ and GeographicLib serve as independent
 * validation references, not runtime dependencies.
 *
 * Performance:
 *     Performance is an explicit quality property after correctness and
 *     numerical robustness. Hot checked paths avoid hidden allocation where
 *     practical, and reusable numerical state is prepared once where the
 *     algorithm benefits from it. Performance claims are made only from
 *     reproducible release-mode benchmarks.
 *
 * Validation:
 *     Numerical acceptance combines normative EPSG/IOGP material, internal
 *     analytical/property/regression tests, compiler and platform coverage,
 *     and independent differential validation appropriate to each operation.
 *
 * See_Also:
 *     `GeodeticCoordinate`, `GeocentricCoordinate`, `TopocentricFrame`,
 *     `TransverseMercator`, `UtmProjection`, `PolarStereographic`, `UpsProjection`,
 *     `LambertConformalConic`, `LambertAzimuthalEqualArea`, `Geodesic`,
 *     `Rhumb`, `RhumbLine`
 *
 * Authors:
 *     Alexander Bernardi
 *
 * Copyright:
 *     Copyright © 2026 Alexander Bernardi
 *
 * License:
 *     MIT
 *
 * Date:
 *     October 6, 2026
 */
module geodesy;

public import geodesy.angle;
public import geodesy.ellipsoid;
public import geodesy.errors;
public import geodesy.geographic;
public import geodesy.geodesic;
public import geodesy.geodesic_polygon;
public import geodesy.geodetic;
public import geodesy.geocentric;
public import geodesy.topocentric;
public import geodesy.projected;
public import geodesy.rhumb;
public import geodesy.scalar;

public import geodesy.conversion;
public import geodesy.projection.factors;
public import geodesy.projection.lambert_azimuthal_equal_area;
public import geodesy.projection.lambert_conformal_conic;
public import geodesy.projection.pseudo_mercator;
public import geodesy.projection.polar_stereographic;
public import geodesy.projection.transverse_mercator;
public import geodesy.projection.utm;
public import geodesy.projection.ups;

public import geodesy.transform.geocentric_translation;

public import geodesy.transform.helmert;
