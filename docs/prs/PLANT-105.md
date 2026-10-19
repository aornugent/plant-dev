# PLANT-105: TF24's soil substepped (with ODELIA-55)

Branches: plant `PLANT-105` on develop bd09645d; odelia `ODELIA-55` on master
1e0f0f0. Merge order: odelia first (0.8.1), then plant. Review:
`docs/prs/PLANT-105-review.md`.

## PR body (squash commit message)

TF24's soil sets every step of a run. Under heavy rain its top layer is stiff
(∂rate/∂θ down to −3.6e4 /yr), and on a variable rainfall record each one-day
hump of the cubic must lie inside one step, so a run either stops at every
knot with zero-depth pulses or misses the rain that falls between a step's
stages (17% low in `J` on the dry record). Either way every node in the stand
pays for the soil's steps.

The patch now names the soil as odelia's subsystem, whose rates read the
plants only through each layer's uptake. A Cash–Karp step that spans a knot
of the rain, or that starts with the plants taking less than
`Control$ode_soil_substep_max_uptake` of the water through the layers
(default 0: off), integrates the soil in substeps of its own while the plants
take the step's stages. Each step records its substeps. Replays, invaders
and the sweep take them as recorded, so the gradient is the gradient of the
run that was taken. A pinned schedule carries the records
(`ode_soil_input_slopes`, `ode_soil_substep_ends`). A schedule that drops
them is refused where a step spans a knot.

## First comment: the evidence

**Gain, long drought** (the 41-year stand from `harness/long_drought.R`, 108
introductions, tol 1e-4, one gradient run per arm, timed one at a time on this
branch; `scratchpad/dev/land/PLANT-105/measure/report.txt`):

| arm | steps | rows | forward | sweep | gradient run | `ln J` vs stops | worst census elasticity move |
|---|---|---|---|---|---|---|---|
| develop's way: knot stops, soil coupled | 15 376 | 838 614 | 145 s | 527 s | 673 s | — | — |
| no stops, share 0 (the default) | 7 313 | 380 974 | 78 s | 228 s | 305 s (0.45×) | −0.0013ε | 0.023 |
| no stops, share 0.1 | 6 370 | 339 691 | 60 s | 191 s | 251 s (0.37×) | +0.0026ε | 0.0056 |

Earlier evidence, from the archived stack:
- Share 0.1 against the coupled baseline: rows −41.5% and −44.8% on long
  drought and episodic, 0.63 of a gradient run, and every elasticity within
  0.063ε of the 1e-5 reference (`docs/design-soil-alone.md`, gates G4 and G6).
- Knot substeps against knot stops, across four records: rows 0.73–0.90, worst
  move 0.23ε (`docs/measurements/schedule-search/localised.md`, *The rain's
  knots*).
- Without stops or substeps, dry's `J` is 7.6ε low and its elasticities move up
  to 19ε (`round4/E`, E2).
- The soil's substeps cure the silent stiff-soil blow-up (elasticities up to
  2186 fall to 60.37) and take a long-drought run from 158 s to 77 s of CPU
  (`docs/measurements/schedule-search/loc/prereg.md`, *Root cause*).

**Cost:**
- Lines: odelia +580/−71 in headers (and `test-substeps.R`, 10 tests). plant
  +265/−117 by hand outside the generated RcppR6/RcppExports, and tests
  +230/−16.
- Every run's `instruction` grows by an optional record, about 0.4 MB per
  7 000 steps.
- A grid of times alone (`ode_times` without sizes) is refused across a step
  that would substep.
- The water-balance sums still follow the main step, so they miss the rain the
  soil takes between stages. On dry that is 3.1% of the rain. A run whose
  budget must close keeps the knot stops, and `test-tf24-water-budget.R` does.

**References moved:** the seasonal regime's 280 rows of
`tests/testthat/reference/reference-gradient.tsv` were re-captured with
`scripts/capture-reference-gradient.R` (seasonal only, spliced in). That regime
runs a cubic rain with no stops, so the forward model itself changed there.
The worst row moved 0.32 of its metric's largest column (2.theta on
leaf_area). Before the re-capture, 14 columns sat outside the reference's own
spread. The four constant-rain regimes are untouched. No other step sequence
moved: plant keeps GSL's step-size rule under odelia 0.8, and FF16's
bit-identity guard passes.

**Tests:**
- plant, full serial sweep on an installed `-O2` build: 5457 pass, 0 fail,
  11 skip.
- odelia, full suite: 729 pass and 2 errors. Both errors are in
  `test-ode-solver.R` lines from master's #77, an unqualified `OdeControl`
  that depends on suite order; that file passes alone.
- New in odelia (`test-substeps.R`), on a population over a stiff two-layer
  store:
  - with substeps off, the run is the plain System's, bit for bit;
  - substepped, it takes under a tenth of Cash–Karp's steps at the same
    accuracy;
  - program, recording and other-parameter replays repeat the run and its
    substeps;
  - the sweep and a tangent replay match central differences;
  - an unstopped pulsed run matches the knot-stopped one;
  - a grid, or a row with its substeps dropped, is refused.
- New in plant (`test-scm.R`):
  - a daily record without stops matches the stopped run (asserted within 2e-5 at tol 1e-5; measured 1.1e-6);
  - a substepped run replays bit for bit from its schedule and its
    parameters;
  - the sweep matches the tangent replay (1e-6) and central differences
    (1e-2);
  - grids and sizes without records are refused.

**For the reviewer:**
1. `ode_step_rkck.hpp`, `take_substepped_step`. The predictor's input slope
   comes from the last adaptive step. The corrector runs along the line to
   the inputs at the t + h stage. The error is the larger of the two passes'
   gap and the stages' input defect. All three are recorded on the row, so no
   replay recomputes them.
2. `step_by` refuses a row without substeps that spans a knot. A step
   substepped only because of the share (> 0) has no such check, and NEWS
   says to carry the records then (review Q2).
3. `make_node_schedule`'s events path still turns a program into a grid, as
   on develop. With records, it is now refused at a substepping step rather
   than run coupled.
4. The default share of 0 leaves only the knot trigger active. That trigger
   moves every run on variable rain without stops (the seasonal re-capture).
   Runs that keep their knot stops are unchanged.
