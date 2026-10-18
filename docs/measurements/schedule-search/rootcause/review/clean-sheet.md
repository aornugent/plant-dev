# Clean sheet: TF24 node schedules (code-review Step 2, Tier 3)

Written from the requirement (R1–R5) and these notes only: `rootcause/{closing,h5,founders,
p50,dwr,single,refine,heldout,moved,proxies,u,loop}/notes.md`, `docs/dynamics.md`,
`docs/measurements/eps-spread.md`. I have not read the design under review. A note name in
brackets cites the fact a sentence uses. No runs were made; every cost below is inferred
from measured layouts.

## The decision everything follows from

**A run is checked against itself.** The schedule is built so that removing every other
node of each stretch leaves a valid coarser schedule, its *parent*. The error estimate is
the parent replayed on the run's own steps, subtracted from the run, and divided by 3.

What follows:
- **No second schedule.** No law has to hold across two builds (R2). A pinned replay uses
  the run's accepted steps, so the estimate carries no step jitter. That jitter is 0.024ε
  rms and 0.09 along M at 1e-4, and E6's pair multiplies it by 2.3 [proxies, refine]. Pinned
  removal replays reproduce measured region errors with cos 0.93–0.98 and slope about 1
  [dwr, single].
- **Breakpoints are nodes at every level.** A removal that crosses an edge measures
  something else: omitting an edge node reads 2–15× the measured error [dwr].
- **Every stretch holds an even number of intervals.** Otherwise part of the stretch is in
  no check. In earlier layouts, stretches whose count did not change between runs carried
  68–100% of the shortfall in order [h5, u].
- **The check sees only what moves.** Anything held fixed must be small by measurement, and
  the report states it as a bound.

## Parts (about 130 lines of R; parts 1–3 need no C++ change)

1. `nested_schedule(pilot, s)`, about 50 lines.
   - Fixed nodes: b = 0, every opening edge o, every closing edge c, and c − 12 d.
   - Each stretch that holds establishment ([0, c₁ − 12 d] and each [o, c − 12 d]) gets
     2·⌈m/2⌉ intervals, equal in the pilot-weighted measure a09 already uses; m is the
     stretch's measure at scale s.
   - No stretch interval is wider than 80 d, so the parent's stay within 160 d. That is the
     widest spacing at which the square law was measured to hold; it fails at 198–224 d
     [h5 W].
   - A stretch no wider than 12 d keeps one interval, like the strip.
   - Gaps (no establishment) are one interval each and are never split.
   - Fronts become breakpoints on any rebuild. A front is a pair of neighbouring nodes whose
     sign-change counts differ [dynamics].
2. `removal_error(run)`, about 25 lines.
   - One pinned gradient replay of the parent, through the existing pin path. The parent is
     the run with every other non-fixed node removed, on the run's step times.
   - Estimate per quantity: e_q = (Q_parent − Q_run)/3.
   - Two parts the replay cannot see are reported as stated bounds:
     - the fixed 12-d strips' own error: under ε/10 (rms 0.015–0.036, max 0.059–0.069 on
       dry, episodic-lma and dry-flat) [h5];
     - the step error at tol 1e-4: at most about 0.03ε rms against 3e-5 [refine].
3. `run_to_target(case)`, about 30 lines.
   - Pass 1 runs at E6's committed background density, measured in a09's units rather than
     in days.
   - Stop when every |e_q| ≤ 0.85·ε_q. The 0.15 covers the stated bounds and the spread of
     the estimate itself.
   - Otherwise rebuild at s·(0.85·ε/max|e|)^½ and check again. The rebuilt run carries its
     own check, so a wrong guess of the scale costs rows, never honesty.
   - At most 3 passes. At the cap, return the finest run with its estimate and a flag.
4. Location, about 25 lines plus the existing node-drop map patch.
   - The map runs on the answer run and costs 5–8% of a sweep.
   - It splits ln J's error by stretch, exact to 0.03ε at E6's spacing [loop].
   - It ranks stretches by the size of the elasticities' error: the |ln J| profile has
     cos 0.94 with the elasticities' rms profile, but it gives no signs [dwr].
   - The report also names the fixed bounds and any stretch that holds a front.
   - A signed split by region for each quantity costs one pinned removal replay per region
     (regions add to within 0.002ε [single]). It runs only on request.

New names: `nested_schedule`, `removal_error`, `run_to_target`.

## How it estimates error

The estimate is one move, with order 2 assumed for the smooth stretches. The data back that
assumption where the parent's intervals stay under about 160 d: the founders run at order
1.8–2.0 [founders], and the spell interiors at a ratio of 4.77 per halving with cos 0.96
[p50].

The error near closing edges is not order 2. It is kept out of the moving part by the
fixed node at c − 12 d (see decision 3). The estimate is per quantity and has no step noise.
What it cannot see is listed by name with its measured bound.

## How it places and refines nodes

Placement uses one scale over the pilot's measure: nodes at the breakpoints, and equal
measure in between. Refinement is a rebuild at a predicted scale, not an allocation by
region. Choosing where to spend rows region by region saved at most 4% of rows, and lost
22–24% once its extra run was paid [proxies C]. Ranking regions by ln J misplaced the
elasticities' error: Route B passed 13 of 18 cases [loop], and the refine tool reached the
founders last [refine].

## Spell edges and near extinction

**Opening edge: a node at o.** Fate has a corner at o: its slope changes sign there, on all
22 edges measured. The gate opens at once, and the hydraulic sensitivity has no turn there
[h5 O1].

**Closing edge: nodes at c and at c − 12 d.**
- Fate is smooth and convex through c, and the gate closes over 1–2 d, which the exact
  counts carry.
- The hydraulic sensitivity turns 9–12 d before c, over a width of 5–10 d [closing].
- An interval that spans that turn errs as δ(h − δ), close to first order. The fixed node
  puts the turn inside a 12-d strip whose own error is under ε/10.
- The node at c keeps the strip off the gap's chord. Read on that chord, the strip's error
  is set by the gap's length and does not shrink [closing, h5].

**Short spells** get a midpoint, so they are in the check.

**Near extinction.**
- Nothing has thrown in any measured run, including near extinction and invaders at ×0.5
  and ×2 lma, with HMAX 15 [heldout, moved, h5].
- A pinned replay reuses steps that were already accepted, so it cannot be refused.
- E6's pair misreads dry-lma125 (cos 0.43) because its two schedules are off a common law
  [heldout]. A removal check has no second schedule.
- The late stretches there have no clean order: their moves alternate in sign [refine].
  This is the first case to test.

## Any simulation length

Everything comes from the pilot's breakpoints and measure. The founders are simply the first
stretch, before the first closing edge. There are no era cutoffs (10, 17, 25), and late
edges are kept; their nodes live for few steps, so they are cheap in rows. The constants in
days are the strip width, 12 d (the seedling's reserve-depletion time), and the 160-d law
range. Neither depends on how long the simulation runs.

## Cost per pass against E6 (inferred)

| | E6 | clean sheet |
|---|---|---|
| answer run | c | S ≈ 1.1–1.4 c |
| check | separate run, 1.55 c | pinned parent replay, ≈ 0.8–0.9 S, plus the map, ≈ 0.05 S |
| per pass | 2.55 c | ≈ 1.9 S ≈ 2.0–2.7 c |
| T = find + 2 × answer | 4.55 c | ≈ 3.9 S (equal to E6 at S ≈ 1.17 c) |
| step noise in the estimate | jitter × 2.3 | none |

Why S lands at 1.1–1.4 c:
- Edge nodes cost rows. Measured layouts with edge nodes cost 1.11× (U, edges before b = 10
  only), 1.37× (o, c − 12 d and c before 25) and 1.54× (rule N) E6 committed's rows at s = 1
  [h5, u, loop].
- E6's committed run sits at a median 0.37–0.46 of ε [heldout], so a run that only has to
  meet ε can use a background about 1.25–1.4× coarser.

On rows it matches E6 to within about ±20%: cheaper on records like dry, dearer where edges
are many (dry-flat). What it buys is an estimate with no step noise and no law shared
between two schedules.

## The decisions a design here must get right

1. **The check: a pinned replay of the run's own parent, not a second schedule.**
   - Simplest alternative: a finer run built separately (E6's 1.55× check), or a coarse
     companion run at 1.6×.
   - Rejected because:
     - both need two builds on one law, which R2 forbids;
     - both carry the step jitter, multiplied by 0.9–2.3;
     - E6's pair reads S1 with cos 0.33–0.54 on the dry records at ε/2 [refine], and with
       cos 0.43 near extinction [heldout];
     - the replay costs 0.8–0.9 S, against 1.55 c.
2. **One removal level at order 2, not two levels with a measured order.**
   - Simplest alternative: a second removal, then fit a·h + b·h², which gives
     e = (5·D₁ − D₂)/3 and needs no assumed order.
   - Rejected because the grandparent's intervals are 4× the run's, about 250–400 d. That is
     past the 160-d range where the law holds [h5 W], so the second move would measure
     behaviour before the law applies.
   - It also needs 4 intervals in every stretch, which is +3 nodes per short spell and ruinous
     on dry-flat.
   - The cost of this choice: order 2 must be made true by layout (decision 3), not checked
     inside one run.
3. **Closing edges get a node at c and a fixed node at c − 12 d; opening edges get a node at
   o only.**
   - Simplest alternative (a), E6's 12-d inset: one node per edge, the cheapest, and the most
     accurate per row. Rejected: its accuracy comes from errors cancelling on the turn, which
     no estimate can see (the inset ladder's x/c is 0.48–0.65 and changes sign [closing]).
     The opening strip is read on a chord across fate's corner, and its error does not shrink
     with the inset (e(6) ≈ e(12) [h5 O2]).
   - Simplest alternative (b), the edge node alone: one node per closing edge cheaper.
     Rejected: the last interval spans the turn, the order is 1.0–1.2 [closing], and D/3
     then under-reads it by up to 3×.
   - A node at o + 12 d adds 11% of rows and buys nothing [h5 V].
   - Risk: 12 d is the turn's measured position at the bank's traits. The buffer traits move
     it, and the check cannot see a turn that falls outside the strip.
4. **Even counts per stretch, with nesting inside each run, not re-gridding by ⌈∫1/(s·h)⌉.**
   - Simplest alternative: the ceiling rule at a 1.6 ratio, as E6, H5 and U use.
   - Rejected because 55–92% of stretches keep their count from one rung to the next, and a
     stretch with one interval cannot be removed, so its error is in no check [u, h5].
   - Cost: one node per short spell. Across passes nothing needs to nest, because each run
     carries its own check.
5. **One global scale, rebuilt from the measured error, not allocation by region from the
   node-drop map.**
   - Simplest live alternative: per-region scales, ranked by each region's ln J error on the
     map.
   - Rejected because:
     - allocation saves at most 4% of rows [proxies C];
     - ln J's signed split does not carry to the elasticities (median |cos| 0.58 [dwr]);
     - both map-guided tools in the record failed on that point [loop, refine].
   - The map stays for reporting only (R5).

Left out on purpose:
- Simpson weights over the founders. They bring that error down to the noise floor and save
  6–9% of rows [founders], but they need a weight rule in C++ and put a second order inside
  one run.
- A tangent carried through the forward run for per-region elasticity errors: 2.4–4.4
  gradient runs, plus generalising odelia [single].
- Any reserve for moved θ. The moved-θ growth comes from K(θ), and rebuilding the grid does
  not remove it [moved]; that belongs to the shared-grid objective, not to R1–R5.
