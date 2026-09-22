# Handover

Where the solver investigation stands, what a next session must not re-derive
wrongly, and what is worth doing next. Measurements are in `docs/measurements/`;
its README marks which conclusions survived.

## Start here

**Run a horizon that supports a stand — or start from one.** Two routes, and
either will do.

*Long horizon.* `max_patch_lifetime = 40`; the package's own tests cluster there
and the TF24 default is 105.32. At 5 the objective is 1e-7 to 1e-11 and the
stand is effectively extinct. The same trait gives `J = 43` at 40, and
`lma = 0.32` gives `J = 5.25` — five times self-replacing, with the default birth
rate making `J` the net reproduction ratio directly. Extinction sits between
`lma` 0.45 and 0.60. Almost every measurement in this workspace was taken at
lifetime 5, and several of its conclusions are properties of that horizon.

*Stable initial structure.* `make_initial_state()` in `plant/R/scm_support.R`
seeds a patch from heights and log-densities, and `SCM::run_next` integrates
from `parameters.initial_time` to the first scheduled introduction, so a run can
begin from a developed stand. This is the better route where it works: it
removes the early transient entirely, and **48 of the default schedule's 88 legs
exist only to resolve that transient, spanning 0.43% of the horizon between
them**. It also puts the objective near 1, which fixes the conditioning scaling
for free.

Two things to fix before relying on it. `make_initial_state` writes a zero matrix
and fills only the height and log-density rows, so every other per-member state —
including the storage pool — starts at exactly zero; and it stamps every seeded
member with birth date 0, which collapses the quadrature abscissa the whole
measure is integrated over. A stable-structure seed needs both filled from the
structure being seeded.

**Align the time grid to the forcing record.** Force a step boundary at every
knot where rainfall is nonzero on at least one side — `events(events_default(p),
rainfall_pulse(time = knots, depth = 0))`; a zero-depth pulse forces a stop and
adds no water. At lifetime 40 an unaligned run is 35–40% wrong and does not
converge out of it with refinement; aligned, `J` holds to 0.29% across four
decades of tolerance and is right at `ode_tol = 1e-3`. `events(events_default(p))`
alone reproduces a no-events run bit-identically, so the mechanism is free.

**Finite differences need a five-point cubic.** `J` is a step function in `θ` at
0.1% rms with 0.3–0.4% steps. A two-point stencil at `d = 1e-3` puts the signal
(0.29%) inside the scatter (0.1%); at 349 nodes `d = 1e-3` and `3e-4` disagree
by 2.5×. Use a least-squares cubic through five trait points at ±0.01 and ±0.03,
or use the adjoint.

## What not to re-derive

| claim | correction |
|---|---|
| the gradient loses half an order where cohorts sit on constrained branches | measured on unaligned grids; the adjoint shows gradients converging at the value's rate |
| the storage boundary is attracting and cohorts arrive at it | strictly inflowing — `ż\|_{z=0} > 0`. Every domain throw is an explicit step overshooting a stable fixed point at positive storage |
| hydraulic shutdown is a real branch the model visits | artefact of step placement. Aligned + tolerance + a pinned program takes it to exactly zero over 28M solves, including under multi-year drought |
| the quadrature is the dominant error and a spline is the free win | the reported error is a cancellation of two `O(Δb²)` terms; a spline on the output alone makes the answer 2.4× worse |
| multirate is on the frontier | it collapses into a linearly-implicit split, because the expensive coupling is a function of the fast variable |
| the cohort-count error is 16–31% under intermittent forcing | that was the time grid. With it pinned, the cohort error is 0.24% |

## Latent bugs

Ordered by the chance of someone hitting one.

**A `DomainError` from inside a reverse sweep propagates uncaught.** The sweep
re-derives `k₁` at each step's own start state and rebuilds stage states from
re-derived rates, so it evaluates the rate function at states the forward pass
never visited. `SCM::census_trait_gradient` catches only `AdjointRangeError`.
The throw site is the per-member storage guard, which fires routinely on a
stressed stand — so the user path is "sweep a stand under drought".

**`refine_schedule` can exit inconsistent, silently.** The loop bisects *after*
its run, so exhausting `schedule_nsteps` installs a schedule that was never run:
`parameters.node_schedule_times` then describes one grid and
`parameters.ode_times` another, with nothing saying so. The convergence `break`
precedes the bisection, so only the exhaustion path is affected.

**An unsorted schedule stamps replayed cohorts with wrong birth dates.**
`SCM::r_set_node_schedule_times` stores the caller's raw vector while the
`NodeSchedule` sorts it, and `reshape_to` indexes that parameter vector
positionally. Nothing raises. The other two setters write
`node_schedule.get_times()` and are safe.

**`run_scm(..., events = ...)` is always the times-only replay form.**
`make_node_schedule` passes `{}` for sizes unconditionally, so supplying
`p$ode_step_sizes` alongside events silently has no effect. The two forms behave
differently: times goes through `step_to`, which catches a domain error and
subdivides; sizes goes through `step_by`, which is bare and never evaluates
`ode_state_valid`.

**`assign_from` drops `storage_domain_tol`.** It copies `storage_gate_width` and
`storage_prod_eps` beside it. A rebound tangent strategy silently reverts that
one to its default. Harmless today.

**`collect_refinement_errors` is set and never cleared**, so every run after a
refinement pays for the sampling. Related: `run_scm(refine_schedule = TRUE,
record_trajectory = TRUE)` returns `p$ode_times` from refinement's last internal
run, not from the run whose trajectory was recorded.

**`control$schedule_verbose` is dead.** Declared, defaulted, bound through
RcppR6, asserted in `test-control.R`, read by nothing. The refinement loop has no
logging call, which is why its non-convergence is unobservable.

**`ci_abs_tol` is inert for TF24.** Only the Medlyn route reads it; the
optimality path's tolerance is hard-wired. Tightening it buys nothing.

## Free wins

**The endpoint evaluation is formed before the error test** and discarded on
rejection, so an accuracy rejection costs six rate evaluations rather than five.
Deferring it past the test saves ~3% of run cost at the measured rejection rates.

**The `L` accumulator states never attain the error norm's maximum and nothing
reads them.** They can leave the norm and the tape.

**`ode_a_dydt` is wired end to end and set to zero.** It is the knob that most
directly changes which component sets the step size, and nothing uses it.

**`ode_step_attempts`, `error_index` and `error_ratio` exist and are unread.**
They name the binding component per step and separate accuracy rejections from
domain throws — the observability a controller needs.

## Build gotchas

`plant` compiles against `phylloptim`'s **installed** headers and `pkgbuild`
tracks no dependency on them, so a `phylloptim` header change needs
`rm plant/src/*.o` before rebuilding or you measure the old code.

With `plant/src/plant.so` present and no `plant/src` source newer than it,
`compile_dll` exits 0 having compiled nothing. Use `force = TRUE`.

Both fail silently into wrong numbers.

## Next measurements

1. **Per-cohort branch attribution.** `operating_point_counts` is a run-level
   scalar per kind; the tally is already per-solve where it is formed. Exposing
   it lets a trait scan be differenced branch by branch, which would convict or
   clear hydraulic shutdown as the source of the 0.3–0.4% steps in `J` in one
   measurement. Small, and it unblocks the others.
2. **An arid site.** The shutdown verdict was reached at 1095 mm/yr over 1.5 m of
   soil, where the wettest rooted layer sits at 1e-13 to 1e-19 MPa suction
   throughout and a 182 mm year changes nothing. 200–300 mm/yr, or a shallower
   column, is the one regime that could overturn it — and the mechanism says why
   it might.
3. **Does the step in `J` scale with switching activity?** Repeat the 25-point
   trait scan on records at 2.6% and 0% non-interior share. No code needed.
4. **The 284× coordinate gap.** At the same aligned grid and cohort count, the
   height and birth-date coordinates give `J` 284× apart while their censuses
   differ by 13–19%. Plausibly a near-extinction artefact; re-check at lifetime
   40, where it should be tame.
5. **Why `stand_gradient` refuses.** It returns `stem_curve_domain` for all three
   census metrics on the short fixture, which is why that work fell back to
   finite differences and their 11.6× amplification.
6. **A census metric for offspring production.** The state is already an ODE
   state per member and the functional is linear in the terminal state; only the
   adjoint seed is missing. That would give `dJ/dθ` by sweep — no finite
   difference, no scatter floor, ~6× cheaper.

## What is unresolved

Whether the gradient converges at the value's rate. The adjoint says yes
(1.29–1.91 against values at 1.31–1.94); finite-difference ladders disagree with
each other, and the instrument is differencing a step function. Item 6 above
settles it.
