# AD implementation design: the general reverse-mode harness (plant × odelia)

Companion to [`ad-touchpoint-catalog.md`](./ad-touchpoint-catalog.md) (the surface survey) and
[`ad-infrastructure-design.md`](./ad-infrastructure-design.md) (the thesis). This document is the
**implementation specification**: for every plant surface the catalog enumerates, it states the
concrete treatment under the committed design — *including the surfaces that do not change* — with
`file:line` anchors so a developer can work each one without re-deriving it.

It is the output of a coordinated design search (reverse-mode-fixed) over both the FF16 core and the
TF24 leaf/soil core at once, plus an independent judge pass. Two search results are load-bearing and
appear throughout:

- **A `20`-line spike** (against real XAD + odelia's `basic_spline`) proved that evaluating the
  fixed-knot cubic at an **active** query point and AD-11's **passive-slope linearisation** give the
  **bit-identical** crown gradient (rel `0`) in the combined resident case. So the crown integral was
  *never* a correctness risk; the active-query `eval(S)` is a **cleanliness** choice (one body, deletes
  the manual slope path), not a fix.
- **The judge caught a convergent bug** shared by every draft: "a frozen input's adjoint flows
  nowhere" is **false** — a passive `AReal` carries `slot_ = INVALID_SLOT`, and
  `Tape::incrementAdjoint` (`odelia/src/Tape.cpp:619`) *throws* `OutOfRange` on it. The
  `supplied_derivative` seam must **skip inactive slots** (§7.4). Corrected here.

---

## 0. Scope, commitment, invariants

**Scope.** One harness delivering exact reverse-mode gradients of emergent SCM metrics with respect to
**30–50 strategy traits and environment (soil) parameters**, for **TF24 resident and mutant**, with
**FF16 and K93 as restrictions of the same code**. Fixed schedule (L0 cohort introductions + L1 RKCK
step times, recorded on a double pass) and **given initial conditions**; the mesh is not
differentiated.

**The commitment (one sentence).** *An `Environment` is a bundle of coupling channels behind one
concept; the harness is written once against that concept and never names a channel, a channel-kind,
or a run-type; the sole way a value becomes frozen `double` is a read from one recording keyed by
`(step, stage)`.*

**Kept true by structure, not convention:**
1. `Patch<T,E>` fails to compile unless `E` satisfies `Coupling` (§6) — a new environment cannot be
   plugged in with a bespoke freeze path.
2. The only producer of a frozen background is `EnvironmentRecording::restore<S>` (§5), which yields
   passive `S`-constants; a **missing** recording is a loud out-of-range read, never a plausible wrong
   number.
3. `plant/ad_value.h` is **deleted**. The one sanctioned narrowing (`xad::value` marshalling into an
   iterative `double` solve, §7) is CI-gated to the `supplied_derivative` argument line; a manifest
   (§11) enumerates the handful of `value()`-reading guards/selectors.

**Invariants (unchanged from the catalog's Part I).**
- **Only `double` crosses R.** Guaranteed structurally: every RcppR6 object lives behind an `XPtr`
  and only method *return values* marshal, all `double`/`List`/`NumericMatrix` (`RcppR6_classes.yml`,
  `RcppR6_support.hpp:102`). Active types are created, used, destroyed inside one C++ call.
- **Resident vs mutant is data-presence, not a mode.** `has_recorded_field()` is a query
  (`odelia/.../ode_interface.hpp:160`), routing recompute-active (resident) vs read-recorded-double
  (mutant). No physiology branch.

---

## 1. Architecture on one page

```
R:  stand_gradient(scm, metrics, traits, feedback)          [only double crosses]
      |  hand-written [[Rcpp::export]] stand_gradient_cpp  (Layer 0)
      v
C++: lift resident SCM<FF16|TF24,Env> --rebind_from<active>--> active SCM        (Layer 1)
     seed traits+soil params via DifferentiationTargets over Patch::ad_parameters() (§7)
     odelia::compute_jacobian(active_solver, targets, EmergentFunctional{metrics}):  (§9)
        record once:  active_solver.reset(); active_solver.run()
          SCM::run() = [introduce cohorts][resize ODE vector][advance_fixed(recorded step times)]  (Layer 7, §5)
             per step:  replay_step()  -> load frozen knot positions (L2) / advance record cursor
             per RK stage: derivs(y, index):
                has_recorded_field()==false (resident): set_ode_state(it, time)  -> recompute env ACTIVE
                has_recorded_field()==true  (mutant):   set_ode_state(it, index) -> restore env FROZEN
             rates: physiology reads env.at(channel,query)->S obliviously;
                    iterative sub-solves (leaf, height_seed) inject partials via supplied_derivative (§7)
        m adjoint sweeps (m = #metrics) over the one Solver-owned tape
        xad::value(...) at the boundary -> double Jacobian
      |
      v
R:  metrics x (traits+params) double matrix, dimnames applied in the thin R wrapper
```

The double model run is the **same code** at `S=double`. The recording is produced by that run (when
`control(save_RK45_cache=TRUE)`); the gradient replays it at `S=active`.

---

## 2. odelia surface consumed (branch `claude/ad-surface`)

Everything here **already exists** and is consumed as-is except one ~2-line change (§7.4).

| odelia surface | file | role | change |
|---|---|---|---|
| `Replayable` concept — `record_stage(int)`, `record_ode_step()`, `replay_step()`, `has_recorded_field()` | `ode_interface.hpp:42` | the record/replay hook set; `if constexpr`-gated, zero-cost if absent | **none** (doc-comment may point at the recording) |
| `derivs(obj,y,dydt,time,index)` dispatch | `ode_interface.hpp:156` | routes recompute (time overload) vs recorded-read (index overload) on `has_recorded_field()` | **none** |
| `compute_jacobian(solver, DifferentiationTargets, functional)` | `gradient.hpp:45` | seed through `ad_parameters()`/`ad_initial_state()` pointers → `reset()`→`run()` → record once + m adjoint sweeps on the Solver-owned tape; `xad::value` at the boundary; `tape_guard` on exit | **none** |
| `DifferentiationTargets{params, ics, values}` | `gradient.hpp:17` | the seed bundle (params-then-ics order) | **none** |
| `rebind<S2>` / `rebind_from<S2>()` | System contract | double→active lift (values only) | **none** (plant provides them, §1/§3) |
| `basic_interpolator<S>` / `basic_spline<S>` | `interpolator.hpp`, `spline.hpp:238` | positions `double`, values `S`; `construct` adaptive-double, `init(knots,values)` active-on-frozen-knots; `operator()(double)` value-query, `deriv(double)` passive slope | **optional add** `S operator()(S)` active-query (cleanliness, §4.3) |
| `supplied_derivative(tape, value, inputs, partials)` | `supplied_derivative.hpp:46` | single value, many `double` partials, via `CheckpointCallback`; System-invoked | **~2-line fix**: skip inputs with `getSlot()==INVALID_SLOT` (§7.4) |
| `Solver<System>` owns `unique_ptr<Tape<double>> tape` + cached `active_solver` | `ode_solver.hpp:242,246` | one tape, reused across m rows and across calls | **none** |
| `advance_fixed(times)` | `ode_solver_internal.hpp:172` | fixed-schedule replay | **none** |
| `set_state_from_system()` → `resize()` | `ode_solver_internal.hpp:145,333` | grows ODE vectors at introductions; move-ctor preserves `slot_` so the tape survives | **none** |
| `xad::Tape<double>::getActive()` | `XAD/Tape.hpp:102` (thread-active) | how a System reaches the Solver-owned tape from inside `ode_rates` (co-design gap B) | **none** — read-only use |

**odelia never learns** cohorts, traits, soil, or "environment": the recording is plant-owned (§5), so
design decision 4 holds structurally.

---

## 3. The scalar skeleton (catalog Layer 1) — every type

Uniform `value_type = S` threaded by the *existing* `<T,E>` templates. The `_`+alias idiom is applied
**only to the scalar-carrying leaves** (Strategy, Environment, Parameters, Internals); the hierarchy
(`Individual`, `Node`, `Species`, `Patch`, `SCM`) is already `<T,E>` and derives `value_type` from
`T`, so no alias of its own is needed — RcppR6 binds the `<…<double>,…>` instantiation, the gradient
TU instantiates `<…<active>,…>`.

| Type | file | current state | treatment | change |
|---|---|---|---|---|
| `Internals_<S>` | `internals.h:14` | already `template<class S=double>`, four `vector<S>` (states/rates/auxs/consumption_rates), `using Internals = Internals_<double>` | **keep verbatim** — this is the root storage; the `aux` vector *must* be `S` (the height→aux→rate trap, §H) | none (AD-1 correct) |
| `Individual<T,E>` | `individual.h:16` | `value_type = T::value_type`; state/rate/aux accessors `S`; `Internals_<value_type> vars` | keep the `value_type` and templated accessors; **collapse the `_ad` twins** (`establishment_probability`/`_ad`, `growth_rate_given_height`/`_ad`) to one `S`-templated body each; the double R/stochastic boundary calls `xad::value(...)` at the *call site* (a manifest-listed read), not via an in-body narrowing | de-twin |
| `Node<T,E>` | `node.h:16` | `value_type`; `log_density`/`density`/`offspring_produced_survival_weighted` are `value_type`; birth stamps (`patch_density_at_birth`, `pr_patch_survival_at_birth`, `node_introduction_time`) are `double` | keep `value_type` state; **collapse** `compute_competition`/`compute_competition_ad`, `get_density`/`get_density_ad`, `growth_rate_gradient`/`growth_rate_gradient_active` (Layer 6, §L6) into one templated body each; birth stamps stay `double` (they are recorded schedule data, not differentiated) | de-twin |
| `Species<T,E>` / `SpeciesBase` | `species.h:27`, `species_base.h:46` | `value_type`; ODE iterator seam templated (`set_ode_state<It>`); `census<Psi>` templated reduction; `compute_competition`/`compute_competition_ad` twin; `net_reproduction_ratio_by_node_weighted` returns `vector<value_type>`; `birth_rate_scale` seed | keep the templated `census<Psi>` (one reduction for LAI/biomass/basal-area) and the `<It>` iterator seam; **collapse** the `compute_competition` twin (one templated trapezium); keep `birth_rate_scale`/`ad_birth_rate()` as the birth-rate IC leaf | de-twin |
| `Patch<T,E>` | `patch.h:22` | `using value_type = double` today; owns `Solver<patch_type>`; the replay/record members | **`value_type = typename T::value_type`**; add `static_assert(Coupling<E>)` (§6); host the `EnvironmentRecording<E_double>` member (§5) and the two generalized `set_ode_state` overloads (§5.3); the four `Replayable` hooks delegate to the recording | core edits |
| `SCM<T,E>` | `scm.h` | double; owns `Solver<patch_type>:133`; `run`/`run_mutant`; `refine_schedule` | `value_type` + `rebind` so it is odelia's runnable; `run()` keeps the `[introduce][resize][advance_fixed]` loop (Layer 7, §5); `run_mutant` becomes "populate the recording's field slice + replay" (§7 witnesses) | edits |
| `Parameters<T,E>` | `parameters.h` | POD config, double | stays `double` **except** `initial_state` seeds `S` state for an IC gradient (out of v1's fixed-IC scope, but the seam is `ad_initial_state()`) | none in v1 |
| `Strategy<E>` base | `strategy.h` | CRTP-ish base | gains nothing structural; the scalar lives on the concrete strategies (§4) | none |

**The single most pervasive item (unchanged in shape).** Every `set_ode_state`/`ode_state`/`ode_rates`
across Individual/Node/Species/Patch/Environment is templated on the iterator `It`
(`individual.h`, `node.h:93`, `species_base.h`), so the ODE-serialisation surface flows at whatever
scalar the ODE vector holds. This is the Cluster-1 "one iteration" the catalog wanted; AD-11 already
did it — **keep it**. Do **not** route through odelia's `double`-only free `set_ode_state` helpers.

---

## 4. Per-strategy physiology (catalog Layer 2) — every model

One `template<class S>` body per method; `S=double` is production, bit-identical (guarded by the
reference-comparison test). No `_active` twin, no `if constexpr(is_same_v<S,double>)` in physiology.

### 4.1 K93 (`k93_strategy.h/.cpp`) — the free restriction
Closed-form `size_dt`/`fecundity_dt`/`mortality_dt` reading `cumulative_basal_area = -log(light)/k_I`.
Template the class on `S`; the two kinks (`if(growth<0)growth=0` `:117`, `(mu>0)?mu:0` `:139`) are
Cluster-7 selectors (§11). No quadrature, no root-find, no leaf. **Falls out for free once the
skeleton templates.** The environment is a light field only (`ode_size()==0`).

### 4.2 FF16 (`ff16_strategy.h/.cpp`) — the core witness
Already `FF16_Strategy_<S>` with `FF16_Pars_<S>` (`ff16_strategy.h:19,141`) and per-method `S`
physiology (`area_leaf`, the mass cascade `mass_leaf`/`area_sapwood`/…/`net_mass_production_dt`). Keep
that. Specific surfaces:

| Surface | file | treatment |
|---|---|---|
| `FF16_Pars_<S>` `field_ptrs()`/`field_names()` | `ff16_strategy.h:107,114` | keep as the column-order contract; **single-source** the two 32-entry lists via an X-macro `.def` (§7.3) so they cannot drift/transpose |
| mass cascade (`area_leaf`…`net_mass_production_dt`) | `ff16_strategy.cpp` | keep the single `S` bodies; delete the never-referenced `ff16_production_kernel.h` composite (`deep_crown_replay`, §4.4) |
| `assimilation` dispatcher + `assimilation_fn` member ptr | `ff16_strategy.h:267,294` | keep — a per-strategy model choice bound in `prepare_strategy`; it selects the crown model, not an AD capability. **BUT**: `assimilation_average_light` (MeanLight) currently runs the integral in `double` (`ff16_strategy.cpp:211`) — must become one `S` body like `assimilation_deep_crown`, or MeanLight (TF24's default) silently drops the crown derivative |
| `assimilation_deep_crown` crown integral | `ff16_strategy.cpp:160` | **collapse** the `if constexpr` fork + `integrate_ad` + the manual light linearisation (`get_environment_deriv_at_height`, `lv+ld*(z-zv)`) into one `QK::integrate<S>` differentiating through the active bound (§4.4). The spike proved the value is identical either way; this is the one-body cleanup |
| `compute_competition_by_ratio` | `ff16_strategy.h:416` | **collapse** the `if constexpr(is_same_v)` fork; it exists only because `CanopyShape` is not templated — template the profile (§4.4) and the fork disappears |
| `height_seed` | `ff16_strategy.cpp:588` | keep the IFT reattachment but route it through the `supplied_derivative` seam (§7); the current inline `g - ad_value(g)` trick is deleted with `ad_value.h` |
| `census_biomass`/`census_basal_area` | `ff16_strategy.h:442` | keep — the per-plant `psi` kernels the `census<Psi>` reduction sums |
| virtuals (`net_mass_production_dt`, `fraction_allocation_reproduction`) | `ff16_strategy.h:320,343` | keep — templating the class, not the method (a virtual on a templated class survives per-instantiation); pre-existing |
| frozen-by-design `r_l = 39.27/0.1978791`, `r_b = 2·r_s` | `ff16_strategy.h:42` | **no change** — `d(r_l)/d(lma)=0` by construction is the model's intended parameterisation; a caveat for interpreting gradients, documented, not a bug |

### 4.3 TF24 / TF24f (`tf24_strategy.h/.cpp`, `tf24f_strategy.h`) — the mixed-scalar witness
`TF24_Strategy_<S>` = `S` pars + `S` mass cascade + a **`double` `Leaf` sub-model**. This is the
catalog's Part V "leaf stays double" made concrete.

- The `Leaf leaf` member (`tf24_strategy.h:338`) stays **`double`** — never templated on `S`. The
  ~1500-line `leaf_model.cpp` (golden-section + two TOMS748 root-finds + four fixed-knot C2 splines)
  never goes active.
- The `S` trait feeds the double leaf as `xad::value(trait)` — the **input-marshalling half of the
  `supplied_derivative` seam** (§7), *not* a freeze: the derivative is re-attached analytically in the
  same expression. This is the single sanctioned narrowing, CI-whitelisted.
- The `aux` store is `Internals_<S>` (§H): `competition_effect`/`height_inverse` are recomputed from
  height and read back into the rate path; a `double` aux drops the height derivative.
- Init-derived pars (`c`/`b`/`psi_crit`/`jmax_25`) re-derive in `prepare_strategy` under the seed.
- `integrate_vector` over QK nodes → the crown treatment is Cluster-4 (§4.4), same as FF16.
- **TF24f**: adds one tracked ODE state `opt_root_psi_state` whose rate is `k_acclim · dprofit_dψ` —
  an analytic derivative placed on the tape as a rate (`tf24f_strategy.cpp:37`); the golden-section
  optimiser runs only at birth (`set_initial_states`). Structurally cleaner for AD than TF24. Same
  leaf-double + injected-partials treatment; one extra active state slot.
- **`ShadingModel`** (`canopy_shape.h:47`): six members. **TF24 defaults to MeanLight**, not
  deep-crown — so §4.2's MeanLight-must-be-`S` note is load-bearing for TF24. FlatTopBox/PPA-hard do
  not run (drop); the rest are C1 and are the Cluster-4 crown treatment with the mode's smooth
  function bound at `prepare_strategy`.

### 4.4 The crown quadrature + canopy shape (catalog Layer 4, Cluster 4)
| Surface | file | treatment |
|---|---|---|
| `QK::integrate` | `qk.h:26` | **one** `template<class S,class F> S integrate(F, S a, S b)`; delete `integrate_ad` (`qk.h:31` — the second GK loop). Fixed rule, active bound tapes exactly (half-length Jacobian included). `S=double` reproduces the Kronrod result bit-for-bit |
| `CanopyShape` | `canopy_shape.h:100` | **template the profile on `S`** — `q`/`Q`/`leaf_area_above` one body each; delete the `q_active`/`leaf_area_above_active` twins (`:141,162`) and the runtime `if(leaf_above_==&leaf_above_deep)` capability check. `eta` stays a `double` member unless seeded (a seeded `eta` is a documented extension). The `pow_eta_`/`leaf_above_` function-pointer dispatch (mode selection) stays — it is a model choice bound once, not a scalar branch |
| light spline value read | `resource_spline.h:100` | `get_value_at_height` returns `S` (value-query, active-in-values) — **keep**; delete `get_deriv_at_height` (`:128`, the passive-slope linearisation), superseded by the one-body active-bound integral / optional `eval(S)` (§2). The `max(0,·)` floor (`:120`) is a Cluster-7 selector (§11) |
| `QAG` adaptive | `qag.h:85` | **no change / off every graph** — `max_iter=1` everywhere (fixed rule in practice), never taped. Its interval-replay API is dormant legacy; do not wire it |
| `deep_crown_replay` + composite kernel | `ff16_production_kernel.h:111` | **delete** — unreferenced by production `FF16_Strategy`; the catalog's "parallel near-copy" that drops `dA/dheight` |

---

## 5. The recording — `EnvironmentRecording<E_double>` (catalog Layer 7, the crux artifact)

The single value by which any environment quantity becomes frozen. Replaces AD-11's three parallel
`Patch` members (`step_history`, `environment_history`, `knot_history`) and its bespoke
`cache_RK45_step`/`load_ode_step`.

### 5.1 Type
```cpp
// plant/environment_recording.h  (the one new plant name)
template <class E>                       // E = environment_type_<double>; only double is stored (R invariant)
struct EnvironmentRecording {
  std::vector<double> step_times;                    // L1: accepted-step times; step_times[0]==0
  std::vector<std::vector<E>> stages;                // L3: whole-env snapshot [step][RK stage]
  std::vector<std::vector<double>> knots;            // L2: field knot positions per step

  bool empty() const { return stages.empty(); }
  void clear() { step_times = {0.0}; stages.clear(); knots.clear(); }

  int step_index(double t, int hint) const;          // fast sequential hint, else search; last-step clamp
  const std::vector<double>& positions(int k) const  // L2 read (resident recompute)
    { return knots[std::min<std::size_t>(k, knots.size() - 1)]; }
  template <class S> environment_type_<S> restore(int k, int stage) const   // L3 read (mutant)
    { return stages[std::min<std::size_t>(k, stages.size()-1)][stage].template rebind_from<S>(); }
};
```
- **Whole-object snapshot** (`stages[k][s]` is a copy of the *entire* `E<double>`) so that *every*
  channel — canopy spline VALUES, TF24 soil `Internals` STATE, driver caches — is captured by
  construction. Adding a soil field freezes it for free; this is what drives the freeze-audit surface
  to **one** site (the `restore`), and is why we reject a hand-enumerated minimal-POD snapshot.
- **Cadence (the "what is saved when"):** **L2 positions per accepted step** (`knots`); **L3 values
  per RK substage** (`stages[k][0..5]`). Positions only remove the adaptive branching (one set per
  step is within tolerance); values must be the exact quantity each of the 6 stages consumed.
- **Lifetime/ownership:** a `private` `Patch` member, cleared in `reset()`, populated on the resident
  `double` run, read-only on any active pass. **Not part of the ODE vector**, so `resize()` never
  touches it. `Patch::rebind_from<S>` copies it verbatim (it is `double`), so the active twin shares
  the resident's recording with no lift.

### 5.2 Production (the `Replayable` hooks, catalog Layer 7)
```cpp
void Patch<T,E>::record_stage(int stage) {                 // per RK stage, double pass, if save_RK45_cache
  if (stage == 0) { stage_scratch_.clear();
                    if constexpr (requires(const E& e){ e.light_knots(); }) knot_scratch_ = environment.light_knots(); }
  stage_scratch_.push_back(environment);                   // deep-copy whole E (the storage cost, §14)
}
void Patch<T,E>::record_ode_step() {                       // per accepted step
  rec_.step_times.push_back(time());
  rec_.stages.push_back(std::move(stage_scratch_));
  rec_.knots.push_back(std::move(knot_scratch_));
}
void Patch<T,E>::replay_step() {                           // per step, active pass
  if (!use_cached_environment && !replay_knots) return;
  cur_step_ = rec_.step_index(time(), cur_step_);
  if (replay_knots) current_knots_ = rec_.positions(cur_step_);   // resident loads frozen positions
}
bool Patch<T,E>::has_recorded_field() const { return use_cached_environment; }   // mutant only
```
`record_stage`/`record_ode_step` are the odelia-signalled cadence (called from `ode_step.hpp:104…148`
and `ode_solver_internal.hpp:312`). `knot_scratch_` is guarded so a canopy-less environment records no
positions at zero cost. This is the catalog's "one recording, two slices": the resident run records
*both* L2 (for its own gradient) and L3 (for a future mutant).

### 5.3 The two generalized `set_ode_state` overloads (the resident/mutant seam)
Routed by odelia's `derivs` on `has_recorded_field()`; **all channels** go through them because they
defer to the Environment (a canopy+soil environment and a canopy-only one take the same path).
```cpp
// (it, double time): recompute ALL channels ACTIVE  — resident (K93/FF16/TF24 resident)
template<class It> It Patch<T,E>::set_ode_state(It it, double time) {
  for (auto& s : species) it = s.set_ode_state(it);        // cohorts (growing block)
  it = environment.set_ode_state(it);                      // env State slots (soil), ACTIVE; no-op if ode_size()==0
  environment.time = time;
  check_finite_ode_state();                                // §14 loud drift gate lives here
  environment.set_field_active(competition_fn(), current_knots_);  // Field: active values on frozen knots
  environment_ptr = &environment;
  compute_rates();                                         // physiology + environment.compute_state_rates(resource_depletion)
  return it;
}
// (it, int stage): restore ALL channels FROZEN  — mutant (K93/FF16/TF24 mutant)
template<class It> It Patch<T,E>::set_ode_state(It it, int stage) {
  for (auto& s : species) it = s.set_ode_state(it);        // cohorts still ACTIVE (the mutant's own)
  env_scratch_ = rec_.template restore<value_type>(cur_step_, stage);   // frozen double -> passive S
  environment_ptr = &env_scratch_;
  environment.time = env_scratch_.time;
  for (std::size_t i = 0; i < env_scratch_.ode_size(); ++i) ++it;       // skip env's own slots (frozen, not stepped)
  compute_rates();
  return it;
}
```
The resident self-shading rides the `(it,time)` overload with `replay_knots=true`,
`has_recorded_field()==false`. `set_field_active(f, knots)` is scalar-agnostic (the interpolator takes
placement decisions in `xad::value`, `interpolator.hpp:66`; `knots` empty → adaptive build on the
double pass, `knots` present → `init` on frozen knots with active values — `resource_spline.h:69`
`compute_environment_fixed`). This **deletes** AD-11's `if constexpr(is_same_v<value_type,double>)`
fork in `compute_environment` (`patch.h:699`).

### 5.4 `set_mutant` / `set_resident_replay`
Two setters choose the read slice (catalog Layer 7, `patch.h:242,261`): `set_mutant()` sets
`use_cached_environment=true` (L3 read); `set_resident_replay()` sets `replay_knots=true`, leaves
`use_cached_environment=false` (L2 recompute). `is_mutant_run` still gates self-competition suppression
(`patch.h:427,438`) — a *model* concern (a rare mutant does not compete with itself), orthogonal to the
replay slice.

---

## 6. The `Coupling` concept (catalog Layer 3, the environments)

The environment is not a light spline with soil bolted on; it is a bundle of channels. The concept is
the compile-time contract every environment satisfies; `Patch<T,E>` `static_assert`s it.

```cpp
// plant/coupling.h
template <class E>
concept Coupling = requires(E e, const E ce, typename E::Query q, typename E::CompetitionFn f,
                            const std::vector<double>& knots,
                            const std::vector<double>& depletion,
                            odelia::ode::const_iterator cit, odelia::ode::iterator it) {
  typename E::value_type;                                        // S
  typename E::Query;                                             // {Light,z} | {SoilPsi,layer} — oblivious read key
  { ce.at(q) }             -> std::same_as<typename E::value_type>;  // THE physiology read (R2)
  e.set_field_active(f, knots);                                  // Field: recompute active on frozen knots
  { ce.light_knots() }     -> std::convertible_to<std::vector<double>>;  // L2 position capture
  { ce.ode_size() }        -> std::convertible_to<std::size_t>;  // State width (0 for FF16/K93)
  { e.set_ode_state(cit) } -> std::same_as<odelia::ode::const_iterator>;
  { ce.ode_state(it) }     -> std::same_as<odelia::ode::iterator>;
  { ce.ode_rates(it) }     -> std::same_as<odelia::ode::iterator>;
  e.compute_state_rates(depletion);                              // plant->soil depletion; no-op if ode_size()==0
  { ce.template rebind_from<double>() };                         // the whole-object freeze (recording)
};
```
(Dropped from the search draft: an `enum ChannelKind` — decoration; *kind* is realised by
`ode_size()>0`, not a stored tag.)

| Environment | file | channels | `ode_size()` | notes |
|---|---|---|---|---|
| `FF16_Environment_<S>` | `ff16_environment.h:15` | canopy light field | 0 | `at({Light,z}) = step_light(spline)`; PPA branch is a Cluster-7 selector (`floor`, `ff16_environment.h:133`) |
| `K93_Environment_<S>` | `k93_environment.h:12` | canopy light field | 0 | raw `get_value_at_height`; relies on the spline `max(0,·)` floor |
| `TF24_Environment_<S>` | `tf24_environment.h:16` | canopy light field **+ soil-water state** | `soil_number_of_depths + 4` | `compute_state_rates` = the bucket mass balance (`:213`); `at({SoilPsi,layer})` via `psi_from_soil_moist` (`:272`, closed-form, **not** an adaptive component — so **no L2 for soil**); `resource_depletion` is the plant→soil channel |

**Soil is state, not a field.** Its grid is fixed and its constitutive curves are closed-form, so it
has **no L2** (no recorded adaptive positions). Resident TF24 → soil is active integrated state
(coupled via `resource_depletion`, §14 stiff/gated); mutant TF24 → soil rides L3 as recorded frozen
values in the whole-object snapshot. The `mutable` exact-compare soil caches (`psi_soil_cache_`,
`tf24_environment.h:111`) copy with the snapshot and are read `double` on the mutant path — safe there;
on the resident (active) path they are a documented hazard the stiff-case gate covers.

---

## 7. Iterative solves + the injected-derivative seam (catalog Layer 5, Cluster 5)

One seam for every data-dependent solve: solve in `double`, register the result, inject analytic
partials. `S=double` skips the injection.

### 7.1 The seam
```cpp
// inside ode_rates, S active. Reaches the Solver-owned tape via XAD's thread-active tape.
auto* tape = xad::Tape<double>::getActive();
double y0 = solve_in_double(...);                              // uniroot / golden-section / TOMS748
std::vector<S*>     inputs;                                    // the ACTIVE quantities y depends on
std::vector<double> partials;                                 // analytic dy/d(input)
// ... fill inputs/partials ...
S y = odelia::ode::supplied_derivative(*tape, y0, inputs, partials);   // §7.4 skips inactive slots
```

### 7.2 `height_seed` (FF16 + TF24, `ff16_strategy.cpp:588`, `tf24_strategy.cpp:720`)
Root `h*` of `mass_live_given_height(h) = omega`. IFT: `dh*/dθ = -(∂g/∂θ)/(∂g/∂h)`, `∂g/∂h` a
`double` central difference, `∂g/∂θ` per seeded trait (the `lma` dependence via
`mass_leaf = area_leaf·lma` is the A-vs-B divergence the catalog names — this seam makes it one tested
site). Runs at `reset()`/`prepare_strategy`, inside the recorded region.

### 7.3 The leaf optimiser (TF24/TF24f, `leaf_model.cpp`)
`profit*` from golden-section over collar-ψ (fixed rule) + two TOMS748 root-finds. Envelope theorem:
`d(profit*)/d(input) = ∂profit/∂input` at fixed ψ*. Inputs = `{seeded traits, light, height, soil ψ}`.
`∂profit/∂ψ` (`leaf_model.cpp:900` `dprofit_droot_collar_psi`) is the **extra partial the TF24
resident needs** (soil ψ active) and the mutant does not — but the call is identical; the mutant's ψ
is a passive constant and §7.4 drops it. The other partials (`∂profit/∂vcmax25` etc.,
`leaf_model.cpp:980`) mostly exist; the full `∂profit/∂θ` set is the substance of the TF24 port.

### 7.4 The seam fix (the bug the judge caught)
A passive `AReal` (a frozen `restore<S>` value, or any `S=double` input) has
`slot_ = INVALID_SLOT = (unsigned)-1`. `supplied_derivative` (`supplied_derivative.hpp:59`) captures
`getSlot()` for every input; the reverse sweep calls `Tape::incrementAdjoint(slot,…)`
(`src/Tape.cpp:619`), which **throws `OutOfRange`** when `slot >= derivatives_.size()`. So a frozen
input does **not** silently contribute zero — it crashes the sweep (fatal on the TF24-mutant witness,
where light *and* ψ are frozen). **Fix:** `supplied_derivative` skips inputs with
`getSlot()==INVALID_SLOT` (a ~2-line guard in odelia). This is a branch on **slot-activity**, not on
run-type — physiology stays oblivious (R2), the seam stays the single sanctioned site. Must be
FD-verified on the TF24-mutant witness (§15 gate 2).

### 7.5 Out of v1
`resource_compensation_point` (`individual.h:162`) is an R-facing diagnostic root-find, off the run
graph — no AD in v1.

---

## 8. The nested characteristic-equation derivative (catalog Layer 6)

`Node::growth_rate_gradient` (`node.h:117,227`) finite-differences `d(growth)/d(height)` and feeds it
into `log_density_dt` (`node.h:161`). It is part of the ODE right-hand side, not an output metric, so
under a trait gradient it must stay **active in the trait**. **Collapse** AD-11's
`growth_rate_gradient` + `growth_rate_gradient_active` twin into one `template` body that:
- uses a **per-call** active scratch `Individual` (not `thread_local` — an active scratch persisted
  across gradient calls reads stale tape slots and returns NaN; the copy is cheap next to the sweep);
- honours **both** FD schemes — plain `gradient_fd` *and* `gradient_richardson` (the AD-11 active twin
  silently ignored Richardson, computing a *different* scheme than the double model when
  `node_gradient_richardson` is on — a real divergence this fixes).

`S=double` reproduces the current `thread_local` fast path bit-for-bit.

---

## 9. The differentiation targets, functional, and driver (catalog Layer 0 + §6.3 of the design)

### 9.1 Seeding surface (30–50 traits + soil params)
`Patch::ad_parameters()` (`patch.h:89`) concatenates, species-major: each species'
`strategy->ad_parameters()` = `FF16_Pars_/TF24_Pars_::field_ptrs()`, **then** the environment's soil
parameter pointers (`TF24_Environment_<S>::param_ptrs()` — `K_sat`, `a_psi`, `n_psi`, …). Reverse mode
makes 30–50 inputs free (still m≈4–6 sweeps). `ad_initial_state()` returns the birth-rate IC leaf(s);
fixed ICs otherwise. The name↔pointer list is **single-sourced by X-macro** so a Jacobian column
cannot transpose:
```cpp
#define FF16_AD_FIELDS(X) X(lma) X(rho) X(hmat) /* …32… */ X(k_I)
std::vector<S*>          field_ptrs()  { return { FF16_AD_FIELDS(PTR)  }; }  // #define PTR(f) &pars.f,
static std::vector<std::string> field_names(){ return { FF16_AD_FIELDS(NAME) }; }  // #define NAME(f) #f,
static_assert(count(FF16_AD_FIELDS) == /* n */);
```
`compute_jacobian` seeds by writing through these pointers **before** `reset()` (`gradient.hpp:88`), so
they must point at members `reset()` preserves and `prepare_strategy` re-derives under the seed
(`ad_prepare()`, `patch.h:114`).

### 9.2 `EmergentFunctional` — the pure reduction
Unchanged in shape from AD-11 (`emergent_functional.h`): `codomain()` = metric count (sizes the sweep,
avoids a spare solve); `operator()(solver)` reads native replayed state and returns `vector<S>`. It
**drives nothing** (the driver owns `reset()`/`run()`). Metrics reuse the model's own scalar-templated
reductions: **LAI/biomass/basal-area** via `Species::census<Psi>` with the FF16/TF24 `census_*` psi
kernels; **offspring_production**/**R0** via `net_reproduction_ratio_by_node_weighted`; the birth-rate
axis via the `birth_rate_scale` leaf. Adding a metric is one `psi` kernel; odelia is untouched.

### 9.3 The R boundary (catalog Layer 0)
One hand-written `[[Rcpp::export]] stand_gradient_cpp(SEXP scm, …)` (`src/stand_gradient.cpp`): unwrap
the RcppR6 pointer (no serialisation), resolve trait/param names → `DifferentiationTargets` columns,
dispatch strategy (`FF16`/`TF24`/`K93`) and feedback (resident/mutant) **in C++**, call
`compute_jacobian`, return a `double` matrix. A **dispatch table** replaces AD-11's three open-coded
`if(strategy=="FF16")` blocks (`stand_gradient.cpp:207,223,240`) so a strategy is a table row.
Regeneration (`compileAttributes`, `RcppR6::RcppR6()`, `Makefile:16`) is unchanged; a free function
needs no yml edit. Dimnames (metrics × traits; species by integer index — there are no species names)
are applied in the thin R wrapper `R/stand_gradient.R`.

### 9.4 The tape (catalog Layer 0 invariant)
One `Solver`-owned `unique_ptr<Tape<double>>` (`ode_solver.hpp:246`), created once, `activate()`d
inside `compute_jacobian`, swept m times, `tape_guard` deactivates on every exit. Estimated peak
~0.5–4 GB for a 50-yr FF16 resident run (fits workstation RAM; the cohort-introduction boundary is a
*reserved, inactive* `CheckpointCallback` seam if a measured tape ever exceeds budget). Only
`xad::value` at the boundary crosses to R.

---

## 10. The five witnesses, end to end

| Witness | Environment channels | `set_ode_state` overload | Recording read | Seam |
|---|---|---|---|---|
| **K93 resident** | light field | `(it,time)`, `replay_knots` | L2 positions → recompute active | none (closed-form) |
| **K93 mutant** | light field | `(it,stage)` | L3 `restore<S>` (field only) | none |
| **FF16 resident** | light field | `(it,time)`, `replay_knots` | L2 → active self-shading on frozen knots | `height_seed` |
| **FF16 mutant** | light field | `(it,stage)` | L3 `restore<S>` | `height_seed` (active in traits; light frozen) |
| **TF24 mutant** | light field + soil state | `(it,stage)` | L3 `restore<S>` (light **and** soil, whole-object) | leaf; light+ψ frozen → §7.4 drops them, no branch |
| **TF24 resident** | light field + soil state | `(it,time)`, `replay_knots` | L2 positions; soil integrated active from the ODE vector | leaf **incl `∂profit/∂ψ`** live; §14 drift gate |

All five are the same code; they differ only in which channels the environment has (`ode_size()`),
which recording slice `set_ode_state` reads, and which seam partials are live.

---

## 11. The freeze rule + kink manifest (catalog Cluster 2 + Cluster 7)

- **Freeze rule (structural).** `plant/ad_value.h` **deleted**. The only narrowings that compile: (a)
  `restore<S>` (recorded read), (b) `xad::value` on a `supplied_derivative` argument line (§7), (c) the
  final `xad::value` in `compute_jacobian`. CI greps `value(`/`xad::value(` and fails on any hit
  outside (b), the R-boundary TU, and the manifest.
- **Kink manifest (a checked-in table).** The enumerable guards/selectors that *read* a passive value
  for control flow, each classified + tested: PPA layer `floor` (`ff16_environment.h:133`,
  selector, zero derivative); `max(0,spline)` resource floor (`resource_spline.h:120`, selector); K93
  `growth<0→0`, `mu>0?mu:0` (`k93_strategy.cpp:117,139`, kinks — documented subgradient); TF24 soil
  positivity resets (`tf24_environment.h:248`, guards, off the operating domain); `util::is_finite`/
  `util::stop` hot-path guards (`species.h:208`, `patch.h:355`, throw paths). A new `value()` site fails
  CI until it is classified here.

---

## 12. What is deleted

`plant/ad_value.h`; `plant/adaptive_interpolator.h` (route `ResourceSpline` to odelia's
`basic_interpolator`); every `_ad`/`_active` twin (`compute_competition_ad` ×3, `get_density_ad`,
`establishment_probability_ad`, `growth_rate_given_height_ad`, `growth_rate_gradient_active`,
`q_active`, `leaf_area_above_active`, `QK::integrate_ad`); every `if constexpr(is_same_v<S,double>)`
freeze-fork (`node.h:160`, `resource_spline.h:228`, `patch.h:699`, `ff16_strategy.h:418`,
`ff16_strategy.cpp:170,613`); `get_environment_deriv_at_height` + the manual light linearisation;
`ff16_production_kernel.h` (`deep_crown_replay` + composite); AD-11's `Patch` `step_history`/
`environment_history`/`knot_history`/`environment_cache`/`idx` (folded into `EnvironmentRecording`);
the three open-coded strategy `if`-blocks in `stand_gradient.cpp` (→ dispatch table).

---

## 13. What is deferred / gated (not fixed here)

- **TF24 resident stiffness.** Soil is active coupled state on a **fixed** schedule; the fixed step
  comb can drift on the stiff soil↔canopy trajectory at long horizons (catalog §9, X.7). **Accepted.**
  Gated by a **loud runtime drift error** driven by the double replay's environment error
  (`check_finite_ode_state`, `patch.h:355`, extended with a drift check), never a wrong number. The
  fix (adaptive sub-step replay) is explicitly out of scope.
- **The mesh derivative.** `d(schedule)/d(trait)` and `d(step-placement)/d(trait)` are **not**
  computed — the gradient is exact *at the resolved mesh*. Locked. (The RKCK controller places steps
  continuously in the trait — `ode_control.hpp:88` — so the frozen-mesh residual is
  integration-tolerance-bounded, small but nonzero; it is reported, not differentiated.)
- **IC gradients** beyond the birth-rate leaf; **second-order/Hessian**; **stochastic engine** (shares
  the hierarchy — the `S`-templating must keep its `double` path compiling, but it is never
  differentiated).

---

## 14. Storage cost (honest arithmetic)

Whole-object per-substage snapshots: `E_TF24` ≈ light spline (~17 knots × coeff arrays) + soil
`Internals` (~30 doubles) + `psi_soil_cache_` + driver caches ≈ 250–400 doubles ≈ 2–3 KB/snapshot; 6
stages × ~1–3 k stiff steps ≈ **~30 MB/patch** — plus a deep-copy of the `tk::spline` coefficient
arrays *every stage* (the real cost is the per-stage copy, not the resting footprint). Acceptable for
one patch × one gradient run. If a **population** of patches or a 10× horizon ever binds RAM, cope by
switching the recording payload to a minimal POD `{knots, values, soil_state, time}` **behind the
unchanged `EnvironmentRecording` interface** — a reversible, type-local retrofit that reopens the
freeze audit and so is not the default.

---

## 15. Build order + the two gates

Mechanism-first (catalog Part III); FF16 first as the cheapest full witness, then TF24.

0. **Skeleton + enforcement scaffold:** `value_type=S` through Patch/SCM; delete `ad_value.h`; stand up
   the kink manifest + CI grep (so nothing regresses into twins). Bit-identical `S=double` guarded by
   the reference-comparison test.
1. **`EnvironmentRecording` + the `Coupling` concept + the two `set_ode_state` overloads;** route
   `ResourceSpline` through odelia's interpolator. FF16 environment (field only).
2. **`QK::integrate<S>` + templated `CanopyShape`;** crown differentiates through the active bound;
   delete `integrate_ad`, `deep_crown_replay`, the linearisation.
3. **`growth_rate_gradient` one body** (both FD schemes, per-call scratch).
4. **`height_seed` via `supplied_derivative`** (+ the §7.4 slot-filter fix in odelia).
5. **Seeding** (X-macro single-source, 32 FF16 fields) + **`stand_gradient_cpp`** dispatch table +
   thin R wrapper.
6. **FF16 verify** (gate below), then **TF24**: `TF24_Strategy_<S>` mixed-scalar (double `Leaf`,
   `Internals_<S>` aux), `TF24_Environment_<S>` soil state + `param_ptrs()`, the leaf `∂profit/∂{θ,ψ}`
   partials, soil-in-recording (rides the whole-object snapshot), MeanLight-as-`S`.

**Gate 1 (pivotal, before relying on any SCM gradient):** an active ≥2-introduction run's reverse
gradient matches finite differences — the growing-dimension tape-survives-`resize()` question. The
mechanism is structurally sound (XAD's move-ctor preserves `slot_`, new cohort ICs are taped
intermediates of the active stand) and AD-11's birth-rate axis already demonstrates it, but this is the
one claim to *execute* before building on it.

**Gate 2:** the §7.4 seam slot-filter on the TF24-mutant witness (light+ψ frozen) — no `OutOfRange`,
gradient FD-matches to ~1e-4.

**Verification discipline (replacing AD-11's 15% bracket).** Resident and mutant axes FD-verified **at
the fixed mesh** to ~1e-4 across all 30–50 inputs; the mesh residual is reported as a diagnostic, not
excused into a loose tolerance. The regression baseline is a real oracle (the validated spike #553
Jacobians), not a self-generated snapshot.

---

## 16. Kill-condition map (the losing "wins when" lines, preserved)

- A genuine **second differentiable System** needing indexed replay with a non-scalar snapshot → move
  the recording into an odelia `SubStateRecorder` of opaque `vector<double>`. Zero witnesses today.
- **Mutants cut** + resident soil made non-stiff/active → the recording collapses to knots-only.
- **Scope collapses to FF16-field-only / mutant-only** → `Coupling` loses its witnesses; the floor
  (template one environment, no concept) wins.
- **Schedule stops being frozen-on-the-double-pass** (adaptive sub-step replay to fix TF24 stiffness) →
  the fixed-`double` snapshot and the "mesh not differentiated" lock both break; this is the largest
  future redesign and is deliberately deferred.

---

## Appendix A — surface-by-surface change index

`internals.h` keep · `individual.h` de-twin, keep `<It>` seam · `node.h` de-twin, one
`growth_rate_gradient`, birth stamps double · `species.h`/`species_base.h` keep `census<Psi>` + `<It>`,
de-twin `compute_competition` · `patch.h` `value_type=S`, `static_assert(Coupling)`, host recording,
two overloads, `Replayable` hooks · `scm.h` runnable, `run()` growing loop kept · `parameters.h`
double (IC seam unused in v1) · `strategy.h` unchanged · `ff16_strategy.{h,cpp}` one-body crown +
`height_seed` seam, X-macro pars, delete kernel · `tf24_strategy.{h,cpp}`/`tf24f_strategy.h`
mixed-scalar (double `Leaf`, `Internals_<S>` aux), leaf seam incl `∂/∂ψ` · `k93_strategy.{h,cpp}`
template class, two kinks · `ff16_environment.h`/`k93_environment.h` satisfy `Coupling`, field-only ·
`tf24_environment.h` satisfy `Coupling`, soil state + `compute_state_rates` + `param_ptrs()` · `qk.h`
one `integrate<S>`, delete `integrate_ad` · `canopy_shape.h` template profile, delete twins ·
`resource_spline.h` route to odelia interpolator, keep value-query, delete `get_deriv_at_height` ·
`qag.h` untouched (dormant) · `adaptive_interpolator.h` delete · `ff16_production_kernel.h` delete ·
`ad_value.h` delete · `emergent_functional.h` keep (pure reduction) · `stand_gradient.{cpp,R}`
dispatch table + thin wrapper · **new:** `environment_recording.h`, `coupling.h`, the X-macro `.def`s.
odelia: consume as-is + the `supplied_derivative` slot-filter (§7.4).
