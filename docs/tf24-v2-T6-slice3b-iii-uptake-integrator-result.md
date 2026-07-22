# T6 Slice 3b-iii — odelia macro/micro uptake integrator (toy-first): PASS

*2026-07-22. The first odelia engine build of the T6 track. 3b-ii proved the
freeze-cohorts / sub-cycle-soil / Taylor-refresh-`a` arbitrage is viable offline
(2.9×–40× fewer cohort sums at ≤5.5e-4 soil accuracy). 3b-iii builds the engine
that realises it and proves the capability on a toy with a known `true_a`, per the
codesign rule (engine capability validated on a cheap toy before the real patch).*

## What was built (minimal seam over the existing MRI machinery)

The decisive design fact: for plant `coupling_size()==0`, so MRI-GARK's linear-
aggregate slow-signal channel (`aggregate`/`a_poly`) is **already inert** —
`mri_macro_step` already reduces to *freeze-slow → sub-cycle-fast → advance-slow*,
with the fast block reading its coupling from the frozen per-leg context, not from
`a_poly`. So 3b-iii is **not** a new macro-stepper; it is **one new inner sub-cycle**
that refreshes the coupling affinely and re-snapshots under a trust monitor,
recording where — reusing `mri_macro_step` + `freeze_slow` + `MRISchedule` wholesale.

Engine additions (`odelia/inst/include/odelia/mri.hpp`):
- **`subcycle_uptake`** — the inner. Captures the affine coupling model
  `a ≈ a₀ + J·(u − anchor)` at leg start (one expensive `true_a` + `J`), then runs
  fixed `nmicro` forward-Euler fast micro-steps reading that frozen model
  (`fast_rates_frozen`); a trust monitor re-captures only when it trips. Record pass
  (double) logs the trip micro-step indices into `MRISchedule.reexpansions`; replay
  pass re-captures at exactly those indices → the reverse pass is a straight-line
  tape (no branch on an AD value), gated by the same `if constexpr (is_same<S,double>)`
  guard `subcycle_fast` already uses.
- **`UptakeSubcycle{tol, nmicro, oracle}`** — the functor slotting `subcycle_uptake`
  into the existing `AdaptiveSubcycle`/`SplitSubcycle` seam; ignores `a_poly`.
- **`MRISchedule.reexpansions`** — the recorded re-expansion indices (parallel to
  `subcycles`); **`mri_coupling_evals`** — the scarce-resource count (1 mandatory
  capture per leg + one per re-expansion).

Toy (`odelia/inst/include/examples/uptake_system.hpp`, `UptakeSystem<T>`): L fast
layers drained by a nonlinear coupled uptake sink `a_l(u) = a_scale·Σ_k B[l][k]·u_k²`
(the toy stand-in for the O(M) cohort sum — real curvature so the affine model
genuinely degrades away from the anchor) plus a gentle refill; M slow modes tracking
the layer mean (the frozen "cohort" block). `a` enters only the uptake term, mirroring
the soil fact. Hooks: `refresh_anchor` (capture `a₀,J,anchor`), `fast_rates_frozen`
(affine `a`), `trust_excursion` (cheap probe-free monitor), `true_a`/`trust_true_error`
(exact coupling, for the reference and the oracle count).

R surface (`odelia/src/mri_interface.cpp`): `uptake_mri` (macro run + coupling-eval
count + baseline), `uptake_reference` (adaptive full-resolve), `uptake_gradient`
(record→replay adjoint vs frozen-schedule FD).

## THE monitor lesson (a real finding, mid-build)

**First attempt over-triggered 12× vs the oracle** (128 re-captures vs 11). The bug
was conceptual and is exactly the 3b-ii spec's warning: the trust monitor first used
`‖J‖·‖δu‖` — a **first-order** quantity (how much `a` *changes*) — as the trigger.
But the linearization *error* is **second-order** (`~C·‖δu‖²`, the curvature the
linear model misses). Because `a` genuinely moves a lot over a leg (that is *why* we
track it), the first-order excursion is large even when the affine model is excellent
→ constant over-triggering, collapsing the reduction to 1.8×.

**Fix (the 3b-ii spec made concrete):** the cheap monitor returns the **squared
relative excursion** `e² = (‖predicted_a − a₀‖ / ‖a₀‖)²` — a probe-free estimate of
the 2nd-order remainder. The leading error scales as `e²` up to an O(1) relative-
curvature factor, so one `tol` serves across regimes with no `true_a` probe. It is
conservative by that O(1) factor (cheap count ≥ oracle), which is the **safe**
direction. This is the concrete production trust-monitor form for the real patch,
which has `a₀` and `J` (Slice 3b-i) but not the Hessian.

## Gate result — PASS on all four criteria

Toy: L=5 fast, M=6 slow, 7 weekly legs, nmicro=40 (baseline 280 coupling evals),
tol=1e-2. Cheap = the probe-free `e²` monitor; oracle = trigger on the true a-error
(ideal lower bound); truth = re-capture every micro-step (isolates the refresh error).

| a_scale | cheap evals | oracle evals | cheap/oracle | baseline/cheap | acc(cheap vs truth) |
|---|---|---|---|---|---|
| 0.5 | 17 | 11 | **1.55×** | 16.5× | 4.6e-4 |
| 1.0 | 22 | 15 | **1.47×** | 12.7× | 5.0e-4 |
| 2.0 | 29 | 19 | **1.53×** | 9.7× | 4.9e-4 |

1. **Accuracy** — the affine-refresh macro run matches the full-resolve macro run to
   **~5e-4**, right at the 3b-ii per-leg soil-accuracy operating point (≤5.5e-4).
2. **Reduction** — **9.7–16.5×** fewer expensive-coupling evaluations than
   one-per-micro-step; the MRI-ancestor death mode (re-capture ≈ every step) does
   **not** occur.
3. **Oracle tracking** — the cheap probe-free monitor is within **~1.5×** of the
   ideal oracle count (conservative, the safe direction), confirming the 3b-ii
   excursion↔error correlation (0.985) realises in the engine.
4. **Reverse mode** — record→replay adjoint dJ/d[a_scale, initial state] matches a
   frozen-schedule central FD to **<1e-6**, and is independent of the FD step
   (adjoint moves <1e-11 as eps 1e-5→1e-7): the discrete gradient of the scheme as
   run is exact, through the re-expansion schedule, for free.

The tol knob is monotone and safe (a_scale=2.0): tol 5e-2 → 1e-2 → 1e-3 → 1e-4 gives
14 → 29 → 76 → 180 evals at accuracy 3.1e-3 → 4.9e-4 → 4.1e-5 → 1.7e-6 — spend more
captures for more accuracy, exactly the Slice-4 accuracy/speed trade lever.

All existing odelia toy tests (two-rate, drainage, lorenz, leaf, drivers, euler,
rodas, spline) stay green — the new hooks are SFINAE/opt-in and the new inner is only
instantiated for `UptakeSubcycle` (bit-identical to the untouched paths).

## Verdict

**PASS.** The engine realises the 3b-ii arbitrage on the toy: affine coupling refresh
+ a probe-free 2nd-order trust monitor (within ~1.5× of oracle) + exact record→replay
reverse mode, at a 9.7–16.5× coupling-eval reduction and ≤5e-4 accuracy. The
production monitor form is settled (squared relative excursion `e²`). NEXT: wire the
real patch (Slice 3b-iii step 2) — a `fast_rates` variant reading a frozen-per-leg
snapshot of `a₀ = assemble_resource_depletion()` and `J = assemble_duptake_jacobian()`
(Slice 3b-i), `ode_method="mri_uptake"` gated OFF (production bit-identical), re-using
`r_residual_rhs`/`analytic_partial_flow` for the soil rate — then the 3b-iii real-patch
gate and Slice 4 (end-to-end offspring + wall-clock on the scenario bank).
