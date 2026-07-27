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

## Landing it in plant: the event segment — SUPERSEDED FOR TF24, read this first

> **The kill condition at the end of this section HAS FIRED.** TF24 measures **18.43 steps/segment**
> against FF16's 1.87, so the segment is not a viable unit there and **the unit to build is the ODE
> step** — see [`v3-control-flow.md`](./v3-control-flow.md) and `OPEN` item 4 in
> [`HANDOFF.md`](./HANDOFF.md). The section below is still correct for K93 (1.23) and FF16 (1.87), and
> it is the cheapest *first witness* because it needs no solver surgery. Do not read it as the plan.

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

**What is unbuilt, precisely — and every piece it needs is already public.**

*Forward, through the SCM.* `refine_schedule()`, then `schedule = recorded_steps()`, then loop
`run_next()`. Per segment record three things: the patch state **entering** it (that is just
`r_patch()`'s state after the *previous* `run_next()`, so it is pre-introduction and the
introduction gets re-recorded inside the unit), the species indices `run_next()` returns, and the
segment's slice of `schedule` — derivable, because every introduction time lies on the ODE grid
(100%, measured above).

*Backward, driving the Patch directly — not the SCM.* This is the part that avoids new surface.
The SCM cannot be positioned at segment `k` (its `node_schedule` has no seek), but it does not
need to be: the unit is a Patch plus a Solver, exactly as the spike is a Toy plus a Solver. Lift
once with `scm.rebind_from<RevS>()` and take the active Patch from `get_system_ref()` as a
configuration mould; then per segment, on a fresh tape, copy the mould,
`set_ode_state(stored[k], t_k)`, `introduce_new_nodes(species[k])`, build
`odelia::ode::Solver<active_patch>`, `advance_fixed(times[k])`, seed the output adjoints, sweep
once per output row, and carry the entering-state adjoints back.

`Patch::introduce_new_nodes`, `Patch::reset`, `Patch::set_ode_state` and `Patch::ode_state` are
all public (`private:` starts at `patch.h:224`), and `set_ode_state(it, time)` re-establishes the
whole invariant itself — states, environment state, time, the finiteness check,
`compute_environment(true)` and `compute_rates()`. So restoring a unit is one call.

**A segment IS exactly re-runnable — verified on plant.**
`docs/reference/segment-rerecord-probe.{cpp,R}` re-runs single event segments and compares them
to the forward pass. Re-run from a **whole copy of the patch entering the segment**, the result is
**bit-exact — max_abs 0.00e+00 at every probed segment, on both K93 and FF16.** That is the
design's core requirement, met on the anchor rather than on a toy.

**What is not enough is `ode_state`.** Rebuilding the patch out of the stored state vector drifts
(K93 to 1.5e-5, FF16 to 1.7e-15 absolute). So a stored trajectory has to carry enough to
reconstitute the entering patch, not merely its ODE state.

**What is missing — ISOLATED.** Each node carries `pr_patch_survival_at_birth`, a plain double set
at birth, **not part of `ode_state`**, and `Node::compute_rates` divides by it:

    offspring_produced_survival_weighted_dt = ... * pr_patch_survival / pr_patch_survival_at_birth

`node.h:74` says so in as many words — *"pr_patch_survival_at_birth feeds the fecundity rate"* —
next to a parenthetical about the loaded ODE state. A reconstruction that introduces its cohorts at
t = 0 gives every one of them `pr_patch_survival_at_birth = 1`, so every cohort's fecundity rate is
wrong by `1 / pr_survival(t_birth)`. That is exactly the measured signature: **zero at segment 0**
(one cohort, born at t = 0, correct) growing with segment index as more cohorts carry the error.

**Verified by a discriminating prediction, not by reading alone.** If this stamp is the cause the
error can only appear in the one state its rate feeds. The probe reports which component of a node
carries the maximum error: **`offspring_produced_survival_weighted`, in every probed segment of both
K93 and FF16, exclusively** — never height, mortality, fecundity, heartwood or log-density. That is
the signature and nothing else produces it.

**Everything a unit needs, then:** the ODE state, the per-species cohort counts, and per node
`pr_patch_survival_at_birth`. For an R0 functional also `node_introduction_time` and
`patch_density_at_birth`. **All are deterministic doubles recoverable from the schedule** — the
birth time is the schedule entry and the rest follow from the disturbance regime — so no derivative
is needed and nothing is lost. **plant already has the surface:** `Species::set_state(..., const
std::vector<double>& pr_patch_survival)` and `Parameters::initial_pr_patch_survival` exist for
exactly this.

**And it has nothing to do with adaptive structure.** So the structure role in `Replayable` has no
witness from this, and should be **deleted** rather than renamed — the outcome
`v3-replayable-redesign.md` flags as strictly better.

**How this was found, and the four wrong turns before it.** Recorded because the method matters
more than the answer:
- *The per-node stamps.* **Right in substance, refuted for the wrong reason.** `patch_density_at_birth`
  really does feed only `weighted_fecundity` (a reduction) and `node_introduction_time` really is
  inert for the rates — both checked correctly. The conclusion "stamps cannot affect the ODE state"
  was then drawn without finding the **third** stamp, which is the one that does.
- *A stale first stage (first-same-as-last).* **Refuted twice.** Invalidating `dydt_in` on a width
  change changed nothing, because `set_state_from_system` already does
  `system.ode_rates(dydt_in.begin()); dydt_in_is_clean = true`. The one-line "fix" was inert and was
  dropped.
- *Spline path-dependence.* **Refuted.** The node comparison behind it was malformed (forward
  *entering* vs rebuilt *leaving*), and restoring the spline properly through
  `Patch::r_set_state` changed the drift not at all — on the rate path both K93 and FF16 read the
  exact field, not the spline.
- *A lagged aux slot.* **Real, but not this.** `compute_environment` does run before `compute_rates`
  inside `set_ode_state`, and the competition source weight is read from an aux slot the latter
  writes — so the field at a stage is built from the previous stage's aux. Settling twice confirms
  the lag is load-bearing for **FF16** (it makes the match *worse*, 1e-35 -> 1e-14, because the
  forward pass uses the lagged value) and is irrelevant for **K93**. It is a genuine property of the
  model worth knowing; it is not the drift.

**The lesson, stated for the next session:** four hypotheses were tested and refuted before the
answer came from *reading the consumer of a quantity* rather than guessing at causes. When two
regimes are measured and stable — whole-patch copy exact, reconstruction drifting — diff the two
objects member by member instead of proposing mechanisms.

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


---

## How the leaf-soil coupling changes the space, and the primitive for all three

Owner, session 22: *"I'm open to new ideas, but they must extend to TF24 too. How does leaf-soil
coupling change the viable solution space? Is there a general primitive for all three strategies?"*

**There is, and it is already built.** All three strategies shade with the *same* rank-3 Yokozawa
kernel. TF24's is `k_I * area_leaf(H) * (1 - (z/H)^eta)^2`, which expands to

    {1, -2 z^eta, z^{2eta}} . {amp, amp H^-eta, amp H^-2eta}

— exactly `CanopyShape::shading_query_factors` / `shading_source_factors`, which is what
`separable_field` consumes. So `separable_field` + `CanopyShape` is the general construct, and the
`env_has_competition_field` trait already routes a System to it.

**The one difference TF24 makes is what a source weight *is*.** For K93 and FF16 the weight is a
closed form in the cohort's state. For TF24 it is `area_leaf`, an output of the leaf solve — and
`implicit_value` already covers that. **So the primitive for all three is the composition of two
existing primitives, with no new vocabulary.** That is the answer to the question as asked.

The coupling changes the space in two further ways, and **neither needs a new primitive**:

**1. TF24's environment carries ODE state, and that is a simplification, not a complication.** Soil
water sits in `y` (`ode_size() > 0`, against `== 0` for FF16 and K93), so the reverse sweep carries
`d/d(theta)` automatically — no recording, no freezing decision, no replay layer. Treating soil as a
background instead would be strictly worse: it would drop the depletion feedback that makes a
water-limited model mean anything. The workflows that legitimately hold soil fixed are the mutant
ones, which is the existing deferred layer. **Soil needs no new concept at all.**

**2. The source weight is read from a LAGGED aux slot — measured, and load-bearing.** Inside
`set_ode_state`, `compute_environment()` runs *before* `compute_rates()`, and the competition source
weight is read from an aux slot that `compute_rates` writes. So the field at RK stage *s* is built
from aux written at stage *s-1*: **the environment is not a pure function of `y`.** Settling a
restored patch a second time (which refreshes aux) makes the match with the forward pass
**markedly worse** for FF16 — 1e-35 -> 1e-14 at segment 20, 2e-22 -> 1e-6 at segment 80 — because the
forward pass genuinely uses the lagged value. For K93 it changes nothing.

This is a property of the model worth knowing rather than a defect to fix, but it constrains any
re-record: **a unit that rebuilds its environment from current state alone is not reproducing what
the forward pass read.** FF16 happened to match to 1e-22 with a single settle; whether that is
structural or luck is untested, and for TF24 — where the aux is a *leaf solve* output rather than a
closed form — it is the thing to check first.

### What a unit must therefore carry, for all three

| | why | recoverable? |
|---|---|---|
| the ODE state | the integrand | stored |
| per-species cohort counts | the width | derivable from the introduction schedule |
| `pr_patch_survival_at_birth` per node | **divides the fecundity rate** — the measured cause of every drift | `survival_weighting->pr_survival(t_birth)`, deterministic |
| `node_introduction_time`, `patch_density_at_birth` | only `weighted_fecundity`, so **only for an R0 functional** | deterministic from the schedule |
| the aux entering the unit | the environment reads it one stage stale (above) | **open — check on TF24 first** |

Everything but the last row is a deterministic double recoverable from the schedule, needing no
derivative, which matches the owner's steer that patch density is deterministic and disturbance
gradients are out of scope. **plant already has the setter:** `Species::set_birth_state(times,
patch_density, pr_patch_survival)`, reached through `Parameters::initial_*`.

**And none of it is adaptive structure.** So `ReplaysStructure` still has no witness, and the
structure role in `Replayable` should be **deleted** rather than renamed.
