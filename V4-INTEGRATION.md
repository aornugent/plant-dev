# V4: the AD program on the refactored leaf

**What this branch is.** `ad/v4-integration` carries the AD work program onto the package
trunks, after the leaf model moved out of `plant` and into `phylloptim`. It is the successor
to `claude/odelia-ad-tape-reverse-496fuf` (v3), which remains readable as the reference line.

**Why the base changed.** v3 was built on `plant p3/wave5` and `odelia p3/odelia-integration`,
neither of which ever landed. While that stack was being built, `plant develop` moved the leaf
gas-exchange and hydraulics model out to `phylloptim` (#591) and adopted its resistance-based
interface (#606). `plant/inst/include/plant/leaf_model.h` is now a 63-line compatibility shim;
the leaf is `phylloptim::Leaf`, header-only, consumed by `LinkingTo`. The v3 AD leaf seam lived
in exactly the file that became the shim, so continuing on v3 meant maintaining a seam against
a leaf the family had stopped using.

## The base

| submodule | pinned | branch |
|---|---|---|
| `plant` | `39c0c657` | `develop` |
| `odelia` | `880a1c2f` | `master` (0.3.0) |
| `phylloptim` | `3345795` | `master` |
| `regnans` | `e53713a9` | `master` |
| `logpile` | `cdef780f` | `main` |

## The leaf seam decision

**The O(P) finite-difference `supplied_derivative` seam is retired.** v3 reached leaf parameter
sensitivity by differencing the leaf P times per cohort per step, and carried the leaf's
non-smoothness as a set of open defects. phylloptim now computes those derivatives analytically,
and does so as the package's own deliverable rather than as a plant-private AD affordance.

This closes what `ad-handover.md` listed as next-step 3 — "TF24 Tier-A, O(1) exact leaf
partials", previously deferred as an optimisation. It is no longer an optimisation: it is where
the leaf derivatives come from.

### How the open phylloptim PRs land on the register

Each of the four leaf-side departures in [`CURRENTSTATE.md`](CURRENTSTATE.md) §2 has a
phylloptim PR addressing it. Verified against the PR descriptions, not inferred from titles:

| departure | phylloptim PR | what it does |
|---|---|---|
| 4 — no guard on the intercellular-CO₂ bracket at a non-producing individual | #11, #5 | `dprofit_at_collar_psi` returns a hard `0.0` sentinel where the `ci` solve is infeasible; #11 tests the arms exactly instead of differencing through it |
| 5 — a non-finite supplied derivative at a branch kink corrupts the value | #11 | over a 621-point sweep, 171 points had an arm on the sentinel and `\|H\|` was out by a median factor of 4.7e4; the guard closes it |
| 7 — the parameter half of $\Pi_{pu}$ is differenced, conditioning unmeasured | #8, #6 | the envelope theorem collapses $\mathrm{d}\Pi^*/\mathrm{d}\theta$ to the partial at an interior optimum, so it is analytic and free; #6 removes the 21.8 µs spline rebuild on vulnerability traits |
| 12 — the bound is the maximum of two magnitudes and one can never win | #9 | both root vulnerability curves extrapolated past their last knot; conductivity crossed zero at 7.31 MPa and resistance *fell* as a layer dried. This is v3's "extrapolated wrong-way flux", found independently and fixed at the source |

Two further PRs supply the seam itself rather than fixing a departure:

- **#13 gradient transpose** — a backward sweep over the leaf's traits, one run instead of one
  run per trait. This is the interface plant's adjoint consumes; it is what replaces the FD seam.
- **#15 environment gradient rows** — the leaf differentiated with respect to `PPFD` and one row
  per soil layer, which is precisely the pair of coupling channels departures 10 and 11 concern
  (light reduction, water reduction).

**Dependency.** #13 and #15 are the two this branch's plant work needs. #5, #9 and #11 are
correctness fixes the gradient is wrong without. Landing order for the plant seam work is
therefore: #9 and #11 first (the forward model must be right), then #5, then #13 and #15.

## What carries over from v3, and what does not

The register in `CURRENTSTATE.md` was established against the v3 base. Classifying its thirteen
departures by where they live:

- **odelia-side (1 entry):** departure 1, the active copy outliving a cleared tape. Re-establish
  against `odelia master`; the v3 measurement was on `p3/odelia-integration`.
- **plant-side (8 entries):** departures 2, 3, 6, 8, 9, 10, 11, 13. These concern the cohort
  block adjoint, the two reductions, the census and the transport term — none of which the leaf
  move touched. They should survive the base change, but each is *read* or *measured* against a
  tree that no longer exists, so each needs re-establishing before it is a claim about v4.
- **leaf-side (4 entries):** departures 4, 5, 7, 12, now phylloptim's, as above.

**Departure 13 is open again on both halves.** The C++ census abscissa fix existed only in plant
commit `66029469`, which was never pushed and is unrecoverable. `scripts/measure/census-abscissa-gate.R`
is ported here and the v3 acceptance numbers are recorded in `CURRENTSTATE.md`, but they were
measured against `600e3ebd` — re-baseline the height arm on the v4 base before trusting the
birth-date arm. **This is the first code task on this branch**, because it is a defect in the
quantity being differentiated and every gradient measured against the old census inherits it.

## The plant port

`p3/wave5` is 128 commits ahead of `develop` and touches 88 files, of which **4 are
leaf-related** (`leaf_model.h`, `src/leaf_model.cpp`, `test-leaf.r`, `scratch/leaf_jac_gate.cpp`).
The remaining ~84 are the cohort block adjoint, the reductions, the census, the transport term
and their harnesses, and they are what ports forward. The conflict surface against `develop` is
24 files, concentrated in the leaf and in generated RcppR6 glue.

The port is **not** a merge. Bring work across per departure, each with its gate, so that a
ported change that fails to reproduce its v3 measurement is caught at the boundary rather than
inside a 128-commit merge resolution.

Two pieces of this are already on the new base as open plant PRs, both branched from `develop`:

- **#82 `feat/census-direct-term`** — departure 3, the census direct term.
- **#84 `feat/single-cohort-jacobian`** — one cohort's Jacobian by finite difference.

## Working branches

| repo | branch | base |
|---|---|---|
| `plant-dev` | `ad/v4-integration` | `claude/tf24-ecology-math-review-j6x5ym` |
| `plant` | `ad/v4-integration` | `develop` |
| `odelia` | `ad/v4-integration` | `master` |
| `phylloptim` | — | work continues in its own PRs |

## Documents

The v3 register and the v4 design set are both carried here. They divide as:

- `docs/reports/00`–`07` — the mathematics, the ecology and the structure. Name no code, track
  no progress; true or wrong, never out of date. Reports 05–07 are the v3 line's copies, which
  are the later ones: the v4 line held a verbatim snapshot of them taken 2026-08-05 03:53, and
  its review commit put its findings in `docs/reviews/` rather than editing the reports. Three
  v3 commits refine them past that snapshot, including the census correction.
- `docs/ad-*.md` — the design: infrastructure, record/replay, R interface, census gradients,
  touchpoint catalog, issues. From the v4 line. **`ad-handover.md` §"Branch / PR state" is stale**
  — the stacked PRs it names were closed and their branches deleted; this document supersedes it.
- `CURRENTSTATE.md` — what the code does, with provenance. Carried from v3, re-scoped above.
- `NEXTSTEPS.md`, `METHOD.md`, `ORCHESTRATOR.md` — the plan, the gate rules, the agent protocol.
  Carried from v3. **Their `p3/wave5` and `p3/odelia-integration` references are historical**;
  the working branches are the table above.
- `docs/reviews/` — the v4 line's reviews, including the forward-model review against `develop`
  that produced several of the findings phylloptim is now fixing.
- `scripts/` — the measurement apparatus, ported whole from v3. `scripts/measure/` holds the
  gates; `scripts/tf24-benchmarks/` holds the scenario bank.
