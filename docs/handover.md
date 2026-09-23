# Handover

For the session that implements τ_g. The consult (`oracle-consultation-gradient-control.md`) is the statement of the system and its measured behaviour; this is what a session needs beside it to act.

## Next: τ_g, a declared establishment window

`TF24_Strategy::establishment_probability` reads a newborn's net production `P` at the instant of its creation and returns `P²/(A²+P²)`, zero for `P ≤ 0`, with `A = a_d0 · area_leaf_seed = 8.79e-06` and `recruitment_decay = 0` on this strategy. So the gate reads soil moisture instantaneously, and it opens within **0.178 days** of rain (median, range 0.071–0.714) and closes over **5.54 days** as soil dries. No cohort mesh can resolve four hours; the edge-bracketed mesh works around it and carries a θ-dependent bias because of it. τ_g replaces the instantaneous read with an exponentially weighted one over a timescale of weeks.

**Where the state lives.** The smoothed quantity must exist for a *hypothetical* newborn at every time, before any cohort is born at it, so it cannot be a cohort's state. It is one ODE state beside the boundary node or the environment, read by `establishment_probability`. Check how the boundary node is rebuilt each step (`set_state_and_boundary`, `Node::compute_initial_conditions`) before choosing; it must be on the tape. Carry it dimensionless: in kg/yr it sits at the scale of `A` against `atol = 1e-4`, so the error test would allow ~11`A`, more than the whole ramp.

**What to filter — open, put to the user with a recommendation.**
- *Filter `P`*: `dḠ/dt = (P − Ḡ)/τ_g`, gate `g(Ḡ)`, the form adopted. The gate is half open at `A` and 98.5% open at `8A`, while `Ḡ` heads for ~`17A` (median plateau 0.9965) and climbs at `≈ P/τ_g` near its crossing. Shut to half open therefore takes `≈ τ_g·A/P ≈ τ_g/17`: a day at 0.05 yr, ~50× today's half hour, not weeks. The 1–99% width is ~0.7 τ_g, so a 1–99% metric passes while the steep part is 12× narrower, and a plain ladder needs a node a day. After a drought (`P` reaches −28`A`) `Ḡ` needs most of a τ_g of wet weather to reach zero, so short wet spells open nothing: a threshold whose effect on `J` needs a run to know.
- *Filter the gate*: `dĒ/dt = (g(P) − Ē)/τ_g`, `Ē` read in place of `g`. Slope `≤ 1/τ_g` exactly on any record; half open at 0.69 τ_g. It conserves `∫g` up to one τ_g at the end and delays it by τ_g on average, so `ΔJ ≈ τ_g ∫ c′g` to first order, `c` the rest of the integrand. Cost: `∂_θĒ` jumps at each instantaneous edge, so the frozen-grid derivative is first order, error ≤ `Δ/2τ_g` of each edge's share; a second stage makes it second order.
- *Decide by an offline check*, no build: replay the stored trajectory with `rw_*`, read `P_newborn` densely, filter both ways at τ_g ∈ {0.02, 0.05, 0.1} yr, and measure half-rise width, lag and suppressed openings. Recommendation: the gate filter.

**What τ_g must be.** A parameter with a declared default and its own AD column, since the optimiser may want it. Weeks: 0.02–0.1 yr. Its value is a modelling statement, and its effect on `J` is to be measured and reported, not assumed small.

**How to know it worked.** (1) The opening ramp's half-rise, not only its 1–99% width, becomes a resolvable fraction of τ_g in the `rw_*` scan. (2) A plain ladder converges without brackets at a count that can be run. (3) The θ-frozen gradient's bias disappears: on a fixed grid `dJ/dlma` agrees with the edge-following `−169.8 ± 1.1`, where today the fixed bracket converges to `−172.9 ± 0.1`. (4) The census and gradient suites pass, and the new state appears in the seed.

Build it on `offspring-adjoint`, which carries the `J` adjoint that item 3 needs.

**In progress.** An agent is evaluating both forms offline and implementing the chosen one on `establishment-window`, branched from `offspring-adjoint` in the `scratchpad/plant-adj` worktree. Its scripts are in `scratchpad/tg/`, and its note, `scratchpad/tg/diag-establishment-window.md`, moves to `docs/measurements/` when it reports.

## Code state

- **`aornugent/plant` branch `offspring-adjoint` at `bb1d8a8a`**, pushed. `J` is a census row; `stand_gradient()` returns `dJ/dθ` by sweep. `S_D` has a column. Verified: the reverse sweep agrees with the forward trajectory tangent on `J` to `2.09e-08` at worst over 22 traits, round-off on species one; `∂J/∂S_D = J/S_D` to round-off; the three size rows and the eleven mutant ratios are bit-identical to the parent build; the FF16 guard passes.
- **Full serial suite: 530 tests, one failure, `test-mutant.R`**, and it fails identically on the parent `5321593a` — stale reference values on the base branch (the model reads `2.7731595978`, the test expects `2.773222`). Not this change's to re-baseline.
- **The `plant-dev` submodule pointer is not bumped** and still records `5321593a`. Bump it to `bb1d8a8a` once nothing is loading the main `plant/` tree: checking out new sources there makes the next `load_all` recompile under any running job. The mesh agent's jobs still load it.
- **No issue filed** for the adjoint; AGENTS.md wants one, and the branch renamed after it.
- The build lives in a git worktree at `scratchpad/plant-adj`, which is ephemeral. The branch is on origin, so recreate the worktree rather than trust it.

## Established — do not re-derive

| fact | numbers |
|---|---|
| The forcing is lost to the tableau, not to smoothness | embedded difference reads `{0,0.3,0.6,0.875,1}h`, vanishes on degree ≤ 3, widest gap `0.3h`. Unaligned: 4.74% of rain lost, `yerr = 0` on every losing step. Stops at the 2931 active knots make the integral exact to `3.2e-12` |
| The interpolant is fine | monotone Hermite, range held to `1.4e-14`, no negative rainfall, the floor at `tf24_environment.h:585` is dead. Its comments and `R/drivers.R` describe a removed spline |
| The integrand is `C¹` and has no transport term | the gate vanishes quadratically; the adjoint is complete. Its non-convergence is resolution |
| An edge-bracketed mesh converges once its edges are located on the stand it runs | Roots located on the default schedule's stand are up to 3.9 d off; with them the ladder converges in the fill to 12.274, 1.2% low. Re-scanned on the mesh's own gate, a fixed point contracting 21× per pass: 12.4261 / 12.4194 / 12.4173 at fill 1/16 / 1/32 / 1/64, **`J = 12.424 ± 0.003`** (12.41–12.43 with the ramp interior). The default 108-node schedule is 3.0% low |
| Uniform placement is erratic | against 12.424: +4.9% at 429, +0.06% at 498 (the matched-cost control, by luck), +3.4% at 857. The "16× from placement" was scored against the 1.2%-low limit and does not hold. One node per edge: −11% / −12% at the ramp's midpoint / past its top, +1.9% at the crossing. A misplaced edge node is a live cohort whose weight spans a dead band and thickens the canopy: 0.141 of `J` where the first-order edge-location price is 0.0016 |
| **A bracket held fixed across θ gives a biased derivative** | fixed at the default schedule's roots: `−172.9 ± 0.1`, 1.8% off. Edge-following, settled across three fills: **`−169.8 ± 1.1`**, the error bar the time grid's at `ode_tol = 1e-3`. The default 108-node schedule: `−155.6`, 8.4% shallow. At the first fill the gap is 3.95: 0.287 is the ramps' own shift priced from root velocities, the rest arrives through the canopy. That fixed bracket was also misplaced (roots up to 3.9 d off), so motion and misplacement are mixed; a bracket fixed at the reference trait's own roots has not been run |
| The transient is free | 44 creations below `b = 0.01` carry 45.5% of member evaluations for 1.35% of `J`; thinning gives 2.09× for `+0.0032%` |
| `β` | Cash–Karp fifth-order real boundary `3.7343596`, crossing at `R = +1`. Adaptive median `h|λ|` is 1.86, half of it |

## Build gotchas that cost time

- `make` → `compile_dll` → `R CMD INSTALL` loses the outer make's jobserver and builds `-j1`. Run `env MAKEFLAGS=-j3 Rscript -e 'pkgbuild::compile_dll(compile_attributes = FALSE, debug = FALSE)'` so the inner make is the jobserver master. A header change is then ~15 minutes.
- Restarting `compile_dll` can wipe `src/*.o`.
- `pkill -f` on a pattern that appears in your own command line kills your own shell. Stop a build by walking its PID tree from the outer `make`.
- `plant` compiles against `phylloptim`'s **installed** headers; `rm plant/src/*.o` after a `phylloptim` header change. `compile_dll` exits 0 having compiled nothing when the `.so` is newer than every source; `force = TRUE`.
- A probe that saves beside `dirname(plant_path)` writes into the `plant-dev` root for the main tree.

## Harness

The measurement scripts are in the session scratchpad and are **not committed**: `ld_common.R` / `lh_common.R` (lifetime 40, 41-year Markov-chain rainfall, `lma = 0.32`, aligned, `J ≈ 12.08`), `rw_*` (the gate scan: `Patch$set_ode_state` replays a stored trajectory and reads the gate at 1 ms a point), `em_*` (the edge mesh; `em_scan*.R` re-locate roots on a mesh's own environment, `em_place.R` runs a bracket at a trait value's roots), `adj_*` (the adjoint probes). They die with the container.

## Open, beyond τ_g

- The consult carries the mesh note as of its 1/64 rungs; the re-located 1/128 rung and variant D at 1/32 were still running. The note says `J` has no adjoint path, which is true of `5321593a` only; scope it to that build when the mesh agent finishes.
- The saturation-excess infiltration split switches on the soil **state**, so its breakpoints are not a priori; knot stops do not cover it.
- `refine_schedule` fires on this record, converges in seven iterations at 206 nodes, and certifies an answer 1.7% above the mesh-converged 12.424. Its indicator is set by the competition term on every node and not by `J`.
- `test-mutant.R` on the base branch.
