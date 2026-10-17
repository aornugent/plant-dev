# Every elasticity's node error, by region, from one run

Subject: can ONE TF24 gradient run return, beside J and its gradient, each region's
node-schedule error in every elasticity (founders, interiors by era, late), without a
second run? Every prediction is written here, with a probability, before the run or
analysis it concerns. Scripts and the patch are in this directory; outputs in
`scratchpad/deep/rootcause/single/` (`build/`, `runs/`, `logs/`, `sched/`). **[m]**
measured, **[i]** inferred (derivation, reading or estimate). Errors and moves are in ε of
each quantity, against the lib19-class reference (`rootcause/common.R`).

## Summary (written last)

(pending)

## Q1. What the second derivative needs (code reading, no runs) [i]

Notation. The run takes steps x_{k+1} = Φ_k(x_k; θ, c), c the region coefficients of the
node-drop map (c_g scales region g's field change δenv_g; c = 0 in the run). The sweep
carries λ_k = λ_{k+1} ∂Φ_k/∂x and gives dJ/dθ = Σ λ_{k+1} ∂Φ_k/∂θ and, as map columns,
dJ/dc_g = Σ λ_{k+1} ∂Φ_k/∂c_g. A region's error in elasticity k is θ_k ∂/∂θ_k of its ln J
error, so it needs d/dθ (dJ/dc_g) and d/dθ of the own part. Differentiating the sum:

- **T2, the mixed term at fixed trajectory**: Σ_k λ_{k+1} [∂²Φ_k/∂c_g∂x · dx_k/dθ +
  ∂²Φ_k/∂c_g∂θ]. It holds how the field change itself moves with θ (∂δenv/∂x through the
  states, and ∂δenv/∂θ: p50's convexity of the understory's leaf area in birth date). It
  is a first-order sweep with a source: μ_k = μ_{k+1} ∂Φ_k/∂x + λ_{k+1} ∂²Φ_k/∂c_g∂x.
- **T1, the trajectory's curvature**: the field change moves the trajectory by
  x' = dx/dc_g, and with it every step's Jacobian and the census seed (∂²Φ/∂x² · x',
  ∂²J/∂x² · x'_N). This needs the forward tangent x'.
- **own'**: own_g is a function of the final state only (the coarse census Σ W^C F
  less Σ W F, W^C the merged weights), so its θ-derivative is a first-order sweep of one
  more census row.

**The dwr round's failed drop1 is T1 plus part of T2.** With δenv passive it kept T1 and
the env-Jacobian part of T2 (λ ∂²Φ/∂env∂x · δenv) and lost everything through ∂δenv/∂x
and ∂δenv/∂θ. It gave cos −0.11 (interiors), so those lost terms carry the answer, but T1
was not small in every quantity (TF24_cost_scale −0.37 against +0.22 measured).

**Routes, as code.**
- Route 1 (adjoint over a tangent in c) computes T1 + T2 + own' exactly. It needs the
  forward at a tangent scalar (rows carrying x'), every step re-recorded at
  AReal<FReal<G>>, λ carried as FReal across rows and insertions, and second derivatives
  at the supplied-derivative sites (`implicit_value`'s IFT row reads y* frozen and dF/dy
  at the point; `record_with_derivatives` in `tf24_strategy.h`). odelia's active scalar
  is `active_scalar<double>` at 9 sites (adjoint.hpp 171/183–206/257/304–310/380/415/
  458–490, ode_step.hpp 670, ode_solver.hpp 329/372/477; plant scm.h 1205 and
  gradient_ladder.cpp).
- **Route 1 confined (adjoint over tangent, sweep only)**: seed the inner tangent on c_g
  inside each step's recording, with x_k entering at zero tangent. Rows stay double, the
  forward is unchanged, and λ carried as FReal gives exactly T2 + own' for all G regions
  in one sweep. It drops T1. The supplied sites still lose their c-response (y* frozen).
- **Its finite-difference twin, B**: the same sweep over the run's own stored rows, but
  re-recorded with the drop engaged at c_g = 1 (δenv active) and the census row taking
  the merged weights. B's gradient less the run's gradient is T2 + own' to O(c²) (the
  sweep at c = 1 over c = 0 states is the source-driven recursion above, since
  ∂Φ^(1)/∂x − ∂Φ^(0)/∂x is O(c)). Cost: one sweep per region, no forward.
- **Route 2's twin, A**: forward at c_g = 1 (δenv active, merged-weight census), then an
  ordinary sweep. A less the run is T1 + T2 + own' to O(c²): route 1's answer by finite
  difference. Cost: one forward + one sweep per region, on the fine schedule.
- **R0, the dwr round's pinned real coarsening**, here on the committed run c (c \ D_g on
  c's own steps): exact at all orders, rows ≈ 1 − (dropped share) of c's, so cheaper per
  region than A. Route 2 is therefore dominated by R0 on cost and accuracy [i]; A is built
  only to say what route 1 would return.

**Cost model for route 1 [i].** A gradient run is forward 1 + sweep 3.27. At FReal<G>, a
recorded op stores G + 1 numbers per multiplier and a reverse op costs ~2G + 1
multiply-adds; transcendental-heavy forwards pay less than G + 1. For G = 5: full route 1
≈ forward 2–3 + sweep 3.27 × (3–6) ≈ 12–22 forwards ≈ 3–5 gradient runs; confined route 1
≈ 1 + 3.27 × (3–6) ≈ 11–21 forwards. G pinned coarsenings on c cost G × ~0.85 ≈ 4.3. So
nested AD is not clearly cheaper than G pinned runs; what it buys is one pass and shared
steps. Measured here: B's and A's cost per region.

## Plan

One scratch build: libS + `dwr/node_drop.patch` + `active_drop.patch` (here): δenv and
the shares active (`shares_around`, `drop_crowns`, `drop_uptake`, the light's prefix
moments), and a census flag that adds the merged-weight census (`drop_census`) to
offspring production. At double with every coefficient and the flag at zero, nothing moves.

Runs on the committed run `val_insk_c_<case>` (E6 committed setting), regions by
`dwr/mk_drop2.R`'s rule (every other node between kept edge/end nodes; F, Ia, Ib, Ic, L):
- **S** (one process): forward at c = 0; map sweep (all drops, c = 0: D_g); then per
  region a B sweep (c_g = 1, census flag 1). Dry also: B for I at c = 0.5 (linearity) and
  for the whole I (additivity).
- **A**: per region (dry: F, I), forward at c_g = 1 with the flag, then the sweep.
- **R0**: pinned c \ D_g per region (F, Ia, Ib, Ic, I, L), plain gradient runs.
Estimates at c's spacing: e_g = (move to the coarse quantity)/3.

## Pre-registration S (before the build's guard and every run)

| # | prediction | P |
|---|---|---|
| G0 | the patched build's S forward on c dry reproduces the saved J, and its c = 0 map sweep the saved 50 trait columns, `identical()` | 85% |
| G1 | its map columns equal dwr's `map_c_dry` columns within 1e-9 relative (sum over regions) | 85% |
| B0 | B at c = 0.5 for I gives half of B at c = 1 within 5% (rms of the difference over the rms of the move, all quantities) | 80% |
| B0′ | B's Ia + Ib + Ic equals B's I within 5% (same measure) | 80% |
| R1 | R0 on c (dry) against measured: interiors cos ≥ 0.9 over the 46 elasticities, founders cos ≥ 0.9 | 65% |
| A1 | A against R0 (dry): cos ≥ 0.9 for F and for I | 70% |
| A2 | A against R0 (dry): slope (R0 on A, no intercept) in [0.8, 1.25] for F and for I | 60% |
| B1 | B against R0 (dry), interiors: cos ≥ 0.9 | 45% |
| B2 | B against R0 (dry), founders: cos ≥ 0.9 | 50% |
| B3 | T1 is small: rms(A − B) < 0.3 rms(A), for both F and I | 40% |
| K1 | a B sweep (5 regions' columns off, one region at c = 1) costs ≤ 1.3× the run's plain sweep | 60% |
| K2 | the map sweep with δenv active costs ≤ 1.3× the run's plain sweep (dwr: 1.05 passive) | 65% |
| K3 | A's forward costs ≤ 1.3× the run's forward | 60% |

Reasons [i]: G0 because at c = 0 every new active term is multiplied by an exact zero
before it reaches a state's adjoint; B3 because the passive drop1 (T1 + part of T2) was
not small; A1 because first order held for ln J (0.99–1.01) and A is first order in the
field and exact in the own part.
