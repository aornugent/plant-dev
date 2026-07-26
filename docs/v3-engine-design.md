# The reverse-mode engine for plant systems

Written session 22, against the owner's assessment: *"the design is for odelia first. If we get
that right, the plant DX is painless. We're not there yet. All our primitives are adding new
surface but without making anything easier. We're not closer to TF24 gradients."*

That assessment was tested rather than assumed, and it held — see **What was actually wrong**
at the end. This document is what replaces it.

---

## Requirements ledger

| | outcome | quantity |
|---|---|---|
| **R1** | exact trait/parameter gradients of the SCM's emergent outputs | census 3-vector + R0/offspring; FD-verified at gate-0 on 7 TF24 channels |
| **R2** | at production lifetime | FF16 `life=105.32`, TF24 `life>=4`. Measured today: TF24 **3.22 GB at life=1**, 5.80 GB at 2.5, kernel OOM above. **Needs >=130x at life=1, more as lifetime grows** |
| **R3** | concept count a plant developer can hold | plant touches **34** odelia names; odelia declares ~160 functions over 23 headers |
| **R4** | FD-verifiable | frozen resolved schedule, delta in the tau^(1/3) window |
| **R5** | a new strategy or environment needs no new engine vocabulary | zero new names per model |

**Scarce resource:** tape bytes in one reverse sweep. Measured at **47-56 kB per cohort-step**,
times steps, times cohorts. Every other component is <=2% of that.

## The floor

What already exists: run `advance_adaptive` once to fix the schedule, replay it with
`advance_fixed` at an active scalar, reduce through a functional, take one reverse sweep.

It meets R1, R4 and R5. **It fails R2 by ~130x.** That gap is the whole design problem.

## Candidates

| | move | commitment | pays for | costs | wins when |
|---|---|---|---|---|---|
| **A** *[first thought]* | make the recording leaner | every hot block records fewer ops | part of R2 | new boundaries, hand-enumerated input lists | the gap is a small constant |
| **B** | trade time for memory | store every k-th state, recompute forward between checkpoints | R2, generically | a checkpoint-schedule concept; recompute factor >1 | the step grid is not already known |
| **C** | shrink the unit of recording | the sweep is taken one ODE step at a time | R2 in full | one stored plain-valued trajectory | the step grid is already known — which it is |

**Winner: C.** Eliminations:

- **A is dead on measurement, and this session added four more data points in its family:**
  crown boundary A **1.49x**, boundary D **3.7x**, the query-factor `pow` hoist **1.24x**, and a
  genuine 5.89x win on the interpolator that moved TF24's total by **0.018%**. Against a
  required 130x, component leanness is not a route. It is worth having; it is not the answer.
- **B loses to C on both axes that matter here.** C's recompute factor is exactly 1 (each unit's
  forward is re-run once); B's is greater. And B needs a checkpoint schedule, while C's unit
  boundary *already exists* as `recorded_steps()` — so B pays a new concept for a worse constant.

## The commitment

> **The reverse sweep is taken one ODE step at a time over a stored plain-valued trajectory,
> and every discrete structure is rebuilt from plain values rather than recorded.**

**Kept true by structure, not convention:**
- The only thing stored per step is the plain-valued state. There is no container for recorded
  structure, so "record the structure" is not expressible.
- `basic_interpolator::construct` refines through a plain-valued predictor, so refining an
  adaptive structure *on tape* is no longer expressible either.

## Kill question

*Which single assumption, if false, makes this unnecessary?* That peak tape is what binds — if
XAD could not release and reuse a tape per unit, "peak" would be fiction and only total
allocation would matter.

**Verdict: survives, by measurement.** The spike holds peak at **3 792 B flat** for nstep
10/20/40/80 while the whole-run tape grows 53 300 -> 419 540 B, with a fresh tape per unit.

## Consistency pass

C requires a re-recorded unit to reproduce the forward reads bit for bit. Two hazards were
open at the start of this session; both are now closed:

- **Adaptive structure reproduction — proven free.** An adaptive node set built under an active
  scalar is **bit-identical** to the plain-valued one with nothing recorded: 149 nodes, 149
  matched, `max_abs_diff` exactly 0. The refiner already decides on `to_passive` values and
  positions are already `double` by type.
- **The field's source ordering — fixed.** `std::sort` on strictly-descending heights left
  equal-height cohorts in an arbitrary order; the comparator now breaks ties on the source
  index, so the cumulative sum adds the same terms in the same order on every rebuild.

## What survives deletion

Each name below is held there by a ledger line. Everything else went.

| name | held by |
|---|---|
| `Solver` (`advance_adaptive`, `advance_fixed`) | R1, R4 — the schedule is discovered once and replayed exactly |
| the `System` contract | R5 — a model expresses itself without engine vocabulary |
| a `Functional` | R1 — the reduction is what the gradient is *of* |
| `implicit_value` | R1 — a solve inside the rates, bounded per call (~1.6k ops, independent of iterations) |
| the stored plain-valued trajectory | R2 — **549 kB at TF24 life=1** against the 3.22 GB it replaces |
| one rule: structure on plain values, values at the active scalar | R2, R3 — deletes L2 as a layer |

**Deleted or never to be built:**
- **L2 as a layer.** No `positions_history`, no `replay_structure(k)`, no L2 role for
  `record_stage`. Structure is derived; AGENTS.md's "no storing what can be derived" settles it,
  and the probe proves it is derivable.
- **L2's *role* in `record_stage`.** Nobody needs to implement a hook to stash node positions.
  `Replayable` itself is **not** a deletion target — it is opt-in through `if constexpr`, so a
  System without the hooks never has them called and the branch compiles away. It costs zero
  concepts when unused. What is true is narrower: on plant's **resident** path all four hooks are
  already no-ops (`recording = control.save_RK45_cache`, off by default;
  `has_recorded_field()` false on an empty history), so the concept serves the mutant/L3 path
  only — and that path is out of scope. Do not grow it for the resident engine; do not delete it
  either.
- **Four primitives whose only caller was their own demo:** `preaccumulate`,
  `supplied_derivative`, `branch_log`/`decide` (whose `diagnostic()` duplicated `util`'s), and a
  `directional_derivative` header parallel to the live one in `gradient.hpp`. **697 lines.**
- **The secant tangent channel** (33 lines), which three design docs had already prescribed
  deleting in favour of the field's exact `dA/dz`.

## The engine, entire

Five things a plant developer must hold:

1. **`Solver`** — `advance_adaptive` discovers the schedule; `advance_fixed` replays it.
2. **The `System` contract** — `derivs`/`ode_state`/`ode_size`/`ode_rates`, `rebind_from`,
   `ad_parameters`/`ad_initial_state`.
3. **A `Functional`** — a pure reduction of the replayed run to scalars.
4. **`implicit_value`** — the one implicit-function primitive, for any solve inside the rates.
5. **One rule** — build discrete structure on plain values; evaluate values at the active scalar.

Nothing else is part of the gradient story. Three replay "axes" collapse to one recorded thing:
the step.

## What this makes hard

- **Wall clock: a flat 4.2x, measured.** 4.15 / 4.37 / 4.30 / 4.15 / 4.19 against the whole-run
  reverse pass at 60 / 120 / 240 / 480 / 960 units, while the memory ratio over the same range
  grows 27.7x -> 438x. So the trade is **a constant factor in time for a memory saving that grows
  with the run** — which is the right shape, since time is what we have and memory is what we do
  not. At ~22 us per unit the cost is dominated by building a tape per unit, and that turns out
  not to be removable:
  - **Reusing one tape, rewound between units, is a trap — refuted by measurement.** It keeps the
    gradient exact (1.8e-15) but rewinding to a marked position does **not release** the tape, so
    peak memory grows with the run (48 kB -> 742 kB over 60 -> 960 units) against a flat 6 560 B
    for a fresh tape. Its time advantage also reverses as the tape grows — 1.48x at 60 units,
    8.42x at 960 — because each unit now clears derivatives over an ever-larger array. **A fresh
    tape per unit is the design, not an unoptimised first draft.** Guarded by a test.
- **A genuinely path-dependent background** — hysteresis, or an accumulator that is not ODE state
  — could not be rebuilt from step-start state. None exists in plant today. If one appears it
  must either become ODE state or be recorded, and then L2's recording returns.
- **Structure must stay a deterministic function of plain values.** True today and now guarded by
  the tie-break, but a new environment could break it by sorting on an active key. There is no
  structural defence against that yet — only this sentence.

## The interface, and why it needs no new names

The spike deliberately kept its backward loop in the example file so the seam could still move.
With L2 deleted, several output rows working, and a fresh tape per unit proven correct, the
loop's requirements are fully known — and they are all satisfied by members that already exist:

    for k = last unit .. 0:
      tape                                    # fresh, per unit
      register the stored entering state and the seeded parameters
      sys.set_ode_state(stored[k], t_k)       # exists -- the pre-change state
      sys.replay_step(k)                      # exists -- apply step k's structural change
      solver.set_state_from_system()           # exists
      solver.advance_fixed({t_k, t_k+1})       # exists
      seed the output adjoints from lambda; sweep once per output row
      lambda <- the entering-state adjoints; accumulate the parameter adjoints

**`replay_step(k)` is the only hook, and it is already there and already indexed** (landed
session 21). Its documented job — *restore the record for step k* — widens by one word: the
structural change recorded for step k is part of that record, and it must run **on tape** so a
stand-dependent newborn carries its adjoint. That is a contract clarification, not a new member.

So `replay_structure(k)`, `unit_count()` and `set_trajectory()` — all three floated in earlier
drafts — are **not needed**. The order matters and is the one thing to get right: restore the
pre-change state, *then* apply the change, so the change is inside the unit. Applying it between
units loses the newborn's adjoint silently (19% error, right sign), which a constant-IC toy
cannot detect.

## Landing it in plant: the unit is the event segment, and that needs no new surface

`SCM::run_next()` already does exactly one unit's worth of work — consume the events at `t0`,
`introduce_new_nodes`, then `advance_fixed(e.times)` over that event's slice of the recorded
grid. So plant's natural unit is the **event segment**, not the ODE step. Measured, on the
schedules plant actually uses:

| | ODE steps | introductions | steps/segment | L0 on L1 |
|---|---|---|---|---|
| K93, default | 173 | 141 | **1.23** | 141/141 |
| K93, refined | 285 | 233 | **1.22** | 233/233 |
| FF16, default | 264 | 141 | **1.87** | 141/141 |
| FF16, refined | 277 | 161 | **1.72** | 161/161 |

A segment holds 1.2-1.9 steps, so segment granularity gives a peak within **1.9x** of ideal
step granularity — nothing against a memory ratio of 130-438x. And every introduction time lies
on the ODE grid (100%, all four rows), so a segment boundary is always a step boundary.

**This partially rehabilitates the retracted event-segment unit** (`v3-step-local-adjoint.md`
§3b). Its *reasoning* was still wrong — the ratio is a property of a schedule policy, not of the
model — but its *conclusion* is right for the schedules in use, and it is the version that needs
no solver surgery. The step remains the ideal unit; the segment is the affordable one.

**So the kill condition for the segment is a number, not an argument:** if a schedule policy
pushes steps/segment high — the multirate finding, a coarse uniform grid refined at
introductions, would — peak tape rises with it and the unit must become the step. That is the
one change that requires reaching inside `SCM::run_next_impl` to split `advance_fixed(e.times)`
into its individual steps. Until then, don't.

**What is unbuilt, precisely.** Two pieces, both inside `scm_gradient.h`, both using SCM's
existing public surface:
1. a plain pass that stores, per segment, the patch state **entering** the segment
   (pre-introduction, so the introduction is re-recorded inside the unit); and
2. a backward loop over segments: fresh tape, register the stored state and the seeded targets,
   restore, introduce, `advance_fixed(e.times)`, seed the output adjoints, sweep once per output
   row, carry the entering-state adjoints back.

## Kill condition

A background whose structure is not derivable from step-start plain values. That hands off to
candidate **B** (checkpointing) plus the L2 recording this design deletes.

## What was actually wrong

The owner's assessment was right on both counts, and specifically:

- **"Primitives adding surface without making anything easier"** — measured. Four of odelia's
  primitives had **no consumer but their own demo**. A fifth (`decide`) duplicated a function
  `util` already provides. A sixth pair (`basic_interpolator`/`Interpolator`) is two names for
  one type, kept "so plant compiles unchanged". That is 697 lines and four names of pure
  surface, now gone.
- **"Not closer to TF24 gradients"** — also right, and this is the sharper half. Sessions of
  component optimisation (crown preaccumulation, boundary D, the `pow` hoist, the interpolator)
  produced 1.24x-5.89x on their components and **0.018%-1.8% on TF24's total.** The reason is now
  measured rather than argued: TF24's tape is **flat per cohort-step**, so it is node *count*
  times run length, and only bounding the run touches it.

The engine was not short a primitive. It was short a **unit of recording** — and it carried four
primitives too many while looking for one.
