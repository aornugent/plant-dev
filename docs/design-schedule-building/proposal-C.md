# Proposal C: the uniform pair, admitted by its own third rung

Move 5: optimise the typical case and detect the rest.

## Triage: 3

This changes public R API (`diagnose_scm`, `control_window`, a new builder) and the
birth-date coordinate's core representation. The requirements also arrived as
mechanisms ("pilot", "refine").

## Requirements ledger

- **R0.** Nobody picks N. Today a person picks it (108).
- **R1.** Every quantity is within ε. Spread u108 alone is 2.72ε off on long drought and 3.31ε on long-wet. The 108+215 extrapolation is 0.174ε and 0.090ε off.
- **R2.** Nudges move a quantity < ε/3. The quarter-shift passes on long-wet and dry. It is unmeasured on long drought.
- **R3.** Smooth in θ on one grid. Invaders walk the resident's recording.
- **R4.** Each knob is on its order. Spread uniform nodes over 108–215–429 have ratios 3.78 and 3.92 and companions 0.95 and 0.98. Episodic's ratio is 0.77, with companions 0.19 (resident) and −0.00 (invader); it reaches the square law only between u429 and u857 (J moves 0.0076, then 0.0016). Constant's gradients do not converge.
- **R5.** Never fails. The 15-day cap and the soil stepped alone hold this.
- **R6.** One grid serves an analysis of 60–84 forwards, counted in rows as 84.
- **R7.** Rows at matched error:
  - A forward at u108 is 373 188 rows on long drought and 229 703 on episodic (`design-soil-alone.md`, R1).
  - Rows grow ×2.05 per halving (§16: 0.64M to 1.31M).
- **R8.** Every run reports its error, its distance from θ₀ and its failures.
- **R9.** The birth-date coordinate, for every strategy. The height coordinate keeps `refine_schedule`.
- **R10.** The interval gets a name, and the name is not a metaphor.

**Scarce resource.** It is the rows of an analysis's 84 forward-equivalents, each paid at the introductions of the grid the analysis runs on. A build is paid once per analysis, so one extra rung at θ₀ costs 13.8 × 4.20 = 58F on long drought, where F is one u108 forward. Running all 84 forwards one halving finer "to be safe" costs 84 × (6.25 − 3.05) = +269F. So it pays to verify a coarse grid once, and it does not pay to over-resolve every run.

**Challenged upward:**
1. *R0's "together".* At 3e-5 the node error is about 100× the time error (item 8). I believe you want both axes chosen without a person, not a joint search. If so, the tolerance is set once (`control_tf24` with the window) and only the introductions are searched. Confirm?
2. *"Constant takes no pilot."* That decision weighed one run. Spread over an analysis, the soil-alone pilot (43k rows, 0.24 of a run) costs less than the window saves (2% × 84 = 1.7 runs). In this design the constant record's window is read from a run on its jump-split grid, which is what a pilot there needs: the causal grid read R within 1.1%, where uniform 54 read J as 0.0008.

## The floor

The floor strings today's pieces into one call: the pilot, then `control_window`, then every forward at the uniform pair (108, 215) extrapolated, then `diagnose_scm` once.

It **fails R1 and R4 on 2 of the 5 records:**
- **Episodic.** The pair's estimate covers nothing (companion 0.19 and −0.00), and J is still moving +0.0076 from 215 to 429.
- **Constant.** Uniform 108 gives J = 1.20 against 289 (lumped), which is |Δ ln J| = 219ε.

It also fails R0 on constant, where the front grid is built by hand. Those lines are what the candidate must pay for.

## Candidate

**Move 5.**
- **Commitment:** an analysis runs on the uniform pair (108, 215) only if that pair's own third rung (429), run at θ₀, passes the square-law gate. Everything else goes to brute force: halving, with jumps split. It never goes to a heuristic grid.
- **Pays for:**
  - R0: no N is chosen by hand.
  - R1 and R4: episodic and constant are detected and refined.
  - R8: every run carries its pair's estimate.
  - R7: the typical record runs at the cheapest verified pair, 0.49 of an always-safe schedule.
- **Costs:**
  - Two functions and one list.
  - Two constants for splitting jumps.
  - +13% rows over today's unverified path on the typical record.
  - 2.3× today's rows on episodic and constant.
- **Wins when:** the workload sits on records that are smooth at a spacing of 0.37. These are 3 of the 5 bank records (long-wet, dry, long drought) and the climate ε is set on.

**The lopsidedness the move needs is in the ledger.** The general alternatives are expensive precisely because they are general:
- *Always-safe uniform:* the pair (215, 429) for every forward, checked at 857. It costs 644.7F per analysis on long drought, against this design's 314.9F.
- *Local refinement of the stand,* `refine_schedule`'s leave-one-out per node. On the birth-date coordinate it would be wrong unless every round paid for a sweep. A node's own share misses the field part: §8 test 2 found 2.3 of the 2.6% that way, and thinning after b = 10 moves ln J 0.70ε.

Uniform halving sidesteps the per-node estimator entirely.

## The commitment

A grid is used only after its own three nested rungs pass the registered square-law gate at θ₀. The uniform 108/215 pair is the only grid tried without search.

**Kept true by:**
- `build_schedule()` takes no node count and no path argument. The only way to get `path = "uniform"` is a passing check on u108/u215/u429.
- `run_extrapolated()` takes only that schedule, and every run returns its own pair's estimate and its distance from θ₀.

## Kill question

*The assumption whose falsity makes this unnecessary:* most analyses run on records where the uniform pair is already asymptotic.

**Survives.** Three of the five records pass L1–L3, and ε's climate is long drought. Even if the workload were all episodic, guessing wrong costs one u108 stand forward (1F), because u215 and u429 are the slow ladder's first rungs and are reused. On constant it costs 7.25F of stand forwards. Neither is a reason to drop the fast path.

## What survives deletion

- `build_schedule`: R0 (nothing else chooses).
- `run_extrapolated`: R1 (its value is the one that is within ε) and R8 (its error column).
- The schedule list: R6, because one grid serves the analysis.
- The staged check: R4, and the 7.25F failure cost on constant.
- Splitting jumps, which needs two constants:
  - It is held by R1 on constant. Without it, halving a uniform lattice never resolves a front under ⅛ day: 1/16 day across 40 years would be about 233k introductions.
  - Threshold |Δ ln| > ln 10⁶ = 13.8. A smooth first-mover layer (L ≥ 0.13) steps at most 0.37/0.13 = 2.8 between u108 nodes. Constant's front steps ≥ 32, from a mortality integral of 32 against 0.45.
  - Floor 1/16 day: the spacing that converged constant's J.
- `max_introductions`: R5 and R8, so the search stops and reports.
- `BirthInterval`: R10.

## What this settles

- No per-node or per-interval error estimator on the birth-date coordinate.
- No hand-chosen N.
- No separate diagnosis call.
- No graded or thinned stand grid. Graded nodes (B) stay an option outside this design.
- A record whose pair failed its square law can never be run on that pair.
- Non-uniform grids appear only where a jump forces them.

## What this makes hard

- **The typical record pays +13%** over today's unverified path (58F for the check against `diagnose_scm`'s 21F). *Cope:* if a one-sided coarse gate is accepted, the check drops to 6.8F and the total to 0.95× today's. Long-wet's 54–108–215 ratio is 5.8, which over-reports. Whether a coarse pass certifies the finer pair has to be measured on the bank first.
- **Episodic and constant cost 2.3× today's path,** which is unverified on both.
- **R2's nudges are not re-checked at each build.** Long drought's quarter-shift is unmeasured.
- **The box's interior is not checked.** On constant the front moves from 0.012 to 2.2 years across ×1.01–×0.5, so in-between invaders get flagged by their per-run estimate rather than served. *Cope:* the caller rebuilds with that invader among the check's invaders, giving several grids per R6.
- **The thinned invader walk's 24–25% is forgone,** as the user decided.

## Kill condition

The workload stops being lopsided: the climates studied have dry spells longer than the spacing (episodic-like), so the check mostly fails. The fast path then becomes decoration, and the search should hand off to a lattice spaced by the record's forcing. That design is unbuilt here.

The check would also die if a single pair's estimate were shown to be honest without a third rung (companion near 1 on every record).

## The design

### 1. The interval

**`BirthInterval`** is a type: a view of two adjacent nodes, `lower` and `upper`, meaning the cohorts born between their birth dates.
- Species builds one on the fly and never stores it.
- E and M stay as ODE states on the lower node (`interval_establishment`, `interval_establishment_moment`). M is a true first moment.

Its parts:
- `shares()` returns {lower, upper}, the establishment split to the two ends. This is today's `interval_shares`; it replaces the term "exact counts".
- `for_each_crown(visit)` gives eight crowns at the midpoints of the interval's eighths. This replaces the term "crown spread".

How Species uses it:
- `Species::for_each_interval(visit)` visits every interval, with the open interval last (its upper end is the boundary node).
- The establishment weights and the light field both iterate over it.
- `boundary_weight` is the open interval's upper share.

**`mom` becomes `top_powers`:** H⁰, H^−η and H^−2η of the crown's top. With it, `crown_moments()` becomes `top_powers()` and `height_weights()` becomes `height_coefficients()`. The lumped path is renamed in the same way.

### 2. Control flow

```
L4 analysis (caller)        reads θ₀, the box's corner invaders, ε
│  s ← build_schedule(p(θ₀), eps, invaders = corners)          once per grid
│  ~84×: run_extrapolated(p(θ), s, invaders)  reads s; writes value, error,
│        distance, failures; a run with error > ε/3 is flagged → caller rebuilds
│
└─ L3 build_schedule
   ├─ pilot: u54 @1e-3, soil alone, corners walked → window factors in ctrl
   ├─ check u108, u215, u429 @ ctrl, each recorded
   │    stage J:   stand forwards → median ratio of ln J        fail → refine
   │    stage all: sweeps + corner walks on those recordings →
   │               L1 ratio ∈ [3, 5.3], <10% negative; L2 companion ∈ [0.8, 1.25],
   │               over quantities whose fine move ≥ ε/30
   │    pass → path "uniform", pair (u108, u215)
   └─ refine (on fail):
        jumps: read u108's per-node offspring per unit birth date;
          loop ≤3: split each interval with |Δ ln| > ln 1e6, width > 1/16 day,
                   into 16; stand forward @1e-3 on the new grid
                   → writes grid G₀ and the window
        halve: loop k: rungs G_k, G_k+1, G_k+2 (recorded ones reused), staged check
               pass → pair (G_k, G_k+1);  |G_k+2| > max_introductions →
               failure row, best pair kept
   │
   └─ L2 SCM::run, per rung (unchanged): insert at each introduction, integrate
      └─ L1 odelia step (unchanged): factors × window(t), cap 15 d, bound 100,
         │  soil substep share 0.1 (control_tf24; the threshold's tuning is
         │  deferred by the user, and it is not a schedule choice)
         └─ L0 rates: each BirthInterval → shares → weights; crowns → field
            (top_powers prefix sums); the open interval's E and M grow
```

The pair is the triple's two coarser rungs, because those are what the registered L2 validates. The finest rung is only the check.

### 3. R API

```r
build_schedule(p, eps, env = NULL, ctrl = control_tf24(), invaders = list(),
               max_introductions = 1728)
# list(introductions = list(coarse, fine), ctrl, theta0,
#      path = "uniform" | "refined",
#      check = data.frame(quantity, parameter, role, coarse, fine, check,
#                         ratio, companion, judged),
#      failures)

run_extrapolated(p, schedule, env = NULL, invaders = list(), gradient = TRUE)
# list(quantities = data.frame(quantity, parameter, role, value, coarse, fine,
#                              error),   # value = fine + (fine - coarse)/3
#      distance, failures)               # diagnose_scm's tables, kept
```

### 4. Cost per analysis, in rows

F is a u108 forward. Rungs cost 1, 2.05, 4.20 and 8.62 F for u108, u215, u429 and u857. The check is 13.8 forward-equivalents per rung: stand gradient 3.6, diagonal invader 3.4 and two corners 6.8.

| | today (by hand) | this design |
|---|---|---|
| long drought | pilot 0.66 + 84×3.05 + diagnose 0.75×13.8×2.05 = 278.1F = **103.8M** | 0.66 + 84×3.05 + 13.8×4.20 = 314.9F = **117.5M** (+13%) |
| episodic | 278.0F = **63.9M**, estimate covers nothing | 0.62 + 1 (u108 wasted) + 84×6.25 + 13.8×8.62 = 645.7F = **148.3M**. This assumes the gradients pass at 215–429–857, which is unmeasured; J's ratio is 4.75. If they do not, 1322F = 303.7M |
| constant (1193 rows per introduction) | Gbf16/32 pair: 84×396 = **39.7M**, gradients 3ε off | 7.25F wasted, then ≈3 jumps × 45 gives 243 introductions; 84×728 + 13.8×969 introductions = **90.0M**. Predicted, not measured |
| long drought, always-safe uniform | 644.7F = **240.6M** | the fast path is 0.49 of it |

### 5. Today's pieces

| Piece | Becomes |
|---|---|
| the pilot | kept, inside `build_schedule`; re-read on a jump-split grid |
| `control_window()` | its reading kept, unexported, called by `build_schedule` |
| `diagnose_scm()` | merged: its runs, walks, sweeps, distance and failure rows become `run_extrapolated` (the pair) and the check (rungs go up, not down); the name is deleted |
| `SCM::refine_schedule()` | kept for the height coordinate, unchanged; its birth-date refusal names `build_schedule` |
| the shared thinned schedule | not built; it stays the measured candidate |
| `control_tf24()` | kept as the base `ctrl`; the soil substep threshold stays there |
| `interval_shares`, `for_each_interval_crown`, `for_each_establishment_weight` | merged into `BirthInterval` and `for_each_interval` |
| `crown_moments`, `height_weights`, `mom` | renamed `top_powers`, `height_coefficients`, `top_powers` |
