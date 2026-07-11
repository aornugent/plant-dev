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

> **Read Part V first if you want the forest.** Parts I–IV enumerate the trees (every
> touch point, the clusters, the Chesterton's-fence investigations). **Part V** steps back
> to the *System* level — what FF16/TF24/TF24f/K93 actually need on their differentiable
> graph for the forward and backward passes — and finds that the differentiable **core** is
> small and nearly model-invariant, while most of the code the two attempts were templating
> is **off the graph** and should stay `double` or be deleted. Part V is the lens; Parts
> I–IV are the ground truth it rests on.
>
> **Then read Part VI — it is the honest correction.** Parts I–V analysed the SCM as if it
> were a plain odelia `Solver`. It is not: it is a **growing-dimension** system (cohorts
> introduced mid-run resize the ODE state), sitting under a workflow layer (equilibrium,
> assembly) that has moved to a separate package, alongside a whole second (stochastic)
> engine that shares its hierarchy. Part VI surfaces that wider ground and the open questions
> it raises — several of which the earlier parts are too clean about.

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

### Cluster 3 — One recorded-adaptive-positions / replay-fixed abstraction ⭐ (revised by pressure test — see Part IV)
**Touch points:** plant `AdaptiveInterpolator` + `ResourceSpline` (spline knots), QAG
`get_last_intervals`/`integrate_with_intervals`/`rescale_intervals` (quadrature intervals),
the ODE `ode_times` record + `advance_fixed` replay (time schedule) — **three existing,
hand-rolled implementations of one pattern**, all sharing `util::rescale`, all predating AD.
**Fundamental fix:** recognise these as one abstraction — *record adaptive positions once in
`double`, replay (optionally rescaled) on fixed positions* — of which odelia's already-S-
templated `basic_interpolator` (positions `double`, values `S`; `construct` freezes placement,
`init` rebuilds fixed) is the AD member. Retire plant's `AdaptiveInterpolator` and route
`ResourceSpline` through odelia's (odelia#22); the cross-run knot recording lives in the Patch
via the `Replayable` hooks. AD's L2 is then not a new mechanism — it is this family's
S-templated instance.
**Challenges:** "plant owns its adaptive refiner" (it owns a *duplicate* of odelia's) and,
deeper, "record/replay is an AD concern" — it is a pattern plant already implements three
times for non-AD reasons (Part IV). **Makes impossible:** N refiners drifting; L2 becoming
interpolator-specific; and the false belief that AD introduces record/replay rather than
reusing it.

### Cluster 4 — Fixed-rule quadrature is one templated body (differentiate *through*) — confirmed + sharpened by pressure test
**Touch points:** `QK::integrate` (FF16 crown/mean-light), the forked `integrate_ad` (B), the
`deep_crown_replay` weight-recording kernel (#540 spike, test-only — Part IV).
**The distinction that resolves it:** *fixed rule vs adaptive rule.* A **fixed** rule (QK — what
the crown integral actually uses) places nodes as a deterministic function of the bound, so an
active bound (moving nodes in `[0,height]`) tapes **exactly**, including the half-length Jacobian
and `dq/dheight` — no branching to corrupt the tape, **no position recording**. An **adaptive**
rule (adaptive QAG, the spline) makes a data-dependent subdivision decision that must not be
taped → that is Cluster 3's recorded-positions path. The crown integral is fixed, so it is
Cluster 4, not L2.
**Fundamental fix:** template `QK::integrate` on the scalar + bound type; the `double` path is
the `S=double` instantiation. Reconcile the three variants into this one — and **delete
`deep_crown_replay`**: it freezes the nodes *and* folds `q` into a frozen `double` weight, so it
silently drops `dA/dheight` (correct only for the restricted fixed-height resident-light partial
#540 validated, **wrong** for the full trait gradient where height is an active state). It is a
partial spike, not the general treatment.
**Challenges:** "the crown integral needs recorded node positions (L2)" (it doesn't — fixed
rule) *and* "`deep_crown_replay` is the AD design for the crown integral" (it is a partial
optimisation that drops a real term). **Makes impossible:** a second GK-loop copy drifting from
`integrate()`; the fixed-vs-adaptive confusion; and a **third silent A-vs-B divergence** — the
crown integral currently has two in-tree AD treatments (`deep_crown_replay` vs `integrate_ad`)
computing different derivatives, with the design silent on which is right.

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

---

# Part IV — Pressure test: Chesterton's fences and the pattern behind them

> **Correction (see Part VI).** This part over-weighted QAG. The "record adaptive positions →
> replay fixed" *pattern* is real, but its one AD-relevant instance is the **adaptive light
> interpolator** (L2, for the resident self-shading gradient — `ad-record-replay.md` §3). QAG's
> adaptive path is a dormant fossil, and the ODE schedule is **L1** (Solver-owned), not L2 — so
> the "three co-equal instances, L2 is the fourth consumer" framing below conflates L1/L2 and
> inflates QAG. Read Part VI for the corrected model and the much larger surface these fences
> distracted from.

Two constructs looked like cruft. Investigating *why they exist* (not just whether they're
used) turned up the general pattern the whole design should rest on.

### Fence 1 — QAG's adaptive path is set to `max_iterations = 1` everywhere. Is it dead?

**No.** The `1` is only the **default constructor** value (`qag.cpp:10`); the parameterised
ctor takes any `max_iterations`, and the whole adaptive machinery — `integrate_adaptive`
(`qag.h:85`), `refine`/worst-interval bisection (`:188`), and crucially the **replay** API
`get_last_intervals`/`integrate_with_intervals`/`integrate_with_last_intervals` +
`rescale_intervals` (`qag.h:112–144`, `qag_internals.cpp:93`) — is intact, R-exposed
(`RcppR6.cpp:991`), and exercised adaptively by `test-qag.R` (`max_iterations=100`,
line 171). It dates to the **original QAG port** (`fe60adcd`, "Port adaptive quadrature"),
long before AD. `integrate_with_intervals` even *requires* `adaptive==true`.
**What it is:** plant's *original* "run the adaptive controller once, **record the
subdivision**, then replay/rescale that fixed subdivision cheaply on later steps" mechanism —
built for the light integral before that moved to the spline. The leaf model's `max_iter=1`
is a deliberate *fixed-rule* choice (`leaf_model.h:276`), not neglect.

### Fence 2 — `ff16_production_kernel.h` / `deep_crown_replay`. Cruft?

**Partly — and instructively.** `#540` ("First slice of end-to-end AD for FF16") added the
whole kernel as an AD milestone spike. Two halves:
- **Per-piece kernels** (`ff16_area_leaf`, `_assimilation_leaf`, `_respiration`, `_turnover`,
  `_net_production_A`) — legitimately delegated to by `FF16_Strategy` (single source of
  truth). Keep (or inline).
- **Composite replica** (`FF16ProdPars`, `ff16_net_from_components`,
  `ff16_net_mass_production_crown_top`, `ff16_assimilation_deep_crown_replay`) — **used only
  by the three AD test files**, never by production `FF16_Strategy`. A parallel copy of the
  net-production chain, built to validate AD *before the real class was templated*. Now that
  AD-1 templates `FF16_Strategy` itself, it is the "parallel near-copy" the code style
  forbids. **Delete.** And `deep_crown_replay` specifically freezes the crown nodes *and*
  folds `q` into a frozen `double` weight — so it drops `dA/dheight`; `#540`'s own scope note
  says it does "not differentiate" the crown schedule. Correct only for the fixed-height
  resident-light partial it validated; **wrong for a full trait gradient where height is an
  active state.**

### The pattern behind both fences (the Pólya move)

QAG interval-replay and the spline knot-replay are the **same idea**, and plant implements it
**three times, all sharing `util::rescale`, all predating AD**:

| Instance | Record | Replay / rescale |
|---|---|---|
| QAG adaptive quadrature | `get_last_intervals` | `integrate_with_intervals` / `rescale_intervals` (`qag.h:112`) |
| Light/resource spline | `AdaptiveInterpolator::construct` knots | `ResourceSpline::rescale_spline` (`resource_spline.h:152`, `util::rescale:157`) |
| ODE time schedule | `refine_schedule` → `ode_times` | `advance_fixed(ode_times)` (mutant fitness) |

**"Record adaptive positions once in `double`, replay on fixed (rescaled) positions" is not
an AD requirement — it is a pattern plant already has in triplicate for performance and
mutant-fitness reasons.** odelia's replayable interpolator is simply the `S`-templated member
of this family. So AD's L2 is the *fourth* consumer of an existing abstraction, not a new
mechanism (this is what sharpens Cluster 3). And the fence reward is a deletion list, not a
port: **QAG's adaptive path, `deep_crown_replay`, and the composite kernel are all off every
System's differentiable graph (Part V) — none needs to be taped or carried along.**

---

# Part V — The System view: the differentiable core vs the shed

Step past the code to the *System*. Under odelia, each plant model is an ODE System: a state
vector and a right-hand side. Reverse-mode AD differentiates one reduction of an integrated
run with respect to seeded traits. The only thing that must be **active (on the tape)** is the
path from a seeded trait to the emergent metric *that is computed by taped arithmetic*.
Everything else is off the graph. The two attempts templated by *file*; the System view
templates by *graph membership* — and the graph is far smaller than the code.

### The activation rule (one principle, replaces "template every `double`")

> A quantity goes **active** iff it lies on the differentiable path from a seeded trait to an
> emergent metric **and** is produced by taped arithmetic (the ODE state, and the algebra that
> maps state+background → rates). A quantity produced by **iteration, optimisation, or
> adaptive refinement** never goes active — it stays `double` and enters the tape, if at all,
> as (a) a **recorded value** (L2 knots / L3 background) or (b) an **injected analytic
> derivative** (`supplied_derivative`). Diagnostics, error estimates, schedule control, and R
> facades are off the graph entirely.

### The universal differentiable core (identical across all four Systems)

The **demographic skeleton** — this is model-agnostic and is the whole of what AD-1 should
activate:
- per-cohort ODE state `{height, mortality, fecundity, (+ model extras)}` and the node
  bookkeeping `{log_density, offspring_produced_survival_weighted}` + their rates
  (`node.h:131–155`);
- the pure-arithmetic map `(state, background) → rates`;
- the **background read** — active value from L2-recompute (resident) or L3-frozen-`double`
  (mutant); the background *construction* is never active;
- initial conditions: `establishment_probability` (closed-form, active), `height_seed`
  (root-find → `supplied_derivative`, Cluster 5);
- `Node::growth_rate_gradient` = `∂g/∂height`, nested, active (Cluster 6).

### Per-System core delta (the science)

| System | What's ADDED to the skeleton, and its AD treatment | The shed (stays `double` / deleted) |
|---|---|---|
| **K93** (`k93_strategy.cpp:80–140`) | closed-form `size_dt`/`fecundity_dt`/`mortality_dt` reading `cumulative_basal_area = -log(light)/k_I` — **pure active arithmetic**, two kinks (`growth<0→0`, `mu>0?mu:0`) | nothing model-specific; light-spline construction is recorded `double` |
| **FF16** (`ff16_strategy.cpp`) | mass cascade (active arithmetic) + crown integral `∫₀ʰ assim_leaf(light(z))·q dz` — **fixed QK rule, active bound, differentiate through** (Cluster 4) | `deep_crown_replay` + composite kernel **deleted**; light-spline construction recorded `double` |
| **TF24** (`tf24_strategy.cpp:308–485`) | net production = same algebra, but `assimilation = leaf.profit_ · area_leaf · …` where `profit_` is the **outcome of the leaf optimiser**. By the envelope theorem `d(profit*)/d(input) = ∂profit/∂input` at fixed ψ* → **`profit` is a `supplied_derivative` node**: leaf solved in `double`, inject `∂profit/∂{trait, light, height, soil}`. Crown aggregation is fixed QK (Cluster 4). | **the entire `leaf_model.cpp`** (golden-section + two TOMS748 root-finds + four splines, ~1500 lines) **stays `double`** — never templated on `S`; the four leaf splines use analytic `.deriv()`; the QAG integrator is fixed (`max_iter=1`) |
| **TF24f** (`tf24f_strategy.cpp:26–114`) | **the cleanest**: the optimum ψ* is a **tracked ODE state** `opt_root_psi_state` with rate `k_acclim · dprofit_dψ` (`:37`) — an analytic derivative (`dprofit_droot_collar_psi`) put **on the tape as a rate**; `profit` at the tracked ψ is a supplied value. The golden-section optimiser runs only at birth (`set_initial_states`). | same leaf internals in `double`; one extra active state |

The pattern: the active core is the **skeleton + a few lines of rate arithmetic per model**;
each model's expensive, iterative, model-defining machinery (the leaf, the soil bucket) is a
`double` black box that touches the tape only through an injected derivative.

### The invasion↔resident environment cut (correcting both attempts)

The environment's role is entirely determined by run type, and neither attempt cut it right:

- **Invasion (mutant, v1's first proof):** the mutant reads the resident canopy **frozen as
  `double`** (L3). The active surface is *only the mutant's own physiology + skeleton*. The
  environment needs **zero templating** — read a recorded `double`. (This is why A, which
  froze the environment, reached an invasion entry; it just froze it by hand instead of via
  the recording.)
- **Resident (self-shading):** the environment **read** goes active — light *values* on
  **frozen `double` knots** (L2 recompute), so a trait re-shades the stand. This is a thin
  `S`-templated accessor over a double-knot spline — **not** the parallel `!is_same_v<double>`
  overload set B built, and **not** an active environment *construction*.
- **Always:** the environment *construction* (adaptive knot placement) stays `double` and is
  recorded (L2). Attempt B templated the construction; that was never needed.

So: A froze too much (couldn't do resident); B activated too much (over-built for invasion).
The correct cut is one thin active *read* over always-`double` knots, chosen by L3 presence.

### The shed — what does NOT need reverse mode at all

Answering the brief's question directly. Each of these is off every System's differentiable
graph; none should be templated on `S`:

1. **`leaf_model.cpp` (the whole leaf hydraulics)** — `double` black box + `supplied_derivative`.
   The single largest shed; the mechanical "template everything" approach would have activated
   ~1500 lines that never need to be active.
2. **The TF24 soil-water bucket** (`tf24_environment.h`) — a frozen L3 background in v1
   (resident soil coupling is deferred as stiff, Appendix A.2). Never active in v1.
3. **QAG's adaptive path + interval replay** — off every graph (crown = fixed QK, leaf = fixed
   QAG, light = spline). Legacy of a non-AD light integral; AD never touches it.
4. **`deep_crown_replay` + the composite production kernel** — an AD spike superseded by AD-1;
   delete.
5. **Adaptive spline construction, the ODE stepper, `refine_schedule`** — recorded `double`
   (L1/L2); the replay is fixed, so no controller is ever taped.
6. **`resource_compensation_point`** (`individual.h:162`) — an R-facing diagnostic root-find,
   off the run graph. No AD in v1.
7. **Refinement-error machinery, `check_finite_ode_state`, all `r_*` facades, `is_finite`
   guards** — diagnostics and the R boundary; `double`.

### What this shrinks

- **Cluster 1** is smaller than "template the hierarchy": activate the *demographic skeleton*
  and each model's *rate arithmetic*; leave the leaf, the soil bucket, and every adaptive
  controller in `double`.
- **Cluster 5** (the `supplied_derivative` seam) is not a TF24 side-quest — it is *how the
  entire leaf model participates*, so it is core, and it keeps `leaf_model.cpp` from ever
  going active.
- The plan gets **more** deletion-heavy: not only retire the duplicate refiner and the forked
  quadrature, but keep an entire subsystem (the leaf) off the tape. The forest the attempts
  missed is that **most of plant does not need reverse mode at all** — only a small,
  model-invariant core does, and the hard, model-defining code contributes through injected
  derivatives, not activation.

---

# Part VI — The wide surface: what the shallow passes missed

Parts I–V modelled each plant model as an odelia System and asked what goes active. That was
necessary but **shallow on the run itself**: they treated the SCM as a plain `Solver<Patch>`
and over-anchored on QAG. A wide survey (SCM run machinery; the equilibrium/assembly/workflow
layer; the stochastic and alternative run modes; the R user stories) surfaces a much larger
ground. This part is corrections + the surface, and it deliberately **stops before solving** —
it ends in open questions, not clusters.

## VI.0 Two corrections to the earlier parts

- **L2 is the adaptive light interpolator, full stop** (`ad-record-replay.md` §3). Its purpose
  is the **resident** self-shading gradient: record the knots the adaptive pass placed, then on
  the active pass rebuild the field *on frozen knots with active values* so a trait re-shades
  the stand. QAG-adaptive is dormant; the ODE schedule is L1. Part IV's "one pattern in
  triplicate" over-read a fossil.
- **Invasion-first was not the villain.** The frozen-`double` background *is* correct for
  invasion — that is L3, by design. The debt in both attempts was **hand-servicing** the freeze
  (A's `ad_value`, B's overloads) instead of routing it through the recording. And the *primary*
  user workflow is the **resident census gradient** (`ad-r-interface.md` §5.1: L0·L1·L2·L3,
  canopy reconstructed active), not invasion — so the plan must reach the L2 resident path,
  which is the one Attempt A structurally could not.

## VI.1 The deepest missed fact: the SCM is a growing-dimension system ⭐

Nothing in odelia (Lorenz, leaf_thermal, the RelaxationSystem demonstrator) changes its state
dimension. **The SCM does, mid-run, repeatedly.** `Patch::ode_size()` (`patch.h:661`) sums over
a *node count that grows at every introduction*; `run_next_impl` interleaves
`introduce_new_nodes` → `solver.set_state_from_system()` (**resizes `y/yerr/dydt`**,
`scm.h:262–263`) → `advance_*` a segment. A run is `[grow][resize][integrate]…`; each segment is
fixed-dimension, consecutive segments are not.

Consequences a reverse-mode tape must survive, none of which odelia's AD surface was validated
against:
- **Introductions are cross-cohort couplings on the tape, not fresh inputs.** A new cohort's
  initial conditions are an *active function of the already-integrated stand*:
  `compute_initial_conditions` sets `log_density = log(birth_rate·pr_estab/g)` where `pr_estab`
  and `g` read the current environment = all existing (active) cohorts (`node.h:163–189`). The
  design's "introductions add tape variables at fixed times, no discontinuity" is **too clean** —
  the seed value carries derivatives from the rest of the stand.
- **Hidden per-node state not in `y`.** `patch_density_at_birth`, `pr_patch_survival_at_birth`,
  `node_introduction_time` (`node.h:107–116`) are stamped at birth and feed rates and fitness
  (`node.h:59–61,152–155`) but never enter the ODE vector — extra per-node parameters the tape
  must treat correctly.
- **Whether odelia's `active_solver`/tape even supports a mid-run `resize()` is unverified.**
  The whole "Model A: the SCM is the runnable" rests on the active replay surviving a growing
  dimension. Neither attempt FD-verified an active multi-introduction run's *introduction
  coupling* (Attempt A's AD-3 test checked only that `d(height)/d(lma)` is finite/nonzero across
  98 cohorts — necessary, not sufficient). **This is open question Q1 below and it is the one
  that could invalidate Model A.**

## VI.2 The schedule is a data-dependent structural choice, frozen before the gradient

`refine_schedule` (`scm.h:334–372`) adaptively **bisects** introduction-time intervals between
whole runs until per-node error < `schedule_eps` — so the *number and placement of cohorts* is a
non-smooth function of parameters. The design's "L0 is double-only, up front" means: refine once
in `double`, **freeze the schedule**, and differentiate the fixed-schedule run. That is the same
"positions frozen, values active" argument as L2, lifted to the schedule — and it carries the
same caveat: the frozen-schedule gradient omits `d(schedule)/d(trait)`, argued below tolerance
but **never measured**. (Open question Q4.)

## VI.3 The workflow layer above a run has moved out of plant

The demographic-equilibrium and community-assembly loops — `equilibrium_birth_rate()`,
`fitness_landscape()`, `assembly_parameters()`, the R0=1 Newton solve — were **removed from
plant (#388) and now live in the `regnans` package** (`NEWS.md:80–84`). So:
- **plant's AD scope is bounded to the single run.** No iteration-over-runs to differentiate
  here; the Newton R0=1 loop is regnans's, and it *consumes* plant's per-run `dR0/d(birth_rate)`.
  This narrows the plant work — and makes the per-run birth-rate derivative the load-bearing
  deliverable for the downstream package.
- **`birth_rate` is not a trait — it is an `ExtrinsicDrivers` value** (`extrinsic_drivers.h`),
  entering on the input side (a node's initial density, `node.h:177`) and the output side
  (offspring scaling, `patch.h:473`); `R0` (`net_reproduction_ratios`, `scalars=1`) is
  birth-rate-independent by construction. Differentiating w.r.t. it means **seeding a driver**,
  a different input kind than a strategy parameter — and in the *variable* form it is a spline
  over patch age, i.e. seeding a driver whose knots are themselves adaptive. (Open question Q5.)

## VI.4 A second engine shares the hierarchy — the stochastic model

`StochasticPatch`/`StochasticSpecies`/`StochasticNode` + `StochasticPatchRunner`
(`stochastic_*.h`) are a full individual-based engine: discrete individuals, **RNG-driven
Bernoulli birth and death** (`unif_rand() < pr_germinate`, `stochastic_patch.h:167`;
`unif_rand() < mortality_probability()`, `stochastic_species.h:227`), integer-dimensional ODE
that grows *and shrinks* at events. It is **non-differentiable and out of AD scope** — but it
**shares `Individual`/`Environment`/`SpeciesBase`** with the deterministic path (CRTP). So the
constraint the earlier parts missed: **templating the shared hierarchy on `S` must not break the
stochastic engine's `double` path.** `value_type` threading is not free of this second consumer.

## VI.5 `IndividualRunner` — the clean AD target the whole plan skipped

`IndividualRunner<T,E>` (`individual_runner.h`) integrates **one** `Individual` in a *fixed*
environment: static `ode_size`, no schedule, no introductions, no competition feedback — the one
plant runner that *is* a plain fixed-dimension odelia System. The R stories use it
(`grow_individual_*`, `optimise_individual_rate_*`, `R/individual.R`). It is the **smallest,
cleanest, genuinely-in-scope first differentiable target** — a single-plant trait gradient with
none of the growing-dimension risk of §VI.1 — and neither attempt nor the design foregrounded
it. (It is where Q1 could be de-risked before betting on the SCM.)

## VI.6 Six competition modes, not one; TF24's default is not FF16's

`ShadingModel` (`canopy_shape.h:47`) has **six** members. Differentiability and even runnability
vary, and the earlier parts assumed deep-crown throughout:

| Mode | Smooth? | Runs? | Default for |
|---|---|---|---|
| DeepCrown | C1 | yes | **FF16** |
| MeanLight | C1 | yes | **TF24** |
| CrownCentre | C1 | yes | — |
| FlatTopSoftBox | C1 (2nd-deriv kink) | yes (biased) | — |
| PPA (smoothed) | C1 (`floor` kink at layer joins) | yes | — |
| FlatTopBox / PPA-hard | **no (hard step)** | **no** | — |

So: the crown-integral treatment (Cluster 4) is mode-dependent; **TF24 defaults to MeanLight**
(one optimisation at the mean light), not deep-crown; **K93 is single-mode** (no shading model);
and two modes are non-differentiable *and don't run* (drop them). The `assimilation_fn` /
`leaf_above_` function pointers are bound once at `prepare_strategy`, so a gradient sees a fixed
smooth function per mode — but *which* function is a per-strategy, per-config choice the plan
must enumerate.

## VI.7 The Control surface changes what a gradient sees

`control.h` groups into: **ODE integration** (`ode_tol_*`, `fixed_time_step` — switches RKCK↔Euler),
**schedule/mesh** (`schedule_eps/nsteps` — changes cohort structure), **environment mode**
(`shading_model`, `ppa_*`, `function_integration_rule`), **offspring solve**
(`offspring_production_tol/iterations`), **the existing FD node-gradient** (`node_gradient_*` —
what AD replaces/compares against), **replay** (`save_RK45_cache`), **TF24 leaf** (`GSS_tol_abs`,
`ci_*`, `vulnerability_curve_ncontrol`). A gradient is only well-defined *relative to a fixed
Control*; several knobs silently change the trajectory (hence the gradient), and one
(`save_RK45_cache`) is the AD enabler itself. The plan must state which Control it differentiates
at.

## VI.8 Open questions to resolve before designing (not answers)

1. **Does reverse-mode AD survive the SCM's growing dimension?** Does odelia's `active_solver`/
   tape tolerate `set_state_from_system()` resizing mid-run, and is the introduction coupling
   (a new cohort's active ICs) captured correctly? **FD-verify a ≥2-introduction active run
   before committing to Model A.** This is the pivotal risk.
2. **Is the leaf-as-`supplied_derivative` (Part V) correct for a *trait* gradient, not just
   `∂profit/∂ψ`?** The envelope-theorem treatment must hold through the full nested solve
   against FD on one TF24 cohort. (PROTO-3 proved the edge; this is the trait-gradient claim.)
3. **Do the FD node-gradient (`growth_rate_gradient`) and its `thread_local` scratch carry the
   trait derivative, or must they be made active?** (Cluster 6, still unmeasured either way.)
4. **How large is the dropped `d(schedule)/d(trait)` from freezing the refined schedule?**
   Argued below tolerance; measure it.
5. **How is `birth_rate` seeded as a differentiation target** given it is an extrinsic driver
   (constant or adaptive spline), not a strategy field — and does regnans need any AD awareness
   to consume `dR0/d(birth_rate)`?
6. **Which (Control, shading-mode, run-mode) configuration is v1's differentiable target?**
   The clean answer points at IndividualRunner and the fixed-schedule adaptive-RKCK
   DeepCrown/MeanLight SCM; everything else (Euler, PPA-hard, FlatTopBox, stochastic,
   refine-during-gradient) is explicitly out.

**Not yet clustered — by intent.** These questions must be answered from the running code before
the Part II clusters are re-drawn; several of them (Q1 especially) could move the boundaries the
clusters assume.

---

# Part VII — Adaptive-component census, the field-vs-state correction, and the input surface

Following the same discipline (surface, don't solve), this part answers four sharpened
questions: is the light spline the *only* L2 target; what actually is soil moisture; what
other adaptive components hide in any system; and what input/coupling surface the earlier
parts never named. It corrects two more modelling errors.

## VII.0 Correction: "reconstructed active" is L2's job *alone*

The `ad-r-interface.md` §5.1 row "resident … L0·L1·L2·L3 … canopy reconstructed (active)" means
the resident run *uses* all four levels, **not** that all four reconstruct. Per odelia#28: **L1**
is the step schedule (Solver-owned, always differentiable), **L2** is the one "record positions →
**recompute values active** on frozen positions" mechanism (the *only* reconstruction), **L3** is
frozen `double` values (explicitly *not* reconstructed — read off-tape). Parts IV–VI loosely said
"L0–L3 reconstruct the canopy active"; that is wrong — reconstruction is L2, and L2 alone.

## VII.1 The adaptive-component census (exhaustive) — the light spline is the only L2 field

Grepping every `construct`/`refine`/adaptive/interpolator/spline across all systems, the
components that make *parameter-dependent placement decisions* are:

| Component | File | Adaptive placement? | AD class |
|---|---|---|---|
| **Light/resource spline** (`ResourceSpline` via `AdaptiveInterpolator`) | `resource_spline.h`, `adaptive_interpolator.h` | **yes** — knots refined to tolerance | **L2** (the one true adaptive field) |
| ODE step schedule (RKCK adaptive) | odelia Solver | yes | **L1** (Solver-owned) |
| SCM introduction schedule (`refine_schedule`) | `scm.h:334` | yes | **L0** — frozen up front, differentiated fixed |
| QAG adaptive subdivision | `qag.h:85` | yes, but **`max_iter=1` everywhere → never fires** | dormant; not on any graph |
| Leaf 4 interpolators (`transpiration_from_psi`, `psi_from_transpiration`, `root_vuln_from_psi`, `root_vuln_integral_from_psi`) | `leaf_model.cpp:1134–1163` | **no** — `.init()` on a fixed 100-knot grid | fixed-knot; analytic `.deriv()`; off the taped graph |
| Extrinsic-driver splines | `extrinsic_drivers.h:16` | **no** — `.init()` on given control points | fixed-knot input (VII.3) |
| Leaf vulnerability grid | `leaf_model.cpp:1116` | **no** — fixed uniform grid | fixed |
| `CanopyShape` | `canopy_shape.h` | **no** — precomputed at `prepare_strategy` | fixed |

**So the light spline is the only adaptive *field* → the only L2 target.** Everything else is
L1 (Solver), L0 (frozen schedule), dormant (QAG), or fixed-knot (leaf, drivers, vulnerability).
The earlier "record adaptive positions" pattern has exactly one live AD instance.

## VII.2 Soil moisture is ODE *state*, not a field — the field-vs-state correction ⭐

Part V called the TF24 soil bucket "a frozen L3 background." That mis-classifies it. **Soil
moisture is integrated ODE state**, not a recomputed/frozen *field*:
- `TF24_Environment` contributes `ode_size = vars.state_size` > 0 (soil layers + 4 cumulative-flux
  diagnostic slots); **FF16/K93 environments carry no ODE state** (`ode_size = 0` — the light
  spline is a recomputed field, never integrated). This is a first-class structural split the
  earlier parts missed: *for TF24 the environment is part of the integrated state vector.*
- The coupling is **bidirectional and inside the ODE** (`patch.h:592–602`): the Patch sums each
  cohort's `consumption_rate` into `resource_depletion[i]` and calls
  `environment.compute_rates(resource_depletion)`, which evolves soil moisture; soil → ψ (retention
  curve) → leaf hydraulics → transpiration → `resource_depletion`. A genuine state↔state feedback.
- Therefore the AD treatment is **not** L2/L3-field:
  - **Resident TF24:** soil is *active state* coupled to the plants via `resource_depletion` — on
    the tape as state, not a recomputed field. (This is exactly the stiff long-horizon coupling the
    design defers, Appendix A.2.)
  - **Mutant/invasion TF24:** the rare mutant doesn't perturb resident soil, so soil ψ is read
    *frozen* — it rides the L3 frozen-environment read (it is part of `environment_history`), but as
    frozen recorded state, not a reconstructed field.

So: **the light spline is a field (L2/L3); soil moisture is state (active/frozen).** Answering the
question directly — canopy (light) is the only L2 field target; soil is a *second coupling*, but of
a different kind, and its resident form is the deferred stiff one.

## VII.3 The input surface the earlier parts never named

Differentiation *targets* and time-varying *couplings* beyond strategy traits:
- **Extrinsic drivers** (`extrinsic_drivers.h`): named, fixed-knot spline (or constant) functions
  of patch time — `birth_rate` (demography), and for TF24 `rainfall` (soil input) + `PPFD`,
  `atm_vpd`, `ca`, `leaf_temp`, `atm_o2_kpa`, `atm_kpa` (leaf climate). They enter rates as `double`
  backgrounds and are **fixed-knot, hence directly differentiable w.r.t. their control-point values**
  — a whole input surface (climate sensitivity, `dR0/d(birth_rate)`) the plan never catalogued.
  `set_extrapolate(false)` clamps beyond the ends (a kink).
- **The consumable-resource subsystem** (`Internals::consumption_rates`, `Patch::resource_depletion`):
  the plant→environment depletion channel. **Dormant for FF16/K93** (0 resources), live only for TF24
  soil. It is extra per-cohort state (`consumption_rate(i)`) and the coupling of VII.2.
- **Disturbance regime** (`disturbance_regime.h`, Weibull): stamps `patch_density_at_birth` and feeds
  `pr_patch_survival` per node — per-node `double` weights entering fitness (`node.h:59,152`).
  Differentiable in principle w.r.t. disturbance parameters; not a current target.

## VII.4 Mutable caches on the const path — a distinct AD hazard class

Several `const` methods memoize into `mutable` members via **exact `double` comparison**, which
interacts badly with active types (a cache keyed on `value(x)` can go stale or poison the tape):
- `TF24_Environment::get_soil_water_potential_state()` — `psi_soil_cache_`, invalidated by
  `psi_soil_cache_state_[i] != vars.state(i)` exact compare (`tf24_environment.h:304–329`).
- The per-time driver memo `cached_driver_` (`tf24_environment.h:295–300`).
- The leaf's own inverted-soil / operating-point caches (`leaf_model.cpp`, `set_physiology`).
These are not on the differentiated-arithmetic path per se, but they gate values that are — a class
of subtle bug neither attempt nor the design mentions.

## VII.5 `run_mutant` — cataloged as an existing fact (not a prescription)

Recording the fact, per the brief: **`run_mutant` already exists as a hand-rolled replay**
(`scm.h:293–316` + `patch.h:707–775`, `set_mutant`/`load_ode_step`/`cache_*`). It pins the schedule
to the resident's `step_history`, swaps mutant strategies, and reads the resident environment frozen
by stage index — a complete, working, invasion-fitness replay predating the AD `Replayable` concept.
*Whether* odelia's `Replayable` should subsume it is a design question for later; the catalog's job
here is only to record that this mechanism exists and works today.

## VII.6 More open questions (continuing to collect — not answering)

7. **Does "the environment stays `double`" survive TF24?** It is an FF16/K93 property (env has no ODE
   state). For resident TF24 the environment *is* active coupled state (soil). What is the correct
   model boundary — and is resident-TF24 simply out of v1 (with a clear error), leaving only the
   frozen-soil mutant?
8. **How do the `mutable` exact-compare caches (VII.4) behave under active types?** Do they invalidate
   correctly, silently freeze a derivative, or corrupt the tape?
9. **Are the climate extrinsic drivers differentiation targets, or only `birth_rate`?** And is seeding
   a *fixed-knot driver spline's control points* a supported target kind alongside strategy fields?
10. **Is the plant↔soil `resource_depletion` coupling in v1 scope at all?** It is live only for TF24
    and only matters for the resident (deferred) path; for the mutant the soil is frozen.
11. **`step_light`/PPA `smooth_floor` and every soil positivity guard** (`max(0,·)`, the
    `theta<=residual` reset) — which are piecewise-constant selectors (safe) vs kinks the operating
    point can sit on? (Extends Cluster 7 to the soil surface.)
12. **Does the resident light field (L2) recompute correctly across the *growing* dimension?** L2
    recompute happens per step on frozen knots — but the set of cohorts contributing to the field
    grows mid-run (VI.1). L2 and the growing dimension interact; neither was tested together.

**Still deliberately unclustered.** The census (VII.1) shrinks L2 to one field; the field-vs-state
correction (VII.2) moves soil out of the L2/L3 model entirely; and questions 7–12 join 1–6 as the
set to resolve from running code before Part II's clusters are re-drawn.

---

# Part VIII — Run-type/level correction, the leaf seam, and the hidden-feature sweep

Answers to four sharpened questions (run-type↔level, TF24 soil under mutant, leaf
interpolators × supplied-derivative, birth-rate science) plus an exhaustive hidden-feature
sweep that closes the coupling-channel enumeration. Still surfacing, not solving.

## VIII.0 Correction: a run reads L2 **or** L3, never both

Parts IV–VII loosely said the resident run "uses L0·L1·L2·L3." Per odelia#28 and the code:
- **Resident gradient run: L0 (schedule frozen up front) + L1 (step schedule) + L2** (light
  field **recomputed active** on frozen knots; self-shading flows). It does **not** read L3.
- **Mutant gradient run: L0 + L1 + L3** (the resident's frozen environment read as `double` by
  `(step,stage)`; the rare invader neither shades the resident nor itself). It does **not**
  recompute (**no L2**).
- The resident's *double recording* stores the **union** (positions *and* values) only so that
  *future mutants* can read the values — the resident's own gradient never reads them. The
  `ad-r-interface.md §5.1` "resident → L2·L3" row conflates "the recording contains all levels"
  with "this run reads all levels." That is the doc's misleading bit.

## VIII.1 TF24 soil under a mutant fits the L3 shape (resident soil does not)

`cache_RK45_step` snapshots the **whole `environment` object** per RK stage
(`environment_cache.push_back(environment)`, `patch.h:743`) — for TF24 that includes the
soil-water ODE state, the light spline, and the driver caches. The mutant `set_ode_state(it,
index)` points `environment_ptr` at the frozen snapshot and **skips the environment's slots in
its own ODE vector** (`patch.h:715–719`), so the resident's soil ψ is read frozen exactly like
light. **So invasion-TF24 soil rides L3 cleanly.** Two caveats: (a) plant's L3 is a *whole-object*
snapshot per stage (heavier than odelia's minimal per-stage field-value cache); (b) **resident**
TF24 soil is *active coupled state* (VII.2), the deferred stiff case — not L3.

## VIII.2 Leaf interpolators × supplied-derivative — and the ∂profit gap

The four leaf interpolators are fixed-knot C2 splines exposing an analytic `.deriv()`. The
leaf's supplied-derivative (`dprofit_droot_collar_psi`, `leaf_model.cpp:900`) is **hand-assembled
in `double`**: forward-AD (`xad::fwd`) of the closed-form algebra (`assim_colimited_ad`,
`hydraulic_cost_ad`) + the implicit-function theorem on the `ci`/`psi` root-finds + the
interpolators' `.deriv()` as the transport terms + a central-difference fallback at kinks. The
interpolators never go active — only `.eval()` (value) and `.deriv()` (slope) are read, both
`double`. **This confirms Part V (the leaf stays `double`) and exposes the gap:** only
`∂profit/∂psi` and `∂profit/∂vcmax25` exist today. A full TF24 trait gradient needs
`∂profit/∂θ` for **every** seeded trait plus `∂profit/∂{light, height}` (the crown reads light at
the active bound) — each a similar hand-assembled analytic partial (envelope theorem + forward-AD
+ IFT + `.deriv()`). Mechanical, but a real body of work — the substance of AD-9.

## VIII.3 Birth-rate science (answering the design question)

`birth_rate` enters twice: **input** — a cohort's initial `log_density = log(birth_rate·pr_estab/g)`
(`node.h:177`), so it sets seedling arrival density; **output** — `offspring_production` scales
each node's fecundity by `birth_rate(t)` (`patch.h:473`), while **R0 = `net_reproduction_ratios`
uses `scalars=1`** (`patch.h:485`), i.e. offspring *per seed*. R0's dependence on `birth_rate` is
therefore **entirely indirect density dependence**: more `birth_rate` → denser cohorts → more
canopy shading → lower per-capita fitness → lower R0. So **`dR0/d(birth_rate)` *is* the
density-dependent regulating feedback** (negative), and it drives the equilibrium solve
`R0(birth_rate)=1` (the self-sustaining density; the Newton loop lives in `regnans`). It flows
through the resident self-shading coupling → **it is a resident (L2) gradient**; the frozen/invasion
version misses the feedback and "can flip the sign" (design AD-10). **Scope to the scalar**
(`is_variable_birth_rate=false`): then `birth_rate` is a plain leaf input seeded like a trait
(`d/d(birth_rate)=1` at the input, the rest is the density→R0 chain). The time-varying spline case
is a *functional* derivative over control points (the spline basis is the analytic factor) —
representable but awkward; out of scope. Climate drivers are fixed input data, not targets.

## VIII.4 Hidden-feature sweep — the residue (11-category hunt)

New items an ODE-`y`-only view misses, beyond what earlier parts caught:

- **The `aux` vector is a derivative-carrying store that *looks* like a cache.**
  `Internals::auxs` is `std::vector<double>`; `competition_effect (= area_leaf(height))` and
  `height_inverse` are recomputed from state in `update_dependent_aux` (`ff16_strategy.h:207`) and
  **read back inside the rate path** (`ff16_strategy.cpp:90–91`). The chain height→aux→rate passes
  through this store — template only `y` and not `auxs` and the derivative drops silently. (AD-1
  correctly templates all four `Internals` vectors; the *trap* is that `aux` reads as a cache.)
  `collect_all_auxiliary` also changes the aux **layout** at runtime (`aux_size` varies).
- **The shared strategy object is both the parameter store *and* a per-call scratchpad.** Every
  cohort of a species aliases one `shared_ptr` strategy; its non-`const` members are shared mutable
  state: TF24's `Leaf leaf` and `mass_root_prop_` (`tf24_strategy.h:338,376`), the `QK
  function_integrator`, and TF24f's `tracked_root_psi_`/`dprofit_dpsi_` write/read channel
  (`tf24f_strategy.h:74`). **Consequence:** a templated `TF24_Strategy_<S>` is a **mixed-scalar
  object** — `S`-typed pars + mass cascade, but a **`double` `Leaf` sub-model** (Part V's "leaf
  stays double" is literally this). The trait→leaf coupling passes traits *into* the double leaf as
  `double` and the derivative comes back via `supplied_derivative`.
- **`height_max` = `std::max` over cohorts sets the environment spline domain**
  (`patch.h:424–432,569`). The resident (L2) field's *domain bound* is a non-smooth max over active
  cohort heights — a structural kink in the self-shading gradient, not just a leaf-level clamp.
- **Deliberately frozen trait dependencies.** FF16 hard-codes `lma` into `r_l = 39.27/0.1978791`
  and `r_b = 2·r_s` "so it doesn't change if that trait changes" (`ff16_strategy.h:42–56`). So
  `d(r_l)/d(lma) = 0` **by construction** — the AD gradient correctly reflects the *model's*
  parameterisation, which omits this physiological chain by choice. A caveat for interpreting
  gradients, not a bug.
- **Non-autonomous time term:** `establishment_probability` reads `environment.time` via
  `exp(-recruitment_decay·time)` (`ff16_strategy.cpp:488`; inert at the default 0, but user-set),
  feeding the mortality/log-density IC.
- **`util::stop`/`is_finite` guards on the hot path** (`species.h:208`, `k93_strategy.cpp:92`,
  `patch.h:355–421` `check_finite_ode_state` with `log_density_ceiling=50`) trip on the perturbed or
  NaN intermediates an FD probe or a boundary-adjacent AD sweep produces — a robustness surface.
- **R-layer gradient *consumers*:** `optimise_individual_rate_*_by_trait` (`individual.R:266`)
  optimises a growth rate over a trait with `stats::optimise/optim` + an NA→0 remap;
  `grow_individual_bisect` root-finds a time with `stats::uniroot`. These are IndividualRunner
  workflows that would *use* AD gradients (today FD) — a use case, not a differentiation target.

## VIII.5 Closure: the coupling channels are now exhaustively enumerated

The sweep found **no** hidden globals/singletons/registries, **no** third resource (only light —
non-depletable, FF16/K93 — and soil water — depletable state, TF24), and **no** direct
cohort→cohort or species→species state reads. Every inter-entity coupling routes through exactly
three channels:
1. **the light environment** (a recomputed field: L2 resident / L3 mutant);
2. **the soil environment** (ODE state + the `resource_depletion` plant→soil channel; TF24 only);
3. **the shared strategy object** (per-species scratchpad: leaf, buffers, tracked-ψ).
Plus the per-node birth stamps (`patch_density_at_birth`, `pr_patch_survival_at_birth`) that are
not in `y`. That is the complete set — a confidence result: further hunting is unlikely to add a
*new kind* of coupling, only more instances within these three.

## VIII.6 Open questions added (13–17)

13. **Is the `aux` store correctly `S` for every read-into-rate path**, and does
    `collect_all_auxiliary`'s runtime layout change interact with a fixed tape?
14. **How is the mixed-scalar strategy (`S` pars + `double` leaf) actually expressed** so the
    trait→leaf→profit path is `double`-in / analytic-partial-out without a hand-serviced boundary
    (the trap both attempts fell into elsewhere)?
15. **Does the `height_max` max-over-cohorts kink** (spline domain bound) bite the resident L2
    gradient at the operating point, or is it a.s. inactive (a strict max)?
16. **Which frozen-by-design trait dependencies** (like `r_l`↔`lma`) does the shipped gradient
    silently omit, and is that the scientifically intended gradient?
17. **Do the hot-path `util::stop`/`is_finite` guards need active-safe forms**, or is the operating
    point always interior enough that an AD sweep never trips them?

**Still unclustered — the surface is now believed complete** (VIII.5 closure). The full open set is
Q1–Q17 across Parts VI–VIII; several (Q1 growing-dimension tape, Q2 leaf trait-gradient, Q14
mixed-scalar strategy) must be answered from running code before Part II's clusters are re-drawn.
