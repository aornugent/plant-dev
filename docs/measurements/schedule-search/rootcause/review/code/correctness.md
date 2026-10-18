# Code review, correctness lens: `harness/schedule/refine*.R`

Branch `claude/trusting-curie-4i9n3l`. Code under review: `harness/schedule/refine.R` (139 lines),
`refine_run.R` (92), `refine_case.R` (20), against `docs/design-refine-schedule.md` and
`AGENTS.md`. Every claim below comes from a run. Scratch scripts are in
`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/review_code/`
(called `RC/` below). Runs spent: one forward-only run (G5_dry's nodes). No gradient runs.

**Verdict.** The run setting reproduces round 5 bit for bit. Given round 5's inputs, the schedule
code reproduces round 5's G5 and G5o layouts exactly on all five cases. The loop logic is
correct: signs, units, nesting, Richardson divisors, and the reproduction of all five saved fits.
Nothing blocks correctness on the documented path. What remains: (a) the canonical configuration
has never been run end to end. That configuration is scale 1 with the first run's inputs. It
differs from round 5's tested layout in where its nodes sit (F5). (b) Several ways to fail or to
go silently wrong are outside the five cases (F1–F4, F6–F9). (c) The quantity set is not the one
the evidence measured (F3).

## Findings

| id | severity | file:line | finding | evidence | simplest fix |
|---|---|---|---|---|---|
| F1 | weakens a guarantee (silent) | refine.R:38 | `scm_run` reuses any finished `<name>.rds` in `dir` without checking it matches the request. A rerun in the same dir with a different scale, trait, regime or seed silently returns old runs. `_times.rds` is not rewritten either, so nothing on disk shows the mismatch | `RC/resume.R`: asked for 230 nodes (scale 1, different regime, seed and trait), got the scale-0.5 run's 167 nodes, with no run and no error | reuse only if `identical(x$node_times, times)` and a saved copy of `spec` matches; otherwise rerun |
| F2 | weakens a guarantee (R3) | refine.R:45, 123–128 | One failed run (`status != 0`) calls `stop()`. The refinement then returns nothing, and the driver saves no `fit.rds`, even when earlier passes hold a valid answer and estimate. A NaN or missing quantity in any run crashes `if (all(bound < 1))` or the `while (max(...) > MARGIN ...)` condition with "missing value where TRUE/FALSE needed" | `RC/mock.R` (loop replayed on saved runs with a mocked `scm_run`): NaN `lma` elasticity at level1 → ERROR; NaN in the replay → ERROR; one quantity missing from the replay → ERROR | catch a failed run and return the last completed pass as `status = "failed"`, with its error; treat a non-finite bound as not converged and report which quantity |
| F3 | weakens a guarantee | refine.R:30–33 | `quantities()` returns 48 quantities. The reference set (`refine/lib.R` `Q`, `refine2/score.R`) has 47. The extra one is `rooting_depth_max`, which the evidence set aside as a model kink (error-modes.md G2). r_min and u_q were never measured on it, the scoring of R20 skipped it, yet it votes in the stop. Its ε is floored to 0.01 (eps.csv says 0.0054). The other 47 ε match lib's `EPS` exactly | `RC/eps.R`: "refine quantities: 48; lib Q: 47 … in refine not lib: rooting_depth_max … eps mismatches: 0". On the five fits its bound is 0.20–0.71, never the worst | add `rooting_depth_max` to the excluded names alongside `recruitment_decay` |
| F4 | weakens a guarantee (R3) | refine.R:51–58, 62–71 | `spells_of`/`spacing_of`/`schedule_of` crash when (a) establishment never closes (`b1` NA, which is the design's "none: one spell [0, horizon]" case), (b) T(t) never reaches 0.5 or 0.1 (`t50`/`t90` NA; this includes J = 0), or (c) t50 falls before b1 (`ref` = median of nothing) | `RC/edge.R`: always open → "missing value where TRUE/FALSE needed"; share never ≤ 0.5, never ≤ 0.1, or NaN → "'vec' must be sorted non-decreasingly and not contain NAs"; t50 before b1 → "missing value …". The constant record still has closing edges (5.19, 7.96, 8.37 y; `RC/const.R`), so no bank case triggers this | with no closing edge, take b1 = horizon (one spell); with t50/t90 NA, use the horizon; with no nodes in (b1, t50), use ref = −Inf |
| F5 | weakens a guarantee | refine.R:84–96 vs layoutB.R/layout5.R | The canonical configuration (scale 1, first-run inputs) is not the schedule round 5 validated. Fed round 5's inputs, refine.R reproduces G5 and G5o node for node on all five cases, so every difference comes from the inputs. Node counts are within ±4, but about half the nodes move by more than 0.5 d. Driver of the moves: edges from the first run rather than the pilot, which shifts nodes a median 0.29–0.59 d (90th percentile 1.7–7.8 d) and moves b1 by about 9.5 d on episodic-lma and epi-adG208. Smaller effects: sub-day gaps where the establishment rate flickers across 0.01, which appear in one input and not the other; T(t) ages (+2 nodes on 4 cases); the offspring curve (+6 on epi-adG208); the analytic grade (+3 on long-wet only); H 39.63 vs 39.6. R20 tested scale 0.5 → level 1, never scale-1 level 0 | `RC/cmp_sched.R`, `RC/cmp_place.R`, `RC/half_eq.R`, `RC/edges_mis.R`; table E2 below | run the five cases once at scale 1 (pass 1 only) before treating round 5's pass-1 acceptance as evidence for this code; or state in the design that the evidence is for pilot inputs |
| F6 | cost | refine.R:128 | The k loop allows up to 3 doublings per pass across 3 refining passes, so level 9 is reachable: about 96k nodes on dry, a run of days. Nothing caps total level, rows or time. G5 ("it stops") holds in passes, not in runtime | code: `k < 3`, `PASSES <- 4`; dry nodes at levels 0..3 are 230/412/776/1504 (`RC/struct.R`), so each level is about 1.9× the last | cap the total level (e.g. ≤ 3) and return unconverged past it |
| F7 | weakens a guarantee | refine.R:21 | u_q after a pair allows 0.05ε for step noise. R21 measured step-only moves up to 0.19ε, which enter e as 0.19/3 = 0.063ε and the bound as 0.077ε. The design's 0.024ε is an rms figure, but the bound needs a maximum | refine2/notes.md R21 item 3: "Step changes alone move other quantities by up to 0.19ε (rms 0.034 on dry), which enters the pair's estimate divided by 3" | set the step term from the measured maximum (≈ 0.08) or say it is an rms allowance |
| F8 | minor | refine.R:95, 105 | Mass points sit at the grid's cell right edges (`gm + dg/2`, step 0.36 d). That can lie past the panel's `hi`. In spells under about 1 d, a doubled short spell can then place a node outside its spell | `RC/struct2.R`/`struct3.R`: dry level 3, panel [5.409394, 5.410957] (0.57 d, n = 1) puts a node at 5.411178, 0.08 d into the next gap. At level 2 a node sits 832 s from that spell's end. One node in 5 cases × 4 levels; nesting, breakpoints and uniqueness all hold (E3) | `at = c(lo, pmin(gm[k] + dg/2, hi))`, or place n = 1 panels' nodes uniformly |
| F9 | minor | refine.R:13, 54, 85 | `HORIZON <- 107 * 40 / 108` hard-codes a 40-y lifetime and a 108-node grid, against R1′/G4 ("no rule names an absolute patch age"). The design's G4 caveat lists only the tolerance-weight grid | code; `uniform_times(108)` ends at 39.6296296296 (`RC/pars.R`) | derive from `p$max_patch_lifetime` (or the first run's last introduction) |
| F10 | minor | refine_run.R:80–88 | `g$refusal` from the sweep is dropped (adj_run_nk.R:142 saves it). So a refused gradient reaches the loop as numbers or NaN, and is not reported as a failure (R6) | code diff of the two runners | save `out$refusal` and fail the run, or flag it, when it is set |
| F11 | minor | refine.R:6, 41; refine_run.R:5 | `spec$lib` is required but missing from the header's spec. If it is absent, `LIB` is dropped from the env, `PLANT_LIB` becomes "", and long_drought.R loads whatever plant is on the default path, with no error. Env values are also pasted unquoted into the shell line by `system2` | `deparse(body(system2))`: `paste(c(env, shQuote(command), args))`; long_drought.R:19–21 | document `lib`, and `stopifnot(nzchar(spec$lib))` |
| F12 | minor (claims) | design §algorithm 1, 3 | First run vs a scale-1 run: 0.094 (dry), 0.11, 0.13, 0.097, 0.13, against the claimed "0.09". Replay vs run is 0.51–0.66 at scale 1, as claimed, but 0.57–0.76 at scale 0.5 (dry-flat 0.76). `fit$costs` counts CPU inside `run()` and the sweep only; the FIRST post-processing is about 2 s (wall 31 s vs CPU 29 s on dry) | E7 below | say "0.09–0.13"; give the replay ratio per scale |
| F13 | minor (comment) | refine.R:74 | "Twice the density over the t_r before each spell end" is wrong: `grade` is 2 only up to 0.95 t_r (1.89 at t_r). The analytic grade is within 5% of round 5's measured dry grade (integral of g − 1: 22.8 vs 23.2 d) | `RC/cmp_grade.R` | "Twice the density until 0.95 t_r before each spell end, falling to 1 by 1.4 t_r" |
| F14 | minor (doc) | design "Not yet built" | The stall boundary is in the commitment, but neither built nor listed as not built | design lines 57, 124–126, 234–236 | add it to the not-yet-built list |
| F15 | minor (style) | see E8 | Names that need a comment to decode (`READ`, `UNSEEN_*`), comments longer than two lines (refine.R:1–8, 15–18, 79–82; refine_run.R:1–4), rationale narration, a doc reference in a comment, borrowed `pin`, base names shadowed (`rm`, `save`), and session-scratchpad paths in a checked-in driver | E8 | rename to the design's `r_min`/`u_replay`/`u_pair`, trim the comments, move the paths to the environment |

No finding on these: run-setting fidelity (E1); loop signs, units and divisors (E5); nesting,
replay ⊂ level 0, breakpoints, uniqueness (E3); the reproduction of all five saved fits (E5); the
use of `record_trajectory` (E7).

## Evidence

### E1. Run-setting fidelity: exact

`RC/fid_dry.R` called the real `scm_run` with refine.R's `SETTING`, through
`refine_run.R`, forward only, on round 5's `sched/G5_dry.rds`:

```
refine_run J 1.19859829207125
G5_dry    J 1.19859829207125
identical J TRUE, steps identical TRUE, sizes identical TRUE
rows 622219 622219  cpu 94.242 94.569
```

The same holds line by line in the code against `run5.sh` + `adj_run_nk.R`: `events(events_default(p))`
equals `KNOTS=0`; `ode_tol_abs = ATOL * tol` in both; `SEED=31`; the same weight files; and the same
`HMAX/365`, `SHARE`, `SPLIT == "1"`, `LIFETIME`, `LMA0` and `record_trajectory`. The trait path
is not covered by dry, so `RC/trait.R` builds `p` both ways. For `""`, `lma=0.25`,
`a_dG2=-0.2` and `lma=0.25,a_dG2=-0.2`, it gets `identical(refine_run p, adj_run_nk p) TRUE`.
`strsplit("", ",")[[1]]` is `character(0)`, so the empty trait is a no-op. In refine.R:111, `pars`
comes from `strategy_default`, which differs from the run's strategy in lma, r_l, k_l, stem_*,
psi_crit and nmass_l. It does not differ in `storage_relaxation_offset`, `a_st3` or `a_dG2`, so t_r is
the same: 19.408 d, or 17.85 d on epi-adG208 (`RC/pars.R`).

### E2. Schedule fidelity against round 5 (`RC/cmp_sched.R`)

refine.R's schedule logic, with each input swapped for round 5's, lands on `layout5_<case>.rds`
`$S` with `identical TRUE, max|d| 0` on all five cases. `nodes_of(half = TRUE)` on that schedule
equals `sched/G5o_<case>.rds` on all five (`RC/half_eq.R`). The cumulative swaps run from
refine.R's inputs to round 5's:

| case | refine (nodes; gap/short/replayed) | +layout grade | +H 39.6 | +TW ages | +pilot edges | +pilot nodes = layout5 |
|---|---|---|---|---|---|---|
| dry | 230; 48/26/23 | 230 | 230 | 232 | 232 | 232; 48/26/23 |
| long-wet | 220; 47/25/23 | 223 | 220 | 222 | 220 | 217; 47/26/22 |
| episodic-lma | 205; 26/3/24 | 205 | 205 | 207 | 201 | 201; 24/3/23 |
| dry-flat | 267; 82/63/20 | 267 | 267 | 269 | 271 | 271; 84/65/20 |
| epi-adG208 | 194; 30/12/19 | 194 | 194 | 194 | 189 | 195; 29/12/18 |

Inputs: refine b1/t50/t90 and pilot b1/t50/t90, by case:

| case | refine | pilot |
|---|---|---|
| dry | 3.538/17.24/24.97 | 3.529/17.45/25.30 |
| long-wet | 3.562/17.06/23.52 | 3.552/17.26/23.69 |
| episodic-lma | 3.715/23.89/28.54 | 3.689/24.09/28.76 |
| dry-flat | 3.778/18.67/22.83 | 3.767/18.78/22.89 |
| epi-adG208 | 3.080/17.83/25.48 | 3.054/17.92/25.27 |

`RC/cmp_place.R` measures placement with one swap at a time from refine. Each cell is the swapped
schedule's node count, then the median/90th-percentile distance (d) from refine's nodes to its
nearest node:

| case | grade | H | ages | edges | nodes |
|---|---|---|---|---|---|
| dry | 230, 0.00/0.25 | 230, 0.03/0.27 | 232, 0/0 | 230, 0.33/1.68 | 230, 0.00/1.48 |
| long-wet | 223, 0.00/0.25 | 220, 0.02/0.33 | 222, 0/0.19 | 218, 0.33/2.93 | 217, 0.00/1.61 |
| episodic-lma | 205, 0.08/0.26 | 205, 0.07/0.27 | 207, 0/22.8 | 199, 0.29/7.28 | 205, 0.00/0.71 |
| dry-flat | 267, 0.00/0.19 | 267, 0.00/0.39 | 269, 0/0 | 271, 0.30/3.66 | 267, 0.00/0.02 |
| epi-adG208 | 194, 0.06/0.25 | 194, 0.08/0.49 | 194, 0/0 | 189, 0.59/7.76 | 200, 0.02/4.41 |

Refine vs layout5 overall: 115/230 (dry), 105/220, 105/205, 170/267 and 75/194 nodes lie within
0.5 d of a layout5 node. Edges with no counterpart within 5 d (`RC/edges_mis.R`):

| case | first run only | pilot only |
|---|---|---|
| long-wet | 4.87c/o | — |
| episodic-lma | 3.71c (b1), 4.73c/4.75o, 20.89c/20.90o | 3.69c (b1) |
| dry-flat | 8.50c/o | 4.74, 18.86, 22.71 c/o pairs |
| epi-adG208 | 3.08c (b1), 3.52c, 5.93c/o | 3.05c (b1), 3.54c |

Most of these are sub-day gaps where the rate crosses 0.01. Sub-day gap panels in refine's
schedule number 1/3/1/7/0 (`RC/flick.R`). Each one costs a node pair.

Grade (`RC/cmp_grade.R`), analytic vs measured at days 0, 10, 12, 15, 18, 20, 22, 24, 26, 27.2:

| | 0 | 10 | 12 | 15 | 18 | 20 | 22 | 24 | 26 | 27.2 |
|---|---|---|---|---|---|---|---|---|---|---|
| analytic | 2.000 | 2.000 | 2.000 | 2.000 | 2.000 | 1.821 | 1.592 | 1.363 | 1.134 | 1.00 |
| measured | 2.002 | 2.031 | 2.091 | 2.091 | 2.051 | 1.733 | 1.500 | 1.352 | 1.117 | 1.09 |

Caps, layer_end and spacing match (BG 90, K 0.2, LAYER 24, FALL 10; the cap's 100/280-d switch
at t50). The edge threshold is 0.01 in both. The count rule `2⌈m/2⌉+2` equals layout_B's
`2⌈m/2⌉` then `+2`.

### E3. Structural guarantees (`RC/struct.R`)

Five first.rds files × scale 1 and 0.5 × levels 0..3. All pass these checks: level k ⊂ level k+1,
half ⊂ level 0, every breakpoint except the horizon present at every level and in the half,
and no collapse under `round(·, 10)` (raw count minus unique = 0/0/0/0 everywhere). Nodes by level:

| case | scale 1, L0/L1/L2/L3 (half) | scale 0.5, L0/L1/L2/L3 (half) |
|---|---|---|
| dry | 230/412/776/1504 (152) | 167/286/524/1000 (123) |
| long-wet | 220/393/739/1431 (146) | 152/257/467/887 (117) |
| episodic-lma | 205/384/742/1458 (117) | 127/228/430/834 (82) |
| dry-flat | 267/452/822/1562 (206) | 201/320/558/1034 (180) |
| epi-adG208 | 194/358/686/1342 (118) | 131/232/434/838 (89) |

The scale-0.5 node counts equal the saved runs' (`RC/mock.R`, "times match TRUE" for every run).

- The replay keeps n/2 intervals per replayed spell, and n/2 is odd in 7–13 spells per case. So
  the replay is not "a coarser schedule of the same kind" in the even-count sense. The /3
  estimate does not need it to be.
- Open panels with tiny mass: one panel with under 0.5 d open (dry-flat, 19.380, 0.52 d wide,
  0.36 d open, n = 1). The smallest gap between nodes at level 3 is 830 s on dry, which is F8's
  short spell.
- No spell that opens at an edge got n = 0 for lack of an open grid point (`RC/struct2.R`).
- The establishment intervals tile time with no holes (`gaps > 0: 0`). So `shut()` and the edges
  agree.

### E4. Edge cases (`RC/edge.R`, synthetic `first` from dry's)

| input | result |
|---|---|
| establishment always open | ERROR missing value where TRUE/FALSE needed |
| share never ≤ 0.5 / never ≤ 0.1 / NaN (J = 0) | ERROR 'vec' must be sorted … not contain NAs |
| t50, t90 before b1 | ERROR missing value … |
| shut at 0, opens at 0.5 | ok, 227 nodes |
| first spell removed (b1 later) | ok, 210 nodes, b1 4.588 |
| open from the last spell to the horizon | ok, 232 nodes |
| an extra spell after t90 | ok, unchanged 230: lies inside the last panel, no grading, by design |
| nrr all zero | ok, 291 nodes |
| nrr[1] = 0 | ok, 238 nodes (silently: `fall = −Inf`, so the whole first spell is at b1/24) |
| never open | ok, 1 node at 0 |
| approx ties = "ordered" at a mass plateau | `approx(c(0,.5,.5,1), 0:3, c(.25,.5,.75))` → 0.5 2 2.5: harmless (plateau hit only at an exact share) |

An edge exactly at 0 or at the horizon is excluded by `b > 0 & b < HORIZON`. With no closing edge
up to t90, `ends` is empty, `nx` is NA, and the grade is 1. That case is safe.

### E5. Loop logic

- **Signs and units.** Replay: e = (Q_2h − Q_h)/3 = Q_h − Q* on the square law. Pair:
  (Q_coarse − Q_fine)/(4^k − 1) = Q_fine − Q*, with the spacing ratio 2^k giving 4^k. Both are
  divided by ε, so they are in ε. `extrapolated = q − e·eps` is in the quantity's own units. All
  correct.
- **k.** Chosen from the current run's own error estimate, predicted as e/4^k. This is the right
  quantity. With the cap k < 3: k = 1 for max|e| ≤ 2.43, k = 2 for max|e| ≤ 9.7, else 3 (F6).
- **Bound term.** `unseen` switches to 0.16 after the first pair. The prediction in the k loop
  always uses 0.16. Correct.
- **Pass cap.** The cap is checked after the stop test, so pass 4 returns the finest run with
  `status = "unconverged"`.
- **Reproduction.** `RC/mock.R` replays `refine_schedule` with `scm_run` mocked to read the
  saved runs. On all five cases every requested time vector matches the saved run's, and
  `answer` and `bound` are identical to the saved `fit.rds`.
- **Alignment.** `quantities(r)[names(q)]` returns an NA with name NA for a missing quantity.
  NaN and missing both crash, as in F2.
- **ε.** `eps_of` vs lib `EPS`: 0 mismatches over the 47 shared names, and lnJ uses 0.025, the
  OBJECTIVES figure. The 48th name is F3.

### E6. Resumability (`RC/resume.R`)

A scale-0.5 `level0.rds` copied into a fresh dir, then `scm_run(spec(episodic, seed 7,
lma=0.5), dir, "level0", <230 scale-1 times>)`, returns the old 167-node run. No run is launched
and no error is raised. `level0_times.rds` still holds 167 nodes. The replay would then be pinned to
those steps with a new half schedule. A partial file (forward saved, no `$finished`) is rerun
correctly.

### E7. Cost

`record_trajectory = TRUE` is required in every run. `census_trait_gradient_tf24` calls
`store_trajectory()`, which reruns the forward pass unless states were kept (plant
`scm.h:780–783`, `1174–1178`). So nothing avoidable is computed, and the replay needs its sweep
for the elasticities.

CPU in `fit$costs`, at scale 0.5:

| case | first (s) | replay / level0 | level0 (s) |
|---|---|---|---|
| dry | 28.5 | 0.64 | 236 |
| long-wet | 36.9 | 0.63 | 261 |
| episodic-lma | 23.9 | 0.57 | 123 |
| dry-flat | 59.7 | 0.76 | 477 |
| epi-adG208 | 24.8 | 0.62 | 137 |

At scale 1 (round 5's G5 and G5o):

| case | G5 run (s) | replay ratio | first / G5 |
|---|---|---|---|
| dry | 303 | 0.58 | 0.094 |
| long-wet | 328 | 0.60 | 0.11 |
| episodic-lma | 185 | 0.51 | 0.13 |
| dry-flat | 618 | 0.66 | 0.097 |
| epi-adG208 | 188 | 0.54 | 0.13 |

### E8. Style (AGENTS.md)

- **Names decoded by comments.** `READ`, `UNSEEN_REPLAY`, `UNSEEN_PAIR` (refine.R:15–21) need the
  comment above them. The design calls them r_min and u_q.
- **Comments over two lines** with no silent-failure hazard: refine.R:1–8 (with a doc path),
  15–18 (narrates why), 79–82; refine_run.R:1–4.
- **Borrowed or metaphor words.** `pin`/`PIN` stands for "replay that run's steps", and its
  comment exists to decode it (refine_run.R:3). `UNSEEN`.
- **Base functions shadowed.** `rm` (refine.R:55), `save` (refine_run.R:45), and `names_`, an
  underscore added to dodge `names`.
- **Absolute session-scratchpad paths** in a checked-in driver (refine_case.R:3), plus absolute
  repo paths in refine.R:10 and 25.
- **Clean.** None of frozen/mutant/live/resident/flush/contract/surface/oracle, no banners, no
  issue tags.
