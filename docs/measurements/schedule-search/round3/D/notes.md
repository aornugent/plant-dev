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

### E1 result (out/e1_a10s.log, out/e1_a09s.log)

- Replay faithful: J bit-identical to the saved J, same step times, and the replayed sweep
  reproduces the saved gradient exactly (max diff 0) on both. PIN is a valid lab.
- Curvature margin: a10s 0.8542, a09s 0.8540. Identical and ~850× the floor.
  **H1 refuted**: no near-singular interior curvature on either differentiated path.
- The tangent reference refuses a SPLIT=1 recording ("A walk at this scalar cannot take
  a recorded step that split a block at a sign change"), so the forward-vs-adjoint
  question has to be asked on the SPLIT=0 pair n1g (bad, lib19) / n2 (sane, lib18).

## H2 (pre-registered before E3): the sweep is not the transpose of the forward's linearisation

E3: n1g pinned, forward tangent along curv_fact_colim and recruitment_decay (no sweep;
the saved sweep gives 66.50 and −0.48; the cluster gives 60.37 and 5.26).
- predict under H2: tangent ≈ 60.4 and ≈ 5.3 (the cluster), i.e. the sweep alone is off;
- if instead the tangent reproduces 66.5 and −0.48, the discrete forward's own
  linearisation carries the error and the next question is finite differences.

## E2 (localisation, pre-registered): per-step worst |lambda| (ODELIA_ADJOINT_TRACE=steps)

a10s and a09s, same physical times. Predict: the two traces agree (within a factor ~2)
from T down to some time t*, where a10s's jumps by ≥ ×100 and stays above a09s's below
it; t* is the same physical time as where n1's (later) departs, since the error
directions agree to 0.9996.

(Outputs from E2 on are in `scratchpad/dev/schedtest/D_out/`; E1 and E3 in `out/`.)

### E3 result (out/e3_n1g.log)

- Tangent along curv_fact_colim on n1g: elasticity **66.4978**, the sweep's 66.50, not
  the cluster's 60.37. **H2 refuted** for this column: the sweep is the transpose of the
  forward's linearisation; the linearisation itself carries the error.
- Tangent along recruitment_decay reads exactly 0 (sweep −0.48, cluster 5.26): the
  tangent reference does not reach that trait at all (it enters elsewhere than the
  trajectory the tangent walks), so it is no referee for it. Not evidence either way.

## H3 (pre-registered before E4): the linearisation differs from the discrete map

The pinned forward is a deterministic function J(θ) of the traits at fixed steps. Either
(a) its true slope is the cluster's (some differentiation rule shared by tangent and
sweep is wrong at a rare event), or (b) its true slope really is 66.5 (the derivative
is right; the discrete forward map itself is that sensitive at this step placement).
E4: central difference of ln J on n1g pinned, curv_fact_colim × (1 ± 1e-4).
- predict under (a): FD elasticity ≈ 60.4 (within 0.5);
- predict under (b): FD ≈ 66.5 (within 0.5).

### E4 result (D_out/e4_n1g_{up,dn}.log)

J(θ·(1+1e-4)) = 12.7769754321, J(θ·(1−1e-4)) = 12.6236407612 on n1g's pinned steps:
central-difference elasticity **60.367**, the cluster's 60.37, not the 66.50 that the
tangent and the sweep agree on. **H3(a) confirmed**: the discrete forward map is fine
and has the cluster's slope; a differentiation rule shared by the forward tangent and
the reverse sweep (i.e. in the model's derivative, not in the sweep's transposition)
is wrong on this run. The defect is in the derivative, not in the forward and not in
odelia's sweep.

## E5 (localisation, pre-registered): where the trait adjoint departs

Instrumented copy (`schedtest/libD`, `schedtest/wtD`; only change: the sweep prints the
trait-adjoint row after every step under ODELIA_ADJOINT_TRACE=params). n1g (bad) and
n2 (sane) share the node schedule and differ only in TOL (1.05e-4 vs 0.95e-4), so their
cumulative curv_fact_colim adjoint, accumulated from T backward, should agree to
≲0.1% of its final value at every time, except that n1g's jumps once — at one step,
t*, by about (66.50 − 60.37)/60.37 ≈ 10% of the final value — and runs parallel below.
If instead it drifts over a long window, the defect is a systematic wrong rule over a
regime, not one event.

### E5 result (D_out/e5_*.log, parsed by e5.R / e5b.R)

The cumulative curv_fact_colim trait adjoint (summed from T backward) for n1g and n2
agrees to ≤1e-4 of the final value at every time after 37.072 y. Then, inside a rain
pulse (daily rain knots 37.0438–37.0849), n1g's per-step increments over eight
consecutive steps k = 13138…13131 (t 37.0716 → 37.0685, h ≈ 3–12e-4 y) alternate in
sign and grow ×3–×20 per step: +0.003, −0.017, +0.012, +0.11, −0.42, −8.28, +12.13,
+7.60 (n2's increments at the same times: ~2e-5). Below that, n1g's per-step
increments stay ~1000× n2's (the propagated bad adjoint) and the cumulative gap
climbs to +117 by t ≈ 34.5 y and settles at +79 (10% of the final value) by t = 28 y.
The a10s `ODELIA_ADJOINT_TRACE=steps` trace shows its largest worst-|λ| (1.6e7) at the
same t ≈ 37.070 y. So: one injection, at one physical time, inside one rain pulse,
with the signature of a linearised step whose multiplier is < −1 (an unstable
alternating mode) over ~8 steps.

## H4 (pre-registered before E6): a stiff soil mode the derivative carries and the forward does not

I think a soil-state mode in the rain pulse has h·μ < −2 in the *linearised* RK step
(alternating, growing) while the forward is stable there, because the forward value
is fixed by a clamp/bound (saturation, potential ceiling, infiltration capacity) that
the derivative passes through (or the reverse).
E6: λ itself (row 0, all components) at every step in t ∈ [37.060, 37.075] for n1g and
n2. Predict under H4: the components that grow and alternate in n1g are the soil
entries (the last 10 of the state), not node entries; n2's same entries stay bounded
and do not alternate. If instead they are one node's entries, H4 is wrong and the
injection is a node's (leaf/collar) derivative.
