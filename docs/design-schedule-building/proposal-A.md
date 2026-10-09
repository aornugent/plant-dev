# Proposal A: ε is owed by the answer, not by the search

Move 1, weaken the quantifier. "Every run within ε" becomes "every *reported
answer* within ε, and every search evaluation good enough to steer". A check
at the answer detects the rest, and one boring repair fixes it: halve every
spacing.

## Triage: 3

Public R API (`control_window`, `diagnose_scm`, the schedule on `Parameters`),
the core representation of the birth-date coordinate, and requirements that
arrived as mechanisms.

## Requirements ledger

R0–R10 as written in `design-schedule-building.md`. The quantities this
proposal leans on, with two derived here:

- **R7, rows per rung** (`pathfinders/node-axis/ladder_ld.log`, bounded
  Cash–Karp with the window): long drought u54/u108/u215/u429 = 0.312, 0.637,
  1.311 and 2.714M rows. That is linear in introductions: in units of one u108
  forward (F), 0.49, 1, 2.06 and 4.26, and u857 ≈ 8.8 by the same growth.
- **R1, split by quantity** (derived from `logs/{ld,wet}_D_u*.log`, against the
  215+429 extrapolation). `ln J` at u108 is within **0.21ε** (long drought) and
  **0.43ε** (long-wet); at u215 within 0.06ε and 0.095ε. The gradients at u108
  err up to 2.72ε and 3.31ε. The pair 108+215, extrapolated, errs at most
  0.17ε and 0.09ε.
- **R6/R7, where the analysis spends** (`design-workflows.md`): 84 forwards
  for one trait. Each of about ten candidates pays 4–6 secant runs for `b*`
  (they read `ln J` only) against 2.3 forwards for its gradient. The reported
  answer is about 7 forwards more.

**Scarce resource:** the rows of the search's 60–84 forwards, every one
multiplied by the introduction count. Only the ~7 forwards of the reported
answer need every quantity within ε, and the secant reads `ln J`, which
converges 6–15× faster in ε than the gradients.

**Challenged upward:**
- **C1 (R8 "every run").** I believe the outcome you want is that every
  *reported* answer carries its error estimate. A search evaluation that only
  steers would carry its grid's last verdict, labelled as such. Confirm?
- **C2 (R1 "every quantity, every run").** I read ε as owed by the answer. A
  secant run is held only to the `ln J` it reads. Confirm?
- **C3 (R0/R1 on the constant record).** No uniform rung resolves the fate
  front, which is under ⅛ day wide. Its invader radius is 0.0075 in `ln lma`,
  so ×0.5–×2 spans about 90 radii. This design detects the front and reports
  it, and it accepts a supplied base schedule (`const_Gbf16`) as the ladder's
  first rung. It does not place front nodes itself. Is a reported failure on
  constant acceptable until a second record shows a front?

## The floor

Spread uniform nodes at the pair 108+215 for every run, `diagnose_scm` as the
check, and a pilot for the window. It meets R1 (0.17ε). It **fails R7**: 282 F
per analysis on long drought against 115 below, at the same 0.17ε. It **fails
R0**, because a person picks the count and nothing acts on episodic's ratio of
0.76.

## Candidate

**[assigned] Move 1, weaken the quantifier.**
- *Commitment:* every evaluation runs on one nested ladder of introductions:
  the search on its coarse rung, the answer on the pair. A failed check is
  repaired only by bisecting every interval.
- *Pays for:* R7, at 115 F against the floor's 282 on long drought. R0, since
  the check's verdict chooses the rung. R4 and R8, through the check's ratio
  and estimate.
- *Costs:* one type (`BirthInterval`, for R10) and three new names on
  `diagnose_scm` (`eps`, `passed`, `next_introductions`). It is bad at
  constant's front, and at any record where the search's rung steers far from
  the answer's.
- *Wins when:* the search is most of the analysis and reads a quantity that
  converges faster than the answer's quantities. That holds here: `ln J` at
  u108 errs 0.43ε where the gradients err 3.31ε.

Winner: this candidate. It beats the floor on R7 by 2.45× at matched error.

## The commitment

ε is owed only by the reported answer. Every schedule on the birth-date
coordinate is a base set of introductions and its nested bisections, and none
is placed by an error indicator.

**Kept true by:** `diagnose_scm`'s `next_introductions` is the one producer
of new birth-date introductions. It is a function of the times alone (every
interval bisected, 2n − 1), so it cannot read the run. `refine_schedule()`
keeps refusing the birth-date coordinate. The search rung is `every_other()`
of the answer rung, the function `diagnose_scm` already uses, so the two rungs
cannot disagree about which nodes they share.

## Kill question

**Assumption:** a search evaluation may be less accurate than the answer,
because re-measuring at the final θ repairs whatever the coarse rung got
wrong.

**Verdict: survives**, argued from the ledger alone:
- *The secant reads `ln J`.* At u108 its error is at most 0.43ε = 0.011, a
  smooth offset. J is smooth in b down to 5.4e-8, and R3 holds on a frozen
  grid. With `d ln J/d ln b ≈ −0.65` (J(1) = 12.67 and b* = 4.659), b* moves
  0.011/1.65 ≈ 0.0065 in `ln b`, which two secant runs on the pair recover.
- *Gradients at u108 err up to 3.31ε,* but the search only steers by them. If
  the pair's gradient at the found θ fails the caller's criterion, the search
  continues on the pair. Two candidates cost +63 F on long drought, and the
  total stays under the floor's (178 against 282).
- *Reported landscapes are answers.* They are walked on every rung, priced
  into the report below.

## What survives deletion

- `BirthInterval`, with `establishment_shares()` and `for_each_crown()`: R10.
- `control_window(run, …)`: R7, since the window is 21–23% of every pulsed
  row.
- `diagnose_scm` with `eps`, `passed` and `next_introductions`: R0, R1, R4
  and R8.
- `control_tf24` and its 15-day cap: R5. The substep threshold (0.1) stays
  here as a fixed setting, because the run's steps hold it and the schedule
  does not choose it.
- `refine_schedule`: R9.

*Deleted:*
- **The pilot.** The analysis's first run feeds `control_window`. That run
  goes without a window, forfeiting about 0.22 F, against the pilot's
  0.25–0.32 F.
- **`control_window`'s `invaders`.** Invaders 8.7–21× outside rule A's
  protection move 0.002–0.06ε, and the walks fail on stability, which the cap
  handles (`grid-dynamics.md` §8).
- **The shared thinned schedule.** It saves 25% of walk rows, about 9% of a
  search, misses by 0.43ε, and would be a placed schedule.
- **Graded and front placement.**

## What this settles

- No refinement loop or per-node error indicator on the birth-date coordinate,
  and no schedule per invader.
- No pilot run kind with its own count (54) and tolerance (1e-3).
- No per-record exception. The window applies on every record, constant
  included, because reading it is now free. That dissolves "the constant
  record takes no pilot".
- The grid's dependence on θ₀ is the window and the recorded steps only.
  Uniform introductions have no placement to go stale.

## What this makes hard

- **The constant record.** The search rung is meaningless there: lumped
  uniform J was 1.20 at u108 against 289.3. The check fails at every rung
  until the cap (default 857), and the run reports failure with its estimate.
  To cope, the user supplies `const_Gbf16` as the base and the ladder halves
  it. Its gradients' 3ε shift is still reported, not fixed.
- **Episodic's first analysis** pays two failed checks (about 95 F) before the
  rung that passes. The check at (55, 108, 215) is unmeasured on episodic; only
  (108, 215, 429) is measured, at 0.76.
- **Thresholds fitted on two records.** The ratio band [2.5, 8] is set from
  the long drought and long-wet medians at (55, 108, 215), 4.98 and 5.78.
- **The time error is never checked.** It is about 1/100 of the node error, and
  the user dropped its companion.

## Kill condition

Three changes end it:
- *Every search evaluation must carry its own estimate* (C1 refused). The
  search then pays the pair, and the floor wins.
- *The constant record must be met without a supplied base* (C3 refused).
  That hands off to a front-placing candidate (graded causal grid plus front
  nodes).
- *A measurement shows the u108 search needing more than about 6 candidates
  of continuation on the pair* (long drought). The design then converges to
  the floor's cost.

## The design

### 1. The interval

**`BirthInterval`** is the cohorts born between two neighbouring
introductions. It is a type, a view with no state of its own: `lower` and
`upper` node references and `width()`. For the open interval, `upper` is the
boundary node.

Its establishment stays as state on the lower node (`interval_establishment`
E, `interval_establishment_moment` M, a true first moment).

Its two parts are the two quadratures:
- `establishment_shares()` → {lower, upper}. This is today's
  `Node::interval_shares(width)` ("exact counts"), moved so the width is
  computed in one place instead of three (`for_each_establishment_weight`,
  `boundary_weight`, `for_each_interval_crown`).
- `for_each_crown(visit)` → `crowns_per_interval` = 8 crowns at the midpoints
  of equal birth-date parts ("crown spread").

`Species::for_each_interval(visit)` yields the closed intervals, and
`open_interval()` the newest one. A crown record is `{top, leaf_area,
top_powers}`.

**`mom` becomes `top_powers`** (H⁰, H^−η, H^−2η). `crown_moments()` becomes
`top_powers()` and `height_weights()` becomes `height_coefficients()`, on the
lumped height path too.

### 2. Control flow

```
L4 analysis (regnans)                               reads → writes
├ grid build at θ₀ (L3):
│    first run, p@108, factors 1                    → recording@108
│    ctrl ← control_window(run)                     reads offspring_produced_at_ode_times
├ SEARCH LOOP over candidates θ_k                   (steers only, carries grid verdict)
│  ├ SECANT LOOP on ln b: 4–6 runs @108, ctrl       reads ln J → b*_k, recording@108
│  └ invaders walked on recording@108               reads ln J′, gradients → next θ
├ ANSWER LOOP (until passed or n > cap):
│  ├ polish b*: 2 secant runs on X(ln J; @n½, @n)   reads both rungs' ln J
│  ├ d ← diagnose_scm(p@n, ctrl, invaders, eps)     runs @n, @n½, @n¼; walks, sweeps
│  │     → answer = value + error, ratio, passed, distance, failures
│  ├ passed            → report d
│  ├ node error        → p ← d$next_introductions (2n−1); search rung ← n
│  │                      (continue SEARCH on the pair if regnans's criterion fails)
│  └ a throw           → failure row; no climb
└ big move in θ (outside ±10% of θ₀)                → new grid build, window re-read

L2 run (SCM::run)    per introduction: close the open BirthInterval, open the next;
                     integrate to the next introduction
L1 step (odelia)     error norm × tolerance factors(t), bound 100, 15-day cap,
                     soil substepped at share 0.1
L0 rate (Patch)      field ← crowns of every closed BirthInterval (sorted, prefix
                     sums of top_powers); the open one is formed at the close;
                     node rates; the open interval's E and M grow at pr_estab
```

`passed` holds when two things are true:
- every quantity's correction is within its ε (`|error| ≤ ε_q`; measured
  corrections at u215 are ≤ 0.88ε and the extrapolation's residual ≤ 0.17ε);
- over the quantities with `|error| ≥ ε_q/30`, the median ratio lies in
  [2.5, 8]. Below ε_q/30 the order goes unchecked. Even a flat ratio would
  then leave under ε/3.

### 3. R API

```r
control_window(run, base = Control(), share_left = 0.1, factor_limit = 100)
# → Control with ode_tol_factor_times/values from the stand's own run.

diagnose_scm(p, env = NULL, ctrl = control(), invaders = list(),
             events = NULL, gradient = TRUE, eps = NULL)
# → as today (quantities, distance, failures, introductions), plus:
#   quantities$answer   value + error, the two-rung extrapolation
#   passed              TRUE / FALSE; NA when eps is NULL
#   next_introductions  p's introductions with every interval bisected,
#                       or NULL when passed
```

The search rung is `every_other(p$node_schedule_times[[1]])`. With 215
uniform introductions that is exactly u108. The climb loop is three lines in
the caller, because it interleaves with the caller's search.

### 4. Cost per analysis

Measured in F, the rows of one u108 forward on that record. On long drought
F = 0.637M. On episodic F ≈ 0.40M, scaled by its unweighted steps
(11 026 / 17 684); that is an estimate.

**Long drought** (dry and long-wet pass the same first check):

| path | search | answer | total | rows | answer's error |
|---|---|---|---|---|---|
| today as used: pilot, u108, `diagnose_scm` | 84.3 | 7 + 5.25 | 96.5 | 61.5M | ≤ 2.72ε raw, ≤ 1.22ε extrapolated: **fails R1** |
| today made to pass by hand (all at u215) | 0.3 + 84 × 2.06 | 7 × 3.55 | 198 | 126M | 0.17ε |
| the floor (the pair everywhere) | 84 × 3.06 | 24.8 | 282 | 180M | 0.17ε |
| **this design** | 84 | 6.1 + 24.8 | **115** | **73M** | 0.17ε |
| this design, with 2 candidates of continuation | 84 | + 63.4 | 178 | 114M | 0.17ε |

**Episodic** (the pair must reach 429+857; the ratio passes at 4.8):

| path | total | rows |
|---|---|---|
| today as used | 96.5 | 38M, with its error unknown (ratio 0.76) |
| today made to pass (all at u857) | 0.3 + 84 × 8.8 + 106 = 846 | 336M |
| the floor at 429+857 | 84 × 13.1 + 106 = 1204 | 478M |
| **this design, first analysis** | 84 + (6.1 + 24.8) + (12.6 + 51.2) + (26.1 + 105.9) = **311**, to 581 with continuation | 124–231M |
| **this design, rung remembered** | 84 + 26.1 + 105.9 = **216**, to 487 | 86–193M |

Against the hand-built path that meets R1, that is −42% on long drought and
−63% to −74% on episodic.

### 5. Today's pieces

| piece | becomes |
|---|---|
| exact counts (`Node::interval_shares`) | **renamed and moved:** `BirthInterval::establishment_shares()` |
| crown spread (`for_each_interval_crown`) | **renamed:** `BirthInterval::for_each_crown()` |
| `mom`, `crown_moments`, `height_weights` | **renamed:** `top_powers`, `top_powers()`, `height_coefficients()` |
| the pilot | **deleted:** the analysis's first run serves |
| `control_window(pilot, invaders, …)` | **kept:** `control_window(run, …)`, without `invaders` |
| `diagnose_scm()` | **kept**, plus `eps`, `answer`, `passed` and `next_introductions` |
| `SCM::refine_schedule()` | **kept** for height; still refuses birth date |
| the shared thinned schedule | **deleted** (unbuilt). It returns if the invader loop comes to dominate, where its 25% is the whole lever |
| `ode_soil_substep_max_uptake` | **kept** in `control_tf24`. It is not a schedule |
| uniform introductions | **kept:** `node_schedule_times`, with 215 as the default answer rung |
