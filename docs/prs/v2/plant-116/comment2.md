## How an invasion solves its own leaf

An invasion replays the resident's recording: its steps, and for each
rate evaluation the light environment and soil water the resident
produced there. On the base, the replay also handed each evaluation
the resident's leaf operating point, and TF24 used it in place of
solving the invader's own leaf. With odelia 0.8.2 the replay hands
each evaluation a copy of the recorded values instead
(aornugent/odelia#58). `Patch::store_solved` finds the resident's
light environment already in the copy and uses it, and each invader
solves its leaf and writes the result into the copy. The invasion's
own recording keeps the copies, so its reverse sweep differentiates
the leaves the invaders solved. The resident's recording is never
written, so two invaders in one call both replay the same resident.

## Why Newton converges linearly

The swept slope is exact for the steps a run took: at the equilibrium,
d ln J/d ln b is −0.741537 from the sweep and −0.741544 from a central
difference of runs held to the same steps. But each run in the loop
chooses its own steps, and those choices move with b. A central
difference of adaptive runs gives −0.7604, 2.5% steeper. Newton
therefore reduces |ln J − ln b| by a roughly constant factor each run,
about 50 near the end, rather than squaring it, and reaches 1e-8 in
seven runs. At `ode_tol` 1e-4 the residual stops falling near 1e-9,
the size of the runs' own noise.

![|ln J − ln b| for each run of Newton's method, at ode_tol 1e-4 and 1e-6](FIG:plant-116/newton.png)

## What an invasion refuses

The recording holds the resident's steps and the times it introduced
cohorts, and nothing about harvests or climate extremes. An invader
replayed through a resident run that had one would never experience
it, and an invader introduced at a time the resident introduced
nothing would never be introduced. `run_mutant()` now refuses both
before changing anything, with a message naming the cause. The
refusals are tested on FF16 in `test-mutant.R`.
