# Design: building a run's schedule on the birth-date coordinate

Plant moved TF24 to the birth-date coordinate for stability once the storage
pools were introduced. The schedule is still built as it was for the height
coordinate:

- `refine_schedule()` refuses the birth date.
- The pilot, the tolerance over time (`control_window`) and the error estimate
  (`diagnose_scm`) are separate calls a person strings together.

This turn designs how plant builds a run's schedule on the birth date from first
principles: the introductions, the tolerance over time, and the representation
between nodes. The map of today's pieces is `map-schedule-building.md`.

The first search (`design-schedule-building/rejected-1.md`) was rejected. Its
assumptions are re-established below before any design is searched again.

## The goal

For one parameter set θ on one rainfall record, compute `ln J` and its gradient,
each converged to within ε. Minimise both:

- **search time:** the runs spent finding the schedule;
- **final runtime:** the run on the schedule found.

## What the first search assumed, and why that was wrong

1. **The wrong unit of work.** It priced an evolutionary analysis: 84 forwards,
   invaders and curvatures. "Search" became the search over traits, and every
   proposal competed on spreading one grid's cost over many runs. The unit is
   one run's `J` and gradient, and the search is for its schedule.
2. **One error estimate, taken as given.** It treated the move between uniform
   rungs, divided by three, as the only honest estimate. That estimate holds
   only on uniform grids, so every proposal ended up uniform. That ruled out
   placing introductions where the error is made, the one lever that cuts both
   search time and runtime.
3. **The evidence for strategic refinement went unread.** The proposers were
   kept from `archive/` and never read `measurements/field-adjoint-map.md`. That
   spike shows the sweep can say where the error is made (W6).

## Working assumptions

Each is marked *measured* (with its source), *assumed*, or *to confirm*.

**W1. Which quantities converge.** The stand's `ln J` and its gradient: the 49
elasticities, each within its ε (0.025 in `ln J`; the elasticities from
`measurements/eps-spread.md`, never under 0.01). Invaders walk the stand's
schedule; their convergence is checked, not designed for, in this turn. *To
confirm.*

**W2. Cost is rows.**
- The final run is a forward plus a sweep: about 3.6F, where F is one u108
  forward (0.373M rows as `control_tf24()` ships it; `design-grid-controller.md`
  R7).
- An introduction at birth date b costs its remaining lifetime in steps, so
  early introductions cost most (59–61% of member-steps fall after t = 25).
- Uniform doubling multiplies rows by 2.06. *Measured.*

**W3. Search time is counted in the same rows** as the final run. A schedule used
once minimises their sum. A schedule reused at nearby θ weights the final run
more. *To confirm the weighting.*

**W4. Introductions are the main axis.** The node error is about 100× the time
error at `3e-5` (item 8). So most of the search is over introductions, and the
tolerance is second. *Measured.*

**W5. The error is concentrated in birth date, so placement is the lever.**
*Measured:*
- J is earned by cohorts born before 3.6 (78–100%); births after 20 hold at
  most 2.4e-4 of it (`grid-dynamics.md` §8).
- Episodic needs spacing below its dry spells (median 31 days); constant needs
  nodes every 1/16 day at its front. Both are local features.
- Uniform refinement pays for these everywhere. Episodic converges only at u429
  to u857, which costs 4.3–8.8F per forward.

**W6. A node's value includes the field it sets for others, and the sweep
measures it.**
- Thinning stand nodes after b = 10 moved `ln J` by 0.70ε, though those births
  earn almost none of J. They change the water that the J-earning cohort sees.
  So a placement weight from J's own shares (the root law, spacing ∝
  weight^(−1/3)) is not enough for the stand.
- The sweep's field adjoints, contracted with each interval's field defect
  (built by dropping every other node of the held run), predict J's field part
  at 0.99–1.00× of the measured move. Per group of intervals they are within
  0.97–1.11×, and the invader's `lma` elasticity's field part within 0.94–0.99×.
  This costs 12% of a sweep (`measurements/field-adjoint-map.md`).
- *Measured on long drought only.* Its own falsifiers are narrow features (the
  constant front), coarse spacing (u54) and moves off the square law.

**W7. Refine strategically from a coarse default.** *The working hypothesis this
turn tests.* Each pass:
1. Run a forward and a sweep.
2. Estimate each interval's share of the error. Its own part is the quadrature
   of J's integrand between nodes; its field part comes from the adjoint map.
3. Bisect the intervals that carry the most.

Stop when the estimated total is under ε. This is `refine_schedule()`'s shape
on the height coordinate (error per node, bisect, repeat), with an estimator
that works on the birth date.

The comparison, the floor, is uniform doubling with the move between rungs as
its estimate. It is honest on long drought and long-wet (companion 0.95–0.98)
but pays for every local feature everywhere.

**W8. The stopping test is the certificate.** The run reports its estimated
error per quantity. On a placed grid the estimate is per interval, because the
move between rungs under-reports there: graded grids' companions report only
0.71–0.80 of the error (`grid-dynamics.md` §16). *Measured for the rung
estimate; the per-interval estimate's honesty off long drought is the open
question.*

**W9. Search must cost less than the final run.**
- Each pass costs a forward and a sweep on its own grid.
- If each pass adds intervals only where they are needed, the earlier passes
  sum to less than the last one.
- The last pass's run is the final run, so nothing is run twice.

*Assumed; this is the target the design is priced against.*

**W10. Time takes the same treatment.** Tolerance goes where J is still to come:
the window saves 21–23% of rows on pulsed records and 1.9% under constant rain.
It is read from the same pass's record, so no separate pilot is run. Whether
time and introductions are refined in one loop, or the tolerance is set by rule
once, follows from W4. *Measured saving; the coupling is assumed.*

**W11. Reuse at nearby θ comes later.** A refined schedule can be frozen and
reused at nearby θ (OBJECTIVES' "shared"). This turn designs one run's schedule
and leaves reuse to a later turn. *To confirm.*

**W12. The interval is the unit of refinement.** The cohorts born between two
introductions carry:
- their establishment (today's "exact counts");
- their crowns (today's "crown spread");
- now their share of the error.

Bisecting one is the schedule's only operation. This gives the interval its
reason to be a named thing; its name follows from that role. *Proposed.*

## What would overturn these

- **W6 fails off long drought:** the map misses an interval's error by more
  than about 20% on episodic or constant, or refining its top-ranked intervals
  does not move J as predicted. W7 then falls back to the floor, and the design
  becomes uniform doubling with a better estimate.
- **The gradient's error is not where J's is.** If the elasticities need
  intervals the J map ranks low, the estimator must rank intervals for each
  quantity. The sweep already carries every registered parameter's adjoint, so
  this costs one contraction per quantity, not another sweep.
