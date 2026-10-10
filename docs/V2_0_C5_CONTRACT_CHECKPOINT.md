# v2.0 C5 — practical public contract sign-off

Status: **first family review; API freeze not authorized**.
Feature-freeze baseline: `01d2bbc1822d99ef711d5d78487597b76e650211`
(tag `freeze/feature-2.0.0`). Stabilization branch: `release/2.0`.

## Review rule

Review observable contracts, not compiler internals. Prefer existing DMD/LDC
API fixtures, external DUB consumers, documentation and numerical oracles.
Open a code-change issue only for a demonstrated ambiguity, broken consumer
or inconsistent behavior. Do not reopen the completed reflection census.

| Family | Contract checked against existing documentation | Disposition |
| --- | --- | --- |
| Geographic / Geodetic / ECEF | Geographic has no height; Geodetic carries ellipsoidal height; conversion requires consistent ellipsoid and linear unit. | **Keep** current explicit distinction. |
| Latitude / Longitude | Strong types; degree factories and radian storage; longitude canonicalization is explicit. | **Keep**; no implicit angle-unit conversion. |
| Checked / throwing conversion | `tryGeodeticToGeocentric` returns `bool` and writes an out result; convenience form throws `GeodesyValueException`. | **Keep**; package-root consumer smoke compiles. |
| Automatic / prepared UTM | Automatic standard zone differs intentionally from a fixed prepared `UtmProjection`. | **Keep** explicit policy split. |
| Geodesic / Rhumb | Shortest ellipsoidal surface route versus constant-bearing route; prepared solver/line exists for reuse. | **Keep** intentional distinctions. |
| Static / time-dependent Helmert | EPSG rotation convention and reference epoch are explicit; dynamic parameters evaluate at observation epoch. | **Keep** strong convention/epoch types. |
| LCC 2SP | `fromTwoStandardParallels` vs `tryFromTwoStandardParallels`; prepared forward/reverse; documented unsupported-domain behavior. | **Keep**; speculative optimization PR #123 correctly rejected. |

## Evidence and boundaries

- Six-compiler and fresh DUB consumer workflow: [run 38054313106](https://github.com/alex-1974/geodesy-d/actions/runs/38054313106), all seven jobs passed.
- Geodesic prolate GeographicLib: [run 38056746778](https://github.com/alex-1974/geodesy-d/actions/runs/38056746778), DMD/LDC passed.
- Dynamic Helmert PROJ: [run 38056748277](https://github.com/alex-1974/geodesy-d/actions/runs/38056748277), DMD/LDC passed.
- Molodensky-Badekas PROJ: [run 38056749859](https://github.com/alex-1974/geodesy-d/actions/runs/38056749859), DMD/LDC passed.
- Root-import consumer smoke in `tools/fixtures/v2_public_consumer_smoke.d`; API fixtures in `validation/api/`.
- Earlier C1/compiler and DDox audit remains scoped as documented in
  `docs/V2_0_C1_API_EVIDENCE_CHECKPOINT.md`; passing compile tests does not
  establish all runtime contracts or all template instantiations.

## Actual pre-API-freeze work

1. Check exact public result-carrier `.init` and failed `try*` output states
   for core coordinate/projection/navigation families; refer to existing
   tests before adding new ones.
2. Check whether exceptions and parameter-name conventions are consistent
   for any actual caller-facing disagreement; document intentional differences.
3. Resolve outstanding C1 issue #118 proportionally; do not confuse the 463
   DDox pages with a complete compiler-reachable public contract.
4. Bring `docs/API.md` forward from the explicitly frozen **v1** contract
   reference to a clearly delineated v2 contract/migration story, without
   rewriting historical v1 guarantees.
5. Only then review the API-freeze decision on the stabilization branch.

This checkpoint makes no claim of exhaustive per-overload inspection and
does not authorize `freeze/api-2.0.0` or a v2.0.0 release.
