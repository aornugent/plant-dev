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

## Change of priorities (from the user, before any run)

1. **The locator is a COARSE run's adjoint.** Map the virtual coarsening inside the coarse
   companion (H1's `val_insx_x_dry`: a09 at 1.6× the committed spacing, inset 19.2 d, 110
   nodes against the committed 149, libS, a gradient run, so a pinned replay reproduces
   it). Does its region split transfer to the committed spacing (against the measured
   region errors on dry: p50 on res, the founders' bisections on c)? Is a coarse adjoint
   run cheap enough to matter?
2. **Magnitude per quantity from successive iterations' differences; the coarse map splits
   it.** Does ln J's region split predict the elasticities' split? If not, what cheap
   per-quantity map does?
3. Nested tangents last.

Runs B (I2 → res) and the res map are dropped unless 1 fails for a reason they would
explain. Revised runs:
- **Ax**: map replay of `val_insx_x_dry` (coarse), SWEEP0=1 for the cost.
- **Ac**: map replay of `val_insk_c_dry` (committed): the same split one spacing finer.
- **Cx-I, Cx-F**: drop1 on the coarse run with the interiors' (then the founders') drop at
  1, pinned, with the full sweep: the field part of that region's virtual move in all 50
  elasticities, one coarse gradient run per region.

Regions on an inset schedule (`mk_drop2.R`), by node: every edge's inset node (the node
nearest each edge, both sides) is kept; within each run of nodes between two kept nodes,
every other node is dropped. A drop is labelled founders (b < the inset node before b1),
late (after the last opening edge's inset node), closing zone (within 36 d before a
closing edge) or interior (Ia/Ib/Ic by birth date: before 10, 10–17, 17–25). Opening
strips and spells' first intervals have no node to drop. Scaling to the committed spacing
for an h² region: e_g(c) ≈ e_g(x) / 1.6² [i: every interval of x is 1.6× c's].

### Pre-registration L (before Ax, Ac)

| # | prediction | P |
|---|---|---|
| L0 | Ax and Ac reproduce their saved runs' J and 50 trait gradients `identical()` | 85% |
| L1 | On x, the interiors carry ln J's largest region estimate, and it is negative | 70% |
| L2 | x's interior and founders' estimates /2.56 lie within ×[0.7, 1.4] of c's own estimates (location stable across spacing) | 55% |
| L3 | signs of e_I and e_F at c (from x, /2.56) match the measured (−0.22, +0.10) | 70% |
| L3′ | both within ×[0.67, 1.5] of the measured | 35% |
| L4 | era Ia carries ≥ 50% of the interiors' estimate on x | 60% |
| L5 | the closing zone's virtual estimate on c is not the measured closing error on c (−0.07): differ by > 0.05ε | 55% |
| K1 | the coarse run's rows are ≥ 0.65 of the committed run's (edges keep it from 1/1.6² or 1/1.6) | 80% |
| K2 | a map sweep costs ≤ 1.25× the plain sweep, same process | 70% |

### Pre-registration S (before reading the saved region scores for priority 2)

Already seen (the user's message, p50 summary): interiors ln J −0.22, root_P50 −0.51;
founders ln J +0.10, root_P50 −0.09. So ln J's split already fails root_P50: allocating
the two regions' root_P50 (−0.60) by ln J's split gives the founders +0.50.

| # | prediction | P |
|---|---|---|
| S1 | over dry's region errors on res (F, I, Os, O1, L, B), the cosine between ln J's region vector and each of the 8 key elasticities' region vectors has median \|cos\| < 0.7 | 75% |
| S2 | the cosine between ln J's region vector and the rms-over-elasticities region profile (each region's rms error) is < 0.7 | 65% |

### Pre-registration E (before Cx-I, Cx-F)

| # | prediction | P |
|---|---|---|
| E1 | Cx-I's root_P50 field part, /3 /2.56, is negative and within ×[0.5, 2] of the measured interiors' −0.51 | 50% |
| E2 | cos(Cx-I field vector over the 50 quantities, measured interiors' vector) ≥ 0.8 | 55% |
| E3 | cos(Cx-F field vector, measured founders' vector on c) ≥ 0.6 (the founders' own part, missing here, is a large share) | 40% |
| E4 | the two drop1 vectors are far apart: cos(Cx-I, Cx-F) < 0.5 (a per-quantity map separates the regions where ln J's cannot) | 65% |

## Results, in run order

### Build and drop sets [m]
- `dwr/build/lib` = libS source + `node_drop.patch`, built 02:23–02:4x UTC (`-O2`, R's
  default flags), odelia and phylloptim linked from `summing/build/lib0` (= libS).
- `mk_drop2.R`: x (110 nodes, median interval 85 d): 75 nodes kept at edges and ends, 26
  dropped: F 5, Ia 6, Ib 7, Ic 7, L 1. c (149 nodes, 69 d): 78 kept, 39 dropped: F 8, Ia 9,
  Ib 9, Ic 7, L 6. No closing-zone or gap node is droppable on either (the inset node is
  the only node within 36 d of a closing edge).

### Ax and Ac: the map on the coarse and the committed run (`score_map.R`; `score_x_dry.log`, `score_c_dry.log`) [m]

Guard: both replays reproduce the saved J and all 50 trait columns `identical()`, and the
plain sweep in the same process too. **L0 holds.**

| region | x: own | x: light | x: soil | x: D | x: e = D/3 | x → c: e/2.56 | c: own | c: field | c: e = D/3 | measured (res; F on c) |
|---|---|---|---|---|---|---|---|---|---|---|
| interiors I | +0.267 | +0.544 | −2.412 | −1.601 | −0.534 | **−0.208** | +0.121 | −0.785 | **−0.221** | **−0.22** |
| Ia (b1–10) | +0.178 | +0.355 | −1.267 | −0.733 | −0.245 | −0.096 | +0.094 | −0.468 | −0.125 | −0.14 |
| Ib (10–17) | +0.065 | +0.170 | −0.999 | −0.764 | −0.255 | −0.099 | +0.023 | −0.259 | −0.079 | −0.07 |
| Ic (17–25) | +0.024 | +0.018 | −0.146 | −0.103 | −0.034 | −0.013 | +0.004 | −0.058 | −0.018 | −0.01 |
| founders F | +1.233 | +0.204 | −0.667 | +0.769 | +0.256 | **+0.100** | +0.526 | −0.203 | **+0.108** | **+0.10** (c, fbis) |
| late L | +0.653 | +0.001 | −0.006 | +0.647 | +0.216 (1 drop) | +0.084 | +0.005 | −0.034 | −0.009 | −0.01 |

(ε of ln J. x → c assumes h² and every x interval 1.6× c's.)

- **ln J's region errors are read from one run, on either spacing.** c's own map gives
  interiors −0.221 against −0.22 measured, founders +0.108 against +0.10, the three eras
  −0.125 / −0.079 / −0.018 against −0.14 / −0.07 / −0.01, late −0.009 against −0.01.
- **They transfer from the coarse run.** x's estimates /2.56: interiors −0.208 (0.94× c's),
  founders +0.100 (0.93×). Late does not transfer: x has one late drop over 400+ d
  intervals, whose own part (+0.65 at x) is not h² there.
- **The field part is soil, and late in the run**: the interiors' field is soil −2.41,
  light +0.54 on x (c: −1.02, +0.23); 100% of it acts after t = 10 y (10–20 y 78%). The
  founders' field is soil too (−0.67 against light +0.20), 26–31% of it after 10 y. So the
  over-counted understory's extra uptake is what lowers everyone's fate, to first order,
  even though the layers themselves agree to 1e-5 between res and I4 (p50 R3): the soil's
  adjoint weights water at the moments it is short [i].
- **Cost.** x: 287 292 rows against c's 389 409 (0.74); forward 33 s against 43 s, sweep
  110 s against 145 s, same session. The map adds 5% to a sweep on both (115 / 110, 152 /
  145 s). **K1, K2 hold.**
- First order: the drop1 forward (coarse field applied in full) moves ln J by −1.855ε
  (interiors) and −0.466ε (founders) against the map's −1.868 and −0.463 (0.99×, 1.01×).

### S: ln J's split against the elasticities' (`s_split.R`, `s_split_dry.log`) [m]

| quantity | F | I | Os | O1 | L | B | cos with ln J |
|---|---|---|---|---|---|---|---|
| ln J | +0.10 | −0.22 | +0.06 | −0.02 | −0.01 | +0.01 | 1 |
| root_P50 | −0.09 | −0.51 | −0.14 | −0.05 | +0.03 | +0.03 | +0.70 |
| omega | +0.01 | +0.31 | +0.09 | +0.01 | −0.02 | +0.01 | −0.76 |
| a_l1 | −0.04 | +0.42 | −0.11 | 0.00 | 0.00 | −0.03 | −0.94 |
| stem_c | −0.18 | −0.11 | −0.05 | +0.02 | +0.03 | −0.01 | +0.06 |
| a | −0.21 | −0.15 | +0.03 | −0.03 | +0.02 | +0.03 | +0.23 |

- Median |cos| over the 8 key quantities 0.58, over all 46 elasticities 0.45; 37% reach
  |cos| ≥ 0.7. **S1 holds.** Allocating a quantity's total by ln J's signed split is far
  off, because ln J's regions cancel (their sum −0.08 is a third of the interiors' −0.22):
  root_P50 would get founders +0.80, interiors −1.80 against −0.09, −0.51.
- But **where** the elasticities err is where ln J errs in size: the rms-over-elasticities
  profile (F 0.132, I 0.138, Os 0.036, O1 0.018, L 0.024, B 0.019) has cos 0.94 with |ln J|'s
  profile (−0.32 with signed ln J). **S2 holds as registered (signed), but the unsigned
  reading is the useful one**: |ln J's map| ranks the regions for the elasticities; it
  does not give their signs or directions.

### Cx-I, Cx-F: drop1 with the sweep on the coarse run (`score_drop1.R`, `score_drop1_x_dry.log`) [m]

| | ln J | root_P50 | omega | cost | stem_c | a_l1 | sro | root_c | a | cos with measured |
|---|---|---|---|---|---|---|---|---|---|---|
| interiors, drop1 field /3/2.56 | −0.24 | −0.04 | +0.01 | −0.37 | +0.09 | +0.03 | +0.08 | +0.04 | +0.11 | **−0.11** |
| interiors, measured | −0.22 | −0.51 | +0.31 | +0.22 | −0.11 | +0.42 | +0.04 | +0.22 | −0.15 | |
| founders, drop1 field /3/2.56 | −0.06 | −0.05 | −0.02 | −0.06 | −0.05 | +0.04 | +0.07 | +0.02 | −0.04 | 0.46 |
| founders on c, measured | +0.10 | −0.04 | +0.01 | +0.09 | −0.26 | −0.04 | +0.12 | +0.01 | −0.21 | |

- **E1, E2, E3 refuted; E4 holds** (cos(Cx-I, Cx-F) 0.15, but neither is right).
- Why [code]: the drop's field change is passive (`drop_crowns`, `drop_uptake` return
  doubles: "only a coefficient scaling the gain is differentiated"). So the swept drop1
  run differentiates λ in a field change frozen at the run's θ, and misses
  ∫ λ · dδenv/dθ: how the field error itself moves with the traits. That is the
  mechanism p50 found (the convexity of the understory's leaf area in birth date, set by
  survival and growth traits). The own part's θ-derivative is missing too.

### Pre-registration E′ (before the pinned real coarsenings)

The per-quantity map that keeps every θ-dependence: run the region's coarsening for real on
the coarse run, pinned to x's steps (`run.sh plain`, TIMES = x \ D_g, PIN = x): own, field
and establishment at all orders, every quantity, no step jitter; one coarse gradient run
per region.

| # | prediction | P |
|---|---|---|
| E5 | the pinned x \ D_I run moves ln J within 10% of the map's D_I (−1.601ε) | 70% |
| E6 | its move /3/2.56 has cos ≥ 0.8 with the measured interiors' vector, and root_P50 within ×[0.5, 2] of −0.51 | 50% |
| E7 | the founders' (x \ D_F) move /3/2.56 has cos ≥ 0.7 with the measured founders on c | 50% |

### E′ results: pinned real coarsenings of the coarse run (`score_plain_x_dry.log`) [m]

Both replays took x's 4382 steps with the region's nodes removed (rows 238 394 interiors,
266 149 founders, against x's 287 292; forward 26–29 s).

| | ln J | root_P50 | omega | cost | stem_c | a_l1 | sro | root_c | a | cos, all quantities | slope meas/est |
|---|---|---|---|---|---|---|---|---|---|---|---|
| interiors: (x \ D_I − x)/3/2.56 | −0.22 | −0.48 | +0.32 | +0.18 | −0.06 | +0.47 | +0.01 | +0.22 | −0.10 | **0.96** | 0.98 |
| interiors, measured (res, I4) | −0.22 | −0.51 | +0.31 | +0.22 | −0.11 | +0.42 | +0.04 | +0.22 | −0.15 | | |
| founders: (x \ D_F − x)/3/2.56 | +0.11 | −0.02 | −0.02 | +0.12 | −0.14 | −0.14 | +0.12 | −0.01 | −0.16 | **0.98** (c), 0.98 (res) | 1.22 |
| founders on c, measured (fbis) | +0.10 | −0.04 | +0.01 | +0.09 | −0.26 | −0.04 | +0.12 | +0.01 | −0.21 | | |

- ln J: −1.683ε (interiors) and +0.858ε (founders) against the map's D −1.601 and +0.769
  (1.05×, 1.12×). **E5 holds.** E6 holds (cos 0.96, root_P50 −0.48). E7 holds (cos 0.98).
- So the per-quantity region split comes from the coarse run itself, one pinned coarse
  gradient run per region (rows 0.61–0.68 of the committed run's each), with h² scaling
  to the committed spacing; the two regions' vectors are nearly orthogonal (cos −0.16),
  as measured (0.28).

## Indicators for where to refine (added by the user, before any run they concern)

**Indicator 1, the field integrands' curvature, from one run.** For each node j with its
neighbours kept, the over-count its omission makes in the per-recruit leaf area and uptake
sums: δ_j(t) = (Wsp.first − Wb.first) x_{j−1} + (Wsp.second − Wa.second) x_{j+1} −
(Wb.second + Wa.first) x_j, with the shares of the intervals below (b), above (a) and
spanning (sp) from the stored E, M (`drop_uptake`'s form); x the per-recruit quantity. It is
a weighted second difference in birth date. Two weightings:
- **W, by the environment's adjoints**: exactly the drop map's column for node j (light by
  height through the crowns, uptake by layer), plus its own part. Region value: D_g = own +
  field over g's drops.
- **U, plain**: x_j(t) = LA(h_j(t))·exp(−m_j(t))·patch density at birth (leaf area at
  ground per recruit, LA = (h/a_l1)^(1/a_l2); the same proxy for uptake, which scales with
  leaf area), from every node's state at ~150 recorded times; region value: the time mean
  of |Σ_{j∈g} δ_j(t)| / Σ_j W_j x_j(t).
- **A, plant's old omit-one on fate** (the baseline): |own_g| alone.

Regions on c: F, I, L from the every-other subset (mk_drop2's rule); the edge regions by the
omit-one of their edge nodes (ranking only, not an h² error): O = the nodes after opening
edges in (b1, 25), C = the inset nodes before closing edges in (b1, 25), B = b1's. Measured
region errors: F from fbis on c (ten cases); C as c − res (four cases); I, O = Os + O1, L,
B from p50's runs on res (dry, dry-flat; long-wet I, O); otherwise rest = e_c − F (− C).

**Indicator 2, the per-band source split of an iteration move.** For nested runs C ⊂ P,
the move in the field splits exactly by the birth band whose interpolation changed:
field_P − field_C = Σ over P's added nodes of (their actual contribution − the hat chord of
their neighbours), evaluated in the coarse run's states. Evaluated instead in the fine run's
states it is Σ δ_j over the added nodes, i.e. indicator 1 on the fine run restricted to the
added nodes; the two differ by the field change itself (≈1%, second order) [i]. No nested
pair with several regions refined at once is on disk on libS, so indicator 2 is scored as U
(and W) on c's every-other regions, which is c's own move to c with every other node removed
in every region at once, split by band.

Runs: two omit-one map replays per committed run (odd and even nodes, so drops are never
adjacent), on all ten cases, the odd one keeping the node states (NODEREC). No case outside
the ten has measured region errors on disk, so none is scored.

### Pre-registration I (before the omit-one runs)

| # | prediction | P |
|---|---|---|
| I0 | every replay reproduces its saved J `identical()` | 85% |
| I1 | W's Spearman with \|ln J\|'s measured region errors ≥ 0.6 on dry and on dry-flat | 45% |
| I1′ | W's top region is the measured top for ln J on ≥ 2 of dry, dry-flat, long-wet | 55% |
| I2 | W's Spearman with the elasticities' rms region errors ≥ 0.5 on dry and on dry-flat | 45% |
| I3 | U ranks at least as well as A (mean Spearman over the three p50 cases, both quantities) | 60% |
| I3′ | W ranks at least as well as U (same) | 60% |
| I4 | founders against the rest, ten cases: W picks the larger for ln J on ≥ 7 | 55% |
| I4′ | the same for the elasticities' rms on ≥ 7 | 45% |

## Q3. Routes to the elasticities' region errors, with costs (dry; seconds in this session)

| route | what it gives | cost | status |
|---|---|---|---|
| ln J's map split applied to each quantity | nothing usable: signed split wrong (S); \|ln J\| ranks regions (cos 0.94 with the rms profile) | free | [m] |
| drop1 + sweep, field change passive (as built) | λ's θ-derivative in a frozen field change; misses dδenv/dθ and the own part | one coarse gradient run per region | **refuted** (cos −0.11, 0.46) [m] |
| **pinned real coarsening of the coarse run, per region** | the region's move in all 50 quantities, all orders, no step jitter | one coarse gradient run per region: rows 0.61–0.68 of the committed run's | **works**: cos 0.96 / 0.98, slope 0.98 / 1.22 [m] |
| drop1 with an active field change | first order in the field, all quantities; the own part's θ-derivative still missing | a patch to `drop_crowns`/`drop_uptake` (return active values), then as drop1 | not built: the route above is simpler and exact [i] |
| (a) a tangent inside the adjoint | the mixed second derivative, all regions per direction | odelia refuses a tangent above an adjoint (`tangent.hpp` static_assert); an adjoint above a tangent needs `active_scalar<double>` generalised at 9 sites and second derivatives at the 4 supplied-derivative sites (the leaf optimum's implicit node, the leaf kernels, one TF24 site) | deprioritised [code] |
| (b) 3 directions only | the 3 directions that hold 90% of the error | 2 pinned map replays per direction (central differences of the map in θ): 6 coarse map runs | not run [i] |
| (c) differencing the map across the θ ± δ runs a local analysis makes | the region split's derivative along those moves only | +5% per run that carries the map | not run [i] |
