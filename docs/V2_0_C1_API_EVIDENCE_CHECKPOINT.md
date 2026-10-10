# v2.0 C1 public API: compiler evidence checkpoint

Tracking: [Issue #113](https://github.com/alex-1974/geodesy-d/issues/113).
This checkpoint records **research qualification of DDox-rendered declarations**;
it is **not** a feature freeze, API freeze, or v2.0 release sign-off.

## Reproducible evidence

The research CI `.github/workflows/v2-api-research.yml` rebuilds
the DDox site and DMD JSON from one clean Git checkout, runs the
Python research regressions, creates typed external D consumers,
compiles them with both DMD and LDC, and records checksums and
source/compiler metadata in `build/v2-evidence-manifest.json`.

Latest individually confirmed green actions runs:

- [38042311465](https://github.com/alex-1974/geodesy-d/actions/runs/38042311465):
  **81** external concrete intersection call compilations (27 overloads
  × float/double/real), DMD/LDC; Python tests and DMD JSON gate.
- [38042415694](https://github.com/alex-1974/geodesy-d/actions/runs/38042415694):
  **63** nonfunction declarations exercised by generated external
  DMD/LDC consumers, including 45 aggregate templates and six aliases.
- [38042534371](https://github.com/alex-1974/geodesy-d/actions/runs/38042534371):
  the 425-function selected defaults and method qualifier audit.
- [38042784304](https://github.com/alex-1974/geodesy-d/actions/runs/38042784304):
  DMD/LDC compilation and independent literal assertions of seven
  enum families with 21 members; clean same-source SHA/provenance gate.

## DDox-rendered API coverage

| Evidence dimension | Observed result | Qualification |
| --- | --- | --- |
| Root exports | 28 implementation modules | Source + DDox |
| DDox public symbol pages | 463 | Rendered, documented only |
| DDox prototype rows | 488 | Complete DDox HTML extraction |
| DMD raw candidate rows | 1,914 | Includes generated, nested, private; **not** public count |
| Function prototype rows | 425 | All classified |
| Initial selected singleton return/attribute matching | 378 | Textual partial contract |
| Overloaded function prototypes | 35 | Unique pairing, selected return and attrs |
| Opaque DMD-type functions | 12 | Separate external DMD/LDC consumers |
| Default argument comparisons | 425/425 | DMD JSON vs DDox |
| Receiver `const` comparisons | 413/413 | Remaining 12 lack a readable DMD type |
| DMD-wrapper constraint text matches | 58 | Same-line wrapper + DDox text only |
| Free intersection calls | 81 | Concrete DMD/LDC compile-only paths |
| Nonfunction DDox rows | 63 | Structural compile-only checks |
| Enum member values | 21 across seven enums | Independent expected literals checked by DMD/LDC |

## Boundaries and remaining release blockers

**Do not equate this DDox inventory with exhaustive public exposure.**
DDox is generated with `--only-documented`. The earlier 198
non-DDox-name lookups were negative or nonexpression results, not
proof that every declaration is inaccessible, especially for
uninstantiated templates. The root-import and inherited/implicit
public surface still needs a semantic accessibility census.

**Contract breadth is narrower than numerical qualification.**
Positive compilation checks show a caller can name and compile the
API, not that invalid runtime `.init` objects produce valid results.
The C5 design audit still requires explicit decisions on units,
angular canonicalization, result validity, checked/throwing symmetry,
prepared state ownership, naming and failure channels.

**Remaining compiler details:** verify every advertised compile-time
attribute (including receiver qualifiers for the twelve opaque JSON
cases) and nested/member/template constraints through appropriate
negative and positive consumers. Audit defaults under LDC directly,
rather than relying only on DMD `-X` representation.

**Numerics and release:** C4 performance/codegen measurements,
platform-specific boundary cases and external reference oracles,
six-version/compiler and cross-platform matrix, independent DUB
consumer, migration notes and release-candidate packaging remain
separate explicit gates in `docs/V2_0_CONSOLIDATION_PLAN.md`.
No checkpoint or `release/2.0` branch is authorized by this
research alone.

The research toolset is suitable for integration as an incremental
qualification gate. Closing #113, setting a freeze tag or releasing
v2.0.0 is **not** justified by these results.
