# What one run can say about its own node error

Phase 1 evidence for replacing the check, a second finer gradient run at 1.55× the
committed one. The question: what does a single TF24 run on the birth-date
coordinate tell us about its own schedule error, now or cheaply?

Tags: **[code]** read from code; **[saved]** measured here from saved `.rds` files
(read-only); **[doc]** a measurement already recorded, cited; **[inferred]** reasoning
that has not been measured.

`P21` = `scratchpad/dev/p21/plant` (branch PLANT-110, head 7ab43139).
`RUNS` = `scratchpad/dev/schedtest/adjmap/runs`.

## 1. plant's original approach: `refine_schedule`

**The loop** [code] (`P21/inst/include/plant/scm.h:879-915`):
- run; flag every node whose combined error exceeds `schedule_eps` (default 1e-3,
  `R/scm_support.R:56`);
- bisect the interval *before* each flagged node (`bisect_flagged_intervals`,
  `scm.h:863-873`);
- repeat up to `schedule_nsteps` times.

**The combined error** [code] (`patch.h:1002-1023`) is, per node, the max of two
indicators. Both are omit-one trapezium errors from `util::local_error_integration`
(`P21/src/util.cpp:76-101`):

    e_i = | ½(y_{i-1}+y_{i+1})(x_{i+1}-x_{i-1}) − [trap(i-1,i) + trap(i,i+1)] | / scal

- This is how much node i changes a trapezium integral: the composite rule with the
  node, against the one-panel rule without it. It is O(h³ y'').
- The end nodes are NA and are never flagged.
- It is unsigned and relative: `scal` is the total.

The two integrals:
1. **Offspring (reproduction) error** (`patch.h:967-977`):
   - x = `node_times()`, the introduction times;
   - y = `weighted_fecundity` = survival-weighted offspring × patch density at birth × S_D
     (`node.h:105-107`);
   - scal = total offspring production of all species;
   - computed once, at the end of the run.
2. **Competition (leaf-area) error** (`species.h:1248-1255`, `patch.h:919-923, 982-997`):
   - x = `quadrature_abscissae()`, which is −height on the height path;
   - y = each node's `compute_competition(0.0)`, its density × leaf area at ground;
   - scal = the patch's total competition at z = 0;
   - sampled after every introduction step (`scm.h:738-741`) and folded into a running
     max per node.

The removed vignette says the same: `git show 67c3e57d^:vignettes/methods/node_spacing.Rmd.orig`,
§ "Monitoring integration accuracy".

**Why it works on the height coordinate** [code + inferred]:
- On the height path a node is born with log density log(birth_rate · pr_estab / g) and
  mortality −log pr_estab (`node.h:318-344`). Its node values y_i therefore already
  carry establishment.
- J on that path *is* `util::trapezium(node_times, weighted_fecundity)`
  (`species.h:979-983`), and the light field is a trapezium in height.
- So omit-one measures the very rule the run takes, coarsened by one node.

**Why it refuses the birth-date coordinate** [code] (`scm.h:876-883`):
- The guard reads: "The refinement indicators are trapezia of node densities, which on
  the birth-date path exclude the establishment probability."
- On that path a node starts at the birth rate with mortality 0 (`node.h:198-202`).
  pr_estab enters only through the establishment weights W_j (`species.h:303-312`).
- J is Σ W_j F_j (`species.h:965-973`), not a trapezium of F.
- The field is built from 8 crowns per interval, spread by the interval's two shares
  (`species.h:329-345`), not from a trapezium of node values.
- So `local_error_integration(node_times, F)` would measure the curvature of a
  per-recruit fate that ignores where recruits establish. A node in a shut gap would
  report spurious error, and the competition indicator would not measure the
  quadrature actually taken.

**What it never measured, on either coordinate** [doc + inferred]:
- Both indicators see only the **own** (interpolation) part of a node's effect. They
  do not see the **field** part: how a coarser node set changes the light and water
  every other member sees.
- On TF24 the field part is as large as the own part and usually of opposite sign
  (§4). A corrected omit-one would therefore still be no error estimate.

## 2. The birth-date coordinate

**What a node is** [code]:
- A node is the cohort born at b_j.
- The interval (b_j, b_{j+1}) carries an exact count: `interval_establishment` E and its
  first moment M, integrated by the ODE while the interval is open (`node.h:60-73`).
- The node's weight is its share of the hat functions on both sides:
  W_j = M_{j−1}/Δ_{j−1} + (E_j − M_j/Δ_j) (`node.h:62-66`, `species.h:303-312`).
- So J = Σ_j W_j F_j = ∫ pr_estab(b) · (I_h F)(b) db. Here I_h F is the piecewise-linear
  interpolant of the per-recruit fate F(b) = nrr(b) · patch_density(b) · S_D.

**What kind of rule that is** [code + inferred]:
- It is **product quadrature**: exact in pr_estab, piecewise linear in fate. The nodes
  are not Gauss points.
- Its own error is ∫ pr (F − I_h F) db ≈ −Σ p̄_i F''_i h_i³/12, which is second order.
  An edge inside an interval costs nothing of its own [doc: `round4/P/notes.md`,
  "The arithmetic"].
- Every population sum has the same form (count × interpolated fate): leaf area
  above z, water drawn per soil layer, census metrics (`species.h:372-377, 1110-1118`).

**J's error has two parts** [doc]:
- The own part: interpolating F between the nodes.
- The field part: F_j itself is wrong, because the field built from the nodes is wrong.
- `field-adjoint-map.md` and `adjmap/scores.md` measure both. On long drought
  u215 → u108, own +0.0151 and field −0.0114 (mostly soil) give D = +0.0037.
- Field is mostly water for the resident, and mostly light for the invader.

**What the elasticities are** [inferred from the above]:
- d ln J/d ln θ = Σ_j (dW_j/dlnθ F_j + W_j dF_j/dlnθ) / J.
- The error of each elasticity is the θ-derivative of J's own + field error. It is
  not a quadrature of J's integrand.
- [doc] `BRIEF.md` items 2 and 5: elasticity errors are sums of both signs that cancel
  about four-fold. Late births act on the founders through the soil.
- [doc] `localised.md:688`: ln J never binds (worst 0.37ε). Leaf and hydraulic
  elasticities bind.

**Edge nodes and the fate curve** [doc: `round4/P/notes.md`]:
- Per-recruit quantities curve within about 10–20 d of each establishment edge, most
  at closing edges.
- A node *at* an edge anchors the hat at the curved end. That is a one-signed,
  second-order bias, about 80% of a09's squared error on dry.
- The 12-day inset removes it. The remaining error then mixes a leaf part that shrinks
  faster than s with a hydraulic strip residual that shrinks at about 0. A pair
  under-reads that residual, and a single run sees neither.

## 3. What a saved run stores

Inspected [saved]: `RUNS/val_ins75_c_dry.rds`, a symlink to `val_insk_c_dry.rds`
(dry, 149 nodes, tol 1e-4).

| field | content | error-relevant? |
|---|---|---|
| `stand$J`, `$gradient`, `$elasticity` | totals and 50 trait columns | no per-node split |
| `stand$nodes$birth`, `$establishment` (W_j, length m+1 with the boundary node), `$nrr` (offspring_produced_survival_weighted) | per-node fate F up to patch density and S_D | yes: the own part of anything, exactly |
| `stand$nodes$state` (9×m) | final height, mortality, fecundity, heartwood, storage, nrr, E_j, M_j | E, M give exact merged-interval weights |
| `stand$times`, `$sizes`, `$input_slopes`, `$substep_ends` | accepted step program | time axis only |
| `stand$splits` (per node, e.g. 4–161) | sign-change splits per node | no |
| `stand$rows`, `$cpu`, `sweep_cpu` | cost | no |

Checked [saved]: Σ W_j · nrr_j · patch_density(b_j) is J times a constant
(`harness/node_parts.R::nodes_of`).

**Not stored:**
- `creation`: present only in `harness/run_record.R` outputs (`creation_record`, lines
  165-178), not in the adjmap runs;
- `error_index` / `error_ratio`: the ODE's per-step binding component and its weighted
  error, from `store_trajectory()` (`scm.h:1094-1115`). These measure **time** error,
  not node error;
- per-node gradients or adjoints;
- per-interval field contributions.

Map runs (`RUNS/loc_G*`, `map_*`) also store `$light` and `$soil` (8 time bands × each
dropped node): the field part of each node's removal, as sweep columns.

**`diagnose_scm`** [code] (`P21/R/scm_support.R:125-246`, commit 5a8519fa):
- It is not single-run. It reruns the stand at every other and at every fourth
  introduction, both ends kept, with walks and sweeps.
- It reports `error = (Q − Q_half)/3` and `ratio = (Q_half − Q_quarter)/(Q − Q_half)`
  per quantity.
- It costs about 0.75 of a run.
- Every-other coarsening reads about 3l of the error at lopsided panels
  (`estimate-shortfall.md`).

**What a run could expose cheaply** [code + inferred]:
- *Per-node fate F_j and weights W_j*: already exposed. They give the exact own part of
  any omit-one or drop-every-other move.
- *Per-node adjoint of a node's state at its birth*:
  - The reverse walk passes every insertion row (`scm.h:1465-1480`), but only
    `at_first_state` is returned (`census_gradient.h:50-55`).
  - Recording the adjoint slice at each insertion row is cheap: no rows, only memory.
  - Alone it is a sensitivity, not an error. It needs a defect to contract with,
    which is what the drop map supplies.
- *The drop map* (branch `adjmap-probe`, fa9afe76, not in PLANT-110 head):
  - It adds one coefficient per dropped node and time band, for light and for soil,
    zero in the forward.
  - The sweep returns ∂J/∂c = the field part of that node's removal.
  - Cost: +4–11% of a sweep, no rows, bit-identical with the drop off
    [doc: `adjmap/scores.md`, `field-adjoint-map.md`].
- *Per-node elasticity contributions*:
  - The own part, d/dθ Σ W_j(F_j − interp), is a linear functional of final node
    states. It could be one more census row in the same sweep, but needs a per-node
    weighted metric; `census.h` metrics are per-individual today [inferred].
  - The field part is a second derivative: forward-over-adjoint, central differences
    of the map in θ, or the `drop1` forward (coefficients at 1) followed by a full
    sweep [doc: `design-schedule-building.md:150-153`; `adjmap/adj_run.R` modes].

## 4. Candidate in-run estimators

Own-part numbers measured here [saved] (script
`scratchpad/inrun/own.R`, read-only, on the ten ins75 committed/check pairs). Units:
ε of ln J (0.025). `err` is the committed run against the reference.

| case | err ln J | pair d/(1−s) | own, drop-every-other /3 | own, h³F''/12 | worst elasticity |
|---|---|---|---|---|---|
| episodic | −0.232 | −0.210 | +0.145 | +0.042 | 0.30 |
| dry | −0.148 | −0.128 | +0.182 | +0.196 | 0.35 |
| long-wet | +0.076 | +0.091 | +0.210 | +0.195 | 0.37 |
| long drought | +0.004 | +0.007 | +0.195 | +0.153 | 0.37 |
| episodic-lma | −0.251 | −0.304 | +0.106 | +0.110 | 1.28 |
| dry-flat | +0.057 | +0.134 | +0.315 | +0.325 | 0.58 |
| ld-102 | +0.048 | +0.033 | +0.209 | +0.205 | 0.41 |
| ld-105 | +0.024 | +0.021 | +0.203 | +0.173 | 0.32 |
| dry-p50 | −0.158 | −0.133 | +0.231 | +0.199 | 0.35 |
| wet-adG2 | +0.128 | +0.148 | +0.207 | +0.247 | 0.44 |

What the table shows:
- Correlation with err: pair 0.98, drop-own 0.64, second-difference own 0.69.
- The own part has one sign (positive) on all ten cases and a size of 0.04–0.33ε. The
  true error has both signs: 4 of 10 cases are negative. The field part cancels it.
- This repeats `round4/F/notes.md` Inversion 5 (`inrun.R`): an h³|f''| indicator was
  anti-correlated (−0.45) with the rms error over all quantities, and moved the wrong
  way under trait moves.

| estimator | estimates | needs | status |
|---|---|---|---|
| A. own part from node data: omit-one, drop-every-other, h³F''/12, or a lower-order embedded rule on the same nodes | J's interpolation part only | F_j, W_j, E, M | **stored now, free; not an estimate**: one-signed, misses the field part (above) |
| B. old `refine_schedule` combined error | own parts of offspring and of ground-level leaf area, unsigned, relative | the height path's densities | **refused on birth date** (`scm.h:880`); with W-weights it collapses to A |
| C. pilot proxy Σ nrr^0.6 h³, shut gaps 0 (`any/a04_proxy.R:17-18`) | the ratio s between two schedules, not an error | a pilot | free, but unitless; it needs the second run to give an error |
| D. drop map + own part: D̂ = own + field of the coarsening, err ≈ D̂/3 | **ln J's** node error | adjmap-probe (+328 lines), +4–11% of a sweep | measured, see below |
| E. D on elasticities by central differences of the map in θ (pinned ±1% replays with map) | one elasticity per two replays and sweeps | D, plus 2 runs per trait | measured on 4 trait-records; costs about one check per trait |
| F. `drop1` forward (coarse field to first order) + full sweep, against the plain sweep; plus the own part's θ-gradient as a sweep metric | field part of **every** elasticity's coarsening move, then all of D | one extra gradient run, and a per-node metric | **unbuilt for residents**; invader lma field part 1.02× [doc] |
| G. per-node adjoint at insertion rows | each node's marginal value to J | read the walk at insertions | cheap to add; a sensitivity without a defect; a ranking at most |
| H. ODE `error_ratio` per step, adjoint-weighted Σλ·est | **time** error, not node error | stored per step; λ needs the sweep | proposed (`archive/oracle-response-grid-controller.md:58`), never built |

**D, the drop map, in detail** [doc]:
- *Is the move predicted?* The map predicts the coarsening move D = Q(C) − Q(P).
  - Field part: 0.85–1.10×, every record and grid type.
  - Total: 0.97–1.19× (`adjmap/scores.md` Measure 1; `design-schedule-building.md:186-189`).
- *Is the error read?* D/3 reads P's error only on the square law with central drops.
  - Companions: 0.87–1.21 on uniform u215/u429.
  - 0.19–0.20 on episodic u215 and default d215; −0.57 and −0.98 on placed p108.
  - The field part's coarsening ratio is 1.7–2.5 against the own part's 3.0–3.8,
    mostly in wide late panels (`estimate-shortfall.md`).
- *Where it reads honestly.* Run the map on a bisection B and drop B's midpoints, which
  are central by construction, on edge-aligned grids (square law 3.7–4.2). The ln J
  estimate was then within 0–26% on every pass of every pulsed record
  (`docs/vignettes/node-schedules.Rmd:205-262`).
- *Not measured yet:* the map on inset (P) schedules.
- *What it cannot do:* it measures ln J only, and ln J never binds.
- *Elasticities by E.* On long drought, lma and a_dG2: D̂ 1.04× and 1.03×, companion
  0.99 and 0.94. On episodic, lma's field part is 0.31× (a 0.05ε quantity) and a_dG2's
  D̂ 0.87×.
- *Ranking.* J's map ranks elasticity panels with Spearman 0.87–0.88 but top-10 overlap
  of only 4–6. `localised.md:654-656`: "J's adjoint map … ranks the elasticities'
  edge cost backwards".

## 5. Ranked in-run signals

1. **F**, the drop1 field + own-part sweep metric (all elasticities and ln J, from one
   extra gradient run). It is the only single-run route to the binding quantities. It
   is about 1.0× a run against the check's 1.55×. It is unbuilt and unmeasured for
   residents, and it still needs central drops and the square law.
2. **D**, the drop map on the run itself: ln J only, +4–11% of a sweep, built on
   `adjmap-probe`, measured 0.97–1.19× of the move. It is honest only with central drops
   on square-law grids, and ln J does not bind.
3. **E**, the map differentiated in θ by pinned replays: honest where measured (LD
   1.03–1.05×), but it costs about one check per trait.
4. **G**, per-node adjoints at insertions: cheap to expose, ranking only.
5. **A/B**, own-part indicators: free and stored, but one-signed and blind to the
   field. Dead as estimates, as measured here and in F's Inversion 5.
6. **C**, the proxy: a shrink ratio, not an error.
7. **H**, time error only: off-topic for node error, though free to log.
