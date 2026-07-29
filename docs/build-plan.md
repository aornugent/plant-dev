# Build plan: exact gradients of plant's emergent outputs

**Baselines.** plant `develop` @ `141dc8df`. odelia @ `854a8e183b0eab99c68fdb4d3aa5e5e6f6e1a060`.
The two AD feature branches are **quarries with a lot of good ore** — §3 says what to take
from each and what to leave, per item.

**Status: plan under review, revision 2. Nothing here is built. Do not start Phase 1
until §9's review gates are closed.**

**What changed in revision 2.** Revision 1 proposed putting the differentiable science in
scalar-templated *free functions* with the class hierarchy left `double`. **That is
withdrawn** — it builds an AD carve-out rather than integrating the engine, and develop
already contains the evidence (§2.2). The plan now carries the scalar on the types that
own the parameters, which is what the plant AD branch and the pre-v1 design
(`archive/v3-docs-and-probes:docs/archive/ad-infrastructure-design.md`) both did, and
revision 1 was too harsh in dismissing. Revision 2 also folds in the measured `Π_pp`
(§8), and adds the two workflows and the four replay levels, which revision 1 omitted
entirely.

---

## 1. What we are building

Exact trait and parameter gradients of the SCM's **emergent** outputs — the three
census metrics (LAI, biomass, basal area) and R0/offspring — for K93, FF16 and TF24,
at production lifetime (`max_patch_lifetime = 105.32`), verifiable against finite
differences, **adding no engine vocabulary per model** and without regressing the
forward model.

The objective is developer experience. A gradient engine nobody can extend is a failed
gradient engine, so the acceptance test is not only a number but a count: a plant
developer adding a new emergent metric writes **one scalar-templated reduction and
registers a name**, touching no tape code and no odelia code.

| | who | call |
|---|---|---|
| 1 | forest ecologist | `stand_gradient(scm, metrics, traits, feedback = "resident")` — emergent LAI/biomass/basal area with self-shading feedback |
| 2 | evolutionary ecologist | `offspring_production_gradient(...)` — a selection gradient, for locating singular strategies |
| 3 | modeller | `value_and_gradient(p)` in an L-BFGS loop, **both from one recording** |
| 4 | plant developer | add a metric with one templated reduction + a registered name |
| 5 | maintainer | compare AD against a re-run finite difference in plain R, same shape |

(1) and (2) are the primary workflows, and §2.4 shows they are two derivatives of two
runs plant already has. (3) is deferred to Phase 5 with its own decision.

---

## 2. The architecture

### 2.1 The decision

> **One implementation of the science, carrying the scalar it is evaluated at.
> `S = double` is production. There is no second copy for AD to read.**

Concretely, and this is the part that keeps it small: **do not add a template
parameter.** Let the scalar live with the types that own the parameters —
`T = TF24_Strategy<S>`, `E = TF24_Environment<S>` — and have the containers derive it:

```cpp
template <typename T, typename E> class Individual {
  using value_type = typename T::value_type;   // ... and likewise Node, Species, Patch
```

`Patch<T,E>` already declares `using value_type = double;` at `patch.h:22`. The change is
to derive it rather than assert it. **The existing `<T,E>` shape is unchanged**, RcppR6's
instantiation table is unchanged in shape, and `Solver<patch_type>` is unchanged. No
`<T,E,S>`, no `SCMSystem`, no `StrategyConcept`, no second `Patch`.

Two consequences carry the whole design:

- **Exactness is structural.** The gradient reads the model's own allometry, its own
  quadrature, its own reductions. There is no bit-for-bit copy anyone has to maintain,
  because there is no copy.
- **One parameter store, templated.** `TF24_Pars<S>` rather than a double `pars` plus a
  lifted active struct. A named trait then registers active *directly*. This is the single
  most important simplification available and it deletes three mechanisms at once:
  `rebind_from`, `rebind_strategy_fields`, and the parallel `FF16ProdPars`.

### 2.2 Why revision 1's free functions were wrong — develop shows it

Revision 1 pointed at `inst/include/plant/models/ff16_production_kernel.h` as "the
pattern to extend": scalar-templated free functions with `FF16_Strategy`'s double methods
delegating to them, and the header's own comment claiming they are the single source of
truth. I read the delegation and not the rest of the header. The rest of the header is the
carve-out already failing:

- **`ff16_net_from_components` re-derives the mass cascade inline.** Lines 79–84 compute
  `mass_leaf`, `area_sapwood`, `mass_sapwood`, `area_bark`, `mass_bark`, `mass_root` from
  scratch. `FF16_Strategy` has all six as methods (`ff16_strategy.cpp:30–62`) and does
  **not** delegate them. `mass_sapwood` is `area_sapwood * height * eta_c * pars.rho` in
  one place and `area_sapwood * height * p.eta_c * p.rho` in the other. **Two independent
  copies of six allometric relations, with nothing tying them.**
- **`FF16ProdPars<S>` is a second parameter struct** — 18 of `FF16_Pars`' 32 doubles,
  re-declared, hand-packed at every call site.
- **`ff16_assimilation_deep_crown_replay` is a second assimilation path**, a frozen
  weighted sum beside the model's own adaptive crown integral.
- **TF24 has no equivalent at all.** The pattern landed once, for one model, and did not
  propagate.

That is what a carve-out looks like eighteen months in: the elementary pieces stay in
sync because they are trivial, the composites drift because they are not, and the second
model never gets one. A model author who adds physiology to the class and forgets the
kernel gets a silently non-differentiable channel — and "silently wrong gradient, right
sign" is this project's most expensive recorded failure mode.

The templated-class route has the opposite property: **forgetting is a compile error, not
a wrong number.**

### 2.3 What the plant AD branch actually got wrong

It was not the templating. Measured against develop the branch is 90 files and
+6 876 / −4 177, and revision 1 read that size as the indictment. Most of it is the
mechanical retype, which is what §2.1 asks for. The genuine mistakes are four bolt-ons,
and three of them are carve-outs of exactly the kind §2.2 rejects:

| what | why it is wrong |
|---|---|
| `assemble_leaf_from`, `seam_collar_psi_input`, `seam_collar_uptake_partials`, `soil_consumption_active_` | a **parallel leaf-assembly path** beside the real one — the carve-out, reintroduced inside the templated design, for the one component that legitimately stays `double`. The leaf needs a *node with a declared boundary*, not a shadow assembly |
| `rebind_from` / `rebind_strategy_fields` | a hand-maintained per-strategy field copy. §2.1's single templated `pars` removes the need entirely |
| `PLANT_DIFFERENTIABLE`, `TF24_AD_FIELDS` as a capability macro | a compile-time flag where a template instantiation suffices. Keep the *invariant* the macro protects (names and pointers from one source); drop the flag |
| a driver that records the whole run | the 220 GB. A **driver** problem, not a templating problem — §2.5 |

So the branch's diff is largely land-worthy and its four bolt-ons are separable. Salvage
is §3.3, and it is much larger than revision 1 allowed.

### 2.4 Two workflows, and they already exist

Revision 1 missed this and it matters, because user story 2 needs no new engine.

| workflow | SCM entry | environment | gradient meaning |
|---|---|---|---|
| **resident / total** | `run()` | co-moving: the stand re-shades itself | d(emergent metric)/d(trait), full self-feedback |
| **mutant / invasion** | `run_mutant()` | the frozen resident canopy | the selection gradient |

`SCM::run_mutant()` already pins integration to the resident's cached step history, reads
the cached environment, and suppresses the mutant's self-competition through
`is_mutant_run`. **The invasion gradient is the derivative of that existing run.** These
are two pre-existing capabilities to differentiate, not a mode flag to invent.

The distinction is not a small correction. On the birth-rate axis the frozen part is the
identity `metric / birth_rate`, and the resident canopy-feedback axis **flips the sign of
biomass**. "Which feedback" is a modelling choice the API must expose, which is why
`stand_gradient` carries a `feedback` argument.

### 2.5 Four replay levels, and the one that is the correctness crux

Adaptive constructions make parameter-dependent decisions; differentiating through the
decisions corrupts the tape. Each is recorded once on a double pass and replayed fixed.
There are four, at different depths, and they compose:

| level | freezes | owner |
|---|---|---|
| **L0** — node schedule | which cohorts exist and when they are introduced | plant |
| **L1** — ODE step times | the adaptive RKCK step selection (`advance_fixed`) | **odelia** |
| **L2** — quadrature abscissae and light-spline knots | adaptive refinement | plant + odelia's interpolant |
| **L3** — the resident canopy | canopy feedback (frozen for a mutant) | plant |

| gradient | L0 | L1 | L2 | L3 |
|---|:--:|:--:|:--:|:--:|
| offspring, invasion | ✅ | ✅ | | frozen |
| census, resident | ✅ | ✅ | ✅ | **re-run** |
| census, invasion | ✅ | ✅ | ✅ | frozen |
| calibration | ✅ | ✅ | ✅ | re-run |

**L3 is where a silent wrong answer lives.** On the resident path the canopy must be
recomputed live from the active, re-evolved cohorts on the recorded knot positions.
Replaying the recorded environment *values* there returns the **invasion** gradient with
the self-shading cross term missing — a plausible number, no error. Only knot positions
are recorded; the values come from the replay.

**L2 has two variants and they are not interchangeable.** For the light spline the knots
are frozen and the values active. For a census integrated over height the integration
bound *is* an active plant height, so the quadrature **nodes move** — this needs the
scalar-templated `QK`, and a frozen-node replay would drop the moving-node sensitivity.

### 2.6 Memory: a driver decision, orthogonal to §2.1

Templating makes a whole-run recording *possible*; at production it is ~220 GB. So the
driver walks the stored double trajectory backwards and records **one cohort's rates per
(stage, cohort)**, sweeping and releasing:

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

Peak is one cohort's rates — kilobytes — and it is flat in run length, in stage count and
in the number of seeded traits. That is report 01's result, and note what it now records:
`Individual::compute_rates` **at `S = active`**, the model's own function, not a kernel
copy of it. Steps (a), (c), (d) are linear or closed-form maps costing what their forward
evaluation costs.

### 2.7 What crosses from odelia into plant

Six names, and no `xad::` spelled in plant:

| name | from | plant's use |
|---|---|---|
| `implicit_value(y*, F)` | `implicit_node.hpp` | the `ci` root-find, the birth-size solve: hand it the **residual**, not the search |
| `hermite_interpolator<S>` | `hermite_interpolator.hpp` | the light field, value and slope from one construct |
| `compute_jacobian` | `gradient.hpp` | record once, sweep m rows |
| `DifferentiationTargets` | `gradient.hpp` | which parameters/ICs to seed |
| `to_passive` | `ode_util.hpp` | knot positions, quadrature abscissae, ordering keys |
| a forward-derivative helper | new, small | the leaf's local IFT (§2.8) |

`odelia::ode::Solver` holds an `xad::Tape<double>` member, so plant includes XAD
transitively and always will. **"Don't leak XAD" means no plant author writes `xad::`** —
which is a grep: `grep -r 'xad::' plant/inst plant/src` must be empty.

### 2.8 Forward mode stays plant-local

The leaf's gas-exchange optimum is a local numerical device: `dprofit_droot_collar_psi`
already uses forward-mode AD plus the IFT to get one exact derivative, and that is the
right tool for one input and one output. odelia should **accommodate** it, not absorb it —
the reverse sweep receives the result through an injected-partials edge.

The only thing to change is the spelling. develop's `src/leaf_model.cpp` names
`xad::fwd<double>` and `xad::derivative` directly; that becomes one odelia helper. Keeping
forward mode is a design choice; naming XAD in a model file is not.

---

## 3. Salvage manifest

Each item is *take*, *take with changes*, or *leave*, with the reason. Nothing is adopted
because it exists.

### 3.1 From plant `develop` — the baseline

| | verdict |
|---|---|
| `ff16_production_kernel.h` | **retire as the composites are absorbed.** Its elementary functions become methods on the templated `FF16_Strategy<S>`; `ff16_net_from_components` and `FF16ProdPars` go away because the class *is* the templated form. §2.2 |
| the three `test-ff16-*-ad.R` witnesses | **take the assertions.** They are the only working gradient tests in either tree. Their in-test `sourceCpp` harness becomes unnecessary once plant has a compiled entry point |
| `Species::census<Psi>` (`species.h:64`) and the self-shading integral built on it | **take.** Already on develop. Phase 2 templates it on `S`; the reduction shape is unchanged |
| `SCM::run_mutant()`, `is_mutant_run`, the cached resident environment | **take, unchanged.** §2.4: this *is* workflow 2 |
| `Control()` as the fast default, `SCM::refine_schedule` in C++, `r_ode_times()` | **take.** The resolved schedule is the replay grid and `r_ode_times()` is its single source |

### 3.2 From odelia branch `claude/odelia-ad-tape-reverse-496fuf`

44 commits ahead of the baseline. Take six; leave the rest.

| commit(s) | what | verdict |
|---|---|---|
| `16cff79`, `7aa9c69`, `7a30940`, `0c62bda` | `implicit_node.hpp` — `implicit_value(y*, residual, denom_sign)`, 84 lines, with a `static_assert` that the residual returns `S` exactly | **take.** Strictly better than the baseline's `supplied_derivative`, which makes the caller compute partials by hand |
| `49f7a7f`, `4c0f3b8` | `hermite_interpolator.hpp` — C1, value and slope per knot, 167 lines | **take.** Report 03's deliverable; two-knot locality is what makes §2.6 step (c) O(1) |
| `baf6eae` | `to_passive`, nested-type-safe | **take** |
| `eb514e9` | `graft_value` | **take.** It exists to make the expression-template dangling-reference trap unwriteable. Keep its `static_assert`s |
| `0139b92` | reject a non-finite step-size decision | **take.** Correct on its own merits, unrelated to AD |
| `b426ac4` | per-term `Tape` size accessors | **take.** Diagnostics; needed to price a recording |
| `aece41d` | `incomplete_gamma.hpp` — exact Weibull antiderivative with injected partials | **take with changes**, conditional: adopt only if it beats the leaf's current pre-integrated spline on a measured forward run |
| `be13d78` | `separable_field.hpp` | **take with changes, in Phase 4.** The rank-3 factorisation is real and the per-species-η generalisation is a known forward-model requirement (P4.1). Land it on its own merits, not as AD scaffolding |
| `7505c93` | `compute_jvp` + the "adjoint dot-product oracle" | **leave.** `⟨Jv,u⟩ = ⟨v,Jᵀu⟩` is self-consistency, not correctness — both directions traverse the same recorded graph. Keeping it invites a green check that proves nothing |
| `cc6571c` | interpolator `slope(u, step, direction)` secant read | **leave.** Superseded by the Hermite; a value and a slope from two constructs agree nowhere except by accident |
| `f9d6ad8`, `ac6a988` | `mass_transport.hpp` — the log-mass chart | **leave.** Report 04 is about doing without it |
| `2a60998` | `preaccumulate` | **leave.** 1.49× and 3.7× on the component; **0.018%** on TF24's total |
| `31fb243` | `decide` / recorded value-branch | **leave.** A named type for `if`. The kink manifest is a document, not a type |
| `18a56ed`, `28059bd`, `73739d7`, `f169540`, `5c023e2` | the step-local sweep toys and their refutations | **leave the code, keep the findings.** These are the measurements reports 01–02 rest on |

Also on the branch and deliberately not listed: `supplied_derivative.hpp` (superseded by
`implicit_value`), `register_implicit` (already deleted, zero callers), and the four
primitives removed in `28059bd` for having no consumer but their own demo. That deletion
is the standing discipline: **697 lines went because nothing but a demo called them.**
Every item taken above must have a named consumer in §6 before it lands.

### 3.3 From plant branch `claude/odelia-ad-tape-reverse-496fuf`

Revision 1 leaned "leave"; on the templated architecture most of this is the work.

| | verdict |
|---|---|
| **the scalar templating itself** — `Internals_<S>`, `TF24_Strategy_<S>`, `Individual`/`Node`/`Species`/`Patch` deriving `value_type` | **take as the starting diff, re-shaped per §2.1.** Port it branch-by-branch, one model at a time, with the FF16 reference tests as the bit-identity tripwire. Two shape changes: derive `value_type` from `T` rather than adding a parameter, and collapse the double `pars` + lifted struct into one `Pars<S>` |
| scalar-templated `CanopyShape` | **take.** It is the model of what §2.1 wants — the science templated, the container not. It closed a measured `eta` severance in all three models |
| the other three severance fixes: `smooth_positive` on FF16's growth/fecundity clamp, IFT-lifted birth size, K93's `k_I` growth channel | **take, one PR each.** Each closed a measured wrong-gradient channel and each carries the channel as its test |
| the three census Ψ (LAI, biomass, basal area) as a codomain-3 functional | **take.** Several Jacobian rows off one recording, measured at +0.38% |
| `scm_gradient.h`'s *entry shape* — resolve the schedule in double, replay it, one recording per output row | **take the shape, rewrite the body** per §2.6. It is correct in structure and is the thing that runs out of memory |
| `Species::census<Psi>` templated, and the light/competition trapezium templated | **take.** §2.5's L2 moving-node case needs the scalar-templated `QK` too |
| `field_ptrs()` / `field_names()` from one list | **take the invariant, drop the macro.** Names and pointers must come from one source so they cannot disagree in membership or order; with a templated `Pars<S>` the RcppR6 yml is already that source |
| the 28 `*_driver.cpp` + `test-ad-*.R` in-test compiles | **mine for assertions, delete the harness.** Once plant has a compiled entry point, a test that compiles C++ is a test of the toolchain |
| `assemble_leaf_from`, `seam_collar_psi_input`, `seam_collar_uptake_partials`, `soil_consumption_active_` | **leave.** §2.3: a parallel leaf-assembly path. The leaf gets one node with a declared boundary — in (ψ_soil per layer, radiation, traits), out (profit, per-layer uptake) |
| `rebind_from`, `rebind_strategy_fields` | **leave.** §2.1's single templated `pars` removes the need |
| `PLANT_DIFFERENTIABLE` | **leave.** A capability flag where an instantiation suffices |
| `geometric_transport`, the extended mass chart, `log_mass_`, `census_leaf_area` | **leave.** Report 04 exists to remove this |

### 3.4 From the pre-v1 design (`archive/v3-docs-and-probes:docs/archive/ad-infrastructure-design.md`)

Held lightly — it did not pan out. Five things in it are right and were lost:

1. **The scalar collapses into `<T,E>`** rather than adding a parameter (§2.1). Smaller
   than what the branch built.
2. **One parameter store that can be active**, "no separate double `pars` plus a lifted
   active struct" (§2.1). The branch's `rebind_from` is exactly the thing this forbids.
3. **The two workflows already exist as `run()` and `run_mutant()`** (§2.4).
4. **L3 frozen ≠ re-run, and confusing them silently returns the invasion gradient**
   (§2.5). Nothing in reports 01–07 says this.
5. **Exactness is structural** — "the gradient reads the model's own reduction, not a
   maintained bit-for-bit copy". This is §2.2's argument, three revisions early.

Two of its named boundaries are carried into §8's risks: the **stiff TF24f resident
coupling** at long lifetimes (fixed-step replay drifts where the live SCM uses adaptive
sub-stepping — the true gradient exists, only the replay diverges) and the **zero-height
cohort trap** (`area_leaf = (h/a_l1)^(1/a_l2)` differentiates to `0·log(0)` = NaN at
`h = 0`).

What did not pan out, and why the plan does not repeat it: the design assumed **one tape
for the whole run** (§8 of that document: "the whole `run_mutant` replay runs on one
tape"). At production that is ~220 GB. §2.6 replaces it. Its `SuppliedDerivative` is also
superseded by `implicit_value`, which takes the residual instead of hand-computed
partials.

---

## 4. The document set — one home per fact

The corpus failed the same way twice: a claim outlived its fix because two documents could
both hold it. So **one home per fact, and the home is named before the code is written.**
`docs/audit-2026-07.md` records what was archived and why.

| document | owns |
|---|---|
| `docs/build-plan.md` | this plan: architecture, salvage, tasks, gates |
| `docs/tf24-correctness.md` | the TF24 forward-model prerequisites |
| `docs/reports/01`–`04`, `06`, `07` | the derivations and measurements the plan rests on. Reference material; never edited to track status |
| `odelia/AUTODIFF.md` | the System contract, the replay hooks, functionals. **Already good** — extend, do not rewrite |
| `odelia/ARCHITECTURE.md` | the `Tape` link across the DLL boundary |
| `plant/agents.md` §13 (new) | **how a plant model author makes their science differentiable** |
| `plant/NEWS.md` | every `old -> new` R-interface change, machine-actionable |

Two co-design rules, enforced per task:

- **A task that changes the differentiable surface changes `plant/agents.md` §13 in the
  same PR.** Not a follow-up. The section is short by construction: past two pages, the
  surface is too big.
- **A task that adds a name to §2.7's six justifies it in the PR body.** Six is the
  budget; seven needs an argument.

`plant/agents.md` §13's outline, written now so tasks fill it rather than invent it:

1. **Your model is templated on its scalar; `double` is production.** Write the science
   once. If you add physiology and it does not compile at the active scalar, that is the
   design working.
2. **Positions are `double`; values carry `S`.** Knots, quadrature abscissae and orderings
   are decided on passive values — `to_passive` is how you say so. A knot *count* that
   depends on an active value makes the recorded computation state-dependent.
3. **An inner solve is declared by its residual**, through `implicit_value`. Never
   differentiate the iteration that found the root: `golden_section_max`'s argmax is affine
   in its bracket and independent of the objective's values, so taping the search returns
   the derivative of the bracket.
4. **Never define a rate as a numerical derivative of an active quantity.**
5. **A clamp, floor, `min`/`max` or `if` on a computed value is a derivative decision.**
   Record it in the kink manifest with the incidence that justifies it.
6. **Never give a deduced return type to anything returning an active value.** XAD
   operators return expression templates holding references to their operands;
   `graft_value` exists so the idiom is not hand-written.

---

## 5. Phase 0 — prerequisites (forward model, no AD)

The subject of [`tf24-correctness.md`](tf24-correctness.md) and report 07. Here because
**the design's own acceptance test cannot pass until P0.1 lands**: report 01 §12's leading
falsifier is "re-run one cohort's rates from its boundary and compare bit for bit", and on
develop that fails on 33.78% of production records for reasons unrelated to AD.

| | task | size | gate |
|---|---|---|---|
| **P0.1** | `soil_consumption_.assign(...)` — stop a cohort inheriting the previous cohort's deep-layer uptake | 1 line + baselines | a seedling's deep layers read 0 on a leaf that solved a tree first; `solve(seedling); solve(tree); solve(seedling)` bit-identical |
| **P0.2** | zero `soil_consumption_` and `E_up_` in `set_shutdown_state` | 3 lines | a shut-down solve reports zero uptake regardless of what ran before |
| **P0.3** | `soil_moist_from_psi`'s missing `* 1e6`, plus a round-trip property test | 1 line + test | round trip to 1e-12 for θ in (θ_r, θ_sat] |
| **P0.4** | size the resource vector by resource count, not ODE width | small | no `NA_REAL` reaches `resource_depletion` |
| **P0.5** | **the kink manifest** — every clamp, floor, `min`/`max` and branch on TF24's carbon and water paths, classified, each with a measured incidence | doc + probes | every row has a number. Report 06 §7/§9b, report 07 and §8 below supply most of it |
| **P0.6** | the two ecology decisions: the double-counted leaf respiration, and `establishment_probability`'s hard gate | **owner's call** | a recorded decision either way, with a `scientific_version` bump |
| **P0.7** | guard `q(0, 0)` (`0/0`, NaN in plain `double`, and the field's lowest knot is exactly 0) and the zero-height cohort (`area_leaf`'s derivative is `0·log(0)`) | small | both carry an explicit test |

P0.5 pays for itself twice: it is the deliverable specified in four places and produced in
none, and it is the input Phase 3 needs — you cannot choose which switches to mollify
before you know which fire. **P0.6 gates Phase 3, not Phase 1.**

---

## 6. Phases 1–5

Each task is one PR with a gate that is a number or a passing test. Phases are ordered by
**attributability of failure**.

### Phase 1 — the engine, on K93

K93 has no leaf, no soil and closed-form rates, so a failure is attributable to the
engine. Its gradient is the only one with a reference today.

| | task | gate |
|---|---|---|
| **P1.1** | Land §3.2's six odelia items on `master` from `854a8e18`, each with a plant-side consumer named in the PR body | odelia suite green; **`ode_util.hpp` still includes no XAD** (plant includes it everywhere) |
| **P1.2** | `K93_Pars<S>` — one templated parameter store; `K93_Strategy<S>`; `Individual`/`Node`/`Species`/`Patch` derive `value_type` from `T` | `test-strategy-k93.R` **bit-identical**; forward benchmark within the accepted band |
| **P1.3** | Register traits by name from the one source the yml already provides | names and pointers cannot disagree — a test asserting size and order |
| **P1.4** | Trajectory storage: replay the resolved schedule in double, one state per accepted step; restore the three birth stamps (`pr_patch_survival_at_birth` divides the fecundity rate and is not in `ode_state`) | replayed final state bit-identical to the forward run; **`set_birth_state` called by a test** — today it is called by none |
| **P1.5** | The reverse driver: §2.6. Per (step, cohort) record `Individual::compute_rates` at `S = active`, sweep, release; soil and allometry adjoints closed-form | K93 census gradient matches a re-run FD to the FD's noise floor; peak tape reported and **flat** in run length and in target count |
| **P1.6** | Trait adjoints accumulate across cohorts | the discriminating test: per-cohort inputs give **41–51%** of the answer, right sign, nothing thrown. Assert the correct value, not finiteness |
| **P1.7** | Cash-Karp stage traversal — a general `sum over j < i`, accepted steps only | three-way agreement (cohort-granular, whole-run tape, FD) at a lifetime where the whole-run tape fits |
| **P1.8** | `plant/agents.md` §13 first draft; the R entry `stand_gradient()` with its `feedback` argument | a developer reads §13 and adds a metric |

**Gate: K93 census + R0 FD-verified at production lifetime, under 2 GB peak, forward model
not regressed, and §13 exists.** Nothing proceeds until this is a number.

### Phase 2 — FF16, and both workflows

| | task | gate |
|---|---|---|
| **P2.1** | `FF16_Pars<S>`, `FF16_Strategy<S>`; absorb `ff16_production_kernel.h`'s composites into the class and delete `FF16ProdPars` | `test-strategy-ff16.R` and the FF16 reference comparison bit-identical |
| **P2.2** | The four severance fixes (§3.3), one PR each | each has the channel it repairs as its test: `eta`, `a_l1`/`a_l2`, `omega`/`height_0`, `k_I` |
| **P2.3** | Template `Species::census<Psi>`, the competition trapezium, and `QK` on `S` — L2's moving-node case | a census whose integration bound is an active height carries the moving-node term; verified against FD |
| **P2.4** | Differentiate **both** L3 variants: `run()` with the canopy re-run live on recorded knots, and `run_mutant()` with it frozen | the two differ, and the resident one carries the self-shading cross term. **Positive control: replaying frozen values on the resident path must reproduce the invasion gradient** — that is the silent failure, so make it a test |
| **P2.5** | `Patch::compute_competition_slope(z)` — exact `dA/dz`, fused so `pow(z/H, eta)` is computed once | agrees with a tight central difference across `eta` in {1,2,4,8,10,12} **and** a general non-integer `eta` |
| **P2.6** | Hold a `hermite_interpolator` in `ResourceSpline` beside the fitted one; add `get_value_and_slope_at_height` | O(h⁴) on value, O(h³) on slope, on a knot set dumped from a real production step |
| **P2.7** | Attribute `rescale_spline`'s unexplained 91% (17.6 µs of 193.2 accounted for), then time a Hermite build against it | the +0.33%…+5.3% bracket collapses to one number, inside the forward budget. **Worth doing for develop alone: 175 µs/build is 3.5 s of a 59.5 s run** |
| **P2.8** | Switch the read; wire the slope into the crown integral's height channel; tighten FF16's own gradient gate | FF16 census + R0 FD-verified at production lifetime. The gate currently passes at 1e-2 where the truth is ~1e-6 — **a 100× regression would pass green** |

### Phase 3 — TF24

| | task | gate |
|---|---|---|
| **P3.1** | `TF24_Pars<S>`, `TF24_Environment<S>`, `TF24_Strategy<S>` — including the storage block (`P_pos`, the reserve gate, the outflow gate) | `test-strategy-tf24.R` bit-identical |
| **P3.2** | The leaf as **one node with a declared boundary**: in (ψ_soil per layer, radiation, traits), out (profit, per-layer uptake). `ci` via `implicit_value`; the argmax via report 06 §6.2 — **plus the bound branch**, selected by a regime test on `\|∂Π/∂p\|` (§8) | both regimes FD-verified; the selector's incidence recorded in P0.5's manifest |
| **P3.3** | `∇(∂Π/∂p)` — one gradient of one closed-form expression, including the `ci` root-find's own IFT term. The single genuinely new piece of code | `d(consumption)/dψ` within FD noise, against the **47.6–53.2%** error the frozen-argmax form gives today |
| **P3.4** | Replace `xad::fwd` in `src/leaf_model.cpp` with the odelia helper (§2.8) | `grep -r 'xad::' plant/inst plant/src` is empty |
| **P3.5** | TF24 census + R0 at `max_patch_lifetime = 105.32`, both workflows | FD-verified against the tight-inner-tolerance reference on the identical resolved schedule, under 2 GB peak. **The deliverable** |

`Π_pp` is now measured (§8), so P3.2 is unblocked and its shape is settled: two regimes,
a selector, and a well-conditioned solve in the interior one.

### Phase 4 — forward-model debts that block the user stories

Stories 1 and 2 are multi-species by definition and the light field is wrong for species of
differing η — **the forward value too, latently**, since η is read from `species[0]` only.

| | task | gate |
|---|---|---|
| **P4.1** | Per-species η: group sources by η, rank 3·n_η, degenerating to today's rank 3 when η is shared (`separable_field.hpp`, §3.2) | the two-species probe goes exact where it now computes **7.98e+14** against 0.118; the descending-height tie-break stays deterministic with differing η |
| **P4.2** | Retarget node-schedule refinement at the coupling field | freezing the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84%. The current criterion flags cohorts by contribution to reproduction, which is already converged |

### Phase 5 — calibration, decision first

`least_squares` reads intermediate trajectory states as **active** values
(`get_history_step(idx)` then `ode_state` into `value_type`). A plain-`double` stored
trajectory breaks it **silently** — the value stays right, the derivative through the
observations is lost. Two candidates, and it is a DX question:

- **(a)** the functional declares which steps it reads and contributes a per-step adjoint
  seed. One new concept for everyone.
- **(b)** calibration keeps a second, denser stored trajectory. No new concept, more memory.

Write the decision down before Phase 5 opens. Do not let `least_squares`'s current shape
decide it by default.

---

## 7. What we are deliberately not building

- **No third template parameter, no `SCMSystem`, no `StrategyConcept`, no second `Patch`.**
- **No parallel path for anything** — no `assemble_leaf_from`, no `*_active_` shadow
  fields, no second parameter struct, no second assimilation path. §2.2 is the argument and
  develop is the evidence.
- **No capability flags or SFINAE detection structs.** A concept and `if constexpr` where a
  compile-time choice is genuinely needed.
- **No `decide()` type.** The kink manifest is a document.
- **No JVP oracle.** Self-consistency is not correctness.
- **No component-level tape leanness work.** 0.018% of TF24's total against a required
  factor of 10²–10³.
- **No mass-chart extension.** Report 04.
- **No disturbance gradients, no Hessians.** Out of scope by the owner's steer.
- **No smoothing without a measured incidence and a sized scale.** develop has the
  precedent (`P_pos`) and the method (`storage_prod_eps`, measured well-sized).

---

## 8. `Π_pp`, measured — and what it changes

`scripts/curvature_probe.R`, against a develop build: a central difference of develop's own
analytic `dprofit_droot_collar_psi` about the solved operating point, at
`GSS_tol_abs = 1e-10` so the number is the geometry, each point at three step sizes. Swept
over the **whole feasible domain of the argmax** — `psi_soil` from the default driver's
0.015–0.17 MPa down to the stem's `psi_crit = 7.085`, four heights, and five heterogeneous
profiles of the kind a drydown makes — so it brackets anything any driver can reach.

**The falsifier does not fire.** 52 states, none shut down, `Π_pp` **negative at all 52** —
no fold, no sign change. `|Π_pp|` from **0.1723 to 15.61**, median 4.2, so the worst
amplification through `μ = −s/Π_pp` is **5.8×**. Report 06 §6.2's one-scalar solve is well
conditioned wherever the argmax is interior.

**But the inferred value was wrong by four orders**, and that inverts an argument. The
design carried `Π_pp ≈ −1.1×10⁵`, inferred from a ratio; measured, it is O(1)–O(10). So the
objective is **gently curved, not sharply peaked**, and report 06's "peakedness as a
licence" section needs re-deriving: with `Π_pp ≈ −4`, a 1e-4 search error should leave
`∂Π/∂p ≈ 4e-4`, not the **11–23** measured at `GSS_tol_abs = 1e-3`. Those two cannot both
describe a small error near an interior maximum. The open question is now about **the
search**, not the geometry — and it is cheap to settle.

**New: the operating point has two regimes, and they must not be pooled.**

| regime | count | |
|---|---|---|
| stationary interior maximum (`\|∂Π/∂p\|` at the solver floor) | **37 / 52** | `Π_pp` −14.6 … −0.17, median −2.08 |
| **pinned at a bound** (`\|∂Π/∂p\|` = 0.054 … 2.12 *at tolerance 1e-10*) | **15 / 52** | every one at `psi_soil ≥ 1.5 MPa` **and** `height ≥ 2 m` |

None of the 15 is inside the default driver's `psi_soil` range, which is exactly why report
06 measured zero corner incidence — that run used the default driver. The stress banks go
to 1.5+ MPa, so **the pinned branch is reachable and P3.2 needs it.** The archived corner
note was groping at something real with a degenerate probe: the corner exists, it is a
dry-**and**-tall phenomenon, and where it binds the second derivative is a local slope
change rather than the denominator of a stationarity solve.

Consequences, all folded in above: P3.2 gains the bound branch and a regime selector;
P0.5's manifest gains a row for that selector with its 29%-of-this-envelope incidence; and
report 06 §7's "genuinely open" row for `Π_pp` and §11's leading falsifier are both
answered.

---

## 9. Risks, each with the number that would expose it

| risk | how it shows | when we would know |
|---|---|---|
| ~~`Π_pp` is small somewhere reachable~~ | **closed.** 52/52 negative, min 0.17, worst amplification 5.8× | §8 |
| a channel exists that templating cannot reach | a derivative only obtainable through a parallel path — i.e. §2.2's carve-out, forced | P1.5 on K93, the cheapest possible discovery |
| the forward model regresses under templating | benchmark outside the accepted band, or FF16 reference numbers move | P1.2 / P2.1 / P3.1, each gated on bit-identity. The branch measured develop 49.57 s vs branch 50.31 s, so this is achievable |
| L3 confusion returns the invasion gradient on the resident path | a plausible number with the self-shading cross term missing, no error | P2.4's positive control makes it a test rather than a hazard |
| trait adjoints do not accumulate | a fixed fraction of the FD with the correct sign, nothing thrown | P1.6 |
| the stage traversal loses a term on Cash-Karp's denser tableau | the reference failure mode is a **19%** error, correct sign, silent | P1.7 |
| **stiff TF24f resident coupling at long lifetimes** | the fixed-step replay itself drifts, because the live SCM tames the `log_density`↔canopy loop with adaptive sub-stepping a frozen schedule cannot reproduce. The true gradient exists (full-SCM FD is finite) | P3.5. **Gate it with a clear error driven by the double replay's environment error, never a wrong number** |
| the leaf node's boundary is wider than (ψ_soil, radiation, traits) | P3.2 grows an output nobody declared | P3.2, and P0.5's manifest should have predicted it |
| a value-reproduction check is mistaken for a gradient check | a **0.2%** value gap has produced a **sign-flipped** gradient in a nonlinearly self-coupled system | every gate: **the gate is always AD vs a re-run FD** |

---

## 10. Review gates on this plan

Three questions before Phase 1 opens. All architecture, none code.

1. **Is §2.1 right — does the scalar belong on the types that own the parameters, with
   `<T,E>` unchanged?** The pre-v1 design says so and the branch's `rebind_from` is what
   happens without it. The cheapest test is P1.2 on K93: if `K93_Pars<S>` plus derived
   `value_type` compiles and `test-strategy-k93.R` stays bit-identical, the shape holds for
   all three models.
2. **Is the leaf's boundary (ψ_soil, radiation, traits) → (profit, per-layer uptake)?**
   Report 06 §5 says so. A sixth quantity changes P3.2's shape — and the branch's four seam
   hooks are what a wider boundary looks like when it is not declared.
3. **Do P0.6's two ecology decisions bump `scientific_version`?** They change every
   simulated number, so they want the owner before anything is FD-verified against them.

**Order: (1) then (2); (3) runs in parallel because it gates nothing before Phase 3.**
