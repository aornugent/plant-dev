# One gradient run's own node error, by region, from its adjoints

Subject: can ONE TF24 gradient run locate and size its node-schedule error by region,
from its own stored node states and its adjoints (a dual-weighted-residual estimate),
instead of differencing runs? Every prediction is written here before its run or
analysis. Scripts and the patch are in this directory; outputs in
`scratchpad/deep/rootcause/dwr/` (`runs/`, `logs/`, `build/`). **[m]** measured, **[i]**
inferred (derivation, reading or estimate). Errors and moves are in ε of each quantity
(ln J: 0.025), against the lib19-class reference (`rootcause/common.R`).

## Summary (written last)

(pending)

## Q1. What the code holds (no runs)

Source: libS = `git archive 07f7c256` (`summing/build/src0/plant`), odelia and phylloptim
from libS. [code] throughout.

**How the field is built from the nodes** (`species.h`).
- J = Σ_j W_j F_j: W_j the node's establishment weight (its shares of the two intervals
  beside it, `for_each_establishment_weight`, from each interval's exact count E and first
  moment M, which are ODE states), F_j the per-recruit fate (nrr × patch density × S_D).
- Uptake per soil layer i: Σ_j W_j u_ij / area, through the same weights
  (`compute_rates`, `consumption_rate(layer)`).
- Light: not through the weights. Each interval (b_j, b_j+1) is 8 crowns
  (`for_each_interval_crown`): crown s at height h_j + u (h_j+1 − h_j), u = (s + ½)/8,
  with leaf area share.first·LA_j·2(1−u)/8 + share.second·LA_j+1·2u/8 (LA = leaf area at
  ground, `compute_competition(0)`). A midpoint rule in u of the hat-weighted leaf area,
  heights linear in u. The knots of the light profile sum these crowns through prefix sums
  of crown moments.

**Where the sweep holds the adjoints** (odelia `ode_solver.hpp`: `solve_adjoint` →
`sweep_range` → `step_adjoint`; plant `scm.h::census_trait_gradient`).
- The sweep carries λ = d(census)/d(state at row k), one row per metric, across every
  recorded row, highest first; at each row `lambda` is overwritten by the row below's.
  Only the last (`at_first_state`) is returned. At each insertion row λ is narrowed by the
  transposed insertion map.
- The state is every node's 9 entries (height, mortality, fecundity, heartwood, storage,
  nrr, E, M, ...) plus the environment's: five soil layers and five cumulative flows. So
  **the soil layers' adjoints are entries of λ at every row**; a disposable accessor that
  copies those 10 entries per row in `sweep_range` costs 5110 × 10 doubles on dry.
- **The light has no state and so no row adjoint.** It is rebuilt at each of the six
  stages of each step from the node states; its adjoint exists only on that step's tape,
  at that stage's adaptive knots, and is cleared with the tape. Exposing it means reading
  the knots' adjoints per stage before the tape is cleared, on a grid that differs from
  stage to stage.
- Node states per row are already kept (`record_trajectory`, `rec[k].state`). But δfield
  needs each node's leaf area and per-layer uptake, which are model evaluations of the
  state, not states. So an offline route (λ per row from an accessor, δfield recomputed in
  R from stored states) repeats a forward evaluation per row and still lacks the light's
  adjoint.

**The route that needs neither**: contract inside the tape. Add c_d·δenv_d to the field,
with c_d = 0 (no number moves in the forward), and read ∂J/∂c_d off the sweep's existing
parameter adjoints. This is exactly branch `adjmap-probe` (fa9afe76, the "drop map"):
one light and one soil coefficient per dropped node per time band, δenv_d = the spanning
interval's 8 crowns less the two intervals' 16 (shares from the merged E, M), and per
layer the merged weights' uptake less the three nodes' own. Its base differs from 07f7c256
in two headers by six unrelated lines; the patch applies to libS cleanly
(`node_drop.patch`, here). So virtual coarsening of any region costs one map sweep for all
regions at once (the columns are per node and band; a region's estimate is a sum of
columns).

**The estimator.** Fine run P with nodes b_0 … b_n; region g's drop set D_g (every other
node of g, each with kept neighbours, no two adjacent); coarse schedule C_g = P \ D_g.
- Own part (exact, no dynamics): own_g = ln(Σ_{j∈C} W^C_j F_j / Σ_j W_j F_j), W^C the
  merged-interval weights. For nested grids W^C_i = Σ_f φ^C_i(b_f) W_f exactly (the coarse
  hat is piecewise linear on the fine grid), so W^C needs only the stored W
  (`p50/split.R::hatw`).
- Field part to first order: field_g = (1/J) Σ_{d∈D_g} Σ_bands (∂J/∂c^light_d,b +
  ∂J/∂c^soil_d,b) = (1/J) ∫ λ_env(t) · δenv_g(t) dt, the exact derivative of the discrete
  scheme (all six stages of every step). It includes the establishment's response (E, M
  are states integrated in the field).
- D_g = own_g + field_g ≈ Q(C_g) − Q(P). For a second-order region, D_g = (2² − 1) K h² =
  3 e_g, so **e_g ≈ D_g / 3**.
- First order: the field moves by ~1% (p50: interiors over-count the understory's leaf area
  by 0.5–1.1%), the remainder is second order in that, ~1% of the field part unless the
  response is sharply nonlinear (drydown mortality a_dG1·exp(−a_dG2·r), a_dG2 = 20: a 1e-3
  relative change in reserves is 2% in rate). The drop map's field part was measured at
  0.85–1.10× the true move (`in-run-signals.md` §4 D). So first order suffices to ~10–15%
  [i].
- Reach: only regions with nodes to drop. A single interval (an opening strip on the gap
  chord, a spell's first interval) has none; its error is not an h-ladder of existing nodes
  and the estimator cannot see it.

**Run plan (the one scratch build: libS + node_drop.patch → `dwr/build/lib`).**
- A: map replay of res dry, pinned to `cl_res_dry` (reproduces J), drops = every other node
  of the founders, of each spell's interior run, of late, and res2x's dropped closing
  offsets (so the closing virtual move is res → res2x, which was run). SWEEP0=1 times the
  plain sweep in the same process.
- B: map replay of I2 dry, pinned to `p5_I2_dry`, COARSE = res: the virtual move I2 → res,
  which was run; tests first order without Richardson.
- C (if A and B read): drop1 on res with the interiors' drop at 1, pinned, with a full
  sweep: the field part of the interiors' virtual move in all 50 elasticities from one
  extra run.

## Pre-registration P (before the build's guard and runs A, B)

| # | prediction | P |
|---|---|---|
| P0 | A and B reproduce the saved runs' J and all 50 trait gradients `identical()` | 85% |
| P1 | B's field part (I2 → res) within ×[0.85, 1.15] of the measured field part of res − I2 (`split.R`) | 65% |
| P1b | B's D (own + field) within ±0.04ε of the measured res − I2 in ln J (−0.17) | 65% |
| P2 | A's interiors: e_I = D_I/3 < 0 | 85% |
| P2′ | e_I within ×[0.67, 1.5] of the measured −0.22 | 50% |
| P2b | A's interiors: own > 0, field < 0, \|field\| > 3\|own\| | 60% |
| P3 | A's founders: e_F > 0 | 80% |
| P3′ | e_F within ×[0.67, 1.5] of the measured +0.10 | 50% |
| P3b | founders' own part positive and larger than \|field\| | 65% |
| P4 | closing (res → res2x virtual): \|D_C\| ≤ 0.05ε and within 0.03ε of the measured res2x − res (−0.006) | 70% |
| P5 | late: \|e_L\| ≤ 0.05 | 80% |
| P6 | era Ia (b1–10) carries ≥ 50% of the interiors' field part | 65% |
| P7 | interiors' field part light-dominated (\|Σ light\| > \|Σ soil\|) | 50% |
| P7′ | founders' field part soil-dominated | 65% |
| P8 | ≥ 50% of the interiors' field part from bands t ≥ 10 y | 50% |
| P9 | A's map sweep ≤ 1.25× the plain sweep in the same process | 70% |
| P10 | e_F + e_I + e_L + e_C + measured (Os + O1 + B) within ±0.06 of e_res ln J (−0.08) | 45% |

Reasons [i]: P1 from the drop map's 0.85–1.10; P2′ is a coin because 140 d interiors may be
pre-asymptotic (the measured 70 → 35 → 18 d ladder ratio is 4.3–4.8, the 140 → 70 d one is
unknown); P3 founders' fates are smooth exponentials with h/L ≈ 0.1–0.3 at 2h; P7 because
p50 found the soil layers equal to 1e-5 (pointing to light) while the uptake differed by
0.01% through drainage.
