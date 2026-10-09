# geodesy-d Documentation Style Guide

**Status:** Release standard  
**Scope:** Public Ddoc, internal code documentation, examples, and explanatory comments

## 1. Purpose

Documentation is part of the product.

A consumer should be able to use a public API without reading its implementation.
A maintainer should be able to change an internal algorithm without first
reverse-engineering why the current code is written that way.

The standard has four goals:

1. explain the public contract to the consumer;
2. show realistic use through compiler-checked DDox examples;
3. explain non-obvious internal functions and invariants to maintainers;
4. preserve the reasons behind important implementation decisions.

## 2. Writing standard

All documentation is written in English and follows the nonfiction principles
associated with William Zinsser's *On Writing Well*: **clarity, simplicity,
brevity, and humanity**.

For this repository that means:

- write for the reader, not for the implementation author;
- state the useful result before the mechanism;
- prefer short, concrete words and strong verbs;
- remove words that do not add meaning;
- prefer active constructions when they make responsibility clearer;
- use project jargon only when it is itself part of the public contract;
- explain one idea at a time;
- do not hide a simple rule behind abstract or ceremonial language;
- assume the reader does not know the repository's history;
- never assume the reader is unintelligent.

Good consumer documentation answers:

> What does this let me do, what do I pass in, what do I get back, and what can
> go wrong?

It should not begin with:

> How did the implementation team arrive here?

Historical reasoning belongs in ADRs, validation plans, git history, and
decision comments when that reasoning is necessary to maintain the code.

### 2.1 Preferred wording

Prefer:

~~~text
Returns the UTM coordinate for this geographic position.
~~~

over:

~~~text
Provides functionality for performing a UTM forward projection operation.
~~~

Prefer:

~~~text
Rejects the geocentre because it has no unique geodetic inverse.
~~~

over:

~~~text
The geocentre case is subject to rejection due to non-uniqueness.
~~~

Technical terms are welcome when they are the precise terms a geodesy consumer
needs. Complexity is not removed by replacing exact terminology with vague
language.

## 2.2 Research basis

This style is informed by William Zinsser's nonfiction-writing principles, not
by a mechanical attempt to imitate literary prose.

Primary essays by Zinsser reinforce the rules used here:

- *Visions and Revisions* emphasizes cutting every word, phrase, sentence, or
  paragraph that does not do necessary work and connects simpler language with
  a more human voice:
  <https://theamericanscholar.org/visions-and-revisions/>
- *Looking for a Model* describes the plain, direct, warm style he valued and
  the importance of speaking directly to readers:
  <https://theamericanscholar.org/looking-for-a-model/>
- *Simple Geometry* argues for removing unnecessary parts:
  <https://theamericanscholar.org/simple-geometry/>
- *No Proverbs, Please* emphasizes short concrete language and active verbs for
  clear English, including technical or complex subjects:
  <https://theamericanscholar.org/no-proverbs-please/>

For `geodesy-d`, these principles become engineering rules: remove clutter,
prefer precise verbs, lead with caller-visible meaning, keep exact technical
terms where they carry necessary information, and never make a consumer learn
the repository's internal history to understand an API.

## 2.3 Consumer comprehension gate

Review every public module and non-trivial public operation as a first-time
consumer. Do not treat a compiled example or syntactically complete Ddoc as
proof that the explanation is useful.

A reviewer must be able to answer these four questions **from the public
documentation alone**, without reading implementation code:

1. **What is it?** State its purpose in one plain sentence.
2. **When would I use it?** Name a recognizable task and, when relevant,
   explain why to choose it over a nearby API.
3. **What does it do?** Identify the inputs, result, units and meaningful
   limits without guessing.
4. **How do I use it?** Follow a short, realistic, compiling example and
   know what to do when the operation fails.

Write for an intelligent reader who does not know the library's history.
Begin with the job and its result, then explain the API choice and example.
Place standards, numerical qualifications and implementation details after
the consumer-facing explanation. Never omit a critical unit, limit, or
failure condition for the sake of simpler prose.

For each non-trivial symbol, record pass/fail for all four questions in the
v2.0 consumer review. A failure is a documentation defect even if all
automated gates pass. Tiny properties need proportionate explanations, not
boilerplate or fabricated use cases.

## 3. Public Ddoc contract

Every public symbol reachable through:

~~~d
import geodesy;
~~~

must have Ddoc that is useful from the generated DDox page without requiring
the implementation source.

Where applicable, the documentation must state:

- what the symbol represents or does;
- parameter meaning;
- input domain;
- output meaning;
- units and unit relationships;
- `.init` semantics;
- canonicalization;
- checked versus throwing failure semantics;
- non-finite input behavior;
- boundary and singular cases;
- allocation behavior when meaningful;
- numerical guarantees and limits;
- relevant standards.

Do not copy the declaration into prose. Explain information the declaration
cannot express.

## 4. Public examples

Every public API declaration must have a compiler-checked documented
`unittest` that DDox renders as an **Example**.

Examples must:

- normally use only `import geodesy;`;
- show realistic consumer code;
- be short enough to understand at a glance;
- demonstrate the declaration being documented;
- use meaningful geodetic values rather than arbitrary test noise;
- avoid regression-corpus logic and implementation probes;
- compile as part of the documentation gate.

A tiny property accessor may have a tiny example. Avoid duplicating paragraphs
of setup by using the smallest valid construction that still reads clearly.

Regression tests are not documentation examples.

The generated DDox site is the authority for whether an example actually
renders. A source `unittest` alone is not enough.

## 5. Module documentation

Every public module included in generated API documentation must have module
Ddoc immediately before its `module` declaration.

The opening sentence tells a consumer what the module provides.

Required metadata:

~~~text
Authors:
Copyright:
License:
Date:
~~~

Use additional sections only when they help the reader:

~~~text
Standards:
Domain:
Units:
Numerics:
Performance:
Validation:
See_Also:
~~~

Do not add sections merely for visual symmetry.

## 6. Parameters, results, and failure

For non-trivial public operations use Ddoc sections when they improve clarity:

~~~text
Params:
Returns:
Throws:
~~~

`Params:` describes semantic meaning, units, domain, and mutation where those
are not obvious.

`Returns:` describes the successful result and, for checked APIs, every
supported reason for returning `false`.

`Throws:` names `GeodesyValueException` and the conditions that cause it.

For D `out` parameters, remember that the value is initialized to `.init` on
entry. Never claim that a caller's previous value is preserved.

## 7. Units, domains, and defaults

Units and domains are part of the API contract.

Document them explicitly instead of relying on implementation checks.

Important examples include:

- radians versus degrees;
- caller-selected ellipsoid linear units;
- metre-valued WGS 84 and UTM policy;
- arc-seconds and ppm for EPSG-style Helmert construction;
- latitude and longitude domains;
- projection bounds;
- geodesic flattening bounds;
- valid and invalid `.init` states.

## 8. Numerical documentation

State only numerical guarantees supported by evidence.

Distinguish among:

- exact algebraic behavior;
- floating-point approximation;
- promoted working precision;
- iterative convergence;
- bounded-domain approximation;
- externally validated accuracy.

There is no library-wide epsilon.

A public document should explain the numerical behavior a consumer must know.
Detailed derivations and acceptance evidence belong in ADRs and validation
documents.

## 9. Internal functions

Internal code is not exempt from documentation.

Every non-trivial `private` or `package` function must have a concise Ddoc
comment that lets a maintainer understand it without reconstructing the
algorithm from its body.

Document, where applicable:

- what the function computes;
- what each input means and its expected domain;
- what it returns;
- what `ref` or `out` parameters receive or how they are mutated;
- required preconditions;
- invariants preserved by the function;
- important numerical assumptions;
- failure meaning.

A trivial local helper such as `square(x)` does not need ceremonial
documentation if its meaning is completely obvious. The burden is on the code
review to justify such exceptions.

Internal Ddoc is written for the next maintainer, not for DDox consumers.

## 10. Decision comments

Comments inside an implementation explain **why**, not what the next statement
already says.

Required decision comments include non-obvious choices involving:

- numerical stability;
- branch ordering;
- special handling of poles, antimeridians, singularities, and canonical zero;
- working-precision promotion;
- boundary tolerances;
- compiler or standard-library compatibility workarounds;
- performance trade-offs;
- deliberately rejected simpler formulas;
- behavior that differs from an obvious textbook implementation.

Good:

~~~d
// Preserve an exact pole representation. libm cos(pi/2) need not return
// mathematical zero, which would send the meridional case down the wrong path.
~~~

Bad:

~~~d
// Calculate cosine.
const c = cos(phi);
~~~

If removing a comment would make a future maintainer reasonably ask
“why is this written this way?”, the rationale belongs in the code or in a
nearby ADR referenced by the code.

## 11. ADRs, validation plans, and Ddoc

Use each layer for one job:

- **Ddoc:** what the consumer can rely on;
- **example:** how the consumer uses it;
- **internal Ddoc:** what an internal function does and assumes;
- **decision comment:** why a non-obvious implementation choice exists;
- **ADR:** persistent architectural or numerical design decision;
- **validation plan:** evidence that the numerical contract is met.

Do not make the consumer read an ADR to discover ordinary API behavior.

## 12. Review method

Documentation quality is reviewed in two layers.

### Automated

The build must verify:

- Ddoc/DDox generation succeeds;
- every public DDox symbol page is inventoried;
- every public symbol page renders an Example;
- every rendered Example comes from a documented, compiler-checked `unittest`;
- public modules have module Ddoc;
- legacy inline `Example:` blocks are rejected.

### Human review

A reviewer must verify:

- public text is written for the consumer;
- internal non-trivial functions explain inputs, outputs, and invariants;
- important implementation decisions explain why;
- examples are useful rather than ceremonial;
- prose follows the clarity/simplicity/brevity/humanity standard.

These judgments must not be replaced by word-count or comment-count heuristics.

## 13. Definition of done

A release is documentation-complete when:

- every public API is understandable from its DDox page;
- every public API has a rendered, compiler-checked example;
- every non-trivial internal function is documented well enough to maintain;
- important code decisions retain their rationale next to the code;
- the generated DDox site has been inspected as documentation, not merely
  generated successfully;
- the automated documentation gate passes;
- the human documentation-quality review is signed off.

Completeness is measured by reader understanding, not by comment volume.
