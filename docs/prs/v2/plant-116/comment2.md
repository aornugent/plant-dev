# How it works

## An invader's own leaf, in the resident's light and soil

TF24's rates hold one inner optimisation: each cohort's leaf settles at
the root-collar water potential that maximises its carbon profit, given
its traits, its light and its soil. A rare invader does not change the
light or the soil, so an invasion reads the resident's field at every
stage; but its leaf is its own, and its optimum moves with its traits.

The base solved nothing in an invasion. Its second pass loaded the
resident's recorded operating point at each stage
(`solve_leaf` → `replay_operating_point`), so an invader at another lma
ran with the resident's collar potential, and its reverse sweep
differentiated a leaf that never optimised. With odelia 0.8.2 the
second pass hands each stage a copy of the recorded row. The copy's
field is the resident's (`Patch::store_solved` finds `field.kept` and
reads it); the invader's strategies store their own solves into the
copy, and the invasion's sweep reads those rows.

The figure is the invader's fitness across lma multipliers 0.5 to 2, at
the resident's equilibrium birth rate, on both builds. The short
segments are the sweep's d ln R0'/d ln lma at {{NGRAD}} multipliers,
each drawn as a tangent.

![Invader fitness ln R0' against the lma multiplier, the resident's leaf (B105) against the invader's own (B95), with the sweep's gradient as tangents](FIG:plant-116/landscape.png)

{{LANDPROSE}}

## The birth-rate column, and why Newton converges linearly

The birth rate is a strategy field read through the `birth_rate`
driver. For a constant birth rate it is now also `birth_rate_`, at the
working scalar, the last entry of `ad_parameters()`, so the sweep's
column is dJ/db and `"<i>.offspring_production"` at a constant b gives
d ln J/d ln b = (b/J) dJ/db. A variable birth rate is a driver read as
a double and has no column.

At equilibrium J(b*) = b*. Newton in ln b on ln J − ln b steps
ln b ← ln b − (ln J − ln b)/(d ln J/d ln b − 1).

![Newton's |ln J − ln b| per run, at ode_tol 1e-4 and 1e-6](FIG:plant-116/newton.png)

{{NEWTONPROSE}}

## What the invasion refuses

An invasion is a replay of the resident's recorded program, which holds
its steps and its introductions and nothing else. Two inputs would be
skipped with every number finite, so `run_mutant()` now refuses them
before it changes anything: a resident run whose events include a
harvest or a climate extreme, which the replay would not apply to the
invaders, and an invader introduced at a time where the resident
introduced nothing (compared with `util::identical` against the
recording's insertion rows), which the replay would never introduce.
Both are tested on FF16 in `test-mutant.R`, since the refusal is in
`SCM` and not in TF24.

## What it costs

{{COST}}
