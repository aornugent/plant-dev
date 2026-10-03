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
  pools are unstable past 26. A 15-day cap prevents it (phase 1c).
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
- events and sub-steps live inside `Step` and have no handle on the global
  step's size.

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
  events;
- per-member events, with the crossing times differentiated: R2 and R3;
- the 15-day cap: R5. Under Cash–Karp it protects every walk for at most 2.4% of
  the window's saving (phase 1c), so invader sub-steps are deleted;
- an implicit chain: R7. The explicit chain takes ×10 but not ×100, and where
  stability binds (constant rain) only the implicit chain pays: 60% against
  4.7%;
- the node rule with its companion: R4 and R8;
- a pilot: R7, for the window.

*Deleted:* the PI law, the chain seeds and the chain guard (they cut forward cost
only, and are even or worse in rows); the crossing, onset and transit caps; the
stability margin; the held collar and the partition; class-switch events;
refusals for kinks.

**What this settles:**
- no partition, and no caps (the 15-day cap aside), seeds or margins in plant's
  controller;
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
  implicit chain.
- *The build:* a dense output, events and their adjoint, in odelia's step and
  sweep.

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
    fallback, and is being built now.
  - Before the implicit chain is built in odelia, two things remain. The chain
    alone's error estimate goes into ARK's norm, to see if `3e-5` then converges
    (about −51%). Then the invader under it.
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

### Phase 2: the node axis

- **2a. B or D,** the user's decision. D changes plant's birth-date competition
  sum and every reference, and its cost objection is gone.
- **2b. The light field's ordering test,** given a tolerance or replaced by a sort
  before the prefix pass, in plant. Either rule needs it at 215 nodes and more.
- **2c. The chosen rule's ladders** on wet, dry and episodic (D's to u429), and
  the constant record with its front nodes, with the introductions also moved by
  a quarter spacing (R2's other knob). *Pass:* square-law ratios near 4,
  companions reporting 0.8–1.25 of the error, and the quarter-spacing move under
  ε/3, on every record and for both roles.

### Phase 3: the build

Stacked changes on the plant and odelia forks, each with its own tests, and
bit-identical wherever its default is off (AGENTS.md):
1. the chain's treatment from 1a. Its mechanism, a weight per state in odelia's
   controller supplied by plant's patch, is built (`state-weights` on both
   forks), and reproduces the driver's weighted runs bit for bit;
2. the dense output from 1b: Cash–Karp's own fourth-order extension, from its
   stages and the end's rate;
3. per-member events, in the forward and the sweep: the invader's structure is
   frozen per grid, and the crossing times are differentiated. They read the
   step's continuous extension through one interface each stepper supplies.
   For Cash–Karp it is its own quartic. For ARK, order 3 is free, and may be
   enough by phase 1b's rule; order 4 costs an extra stage on crossing steps.
   The field check on an ARK grid decides (`grid-dynamics.md` §11);
4. the window's weight from a pilot, through the same mechanism's schedule, and
   the 15-day cap from 1c, which is plant's `ode_step_size_max`;
5. the node rule from phase 2, with its companion;
6. the diagnostics R8 asks for: the companions' estimate, θ's distance from θ₀
   against the radius, the failures, and the chain's error.

### Phase 4: on the bank

1. *The four tests at ε* for forward runs and both roles' gradients, on every
   record of the bank, with the runtime against the floor's at matched error.
2. *Local analyses, each on one grid within its radius:* invader landscapes
   over ×0.5–×2, the resident within ±10%, the selection gradient, and
   curvatures. Where a radius falls short, several grids or a finer one,
   whichever costs less, with brute force the fallback. The invader's radius is
   measured first, at ×0.5, 0.7, 1.4 and 2 against brute force. Once events make
   `J` smooth on a grid, curvatures have three routes:
   - chords of gradients, about 68 forwards for five traits in both roles;
   - forward-over-reverse, about 26;
   - forward second differences, about 10.
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
  - three smaller items follow.
  - Check first that the invader's sweep has the same profile. The pulse change
    touches the rows that events extend, so it lands before events if both are
    in flight.
- *The forward's and the walk's cost per row:* the inner solve warm-started as an
  index-1 algebraic variable.
- *The refused gradient* at u108 under `ode_tol_rel = ode_tol_abs = 1e-3`.

## The user's decisions

- *B or D:* evaluated at phase 2a.
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
