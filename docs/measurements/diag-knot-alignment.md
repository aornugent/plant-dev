# Pinning the rainfall interpolant's curvature jumps to step boundaries

TF24 SCM, one species, `lma = 0.0825`, `max_patch_lifetime = 5`, forcing
`mixed-ordinary`, optimised `-O2` build (`cd plant && make`, already current),
`TESTTHAT_PARALLEL = false`, serial inside each run and four runs at a time on
four cores. `J = sum(scm$offspring_production)`.

**No code under `plant/` or `odelia/` was changed.** Both trees are clean at
`claude/trusting-curie-4i9n3l` (`5321593a` / `be3e2cb`), so the `make test-cpp` /
plant fast-sweep guard did not apply and nothing was committed or pushed.
Everything below is scripts in the scratchpad: `ka_common.R`, `ka_probe.R`,
`ka_smoke.R`, `ka_repro.R`, `ka_align.R`, `ka_order.R`, `ka_coarse.R`,
`ka_sham.R`, `ka_near.R`, `ka_kinds.R`, `ka_frag.R`, `ka_shares.R`.

---

## The five numbers

| | |
|---|---|
| **Reproduction** | exact. Adaptive, 88 nodes, `ode_tol = 1e-4`: `J = 1.77114282e-10`. Pinned union grid, 88 nodes, 7278 times (4.22x the steps): `7.36044830e-11`. Pinned at 697 nodes: `7.34294898e-11`. Gap **+140.63%**. |
| **Active knot count** | **412** in `(0, 5)` — against **1824** daily knots in range and **1725** accepted steps. Not 3.5 knots per step: 0.24 *active* knots per accepted step, i.e. 4.2 accepted steps per active knot. |
| **Gap, before → after** | **+140.63% → -0.057%** (adaptive vs pinned, each against its own counterpart) |
| **Observed order** | **neither 2 nor 5 — there is no power law in either arm.** Unaligned the error is +65% to +140% flat across `ode_tol` 1e-2…1e-4 and then collapses to -0.45% in one half-decade. Aligned it is between -0.21% and +0.06% across the same four decades, and stays there to 1e-7. |
| **Classification** | `hydraulic-shutdown` is the branch that separates them: **0.401%** of leaf solves unaligned, **0.027%** knot-aligned, **0.008%** all-knot-aligned, and **exactly 0.000%** on both pinned grids. Concentrated in the first 1.5 years. |

## Verdict — the remedy holds, the stated mechanism does not

**Confirmed:** forcing every active knot to be a step boundary collapses the
140.6% to -0.057%, and — the part that matters — it *holds* the answer to within
0.21% across four decades of `ode_tol`, from 1e-2 (four decades coarser than
shipped, 1375 steps) down to 1e-7. Knot alignment is a real and specific fix.
Stops at the same count placed in the dry spans, where the reconstruction is
identically zero, do **not** hold it: that arm still flips by +93% at one
tolerance. Stops placed in the same rain-event stretches but a
quarter or half a day off a breakpoint do hold it, but only to 2.6-2.8% — 50x
better than leaving it alone and 13x worse than landing on the breakpoints.

**Refuted:** the mechanism offered for *why*. The claim was that Cash-Karp 5(4)
is behaving as a second-order method in event stretches at any tolerance, so the
error is an `O(h^2)` truncation error that alignment restores to `O(h^5)`. It is
not a truncation error of any order. Unaligned, the error does not decay with
tolerance at all over three decades — it sits at +65% to +140%, non-monotone —
and then falls by a factor of 300 between `ode_tol = 1e-4` and `3.16e-5`.
Aligned, it is already at its floor at `ode_tol = 1e-2` and does not improve
over five further decades. A power law fitted to either sequence is a line
through noise, and the predicted move "near 2 → 5" is not present to be seen.

What is actually happening is what `spike-fixed-grid.md` named: **a discrete
event flipping, not a truncation error growing**. One extra forced stop anywhere
in the run — a perturbation that changes nothing about the model — moves `J` over
`6.2e-11` to `1.85e-10`, a factor of three, straddling the converged answer in
both directions. The 140.6% is one draw from that spread, not a bias with an
order.

Knot alignment works because it removes the flip, not because it restores an
order. That is a different thing to fix and a different thing to test for.

---

## 1. Reproduction

All three reported numbers reproduce to every digit printed (`ka_repro.R`, and
the adaptive number independently in four later scripts):

| configuration | `J` | steps |
|---|---|---|
| adaptive, 88 nodes, `ode_tol = 1e-4` | **1.77114282e-10** | 1725 |
| adaptive, 175 / 349 / 697 nodes | 7.32716266e-11 / 7.35735559e-11 / 7.33373891e-11 | 1845 / 1999 / 2328 |
| pinned union grid (7278 times), 88 nodes | **7.36044830e-11** | 7359 |
| pinned union grid, 697 nodes | **7.34294898e-11** | 7942 |

Gap, adaptive-88 against pinned-88: **+140.63%**; against pinned-697,
**+141.19%**. The union program is the union of the four levels' accepted
programs, as in `diag-gradient-error.md`; it holds every level's introduction
times (0 missing at every level) and is 4.22x the 88-node adaptive step count.

Already visible here, and worth stating before any mechanism is proposed: the
adaptive answer is wrong **only at 88 nodes**. At 175 nodes — 7% more steps —
it is 7.327e-11, within 0.5% of the pinned answer. A second-order truncation
error does not fall by 60% for a 7% increase in step count.

## 2. The active knot set

The driver is read through `odelia::interpolator::hermite_interpolator` with
slopes from `monotone_slopes` (`odelia/inst/include/odelia/interpolator.hpp:404`),
reached from `plant` through `ExtrinsicDrivers`
(`plant/inst/include/plant/extrinsic_drivers.h`). It is C1 by construction and
C2 nowhere in general, so the premise about the reconstruction is sound.

The zero-span rule that makes the *active* set small is explicit in the source:
`monotone_slopes` pins `m[k] = m[k+1] = 0` whenever `secant[k] == 0` (the "flat
pair" branch, line 432). Two adjacent zero control values therefore give a span
that is identically zero with zero slopes at both ends, and its neighbour meets
it with no curvature jump. Working that through, **a knot carries a jump iff at
least one of `y[k-1]`, `y[k]`, `y[k+1]` is non-zero** — which is the brief's
"non-zero on at least one side", confirmed against the code rather than assumed.

Measured on the `mixed-ordinary` record (`ka_probe.R`):

| | count |
|---|---|
| daily control points over the whole record | 2191 |
| daily control points in `(0, 5)` — the run's span | **1824** |
| non-zero control values in `(0, 5)` | 203 |
| **active knots in `(0, 5)`** | **412** (22.6% of the daily grid) |
| accepted steps, adaptive 88 nodes | 1725 |

**The brief's ratio is the wrong way round.** Knots do not outnumber accepted
steps 3.5:1. The full daily grid is 1824 against 1725 accepted steps — 1.06:1 —
and the active set is 412, i.e. **0.24 active knots per accepted step, or 4.2
accepted steps per active knot**. What is true is the placement claim: the
active knots are dense exactly where the steps are small, so a fifth of the
steps meet them and four fifths never see one.

| program | steps | steps holding an active knot | active knots inside a step |
|---|---|---|---|
| adaptive, 88 nodes | 1724 | 390 (**22.6%**) | **412 of 412** |
| adaptive, 175 / 349 / 697 nodes | 1844 / 1998 / 2327 | 399 / 399 / 400 | 412 / 412 / 412 |
| pinned union grid | 7277 | 412 (5.7%) | **412 of 412** |

So **not one of the 412 active knots is a step boundary in either configuration**
before the intervention — the experiment is well posed, and the finer pinned grid
is no more aligned than the adaptive one.

## 3. Forcing the knots to be step boundaries — which mechanism, and why

**Mechanism (a), the scheduled event, is the one used.** A zero-depth rainfall
pulse at each active knot: `events(events_default(p), rainfall_pulse(time = knots,
depth = 0))`. An event is a stop time for the integrator
(`SCM::run_next` takes one leg per schedule entry, `scm.h:580`), and
`add_water_pulse_to_layer` accepts `depth == 0` and adds `min(0, capacity) = 0`
(`tf24_environment.h:819`), so this pins step boundaries and changes no state.

It was chosen because it is the only one of the two that leaves the *adaptive*
configuration adaptive. `set_ode_steps(times, numeric(0))` replaces the whole
grid — `step_to` takes one RK step to each supplied time with no error control,
subdividing only on a domain refusal
(`odelia/inst/include/odelia/ode_solver_internal.hpp:624`) — so using it on the
adaptive arm would have measured a different question. On the *pinned* arm the
events compose with the replay for free: `program_within(t0, t_end)` hands each
leg only the recorded times strictly inside it
(`plant/src/node_schedule.cpp:172`), so adding events splits the union program at
the knots without touching it.

Two checks before any of it was believed (`ka_smoke.R`):

- `events(events_default(p))` with no extra events reproduces the no-events run
  **bit-identically** (`J = 6.23127635e-07`, 466 steps, both). So the default
  path and the event path are the same run.
- 20 zero-depth pulses: all 20 land exactly on step boundaries, and `J` moves by
  `-3.6e-05` relative — the tolerance's own scale.

`set_node_schedule_times()` after construction keeps the action entries
(`clear_times` erases an instant only when its species *and* its actions are
empty, `node_schedule.cpp:133-144`), so introductions and pulses compose. Nothing
about either mechanism failed as described.

## 4. Before and after, and the controls that decide what it means

Six configurations at 88 nodes and `ode_tol = 1e-4` (`ka_align.R`):

| | `J` | steps | vs **B0** |
|---|---|---|---|
| **A0** adaptive | 1.77114282e-10 | 1725 | **+140.63%** |
| **A1** adaptive + 412 active knots | 7.36321378e-11 | 1825 | +0.038% |
| **A2** adaptive + all 1824 daily knots | 7.37027588e-11 | 2826 | +0.134% |
| **A3** adaptive + 412 stops in dry spans | 7.35264232e-11 | 1978 | -0.106% |
| **B0** pinned union grid | 7.36044830e-11 | 7359 | — |
| **B1** pinned + 412 active knots | 7.36742197e-11 | 7771 | +0.095% |

After alignment every one of the 412 knots is a step boundary in A1, A2 and B1
(0 knots left inside a step). The gap the brief asks for is each configuration
against its own counterpart — unaligned A0 against unaligned B0, aligned A1
against aligned B1: **+140.63% → -0.057%.** Every aligned or sham run in this
table agrees with every other to within 0.24%, which is why this tolerance
alone decides nothing.

At this one tolerance the sham control A3 also lands on the right answer, which
on its own would refute the whole hypothesis. It does not survive the ladder.
Relative error against the converged answer `7.3679e-11` (the `ode_tol = 1e-7`
value, reached independently by both arms to 1.3e-6), across four decades of
tolerance (`ka_coarse.R`, `ka_sham.R`, `ka_near.R`):

| `ode_tol` | 1e-2 | 3.16e-3 | 1e-3 | 3.16e-4 | 1e-4 | worst |
|---|---|---|---|---|---|---|
| unaligned | +117.7% | +64.8% | +121.1% | +132.4% | +140.4% | **+140%** |
| 412 stops, dry spans (sham) | -5.9% | **+92.6%** | -6.7% | +0.73% | -0.21% | **+93%** |
| 412 stops, +0.25 d off each knot | +2.80% | -0.14% | +0.51% | -0.17% | +0.09% | **2.8%** |
| 412 stops, +0.5 d off each knot | -2.56% | +2.00% | -0.17% | +0.47% | +0.02% | **2.6%** |
| **412 active knots** | -0.10% | -0.21% | +0.06% | -0.06% | -0.06% | **0.21%** |
| **all 1824 daily knots** | +0.03% | -0.06% | -0.06% | -0.02% | +0.03% | **0.06%** |

Read down a column and the effect separates into two parts:

1. **Where the stops go decides whether the flip survives.** 412 stops in the
   dry spans leave it (one +93% excursion, two ~6% errors). 412 stops in the same
   rain-event stretches — the *near-miss* rows, the active knots shifted by a
   quarter or half a day so they land inside a span instead of on a breakpoint —
   remove it entirely: no excursion anywhere, worst error 2.8%.
2. **Landing exactly on the breakpoints decides the size of what is left.**
   Near-miss 2.6-2.8%, on the knots 0.21%, on every daily knot 0.06%. That
   13- to 45-fold gap between "in the right stretch" and "on the breakpoint" is
   the only part of the measurement that is specific to the interpolant's C1
   structure, and it is real.

So the C1 knots do matter, and the brief's remedy is the right remedy. The
reason it works is not the reason the brief gave.

### How narrow is the failing configuration

One extra forced stop, at 16 times spread over the run, shipped tolerance,
88 nodes, nothing else changed (`ka_frag.R`):

```
0.200 6.234e-11   0.507 6.216e-11   0.813 6.939e-11   1.120 1.764e-10
1.427 6.952e-11   1.733 1.779e-10   2.040 1.776e-10   2.347 1.849e-10
2.653 1.770e-10   2.960 9.653e-11   3.267 1.761e-10   3.573 1.766e-10
3.880 1.770e-10   4.187 1.492e-10   4.493 1.770e-10   4.800 1.771e-10
```

`J` spans `6.22e-11` to `1.85e-10` — a factor of three — under a perturbation
that adds one step boundary. Five of the sixteen fall below `1e-10` and ten above
`1.5e-10`, with the converged `7.37e-11` sitting inside the spread and matched by
none of them. A single stop early in the run does not converge the answer; it
moves it to a different wrong value, 10–16% *below* the truth. Only the systematic
412- or 1824-stop alignment lands on it and stays there.

## 5. The observed order

`ode_tol` swept over seven half-decades from 1e-4 to 1e-7 at 88 nodes, and then
over five more from 1e-2 to 1e-4 once it was clear the first sweep had nothing
in it (`ka_order.R`, `ka_coarse.R`). Relative error against `7.3679e-11`:

| `ode_tol` | 1e-2 | 3.16e-3 | 1e-3 | 3.16e-4 | 1e-4 | 3.16e-5 | 1e-5 | 3.16e-6 | 1e-6 | 3.16e-7 | 1e-7 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| unaligned | +1.18 | +0.648 | +1.21 | +1.32 | +1.40 | -4.5e-3 | -9.3e-5 | -8.8e-5 | -6.6e-5 | +4.5e-5 | 0 |
| aligned | -1.0e-3 | -2.1e-3 | +6.4e-4 | -6.5e-4 | -6.4e-4 | +5.3e-4 | -1.9e-4 | -7.7e-5 | -2.5e-5 | -2.4e-5 | 0 |
| steps (unaligned) | 1168 | 1284 | 1348 | 1523 | 1725 | 2023 | 2428 | 2899 | 3594 | 4507 | 5780 |
| steps (aligned) | 1375 | 1420 | 1496 | 1632 | 1825 | 2074 | 2419 | 2896 | 3510 | 4377 | 5568 |

**There is no order to report, in either arm, and that is the finding.**

- Unaligned, the error is O(1) and non-monotone across three decades of
  tolerance, then drops by a factor of 300 between 1e-4 and 3.16e-5 and is at
  1e-4 relative by `ode_tol = 1e-5`. Fitting `err ~ tol^r` gives r = 0.52,
  -0.54, -0.08, -0.05 over the coarse windows — which is to say, nothing.
- Aligned, the error is already at ~1e-3 relative at `ode_tol = 1e-2` with 1375
  steps and improves by less than a decade over the five decades that follow.
  The window-by-window "orders" (0.64, -2.75, 1.01, -1.33, -0.75 in the step
  size) are the scatter of a converged number.

Two things follow that are worth more than the missing exponent. First, **the
aligned run at `ode_tol = 1e-2` with 1375 steps is correct to 0.1%, while the
unaligned run at `ode_tol = 1e-4` with 1725 steps is wrong by 140%** — more steps
in the wrong places is worse than fewer steps in the right places, by three
orders of magnitude. Second, once the knots are boundaries the tolerance stops
being the binding constraint at all: the grid is essentially the knot grid plus
the introductions, and the residual ~0.1% is the distance from the 88-node
quadrature to its own limit, not time-integration error.

## 6. The operating-point classification

The tally is cumulative over a run, so it was read off runs cut at half-year
intervals with the same introductions, forcing and stops, and differenced
(`run_upto` in `ka_common.R`, `ka_kinds.R`). The ladder's last rung reproduces
the uncut run's tally exactly in all four arms, so the cut is faithful.

Run totals, as a share of all leaf solves (`ka_shares.R`):

| | solves | interior | boundary-crit | boundary-root-crit | determined | **hydraulic-shutdown** |
|---|---|---|---|---|---|---|
| A0 adaptive | 2 220 774 | 86.04% | 13.52% | 0.00081% | 0.0484% | **0.4008%** |
| A3 adaptive + sham | 2 557 033 | 86.18% | 13.44% | 0.00078% | 0.0193% | **0.3603%** |
| A1 adaptive + active knots | 2 253 892 | 88.21% | 11.76% | 0.00018% | 0.0017% | **0.0268%** |
| A2 adaptive + all knots | 3 623 059 | 83.91% | 16.08% | 0 | 0.0011% | **0.0084%** |
| B0 pinned | 6 902 992 | 87.32% | 12.68% | 0 | 0 | **0** |
| B1 pinned + active knots | 7 437 051 | 87.85% | 12.15% | 0 | 0 | **0** |

**`hydraulic-shutdown` is the branch the two trajectories disagree about.** Both
pinned grids reach it exactly zero times, along with `determined` and
`boundary-root-crit`. The unaligned adaptive run reaches it 8901 times. Knot
alignment cuts that by 15x and all-knot alignment by 48x. The sham arm barely
moves it (0.360% against 0.401%) — so A3's correct `J` at `ode_tol = 1e-4` is a
coincidence of the endpoint, not a trajectory that agrees with the pinned one.
The step-attempt census says the same thing from the solver's side: domain
refusals (`rejected_thrown`) go 189 (A0) → 131 (sham) → 91 (active knots) → 6
(all knots). The pinned arms report zeros because the pinned path forms no error
estimate and counts no attempts.

**Where in the record it appears: the first 1.5 years.** Non-interior share of
solves per half-year window —

| window ending | 0.5 | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 | 4.0 | 4.5 | 5.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| A0 adaptive | **1.58%** | **1.57%** | **4.96%** | 31.5% | 4.64% | 23.5% | 8.90% | 28.0% | 10.6% | 21.2% |
| B0 pinned | **0.00%** | **0.00%** | **0.00%** | 25.7% | 11.3% | 23.6% | 11.2% | 27.4% | 9.37% | 19.3% |
| A1 adaptive + active knots | **0.19%** | **0.30%** | **0.57%** | 20.7% | 12.7% | 21.0% | 8.51% | 26.8% | 6.64% | 19.9% |
| B1 pinned + active knots | 0.00% | 0.00% | 0.00% | 24.5% | 11.0% | 23.6% | 10.5% | 25.7% | 8.98% | 18.6% |

`hydraulic-shutdown` share of solves per window, x1e4 —

| window ending | 0.5 | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 | 4.0 | 4.5 | 5.0 |
|---|---|---|---|---|---|---|---|---|---|---|
| A0 adaptive | **102.2** | 17.4 | 13.2 | 23.8 | 55.4 | 20.1 | 44.2 | 26.0 | 40.8 | 23.0 |
| A1 adaptive + active knots | 10.6 | 1.3 | 10.6 | 0.23 | 1.3 | 0.72 | 0.89 | 0 | 0.34 | 0.32 |
| B0 / B1 pinned | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

For the first three windows the pinned trajectory is on the interior branch for
**every solve**, while the unaligned adaptive one is off it for 1.6%, 1.6% and
5.0% of them, a third of its whole run's `hydraulic-shutdown` count landing in
`[0, 0.5]` alone. Knot alignment takes A1 an order of magnitude closer to the
pinned trajectory in exactly those windows. After `t = 2` the four arms agree to
within a few points, and the remaining spread there is the ordinary difference
between a 1725-step and a 7359-step grid.

So the competing explanation is not a competitor: it is the same finding seen
from the other side. **The residual gap after knot alignment is 0.06%, and the
classification that goes with the 140% is a discrete branch flip in the first
1.5 years — a cohort driven into `hydraulic-shutdown` by a step that crossed a
rain event without stopping in it.**

## 7. Is a relative change on `J ~ 1e-10` meaningful?

**As a statement about discretisation, yes.** `J` is deterministic: the adaptive
88-node value came back `1.77114282e-10` in five independent process invocations
across this session, and the two `ode_tol = 1e-7` runs — reached by two different
step sequences, one aligned and one not — agree to 1.3e-6 relative. The
converged value is `7.3679e-11` and the pinned union grid at 88 nodes sits 0.10%
below it. Nothing here is at the edge of what can be resolved.

**As a statement about anything an optimiser would do, no**, and this must be
said with the rest. `J << 1` everywhere on this fixture: the stand is ten orders
of magnitude short of self-replacing, which is `max_patch_lifetime = 5` under a
record with a 130-day dry run, not a property of the integrator. A 140% error on
a number that small changes no decision. What makes it worth fixing is that the
same step-placement failure is the one `spike-fixed-grid.md` measured at 25–89%
on `constant 3.0` where `J ~ 1e-06`, and that one does change decisions.

---

## What is missing

- **One forcing record.** Everything here is `mixed-ordinary` at 88 nodes.
  `moist-storms`, `moist-drought` and `moist-drizzle` have the same intermittency
  structure and were not run; whether 412 is the right order of magnitude for the
  active set there, and whether alignment holds the answer as flatly, is
  untested.
- **One trait point.** No `theta` sweep, so nothing here says whether the aligned
  configuration is stable enough to difference for a gradient. That is the
  obvious next measurement and it is cheap: the aligned arm is correct at
  `ode_tol = 1e-2`, so a finite-difference stencil on it costs less than one
  unaligned run.
- **Why the near-miss arm is 2.6% and the aligned arm 0.21%** is measured, not
  explained. It is the only quantity here that is specific to the C1 structure,
  and it is the one worth a mechanism.
- **No `J` seed for the adjoint.** Unchanged from `diag-gradient-error.md`; not
  touched here.
