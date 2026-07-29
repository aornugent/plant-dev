# Build plan: exact gradients of plant's emergent outputs

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
Both AD feature branches are treated as **quarries, not baselines** — §3 says what to
take from each and what to leave.

**Status: plan under review. Nothing here is built. Do not start Phase 1 until §8's
review gates are closed.**

---

## 1. What we are building

Exact trait and parameter gradients of the SCM's **emergent** outputs — the three
census metrics (LAI, biomass, basal area) and R0/offspring — for K93, FF16 and TF24,
at production lifetime (`max_patch_lifetime = 105.32`), verifiable against finite
differences, **adding no engine vocabulary per model** and without regressing the
forward model.

The objective is developer experience. A gradient engine nobody can extend is a
failed gradient engine, so the acceptance test is not only a number but a count: a
plant developer adding a new emergent metric writes **one scalar-templated kernel and
registers a name**, touching no tape code and no odelia code.

Five things a user should be able to do, in R, with doubles in and doubles out:

| | who | call |
|---|---|---|
| 1 | forest ecologist | `stand_gradient(scm, metrics, traits)` — trait sensitivity of emergent LAI/biomass/basal area, with resident self-shading feedback |
| 2 | evolutionary ecologist | `offspring_production_gradient(...)` — a selection gradient, for locating singular strategies |
| 3 | modeller | `value_and_gradient(p)` in an L-BFGS loop, **both from one recording** |
| 4 | plant developer | add a metric with one kernel + a registered name |
| 5 | maintainer | compare AD against a re-run finite difference in plain R, same shape |

(1) and (2) are the primary workflows. (3) is the one that stresses the design hardest
and is deferred to Phase 5 with its own decision, because it wants intermediate
trajectory states as active values.

---

## 2. The architecture, and the one it replaces

### 2.1 The decision

> **The differentiable surface is a set of scalar-templated free functions. The class
> hierarchy stays `double`.**

`Internals`, `Individual`, `Node`, `Species`, `Patch`, `SCM` and every `*_Strategy`
class remain exactly as they are today: plain `double`, one instantiation, no
`_<S>` suffix, no `rebind_from`, no `value_type` template parameter. The arithmetic
that needs a derivative moves into free functions templated on the scalar, in a
per-model kernel header, and the class methods **delegate** to them.

**develop has already drawn this line and it works.** `inst/include/plant/models/
ff16_production_kernel.h` holds `ff16_area_leaf`, `ff16_respiration`, `ff16_turnover`,
`ff16_net_production_A`, `ff16_net_from_components` and a deep-crown replay form.
`FF16_Strategy`'s double methods call them. Its own comment states the rule we are
adopting:

> They are the SINGLE SOURCE OF TRUTH: FF16_Strategy's double methods delegate to them
> (so the existing FF16 test suite validates faithfulness), and the AD calibration path
> instantiates them with an active scalar.

Three tests on develop already witness gradients through that header
(`test-ff16-ad-kernel.R`, `test-ff16-deep-crown-ad.R`,
`test-ff16-resident-coupling-ad.R`), each compiling a throwaway `Rcpp::sourceCpp`
that links odelia's tape. **Half a milestone landed and its consumer never did.** This
plan builds the consumer.

### 2.2 Why not template the classes

The plant AD branch took the other fork: template `Internals_<S>`, `TF24_Strategy_<S>`,
`Individual<T,E>` on the scalar throughout. Measured against develop that is
**90 files, +6 876 / −4 177**, of which exactly **one** is a new header
(`scm_gradient.h`, 165 lines) and 28 are tests. Everything else is the same code,
re-typed. Three costs, in order of how much they matter:

1. **Every model author now sees the scalar.** `state_size()` is static, `Internals` is
   templated, `set_ode_state` is iterator-templated over an active type, and a
   deduced return type anywhere in the chain is a segfault far from its cause (this
   is real: it cost a session, and it is why `odelia::util::graft_value` exists). That
   is engine vocabulary per model, which §1 forbids.
2. **The invasive diff is unreviewable and unsalvageable.** The reports record several
   conclusions built on branch-only constructs that do not exist on develop; the
   present session began by discovering it had measured the wrong tree.
3. **It buys nothing the free functions do not.** What the reverse pass needs to record
   is *arithmetic*. `Individual::compute_rates` is arithmetic wrapped in plumbing —
   cached integer aux indices, buffer management, rate slots. None of the plumbing has
   a derivative. Recording it is recording the wrapper to reach the contents.

The free-function fork also collapses the risk report 01 §5 spends its length on.
A free function has no shared mutable state, so "is one cohort's rate computation a
pure function of its boundary?" stops being a property held by discipline and becomes
a property of the signature. (One exception survives — `Leaf` — which is why §4's
prerequisites exist.)

### 2.3 The shape of a gradient

```
1.  run_scm(refine_schedule = TRUE)          double. discovers the L0 node schedule
                                              and the L1 ODE grid. Immutable after.
2.  replay in double, storing the trajectory  one state vector per accepted step
                                              (22.5 MB at production)
3.  walk the trajectory backwards, per step:
      a  soil adjoint                         closed form: bidiagonal, no solve
      b  per cohort: record ONE kernel chain at the active scalar; sweep; release
             in:  own state, light value+slope at the crown abscissae,
                  soil potential per layer, seeded traits
             out: rates, per-layer uptake
      c  light-field adjoint                  Hermite: 2 knots per read, O(1)
      d  allometry adjoint                    closed form
4.  reduce the final state through the functional; return doubles
```

Peak memory is one cohort's kernel chain — kilobytes — against ~220 GB for a whole-run
tape at production. That is report 01's result and it is the reason the design exists.
Steps (a), (c), (d) are linear or closed-form maps costing what their forward
evaluation costs. Step (b) is the only recording.

### 2.4 What crosses from odelia into plant

Five names, and no `xad::` anywhere in plant:

| name | from | what plant does with it |
|---|---|---|
| `odelia::implicit_value(y*, F)` | `implicit_node.hpp` | the `ci` root-find, the birth-size solve: hand it the **residual**, not the search |
| `odelia::interpolator::hermite_interpolator<S>` | `hermite_interpolator.hpp` | the light field, carrying value and slope |
| `odelia::ode::compute_jacobian` | `gradient.hpp` | the driver: record once, sweep m rows |
| `odelia::ode::DifferentiationTargets` | `gradient.hpp` | which parameters/ICs to seed |
| `odelia::util::to_passive` | `ode_util.hpp` | knot positions, quadrature abscissae, ordering keys |

`odelia::ode::Solver` already carries a `xad::Tape<double>` member, so plant already
includes XAD transitively and will continue to. **"Don't leak XAD" means no plant
author writes `xad::`, not that the header is absent.** There is one violation on
develop today — `src/leaf_model.cpp` uses `xad::fwd<double>` and `xad::derivative`
directly for TF24f's profit gradient — and Phase 3 removes it in favour of a
one-line odelia helper. That is the standing test of the rule: `grep -r 'xad::'
plant/inst plant/src` returns nothing.

---

## 3. Salvage manifest

Each item is *take*, *take with changes*, or *leave*, with the reason. Nothing is
adopted because it exists.

### 3.1 From plant `develop` — the baseline, already load-bearing

| | verdict |
|---|---|
| `ff16_production_kernel.h` and FF16's delegation | **the pattern.** Extend it; do not replace it |
| the three `test-ff16-*-ad.R` witnesses | **take.** They are the only working gradient tests in either tree. Their `sourceCpp` harness becomes unnecessary once plant has a compiled entry point; keep the assertions |
| `Species::census<Psi>` (species.h:64) | **already on develop.** The mass-weighted reduction and the self-shading integral built on it. Phase 2 templates `Psi`'s arithmetic, not the reduction |
| `Control()` as the fast default, `SCM::refine_schedule` in C++ | **take.** The resolved schedule is the replay grid; `r_ode_times()` is its single source |

### 3.2 From odelia branch `claude/odelia-ad-tape-reverse-496fuf`

44 commits ahead of the baseline. Take five, leave the rest.

| commit(s) | what | verdict |
|---|---|---|
| `16cff79`, `7aa9c69`, `7a30940`, `0c62bda` | `implicit_node.hpp` — `implicit_value(y*, residual, denom_sign)`, 84 lines, with a `static_assert` that the residual returns `S` exactly | **take.** Strictly better than the baseline's `supplied_derivative`, which makes the caller compute partials by hand. Report 01 §10 rule 5 is exactly this: expose the residual, not the search |
| `49f7a7f`, `4c0f3b8` | `hermite_interpolator.hpp` — C1 interpolant carrying value and slope, 167 lines | **take.** Report 03's deliverable. Two-knot locality is what makes step (c) O(1) |
| `aece41d` | `incomplete_gamma.hpp` — exact Weibull antiderivative with injected partials | **take with changes.** The leaf's vulnerability integrals are this shape. Verify it is faster than the current pre-integrated spline before adopting; if not, leave it |
| `baf6eae` | `util::to_passive`, nested-type-safe | **take** |
| `eb514e9` | `util::graft_value` | **take.** It exists to make the expression-template dangling-reference trap unwriteable. Keep the `static_assert`s |
| `0139b92` | reject a non-finite step-size decision | **take.** Unrelated to AD, correct on its own |
| `b426ac4` | per-term `Tape` size accessors | **take.** Diagnostics only; needed to price a recording |
| `7505c93` | `compute_jvp` + the "adjoint dot-product oracle" | **leave.** `<Jv,u> = <v,Jᵀu>` is self-consistency, not correctness — both directions traverse the same recorded graph. Three independent sources in the corpus say so. Keeping it invites a green check that proves nothing |
| `cc6571c` | interpolator `slope(u, step, direction)` secant read | **leave.** Superseded by the Hermite. A value and a slope from two constructs agree nowhere except by accident |
| `be13d78` | `separable_field.hpp` | **leave for now.** The rank-3 factorisation is real and the per-species-η generalisation (rank 3·n_η) is a known requirement, but it is a *forward-model* fix to a *forward-model* defect. Phase 4, on its own merits, not as AD scaffolding |
| `f9d6ad8`, `ac6a988` | `mass_transport.hpp` — the log-mass chart | **leave.** Report 04 is about doing without the mass chart. Do not extend it |
| `2a60998` | `preaccumulate` | **leave.** Measured at 1.49× and 3.7× on the component and **0.018%** on TF24's total. Component leanness is not a route |
| `31fb243` | `decide` / recorded value-branch | **leave.** A named object for `if`. Report 01 §10 rule 7 wants switches *recorded in a manifest*, which is a document, not a type |
| `18a56ed`, `28059bd`, `73739d7`, `f169540`, `5c023e2` | the step-local sweep toys and their refutations | **leave the code, keep the findings.** These are the measurements reports 01 and 02 are built on. Cite them; do not ship them |

Also on the branch and deliberately not listed: `supplied_derivative.hpp` (superseded by
`implicit_value`), `register_implicit` (already deleted, zero production callers), and
the four primitives removed in `28059bd` for having no consumer but their own demo.
That deletion is the standing discipline: **697 lines went because nothing but a demo
called them.** Every item taken above must have a named consumer in §5 before it lands.

### 3.3 From plant branch `claude/odelia-ad-tape-reverse-496fuf`

| | verdict |
|---|---|
| the four severance fixes (`a1`–`a4`): scalar-templated `CanopyShape`, `smooth_positive` on FF16's growth/fecundity clamp, IFT-lifted birth size, K93's `k_I` growth channel | **take, one PR each, ported to the free-function form.** Each closed a measured wrong-gradient channel. `CanopyShape` templated on `S` is the model of what this plan wants: the science templated, the class not |
| the three census Ψ (LAI, biomass, basal area) as a codomain-3 functional | **take.** Several Jacobian rows off one recording is measured and is the point |
| `scm_gradient.h`'s *entry shape* — resolve the schedule in double, replay it, one recording per output row | **take the shape, rewrite the body.** It is correct in structure and is the thing that runs out of memory |
| `TF24_AD_FIELDS` / `field_ptrs()` / `field_names()` macro list | **take the invariant, not the macro.** Names and pointers must come from one source so they cannot disagree in membership or order. Whether that source is a macro or the RcppR6 yml is a Phase 1 task decision |
| `geometric_transport`, the extended mass chart, `log_mass_` | **leave.** Report 04 exists to remove this |
| `assemble_leaf_from`, `seam_collar_psi_input`, `seam_collar_uptake_partials`, `soil_consumption_active_` | **leave.** A parallel leaf-assembly path beside the real one. The leaf's boundary is (ψ_soil, radiation, traits) → (profit, per-layer uptake); implement *that*, once |
| `PLANT_DIFFERENTIABLE`, `census_leaf_area`, the `Internals_<S>` templating | **leave.** §2.2 |
| the 28 `*_driver.cpp` + `test-ad-*.R` in-test compiles | **mine for assertions, delete the harness.** Once plant has a compiled entry point, a test that compiles C++ is a test of the toolchain |

---

## 4. The document set — one home per fact

The corpus failed the same way twice: a claim outlived its fix because two documents
could both hold it. So the rule is **one home per fact, and the home is named before
the code is written.** `docs/audit-2026-07.md` records what was archived and why.

| document | owns | lives |
|---|---|---|
| `docs/build-plan.md` | this plan: tasks, order, gates | plant-dev, this file |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites | plant-dev |
| `docs/reports/01`–`04`, `06`, `07` | the *derivations and measurements* the plan rests on. Reference material; never edited to track status | plant-dev |
| `odelia/AUTODIFF.md` | the System contract, the two axes, the replay hooks, functionals | odelia. **Already good** — extend, do not rewrite |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary | odelia |
| `plant/agents.md` §13 (new) | **how a plant model author makes their science differentiable.** The kernel-header pattern, the five odelia names, the five rules | plant |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable | plant |

Two co-design rules, enforced per task in §5:

- **A task that changes the differentiable surface changes `plant/agents.md` §13 in the
  same PR.** Not a follow-up. The section is short by construction: if it grows past
  two pages the surface is too big.
- **A task that adds a name to §2.4's table of five justifies the addition in the PR
  body.** Five is the budget. Six needs an argument.

`plant/agents.md` §13's outline, written now so the tasks can fill it rather than
invent it:

1. Your science goes in `models/<model>_kernel.h` as free functions templated on `S`.
   Your `Strategy` methods call them. The existing double test suite is what proves
   the delegation faithful.
2. Positions are `double`; values carry `S`. Knots, quadrature abscissae and orderings
   are decided on passive values — `to_passive` is how you say so.
3. An inner solve is declared by its **residual**, through `implicit_value`. Never
   differentiate the iteration that found the root.
4. Never define a rate as a numerical derivative of an active quantity.
5. A clamp, a floor, a `min`/`max` or an `if` on a computed value is a derivative
   decision. Record it in the kink manifest with the incidence that justifies it.

---

## 5. The tasks

Each task is one PR, has a gate that is a number or a passing test, and names the
document it changes. Phases are ordered by *attributability of failure*, not by
enthusiasm.

### Phase 0 — prerequisites (forward model; no AD)

These are the subject of [`tf24-correctness.md`](tf24-correctness.md) and of report 07.
They are in this plan because **the design's own acceptance test cannot pass until
P0.1 lands**: report 01 §12's leading falsifier is "re-run one cohort's rates from its
boundary and compare bit for bit", and on develop that fails on 33.78% of production
records for a reason that has nothing to do with AD.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort inheriting the previous cohort's deep-layer uptake | 1 line + baselines | the seedling's deep layers are 0 on a leaf that solved a tree first; TF24 baselines re-blessed with the shift recorded |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake regardless of what ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip property test | 1 line + test | `soil_moist_from_psi(psi_from_soil_moist(θ)) == θ` to 1e-12 for θ in (θ_r, θ_sat) |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | kink manifest for TF24 — every clamp, floor, `min`/`max` and branch on the carbon and water paths, with its measured incidence and a recorded decision | doc + probes | the manifest exists and every row has an incidence number. Report 07 and report 06 §7 supply most of it |
| **P0.6** | the two ecology decisions: the double-counted leaf respiration, and `establishment_probability`'s hard gate | **owner's call, not ours** | a recorded decision, either way |

P0.5 is the one that pays for itself twice. It is `v3-requirements`' §20c S3 — specified
in four places, produced in none — and it is also the input Phase 3 needs: you cannot
choose which switches to mollify before you know which ones fire.

**P0.6 gates Phase 3, not Phase 1.** The engine does not care what the numbers are.

### Phase 1 — the engine, on K93

K93 first because it has no leaf, no soil and closed-form rates, so a failure is
attributable to the engine. Its gradient is the only one with a reference today.

| | task | gate |
|---|---|---|
| **P1.1** | Land the five odelia items from §3.2 on odelia `master` from `854a8e18`, each with a plant-side consumer named in the PR body. `implicit_value`, `hermite_interpolator`, `to_passive`, `graft_value`, the non-finite step guard | odelia suite green; **`ode_util.hpp` still includes no XAD** (plant includes it everywhere) |
| **P1.2** | `k93_kernel.h`: K93's rates as free functions on `S`; `K93_Strategy` delegates | existing `test-strategy-k93.R` bit-identical |
| **P1.3** | The parameter-handle list: one source for names and pointers, per model | names and pointers cannot disagree — a test that asserts `size()` and order agree |
| **P1.4** | Trajectory storage: replay the resolved schedule in double, keep one state per accepted step. Restore the three birth stamps (`pr_patch_survival_at_birth` divides the fecundity rate and is not in `ode_state`) | replayed final state bit-identical to the forward run; **`set_birth_state` called by a test** — today it is called by none |
| **P1.5** | The reverse driver: walk the trajectory backwards; per (step, cohort) record the kernel chain, sweep, release. Soil and allometry adjoints closed-form | K93 census gradient matches a re-run FD to the FD's own noise floor; peak tape reported and **flat** in run length and in target count |
| **P1.6** | Trait adjoints accumulate across cohorts | the discriminating test: per-cohort inputs give **41–51%** of the answer with the right sign and nothing thrown. Assert against the correct value, not against finiteness |
| **P1.7** | The Cash-Karp stage traversal — a general `sum over j < i`, not RK4's three special cases; accepted steps only | three-way agreement: cohort-granular, whole-run tape, FD, at a lifetime small enough for the whole-run tape to fit |
| **P1.8** | `plant/agents.md` §13, first draft, and the R entry point `stand_gradient()` | a developer can read §13 and add a metric |

**Gate for Phase 1: K93 census + R0 gradients FD-verified at production lifetime, under
2 GB peak, and §13 exists.** Nothing proceeds until this is a number.

### Phase 2 — FF16

Adds the crown integral and the light field's self-shading feedback. Its coupled
gradient is already exact to the FD noise floor on the branch, so a regression is
visible.

| | task | gate |
|---|---|---|
| **P2.1** | Port the four severance fixes (§3.3) as separate PRs | each has the channel it repairs as its test: `eta`, `a_l1`/`a_l2`, `omega`/`height_0`, `k_I` |
| **P2.2** | `Patch::compute_competition_slope(z)` — the exact `dA/dz`, fused with `compute_competition` so `pow(z/H, eta)` is computed once. Guard `z = 0` (`q(0,0)` is `0/0`, NaN in plain `double`, and the field's lowest knot is exactly 0) | agrees with a tight central difference of `compute_competition` across `eta` in {1,2,4,8,10,12} **and** a general non-integer `eta` |
| **P2.3** | Hold a `hermite_interpolator` inside `ResourceSpline` beside the fitted one; add `get_value_and_slope_at_height` | O(h⁴) on value and O(h³) on slope at production knot density, on a knot set dumped from a real step |
| **P2.4** | Attribute `rescale_spline`'s unexplained 91% (17.6 µs of 193.2 accounted for), then time a Hermite build against it on one production run | the +0.33%…+5.3% bracket collapses to one number, and it is inside the forward-performance budget. **Worth doing for develop alone: 175 µs/build is 3.5 s of a 59.5 s run** |
| **P2.5** | Switch the read; wire the slope into the crown integral's height channel | FF16 census + R0 FD-verified at production lifetime. Baselines re-blessed |
| **P2.6** | Tighten FF16's own gradient gate | it currently passes at 1e-2 where the truth is ~1e-6: **a 100× regression would pass green** |

### Phase 3 — TF24

| | task | gate |
|---|---|---|
| **P3.1** | `tf24_kernel.h`: geometry, mass cascade, respiration/turnover/net, the storage block (`P_pos`, the reserve gate `G`, the outflow gate), the allometric rate chain. `TF24_Strategy` delegates | `test-strategy-tf24.R` bit-identical |
| **P3.2** | The leaf as **one node** with a declared boundary: in (ψ_soil per layer, radiation, traits), out (profit, per-layer uptake). The `ci` root-find via `implicit_value`; the argmax via report 06 §6.2 | see below |
| **P3.3** | Measure `Π_pp` directly across the production envelope | it is the denominator of the whole argmax channel and is currently `≈ −1.1×10⁵` inferred from a ratio of two other measurements. **If it is small anywhere reachable, P3.2 needs a bracketed fallback and §6.2 is not a one-line solve** |
| **P3.4** | Build `∇(∂Π/∂p)` — one gradient of one closed-form expression, including the `ci` root-find's own IFT term. The single genuinely new piece of code in the plan | `d(consumption)/dψ` within FD noise, against the **47.6–53.2%** error the frozen-argmax form gives today |
| **P3.5** | Remove `xad::` from `src/leaf_model.cpp`: replace `xad::fwd<double>` with an odelia one-liner | `grep -r 'xad::' plant/inst plant/src` is empty |
| **P3.6** | TF24 census + R0 at `max_patch_lifetime = 105.32` | FD-verified against the tight-inner-tolerance reference on the identical resolved schedule, under 2 GB peak. **This is the deliverable** |

P3.2's ordering matters and is the one place the reports genuinely disagree with each
other's ancestors: report 06 §6 derives the reverse pass from the **envelope theorem at
a stationary interior maximum**, and that is the measured production regime
(`|∂Π/∂p| ~ 1e-5…1e-7` at tight tolerance; zero corner incidence in 10 153 records;
minimum margin 27× `GSS_tol_abs`). An archived note claims the opposite from a
degenerate single-layer probe. **P3.3 is what settles it for good** — build nothing in
P3.2 until it returns a number.

### Phase 4 — forward-model debts that block the user stories

Not AD work, but stories (1) and (2) are multi-species by definition and the light
field is wrong for species of differing η — **the forward value too, latently**, since
η is read from `species[0]` only.

| | task | gate |
|---|---|---|
| **P4.1** | Per-species η in the light field: group sources by η, rank 3·n_η. Degenerates to today's rank 3 when η is shared | the two-species probe goes exact where it now computes **7.98e+14** against 0.118; the descending-height tie-break stays deterministic with differing η |
| **P4.2** | Retarget the node-schedule refinement criterion at the coupling field | freezing the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84%. The current criterion flags cohorts by contribution to reproduction, which is already converged |

### Phase 5 — calibration, with a decision first

Story (3) reads intermediate trajectory states as **active** values
(`odelia/gradient.hpp`'s `least_squares` does exactly this: `get_history_step(idx)`
then `ode_state` into `value_type`). A plain-`double` stored trajectory breaks it
**silently** — the value stays right and the derivative through the observations is
lost.

**Decide before building.** Two candidates, and the choice is a DX question:

- **(a)** the functional declares which steps it reads and contributes a per-step
  adjoint seed. One new concept for everyone.
- **(b)** calibration keeps a second, denser stored trajectory. No new concept, more
  memory.

Write the decision down before Phase 5 opens. Do not let `least_squares`'s current
shape decide it by default.

---

## 6. What we are deliberately not building

Stated so it is a decision rather than an omission.

- **No templated class hierarchy.** §2.2.
- **No `decide()` type, no runtime AD flags, no capability-detection structs.** A
  concept and `if constexpr` where a compile-time choice is genuinely needed.
- **No second `Patch`, no parallel leaf-assembly path, no `*_active_` shadow fields.**
  One implementation of each thing.
- **No JVP oracle.** `<Jv,u> = <v,Jᵀu>` proves self-consistency, not correctness.
- **No component-level tape leanness work.** Measured at 0.018% of TF24's total against
  a required factor of 10²–10³.
- **No mass-chart extension.** Report 04.
- **No disturbance gradients.** Patch survival is deterministic; out of scope by the
  owner's steer.
- **No smoothing without a measured incidence and a sized scale.** develop already has
  the precedent (`P_pos`) and the method (`storage_prod_eps`, measured well-sized: 3.55%
  of records within one scale length of zero net production, median 730 away).

---

## 7. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| `Π_pp` is small somewhere reachable | the argmax channel needs a bracketed fallback; report 06 §6.2 is not a one-line solve | P3.3, before any P3.2 code |
| the free-function boundary is not where the derivative lives | a channel we cannot reach without templating a class | P1.5 on K93 — cheapest possible discovery |
| the Hermite build cost lands at the top of its bracket | forward regression outside the accepted band | P2.4 |
| trait adjoints do not accumulate | a gradient that is a fixed fraction of the FD with the correct sign, nothing thrown | P1.6 |
| the stage traversal loses a term on Cash-Karp's denser tableau | the reference failure mode is a **19%** error, correct sign, silent | P1.7 |
| the leaf node's boundary is wider than (ψ_soil, radiation, traits) | P3.2 grows a second output nobody declared | P3.2, and P0.5's manifest should have predicted it |
| a value-reproduction check is mistaken for a gradient check | a **0.2%** value gap has produced a **sign-flipped** gradient in a nonlinearly self-coupled system | every phase gate: **the gate is always AD vs a re-run FD, never value reproduction** |

---

## 8. Review gates on this plan

Three questions to answer before Phase 1 opens. All are architecture, none is code.

1. **Is §2.1 right?** Does the free-function boundary reach every channel we need, or
   is there a derivative that only exists inside a class? The cheapest test is P1.5 on
   K93, which is also the first task — so the answer is available for one PR's cost.
2. **Is the leaf's boundary (ψ_soil, radiation, traits) → (profit, per-layer uptake)?**
   Report 06 §5 says so. If a sixth quantity crosses, P3.2 changes shape.
3. **Do P0.6's two ecology decisions change the science version?** They change every
   simulated number, so they want the owner and a `scientific_version` bump before
   anything is FD-verified against them.

**Recommended order of review: (1) then (2); (3) can run in parallel because it gates
nothing before Phase 3.**
