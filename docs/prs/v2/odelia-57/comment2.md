# How it works

## Two passes over the same substeps

A stage of the whole System needs the subsystem at the stage's time
before that stage has produced the inputs the subsystem reads. So the
step integrates the subsystem twice over one set of substeps. The
first pass holds the inputs on a line extrapolated along their slope
since the last step and hands each stage the subsystem at its time.
The second holds them on the line from the start's inputs to those the
stage at `t + h` produced, and gives the step's end. The two passes'
difference is the subsystem's error estimate; it measures the coupling,
which shrinks as h² where Cash–Karp's own error shrinks as h⁵.

## When a step substeps

At every knot of the forcing, since the stages cannot read between
knots. Elsewhere, only where the subsystem is what limits the step:
past Cash–Karp's stability limit on it (its stiffness, read from the
step's own last two evaluations, times h above 3.73), or where its own
error set the previous step and the coupling error would have been
smaller. Where the subsystem is not stiff, the h² coupling error would
make substepping cost more than plain steps, so the step stays plain.
An earlier version of this branch substepped wherever the System
reported the subsystem weakly coupled; the figure shows what that cost:

![Accepted steps against the store's stiffness for plain Cash–Karp, the earlier weak-coupling trigger and this one, at matched accuracy](FIG:odelia-57/steps_vs_stiffness.png)

## What a replay must carry

The input slope comes from the step before, and a replay of one step
has no step before it. So the run records the slope and the substep
ends on the step's row (`instruction::subsystem`), and every other pass
(a replay of the program, of a recording, at another scalar, and the
reverse sweep) takes both from the row. The sweep therefore
differentiates the step the run took; `test-substeps.R` checks the
sweep and a tangent replay against central differences. A grid of
times alone carries no substeps, so `step_to` refuses a step that would
substep, and `step_by` refuses a recorded row without substeps across a
knot.
