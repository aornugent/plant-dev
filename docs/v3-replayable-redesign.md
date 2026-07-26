# A better Replayable, co-designed with the interpolator and plant

Owner, session 22: *"Sounds like we need a better Replayable concept co-designed with the
interpolator and plant."*

This is a design, not a build. Every quantity in the ledger is measured this session; the sources
are `v3-engine-design.md` and `v3-l2-audit.md`.

## Triage: 2 — a concept is a module boundary, and two repos implement it

## Requirements ledger

| | outcome | quantity / evidence |
|---|---|---|
| **R1** | a step re-run in isolation reproduces the forward pass exactly | **met from a whole patch copy: max_abs 0.00e+00 at every probed segment, K93 and FF16.** Not met from `ode_state` alone (drifts to 1.5e-5 / 1.7e-15) |
| **R2** | *something* must survive between passes; **what, is not yet established** | restoring the spline properly through `Patch::r_set_state` changed the drift **not at all** — both K93 and FF16 read the exact field on the rate path, not the spline. So R2 is a real requirement with an **unidentified** subject. This design does not depend on it: see the note below |
| **R3** | structure is a **per-step** quantity, not per-stage | positions change as the canopy grows; values were the per-stage thing, and values are L3 |
| **R4** | a System that claims to replay must actually replay | **plant satisfies `Replayable` today and does not replay structure at all.** Nothing caught that |
| **R5** | no new interpolator surface | `get_x()` and `init(x, y)` already exist and are exactly the two operations needed |
| **R6** | L3 (recorded background values, the mutant path) is **out of scope** | owner, this session |

**Scarce resource:** not bytes — a step's node set is tens of kB over a whole run. It is
**checkable intent**: the current concept cannot tell a System that replays structure from one
that doesn't.

**What this design does and does not rest on.** It rests on **R4** — that satisfying a replay
concept should mean something, which is falsified today because plant satisfies `Replayable` while
replaying no structure. That argument stands on its own. It does **not** rest on structure being
the thing a stored `ode_state` fails to restore: four hypotheses for that have now been refuted,
including the spline. So build the concept for R4, and let the bisect say what `save_structure`
must actually save — it may need company, or a different name.

## The floor

Keep `Replayable` as it is — four members, `record_stage(int)`, `record_ode_step()`,
`replay_step(size_t)`, `has_recorded_field()` — and just make plant implement the structure half.

**The floor fails R4, and the failure is already realised.** `record_stage(int stage)` carries two
jobs: `CanopySystem` uses `stage == 0` to snapshot *positions* (a per-step job in a per-stage hook)
and every stage to record *light values*. Because one member covers both, plant implements the
value half and satisfies the concept while replaying no structure — which is how the gap survived
to this session unnoticed. Making plant implement more does not fix a concept that cannot express
the difference.

## Candidates

| | move | commitment | pays for | costs | wins when |
|---|---|---|---|---|---|
| **A** *[first thought]* | leave the concept, add to plant | one hook set covers structure and values | R2 | R4 stays broken; the per-stage cadence stays on a per-step job | the two jobs really are one |
| **B** | split by job | structure replay is its own concept; the background-value cache is the System's own business | R2, R3, R4 | one concept renamed, two members instead of four | the two jobs have different cadences and different scopes — which they do |
| **C** | make it a mode | one `replay(step)` plus a `recording` flag | R2, R3 | R4 still unexpressed: a flag is not checkable at compile time | there is only ever one job |

**Winner: B.** Eliminations: **A** is the floor and fails R4 by construction. **C** collapses the
member count but leaves R4 exactly where it is — the point is that satisfying the concept should
*mean* something, and a runtime flag cannot carry that.

## The commitment

> **Replaying a background means restoring the structure it was built on, per step. Reading back
> recorded values is a different job with a different cadence, and is not part of this concept.**

```cpp
// Per accepted step on the plain pass, save whatever the background's shape was chosen
// from; per step on a differentiated pass, rebuild the background on that saved shape at
// the working scalar. The index is handed over, so a pass may visit steps in any order --
// which a backward sweep does.
template <typename System>
concept ReplaysStructure = requires(System s, std::size_t step) {
  s.save_structure(step);
  s.load_structure(step);
};
```

**Kept true by structure:** the concept mentions no stage, so a per-stage job cannot be written
through it; and it mentions no values, so a System cannot satisfy it by caching values — which is
precisely the way plant satisfies today's concept while replaying nothing.

## What each side provides — the co-design

**odelia interpolator: no change.** `get_x()` returns the node set and `init(x, y)` builds values
on a given node set. Those are exactly `save_structure` and `load_structure`, so the concept is
already expressible against the interpolator as it stands. (`construct` stays for the plain pass,
and since this session it refines through a plain-valued predictor, so it no longer records the
coefficient solves it used to.)

**odelia solver: two call sites replace three.** `record_ode_step` and the stage-0 branch of
`record_stage` become one `save_structure(k)` on an accepted step; `replay_step(k)` becomes
`load_structure(k)`. The per-stage hook leaves the solver's cadence entirely.

**plant `ResourceSpline`: one entry point, and it replaces one.** Add `build_on(nodes, f)` —
evaluate `f` at given nodes and `init`. `rescale_spline` then *becomes* a caller of it
(`build_on(rescaled_old_nodes, f)`), so this is a refactor rather than an addition, and the
replay path stops re-refining.

**plant `Patch`: implement the two.** `save_structure(k)` stores the environment's node set for
step `k`; `load_structure(k)` calls `build_on` with it. The mutant background cache
(`record_stage`'s per-stage values, `has_recorded_field`, `set_ode_state(it, stage)`,
`environment_history`) stays exactly as it is — as plant's own methods, no longer pretending to be
the same concept.

## What this settles

- **A System either replays structure or does not satisfy the concept.** The bug class that
  actually bit — satisfying `Replayable` while replaying nothing — becomes inexpressible.
- **The per-stage cadence leaves the structure path.** `record_stage(int)` is called six times a
  step to do, for structure, work that belongs once a step.
- **Four members become two**, and the remaining two are symmetric, so there is one thing to
  understand rather than a cadence table.
- **Quadrature needs none of it.** `quadrature::QK`'s nodes are a fixed rule affinely mapped, so
  the crown integral has no adaptive structure to save. That is not a gap to fill; it is a case
  the concept correctly does not apply to.

## What this makes hard

- **It may store what could be derived, and that is not yet settled.** A background refined from
  scratch each step has a node set that *is* a function of state — proven this session,
  bit-identically. plant instead *inherits* its node set through `rescale_spline`, which makes it
  path-dependent in principle. But installing the forward node set properly changed the measured
  drift not at all, because on the rate path both K93 and FF16 read the exact field rather than the
  spline. **So whether anything about the light structure needs saving at all is open.** The
  concept's job may reduce to naming the hook and having no plant witness that needs it — in which
  case it should not be built.
- **It says nothing about how much structure.** A System could save something enormous per step
  and the concept would not object. The bound is a review matter, not a structural one.

## Kill condition

**No System needs to save anything.** If the bisect shows that what a stored `ode_state` fails to
restore has nothing to do with adaptive structure — and the spline result now points that way —
then `ReplaysStructure` has no witness and should not be built. The R4 problem (a concept that
cannot tell replaying from not replaying) would then be fixed by **deleting** the structure role
from `Replayable` outright rather than by renaming it, which is a strictly better outcome and
should be preferred if the evidence allows.

## Unverified before building

R1 is met from a whole patch copy but **not** from `ode_state`, and *what else is missing has not
been isolated* — three attributions this session were wrong (the per-node stamps, a stale first
stage twice over, and spline path-dependence as the sole cause; K93 fits no spline and still
drifts). **Bisect between the two measured regimes — whole-patch copy (exact) and
rebuilt-from-`ode_state` (drifts) — restoring one piece at a time until it goes exact, before
writing either hook.** `save_structure` may well turn out to need company.
