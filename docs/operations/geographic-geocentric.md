# Geographic/geocentric conversion — EPSG method 9602

## Status

Forward direction implemented. Reverse direction pending.

## Scope

This operation converts a 3D geodetic coordinate

```text
(latitude, longitude, ellipsoidal height)
```

to geocentric Cartesian coordinates

```text
(X, Y, Z)
```

on the **same ellipsoid/reference frame**.

It is a coordinate conversion, not a datum transformation.

## Reference

Primary method: **EPSG coordinate operation method 9602 — Geographic/geocentric conversions**, as defined by IOGP Report 373-07-2 / EPSG Guidance Note 7-2.

Current IOGP publication metadata at implementation time identifies Report 373-07-2 as version 74, July 2026. The initial deterministic worked-example test is the WGS 84 North Sea example also present in the publicly accessible December 2024 edition. Before a stable release, the implementation and vector should be rechecked against the exact current publication revision.

## Forward equations

For geodetic latitude `phi`, longitude `lambda`, ellipsoidal height `h`, semi-major axis `a`, and first eccentricity squared `e²`:

```text
nu = a / sqrt(1 - e² sin²(phi))

X = (nu + h) cos(phi) cos(lambda)
Y = (nu + h) cos(phi) sin(lambda)
Z = ((1 - e²) nu + h) sin(phi)
```

with:

```text
e² = 2f - f²
```

where `f` is ellipsoid flattening.

## Axis and prime-meridian semantics

The geocentric system is right-handed:

- `Z` is positive along the Earth's rotation axis toward the north pole;
- `X` passes through the equator and the prime meridian defining the geocentric frame;
- `Y` passes through the equator at +90° longitude from that meridian.

Conventional EPSG geocentric systems use the Greenwich meridian. `geodesy-d` does not carry CRS or prime-meridian metadata, so callers are responsible for supplying longitude in the convention required by the intended geocentric frame.

## Units

`geodesy-d` does not encode a linear unit in the scalar type.

For this operation:

```text
ellipsoid semi-major axis
ellipsoidal height
output X/Y/Z
```

must all use the same linear unit. EPSG geocentric coordinates conventionally use metres.

## API

```d
bool tryGeodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid,
    out GeocentricCoordinate!T result)
    pure nothrow @safe @nogc;

GeocentricCoordinate!T geodeticToGeocentric(T)(
    const GeodeticCoordinate!T source,
    const Ellipsoid!T ellipsoid);
```

The `try...` form reports scalar overflow/non-finite output without throwing. The convenience form throws `GeodesyValueException` in that case.

## Initial validation

The initial test set contains:

1. the EPSG/IOGP WGS 84 North Sea worked example;
2. an equator/prime-meridian axis case;
3. a north-pole case;
4. instantiation checks for `float`, `double`, and `real`;
5. an explicit overflow case for the checked API.

The published WGS 84 reference vector is:

```text
latitude            53°48'33.820" N
longitude            2°07'46.380" E
ellipsoidal height  73.0 m

X = 3 771 793.968 m
Y =   140 253.342 m
Z = 5 124 304.349 m
```

`double` is the normative scalar for the reference-vector tolerance. Broader randomized differential testing against PROJ is still pending.
