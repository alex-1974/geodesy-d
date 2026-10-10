# C1 external consumer probes for opaque DMD function types

The DMD `-X` JSON snapshot omitted readable function type strings
for twelve methods in `GeodesicIntersectionEnumeration` and `UtmZone`.
An empty JSON type is **not evidence of inaccessibility or API failure**.

Fixture `tools/research/fixtures/external_contract_opaque.d`
imports the public `geodesy` root package from an external module
and tests all twelve method/property return types using
`typeof` and typed consumer expressions. It additionally compiles
read-only and checked-factory consumers under
`@safe pure nothrow @nogc`, and compiles the throwing `fromNumber`
factory in an `@safe` consumer.

Run from repository root:

```sh
dmd  -o- -Isource tools/research/fixtures/external_contract_opaque.d
ldc2 -o- -Isource tools/research/fixtures/external_contract_opaque.d
```

**Not yet run on XPS.** These probes are intentionally narrower
than full signature proof: they establish observed return types and
selected call-site attributes for concrete expressions. They do not
establish complete overload sets, template constraints, all possible
argument conversions, `@property` annotations, parameter name
spelling, or default arguments. Execute under both toolchains,
record compiler versions and source SHA, then update the results.

See `docs/V2_0_OVERLOAD_PAIRING.md` for the separate 35-overload
parameter-key matching exercise. Neither gate alone authorizes
feature or API freeze.
