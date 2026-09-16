# What the tests cost, and why

A companion to `catalog.md`, which holds what must be fixed before submitting.
This holds what was measured about the suite this branch adds: one defect found
while measuring it and what the defect turned out to be, where the cost came
from, and which of the remaining levers belong to a maintainer rather than to the
branch.

Every number here was taken on this tree at `-O2`. Where a figure is a property
of one fixture it says which.

---

## 1. The defect, and what it was

`test-census.R`'s G3 compared the census seed against a closed form written out
beside it, and the two disagreed by a uniform relative scalar -- 6.13e-09 on a
written distribution, 8.63e-05 on one grown to a lifetime of 12 -- which the
1e-4 tolerance absorbed.

**The seed was right and the reference was incomplete.** The inflow boundary node
is the reduction's closing grid point and is not ODE state:
`census_state_and_trait_rows` rebuilds it through `set_state_and_boundary`, from
a light field every cohort's height and log density enters by `n_k * A_k` -- the
same product the census integrates. So the seed carries a channel that a
reduction written over a fixed state table cannot, and the closed form was the
derivative of a different function.

Measured against a direct difference of the boundary node's own contribution,
that channel is the whole of the disagreement:

| fixture | observed gap | boundary channel | ratio |
|---|---|---|---|
| written, lifetime 1 | 6.1316e-09 | 6.0758e-09 | 0.99 |
| grown, lifetime 3 | 9.2427e-06 | 9.2427e-06 | 1.0000 |
| grown, lifetime 12 | 8.6290e-05 | 8.6290e-05 | 1.0000 |

Three properties of the gap fall out of the mechanism and were what made it look
like a missing scalar. It is the same for `height` and for `log_density`, because
both reach the light field only through `n_k * A_k`. It is near-uniform over
nodes, because the field is the same trapezium the census is, so the weight
divides out and what is left is the canopy shape at the boundary node's height --
which is one for every cohort taller than it, and departs only at the shortest
(node 78 read 6.1454e-09 against 6.1316e-09). And it is **exactly zero** on
`area_heartwood` and `mass_heartwood`, which are not in the light field, which is
why G4's linear channels were already bit-exact.

### What the fix was

G3 now differences the census itself, read off a copy of the patch, so the
boundary node moves with the state. Over every node and both state families:

| | measured | asserted |
|---|---|---|
| seed against the birth-date difference | worst 9.50e-11 | < 1e-8 |
| seed against the height-grid difference | closest 0.41 | > 0.25 |
| seed against the boundary-held closed form | 2.47e-07 | > 1e-8 |

The third line is new and closes a failure mode `scm.h` names and nothing
guarded: loading the state without the boundary rebuild takes that contribution
to exactly zero with nothing thrown, and the old comparison would have passed
*better* for it. Substituting each wrong answer for the seed, the block rejects a
seed with the channel gone, a seed built on the height grid, and a seed wrong by
one part per million -- where the old tolerance admitted the last.

---

## 2. What the suite cost, and what it costs now

Measured end to end, one process, per file:

| | before | after | checks |
|---|---|---|---|
| the ladder, 14 files | 63 s | 61 s | 615 |
| `test-census.R` | 259 s | **1.4 s** | 27 → 31 |
| `test-mutant.R` | 632 s | **80 s** | 23 → 24 |
| `test-gradient-incidence.R` | 580 s | **253 s** | 66 → 68 |
| `test-gradient-parity.R` | 343 s | **157 s** | 58 |
| total | 1877 s | **552 s** | 789 → 802 |

`tests/testthat.R` is `test_check("plant")`, so all of it runs under `R CMD check`
on three operating systems. The eleven failures are A1's and are unchanged in
number, file and reason.

### The mechanism, in one sentence

**A patch lifetime buys the stiff regime; the cohort count is what it costs; and
the default schedule confounds them by deriving its introduction count from the
lifetime.** Held at a fixed lifetime and varying only how many of that schedule's
introductions are kept:

| | full schedule | thinned | thinned to |
|---|---|---|---|
| `test-mutant.R`'s TF24 replay, lifetime 6 | 12714 steps, 623 s | 6071 steps, 71 s | 20 of 89 |
| incidence's clamped stand, lifetime 5 | 11347 steps, 258 s | 3267 steps, 18 s | 20 of 88 |
| parity's `shaded`, lifetime 5 | 11810 steps, 319 s | 3250 steps, 22 s | 20 of 88 |

In each case the thinned run keeps everything the block asserts: the replay
identity holds to 1.6e-13 against a 1e-3 tolerance where the full schedule holds
to 8.1e-13; both light-floor sites still fire on both paths with the crown site
ahead by 170x; and every driver keeps its verdict, its refusal reason and its
clamp sites. This is the same confound `AGENTS.md`'s introductions table
measured from the other side, now confirmed on three independent fixtures.

### Three structural findings, each a check that could not fail

**A shared stand was cleared.** `clear_diagnostics()` resets every counter, the
clamps and the curvature margin together. The block checking that the tally is
per-run cleared the wet stand every other block reads, so the light floor's *"does
not bind at the shipped value"* was asserted against a tally another block had
zeroed. On a fresh stand the claim is true -- `rooting_depth` fires 168,989 times
and both light sites read zero -- so the check now reads a copy taken at build
time and carries a non-vacuity assertion on a site that does bind.

**A cache keyed on whether a stand had been swept** ran two of five drivers
twice, once for their forward tallies and once for the differentiated ones. An
entry now holds the run, the readings taken before anything sweeps it, and a
gradient taken on first request.

**One recipe, two copies.** `incidence_run` and `parity_stand` were the same
function, and parity's own comment claimed the regimes were named once. They now
call `ladder_driver_stand()`, beside the regime list the reference capture reads.

---

## 3. Construct, or grow

The suite has two idioms and the cost tracks them exactly.

**The ladder constructs its states.** `ladder_patch_fold()` forces a curvature
fold by setting the floor; `ladder_patch_shutdown()` reaches a genuine hydraulic
shutdown by drying the soil; `ladder_patch_uniform_drying()` places a drying
profile. Each elicits a specific leaf behaviour in milliseconds. Fourteen files,
615 assertions, 61 s.

**The surface tier grows to them.** `test-census.R` is the case where that was
paying for nothing: its three grown stands asserted per-state properties, and one
written stand of six nodes reaches all of them. Six rather than the seventy-eight
a default schedule fills in is also what makes the boundary node readable -- it is
2.5e-07 of the answer there against 6.1e-09 under a default schedule, where the
reference's own floor is 9.5e-11.

What does not construct is *how often*. incidence's tallies and parity's coverage
are properties of a history, and the fixtures below are what is left after the
schedule has been thinned to what each asserts.

---

## 4. What is left, and it is D's

| | cost | what it is |
|---|---|---|
| incidence, *"the dry pins are a small minority"* | 178 s | `incidence_stand(0.25, 10)` and `(0.10, 5)`, and its `expect_lt(share, 5)` is one of A1's six failures. Retuning the fixture would tangle a fixture change with the decision it is evidence for. |
| incidence, *"clamps stay out of reach"* | 43 s | a third driver at `rain = 0.05`, read for its soil potentials only |
| parity, `seasonal` | 157 s | the file's only route to a hydraulic shutdown, and the one driver a thinned schedule changes |

D's recalibration row is about the patch lifetime, which is the ecology. Nothing
here moved a lifetime, a rainfall, an amplitude or a `k_I`.

---

## What did not survive measurement

Kept so nobody re-opens them.

- **Thinning parity's `seasonal` driver.** Twenty introductions costs 13 s
  against 156, and loses `determined` and `hydraulic-shutdown`, reaching
  `boundary-root-crit` instead. The other four are identical on all three axes.
- **A denser written distribution, to make the boundary channel bigger.** At
  `log_density` 2 the boundary node's density underflows to zero and the channel
  becomes exactly zero: deeper shade removes the thing being measured.
- **The schedule as the cost driver at a fixed lifetime.** Refused by the
  truncation tables above, which is the same correction applied in reverse.
- **`TF24_hyperpar` as a cheaper fixture for G3.** 17x cheaper at the same node
  count, and G3 failed on it at 4.13e-04 against a tolerance of 1e-4.
- **`node_gradient_eps` as the source of the 6e-09.** Invariant across four
  decades. **Patch survival** as its source: exactly 1.0 on both fixtures. **XAD's
  `pow`**: bit-identical to `std::pow` at an active scalar over the fixture's
  whole height range.
- **Caching as parity's lever.** It already caches in process and on disk, keyed
  by the compiled object's checksum, and forks across regimes, so it costs its
  slowest regime rather than their sum.
- **A cross-file cache for the three drivers incidence and parity share.**
  `Config/testthat/parallel: true` puts the two files in separate processes and
  an on-disk cache outside `tempdir()` is not available under `R CMD check`, so
  sharing the runs would mean merging the files. The recipe is shared instead.
