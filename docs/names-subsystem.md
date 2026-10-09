# Naming the soil's substeps, from odelia up

This is the naming turn after the vocabulary catalog (`vocabulary-items-5-8.md`).
"Alone" is opaque, so this starts again from the data structure in odelia. The
names follow from that structure: odelia's names first, then plant's, which
become soil-specific. The step's control flow is drawn so that each name can be
read where it is used. Nothing is renamed yet: this is the proposal to approve.

## The data structure

A System's state has a contiguous **subsystem**, TF24's soil layers. The
subsystem's rates read the rest of the state only through **inputs**, one per
subsystem component; for TF24 these are the uptake from each layer:

```
y = [ plants ............ | soil layers ]
                            └─ subsystem: ds/dt = g(t, s, u),  u = uptake from each layer
```

On a step where the coupling is weak, the outer Cash–Karp step does not take the
subsystem through its stages. It integrates the subsystem over **substeps** of
its own, with the inputs moving along a line over the step:

- the **predictor** pass extrapolates the inputs along the last step's slope;
- the **corrector** pass runs the inputs from the start to their value at t + h.

What a replay or the sweep must repeat is the **record** of those substeps: the
inputs' slope and where each substep ends. It is per step and optional:

```cpp
// How a step integrated the System's subsystem in substeps: the slope its
// inputs were extrapolated along, and where each substep ends, as fractions of
// the step.
struct subsystem_substeps {
  std::vector<double> input_slope;
  std::vector<double> ends;
};

struct instruction {
  double time;
  double step_size;
  bool insertion = false;
  std::optional<subsystem_substeps> subsystem{};  // present where the step substepped it
};
```

Three nouns cover it: the **subsystem**, its **inputs**, and the **substeps**.
Every name below is built from them.

### Why "substep", not "piece"

The sign-change split already integrates a node's state over parts of a step
(`integrate_pieces`, `step_piece`). The subsystem's substeps run through
**the same function**, with the substep ends standing in for the sign changes.
One word for one mechanism makes that sharing visible. "Substep" is one word and
the standard term for a step inside a step, so the split adopts it too:

- `integrate_pieces` → `integrate_substeps`
- `step_piece` → `take_substep`
- "in pieces between the sign changes" → "in substeps meeting at the sign changes"

You suggested `partial_step`. It works if you prefer it, but it is longer and
reads as an incomplete step rather than a step within one.

## Control flow, with the new names

### One adaptive step (`SolverInternal::step`)

```
SolverInternal::step(system)
│
├─ factors ← system.state_tolerance_factors()               the System's layout
├─ if HasSubsystem<System> and method is rkck:
│    substep_subsystem ← system.subsystem_weakly_coupled()   TF24: uptake share < ode_soil_substep_share
│    if substep_subsystem:
│       u0          ← system.subsystem_inputs()              the inputs at the step's start
│       input_slope ← (u0 − last_inputs_.inputs) / last_inputs_.step_size
│       factors over the subsystem ← the tightest factor outside it
│
└─ loop (retries on rejection):
     if substep_subsystem:
        substeps ← stepper.choose_substeps(system, t, h, y, dydt, u0, input_slope)
     stepper.step(system, …, substeps, u0)                  ─┐ see the next diagram
     accept or shrink h                                      │
     on accept:                                              │
        record {t, h, subsystem = substeps}                  │
        last_inputs_ ← {u0, h}                              ─┘
```

### Inside the step (`Step::take_substepped_step`)

```
fraction of the step  0     .2 .25 .3      .5   .6   .75  .875   1
substep ends          |--|---|--|--|-----|----|----|-----|-----|
                      choose_substeps lands on every stage and sample fraction

1. predictor   integrate_subsystem(u0 → extrapolated_inputs(u0, input_slope, h))
               keep the subsystem at each stage and sample fraction
2. stages      each Cash–Karp stage: the rest from the tableau, the subsystem from
               the predictor; evaluating the System there leaves that stage's inputs
3. corrector   integrate_subsystem(u0 → inputs at the stage at t + h)
               its end is the step's end for the subsystem
4. error       the subsystem's error = max(|corrector − predictor| at the end,
                                           the stages' input defect from the corrector's line)
```

The body as it would read. This replaces the sentence "The predictor, under the
inputs the record's slope extrapolates, keeps the block at each stop":

```cpp
// Predictor: the subsystem over the substeps, its inputs extrapolated from u0
// along the recorded slope. Kept at each stage and sample fraction.
const auto predicted =
  integrate_subsystem(sys, time, h, y0, k, substeps.ends, u0,
                      extrapolated_inputs(u0, substeps.input_slope, h),
                      keep_at(stage_and_sample_fractions));

// Stages: the rest from the tableau, the subsystem from the predictor. Each
// evaluation leaves that stage's inputs on the System.
for (int i = 1; i < 6; ++i) {
  stage_state(i, y0, k, h, stage);
  place_subsystem(predicted.at(ah[i - 1]), stage);
  ode::derivs(sys, stage, k[i], stage_time(i, time, h), solved.stages[i - 1]);
  sys.subsystem_inputs(stage_inputs[i - 1]);
}

// Corrector: the subsystem again over the same substeps, its inputs on the
// line from u0 to those at the stage at t + h. Its end is the step's.
const std::vector<S> end = integrate_subsystem(sys, time, h, y0, k, substeps.ends,
                                               u0, stage_inputs[stage_at_end]);

// Error: how far the corrector ends from the predictor, or how far the stages'
// inputs stray from the corrector's line, whichever is larger.
```

`keep_at` and `place_subsystem` are sketch helpers for copying the predictor's
subsystem in and out; the real body may inline them.

`rates_on_line` becomes the verb `integrate_subsystem(…, from, to)`: integrate
the subsystem over the substeps with its inputs moving linearly from `from` to
`to`. The predictor, the corrector and `choose_substeps` all call it, and the
line rate closure becomes a detail inside it.

### Replays, walks and the sweep

```
program step (a replay, pinned or at a nudged θ)
   row.subsystem present, and not a walk → u0 ← system.subsystem_inputs();
                                           take_substepped_step(row.subsystem)
walk at double                         → steps the subsystem with the rest: its
                                           evaluations read the run's recording,
                                           so its own subsystem is never read
walk at an active scalar, row substepped → refused
reverse sweep, row substepped           → take_substepped_step at the active scalar,
                                           u0 read off the evaluation at the row's start
```

## Old → new

### odelia

| Now | Proposed | How it reads in place |
|---|---|---|
| `StepsBlockAlone` | `HasSubsystem` | `if constexpr (HasSubsystem<System>)`: what the System has, not what the step does |
| `alone_block()` → `pair<first, n>` | `subsystem()` → `state_range{first, size}` | `const auto [first, size] = system.subsystem();` |
| `steps_alone()` | `subsystem_weakly_coupled()` | `substep_subsystem = system.subsystem_weakly_coupled();` the System reports a fact; the solver acts on it |
| `alone_inputs(u)` | `subsystem_inputs(u)` | `system.subsystem_inputs(u0);` |
| `alone_rates(t, y, u, out)` | `subsystem_rates(t, s, u, out)` | `sys.subsystem_rates(t, s, u, out);` |
| `alone_steps {slope, ends}` | `subsystem_substeps {input_slope, ends}` | `row.subsystem->ends` |
| `instruction::alone` | `instruction::subsystem` | `std::optional<subsystem_substeps> subsystem;` |
| `choose_alone_steps` | `choose_substeps` | `substeps = stepper.choose_substeps(system, t, h, y, dydt, u0, input_slope);` |
| `take_step_alone` | `take_substepped_step` | the counterpart of `take_step` |
| `pass` (lambda) + `rates_on_line` | `integrate_subsystem(…, from, to)` | the verb; see the body above |
| `predicted_inputs` | `extrapolated_inputs` | it extrapolates along the slope, held at zero rather than changing sign |
| `alone_stops` | `stage_and_sample_fractions` | says exactly what the fractions are |
| `at_fraction(u)` | `predicted.at(u)` | the predictor's subsystem at fraction u |
| `block_samples<S>` | `subsystem_samples<S>` | the predictor's subsystem at the five sample fractions, for the dense output |
| `alone_samples` (Step), `taken_step::alone` | `predicted_subsystem` | `taken_step::dense_state` reads the subsystem from it |
| `alone_tol` | `substep_tol` | the substeps' relative tolerance |
| `integrate_pieces`, `step_piece` | `integrate_substeps`, `take_substep` | shared with the split |
| `slope_base_` `{inputs, step_size}` | `last_inputs_` `{inputs, step_size}` | the subsystem's inputs at the last accepted step's start, and its size |
| `takes_alone` | `substep_subsystem` | `if (substep_subsystem) …` |
| `with_inputs`, `along_line`, `on_line` | `stage_rates`, `line_rates` | in the error estimate: rates under the stage's inputs against rates on the corrector's line |
| `ScalesTolerances`, `tolerance_factors(time, f)` | `ScalesStateTolerances`, `state_tolerance_factors(f)` | see C below: the time dependence moves to `OdeControl` |

After this, "alone" appears nowhere.

### plant

The odelia names stop at `Patch`, the one class that is an odelia System. Below
it the words are the soil's:

```cpp
// patch.h
// The soil layers, the environment's first states, which come last in the patch's.
state_range subsystem() const requires RatesSoilUnderUptake<E>;
bool subsystem_weakly_coupled() const requires RatesSoilUnderUptake<E> {
  return environment.uptake_share() < control.ode_soil_substep_share;
}
void subsystem_inputs(std::vector<value_type>& u) const requires RatesSoilUnderUptake<E> {
  u = environment.resource_uptake;
}
template <class U>
void subsystem_rates(double t, const std::vector<U>& theta, const std::vector<U>& uptake,
                     std::vector<U>& rate) const requires RatesSoilUnderUptake<E> {
  environment.layer_rates(t, theta, uptake, rate);
}
```

| Now | Proposed |
|---|---|
| `SoilStepsAlone` | `RatesSoilUnderUptake`: the environment rates its layers under a given uptake |
| Patch's `alone_block`, `steps_alone`, `alone_inputs`, `alone_rates` | odelia's four names, with bodies in soil words (above) |
| TF24 `alone_inputs(u)` | removed: Patch reads the public `resource_uptake` |
| TF24 `alone_rates(t, θ, u, rate)` | `layer_rates(time, theta, uptake, rate)`, an overload of the shared body |
| Control `ode_soil_alone_share` | `ode_soil_substep_share`: the soil is substepped on steps whose uptake share is below it |
| Parameters `ode_alone_slopes`, `ode_alone_ends` | under decision 1, the `soil_substeps` column of `ode_steps`. Without it, `ode_soil_input_slopes` and `ode_soil_substep_ends` |
| `alone_field`, the `r_ode_alone_*` getters | removed under decision 1 |
| `uptake_share` | keep the name; redefine it per layer (decision 4) |

## C — does `Patch` need to know about tolerance factors?

It needs half of them. `Patch::tolerance_factors(time, f)` does two jobs:

```cpp
f.assign(ode_size(), 1.0);
environment.tolerance_factors(control, f.end() - environment.ode_size());  // ① layout
factor = control.ode_tol_factor_values.at(upper_bound(times, time) - 1);    // ② schedule over time
for (double& x : f) x = std::min(x * factor, control.ode_tol_factor_max);  // ② bound
```

- **① Which states are soil and which are accumulators** is model knowledge. Only
  the System knows its layout, and the layout changes as nodes are inserted. This
  part stays a System hook, without the time: `state_tolerance_factors(f)`.
- **② The factor over time and the bound** need no model knowledge. They apply
  to every component alike, so they belong where odelia already adjusts the step
  against the tolerance: in `OdeControl`, beside `errlevel()`.

The resulting principle: odelia holds whatever needs no model knowledge. The
coupling threshold stays in plant for the same reason, because the uptake share
it compares against is TF24's.

That leaves `Patch` with layout only. It also removes the time argument from
the odelia concept, which becomes `ScalesStateTolerances`. "State" says whose
tolerances they are: each state component's. The time schedule is the part tied
up with the pilot, so its final shape belongs to the schedule design turn below.

## D — `control_window`, and the schedule design turn

`control_variable_tolerance()` describes what the function does today: it
returns a `Control` whose tolerance varies over time. But your other points
(`share_left`, `left` and `earned` unclear out of context, "pilot" hard to read,
and `refine_schedule`) all lead to the same question: how plant builds a run's
schedule. Answer that first and the names follow.

What exists now:

| Piece | What it chooses | How |
|---|---|---|
| `refine_schedule()` (C++, pre-epic) | introductions | runs, bisects every interval whose node error exceeds `schedule_eps`, and repeats up to `schedule_nsteps`. **Height coordinate only**: it refuses the birth-date coordinate ("give the node schedule directly") |
| `control_window(pilot, …)` | the tolerance over time | one coarse run (the pilot) plus walks give the share of offspring production still to come after each step, which sets the factor |
| `diagnose_scm()` | nothing; it measures | runs at every other and every fourth introduction give each quantity's node error and its ratio |
| the shared thinned schedule (6.4, decided) | which introductions an invader takes | the union of the walks' shares |
| `uptake_share` against `ode_soil_substep_share` | which steps substep the soil | per step, inside the run |

Seen together, the pilot is iteration 0 of a refinement: a coarse run that
measures where the answer comes from. `diagnose_scm` already measures where the
introductions fall short. So a single `refine_schedule` would do it all:

- it starts from a coarse default on the birth-date coordinate;
- it refines introductions where the node error is large;
- it sets the tolerance over time from where offspring production is still to
  come;
- it covers the invaders of the analysis;
- it stops at ε.

That would retire the word "pilot". `control_window`'s quantities become parts
of the refinement:

- `produced(t)`, the offspring production produced by t;
- `remaining(t) = 1 − produced(t)/produced(T)`;
- the factor `min(max_factor, loosen_below / remaining(t))`.

**Proposed design turn** (system-design skill, Tier 2–3, since it is public R
API). The question: *how plant builds the schedule a run of TF24 takes, from a
coarse default, to ε, for a stand and its invaders.* It starts from:

- `refine_schedule`;
- `control_window`;
- `diagnose_scm`;
- the 6.4 thinning;
- OBJECTIVES.md's "Shared" and "Performant".

It settles:

- whether the tolerance schedule lives in `Control` or in the schedule;
- C's split of the tolerance factors;
- the names above.

Until then, `control_window` keeps its current name rather than being renamed
twice.

## Code organisation, with what this round found

1. **The program travels as four fields copied by hand.** Only
   `refine_schedule()` writes a run's program into its `Parameters`. Every other
   caller copies the four fields itself, for example `test-scm.R:742`:

   ```r
   q$ode_step_sizes <- alone$ode_step_sizes
   q$ode_alone_slopes <- alone$ode_alone_slopes
   ```

   This is decision 1's case in practice. With `Parameters$ode_steps`, the copy
   becomes one assignment and can no longer mix two runs.
2. **The subsystem setup in `SolverInternal::step`.** Extract it, as before, to
   `prepare_subsystem(system, factors, u0, input_slope) → bool`.
3. **The time schedule of the tolerance factors lives in `Patch`** (C). It moves
   to `OdeControl`.
4. **The split and the substeps share `integrate_substeps`**, but the shared
   machinery sits in the middle of `ode_step.hpp` (959 lines). Move it, with the
   subsystem's members, into `ode_substeps.hpp`, so the ordinary step reads
   without them.
5. **`R/scm_support.R`** (562 lines) mixes the control presets, `diagnose_scm`
   and the run helpers. Split it into `R/control.R`, `R/diagnose_scm.R` and the
   rest.
6. **Patch's odelia hooks are scattered through `patch.h`** (2013 lines): the
   four subsystem hooks, `state_tolerance_factors`, `sign_values`, and the
   split's hooks. Gather them under one heading, "As an odelia System", so the
   boundary is one place to read.

## Order of work, once approved

1. odelia `ODELIA-55`: the subsystem names, `state_range`,
   `integrate_subsystem`, substeps shared with the split, and `ode_substeps.hpp`.
   The state-weights branch: `ScalesStateTolerances` (rename only; the time
   schedule moves with the design turn).
2. plant `PLANT-105`: Patch's hooks in soil words, `RatesSoilUnderUptake`,
   `layer_rates(time, …)`, `ode_soil_substep_share`, and the fields' names.
   `PLANT-102`/`103` take "substep" where the split says "pieces".
3. Rebase the stacks with `--update-refs`, rebuild, run both suites, and check
   that no number moves (these are pure renames).
4. Decision 1 (`ode_steps`) as its own issue on `PLANT-110`.
5. The schedule design turn, then `uptake_share` (decision 4), C's move and
   `control_window`'s fate together.
