# Cohort-granular reverse-mode gradients for the SCM

A proposal for obtaining exact trait gradients of SCM outputs at production
lifetime, addressed to plant maintainers. It concerns the memory cost of
reverse-mode automatic differentiation and how the structure of
`Patch::compute_rates` bounds it.

Numbers labelled **measured** were produced in this study and the command that
produced them is given. Numbers labelled **projected** are arithmetic on measured
quantities and are marked as such. Numbers taken from earlier work in this
repository are attributed to it.

---

## 1. The problem

Reverse-mode AD records every floating-point operation on a tape, then walks the
tape backwards to accumulate derivatives. The tape must be complete before the
reverse walk begins, so its peak size is the whole recorded computation.

For the SCM the recorded computation is the whole run. At TF24 production
settings the run has:

| quantity | value | how |
|---|---|---|
| node ODE states | **987** | `scm$patch$node_ode_size`, `max_patch_lifetime = 105.32` |
| cohorts | **141** | 987 / 7; `Node::ode_size()` is `state_size() + 2` (`node.h:79`) |
| environment ODE states | **9** | 5 soil layers + 4 cumulative-flux slots (`tf24_environment.h:52`) |
| accepted ODE steps | **2 829** | `length(scm$ode_times)`, `refine_schedule = FALSE` |
| leaf optimisations | **4 372 101** | instrumented count, this study |
| forward wall clock | **53.1 s** | same run |

Earlier work in this repository measured the reverse tape at approximately
**86 kB per node-ODE-state per step**, flat in stand width over the range it could
reach (widths 543–606). Multiplying out:

    987 states x 2 829 steps x 86 kB  ~=  220 GB          (projected)

That figure is why no TF24 gradient has been taken at production lifetime. The
same earlier work measured TF24 gradients succeeding at `max_patch_lifetime = 1`
(3.22 GB) and the kernel killing the process above 2.5.

Two families of remedy have already been tried in this repository and measured:

- **Recording fewer operations.** Crown preaccumulation at two boundaries (1.49x,
  3.7x), hoisting the query-factor `pow` (1.24x), and a leaner interpolant
  refinement (5.89x on the component, **0.018%** on TF24's total). Against a
  required factor of order 10^2–10^3 this is not a route.
- **Reusing one tape, rewound between units.** `xad::Tape::resetTo` keeps the
  gradient exact but does not release memory: peak grew 48 kB to 742 kB over
  60 to 960 units, and the time advantage reversed from 1.48x to 8.42x.

What follows is a third family: keep the tape complete, but make the *unit* that
is recorded a single cohort within a single ODE step rather than the whole run.

---

## 2. State at develop

### 2.1 The forward call chain, one accepted step

`SCM::run_next()` advances the ODE solver, which calls `Patch::set_ode_state(it,
time)` at every Runge-Kutta stage. That function (`patch.h:679-702` on develop) is
the whole per-stage computation and it runs in a fixed order:

```
Patch::set_ode_state(const_iterator it, double time)
  1  odelia::ode::set_ode_state(species.begin(), species.end(), it)
        Species::set_ode_state -> Node::set_ode_state -> Individual::set_ode_state
          per state slot:  vars.states[i] = *it++;
                           strategy->update_dependent_aux(i, vars)
          Node also:       set_log_density(*it++)  ->  density = exp(log_density)
  2  environment.set_ode_state(it)                      // 9 environment states
  3  environment.time = time
  4  check_finite_ode_state()                           // #550 guard
  5  compute_environment(true)
        f = [](double x) -> double { return compute_competition(x); }
        environment.compute_environment(f, height_max(), rescale)
          -> ResourceSpline::construct: adaptive cubic fitted to light vs height
  6  compute_rates()
        for each species: Species::compute_rates(env, pr_patch_survival, birth_rate)
          Node::compute_rates -> Individual::compute_rates
            -> TF24_Strategy::compute_rates -> net_mass_production_dt
                 leaf.set_physiology(...); solve_leaf()      // the hydraulic solve
               writes vars.rates and vars.consumption_rates
          Node::compute_rates also:
            log_density_dt = -growth_rate_gradient(env) - mortality
        resource_depletion[i] = sum over species, nodes of consumption_rate(i) / area
        environment.compute_rates(resource_depletion)   // soil rates
```

Two properties of this ordering matter and are worth stating because at least one
document in this repository records the opposite.

**The auxiliary slots are not lagged.** `Individual::set_ode_state`
(`individual.h:104-110`) calls `update_dependent_aux` for each slot *as it loads
it*, and TF24's `update_dependent_aux` (`tf24_strategy.cpp:140-147`) is what sets
`competition_effect = area_leaf(height)` and `height_inverse = 1/height`. Step 5
reads those auxiliary values through `compute_competition`. Step 5 therefore reads
auxiliary values written in step 1 of the same call. `Patch::compute_environment`
is a pure function of the ODE state just loaded. The same is true on the AD
branch: `update_dependent_aux` and the step ordering are unchanged there.

**The plant-to-soil and soil-to-plant couplings are both narrow.** Cohorts reach
the soil only through the summed `resource_depletion` vector (9 entries), and the
soil reaches cohorts only through `get_soil_water_potential_state()` (5 entries,
one per layer). Nothing else crosses.

### 2.2 What the AD branch adds

`claude/odelia-ad-tape-reverse-496fuf` adds `plant/inst/include/plant/scm_gradient.h`,
whose `scm_jacobian` runs an adaptive double pass to fix the schedule, replays it
at an active scalar via `SCM::rebind_from<S>()`, and calls odelia's
`compute_jacobian` for one recording and one sweep per output row. That entry
point is correct in structure and is what runs out of memory. Nothing in this
proposal replaces it; the proposal replaces the single recording it takes.

---

## 3. The structure being exploited

Read section 2.1 again as a data-flow graph rather than a call sequence. Per
Runge-Kutta stage, the computation is four layers, and the coupling between them
is thin:

```
     y  =  cohort states (141 x 7)  +  environment states (9)
     |
 L1  | per cohort, independent, closed form
     |   Individual::set_ode_state + update_dependent_aux
     |   -> competition_effect_j = area_leaf(H_j),  density_j = exp(log_density_j)
     v
 L2  | ONE reduction over all cohorts, then an interpolant
     |   Patch::compute_environment -> compute_competition(x) summed over nodes
     |   -> light availability as a function of height
     v
 L3  | per cohort, independent, expensive
     |   Individual::compute_rates -> TF24_Strategy::compute_rates
     |     reads light at the 21 Gauss-Kronrod abscissae of its own crown
     |     runs the leaf hydraulic optimisation
     |   -> vars.rates (5) + log_density_dt + offspring rate  = 7
     |   -> vars.consumption_rates                            = 9
     v
 L4  | ONE reduction, then the soil
     |   resource_depletion = sum of consumption_rates / area
     |   TF24_Environment::compute_rates(resource_depletion)
     v
    dydt
```

L1 and L3 are embarrassingly parallel across cohorts. They are coupled only
through L2's output. This is not an accident of implementation: it is the
mean-field structure of the model. Every cohort influences every other one only
by contributing to, and reading from, one scalar field of height. That is the same
property that makes `Patch::compute_environment` an O(n) build plus O(1) queries
rather than an O(n^2) all-pairs sum (see plant's `agents.md` section 12).

The consequence for reverse mode is that **the only quantity that has to be held
across the cohort loop is the adjoint of the field**, not the adjoint of every
cohort's internal computation.

### 3.1 The cohort's interface, counted

For TF24 with `n` seeded trait targets:

| direction | quantity | count |
|---|---|---|
| in | own ODE state (`state_size()` 5 + log_density + offspring) | 7 |
| in | light at the crown's Gauss-Kronrod abscissae (`function_integration_rule = 21`) | 21 |
| in | vertical light gradient at the same abscissae (see report 3) | 21 |
| in | soil water potential per layer | 5 |
| in | seeded traits (a subset of `TF24_AD_FIELDS`, not all 51) | n |
| out | rates | 7 |
| out | per-slot consumption | 9 |

At `n = 4` that is 58 inputs and 16 outputs. The local Jacobian is 928 doubles,
about **7.4 kB**, against the roughly **600 kB** the same cohort-step currently
records (7 states x 86 kB). The ratio is about **80x**, and it is set by the
model's coupling structure, not by any tuning of the recorded arithmetic.

There is a variant that stores nothing at all, described next, and it is the one
this proposal recommends.

---

## 4. Is the cohort a legitimate unit?

The decomposition is only valid if `Individual::compute_rates` is a pure function
of (its own `Internals`, the environment values it reads, the strategy's
parameters). If it carried information from one cohort to the next, re-running one
cohort in isolation during a reverse pass would not reproduce the forward pass.

The risk is concrete. `Individual` holds a `strategy_type_ptr`
(`individual.h:179`), which is a `std::shared_ptr`, so **every cohort of a species
writes into the same `TF24_Strategy` object**. That object has three mutable
members every cohort touches:

| member | declared at | verdict |
|---|---|---|
| `std::vector<double> mass_root_prop_` | `tf24_strategy.h` | scratch. `mass_root_prop_.assign(soil_number_of_depths_, 0.0)` at the top of every `net_mass_production_dt`, then refilled. Write before read. |
| `quadrature::QK function_integrator` | `tf24_strategy.h` | fixed rule, set once in `prepare_strategy`. Its `last_*` members are diagnostic only. |
| `Leaf leaf` | `tf24_strategy.h` | see below |

The `Leaf` is the one that needs care, and it is clean for a specific reason.
`net_mass_production_dt` reaches the leaf only through the local lambda
`optimise_at`, which calls `leaf.set_physiology(...)` **before** `solve_leaf()` on
every invocation (`tf24_strategy.cpp:401`). `Leaf::set_physiology` re-seats every
per-solve field: it assigns `psi_soil_`, rebuilds `grav_head_z_`, `.assign`s
`c_r_V_` and `c_r_H_`, resizes `soil_consumption_`, and sets
`transpiration_cached_ = false`. And `find_root_collar_psi` takes its bracket from
`prepare_collar_solve` off the current soil state and runs a **fresh**
`golden_section_max` — there is no warm start from a previous solve. The leaf is
therefore a function of the inputs `set_physiology` was handed, not of the cohort
that used it last.

Two exceptions were found. Both are correct in value today and both are worth
recording because they become live hazards the moment an active scalar reaches
them:

1. **`photo_temp_cached_`** (`leaf_model.h:250-252`) persists across cohorts and
   across the whole run. Its key is `(leaf_temp_, atm_o2_kpa_)`. The members it
   caches include `vcmax_` and `jmax_`, which are functions of `pars.vcmax_25` and
   `pars.jmax_25` — **both declared entries of `TF24_AD_FIELDS`**. The key is a
   proper subset of the cached values' dependencies. This is safe only because
   those two parameters are constant within a run. If a caller ever varied them
   mid-run, or if the cache key is not extended when the leaf is templated, the
   cache would serve values for the wrong parameters.
2. **`psi_soil_cache_`** (`tf24_environment.h:304-328`) invalidates on
   `psi_soil_cache_state_[i] != vars.state(i)`, an exact `double` comparison
   against soil state. The AD branch closes the analogous hazard elsewhere with
   `if constexpr (!std::is_same_v<S, double>) cache_stale = true;`
   (`tf24_environment.h:394-400` on the branch). The same treatment applies here.

**Conclusion.** On develop, one cohort's rate computation is a pure function of its
boundary. The unit is legitimate. The two caches above are prerequisites, not
blockers.

---

## 5. The proposal

### 5.1 Forward pass

Unchanged from what `scm_gradient.h` already does, except that the trajectory is
kept:

1. Run the adaptive double pass (`SCM::refine_schedule()`), which fixes the
   resolved L1 schedule. `recorded_steps()` is the single source of the replay
   grid.
2. Replay that schedule in plain `double`, storing the full ODE state at each
   accepted step.

Storage, at production: 996 states x 8 bytes x 2 829 steps = **22.5 MB**
(projected from the measured shape). This is the whole additional memory the
proposal requires.

### 5.2 Reverse pass

Walk the stored trajectory backwards. Within one step, the reverse of the four
layers runs in a strict order with no circular dependency. This was the one point
that had to be settled before the design was viable, because the obvious reading
of the graph suggests a cycle: L3's sweep needs the light adjoints that L2
produces, and L2 needs the light adjoints that L3 produces. It does not, because
L1 is a separate closed-form map and is adjointed analytically rather than on a
cohort's tape:

```
given  lambda  (adjoint of y at the end of this step)

  a  L4 adjoint:  lambda_soil, lambda_depletion
                  (9 x 9 and 9 x 9 blocks; small, closed form or a small tape)

  b  for each cohort j, one at a time:
        fresh tape
        register:  own state (7), light (21), light gradient (21),
                   soil potential (5), seeded traits (n)
        record:    Individual::compute_rates for this cohort only
        seed:      lambda_rates_j, lambda_depletion
        sweep once
        read off:  lambda_y_j (direct), lambda_light_j, lambda_gradient_j,
                   lambda_psi, lambda_traits (accumulate)
        release tape                              <-- PEAK IS HERE, ONE COHORT

  c  L2 adjoint:  lambda_light_j, lambda_gradient_j  ->  lambda at the field's nodes
                  ->  lambda_(competition_effect_j, density_j, H_j)

  d  L1 adjoint:  closed form (area_leaf and exp are analytic)
                  ->  lambda_y_j (field contribution)

  e  lambda_y_j  =  direct + field
```

Step (b) is where all the expensive arithmetic is, and its tape is released before
the next cohort's is created. Step (c) is a linear map whose adjoint is another
linear map of the same size. Steps (a), (d) and (e) are closed form.

**Trait adjoints accumulate over (b) across all cohorts and all steps.** This is
load-bearing: because the strategy is shared through a `shared_ptr`
(`individual.h:179`) and `Species::ad_parameters()` returns pointers into the
strategy's `pars`, a single trait is one input read by every cohort. Earlier work
in this repository measured that treating each cohort as a distinct input instead
yields **41–51%** of the correct answer with the right sign and no error raised.
The accumulation in (b) must therefore be tested directly, not assumed.

### 5.3 What replaces `compute_environment` on the reverse pass

Step (c) requires the adjoint of the field. This is where the interpolant choice
becomes structural rather than a matter of accuracy, and it is the subject of
report 3. The short statement:

- develop fits a **C2 cubic spline** to light values (`ResourceSpline::construct`
  via `basic_interpolator`). C2 continuity is enforced by a tridiagonal solve over
  all nodes, so one light read depends on **every** node value, and its adjoint is
  a transposed band solve of run-dependent width.
- A **cubic Hermite** interpolant carrying value and slope at each node is local:
  one read depends on exactly **two** nodes. Its adjoint is O(1) per query.

Locality was verified rather than assumed. With an active knot value registered on
a tape, `d(eval)/d(node_2)` is 0.55 for a query in a span touching node 2 and
**exactly 0** for a query two spans away.

The field's node values themselves are a reduction over cohorts, so their adjoint
is a reduction of the same shape and the same cost as the forward build — the
standard reverse-mode guarantee.

---

## 6. Evidence

A standalone system was built with plant's coupling structure and none of its
physiology: N cohorts, a shared light field with the same
`(1 - (z/H)^eta)^2` kernel, per-cohort rates containing an inner implicit solve,
soil water as ODE state depleted by the cohorts and read back as a potential,
traits shared across cohorts, explicit Euler stepping, and a mass-weighted census
functional. Source: `scratchpad/cohort_toy.cpp`.

**This is a toy. It establishes that the decomposition and the reverse ordering
are correct and how peak memory scales. It establishes nothing about TF24's
physiology.** The distinction matters: earlier work in this repository records a
case where a summed-height functional gave a constant adjoint and could not detect
a 19% error, so a toy witness has to be checked for vacuity. Here the functional
is mass-weighted and the severance controls in section 6.3 confirm the witness
responds when a real channel is cut.

### 6.1 Correctness

With the field queried exactly (no interpolant, isolating the adjoint machinery
from any interpolation error):

| check | result |
|---|---|
| cohort-granular vs one whole-run tape | **1e-14 to 1e-15**, all configurations |
| AD vs central finite differences | **4.5e-10 to 3.4e-9** |
| finite-difference step dependence | improves as the step *grows* (1.9e-8 at 1e-7, 4.5e-10 at 1e-5) |

The last row matters: it is the roundoff-dominated regime, so the finite
difference is the less accurate of the two. Configurations covered N in {8, 20,
40, 80} and 60 to 480 steps.

### 6.2 Scaling

| N | steps | one whole-run tape | per-cohort tape | field tape | trajectory |
|---|---|---|---|---|---|
| 20 | 60 | 20.8 MB | **1.0 kB** | 330 kB | 0.02 MB |
| 20 | 120 | 41.8 MB | **1.0 kB** | 331 kB | 0.04 MB |
| 20 | 240 | 83.9 MB | **1.0 kB** | 334 kB | 0.08 MB |
| 20 | 480 | 169.0 MB | **1.0 kB** | 339 kB | 0.17 MB |
| 40 | 240 | 321 MB | **1.0 kB** | 1 310 kB | 0.16 MB |
| 80 | 240 | 1 252 MB | **1.0 kB** | 5 184 kB | 0.31 MB |

Three readings:

- **The per-cohort tape is flat in both run length and stand size.** This is the
  claim the proposal rests on and it holds exactly.
- The whole-run tape is linear in step count and quadratic in stand size.
- The field-assembly tape is flat in step count and quadratic in stand size
  (330 to 1 310 to 5 184 kB for N of 20, 40, 80: exactly 4x per doubling). In this
  toy L2 was placed on a tape for convenience rather than adjointed by hand, so
  this term is an implementation choice, not a property of the design. It is
  quadratic because the toy's field assembly is an all-pairs sum; plant's is O(n)
  by construction.

At the largest configuration the peak for the cohort path is **5.2 MB against
1 252 MB, a factor of 241**, and the factor grows with run length because the
numerator is flat and the denominator is not.

### 6.3 Behaviour under TF24's harder features

The inner implicit solve was replaced with TF24's actual construct: a
fixed-tolerance golden-section maximisation over a bracket whose upper bound comes
from the soil state, with the envelope theorem for the objective and the implicit
function theorem for the side outputs, plus the boundary branch where the argmax
lands on the bracket end.

| leaf treatment | interior | boundary | cohort vs whole | AD vs FD |
|---|---|---|---|---|
| implicit root-find | — | — | 1.4e-14 | 4.5e-10 |
| argmax, all interior | 1 200 | 0 | 8.1e-15 | 1.1e-05 |
| argmax, bound at 0.60 | 1 200 | 0 | 1.4e-14 | 4.0e-06 |
| argmax, bound at 0.30 | 1 183 | **17** | 7.5e-15 | 2.9e-06 |
| argmax, bound at 0.10 | 0 | **1 200** | 9.8e-15 | **3.1e-10** |

**The decomposition is unaffected by any of it.** The argmax, the boundary branch,
and a run that mixes the two all reproduce the whole-run tape to 1e-14 or better.
The residual AD-versus-FD discrepancy introduced by the argmax is a property of
the argmax node and is the subject of report 2.

**The witness is not vacuous.** Severing the argmax's influence on the side output
— the consumer the envelope theorem does not cover — breaks the gradient by
**4.1%** (root-find) and **11.6%** (argmax) while the decomposition stays at
1e-15. The channel being tested is load-bearing.

### 6.4 Two defects found in the course of building this, both relevant to plant

- **`pow(0, eta)` has a NaN derivative with respect to the exponent.**
  `d/d(eta) 0^eta = 0^eta log(0)`. In the toy this made exactly one trait's
  gradient NaN while the others stayed finite and plausible. plant's canopy kernel
  evaluates `pow(z / height, eta)` and the ground-level query is `z = 0`
  (`Patch::compute_competition(0.0)` is called by `Node::compute_competition`).
  Whether this is reachable on plant's active path should be checked; the failure
  mode is a single silently-NaN trait.
- **A bounded value with an unbounded derivative.** In an early version the
  per-cohort soil draw did not scale with stand size, so 20 cohorts drove the soil
  toward the pole of `psi = 1/(0.05 + theta)`. The census value stayed at 27 while
  the gradient grew by a factor of 1.85 per step to 6e14. This is the shape of a
  derivative blow-up that value-based tests cannot see, and it is why TF24's soil
  positivity guards exist.

A third hypothesis was tested and **refuted**: that nodes placed at cohort tops
would produce collapsing spans when cohorts converge in height, making the
interpolant ill-conditioned. Measured minimum span was 3.7e-2 over the whole run,
never close. This is recorded so it is not re-derived.

---

## 7. Leverage, projected to plant

Arithmetic on the measured quantities in section 1, with the source of each factor
stated. **These are projections, not measurements.**

| | current | proposed |
|---|---|---|
| peak tape | ~220 GB (86 kB x 987 x 2 829) | one cohort-step, ~600 kB |
| plus field adjoint per step | — | O(n) in plant, small |
| plus stored trajectory | — | 22.5 MB |
| recompute factor | 1 | 1 (each cohort's rates re-run once) |
| new concepts a strategy author sees | — | none |

The final row is the one that motivates the whole approach. Nothing in section 5
appears in a strategy's source. `Individual::compute_rates` is recorded as it
already stands; the decomposition lives entirely in the gradient driver.

Earlier work in this repository measured the wall-clock cost of a step-local
reverse sweep at a flat **4.2x** relative to a whole-run reverse pass over 60 to
960 units, while the memory ratio over the same range grew from 27.7x to 438x.
That trade — a constant factor in time for a memory saving that grows with the run
— is the right shape here, since time is available and memory is not. The
cohort-granular variant should sit in the same regime but has not been timed.

---

## 8. Constraints and open risks

**C1. The two caches in section 4 must be handled first.** `photo_temp_cached_`'s
key omits `vcmax_25` and `jmax_25`; `psi_soil_cache_`'s key is an exact `double`
comparison on soil state. Neither is wrong today. Both are prerequisites.

**C2. Explicit versus Runge-Kutta stepping.** The toy uses explicit Euler, for
which the step map is `y_{k+1} = y_k + h f(y_k)` and the adjoint recursion is
unambiguous. plant uses an adaptive RK45 (Cash-Karp). Each accepted step has six
stage evaluations, and the reverse pass must traverse the stage structure, not
just the step. This is standard but it is genuinely unbuilt and it is the largest
piece of implementation work in the proposal.

**C3. The field adjoint's cost depends on the interpolant.** With develop's C2
fitted spline, one light read reaches every node through the band solve. The
proposal assumes a local interpolant (report 3). Without it the design still works
but the field adjoint is materially more expensive and the node count becomes a
run-dependent quantity in the middle of the reverse pass.

**C4. Trait adjoint accumulation is untested in plant.** Section 5.2 depends on
it; the 41–51% figure from earlier work shows what a failure looks like and that
it fails quietly.

**C5. Introductions inside a step.** `Patch::introduce_new_nodes` changes the ODE
width, and earlier work in this repository measured that applying a structural
change *between* units rather than inside one loses the newborn's adjoint —
**19% error, correct sign, silent**, undetectable by a constant-initial-condition
toy. Every introduction time was measured to lie on the ODE grid (141/141 and
233/233 for K93, 141/141 and 161/161 for FF16, 141/141 for TF24), so a step
boundary is always available; the ordering still has to be got right deliberately.

**C6. The stored trajectory is not sufficient on its own.** Earlier work found
that rebuilding a patch from `ode_state` alone drifts, and isolated the cause: each
`Node` carries `pr_patch_survival_at_birth`, a plain `double` set at birth, not
part of `ode_state`, which **divides** the fecundity rate (`node.h:74` states this;
the division is at `node.h:217`). Omitting it puts the error exclusively in
`offspring_produced_survival_weighted` — verified by discriminating prediction on
both K93 and FF16. It is recoverable deterministically from the schedule and the
disturbance regime, so no derivative is needed, but the reverse pass must restore
it. `Species::set_birth_state(times, patch_density, pr_survival)` exists
(`species.h:132`) and is called by no test.

**C7. This design carries no structural defence of its own assumption.** It
requires that a cohort's rates be a pure function of its boundary. Section 4
establishes that by reading the current code. A future warm start in any inner
solver would break it silently, with every double-valued test still passing.
Earlier work flagged this and concluded it wants a structural guard rather than a
comment; no such guard exists.

---

## 9. Implementation order

Each step is independently checkable and the sequence is chosen so a failure is
attributable.

1. **Extend `photo_temp_cached_`'s key** to include `vcmax_25` and `jmax_25`, and
   give `psi_soil_cache_` the `if constexpr` treatment the branch already applies
   elsewhere. Both are small and both are prerequisites.
2. **Check `pow(0, eta)`** on plant's active path (section 6.4). A single trait
   returning NaN is easy to miss.
3. **K93 first.** No leaf, no soil, closed-form rates. This exercises the
   decomposition, the RK stage traversal (C2), trait accumulation (C4) and the
   birth stamp (C6) with nothing else in the way. Its gradient is already
   FD-verified through `scm_gradient.h`, so there is a reference.
4. **Hand-adjoint L1 and L2** rather than taping them, removing the residual
   stand-size term in the peak (section 6.2).
5. **FF16.** Adds the crown integral and the light field's self-shading feedback.
   Its coupled gradient is already exact to the finite-difference noise floor
   (lma 2.64e-06, a_l1 6.06e-06, k_l 1.31e-08 in earlier work), so a regression is
   visible.
6. **TF24 at `max_patch_lifetime = 105.32`.** The deliverable. Requires report 2's
   leaf node and report 3's interpolant.

---

## 10. What would falsify this

Stated as checks rather than arguments, so the answer is a number:

- **A cohort's rates are not reproducible from its boundary.** Re-run one cohort's
  `compute_rates` from stored state plus stored environment reads and compare to
  the forward pass bit for bit. Any difference locates a carried-over quantity
  section 4 missed.
- **Peak does not stay flat.** Report the per-cohort tape at K93 production width
  and lifetime. If it grows with either, the unit is not what section 3 claims.
- **Trait adjoints do not accumulate.** A gradient that is a fixed fraction of the
  finite-difference reference, with the correct sign, is the signature.
- **The RK stage traversal loses a term.** The census functional's gradient against
  the existing FF16 finite-difference gate; earlier work's 19% newborn-adjoint
  error is the reference failure mode.

---

## 11. Relationship to the other two reports

This report assumes, and does not establish:

- **Report 2 (the leaf as one differentiable node).** The cohort tape in section
  5.2 step (b) records `Individual::compute_rates`, which for TF24 contains the
  hydraulic optimisation. Report 2 argues that solve should enter the tape as a
  single node with a supplied local Jacobian rather than as recorded arithmetic,
  and quantifies the residual that treatment leaves.
- **Report 3 (the light interpolant).** Section 5.3's locality requirement, and
  the vertical light gradient that appears in the cohort's input list in section
  3.1.

The three are separable. The decomposition in this report is correct with
develop's fitted spline and with the leaf recorded operation by operation; it is
merely more expensive.
