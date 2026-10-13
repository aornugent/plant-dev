# Building schedules from TF24's structure: what an algorithm can rely on

For agents searching schedule-building algorithms with `score_any.R`. Read
`BRIEF.md` first for the mechanisms; this adds what the localised runs measured, and
what the any-schedule scorer assumes. Sources: `docs/measurements/schedule-search/
localised.md`, `root-p50.md`, `estimate-shortfall.md`, `grid-dynamics.md`.

## What a schedule is, and what it costs

- A schedule is a set of birth dates: the cohorts born between two neighbours form an
  interval, integrated exactly by counts and the hat rule.
- **Every pilot edge is a node.** Edges are where establishment opens or shuts. An
  interval across one errs at first order and its estimate misreads 4–30×.
- **Cost is rows:** a node costs a little on its own plus its remaining life,
  rows ≈ a·n + c·Σ(39.6 − b) (R² 0.9997; on dry c ≈ 184 per node-year, a ≈ 150). A
  node at b = 0 costs about four times one at b = 30. Edges are 80–140 nodes per case.
- A gradient run costs 4.27 forward runs. The map adds 5.4%.

## Where the error is made

- **Each interval errs by d(b)·h³**, so the run's error is the sum over intervals and
  falls with the square of spacing. This holds for intervals up to 80 d late (45–80 d:
  10 of 10 on the square law; 80–110 d: 6 of 7; over 110 d: 11 of 15) and for the
  founders' window from b1/16.
- **J's map shows d(b).** A run with the map on reports, for each dropped node, the
  move of ln J if it were removed: m = d·((h1 + h2)³ − h1³ − h2³), or 6dh³ for a
  central drop. The map predicts the move of bisecting at 0.95–1.01×. The scorer's
  ln J, from the maps alone, matches every stored real run within 0.06ε.
- **Where d sits, by case** (share of the summed |move| on the 80 d start):

  | case | births before 3.6 | 3.6–10 | 10–20 | after 20 |
  |---|---|---|---|---|
  | episodic | 0.15 | 0.35 | 0.46 | 0.04 |
  | dry | 0.53 | 0.25 | 0.21 | 0.02 |
  | long-wet | 0.79 | 0.10 | 0.10 | 0.00 |
  | long drought | 0.67 | 0.19 | 0.13 | 0.01 |
  | lma ×1.25 | 0.50 | 0.10 | 0.32 | 0.08 |

  It is concentrated: 3 to 18 of 80–89 panels carry 75%.
- **The elasticities' error is where J's is.** Its per-interval parts rank with J's
  (Spearman 0.92 for root_P50 on dry), but they have both signs and cancel about
  four-fold, so a quantity's net error is not J's times a constant.
- **Founders:** fate falls nearly exponentially across the window (the pilot's nrr:
  80, 21, 6, 2 on dry's first four nodes). lma's own elasticity needs fine founders:
  1.5ε at b1/16.
- **Late births reach the founders through the soil,** 10–20 years after birth; after
  b = 20 almost nothing is earned or passed on.

## What one map pass did on the five cases

The start (`search/any/seed_onepass.R`): the edges, each open gap cut into an even
number of equal intervals of at most b1/16 or 80 d; one pass bisects the panels with
75% of the summed |move|. The pass's result, G1, is within ε on all five cases, more
accurate than lattice (32, 70) at about its cost. 4/3 of the pass's move reads the
start's error honestly (median 0.92–1.18; 108 of 113 quantities over ε/3 within ×2).
(Q0 − Q1)/3 reads only 0.57–0.68 of G1's error: what G1 has left is in panels it did
not bisect, which the move cannot see.

## The scorer

- A run's errors are the scorer's model plus noise: per quantity, the model's measured
  miss (median 0.02–0.03ε; rooting_depth_max about 0.2ε) and 0.04ε of run-to-run jitter.
  Robust means feasible on all 20 draws.
- Its range: edges as nodes; open intervals at most b1/12 in the founders' window,
  100 d before b = 20, 280 d after. Outside it, a run refuses (an infeasible case).
- It knows each case's d(b) and the per-band factors; the algorithm does not, and
  sees d only through the maps it pays for.

## The shape of d(b), measured on the five cases

Isolated from the maps, without new runs (`loc/dband.R`, `loc/founders.R`, `loc/pilotproxy.R`):
- **J's per-panel moves share one sign:** 90–94% are negative. Unlike the elasticities'
  parts, they do not cancel.
- **The founders' error is the first-mover layer.** At 35–42 d panels, |d| is 2–7
  ε per year³ for births before about 1.5 years, about 0 from 1.7 years to just before
  b1, and up to 1 ε/y³ beside b1. Episodic differs: its founders' d is small (under 1.1).
- **Elsewhere d is a flat background before 15–20 years** (median 0.2–0.7 ε/y³,
  varying ×2.6 from panel to panel), falling to 0.1–0.3 over 15–20 and about 0 after 20.
- **The pilot shows the trend, not the scatter.** log|d| tracks the pilot's offspring
  curve as about f^(1/3) (R² 0.6–0.9), but no pilot feature predicts the ×2.6 scatter
  around it (rank correlation 0.3 or less). Only a map sees which panels carry it.
- **Cost pulls the other way:** a node born at 0 costs about twice one born at 20, so
  the ideal spacing, h ∝ (cost per node / d)^(1/3), is about 2× finer in the
  first-mover layer than in the late background, and as coarse as allowed where d ≈ 0.

## The seed under the scorer

`seed_onepass.R` is feasible without noise at T = 9936 but on no noise draw. Every
failure is G1's estimate, (Q0 − Q1)/3, reading half to two thirds of the error, so C2
or C3 fails on lma or episodic (`search/any/fails_any.R FILE N` lists the failures).
