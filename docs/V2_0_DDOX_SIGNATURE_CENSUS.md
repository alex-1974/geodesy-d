# v2.0: public DDox prototype census (first reproducible snapshot)

Status: **C1 evidence, not a complete compiler-level API census**  
Tracking: #113  
Pinned source baseline on `develop`: `6697759c3cc5b4f34a5a70bfd05658f5018cec93` (merge of #115).  
Input HTML was built on the earlier documentation PR head `79de38bea8073a27b65f553db75beac647c30e1f`.

## Measured inventory

The archived current-version DDox site has **463 distinct public symbol pages**
in **28 exported implementation modules**. Extracting each separately rendered
`.single-prototype` block yields **488 prototype records**. In other words,
the number of public symbol pages is *not* the number of represented
prototypes; several pages render multiple overloads. An additional
29 module overview pages and the site index are not callable-symbol pages.

The source inventory begins from `source/geodesy/package.d`, which
re-exports those 28 implementation modules via `public import`.

## Reproduce

From a checkout with DDox available, generate the current site:

```sh
bash tools/build-versioned-docs.sh
python3 tools/research/ddox_signature_census.py \
    build/versioned-docs/output/current/build/ddox/site \
    build/v2-public-ddox-prototypes.csv
```

The extraction script requires `python3-bs4` (Beautiful Soup 4). Record the
exact `git rev-parse HEAD`, DMD version and generated file checksum with
the results. The generated CSV contains `module`, `symbol`, `page`,
`overload`, `page_title`, and the **rendered declaration signature**.
Rows are deterministically ordered by HTML path and within-page prototype order.

## Important limits

1. This is an exhaustive list of **rendered DDox prototypes**, not proof
   that every publicly accessible declaration appears in DDox.
   The documentation builder explicitly filters to documented public
   declarations. Confirm undocumented and implicit public items separately.
2. DDox presentation may omit template constraints, inferred compiler
   details, inherited members, or visibility context; compile-time
   overload resolution requires additional D-language review.
3. A multiple-prototype page preserves each DDox-rendered overload;
   a single-prototype page can still represent a template with several
   valid instantiations, which is not enumerated exhaustively.
4. The source commit for the inspected archive precedes the #115 merge.
   Regenerate at the pinned `develop` commit and diff the CSV before
   treating it as the canonical v2 baseline.

## Required next C1 checks

- Compare every emitted record with the corresponding source declaration,
  template constraints, public visibility, attributes and aliases.
- Identify publicly accessible symbols without a rendered page (including
  indirect public imports, aliases and inherited members).
- Audit checked/throwing and prepared/one-shot symmetry and record
  semantic decisions, especially `.init`, units and failure states.
- Obtain a DMD/LDC external consumer pass for the standalone Helmert
  Getting Started program.
- Only then close the API census gate and authorize the **feature-freeze**
  checkpoint; do not create `freeze/feature-2.0.0` or `freeze/api-2.0.0`
  based on the DDox snapshot alone.


## Compiler-generated module snapshots (DMD)

An additional tool, `tools/research/dmd_api_json_snapshot.py`, enumerates the
`public import` statements from the root package, checks that all 28
implementation source modules exist, and invokes DMD's `-X` JSON generation
**for each module**. It also saves an exact Git commit, compiler version and
per-file SHA-256 digests in a manifest.

```sh
git rev-parse HEAD
python3 tools/research/dmd_api_json_snapshot.py --compiler dmd
dub test --compiler=dmd
dub test --compiler=ldc2
```

DMD officially supports `-X`/`-Xf=filename` for generated module JSON;
the source scanner uses `-o-` so it does not write object files. The
command must be executed on the XPS (or another environment with DMD and
the full repository), not inferred from DDox output. Validate the produced
JSON and manifest before constructing an authoritative visibility and
overload comparison. **LDC DUB tests provide cross-compiler consumer
qualification, not proof that DMD's JSON and LDC's public model are
identical.**

At this checkpoint the compiler-generated snapshot command is committed
but **has not been executed on an installed D toolchain by this review
environment**. Hence the exhaustive compiler-verification gate remains
OPEN. Do not present the 488 rendered DDox prototypes as compiler-certified
or advance C1 to a freeze checkpoint prematurely.
