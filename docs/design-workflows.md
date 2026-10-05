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
equilibrium (`docs/measurements/equilibrium.md`). Its candidates were judged by
a second, blind review with kill authority, which overturned the first draft's
winner (a grid replayed inside its radius) for the floor; the arithmetic below is
the corrected one. The grid controller (`docs/design-grid-controller.md`) is the
design for one run; this one is the design for the analyses that string runs
together.

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
    longer takes, so it errors with a resident and without one, and the viable
    bounds with it;
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
  plant's sweeps available. Today none does (the five failures above). regnans's
  suite keeps passing: 401 tests at 56ad241, its FF16 smoke tests among them.
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
  - *Challenged upward:* every invader-side quantity already shares its
    resident's grid, since a walk takes the recorded steps. What one grid adds
    is the moved residents' steps: 1–6% of the reference analysis, and 0.16ε of
    consistency in the resident's curvature at `1e-2` (adaptive −43.67 against
    pinned −43.86, `eps-spread.md`). Is one grid for moved residents an outcome
    you want for itself, or a means to accuracy and cost? As a means, the floor
    below suffices.
- **R5, performant:** the least runtime at ε, read here as wall-clock on the
  4-core machine every run used (challenged upward: on a cluster, or in CPU
  hours, the forks below buy nothing). Measured on long drought, 40 years, 108
  nodes, `1e-4`, splits on, in forward runs at `b*` (91 s, adaptive):
  - a replay of the resident's own recorded program 0.82 of a forward (74 s),
    since it attempts none of the 3 461 steps the adaptive run rejected;
  - the stand's sweep 2.9, a walk 0.77, an invader's sweep 2.2, so a walk and its
    sweep 3.0;
  - the equilibrium from `b = 1`: a secant on `ln J − ln b` in `ln b`, 6 runs to
    5.4e-8. Iteration contracts by 0.76 a run, alternating in sign: 8 runs reach
    0.35, and about 47 would reach 1e-5;
  - regnans's counts: a singularity in one trait about 10 candidates, each
    started from `b = 1e-3`; a classification `1 + 4k²` walk members and
    `2k + 1` equilibria, the singular resident's solved again; an assembly step
    54 walk members for the landscape and 10–20 for the maximum.
  - *Every measurement here moved `lma` alone.* regnans moves it through the
    hyperparameterisation, along which the stand's elasticity at `b*` is −5.9,
    not −9.96.
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
in a search needs its `b*`: 6 runs cold, about 4 warm, against 2.3 forwards for
its gradient. A search makes about ten candidates and a classification `2k`
more. Iteration from regnans's `1e-3` would take about 51 runs for each.

**The reference analysis,** by which the designs below are priced: a singular
strategy found in regnans's bounds, then classified, in forward runs at `b*`
(`docs/measurements/equilibrium/costs.R`). Assumed: ten candidates in one trait
and fifteen in two, two in five far from the last; a near candidate starting
0.30 off in `ln J − ln b` (a 5% move along the hyperparameterisation); a moved
resident 5.9e-3 off (regnans's step of `1e-3`). The secant's runs follow from
its measured convergence; iteration's from its measured contraction.

| forward runs at `b*`, wall-clock (hours) | one trait | two traits |
|---|---|---|
| regnans as it stands, iterating each equilibrium from `1e-3` | 608 (15.3) | 976 (24.6) |
| the floor: a secant, warm starts, adaptive runs, differences | 84 (2.1) | 166 (4.2) |
| the floor, its walks and moved residents forked over 4 cores | 60 (1.5) | 103 (2.6) |
| B: near candidates and moved residents replayed | 79 (2.0) | 159 (4.0) |
| B, the moved residents alone replayed | 83 (2.1) | 165 (4.1) |
| the floor with a sweep for every gradient (A) | 95 (2.4) | 147 (3.7) |

The equilibrium's solver is the lever: 7.3× in one trait. Forking takes 28–38%
more off; the grid 1–6%; a sweep in the loops costs 13% in one trait and saves
11% in two. None includes the answer's report (about 7 forwards) or the
companion, which every design pays alike.

## The floor

regnans's plant bridge made to run on this plant, and the equilibrium solved by
root-finding, and nothing else.
- *The bridge:* each connector passes the environment and events; node times
  are given, never refined; every run of the runner keeps its record, and the
  fitness function walks the last.
- *The equilibrium:* a secant on `f(x) = ln J(e^x) − x`. From a cold start its
  first move is the iteration's, `b ← J(b)`, and every move is held to `e^±3`;
  from a previous `b*`, its second point is a Newton step on that solve's last
  slope. regnans's own `nleqslv` and `dfsane` paths each reach the same `b*` in
  12 runs, against the secant's 6 (P8, P9).
- *Derivatives* are regnans's differences, as today. The Jacobian's two sides
  each take one run at `b*` to read `f₊` and one at `b* exp(−f₊/f′)`; the
  equilibrium's error left, `O(h²)`, cancels in the chord.
- Meets R1, R2 as far as plant's grid does, and R3: the secant converges on
  adaptive runs.
- *Meets R4 for every invader-side quantity:* a walk takes the resident's
  recorded steps, so a landscape, a selection gradient and a mutant Hessian
  around one resident already share its grid. Only moved residents, the
  Jacobian's, choose their own steps: 0.16ε apart at a perturbation of `1e-2`.
- Leaves R6's error estimate unbuilt. Its distance is an invader's from the
  resident whose record it walks, against the invader's radius, which is
  unmeasured; every resident run is its own grid.
- Leaves wall-clock on the table (the forks below).

## Candidates

- **A [first thought]: every derivative regnans takes of plant is a sweep**
  (move 6: one mechanism for regnans's difference stencils).
  - A connector returns `∂ ln R′/∂ ln θ′` for each mutant row over every
    parameter, from one walk and one sweep: the census sums over species and
    invaders do not interact, so one sweep gives each its own gradient. Hessian
    rows are chords of it, and the resident's sweep gives `d ln b*/dθ` by the
    implicit function theorem for the Jacobian's equilibria.
  - *Pays for* R2's elasticities on all 50 parameters (3.0 forwards, against
    about 78 by differences) and R7 from k = 2 (11% of the reference analysis).
  - *Costs* a connector, plant composing its gradients through the
    hyperparameterisation for regnans's traits, and 13% more on the reference
    analysis at k = 1. Today a sweep after a walk of several invaders fails in
    plant, so "one walk and one sweep" needs plant's fix first.
  - *Wins* when two or more traits evolve, or every candidate must report every
    parameter's gradient.
- **B: one recorded resident per local analysis, replayed by every run inside
  its radius** (move 2: record once, replay).
  - Inside the radius every later run replays the program the resident's
    equilibrium ended on: the Jacobian's moved residents and nearby candidates'
    equilibria. Outside it, the next equilibrium builds the next grid.
  - *Pays for* R4's letter for moved residents, R6's distance, and 18% of every
    replayed run.
  - *Costs* the grid carried through regnans's community and a radius per trait
    and in `ln b`, measured for neither at `b*`: a near candidate moves `ln b*`
    by 0.16–0.28, and every replay here held `b*`. A replay has no error
    control: at every θ ≠ θ₀ a pinned θ₀ program's steps ran 6.3–12.3 times over
    the tolerance, with up to 317 stages outside the model's domain
    (`perf-across-theta.md`, before the splits).
  - *Wins* when moved residents' own step choices cost more than ε/3, or when
    one grid is wanted for itself.
- **C: independent evaluations forked across cores** (move 7: batch the
  population).
  - The walk members of each selection gradient and Hessian, and the Jacobian's
    moved residents, run side by side in forked processes, which share the
    recorded resident copy-on-write. regnans's fitness function already takes a
    batch of mutants.
  - *Pays for* R5 in wall-clock: 28% of the reference analysis in one trait, 38%
    in two, on four cores; the 54-mutant landscape in about 10.4 forwards
    instead of 41.6.
  - *Costs* memory, 0.45 GB a recorded run per fork. Nothing in regnans's
    generic code.
  - *Wins* on any machine with cores to spare, which every measurement here had.

**Winner: the floor, with C's forks as a part of its harness and a companion
estimate for R6.** This is the blind review's verdict; the first draft had
picked B.
- *A* costs 13% at k = 1 and pays neither R4 nor R6. Its sweep earns its keep
  where differences cannot follow: every parameter's gradient at an answer, once
  per analysis. From k = 2 it saves 11%, and the kill condition hands the loops
  to it.
- *B* saves 6% if nearby candidates' replays hold, which no measurement shows,
  and 1% on measured ground: the Jacobian's replays. What it pays for, R4 for
  moved residents, is worth 0.16ε at `1e-2`, and it gives up error control.
- *C* is no commitment and needs none: it is the floor's harness running side by
  side what it would otherwise run in turn.

## The commitment

**The record every invader walks is the run its resident's equilibrium ended
on.**

Kept true by:
- the plant harness's runner keeps the record of every run and returns its last;
- the fitness function closes over that run and has no `run_scm` of its own, so
  no resident is run again to be recorded;
- the cleanup that writes `b*` back is the cleanup that hands the record on.

## Kill question

The assumption whose falsity makes the commitment unnecessary: that which run
invaders walk matters.
- It saves a run per candidate, the one regnans repeats to record: 13 runs, about
  15% of the reference analysis in one trait.
- It removes a mismatch: regnans walks a run of the community's parameters made
  after the equilibrium, on a grid the equilibrium did not run.

Survives.

**The floor's open question,** which decides whether B returns: are adaptive
runs smooth enough at regnans's own Jacobian step, `1e-3`? At `1e-2` they sit
0.16ε from replays. If that is step-choice noise growing as `1/D`, it is about
1.6ε at `1e-3`. Unmeasured, and the first measurement below. The convergence
Jacobian has no ε of its own yet; the resident's curvature's, 1.16, stands in.

## What survives deletion

- *the record kept on every equilibrium run, the last one walked:* R5 (a run a
  candidate) and R3 (one function walked);
- *the secant in `ln b`,* with its cold first move and its `e^±3` hold: R5, 6
  runs against 12 for `nleqslv` or `dfsane` and about 47 for iteration;
- *warm starts* from the previous `b*` and its slope, in regnans's one-trait
  search too: R5, 4 runs against 6;
- *the Jacobian's two runs a side, and the singular resident's equilibrium
  reused:* R5;
- *forked batches:* R5's wall-clock;
- *the answer's sweeps,* the stand's and its own invader's, once per analysis:
  R2, every parameter's elasticity, and with the secant's slope
  `d ln b*/d ln θ = −e/f′` for every θ;
- *a companion analysis at a looser setting:* R6's error estimate.

*Deleted:* refining the schedule on every runner call; `community_reset`'s
reach into the model's support; the run repeated in the fitness function to
record; `save_RK45_cache` and `use_ode_times`; the classifier's second solve of
the singular resident. *Not built:* B's replays, until the kill question says
otherwise; the sweep inside the loops, until a plant analysis evolves two or
more traits.

## What this settles

- *plant needs one fix and odelia none.* A sweep after a walk of several
  invaders fails today (`PLANT-95`'s rebind of a walked patch,
  `measurements/equilibrium.md`), which the report does not need and A does.
  Otherwise everything exists: records (`record_trajectory`), walks
  (`run_mutant`), sweeps (`stand_gradient`), splits. The work is in regnans's
  plant harness and in two generic places, the equilibrium's solver and the
  classifier.
- *No refinement inside any loop.* FF16 on the height coordinate refines at a
  new resident, TF24 on the birth-date coordinate is given its node times.
- *A mutant's birth rate never reaches a sweep.* regnans's mutants enter at a
  birth rate of 0, where `R′` is read per capita and offspring production, the
  census plant sweeps, is zero; the answer's report walks its own invader at 1,
  where `J′ = R′` (P13).

## What this makes hard

- *The Jacobian at small steps,* if adaptive runs' own step choices dominate
  there. Cope: regnans's step at `1e-2`, where the chord is measured, or B's
  replays for the moved residents.
- *Invaders stay unsplit.* At the stand's own traits the walk is −7.6e-5 off the
  stand's `J/b` (0.003ε of `ln J`, P12); a walk that split would need fields
  at the split's stages, which no run records.
- *Memory:* 0.45 GB a recorded run, per fork. Over an assembly regnans keeps
  every step's community in its history, and each community's fitness function
  holds its resident's record. Cope: the history keeps a community and drops its
  record.
- *A trait moves the way regnans moves it.* Every measurement here moved `lma`
  alone; regnans moves it through the hyperparameterisation, along which the
  stand's elasticity at `b*` is −5.9 rather than −9.96. Radii and warm starts
  are to be measured along regnans's direction.
- *The evolving traits' derivatives stay differences at k = 1,* with their step a
  knob. Cope: the step is set once against the sweep, which the report computes
  anyway.

## Kill condition

- *Adaptive runs at regnans's Jacobian step more than ε/3 from replays,* or one
  grid wanted as an outcome (R4's challenge), with a radius in `ln b` that holds
  a near candidate: B's replays, for the moved residents first.
- *Two or more evolving traits in a plant analysis:* the selection gradient
  moves to the sweep, A's "wins when", once plant's fix lands.

## The design

### The workflows, run by run

1. **Equilibrium, cold:** the secant from the starting birth rate, its first move
   the iteration's, every move held to `e^±3`, on adaptive runs at the given node
   times, each keeping its record. 6 runs from `b = 1` on long drought; from
   regnans's `1e-3`, where `f` stays near `ln R₀` until density binds, about
   three held moves more (unmeasured).
2. **Equilibrium, warm:** from the previous candidate's `b*`, its second point a
   Newton step on that solve's last slope. About 4 runs from 0.30 off.
3. **Selection gradient:** regnans's difference, `2k + 1` walk members on the
   record, side by side.
4. **Singular strategy:** regnans's root-finders, stopped at the selection
   gradient's own error estimate rather than `1e-6`.
5. **Classification:** the mutant Hessian by walks on the singular resident's
   record, side by side; the Jacobian by chords of the selection gradient over
   the resident moved ±h, each side two runs (above), the two sides side by
   side; the singular resident's equilibrium reused.
6. **Landscape and maximum:** walks of the record, the batch forked across cores.
7. **Assembly:** the same steps for each species added.
8. **The answer's report:** at the final resident, the stand's sweep (every
   elasticity, and `d ln b*/d ln θ = −e/f′` for every parameter) and its own
   invader's (every parameter's selection gradient), about 7 forwards once.
9. **The error estimate:** the final analysis repeated at the looser setting,
   `tol` doubled, beside each answer.

### The seams

- *regnans's six connectors stay.* The plant harness's `model_support` gains the
  environment and the events; its runner keeps records and its fitness function
  walks the last. One connector is added for the answer's report, which the toy
  harnesses implement by difference over their traits.
- *regnans's generic code:* the secant beside its solvers, warm starts in its
  one-trait search, the classifier reusing the singular resident, its
  tolerances from the companion.
- *plant:* the walked patch takes the invaders' parameters whole
  (`measurements/equilibrium/walked_patch_fix.patch`, with its test), on
  `PLANT-95`, which owns it.
- *odelia:* no change.

### Work items

On `aornugent/regnans`, one issue each:
1. The plant harness on this plant: the environment and events through
   `model_support`, node times given, records kept, the fitness function walking
   the last run, with or without a resident, and the assembler's history keeping
   no record (R1). With a TF24 smoke test, at the shortest lifetime where the
   stand reproduces, beside the FF16 ones.
2. The secant, its cold first move and hold, and warm starts in every search
   (R5).
3. The Jacobian's two runs a side, and the classifier reusing the singular
   resident (R5).
4. Forked batches in the plant harness (R5).
5. The answer's report (R2), with `d ln b*/d ln θ`.
6. The companion error estimate, and the singularity's tolerance and the
   classifier's degeneracy test taken from it (R6).

On `aornugent/plant`: the walked patch's parameters, fixed on `PLANT-95` with its
test, and the stack above it rebased.

Measurements first: adaptive runs against replays at regnans's Jacobian step,
`1e-3`, along the hyperparameterisation (the kill question); the cold secant from
`b = 1e-3`; the five-invader sweep's cost once plant's fix lands (P7).

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
