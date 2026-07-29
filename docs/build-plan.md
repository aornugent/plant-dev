# Build plan: exact resident gradients for TF24

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
Both AD feature branches contain work worth taking; §3 says what.

**Status: under review. Nothing here is built. Phase 0.5's measurements decide four of the
design choices below, so they come before Phase 1.**

---

## 1. Scope

**The prize is TF24 resident gradients at production lifetime.** Exact trait and parameter
gradients of the three census metrics (LAI, biomass, basal area) and R0/offspring for TF24 at
`max_patch_lifetime = 105.32`, with the canopy responding to the trait — verified against a
re-run finite difference, adding no engine vocabulary per model, and without slowing the
forward model.

Deferred, in this order:

| deferred | why it is later, not harder |
|---|---|
| invasion gradients | the invasion gradient is the resident one with the light interpolant's knot adjoints dropped (§2.7). Subtractive, so it follows |
| FF16, K93 | the same engine at a lower difficulty. Once TF24 works they are the templating plus the existing census reduction |
| calibration | needs a decision about intermediate trajectory states first (§6, Phase 4) |
| RODAS | out of scope. RKCK only |
| the stochastic solver | out of scope. It shares the Strategy, so it must keep compiling and its tests must keep passing |

**What TF24-first costs, and how it is paid.** K93 was going to be the first thing to run
because a failure there belongs to the engine and nowhere else. Without it, the first thing
that runs has a leaf and a soil, so attributability has to come from the verification design
rather than from model simplicity. That makes the block-locality checks (§2.5) the *first*
thing built, not a convenience.

The acceptance test is a number and a count. The count: a plant developer adding an emergent
metric writes one scalar-templated reduction and registers a name, touching no tape code and
no odelia code.

---

## 2. The architecture

Reports 01–04, 06 and 07 carry the arguments and the measurements. This section states the
decisions, and spells out only what no report owns.

### 2.1 One implementation of the science, carrying the scalar it is evaluated at

`S = double` is production. No model equation is written twice.

The scalar lives with the types that own the parameters, and the containers read it off `T`, so
**no template parameter is added**:

```cpp
template <typename T, typename E> class Individual {
  using value_type = typename T::value_type;   // and likewise Node, Species, Patch
```

`Patch<T,E>` already declares `using value_type = double;` (`patch.h:22`); the change is to read
it from `T`. The `<T,E>` shape is unchanged, RcppR6's instantiation table keeps its shape, and
`Solver<patch_type>` is unchanged. There is no new System type and no second `Patch`.

**One parameter store per model, templated.** `TF24_Pars<S>`, not a double `pars` plus a separate
active copy, so a named trait registers active directly.

Two properties follow. The gradient reads the model's own allometry, quadrature and reductions,
so there is nothing to keep in agreement. And a model author who adds physiology gets it
differentiated or gets a build failure, never a channel that silently reads zero.

**What this rules out.** `ff16_production_kernel.h` is the counter-example: its five elementary
functions are shared with `FF16_Strategy`, but `ff16_net_from_components` recomputes the mass
cascade (`mass_sapwood` written twice, in `ff16_strategy.cpp:39` and in the kernel, with nothing
keeping them equal), `FF16ProdPars<S>` re-declares 18 of `FF16_Pars`' 32 fields, and
`ff16_assimilation_deep_crown_replay` computes assimilation a second way. TF24 has no equivalent,
so the arrangement served one model and did not spread. Under this decision the class *is* the
templated form, so nothing needs a second copy — which also rules out the AD branch's parallel
leaf assembly (§3).

### 2.2 What carries `S`, and what does not

| stays `double` | carries `S` |
|---|---|
| `Control` — never a differentiation target | `TF24_Pars<S>` |
| `ExtrinsicDrivers` and their interpolator — fixed input data | the Strategy's precomputed members (`eta_c`, `height_0`, `area_leaf_0`) |
| `Leaf` — a sub-model with a declared boundary (§2.4) | `Internals<S>` |
| knot fractions, quadrature abscissae, sort keys | `TF24_Environment<S>`'s state; the light interpolant's knot **values** |

With `Control` and `ExtrinsicDrivers` out, the double-to-active copy is `TF24_Pars<S2>` from the
values of `pars` and then `prepare_strategy()`. The AD branch's per-strategy field-copy function
carried things that no longer need carrying.

**A gradient is defined against one `Control`.** `GSS_tol_abs`, `ci_abs_tol`,
`node_gradient_eps` and `schedule_eps` all change the trajectory and hence the gradient, so the
entry point records which `Control` it differentiated at and refuses to compare across two.

**`birth_rate` is a target only as a scalar.** `birth_rate_y` becomes `std::vector<S>` with index
0 seedable when `is_variable_birth_rate == false`, an error otherwise.

### 2.3 The cohort block

The recorded unit is one cohort's rate chain at one Runge-Kutta stage. Report 01 §4.1 and §6.2
give the unit, the declared inputs, why the light enters as knot values, why step (b) is a
vector-Jacobian product, and why the seeding order is forced. For TF24 concretely:

| declared inputs | | outputs | |
|---|---|---|---|
| own ODE state | 6 + log-density + offspring | rates | 8 |
| light interpolant knot **values** | 65 | per-layer uptake | 5 |
| soil water potential per layer | 5 | height growth rate `g` | 1 |
| seeded traits | up to 51 | | |

`Leaf` stays `double` inside the block behind a declared boundary — in (soil water potential per
layer, radiation, traits), out (profit, per-layer uptake) — with its derivatives arriving as
injected partials.

**The block removes `growth_rate_gradient`'s scratch, and this has no report home.** Today
`Node::growth_rate_gradient` holds `thread_local std::optional<individual_type> scratch` so it
has a mutable `Individual` to perturb height on. Under §2.1 that is a `thread_local` holding
active values across block tape lifetimes, which is the class of fault that segfaults far from
its cause. It is not needed: the block *is* the rate chain as a function of height, so evaluating
it at two heights is two calls with different arguments and nothing to perturb. The scratch
survives only on the pure-double path, and M5 measures whether it is still worth having there. If
one is needed, a `Node` member beats `thread_local` — 141 scratches at about 36 kB total, the same
copy-assignment storage reuse, per Node rather than per thread, and warmer in cache.

### 2.4 Where each part of the reverse pass lives

Report 01 §6.2 explains why: the Cash-Karp tableau and stage states are `private static const` on
`odelia::ode::Step`, so a reverse stage traversal cannot be written in plant. **odelia owns the
within-step recursion; plant owns one new System member and the between-step structure.**

```cpp
// odelia, ode_step.hpp
template <class System>
void Step<System>::step_adjoint(System& system, const state_type& lambda_out,
                                state_type& lambda_in, double h);

// plant, patch.h  -- the mirror of ode_rates
template <class ItIn, class ItOut>
void Patch<T,E>::ode_rates_adjoint(ItIn lambda_dydt, ItOut lambda_y);
```

`Patch::ode_rates_adjoint`, given the adjoint of `dydt`:

```
a  soil adjoint            closed form: the drainage cascade is bidiagonal, no solve
b  per cohort: record the block, seed its output adjoints, sweep, read input adjoints
c  transport stencil       closed form over neighbouring cohorts' g outputs (§2.6)
d  light knot adjoints -> (area_leaf, density, height)   the summed reduction, closed form
e  allometry adjoint       closed form
```

`SCM` keeps the between-step structure and does **not** grow a `Solver`'s members: an
introduction's adjoint contributes only parameter terms, through
`log(birth_rate · pr_estab / g)`.

Peak is one cohort's block, constant in run length, stage count and seeded-trait count. The
trajectory is stored in `double`, one state per accepted step, 46.0 MB at production; stage states
are rebuilt by re-running the step rather than stored, so storage does not grow with the stage
count.

**Nothing crosses the boundary to describe the stage structure.** `step_adjoint` is a member of
`Step`, so the tableau it needs is already in scope and no stage count has to be published. That
matters because plant currently hard-codes one across the boundary — `environment_cache(6) { //
length of odelia::ode::Step` — on the mutant path, which §3 leaves dead. RKCK only, per §1.

### 2.5 Verification: local, and at the Patch level

No report owns this, and it is what pays for going at TF24 first.

| | check | what it tests | what it needs |
|---|---|---|---|
| **V1** | one whole-`Patch` recording at one state, against the sum of steps (a)–(e) at the same state | the decomposition | one state. No schedule, no trajectory, no `SCM` surface |
| **V2** | `block_adjoints(scm, step, cohort, output_seed)` against a finite difference of the same block | one block's adjoint, attributably | the trajectory store |
| **V3** | one step's `lambda_y` against a finite difference of one step | the stage recursion | one step |
| **V4** | whole-run gradient against a re-run finite difference at production lifetime | the deliverable | everything |

**V2 verifies at stage 0 only.** A block lives at a stage, and stage states are rebuilt rather
than stored, so verifying at stage > 0 would need the rebuild working before it could check
anything. At stage 0 the state *is* the stored trajectory state, exactly. V3 covers the rebuild
and the tableau separately.

**There is deliberately no whole-run recording.** Supporting one is exactly what made `SCM` grow
a `Solver`'s members on the AD branch, and V1 gets the same evidence about the decomposition from
one state at the `Patch` level, where the System already exists. V1 plus V3 makes a V4
disagreement attributable without it.

### 2.6 Three decisions the reports argue and this plan adopts

**Resident, with invasion following from it** (§2.7 below is the only part with no report home).

**The transport stencil differences across neighbouring cohorts**, not on a `1e-6` sub-grid.
Report 04 §2.1: the cohort-grid difference is not an approximation to `dg/dh` — it is exactly
`d(log dh)/dt`, because the spacing between two characteristics has an exact rate. So it is the
same discretisation as transporting counts, without changing the state or any consumer, and it
makes the scheme conserve individuals up to mortality where a sub-grid probe leaks them at
`O(dh g'')` (§2.2). It also removes about half of TF24's leaf solves (§3). A sub-grid difference
divided by `eps` amplifies roundoff by `1/eps` regardless of smoothness, against a measured
minimum spacing of **8.2095e-06** — so the divisor advantage is 3 470x at the median and only 8x at
the first percentile, not the four orders a toy measurement suggested (§5). The choice does not rest
on it: §2.1 makes the cohort-grid difference exact rather than an estimate. Substituting the
analytic `dg/dh` removes the upwinding (§6).

**The light interpolant is held on `u = z / height_max` with fixed fractions.** Report 03 §1b:
`rescale_spline` is not cheaper than building adaptively, so it exists to keep the knot count
fixed across stages, and the map it applies is `x_k = u_k · height_max` — so the normalised form
is bit-identical, the knot positions become constant, and `height_max`'s sensitivity becomes
chain-rule terms in the query rather than a structural approximation. The fitted cubic keeps its
refiner and supplies the fractions; a `hermite_interpolator<S>` evaluates value and slope at them.

### 2.7 Resident, and how invasion follows

The resident gradient is the one where the canopy responds to the trait. In the reverse pass that
is step (d): the knot-value adjoints propagate back into every cohort's `area_leaf`, density and
height, closing the light loop.

**The invasion gradient is the same pass with step (d) omitted** — the mutant reads a canopy that
does not respond to its trait. One branch in one step, not a second path.

So the resident case is the general one and needs no recorded environment. None of
`environment_history`, `environment_cache`, `save_RK45_cache` or `use_cached_environment` is on
its path, which keeps the two-record arrangement — `step_history` per accepted step,
`environment_history[step][stage]` per stage, resolved by matching time — out of it. Replaying the
wrong one of those gave a gradient wrong by 60×.

### 2.8 Two recorded structures, and the XAD boundary

Resident TF24 records two things: **the node schedule** (plant) and **the ODE step times**
(odelia, `advance_fixed`). `r_ode_times()` is the one source of the replay grid. With the schedule
recorded, introduction times are constants, so introductions widen the state without adding a
discontinuity.

There is no knot-position record — §2.6's fractions are fixed by construction — and no recorded
environment, since §2.7 recomputes it. The quadrature abscissae move with an active integration
bound, and inside the cohort block that is recorded rather than replayed, because both the
quadrature and the bound are on the block's tape.

**Introduction times, step times and stage times, precisely.** Introductions land on step
boundaries **structurally**, not just in measurement: `advance_adaptive` sets
`time = time_max` on its final step (`ode_solver_internal.hpp:304`), so a step always ends
exactly on the event time. Report 01 C5's 141/141 is a consequence. Within a step, RKCK's
stage times are `ah = {1/5, 3/10, 3/5, 1, 7/8}`, so **stage index is not time order**: index 3
(`k5`) is at `t + h` and index 4 (`k6`) at `t + 0.875 h`, and index 5 (`dydt_out`) is at
`t + h` as well. Two stages share a timestamp, so **a stage is addressed by index and never by
time**. develop's `set_ode_state(it, int index)` is index-based and correct; `load_ode_step`
resolves *steps* by time and is also correct.

`k1` is not a stage of its own step: RKCK is first-same-as-last, so `k1` is the previous step's
index-5 evaluation carried by `save_dydt_out_as_in` (`ode_solver_internal.hpp:355`). That is
clean for a reverse traversal — `dydt_out` enters neither the `y` update nor `yerr`
(`ode_step.hpp:140-154`), so it has exactly one consumer and no double counting. The exception
is every introduction: `Patch::introduce_new_nodes` rebuilds the field but does not recompute
rates (`patch.h:621-631`), and `set_state_from_system` then seeds `dydt_in` from the stored
rates and marks them clean (`ode_solver_internal.hpp:146-152`). So at ~141 of 2 829 steps,
`k1` is the rate vector from before the newcomer entered the field, entering the update with
weight `c1 = 37/378`. **`lambda_k1` therefore belongs to the step boundary, and the step
boundary is where introductions live** — one seam, to be designed once (§11).

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD transitively and
always will. The rule is that **no plant file spells `xad::`**, checked by
`grep -r 'xad::' plant/inst plant/src` returning nothing. develop has one violation today, in
`src/leaf_model.cpp`. Forward-mode AD stays in plant — the leaf's gas-exchange optimum has one
input and one output, so forward mode plus the implicit function theorem is the right method —
and only the spelling moves.

---

## 3. What we take

Three names cross from odelia into plant, plus one small helper and one concept. **None exists at
the `854a8e18` baseline** — `implicit_value` and `hermite_interpolator` are on odelia's AD branch,
and `preaccumulate` was added there in `2a60998` and deleted again in `28059bd`. So all of it is
new code written against a design rather than a lift.

**`to_passive` is not among them.** P1.1 sets out why nothing in plant needs to convert an active
value to a passive one: comparisons and branches work natively, the cohort order is structural, the
knot fractions are `double` by declaration under §2.6, and the graft idiom belonged to a mechanism
this design does not have. The one real extraction is the R boundary and it lives in the `r_*`
family.

| name | prior art | its one consumer in plant |
|---|---|---|
| `vector_jacobian_product` | `preaccumulate` (deleted) solved a different problem — it grafted partials back onto an enclosing tape. There is no enclosing tape here, so the graft, its first-order-only property and its return-type `static_assert` are all beside the point | step (b): the cohort block |
| `OdeElement` | new. Constrains the four recursive helpers so the state-transfer interface stops naming `double` (§11.1) | every container's ODE plumbing |
| `implicit_value(y*, F)` | AD branch, `implicit_node.hpp` | `height_seed`'s `uniroot` on `mass_live_given_height - omega`, so `height_0` and `area_leaf_0` carry the derivatives of `omega`, `lma`, `rho`, `a_l1`, `a_l2`, `theta`, `a_b1` and `a_r1` |
| `hermite_interpolator<S>` | AD branch, `hermite_interpolator.hpp` | the light interpolant's evaluation (§2.6) |
| a forward-derivative helper | new, small | `dprofit_droot_collar_psi`, so `src/leaf_model.cpp` stops spelling `xad::fwd` |

Two odelia changes have no plant-visible name: `Step` gains `step_adjoint` and a description of
its stage structure (§2.5), and the vector-Jacobian product reports its recording size so plant
can assert the peak without touching `xad::Tape`.

From plant `develop`: `Species::census<Psi>` and its self-shading integral, `Control()`'s
defaults, `SCM::refine_schedule`, `r_ode_times()`.

**The mutant replay path is already dead on develop, and we leave it dead.**
`Patch::cache_ode_step`, `cache_RK45_step` and `load_ode_step` (`patch.h:727-775`) carry
comments saying odelia calls them; odelia at `854a8e18` does not, and neither does anything in
plant. `save_RK45_cache` defaults false and is set true only in `R/benchmark.R`. So
`environment_history` is always empty, `Patch::set_mutant` stops with "Run a resident first"
(`patch.h:236`), and `run_mutant` pins the replay grid to `patch.step_history`
(`scm.h:309`), which is still `{0.0}` — which is where the 60x came from. Meanwhile odelia at
`854a8e18` carries a *different* replay interface: the `Replayable` concept with
`record_stage` / `record_ode_step` / `replay_step` / `has_recorded_field`
(`ode_interface.hpp:42-48`), which plant does not implement. Phase 4's invasion task therefore
reconnects a dead path to a renamed interface; it does not resume a working one.

From the plant AD branch: the scalar templating as the starting diff, reshaped per §2.1;
`CanopyShape<S>`; birth size through `implicit_value`; the three census metrics as one
codomain-3 functional; `Species::census<Psi>` and `QK` templated; names and pointers from the
yml rather than a macro; and one line of `scm_gradient.h` — the check that the active value
reproduces the double value, which catches a configuration member that failed to cross
double-to-active and is not an acceptance test.


`28059bd` removed 697 lines and four primitives from odelia because nothing but their own
examples called them. Every name in the first table above has a consumer in §6 before it lands.

---

## 4. Documents

One home per fact, and the home is named before the code is written.
`docs/audit-2026-07.md` indexes what is archived.

| document | owns |
|---|---|
| `docs/build-plan.md` | this plan: architecture, what to take, tasks, gates |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites |
| `docs/reports/01`–`04`, `06`, `07` | the derivations and measurements the plan rests on. Not edited to track progress |
| `odelia/AUTODIFF.md` | the System requirements, including `ode_rates_adjoint` |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary |
| `plant/agents.md` §13 (new) | how a plant model author makes their science differentiable |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable |

Two rules, enforced per task:

- A task that changes what a model author writes changes `plant/agents.md` §13 in the same PR.
  Past two pages, there is too much to learn.
- A task that adds a name to §3's four justifies it in the PR body.

`plant/agents.md` §13's outline:

1. **Your model is templated on its scalar; `double` is production.** Write the science once.
   If new physiology does not compile at the active scalar, that is the design working.
2. **Positions are `double`; values carry `S`.** Knot fractions, quadrature abscissae and sort
   keys are decided on passive values, and declaring them `double` is how you say so. A knot *count* that
   depends on an active value makes the recorded computation depend on the state.
3. **An inner solve is declared by its residual,** through `implicit_value`. Never
   differentiate the iteration that found the root: `golden_section_max`'s result is affine in
   its bracket and independent of the objective's values, so recording the search returns the
   bracket's derivative.
4. **Never define a rate as a numerical derivative of an active quantity.** If a rate is a
   difference, difference on a grid the model already has.
5. **A clamp, floor, `min`/`max` or `if` on a computed value is a derivative decision.** Put it
   in the switch inventory with the incidence that justifies it.
6. **Never give a deduced return type to anything returning an active value.** XAD operators
   return expression templates holding references to their operands, so a deduced return type
   hands the caller references to temporaries that die on return. The reverse sweep then reads
   reused stack memory and segfaults arbitrarily far from the cause, and valgrind cannot see it
   because the storage is stack. Declare the scalar return type on every such function and
   lambda, including one-line helpers.

---

## 5. Phase 0 — forward-model prerequisites, no AD

[`tf24-correctness.md`](tf24-correctness.md) and report 07. P0.1 is a prerequisite because V1
and V2 compare a decomposed computation against the forward pass, and on develop the forward
pass is order-dependent.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort reading the previous cohort's deep-layer uptake | 1 line + baselines | a seedling's deep layers read 0 on a leaf that solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake whatever ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip test | 1 line + test | round trip to 1e-12 for θ in (θ_r, θ_sat] |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | **the switch inventory** — every clamp, floor, `min`/`max` and branch on a computed value on TF24's carbon and water paths, classified, each with a measured incidence | doc + probes | every row has a number. Includes `height_max`'s selector (§2.6) and the operating-point selector (§8) |
| **P0.6** | the two ecology decisions: leaf respiration counted twice, and `establishment_probability`'s hard gate | owner's call | a recorded decision either way, with a `scientific_version` bump |
| **P0.7** | `q(z, height)` divides by `z`, so `q(0, h)` is NaN for every `h`, and the light interpolant's lowest knot is exactly `z = 0` | small | `q(0, h)` finite for every `h` |

P0.5 is the input Phase 3 needs: you cannot choose which switches to smooth before knowing
which fire. **P0.6 gates Phase 3, not Phase 1.**

---

## 5b. Phase 0.5 — measurements that decide the design

None on the critical path; each can kill or confirm one choice in §2.

| | measurement | what it decides | needs |
|---|---|---|---|
| **M1** | **A block with a moving integration bound.** An interpolant integrated over `[0, h]` with `h` a declared input; check the height adjoint against a finite difference. This is the structure that fails if §2.4 is wrong | whether the block boundary closes, including the moving bound | odelia only |
| **M2** | **`CanopyShape<S>` alone, ported to develop.** One file | §2.1's shape, bit-identity, and the forward benchmark, at the smallest possible cost | the AD branch already wrote it |
| **M3** | **The normalised light coordinate.** Rebuild the field as `u = z/height_max` with fixed fractions. Bit-identity holds only **within an introduction interval**: `introduce_new_node` passes `rescale = false`, so develop re-refines adaptively at each of the 141 introductions and the knot count runs 33 to 129, mean 58.4 (report 03 §1b). So M3 measures two things — bit-identity between introductions, and the size of the shift across one | §2.6, and how much of it needs re-blessing | `double` only |
| **M4** | **The transport stencil across neighbouring cohorts.** Value change against the sub-grid stencil on one production run; conditioning of both against a finite difference | §2.8, and the size of the forward-value change to re-bless | `double` for the value; M1 and M2 for the derivative |
| **M5** | **The scratch.** Forward benchmark with `growth_rate_gradient`'s `thread_local` scratch, with a `Node` member, and with the block called twice | §2.4's last paragraph. The prior is that a member is no slower and possibly warmer | `double` only |

M1, M2, M3 and M5 are independent. M4's value half is independent; its derivative half needs
M1 and M2.

---

## 6. Phases 1–4

One PR per task. Each says what to write, in what order, and what closes it.

### Phase 1 — make the model differentiable and store a trajectory

Nothing here computes a gradient.

---

**P1.1 — the odelia surface.** From `854a8e18` on `master`.

Nothing here is a lift: none of the names exists at the baseline (§3). Three have prior art on
odelia's AD branch, one is new, and one is the concept that stops the state-transfer interface
regressing.

```cpp
// ode_interface.hpp -- constrain the four recursive helpers, and delete the two
// legacy double typedefs. Required AT the element's own value_type iterator: that is
// the constraint a double-typed signature fails, and it fails here rather than
// inside derivs.
template <typename E>
concept OdeElement = requires(E e,
    typename std::vector<typename E::value_type>::iterator it,
    typename std::vector<typename E::value_type>::const_iterator cit) {
  typename E::value_type;
  { e.ode_size() }         -> std::convertible_to<std::size_t>;
  { e.ode_state(it) }      -> std::same_as<decltype(it)>;
  { e.ode_rates(it) }      -> std::same_as<decltype(it)>;
  { e.set_ode_state(cit) } -> std::same_as<decltype(cit)>;
};

template <std::forward_iterator FwdIt, class It>
  requires OdeElement<typename std::iter_value_t<FwdIt>>
It ode_rates(FwdIt first, FwdIt last, It it);      // and ode_state, ode_aux, set_ode_state

// vector-Jacobian product over one block: the only new primitive. NOT preaccumulate --
// there is no enclosing tape here, so nothing is grafted back and the block's own tape
// is the only one. Doubles in, doubles out; f is generic and is instantiated at the
// active scalar inside, so plant never spells xad::.
template <class F>
std::vector<double> vector_jacobian_product(const std::vector<double>& x,
                                            const std::vector<double>& output_adjoints,
                                            F&& f);
std::size_t last_recording_size();   // so plant can assert peak without touching xad::Tape

// ode_step.hpp
template <class System>
void Step<System>::step_adjoint(System&, const state_type& lambda_out,
                                state_type& lambda_in, double h);
```

Plus `implicit_value` and `hermite_interpolator`, and the non-finite step-size rejection.
`needs_time` stays as it is — a legacy quirk that costs nothing to leave. **One concept, not
two:** with the time dispatch untouched there is no reason for a System-level refinement, and
`OdeElement` is the whole requirement.

**What the concept buys, stated honestly.** It does not remove a mechanism — it adds one. What it
buys is that the four helpers stop naming `double`, the two legacy typedefs are deleted, and a
container written against a `double` iterator fails at the helper with a readable message instead
of deep inside `derivs`. `r_ode_state` and the rest of the `r_*` family then name
`std::vector<double>::iterator` inline, where it means something.

**No conversion helper.** There is nothing for a `to_passive` to do: comparisons and branches work
on active values natively (XAD defines them for `AReal`, expressions, and mixed active/`double` —
`BinaryOperators.hpp:99-158`); cohorts are kept in descending order by construction so there is no
sort key to extract; §2.6's normalised coordinate makes the knot fractions `double` by declaration;
and the graft idiom belonged to `preaccumulate`'s inject-onto-an-outer-tape mechanism, which this
design does not have. The one real extraction is the R boundary, and it lives inside the `r_*`
family. Putting a converter in `ode_util.hpp` — which plant reaches from every translation unit
via `control.h` → `ode_control.hpp` — is how the XAD boundary erodes, and it is what odelia's AD
branch did.

*Order.* The concept and the four helpers first, since P1.2a depends on them. Then
`vector_jacobian_product`, then `step_adjoint`, then `implicit_value` and `hermite_interpolator`
in either order.
*Must not break* the odelia suite, and `ode_util.hpp` must still include no XAD.
*Closes on* one test per name driven from a System rather than from an example; `step_adjoint`
reproducing a finite difference of one step on the Lorenz System; and a negative test — a
deliberately `double`-typed element rejected by `OdeElement` with the error at the helper.

---

**P1.2a — the state-transfer plumbing, at `S = double`.** Probe-measured (§11.1), so this is a
known quantity rather than an estimate: **26 uses of the two legacy typedefs across 9 headers.**

| file | uses | |
|---|---|---|
| `patch.h` | 6 | deterministic |
| `node.h` | 4 | deterministic |
| `stochastic_patch.h` | 4 | stochastic |
| `environment.h`, `individual.h`, `species.h`, `species_base.h`, `individual_runner.h`, `stochastic_node.h` | 2 each | mixed |

`models/*.h` has none — `TF24_Environment` inherits `Environment`'s. Four of the nine files are
the stochastic and single-individual paths, which never carry an active scalar but do share the
plumbing, so they are in the sweep.

```cpp
template <typename It> It ode_state(It it) const;      // and ode_rates, ode_aux
template <typename It> It set_ode_state(It it);        // Patch also takes (It, double) and (It, int)
```

**Fifteen of the twenty-six are signature-only.** Probe B established that the read-out direction
(`ode_state`, `ode_rates`, `ode_aux`) needs no body changes at all, because `double` to active is
an implicit conversion. Only `set_ode_state` has work behind it, and that work is P1.2b.

*Order.* odelia's helpers and the concept (P1.1) first. Then the six deterministic-path headers,
then the three stochastic ones. Add `#include <plant/individual.h>` to `node.h`, which is missing
it (§11.1).
*Must not break* anything: at `S = double` the deduced `It` **is** `std::vector<double>::iterator`,
so this generates identical object code.
*Closes on* bit-identity — the TF24 and FF16 suites unchanged, the FF16 references unchanged, and
one production run reproducing offspring `4.214017357509567e+01` exactly — **at a pinned build**.
A `-O0` build of the same tree differs by 0.145% in offspring and 0.79% in accepted step count
(report 01 §2), so a gate that does not name its compiler flags measures the compiler.

---

**P1.2b — TF24 templated.** The largest task and the one to break into commits. Probe B named its
four entry points: `Environment::vars.states[i] = *it++`, `Individual::set_state(int, double)`,
`Node::offspring_produced_survival_weighted`, and `Node::set_log_density(double)`.

```cpp
template <typename S = double> struct TF24_Pars { S lma, rho, hmat, omega, ...; };
template <typename S = double> class TF24_Strategy : public Strategy<TF24_Environment<S>> {
  using value_type = S;
  TF24_Pars<S> pars;  S eta_c, height_0, area_leaf_0;  Control control;  Leaf leaf;
};
template <typename S = double> class TF24_Environment { using value_type = S; ... };
template <typename S = double> class Internals { std::vector<S> states, rates, auxs, ...; };
```

Then in each container, one line: `using value_type = typename T::value_type;`. **Six containers,
not four** — `Patch`, `Species`, `SpeciesBase`, `Node`, `Individual` and `Environment`, plus
`ResourceSpline`, which is a plain class today holding a concrete `Interpolator` and which sits on
the R boundary. `SpeciesBase` is the one shared with the stochastic path.

*Commit order, each bit-identical before the next.* (1) `Internals<S>` with `S = double`
everywhere else. (2) `TF24_Pars<S>` and `TF24_Strategy<S>`, `Control` and `ExtrinsicDrivers` left
`double`. (3) `TF24_Environment<S>` and `ResourceSpline<S>`. (4) the six containers reading
`value_type` from `T`. (5) the RcppR6 yml and regeneration. (6) remove or relocate
`growth_rate_gradient`'s scratch — but see P2.4, which deletes it outright, so M5 may have nothing
left to measure.
*Must not break* `test-strategy-tf24.R`, `test-strategy-tf24f.R`, `test-patch.R`,
`test-individual.R`, the stochastic tests, or the forward benchmark.
*Closes on* bit-identity at a pinned build — the TF24 suite unchanged, and one production run
reproducing offspring `4.214017357509567e+01` to the last bit — plus the forward benchmark inside
the accepted band against develop's **89.9 s** at `-O2` (report 01 §2).
*The failure to watch for* is a deduced return type on anything returning an active value. XAD
operators return expression templates holding references to their operands, so the caller gets
references to dead temporaries, the reverse sweep reads reused stack memory, and the segfault
lands arbitrarily far from the cause. Valgrind cannot see it because the storage is stack.

---

**P1.3 — trait registration.** Names and pointers from the RcppR6 yml, which is already the one
source; no macro list.

```cpp
std::vector<S*>          TF24_Strategy<S>::ad_parameters();
std::vector<std::string> TF24_Strategy<S>::ad_parameter_names();
```

*Closes on* a test asserting the two have the same size and order, and that seeding by name and by
index reach the same field.

---

**P1.4 — the trajectory store.** Replay the resolved schedule in `double`, keeping one state per
accepted step.

```cpp
struct Trajectory {
  std::vector<double> times;                 // == scm.r_ode_times()
  std::vector<std::vector<double>> states;   // one per accepted step
  // per species, per node: introduction time, patch density at birth, pr_survival at birth
};
Trajectory SCM<T,E>::store_trajectory();
```

`pr_patch_survival_at_birth` divides the fecundity rate and is not in `ode_state`, so omitting it
puts the error exclusively in `offspring_produced_survival_weighted`.

*Order.* Store and replay first, then the birth values, then give `Species::set_birth_state` a
test — today it has none.
*Closes on* the replayed final state being bit-identical to the forward run.
*The trap.* Two schedule records exist. `r_ode_times()` is the replay grid; `patch.step_history`
is the other, and replaying it instead gave a gradient wrong by 60×.

---

### Phase 2 — the two changes that move forward numbers

They land together so there is one re-blessing rather than two, and P0.6's ecology decisions
belong in the same conversation with the owner (§10).

---

**P2.1 — the light interpolant on a normalised coordinate.** Report 03 §1b.

```cpp
class ResourceSpline {
  std::vector<double> knot_fractions_;              // u_k, fixed after one adaptive construct
  interpolator::Interpolator     fitted_;           // supplies the fractions, once
  interpolator::hermite_interpolator<S> field_;     // evaluates, carries S
  double height_max_, inv_height_max_;
  S get_value_at_height(double z) const;            // field_(z * inv_height_max_)
  void get_value_and_slope_at_height(double z, S& v, S& dvdz) const;
};
```

*Order.* (1) Add `knot_fractions_` and rebuild through it, keeping the fitted cubic as the
evaluator — this alone should be bit-identical to `rescale_spline`, which is M3. (2) Delete
`rescale_spline`. (3) Only then bring in the Hermite (P2.3).
*Touches* every `get_environment_at_height` caller, plus the `cap` argument and the
`max(0.0, spline(height))` undershoot guard, both expressed in absolute height today.
*Closes on* M3's result: bit-identical where M3 says it should be, otherwise the shift recorded and
baselines re-blessed.

---

**P2.2 — the slope reduction.**

```cpp
// one pass, so pow(z/H, eta) is evaluated once and the two sums associate identically
std::pair<S,S> Patch<T,E>::compute_competition_and_slope(double z) const;
```

Merge sources in the **same descending-height order with the same flat-index tie-break** as the
value reduction. A value and a slope from sums that associate differently disagree in their last
bits, which is the pattern report 03 exists to remove reappearing in floating-point association.
Guard `q(0, h)` per P0.7 — it is `0/0` for every `h`, and the field's lowest query is `z = 0`.

*Closes on* agreement with a tight central difference of `compute_competition` across `eta` in
{1,2,4,8,10,12} and one general non-integer `eta`; and the two sums adding the same terms in the
same order, checked rather than asserted.

---

**P2.3 — the Hermite in `ResourceSpline`.** Swap the evaluator, feeding `init(x, y, dydx)` from
P2.2.

*Closes on* O(h⁴) on value and O(h³) on slope at the production fraction set.
*Note* the R-facing state changes shape — the fitted cubic reports (x, y), a Hermite carries
(x, y, m). That is a `NEWS.md` entry.

---

**P2.4 — the transport stencil across cohorts.** Report 04 §2 and §7.

```cpp
// species.h -- g comes from the neighbours' already-computed rates
double Species<T,E>::growth_rate_gradient(std::size_t i) const;   // one-sided at i = 0 and i = n-1
```

`node_gradient_eps`, `node_gradient_direction` and `node_gradient_richardson` go from `Control`,
and with them the coupling to `GSS_tol_abs` that nothing else records.

*Order.* (1) Add the cohort-grid stencil beside the sub-grid probe and log both on one production
run — that is M4's value half. (2) Switch `log_density_dt` to it. (3) Delete the probe and the
three `Control` fields.
*Closes on* `log_density_dt` matching M4's measured change, with offspring and the three census
metrics re-blessed and the shift recorded.
*The ends.* First and last cohort have one neighbour, so the stencil is one-sided there — the same
one-sidedness the sub-grid probe had, on a grid that exists.

---

**P2.5 — account for `rescale_spline`'s cost before it goes.** 17.6 µs of 193.2 is accounted for;
175 µs per build over 20 160 builds is 3.5 s of a 59.5 s run. Worth knowing whether P2.1 recovers
it or whether it was somewhere else.

*Closes on* the forward benchmark after P2.1, with the difference attributed.

---

### Phase 3 — the reverse pass

Ordered so that each task closes on one of §2.5's checks and a failure has one cause.

---

**P3.1 — the closed-form steps.** Steps (a), (d), (e), with step (b) a stub returning zeros.

```cpp
template <class ItIn, class ItOut>
void Patch<T,E>::ode_rates_adjoint(ItIn lambda_dydt, ItOut lambda_y) {
  soil_adjoint(...);            // (a) bidiagonal drainage cascade, no linear solve
  // (b) stub
  light_knot_adjoint(...);      // (d) knot values -> (area_leaf, density, height)
  allometry_adjoint(...);       // (e)
}
```

*Order.* The soil adjoint first, because it is checkable on its own: **V1** with the blocks
stubbed compares the closed-form part against the matching part of a whole-`Patch` recording at one
state.
*Watch* step (d) visiting sources in the same order as the forward sum, for P2.2's reason.

---

**P3.2 — the cohort block and the leaf's boundary.** The largest reverse-pass task.

```cpp
// the block: a pure function of its declared inputs
template <class S>
std::vector<S> tf24_cohort_block(const std::vector<S>& inputs,
                                 const TF24_Pars<S>& pars, const Control& control);
// the leaf's boundary, S = double inside
struct LeafOutcome { double profit; std::vector<double> uptake;
                     std::vector<double> d_profit, d_uptake; };   // partials, injected
LeafOutcome solve_leaf_boundary(Leaf&, const std::vector<double>& psi_soil,
                                double radiation, const TF24_Pars<double>& pars);
```

*Order.* (1) The block with the leaf held constant, so **V2** exercises the allometry, storage and
demographic chain alone. (2) The leaf boundary with the interior operating point only. (3) The
bound-pinned case and the selector.
*Closes on* **V1** complete, and **V2** at stage 0 for both operating-point cases — the pinned one
needs `psi_soil ≥ 1.5 MPa` at `height ≥ 2 m` (§8). The selector's incidence goes in P0.5's
inventory.
*Two things to decide here, not in P3.3.* `∂Π/∂p` is `dprofit_droot_collar_psi`, which already
contains forward-mode AD and an implicit-function term, so its gradient is the mixed second partial
`∂²Π/∂p∂φ`. A preaccumulated block carries exact first derivatives and no curvature, so the leaf
cannot be both preaccumulated and the source of `∇(∂Π/∂p)`: either the block declares `∂Π/∂p` as a
fifteenth output, making the mixed partial a first-order sweep of it, or `∇(∂Π/∂p)` is written by
hand. And `bound_a = -root_zero_E` comes from a root-find, so the bound's derivative needs its own
implicit-function term. Nobody has written it.

---

**P3.3 — `∇(∂Π/∂p)`**, including the `ci` root-find's implicit-function term, in whichever form
P3.2 chose.

*Closes on* `d(consumption)/dψ` within finite-difference noise, against the **47.6–53.2%** error
that holding the operating point fixed gives today. That error is fully explained by cancellation
of the search's own displacement, so a fix that does not remove it has not addressed the cause.

---

**P3.4 — remove the last `xad::` from plant.** `xad::fwd<double>` and `xad::derivative` in
`src/leaf_model.cpp` become one odelia helper. Forward mode stays; only the spelling moves.

*Closes on* `grep -r 'xad::' plant/inst plant/src` returning nothing.

---

**P3.5 — the stencil's adjoint, and drive from the stepper.** Step (c) distributes `lambda_g`
across the three neighbouring blocks P2.4's stencil reads; then `Step::step_adjoint` drives
`Patch::ode_rates_adjoint`.

*Closes on* **V3** — one step's `lambda_y` against a finite difference of one step. The reference
failure for a lost tableau term is a **19%** error with the correct sign and no message, so a
whole-run check would not localise it.

---

**P3.6 — the census metrics and the entry point.**

```cpp
template <class Psi> value_type Species<T,E>::census(Psi psi, double query = 0.0) const;  // templated on S
struct census_vector { std::size_t codomain() const { return 3; } /* LAI, biomass, basal area */ };
```

R side: `stand_gradient(scm, metrics, traits)`, doubles in and out, recording the `Control` it
differentiated at. Plus `plant/agents.md` §13.

*Closes on* **V4** — TF24 census and R0 at `max_patch_lifetime = 105.32`, resident, against a
re-run finite difference on the identical resolved schedule, under 2 GB peak — and on the count: a
developer reads §13 and adds a fourth metric without touching tape code.
*The failure to watch for* is trait adjoints not accumulating across cohorts. Treating each cohort
as a separate input gives **41–51%** of the answer with the correct sign and nothing thrown, so the
test asserts the value, not finiteness.

---

### Phase 4 — after the prize

Separate pushes, sequenced by what each needs.

| | what it is | needs first |
|---|---|---|
| **invasion gradients** | omit step (d) (§2.7). Bring back `run_mutant` and the recorded environment, and make a missing `save_RK45_cache` an error rather than a search failure | Phase 3 |
| **FF16 and K93** | the templating plus the existing census reduction; retire `ff16_production_kernel.h`; port the `smooth_positive` clamp fix and K93's `k_I` channel; tighten FF16's gradient test, which passes at 1e-2 where the truth is ~1e-6 | Phase 3 |
| **two species** | two `Leaf` objects, `Species::consumption_rate`'s `size() < 2` per species, and per-species η grouped inside the light reduction. Every incidence number in reports 06 and 07 is single-species | FF16 |
| **calibration** | `least_squares` reads intermediate trajectory states as active values, which a `double` trajectory breaks without a message. Either the functional declares which steps it reads and contributes a per-step adjoint seed, or calibration stores a second denser trajectory. Record the decision before opening it | Phase 3 |
| **node-schedule refinement** | point it at the coupling field. Recording the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84% | invasion, for the comparison |
| **TF24f** | the tracked collar state reparameterised onto its feasible interval, so the clamp and its two roles go away. Its `∂Π/∂p` is a rate, so P3.2's mixed-second-partial fork does not arise | Phase 3, and the owner on `plant#61` |

---

## 7. What we are deliberately not building

- No third template parameter, no new System type, no second `Patch`.
- No whole-run recording (§2.5), and therefore no `Solver` members on `SCM`.
- No second implementation of anything: no separate leaf assembly, no shadow active fields, no
  second parameter struct.
- No capability flags or SFINAE detection structs. A concept and `if constexpr` where a
  compile-time choice is needed.
- No `decide()` type. The switch inventory is a document.
- No check that forward and reverse agree, in place of a finite difference.
- No component-level tape size work: 0.018% of TF24's total against a required factor of
  10²–10³.
- No mass chart.
- No analytic `dg/dh` substituted for the stencil (§2.6) — it removes the upwinding.
- RODAS and the stochastic solver are out of scope; both must keep compiling and passing.
- No disturbance gradients, no second derivatives.
- No smoothing without a measured incidence and a scale sized against data. develop has both
  the precedent (`P_pos`) and the method (`storage_prod_eps`).

---

## 8. `Π_pp`, and the two cases of the operating point

`scripts/curvature_probe.R`, against a develop build: a central difference of develop's analytic
`dprofit_droot_collar_psi` about the solved operating point, at `GSS_tol_abs = 1e-10` so the
number is the geometry, each point at three step sizes. Swept over the whole feasible domain of
the maximisation — `psi_soil` from the default driver's 0.015–0.17 MPa down to the stem's
`psi_crit = 7.085`, four heights, five uneven profiles of the kind a drydown produces.

**`Π_pp` is negative at 52 of 52 states**, `|Π_pp|` from **0.1723 to 15.61** (median 4.2). The
divide in report 06 §6.2 fails when `Π_pp → 0`; nothing in the domain comes near it, and the
largest amplification of a flux adjoint is **5.8×**. So the interior case is one divide with no
fallback.

| case | count | treatment |
|---|---|---|
| stationary interior maximum (`\|∂Π/∂p\|` at the solver's floor) | **37 / 52** | report 06 §6.2 as written |
| pinned at a bound (`\|∂Π/∂p\|` = 0.054 … 2.12 at tolerance `1e-10`) | **15 / 52** | `p*` is the bound, so its derivative is the bound's derivative |

Every pinned state is at `psi_soil ≥ 1.5 MPa` **and** `height ≥ 2 m`. None is inside the
default driver's `psi_soil` range, which is why report 06's production census finds no pinned
states; the committed rainfall sequences reach 1.5+ MPa. Selection is a comparison on
`|∂Π/∂p|` available where the search returns, and it is a discrete branch on the gradient path,
so P0.5's inventory carries it.

**Why report 06 §9's `∂Π/∂p` of 11–23 is consistent with a curvature of −4.** A `1e-4`
displacement would give about `4e-4`. `golden_section_max` returns a point affine in its
bracket within one comparison pattern, jumping when the pattern changes, so the displacement is
bracket-scale rather than tolerance-scale — report 04 §5's mechanism. A property of the search,
not the objective, so it does not touch §6.2's derivation. It is also the extra, TF24-specific
part of §2.8's conditioning argument, on top of the `1/eps` roundoff amplification that any
sub-grid difference carries.

---

## 9. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| the block boundary does not close around a moving integration bound | the height adjoint disagrees with a finite difference | **M1**, before Phase 1 |
| the forward model slows under templating | benchmark outside the accepted band, or reference numbers move | **M2**, then P1.2, gated on bit-identity. The AD branch measured develop 49.57 s against branch 50.31 s |
| the normalised coordinate is not bit-identical to `rescale_spline` | a forward shift where none was expected | **M3** |
| differencing across cohorts changes the forward value more than expected | `log_density_dt` and offspring move | **M4** |
| removing the scratch slows the forward pass | benchmark | **M5** |
| a channel exists that templating cannot reach | a derivative obtainable only through a second implementation | P3.1's V1 |
| the decomposition is wrong | V1 fails at one state, with nothing else in the way | P3.1 |
| the stage recursion loses a term | V3 fails on one step; the reference failure is a 19% error with the correct sign and no message | P3.5 |
| trait adjoints do not accumulate across cohorts | a fixed fraction of the finite difference with the correct sign, nothing thrown. Treating each cohort as a separate input gives 41–51% | P3.6 |
| the leaf's boundary is wider than §2.4 declares | P3.2 grows an output nobody declared | P3.2; P0.5's inventory should predict it |
| the value-reproduction check is read as an acceptance test | a 0.2% difference in value has produced a sign-flipped gradient | every gate compares AD against a re-run finite difference |

---

## 10. Review gates on this plan

1. **Does the block boundary close as §2.4 states, with the light entering as knot values?**
   **M1** answers it without plant.
2. **Does the scalar belong on the types that own the parameters, with `<T,E>` unchanged?**
   **M2** for one file; P1.2 for TF24.
3. **Is the normalised light coordinate bit-identical to `rescale_spline`?** **M3.** If not, the
   interpolant change is a model change and Phase 2 needs the owner.
4. **Is the leaf's boundary (soil water potential per layer, radiation, traits) → (profit,
   per-layer uptake)?** Report 06 §5 says so. A sixth quantity changes P3.2's shape.
5. **Do P0.6's two ecology decisions bump `scientific_version`?** With P2.1 and P2.4 also
   changing forward numbers, there is a case for taking all four to the owner together.

**Order: M1 and M2 in parallel, then M3 and M4; (4) before P3.2; (5) before anything is
verified against TF24's numbers.**

---

## 11. Four open design threads

Each is frontloaded deliberately: the cost of getting one wrong is a wrong gradient that looks
plausible, and all four are cheaper to settle on paper than in a bisect. Worked in this order,
because each constrains the next.

**11.1 The state-transfer interface. Settled — the shape is P1.1 and P1.2a.**

odelia's System contract is already scalar-generic: its own AD examples template every ODE
method on the iterator (`examples/lorenz_system.hpp:106`), and `least_squares` calls
`ode_state` on an active vector (`gradient.hpp:157`). The legacy `double` typedefs are used in
exactly four places in all of odelia — the recursive element-range helpers at
`ode_interface.hpp:73, 82, 92, 102` — which exist only for plant, because odelia has no
container System. plant's signatures adopt them from there, in **26 places across 9 headers**.

Two compile probes on develop `141dc8df` against odelia `854a8e18` measured the surface rather
than estimating it.

*Probe A*, double containers called with an active iterator: **3 errors**, all the iterator
type. Nothing hidden.

*Probe B*, the two legacy typedefs redefined to name an active iterator — which makes every
plant signature that adopted them active-typed **without editing plant** — **4 errors**, all one
shape:

```
environment.h:40   vars.states[i] = *it++;                        // store is vector<double>
node.h:243         individual.set_state(i, *it++);                // set_state(int, double)
node.h:245         offspring_produced_survival_weighted = *it++;
node.h:246         set_log_density(*it++);                         // takes double
```

**The read-out direction produced no errors at all** — `ode_state`, `ode_rates` and `ode_aux`
write `*it++ = individual.state(i)`, and `double` to active is an implicit conversion. So
templating those signatures is *sufficient*, with no body changes. Only the load direction
fails, and it fails exactly where an active value must be stored into a `double` member. Those
four points are the state vector, which is why the plumbing and the scalar split cleanly into
P1.2a and P1.2b.

The probe reports only what was instantiated, and each `set_ode_state` body stopped at its first
failing assignment, so there is a cascade behind each of the four once the store carries `S`.
What it establishes is that there is no *third* category: no `Rcpp::` conversion, no `util::`
helper taking `double` by value, no arithmetic failure, and nothing in `Species`, `Patch` or
`SpeciesBase` bodies.

Two incidentals from the same probes. plant-develop compiles clean against `854a8e18`, so
report 02 §4's build blocker is AD-branch-only and its §10 item 5 is dead. And `node.h` is not
self-contained — it names `Individual<T,E>` at line 18 without including `plant/individual.h`,
and only compiles because real translation units reach `species_base.h` first by another route.
Harmless today; it bites the first time a translation unit is added, which is what a gradient
entry point is.

**11.2 The boundary node.** Report 01 §3.1 carries the mathematics — it is a flux boundary
condition, `g(x_b) n(x_b) = B(t)`, and the reverse-mode treatment of one is standard and costs a
single term because the forward inflow boundary is the adjoint's outflow boundary. It also carries
the measurements, and they settle the numerical half:

- **The one-stage lag is numerically irrelevant.** The boundary node's whole contribution to the
  light field is bounded by **3.5e-04**, at `ResourceSpline`'s own `1e-4` fitting tolerance, so the
  difference between its lagged and converged value is smaller again. Closing the fixed point buys
  no accuracy.
- **The circularity is real** — the `max(light, 1e-4)` clamp would sever `pr_estab`'s dependence on
  the field if it bound over the seedling crown, and it does not: `L` runs 0.1657 to 1.0 there.

**Decided: keep the channel and close the lag.** Two facts settle it. `A` is exactly proportional to
`birth_rate` — every cohort's density is seeded as `log(birth_rate * pr_estab / g)` and transported
by a rate independent of it — so `dA/d(log birth_rate) = A` and the boundary node carries *exactly
its share* of that sensitivity, 1.454% at the median. Dropping the channel therefore needs a number
nobody has. And the fixed point

    n_b  ->  B * pr_estab(field(n_b)) / g(field(n_b))

is **a contraction with modulus of order 1e-3**, because the boundary term is at most 1.3e-3 of `A`.
So one extra Picard step converges it to about 1e-6 relative — one additional boundary-node
evaluation per species per stage, not a root-find, and `implicit_value` is not needed. The
implicit-function correction to the derivative is O(1e-3), so the adjoint takes the naive
within-stage derivative and is right to a tenth of a percent.

The reason to close it is structural rather than numerical: keeping the lag forces a scalar to be
carried backwards across stage boundaries and, at a step's first stage, across the step boundary,
through `step_adjoint` — which is odelia's and knows nothing about species. That is mutable state in
the adjoint pass.

**Open:** the two-term boundary derivative (through the flux, and through the speed); the Leibniz
term at the reduction's lower limit, owed either way; and the introduction seam it shares with
§11.3 and §2.8. The `g > 0 ? ... : log(0)` cliff is representational rather than ecological and
belongs with P0.5.

**Also open, and found by the same probe:** report 07 §1.8's light-floor census disagrees with the
profile by four orders of magnitude. `tf24-correctness.md` P0.5 carries it. Until it is settled,
neither the floor nor the undershoot guard has a usable incidence.

**11.3 Density transport. Settled — report 04 now states it as the design.** The cohort-grid
stencil is exactly `d(log dh)/dt`, so it is the same discretisation as transporting counts without
changing the state or any consumer; it makes the scheme conserve individuals up to mortality; it is
consistent with the flux boundary condition in the collapsing-interval limit; and it removes about
half of TF24's leaf solves.

**The staggering is decided** (report 04 §7): pair each cohort with the interval **below** it. It
is the upwind direction, it is develop's `node_gradient_direction = -1`, it is the staggering
`Species::compute_competition` already uses by closing its trapezium on `new_node`, and it removes
the `size() < 2` case by construction because the boundary node is always a neighbour.

**The seam is one line, and it is now measured.** At the instant of introduction `nodes.back()` is a
copy of `new_node`, so the interval below has zero width — and a rate *is* read there, once per
introduction, through `set_state_from_system`'s first-same-as-last seed. That is the same place as
the stale `k1` (§2.8) and the same place as the boundary node's prescribed density (§11.2).
`tf24-correctness.md` **P0.9** measures it: a pre-existing cohort's rate wrong by more than its own
magnitude at **51 of 141** introductions, and offspring moving **0.2916%** once fixed — twice the
build noise, so attributable. The fix is `compute_rates()` after `compute_environment(false)` in
`introduce_new_nodes`, and it removes all three symptoms. Report 04 §7's stencil carries the
remaining branch with no tolerance in it, keyed on the introduction time rather than on a spacing.

**A third reduction has the same cause.** `Species::consumption_rate`'s `size() < 2` returns zero
because a trapezium needs two points, where `compute_competition` integrates from `new_node` up and
never has the problem. **P0.8**: a reduction over the size distribution starts at the boundary, not
at the smallest cohort. Both P0.8 and P0.9 are family-wide and both are engine blockers.

**Open:** the size of the forward-value change (M4), to be presented alongside report 04 §2.2's
conservation diagnostic; and the two-pass restructure of `Species::compute_rates`, which must
include `new_node` in the first pass so the bottom cohort's neighbour is current rather than lagged.

**11.4 The block's VJP.** A thin wrapper over XAD's tape drivers, not a primitive with a
theory. The design question is not the wrapper but the block's input and output layout, which
must be written once rather than twice — a forward assembly and an adjoint scatter that
disagree silently is a wrong gradient. **Open:** and it is the same decision as 11.1, because
if the patch owns contiguous state then a block's inputs are views and its adjoints scatter in
place, and no layout can disagree.
