# The creation grid by the stand's structure

The grid consultation's second reply (`docs/oracle-response-grid-controller.md`)
reads the creation axis as a canopy:
- a first-mover layer at the opening of each creation window;
- the windows' edges;
- a fate front between members that reach the canopy and members left below it.

It proposes grids built from that structure, and five experiments. This note
has experiments 1, 3 and 4.

The setting:
- Cash–Karp under the tied tolerance at `tol = 3e-5`, each record's knots as step
  targets;
- one species at `lma = 0.32`, lifetime 40, birth-date density;
- `PLANT-98` (the `lib_guard` library).

The scripts:
- `harness/run_record.R` runs each grid, with `TIMES` (a schedule file) and
  `FORWARD=1` (the stand alone, with no gradient) unless stated;
- `harness/graded_times.R` writes every schedule;
- `harness/node_parts.R` splits `J`'s moves between nested grids;
- `harness/first_panel.R` with `TIMES` gives the invader's slopes.

The runs are in `creation-grid/`, each named for its schedule in
`graded_times.R`, with `_full` where it carries every gradient. `const_Gbf16` is
the 53-node causal grid with nodes added every 1/16 day around the front, 150 in
all; `u108` and the like are uniform. `fp_*.log` are `first_panel.R`'s.

## The creation record

`run_record.R` now saves, for each accepted step, the creation probability
averaged over the step: the growth of the newest node's establishment integral
in the stored trajectory. It also saves each node's height and mortality integral
at the end. On the constant record, long drought and wet the uniform 108-node
run reproduces the spot-check's `J` exactly.

## The constant record (experiment 3)

**Creation does not stop at the front.** On the stand with its first spacing
split 32 ways:
- creation runs at 0.998 to 4.9 and falls to zero at 5.20, an integral of 0.066
  before the front at day 23.5 and 5.0 after it;
- it opens again at 11.11, once the first understory has died, and runs to the
  end at a median 0.68, an integral of 19.

On uniform 108 nodes it closes at 5.20 too, has a faint window from 7.94 to
8.40, and never opens again.

**The reply's rule as written fails.** It puts ten panels growing by 1.18 from a
day to day 23.5, and nothing after. `J` is 330.3, 14% high. The last node's open
panel takes all later creation, a weight of 9.96, at the state of a member born
on the front, which dies.

**With the understory represented, ten members before the front give `J` within
1%.** The grids follow the reply's rules by hand:
- the ten panels to the front, then growing by 1.4 per panel to a cap;
- uniform at the cap to the first window's close at 5.20;
- nothing in the gap;
- a node at 11.11 and the second window uniform.

| cap in the first window | spacing in the second | nodes | `J` |
|---|---|---|---|
| 0.37 | 0.37 | 111 | 287.7427 |
| 0.37 | 1.48 | 53 | 287.7427 |
| 0.74 | 0.74 | 68 | 287.7418 |

The understory's spacing moves `J` by at most 3e-6 of itself. All three are 0.53%
below the converged 289.274, which is 0.21ε.

**The front is sharp, and its panel is first order.** On the grid with nodes every
⅛ day around it:
- the members born by day 23.38 end at 17.5–17.9 m, with mortality integrals of
  0.42–0.45;
- their net reproduction ratio falls from 1.5e5 at day 19 to 4.0e3 at day 23.38;
- the member born at day 23.50 ends at 15.9 m with a mortality integral of 32.

So the front is under ⅛ day wide. Nodes around it, over days 20–26, converge `J`:

| nodes around the front | on the 111-node grid | on the 53-node grid |
|---|---|---|
| every ½ day | 289.3381 (124 nodes) | |
| ¼ | 289.2900 (136) | |
| ⅛ | 289.2732 (160) | 289.2732 (102) |
| 1/16 | | 289.2739 (150) |
| 1/32 | | 289.2738 (246) |

Against that, 289.274:
- uniform 108 nodes give 1.204;
- the first spacing split 32 and 128 ways gives 291.55 and 289.39, the 128-way
  split with 215 uniform nodes after it 289.31;
- the 53-node causal grid gives 287.74.

**The gradients need the front.** `run_record.R` with every gradient, on the
53-node grid with nodes around the front:

| around the front | resident `lma` | invader `lma` | resident: over ε against the next | invader: over ε against the next |
|---|---|---|---|---|
| none (`first_panel.R`) | −6.221 | −133.3 | | |
| every ⅛ day, 102 nodes | −6.943 | −187.38 | 2 of 48, median 0.022ε | 36 of 48, median 3.3ε |
| 1/16, 150 | −6.940 | −186.19 | 2, median 0.021ε | none, median 0.049ε |
| 1/32, 246 | −6.937 | −186.17 | | |

- The resident converges with the front at ⅛ day. Its main traits move by at most
  0.18ε from ⅛ to 1/16 day. The two over ε are `d_I` and `a_f1`, by 1.0–1.2ε at
  each halving, and their moves do not shrink: about 5e-4 and 1.3e-3.
- The invader converges at 1/16 day. From 1/16 to 1/32 its largest move is
  `a_l1`'s, 0.1ε.
- The understory's spacing does not matter. With the second window at 0.37 in
  place of 1.48 (160 nodes against 102), no gradient of either role moves by
  more than 5e-4ε.
- Without the front the resident's `lma` is 8ε off. The 32- and 128-way splits
  give −7.061 and −7.027, the 128-way split 1.0ε off. Uniform 108 nodes give
  −18.37.

## The invader's cliff (experiment 4)

`first_panel.R` with `INVADER=1 D=1e-4` and `M` at `e^{±u}`. It reports the
invader's swept elasticity and the slope of `ln J′` from the resident's at each
`u`, taken on the left and on the right.

| `u` | split 32 ways, front at 4.2 days: left, right | split 128 ways, 1.05 days | causal, ⅛ day |
|---|---|---|---|
| 1e-4 | −150.1, −160.5 | −184.1, −203.6 | −184.7, −187.5 |
| 3e-4 | −141.6, −173.3 | −176.8, −186.0 | −181.9, −190.7 |
| 1e-3 | −172.2, −215.3 | −170.7, −197.0 | −179.7, −204.1 |
| 3e-3 | −150.5, −232.1 | −152.6, −237.1 | −162.0, −234.3 |
| 1e-2 | −113.6, −1169 | −114.0, −1185 | −117.7, −1203 |
| swept | −155.0 | −194.6 | −187.4 |

- *The cliff's shape is the model's.* At `u` of 3e-3 and 1e-2 the three grids'
  slopes agree to within 8%.
- *Near `θ′ = θ` only the resolved front is smooth.* On the causal grid the gap
  between the two slopes closes in proportion to `u`: 2.8, 8.8, 24 and 72 at 1e-4
  to 3e-3. That is `(ln J′)″ ≈ −2.5e4`, and a radius `|g|/|g′|` of 0.0075 in
  `ln lma`. On the split grids the slopes still jump at the scale of 1e-4.
- *The sweep is right on every grid.* Its gradient matches the central difference
  over ±1e-4 to 0.7% on each one. The grids differ in their local slope because a
  panel across the front misplaces it: −155 and −194.6 against −187.4.
- *The earlier −194 was the chord.* At 8 and 32 ways the central difference over
  ±1e-3 was −194, the mean of the two slopes there; the swept −155 was the 32-way
  grid's local slope.

## Graded grids on long drought and wet (experiment 1)

The reply's grid, as experiment 1 describes it:
- the first window geometric from 0.03, growing by 1.11 per panel to 0.37, with
  26 nodes before the first gap;
- nodes at that gap's two edges (3.5587 and 3.7309 on long drought, 3.5591 and
  3.7305 on wet, from the 108-node run's creation record) and none inside it;
- 108 uniform's nodes after it.

G2, G3 and G4 halve every panel of the grid before them, but the gap's.
Against uniform 54, 108, 215 and 429 nodes:

| record | grid | nodes | `J` | error | member steps |
|---|---|---|---|---|---|
| long drought | uniform | 54 | 12.88631 | +1.13% | 4.71e5 |
| | | 108 | 12.66855 | −0.58% | 9.62e5 |
| | | 215 | 12.72456 | −0.14% | 1.97e6 |
| | | 429 | 12.73758 | −0.037% | 4.07e6 |
| | graded | G1, 125 | 12.63375 | −0.85% | 1.25e6 |
| | | G2, 248 | 12.71520 | −0.21% | 2.56e6 |
| | | G3, 494 | 12.73556 | −0.053% | 5.26e6 |
| wet | uniform | 54 | 18.66890 | +0.94% | 5.87e5 |
| | | 108 | 18.40206 | −0.50% | 1.19e6 |
| | | 215 | 18.46254 | −0.18% | 2.42e6 |
| | | 429 | 18.48580 | −0.050% | 4.96e6 |
| | graded | G1, 125 | 18.36324 | −0.71% | 1.55e6 |
| | | G2, 248 | 18.45115 | −0.24% | 3.14e6 |
| | | G3, 494 | 18.48312 | −0.064% | 6.42e6 |
| | | G4, 986 | 18.49203 | −0.016% | 1.32e7 |

The error is against the extrapolation of each record's finest rungs: 12.7423 on
long drought, where the two ladders' extrapolations agree to 6e-5, and 18.495 on
wet, from G3 and G4. A node's member steps are the accepted steps after its
birth.

**The ratio of successive moves in `J`,** 4 on the square law:

| record | uniform 54, 108, 215 | uniform 108, 215, 429 | graded G1, G2, G3 | graded G2, G3, G4 |
|---|---|---|---|---|
| long drought | −3.9 | 4.3 | 4.0 | |
| wet | −4.4 | 2.6 | 2.75 | 3.59 |

**The two parts of each move,** from `node_parts.R`:

| record | grid | move | field part | quadrature part |
|---|---|---|---|---|
| long drought | uniform | 108 → 215 | +1.94% | −1.52% |
| | | 215 → 429 | +0.47% | −0.37% |
| | graded | G1 → G2 | +0.97% | −0.35% |
| | | G2 → G3 | +0.24% | −0.083% |
| wet | uniform | 108 → 215 | +2.01% | −1.70% |
| | | 215 → 429 | +0.55% | −0.43% |
| | graded | G1 → G2 | +0.80% | −0.34% |
| | | G2 → G3 | +0.26% | −0.093% |
| | | G3 → G4 | +0.073% | −0.026% |

- *On long drought uniform is on the square law from 108 nodes.* Each part falls
  4.1-fold from 108 → 215 to 215 → 429, and `J`'s ratio is 4.3. The ratios off
  the law that the spot-check read came from the 54-node rung. Its spacing, 0.75,
  is longer than the stretches between gaps in creation, and its error has the
  other sign.
- *The companion on 215 nodes is honest for `J` there.* It puts the 108-node
  error at 4/3 of the move, 0.59%, against 0.58%. On wet it gives 0.44%,
  against 0.50%.
- *Grading cuts both parts, and loses their cancellation.* At a matched count the
  graded grid's field part is half the uniform one's and its quadrature part a
  quarter. Its net move is larger, though, and so is its error at a matched cost:
  −0.85% for 1.25e6 member steps against −0.58% for 9.62e5 on long drought, and
  −0.71% against −0.50% on wet.
- *On wet the graded ladder reaches the square law only past 494 nodes.* Its
  ratio is 2.75 from G1 and 3.59 from G2, where both parts fall 3.6-fold;
  uniform's is 2.6 from 108.
- *Most of the field part is born before 1,* on both grids: +0.71% of G1 → G2's
  +0.97% on long drought.
- *The first-mover layer is not set by the final heights.* The reply puts its
  width at `0.02/|∂x_T/∂b|`, the reproduction switch's width over the slope of the
  final height profile. On long drought's G1 every member born before 3.1 ends at
  `x` of 1.07–1.08, so that is 7–14. Its net reproduction ratio e-folds every
  0.43–0.9 (937 at birth 0, 6.2 at 3.07), while its mortality integral rises only
  from 12.9 to 14.0.
- *By band the quadrature part is not meaningful.* Its pieces before 1 and from 1
  to 3 converge at about first order with opposite signs (+0.59% → +0.32% and
  −0.68% → −0.32% on long drought), because a band's edge cuts panels; their
  total falls 4.25-fold.

**The gradients on long drought,** with every gradient on uniform 429 and the
graded grids, against the spot-check's 108 and 215, in units of each quantity's
ε. The 429-node run is the reference; its own node error is at the tolerance's
noise for the resident.

| | resident: median error | over ε/3 | over ε | invader: median error | over ε/3 | over ε |
|---|---|---|---|---|---|---|
| uniform 108 | 0.26 | 13 of 49 | 2 | 0.14 | 10 | 1 |
| graded G1, 125 | 0.12 | 7 | 1 | 0.27 | 7 | 1 |
| uniform 215 | 0.018 | 1 | 1 | 0.12 | 1 | 0 |
| graded G2, 248 | 0.030 | 1 | 1 | 0.17 | 2 | 0 |

For the invader 429 is a weaker reference: if its moves keep shrinking threefold
per halving, its own error is about 0.04ε.

- *The resident is on the square law from 108 nodes.* Where the move from 215 to
  429 exceeds three times the tolerance nudge, on 7 of 49 quantities, the ratio of
  successive moves runs from 2.1 to 13.8, median 4.5, none below zero. Elsewhere
  the move from 215 is under the tolerance's noise: 0.01–0.04ε for the main
  traits, against 0.12–0.31ε from 108. The 215-node companion's estimate of the
  108-node error, 4/3 of the move, is 1.09 times the error against 429 (median).
- *The invader is not.* Its moves are resolved on 44 of 49 quantities, and on 33
  of them the move from 215 to 429 reverses the move from 108 to 215. Its `lma`
  goes −27.069, −26.973, −27.004, and `stem_P50` 26.734, 26.686, 26.711. The size
  of the move falls about threefold per halving, but its sign does not hold, so
  the companion's estimate is 2.15 times the error against 429 (median).
- *The graded ladder puts the resident on the square law as well.* With G3's
  resident gradients, 7 quantities are resolved, with a median ratio of 3.9–5.0
  by group and none below zero: `ln J` 4.02, `hmat` 3.91. G3 and uniform 429
  agree to a median 0.014ε.
- *Grading helps the resident at about 108 nodes, and neither role at about
  215.* The graded grid halves the resident's median error at 125 nodes. Its `lma`,
  `stem_P50` and `rho` errors are 0.14–0.37 of uniform's, but its `ln J` and
  `hmat` are worse. The invader's median error doubles. At 248 nodes both roles'
  median errors are larger than uniform 215's: 0.030ε against 0.018ε, and 0.17ε
  against 0.12ε.

## Not run

- *Experiment 2,* the panel estimate from the sweep, needs the sweep's adjoints of
  the field intermediates, which plant's sweep does not expose.
- *Experiment 5.* A node puts no leaf area above its own top (`Q(h, h) = 0`), so
  `A(x_j; x_j)` is zero. But TF24's default shading reads the leaf-area-weighted
  openness over the crown, `[0, h]`, which includes the node's own leaf area. A
  run with and without that self-term needs a change in plant.
