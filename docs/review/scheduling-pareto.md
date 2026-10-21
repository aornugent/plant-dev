# What the Caswell loop needs from the schedule, and what is Pareto-optimal

The goal: Caswell-type sensitivities (reproductive value times rate sensitivity)
and the derivatives of the eco-evolutionary loop, computed efficiently,
accurately and robustly. This note works out what that asks of the node
schedule and the time steps, from measurements E1–E8
(`../measurements/regnans-roadtest/rootcause/`) and the refine's design record
(`../design-refine-schedule.md`).

## 1. What the loop computes

| use | quantities | accuracy |
|---|---|---|
| following the equilibrium | F = ln J − ln b; F_θ (every trait); F_{ln b} | ln J within 0.025; \|F\| < 0.02 suffices for g (E5) |
| selection, the Caswell sensitivity | the invader's g at θ′ = θ, every trait | each elasticity's invader ε (`lma` 0.20) |
| prices | adjoint rows; field sensitivities S | through the identities in `prices-and-manifold.md` §3 |
| classification, occasionally | chords of g: Hessian rows, and dg/dθ along the curve | the curvature ε |
| continuation and chords | g smooth in θ on one grid, within a radius | OBJECTIVES' Stable 2 |

The last row binds hardest, and it is the one the schedule cannot always
provide (§3).

## 2. What a run costs

A forward run costs accepted steps × introductions × the cost of one cohort over
one step. A sweep multiplies that by about 2.3.

- **Steps are set by time, not by introductions.** On long drought, 108 to 402
  introductions take 8223–9024 steps at an absolute tolerance of 1e-8. The daily
  rain triples them against constant rain (E1, E4).
- **The absolute tolerance of 1e-4 holds every quantity (E6).** Against 402
  introductions at 1e-8, with 201 introductions:
  - ln J is 0.02 ε off;
  - the invader's gradient is 0.07 ε off (0.19 ε at 1e-8);
  - ln R′ at lma × 0.95 is 0.21 ε off;
  - all of it in 5157 steps instead of 8549, at 0.65–0.67 of the cost, for
    resident and invaders alike.
- **About 200 introductions are needed for g on long drought,** and about 100 for
  ln J (E2, E6). The gradient is the binding quantity.

## 3. Why the refine settled at level 0, and why that was expensive

- **Level 0 is set high by design.** The refine's honesty (R2) needs the half-node
  replay to read the error correctly, which holds only when the half grid is
  already on the square law. So level 0 sits at "scale 1", about twice the
  accuracy-optimal density (`design-refine-schedule.md`, step 3: below scale 1
  the estimate can read low). Settling at level 0 is the design working. Its
  price is that every grid is about twice as dense as accuracy needs.
- **The target set is the broadest possible.** R1 asks for ln J, every elasticity
  and every curvature, for residents and for invaders from × 0.5 to × 2. The
  verification judges about 50 elasticities, with a sweep on each of two grids:
  about 6 forwards per grid, the cost of two or three evolutionary steps.
- **The invader's g, which the loop needs most, is not in the judged set.**

## 4. Why constant rain is the hardest case

It should be the easiest: no weather, one establishment spell. E8 shows why it is
not.

- **One cohort carries everything.** On the rebuilt schedule at b* = 45.1, the
  cohort born at day 0 produces 16 300 offspring per seed. The next, born two days
  later, produces 4.7e-5: nine orders of magnitude less. The stand is a single
  even-aged canopy.
- **The jump at the resident is that cohort racing the invader's.** At lma ×
  (1 − 1e-4), the invader's day-0 cohort produces 186 200, eleven times the
  resident's. At × (1 + 1e-4) it produces 60, 270 times less. That one node
  carries all of the change in ln R′.
- **The cause is in the model's representation, not the schedule.**
  - A cohort has no within-cohort size variation, and constant rain gives no
    spread in establishment timing.
  - So a rare invader born at the same instant sits exactly at, just above, or
    just below the resident's canopy. Forty years of light competition amplify a
    0.01% difference into a factor of 3000.
  - No node schedule changes this. It also explains the rest of constant's
    trouble: J depends on how the first days are resolved (the pilot's 100 even
    introductions gave J 570 times too small), and the refine never settled.
- **The general point.** In a deterministic size-structured model, variance is
  what makes fitness landscapes smooth: in establishment timing (from climate),
  in seed arrival, or within cohorts. Constant rain is not the simple limit but
  the singular one. Any climate where one cohort dominates will behave the same
  way.
  - The remedy belongs to the model's representation, not to scheduling: a
    within-cohort size spread, or seed arrival spread over a short window.
  - That is a modelling decision, and it is left open here, as asked.

## 5. The Pareto frontier

Each lever, with what it buys in each of the three dimensions. Measured gains
are marked; the rest are estimates.

| lever | performance | accuracy | robustness | status |
|---|---|---|---|---|
| absolute tolerance 1e-4 | ×0.65 per run (measured) | holds every quantity within 0.21 ε (measured) | unchanged | ready to adopt |
| judge only the loop's targets (F, F_θ, F_{ln b}, g in every trait), curvatures only at classification | verification from about 6 to about 2 forwards per grid | the target the loop needs (g) becomes guaranteed | unchanged | refine change |
| the invader's error estimate as a sub-sum of its own run | free: invaders do not interact, so dropping every other node is arithmetic on f_k, with no replay | exact estimate of the quadrature part | unchanged | small change |
| follow the equilibrium, with a radius per grid | 9.4 → 2.2–6 forwards per step (estimated) | \|F\| held to O(Δθ²) | needs the radius | regnans #89 plus a loop |
| a smaller tape (#119–#122, odelia#61, phylloptim#22) | sweep from 2.3 toward about 1.3 forwards (estimated) | bit-identical or roundoff | unchanged | issues filed |
| breakpoints located and moved with θ, nodes placed relative to them | none | removes jumps where a stall edge crosses a node | g smooth in θ on one grid: what chords and continuation need | design |
| invaders on their own introduction dates, reading the field at the resident's step ends | none | the invader's own spells resolved | removes the restriction to the resident's dates | the field at step ends is already recorded |
| time-step error weighted by price (adjoint rows from a pilot) | unknown, possibly large | aimed at the goal, not at every state | — | research; the general form of the earlier window weights |
| within-cohort spread for single-cohort stands | small cost | makes constant-like landscapes differentiable | essential where one cohort dominates | a modelling decision |

**The frontier, in order of return on effort:**
1. Absolute tolerance 1e-4.
2. Judge the loop's own targets. Get invader estimates from sub-sums.
3. Follow the equilibrium.
4. Shrink the tape.

Items 1–2 alone take one evolutionary step with its verification, amortised over
a grid's radius, from about 15 forwards at 77 s to about 4–5 at 52 s: roughly
five times less wall time.

**Robustness** comes from the representation: located breakpoints, invaders on
their own dates, and spread where one cohort dominates. None of these makes runs
cheaper. All are what make derivatives smooth enough to follow.

## 6. Building confidence toward H1 and H2

The order is chosen so that each step tests the one before it.

1. **Instruments.**
   - E6 (done) and E7 (running): accuracy and cost at 1e-4, and the sweep's cost
     on regnans's footing.
   - The adjoint-rows spike, with its checks: sum rule, mortality identity,
     injection.
2. **The invader's g under guarantees.**
   - Nudge tests on g in every trait on two or three smooth climates.
   - g's smoothness across a radius on one grid.
   - Record where it fails: constant rain, by E8.
3. **Prices.** Field sensitivities for invaders, checked by field contraction and
   the envelope test.
4. **The H1 and H2 pilot:** S for five strategies on two climates, and the Gram
   spectrum.
