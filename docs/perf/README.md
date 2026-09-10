# The path to 100 s

The reverse sweep over a century stand costs **156.27 s, which is 4.58 times its
own forward run**. The target is 100 s, about **2.93 times forward**, which is
roughly where this model sat before the leaf's derivative surface was rebuilt.
This directory is the measurement of where the remaining time is and what has
already been ruled out.

Everything below describes the triple as it stands. What it used to cost, and
which commit moved which figure, is in the git history and is not the question
any more.

## How to price a change here

Read this part first. Three of the four wrong conclusions this project has
reached about its own performance came from measuring the wrong quantity, not
from measuring badly.

⚠️ **COST IS OPERATIONS TIMES THE PRICE OF ONE, SO A STATEMENT COUNT IS NOT A
PRICE.** A tape statement is bookkeeping over a run of operations. Counting
statements is blind twice: to arithmetic that never reaches a tape, which is all
of a tangent's, and to how WIDE a scalar's derivative is, which is the entire
cost of a nested one. Measured here: removing 1219 statements a placement from
the leaf boundary -- a 22-fold cut -- changed the gradient by nothing, while a
curve dismissed at four statements turned out to be a quarter of the
instructions.

⚠️ **USE `callgrind`, NOT SECONDS.** Wall clock on this fixture has moved 28%
between sittings and 81% for the SAME BINARY. Instruction counts are exact and
repeatable:

```sh
valgrind --tool=callgrind --callgrind-out-file=cg.out ./probe_tape_regions
callgrind_annotate cg.out
```

Seconds are still what the target is written in, so take them -- but take them
as `gradient_s / forward_s`, never as absolute seconds, and never across
sittings without the forward control beside them.

⚠️ **A COMPARISON WITHOUT A CONTROL IS NOT A MEASUREMENT.** Three times in one
session a comparison returned green because it was comparing nothing: two empty
outputs from a fixture that was not interior, a row set that the change did not
touch, and twenty pre-existing failures attributed to a change that did not
cause them. Take the baseline first, on the same fixture, with the same
binary shape, and count the entries before reading the verdict.

⚠️ **THE GRADIENT SUITE IS NOT THE GUARD.** It passed `pass=684 fail=0` while
135 of 138 entries moved. The guard is a value comparison against
`values/current.tsv`:

```sh
R_LIBS="<your lib>:$(Rscript -e 'cat(paste(.libPaths(),collapse=":"))')" \
  OPENBLAS_NUM_THREADS=1 MODE=values ARM=mine \
  Rscript docs/perf/tools/century-gradient.R > /tmp/mine.txt
python3 docs/perf/tools/compare-gradient.py docs/perf/values/current.tsv /tmp/mine.txt
```

It counts finite entries before comparing any value, because `identical(NaN,
NaN)` is TRUE in R and a bit-identity check otherwise passes against an all-NaN
gradient. It reports DROPPED ROWS separately -- an exact zero where the
reference is non-zero -- because that, and not a wrong number, is what a missing
supplied row looks like.

⚠️ **A MOVED-COUNT MEANS NOTHING; THE MAGNITUDE MEANS EVERYTHING.** Almost every
entry runs through the leaf, so almost any change moves 135 of 138. Reassociation
moves them 1e-11. A change to the science moves them 1e-3. Those two look
identical in the count and differ by eight orders in the number beside it.

⚠️ **THE GRADIENT AMPLIFIES A ROUNDING CHANGE AT A CURVE KNOT BY THIRTEEN
ORDERS**, and only at a curve knot. A 1-5 ULP change to the incomplete gamma
that builds the vulnerability spline reaches 6.707e-03 at the census metrics,
because the spline is what the root-finds run on. The same size of change to a
multiplicative temperature response reached exactly zero: measured, 138 of 138
bit-identical. Which primitive moved decides whether it matters.

## The fixture, and the counts that make two runs comparable

`scripts/forward-century-schedule.rds`, transplanted by
`scripts/profile-stand-reverse.R`: one species, `max_patch_lifetime` 105.32, 169
nodes, 3378 accepted steps.

⚠️ **These must match or the runs are not doing the same work**, and no
comparison between them means anything: `rate_evaluations` 20268, `placements`
2330530, `swept_ranges` 169, `metrics` 3, recordings swept 3548, `refusal` none,
`keeps_states` TRUE.

⚠️ A figure from a shorter stand is not comparable and understates every ratio:
the field build is O(knots x cohorts), so anything scaling with cohort count is
invisible until the stand is long.

## Where the cost is

`values/boundary-cost.txt` prices one placement three ways. The headline: the
leaf boundary spends **34.7% of its instructions re-deriving quantities that do
not move with the variable being differentiated** -- `assim_colimited_kernel`
recomputes vcmax, the electron transport and the dark respiration on every call,
and the slope helper differentiates all of it in `n_pars + 1` directions.

## The levers, and what each is worth

| lever | worth | what it costs |
| --- | --- | --- |
| **Hoist the ci-independent rates** out of the assimilation kernel, as the pre-merge five-argument overload allowed | 34.7% of the boundary's instructions, measured | a wider kernel signature; no model decision |
| **Attribute the rest of the recording.** 1018.70 statements a placement, ~82% of what plant now pushes, and never once measured in operations or instructions | unknown, and it is the only block left big enough to reach the target | a fresh profile; the leaf probe's technique extends to it |
| **The placement count**, 2,330,530 -- one leaf per cohort per RK stage per step | 6x, larger than everything else combined | it moves the trajectory. A model decision about whether the operating point is stage-invariant, not a performance one |
| **plant's per-placement rebuilds**: `layer_thicknesses` twice a placement, `leaf_pars` 20 constructions and 15 copies of which 13 never vary, two local vectors of actives | ~1%, and it removes a stated hazard -- the two `layer_thicknesses` sources are warned to be a silent squared factor if they drift | nothing |

## Refused, with the measurement that refuses it

| proposal | why not |
| --- | --- |
| more tape economy at the leaf | measured out twice: taking the whole marginal forward is 17%, and taking the kernels' slopes through a tangent removed 1219 statements a placement for no change in the gradient at all |
| `promote_double<false>` on the incomplete gamma | 3.97x faster and it MOVES THE SCIENCE: 135 of 138 entries, worst 6.707e-03 relative, 88 of them past 1e-4, against a base-vs-base control of exactly zero |
| preaccumulating the whole leaf region | odelia has the primitive; it pays when the consumer sweeps more often than the region has outputs. The leaf has six outputs and the stand seeds three metrics. Measured at 2544 walks against 1440 inline, and its own probe reports two regions sharing inputs summing rows in a different order (9.8e-10 to 1.4e-08), which the gradient ladder asserts against |
| a private tape per solved leaf | constructing one reserves 192 MiB; reusing one costs 0.14 us a cycle, so the cycle was never the expense |
| blaming the slot high-water mark | `resetTo` does not lower `maxDerivative_` and `XAD_TAPE_REUSE_SLOTS` is off, so the derivative array stays sized by the peak -- measured, 5.1% |
| nesting a tangent above an adjoint | 521 tape statements against the 17 of the kernel it differentiates. `odelia/tangent.hpp` now refuses it at compile time, so this one cannot come back |

`docs/design/leaf-derivatives.md` carries the refusals about what the leaf's
derivative may be taken FROM, which are model arguments rather than measurements
and are not repeated here.

## Reproducing

`values/current.tsv` is the 138-entry census gradient at `%.17g` for the current
triple, and is the reference every change is held against. `MODE=time` on the
same script reports the ratio beside the four counts.

`phylloptim/tests/cpp/probe_tape_regions` (`make CXX=g++ probe_tape_regions`)
prices the leaf boundary region by region and kernel by kernel in seconds, where
the century stand is minutes. ⚠️ Its fixture must reach an Interior point or it
prints no rows at all, and a diff of two empty outputs passes.

⚠️ **Rebuild deliberately.** `R CMD INSTALL --preclean` has been observed
rebuilding 3 of 25 objects after a header edit, reporting `DONE`, and leaving 22
compiled against the old header. `rm -f src/*.o src/*.so` first, and count the
compile lines: a real plant build prints about 25, every one ending at `-O2`
with no `-O0`.

⚠️ **Two golden files are stale on Linux and are not yours to re-bless.**
`test_golden` reports 222 mismatches of 576 operating points beyond even the
cross-platform tolerance, and `test_primitives` reports 20 arithmetic failures.
Both were generated on macOS/arm64. Take their baseline before a change and
compare against it; do not regenerate either from here.
