# Measurements

Diagnostic runs behind the consultation in `docs/`. Each note states its own
fixture and caveats; this says what it established and whether that survived.

The notes are records of what was measured and are left as written, so a few
cite consultation drafts that have since been removed. Those citations are
stale; this table is the current reading.

**Read this first.** Every note except `diag-long-drought.md` and
`diag-long-horizon-remeasure.md` was measured at `max_patch_lifetime = 5`, where
the objective is 1e-7 to 1e-11 and the stand is effectively extinct. The same
trait at `max_patch_lifetime = 40` gives `J = 43`. The near-extinction was the
horizon, not the trait, and relative errors quoted against 1e-10 are
discretisation statements rather than anything an optimiser would act on.
`diag-long-horizon-remeasure.md` carries nine of those conclusions to
`max_patch_lifetime = 40` and says which survive; the status column below is its
verdict where it has one.

| note | established | status |
|---|---|---|
| `diag-error-norm.md` | the environment block sets 69–84% of steps; removing every member component from the error norm changes the step count under 1% | holds |
| `diag-rejections.md` | 19–28% of step attempts rejected, 17–27% of rate evaluations wasted; every domain throw is one per-member state | holds; at lifetime 40 the same census reads 15.2% / 28.6% rejected and 8.4% / 24.4% wasted on a smooth and an intermittent record, the smooth arm's rejections now mostly domain throws |
| `spike-fixed-grid.md` | a captured grid holds a ±2× parameter box at safety factor 2; zero transfer across forcing records; the failure is step placement | box and placement hold at lifetime 5; **untested at lifetime 40** |
| `diag-schedule-refinement.md` | `schedule_eps = 2e-2` never fires on a benign record; the 57% tolerance response is time integration, not the schedule | holds |
| `diag-quadrature-order.md` | the reported error is a cancellation of two `O(Δb²)` terms, ratio stable to three digits; a spline on the output alone makes the answer 2.4× worse; a ladder without spacing doublings improves every term | **overturned at lifetime 40**: under the same smooth record the two terms have the same sign (−0.334% and −0.086% at 108 cohorts), the total exceeds either, and a higher-order output rule is 1.26× *better*. Its mixed-forcing attribution of 16–31% to the cohort grid was the time grid, see `diag-gradient-error.md` |
| `diag-wrong-sign.md` | a sign-wrong gradient is a near-cancellation of two paths at condition number ~100, with `err(total) = 100·err(direct) + 101·err(swept)` exact at six levels | **the cancellation is the horizon**: `\|direct\|/\|total\|` reads 10.3 / 3.7 / 0.6 / **0.2** at lifetimes 5 / 10 / 20 / 40 and the two paths share a sign by lifetime 20. The amplification identity and the note's own "do not choose lifetime 5 for a `rho` study" hold |
| `diag-gradient-error.md` | gradient orders of 1.8 with no switching and 1.34 with 14%; the 16–31% is the time grid, not the cohort grid | the time-grid attribution holds; **the orders were measured on unaligned grids and are contaminated** |
| `diag-knot-alignment.md` | forcing steps onto the record's 412 active breakpoints collapses a 140% gap to −0.057%; sham and near-miss controls separate placement from breakpoint structure; not order reduction | **half confirmed at lifetime 40.** The sham control is sharper there (9264 steps in the dry spans, 37.9% low, against 8683 aligned steps at +0.3%). The near-miss is not: half a day off holds to 0.32% against the knots' 0.31%, so the 13-fold breakpoint gap is a short-record property. One extra stop moves `J` by 1.44×, not 3×, and never reaches the converged value |
| `diag-jump-vs-floor.md` | neither an inner-tolerance floor nor a first-order jump term; `J` is a step function in θ at 0.1% rms with 0.3–0.4% steps where the branch census reorganises | **overturned at lifetime 40**: 0.031% rms, lag-1 acf 0.09, branch census moving ≤0.099 points between adjacent traits; the one 0.44% departure in 25 points is time integration and goes at `ode_tol = 1e-4` |
| `diag-long-drought.md` | at `lifetime 40` with genuine drought, hydraulic shutdown falls to 0.002% and is a birth transient, not drought; unaligned error is −35% to −40% and does not wash out with refinement | holds, and independently reproduced to every digit (`J = 12.0526222` at 9931 steps, `J = 12.0779933` at `ode_tol = 1e-5`); a genuinely arid site is untested, and the note says why |
| `diag-gradient-aligned.md` | a finite-difference plateau needs `ode_tol = 1e-6`; the adjoint shows gradients converging at the value's rate; a pinned program gives exactly zero shutdown over 28M solves | **the plateau claim is overturned at lifetime 40**: one exists at `ode_tol = 1e-3`, 3.5 decades wide, flat to 4.6%. Its order ladders are untested there. **Conflicts with `diag-jump-vs-floor.md` on the half-order loss**, see below |
| `diag-long-horizon-remeasure.md` | nine short-fixture conclusions re-run at `lifetime 40`: M1 and M11 overturn, M5 and M6 reverse, M2 half survives, M7–M10 untested | current |

## The half-order loss

`diag-gradient-error.md` measured gradient orders of 1.34 against a value's
1.87. `diag-gradient-aligned.md` reports the gap surviving across three arms;
`diag-jump-vs-floor.md` reports it absent on aligned grids in both coordinates.

The arms differ in instrument. `diag-gradient-aligned.md` §1 establishes that no
finite-difference plateau exists at `ode_tol = 1e-4`, and its §2/§3 ladders are
at `1e-4`; its own caveat records the gradient's per-window orders as 1.08/2.06
and 1.76/1.17, averaging to the quoted figures.
`diag-jump-vs-floor.md` established that `J` is a step function in θ, that the
finite-difference signal at `d = 1e-3` is 0.29% against 0.1% scatter, and used a
five-point least-squares cubic instead.

The arm without a difference quotient — the adjoint, `diag-gradient-aligned.md`
§4 — shows gradients converging at 1.29–1.91 against values at 1.31–1.94.

All three arms are at `max_patch_lifetime = 5`, and the premise one of them rests
on does not carry: at lifetime 40 a difference plateau exists at `ode_tol = 1e-3`
and runs three and a half decades (`diag-long-horizon-remeasure.md` §6). Nothing
settles the half-order loss at that horizon, because no order ladder has been run
there — and §7 of that note says a ladder would have to run upward from 108
cohorts, where lifetime 5 ran downward from 88.

## Two coordinates, two stands

`diag-gradient-aligned.md` §6: the same aligned grid at the same 88 nodes gives
`J = 7.363e-11` in the height coordinate and `2.089e-08` in birth date, 284×
apart, while the censuses differ by 13–19%. Cross-coordinate comparisons
elsewhere in these notes — including a claim that birth date is 4× more accurate
on the quadrature — compare different stands.
