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

## Appendix: source references

**odelia (AD runtime):**
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
- `inst/include/plant/gradient/{scm_harvest.h, coupled_canopy.h}` — the
  already-shared plant-specific reductions (keep)
- `inst/include/plant/{individual,node,species,patch}.h` — the `<T, E, S>`
  third axis
- `inst/include/plant/scm.h` — `odelia::ode::Solver<patch_type> solver`
- `notes/ad-refactor-optimize-roadmap.md` — the spike's own (plant-internal)
  refactor plan; Phase 3's "irreducible biology" finding motivates §4
