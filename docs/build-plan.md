# Build plan: exact gradients of plant's emergent outputs

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
The two AD feature branches are quarries; §3 says what to take from each, per item.

**Status: under review. Nothing here is built. Do not start Phase 1 until §9's gates are
closed.**

---

## 1. What we are building

Exact trait and parameter gradients of the SCM's **emergent** outputs — the three census
metrics (LAI, biomass, basal area) and R0/offspring — for K93, FF16 and TF24, at production
lifetime (`max_patch_lifetime = 105.32`), verifiable against finite differences, **adding no
engine vocabulary per model** and without regressing the forward model.

The objective is developer experience. A gradient engine nobody can extend is a failed
gradient engine, so the acceptance test is not only a number but a count: a plant developer
adding a new emergent metric writes **one scalar-templated reduction and registers a name**,
touching no tape code and no odelia code.

| | who | call |
|---|---|---|
| 1 | forest ecologist | `stand_gradient(scm, metrics, traits)` — emergent LAI/biomass/basal area |
| 2 | evolutionary ecologist | `offspring_production_gradient(...)` — a selection gradient, for locating singular strategies |
| 3 | modeller | `value_and_gradient(p)` in an L-BFGS loop, both from one recording |
| 4 | plant developer | add a metric with one templated reduction + a registered name |
| 5 | maintainer | compare AD against a re-run finite difference in plain R, same shape |

(1) and (2) are the primary workflows. (3) is Phase 5 and needs a decision first (§6).

---

## 2. The architecture

### 2.1 One implementation of the science, carrying the scalar it is evaluated at

`S = double` is production. There is no second copy of any model equation for AD to read.

The scalar lives with the types that own the parameters — `T = TF24_Strategy<S>`,
`E = TF24_Environment<S>` — and the containers derive it:

```cpp
template <typename T, typename E> class Individual {
  using value_type = typename T::value_type;   // ... and likewise Node, Species, Patch
```

`Patch<T,E>` already declares `using value_type = double;` (`patch.h:22`); the change is to
derive it rather than assert it. **No template parameter is added.** The existing `<T,E>`
shape is unchanged, RcppR6's instantiation table is unchanged in shape, and
`Solver<patch_type>` is unchanged. There is no `SCMSystem`, no `StrategyConcept`, no second
`Patch`.

**One parameter store per model, templated.** `TF24_Pars<S>`, not a double `pars` plus a
lifted active struct. A named trait then registers active directly, and nothing has to copy
fields between two representations.

Two properties follow, and they are why this shape is the one:

- **Exactness is structural.** The gradient reads the model's own allometry, its own
  quadrature, its own reductions. There is no bit-for-bit copy to maintain because there is
  no copy.
- **Forgetting is a compile error.** A model author who adds physiology gets it
  differentiated or gets a build failure — never a silently zero channel.

### 2.2 No parallel path, for anything

`inst/include/plant/models/ff16_production_kernel.h` is the counter-example and it is not to
be extended or imitated. Five elementary functions there are genuinely shared with
`FF16_Strategy`, but the rest is a second implementation:

- `ff16_net_from_components` re-derives the mass cascade inline. `mass_sapwood` is
  `area_sapwood * height * eta_c * pars.rho` in `ff16_strategy.cpp:39` and
  `area_sapwood * height * p.eta_c * p.rho` in the kernel. Six allometric relations, two
  copies, nothing tying them.
- `FF16ProdPars<S>` is a second parameter struct — 18 of `FF16_Pars`' 32 fields, re-declared
  and hand-packed at every call site.
- `ff16_assimilation_deep_crown_replay` is a second assimilation path.
- TF24 has no equivalent, so the pattern served one model and did not propagate.

Under §2.1 the class *is* the templated form, so the composites are absorbed into it and the
header retires. The same rule rules out the other parallel paths named in §3.3.

### 2.3 Two workflows, both already in the SCM

| workflow | SCM entry | environment | gradient meaning |
|---|---|---|---|
| **resident / total** | `run()` | co-moving: the stand re-shades itself | d(emergent metric)/d(trait), full self-feedback |
| **mutant / invasion** | `run_mutant()` | the frozen resident canopy | the selection gradient |

`SCM::run_mutant()` already pins integration to the resident's cached step history, reads the
cached environment, and suppresses the mutant's self-competition through `is_mutant_run`. So
user story 2 is the derivative of a run plant already has, not a new engine.

**Phases 1–3 build the invasion workflow only.** The resident workflow needs the canopy
recomputed live during the replay, which is L3 in §2.4; that is **deferred to Phase 4** and
`stand_gradient` gains its `feedback` argument there. Until then the engine's answer is the
invasion gradient and the API says so.

### 2.4 Four replay levels

Adaptive constructions make parameter-dependent decisions; differentiating the decisions
corrupts the tape. Each is recorded once on a double pass and replayed fixed. There are four,
and they compose:

| level | freezes | owner | phase |
|---|---|---|---|
| **L0** — node schedule | which cohorts exist and when they are introduced | plant | 1 |
| **L1** — ODE step times | the adaptive RKCK step selection (`advance_fixed`) | odelia | 1 |
| **L2** — quadrature abscissae and light-spline knots | adaptive refinement | plant + odelia's interpolant | 2 |
| **L3** — the resident canopy | canopy feedback (frozen for a mutant) | plant | **4** |

L0 and L1 are what the invasion gradient needs, plus L2 once a census integrates over
height. With L0 frozen, introduction times are constants, so introductions widen the state
without injecting a discontinuity.

**L2 has two variants and they are not interchangeable.** For the light spline the knots are
frozen and the values active. For a census integrated over height the integration bound *is*
an active plant height, so the quadrature **nodes move** — that needs the scalar-templated
`QK`, and a frozen-node replay would drop the moving-node sensitivity.

**L3 is where a silent wrong answer lives, and it is the reason it gets its own phase.** On
the resident path the canopy must be recomputed live from the active, re-evolved cohorts on
the recorded knot positions. Replaying the recorded environment *values* there returns the
invasion gradient with the self-shading cross term missing — a plausible number and no error.
Phase 4 carries a positive control that makes the confusion a test.

### 2.5 Memory: the driver walks a double trajectory backwards

Templating makes a whole-run recording possible; at production that recording is ~220 GB. So
the driver records **one cohort's rates per (stage, cohort)** and releases:

```
1. run_scm(refine_schedule = TRUE)   double. resolves L0 and L1. Immutable after.
2. replay in double, storing one state per accepted step   (22.5 MB at production)
3. backwards, per step:
     a  soil adjoint          closed form: bidiagonal, no solve
     b  per cohort: record this cohort's compute_rates at S = active; sweep; release
     c  light-field adjoint   Hermite: 2 knots per read, O(1)
     d  allometry adjoint     closed form
4. reduce the final state through the functional; return doubles
```

Peak is one cohort's rates — kilobytes — flat in run length, in stage count and in the number
of seeded traits. Steps (a), (c), (d) are linear or closed-form maps costing what their
forward evaluation costs. What step (b) records is `Individual::compute_rates` at `S =
active`: the model's own function.

### 2.6 What crosses from odelia into plant

Six names, and no `xad::` spelled anywhere in plant:

| name | from | plant's use |
|---|---|---|
| `implicit_value(y*, F)` | `implicit_node.hpp` | the `ci` root-find, the birth-size solve: hand it the **residual**, not the search |
| `hermite_interpolator<S>` | `hermite_interpolator.hpp` | the light field, value and slope from one construct |
| `compute_jacobian` | `gradient.hpp` | record once, sweep m rows |
| `DifferentiationTargets` | `gradient.hpp` | which parameters/ICs to seed |
| `to_passive` | `ode_util.hpp` | knot positions, quadrature abscissae, ordering keys |
| a forward-derivative helper | new, small | the leaf's local IFT (§2.7) |

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD
transitively. The rule is that no plant author writes `xad::`, and it is a grep:
`grep -r 'xad::' plant/inst plant/src` must be empty.

### 2.7 Forward mode stays plant-local

The leaf's gas-exchange optimum is a local numerical device with one input and one output, so
forward-mode AD plus the IFT is the right tool and `dprofit_droot_collar_psi` already uses it.
odelia accommodates the result through an injected-partials edge rather than absorbing the
method. The only change is the spelling: `src/leaf_model.cpp` names `xad::fwd<double>` and
`xad::derivative` directly, and those become one odelia helper.

---

## 3. Salvage manifest

Each item is *take*, *take with changes*, or *leave*, with the reason.

### 3.1 From plant `develop`

| | verdict |
|---|---|
| `ff16_production_kernel.h` | **retire.** Its elementary functions become methods on `FF16_Strategy<S>`; the composites and `FF16ProdPars` go away because the class is the templated form (§2.2) |
| the three `test-ff16-*-ad.R` witnesses | **take the assertions.** They are the only working gradient tests in either tree; their in-test `sourceCpp` harness becomes unnecessary once plant has a compiled entry point |
| `Species::census<Psi>` (`species.h:64`) and the self-shading integral on it | **take.** Phase 2 templates it on `S`; the reduction shape is unchanged |
| `SCM::run_mutant()`, `is_mutant_run`, the cached resident environment | **take, unchanged.** §2.3: this is workflow 2 |
| `Control()` as the fast default, `SCM::refine_schedule` in C++, `r_ode_times()` | **take.** The resolved schedule is the replay grid and `r_ode_times()` is its single source |

### 3.2 From odelia branch `claude/odelia-ad-tape-reverse-496fuf`

44 commits ahead of the baseline. Take six.

| commit(s) | what | verdict |
|---|---|---|
| `16cff79`, `7aa9c69`, `7a30940`, `0c62bda` | `implicit_node.hpp` — `implicit_value(y*, residual, denom_sign)`, 84 lines, with a `static_assert` that the residual returns `S` exactly | **take.** The caller declares the equation; the baseline's `supplied_derivative` makes the caller compute partials by hand |
| `49f7a7f`, `4c0f3b8` | `hermite_interpolator.hpp` — C1, value and slope per knot, 167 lines | **take.** Report 03's deliverable; two-knot locality is what makes §2.5 step (c) O(1) |
| `baf6eae` | `to_passive`, nested-type-safe | **take** |
| `eb514e9` | `graft_value` | **take.** It makes the expression-template dangling-reference trap unwriteable; keep its `static_assert`s |
| `0139b92` | reject a non-finite step-size decision | **take.** Correct on its own merits |
| `b426ac4` | per-term `Tape` size accessors | **take.** Diagnostics; needed to price a recording |
| `aece41d` | `incomplete_gamma.hpp` — exact Weibull antiderivative with injected partials | **conditional.** Adopt only if it beats the leaf's current pre-integrated spline on a measured forward run |
| `be13d78` | `separable_field.hpp` | **take in Phase 4**, on its own merits as the per-species-η fix (P4.1), not as AD scaffolding |
| `7505c93` | `compute_jvp` + the adjoint dot-product oracle | **leave.** `⟨Jv,u⟩ = ⟨v,Jᵀu⟩` is self-consistency: both directions traverse the same recorded graph, so it is a green check that proves nothing |
| `cc6571c` | interpolator `slope(u, step, direction)` secant read | **leave.** A value and a slope from two constructs agree nowhere except by accident; the Hermite supplies both from one |
| `f9d6ad8`, `ac6a988` | `mass_transport.hpp` — the log-mass chart | **leave.** Report 04 is about doing without it |
| `2a60998` | `preaccumulate` | **leave.** 1.49× and 3.7× on the component; 0.018% on TF24's total |
| `31fb243` | `decide` / recorded value-branch | **leave.** A named type for `if`; the kink manifest is a document |
| `18a56ed`, `28059bd`, `73739d7`, `f169540`, `5c023e2` | the step-local sweep toys | **leave the code, keep the findings.** These are the measurements reports 01–02 rest on |

`supplied_derivative.hpp` is superseded by `implicit_value`; `register_implicit` is already
deleted. The discipline behind `28059bd` applies to everything above: **697 lines went
because nothing but a demo called them**, so every item taken must have a named consumer in
§6 before it lands.

### 3.3 From plant branch `claude/odelia-ad-tape-reverse-496fuf`

| | verdict |
|---|---|
| **the scalar templating** — `Internals_<S>`, `TF24_Strategy_<S>`, the containers deriving `value_type` | **take as the starting diff, re-shaped per §2.1.** Port one model at a time with the reference tests as the bit-identity tripwire. Two shape changes: derive `value_type` from `T` rather than adding a parameter, and collapse the double `pars` plus lifted struct into one `Pars<S>` |
| scalar-templated `CanopyShape` | **take.** It closed a measured `eta` severance in all three models, and it is the shape §2.1 wants: the science templated, the container not |
| the other three severance fixes: `smooth_positive` on FF16's growth/fecundity clamp, IFT-lifted birth size, K93's `k_I` growth channel | **take, one PR each.** Each closed a measured wrong-gradient channel and each carries that channel as its test |
| the three census Ψ (LAI, biomass, basal area) as a codomain-3 functional | **take.** Several Jacobian rows off one recording, measured at +0.38% |
| `scm_gradient.h`'s *entry shape* — resolve the schedule in double, replay it, one recording per output row | **take the shape, rewrite the body** per §2.5 |
| `Species::census<Psi>` templated; the competition trapezium and `QK` templated | **take.** §2.4's L2 moving-node case needs the templated `QK` |
| `field_ptrs()` / `field_names()` from one list | **take the invariant, drop the macro.** Names and pointers must come from one source; with a templated `Pars<S>` the RcppR6 yml already is that source |
| the 28 `*_driver.cpp` + `test-ad-*.R` in-test compiles | **mine for assertions, delete the harness.** With a compiled entry point, a test that compiles C++ tests the toolchain |
| `assemble_leaf_from`, `seam_collar_psi_input`, `seam_collar_uptake_partials`, `soil_consumption_active_` | **leave.** A parallel leaf-assembly path (§2.2). The leaf gets one node with a declared boundary: in (ψ_soil per layer, radiation, traits), out (profit, per-layer uptake) |
| `rebind_from`, `rebind_strategy_fields` | **leave.** §2.1's single templated `pars` removes the need |
| `PLANT_DIFFERENTIABLE` | **leave.** A capability flag where an instantiation suffices |
| `geometric_transport`, the extended mass chart, `log_mass_`, `census_leaf_area` | **leave.** Report 04 exists to remove this |

---

## 4. The document set

**One home per fact, and the home is named before the code is written.**
`docs/audit-2026-07.md` indexes what is archived.

| document | owns |
|---|---|
| `docs/build-plan.md` | this plan: architecture, salvage, tasks, gates |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites |
| `docs/reports/01`–`04`, `06`, `07` | the derivations and measurements the plan rests on. Reference material; not edited to track progress |
| `odelia/AUTODIFF.md` | the System contract, the replay hooks, functionals |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary |
| `plant/agents.md` §13 (new) | how a plant model author makes their science differentiable |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable |

Two co-design rules, enforced per task:

- **A task that changes the differentiable surface changes `plant/agents.md` §13 in the same
  PR.** The section is short by construction: past two pages, the surface is too big.
- **A task that adds a name to §2.6's six justifies it in the PR body.**

`plant/agents.md` §13's outline, so tasks fill it rather than invent it:

1. **Your model is templated on its scalar; `double` is production.** Write the science once.
   If new physiology does not compile at the active scalar, that is the design working.
2. **Positions are `double`; values carry `S`.** Knots, quadrature abscissae and orderings are
   decided on passive values — `to_passive` is how you say so. A knot *count* that depends on
   an active value makes the recorded computation state-dependent.
3. **An inner solve is declared by its residual**, through `implicit_value`. Never
   differentiate the iteration that found the root: `golden_section_max`'s argmax is affine in
   its bracket and independent of the objective's values, so taping the search returns the
   derivative of the bracket.
4. **Never define a rate as a numerical derivative of an active quantity.**
5. **A clamp, floor, `min`/`max` or `if` on a computed value is a derivative decision.**
   Record it in the kink manifest with the incidence that justifies it.
6. **Never give a deduced return type to anything returning an active value.** XAD operators
   return expression templates holding references to their operands; `graft_value` exists so
   the idiom is not hand-written.

---

## 5. Phase 0 — prerequisites (forward model, no AD)

The subject of [`tf24-correctness.md`](tf24-correctness.md) and report 07. Here because the
design's bit-identity acceptance test cannot pass until P0.1 lands: report 01 §12 asks for
"re-run one cohort's rates from its boundary and compare bit for bit", and on develop that
fails on 33.78% of production records for reasons unrelated to AD.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort inheriting the previous cohort's deep-layer uptake | 1 line + baselines | a seedling's deep layers read 0 on a leaf that solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake regardless of what ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip property test | 1 line + test | round trip to 1e-12 for θ in (θ_r, θ_sat] |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | **the kink manifest** — every clamp, floor, `min`/`max` and branch on TF24's carbon and water paths, classified, each with a measured incidence | doc + probes | every row has a number. Report 06 §7/§9b, report 07 and §8 supply most of it |
| **P0.6** | the two ecology decisions: the double-counted leaf respiration, and `establishment_probability`'s hard gate | owner's call | a recorded decision either way, with a `scientific_version` bump |
| **P0.7** | fix `q(z, height)`'s division by `z` | small | `q(0, h)` is finite for every `h` |

**P0.7, stated concretely.** `q(z, h) = 2η(1−u^η)u^η / z` divides by `z`, so `q(0, h)` is
`0/0` — **NaN for every height, not only at `h = 0`** (measured). The light field's lowest
knot is exactly `z = 0` (`construct_spline` sets `lower_bound = 0.0`), so the first consumer
to ask the field for a slope at the ground meets it. Writing `q` over `u^(η−1)/h` rather than
`u^η/z` — equal for `z > 0` — is finite there and removes a division from the hot path; the
`u → 0` limit is 0 for every `η > 1` and `1/h` at `η = 1`. Separately, `d/dη` of `0^η` is
`0^η log 0` = NaN, which bites at the same ground knot once `η` is a differentiation target.
A zero-**height cohort** is not the concern: `height_0 = 0.344195 m` (measured), so `h = 0`
is unreachable through introduction.

P0.5 pays for itself twice: it is the deliverable specified in several places and produced in
none, and it is the input Phase 3 needs — you cannot choose which switches to mollify before
you know which fire. **P0.6 gates Phase 3, not Phase 1.**

---

## 6. Phases 1–5

Each task is one PR with a gate that is a number or a passing test. Phases are ordered by
**attributability of failure**.

### Phase 1 — the engine, on K93

K93 has no leaf, no soil and closed-form rates, so a failure is attributable to the engine.
Its gradient is the only one with a reference today.

| | task | gate |
|---|---|---|
| **P1.1** | Land §3.2's six odelia items on `master` from `854a8e18`, each with a plant-side consumer named in the PR body | odelia suite green; **`ode_util.hpp` still includes no XAD** (plant includes it everywhere) |
| **P1.2** | `K93_Pars<S>`, `K93_Strategy<S>`; containers derive `value_type` from `T` | `test-strategy-k93.R` **bit-identical**; forward benchmark within the accepted band |
| **P1.3** | Register traits by name from the one source the yml already provides | names and pointers cannot disagree — a test asserting size and order |
| **P1.4** | Trajectory storage: replay the resolved schedule in double, one state per accepted step; restore the three birth stamps (`pr_patch_survival_at_birth` divides the fecundity rate and is not in `ode_state`) | replayed final state bit-identical to the forward run; **`set_birth_state` called by a test** — today it is called by none |
| **P1.5** | The reverse driver (§2.5). Per (step, cohort) record `Individual::compute_rates` at `S = active`, sweep, release; soil and allometry adjoints closed-form | K93 census gradient matches a re-run FD to the FD's noise floor; peak tape reported and **flat** in run length and in target count |
| **P1.6** | Trait adjoints accumulate across cohorts | the discriminating test: per-cohort inputs give **41–51%** of the answer, right sign, nothing thrown. Assert the correct value, not finiteness |
| **P1.7** | Cash-Karp stage traversal — a general `sum over j < i`, accepted steps only | three-way agreement (cohort-granular, whole-run tape, FD) at a lifetime where the whole-run tape fits |
| **P1.8** | `plant/agents.md` §13 first draft; the R entry `stand_gradient()`, invasion workflow | a developer reads §13 and adds a metric |

**Gate: K93 census + R0 FD-verified at production lifetime, under 2 GB peak, forward model
not regressed, and §13 exists.**

### Phase 2 — FF16

| | task | gate |
|---|---|---|
| **P2.1** | `FF16_Pars<S>`, `FF16_Strategy<S>`; absorb `ff16_production_kernel.h`'s composites into the class and delete `FF16ProdPars` | `test-strategy-ff16.R` and the FF16 reference comparison bit-identical |
| **P2.2** | The four severance fixes (§3.3), one PR each | each has the channel it repairs as its test: `eta`, `a_l1`/`a_l2`, `omega`/`height_0`, `k_I` |
| **P2.3** | Template `Species::census<Psi>`, the competition trapezium and `QK` on `S` — L2's moving-node case | a census whose integration bound is an active height carries the moving-node term, verified against FD |
| **P2.4** | `Patch::compute_competition_slope(z)` — exact `dA/dz`, fused so `pow(z/H, eta)` is computed once | agrees with a tight central difference across `eta` in {1,2,4,8,10,12} **and** a general non-integer `eta` |
| **P2.5** | Hold a `hermite_interpolator` in `ResourceSpline` beside the fitted one; add `get_value_and_slope_at_height` | O(h⁴) on value, O(h³) on slope, on a knot set dumped from a real production step |
| **P2.6** | Attribute `rescale_spline`'s unexplained 91% (17.6 µs of 193.2 accounted for), then time a Hermite build against it | the +0.33%…+5.3% bracket collapses to one number, inside the forward budget. Worth doing for develop alone: 175 µs/build is 3.5 s of a 59.5 s run |
| **P2.7** | Switch the read; wire the slope into the crown integral's height channel; tighten FF16's own gradient gate | FF16 census + R0 FD-verified at production lifetime. The gate currently passes at 1e-2 where the truth is ~1e-6, so a 100× regression would pass green |

### Phase 3 — TF24

| | task | gate |
|---|---|---|
| **P3.1** | `TF24_Pars<S>`, `TF24_Environment<S>`, `TF24_Strategy<S>`, including the storage block (`P_pos`, the reserve gate, the outflow gate) | `test-strategy-tf24.R` bit-identical |
| **P3.2** | The leaf as one node with a declared boundary: in (ψ_soil per layer, radiation, traits), out (profit, per-layer uptake). `ci` via `implicit_value`; the interior argmax via report 06 §6.2; the bound branch via the bound's own derivative; a selector on `\|∂Π/∂p\|` | both regimes FD-verified; the selector's incidence in P0.5's manifest |
| **P3.3** | `∇(∂Π/∂p)` — one gradient of one closed-form expression, including the `ci` root-find's own IFT term | `d(consumption)/dψ` within FD noise, against the **47.6–53.2%** error the frozen-argmax form gives today |
| **P3.4** | Replace `xad::fwd` in `src/leaf_model.cpp` with the odelia helper (§2.7) | `grep -r 'xad::' plant/inst plant/src` is empty |
| **P3.5** | TF24 census + R0 at `max_patch_lifetime = 105.32`, invasion workflow | FD-verified against the tight-inner-tolerance reference on the identical resolved schedule, under 2 GB peak |

`Π_pp` is measured (§8), so P3.2's shape is settled: two regimes, a selector, and a
well-conditioned divide in the interior one.

### Phase 4 — the resident workflow, and the forward-model debts it needs

| | task | gate |
|---|---|---|
| **P4.1** | L3: recompute the canopy live from the active cohorts on the recorded knot positions during the replay | the resident and invasion gradients differ, and the resident one carries the self-shading cross term. **Positive control: replaying frozen values on the resident path must reproduce the invasion gradient** — the silent failure becomes a test |
| **P4.2** | `stand_gradient(..., feedback =)` | both workflows reachable from R, and the default is stated |
| **P4.3** | Per-species η: group sources by η, rank 3·n_η, degenerating to today's rank 3 when η is shared (`separable_field.hpp`) | the two-species probe goes exact where it now computes **7.98e+14** against 0.118; the descending-height tie-break stays deterministic with differing η |
| **P4.4** | Retarget node-schedule refinement at the coupling field | freezing the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84%. The current criterion flags cohorts by contribution to reproduction, which is already converged |

P4.3 is a prerequisite for the resident workflow being *usable*: stories 1 and 2 vary traits
across species by definition, and the light field is wrong for species of differing η — the
forward value too, since η is read from `species[0]` only.

### Phase 5 — calibration, decision first

`least_squares` reads intermediate trajectory states as **active** values
(`get_history_step(idx)` then `ode_state` into `value_type`). A plain-`double` stored
trajectory breaks it silently: the value stays right and the derivative through the
observations is lost. Two candidates, and it is a DX question:

- **(a)** the functional declares which steps it reads and contributes a per-step adjoint
  seed. One new concept for everyone.
- **(b)** calibration keeps a second, denser stored trajectory. No new concept, more memory.

Write the decision down before Phase 5 opens.

---

## 7. What we are deliberately not building

- **No third template parameter, no `SCMSystem`, no `StrategyConcept`, no second `Patch`.**
- **No parallel path for anything** — no `assemble_leaf_from`, no `*_active_` shadow fields,
  no second parameter struct, no second assimilation path (§2.2).
- **No capability flags or SFINAE detection structs.** A concept and `if constexpr` where a
  compile-time choice is genuinely needed.
- **No `decide()` type.** The kink manifest is a document.
- **No JVP oracle.** Self-consistency is not correctness.
- **No component-level tape leanness work.** 0.018% of TF24's total against a required factor
  of 10²–10³.
- **No mass-chart extension.** Report 04.
- **No disturbance gradients, no Hessians.** Out of scope.
- **No smoothing without a measured incidence and a sized scale.** develop has the precedent
  (`P_pos`) and the method (`storage_prod_eps`, measured well-sized).

---

## 8. `Π_pp`, and the two regimes of the operating point

`scripts/curvature_probe.R`, against a develop build: a central difference of develop's
analytic `dprofit_droot_collar_psi` about the solved operating point, at
`GSS_tol_abs = 1e-10` so the number is the geometry, each point at three step sizes. Swept
over the **whole feasible domain of the argmax** — `psi_soil` from the default driver's
0.015–0.17 MPa down to the stem's `psi_crit = 7.085`, four heights, five heterogeneous
profiles of the kind a drydown makes — so it brackets what any driver can reach.

**`Π_pp` is negative at 52 of 52 states**, `|Π_pp|` from **0.1723 to 15.61** (median 4.2).
The failure mode of the divide in report 06 §6.2 is `Π_pp → 0`; nothing in the domain comes
near it, and the worst amplification of a flux adjoint is **5.8×**. So the interior solve is
one divide with no fallback and no second-order safeguard.

**The operating point has two regimes:**

| regime | count | treatment |
|---|---|---|
| stationary interior maximum (`\|∂Π/∂p\|` at the solver floor) | **37 / 52** | report 06 §6.2 as written |
| **pinned at a bound** (`\|∂Π/∂p\|` = 0.054 … 2.12 at tolerance `1e-10`) | **15 / 52** | `p*` *is* the bound, so `dp*/d(·)` is the bound's derivative — analytic |

Every pinned state is at `psi_soil ≥ 1.5 MPa` **and** `height ≥ 2 m`: dry and tall. None is
inside the default driver's `psi_soil` range, which is why report 06's production census finds
zero corner incidence; the committed stress banks reach 1.5+ MPa, so the regime is live
there. The selector is a comparison on `|∂Π/∂p|` available where the search returns, and it
is a discrete branch on the gradient path, so P0.5's manifest carries it with its incidence.

**One thing to measure next.** With `Π_pp ≈ −4`, displacing `p*` by `1e-4` should move
`∂Π/∂p` by about `4e-4`; report 06 §9 measures 11–23 at `GSS_tol_abs = 1e-3`. So either the
search error at production tolerance is much larger than `1e-4`, or those states are pinned.
That is a question about `golden_section_max` and it does not affect P3.2's shape.

---

## 9. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| a channel exists that templating cannot reach | a derivative obtainable only through a parallel path, i.e. §2.2's carve-out forced | P1.5 on K93, the cheapest possible discovery |
| the forward model regresses under templating | benchmark outside the accepted band, or reference numbers move | P1.2 / P2.1 / P3.1, each gated on bit-identity. The branch measured develop 49.57 s against branch 50.31 s, so this is achievable |
| L3 confusion returns the invasion gradient on the resident path | a plausible number with the self-shading cross term missing, no error | P4.1's positive control makes it a test |
| trait adjoints do not accumulate | a fixed fraction of the FD with the correct sign, nothing thrown | P1.6 |
| the stage traversal loses a term on Cash-Karp's denser tableau | the reference failure mode is a **19%** error, correct sign, silent | P1.7 |
| the leaf node's boundary is wider than (ψ_soil, radiation, traits) | P3.2 grows an output nobody declared | P3.2; P0.5's manifest should predict it |
| a value-reproduction check is mistaken for a gradient check | a **0.2%** value gap has produced a **sign-flipped** gradient in a nonlinearly self-coupled system | every gate: **the gate is always AD against a re-run FD** |

---

## 10. Review gates on this plan

Three questions before Phase 1 opens. All architecture, none code.

1. **Does the scalar belong on the types that own the parameters, with `<T,E>` unchanged?**
   The cheapest test is P1.2: if `K93_Pars<S>` plus derived `value_type` compiles and
   `test-strategy-k93.R` stays bit-identical, the shape holds for all three models.
2. **Is the leaf's boundary (ψ_soil, radiation, traits) → (profit, per-layer uptake)?**
   Report 06 §5 says so. A sixth quantity changes P3.2's shape.
3. **Do P0.6's two ecology decisions bump `scientific_version`?** They change every simulated
   number, so they want the owner before anything is FD-verified against them.

**Order: (1) then (2); (3) runs in parallel because it gates nothing before Phase 3.**
