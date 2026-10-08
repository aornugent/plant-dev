# The problem as geometry: spaces, metrics, error, stability and the frontier

One picture for `OBJECTIVES.md`, the record in `docs/grid-dynamics.md` and
`docs/measurements/`, and the design in `docs/design-grid-controller.md`. Three
things here are new:
- the two pairs' stability and positivity on a pool (`harness/stability.R`);
- a few ratios taken from the ε table (`docs/measurements/eps-spread.md`);
- the laws that price the mesh, and the frontier they draw (§3 and §6 here),
  each checked against the record.

Everything else is cited. Section marks (§) are `grid-dynamics.md`'s.

**In short.**
- *Where the answer lives.* On a triangle of birth date b and time t.
- *The grid* is a mesh on that triangle. Each node is a vertical line, and each
  accepted step a horizontal line across every member alive.
- *The cost.* A row is one cell of the mesh. A step costs its row, a node its
  lifetime, and a gradient run pays every cell about seven times.
- *The error* of a quantity is the sum, over cells, of each cell's local error
  weighted by the adjoint: how far that cell's states reach into the quantity.
- *Where cells pay.* For a given weighted error, the fewest cells shrink as the
  sixth root of their weight in time and the cube root in birth date. So nodes
  answer to weight and steps hardly do.
- *The frontier* is runtime against error. A knob moves along it, a lever moves
  it, and a wall is where a knob stops working. Its cheapest point splits the
  error budget about 2:5 between time and nodes; today the time axis spends far
  less than its share.
- *The objectives' stability* is the regularity of two maps:
  - the answer as a knob moves (accurate, reproducible, predictable);
  - the answer as the traits move on one frozen mesh (continuous, never fails).
- *The numerical stability that limits the mesh* is a third geometry: the pair's
  stability region against the spectrum of the stiff parts, the soil chain and
  the pools.

## 1. The triangle and its mesh

- *The solution.* On the birth-date coordinate each member is born at b and
  followed to the end of the run: a vertical line from (b, b) upward. The stand
  at time t is the row of members born before t.
  - The light field, the soil and the newborn flux at t are built from that
    row. So at each instant every member is coupled to every other through them.
- *`J`'s window.* `J` is earned by the members' offspring along the run.
  - On the pulsed records 1% to 99% of it is earned between t = 13.4–13.7 and
    29.2–29.3; on the constant record, between 10.8 and 28.5.
  - Members born before 3.6 hold 78–100% of it (§8).
- *The grid is a mesh on the triangle.* A node is a vertical line. An accepted
  step is a horizontal line across the whole row, since every member alive
  takes it. A **row** is one cell: one member over one accepted step.
- *So a step costs the row's width, and a node its lifetime in steps.* The cells
  are the total length of the lines. Members accumulate, so late steps cost
  most: 59–61% of member-steps come after t = 25, where at most 6.1% of `J` is
  still to be earned.
- *A gradient run pays every cell about seven times:* the forward, its sweep
  (2.6), the invader's walk (0.8) and its sweep (2.6). A rejected attempt is
  paid once, by the forward alone.
- *A stiff part anywhere shortens the step for every member.* The soil chain, a
  function of t alone, binds 83–91% of the steps. The members alone would need
  about half as many.

What the triangle carries, and what resolves each feature:

| feature | where on the triangle | known before the run | resolved by |
|---|---|---|---|
| the record's knots | horizontal lines: 2931 active knots on long drought | yes | steps that land on them |
| the soil's stiffness | after rain a layer relaxes at about one over the time since the rain; under constant rain, steadily and stiffly | from the record, and from the chain alone at 2.4e-4 of a forward | the global step's stability limit |
| `J`'s window | the band t ≈ 11–29, carried by members born before 3.6 | from a 54-node pilot, within 1–4% | the window's weight, which loosens steps and thins nodes outside it |
| creation windows | vertical bands, each opening with a first-mover layer 0.13–2.7 wide | from a pilot | graded nodes (B) or the spread canopy (D) |
| the fate front | a vertical line where neighbours split into canopy and understory, under constant rain | from a pilot | nodes every 1/16 day around it |
| crossings | a curve per member where its net production changes sign; 726 of 14 845 steps hold one | no: they move with θ | per-member events |
| the invader's fast pools | along its lines, wherever h/τ_eff is large | in part: τ_eff ≥ τ_s = 7 days | a cap, or sub-steps inside the resident's step |
| a change in height order | where a later member overtakes an earlier one | no | nothing in the model; in the light field's code, an ordering tolerance or a sort |

The forcing fixes most of the horizontal structure before the run, and a pilot
most of the vertical. What moves with the traits is the crossings, the fate
front, and where an invader's `J′` is earned.

## 2. The spaces and their metrics

**The answers.** A run reports quantities Q: `ln J`, each elasticity
`d ln J / d ln θ`, and curvatures. The distance between two answers is
d(Q, Q′) = max over the quantities of |Q − Q′| / ε_Q. "Within ε" is the unit
ball and "reproducible" the ball of radius 1/3.
- *ε_Q is a tenth of Q's spread* across eight records of one climate. So the
  metric is scaled by what tells realistic records apart, not by what the solver
  can do.
- *The floor of 0.01 on elasticities is set by the trait box* (below). An
  elasticity off by δe moves `ln J`'s first-order prediction across a move of
  ln 2 by δe·ln 2. So the floor is `ln J`'s ε/3 over the box's half-width,
  0.012, rounded down; 0.01 uses 0.83 of ε/3.

**The traits.** The coordinates are ln θ, since elasticities are gradients in
them. One local analysis is a box: the resident within ln 1.1 = 0.095 of θ₀ in
each trait, and an invader within ln 2 = 0.69 of the resident.
- *Invaders double the space.* A point is a pair (θ, θ′): the resident sets the
  environment, and the invader lives in it.
  - On the diagonal θ′ = θ, `J′` equals `J`, on the grid too, to the last bit,
    because the invader re-evaluates the resident's own stages.
- *A landscape is a fibre:* θ′ moving with θ held, `ln J′(θ′; θ)`.
  - The invader's gradient at θ′ = θ is the fibre's slope there: the selection
    gradient.
  - The resident's gradient is the slope along the diagonal, which adds the
    environment's response. For `lma` on long drought it is −9.6 against
    −27.0, so the response adds +17.4 (from the eight records' means).
- *A landscape's length scale* is |g|/|g′|: the distance over which its slope
  changes by its own size.
  - On long drought: 0.245 for the resident's `lma` and 0.177 for the
    invader's (from the eight records' means of slope and curvature).
  - Under constant rain: 0.0075 for the invader.

**The knobs.** `ln tol` and the node spacing. R2's nudges are a ball of radius
about ln 1.05 in `ln tol`, and a shift of the introductions by a quarter
spacing.

**The states.** The controller measures a step's local error in a weighted max
norm. Each state's error is divided by its error level,
`atol + rtol·(a_y·|y| + a_dydt·|h·ẏ|)`, with `atol = 1e-4·rtol`. The norm's unit
ball is what one step may get wrong.

**The records.** One climate is a distribution over records. ε is a tenth of
each quantity's spread over eight draws, and that spread's own 90% interval runs
from 0.71 to 1.80 times the estimate. The bank (constant, wet, episodic, dry,
long drought) samples several climates, with ε held from one.

## 3. Error

**The error of Q on a grid is Q_grid − Q\*.** To first order it is a sum over
the cells:
- each step's local error, paired with the adjoint ȳ(t) = ∂Q/∂y(t) at the
  step's end;
- the nodes' quadrature error across each row.

Plant's sweep computes ȳ backwards over the recorded steps. In one line, with
w a cell's weight |ȳ|, h its step, Δ_b its node spacing and p the pair's order,
the error is Σ over cells of w·(C_t·h^{p+1} + C_b·Δ_b²), plus a term for each
cell that straddles a switch, plus whatever lies in directions the norm cannot
see. The last two are the kinks and the norm's blind directions below.

*R(t), the share of `J` still to be earned, bounds ȳ in time.* An error made
at t, in a step or in a node born at t, changes `J` only through what is earned
after t (§8). That is why steps and nodes after the window cost `J` nothing
measurable.

**The controller's norm stands in for that pairing.** A weight per state is a
guess at |ȳ_i(t)|, the reach of state i into the quantities. Every lever that
saved rows is such a guess:
- the tied tolerance: the pools' share;
- the chain's weight, phase 1a: the soil's share;
- the window's weight: ȳ's profile in time, read from R(t). It saves 21–28% of
  rows at ≤ 0.08ε;
- graded nodes: where in birth date the quadrature's error carries weight.

The design's commitment is this statement: the global step is set by a norm
that weighs each state by its reach into the objectives.

**Where cells pay: the root law.** At a fixed weighted error the fewest cells
come from sizing each cell as (w·C)^{−1/(p+1)} along each axis: the sixth root
in t for Cash–Karp's fifth order, the cube root in b for the nodes' second
order. A weight of 100 then lengthens a step about 2× and widens a node spacing
about 4.6×. The controller itself, holding each step's error to the tolerance,
answers a weight with the fifth root, 2.5×.
- *The record agrees.* Every tolerance weighted ×100 after t = 25 on long
  drought cut the accepted steps from 17 684 to 14 730, and the member
  evaluations by 27% (§8, test 1). So the steps after 25, 34–38% of the run's,
  grew 1.8–2.0× longer, short of either root because some sit at walls
  (section 6).
- *Nodes take far more.* Nodes born after 25, thinned fourfold, moved every main
  quantity by at most 0.07ε (§8, test 3).
- *So nodes answer to weight and steps hardly do.* The window's weight returns
  21–28% and no more because the time axis saturates. The node axis has the
  larger lever, but late nodes hold few cells: the fourfold thinning after 25
  saved 11.7% of member-steps. Its lever is the grading of the early nodes,
  where the first-mover layers carry the weight.

**An error the norm cannot see does not converge.** Take a direction of error
that has weight in ȳ but none in the norm. The controller never shortens a step
for it, so that part of the error stays as the tolerance falls.
- The partition's coupling defect was such a direction (§13). Adding its size to
  the members' norm restored convergence.
- So anything taken out of the norm, the implicit chain included, needs a
  control of its own.

**A stage the norm cannot see can leave the domain.** A weight frees a
component's stages as well as its error.
- With the soil ×10 and rule A's factor of 100, the soil's weight late in the
  run is 1000. The error test then accepts steps with a soil stage at plant's
  1000 MPa potential ceiling. There the root curve's derivative is refused, and
  both roles' gradients fail (§8). At a weight of 100 no accepted step reaches
  the ceiling, though rejected attempts do.
- R(t) bounds a weighted error's reach into `J`. It says nothing about where a
  stage goes.
- So every weight is bounded (plant's `ode_tol_factor_max`), and anything weighted
  further down needs its stages checked against the domain, not assumed inside
  it.

**Kinks lie where the model switches.** The model is smooth except where:
- a member's net production is zero (its positive part);
- the leaf changes operating class;
- two members are at equal height, which is a switch in code only.

What follows:
- *A step that straddles a switch loses order.* Its error then depends on where
  the crossing falls among the stages.
- *So the answer jitters as a knob moves the stages.* The crossings are 70–85%
  of the gradients' spread under nudges.
- *And on a frozen mesh the gradient jumps* as θ slides a crossing past a stage:
  a staircase.
- *Events put the crossing on the mesh.* Locating it on an interpolant of the
  step's order, and differentiating its time, restores the order. The spread
  falls 3.4–6.4×, for 10.2% of a forward. A cubic interpolant is too coarse
  (§11).
- *Class switches do not set the steps* (§7).

**Predictable means each knob's error has a leading term.** Along a knob k's
ray, Q_grid − Q\* ≈ C·k^p with the knob's order p, so two points on the ray give
the error. It fails in two ways:
- *The leading term is not yet dominant.* On long drought, uniform nodes make
  two opposite errors at the first-mover layer's top, whose difference changes
  sign with each halving. Companions report only 0.41 and 0.33 of the invader's
  node error.
- *An error is out of the norm.*

## 4. Stability, in three senses

### (a) The pair against the spectrum

An explicit step is stable while h·μ stays inside the pair's stability region,
for every eigenvalue μ of the stiff parts.
- *The soil chain.* Drainage goes as the 16.14th power of moisture, so a wet
  layer's |μ| is large. After rain it relaxes at about one over the time since
  the rain (`docs/archive/scope-imex-stepper.md`).
  - Under constant rain the soil stays wet. 83% of the chain's steps start near
    the explicit limit, and an implicit chain saves 66% there (§7).
- *The pools* relax at 1/τ_eff, with τ_eff ≥ τ_s = 7 days.
  - A resident's pools are in the norm.
  - An invader's are not: it walks the resident's steps with no error control.
    So R5 for invaders is a condition on every step of the resident's grid, for
    every θ′ in the box: h/τ_eff must stay inside the region.

On the test equation y′ = −y/τ (`harness/stability.R`), in multiples of τ, and
the lowest stage on 15- and 26-day steps at τ_s = 7 days:

| method | order | evaluations | a stage turns negative past | per evaluation | unstable past | lowest stage, 15 days | 26 days |
|---|---|---|---|---|---|---|---|
| forward Euler | 1 | 1 | 1.00 (its result) | 1.00 | 2.00 | +1.00 | +1.00 |
| Heun | 2 | 2 | 1.00 | 0.50 | 2.00 | −1.14 | −2.71 |
| SSPRK(3,3) | 3 | 3 | 1.00 | 0.33 | 2.51 | −1.14 | −2.71 |
| Bogacki–Shampine 3(2) | 3 | 3 | 1.60 | 0.53 | 2.51 | −0.49 | −4.36 |
| classic RK4 | 4 | 4 | 1.30 | 0.32 | 2.79 | −1.31 | −8.63 |
| Fehlberg 4(5) | 4 | 6 | 1.02 | 0.17 | 3.02 | −3.96 | −26.3 |
| **Cash–Karp 5(4)** | 5 | 6 | 2.16 | 0.36 | 3.73 | +0.01 | −1.51 |
| **Dormand–Prince 5(4)** | 5 | 6 | 1.04 | 0.17 | 3.31 | −4.25 | −34.1 |
| Tsitouras 5(4) | 5 | 6 | 1.05 | 0.18 | 3.51 | −3.39 | −21.9 |
| ARK4(3)6L, explicit part | 4 | 6 | 2.00 | 0.33 | 4.23 | −0.07 | −1.04 |
| SSPRK(10,4) | 4 | 10 | 6.00 | 0.60 | 13.9 | +0.11 | +0.01 |
| RODAS, implicit | 4 | 6 | 2.45 | 0.41 | never | +0.05 | −0.11 |

- *Every method's stages overshoot a decaying pool once the step passes one to
  two relaxation times.* The exceptions are made so: SSPRK(10,4) keeps its stages
  positive to 6τ, at ten evaluations a step. Even the implicit RODAS has a
  negative stage past 2.45τ.
- *What differs is how deep.* The pairs tuned for a small error per step,
  Dormand–Prince, Tsitouras and Fehlberg, reach −3.4 to −4.25 on a 15-day step.
  Cash–Karp, the ARK's explicit part and RODAS stay near zero there.
- *Why most users of Dormand–Prince never see it.* Error control normally keeps
  h·|μ| well under one for every component that matters at the tolerance.
  - Here steps average under a day (17 684 over 40 years) against τ_s = 7 days.
  - The overshoot appears where a fast component is loosely controlled, or not
    controlled at all. That means rule A's loosened steps after the window (up
    to 31–38 days on episodic, 22 on long drought), and an invader's walk.
- *It matters only where a rate misbehaves below zero.* For a linear rate a
  negative stage is harmless: the results of Cash–Karp, Dormand–Prince,
  Tsitouras, RK4 and RODAS stay positive until the step turns unstable.
  - TF24's mortality is not linear in the pool. Its rate is 0.01 + 5.5·e^{−20r}
    in the pool's fill r: 41 a year at r = −0.1, and 1.2e5 at r = −0.5.
  - So a stage's harm scales with the fill at the step's start times the stage's
    depth. A negative weight downstream can then push mortality below −50,
    which plant refuses.
  - This is read from the source, not measured. It fits 1b's refusals, all at
    near-empty pools, and 1c's harmless stages at −0.78.
- *Under Cash–Karp, stability sets the limit.* On episodic the ×2 `lma` invader
  raised on rule A's steps of 31–38 days, past both of Cash–Karp's limits. Under
  phase 1c's caps it runs at 15, 20 and 22 days, and raises only at 26, at the
  stability limit.
- *What the runs showed* (`grid-dynamics.md` §8 and §11).
  - Under Cash–Karp, invader walks need stability, not positivity. Stages down
    to −0.78 of a pool are harmless, and the one raise sits at the stability
    limit.
  - On the resident, Dormand–Prince throws 8–38× as many stage rejections, each
    a negative pool. They come on short steps at near-empty late pools, not
    from the long-step overshoot.
  - Cash–Karp has its own free fourth-order extension, so the pair decision's
    reason for Dormand–Prince is gone.

### (b) The controller as a dynamical system

The controller is a feedback law on `ln h`: each step is set from the last
error. It settles where the error estimate meets the tolerance or, on a stiff
part, at the stability boundary.
- *Rejections are the chain's transients.* At a rain onset or rise the drainage
  switches on, |μ| jumps, and the step in flight leaves the region. The chain
  alone reproduces 98% of the first day's rejections (§7).
- *Levers on the controller's dynamics move the forward.* Seeds, PI and the guard
  change how the controller reaches its steps. They cut rejections, which only
  the forward pays, and keep or add accepted steps, which all seven forwards
  pay. The guard is −10.4% on the forward and +0.2% on a gradient run; PI with
  seeds is +5.8% (§7).
- *Levers on the metric move rows.* The window's weight changes which steps the
  norm accepts, and saves 21–28% of rows.

### (c) The objectives' stability: the regularity of two maps

- *The answer as a knob moves,* at fixed θ:
  - accurate: inside the unit ball around Q\*;
  - reproducible: it moves by less than 1/3 within a 5% ball of the knob;
  - predictable: it has a leading term along each knob's ray.
- *The answer as the traits move,* on one frozen mesh:
  - continuous: smooth within the mesh's radius. Freezing the mesh removes the
    controller's jumps, and events remove the crossings' kinks;
  - never fails: defined over the whole box.
- *Shared:* one frozen mesh covers the box.
- *Diagnosed:* each evaluation reports its distance from Q\* and its place
  against the radius.

## 5. The radius

**A mesh's radius is how far θ can move before a feature that carries weight
leaves what the mesh resolves.** As θ moves, crossings slide, the fate front
moves and the region where `J` is earned shifts, but the mesh stays.
- *Measured for the resident:* one uniform 108-node grid at `1e-4` holds every
  elasticity within ε over `lma` ×0.95–×1.1, but not at ×0.9
  (`docs/assessment.md`, step 4(c)).
- *The invader's region moves on the resident's mesh.* Under constant rain the
  members that earn 90% of `J′` are born before 2.2, 0.12 and 0.012 years at
  `lma` ×0.5, ×0.99 and ×1.01.
- *The invader's radius over ×0.5–×2 is measured on no record.*

**The landscape's length scale is a different thing.** |g|/|g′| says how far a
local model of the landscape holds, not how far a mesh serves.
- *On long drought the invader's box,* ln 2, is about four of its length scales
  (0.177) wide.
  - No linear or quadratic model spans it.
  - So a landscape over ×0.5–×2 is a set of evaluations, and continuity on one
    mesh is what makes them one landscape.
- *For the resident the box,* 0.095, is 0.39 of its scale (0.245), so a
  quadratic model holds there.

**The ε of each order, compared over the box.** The table gives the largest
error each ε allows in a prediction of `ln J` at the box's edge, as a multiple
of `ln J`'s ε/3 = 0.0084:

| | over the box | over one length scale |
|---|---|---|
| resident `lma` elasticity, ε 0.087 | 0.98 | |
| resident `lma` curvature, ε 1.16 | 0.63 | |
| invader `lma` elasticity, ε 0.198 | 16 | 4.2 |
| invader `lma` curvature, ε 4.0 | 115 | 7.5 |
| the floor, 0.01 | 0.83 | 0.21 |

The floor's second entry uses the invader's `lma` scale; the small elasticities'
own scales are not measured.

- *For the resident,* the ε set from spreads agree with `ln J`'s.
- *For the invader* they are 4–8× looser over one length scale. That is fine
  while an invader's gradient steers an optimiser and `J′` is evaluated at each
  point. It is not fine if gradients are used to predict `J′` between
  evaluations.

**Covering the box.** When one mesh's radius is shorter than the box, there are
two ways to cover it:
- several meshes, each within its own radius;
- one finer mesh that resolves the features wherever they move. Brute force is
  the finest.

Each new mesh for an invader is a new resident run, since an invader walks its
resident's recording.

**Covering is a second frontier: radius against cells.** A radius ends where
moved weight first lands on coarse cells, so where an invader's weight moves
decides which cover is cheaper.
- *A costlier invader's weight moves to the window's opening.* Under constant
  rain the members that earn 90% of `J′` are born before 0.012 years at `lma`
  ×1.01, 0.12 at ×0.99 and 2.2 at ×0.5. Graded nodes are densest at the
  opening, so one graded mesh can serve the costlier side.
- *A cheaper invader's weight spreads later in b,* where the resident's mesh is
  coarser, so the cheaper side meets the radius first. Its `J′` there runs to
  hundreds or thousands: 541–2682 at `lma` ×0.5 on the pulsed records. How
  closely a landscape must hold where the invader could not stay rare is a
  modelling question.

## 6. The frontier

Runtime and error trade along a frontier. A **knob** moves a run along it:
`tol`, the node count. A **lever** moves the frontier itself: events, a weight,
the implicit chain, graded nodes. A **wall** is where a knob stops working.

**Two curves, and the budget's split.**
- *In `tol`:* the error goes as `tol` and, on a free mesh, the cells as
  `tol^{−1/5}`: ten times the error for 1.6 times the cells. TF24's steps go as
  `tol^{−0.15}` (§1), which puts about three quarters of them on that curve and
  a quarter at walls. The node count barely moves them: 17 338 to 18 807 steps
  from 54 to 429 nodes (§1), so the two axes price separately.
- *In the nodes:* the error goes as Δ_b² once each panel holds one regime, so
  the cells go as ε_b^{−1/2}, or ε_b^{−1/4} with two rungs extrapolated. Uniform
  nodes on long drought follow no power law (section 3), so this curve needs
  graded or spread nodes first.
- *The split.* Cells ∝ ε_t^{−1/5}·ε_b^{−1/2} are fewest when the error budget
  splits between time and nodes as the exponents do: about 2:5, near even with
  two rungs.

**Where the run sits today.**
- For `J` the time axis holds 1/2000 of ε: 1.26e-5 at `3e-5`.
- For the gradients the floor runs at `1e-5` because of the kinks. At `1e-4` the
  resident's pool traits move up to 1.65 ε/3 under nudges, 70–85% of it from
  the crossings (R2).
- The node axis is at the bar or past it: 1.19ε for wet's invader `lma` on
  uniform 108.
- *So once events cut the kinks, loosen `tol` and spend on nodes.* On the cut
  mesh the four pool traits measured move 0.06–0.28 of ε/3 under nudges at
  `1e-4` (§11). If that grows in proportion to `tol`, about `3e-4` meets the
  bar, with about 1.2× fewer steps than `1e-4` and 1.7× fewer than `1e-5` at
  `tol^{−0.15}`. The saving goes to graded nodes, with a second rung read for
  their error.

**The walls.**

| wall | where it binds | what it costs | removed by |
|---|---|---|---|
| the record's knots | a step ends at each: 2931 on long drought, of 17 684 steps | a floor under the step count as `tol` loosens | nothing; they are the forcing |
| the soil's stability | constant rain, where 83% of the chain's steps start near the explicit limit; the days after rain | the implicit chain saves 66% there (§7) | the implicit chain, with a control of its own (§10) |
| the pools' stability | rule A's long steps, and every invader walk | the 15-day cap gives up 0.0–2.4% of rule A's saving (§8) | the cap |
| kinks, on the gradients | 726 of 14 845 steps hold a crossing | `1e-5` in place of `1e-4`: +41% of leaf solves (§11) | events: +10.2% of a forward on a quintic, +5.9% on Cash–Karp's own extension (§11) |
| directions out of the norm | the partition's coupling | no convergence (§13) | a control for each |
| stages out of the domain | the soil ×10 times rule A's 100 | both roles' gradients refused (§8) | a bound on every weight |

- *The soil's accuracy is not a wall.* Its steps answer to `tol`, and its error
  reaches `J` in proportion (§1). A weight on the soil loosens the time axis
  where the error is cheapest to give, as `tol` does everywhere (phase 1a).
- *A kink is a wall on the gradients only.* Across the crossings `J`'s kink
  error averages out. A gradient's error follows h at the crossings (§11), so
  its slope in `tol` falls from 1 to about 1/5, and only a cut restores it.

**Levers that give up nothing.** Each moves the frontier, so none is a trade.

| lever | cost at matched error | state |
|---|---|---|
| events | about 0.75 of `1e-5`'s (1.059 against 1.41) | measured on the driver (§11) |
| the window's weight and thinning | 0.72–0.75, at ≤ 0.08ε | measured (§8) |
| graded nodes, two rungs read | about 0.5 of uniform's, at equal and predictable error | the square law measured; the factor projected |
| the implicit chain, the soil judged by the chain alone | 0.56 on long drought at `3e-5`, 0.33 under constant rain | measured for the resident (§10); being built |
| the sweep's cost per cell | about 0.5 of the sweep's | profiled (`measurements/perf-sweep.md`) |
| an invader's members thinned by its own share of `J′` | 0.53–0.66 of its walk and sweep, within 0.17ε in `ln J′` | emulated exactly (`grid-dynamics.md` §14); its gradient unmeasured |
| the forward's warm start | about 0.9 of a gradient run | projected |

The controller's levers are not on this list. Seeds, PI and the guard turn
rejections, paid once, into accepted steps, paid seven times: 1.00–1.06 of a
gradient run (4(b) above).

**What remains to trade, and what is never traded.**
- *Three trade-offs:*
  - the `tol` knob, nearly free;
  - the node count against predictability: a uniform rung can be right by
    cancellation, off any power law, while a graded one is honest and needs two
    rungs to read;
  - a weight against risk: each direction weighted down needs a control of its
    own, and a bound on where its stages go.
- *Three constraints:*
  - nothing fails, for every cell at every θ′ in the box, which no weight on the
    resident sees;
  - `J′ = J` on the diagonal;
  - regularity on a frozen mesh, with the controller frozen, the kinks cut and
    the cuts frozen with the mesh.

## 7. The design in these terms

- *Whatever one member needs is cut inside its cell; whatever the row needs is
  drawn as a global line.* A cut costs one member's cell, a global line the
  whole row.
  - One member's: its crossings, and an invader's fast pools.
  - The row's: the soil, the knots and the window. The norm places these lines,
    weighted by reach into the objectives.
  - Events cut a member's cell at its crossing. An invader's pools are held by
    the 15-day cap instead, for at most 2.4% of rule A's saving, so they need no
    sub-steps under Cash–Karp (phase 1c).
- *The pair follows.* A cut needs a continuous extension of the step's order.
  Cash–Karp's own is free, and Dormand–Prince overshoots pools earlier and
  deeper (4(a) above), so there is nothing to trade.
- *Refinements are part of the mesh,* and frozen with it. So `J′(θ′)` is smooth
  on it, and the sweep differentiates the discrete map on that mesh.
- *On the diagonal the refinements vanish:* nothing triggers at θ′ = θ. The
  invader keeps its resident's pair and stages, so `J′ = J` there exactly.
- *Probes map what is fixed before the run:* the record, the chain alone, a
  pilot's R(t). They pay where they change the mesh's density, not where they
  only spare the controller rejections.

## 8. What the picture adds

1. *Dormand–Prince's stages overshoot early and deep:* past 1.04τ against
   Cash–Karp's 2.16τ, and to −4.25 on a 15-day step (4(a) above). Most explicit
   methods overshoot past 1–2τ; Cash–Karp is unusually mild among fifth-order
   pairs. On TF24, Dormand–Prince also loses on rows and error (phase 1b), and
   Cash–Karp walks need stability rather than positivity (phase 1c).
2. *The 0.01 floor is conservative.* Over the box it allows 0.83 of ε/3, and over
   `lma`'s length scale 0.21.
3. *An invader's box is several length scales wide.* So its local analysis is a
   set of evaluations made consistent by one mesh, not a Taylor model. Its
   gradient's ε is looser than `ln J`'s over that scale, which suits steering but
   not interpolation.
4. *A candidate for R8's radius, untested:* compare where an evaluation's `J′` is
   earned with where its mesh is fine.
   - A run already knows each member's share of `J′`.
   - The mesh knows where it thinned nodes and loosened steps.
   - If the region moves to where the mesh is coarse, the evaluation is outside
     the radius.
5. *One test for anything taken out of the norm,* the partition's coupling and the
   implicit chain alike: an error direction with weight in the adjoint needs a
   control.
6. *Two kinds of lever.* Those on the controller's dynamics cut rejections, which
   the forward alone pays. Those on the metric cut accepted cells, which every
   sweep and walk pays.
7. *Nodes answer to weight; steps hardly do.* The root law prices a weight of 100
   at about 2× on a step and 4.6× on a node spacing, and the record's ×100 after
   t = 25 lengthened those steps 1.8–2.0×.
8. *The budget splits about 2:5 between time and nodes.* Today the time axis
   holds 1/2000 of `J`'s ε while the nodes sit at the bar. So after events the
   cheaper point loosens `tol` toward `3e-4` and spends the saving on nodes,
   which phase 4 confirms or refutes.
9. *A weight frees stages as well as errors.* Every weight needs a bound, since
   R(t) bounds a weighted error's reach into `J` but not where a stage goes.
10. *An invader has no field part.* Its members see only the recorded field, so
    its own nodes answer to its own weight alone. Thinned by the root law, its
    walk and sweep keep 53–66% of their rows at ≤ 0.17ε in `ln J′`.
