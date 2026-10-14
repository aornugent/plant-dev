# P: what accuracy requires of nodes around establishment edges (round 4)

Question: a09 makes every pilot edge before 25 a node (44–81% of committed nodes), yet F
found dry-p50 on dry's grid (none of its edges a node, 29 more than 1 d off) within 0.07ε
of its own grid. What does an edge inside an interval do, and what is required?

Scripts beside this file (`lib.R` loads F's lib plus edge tables, interval anatomy,
schedule variants); schedules and outputs in `scratchpad/dev/schedtest/P_out/`.

## The arithmetic (lib19 = plant fa9afe76: instantaneous gate, exact counts, crown spread)

- lib19 predates the averaged gate (`b3a33626` is not an ancestor of `fa9afe76`): pr_estab
  switches over 0.06 d (open) / 1.7 d (close). Edges are sharp.
- On the birth-date path a node is born at the birth rate with mortality 0 whatever the
  gate; pr_estab enters only through the interval's exact integrals E_j, M_j
  (`Node::interval_shares`: {E − M/Δ, M/Δ}). A node born in a shut gap is a full cohort
  of hypothetical recruits that faces the gap's conditions.
- Counts and water use: Σ_j w_j g(N_j), i.e. ∫ pr(b) g_lin(b) db with g_lin the hat
  interpolant between the interval's two nodes. Exact in pr; an edge inside the interval
  adds no error of its own. The error is ∫ pr (g − g_lin): it depends on how well the two
  nodes' cohorts represent the recruits that actually establish.
- Light (crown spread, `for_each_interval_crown`): leaf area at_node = share.first·L_j,
  at_end = share.second·L_{j+1}, spread over 8 crowns at heights h_j + u(h_{j+1} − h_j)
  with density 2(1−u)·at_node + 2u·at_end. A linear density in u whose mean can only lie
  in [1/3, 2/3]: establishment lopsided inside an interval (a sliver beside a gap) is
  smeared over the whole interval's height range, its mean height off by up to 1/3 of the
  height difference across the interval.
- The old reasons for edge nodes (`diag-edge-resolving-mesh.md`: "a misplaced root node
  is a live cohort whose weight spans a dead band"; −11% J for a node on the ramp) were
  trapezium-era: weights were node values of the gate. Exact counts removed that channel.
  The references themselves are uniform u215 → u429 ladders with edges anywhere.
- Per-recruit fate across gaps (`gaps.R`, a09 committed runs, Δ ln nrr edge to edge):
  gaps under 10 d move it 0.001–0.002, 10–60 d 0.02–0.05, over 60 d 0.42–0.62 (the dry
  seasons). A node inside a long gap is not like the recruits beside it; one inside a
  short gap is.

## Hypotheses

- H_at: a node must sit at the edge (step boundary / transport of the edge with θ).
- H_out: a node must not sit inside a shut gap next to establishing births (its cohort
  misrepresents their fate, leaf area, water use); first order in the displacement.
- H_spread: establishment must not be lopsided inside an interval (slivers across a gap
  are smeared by the crown spread over the gap's height range).
- H_inside: only the spacing of nodes over open time matters; the exact integral handles
  edges inside intervals and nodes may sit anywhere.

Variants of a09's committed schedule (`make.R CASE`), node count kept unless stated:
`outK` each edge node K days into its gap (≤ 0.45 of the gap); `inK` K days into its
spell (≤ 0.45 of the spell); `mid` each spell's edge-to-edge segments replaced by their
midpoints (no edge nodes after b1, one node fewer per spell: dry 169 → 122, episodic
137 → 108, long drought 167 → 115).

Noise floor: equivalent schedules differ by rms 0.02–0.04ε, max ~0.07–0.1ε (F, round 3 A).

## Pre-registrations (written before each run)

Runs on lib19, TOL 1e-4, one.sh defaults, against a09's committed run (val_a09_c_dry).

- P1 (out10, dry): max move 0.15–0.5ε, rms over 0.05 (H_out). H_inside predicts ≤ 0.1.
- P2 (in10, dry): max move ≤ 0.15ε (55%); ≥ 0.3ε would make H_spread real.
- P3 (mid, dry): max move ≤ 0.25ε (50%), worst error within 0.2ε of the base's 0.94.
  If it holds, edges need no node at all, only nodes inside spells.
- P4 (out3, dry): max move ≤ 0.1ε (noise), against H_at's ≥ 0.2.

### P1 result (P_out10_dry): holds

Max move 0.42ε (stem_c), rms 0.115, 9 quantities over 0.1, 3 over 0.3; ln J +0.03. The
moves lie along the hydraulic direction (stem_c +0.42, root_P50 +0.36, omega −0.35, root_c
−0.24, storage_relaxation_offset −0.18), not ln J. Worst error 0.90 (base 0.94), rms
0.338 (0.302). Rows +1.7%. Nodes 10 d inside gaps are not free.

### P2 result (P_in10_dry): refuted in size, and inverted in sign

Max move 0.66ε (a_l1), rms 0.217, 25 over 0.1; ln J +0.146. But the move is the base's
error undone: corr(move, base error) −0.88. **Worst error 0.94 → 0.36, rms 0.302 → 0.153**,
same node count, rows −1.3%. a_l1 0.94 → 0.28, root_P50 0.47 → −0.14,
storage_relaxation_offset −0.53 → −0.01. Moving each edge node 10 d into its spell halves
the committed run's error. So the node at the edge is not what accuracy needs; it is a
source of the error.

`layer.R dry` (ln nrr at each edge with both shifts the full 10 d, from the base, in10 and
out10 runs): at closing edges the fate rises steeply in the spell's last days and on into
the gap (edge − 10 d inside: +0.032; 10 d into the gap − edge: +0.065); the base's hat
interpolant 10 d inside reads +0.023 high, i.e. the edge's value leaks across the last
interval. Opening edges: a mild peak (edge − inside +0.020, hat −0.008, gap side −0.007).

H_layer (new): the per-recruit quantities have a layer a few days wide at each edge (most
at closing edges). A node at the edge samples the layer's extreme and the hat function
spreads it over half the neighbouring interval (h/2 ≈ 36 d against a layer of days):
a first-order bias that sits in every spell. A node a layer-width inside samples the
bulk; the layer's days fall into the gap interval with their weight on the inside node,
counted over their true width only.

- P3 (mid, dry), revised before running: worst error ≤ 0.6ε and corr(move, base error)
  < −0.5 (mid removes the edge nodes as in10 does, nodes h'/2 inside); 60%.

### P3 result (P_mid_dry): holds

122 nodes (−28%), rows 417k (−29.5%), CPU 229 s (−31%). **Worst error 0.60 (root_P50),
rms 0.152, against the base's 0.94 / 0.302**; corr(move, base error) −0.92. ln J error
−0.319 → +0.213.

`proj.R`: every move lies on one direction. Taking in10's move M as the unit, in10 = 1,
mid = 1.68 (corr 0.96), out10 = −0.28 (corr −0.52). The base's error is −1.22 M plus a
residual of rms 0.145 (base rms 0.302): **the edge nodes' bias is about 80% of the a09
committed run's squared error on dry**, and a09's own estimate projects 1.14 on M (the
check reads it, since refining h shrinks it). The error-free point on the axis is ≈1.2:
in10 stops just short, mid overshoots by 0.46 M (residual errors of the opposite sign:
root_P50 −0.60, ln J +0.21).

The move saturates with the inward distance d: an exponential layer of width w gives
p(d) ∝ 1 − e^(−d/w); p(36 d)/p(10 d) = 1.68 → w ≈ 12 d, p(∞) ≈ 1.77.

- P5 (in3, dry): projection on M 0.3–0.5 (w ≈ 12 d predicts 0.39); a layer of 2 d or
  less (the node must merely not be at the edge) would give ≥ 0.8.

### P5 result (P_in3_dry): refuted low; the narrow-layer alternative refuted harder

Projection on M 0.25 (corr 0.80), worst 0.81, rms 0.257; moves max 0.28. So p(3) = 0.25,
p(10) = 1, p(36) = 1.68: roughly linear in d up to ~10–15 d, saturating beyond. Being
3 d off the edge is a quarter of the way: no step at the edge (H_at dead), and the
structure is broad, of order 10–20 d, not a sliver.

Base errors for reference (a09 c): episodic 0.76 / rms 0.196, long drought (a09p) 0.57 /
0.172, dry-flat 0.95 / 0.342 (81% edges), episodic-lma 1.29 / 0.690 (commits fine).

- P6 (mid on episodic, long drought, dry-flat): on each, corr(move, base error) < −0.4,
  rms error ≤ the base's, worst error ≤ the base's + 0.1; the improvement largest on
  dry-flat (most edges) and smallest on episodic (fewest, longest spells).

### P6 result (mid on episodic, long drought, dry-flat): holds on all three

| case | nodes | rows | CPU | worst error (base) | rms error (base) | corr(move, base err) |
|---|---|---|---|---|---|---|
| dry | 169 → 122 | −29.5% | −31% | 0.60 (0.94) | 0.152 (0.302) | −0.92 |
| episodic | 137 → 108 | −22% | −30% | 0.53 (0.76) | 0.142 (0.196) | −0.94 |
| long drought | 167 → 115 | −32% | −33% | 0.23 (0.57) | 0.113 (0.172) | −0.77 |
| dry-flat (held out) | 230 → 138 | −41% | −48% | 0.43 (0.95) | 0.145 (0.342) | −0.92 |

Same direction everywhere: a_l1 down, root_P50 down, omega / storage_relaxation_offset
up, ln J up. Every mid run overshoots a little (errors of the opposite sign, 0.2–0.5).

`order.R`: on dry the edge bias (error projected on −M) is 1.22 in the committed run and
0.56 in the check, a ratio 2.18 for an open-spacing ratio 1.38 (1.90 squared): it shrinks
like a second-order term. So it is not a thin layer spread over h/2 (first order) but
curvature of the per-recruit quantities concentrated within ~10–20 d of each edge,
which the hat function across the spell's end interval reads with the node at the
curved end.

- P7 (mid's check, dry): the mid layout of a09's f schedule (P_midf_dry). Its error
  projects on −M at about −1.5 (saturated, like mid c's −0.46 overshoot), so the
  overshoot is shared by the pair and unread: the mid pair's estimate (c − f)/(1 − s)
  projects on M within 0.25 of zero while mid c's error projects at ≈ −0.46. C1–C5 may
  still pass because the overshoot is small; I predict pass with C3 marginal (50%).

**Container restart (05:15).** P_midf_dry was killed mid-run: its .rds is partial (stand
only, no gradient, no `finished`) and queue.out has no done line. Nothing else was lost:
P_out10, P_in10, P_mid, P_in3 (dry), P_mid on episodic, long drought and dry-flat all
completed before it. P7 is rerun as P_midf2_dry (same schedule, `midf2_dry.rds`); the
killed attempt counts against the budget (8 of 14 used before the rerun).

### P7 result (P_midf2_dry): refuted, in the useful direction

The mid check's error projects on −M at −0.32 (mid c −0.46): the overshoot is not
saturated, it shrinks with the spacing (the inside node sits h'/2 from the edge, so it
moves with h). The pair reads it: estimate −0.25 on M, and **C1–C5 pass, commits coarse,
s 0.43 (a09 0.42), estimate worst 0.54, read ratios 0.89–1.03 on the three quantities
over ε/3, corr(est, err) 0.93**. Check worst 0.30, rms 0.082. T on dry (rows model, three
committed + check) 1241 → 901 (−27%); real CPU 1424 → 1049 (−26%).

- P8 (mid check on episodic, long drought, dry-flat): each mid pair commits coarse and
  passes C1–C5 with a09's s rule; T falls 20–35% on each (dry-flat most).

### P8 result (mid checks on episodic, long drought, dry-flat): holds

| case | s (a09) | c worst / rms | f worst / rms | est worst | commits | C1–C5 | reads over ε/3 (a09's) | T rows model | real CPU |
|---|---|---|---|---|---|---|---|---|---|
| dry | 0.43 (0.42) | 0.60 / 0.152 | 0.30 / 0.082 | 0.54 | coarse | pass | 3: 0.89–1.03 (15: 0.32–1.47) | 1241 → 901 (−27%) | 1424 → 1049 (−26%) |
| episodic | 0.35 (0.34) | 0.53 / 0.142 | 0.36 / 0.101 | 0.39 | coarse | pass | 3: 0.30, 0.66, 0.73 (3: 0.54–1.13) | 720 → 579 (−20%) | 785 → 593 (−24%) |
| long drought | 0.42 (0.41) | 0.23 / 0.113 | 0.10 / 0.055 | 0.23 | coarse | pass | 0 (3: 0.82–0.96) | 1423 → 993 (−30%) | 1475 → 1076 (−27%) |
| dry-flat | 0.42 (0.42) | 0.43 / 0.145 | 0.34 / 0.102 | 0.52 | coarse | pass | 4: 0.37, 1.51, 1.63, 1.75 (12: 0.64–0.94) | 1955 → 1198 (−39%) | 2419 → 1389 (−43%) |

Four of four pass, all commit coarse, T −20% to −39% (rows), −24% to −43% (CPU). The
estimate correlates with the error less well than a09's (0.73–0.97 against 0.95–0.99)
and misreads more (a_l1 0.30 on episodic, root_P50 0.37 on dry-flat; one miss each,
inside C3), with far fewer quantities over ε/3.

Why it reads worse: mid's residual (its overshoot along M) shrinks with the spacing at
first order (dry: −0.46 → −0.32, ratio 1.44 for an open-spacing ratio 1.38), because the
inside node sits h'/2 from the edge, while s is read as a second-order shrink (0.42). The
pair reads a first-order component at (1 − 0.72)/(1 − 0.42) ≈ 0.5 of its size (dry:
estimate −0.25 against −0.46). Placing the spell-end nodes a fixed 10–15 d inside
(independent of h) would remove that term but leave the true edge-layer residual (in10:
−0.22 M on dry) shared by both runs, i.e. unread.

- P9 (episodic-lma, mid c and f; a09 commits fine there, c worst 1.29): the mid pair
  passes C1–C5; mid c worst error below 1.0 (so it may commit coarse); 55%.

### P9 result (episodic-lma, mid c and f): refuted; mid fails C3 there

mid c: 99 nodes (a09 120), worst 1.24 (a_l1; a09 +0.32 → −1.24), rms 0.452 (a09 0.690);
the move (corr −0.76 with the base error) overshoots far past the truth on a_l1. The pair
commits fine (est worst 1.06; f worst 0.80, rms 0.199 against a09 f's) and **fails C3**:
of 10 quantities over ε/3 on the fine side, a_l1 reads 0.40, omega 0.33,
storage_relaxation_offset the wrong sign (−0.16), vcmax_25 5.3. T (fine commit) 755 →
643 (−15%). The first-order overshoot of the h'/2 placement is case-dependent and is what
the pair misreads.

Real runs: 14 of 14 (out10, in10, in3, mid ×5 cases, mid checks ×5 including the killed
P_midf_dry). The in3 attempt at 04:56:46 exited in 1 s without a schedule (not counted).

## Mechanism, as measured

1. On lib19 (instantaneous gate, exact counts, crown spread) an edge inside an interval
   costs nothing by itself: the establishment integral is exact and the references are
   uniform ladders with edges anywhere. Nodes 1 d off the edges cost ≤ 0.07ε (F).
2. The per-recruit quantities (fate; by the moves, also water use: the moved direction is
   a_l1, root_P50, omega, root_c, stem_c, storage_relaxation_offset) curve strongly within
   ~10–20 d of each edge, mostly at closing edges (ln nrr rises 0.03 over the spell's last
   10 d and 0.065 over the gap's first 10 d on dry). A node at the edge anchors the hat
   interpolant of the spell's end interval at that curved end. The misread is a large,
   one-signed, second-order term (c/f ratio 2.18 on dry): **about 80% of a09's committed
   squared error on dry** (error = −1.22 M + rms 0.145).
3. Moving the end node d days inside trades it for the strip's own misrepresentation in
   the gap interval: p(d) on dry 0.25 (3 d), 1 (10 d), 1.68 (h'/2 ≈ 36 d), out10 −0.28; the
   error-free point ≈ 1.22, i.e. d ≈ 12–15 d on dry. Beyond that the run overshoots, and
   when d scales with h (mid: h'/2) the overshoot is first order in h, which a pair read
   with a second-order s under-reads by about half (dry: −0.25 read for −0.46).

## What is required, as a rule

- Not required: a node at the edge, or near it. A node at the edge is the error source.
- Required: no node in the curved strip next to an edge; each spell's outermost nodes sit
  about 12 d inside it (a fixed distance, the same in the committed run and the check;
  one node at the centre of a spell shorter than 24 d); interior nodes at the usual
  spacing; each gap is one interval between the two spells' end nodes. A node inside a
  gap next to establishing births is worse than one at the edge (out10).
- Count (a09 c, all ten): fixed 12 d inset 1644 → 1517 nodes (−8%); 18 d 1466 (−11%);
  the mid layout 1164 (−29%) — measured T −20% to −39% on four cases, but it fails C3 on
  episodic-lma, so as built it is not safe.
