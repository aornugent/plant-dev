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

## Can the workflow make the field faster? Measured: essentially no

The adaptive → fixed → replay workflow suggests two levers. Both were studied before
building, and the arithmetic killed a third.

**Direct summation instead of any cache — dead on arithmetic, no measurement needed.**
`separable_field` is not a cache justified by op count; it is an asymptotic restructuring.
Per RK stage the field costs `O(n·R)` assembly plus `O(R)` per read, so `~3n + 3nq`, against
`n²q` for evaluating competition directly at every read. At n ≈ 200 that is ~67× more work.
Step-local repricing does not rescue it: the gap is a factor of n, not a constant.

**Hoisting the query-factor `pow` out of the crown integral — measured 1.24×, not worth it.**
On an active scalar `pow_eta` is *always* the general `pow(u, eta)` (the integer multiply
chains are double-only, since they would drop the eta derivative), so every quadrature node
pays a full active `pow`. A node sits at `z_j = u_j * h` with `u_j` fixed by the rule, and the
source factors already compute `h^eta` during assembly, so `z_j^eta = u_j^eta * h^eta` can pay
that `pow` once per cohort instead of once per node. Implemented as the `field_hoist` variant
of `docs/reference/crown-preaccum-probe.cpp` and measured:

| | bytes | factor |
|---|---|---|
| field reads, as they are | 8 376 | — |
| field reads, `z^eta` factorised | 5 888 | **1.42× leaner** |
| whole crown, consequently | 12 764 → 10 276 | **1.24×** |

All channels agree to round-off (`value` and `d_src0` bit-identical, `d_h` and `d_src_mid`
1.3e-16, `d_eta` 1.1e-14), so the factorisation is correct. **The prediction that motivated it
was wrong:** the per-node `pow` is ~30% of the field read, not its dominant term — the rank-3
dot product, the `exp` and the read machinery carry the rest. 1.24× is in boundary A's family
(1.49×), far under the ≥8× §6e says is needed, and it costs bit-identity with develop plus an
overload to pass a precomputed `z^eta`. **Do not build it.**

**The one lever still worth having is about correctness, not speed.** `separable_field.hpp`
says it needs "no recorded positions", and that is true only because it takes the source
ordering *from the caller* — the structure lives in `patch.h`'s sort and `n_sources_at_least`.
So the field's L2 is **the source permutation and the per-query rank cutoffs**, both pure
functions of double heights. Recording them on the adaptive pass removes the per-stage
`O(n log n)` sort and the `n·q` binary searches from the replay pass, and freezes the branching
so a re-recorded unit is bit-identical **by construction** rather than by the tie-break comparator.
Step-local is what makes it affordable: only one step's ranks are ever live. Unmeasured.

**What this settles about the owner's doubt.** The field is not accreted bandaid *on the read
path* — 1.24× is all that a real restructuring buys, which is the same story boundary D told
(67 partials for a scalar output is that shape's information floor). What is accreted is the
field's **coexistence with the spline**, not the field itself. So the target is the second
construct, not the first.

## TF24: why the clean IFT did not finish the job

The expectation was one implicit-function lift around the leaf solve, and done. **The IFT is
clean and it works** — `weibull_leaf` measured the solve-off-tape node at ~1.6k ops per solve,
*exactly* independent of solver iterations, against ~26× for a naive on-tape solve that also
returns a wrong zero gradient. Nothing about the inversion is the problem.

Two structural facts explain the rest.

**1. The IFT bounds cost per call; nothing bounds the call count.** `assemble_leaf_from`
carries 2–3 `implicit_value` nodes (p\*, ci, psi_stem) and they live *inside* `ode_rates`, so
they are instantiated `cohorts × stages × nodes` times per step — order 3 600 residual
recordings at 200 cohorts and 6 stages — and each residual sums the resistance network over
soil layers. "One IFT and done" would hold if the solve happened once per step. Memory was
never the IFT's job, and no improvement to the inversion touches it. Only bounding the *run*
does, which is the step-local adjoint.

**2. TF24's environment carries ODE state, and FF16's does not.** `FF16_Environment` is a pure
background (`ode_size() == 0`); `TF24_Environment` holds soil water as ODE state and computes
its own rates from the depletion the leaves caused. So one object plays two roles with two
different replay requirements — soil state is **L1**, solver-owned; the light spline is **L2**,
System-owned — and the leaf node sits wedged between them, reading light and driving soil.
That is the coupling, and it is why the leaf could not be reasoned about as one isolated
inversion.

**Consequence for the L2 decision, and it is the useful part:** TF24's memory problem is node
*count* × run length. **L2 is not on that critical path at all.** So the L2 choice should be
made on correctness and change-size grounds alone — which favours **keeping TF24 on the spline
and building the missing L2 positions recording in odelia**, rather than restructuring TF24's
model onto the field. The spline route touches the engine, where the primitive is genuinely
missing; the field route touches the science, and buys no memory it does not already have.
Fewer changes to reverse-mode-critical model code is the tie-breaker, and nothing measured
here outweighs it.

Unmeasured, and the confirming arithmetic for OPEN #2: node count per step × recorded residual
body, via `PLANT_TAPE_STATS=1` with soil layers varied. Confirm before acting.

## Does the soil ODE state need differentiating? Yes — and it is already free

Soil water is **not a background**. `Environment::ode_size()` returns `vars.state_size` and
`Patch::ode_state` splices `environment.ode_state(it)` into the state vector, so soil water is
part of `y`. Consequences:

- **The soil derivative flows automatically.** Being state, it is carried by the reverse sweep
  with no recording, no freezing decision, and no L2/L3 involvement. Its replay is L1, settled.
- **Replaying soil "as any other competitive field" would be strictly worse.** It would demote
  soil from state (exact, free) to background (frozen or recorded, feedback dropped) — the same
  trap as populating L3 on light.
- **The feedback is the mechanism, not a refinement.** A trait that transpires harder draws the
  soil down, which feeds back on uptake. Freeze theta and the gradient claims more transpiration
  buys carbon with no drying cost — systematically wrong for the trait-selection workflows this
  exists to serve.
- **The workflows that legitimately hold soil fixed are the mutant ones**, where a rare invader
  does not move the resident's soil, so it reads the recorded resident soil. That is L3, mutant,
  deferred. So **soil needs no new concept**: state for residents, L3 for mutants, exactly as
  light already is.

**The real hazard is differentiability, not replay.** The soil rates carry three hard selects,
and `smooth_positive` appears three times in `ff16_strategy.h` and **zero** times in
`tf24_environment.h` — the same class of clamp that was smoothed for FF16's growth/fecundity
path. Ranked by whether a physical trajectory crosses them:

1. **The saturation-excess runoff floor**, `(runoff_factor > 0) ? runoff_factor : 0`. A physical
   regime boundary, crossed whenever the soil wets to saturation, so it is a genuine kink **on**
   the trajectory and a trait that shifts uptake shifts where it is crossed. **This is the one
   that matters.**
2. `theta <= soil_moist_residual && rate < 0`, and `(theta > 0) ? theta : 0` guarding `pow`.
   Both guard nonphysical excursions an intermediate RK stage can probe, so they bite **off**
   the physical manifold and are probably harmless — an assumption to test, not to assume.

Unmeasured: whether a TF24 run actually crosses the runoff floor at production rainfall, and
whether the gradient is one-sided there. That is the check to run before smoothing anything.
