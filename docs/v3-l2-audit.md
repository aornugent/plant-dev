# The L2 audit: what a replayable background actually costs

The owner's question (sessions 21–22): *the light field has accreted a lot of bandaid, and
there may be no optimal replayable L2 construct.*

**Why it blocks:** the only route to production lifetime is the step-local adjoint (#35) —
peak tape = one ODE step. Landing it in plant needs a backward pass to re-record unit `k`
from stored step-start state and reproduce the forward reads bit-for-bit. L1 and L0 are
settled. L2 is the layer that must replay for that to be exact. So the question is not how
many light paths exist; it is **what a light read depends on that is not recoverable from
step-start state.**

## First, the distinction this audit initially got wrong

From `odelia/AUTODIFF.md`, and it is load-bearing:

- **L2 = adaptive node positions, recorded per step.** It **is** on the resident gradient
  path. Positions are frozen so the adaptive branching stays off the tape; the values are
  **recomputed** with the active scalar so the feedback derivative flows.
- **L3 = recorded background values, per stage.** The **mutant** gradient. Deferred.

Session 22 first read `record_stage`/`environment_history`/`save_RK45_cache` and concluded
"the resident path records nothing." That is true of **L3 only**. L2 is a separate layer, and
`ff16_environment.h` calls it *"the deferred L2 path"* — also unbuilt. Neither is recorded
today.

## The criterion that falls out

**A background needs L2 only if it has adaptive structure.** So the good replayable L2
construct is not a better recorder — it is a background with **nothing adaptive to record**,
which makes L2 *vacuous* rather than implemented.

The exact `separable_field` is that background: a frozen-rank linear operator over cohort
sources, a pure function of cohort state, no knots. The adaptively-refined `ResourceSpline`
is the opposite: its knot placement is data-dependent, so replaying it requires exactly the
position recording that is deferred.

## Grading the three environments against it

| env | rate-path light | adaptive structure on that path? | L2 |
|---|---|---|---|
| **K93** | exact field only (`field_supersedes_spline=true`; spline never fitted) | none | **vacuous — clean** |
| **FF16** | exact field; spline still refit every step but **not read** there | none *reaching the gradient* | **vacuous — clean by accident, wasteful** |
| **TF24** | fitted spline; **no field at all** (`env_has_competition_field` is false) | **yes — refit from active state every step, replay included** | **required, and deferred** |

TF24 is the exposed one, and it is the same strategy as the memory quagmire (OPEN #2). Its
adaptive branching is not off the tape and there is no recorded position set, so a replay
refits knots from a trajectory that differs at round-off from the recording pass. That its
gate-0 FD still matches means the refinement is stable enough in practice — not that the
layer is right. TF24 also therefore lacks the active query-height self-shading derivative
that the field carries.

## The recommendation: make L2 vacuous everywhere

**Give `TF24_Environment` the separable field**, as K93 and FF16 already have. This is
wiring, not research — TF24's competition is the same rank-3 Yokozawa kernel:

    k_I * area_leaf(H) * (1 - (z/H)^eta)^2
      = {1, -2 z^eta, z^{2eta}} . {amp, amp H^-eta, amp H^-2eta}

which is exactly `CanopyShape::shading_query_factors` / `shading_source_factors`. The
`env_has_competition_field` trait then picks TF24 up with no new vocabulary.

One decision settles several things: the deferred L2 positions path never has to be built;
the adaptive spline leaves every gradient rate path; TF24 gains the query-height feedback;
and the step-local adjoint's bit-determinism requirement reduces to **deterministic
reconstruction**, which is now secured (below). Two existing witnesses, so this generalises
over witnesses rather than speculating.

## The price of replacing recording with reconstruction

If L2 is vacuous because the background is rebuilt from state, the rebuild must be a
*deterministic* function of that state. One gap, now fixed (`patch.h`
`assemble_competition_field`): the source merge was `std::sort` with a strict `>` on passive
heights, so cohorts at equal height were ordered arbitrarily — and equal heights are
ordinary, since every species' boundary cohort sits at its birth height. Reordering the
merge reorders the cumulative sum and moves the field at round-off. The comparator now
breaks ties on the source index.

Honest scope: with a fixed input order this was **latent, not a live bug** — same algorithm
and same input reproduce the same permutation. It becomes live the moment anything reorders
cohorts between record and re-record, which is precisely what a step-local backward pass
does. The fix removes the class for one clause and changes no numerics.

## What this makes hard

`CanopyShape` says only the Deep (Yokozawa) profile is separable — **Box and SoftBox shading
are not, and must keep the interpolator.** So L2 becomes vacuous for the production
deep-crown model, not for every model plant can run. If anyone needs a gradient through a
Box/SoftBox stand, the deferred L2 positions path becomes required again, and that is the
kill condition for this recommendation.

## Also settled while reading the code

- **`step_light` is not a third light path.** It wraps *both* branches of
  `get_environment_at_height` — one shared read-time transform, not an alternative source.
- **The secant tangent channel was dead and is deleted** (33 lines: both
  `get_environment_slope_at_height` wrappers and `ResourceSpline::slope_at_height`). Its
  exact replacement, `CanopyShape::shading_query_slopes`, already exists.
- **The two `freeze_*` statics are live diagnostics**, one caller (the channel-isolation
  driver), set per call. Not dead — but they are mutable globals on a production class, so
  correctness rests on every entry point setting them.
