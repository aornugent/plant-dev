# TF24 at develop: what the six reports do not cover

**What this is.** A close reading of every line of TF24's compute path on develop
`141dc8df`, followed by a review of which parts of it the six reports own. It is
written because the reports were each scoped to one *mechanism* — a tape, an
argmax, an interpolant, a transport term, a coupling — and the seams between
those mechanisms turn out to hold most of what is wrong.

**Everything numbered below was measured against a develop build**, not inferred.
Two probes were written for it and are committed:

- `scripts/leaf_state_carryover.R` — does one leaf solve leave state the next one reads
- `scripts/uncounted_switches.R` — incidence, on a production run, of four discrete constructs

Read `00-tf24-dependency-map.md` first for the forward/reverse structure. This
report does not restate it; it adds the parts the map's own §7 table has no row
for, because nothing in the map's derivation reaches them.

**Scope.** TF24 and TF24f only, develop only. Where a finding is family-wide
(FF16/K93 share the code) that is said explicitly.

---

## 1. Findings, ranked by what they cost

Ranked by consequence, not by how hard they were to find. The first two are
forward-model defects that exist whether or not anyone ever takes a gradient.

### 1.1 One leaf solve leaks into the next — the purity claim report 1 rests on is false

**The mechanism.** `TF24_Strategy` holds `Leaf leaf` as a value member, and every
cohort of a species reaches it through the same `Strategy` `shared_ptr`. Report 1
§5 checked this and concluded the leaf is clean, because `set_physiology`
"re-seats every per-solve field": it "resizes `soil_consumption_`". That is the
hole. `set_physiology` does

```cpp
soil_consumption_.resize(soil_number_of_depths_, 0.0);
```

and `std::vector::resize`'s fill argument applies **only to newly added
elements**. Every element that already exists keeps its value. Two lines above,
the sibling buffers are handled the other way — `c_r_V_.assign(max_soil_layer,
0.0)` — so the file is inconsistent with itself by exactly one call.

That would not matter if the solve wrote every element. It does not.
`E_from_Soil_to_Root_Collar`'s loop is

```cpp
for(size_t i = 0; i < max_soil_layer; i++){ ... soil_consumption_[i] = E_i; ... }
```

and `max_soil_layer` is set in `set_physiology` to the last layer with nonzero
root mass. Root mass comes from `Q(z, rooting_depth, 0.2)` with
`rooting_depth = min(height, 1.5)`, so a plant shorter than the soil column
roots into only the upper layers. **Layers at and beyond `max_soil_layer` are
never written this solve, and were never cleared, so they hold the previous
cohort's values.**

`TF24_Strategy::compute_rates` then reads *all* of them:

```cpp
for (int i = 0; i < soil_number_of_depths_; i++)
  vars.set_consumption_rate(i, evapotranspiration_dt(area_leaf_, i)*60*60*12*365/1000*kg_per_mol_h2o);
```

with `evapotranspiration_dt(a, i) = leaf.soil_consumption_[i] * a`. So a
shallow-rooted cohort is credited with drawing water from layers it has no roots
in, at the previous cohort's per-leaf-area rate, scaled by its own leaf area.

**Measured** (`scripts/leaf_state_carryover.R`, five layers over 1.5 m, wet soil,
a 20 m tree solved then a 0.4 m seedling, which is the height-descending order
`Species::compute_rates` uses):

```
height  20.00 m  max_soil_layer 5
   soil_consumption_ = 7.076578e-04  3.489490e-05  1.054333e-05  3.865077e-06  1.080036e-06
height   0.40 m  max_soil_layer 2
   soil_consumption_ = 2.232803e-03  6.975421e-06  1.054333e-05  3.865077e-06  1.080036e-06
same seedling on a FRESH leaf:
   soil_consumption_ = 2.232803e-03  6.975421e-06  0.000000e+00  0.000000e+00  0.000000e+00
```

Layers 3–5 of the seedling's record are **bit-identical to the tree's**. The
seedling's spurious draw is 0.7% of its real draw here; the fraction scales with
how much of the profile the neighbour reaches and the seedling does not.

**It is order-dependent, which is the sharper statement.** Solve the seedling,
then the tree, then the same seedling again:

```
   seedling, 1st time: 2.232803e-03 6.975421e-06 0.000000e+00 0.000000e+00 0.000000e+00
   seedling, 2nd time: 2.232803e-03 6.975421e-06 1.054333e-05 3.865077e-06 1.080036e-06
   bit-identical: FALSE
```

**Incidence on a production run** (`scripts/uncounted_switches.R`,
`max_patch_lifetime = 105.32`, 10 153 cohort-time records):

| `max_soil_layer` | records | share |
|---|---|---|
| 2 (three stale layers) | 2 612 | **25.73%** |
| 3 (two stale layers) | 448 | 4.41% |
| 4 (one stale layer) | 370 | 3.64% |
| 5 (clean) | 6 723 | 66.22% |
| **at least one stale layer** | **3 430** | **33.78%** |

So a third of all cohort-solves in a production run are contaminated, and a
quarter of them by three layers out of five.

**And the source is worse than "the neighbour".** `Node::compute_rates` runs
`individual.compute_rates(environment)` and *then* `growth_rate_gradient`, which
finite-differences the growth rate by calling `compute_rates` on a scratch
`Individual` at `height + eps`. The scratch shares the same `Strategy`, so it
runs a full leaf solve on the same `Leaf`. The stale deep layers a cohort
inherits are therefore the previous cohort's **finite-difference probe at a
perturbed height**, not even its actual operating point.

**Which report should have caught it.** Report 1 §5 — this is precisely its
subject, and its §10 rule 2 ("shared mutable members on the Strategy are a
liability, and the safe pattern is write-before-read") names the pattern. It
cleared `mass_root_prop_` (correctly — `.assign`) and cleared the `Leaf` on the
strength of `set_physiology`'s discipline. §5's own closing sentence is the
warning: "the property is held by *discipline inside `set_physiology`* rather
than by structure". The discipline had a gap.

**Consequences for report 1's design.** §12's leading falsifier is "a cohort's
rates are not reproducible from its boundary. Re-run one cohort's
`compute_rates` from stored state plus stored environment reads and compare to
the forward pass bit for bit." That check now has a known answer: **it fails, on
33.78% of records.** The cohort-granular decomposition is not thereby wrong — it
is *more* correct than the forward pass, because a re-recorded cohort in
isolation computes the deep layers as zero, which is what its own physics
implies. But it will not reproduce develop bit-for-bit, and the difference will
look like a decomposition bug. Fix the forward model first, or the design's own
acceptance test cannot pass.

**Fix.** `soil_consumption_.assign(soil_number_of_depths_, 0.0);` — one word.
Re-bless the TF24 baselines; the shift is real but small (0.7% of a small
cohort's draw). Landing it also removes the ordering dependence, which is worth
more than the numbers.

### 1.2 The shut-down exits hand the soil the previous cohort's entire uptake

**The mechanism.** `set_shutdown_state(root_collar)` sets `root_collar_psi_`,
`opt_psi_stem_` and `profit_`. It sets neither `soil_consumption_` nor `E_up_`.
Three of `prepare_collar_solve`'s early exits call it, and they leave the leaf in
three *different* wrong states:

| exit | what `soil_consumption_` holds |
|---|---|
| `-wettest_soil_layer >= psi_crit` | the **previous cohort's** values — `E_from_Soil_to_Root_Collar` is not called at all this solve |
| `E_column(-psi_crit, ...) < 0` | uptake at `-psi_crit`, not at the shut-down point |
| `-root_crit >= psi_crit` | the **last trial iterate of the TOMS748 root-find** inside `find_root_psi` |

A shut-down plant transpires nothing, so the correct value in all three cases is
zero.

**Measured.** Same leaf, a wet 20 m tree then the identical tree with every layer
drier than `psi_crit`:

```
wet tree      E_up_ = 1.365611e-05  soil_consumption_[1] = 7.076578e-04
then bone dry E_up_ = 1.365611e-05  soil_consumption_[1] = 7.076578e-04
   E_up_ carried over from the wet solve: TRUE
   soil_consumption_ carried over:        TRUE
   same dry solve on a FRESH leaf: E_up_ = NA, consumption[1] = 0
```

Not a fraction of a percent — the **whole** uptake, at the same leaf area, from a
plant that is not transpiring. And on a fresh leaf the same solve reports `NA`,
so the value is entirely a function of what ran before it.

**Where it bites.** Report 00 §9 measured **zero** shut-down incidence on a
production run (0 of 10 153, minimum margin 0.02688 MPa = 27× `GSS_tol_abs`), so
this is latent at the default driver. It is live exactly in the drought
transients — the configuration OPEN-ITEMS #58 exists to explore and the one where
a water-balance error matters most. Report 02 §3.5 recorded the defect; report 00
§8 item 5 confirmed it is unfixed on develop. What neither says is that the third
exit's value is a *solver iterate*, which is not "stale" so much as meaningless.

**Fix.** `set_shutdown_state` should zero both, and the `assim_max_ < 0` exit
(which does call `E_from_Soil_to_Root_Collar` at its own operating point) is
already correct and shows the intended shape.

### 1.3 Leaf dark respiration is subtracted twice on the carbon path

**The mechanism.** `Leaf::assim_colimited` ends in `- R_d_`, so it returns **net**
assimilation. `profit_psi_stem_TF` = `assim_colimited_ − hydraulic_cost_TF`, so
`profit_` is net of dark respiration. `net_mass_production_dt` then computes

```cpp
assimilation_ = leaf.profit_ * area_leaf_ * 60*60*12*365/1e6;
respiration_  = respiration(mass_leaf_, mass_sapwood_, mass_bark_, mass_root_);
return net_mass_production_dt_A(assimilation_, respiration_, turnover_);
```

and `respiration_leaf(mass) = pars.r_l * mass` — leaf dark respiration, again.

**Measured**, both terms reduced to kg dry mass per m² leaf per year at the
defaults:

| term | value |
|---|---|
| inside `profit_`, as `R_d_ = vcmax_ · 0.015` | **0.389407** |
| again, as `r_l · mass_leaf` | **0.673481** |
| leaf respiration counted | **1.578×** |
| double-counted share of the pair | **36.6%** |

**Why it is plausible rather than a misreading.** TF24 was scaffolded from FF16
(the header says so). FF16's assimilation is a **gross** light-response
hyperbola, `assimilation_leaf = a_p1·x/(x + a_p2)`, where `r_l` is the only leaf
respiration in the model and is therefore correct. TF24 replaced that with a
Farquhar leaf returning net assimilation and kept `r_l`. The dead FF16 code is
still in the file: `TF24_Strategy::assimilation` carries the comment
`(!!not in use for TF24 model!!)`, its call site is commented out at
`tf24_strategy.cpp:512`, and `a_p1`/`a_p2` are still live entries of `TF24_Pars`.
The provenance of the double count is visible in the same forty lines.

**This is an ecology decision, not a bug I can fix.** It changes every simulated
number, so it needs the hydraulics owner. Two other things in the same expression
want the same conversation: the hydraulic cost is inside the term multiplied by
`a_bio · a_y`, so hydraulic risk is discounted by the 0.7 growth-conversion
efficiency as though it were assimilated carbon; and `root_mass_carbon_scale =
83.26 · 0.5` is an unexplained factor of 41.63 converting fine-root mass into the
units the root hydraulic network expects, flagged `TODO` and never resolved.

**No report owns this.** Report 02 owns the leaf's *gradient*; report 00 maps the
leaf's *dependencies*. Neither audits the leaf's carbon bookkeeping against the
strategy that consumes it, because the boundary between them is exactly where the
two reports' scopes meet.

### 1.4 `soil_moist_from_psi` is wrong by a factor of 8.19, and it is exported

`psi_from_soil_moist` converts Pa to MPa:

```cpp
return std::min(a_psi_layer * std::pow(t / soil_moist_sat_layer, -n_psi_layer) / 1e6, soil_psi_max_);
```

`soil_moist_from_psi` does not undo it:

```cpp
return pow((psi_soil_ / a_psi_layer), (-1 / n_psi_layer)) * soil_moist_sat_layer;
```

The missing `· 1e6` inside the power scales the result by
`1e6^(1/n_psi) = 10^(6/6.57) = 8.19`.

**Measured** round trip:

```
  theta 0.3000 -> psi 1.837887e-02 -> theta 2.456763e+00   round-trip err 2.157e+00
```

2.456763 / 0.30 = **8.189**, exactly the predicted factor. The returned moisture
also exceeds saturation (0.428), which is the tell.

`soil_moist_from_psi` is called by **no C++ code** — it exists only as an R-facing
utility, and no test covers it. So it is not a simulation defect. It is worse in
one specific way: it is the natural function to reach for when converting a
critical potential into a moisture threshold, which is what OPEN-ITEMS #58's
recorded figure ("develop reaches `psi_crit` at θ = 0.1246") is. Any number in the
corpus derived through this function is wrong by 8.19×.

**Fix.** One `* 1e6`. Add the round-trip as a test — it is a two-line property
check that would have caught this the day it was written.

### 1.5 An aux output that is declared, allocated, reported and never written

`aux_names()` returns eleven names, ending in `"assimilation"`.
`refresh_indices()` caches ten of them plus `area_sapwood`; there is no
`aux_idx_assimilation` anywhere in the package. Nothing ever calls
`set_aux` for that slot. `Internals` initialises `auxs(a_size, 0.0)`.

**Measured**: over 10 153 production records the `assimilation` aux is exactly
`0` for every one. It reaches R through `tidy_patch` as a column reading zero
assimilation for every cohort at every time.

Harmless numerically, and a fair test of whether anyone reads TF24's aux output.
Either write it (`assimilation_` is computed one line above the return in
`net_mass_production_dt`) or delete the name.

### 1.6 Four of nine resource slots carry NaN through every stage

Read directly, not measured — no R-facing route reaches
`Internals::consumption_rates`.

`Individual::compute_rates` sizes the vector to `environment.ode_size()`, which
for TF24 is `soil_number_of_depths + aux_num` = **9**. `Internals::resize`
fills with `NA_REAL`. `TF24_Strategy::compute_rates` writes slots `0 … 4` only —
the four cumulative-flux slots have no consumer. `Patch::compute_rates` then
accumulates **all nine**:

```cpp
for(size_t i = 0; i < environment_ptr->ode_size(); i++) {
  double resource_consumed = std::accumulate(species.begin(), species.end(), 0.0,
    [i](double r, const species_type& s) { return r + s.consumption_rate(i); });
  resource_depletion.push_back(resource_consumed/area);
}
```

`Species::consumption_rate` trapezium-integrates over the nodes, so slots 5–8
produce `NaN`, get divided by `area`, and are pushed. `TF24_Environment::
compute_rates` reads only `resource_depletion[0 … 4]`, so the NaNs are discarded.

Latent today. It becomes live the moment anything sweeps that vector for
finiteness, and under AD it would put four NaNs on the tape per stage. The
mismatch is structural: the resource vector is sized by the environment's **ODE
width** when what it means is the environment's **number of consumable
resources**, and those differ by exactly the four diagnostic accumulators.

### 1.7 `Species::consumption_rate` returns exactly zero for a one-cohort species

```cpp
if(size() < 2) { return 0.0; }        // "can't determine density for one node"
```

The comment is honest: with one node there is no spacing, so the trapezium has no
interval. But the consequence is that a species with one live cohort draws **no
water at all**, and the soil integrates as though the patch were unplanted.

**Measured**: 1 of 142 output times, **0.70%**, and it is the *first* one — the
window between a species' first and second introduction. Small, but it is the
window in which establishment is decided, and it is the only place in the model
where a transpiring plant consumes nothing.

Report 00 listed this as an uncounted switch (§10 item 3). It is now counted. The
number is small enough that it is a correctness question, not a priority one.

### 1.8 The `1e-4` light floor never binds, and neither does the undershoot guard

`compute_average_light_environment` and `radiation_at` both clamp with
`std::max(light, 1e-4)` (`tf24_strategy.cpp:41, 449`), with a comment recording that
the original rationale was never written down. On the clamped side `d(light)/dz` is
zero, so it would be a derivative severance wherever it binds. Report 03 C7 asks for
its incidence.

**Measured** (`scripts/light_floor.R`, 8 292 knot values over 142 output steps of a
production run):

| | |
|---|---|
| light knot values at or below `1e-4` | **0 of 8 292** |
| minimum light knot value | **0.1657209** |
| negative knot values | **0** |
| knots per step | 33 to 129, mean 58.4 |

**Zero incidence, and it is structural rather than lucky.** `L(z) = exp(-A(z))` with
`A` the projected leaf area *above* `z`, so `L` is minimised at the ground by
construction, and the ground value is 0.166. Reaching `1e-4` needs `A ~ 9.2`, about
five times the optical depth this stand attains. Confirmed independently by evaluating
`exp(-Patch::compute_competition(z))` directly over `[0, height_0]` at 141
introduction steps (`scripts/boundary_node.R`): the same 0.1657.

**The `std::max(0.0, spline(height))` undershoot guard is not firing either.** No knot
value is negative. `resource_spline.h` documents the guard against a cubic undershooting
between knots, notably for K93 at high `k_I`; on TF24 at these settings it has nothing
to catch.

So neither construct is on TF24's production path, and neither needs a derivative
treatment. Both belong in the switch inventory at zero, with the driver recorded — the
argument above is about this stand's optical depth, so a denser canopy or a higher `k_I`
would change it.

### 1.9 TF24f's single-plant R interface is silently wrong

`TF24f_Strategy::solve_leaf` evaluates the leaf at `tracked_root_psi_`, read from
the tracked ODE state. `profit_at_collar_psi` clamps that into the feasible
interval. An `Individual` constructed from R has never had `set_initial_states`
called, so the state is `0`, which clamps to `bound_a` — the **zero-uptake** end
of the interval.

**Measured**, open sky and wet soil:

| | `net_mass_production_dt` | `establishment_probability` |
|---|---|---|
| TF24 | +3.053802e-04 | **0.9984355** |
| TF24f | **−1.367946e-04** | **0** |

A sign flip on production, and an establishment probability of exactly zero,
because the hard `if (net_mass_production_dt_ > 0)` gate closes.

**The SCM path is correct**, and only by ordering: `Node::compute_initial_
conditions` calls `set_initial_states` (which runs the base optimiser through the
`initializing_` flag), then `compute_rates`, then `establishment_probability`. So
`test-strategy-tf24f.R`'s assertion that offspring production is finite and
positive passes, and the model is usable through `run_scm`. What is broken is the
per-individual API — `TF24f_Individual()$net_mass_production_dt(env)` — and
nothing in the R interface makes the required call visible.

**This reframes two backlog items.** OPEN-ITEMS #32/#33 (close TF24f's 2.9e-4
tracked-collar residual; fold it into the leaf assembly) are recorded as blocked
on `plant#61`, "TF24f aborting on every hard scenario at its shipped `k_acclim`
= 1 default, because the tracked potential leaves the feasible leaf-solve
domain". The domain-escape mechanism is real, but there is a second one in the
same area: the tracked state's *default* is outside the domain, and the clamp
that saves the value path is the same clamp that makes the gradient point out of
it. Whether `plant#61` is one problem or two is worth settling before either
backlog item is picked up.

### 1.10 Smaller things, read directly

Each is a one-line finding; none changes a number.

- **`compute_roots` is declared and never defined.** `tf24_strategy.h:208`.
  No definition, no caller, no yml entry — a link error waiting for its first
  caller, the same shape as `Patch::r_at` (v3-requirements C4.9).
- **`TF24_Environment`'s constructor argument
  `light_availability_spline_rescale_usually` is ignored.** The initialiser list
  does not use it; the body hard-codes `true` with the parameter's name in a
  trailing comment. The member `canopy_rescale_usually` that would hold it is
  declared, never assigned, never read. **Family-wide** — FF16 and K93 do the
  same. Report 03 C5 calls `rescale_usually` "the production path", which it is;
  it is just not configurable.
- **A dead local in the constructor.** `ExtrinsicDrivers extrinsic_drivers;`
  inside `TF24_Environment`'s body constructs and discards a local; the
  `extrinsic_drivers_set_constant` calls that follow act on the base member.
- **`profit_psi_stem_Sperry` is exported and always `NA`.** `lambda_` is set to
  `NA_REAL` in `setup_clean_leaf` and assigned nowhere else, and the function
  returns `benefit_ - lambda_ * cost`. Measured: `NA`, against `9.105408` for
  `profit_psi_stem_TF` at the same arguments. `hydraulic_cost_Sperry`,
  `optimise_psi_stem_Sperry`, `transpiration_full_integration` and the Medlyn
  block are all exported and off the compute path; only this one is *wrong* as
  opposed to unused.
- **`environment.depth` is settable and the rooting cap does not read it.**
  `rooting_depth_max = 1.5` is a file-static in `tf24_strategy.cpp`;
  `depth` is an R-settable field. Setting `depth <- 3.0` and re-running
  `set_soil_number_of_depths(5)` gives a 3 m column in which the two deepest
  layers can never be rooted by a plant of any height, silently.
- **`Leaf::dz_ = soil_depth_.back()/soil_number_of_depths_`** re-derives the layer
  thickness the environment already holds in `dz[]`, and is only correct for a
  uniform grid. The environment's grid is uniform today.
- **`electron_transport()` declares a local shadowing the member it computes**,
  and relies on the caller assigning the return value.

---

## 2. How the six reports integrate

They integrate cleanly *with each other*. Each owns one mechanism, states its
constraints, and hands off at a named boundary: report 1 needs report 2's leaf
node and report 3's interpolant (§11 step 7); report 3 supplies the slope report
1's crown channel wants; report 4 removes the mass chart report 1's §7 witness
assumed. There is no contradiction between them that I can find, and report 00's
dependency map is a consistent spine for all five.

What they do not do is **cover the System**. Each report starts from a mechanism
and reads outward until the mechanism is settled. Nothing starts from the code
and reads until the code is exhausted. Here is TF24's compute path with the
report that owns each part:

| part of the path | owner | state |
|---|---|---|
| cohort tape / RK traversal / trait accumulation | 01 | designed, toy-verified |
| the collar argmax and its adjoint | 02, 06 | derived, measured |
| the light interpolant's value and slope | 03 | measured, bracketed |
| the demographic transport stencil | 04 | routes unmeasured |
| the soil water balance and its clamps | 05 (superseded), 06 | re-verified on develop |
| the leaf's forward/reverse dependency structure | 06 | mapped |
| **the leaf's shared per-solve state** | **1 §5, incompletely** | **§1.1, §1.2 above** |
| **the leaf's carbon bookkeeping vs the strategy's** | **nobody** | **§1.3** |
| **the aux vector** | **nobody** | **§1.5** |
| **the resource vector's width** | **nobody** | **§1.6** |
| **`Species`' density reduction** | **06 named it, uncounted** | **§1.7 (now counted)** |
| **the root-mass depth distribution and its cap** | **nobody** | **§1.10, and the `83.26` scale in §1.3** |
| **establishment probability** | **06 named it, undecided** | **§1.9** |
| **NSC storage (#517)** | **nobody** | **06 §9b (clamp active on 13.96%)** |
| **the R-facing surface** | **nobody** | **§1.4, §1.9, §1.10** |

Eight of fifteen rows are unowned, and three of the eight hold measured defects.
That is the answer to "what has fallen between the cracks": **the boundaries
between the reports, plus everything that is neither a numerical mechanism nor a
gradient channel** — units, bookkeeping, vector widths, exported utilities, and
the storage pool, which landed after the reports were written and which no report
mentions.

### 2.1 The pattern the findings share

Six of the ten findings are the same mistake in different clothes: **a quantity
is written by one piece of code and read by another under an assumption the two
never state.**

- `soil_consumption_`: written up to `max_soil_layer`, read up to
  `soil_number_of_depths` (§1.1)
- `soil_consumption_` / `E_up_`: written by the solve, read after an exit that
  skipped it (§1.2)
- `profit_`: written net of respiration, read as though gross (§1.3)
- the `assimilation` aux: read by R, written by nobody (§1.5)
- `consumption_rates`: sized by ODE width, read as resource count (§1.6)
- `depth`: written by R, read by nobody that matters (§1.10)

The project's own style guide already names the rule this violates — "no storing
what can be derived; no passing a count that can disagree with its source of
truth". `max_soil_layer` and `soil_number_of_depths` are exactly a count that can
disagree with its source of truth, and 33.78% of production records is what the
disagreement costs.

That is a **general** finding, and the standing instruction is to fix general
problems generally: any per-solve buffer on a shared `Strategy` member should be
sized and cleared by the same statement, once, from the one authority on its
length. Report 01 §11 step 4 already proposes "give the `Leaf`'s per-solve fields
an explicit boundary from its parameters, so 'what `set_physiology` must re-seat'
is a structural fact rather than a list someone maintains" — and lists it as
optional. §1.1 makes it not optional.

### 2.2 What changes in the reports

**Report 01.** §5's conclusion ("on develop, one cohort's rate computation is a
pure function of its boundary, and the unit is legitimate") is **false as
stated** — a third of production records carry the previous cohort's deep-layer
uptake, and the previous cohort's finite-difference probe at that. §5's table
needs a fourth row for `soil_consumption_`, §9 a prerequisite C8 alongside the
two caches, and §11 step 4's second bullet promotes from optional to required.
The design survives intact; its bit-identity acceptance test does not.

**Report 02.** §3.5's stale-uptake defect is confirmed live on develop and is
larger than recorded: the third shut-down exit leaves a root-finder iterate, and
the carry-over is 100% of the uptake, not a correction to it.

**Report 03.** C7's light-floor incidence is now measured (4.638%), and the
`std::max(0.0, spline)` guard is confirmed firing (minimum exactly 0). Both were
open asks. C5's premise — `rescale_usually` is the production path — is correct
and now known to be non-configurable.

**Report 05.** Already superseded. Nothing here revives it.

**Report 00.** §7's classification table needs the eight unowned rows above; §10
items 3 and 4 are answered (0.70% and the establishment gate's exact
consequence); §8's adversarial list needs `soil_consumption_`, which is the one
way the map could be wrong that its fourteen items do not consider — the map
treats the leaf as a function of its inputs, and on develop it is not.

**`OPEN-ITEMS.md` and `v3-requirements.md`.** Both are stale in ways already
noted, and this audit adds: C11.10 ("`Leaf` has no structural boundary between
parameters and per-solve scratch — why 'audit every cache' decays") is exactly
right and is now paid for; #32/#33's `plant#61` blocker needs re-diagnosing per
§1.9; and any number derived through `soil_moist_from_psi` is wrong by 8.19×.

---

## 3. What to do, in order

The first three are forward-model fixes that need no AD work and no design
decision, and two of them are one line each.

1. **`soil_consumption_.assign(...)`** (§1.1). One word. Removes the ordering
   dependence and unblocks report 01's own acceptance test. Re-bless TF24
   baselines.
2. **Zero `soil_consumption_` and `E_up_` in `set_shutdown_state`** (§1.2).
   Three lines. Latent at the default driver, load-bearing in the transients.
3. **`soil_moist_from_psi`'s missing `* 1e6`**, plus a round-trip test (§1.4).
   Then re-derive any recorded moisture threshold that used it.
4. **Take the double-counted leaf respiration to the hydraulics owner** (§1.3),
   together with the `a_bio · a_y` treatment of hydraulic cost and the `83.26`
   root-mass scale. This is the largest ecological question in the file and the
   only finding here I should not decide.
5. **Decide `establishment_probability`'s gate** (§1.9, report 00 §10 item 4) —
   and while it is open, fix TF24f's per-individual path so the two models agree
   on a bare `Individual`. Develop already has the precedent (`P_pos`) and the
   sizing method (`storage_prod_eps`, measured well-sized in report 00 §9b).
6. **Size the resource vector by resource count, not ODE width** (§1.6). Removes
   four NaNs per stage and one structural disagreement.
7. **Then the leaf's reverse pass.** `Π_pp` is measured (`scripts/curvature_probe.R`) and
   the interior case is well conditioned; what remains is the bound-pinned case and
   `∇(∂Π/∂p)`. Both come after items 1 and 2, because those change what the forward pass
   they are verified against computes. The ordered work list is `../build-plan.md` §5–§6.

Housekeeping, batchable: delete or write the `assimilation` aux (§1.5); delete
`compute_roots`, the dead constructor local, and the ignored `rescale_usually`
argument; either fix `lambda_` or unexport the Sperry profit path (§1.10).

---

## 4. What would falsify this

Stated as checks, so the answer is a number.

- **The deep-layer carry-over does not reach the soil.** Instrument
  `Patch::compute_rates` to log `resource_depletion[3]` and
  `resource_depletion[4]` with and without the `.assign` fix on one production
  run. If the difference is zero, the stale layers are being multiplied by a leaf
  area small enough not to matter and this is cosmetic. Predicted: nonzero, and
  concentrated in the first few years while the stand is short.
- **The respiration double count is not one.** If `r_l`'s 39.27 was calibrated
  against a model that already netted out `R_d_`, then the pair is right and only
  the naming is wrong. That is a question for the parameterisation's provenance,
  not for the code, and it is the one way §1.3 dissolves.
- **`max_soil_layer` never actually falls short in a coupled run.** The 33.78%
  above is computed from recorded heights through the same `Q` loop, not read from
  the leaf. Read `leaf.max_soil_layer` directly per solve and compare. A
  mismatch means the root-distribution loop does something the reimplementation
  does not.
- **The shut-down carry-over is unreachable even in the transients.** Report 00
  measured zero incidence at the default driver. Re-run the committed rainfall
  banks with the shut-down exits instrumented. Zero there too would make §1.2
  genuinely dead code rather than latent.
