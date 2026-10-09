# Vocabulary of items 5–8, in context

This catalog lists every name that items 5–8 introduce, and the state weights
before them. That covers odelia `ODELIA-54`/`55` and the state weights, and plant
`PLANT-103`–`110`. Each name is shown where it is used and judged against the
style in AGENTS.md:

- Does it name what happens or what it is?
- Is it free of metaphor?
- Is it defined by what it is, rather than by what it is not?
- Does it carry a concept down a layer that already describes itself (shallow)?
- Is the abstraction the right size, neither more nor less than the change needs?

Heads: odelia `ODELIA-55` 512cd73; plant `PLANT-110` e10e78a6.

Each name gets one of three verdicts:

- **keep**;
- **rename** (with a proposal);
- **remove**, because a structural change makes it unnecessary.

Proposals are listed in the last section and are not yet made, except those
marked *done*.

## The five decisions

### 1. What `ode_alone_slopes` / `ode_alone_ends` achieve, and the clean fix

**What they carry.** Some steps take the soil alone. For each such step, the two
fields record what the run chose:

- the **slope** along which the plants' uptake was extrapolated over the step;
- the **ends** of the soil's inner steps, as fractions of the step.

They travel inside `Parameters`. A pinned replay then repeats that step's soil
integration exactly. A pinned replay is `run_scm()` on a run's parameters: at a
nudged θ for central differences, or at an invader's θ on a shared grid. The
reverse sweep does not use these fields: it reads the same record from the
solver's recording in C++.

**Why a replay needs them.** Without the record, a replay has two options, and
both fail:

- *Step the soil with the rest at the recorded step size.* That step is longer
  than the soil's stability limit, which is the reason it was taken alone.
- *Choose new inner steps.* Then the grid moves with θ, and the answer stops
  being a smooth function of the traits ("Stable", items 1–2 of OBJECTIVES.md).

The slope is a choice of the controller, like the step size. A replay has no
previous adaptive step to compute it from: `slope_base_` is reset on a replay.
Holding the slope as a recorded constant also keeps each row's map
self-contained for the sweep.

**What is wrong with the current form.** A program crosses into R as four
parallel vectors:

```cpp
// parameters.h
std::vector<double> ode_times;
std::vector<double> ode_step_sizes;
std::vector<std::vector<double> > ode_alone_slopes;
std::vector<std::vector<double> > ode_alone_ends;
```

The C++ already holds one object per step:

```cpp
// odelia ode_interface.hpp: the program's row
struct instruction {
  double time;
  double step_size;
  bool insertion = false;
  std::optional<alone_steps> alone{};
};
```

The comment on that very struct explains why four parallel vectors are a hazard
("Two vectors side by side can also be paired across different runs; one
cannot"). So `Parameters` splits the instruction into four vectors, and
`NodeSchedule::r_set_ode_steps(times, sizes, slopes, ends)` puts them back
together. Three pieces of code exist only to defend that split:

- `alone_field()`, which pulls one field out of every step;
- a check that the four lengths agree;
- a check that a step carrying a slope also carries its ends.

`design-soil-alone.md` already lists this as a cost ("A program now carries four
fields through R, not two").

**The clean fix:** one field, `Parameters$ode_steps`, the program itself.

- **C++.**
  - `Parameters` holds `std::vector<odelia::ode::instruction> ode_steps` (not
    insertion rows: a replay derives those from the node schedule).
  - One Rcpp `as`/`wrap` pair converts between that vector and an R data frame.
    The frame has the columns `time` and `step_size`, plus an optional list
    column `alone`, each element `NULL` or `list(slope =, ends =)`.
  - `make_node_schedule` passes the vector straight to the NodeSchedule's
    `ode_steps`, which is already that type.
- **R.**
  - A grid is `data.frame(time = times, step_size = NaN)`.
  - Carrying a run's program to another `Parameters` is one assignment.
- **What goes.**
  - `ode_step_sizes`, `ode_alone_slopes` and `ode_alone_ends` on `Parameters`;
  - their three getters on `SCM` and on `NodeSchedule`;
  - the four-argument setter;
  - `alone_field()`;
  - both pairing checks.
- **What stays.** The checks on times and sizes: the first time is 0, the last is
  `max_time`, times are sorted, and the first size is NaN.
- **`scm$ode_times`** stays as a read-only getter, derived from the recording.
  Reading cannot mis-pair, and it is read 56 times in 14 files to line outputs up
  with steps.
- **Size of the change.**
  - Hand-written R never reads the size or soil fields. Only the generated
    bindings and three test files do (`test-scm.R`, `test-strategy-tf24.R`,
    `test-node-schedule.R`).
  - `p$ode_times <-` appears 11 times in 7 files.
  - `ode_step_sizes` appears 37 times in 10 files.
  - `set_ode_steps` appears 25 times in 6 files.

  So the migration touches about ten files, mostly tests.
- **Where it lands.** `ode_step_sizes` predates this epic, so the change gets its
  own issue on top of `PLANT-110` rather than an amendment to `PLANT-105`.

### 2. `R0`, and `J` as a word *(done)*

- **`control_window()`.**
  - The argument `R0` and the local `R` are now `share_left` and `left`.
  - The ceiling `100` became the argument `factor_limit`.
  - Its documentation says "share of offspring production left to earn"
    (`PLANT-106` 4533a304).
- **`diagnose_scm()`** no longer says `J`:
  - The quantity row is `"log_offspring_production"`.
  - The local is `offspring <- sum(scm$offspring_production)`.
  - The documentation gives the derivatives in words.
  - The stand's run is labelled `"stand"`, not `"resident"`, which AGENTS.md
    bans (`PLANT-110` e10e78a6).
- **Elsewhere.** No C++ or R in the epic names `J` or `R0`. The plant words are:
  - `offspring_production`, the total;
  - `offspring_produced_survival_weighted`, the node's accumulated state.

### 3. The C++ accessor *(done, one rename proposed)*

The share left to earn is now read from C++ rather than reconstructed in R:

```cpp
// scm.h (PLANT-106)
std::vector<double> r_offspring_production_by_step() const;
```

```r
## scm_support.R, control_window()
left_after <- function() {
  earned <- pilot$offspring_production_by_step
  list(time = pilot$ode_times, left = 1 - earned / earned[length(earned)])
}
```

**Prediction miss:** `_by_step` reads as each step's increment, but the value is
cumulative. The test checks that it is sorted and ends at
`sum(offspring_production)`.

**Rename:** `offspring_produced_at_ode_times`.

- "Produced" is plant's word for an accumulated amount, as in the node state
  `offspring_produced_survival_weighted`.
- "At ode_times" names the vector it lines up with.

### 4. `uptake_share()` needs more work — agreed

```cpp
// tf24_environment.h
// The uptake's share, at the last evaluation, of what the layers take in,
// drain and lose to the plants, summed over the layers.
double uptake_share() const {
  double taken = 0.0, moving = 0.0;
  for (size_t i = 0; i < n_resources(); ++i) {
    const double in = to_passive(i == 0 ? vars.rate(soil_number_of_depths + 1)
                                        : water_flux[i - 1]);
    const double u = std::abs(to_passive(resource_uptake[i]));
    taken += u;
    moving += std::abs(in) + std::abs(to_passive(water_flux[i])) + u;
  }
  return taken / moving;
}
```

It feeds one decision:

```cpp
// patch.h
bool steps_alone() const requires SoilStepsAlone<E> {
  return environment.uptake_share() < control.ode_soil_alone_share;
}
```

**What the share decides.** It decides cost, not accuracy. A step taken alone
still passes the error test, because the coupling's error replaces the soil's
own. The share picks the cheaper of two options:

- inner steps under the soil's stiffness;
- outer steps cut to the soil's stability limit.

**Four defects.**

1. **Each flow between layers is counted twice**, once as layer i's drainage and
   once as layer i+1's inflow. The share is therefore diluted by the internal
   flows. A profile with more layers dilutes more, so the number of layers, a
   discretisation choice, changes which steps go alone.
2. **The sum hides the layer that matters.** Take a dry root layer whose drainage
   is tiny (k ∝ θ^(2n+3)), so uptake is most of its budget. A wet top layer with
   large infiltration can hide it. The summed share is a weighted average of the
   per-layer shares, so it is never above the largest of them.
3. **0/0 is NaN when nothing moves.** `NaN < 0.1` is false, so the soil stays
   coupled. Here the outcome happens to be harmless, but a NaN silently makes the
   decision.
4. **`vars.rate(soil_number_of_depths + 1)` is infiltration, read by its
   position.**

**Where 0.1 comes from.** It was registered once, in Q3, and never swept:
`design-soil-alone.md` says "Q3 named the share threshold … but did not test it".
The driver's `start_share` (in `mr_harness.diff`) has the same definition, so
gates G1–G7 measured this definition at 0.1. That is one point, not a
calibration.

**Proposal.** Take the largest over layers of uptake's share of that layer's own
flows, where a layer with no flows has share 0:

```cpp
// The largest share, over the layers, of a layer's flows that the plants take:
// uptake against inflow, drainage and uptake. A layer where nothing moves has
// none.
double uptake_share() const {
  double largest = 0.0;
  for (size_t i = 0; i < n_resources(); ++i) {
    const double u = std::abs(to_passive(resource_uptake[i]));
    const double flows = std::abs(to_passive(inflow(i))) +
                         std::abs(to_passive(water_flux[i])) + u;
    if (flows > 0.0) largest = std::max(largest, u / flows);
  }
  return largest;
}
```

- It counts each flow once per layer it touches.
- It does not dilute as layers are added.
- It is never NaN.
- `inflow(i)` names infiltration for the top layer and `water_flux[i - 1]` below
  it. This needs a named infiltration, which is a small change.
- The new share is never below the old one, so at 0.1 fewer steps go alone.

**Measurement before changing the default.** Run the G5 bank and the G6 timing
with the share at {0.1, 0.2, 0.3} under both definitions. For each record,
report:

- the fraction of steps taken alone;
- the runtime at matched error;
- `ln J` and the elasticities against ε.

Pick the threshold at the least runtime that keeps every record within ε/3 of
the coupled run. If the two definitions tie on runtime, keep the new one,
because a choice of discretisation then no longer changes the decision.

### 5. "`value` changes units by row" — explained

`diagnose_scm()` returns a table with one row per run and quantity (the
numbers are only illustrative):

```text
 run    quantity                  value      half    quarter  error  ratio
 stand  log_offspring_production  -3.21      ...
 stand  lma                       -0.84      ...    # elasticity: d log J / d log lma, unitless
 stand  theta_c                    0.0123    ...    # NOT an elasticity: d log J / d theta_c
```

The code that fills `value`:

```r
theta <- vapply(names(grad), function(n) pars[[n]], 0)
c(out, ifelse(theta == 0, 1, theta) * grad / offspring)
```

**Why rows differ.** An elasticity is θ·(dJ/dθ)/J, which needs log θ, and log 0
does not exist. So for a trait whose value is 0, the code multiplies by 1
instead of θ.

- That row's `value` is d ln J / dθ, measured per unit of θ.
- Every other trait row is a unitless elasticity.
- Four TF24 defaults are 0: `theta_c`, `recruitment_decay`, `dmass_dN` and
  `TF24_floor_lambda_o`.

**Why it matters.** Comparing the column against ε (which is set in elasticity
units), sorting it, or plotting it mixes the two kinds of row without warning.

**The same in `distance`.** It is log(θ′/θ) except where θ = 0, where it is
θ′ − θ.

**Proposal.** One column, one unit, which is the tidy form `distance` already
uses with its `parameter` column:

```text
quantities: run, quantity, parameter, value, half, quarter, error, ratio
  quantity ∈ "log_offspring_production" (parameter NA),
             "elasticity"  (θ ≠ 0),
             "derivative"  (θ = 0: d log offspring production / d θ)
distance:   run, parameter, scale, distance
  scale    ∈ "log_ratio" (θ ≠ 0), "difference" (θ = 0)
```

Now every row says what its number is, and the arithmetic stays as it is.

## The catalog

### A. Taking a block alone — odelia

Superseded by `names-subsystem.md`, which renames this vocabulary from
odelia's data structure up, in sections A and B.

| Name | In context | Verdict |
|---|---|---|
| `StepsBlockAlone` | `concept StepsBlockAlone = requires(...) { s.alone_block(); s.steps_alone(); s.alone_inputs(out); s.alone_rates(time, y, y, out); }` | **keep.** Names the capability, in the same pattern as `SplitsSignChanges` and `ScalesTolerances`. |
| `alone_block()` | `const auto [first, n] = system.alone_block();` — "the block [first, first + n) that reads the rest only through one input per component" | **keep.** "Block" means a contiguous range of the state, which is also what the split's `split_blocks` means, so the word is used consistently. |
| `steps_alone()` | `takes_alone = method == Method::rkck && system.steps_alone();` | **keep.** This is where the System decides, per step. |
| `alone_inputs(u)` | `system.alone_inputs(inputs);` | **rename → `block_inputs`.** The inputs are not alone; they are the block's. |
| `alone_rates(t, y, u, out)` | `sys.alone_rates(time + u * h, block, line, out);` | **rename → `block_rates`.** These are the block's rates under the given inputs. |
| `alone_steps {slope, ends}` | `std::optional<alone_steps> alone{};` on `instruction` | **keep the field `alone`** (present means the step took the block alone). The type reads as "steps that are alone"; `block_steps` is an option but no clearer. **Keep.** |
| `choose_alone_steps` | `alone = stepper.choose_alone_steps(system, time, step_size, y, dydt_in, inputs, slope, step_size_min);` | **keep.** A verb and an object. |
| `take_step_alone` | `block_error = take_step_alone(system, solved, time, h, y, k, y, *alone, inputs, alone_samples.emplace());` | **keep.** It is the counterpart of `take_step`. |
| `alone_tol` | `static constexpr double alone_tol = 1e-9; // The inner steps' relative tolerance` | **rename → `inner_tol`.** The comment already says "inner steps". |
| `alone_stops` | `for (const double stop : alone_stops) { while (from < stop) ...` — the fractions every inner-step sequence must land on: each stage's, and each sample's | **rename → `inner_step_stops`.** "Stop" is established vocabulary in this codebase (step 1, "stops become step targets"). |
| `alone_samples`, `block_samples<S>` | `struct block_samples { std::size_t first; std::array<std::vector<S>, 5> at; };` — the block at each sample fraction, from the predictor | **keep `block_samples`; rename the member `alone_samples` → `predictor_samples`.** That says whose samples they are. |
| predictor / corrector | `// The predictor, under the inputs the record's slope extrapolates, keeps the block at each stop.` / `// The corrector, to the inputs at the stage at t + h` | **keep.** Standard numerical terms, used literally. |
| `pass` (lambda) | `auto pass = [&](const std::vector<S>& to, auto&& at_end) { ... integrate_pieces(...) }` — one integration of the block over the inner steps | **keep.** Local, and its comment defines it. |
| `predicted_inputs` | `pass(predicted_inputs(u0, alone.slope, h), ...)` | **keep.** |
| `rates_on_line` | `rates_on_line(sys, time, h, u0, to)` — the rates under inputs interpolated on a straight line from `from` to `to` | **keep.** Geometric and literal. |
| `on_line`, `with_inputs`, `along_line` (locals) | `sys.alone_rates(..., stage_inputs[i - 1], with_inputs); on_line(ah[i - 1], b, along_line); error[q] += ... abs(with_inputs[q] - along_line[q]);` | **rename → `at_stage_inputs`, `on_corrector_line`, `corrector_rates`.** As written, a reader has to work out which rate comes from which inputs. |
| `at_fraction`, `stage_inputs`, `stage_at_end`, `inputs_at_end`, `predicted_end`, `block_error` | locals of `take_step_alone` | **keep.** Each is literal. |
| `step_piece` | `step_piece(own, r, from, end, h, rates, next);` — one Cash–Karp step over part of a step | **keep.** Shared with the split's `integrate_pieces`. |
| `slope_base_` | `struct slope_base { state_type inputs; double step_size; }; std::optional<slope_base> slope_base_;` | **rename → `last_inputs_`** ("the block's inputs at the last accepted step's start, and its size"). "Base" makes the reader decode what the slope is taken from. |
| `takes_alone` | `bool takes_alone = false;` in `SolverInternal::step` | **keep.** |
| `ScalesTolerances`, `tolerance_factors(time, f)` | `if constexpr (ScalesTolerances<System>) system.tolerance_factors(time_orig, factors);` | **keep.** The words say what it does. |
| `ode_control.hpp` comment | `// ... Without them the level is errlevel()'s alone.` | **reword.** It uses "alone" in another sense, two files from the concept that owns the word. |

**How much "alone" is too much?** Thirteen odelia identifiers carry "alone".
With the renames above, eight remain, and in each the word means what it says:

- the concept `StepsBlockAlone`;
- `alone_block()`, the block that can be taken alone;
- the System's decision `steps_alone()`;
- `choose_alone_steps`;
- `take_step_alone`;
- the solver's `takes_alone`;
- the record `alone_steps` and its field `alone`.

Everything else names the block, the inner steps, or the predictor.

### B. Taking the soil alone — plant

| Name | In context | Verdict |
|---|---|---|
| `SoilStepsAlone` | `concept SoilStepsAlone = requires(const E& e, ...) { e.alone_inputs(u); e.alone_rates(time, u, u, u); { e.uptake_share() } -> ...; };` | **rename → `RatesSoilUnderUptake`**, with the requirements below. It should describe what the environment can do, not what the step does. |
| Patch's `alone_block`, `steps_alone`, `alone_inputs`, `alone_rates` | `void alone_inputs(std::vector<value_type>& u) const requires SoilStepsAlone<E> { environment.alone_inputs(u); }` | **keep in Patch**, because Patch is the System, so the odelia names belong here. |
| TF24's `alone_inputs(u)` | `void alone_inputs(std::vector<S>& u) const { u = resource_uptake; }` | **remove.** It is a getter with an odelia name for the public member `resource_uptake`. Patch reads `environment.resource_uptake` itself. |
| TF24's `alone_rates(t, θ, u, rate)` | evaluates rainfall at `t`, then calls `layer_rates(rainfall, theta, u, rate, nullptr, note)` | **rename → an overload `layer_rates(time, theta, uptake, rate)`**: the layers' rates at a time, under a given uptake. |
| `layer_rates(rainfall, θ, u, rate, drainage, note)` | the one body `compute_rates` and the step taken alone share | **keep.** |
| `infiltrated_share(θ)` | `const U share = infiltrated_share(theta[0]); ... rainfall * max(U(0.0), share)` | **keep.** |
| `conductivity(θ, layer)` | `const U k = conductivity(t, i);` | **keep.** |
| `uptake_share()` | see decision 4 | **redefine** (decision 4). |
| `ode_soil_alone_share` (Control) | `environment.uptake_share() < control.ode_soil_alone_share` | **keep.** It is the threshold on that share. |
| `ode_alone_slopes`, `ode_alone_ends`, `alone_field`, `r_ode_alone_*`, `r_set_ode_steps(times, sizes, slopes, ends)` | see decision 1 | **remove** under decision 1. |

**The shallow concepts.** Before the fix, odelia's vocabulary runs two layers
down: odelia → Patch → TF24_Environment. The environment gains two methods that
mean nothing in soil terms. After it, the boundary is at Patch, the one class
that is an odelia System:

```cpp
// patch.h, after
void block_inputs(std::vector<value_type>& u) const requires RatesSoilUnderUptake<E> {
  u = environment.resource_uptake;
}
template <class U>
void block_rates(double t, const std::vector<U>& y, const std::vector<U>& u,
                 std::vector<U>& out) const requires RatesSoilUnderUptake<E> {
  environment.layer_rates(t, y, u, out);
}
```

The environment then speaks only of uptake, layers, infiltration and
conductivity.

### C. Tolerance factors

| Name | In context | Verdict |
|---|---|---|
| `ode_tol_factor_soil`, `ode_tol_factor_accumulator` | "multiplies each state's error level" on the soil layers and the flux accumulators | **keep.** |
| `ode_tol_factor_times`, `ode_tol_factor_values` | `factor = control.ode_tol_factor_values.at(upper_bound(times, time) - begin - 1)` | **keep, with a note.** This is another pair of parallel vectors. `validate_ode_tol_factors` checks them, and `control_window()` writes both together. A data frame would match decision 1's form, but `Control` is a flat RcppR6 class and only one writer exists. The pair is only worth replacing once a second writer appears. |
| `ode_tol_factor_max` | `x = std::min(x * factor, control.ode_tol_factor_max);` | **keep.** |
| `validate_ode_tol_factors` | called where `Control` is used | **keep.** |
| `Patch::tolerance_factors(time, w)` | `w.assign(ode_size(), 1.0); ...` | **rename the parameter `w` → `f`.** `w` is left over from "weights". |

### D. The schedule of factors from a pilot

| Name | In context | Verdict |
|---|---|---|
| `control_window(pilot, invaders, base, share_left, factor_limit)` | sets `ode_tol_factor_times/values` | **rename → `control_tol_factors()`.** "Window" is a picture word, and the documentation has to define it ("the window late in a run where …"). The function sets the tolerance factors from a pilot, alongside `control_accurate` and `control_tf24`. |
| `pilot` | "A run of the analysis on the birth-date coordinate … a coarse stand at a loose tolerance serves" | **keep.** "Pilot run" is plain scientific English. |
| `share_left`, `factor_limit`, `left`, `left_after`, `earned` | `1 / pmin(pmax(left / share_left, 1 / factor_limit), 1)` | **keep.** *Done* this round. |
| `offspring_production_by_step` | see decision 3 | **rename → `offspring_produced_at_ode_times`.** |
| `invaded` (SCM getter) | `if (pilot$invaded) stop("control_window() reads a pilot no invader has walked")`; `bool invaded() const { return !invaded_run.empty(); }` | **keep.** It matches `invaded_run`, which predates the epic. |

### E. The spread crowns

| Name | In context | Verdict |
|---|---|---|
| `crowns_per_interval` | `static constexpr int crowns_per_interval = 8;` | **keep.** |
| `for_each_interval_crown(node, end, visit)` | `visit(h + lambda * (end.height() - h), at_node * (2 (1 - lambda) / 8) + at_end * (2 lambda / 8))` | **keep.** A crown here is literal: leaf area under a top height, with the canopy's Q profile below it. It stands for the plants born in one eighth of the interval. |
| `for_each_crown_between_nodes` | used twice: the field build and the sum without the boundary | **keep.** It has two callers. |
| `add_crown(sum, top, leaf_area, height)` | `if (height <= top) { ... sum.value += leaf_area * Q; sum.slope -= leaf_area * q; }` | **keep.** |
| `crown {top, leaf_area, mom}` | `crown& c = crowns.emplace_back(crown{top, leaf_area, {}}); crown_moments(1.0 / top, c.mom);` | **rename `mom` → `moments`.** Rename the local alias `moments` → `moment_array` so the two don't collide. |
| `lambda` | `const double lambda = (s + 0.5) / crowns_per_interval;` | **rename → `u`**, odelia's word for a fraction of an interval. `lambda` is otherwise TF24's light parameter (`TF24_floor_lambda_o`). |
| `at_node`, `at_end` | the leaf area each end of the interval contributes | **keep.** |

### F. Walking by birth date

| Name | In context | Verdict |
|---|---|---|
| `recorded_birth_dates`, `set_/get_recorded_birth_dates` | `const double born = recorded_birth_dates.at(run_block.block); ... util::identical(n.introduction_time(), born)` | **keep.** Patch holds the dates because `take_recorded_splits` reads them; SCM writes them once. |
| `add_entry(time)` | `// An entry at time that introduces nothing and acts on nothing, unless one is there already.` | **keep the name; reword the comment.** As written it defines the entry by what it is not. Proposed: "Ensures the schedule stops at `time`, adding an empty entry where none is there." |

### G. `diagnose_scm()`

| Name | Verdict |
|---|---|
| `quantities`, `distance`, `failures`, `introductions` | **keep.** Change the columns as in decision 5. |
| `value`, `half`, `quarter`, `error`, `ratio` | **keep `value`, `error`, `ratio`.** `half` and `quarter` read like value/2 and value/4. They are the runs at every other and every fourth introduction. **Rename → `every_other`, `every_fourth`**, which match the local `every_other()`. |
| `measure`, `fail`, `every_other` (locals) | **keep.** |
| `"stand"` run label, `log_offspring_production` | *done*. |

## Code organisation

1. **`SolverInternal::step` carries 25 lines of setup for the block taken
   alone:** the slope from `slope_base_`, and the block's factors set to the
   tightest factor outside it. They interrupt the step's flow.

   **Proposal:** extract a private helper

   ```cpp
   bool prepare_block_alone(System&, std::vector<double>& factors,
                            state_type& inputs, std::vector<double>& slope)
   ```

   The step then reads as it did before the epic, plus one call.
2. **`ode_step.hpp` is 959 lines, about 210 of them for the block taken alone.**
   Those 210 are `choose_alone_steps`, `take_step_alone`, `predicted_inputs`,
   `rates_on_line`, `block_samples` and `inner_step_stops`. They are members,
   because they use the tableau and `integrate_pieces`.

   **Proposal:** move their out-of-line definitions to `ode_step_alone.hpp`,
   included at the end of `ode_step.hpp`. A reader of the ordinary step then
   never passes through them. This is moderate value at small cost; take it
   only alongside other changes to those functions.
3. **`R/scm_support.R` (562 lines) mixes three kinds of function:**
   - the control presets: `control`, `control_accurate`, `control_tf24`,
     `control_window`;
   - the 100-line `diagnose_scm`;
   - run helpers: `run_scm`, `export_patch_state`, `make_initial_state`.

   **Proposal:** move `diagnose_scm` to `R/diagnose_scm.R` and the presets to
   `R/control.R`. This is a pure move.
4. **`species.h` (1393 lines) and `patch.h` (2013 lines)** grew by the crowns and
   the soil hooks. The crowns sit next to the field build that uses them, and
   the hooks next to `tolerance_factors`. **No move proposed.**

## Proposals, ranked by what they remove

| # | Change | Removes | Where |
|---|---|---|---|
| 1 | `Parameters$ode_steps`, one program (decision 1) | 3 fields, 6 getters, a 4-argument setter, `alone_field`, 2 pairing checks | new plant issue on `PLANT-110` |
| 2 | Odelia hooks named by the block; TF24 speaks soil (B) | 2 TF24 methods, the odelia vocabulary in the environment | `ODELIA-55`, `PLANT-105` |
| 3 | `uptake_share` per layer, then measure (decision 4) | double counting, NaN, the dependence on the number of layers | `PLANT-105`, then a G5/G6 run |
| 4 | Tidy `diagnose_scm` columns (decision 5) | mixed units in a column | `PLANT-110` |
| 5 | Renames: `slope_base_`, `alone_tol`, `alone_stops`, `alone_samples`, the error locals, `control_window`, `offspring_production_by_step`, `half`/`quarter`, `mom`, `lambda`, `w`; two comments | names the reader must decode | the branch that owns each |
| 6 | `prepare_block_alone`; the R file moves | none, but the flow reads straight | `ODELIA-55`; `PLANT-110` |
