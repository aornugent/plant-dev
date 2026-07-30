# TF24 forward-model correctness: the prerequisites

Phase 0 of [`build-plan.md`](build-plan.md), separated because none of it is AD work.
These are defects and undecided questions in TF24's forward model on develop
`141dc8df`. They are prerequisites for two different reasons, and the distinction
matters when scheduling them:

- **P0.1–P0.4, P0.8, P0.9 and P0.10 block the engine**, because the design's own acceptance
  test is "re-run one cohort's rates from its boundary and compare bit for bit", and on
  develop that fails for reasons unrelated to gradients. P0.1 and P0.10 are that claim at
  two strengths. P0.8 and P0.9 are **family-wide** rather than TF24-specific. P0.1 also gates the
  reverse pass's aux carry: restoring a leaf's inputs and operating point reproduces its outputs
  bit-for-bit at 8 of 9 states and the ninth is P0.1 (`scripts/aux_round_trip.R`).
- **P0.5 and P0.6 block TF24's phase only**, because you cannot decide which switches to
  mollify before you know which ones fire, and you cannot FD-verify against numbers
  the owner may change.
- **P0.7 blocks whoever first asks the light field for a slope**, which is P2.2. It is latent
  until then, and it is one line either way. Its derivative sibling is **P0.12**: `q`'s NaN at
  `z = 0` is in the value, and `pow(u, eta)`'s at `u = 0` is only in the derivative, so that one
  stays invisible until `eta` is seeded.
- **P0.11 blocks the reverse pass rather than the forward comparisons.** Two evaluations of one
  function have two adjoints; removing the duplicate is cheaper than remembering to add them.
- **P0.12 gates P1.2b**, which templates TF24: landing it first means one canopy profile is
  templated rather than two.

Every item's mechanism, measurement and provenance is in
[`reports/07-tf24-develop-audit.md`](reports/07-tf24-develop-audit.md). This file is
the work list, not the argument. Probes: `scripts/leaf_state_carryover.R`,
`scripts/uncounted_switches.R`, `scripts/light_floor.R`, `scripts/boundary_node.R`,
`scripts/cohort_spacing.R`, `scripts/aux_round_trip.R`, `scripts/descending_heights.R`,
`scripts/k1_arms.R` with `reports/introduction-k1.patch`, and
the leaf-boundary set `scripts/leaf_bundle.R`, `leaf_waist.R`, `leaf_waist2.R`,
`leaf_waist3.R`, `leaf_translation.R`, `leaf_translation_R.R`, `leaf_uniform_check.R`,
`leaf_recover_a.R`.

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

**It also gates the reverse pass's aux carry, which is a second reason to land it first.**
`scripts/aux_round_trip.R` restores `set_physiology`'s inputs and the stored operating point and
compares 14 leaf outputs: bit-identical at 9 of 9 states on the same leaf, and at 8 of 9 on a fresh
one. The ninth is this defect — a seedling whose layers 3–5 hold the previous solve's uptake, worst
relative difference 1.0 — and the fresh leaf is the one that is right. So until this lands, a leaf's
outputs are not a function of its own inputs and aux, and the reverse pass's rebuild cannot
reproduce the forward pass by restoring them. Any one deeper-rooted prior state is enough to trigger
it, and the cohort loop runs tallest-first.

**The same object has a second undeclared read, and it lands here.**
`dprofit_droot_collar_psi` reads the member `psi_soil_inverted_`, which only
`prepare_collar_solve` refreshes. Change the soil and call it directly and it differentiates
against the previous state's vector: measured, `R` returns `-4.3244858e-07` where the refreshed
value is `0.12438779` — a relative difference of 1, not a drift. It is the same fault as the
stale uptake, one level up: a function whose inputs are partly members, with no statement that
says which. Fix it the same way — the derivative entry point refreshes what it reads, or takes
it as an argument.

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

**The same vector is what the reverse pass needs published.** `Patch::resource_depletion` is a member
rebuilt per `compute_rates` and overwritten by the next stage, and the soil's positivity guard is
closed form in the soil state and that vector — so the sweep cannot recover which rows fired unless the
environment carries its per-layer uptake in aux (`build-plan.md` §2.8). Sizing it by resource count and
publishing it are the same edit at the same site.

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
| `max(S, 0)` on storage | **13.96%** of records; storage genuinely goes negative (min −2.249e-03 vs median 1.756e-04), so the `dS/dt` comment's claim that the outflow gate "floors storage at zero" does not hold | report 00 §9b |
| `net_mass_production_dt <= 0` | **14.04%** — but *not* a discontinuity count, since `P_pos` smooths it | report 00 §9b |
| `max(light, 1e-4)` | **zero. 0 of 8 292 light knot values at or below the floor; minimum 0.1657209** (`../scripts/light_floor.R`). Structural, not lucky: `L = exp(-A)` with `A` the leaf area *above* `z`, so `L` is minimised at the ground, and reaching `1e-4` needs about five times this stand's optical depth. Confirmed independently against `exp(-Patch::compute_competition(z))` over `[0, height_0]` | report 07 §1.8 |
| `height <= cap ? spline(height) : 1.0` | **structurally zero in a resident run.** `cap` is `spline.max()`, set from `Patch::height_max()`, which *is* the tallest cohort's height — so no crown query can exceed it and the tallest cohort's top quadrature point sits exactly at equality, taking the spline arm. Listed because it is a branch on a computed value, and because it is not structurally zero for a mutant taller than every resident | `resource_spline.h:88` |
| `max(0.0, spline(height))` undershoot guard | **zero. No negative knot value.** The guard exists for a cubic undershooting between knots (K93 at high `k_I`); on TF24 at these settings it has nothing to catch | report 07 §1.8 |
| `Species::consumption_rate`'s `size() < 2` | **0.70%** of output times, and it is the *first* one | report 07 §1.7 |
| the three shut-down exits | **0%** at the default driver; minimum margin 27× `GSS_tol_abs` | report 00 §9 |
| the **interior / bound-pinned** operating-point selector | **15 of 52** states across the argmax's whole feasible domain, all at `psi_soil ≥ 1.5 MPa` and `height ≥ 2 m`. None inside the default driver's range; the committed rainfall sequences reach it | `scripts/curvature_probe.R` |
| the zero-flux `psi_upstream >= psi_stem` branch | **0%**; the jump across it is exactly `R_d` | report 00, report 07 |
| `E_up_ < 0` (hydraulic redistribution) | **never** | report 00 §9 |
| `rooting_depth = min(height, 1.5)` | crossed by **every** cohort, once, early — so the channel is correctly dead for production-size plants | report 07 |
| soil positivity guard, conductivity floor, retention floor, `soil_psi_max_` | the guard is NaN-safe on develop (`!(rate > 0.0)`); reachability argued from `K ∝ θ^16.14` but the drier-driver case is open | report 00, open-item 58 |

### Demographic and field reduction

Read directly from develop's container headers. Every one is on the census gradient's
path, because a census metric is `sum_k n_k psi(state_k)` with `n_k = exp(l_k)`.
**Counted** by `scripts/demographic_switches.R`, which needs the counters in
`p0.5-instrumentation.patch` because seven of these are unreachable from R.

**Read the denominator, because three are in play.** 10 153 cohort-time records and 142
output times are the census grid. **35 133 is Runge-Kutta stage evaluations of the
boundary node, not 141 introductions** — `compute_initial_conditions` runs once per
species per stage, 249 times per introduction, and each one is a full
`establishment_probability` and so a full leaf solve at `height_0` on the shared `Leaf`.
The rest are calls of the enclosing C++ function, which see every stage including the
growth-rate gradient's probes and the collar root-find's iterates.

| construct | where | incidence | what it decides |
|---|---|---|---|
| `Species::height_max()` returns `nodes.front().height()`, **not a max** | `species.h:167` | no selector within a species | it relies on the descending-height invariant, so within a species the derivative is 1 for the first node unconditionally and there is no tie. The `max` — and the tie — exist only **across** species in `Patch::height_max` (`patch.h:424`). This is a cheaper selector than report 03 §1b assumes, and single-species runs have no selector at all |
| `if (size() == 1 \|\| f_h1 > 0)` | `species.h:220` | **74 060 of 3 075 900 calls (2.41%)** enter the interval — 627 via `size() == 1`, 73 433 via `f_h1 > 0`. Smallest positive `f_h1` that took the arm **2.714503e-11** | whether the boundary node's trapezium interval enters the light field. **The row with no scale at all**: the term it switches on is `(h1 - h0)(f_h1 + f_h0)`, which vanishes as `f_h1 -> 0` only if `f_h0` does, and `f_h0` is the boundary node's own competition, which does not. So the field reduction is discontinuous in the resident state at a threshold sitting where the comparison decides on rounding — against `storage_prod_eps = 1e-4` sized against a median `\|P\|` of 7.3e-2 |
| `if (h0 < height) break;` | `species.h:215` | **2 989 227 of 3 075 900 calls (97.18%)** break early; 86 574 run to the end, 99 return early. 216 594 704 trapezium terms, at most 141 in one call | where the descending sweep stops. The term count of the field reduction is state-dependent, which is the same class as an adaptive knot count. Almost always taken because the field is queried well below the canopy top, so this is a term count rather than a severance — and the exposure is report 00 §8 item 3's, that the trapezium weights are functions of state, over 216 M terms |
| `new_node.height()` as the field trapezium's **lower integration limit** | `species.h:221` | every field build | a moving integration bound in the field reduction itself, equal to `height_0` and therefore trait-dependent through `height_seed`. Not a switch; listed here because it is the other thing that sweep reads which is not ODE state |
| `!util::is_finite(survival_individual)` → `0.0` | `node.h:144-150` | **zero. 0 of 3 758 283 calls** | **dead, and the effect it was credited with belongs one line above it.** The guard tests `is_finite`, and `exp(-mortality)` underflows to exactly `0.0`, which is finite — so it cannot fire on an underflow, only on a NaN mortality. The zeroing of fecundity is real and does grow monotonically: `exp(-mortality)` is exactly `0.0` on **185 851 calls (4.95%)**, and **327 of 10 153 records (3.22%)** hold `mortality = Inf`, none before `t = 3.5` and 6 nodes per output time from `t = 7` on. The live severance is the `exp`, so the switch needs no derivative treatment and the underflow does |
| `!util::is_finite(log_density)` → `log_density_dt = 0.0` | `node.h:182-185` | **7 879 of 35 133 stage evaluations (22.43%)**, confined to `t` in **[3.222267, 8.544184]** and absent from every later decile | zeroes the newborn's transport rate. **Not for the documented reason**: `g > 0` on all 35 133 calls, and the `-Inf` comes from the numerator. Attributed — `birth_rate == 0` on **0**, `pr_estab == 0` on **all 7 879** — so this guard's active set *is* `establishment_probability`'s gate and nothing else. Smoothing that gate retires this row with it |
| `g > 0 ? log(birth_rate * pr_estab / g) : log(0.0)` | `node.h:177` | **zero, at a wide margin: 0 of 35 133**, minimum `g` over the run **0.09529771 m/yr** | the inflow boundary condition itself. The closed arm is never taken, so the `-Inf` above never comes from here. Also: the operation is itself a derivative of the boundary condition |
| `mortality_dt`'s `is_finite(cumulative_mortality)` | `tf24_strategy.cpp` | **371 702 of 7 516 566 calls (4.95%)** return `0.0` on `cumulative_mortality = Inf`; largest finite value 545.06 | **the largest live severance in this pass.** The rate is replaced by an exact zero, so `d(mortality)/d(state)` is zero on that set and every census metric inherits it. Not a rounding effect and not smoothable: 327 records hold `Inf` outright, so the set is not near a threshold — the cohort is at survival zero, and dropping the node is the honest treatment rather than zeroing its derivative and carrying it |
| `Patch::check_finite_ode_state()` | `patch.h:693` | not counted; a stop | a hard stop rather than a branch, so it has no derivative — but it defines the domain the gradient is valid on, and a finite-difference verification step that crosses it fails loudly rather than quietly. Worth a row so that is on purpose |
| `size() > 0 & !is_mutant_run` | `patch.h:568` | **always true: 35 274 of 35 274**, 0 empty and 0 mutant | whether the field is rebuilt at all. Structurally true in a resident run, so it needs no derivative treatment. Also a bitwise `&` on two bools, which is a wart rather than a hazard |
| `consumption_rates` sized `NA_REAL` to ODE width | P0.4 | four per cohort per stage | four NaNs per cohort per stage reach `resource_depletion`. Under a reverse sweep `NaN * 0` is `NaN`, so this poisons the adjoint rather than staying latent. **Promote P0.4 to the same tier as P0.1** |

**The soil positivity guard is now counted, and it is zero.** `theta_i <= theta_r && !(rate_i > 0)`
was argued unreachable from `K ∝ θ^16.14`; measured, θ's minimum over a production run is
**0.1563 against `theta_r = 1e-2`**, a factor of 15.6, and no record is at or below it
(`scripts/aux_round_trip.R` A4). So the reverse pass's zeroed transposed row is insurance rather
than machinery *at this driver* — and it is still owed, because the committed rainfall sequences are
where it would fire. The census is at 142 output times rather than per stage, so a stage dipping
between two of them is not observed; at this margin that is an inference.

**The three that were still to count are counted**, all by
`scripts/demographic_switches.R`. `mortality_dt`'s guard is in the table above.

**The root vulnerability curve's domain edge is zero at 1.15x, and that is the tightest
margin in this document.** Beyond its fitted domain `root_vuln_from_psi` extrapolates
negative, giving negative conductivity, a negative-but-finite `r_R` and a wrong-sign
`E_i` the `isfinite(E_up_)` net cannot catch. Measured: **0 of 1 162 082 517 layer
evaluations** cross it, largest magnitude presented **5.919880 MPa** against a last knot
at **6.822923** — a margin of 0.903 MPa. Every other zero here is comfortable, at 27x
`GSS_tol_abs`, a factor of 15.6, or five times the stand's optical depth. Two things make
this one worth acting on rather than recording. The near-edge magnitude is a **collar
root-find iterate, not a state**: `|opt_root_psi|` peaks at 2.36 MPa, so an output-time
census reports 2.5x more margin than the solver holds, and a drier driver or a wider
bracket moves the iterate rather than the state. But the sign-error path is narrower than
the description above: `root_vuln_from_psi` is read only in the **equal-potentials
branch, 15 109 531 evals (1.30%)**, which already carries the `f_ri <= 0` stop, while the
general branch's **1 146 972 986 (98.70%)** read `root_vuln_integral_from_psi`, whose
linear extrapolation is **positive** — so crossing the edge there gives a wrong
conductance rather than a wrong-sign flux, and the gravity-balanced branch is taken 0
times. **What is owed is a domain assertion, not a second sign guard.**

**The `prev_q == 0` exact-double break** is a selector on cohort height: **767 291 of
7 551 699 loop calls (10.16%)**, breaking at layer 3, 4 or 5 on 403 873 / 188 566 /
174 852, and at the record level **3 430 of 10 153 (33.78%)** — the same set as P0.1's,
because a break at `a = k` is `max_soil_layer == k - 1`. It fires only for cohorts below
1.199 m, and it sits on the direct `h -> water` path.

**Five rows have nonzero incidence and no recorded derivative treatment**, in order of
exposure: `establishment_probability`'s gate (below, and P0.6's to decide);
`mortality_dt`'s `is_finite` guard; `species.h:220`'s scaleless `f_h1 > 0`;
`node.h:182-185`, whose whole active set is the gate's; and the `prev_q == 0` break.
`species.h:215` is a term count rather than a severance, and `patch.h:568`,
`node.h:177` and `node.h:144-150` need none.

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

**It now has an incidence, and it closes on a quantity that is numerically zero.**
`scripts/demographic_switches.R`: the gate takes its closed arm on **7 879 of 35 133
boundary-node stage evaluations (22.43%)**, all inside `t` in **[3.222267, 8.544184]** —
the recruitment window, and no later decile. On exactly those calls
`net_mass_production_dt` at `height_0` is negative on all 7 879 but only just: **minimum
−3.352987e-05, maximum −2.283012e-09, mean −2.063678e-05**. That is about five orders
below `storage_prod_eps = 1e-4`, the scale develop already applies to the positive part
of the same quantity one function away, and seven below report 00 §9b's median `|P|` of
7.3e-2. So `d(pr_estab)/d(state)` jumps from zero to the full `1/(tmp^2 + 1)` slope
across a threshold the model cannot resolve, and the decision is not whether the
derivative should be zero — it is that the sign of a quantity at `1e-9` is deciding it.

Two consequences follow whichever way the ecology goes. `node.h:182-185`'s entire active
set is downstream of this gate, so smoothing it retires that row as well. And **a
finite-difference verification of any census gradient straddles this gate** for
`t` in [3.2, 8.5] at a perturbation of `1e-9`, which is below every step size a re-run
difference would use — so V4's reference is exposed to it, not just the model.

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

## P0.8 — a reduction over the size distribution starts at the boundary, not at the smallest cohort

**Family-wide**, not TF24-specific: FF16 and K93 share every line of it.

Three reductions run over the size distribution, and they disagree about where the
distribution starts.

| reduction | bottom endpoint | consequence |
|---|---|---|
| `Species::compute_competition` (`species.h:220-223`) | **`new_node`** at `height_0` | correct, and needs no special case |
| `Species::consumption_rate` | `nodes.back()`, with `if (size() < 2) return 0.0;` | a transpiring plant draws **no water**, at 0.70% of output times — and it is the *first* one, the window in which establishment is decided (report 07 §1.7) |
| the transport stencil | before report 04 §7's staggering, no neighbour below the lowest cohort | settled the same way: pairing each cohort with the interval **below** makes the boundary node the lowest cohort's neighbour, so the case does not arise |

`new_node` is the size-density equation's inflow boundary. It is always live, its height is
always `height_0`, and it is the distribution's left endpoint. `compute_competition` reaches
the right answer *because* it integrates from there; the other two invent a lower limit and
then need a rule for what happens when it does not exist.

**The fix is one fix.** Give `Species::consumption_rate` the boundary node as its bottom
endpoint, exactly as `compute_competition` does. Then a one-cohort species has two trapezium
points, the `size() < 2` branch goes, and the transport stencil's bottom neighbour is the same
node in the same place.

It is a correctness fix rather than tidying: recruits between `height_0` and the smallest
cohort transpire, and develop omits them from the water balance. It also removes an
inconsistency nothing records — **the same patch state is integrated over `[height_0, H]` for
light and `[h_smallest, H]` for water.**

**It also reaches the inflow boundary condition.** `establishment_probability` solves the leaf
against the soil state, and that state was depleted by `consumption_rate` — so the `pr_estab` a
newborn is seeded with was computed against a soil that the recruits between `height_0` and the
smallest cohort never drew from. The boundary density is `log(birth_rate · pr_estab / g)`, so the
omission propagates into every cohort's seeded density, not only into the water balance.

**Gate.** A one-cohort species draws nonzero water. The light and water reductions agree on
their domain of integration. Offspring and the three census metrics re-blessed with the shift
recorded, at a pinned build.

---

## P0.9 — `ode_rates` is not the derivative of `ode_state` after an introduction

**Family-wide.** `Patch::introduce_new_nodes` widens the state and rebuilds the light field,
and does not recompute rates (`patch.h:621-631`). `SCM::run_next_impl` then calls
`solver.set_state_from_system()` immediately (`scm.h:262-263`), which reads `ode_rates` into
`dydt_in` and sets `dydt_in_is_clean = true` (`ode_solver_internal.hpp:146-152`), so
`setup_dydt_in` will not recompute. RKCK is first-same-as-last, so **`dydt_in` becomes `k1`**:
the rate vector from the previous state and the previous field, used as the derivative of the
widened state under the rebuilt field. odelia records the doubt in place — *"Not clear that
this is the right thing here; should just be able to look up the correct dydt rates because
we've already set state?"*

**Measured** (`scripts/k1_arms.R`, instrumented by `reports/introduction-k1.patch`; 141 introductions, `-O2`):

| max abs |Δrate| at an introduction | median | max |
|---|---|---|
| pre-existing cohorts | 6.66e-09 | **5.884** |
| the newborn's own slots | 2.44e-09 | 0.994 |
| environment (soil) | 8.31e-06 | 3.10e-03 |
| pre-existing cohorts, **relative** | 1.12e-08 | **1.203e+02** |

Above 1% relative at **59 of 141** introductions, above 10% at 56, **above 100% at 51**. The
distribution is bimodal because the amplifier is the sub-grid stencil: a newborn perturbs the
field slightly, and `log_density_dt = -dg/dh - mortality` differences two nearly-equal growth
rates, so a small field change becomes a large rate change. That predicts the error mostly
disappears once the transport stencil moves to the cohort grid — worth checking rather than
assuming.

**Effect on the run.** Offspring `4.214017357509567e+01` to `4.226306091461433e+01`, a change
of **0.2916%**, and 5 055 accepted steps to 5 060. That is twice the `-O0`/`-O2` build noise
(report 01 §2), so it is attributable at a pinned build. Cost: 141 extra rate evaluations
against about 30 000, and no measurable wall-clock difference.

**Fix.** One line — `compute_rates()` after `compute_environment(false)` in
`introduce_new_nodes`. `environment_ptr` is already `&environment` there, set in `reset()`.

**Why it matters beyond the value.** `dydt_in` becoming `k1` means a reverse traversal that
treats `k1` as `derivs(y_n, t_n)` is differentiating at the wrong point at 141 of 5 055 steps,
with the right sign and nothing thrown — report 01 C5's newborn-adjoint failure mode. And it
is the same instant at which the transport stencil's bottom interval has zero width and the
boundary density is stale, so **one fix removes three symptoms**.

**Gate.** At every introduction, `ode_rates` immediately after `introduce_new_nodes` equals
`ode_rates` after a further `compute_rates()`. Re-bless with P0.8, P2.1 and P2.4 in one pass.

---

## P0.10 — the shared `Leaf`'s purity is derived by reading, and nothing executes it

**Family-shaped, TF24-bodied**: every model shares a `Strategy` across its cohorts through
`Individual`'s `strategy_type_ptr` (`individual.h:179`); only TF24 hangs a sixty-member
sub-model off it.

The cohort is a legitimate reverse-pass unit only if `Individual::compute_rates` is a function of
its own `Internals`, the environment values it reads, and the parameters. Report 01 §5 establishes
that by reading `set_physiology` and enumerating what it re-seats — `psi_soil_`, `grav_head_z_`,
`c_r_V_`, `c_r_H_`, `soil_consumption_`'s resize, `transpiration_cached_ = false` — and by noting
that `find_root_collar_psi` brackets off the current soil state with no warm start. That is the
right method and it found four carriers:

| carrier | where |
|---|---|
| `Leaf::soil_consumption_`, deep layers | P0.1. **33.78%** of production records |
| `Leaf::soil_consumption_` and `E_up_` past a shutdown exit | P0.2, report 00 §8 item 5 |
| `photo_temp_cached_`, keyed on `(leaf_temp_, atm_o2_kpa_)` while caching `vcmax_` and `jmax_` | report 01 §5, report 02 C3. The key is a proper subset of the dependencies, and both parameters are differentiation targets |
| `psi_soil_cache_`, keyed on exact `double` equality of the soil state | report 01 §5, report 00 §8 item 10. A finite-difference verification perturbs exactly that state |

**What is missing is not the enumeration but an executable check.** Report 02 C5 says why reading
is not enough: the input list "was assembled by reading `set_physiology`'s signature and would
silently become incomplete if that signature grew", against roughly thirty loose doubles, five
vectors and four interpolators with nothing marking which are transient. And report 01 §10 rule 2
states the conclusion flatly — "`Leaf leaf` is safe because `set_physiology` re-seats it. Neither
is enforced" — where §5 lists three exceptions inside that object. P0.1's gate is the right shape
(`solve(seedling); solve(tree); solve(seedling)` bit-identical) but covers one triple and one
member.

**The check.** Take a census of production `(height, psi_soil, radiation)` states. Solve them in a
fixed order, then in several permutations, and assert every leaf output — `profit_`,
`soil_consumption_[]`, `E_up_`, `transpiration_`, `opt_psi_stem_`, `root_collar_psi_`,
`stom_cond_CO2_` — bit-identical across permutations. A single re-solve of the same state after any
other state must reproduce it exactly.

Two properties make this the right instrument. It needs no AD, so it can run on develop today. And
it catches what no forward test can: the forward pass is order-deterministic, so a stale read
reproduces exactly, run after run, and only a *reordering* exposes it.

**Gate.** Bit-identity across permutations for every output, at a pinned build. Any carrier it
finds becomes a P0 row of its own. Running it before P0.1 and P0.2 should reproduce their known
incidences, which is the check on the harness.

---

## P0.12 — TF24 writes the canopy profile itself, twice, and pays `pow` for it

**Where.** `tf24_strategy.h` includes `canopy_shape.h` for the `ShadingModel` enum only.
TF24 has its own `q` (`tf24_strategy.cpp:737`), `Q` (`:744`) and `Qp` (`:754`), and a
**second copy of `Q` inlined** into the hot-path `compute_competition` overload
(`:726-734`), whose own comment says it "reproduces `pars.k_I * area_leaf(height) *
Q(z, height, pars.eta)`". FF16 (`ff16_strategy.h:377`) and K93 (`k93_strategy.h:103`)
use `CanopyShape`. The `eta_c` formula is written three times — `tf24_strategy.cpp:804`,
`ff16_strategy.cpp:569`, and `CanopyShape::compute_eta_c`.

**Three things follow, and only one of them is a style question.**

*Two copies of one equation with nothing keeping them equal.* This is the
`ff16_production_kernel.h` pattern [`build-plan.md`](build-plan.md) §2.1 rules out, in the
model the gradient is being built for.

*`pow` has a NaN derivative at `u = 0`, and the field's lowest knot is exactly `z = 0`.*
`d/d(eta) u^eta = u^eta log(u)`, which at `u = 0` is `0 · (−inf)`. The value is fine —
`pow(0, 12)` is 0 — so this is latent until `eta` is seeded, and then it fires on the
**first knot of every field build**, making one trait's gradient NaN while every other
stays finite and plausible (report 01 §7.6 found exactly this in a toy). `CanopyShape`'s
`pow_eta` returns `Z(0.0)` when `to_passive(u) <= 0`, which is the limit, and the
eta-specialised chains carry no `log` at all.

*The eta-specialised chains are ~9x faster than the general `pow`.* TF24 calls
`pow(u, pars.eta)` with `pars.eta = 12.0`, which is one of the specialised values.
Arithmetic, not measurement: about 127 M competition evaluations per run (58.4 knots x
~71.5 cohorts x 6 stages x 5 055 steps) plus about 45 M crown-integral `q` calls, at the
~20 ns per evaluation M2 measures between the general `pow` and the `u^12` chain, is about
**3.4 s of an 86 s run, ~4%**. Treat as an upper bound: a microbenchmark's cache is warmer
than the field build's.

**It is not bit-identical, and that is the whole cost.** `pow(u, 12.0)` and `u2*u4*u8`
differ in the last bits, so this moves the forward value, and the adaptive controller
amplifies last-bit differences into a different accepted grid — report 01 §2 measures
0.145% in offspring and 0.79% in step count between two builds of one tree. So expect a
shift of that order and re-bless deliberately. There is no bit-identical route to the
chain; the only bit-identical option is to keep `pow` and add the `u <= 0` guard alone,
which fixes the NaN and leaves the duplication and the 4%.

**Order.** (1) Add a `CanopyShape canopy_shape` member to `TF24_Strategy`, initialise it in
`prepare_strategy`, and assert its `Q` against TF24's over a production census of
`(z, height, eta)` — this measures the shift before anything moves. (2) Switch
`compute_competition`, both overloads, and the crown integral's `q` to it; re-bless.
(3) Delete `TF24_Strategy::q`, `::Q`, `::Qp` and the inlined duplicate. (4) Take `eta_c`
from one formula: `CanopyShape` already computes it, so expose it and have both strategies
read it.

**Why before Phase 1.** [`build-plan.md`](build-plan.md) P1.2b templates TF24. Doing this
first means one implementation is templated rather than two, and `CanopyShape<S>` is
already what §3 takes.

**What it does not need.** TF24's `prepare_strategy` rejects PPA and both flat-top models,
so `Q` is the only profile it can reach and `leaf_area_above`'s dispatch is not wanted —
FF16 needs that, TF24 does not.

**It also makes P0.7 a one-place fix.** `q` divides by `z`, so `q(0, h)` is NaN for every
`h`, and `CanopyShape::q` has the same division. With TF24 on `CanopyShape` that guard is
written once for three models instead of twice for two.

**Gate.** `CanopyShape::Q` and TF24's agree to the last bit at every sampled `(z, h)` **or**
the difference is recorded as last-bits-only before the switch; one production run
re-blessed with the shift stated; `grep -c "pow(z / height\|pow(u, pars.eta)" src/tf24_strategy.cpp`
returns 0; and a seeded-`eta` gradient at the ground knot is finite.

---

## P0.11 — the boundary node solves the same leaf twice per stage

**Family-wide.** `Node::compute_initial_conditions` calls `compute_rates`, which stores
`net_mass_production_dt_` in an aux slot, and then `establishment_probability`, which recomputes it
at the identical arguments: `new_node`'s height is `height_0` from `Individual`'s constructor and it
is never stepped, so `vars.aux(competition_effect)` is `area_leaf(height_0)` by the same function
that `prepare_strategy` used for `area_leaf_0`, and `1/height_0` likewise
(`tf24_strategy.cpp:704-716`, `node.h:164-175`, `individual.h:113-117`). Two evaluations, one
value.

**Why it is a P0 rather than housekeeping.** Under a reverse sweep two evaluations of one function
have two adjoints, and they must be added. Dropping one gives a gradient that is wrong through the
recruitment channel — hence through every census metric and R0 — by whatever share establishment
carries, with the correct sign and nothing thrown. That is the same silent failure as the trait and
knot accumulations, in a third place, and unlike those two it can be removed rather than tested for:
one evaluation has one adjoint.

**The fix is to pass the value, not to cache it.** `compute_initial_conditions` hands
`establishment_probability` the rate it has just stored. The R-facing
`establishment_probability(env)` keeps its current meaning — it is a birth-size quantity evaluated at
`height_0` whatever the individual's own height, and a caller reaching it through an arbitrary
`Individual` must keep getting that.

**Not counted.** The share is one boundary node against the live cohorts, so it falls from a few
percent early in a run to well under one percent at 141 cohorts. Worth taking with the forward
benchmark rather than on its own.

**Gate.** `establishment_probability` at the boundary node bit-identical before and after — it is the
same function at the same arguments, so anything else means the arguments were not the same. Leaf
solves per stage down by one per species, counted rather than argued.

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
