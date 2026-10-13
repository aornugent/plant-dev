# Map-ranked batch bisection: first pass on dry and episodic

The test of `design-schedule-building.md`'s revisited strategy, pre-registered in
`loc/prereg.md`. Errors are in each quantity's ε against the training references.
Costs are CPU seconds of a gradient run by the rows model of `plan-schedule-search.md`;
the map adds 4–11% of a sweep on top.

**G0** is the pilot's edges with each open gap cut into an even number of equal
intervals, at most b1/16 before b1 and 80 d after. It runs with the map on, dropping
every other node of each gap. **G1** bisects both intervals of the fewest panels that
carry 75% of the summed |move of ln J|: 11 of 84 panels on dry (4 of them founders'),
18 of 87 on episodic.

| record | run | cost | worst | over ε/3 |
|---|---|---|---|---|
| dry | lattice (16, 70) | 428 | 0.79 | 20 |
| dry | G0 | 448 | 0.74 | 21 |
| dry | **G1** | **516** | **0.25** | 0 |
| dry | lattice (32, 35) | 700 | 0.27 | 0 |
| episodic | lattice (16, 70) | 238 | 0.65 | 3 |
| episodic | G0 | 256 | 0.39 | 1 |
| episodic | **G1** | **324** | **0.20** | 0 |
| episodic | lattice (32, 35) | 455 | 0.12 | 0 |

- **G1 matches (32, 35)'s accuracy at 26–29% less cost.** Its 22 and 36 added nodes
  sit where J's map ranks the error: births before 20 on both records, none after 20.
- **The move G0 → G1 reads G0's error** (4/3 of the move against G0's error):
  - dry: median ratio 0.98, correlation 0.97, all 27 quantities over ε/3 within ×2
    with the right sign;
  - episodic: median 0.55, correlation 0.89; root_P50 and storage_relaxation_offset
    read half, so on episodic half of their error sits in panels J's map ranked below
    the 75% cut.
- **What G1 has left is outside the bisected panels.** (Q0 − Q1)/3 reads 0.68 (dry)
  and 0.12 (episodic) of G1's error; the largest gap is 0.30ε. An estimate for the
  committed run needs the unbisected panels' share.

Against the pre-registration:

| | prediction | result |
|---|---|---|
| P1 | ln J's move = Σ m/4 over the chosen panels, within 20% | 1.01× (dry) and 0.95× (episodic) in size, opposite in sign: the move of a bisection is −m/4, since m is the coarsening's move. The registered sign was a derivation error. |
| P2 | median \|err(G1)\|/\|err(G0)\| in [0.3, 0.6] | 0.28 (dry, 21 quantities); 0.36 (episodic, 1) |
| P3 | (Q0 − Q1)/3 within ×2 for 80% over ε/3 | vacuous: no quantity of G1 is over ε/3 |
| P4 | rows(G1) ≤ 1.35 rows(G0); G0 within 10% of (16, 70) | 1.15 and 1.27; +5% and +7% |
| P5 | every quantity of G1 within ε | yes, worst 0.25 and 0.20 |

`rooting_depth_max` is +0.48 (dry) and +0.39 (episodic) on G0 against about 0 on the
lattice runs, and +0.21 and +0.14 on G1. Not yet explained.

## The other three training cases

| record | run | cost | worst | over ε/3 | 4/3 (Q0 − Q1) against err(G0) |
|---|---|---|---|---|---|
| long-wet | G0 | 516 | 1.02 | 10 | median 1.18, 14 of 15 within ×2 |
| long-wet | **G1** (+6 nodes) | **541** | **0.33** | 0 | |
| long-wet | lattice (32, 70) | 546 | 0.41 | 1 | |
| long drought | G0 | 871 | 0.93 | 12 | median 0.96, 14 of 15 |
| long drought | **G1** (+12 nodes) | **941** | **0.37** | 1 | |
| long drought | lattice (32, 70) | 907 | 0.45 | 3 | |
| lma ×1.25 | G0 | 230 | 1.50 | 32 | median 0.92, 33 of 33 |
| lma ×1.25 | **G1** (+36 nodes) | **293** | **0.43** | 7 | |
| lma ×1.25 | lattice (32, 70) | 252 | 0.49 | 8 | |

- On all five cases G1 is within ε, and more accurate than lattice (32, 70) at about
  its cost.
- The map puts 0.55–0.81 of J's error in the founders' window on lma, long-wet and long
  drought, and its few top panels there take most of the fix: 3 panels on long-wet.
- One pass's move reads G0's error honestly on every case: median 0.92–1.18, and 108
  of 113 quantities over ε/3 within ×2 with the right sign.
- G1's own estimate, (Q0 − Q1)/3, reads 0.57–0.68 of its error: what G1 has left
  sits in the panels it did not bisect.

## The prize: the cheapest schedule with d(b) known

`loc/prize.R` builds schedules with spacing h(b) = s·(cost per node / |d(b)|)^(1/3),
d(b) from the case's maps (smoothed over three panels), one scale s per band
(founders' window, b1–10, after 10), searched on a grid, scored by the any-schedule
scorer without noise. It bounds what placement alone can save once d is known; finding
d costs at least one map run, which this does not count.

| case | best at worst ≤ 0.33ε: cost (worst) | G1: cost (worst) | lattice (32, 35) |
|---|---|---|---|
| episodic | 204 (0.30) | 323 (0.16) | 455 (0.12) |
| dry | 435 (0.29) | 514 (0.24) | 700 (0.27) |
| long-wet | 473 (0.28) | 541 (0.37) | |
| long drought | 833 (0.32) | 939 (0.34) | |
| lma ×1.25 | 232 (0.32) | 294 (0.44) | |

- Over the five cases the best use cost is about 17% under G1's at similar worst error,
  and 25–40% under the lattice's.
- The best schedules put 13–30 nodes in the founders' window, 30–55 over b1–10, and
  about 120–160 after 10, most of those the edges.

## rooting_depth_max: a trait at the edge of its range

Its error moved by 0.5ε between schedules with the same founders' nodes, against no
square law, and decided most failing noise draws. Root cause (`loc/rdmmap.R`,
`loc/rdmscan.R`):
- TF24 sets `rooting_depth_max = 1.5` m, the soil column's depth. Rooting depth is
  min(height, rooting_depth_max); below 1.5 m roots lose soil they could use, above it
  they grow into layers that do not exist. θ₀ sits on that edge.
- ln J on G0's own steps at rooting_depth_max × (1 + u): the local slope falls steadily,
  0.035 at u = −1.5%, 0.028 at 0, 0.020 at +0.75%, 0.0125 at +1.5%. The elasticity moves
  0.3ε per 1% of the trait, and the sweep's derivative (0.0289) sits 0.1ε off the pinned
  finite difference at 0 (0.0279).
- Its map on dry's G0 is concentrated: 3 of 84 panels hold half of Σ|move|, one at birth
  8.04 where J's map is near zero.

So, at θ₀, this elasticity is set by where the parameter sits, not by the schedule; it is
set aside from the schedule's targets, as recruitment_decay is. Whether
rooting_depth_max should equal the column depth is a model question.

## Agents on the any-schedule scorer

Three agents, about 100 candidates. Rescored with the scorer's miss shared by a case's
runs, jitter shared by nested runs, the cost fit without an intercept, C3 allowing one
miss under five quantities, rooting_depth_max set aside (`any/score_norm.R`), 40 draws:

| algorithm | T | draws |
|---|---|---|
| structure, `any/c05_graded.R` | 9126 | 40/40 |
| structure, `any/c06_tail.R` | 9199 | 40/40 |
| free, `any/c05_units_f16l95.R` | 9799–9871 | 40/40 |
| learn then build, `any/c14.R` | 11434–11940 | 39/40 |
| seed, one map pass | 10140–10180 | 38/40 |

The leader reads everything from the pilot and uses no map:
- the founders' first-mover layer at b1/24 until the pilot's offspring has fallen
  10-fold (1.1–2.1 years), the quiet middle at b1/12;
- a background of 85 d after b1, widening as the pilot's offspring falls (h ∝ f^−0.2
  below its median), within the range (100 d to 20 years, 280 d after);
- a check that halves every interval wider than half its target, so every checked
  interval's error falls 4-fold and 4/3 of the move reads the committed run's error in
  every region at once (estimate/error 0.96–1.02 without noise);
- commit the coarse run when every estimate is under ε, else the fine run.

A map pass did not pay: the fallback fires on 2–5% of case-draws. Committing the fine
run failed because too few quantities are over ε/3 for C3 to absorb one noisy one.

## Lateral: approaches outside node placement (13 October)

A first-principles review, with offline numbers from stored runs (`lateral/`). Two
facts about the leader: its check costs 1.54–1.75× the committed run, and edge nodes
carry 44–64% of the committed run's rows.

| approach | mechanism and measurement | expected saving in T | decisive test |
|---|---|---|---|
| halve the reverse sweep | three code changes measured in `perf-sweep.md` at 47–51% of the sweep: identity rows that do not split the descent (−19%), the crown's light quadrature off the tape (−20–24%), the collar's slope stored (−8.5%); a gradient run falls from 4.27 to about 2.65 forwards | about −38% | one dry gradient run, timed, bit-identical |
| stop where J's window ends | the pilot's R(t), J still to be earned, reaches 1e-3 at t ≈ 33.5–34.5; rows after 34.5 are 15–24% of a run; correct ln J by −ln(1 − R), off by about 0.004ε | about −18% | the committed schedules stopped at 34.5 against the full runs; elasticities' tail bias unmeasured; invaders that earn late set the stop |
| a quadrature per open spell instead of edge nodes | integrate each spell on its own: one midpoint node under 85 d, Gauss nodes above; nothing crosses an edge | about −12% (committed rows −4% to −18%) | weights per spell in plant; dry and long drought against references |
| log fate across the founders' window | fate falls nearly exponentially; the founders' error is mostly the own part (43–80% of the map's \|move\|); own-part error at f8 0.34–1.45ε with the hat rule, 0.03–0.07ε interpolating log fate | about −7%, and lma more robust | f8, f16 on dry and lma with the new weights |
| share the late check across θ | the late move at θ₀ reads a moved trait's with correlation 0.95–0.97, rms about 0.05ε; whole-run errors do not transfer (0.10) | about −10% per extra θ in a local analysis | wet-adG2 against long-wet |
