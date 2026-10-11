# Breakpoints in fate across the bank, and finding them cheaply

`predictable-error.md` found two causes of unpredictable node error on episodic:
- corners in fate at creation-window edges;
- births that set the water, spaced too widely.

This round checks both across the records, asks how cheaply the edges can be
found, and resolves the constant record. Settings and reference are as in
`predictable-error.md`, plus:
- dry and long-wet: `nr`, reference u215 + (u429 − u215)/3;
- long drought: `pf`, reference pf ld_D u215 + (u429 − u215)/3.

Errors are in ε, with `recruitment_decay` excluded.

## Fate is smooth between breakpoints of two kinds

**Corners at creation-window edges.** Fate peaks just after an opening and dips
at a shutting. Every record has them: 84–154 edges over 40 years.

**Steep fronts in fate not tied to the gate.** On constant rain, establishment
never shuts (rate 0.998 throughout).
- Cumulative mortality to the run's end rises from 0.46 to 3.9 across births
  from day 23.531 to 23.563, and reaches 35 by day 23.63 (`e_cfront_scan`,
  nodes every 1/2048 day).
- At that spacing the rise is smooth, but survival falls from 0.63 to 0.02
  within 0.032 days.
- Net reproduction moves only 20% across it, so these cohorts reproduce first
  and die later.

## Edges as nodes give the square law on every record

Nested ladders on a uniform base, with the base run's own creation edges added
as nodes (`mk.R`, `mk2.R`). The `g` ladders also drop base nodes born while the
gate is shut. Ratios are of successive moves; the honest value of the last
column is 4/3.

| record | ladder | rows (k) | max err per level | resident | invader | ln J | (Q1 − Q2)/3 over Q2 − Q4 |
|---|---|---|---|---|---|---|---|
| episodic | uniform 108/215/429 | 230/497/1112 | 0.98/0.58/0.21 | 0.78 | 0.09 | 0.77 | 0.21 |
| episodic | u108 + edges | 431/953/2128 | 1.59/0.41/0.14 | 2.59 | 3.89 | 3.79 | 1.26 |
| episodic | **u54 + edges, no gap nodes** | **273/594/1319** | 4.98/1.16/0.26 | **3.80** | **3.99** | **3.92** | **1.30** |
| dry | uniform | 327/699/1510 | 1.66/0.43/0.11 | 3.20 | 3.95 | 6.00 | 1.30 |
| dry | u108 + edges, no gap nodes | 738/1592/3471 | 1.98/0.46/0.19 | 3.78 | 4.02 | 3.85 | 1.32 |
| long-wet | uniform | 390/814/1717 | 3.31/0.89/0.22 | 3.95 | 3.78 | 4.68 | 1.27 |
| long-wet | u108 + edges, no gap nodes | 910/1921/4107 | 3.33/0.90/0.23 | 3.78 | 3.68 | 4.71 | 1.23 |
| long drought | uniform | 637/1311/2714 | 2.73/0.71/0.18 | 3.31 | 3.99 | 3.35 | 1.30 |
| long drought | u108 + edges, no gap nodes | 1507/3129/6552 | 2.77/0.73/0.24 | 4.06 | 3.83 | 4.22 | 1.28 |

- Dropping the base nodes born while the gate is shut changes J by 2e-6
  relative and saves 12% of rows (episodic u108 + edges: 379k against 431k).
  Those nodes carry no count.
- Edges buy predictability, not accuracy: errors per level are about the same as
  uniform's. On top of a 108-node base they cost 2.3–2.4× the rows. On a 54-node
  base (episodic) they cost about what uniform does.

**Why uniform looks predictable on some records and not others** (`share.R`,
drop maps on u215). Edge panels carry an absolute move of 0.010–0.027 in ln J
on every record. Their signs differ by edge type, and their residue is erratic:

| record | edge, signed | edge, absolute | interior, signed |
|---|---|---|---|
| episodic | +0.0069 | 0.0266 | −0.0098 |
| dry | −0.0045 | 0.0237 | +0.0018 |
| long-wet | −0.0041 | 0.0102 | +0.0127 |

Where the interior's systematic move dominates the edges' residue (long-wet,
long drought), uniform ladders look clean. Where it doesn't (episodic, whose
uniform error is 5–7× smaller; dry's ln J), they don't. Edge nodes remove the
residue whichever way the balance falls.

**The edge error is concentrated** (`conc.R`). 4–6 edges carry half of it, and
15–20 of 54–65 carry 90%. Only 0–2 panels per record exceed ε/10 in ln J, all
born at b = 7–13.

## The front needs nodes at its own scale (constant)

| ladder | rows (k) | max err against Gbf16 + Gbf32 | resident | invader | (Q1 − Q2)/3 over Q2 − Q4 |
|---|---|---|---|---|---|
| pA → pA2 → pA4 (front at 0.06 d) | 147/368/957 | 6.1/16.6/13.7 | −1.65 | −3.62 | −1.20 |
| Gbf8 → Gbf16 → Gbf32 (front at 1/8–1/32 d) | 113/179/317 | 6.9/0.72/0.18 | 1.73 | 11.5 | 3.84 |
| **cF → cF2 → cF4 (pA + nodes every 1/512 d over days 23.50–23.62)** | 247/624/1651 | 10.6/12.8/13.3 | **3.67** | **4.45** | **1.48** |

- The front-resolved ladder converges by the square law. It reaches a limit
  about 13ε (in the invader's elasticities) from the Gbf reference, where the
  pA ladder also heads (pA4 13.7, cF4 13.3).
- The Gbf reference is biased:
  - its front spacing (0.031 d at the finest) is coarser than the front;
  - its successive-move ratio of 11.5 is not the square law;
  - Gbf16 and Gbf32 are identical outside days 20–26, so their extrapolation
    never measures the rest of the run.
- The constant record's reference should be rebuilt on the cF ladder.

## Finding the edges cheaply

**A stand run's own creation record finds them** (`match.R`, against the finest
run's edges):

| first pass | openings within a day | shuttings within a day / 3 days |
|---|---|---|
| uniform 108 (episodic, dry, long-wet) | 98–100% (median 0.01 d) | 75–89% / 93–97% |
| 27 nodes | 93–99%, but whole edges missed (up to 250 d away) | 27–47% / 64–83% |

**Rain and soil without plants cannot** (test 3, `schedtest/probe`):
- Openings follow a rain onset by 0.2–0.7 days on every record, so the rain
  record proposes every opening. But whether a rain opens the gate depends on
  the stand's soil: the best rain-only rule finds about 90% within a day, with
  one false alarm per 1.5–3 true openings.
- The soil chain without uptake does worse.
- Every missed opening leaves an edge unaligned and its error erratic.

**The run can find them itself.** A gate edge at birth date b happens at time
t = b in the forward run. So a run can introduce a node at each gate crossing
as it happens, by the same root-finding the split uses for sign changes.
Neither a first pass nor a probe is needed for edges. Fronts like constant's
are not causal at birth, and need a pass.

## A diagnostic that localises what needs resolution

- **Edges:** from the run's creation record. Each edge should be a node.
- **Unresolved spans:** from the drop maps of two consecutive passes, region by
  region. A region whose coarsening move does not fall about four-fold is
  unresolved. That comparison found:
  - the late births: ratio 1.07 on pA/pA2;
  - the edges: signs flipping region to region;
  - the constant front: oscillating ratio on pA.
- **Raw steepness is not enough** (`steep.R`). The largest neighbour change in log
  net reproduction or in survival sits in the founders' first interval on every
  grid, about 2 on uniform u108, which still converges. cF and pA show the same
  maximum. Steepness matters only in proportion to an interval's weight, which is
  what the per-interval estimate supplies.
- **The per-interval estimate ranks correctly once edges are nodes** (`bisect.R`
  on episodic u108 + edges, 17 of 173 panels bisected):

  | panels chosen by | ln J moved / predicted |
  |---|---|
  | the map (own + field) | +0.002851 / +0.002851 (1.00×) |
  | own part alone | +0.001356 / +0.001286 (1.05×) |
  | at random | +0.000519 / +0.000570 (0.91×) |

  Without edge nodes the same test gave −0.95× and −0.06×.

## Open

- A cheaper edge set: the 15–20 edges that carry 90%, or edges on a coarser base
  for dry, long-wet and long drought.
- Placing edge nodes in the run, causally, in plant.
- Rebuilding the constant reference on the front-resolved ladder.
- The front-detection rule: where to refine, at what spacing, from one pass.

## Files

`breakpoints/`:
- `mk.R`, `mk2.R`: edge schedules.
- `match.R`: edge accuracy.
- `ladder.R`: scoring.
- `front.R`, `steep.R`: fronts and steepness.
- `share.R`, `conc.R`: edge share and concentration.
- `bisect.R`, `rank_lane.sh`: the ranking test.
- `lane.sh`: runs.
- The ladders' schedules as `.rds`.

The scripts ran from the session's scratch `schedtest/{edges,order,adjmap}`.
