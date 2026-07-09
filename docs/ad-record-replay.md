# AD record → replay: the one adaptive-numerics primitive (ODELIA-6)

**Scope:** `traitecoevo/odelia` — the record→replay primitive under every adaptive
construction on the AD path. It applies in plant unchanged in shape (the light spline
and the crown quadrature record the same way); the plant `QK` node-set slots into the
identical machinery.
**Companions:** [`ad-infrastructure-design.md`](./ad-infrastructure-design.md) §7
(replay levels); [`ad-r-interface.md`](./ad-r-interface.md) §3.3 (tape/scratch reuse),
§6.8 (the model-developer story); [`ad-issues.md`](./ad-issues.md) ODELIA-6. Issues:
odelia#18 (ODELIA-6, the primitive), odelia#12 (RIF-3, scratch reuse), odelia#19 /
plant#3 (the hook rename), plant#4 (the RIF-5 driver contract).

---

## 1. Thesis

Every adaptive numerical construction in the stack — the RKCK stepper, the light
interpolator, the crown-depth quadrature — exists to *discover where to place nodes*
to hit a tolerance **without knowing the answer**. On a gradient pass the adaptive
pass has already run, so the node placement is already known. Re-discovering it is
pure overhead, and differentiating *through* the adaptive branching is fragile.
Therefore:

> **Record** where the double (adaptive) pass placed its nodes. **Replay** pinned to
> those nodes with the active scalar, no adaptive branching, and read the adjoints.

The double pass, once recorded, is **immutable** — its only job is to feed replays.
This is one idea; the apparent "levels" (§3) are the *same* idea at different depths,
and they collapse to a single System concept (§5).

---

## 2. The system, in four names

An AD run holds exactly three nouns and one verb; the whole design fits in them.

- **the double solver** (`d`) — the real adaptive run. R holds it. It is immutable
  after its pass, and it **owns the recording**.
- **the active replay** — the double System lifted to the active scalar (the RIF-2
  rebind): the differentiable twin the gradient runs on. It holds **no** semantics
  between calls — it is re-seeded and re-fed the recording every call.
- **the recording** — the schedule plus the node stash the double pass produced,
  read *per call*.
- **replay** (the verb) — the twin re-running the double's recorded schedule with the
  active scalar.

Reuse of the twin and its tape (RIF-3, §7) is a *property* of the active replay, not a
concept of its own: it is kept on the double solver and reused so an optimiser loop
does not rebuild it. It never changes a number.

---

## 3. Ownership sets the layers

The **Solver** is the generic engine: it steps arbitrary systems, either adaptively
(discovering node positions) or on a fixed grid (replaying them). The **System** owns
whatever field it builds to compute its rates. That ownership split *is* the layer
ladder:

| Layer | Recorded thing | Cadence | Owner | Needs |
|---|---|---|---|---|
| **L1** | the step **schedule** (`recorded_steps()` = `times()`) | per accepted step | **Solver** | nothing — always present, always differentiable |
| **L2** | the System's adaptive **node positions** (interpolator knots, `QK`/QAG subdivision) | **per step** | **System** | *record positions* |
| **L3** | the System's **background field** values | **per RK stage** | **System** | *record positions and values, and freeze* |

L1 is universal: every ODE has a stepper, so every System replays its schedule via
`advance_fixed(recorded_steps())` with no System participation. L2/L3 are the System's
own state; the stepper only signals cadence.

### 3.1 Positions are per step; values are per stage — and why

The cadences are not a stylistic choice; they follow from what each freeze is *for*.

**Positions freeze per step.** The only reason to freeze node positions is to keep the
parameter-dependent adaptive *branching* off the tape — the refinement decisions are
`double`-valued control flow. One representative position set per step removes the
branching completely. It is representative *by construction*: the step-size controller
accepts a step only when the RKCK error estimate stays under tolerance, i.e. only when
the state — and hence the field's adaptive structure — varies within the step by less
than tolerance. If it varied more, the step would be rejected and halved. Any residual
difference between a step's representative positions and a stage's ideal positions is a
discretization difference *below* tolerance — the noise floor the adaptive scheme
already accepts. Recording positions per stage would be six times the storage to
resolve something already inside the tolerance band.

**Values freeze per stage.** A frozen background is different in kind: each RK stage
evaluates the field at a genuinely different state, and a frozen consumer must read
back the *exact* value that stage consumed — a real quantity, not a discretization
choice. A per-step value would be wrong, not merely coarse.

### 3.2 One recording, read as two slices

A single double pass records the **union** — positions *and* values — in one
accumulate/commit cycle (§5). Each consumer reads its slice:

| Consumer | Reads | On the active pass | Cross term |
|---|---|---|---|
| **resident / total** (live) | the recorded **positions** | recompute the field on frozen positions with active state → self-feedback flows | present |
| **mutant / invasion** (frozen) | the recorded **values** | read as `double` background — off the tape, no recompute; only the mutant's own state is active | zero |

The union is forced by cross-feedback, not by the hook design: a `run_mutant` reads the
*resident's* per-stage values, so the resident's `run` must record values for mutants
it cannot foresee. It records them anyway for free — the per-stage record hook captures
the positions (at stage 0) and the values (each stage) together. plant already records
exactly this union (`stand_height_history` positions **and** `environment_history`
values, `patch.h`).

---

## 4. Generality: not the interpolator, not the environment

Because the recording is System state and the core hooks carry only cadence, both
freezes generalise past the odelia example:

- **L2 is any adaptive component.** The record hooks stash whatever *positions* a
  System's adaptive machinery chose — spline knots for an interpolator, the Gauss–
  Kronrod subdivision for `QK`/QAG, or a *list* of position-sets for a System with
  several (a TF24 Patch records the light-spline knots **and** the crown-depth
  quadrature nodes through the identical hooks). Nothing in the concept or `derivs`
  names a knot.
- **L3 is any recomputable sub-state.** A frozen background is whatever doubles a
  System stashed per stage — a held-fixed sub-state, frozen state variables, a canopy —
  not specifically an interpolated field. `derivs` calls `set_ode_state(y, index)` and
  the System decides what that reads.

"Environment" is a plant term; the odelia-neutral word is **field**, meaning the
background coupling a rate reads. odelia grows no `Recording` noun and no
`ReplayableInterpolator` class: the schedule is `times()` (Solver state), the
positions/values are thin System state, and the numeric (`basic_interpolator<S>`,
`QK<S>`) is stateless and rebuilt from the recording.

---

## 5. One `Replayable` concept: three signals and one query

There is **one** System, driven live or frozen per call (`run` vs `run_mutant`), and
one concept the stepper dispatches on behind `if constexpr (Replayable<System>)`. An
absent hook makes every call site a zero-cost no-op; nothing forces a System to be
differentiable or replayable.

```cpp
template <class S>
concept Replayable = requires(S s, int stage) {
  s.record_stage(stage);                                   // accumulate (per RK stage)
  s.record_step();                                         // commit    (per accepted step)
  s.replay_step();                                         // load      (per step, active pass)
  { s.has_recorded_field() } -> std::convertible_to<bool>; // the mode query
};
```

The three signals are two nested loops of the adaptive stepper, not two recordings:

| Signal | Fires | Job |
|---|---|---|
| `record_stage(k)` | per RK stage, record pass | accumulate the union (positions@0, value@k) into scratch |
| `record_step()` | per **accepted** step, record pass | commit the scratch → recording |
| `replay_step()` | per step, active pass, before the stages | load this step's positions / advance the recording index |

`record_stage` and `record_step` are two because adaptive step **rejection** forces
commit-on-accept: a rejected step re-runs its stages, harmlessly clobbering the
scratch; only an accepted step commits. Folding the commit into the per-stage hook
would record rejected steps. `replay_step` is separate because positions must load
*before* a step's stages run. This is the minimal seam — three signals, one query.

### 5.1 `ReplayMode`: illegal states unrepresentable

A Replayable System is in exactly one of four states, held as one enum rather than
three booleans (which admit nonsense combinations like recording-and-replaying):

```cpp
enum class ReplayMode { Idle, Recording, ReplayLive, ReplayFrozen };
```

- `record_stage` / `record_step` act only in `Recording`.
- `replay_step` acts in `ReplayLive` and `ReplayFrozen`.
- `has_recorded_field()` is `mode == ReplayFrozen`.

The driver sets the mode: `Recording` on the double pass, `ReplayLive` for `run`,
`ReplayFrozen` for `run_mutant`. The enum values *are* the runs of §6, and the "one
bit" `run`/`run_mutant` flips is a named state. The mode is System-internal
bookkeeping; the core sees only the four concept members.

---

## 6. Control flow of an AD run

Three runs share the identical stepper, `advance_fixed`, and tape machinery. They
differ in exactly three slots: which **system** the twin carries, which **slice** of
the recording it reads, and the `has_recorded_field()` **query** inside `derivs`.

### 6.1 `run` (double) — the record pass

```
d.advance_adaptive({0, T})                                   [mode = Recording]
  per adaptive step  step():
    retry loop:
      stepper.step():  6 RK stages
        per stage k:  derivs(sys, y, k, t):  set_ode_state(y, t)   ← field on ADAPTIVE positions
                      record_stage(k)                              → accumulate: positions@0, value@k
      accept? ─no─→ shrink h, undo y/t, retry   (scratch clobbered)
             └yes─→ record_step()                                  → COMMIT scratch → recording[step]
  ⇒ recording = schedule times() (L1) + positions/step (L2) + values/step×stage (L3)
     owned by d, immutable hereafter
```

### 6.2 `run` (active) — resident / live gradient

The twin carries the resident system, reads its **own** recording, and recomputes the
field so self-feedback flows.

```
twin = active_replay(d)                                      [mode = ReplayLive]
  schedule  → advance_fixed grid          (L1, Solver→Solver)
  recording → twin.system  (positions read, values ignored)  (L2, System→System)
  tape on; computeJacobian(trait/IC seeds, forward):
    forward(x):
      twin.system.scatter(x, slots); twin.reset()
      twin.advance_fixed(times):           ← replay schedule, NO adaptivity
        per step step_to:
          replay_step()                    → load THIS step's frozen positions
          stepper.step(): per stage derivs(...,k):
            query false → set_ode_state(y, t)   REBUILD field on FROZEN positions,
                                                ACTIVE values (gradient flows; self-feedback)
      return state
    seed adjoints → sweep → ∂functional/∂trait   (with self-feedback)
  tape off
```

### 6.3 `run_mutant` (active) — mutant gradient only

The twin carries the mutant system, reads the **resident's** recording as fixed
background, and the field is read back off-tape (its derivative zero).

```
twin = active_replay(d_resident)  (mutant system)            [mode = ReplayFrozen]
  schedule           → advance_fixed grid   (L1)
  RESIDENT recording → twin.system  (values read, positions ignored)  (L3, System→System)
  tape on; computeJacobian(MUTANT seeds, forward):
    forward(x):
      twin.system.scatter(x, slots); twin.reset()   ← background ← recorded value[0]
      twin.advance_fixed(times):
        per step step_to:
          replay_step()                    → advance index (positions unused)
          stepper.step(): per stage derivs(...,k):
            query true → set_ode_state(y, k)   read recorded value @stage k as DOUBLE
                                               background (off tape, ∂/∂field = 0)
      return mutant state
    seed adjoints → sweep → ∂functional/∂mutant-trait   (field contribution 0)
  tape off
```

The only forks are inside `derivs`, keyed by the mode; the stepper never learns what a
position *is*. The differentiation trick, stated once: on replay the node **positions**
are frozen doubles (no adaptive branching to corrupt the tape) while the node
**values** stay active — so the gradient flows through *what the nodes hold*, never
through *where they sit*. L3 goes one step further and takes the field off the tape
entirely.

---

## 7. RIF-3: reuse the twin, read the recording per call

A gradient call builds an active replay, records a tape, sweeps it, and reads adjoints.
An optimiser loop (or a batch of mutants against one recording) calls this repeatedly.
Rebuilding the twin and reallocating the tape every call is waste; the reuse stays
invisible to R.

**The twin is the only cached thing.** The gradient runs on the twin, and a `Solver`
carries its own `tape`, so `twin.tape` *is* the reused tape — there is nothing else to
cache. The twin is held on the double solver as a `mutable std::shared_ptr<void>
active_replay`, built once and reused; it is opaque because a double `Solver` cannot
name the active type, so the driver `static_cast`s it back. `Solver::tape` is a
`std::unique_ptr` — ownership is self-evident, no hand-written destructor.

**Anchored on the Solver object, not an R handle.** plant holds the solver as a plain
C++ member (`scm.h`: `Solver<patch_type> solver;`) and never wraps it in an XPtr, so an
anchor on the R XPtr's `prot` slot is invisible to it. Anchoring the twin on the
`Solver` object gives the SCM the reuse for free.

**The recording is read per call, never frozen into the twin.** The schedule and node
stash live on the immutable double solver/System and are handed to the twin on every
call — not snapshotted at first build, not carried through `rebind_from` (values-only,
RIF-2), not smuggled onto the solver as fit state. Each consumer hands over its own
slice: the calibration entry hands its observations (in the `least_squares` functional),
a record→replay System hands its recording (`set_recording`). Reusing the twin is
therefore pure speed; the number a
gradient returns comes entirely from the per-call recording and seeds.

**Validity domain.** The recording is keyed to the ICs + params of the double run;
those fix the schedule and the positions. A cached run may be replayed with a different
**mutant** or a different **functional / observations**. Changing ICs or params
invalidates the recording and forces a re-record — reading it per call is what makes
that pickup automatic rather than a stale reuse.

**Read-only surface.** `has_recording()` (a schedule has been resolved) and
`recorded_steps()` (that schedule) are the honest guard behind the "forgot to record"
error (`ad-r-interface.md` §6.7).

Two senses of "cache" stay distinct: **cache = the amortized twin/tape (speed);
record/replay = the recording (semantics).** Reusing the cache never changes a number;
the recording is what does.

---

## 8. Calibration is one functional, not the foundation

The foundational blocks are **an arbitrary functional** (odelia#1/#2 — a callable that
drives a seeded solver and returns the scalar(s)) and **replay-fixed** (this doc).
`least_squares` is the first functional built on them; it owns its measured
observations and sampling schedule and reads the model's predicted observations at the
recorded steps (via the solver's generic `advance_observations`). An emergent functional
reads native state at the recorded steps and carries no observations. Calibration is one
case among many, not the primary one — and its data lives in the functional, not the
solver.

---

## 9. The odelia-native example (RelaxationSystem)

Neither Lorenz nor leaf_thermal implements the hooks, so `Replayable` is exercised by
**RelaxationSystem**: the odelia-native shrink of FF16's resident light — a scalar
state whose rate reads a field built by an adaptive interpolator over state-dependent
node positions. It carries one differentiable input (`gain`) and one `ReplayMode`, and
exercises all three depths against finite differences:

- **L1 — schedule freeze.** Record `times()` on the double solver; replay
  `advance_fixed` on the twin. Value reproduces to floating point; gradient matches
  central FD.
- **L2 — interpolator freeze (live).** Record the knots per step; replay with frozen
  positions carrying active values, field recomputed. The first `Replayable == true`
  case on the AD path. Value + gradient-vs-FD.
- **L3 — frozen field.** Read the recorded per-stage values as `double` background;
  the trajectory reproduces the resident and the field's gradient contribution is zero
  (the invasion property in miniature). The field is plain double data — never an
  active constant with a zeroed derivative.
- **Reuse (RIF-3).** On a persistent double solver, repeated gradient calls reuse the
  twin and tape and reproduce; a recording from a *fresh* double pass is picked up per
  call (the anti-staleness assertion Lorenz's L1-only cache cannot make); live and
  frozen replays share one twin with the mode chosen per call; replay-before-record
  errors.

---

## 10. Mapping to plant (FF16 / TF24 / TF24f) and QK

The Systems differ only in **which node-sets** they record — a *list* of position-sets,
each read live or frozen:

- **FF16** records the light-spline knots. Resident → live recompute; mutant → frozen.
  The direct analogue of §9.
- **TF24 / TF24f** additionally record the crown-depth quadrature nodes (the `QK` case)
  and route the leaf-optimizer sensitivity through a `SuppliedDerivative` (odelia#8).
  TF24f's coupled resident feedback is the stiff long-horizon gate.

`QK<S>` lives in plant and is out of odelia scope, but it is the same shape as
`Interpolator<S>` — record positions, replay fixed, choose frozen/live — so plant adds a
quadrature node-set with no new mechanism. The single-concept, positions-vs-values model
is what guarantees that.

---

## 11. Status

**Implemented (odelia).**
- One `Replayable` concept (C++20 `requires`) replaces the `has_cache` SFINAE; the
  stepper dispatches behind `if constexpr`.
- `Interpolator<S>` (frozen knots, active values) runs on the AD path.
- The schedule replays via `advance_fixed(recorded_steps())`, read independently of
  the calibration observations.
- L3 reads the recorded field as `double` background (not an active constant).
- RelaxationSystem drives L1/L2/L3 + reuse against finite differences.
- RIF-3: the twin (tape included) is cached on the double `Solver` object; the
  recording is read per call; `has_recording()` / `recorded_steps()` expose the
  schedule; the anti-staleness reuse test is green.
- **odelia#19 §3 (calibration decouple)** — the fit data no longer lives on the
  `Solver`. The `least_squares` functional owns its observations + schedule and drives
  the solver's generic `advance_observations`; `set_target`/`advance_target`/`targets`
  are gone. The R6 wrapper's `set_observations` holds the data and passes it to each
  `value_and_gradient` call.

**Owed, tracked as their own issues.**
- **odelia#19 / plant#3** — apply the remaining settled names in the code:
  `cache_*`/`load_*` → `record_stage`/`record_step`/`replay_step`; the frozen-mode member
  `use_cached_environment` → the `has_recorded_field()` query + `ReplayMode`;
  `Independents` → `DifferentiationTargets`; `AnalyticEdge` → `SuppliedDerivative`.
- **plant#4** — the RIF-5 driver contract: one differentiated `run` (live) and one
  `run_mutant` (frozen); no `feedback` flag; the metric is the functional argument; the
  mutant reads the resident field as `double` background (RIF-6 native harvest).
- **Interpolator unification** — merge plant's `AdaptiveInterpolator` (the refiner) with
  odelia's `basic_interpolator<S>` (the fixed evaluator) into one replayable
  interpolator and retire the `basic_` name. Cross-package, RcppR6-bound; a
  naming/packaging cleanup, not a functional gap.
