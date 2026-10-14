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
