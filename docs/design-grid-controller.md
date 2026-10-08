# Design: a step and node controller for TF24's gradients

The goal is `OBJECTIVES.md`. A **grid** is a run's node introductions (birth
dates) together with its ODE steps. The controller chooses the grid and the
solver does each step's arithmetic. Together they make forward runs, the
residents' and invaders' gradients (as elasticities) and their curvatures meet
the objectives for TF24 on the birth-date coordinate, on every record of the
bank, at the least runtime. The **four tests** of stability are reproducible,
continuous in the traits, predictable and never fails. The **floor** is brute
force: uniform nodes, plain error control, no heuristics.

**The working hypothesis.** A well-designed solver and controller are
deterministic enough to follow what is known of the ecological process. Once
that behaviour is characterised, one general controller can build efficient,
accurate and stable step and node schedules. The leverage is that the forcing
and its events are known before the run, and that the machinery is precise
enough for cheap probes to find and refine the solver's errors.

This document is the design, and the arc from here to finished. The assessment
that led here (ε, the enablers, the floor, the headroom, local analyses) is
recorded in `docs/assessment.md`. The debugging record of the grid's cost and
error is `docs/grid-dynamics.md`. `docs/geometry.md` sets all three in one
picture: the triangle the run lives on, its mesh, the metrics, the error and
stability.

## What the grid is for

The grid serves the evolutionary analyses regnans builds from TF24
(`docs/design-workflows.md`): a resident at its demographic equilibrium,
invasion fitness and its landscape, the selection gradient, singular strategies
and their classification, and assembly. Each strings together three kinds of
run, all at the equilibrium birth rate `b*`, where `J(b*) = b*`: 4.659 on long
drought, against `J(1) = 12.67` (`measurements/equilibrium.md`). Every number
below this section was measured at `b = 1`, where a run costs 6% less and
splits 9 247 node steps against 10 841.
- *The resident's forward,* 91 s at `b*` (adaptive at `1e-4`, 108 nodes, splits
  on). A secant in `ln b` reaches `b*` in 6 of them cold and about 4 from the
  last candidate's, so each candidate in a search pays 4–6, and the secant needs
  `J` smooth in `b`: it met no noise down to 5.4e-8.
- *An invader's walk* on the resident's recorded steps, 0.77 of a forward.
  Selection gradients, mutant Hessians and landscapes are walks: regnans
  differences `ln R′` at a relative step of `1e-4`, over `2k + 1` invaders for a
  gradient and `1 + 4k²` for a Hessian. A walk splits its nodes where the
  resident split, in the resident's recorded field (`design-sign-changes.md`
  §9).
- *A sweep,* 2.9 forwards for the resident and 2.2 for an invader. Once per
  analysis, at the answer, it gives every parameter's elasticity, and with the
  secant's slope every `d ln b*/d ln θ`. If two or more traits evolve, it
  carries the selection gradient inside the loops too.

The grid an analysis shares is the record of its resident's last equilibrium
run, which every invader walks. A singular strategy in one trait, found and
classified, costs 84 forwards at `b*`, or 60 with its walks forked over four
cores (1.5–2.1 hours), and the answer's report about 7 more.

What phase 3's items are for, in those terms:
- *The splits* (item 2) are in every resident forward. *The sweep through
  them* (item 3) is the report's, on a resident run at `b*`.
- *Curvatures from the adjoint* (item 4) are the report's curvature rows.
  regnans classifies by differences of walks.
- *The soil stepped on its own and the window's weight* (items 5 and 7) cut the
  cost of every forward and walk, paid 60–84 times an analysis; the 15-day cap
  keeps an invader's walk from failing.
- *The node rule* (item 6) sets every run's accuracy and its companion, and *the
  diagnostics* (item 8) are the analysis's error estimate and its distance from
  the grid's θ₀.
- *The radius* (R6 below) decides whether a moved resident, the convergence
  Jacobian's at regnans's step of `1e-3`, could replay its resident's grid
  rather than choose its own steps. Unmeasured; the workflows' first
  measurement.

## Where the arc starts

- *ε is set* (`docs/measurements/eps-spread.md`): 0.025 in `ln J`; for each
  elasticity a tenth of its spread across eight records of one climate, and at
  least 0.01; 1.2 and 4.0 for `lma`'s curvature in residents and invaders.
- *The enablers are in plant* (`PLANT-98`): the tied tolerance,
  `ode_tol_abs = 1e-4·ode_tol_rel`, and no stage guard.
- *The floor has been checked on four records* (`docs/measurements/spot-check.md`).
  - On wet and dry it points to `1e-5` on 215 nodes, about 2.5× `3e-5` on 108.
  - On the constant record no uniform count converges.
  - On long drought uniform companions under-report the invader's error.
- *The headroom's causes are found on both axes* (below). The strategy
  consult's reply (`docs/oracle-response-strategy.md`) has been tested against
  them.
- *None of the changes below is built.* The R driver (`harness/ark_prototype.R`)
  reproduces plant's run bit for bit and carries each tested rule as an option.

## The design

**Triage: 2.** The seams are visible: odelia's stepper and its sweep, plant's
control and schedule. Each change can still be migrated, and none is a
persisted format with outside consumers.

**Requirements ledger** (`OBJECTIVES.md`, with what is measured):
- **R1, accurate:** every quantity within ε of the converged answer. At `3e-5` on
  108 nodes `J` is 2000× inside ε (1.26e-5). The main elasticities' node error
  reaches 1.19ε, for wet's invader `lma` on uniform 108.
  - *Challenged upward, and settled:* at a tenth of their spread, elasticities
    below 0.1 missed their ε on every record, by up to 71ε but 0.004 in absolute
    terms. Their ε is now at least 0.01 (`OBJECTIVES.md`). Even so, at 108 nodes
    three quantities miss outside wet and the constant record, each by under
    1.6×, and nine of wet's invader's.
- **R2, reproducible:** ±5% in `tol`, or a quarter spacing in the introductions,
  moves each quantity by less than ε/3. At `1e-4` the resident fails on five
  pool traits, to 1.65 ε/3; at `1e-5` it passes. The crossings are 70–85% of the
  spread.
- **R3, continuous in the traits:** smooth on one grid within its radius, for
  invaders over ×0.5–×2 and the resident within ±10%. On one grid the gradient
  is a staircase as crossings slide past stages. Split members with two cuts
  carry `J` continuously through a grazing dip's disappearance
  (`grid-dynamics.md` §11).
- **R4, predictable:** each knob's error falls at its order, so a looser
  companion estimates a run's error.
  - Uniform companions report 0.41 and 0.33 of the invader's node error on long
    drought; graded or spread ones report 0.93–1.2.
  - An error kept out of every norm does not converge (the partition,
    `grid-dynamics.md` §13).
- **R5, never fails** over the trait range, for residents and invaders. On
  episodic the lma ×2 invader raises on rule A's steps of 31–38 days, where its
  pools are unstable past 26. A 15-day cap prevents it (phase 1c). The tied
  tolerance alone takes such a step on episodic and dry (27 days), where the
  same walk raises with splits or without and runs capped
  (`design-sign-changes.md` §9, D4).
- **R6, shared:** one grid per local analysis, rebuilt on big moves in θ. The
  floor's grid holds the resident's gradients over `lma` ×0.95–×1.1.
  - Where one grid's radius is shorter than the analysis, several grids or a
    finer one serve it, with brute force the fallback. The controller does its
    best on every record.
  - The invader's radius over ×0.5–×2 is measured on no record. Its slope in
    `ln lma` changes by its own size over |g|/|g′|: about 0.18 on long drought
    (the eight seeds' means), a quarter of ln 2, and 0.0075 under constant
    rain.
- **R7, performant:** the least runtime at matched error.
  - A run with both roles' gradients is about seven forwards (1 + 2.6 + 0.8 + 2.6).
  - In an optimising loop over invaders the resident's run is shared, and an
    evaluation is the walk and its sweep, about 3.4.
  - The baseline on long drought at `3e-5` on 108 nodes is 17 684 steps,
    962 505 rows and 7.06e6 member evaluations.
- **R8, diagnosed:** every run reports its error estimate, its θ's distance from
  the grid's θ₀ against the radius, and its failures.
- **R9, scope:** forward runs, residents and invaders, on the bank (constant,
  wet, episodic, dry, long drought).

**Scarce resource: rows at ε on the gradients.** Every walk and sweep pays the
rows again: six of the seven forwards, or all of an invader's evaluation. The
forward's rejections and its cost per evaluation are paid once, and `J` binds
nowhere.

**The floor:** Cash–Karp under the tied tolerance at `1e-5`, uniform nodes (215
where 108 fails), the knots as step targets, steps capped at 15 days (phase
1c), and companions as the check.
- It meets R2 on long drought and R5 on the pulsed records.
- It fails R4 for the invader (companions 0.41 and 0.33), and R1 and R4 on the
  constant record (`J` 0.0008, 1.20 and 200.7 on 54, 108 and 215 nodes).
- It leaves R7's measured headroom: the window's weight saves 21–28% of rows at
  ≤0.08ε, and the members alone need about half the chain's steps.

**Candidates:**
- **A [first thought]: one mechanism for what the step cannot see** (move 6;
  the witnesses are the driver's special cases).
  - The global step is set by a norm that weighs every state by its reach into
    the objectives: the window's weight in time, the chain's weight, the pools'
    tied tolerance.
  - Whatever the norm cannot see is refined inside the step against its dense
    output: a member's crossing, an invader's stiff pool.
  - *Pays for* R2 and R3 (events), R4 (every error in the norm), R5 (invader
    sub-steps) and R7 (rows).
  - *Costs* a dense output, per-member events with their adjoint (about 1k
    lines), and perhaps an implicit chain.
  - *Wins* where the step's blind spots are few and local: 726 of 14 845 steps
    hold a crossing, and the chain is five scalars.
- **B: the grid built before the run** (move 2). The chain alone's step program,
  a pilot's R(t) and its creation record set a fixed grid. It is replayed
  without control, and refined where companions disagree.
  - *Pays for* R6 by construction, and R7 by dropping the controller's probing.
  - *Costs* probes per record and θ, and a run with no error control.
  - *Wins* where cheap probes predict the coupled run's needs.
  - *Measured against it:* the chain alone matches the coupled program within a
    step in 89% of intervals. As a cap, though, its program catches 38% of
    first-day rejections and caps 19% of accepted steps, a net +0.2%.
    Rejections are paid once, and a pinned resident holds only over ×0.95–×1.1.
- **C: tolerate the kinks** (move 1). Plant's solver as it is: `1e-5` where nudges
  fail, curvatures by corrected chords, the window's weight for rows.
  - *Pays for* R2 (nudges pass at `1e-5`), R1's curvatures (the corrected chord
    within 0.2ε) and part of R7.
  - *Costs* 42% more steps for `1e-5`, against events' 10%. R3 is met only on
    average, since the gradient stays a staircase. R5 needs the invader cap.
  - *Wins* if events are not worth their build: only `J` and wide differences
    needed.

**Winner: A.** Each part is adopted only as the arc's phase 1 confirms it, and C
is each part's fallback.
- *B*'s probes are kept as A's inputs, not as a fixed program. As a cap the chain
  alone's program lost (+0.2%), what the members need inside a step (crossings,
  pools) no probe sees, and a fixed program fails R6 beyond ×0.95–×1.1.
- *C* costs 42% more steps (R7) and meets R3 only on average.

**The commitment:** the global step is set by the error norm alone, which
weighs each state by its reach into the objectives; whatever the norm cannot
see is refined inside the step, never by shortening it.

Kept true by:
- plant's control passes one weight per state (the tolerance weights times the
  window's weight), and odelia's controller takes no cap;
- the knots stay step targets, which land steps rather than shorten them;
- splits live inside `Step` and have no handle on the global step's size.

Phase 1c keeps the 15-day cap, plant's `ode_step_size_max`. It is the one bound
on the global step besides the norm, and the kill condition names it.

**Kill question.** The assumption whose falsity makes this unnecessary: that
every error reaching the objectives can either be weighted in the norm or is
local to a member.
- The crossings are per member.
- The chain is five scalars. The chain alone costs 2.4e-4 of a forward, so its
  error can be checked on every run.
- The window's weight is read off a pilot within 10%.
- The one error kept out of every norm, the partition's coupling, broke
  convergence, so the commitment's first half is what R4 asks.

Survives. Phase 1a confirms both halves: the chain weighted ×10 in the norm
converges, and the implicit chain out of the norm does not (`grid-dynamics.md`
§10).

**What survives deletion:**
- the state weights, the window's and the chain's: R7 and R4;
- the dense output, Cash–Karp's own fourth-order extension: R2 and R3 through
  the splits;
- splits at the sign changes of each node's net production, their times held
  fixed in the sweep: R2, R3 and the curvatures;
- the 15-day cap: R5. Under Cash–Karp it protects every walk for at most 2.4% of
  the window's saving (phase 1c), so invader sub-steps are deleted;
- the soil stepped on its own where the plants draw little (item 5): R7. The
  explicit chain takes ×10 but not ×100. Where stability binds (constant rain),
  the implicit chain paid (60% against 4.7%), and the soil stepped on its own
  now pays as much, at 0.98 of its member evaluations. So it replaces the
  implicit chain (`measurements/soil-alone/`, S3);
- the node rule with its companion: R4 and R8;
- a pilot: R7, for the window.

*Deleted:* the PI law, the chain seeds and the chain guard (they cut forward cost
only, and are even or worse in rows); the crossing, onset and transit caps; the
stability margin; the held collar and the partition, whose coupling's error sat
in no norm (`grid-dynamics.md` §13); class-switch events; refusals for kinks.
Item 5 is not that partition: its coupling's error is in the norm.

**What this settles:**
- no partition whose coupling's error sits outside the norm, and no caps (the
  15-day cap aside), seeds or margins in plant's controller;
- one input to the controller, a weight per state;
- an invader's refinements frozen per grid, so `J′(θ′)` is continuous on it;
- the sweep differentiates the discrete model on the frozen grid, the dense
  output as a fixed linear map of the recorded stages.

**What this makes hard:**
- *A state whose error the norm cannot estimate reliably.* ARK's embedded
  estimate misjudges stiff components. Cope: the chain alone, integrated
  tightly against the recorded uptake, reports the chain's error on every run.
- *Invaders beyond the frozen refinements.* A θ′ outside the analysis range may
  need refinements the grid did not freeze. Cope: rebuild, as for a big move.
- *Records where stability sets every step,* as under constant rain. Cope: the
  soil stepped on its own (item 5). Every step of the constant record takes it,
  at 0.98 of the implicit chain's member evaluations.
- *The build:* a dense output and the splits, in odelia's step and sweep.

**Kill condition:** a component whose error can be neither weighted nor refined
locally, so the global step must be capped by a reading.
- One has arrived: the invader's pools, capped at 15 days. The cap is cheap and
  read off τ_s, not the run, so the design survives it.
- A second would end it: a chain the norm cannot see, or a cap that costs more
  than a fifth of the window's saving. Each hands its part to C.

## What the design rests on

**The cost** (`grid-dynamics.md`, *What a gradient run pays*; `perf-sweep.md` and
`perf-adjoint.md` in `docs/measurements/`).
- *A run's gradients come from sweeps of about 2.6 forwards.* `stand_gradient()`
  differentiates the discrete model on the grid the run took. An invader walks
  the resident's recording (#95), so every invader of a resident shares its
  grid, and its sweep holds the resident's field fixed. At θ′ = θ the invader's
  `J′` equals `J` exactly, and its gradient is the selection gradient.
- *The walk and the sweeps pay rows, the forward alone pays rejections.* Scored
  in rows (`harness/rows.R`), PI with the chain seeds costs a gradient run 5.8%
  more, while the window's rule saves as many rows as forward evaluations.
- *The sweep's cost per row is its tape.* It repeats no search, and each inner
  root is one implicit-function solve. A member taped at its recorded point
  still costs 2.4 forward evaluations. Three changes would halve the sweep
  (*After: performance*).

**The time axis** (`grid-dynamics.md`).
- *The soil chain sets the steps.* Alone it takes 16 447 of the coupled run's
  17 684, and it binds 83–91% of the accepted steps. The members alone need
  about 9176, with the explicit soil then unstable. Its weight ×10 took 21% fewer
  steps at `3e-5`, scored then on `J` alone (§1, §10).
- *Its rejections are its own transient:* the first day's soil-bound rejections
  are drainage switching on as rain starts or rises. The chain alone reproduces
  98% of them, and class switches are no commoner there than in accepted
  attempts (§7).
- *Constant rain makes the chain stiff:* 83% of its steps start near the explicit
  limit, and the implicit chain saves 66% there (§7).
- *The crossings are the gradients' spread.* A crossing of zero net production is
  a kink. Per-member events on an interpolant of the step's order cut the spread
  under nudges 3.4–6.4×, for 10.2% of a forward. A cubic interpolant fails (§11).
- *One window of the goal on every record.* 1–99% of `J` is earned over t ≈ 11–29.
  A weight from a 54-node pilot saves 21–28% at ≤0.08ε. But a failing invader's
  pools are unstable on its long steps: Cash–Karp is unstable past 3.73τ_s, 26
  days (§8).
- *Errors outside the norm do not converge.* The partition's corrections are
  consistent, but its coupling error sat in no norm, so the dry spells' steps
  stayed long as the tolerance tightened (§13).
- *ARK's embedded estimate misjudges the chain* on long steps, in either
  direction (§7).

**The node axis** (`docs/assessment.md`, step 4 and *After the assessment*;
`creation-grid.md`, `canopy-spread.md` and `perf-sweep.md` in
`docs/measurements/`).
- *The node error sits at the first-mover layer's top.* Interpolating in birth
  date a profile that falls by e every `L` makes two opposite errors; `L` runs
  from 0.13 to 2.7 across records. On uniform nodes their difference changes
  sign with each halving, so the invader's companion under-reports.
- *B, graded.* The first window is graded from 0.03 by 1.11 to a cap of 0.37 and
  refined by halving. On long drought every quantity of both roles is then on
  the square law, and companions report 1.0–1.2 of the error. Its constants are
  long drought's; wet's graded `J` reaches the square law only past 494 nodes.
- *D, spread.* Each panel's leaf area is spread over its members' heights. On
  long drought uniform halving then reports its own error: ratios 3.6–3.9,
  companions 0.93–1.09.
  - Single rungs are coarse, so the rule reports a two-rung extrapolation.
  - It costs 3–8% of a sweep.
  - It changes plant's birth-date competition sum.
- *The constant record* needs its founders resolved and nodes at its front: with
  the first window graded and nodes every 1/16 day at the front, 150 nodes
  converge.
- *The light field's fast path holds only while heights run tallest first.* A
  millimetre's disorder sends it down a path that walks every node at every
  knot, 14 times the tape at u429.

**Tried and not kept:**
- locating each crossing and stepping onto it (+2.6e-4 at `1e-4`, for about 3× the
  cost);
- re-integrating a crossing member on a cubic interpolant, which makes `J` worse;
  the step's order is needed (§11);
- a wider positive part of net production (a model change that moves `J` by 3.9%);
- the crossing correction of Shelley and Tao, which halves `J`'s and `lma`'s
  draw and leaves `a_dG2`'s;
- capping crossing steps at a day, which halves `lma`'s draw for 5% more, where
  events cut the spread 3.4–6.4×;
- capping each pool's motion per step, which costs 14–41% and leaves the
  gradients' errors as large or larger;
- implicit and multirate treatments of the soil held to the norm's tolerance;
  the chain implicit and out of the norm is phase 1a;
- a stability margin on the soil, 9.6% for no radius;
- the partitioned step (`grid-dynamics.md` §13);
- the PI law, the chain seeds and the chain guard, scored in rows (§7);
- events at class switches (§7);
- deleting the end-state refusal, which changes nothing on long drought.

The records are `docs/assessment.md`, `docs/archive/scope-imex-stepper.md` and
`docs/archive/oracle-consultation-solver-performance.md`.

## The arc

Four phases from here to finished, each ending in a gate. Phase 1 decides on the
driver what phase 3 builds. Phase 4 is the finish line.

### Phase 1: the time axis, settled on the driver

Three independent sets of driver runs. Each is scored in rows and in both roles'
gradients' spread under ±5% nudges, over three tolerances so that convergence
shows (R4). The records are long drought and the constant record, then one more
pulsed record before the gate.

**1a. The chain's weight and treatment** (R7, R4).
- *Runs:* the explicit chain at weights ×10 and ×100, still in the norm; the
  implicit chain (the driver's ARK) at ×100 and out of the norm. Each at
  `1e-4`, `3e-5` and `1e-5`.
- *Each run's chain error:* the chain alone, integrated tightly against the
  recorded uptake (R8).
- *Gradients:* plant replays the explicit variants' programs for both roles
  (`run_record.R`'s `PROGRAM`). It cannot replay the implicit ones, so those get
  the resident's elasticities by frozen-step differences on the driver.
- *Pass:* R1 and R2 on both roles' main traits, with errors falling with the
  tolerance. The winner is the passing variant with the fewest rows.
- *Decides* whether the chain's treatment is a weight in plant's control, an
  implicit step in odelia, or neither.
- *Result* (`grid-dynamics.md` §10, `phase1a/`):
  - The explicit weight ×10 passes both tests for both roles at `3e-5`: −20.7% of
    a gradient run.
  - ×100 does not converge: the saturated top layer cycles at the explicit
    limit.
  - The implicit chain at ×100 passes at `1e-5`, for the resident only: −36.8%.
    At `3e-5` its `J` is outside ε, because ARK's embedded estimate misjudges
    the soil.
  - Implicit and out of the norm does not converge.
  - On the constant record the implicit chain saves 60.3% against the weight's
    4.7%. On episodic the two are within 2 points.
  - By the pre-registered rule the implicit chain wins. The weight is the
    fallback, and is built (`state-weights`).
  - *Round two:* with the chain alone's estimate for the soil in place of ARK's
    embedded one, the implicit chain converges and passes R1 and R2 at `3e-5`
    for the resident: −44.3% on long drought, −67.0% on the constant record.
    At `1e-4` it fails R2 on the crossings.
  - The explicit weight's ceiling is ×20 (−25.4%); ×30 and ×50 stop
    converging.
  - It is built in odelia and plant (`ark-step`, `ark-soil`), with the chain
    alone's estimate, and repeats the driver's arkc bit for bit at `1e-4`,
    `3e-5` and `1e-5`. Both roles' gradients are finite on the stand
    (`grid-dynamics.md` §10).
  - On three records with the walks, arkc at `3e-5` saves 42–55% of a gradient
    run and never fails. But it misses the accuracy bar on long drought and
    episodic, where the resident's largest distance from `1e-5` is 0.36–0.40ε.
    The soil's weight does not set that error: at 10, 30 and 50 it moves with
    the program instead. At `1e-5` the long-drought error falls 3.1×, a smooth
    bias from ARK's fourth order, and ARK with rule A is still 2.0–2.7× farther
    from `1e-5` than bounded Cash–Karp at `3e-5` for 6–11% less. So at matched
    error bounded Cash–Karp wins on the pulsed records, and the implicit chain
    earns its place under constant rain, where stability binds.
  - *Retired* (`measurements/soil-alone/`, S3). Under constant rain the soil
    stepped on its own (1e) takes 0.98 of arkc's member evaluations, at
    `J` +6.9e-8 against arkc's +1.6e-6. So one mechanism serves every record,
    and `ark-step` and `ark-soil` are not merged.
- *RODAS on the whole stand: assessed, not run.*
  - Selecting it is one line: odelia's solver takes its method at construction
    (`scm.h:548`).
  - But its Jacobian comes from plant's forward tangent. There the environment
    holds the soil as a plain double, so every soil row and column is exactly
    zero, and RODAS would step the chain explicitly.
  - It records nothing, so it gives forward `J` only. Its dense Jacobian and LU
    cost about a thousand stand evaluations a step at 108 nodes.
  - Its stages go negative past 2.45τ (`docs/geometry.md`, 4(a)). Its one gain,
    the chain's stability limit lifted, is what the implicit chain here tests at
    a fraction of the cost.

**1b. The pair and its interpolant** (R2, R3, R7).
- *Runs:* Dormand–Prince 5(4), with its free fourth-order dense output, against
  Cash–Karp in rows and error. Then per-member events on that interpolant, in
  cost and spread, against §11's quintic.
- *A reference implementation:* dust2's continuous solver (`mrc-ide/dust2`,
  `inst/include/dust2/continuous/`). It is Dormand–Prince with Shampine's free
  fourth-order dense output, stored per step as five coefficient vectors for
  only the variables read later, with events found on it by a bracketing root
  finder.
- *Also each pair's negative stages on the pools,* and any raise. On a pool's
  test equation Dormand–Prince's sixth stage turns negative past 1.04τ, against
  Cash–Karp's fourth past 2.16τ. On a 15-day step at τ_s its lowest stage is
  −4.25, where Cash–Karp's stay positive (`harness/stability.R`,
  `docs/geometry.md`, 4(a)).
- *Pass:* the split members' fields within one error weight, the spread cut as
  far as with the quintic, for under 5% of a forward.
- *Decides* the pair and the interpolant's order. If 1a picks an implicit chain,
  the dense output must come from that method's family, and 1b says what order
  it needs.
- *Result: keep Cash–Karp, with its own fourth-order extension* (`grid-dynamics.md`
  §11, `phase1b/`).
  - Using the end's rate, which plant already evaluates, Cash–Karp has a free
    order-4 extension. Events on it match the quintic in `J` and in nudge spread
    (`d_I` 1.261 → 0.262 ε/3) for 5.9% of a forward, against the quintic's 10.1%.
  - Dormand–Prince takes 11–15% more rows, stalls at a larger error, and throws
    8–38× as many stage rejections.
  - Against the pre-registered criteria: the field test fails for every arm,
    the quintic included, and the cost test misses 5% by 0.9 points.
  - An implicit chain's dense output needs order 4; the cubic fails.
- *What it does not test: an invader refined against the resident's step.*
  - An invader walks the resident's recorded stages, so it must use the
    resident's pair. Cash–Karp and Dormand–Prince share only the stage times 0,
    1/5, 3/10 and 1.
  - Reading fields between stages also needs the resident's run to keep its
    dense-output data.
  - 1b measures the interpolant's accuracy, which an invader shares, since it
    reads the same fields; 1d tests the plumbing if it is needed.

**1c. Invaders under long steps** (R5, R7).
- *Runs:* rule A's weight with every step capped at 15 days (2.16τ_s), on the
  bank's pulsed records, with invaders over `lma` and `hmat` ×0.5–×2 walked on
  each.
- *Also which limit raises.* A cap at 26 days breaks Cash–Karp's positivity
  (2.16τ_s) but keeps its stability (3.73τ_s). If invaders raise there, a negative
  stage raises. Then Dormand–Prince runs, whose stages turn negative past 1.04τ_s
  (7.3 days), need a 7-day cap or sub-steps past `h/τ_eff ≈ 1`.
- *Pass:* nothing raises. The cap stays if it gives up less than a fifth of the
  window's 21–28%. Otherwise the invaders' members sub-step where `h/τ_eff > 2`,
  frozen per grid.
- *Result: keep the 15-day cap, on the floor too; no invader sub-steps under
  Cash–Karp* (`grid-dynamics.md` §8, `phase1c/report.log`).
  - No walk raises at 15, 20 or 22 days. The lma ×2 invader raises only at 26
    days, at Cash–Karp's stability limit, so stability matters and a negative
    stage down to −0.78 does not.
  - The cap gives up 0.0–2.4% of rule A's saving.
  - It moves the resident's pool traits by up to 0.187ε, which fails the move
    test as registered. Post hoc, that is the cap correcting the uncapped run,
    which is farther from `1e-5`.
  - *Dormand–Prince, since dropped, would have needed about 10 days.* Its stages
    are −4.25 at 15 days and −12.5 at 20, past anything tested. A 10-day cap
    gives up 1.0% (long drought) and 9.0% (episodic) of the saving.
- *With 1a's soil weight, a bound on every weight* (`grid-dynamics.md` §8,
  `phase1c/combined/`).
  - The soil ×10, rule A and the cap together save 33–37% of a gradient run on
    three pulsed records, and every walk runs.
  - But the soil's weight times rule A's factor reaches 1000. The error test
    then accepts steps with a soil stage at the 1000 MPa potential ceiling, and
    both roles' gradients are refused.
  - plant now bounds each state's weight (`ode_tol_factor_max`). At 100 every
    gradient is finite on the three records and every walk runs. The setting
    saves 31–34% of a gradient run and passes the accuracy and nudge tests:
    Cash–Karp's setting.

**1d. Invaders refined against the resident's dense output** (R5, R3), only if
phase 4 finds the invader's curvatures short. For R5, 1c's cap suffices.
- *Runs:* an invader walk on the driver that reads the resident's recorded stages
  and dense output, and sub-steps its members where `h/τ_eff > 2` or at a
  crossing.
- *Pass:* `J′ = J` at θ′ = θ, nothing raises over ×0.5–×2, and a continuous
  `J′(θ′)` on the frozen refinements.
- *The trigger can be read rather than derived.* In Dormand–Prince the sixth and
  seventh stages share t + h, so h·‖Δf‖/‖Δy‖ between them estimates h·|μ| for
  free on the step's stiffest direction. This is dopri5's stiffness test; dust2
  keeps its storage but not the test. Cash–Karp's fifth stage and the next
  step's first evaluation share t + h likewise. Per member, it reads h/τ_eff
  without the model's formula, and catches fast parts no formula names.
- Invader events matter less than the resident's. At `1e-4` the invader already
  passes the nudge test (largest move 0.32 of ε/3), and its gradient's jumps are
  3e-5 of itself, since its sweep holds the resident's field fixed.

**1e. The soil stepped on its own where the plants draw little** (a pathfinder;
`grid-dynamics.md` §15). It was not in the arc as first written. The user has
decided that it joins the build (phase 3, item 5), and that tuning it belongs
with the later task of building general scheduling heuristics.
- *How it works:* when the uptake at a step's start is under 10% of the soil's
  water budget, the soil is integrated on its own under an uptake extrapolated
  from the last step, a corrector pass follows, and the coupling's error enters
  the error norm at the members' weight.
- *What it gave on the driver:* against bounded Cash–Karp, rows fell 41% on long
  drought and 45% on episodic, and 41% and 29% at bounded Cash–Karp's error in
  `J`. Every elasticity of five traits stayed within 0.11ε of the reference.
  When the coupling's error was judged at the soil's weight instead, the error
  in `J` grew to 22 times bounded Cash–Karp's.
- *What the build needs:* the soil's inner steps held fixed in the replay, so
  that reverse mode can run through them, and the invader's gradients measured,
  which the driver cannot do. The threshold stays at 10% until it is tuned.
  Tuning includes making it tighten with the tolerance, which the error in `J`
  needs below `3e-5`.
- *Settled for the build* (`measurements/soil-alone/`; designed in
  `design-soil-alone.md`, the build being phase 3's item 5):
  - the slope stays, recorded on the row;
  - the end's uptake comes from the stage at t + h;
  - under constant rain it matches ARK, which retires.
  - Without the slope `J`'s error still stops falling below `3e-5`, so the
    floor is not the slope's.

### Phase 2: the node axis

- **2a. B or D,** the user's decision. D changes plant's birth-date competition
  sum and every reference, and its cost objection is gone.
  - *Measured on long-wet and long drought under bounded Cash–Karp*
    (`grid-dynamics.md` §16). Spread uniform nodes (D) are on the square law
    over 108, 215 and 429 introductions on both records, and their companion
    reports 0.95 and 0.98 of the error. Graded nodes (B) are not: their
    companion reports 0.71 and 0.80 of it, and adding the spread to graded
    nodes does not help.
  - D's two-rung extrapolation reaches 0.090ε at 2.41M rows on long-wet and
    0.174ε at 1.95M rows on long drought, with an estimate that covers 93–95% of
    quantities. B's extrapolation takes 3.19M and 2.57M rows for 0.114ε and
    0.155ε, and its estimate covers only 64–78%.
  - The spread costs 2–6% of the resident's sweep per row once the crowns are
    sorted.
  - *Decided:* D is in the build. B is not rejected: it stays an option to
    consider later, since there may be cases where grading helps.
- **2b. The light field's ordering test,** given a tolerance or replaced by a sort
  before the prefix pass, in plant. Either rule needs it at its finest rungs.
  - *Measured on both records:* the crowns fall out of height order only at
    429 uniform or 494 graded introductions, in 20% of builds on long-wet and
    79% on long drought, by at most 1.2 mm. Sorting them costs nothing
    measurable on either record. On long-wet a 1 cm tolerance repeats the
    sort's `J` bit for bit, while walking every node costs 23% of a forward. The
    sort is the fix, and it needs no tolerance to choose.
  - *Decided:* the sort is agreed in principle, and it gets a design turn of its
    own before it is built.
- **2c. The chosen rule's ladders** on wet, dry and episodic (D's to u429), and
  the constant record with its front nodes, with the introductions also moved by
  a quarter spacing (R2's other knob). *Pass:* square-law ratios near 4,
  companions reporting 0.8–1.25 of the error, and the quarter-spacing move under
  ε/3, on every record and for both roles.

### Phase 3: the build

Stacked changes on the plant and odelia forks, each with its own tests, and
bit-identical wherever its default is off (AGENTS.md). The order puts
subtraction first and the resident's workflow before performance (the user,
after the events reply):
1. *Land the stack under it:* exact counts (#94), the reverse sweep (#91),
   exact invader replay (#95), the knots as step targets (#96), the pool's
   relaxation offset and stage guard (#97, #98), the first invasion walk (#99)
   and the state weights (`state-weights`, both forks). #96 subtracts before the
   splits add: its knots no longer split the sweep's descent with identity
   rows, 19% of the sweep (`perf-sweep.md`). The PRs and merges are the
   user's call.
2. *Splits in the forward step.* Where a node's net production changes sign
   inside an accepted step, that node's components are integrated over the step
   in two parts, the first ending at the sign change; the rest of the state is
   read from the step's dense output.
   - The dense output is Cash–Karp's own fourth-order extension, from its six
     stages and the end's rate (1b). It exists for the splits, so it lands with
     them.
   - The sign change is located on the dense output. A pair of sign changes
     inside one step is split twice, since a test at the step's ends misses it
     (`grid-dynamics.md` §17).
   - Each part integrates the model's own rates, its smooth positive part
     included, so the rates do not change. (The events reply proposed one branch
     of the positive part per part instead. That changes the rates, and it
     threads a flag from the patch into the strategy's rate function.)
   - The state's rates are evaluated again at the corrected end state, which
     the next step starts from.
   - A replay of the resident repeats the forward's splits bit for bit, since
     it evaluates every node again. (As built, an invader walk integrates each
     node the resident split in pieces at the resident's sign changes, held, in
     the field the resident recorded at five fractions of the step, so at the
     resident's traits `J′` = `J` to the bit: `design-sign-changes.md` §9.)
   - Gates: `J`'s error falls with `tol`; `J` moves by at most 1e-8 as a sign
     change passes from one step to the next; a pair of sign changes merging is
     continuous; the forward costs at most 6% more; and halving only the split
     steps shrinks the split nodes' error at the pair's order, which is
     unmeasured for the quartic.
   - *Built* on `sign-changes` (odelia `6a6ce45`, plant `abcfcc22`), and
     *measured* on long drought (`grid-dynamics.md` §18). It repeats the
     driver's split: `J` 10× nearer the reference than plain at `1e-4`, and the
     curvature within 0.015ε of −43.45 at r = `1e-2` and `3e-2`. Three gates are
     missed as registered: below `3e-5` an error both arms share stops `J`'s
     error falling; the forward costs 6.9% more; and from r = `1e-2` to `1e-3`
     the curvature still moves 0.49ε. At matched stability the split at
     `1e-4` costs 0.77 of plain at `1e-5`.
   - *The residue* (`grid-dynamics.md` §18, as revised). Every replay on a
     pinned grid carries noise of about 1.9e-8 in `ln J`, plain too, under a
     change of the trait as small as 1e-12. It is the leaf solve's stopping
     tolerances: stopped at adjacent floats, plant's own root-finds with it,
     the noise falls to 1.1e-14 and `ln J` moves by −1.5e-6 (`tight.log`). No
     split choice was seen to move `J` by
     more than that: the bisected passage and pairs lie inside it. Over 6.25e-5
     in r `ln J` also wanders from a smooth curve by 6.5e-8, the same in the
     split and in its correction at a step's end (correlation 0.78), so the
     passages do not carry it. Every arm holds about the same residue at `1e-3`,
     +0.57 to +0.72 against its value at `1e-2` (the correction's +0.18 is its
     one jump of −5.4e-7), and it falls more like 1/r than r⁻². With the leaf
     solve stopped at adjacent floats the residue (+0.58) and the slower
     departure (correlation 0.90) stay, so both are the split's on its pinned
     grid. Both shrink when the positive part's width is ×10 (the departure
     about tenfold, `band_fit.log`), against the splits reply's prediction
     that it would grow. What carries them is not traced; the split leaves the
     class switches and the soil's floor and saturation uncut. The tight leaf
     solve costs 10% of a replay. The correction costs `J` 6.7× its accuracy and
     cutting every pair the dense output shows 12× the runtime, and neither
     changes the residue. An adjoint differentiates the run's own choices, so
     item 4's chord of two gradients carries no jump, only how the slope
     differs between its ends, which the fine grid bounds at about 1.5e-3 and
     item 4's gate will measure. The gates "`J` moves by at most 1e-8 as a sign
     change passes" and "a pair merging is continuous" cannot be read on
     replays whose own noise is 1.9e-8. On the build without that noise they
     are read by bisection (*Finished*, below).
   - *The cost* is a fixed 0.5–0.7 ms a node step split, 12.5% of plain at `1e-3`
     and 7% at `3e-4` and `1e-4`. 92% of it is part evaluations, each of which
     rebuilds the whole field, the boundary node's leaf solve included (39%).
   - *Finished* (after the splits reply, `oracle-response-splits.md`;
     `grid-dynamics.md` §18, *Finished*; the eighth to tenth extensions in
     `measurements/sign-changes/prereg.txt`). Each change is its own commit and
     issue:
     - *The leaf solve and the newborn's height stop at roundoff*
       (aornugent/phylloptim#17, aornugent/plant#100; TF24 v13, TF24f v13.1).
       Every root-find stops once its bracket's ends agree to 4 DBL_EPSILON
       relative. A replay's noise falls from 2.7e-8 to 8.5e-15 in `ln J`,
       `ln J` moves by −1.5e-6, and a replay costs 1.12× as long. Stopping at
       exactly adjacent doubles costs 1.38× for the same noise. (The reply's
       alternative, one Newton step at the end of each solve, is unmeasured.)
     - *The field build sets the newborn's initial state without computing its
       rates* (aornugent/plant#101), bit for bit. Of *a part rebuilds only what it
       reads*, this is the newborn's leaf solve, 39% of the split's cost; the
       chain from the dense output and the light field from the nodes'
       interpolated heights are not built, and each part rating still rebuilds
       the uptake and the light field.
     - *A pair inside a step is searched for beside a reading near zero*
       (aornugent/odelia#53). Where no stage holds the other sign on the dense
       output, the gaps beside the reading nearest zero are searched if it is
       within 2% of the readings' spread, by a golden section of at most four
       dense-output values. As first built the search ran only where no stage
       held the other sign at all, and the scan still showed the 7 pairs a run
       the stage rule missed: the first stage, one Euler step from the start,
       carries the pulse's fall past the dip. Run whenever the stage rule cuts
       nothing, the scan shows none missed at the trait or 1e-3 below it, and
       `ln J` moves by −6.7e-9.
     - *Each run reports its splits* (aornugent/plant#102):
       `SCM$ode_split_record` gives each node's steps split and steps searched,
       and the slowest crossing at a cut. On long drought every node but the
       last is split, a median of 82 steps; the search runs on 417 node steps;
       the slowest crossing is 0.0033 a year.
     - *The cost* is 5.4% over plain alone (69 and 68 s against 64 and 66 s),
       against 6.9% before: inside the item's 6%, short of the 4% registered for
       after the rebuilds. A node step split costs 0.38 ms against 0.53, and the
       rebuilds above are what remain of it.
     - *A choice's jump*, readable now the noise is gone (the tenth
       extension): where a pair is first cut, `ln J` moves by −4.7e-10, and where
       a sign change passes out of a step, by +4.9e-11, under the gate's 1e-8.
     - *The positive part in a part, smooth or one branch per side* (the
       eleventh extension; `branch.log`). The reply held a branch is not a
       change to the rates (under 1e-10 in `ln J`), and that the sweep could
       then freeze the split times. Tested, it changes them: `ln J` moves by
       −1.5e-3 at the trait, the fine grid's residual sd is 8.45× the smooth
       arm's, and the curvature moves 8.2ε from r = `1e-2` to `1e-3` against
       the smooth arm's 0.54ε, at the same cost. The smooth positive part stays,
       so item 3 routes each split time by the implicit function.
3. *Splits in the sweep.* Each part is a row of its own for its node's
   components, and the field values it read are fixed linear maps of the
   recorded stages. Each split time enters the tape by one implicit-function
   step at its located time, through odelia's implicit node: its derivative is
   minus the node's net production's sensitivity over its rate of change. With
   the model's smooth positive part in both parts, that term is what makes the
   gradient exact rather than first order in the step. Gates: the sweep's
   gradient against central differences of the forward on the recorded steps
   at r = `1e-3`, within about 2e-3 in an elasticity, which the wobble's local
   slope allows; a sweep with the split times frozen against one that routes
   them, which agree with a branch per side and differ at first order in the
   step without (the construction's own test, from the splits reply); and the
   sweep costs at most 6% more.
   - *Built* on `PLANT-103` and odelia `ODELIA-54` (#103, odelia#54; the
     twelfth extension in `measurements/sign-changes/prereg.txt`). The sweep
     tapes each split node step's pieces at the run's recorded ratings, the
     rest of the state read from the taped dense output, and each cut by
     odelia's implicit node, its slope a central difference of 1e-5 of the step
     on the dense output (two part ratings a cut in the forward). The tangent
     walks still refuse a run that split.
   - *Why the cuts move and the steps do not* (the user's question). A step
     boundary is placed for accuracy, and moving it changes `J` only at the
     method's order, so the sweep holds it. A cut is placed at the zero of net
     production, and the piece after it takes its first rating there, at the
     turn's centre whatever θ. Held while θ moves the zero, that rating reads
     the turn off-centre with a stage's weight, and the gradient's error is
     first order in the step again. For the same reason a replay relocates the
     cuts: pinned at θ₀ they would sit off the zeros at θ.
   - *The stage times are held* (the user's choice). A cut that moves moves its
     pieces' stage times, and rates that read the time itself are
     differentiated as if they did not. On the bank only patch survival does:
     1.2e-5 of `d J / d lma` on 8 years of long drought. A forward difference
     of each piece rating in time closed it to 8.9e-9 for 1.4% of the forward,
     and is not built.
   - *Measured* (the twelfth extension; `sweep_gates.log`,
     `sweep_profile.txt`). The sweep's elasticity in `lma`, −8.276, lies
     2.7e-4 and 1.8e-5 from central differences at r = 0 and `1e-3` (S4
     holds); at r = 0 the central difference straddles a pair's first cut, and
     the slope below puts the sweep 2.1e-5 off, about 2.5e-6 of it, patch
     survival's time. With the cuts held it is 7.5e-3 off. The sweep costs
     14.7% more than plain's (254 and 254 s against 217 and 226 s; S5 fails):
     8.3% of it is the split's pieces. Read again on the split's own stacks,
     half of that is the light field each piece rating rebuilds on the tape, a
     quarter the whole state's dense output and its copy into the patch, and a
     quarter the node's own rates; the 90% first recorded counted the forward's
     field builds and the main steps' too. The forward recording for a sweep
     costs 4.6% more than `PLANT-102`'s, and nothing more where it keeps no
     rows; the profile puts the extra in the main steps' leaf solves beside the
     kept split records, by a route not traced.
   - *The cure* (the thirteenth extension). Rebuilding only the knots a rating
     reads leaves the whole state and the reduction over every node: about 1.4×
     on the pieces, short of S5. So a split step reads the rest of the patch
     once at five fractions of the step on the dense output, u = 0, ¼, ½, ¾ and 1:
     the light field's knot data and the soil's state, which are all a node's
     rates read of it. Each rating reads the quartic through the five at its own
     u, with its own components in place.
     - The soil's state is a quartic in u on the dense output, so it is read as
       before, to roundoff. The light field is read to fifth order in the step,
       the dense output's own, and a node's own shade no longer follows its
       pieces within the step.
     - The forward and the sweep read the same, so the sweep stays the run's
       derivative, and a rating costs the node's own rates and a quartic.
     - *Measured* (the thirteenth to fifteenth extensions; `reads_gates.log`,
       `reads_timing.log`, `inproc_timing.log`). `ln J` moves by −2.4e-9 on
       the split's pinned program and by about −2e-8 on adaptive runs at
       `1e-3` and `3e-4`, which take the same steps; S4 holds as before. Alone
       on one core and alternating, the sweep costs 7.3% more than plain's
       (six each; CPU time +6.8%), so S5 reads neither, and the forward 6.0%
       more, against 8.7% before. The pieces with their reverse pass are 4.0%
       of plain's sweep, about what the method needs: twelve ratings a split
       part, the end rated again and five reads a split step. Swept
       alternately in one process the two differ by 5.9% (CPU 5.0%), which
       agrees with both within the runs' noise; what carries the rest, up to
       3%, is not placed. The user accepts 7% for S5.
   *The design of items 2 and 3.* (Rebuilt as `design-sign-changes.md` §8 maps
   it, plant owning the split and odelia the step's numerics, in its
   vocabulary; §9 changed the walk.) One commitment: odelia does the arithmetic
   and plant names the parts.
   - *odelia.* A System that satisfies `SplitsSignChanges` supplies three
     things: the sign value of each part after an evaluation (for TF24, each
     node's net production), the width of a part, whose parts open the state,
     and what a part reads of the rest of a state with one part's rates and
     sign value from its own components and those reads. Only a double System
     splits.
   - The solver splits each step its error estimate keeps, and every pinned
     step, before the end rate is handed on and the row recorded. It compares
     each part's sign value at the step's ends and at its five stages, locates
     each sign change on the step's dense output by regula falsi, integrates the
     part's components over the pieces between them with the step's own tableau,
     writes the end state, and evaluates the rates there again. A part's stage
     that throws rejects the step, and the validity check reads the corrected
     end. A System that names no parts runs bit for bit as before.
   - `Step` gains the dense output, from the six stage rates and the end's rate
     it already holds, and its stage and end combinations take their length from
     the vectors rather than the full state, so a part reuses them.
   - *plant.* The patch satisfies the concept where its strategy names the
     auxiliary its rates change form at (TF24's net production), and names its
     nodes as parts when `ode_split_sign_changes` is on: a node's components are
     where `ode_state` writes them, and a part's rates are that node's alone, in
     the light field and soil a split step reads at its five fractions. A walk
     integrates each invader node laid out as the run's in pieces at the run's
     sign changes, held, in the run's recorded field. `ode_splits` counts the
     node steps a run or walk split. The tangent walks refuse a run that split;
     the sweep follows it (item 3).
   - *Recorded,* for each split step: what the evaluation at the end before the
     split solved for; the field at the five fractions, which a walk reads; and
     for each split block its sign changes (each one's u, slope and what the
     evaluation there solved for) and what each evaluation in its pieces solved
     for, which the sweep loads at the solutions found.
   - *Tests, with the change:* the dense output's order and its end against
     the step's solution, in odelia; in plant, a TF24 run with splits on, its
     replay bit for bit, and its error falling with `tol`, with every run
     without splits bit for bit, the FF16 guard included.
4. *Curvatures from the adjoint.* A chord of two split gradients at
   `θ·e^{±r}` gives a whole row of curvatures, every elasticity's derivative in
   one trait, for two gradient runs. `lma`'s row, which the ε table sets, is one
   example. A forward second difference of `ln J` checks the row's diagonal
   entry: with splits it is reproducible at r from `1e-2` to `3e-2`
   (`grid-dynamics.md` §17). Gate: each row stable under the `tol` nudges and
   across r, against the check. The wobble (below) keeps chords at r of `1e-2`
   or more, where it costs about 0.05 of the curvature's ε; at `1e-3` it would
   cost half of it. With item 3 built, the gradient's own wobble is read at the
   fine grid's seventeen points.
   - *Measured* (the sixteenth extension; `measurements/sign-changes/`
     `curvature_rows.log`). Long drought at `1e-4`, `lma` alone, each row the
     chord of two split gradients on one grid, its ε a tenth of its spread over
     the eight records. The resident's `lma` entry, −43.46, matches its second
     difference to 0.001 and moves 0.13ε from r = `1e-2` to `3e-2` and 0.06ε
     under the nudges. Across the row 41 of 48 entries stay within ε/3 across r
     and 42–46 under the nudges; seven entries with small spreads do not, up
     to 3.7ε across r (`rooting_depth_max`) and 0.8ε under the nudges, so as
     registered the row fails both.
   - *The invader's row* repeats under the nudges, a median 0.01–0.03ε, but
     not across r, a median 2ε: its curvature in `lma` runs from −161 to −197
     over ±3% of it. An invader's row is read at one r.
   - *The selection gradient's row over moved residents,* the convergence
     Jacobian at a fixed birth rate, moves 0.17ε across r and 0.02–0.04ε under
     the nudges, against the invader's ε as a stand-in. With the mutant
     Hessian as the invader's row, both of regnans's classifying matrices are
     chords of a swept gradient (`design-workflows.md`).
5. *The soil stepped on its own where the plants draw little* (1e).
   - *The item:* on steps whose uptake is under 10% of the soil's budget, the
     soil is integrated on its own under an extrapolated uptake, with a
     corrector pass, and the coupling's error enters the norm at the members'
     weight. Its inner steps are held fixed in replays, so the sweep runs
     through them, and a split reads the soil from them. Its threshold is tuned
     later, with the scheduling heuristics.
   - *Settled by three spikes,* registered before they ran
     (`measurements/soil-alone/`):
     - *S1, the slope stays.* The predictor keeps the driver's slope,
       extrapolated from the last step, recorded on the row and held in replays
       and the sweep. Holding the uptake at the step's start instead cost 5.8%
       and 12.8% more rows.
     - *S2, the end's uptake from the stage at t + h.* An attempt then costs six
       evaluations, as an ordinary step does: 9% fewer member evaluations, with
       `J` inside the bound.
     - *S3, ARK retires.* Under constant rain the step takes 0.98 of arkc's
       member evaluations, at `J` +6.9e-8, so it is the one soil mechanism.
     - *The floor is not the slope's.* Without the slope too, `J`'s error stops
       falling below `3e-5`: +2.2e-5, +1.6e-8 and +2.3e-5 at `1e-4`, `3e-5`
       and `1e-5`, about 0.001ε. Q3 read it as the threshold's, held fixed as
       the tolerance tightens, which is untested. The threshold's tuning stays
       with the scheduling heuristics.
   - *Designed* in `design-soil-alone.md`, under the system-design skill.
     - *One commitment:* a step that takes the soil alone is a function of its
       own row. Its instruction holds every choice the run made for it: that it
       took the soil alone, the slope, and the inner steps as fractions of the
       step.
     - *odelia steps the block and the System names it,* in four hooks: where
       the block is, whether this step takes it alone, its inputs, and its
       rates under given inputs.
     - *An invader's walk is untouched:* its evaluations load the run's field,
       the soil included.
     - *The split reads the soil through the step's dense output,* the block's
       from the predictor's samples at the five fractions. So the split's guard
       from §9 holds by structure.
   - *The build, done:*
     - odelia `ODELIA-55` (`27a0def`) on `ODELIA-54`: the step's forward and
       its recording first become one body at any scalar;
     - plant `PLANT-105` (`91bf8b59`) on `PLANT-104`: TF24's soil as the block,
       the share in Control (0, off, by default), and the program's two new
       fields through R;
     - its departures and first runs: `design-soil-alone.md`, *As built*.
   - *Gates,* G1–G7 there, and every one holds.
     The gates found two defects, each fixed in its own branch before the
     reruns: the slope emptied at every knot, and a program given with events
     replayed as a grid of times.
     - G1: plant takes the aligned driver's 7691 steps on long drought, 5129 of
       them alone, and its `J`, bit for bit;
     - G2: replays and `J′ = J` to the bit;
     - G3: the sweep 2.38e-4 from central differences at r = `1e-3`;
     - G4: rows −41.5% and −44.8% against bnd on long drought and episodic,
       every elasticity within 0.063ε, both roles;
     - G5: the bank under the cap with splits on: nothing fails, the sweep is
       within 2e-3 of the replays and `ln J` within 5.8e-5 of the bank's split
       at `1e-6` on all five records;
     - G6: timed alone, a gradient run takes 0.63 of bnd's time, the forward
       0.58, and the soil's inner steps 0.79% of the forward's profile;
     - G7: off, bit for bit.
   - *Depends on* item 7's setting (its path's first step), which is its
     baseline.
6. *The node rule from phase 2.*
   - *The item:* spread uniform nodes (D), each reported as the two-rung
     extrapolation with the coarser run as its companion. It changes plant's
     birth-date competition sum, and so every reference. Its finest rungs need
     the crowns sorted by height, which waits for its own design turn (2b).
     With it comes the invader's own rule: sparser introductions by its own
     share of `J′` (`grid-dynamics.md` §14), with the full walk kept on the
     diagonal.
   - *Decided:*
     - D (2a);
     - the sort, in principle (2b);
     - the invader's sparser introductions, which kept 53–66% of its walk and
       sweep at ≤ 0.17ε in `ln J′` (§14).
   - *The path, in order:*
     1. *The sort's design turn, then its build:* the crowns sorted by height
        before the light field's sum, at no measurable cost and with no
        tolerance.
        - *Built:* aornugent/plant#107 (`PLANT-107` `9c9a3bfd`, on `PLANT-106`).
          S1 holds, bit for bit on 108 introductions. S2, the crossed rung at
          429 timed alone, takes 0.97 of the walk's forward; its `J` differs by
          2.3e-12, past the registered 1e-12, from the sum's association carried
          by the step control after step 2944 of 13563
          (`measurements/node-rule/prereg.txt`).
     2. *D in plant's competition sum.* Every reference changes, the FF16 guard
        included. So the references are blessed again in a commit of their
        own, with the move registered first. One build with the split measures
        what the spread's 16 point crowns a node cost it: five field builds a
        split step.
        - *Built:* aornugent/plant#108 (`PLANT-108`: `77cbb5e3`, and the
          references blessed again in `68f7f7fd`, each move registered first).
        - *Found by the suite's referees:* the first build put the boundary
          interval's crowns in the field the boundary node is evaluated in, read
          from a boundary node not yet set, so the sweep lost the newborn's size
          (the adjoint 4.2e-4 from the tangent). That interval is now formed at
          the close, and the two agree to 1.5e-14.
        - *What it trades,* measured on FF16's birth-date coordinate: its raw
          error at the default schedule is 9–25× lumped's (the deep-crown
          anchor +4.6% against −0.49%), on the square law. Extrapolated over
          two rungs it matches lumped in 40% of lumped's time on the size-only
          case, while on the anchor lumped's second halving alone matches it at
          a third of the cost. The height coordinate, plant's default, does not
          move.
        - *Decided* (the user): D applies to every strategy on the birth-date
          coordinate.
        - *Measured,* the split's cost with the spread, timed alone on long
          drought: the split costs no more on the spread than on lumped (+5.0%
          of the gradient against +9.1%). The spread itself costs the gradient
          10.8% and the forward 3%.
     3. *The ladders of 2c:* wet, dry and episodic to u429, and the constant
        record with its front nodes, for both roles and with the quarter-spacing
        move. They pass with square-law ratios near 4, companions reporting
        0.8–1.25 of the error, and the move under ε/3.
        - *Measured* (`measurements/node-rule/`): long-wet and dry pass for both
          roles.
        - Episodic's error is not yet falling over u108–u429, on lumped and
          spread alike. It falls 4.8× from u429 to u857, once the spacing is
          under its dry spells (median 31 days, against dry's 9). So `J`'s
          two-rung report holds from u429 up (the gradients at u857 are not
          run), and a ladder's own ratio (0.76 here) flags a pair that is too
          coarse.
        - Constant's `J` falls at the square law but its gradients do not. The
          shift moves them up to 3ε through its bulk after the first year, which
          no rung refines.
     4. *The invader's own rule.* First, the walk finds the run's node by its
        birth date rather than its position, and refuses an invader it cannot
        map. Today a thinned invader matches no node and walks unsplit, with
        nothing to say so (the split's guard, `design-sign-changes.md` §9).
        Then the thinning, with the selection gradient and the diagonal
        measured, which §14 left open.
        - *Built, the walk:* aornugent/plant#109 (`PLANT-109` `4219616f`, on
          `PLANT-108`). An empty entry at each recorded insertion the invader
          skips; each split node's copy found by its birth date; an invader
          introduced where the run introduced no node refused by name. A thinned
          invader at the stand's traits keeps every member's fitness and split
          count to the bit.
        - *Measured, the thinning* (`measurements/node-rule/`, long drought and
          episodic). The walk is exact: in 36 thinned walks every kept member
          matches the full walk to the bit, and `J′` repeats from its own nodes
          to 9e-16. The emulation misses by 1.2e-7, because a split newest node
          integrates its merged interval's establishment on its own pieces.
        - Rule b at 0.1, each invader's own share of `J′` (the rule decided
          above), saves 36–64% of the walk and sweep and keeps `ln J′` within
          0.13ε. But it moves an elasticity 0.74ε: `recruitment_decay`'s is
          minus `J`'s mean birth date, which leans on the late births b spaces
          widest.
        - One schedule from the nine walks' shares at 0.03 keeps every entry
          within 0.24ε. It saves 48% on long drought but 22% on episodic, under
          the registered 30%.
        - *Measured, the shared schedule chosen from the pilot's three walks:*
          24–25% of a walk's rows saved, nothing fails, and the selection
          gradient by differences on it within 0.004ε of the full sweep. One
          entry misses on long drought: `lma` ×0.5's `recruitment_decay`, 0.43ε.
          Without `recruitment_decay`, a nuisance parameter, the largest entry
          is 0.039ε on long drought and 0.087ε on episodic.
        - *Decided* (the user): the full walk stays the default; the shared
          schedule is the candidate, its miss the birth-date weighting its
          shares lack.
   - *With item 7:* rule A's thinning of the nodes after the window, ⌊√F(b)⌋
     spacings apart, is a node rule, so it is built here, on D's lattice.
   - *With item 5:* nothing. The soil is the nodes' environment, not a node.
   - *Open:* B, graded nodes, stays an option.
7. *The window's weight from a pilot,* through the state weights, and the
   15-day cap from 1c, which is plant's `ode_step_size_max`.
   - *Named:* the code calls each state's weight its tolerance factor: it
     multiplies the state's error level, so a factor above 1 loosens it. The
     fields are `ode_tol_factor_soil`, `_accumulator`, `_times`, `_values` and
     `_max`; the hooks are plant's `tolerance_factors` and odelia's
     `ScalesTolerances`. This spec and the records before the rename say
     weight.
   - *Decided* (1c, combined): Cash–Karp's setting.
     - It is the tied tolerance (the absolute at 1e-4 of the relative), the
       soil ×10 (the accumulators keep a weight of 1), rule A's weight, every
       weight bounded at 100 (`ode_tol_factor_max`), and the 15-day cap.
     - On three pulsed records it saves 31–34% of a gradient run, every
       gradient is finite and every walk runs.
     - Rule A is F(t) = 1/clamp(R̂(t)/R₀, r_min, 1), with R₀ = 0.1, r_min = 0.01,
       and R̂ the pilot's largest R over the stand and `lma`'s range ends
       (`grid-dynamics.md` §8).
   - *Built:* every mechanism, on `state-weights`: the soil's, the
     accumulators' and the time's weights, their bound, and the cap.
   - *Built since:* the setting named once, `control_tf24(tol, base)`
     (aornugent/plant#104, `PLANT-104` `8ba5f7d0`, on `PLANT-103`).
   - *Built since:* the pilot that sets F, `control_window(pilot, invaders,
     base, R0, r_min)` (aornugent/plant#106, `PLANT-106` `4dd30b7a`).
   - *The path:*
     1. *The setting, named once.* G1 of the bank needs its cap on episodic and
        dry (D4), and item 5 takes it as its baseline, so it comes first.
        Plant's defaults today are a 5-year step bound, weights of 1 and no
        weight bound.
        - As TF24's defaults it would move TF24's references, and FF16's too,
          since Control is shared.
        - As one plant function that every run calls, nothing moves.
        - *Decided* (the user): the function, now. Once the setting stops
          changing, after the pilot (2) and the tuning of item 5's threshold,
          it becomes plant's defaults in one commit that blesses the
          references again, and the function goes.
        - *Built:* `control_tf24(tol = 3e-5, base = Control())`, beside
          `control_accurate()` (aornugent/plant#104, `PLANT-104` `8ba5f7d0`).
          It sets the relative tolerance, the absolute one at 1e-4 of it, the
          soil's weight 10, the bound 100 and the 15-day cap, and nothing
          else; the window's weights stay the caller's. The new harnesses and
          gates call it, and the recorded measurements keep their scripts as
          they ran.
     2. *The pilot:* 54 uniform nodes at `1e-3`, which reads R within 10%
        wherever R ≥ 1e-3, on every record, for 0.25–0.32 of a forward's
        member-steps.
        - The walks at `lma`'s range ends now run under the cap.
        - A plant function turns the pilot's per-node offspring, and the two
          walks', into `ode_tol_factor_times` and `ode_tol_factor_values`.
        - It saves 21–23% of rows on the pulsed records, and 1.9% under
          constant rain. There the 53-node causal grid reads R within 1.1%.
     3. *Gates:* 1c's combined pass in plant, with splits on, across the bank.
        Both roles' gradients are finite, every walk over `lma` and `hmat`
        ×0.5–×2 runs, and the accuracy and nudge tests pass.
        - *Held,* on all five records (`measurements/window-pilot/`). `ln J` is
          within 5.8e-5 of the bank's 1e-6 split, every entry within 0.004ε of
          G5's on the harness's window, and no nudge moves a gated entry past 0.08ε.
        - The factors match the harness's within |ln| 0.12, except on episodic.
          There the harness's pilot lost its raising `lma` ×2 walk, plant's runs
          it, and the window stays open longer for 10.4% more rows.
        - The pilot costs what the harness's did, 0.84–1.00 of its rows. The
          runs it serves now step the soil alone, so it costs 0.40–0.80 of one
          on the pulsed records and 1.37 under constant rain.
        - A pilot with the soil alone reads the same window, within |ln| 0.06,
          for 0.31–0.53 of the rows on four records but 0.91 on dry. That misses
          the registered 0.8 on every record, so the pilot stays as gated.
        - *Decided* (the user): the pilot steps the soil alone, and runs only
          where the window pays. Under constant rain the window saves about 2%
          and the soil stepped alone already does ARK's work there (0.97 of
          arkc's rows), so that record takes no pilot. Built by
          `control_tf24()` setting the share (`PLANT-105`), not yet done.
   - *With the split and item 5,* one place each:
     - splits run after the error estimate keeps a step, whatever set its size
       (§9);
     - item 5's block is judged at the smallest weight outside it, the window's
       factor included.
   - *Open:* a shared grid's window must cover every invader of an analysis,
     and one that reproduces later widens it (§8's caveats, unmeasured).
8. *The diagnostics R8 asks for,* built as plant's `diagnose_scm()` (`PLANT-110`,
   on `PLANT-109`), beside `control_window()`:
   - *The error estimate:* runs at every other and every fourth of the run's
     introductions, both ends kept, each with its invaders walked and swept. Per
     quantity, `error` is (Q − Q½)/3 and `ratio` is (Q½ − Q¼)/(Q − Q½), near 4
     where the estimate holds. Only the node knob: node error is about 100× the
     time error.
   - *The distance:* each invader's ln(θ′/θ) per parameter it moves, from the
     resident whose recording it walks. The radius is unmeasured (R6), so it is
     reported, not compared.
   - *The failures:* each run, walk or sweep that throws or is refused is a row,
     with its quantities `NA`, rather than a throw.
   - *Dropped* (the user): the chain's error, which item 5's gates hold inside
     the norm.
   - Run once per analysis, on the final resident and its invaders: the two
     coarser runs cost about three quarters of the run again.
   - *Found building it, open:* on an eight-year stand under constant rain at
     `1e-3`, with the soil coupled at weight 10, the resident's sweep returns
     elasticities of 1e45–1e77 while `J` is right and the invader's walk sweeps
     sane. Plain control, the cap and the bound alone are fine, and so is
     `3e-4`; at rain 1 it is −2.8e24 at `1e-3` and −31 at `6e-4`. The soil
     stepped alone, now `control_tf24()`'s default, removes it at every
     tolerance tried. No refusal fires. Not root-caused; the hypothesis is steps
     held at the soil's stability edge, where the error test bounds the forward
     and nothing bounds the sweep.

*From here,* with the split closed out (`design-sign-changes.md` §9):
1. Item 7's setting (7.1), since item 5 takes it as its baseline and the bank's
   G1 needs its cap.
2. Item 5.
3. Item 7's pilot (7.2) and item 6, in either order; item 6 starts with its
   sort's design turn.
4. Item 8.

The stack's PRs and merges stay the user's call.

Out of scope: the second-order adjoint, and splits at class switches, which
carry nothing measurable on their own
(`archive/oracle-consultation-solver-performance.md`).

### The acceptance suite: the objectives as tests

Designed, and its build is held until the user starts it. It lands in plant's
tests beside the build it accepts, and asserts only what `OBJECTIVES.md`
asserts, so a better controller passes without a test edited.
- *Three rules keep it from fixing today's design in place.*
  1. It asserts the objectives' bounds and nothing else: error ≤ ε, nudges
     ≤ ε/3, an error estimate within 0.5–2× of the true error, no throws, and
     rows no more than brute force's at the same error. Never a step count, a
     binding component, which rule fired, or a pinned `J`.
  2. Its reference is brute force, not today's controller: one converged answer
     per fixture, regenerated only when plant's scientific surface changes (its
     model-version snapshot).
  3. Each fixture's ε is set as `OBJECTIVES.md` sets it: a tenth of the spread
     over a few weather seeds of that fixture, computed once with the
     references, and never under 0.01 for an elasticity.
- *A fixture* is one record on about 20–27 nodes, with the resident and invaders
  at ×0.5 and ×2.
  - The reference script also checks that the fixture still shows what is
    guarded: crossings, soil-bound steps, a dry spell long enough to reach the
    15-day cap, and invaders at the range's ends.
  - Every run takes both roles' full gradients, so one sweep each checks all 48
    elasticities.
- *The runs:* the base; `tol` ×1.05 and ×0.95; the introductions shifted by a
  quarter spacing; and a looser companion, which becomes the controller's own
  estimate once R8's diagnostic exists.

| objective | compared | bound |
|---|---|---|
| R1, accurate | the base against the reference | ≤ ε per quantity |
| R2, reproducible | each nudged run against the base | ≤ ε/3 |
| R4 and R8, predictable and diagnosed | the estimated error against the true error | within 0.5–2× where the true error is above noise |
| R3, continuous | two nearby invaders on one recording: their chord against the mean of their gradients | ≤ ε/3 |
| R5, never fails | invaders at the range's ends, the resident at ±10% | no throw |
| the diagonal | the invader's `J′` against `J` at the resident's traits | bit-equal |
| R7, performant | rows against brute force's at the same achieved error | no more |

- *Tiers.*
  - Every edit, seconds: each build's own component checks, such as the
    interpolant's order, the adjoint against differences, weights of one
    changing nothing, and the implicit stepper's order.
  - Before a push, under 3 minutes serial: one fixture and the table. That needs
    a forward of about 5 s, from fewer nodes and a shorter lifetime or a
    faster-maturing fixture species, with `J` still earned inside the run (on
    the bank, from about year 11 to 29).
  - Nightly or before a merge, about 15 minutes: three fixtures (pulsed, wet,
    constant rain), the node knob at n against 2n, one curvature, and a seeded
    sweep of invader traits. A trait point that ever fails joins a list rerun
    every time.
  - Milestones, hours: the bank, which is phase 4.
- *An objective not yet met is skipped with its reason, not dropped.* A build is
  accepted when its skip comes out and the test passes, so the skips list what
  remains: reproducibility at a loose `tol` until the splits land, for one.
- *`tol` stands in for the target.* Until the controller takes an accuracy
  target, the tests drive it through `tol`. When it takes one, `tol` leaves the
  tests and nothing else changes. Finding the operating point is phase 4's; the
  suite checks the bounds wherever the controller lands.
- *Cost:* about 300 lines in plant's tests (a fixture helper, the property
  tests and the reference script), with no dependence on plant-dev's harness.
  The references take 1–3 CPU hours once.
- *Rejected:* pinned-output snapshots, fast but broken by every controller
  improvement; and the bank alone, the right checks at hours a run.

### Later: investigations held open

- *The wobble.* On a frozen grid, with the leaf solve exact, `ln J` departs
  from a smooth curve in `lma` by up to about 1e-7, in a slow wave, alike in
  every variant of the split, and the `lma` elasticity wanders by about 1e-3
  (up to 2e-3) with it (`grid-dynamics.md` §18). It shrank tenfold when the
  positive part's width went from 1e-4 to 1e-3, against the splits reply's
  account, and what carries it is not traced. It costs a gradient at most a
  tenth of the smallest ε (0.01) and a hundredth of `lma`'s, and a chord at r
  of `1e-2` or more about 0.05 of the curvature's; it matters only below r =
  `1e-2` or for a pointwise second-order adjoint, which is out of scope. When
  it is picked up: the gradient's wobble at the seventeen points (phase 3, item
  4), then a scan at `storage_prod_eps` 3e-4.
- *The positive part's width as part of the model: the user's decision.* On
  the split's pinned program `ln J` moves by −0.228 from `storage_prod_eps`
  1e-4 to 1e-3, and by +0.0165 (0.65ε) from 1e-4 to 1e-5, so 1e-4 sits about
  0.7ε below a sharp cutoff if the fourteenfold fall a decade holds
  (`grid-dynamics.md` §18). The crossings' turn is too brief to carry it, so
  it would come through time spent with net production near zero (inferred). Either the width is part of
  TF24's definition, as now, or it narrows; how the wobble moves with a
  narrower width is unmeasured.
- *The error both arms share below `3e-5`,* which stops `J`'s error falling,
  and the class switches the split leaves uncut.

### Phase 4: on the bank

1. *The four tests at ε* for forward runs and both roles' gradients, on every
   record of the bank, with the runtime against the floor's at matched error.
   *The operating point* splits the error budget about 2:5 between time and
   nodes (`geometry.md` §6). With the splits in, `tol` loosens until the gradients'
   spread under nudges meets ε/3: about `3e-4`, if it grows in proportion from
   0.06–0.28 of ε/3 at `1e-4`. The saving goes to graded nodes, with a second
   rung read for their error.
2. *Local analyses, each on one grid within its radius:* invader landscapes
   over ×0.5–×2, the resident within ±10%, the selection gradient, and
   curvatures. Where a radius falls short, several grids or a finer one,
   whichever costs less, with brute force the fallback. The invader's radius is
   measured first, at ×0.5, 0.7, 1.4 and 2 against brute force. The cheaper side
   should meet it first, since its weight spreads later in b, where the mesh is
   coarser (`geometry.md` §5). Curvatures come from the adjoint: once the
   splits make `J` smooth on a grid, a chord of two split gradients gives a
   whole row of them for two gradient runs (phase 3, item 4), and a forward
   second difference checks a row's diagonal entry (`grid-dynamics.md` §17).
   For an invader's row the perturbation is nearer `1e-3`, since `J′` has large
   higher derivatives (`assessment.md`, step 5). The second-order adjoint is out
   of scope.
3. *The optimising loop:* one resident run serving many invader evaluations,
   with refinements frozen per grid and the grid rebuilt on big moves.

Finished when 1–3 pass on the bank.

### After: performance

These follow the arc without blocking it. Each is engineering with a known
gain, and each multiplies with the rows the arc saves.
- *The sweep, about 2×* (`docs/measurements/perf-sweep.md`):
  - the zero-depth pulses no longer split the descent (19%);
  - the crown's light quadrature comes off the tape (20–24%);
  - the collar's slope is stored with the recorded collar (8.5%);
  - three smaller items follow;
  - the rebinds at the introductions: 4.8% of the sweep at u108 and `1e-4` on
    the split build, twice an introduction, nearly all of it each leaf's
    vulnerability tables rebuilt at the active scalar. Cloning the tables
    would take about two thirds of it (`perf-sweep.md` §5).
  - Check first that the invader's sweep has the same profile. The first item is
    #96, which lands before the splits (phase 3, item 1).
- *The forward's and the walk's cost per row:* the inner solve warm-started as an
  index-1 algebraic variable.
- *The refused gradient* at u108 under `ode_tol_rel = ode_tol_abs = 1e-3`.
- *A schedule set by a pilot, not a general one* (the algorithm reply,
  `oracle-response-grids.md`). A cheap pilot's adjoint and field map would set
  the step weights per state and time, the creation times and the error budget
  for the base run, and the next θ₀ would reuse the base as its pilot. What to
  carry: its passes informing each other, the budget per quantity with the
  binding one deciding, and the warm start's three sources (stage, step,
  recording). What the record contradicts and must be measured first: a
  non-uniform grid converging on the square law (graded ladders gave ratios
  2.8–3.3), and a single rung corrected by the map, which predicts only the move
  to a grid dropped from the run. Its first measurements: `|λ|` weights against
  the weighted norm, and a map-corrected single rung against two rungs.

## The user's decisions

- *The node rule:* D, the spread, is in the build. B stays an option to consider
  later, since there may be cases where grading helps (2a).
- *The multirate soil step (1e)* is in the build. Tuning it, its threshold
  included, waits for the later task of building general scheduling heuristics.
  - Its design (`design-soil-alone.md`) is accepted with its defaults: the
    program's two list fields with the setter's length check, ARK's branches
    kept on the forks unmerged and marked retired, and the threshold's tuning
    deferred now that the floor is measured at 0.001ε.
- *Cash–Karp's setting is named once,* as a plant function (item 7, step 1).
  Once it stops changing it becomes plant's defaults, the references blessed
  again in one commit.
- *The crowns' height sort* is agreed in principle, and is designed in a turn of
  its own before it is built (2b).
- *The acceptance suite* is part of the design; its build waits for the user's
  go.
- *The two workflows, in order* (the events consult): first the resident's
  gradients with stable, efficient curvatures; then convergent, cheap invader
  gradients for an optimiser.
  - No trait is special, and which curvatures the work needs is open, so stable
    curvature estimates are asked of the solver and controller in general.
  - The invader loop expects tens of invader evaluations per resident run when
    the gradient is informative.
  - *Equilibrium residents belong to the invader workflow only.* There the
    resident is solved to its demographic equilibrium (`J = 1`) before invaders
    are run against it, and again after an invader is adopted. The resident
    workflow does not assume equilibrium.
  - What the optimiser needs between evaluations is left to the events reply.
- *The build's order* is phase 3's, after the events reply: the stack first,
  then the splits in the forward step and in the sweep, then curvatures, then
  the multirate soil step and the node rule. After the splits and algorithm
  replies: finish the splits in the forward step, then build them in the sweep.
- *The leaf solve stops at adjacent floats* (after the tightened build's
  tests), for 10% of a replay.
- *Item 3's cost:* the sweep through a split run at 7.3% over plain's, against
  S5's 6%, is accepted. The split's own work is 4.0% of plain's sweep, about
  what the method needs.
- *The wobble is held open* as a later investigation; the adjoint workflows go
  ahead with chords at r of `1e-2` or more.
- *Names.* The *sign change* of a node's net production, and *splitting* that
  node's step there. odelia needs no new noun: it speaks of a state's
  components, and plant says which are a node's. "Event" stays plant's word for
  its discrete actions (`plant/events.h`).
- *Curvatures come from the adjoint,* as chords of split gradients; `lma`'s row
  is one example. Forward second differences are only a check. The second-order
  adjoint is out of scope.
- *The pair:* Cash–Karp everywhere, invader runs included, with its own
  fourth-order extension as the dense output. Dormand–Prince is dropped.
  - The earlier plan, Dormand–Prince for runs that host invader gradients, rested
    on its free interpolant.
  - Phase 1b found Cash–Karp has one that matches the quintic for 5.9% of a
    forward, and Dormand–Prince worse on TF24 in rows, error and stage
    rejections.
- *The local analysis* is invaders over ×0.5–×2 and the resident within ±10%
  (`OBJECTIVES.md`).
- *Elasticities' ε is at least 0.01* (`OBJECTIVES.md`).
  - An elasticity off by δe moves `ln J`'s prediction over a move Δ ln θ by
    δe·Δ.
  - Over the invader range, Δ is up to ln 2. So δe ≤ (ε/3)/ln 2 = 0.012 keeps
    every prediction inside `ln J`'s own reproducibility bar.
  - That bounds what an optimising loop loses. It does not resolve the sign of an
    elasticity under 0.01, which inference about weak selection on that trait
    would need: such a study runs that trait at a tighter setting.
- *A grid serves its radius, and an analysis still covers its range*
  (`OBJECTIVES.md`, *Shared*): with several grids, each within its radius, or
  one finer grid, whichever costs less. The controller does its best on every
  record, and brute force is the fallback.
  - The case in view is the constant record's invader. With nothing to thin the
    canopy, a slightly better invader takes it and a slightly worse one is shut
    out: `J′` is 938, 289.3 and 0.0017 at `lma` e^{−0.01}, ×1 and e^{+0.01}.
  - The landscape is smooth once the front is resolved, and the invader's
    elasticity at θ′ = θ meets its ε. But the cohorts that earn `J′` end at 2.2,
    0.12 and 0.012 years at ×0.5, ×0.99 and ×1.01, so the grid built for θ′ = θ
    cannot be assumed to serve the range.
  - A grid's radius is the largest move over which the four tests hold at ε
    (`docs/assessment.md`, step 4(c)). |g|/|g′| says only how fast the
    landscape bends, not how far a grid serves.

## Running it

**Session start** (AGENTS.md): `git submodule update --init --recursive`, and
`add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**A private library,** with `DEV` under the scratchpad:

```bash
mkdir -p $DEV/lib_stack
git -C odelia     fetch origin claude/trusting-curie-4i9n3l
git -C odelia     worktree add --detach $DEV/odelia05 origin/claude/trusting-curie-4i9n3l
git -C phylloptim worktree add --detach $DEV/phylloptim09 378b083
git -C plant      fetch origin PLANT-95
git -C plant      worktree add -b PLANT-95 $DEV/stack origin/PLANT-95
export R_LIBS=$DEV/lib_stack MAKEFLAGS=-j4
for pkg in odelia05 phylloptim09 stack; do
  R CMD INSTALL --no-docs --library=$DEV/lib_stack $DEV/$pkg > $DEV/install_$pkg.log 2>&1 || { echo "FAILED $pkg"; break; }
done
```

- **Build times.** odelia builds in 26 s and plant in about 3 min.
  - After an odelia edit, reinstall plant with `--preclean`: it compiles
    odelia's headers and does not track them.
  - A new value exposed to R needs an entry in `inst/RcppR6_classes.yml`, and
    `RcppR6::RcppR6()` before the rebuild.
- **The v12 build** with zero pulses as step targets merges the two branches,
  one at a time, and `harness/` runs on it:
  1. `git -C plant worktree add -b v12-targets $DEV/v12t origin/PLANT-95`
  2. `git -C $DEV/v12t merge origin/PLANT-96` (a fast-forward)
  3. `git -C $DEV/v12t merge origin/PLANT-97`, keeping both `NEWS.md`
     entries in the one conflict
  4. Install odelia05, phylloptim09 and `$DEV/v12t` into a library of their
     own.
- **The probe build** is `harness/tf24_probe.patch` applied to v12t. It adds
  the driver's `CLASS_EVENTS` and `CLASS_LOG`, a wider positive part
  (`TF24_PROD_EPS`, `TF24_PROD_EPS_REL`) and a settable stage guard
  (`TF24_DOMAIN_TOL`).
  - Apply it with `git -C $DEV/v12probe apply "$PWD/harness/tf24_probe.patch"`
    from the plant-dev root.
  - It puts the leaf's operating-point class in the thirteenth auxiliary.
  - With the default environment it reproduces v12t bit for bit.
- **Tests** run with `TESTTHAT_PARALLEL=false`, by AGENTS.md's tiers:
  `testthat::test_file(..., package = "plant", load_package = "installed")`
  after `library(odelia)`.
  - On `PLANT-95` the full serial suite passes 4651 and fails 2, in 9.1 min;
    odelia passes 325.
  - The two failures are older than #95: `test-mutant.R`'s "mutant method
    works" on FF16's ten-mutant panels, which are pinned to `develop`.
  - odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced
    list to a `std::span` parameter, which this compiler refuses.

**The harness.**
- `long_drought.R` holds the record generator and `run_J`.
- `ark_prototype.R` is an R driver that reproduces plant's Cash–Karp run bit
  for bit, with options for step rules and replays (see its header).
- `run_record.R` runs one stand and its invader on one record, with their
  gradients, and saves everything a later analysis reads. `spot_check.R`
  checks a directory of those runs against `docs/measurements/eps.csv`, and
  `error_structure.R` reads how their errors scale and where the node error
  lives. `first_panel.R` splits a record's first node spacing, or takes a
  schedule, and reports `J`, the surviving founders, the invader's gradient and
  its one-sided slopes. `graded_times.R` writes the schedules of step 4's second
  tests, and `node_parts.R` splits `J`'s move between nested schedules into its
  field and quadrature parts.
- `curvature.R` takes reverse-mode gradients at `lma·e^{±δ}` on one grid, for
  the curvatures of steps 1, 4 and 5.
- `rows.R` scores the driver's runs in rows, and `attempts.R` reads their
  attempt logs.
- `stability.R` gives each pair's stability and positivity limits on a pool's
  test equation.
- `v12_steps.R`, `error_channels.R`, `j_error_trace.R` and `soil_bound.R`
  record and decompose a run's steps and errors.

**Known behaviour.**
- *One `J` is one draw:* moving tol by 3% moves plain Cash–Karp's `J` error by
  2e-4. Compare treatments by nearby tolerances or by their channels
  (`harness/error_channels.R`), never by one run.
- *A split reference stops converging near its resolution:* split 8, 16 and 32
  ways, the driver's 1e-6 grid moves by 3e-5 in `lma` and 1.3e-4 in `a_dG2`.
- *The reference for long drought at θ₀ is `J* = 12.6687135`,* from Cash–Karp
  at `1e-8`. The run at `1e-6` is 6.1e-6 low.
- *A TF24 run at the default tolerance carries its own time error,* about 0.1%
  on five-year stands. Compare against a run integrated to `1e-6`.
- *`lma`'s pinned difference has a floor near 1e-5,* on residents too.
- *A crossing step often holds class switches too:* split them apart before
  blaming either.
- *A switch smoothed within a step is still a kink to the integrator.*
- *The pool's kink is a difference of slopes:* its rate has slope `(1 − G)(1 −
  r)` in net production above zero and `r` below, so the jump vanishes near
  `r = 0.2`.
- *A crossing correction needs the crossing from the stages, and a sharp
  switch.* From the step's ends the crossing's place misses by a tenth of the
  step. A node whose net production moves less than about 100ε across the step
  has no kink at the step's scale.
- *A correction put on the tape must be zero in value,* or the sweep no longer
  repeats the run's values.
- *Retaking an interval from the reference's state measures its local error
  only:* the survival error arrives with the state.
- *On pulsed records the soil has no fast mode to separate:* drainage goes as
  `θ^16.14`, so after rain a layer's relaxation rate is about one over the time
  since the rain, and held to the norm's tolerance an implicit soil keeps its
  steps. ARK's longer steps there were inaccurate, and on one its embedded
  estimate put the top layer's error at a fifteenth of its size. Under constant
  rain the soil is stiff and the implicit soil pays (`grid-dynamics.md` §7).
- *A replayed input must be exact:* TF24's leaf solve turns a one-ulp
  difference upstream into 1e-9.
- *A slot's choices are a sequence:* TF24's leaf points are read in order, so
  only a full evaluation may read a full evaluation's slot.
- *Two clocks:* a step's `at_state` ran at `fl(t + h)` from the row below. After
  an entry the solver keeps the recorded time, and the System's clock must
  agree to 2 ulp.
- *An invasion's recording pass re-runs the run,* and reproduces it only while
  nothing between the two calls changes the SCM.
- *A zero pulse is not an entry,* even at an introduction's time. `entries()`,
  `size`, the walks and `event_log` never see it.
- *A lambda returning an active product needs `-> value_type`:* a deduced
  return type hands back an expression template over dead operands.
- *R reads a script as it runs:* run from a snapshot.
- *`queue.sh` needs absolute paths.*
