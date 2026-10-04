# geodesy-d research repository split

Status: **PRODUCTION SPLIT PREPARED — COMPANION SNAPSHOT VERIFICATION REQUIRED**

The purpose of this split is to keep the production DUB package focused on
consumer and release needs while preserving detailed research evidence in a
separate companion repository.

## Source snapshot

Production source repository:

~~~text
alex-1974/geodesy-d
~~~

Pinned source commit before the split:

~~~text
1acd53709cbf014608c250fcb372d0b52b4e751a
~~~

Selected companion paths:

~~~text
research/**
benchmarks/**
~~~

Pinned tree inventory at that commit:

~~~text
research:    103 files   1,168,756 bytes
benchmarks:   13 files     112,107 bytes
total:       116 files   1,280,863 bytes
~~~

Git history in `geodesy-d` is not rewritten by the split.

## Production boundary

The production repository retains:

- `source/` and the public DUB recipe;
- active unit/API/documentation tests;
- active `validation/` release and regression gates;
- CI/release workflows;
- user and maintainer documentation;
- accepted ADRs;
- small maintainer tools.

The complete `research/` and `benchmarks/` trees move to
`alex-1974/geodesy-d-research`.

Four topocentric files are both historical research evidence and part of the
active hosted release gate. The original copies remain in the companion
snapshot, while production copies are promoted to:

~~~text
validation/topocentric/topo_e_contract_probe.d
validation/topocentric/validate_geodesy_vs_proj.py
validation/topocentric/validate_proj_oracle.py
validation/topocentric/geodesy_topocentric_probe.d
~~~

The hosted topocentric workflow uses only those production validation paths.

Benchmark driver scripts remain in `geodesy-d/tools/` because they are active
maintainer tools. They read benchmark fixtures from a sibling
`geodesy-d-research` checkout by default or from the path in
`GEODESY_D_RESEARCH`.

## Merge gate

Do not merge the production deletion until the companion repository has been
verified against the pinned source commit.

Required companion verification:

- same 116 selected relative paths;
- same file modes;
- same byte sizes;
- same Git blob identities or independent SHA-256 hashes;
- provenance file recording the pinned source commit;
- no production API source introduced into the research repository.

After that verification passes, the production split may merge without
rewriting historical commits.
