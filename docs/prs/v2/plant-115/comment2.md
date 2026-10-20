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

## The uptake fraction

A step that spans no knot is also substepped when, at its start, the
plants take less than `Control$ode_soil_substep_max_uptake` of the water
moving through the soil: Σ|uptake| / Σ(|inflow| + |drainage| + |uptake|)
over the five layers (`TF24_Environment::uptake_fraction_of_flows`).
The default, 0, turns this off. At 0.1 the synthetic record's stand
takes 4101 steps against 4793 and is 7.4e-5 off in ln J against 3.0e-6.
A step substepped for this reason has no knot to check against on
replay, so a run that uses it should carry its records.
