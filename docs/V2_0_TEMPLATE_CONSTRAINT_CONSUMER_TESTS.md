# C1 scalar template constraint consumer qualification

The XPS constraint mapping found 27 function-template wrapper records
with `isGeodesyScalar!T` and eight methods in the constrained
`Geodesic!T` / `GeodesicLine!T` aggregates.

A new external consumer source file,
`tools/research/fixtures/external_template_constraints.d`,
compiles positive and negative scalar-policy assertions under DMD and
LDC. Accepted types: `float`, `double`, `real`. Rejected types:
`int`, `uint`, `string`, `const(double)` (where applicable).
It also attempts actual aggregate-template instantiation with
`__traits(compiles, Geodesic!T)` and
`__traits(compiles, GeodesicLine!T)`, testing accepted versus
rejected types from an external module.

**This file is not yet XPS-verified.** Run:

```sh
set -euo pipefail
git pull --ff-only
git rev-parse HEAD
dmd --version
ldc2 --version
dmd -o- -Isource tools/research/fixtures/external_template_constraints.d
echo 'PASS: DMD public scalar and aggregate constraints'
ldc2 -o- -Isource tools/research/fixtures/external_template_constraints.d
echo 'PASS: LDC public scalar and aggregate constraints'
```

The six overloaded free intersection function-template families
remain a separate test gate. A bare `function!double` can be rejected
because it is an unresolved overload set even if actual calls are
valid; negative lookup on such a bare name cannot prove the
`if (isGeodesyScalar!T)` constraint. Their positive and negative
tests must use **valid concrete argument lists** for the relevant
overloads, preferably generated from the 27 source declarations and
qualified under both compilers. Their return types and basic
attributes have been compared in a prior partial audit, but the
constraints have **not** been behaviorally qualified.

This test also does not validate the 63 nonfunction declaration
contracts, complete method qualifiers, all default arguments or full
overload resolution. C1 and both freeze gates remain open.
