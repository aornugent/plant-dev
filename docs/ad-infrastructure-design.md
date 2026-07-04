# AD infrastructure design: plant emergent gradients on odelia's AD runtime

**Status:** design proposal (no code changes yet).
**Scope:** `traitecoevo/plant` (SCM emergent-trait gradients — prototype on PR
[#553](https://github.com/traitecoevo/plant/pull/553), tracking issue
[#472](https://github.com/traitecoevo/plant/issues/472)) and `traitecoevo/odelia`
(the AD-aware ODE runtime).
**Branches:** `claude/ad-infrastructure-design` on the plant and odelia forks;
this document is on `claude/ad-infrastructure-design-87k3g8` in `plant-dev`.
**Companions:** [`ad-issues.md`](./ad-issues.md) — tightly-scoped work items,
dependencies, and build order; [`ad-r-interface.md`](./ad-r-interface.md) — the
R/C++ AD boundary for both packages.

---

## 1. Thesis

odelia is the AD runtime for this package family: it compiles XAD's `Tape` once
and ships a scalar-templated ODE `Solver`, a persistent tape, a reverse-mode
gradient driver, and a differentiable spline. plant already `LinkingTo: odelia`
and already runs its SCM on `odelia::ode::Solver<patch_type>`.

The #553 spike computes exact reverse-mode SCM gradients (validated to ~1e-13) but
does so with a **second, plant-private AD stack** parallel to odelia: a third
scalar axis, three replay engines, five hand-managed tapes, an R-side harvest, and
reductions hand-copied from the forward model.

**This design reaches the same gradients by making surgical changes to the
existing plant components so they are AD-compatible, and by adding a small generic
surface to odelia — not by building a parallel stack.** Two facts make this
tractable and are the backbone of the design:

- **The Patch is already the odelia System** (`Solver<patch_type>`); it does not
  need an `SCMSystem` wrapper, only to satisfy odelia's AD contract.
- **`SCM::run_mutant()` is already the frozen-schedule replay** — it pins
  integration to the resident's cached `step_history`, reads the cached
  environment, and suppresses the mutant's self-competition. The gradient is the
  derivative *of that existing run*, not of a new engine.

The spike becomes the specification and the regression oracle.

---

## 2. Decisions

1. **Reverse mode at the SCM level.** Emergent Jacobian is metrics × traits
   (≈4 × 28), outputs ≪ inputs; odelia's driver is reverse-only.
2. **Full scalar (uniform `value_type`).** The Patch/Species/Node/Individual run
   one active scalar throughout; the spike's mixed active/frozen axis is dropped.
   Pare back to mixed only if the §9 measurement shows the uniform tape is too
   large.
3. **Surgical changes to existing plant types; no new abstractions.** No
   `SCMSystem`, no `StrategyConcept` struct. Strategy and Patch already exist; we
   make them AD-compatible in place (§5).
4. **odelia stays plant-agnostic.** It knows Systems, tapes, functionals, and
   Jacobians — never cohorts, traits, emergence, or basal area. plant leads
   odelia's API by concrete need.
5. **Two workflows, both differentiated (issue #472).** *Resident/total* (the
   stand differentiates with self-feedback) and *mutant/invasion* (a rare mutant
   in the frozen resident canopy). These already exist as `run()` and
   `run_mutant()`; the design differentiates each (§6).
6. **Forward mode stays plant-local.** The leaf gas-exchange optimizer keeps its
   `xad::fwd` IFT/envelope solve; odelia only *accommodates* it via an
   analytic-adjoint edge (§4.2, §5.2).
7. **TF24 and TF24f land in the first release**, contingent on the §8
   cross-sensitivity prototype.
8. **Do not merge the spike; codesign odelia first.** Second order is out of scope.

---

## 3. Three layers

The work separates cleanly. The rest of the document is organised by these layers;
[`ad-issues.md`](./ad-issues.md) assigns each work item to one.

| Layer | Owns | Knows about plant? |
|---|---|---|
| **odelia** (§4) | tape, Solver, `compute_gradient`/`compute_jacobian`, the functional *shape*, the independent-variable *shape* | No |
| **plant** (§5) | Patch-as-System, Strategy AD-compat, scalar-templated reductions, differentiating `run`/`run_mutant`, SCM orchestration | — |
| **UX / API / workflow** (§6) | `stand_gradient()` and friends, the two workflows, the metric set, the regression oracle | — |

---

## 4. odelia layer (generic, plant-agnostic)

### 4.1 What exists

- Compiled single-definition `Tape` (`src/Tape.cpp`, `ARCHITECTURE.md`);
  scalar-templated `Solver<System>` on `System::value_type`; Solver-owned
  persistent tape; `compute_gradient(solver, ic, params)` (`ode_fit.hpp`); the
  System AD contract `set_params`/`set_initial_state` returning `vector<T*>`
  (`leaf_thermal_system.hpp`); the differentiable spline (`spline.hpp`).
- Vendored XAD facilities: `computeJacobian` (adjoint + forward, `XAD/Jacobian.hpp`),
  `CheckpointCallback` for analytic-adjoint injection (`XAD/CheckpointCallback.hpp`),
  `xad::adj`/`xad::fwd` (`XAD/Interface.hpp`).

### 4.2 Additions (all generic)

**(a) The functional *shape*.** Today `compute_gradient` hard-codes
`sum_of_squares` over observations. Generalize so the driver differentiates a
caller-supplied functional of the solved system — odelia defines *"a functional
maps a solved System to output scalar(s)"* and nothing more. `sum_of_squares` /
`advance_target` become one prebuilt instance; plant supplies its own (§6). odelia
never learns what the scalars mean.

```cpp
// odelia: the shape. F is any callable  std::vector<S>  f(const System& solved).
template <class System, class F>
std::pair<double, std::vector<double>>
compute_gradient(Solver<System>&, const Independents&, F&& functional);
```

**(b) `compute_jacobian` (reverse, generic).** Record once, one adjoint sweep per
output row — the adjoint variant of `XAD::computeJacobian`. Works for any odelia
System; no plant knowledge.

```cpp
template <class System, class F>          // F -> std::vector<S> (the m outputs)
Matrix compute_jacobian(Solver<System>&, const Independents&, F&& functional);
// seed(independents); newRecording(); y = functional(solved);
// registerOutputs(y);
// for i in rows: derivative(y[i]) = 1; computeAdjoints();
//                read derivative(input_j); clearDerivatives();
```

**(c) `Independents` — the "gradients w.r.t. what?" shape.** *(Renamed from the
earlier `Seeds`: in AD "seed" is a verb, and in plant a "seed" is an offspring — a
name clash. `Independents` is the standard AD term and is unambiguous.)* It is a
generic description of which registered inputs are active and any analytic edges;
it contains no plant vocabulary.

```cpp
struct Independents {
  // opaque handles the System registered via set_params / set_initial_state
  std::vector<double>       params;        // values to seed active
  std::optional<std::vector<double>> initial_state;
  std::vector<AnalyticEdge> edges;         // §(d)
};
```

**(d) `AnalyticEdge` — accommodating IFT / forward-mode results.** For a value the
forward pass computes off-tape (a root-find or optimizer result), inject its known
partials into the reverse tape via `CheckpointCallback::computeAdjoint`. This is
odelia's compatibility seam for plant's leaf-optimizer forward-mode sensitivity and
the TF24 stomatal IFT — generic (odelia sees inputs, an output, and partials), and
it replaces the spike's hand-rolled `inject_h0`.

---

## 5. plant layer (surgical changes to existing components)

Each change below is a small in-place modification of a type that already exists.

### 5.1 Patch — satisfy odelia's System AD contract

The Patch is already the System (`SCM` holds `odelia::ode::Solver<patch_type>`).
Changes:

- **Uniform `value_type = S`** across `Patch<T,E,S>` and its members
  (`Node`, `Species`, `Individual`), replacing the spike's mixed
  physiology-active/demography-double split (decision 2).
- **Add `set_params(tape, it)` / `set_initial_state(tape, it, t0)`** returning the
  registered active inputs — the same contract `leaf_thermal_system.hpp` models.
  This is where traits and birth-rate become active; the map from trait names to
  registered fields is plant's (§5.2).

No `SCMSystem` type is introduced; these are methods on the existing Patch.

### 5.2 Strategy — make traits seedable, keep physiology scalar-templated

The Strategy classes already exist and already expose per-method `template<class S>`
physiology (`area_leaf<S>`, `update_dependent_aux<S>`). Two minimal changes:

- **One parameter representation that can be active.** Today the strategy stores
  double `pars` and the replay carries a *separate* lifted active struct
  (`TF24ProdPars<AD> p; p.lma = pd.lma; …`). Collapse to a single scalar-templated
  parameter store so a named trait can be registered active directly (feeding
  §5.1's `set_params`). This removes the dual representation.
- **Leaf-optimizer edge.** TF24/TF24f keep their forward-mode leaf solve; expose
  its sensitivity as an `AnalyticEdge` (§4.2d) rather than the spike's active-`h0`
  injection.

The existing FF16 (no optimizer) needs only the parameter-store change.

### 5.3 Reductions — scalar-template the model's own quadratures, delete the copies

`Species::compute_competition(double height)` **is** the census/light trapezium
that the gradient layer copies as `canopy_comp_at`; it currently returns `double`.
Surgical change: **template it (and the patch census integral) on `S`** so the same
function serves the forward model (`S=double`, unchanged) and the gradient replay
(`S=active`). Then `inst/include/plant/gradient/{coupled_canopy.h, scm_harvest.h}`
retire and exactness is structural, not a maintained bit-for-bit copy.

### 5.4 The replay is `run_mutant` / `run`, differentiated — not a new engine

The two workflows differentiate two existing runs, and they differ precisely in how
the canopy (L3, §7) is accessed:

- **Invasion** = differentiate `SCM::run_mutant(p)` with `S=active`. It switches the
  Patch to the cached resident environment (`set_mutant()`), pins the schedule to
  the resident `step_history` (`use_ode_times`), and runs — the mutant reads the
  **frozen** canopy and does not compete with itself (`is_mutant_run` gates
  `compute_competition`). The derivative through the canopy is zero.
- **Resident / total** = differentiate the resident run on the *same* frozen L0/L1
  schedule, but with the canopy **reconstructed from the active cohorts** (§7, L3
  reconstructed) so a trait re-shades the stand. It must **not** read the frozen
  `environment_history` — doing so collapses it to the invasion gradient.

Either way the three `*_emergent.cpp` engines are replaced by *differentiating the
SCM we already have*, not a new engine. (Whether the resident reconstruction reads
the cached stand state or re-computes the canopy live on the frozen schedule is an
implementation choice for PLANT-5/5a; both must keep the canopy active.)

### 5.5 SCM orchestration over odelia's atomic components

The SCM stays the plant-specific orchestrator; odelia supplies the atoms
(`advance_fixed`/`advance_adaptive`, tape). Two orchestration points matter for AD:

- **Node introductions grow the system; they are not discontinuities.**
  `run_next_impl` introduces cohorts at scheduled times, then integrates to the
  next event. When the node schedule is frozen (§7, L0) the introduction times are
  *constants* (`d(t_intro)/d(trait) = 0`), so introductions add tape variables (a
  wider state) but inject no discontinuity into the differentiated output. This is
  exactly why the schedule must be frozen: an adaptive, trait-dependent schedule
  *would* be non-differentiable. One recording spans the whole run across
  introductions.
- **Adaptivity is frozen in layers, not all at once.** The SCM has *four* adaptive
  constructions that each break differentiability, and they are frozen
  independently at different depths (the node schedule, the ODE step times, the
  quadrature/interpolator knots, and — for invasion — the resident environment).
  These are the "replay levels" of §7; the earlier prototype conflated them. Which
  levels a given gradient needs is what §7 sorts out.

---

## 6. UX / API / workflow layer

### 6.1 The two workflows (issue #472)

| Workflow | SCM entry | Environment | Gradient meaning |
|---|---|---|---|
| **Resident / total** | `run()` | co-moving (stand re-shades itself) | d(emergent metric)/d(trait), full self-feedback |
| **Mutant / invasion** | `run_mutant()` | frozen resident canopy | selection gradient: d(rare-mutant fitness)/d(mutant trait) |

The mutant has low density in an established stand: it competes with the residents
but not with itself, so its fitness gradient holds the environment fixed. Positive
fitness ⇒ it can invade. This is a genuinely separate workflow, not a mode flag on
the first — and both are pre-existing SCM capabilities the design differentiates.

### 6.2 Gradient semantics

| Gradient | Workflow | Cross term | Notes |
|---|---|---|---|
| Trait, invasion | mutant | 0 (frozen canopy) | the selection gradient; `offspring_production` is always this |
| Trait, resident | resident | present | species re-shades the stand it lives in |
| Birth-rate | either | — | density dependence; `dR0/db`; density is linear in birth_rate ⇒ exact |

### 6.3 Public API (unchanged surface)

`stand_gradient(scm, metrics, traits, species, feedback=…)` keeps its shape and maps
to `compute_jacobian(solver, independents(traits, species, birth_rate),
EmergentFunctional{metrics})`, where `EmergentFunctional` is plant-supplied and
reuses §5.3's reductions. The R harvest and `Rcpp::as<>` round-trip disappear (the
functional reads native state on the tape). Adding a metric is a one-kernel change
in plant that reuses model functions; odelia is untouched.

---

### 6.4 What each workflow accesses

The workflows are ordered by how central they are to plant, and they access
genuinely different data — this is what must drive the plant UX (odelia's ODE-fit
example does **not**).

| Priority | Workflow | Reads from the resident run | Levels | Canopy | Extra input |
|---|---|---|---|---|---|
| **1 (primary)** | Emergent gradient, resident/total (forest ecologist) | node schedule (L0), `step_history` (L1), `stand_*_stage_history` + light-spline knots (L2), `environment_history` as value anchor (L3) | L0·L1·L2·L3-reconstructed | **active** (reconstructed from cohorts) | traits, metrics |
| **2** | Mutant/invasion fitness (evolutionary ecologist) | node schedule (L0), `step_history` (L1), `environment_history` **frozen** (L3); L2 for census metrics | L0·L1·(L2)·L3-frozen | **frozen** | mutant traits |
| **3 (advanced)** | Calibration / inference (ODE fit) | resolved ODE times (L1) | L1 | n/a | **observations + likelihood** |

Reading across: the **resident** gradient accesses the cached *stand state* and
reconstructs the canopy; the **invasion** gradient accesses the *frozen env values*;
**calibration** accesses neither — only the ODE schedule plus a user-supplied loss
over observations. Because calibration additionally requires the user to define
targets and a likelihood, it is an advanced workflow, not the entry point. The two
emergent-gradient workflows (1 and 2) need **no** observations and are the primary
plant UX; the design must serve them first and must not inherit odelia's
`set_target`/`fit` shape (which belongs to workflow 3).

## 7. Replay levels: four independent freezes

"Differentiate the converged construction" applies at four *distinct* depths in the
SCM. Each freezes a different adaptive construction that would otherwise break
differentiability; they compose, and a given gradient needs only some of them.
Keeping them separate is the clarity the prototype lacked (it spoke of one "frozen
schedule").

| Level | Freezes | Captured by | Removes non-diff from | Owner |
|---|---|---|---|---|
| **L0 — node schedule** | which cohorts exist and when introduced | `build_schedule`/`refine_schedule`, *before* the adaptive run | adaptive cohort introduction | plant |
| **L1 — ODE step times** | the adaptive RKCK step selection | `solver.times()` → `advance_target`/`advance_fixed` (pinned replay) | adaptive step-size control | **odelia (exists)** |
| **L2 — quadrature / interpolator knots** | height-QAG abscissae and the light-spline knots | cached knots (frozen) *or* scalar-templated `QK` (moving nodes) | adaptive quadrature / interpolation refinement | plant (`qk.h`) + odelia spline |
| **L3 — resident canopy** | the resident environment the focal cohorts read | `save_RK45_cache` (stores *both* frozen env values *and* resident stand state) | see below — **frozen ≠ reconstructed** | plant |

**L1 is the ODE-fit case (calibration), and it already works — but it is not the
plant driver (§6, R-interface).** odelia's own AD test (`test-ad-workflow.R`) runs a
Lorenz solve adaptively, captures `times()`, and replays pinned via
`set_target`/`advance_target` — *no environment cache, just the resolved ODE
schedule*. It needs L1 alone.

**L2 has two variants, and #472 flags the harder one.** For the resident light
spline, the knots are frozen (positions) and the values active — odelia's
differentiable spline (§4.1). For a census integrated over height, the integration
bound *is* an active plant height, so the Gauss–Kronrod **nodes move**: this needs
the scalar-templated `QK` (`qk.h`, already written for #472) rather than a
frozen-node replay, which "would miss" the moving-node sensitivity.

**L3 is accessed two *different* ways — and this is the correctness crux.**
`save_RK45_cache` caches both the frozen resident environment *values*
(`environment_history`) and the resident *stand state* per RK stage
(`stand_*_stage_history`). The two gradients use different data:

- **Invasion (frozen):** a rare mutant reads the cached `environment_history` as a
  **constant** — the derivative through the canopy is zero by construction. This is
  `run_mutant` (`is_mutant_run` suppresses self-competition). Correct for a rare
  invader.
- **Resident / total (reconstructed):** the canopy is **rebuilt differentiably**
  from the cached stand state (heights + competition effects) via the L2 quadrature,
  so a trait re-shades the stand through `area_leaf`; the frozen env value is used
  only as a value anchor. **Replaying the frozen environment here would silently
  give the invasion gradient — the self-shading cross term would be missing.** The
  resident total gradient therefore does *not* use the frozen-env replay.

### Which workflow needs which levels

| Gradient | L0 | L1 | L2 | L3 |
|---|:--:|:--:|:--:|:--:|
| Calibration (odelia ODE fit) | | ✅ | | |
| Offspring, invasion | ✅ | ✅ | | frozen |
| Census (LAI/biomass/basal area), resident | ✅ | ✅ | ✅ | **reconstructed** |
| Census, invasion | ✅ | ✅ | ✅ | frozen |

### The fixed comb still makes functionals simple

With L0–L1 frozen, the emergent functionals are simple reductions over a fixed set
of cohorts. Offspring is a **constant-weighted sum** `Σ tw_i · offspring_i` (fixed
introduction times ⇒ constant weights). A census reduction is
`Species::compute_competition` scalar-templated (§5.3) — reused, not re-derived —
with L2 supplying the (moving or frozen) quadrature nodes. The design keeps the
*same* quadratures the model already uses and differentiates them; it adds no new
integration.

---

## 8. Strategy coverage and the cross-sensitivity gap

| Strategy | Offspring | Census, invasion | Census, resident | Blocker |
|---|---|---|---|---|
| FF16 | ✅ | ✅ | ✅ | — (no leaf optimizer) |
| TF24f | ✅ | ✅ (long-horizon gate) | partial | stiff feedback at long lifetime |
| TF24 | ✅ | ✗ in spike | ✗ in spike | **leaf-optimizer cross-sensitivity** |

**The gap:** TF24/TF24f solve a per-cohort leaf optimum; a census metric depends on
it, so a trait shift moves the optimum → growth → census density. The spike's
*linearised, frozen* harvest injects the leaf sensitivity along the focal path but
zeroes this cross-term through the density.

**Why the full-scalar design plausibly closes it:** with the whole `run_mutant`
replay on one tape and the leaf IFT delivered as an `AnalyticEdge` (§4.2d) rather
than a frozen-path injection, the reverse sweep traverses density→optimum→trait
natively. **This is the single highest-risk claim; the §-prototype in `ad-issues.md`
(PROTO-2) must confirm it** before TF24 census is guaranteed for v1 (decision 7).

---

## 9. Scalar-cost measurement (validates decision 2)

Before building the production path: implement the FF16 frozen cohort as a
uniform-`value_type` System, gradient one metric, and compare `tape.getMemory()` /
wall-clock against the spike's mixed engine (`scripts/bench_gradient.R`). Outcomes:
(a) within a small constant → ship uniform scalar; (b) decisively worse → keep a
mixed scalar but as an odelia "frozen input" concept (inputs with a permanent zero
adjoint), not a hand-threaded template axis; (c) ambiguous → uniform for
maintainability. This is PROTO-1.

---

## 10. Migration (spike as oracle)

Snapshot the spike's validated Jacobians to a regression fixture and assert
bit-identity (relocations) or a documented noise floor (FP-reorder paths) at every
step, plus the existing AD-vs-FD physics tests. Build order and dependencies are in
[`ad-issues.md`](./ad-issues.md); in brief: odelia foundation (functional shape,
`compute_jacobian`, `Independents`/`AnalyticEdge`) → scalar-cost spike → FF16
invasion via differentiated `run_mutant` → FF16 resident + spline → TF24/TF24f (+
cross-sensitivity prototype) → delete the engines, R harvest, and local tapes.

---

## 11. Risks and open areas

- **TF24 census cross-sensitivity (§8)** — highest risk; gated on PROTO-2.
- **Scalar cost (§9)** — default unproven; gated on PROTO-1.
- **`AnalyticEdge`/`CheckpointCallback` ergonomics (§4.2d, §5.2)** — mechanism
  exists but is unused in plant; needs PROTO-3 to fix its API.
- **Metric set (§6.3)** — enumerate the required metrics + kernels so the interface
  covers them in one shape.
- **Resident TF24f at long horizon (§8)** — a physics stiffness limit; may stay
  gated in v1.

---

## Appendix: source references

**odelia** — `inst/include/XAD/{Jacobian,CheckpointCallback,Interface}.hpp`;
`inst/include/odelia/{ode_fit,ode_solver,spline,interpolator}.hpp`;
`inst/examples/leaf_thermal/src/leaf_thermal_system.hpp`; `ARCHITECTURE.md`.

**plant** — `inst/include/plant/scm.h` (`run`, `run_next_impl`, `run_mutant`,
`Solver<patch_type>`); `inst/include/plant/patch.h` (`set_mutant`,
`introduce_new_nodes`, `environment_history`/`step_history`, `is_mutant_run`);
`inst/include/plant/species.h` (`compute_competition` — the census trapezium, still
`double`); `inst/include/plant/models/ff16_strategy.h` (`template<class S>`
physiology; double `pars`); `src/{ff16,tf24,tf24f}_emergent.cpp` (the parallel
engines, five local tapes, `inject_h0`); `src/leaf_model.cpp`,
`src/tf24_strategy.cpp` (forward-mode leaf IFT); `R/*_emergent_gradient.R` (harvest,
round-trip, `frozen`/`resident` feedback); `inst/include/plant/gradient/*` (the
reduction copies to retire); `notes/ad-refactor-optimize-roadmap.md`.
