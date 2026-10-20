## Two passes over the same substeps

A stage of the whole System needs the subsystem's value at the stage's
time before that stage has produced the inputs the subsystem reads. The
step therefore integrates the subsystem twice over one set of substeps.

The predictor runs first, under inputs on the line from the step's
starting inputs `u0` along the input slope: the trend of the inputs
from the start of the last adaptive step to the start of this one,
zero where there is none (`last_inputs_`, emptied by `set_state` and
by any step that was not adaptive). Its substeps land on the five
stage fractions, so it hands each stage the subsystem at that stage's
time, and each stage evaluates the whole System there and leaves its
own inputs on the System. The corrector then runs over the same
substeps under the line from `u0` to the inputs of the stage at
`t + h`, and its end is the subsystem's part of the step's end. The
rest of the state takes the tableau's combination of the five stages,
as on any step.

![One substepped step of the toy: the store's first layer over a step 38 times plain Cash–Karp's size, the six evaluations of the whole System on the reference trajectory, and 134 substep ends](FIG:odelia-57/one_step.png)

The figure is step 54 of the whole game's substepped run, from
`t = 1.019` with `h = 0.0445`; plain Cash–Karp's steps at that time are
0.00117. The six evaluations read the store from the predictor, on the
reference trajectory (plain Cash–Karp at 1e-12 from the same start).
The predictor ends at `w1 = 0.154483014`, the corrector at
`0.154483083`, and the reference at `0.154483083`. Plain Cash–Karp
over the same `h` from the same state reads `w1 = 0.244`, `−21.3` and
`−12 498` at its stages at 3/5, 1 and 7/8 of the step, and ends at
`−2.0e10`. The 134 substeps are each about 0.0075 of the step, 3.3e-4
in time, a third of plain Cash–Karp's own step there, because they are
chosen at a relative tolerance of 1e-9 whatever the run's tolerance is.

## The error, and its order

A substepped step's error in the subsystem's components is the larger
of two things: how far the corrector ends from the predictor, and how
far the stages' inputs stray from the corrector's line, weighed as
`step_end` weighs the stages. The first measures the input slope's
miss; the second, inputs that curve within the step. The other
components keep Cash–Karp's estimate. In the step above the first term
is 6.9e-8 against a corrector 2.7e-10 from the reference.

The coupling this estimates is second order in the step. Across
tolerances 1e-6 to 1e-10 on the toy to `t = 2`, a substepped run's
error against the 1e-12 reference falls as the step count to the power
1.7 to 2.6, at every `K` from 10 to 1e5; plain Cash–Karp's falls at
5.7 to 6.1 where its steps are set by accuracy (`K` up to 1e3). The
size of the substepped error falls as the store stiffens. At `K = 1e4` and
tolerance 1e-6 the substepped run ends 9.4e-9 from the reference; at
`K = 10`, 5.4e-5, which is 1e-7 of the population there (x ≈ 531) and
inside the run's relative tolerance; plain Cash–Karp ends 6.1e-7 from
it because it carries its fifth-order solution.

## What a replay must carry

The input slope comes from the step before, and a replay of one step,
or a sweep that re-runs it at an active scalar, has no step before it
to take a slope from. So the run records the slope with the substep
ends on the step's row (`instruction::subsystem`), and every other pass
takes both from the row and calls the same `take_substepped_step`: the
substeps and the line are the run's, the arithmetic along them is the
pass's own. A replay at other parameters therefore takes the run's
substeps, and the sweep differentiates the step the run took; the
tangent and adjoint tests check both against central differences of
that replay, to 1e-5 relative.

Two things cannot carry a row and are refused. `step_to` steps a grid
of times and holds no substeps, so it stops where a step would
substep. A recorded row without substeps over an interval that spans a
knot was substepped by the run whatever the System reported, so
`step_by` stops there too. A row without substeps where the run
substepped only because the System reported weak coupling is not
caught, since a replay at other parameters may report differently and
the decision belongs to the run; NEWS says to carry the rows.

## Performance

![Accepted steps and rate evaluations against the store's drainage K, plain Cash–Karp and substepped, each at its cheapest tolerance within 1e-6 of the reference](FIG:odelia-57/steps_vs_stiffness.png)

Counts on the toy to `t = 2`, each arm at the cheapest tolerance in a
sweep from 1e-3 to 1e-10 (half-decade steps) that ends within 1e-6 of
plain Cash–Karp at 1e-12, `substep_below` 0.1:

| K | plain steps | substepped steps | plain, whole System | substepped, whole System | substepped, store alone |
|---|---|---|---|---|---|
| 10 | 186 | 2 468 | 1 184 | 14 918 | 171 771 |
| 100 | 442 | 2 057 | 2 756 | 12 572 | 195 573 |
| 316 | 502 | 311 | 3 098 | 2 042 | 63 165 |
| 1e3 | 611 | 42 | 3 788 | 284 | 66 862 |
| 1e4 | 1 572 | 27 | 11 498 | 176 | 130 820 |
| 1e5 | 4 759 | 26 | 34 460 | 170 | 275 784 |

Plain Cash–Karp's steps grow with the store's stiffness, which goes
about as the square root of `K` in this System; substepped, they stay between
19 and 42 from `K = 1e3` up. Below `K = 316` the substepped run costs
more, because the second-order coupling error above forces a tolerance
of 1e-8 to 3e-10 on it to reach 1e-6. A System that names a subsystem
decides when it is weakly coupled, and this one says so at every `K`;
stiffness is not part of the test.

Each substep costs six evaluations of the subsystem's rates in each of
three passes (choosing, predictor, corrector), 18 per substep before
rejected attempts, so the store's own evaluations outnumber the whole
System's by a factor of 12 to 1 600 here, where the two cost about the
same. In plant the whole System is every cohort of every species and
the subsystem is the soil's layers. Timings are not given: these counts are
deterministic, and the toy's two kinds of evaluation do not weigh what
plant's do.

## Tests

`test-substeps.R`: ten tests, all passing on this branch (odelia 0.8.1
installed). With `substep_below` at zero the run is the plain System's, bit
for bit. Substepped at `K = 1e4`, a run takes under a tenth of plain
Cash–Karp's steps and ends within 1e-5 of the reference, within 1e-8
at tolerance 1e-9. Every row carries its slope and substeps, which land
on every stage fraction. Replays of the program, of the recording, and
at a parameter moved by 1%, take the run's substeps. A tangent replay
and the reverse sweep match central differences of the replayed
program. A run under pulses of inflow without stops matches one
stopped at each knot, with a substep on every knot. A grid of times,
and a row with its substeps dropped, are refused, as is a store whose
rates fail at every substep. `tests/standalone` passes under clang
(`all checks passed`) and compiles under GCC 13.3.
