# geodesy-d v1.0.1 documentation quality audit

Status: **OPEN — RELEASE BLOCKER**

This audit applies the repository documentation standard in
`docs/ddoc-style.md` to the v1 source tree.

It is separate from numerical validation. Passing unit tests or generating
DDox HTML does not make the documentation complete.

## Q1 — reader-first writing standard

Decision:

- documentation is written for the consumer or maintainer who reads it;
- public prose follows clarity, simplicity, brevity, and humanity;
- public Ddoc describes observable behavior before implementation details;
- repository-history terms and validation-gate jargon stay out of ordinary
  consumer documentation unless they are part of the public contract.

Status: **standard defined; source review pending**.

## Q2 — public Ddoc coverage

Requirement:

Every public symbol reachable through `import geodesy;` must be understandable
from its generated DDox page without reading implementation source.

The page must document, where applicable:

- meaning;
- inputs and their domain;
- result;
- units;
- failure;
- default state;
- boundaries and singularities;
- numerical limits.

Status: **audit required against generated DDox**.

## Q3 — executable public examples

Requirement:

Every public API declaration must have a documented, compiler-checked
`unittest` that renders as an Example on its DDox page.

Current inventory from `docs/public-api-example-audit.md`:

~~~text
public DDox symbol pages: 211
own rendered/compiled example classification: 24
family-covered classification: 187
remaining "add" classification: 0
~~~

The previous policy treated family coverage as complete. That no longer meets
the v1.0.1 documentation standard.

Status: **FAIL — 187 public pages still require their own rendered example
under the new policy**.

Before enabling the hard gate, each row in
`docs/public-api-example-audit.md` must move to `existing`, and the generated
DDox page must contain the Example.

## Q4 — internal function documentation

Requirement:

Every non-trivial private/package function must explain enough for a maintainer
to understand:

- what it computes;
- input meaning and expected domain;
- output meaning;
- `ref`/`out` mutation;
- preconditions/invariants;
- important numerical assumptions;
- failure semantics where relevant.

Tiny self-evident helpers may be exempt, but the exception must be obvious in
review rather than inferred from missing documentation.

Status: **manual/source-assisted audit required**.

The current source contains many good internal algorithm comments, especially
in the geodesic, geocentric inverse, Transverse Mercator, and topocentric
kernels. Their presence does not establish complete function-level coverage.

## Q5 — decision comments

Requirement:

Important implementation decisions must preserve their rationale next to the
code or point to a nearby ADR.

Review at least:

- precision promotion;
- numerical stabilization;
- tolerance selection;
- special handling of poles, antimeridians, canonical zero, and singularities;
- compiler/Phobos compatibility workarounds;
- performance trade-offs;
- non-obvious branch ordering;
- deliberately rejected simpler formulas.

Comments that merely restate code do not satisfy this gate.

Status: **manual audit required**.

## Q6 — generated documentation review

Requirement:

Generate the actual DDox site and inspect it as a consumer would.

Verify:

- examples render under the intended symbol;
- summaries are useful;
- long descriptions remain readable;
- parameter/return/throw sections are not repetitive;
- links and related symbols work;
- internal modules do not leak into the public site.

Status: **pending after Q2–Q5 remediation**.

## Q7 — release gate

v1.0.1 may not be tagged until:

- [ ] Q1 prose review is complete;
- [ ] Q2 every public API page is semantically complete;
- [ ] Q3 all public API pages render compiler-checked examples;
- [ ] Q4 non-trivial internal functions are documented;
- [ ] Q5 important implementation decisions retain rationale comments;
- [ ] Q6 generated DDox has been reviewed;
- [ ] DMD documentation generation passes;
- [ ] DDox example verifier passes under the strict policy;
- [ ] API documentation workflow is green on the final release candidate.

The final gate is about reader understanding, not comment count.
