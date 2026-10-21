Spikes, patches and tools are in [aornugent/plant-dev `spikes/plant-677`](https://github.com/aornugent/plant-dev/tree/claude/pensive-johnson-ip4lx3/spikes/plant-677). `CATALOG.md` has one row per change with its measured effect. Everything below is FF16, one species, birth-date coordinate, gradient divided by its own forward run, starting from #679 + odelia #78 ("B").

## Read the ratio per trait, not per pass

The issue measures one metric and one column (`1.lma`), and gives the break-even as finite differences beating the pass "for fewer than about 12 traits". But the pass costs the same for 1 column or all of them, as the issue itself notes. So its ratio is the price of **every** column at once, and the fair comparison is per trait:

| | columns | gradient / run | per column | one-sided FD per column |
| --- | --- | --- | --- | --- |
| FF16, B, 1 metric | 32 | 14.5x | 0.45x | ≥ 1x |
| FF16, B, 5 metrics | 32 | 27x | 0.84x | ≥ 1x (a run yields every metric) |
| FF16, now, 1 metric | 32 | 4.8x | 0.15x | ≥ 1x |
| FF16, now, 5 metrics | 32 | 6.4–7.2x | 0.20–0.23x | ≥ 1x |
| TF24, B, 1 metric (lifetime 2) | 48 | 2.8–3.2x | ~0.06x | ≥ 1x |

- **Against one-sided differences over every column**, FF16 now costs about 5–7 times less and TF24 about 16 times less. Central differences double the FD side.
- **The break-even is now 5–7 traits.** Asking for a single trait is the one case reverse mode was never meant to win.
- **With `hyperpar`**, the same single pass gives every fitted trait.
- **TF24's low ratio** is because its forward run is 90% `solve_leaf`, which the replay loads rather than solving again. Per step it costs more than FF16; it is divided by a much larger run. With about 50 traits, that model is where the trait count pays most.

## Where it is now

Lifetime 60, interleaved medians, re-evaluating timer:

| | 1 metric | 5 metrics |
| --- | --- | --- |
| B | 0.56 s (14.5x) | 1.04 s (27x) |
| now | 0.18–0.20 s (4.8–5.2x) | 0.25–0.27 s (6.4–7.2x) |

- **Values are identical** to B in every arm.
- **Gradients move at rounding only:** ≤2.7e-13 relative at lifetime 30 and ≤2.3e-12 at lifetime 8. No entry dropped to zero or went non-finite.
- **Tests:** plant's gradient, ladder, census, fitness, strategy, canopy, patch, species, node and environment files (315 tests), and odelia's suite, fail the same tests as B.

Multi-species, all metrics, lifetime 60:

| species | metrics × columns | B | now |
| --- | --- | --- | --- |
| 1 | 5 × 32 | 25–30x | 6.4–7x |
| 2 | 7 × 64 | 32–36x | 7.7x |
| 4 | 11 × 128 | 51x | 8.8–9.2x |

## How we profiled

1. **Instructions, not seconds.** Callgrind, collected only inside the gradient (`--toggle-collect=census_trait_gradient_ff16*`), with the forward run as the denominator. Wall clock varied too much to separate arms, so seconds were taken only as interleaved medians to confirm a change.
2. **A representative fixture.** At lifetime 8 the seedling sits at 82% of canopy height, which hides any lever that depends on canopy structure. Every number above is at lifetime 60.
3. **A guard on every arm before reading a number.** It checks that values are identical, counts finite entries, counts bit-identical entries, finds the worst relative change and checks for rows that dropped to zero. The test files are run on both arms and their failure sets compared. One stale build reproduced its baseline exactly, which is how we learned to clear `src/*.o` before every build.
4. **A cost model.** gradient ≈ Σ_steps [record + seeds × sweep]. We priced XAD's floor directly: about 106 instructions to record a statement, about 10 per statement plus 8.5 per live operation to sweep. Then calls × cost per call by region (`tools/cgtree/ledger.py`), localised line by line.
5. **The tape as data.** A liveness and taint pass over one evaluation's tape (`tools/live*.cpp`) marks each statement dead, live, or dependent on parameters alone, and classes its operands: parameter, state, knot or temporary. Most of the wins came from reading it.

## What worked

| lever | effect |
| --- | --- |
| Stop recording copies and repeats: fold the crown shape, move stage states, return parameters by reference, drop duplicated subexpressions | with odelia's tape changes below, 14.5x → 6.6x one metric at lifetime 8 |
| Record nothing the rates do not read, found by the liveness pass | to 6.3x at lifetime 60 |
| Supplied rows through odelia's own `record_with_derivatives`: the crown integral, then the field reduction. Value and partials in double, one statement each, rows on knot values and slopes | 6.3x → 5.2x one metric; 11.7x → 8.6x five metrics |
| odelia: 12-byte operations, no `memmove` per statement, a cubic's slope read at its value, one-pass row gathering | 8.7x → 7.3x at lifetime 8 for the first three, bit-identical |
| One active System per descent, re-seated in place rather than rebuilt at every insertion. A node is introduced at almost every step, so this was a cost per step | 237 rebuilds → 2; −6.5% |
| Sweep a basis of the metric seeds, not every metric. At a constant birth rate, `offspring_production`'s seed is proportional to `net_reproduction_ratio`'s, so each species adds one sweep rather than two | −10% at 5 metrics; −20% at 4 species × 11 metrics |

The hand-written part is small. It is the partials of the leaf rate `a_p1 E/(E + a_p2)` and of the crown profile `(1 − w)²`, handed to odelia as rows. The spline's linear form stays in odelia (`read_linear`).

## What did not

| proposal | result |
| --- | --- |
| Vector adjoints (`AReal<double, 5>`) | 1.5x slower |
| A sweep carrying five adjoint lanes per slot | Bit-identical and no faster. The cost is the scattered update itself, not the walk |
| Preaccumulating the crown on a local tape | Breaks even near three metrics |
| `XAD_TAPE_REUSE_SLOTS` | Recording 64% slower |
| Skipping zero multipliers in the sweep | A wash |
| Moving rates out on write-out | Not safe: a later reader would get a value without its derivative, silently |
| The crossing interval as rows | Sweep −6% per metric, recording +4% |
| Registering only the requested traits | −3.5–5.6%, which confirms parameters are a small part of the tape |

## Where the floor is

Recording is now about 3.9x the double evaluation and 80% of a one-metric gradient. About 30 points of that is XAD's own bookkeeping; the node and field blocks are close to XAD's minimum for their algebra. Remaining levers:

- **Record step tapes on worker threads ahead of the sweep.** A step's recording reads only the stored forward state, never λ. Measured at 2.8–3.1x on 4 threads, which would put one metric at about 1.7x the run. It needs thread-local tapes, costing 7–10% more instructions single-threaded; `thread_local` scratch; worker errors raised again on the main thread; and a pipeline that crosses widths.
- **XAD stores every operation twice** (a stack buffer, then the chunk): 5–8%.
- **The RK stage combinations are recorded on the tape**, though they are fixed linear algebra: 5–8%.
- **Dead span coefficients and knot positions in the field build:** about 2.6%.

On the open questions: the route that paid was supplying rows through odelia's own `record_with_derivatives`, the "partials in double, one statement per cohort" option. A Jacobian preaccumulated on a local tape cost as much as it saved, and we did not try source transformation. The patches are spikes on #679, not PRs; we will split the ones worth keeping into one PR per change.
