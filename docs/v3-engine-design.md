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
- **`Replayable` is L3-only machinery.** All four of its hooks are already no-ops on the resident
  path (`recording = control.save_RK45_cache`, off by default), so the resident engine — the one
  that works and that we are scaling — needs none of them.
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

- **Wall clock.** Each unit's forward is re-run once on the backward pass, in active arithmetic,
  so expect rather more than 2x the forward cost. Unpriced.
- **A genuinely path-dependent background** — hysteresis, or an accumulator that is not ODE state
  — could not be rebuilt from step-start state. None exists in plant today. If one appears it
  must either become ODE state or be recorded, and then L2's recording returns.
- **Structure must stay a deterministic function of plain values.** True today and now guarded by
  the tie-break, but a new environment could break it by sorting on an active key. There is no
  structural defence against that yet — only this sentence.

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
