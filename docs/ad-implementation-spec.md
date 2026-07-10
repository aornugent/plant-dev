# AD implementation spec: plant emergent gradients on odelia's AD runtime

Operationalises [`ad-infrastructure-design.md`](./ad-infrastructure-design.md),
[`ad-record-replay.md`](./ad-record-replay.md), and
[`ad-r-interface.md`](./ad-r-interface.md) into the code-grounded plan the
`aornugent/plant` AD epic ([#7](https://github.com/aornugent/plant/issues/7),
sub-issues AD-1…AD-11) implements. This is the *implementation* layer: the design
docs say what and why; this says which file, which odelia call, what to delete, and
how each step is gated.

## Base and provenance

- **Base:** `plant:develop` and `odelia:claude/ad-surface`. Nothing is built on the
  prototypes.
- **Oracle, not base:** the #553 spike (`spike-ff16-scm-emergent`) and PROTO-3
  (`proto3_leaf_edge.cpp`) proved the gradients are reachable and the odelia tape
  links from `plant.so`. Their *code* is reference only — the spike's parallel engine
  (`gradient/coupled_canopy.h`, `scm_harvest.h`, `*_emergent.cpp`, five local tapes)
  is exactly the debt this plan deletes rather than ships.
- **odelia is done and generic.** `claude/ad-surface` ships the whole reverse-mode
  surface: a Solver-owned tape, the duck-typed `compute_jacobian`/`compute_gradient`
  driver, `DifferentiationTargets`, the pure-reduction functional, the `Replayable`
  record/replay concept, `SuppliedDerivative`, the `rebind` lift, and one replayable
  interpolator (odelia#22). Plant's job is therefore small and **deletion-heavy**:
  template the model on one scalar, satisfy the contract, delete the parallel paths.

---

## 1. The commitment

### The hard fact
The differentiable machine already exists inside plant. The Patch is already the
odelia System (`SCM` holds `odelia::ode::Solver<patch_type>`, `scm.h:133`), and
`run_mutant` is already the frozen-schedule replay (`scm.h:294`). odelia already owns
every generic AD mechanism. Exact reverse-mode SCM gradients — many traits in (~28),
few metrics out (~4) — therefore need **no new AD engine**: only the model's own types
carrying one active scalar and satisfying a contract that is already built.

### The commitment
> Make the *existing* `Patch`/`SCM`/`Strategy` differentiable by threading one scalar
> `value_type = S` and satisfying odelia's System + `Replayable` contract — running the
> model's own `run`/`run_mutant`/reductions at `S=active`. **odelia owns every tape;
> plant writes no XAD.**

**Kept true by structure, not convention:**
- `FF16_Strategy` becomes `FF16_Strategy_<S>` with `using FF16_Strategy =
  FF16_Strategy_<double>`, so the double path is *literally the same code* at `S=double`
  — the existing FF16 reference-comparison test guarantees no drift.
- The only tape is `Solver::tape` (odelia). No `xad::AReal`, `Tape`, `registerInput`, or
  `computeJacobian` appears in plant source — grep-able as a CI invariant.
- Every reduction is the model's own scalar-templated function (`Species::compute_competition`,
  `QK::integrate`), so gradient exactness is structural, not a maintained bit-copy.
- The two workflows are `run` (L3 cache empty) vs `run_mutant` (L3 cache populated) — a
  data-presence choice inside `derivs`, not a `feedback` mode flag.
- Only `double` crosses the R boundary; active types are born and die inside one C++ call.

### What this settles (the code we do *not* write)
- **No** `SCMSystem`, `StrategyConcept`, or `Runnable` wrapper — the driver is duck-typed,
  so the SCM *is* the runnable as-is (§3).
- **No** parallel active/frozen physiology axis — one uniform `S`, so `<T,E,S>` collapses
  to the existing `<T,E>`.
- **No** `coupled_canopy.h`, `scm_harvest.h`, `ff16_emergent.cpp`, `tf24_emergent.cpp`,
  `tf24f_emergent.cpp`, and no five local tapes — deleted, never ported.
- **No** separate census kernel — the census reduction *is* `compute_competition` at
  `S=active`.
- **No** plant-owned adaptive interpolator — `AdaptiveInterpolator`/the adaptive half of
  `ResourceSpline` give way to odelia's replayable interpolator (odelia#22).
- **No** R-visible active solver, `active` flag, or second solver — the boundary can only
  fail loudly (`ad-r-interface.md` §2).
- The "which replay grid?" question disappears: `recorded_steps()` on the Solver is the
  one source. The "which feedback?" question disappears: `has_recorded_field()`.

### What this makes hard (the price)
- **Stiff TF24f resident coupling at long patch lifetimes.** A fixed-node replay cannot
  reproduce the adaptive sub-stepping the live SCM uses to tame the `log_density`↔canopy
  stiffness; the frozen-step replay drifts. Cope: gate with a clear error driven by the
  double replay's environment error — never a wrong number. Out of v1 (Appendix A).
- **Any metric that must differentiate through *where* the adaptive scheme placed nodes**
  (not just what they hold) is inexpressible. None of the shipped metrics need it; the
  record→replay argument (`ad-record-replay.md` §3.1) shows the residual is below the
  tolerance the adaptive scheme already accepts.
- **Debugging active values is awkward** — no `wrap`/`as`, extraction only via
  `xad::value`/`xad::derivative`. By policy (`ad-r-interface.md` §3.4), to make silent
  derivative loss impossible.
- **A trait feeding a `prepare_strategy()`-derived quantity differentiates to zero**
  unless `prepare_strategy()` re-runs under the active scalar after seeding — a required,
  easy-to-miss step. Cope: it is the primary gate of AD-2.

### Kill condition
If a required emergent metric turned out to depend on the adaptive *branching itself* —
the gradient genuinely needing the derivative of node *placement*, not node *values* —
the record→replay-fixed commitment would be invalid and a differentiable adaptive scheme
would be required. The design argues this never occurs within tolerance; a metric that
violated it would force a rethink, not a patch.

---

## 2. The odelia surface plant codes against (verified against `claude/ad-surface`)

These are the exact shapes plant targets. Copied from the headers, not the (slightly
stale) `autodiff.md` — see the drift note in Appendix B.

**The driver** — `inst/include/odelia/gradient.hpp:45,116`. Duck-typed on the runnable,
**no `schedule` argument** (the runnable owns its replay):
```cpp
template<typename Solver, typename Functional>
std::pair<std::vector<double>, std::vector<std::vector<double>>>   // {values, rows}
compute_jacobian(Solver& solver, const DifferentiationTargets& targets, Functional&& functional);

template<typename Solver, typename Functional>
std::pair<double, std::vector<double>>
compute_gradient(Solver& solver, const DifferentiationTargets& targets, Functional&& functional);
```
The forward callback (one per Jacobian row) does exactly: seed the targets through
`solver.get_system_ref().ad_parameters()/ad_initial_state()`, `solver.reset()`,
`solver.run()`, `functional(solver)`. The tape is `solver.tape` (a lazy
`unique_ptr`, created once and reused across rows). The codomain is read off
`functional.codomain()` (no spare model run to size it).

**Differentiation targets** — `DifferentiationTargets{ std::vector<int> params;
std::vector<int> ics; std::vector<double> values; }` with `empty()`/`size()`. Column
order is a contract: column *j* is `d(out)/d(input_j)` in `values` order (params then
ics). A caller resolving trait names → indices seeds in the same order it reads columns.

**The functional** — any struct with `std::size_t codomain() const` and
`template<class Solver> std::vector<typename Solver::value_type> operator()(Solver&) const`.
It is a pure reduction: reads the replayed solver, drives nothing, holds no schedule.
`scalar_functional` adapts a one-output functional; `least_squares`/`sum_of_squares` are
prebuilt (`gradient.hpp`).

**The System contract** — the members a differentiable System adds (worked example:
`inst/include/examples/canopy_system.hpp`, which plant's Patch mirrors):
```cpp
using value_type = S;
template <class S2> using rebind = System<…, S2>;   // double -> active mould
template <class S2> rebind<S2> rebind_from() const;  // xad::value the config into S2
std::vector<S*> ad_parameters();                     // handles to the active parameters
std::vector<S*> ad_initial_state();                  // handles to the active initial state
```
Plus the ODE interface, including the two `set_ode_state` overloads the replay dispatch
routes between: `set_ode_state(it, double time)` (recompute) and `set_ode_state(it, int
stage)` (frozen read).

**The `Replayable` concept** — `inst/include/odelia/ode_interface.hpp:42`:
```cpp
template <typename System>
concept Replayable = requires(System s, int stage) {
  s.record_stage(stage);      // per RK stage, record pass: positions@0 + field value@stage
  s.record_ode_step();        // per accepted step, record pass: commit
  s.replay_step();            // per step, replay pass: load this step's slice
  { s.has_recorded_field() } -> std::convertible_to<bool>;  // is the L3 cache populated?
};
```
The `derivs` dispatch (`ode_interface.hpp:156`) is the whole semantic fork:
```cpp
if constexpr (Replayable<T>) {
  if (obj.has_recorded_field()) internal::set_ode_state(obj, y, index); // L3: frozen double
  else                          internal::set_ode_state(obj, y, time);  // recompute, active
} else                          internal::set_ode_state(obj, y, time);
```
`has_recorded_field()` is *data presence*, not a mode (odelia#28): populated ⇒ mutant/
frozen (derivative through the field is zero by construction); empty ⇒ resident/recompute
(self-shading flows). **The one way to get it wrong:** for a resident gradient, populating
L3 (or otherwise reading recorded values) silently drops the self-shading cross term.

**`SuppliedDerivative`** — a free function called from *within* the forward pass, built on
`xad::CheckpointCallback` (`inst/examples/supplied_derivative_interface.cpp`). Registers an
off-tape value (a root-find / optimizer result) as a fresh leaf and hands the reverse sweep
its analytic partials `∂y/∂x_i`. odelia's compatibility seam for plant's forward-mode leaf
optimizer (AD-9); never used for FF16 physiology, which tapes directly.

**The `Solver`** — `inst/include/odelia/ode_solver.hpp`. `run()` = `advance_fixed(replay_schedule_)`;
`set_schedule()` hands over the L1 schedule per call; `active_solver` caches the active twin
(built via `rebind_from`, tape included); AD is opt-in via `rebind_or_self` (a plain-double
System without `rebind` still compiles), and the Solver is copyable (copy resets tape/active
twin — they are amortization scratch, not value).

---

## 3. The runnable seam: the SCM is the runnable (Model A)

**Why the SCM, not the odelia `Solver`.** The gradient's forward pass must reproduce the
full trajectory, and cohort introductions are *interleaved between* `advance_fixed` calls
in `SCM::run_next_impl` (`scm.h:262` `introduce_new_nodes` → `:278` `advance_fixed(e.times)`,
looped by `run()`). An introduction grows the Patch's `ode_size`; a single
`Solver::run()`/`advance_fixed` integrates a fixed-size system, so it cannot introduce
mid-run. Making the odelia `Solver` the runnable would require folding L0 into a
growing-system stepper (Model B) — more mechanism in odelia's core, against "L0 is
plant-owned". So the runnable is `SCM::run()`/`run_mutant()`.

**Why this needs no odelia change.** The last two `ad-surface` commits made the SCM a
first-class runnable without touching plant's use: `e776a8c` dropped the driver's
`schedule` arg (so `compute_jacobian(runnable, targets, functional)` calls only
`runnable.run()/reset()/get_system_ref()` and `runnable.tape`), and `9ea4704` made
`Solver` AD-opt-in + copyable (so plant's double `Solver<patch_type>` still compiles and
snapshots). **Both odelia's `Solver` and plant's `SCM` are runnables the one duck-typed
driver accepts.** The SCM satisfies the surface by adding `get_system_ref()` and a `tape`
member and fixing `reset()` (AD-3); the inner `Solver<patch_type>` remains the ODE engine
each `advance_fixed` segment runs on.

**Active-twin construction & the recording.** The R-held double SCM builds the active SCM
per gradient call via `rebind_from()` and hands over the recording (schedule =
`step_history`, frozen field = `environment_history`). Build-per-call in v1; amortized
reuse is Appendix A.1.

---

## 4. Per-issue implementation spec

Legend: **Change** = the edit and where; **odelia** = the contract used; **Delete** = code
removed; **Trap** = the correctness gotcha; **Gate** = validation. FD = re-optimising
central finite difference of the same run. The AD-1/AD-2 checkboxes in epic #7 are
**premature — neither is on any branch**; they gate everything and land first.

### Foundation

**AD-1 (#5) — scalar-template FF16 on `S`.**
- **Change.** `Internals` → `Internals<S>` (`internals.h:35-38` state vectors
  `std::vector<double>`→`std::vector<S>`, accessors→`S`). `FF16_Pars`→`FF16_Pars<S>` and
  `FF16_Strategy`→`FF16_Strategy_<S>` with alias `FF16_Strategy = FF16_Strategy_<double>`
  (`ff16_strategy.h`). Thread `using value_type = typename T::value_type` through
  `Individual/Node/Species` and change `patch.h:22` `using value_type = double` →
  `typename T::value_type`. Template the class, **not** the 67 methods — a class-template
  instantiation keeps its own vtable, so the `assimilation_fn` member pointer and the
  `virtual net_mass_production_dt` survive per-`S`. Reuse `ff16_production_kernel.h`'s
  already-templated free functions; template the remaining inline `double` math
  (`mass_leaf`, `area_sapwood`, the `d*_d*` allocation-derivative family, `mortality_dt`,
  `establishment_probability`, `height_seed`, the header hot paths).
- **odelia.** `Solver<patch_type>` compiles for `S=double` via `rebind_or_self` (no
  `rebind` yet). Environment stays `double` here (invasion reads it frozen).
- **Delete.** Fold #540's **test-only** kernel machinery into the templated class:
  `FF16ProdPars`, `ff16_net_from_components`, `ff16_net_mass_production_crown_top`,
  `ff16_assimilation_deep_crown_replay` are referenced only by the three AD tests
  (confirmed: zero production call sites). Once `FF16_Strategy<S>` is the single source,
  the tests seed a trait and run the real class; delete the struct + composition helpers.
  Keep the four per-piece kernels the model calls (`ff16_area_leaf` etc.) or inline them —
  either preserves single-source.
- **Trap.** `std::pow/exp/sqrt/log` get XAD overloads by ADL; audit `util::is_finite`,
  `util::uniroot`, `std::numeric_limits` for `S`-friendly forms — call each out in the PR.
- **Gate.** FF16 **double** suite bit-identical (the alias guarantees it); a minimal check
  that `FF16_Strategy_<active>` evaluates one kernel. Take the in-situ `tape.getMemory()`
  reading here (PROTO-1 resolved *uniform S*; the number is confirmatory).

**AD-2 (#6) — Patch satisfies the System contract.**
- **Change.** Add `rebind`/`rebind_from()` (`rebind = Patch<T, FF16_Environment>`, env
  `double` for invasion), `ad_parameters()` (pointers into the one shared `FF16_Pars<S>`
  trait fields — **fixed, documented column order**), `ad_initial_state()` (seedable
  initial size distribution; may start empty). Lean on existing strategy sharing:
  `SpeciesBase` holds one `shared_ptr` strategy (`species_base.h:79,83`) aliased by every
  `Node`/`Individual`, so seeding the one strategy reaches all cohorts, including late
  introductions.
- **odelia.** The four-member differentiable-System contract; the `CanopySystem` shape.
- **Trap (primary gate).** `prepare_strategy()` freezes derived quantities as `double`
  (`eta_c`, `height_0*`, `area_leaf_0`, `canopy_shape`, the bound `assimilation_fn`,
  `ff16_strategy.cpp:544-585`). A trait feeding any of these differentiates to zero unless
  `prepare_strategy()` re-runs under the active scalar **after** seeding. `Patch::reset()`
  must re-init cohort state from its *own* seeded `parameters`, never an external double
  snapshot (mirrors `CanopySystem::reset` keeping `gain`).
- **Gate.** Build an active Patch, seed one trait, re-run `prepare_strategy()`, `reset()`,
  introduce a cohort, assert a derived quantity (e.g. `height_0`) carries the derivative
  and the seed survives to a late introduction.

### FF16 invasion (the first end-to-end proof)

**AD-3 (#8) — the SCM is the runnable + fix `reset`.**
- **Change.** Add to `SCM` (`scm.h`): `patch_type& get_system_ref()` (forward
  `solver.get_system_ref()`), a `tape` member the driver manages, and confirm
  `run()`/`run_mutant()` run under the tape at `S=active` unchanged. `rebind`/`rebind_from()`
  build `SCM<FF16_Strategy_<active>, FF16_Environment>`; **`node_schedule` stays `double`**
  (L0 resolved up front; introduction times are constants).
- **odelia.** The duck-typed driver (§2/§3) — no odelia change.
- **Trap (the reset fix).** `SCM::reset` (`scm.h:377-384`) does `solver.get_system_ref() =
  patch; solver.reset(); patch = solver.get_system_ref();` — copying the stored *double*
  `patch` over the system, which clobbers the driver's seed on the active twin. The active
  path must delegate to `Patch::reset()` (AD-2), re-initialising from the seeded parameters;
  keep the double path behaviourally identical.
- **Gate.** Instantiate `SCM<…active…>`, seed a trait via `get_system_ref().ad_parameters()`,
  `reset()`, `run()` a pinned schedule, confirm completion at `S=active` and seed survival.

**AD-4 (#9) — Patch satisfies `Replayable` (frozen-field dispatch).**
- **Change (rename, plant half of odelia#28/#19).** `patch.h`: `cache_ode_step()`→
  `record_ode_step()` (`:728`), `cache_RK45_step(int)`→`record_stage(int)` (`:738`),
  `load_ode_step()`→`replay_step()` (`:749`); expose `use_cached_environment` (`:155`) as
  the `has_recorded_field()` query; `save_RK45_cache` (`:152`) stays the record-mode flag
  (rename at the R/Control surface to read as "prepare for gradients", RIF-7). Supersedes
  the stale issue #3.
- **The real wiring.** Add the `set_ode_state(it, int stage)` overload odelia's dispatch
  calls (`ode_interface.hpp:160`), routing the per-stage frozen read (`environment_ptr =
  &environment_history[idx][index]`, `patch.h:715`) through the concept rather than the
  default state-set. Static-assert `Replayable<Patch>`.
- **Scope.** Invasion needs only the **L3** frozen read. L2 (recording light-spline knot
  *positions* for the resident recompute) lands with AD-8 — keep independent:
  `record_stage` records field values; knot-position recording is added later without
  disturbing this.
- **Gate.** The double `run_mutant` path stays behaviourally identical (`test-mutant.R`
  green); `Replayable<Patch>` static-asserts true.

**AD-5 (#10) — `EmergentFunctional` + the `stand_gradient_cpp` entry + thin R wrapper.**
- **Change.** New `inst/include/plant/emergent_functional.h`: a pure reduction
  (`codomain()` + `operator()(runnable)`) reading `runnable.get_system_ref()` and the
  trajectory. Metric kernels selected by name: `offspring` (`Σ tw_i · offspring_i`, fixed
  weights), `LAI`/`biomass`/`basal_area` (census reductions reusing `compute_competition`,
  AD-1/AD-7), `R0` (`net_reproduction_ratio`, `scm.h`). New **hand-written** `src/stand_gradient.cpp`
  (not the generated TUs): one `[[Rcpp::export]]` taking the RcppR6 SCM by pointer-unwrap
  only (`Rcpp::as<RcppR6<…>>` — no serialisation), resolving `metrics`→functional and
  `traits`→`DifferentiationTargets` in AD-2 column order, `rebind_from()`, configuring
  feedback, calling `odelia::ode::compute_jacobian`, returning doubles. Strategy dispatch is
  a C++ `switch` on a strategy tag off the handle. Thin R wrappers `stand_gradient(scm,
  metrics, traits, species, feedback)` and `offspring_production_gradient(resident, traits)`.
- **odelia.** `compute_jacobian` + the functional shape. `Rcpp::compileAttributes()`
  regenerates `RcppExports.*`; no `RcppR6_classes.yml` change (free function).
- **Delete.** This entry replaces the spike's `stand_gradient` R/`*_emergent.cpp` surface
  wholesale — no per-strategy entry points, no R harvest.
- **Gate.** Compiles and links (tape symbols resolve at load against odelia, proven by
  PROTO-3); `stand_gradient(scm, "offspring", "lma")` returns a finite double on a cached
  resident. (Numbers are AD-6.)

**AD-6 (#11) — FF16 invasion gradient end-to-end + FD gate + zero-height fix.**
- **Change.** Compose AD-3/4/5 into the invasion gradient: differentiate `run_mutant` at
  `S=active`, canopy read frozen (L3 populated → derivative through it zero), self-competition
  suppressed by the existing `is_mutant_run` gate (`patch.h:427,438,568`, set by `set_mutant()`).
- **Zero-height fix (was PLANT-11).** A cohort introduced on the final step (`birth == N`)
  can sit at `h≈0`, where `area_leaf = (h/a_l1)^(1/a_l2)` differentiates to `0·log(0) = NaN`
  (also biased the value). Establish `birth ≥ N` cohorts at seed height `h0` in the
  Species/Patch introduction path; add an AD test at the final-step boundary.
- **Gate.** `offspring_production_gradient(resident, c("lma","hmat"))` matches re-optimising
  central FD to `tol ~1e-4` on the canonical FF16 case with `control(save_RK45_cache = TRUE)`.

### Census, resident, TF24, birth-rate

**AD-7 (#12) — `qk.h::integrate_ad` + native census kernels.**
- **Change.** Add `template<class S> S integrate_ad(F f, S a, S b) const` to `qk.h` — the
  same `xgk`/`wgk` rule, bounds/abscissae/accumulator `S`, so an active plant-height bound
  propagates through the *moving* nodes (a frozen-node replay would miss this). Single-layer,
  Kronrod result only, stateless (no `last_*` writes). Add LAI/biomass/basal_area `psi`
  kernels to `EmergentFunctional`: a descending-height trapezium over active cohorts +
  `integrate_ad` at the active bound, reusing `compute_competition`.
- **Note vs #540.** This is the *other* L2 quadrature pattern: #540's `deep_crown_replay`
  folds `q` into a frozen weighted sum (per-plant crown, fixed weights); the census bound is
  a differentiable height, so it needs moving nodes.
- **Delete.** The spike's `scm_harvest.h::census_trapezium` — replaced by the templated
  reduction, no hand-copied census.
- **Gate.** `stand_gradient(scm, c("LAI","biomass","basal_area"), traits,
  feedback="invasion")` matches central FD per metric (`tol ~1e-4`).

**AD-8 (#13) — resident/total gradient: `FF16_Environment<S>` + L2-live spline recompute.**
- **Change.** Template `FF16_Environment` and `ResourceSpline` on `S` (values → `S`, knot
  positions stay `double`); generalise the `double` literals in `step_light`/`smooth_floor`
  and the `std::max(0.0, spline(h))` clamp (`ff16_environment.h:70-121`). Record the
  light-spline knot **positions** per accepted step (AD-4's `record_stage`/`record_ode_step`,
  the L2 slice, independent of the L3 field cache). On the active pass `run()` (resident, L3
  cache **empty**) recomputes `compute_environment` on those frozen knots with the active
  cohorts, so a trait re-shades the stand through `area_leaf`.
- **odelia (the unlock, odelia#22 — done).** Retire plant's `AdaptiveInterpolator`/the
  adaptive half of `ResourceSpline` in favour of odelia's one replayable `interpolator.hpp`
  (records its own knots, rebuilds fixed). Net deletion in plant.
- **Trap (the correctness crux).** Do **not** read the frozen `environment_history` on the
  resident path — that silently collapses to the invasion gradient (`ad-r-interface.md` §6.8;
  odelia autodiff "the one way to get it wrong"). Only knot positions are recorded; cohort
  values come from the replay.
- **Gate.** Resident census gradient matches central FD of the full self-shading `run`
  (`tol ~1e-4`) **and** demonstrably differs from the invasion gradient (self-shading term
  present, can flip signs).

**AD-9 (#14) — TF24/TF24f leaf edge inside the SCM (realises PROTO-2, highest risk).**
- **Change.** Scalar-template TF24/TF24f on `S` as AD-1 did FF16. Keep the leaf optimizer's
  own solve plant-local forward-mode; at the optimised operating point compute the leaf
  trait partial as a `double` and inject it via `odelia::ode::supplied_derivative(tape,
  value, {&trait_active}, {partial})`, so the whole `run_mutant` runs on **one tape** and the
  reverse sweep traverses density→optimum→trait natively. Census reuses AD-7.
- **odelia.** `SuppliedDerivative`. **Settle the open question empirically:** does TF24
  census need a *recorded adaptive QAG subdivision* (L2), or does the fixed `integrate_ad` at
  the active bound suffice? develop's evidence says fixed suffices; if not, record QAG
  abscissae through AD-4/AD-8's hooks (no new odelia change).
- **Delete.** The spike's `tf24_emergent.cpp`/`tf24f_emergent.cpp` and their local tapes.
- **Gate.** A single-TF24-cohort density-dependent census gradient matches central FD
  (`tol ~1e-4`) and demonstrably **includes** the density→optimum cross-term (vs a
  frozen-optimum variant). Boundary: TF24f coupled resident feedback at long horizons is out
  of v1 (Appendix A.2).

**AD-10 (#15) — birth-rate gradient + `d R0/d birth_rate` (equilibrium).**
- **Change.** `birth_rate_gradient(scm, metrics, species)` on the coupled resident replay
  (AD-8): the frozen part is the identity `metric/birth_rate`; the resident (canopy-feedback)
  axis needs the tape and can flip the sign of biomass. Register `birth_rate` as an active
  input alongside traits (a registered leaf in `DifferentiationTargets`). Plus
  `d(net_reproduction_ratio)/d(birth_rate) = dR0/db` via the mutant framing (mutant traits =
  resident; the change in mutant fitness as resident density moves is the density feedback) —
  the plant-side derivative for the R0 = 1 equilibrium Newton solve. FF16 single- then
  multi-species; TF24f gated like its trait gradient.
- **Gate.** `birth_rate_gradient` matches central FD of the coupled resident run
  (`tol ~1e-4`); `dR0/db` matches FD of `net_reproduction_ratio`; a smoke test that a Newton
  step using `dR0/db` moves toward R0 = 1.

**AD-11 (#16) — un-skip the AD suite against the compiled path + regression baseline.**
- **Change.** Convert `test-ff16-ad-kernel.R`, `test-ff16-deep-crown-ad.R`,
  `test-ff16-resident-coupling-ad.R` from out-of-tree `sourceCpp`-against-`odelia.so` (four
  skip guards apiece) to exercise the **compiled** `stand_gradient`/kernel path in `plant.so`.
  **This is where the #540 test-only replica dies:** the tests seed a trait and run the real
  `FF16_Strategy<active>`/SCM, not a hand-built `FF16ProdPars` composition. Keep the
  `is_pkgload_dll()` guard (AD needs the installed DLL). Snapshot the validated Jacobians to
  `tests/testthat/fixtures/gradient-baseline.rds` (add `scripts/gradient_fixture.R` +
  `helper-gradient-fixture.R`), two-tier tolerance (bit-identity on the recording machine,
  a noise floor across platforms).
- **Gate.** The three files run (not skip) in `R CMD check` against the installed package and
  pass; the `.rds` baseline round-trips and catches an injected perturbation.

### Cross-cutting: UX-2 oracle
No stored baseline exists on develop; FD is the only oracle. Every `AD-*` gate is
AD-vs-FD to `~1e-4` (loosen only with justification; #540's kernel milestones hit ~1e-8).
The `.rds` baseline is snapshotted once AD-6 + AD-8 are green (AD-11) and then gates every
subsequent AD change.

---

## 5. Co-design ledger (odelia changes this port implies)

The corrected ledger is nearly empty — the runnable seam needs **no** structural odelia
change (§3).

| Item | What | Priority | Blocks plant? |
|---|---|---|---|
| `autodiff.md` `schedule` drift | The doc still shows `compute_gradient(d, targets, schedule, functional)`; the arg was dropped (`e776a8c`, odelia#27→#31). Fix the doc so a developer codes to the real contract. | Should-fix (doc) | No |
| Name the `Runnable` concept (optional) | The driver's `Solver` template param is duck-typed; both odelia's `Solver` and plant's `SCM` satisfy it. Optionally name a `Runnable` concept + `static_assert` so a missing member fails at the boundary with a clear message, not deep in `computeJacobian`. Small; naming/clarity only. | Nice-to-have | No |
| ODELIA-4 test gap (from `9ea4704`) | No non-AD-System-on-the-AD-Solver test and no Solver-copy test. plant's double build exercises both; odelia should cover them natively. | Nice-to-have | No |

---

## 6. Build order, gating, and PR plan

```
AD-1 ─► AD-2 ─► AD-3 ─► AD-4 ─► AD-5 ─► AD-6 ─┬─► AD-7 ─► AD-8 ─► AD-10
                                              └─► AD-9 (PROTO-2) ─► AD-8/AD-10 (TF24)
UX-2 (FD oracle) gates every AD-* ; .rds baseline lands at AD-11 (after AD-6+AD-8 green)
```
- **AD-1..AD-2** are the foundation and are **not yet on any branch** despite the epic
  checkboxes — they land first.
- **AD-6 is the first end-to-end proof** (FF16 invasion); it lands before the resident path
  (AD-8) and any TF24 work (AD-9).
- **Stacked diffs** (`AGENTS.md` PR workflow): one PR per issue, each branched on its parent
  (`AD-1`→`AD-2`→…), targeting the parent branch; `git rebase --update-refs` +
  force-with-lease when an underlying branch changes. Tests land with the component they
  cover. Bump the `plant-dev` submodule pointer as each merges.
- **Nothing merges without UX-2 (AD-vs-FD) green.**

---

## 7. Risks and boundaries

- **Stiff TF24f resident coupling at long lifetimes** — the fixed-node replay drifts; gate
  with a clear error driven by the double replay's environment error, never a wrong number
  (Appendix A.2).
- **Zero-height cohort** — the `0·log(0) = NaN` trap; cheap but load-bearing (AD-6).
- **`prepare_strategy()` re-seed** — the primary AD-2 correctness gate; a missed re-run
  silently zeroes a derived-quantity trait's gradient.
- **Windows** — the AD tape linkage needs `Makevars.win`; Linux resolves undefined `Tape`
  symbols at load against globally-loaded odelia (proven by PROTO-3). No linkage blocker on
  Linux.

---

## Appendix A — Deferred / non-blocking (post-v1)

These are correct to leave out of v1; each has a build-per-call or clear-error fallback so
their absence never returns a wrong number.

- **A.1 — Active-twin + tape caching for the SCM runnable (RIF-3).** odelia's `active_solver`
  caching lives on the `Solver`; the SCM-as-runnable can't reuse it directly. An optimizer
  hot-loop would either hand-roll an active-SCM cache on the SCM (no odelia change) or share
  odelia's helper later. v1 builds the active twin per call — correct, just not amortized.
- **A.2 — TF24f resident coupled gradient at long patch lifetimes.** The
  `log_density`↔canopy loop is stiff; the live SCM tames it with adaptive sub-stepping a
  fixed schedule cannot reproduce. Needs adaptive sub-stepping in the replay; until then,
  gated by a clear error.
- **A.3 — Second-order / Hessian (`fwd_adj`).** Out of scope.
- **A.4 — IC sensitivity as a first-class target.** `ad_initial_state()` may start empty;
  seeding the initial size distribution is a genuine target (`make_initial_state` /
  `export_patch_state`) but not v1 scope.
- **A.5 — Adaptive sub-stepping in the replay.** The hardening that would extend A.2 past its
  stiff horizon.
- **A.6 — Moving plant's leaf-level forward-mode AD into odelia.** Stays plant-local; the
  `SuppliedDerivative` edge (AD-9) is the seam, not absorption.

## Appendix B — Notes for implementers

- **`autodiff.md` is slightly ahead-stale:** it documents a `schedule` argument the driver no
  longer takes (§5). Code to `gradient.hpp`, not the doc, until the doc is fixed.
- **The `CanopySystem` demonstrator** (`odelia/inst/include/examples/canopy_system.hpp`) is
  the reference the Patch mirrors for the `Replayable` hooks and the two `set_ode_state`
  overloads — read it before AD-4.
- **Grep-invariant:** no `xad::`, `Tape`, `registerInput`, or `computeJacobian` in plant
  source outside the odelia include path — the "plant writes no XAD" commitment as a CI check.
