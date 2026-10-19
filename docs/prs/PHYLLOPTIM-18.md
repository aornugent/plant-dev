# PHYLLOPTIM-18: differentiate the leaf where its forward answers

Branch `PHYLLOPTIM-18` on aornugent/phylloptim, three commits on master d216a17 (0.10.3),
version 0.10.4. Review notes: `docs/prs/PHYLLOPTIM-18-review.md`.

phylloptim's PR template puts two short paragraphs in the description, which become the
squash commit, and the measurements in the first comment. Both are below.

## Description

The leaf's forward solve returns an operating point in two places where its derivative path
refused. Past the root curve's dry end the forward reads the table's tangent or its cap,
while the rows threw `stem_curve_domain`; and where the feasible collar interval collapses
the forward holds the collar at its midpoint, while `collar_at()` refused `determined`. A
consumer differentiating a stand (traitecoevo/plant's TF24 gradient) meets both on dry
records, and the whole gradient is refused.

The rows are now those of what the forward returns. Past the dry end: the last knot's
tangent with G's rows at the knot, then G(inf) with `dG/db = Gamma(1 + 1/c)` and a digamma
row in `c`, and no row for the conductivity floor. At a determined collar: the mean of its
two bounds' rows, with the stem at `psi_crit` and no collar response; a stem optimum inside
its interval is refused by name. Both bounds of a collapsed interval are polished to collar
precision first, as a pinned bound already is, so a determined collar moves by up to
2.8e-7 MPa and a stem conductance of 1e-30 now solves instead of refusing. `uniroot()` now
refuses a bisection that spends its budget (`>=`, as `uniroot_smooth()`); its old check could
not fire. Nothing else moves: the golden outputs are byte-identical.

## First comment: the case

### The problem, in the model's terms
- **The root curve past its dry end.** The forward caps the root integral past 7.31 MPa; the
  derivative path had no cap and refused past the curve's P99, 6.89 MPa at the defaults. In
  a long drought these readings come from Runge–Kutta stages inside accepted steps (no
  recorded state passes 5.17 MPa): on 1e-4's step sequence the cap binds 2189 times, and the
  reverse sweep replays the stage and refuses (`error-modes.md` F; `localised.md`, *Root
  cause: long drought's sweep refuses at tolerance 1e-4*).
- **A determined collar.** At tolerance 3e-4 a stage reaches a collapsed collar interval;
  the forward holds the collar at the midpoint and `collar_at` had no case, so every
  long-drought record refused (`error-modes.md` F; `localised.md`, *Tolerance 3e-4
  reopened*).
- **Re-measured on 0.10.3:** this branch's `test_leaf.cpp` compiled against master's
  headers fails 17 checks, every one a refusal: 9 dry-end rows (`stem_curve_domain`, (ψ/b)^c
  = 4.99, 4.80 and 259 against the domain's 4.61), 6 determined rows ("no operating point
  to place at one that is determined"), the named refusal, and the budget check.

### The mechanism
- *Dry end* (`closed_form_rows.hpp`, `vulnerability.hpp`): where the read sits past
  `vulnerability_psi_max`, the trait rows are G's at the last knot on the tangent (its slope
  is f there, so the knot's own motion cancels) and G(inf)'s past the cap. The conductivity
  read has no row: the curve is the floor for every trait.
- *Determined* (`leaf_model.hpp`): `collar_at` records the solved collar against the wet
  bound's row and the dry bound's (continuity root or root limit, whichever closed it) at
  weight 1/2 each, so the value stays the solve's. `collar_coords_at` places the stem at
  `psi_crit_at(pars)` with zero response to the collar. Placed by continuity instead, the
  stem kept its value and took the wrong rows: profit's row in `root_P50` read 0.053 where a
  difference of the solve gives −0.83 (archived 29982dc; review C, `C-plant-106-110-phylloptim.md`).
- *Polish:* on 0.10 the two bounds come from root-finds that stop at 1e-4. The collapsed
  branch now polishes both with `polish_bracket_bound`, the same call #136 uses for a
  pinned bound. It runs only where the interval has collapsed.
- *Budget:* boost's `bisect` reports the iterations it used and never more than the
  budget, so `it > max_iterations` could not fire on the Medlyn ci solve.

### The measured gain
| | before | after | source |
|---|---|---|---|
| long drought and ld-105 sweeps at 1e-4 | refused (C4) | pass, worst 0.56ε and 0.45ε | `localised.md`, *After the fix (phylloptim 0.9.2)* |
| long-drought records at 3e-4 | every one refused | all run, finite gradients; forward values equal to the bit | `loc/prereg.md`, a09 at 3e-4, H19-1 |
| what 3e-4 then buys the schedule loop | — | T 6066 against 6699 at 1e-4 on the five training cases (−9.4%) | `localised.md`, *Round 3 on real runs* |
| profit row in `root_P50`, determined (root limit) | 0.053 (continuity placement) | −0.8291; difference of the solve −0.8291 | archived 29982dc; `test_leaf` here |
| determined collar row along `root_P50`, continuity fixture, bounds at 1e-4 | difference of the solve 0.014 | −1.5e-6, against the row's −1.6e-6 | `test_leaf` here, unpolished vs polished |

The first three rows were measured on the stack's library (phylloptim 0.9.2/0.9.3, plant
libS); this PR carries the same rows onto 0.10.

### What it costs
- Lines: +366/−42 over 9 files: headers +79/−15, tests +265/−22, NEWS, DESCRIPTION and the
  vignette.
- Runtime: nothing on the forward. On the derivative path, one `pow` per closed-form root
  integral read to locate the dry end. The polish runs only on a collapsed interval (two
  extra root-finds there).
- Values: the golden grid has no determined point, and the operating-point, psi_stem-optima
  and primitives outputs regenerated on Linux are byte-identical to master's. A determined
  collar moves by up to 2.8e-7 MPa (the polish); a stem conductance of 1e-30 now solves as
  a determined point where it refused as `stem_curve_domain`.

### How it is tested
- `test_leaf`: the dry-end rows against the table's central difference at three (collar,
  soil) points; the determined collar's collar, profit and uptake rows against differences
  of the solve along `root_P50`, `stem_P50` and `psi_soil`, at a root-limit and a continuity
  dry bound, the latter where the unpolished bound sat furthest from its root; the named
  refusal; a starved bisection. `test_transpose` adds both determined fixtures to the
  tangent-against-sweep identity.
- C++ suite on Linux against odelia v0.8.0: test_leaf 3018 checks, test_supplied_rows 178,
  test_transpose 154, 0 failures; golden and primitives pass (cross-platform).
- R testthat: PLACEHOLDER_R.
- plant develop (bd09645d) built against 0.10.4: PLACEHOLDER_PLANT.

### What a reviewer should check
- `collar_at`'s determined case takes both bound rows at the midpoint, up to 5e-4 MPa from
  either bound; measured, that costs 9e-5 relative on the collar row. Taking them at the
  bounds would need two more supply draws.
- The polished continuity root is capped at the root's own limit, and the selector set from
  the same comparison the bracket uses, as on the pin path.
- `test_infeasible_is_a_distinct_failure` now starves the continuity root-find
  (`ci_niter = 3`) because the 1e-30 fixture solves.

### For plant
plant pins `phylloptim (== 0.10.2)` (LinkingTo; Remotes `edaffe8`) and `odelia (== 0.7.3)`.
phylloptim 0.10.3 already raised its odelia floor to 0.8.0, and R refuses to install it
against 0.7.3, so plant's pin change is: `LinkingTo: phylloptim (== 0.10.4)`, Remotes at this
PR's merge commit, and odelia at 0.8.x (the landed PLANT-105 already pins `odelia (== 0.8.1)`).
It belongs in the first plant PR that needs these rows: the scheduling port, or any
long-drought gradient at 1e-4.
