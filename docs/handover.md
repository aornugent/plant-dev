# Handover

For the next session. The consult (`oracle-consultation-gradient-control.md`) is the statement of the system and its measured behaviour; this is what a session needs beside it to act.

## Where it stands

The averaged establishment gate is accepted as the model, at its default `establishment_window = 0.05` yr (`docs/measurements/diag-establishment-window.md`, consult M22). It resolved stability; the question now is performance at fixed accuracy.

**Next: a new consult, `docs/oracle-consultation-solver-performance.md`**, for a fresh Oracle. The existing `oracle-consultation-gradient-control.md` stays as the record of the stability consultation. The user's questions:
- A replacement for `refine_schedule` (built for FF16 and the height coordinate) suited to TF24, the birth-date coordinate and realistic rainfall: fast to find, lean in `Σ M`.
- A grid fixed per rainfall record and shared across θ, with a trust region set by conditioning metrics — or, if the schedule must depend on θ, good heuristics.
- Controller improvements now the dynamics are mollified; whether implicit or multirate integration helps.
- Whether the adjoint can drive convergence, or costs more than it saves.

**Five measurement agents** write their notes in `$SP/perf/<name>/<name>.md` (`$SP` = the session scratchpad). They are `controller` (step anatomy, rejections, stiffness, tolerance economics, stops), `profile` (RHS cost by callgrind, dead members' share, the multirate and forward-speed branches, the implicit stepper), `schedule` (error and cost by birth date, `refine_schedule` on the averaged model, lean fixed designs and their Pareto front), `theta` (a θ0 schedule's error across lma and two more parameters, pinned time grids, conditioning metrics) and `adjoint` (cost and memory, gradient convergence, the value of a newborn by birth date, a goal-oriented schedule error estimate). Lean schedules pass between them through `$SP/perf/schedules/` (`README.txt`). Move each note to `docs/measurements/` when it reports.

Open issues that feed the consult: aornugent/plant#88 (dead members held to `atol`), #89 (`refine_schedule`'s structure on the birth-date coordinate), #90 (its indicator does not bound the error in `J`).

## Code state

- **`plant-dev` records `plant` at `6613dd24`**, the head of `establishment-window`: aornugent/plant#91 (`offspring-adjoint`, `J` by the reverse sweep) and #92 (`establishment-window`, stacked on it). No PRs. The main `plant/` tree is checked out there, detached, with `plant-adj`'s `-O2` build copied in (`needs_compile` FALSE; the establishment-window tests pass on it).
- **Full serial sweep at `6613dd24`: 536 tests, 2 failures, both `test-mutant.R`**, identical on the base build (stale references on the base branch).
- **Builds in the scratchpad:** `plant-adj`, a worktree on `establishment-window`, and `tg/plant-base`, a plain copy of `bb1d8a8a` for the instantaneous model. They survive a container restart; the session's background jobs do not.

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

- Why the stand answers the window with the opposite sign to the stand-fixed estimate.
- A mesh built for the averaged gate: brackets at its kinks, the band fill's spacing, a cost-weighted grading. Uniform 857 costs 654 s.
- The derivative's convergence rate under the window, the time grid's share of it, and the adjoint on a converged mesh.
- The instantaneous fixed bracket's adjoint at `lma = 0.320`, on `tg/plant-base` (about 45 min): it settles M20's "not separated at `d = 1e-3`".
- The saturation-excess infiltration split switches on the soil state, so its breakpoints are not a priori.
- `refine_schedule` certifies an answer 1.7% above the mesh-converged 12.417.
- `test-mutant.R` on the base branch.
