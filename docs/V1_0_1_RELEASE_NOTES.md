# geodesy-d v1.0.1 release notes

`geodesy-d` v1.0.1 is a narrow patch release for the frozen v1 API.

It contains two numerical correctness fixes and documentation-quality
corrections. No public API signature or capability family is added or removed.

## Fixed

### Transverse Mercator boundary handling

Reverse-boundary acceptance is now invariant under a consistent rescaling of
ellipsoid and projected linear units.

The v1.0.0 implementation used an absolute tolerance whose interpretation
depended on the magnitude of the ellipsoid semi-major axis. That could make the
same physical Transverse Mercator operation behave differently when expressed,
for example, in metres versus kilometres near the supported reverse boundary.

v1.0.1 replaces that magnitude inference with a scale-aware linear validation
budget while preserving the accepted v1 terrestrial tolerance envelope.

The fix includes the metre/kilometre regression case and retains valid public
`float` behavior at the documented boundary.

### Geodesic norm on DMD/Phobos 2.111

The geodesic core no longer relies on the affected two-argument
`std.math.hypot` behavior from the supported 2.111 frontend/Phobos baseline.

An internal scale-first norm preserves finite subnormal inputs and avoids the
known zero-result defect without changing the public API or adding a runtime
dependency.

## Documentation corrected

Public Ddoc for checked APIs using D `out` result parameters has been
corrected in 34 locations across 11 public source modules.

The previous wording could imply that a caller's existing result value was
preserved when an operation returned `false`. In D, an `out` parameter is
initialized to `.init` on entry, so the caller's previous value is not
preserved.

The corrected documentation therefore describes the actual language and API
semantics. This documentation correction does not alter implementation logic, failure
channels, or runtime behavior.

The v1.0.1 documentation pass also establishes a stricter quality baseline:
all 211 public DDox symbol pages own compiler-checked examples, internal
private/package functions are Ddoc-audited, important numerical decisions are
reviewed for rationale comments, and generated DDox is filtered and verified
as public-only documentation.

## Compatibility

v1.0.1 preserves the frozen v1 public source contract.

There are no intended changes to:

- public names or signatures;
- argument order or public parameter names;
- aggregate `import geodesy;` exports;
- scalar or unit policy;
- checked/throwing API families;
- documented operation domains.

Existing v1.0.0 consumers should not require source changes for v1.0.1.

## Validation

The Transverse Mercator fix passed the repository's normal CI and the dedicated
Transverse Mercator validation matrix, including the added unit-invariance
regression.

The documentation correction and quality hardening pass the strict public API
and DDox gates. The final PR #54 documentation run reports 211/211 public
symbol pages with their own compiled Example and no family-only coverage.

## Upgrade notes

No migration is required.

Consumers using Transverse Mercator with consistently scaled non-metre linear
units should upgrade to v1.0.1 to receive the corrected reverse-boundary
behavior.

For the stable v1 public contract, see `docs/API.md`. For the complete change
history, see `CHANGELOG.md`.
