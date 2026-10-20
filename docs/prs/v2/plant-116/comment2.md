# How it works

## A copy of each recorded row

An invasion replays the resident's recording: its steps, and at every
stage the field (the light spline and the soil water) the resident
produced. The base's replay also loaded the resident's leaf operating
point at each stage (`solve_leaf` → `replay_operating_point`), so the
invader solved nothing. odelia 0.8.2's `advance_recorded(rec, true)`
hands each stage a copy of the row instead. `Patch::store_solved` finds
the copy's field already kept and reads it, and the invader's
strategies solve their own leaves and store them in the copy, where the
invasion's reverse sweep reads them. The recording itself is never
written, so two invaders in one call each read the same resident.

## Newton on the birth-rate column

For a species at a constant birth rate, `birth_rate_` sits at the
working scalar as the last entry of `ad_parameters()`, so the sweep's
`"1.birth_rate"` column of offspring production is dJ/db. At
equilibrium J(b*) = b*, and Newton in ln b takes
ln b ← ln b − (ln J − ln b) / (d ln J/d ln b − 1).

![Newton's |ln J − ln b| per run at ode_tol 1e-4 and 1e-6](FIG:plant-116/newton.png)

Convergence is linear, the last three runs each cutting |ln J − ln b|
about fifty-fold, because the swept slope is the slope of one run's own steps. At b*
(`ode_tol` 1e-6) it reads d ln J/d ln b = −0.741537, against −0.741544
from a central difference of runs pinned to those steps, and −0.760361
from a difference of adaptive runs, whose step sequences move with b.
That 2.5% predicts a contraction of 0.011 a run, near the 0.02 seen. At
`ode_tol` 1e-4 the residual stops falling near 1e-9, the runs' own
noise.

## What an invasion refuses

The recording holds steps and introductions and nothing else, so
`run_mutant()` now refuses, before changing anything, a resident run
with a harvest or climate extreme, which would not reach the invaders,
and an invader introduced where the resident introduced nothing, which
would never be introduced. The refusals are in `SCM` and tested on
FF16.
