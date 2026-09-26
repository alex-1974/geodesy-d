/**
 * Public package API for dependency-light, pure-D geodetic mathematics.
 *
 * geodesy-d provides strongly typed, bounded numerical operations for
 * reference ellipsoids, geographic/geocentric/topocentric coordinates,
 * map projections, surface geodesics, and static reference-frame
 * transformations. Import this module to access the supported public API:
 *
 * ---
 * import geodesy;
 * ---
 *
 * The library is designed for applications where explicit geodetic semantics,
 * numerical robustness, predictable hot-path behaviour, and independent
 * validation matter. Public scalar types support float, double, and real;
 * numerically sensitive float operations may use promoted double working
 * precision. Checked numerical paths are allocation-free where the operation
 * permits it, and prepared projection, geodesic, and topocentric objects cache
 * reusable state for repeated operations.
 *
 * Numerical algorithms have documented provenance and bounded support domains.
 * Substantial operations are qualified with analytical/reference cases,
 * deterministic adversarial/property tests, and independent implementations
 * such as PROJ or GeographicLib where appropriate. There is no library-wide
 * epsilon and no broad fast-math policy: numerical stability and explicit
 * semantics take precedence over raw benchmark speed.
 *
 * geodesy-d deliberately is not a general CRS engine. It does not provide an
 * authority database, WKT/PROJJSON parsing, grid-resource management,
 * automatic operation discovery, or general CRS pipelines, and PROJ and
 * GeographicLib are validation/reference systems rather than runtime
 * dependencies.
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
 *     `TransverseMercator`, `UtmProjection`, `Geodesic`
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
 *     September 26, 2026
 */
module geodesy;

public import geodesy.angle;
public import geodesy.ellipsoid;
public import geodesy.errors;
public import geodesy.geographic;
public import geodesy.geodesic;
public import geodesy.geodetic;
public import geodesy.geocentric;
public import geodesy.topocentric;
public import geodesy.projected;
public import geodesy.scalar;

public import geodesy.conversion;
public import geodesy.projection.factors;
public import geodesy.projection.pseudo_mercator;
public import geodesy.projection.transverse_mercator;
public import geodesy.projection.utm;

public import geodesy.transform.geocentric_translation;

public import geodesy.transform.helmert;
