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

## Other algorithm families on the scorer (13 October)

About 22 candidates in six families, the leader's knobs out of bounds (`any/lateral/`):

| family | result | why |
|---|---|---|
| a check coarser than the answer | fails, or 10.2k | nested coarsening needs the answer at half the range wherever nodes drop; a non-nested one amplifies jitter by s/(1−s) |
| a partial check plus a remainder from the pilot | fails | per-band factors differ in sign by quantity, so J's error cannot carry an elasticity's remainder |
| one gradient run plus forward runs or a map | cannot be honest | they measure J's error only |
| commit the finer run | fails C3 | 2–4 quantities over ε/3, one jitter miss fails |
| size a third run from the pair | fails on cost | edges make every run at least 0.91 of the committed |
| Richardson answer from two runs | passes at 14.4k | both runs are paid in use |
| **check finer by one ratio, not nested** (`any/a04_proxy.R`) | **T 8384, 40/40; 99/100** | the check at 1.6× costs 1.4× the answer against the halving check's 1.58×; estimate = move/(1 − s), s from the pilot |

The last trades nesting for a cheaper check, and lesson 15 (`BRIEF.md`) found a
non-nested pair failing C3 on real runs; it needs real runs before it counts. Within
this scorer, placement is close to exhausted: 8.4–9.1k against about 8.8k for the
prize's schedules at worst 0.5ε (use cost 2001 over the five cases) with a check of
1.4× and three uses' worth of the answer. The larger levers are the lateral ones above.

## c05_graded with real runs: training and held-out (13 October)

Both of its schedules run for real on the five training cases and five held-out ones,
scored against the references (`loc/val.R`, `loc/val_c5g.log`; held-out references
extrapolate u215 and u429, whose own estimate is up to 0.10–0.24ε):

| case | commits | worst | quantities over ε/3, read within ×2 | estimate/error (median) | T |
|---|---|---|---|---|---|
| episodic | coarse | 0.74 | 3/3 | 0.94 | 1065 |
| dry | coarse | 0.97 | 12/12 | 0.92 | 1774 |
| long-wet | coarse | 0.50 | 2/2 | 0.91 | 2069 |
| long drought | coarse | 0.49 | 3/3 | 0.82 | 3448 |
| lma ×1.25 | fine | 0.33 | 0/0 | 1.01 | 1216 |
| dry without season | coarse | 0.90 | 12/12 | 0.92 | 3066 |
| long drought, seed 102 | coarse | 0.44 | 2/2 | 0.83 | 3236 |
| long drought, seed 105 | coarse | 0.43 | 3/3 | 1.11 | 3054 |
| dry, root_P50 ×1.2 | coarse | 0.86 | 8/8 | 0.91 | 1861 |
| long-wet, a_dG2 ×1.25 | coarse | 0.55 | 2/2 | 0.96 | 2135 |

- **C1, C2, C3 and C5 hold on all ten cases,** held-out included; every quantity over
  ε/3 is read within ×2 with the right sign.
- Real T on the training cases is 9572, 5% above the scorer's 9126.
- The scorer predicted each real run's errors within 0.02–0.07ε rms, except lma's
  committed run (0.31, max 0.57); real rows were 0.98–1.11 of its model.

Against the pre-registration: R1 and R2 hold (10 of 10); R3 holds on four of five
training cases (lma's committed run misses at 0.31); R4 holds within 11% (two check
runs at 1.10 and 1.11).

## Probes outside the scorer's range (13 October)

On c05_graded's committed run, dry and episodic (`loc/probes.R`):

| probe | CPU of the base | largest move | worst error (base) |
|---|---|---|---|
| tolerance 1e-4 | 0.84–0.88 | 0.06 (dry), 0.11 (episodic) | 0.99 (0.97), 0.65 (0.74) |
| tolerance 3e-4 | 0.73–0.78 | 0.32 on dry; episodic's elasticities NaN | |
| no edges after 20 | 0.88–0.91 | 0.34, 0.27 | 0.67 (0.97), 0.61 (0.74) |
| 10–20 at about 190 d | 0.93–0.94 | 0.77, 0.91 | 1.74, 1.65 |

- **Tolerance 1e-4 is free accuracy-wise and saves 12–16% of every run.** At 3e-4 the run
  fails (NaN), so 1e-4 is the setting.
- Edges after 20 matter. Dropping them moved 10–14 quantities by over 0.1ε, and only
  2 of each record's moved toward the reference; rms error rose (0.31 → 0.33 dry,
  0.19 → 0.22 episodic; `loc/noedge.R`). The worst error fell only because a_l1 moved
  by chance. An interval across an edge interpolates its counted cohorts from a node in
  the shut gap, a first-order error even where little is earned. Where they stop
  mattering (after 25, after 30) is being probed.
- The 100 d range is real: intervals near 190 d err up to 1.7ε.

## The founders' window (13 October)

About 32 configurations on the scorer, inside the a04_proxy framework (`any/f05.R`):
- **It costs 14% of T** (1186 of 8384): 16–22 nodes committed, 26–34 in the check; the
  first-mover layer is 3.8% of T.
- **Its error follows the pilot's offspring curve:** d ≈ 0.055·g′²·f/J, f the pilot's
  offspring by birth date and g = ln f, within ×1.3 on dry and lma (the first panel
  reads lower on long-wet and long drought). Spacing by it, for equal error per
  interval, did not beat the step layer (8395 against 8384).
- The layer's extent (offspring falling 10-fold) is a local optimum; refining beside b1
  costs more than it buys; the quiet middle is held by the b1/12 limit (d there 0.1–0.3),
  and halving its nodes would save about 2.3% only if real runs allow 200 d intervals.
- The check must refine the founders by the same ratio as the rest: one shrink s cannot
  serve two ratios (a founders-only quantity misread by up to ×1.5).
- Dropping the layer where the pilot predicts little founders' error (episodic, by 2.8×
  from the next case) saves 69 of episodic's T: T 8316 at 98/100 draws against 8384 at
  99/100. Within noise of a04; the founders' window is close to its optimum.
