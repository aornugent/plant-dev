# Sign changes in TF24's net production: the problem, reformulated, and its ledger

Paths: `PD=/home/user/plant-dev` (docs, harness, OBJECTIVES.md, AGENTS.md),
`DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev`.
Section marks (§) are `PD/docs/grid-dynamics.md`'s unless named.

## Part 1. The problem as mathematics

### 1.1 The system

The state is y = (x_1, ..., x_N, s). N is about 108 node blocks x_i (a cohort
of plants born at b_i, about 20 components each: height, mass pools, storage,
density, mortality and fecundity integrals), contiguous in y, followed by the
environment's state s (5 soil layers, 5 accumulators). The rates are

    dx_i/dt = F(x_i, E(y,t), t; theta, sigma(P_i)),
    P_i     = P(x_i, E(y,t), t; theta),
    ds/dt   = G(y, t; theta).

- E(y,t) is the field every node reads: the light field (65 knots in relative
  height, built from every node's height and leaf area) and the soil's water
  potentials. One rate evaluation builds E from every node, then rates every
  node, then the environment.
- P_i is node i's net production (kg/yr). Rating a node needs its leaf solve
  (inner root-finds), which a run records and replays as solved values.
- F, P and G are smooth at the step scale. The leaf's class switches are C0
  kinks in the leaf solution, measured to carry nothing. The soil's floor and
  saturation are not met on accepted steps.
- sigma is TF24's smooth positive part,
  sigma(P) = (P + sqrt(P^2 + eta^2))/2 with eta = 1e-4 kg/yr
  (`storage_prod_eps`, `tf24_strategy.h` ~line 1990). Growth (height,
  fecundity) and the storage pool's charge, drain and relaxation read P only
  through sigma.

### 1.2 The switch, in numbers

- sigma is analytic, but its curvature sits in the band |P| < eta, where
  sigma''(0) = 1/(2 eta).
- A node crosses the band in tau = eta/|dP/dt|. For the nodes that carry J
  that is about 2e-7 yr. At the slowest crossing on the record
  (|dP/dt| = 0.0033 kg/yr^2, node 24, 0.6% of J) it is about 0.03 yr.
- Steps at crossings: median 0.57 days (1.6e-3 yr) at tol 3e-5.
- So kappa = h/tau = h|dP/dt|/eta runs from about 0.05 (the band resolved by
  the step) to about 1e4 (a kink at any step size). Where kappa >> 1, the
  rate's time derivative jumps across the crossing by
  dF/dsigma * dP/dt, because sigma' goes from 0 to 1.
- Members spend 9.1% of member-time with |P| < 0.01 kg/yr and 16% with
  |P| < 0.1 (archive `oracle-consultation-solver-performance.md`, T15). Which
  members, and at what sizes, is not recorded.
- The width is part of the model. On one program, ln J is 2.55559, 2.53914 and
  2.31110 at eta = 1e-5, 1e-4 and 1e-3: 0.65 eps a decade near 1e-4, and
  9 eps at 1e-3.
  - A relative width eta_j = 0.05 P_b,j moves J by +3.9% (T15).
  - Replacing sigma by its branches (P above zero, 0 below) moves ln J by
    -1.5e-3, and makes the curvature move 8.2 eps from r = 1e-2 to 1e-3
    against 0.54 eps (§18).

### 1.3 The continuous map theta -> Q

Q is ln J, each elasticity d ln J / d ln theta, and the curvatures.
- In the sharp limit (eta -> 0) the field is Lipschitz and continuous across
  each switching surface S_i = {P_i = 0}, and its Jacobian jumps there. The
  saltation matrix is the identity, since the field itself does not jump. So
  dy/dtheta is continuous in t and theta, and ln J is C2 in theta wherever
  every crossing is transversal (dP_i/dt != 0).
- Where a dip's two crossings merge (a tangency), ln J has a square-root
  singularity in its second derivative. That is the model's own.
- With eta > 0 everything is analytic. Where kappa >> 1, the sharp-limit
  picture holds at the step scale.

### 1.4 The discrete map on a frozen mesh

On the recorded program M (step ends t_0 < ... < t_n), Cash–Karp gives
Phi_M : theta -> Q_M(theta).
- Every step samples each node's sigma(P_i) at six stage abscissae,
  c = (0, 1/5, 3/10, 3/5, 1, 7/8). The end's rate is the next step's first
  stage (FSAL), and with it Cash–Karp has a free fourth-order dense output (§11).
- *Raw stages are O(h^2) wrong as point values.* The method's order comes from
  the weights' order conditions, not from the stage states.

For one node crossing inside a step at u* = (t* - t_n)/h, with kappa >> 1:
- *The local error* is about h^2 |dF/dsigma * dP/dt| psi(u*). psi is piecewise
  quadratic in u*, breaks at the c_k, and averages to zero over u*, since the
  weights integrate low-degree polynomials exactly.
- *Its theta-derivative* is O(h) per crossing. It is piecewise linear in t*
  and jumps by b_k h |dF/dsigma * dP/dt| dt*/dtheta each time t* passes a
  stage abscissa: a staircase in theta on a frozen mesh.
- *Over about 9000 crossings at random u*:*
  - the value errors average out (J's time error is 1/2000 of eps at 3e-5);
  - the gradient's error is a random-signed sum of O(h) staircases;
  - any knob nudge reshuffles every u*, so the gradient's spread under nudges
    is that sum's spread, and the heaviest crossings dominate it (it is a
    variance);
  - a second difference or a chord at r averages the staircase over +-r.

### 1.5 The objectives as conditions on Phi_M

Metric: d(Q, Q') = max over quantities |Q - Q'|/eps_Q (`OBJECTIVES.md`,
`docs/geometry.md` §2). "Within eps" is the unit ball, "reproducible" the ball
of 1/3.
- *J:* |ln J_M - ln J*| < 0.025. The kink contributes nothing measurable.
- *Gradients:* each elasticity within eps of the converged one, and moving by
  less than eps/3 under tol +-5% or a quarter-spacing shift of the
  introductions. eps: resident lma 0.087, a_dG2 0.019; invader lma 0.20, a_dG2
  0.050; floor 0.01.
- *Curvatures:* within eps (resident lma 1.17, invader lma 4.0), reproducible
  under the same nudges, from chords of gradients (or second differences of
  ln J) at the workflow's r (about 1e-2).
- *Continuous in theta on one frozen mesh* within its radius; *never fails*;
  *J' = J on the diagonal*; *diagnosed*; *the least runtime at matched error*.

### 1.6 The measured map, plain and treated

Long drought, 40 years, 108 uniform nodes, tol 1e-4 tied, unless stated.
- *Counts:*
  - 14 840 steps and about 810k node steps;
  - 9247 node steps (1.1%) hold a sign change, in about 726 steps (4.9%), so
    crossings cluster in time;
  - every node but the last changes sign, a median of 82 node steps each and
    at most 186;
  - 14 node steps, in 12 steps, hold a pair (a dip below zero and back)
    inside one step, 12 of them at pulse onsets. (417 is the number of node
    steps the golden search looked in, not the pairs it found.)
- *Plain, the largest move under seven tol nudges (in eps/3):* d_I 1.261,
  a_dG1 1.048, a_dG2 0.906, lma 0.477. The kink is 70–85% of it (§11).
- *Plain's curvature (ln J in ln lma, second differences), its spread under the
  nudges:* 2.59 eps at r = 3e-3, 0.56 eps at 1e-2, 0.10 eps at 3e-2 (§17).
- *The record's remedy without a treatment:* tol 1e-5, about +41% leaf solves
  over 1e-4.
- *Global step ends at every crossing* (archive
  `oracle-consultation-solver-performance.md`, T12): about 8600 located,
  1.33e7 + 1.75e6 node ratings at 1e-4 against plain's 4.6e6, so 2.9–3.3×
  plain.
- *Restricting a treatment by weight* (§9): limited to the cohort born before
  3.6 and to t < 25, the crossings (1212 of 9235) carry about 60% of J's kink
  error; every member before t = 25 keeps all of it.
- *The incumbent* (a per-node cut, below) on the same setting:
  - nudge moves d_I 0.282, a_dG1 0.174, a_dG2 0.138, lma 0.058 (eps/3);
  - curvature spread 0.23, 0.05 and 0.002 eps at r = 3e-3, 1e-2 and 3e-2;
  - J 10× nearer the reference than plain;
  - forward +6.0% and sweep +7.3% over plain;
  - at matched gradient stability, 0.77 of plain at 1e-5.

### 1.7 Prices

- A forward at 1e-4 takes 64–66 s: about 80k evaluations and 4.4e6 node
  ratings, so a node rating (with its leaf solve) is about 15 us.
- A row (one accepted step across every node) is about 4.4 ms, about 290 node
  ratings.
- A gradient run pays every cell about seven times: forward 1, sweep 2.6,
  invader walk 0.8, its sweep 2.6. A rejected attempt is paid once, by the
  forward.
- The incumbent's split costs 0.38 ms per split node step, about 26 node
  ratings. It needs about 12 node ratings (two pieces of six stages), the end
  rated again, and five field reads per split step.

## Part 2. The ledger (outcomes, with quantities)

R1 *Gradients are accurate and reproducible at the cheapest tol.* At 1e-4
   (and, if it holds, 3e-4, about 1.2x fewer steps), every elasticity moves
   less than eps/3 under seven tol nudges within 5% and a quarter-spacing
   shift of the introductions. Plain fails at 1e-4 (d_I 1.261, a_dG1 1.048);
   the incumbent passes (0.282, 0.174).
   - *Correction found during the search (to verify):* §11's table used each
     trait's unfloored eps. With OBJECTIVES.md's 0.01 floor, d_I's eps is
     0.01, not 0.00047, and its move is about 0.06 eps/3. One proposer
     re-measured plain at 1e-4 with the floor: a_dG1 1.05,
     storage_relaxation_offset 0.98, a_dG2 0.91, TF24_cost_scale 0.90 and
     lma 0.48 eps/3. So plain fails R1 narrowly, on a_dG1 alone.
   - *Also found:* the incumbent does not meet R7 as worded. Its invader walks
     are unsplit, so on the diagonal ln J' - ln J is 3e-5 to 7e-5.
R2 *Curvatures are stable at the workflow's r.* A chord of two gradients at
   theta e^{+-r} is reproducible within eps/3 and within eps of the converged
   value (-43.45 for the resident's lma entry, eps 1.17) from r about 1e-2.
   Plain at 1e-2 moves 0.56 eps (fails) and at 3e-2 0.10 eps (passes). The
   incumbent moves 0.05 eps at 1e-2.
R3 *Continuous on a frozen mesh.* Within the radius, ln J has no jump above
   1e-8 as a sign change passes from one step to the next or a pair merges. A
   replay's own noise is 8.5e-15. (The user accepted this wording in place of
   "a 32-point scan of each step finds no pair uncut".)
R4 *The sweep returns the derivative of the run's own map:* within 2e-3 of
   central differences in an elasticity.
   (Challenged upward: is exactness needed, or "a gradient within eps of the
   converged one"? Default: exact, since it keeps J, its gradients and their
   chords mutually consistent for root-finding on the selection gradient.)
R5 *J is not degraded:* ln J within eps (0.025), and J's error falls with tol.
   Today the time axis holds 1/2000 of eps.
R6 *Never fails:* nothing throws over the trait box, for residents or invaders.
R7 *Invaders:* J' = J to the last bit on the diagonal. An invader walks the
   resident's recorded rows and evaluates in the fields the resident recorded.
   Invaders' own crossings are not treated today. The selection gradient's
   chord is smooth (0.02–0.04 eps under nudges). The invader's curvature row
   depends on r. (Open: whether invaders need a treatment.)
R8 *The least runtime at matched error.* Bar: the incumbent, forward +6.0% and
   sweep +7.3% over plain, accepted by the user.
R9 *Least code, least reader load* (the user's principles, `principles.md`;
   `PD/AGENTS.md` code style):
   - least code, a flat call hierarchy, one source of truth per decision,
     minimal threading, the domain in data structures;
   - concrete names: write what happens. The user: "I hate the semantics
     'parts', 'RatesParts'";
   - only doubles cross into R; no near-copies of an existing path; a concept
     and `if constexpr`, not runtime capability flags; nothing stored that can
     be derived; no guarantee dropped.
   - The incumbent: odelia +1117/-30 lines in 6 files (`ode_step.hpp` +514),
     plant +605/-37 in 20 files, plus phylloptim. Its review's verdict was
     "rethink the orchestration".
R10 *Off is bit-identical:* with the treatment off every run repeats bit for
   bit, and FF16 and the other models are untouched. TF24 opts in alone
   (TF24f out).
R11 *Diagnosed:* each run reports what it treated, per node, counted on
   committed steps.
R12 *Layering:* odelia knows state components, not nodes; the model names
   which components belong together. (Challengeable upward.)
R13 *Model fidelity:* the rates stay the model's own, sigma with eta = 1e-4
   included. A candidate that changes the model must state the change in ln J
   and in elasticities (in eps) and route it to the user as a modelling
   decision. TF24 is the user's group's model.

## Part 3. What exists

- *odelia* (C++ headers and an R package), `DEV/sw/odelia`.
  - The incumbent is at `1e5a2d7`; the code before the treatment is at
    `a62e97c`.
  - It solves a System concept: ode_size, set_ode_state, ode_state, derivs,
    and optionally solved values each evaluation stores and loads.
  - Step: Cash–Karp RK5(4), six stages, an embedded error estimate, and the
    fourth-order dense output.
  - Solver: adaptive control with per-component error weights, or a pinned
    program. It records a row per step (state, step size, each evaluation's
    solved values).
  - Sweep: reverse mode with XAD. Per recorded step it rebinds the System to
    an active scalar, tapes the step's evaluations from the recorded start
    state (loading recorded solved values), and pulls adjoints back.
  - `implicit_node.hpp` differentiates an implicitly defined value.
- *plant*, `DEV/sw/plant`.
  - The incumbent is at `91098156`; the code before it is at `4555ea13`.
  - Patch is the System: species, then nodes, then components, then the
    environment.
  - A node's rates read the rest of the patch only through the field (light
    knots and soil state) and time.
  - TF24's strategy exposes net production as an auxiliary,
    `sign_value_aux()`.
  - Invader walks: `run_mutant` over the resident's recorded rows.
- *The incumbent treatment, per node:*
  - Detect a sign change by the step's ends, the stages, the dense output's
    check of the deepest stage, and a golden search beside a reading within 2%
    of zero.
  - Locate it by regula falsi on the dense output.
  - Re-integrate that node over the step in pieces between its sign changes,
    with the tableau, in the field read at u = 0, 1/4, 1/2, 3/4, 1 and
    interpolated by a quartic.
  - Rate the end state again.
  - Record the cuts, their slopes, the states at the cuts and the ratings.
  - In the sweep, tape the pieces at the recorded ratings, each cut moving by
    the implicit function of net production's zero.
- *Driver and harness.* `PD/harness/run_record.R` runs a stand from env vars:
  PLANT_LIB, PROGRAM, SPLIT, LMA_REL, FORWARD, STAND_ONLY, ATOL, NODES, TOL,
  OUT. See `PD/docs/measurements/sign-changes/reads_gates.sh`.
  - Programs: `DEV/sc/runs/program_split.rds` and `program_plain.rds`.
  - Library with the incumbent (its off switch is plain): `DEV/lib_rr`.
  - R-level drivers of the step: `PD/harness/ark_prototype.R`,
    `PD/docs/measurements/grid-dynamics/events/`.
- *Docs:* `PD/docs/geometry.md` (the problem's geometry, the frontier, the
  walls), `PD/docs/grid-dynamics.md` §9, §11, §17, §18, §19,
  `PD/docs/design-grid-controller.md` phase 3, and `PD/OBJECTIVES.md`.
