# Handover

For the next session. The consult (`oracle-consultation-gradient-control.md`) is the statement of the system and its measured behaviour; this is what a session needs beside it to act.

## Where it stands

A declared establishment window is implemented and measured (`docs/measurements/diag-establishment-window.md`, consult M22). A TF24 newborn establishes on its gate averaged over `establishment_window`, default 0.05 yr: `dĒ/dt = (g(P) − Ē)/τ_g`, `Ē` in place of `g`, one ODE state per species. Averaging the gate won over averaging the carbon `P`, which leaves the narrowest opening as sharp as the instantaneous gate and takes 2–3 openings entirely. Under the window:
- the opening widens from 0.058 to 39.8 d (10–90%, median), the closing from 1.73 to 17.7 d;
- a uniform ladder converges at order 3 to `1.4e-5`;
- three grids held fixed across θ give `dJ/dlma = −172.52 ± 0.03`;
- the adjoint matches pinned differences;
- `J` moves +1.26%.

The consult's questions still frame the instantaneous model's problems. Reframing them around the averaged model before a fresh Oracle session is the user's call.

## Code state

- **`aornugent/plant` branch `offspring-adjoint` at `bb1d8a8a`**, pushed. `J` is a census row; `stand_gradient()` returns `dJ/dθ` by sweep. `S_D` has a column. Verified: the sweep matches the forward trajectory tangent on `J` to `2.09e-08` at worst over 22 traits; `∂J/∂S_D = J/S_D` to round-off; size rows and mutant ratios bit-identical to the parent; FF16 guard passes.
- **Branch `establishment-window` at `6613dd24`**, pushed, two commits on `bb1d8a8a`:
  - `b3a33626`: the averaged gate. It lives in `Species`, after that species' nodes, behind the `EstablishesOverWindow` concept, so FF16 and K93 are bit-identical and TF24f inherits it (`TF24@v12`, `TF24f@v12.1`). The boundary node is seeded at `Ē`. `Patch::reset()` of an empty patch starts `Ē` at the newborn's gate; the sweep transposes that start at row 0 and the tangent re-seats it. `node_ode_size()` now counts nodes. It also adds the tests (`test-tf24-establishment-window.R`) and a NEWS entry.
  - `6613dd24`: recaptures `reference-gradient.tsv`: 540 new rows; 1380 shared rows move a median of 6.6e-8. Drought moves most (1.theta leaf_area 306.6 → 591.0), because its gradient is unconverged in the step sequence (602 base / 589 window at 1e-8). One clamped row that straddles a census jump is declared as `reference_straddled_jump`.
- **Full serial sweep at `6613dd24`: 536 tests, 2 failures, both `test-mutant.R`**, identical on the base build (stale references on the base branch).
- **Builds in the scratchpad, ephemeral:**
  - `plant-adj` is a worktree on `establishment-window`, built at `-O2`. Two comment-only header edits carry back-dated timestamps, so `needs_compile` is FALSE; a clean checkout compiles them.
  - `tg/plant-base` is a plain copy of `bb1d8a8a`, built, for the instantaneous model.
- **The `plant-dev` submodule pointer still records `5321593a`.** Nothing loads the main `plant/` tree now, so it can be bumped. No issues filed and no PRs; AGENTS.md wants an issue per PR.

## Established — do not re-derive

| fact | numbers |
|---|---|
| The forcing is lost to the tableau, not to smoothness | embedded difference reads `{0,0.3,0.6,0.875,1}h`, vanishes on degree ≤ 3, widest gap `0.3h`. Unaligned: 4.74% of rain lost, `yerr = 0` on every losing step. Stops at the 2931 active knots make the integral exact to `3.2e-12` |
| The interpolant is fine | monotone Hermite, range held to `1.4e-14`, no negative rainfall, the floor at `tf24_environment.h:585` is dead |
| The instantaneous integrand is `C¹` with no transport term | the gate vanishes quadratically; the adjoint is complete; non-convergence is resolution |
| Instantaneous: a bracket converges once its edges come from its own stand, down to a floor | reference-stand roots up to 3.9 d off → 1.2% low. Re-located, 21× contraction per pass: 12.4261 / 12.4194 / 12.4173 / 12.4154 at 499 / 793 / 1375 / 2539; floor 1.5e-4 per doubling, cause not found. **`J = 12.417 ± 0.006`** |
| Instantaneous: uniform placement is erratic | against 12.4222: +4.9% at 429, +0.08% at 498, +3.4% at 857. Misplaced edge nodes act through the canopy, 88× the direct edge-location price |
| Instantaneous: a bracket held fixed across θ curves `J` | edge-following −169.8 ± 1.1. Fixed at the default stand's roots −172.9 (1.8%). Fixed at its own roots: backward −170.59, forward −181.36, central −175.98 (3.8%), `J''` −10 768 against +575 (`em/place_fixc_*.rds`) |
| The window's form and width | offline, averaging `P`: min opening 0.000 d, 2–3 openings taken. Averaging the gate: median opening 10–90% 16.0 / 39.8 / 76.9 d at 0.02 / 0.05 / 0.1, none taken. In the model 39.8 d open, 17.7 d close; `max|dĒ/dt|` 19.7 against the bound 20 |
| The window makes a uniform ladder converge | 13.2764 / 12.7475 / 12.5751 / 12.5736 / 12.5734 at 108…1713; last step 1.4e-5, order 3.0. The default schedule bisected does not converge by 857 (0.25 yr spacing past `b = 3`) |
| Fixed grids agree under the window | pinned, `d = 1e-3`: −172.531 / −172.482 / −172.547 on uniform 857, shifted 857, bracket + band fill 865; `J''` +884 to +1176 |
| Under the window, dead bands need nodes | `Ē` decays inside them; a bracket without band nodes reads `J` 1.8–1.9% low (12.3216 → 12.5632 with 72 band nodes) |
| The window's adjoint | `dJ/dτ_g` 3.6876 against pinned 3.6945; `dJ/dlma` −158.593 against −158.762, plain 108 grid |
| The window's effect on `J` | +1.26% (12.417 → 12.5734); `dJ/dτ_g` +2.2 to +3.7 /yr; all of it in cohorts born before the first band (`b < 3.56`), where a stand-fixed estimate gives −0.47% |
| The transient is free | 44 creations below `b = 0.01` carry 45.5% of member evaluations for 1.35% of `J`; thinning gives 2.09× for `+0.0032%` |
| `β` | Cash–Karp fifth-order real boundary `3.7343596`, crossing at `R = +1`. Adaptive median `h|λ|` is 1.86, half of it |

## Build gotchas that cost time

- `make` → `compile_dll` → `R CMD INSTALL` loses the outer make's jobserver and builds `-j1`. Run `env MAKEFLAGS=-j3 Rscript -e 'pkgbuild::compile_dll(compile_attributes = FALSE, debug = FALSE)'`. A header change is then ~15 minutes.
- Restarting `compile_dll` can wipe `src/*.o`.
- `pkill -f` on a pattern that appears in your own command line kills your own shell. Stop a build by walking its PID tree.
- `plant` compiles against `phylloptim`'s **installed** headers; `rm plant/src/*.o` after a `phylloptim` header change. `compile_dll` exits 0 having compiled nothing when the `.so` is newer than every source; `force = TRUE`.
- A new TF24 parameter needs its `PLANT_TF24_AD_PARAMETER` entry, its `inst/RcppR6_classes.yml` entries and `RcppR6::RcppR6()`.
- `tail -3 a b` fails on two files; a background job then reports failure after its runs succeeded.

## Harness

All in the session scratchpad, not committed, dying with the container:
- `ld_common.R` / `lh_common.R`: lifetime 40, 41-year Markov-chain rainfall, `lma = 0.32`, aligned, `J ≈ 12.08`. `ld_common.R` hard-codes the main `plant/` tree.
- `rw_*`: the gate scan.
- `em_*`: the edge mesh; `em_place.R <roots rds> <denom> <tag> [lma]` runs a bracket at given roots.
- `tg/tg_*.R`, `tg/tg2_*.R`: the window, with copied fixtures pointed at `plant-adj`; `TG_PLANT` selects `tg/plant-base`.
- `adj_*`: the adjoint probes.

## Open

- The consult's questions around the averaged model: the user's call.
- Why the stand answers the window with the opposite sign to the stand-fixed estimate.
- A mesh built for the averaged gate: brackets at its kinks, the band fill's spacing, a cost-weighted grading. Uniform 857 costs 654 s.
- The derivative's convergence rate under the window, the time grid's share of it, and the adjoint on a converged mesh.
- The instantaneous fixed bracket's adjoint at `lma = 0.320`, on `tg/plant-base` (about 45 min): it settles M20's "not separated at `d = 1e-3`".
- The saturation-excess infiltration split switches on the soil state, so its breakpoints are not a priori.
- `refine_schedule` certifies an answer 1.7% above the mesh-converged 12.417.
- Submodule pointer, issues, `test-mutant.R` on the base branch.
