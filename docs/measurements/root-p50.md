# Why root_P50's certificate misreads: edges that move with the trait

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
| 4 | H1′: misplaced closings | move each closing node to the nearest closing of H's own run (median shift 0.16 day) | ladder unchanged (+1.06, −0.29, −0.18ε): rejected |
| 5 | H5: moving corner | bisect only the late intervals that touch an edge, or only those that do not | see below |

## The mechanism

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

**J does not share the first-order part,** on the same schedules. A fate corner left
unresolved at the edges would show in J too. The first-order part is in the derivative
alone:
- AD differentiates the quadrature with every node held where it is.
- An edge is where a newborn's net production crosses zero, so it moves when a trait
  changes the soil water or light at which that happens.
- Fate has a corner at the edge, so the trait derivative of fate *jumps* there.
- Linear interpolation across a jump errs by about the jump times the spacing beside
  it: first order, wherever the node sits.

root_P50 sets the soil water potential at which roots lose conductance. It therefore
moves openings and closings more than most traits, and its jumps are large next to
its small ε.

## What follows

- **Edge nodes placed in the run, at the moment P₀ crosses zero.** A node born at the
  crossing time has a birth date that is a function of θ. The sweep then
  differentiates through the crossing (implicit function), and the jump never enters
  the quadrature. The same move also fixes the alignment of closings, which shift with
  the grid. This is the "causal in-run edge nodes" item of `breakpoints.md`.
- **Until then, edge collars:** spacing beside each edge that halves the first-order
  part with each halving. For dry that took about 280 extra nodes per halving.
- **The certificate.** For a quantity whose move ratio is near 2 rather than 4, the
  error is about the move itself, not a third of it. A per-quantity order read from
  three levels would catch this, at the price of a third run.
