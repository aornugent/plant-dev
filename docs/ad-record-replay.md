# AD record → replay: the one adaptive-numerics primitive (ODELIA-6)

**Status:** design proposal (implementation pending).
**Scope:** `traitecoevo/odelia` — the record→replay primitive under every adaptive
construction on the AD path. Applies in plant unchanged in shape (the light spline
and the crown quadrature record the same way); the plant `QK` node-set is
out of odelia scope but must slot into the identical machinery.
**Companions:** [`ad-infrastructure-design.md`](./ad-infrastructure-design.md) §7
(replay levels); [`ad-r-interface.md`](./ad-r-interface.md) §3.3 (tape/scratch reuse);
[`ad-issues.md`](./ad-issues.md) ODELIA-6. Issues: odelia#18 (ODELIA-6), odelia#12 /
PR odelia#17 (RIF-3), odelia#19 / plant#3 (the hook rename).

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

## 2. The unifying principle: positions vs. values

The design doc's L1/L2/L3 read like a ladder. Grounded in what plant actually records
(`patch.h:151-218`), they resolve into one axis — **is the recorded thing a node
*position* or a field *value*?** — and that axis alone explains the granularity and
the two consumers.

| Recorded thing | Example | Granularity | Why |
|---|---|---|---|
| **Positions** | ODE step times; interpolator / quadrature knots | **per ODE step** | positions pin *where* the nodes go; they do not change across the 6 Cash–Karp stages of a step |
| **Values** | the frozen resident environment | **per RK stage** (6× denser) | each stage evaluates the field at a different intermediate state, so the *values* differ stage to stage |

plant's own comments name exactly this split — a *"cheaper per-step reconstruction"*
against the *"faithful-to-the-SCM"* per-stage harvest. It is not arbitrary: **you only
pay per-stage density when you record values, and you only record values when you
refuse to recompute them.**

### 2.1 L2 and L3 are not a stack — they are two consumers of the same knots

The resident and mutant gradients differ only in how they consume the recorded knot
*positions*:

| Consumer | Records | On the active pass | Cross term |
|---|---|---|---|
| **Resident / total** (live) | knot **positions**, per step | re-runs the model's own field build on the frozen knots with the active state → values recomputed, self-feedback flows | present |
| **Mutant / invasion** (frozen) | knot positions **+ values**, per stage | reads the saved values as constants → no recompute (cheap; d/d(field) = 0 by construction) | zero |

So "does the frozen path need the live path?" — **no.** They share the recording
mechanism (positions) and diverge on whether the active pass *reads frozen values* or
*recomputes on the positions*. The frozen path is heavier by nature: per-stage values
are the price of not recomputing, which is precisely the mutant UX — record one
resident, then play many cheap mutants through it. This is issue odelia#18's "the
System's choice, not an odelia-level mode," made concrete.

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

The only thing genuinely missing is a **channel for the active replay System to read
the double System's recorded nodes** — the native-harvest-by-pointer (RIF-6) expressed
generically, so the driver wires the active scratch to the immutable double System once
per call.

---

## 4. One `Replayable` concept — runtime mode, not a type split

A System does not come in resident and mutant *flavours*. There is **one** System,
called by `run` or `run_mutant`, occasionally driven in active mode to get a gradient
(plant already models this with a runtime `is_mutant_run` / `use_cached_environment`
flag). So the record/replay capability is **one concept**, and the frozen-vs-live
choice is a **runtime mode on the System**, not a second type.

```cpp
// odelia: a System opts into record/replay by providing the three hooks.
// Absent -> compiles to a zero-cost no-op (an ordinary ODE System is unaffected;
// nothing forces a System to be differentiable or replayable).
template <class S>
concept Replayable = requires(S s, int stage) {
  s.record_step();          // per ODE step   (positions; flush)
  s.record_stage(stage);    // per RK stage    (values, when the System keeps them)
  s.replay_step();          // per step on the active pass (restore / no-op if live)
};
```

The stepper calls these behind `if constexpr (Replayable<System>)` (replacing the
`has_cache` SFINAE trait, design §7.6). The System decides, per its runtime mode:

- **live (resident):** `record_step` stashes knot positions; `replay_step` is a no-op;
  the field is recomputed on the frozen knots with active state.
- **frozen (mutant):** `record_stage` additionally stashes per-stage field values;
  `replay_step` loads them so the active pass reads a constant field.

One concept spans `run`, `run_mutant`, and the active replay. Fewer types, and the
correctness-relevant choice lives in the one place — the System's mode — that a reader
already has to understand to reason about the model.

### 4.1 What odelia grows, and what it does not

**Grows (small):**
1. `Replayable` and the `if constexpr` dispatch (the concept-gated hook points).
2. The fixed-node numerics carrying an active value scalar — `Interpolator<S>` today
   (frozen `double` knots, active `S` values, via `Spline<S>`); `QK<S>` is the plant
   instance of the same shape.
3. The System→System replay channel (§3): the driver hands the active scratch a
   reference to the immutable double System's stash.

**Does not grow:** a `Recording` struct that owns knots. The schedule is `times()`
(Solver-owned); the nodes are System state (System-owned). Neither was ever welded to
`set_target`, so "the recording travels independently of the fit objective"
(odelia#18) is automatic rather than engineered.

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

**Done (ODELIA-6, odelia#18):**
- One `Replayable` concept (C++20 `requires`) replaces the `has_cache` SFINAE; the
  frozen-vs-live choice is a runtime System mode, not a type split.
- `Interpolator<S>` (frozen knots, active values) is exercised on the AD path — the
  plane is no longer dormant.
- The schedule replays via `advance_fixed(times())`, read independently of
  `set_target`; the example System's L1/L2/L3 tests are green vs finite differences.

**Then (RIF-3, odelia#12 / amend PR odelia#17):**
- Amortized scratch moves to a `Solver` member (`shared_ptr<void>`), read the recording
  per call; correct for `Replayable == true`; anti-staleness test passes.

**Sequencing.** ODELIA-6 lands the primitive (concept + `Interpolator<S>` + example +
tests) first; RIF-3 is then re-scoped **on its own branch** (`claude/rif-3-tape-cache`,
rebased onto ODELIA-6) per the one-PR-per-issue rule — the recording split is a fix to
the branch that owns RIF-3, not a new branch stacked above it. The hook rename
(odelia#19 / plant#3) is deferred and tracked separately; the new hooks should be born
with the record/replay names if the rename lands first, otherwise renamed in that pass.
