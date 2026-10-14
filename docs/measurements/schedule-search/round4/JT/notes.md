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
