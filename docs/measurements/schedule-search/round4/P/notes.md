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
