# AD record → replay: the one adaptive-numerics primitive (ODELIA-6)

**Status:** the ODELIA-6 mechanism has landed (PR odelia#21 — `Replayable` concept,
`Interpolator<S>` on the AD path, RelaxationSystem, L1/L2/L3 tests). This doc now also
records the design refinements from review that the *follow-on* issues execute against:
the two-capability split (§2, §4), the driver-set frozen mode + `replay_against` handoff
(§4.1), calibration as an extension not the foundation (§6), and the RIF-3 rescope (§5).
**Scope:** `traitecoevo/odelia` — the record→replay primitive under every adaptive
construction on the AD path. Applies in plant unchanged in shape (the light spline
and the crown quadrature record the same way); the plant `QK` node-set is
out of odelia scope but must slot into the identical machinery.
**Companions:** [`ad-infrastructure-design.md`](./ad-infrastructure-design.md) §7
(replay levels); [`ad-r-interface.md`](./ad-r-interface.md) §3.3 (tape/scratch reuse),
§6.8 (the model-developer story this specs against); [`ad-issues.md`](./ad-issues.md)
ODELIA-6. Issues: odelia#18 (ODELIA-6), odelia#12 / PR odelia#17 (RIF-3), odelia#19 /
plant#3 (the hook rename), plant#4 (the RIF-5 frozen-variant driver codesign).

---

## 1. Thesis

Every adaptive numerical construction in the stack — the RKCK stepper, the light
interpolator, the crown-depth quadrature — exists to *discover where to place nodes*
to hit a tolerance **without knowing the answer**. On a gradient pass we already ran
the adaptive pass once, so we already know where the nodes go. Re-discovering them is
pure overhead, and differentiating *through* the adaptive branching is fragile. So:

> **Record** where the double (adaptive) pass placed its nodes. **Replay** pinned to
> those nodes with the active scalar, no adaptive branching, and read the adjoints.

The double pass, once recorded, is **immutable** — its only job is to feed replays.
This is one idea; the apparent "levels" (§2) are the *same* idea applied at different
depths, and they collapse to a single System concept (§4).

---

## 2. Two freezes, not one ladder

The L1/L2/L3 in the design doc read like a ladder. They are really **two orthogonal
capabilities** a replay needs, distinguished by *what* is frozen and *why*:

**A — Node-position freeze (structural; required for AD; automatic).** Every adaptive
construction — the ODE stepper, an interpolator, a quadrature — makes
parameter-dependent decisions about *where to place nodes*. Those branches corrupt the
tape, so the double pass records the node **positions** and the AD pass replays them
**fixed**. Only the adaptive *structure* is frozen; the node **values stay live and
differentiable**. This is switched on by *doing reverse-mode AD* on a system that has
such a component — not a user choice, not a workflow. `times()` is the universal
instance (every ODE has a stepper; this is L1); an interpolator/quadrature is the
per-system instance (L2). Lorenz has none — the reason RelaxationSystem exists.

**B — Value freeze (semantic; optional; workflow-chosen).** Separately, a run may hold
some *recomputable quantity* **constant** — its derivative zero by construction. plant's
rare mutant reading a fixed resident field is one instance, but the quantity **need not
be an "environment" and need not be an interpolator**: it can be a held-fixed sub-state
or frozen state variables. "Environment" is a plant term that leaked into the odelia
core when the solver lived there. This *is* a per-call choice — expressed by **calling
the variant entry** (a `run_mutant`-style function), not a `feedback` flag.

The two map onto positions vs. values, and that explains the recording granularity:

| Freeze | What's recorded | Granularity | Gated by |
|---|---|---|---|
| **A — structural** | node **positions** (step times, knots) | per ODE step (they don't move across a step's 6 stages) | doing AD (automatic) |
| **B — semantic** | field **values** | per RK stage (each stage evaluates at a different state) | choosing the variant entry |

You only pay per-stage density when you freeze *values* (B), and you only freeze values
when you refuse to recompute them. plant's own comments name this split — a *"cheaper
per-step reconstruction"* vs. the *"faithful-to-the-SCM"* per-stage harvest.

### 2.1 One recorded pass serves both feedbacks

A single "prepare for gradients" run must serve **both** a later resident gradient *and*
many invasion gradients — the user does not re-run per feedback choice. So the double
pass records the **union** (node positions *and*, when capability B is wanted, the
per-stage values); each consumer reads its slice:

| Consumer | Reads | On the active pass | Cross term |
|---|---|---|---|
| **Resident / total** (live) | the recorded **positions** | recompute the field on frozen knots with active state → self-feedback flows | present |
| **Mutant / invasion** (frozen) | the recorded **values** | read as `double` background — off the tape, no recompute; only the mutant's own state is active | zero |

So it is *not* "each consumer records what it needs" — it is **one pass records the
union; each consumer reads its slice.** plant already does exactly this
(`stand_height_history` positions **and** `environment_history` values,
`patch.h:151-218`). Capability A alone (no B) is the resident-only / bare-AD case;
B adds the per-stage values for the frozen variant.

---

## 3. Where each thing already lives

Most of "the recording" is **already state on objects we have** — which is why odelia
should *not* grow a fat `Recording` noun that hoards knots (§4).

- **The ODE schedule is Solver state.** `solver.times()` already holds the resolved
  step times; replaying is `advance_fixed(times())` — "run the same steps again." No
  new concept. (This is design §7.5's L1, and it already works.)
- **The field nodes/values are System state.** plant's `Patch` already owns
  `step_history` / `environment_history`; an odelia example System owns its
  interpolator's knots. odelia has no business knowing a knot is a height.

The active replay reads those recorded doubles directly — a **plain-double handoff**,
since positions and values are always `double`. For a resident gradient the active System
reads its own recording; for a mutant it reads the **resident's** recording as background
(the native-pointer harvest, RIF-6 — no R round-trip, no serialisation). No fancy channel
and no `Recording` noun: the recording is thin System state and the numerics are rebuilt
from it.

---

## 4. One `Replayable` concept — capability A automatic, capability B a driver-set mode

There is **one** System, not resident and mutant *flavours*; it is driven live or frozen
per call (plant's `run` vs `run_mutant`). So record/replay is one concept — but the two
capabilities of §2 enter it differently, and keeping that clear is what stops "mode"
from becoming a muddle:

- **Capability A rides the AD call.** Whenever the System records node positions, the
  stepper replays them — no flag, no mode. It is just the `Replayable` hooks plus the
  fixed-node numerics.
- **Capability B is a runtime mode the driver sets** (`replay_live()` / `replay_frozen()`)
  and odelia's stepper queries — replacing the magic `use_cached_environment` member
  `derivs` reads today. Live recomputes on the recorded positions; frozen reads the
  recorded values.

```cpp
// Names illustrative -- settled in odelia#19 (record_step collides with the history
// record_step(), resolved there). Absent hooks -> zero-cost no-op; nothing forces a
// System to be differentiable or replayable.
template <class S>
concept Replayable = requires(S s, int stage) {
  s.record_step();          // capability A: per ODE step (node positions; flush)
  s.record_stage(stage);    // capability B: per RK stage (values, when kept)
  s.replay_step();          // per step on the active pass (restore / advance index)
  { s.replaying_frozen() } -> std::convertible_to<bool>;  // capability B mode query
};
```

The stepper calls these behind `if constexpr (Replayable<System>)` (replacing the
`has_cache` SFINAE trait, design §7.6). The frozen selector is **correctly a settable,
driver-set flag**, not a compile-time trait: the same Patch is live for a resident
gradient and frozen for an invasion gradient, so the mode is a per-call choice
(plant#4 codesigns how RIF-5 sets it, `run` vs `run_mutant`). An earlier draft proposed
a `const` accessor — wrong: it would make `run_mutant` inexpressible on a cached replay.
The `replaying_frozen()` **query** belongs in the concept (it completes the contract
`derivs` depends on); the `replay_live()`/`replay_frozen()` **setters** are the driver's
handle on the mode.

### 4.1 What odelia grows, and what it does not

**Grows (small):**
1. `Replayable` + the `if constexpr` dispatch — the concept-gated step/stage/load hooks.
   These stay **thin**: the System forwards the stepper's cadence signals to its own
   recording (only the stepper knows the boundaries; only the System knows what it keeps).
2. **Nothing new for the numeric.** `basic_interpolator<S>` **already** carries active
   values on fixed `double` knots (odelia#32) — it *is* the AD-compatible replay
   interpolator, and many systems already share it. The System records the adaptive knots
   on the double pass and rebuilds it (active values) on replay; `QK<S>` is the plant
   instance of the identical seam. **We never refine a recorded interpolator** — *refine*
   is the double/record path, *fixed build* the active/replay path.
3. **The capability-B mode selector** — `replay_live()` / `replay_frozen()`, set by the
   driver (`run` vs `run_mutant`), queried via `replaying_frozen()`; never a `feedback`
   flag. Frozen (L3) loads the recorded field as **`double` background** the active solve
   reads — off the tape entirely; only the mutant's own state is active. It is *not* an
   active constant with a zeroed derivative — the field is simply double data, and it
   generalises past the interpolator to any recorded sub-state.

**Does not grow:** a `Recording` noun, a `ReplayableInterpolator` class, or any
"environment" vocabulary. The schedule is `times()` (Solver-owned); the nodes/values are
thin System state; the numeric (`basic_interpolator<S>`, later `QK<S>`) is **stateless**
and rebuilt from the recording. Retiring the `basic_` name and merging plant's
`AdaptiveInterpolator` (the refiner) into one replayable interpolator is a *separate*
cross-package change — the type is RcppR6-bound throughout plant — tracked as its own
issue, not smuggled into ODELIA-6.

---

## 5. Interaction with RIF-3 (odelia#12 / PR odelia#17)

Two different things wear the word "cache" in this stack, and conflating them is the
central hazard RIF-3 must avoid:

| Concept | What | Effect of reuse | Owner |
|---|---|---|---|
| **cache** (RIF-3) | amortized tape buffer + active scratch System | *speed* only — never changes a number | the double Solver |
| **record / replay** (ODELIA-6) | the resolved schedule + the System's node stash | *semantic* — changes the number a gradient returns | the immutable double Solver / its System |

Settle the vocabulary as **cache = amortized scratch; record/replay = the recording**,
and the split RIF-3 needs falls out (this is the odelia#19 / plant#3 rename):

- **Cache only the scratch.** The tape + active scratch carry no semantics between
  calls; reusing them is pure amortization, correct at every level.
- **Read the recording per call.** The schedule (`times()`) and the System stash live
  on the immutable double Solver and are read on the call — **not** frozen into the
  scratch at first build, **not** carried through `rebind_from` (which stays
  values-only, RIF-2), **not** smuggled through `set_target`.
- **Validity domain.** The recording is keyed to the ICs + params of the double run —
  those fix the schedule and the knots. A cached run may be replayed with a different
  **mutant** or a different **functional / observations**; changing ICs or params
  invalidates the recording and forces a re-record (never a silent reuse against a
  stale schedule).

### 5.1 The anchor: on the Solver object, not the R handle — settled

PR odelia#17 anchors the cache on the odelia `Solver` XPtr's `prot` slot
(`solver_interface.hpp:177`). That slot exists **only when R holds the odelia Solver
directly** (the Lorenz / leaf test wrappers). plant's SCM holds the solver as a plain
**C++ member** (`scm.h:133`: `odelia::ode::Solver<patch_type> solver;`) and never wraps
it in its own XPtr — so as written, plant's `stand_gradient_cpp` (RIF-5) both inherits
**no reuse** and cannot call the XPtr-shaped `cached_active_replay` at all.

So §3.3's "owned by the double `Solver`" is not optional — the SCM-as-member reality
**forces** the cache onto the `Solver` object:

- Move the amortized scratch to a `Solver` member. Follow the precedent already there
  (`Solver` carries a raw `xad::Tape<double>* tape`): a `mutable std::shared_ptr<void>`
  populated on the first gradient call and `static_cast` back at the driver, where the
  active type is known. **No base class, no vtable** (`ADScratchBase` is rejected — a
  name and a shape that both smell), and a null pointer for any System that never gets
  a gradient — nothing mandates a System be differentiable.
- The recording rides the same object for free: the `Solver` member already holds the
  double System (whose stash is the per-run recording) and `times()`. plant's SCM member
  therefore gets the scratch reuse *and* the recording with no XPtr and no `prot`.
- Read-only surface for honesty and the "forgot to record" error (§6.7 of the R-interface
  doc): `has_recording()` / `recorded_steps()`.

---

## 6. `set_target` is one functional, not the foundation

`set_target` / `advance_target` was the first cut and must not lead the design. The
foundational blocks are **an arbitrary functional** (odelia#1/#2 — a callable that
drives a seeded Solver and returns the scalar(s)) and **replay-fixed** (this doc).
`sum_of_squares_loss` is just the first functional built on them; it reads observations
at the recorded steps. An emergent functional (plant's word, not odelia's — in odelia
it is simply another functional) reads native state at the recorded steps and never
touches a target. Calibration is *one case among many*, exactly as the user stories
frame it (`ad-r-interface.md` §6) — necessary, not primary.

---

## 7. The odelia-native example System (de-dormant the plane)

Neither Lorenz nor leaf_thermal implements the hooks, so `Replayable` is false
everywhere and the whole plane past L1 is untested. ODELIA-6 needs one odelia example
System with an **internal adaptive interpolator** — deliberately the odelia-native
shrink of FF16's resident light, so a green test here is a proven template for the plant
port.

**Mini self-shading relaxation** (plant-agnostic framing: *a reaction network whose
per-node rate reads a self-consistent field interpolated over the node positions*):

- **State:** `a_i(t)`, `i = 1..N` at fixed positions `z_i`.
- **Coupling:** a field `L(z) = Σ_j a_j · Q(z − z_j)` built by an **adaptive
  interpolator refined over `z` to a tolerance** (genuinely adaptive — not a rigged
  grid).
- **Dynamics:** `da_i/dt = g(L(z_i); θ)`, with `θ` the differentiable parameter.
- **Functional:** `Σ_i a_i(T)`.

One System, one runtime mode flag, exercises all three depths:

- **L1 — schedule freeze.** Record `times()` on the double Solver; replay
  `advance_fixed` on the active Solver. Assert value reproduces to floating point and
  the gradient matches central finite differences.
- **L2 — interpolator freeze (live).** Record the interpolator knots per step; replay
  with the frozen-knot `Interpolator<S>` carrying active values, field recomputed. The
  first `Replayable == true` case on the AD path. Value + gradient-vs-FD.
- **L3 — frozen field.** Save `L(z_i)` values per stage; hold them constant on the
  active pass. Assert the cheap trajectory reproduces the resident and the gradient is
  correct (field contribution zero, as for a mutant).
- **Reuse (ties RIF-3).** Repeated gradient calls reuse the tape/scratch and reproduce
  the first result; a recording from a *fresh* double pass is picked up per call (the
  anti-staleness assertion the frozen-once cache cannot currently make).

---

## 8. Mapping to plant (FF16 / TF24 / TF24f) and QK

The Systems differ only in **which node-sets** they record — the "field nodes" are a
*list* of position-sets, each consumed live-or-frozen:

- **FF16** records the light-spline knots. Resident → live recompute; mutant → frozen.
  No leaf optimizer. This is the direct analogue of §7's example.
- **TF24 / TF24f** additionally record the **crown-depth quadrature nodes** (the `QK`
  case) and route the leaf-optimizer sensitivity through an `AnalyticEdge` (odelia#8).
  TF24f's coupled resident feedback is the stiff long-horizon gate (design §7.5, §11).

`QK<S>` lives in plant and is out of odelia scope, but it is the same shape as
`Interpolator<S>` — record positions, replay fixed, choose frozen/live — so the odelia
primitive and the `Replayable` concept must be general enough that plant adds a
quadrature node-set without a new mechanism. The single-concept, positions-vs-values
model of §2/§4 is what guarantees that.

---

## 9. Definition of done & sequencing

**Landed (ODELIA-6, odelia#18 / PR odelia#21):**
- One `Replayable` concept (C++20 `requires`) replaces the `has_cache` SFINAE.
- `Interpolator<S>` (frozen knots, active values) is exercised on the AD path — the
  plane is no longer dormant.
- The schedule replays via `advance_fixed(times())`, read independently of
  `set_target`; RelaxationSystem's L1/L2/L3 + reuse tests are green vs finite
  differences.

  *Corrections still owed on the PR #21 example* (tracked on the PR): it carries the
  superseded L3 framing (the frozen field cast to an active constant with a zeroed
  derivative) — it should be **`double` background** the active solve reads (§4.1); the
  `use_cached_environment` member stays a driver-set flag; and the example wants a
  concrete reskin so it reads like Lorenz. The `Replayable` concept and the interpolator
  usage themselves are sound.

**Follow-ons (separate issues, execute against this spec):**
- **odelia#19 / plant#3** — the hook rename (`cache_*`/`load_*` → `record_*`/`replay_*`),
  the `use_cached_environment` → `replaying_frozen()` mode-query split, the `record_step()`
  history collision, and the `cache`/`load` free-function overloads.
- **plant#4** — the RIF-5 contract. The two workflows are `run` (live) and `run_mutant`
  (frozen); there is **no `feedback` flag** and the per-metric `stand_gradient` /
  `offspring_gradient` C++ entries are spike remnants — one differentiated run, the metric
  is the functional argument. The mutant reads the resident field as `double` background.
- **Interpolator unification (new issue)** — merge plant's `AdaptiveInterpolator` (the
  double refiner) with odelia's `basic_interpolator<S>` (the fixed evaluator) into one
  replayable interpolator and retire the `basic_` name. Cross-package and RcppR6-bound
  (the type is used throughout plant); **not** ODELIA-6. `basic_interpolator<S>` already
  serves the L2 replay today (odelia#32), so this is a naming/packaging cleanup, not a
  functional gap.
- **RIF-3 (odelia#12 / PR odelia#17)** — amortized scratch moves to a `Solver` member
  (`shared_ptr<void>`), recording read per call; correct for `Replayable == true`;
  anti-staleness test. `cached_active_replay` clarified.
- **Calibration decouple (Finding #1)** — `set_target`/`advance_target`/`fit_times_`/
  `targets_`/`obs_indices_` move off the generic `Solver` onto a calibration functional
  that samples the trajectory at observation times (independent of the ODE schedule).

**Sequencing.** ODELIA-6 (PR odelia#21) is the landed foundation and stays lean. The
follow-ons run against this spec; RIF-3 is re-scoped **on its own branch**
(`claude/rif-3-tape-cache`, rebased onto ODELIA-6) per one-PR-per-issue, not stacked
above it.
