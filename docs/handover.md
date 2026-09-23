# Handover

For the session that implements τ_g. The consult (`oracle-consultation-gradient-control.md`) is the statement of the system and its measured behaviour; this is what a session needs beside it to act.

## Next: τ_g, a declared establishment window

`TF24_Strategy::establishment_probability` reads a newborn's net production `P` at the instant of its creation and returns `P²/(A²+P²)`, zero for `P ≤ 0`, with `A = a_d0 · area_leaf_seed = 8.79e-06` and `recruitment_decay = 0` on this strategy. So the gate reads soil moisture instantaneously, and it opens within **0.178 days** of rain (median, range 0.071–0.714) and closes over **5.54 days** as soil dries. No cohort mesh can resolve four hours; the edge-bracketed mesh works around it and carries a θ-dependent bias because of it. τ_g replaces the instantaneous read with an exponentially weighted one over a timescale of weeks, so both ramps become weeks wide and ordinary fill resolves them.

**The design question to settle first.** `Ḡ` must exist for a *hypothetical* newborn at every time, before any cohort is born at it — so it cannot be a cohort's state. It is the boundary node's net production, smoothed: `dḠ/dt = (P_newborn(t) − Ḡ)/τ_g`, one ODE state carried beside the boundary node or the environment, read by `establishment_probability` in place of `P`. Check how the boundary node is rebuilt each step (`set_state_and_boundary`, `Node::compute_initial_conditions`) before choosing where the state lives; it must be on the tape, and it must be in `census_of`'s path so the seed sees it.

**What τ_g must be.** A parameter with a declared default and its own AD column, since the optimiser may want it. Weeks: 0.02–0.1 yr. Its value is a modelling statement — germination responds to moisture integrated over days — and its effect on `J` is to be measured and reported, not assumed small.

**How to know it worked.** (1) The opening-ramp width measured by the `rw_*` scan rises from hours to about τ_g. (2) The plain dyadic or uniform ladder converges without brackets. (3) The θ-frozen gradient's bias disappears: on a fixed grid, `dJ/dlma` agrees with the edge-following estimate, where today the fixed bracket converges to `−172.9 ± 0.1` against the edge-following `−169.57`. (4) The census and gradient suites pass, and the new state appears in the seed.

Build it on `offspring-adjoint` — it carries the `J` adjoint that item 3 needs.

## Code state

- **`aornugent/plant` branch `offspring-adjoint` at `bb1d8a8a`**, pushed. `J` is a census row; `stand_gradient()` returns `dJ/dθ` by sweep. `S_D` has a column. Verified: the reverse sweep agrees with the forward trajectory tangent on `J` to `2.09e-08` at worst over 22 traits, round-off on species one; `∂J/∂S_D = J/S_D` to round-off; the three size rows and the eleven mutant ratios are bit-identical to the parent build; the FF16 guard passes.
- **Full serial suite: 530 tests, one failure, `test-mutant.R`**, and it fails identically on the parent `5321593a` — stale reference values on the base branch (the model reads `2.7731595978`, the test expects `2.773222`). Not this change's to re-baseline.
- **The `plant-dev` submodule pointer is not bumped** and still records `5321593a`. Bump it to `bb1d8a8a` once nothing is loading the main `plant/` tree: checking out new sources there makes the next `load_all` recompile under any running job.
- **No issue filed** for the adjoint; AGENTS.md wants one, and the branch renamed after it.
- The build lives in a git worktree at `scratchpad/plant-adj`, which is ephemeral. The branch is on origin, so recreate the worktree rather than trust it.

## Established — do not re-derive

| fact | numbers |
|---|---|
| The forcing is lost to the tableau, not to smoothness | embedded difference reads `{0,0.3,0.6,0.875,1}h`, vanishes on degree ≤ 3, widest gap `0.3h`. Unaligned: 4.74% of rain lost, `yerr = 0` on every losing step. Stops at the 2931 active knots make the integral exact to `3.2e-12` |
| The interpolant is fine | monotone Hermite, range held to `1.4e-14`, no negative rainfall, the floor at `tf24_environment.h:585` is dead. Its comments and `R/drivers.R` describe a removed spline |
| The integrand is `C¹` and has no transport term | the gate vanishes quadratically; the adjoint is complete. Its non-convergence is resolution |
| An edge-bracketed mesh converges, to ~0.1% | 2 nodes per edge (crossing, top of ramp): 12.2849 / 12.2768 / 12.2754 / 12.2740 at 498 / 793 / 1378 / 2542. Order 2.57 then stalls; a 3-node bracket sits 0.086% lower |
| Placement decides, not count | at 498 nodes and matched cost, bracketed 0.079% vs uniform 1.277% — 16×. One node per edge is 10–11% out |
| **A frozen grid's gradient converges to the wrong function** | fixed bracket: `−172.9 ± 0.1`, stable across meshes. Edge-following: `−169.57`. 2.3% bias, because the frozen brackets misplace edges that move with θ |
| The transient is free | 44 creations below `b = 0.01` carry 45.5% of member evaluations for 1.35% of `J`; thinning gives 2.09× for `+0.0032%` |
| `β` | Cash–Karp fifth-order real boundary `3.7343596`, crossing at `R = +1`. Adaptive median `h|λ|` is 1.86, half of it |

## Build gotchas that cost time

- `make` → `compile_dll` → `R CMD INSTALL` loses the outer make's jobserver and builds `-j1`. Run `env MAKEFLAGS=-j3 Rscript -e 'pkgbuild::compile_dll(compile_attributes = FALSE, debug = FALSE)'` so the inner make is the jobserver master. A header change is then ~15 minutes.
- Restarting `compile_dll` can wipe `src/*.o`.
- `pkill -f` on a pattern that appears in your own command line kills your own shell. Stop a build by walking its PID tree from the outer `make`.
- `plant` compiles against `phylloptim`'s **installed** headers; `rm plant/src/*.o` after a `phylloptim` header change. `compile_dll` exits 0 having compiled nothing when the `.so` is newer than every source; `force = TRUE`.
- A probe that saves beside `dirname(plant_path)` writes into the `plant-dev` root for the main tree.

## Harness

The measurement scripts are in the session scratchpad and are **not committed**: `ld_common.R` / `lh_common.R` (lifetime 40, 41-year Markov-chain rainfall, `lma = 0.32`, aligned, `J ≈ 12.08`), `rw_*` (the gate scan: `Patch$set_ode_state` replays a stored trajectory and reads the gate at 1 ms a point), `em_*` (the edge mesh), `adj_*` (the adjoint probes). They die with the container.

## Open, beyond τ_g

- The saturation-excess infiltration split switches on the soil **state**, so its breakpoints are not a priori; knot stops do not cover it.
- `refine_schedule` fires on this record, converges in seven iterations at 206 nodes, and certifies an answer 3% from the edge-bracketed one. Its indicator is set by the competition term on every node and not by `J`.
- `test-mutant.R` on the base branch.
