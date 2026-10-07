# geodesy-d v1.2.0 Ddoc prose and style audit

Status: **COMPLETE — pending rendered-site qualification**

Tracking issue: #90.

API-freeze checkpoint:

`freeze/api-1.2.0` -> `7294077b237c7b933b383e86e2e747659b333f26`

## Purpose

Review the published source Ddoc as user-facing technical prose after the v1.2
API freeze.

The audit does not change API or numerical semantics. It improves how the
existing contract is explained.

## Editorial standard

The prose pass combines the workspace documentation contract with
Zinsser-style technical editing:

- write for the caller, not for the implementation;
- begin with what the type or operation does;
- prefer concrete nouns and active verbs;
- keep one main idea per sentence;
- remove project/process language when it does not help the caller;
- remove needless qualifiers and repeated justification;
- put caller-visible semantics before implementation detail;
- keep domain limits, units, failure behaviour, working precision, standards,
  and important performance properties explicit;
- use examples to show realistic use rather than merely restating syntax;
- keep evidence and implementation rationale separate from task-oriented user
  documentation where practical.

The workspace contract remains authoritative when brevity and completeness
compete.

## Scope

The audit covered all 24 public source modules under `source/geodesy`,
including the projection and transform subpackages.

A mechanical first-sentence/style inventory examined about 428 Ddoc blocks on
that public-module surface. It looked for:

- overlong opening sentences;
- meta-openings such as "this module provides";
- passive/process wording such as "is implemented as";
- repeated "deliberately", "intentionally", "accepted", or similar
  engineering-process qualifiers;
- implementation-first wording where a caller-first statement is clearer.

The inventory was followed by a manual review of every public module overview
and the primary type/family documentation.

## Findings

The callable-level Ddoc was already strong overall. Most public methods and
properties use short action-oriented summaries, and the strict DDox example
audit already attaches compiler-checked examples to the rendered symbol
surface.

The main style debt was concentrated in module overviews rather than individual
functions.

The pass therefore avoided a cosmetic mass rewrite.

## Changes

The following module overviews were rewritten for caller-first prose:

- aggregate `geodesy` package;
- angles;
- geographic/geocentric conversion;
- geocentric coordinates;
- geodesic polygon measurement;
- scalar policy;
- conformal projection factors;
- Lambert Azimuthal Equal Area;
- Polar Stereographic;
- Pseudo-Mercator;
- Transverse Mercator;
- UPS;
- UTM.

The conformal-factor overview also corrected stale producer text: the public
producers now include Polar Stereographic and Lambert Conformal Conic in
addition to Transverse Mercator and UTM.

LCC, Rhumb, topocentric, geodesic, Helmert, geocentric translation, and the
remaining value-type module overviews already met the intended style closely
enough that further rewriting would have been churn rather than improvement.

## Contract checks

This prose pass changes no:

- public symbol;
- signature;
- parameter order or name;
- supported scalar;
- unit contract;
- `.init` behaviour;
- failure channel;
- numerical domain;
- canonicalization rule;
- allocation contract.

The authoritative API-freeze checkpoint remains unchanged.

## Remaining publication check

Before the documentation-polish gate is closed:

1. build the exact current DDox/Pages site;
2. require the strict per-symbol example audit to pass;
3. inspect the rendered module tree and representative v1.2 family pages;
4. check navigation and visible formatting for malformed or detached Ddoc;
5. only then mark generated GitHub Pages/DDox output as qualified.
