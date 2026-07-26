# The stress-bank crashes are plant#550 (cohort-density blow-up), not a drainage overflow

> **CORRECTED 2026-07-26 by [`tf24-v2-T6-mass-chart-vs-550-result.md`](tf24-v2-T6-mass-chart-vs-550-result.md).**
> §1 below classifies the crashes as mode (1) from the *message* they abort with. Instrumented, the
> cohort density never diverges on `whiplash` (max `log_density` ≈ 0) or `long_horizon` (≈ −27) — a soil
> layer leaves its physical range first and the inter-layer cascade amplifies it, which is mode (2)
> arriving through the mode-(1) message. `whiplash` also completes at `ode_tol = 1e-6`. The refutation of
> rung #5 (the exact drainage recession) rests on the mode-(1) reading and should be treated as open;
> §§2–5 (Slice 1 rescuing `extended_drought`, the 1400× reference disagreement, the reclassification of
> the bank) are unaffected.

*2026-07-22. Oracle ladder rung #5 was "retrofit the exact drainage recession into the global
adaptive RK so it stops going non-finite on the 3 crashing stress traces, giving a second-family
reference." The premise was falsified before any code was written, and the investigation instead
produced (a) a correction to our own Slice 4 claim and (b) new evidence on an upstream issue closed
as not-planned.*

## 1. The Oracle's mechanism is refuted

The Oracle diagnosed the crashes as *"embedded-pair false negative striding into the `u^16`
ceiling"* — a **soil-drainage overflow** the exact recession would delete. plant distinguishes the
two failure modes by message (`patch.h:755-812`, issue #550):

| mode | mechanism | message |
|---|---|---|
| **(1)** cohort **density** → +Inf, poisoning the competition integral | `d(log ρ)/dt = −d(g)/d(h) − mortality` spikes | **"Detected non-finite contribution"** (`species.h:241`) |
| **(2)** **soil water** state non-finite (the `u^16` channel) | RK stage arithmetic on drainage | "Non-finite environment state" / "non-finite psi_soil" |

**All three crashes report mode (1).** None reports mode (2). Confirmed independently by the
upstream issue's own diagnostics: *"The offending node's DENSITY has become +Inf"*, with individual
physiology healthy (finite height ~8–10 m, leaf area) and **all soil moisture finite across layers**.
The recession acts only on mode (2). **Rung #5 as specified was not built** — it would have been a
solver fix for a non-solver failure. No new names, no risk to the bit-identical invariant.

## 2. The upstream history (this is not the first encounter)

- **plant#550** *"[TF24 hydraulics] SCM cohort-density blow-up under extreme seasonal drought"* —
  our exact failure. Reprex: mean rainfall 0.5, **amplitude 0.4** (0.1–0.9 oscillation), TF24,
  5 soil depths, `max_patch_lifetime` 20–70 yr. Same regime as our bank and our amp≥0.6 crosscheck.
- **plant#552** (which closed #550) is a **guard only**, and says so:
  > *"This does **not** make the affected runs complete — trustworthy completion is blocked on the
  > model."*

  It added `Patch::check_finite_ode_state()` to convert the opaque downstream crash into the
  actionable message, and **deferred the root causes to #517 and #551.**
- **plant#551** *"Check growth-rate / opt_psi_stem continuity in height (root cause of SCM density
  blow-up #550)"* — the mechanism:
  > *"Because net production (hence height growth `g`) inherits that jump, the finite-differenced
  > `dg/dh` explodes and the SCM density characteristic drives density to overflow."*

  The hydraulic optimiser's `opt_psi_stem` **jumps discontinuously in height** under drought.
  **Status: closed as *not planned*** — never fixed.
- **plant#517 → NSC storage (`TF24@v3`)** *was* done; NEWS calls it *"the root-cause fix for the SCM
  cohort-density blow-up (#550)"* (reserve-gated growth + mortality bounded in
  `[a_dG1·e^−a_dG2, a_dG1]`).

**Verified: our build is `TF24@v3` with the `storage` state active** (`model_version("TF24") == 3`;
individual ODE names include `storage`). So **we ran *with* the root-cause fix and still crashed** —
the NSC buffering reduced but did not eliminate the blow-up at the bank's extremity, and #551's
discontinuity remains unfixed.

Also relevant: the in-code comment states *"Smaller ODE steps do not help (the divergence is in the
equations, not the stepper)"* — consistent with #552's "blocked on the model."

## 3. New result: T6 Slice 1 rescues one crashing trace (evidence on a not-planned issue)

#551's unfixed root cause is a **discontinuous hydraulic operating point in height**. T6 **Slice 1
(`newton_collar_solve`)** replaces the derivative-free bracketing argmax with a safeguarded
root-find on the exact optimality condition `dprofit_droot_collar_psi == 0` — a direct attack on that
discontinuity. It had never been pointed at the crashing traces.

| trace | `newton_collar_solve=FALSE` | `newton_collar_solve=TRUE` |
|---|---|---|
| whiplash | crash | crash (reaches divergence earlier) |
| **extended_drought** | crash | **5.64986e-10 — completes** |
| long_horizon | crash | crash (reaches divergence earlier) |

**Slice 1 rescues 1 of 3.** This is genuine evidence for #551's mechanism (closed as not planned):
removing the operating-point discontinuity *does* prevent the blow-up on `extended_drought`. It is
not the whole story — two traces still diverge, and reach divergence sooner in simulated time, so
either an additional cause operates there or the divergence is genuinely in the equations.

## 4. The correction this forces on Slice 4

`extended_drought` is now the one crashing trace with an obtainable reference, so it is the first
real test of our "mri_uptake out-survives the reference" claim. Apples-to-apples (same collar solver):

| run | offspring |
|---|---|
| rkck, `newton=TRUE` **[reference]** | **5.64986e-10** |
| mri_uptake, `newton=TRUE` (matched) | 4.05814e-13 |
| mri_uptake, `newton=FALSE` (as run in the bank) | 4.04492e-13 |

**mri_uptake is ~1400× below the reference** (rel err 0.9993). The collar solver moves mri_uptake by
only 0.3%, so the discrepancy is **mri_uptake itself**, not the confound.

**Therefore: completing a trace the reference cannot is NOT a robustness win, and the Slice 4
write-up has been corrected.** Both numbers sit deep in the near-extinction hypersensitive regime
(1e-10 vs 1e-13, hard-won lesson #4) on a trace the model is *documented to diverge on*, so the
honest reading is that **neither value is trustworthy there** — not that mri_uptake is superior.
What survives is the narrower, true statement: mri_uptake does not trip the density guard, but it
also does not deliver a usable offspring number on the stress traces.

**What is unaffected** (all in well-conditioned regimes, and independently referenced): the certified
escape from the frozen-coupling refutation; static 5e-3; survivable-dynamic (amp=0.3) 1.8e-4;
constant-rainfall gate 2.3e-3; the 3–10× cohort-solve reduction; the trust monitor's death-mode
absence (0.11–0.53 re-expansions/leg).

## 5. Consequences for the ladder

- **Rung #5 (recession retrofit) is cancelled** — refuted premise. The Oracle's §4 advice, including
  its two-tier validation framing, was built on that mechanism and should be revisited.
- **A second-family reference is not obtainable by a solver change** on these traces; where a
  reference *is* obtainable (`extended_drought` + Slice 1), it disagrees with mri_uptake by 1400×.
- **The stress bank should be reclassified**: it measures *cost* and *monitor behaviour* (both still
  valid, and valuable), not accuracy. Accuracy lives in the survivable regimes, as Slice 4 already
  concluded — this investigation strengthens that conclusion and removes the one claim that exceeded
  it.
- **Worth reporting upstream:** Slice 1 completing `extended_drought` is concrete evidence for #551,
  which was closed as not planned. It also suggests `newton_collar_solve` is worth more than the
  1.20×-cost accuracy tweak it was filed as.
