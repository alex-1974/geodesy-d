# PM-G5 — Platform / release / regression results

Status: PARTIAL — G5A/G5B PASS; G5C/G5D/G5E/G5F pending

## Baseline

The acceptance run was performed from:

    997d48c docs: define pseudo-mercator PM-G5 acceptance gate

with a clean worktree synchronized to:

    origin/research/pseudo-mercator

## G5A — release builds — PASS

Release-mode library builds succeeded on x86_64 with:

    DMD 2.111.0
    LDC 1.41.0

Commands:

    dub build --build=release --compiler=dmd-2.111.0 --force
    dub build --build=release --compiler=ldc-1.41.0 --force

Both built geodesy-d successfully as a library.

No Pseudo-Mercator-specific release-only compilation failure was observed.

## G5B — repository regression — PASS

Full repository unit tests:

    DMD 2.111.0    22 modules passed unittests
    LDC 1.41.0     22 modules passed unittests

Public API contract validation passed under both compilers, including the
Pseudo-Mercator negative contracts:

    WebMercator alias                 rejected
    conformal factor surface          rejected

The documentation/release metadata contract also passed:

    PASS: Ddoc generated 24 module files
    PASS: documentation/release metadata contract

The worktree remained clean after the run.

## Repository audit observations for G5C/G5D

The package manifest currently declares:

    targetType "library"
    sourcePaths "source"
    toolchainRequirements frontend=">=2.111.0"

No runtime dependency is declared in dub.sdl.

The package aggregate:

    source/geodesy/package.d

publicly imports:

    geodesy.projection.pseudo_mercator

The production Pseudo-Mercator module imports only Phobos and geodesy-d
production modules. No PROJ, GeographicLib, imagery/raster, CRS database, tile
policy, or research module dependency is present in the inspected production
surface.

The existing API validation rejects the two most important explicitly excluded
Pseudo-Mercator public surfaces:

    WebMercator alias
    ConformalProjectionFactors surface

G5C still requires an external consumer smoke build so package exposure is
validated outside the repository.

G5D still requires the final explicit leakage audit against the complete
PM-F exclusion set.

## Remaining work

    G5C external package / aggregate consumer smoke
    G5D research-only leakage audit
    G5E final platform evidence
    G5F documentation consistency / accepted-state update

Pseudo-Mercator is not yet marked accepted.
