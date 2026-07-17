# MRI multi-rate vs global RK45 on the real TF24 patch — results

*Companion to [`tf24-multirate-forward-track.md`](./tf24-multirate-forward-track.md) and
[`tf24-multirate-implementation-plan.md`](./tf24-multirate-implementation-plan.md). Numbers from
[`scripts/tf24-multirate/bench_real_patch.R`](../scripts/tf24-multirate/bench_real_patch.R) and
`real_patch_probe.R`, run against the real `plant` TF24 patch (odelia@master + plant@develop,
including `traitecoevo/plant#554` NSC fix).*

## Setup

Seed a realistic 8-cohort stand (`make_initial_state`) under a rainfall driver, then **freeze the
cohort block** (the slow block; the demographic dynamics are a separate, now-fixed concern, #554) and
drive the 5 soil states forward 60 days. Only soil states are varied — the raw `patch$derivs`
**segfaults** if a hand-rolled integrator hands it an overshooting *cohort* state; soil-only
perturbation over the full physical range is safe.

- **Global** = one adaptive step size over the full patch RHS (soil + light-field scan + per-cohort
  hydraulics). Every soil-limited step re-runs the whole expensive RHS — what plant's solver pays.
- **MRI** = refresh the (expensive) cohort water demand at a chosen cadence; sub-cycle the 5 soil
  states cheaply in between (real TF24 drainage/infiltration; demand held between refreshes). The soil
  block is stiff + positivity-clamped, so the sub-cycle uses a local-stability-limited clamped explicit
  Euler.

## Findings

1. **The premise holds on the real patch.** Soil `∂θ̇/∂θ ≈ 343 day⁻¹` (fast timescale ~0.003 d) vs the
   daily cohort/light scale — a ~300× separation.
2. **The soil physics factors exactly.** The cheap soil-only RHS reproduces the patch soil derivative
   to **machine precision at every θ**, given the uptake (max|diff| = 0).
3. **The coupling is the crux (verdict-changing risk #1, confirmed).** Per-layer root uptake is a
   **non-separable** function of the *whole* soil-moisture profile: as the top layer dries (θ 0.21→0.05)
   its uptake *rises* (0.59→0.84) while deeper layers fall — the plant redistributes demand through the
   hydraulic solve. It **cannot be frozen**: a naive daily Lie-split gives max|dθ| ≈ 0.26–0.38.
4. **Two stiffness traps in the soil block** (both real, both must be respected by any sub-cycler):
   the positivity clamp (an adaptive high-order stage straddles it and locks a spurious wet state) and
   the drainage Jacobian at wet θ (`(2n+3)K/θ/dz ≈ 1400 day⁻¹` → fixed sub-steps go unstable). A
   local-stability-limited clamped Euler handles both.
5. **Refresh-cadence result (refreshes/day; err = max|dθ| vs global over 60 d):**

   | scenario | mm/yr | global evals (·/day) | 20/day | 50/day | 100/day | eval-cut @ track |
   |---|--:|--:|--:|--:|--:|--:|
   | drought  |  11 |  19 242 (321) | 1.9e-1 | **5.9e-4** | 4.6e-4 | **6×** (err<1e-3) |
   | semiarid | 315 | 107 490 (1792) | 2.8e-1 | 1.4e-1 | 1.2e-1 | converging |
   | wet      | 599 | 218 538 (3642) | 2.8e-1 | 1.5e-1 | 1.3e-1 | converging |

   The **driest** case tracks global to <1e-3 at 50 refreshes/day — **6× fewer expensive full-patch
   evaluations**, and the eval-cut ceiling grows with soil stiffness (global runs 321→3642 evals/day
   drought→wet). Wetter scenarios are cadence-responsive and converging but **plateau ~0.12** under
   periodic refresh.

6. **Why the plateau, and where the real win is.** Periodic refresh of the *whole* demand is a stopgap:
   the uptake responds to θ on (near) the fast soil timescale, so it must be evaluated **continuously**
   in the sub-cycle — but the expensive part it rides on, the **light-field/cohort geometry, is truly
   slow**. The win therefore requires separating the two: compute the hydraulic-uptake-given-θ cheaply
   in the sub-cycle (the leaf/collar solve — the plan's §6 aggregate surrogate), freezing only the slow
   light field. That is the scoped C++ factoring (`StateView.u()`), not a scheme change.

## Bottom line

Multi-rate is viable on the real TF24 soil block and the numerical premise is confirmed, but the
real coupling is a **fast, non-separable hydraulic response** — the naive Lie-split freeze that worked
on the surrogate does not transfer. The demonstrated path: a stiffness-aware soil sub-cycle plus a
**cheap continuous uptake surrogate** (leaf solve) with the slow light field frozen. This benchmark
turns the plan's anticipated risk #1 into a measured requirement and scopes the remaining work.
