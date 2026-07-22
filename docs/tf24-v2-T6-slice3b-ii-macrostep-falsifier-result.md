# T6 Slice 3b-ii — offline macro-step falsifier: GO (arbitrage viable, 2.9×–40×)

*2026-07-22. THE decision gate for the multirate uptake arbitrage, before any engine
code. Over a weekly window with cohorts frozen, sub-cycle the 5-layer soil two ways
that differ ONLY in the root-uptake coupling channel `a`, and measure the refresh
error, the trust-monitor re-expansion rate, and the realised cohort-solve reduction.
Script `scripts/tf24-benchmarks/macrostep_falsifier.R`.*

## The test (clean isolation of the linearization error)

The soil water balance splits into `a`-independent parts (rainfall infiltration,
inter-layer drainage cascade — `analytic_partial_flow` + the rain/cascade terms of
`residual_rhs`) and the root-uptake term `−a_i/dz_i`, the ONLY place the coupling
enters. A split micro-stepper (`flow(dt/2) · residual(dt) · flow(dt/2)`, matching the
intended fast-block stepper) is run **byte-identically** two ways over a weekly window
(40 micro-steps), differing only in how `a` is obtained:

- **TRUE:** `a(u)` = stand `resource_depletion` recomputed at the current soil state
  (the O(M) cohort sum — the expensive channel we want to avoid).
- **LIN:** `a(u) ≈ a₀ + J(u − u₀)`, the Taylor refresh from the frozen-window Jacobian
  `J = assemble_duptake_jacobian()` (Slice 3b-i) — cheap.

So any divergence is **purely** the `a`-linearization error. Regime bank:
{wet 0.80·θ_sat, mid 0.50, dry 0.30} × {drought, drizzle, storm}, on a realistic
103-node frozen distribution.

## Result — the arbitrage works across all regimes

Adaptive pass = re-linearize (one cohort sum for `a₀+J`) whenever the linear model's
error would exceed `tol=1e-2`, using an **oracle** trigger (the ideal lower bound on
cohort sums; a cheap engine monitor can only match or trail it). Baseline = 40 cohort
sums/window (recompute every micro-step).

| soil | rain | 1-expansion a-err | adaptive cohort-sums | speedup | adaptive soil err |
|---|---|---|---|---|---|
| wet | drizzle/storm | 5e-4 | **1**/40 | **40×** | ≤2e-5 |
| wet | drought | 1.1e-2 | 2/40 | 20× | 4.9e-4 |
| mid | drought/drizzle | 0.08–0.18 | 3–4/40 | 10–13× | ≤5.4e-4 |
| mid | storm | 0.23 | 5/40 | 8× | 2.0e-4 |
| dry | drought | 0.31 | 5/40 | 8× | 1.7e-5 |
| dry | drizzle | 0.95 | 11/40 | 3.6× | 5.5e-4 |
| dry | storm (rewetting) | **6.5** | 14/40 | **2.9×** | 1.9e-4 |

- **Every regime keeps soil accuracy ≤5.5e-4** under the trust monitor.
- **Speedup 2.9×–40×** in cohort sums (the dominant cost). Wet is nearly free (the
  coupling barely moves); dry-rewetting is the hardest but still 2.9×.
- **The kill condition does NOT occur.** The MRI-ancestor death mode is
  `cohort-sums ≈ nmicro` (re-expand every step → collapse to global RK). Worst case
  here is 14/40 — the linear model never becomes useless enough to force that.
- Without a trust monitor (single expansion, never re-expand), dry+storm reaches 650%
  `a`-error — so the monitor is **necessary**, and it is what makes the arbitrage safe:
  it spends re-expansions exactly where the nonlinearity (dry→wet rewetting, the
  retention curve steepening across the residual floor) demands them.

## A cheap trust monitor is feasible (de-risks 3b-iii)

The oracle trigger probes true `a`; the engine cannot. But the leading linearization
error is ~C·‖δu‖², so a probe-free excursion/2nd-order trigger should reproduce the
oracle rate. Measured across the window: **corr(a_err, ‖δu‖²) med 0.985 (min 0.80)** —
the error tracks the excursion tightly. Caveat: the excursion at the tol=1e-2 trip
spans ~2 orders across regimes (5.6e-4 → 8.5e-2), so the monitor must **scale by local
sensitivity** (‖J‖ / the 2nd-order remainder), not use a raw fixed ‖δu‖ threshold.
That is the concrete trust-monitor spec for 3b-iii.

## Honest caveats / carried to Slice 4
- The 2.9×–40× is an **oracle** (ideal) cohort-sum reduction; the cheap-monitor
  realisation will trail it somewhat (headroom is large — even 14/40 is 2.9×).
- `nmicro=40` is illustrative; production uses adaptive RK45, so the absolute count
  differs — the **ratio** nmicro/cohort-sums is the reduction and is stepper-agnostic.
- Per-window soil error ≤5.5e-4 feeds the demography with ~10× amplification (T3), so
  the ~1e-2 trust tol leaves headroom under a ~1e-1 offspring budget — but **offspring
  convergence is Slice 4's acceptance test**, measured end-to-end over the scenario
  bank, not assumed here.
- Interior↔boundary per-leaf kinks (Slice 3a) sit inside the window; the trust monitor
  re-expands across them (they show up as excursion-driven error spikes).

## Verdict
**GO.** The freeze-cohorts / sub-cycle-soil / Taylor-refresh-`a` arbitrage has a viable
operating point across the full moisture × rainfall bank: 2.9×–40× fewer O(M) cohort
sums at ≤5.5e-4 soil accuracy, with a feasible cheap trust monitor. Proceed to
Slice 3b-iii (odelia macro/micro integrator, toy-first) with the trust-monitor spec
above, then Slice 4 (end-to-end offspring + wall-clock on the scenario bank).
