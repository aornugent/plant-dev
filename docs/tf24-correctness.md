# TF24 forward-model correctness: the prerequisites

Phase 0 of [`build-plan.md`](build-plan.md), separated because none of it is AD work.
These are defects and undecided questions in TF24's forward model on develop
`141dc8df`. They are prerequisites for two different reasons, and the distinction
matters when scheduling them:

- **P0.1–P0.4 block the engine**, because the design's own acceptance test is
  "re-run one cohort's rates from its boundary and compare bit for bit", and on develop
  that fails for reasons unrelated to gradients.
- **P0.5–P0.6 block TF24's phase only**, because you cannot decide which switches to
  mollify before you know which ones fire, and you cannot FD-verify against numbers
  the owner may change.

Every item's mechanism, measurement and provenance is in
[`reports/07-tf24-develop-audit.md`](reports/07-tf24-develop-audit.md). This file is
the work list, not the argument. Probes: `scripts/leaf_state_carryover.R`,
`scripts/uncounted_switches.R`.

---

## P0.1 — `soil_consumption_` carries over between cohorts

**One line.** `Leaf::set_physiology` calls

```cpp
soil_consumption_.resize(soil_number_of_depths_, 0.0);
```

where it needs `.assign`. `resize`'s fill argument applies only to newly added
elements. `E_from_Soil_to_Root_Collar`'s loop then runs to `max_soil_layer`, not to
`soil_number_of_depths`, so every layer a plant has no roots in is neither written this
solve nor cleared — and `TF24_Strategy::compute_rates` bills all of them to the patch
water balance. The `Leaf` is shared across every cohort of a species through the
`Strategy` `shared_ptr`, so the inherited values are the previous cohort's.

Two lines above, the sibling buffers use `.assign(max_soil_layer, 0.0)`. The file is
inconsistent with itself by one call.

**Measured.** A 20 m tree then a 0.4 m seedling on the same leaf: the seedling's
layers 3–5 are bit-identical to the tree's. Solve seedling → tree → seedling and the
two seedling records differ. On a production run (`max_patch_lifetime = 105.32`,
10 153 cohort-time records) **33.78%** carry at least one stale layer and **25.73%**
carry three of five.

Worse than "the neighbour": `Node::compute_rates` runs `growth_rate_gradient` *after*
`individual.compute_rates`, and that finite-differences growth by re-solving the shared
`Leaf` at `height + eps`. What a cohort inherits is the previous cohort's **FD probe at
a perturbed height**.

**Gate.** The seedling's deep layers read 0 on a leaf that solved a tree first, and
`solve(seedling); solve(tree); solve(seedling)` is bit-identical. Re-bless TF24
baselines and record the shift.

**Also do.** Assert the invariant rather than restoring it by hand:
`soil_consumption_` is sized and cleared by the one statement that knows its length.
Report 01 §11 step 4's second bullet — "give the `Leaf`'s per-solve fields an explicit
boundary from its parameters, so *what `set_physiology` must re-seat* is a structural
fact rather than a list someone maintains" — is listed there as optional. It is not.

---

## P0.2 — the shut-down exits leave the leaf's uptake untouched

**Three lines.** `set_shutdown_state(root_collar)` sets `root_collar_psi_`,
`opt_psi_stem_` and `profit_`, and neither `soil_consumption_` nor `E_up_`. Three of
`prepare_collar_solve`'s early exits call it, leaving three different wrong states:

| exit | what `soil_consumption_` holds |
|---|---|
| `-wettest_soil_layer >= psi_crit` | the previous cohort's values — `E_from_Soil_to_Root_Collar` is not called at all |
| `E_column(-psi_crit, ...) < 0` | uptake at `-psi_crit`, not at the shut-down point |
| `-root_crit >= psi_crit` | the **last trial iterate of the TOMS748 root-find** inside `find_root_psi` |

A shut-down plant transpires nothing; the correct value is zero in all three.

**Measured.** A wet 20 m tree, then the identical tree with every layer drier than
`psi_crit`: `E_up_` and `soil_consumption_` are unchanged from the wet solve. The same
dry solve on a fresh leaf reports `NA`, so the value is entirely a function of what ran
before it.

**Incidence: zero at the default driver** (0 of 10 153; minimum margin to the shut-down
branch 0.02688 MPa = 27× `GSS_tol_abs`). Reached by the committed rainfall
sequences, which is where a water-balance error matters most.

The `assim_max_ < 0` exit does call `E_from_Soil_to_Root_Collar` at its own operating
point and is already correct — it shows the intended shape.

**Gate.** A shut-down solve reports zero uptake regardless of what ran before.

---

## P0.3 — `soil_moist_from_psi` omits the Pa→MPa factor

**One line plus a test.** `psi_from_soil_moist` divides by `1e6`; its inverse does not
multiply by it, so the result is scaled by `1e6^(1/n_psi) = 10^(6/6.57) = 8.19`.

**Measured.** `theta 0.3000 -> psi 1.837887e-02 -> theta 2.456763e+00`. The ratio
2.456763/0.30 = **8.189**, exactly as predicted; the returned moisture also exceeds
saturation (0.428), which is the tell.

Called by no C++ code and covered by no test — it is an R-facing utility only, so this
is not a simulation defect. It is worse in one specific way: it is the natural function
to reach for when converting a critical potential into a moisture threshold, so any
recorded figure of that kind is wrong by 8.19×, so re-derive any moisture threshold that
came through it.

**Gate.** `soil_moist_from_psi(psi_from_soil_moist(θ)) == θ` to 1e-12 for θ in
(θ_r, θ_sat], and the round trip is a committed test. A property check is the right
shape here: it would have caught this the day it was written.

---

## P0.4 — the resource vector is sized by ODE width, not resource count

`Individual::compute_rates` sizes `consumption_rates` to `environment.ode_size()` = 9
(five soil layers plus four diagnostic flux accumulators). `Internals::resize` fills
with `NA_REAL`. `TF24_Strategy::compute_rates` writes slots 0–4. `Patch::compute_rates`
then accumulates all nine, so slots 5–8 trapezium-integrate `NA_REAL` into `NaN`,
divide by `area`, and are discarded unread by `TF24_Environment::compute_rates`.

Read directly from the code, not measured — no R-facing route reaches
`Internals::consumption_rates`.

Latent today; live the moment anything sweeps that vector for finiteness, and under AD
it puts four NaNs on the tape per stage. The mismatch is structural: the vector is
sized by the environment's **ODE width** when what it means is the environment's
**number of consumable resources**.

**Gate.** No `NA_REAL` reaches `resource_depletion`. Prefer giving the environment an
explicit `n_resources()` over shrinking the vector by hand — the count should have one
source of truth.

---

## P0.5 — the switch inventory

**The one item specified in four places and produced in none.** Every clamp, floor,
`min`/`max`, ternary and branch on a computed value on TF24's carbon, water,
**demographic and field-reduction** paths, each classified (selector / kink / guard /
*the operation is itself a derivative*) and each carrying a **measured incidence**.

The first table is the carbon and water paths, which are two thirds measured. The second
is the demographic and field-reduction paths, read directly from the container headers,
all uncounted — they were outside every report's scope because no report starts from
`Node`, `Species` or `Patch`.

### Carbon and water

| construct | incidence | source |
|---|---|---|
| `max(S, 0)` on storage | **13.96%** of records; storage genuinely goes negative (min −2.249e-03 vs median 1.756e-04), so the `dS/dt` comment's claim that the outflow gate "floors storage at zero" does not hold | report 06 §9b |
| `net_mass_production_dt <= 0` | **14.04%** — but *not* a discontinuity count, since `P_pos` smooths it | report 06 §9b |
| `max(light, 1e-4)` | **4.638%** of 41 460 light-spline knot values at or below the floor; 8.22% below 1e-3 | report 07 §1.8 |
| `max(0.0, spline(height))` undershoot guard | firing — the field's minimum is **exactly 0** | report 07 §1.8 |
| `Species::consumption_rate`'s `size() < 2` | **0.70%** of output times, and it is the *first* one | report 07 §1.7 |
| the three shut-down exits | **0%** at the default driver; minimum margin 27× `GSS_tol_abs` | report 06 §9 |
| the **interior / bound-pinned** operating-point selector | **15 of 52** states across the argmax's whole feasible domain, all at `psi_soil ≥ 1.5 MPa` and `height ≥ 2 m`. None inside the default driver's range; the committed rainfall sequences reach it | `scripts/curvature_probe.R` |
| the zero-flux `psi_upstream >= psi_stem` branch | **0%**; the jump across it is exactly `R_d` | report 06, report 07 |
| `E_up_ < 0` (hydraulic redistribution) | **never** | report 06 §9 |
| `rooting_depth = min(height, 1.5)` | crossed by **every** cohort, once, early — so the channel is correctly dead for production-size plants | report 07 |
| soil positivity guard, conductivity floor, retention floor, `soil_psi_max_` | the guard is NaN-safe on develop (`!(rate > 0.0)`); reachability argued from `K ∝ θ^16.14` but the drier-driver case is open | report 06, open-item 58 |

### Demographic and field reduction

Read directly from develop's container headers. Every one is on the census gradient's
path, because a census metric is `sum_k n_k psi(state_k)` with `n_k = exp(l_k)`, and
none is counted.

| construct | where | what it decides |
|---|---|---|
| `Species::height_max()` returns `nodes.front().height()`, **not a max** | `species.h:167` | it relies on the descending-height invariant, so within a species the derivative is 1 for the first node unconditionally and there is no tie. The `max` — and the tie — exist only **across** species in `Patch::height_max` (`patch.h:424`). This is a cheaper selector than report 03 §1b assumes, and single-species runs have no selector at all |
| `if (size() == 1 \|\| f_h1 > 0)` | `species.h:220` | whether the boundary node's trapezium interval enters the light field. A branch on a computed competition value that changes how many terms the field reduction contains |
| `if (h0 < height) break;` | `species.h:215` | where the descending sweep stops. The term count of the field reduction is state-dependent, which is the same class as an adaptive knot count |
| `new_node.height()` as the field trapezium's **lower integration limit** | `species.h:221` | a moving integration bound in the field reduction itself, equal to `height_0` and therefore trait-dependent through `height_seed`. Not a switch; listed here because it is the other thing that sweep reads which is not ODE state |
| `!util::is_finite(survival_individual)` → `0.0` | `node.h:144-150` | zeroes the whole fecundity rate, hence offspring and R0, when `exp(-mortality)` underflows. A switch on a state, whose active set grows monotonically through a run |
| `!util::is_finite(log_density)` → `log_density_dt = 0.0` | `node.h:182-185` | at introduction, when `g <= 0` makes `log_density` `-Inf`. Zeroes the newborn's transport rate |
| `g > 0 ? log(birth_rate * pr_estab / g) : log(0.0)` | `node.h:177` | the inflow boundary condition itself. `-Inf` on the closed side |
| `mortality_dt`'s `is_finite(cumulative_mortality)` | `tf24_strategy.cpp` | already on the "still to count" list below; recorded here too because it is the switch that feeds the two above |
| `Patch::check_finite_ode_state()` | `patch.h:693` | a hard stop rather than a branch, so it has no derivative — but it defines the domain the gradient is valid on, and a finite-difference verification step that crosses it fails loudly rather than quietly. Worth a row so that is on purpose |
| `size() > 0 & !is_mutant_run` | `patch.h:568` | whether the field is rebuilt at all. Also a bitwise `&` on two bools, which is a wart rather than a hazard |
| `consumption_rates` sized `NA_REAL` to ODE width | P0.4 | four NaNs per cohort per stage reach `resource_depletion`. Under a reverse sweep `NaN * 0` is `NaN`, so this poisons the adjoint rather than staying latent. **Promote P0.4 to the same tier as P0.1** |

**Still to count**: the root vulnerability curve's domain edge (beyond its fitted
domain `root_vuln_from_psi` extrapolates **negative** → negative conductivity →
negative-but-finite `r_R` → wrong-sign `E_i` that the `isfinite(E_up_)` net cannot
catch; guarded in one of three branches); the `prev_q == 0` exact-double break in the
root-distribution loop; `mortality_dt`'s `is_finite(cumulative_mortality)` switch; and
`establishment_probability`'s gate (P0.6).

**Gate.** Every row has an incidence number. A row with nonzero incidence and no
recorded derivative treatment is a missing constraint, and that is exactly what the
manifest is for.

---

## P0.6 — two ecology decisions, for the hydraulics owner

Neither is ours to make. Both change every simulated number, so both want a
`scientific_version` bump.

### Leaf dark respiration is subtracted twice

`Leaf::assim_colimited` ends in `- R_d_`, so `profit_` is net of dark respiration.
`net_mass_production_dt` then subtracts `pars.r_l * mass_leaf` — leaf dark respiration
again.

| term, per m² leaf per year | kg dry mass |
|---|---|
| inside `profit_`, as `R_d_ = vcmax_ · 0.015` | **0.389407** |
| again, as `r_l · mass_leaf` | **0.673481** |
| leaf respiration counted | **1.578×** |

The provenance is visible in the same forty lines: TF24 was scaffolded from FF16, whose
`assimilation_leaf` is a **gross** light-response hyperbola where `r_l` is the only leaf
respiration and is correct. The Farquhar leaf replaced it and `r_l` stayed. The dead
FF16 code is still in the file, carrying the comment
`(!!not in use for TF24 model!!)`, with its call site commented out and `a_p1`/`a_p2`
still live entries of `TF24_Pars`.

**The one way this dissolves**: if `r_l`'s 39.27 was calibrated against a model that
already netted out `R_d_`, the pair is right and only the naming is wrong. That is a
question about the parameterisation's provenance, not about the code.

Two neighbours want the same conversation: the hydraulic cost sits inside the term
multiplied by `a_bio · a_y`, so hydraulic risk is discounted by the 0.7
growth-conversion efficiency as though it were assimilated carbon; and
`root_mass_carbon_scale = 83.26 · 0.5` is an unexplained factor of 41.63 converting
fine-root mass into the units the root hydraulic network expects, flagged `TODO` and
never resolved.

### `establishment_probability`'s hard gate

```cpp
if (net_mass_production_dt_ > 0) { ... } else { return 0.0; }
```

The last hard, un-smoothed switch on TF24's carbon path, and it sits on every census
metric's gradient through the recruitment channel. A zero derivative may be exactly
what the model means at the carbon compensation point — the point is that it should be
a recorded decision rather than an artefact of writing an `if`. develop already has
both the precedent (`P_pos`) and the method for sizing a smoothing scale against data
(`storage_prod_eps`, measured well-sized).

---

## P0.7 — `q(z, height)` divides by `z`

`q(z, h) = 2η(1 − u^η)u^η / z` with `u = (z/h)^η`. The division makes `q(0, h)` a `0/0`, so
it is **NaN for every height**, not only at `h = 0` — measured. The light field's lowest knot
is exactly `z = 0` (`construct_spline` sets `lower_bound = 0.0`), so the first consumer to ask
the field for a slope at the ground meets it. Nothing reads the field's slope today, which is
why the defect is latent.

Writing `q` over `u^(η−1)/h` rather than `u^η/z` — the two are equal for `z > 0` — is finite
there and removes a division from the hot path. The `u → 0` limit is 0 for every `η > 1` and
`1/h` at `η = 1`, resolved once alongside the other `η` precomputation.

Separately at the same knot: `d/dη` of `0^η` is `0^η log 0` = NaN, which bites once `η` is a
differentiation target. At `z = 0` a cohort contributes its full amplitude with `u = 0` and no
`pow` is needed, so the fix is a guard rather than a reformulation.

**A zero-height cohort is not the concern.** `height_0 = 0.344195 m` (measured), so `h = 0`
is unreachable through introduction, and `growth_rate_gradient`'s `1e-6` probe is far from it.

**Gate.** `q(0, h)` finite for every `h`, and both sites carry a test.

---

## Housekeeping — batchable, no gate

Small, none changes a number. Worth one PR together.

- The `assimilation` aux name is declared, allocated, reported to R and **written
  nowhere** — exactly `0` on all 10 153 records. Either write it (`assimilation_` is
  computed one line above the return in `net_mass_production_dt`) or delete the name.
- `TF24_Strategy::compute_roots` is declared (`tf24_strategy.h:208`) and never defined,
  never called, absent from the yml — a link error waiting for its first caller.
- `TF24_Environment`'s constructor argument
  `light_availability_spline_rescale_usually` is ignored: the initialiser list does not
  use it and the body hard-codes `true`. The member that would hold it,
  `canopy_rescale_usually`, is declared, never assigned, never read. **Family-wide** —
  FF16 and K93 do the same.
- A dead local in that constructor: `ExtrinsicDrivers extrinsic_drivers;` constructs and
  discards a local while the calls that follow act on the base member.
- `Leaf::profit_psi_stem_Sperry` is exported and always `NA` — `lambda_` is set to
  `NA_REAL` in `setup_clean_leaf` and assigned nowhere else. Either fix it or unexport
  the Sperry path. (`hydraulic_cost_Sperry`, `optimise_psi_stem_Sperry`,
  `transpiration_full_integration` and the Medlyn block are also exported and off the
  compute path, but merely unused rather than wrong.)
- `environment.depth` is an R-settable field that the rooting cap does not read:
  `rooting_depth_max = 1.5` is a file-static in `tf24_strategy.cpp`. Setting
  `depth <- 3.0` gives a column whose two deepest layers no plant of any height can
  root into, silently.
- `Leaf::dz_ = soil_depth_.back()/soil_number_of_depths_` re-derives a thickness the
  environment already holds in `dz[]`, and is correct only for a uniform grid.
- `Leaf::electron_transport()` declares a local shadowing the member it computes and
  relies on the caller assigning the return value.

---

## TF24f

Separate from the above because TF24f is not on the deliverable's critical path, and
because its recorded blocker needs re-diagnosing before either of its backlog items is
worth picking up.

**Its per-individual R API is silently wrong.** `solve_leaf` evaluates the leaf at the
tracked collar state, which an `Individual` constructed from R has never had seeded, so
it is `0` and clamps to `bound_a` — the zero-uptake end of the feasible interval.
Measured, open sky and wet soil:

| | `net_mass_production_dt` | `establishment_probability` |
|---|---|---|
| TF24 | +3.053802e-04 | 0.9984355 |
| TF24f | **−1.367946e-04** | **0** |

A sign flip on production, and establishment exactly zero because P0.6's hard gate
closes.

**The SCM path is correct, and only by ordering**: `Node::compute_initial_conditions`
calls `set_initial_states` (which runs the base optimiser through the `initializing_`
flag), then `compute_rates`, then `establishment_probability`. So
`test-strategy-tf24f.R`'s assertion that offspring production is finite and positive
passes and the model is usable through `run_scm`.

**What this changes.** `plant#61` records TF24f aborting on hard scenarios at its
shipped `k_acclim = 1` "because the tracked potential leaves the feasible leaf-solve
domain". That mechanism is real, but there is a second one in the same area: the
tracked state's *default* is outside the domain, and the clamp that rescues the value
path is the same clamp that makes the gradient point out of it. Settle whether
`plant#61` is one problem or two before closing the 2.9e-4 tracked-collar residual or
folding the tracked collar into the leaf's boundary.
