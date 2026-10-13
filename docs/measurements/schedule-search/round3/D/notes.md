# D: silent blown-up TF24 adjoint on long drought

Scripts beside this file. Runs in `RUNS=.../schedtest/adjmap/runs/`.

## Observation 0 (look.R, look2.R)

The gradient error of the three bad runs against `val_a09s_c` (bug, n1, a10s) is one
direction: correlation of the difference vectors 0.988–0.9996, and their size ratio
bug : n1 : a10s ≈ 0.017 : 1 : 347, near-constant across all 50 traits. So the
defect is a single scalar λ multiplying a fixed trait-direction v: error = λ·v, λ spread
over three decades (heavy-tailed, like 1/δ with δ a small random number). Largest
components of v: omega, theta, a_bio, storage_relaxation_offset, a_r1, curv_fact_colim.

Inference: one place in the reverse sweep (or one forward quantity) divides by
something the schedule/tolerance makes arbitrarily small, and its adjoint flows into
the traits through one fixed path.

## Sources

lib19 = odelia from `dev/design/odelia` (f19f7de; its installed headers match that tree
and no other), phylloptim `dev/p21/phylloptim` 0.9.3, plant worktree `adjmap/wt`
(adjmap-probe, fa9afe76). lib18 differs only in phylloptim 0.9.2. The sweep is
`odelia::Solver::solve_adjoint` (ode_solver.hpp:324); the leaf's interior derivation
divides by the profit curvature, guarded by `gradient_curvature_floor` (1e-3) in
`tf24_strategy.h:1708`, the smallest |curvature| met reported by
`census_curvature_margin_tf24`. An independent reference exists:
`ladder_trajectory_tangent_tf24` (forward tangent along the recorded steps).

## H1 (pre-registered before E1): a near-singular leaf curvature on the differentiated path

I think λ is 1/curvature of the leaf's profit at one interior operating point met only
on the bad runs, just above the 1e-3 floor (so not refused), because λ is heavy-tailed
like 1/δ, a single direction v, and v leads with omega/theta (the leaf's
curvature parameters) and the hydraulic traits.

E1 (probe.R, PIN replay of the run's own steps; then sweep, margins, tangent along
curv_fact_colim):
- predict: replay J bit-identical to the saved J and the replayed sweep reproduces the
  saved gradient (otherwise PIN is not a faithful replay and later steps are moot);
- predict under H1: curvature margin a10s ≪ a09s, with a10s's within ×10 of 1e-3 and
  a09s's at least ×30 above a10s's;
- predict under H1: the forward tangent along curv_fact_colim agrees with the adjoint
  (both linearise the same IFT) on both runs: a10s elasticity ≈ 2186;
- the alternative H2 (the transpose is wrong): the tangent on a10s gives ≈ 60 where
  the sweep gives 2186.
