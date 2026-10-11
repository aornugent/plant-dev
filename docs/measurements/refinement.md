# Iterative schedule refinement across traits and records

This builds on `breakpoints.md` and `dynamics.md`:
- Fate in birth date is smooth between breakpoints: creation-window edges, and
  fronts where a cohort's net production touches zero.
- Edges as nodes restore the square law.

Here the recipe is tested on moved traits, constant's fronts are found
automatically, and placement is driven by the drop map.

Settings: `nr`, lib_109 for the ladders, and the `adjmap-probe` build for map runs
(bit-identical J). Errors are in ε with `recruitment_decay` excluded. Ratios are
of successive moves; 4 is the square law, and an honest pair estimate reads 4/3
of the next move.

## Edge-aligned ladders across traits

Each ladder takes its edges from its own forward run on 54 even introductions;
that run takes 16 s on episodic. L0 is those introductions less the closed-gap
nodes, plus the edges; L1 and L2 are nested bisections of it. Moved traits are
scored against their own L1 + (L1 − L2)/3 (`mscore.sh`, `prereg_matrix.md`).

| record | traits | edges | resident | invader | ln J | estimate / next move |
|---|---|---|---|---|---|---|
| episodic | θ₀ | 84 | 3.78 | 3.99 | 3.92 | 1.28 |
| episodic | lma ×1.25 | 64 | 2.40 | 3.22 | 4.44 | 0.99 |
| episodic | stem_P50 ×0.8 | 64 | 3.23 | 4.48 | 5.00 | 1.16 |
| dry | θ₀ | 138 | 3.51 | 3.57 | 4.81 | 1.18 |
| dry | lma ×1.25 | — | 3.57 | 4.03 | 3.90 | 1.28 |
| dry | stem_P50 ×0.8 | — | 3.99 | 4.23 | 4.20 | 1.40 |
| long-wet | θ₀ | — | 3.91 | 5.61 | 3.79 | 1.57 |
| long-wet | lma ×1.25 | — | 3.96 (IQR 0.74–5.58) | 4.79 | 3.90 | 1.56 |
| long-wet | stem_P50 ×0.8 | — | 5.92 | 3.79 | 4.01 | 1.31 |

- Traits move the windows: episodic has 84 edges at θ₀ and 64 at either moved
  trait. The first pass picks them up.
- Two combinations scatter in the resident: episodic and long-wet at lma ×1.25.
- Their unaligned itinerary changes (`itin.R`) carry survival jumps of at most
  0.1, so no breakpoint is missing. The scatter is resolution: 54 even nodes
  leave the first window's first-mover layer under-resolved at L0 and L1.

## Constant's fronts, found and resolved

**Finding the front** (`locate.R`):
- Start from forward runs over the full horizon, on even introductions with nodes
  every 2 days over days 0–60.
- Each round, bisect the first neighbour pair whose sign-change counts differ
  with 8 new nodes.
- Five rounds, each a forward run of about 100 nodes taking 1–2 minutes, place
  the front to 0.0003 day:

| traits | front found | 1/16-day scan |
|---|---|---|
| θ₀ | 23.524 d | 23.53 |
| lma ×1.25 | 18.873 d | 18.81–18.88 |
| hmat ×1.25 | 10.847 d | 9.9–10.9 |

The front shows only over the full horizon. Cohorts just after it first cross
zero after year 10, so a 10-year run brackets a different change (day 37.6).

**Resolving it.** With nodes every 1/512 day across the front (ladders `mkf.R`),
the invader converges by the square law at θ₀ (4.31), but the resident does not
(1.89). The cause is not another front: the remaining itinerary changes carry
survival jumps under 0.01. The founders' fate falls steeply toward the front, so
the founders' window needs resolution of its own. The earlier front ladder on
rule v2's grid, which grades that window, converged in both roles (3.67, 4.45).

## Placement driven by the map

`refine.R` runs passes with the drop map. Each panel's estimate e is the own
plus field part of its coarsening move. Each pass bisects both intervals of the
fewest panels carrying 70% of Σ|e|. It stops when Σ|e|/3 < ε/2 and, in round 2,
when ln J moved less than ε/4 since the last pass.

**Round 1: from L0, the 54-node base.** It stops after 3–4 passes at 0.4–0.9M
rows, but the estimate under-reports:
- dry: estimate −0.14ε against an error of −1.82ε, with 10 of 48 quantities
  over ε;
- the top panel is always the founders' [0, 0.74] interval, halved one level per
  pass;
- regions whose structure is narrower than the spacing show a small coarsening
  move at both levels, so the map rates them low;
- uniform L2 (0.185 spacing everywhere) gets ln J within 0.05ε on dry, where the
  map-driven passes do not.

**Round 2: from L1, one uniform bisection** (`prereg_refine.md`):

| case | passes | rows | max err | over ε | ln J error / estimate | uniform L2: rows, max |
|---|---|---|---|---|---|---|
| episodic θ₀ | 2 | 833k | 0.24 | 0 | −0.13ε / −0.11ε | 1319k, 0.27 |
| dry θ₀ | 2 | 1471k | 0.80 | 0 | −0.17ε / −0.17ε | 2752k, 0.38 |
| long-wet θ₀ | 2 | 1660k | 0.41 | 0 | −0.06ε / −0.03ε | 3231k, 0.66 |
| episodic lma ×1.25 | 1 | 545k | 1.33 | 7 | −0.12ε / −0.11ε | 1086k, 0.95 |

- One pass earlier, each θ₀ case is already within ε everywhere, at 678k, 1333k
  and 1569k rows.
- From a resolved start, the loop reaches ε at about half of L2's rows, and its
  ln J estimate is honest: within 10% on episodic and dry.
- It stopped too early at lma ×1.25, where 7 elasticities are still over ε. The
  stop reads ln J only; elasticities need a guard of their own. Their
  pass-to-pass change is the cheap one.

## What it says about the recipe

1. **A first pass of forward runs finds the breakpoints.** Edges come from the
   creation record; fronts from sign-change counts, bisected on forward runs.
   It costs seconds to minutes.
2. **The start must resolve the structures the dynamics guarantee before the
   estimate can be trusted.** These are the first-mover layer of the founders'
   window (and of later windows), and the founders' approach to a front.
   108 even nodes with edges is enough on episodic, dry and long-wet; 54 is not.
3. **From there the map places nodes and certifies ln J,** at about half the
   rows of uniform bisection.
4. **Open:**
   - an elasticity guard for the stop;
   - a start rule for the first-mover layers that does not cost a full uniform
     bisection;
   - long drought and constant through the loop.
