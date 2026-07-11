# AD touch-point catalog: reverse mode across *all* plant systems

Built from an exhaustive four-part survey of `plant:develop` (strategies; environments +
adaptive numerics; the shared hierarchy + R boundary; every iterative solver) and read
against `odelia:claude/ad-surface` + [odelia#28](https://github.com/aornugent/odelia/issues/28).
Its purpose is the one the two attempts skipped: enumerate **everything** that must change
to run every plant system (FF16, TF24, TF24f, K93) at a templated scalar `S` under
reverse-mode AD, then **cluster** the touch points so we solve at the level of *mechanism*,
not *component*. The per-issue plan (AD-1…AD-11) is the wrong altitude — it slices by
deliverable, which is exactly what put a frozen-double boundary first and made both attempts
build scaffolding they then had to unpick.

Two invariants frame everything below:

- **Only `double` crosses to R.** Guaranteed structurally: the object lives behind an
  RcppR6 `XPtr` (`RcppR6_support.hpp:102`) and never serialises; only method *return
  values* marshal, and every one in `RcppR6_classes.yml` is `double`/`List`/`NumericMatrix`.
  Internals can go active without touching the boundary.
- **The two run types are data-presence, not modes** (odelia#28): **resident** ⇒ L3 empty ⇒
  recompute the background *active* on frozen L2 knots (self-shading flows); **mutant** ⇒ L3
  populated ⇒ read recorded `double` background by `(step,stage)` index (derivative zero by
  construction). `has_recorded_field()` is a query, not a state machine.

---

# Part I — The complete touch-point inventory

Eight layers, ordered from model-agnostic foundation to model-specific numerics. Each row is
a stone.

## Layer 0 — The R boundary (must stay `double`; the invariant to protect)

| Touch point | File:line | Note |
|---|---|---|
| RcppR6 exposure of SCM/Patch/Species/Node/Individual/Parameters/Internals + all 4 strategy/env pairs | `RcppR6_classes.yml:387–763` | every `return_type` is `double`/`vector<double>`/`List`/`NumericMatrix`/`SEXP` — never a scalar template |
| `odelia::ode::r_ode_state/r_ode_rates/r_set_ode_state/r_derivs` | `odelia .../ode_interface.hpp:171–224` | the fixed `vector<double>` funnel every `ode_*` binding routes through |
| Hand-written boundary TUs | `strategy_expand.cpp:74–99`, `proto3_leaf_edge.cpp:47–80` (the doubles-in/doubles-out exemplar), quadrature/util glue | the only hand-written marshalling; new AD entry (`stand_gradient.cpp`) joins these |
| Regeneration | `Makefile:16–25` (`compileAttributes`, `RcppR6::RcppR6()`) | generated `RcppExports.*`/`RcppR6.*` never hand-edited |

## Layer 1 — The scalar-carrying skeleton (model-agnostic; one templating cut)

| Class | File | State today | Must carry `S` |
|---|---|---|---|
| `Internals` | `internals.h:14` | hard-`double`; 4 `vector<double>` (states/rates/auxs/consumption_rates) | the root storage — everything rests on this |
| `Individual` | `individual.h` | `T,E`; no scalar; holds `Internals vars:180` | state/rate/aux accessors, `compute_competition`, `net_mass_production_dt` |
| `Node` | `node.h` | hard-`double`; own bookkeeping `:107–116` | `log_density(_dt)`, `density`, `offspring_produced_survival_weighted(_dt)`, `weighted_fecundity`, `compute_rates:131–155` |
| `Species`/`SpeciesBase` | `species.h`, `species_base.h` | CRTP double | `compute_competition` trapezium `:197`, `net_reproduction_ratio_by_node[_weighted]`, `consumption_rate` |
| `Patch` | `patch.h:22` | **`using value_type = double`** | the `System::value_type` odelia reads; fitness/offspring block `:453–500`, `resource_depletion` |
| `SCM` | `scm.h` | double; owns `Solver<patch_type>:133` | `value_type` + `rebind` for the driver |
| `Parameters` | `parameters.h` | POD config, double | stays double (crosses R) *except* `initial_state` seeds `S` state |

**The single most pervasive item:** every `set_ode_state`/`ode_state`/`ode_rates`/`ode_aux`
across Individual/Node/SpeciesBase/Species/Patch/Environment is typed against the concrete
`odelia::ode::const_iterator`/`iterator` = `vector<double>::iterator`
(`ode_interface.hpp:16–18`). This one concrete type is what forces the scalar through the
whole ODE-serialisation surface.

## Layer 2 — Per-strategy physiology (the models)

| Strategy | File | Difficulty | AD-hostile content |
|---|---|---|---|
| **K93** | `k93_strategy.h/.cpp` | **trivial** | closed-form; no iteration, no quadrature; 11 params; **no virtuals, no member pointers**. Kinks: `if(growth<0)growth=0` `:117`, `(mu>0)?mu:0` `:139`. The free win once the skeleton templates. |
| **FF16** | `ff16_strategy.h/.cpp` | moderate | ~40 params; virtuals `net_mass_production_dt:273`, `fraction_allocation_reproduction:296`; member pointer `assimilation_fn:244`; one `uniroot` (`height_seed:530`); `QK` crown integral; production kernel already templated (`ff16_production_kernel.h`) |
| **TF24** | `tf24_strategy.h/.cpp` | **hard** | ~50 params incl. init-derived (`c/b/psi_crit/jmax_25`); virtuals + `solve_leaf:226`; the **leaf optimizer nest** (Layer 6); `integrate_vector` over QK nodes; hundreds of nested root-finds per rate eval |
| **TF24f** | `tf24f_strategy.h/.cpp` | **hard** | derives TF24; adds **one extra ODE state** `opt_root_psi_state`; `solve_leaf` becomes gradient-ascent tracking; already consumes forward-mode leaf AD (`use_ad_gradient`, `dprofit_droot_collar_psi`) |

Cross-cutting per-strategy: `virtual` methods survive per-instantiation (template the class,
not the method); `assimilation_fn` member pointer (FF16 only — TF24 already uses a
`ShadingModel` enum branch); the annual-factor integer product `60*60*12*365` kept
un-collapsed for FP rounding (`tf24_strategy.cpp:16`).

## Layer 3 — Environments

| Environment | File | State | Background the plant reads |
|---|---|---|---|
| `FF16_Environment` | `ff16_environment.h:15` | `ResourceSpline light_availability`; PPA params | `get_environment_at_height → step_light(spline)`; **the one FF16 light read** |
| `K93_Environment` | `k93_environment.h:12` | `ResourceSpline` only | raw `get_value_at_height` (no step_light); relies on the spline `max(0,·)` floor |
| `TF24_Environment` | `tf24_environment.h:16` | spline **+ full soil-water bucket model** (multi-layer, `psi_soil` cache, hydraulic params) | light + soil water potential; **many positivity clamps/floors** `:218,248,267,277` — a whole extra differentiable surface |

## Layer 4 — Adaptive numerics (classified L2 / L3 / fixed-rule / kink)

| Construction | File:line | Class | Fate |
|---|---|---|---|
| plant `AdaptiveInterpolator::construct/refine` | `adaptive_interpolator.h:62,96` | **L2** (records knot x-positions) | **duplicate of odelia's** — delete, route to odelia |
| odelia `basic_interpolator::construct` | `odelia .../interpolator.hpp:36` | **L2, already S-templated** (positions `double` via `xad::value`, values `S`) | the target; retire plant's (odelia#22) |
| `ResourceSpline` (FF16/K93/TF24 light) | `resource_spline.h:16` | L2 wrapper; fast path *reuses* positions (`rescale_spline:151`) | route through odelia interpolator |
| `QK` fixed Gauss–Kronrod | `qk.h:61` | **fixed rule** — nodes = affine images of fixed abscissae in `[0,height]` | template on scalar+bound; **no** position recording needed (active bound is fine) |
| `QAG` adaptive subdivision | `qag.h:187` | **L2 intervals** *but `max_iter=1` everywhere → dormant/fixed* | not a v1 L2 site; replay API already exists (`integrate_with_intervals`) |
| `CanopyShape` | `canopy_shape.h:99` | precomputed `double` shape; fn-pointers `pow_eta_`, `leaf_above_` | positions/coordinates the argument, not the shape — see Cluster B |
| `refine_schedule` (introduction times) | `scm.h:335` | **L1-adjacent** (time-node schedule) | recorded `ode_times` replayed for mutant; L0 stays double |
| adaptive RKCK stepping | `scm.h:283` / odelia Solver | **L1** (recorded step schedule) | already odelia's `advance_fixed(recorded_steps())` |
| `ff16_...deep_crown_replay` kernel | `ff16_production_kernel.h:111` | **record-weights/replay** sketch | a third pattern already present; reconcile with QK-active-bound |

## Layer 5 — Iterative solvers (the `supplied_derivative` sites)

| Solve | File:line | Iters | Solves for | IFT partial needs |
|---|---|---|---|---|
| FF16 `height_seed` | `ff16_strategy.cpp:530` | data-dep (bisect) | seed height: `mass_live_given_height(h)=omega` | `dh/dθ` (depends on **lma** via `mass_leaf=area_leaf·lma`) — **the A-vs-B divergence** |
| TF24 `height_seed` | `tf24_strategy.cpp:720` | data-dep | same, TF24 allometry | same shape |
| `resource_compensation_point` | `individual.h:162` | data-dep | env level where `net_production=0` | diagnostic/R-facing — may be out of v1 |
| **Leaf optimizer (outer)** `find_root_collar_psi` | `leaf_model.cpp:808` | **fixed** (golden-section, by design) | argmax profit over collar-ψ | smooth argmax already; IFT seam `dprofit_droot_collar_psi:900` |
| Leaf `find_root_psi` (soil→collar) | `leaf_model.cpp:606` | data-dep (TOMS748) | collar-ψ continuity | nested inside optimizer |
| Leaf `psi_stem_to_ci` | `leaf_model.cpp:1280` | data-dep (TOMS748) | leaf CO₂ `ci` | IFT hand-coded `:933–937` |
| Leaf `dprofit_dvcmax25` | `leaf_model.cpp:980` | — | envelope-theorem trait grad | first TF24 trait gradient (PROTO-3) |

## Layer 6 — The nested FD gradient (a rate, not a metric)

`Node::growth_rate_gradient` (`node.h:191–220`) finite-differences `d(growth)/d(height)` and
**feeds it into `log_density_dt`** (`node.h:138`) — it is part of the ODE right-hand side, not
an output metric. Under a trait gradient it must stay **active in the trait** (the FD is over
height, a fixed perturbation; the trait derivative flows through each `growth` evaluation).
**Both attempts `ad_value`'d it — dropping the trait sensitivity of the characteristic
equation.** Its `thread_local` scratch individual (`node.h:200`) must also be active or the
derivative is lost there. This is its own subtle site: a FD-derivative that must remain
active, using an active scratch. (The FD primitives `gradient_fd`/`gradient_richardson`,
`gradient.h:16–121`, are hard-`double`.)

## Layer 7 — run vs run_mutant and the record/replay hooks

| Mechanism | File:line | Under AD |
|---|---|---|
| `set_mutant()` sets `is_mutant_run/use_cached_environment`, `save_RK45_cache=false` | `patch.h:242` | becomes "populate L3" per odelia#28 |
| resident `set_ode_state(it,double time)` — recompute env | `patch.h:679` | L2 recompute path (active on frozen knots) |
| mutant `set_ode_state(it,int index)` — `environment_ptr=&environment_history[idx][index]` | `patch.h:707` | L3 recorded-double read |
| `cache_RK45_step`/`cache_ode_step`/`load_ode_step` (renamed `record_stage`/`record_ode_step`/`replay_step`) | `patch.h:727–775` | the odelia `Replayable` hooks |
| `compute_environment` skips when `is_mutant_run` | `patch.h:562–571` | mutant never shapes the field |
| self-competition suppression `is_mutant_run` gates | `patch.h:427,438` | model concern, orthogonal to replay mode |

## AD-hostile primitives (cross-cutting, all layers)

`util::uniroot`/`uniroot_smooth` (`uniroot.h`, double-only bracketing); `util::golden_section_max`/
`brent_fmin` (`optimize.h`, double); `util::is_finite` + `util::stop` throw-guards sprinkled
through every rate path (gate on `double`, throw on active); `std::numeric_limits<double>`,
`M_PI`; `boost::math::tgamma_lower` (leaf vulnerability seed); `std::pow/exp/sqrt/log`
(fine by ADL) and the kinks catalogued in Layer 2/3.

---

# Part II — Clustering: the fundamental solve-classes

The ~120 individual touch points above collapse into **seven mechanisms**. Solve each once,
model-agnostically, and the four strategies fall out — because everything model-specific
reduces to *supplying two things* (leaf IFT partials; a kink classification). This is the
payoff the per-issue plan misses: it is **7 mechanisms, not 4 strategies × N components**.

For each cluster: the assumption it challenges, and **the class of problem it makes
impossible**.

### Cluster 1 — The scalar skeleton, threaded through one iterator seam
**Touch points:** all of Layer 1 + the `set_ode_state`/`ode_state`/`ode_rates` surface.
**Fundamental fix:** propagate `value_type = S` by the existing `<T,E>` templates (AD-1
already does this correctly), **and template the ODE-serialisation *iterator* in odelia
once** (`ode_interface.hpp:16`) so plant does not hand-roll iteration loops in five files.
**Challenges:** "plant must re-implement odelia's `set_ode_state(begin,end,it)` to template
it" (Attempt A forked it into 5 files). **Makes impossible:** the plant/odelia iteration
fork drifting — there is one iteration, in odelia, over a templated iterator.

### Cluster 2 — Freezing is *data presence*, never an operation ⭐ (the big one)
**Touch points:** every `ad_value()` (A, ~20) and every `!is_same_v<double>` overload +
`xad::value()` guard (B, ~8 functions across canopy/env/spline); the resident vs mutant
`set_ode_state` fork; the whole `environment_history` machinery.
**Fundamental fix:** template `FF16_Environment`/`ResourceSpline`/`CanopyShape` on `S`, and
make the *only* way a background becomes frozen `double` be **reading it from the recording**
— L3 (`has_recorded_field()` → recorded-double by index) or L2 (recompute active on recorded
knots). No physiology function ever calls `value()` on a background quantity. Resident and
mutant then differ by *one data query*, not by scattered extractions or twin overloads.
**Challenges:** the design's build order — **"invasion first, resident canopy frozen as
`double`."** That sequencing is what creates a mixed-scalar model *before* the environment is
templated, voiding uniform-`S` exactly where it was supposed to hold, and forcing both devs
to hand-service the boundary. Template the environment from the start and the boundary never
exists. **Makes impossible:** the entire "which `ad_value`/overload is a safe freeze vs a
silently-dropped derivative?" audit class — the single largest source of debt in *both*
attempts. If freezing can only be a recorded read, a dropped derivative is a
missing-recording error (loud), not a plausible-wrong number (silent).

### Cluster 3 — One replayable interpolator (L2), by deletion
**Touch points:** plant `AdaptiveInterpolator`, `ResourceSpline` construct/rescale, the
(dormant) QAG interval machinery.
**Fundamental fix:** retire plant's `AdaptiveInterpolator` and route `ResourceSpline` through
odelia's already-S-templated `basic_interpolator` (positions `double`, values `S`, `construct`
freezes placement, `init` rebuilds fixed) — odelia#22. The cross-run knot recording lives in
the Patch via the `Replayable` hooks; the interpolator owns its knots.
**Challenges:** "plant owns its adaptive refiner." It owns a *duplicate* of odelia's.
**Makes impossible:** two refiners drifting; L2 becoming interpolator-specific (any future
adaptive component records positions through the same hook).

### Cluster 4 — Fixed-rule quadrature is one templated body
**Touch points:** `QK::integrate` (FF16 crown/mean-light), the forked `integrate_ad` (B), the
`deep_crown_replay` weight-recording kernel.
**Fundamental fix:** template `QK::integrate` on the scalar + bound type; the `double` path is
the `S=double` instantiation. A fixed rule has no adaptive branching, so an active bound
(moving nodes in `[0,height]`) tapes cleanly — **no position recording needed** for QK.
Reconcile the three variants (double `integrate`, B's `integrate_ad`, the replay kernel) into
one.
**Challenges:** "the crown integral needs recorded node positions (L2)." It doesn't — it's a
*fixed* rule; only adaptive constructions need L2. **Makes impossible:** a second copy of the
GK loop (B's `integrate_ad`) drifting from `integrate()`; the confusion between "fixed rule
with active bound" and "adaptive placement."

### Cluster 5 — One iterative-solve seam (`supplied_derivative`)
**Touch points:** `height_seed` (FF16 + TF24), the leaf optimizer nest, `psi_stem_to_ci`,
`find_root_psi`, `resource_compensation_point`.
**Fundamental fix:** every data-dependent solve uses the *same* sanctioned pattern — solve in
`double`, register the result as a leaf, hand the reverse sweep its analytic IFT partial via
`odelia::ode::supplied_derivative` (proven by PROTO-3). Never tape through an iteration. The
leaf optimizer's IFT partials already exist (`dprofit_droot_collar_psi`, `dprofit_dvcmax25`);
`height_seed`'s is a one-line IFT on `mass_live_given_height`.
**Challenges:** "each solve reattaches its own derivative however it likes." That is exactly
where A (correct IFT) and B (dropped it, with a *provably wrong* justification — `area_leaf`
has no `lma` dependence) diverged at the *same undocumented spot*. **Makes impossible:** the
"did we reattach this root's derivative, and is the trick reverse-mode-correct?" class — one
mechanism, tested once, used everywhere.

### Cluster 6 — The nested characteristic-equation derivative
**Touch points:** `Node::growth_rate_gradient` + its `thread_local` scratch; the
`gradient_fd`/`gradient_richardson` primitives.
**Fundamental fix:** decide *once* how `d(growth)/d(height)` carries its trait derivative into
`log_density_dt` — keep the FD but make the scratch and the result **active in the trait** (do
not `ad_value` it), or replace it with an inner AD derivative. Both attempts froze it; that
silently drops the trait sensitivity of the SCM characteristic equation.
**Challenges:** "the growth-rate gradient is just a number we can take in `double`." It is a
*rate*, and under a trait gradient it is a cross derivative that must flow. **Makes
impossible:** a whole-stand gradient that looks right but is missing the density-transport
term — the hardest kind of silent error to catch, because the value is unaffected.

### Cluster 7 — Kink classification (the test manifest, not a mechanism)
**Touch points:** `max(0,spline)`/`cap→1.0` (`resource_spline.h:88`), K93 `growth`/`mu`
clamps, FF16 `step_light`/`smooth_floor`, `CanopyShape` box/softbox steps, TF24 soil
positivity resets, leaf `abs(·)<1e-8` special-cases, every `is_finite`/`stop` guard.
**Fundamental fix:** this one does *not* reduce to a single mechanism — instead classify each
kink **once** into three kinds and record the decision: (a) piecewise-constant *selector*
(branch on the passive value is correct; derivative structurally zero — e.g. PPA layer index);
(b) genuine *kink* (document the subgradient choice); (c) *guard* (throw path, off the
differentiated domain — must not be hit at the operating point). The output is a review
manifest, not code.
**Challenges:** "a clamp is just a clamp." Each is a derivative decision. **Makes impossible:**
a silently-wrong subgradient shipping unnoticed — every kink has a recorded, tested verdict.

---

# Part III — What the clustering implies

**Sequence by mechanism, not by deliverable.** The design's order (FF16 invasion → census →
resident → TF24 → birth-rate) is what forced the frozen-double boundary to the front and made
both attempts build invasion-specific freezing they then had to unpick for resident. The
mechanism order removes the boundary before anything is built on it:

1. **Cluster 1 + 2** (scalar skeleton + templated environment, frozen only via the recording)
   — after these, *invasion and resident are the same code path*, differing only by whether
   L3 is populated. No invasion-only scaffolding.
2. **Cluster 3** (L2 interpolator unification — a deletion).
3. **Cluster 4** (one templated quadrature).
4. **Cluster 5** (the `supplied_derivative` seam) — unlocks `height_seed` (FF16) and the leaf
   optimizer (TF24) with one mechanism.
5. **Cluster 6** (the characteristic-equation derivative) — the correctness crux for
   *resident*.
6. **Cluster 7** (kink manifest) — runs alongside as the test gate.

**Per-strategy residual after the mechanisms land:**
- **K93** — essentially free (closed-form; template the class, classify two kinks).
- **FF16** — the crown integral (Cluster 4) + `height_seed` (Cluster 5) + resident
  characteristic term (Cluster 6). No leaf model.
- **TF24** — the leaf optimizer nest, but *only* as "supply the IFT partials to Cluster 5"
  (they mostly exist) + the soil-model kinks (Cluster 7). The nesting depth is real but the
  *mechanism* is already proven (PROTO-3).
- **TF24f** — TF24 plus one extra tracked ODE state; the gradient-ascent `solve_leaf` already
  consumes forward-mode leaf AD.

**The three assumptions to overturn, in priority order:**
1. **Invasion-first / frozen-double environment** (Cluster 2) — the highest-leverage reversal;
   it deletes the boundary that generated most of both attempts' debt.
2. **Freezing is an operation code performs** (Cluster 2) — make it data-presence only.
3. **Each iterative solve owns its derivative** (Cluster 5) — one seam, killing the
   `height_seed` divergence class.

The net: a **deletion-heavy** plan (retire plant's refiner, collapse forked quadrature,
remove every hand-serviced boundary), not the addition-heavy scaffolding both attempts
produced — which is what the implementation spec promised and neither delivered.
