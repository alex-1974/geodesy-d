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

## XPS DMD and LDC execution (2026-10-10)

The user ran both documented external fixture compile commands from the repository root:

```sh
dmd -o- -Isource tools/research/fixtures/external_contract_opaque.d
ldc2 -o- -Isource tools/research/fixtures/external_contract_opaque.d
```

Both returned to the shell prompt without error output. This is evidence that **the same external consumer fixture compiled under both compilers**, checking twelve opaque DMD-JSON method/property return types, selected `@safe` and `pure nothrow @nogc` call contexts. The paste does not print compiler versions or an explicit exit-code capture; because both commands were issued sequentially without `set -e`, the absence of visible diagnostics is a successful-compilation indication rather than independently recorded zero exit codes. For final gate evidence, rerun with `set -euo pipefail`, versions, source SHA and explicit PASS markers.

This is *not* complete compiler verification of all function attributes, templates, overload resolution or nonfunction declarations. Feature/API freeze remains open.
