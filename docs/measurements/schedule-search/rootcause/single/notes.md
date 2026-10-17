# Every elasticity's node error, by region, from one run

Subject: can ONE TF24 gradient run return, beside J and its gradient, each region's
node-schedule error in every elasticity (founders, interiors by era, late), without a
second run? Every prediction is written here, with a probability, before the run or
analysis it concerns. Scripts and the patch are in this directory; outputs in
`scratchpad/deep/rootcause/single/` (`build/`, `runs/`, `logs/`, `sched/`). **[m]**
measured, **[i]** inferred (derivation, reading or estimate). Errors and moves are in ε of
each quantity, against the lib19-class reference (`rootcause/common.R`).

## Summary (written last)

**The question.** A region's error in an elasticity is ∂/∂θ of its ln J error: a mixed
second derivative. It splits into T2 (the field change's own θ-dependence at fixed
trajectory), T1 (the trajectory's curvature: the field change moves the states, and with
them every step's Jacobian) and own′ (the merged-weight census's θ-derivative). Each route
was tested by its finite-difference twin on one scratch build (libS + `dwr/node_drop.patch`
+ `active_drop.patch`: δenv active, merged-weight census flag), against the pinned real
coarsening of the committed run per region (R0) and the measured region errors.

**What works [m]: route 1's twin, A** (forward and sweep with region g's drop applied at
c_g = 1, δenv active, census merged). On all three cases it is R0 to within 0.04ε:
- dry: F cos 1.000 (slope 0.94, worst 0.017), I 0.999 (1.00, 0.006), eras Ia/Ib/Ic 1.000
  each (worst ≤ 0.005), L 1.000; against the measured: F 0.984, I 0.932, L 0.973 (the same
  as R0's own 0.985 / 0.935 / 0.971).
- dry-flat: F 0.998 (0.93), I 0.985 (0.94); measured F 0.975, I 0.838 (R0 0.824: the
  every-other drop set's interiors read −0.17 in ln J against the ladder's −0.09).
- episodic-lma: F 1.000 (1.03), I 1.000 (0.98), L 0.998 (1.16); measured F 0.996.
- Errors add over regions (dry: R0 with every region dropped equals the sum of R0 by
  region, cos 1.000, rms 0.002ε) and over eras (A: 2.7%).
- Route 1 itself returns the derivative at c = 0. A at c = 0.5 puts that at cos 0.975
  (F, worst 0.15ε) and 0.996 (I, worst 0.03ε) against R0 [i]: linear in c for the
  interiors (3.7%), less for the founders (12.6%).

**What fails [m]: the sweep-only route (adjoint over a tangent confined to each step).**
Its twin B (one sweep over the run's own rows with the drop at c = 1) is linear and
additive, and wrong: F cos −0.53 / −0.17 / 0.80, I 0.47 / 0.74 / 0.96 with slopes 0.07–0.15
(B reads a_l1 +1.27 in Ia against +0.32). Re-solving every leaf in the sweep (B′) changes
nothing (−0.59, 0.43). So the missing term is T1, the trajectory's curvature, as large as
the answer: the tangent in c must ride the forward. The dwr round's passive drop1 failed
for the other half (T2's ∂δenv/∂θ).

**Cost, per run, in gradient runs [m unless marked].**
- R0 (works, all orders, no code change): 0.76–0.98 per region (its rows). Dry F + Ia + Ib
  + Ic + L: 4.74 beyond the run; F + I + L: 2.71.
- A (works): 0.99–1.12 per region, so dominated by R0.
- Route 1, all regions in one run [i, from measured rate costs: tangent width 1 1.66×,
  width 5 3.39×, adjoint record + sweep 6.15× a double evaluation]: G = 5 ≈ 3.4–5.4 gradient
  runs including the run's own J and gradient, i.e. 2.4–4.4 beyond it against R0's 4.74;
  G = 3 ≈ 1.5–2.6 beyond against R0's 2.71. A saving of 10–40%, not a different order.
- The node-drop map with δenv active costs 1.11–1.20× a plain sweep (passive: 1.05).

**Verdict [i].** One run cannot give the elasticities' region errors at a gradient run's
cost: the needed term T1 exists only in a tangent carried through the forward. A nested run
(route 1, adjoint over a width-G tangent in c) can give all regions at once with the
accuracy A shows, for 2.4–4.4 gradient runs beyond the run at G = 5. Today the cheapest
honest route is R0: one pinned coarsening per region on the run's own steps, 0.8–1.0 each,
exact, and no code change; since the regions add, a loop that already runs the
all-regions coarsening as its pair's coarse member needs only G − 1 more for the split.

**What a production route 1 changes [i, code].**
- odelia: the adjoint machinery templated on the inner scalar instead of
  `active_scalar<double>` / `adjoint_tape<double>` (adjoint.hpp `active_system`,
  `sweep_each_seed`, `vector_jacobian_product`, `state_and_parameter_adjoints`; ode_step.hpp
  `step_adjoint`; ode_solver.hpp `solve_adjoint`, `sweep_range`; plant scm.h's census rows),
  with XAD's `fwd_adj<double, G>` and `adjoint_rows` carrying G + 1 numbers per entry; the
  forward run at `fwd<double, G>` (Patch already compiles there) keeping rows with
  tangents; the insertion map transposed at that scalar.
- The supplied-derivative sites: `record_with_derivatives` pushes double multipliers, so
  at AReal<FReal> each supplied row must carry its own c-tangent (the kernel at a tangent of
  a tangent, which odelia allows): `implicit_value` (leaf optimum), tf24_strategy.h's
  `record_with_derivatives`, the leaf kernels. The recorded leaf point (`leaf_solved_point`)
  needs its collar's tangent too, or the sweep's replayed leaf ignores the field change.
- plant: this spike's active δenv (`shares_around`, `drop_crowns`, `drop_uptake`, the
  light's prefix moments) and the merged-weight census (`drop_census`), with c_g as tangent
  seeds rather than parameters; only doubles cross to R (J, gradient, the G × 50 mixed
  block).

**Not covered: the edge strips.** An opening strip or a spell's first interval has no node
to drop. A strip diagnostic needs a virtual insertion, not a drop: a probe node per strip at
the fixed offset, integrated in the run's field without feedback (as an invader), whose
leaf area and uptake give the strip's δenv for a split interval and whose fate gives the
own part; then the same c-tangent (or an A-type pass) for its elasticities. Or a real
pinned run with the strip nodes moved by a quarter offset (R0's insertion twin).

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

One scratch build (deleted after the runs; `build/*.log` kept): libS + `dwr/node_drop.patch` + `active_drop.patch` (here): δenv and
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

## Results, in run order

### Build and drop sets [m]
- `single/build/lib` = libS source + `dwr/node_drop.patch` + `active_drop.patch`, built
  22:36–22:40 UTC (`-O2`, R's default flags), odelia and phylloptim linked from
  `summing/build/lib0` (= libS).
- `mk_regions.R` (mk_drop2's rule) on the committed runs: dry 149 nodes, 39 dropped (F 8,
  Ia 9, Ib 9, Ic 7, L 6; the same set as dwr's c); dry-flat 191, 29 dropped (F 8, Ia 7,
  Ib 10, Ic 3, L 1); episodic-lma 120, 42 dropped (F 9, Ia 10, Ib 12, Ic 6, L 5).

### Dry: S, A, R0 (`score.R dry`; `score_dry.rds`) [m]

Guard: the S forward reproduces the saved J, its c = 0 map sweep the saved 50 trait columns,
`identical()`; the map's light and soil columns are `identical()` to dwr's `map_c_dry`
(the active δenv changes no column at c = 0). **G0, G1 hold.**

Each region's error at c's spacing, (move to the coarsening)/3, ε of each quantity:

| region | estimator | truth | cos (46 elasticities) | slope truth/est | worst \|diff\| | rms truth | ln J est / truth |
|---|---|---|---|---|---|---|---|
| F | **A** | R0 | **1.000** | 0.94 | 0.017 | 0.132 | +0.118 / +0.118 |
| F | A | measured (fbis) | 0.984 | 0.94 | 0.096 | 0.135 | +0.118 / +0.102 |
| F | R0 | measured | 0.985 | 1.01 | 0.088 | 0.135 | +0.118 / +0.102 |
| F | B | R0 | **−0.53** | −0.64 | 0.367 | 0.132 | +0.119 / +0.118 |
| I | **A** | R0 | **0.999** | 1.00 | 0.006 | 0.121 | −0.232 / −0.232 |
| I | A | measured (I4 on res) | 0.932 | 1.06 | 0.224 | 0.138 | −0.232 / −0.223 |
| I | R0 | measured | 0.935 | 1.07 | 0.224 | 0.138 | −0.232 / −0.223 |
| I | B | R0 | **0.47** | 0.07 | 1.551 | 0.121 | −0.234 / −0.232 |
| Ia / Ib / Ic | B | R0 | −0.10 / 0.94 / 0.96 | −0.02 / 0.19 / 0.36 | 0.95 / 0.50 / 0.09 | 0.096 / 0.052 / 0.021 | |
| L | B | R0 | 0.90 | 0.49 | 0.059 | 0.018 | −0.011 / −0.011 |
| L | R0 | measured | 0.97 | 1.26 | 0.016 | 0.024 | −0.011 / −0.012 |

Key quantities (root_P50, omega, TF24_cost_scale, stem_c, a_l1, sro, root_c, a):
- F: A −0.04 −0.01 +0.18 −0.18 −0.12 +0.13 −0.01 −0.21; R0 −0.04 −0.01 +0.17 −0.17 −0.11
  +0.13 −0.01 −0.20; measured −0.04 +0.01 +0.09 −0.26 −0.04 +0.12 +0.01 −0.21; B −0.17 −0.01
  +0.06 +0.18 +0.26 −0.09 +0.06 −0.13.
- I: A −0.28 +0.20 +0.17 −0.04 +0.57 +0.01 +0.13 −0.13 (R0 the same to 0.01); measured −0.51
  +0.31 +0.22 −0.11 +0.42 +0.04 +0.22 −0.15. Eras by R0: root_P50 −0.21 / −0.02 / −0.05,
  a_l1 +0.32 / +0.18 / +0.06.

- **A, route 1's finite-difference twin, is the pinned real coarsening to within 0.017ε in
  every quantity** (F, I). So the first-order emulation of a region's coarsening (field
  change active, merged-weight census), differentiated through forward and sweep, is the
  region's elasticity error. A1, A2 hold.
- **B, the sweep-only twin, fails**: F's direction is reversed, the interiors' is 6× too
  large in a_l1/stem_c/root_P50 (Ia a_l1 +1.27 against +0.32). B1, B2, B3 refuted. B is
  linear in c (c = 0.5 gives half to 0.001) and additive over eras (0.009), so this is not
  noise: what B lacks is real. B0, B0′ hold.
- R0 on c matches the measured truth as dwr's R0 on x did (cos 0.985 F, 0.935 I; the I gap
  is R0's/A's root_P50 −0.28 against the I4 ladder's −0.51, ln J agrees). R1 holds.
- Cost (same session, s): base forward 39, plain sweep 126 (gradient run 165); map sweep
  151 (1.20×; K2 holds); B sweeps 127–139 (≤ 1.10×; K1 holds); A forward 41 + sweep 145 =
  186 (1.13 gradient runs; K3 holds); R0 for I 33 + 104 = 137 (0.83, rows 0.83).

### Why B fails: two candidates [i]
B's c = 1 recording reads the base run's stored leaf operating points
(`TF24_Strategy::solve_leaf` replays `recorded.collar`), so the leaf does not move with the
field change, and B also omits T1 (the trajectory's own curvature). Both are O(c), the
size of the signal. A test that separates them: B′, B with the leaf re-solved in the
sweep (a flag that makes `solve_leaf` ignore the recorded point), so its leaf is
consistent with the c = 1 field at the base states. Then A − B′ is T1 alone.

## Pre-registration T (before B′, the half-step A runs, A's eras, and the two other cases)

Build 2 adds `plant::leaf_resolve_on_replay` (default off; `solve_leaf` then ignores the
recorded collar) and its R setter; nothing else changes.

| # | prediction | P |
|---|---|---|
| T0 | dry: the re-solved run's own sweep (B′ at c = 0) gives the saved trait gradient within 1e-6 relative in every column | 70% |
| T1 | dry: B′ against R0, cos ≥ 0.9 for both F and I (then T1 is small and the leaf replay was B's failure) | 40% |
| T1′ | dry: B′ is closer to R0 than B is (rms of the difference), for F and for I | 75% |
| T2 | dry: A at c = 0.5 gives half of A at c = 1, rms of (2·move(0.5) − move(1)) under 5% of rms move(1), for F and for I | 85% |
| T3 | dry: A's eras Ia, Ib, Ic against R0's: cos ≥ 0.95 each, and their sum equals A's I within 5% | 75% |
| T4 | dry-flat and episodic-lma: A against R0, cos ≥ 0.95 and slope in [0.85, 1.15] for F and I | 70% |
| T5 | dry-flat and episodic-lma: A against the measured founders (fbis), cos ≥ 0.9 | 75% |
| T6 | dry-flat: A against the measured interiors (I4 on res), cos ≥ 0.85 | 60% |
| T7 | B fails on both other cases too (cos < 0.9 against R0 for F or I) | 85% |

### Dry: B′, A at half step, A's eras (`score.R dry`) [m]

| region | estimator | truth | cos | slope | worst | ln J est / truth |
|---|---|---|---|---|---|---|
| F | B′ (leaf re-solved) | R0 | −0.59 | −0.72 | 0.357 | +0.119 / +0.118 |
| I | B′ | R0 | 0.43 | 0.07 | 1.432 | −0.234 / −0.232 |
| F | 2 × A(c = 0.5) | R0 | 0.995 | 1.01 | 0.083 | +0.119 / +0.118 |
| I | 2 × A(c = 0.5) | R0 | 0.998 | 1.02 | 0.016 | −0.232 / −0.232 |
| Ia / Ib / Ic | A | R0 | 1.000 / 1.000 / 1.000 | 1.02 / 0.99 / 1.00 | 0.005 / 0.002 / 0.001 | |
| L | A | R0 | 1.000 | 1.01 | 0.001 | −0.011 / −0.011 |
| L | A | measured | 0.973 | 1.27 | 0.017 | |

- The re-solved run's own sweep reproduces its gradient `identical()` (the same solver
  from the same state finds the same collar); the sweep costs 156 s against 126. **T0 holds.**
- **B′ is B** (F cos −0.59, I 0.43): the leaf replay was not what B lacked. So T1, the
  trajectory's curvature, is the missing half, and it is as large as the answer and
  opposite to T2 in places. A sweep-only (confined) nested route cannot work: the tangent
  has to ride the forward. **T1 refuted, T1′ refuted** (B′ is no closer than B).
- A is linear in c for the interiors (rms of 2·A(0.5) − A(1) is 3.7% of the move) but less
  so for the founders (12.6%). **T2 holds for I, refuted for F.** Route 1 returns the
  derivative at c = 0, which a quadratic in c puts at 4·A(0.5) − A(1) (moves from the run)
  [i]: against R0 that gives cos 0.975 (F; worst 0.15, a_l1 −0.26 against −0.11) and 0.996
  (I; worst 0.03). A at c = 1 (the drop applied in full) is closer to the real coarsening
  than the derivative is, as it should be: the founders' field change is not small.
- A's eras are R0's eras to 0.005ε and sum to A's I within 2.7%. **T3 holds.**
- Scoring note: the half-step's J had to be J + 0.5·gain (the census coefficient scales
  the gain); first scored with the full gain it read as nonlinear, corrected before this
  table.

## Pre-registration C (before the rate-cost measurement)

Build 3 adds `SCM::rate_cost` (seconds per rate evaluation at the last recorded state,
every leaf solved, at double, at odelia's tangent of width 1, at XAD's `fwd<double, 5>`,
and recorded at the adjoint scalar with one transpose row swept) and its R entry; nothing
else changes. Measured on dry's final state (149 nodes), 20 repetitions.

| # | prediction | P |
|---|---|---|
| C1 | width-1 tangent ≤ 2.0× double | 60% |
| C2 | width-5 tangent ≤ 3.5× double | 55% |
| C3 | adjoint record + one-row sweep ≤ 5× double | 60% |
| C4 | Patch at `fwd<double, 5>` compiles without change (the tangent paths are generic in width) | 60% |

### Dry-flat and episodic-lma: S, A, R0 (`score.R`; `score_dry-flat.rds`, `score_episodic-lma.rds`) [m]

Guards: both S forwards reproduce the saved J, and both c = 0 map sweeps the saved 50 trait
columns, `identical()` (build 2).

| case | region | estimator | truth | cos | slope | worst | ln J est / truth |
|---|---|---|---|---|---|---|---|
| dry-flat | F | **A** | R0 | **0.998** | 0.93 | 0.038 | +0.190 / +0.190 |
| dry-flat | F | A | measured (fbis) | 0.975 | 0.76 | 0.103 | +0.190 / +0.191 |
| dry-flat | F | R0 | measured | 0.983 | 0.83 | 0.087 | |
| dry-flat | I | **A** | R0 | **0.985** | 0.94 | 0.034 | −0.167 / −0.167 |
| dry-flat | I | A | measured (I4 on res) | 0.838 | 0.57 | 0.280 | −0.167 / −0.089 |
| dry-flat | I | R0 | measured | 0.824 | 0.59 | 0.261 | |
| dry-flat | F / I | B | R0 | −0.17 / 0.74 | −0.11 / 0.14 | 0.80 / 1.06 | |
| episodic-lma | F | **A** | R0 | **1.000** | 1.03 | 0.020 | +0.072 / +0.072 |
| episodic-lma | F | A | measured (fbis) | 0.996 | 1.12 | 0.147 | +0.072 / +0.082 |
| episodic-lma | I | **A** | R0 | **1.000** | 0.98 | 0.011 | −0.264 / −0.266 |
| episodic-lma | L | A | R0 | 0.998 | 1.16 | 0.042 | −0.076 / −0.084 |
| episodic-lma | F / I / L | B | R0 | 0.80 / 0.96 / 0.99 | 0.80 / 0.15 / 0.36 | 0.93 / 2.28 / 0.49 | |

dry-flat's late region has one drop and no error (0.000 by A, B, R0). episodic-lma has no
measured interiors (its measured rest holds the edge strips).

- **A reproduces R0 on both** (cos 0.985–1.000, slope 0.93–1.03, worst ≤ 0.042ε). **T4
  holds.** Against the measured founders A reads cos 0.975 / 0.996. **T5 holds.**
- dry-flat's interiors: A and R0 both read ln J −0.17 against the I4 ladder's −0.09, cos
  0.84 / 0.82, slope 0.57 / 0.59. The gap is the every-other drop set's (R0's), not A's:
  dry-flat's 42-d interiors at 84 d are not on the square law, or the drop set's interior
  is not p50's (spell's first interval to c − 36 d). **T6 refuted (0.838).**
- B fails on both (founders' cos −0.17 and 0.80, interiors' slope 0.14–0.15). **T7 holds.**
- dry, R0 with every region dropped at once equals the sum of R0 by region: cos 1.000, rms
  difference 0.002ε, ln J −0.125 both. The regions' errors add.

### Cost [m]

Same process, one gradient run = forward + plain sweep (dry 166 s, dry-flat 370 s under a
heavier machine load, episodic-lma 100 s):

| run | dry | dry-flat | episodic-lma |
|---|---|---|---|
| map sweep / plain sweep (δenv active) | 1.20 | 1.11 | 1.16 |
| B sweep / plain sweep | 1.00–1.10 | 1.02–1.10 | 0.98–1.17 |
| A per region (gradient runs) | 1.06–1.12 | 0.99–1.06 | 1.01–1.11 |
| R0 per region (gradient runs) | F 0.90, Ia 0.95, Ib 0.94, Ic 0.97, I 0.83, L 0.98 | F 0.96, I 0.90, L 1.02 | F 0.87, I 0.76, L 0.97 |

R0's cost follows its rows (0.77–0.99 of the run's): dropping every other node of one
region removes few rows, because the edge and end nodes stay.

### Rate-cost measurement (build 3, `bench_dry`) [m]

Seconds per rate evaluation at dry's last state (149 nodes, every leaf solved), 20
repetitions: double 2.65 ms; tangent width 1 4.41 ms (**1.66×**); `fwd<double, 5>`
8.97 ms (**3.39×**); adjoint record + one-row sweep 16.3 ms (**6.15×**). Patch compiled at
`fwd<double, 5>` with no change. **C1, C2, C4 hold; C3 refuted.**

Route 1's cost from these [i]: forward at width G ≈ 1.66× (G = 1) to 3.4× (G = 5) of the
run's forward; the sweep at AReal<FReal<G>> records at least the tangent's multiple and
reverses FReal multipliers, so 3.4–6× the plain sweep at G = 5. Dry, G = 5 (F, Ia, Ib, Ic,
L): 39 × 3.4 + 126 × (3.4–6) ≈ 560–890 s = 3.4–5.4 gradient runs, the run's own J and
gradient included, so 2.4–4.4 beyond it, against R0's 4.74 for the same five regions. At
G = 3 (F, I, L): ≈ 1.5–2.6 beyond the run against R0's 2.71. So route 1 would save
0.6–0.9× of R0's extra cost, at the price of the generalisation below, and returns the
derivative at c = 0 (founders cos 0.975 by the half-step extrapolation, against R0's
exact 1.000).

## Predictions scored

| # | prediction | P | result |
|---|---|---|---|
| G0 | S forward and c = 0 map sweep reproduce J and trait columns | 85% | holds (`identical()`, all three cases) |
| G1 | map columns equal dwr's within 1e-9 | 85% | holds (`identical()`) |
| B0 | B linear in c (5%) | 80% | holds (0.001) |
| B0′ | B additive over eras (5%) | 80% | holds (0.009) |
| R1 | R0 vs measured, cos ≥ 0.9 for I and F (dry) | 65% | holds (0.935, 0.985) |
| A1 | A vs R0 cos ≥ 0.9, F and I (dry) | 70% | holds (1.000, 0.999) |
| A2 | A vs R0 slope in [0.8, 1.25] | 60% | holds (0.94, 1.00) |
| B1 | B vs R0 interiors cos ≥ 0.9 | 45% | refuted (0.47) |
| B2 | B vs R0 founders cos ≥ 0.9 | 50% | refuted (−0.53) |
| B3 | T1 small: rms(A − B) < 0.3 rms(A) | 40% | refuted (B's error 1.6–6× the answer) |
| K1 | B sweep ≤ 1.3× plain sweep | 60% | holds (≤ 1.17) |
| K2 | map sweep with δenv active ≤ 1.3× | 65% | holds (1.11–1.20) |
| K3 | A's forward ≤ 1.3× the run's | 60% | holds (1.03–1.08) |
| T0 | re-solved sweep at c = 0 gives the gradient within 1e-6 | 70% | holds (`identical()`) |
| T1 | B′ vs R0 cos ≥ 0.9, F and I | 40% | refuted (−0.59, 0.43) |
| T1′ | B′ closer to R0 than B | 75% | refuted (no closer) |
| T2 | A linear in c (5%), F and I | 85% | refuted: I holds (3.7%), F 12.6% |
| T3 | A's eras vs R0 cos ≥ 0.95, sum = I within 5% | 75% | holds (1.000 each; 2.7%) |
| T4 | A vs R0 on dry-flat, episodic-lma: cos ≥ 0.95, slope in [0.85, 1.15] | 70% | holds (0.985–1.000; 0.93–1.03) |
| T5 | A vs measured founders cos ≥ 0.9 there | 75% | holds (0.975, 0.996) |
| T6 | dry-flat A vs measured interiors cos ≥ 0.85 | 60% | refuted (0.838; R0 0.824) |
| T7 | B fails on both other cases | 85% | holds |
| C1 | tangent width 1 ≤ 2× double | 60% | holds (1.66) |
| C2 | tangent width 5 ≤ 3.5× | 55% | holds (3.39) |
| C3 | adjoint record + sweep ≤ 5× | 60% | refuted (6.15) |
| C4 | Patch at fwd<double, 5> compiles unchanged | 60% | holds |

Runs: 33 on the scratch builds, all exit 0 (S ×3, Sr, Sh, A ×14 incl. 2 half-step, R0 ×13
incl. the all-regions one, bench). At most three R processes of this study at a time.
