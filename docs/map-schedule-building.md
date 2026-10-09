# Map: how a run's schedule is built, and the birth-date intervals it builds

This maps the pieces the schedule design turn will rework:

- exact counts;
- the crown spread;
- the pilot and the tolerance over time;
- the diagnostics;
- `refine_schedule()`.

It gives each piece's data structure, the control flow that uses it, and how far
each is ecology, numerical method, or ODE machinery. Nothing here proposes a
design yet; the questions it raises are at the end.

Your hunch holds. Of all this, only the tolerance factors reach the ODE solver,
and the solver sees introductions only as insertion rows. Everything else is
ecology (establishment, leaf area, offspring) evaluated by a numerical method on
the birth-date axis: interpolation and quadrature between nodes.

## 1. What the birth-date coordinate represents

On the birth-date coordinate, the population at time t is every cohort born
before t, labelled by its birth date b. Its density is the birth rate at b times
survival since then. The model never holds the density between nodes. It holds
**nodes**, cohorts at chosen birth dates b₀ < b₁ < … < bₙ, and treats each
**interval** [bⱼ, bⱼ₊₁] between neighbouring nodes as the cohorts born in it.
Their sizes, leaf areas and fecundities are interpolated between the two nodes.

```
birth date →   b₀ ───────── b₁ ───────── b₂ ─── … ─── bₙ ───────── t (now)
nodes          N₀           N₁           N₂            Nₙ           boundary node
                                                                  (birth date = now, moves)
intervals          I₀            I₁            …            Iₙ (open: still growing)
```

The **schedule** (the introduction times) is therefore the birth-date grid. Each
introduction closes the open interval and opens the next. The ODE steps are a
second, separate grid in time.

## 2. The data structure

### The interval's establishment ("exact counts")

Each node carries its interval's establishment, integrated exactly while the
interval is open: the establishment probability of a seed arriving at each
instant, accumulated as an ODE state.

```cpp
// node.h: only the newest node's interval grows
interval_establishment          E_j = ∫_{b_j}^{b_{j+1}} pr_estab(b) db
interval_establishment_moment   M_j = ∫_{b_j}^{b_{j+1}} (b − b_j) pr_estab(b) db

// interval_shares(Δ_j): the interval split between the hat functions at its ends
{ E_j − M_j/Δ_j  (to node j),   M_j/Δ_j  (to node j+1) }
```

A node's **establishment weight** is its share of the interval above it plus its
share of the one below (`Species::for_each_establishment_weight`). The boundary
node takes the open interval's upper share (`boundary_weight`). Every count or
sum over the population is Σⱼ wⱼ f(Nⱼ). Offspring production is one such sum:
`offspring_production_per_fecundity` gives each node's wⱼ × birth rate × patch
density × S_D.

- **Ecology:** pr_estab, birth rate and fecundity.
- **Numerics:** a linear (hat-function) interpolation of f in birth date,
  weighted by the exact establishment integral. The establishment is exact; f
  between nodes is interpolated.

### The interval's canopy (the "crown spread")

For light, an interval's plants have heights between hⱼ and hⱼ₊₁. Before
`PLANT-108`, all of an interval's leaf area sat at its two nodes' heights (the
"lumped" field). The crown spread places it at eight birth dates inside the
interval:

```cpp
// species.h, for_each_interval_crown(node, end, visit)
at_node = share.first  × node.compute_competition(0)   // node j's share, as leaf area
at_end  = share.second × end.compute_competition(0)    // node j+1's share
for s in 0..7:  u = (s + ½)/8                           // the midpoint of each eighth
    visit(top       = h_j + u (h_{j+1} − h_j),
          leaf_area = at_node · 2(1−u)/8 + at_end · 2u/8)
```

Each visit is a crown: leaf area under a top height, with the strategy's Q
profile below it. The field at height z sums the crowns that reach z.

- **Ecology:** leaf area and the crown's vertical profile.
- **Numerics:** the midpoint rule on eight sub-intervals of the same linear
  interpolation in birth date. It is what makes the birth-date field converge
  on the square law, and so what makes the every-other-introduction error
  estimate work (`grid-dynamics.md` §16). So the spread is part of the
  quadrature's design, not a canopy feature.

### What `mom` is

In the field build, each crown record holds `mom`. These are not moments: they
are the powers of the crown's top, H^0, H^−η and H^−2η (`canopy_shape.crown_moments`).
The crown profile factors as Q(z, H) = Σₖ aₖ(z) · H^(−kη), with the aₖ from
`height_weights(z)`. So the field at every height is a prefix sum over crowns
sorted tallest first, one pass for all heights.

The record is "a crown's top, its leaf area, and its top's powers". Candidates:

| Now | Proposal |
|---|---|
| `crown_moments` | `top_powers` |
| `height_weights` | `height_coefficients` |
| field `mom` | `powers` |

These names predate this work (`61af9238`), and the lumped path beside it uses
the same `mom`, so the rename spans both.

### The two integrals share one structure

| | counts and sums | light field |
|---|---|---|
| integrand | f(node): fecundity, density, … | leaf area at height z |
| interpolation in b | linear between the interval's ends (hat functions) | linear between the interval's ends |
| quadrature | exact weight (E, M) × nodal values | midpoint, 8 points, weights from the same shares |
| code home | `Node::interval_shares`, `for_each_establishment_weight` | `for_each_interval_crown`, `field_splits` |

Both read `interval_shares`. "Exact counts" and "crown spread" are therefore two
quadratures over the same object: the **birth-date interval**, its establishment
split between its two ends. Yet no type or name in the code says "interval".
It exists only as the pair (`nodes[j]`, `nodes[j+1]`), and its state lives on the
lower node.

## 3. Control flow, with its nesting

Five levels, from the analysis down to one rate evaluation. Levels 3 and 4 are
iterative; the inner three are one run.

```
L4  analysis: stand θ and its invaders θ′ → J, gradients and curvatures, each within ε
│     (regnans, or by hand; OBJECTIVES.md "one local analysis")
│
└─ L3  build the schedule (iterative; today in pieces, by hand)
   │    ├─ pilot: a coarse run at a loose tolerance, with the invaders walked
   │    │    → offspring_produced_at_ode_times → the tolerance over time
   │    │      (control_window)
   │    ├─ introductions:
   │    │    height coordinate:  refine_schedule() loops
   │    │        run → error per node → bisect intervals over schedule_eps → repeat
   │    │    birth-date coordinate: uniform introductions, chosen by hand;
   │    │        refine_schedule() refuses
   │    ├─ invaders: the shared thinned schedule (6.4, chosen from the pilot's walks)
   │    └─ diagnose_scm(): runs at every other and every fourth introduction
   │         → error and ratio per quantity (measures; refines nothing)
   │
   └─ L2  one run (SCM::run)
      │    for each introduction time b_k:
      │       insert node: the open interval closes; the boundary node becomes N_k
      │       integrate to b_{k+1}  (adaptive steps)
      │
      └─ L1  one step (odelia)
         │    tolerance factors (layout × time schedule, bound)
         │    substep the soil?  split the nodes at sign changes?
         │
         └─ L0  one rate evaluation (Patch)
                light field  ← crowns of every closed interval + the nodes
                node rates   ← growth, mortality, fecundity in that field
                open interval's establishment rate ← boundary node
                (pr_estab of a seed arriving now; E and M grow)
```

What is iterative, and on what it iterates:

| Loop | Iterates on | Reads | Writes |
|---|---|---|---|
| `refine_schedule` (L3, height only) | introductions | per-node error from leaving a node out | bisected intervals |
| the pilot (L3) | tolerance over time | where offspring are produced | `ode_tol_factor_times/values` |
| `diagnose_scm` (L3) | nothing (it measures) | runs at ½ and ¼ the introductions | error and ratio per quantity |
| the shared thinned schedule (L3) | which introductions an invader takes | the pilot's walks' shares | an invader's introductions |
| equilibrium (L4, regnans) | the stand's birth rate | J | b* |

## 4. Where each piece belongs

| Piece | Level | Kind | Home today |
|---|---|---|---|
| establishment integral E, M | L0 | ecology (pr_estab) through an exact integral | `Node` |
| establishment weights | L0 | numerics: hat-function quadrature | `Species` |
| interval crowns | L0 | numerics: midpoint quadrature of the canopy | `Species` |
| crown top powers | L0 | numerics: factoring Q for a prefix sum | `CanopyShape`, `Species::field_splits` |
| introductions | L3 → L2 | numerics: the birth-date grid | `NodeSchedule`, `Parameters` |
| tolerance over time | L3 → L1 | numerics, set from ecology (offspring still to come) | R `control_window`, then `Control`, then `Patch` |
| error estimate | L3 | numerics: Richardson on the birth-date grid | R `diagnose_scm` |
| per-node error and bisection | L3 | numerics: leave-one-out on the height grid | `SCM::refine_schedule`, `Patch` |
| substep threshold | L1 | ODE, set from ecology (uptake) | `Control`, `Patch` |

## 5. What the map shows

1. **One object, unnamed.** Counts and canopy are two quadratures over the
   birth-date interval. Naming the interval, perhaps as a value Species hands
   out with its two nodes and its shares, would let "exact counts" and the
   "spread" read as its two methods: its establishment and its crowns.
2. **The schedule is the quadrature grid.** Introductions are birth-date
   quadrature points. The tolerance over time weights the time grid by where
   offspring come from. Both are numerical choices driven by ecology, and both
   belong at L3.
3. **Two error estimators for one grid.**
   - `refine_schedule` uses leave-one-out, per node, on the height coordinate
     only.
   - `diagnose_scm` uses Richardson from coarser grids, per quantity, on the
     birth-date coordinate.

   On the birth-date coordinate a refinement loop could use either, or both:
   the per-quantity estimate says when to stop, the per-node one where to add.
4. **The pilot is iteration 0 of L3.** It reads where offspring come from. A
   refinement loop's first coarse run reads the same thing.
5. **Most of it is plant, not odelia.** odelia receives a program (step times,
   insertions) and per-state tolerance factors. The time schedule of those
   factors needs no model knowledge, which supports moving it into
   `OdeControl` (C in `names-subsystem.md`). Choosing it does need ecology, so
   the choice stays at L3 in plant.

## 6. Questions for the design turn

- Is the birth-date interval a type, with establishment shares and crowns as
  its methods? If so, what is it called: interval, cohort span?
- Should the spread be named for what it is numerically (the canopy's
  quadrature points, eight per interval) or ecologically (sub-cohorts at
  birth dates inside the interval)?
- What should one L3 loop look like?
  - It starts from a coarse default.
  - It reads offspring still to come, per-quantity Richardson and per-node error.
  - It refines introductions where it must and sets the tolerance over time.
  - It covers the invaders.
  - It stops at ε.
- Does `refine_schedule` (height) become that loop's height-coordinate case, or
  does the loop replace it?
- What does the loop return: `Parameters` carrying the schedule and the
  program (decision 1's `ode_steps`), a `Control` with the tolerance over time,
  or one object holding both?
- Where does the substep threshold sit: per run (L1), or chosen at L3 like the
  tolerance?
