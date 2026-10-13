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

## Second lateral round: a floor for answer-plus-check (13 October)

About 35 configurations (`any/floor.R`, `any/oracle.R`, `any/b01_alt.R`):
- **The answer is near the scorer's range.** Setting every interval to the widest the
  range allows makes the answer only 4–7% cheaper, and that schedule errs by 0.94–2.42ε.
  Choosing each case's spacing with full knowledge, to land the worst error at 0.8–0.9ε,
  saves 2.1–3.3% of the answer. Edges dominate every run.
- **So T ≈ 3·answer + check ≥ about 8000** at tolerance 3e-5 (answer ≥ about 1890, check
  1.25–1.4× the answer), about 6900 at 1e-4. a04_proxy (8384) is within 5% of it.
- Failed: a refinement ratio per region (one move cannot separate regions whose terms
  cancel by sign; estimate/error 0.03–2.34); shrinking small estimates (fails C2); a lower
  ratio with a rescue run (R = 1.4 fails 21 of 40 draws, estimate noise lifts small
  errors past ε/3); a check shifted by half an interval (inside fixed edges it is a
  partial check, elsewhere its expected move is zero).
- **The nested alternative:** `any/b01_alt.R`, a check that contains the answer and
  bisects a share of its intervals, scaled from the pilot: T 8607, 40/40 and 100/100. The
  fallback if a04's non-nested jitter proves larger on real runs.
- The scorer extrapolates its square law to the 280 d intervals after 20, which carry
  11–38% of the modelled error; the real runs of a04 test that.

What is left lies in the constraints, not the search: the 100 d range and edges as
nodes (both confirmed by real probes), and the check being a full gradient run (every
family that avoided one could not read elasticities honestly).

## a04_proxy at tolerance 1e-4, real runs (13 October)

| case | commits | worst | C1–C5 | T | c05_graded at 3e-5 |
|---|---|---|---|---|---|
| episodic | coarse | 0.81 | pass (2 of 3 over ε/3 read) | 761 | 1065 |
| dry | coarse | 0.97 | pass (16/17) | 1363 | 1774 |
| long-wet | coarse | 0.49 | pass (2/2) | 1573 | 2069 |
| lma ×1.25 | fine | 0.56 | pass (18/18) | 781 | 1216 |
| long drought | — | — | **C4: the sweep refused on both runs** | — | 3448 |

- Where it passes, T is 23–36% below c05_graded at 3e-5, and real rows are 0.81–0.87 of
  the scorer's model (fit at 3e-5), so the tolerance's saving is about what the probes
  measured.
- Long drought at 1e-4: the forward runs completed, and both sweeps refused with
  "past the vulnerability curve's domain" (phylloptim, stem curve). Long drought runs
  without splits. The same schedule is being rerun at 3e-5 to tell the tolerance from
  the schedule; tolerance 3e-4 already returned NaN elasticities on episodic.
- Tail edges, at 1e-4: dropping those after 25 moves no quantity by more than 0.08ε and
  saves 6.5–10% of the committed run's rows; after 30, about nothing either way
  (`loc/probes2.R`). The band 20–25 is what mattered.

## Root cause: long drought's sweep refuses at tolerance 1e-4

Systematic debugging (`loc/prereg.md`, `loc/soilcmp.R`):
- The refusal is the **root** vulnerability curve's: the throwing function serves both
  curves, and x = 256 is 31 MPa on the root curve (420 MPa on the stem's, which its table
  would have refused first).
- **The forward model and its derivative disagree past the root curve's dry end.** The
  forward root integral is capped at its limit past 7.31 MPa (`root_vuln_integral_at`);
  the sweep's exact path (`closed_form_integral` →
  `cumulative_vulnerability_integral_derivatives_at`) has no cap and refuses past the
  curve's P99, 6.89 MPa.
- **The dry evaluations are stages inside accepted steps.** No recorded state passes
  5.17 MPa at either tolerance. Replaying the step sequences pinned: 1e-4's steps at
  tolerance 3e-5 refuse and 3e-5's steps at 1e-4 pass, as predicted; in the replays the
  root integral cap binds 2189 times on 1e-4's steps and never on 3e-5's.
- So the step sequence decides it: longer steps at 1e-4 carry stages whose rooted soil
  layer passes 7.31 MPa; the forward caps it (uptake is about zero either way) and accepts
  the step; the sweep replays the stage and refuses. 3e-5 avoided it on this schedule, but
  nothing in the model guarantees that at any tolerance.
- The fix belongs where the mismatch is: the derivative path should differentiate the
  capped curve the forward evaluates (value at the cap, zero slope in ψ, the cap's own
  trait rows), not refuse it. That is a phylloptim change, outside the schedule.

### All ten cases

| case | verdict | T | c05_graded at 3e-5 |
|---|---|---|---|
| episodic | pass | 761 | 1065 |
| dry | pass | 1363 | 1774 |
| long-wet | pass | 1573 | 2069 |
| lma ×1.25 | pass | 781 | 1216 |
| long drought | **C4: sweep refused** (the root curve, above) | — | 3448 |
| dry without season | **C2, C3 fail**: estimate reads 0.69 of the error, storage_relaxation_offset 0.41 | 2346 | 3066 |
| long drought, seed 102 | pass | 2553 | 3236 |
| long drought, seed 105 | **C4: sweep refused**, (ψ/b)^c = 5783 | — | 3054 |
| dry, root_P50 ×1.2 | pass | 1420 | 1861 |
| long-wet, a_dG2 ×1.25 | pass | 1623 | 2135 |

- Seven of ten pass, at 21–36% less T than c05_graded at 3e-5, which passed all ten.
- Two long-drought records refuse at 1e-4: the dry-stage mechanism above, a defect in
  the derivative path rather than in the schedule.
- On dry without season the non-nested check under-reads (0.69 median; storage 0.41).
  Its shrink s comes from the pilot's offspring^0.6·h³, and where the error sits in
  intervals the ratio cannot refine (short spells between edges) the real shrink is
  smaller than the proxy's. c05_graded's nested check read the same case at 0.92 with
  12 of 12. This is lesson 15 again: a non-nested pair's estimate depends on a model of
  where the error is.

### After the fix (phylloptim 0.9.2)

The root curve's derivative past its dry end is fixed in phylloptim 0.9.2 (branch
PHYLLOPTIM-18, aornugent/phylloptim#18): the rows are those of what the table returns
there (the last knot's tangent, then G(inf)). The four refused runs, rerun on a lib
built against it (`loc/jobs_fix18.txt`):

| case | verdict | worst | T | c05_graded at 3e-5 |
|---|---|---|---|---|
| long drought | pass, coarse (6/6 read) | 0.56 | 2723 | 3448 |
| long drought, seed 105 | pass, coarse (3/3) | 0.45 | 2460 | 3054 |

- No refusal; forward J bit-identical to the refused runs (F1, F2).
- **a04 at 1e-4 now passes nine of ten cases,** at 21–36% less T than c05_graded at
  3e-5. Dry without season is the one left (next section).

## Root cause: a04's check under-reads dry without season

Systematic debugging (`loc/a04why*.R`, `loc/prereg.md`):
- **Not the tolerance.** a04's committed run at 1e-4 errs as c05_graded's (the same 356
  nodes) does at 3e-5: `a` −0.898 in both, every quantity within 0.07ε.
- **The real shrink is 0.51–0.87 against the proxy's 0.433** (median about 0.6), so
  move/(1 − s) reads about 0.7 of the error. c05_graded's nested check shrinks 0.19–0.39
  against its 0.25.
- **The ratio check refines this record's background least.** 312 edges leave gaps
  mostly shorter than 1/R of the target, which the ratio leaves at one interval: by
  band (proxy-weighted) the check shrinks 0.41 before b1, 0.59 to 10, 0.53 to 20, 0.33
  after. On dry, long-wet and episodic every band shrinks alike (0.37–0.54).
- **The proxy locates the error in the wrong place.** It puts 85% of dry without
  season's committed error before b1. Fitting err = α·F(S) + β·P(S) (F, P the proxy's
  h³ sums before and after b1) to four runs at once (a04's pair, c05_graded's pair),
  two parameters per quantity explain all four to 0.012ε median, and put about a
  quarter of the error before b1. On dry and long-wet the same fit agrees with the
  proxy (0.62 against 0.53; 0.91 against 0.64), which is why they pass.
- **Some quantities cannot be read by any single s.** storage_relaxation_offset, a_l1
  and stem_c carry opposite-sign error before and after b1 (−1.9 and +1.1, for
  storage). A shrink taken as the largest over the bands lifts the median read to 0.96
  and passes C2, but C3 still fails (7/10); the other seven cases still pass.

So the mechanism is lesson 15 at the scale of one record: a non-nested check is honest
only where it shrinks every interval that carries error by about the same factor. The
fix belongs in the check. **a05_fill** keeps a04's committed schedule and bisects, in
every gap the ratio gives no new node, the intervals wider than half the target (as
c05_graded's check would): +18 nodes on dry without season, band shrinks 0.40–0.44,
scorer T 8473 (+1%), 19/20 draws. Its real check runs are registered and queued.

## Short shut gaps cannot be spanned for free (13 October)

Edges are 53–88% of a04's committed nodes and 16–61 shut gaps per case are under 10 d,
so spanning those gaps with one interval looked like the largest lever left
(`loc/mkmerge.R`, `loc/merge_cmp.R`). On dry, G = 10 drops 12% of rows and moves stem_c
by +0.24ε and TF24_cost_scale by +0.17ε, both away from the reference (worst error 0.97
→ 1.03). Putting back the gap's later edge instead of a node at its centre changes
nothing, so the error is not the known one of a node where nothing establishes; it is
the merging. That is about what coarsening every interval by the same 12% would cost
(errors scale as N⁻², about +0.15ε here), so it is not a free saving.

On dry without season the same G = 10 drops 28% of rows and moves no quantity by more
than 0.12ε (rms 0.034; worst error 0.90 → 0.95), where coarsening by 28% would add about
0.3ε. So spanning short gaps is cheap on a record of scattered gaps and dear on a
seasonal one. Why is open: offspring per founder hardly differs across a short gap
(|Δ ln| ≤ 0.03 at every gap on all three records), so it is not a jump in the cohort's
own fate. The G = 30 probes were dropped.

The same mechanism shows inside spells (`loc/spellpos.R`, each case's G0 map, nodes
after b1 and before 20 in spells longer than two intervals): the error per interval
rises toward the closing edge. By quarter of the spell it runs 0.5–0.9, 0.7–1.1,
0.8–2.7 and 1.1–2.6 of the median; Spearman 0.19–0.42, positive on all five training
cases. Grading interior nodes toward each spell's end (h ∝ d^(-1/3), a 1.36 ratio
across a 2.5-fold rise) would cut about 3% of interior nodes at equal error, and
interior nodes are 12–47% of a committed schedule: 1–2% of T, not worth a run now.

## a05_fill on real runs (13 October)

a05's check (a04's, plus a bisection of each wide interval in a gap the ratio left
alone) on dry without season, at 1e-4: **pass**, commit coarse, worst 0.90, C1–C5 with
12 of 12 read (the three opposite-sign quantities included), estimate/error median 0.85,
T 2391 (a04: 2346, failing C2 and C3). The real shrinks run 0.46–0.70 (a04's 0.51–0.87).
On dry the verdict and reads are a04's (16/17, median 1.13 against 1.14), T +9. Registered
A1 (median 0.85–1.1) and A2 hold. Its checks on the other eight cases are queued.

### Where merging costs (13 October, continued)

Bisecting dry's 16 short gaps (`loc/mkmerge.R` with FROM/TO): the 13 after 10 move
nothing (max 0.02ε, rows −7.6%), the gap at 5.64 alone nothing (0.03ε); both moves come
from the pair at 5.403 and 5.416, which between them remove every edge of a one-day
open spell. Rules, each against the same schedule unmerged:

| rule (gaps under 10 d) | dry | dry without season | long drought |
|---|---|---|---|
| merge every gap | −12.3% rows, max 0.24ε | −28.3%, 0.12ε | −19.5%, 0.02ε |
| a spell keeps its start edge (SPELLS=1) | −10.8%, 0.10ε | −24.2%, 0.04ε | −18.5%, 0.03ε |
| every spell keeps both edges (SPELLS=2) | −7.9%, 0.09ε | | |

- **SPELLS=1 costs at most 0.10ε for 11–24% of rows** on three records; coarsening by the
  same share would cost about 0.15–0.3ε. Both registered "under 0.05ε" predictions for
  dry failed: what remains there is in that one cluster, and neither the cohort's fate
  (|Δ ln offspring| ≤ 0.03 across every gap) nor the offspring weight (dry's pair at 26×
  median; long drought's free gaps at 10–20×, dry without season's at up to 30,000×)
  separates it from the free gaps. Not understood.
- **For an algorithm:** a merge error does not shrink as the spacing refines, so a check
  that merges the same gaps cannot see it. A check that keeps the dropped edges reads it
  as a component with shrink 0, which is the mixed-shrink case a05 was built to avoid; at
  0.10ε it would sit inside the estimate's tolerance. Combining SPELLS=1 with c5t or a05
  is the next real-run candidate.

## c05_graded made cheaper: tolerance 1e-4, no edges after 25 (13 October)

Both of c05_graded's schedules lose their edges after b = 25 and run at 1e-4 on the fixed
phylloptim (`loc/mkc5t.R`, `loc/val_c5t.log`):

| case | commits | worst | C1–C5 | T | c05_graded at 3e-5 | a04 at 1e-4 |
|---|---|---|---|---|---|---|
| episodic | coarse | 0.60 | pass (3/3) | 798 | 1065 | 761 |
| dry | **fine** | 0.31 | pass | 1726 | 1774 | 1363 |
| long-wet | coarse | 0.49 | pass (2/2) | 1575 | 2069 | 1573 |
| long drought | coarse | 0.53 | pass (6/6) | 2759 | 3448 | 2723 |
| lma ×1.25 | fine | 0.20 | pass (2/2) | 935 | 1216 | 781 |
| dry without season | coarse | 0.95 | pass (12/12) | 2023 | 3066 | 2346 (fails) |
| long drought, seed 102 | coarse | 0.46 | pass (2/2) | 2559 | 3236 | 2553 |
| long drought, seed 105 | coarse | 0.41 | pass (4/4) | 2514 | 3054 | 2460 |
| dry, root_P50 ×1.2 | coarse | 0.95 | pass (14/14) | 1391 | 1861 | 1420 |
| long-wet, a_dG2 ×1.25 | coarse | 0.57 | pass (2/2) | 1603 | 2135 | 1623 |

- **Ten of ten pass,** at 22% less T than c05_graded at 3e-5 (17883 against 22924;
  training 7793 against 9572, held-out 10090 against 13352). Estimate/error medians
  0.92–1.28.
- Against the registration: K1 holds (10/10). K2 fails on dry, which now commits the fine
  run: its coarse error was already 0.97 at 3e-5, and the move tipped 4/3 of it past ε,
  so T falls only 3% there. K3: training sums to 7793, just above 7100–7700, for that
  reason. K4 cannot be read: the scorer requires every edge, so it does not model these
  schedules (its miss on the committed runs is 0.07–0.51ε rms).
- Where both pass, c5t costs about what a04 at 1e-4 costs (within 0–6% on seven cases;
  dry and lma ×1.25, which c5t commits fine, are the exceptions), and it also passes dry
  without season, where a04's non-nested check fails. a05 fixes that failure for 2%; a05
  without the late edges has not been run.

### a05_fill on all ten cases (13 October)

`loc/val_a05t.log`, tolerance 1e-4, the fixed phylloptim; a05's committed schedule is
a04's, its check a04's plus the bisected wide intervals:

| case | commits | worst | C1–C5 | T | a04 at 1e-4 | c5t |
|---|---|---|---|---|---|---|
| episodic | coarse | 0.81 | pass (3/3) | 768 | 761 (2/3) | 798 |
| dry | coarse | 0.97 | pass (16/17) | 1372 | 1363 | 1726 |
| long-wet | coarse | 0.49 | pass (2/2) | 1603 | 1573 | 1575 |
| long drought | coarse | 0.56 | pass (6/6) | 2743 | 2723 | 2759 |
| lma ×1.25 | fine | 0.52 | pass (17/17) | 796 | 781 | 935 |
| dry without season | coarse | 0.90 | pass (12/12) | 2391 | 2346 (fails) | 2023 |
| long drought, seed 102 | coarse | 0.45 | pass (3/3) | 2593 | 2553 | 2559 |
| long drought, seed 105 | coarse | 0.45 | pass (3/3) | 2476 | 2460 | 2514 |
| dry, root_P50 ×1.2 | coarse | 0.97 | pass (11/11) | 1428 | 1420 | 1391 |
| long-wet, a_dG2 ×1.25 | coarse | 0.57 | pass (2/2) | 1655 | 1623 | 1603 |

- **Ten of ten pass, T 17825:** 22% below c05_graded at 3e-5 (22924), 1.5% above a04 at
  1e-4 where a04 passes, and level with c5t (17883), which already drops the late edges
  that a05 keeps. Estimate/error medians 0.85–1.21.
- So a05 and c5t reach the same T by different routes: a05 by a cheaper check, c5t by a
  cheaper schedule. a06 (registered, running) puts c5t's trimming, plus the short-gap rule,
  on a05.

## a06: a05's schedules trimmed after building (13 October)

`loc/mka06.R`, `loc/val_a06.log`: both of a05's schedules lose every edge after 25 and the
edges of shut gaps under 10 d (a spell keeps its start edge), tolerance 1e-4.

| case | worst | C1–C5 | T | a05 |
|---|---|---|---|---|
| episodic | 0.76 | pass (3/3) | 698 | 768 |
| dry | 0.98 | pass (17/19) | 1119 | 1372 |
| long-wet | 0.51 | pass (2/2) | 1265 | 1603 |
| long drought | 0.51 | pass (3/3) | 2119 | 2743 |
| lma ×1.25 (fine) | 0.41 | pass (15/15) | 758 | 796 |
| dry without season | 0.92 | **C2 fails** (stem_c: error 0.51, estimate 0.23) | 1596 | 2391 |
| long drought, seed 102 | 0.46 | pass (4/4) | 2116 | 2593 |
| long drought, seed 105 | 0.42 | pass (6/7) | 2173 | 2476 |
| dry, root_P50 ×1.2 | 0.92 | pass (12/12) | 1126 | 1428 |
| long-wet, a_dG2 ×1.25 | 0.56 | pass (2/2) | 1303 | 1655 |

- Nine of ten pass; T 14273, **20% below a05 and 38% below c05_graded at 3e-5** (22924).
  B1 holds, B2 misses narrowly (19.9% against 20–30%), B3 holds (worst errors rise by at
  most 0.02ε).
- The failure is the order of operations, not the trimming: trimming moved stem_c by only
  +0.05ε, but trimming two finished schedules leaves the check's ratio and bisection nodes
  placed for gaps that no longer exist, and the band shrinks spread again (0.41–0.51 flat on
  dry without season). a07 trims the pilot's edges first and builds on what remains (band
  shrinks 0.40–0.45); it is running on all ten.

## a07: a05 built on the edges a run needs (13 October)

`any/a07_trimmed.R`, `loc/val_a07.log`: the pilot loses every edge after 25 and the
edges of shut gaps under 10 d (a spell keeps its start edge); merged gaps and the span
after 25 count as open; then a05 builds both schedules. Tolerance 1e-4.

| case | commits | worst | C1–C5 | est/err | T | a06 | a05 |
|---|---|---|---|---|---|---|---|
| episodic | **fine** | 0.26 | pass (1/1) | 1.00 | 877 | 698 | 768 |
| dry | coarse | 0.92 | pass (12/14) | 1.13 | 1131 | 1119 | 1372 |
| long-wet | coarse | 0.48 | pass (2/2) | 0.96 | 1282 | 1265 | 1603 |
| long drought | coarse | 0.54 | pass (3/3) | **0.65** | 2156 | 2119 | 2743 |
| lma ×1.25 | fine | 0.54 | pass (17/17) | 0.91 | 770 | 758 | 796 |
| dry without season | coarse | 0.94 | pass (12/13) | 0.86 | 1600 | 1596 (fails) | 2391 |
| long drought, seed 102 | coarse | 0.46 | pass (5/5) | 1.11 | 2091 | 2116 | 2593 |
| long drought, seed 105 | coarse | 0.49 | pass (3/3) | 0.99 | 2189 | 2173 | 2476 |
| dry, root_P50 ×1.2 | coarse | 0.99 | pass (13/14) | 0.99 | 1122 | 1126 | 1428 |
| long-wet, a_dG2 ×1.25 | coarse | 0.56 | pass (2/2) | 1.01 | 1321 | 1303 | 1655 |

- **Ten of ten pass, T 14539: 37% below c05_graded at 3e-5 (22924), 18% below a05
  (17825).** A7-1 holds. A7-2 fails on episodic only: a_l1's coarse error is 0.85 and its
  estimate 1.004, one part in 250 past the commit threshold, so it commits fine (+26%);
  elsewhere a07 is within ±2% of a06.
- Building on the trimmed edges fixes a06's failure on dry without season at the same
  cost (1600 against 1596).
- **Long drought reads 0.65** (still passing, 3/3 within ×2): every top quantity shrinks by
  about 0.6 against the proxy's 0.425, the signature of a first-order part. Nodes in shut
  periods are ruled out (one); seeds 102 and 105, with the same treatment after 25, read
  1.11 and 0.99, so the cause is particular to that record. a08 (late edges kept through
  the build, then dropped from both runs) is running on it.

## a08: late edges kept through the build (13 October)

`any/a08_trimmed.R`, `loc/val_a08.log`: as a07, but the edges after 25 stay in the pilot,
so late spells keep their own interior nodes, and are left out of both runs.

- **Nine of ten pass, T 14030** (a07 14539, a06 14273). It **fails C2 on dry**: root_P50
  errs 0.51 with an estimate of 0.20. a07 under-reads the same quantity (estimate about
  0.15) but its error stayed at 0.47, under C2's 0.5, so a07's ten of ten has thin margin.
- Long drought still reads 0.66, so the late region is not the cause of that under-read.
  The committed errors of a06, a07 and a08 agree there (a_l1 0.51, 0.54, 0.53); the checks
  differ: a06's check, laid out spell by spell before the merge, takes a_l1 to 0.23;
  a08's, laid out across merged spans, to 0.34, with as many nodes in every band. A check
  built across merged spans refines less of some quantities' error, and the spacing proxy
  cannot see it.
- So short-gap merging buys about 10% of T but costs the check's honesty on two of ten
  records. a09 (a05 with only the late edges left out, no merging) is running as the
  robust alternative.

## a09: a05 without the late edges, no merging (13 October)

`any/a09_late.R`, `loc/val_a09.log`: a05 builds on every edge; both runs leave out the
edges after 25.

| case | worst | C1–C5 | est/err | T | a05 | a07 |
|---|---|---|---|---|---|---|
| episodic | 0.76 | pass (3/3) | 0.94 | 720 | 768 | 877 |
| dry | 0.94 | pass (14/15) | 1.12 | 1241 | 1372 | 1131 |
| long-wet | 0.50 | pass (2/2) | 1.04 | 1470 | 1603 | 1282 |
| long drought | 0.53 | pass (4/4) | 1.12 | 2513 | 2743 | 2156 |
| lma ×1.25 (fine) | 0.41 | pass (20/20) | 1.17 | 755 | 796 | 770 |
| dry without season | 0.95 | pass (12/12) | 0.88 | 1955 | 2391 | 1600 |
| long drought, seed 102 | 0.46 | pass (3/3) | 1.01 | 2351 | 2593 | 2091 |
| long drought, seed 105 | 0.45 | pass (3/3) | 0.87 | 2332 | 2476 | 2189 |
| dry, root_P50 ×1.2 | 0.93 | pass (11/11) | 0.96 | 1278 | 1428 | 1122 |
| long-wet, a_dG2 ×1.25 | 0.57 | pass (2/2) | 0.93 | 1507 | 1655 | 1321 |

- **Ten of ten, every median read 0.87–1.17, T 16122:** 9.6% below a05, 30% below
  c05_graded at 3e-5. All three registered predictions hold.
- Long drought reads 1.12 (a07 0.65, a08 0.66): the under-read came from merging short gaps
  before the build, as the a06/a08 comparison suggested.

## Where the algorithms stand (13 October)

All at tolerance 1e-4 on the fixed phylloptim, the ten real cases:

T summed over the five training cases (the scorer's basis, where a04_proxy scored 8384 at
3e-5) and over all ten real cases:

| algorithm | passes | median reads | T, training five | T, all ten | against c05_graded at 3e-5 |
|---|---|---|---|---|---|
| c05_graded at 3e-5 | 10/10 | 0.82–1.11 | 9572 | 22924 | — |
| c5t: c05_graded, no edges after 25 | 10/10 | 0.92–1.28 | 7793 | 17883 | −22% |
| a05: a04 + bisected wide intervals | 10/10 | 0.85–1.21 | 7282 | 17825 | −22% |
| **a09: a05, no edges after 25** | **10/10** | **0.87–1.17** | **6699** | **16122** | **−30%** |
| a07: a05 on merged gaps, no edges after 25 | 10/10 | 0.65–1.13 | 6216 | 14539 | −37% |
| a08: as a07, late edges through the build | 9/10 | 0.66–1.17 | 5930 | 14030 | −39% |
| a06: a05 trimmed after the build | 9/10 | 0.81–1.15 | 5959 | 14273 | −38% |

On the training five, a09 is 20% below a04_proxy's scored 8384 and under the 1e-4 floor
estimated earlier (about 6900), which assumed every edge is a node.

- **a09 is the robust choice:** every case passes and every median read sits in 0.87–1.17.
- Merging shut gaps under 10 d buys a further ~10% (a07), but a check laid out across
  merged spans refines less of some quantities' error than the spacing proxy says (long
  drought reads 0.65, dry's root_P50 0.3), so a07's ten of ten holds with thin margin and
  a08's does not. The merge's own error is small (≤0.10ε); what it costs is the check's
  honesty. Making the merge safe would need a check that refines merged spans by the error
  they carry (e.g. toward each spell's closing edge), not by their length.

### Tolerance 3e-4 reopened (13 October)

The probe that ruled 3e-4 out (NaN elasticities on episodic, `val_probe_tol3e4_episodic`)
refused with the same root-curve error fixed in phylloptim 0.9.2 ((ψ/b)^c = 9.9, past the
dry end); dry at 3e-4 ran clean. So 3e-4 failed on the derivative path, not on accuracy.
Its CPU was 0.73–0.78 of the 3e-5 base against 1e-4's 0.84–0.88. Its largest move on dry
was 0.32ε, which a node-only check cannot see.

Where a09's T goes: the committed schedule, run three times (find plus two uses), is
66–70% of T; the check 30–34% (episodic-lma, which commits fine, 82/18). The check costs
1.30–1.53 committed runs.

## Round 3: one shrink for every error source, and edges by measured value (13 October)

Two offline lenses on the scorer and saved runs (scripts in `round3/A`, `round3/B`).

**A: can the check shrink every error source by one factor?** No; tolerance error is not
a power law.
- At 1e-4 the tolerance error is the same in both runs and small (≤0.06ε of bias, jitter
  rms 0.02–0.03), so the node-only check need not read it.
- It is flat up to 1e-4 and starts between 1e-4 and 3e-4, where it lies along one
  hydraulic direction (stem_c, TF24_cost_scale, storage_relaxation_offset move together)
  at 0.17–0.35ε on dry and lma. `ln J` barely moves. No s reads it, and a check at a
  matched looser tolerance saves at most 4–11% of rows (about 6% of CPU) while misreading
  whenever the fine run commits.
- Late edges dropped from both runs are shared error at shrink 0 (≤0.08ε): harmless.
- Splits cut the run-to-run jitter of a ±5% tolerance nudge 3–6× (rms 0.02–0.04 against
  0.08–0.13 without). Long drought runs without them.
- At 3e-4 rows fall to 0.875 of 1e-4 but CPU only to about 0.91.

**B: which edges does a run need, by measured value?** J's adjoint map of per-node
removal moves ranks the elasticities' edge cost backwards, and clustered removals do not
add (×5), so a map cannot choose edges. What can be done is thin the committed run only
and keep the check whole, reading the thinning at shrink 0 (`round3/B/prereg.md`):
- long drought, gaps under 10 d merged: commits coarse, passes, reads 1.16–1.23, T 2371
  against a05's 2743;
- dry-flat: passes, reads 0.86, T 1913 against 2391;
- dry, every gap: commits fine and fails C3, because the check's estimate s/(1 − s)·d
  carries the thinning shift (stem_c +0.21–0.24) into the fine run's read;
- dry, only gaps after b = 10 merged: passes, T 1300 against 1372.

So merging is safe where it is late and kept out of the check. B's lowest-risk design
merges gaps under 10 d after b = 10 in the committed run only, predicted T 6412 on the
training five (−4.3% on a09), at the cost of ten thinned committed runs to validate.

## Round 3: the check's structure, and a check reused across a trait move (13 October)

Agent C, on the scorer (a05_fill at R = 1.6, BG = 90: T 8473, 19/20 draws) and on saved
real runs (scripts in `round3/C`).

**The check's structure has about 1% left.** T = 3c + f with f = c + Δ, and the check
re-runs every edge, so Δ, the nodes the check adds, is only 668 s, 7.9% of T, and
55–68% of it lies between b1 and 25, where 56–88% of the error is.

| design | scorer T | draws passed | why |
|---|---|---|---|
| check is the widest legal schedule, estimate move/(s − 1) | 7669 | 0/5 | committed run already at the range; s spreads 1.04–4.1 across bands; dry's a_l1 reads the wrong sign |
| committed built finer so the check can coarsen evenly | 9088–9337 | 1/5 | the room costs 25–30% more committed nodes, paid three times; one-interval gaps cannot coarsen |
| bisect every wide interval (nested) | 8916; before 25 only 8818 | 5/5; 20/20 | reads exactly: the honest fallback at +4% |
| bisect the top 80% of proxy error | 8281 | 0/5 | the proxy misses lma's late storage_relaxation_offset error |
| a05 at R = 1.5, 1.4 | 8406, 8372 | 4/5 | 1/(1 − s) amplifies the jitter between non-nested runs |
| **check not refined after 25** | **8393** | **20/20** | after 25 the check spends 8–17% of Δ on 0.5–7% of the error |
| map on the committed run, bisect each region's top 75% | 8348 | 20/20 | passes only because the scorer cannot see sign-mixed error inside a band; its real counterpart read 0.55 on episodic |

Using J's map as ln J's estimate saves nothing: ln J never binds (worst 0.37ε).

**A check reused after a trait move.** On saved real runs of seven designs, θ1's schedule
built from θ1's own pilot, with θ0's estimate standing in for θ1's check:
- dry → dry-p50 (root_P50 ×1.2) and long-wet ↔ wet-adG2 (a_dG2 ×1.25) pass C1–C5 in every
  design (error correlation 0.93–0.98, rms difference 0.04–0.09ε; a09 reads 1.21, 0.91);
- dry-p50 → dry fails C2 in all seven: storage_relaxation_offset's error moves −0.31 →
  −0.53 with the trait, and θ0's estimate reads about 0;
- lma ×1.25 fails both ways, and the pilot flags it (J ×0.016, proxy ×0.06, against
  ×0.82–1.28 and ×0.90–0.97 for the moves that pass); ln J's own move does not;
- across weather seeds the estimate does not transfer (reads 0.24–0.88);
- only about half of θ1's edges lie within 1e-3 of θ0's, so a grid is rebuilt from θ1's
  pilot, not reused.
Where it holds, a rebuild costs 2c instead of 3c + f: −54% on dry-p50 (1278 → 588) and
wet-adG2 (1507 → 686). Its risk is a trait-sensitive quantity shifting 0.2ε, as
storage_relaxation_offset does at ×1.2 one way. It is untested on invaders and at the
objective's ±10% radius.

## Round 3 on real runs: 3e-4, merging in the committed run, a lighter check (13 October)

Pre-registrations and every number: `loc/prereg.md` (a09 at 3e-4, a10, a11, a12, the
nudge test, D1–D2, R1–R2).

| algorithm | passes | T, training five | T, all ten | against a09 |
|---|---|---|---|---|
| a09 at 1e-4 | 10/10 | 6699 | 16122 | — |
| a09 at 3e-4 (phylloptim 0.9.3 for long drought) | 9/10 (ld-102 C3) | 6066 | 14360 | −9.4%, −10.9% |
| a10: a09 + short gaps merged after 10, committed run only | 9/10 (long drought: a gradient blow-up, below) | 6399 | 15302 | −4.5%, −5.1% |
| a11: a09, check refined before 25 only | 10/10 | 6634 | 15985 | −1.0%, −0.85% |
| a12: a10's committed run, a11's check | 9/9 (long drought pending) | — | 12826 on nine | −5.8% on nine |

- **3e-4 needs phylloptim 0.9.3** (`PHYLLOPTIM-19`, aornugent/phylloptim#19): every
  long-drought record refused at 3e-4 on a determined collar until then. It then saves
  about 10%, but on ld-102 the tolerance error along the hydraulic direction lands
  unevenly in the two runs and the check misreads it (a_l1 reads 0.14 against 0.42):
  the unread error agent A warned of.
- **a10's merge is cheap and safe where it was measured** (moves ≤0.06ε on nine cases),
  but `mka10.R` first dropped both edges of some open spells (fixed: a spell whose gaps
  both merge keeps its start edge). The edges were not what broke long drought.
- **a11 saves 1%** and costs accuracy wherever the fine run commits (episodic-lma's worst
  0.41 → 0.69); its shrink must be read before 25, or the proxy credits the unrefined late
  region with error and pushes episodic to commit fine.

**Long drought's gradient blows up silently on some schedules and tolerances.** One a10
schedule gave −0.43, the cluster and a 33ε blow-up at tolerances 1e-4, 0.95e-4 and
1.05e-4 without splits, with J unchanged; with splits the 1.05e-4 run returned to the
cluster, but the fixed a10 schedule with splits returned elasticities up to 2186. No
refusal is recorded. The references are sound (the splits reference agrees with the old
to 0.04ε). This breaks "never fails" in its silent form and is being root-caused
(`round3/D/`); until it is, every long-drought number rests on runs that happened to
land in the cluster, and a guard that flags a blown gradient is needed for "diagnosed".
