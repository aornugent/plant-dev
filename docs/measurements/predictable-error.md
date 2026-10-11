# Why the node error was not predictable on episodic

On episodic the node error did not fall four-fold per halving, so a run and its
bisection could not estimate it:
- Rule v2's nested ladder (pA → pA2 → pA4) fell about two-fold per halving
  (ln J move ratio 2.11; resident elasticities' median 1.63).
- The uniform ladder (u108 → u215 → u429) gave moves that grew as nodes were
  added (effective order −0.38).

The cause is two features of the birth-date axis that the runs left unresolved.
Neither is in J's own integrand: both act through the water that the cohorts
earning J see after t ≈ 10.

1. **Late births spaced too widely.** Rule v2 spaced births after b = 16 by 270–540
   days, because they earn no J. Neighbouring cohorts' net reproduction differed
   by factors of up to e^7.6 on pA, so a straight line between nodes could not
   follow them.
2. **Corners in fate at creation-window edges.** At 82% of openings, the slope of
   log net reproduction across birth date falls (a peak), and at 83% of shuttings
   it rises (a trough). The median jump in slope is 1.3 per year, more than the
   typical slope inside a window (1.1).
   - Cohorts born while establishment is shut carry no count, but each one born
     later in the gap waits out less of the drought.
   - After the opening, each later arrival is more shaded.
   - An interval that straddles an edge interpolates its counted cohorts' fate
     from a node in the closed gap. The error is set by where the edge falls in
     the interval, not by the spacing.
   - Openings and shuttings give errors of opposite sign, which mostly cancel.

With both resolved, the nested ladder falls by the square law, and the
bisection's move estimates the error to the expected factor.

## The evidence

All on episodic, setting `nr`, lib_109, both roles' gradients. Errors are in ε,
against u429 + (u857 − u429)/3, with `recruitment_decay` excluded.

**Where the uniform ladder leaves the square law.** The drop maps on u108, u215
and u429 split each coarsening's field part by birth date and time band
(`bins.R`):
- Bands before t = 10 fall at 3.75–4.15 per halving (u215/u429).
- The bands after t = 10 fall at 0.53–0.59: u215's move is about half of
  u429's.
- The late move comes from births at b = 4–16. Its largest terms are dropped
  nodes beside an interval with almost no establishment, positive at openings
  and negative at shuttings.

**Where the placed ladder leaves it.** Region by region, a pA region's move should
be 4× the sum of its pA2 moves (`region.R`, maps on pA and pA2):
- Births before b = 16: ratios 3.4–5.8 for the field part and for J's own part.
- Births after b = 16, spaced 540 then 270 days: ratio 1.07, with signs flipping
  region by region. They carry 80% of pA2's field move.

**Refining the late births** (pAL, pA2L, pA4L: pA's nodes before b = 16 plus one
every 34 days after, then nested bisections; `score_L.R`):
- Errors per level: 0.55/0.11/0.13 (placed 0.89/0.31/0.14).
- Median move: 0.016, then 0.019.
- A floor remained that no longer shrank with nodes.

**The floor is not the tolerance** (`nudge.R`). Moving `tol` by ±5% moves a
median quantity by 0.001ε and at most 0.03ε, 15–20× less than the floor.

**The floor is the edges** (`region2.R`, maps on pA2L and pA4L):
- Interior regions fall by the square law: field 4.21, own 3.37.
- Regions straddling an edge give +0.0044, then −0.00003, with terms changing
  sign.
- `inside.R` shows one: the gap 12.500–12.806, where net reproduction rises
  1.57 → 3.01 across the closed gap and peaks at 3.21 three days after the
  opening.

**Edges as nodes** (pALe, pA2Le, pA4Le: pAL plus a node at each of the 84 edges
where pA4L's creation rate crosses 0.01, then nested bisections; `score_E.R`,
registered in `prereg.md`):

| ladder | nodes | errors per level | resident move ratio | invader move ratio | ln J ratio | (Q1 − Q2)/3 over Q2 − Q4 |
|---|---|---|---|---|---|---|
| placed | 135/269/537 | 0.89/0.31/0.14 | 1.63 (12% negative) | 2.11 | 2.11 | 0.69 |
| late refined | 370/739/1477 | 0.55/0.11/0.13 | 0.22 (42% negative) | 0.08 | 0.22 | −0.06 |
| **late refined + edges** | 451/901/1801 | 0.73/0.18/0.08 | **4.03** (IQR 3.90–4.30, 0% negative) | **3.94** (IQR 3.91–4.08) | **4.19** | **1.32** |

On the square law, Q2 − Q4 is 3/4 of Q2's error, so an honest (Q1 − Q2)/3 reads
4/3 = 1.33 of it. The edge-aligned ladder reads 1.32 (IQR 1.27–1.40, same sign
on 99% of quantities).

pAL looked more accurate than pALe (0.55 against 0.73), because errors
at edges of opposite sign cancelled there. That cancellation is unpredictable,
not accurate.

## What it means for schedules

- **A node at every window edge** makes the error predictable. Its positions come
  from the run's own creation record, which is the same quadrature practice as
  placing break points at a known corner.
- **Births that set the water need nodes,** whether or not they earn J. Spacing
  after b = 16 must stay near the creation windows' scale (tens of days on
  episodic), not R-weighted.
- **Interior intervals follow the square law,** so once edges are nodes and late
  births are resolved, a run and its bisection estimate the error honestly.
  That is the precondition the per-interval estimate (W7, W8) was missing.
- **Unmeasured:** the edge-aligned ladder's cost against a cheaper base, the
  other records, and the field-adjoint map's ranking on an edge-aligned grid.

## Files

`predictable-error/`:
- Scripts: `bins.R`, `edge.R`, `placed.R`, `region.R`, `region2.R`, `mort.R`,
  `sliver.R`, `corner.R`, `inside.R`, `score_L.R`, `score_E.R`, `nudge.R`, and
  `map_lib.R` (the drop map's readers).
- Schedules: the six ladder schedules as `.rds`.
- `prereg.md`: both registrations.

The scripts ran from the session's scratch directory `schedtest/order/`, beside
`schedtest/{adjmap,placed2,placement}` and the node_rule ladder runs. The maps
come from the `adjmap-probe` build (`field-adjoint-map.md`).
