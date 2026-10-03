# The problem as geometry: spaces, metrics, error and stability

One picture for `OBJECTIVES.md`, the record in `docs/grid-dynamics.md` and
`docs/measurements/`, and the design in `docs/design-grid-controller.md`. Two
things here are new:
- the two pairs' stability and positivity on a pool (`harness/stability.R`);
- a few ratios taken from the ε table (`docs/measurements/eps-spread.md`).

Everything else is cited. Section marks (§) are `grid-dynamics.md`'s.

**In short.**
- *Where the answer lives.* On a triangle of birth date b and time t.
- *The grid* is a mesh on that triangle. Each node is a vertical line, and each
  accepted step a horizontal line across every member alive.
- *The cost.* A row is one cell of the mesh, and rows are what a gradient run
  pays.
- *The error* of a quantity is the sum, over cells, of each cell's local error
  weighted by the adjoint: how far that cell's states reach into the quantity.
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
- *So a step costs the row's width.* Members accumulate, so late steps cost
  most: 59–61% of member-steps come after t = 25, where at most 6.1% of `J` is
  still to be earned.
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

Plant's sweep computes ȳ backwards over the recorded steps.

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

**An error the norm cannot see does not converge.** Take a direction of error
that has weight in ȳ but none in the norm. The controller never shortens a step
for it, so that part of the error stays as the tolerance falls.
- The partition's coupling defect was such a direction (§13). Adding its size to
  the members' norm restored convergence.
- So anything taken out of the norm, the implicit chain included, needs a
  control of its own.

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
    to 31–38 days), and an invader's walk.
- *It matters only where a rate misbehaves below zero.* For a linear rate a
  negative stage is harmless: the results of Cash–Karp, Dormand–Prince,
  Tsitouras, RK4 and RODAS stay positive until the step turns unstable. Whether
  TF24's storage rates raise below zero is what phases 1b and 1c now measure.
- *Which limit triggers a raise is not yet known.* The ×2 `lma` invader raised on
  steps of 31–38 days, past both of Cash–Karp's limits. Phase 1c's caps at 15
  and 26 days separate them for Cash–Karp, whose stages reach −1.5 by 26 days.
- *This bears on the pair's decision.* Runs that host invader gradients are to
  use Dormand–Prince for its free interpolant, and their invaders meet these
  overshoots unguarded.
  - If a negative stage raises, those runs need a 7-day cap or sub-steps past
    h/τ_eff ≈ 1.
  - An interpolant for Cash–Karp, if phase 1b finds one good enough, would avoid
    the question.

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

## 6. The design in these terms

- *The norm places the global lines,* weighted by reach into the objectives.
  - Whatever the norm cannot see is refined inside a cell, never by adding a
    global line.
  - Events cut a member's cell at its crossing. Sub-steps divide an invader's
    cell where its pools are fast.
  - A local refinement costs one member's cell; a global line costs the whole
    row.
- *Refinements are part of the mesh,* and frozen with it. So `J′(θ′)` is smooth
  on it, and the sweep differentiates the discrete map on that mesh.
- *On the diagonal the refinements vanish:* nothing triggers at θ′ = θ. The
  invader keeps its resident's pair and stages, so `J′ = J` there exactly.
- *Probes map what is fixed before the run:* the record, the chain alone, a
  pilot's R(t). They pay where they change the mesh's density, not where they
  only spare the controller rejections.

## 7. What the picture adds

1. *Dormand–Prince's stages overshoot early and deep:* past 1.04τ against
   Cash–Karp's 2.16τ, and to −4.25 on a 15-day step (4(a) above). Most explicit
   methods overshoot past 1–2τ; Cash–Karp is unusually mild among fifth-order
   pairs. It bears on hosting invader gradients on Dormand–Prince, and phases
   1b and 1c now measure whether a negative stage raises.
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
