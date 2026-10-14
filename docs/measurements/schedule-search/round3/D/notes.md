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

### E6 result (D_out/e6_*.log, e6.R)

State width 1342 = 148 nodes × 9 + 10 environment entries. In n1g the only λ component
that moves is **env1, the top soil layer**: walking backward from t = 37.0750 it
alternates sign every step and grows (0.0024, −0.0032, 0.0046, −0.0077, … −1.5, −11,
−15, −20, +48, −237, −158, +889, −6.2e3, −5.1e4 at t = 37.0696), then decays
(−3.6e3, −1.9e3, … −0.9 by 37.0575) as it hands its size to everything that reads the
top layer. Node entries do not move (the int_est_mom entries are the steady seeds).
n2, at the same times: env1 stays ≤ 0.13 and does not alternate. env6–env10 carry 0.

**H4 confirmed** in its first half: the defect is a top-soil-layer mode that the
linearised step amplifies with a multiplier between about −1.4 and −8 per step (an
alternating, growing mode: h·μ beyond the RKCK stability boundary) over ~15 steps of
h ≈ 3e-4 y in a rain pulse — while the forward, on the same steps, is stable (its error
control accepted them and its J matches neighbours). The second half (which clamp or
branch makes the derivative stiffer than the forward) is E7's question.

## H5 (pre-registered before E7): the top layer is integrated outside RKCK's stability interval

The top layer's rate is (rain·max(0, 1 − a_infil(θ/θs)^b_infil) − K(θ) − u)/dz with
b_infil = 8, so in heavy rain near saturation ∂rate/∂θ1 = μ1 ≈ −rain·a·b(θ/θs)^7/(θs·dz)
is large. I think the forward sits at the near-saturated equilibrium just wet of which
the kink max(0, ·) cuts infiltration off, with h·μ1 beyond RKCK's real stability limit:
the forward oscillation is bounded by the kink (so its error control passes and J is
right), while the derivative — the product of the step Jacobians on the stiff side —
multiplies by R(hμ1) < −1 every step. E7 (forward only, pinned; θ1 and the rain at
every step in [37.04, 37.09]): predict n1g has a run of ≥ 6 consecutive steps with
share > 0 and R(hμ1) < −1 ending at t ≈ 37.0696 (where λ peaks), and the product of
those R over the run is of order the observed growth (×1e4–1e7); n2 at the same times
has |R| < 1 or its run is broken by share ≤ 0 stages (where the clamp severs the row).

### E7 result (D_out/e7_*.log, e7.R, e7b.R)

Soil: θs 0.428, b_infil 8, a_infil 1, top layer dz 0.3 m. In the rain pulse
(37.047–37.084, rain up to 338 m/yr on the interpolated driver) the top layer sits at
θ1 ≈ 0.39–0.42 with μ1 = ∂rate1/∂θ1 ≈ −6e3 … −3.6e4 /yr, and the run's steps give
z = h·μ1 between −2.3 and −6.2 — at and past RKCK's real stability limit (R(z) = 1 at
z ≈ −3.7; R(−5.8) = 19.5). **The forward itself chatters**: θ1 jumps 0.005–0.03 from
step to step (0.386, 0.417, 0.394, 0.419, 0.399, 0.422 …) while the true solution
there is a smooth near-equilibrium. The step-size controller is sitting on the
stability boundary (accepted z alternating ≈ −5 / −2.5), the classical behaviour of
an explicit adaptive RK on a stiff mode; the soil's error weight is loosened
(WEIGHT_SOIL = 10). **H5 confirmed in mechanism**, but its discriminating prediction
failed: n2 has the same chatter and similar top-layer-only products of R (log10 prod
R: n1g 5.0 over 37.0685–37.075; n2 2.4 there and 6.2 over 37.075–37.082), so the scalar
top-layer model does not say why n1g's adjoint blew up and n2's did not (stage-level
clamp crossings at θ > θs and the coupling to layer 2 and the uptake are not in it).

## H6 (pre-registered before E8): the derivative is the true local slope of a rippled map

If the pinned discrete forward is smooth along the trajectory (no stage crossing a
clamp), the tangent/adjoint is its exact derivative, and the cluster value from a
1e-4 difference is a secant over a ripple of tiny amplitude that the chatter's
exponential sensitivity puts into J(θ). E8: central differences on n1g, rel steps
1e-6 and 1e-7 (and the 1e-4 already done).
- predict under H6: elasticity moves from 60.37 (1e-4) towards 66.5 as the step falls
  (within 0.5 of 66.5 at 1e-7);
- if it stays at 60.37 at 1e-7, the linearisation is not even the local derivative and a
  derivative rule at a stage (clamp at θ > θs, the infiltration max) is wrong.

### E8 result (D_out/e8_*.log)

Central differences of ln J on n1g's pinned steps, curv_fact_colim: rel step 1e-4 →
60.367; 1e-6 → 60.362; 1e-7 → 60.3618 (one-sided either way 60.362). The pinned map is
smooth at every scale tried and its slope is 60.36. **H6 refuted**: there is no ripple;
the tangent/sweep 66.50 is not the derivative of the discrete forward at any scale.
So a derivative rule on the path is wrong, and E5–E6 place it in the top-layer soil
dynamics during the rain pulse at 37.05–37.08 y.

## H7 (pre-registered before E9): the linearised soil chain is wrong in the late window

E9: from the state just after the last introduction before the pulse (t = 36.92129,
range = that insertion's count), forward tangent of J along e_θ1 (and along e_θ2 and
a node's height as controls) vs the central difference of the plain-double replay
from that state, δ = 1e-6 and 1e-8.
- predict under H7: along θ1 the tangent exceeds the replay difference by ≥ 10×; the
  replay difference is the same at both δ;
- controls: tangent and difference agree to ≤ 1% along the controls (or, if they
  disagree too, the fault is not specific to the top layer).

### E9 result (D_out/e9_*.log)

From the state just after t = 36.92129 (replay of it reproduces J to 12 digits in both):

| direction | n2 tangent | n2 FD 1e-6 / 1e-8 | n1g tangent | n1g FD 1e-6 / 1e-8 |
|---|---|---|---|---|
| θ1 | 2.694e-5 | 2.694e-5 / 2.709e-5 | **2.66e-2** | 2.25e-5 / 9.07e-3 |
| θ2 | 6.65e-7 | 6.69e-7 / 4.4e-7 | 6.46e-4 | 1.34e-4 / −1.28e-4 |
| height n1 | 4.56e-8 | 4.59e-8 / 4.96e-8 | 9.20e-5 | 1.25e-5 / 8.44e-5 |

n2: tangent = difference in every direction. n1g: the tangent along θ1 is 1000× n2's,
and the replay differences are not consistent across δ — ΔJ is ~1e-10 whatever δ is,
i.e. n1g's replay carries a noise floor of ~1e-10 in J (n2's is < 1e-13) and both of its
small-δ differences are noise. Not yet decisive: E9b repeats θ1 at δ = 1e-5…1e-3,
where ΔJ clears that floor. Prediction (H7): n1g's difference ≈ 2.7e-5 (n2's), not 2.7e-2.

### E9b result (D_out/e9b_*.log)

Replay central differences along θ1 from t = 36.92: n2 2.78e-5, 2.79e-5, 2.72e-5 at
δ = 1e-3, 1e-4, 1e-5 (smooth). n1g 2.69e-5 at 1e-3 — n2's slope — then 2.82e-5 with
one-sided 2.1e-5 / 3.5e-5 at 1e-4, and −1.8e-5 at 1e-5: n1g's J(θ1) is rough at an
amplitude of ~5e-10 in J, and its large-scale slope is n2's, 1000× below its tangent.

## H8 (pre-registered before E10): roughness is a ripple, smooth below its wavelength

Either (a) the roughness is a ripple from the chatter's exponential sensitivity, smooth
below some wavelength, where its slope is the tangent's 2.66e-2 (the derivative is the
exact derivative of a map whose small-scale structure is meaningless), or (b) it is
non-smooth noise (an iterative solve's tolerance jitter, a branch flip), and the
tangent is not the slope at any scale.
E10: n1g, θ1 replay differences at δ = 1e-7, 1e-9, 1e-10, 1e-11; and the trait,
curv_fact_colim × (1 ± 1e-10) on a pinned run.
- (a) predicts the θ1 differences converge to ≈ 2.66e-2 as δ falls (within 20% at 1e-10
  and 1e-11), and the trait difference at 1e-10 gives ≈ 66.5;
- (b) predicts erratic θ1 differences with no limit and a trait difference near 60.36.

### E10 result (D_out/e10_*.log)

- n1g θ1 replay differences from t = 36.92 at δ = 1e-7, 1e-9, 1e-10, 1e-11: 2.1e-3,
  −6.1e-3, 5.5e-2, −0.47 (one-sided pairs disagree in sign). ΔJ stays ~1e-11–4e-10
  whatever δ is: no limit, a non-smooth floor, not a ripple with a wavelength.
- Trait difference at rel 1e-10: central 60.214 (one-sided 60.211 / 60.218); the
  tangent's 66.50 would move J by 8.4e-8, the observed move is 7.6e-8, and the floor is
  ~1e-10. **H8(b)**: the tangent is not the slope at any scale. (RKCK's stability
  function is positive on the whole negative axis — R(−3.734) = 1, R(−5) = 7.2 — so E6's
  sign-alternating λθ1 is not a real top-layer multiplier on its own either.)

## H9 (localisation, pre-registered before E11)

Starting the tangent at each zero-depth rain stop (h = 0 rows: 37.0575 … 37.0849) and
comparing it with the replay secant (δ = 1e-3, 1e-4) along θ1: predict agreement
(≤ 20%) from every start at or after 37.0740 and disagreement (≥ 10×) from every start
at or before 37.0685, so the defect sits in the steps between 37.0685 and 37.0740
(E5's burst, steps 13131–13145).

### E11 result (D_out/e11a.log, e11b.log)

Tangent from each stop (it reproduces E6's λθ1 at the same rows: −3651 at 37.0685,
−237 at 37.0712, −1883 at 37.0658 … so the tangent and the sweep agree step for step)
against the replay secant along θ1 (δ = 1e-3, 1e-4):

| start | tangent | secant 1e-3 | secant 1e-4 |
|---|---|---|---|
| 37.0849 | 4.25e-6 | 3.79e-6 | 4.39e-6 |
| 37.0822 | 3.79e-8 | −4.1e-6 | 3.79e-8 |
| 37.0795 | 9.3e-6 | −2.3e-7 | 2.0e-6 |
| 37.0767 | −6.6e-3 | 1.2e-7 | 5.1e-6 |
| 37.0740 | −7.7e-3 | −7e-7 | 5.1e-6 |
| 37.0712 | −237 | 2.7e-6 | −4.1e-5 |
| 37.0685 | −3651 | 1.5e-7 | −2.3e-5 |
| 37.0658 | −1883 | −4.5e-6 | 4.2e-5 |
| 37.0630 | −546 | 5.1e-6 | −4.9e-7 |
| 37.0603 | −8.35 | −6.4e-7 | −4.8e-6 |
| 37.0575 | −0.908 | 1.8e-7 | 1.8e-7 |

Agreement from 37.0822 on; from 37.0795 back the tangent grows ×1e3 (by 37.0767) and
×1e8–1e9 (by 37.0685) while the secants stay ≤ 4e-5 and noisy (J's floor here ~1e-9).
**H9 partly wrong**: the departure starts a day earlier than predicted (between 37.0795
and 37.0767), with the steepest growth inside 37.0685–37.0740.

Reading: an amplification of 1e8–1e9 means even δ = 1e-11 leaves the linear regime
inside the window, and roundoff (1e-16) amplified by it is ~1e-7 in θ1 — exactly the
kind of δ-independent floor E10 saw. So E8/E10 cannot by themselves separate
"wrong derivative rule" from "exact derivative of a forward map that is chaotic over
the pulse". The forward's own sensitivity decides it.

## H10 (pre-registered before E12): the forward itself is chaotic in θ1 over the pulse

E12: two pinned forwards of n1g, base and curv_fact_colim × (1 + 1e-10), θ1…θ5 kept
at every row; the same pair for n2.
- predict under H10: n1g's |Δθ1| is ≤ 1e-10 before 37.04, grows by ≥ 1e4 through
  37.065–37.080 (to ≥ 1e-6), then shrinks again after the rain; n2's grows by ≤ 1e2 —
  i.e. the tangent is the exact derivative of a forward that has sensitive dependence
  there, and the defect is the forward discretisation, not a derivative rule;
- if n1g's |Δθ1| stays at the 1e-12–1e-10 level through the pulse, the forward is not
  sensitive and a derivative rule in the top-layer chain is wrong.

### E12 result (D_out/e12_*.rds, e12.R): the forward itself is chaotic over the pulse

max |Δθ1| between the pinned base run and curv_fact_colim × (1 + 1e-10), by window
(log10):

| window | n1g | n2 |
|---|---|---|
| 36.9–37.04 | −9.7 | −9.3 |
| 37.06–37.065 | −12.3 | −12.3 |
| 37.065–37.069 | −11.8 | −11.8 |
| 37.069–37.071 | −10.3 | −11.3 |
| 37.071–37.074 | −5.9 | −10.8 |
| 37.074–37.077 | −5.4 | −12.9 |
| 37.077–37.080 | −3.1 | −10.3 |
| 37.080–37.082 | **−1.6** | −6.9 |
| 37.082–37.085 | −5.2 | −9.0 |
| 37.085–37.1 | −7.8 | −11.4 |
| 38–40.1 | −8.9 | −9.1 |

In n1g a 1e-10 trait change grows ×1e10 in 0.015 y: every soil layer ends up 0.020–0.025
apart (the chatter's own amplitude — saturated), and after the rain stops the forward
forgets it (back to 1e-8 by 37.1). n2 amplifies too (×1e5 to 1e-7) but never leaves
the linear regime. **H10 confirmed for n1g** (its "n2 ≤ 1e2" half was wrong in degree:
n2 sits in the same regime, short of saturation).

So the defect is the forward discretisation, and the derivative is not wrong in the
sense of a bad rule: the tangent and the sweep are the exact derivative of a discrete
forward map that, over this rain pulse, has sensitive dependence on its state (the
top layer integrated by RKCK past its stability boundary, chattering, coupled through
drainage into every layer). That derivative is valid only for perturbations below
~1e-20 and says nothing about J's slope at any usable scale. J survives because the
forward saturates and then forgets; the linearisation does neither.

## Root cause (from E1–E12)

During a heavy rain pulse onto a near-saturated top layer, the top soil layer is stiff:
∂rate1/∂θ1 ≈ −rain·a_infil·b_infil·(θ1/θs)^7/(θs·dz1) − K′(θ1)/dz1 ≈ −1e4 … −3.6e4 /yr
(b_infil = 8, dz1 = 0.3 m, rain up to ~340 m/yr on the interpolated driver). RKCK is
explicit; its stability function is > 1 for h·μ < −3.73. The adaptive controller does
what explicit controllers do on a stiff mode at quasi-equilibrium: it rides the
stability boundary, accepting steps with h·μ alternating ≈ −2.5 and −4…−6 (R up to
~20), and the top layer chatters step to step by about the soil's error level — 1e-2
relative there, because the late-time tolerance weight (100) loosens it. The forward
value is fine: the chatter is bounded, the soil forgets it once the rain stops, and J
moves by ≤1e-9. But the forward map is *transiently chaotic* over the pulse (E12: a
1e-10 trait change grows ×1e10 in 0.015 y), so its exact derivative — which is what
both the forward tangent and the reverse sweep compute, correctly, step for step
(E3, E11 vs E6) — is a product of step multipliers ≫ 1 that only holds for
perturbations below ~1e-20. Whether that product is 1e2 or 1e9 is decided by the
realised sequence of step sizes, i.e. by the schedule and the tolerance: n1 (TOL
1.05e-4) blows up, n2 (0.95e-4) does not, a10s (fixed schedule, SPLIT=1) blows up
worse, n1s (SPLIT=1) happens not to. The blown-up adjoint is injected into θ1 at
~37.07 y and propagates backwards correctly, which is why every bad run's error is the
same trait direction v = λ·dθ1(37.07)/dθ.

Not the adjoint, not a derivative rule, not the leaf curvature (H1 refuted), not the
splits (split runs blow up too), not the determined-collar path (n1g = n1). It is the
forward discretisation: an explicit step outside its stability region, accepted.

Frequency (freq.R over the 62 saved long-drought-family gradient runs): two gross
blow-ups (a10s 1.2e4 ε; n1/n1g 33 ε), one mild one (a10bug, ~0.5 ε off its
neighbours); the rest sit within their discretisation error. The magnitude is a product
of random multipliers, so its distribution is heavy-tailed: gross failures are a few
percent of runs on this record, and sub-ε contamination is likely more common and
invisible. Any record with intense rain on a wet top layer is exposed; how exposed
depends on how loose the soil's error level is in the pulse.

### E13: a small reproduction (small.R, current code, lib19)

TF24 patch, 0.2 y, three nodes, constant rain 100 m/yr onto θ = 0.38: of ~520 accepted
steps, **319–465 take the top layer past RKCK's stability limit** (h·|∂rate1/∂θ1| up to
5.35; the derivative is a central difference through the environment's own
compute_rates, independent of any fix). At the default soil error level (factor 1) the
count is 337 and the chatter amplitude 6e-4; at factor 100 it is 319 and 0.015. So the
controller rides the boundary at any tolerance; the error level only sets the chatter's
amplitude, not whether the step multipliers exceed 1.

## H11 (pre-registered before E14): a stability bound on the step is the fix

Fix: the System reports its stiffest soil relaxation rate at the step's start state
(the largest |∂rate_i/∂θ_i| over layers, by a tangent through layer_rates), and the
adaptive RKCK step is capped at 3.0 over it (R(−3) = 0.26: the mode is damped, not
merely bounded). Predict:
- small.R: no step past 3.0 (+ a few % for the change of θ within a step), steps +≤40%;
- n1's configuration (a10bug schedule, TOL 1.05e-4, SPLIT=0, unpinned): every
  elasticity within ε/3 of n2's configuration under the same fix and of a09s;
  max |elasticity| ≈ 60;
- a10s's configuration (fixed a10 schedule, SPLIT=1): likewise;
- J moves by < ε/3 in ln J; total accepted steps +≤ 10% on long drought.

## Fix (Phase 4)

Local branches, not pushed (worktrees of the plant-dev submodule repos, under
`scratchpad/dev/schedtest/D_src/`):
- odelia `D-soil-stability` (from f19f7de, the tree lib19's odelia was built from): a
  concept `BoundsStiffness` (`s.stiffness(time, y)`, reciprocal time) and, in the
  adaptive RKCK `step()`, the step capped at `3.0 / stiffness` (RKCK multiplier 0.26;
  its stability interval ends at 3.73), not below the minimum step, and not on a
  step that substeps the subsystem. Test first: `tests/testthat/test-stiffness-bound.R`
  (Lorenz declaring a stiffness): failed before (max h·rate 12.0), passes after;
  test-tolerance-factors and test-substeps still pass.
- plant `D-soil-stability` (from fa9afe76, lib19's plant): `TF24_Environment::
  soil_stiffness` (max over layers of |∂rate_i/∂θ_i| by a forward tangent through the
  existing `layer_rates`, uptake held, counting no clamp) and `Patch::stiffness`
  (requires HasSoil). Test first: `tests/testthat/test-tf24-soil-stability.R` (the
  E13 case, stiffness differenced through the environment's own compute_rates):
  failed before (max 4.7 at the default soil error level, 8.5 at factor 100), passes
  after (3.00).

E13 case after the fix (small.R, libE): max z 3.00, no step past 3.73, top-layer chatter
0.0147 → 0.0003 at factor 100; accepted steps 511 → 666 (+30%) — this case is rain
throughout, so it is the worst case for cost.

### E14 result: the fix on the failing configurations (fixrun.sh, fixcmp.R; D_out/f_*)

Unpinned gradient runs on libE (fixed odelia + plant), the a10bug schedule, SPLIT=0:

| run | TOL | J | steps | max \|el\| | worst \|q − ref\|/ε |
|---|---|---|---|---|---|
| n1 (old) | 1.05e-4 | 12.69999 | 11029 | 66.50 | 33.5 |
| **f_n1** | 1.05e-4 | 12.69917 | 11581 | 60.36 | 0.65 |
| n2 (old) | 0.95e-4 | 12.69930 | 11155 | 60.36 | 0.63 |
| **f_n2** | 0.95e-4 | 12.69917 | 11689 | 60.34 | 0.71 |

f_n1 vs f_n2: every quantity within 0.064 ε (the tolerance nudge the objective
allows ε/3 for); both within 0.085 ε of the old sane n2 (the remaining |q − ref| ≈
0.6 ε is this schedule's own discretisation error, shared by all three). ln J moves
6e-5 (ε = 0.025). Accepted steps +5%.

| run | schedule, SPLIT, TOL | steps (old → fixed) | max \|el\| (old → fixed) | worst diff vs |
|---|---|---|---|---|
| f_a10s | fixed a10, 1, 1e-4 | 11076 → 11617 | 2185.5 → 60.37 | a09s: 0.027 ε |
| f_bug | a10bug, 0, 1e-4 | 11086 → 11625 | 60.46 → 60.36 | f_n1 0.070 ε, f_n2 0.129 ε |

**H11 confirmed.** Every fixed run agrees with the sane cluster; the tolerance nudge
(0.95/1.0/1.05e-4) on one schedule now moves every quantity by ≤ 0.13 ε (< ε/3), where it
moved it by 33 ε before. Cost: accepted steps +4.8–5.0% on long drought (the forward
CPU logged here is lower than the old runs', but the machine's load differs, so read the
step count).

Tests on the fixed build (libE), serial, installed package: plant test-census,
test-environment-TF24, all 13 test-gradient-ladder-*, test-gradient-incidence,
test-gradient-parity, test-scm, test-scm-support, test-strategy-ff16 and its
reference comparison (bit-identity tripwire), test-strategy-tf24, test-strategy-tf24f,
all test-tf24-* including the new one: 0 failures. odelia: the new test, tolerance-
factors, substeps, step-adjoint-recording, split-sign-changes and the rest pass; 5
errors in test-implicit-value / test-ode-element-concept / test-step-adjoint are test
snippets that fail to compile against the span-taking record_with_derivatives, and
fail identically on the unmodified f19f7de (pre-existing, unrelated).

Patches: `scratchpad/dev/schedtest/D_out/{odelia,plant}-D-soil-stability.patch`
(uncommitted on the two local branches; nothing committed or pushed).

## A cheap guard for "diagnosed"

1. **Stability margin, free** — the run reports max over accepted steps of
   h·stiffness (the number the cap now bounds at 3.0). On the old code every
   long-drought run would have reported 4–6 in each heavy pulse (E7); with the fix it
   is ≤ 3 by construction, so a value above 3.73 means a step ran unstable somewhere
   the bound does not reach.
2. **Directional difference along the reported gradient, one pinned forward** — move
   ln θ by δ along u = el/|el| on the run's own steps and compare Δln J/δ with |el|
   (guard.R, using f_n2 as the truth): sane runs 1.0003–1.0005, a10bug 1.0019,
   n1 1.103, a10s 70.7. It is generic (it catches any linearisation the forward does
   not have, whatever its cause), costs one forward (~25% of a gradient run), and
   flags gross blow-ups at a 1% threshold; it is blind to error orthogonal to el, so
   it misses mild contamination like a10bug's 0.5 ε in one trait.
3. Zero-cost alternative inside the sweep: the soil block's adjoint growth over any
   0.01 y window (n1g: ×2e7 over 15 steps; n2: bounded) — flag above ×1e3.
