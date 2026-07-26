# Correction: every offspring-accuracy number was measured against an under-converged reference

*2026-07-25/26. While running the order test (Oracle ladder rung #4) we discovered that the
"converged reference" used throughout Slice 4 and the gate was converged in only ONE of plant's two
tolerance families. This document records the error, the corrected measurements, and what changes.*

## 1. The error

plant's `Control` carries two independent tolerance families:

| family | keys | default | what it converges |
|---|---|---|---|
| inner-solve | `GSS_tol_abs`, `ci_abs_tol` | — | per-member physiology + the competition integral, at a fixed state |
| **outer ODE** | `ode_tol_rel`, `ode_tol_abs` | **1e-4** | the **time integration** of the coupled system |

Every accuracy harness this session used `ctrl$GSS_tol_abs <- 1e-12; ctrl$ci_abs_tol <- 1e-12` and
called the result "the converged reference". **`ode_tol` was left at its 1e-4 default**, so the
reference carried ~4e-3 of its own time-integration error — larger than the quantity being measured.

Measured (survivable dynamic regime, mean=1, amp=0.3, life=40, birth=20):

| reference `ode_tol` | J | cost |
|---|---|---|
| **1e-4** (what we used) | **35.1148736** | 112 s |
| 1e-5 | **35.2448663** | 508 s |
| 1e-6 | (>2900 s, timed out) | — |
| — | *mri_uptake's own converged limit ≈ **35.24*** | — |

**The reference was the outlier. The scheme under test was right.** Tightening one decade moves the
reference 3.7e-3, onto mri_uptake's answer.

**Why it hid for a whole session:** the error made our scheme look *worse* than it was, so no
"too good to be true" instinct fired. **An error that flatters your reference is as dangerous as one
that flatters your method.** Recorded as hard-won lesson #7.

**Why it was easy to make:** `mri_uptake` reports `yerr = 0` (always accept), so `ode_tol` does *not*
control it — its accuracy is set by `ode_step_size_max` / `mri_uptake_tol` / `nmicro`. Tightening
"the tolerance" therefore moves the **reference only**, and a shared under-converged reference
silently mis-scores every method that ignores it.

**Structural fix:** `scripts/tf24-benchmarks/converged_control.R` provides
`converged_control(ode_tol, inner_tol)` and `mri_uptake_control(days, ...)`. No script hand-rolls the
tolerance block any more.

## 2. Corrected accuracy (survivable dynamic regime, amp=0.3, reference `ode_tol=1e-5`)

| H (days) | J | rel err | coupling evals | vs rkck (16581 RHS) |
|---|---|---|---|---|
| 14 | 32.271183 | 8.4e-2 | 2278 | 7.3× fewer |
| **7 (operating point)** | 35.1211782 | **3.5e-3** | 4358 | **3.8× fewer** |
| 3.5 | 35.1491457 | 2.7e-3 | 8518 | 1.9× fewer |
| 1.75 | 35.2429297 | 5.5e-5 † | 16868 | ~1.0× (none) |

† **Not resolvable.** The reference's own residual is ~4e-4 relative (≈0.014 absolute), *larger* than
the 0.0019 discrepancy measured. Honest statement: at H=1.75 d, mri_uptake agrees with the reference
**to within the reference's uncertainty (≤4e-4)** — possibly much better, we cannot tell without a
1e-6 reference we could not afford.

### What this changes
- **The weekly-leg error is 3.5e-3, not the 1.8e-4 previously reported.** The old figure was
  flattered twice: by the under-converged reference, and by a **sign crossing** (the coarse-leg error
  is negative — J=32.27 at 14 d — and passes through zero near the weekly leg).
- **Refining H *does* pay.** An earlier interim claim in this session that "refining H below 7 days is
  counterproductive" was an artifact of the bad reference and is **withdrawn**: 7 d → 1.75 d improves
  accuracy ≥8× for 3.9× the cohort solves.
- **The cohort-solve advantage disappears exactly where the accuracy gets good.** At H=1.75 d the
  coupling count (16868) essentially equals rkck's RHS count (16581). In this regime the honest value
  proposition is **3.8× fewer cohort solves at 3.5e-3**; below ~1e-3 the arbitrage buys nothing.
- **Stop quoting a single reduction factor.** It is strongly regime-dependent: 40× on the
  constant-rainfall gate, 3.8× here at the same operating leg, 3–10× on the stress bank.

## 3. The order test cannot be done this way (rung #4 blocked, replacement named)

Reference-free successive differences `|J(H) − J(H/2)|` should shrink by a constant factor `2^p`.
Measured: **2.85e+00, 2.80e-02, 9.38e-02** → ratios **101.9, 0.30** — non-monotone, and one below 1.

**The scheme is not in an asymptotic regime over H ∈ [1.75, 14] days.** There is a **~2.7e-3 relative
jitter floor** in J with respect to H: a *deterministic* but non-smooth dependence, most plausibly leg
boundaries aligning differently with the member-introduction schedule and the forcing, plus the
adaptive ramp from `ode_step_size_initial`. (The fit-vs-reference slope of 3.21 is not evidence of
third order; it is a line through four points dominated by that floor.)

No reference quality fixes this — the floor is in the scheme's H-dependence, not the reference.

**Consequence:** the 2-vs-3-member-sweep question (does `mri_heun` hold the accuracy at 2 sweeps/leg
instead of `mri_kutta3`'s 3, saving a third of the per-leg floor?) **cannot be settled by an H-sweep.**
Replacement experiment, now the recommended rung #4: a **direct A/B at the fixed operating leg** —
rebuild with `mri_heun`, compare J and cohort-solve count against `kutta3`. That measures what we
actually ship rather than an asymptotic rate we never operate in.

## 4. What is NOT affected

None of these used the rkck reference, so all stand unchanged:
- the **certified escape** from the frozen-coupling refutation (`refresh_sweep.R`: the affine and
  true-coupling trajectories use the *same* split, so the splitting error is common-mode);
- the **3b-ii offline falsifier** (soil trajectory ≤5.5e-4; byte-identical A/B differing only in the
  coupling channel);
- the **toy record→replay adjoint** (<1e-6 vs FD) and the odelia in-package tests (25/25);
- all **cohort-solve counts** and the **trust-monitor re-expansion rates** (death mode absent,
  0.11–0.53/leg) — these are counters, not accuracy claims;
- the **qualitative kutta3 decision**: forward-Euler's 12% error at amp=0.3 is ~30× the reference's
  own ~4e-4, far too large to be reference error, so the swap stands. Only the *magnitude* of the
  kutta3 improvement was overstated.

## 5. Still to re-measure

- `mri_uptake_gate.R` (constant rainfall, 30 yr): re-running with a converged reference; its
  published 9.8e-3 (forward-Euler) / 2.3e-3 (kutta3) are upper bounds on disagreement, not
  measurements of mri_uptake's error.
- `slice4_crosscheck.R` (the amp = 0, 0.3, 0.6, 0.9 table): every `rel` column was measured against a
  1e-4 reference. The amp=0.3 row is corrected above (3.5e-3, not 1.8e-4); the others need re-running.
- `slice4_scenario_bank.R`: the stress-bank rows are unaffected as *cost/monitor* measurements, which
  is all they are now claimed to be (see the #550 investigation), but any offspring comparison in them
  inherits the same caveat.
