# AD implementation design: the general reverse-mode harness (plant × odelia)

Companion to [`ad-touchpoint-catalog.md`](./ad-touchpoint-catalog.md) (the surface survey) and
[`ad-infrastructure-design.md`](./ad-infrastructure-design.md) (the thesis). This is the
**implementation specification**: for every plant surface the catalog enumerates, it states the
concrete treatment under the committed design — *including surfaces that do not change* — with
`file:line` anchors. Parts 1–7 are the mechanism; **Part 8 is the input/output, workflow, and R-facing
semantics** (the surfaces the catalog added in its Parts VI–IX); Appendix A is the per-file change index.

**v2 — revised after an adversarial teardown** (three red-teams + a code-verifying judge). Changes from
v1 are tagged **[Sn]/[Mn]** and summarised in §0.4. Two prior search results remain load-bearing:
- A spike (real XAD + odelia `basic_spline`) proved active-query `eval(S)` and a passive-slope
  linearisation give the **bit-identical** crown gradient — so `eval(S)` is *cleanliness*, not a fix.
- The judge caught a convergent crash: a frozen input's adjoint does **not** flow nowhere — a passive
  `AReal` has `slot_ = INVALID_SLOT` and `Tape::incrementAdjoint` (`odelia/src/Tape.cpp:619`) *throws*.
  The seam must skip inactive slots, filtering `(slot, partial)` **pairs** (§7.4).

---

## 0. Scope, commitment, invariants

**Scope.** One harness delivering exact reverse-mode gradients of emergent SCM metrics with respect to
**30–50 low-level strategy and environment (soil) parameters**, for **TF24 resident and mutant**, with
**FF16 and K93 as restrictions of the same code**. Fixed schedule (L0 introductions + L1 RKCK step
times, recorded on a double pass) and **given initial conditions**; the mesh is not differentiated.

**The commitment (one sentence).** *`S` lives only on the ODE state/rate storage and the rate
arithmetic that reads it — plus the seeded parameters and the active background reads; every other
type is `double`; the sole crossing on the rate path is `supplied_derivative` at the shed edge, and the
only way a background becomes frozen `double` is a read from the recording.*

**Kept true by structure, not convention:**
1. The shed's function signatures are `double` (`Leaf::*`, the leaf interpolators' `.eval()/.deriv()`,
   `QAG`, `util::gradient_fd`, `util::uniroot`), so passing an active `S` into the shed is a **compile
   error** — the one sanctioned narrowing (`supplied_derivative(tape, xad::value(...), {inputs},
   {partials})`) re-injects the partial in the same call. A model type's scalar is decided by which of
   its members carry `S`: a `double Leaf` member *cannot* go active, a `Pars_<S>`/`Internals_<S>` member
   *must* — so a mixed-scalar strategy (active pars + `double` leaf) needs no special type, and the
   endpoint's active soil is just a `TF24_Environment_<S>` whose `Internals_<S>` state and closed-form
   rate arithmetic carry `S` like any other core member.
2. The only producer of a frozen background is `EnvironmentRecording::restore<S>` (§5), yielding
   passive `S`-constants; a **missing** recording is a loud out-of-range read.
3. The recording carries a **parameter fingerprint**; a gradient call whose seeds do not match it
   errors loudly rather than replaying a stale background **[S3]**.
4. `plant/ad_value.h` is **deleted**. The sanctioned narrowings are exactly: `restore<S>`; `xad::value`
   marshalling on a `supplied_derivative` argument line (§7); the final `xad::value` in
   `compute_jacobian`; and the enumerated Cluster-7 guards/selectors in the **kink manifest** (§11). CI
   greps `value(`/`xad::value(` and fails on any other hit.

**No `Coupling` concept [v3].** v2 §6.1 proposed a `Coupling` concept `static_assert`ed on `Patch`; it
was implemented and **removed**. Every clause it required (`get_environment_at_height`, `ode_size`, the
`<It>` seam, `compute_rates`) is a call `Patch` already makes, so the compiler enforces the identical
contract at the use site — the concept restated it, and lagged the real `rebind_from`/`ad_parameters`
surface. A contract-accurate concept over *that* surface is a legitimate later add, once the machinery
exists and is not yet enforced by use; §6.1 below is superseded.

**Invariants.**
- **Only `double` crosses R** — RcppR6 `XPtr`; only `double`/`List`/`NumericMatrix` returns marshal.
- **Resident vs mutant is data-presence** — `has_recorded_field()` (`ode_interface.hpp:160`) routes
  recompute-active vs read-recorded. This dispatch and the two `set_ode_state` overloads (§5.3) live **at
  the Patch seam**; the physiology *below* Patch is oblivious. The doc claims obliviousness of the
  *physiology*, not the *harness* **[RT-A#2 framing]**.
- **The gradient is defined only at a fixed `Control`** (§8.4) and is w.r.t. **low-level parameters, not
  ecological traits** (§8.1) **[S5]**.

### 0.4 Changelog from v1
**S1** soil-ψ read active, no `double` cache on the active environment; false gate claim removed (§6.3).
**S2** the SCM is specified as the `Solver`-runnable; one growing `run()` (§1, §8.3). **S3** recording
fingerprint + stale-guard (§5.1, §5.4). **S4** `Coupling` checks the templated iterator +
`rebind_from<value_type>` (§6.1). **S5** columns labelled low-level-parameter partials (§8.1). **M1**
seam skips `(slot,partial)` pairs + gates every seeded parameter to a leaf partial (§7.4). **M2** field
domain is a frozen L2 position (§5.5). **M3** MeanLight→`S` scheduled (§4.2/§15). **M4** birth_rate seeded
at read sites (§8.5). **M5** Gate 1 multi-species (§15). **M6** shared-strategy scratch invariant (§3).
**M7** IndividualRunner Gate 0 (§15). **M8** kink-manifest completeness, active-safe guards, Control
surface, extrinsic drivers, recording UX, disturbance/stochastic/NEWS, aux invariant (§8, §11, §5).

### 0.5 Changelog v2→v3 (deep design search, read forward to resident TF24)
The commitment is reframed onto **scalar placement** (§0): `S` = ODE state/rate storage + the rate
arithmetic that reads it; everything else `double`; the shed's `double` signatures make activating the
leaf a **compile error** (the structural enforcement), and a model's scalar is which members carry `S`.
**V1** the `Coupling` concept is **removed** — it restated what `Patch`'s use compile-enforces and lagged
the real `rebind_from`/`ad_parameters` surface (§0, §6.1, §12). **V2** the four per-strategy
`make_strategy_ptr` overloads collapse to one generic in `strategy.h` (§12). **V3** the environment is
templated because soil is *integrated state + closed-form algebra* (it cannot be a `supplied_derivative`
of a value the solver evolves) **and** because a resident's self-shading needs active light *values* —
so R5 holds environment-templating even for the soil-less FF16/K93 resident. Two flags the build order
must not lose: `Node::growth_rate_gradient` **result** must carry `value_type` (its FD stencil stays a
`double` primitive, but the result feeds `log_density_dt` and every density-weighted metric — left
`double` it silently drops the density-transport term, §15 step 3); and this scalar foundation reaches
the endpoint's **types** but not its **numerics** — the stiff resident replay and the mid-run active
`resize()` tape-survival are orthogonal odelia items to de-risk on IndividualRunner + K93 resident first
(§13, §15 Gate 1).

---

## 1. Architecture on one page

```
R:  stand_gradient(scm, metrics, params, feedback)            [only double crosses]
      |  [[Rcpp::export]] stand_gradient_cpp (§8.2): C++ dispatch on strategy/feedback
      v
C++: double SCM<T,Env> --rebind_from<active>--> ACTIVE SCM   (the runnable, §8.3)
     seed 30-50 params via DifferentiationTargets over scm.ad_parameters()   (§8.1)
     odelia::compute_jacobian(active_scm, targets, EmergentFunctional{metrics}):
        check recording fingerprint == current seeds, else error   (§5.4)
        record once:  active_scm.reset(); active_scm.run()          <-- ONE growing run()
          SCM::run(): per introduction -> introduce cohorts -> resize ODE vector -> advance_fixed(recorded step times)
             per step:  replay_step()  -> load frozen L2 knots / advance cursor
             per RK stage: derivs(y, index):
                resident (has_recorded_field()==false): set_ode_state(it,time)  -> recompute env ACTIVE on frozen knots
                mutant   (has_recorded_field()==true ): set_ode_state(it,index) -> restore env FROZEN by (step,stage)
             rates: physiology reads env.at(channel,query)->S; sub-solves inject via supplied_derivative (§7)
        m adjoint sweeps over the one SCM-owned tape; xad::value -> double Jacobian
      v
R:  metrics x parameters matrix; dimnames + low-level-partial caveat in the R wrapper (§8.1)
```

**The runnable [S2].** `compute_jacobian(solver, …)` (`gradient.hpp:45`) requires on its argument, on the
emergent path: `get_system_ref()` (→ `Patch&`, `:62`), `ad_parameters()`/`ad_initial_state()` (`:88-89`),
public `tape` (`:74-77`), `reset()` (`:93`), `run()` (`:94`). (`get_history_step` is `least_squares`-only,
**not** the emergent path.) The **SCM** is the object passed in: it exposes exactly those members
(`get_system_ref()`→its `Patch`; `tape` forwards its inner `Solver<patch_type>::tape`; `reset()`/`run()`
its own), and `SCM::run()` is the single growing `[introduce][resize][advance_fixed]` loop. The inner
`Solver<patch_type>` is a member the SCM *drives* (`solver.advance_fixed(segment)`), never the object
`compute_jacobian` calls — v1's "`active_solver.run()`" is removed. `stand_gradient_cpp` lifts the double
SCM to the active SCM via `rebind_from<active>` and passes that.

---

## 2. odelia surface consumed (branch `claude/ad-surface`)

Consumed as-is except one ~2-line change (§7.4).

| surface | file | role | change |
|---|---|---|---|
| `Replayable` (`record_stage`/`record_ode_step`/`replay_step`/`has_recorded_field`) | `ode_interface.hpp:42` | record/replay hooks; `if constexpr`, zero-cost if absent | none |
| `derivs(obj,y,dydt,time,index)` | `ode_interface.hpp:156` | recompute vs recorded-read on `has_recorded_field()` | none |
| `const_iterator`/`iterator`=`vector<double>::iterator` | `ode_interface.hpp:16-18` | odelia's double-only free helpers — **plant does NOT use them**; it uses its own `<It>` seam (§3) | none; the concept must not check these (§6.1) |
| `compute_jacobian(solver, DifferentiationTargets, functional)` | `gradient.hpp:45` | seed → reset → run → record once + m sweeps; `tape_guard` on exit | none |
| `rebind<S2>`/`rebind_from<S2>()` | System contract | double→active lift | none (plant provides) |
| `basic_interpolator<S>`/`basic_spline<S>` | `interpolator.hpp`,`spline.hpp:238` | positions double, values S; `construct` adaptive-double, `init` active-on-frozen-knots | optional add `S operator()(S)` (cleanliness, §4.4) |
| `supplied_derivative(tape,value,inputs,partials)` | `supplied_derivative.hpp:46` | single value, many double partials | **~2-line fix**: skip `(slot,partial)` pairs whose slot is `INVALID_SLOT` (§7.4) |
| `Solver<System>` owns `tape` + cached `active_solver` | `ode_solver.hpp:242,246` | one tape reused | none |
| `advance_fixed(times)` | `ode_solver_internal.hpp:172` | fixed-segment replay | none |
| `set_state_from_system()`→`resize()` | `ode_solver_internal.hpp:145,333` | grows ODE vectors; move-ctor preserves `slot_` | none |
| `xad::Tape<double>::getActive()` | `XAD/Tape.hpp:102` | System reaches the active tape from `ode_rates` | none |

Slot reuse is **off** (`XAD/Config.hpp:44`; `Tape.hpp:212` `registerVariableAtEnd`), so a retired slot is
never reassigned mid-recording — the stale-valid-slot hazard does not arise **[RT-C#2b killed]**.

---

## 3. The scalar skeleton (Layer 1) — every type

Uniform `value_type = S` via the existing `<T,E>` templates; `_`+alias only on scalar-carrying leaves.

| Type | file | current | treatment | change |
|---|---|---|---|---|
| `Internals_<S>` | `internals.h:14` | `template<class S=double>`, four `vector<S>` | keep; `aux` is `S`. **Invariant [M8/Q13]:** `aux` is a recomputed taped intermediate, **never** part of the frozen snapshot (§5.1) — so `collect_all_auxiliary` varying `aux_size` between record and replay cannot desync `restore<S>` | none |
| `Individual<T,E>` | `individual.h:16` | `value_type` | collapse `_ad` twins to one `S` body; double R/stochastic call sites narrow via a manifest `xad::value` at the call site | de-twin |
| `Node<T,E>` | `node.h:16` | `value_type`; birth stamps double | collapse `compute_competition(_ad)`/`get_density(_ad)`/`growth_rate_gradient(_active)`; birth stamps double, completeness §8.5 | de-twin |
| `Species<T,E>`/`SpeciesBase` | `species.h:27`,`species_base.h:46` | `value_type`; `<It>`; `census<Psi>` | keep `census<Psi>`+`<It>`; de-twin; birth-rate §8.5 | de-twin |
| `Patch<T,E>` | `patch.h:22` | `double` | `value_type=T::value_type`; `static_assert(Coupling<E>)`; host recording (§5); two overloads (§5.3); `Replayable` hooks; `height_max()` §5.5 | core |
| `SCM<T,E>` | `scm.h` | double; owns `Solver<patch_type>:133` | `value_type`+`rebind`; **expose the Solver-runnable interface** (§1); growing `run()` | edits |
| `Parameters<T,E>` | `parameters.h` | POD double | double; `initial_state` IC seam **deferred** (§13, diverges from catalog XII Q19 per fixed-IC scope) | none v1 |
| `Strategy<E>` base | `strategy.h` | base | none | none |

**The `<It>` seam is plant's, not odelia's.** Every `set_ode_state`/`ode_state`/`ode_rates` is templated
on `It` so it flows at the ODE vector's scalar; do not route through odelia's `double`-only free helpers.
This is why `Coupling` must check the templated form (§6.1).

**Shared-strategy scratch [M6].** Cohorts of a species alias one `shared_ptr` strategy whose non-`const`
members (`QK function_integrator`; TF24 `mass_root_prop_`, `tf24_strategy.h:376`) are per-call scratch.
Invariant to hold and test: scratch is **write-before-read within one cohort's rate eval**, never carried
across cohorts (else it holds the prior cohort's active tape identity). TF24f's tracked ψ
(`tracked_root_psi_`/`dprofit_dpsi_`, `tf24f_strategy.h:74`) is genuine per-cohort state → must live in
the cohort `Internals` (`opt_root_psi_state`), **not** the shared strategy (a required TF24f change).

---

## 4. Per-strategy physiology (Layer 2)

One `template<class S>` body per method; `S=double` bit-identical. "One body" scopes to **physiology
arithmetic**; surviving poly-dispatch (strategy virtuals, `assimilation_fn`/`leaf_above_`/`pow_eta_`
function pointers, the R-boundary table §8.2) are model/boundary choices, not scalar branches **[M3]**.

### 4.1 K93 — free restriction
Closed-form; template the class; two kinks (`:117,:139`) → manifest (§11). Field-only env.

### 4.2 FF16 (`ff16_strategy.h/.cpp`)
| Surface | file | treatment |
|---|---|---|
| `FF16_Pars_<S>` `field_ptrs()`/`field_names()` | `:107,114` | X-macro single-source (§8.1) |
| mass cascade | `.cpp` | one `S` body; delete `ff16_production_kernel.h` (§4.4) |
| `assimilation_fn` dispatcher | `:267,294` | keep. **[M3]** `assimilation_average_light` (MeanLight, **TF24's default**) integrates in `double` (`:211`) — **must** become one `S` body (build step 2, §15) or MeanLight silently drops the crown derivative |
| `assimilation_deep_crown` | `:160` | collapse the `if constexpr` fork + `integrate_ad` + the manual linearisation → one `QK::integrate<S>` (§4.4) |
| `compute_competition_by_ratio` | `:416` | collapse the fork (falls out once `CanopyShape` is templated) |
| `height_seed` | `:588` | IFT via the `supplied_derivative` seam (§7); delete inline `g-ad_value(g)` |
| `establishment_probability` | `:488` | one `S` body. **[M8]** reads `environment.time` via `exp(-recruitment_decay·time)` — a non-autonomous time term on the IC, **inert at default `recruitment_decay=0`, user-settable** — documented |
| frozen `r_l`, `r_b=2·r_s` | `:42` | **no change** — `d(r_l)/d(lma)=0` by construction (a gradient-interpretation caveat) |

### 4.3 TF24/TF24f — mixed-scalar witness
`TF24_Strategy_<S>` = `S` pars + `S` mass cascade + a **`double` `Leaf`** (`:338`, never templated on `S`;
`leaf_model.cpp` never active). Trait feeds the leaf as `xad::value(trait)` (seam marshalling §7, not a
freeze). `aux` = `Internals_<S>`. Crown = §4.4; MeanLight default (§4.2). TF24f adds `opt_root_psi_state`
in the cohort `Internals` (§3). `ShadingModel` (`canopy_shape.h:47`): FlatTopBox/PPA-hard don't run
(drop); FlatTopSoftBox C1 2nd-deriv step → manifest.

### 4.4 Crown quadrature + canopy shape (Cluster 4)
`QK::integrate` → one `template<class S,class F> S integrate(F,S a,S b)`; delete `integrate_ad`
(`qk.h:31`); fixed rule, active bound tapes exactly. `CanopyShape` (`canopy_shape.h:100`) → template the
profile; delete `_active` twins + the `if(leaf_above_==…)` check; `eta` double unless seeded.
`resource_spline.h:100` `get_value_at_height`→`S` keep; delete `get_environment_deriv_at_height` (`:128`).
`QAG` (`qag.h:85`) **no change** (dormant, `max_iter=1`). `deep_crown_replay`+composite
(`ff16_production_kernel.h:111`) **delete**.

---

## 5. The recording — `EnvironmentRecording<E_double>` (Layer 7)

### 5.1 Type
```cpp
template <class E>                       // E = environment_type_<double>; only double stored
struct EnvironmentRecording {
  std::size_t params_fingerprint = 0;                // [S3] hash of the seed values recorded at
  std::vector<double> step_times;                    // L1; step_times[0]==0
  std::vector<std::vector<E>> stages;                // L3: whole-env snapshot [step][RK stage]
  std::vector<std::vector<double>> knots;            // L2: field knot positions per step (incl. domain-bound top knot, §5.5)
  int  step_index(double t, int hint) const;         // hint, else search; last-step clamp
  const std::vector<double>& positions(int k) const { return knots[std::min<std::size_t>(k,knots.size()-1)]; }
  template <class S> environment_type_<S> restore(int k, int stage) const
    { return stages[std::min<std::size_t>(k,stages.size()-1)][stage].template rebind_from<S>(); }
};
```
Whole-`E<double>` snapshot (not a hand-listed field set) → adding a soil field freezes it for free → one
freeze-audit site. **`aux` is not snapshotted** (recomputed intermediate, §3), so a runtime `aux_size`
change cannot desync `restore` **[M8]**. RAM fallback: minimal-POD `{knots,values,soil_state,time}` behind
this interface (§14). Cadence: L2 positions per step; L3 values per RK substage.

### 5.2 Production (`Replayable` hooks)
`record_stage` (per stage) pushes `environment` (guarding `light_knots()` at stage 0); `record_ode_step`
(per accepted step) commits `step_times`/`stages`/`knots` and sets `params_fingerprint` once from the
current seeds; `replay_step` seeks + loads `positions(k)` (resident); `has_recorded_field()` (mutant).

### 5.3 Two `set_ode_state` overloads (Patch seam)
Routed by `derivs` on `has_recorded_field()`; both defer to the concept. Resident `(it,time)`: cohorts,
then `environment.set_ode_state` (soil state), then `set_field_active(competition_fn(),current_knots_)`,
then `compute_rates` (incl. `environment.compute_state_rates(resource_depletion)`). Mutant `(it,stage)`:
`env_scratch_ = restore<S>(cur_step_,stage)`, `environment_ptr=&env_scratch_`, skip env ODE slots.
**[RT-C#7]** `env_scratch_` is one member overwritten each stage; nothing may retain a reference to
`environment` across stages (shared-strategy scratch reads within the stage, §3) — an explicit, tested
invariant.

### 5.4 Fingerprint / staleness guard [S3]
`stand_gradient_cpp` hashes the SCM's current seed parameters and compares to
`recording.params_fingerprint`; on mismatch it errors (`"AD recording is stale for these parameters;
re-run run_scm(control(save_RK45_cache=TRUE))"`). Closes the optimiser/regnans-Newton hazard: a caller
that perturbs parameters and re-invokes `stand_gradient` on the same in-session SCM without re-recording
gets a loud error, not a silent gradient against a stale background.

### 5.5 The field domain is a frozen L2 position [M2]
The resident replay rebuilds the field on the **recorded** knots (`compute_environment_fixed`), so the
domain `[0, height_max]` is the **recorded top knot** — a frozen `double` L2 position, consistent with
freezing all L2 positions. `Patch::height_max()` (a non-smooth `max`, `patch.h:542`, `double`) is used
**only on the double record pass**, never on the active replay — so no active `max` enters the gradient.
The dropped `∂(domain)/∂param` is the same accepted L2 position-freeze as every knot, recorded in the
manifest (§11), not a separate live kink.

### 5.6 Recording lifecycle / UX [M8 / IX.3, Q23]
Ephemeral session state behind the SCM `XPtr`, opt-in via `control(save_RK45_cache=TRUE)`, distinct from
`collect=TRUE`, **not serialised** — a `saveRDS`'d/resumed SCM has lost it. A gradient call on an SCM
that never opted in errors loudly (distinct from §5.4 stale and §5.1 missing-index). Documented in the R
help.

---

## 6. The environment contract + the environments (Layer 3)

### 6.1 The contract [v3 — no concept]
There is no `Coupling` concept (§0). `Patch` requires of its environment exactly what it calls, enforced
by use at the scalar `Patch` is instantiated with: `get_environment_at_height(value_type) -> value_type`,
`ode_size()`, the `<It>`-templated `set_ode_state`/`ode_state`/`ode_rates` seam, and
`compute_rates(depletion)`. The environment's scalar is decided by its member types (`Internals_<S> vars`,
`ResourceSpline_<S> light_availability`): FF16/K93 carry `ode_size()==0` and an active light *read* only;
`TF24_Environment_<S>` additionally carries active soil ODE state and closed-form soil rate arithmetic.
`restore<S>`/`rebind_from<S>` are the recording/lift verbs (§5, §8.3); a small concept over *that*
surface is a legitimate add once it exists and is not yet enforced by use — not before.

### 6.2 `at(Query)` [RT-A#3]
`at(Query)` is the physiology **point-read** (light at a height, soil ψ at a layer; active `z` or int
`layer`, returns `value_type`). The **crown integral** reads the light spline through `QK::integrate<S>`
over the active bound (§4.4), i.e. via the spline `operator()`/`eval(S)`, **not** `at()` — two light read
paths; the "single audited read" claim is scoped to point reads. Crown-derivative correctness is verified
by the FD gate on `assimilation_deep_crown` (§15), not the concept.

### 6.3 The environments — and S1 (soil ψ read active)
| Environment | file | channels | `ode_size()` |
|---|---|---|---|
| `FF16_Environment_<S>` | `ff16_environment.h:15` | light field | 0 |
| `K93_Environment_<S>` | `k93_environment.h:12` | light field | 0 |
| `TF24_Environment_<S>` | `tf24_environment.h:16` | light + **soil-water state** | `soil_number_of_depths+4` |

Soil is **state, not a field** (fixed grid, closed-form curves) → **no L2** for soil. Resident TF24: soil
is active integrated state (§13 gate); mutant: soil rides L3 in the whole-object snapshot.

**S1 — soil ψ read ACTIVE; no `double` cache on the active environment.** `psi_from_soil_moist`
(`tf24_environment.h:272`) is templated on `S`; `get_soil_water_potential_state()` recomputes
`psi_from_soil_moist(vars.state(i))` at scalar `S` per read. The v1 `mutable vector<double>
psi_soil_cache_` exact-compare memo (`:111`) is a **double-run-only** optimisation and does **not** exist
on `TF24_Environment_<active>` (recompute is cheap, closed-form). This removes the freeze v1 wrongly
claimed the stiffness gate would catch: a `double` cache on the active object would cut every
`∂ψ/∂(soil state)` edge, and a value-based *drift* gate is structurally blind to a zeroed *derivative*.
`cached_driver_` (`:117`) stays `double` (drivers are genuine `double` inputs, §8.5). The leaf's
operating-point caches are inside the `double` `Leaf` (§4.3), off the active object — safe.

---

## 7. Iterative solves + the injected-derivative seam (Cluster 5)

### 7.1 The seam
```cpp
auto* tape = xad::Tape<double>::getActive();
double y0 = solve_in_double(...);
std::vector<S*> inputs; std::vector<double> partials;         // active inputs y depends on; analytic dy/d(input)
S y = odelia::ode::supplied_derivative(*tape, y0, inputs, partials);   // §7.4
```
### 7.2 `height_seed` — root of `mass_live_given_height=omega`; IFT `dh*/dθ=-(∂g/∂θ)/(∂g/∂h)` (`∂g/∂h`
double CD, `∂g/∂θ` per seeded parameter, incl. the `lma`→`mass_leaf` chain); at `reset()`, tape active.
### 7.3 Leaf optimiser — envelope theorem at ψ*; inputs `{seeded params, light, height, soil ψ}`;
`∂profit/∂ψ` (`leaf_model.cpp:900`) is the extra **resident** partial (ψ active); identical call on the
mutant (ψ passive, dropped by §7.4).
### 7.4 The seam fix [S1-adjacent / M1]
A passive `AReal` has `slot_=INVALID_SLOT`; `Tape::incrementAdjoint` (`src/Tape.cpp:619`) **throws** for
`slot>=size`. Fix: skip inputs whose slot is `INVALID_SLOT`, **filtering `(slot,partial)` as a pair** so
`partials` stays aligned (a slot-only skip mis-pairs → silently wrong). Branch on slot-activity, not
run-type. **Gate [M1]:** a test that every seeded parameter reaching a `supplied_derivative` site has a
leaf partial — an **absent** partial is an implicit zero the filter neither causes nor catches; the full
`∂profit/∂θ` set for TF24 is gated this way (§15).
### 7.5 `resource_compensation_point` (`individual.h:162`) — R-facing diagnostic, off the run graph.

---

## 8. Input/output semantics, workflow, and the R boundary (catalog Parts VI–IX)

### 8.1 What the gradient is w.r.t. — low-level parameters, not traits [S5]
The 30–50 columns are gradients w.r.t. **low-level `FF16_Pars`/`TF24_Pars` fields and soil parameters** —
the **partial** holding hyperpar-derived quantities fixed. They are **not** the ecological total through
`hyperpar()`'s fan-out (`lma→{k_l,r_l}`, `rho→{d_I,k_s,r_s,r_b}`, `a_p1/a_p2` via a solar integral;
`ff16.R`, `solar_model.R`). Deliberate (the user wants the low-level Jacobian) — but the R help and the
result state it, so `d(LAI)/d(lma)` is not mistaken for an ecological trait sensitivity. Composing the
hyperpar Jacobian is out of v1 scope. **Seeding:** `Patch::ad_parameters()` = species-major
`strategy->field_ptrs()` ++ environment `param_ptrs()` (soil), single-sourced by X-macro:
```cpp
#define FF16_AD_FIELDS(X) X(lma) X(rho) X(hmat) /* … */ X(k_I)   // ONE list
std::vector<S*> field_ptrs(){ return { FF16_AD_FIELDS(PTR) }; }               // PTR(f) &pars.f,
static std::vector<std::string> field_names(){ return { FF16_AD_FIELDS(NAME) }; }  // NAME(f) #f,
static_assert(FF16_AD_FIELD_COUNT == field_names().size());
```
**Count [M8]:** FF16 exposes **32** fields; TF24 more + soil — "30–50" is the range across strategies,
not a literal; the `static_assert` is wired to the macro, never a hand-typed number.

### 8.2 The R boundary (Layer 0)
One `[[Rcpp::export]] stand_gradient_cpp(SEXP scm, …)`: unwrap the RcppR6 pointer (no serialisation),
resolve names→`DifferentiationTargets`, check the fingerprint (§5.4) + opted-in-cache precondition (§5.6),
**dispatch strategy/feedback via a table** (not open-coded `if`s), call `compute_jacobian`, return a
`double` matrix. Dimnames (metrics × params; species by integer index) + the §8.1 caveat + the Control
record in the thin R wrapper. `compileAttributes`/`RcppR6::RcppR6()` unchanged.

### 8.3 Runnable — §1 [S2].

### 8.4 The `Control` surface [M8 / VI.7, Q6]
Absent from v1. A gradient is well-defined **only at a fixed `Control`**; the stated reference Control:
**adaptive RKCK** (not `fixed_time_step`/Euler — Euler doesn't populate the RK-stage cache and is
refused), `save_RK45_cache=TRUE`, the per-strategy `shading_model`, and
`schedule_eps`/`offspring_production_tol`/`GSS_tol_abs`/`ci_*` at run values. `node_gradient_*` selects the
existing FD node-gradient the AD replaces/compares (the incumbent the §15 gate matches). `stand_gradient`
records the Control in its result.

### 8.5 `birth_rate` + extrinsic drivers [M4 / VII.3, VIII.3]
`extrinsic_drivers.h` supplies `birth_rate` + climate (`rainfall`, `PPFD`, `atm_vpd`, `ca`, `leaf_temp`,
`atm_o2_kpa`, `atm_kpa`). **Climate drivers are fixed input data, not targets** (stated). **`birth_rate`
is first-class** (`dR0/d(birth_rate)` → regnans). It enters at **two read sites**: the cohort density IC
(`log(birth_rate·pr_estab/g)`, `node.h:177`) **and** the offspring-output scaling (`patch.h:473`; R0 uses
`scalars=1`). The seed is registered **at the read sites** (one active `birth_rate` both sites read), so
the derivative reaches both — **not** only an introduction-time `birth_rate_scale`, which would miss the
offspring-output term. (v1 seeded only the scale; corrected.) Scope: scalar `birth_rate`
(`is_variable_birth_rate=false`); the spline case is a functional derivative over control points, out of v1.

### 8.6 Compatibility, NEWS, stochastic [M8 / IX.3, VI.4, Q24]
Templating on `S` with `double` aliases changes no R-visible signature (RcppR6 binds `<double>`), so no
`NEWS.md` entry is required as designed; **if** any Control field / return shape changes during
implementation, a `NEWS.md ### Breaking changes` entry is required (machine-read by
`plant-update-interface`) — stated so it is not forgotten. The **stochastic engine** (`stochastic_*.h`)
shares the hierarchy (CRTP) and the four instantiations; non-differentiable, out of AD scope, but the
`S`-templating **must keep its `double` path compiling** — a build constraint tested by keeping
`stochastic.R` green.

---

## 9. The functional + driver

`EmergentFunctional` — a pure reduction: `codomain()`=metric count, `operator()(solver)` reads native
state → `vector<S>`, drives nothing. Metrics reuse the model's reductions: LAI/biomass/basal-area via
`Species::census<Psi>`; offspring/R0 via `net_reproduction_ratio_by_node_weighted`; birth-rate via §8.5.
One tape, recorded once, m sweeps, `xad::value` at the boundary, `tape_guard` on exit. Peak ~0.5–4 GB
(50-yr FF16 resident; fits workstation RAM; cohort-introduction boundary = reserved inactive
`CheckpointCallback` seam if a measured tape exceeds budget).

---

## 10. The five witnesses

| Witness | Channels | overload | recording read | seam |
|---|---|---|---|---|
| K93 resident | light | `(it,time)`,`replay_knots` | L2 → recompute active | none |
| K93 mutant | light | `(it,stage)` | L3 `restore<S>` | none |
| FF16 resident | light | `(it,time)`,`replay_knots` | L2 → active self-shading | `height_seed` |
| FF16 mutant | light | `(it,stage)` | L3 `restore<S>` | `height_seed` (active in params) |
| TF24 mutant | light+soil | `(it,stage)` | L3 `restore<S>` (light+soil) | leaf; light+ψ frozen → §7.4 drops |
| TF24 resident | light+soil | `(it,time)`,`replay_knots` | L2; soil active (ψ read active §6.3) | leaf incl `∂profit/∂ψ`; §13 gate |

---

## 11. Freeze rule + kink manifest (Cluster 2 + 7)

**The barrier taxonomy [v3.1].** "AD-hostile primitives" (catalog Part I) are not a category to
patch per site. Every value a barrier touches falls into exactly one kind by its relationship to the
derivative, and each kind's treatment lives at the operation's **definition**, never the call site —
so no call site narrows and the sanctioned-`value(` allowlist (§0.4 pt 4) stays O(1) in strategy
count, not O(sites):
- **Kind A — off the derivative** (finiteness/NaN guards, `stop` text, indices, PPA layer selectors).
  The guard reads the value, never the tape. Make the *utility* scalar-generic at its definition: keep
  `is_finite(double)` (bit-identity — double keeps selecting the non-template overload) and add
  `template<class T> bool is_finite(const T& x){ using std::isfinite; return isfinite(x); }`. ADL
  resolves `isfinite` to `xad::isfinite` for an active `S` and `std::isfinite` for `double`, so the
  guard needs **no `xad::value` and no XAD include in the foundational `util.h`** — nothing reaches the
  CI `value(` grep, and a raw double guard no longer exists for a call site to misuse on an `S`.
  (Verified: active finite/inf classify correctly; `numeric_limits<AReal>` at `StdCompatibility.hpp:184`
  lets `numeric_limits<double>`/`M_PI` promote untouched.)
- **Kind B — on the derivative, computed off-tape** (root-finds, optimisers, all of `leaf_model.cpp`).
  The shed keeps `double` signatures; the sole crossing is `supplied_derivative` (§7).
- **Kind C — on the derivative, on-tape** (rate arithmetic, reductions, quadrature-through, `min/max`
  clamps as documented subgradients). Just `S`; XAD's ADL handles `pow/exp/min/max`/comparisons; no
  narrowing. `Node::growth_rate_gradient` is **Kind C** — the FD stencil coefficients (±ε, /2ε) are
  `double` but `g` is evaluated active, so the result carries `value_type` (the §0.5 flag, derived);
  it must **not** reach for the Kind-B seam.

The kill condition for this split: a barrier whose correct treatment depends on **run-type** (resident
vs mutant) rather than on its derivative relationship — none is expected, since resident/mutant is
data-presence *at the Patch seam* and physiology below is oblivious (§0); if one appears, hoist that
decision to the Patch seam, do not give the guard two forms.

Freeze rule — §0.4 point 4. **Kink manifest** (checked-in, each entry classified selector/kink/guard +
tested) now including, on the differentiated rate path **[M8]**: the **production sign branch**
`if(net_production>0){…}else{zero rates}` (`ff16_strategy.cpp:103`, `tf24_strategy.cpp:186` — compensation
point sits on it); **FlatTopSoftBox** C1 2nd-deriv step (`canopy_shape.h:176`); **TF24 rooting-depth clamp**
`min(height, rooting_depth_max)` (`tf24_strategy.cpp:374`); the **field-domain top knot** (§5.5); soil
positivity resets **`tf24_environment.h:218,248,267,277`** (v1 listed only `:248`); PPA `floor`
(`ff16_environment.h:133`); `max(0,spline)` (`resource_spline.h:120`); K93 `growth<0→0`/`mu>0?mu:0`.
**Guards need an active-safe form [M8]:** `is_finite`/`util::stop`/`check_finite_ode_state` (8
`is_finite` sites incl. `ff16_strategy.h:617`, `node.h:147,185`, `species.h:208`, `patch.h:386,422`)
must **never throw on an active intermediate**. This is Kind A above: fix it **once at the utility
definition** (scalar-generic `is_finite`; `check_finite_*` reads `xad::value`), not with a `value(...)`
wrap at each call site — the per-site form grows the allowlist per strategy and a single forgotten wrap
is a silent throw at exactly the boundary an FD probe lands on.

---

## 12. What is deleted

`ad_value.h`; `adaptive_interpolator.h`; every `_ad`/`_active` twin; every `if constexpr(is_same_v)`
freeze-fork; `get_environment_deriv_at_height` + the linearisation; `ff16_production_kernel.h`; AD-11's
`Patch` `step_history`/`environment_history`/`knot_history`/`environment_cache`/`idx` (→
`EnvironmentRecording`); the double `psi_soil_cache_` on the active environment (§6.3); the open-coded
strategy `if`-blocks (→ dispatch table, §8.2); **`coupling.h` + the `static_assert` on `Patch`** (v3, §0
— restated what `Patch`'s use enforces); **the per-strategy `make_strategy_ptr` overloads** (v3 — one
generic `make_strategy_ptr(Strat)` in `strategy.h`).

---

## 13. Deferred / gated

- **TF24 resident stiffness** — accepted; a **loud drift gate** (double-replay env error vs adaptive
  trajectory, in `check_finite_ode_state`) refuses rather than returns a drifted gradient. This gate
  detects *trajectory drift*; it does **not** detect a frozen derivative — which is why S1 fixes the
  soil-ψ read directly (§6.3), not via this gate.
- **Mesh derivative** — not computed; exact at the resolved mesh (locked).
- **IC gradients** beyond birth-rate — **deferred; diverges from catalog XII Q19** (which puts IC
  gradients in v1); fixed-IC scope means `ad_initial_state()` stays a thin seam and `scm.h:231`
  resume-forbids-replay is not exercised. Recorded as a divergence, not silent.
- **Second-order/Hessian**; the **stochastic engine** (§8.6 constraint).

---

## 14. Storage cost

Whole-object snapshots ≈ 2–3 KB × 6 stages × ~1–3 k steps ≈ ~30 MB/patch (real cost: per-stage
`tk::spline` coeff deep-copy). Fine for one patch × one gradient. Patch population / long horizon → the
§5.1 minimal-POD payload.

---

## 15. Build order + gates

0. Skeleton `value_type=S`; delete `ad_value.h`; kink manifest + CI grep; guards → active-safe.
0.5 **Scalar-generic guard layer (§11 Kind A), before Gate 0.** One `util.h` change makes the finiteness
   guards active-safe *at the definition* for all four strategies at once — so Gate 0 does not fix
   `ff16_strategy.h:617` at its call site and TF24's soil-reset guards need no new narrowing later. Cheap
   (one header), and the barrier the per-gate order would otherwise rediscover per strategy.
1. `EnvironmentRecording` (fingerprint §5.4) + `Coupling` (§6.1) + two overloads; `ResourceSpline` →
   odelia interpolator. FF16 env.
2. `QK::integrate<S>` + templated `CanopyShape`; **re-body MeanLight to `S`**; delete
   `integrate_ad`/`deep_crown_replay`/linearisation.
3. `growth_rate_gradient` one body (both FD schemes, per-call scratch); shared-strategy scratch invariant.
4. `height_seed` via `supplied_derivative` (+ §7.4 pair-filter in odelia).
5. Seeding (X-macro) + `stand_gradient_cpp` (table + fingerprint + cache precondition) + R wrapper
   (dimnames + low-level caveat + Control record).
6. FF16 verify, then TF24: mixed-scalar, soil state + `param_ptrs()`, soil ψ read active (§6.3), the leaf
   `∂profit/∂{θ,ψ}` set (gated §7.4), soil-in-recording, birth-rate at read sites (§8.5).

**Gate 0 (cheapest de-risk) [M7]:** `IndividualRunner` (`individual_runner.h`), a fixed-dimension
single-plant System, is the smallest in-scope AD target — validate the tape + `supplied_derivative` seam
there **before** the growing SCM.

**Gate 1 (pivotal) [M5]:** an active **multi-species, co-timed-introduction** run's reverse gradient
matches FD — exercising the **species-major mid-vector resize** (several blocks relocating in one step)
**and cross-species IC coupling** (seeding species-2's parameter moves species-1 cohorts via shading →
cross-species Jacobian columns). A single-species ≥2-introduction run does **not** exercise these.
Structurally sound (move-ctor preserves `slot_`; new-cohort ICs are taped intermediates) but the claim to
*execute*.

*Gate 1 status.* Single-cohort resident SCM matches FD **exactly** (all params, machine precision) and the
two-cohort forward value is bit-identical to the double replay. The two-cohort **gradient** currently lands
a clean, consistent **0.96×** FD across every seeded parameter — the ~4% residual is exactly the dropped
`∂(∂g/∂h)/∂θ` (the density-transport mixed partial). It is deferred, not miscomputed: differentiating the
`growth_rate_gradient` FD stencil on the outer tape is unreliable (a suppressed cohort's backward stencil
straddles the `size_dt` growth clamp, and `/eps` amplifies the kink to ~2.3× FD). Closing it is candidate B —
compute `∂g/∂h` off-tape in `double` and inject its parameter partials through `supplied_derivative` (the §7.4
`(slot,partial)`-pair filter), the same Kind-B seam TF24's leaf optimiser needs. This is the remaining Gate 1
work item.

**Gate 2:** the §7.4 pair-filter on the TF24-mutant witness (light+ψ frozen) — no `OutOfRange`, FD-match;
every seeded parameter has a leaf partial.

**Verification.** Resident + mutant FD-verified **at the fixed mesh** to ~1e-4 across all inputs, against
a real oracle (validated spike #553 Jacobians); the offspring/R0 axis FD-checked including a case that
would expose a wrongly-frozen birth stamp or a dropped establishment-at-birth term (§8.5).

**FD verification is a two-sided instrument — sweep the step, don't trust one.** A single small
`delta` can report a spurious ~1e-3 disagreement that is entirely the *oracle's* error, not the AD's:
where the metric contains an inner root-find or optimiser (`height_seed`, the leaf), the double oracle
re-solves it per perturbation to a finite tolerance, and that ~1e-8 noise divided by a small `2·delta`
blows up as `delta→0`. The AD gradient, being analytic, is **invariant to `delta`** — so the diagnostic
is to sweep `delta` and watch which side moves: a flat AD value with a U-shaped `|ad−fd|` (roundoff/
solver-noise as `delta→0`, truncation as `delta→` large) means the AD is right and you were reading the
oracle's floor. Gate 0's `height_seed` check showed exactly this — `lma`/`a_l1` sat at ~5e-4 at
`delta=1e-5` but the AD was bit-stable and matched to ~6e-5 in the oracle's clean band (`delta≈1e-4`).
Pick the comparison `delta` from the sweep's minimum, or tighten the inner solve's tolerance; never gate
on a single `delta` when the metric hides a solve.

**The environment query-height derivative is frozen on the ODE rate path (Kind A) [Gate 1 finding].**
`§0`'s spike proved active-query `eval(S)` and a passive-slope linearisation give the *bit-identical*
crown gradient — but that spike differentiated the **crown integral**, where the query points are
quadrature abscissae (fixed `double` fractions of the active bound). On the **ODE rate path** the query
height is different in kind: it is the cohort's own height, an **evolving tape state**. Recording the
interpolant's analytic tangent `spline.deriv(uv)` as `∂E/∂h` there injects a spurious `∂g/∂E·∂E/∂h` term
into the ODE Jacobian that **compounds across the fixed-step replay** — the resident light spline is
under-resolved at the infinitesimal scale AD probes, so its tangent is a poor estimate of the smooth
field's slope (the FD oracle, probing over a finite `2·delta` height shift, sees the well-behaved secant
and never the wild tangent). Measured on the K93 single-cohort resident SCM, `d(height)/d(b_0)` drifts
from ratio 1.00 at `t_end=5` to **17×** at `t_end=40` (value bit-identical throughout — a tape-only
error), and collapses to an exact FD match the moment the query-height derivative is frozen. Isolation
confirmed the interpolator itself is clean (AD=FD to 1e-11 for `d(eval)/d(knot)`), FF16/K93
`IndividualRunner` with a flat/fixed field is clean to `t_end=80`, and detaching either the knot-value
derivatives or `growth_rate_gradient` changes nothing — the spurious term is *only* the query-height
tangent, and *only* when the field carries a real slope at the cohort's height.

So on the rate path the environment is read at the **frozen operating-point height** (`get_value_at_height`
narrows the query to `xad::value(height)`). This is Kind A: the within-step spline read is a *diagnostic
sample of the field*, not a differentiation channel. Parameter sensitivity still flows through (a) the
**active knot values** — the resident self-shading channel, the actual Gate 1 target — and (b) the plant's
**explicit** height dependence in `compute_rates` (`b_1·log(size)`, the mass cascade); only the interpolant's
tangent w.r.t. its own evolving query point is dropped. Bit-identical on the `double` path. The four
strategies each read the field on their rate path, so each needs the frozen query (K93 done at Gate 1;
FF16/TF24 to match — their crown-integral reads, validated bit-identical in `§0`, are a separate site and
unaffected).

---

## 16. Kill-condition map

- Second differentiable System needing indexed replay with a non-scalar snapshot → odelia
  `SubStateRecorder` of opaque `vector<double>`.
- Mutants cut + resident soil non-stiff/active → knots-only recording.
- Scope collapses to FF16-field-only/mutant-only → `Coupling` loses its second shape → plain `requires`.
- Schedule stops being frozen-on-the-double-pass (adaptive sub-step replay) → fixed-`double` snapshot +
  "mesh not differentiated" both break — the largest future redesign.
- RAM binds → §5.1 minimal-POD payload.

---

## Appendix A — surface-by-surface change index

`internals.h` keep, `aux` is `S`, never snapshotted · `individual.h` de-twin, keep `<It>` · `node.h`
de-twin, one `growth_rate_gradient`, birth stamps `double` (completeness §8.5) · `species.h`/
`species_base.h` keep `census<Psi>`+`<It>`, de-twin, birth-rate at read sites · `patch.h` `value_type=S`,
`static_assert(Coupling)`, host recording+fingerprint, two overloads, `height_max` double used only on
record pass (§5.5) · `scm.h` runnable interface (§1), growing `run()` · `parameters.h` double, IC seam
deferred (§13) · `strategy.h` unchanged · `ff16_strategy.{h,cpp}` one-body crown, `height_seed` seam,
X-macro, MeanLight→S, `recruitment_decay` time-term noted, frozen `r_l` no-change, delete kernel ·
`tf24_strategy.{h,cpp}`/`tf24f_strategy.h` mixed-scalar (double `Leaf`, `Internals_<S>` aux), leaf seam
incl `∂/∂ψ`, tracked-ψ into cohort `Internals` not shared strategy · `k93_strategy.{h,cpp}` template, two
kinks · `ff16_environment.h`/`k93_environment.h` satisfy `Coupling`, field-only · `tf24_environment.h`
satisfy `Coupling`, soil state + `compute_state_rates` + `param_ptrs()`, **soil ψ read active, no double
cache** (§6.3) · `qk.h` one `integrate<S>` · `canopy_shape.h` template profile · `resource_spline.h`
route to odelia interpolator, delete `get_environment_deriv_at_height` · `qag.h` untouched (dormant) ·
`adaptive_interpolator.h` delete · `ff16_production_kernel.h` delete · `ad_value.h` delete ·
`emergent_functional.h` keep · `extrinsic_drivers.h` climate fixed-data-not-targets, `birth_rate` at read
sites (§8.5) · `disturbance_regime.h` **no change** — stamps `patch_density_at_birth`/`pr_patch_survival`
(`node.h:59,152`), differentiable in principle, **not a v1 target** · `control.h` reference Control
stated (§8.4), Euler out · `stochastic_*.h` **no change**, `double` path must keep compiling (§8.6) ·
`individual_runner.h` Gate-0 de-risk (§15) · `stand_gradient.{cpp,R}` dispatch table + fingerprint +
cache precondition + low-level caveat + Control record · **new:** `environment_recording.h`,
`coupling.h`, the X-macro `.def`s. odelia: consume as-is + the `supplied_derivative` `(slot,partial)`-pair
filter (§7.4); optional `basic_interpolator::operator()(S)` active-query (§4.4).
