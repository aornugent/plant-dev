## How a substepped step works

The fast part needs its inputs at every moment of the step, but the
rest of the System only computes them at its six evaluations. The
step therefore assumes the inputs change along a straight line, and
it integrates the fast part twice.

The first time, it extends the inputs along the trend they showed over
the previous step, and integrates the fast part with those. This gives
the fast part's value at each of the six evaluation times, so the rest
of the System can be evaluated as in any Cash-Karp step. Those
evaluations produce the inputs at the end of the step. The second
time, the step integrates the fast part with inputs on the straight
line from their value at the start to their value at the end, and
that result is the step's answer for the fast part. The difference
between the two results is its error estimate.

The straight-line assumption makes this error shrink with the square
of the step length, where a plain Cash-Karp step's error shrinks with
the fifth power. That is why plain steps are cheaper when the fast
part is not stiff, and why the solver substeps only when it has to.

## When a step uses substeps

A step that crosses a knot of the forcing always uses substeps,
because the six evaluations cannot see the forcing between knots, and
one substep ends on each knot. Any other step uses substeps in two
cases. In the first, the step is longer than plain Cash-Karp can take
stably on the fast part: the solver estimates the fast part's
stiffness from the last two evaluations of each step and compares it,
times the step length, with 3.73, Cash-Karp's stability limit. In the
second, the fast part's own Cash-Karp error was what limited the
previous step, and the straight-line error would have been smaller.
`OdeControl::substep_subsystem`, on by default, switches both off and
leaves only the knots.

## What a replay must repeat

The first integration uses the inputs' trend over the previous step,
and a replay of a single step, or the reverse sweep that computes
gradients, does not have the previous step. So each accepted step
records its input trend and the end time of every substep, in its
entry of the run's program (`instruction::subsystem`). A replay at
other parameters and the reverse sweep read them back and repeat the
calculation the run made, and the sweep therefore gives the gradient
of that calculation. `test-substeps.R` checks the sweep and a tangent
replay against central differences of the replay.

A replay given only the times of the steps has no record of the
substeps, so `step_to` refuses an interval where a step would use
them, and `step_by` refuses a recorded step that crosses a knot but
has no substeps recorded. Only `method = "rkck"` takes substeps.
