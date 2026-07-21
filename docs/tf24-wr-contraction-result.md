# WR contraction (ladder rung 5) — result: plain waveform relaxation is killed

*2026-07-21. Fresh Oracle's ladder, rung 5 (the architectural swing): iterate the
coupling `a(t)` to self-consistency (Picard/waveform relaxation) instead of
freezing it — the one decoupling §6c never tried. It would remove the global
max-norm and the O(M)-per-decision at once. Kill-or-fund test: measure the
Picard contraction factor κ near the resident fixed point. Script:
`scripts/tf24-benchmarks/wr_contraction.R`; probe hooks: plant `0015c9fd`.*

## The probe

The WR map is `T: a(t) → u(t) → members → a_out(t)`: hold the coupling aggregate
`a`, integrate the 5-dim soil against it, advance all members against the
resulting `(u, s)`, reassemble `a`. Its fixed point is the exact coupled
solution. Contraction near the resident fixed point `a*`:

```
kappa(delta) = || a_out(delta) - a_out(0) || / (delta * ||a*||)
```

measured on **saved fields** (no coupled resident re-solve), using the discrete
operator's own image `a_out(0)` as reference so `sweep_soil`'s absolute
discretization bias cancels. Realized with three diagnostic hooks (off by
default, bit-identical production, `test-mutant.R` green):

- `record_uptake` — logs `a = assemble_resource_depletion()` per RHS eval;
  recovers `a*` by replaying the resident against its own (bit-identical) cache.
- `sweep_soil` — integrates the environment block alone from the first cached
  soil state with `a(t)` prescribed (RK4; the system is accuracy- not
  stability-limited, so a fixed grid at the resident step scale is stable).
- `overwrite_cached_soil` — injects the swept soil into the slim replay cache
  (keeping recorded light); a subsequent `run_mutant` advances members against
  `(swept soil, resident light)`, whose recorded uptake is `a_out`.

## Result (intense_storms, 12 yr, peak 1.1 GB)

- **δ=0 round-trip sanity:** `||a_out(0) − a*|| / ||a*|| = 0.011` — the probe
  reproduces the resident aggregate to ~1%, validating `sweep_soil` + injection
  + member replay.

| δ | κ global | κ per window (6 × 2 yr) |
|---|---|---|
| 1e-3 | **9.93** | 5.37 9.85 7.42 6.94 11.76 11.33 |
| 1e-2 | **10.27** | 5.11 8.85 9.90 10.19 12.08 11.30 |

κ ≈ 10 ≫ 1, consistent across δ (linear regime) and across every 2-yr window.

## Verdict: KILL plain / windowed / damped WR

One Picard sweep **amplifies** a coupling perturbation ~10×. Windowing down to
2-yr windows does not rescue it (κ still 5–12); useful window lengths do not
contract. κ≈10 is not a probe artifact — it is the **same ~10× coupling
amplification already on record** (perturbing uptake moves the soil, and members
respond enormously near `u_min`, the measured 50–291× amplifier region, so the
reassembled uptake overshoots). The coupling that makes the problem hard is
exactly what makes Picard expansive.

Simple damping cannot save it: for an expansive positive round-trip gain `G≈10`,
the damped iteration matrix `(1−ω)I + ωG` has spectral radius `|1+9ω| > 1` for
every `ω>0`. Anderson acceleration or Newton–Krylov on the small `a(t)+s(t)`
fixed point is the only remaining route, but that abandons the "iterate to
self-consistency cheaply" simplicity that was WR's entire appeal — it is a
heavy nonlinear solve wrapped around each window, no longer obviously cheaper
than the global explicit RK it was meant to replace.

**So rung 5 is retired as posed.** The global max-norm and the O(M)-per-decision
are not removable by relaxation, because the `x↔u` coupling is too strongly
expansive to relax. The Oracle anticipated the loop-gain risk; the measurement
resolves it against WR.

## What remains on the ladder

- **Rung 2 — goal-oriented member placement + J certificate** (measure axis, the
  "main event"): executable now in pure R on `g(τ)` + the validated ghost; needs
  no new infra. This is the surviving high-value frontier.
- **Rung 3 — certified survival crossings** via ghost bisection in `τ_ins`.

The WR probe hooks stay as documented diagnostics (bit-identical off), reusable
if an accelerated fixed-point solve on `a(t)` is ever revisited.
