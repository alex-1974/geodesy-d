# v2.0 C5 sign-off triage — feature-frozen release branch

Status: **C5 review in progress; no API-freeze authorization**.
Baseline feature tag: `freeze/feature-2.0.0` at
`01d2bbc1822d99ef711d5d78487597b76e650211`.
This review follows the incorporation of PRs #125, #126, #127 and #129 on
`release/2.0`.

## Accepted evidence (do not repeat research without a specific failure)

| Area | Source/evidence | Decision |
| --- | --- | --- |
| Root exports | `source/geodesy/package.d`, 28 exported modules | Keep explicit root entrypoint. |
| DDox | 463 symbol pages / 488 prototypes, documented-only | Useful for consumer documentation, **not** exhaustive public visibility. |
| Externally checked declarations | DMD/LDC consumer checks of selected overloads, templates, enum literals, defaults and aggregate types | Keep as regression evidence; coverage is deliberately bounded. |
| Compiler-level visibility | PR #119, research workflows 38049534795 / 38049534802 / 38049534687 | 329 module rows; 99 documented names, 29 implicit `object` imports, 200 nonpublic and 1 root self-name; zero unexplained module-level names. |
| Own declared aggregate members | PR #119, `__traits(derivedMembers)` on both DMD/LDC | 21 entries; identical compiler output, zero unresolved. Inherited runtime members deliberately excluded. |
| Package-root external consumer and six-compiler matrix | Run 38054313106 | Seven jobs passed on earlier `develop` freeze baseline. |
| Geodesic prolate, Dynamic Helmert, Molodensky-Badekas | Runs 38056746778, 38056748277, 38056749859 | Two compilers passed per workflow, on feature-freeze baseline. |
| Checked-result contracts | PRs #126, #127, #129 | Clarified documented `out` semantics and added two focused failure-path tests. No signature change. |

## C1 issue #118 resolution proposal

**What is resolved:** the unexplained *module-level* visibility set and the
owned declared aggregate-member census from PR #119. The implicit module
`object` imports and root self-name are classified rather than misreported
as novel geodesy-d API. No API defect was discovered by that census.

**What is not proven:** exhaustive reachable template instantiations, inherited
runtime/API contracts, every overload under every negative access context,
or the final release candidate. Such an exhaustive guarantee is substantially
broader than the accepted compiler census. Do not assert it in an API-freeze
record. Do not close issue #118 under its current exhaustive acceptance
criteria without either explicitly narrowing its acceptance or satisfying it.
Pragmatic way forward: amend #118 acceptance to a finite, consumer-driven
release gate based on (a) zero unexplained declared module/aggregate names,
(b) root-import consumer compilation with DMD/LDC, and (c) no known
reproducible unintended public exposure. Keep genuine defects as separate
issues if they arise.

## No API-breaking change justified by current findings

Reviewed families include geographic/geodetic/ECEF, angle strong types,
checked/throwing conversion, UTM prepared/automatic, geodesic/rhumb,
static/dynamic Helmert and LCC. The examined differences reflect intentional
consumer semantics, not evidenced signature defects. The checked `out`
documentation fixes do not require an API rename.

## Remaining release decisions (bounded)

1. Formally decide #118's scope and record the acceptance rationale. The
   acceptance criteria currently demand exhaustive visibility beyond the
   proven declared surface.
2. Conduct a short external root-import consumer smoke on the **exact API
   freeze candidate** with DMD and LDC, including invalid `.init`/failed
   `try*` for the newly clarified core/UTM cases.
3. Produce the v1.x to v2.0 API/migration distinction in `docs/API.md` and
   release notes. Preserve the historical v1 contract.
4. Verify every required release CI/oracle/platform gate on the **exact
   release candidate** after stabilization; historic PASS is not RC PASS.

No v2 API freeze tag or release sign-off is created by this checkpoint.
