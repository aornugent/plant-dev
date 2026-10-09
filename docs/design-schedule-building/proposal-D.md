# Proposal D: Pólya, with witnesses. One lattice of edges, halved; every schedule on it

## Triage: 3

This is public R API (`run_scm`, `control_window`, `diagnose_scm`, the Parameters that carry a schedule). It is also the birth-date coordinate's numerical representation, and several requirements arrived as mechanisms ("pilot", "window", "refine").

## Requirements ledger

R0–R10 as written in `design-schedule-building.md`. The numbers this proposal leans on:

- **R1.** Spread u108 alone errs by up to 2.73ε (long drought) and 3.31ε (long-wet). u215 alone errs by 0.71ε and 0.88ε (`ladder_ld.log`, `ladder_wet.log`). Extrapolating 108 and 215 errs by 0.17ε and 0.09ε.
- **R4.** The 54/108/215 ratio is 4.98 (6% negative) on long drought and 5.78 (9% negative) on long-wet. The 108/215/429 ratio is 3.92 and 3.78. Episodic's 108/215/429 ratio is 0.77, with a companion reporting 0.19 of the error. Its `J` moves 0.0058, then 0.0076, then 0.0016 up to u857. Graded nested halvings (B) stay at a ratio of 2.76.
- **R7.** Rows for one long-drought forward (bounded CK, soil alone, rule A): u54 0.312M, u108 0.637M, u215 1.311M, u429 2.714M. Rule A's late thinning saves 4.9 points beyond the weight alone (−27.7% against −22.8%) and moves no quantity more than 0.078ε. The weight alone moves no quantity more than 0.016ε.
- **R6.** An analysis is 60–84 evaluations on one grid.

**Scarce resource:** rows per evaluation. An analysis makes 60–84 evaluations at 1.9–5.3M rows each, and the extra rungs a build needs cost 0.4–1.5M, under 2% of the analysis. So it pays to spend at build time on anything that cuts rows per evaluation, or that makes each evaluation's estimate true.

**Challenged upward:**
- *C1 (R0, constant record).* The only witness for local refinement is a front placed by hand at 1/16 day. Its own ladder fails (ratio 1.65), and no rule that places it is measured. I propose that constant takes caller-given edges until a measured rule exists. Confirm?
- *C2 (R8).* "Every run reports its error estimate" literally needs a companion for every evaluation, which costs 1.49× the rows of the fine rung alone. If a build-time estimate is enough for walks inside the radius, an evaluation could run the fine rung alone, saving 33%. Confirm which.

## The floor

The floor keeps today's pieces and adds a loop: double a uniform count until `diagnose_scm`'s estimate is ≤ ε and its ratio is ≥ 3, with the separate pilot, full walks and no thinning. It fails in two places:
- **R1 on constant.** No uniform count converges there; the gradients stay up to 3ε off.
- **R7.** It forgoes rule A's thinning, the decided node rule worth 4.9 points.

Its estimator also breaks the moment either is added. `every_other` drops nodes by index, so a non-uniform schedule merges cells of widths h and 4h into one of 5h. That coarse cell's error is then 125/65 = 1.9× its two parts', not 4×, and dividing by 3 is wrong there.

## Candidate

**6. Pólya, with witnesses.**
- **Commitment:** every birth-date schedule an analysis runs is one list of edges with every cell halved r times. The companion is r−1. An invader's schedule is coarser edges at the same r.
- **Pays for:**
  - R4/R8: the estimate stays true on every schedule actually used.
  - R0: the stop is automatic.
  - R1 on constant: the front is expressed as edges.
  - R7: the thinning is kept, and the pilot merges into the ladder.
- **Costs:** new names `edges`, `halvings`, `introduction_times`, `build_grid`, `walk_grid`, `Interval`. It is bad at local refinement after a build: changing the edges reruns every rung.
- **Wins when:** two or more non-uniform schedules ship (the thinning plus the front, or plus the invader subset).

**The witnesses** are five cases in hand. Each reads a coarse run and writes a schedule or an estimate:

| case today | reads | writes | becomes |
|---|---|---|---|
| the pilot | its own 54 nodes (53 spacings, which nest in none of the run's) at `1e-3` | F(t) | rung r−2, unweighted |
| `diagnose_scm` | `every_other` by index | error, ratio | rungs r−1 and r−2 |
| rule A's thinning | F(b) | nodes ⌊√F⌋ apart | edges merged 2^⌊½log₂F⌋ after the window |
| the invader's shared subset | the pilot's walks' shares | a subset of the run's nodes | coarser edges (user's default stays the full walk) |
| constant's front | a hand pilot | 150 hand-placed times | the caller's edges |

**Their disagreement is a live class of bug:**
- `diagnose_scm` walks invaders on the full rung (`q$node_schedule_times <- list(t)`). A thinned walk's 0.43ε miss is therefore invisible to it.
- Index-halving breaks at every change in spacing.
- `PLANT-109`'s refusal exists because an invader's times could fall off the run's.

**Winner: this candidate.** It meets every ledger line the floor meets, at the same rows within 0.6% (below), and adds constant and the thinning.

## The commitment

A rung's introductions are `introduction_times(edges, halvings)`, and nothing else.

**Kept true by:**
- `build_grid` and `walk_grid` take edges and halvings, never times. The grid stores those two, and the times are derived from them.
- `walk_grid` takes a grid, not introductions, so an invader's times cannot be supplied by hand.
- The companion is `halvings − 1` of the same edges, so every coarse cell is exactly two fine ones. Any edges are nested at every rung, and so is any coarser list of them.

## Kill question

**Assumption:** an analysis runs more than one schedule shape. If everything is uniform with full walks, today's `every_other` already nests, and this design is the floor with one renamed estimator.

**Verdict: survives, narrowly.**
- Rule A's thinning is decided and still to build (4.9 points).
- Constant has no uniform answer (3ε).
- The shared invader subset is the user's candidate (24–25% of walk rows).

Drop the first two and the design dies to the floor.

## What survives deletion

- `build_grid` (R0: the stop chosen; R6: one grid per analysis). "Grid" is already the docs' word for introductions plus steps.
- `walk_grid` (R6; R8 per evaluation).
- `edges` (R1 on constant; R7, the 4.9 points).
- `halvings` (R4: the knob the companion moves).
- `introduction_times` (the commitment's mechanism).
- The column `extrapolated` (R1: u216 alone errs 0.71–0.88ε, the extrapolation 0.09–0.17ε).
- `Interval` with `shares` and `crowns`, and the renames of `mom` (R10).

Deleted: the pilot as a run of its own, `diagnose_scm`, `every_other`, and the word "spread".

## What this settles

- No invader is ever introduced off the stand's nodes at any rung. `PLANT-109`'s refusal becomes unreachable from `walk_grid` and stays as the C++ backstop.
- No lattice is run that the analysis does not share. The run that sets the window is a rung.
- The estimate cannot describe a different walk from the one the analysis uses.
- Every evaluation reports its error, its distance and its failures with no extra run (R8).
- On the height coordinate nothing moves. `refine_schedule()` and `run_scm(refine_schedule = TRUE)` are untouched (R9), and the `mom` rename is bit-identical.

## What this makes hard

- **Refinement after a build.** New edges rerun all three rungs (2.35M rows on long drought). A front that moves with θ inside the box forces a rebuild.
- **The pair per evaluation.** It costs 1.49× the fine rung's rows and keeps two recordings in memory (C2).
- **Episodic.** It costs 4.3× the hand pair's rows to buy an estimate that holds.
- **A cost cliff at the stop.** The threshold sits near long-wet's u216 error (0.88ε). A flip doubles the rows per evaluation (2.41M to 4.95M), while the answer moves by at most the extrapolation's error, 0.09ε < ε/3.
- **Graded edges (B).** They fail the ratio (2.76), so the loop climbs past them instead of using them.

## Kill condition

1. Episodic's 54/108/216 ratio comes out ≥ 3 by accident. The loop would then stop at the 108/216 pair, whose companion reports 0.19 of the error, and the ratio would be no guard. This is the first measurement.
2. Halving constant's edges (front and bulk together) still fails the ratio. The edges then buy constant nothing, and the thinning's 4 points alone hand the search back to the uniform-ladder floor.
3. The user keeps full walks and drops the thinning. One witness is left, and the floor wins.

## The design

### 1. The interval

The interval is a type: `Interval`, a view in `species.h` over two adjacent nodes (`lower`, `upper`). Its width is derived from their birth dates and not stored. Its establishment integrals E and M stay ODE states on `lower`, under today's names.

Its parts:
- **`shares()`**: {E − M/Δ to `lower`, M/Δ to `upper`}. This is today's `interval_shares`. A node's establishment weight is the sum of the shares that reach it, as now.
- **`crowns(visit)`**: eight midpoint crowns, each a top and a leaf area. This is today's `for_each_interval_crown`. "Crown spread" becomes "the interval's crowns".

The open interval is `Interval{nodes.back(), new_node}`. That one constructor replaces the five places that form (node, next, width) by hand: two closed, three open. `boundary_weight()` becomes `open.shares().second`.

**What replaces `mom`:** the field becomes `powers`, `crown_moments` becomes `top_powers`, `height_weights` becomes `height_coefficients`, and `n_moments` becomes `n_powers`. The lumped path renames alike.

### 2. Control flow

```
L4 analysis ─ build_grid(p, invaders = range ends)   once per θ₀; again on a big move
│  └ repeat 60–84×: walk_grid(grid, θ′)            reads both recordings
│                     → value, companion, extrapolated, error, ratio, distance, failures
│
└ L3 build_grid  — loop over r (halvings); reads rung reports; writes edges, r, F(t)
   0  edges ← 27 uniform cells over [0, T) (or the caller's); r ← 3
   1  run rung r−2 with factors 1, walk the given invaders
        → control_window(run) → F(t) in ctrl
        → merge the edges after the window: 2^⌊½log₂F(b)⌋ cells
   2  run rungs r−1, r at ctrl (recorded, splits on), walk the invaders on each
   3  per quantity, stand and invaders:
        e = (Q_r − Q_{r−1})/3,   ratio = (Q_{r−1} − Q_{r−2})/(Q_r − Q_{r−1})
      stop if every |e| ≤ ε_Q and, over the resolved quantities, the median ratio
        is ≥ 3 with under 10% negative
      else r ← r+1: the old r−1 and r become r−2 and r−1, so one new run
      at max_halvings: return with a failure row, never a throw (R5)
│
└ L2 run_scm on introduction_times(edges, h): each introduction closes an
│     Interval and opens the next
└ L1 step (odelia): F(t) × the state factors, bound 100, 15-day cap,
│     soil substeps over ode_soil_substep_max_uptake
└ L0 rates: the field from Interval::crowns (open interval at the close);
      the counts from Interval::shares; the open interval's E and M rates
```

**Two details of the loop:**
- *The first rung r−2 runs without factors.* Its ratio is then off by at most 0.016ε, against rung moves of several ε (u54 errs up to 12.5ε).
- *The substep threshold stays at L1 in Control,* set by `control_tf24`. It is a stability limit within a step. Its error is inside the soil's norm (G1–G7), and no rung changes it, so it is not part of the schedule.

### 3. R API

```r
build_grid(p, env = NULL, ctrl = control_tf24(), events = NULL,
           invaders = list(), eps = NULL, edges = NULL,
           halvings = 3, max_halvings = 5, gradient = TRUE)
#> list(runs = list(fine, companion),     # recorded SCMs
#>      edges, halvings, ctrl,            # ctrl carries the tolerance over time
#>      report = list(quantities, distance, failures),
#>      rungs)                            # halvings, introductions, rows, ratio
walk_grid(grid, invaders, gradient = TRUE)   # the report, for each invader
introduction_times(edges, halvings)
control_window(run, invaders, base, share_left, factor_limit)  # `pilot` → `run`
```

- `eps = NULL` reads plant's shipped table (`eps.csv`).
- An equilibrium caller finds b\* by secant on the fine rung of the previous grid, then builds at b\*.

### 4. Cost per analysis

Hand path H2 is pair 108/215 by hand, plus the soil-alone pilot, plus `diagnose_scm` on u215.

| | per evaluation | overhead | E = 60 | E = 84 |
|---|---|---|---|---|
| **Long drought, H2** | 1.948M | pilot 0.22 + 0.637 + 0.312 = 1.17M | 118.0M | 164.8M |
| **Long drought, this design** (stop 108/216) | 1.948M | u54 unweighted 0.312/0.773 = 0.40M | 117.3M (−0.6%) | 164.0M (−0.5%) |
| Long drought, + thinning (est. 4 points) | 1.87M | 0.40M | 112.6M | 157.5M (−4.4%) |
| **Episodic, H2** (estimate 0.19 of the error) | 1.243M | 0.12 + 0.61 = 0.73M | 75.3M | 105.1M |
| **Episodic, this design** (stop 432/864) | 5.31M | 0.26 + 0.41 + 0.84 = 1.50M | 320.1M | 447.5M (4.3×) |

- Episodic's rows are estimated as 0.638 of long drought's for each rung (rule runs in `rows.log`, 474 623 / 744 188). u864 is taken as 2.07× u432, long drought's growth per halving.
- Thinning is estimated at 4 points rather than 4.9 because the dyadic merge keeps 0.5–1× rule A's spacing.
- u108 alone is 53.5M at E = 84, but it errs by 2.73ε: meeting R1 costs 3.0× that.

**On each record:**
- **Long drought and long-wet:** stop at the 108/216 pair (ratios 4.98 and 5.78).
- **Dry:** stops there if its 54/108/215 ratio is ≥ 3; this is unreported (its 108/215/429 ratios are 3.47 and 3.95).
- **Episodic:** climbs to 432/864. `J`'s ratio there is 4.75 and its e is 0.021ε; its gradients at u857 are unrun.
- **Constant:** the caller's edges are halved, which is unmeasured (C1).
- **Invaders:** the range ends gate the build. Every other invader's ratio is reported by `walk_grid`, not trusted.

### 5. Today's pieces

| piece | becomes |
|---|---|
| the pilot | deleted; rung r−2 |
| `control_window` | kept; its first argument is renamed `run` |
| `diagnose_scm` | merged into `build_grid`/`walk_grid`'s report, plus the column `extrapolated` |
| `refine_schedule` | kept, height only, unchanged |
| the shared invader subset | coarser edges; not the default |
| rule A's thinning | merged edges after the window |
| constant's front grid | the caller's `edges` |
| `ode_soil_substep_max_uptake` | kept in Control (L1) |
| `interval_shares`, `for_each_interval_crown` | `Interval::shares`, `Interval::crowns` |
| `mom`, `crown_moments`, `height_weights` | `powers`, `top_powers`, `height_coefficients` |
