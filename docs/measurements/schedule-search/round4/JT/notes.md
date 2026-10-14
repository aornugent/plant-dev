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
