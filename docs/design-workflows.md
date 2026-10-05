# Design: evolutionary analyses across regnans, odelia and plant

The goal is `OBJECTIVES.md`, carried from TF24's runs into the analyses regnans
builds from them: a resident at demographic equilibrium, invasion fitness and
its landscape, the selection gradient, singular strategies and their
classification, and assembly. regnans (`traitecoevo/regnans` 56ad241) runs each
analysis through a harness of six connectors and takes every derivative by
finite differences. plant runs TF24 on the birth-date coordinate with splits at
sign changes, walks invaders on a resident's recorded run and sweeps either.
odelia steps, records and sweeps.

Status: a proposal, nothing built. Measured for it: the stand at its
equilibrium (`docs/measurements/equilibrium/`). The grid controller
(`docs/design-grid-controller.md`) is the design for one run; this one is the
design for the analyses that string runs together.

## What regnans does today

- *Every analysis reaches plant through six connectors* (`R/harness.R`):
  parameters, a demography runner (`b ↦ J(b)`), its cleanup, the viable bounds,
  an inviability check, and a fitness function (mutant traits ↦ `ln R′` on the
  resident's recorded run). The toy harnesses (DD99, GK98, GM99, JJ12, DD99 in
  k dimensions) implement the same six with closed forms, and carry the 401
  tests that validate the solvers against analytic answers.
- *Every derivative is a difference.*
  - The selection gradient is a central difference of the fitness function at a
    relative step of `1e-4`: `2k` mutants and the resident's own traits in one
    walk (`community_selection_gradient`).
  - The mutant Hessian takes `1 + 4k²` mutants, Richardson-extrapolated over two
    steps (`util_hessian`).
  - The convergence Jacobian takes `2k` selection gradients at perturbed
    residents, each with its own equilibrium (`util_jacobian`).
  - Singular strategies are roots of the selection gradient: `uniroot` in one
    trait, `nleqslv` or `dfsane` in k.
- *The equilibrium's default is iteration,* `b ← J(b)` to a relative change of
  `1e-5` (`equilibrium_iteration`), with root-finders on `ln b` available.
- *Its plant bridge does not run on the plant this work builds* (checked against
  `PLANT-103` by `docs/measurements/equilibrium/seam.R`):
  - the fitness function calls `run_scm(use_ode_times =)`, an argument plant no
    longer takes, so it errors whenever there is a resident;
  - it sets `ctrl$save_RK45_cache`, which plant no longer has; the assignment
    succeeds and does nothing;
  - the runner refines the node schedule on every call, which plant refuses on
    the birth-date coordinate, the only one its sweeps run on;
  - no environment or events reach `run_scm`, so TF24 would run without its
    rainfall record;
  - `community_reset` clears the node schedule whenever residents change, so
    every candidate in a search starts from the default schedule.
- *regnans holds no events, no adjoint and nothing like the splits.* Its tests
  run plant's FF16, on the height coordinate, at a patch lifetime of 30.

## Triage: 3

The seam is two public APIs with users and an upstream on each side: regnans's
harness and plant's `run_scm`, `run_mutant` and `stand_gradient`. And the
requirement arrived as mechanisms: exact derivatives, shared grids.

## Requirements ledger

- **R1, runs on this plant:** every regnans analysis answers on TF24 with
  plant's sweeps available. Today none does (the five failures above). The toy
  harnesses keep their 401 tests.
- **R2, accurate** (`OBJECTIVES.md`): `ln J` within 0.025; each elasticity
  within its ε (resident `lma` 0.087, `a_dG2` 0.019; invader `lma` 0.20, `a_dG2`
  0.050; never under 0.01); `lma`'s curvature within 1.16 (resident) and 4.0
  (invader). For regnans's own answers, derived:
  - `b*` to `|ln J(b*) − ln b*| < 1e-5`, regnans's own setting, kept because a
    secant pays about one run for its last two decades;
  - a singular strategy to `|g|` below the selection gradient's own error
    estimate, since a root finer than that is noise.
- **R3, stable** (the four tests), and smooth enough for regnans's
  root-finders to converge. The secant on adaptive runs reached
  `|f| = 5.4e-8` with no sign of noise.
- **R4, shared:** one grid per local analysis around a resident, the resident
  within ±10% of the grid's θ₀, rebuilt on big moves. Measured at a birth rate
  of 1: one uniform 108-node grid at `1e-4` holds every elasticity within ε over
  `lma` ×0.95–×1.1. Unmeasured at `b*`, and for the invader.
  - *Challenged upward:* on a singularity search the shared grid buys 7% of
    runtime and, for the resident's curvature at a perturbation of `1e-2`,
    0.16ε of consistency (adaptive −43.67 against pinned −43.86,
    `eps-spread.md`). Is one grid an outcome you want for itself, every answer
    of an analysis a derivative of one function, or a means to accuracy and
    cost? If a means, the floor below suffices and the grid waits.
- **R5, performant:** the least runtime at ε. Measured on long drought, 40
  years, 108 nodes, `1e-4`, splits on, in forward runs at `b*` (91 s, adaptive):
  - a replay of the resident's own recorded program 0.82 of a forward (74 s),
    since it attempts none of the 3 461 steps the adaptive run rejected;
  - the stand's sweep 2.9, a walk 0.77, an invader's sweep 2.2, so a walk and its
    sweep 3.0;
  - the equilibrium from `b = 1`: a secant on `ln J − ln b` in `ln b`, 6 runs to
    5.4e-8. Iteration contracts by 0.76 a run, alternating in sign: 8 runs reach
    0.35, and about 47 would reach 1e-5;
  - regnans's counts: a singularity in one trait about 10 candidates; a
    classification `1 + 4k²` walk members and `2k` equilibria; an assembly step
    54 walk members for the landscape and 10–20 for the maximum.
- **R6, diagnosed:** every answer reports its error estimate, its distance from
  its grid's θ₀ against the radius, and its failures.
- **R7, the traits evolving in one analysis, k:** unknown — ask. regnans's
  plant tests evolve one (`lma`); its k-dimensional solver and toys two.
  - Hanging on it: in the mutant direction a difference costs `2k + 1` walk
    members, the resident's own traits among them, against a walk and its sweep
    at 3.0 forwards. Differences are cheaper at k = 1 (2.3 against 3.0) and the
    sweep from k = 2 (3.8 against 3.0).
  - *Challenged upward:* is a plant analysis evolving two or more traits
    planned? If not, the sweep enters regnans's answers, not its loops.
- **R8, invariants:** only doubles cross into R (`AGENTS.md`); fitness and
  equilibrium live in regnans, not plant (plant `NEWS` #388); regnans's
  harness stays model-agnostic.

**Scarce resource: resident runs spent reaching equilibrium.** Each candidate
in a search needs its `b*`: 6 runs cold, about 3 warm, against 2.3 forwards for
its gradient. A search makes about ten candidates and a classification `2k`
more. Iteration would multiply the first term by about 8.

**The reference analysis,** by which the designs below are priced: a singular
strategy found from regnans's bounds, then classified, in forward runs at `b*`
(`docs/measurements/equilibrium/costs.R`). Assumed: ten candidates in one trait
and fifteen in two, two in five outside any radius; 3 runs for a warm
equilibrium; a warm candidate starting 0.4 off in `ln J − ln b` (a 5% move at an
elasticity of 8), a perturbed resident 8e-3 (regnans's step of `1e-3`).

| forward runs at `b*` (hours) | one trait | two traits |
|---|---|---|
| regnans as it stands, iterating each equilibrium | 530 (13.3) | 860 (21.6) |
| the floor: a secant, adaptive runs, differences | 80 (2.0) | 161 (4.1) |
| B: the grid replayed inside its radius, differences | 74 (1.9) | 151 (3.8) |
| B with the sweep for every gradient | 85 (2.1) | 133 (3.3) |

The equilibrium's solver is the lever: 6.6× in one trait. The grid takes 7%
more off it, and the sweep in the loops costs 15% in one trait and saves 12% in
two.

## The floor

regnans's plant bridge made to run on this plant, and nothing else. Each
connector passes the environment and events; node times are given, never
refined; every run of the runner keeps its record, and the fitness function
walks the last; differences as today; the log-scale root-finder as the default
equilibrium for plant.
- Meets R1, R2 as far as plant's grid does, and R3: the secant converges on
  adaptive runs.
- Fails R4 on the steps: every run chooses its own, so no grid serves an
  analysis. Leaves R6's error estimate unbuilt. Leaves 18% of every run inside
  a radius (74 s against 90).
- Costs 80 forwards on the reference analysis in one trait, against 530 for
  regnans's iteration.

## Candidates

- **A [first thought]: every derivative regnans takes of plant is a sweep**
  (move 6: one mechanism for regnans's difference stencils).
  - A connector returns `∂ ln R′/∂ ln θ′` for each mutant row over every
    parameter, from one walk and one sweep: the census sums over species and
    invaders do not interact, so one sweep gives each its own gradient. Hessian
    rows are chords of it, and the resident's sweep gives `d ln b*/dθ` by the
    implicit function theorem for the Jacobian's equilibria.
  - *Pays for* R2's elasticities on all 50 parameters (3.0 forwards, against
    about 78 by differences) and R7 from k = 2 (12% of the reference analysis).
  - *Costs* a connector, plant composing its gradients through the
    hyperparameterisation for regnans's traits, and at k = 1 15% more on the
    reference analysis. Pays nothing toward R4 or R6.
  - *Wins* when two or more traits evolve, or every candidate must report every
    parameter's gradient.
- **B: one recorded resident per local analysis, replayed by every run inside
  its radius** (move 2: record once, replay).
  - A resident's equilibrium runs adaptively, and its last run is kept: its
    node times, its accepted program, the traits and birth rate it ran at, and
    the record invaders walk. Inside the radius every later run replays that
    program: the Jacobian's perturbed residents, chords, nearby candidates'
    equilibria. Outside it, the next equilibrium builds the next grid.
  - *Pays for* R4 by construction, R6's distance (there is now a θ₀ to be far
    from), R5's 18% on every run inside a radius (7% of the reference
    analysis), and R1, since nothing in a loop refines.
  - *Costs* the grid carried through regnans's community, and a radius per
    trait and in `ln b`, measured only for `lma`: ×0.95–×1.1 at a birth rate of
    1, and a 1% move at `b*` held to 1.4e-5 in `ln J`.
  - *Wins* when analyses differentiate over the resident (Jacobians, curvature
    rows) or search inside a radius.
- **C: independent evaluations forked across cores** (move 7: batch the
  population).
  - regnans's fitness function already takes a batch of mutants. The plant
    harness splits each batch across forked processes, which share the recorded
    resident copy-on-write; the Jacobian's `2k` perturbations run likewise.
  - *Pays for* R5 in wall-clock: the 54-mutant landscape, 43 forwards, in about
    11 on four cores.
  - *Costs* memory per fork, about 0.45 GB for a recorded run. Nothing changes
    in regnans.
  - *Wins* for assembly, where the landscape is most of each step, on a machine
    with cores to spare.

**Winner: B,** with C as a part of B's harness and A as its answers' report.
- *A* costs 15% at k = 1 and pays neither R4 nor R6. Its sweep earns its keep
  where differences cannot follow: every parameter's gradient at an answer, once
  per analysis. From k = 2 it saves 12%, and the kill condition hands the loops
  to it.
- *C* pays wall-clock only for batch-shaped work and leaves R4 and R6 unpaid. It
  needs no commitment of its own, so it rides in B's harness.

## The commitment

**A grid is built only by a resident's equilibrium, and every run inside its
radius replays it.**

Kept true by:
- the plant harness's runner has one call to `run_scm`, which passes the held
  program when the community's traits and birth rates are inside the radius of
  the grid's and nothing otherwise;
- the grid is replaced in one place, the cleanup after an equilibrium, from the
  run the equilibrium ended on;
- regnans's generic code no longer touches the schedule: `community_reset`
  stops clearing it, and the harness alone decides when a grid is stale.

## Kill question

The assumption whose falsity makes this unnecessary: that runs inside one local
analysis, each choosing its own steps, differ by enough to matter.
- In consistency they barely do: 0.16ε for the resident's curvature at `1e-2`,
  and the secant converges on adaptive runs to 5.4e-8.
- In cost they do: a replay attempts no step it would reject, 74 s against
  90 s, which is 18% of every run inside a radius and 7% of the reference
  analysis.
- And R4 asks for it in so many words.

Survives, on R4 and R5, not on accuracy. If the challenge to R4 comes back "a
means", the floor wins and B is deferred to the day a radius holds many
evaluations.

## What survives deletion

- *the grid:* plant's own `node_schedule_times`, `ode_times` and
  `ode_step_sizes`, with the traits and birth rate it was built at: R4, R5, R6;
- *a radius per trait and in `ln b`:* R4, R6. `lma`'s is measured at `b = 1`;
  until the others are, ±5%;
- *the secant in `ln b`:* R5, 6 runs against about 47;
- *the record kept on every equilibrium run:* R5, since the last one is walked
  and no run is repeated to record it (+4.6% per run against a whole run);
- *the answer's sweeps,* the stand's and its own invader's, once per analysis:
  R2, every parameter's elasticity, and with the secant's slope
  `d ln b*/d ln θ = −e/f′` for every θ;
- *a companion analysis at a looser setting:* R6's error estimate;
- *forked batches:* R5's wall-clock.

*Deleted:* refining the schedule on every runner call; `community_reset`'s
reach into the model's support; the run repeated in the fitness function to
record; `save_RK45_cache` and `use_ode_times`. *Not built:* the sweep inside
the loops, until a plant analysis evolves two or more traits.

## What this settles

- *plant and odelia need nothing new.* Replaying a program
  (`p$ode_times` with `p$ode_step_sizes`), keeping a record
  (`record_trajectory`), walking invaders on it (`run_mutant`) and sweeping
  either (`stand_gradient`) exist, splits included. The work is in regnans's
  plant harness.
- *No refinement inside any loop.* FF16 on the height coordinate refines once
  per grid, TF24 on the birth-date coordinate is given its node times.
- *One function per local analysis:* a selection gradient, a Hessian and a
  Jacobian taken around one resident differentiate the same discretisation.
- *A mutant's birth rate never reaches a sweep.* regnans's mutants enter at a
  birth rate of 0, where offspring production and its gradient are zero; the
  answer's report walks its own invader at 1, where `J′ = R′`.

## What this makes hard

- *A search whose candidates leave the radius every step* rebuilds a grid each
  time and pays the floor's cost. Cope: nothing; that is brute force, and it is
  correct.
- *A landscape wider than the invader's radius,* which is unmeasured over
  ×0.5–×2. Cope: several grids, one per stretch of the landscape.
- *Memory:* every equilibrium run keeps its record, 0.45 GB at 40 years, one at
  a time. Over an assembly regnans keeps every step's community in its history,
  and each community's fitness function holds its resident's record. Cope: the
  history keeps a community's grid and drops its record.
- *The evolving traits' derivatives stay differences at k ≤ 2,* with their step
  a knob. Cope: the step is set once against the sweep, which the answer's
  report computes anyway.
- *A replay at a moved θ has no error control.* A step near a pool's stability
  limit at θ₀ can fail within the radius. Cope: the radius is measured with the
  four tests, "never fails" among them.

## Kill condition

- *Two or more evolving traits in a plant analysis:* the selection gradient
  moves to the sweep, A's "wins when". The commitment survives it, since the
  sweep runs on the same record.
- *A model whose recorded program cannot be replayed even ±5% from θ₀:* no
  radius exists, and the floor's adaptive runs take over.

## The design

### The workflows, run by run

1. **Equilibrium, cold:** a secant on `f(x) = ln J(e^x) − x` from the starting
   birth rate and the iteration's first step; adaptive runs on the given node
   times, each keeping its record. The run it ends on becomes the grid and the
   record invaders walk. 6 runs from `b = 1` on long drought.
2. **Equilibrium, warm** (a candidate inside the radius): the birth rate
   extrapolated from the last two candidates' `b*`, then the secant on replays.
3. **Selection gradient:** regnans's difference, `2k + 1` walk members on the
   record, while one trait evolves.
4. **Singular strategy:** regnans's root-finders as they are, stopped at the
   selection gradient's own error estimate rather than `1e-6`.
5. **Classification:**
   - the mutant Hessian by walks on the singular resident's record;
   - the Jacobian by chords of the selection gradient at the resident moved
     ±h on replays. Each side first replays at `b*` to read `f₊`, then once
     more at `b* exp(−f₊/f′)`, with `f′` the secant's last slope; the
     equilibrium's error left, `O(h²)`, cancels in the chord.
6. **Landscape and maximum:** walks of the record, the batch forked across
   cores.
7. **Assembly:** the same steps for each species added. A new species is a new
   community, so its equilibrium builds a new grid.
8. **The answer's report:** at the final resident, the stand's sweep (every
   elasticity, and `d ln b*/d ln θ = −e/f′` for every parameter) and its own
   invader's (every parameter's selection gradient), about 7 forwards once.
9. **The error estimate:** the final analysis repeated on a companion grid at
   the looser setting, `tol` doubled, reported beside each answer.

### The seams

- *regnans's six connectors stay.* The plant harness's `model_support` gains the
  environment, the events and the grid; its runner and cleanup implement the
  commitment; its fitness function walks the kept record. One connector is
  added for the answer's report, which the toy harnesses implement by
  difference over their traits.
- *plant:* no change. The answer's report reads `stand_gradient` after the
  resident's run and after its own invader's walk.
- *odelia:* no change. The one inefficiency found below, the split's sweep
  rebuilding the light field on the tape, is a plant item already on the list.

### Work items, one issue each on `aornugent/regnans`

1. The plant harness on this plant: the environment and events through
   `model_support`, node times given, records kept, the fitness function walking
   the last run, the assembler's history keeping no record (R1). With a TF24
   smoke test, at the shortest lifetime where the stand reproduces, beside the
   FF16 ones.
2. The secant as the plant harness's equilibrium, warm starts extrapolated from
   the previous candidates (R5).
3. The grid: held, replayed inside its radius, rebuilt outside, its distance
   reported (R4, R6); `community_reset` leaves the schedule to the harness.
4. The answer's report (R2), with `d ln b*/d ln θ`.
5. The companion error estimate, and the singularity's tolerance and the
   classifier's degeneracy test taken from it (R6).
6. Forked batches in the plant harness's fitness function (R5).

Measurements before 3: the resident's radius at `b*`, in its traits and in
`ln b`, and the invader's over ×0.5–×2.

## The splits, against regnans, dust2 and the references

The user asked whether regnans holds anything like the splits, how they
compare with dust2's events, and whether the implementation is lean. A
survey of nine libraries' source backs what follows.
- *regnans holds nothing like them.* It has no events, no adjoint, and no step
  of its own.
- *dust2's events* (`inst/include/dust2/continuous/solver.hpp`) are the same
  idea as everyone else's, not ours:
  - each event's test is read on the DOPRI5 dense output at the step's two ends
    only, so two crossings inside one step are missed;
  - its root is found by Brent's method to `1e-6`, the whole state is
    interpolated there, the action applied, and the step cut short;
  - continuous-time events have no adjoint at all: dust2's adjoint is in the
    discrete-time system only.
- *Everyone else makes the root a step boundary for the whole system* (CVODES
  with AMICI, SciML, dust2, PETSc, de Roos's EBTtool) or ends the solve there
  (torchdiffeq, Diffrax). Measured here, stopping the global step at each
  crossing costs 3.4× the member evaluations and its error in `J` does not
  converge, against +5.4% for a split per node. TF24 splits 9 247 node steps in
  40 years at `b = 1` and 10 841 at `b*`.
- *The nearest precedent is multirate Runge–Kutta:* Fok (J Sci Comput 66, 2016)
  re-integrates flagged components of an accepted Cash–Karp step with the rest
  read from an interpolant, and Savcenco, Hundsdorfer and Verwer (BIT 47, 2007)
  refine only the components whose error exceeds the tolerance. Both are
  triggered by error estimates, not by sign changes. No code was found that
  splits one component's step at its own sign change, with or without an
  adjoint.
- *Detection.* CVODES, Diffrax and dust2 compare signs at the step's ends;
  SciML also samples ten points on the interpolant. Ours reads the ends, then
  the stages' sign values, which the step computed anyway, then searches at
  most four values beside a reading near zero, so a pair inside a step costs
  nothing where nothing is near zero.
- *Location:* Illinois regula falsi on the dense output, as CVODES does; SciML
  and dust2 use Anderson–Björck and Brent.
- *The cut's derivative* is the implicit function theorem's
  `dτ/dθ = −(∂P/∂θ)/(dP/dt)`, as in torchdiffeq, Diffrax, AMICI and SciML: one
  derivative of `P` per cut, which is minimal. With `P⁺` continuous, the
  classical jump `(f⁺ − f⁻)·dτ/dθ` is zero, as AMICI's update is.
- *Positivity schemes* (modified Patankar Runge–Kutta, clipping, projection)
  keep states non-negative, a different problem from a kink in the rates. Our
  `P⁺ = ½(P + √(P² + ε²))` is the standard Chen–Harker–Kanzow–Smale smoothing
  of the plus function.

**Is it lean?** Every field a split records is read by the sweep: the cuts and
their slopes by the implicit function theorem, the ratings at the cuts and the
pieces' ratings to replay them, and the end before the split to rebuild the
dense output. A split costs 5.4% of a forward against none; recording for the
sweep adds 0.6% of arithmetic, the slopes and the record, and 4.6% of wall
time when rows are kept, by a route not traced (`sweep_profile.txt`).
- *One inefficiency:* the split's sweep costs +14.7%, and 90% of that is the
  whole light field rebuilt on the tape at each piece's rating. The forward
  already rebuilds only what a part reads; the sweep should too.
- *One alternative, already tested:* the survey's own suggestion, each piece on
  its one-sided branch of `P⁺`, as AMICI's Heaviside helpers do, so the sweep
  could hold the cuts. It is the eleventh extension's one branch per side
  (`grid-dynamics.md` §18). It changes the rates: `ln J` moves by −1.5e-3, and
  the curvature moves 8.2ε between `r = 1e-2` and `1e-3`, against 0.54ε with
  the smooth positive part. So the smooth part stays and the cuts move.
