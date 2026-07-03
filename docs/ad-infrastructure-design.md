# AD infrastructure design: plant emergent gradients on odelia's AD runtime

**Status:** design proposal (no code changes yet).
**Scope:** `traitecoevo/plant` (SCM emergent-trait gradients — the prototype on
PR [#553](https://github.com/traitecoevo/plant/pull/553), tracking issue
[#472](https://github.com/traitecoevo/plant/issues/472)) and
`traitecoevo/odelia` (the AD-aware ODE runtime).
**Branches:** `claude/ad-infrastructure-design` on the plant and odelia forks;
this document is on `claude/ad-infrastructure-design-87k3g8` in `plant-dev`.

---

## 1. Thesis

odelia is the automatic-differentiation runtime for this package family: it
compiles XAD's `Tape` once, and ships a scalar-templated ODE `Solver`, a
persistent tape, a reverse-mode gradient driver, and a differentiable spline.
plant already `LinkingTo: odelia` and consumes odelia's `Tape` runtime,
interpolator, and spline.

The #553 spike computes exact reverse-mode SCM gradients and is validated to
~1e-13, but it does so with a **second, plant-private AD stack**: a third scalar
template axis, three per-strategy replay engines, five hand-managed tapes, an
R-side harvest with an `Rcpp::as<>` round-trip, and reductions hand-copied from
the forward model. Most of that machinery is generic AD mechanism that odelia
already owns or should own.

**This design moves the generic AD mechanism into odelia and keeps only
irreducible plant physiology in plant.** The result is one scalar model, one
gradient driver, one tape lifecycle, and emergent metrics that reuse the model's
own reductions instead of copying them. The spike becomes the specification and
the regression oracle, not the merge candidate.

---

## 2. Decisions

These are settled and drive the rest of the document.

1. **Reverse mode is the objective at the SCM level.** The emergent Jacobian is
   metrics × traits (≈4 × 28), so outputs ≪ inputs and reverse is optimal.
   odelia's driver is reverse-only.
2. **Full scalar (uniform `value_type`).** The SCM becomes an odelia System with
   one active scalar throughout; the spike's mixed active/frozen `<T,E,S>` axis
   is dropped. Pare back to a mixed representation later *only* if profiling shows
   the uniform tape is too large (§9).
3. **Plant owns a `Strategy` concept; odelia stays plant-agnostic.** odelia
   differentiates an abstract System and never learns what a cohort or a trait
   is. plant leads odelia's API by concrete application, not speculation.
4. **Forward mode stays plant-local.** plant's leaf gas-exchange optimizer uses
   `xad::fwd` (IFT + envelope theorem, seed-tangent injection). It stays where it
   is; odelia does not adopt forward mode. odelia must, however, *accommodate* it
   and the TF24 root-solver IFT by exposing an analytic-adjoint edge (§6.5).
5. **TF24 and TF24f land in the first release**, alongside FF16 — including the
   TF24 census cross-sensitivity that the spike left open, if the prototype in
   §10 confirms the full-scalar path closes it.
6. **Do not merge the spike; codesign odelia first.** Landing a second tape
   lifecycle and scalar axis and then refactoring them away is the failure mode to
   avoid.
7. **Second order is out of scope.** No Hessian / `fwd_adj`.

---

## 3. odelia's AD runtime (what exists)

- **Compiled `Tape`, single definition.** `odelia/src/Tape.cpp` holds the only
  `Tape<double>` instantiation and the one `active_tape_`; header-only consumers
  link it. plant satisfies this contract on all three platforms
  (`odelia/ARCHITECTURE.md`, `plant/src/Makevars.win`).
- **Scalar-templated System/Solver.** `Solver<System>` runs state through
  `System::value_type` (`odelia/inst/include/odelia/ode_solver.hpp`,
  `ode_interface.hpp`). `value_type = double` is the reference model; an XAD active
  type differentiates the same code.
- **Solver-owned persistent tape.** `Solver` holds `xad::Tape<double>* tape` and
  manages its lifetime; `compute_gradient` reuses it across calls.
- **Reverse-mode driver.** `odelia/inst/include/odelia/ode_fit.hpp`:
  `compute_gradient(solver, ic, params) -> {value, gradient}` seeds inputs, records,
  runs the forward solve, forms a scalar loss, back-propagates, and reads input
  adjoints.
- **System AD contract.** `value_type`, and `set_params(tape, it)` /
  `set_initial_state(tape, it, t0)` returning `std::vector<T*>` of registered
  inputs (`odelia/inst/examples/leaf_thermal/src/leaf_thermal_system.hpp`).
- **Differentiable spline.** `odelia/inst/include/odelia/spline.hpp` freezes knot
  *positions* (`double`) and differentiates knot *values* (`S`) — the reusable
  form of "differentiate the converged construction."
- **XAD facilities already vendored.** `computeJacobian` in adjoint and forward
  variants (`XAD/Jacobian.hpp`); `CheckpointCallback` for injecting analytic
  adjoints (`XAD/CheckpointCallback.hpp`); `xad::adj`/`xad::fwd` modes
  (`XAD/Interface.hpp`).

---

## 4. The spike (what exists in plant) and its debt

| Spike component | Location | Debt |
|---|---|---|
| Third scalar axis `<T,E,S>`, mixed active/frozen | `individual.h`, `node.h`, `species.h`, `patch.h` | Threaded by hand through every class; dual parameter representation (`TF24ProdPars<AD> p; p.lma = pd.lma; …`) |
| Three per-strategy replay engines | `src/ff16_emergent.cpp` (1851), `src/tf24_emergent.cpp` (479), `src/tf24f_emergent.cpp` (2266) | Orchestration triplicated; unifiable only across the odelia boundary |
| Five hand-managed tapes | `tf24f_emergent.cpp` (`ad::tape_type tape;` ×5) | Bypasses the Solver-owned tape; source of the 7 skipped FF16 AD tests |
| R-side harvest + `Rcpp::as<>` round-trip | `R/*_emergent_gradient.R` | "Correctness ceiling" and ~1600× per-access cost (spike roadmap) |
| Reductions copied from the model | `inst/include/plant/gradient/{scm_harvest.h, coupled_canopy.h}` | `canopy_comp_at` is a bit-for-bit copy of `Species::compute_competition` |
| Manual IFT injection | `inject_h0` in `ff16_emergent.cpp` | Hand-rolled where `CheckpointCallback` is the intended mechanism |

The spike's own roadmap (`plant/notes/ad-refactor-optimize-roadmap.md`) records
that deduplicating the three engines *inside plant* saved only ~107 lines: the
shared substrate is ODE/AD *runtime*, whose owner is odelia, not plant.

---

## 5. Target architecture (overview)

```
              plant                                    odelia
  ───────────────────────────────────      ─────────────────────────────────────
  Strategy concept (§6.2):                  Solver<System>  (value_type = S)
    · deriv kernel                          compute_gradient / compute_jacobian (§6.3)
    · trait / birth-rate seed map           Functional seam — no targets required (§6.4)
    · scalar-templated reductions (§6.7)     Seeds + AnalyticEdge (IFT/fwd) (§6.5)
    · environment coupling                  differentiable spline (schedule freeze) (§6.8)
                                            persistent Tape, single active_tape_ (§6.9)
  thin R forwarders                         ── compiled Tape runtime ──
        │  LinkingTo + Imports: odelia (full AD API, not just the Tape) ▲
        └──────────────────────────────────────────────────────────────┘
```

The existing odelia↔plant contract (odelia compiles the Tape; plant links it)
extends up one level: odelia owns the AD *API*, versioned in its
`ARCHITECTURE.md`, and plant depends on an odelia version rather than a private
copy.

---

## 6. Component design sketches

Signatures below are illustrative, not final; they fix the seams and ownership.

### 6.1 One scalar: the SCM as an odelia System

The Patch is the System; its scalar is uniform. Differentiated inputs are seeded
active; every frozen quantity is an active-typed constant with zero derivative
(correct, and the tape cost is the subject of the §9 measurement).

```cpp
template <class Strategy, class S = double>
class ScmSystem {
public:
  using value_type = S;
  static std::size_t ode_size();
  const_iterator set_ode_state(const_iterator it);   // existing odelia seam
  iterator       ode_rates(iterator it) const;        // calls Strategy deriv kernel

  // odelia AD contract (§3): register the differentiated inputs, return refs.
  template <class Tape, class It> std::vector<S*> set_params(Tape&, It traits);
  template <class Tape, class It> std::vector<S*> set_initial_state(Tape&, It, double t0);
};
```

### 6.2 The plant `Strategy` concept (plant-side, odelia-agnostic)

The one place strategy-specific biology lives. FF16/TF24/TF24f each model it.

```cpp
// A Strategy supplies, for any scalar S:
//   value_type / parameter storage that can be seeded active per trait name
//   the demographic deriv kernel      : rates(state, env)      -> d(state)/dt
//   the emergent reductions           : metric<Metric>(cohorts, env) -> S   (§6.7)
//   the environment coupling          : canopy(z, cohorts)     -> S         (§6.7)
//   optional analytic edges           : leaf-optimizer IFT contribution     (§6.5)
struct StrategyConcept {
  template <class S> S            area_leaf(S height) const;         // allometry
  template <class S> void         compute_rates(const Env<S>&, State<S>&) const;
  template <class S> S            canopy_competition(double z, const Cohorts<S>&) const;
  template <class Metric, class S> S emergent(const Cohorts<S>&, const Env<S>&) const;
};
```

Adding a metric = adding a `Metric` tag + kernel that reuses existing model
functions; it does not touch odelia. New strategies implement the concept once.

### 6.3 odelia gradient / Jacobian driver (reverse)

Generalize `compute_gradient` from "loss over observations" to "functional of the
solve," and add a Jacobian that records once and sweeps per output row
(`XAD/Jacobian.hpp`'s adjoint variant is the template).

```cpp
// scalar functional -> value + gradient wrt seeded inputs
template <class System, class Functional>
std::pair<double, std::vector<double>>
compute_gradient(Solver<System>& solver, const Seeds& seeds, Functional&& f);

// vector functional (metrics) -> Jacobian; one recording, one adjoint sweep/row
template <class System, class VectorFunctional>
Matrix compute_jacobian(Solver<System>& solver, const Seeds& seeds, VectorFunctional&& f);
// body: seed(seeds); tape.newRecording(); auto y = f(solver.run());
//       registerOutputs(y);
//       for each row i: derivative(y[i]) = 1; computeAdjoints();
//                       read derivative(*input_j); clearDerivatives();
```

### 6.4 The functional seam (no natural observations)

plant's gradient is not a fit-to-data problem: there are no targets, and the
output is a functional of the *whole replayed stand*, not state at fixed indices.
So the driver takes a `Functional` that maps the solved System to active
scalar(s); `sum_of_squares(advance_target(), targets)` becomes one instance of it,
not the interface.

```cpp
// plant supplies this; it reuses the Strategy's scalar-templated reductions.
struct EmergentFunctional {
  std::vector<Metric> metrics;                 // e.g. {LAI, biomass, offspring}
  template <class S>
  std::vector<S> operator()(const ScmSystem<Strategy,S>& solved) const;  // one entry/metric
};
```

This keeps the UX seamless: `stand_gradient(scm, metrics, traits, species)` maps
to `compute_jacobian(solver, seeds(traits, species), EmergentFunctional{metrics})`.
If a target/observation problem arises later, odelia's `set_target` path is
retained as a prebuilt functional.

### 6.5 Seeds, and accommodating plant's forward/IFT AD

`Seeds` names which inputs are active and carries any analytic edges for
quantities computed off-tape (root-find optima). This is odelia's compatibility
surface for plant's forward-mode leaf sensitivities and the TF24 stomatal IFT.

```cpp
struct Seeds {
  std::span<const std::string> traits;   // -> System::set_params
  bool                         birth_rate = false;   // -> extra registered input
  std::span<const std::string> initial_state;        // -> System::set_initial_state
  std::vector<AnalyticEdge>    edges;    // IFT / envelope contributions
};

// An AnalyticEdge injects a known d(output)/d(input) into the reverse tape for a
// value the forward pass computed in double (e.g. the leaf optimum). Implemented
// with XAD's CheckpointCallback::computeAdjoint — replaces the spike's inject_h0.
struct AnalyticEdge { /* input refs, output ref, analytic partials */ };
```

The leaf optimizer keeps computing its local sensitivity in forward mode
(plant-local); the *result* enters the SCM reverse tape as an `AnalyticEdge`,
cleanly, via `CheckpointCallback` rather than hand-seeded active variables.

### 6.6 Feedback modes = which inputs are active

The two gradient semantics (§7) are not two engines; they are a wiring choice on
the environment functional:

- **frozen (invasion / selection gradient):** the resident canopy is a constant —
  its inputs are *not* seeded active — so the cross term (mutant re-shading the
  stand) is zero by construction.
- **resident (total / stand-level gradient):** the canopy is reconstructed from
  active cohort states via `Strategy::canopy_competition<S>`, so every trait that
  moves a height re-shades the stand and the cross term appears.

In the full-scalar model this is a one-line difference (freeze vs. re-evaluate the
canopy), where the spike needed distinct code paths.

### 6.7 Emergent metrics reuse the model's own reductions

The reductions are exact quadratures that must mirror the SCM's own construction
(differentiate the reported quantity, not a "better" integral). Rather than the
gradient-layer copies, scalar-template the model's own reductions —
`Species::compute_competition`, the patch census integral — on `S` and call them
from both the forward model (`S=double`, unchanged) and the gradient replay
(`S=active`). Exactness becomes structural; `gradient/coupled_canopy.h` and the
`census_trapezium` copy retire.

### 6.8 Frozen light on the differentiable spline

The resident light schedule ("positions frozen, values active") is an instance of
odelia's spline. Build the frozen environment on `odelia::spline::basic_spline<S>`
/ `basic_interpolator<S>` (already included by the engines) so the frozen-schedule
replay's "derivative matches construction" is guaranteed by the primitive.

### 6.9 Tape lifecycle and linking

All AD goes through the Solver-owned persistent tape (§3), respecting the single
`active_tape_` invariant. This retires plant's five local tapes and should let the
7 skipped FF16 AD tests run, because the tape now lives on odelia's load path.

### What stays irreducibly in plant

Strategy physiology (FF16 light hyperbola; TF24/TF24f leaf solve + curvature
harvest; coupled deriv kernels), the emergent metric kernels, the trait→parameter
map, and the demographic replay semantics (birth steps, patch survival). These are
biology, not AD plumbing.

---

## 7. Gradient semantics (what is measured)

The SCM gradient is not one object. The design treats the choice as first-class
(§6.6):

| Gradient | Definition | Feedback | Notes |
|---|---|---|---|
| **Trait, invasion** | ∂(metric of a rare mutant)/∂(mutant trait), resident canopy fixed | frozen | The selection gradient; cross term = 0. `offspring_production` is always this. |
| **Trait, resident** | d(emergent metric)/d(trait) with the differentiated species *as resident* | resident | Includes the cross term (the species re-shades the stand it lives in). |
| **Birth-rate** | ∂(metric)/∂(birth_rate) | — | Density dependence; for `offspring_production`, `dR0/db`. Every cohort's density is linear in birth_rate, so the rare-mutant reading is exact. |

The **mutant path** is the frozen/invasion column: a rare mutant reads the
resident's canopy, so its fitness gradient holds the environment fixed. This is
why `offspring_production` coincides between modes and why the birth-rate gradient
is well-conditioned. The design accommodates the full stand-level (resident) total
derivative through the same driver by seeding the canopy inputs active; nothing
else changes.

---

## 8. Strategy coverage and the cross-sensitivity gap

| Strategy | Offspring | Census (LAI, biomass, …), invasion | Census, resident | Blocker |
|---|---|---|---|---|
| FF16 | ✅ | ✅ | ✅ | — (no leaf optimizer) |
| TF24f | ✅ | ✅ (long-horizon gate) | partial | stiff feedback at long patch lifetime |
| TF24 | ✅ | ✗ in spike | ✗ in spike | **leaf-optimizer cross-sensitivity** |

**The cross-sensitivity gap:** TF24/TF24f resolve a leaf gas-exchange optimum per
cohort per environment. A census metric (e.g. number density) depends on that
optimum; when a trait moves, the optimum shifts, which shifts growth and therefore
the density at census. The spike's *linearised, frozen* harvest injects the leaf
sensitivity as a first-order tangent along the focal path but zeroes this
cross-term through the density, so TF24 census gradients are unavailable. FF16 has
no optimizer, so FF16 census is fine.

**Why the full-scalar design plausibly closes it:** with the whole replay on one
tape and the leaf-optimizer IFT delivered as an `AnalyticEdge` (§6.5) rather than a
frozen-path injection, the reverse sweep traverses the density→optimum→trait path
natively, so the cross-term is captured without special handling. **This is the
single highest-risk claim in the design and is the subject of the §10 prototype;**
landing TF24 census in the first release (decision 5) is contingent on it.

---

## 9. The scalar-cost measurement (validates decision 2)

Full scalar is the default; the fallback is a mixed representation, chosen only on
evidence. Before building the production path, measure:

- Implement the FF16 frozen cohort as a uniform-`value_type` odelia System;
  gradient one metric.
- Compare `tape.getMemory()` and wall-clock against the spike's mixed engine on
  the canonical cases (`scripts/bench_gradient.R`).
- Outcomes: (a) within a small constant → ship uniform scalar; (b) decisively
  worse → keep a mixed scalar but as an odelia "frozen input" concept (inputs
  registered with a permanent zero adjoint), not a hand-threaded template axis;
  (c) ambiguous → uniform scalar for maintainability.

---

## 10. Migration plan

The spike's validated Jacobians are the regression oracle. Each step asserts
bit-identity (pure relocations) or a documented noise floor (paths that reorder FP
sums) against a snapshot fixture (`tests/testthat/fixtures/gradient-baseline.rds`),
plus the existing AD-vs-FD physics tests.

0. **odelia foundation.** `compute_jacobian`, the `Functional` seam (§6.4), `Seeds`
   + `AnalyticEdge` (§6.5); cover with odelia's own tests (extend `leaf_thermal` to
   a multi-output Jacobian). No plant change.
1. **Scalar-cost spike (§9).** Decide uniform vs. mixed before porting.
2. **FF16 frozen.** SCM-as-System; port the simplest engine onto
   `compute_gradient`; prove bit-identical.
3. **FF16 resident/coupled + spline.** Move the frozen light onto odelia's spline
   (§6.8); delete the `Rcpp::as<>` loop; add the long-horizon gates the round-trip
   made impossible.
4. **TF24 / TF24f.** Port as `Strategy`-concept models on the one System; land the
   census cross-sensitivity via the §10-prototype `AnalyticEdge` (or scope it out
   explicitly if the prototype fails).
5. **Cleanup.** Delete the three engines, the R harvest, plant's local tapes, and
   the `<T,E,S>` axis; un-skip the FF16 AD tests; prune prototype scripts.

---

## 11. Risks and areas needing development

- **TF24 census cross-sensitivity (§8).** Highest risk. Needs the §10 prototype to
  confirm the on-tape `AnalyticEdge` captures the density→optimum cross-term before
  decision 5 is guaranteed.
- **Scalar cost (§9).** Needs the measurement spike; the fallback is designed but
  the default is unproven.
- **`AnalyticEdge` / `CheckpointCallback` ergonomics (§6.5).** The mechanism exists
  in XAD but is unused in plant today; the leaf-IFT edge needs a small prototype to
  fix its API and prove it reproduces the spike's injected sensitivities.
- **Metric set (§6.2/§6.7).** The concrete required metrics and their kernels
  should be enumerated so the `Metric`-tag interface covers them in one shape.
- **Resident TF24f at long horizon (§8).** A stiffness/conditioning limit that is
  physics, not plumbing; may remain gated in v1.

---

## Appendix: source references

**odelia (AD runtime)**
- `inst/include/XAD/Jacobian.hpp` — `computeJacobian` (adjoint + forward)
- `inst/include/XAD/CheckpointCallback.hpp` — analytic-adjoint injection (IFT)
- `inst/include/XAD/Interface.hpp` — `xad::adj` / `xad::fwd` modes
- `inst/include/odelia/ode_fit.hpp` — `compute_gradient`, `sum_of_squares`
- `inst/include/odelia/ode_solver.hpp` — `Solver`, persistent tape,
  `set_target`/`advance_target`
- `inst/include/odelia/spline.hpp`, `interpolator.hpp` — differentiable spline
- `inst/examples/leaf_thermal/src/leaf_thermal_system.hpp` — System AD contract
- `ARCHITECTURE.md` — Tape linking / single-`active_tape_` contract

**plant (spike)**
- `DESCRIPTION` — `LinkingTo: odelia`; `Imports: odelia`
- `src/{ff16,tf24,tf24f}_emergent.cpp` — the three replay engines; the five local
  tapes; `inject_h0` (manual IFT injection); the cross-term comments (`ff16_emergent.cpp:1029,1860`)
- `src/leaf_model.cpp` (`dprofit_droot_collar_psi`), `src/tf24_strategy.cpp` —
  leaf-optimizer forward-mode AD (IFT + envelope, seed-tangent injection)
- `R/{emergent,tf24_emergent,tf24f_emergent}_gradient.R` — R harvest + round-trip;
  feedback modes (`frozen`/`resident`) and the mutant/invasion semantics
- `inst/include/plant/gradient/{scm_harvest.h, coupled_canopy.h}` — the emergent
  reductions (copies of the model's quadratures)
- `inst/include/plant/{individual,node,species,patch}.h` — the `<T,E,S>` axis
- `inst/include/plant/models/ff16_strategy.h` — per-method `template<typename S>`
- `inst/include/plant/scm.h` — `odelia::ode::Solver<patch_type>`
- `notes/ad-refactor-optimize-roadmap.md` — the spike's own refactor plan
