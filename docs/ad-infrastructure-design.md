# AD infrastructure design: fold the plant gradient spike onto odelia's AD runtime

**Status:** design proposal (no code changes yet)
**Scope:** `traitecoevo/plant` (SCM emergent-trait gradients, PR
[traitecoevo/plant#553](https://github.com/traitecoevo/plant/pull/553)) and
`traitecoevo/odelia` (the AD-aware ODE runtime)
**Branches prepared:** `claude/ad-infrastructure-design` on both the plant and
odelia forks (`aornugent/*`); this document lives on
`claude/ad-infrastructure-design-87k3g8` in `aornugent/plant-dev`.
**Audience:** plant/odelia maintainers deciding how to land the AD spike with
low long-term technical debt.

---

## TL;DR

The plant AD spike (#553) is a genuine achievement — exact reverse-mode trait
and birth-rate gradients through the SCM, validated to ~1e-13. But it was built
as a **self-contained gradient subsystem inside plant**: a parallel scalar
template axis, three per-strategy replay engines, an R-side harvest with
`Rcpp::as<>` round-trips, and hand-rolled tape lifecycles.

Meanwhile **odelia already is the AD runtime for this family**. It vendors and
compiles XAD once, and ships a header-only, scalar-templated ODE `Solver` with a
persistent tape, a generic reverse-mode gradient driver (`compute_gradient`), a
`set_target`/`advance_target` observation seam, and a differentiable spline built
on exactly the "freeze the schedule, differentiate the construction" idea the
spike rediscovered. plant **already `LinkingTo: odelia`** and already consumes
odelia's Tape runtime, interpolator, and spline.

The spike largely **rebuilt in plant the AD mechanism that odelia already
provides**, instead of extending odelia's mechanism and keeping only plant's
physiology. This document proposes the inverse: push the generic AD machinery
down into odelia, keep only irreducible plant biology in plant, and land the
result as a much smaller, more maintainable surface.

The spike's own refactor roadmap
(`plant/notes/ad-refactor-optimize-roadmap.md`) is strong evidence for this. Its
Phase 3 tried to deduplicate the three engines *within plant* and found they
"shrank only ~107 lines for ~132 lines of shared header" — concluding the
remainder is "irreducible strategy-specific physiology." That conclusion is
correct **given the constraint that the AD orchestration stays in plant**. Lift
that constraint — move the orchestration to its natural owner, odelia — and the
consolidation that Phase 3 couldn't find inside plant appears at the package
boundary.

---

## 1. What odelia already provides (the AD runtime)

odelia is "almost header-only": the ODE `Solver`, interpolator, and spline are
templates, and the **only** compiled unit is the XAD `Tape` runtime, built once
into `odelia.so`/`odelia.dll` (`odelia/src/Tape.cpp`, `odelia/ARCHITECTURE.md`).
Downstream packages that `LinkingTo: odelia` resolve the `Tape` symbols against
that single library — a contract plant already satisfies on all three platforms
(`plant/src/Makevars.win`, `odelia/ARCHITECTURE.md`).

On top of that runtime, odelia ships four pieces of **generic AD mechanism**:

### 1a. Scalar-templated System / Solver
`odelia/inst/include/odelia/ode_solver.hpp` — `Solver<System>` is templated on
the system, and state flows through `System::value_type`
(`ode_interface.hpp`: `state_type<System> = std::vector<System::value_type>`).
Set `value_type = double` and you get the reference model bit-for-bit; set it to
an XAD active type and the same code differentiates. This is the "scalar axis"
pattern — and odelia already owns it.

### 1b. A persistent, Solver-owned tape
`Solver` holds `xad::Tape<double>* tape = nullptr` and manages its lifetime.
`compute_gradient` reuses it across calls "to avoid invalidating slots"
(`ode_fit.hpp`). Tape creation, activation, `newRecording`, and teardown are
handled in one place.

### 1c. A generic reverse-mode gradient driver
`odelia/inst/include/odelia/ode_fit.hpp` —
`compute_gradient(solver, ic, params) -> {value, gradient}`. It:
1. reuses/activates the Solver's tape,
2. seeds inputs via the System contract (below),
3. `newRecording()`, runs the forward solve (`advance_target`),
4. forms a scalar loss (`sum_of_squares` over observation times),
5. `registerOutput` + `computeAdjoints`,
6. extracts `xad::derivative(*input)` for each registered input.

### 1d. The System AD contract
A differentiable system implements (see
`odelia/inst/examples/leaf_thermal/src/leaf_thermal_system.hpp`):

```cpp
using value_type = T;                                   // scalar axis
template <typename Tape, typename It>
std::vector<T*> set_params(Tape& tape, It it);          // registerInput params → active refs
template <typename Tape, typename It>
std::vector<T*> set_initial_state(Tape& tape, It it, double t0);  // registerInput ICs → active refs
```

The System declares *what its differentiable inputs are*; odelia owns *how the
gradient is taped, propagated, and read back*. **plant's SCM does not implement
this contract** — the spike bypassed it entirely.

### 1e. The differentiable spline == "freeze positions, differentiate values"
`odelia/inst/include/odelia/spline.hpp` templates the cubic spline on the scalar
`S` of the knot **values**, while the knot **positions** stay `double`. The band
matrix is assembled from frozen positions and its solves are templated on the
RHS scalar, so the coefficients become differentiable w.r.t. the values "with no
special handling." The header says it plainly: *"Templated on the scalar S of the
knot VALUES … the knot POSITIONS m_x stay double."*

This is **precisely the spike's core principle** — the spike's PR body states
"Never differentiate a solver — differentiate its converged point" and "Derivative
must match construction: same splines." odelia already encodes that principle as
a reusable primitive.

---

## 2. What the spike built in plant (the parallel subsystem)

The spike (#553; branch `spike-ff16-scm-emergent`, ~17.5k net lines / 143
commits) is a **separate gradient stack living inside plant**:

| Spike component | Location | odelia already has |
|---|---|---|
| Third template axis `S` on the whole hierarchy | `individual.h`, `node.h`, `species.h`, `patch.h`, … (`template <typename T, typename E, typename S = double>`) | `System::value_type` scalar axis (§1a) |
| Three per-strategy replay engines | `src/ff16_emergent.cpp` (1851 lines), `src/tf24_emergent.cpp` (479), `src/tf24f_emergent.cpp` (2266) | generic `compute_gradient` driver (§1c) |
| Hand-rolled tape lifecycle in each engine | the `*_emergent.cpp` files | Solver-owned persistent tape (§1b) |
| R-side harvest + `Rcpp::as<>` env round-trip | `R/emergent_gradient.R` (`ff16_harvest`), `R/tf24_emergent_gradient.R`, `R/tf24f_emergent_gradient.R` | `set_target`/`advance_target` observation seam (§1c/§1d) |
| Frozen light schedule replay | the `Frozen` struct + per-stage env reconstruction | frozen-position / active-value spline (§1e) |
| Genuinely shared, already factored | `inst/include/plant/gradient/{scm_harvest.h, coupled_canopy.h}` (178 lines) | — (plant-specific, keep) |

Two structural liabilities fall directly out of this table, and the spike's own
roadmap names both:

- **The `Rcpp::as<>` round-trip.** Pass 1 harvests the resident schedule in R and
  rebuilds each per-RK-stage environment across the boundary. The roadmap calls
  this "the correctness ceiling" — the documented root cause of a TF24f
  long-horizon fidelity floor and "a validation trap," and ~1600× slower per
  access (`R/emergent_gradient.R` comments; roadmap Phases 1–2). odelia's
  observation seam exists specifically so the forward pass reads state natively,
  on-tape — no round-trip is possible.

- **Three engines that resist deduplication.** Roadmap Phase 3 deduplicated what
  it could *within plant* and stopped: "the engines shrank only ~107 lines … the
  bulk of each engine is distinct biology, not redundant copy." Correct — because
  the part that *is* shared (step, tape, adjoint, observation) is **runtime**,
  and the runtime's owner is odelia, not plant. Dedup inside plant hits a floor;
  dedup across the boundary does not.

---

## 3. Diagnosis

**The spike treats plant as the AD owner. odelia is the AD owner.**

plant already links odelia for the Tape runtime, the interpolator, and the
spline — but it reuses only the *lowest* layer (the compiled Tape) and rebuilt
every layer above it (scalar axis, tape lifecycle, gradient driver, observation
harvest, schedule-freeze). Those upper layers already exist in odelia, are
generic, and are the natural home for exactly this kind of consolidation.

The result is not wrong — it is validated and it works — but it carries
avoidable debt:

1. **Two scalar axes** (`S` in plant vs `value_type` in odelia) that must be kept
   coherent by hand.
2. **A second tape lifecycle** outside odelia's Solver, which is why 7 FF16 AD
   test files `skip()` with "AD tape symbols unavailable in this load_all
   session" (roadmap Phase 1) — the bespoke path doesn't inherit odelia's load
   contract cleanly.
3. **An R/C++ round-trip** that odelia's design makes structurally unnecessary.
4. **Three engines** whose shared substrate can't be factored while it lives in
   plant.

---

## 4. Proposed target architecture

**Principle:** odelia owns the AD *mechanism*; plant owns the *physiology and the
emergent functional*. Draw the line exactly where the roadmap's Phase 3 found the
"irreducible biology" boundary — and put everything on the other side of it into
odelia.

### 4a. One scalar axis
Make the SCM's differentiable objects flow through odelia's `value_type`
convention rather than a plant-private `S`. Where plant needs its own alias it
becomes `using value_type = S;` on the relevant system type, so plant's
differentiability is a *consequence* of being an odelia System, not a parallel
mechanism. (Migration note: audit the `<T, E, S>` sites — `individual.h`,
`node.h`, `species.h`, `patch.h` — and classify each as "is-a-System scalar"
(fold into `value_type`) vs "genuinely plant-local template" (keep).)

### 4b. Make the SCM an odelia System; use `compute_gradient`
Implement the §1d contract on the SCM/patch system:
`value_type`, `set_params(tape, it)` (the trait seed — this is plant's existing
28-trait map), `set_initial_state(tape, it, t0)` (birth-rate / IC seed). Then the
three `*_emergent.cpp` engines collapse into **one** strategy-parameterized
System that plugs into odelia's `compute_gradient`. odelia owns tape activation,
`newRecording`, the adjoint sweep, and gradient read-back; plant supplies only
the deriv kernel and the seed map. This is the consolidation Phase 3 could not
reach from inside plant.

Two capabilities must be added to odelia's driver to cover plant's needs — both
are natural generalizations, not plant-specific hacks:
- **Arbitrary output functional**, not just `sum_of_squares`. Generalize
  `compute_gradient` to take a caller-supplied loss/observation functional so
  plant can plug in its census/trapezoid emergent reductions
  (`inst/include/plant/gradient/scm_harvest.h`).
- **Multiple outputs → Jacobian.** plant wants a metrics×traits Jacobian
  (`stand_gradient`), so odelia should expose a `compute_jacobian` that seeds
  outputs row-by-row (or vector-mode), reusing the same tape.

### 4c. Native observation seam (delete the R round-trip)
Reframe the spike's Phase 2 work (`resident_harvest.h`, borrowed native env
pointers) as **generalizing odelia's `set_target`/`advance_target` observation
seam** to (i) observe borrowed native state and (ii) apply a plant-supplied
reduction as the differentiated functional. The forward pass then reads the
resident schedule on-tape in C++; the `Rcpp::as<>` reconstruction disappears
entirely and the round-trip becomes structurally impossible, not merely avoided.
This is the highest-value single change and it is already half-built in the
spike — it just needs to land in odelia's seam rather than a plant-private one.

### 4d. Build plant's frozen light on odelia's differentiable spline
plant's "resident light frozen, traits active" replay is a domain instance of
odelia's "knot positions frozen, knot values active" spline (§1e). plant already
`#include <odelia/interpolator.hpp>` in the emergent engines; build the frozen
light environment on `odelia::spline::basic_spline<S>` /
`basic_interpolator<S>` so "derivative matches construction" is guaranteed by the
primitive rather than maintained by hand in the `Frozen` struct.

### 4e. Tape lifecycle via odelia's Solver
Route all AD through odelia's Solver-owned persistent tape (§1b). This retires
plant's bespoke tape management and, because the tape now lives on odelia's load
path, should let the 7 skipped FF16 AD tests run in CI.

### What stays in plant (irreducible — do not move)
- Strategy physiology kernels: FF16 light-response hyperbola + deep-crown GK;
  TF24f tracked-collar leaf solve + curvature harvest; the coupled
  `deep_net_coupled` deriv kernels.
- The emergent reductions: census/trapezoid weighting, birth-step demography,
  per-stage patch survival (`scm_harvest.h`, `coupled_canopy.h`).
- The trait→parameter seeding map (the 28 FF16 traits etc.).

These are biology and demography, not AD plumbing. The roadmap already isolated
them; this design simply stops surrounding them with re-implemented runtime.

---

## 5. Layering, before and after

```
                    BEFORE (spike as merged today)         AFTER (this proposal)
  plant   ── R harvest + Rcpp::as round-trip          ── thin R forwarders
          ── 3x *_emergent.cpp replay engines         ── 1 strategy-param System
          ── bespoke tape lifecycle                   ── deriv kernels + seed map
          ── <T,E,S> parallel scalar axis             ── census/trapezoid functional
          │                                           │  (value_type = S)
          ▼ LinkingTo: odelia (Tape only)             ▼ LinkingTo: odelia (full AD API)
  odelia  ── compiled Tape runtime                    ── compiled Tape runtime
          ── Solver / spline / interpolator           ── Solver (+ Jacobian, native-obs seam)
             (present but bypassed for gradients)     ── compute_gradient / compute_jacobian
                                                      ── differentiable spline (schedule freeze)
```

The AGENTS/ARCHITECTURE contract that already binds the two packages (odelia
compiles the Tape; plant links it) simply **extends up one level**: odelia owns
the AD *API*, not only the AD *runtime*. That API becomes a versioned odelia
interface documented in `odelia/ARCHITECTURE.md`, and plant depends on an odelia
version rather than carrying its own copy.

---

## 6. Migration plan (incremental, bit-checked)

The spike's Phase 1 correctness fixture is the safety net for this refactor too:
snapshot the current validated Jacobians (AD-vs-AD baseline,
`tests/testthat/fixtures/gradient-baseline.rds`) and assert bit-identity (or the
documented coupled/ms noise floor) at every step. No step lands without its
correctness verdict.

- **Step 0 (odelia).** Add the two driver generalizations (arbitrary functional;
  `compute_jacobian`) and the native-observation seam, behind the existing
  `compute_gradient`. Cover with odelia's own tests (extend the `leaf_thermal`
  example to a multi-output Jacobian). No plant change yet.
- **Step 1 (plant, FF16 frozen).** Make the FF16 SCM an odelia System; port the
  simplest engine (frozen, single-species) onto `compute_gradient`. Prove
  bit-identical against the fixture. This validates the whole seam on the easiest
  case.
- **Step 2 (plant, resident/coupled).** Port the resident and coupled-canopy
  FF16 paths; move the frozen light onto odelia's differentiable spline (§4d).
  Delete the `Rcpp::as<>` loop; add the long-horizon TF24f gates the round-trip
  previously made impossible (roadmap Phase 2b).
- **Step 3 (plant, TF24 / TF24f).** Port the remaining strategies as deriv-kernel
  policies on the one System. Delete `tf24_emergent.cpp` and
  `tf24f_emergent.cpp`.
- **Step 4 (cleanup).** Remove plant's bespoke tape lifecycle and the parallel
  `S` axis where it folded into `value_type`; un-skip the 7 FF16 AD tests; prune
  the ~31 intermediate prototype validation scripts (roadmap Phase 1).

Each step is independently reviewable and independently revertable, and each is
pinned to the AD-vs-AD fixture plus the existing AD-vs-FD physics tests.

---

## 7. Trade-offs and risks (honest accounting)

- **Couples odelia's release cadence to plant's AD needs.** True, but odelia is
  *already* the AD owner (it compiles the Tape and plant links it); this makes an
  existing coupling explicit and versioned rather than adding a new one. The
  ARCHITECTURE.md contract already exists to manage exactly this.
- **odelia's driver must generalize (functional + Jacobian).** Real work, but it
  is the *right* home for it and benefits any future odelia consumer (e.g. the
  leaf_thermal fitting example gets multi-output Jacobians for free).
- **Physics subtleties don't move.** The frozen-schedule replay legitimately
  omits ~16–30% self-shading response and TF24f gates at stiff long-horizon
  feedback (PR #553 scope limits). These are modelling choices that remain
  plant's, unchanged by where the AD plumbing lives. This refactor neither fixes
  nor worsens them — it just stops entangling them with re-implemented runtime.
- **Big diff to land.** Mitigated by the step-wise, bit-checked plan and by the
  fact that Steps 1–4 *delete* far more than they add.
- **One-active-tape invariant.** Routing plant's gradients through odelia's
  Solver-owned tape must respect the single-`active_tape_` invariant
  (`odelia/ARCHITECTURE.md`). This is actually *safer* than the status quo, where
  plant runs its own tape lifecycle alongside odelia's — consolidating to one
  owner removes a class of cross-DLL tape hazards.

---

## 8. Open questions for the maintainers

> **Update:** Part II resolves several of these — #1 (mode/Jacobian) via §9, #2
> (Strategy concept) and #4 (sequencing) via §12. #3 (the `S` fold) becomes the
> measured §11 test rather than a judgement call. The remaining live questions
> are gathered in §13.

1. **Vector-mode vs row-by-row Jacobian.** For metrics×traits, does odelia expose
   XAD's vector/forward-over-reverse mode, or reuse one reverse tape per output
   row? (Affects the `compute_jacobian` API shape in Step 0.)
2. **Where does the strategy policy live?** A trait-class on the odelia System
   template (plant supplies the deriv kernel as a policy type), or a plant-side
   `Strategy` concept the System is parameterized on? Both keep biology in plant;
   they differ in who owns the template seam.
3. **Scope of the `S`→`value_type` fold.** Some `<T, E, S>` sites may be
   genuinely plant-local (not System scalars). The Step-1 audit should classify
   each; this doc assumes most fold but a few stay.
4. **Sequencing vs the roadmap.** The spike's roadmap proposes landing the spike
   to `develop` as a stacked PR series *first*, then optimizing. Should this
   odelia-integration be folded into that stack (as the "foundation slice"), or
   sequenced after the spike merges as-is? Recommendation: make the odelia
   generalization (Step 0) the foundation slice, so plant never merges a second
   tape lifecycle it will immediately delete.

---

# Part II — Discovery findings (round 2)

*Added after a close read of XAD's own facilities, the emergent reductions, the
forward/reverse split already in plant, and the `S` template axis. This round
resolves several of the §8 open questions and sharpens the recommendation.*

## 9. XAD gives us the Jacobian machinery; the mode choice is settled

`odelia/inst/include/XAD/Jacobian.hpp` ships `xad::computeJacobian` in **both**
modes:

- **Adjoint (reverse):** register inputs once, one `newRecording()`, then per
  output row `derivative(y[i]) = 1; computeAdjoints(); read derivative(v[j]);
  clearDerivatives()`. Cost = **one forward record + one adjoint sweep per output
  row**.
- **Forward (tangent):** per input column, seed `derivative(v[i]) = 1`,
  re-evaluate `foo`, read `derivative(y[j])`. Cost = **one function evaluation per
  input**.

The plant emergent Jacobian is *metrics × traits* — roughly **4 × 28** (FF16).
Outputs ≪ inputs, so **reverse mode is optimal** (≈4 adjoint sweeps over one
recording vs ≈28 forward re-evaluations). odelia's reverse-only tape is the right
primitive, and `computeJacobian`'s adjoint variant is the **established template**
for `odelia::compute_jacobian`. The only novelty odelia adds is routing inputs
through the System `set_params`/`set_initial_state` seam and reusing the
Solver-owned persistent tape — record once, `clearDerivatives()` between rows
(**not** `newRecording()`).

**Where forward mode legitimately lives (and should stay).** plant already uses
`xad::fwd` — but only at the **leaf gas-exchange optimizer**
(`leaf_model.cpp: dprofit_droot_collar_psi`, `tf24_strategy.cpp`). There it
computes small *local* analytic sensitivities (A′(ci), C′(ψ)) via forward AD,
combines them with the implicit-function theorem on the stomatal root-find and the
envelope theorem at the collar optimum, then **injects the result as a seed
tangent** into an active `net` that flows onward (`xad::derivative(net_ad) =
dnet_dvcmax`). This is a textbook two-level scheme: forward for cheap local
(few-input) Jacobians at the operating point, reverse for the global trait scan.
It is correct and well-scoped. **Leave leaf-level forward mode exactly where it is
(plant-local); do not lift it into odelia.** odelia's driver stays reverse-only.
Second-order / `fwd_adj` Hessian modes exist in XAD but are explicitly **out of
scope**.

The one generalization this forces on odelia: the driver must accept an
**injected seed derivative** on an input/intermediate (the IFT/envelope
contribution), not only unit-vector seeding. A small, honest extension of
`compute_gradient` — and plant is the design driver for it.

## 10. The emergent reductions: what they are, and the real smell

Three functionals live in `inst/include/plant/gradient/`:

- **`census_trapezium`** (`scm_harvest.h`) — an emergent stand metric (LAI,
  biomass, basal area…) as a **trapezoidal integral over cohorts sorted by
  descending height**, `J = Σ ½(h_a−h_b)(φ_a+φ_b)` plus a pending-seed ground
  tail, with `φ = psi(h, dens, mhw)` the per-metric kernel. The
  method-of-characteristics quadrature of the size distribution.
- **`offspring_weights`** (`scm_harvest.h`) — `offspring_production = Σ tw_i ·
  offspring_i`, a trapezoid over *introduction times*, `tw_i` = node-spacing
  weight × patch density × survival × birth rate. The seed-rain integral over the
  demographic axis.
- **`canopy_comp_at`** (`coupled_canopy.h`) — the Yokozawa light-competition
  trapezium `Σ geff_i·Q(z/h_i)`, the light field cohorts shade each other with
  (the resident coupling).

**Purpose:** these *are* the differentiated outputs — the "loss/observation
functional" in odelia's vocabulary. **Correctness principle:** each must reproduce
the SCM's own internal quadrature *exactly* — the headers say so ("Bit-for-bit the
hand-rolled comp_at it replaces"; `canopy_comp_at` "mirrors
`Species::compute_competition`"). This is not incidental: to get an exact gradient
of the quantity *the model reports*, you must differentiate *the model's own
construction*, not an independently "better" integral. So the trapezoid rule is
**not a free design choice** — a higher-order quadrature would be a more accurate
integral but would differentiate the *wrong* function. That constraint is real and
stays.

**The smell is not the quadrature — it is that the gradient layer re-implements
the model's quadrature instead of differentiating it.** `canopy_comp_at` is a
hand-verified copy of `Species::compute_competition`; `census_trapezium` mirrors
the patch census integral. Two copies of one integral, kept "bit-for-bit"
identical by comment and test. The clean form of "derivative matches construction"
is not *"write a matching copy"* but *"differentiate the actual construction"* —
i.e. **scalar-template the SCM's own reduction (`Species::compute_competition`,
the census integral) on `S` and call it from both the forward model (`S=double`)
and the gradient replay (`S=active`).** Then the `gradient/` copies disappear and
exactness becomes structural, not a maintained invariant.

That is the hinge into §11: **the whole point of the `S` axis is to let the
model's own code run with an active scalar** — which is exactly what would retire
these duplicated reductions. The spike currently does *both* (threads `S` *and*
keeps hand-copied reductions), which is why it feels redundant. Pick one, done
well.

## 11. The `S` template axis: what it is, and how to establish its worth

`Node<T,E,S>` (and `Individual<T,E,S>`, `Species<T,E,S>`) is **not** a uniform
`value_type` system. `node.h` is explicit: a `Node<...,ad>` is **intentionally
mixed** — "only the individual's *physiological* state carries the active scalar,"
while "demographic bookkeeping (log_density, density, fecundity, offspring) stays
**double**." `FF16_Strategy` is not class-templated on `S` at all; it exposes
*per-method* `template<typename S>` members (`area_leaf<S>`,
`update_dependent_aux<S>`) that cast stored double params up (`S(pars.a_l1)`),
while the active trait is carried in a **separate lifted parameter struct**
(`TF24ProdPars<AD> p; p.lma = pd.lma; …`, field by field) the replay routes in by
hand.

So `S` is a **mixed active/frozen scalar**: active on the trait→physiology→metric
path, frozen `double` on the demographic schedule harvested in pass 1. **Why it
exists:** to keep the tape small — the frozen demographic arithmetic (densities,
survival, patch weights over every cohort × every step) is never taped. A genuine
performance motive.

**But its utility has never been established against the simpler alternative**,
and that is the spike's core methodological gap. The clean-design alternative is
odelia's uniform `value_type = S`:

- **Design A — uniform scalar (odelia-native).** The whole cohort/patch is one
  scalar `S`. Seed only the traits as active; frozen demographic values are
  active-typed constants with zero derivative. **Correct** (zero-derivative
  constants propagate correctly), **simpler types** (no third axis, no lifted-param
  struct, no mixed-member bookkeeping, reductions reuse the model's own code), but
  a **larger tape** (the frozen arithmetic is recorded).
- **Design B — mixed scalar (the spike).** Physiology active, demography double.
  **Smaller tape**, paid for with the `<T,E,S>` sprawl, the dual parameter
  representation, and the duplicated reductions of §10.

The right way to decide is exactly what the spike skipped: **build Design A,
measure tape size and wall-clock against Design B on the canonical cases, and keep
the mixed axis only if the delta justifies the maintenance cost.** "Only clean
design can establish their utility" — precisely. Concretely this is a small
discovery spike on the odelia branch: implement the FF16 frozen cohort as a
uniform-`value_type` odelia System, gradient one metric, and compare
`tape.getMemory()` / timing to the spike's mixed engine. Three outcomes:

1. **A within a small constant of B** → drop `S`, adopt uniform `value_type`,
   delete the third axis, the lifted-param lift, and the reduction copies. Largest
   debt reduction.
2. **B decisively faster/smaller** → keep a mixed scalar, but **encapsulate** it
   as an odelia-recognized pattern (a "frozen input" concept: inputs registered
   with a permanent zero adjoint), *not* a hand-threaded third template parameter
   across every class. The optimization survives; the sprawl does not.
3. **Ambiguous** → default to A for maintainability; revisit if profiling later
   demands it.

Cheap to run, it is the kind of thing the spike should have done first, and it
converts "S looks like a smell" into a measured decision instead of a taste
argument.

## 12. Decisions locked in from this round

- **Reverse-only at the SCM level; forward stays leaf-local.** odelia's driver
  remains reverse; `xad::computeJacobian` (adjoint) is the template for
  `compute_jacobian`. (§9)
- **Plant-side `Strategy` concept; odelia stays plant-agnostic.** The
  differentiable System is parameterized on a **plant-owned `Strategy` concept**
  (supplying the deriv kernel, the trait seed map, and — per §10 — the
  scalar-templated emergent reduction). odelia never learns what a "cohort" or
  "trait" is; it owns tape/record/adjoint/Jacobian over an abstract System. plant
  is odelia's primary consumer and **leads the upstream API by application** — new
  odelia surface is proposed from a concrete plant need, not speculatively.
  (Resolves old open-question #2.)
- **Do not merge the spike; codesign odelia first.** The spike should **not** land
  on `develop` as-is. Landing a second tape lifecycle, a third scalar axis, and
  duplicated reductions — then refactoring them away — is the tail-chasing to
  avoid. Instead: (1) the §11 measurement decides the scalar model; (2) the odelia
  generic surface (`compute_jacobian`, injected-seed, native-observation seam)
  lands as the **foundation slice**; (3) plant's engines are rebuilt onto it
  strategy-by-strategy, each bit-checked against the spike's own AD-vs-AD fixture.
  The spike is the **specification and the test oracle** (its validated Jacobians
  are its durable value), not the merge candidate. (Supersedes the "fold into the
  spike's stack" leaning in §4b/§6-Step-0.)

## 13. What would sharpen the next round

- **The spike's benchmark/tape numbers** (`scripts/bench_gradient.R`, any
  `tape.getMemory()` figures) — to pre-inform the §11 A/B before building it. If
  they don't exist, the §11 spike produces them.
- **The authoritative metric set and kernels** — which emergent metrics
  `stand_gradient` must differentiate (LAI, biomass, basal area,
  offspring_production, census-at-time…) and their `psi` kernels, so the
  `Strategy` concept's reduction interface covers them in one shape.
- **TF24/TF24f leaf-optimizer coverage** — the PR notes a "leaf-optimizer
  cross-sensitivity gap" (TF24 census metrics unavailable). Whether that is a
  physics limit or a plumbing limit tells us if the `Strategy` concept can cover
  TF24 census or if it is legitimately out of scope for v1.
- **Confirmation on second-order** — this design assumes no Hessian/`fwd_adj`
  requirement. If curvature is ever wanted (e.g. optimizing the emergent
  gradient), it changes the mode story; flag it now if so.

I have enough XAD documentation (the vendored headers are authoritative) and
enough of both codebases to draft the odelia API sketch and the §11 measurement
spike whenever you want to move from discovery to a concrete proposal.

---

## Appendix: source references

**odelia (AD runtime):**
- `inst/include/XAD/Jacobian.hpp` — `xad::computeJacobian` (adjoint + forward
  variants); the template for `odelia::compute_jacobian` (§9)
- `inst/include/XAD/Interface.hpp` — `xad::adj` / `xad::fwd` (and `fwd_adj`,
  out of scope) mode structs
- `inst/include/odelia/ode_fit.hpp` — `compute_gradient`, `sum_of_squares`
- `inst/include/odelia/ode_solver.hpp` — `Solver`, persistent `tape`,
  `set_target`/`advance_target`
- `inst/include/odelia/spline.hpp` — `basic_spline<S>`, scalar-templated band
  solve (freeze positions / differentiate values)
- `inst/include/odelia/interpolator.hpp` — `basic_interpolator<S>`
- `inst/examples/leaf_thermal/src/leaf_thermal_system.hpp` — System AD contract
  (`value_type`, `set_params`, `set_initial_state`)
- `ARCHITECTURE.md` — the Tape linking / single-`active_tape_` contract

**plant (spike):**
- `DESCRIPTION` — `LinkingTo: odelia`; `Imports: odelia`
- `src/{ff16,tf24,tf24f}_emergent.cpp` — the three replay engines
- `R/{emergent_gradient,tf24_emergent_gradient,tf24f_emergent_gradient}.R` —
  R harvest + `Rcpp::as<>` round-trip
- `inst/include/plant/gradient/{scm_harvest.h, coupled_canopy.h}` — the emergent
  reductions (`census_trapezium`, `offspring_weights`, `canopy_comp_at`); §10
- `src/leaf_model.cpp` (`dprofit_droot_collar_psi`), `src/tf24_strategy.cpp`,
  `src/tf24f_strategy.cpp` — leaf-optimizer **forward-mode** AD (IFT + envelope,
  seed-tangent injection); §9 — stays plant-local
- `inst/include/plant/models/ff16_strategy.h` — per-method `template<typename S>`
  members (`area_leaf<S>`, `update_dependent_aux<S>`) and the double `pars`; §11
- `inst/include/plant/{individual,node,species,patch}.h` — the `<T, E, S>`
  third axis
- `inst/include/plant/scm.h` — `odelia::ode::Solver<patch_type> solver`
- `notes/ad-refactor-optimize-roadmap.md` — the spike's own (plant-internal)
  refactor plan; Phase 3's "irreducible biology" finding motivates §4
