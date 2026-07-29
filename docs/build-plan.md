# Build plan: exact gradients of plant's emergent outputs

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
Both AD feature branches contain work worth taking; §3 lists it item by item.

**Status: under review. Nothing here is built. Phase 0.5's measurements decide three of the
design choices below, so they come before Phase 1.**

---

## 1. What we are building

Exact trait and parameter gradients of the SCM's emergent outputs — the three census metrics
(LAI, biomass, basal area) and R0/offspring — for K93, FF16 and TF24, at production lifetime
(`max_patch_lifetime = 105.32`), verifiable against finite differences, adding no engine
vocabulary per model, and without slowing the forward model.

The acceptance test is a number and a count. The count: a plant developer adding an emergent
metric writes one scalar-templated reduction and registers a name, touching no tape code and
no odelia code.

| | who | call |
|---|---|---|
| 1 | forest ecologist | `stand_gradient(scm, metrics, traits)` — emergent LAI/biomass/basal area |
| 2 | evolutionary ecologist | `offspring_production_gradient(...)` — a selection gradient, for locating singular strategies |
| 3 | modeller | `value_and_gradient(p)` in an L-BFGS loop, both from one recording |
| 4 | plant developer | add a metric with one templated reduction and a registered name |
| 5 | maintainer | compare AD against a re-run finite difference in plain R, same shape |

Stories 1 and 2 are the primary workflows. Story 3 is Phase 5 and needs a decision first.

**Accuracy is not one standard.** Locating singular strategies needs the gradient's sign and
its zero crossing, so nothing approximate will do. Calibration needs a descent direction, and
L-BFGS converges on an inexact gradient. Phase 5 may therefore ship on a cheaper adjoint than
Phases 1–3, and should say which accuracy it provides.

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
| `Control` — never a differentiation target | `Pars<S>` |
| `ExtrinsicDrivers` and their interpolator — fixed input data | the Strategy's precomputed members (`eta_c`, `height_0`, `area_leaf_0`) |
| `Leaf` — a sub-model with a declared boundary (§2.4) | `Internals<S>` |
| knot positions, quadrature abscissae, sort keys | `Environment<S>`'s state; the light interpolant's knot **values** |

Two consequences worth stating.

**The double-to-active copy is almost nothing.** With `Control` and `ExtrinsicDrivers` out, it
is `Pars<S2>` from the values of `pars`, then `prepare_strategy()` re-derives the rest. The
per-strategy field-copy function on the AD branch existed to carry things that no longer need
carrying.

**A gradient is defined against one `Control`.** `GSS_tol_abs`, `ci_abs_tol`,
`node_gradient_eps`, `schedule_eps` and `shading_model` all change the trajectory and hence
the gradient. The entry point records the `Control` it differentiated at, and refuses to
compare two gradients taken at different ones.

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

Under §2.1 the class is the templated form, so the composites move into it and the header
retires. The same rule rules out the leaf-assembly duplicates listed in §3.3.

### 2.4 The cohort block, and what its inputs are

The unit the reverse pass records is **one cohort's `compute_rates` at one Runge-Kutta stage**.
Its declared inputs are:

```
own ODE state (6 for TF24, plus log-density and offspring)
the light interpolant's 65 knot VALUES
soil water potential, one per layer (5)
the seeded traits
```

**The light enters as knot values, not as sampled light.** The crown quadrature reads light at
`z = u_k · h`, so the sample positions depend on the cohort's own height and sampled light is
an intermediate, not an input. Putting the interpolation and the quadrature inside the block
means the tape carries the moving-bound term and the `q(z,h)` dependence without anyone
writing them, and the sweep returns the adjoints of the knot values directly. Cost is about 21
Hermite span evaluations on a tape that holds one cohort.

The block's outputs are the cohort's rates and its per-layer uptake, plus — if the transport
stencil is recorded there (§6, Phase 2) — the growth-rate derivative `dg/dh`.

Nothing may be read from enclosing scope. That is checkable rather than conventional: a
channel left out of the input list cannot be reached from inside the block, so it fails to
compile or reads as a constant, not as a gradient missing one term.

`Leaf` is `double` and sits inside the block behind a declared boundary: in (soil water
potential per layer, radiation, traits), out (profit, per-layer uptake). Its own derivatives
reach the block's tape through injected partials (§2.6).

### 2.5 Two recordings, for two purposes

| | what it records | scale | purpose |
|---|---|---|---|
| **whole-run** | the entire SCM run on one tape, via `compute_jacobian` | short lifetime only (~220 GB at production) | the reference that is not a finite difference |
| **per-cohort** | one cohort's block per stage, swept and released | production lifetime | what ships |

They must agree wherever both fit, and that agreement is a gate. Keeping both is deliberate:
finite differences on TF24 are a step-size family with a narrow usable window, so a second
independent reference matters.

The per-cohort pass:

```
1. run_scm(refine_schedule = TRUE)   double. resolves the node schedule and the ODE grid.
2. replay in double, storing one state per accepted step   (22.5 MB at production)
3. backwards, per step:
     a  soil adjoint            closed form: the drainage cascade is bidiagonal, no solve
     b  per cohort: record the block, seed its output adjoints, sweep, read input adjoints
     c  light knot adjoints -> (area_leaf, density, height)   the summed reduction, closed form
     d  allometry adjoint       closed form
4. reduce the final state through the functional; return doubles
```

Peak is one cohort's block, and it does not grow with run length, stage count or the number of
seeded traits. Steps (a), (c) and (d) cost what their forward evaluation costs. Step (c) is
now only the cohort sum, because the interpolation moved inside the block.

### 2.6 What crosses from odelia into plant

Six names. No plant file spells `xad::`.

| name | from | plant's use |
|---|---|---|
| `preaccumulate(inputs, outputs, f)` | `preaccumulate.hpp`, extended | step (b): record a block on its own tape, seed its output adjoints from outside, sweep, return the input adjoints. Today's version is the one-output, internally-seeded case |
| `implicit_value(y*, F)` | `implicit_node.hpp` | the `ci` root-find and the birth-size solve, declared by residual rather than by search |
| `hermite_interpolator<S>` | `hermite_interpolator.hpp` | the light interpolant, value and slope from one construct |
| `compute_jacobian` | `gradient.hpp` | the whole-run recording |
| `DifferentiationTargets` | `gradient.hpp` | which parameters and initial-state entries to seed |
| `to_passive` | `ode_util.hpp` | knot positions, quadrature abscissae, sort keys |

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD
transitively. The rule is that no plant author writes `xad::`, checked by
`grep -r 'xad::' plant/inst plant/src` returning nothing. develop has one violation today,
in `src/leaf_model.cpp`.

**Forward-mode AD stays in plant.** The leaf's gas-exchange optimum has one input and one
output, so forward mode plus the implicit function theorem is the right method and
`dprofit_droot_collar_psi` already uses it. Only the spelling moves: `xad::fwd<double>` and
`xad::derivative` become one odelia helper.

### 2.7 Two workflows, both already in the SCM

| workflow | SCM entry | environment during the run | gradient meaning |
|---|---|---|---|
| invasion | `run_mutant()` | read from the recorded resident values | selection gradient of a rare mutant |
| total | `run()` | recomputed from the cohorts as they evolve | d(metric)/d(trait) with self-shading feedback |

`SCM::run_mutant()` already pins integration to the recorded resident step history, reads the
recorded environment, and suppresses the mutant's self-competition through `is_mutant_run`. So
story 2 is the derivative of a run plant already has.

**Phases 1–3 deliver the invasion workflow only.** The total workflow requires the canopy to be
recomputed during the reverse pass, which is deferred to Phase 4. Until then the engine's
answer is the invasion gradient and the API says which one it is.

### 2.8 Four recorded structures

Adaptive constructions make parameter-dependent decisions, and differentiating those decisions
corrupts the tape. Each is recorded once on the double pass and replayed at fixed positions.

| | recorded | owner | phase |
|---|---|---|---|
| **R0** | the node schedule: which cohorts exist and when introduced | plant | 1 |
| **R1** | the ODE step times (`advance_fixed`) | odelia | 1 |
| **R2** | quadrature abscissae and light interpolant knot positions | plant, odelia's interpolant | 2 |
| **R3** | the resident canopy read by the focal cohorts | plant | 4 |

R0 and R1 are what the invasion gradient needs, plus R2 once a census integrates over height.
With R0 recorded, introduction times are constants, so introductions widen the state without
adding a discontinuity.

**R2 has two cases and they are not interchangeable.** For the light interpolant the knot
positions are recorded and the values active. For a census integrated over height the
integration bound *is* an active plant height, so the quadrature abscissae move with it — that
needs the scalar-templated `QK`, and replaying fixed abscissae would drop the bound's
contribution.

**R3 is where a wrong answer can pass silently.** On the total path the canopy must be
recomputed from the active cohorts at the recorded knot positions. Reading the recorded
environment *values* there returns the invasion gradient with the self-shading cross term
missing — a plausible number and no error. Phase 4 carries a positive control for exactly
that.

### 2.9 The light interpolant: two jobs, two types

`ResourceSpline` holds both, and they do different things:

| | type | job |
|---|---|---|
| knot placement | the existing value-fitted cubic, with its adaptive refiner | discovers the knot set on the double pass. Positions only |
| evaluation | `hermite_interpolator<S>` | evaluates value and slope at the recorded positions, carrying `S` |

That is R2's split written as code: the refiner supplies positions, the Hermite supplies
values and slopes. The Hermite has no refiner and cannot replace the fitted cubic; it is an
addition with exactly one consumer.

Two things follow. `hermite_interpolator::init` takes `dydx`, which nothing supplies today —
`Patch::compute_competition_slope` is P2.4. And the Hermite is not a candidate for the leaf's
four vulnerability and transpiration curves or for the extrinsic drivers: those call
`set_extrapolate(false)` and depend on it, while the Hermite extends linearly by construction.

---

## 3. What to take from where

### 3.1 From plant `develop`

| | verdict |
|---|---|
| `ff16_production_kernel.h` | **retire.** Its elementary functions become methods on `FF16_Strategy<S>`; the composites and `FF16ProdPars` go because the class is the templated form (§2.3) |
| the three `test-ff16-*-ad.R` gradient checks | **take the assertions.** The only working gradient tests in either tree. Their in-test `sourceCpp` build is unnecessary once plant has a compiled entry point |
| `Species::census<Psi>` (`species.h:64`) and the self-shading integral on it | **take.** Phase 2 templates it on `S`; the reduction is unchanged |
| `SCM::run_mutant()`, `is_mutant_run`, the recorded resident environment | **take, unchanged.** §2.7: this is workflow 2 |
| `Control()` as the fast default, `SCM::refine_schedule` in C++, `r_ode_times()` | **take.** `r_ode_times()` is the one source of the replay grid |

### 3.2 From odelia branch `claude/odelia-ad-tape-reverse-496fuf`

| commit(s) | what | verdict |
|---|---|---|
| `2a60998` | `preaccumulate` — record a block's local derivatives instead of its internals, on its own tape, with a declared input list and a `static_assert` on the return type | **take and extend** to m outputs with externally seeded output adjoints. This is §2.5 step (b) |
| `16cff79`, `7aa9c69`, `7a30940`, `0c62bda` | `implicit_node.hpp` — `implicit_value(y*, residual, denom_sign)`, 84 lines | **take.** The caller declares the equation; the baseline's alternative makes the caller compute partials by hand |
| `49f7a7f`, `4c0f3b8` | `hermite_interpolator.hpp` — C1, value and slope per knot | **take.** Two-knot locality is what keeps §2.5 step (c) O(1) per read |
| `baf6eae` | `to_passive`, safe for nested types | **take** |
| `eb514e9` | `graft_value` | **take.** It makes the dangling expression-template pattern unwriteable; keep its `static_assert`s |
| `0139b92` | reject a non-finite step-size decision | **take.** Correct independently of AD |
| `b426ac4` | per-term `Tape` size accessors | **take.** Needed to report a recording's size |
| `aece41d` | `incomplete_gamma.hpp` — exact Weibull antiderivative with injected partials | **conditional.** Adopt only if it beats the leaf's pre-integrated spline on a measured forward run |
| `be13d78` | `separable_field.hpp` | **take in Phase 4** as the per-species-η fix (P4.3), on its own merits |
| `7505c93` | `compute_jvp` and its dot-product check | **leave.** Forward and reverse traverse the same recorded graph, so agreement between them says nothing about correctness |
| `cc6571c` | interpolator `slope(u, step, direction)` secant | **leave.** A value and a slope from two constructs agree only by accident; the Hermite supplies both |
| `f9d6ad8`, `ac6a988` | `mass_transport.hpp` | **leave.** Report 04 does without it |
| `31fb243` | `decide` / recorded value-branch | **leave.** A named type for `if`; the switch inventory is a document |
| `18a56ed`, `28059bd`, `73739d7`, `f169540`, `5c023e2` | the step-local sweep trials | **leave the code, keep the measurements.** Reports 01 and 02 rest on them |

`supplied_derivative.hpp` is superseded by `implicit_value`, and `register_implicit` is already
deleted. `28059bd` removed 697 lines and four primitives because nothing but their own examples
called them, so every item above must have a named consumer in §6 before it lands.

### 3.3 From plant branch `claude/odelia-ad-tape-reverse-496fuf`

| | verdict |
|---|---|
| **the scalar templating** — `Internals_<S>`, `TF24_Strategy_<S>`, the containers reading `value_type` | **take as the starting diff, reshaped per §2.1.** One model at a time, with the reference tests checking bit-identity. Two changes: read `value_type` from `T` rather than adding a parameter, and collapse the double `pars` plus its active copy into one `Pars<S>` |
| scalar-templated `CanopyShape` | **take.** It closed a measured `eta` channel in all three models and is §2.1 in miniature |
| the other three channel fixes: `smooth_positive` on FF16's growth/fecundity clamp, birth size via the implicit function theorem, K93's `k_I` growth channel | **take, one PR each,** with the repaired channel as the test |
| the three census metrics as one codomain-3 functional | **take.** Three Jacobian rows from one recording, measured at +0.38% |
| `scm_gradient.h`'s entry shape — resolve the schedule in double, replay it, one recording per output row | **take the shape, rewrite the body** per §2.5 |
| `Species::census<Psi>`, the competition trapezium and `QK` templated | **take.** R2's moving-abscissae case needs the templated `QK` |
| `field_ptrs()` / `field_names()` from one list | **take the invariant, drop the macro.** With `Pars<S>` the RcppR6 yml is already the one source |
| the 28 `*_driver.cpp` + `test-ad-*.R` in-test builds | **take the assertions, drop the arrangement.** With a compiled entry point, a test that compiles C++ tests the toolchain |
| `assemble_leaf_from`, `seam_collar_psi_input`, `seam_collar_uptake_partials`, `soil_consumption_active_` | **leave.** A second way to assemble the leaf (§2.3). The leaf has one declared boundary (§2.4) |
| the per-strategy field-copy function | **leave.** §2.2 removes the need |
| `PLANT_DIFFERENTIABLE` | **leave.** A compile-time flag where an instantiation suffices |
| `geometric_transport`, the extended mass chart, `log_mass_`, `census_leaf_area` | **leave.** Report 04 does without them |

One thing in `scm_gradient.h` to keep, named for what it does: **the check that the active
value reproduces the double value**, which stops when they differ by more than 1e-8 relative.
It catches a configuration member that failed to cross double-to-active. It does not check the
gradient — a 0.2% difference in value has produced a sign-flipped gradient in this model
family — so it is a configuration check, not an acceptance test.

One trap recorded there and nowhere else: two schedule records exist, and replaying
`patch.step_history` where `r_ode_times()` was wanted gave a gradient wrong by 60×.

---

## 4. Documents

One home per fact, and the home is named before the code is written.
`docs/audit-2026-07.md` indexes what is archived.

| document | owns |
|---|---|
| `docs/build-plan.md` | this plan: architecture, what to take, tasks, gates |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites |
| `docs/reports/01`–`04`, `06`, `07` | the derivations and measurements the plan rests on. Not edited to track progress |
| `odelia/AUTODIFF.md` | the System requirements, the record-and-replay hooks, functionals |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary |
| `plant/agents.md` §13 (new) | how a plant model author makes their science differentiable |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable |

Two rules, enforced per task:

- A task that changes what a model author writes changes `plant/agents.md` §13 in the same PR.
  The section is short by construction: past two pages, there is too much to learn.
- A task that adds a name to §2.6's six justifies it in the PR body.

`plant/agents.md` §13's outline:

1. **Your model is templated on its scalar; `double` is production.** Write the science once.
   If new physiology does not compile at the active scalar, that is the design working.
2. **Positions are `double`; values carry `S`.** Knots, quadrature abscissae and sort keys are
   decided on passive values, and `to_passive` is how you say so. A knot *count* that depends
   on an active value makes the recorded computation depend on the state.
3. **An inner solve is declared by its residual,** through `implicit_value`. Never
   differentiate the iteration that found the root: `golden_section_max`'s result is affine in
   its bracket and independent of the objective's values, so recording the search returns the
   bracket's derivative.
4. **Never define a rate as a numerical derivative of an active quantity.**
5. **A clamp, floor, `min`/`max` or `if` on a computed value is a derivative decision.** Put
   it in the switch inventory with the incidence that justifies it.
6. **Never give a deduced return type to anything returning an active value.** XAD operators
   return expression templates holding references to their operands; `graft_value` exists so
   the pattern is not written by hand.

---

## 5. Phase 0 — forward-model prerequisites, no AD

[`tf24-correctness.md`](tf24-correctness.md) and report 07. Here because the bit-identity
acceptance test cannot pass until P0.1 lands: report 01 §12 asks for "re-run one cohort's rates
from its inputs and compare bit for bit", and on develop that fails on 33.78% of production
records for reasons unrelated to gradients.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort reading the previous cohort's deep-layer uptake | 1 line + baselines | a seedling's deep layers read 0 on a leaf that solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake whatever ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip test | 1 line + test | round trip to 1e-12 for θ in (θ_r, θ_sat] |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | **the switch inventory** — every clamp, floor, `min`/`max` and branch on a computed value on TF24's carbon and water paths, classified, each with a measured incidence | doc + probes | every row has a number. Report 06 §7/§9b, report 07 and §8 supply most of it |
| **P0.6** | the two ecology decisions: leaf respiration counted twice, and `establishment_probability`'s hard gate | owner's call | a recorded decision either way, with a `scientific_version` bump |
| **P0.7** | `q(z, height)` divides by `z`, so `q(0, h)` is NaN for every `h`, and the light interpolant's lowest knot is exactly `z = 0` | small | `q(0, h)` finite for every `h` |

P0.5 is the input Phase 3 needs: you cannot choose which switches to smooth before knowing
which ones fire. **P0.6 gates Phase 3, not Phase 1.**

---

## 5b. Phase 0.5 — measurements that decide the design

Five measurements, none on the critical path, each able to kill or confirm one choice in §2
before the phase that depends on it. M1 and M2 are independent and can run together; M3 is
independent of both.

| | measurement | what it decides | needs |
|---|---|---|---|
| **M1** | **A block with a moving integration bound.** An interpolant integrated over `[0, h]` with `h` a declared input; check the height adjoint against a finite difference. This is the structure that fails if §2.4 is wrong | whether the block boundary closes, including the moving bound | odelia only |
| **M2** | **`CanopyShape<S>` alone, ported to develop.** One file; all three models use it | §2.1's shape, bit-identity, and the forward benchmark, at the smallest possible cost | the AD branch already wrote it |
| **M3** | **Hermite convergence on a knot set taken from a production step**, plus the knot-position channel against knot density. Report 03's own two falsifiers | §2.9, and report 03's +0.33%…+5.3% forward-cost bracket | `double` only |
| **M4** | **The transport stencil inside a block.** Take the stencil's trait derivative from the tape at `node_gradient_eps` = 1e-4, 1e-6, 1e-8; K93 first as a control, then TF24 | report 04's route A, and whether the amplification is real | M1, M2 |
| **M5** | **Two species.** Two `Leaf` objects, `Species::consumption_rate`'s `size() < 2` per species, and the η defect in the light field all appear together | the scope of every incidence number in reports 06 and 07, all of which are single-species | no AD |

Two facts M4 rests on. **develop already pays route A's forward cost**: `growth_rate_gradient`
calls `growth_rate_given_height` on a `thread_local` scratch for every cohort at every stage,
so the second rate evaluation — and the leaf solve inside it — is already in the 53 s. Route A
costs recording it, not evaluating it. And the hazard M4 must face is that taking `dg/dh`
analytically instead of from the stencil is route C, which the AD branch found destabilises the
density transport unless the growth clamp is smoothed to `eps ~ 5e-2`. That is an ODE
stability question, not a gradient one, and report 04 leaves it open. Route A keeps the
stencil's value and takes its derivative from the tape, which is why it is first.

---

## 6. Phases 1–5

One PR per task, each with a gate that is a number or a passing test. Phases are ordered so
that a failure is attributable.

### Phase 1 — the engine, on K93

K93 has no leaf, no soil and closed-form rates, so a failure belongs to the engine. Its
gradient is the only one with a reference today.

| | task | gate |
|---|---|---|
| **P1.1** | Land §3.2's items on odelia `master` from `854a8e18`, each with a plant-side consumer named in the PR body. `preaccumulate` extended to m outputs and external seeding is the largest | odelia suite green; `ode_util.hpp` still includes no XAD, since plant includes it everywhere |
| **P1.2** | `K93_Pars<S>`, `K93_Strategy<S>`; containers read `value_type` from `T` | `test-strategy-k93.R` bit-identical; forward benchmark within the accepted band |
| **P1.3** | Register traits by name from the yml, the one source that already exists | names and pointers cannot disagree — a test asserting size and order |
| **P1.4** | Store the trajectory: replay the resolved schedule in double, one state per accepted step; restore the three birth values (`pr_patch_survival_at_birth` divides the fecundity rate and is not in `ode_state`) | replayed final state bit-identical to the forward run; `set_birth_state` called by a test, which it is not today |
| **P1.5** | The per-cohort reverse pass (§2.5). Record the block, seed, sweep, release; soil and allometry adjoints closed form | K93 census gradient matches a re-run finite difference to its noise floor; recording size reported and constant in run length and in target count |
| **P1.6** | Trait adjoints accumulate across cohorts | the discriminating test: treating each cohort as a separate input gives 41–51% of the answer with the right sign and nothing thrown. Assert the correct value, not finiteness |
| **P1.7** | The development entry point: `block_adjoints(scm, step, cohort, output_seed)` against a finite difference of the same block | a wrong adjoint is attributable to one block. Lives in `tests/testthat/`, deleted at the end of Phase 3 |
| **P1.8** | The whole-run recording via `compute_jacobian`, at a lifetime where it fits | the two recordings agree; Cash-Karp stage traversal as a general `sum over j < i`, accepted steps only. The reference failure is a 19% error with the correct sign and no message |
| **P1.9** | `plant/agents.md` §13 first draft; the R entry `stand_gradient()`, invasion workflow | a developer reads §13 and adds a metric |

**Gate: K93 census and R0 verified against a re-run finite difference at production lifetime,
under 2 GB peak, forward model not slowed, and §13 exists.**

### Phase 2 — FF16

| | task | gate |
|---|---|---|
| **P2.1** | `FF16_Pars<S>`, `FF16_Strategy<S>`; move `ff16_production_kernel.h`'s composites into the class and delete `FF16ProdPars` | `test-strategy-ff16.R` and the FF16 reference comparison bit-identical |
| **P2.2** | The four channel fixes (§3.3), one PR each | each with the repaired channel as its test: `eta`, `a_l1`/`a_l2`, `omega`/`height_0`, `k_I` |
| **P2.3** | Template `Species::census<Psi>`, the competition trapezium and `QK` on `S` — R2's moving-abscissae case | a census whose integration bound is an active height carries the bound's contribution, verified against a finite difference |
| **P2.4** | `Patch::compute_competition_slope(z)` — the exact `dA/dz`, computed with `compute_competition` so `pow(z/H, eta)` is evaluated once | agrees with a tight central difference across `eta` in {1,2,4,8,10,12} and one general non-integer `eta` |
| **P2.5** | `ResourceSpline` holds the Hermite beside the fitted cubic per §2.9; add `get_value_and_slope_at_height` | O(h⁴) on value and O(h³) on slope on a production knot set (M3 has already measured this) |
| **P2.6** | Account for `rescale_spline`'s unmeasured 91% — 17.6 µs of 193.2 is accounted for — then time a Hermite build against it | the forward-cost bracket collapses to one number, inside budget. Worth doing for develop alone: 175 µs per build is 3.5 s of a 59.5 s run |
| **P2.7** | Record the transport stencil in the block, per M4's result | the stencil's trait derivative matches a finite difference; `log_density_dt` unchanged in value |
| **P2.8** | Switch the light read; wire the slope into the crown integral's height channel; tighten FF16's gradient test | FF16 census and R0 verified at production lifetime. The current test passes at 1e-2 where the truth is ~1e-6, so a 100× regression would pass |

### Phase 3 — TF24

| | task | gate |
|---|---|---|
| **P3.1** | `TF24_Pars<S>`, `TF24_Environment<S>`, `TF24_Strategy<S>`, including the storage block | `test-strategy-tf24.R` bit-identical |
| **P3.2** | The leaf's declared boundary (§2.4). `ci` through `implicit_value`; the interior operating point through report 06 §6.2; the bound-pinned case through the bound's own derivative; selection on `\|∂Π/∂p\|` | both cases verified against a finite difference; the selector's incidence in P0.5's inventory |
| **P3.3** | `∇(∂Π/∂p)`, including the `ci` root-find's implicit-function term | `d(consumption)/dψ` within finite-difference noise, against the 47.6–53.2% error that holding the operating point fixed gives today |
| **P3.4** | Replace `xad::fwd` in `src/leaf_model.cpp` with the odelia helper (§2.6) | `grep -r 'xad::' plant/inst plant/src` returns nothing |
| **P3.5** | TF24 census and R0 at `max_patch_lifetime = 105.32`, invasion workflow | verified against the tight-inner-tolerance reference on the identical resolved schedule, under 2 GB peak |

P3.3 has a fork M1 does not settle and P3.2 must choose. `∂Π/∂p` is `dprofit_droot_collar_psi`,
which already contains forward-mode AD and an implicit-function term, so its gradient is the
mixed second partial `∂²Π/∂p∂φ`. A preaccumulated block carries exact first derivatives and no
curvature, so the leaf cannot be both preaccumulated and the source of `∇(∂Π/∂p)`. Either the
block declares `∂Π/∂p` as an additional output, which makes the mixed partial a first-order
sweep of that output, or `∇(∂Π/∂p)` is written by hand. Decide in P3.2, not P3.3.

### Phase 4 — the total workflow, and what it needs

| | task | gate |
|---|---|---|
| **P4.1** | R3: recompute the canopy from the active cohorts at the recorded knot positions during the reverse pass | the two workflows differ and the total one carries the self-shading cross term. **Positive control: reading recorded values on the total path must reproduce the invasion gradient** |
| **P4.2** | `stand_gradient(..., feedback =)` | both workflows reachable from R, with a stated default |
| **P4.3** | Per-species η: group sources by η, rank 3·n_η, reducing to today's rank 3 when η is shared | the two-species check goes exact where it now computes 7.98e+14 against 0.118; the descending-height sort stays deterministic with differing η |
| **P4.4** | Point node-schedule refinement at the coupling field | recording the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84%. The current criterion selects cohorts by contribution to reproduction, which has already converged |

P4.3 is a prerequisite for the total workflow being usable: stories 1 and 2 vary traits across
species by definition, and the light field is wrong for species of differing η — including the
forward value, since η is read from `species[0]` only.

### Phase 5 — calibration, decision first

`least_squares` reads intermediate trajectory states as active values (`get_history_step(idx)`
then `ode_state` into `value_type`). A stored `double` trajectory breaks that without a
message: the value stays right and the derivative through the observations is lost. Two
candidates:

- **(a)** the functional declares which steps it reads and contributes a per-step adjoint seed.
  One new concept for everyone.
- **(b)** calibration stores a second, denser trajectory. No new concept, more memory.

Record the decision before Phase 5 opens. §1's note on accuracy applies here.

---

## 7. What we are deliberately not building

- No third template parameter, no new System type, no second `Patch`.
- No second implementation of anything: no separate leaf assembly, no shadow active fields, no
  second parameter struct, no second assimilation path (§2.3).
- No capability flags or SFINAE detection structs. A concept and `if constexpr` where a
  compile-time choice is needed.
- No `decide()` type. The switch inventory is a document.
- No check that forward and reverse agree, in place of a finite difference.
- No component-level tape size work: 0.018% of TF24's total against a required factor of
  10²–10³.
- No mass-chart extension.
- **The stochastic solver is out of scope.** It shares the Strategy, so it must keep compiling
  and its tests must keep passing; it is not differentiated.
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
so P0.5's inventory carries it with its incidence.

The bound's own derivative is not yet written: `bound_a = -root_zero_E` comes from a root-find,
so it needs an implicit-function term of its own. P3.2 owns it.

**One thing to measure next.** With `Π_pp ≈ −4`, displacing `p*` by `1e-4` should move
`∂Π/∂p` by about `4e-4`; report 06 §9 measures 11–23 at `GSS_tol_abs = 1e-3`. Report 04 §5
explains the shape: `golden_section_max`'s result is affine in its bracket within one
comparison pattern and jumps when the pattern changes, so the displacement is bracket-scale
rather than tolerance-scale. That reconciles the two numbers and is a property of the search,
not of the geometry, so it does not change §6.2's derivation. It does bear on M4, because the
same steps are what the transport stencil differences.

---

## 9. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| a channel exists that templating cannot reach | a derivative obtainable only through a second implementation | P1.5 on K93, the cheapest discovery available |
| the block boundary does not close around a moving integration bound | the height adjoint disagrees with a finite difference | **M1**, before Phase 1 |
| the forward model slows under templating | benchmark outside the accepted band, or reference numbers move | **M2**, then P1.2 / P2.1 / P3.1, each gated on bit-identity. The AD branch measured develop 49.57 s against branch 50.31 s |
| reading recorded environment values on the total path | a plausible number with the self-shading cross term missing, no message | P4.1's positive control |
| trait adjoints do not accumulate | a fixed fraction of the finite difference with the correct sign, nothing thrown | P1.6 |
| the stage traversal loses a term on Cash-Karp's denser tableau | a 19% error, correct sign, no message | P1.8 |
| the leaf's boundary is wider than §2.4 declares | P3.2 grows an output nobody declared | P3.2; P0.5's inventory should predict it |
| analytic `dg/dh` destabilises the density transport | the trajectory leaves the bounded region unless the growth clamp is smoothed to `eps ~ 5e-2` | **M4** |
| every incidence number is single-species | a switch that never fires with one species fires with two | **M5** |
| the value-reproduction check is read as an acceptance test | a 0.2% difference in value has produced a sign-flipped gradient | every gate compares AD against a re-run finite difference |

---

## 10. Review gates on this plan

1. **Does the scalar belong on the types that own the parameters, with `<T,E>` unchanged?**
   **M2** answers it for one file; P1.2 confirms it for a model.
2. **Does the block boundary close as §2.4 states, with the light entering as knot values?**
   **M1** answers it without plant.
3. **Is the leaf's boundary (soil water potential per layer, radiation, traits) → (profit,
   per-layer uptake)?** Report 06 §5 says so. A sixth quantity changes P3.2's shape, and the AD
   branch's four leaf hooks are what a wider boundary looks like when it is not declared.
4. **Do P0.6's two ecology decisions bump `scientific_version`?** They change every simulated
   number, so they want the owner before anything is verified against them.

**Order: M1 and M2 in parallel, then (3); (4) gates nothing before Phase 3.**
