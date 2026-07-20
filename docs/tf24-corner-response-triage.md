# Oracle corner+decoupling response — §7 triage

*Triage of `docs/oracle-consultation-corner-and-decoupling-response.md` under
consult-guide §7: reduce every claim to the cheapest test, run it before building.
Probes: R-level leaf sub-function sweeps + `control()` knobs + `step_log`; zero
production changes. Scripts kept in scratch (leaf/solver probes); numbers below.*

## Summary

The Oracle's reframe — **the inner operating point is an active-constraint corner
(C5), not an interior optimum (C4)** — is **confirmed** and sharpened. But two of its
downstream claims are **corrected by measurement**: the `h_min` clamp is not binding
(there is *no* mid-run step collapse to audit), and the speed residual is **I-controller
over-reach**, which weakens the Oracle's own T1 (norm-artifact) and points squarely at
its T2 (better controller).

## Claim A — the corner is a branch switch (CONFIRMED, and identified)

Sweeping the inner objective across `p*` and reading the evaluator's internals
(`opt_psi_stem`, `ci`, `assim`, `hydraulic_cost`) at fixed state:

| side of p* | opt_psi_stem | ci | assim (net) | reading |
|---|---|---|---|---|
| wet (p<p*) — shelf | pinned | 4.331 | **−1.5** | fallback branch (net assim = −R_d) |
| dry (p≥p*) — live | tracks p | 5.488 (**jumps**) | ~0 → productive | productive branch |

The 1.5 drop is exactly the "fallback branch value" the Oracle predicted: on the wet
side the inner **ci / assimilation solve** returns a non-productive fallback (net
assimilation collapses to the −R_d floor); at `p*` the productive branch turns on (ci
jumps 4.33→5.49). The "argmax" is the **last point on the surviving productive branch**
— an active-constraint corner, `∂P/∂p ≈ −8.8 ≠ 0` there, no interior stationary point.
This is a **ci/assimilation feasibility edge, not a transport root-fold** — so the exact
locator's defining condition `S(p;state)=0` is "the productive ci branch ceases to
exist," not necessarily the quadratic-fold/bordered system the Oracle sketched. Same
idea (locator + IFT node), different equation; identifying it exactly is the
"one-afternoon branch-indicator log" the Oracle named.

This validates the Oracle's §1 for the **accuracy/adjoint** side: with `∂P/∂p ≠ 0` at
the operating point nothing is stationary, so any envelope-at-fixed-`p*` adjoint is
first-order wrong. (Untested here — that is E4/plant#60, still the highest-priority
correctness item; needs the reverse tape.)

## Claim C — the h_min clamp / step collapse (REFUTED and reframed)

The Oracle read the constant `h_min` as a clamp with "forced accepts = uncontrolled
error" and as the censor of E2's second row. Measured:

- **The clamp is essentially never hit.** Accepts at the floor: **1 step (0.0%)** at
  `h_min=1e-6`. Setting `h_min=1e-10` (unclamped) leaves attempts, reject fraction,
  min-h, and offspring **identical to all digits.**
- **min-h is the *initial* step, not a wall.** `min-h = 3.65e-4 d = 1e-6 yr =
  ode_step_size_initial`, and the smallest ~18 accepted steps all occur at `t/T≈0.00`.
  Raising `ode_step_size_initial` to `1e-3` raises min-h to match. There is **no
  catastrophic mid-run collapse.**
- **The accepted-step distribution is healthy:** (days) 1%ile 0.012, 25% 0.029,
  median 0.062, 75% 0.36, 99% 7.3 (extended_drought). The 0.1%-ile is 3.65e-3 d ≈
  `1e-6·T`, not `1e-8·T`.

So the long-standing "scattered min-h ~1e-8..1e-9·T collapse" was the **initial step at
t=0 misread as collapse**. (This also corrects a statement in the E1/E2 write-up that
min-h `= ode_step_size_min`; it equals `ode_step_size_initial`, and is emergent-invariant,
not clamped.) The Oracle's forced-accept audit is **moot** — there are ~0 forced accepts.

## The speed residual — I-controller over-reach (identified)

With no collapse and no floor, what is the 27–35% rejection? **Rejected attempts are
systematically ~3–4× larger than accepted steps** — the controller proposes too-large
steps, fails the error test, shrinks, accepts:

| sequence | reject frac | median(rejected h) / median(accepted h) |
|---|---|---|
| intense_storms | 0.297 | 3.11 |
| whiplash | 0.278 | 2.44 |
| dry_to_wet | 0.313 | 3.74 |
| extended_drought | 0.274 | 3.97 |

Universal across the bank. This is textbook **I-controller over-reach / limit-cycling**:
the rejections are wasted probing at *large* steps around an otherwise-healthy step
distribution — not stiffness forcing small steps.

Consequences for the Oracle's build order:
- **Supports T2** (swap the I-controller for PI/Gustafsson with sane growth caps): the
  reject fraction is a controller-tuning artifact, the cleanest available speed lever.
- **Weakens T1** (the norm's treatment of vanishing components forcing collapse): its
  premise is absent — there is no collapse, and rejections are at *large* h, not the
  small-h shrinkage a vanishing component would force. T1's norm attribution could still
  be instrumented to confirm what the estimator keys on during over-reach, but it is no
  longer the leading speed hypothesis; T2 is.
- The speed side is confirmed as **hygiene**, as the Oracle framed it — but the specific
  hygiene is controller tuning, not component atol floors.

## Status of the Oracle's claims after this triage

| claim | test | result |
|---|---|---|
| A: corner = branch switch (C5) | leaf sub-function sweep | **CONFIRMED** (ci/assim feasibility edge) |
| C-i: forced-accepts = error hole | count accepts at floor | **refuted** (~0 forced accepts) |
| C-ii: h_min censored E2 | unclamp probe | **refuted** (min-h = initial step; no collapse) |
| speed = norm artifact (T1) | rej-vs-acc h distribution | **weakened** (over-reach, not collapse) |
| speed = controller (T2) | rej/acc ratio 2.4–4.0× | **supported** (leading lever) |
| D: adjoint O(1) wrong at corner | reverse tape vs FD | **untested** (E4/plant#60; highest-priority correctness) |
| E: J-flip is one member | diff member contributions | untested (cheap; next) |
| locator flattens J(τ) | build locator, re-run J(τ) | pending (accuracy fix; after D) |

## What to build next (all still gated on cheap tests where one exists)

1. **E4 / adjoint correctness (Claim D).** The one un-run high-value test. Reverse-mode
   `dJ/dθ` vs a true FD that re-solves the inner problem, on a transpiring state — the
   corner makes the envelope-at-fixed-`p*` adjoint first-order wrong by construction.
   Test before any locator build. (task #23, branch `claude/odelia-ad-tape-reverse-*`.)
2. **T2 controller (speed).** PI/Gustafsson controller in odelia (toy-first per codesign),
   measure reject fraction on the bank. Bit-identical is not required (it changes the step
   sequence) — judge by reject fraction ↓ and J unchanged. The clearest speed win.
3. **The corner locator + IFT node (accuracy).** Identify the ci-branch-existence
   condition `S(p;state)=0` (the branch-indicator log), replace the golden-section with a
   safeguarded solve of `S=0`, present `p*` as an IFT node on `S`. Acceptance test
   (pre-tabulated): `J(τ)` flattens at 5.87e-8 for all `τ`, and the adjoint matches FD.
4. **J mollification (accuracy, model-side).** The survival-threshold discontinuity in J
   is a functional-conditioning problem no stepper touches; the exact locator pins the
   τ-flip but the θ-space discontinuity remains. This is a model-owner decision (soften
   the survival entry into J). Flag, don't build unilaterally.
