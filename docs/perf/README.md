# The path to 100 s

The reverse sweep over a century stand costs **about 2.9 times its own forward
run**, from about 4.7 times. The target is 100 s, about **2.93 times forward**,
which is roughly where this model sat before the leaf's derivative surface was
rebuilt -- so it is reached to within what this fixture's timing can resolve,
and no further. Interleaved against the arm the last run of work started from,
alternating in one sitting:

| arm | forward | gradient | ratio |
| --- | --- | --- | --- |
| before | 33.76 | 151.30 | 4.48x |
| **now** | 36.74 | 109.58 | **2.98x** |
| before | 35.07 | 172.53 | 4.92x |
| **now** | 38.88 | 109.80 | **2.82x** |

A third reading of the new arm, later the same sitting and with no control
beside it, gave 123.85 against 40.28 -- 3.07x. Three readings, 2.82 to 3.07.

⚠️ **READ THE RATIO AND THE REPRODUCIBILITY, NOT THE SECONDS.** The forward run
drifted 19% upward across the five readings, which moves every ratio; what does
not drift is that the new arm's gradient repeated to 0.2% across the two
interleaved ones where the old arm's moved 14%.

This directory is the measurement of where the remaining time is and what has
already been ruled out.

Everything below describes the triple as it stands. What it used to cost, and
which commit moved which figure, is in the git history and is not the question
any more.

## How to price a change here

Read this part first. Every wrong conclusion this project has reached about its
own performance came from measuring the wrong quantity, or the right one on the
wrong fixture -- not from measuring badly.

⚠️ **COST IS OPERATIONS TIMES THE PRICE OF ONE, AND BOTH HALVES MOVE.** The
arithmetic was the cost until recently: a slope taken through a twenty-slot pack
carried twenty-one derivative directions where five would do, and `xad::FReal`'s
constructor alone was 18.9% of the run. Removing that left the ARITHMETIC lean
and the TAPE's bookkeeping dominant -- recording is about 28% of the process now
and sweeping 20% -- so a statement count is a real term again. It was never a
price on its own and it is not one now: price a statement as `record + sweep`,
and price arithmetic in instructions.

⚠️ **A PERMANENT STATEMENT IS SWEPT ONCE PER CENSUS METRIC. A REWOUND ONE IS
SWEPT ONCE.** `SCM::census_trait_gradient` records a block once and sweeps it
once per metric, and the stand seeds three. Work inside an `implicit_value`
residual is recorded, swept locally, and thrown away; the same work hoisted out
of the residual is swept three times instead. So hoisting a common
subexpression out of a residual is not free and can lose.

⚠️ **A COPY OF AN ACTIVE SCALAR IS A RECORDED STATEMENT.** `const T x = cond ? a
: b;` over two actives records one; `const T& x = ...` records none and is the
same number. Four of those in one layer loop, and a vector of them copied out of
the draw and then overwritten term by term, were 12 statements a placement at
the fixture's five soil layers.

⚠️ **USE `callgrind`, NOT SECONDS.** Wall clock on this fixture has moved 28%
between sittings and 81% for the SAME BINARY; the forward run alone drifted 15%
across the four interleaved readings above. Instruction counts are exact and
repeatable:

```sh
valgrind --tool=callgrind --callgrind-out-file=cg.out \
  ./probe_tape_regions placements 60 5
callgrind_annotate cg.out
```

Seconds are still what the target is written in, so take them -- but take them
as `gradient_s / forward_s`, never as absolute seconds, and never across
sittings without the forward control beside them.

⚠️ **A COMPARISON WITHOUT A CONTROL IS NOT A MEASUREMENT.** Three times in one
session a comparison returned green because it was comparing nothing: two empty
outputs from a fixture that was not interior, a row set that the change did not
touch, and twenty pre-existing failures attributed to a change that did not
cause them. Take the baseline first, on the same fixture, with the same binary
shape, and count the entries before reading the verdict.

⚠️ **THE GRADIENT SUITE IS NOT THE GUARD.** It once passed `pass=684 fail=0`
while 135 of 138 entries moved; at HEAD it is `pass=716 fail=0 error=0 skip=5`
over 19 files, and it would pass the same way. The guard is a value comparison
against `values/current.tsv`:

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
entry runs through the leaf, so almost any change moves 135 of 138.
Reassociation moves them 1e-11. A change to the science moves them 1e-3. Those
two look identical in the count and differ by eight orders in the number beside
it.

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

⚠️ These must match or the runs are not doing the same work, and no comparison
between them means anything: `rate_evaluations` 20268, `placements` 2330530,
`swept_ranges` 169, `metrics` 3, recordings swept 3548, `refusal` none,
`keeps_states` TRUE.

⚠️ **THE STAND HAS FIVE SOIL LAYERS, AND THE SUPPLY SCALES WITH THEM.** The draw
is 17 tape statements a placement at one layer and 73 at five, so a probe run at
one layer understates the largest block in the leaf by four-fold. `Environment("TF24")`'s
`get_soil_number_of_depths()` is where that number comes from.

⚠️ A figure from a shorter stand is not comparable and understates every ratio:
the field build is O(knots x cohorts), so anything scaling with cohort count is
invisible until the stand is long.

## Where the cost is

`values/century-profile.txt` is a sampled profile of the whole run;
`values/boundary-cost.txt` prices one placement in statements, operations and
instructions. Shares below are of the whole process, of which
`census_trait_gradient` is 74.6% and the forward run it divides by is the rest.

| | share |
| --- | --- |
| `TF24_Strategy::record_leaf_outputs` | **28.7%** |
| the tape's own bookkeeping -- `AReal::AReal` 12.7%, `registerVariable` and `registerVariableAtEnd` 8.6%, `append_n` 4.5% | **~28%** |
| `Tape::computeAdjointsToImpl` -- the sweeps | **19.8%** |
| `MultiLayerRoots::uptake_impl`, both passes (6.5% of the run is its own instructions) | 17.7% |
| `odelia::implicit_value` | 11.5% |
| `quadrature::QK::integrate` -- the crown light integration | 11.5% |
| `Leaf::collar_at` | 9.8% |
| `TF24_Strategy::compute_average_light_environment` | 9.8% |
| `Leaf::marginal_collar_slope` -- the curvature, three double solves a placement | 7.5% |
| `Leaf::supply_draw_at` | 5.7% |
| `Leaf::outputs_at` | 4.2% |
| `Leaf::kernel_slope_at` | 4.0% |

⚠️ **THE ROOT FINDS ARE THE FORWARD RUN, WHICH IS THE DENOMINATOR.**
`toms748_solve` is 29.8% and `find_root_collar_psi_for` 27.5%, against a forward
run that is 25.4% of the process -- so nearly all of the searching is the model
being solved, not the gradient re-solving it. A previous version of this file
called the root finds a lever on that arithmetic. They are not. What the
gradient re-solves is `marginal_collar_slope`, and that is 7.5%.

⚠️ **THE TAPE IS ABOUT HALF THE GRADIENT NOW.** Recording is around 28% of the
process and sweeping 19.8%, against a leaf boundary of 28.7%. That is the
opposite of where this started -- `kernel_slope_at` was 21.6% and is 4.0% -- and
it is why statement counts are back in the pricing above.

## The levers, and what each is worth

| lever | worth | what it costs |
| --- | --- | --- |
| **plant's parameter pack.** `record_leaf_outputs` copies fifteen of the strategy's registered traits into a `leaf_pars<S>` per placement, and a copy of an active is a recorded statement | 15 statements and 15 operations a placement, measured on the tape's counters, against the leaf's own 104 -- and each is swept three times | the pack has to become a view over what plant already owns rather than a copy of it, which is `leaf_pars`'s element type and every read through it. plant has no hook at the recording boundary -- `load_solved` is per rate evaluation, which is 115 placements -- so a cached pack goes stale silently |
| **The curvature, `marginal_collar_slope`, 7.5%.** Three double model evaluations a placement on the gradient pass: `dprofit_at_collar_psi` at p0 +/- 1e-5, then `evaluate_root_collar_psi_for(p0)` to put the model back, which re-runs `prepare_collar_solve` and rebuilds the soil-side cache | up to 7.5%, of which the restore is about a third | the difference itself is not negotiable: the analytic assembly was measured at an eighth of the answer on this stand. The restore might be -- it is a re-solve used to undo a probe, where plant's own `marginal_here` probes on a COPY of the leaf instead |
| **The supply draw, 73 statements a placement** at the stand's five layers, 14.6 a layer | still the largest block in the leaf | the layer body is near its floor: two supplied integral rows, a span, a resistance, a flux and the slope's five terms. Anything further is a change to the supply model |
| **The placement count**, 2,330,530 -- one leaf per cohort per RK stage per step | 6x, larger than everything else combined | it moves the trajectory. A model decision about whether the operating point is stage-invariant, not a performance one |

## Refused, with the measurement that refuses it

| proposal | why not |
| --- | --- |
| `promote_double<false>` on the incomplete gamma | 3.97x faster and it MOVES THE SCIENCE: 135 of 138 entries, worst 6.707e-03 relative, 88 of them past 1e-4, against a base-vs-base control of exactly zero |
| preaccumulating the leaf region | odelia has the primitive; it pays when the consumer sweeps more often than the region has outputs. The leaf has six outputs and the stand seeds three metrics. Measured at 2544 walks against 1440 inline, and its own probe reports two regions sharing inputs summing rows in a different order (9.8e-10 to 1.4e-08), which the gradient ladder asserts against. The supply draw on its own is worse, not better: seven outputs against three sweeps |
| a wider adjoint scalar, so the three metrics sweep once | measured in odelia: 1.15x slower to 0.97x at width three, worse than separate walks at width four. `ode_interface.hpp` carries the numbers, and every width agrees bit for bit, so what is ruled out is cost |
| a private tape per solved leaf | constructing one reserves 192 MiB; reusing one costs 0.14 us a cycle, so the cycle was never the expense |
| blaming the slot high-water mark | `resetTo` does not lower `maxDerivative_` and `XAD_TAPE_REUSE_SLOTS` is off, so the derivative array stays sized by the peak -- measured, 5.1% |
| nesting a tangent above an adjoint | 521 tape statements against the 17 of the kernel it differentiates. `odelia/tangent.hpp` now refuses it at compile time, so this one cannot come back |

⚠️ **"MORE TAPE ECONOMY AT THE LEAF" WAS ON THAT LIST, AND IT WAS WRONG.** It was
refused on two measurements -- taking the whole marginal forward was 17%, and
taking the kernels' slopes through a tangent removed 1219 statements a placement
for no change at all. Both were true, and both were about the tape's economy
being paid for in ARITHMETIC: what those statements bought was a nested tangent
that cost more than they did. With the arithmetic lean, the same leaf gave up a
third of its recording for a quarter of the gradient's time. The lesson is not
that statement counts matter after all; it is that neither half of
`count x price` can be read without the other.

⚠️ **AND ONE THAT LOOKS FREE AND MAY NOT BE.** The operating point is placed
TWICE a placement: `collar_coords_at` runs inside the collar residual, where it
is rewound, and again inside `profit_at`, where it is not -- at the same held
collar with the same pack. Sharing it means hoisting the placement out of the
residual, which moves about 35 statements from one sweep to three. Whether that
wins is arithmetic nobody has done on a real build; the counts say it is close
to a wash. If you try it, take the ratio, not the statement count.

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
`./probe_tape_regions placements 60 5` is the mode to run under callgrind: the
three calls plant makes and nothing else, at the stand's five soil layers.

⚠️ **Rebuild deliberately.** `R CMD INSTALL --preclean` has been observed
rebuilding 3 of 25 objects after a header edit, reporting `DONE`, and leaving 22
compiled against the old header. `rm -f src/*.o src/*.so` first, and count the
compile lines: a real plant build prints about 25, every one ending at `-O2`
with no `-O0`.

⚠️ **Two golden files are stale on Linux and are not yours to re-bless.**
`test_golden` reports 4320 mismatches over 576 operating points beyond even the
cross-platform tolerance, and the psi-stem golden 10692 over 5184 rows. Both
were generated on macOS/arm64. Take their baseline before a change and compare
against it -- EVERY summary line, not the failure count -- and do not regenerate
either from here.
