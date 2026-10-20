# How it works

## What the stages miss

The rain between two daily knots is a cubic, and a step's six stages
read it at six instants. One real step from the stand in comment 1, on
this branch:

![One 13.5-day step: the rain over it, the plants' six stage times and the soil's 60 substep ends, one on each knot](FIG:plant-115/step.png)

Weighted as the step's 5th-order solution weights its stages, the six
stage times see 3.8% of the rain that falls in this step; that is what
the base, run without stops, gave the soil. On this branch the soil is
integrated across the step on its own, in Cash-Karp substeps controlled
at a relative tolerance of 1e-9, ending on every knot and every stage
time, and the plants read the soil at their stages. The soil's rates
read the plants only through each layer's uptake, which is extrapolated
across the step along its trend since the last step, then corrected
toward the uptake at the step's end. Each step's slopes and substep
ends are recorded, so a replay, an invasion or the reverse sweep takes
the step exactly as the run did.

## How close it lands

![|ln J − ln J_ref| for the base without stops, knot stops and substeps, against knot stops at ode_tol 1e-7](FIG:plant-115/soil-accuracy.png)

On the synthetic record's stand at `ode_tol` 1e-4, against knot stops
at `ode_tol` 1e-7 (34 248 steps), substeps are 3.0e-6 off in ln J and
knot stops 6.8e-4; the base without stops is 0.30 off. On plant's
seasonal reference regime (rain 1 + sin 2πt m/yr, knots 7.6 days
apart, a 10-year stand) the base misses little, 3.1e-4, and all three
are inside 1e-3. The cost of the same runs is the figure in comment 1:
on the seasonal regime substeps take 0.69 of the steps and 0.64 of the
gradient run's CPU, but 1.07 of the stand's rate evaluations, since
they are rejected 424 times against knot stops' 91.

## Substepping where the soil holds the step back: an option

With `Control$ode_soil_substep = TRUE`, a step that spans no knot is
also substepped where the soil is what limits it: where the step is
past Cash–Karp's stability limit on the soil (the soil's stiffness,
read from the step's own last two rate evaluations, times the step
above 3.73), or where the soil's own error set the previous step and
the coupling error of substepping would have been smaller. odelia makes
that decision (aornugent/odelia#57); plant only switches it on.

On the synthetic record's stand (`ode_tol` 1e-4, gradient runs) it
takes 4039 steps against the knot trigger's 4793, and 206 287 rows
against 237 971 (13% fewer). ln J and every census elasticity stay
within a third of ε (0.025 in ln J) of a run stopped at every knot at
`ode_tol` 1e-5. On the seasonal regime it changes nothing (583 steps
against 586).

It is off by default because two checks assume the soil moves with the
main step. The water-balance sums (`sum_rainfall`, `sum_infiltration`,
`sum_drainage`, `sum_resource_depletion`) accumulate at the main step,
so with it on the budget closes to about 1e-5 relative, not 1e-12. And
the whole-run gradient references for the drought, shaded and clamped
regimes move. Turning it on by default would move those sums into the
soil's substeps (about 20 lines) and re-capture those references.

**For the maintainers:** keep it opt-in, or make it the default, in this
PR or a follow-up?
