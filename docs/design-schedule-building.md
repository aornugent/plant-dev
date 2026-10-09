# Design: building a run's schedule on the birth-date coordinate

Plant moved TF24 to the birth-date coordinate for stability once the storage
pools were introduced. On the height coordinate, invaders at a zero relaxation
offset overshot; on the birth date they run (`assessment.md`;
`archive/scope-imex-stepper.md`). Exact counts followed, then the crown spread.
The schedule is still built as it was for the height coordinate:

- `refine_schedule()` refuses the birth date.
- The pilot, the tolerance over time (`control_window`) and the error estimate
  (`diagnose_scm`) are separate calls a person strings together.

This turn designs how plant builds a run's schedule on the birth date from first
principles. That covers:

- the introductions;
- the tolerance over time;
- the representation between nodes, today's "exact counts" and "crown spread".

The object both of those integrate over is unnamed, and naming it is part of the
design. The map of today's pieces is `map-schedule-building.md`.

## Triage: 3

- It is public R API: `run_scm(refine_schedule = )`, `control_window`,
  `diagnose_scm`, and the Parameters that carry a schedule.
- It is the core numerical representation of the birth-date coordinate.
- The requirements arrived partly as mechanisms ("pilot", "window",
  "refine").

## Requirements ledger

Sources: `OBJECTIVES.md`, `design-grid-controller.md` (items 6–8 and the user's
decisions), `grid-dynamics.md` (§8, §14, §16) and `geometry.md` (§1–3, §5).

- **R0: heuristics choose the introductions and the tolerance over time,
  together** (OBJECTIVES.md, first line).
  - Today a person chooses the node count and strings together pilot, run and
    diagnosis. `refine_schedule()` refuses the birth-date coordinate.
- **R1: accurate.** `ln J`, every elasticity and every curvature is within ε of
  the converged answer.
  - ε is 0.025 in `ln J`. Each elasticity's ε is a tenth of its spread, never
    under 0.01. Curvatures' ε is 1.2 and 4.0 for `lma`.
  - On the birth-date coordinate the node error is about 100× the time error at
    the tolerances used (item 8).
  - Spread uniform nodes at 108 introductions alone err by up to 3.31ε (long-wet)
    and 2.72ε (long drought).
- **R2: reproducible.**
  - A ±5% nudge in `tol`, or the introductions moved by a quarter of their
    spacing, moves each quantity by less than ε/3.
  - The quarter-spacing move passes on long-wet and dry for both roles
    (`measurements/node-rule/`).
- **R3: continuous in the traits.** On one frozen grid the answer moves smoothly
  as the resident's θ moves within ±10%, or an invader's θ′ within ×0.5–×2.
  - The grid's introductions and steps are frozen per analysis. Invaders walk the
    resident's recording.
- **R4: predictable.** Each knob's error falls at its order, so a coarser run
  estimates the error.
  - Spread uniform nodes are on the square law over 108, 215 and 429 on long-wet
    and long drought. The ratio is 3.78 and 3.92, the companion reports 0.95 and
    0.98 of the error, and the estimate covers 93–95% of quantities.
  - Graded nodes (a fixed rule: 0.03 growing ×1.11 to 0.37) are not on the square
    law under bounded Cash–Karp: their companion reports 0.71 and 0.80.
  - Episodic is not yet asymptotic over u108–u429. Its error falls 4.8× from u429
    to u857, once the spacing is under its dry spells (median 31 days).
  - Under constant rain `J` falls on the square law but its gradients do not:
    the fate front moves them up to 3ε, and no uniform rung refines it. A pilot
    with nodes every 1/16 day around the front was used.
- **R5: never fails** over the trait range, for residents and invaders. This is
  held today by the 15-day cap and the substepped soil.
- **R6: shared.** One grid per local analysis serves the resident and every
  invader in the box. It is rebuilt on big moves in θ.
  - An analysis is 83.6 forwards in rows: 52 stand forwards for `b*` and 31.6
    walks for gradients and curvatures by differences
    (`measurements/equilibrium/costs.log`; the 60 quoted earlier is its
    four-core wall-clock). Each `b*` takes a secant of 4–6 runs.
  - The grid an analysis shares is the record of its resident's last
    equilibrium run.
- **R7: performant.** The least runtime at matched error.
  - One spread u108 forward on long drought is 0.637M rows with the soil
    unsubstepped, the setting every node error was measured at, and 0.373M as
    `control_tf24()` ships it; on episodic 0.416M and 0.230M
    (`measurements/soil-alone/report.log`). The 962 505 quoted earlier was the
    tied baseline, without the window or the bound. A gradient run is about 7 forwards in rows (1 + 2.6 + 0.8 + 2.6). In an
    invader loop an evaluation is about 3.4.
  - Spread 108+215 extrapolated reaches 0.090ε at 2.41M rows (long-wet) and
    0.174ε at 1.95M rows (long drought), forward rows over both rungs.
  - **Measured levers:**
    - the tolerance over time from a pilot saves 21–23% of rows on pulsed
      records and 1.9% under constant rain;
    - the pilot (54 nodes at `1e-3`) costs 0.25–0.32 of a forward's
      member-steps;
    - an invader's shared thinned schedule saves 24–25% of a walk's rows, at
      most 0.43ε (on `recruitment_decay`);
    - thinning the stand's nodes after b = 10 fails (0.70ε), because the soil
      field changes for the cohort that produces `J`.
  - **Where J comes from:** 78–100% of `J` from members born before 3.6.
    59–61% of member-steps come after t = 25, where at most 6.1% of `J` is still
    to come. A node costs its lifetime in steps, so early nodes cost most.
  - **The root law:** at fixed weighted error the fewest cells take spacing ∝
    weight^(−1/3) in birth date (second order) and weight^(−1/6) in time. So
    nodes answer to weight, and steps hardly do.
- **R8: diagnosed.** Every run reports:
  - its error estimate;
  - its θ's distance from the grid's θ₀ against the radius (the radius is
    unmeasured);
  - its failures.

  `diagnose_scm` does this today, at about 0.75 of a run extra.
- **R9: scope.** The birth-date coordinate, which the user decided D applies to
  for every strategy: TF24 first, FF16 and K93 on the same code. The bank is
  constant, wet, episodic, dry and long drought. The height coordinate keeps
  `refine_schedule` and must not break.
- **R10: names a reader can reason with.** The object the counts and the canopy
  integrate over (the birth-date interval between two introductions) has no
  type or name. "Crown spread", `mom` and "pilot" were each hard to read
  (the user). Every new noun must earn its place; none may be a metaphor.

*Challenged upward:* see [Questions for you](#questions-for-you).

## How this was searched

Four proposers each wrote one design in isolation, under one framing move. A
fresh judge then:

- derived the scarce resource before reading them;
- re-priced all four on one set of figures;
- asked each its own kill question.

The proposals, the verdict and the pricing script are in
`design-schedule-building/`.

**Scarce resource.** Rows per evaluation on the one shared grid, paid about 84
times per analysis.

- u108 errs 2.72ε on long drought, so R1 needs the u108+u215 pair, at 3.06
  times u108's rows.
- Building and checking a grid costs about 3 forwards, at most 4% of an
  analysis.

The orchestrator's sealed sentence counted certification as a cost on every
run. Whether it is, is the second question below, and it sets the price:

- a companion beside every evaluation adds 49% to each;
- a recorded estimate costs about 25 forwards once per grid.

**Common figures.** F is one spread u108 forward (0.637M rows on long drought,
0.416M on episodic, at the ladder's setting). Rungs cost u54 0.49F, u215 2.06F,
u429 4.26F, and about 8.8F at u857. Every design also pays the report: one
gradient run, 7 forwards on its answer's rung.

## The floor

The uniform 108/215 pair for every evaluation, extrapolated, with today's
pilot, window and `diagnose_scm`. It meets R1 (0.17ε), but fails twice:

- **R7:** 281F per analysis on long drought.
- **R0:** a person picks the count, and nothing acts on episodic's ratio of
  0.76.

Today's path (u108 by hand) costs 96F and fails R1 at 2.72ε.

## Candidates

| | move | commitment | long drought | episodic | verdict |
|---|---|---|---|---|---|
| A | weaken the quantifier | ε is owed by the reported answer; the search runs on the answer's coarser rung | 128F | 263–310F | **first, with grafts** |
| B | decide offline | a correction recorded at θ₀ is added to every run | 212F | 914F | second |
| C | typical case, detect the rest | the uniform pair, admitted by its own third rung at θ₀ | 376F | 777F | third |
| D | one mechanism | one list of edges, halved; every schedule on it | 303F | 1300F | **killed** |

Rows per analysis on long drought: A 82M, B 135M, C 239M and D 193M at the
ladder's setting. As `control_tf24()` ships, A is 48M.

The judge's corrections to the proposers' own prices:

- **B, C and D** each left out the report and their own check's sweeps.
- **A** priced a remembered episodic rung that broke its own rule (216F, against
  488F when the rule is followed). It also left out the curvatures' walks on the
  answer rungs (+14F).

**D is killed** by its own ledger. Its lattice is justified by estimates staying
true on non-uniform nested schedules, but the only two measured fail:

- the graded ladder sits at a ratio of 2.76, with companions of 0.65–0.80;
- constant's sits at 1.65.

On uniform nodes D is the floor plus a gate.

## The commitment

**ε is owed by the reported answer.** Every evaluation in an analysis runs on
one nested ladder of introductions:

- the search runs on the companion rung;
- the answer runs on the pair, extrapolated and checked.

Kept true by:

- `Parameters` holds the base introductions and `halvings`. The run's
  introductions are derived from them, so a schedule that is not a nested
  bisection cannot be expressed.
- The search rung and the check's companions are `halvings − 1` and
  `halvings − 2` of the same base. They cannot disagree with the run about which
  nodes they share.
- `refine_schedule()` keeps refusing the birth-date coordinate, so no error
  indicator places a node.

## Kill question

*Assumption:* a search evaluation may be less accurate than the answer, because
measuring again at the final θ repairs it.

*Verdict: survives,* argued from ledger facts:

- **The secant reads `ln J`,** which at u108 errs at most 0.43ε (about 0.3ε on
  episodic). That moves `b*` at most 0.0065 in `ln b`, and two secant runs on
  the pair recover it.
- **The selection gradient** at u108 errs at most 2.72ε. Through the
  convergence Jacobian (−91, `grid-dynamics.md` §19) that moves the singular
  point about 0.006 in `ln lma`, far inside ±10%. One Newton step on the pair
  (about 19F) repairs it.

## The design

### The interval: `BirthInterval`

The cohorts born between two neighbouring introductions. It is a view of two
nodes, `lower` and `upper`, with no state of its own. The open interval's
`upper` is the boundary node.

A type is warranted: `species.h` forms the pair by hand at five sites, the width
at four and the shares at three. The establishment integrals stay ODE states on
the lower node (`interval_establishment`, `interval_establishment_moment`),
because the state is indexed by node.

| part | today | becomes |
|---|---|---|
| width | computed at four sites | `width()` |
| its establishment, split to its two ends | "exact counts", `Node::interval_shares` | `establishment_shares()` |
| its canopy, eight crowns at the midpoints of its eighths | "crown spread", `for_each_interval_crown` | `for_each_crown(visit)` |
| every interval, the open one last | hand loops | `Species::for_each_interval(visit)` |
| a crown's top's powers H⁰, H^−η, H^−2η | `mom`, `crown_moments()`, `n_moments` | `top_powers`, `top_powers()`, `n_top_powers` |
| the profile's coefficients in those powers | `height_weights()` | `height_coefficients()` |

- **Kept:** `crowns_per_interval` (8).
- **The lumped height path** takes the same renames, bit-identical (R9).
- **Rejected:**
  - `Interval`, because the word already names the walk's span, the
    disturbance interval and odelia's time intervals;
  - `shares()`, because "share" already means the soil's uptake share and an
    invader's share of J′;
  - `crowns()`, which reads as a getter;
  - `powers`, which says powers of nothing.

### The schedule: a base and its halvings

`Parameters` gains one integer, `halvings` (default 0). On the birth-date
coordinate a run introduces at `introduction_times(node_schedule_times,
halvings)`: every interval of the base is bisected `halvings` times. The default
leaves every existing schedule, and the height coordinate, as it is.

Constant's front is a non-uniform base. It is halved by its cells, not by index:
dropping every other node of a non-uniform schedule merges cells of widths h and
4h, whose error ratio is 1.9 rather than 4, so the /3 estimate breaks.

### The check: `diagnose_scm`

It runs at `halvings`, `halvings − 1` and `halvings − 2`. It is staged:

1. `ln J`'s ratio from stand forwards first.
2. The sweeps and walks, only if that passes.

It gains `eps` (default: the shipped table), `passed`, and the column
`extrapolated` (value + error).

`passed` holds when every |error| ≤ its ε, and the median ratio over the
quantities whose error is at least ε/30 lies in [2.5, 8]. A failed check is
repaired one way only: `halvings + 1`.

### The tolerance over time

The analysis's first run feeds it, and the pilot is deleted. That first run goes
without a window, forfeiting about 0.22F against the pilot's 0.25–0.32F.

The `invaders` argument is dropped. Invaders outside rule A's protection move
0.002–0.06ε, and their stability is the 15-day cap's job (`grid-dynamics.md`
§8).

The names below are mine, not the proposers' or the judge's; your earlier note
asked for them:

| today | proposed | what it is |
|---|---|---|
| `control_window(pilot, …)` | `tolerance_over_time(run, …)` | sets `ode_tol_factor_times/values` from a run |
| `earned` | `produced` | offspring produced by each step's end, as `offspring_produced_at_ode_times` says |
| `left(t)` | `to_come(t)` | 1 − produced(t)/total: the fraction still to come after t |
| `share_left` | `loosen_below` | steps loosen once `to_come` falls below this (0.1) |
| `factor_limit` | kept | |

### The substep threshold

It stays fixed in `control_tf24()` (0.1), at L1. Every proposal and the judge
agree:

- it is a stability limit inside a step;
- no rung changes it;
- its error sits inside the soil's own error test.

It is not part of the schedule.

### Control flow

```
L4 analysis (regnans)
├ grid at θ₀: first run, base, halvings h      → recording
│   ctrl ← tolerance_over_time(run)             reads offspring produced over time
├ search: candidates θ_k, on rung h − 1         steers only; carries the grid's last verdict
│   secant on ln b (4–6 runs)                   reads ln J → b*_k
│   invaders walked on the recording            reads ln J′ (and differences of it)
├ answer:
│   two secant runs on the pair's extrapolated ln J
│   d ← diagnose_scm(p, ctrl, invaders, eps)    runs h, h−1, h−2; staged
│   passed        → report d (extrapolated, error, ratio, distance, failures)
│   not passed    → h ← h + 1; the search continues on the new h − 1 if its
│                   criterion fails there
│   a throw       → a failure row; no climb
└ big move in θ → a new grid; the window read again

L2 SCM::run   introductions = introduction_times(base, h); each closes the open
              BirthInterval and opens the next
L1 step       factors × tolerance over time, bound 100, 15-day cap, soil
              substepped below 0.1
L0 rates      the field from every closed BirthInterval's crowns (top_powers
              prefix sums); counts from establishment_shares; the open
              interval's E and M grow at pr_estab
```

### Today's pieces

| piece | becomes |
|---|---|
| the pilot | deleted; the analysis's first run |
| `control_window()` | `tolerance_over_time(run, …)`, without `invaders` |
| `diagnose_scm()` | kept; rungs by `halvings`, staged, plus `eps`, `passed`, `extrapolated` |
| `refine_schedule()` | kept for height; still refuses the birth date |
| the invaders' shared thinned schedule | not built; it returns if walks come to dominate |
| graded nodes, thinning, front placement by rule | not built (no nested non-uniform ladder passes the gate) |
| `ode_soil_substep_max_uptake` | kept in `control_tf24()` |

## What survives deletion

| name | the ledger line holding it |
|---|---|
| `BirthInterval`, `width`, `establishment_shares`, `for_each_crown`, `for_each_interval` | R10; five hand-built call sites |
| `top_powers`, `height_coefficients` | R10 |
| `halvings`, `introduction_times` | R4 on a non-uniform base; the commitment's mechanism |
| `diagnose_scm`'s `eps`, `passed`, `extrapolated` | R0, R1, R4, R8 |
| `tolerance_over_time` | R7: 21–23% of every pulsed row |

## What this settles

- No refinement loop or per-node error indicator on the birth-date coordinate.
- No schedule per invader.
- No pilot, with its own count and tolerance.
- No per-record exception for the window.
- Uniform introductions have no placement to go stale in θ. The grid depends on
  θ₀ only through the window and the recorded steps.

## What this makes hard

- **The constant record.** No uniform rung resolves its fate front. The caller
  supplies the base (`Gbf16`), and the ladder halves it. If you want a rule
  instead, graft C's jump split (unmeasured; predicted at 90M rows against 40M
  by hand).
- **Episodic's first analysis** climbs twice before its rung passes. Its first
  check, (54, 108, 215), is unmeasured. If it passes by accident it accepts a
  pair whose companion reports 0.19 of the error.
- **The check's ratio band** [2.5, 8] is fitted on two records.
- **The time error is never checked.** It is about 1/100 of the node error.

## Kill-condition map

**A dies** in either case:

- you refuse question 1 or 2 below;
- the u108 search needs more candidates of continuation on the pair than the
  margin allows: more than 2 on long drought (about 19F each), more than 5.6
  on episodic.

Then:

- **B wins** when every evaluation owes ε but may carry a recorded estimate,
  and the elasticities' correction drifts under 30% across the box. It costs
  1.65× A on long drought.
- **C wins** when every evaluation must carry its own companion and the workload
  is episodic-like, provided the (215, 429) pair certifies at u857. With D's
  coarse gate it costs 303F on long drought.
- **D wins** when two or more non-uniform schedules ship, each passing the ratio
  gate on the spread.

## Questions for you

The ranking rests entirely on the first two.

1. **Is ε owed by the reported answer, rather than by every run in the search?**
   R1 says "the converged answer", and OBJECTIVES does not say every run.
   - Yes: A wins at 128F on long drought.
   - No: A dies and B leads at 212F.
2. **Does a recorded estimate satisfy R8, rather than a coarser companion run
   beside every evaluation?**
   - If a companion is required per run, A and B die, and C (with a coarse gate)
     leads at 303F.
3. **R0's "together":** fix the tolerance by rule (`3e-5` with the window) and
   search only the introductions? Node error is about 100× time error. All four
   proposals already do this.
4. **Constant's front:** may the caller supply it, or must a rule place it?
   This does not move the ranking on the pulsed records.

## Measurements that settle it

Rows are at the ladder's setting, then as `control_tf24()` ships.

| # | measurement | settles | rows |
|---|---|---|---|
| 1 | the coarse (54, 108, 215) check on episodic and dry, with gradients | A's episodic exposure; whether the check needs the finer third rung (+30F on long drought) | 2.9M (1.7M) |
| 2 | episodic gradients at u857, stand and invader | every design's episodic rung | 25.6M (14.2M) |
| 3 | A's steering error: the u108 against the pair's selection gradient at θ₀ | A's continuation count | 0 if the node-axis runs survive, else 13.6M |
| 4 | a recorded correction's drift across θ (resident ×0.95, ×1.1; invaders ×0.5, ×2) | B against A; R8's radius for every design | 81M (47M) |
| 5 | the quarter-spacing nudge on long drought at u108 | only if search runs owe R2 | 8.9M (5.2M) |
| 6 | constant's base halved twice, with gradients | whether halving by cells buys R4 on constant | about 8.8M |
