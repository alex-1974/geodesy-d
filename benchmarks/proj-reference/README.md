# geodesy-d PROJ reference benchmark

This optional benchmark project compares `geodesy-d` against the PROJ C API
in-process.

It is intentionally separate from the main library and does not make PROJ a
runtime dependency of `geodesy-d`.

## Requirements

A development installation of PROJ providing both `proj.h` and `libproj` is
required.

The initial reference environment uses PROJ 9.7.1.

## Numerical reference probe

The executable first compares the implementations over the same deterministic
8192-point sample set.

Covered operations:

- EPSG 9602 geodetic -> geocentric;
- EPSG 9602 geocentric -> geodetic;
- EPSG 1031 geocentric translation;
- EPSG 1033 Position Vector Helmert;
- EPSG 1032 Coordinate Frame Helmert.

The comparison uses explicit tolerances and fails at runtime if an operation
exceeds its reference envelope. These tolerances are validation envelopes for
the benchmark comparison, not general accuracy guarantees for `geodesy-d`.

Run with:

~~~sh
dub run --build=release --compiler=ldc2 --force
~~~

or:

~~~sh
dub run --build=release --compiler=dmd --force
~~~

PROJ operation construction, definition parsing and context creation are
outside any future timed kernel.
