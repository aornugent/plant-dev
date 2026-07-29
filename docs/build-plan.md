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
rather than from model simplicity. That makes the block-locality checks (§2.6) the *first*
thing built, not a convenience.

The acceptance test is a number and a count. The count: a plant developer adding an emergent
metric writes one scalar-templated reduction and registers a name, touching no tape code and
no odelia code.

---

## 2. The architecture

### 2.1 One implementation of the science, carrying the scalar it is evaluated at

`S = double` is production. No model equation is written twice.

The scalar lives with the types that own the parameters — `T = TF24_Strategy<S>`,
`E = TF24_Environment<S>` — and the containers read it off `T`:

```cpp
template <typename T, typename E> class Individual {
  using value_type = typename T::value_type;   // and likewise Node, Species, Patch
```

`Patch<T,E>` already declares `using value_type = double;` (`patch.h:22`); the change is to
read it from `T` rather than fix it. **No template parameter is added.** The `<T,E>` shape is
unchanged, RcppR6's instantiation table keeps its shape, and `Solver<patch_type>` is
unchanged. There is no new System type and no second `Patch`.

**One parameter store per model, templated.** `TF24_Pars<S>`, not a double `pars` plus a
separate active copy. A named trait then registers active directly and nothing copies fields
between two representations.

Two properties follow:

- The gradient reads the model's own allometry, quadrature and reductions, so there is nothing
  to keep in agreement.
- A model author who adds physiology gets it differentiated or gets a build failure, never a
  channel that silently reads zero.

### 2.2 What carries `S`, and what does not

| stays `double` | carries `S` |
|---|---|
| `Control` — never a differentiation target | `TF24_Pars<S>` |
| `ExtrinsicDrivers` and their interpolator — fixed input data | the Strategy's precomputed members (`eta_c`, `height_0`, `area_leaf_0`) |
| `Leaf` — a sub-model with a declared boundary (§2.4) | `Internals<S>` |
| knot fractions, quadrature abscissae, sort keys | `TF24_Environment<S>`'s state; the light interpolant's knot **values** |

**The double-to-active copy is almost nothing.** With `Control` and `ExtrinsicDrivers` out, it
is `TF24_Pars<S2>` from the values of `pars`, then `prepare_strategy()` re-derives the rest.
The per-strategy field-copy function on the AD branch existed to carry things that no longer
need carrying.

**A gradient is defined against one `Control`.** `GSS_tol_abs`, `ci_abs_tol`,
`node_gradient_eps` and `schedule_eps` all change the trajectory and hence the gradient. The
entry point records the `Control` it differentiated at and refuses to compare two gradients
taken at different ones.

**`birth_rate` is a differentiation target only as a scalar.** Seedable when
`is_variable_birth_rate == false`; an error otherwise. `birth_rate_y` becomes
`std::vector<S>` with index 0 seedable, which adds no new member.

### 2.3 No second implementation of anything

`inst/include/plant/models/ff16_production_kernel.h` is what to avoid. Five elementary
functions there are shared with `FF16_Strategy`; the rest is written twice:

- `ff16_net_from_components` recomputes the mass cascade. `mass_sapwood` is
  `area_sapwood * height * eta_c * pars.rho` in `ff16_strategy.cpp:39` and
  `area_sapwood * height * p.eta_c * p.rho` in the kernel. Six allometric relations, two
  copies, nothing keeping them equal.
- `FF16ProdPars<S>` re-declares 18 of `FF16_Pars`' 32 fields and is packed by hand at each
  call site.
- `ff16_assimilation_deep_crown_replay` computes assimilation a second way.
- TF24 has no equivalent, so the arrangement served one model and did not spread.

Under §2.1 the class is the templated form. When FF16 comes back, the composites move into it
and the header retires. The same rule rules out the leaf-assembly duplicates listed in §3.

### 2.4 The cohort block

The unit the reverse pass records is **one cohort's rate chain at one Runge-Kutta stage**.

| declared inputs | count |
|---|---|
| own ODE state | 6 + log-density + offspring |
| the light interpolant's knot **values** | 65 |
| soil water potential, one per layer | 5 |
| seeded traits | up to 51 |

| outputs | count |
|---|---|
| rates | 8 |
| per-layer uptake | 5 |
| height growth rate `g`, for the transport stencil (§2.8) | 1 |

**The light enters as knot values, not as sampled light.** The crown quadrature reads light at
`z = u_k · h`, so sample positions depend on the cohort's own height and sampled light is an
intermediate. Putting the interpolation and the quadrature inside the block means the tape
carries the moving-bound term and the `q(z,h)` dependence without anyone writing them, and the
sweep returns the knot-value adjoints directly. Cost is about 21 Hermite span evaluations on a
tape holding one cohort.

**It is a vector-Jacobian product, not a Jacobian.** 14 outputs and up to 57 inputs, and the
matrix is never formed: seed all 14 output adjoints, sweep once. Cost is one sweep per cohort
per stage regardless of trait count, which is the property the design rests on. That forces
the order, and there is no freedom in it:

```
lambda_uptake  from the soil adjoint          |  both before any block is swept
lambda_rates   from the stage adjoint         |
lambda_g       from lambda_log_density_dt     |
then per cohort: seed all three, one sweep
```

**Nothing may be read from enclosing scope.** That is checkable rather than conventional: a
channel left out of the input list cannot be reached from inside the block, so it fails to
compile or reads as a constant, not as a gradient missing one term.

`Leaf` is `double` and sits inside the block behind a declared boundary: in (soil water
potential per layer, radiation, traits), out (profit, per-layer uptake). Its derivatives reach
the block's tape as injected partials.

**The block replaces `growth_rate_gradient`'s scratch.** Today `Node::growth_rate_gradient`
holds `thread_local std::optional<individual_type> scratch` so it has a mutable `Individual`
to perturb height on. Under §2.1 that is a `thread_local` holding active values across block
tape lifetimes, which is the class of fault that segfaults far from its cause. It is not
needed: the block *is* the rate chain as a function of height, so evaluating it at two heights
is two calls with different arguments and nothing to perturb. The scratch survives only on the
pure-double path, and P1.2 measures whether it is still worth having there. If a scratch is
needed, a `Node` member is better than `thread_local` — 141 scratches at about 36 kB total,
the same copy-assignment storage reuse, per Node instead of per thread, and warmer in cache.

### 2.5 The reverse pass, and where each part lives

The Cash-Karp tableau and stage states are `private static const` on `odelia::ode::Step`, so
the reverse stage recursion cannot be written in plant. The division follows from that:

**odelia owns the within-step stage recursion.** `Step` gains `step_adjoint`, which walks its
own six stages in reverse using its own tableau. That needs one new System requirement, the
mirror of one that already exists:

```cpp
template <class It> It  ode_rates(It out) const;                  // exists:  y -> dydt
template <class ItIn, class ItOut>
void ode_rates_adjoint(ItIn lambda_dydt, ItOut lambda_y);         // new:  lambda_dydt -> lambda_y
```

**plant owns `Patch::ode_rates_adjoint` and the between-step structure.** Introductions widen
the state between steps, and their adjoint contributes only parameter terms — through
`log(birth_rate · pr_estab / g)` — so it is `SCM`'s business, not `Step`'s.

Consequence: **`SCM` does not impersonate a `Solver`.** No `get_system_ref`, no `tape`, no
`set_schedule` bolted on. The Patch gains one member and odelia's `Step` gains one loop.

`Patch::ode_rates_adjoint`, given the adjoint of `dydt`:

```
a  soil adjoint            closed form: the drainage cascade is bidiagonal, no solve
b  per cohort: record the block, seed its output adjoints, sweep, read input adjoints
c  transport stencil       closed form over neighbouring cohorts' g outputs (§2.8)
d  light knot adjoints -> (area_leaf, density, height)   the summed reduction, closed form
e  allometry adjoint       closed form
```

Peak is one cohort's block, constant in run length, stage count and seeded-trait count. Steps
(a), (c), (d) and (e) cost what their forward evaluation costs.

**The trajectory is stored in `double`**, one state per accepted step, 22.5 MB at production.
Stage states are rebuilt by re-running the step in `double` rather than stored, so storage does
not grow with the stage count.

**One prerequisite in odelia.** Its two steppers describe their stages differently — RODAS has
a public `static const int n_stages = 6`, RKCK has neither a count nor reachable coefficients —
and plant hard-codes the count across the boundary (`environment_cache(6) { // length of
odelia::ode::Step`). A stepper must describe its stage structure before a traversal can be
written against it. RKCK only, per §1.

### 2.6 Verification: local, and at the Patch level

Every check is small enough that a failure names one thing.

| | check | what it tests | what it needs |
|---|---|---|---|
| **V1** | one whole-`Patch` recording at one state, against the sum of per-cohort blocks at the same state | the decomposition — steps (a)–(e) against recording the lot | one state. No schedule, no trajectory, no `SCM` surface |
| **V2** | `block_adjoints(scm, step, cohort, output_seed)` against a finite difference of the same block | one block's adjoint, attributably | the trajectory store |
| **V3** | one step's `lambda_y` against a finite difference of one step | the stage recursion | one step |
| **V4** | whole-run gradient against a re-run finite difference at production lifetime | the deliverable | everything |

**V2 verifies at stage 0 only.** A block lives at a stage, and stage states are rebuilt rather
than stored — so verifying at stage > 0 would need the rebuild working before it can check
anything, which inverts the dependency. At stage 0 the state *is* the stored trajectory state,
exactly. V3 covers the rebuild and the tableau separately.

**There is deliberately no whole-run recording.** Supporting one is exactly what made `SCM`
grow a `Solver`'s members on the AD branch, and V1 gets the same evidence about the
decomposition from one state at the `Patch` level, where the System already exists. V1 plus V3
makes a V4 disagreement attributable without it.

V2 and V4 are the two entry points a maintainer uses; V2 lives in `tests/testthat/` and is
deleted when Phase 3 closes.

### 2.7 Resident, and how invasion follows from it

The resident gradient is the one where the canopy responds to the trait. In the reverse pass
that is step (d): the knot-value adjoints propagate back into every cohort's `area_leaf`,
density and height, closing the light loop.

**The invasion gradient is the same pass with step (d) omitted** — the mutant reads a canopy
that does not respond to its trait, so the knot adjoints do not return to its own states. One
branch in one step, not a second path.

So the resident case is the general one and needs no recorded environment. None of
`environment_history`, `environment_cache`, `save_RK45_cache` or `use_cached_environment` is on
the resident gradient's path, which keeps the two-record arrangement — `step_history` per
accepted step, `environment_history[step][stage]` per stage, resolved by matching time with
`util::identical` — out of it. Replaying the wrong one of those gave a gradient wrong by 60×.

### 2.8 The transport stencil: difference across cohorts

`log_density_dt = -dg/dh - mortality`, and `dg/dh` has no closed form. develop computes it as a
one-sided sub-grid difference: `gradient_fd_backward(f, h, eps, g_at_h)` is
`(g(h - eps) - g_at_h) / -eps` with `node_gradient_eps = 1e-6`, reusing the rate already
computed at `h`. The parameter derivative of that stencil is dropped today, so
`d(census)/d(trait)` is missing a channel — every census metric weights by `n_i = exp(l_i)`.

**Difference across neighbouring cohorts instead of on a sub-grid.** Three reasons, in order
of weight:

1. **Conditioning.** Any first difference of active derivatives divided by `eps` amplifies
   roundoff by `1/eps`, whether or not the derivative is smooth in `h`: two O(1) quantities
   accurate to ~1e-16 differenced and divided by 1e-6 leaves ~1e-10 absolute. The cohort
   spacing is the divisor instead, and the minimum spacing measured over a full run is
   **3.7e-2** — four to five orders larger.
2. **It is the discretisation the scheme already has.** In a method-of-characteristics scheme
   the cohorts *are* the grid, so differencing on the cohort grid is the natural upwind
   stencil. A `1e-6` probe discretises on a grid that does not exist.
3. **It costs nothing.** The neighbours' rates are already computed, so there is no extra
   evaluation forward, and no extra recording reverse.
4. **It keeps the block boundary at one cohort.** Each block outputs its own `g`; the stencil
   is a closed-form combination of three neighbouring blocks' outputs, so it belongs in step
   (c) alongside the soil and allometry adjoints rather than inside a block.

The cost is a change to the forward value, unquantified, so it needs measuring and re-blessing
— less of an obstacle here than it was, since P0.1 re-blesses TF24's baselines anyway.

**Substituting the analytic `dg/dh` is not the alternative.** The stencil is an upwind
discretisation of the advection term, so replacing it with the exact derivative removes the
numerical diffusion that keeps the transport bounded. That is why the AD branch found it needs
the growth clamp smoothed to `eps ~ 5e-2` to stay bounded, at a ~6% change to K93's demography.
The choice is which grid to difference on, not whether to difference.

### 2.9 The light interpolant on a normalised coordinate

`ResourceSpline::rescale_spline` reuses the knot distribution and re-evaluates. It is **not**
cheaper — 193.2 µs against `construct_spline`'s 143.0 — so cost is not why it exists. It is
there to keep the **knot count fixed across stages**: an adaptive refiner re-run per stage
would return a different number of knots at different positions, so the field's discretisation
would jitter and the step controller would see error that is not in the solution. That is also
exactly what the gradient needs, since a knot *count* depending on an active value makes the
recorded computation depend on the state.

The map it applies is `x_new = x_old · height_max / height_max_old` with `spline.min() = 0` —
which is `x_k = u_k · height_max` for fixed fractions `u_k`. So:

> **Hold the interpolant on `u = z / height_max`, with fixed fractional knots.**

Bit-identical to what `rescale` computes, up to doing one division rather than an affine remap.
What it buys: the knot positions become genuinely constant, and `height_max`'s sensitivity
moves out of the *structure* and into the *query*, as ordinary chain-rule terms
(`d/dh -> 1/height_max`, `d/d(height_max) -> -z/height_max²`). A channel that would otherwise
be dropped by `to_passive` becomes recorded arithmetic.

`height_max` is `max` over active cohort heights, so it keeps a selector — derivative 1 for the
tallest cohort and 0 for the rest, with a tie when two are equal. On the normalised coordinate
that selector sits in the arithmetic, where the tape handles it, rather than in the knot
placement. It is a discrete branch on the gradient path, so P0.5's inventory carries it.

A fixed absolute grid would also make positions constant, and is wrong: `height_max` runs from
0.34 m at the first cohort to 17.94 m, so most of 65 knots would sit above the canopy for the
first decades.

**Two interpolants, two jobs.** `ResourceSpline` keeps the value-fitted cubic and its adaptive
refiner to choose the knot *fractions* once, and holds a `hermite_interpolator<S>` that
evaluates value and slope at those fractions carrying `S`. The Hermite has no refiner and
cannot replace the fitted cubic; it is an addition with one consumer. It is also not a
candidate for the leaf's four vulnerability and transpiration curves or for the extrinsic
drivers, which call `set_extrapolate(false)` and depend on it.

`hermite_interpolator::init` takes `dydx`, which nothing supplies today —
`Patch::compute_competition_slope` is P2.2, and it must merge sources in the same
descending-height order with the same flat-index tie-break as the value reduction, or the two
disagree in the last bits.

### 2.10 The XAD boundary

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD transitively and
always will. The rule is that **no plant file spells `xad::`**, checked by
`grep -r 'xad::' plant/inst plant/src` returning nothing. develop has one violation today, in
`src/leaf_model.cpp`.

Forward-mode AD stays in plant: the leaf's gas-exchange optimum has one input and one output, so
forward mode plus the implicit function theorem is the right method and
`dprofit_droot_collar_psi` already uses it. Only the spelling moves, to one odelia helper.

§3 lists the four names that cross, and the four does not include a Jacobian driver — §2.6
removes the whole-run recording, so plant never calls one.

### 2.11 Two recorded structures, not four

Resident TF24 needs two, and the other two are elsewhere.

| | recorded | owner |
|---|---|---|
| **R0** | the node schedule: which cohorts exist and when introduced | plant |
| **R1** | the ODE step times (`advance_fixed`) | odelia |

With R0 recorded, introduction times are constants, so introductions widen the state without
adding a discontinuity. `r_ode_times()` is the one source of the replay grid.

There is no knot-position record: §2.9's fractions are fixed by construction. And there is no
recorded environment: §2.7's resident pass recomputes it.

The quadrature abscissae are the remaining case, and they move. A census integrated over height
has an active plant height as its integration bound, so the abscissae move with it — that needs
the scalar-templated `QK`, and replaying fixed abscissae would drop the bound's contribution.
Inside the cohort block that is recorded rather than replayed, because both the quadrature and
the bound are on the block's tape.

---

## 3. What we take

Four names cross from odelia into plant, plus one small helper. Nothing else is adopted.

| name | from | its one consumer in plant |
|---|---|---|
| `preaccumulate(inputs, outputs, f)` | `preaccumulate.hpp`, extended to m outputs with externally seeded output adjoints | step (b): the cohort block |
| `implicit_value(y*, F)` | `implicit_node.hpp` | `height_seed`'s `uniroot` on `mass_live_given_height - omega`, so `height_0` and `area_leaf_0` carry the derivatives of `omega`, `lma`, `rho`, `a_l1`, `a_l2`, `theta`, `a_b1` and `a_r1` |
| `hermite_interpolator<S>` | `hermite_interpolator.hpp` | the light interpolant's evaluation (§2.9) |
| `to_passive` | `ode_util.hpp` | the descending-height sort key in the light reduction |
| a forward-derivative helper | new, small | `dprofit_droot_collar_psi`, so `src/leaf_model.cpp` stops spelling `xad::fwd` |

Two odelia changes have no plant-visible name: `Step` gains `step_adjoint` and a description of
its stage structure (§2.5), and `preaccumulate` reports its recording size so plant can assert
the peak without touching `xad::Tape`.

From plant `develop`: `Species::census<Psi>` and its self-shading integral, `Control()`'s
defaults, `SCM::refine_schedule`, `r_ode_times()`. `SCM::run_mutant`, `is_mutant_run` and
`environment_history` stay in place untouched — not on the resident path, needed when invasion
returns.

From the plant AD branch: the scalar templating as the starting diff, reshaped per §2.1;
`CanopyShape<S>`; birth size through `implicit_value`; the three census metrics as one
codomain-3 functional; `Species::census<Psi>` and `QK` templated; names and pointers from the
yml rather than a macro; and one line of `scm_gradient.h` — the check that the active value
reproduces the double value, which catches a configuration member that failed to cross
double-to-active and is not an acceptance test.

### Considered and not taken

| | why not |
|---|---|
| `incomplete_gamma.hpp` | it injects partials instead of recording a series. `Leaf` stays `double` (§2.2), so the vulnerability integrals are never on a tape and there is no series to avoid recording |
| `separable_field.hpp` | the field is a Hermite over fixed fractions built from a reduction over cohorts (§2.9), not an algebraic rank-3 form. The per-species-η defect is real and its fix is grouping inside that reduction, not this header |
| `graft_value` | it makes one idiom safe — grafting a double value onto an active variable's derivative — and that idiom came from the leaf-assembly path we are not building. What remains is the general rule against deduced return types on anything returning an active value, which belongs in `plant/agents.md` §13. `implicit_value` carries its own `static_assert` |
| `compute_jacobian`, `DifferentiationTargets` | §2.6 removes the whole-run recording, so plant does not call odelia's Jacobian driver |
| `compute_jvp` and its dot-product check | forward and reverse traverse the same recorded graph, so agreement between them says nothing about correctness |
| interpolator `slope(u, step, direction)` | a value and a slope from two constructs agree only by accident; the Hermite supplies both |
| `mass_transport.hpp`, `geometric_transport`, `log_mass_` | §2.8 differences on the cohort grid instead |
| `decide` / recorded value-branch | a named type for `if`. The switch inventory is a document |
| `assemble_leaf_from`, `seam_collar_*`, `soil_consumption_active_` | a second way to assemble the leaf. It has one declared boundary (§2.4) |
| the per-strategy field-copy function, `PLANT_DIFFERENTIABLE` | §2.2 removes the need; a template instantiation replaces the flag |

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
- A task that adds a name to §2.10's five justifies it in the PR body.

`plant/agents.md` §13's outline:

1. **Your model is templated on its scalar; `double` is production.** Write the science once.
   If new physiology does not compile at the active scalar, that is the design working.
2. **Positions are `double`; values carry `S`.** Knot fractions, quadrature abscissae and sort
   keys are decided on passive values, and `to_passive` is how you say so. A knot *count* that
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
| **P0.5** | **the switch inventory** — every clamp, floor, `min`/`max` and branch on a computed value on TF24's carbon and water paths, classified, each with a measured incidence | doc + probes | every row has a number. Includes `height_max`'s selector (§2.9) and the operating-point selector (§8) |
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
| **M3** | **The normalised light coordinate.** Rebuild the field as `u = z/height_max` with fixed fractions and confirm it reproduces `rescale_spline` bit-for-bit; then Hermite convergence on that fraction set | §2.9. If it is not bit-identical, the reparameterisation is a model change and needs re-blessing | `double` only |
| **M4** | **The transport stencil across neighbouring cohorts.** Value change against the sub-grid stencil on one production run; conditioning of both against a finite difference | §2.8, and the size of the forward-value change to re-bless | `double` for the value; M1 and M2 for the derivative |
| **M5** | **The scratch.** Forward benchmark with `growth_rate_gradient`'s `thread_local` scratch, with a `Node` member, and with the block called twice | §2.4's last paragraph. The prior is that a member is no slower and possibly warmer | `double` only |

M1, M2, M3 and M5 are independent. M4's value half is independent; its derivative half needs
M1 and M2.

---

## 6. Phases 1–4

One PR per task. Each names what it touches, what it must not break, and the number or passing
test that closes it.

### Phase 1 — the templating and the trajectory

Nothing here computes a gradient. It makes the model differentiable and gives the reverse pass
something to walk.

**P1.1 — the odelia surface.** Land on `master` from `854a8e18`: `preaccumulate` extended to m
outputs with externally seeded output adjoints and a recording-size report; `implicit_value`;
`hermite_interpolator`; `to_passive`; the non-finite step-size rejection; `Step::step_adjoint`
and a description of `Step`'s stage structure so a traversal can be written against it.

*Touches* `inst/include/odelia/{preaccumulate,implicit_node,hermite_interpolator,ode_util,ode_step}.hpp`.
*Must not break* the odelia suite, and `ode_util.hpp` must still include no XAD — plant includes
it everywhere, and pulling XAD in through it is how the boundary erodes.
*Closes on* odelia green, plus one test per name exercising it from a System rather than from an
example.

**P1.2 — TF24 templated.** `TF24_Pars<S>`, `TF24_Environment<S>`, `TF24_Strategy<S>`, including
the storage block; `Internals<S>`; `Individual`, `Node`, `Species` and `Patch` reading
`value_type` from `T`. `Control` and `ExtrinsicDrivers` stay `double` (§2.2). Remove or relocate
`growth_rate_gradient`'s `thread_local` scratch as M5 directs.

*Touches* the TF24 headers and `src/tf24_strategy.cpp`, `internals.h`, `individual.h`, `node.h`,
`species.h`, `patch.h`, and the RcppR6 yml if any signature moves.
*Must not break* `test-strategy-tf24.R`, `test-strategy-tf24f.R`, `test-patch.R`,
`test-individual.R`, the stochastic tests, or the forward benchmark.
*Closes on* bit-identity: the TF24 suite passes unchanged, and one production run reproduces
develop's offspring and census to the last bit. Benchmark inside the accepted band — the AD
branch measured develop 49.57 s against branch 50.31 s, so this is achievable.
*Watch for* deduced return types on anything returning an active value. The failure is a
segfault far from its cause, invisible to valgrind because the storage is stack.

**P1.3 — trait registration.** Names and pointers from the RcppR6 yml, which is already the one
source. No macro list.

*Closes on* a test asserting that the name list and the pointer list have the same size and the
same order, and that seeding by name and by index reach the same field.

**P1.4 — the trajectory store.** Replay the resolved schedule in `double`, keeping one state per
accepted step. Restore the three birth values: `pr_patch_survival_at_birth` divides the fecundity
rate and is not in `ode_state`, so omitting it puts the error exclusively in
`offspring_produced_survival_weighted`.

*Touches* `scm.h`, `patch.h`, `species.h` (`set_birth_state`).
*Closes on* the replayed final state being bit-identical to the forward run, and `set_birth_state`
having a caller in the test suite — today it has none.
*Watch for* the two schedule records. `r_ode_times()` is the replay grid; `patch.step_history` is
the other one, and replaying it instead gave a gradient wrong by 60×.

### Phase 2 — the two changes that move forward numbers

These land before anything is verified against TF24's numbers, so there is one re-blessing rather
than two. P0.6's ecology decisions belong in the same conversation with the owner (§10).

**P2.1 — the light interpolant on a normalised coordinate.** Hold it on `u = z / height_max` with
the fractions fixed by one adaptive `construct` at the start of the run (§2.9, report 03 §1b).
`rescale_spline` goes.

*Touches* `resource_spline.h`, `tf24_environment.h`, and every `get_environment_at_height` caller.
*Closes on* M3's result: bit-identical to `rescale_spline` where M3 says it should be, otherwise
the shift is recorded and baselines re-blessed.
*Watch for* the `cap` argument and the `max(0.0, spline(height))` undershoot guard, which are
expressed in absolute height today.

**P2.2 — the slope reduction.** `Patch::compute_competition_slope(z)`, the exact `dA/dz`, fused
with `compute_competition` so `pow(z/H, eta)` is evaluated once, **merging in the same descending
height order with the same flat-index tie-break as the value reduction**. Guard `q(0, h)` per
P0.7.

*Closes on* agreement with a tight central difference of `compute_competition` across `eta` in
{1,2,4,8,10,12} and one general non-integer `eta`; and the two reductions summing the same terms
in the same order, checked rather than asserted.
*Why the order matters* — a value and a slope from sums that associate differently disagree in
their last bits, which is the pattern report 03 exists to remove, reappearing at the level of
floating-point association.

**P2.3 — the Hermite in `ResourceSpline`.** Hold `hermite_interpolator<S>` beside the fitted
cubic, which keeps its refiner and supplies the fractions. Add `get_value_and_slope_at_height`.

*Closes on* O(h⁴) on value and O(h³) on slope at the production fraction set.
*Note* the R-facing state changes shape: the fitted cubic reports (x, y) and a Hermite carries
(x, y, m). That is a `NEWS.md` entry.

**P2.4 — the transport stencil across cohorts.** Difference `g` between neighbouring cohorts
instead of on a `1e-6` sub-grid (§2.8, report 04 §1b). `node_gradient_eps`,
`node_gradient_direction` and `node_gradient_richardson` go, and with them the coupling to
`GSS_tol_abs` that nothing else records.

*Touches* `node.h` (`growth_rate_gradient`, `log_density_dt`), `species.h` for the neighbour
access, `src/control.cpp`.
*Closes on* `log_density_dt` matching M4's measured value change; offspring and the three census
metrics re-blessed with the shift recorded.
*Watch for* the ends. The first and last cohort have one neighbour, so the stencil is one-sided
there — which is the same one-sidedness the sub-grid probe had, on a grid that exists.

**P2.5 — account for `rescale_spline`'s cost before deleting it.** 17.6 µs of 193.2 is accounted
for; 175 µs per build over 20 160 builds is 3.5 s of a 59.5 s run. Worth knowing whether P2.1
recovers it or whether it was somewhere else all along.

*Closes on* the forward benchmark after P2.1, with the difference attributed.

### Phase 3 — the reverse pass

Each task closes on one of §2.6's checks, and they are ordered so that a failure has one cause.

**P3.1 — the closed-form steps.** `Patch::ode_rates_adjoint` steps (a), (d) and (e): the soil
adjoint (the drainage cascade is bidiagonal, so no linear solve), the light reduction's adjoint
from knot values back to (`area_leaf`, density, height), and the allometry adjoint. Step (b) is a
stub returning zeros at this point.

*Closes on* **V1** with the cohort blocks stubbed: the closed-form part matches the corresponding
part of a whole-`Patch` recording at one state. The soil adjoint alone is checkable this way,
which is why it is first.
*Watch for* the light reduction's adjoint having to visit sources in the same order as the forward
sum, for P2.2's reason.

**P3.2 — the cohort block, and the leaf's boundary.** Record one cohort's rate chain per §2.4.
The leaf stays `double` behind its declared boundary, with the interior operating point handled by
report 06 §6.2's one-scalar solve, the bound-pinned case by the bound's own derivative, and
selection between them by comparing `|∂Π/∂p|` against the solver's floor.

*Closes on* **V1** complete, and **V2** at stage 0 for both operating-point cases, one of which
needs a soil profile dry enough to pin the bound — `psi_soil ≥ 1.5 MPa` at `height ≥ 2 m` (§8).
The selector's incidence goes in P0.5's inventory.
*Decide here, not in P3.3.* `∂Π/∂p` is `dprofit_droot_collar_psi`, which already contains
forward-mode AD and an implicit-function term, so its gradient is the mixed second partial
`∂²Π/∂p∂φ`. A preaccumulated block carries exact first derivatives and no curvature, so the leaf
cannot be both preaccumulated and the source of `∇(∂Π/∂p)`. Either the block declares `∂Π/∂p` as
an additional output, which makes the mixed partial a first-order sweep of that output, or
`∇(∂Π/∂p)` is written by hand.
*Also here.* `bound_a = -root_zero_E` comes from a root-find, so the bound's derivative needs its
own implicit-function term. Nobody has written it.

**P3.3 — `∇(∂Π/∂p)`**, including the `ci` root-find's implicit-function term, in whichever form
P3.2 chose.

*Closes on* `d(consumption)/dψ` within finite-difference noise, against the **47.6–53.2%** error
that holding the operating point fixed gives today. That error is fully explained by cancellation
of the search's own displacement, so a fix that does not remove it has not addressed the cause.

**P3.4 — remove the last `xad::` from plant.** Replace `xad::fwd<double>` and `xad::derivative`
in `src/leaf_model.cpp` with the odelia helper.

*Closes on* `grep -r 'xad::' plant/inst plant/src` returning nothing. Forward mode stays; only
the spelling moves.

**P3.5 — the stencil's adjoint and the stage recursion.** Step (c): distribute `λ_g` across the
three neighbouring blocks that P2.4's stencil reads. Then drive `Patch::ode_rates_adjoint` from
`Step::step_adjoint`.

*Closes on* **V3** — one step's `λ_y` against a finite difference of one step. The reference
failure for a lost tableau term is a **19%** error with the correct sign and no message, so a
whole-run check would not localise it.

**P3.6 — the census metrics and the entry point.** `Species::census<Psi>` templated on `S`; the
three metrics as one codomain-3 functional so three Jacobian rows come off one recording;
`stand_gradient()`; `plant/agents.md` §13.

*Closes on* **V4** — TF24 census and R0 at `max_patch_lifetime = 105.32`, resident, against a
re-run finite difference on the identical resolved schedule, under 2 GB peak. And on the count: a
developer reads §13 and adds a fourth metric without touching tape code.
*Watch for* trait adjoints failing to accumulate across cohorts. Treating each cohort as a
separate input gives **41–51%** of the answer with the correct sign and nothing thrown, so the
test asserts the value, not finiteness.

### Phase 4 — after the prize

Separate pushes, sequenced by what each needs.

| | what it is | what it needs first |
|---|---|---|
| **invasion gradients** | drop step (d) (§2.7). Bring back `run_mutant` and the recorded environment, and make a missing `save_RK45_cache` an error rather than a search failure | Phase 3 |
| **FF16 and K93** | the templating plus the existing census reduction; retire `ff16_production_kernel.h`; port the `smooth_positive` clamp fix and K93's `k_I` channel; tighten FF16's gradient test, which passes at 1e-2 where the truth is ~1e-6 | Phase 3 |
| **two species** | two `Leaf` objects, `Species::consumption_rate`'s `size() < 2` per species, and per-species η grouped inside the light reduction. Every incidence number in reports 06 and 07 is single-species | FF16 |
| **calibration** | `least_squares` reads intermediate trajectory states as active values, which a `double` trajectory breaks without a message. Either the functional declares which steps it reads and contributes a per-step adjoint seed, or calibration stores a second denser trajectory. Record the decision before opening it | Phase 3 |
| **node-schedule refinement** | point it at the coupling field. Recording the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84% | invasion, for the comparison |
| **TF24f** | the tracked collar state reparameterised onto its feasible interval, so the clamp and its two roles go away. Its `∂Π/∂p` is a rate, so the mixed second partial P3.2 has to decide about does not arise | Phase 3, and the owner on `plant#61` |

---

## 7. What we are deliberately not building

- No third template parameter, no new System type, no second `Patch`.
- No whole-run recording (§2.6), and therefore no `Solver` members on `SCM`.
- No second implementation of anything: no separate leaf assembly, no shadow active fields, no
  second parameter struct.
- No capability flags or SFINAE detection structs. A concept and `if constexpr` where a
  compile-time choice is needed.
- No `decide()` type. The switch inventory is a document.
- No check that forward and reverse agree, in place of a finite difference.
- No component-level tape size work: 0.018% of TF24's total against a required factor of
  10²–10³.
- No mass chart.
- No analytic `dg/dh` substituted for the stencil (§2.8) — it removes the upwinding.
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
