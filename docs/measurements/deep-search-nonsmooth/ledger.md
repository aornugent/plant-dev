# Brief for proposers: how odelia should represent the points where a System's rates are not smooth

You are one of several independent proposers. Work alone. Do NOT read
`docs/design-shared-sign-changes.md` or `docs/measurements/kinks/` beyond
`inventory.md`'s table and notes (a design already exists; your job is an independent
one). Everything else in the repo is open to you, read-only. Do not build, commit, push
or edit any repository; write only into the directory you are given.

## The problem, as outcomes

TF24 (in `plant`, with leaf physiology in `phylloptim`, solved by `odelia`) is an ODE
system whose rates come from inner solves and selections: a leaf's operating point is an
optimum over the root-collar potential with bounds (it switches between an interior
optimum and the hydraulic bound), net production enters storage through a positive part,
soil moisture has clamps, rooting depth is capped, and so on. 26 such points are listed
in `docs/measurements/kinks/inventory.md` (kind: rate jumps J, derivative jumps K, C1,
or smooth with a narrow width W; reach: which components' rates change).

Reverse-mode gradients of the discrete map are exact for the steps taken, but where a
rate's derivative jumps inside an explicit Cash–Karp step, the gradient carries an
O(h·jump) error that depends on where the step's stages fall. The error control sees
the forward's error, not the derivative's. So gradients jitter with incidental
controller choices.

## Requirements (outcome form, with quantities)

- **R1 Reproducible gradients.** On the dry record, sharp gate, tolerance 3e-4: a ±5%
  nudge of the tolerance moves the elasticities by ≤ 0.006 rms (in units of each trait's
  ε), max ≤ 0.1. Today 0.048 rms (max 0.176). At 1e-4, 0.02–0.03. The tolerance's own move
  from 1e-4 to 3e-4 is 0.018 rms. (A third of that move is the proposed bar; you may
  challenge it upward.)
- **R2 Continuous on one grid.** One grid (node schedule and recorded steps) serves each
  local analysis around the resident: chords of gradients at u = 1e-2, regnans's
  convergence Jacobian at 1e-3, the resident within ±10% of θ₀, central differences at
  1e-4. Gradients from passes over the resident's grid at θ′ must change smoothly with θ′
  (no jumps above 0.01ε). Unmeasured today.
- **R3 Cost.** Rows are the cost: the forward is about 1.11e-4 s per row plus 2.4e-3 s per
  step, and the sweep about 3.56e-4 s per row (about three quarters of a gradient run). At
  most +14% rows over an unresolved run at the same tolerance (3e-4 runs 0.875 of 1e-4's
  rows). Report forward evaluations.
- **R4 Declare, don't handle.** A model developer adds a new non-smooth point with about
  one member. Detecting, locating, recording, replaying and differentiating it need no
  model code.
- **R5 plant's Events** (node introductions, harvest/thinning, resource pulses, climate
  extremes: actions at scheduled times that change the state or its width): R interface
  and behaviour unchanged. Your representation must give one account of every place where
  time is divided: scheduled times, controller step ends, rain knots, and points located
  from the state.
- **R6 Exact for its own map.** The sweep differentiates the map its pass took: central
  differences within 0.01ε.
- **R7 Walks.** An invader (θ′ from ×0.5 to ×2 of the resident) walks the resident's
  recorded steps and field. It is at zero density and does not feed back on the soil.
- **R8 What exists must not get worse.** The per-node split at net production's sign
  changes (16 502 on dry) stays at least as cheap and accurate. So do the rain knots in
  the soil's substeps and node insertions.
- **R9 Jumps (J kinds).** How often they occur on current builds is unknown.
- **R10** The averaged establishment gate (a W feature) is out of scope: it will not land.

The user's principles (verbatim in `docs/handover.md` under "Principles": Laziness
Protocol, Subtract Before You Add, Minimize Reader Load, Foundational Thinking, Model the
Domain) and `AGENTS.md`'s code and naming style bind every design.

The user's own words:
- "Having odelia handle this automatically, through a single, correct representation,
  feels much cleaner than bespoke bandaids over sharp model edges."
- "It'd be great DX if plant devs didn't need to worry about it."
- "Events also refers to thinning."
- "Restepping is fiddly; advance_adaptive is exactly this, and then means we get a good
  discretisation for our adjoints. But stopping might be OK too."
- Forward tangents (carrying a sensitivity in the forward for error control) were judged
  too expensive.
- "I'm not sure the domain is correctly modelled yet."

## Facts, with sources

**Measurements** (`docs/measurements/schedule-search/round4/JT/notes.md`, parts 2–4,
libD, dry, inset schedule, tolerance 3e-4):
- The leaf's switch: 14 728 sign changes of f_hi (dprofit/dcollar at the dry end) in 234
  of 4786 steps, a median of 51 per step. The stand switches as one cluster, about 0.44 d
  wide, inside steps of about 2 d.
- Treatments, as nudge rms:

| Treatment | Nudge rms | Cost |
|---|---|---|
| None | 0.048 | — |
| End the step at the first and last sign change of each cluster | 0.0020 | +12.8% rows, +11.5% steps |
| The same, only on steps over 0.5 d | 0.0081 | +7.1% rows |
| Split the node at f_hi | 0.044 | — |
| Split the soil at the first and last sign change | 0.010 | +8.5% evaluations, rows unchanged; the residual is the nodes reading the main step's soil |
| Split the soil at every sign change | 0.018 | — |
| Tolerance ×0.1 within 15 d of closing edges | 0.025 | +8.6% rows |

- Part 4: a step's contribution is about (θ/J/ε)·λ_soil·h·ΔG·φ(u), with φ bounded by
  ±0.2. The soil adjoint λ_soil varies most across steps. The top 30 of 221 switch steps
  hold 90% of the error.

**The integrator.** RKCK propagates the fifth-order solution; its stage at c = 1 has
weight 0, and the first stage has weight 37/378 (`odelia/inst/include/odelia/ode_step.hpp`).

**The record** (odelia branch `ODELIA-55` in `odelia/`, `git show
origin/ODELIA-55:<path>`; plant at
`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/p21/plant`,
branch PLANT-110):
- `instruction`, `step_record`, `solved_row`, `split_block`, `sign_change` and
  `subsystem_substeps` are in `ode_interface.hpp`. `SolverInternal::step` is in
  `ode_solver_internal.hpp`. `SplitsSignChanges` and `taken_step` are in `ode_step.hpp`.
- Each evaluation stores what its inner solves found. For TF24 that is each leaf's collar
  and the arm it was placed on (`leaf_solved_point`, `TF24_Strategy::solve_leaf` in
  `inst/include/plant/models/tf24_strategy.h`).
- A forward pass stores; only the sweep loads; walks search again.

**Ownership** (`docs/design-sign-changes.md` §8): plant owns the per-node split, and
odelia owns step numerics.

**Why the cuts move and the steps do not** (`docs/design-grid-controller.md`, near the
line "Why the cuts move"):
- Row ends chosen by the controller are held in replays and the sweep.
- Split cuts at zeros are located again in replays and moved in the sweep by the implicit
  function (`implicit_value` in `implicit_node.hpp`). Held, they would read the zero
  off-centre with a stage's weight.

**Events** (plant `Events`, `Patch::apply_event`, `Species::introduce_new_node`): the SCM
runs `advance_adaptive` to each scheduled time and applies the action between solver
calls. Insertions are an `instruction` kind, and the sweep transposes them.

**An earlier outside reply on events** (`docs/oracle-response-events.md`): branch-selected
sub-steps, the implicit-function term, and class switches.

**Objectives:** `OBJECTIVES.md`.
