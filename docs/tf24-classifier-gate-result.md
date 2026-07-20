# Stage-1 event classifier — gate result

*The go/no-go measurement for the event-aware stepper (spec §3, build-order #2).
Instrument: odelia per-accepted-step `step_monitor` + plant per-cohort branch
sink (`tf24_solve_diag`). Data: `classifier_capture.R` (raw per-step, saved in
`results/classifier_raw/`) → `classifier_analyze.R`. Bank at full horizon,
`ode_method="rkck"`, tol 1e-6. Every run bit-identical to monitor-off (R4).*

## Verdict: **INTRINSIC — do not build the event-location stepper.**

The 70–98 % unattributed step-collapse is **not** removable discrete events. The
hypothesized event surfaces (leaf shutdown, θ_res/θ_sat soil clamps, ψ ceiling,
runoff, collapsed argmax interval) are **never approached** and step collapse
does **not** co-locate with the events that do fire.

| scenario | yr | rej_frac | branch5 frac | min shutdown margin | rej near event |
|---|---|---|---|---|---|
| intense_storms   | 20 | 0.302 | 0.9973 | 5.60 | 4 % |
| extended_drought | 30 | 0.297 | 0.9997 | 5.51 | 2 % |
| whiplash         | 24 | 0.285 | 0.9977 | 5.57 | 3 % |
| dry_to_wet       | 25 | 0.310 | 0.9994 | 5.65 | 2 % |
| long_horizon     | 70 | 0.270 | 0.9978 | 4.66 | 2 % |

**median rejections co-located with a discrete event = 2 %.**

## Evidence

1. **The hypothesized surfaces are never approached.** Soil-clamp and runoff
   signatures never fire (`clamp_bits=0`, `runoff_on=0`) in any scenario,
   including a 30-yr extended drought. The leaf-shutdown margin
   `psi_crit − |ψ_wettest|` never falls below **4.66** (shutdown is at 0). The
   collapsed-interval branch (the argmax bound-flip degenerate case) **never
   fires**. ~99.8 % of every cohort solve takes the smooth golden-section branch
   (branch 5); the only discrete event that ever occurs (branch 1, `E_column<0`)
   fires on <0.5 % of steps.

2. **The 30 % rejection waste does not co-locate with events.** Only ~2 % of
   rejection attempts fall within ±1 step of any per-cohort branch flip or soil
   signature change. If collapse were removable events, rejections would cluster
   at them; they don't.

3. **What weakly predicts step size is continuous, not discrete.** The strongest
   (still weak) correlate of `log h` is the GSS feasible-interval width
   (Spearman ρ ≈ +0.24…+0.42) and, collinearly, soil wetness (θ_res / ψ_ceil
   ρ ≈ +0.4). These are smooth stiffness that scales with state, not a surface
   the controller crosses. The interval never collapses to a point (branch 4 = 0),
   so even the argmax narrowing stays continuous — there is no kink to step to.

## Consequence for the build (spec §4, §8; handoff Part 2)

- **Do NOT build:** dense-output event location, the Brent-on-interpolant
  locator, hot restart / FSAL invalidation, the clamp active-set, transition
  handlers (spec 4a–4e). The kill question (spec §5) is answered: the collapse
  is intrinsic, so step-to-event buys ~nothing beyond the reject fraction.
- **Keep:** forcing-kink clip (#21, shipped — independent, cost-neutral).
- **Optional, cheap:** the proximity governor (spec 4d) could still cap the
  reject fraction by capping the trial step near the mild continuous stiffness,
  but with rejections not co-located to any surface its expected win is small;
  measure before building.
- **Go to the real frontier (spec §7):** coupling-weighted (ρ·|c|) mesh
  refinement and J conditioning — where the Oracle has said the accuracy lives.
  The one cohort-layer lever the data point at is the **GSS/argmax smoothness**
  (interval width is the only consistent predictor): the TF24f tracked-control
  variant that removes the argmax could reduce the continuous stiffness — a
  model-side lever, not an event stepper.

## Stress battery (added after review — coverage the first run lacked)

To rule out a benign-coverage artifact, the gate was re-run with a whole-profile
**drydown** scenario (4 yr build + 12 yr zero rain), the **TF24f** model variant,
and a **multispecies** assembly. Findings:

- **TF24 drydown** (max dry-end stress, 45k steps): bit-identical, branch5 ≈ 1.0,
  and shutdown *still* never fires — min shutdown margin 0.79, the closest any run
  gets, but never ≤ 0. Reject fraction is actually *low* (0.063): the stand dies
  (carbon starvation) as the topsoil dries, so the run gets easier, not harder.
  Intrinsic verdict holds at the dry extreme.
- **Shutdown is nearly unreachable by construction** — even 12 yr zero rain does
  not dry the wettest layer to psi_crit (it keys on the wettest accessible layer;
  deep layers stay saturated). Full mechanistic write-up:
  `docs/tf24-soil-profile-eco.md`. This *reinforces* INTRINSIC from the model side:
  the event the stepper would locate is not merely absent, it is structurally
  hard to reach.
- **TF24f is too fragile to run the gate on**: it aborts on every hard scenario at
  the default `k_acclim=1` (the tracked-ψ control leaves the feasible leaf-solve
  domain — filed as **plant#61**). So the "delete the argmax via TF24f tracked-p"
  lever is currently unusable on hard sequences and needs the feasibility guard
  first.
- **Multispecies** not yet captured (harness birth-rate API mismatch — remaining).

## Instrument (kept as a diagnostic; bit-identical when off)

- odelia: `has_step_monitor` trait, `step_monitor_{enable,reset,get}` +
  `step_diag` storage, one record site in `SolverInternal::step`.
- plant: `Patch::step_monitor` (env margins + cohort branch digest),
  `tf24_solve_diag` per-cohort sink written in `Leaf::prepare_collar_solve`,
  `TF24_Environment::soil_event_margins`.

Re-run: `Rscript scripts/tf24-benchmarks/classifier_capture.R` then
`classifier_analyze.R`. Attribution logic can be iterated freely on the saved
raw data without re-running the (expensive, monitored) simulations.
