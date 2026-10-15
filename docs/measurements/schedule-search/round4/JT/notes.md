# JT: what makes the derivative sensitive to where steps fall at dry's closing edge

Runs A (P_ins3c_dry, tol 3e-4) and B (X_ins3c_2.85e-4_dry), the inset schedule on dry,
lib19. A − B along TF24_cost_scale 0.176ε; 30% of the jitter enters in 9.678–9.753.
Scripts here, outputs under `schedtest/JT_out/`.

Library: libD (lib19's odelia with the sweep printing the trait-adjoint row,
PARAMS, and the state adjoint, LAMBDA, inside ODELIA_TRACE_T0..T1). libD/plant was
built from lib19's plant source plus that header; E1 checks it reproduces A's
elasticities bit for bit before anything is read from it.

## Hypotheses

- H1 a leaf solve crossing into or out of a determined collar (phylloptim#20: ×8
  transpiration across 5e-5 MPa of soil near psi_soil 5.864 MPa).
- H2 the establishment gate g = P²/(a² + P²), P > 0, at the seedling's P = 0 (the
  closing edge), entering the newest interval's establishment count.
- H3 a resident node's net production changing sign inside a step without a split.
- H4 the top soil layer's stiffness under the explicit step, in drying.

## E1 (registered before the runs): per-step trait adjoint and state in the window

`probe.R` on A and on B (pinned, libD, sweep with PARAMS and LAMBDA in 9.60–9.80).
Forward: at each recorded state in 9.60–9.80, the soil by layer (θ, ψ), each node's net
production, collar (opt_root_psi), transpiration, the seedling's net production and
establishment probability, and the TF24_cost_scale column of ∂f/∂θ.

Predictions:
- Check: libD reproduces A's and B's stored elasticities to ≤ 1e-10 relative.
- Localisation: D(t) = (P_A(t) − P_B(t))·θ/J/ε, the cumulative trait adjoint along
  TF24_cost_scale summed from T back to t. Its change across 9.678–9.753 is of the
  splice's order (≥ 0.03ε). If a feature (H1–H3) carries it, ≥ 70% of that change sits
  in one or two steps of either run; if a stiff mode (H4), it is spread over the window
  and the top-soil λ alternates in sign step to step.
- H1 needs a rooted layer at ψ ≥ 5.8 MPa or a node's collar at root_psi_crit (5.870) in
  the window; otherwise H1 is out for this window.
- H2 needs the seedling's net production to cross zero inside the window (at ≈ 9.711),
  and the newest node's establishment entry of ∂f/∂θ to carry the change.
- H3 needs a resident node's net production to change sign inside a step of the window.

### E1 result (JT1_A, JT1_B; `e1.R`, `trace.R`)

- libD reproduces A's and B's stored elasticities exactly (max difference 0), J to 15 digits.
- State in 9.678–9.777 (A; B alike): top-layer ψ 2.0 → 4.4 MPa by the rain at 9.753,
  deeper layers 0.05–0.12 MPa. Collar max 5.60 MPa (at 9.753), under root_psi_crit
  5.870; the soil never nears the determined band (ψ_soil ≈ 5.864). **H1 out** here.
- The seedling's net production crosses zero at 9.7106; its establishment probability
  falls 0.90 (9.701) → 0.52 (9.707) → 0.03 (9.710) → 0: the gate shuts within ~3.5 d,
  half of it in the last ~1.3 d. A's steps there are 1.98, 1.47, 1.50 d (an A step ends
  at 9.71061, P = −2.5e-7: on the crossing); B's 2.2, 1.9, 1.9 d, straddling it.
- The residents' net production: 13/56 nodes negative at 9.678, 56/56 by 9.7106 (all
  cross zero in the same 3 weeks; the split machinery stops at each).
- Cumulative trait adjoint (TF24_cost_scale), D = A − B in ε: −0.130 at 9.678, −0.102
  at 9.753. The window's own increments carry −0.028ε; the rest of the splice's share
  enters before 9.678 through the state adjoint the window hands back.
- The existing splices along TF24_cost_scale (from B, in ε): A to 9.6 −0.027, to 9.678
  (J12) −0.027, to 9.753 (J13) −0.092, to 9.9 −0.103: **the window 9.678–9.753 carries
  −0.065ε of A − B's −0.176ε (37%)** along this trait.

## E2 (registered before the runs): soften the gate, keep the steps

H2 says the discrete derivative's error is the RKCK quadrature of the gate's θ-bump
g'(P)·P_θ, ~2–3 d wide at the default a_d0 (g from 0.9 to 0 in 3.5 d) and sampled by
1.5–2 d steps; the forward's integral of g is error-controlled, its θ-derivative is not.
Test: the splice pair J12 (A's steps to 9.678, B's after) and J13 (A's to 9.753) replayed
with a_d0 × 10 (TRAIT_REL=a_d0=9), which widens the gate's knee in P tenfold (weeks in
time) on the same steps. The pair differs only in the window's steps.
- H2: |J13 − J12| along TF24_cost_scale falls from 0.065ε to ≤ 0.02ε (65%).
- H3/H4 (residents' sign changes, soil stiffness: neither reads a_d0): it stays within
  ±30% of 0.065ε.

### E2 result (JT2_J12_ad10, JT2_J13_ad10; `pair.R`)

With a_d0 × 10 the window's splice difference along TF24_cost_scale falls from −0.0650ε
to −0.0077ε (8.4×), rms over all quantities 0.0149 → 0.0017, same direction (cos 1.00).
**H2 holds as registered; H3/H4's ±30% refuted.** Caveat found afterwards: a_d0 is not a
clean toggle, because establishment weights feed the field (heights differ by up to
0.13 between the a_d0 runs), so the stand itself changed. E3 removes the confound.

## E3 (registered before the build): cut only the gate's derivative

Scratch build libJTcut (`build_cut.sh`): lib19 with `establishment_probability`'s net
production passed through to_passive, so the gate's value (and every forward number) is
unchanged and only ∂g/∂P is dropped from the derivative. Replays on lib19's pinned steps.
- Check: J of the J12 splice equals lib19's to the last digit.
- E3a (J12, J13 splices): H2 says the window's difference along TF24_cost_scale falls from
  0.065ε to ≤ 0.01ε (70%). Refuted (H3/H4 or another path) if ≥ 0.045ε remains.
- E3b (A, B whole runs): the share of the whole A − B (0.176ε along TF24_cost_scale; rms
  0.048) that the gate's derivative carries. Registered: ≥ 60% of A − B along
  TF24_cost_scale goes with the cut (the other lumps also sit at closing edges) (50%).

## E4 (registered before the runs): resolve the gate's knee, keep everything else

`mkfine.R`: the J12 and J13 splice pins with every step ending in (9.69, 9.72] cut into
pieces of ≤ 0.1 d (5 steps each; +146 and +131 rows), lib19, unchanged model. Both runs
then resolve the knee (g 0.95 → 0 over 9.695–9.711) and differ only in the steps of
9.678–9.69 and 9.72–9.753, where nothing has an edge. H2: their difference along
TF24_cost_scale falls from 0.065ε to ≤ 0.015ε (70%); the residents' crossings are also
refined here, so E4 says what a fix buys, and E3 says whose derivative it is.

### E3a result (JT3_J12_cut, JT3_J13_cut): H2 refuted as the carrier

libJTcut reproduces lib19's J to 15 digits. With the gate's derivative cut, the window's
splice difference along TF24_cost_scale **grows** from −0.065ε to −0.161ε (rms 0.015 →
0.042, cos 0.93 with the default pair). The gate's own path carries +0.095ε, opposite in
sign: it offsets part of a larger jitter that lives elsewhere. E2's collapse under
a_d0 × 10 was the confound (a_d0 moves the stand through the establishment weights).
Not H1, not H2. Remaining: H3 (residents crossing zero), H4 (stiffness), or another.
The traces point at the state adjoint: at 9.678 the top soil's λ differs A − B by 0.9%,
every node entry by ≤ 3e-4; the residents' storage λ reaches −6000 mid-window.

## E5 (registered before computing; no run, states from JT1_A/JT1_B): a stiff mode?

At each recorded state in the window, the rates' state Jacobian (forward tangent,
`ladder_rhs_state_jacobian_forward_tf24`), its eigenvalues μ, and z = h·μ for the step
taken from that state. RKCK's real stability limit is z ≈ −3.73.
- H4-like (a stiff mode under explicit steps): some |z| ≥ 2 in the window's long steps
  (1.5–5 d), the mode localised on soil (H4) or on nodes' storage (a storage pool with
  tiny capacity relaxing in hours), and A's and B's z differ in which steps cross −3.73.
- If every |z| < 1 the window is non-stiff and the sensitivity is a resolution effect of
  the residents' sign changes (H3).

### E5 result (`e5.R`): no stiff mode

Over the window max |h·μ| is 1.1 (stiffest mode the seedling node's mortality/height/
storage, μ ≈ −60…−125 /yr); nothing near RKCK's −3.73. **H4 out**; storage is not stiff.

### What the fine grid shows instead (`kink.R`, `switch.R`, JT1_A fine states)

Every resident's leaf switches from an Interior optimum to BoundaryCrit (psi_stem pinned
at psi_crit = 5.9199) during the drydown: 8 nodes in 9.6990–9.7023, then **48 of 56
within 0.44 d, 9.70296–9.70417**; all switch back at 9.758 after the rain. At the
switch the collar's slope drops ×2.5–6 and log-transpiration's slope ×2.5 (kinks in the
forward). The rates' TF24_cost_scale column (forward tangent) shows what that does to the
derivative: the top soil layer's rate sensitivity steps down 0.0159 → 0.0091 → 0.0036 →
0.0008 → exactly 0 across 9.7028–9.7042 (each switched node's uptake stops reading the
cost scale), while each node's storage (net production) sensitivity is smooth through
it (the optimised profit is continuous in θ, by the envelope theorem; transpiration, the
argmax, is not). So the derivative's integrand jumps where the forward only kinks, at
times no step boundary marks: the splits stop at net production's zero, and the cluster
lies inside A's step 9.7012–9.7066 and B's 9.7022–9.7083. A jump inside a step is
integrated with an O(h·jump) error that depends on where the stages fall; the forward's
kink costs O(h²), within the tolerance. TF24_cost_scale, stem_c, a_l1, R_d_25 (traits
that set the interior optimum) against root_P50, a_r1, a (the hydraulic bound) is the
jitter's direction, which is the Interior / BoundaryCrit divide.

## E6 (registered before the runs): put step boundaries on the switches only

`mkstops.R`: the J12 and J13 splice pins with their boundaries in [9.6975, 9.70417]
replaced by exactly 9.6975, 9.70296, 9.70417 in both (first switch at 9.69796), nothing
else changed. All 56 switches then fall in two steps (1.99 d and 0.44 d) the two runs
share; the gate's knee (g 0.87 → 0 over 9.703–9.7106) stays mostly on each run's own
steps, which still differ (A 0.88, 1.47, 1.50 d; B 1.51, 1.87 d).
- Arm switch is the carrier: the window difference along TF24_cost_scale falls from
  0.065ε to ≤ 0.015ε, and rms over quantities from 0.0149 to ≤ 0.005 (70%).
- If ≥ 0.045ε remains, the switches are not the carrier (the gate's knee or another).

### E4 result (JT4_J12_fine, JT4_J13_fine)

Steps in (9.69, 9.72] cut to ≤ 0.1 d in both: the window's difference along
TF24_cost_scale falls from −0.0650ε to +0.0004ε (rms 0.0149 → 0.0001), ln J moves 1e-7ε.
Against the resolved value, A's window steps err by −0.042ε and B's by +0.023ε: errors
of either sign around one answer. **Holds**: everything in the window's jitter lives in
9.69–9.72 (the switch cluster and the gate's knee); E6 separates the two.

### E6 result (JT6_J12_stops, JT6_J13_stops): **the arm switches carry it**

Identical step boundaries over the switches only (steps of 1.99 d and 0.44 d, not a
refinement), each run's own steps over the gate's knee: the window's difference along
TF24_cost_scale falls from −0.0650ε to +0.0018ε (36×), rms 0.0149 → 0.0005. Each run
also lands within 0.002ε of its fully refined value (E4): bracketing the 48-node cluster
with two boundaries is as good as cutting 9.69–9.72 into 0.1-d steps. The gate's knee,
left on different steps, moves the answer by ≤ 0.002ε. Registered as the carrier (70%):
holds.

## E7 (registered before the run): do the other lumps sit on switch clusters?

`tl.R` on A (forward, every recorded state): nodes at psi_crit. For each step, m = the
change in that count (switches inside the step) and h its length; the jump error scales
like Σ m·h·(the jump's weight). Registered: the windows that carry the jitter (3.5–5,
6.7–8.25, 9.68–9.75, 10.04–17) have large Interior ↔ BoundaryCrit switch traffic inside
long steps (Σ m·h), and the quiet windows (5–6.7, 8.25–9.15, after 17) have little
(60%). A weak test: the weight (λ of the soil, the cohort's share of J) is not read.

### E3b result (JT3_A_cut, JT3_B_cut): refuted, the other way

With the gate's derivative cut over the whole run, A − B grows from rms 0.048 to 0.243
(max 0.84 on a_dG1; TF24_cost_scale −0.18 → +0.54ε). The gate's path does not carry the
jitter; it cancels much of it (in the window too, E3a: +0.095 against −0.16). Read with
E6: the jitter is a quadrature error of the residents' uptake sensitivity at the arm
switches, weighted by the soil's adjoint, and the gate's sensitivity to the soil is one
of the terms of that weight, opposite in sign to the rest.

### E7 result (`tl.R`, `e7.R`, tl_A.rds): traffic is necessary, not sufficient

Every drydown after b = 3.5 has the whole stand switch to BoundaryCrit, mostly inside one
long tolerance-set step (e.g. 45 nodes in a 4.2-d step at 7.54, 52 in 1.98 d at 9.70, 60
in 3.7 d at 10.68); the switch back is at the rain, on the rain's 1-day knots, which A and
B share. Windows with no switches (0–3.5, 9.15–9.68) carry no jitter, as predicted; but
5–6.7, 8.25–9.15 and after 17 have as much traffic in long steps and carry ~0. Refuted as
registered: the jump's weight (the soil's adjoint there, large near a closing edge where
the gate reads the soil, and offset by the gate's own term, E3) decides which clusters
show. Not measured outside 9.6–9.8.

## Root cause

When the soil dries, each resident's leaf moves from an Interior optimum to the
BoundaryCrit arm (stem at psi_crit). Net production is the optimised profit and stays
smooth in θ and the soil, but transpiration (the argmax) has a kink, so the rates' θ-
and soil-sensitivity of the soil's water balance jumps (the top layer's ∂rate/∂cost_scale
goes 0.016 → 0 across 0.4 d). No step boundary is placed there: the splits stop at net
production's zero, the forward's tolerance sees only a kink. RKCK integrates the jump
with an O(h) error set by where the stages fall, which is the jitter; ln J, the forward,
carries O(h²) and moves 1e-3ε. Bracketing the cluster with two step boundaries removes
it (E6, 36×; matches a 0.1-d refinement within 0.002ε).

# Part 2 (15 October): detect the arm switch, stop the step there (plant#112)

## The scalar (read from phylloptim, before any run)

`Leaf::maximise_profit_over_collar` classifies from the marginal profit dprofit/dcollar
at the two ends of the feasible collar interval, which it evaluates on every solve:
f_lo at the wet end (root_zero_E) and f_hi at the dry end (psi_stem = psi_crit, or the
root's 5% potential). Interior ⇔ f_lo > 0 > f_hi; BoundaryCrit (or BoundaryRootCrit) ⇔
f_hi ≥ 0; BoundarySoil ⇔ f_lo ≤ 0. So the switch Interior → BoundaryCrit is f_hi's zero,
and f_hi is a marginal evaluated at a bound that moves smoothly with the soil and the
traits, whichever arm wins: smooth through the switch. f_lo plays the same part for
BoundarySoil. Neither is kept today; Determined, HydraulicShutdown and the infeasible
exits never compute them.

## The build (libJTstop; `build_stop.sh`, diff `JT_out/stop_plant.diff`)

- phylloptim: `arm_margin_dry_` = f_hi, `arm_margin_wet_` = f_lo (NaN where no collar
  solve ran, reset per solve and per replay).
- plant: aux `arm_margin_dry`, `arm_margin_wet`, `arm_kind`; `Patch::sign_values` gives
  net production for every node and then f_hi for every node (blocks n..2n−1; the splits
  read only 0..n−1); `Patch::stop_fraction` runs odelia's own `taken_step::sign_changes`
  rule (ends and four inner stages, the pair rule, regula falsi on the dense output in
  the step's sampled field) on each node's f_hi block, skipping nodes with a non-finite
  reading, and returns the first root in (1e-6, 1 − 1e-6), or the last when asked.
- odelia `step()`: after a step is accepted and before its split, with JT_STOP=1, cut it
  at that root and retake it (one retake per step); a step that was cut at its first
  root makes the next step cut at its last (E6: bracketing a cluster is enough).
  JT_STOP=0 detects and logs only (JT_STOP_LOG, JT_STOP_SCAN: 400-point scan of the
  step's own dense output, JT_STOP_T0/T1 window). Pinned replays and the sweep are
  untouched: a stopped run's steps are ordinary rows.

## S1 (registered before the run): detection on A's own steps

Inset schedule, dry, tol 3e-4, libJTstop, JT_STOP=0, forward only, logging 9.69–9.72.
- Check: the run takes A's steps exactly (same J to 15 digits, same step count).
- The step 9.70117 → 9.70658 holds 49 switches (E-switch.R: 48 in 9.70296–9.70417 plus
  stragglers). The rule finds one root per switching node in it (≥ 95% of them), each
  within 1e-3 of the step (≈ 8 min) of the 400-point scan's crossing; the scan finds one
  crossing per node per step (no chatter).
- f_hi's zero agrees with the arm switch from E-switch.R (psi_stem reaching psi_crit) to
  the fine grid's 0.02-d resolution.
- Other arms: census_operating_point_counts over the run. Registered: Interior and
  BoundaryCrit dominate; BoundarySoil, Determined, HydraulicShutdown at most rare on dry.

## S2 (registered before the runs): the stop in the whole-run nudges

Sharp gate: inset committed schedule, dry, gradient, JT_STOP=1, tol 3e-4 and 2.85e-4
(libJTstop). Averaged gate: a09's committed schedule (loc_a09_c_dry), dry, 1e-4 and
1.05e-4 (libJTstopAG). Bar (the coordinator's): the nudge's rms move ≤ 0.03ε in both
(now 0.048 sharp at 3e-4, 0.110 averaged at 1e-4). Registered: holds on the sharp gate
(65%), holds on the averaged gate (50%: its edge error may not all be switch-borne).
Cost: extra accepted steps and rows against the unstopped runs, registered +3–10%.

### S1 result (S1_detect, S1b_census; `s1b.R`)

- Detection only (JT_STOP=0) takes A's steps exactly: J 1.1962273456123, 4786 steps.
- Step 9.69114 → 9.70117 holds 4 switches, step 9.70117 → 9.70658 holds 52; the rule
  finds every one (56 of 56), each a plain end-sign change (v0 < 0 < v1), located within
  |Δu| ≤ 0.0012 of the 400-point scan of the dense output (≤ 4.6 min; the scan's own
  bin is 0.0025), and the scan sees exactly one crossing per node per step. Against the
  psi_stem-based switch times (Hermite of step ends, 0.007-d grid) the roots sit
  −0.009 … +0.04 d off. **Holds.**
- Whole run: 14728 roots in 234 steps (median 51 nodes per step: the stand switches as
  one cluster), 7328 into BoundaryCrit and 7334 out; 33 node-steps hold an in-and-out
  pair (brief excursions in sub-day steps), no chatter. Steps holding roots: 91 under a
  day, 30 rain-knot days, 113 longer than a day.
- Arms over the run (census_operating_point_counts): Interior 3 232 043, BoundaryCrit
  681 934, nothing else (no BoundarySoil, BoundaryRootCrit, Determined, Shutdown) on
  dry. **Holds.**

### S2 result, sharp gate (JT8_ins_{3e-4,2.85e-4}_stop; `nudge.R`)

The nudge 3e-4 → 2.85e-4 moves rms **0.0020** (max 0.007, a_dG1; TF24_cost_scale +0.004)
against 0.048 (0.176) without the stop: 24× smaller, under the bar and under the sharp
gate's 1e-4 jitter (0.02–0.03). **Holds.** The stop moves the 3e-4 answer by rms 0.014
(max 0.042) from A's: A's share of jitter. Cost: steps 4786 → 5334 (+11.5%), rows
454 494 → 512 679 (+12.8%); 530 cuts (299 at a first switch, 231 at a last). For
comparison X's ETT (tolerance ×0.1 within 15 d of closing edges): rms 0.025, rows +8.6%.
Where the cuts fall: 243 in attempted steps under 0.25 d and 148 after b = 25 (where
nothing jitters), so most of the cost buys nothing measurable here.

## S3 (registered before the build and runs): the stop only on steps longer than 0.5 d

Same build plus JT_STOP_HMIN (yr): a step shorter than it is never cut (the jump error
scales with the step; the jitter came from the 1.5–5 d tolerance-set steps). Sharp gate,
inset, dry, 3e-4 and 2.85e-4, HMIN = 0.5 d. Registered: nudge rms ≤ 0.01, cuts fall from
530 to ≤ 250, steps +4–7% (60%).

### S2 result, averaged gate (JT9_a09c_{1e-4,1.05e-4}_stop)

The nudge moves rms **0.095** (max 0.34 a_l1; TF24_cost_scale −0.16) against 0.110
(0.42) without the stop. **Refuted**: under the averaged gate the stop removes little.
Cost +12.6% steps (5448 → 6135), +14.2% rows, 683 cuts. X's ETT (tolerance ×0.1 within
15 d of closing edges) took this pair to 0.009, so the averaged gate's jitter is at
closing edges but not at the residents' arm switches.

Reading: the averaged gate's state E follows dE/dt = (g(P_seed) − E)/0.05 yr, so the
seedling gate's θ- and soil-sensitivity g'(P)·∂P enters a state that seeds every
newborn's density, where under the sharp gate it entered only the newest interval's
count. g'(P) is a bump 2–3 d wide just before the seedling's P = 0 (Part 1, E1: g 0.9 →
0 in 3.5 d) sampled by 1.5–5 d steps: a smooth but unresolved feature, which no sign
change marks and the forward tolerance on E does not see (E moves little across it).

## S4 (registered before the build and runs): the averaged gate's residual is its own gate

libJTstopAGcut: libJTstopAG with the gate's derivative in P cut (forward unchanged), the
same pair with the stop. If the residual is the gate's bump in dE/dt, the nudge rms
falls to ≤ 0.03 (60%); refuted if it stays ≥ 0.06.

### S3 result (JT10_ins_{3e-4,2.85e-4}_h05)

Stop only on steps over 0.5 d: nudge rms **0.0081** (max 0.038 stem_c; TF24_cost_scale
−0.017), 241 cuts, steps 4786 → 5065 (+5.8%), rows +7.1%; within rms 0.004 of the full
stop's answer. **Holds** as registered (≤ 0.01, ≤ 250 cuts, +4–7%). Against X's ETT
(0.025 at +8.6% rows) it is 3× steadier for less.

### S4 result (JT11_a09c_{1e-4,1.05e-4}_stopcut)

Same steps as the stop runs (6135 / 6163: the forward is unchanged). With the gate's
derivative cut on top of the stop the nudge moves rms **0.0285** (max 0.093 a_l1;
TF24_cost_scale −0.059) against 0.095 with the stop alone. **Holds** (≤ 0.03): about
70% of the averaged gate's remaining jitter is the seedling gate's own sensitivity
bump entering dE/dt at closing edges. That carrier needs its knee resolved (X's ETT
does it: 0.009 at +11.5% rows) or a gate whose knee is wide against the steps; the arm
stop cannot reach it, because nothing changes sign there.

## Summary of part 2

- Scalar: f_hi, the collar solve's marginal profit at the dry end, already computed on
  every solve; smooth through the switch, negative on Interior, ≥ 0 on BoundaryCrit.
- odelia's sign-change rule on it finds 56/56 switches in A's two steps over the 9.70
  cluster within ≤ 0.0012 of the step (≤ 5 min), one crossing per node per step; over the
  run 14 728 roots in 234 steps, 33 brief in-and-out pairs, no chatter; only Interior
  and BoundaryCrit occur on dry.
- Stop (cut at first switch, then at last): sharp gate nudge 0.048 → 0.0020 (+11.5%
  steps, +12.8% rows); on steps over 0.5 d only, 0.0081 (+5.8% steps, +7.1% rows).
  Averaged gate 0.110 → 0.095 (+12.6% steps): fails; its jitter is the gate's knee.

# Part 3 (15 October): can the existing split fix #112?

Scratch build libJTsplit (`build_split.sh`): libJTstop (f_hi as each node's second sign
value; the stop off unless JT_STOP is set) plus, under JT_SPLIT_ARM:
- `node`: each node's own split also at its f_hi sign changes, merged with its net
  production's, in the held field; the f_hi sign changes are held fixed in the sweep
  (slope 0), which is first-order exact where the node's own rates are continuous.
- `soil` / `soilall`: a split of the soil, a block after the nodes: the soil's components
  integrated again in pieces meeting at the first and last (`soil`) or at every
  (`soilall`) f_hi sign change of any node in the step, each piece stage a full rate
  evaluation with every other component read from the step's dense output, the soil
  from the piece; recorded and swept like a node's split (`Patch::split_soil`).

Why this route for S2 and not the soil's substeps: the substepped soil takes the stand's
uptake as an input linear across the step (its input slope), so it cannot carry an
input whose derivative in θ jumps inside the step; and it already runs only where the
plants take < SHARE of the flow, which is not the drying steps. Re-evaluating the soil's
rate at the pieces' stages is the node split's own construction, mirrored, and the
sweep already transposes `integrate_substeps`.

## P3-S1 (registered before the run): split the switching node only

Inset schedule, dry, 3e-4 and 2.85e-4, JT_SPLIT_ARM=node, gradient. Registered (the
coordinator's prediction too): it clears little, nudge rms ≥ 0.035 (now 0.048), because
the node's own rates are continuous through the switch (net production is the optimised
profit; E-kink: its storage sensitivity smooth) and what jumps is the soil's uptake
sensitivity (70%).

## P3-S2 (registered before the runs): split the soil at the first and last f_hi sign change

Same pair, JT_SPLIT_ARM=soil. Each step holding switches integrates the soil again in
3 pieces (5 + 6 + 6 = 17 full rate evaluations, about 2.8 steps' worth); A has 234 such
steps. Registered: nudge rms ≤ 0.01 (the soil carries the jump and bracketing isolates
the cluster as the stop did) (60%); steps within ±2% of the unsplit run; extra full
evaluations ≈ 4000 (≈ +14% of the forward's ~28 700), above the stop's +12.8% rows unless
restricted to long steps. If rms stays ≥ 0.02, `soilall` (a piece per sign change) next.

### P3-S1 result (JT12_node_{3e-4,2.85e-4})

Nudge rms **0.0436** (max 0.168, TF24_cost_scale) against 0.048 (0.176): **holds** as
registered, it clears little. 12 322 more node splits (16 502 → 28 824), steps +1
(4786 → 4787). The switching node's own rates are not where the jump is.

### P3-S2 result (JT12_soil_{3e-4,2.85e-4})

Nudge rms **0.0100** (max 0.042 a_dG1; TF24_cost_scale +0.019) against 0.048: **holds**
(≤ 0.01, at the edge). 166 steps split the soil (of 234 holding switches: those whose
soil was already substepped are skipped), 489 pieces from 10 120 sign changes, 2 768
extra full rate evaluations (≈ +8.5% of the run's ≈ 32 500); steps 4787 (+1), rows
unchanged. The 3e-4 answer moves rms 0.008 from A's and 0.017 from the stopped run's.

## P3-S3 (registered before the runs): is the split's derivative right, and does a piece per sign change do better?

- FD check (result: reverse −3.350590, FD −3.350643, 0.0027ε apart on the same steps: **holds**): central differences of ln J along TF24_cost_scale (×(1 ± 1e-4)) on the soil-
  split run's own pinned steps (the replay splits again) against its reverse-mode
  elasticity: within 0.01ε (85%); if not, the soil split's sweep is wrong and S2's number
  means nothing.
- `soilall`, the same pair: nudge rms ≤ 0.005 (closer to the stop's 0.002) at ~18× the
  bracket's split evaluations (a piece per sign change, median 51) (50%).

### P3-S3 result (JT13_fd_±1e-4, JT12_soilall_{3e-4,2.85e-4})

- FD check holds (0.0027ε): the soil split's sweep differentiates the map the run took.
- `soilall` (a piece per sign change: 10 286 pieces, 61 550 extra evaluations, forward
  CPU 131 s against 60, sweep 583 s against 219): nudge rms **0.018**, worse than the
  bracket's 0.010. **Refuted.** Bracketing is enough, and more pieces buy nothing: the
  residual (0.01–0.02) is what the soil split does not reach: the nodes' own
  integration across the switch reads the main step's soil stages, and the 68 steps
  holding switches whose soil was substepped are not split.

## Summary of part 3

| | nudge rms (3e-4 → 2.85e-4) | extra steps | extra full evaluations | rows |
|---|---|---|---|---|
| none | 0.048 | — | — | — |
| node split at f_hi | 0.044 | +1 | (node-only, 12 322 node splits) | +0% |
| soil split, first and last sign change | **0.010** | +1 | 2 768 (≈ +8.5%) | +0% |
| soil split, every sign change | 0.018 | +1 | 61 550 (≈ +190%) | +0% |
| stop (part 2) | 0.0020 | +548 | ≈ 12 per cut × 530 (≈ +20%) | +12.8% |
| stop on steps > 0.5 d | 0.0081 | +279 | ≈ 12 × 241 (≈ +9%) | +7.1% |

# Part 4 (15 October): which sign changes carry derivative error into the elasticities?

Every drydown after b = 3.5 has a stand-wide f_hi sign-change cluster inside one step,
yet the jitter enters in a few windows (3.5–5 16%, 6.7–8.25 9%, 9.68–9.75 30%, 10–17
38%; ~0 in 5–6.7, 8.25–9.15, after 17), and most of the stop's 530 cuts bought nothing.

## H (registered before any run)

A step's contribution to an elasticity's error is the step's quadrature error of the
rates' θ-sensitivity, weighted by the adjoint:
  c_k(θ) = (θ/J) · λ_{k+1}ᵀ · E_k(θ),  E_k = h Σ_i b_i F(t_k + c_i h) − ∫ F dt over the step,
F = ∂f/∂θ along the trajectory (RKCK's fifth-order weights b, stages c). For a jump ΔF
at fraction u of the step, E ≈ h ΔF φ(u), φ(u) = Σ_{c_i > u} b_i − (1 − u), a sawtooth
in [−0.2, 0.2] that is zero at u = 0 and u = 1. The f_hi sign changes put jumps into the
soil rows of F; elsewhere F is smooth and E small. Which windows carry jitter is then
set by λ_soil·ΔF (the weight: how much J reads that soil at that moment), times h and
φ(u) (where the stages fall). Registered: the weight decides, not the switch count or h:
the quiet windows have long steps and full clusters but small λ_soil·ΔF.

## Measurements (registered before the runs)

- P4-R1, R2: A (3e-4) and B (2.85e-4) adaptive on libJTstop, detection only (JT_STOP=0,
  roots logged), the trajectory kept (`probe.R` SAVETRAJ). Check: same steps and J as A
  and B.
- P4-R3, R4: A and B pinned on libD with the sweep printing the state adjoint at every
  step (LAMBDA, whole run); kept only at the steps holding f_hi sign changes.
- Offline (`p4F.R`, no run): for each such step, F (all components × 50 traits, forward
  tangent) at the six stage times and on 24 points across the step (Hermite states),
  E_k from those, c_k from λ.

## Predictions

- P1: Σ_k c_k(A) − Σ_k c_k(B) reproduces A − B along TF24_cost_scale (−0.176ε) within
  30%, and its cosine with the measured A − B over the 50 traits is ≥ 0.8.
- P2: by window, the predicted A − B shares match the splices' (16 / ~0 / 9 / 30 / 38 /
  ~0%) within ±10 points; in the quiet windows |λ_soil·ΔF| is ≥ 5× smaller than in the
  jittering ones while h and the switch counts are comparable.
- P3 (toggles, after the offline prediction): A pinned with step boundaries bracketing one
  cluster (first and last sign change), gradient: the move in TF24_cost_scale is within
  ×2 of −c_k for clusters with |c_k| ≥ 0.01ε, and under 0.005ε for |c_k| < 0.002ε.
Refuted if P1 misses by more than ×2 or the cosine is under 0.5 (then something besides
the quadrature of F's jumps carries it: the jump in ∂f/∂y, or a stage-state effect).
