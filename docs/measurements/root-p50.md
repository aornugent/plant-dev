# Why root_P50's certificate misreads: first-order error before closings

On the hybrid schedules of `central.md`, the central coarsening reads almost every
quantity's error within ×2. root_P50's resident elasticity is the exception:
- episodic: error +0.37ε, estimate −0.10ε;
- dry: error +0.54ε, estimate −0.37ε.

This note finds why. Its ε is 0.0108. Everything below is on dry, using central
differences (±2%) of ln J on forward runs. The scripts and the pre-registered rounds
are in `root-p50/` (`prereg.md`).

## Hypotheses tested

| round | hypothesis | test | result |
|---|---|---|---|
| 1 | H3: tolerance | H at a tenth of the tolerance | moved 0.034ε: rejected |
| 1 | H1: closings (effect side) | split the moves by the birth of the cohorts whose fate changed | births within 10 days of a closing carry +0.23ε then +0.02ε: rejected as stated |
| 1 | H2: reference | spread of the finest schedules' values | ±0.2ε: true in part, too small to explain +0.54ε |
| 2 | H4: late spacing | coarsen or bisect only late births (after the founders' window), or only founders | late births carry all of it (+1.04ε then −0.32ε, ratio −3.3); founders follow the square law (ratio 4.2); the parts add up |
| 3 | is the bisected late spacing asymptotic? | halve the late intervals again | moves −0.32ε then −0.15ε: first order |
| 4 | H1′: misplaced closings | move each closing node to the nearest closing of H's own run (median shift 0.16 day) | ladder unchanged (+1.06, −0.29, −0.18ε): rejected (its rule left the nodes on the shut side; round 6 tests that) |
| 5 | H5: moving corner | bisect only the late intervals that touch an edge, or only those that do not | first order beside edges (below) |
| 6 | H6: edge nodes on the shut side of the run's own root | move every edge node inside its open window | ladder unchanged: rejected |
| 7 | H7: a layer of days beside the edge | graded nodes before closings, or after openings | closings carry it, openings none |
| 8 | H8: the layer is wider than 8 days | extend the nodes before closings to 32 days, or refine within 8 | wider moves it, finer does not |

## Where the error is

**Round 5.** On dry, 277 of the 313 late intervals touch an edge.

| refinement | root_P50 move | ln J move |
|---|---|---|
| H → late intervals touching an edge bisected | −0.54ε | +0.398ε |
| → those halves touching the edge bisected again | −0.28ε (ratio 1.93) | +0.044ε (ratio 9.05) |
| H → late intervals touching no edge bisected | +0.24ε | +0.094ε |
| H → all late intervals bisected | −0.32ε | +0.492ε |
| → all late intervals bisected again | −0.15ε (ratio 2.1) | +0.122ε (ratio 4.05) |

**Two parts of opposite sign make up root_P50's error.**
- *Near edges:* a part that converges at first order in the spacing beside an edge.
- *Elsewhere:* a smaller part that converges by the square law.

They partly cancel, so the uniform moves look erratic. The coarsening also misjudges
them, since its estimate assumes the square law throughout.

**J does not share the first-order part** on the same schedules. Rounds 6 to 8
narrow down where it is.

**Not where the edge node sits** (round 6, `mkopen.R`, `score6.R`).
- The pilot's rule puts edge nodes on the shut side of the run's own root: for 92 of
  137 roots at +2% and 123 of 136 at −2% (`side.R`). It takes the end of the last
  step above 0.01 for a closing and the start of the first for an opening.
- Ho moves each edge node inside its window: 0.5 d before a closing's root step,
  0.1 d after an opening's, against both ±2% runs. 122 of 123 stay inside on Ho's own
  runs.
- The ladder barely changes: Ho → Hoea → Hoea2 moves −0.461ε then −0.249ε (ratio
  1.85).

The run's record finds each root to within its step (median 0.17–0.27 d). Over 4% of
root_P50, closings move by 0.18 d (median; 90% within 0.49 d) and openings by 0.014 d
(`travel.R`).

**In births before closings** (rounds 7 and 8, `mkcollar.R`, `mkcollar2.R`,
`score7.R`). Moves from Ho:

| schedule | added nodes | root_P50 | ln J |
|---|---|---|---|
| Hoea: edge-touching late intervals bisected | 244 | −0.461ε | +0.383ε |
| Hoea2: those halves bisected again | 489 | −0.710ε | +0.424ε |
| Hoc: 0.25–8 d before each closing, graded | 293 | −0.420ε | +0.078ε |
| Hoo: 0.1–8 d after each opening, graded | 484 | −0.023ε | +0.018ε |
| Hocw: Hoc plus 12, 16, 24, 32 d | 454 | −0.692ε | +0.195ε |
| Hocd: Hoc refined within 8 d | 592 | −0.415ε | +0.078ε |

Ho's ladder extrapolated at first order puts the limit at −0.922ε from Ho.

- Openings carry none of it.
- Births up to 32 d before closings carry three quarters of it.
- Finer nodes within 8 d add nothing.
- The other quarter is not yet located.

**Fate is smooth there** (`profile.R`). On Hocw's ±2% runs, over the 60 d before
three closings:
- fate (net reproduction) is smooth in birth date;
- so are its root_P50 derivative and cumulative mortality;
- the count established there is small (0–0.05 per node).

So these births most likely act through the stand's environment, the soil they draw
down. The earlier coarsenings also found the field part, through soil, converging at
ratios of 1.7–2.5 (`estimate-shortfall.md`).

## What follows

- **Edge nodes need not be placed in the run.** Where an edge node sits does not carry
  the error. The previous run's record finds each root to within a fraction of a day,
  which is enough for the schedule to place them.
- **A schedule rule works today:** graded nodes over the weeks before each closing of
  the previous run, at about the cost of bisecting the edge-touching intervals.
- **Next root-cause step:** split those births' move into its own part and its field
  part (soil, light) with the field-adjoint map. Then find why the field part converges
  at first order there.
- **The certificate.** For a quantity whose move ratio is near 2 rather than 4, the
  error is about the move itself, not a third of it. A per-quantity order read from
  three levels would catch this, at the price of a third run.
