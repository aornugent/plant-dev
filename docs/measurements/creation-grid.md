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

**The two parts of each move,** from `node_parts.R`. Each node's net reproduction
is weighted by the density of patches of its age at its birth, as in `J`. The
first version of this table left the weight out; no part moved by more than
0.04% of `J`.

| record | grid | move | field part | quadrature part |
|---|---|---|---|---|
| long drought | uniform | 108 → 215 | +1.97% | −1.53% |
| | | 215 → 429 | +0.47% | −0.37% |
| | graded | G1 → G2 | +0.96% | −0.31% |
| | | G2 → G3 | +0.23% | −0.073% |
| wet | uniform | 108 → 215 | +2.04% | −1.71% |
| | | 215 → 429 | +0.55% | −0.43% |
| | graded | G1 → G2 | +0.79% | −0.31% |
| | | G2 → G3 | +0.25% | −0.080% |
| | | G3 → G4 | +0.071% | −0.022% |

- *On long drought uniform is on the square law from 108 nodes.* Each part falls
  4.1–4.2-fold from 108 → 215 to 215 → 429, and `J`'s ratio is 4.3. The ratios off
  the law that the spot-check read came from the 54-node rung. Its spacing, 0.75,
  is longer than the stretches between gaps in creation, and its error has the
  other sign.
- *The companion on 215 nodes is honest for `J` there.* It puts the 108-node
  error at 4/3 of the move, 0.59%, against 0.58%. On wet it gives 0.44%,
  against 0.50%.
- *Grading cuts both parts, and loses their cancellation.* At a matched count the
  graded grid's field part is half the uniform one's and its quadrature part a
  fifth. Its net move is larger, though, and so is its error at a matched cost:
  −0.85% for 1.25e6 member steps against −0.58% for 9.62e5 on long drought, and
  −0.71% against −0.50% on wet.
- *On wet the graded ladder reaches the square law only past 494 nodes.* Its
  ratio is 2.75 from G1 and 3.59 from G2, where both parts fall 3.6-fold;
  uniform's is 2.6 from 108.
- *Most of the field part is born before 1,* on both grids: +0.75% of G1 → G2's
  +0.96% on long drought, and +1.82% of uniform 108 → 215's +1.97%.
- *The first-mover layer is not set by the final heights.* The reply puts its
  width at `0.02/|∂x_T/∂b|`, the reproduction switch's width over the slope of the
  final height profile. On long drought's G1 every member born before 3.1 ends at
  `x` of 1.07–1.08, so that is 7–14. Its net reproduction ratio e-folds every
  0.43–0.9 (937 at birth 0, 6.2 at 3.07), while its mortality integral rises only
  from 12.9 to 14.0.
- *By band the quadrature part is not meaningful.* Its pieces before 1 and from 1
  to 3 converge at about first order with opposite signs (+0.61% → +0.33% and
  −0.71% → −0.33% on long drought), because a band's edge cuts panels; their
  total falls 4.3-fold.

**The gradients on long drought,** with every gradient on the three graded grids
and uniform 429, beside the spot-check's 108 and 215. The reference is the graded
ladder's extrapolation from G2 and G3, which is on the square law (below). Errors
are in units of each quantity's ε.

| grid | member steps | resident: median error | over ε/3 | invader: median error | over ε/3 |
|---|---|---|---|---|---|
| uniform 108 | 9.62e5 | 0.27 | 16 of 49 | 0.088 | 9 of 49 |
| uniform 215 | 1.97e6 | 0.028 | 1 | 0.25 | 11 |
| uniform 429 | 4.07e6 | 0.014 | 1 | 0.10 | 0 |
| graded G1, 125 | 1.25e6 | 0.14 | 8 | 0.15 | 3 |
| graded G2, 248 | 2.56e6 | 0.029 | 1 | 0.040 | 1 |
| graded G3, 494 | 5.26e6 | 0.007 | 1 | 0.010 | 0 |

The one quantity over ε throughout is the resident's `a_st3`, whose ε is 6e-5:
29ε at 108 and 125 nodes, 1.4ε at 429 and 494.

- *On the graded ladder every quantity is on the square law,* the invader's too.
  Where the move from G2 to G3 is at least three times the tolerance nudge:
  - the resident's 7 such have a median ratio of 3.9–5.0 by group, none below
    zero;
  - the invader's 39 have a median of 3.9 (main traits) and 4.0 (the rest), one
    below zero. Its `lma` goes −27.0737, −27.0481, −27.0415;
  - the 125-node grid's companion, 4/3 of its move to 248, estimates its error to
    1.09 times for the resident and 1.01 times for the invader (medians).
- *On uniform nodes the resident is on it, and the invader is not.*
  - The resident's 7 resolved quantities have a median ratio of 4.5, none below
    zero. The 215-node companion estimates the 108-node error to 1.18 times.
  - On 33 of the invader's 44 the move from 215 to 429 reverses the move from 108
    to 215. Its `lma` goes −27.069, −26.973, −27.004, and `stem_P50` 26.734,
    26.686, 26.711.
  - Its median error is 0.088ε at 108 nodes, 0.25ε at 215 and 0.10ε at 429. So
    the companion overstates it 2.27-fold, and 108 nodes is close by chance.
- *At a matched cost grading wins on the invader from about 250 nodes:* 0.040ε
  against uniform 215's 0.25ε, and 0.010ε against 429's 0.10ε. For the resident
  it halves uniform's error at about 108 nodes and is level from about 250. For
  `J` uniform is ahead (above).

## What sets the node error on long drought

Long drought at `3e-5`, on the ladders above and three more from
`graded_times.R`, each nested in the next:
- G0, every other node of G1 with the gap's edges kept;
- D, uniform's spacing halved before the first gap (0.185, then 0.093), and 108
  and 215 uniform after it;
- De, D with the gap's edges and nothing inside the gap; Gn, graded without them
  and with 108 uniform's node inside it. A restart lost De2's and Gn2's invader
  phases; their stands are complete.

The scripts are `node_parts.R`'s `panel_moves()` and `elasticity_moves()`,
`harness/layer_heights.R`, `harness/invader_nodes.R` and the later sections of
`harness/error_structure.R`, which print every number below.

**J's move, panel by panel.** Each coarser panel holds one node of the finer
rung, so the move splits exactly into a field part at each coarser node, the
change in its establishment weight, and an interpolation part in each panel. The
establishment part is under 1e-4 of `J` on every ladder. In percent of `J`:

| move | field part | of it born before 0.5 | interpolation part | of it born before 0.5 | the first two nodes' field part, of their own |
|---|---|---|---|---|---|
| uniform 108 → 215 | +1.97 | +1.63 | −1.53 | −0.56 | 2.8, 2.3 |
| uniform 215 → 429 | +0.47 | +0.35 | −0.37 | −0.04 | 0.63, 0.65 |
| D 118 → 235 | +1.05 | +0.66 | −0.47 | −0.04 | 1.2, 1.2 |
| graded 125 → 248 | +0.96 | +0.50 | −0.32 | −0.01 | 0.85, 0.85 |
| graded 248 → 494 | +0.23 | +0.12 | −0.07 | −0.00 | 0.19, 0.19 |

- *The two parts have opposite signs on every ladder.* Net reproduction falls by
  e every `L`, so its interpolant lies above it, and a coarser rung's `J` is that
  much high. The field part is mostly the coarser hats' over-counted water use,
  which lowers their members' net reproduction: soil +2.14% of `J` against
  light −0.17% on 108 → 215 (`field-adjoint-map.md`).
- *On uniform nodes the field part is the top's.* The first two nodes' net
  reproduction is 2.8% and 2.3% low at 108 nodes, and 0.1–0.7% for births after
  1. On graded nodes it is 0.7–1.1% low for every member born before 3.5.
- *At the top, the field part falls 4.5-fold per halving on both ladders,* from
  2.8% to 0.63% on uniform and from 0.85% to 0.19% on graded.

**The gap's edges do not matter.** At the first rung, adding them to D or taking
them out of graded moves no quantity outside the small four by more than 0.05ε
(median 0.002–0.018ε), against errors of median 0.12–0.17ε. The resident's De
and Gn ladders converge as D's and graded's do: ratio 3.8 and 3.8, companion 0.98
and 0.99. What graded grids change is their opening.

**The crowns at the layer's top.** TF24's crowns are sharp: at `η = 12` half a
crown's leaf area is in its top 10%. Where neighbouring nodes differ in height by
more than that top layer, `h/η`, the canopy they build is a comb of separate
crowns. The largest ratio of the gap to `h/η` among neighbours born before 0.5,
from G1's heights interpolated at each grid's nodes:

| grid | t = 0.5 | 1 | 2 | 3 | 5 | 12 | t = 5, born before 3.5 |
|---|---|---|---|---|---|---|---|
| uniform 108 | 4.76 | 4.14 | 2.84 | 1.98 | 1.37 | 0.79 | 3.26 |
| uniform 215, D1 | 2.75 | 2.37 | 1.58 | 1.07 | 0.75 | 0.46 | 1.78 |
| uniform 429, D2 | 1.48 | 1.31 | 0.87 | 0.58 | 0.41 | 0.27 | 1.05 |
| graded G0 | 1.85 | 1.59 | 1.04 | 0.70 | 0.49 | 0.30 | 4.62 |
| graded G1 | 1.15 | 0.99 | 0.65 | 0.43 | 0.30 | 0.20 | 3.31 |
| graded G2 | 0.60 | 0.56 | 0.37 | 0.25 | 0.17 | 0.11 | 1.92 |
| graded G3 | 0.31 | 0.29 | 0.19 | 0.13 | 0.09 | 0.06 | 1.04 |

- *Every pair whose invader converges on the square law starts from a ratio of at
  most 1.15 at the top in the first half year:* G1 → G2 and G2 → G3. Every pair
  that does not starts from 1.85 or more: uniform 108 → 215 and 215 → 429, D, and
  G0 → G1, whose companion reports 0.75 of the invader's error.
- *Through the rest of the layer the graded grids are combed too,* to 3.3 at
  t = 5 on G1, and their invader converges anyway. The top carries the weight:
  56% of `J` is born before 0.5 on G1.
- *The ratio is set by `η`, a trait, and by how fast the first cohorts' heights
  part,* which is where the rainfall enters. Whether G1's opening of 0.03 serves
  other records is not measured.

**Where the invader's `lma` elasticity moves,** from `invader_nodes.R`'s central
differences over ±1e-6 in `ln lma`, which agree with the sweep's to 0.004–0.007
on every rung. In units of the elasticity, whose ε is 0.20:

| move | net (the sweep's) | field part | of it born before 0.5 | interpolation part | of it born before 0.5 |
|---|---|---|---|---|---|
| uniform 108 → 215 | +0.100 (+0.097) | +0.380 | +0.301 | −0.281 | −0.287 |
| uniform 215 → 429 | −0.031 (−0.032) | +0.035 | +0.034 | −0.066 | −0.061 |
| graded 125 → 248 | +0.027 (+0.026) | +0.034 | +0.036 | −0.007 | −0.007 |

- *On uniform nodes the invader's move is the difference of two errors at the
  top,* each about 1.5ε at 108 nodes and of opposite sign: its light under the
  coarser canopy, and its net reproduction's profile across the first panels.
- *The two shrink at different rates, so their difference changes sign.* From
  108 → 215 to 215 → 429 the field part falls 11-fold, as the comb at the top
  resolves, and the interpolation part 4.2-fold, on the square law. In `lma` the
  net goes +0.10 then −0.03, the reversal seen on 33 of the invader's 44 resolved
  quantities.
- *The graded opening shrinks them 8- and 40-fold,* and what is left falls on
  the square law.
- *Crown sharpness sets the top's field error* (`harness/crown_eta.R`, forward,
  uniform 108 → 215): the first node's net reproduction is 2.1%, 2.8% and 4.7% low
  at `η` = 6, 12 and 24, and the whole field part is +1.77%, +1.97% and +2.20% of
  `J`.
- *The channels differ by role* (`field-adjoint-map.md`). `J`'s field part is
  the soil's, the coarser hats' water use. The invader's is light's, +0.45 of
  its +0.38 on 108 → 215, since it neither shades nor drinks.

**Each answer with its coarser rung as companion,** in ε, over the 45 quantities
outside the small four. The estimate is a third of the move from the companion;
the extrapolation adds it to the answer.

| answer, companion | member steps of both | resident: max, median error | estimate over error | invader: max, median error | estimate over error | invader extrapolated: median |
|---|---|---|---|---|---|---|
| G1, G0 | 1.89e6 | 0.64, 0.12 | 0.59 | 0.34, 0.15 | 0.75 | 0.041 |
| G2, G1 | 3.81e6 | 0.18, 0.028 | 1.19 | 0.085, 0.039 | 1.03 | 0.006 |
| uniform 215, 108 | 2.93e6 | 0.14, 0.028 | 2.44 | 0.37, 0.21 | 0.41 | 0.29 |
| uniform 429, 215 | 6.04e6 | 0.035, 0.013 | 0.52 | 0.20, 0.090 | 0.33 | 0.052 |
| D2, D1 | 3.45e6 | 0.12, 0.030 | 1.08 | 0.17, 0.066 | 0.24 | 0.065 |

- *Every grid from 108 nodes is within ε on every quantity outside the small
  four;* the worst is 0.73ε, the resident's `rooting_depth_max` on uniform 108.
  What the coarse grids lack is an honest estimate, not accuracy.
- *Only graded rungs from G1 up report the invader's error:* 1.03 times it at G2.
  Uniform's and D's companions report a quarter to two fifths of it, so a run
  that trusted them would stop short.
- *Extrapolating along the graded ladder pays:* the invader's median error falls
  from 0.039ε at G2 to 0.006ε, for G1's and G2's 3.81e6 member steps, against
  G3's 0.010ε for 5.26e6. On uniform it does not: 0.21ε becomes 0.29ε.

## Not run

- *Experiment 2,* the panel estimate from the sweep, needs the sweep's adjoints of
  the field intermediates, which plant's sweep does not expose.
- *Experiment 5.* A node puts no leaf area above its own top (`Q(h, h) = 0`), so
  `A(x_j; x_j)` is zero. But TF24's default shading reads the leaf-area-weighted
  openness over the crown, `[0, h]`, which includes the node's own leaf area. A
  run with and without that self-term needs a change in plant.
