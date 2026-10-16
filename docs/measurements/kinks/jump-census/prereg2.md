# Determined collars and the soil's potential ceiling: where, how bunched, how much (registered before the runs)

The census (`results.md`) found two things on three records (long-wet, wet-adG2,
ld-105):
- 424–489 Determined leaf solves on accepted stages;
- the soil's potential ceiling (#21, ψ held at 1000 MPa) binding 176–957 times.

It could not say:
- how many steps those solves fall inside;
- whether the ceiling causes the Determined collars;
- whether either moves a gradient by an amount that matters.

All patches are disposable diagnostics in a scratch copy of libS's plant source. Nothing
lands.

## D1: where and how bunched

*Patch:* an R accessor for each recorded evaluation's leaf solves: node, collar, kind.
Also record, per evaluation, which soil layers sit at the potential ceiling.

*Runs:* a pinned forward replay of each of the three records. It must reproduce J
exactly.

*Report:*
- the steps holding a Determined solve: how many, how many such solves per step,
  and the step lengths;
- which nodes (birth date, age) and which stages;
- whether the step also holds a change of kind into or out of Determined (a jump inside
  the step) or is Determined throughout;
- before and after b = 25;
- the same for HydraulicShutdown and BoundaryRootCrit;
- for the ceiling: which layer, when, and whether its evaluations are the ones with the
  Determined solves (same evaluation, same node's rooting layers).

*Predicted:*

| Prediction | Probability |
|---|---|
| The Determined solves fall in ≤ 60 steps per record: bunched, a few nodes for a few steps each | 60% |
| ≥ 80% of the Determined solves are in evaluations where some layer the node roots in sits at the ceiling: the ceiling is the cause | 55% |
| Most steps holding Determined also hold a change of kind (the jump is inside the step) | 50% |

## D2: how much it moves the gradient

*Runs, on long-wet:*
- the saved AD gradient;
- central differences of ln J on the pinned grid at δ = 1e-3 and 1e-4 (relative) for
  `lma`, `TF24_cost_scale`, `stem_c`, `a_l1`, `root_P50`, `a_r1`, `R_d_25` and
  `rooting_depth_max`;
- the same with step ends added at the first and last Determined transition of each step
  that holds one (`round4/JT/mkstops.R`'s method), and its AD gradient.

*Measure:*
- |AD − central difference| per trait in ε, at both δ (the jump's missing Δf·dt/dθ term,
  plus any jitter);
- |AD with added ends − AD plain| (the stage-placement part).

*Predicted:*
- every |AD − central difference| ≤ 0.1ε at δ = 1e-3 (65%);
- |AD with added ends − AD plain| ≤ 0.05ε rms (65%).

If both hold, the Determined collar does not matter at ε and nothing is built for it.
