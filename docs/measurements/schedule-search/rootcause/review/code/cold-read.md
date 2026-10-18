# Lens 1 — Cold Reader: harness/schedule/refine*.R

Code: `harness/schedule/refine.R` (139 lines), `refine_run.R` (92), `refine_case.R` (20).

Honesty note: step 1 was the prescribed grep (`<- function|^[A-Z_]* <-|^#`). Because some
definitions are one-liners, the grep itself showed a few bodies before predictions:
`grade` and `reserve_time` (full bodies), `eps_of`'s first line (`vapply(q, function(n) {`),
line 55 of `spells_of` (`rm <- first$stand$remaining; when <- ...`), line 115 of
`refine_schedule` (`history <- list(); cost <- ...`), the first line of `SETTING`, and
`env_num`, `cpu`, `save` in `refine_run.R`. Predictions for those elements are weakened, so
their misses are a lower bound. Nothing else was opened before this section was saved.

## Predictions (written before bodies)

### refine.R

- **Header / `refine_schedule(spec, dir, scale = 1)`**: takes `spec = list(regime, seed,
  trait, weight)`. Runs a first forward run (FIRST=1) to get the establishment rate and
  T(t), builds a schedule, runs level 0 in full (forward + gradient), then a replay of level 0
  with every other interior node removed (`nodes_of(half = TRUE)`, `pin =` level 0) to get
  the estimate. Bound = |estimate| / READ + UNSEEN_REPLAY, in eps units. If every quantity's
  bound < MARGIN, stop; else run level k+1 (counts doubled), estimate = level k+1 - level k,
  bound = |e| / READ + UNSEEN_PAIR; up to PASSES levels. Writes one .rds per run under `dir`
  (via `scm_run`). Returns `list(answer, estimate, bound, extrapolated, schedule, history,
  status)`: `answer` = named numeric of the last full run's quantities (own units);
  `estimate`, `bound` = named numeric in eps; `extrapolated` = Richardson-style answer +
  estimate (or logical "was the answer extrapolated?"); `schedule` = the `schedule_of`
  object; `history` = list of per-pass records (quantities, cost forward/sweep); `status` =
  string, "converged" or "exhausted"/"passes" when PASSES runs out. On a failed run: error
  propagates (stop), no partial result returned.
- **`RUN`**: absolute path to `refine_run.R`, launched as an `Rscript` subprocess per run.
- **`SETTING`**: named character vector of env vars common to every run (TOL, ATOL,
  WEIGHT_SOIL, WEIGHT_MAX, HMAX, ...), passed verbatim to the subprocess.
- **`HORIZON`**: run horizon in years, ~39.63 (107*40/108), the last schedule breakpoint.
- **`READ`** (0.82): divisor in the bound, lowest measured estimate/true-error ratio.
- **`UNSEEN_REPLAY`** (0.33), **`UNSEEN_PAIR`** (0.16): additive bound terms in eps for the
  replay and doubled-pair estimates.
- **`MARGIN`** (0.9): accept when bound < MARGIN (eps units), i.e. 10% headroom under eps.
- **`PASSES`** (4): maximum number of refinement levels (full runs) before giving up.
- **`eps_of(q)`**: maps quantity names (`lnJ`, `lma`, `a_dG2`, ...) to eps; for ln J
  0.025, elasticities from the table (resident vs invader chosen by name or spec), 0.01
  floor/default. Returns named numeric. Unknown name: either 0.01 default or vapply error.
- **`quantities(x)`**: extracts the named numeric vector (ln J, elasticities) from a run
  result `x`. Pure. Errors/NA if the run has no gradient (FORWARD run).
- **`scm_run(spec, dir, name, times, pin, forward, first)`**: if `dir/name.rds` exists,
  returns it (resume); else sets env (SETTING + spec + TIMES + PIN + FORWARD + FIRST + OUT),
  calls `system2("Rscript", RUN)`, reads and returns the .rds. Writes `dir/name.rds`
  (written by the subprocess). On non-zero exit: stop(). `pin` is a run object or path whose
  steps the new run replays.
- **`spells_of(first)`**: from the first run's establishment-rate series, returns spell
  starts and ends (times where the rate rises above / falls below a threshold), plus t50 and
  t90 from `first$stand$remaining`. Returns a list (e.g. `open`, `end`, `t50`, `t90`).
- **`spacing_of(first, sp)`**: returns a node spacing (days) as a function of time (or a
  vector over a grid): fine early, capped 100 d to t50 and 280 d after, wider where offspring
  are far below the spells' median. Pure.
- **`grade(days, t_r)`**: density multiplier: 2 for `days` within ~t_r before a spell end,
  ramping to 1 by 1.4 t_r. (Body seen: 2 for days <= 0.95 t_r, linear to 1 at 1.4 t_r.)
- **`reserve_time(pars)`**: t_r in days = offset * 365 * ln(a_st3 * a_dG2). (Body seen.)
- **`schedule_of(first, pars, scale = 1)`**: returns a schedule object: breakpoints (0, spell
  edges up to t90, HORIZON), base interval count per spell (1 or even+2), and a density
  (from `spacing_of` and `grade`) used to place nodes; `scale` multiplies the base counts.
  Pure.
- **`nodes_of(sch, k, half = FALSE)`**: node times at level k (counts * 2^k), as numeric
  vector sorted including breakpoints; `half = TRUE` drops every other interior node of each
  spell with >= 2 intervals. Pure.

### refine_run.R

- **Script**: one stand run: forward run then the gradient (reverse sweep) unless FORWARD=1.
  Reads env, writes `OUT` (.rds) holding `stand` (cpu, quantities, `remaining` when FIRST),
  `sweep_cpu`, the recorded steps (for a later PIN). Saves partial output (forward) before the
  sweep so a crash keeps the forward result. On failure: R error, non-zero exit, OUT may hold
  the forward part only.
- **Env**: REGIME (climate name), SEED (weather seed), TRAIT_REL (invader trait multiplier
  relative to resident; 1 = resident), TOL/ATOL (ODE tolerances), WEIGHT_SOIL, WEIGHT (path
  to a weight .rds), WEIGHT_MAX, HMAX (max step, days), SHARE (?, a share threshold for T(t) or
  splitting), SPLIT (?, step splitting), LIB (R library holding the plant build), TIMES (node
  introduction times, comma-separated), OUT (output path), PIN (path of an earlier run whose
  ODE steps this run replays), FIRST=1 (also record establishment rate and T(t)), FORWARD=1.
- **`env_num(v)`**: `as.numeric(Sys.getenv(v))`; unset gives NA silently. (Body seen.)
- **`cpu()`**: process user+sys CPU seconds. (Body seen.)
- **`save()`**: writes global `out` to `out_file`; masks `base::save`. (Body seen.)
- **Establishment-rate/T(t) block (lines 59-60)**: per step, rate = growth of the newest
  node's establishment integral / step length; T(t) = survival-weighted offspring so far,
  stored as `remaining` = 1 - T(t)/J (the share still to be produced).

### refine_case.R

- **CLI `CASE SCALE DIR`**: CASE is a key in SPECS; SCALE numeric passed to
  `refine_schedule(scale=)`; DIR is the output directory for run .rds files and the result
  (e.g. `DIR/CASE/...` and `DIR/CASE.rds` or `DIR/result.rds`). Unknown CASE: error.
- **`DEV`**, **`LIB`**: hard-coded scratchpad paths; LIB is the plant library passed on to runs.
- **`weight(w)`**: path to `window/rule_A/weight_<w>.rds`.
- **`SPECS`**: named list of `list(regime, seed, trait, weight)` per case.

## Misses (bodies read after the section above was saved)

Checked 53 elements (refine.R: 18 functions/constants, the `spec` argument and the 7
header-named fit fields; refine_run.R: the script, 17 env vars, `env_num`, `cpu`, `save`,
the FIRST block; refine_case.R: CLI, `DEV`, `LIB`, `weight`, `SPECS`). 18 misses, 35 hits;
five of the hits carry a hazard and are listed after the misses. Evidence from saved runs
in `scratchpad/refine/s05/dry/` where noted; no SCM runs made.

### Structural (change a call site's behaviour)

1. **`spec` (refine.R header, `scm_run`)**: predicted `list(regime, seed, trait, weight)` is
   the whole contract; actual `scm_run` also reads `spec$lib`, and `c(..., LIB = NULL)` drops
   the variable, so refine_run.R runs `Sys.setenv(PLANT_LIB = "")` and long_drought.R falls
   back to `load_all()` on the plant submodule, a different, unoptimised plant (the submodule
   has no `storage_relaxation_offset`). A missing `seed` likewise falls back silently to the
   regime's default seed. Makes calling `refine_schedule` from anywhere but refine_case.R
   wrong without an error, because the header names four fields and the fifth fails silently.
   Fix: name `lib` in the header and `stop()` on any missing spec field (or in refine_run.R
   when `LIB` is empty).
2. **`spec$trait` / `TRAIT_REL`**: predicted an invader's trait as a multiplier, built the
   harness's way; actual a `"name=x[,name=x]"` string applied as `* (1 + x)` to strategy 1
   (the only strategy) on the raw parameter *after* `add_strategies`, so `"lma=0.25"` moves
   `lma` alone while `r_l`, `k_l`, `stem_P50`, `stem_c`, `stem_b`, `psi_crit`, `nmass_l` stay
   at lma 0.32 (verified: these are the parameters the TF24 hyper-parameterisation sets).
   `stand_at(trait, factor)` in long_drought.R uses a factor and re-derives them. The case
   name `epi-adG208` encodes the factor 0.8 while its spec says `-0.2`. Makes comparing a
   refine case with any `stand_at` run harder, because the same trait words name different
   stands. Fix: one convention (factor), named `FACTOR`/`factor`, routed through `stand_at`'s
   construction, or state "raw parameter, others held" in the name.
3. **`MARGIN`** (0.9): predicted the acceptance threshold; actual acceptance is
   `all(bound < 1)` and `MARGIN` is only the target for the *predicted* bound when choosing
   how many levels to jump. Makes tightening acceptance harder: the natural edit (lower
   `MARGIN`) changes level jumps, not when the loop stops. Fix: rename `JUMP_TARGET` (and
   make the `1` a named constant if it is ever meant to move).
4. **Level step / header "each later pass doubles every count, so the run before it is its
   estimate"**: actual jumps `k` = 1..3 levels (counts x2, x4 or x8) with
   `e = (q - qy) / (4^k - 1)`, and `k` stops at 3 silently even if the predicted bound is
   still over `MARGIN` (the cap is in neither comment nor design). `k` also collides with the
   comments' "level k". Makes reading the estimate's divisor and the cost of a pass harder,
   because the header says x2 and /3. Fix: header text; rename `k` to `jump` (design: `j`);
   name the cap.
5. **fit fields (header)**: predicted the seven listed; actual eight: `costs` (matrix, rows
   per run, cols forward/sweep) is returned but not named. Fix: header.
6. **`fit$schedule`**: predicted the `schedule_of` object; actual a summary
   `list(breaks, counts, nodes, t_r, ages)`, while `schedule_of` returns
   `list(breaks, panels, spells, t_r, scale)`. Same noun, two shapes. Makes the design's next
   step ("fix the schedule; later runs run on it unchanged") harder, because the returned
   value cannot be passed back to `nodes_of` (no `panels`, no density mass) and `scale` is
   dropped. Fix: return `sch` itself (plus `level`), derive the summary when printing.
7. **`history[[i]]$bound`** is the scalar worst bound while `fit$bound` is the per-quantity
   vector. Makes any code that walks `history` and `fit` together misread one of them. Fix:
   `worst_bound` (it already sits beside `worst`).
8. **`quantities(x)`**: predicted all elasticities plus ln J; actual silently drops `S_D`,
   `a_f3`, `recruitment_decay`, and the "elasticity" of `TF24_floor_lambda_o` (theta = 0 in
   these pars, verified) is `d ln J / d theta` because of `ifelse(theta == 0, 1, theta)` in
   refine_run.R. OBJECTIVES gives `S_D` and `a_f3` eps 0.01; it does not exclude them. Makes
   adding or auditing a quantity harder, because convergence policy lives in a filter inside
   an extractor. Fix: a named top-level `EXCLUDED <- c(...)`, or keep them at 0.01.
9. **`eps_of(q)`**: predicted the role (resident/invader) chosen by spec or name; actual
   always `role == "resident"`, and an unknown name gets 0.01 via
   `max(NA, 0.01, na.rm = TRUE)` instead of an error, so a misspelled or renamed trait
   converges at the floor. The table is read at `source()` time by a top-level `eps_tab <-
   read.csv(...)` that the surface grep missed (lower-case name). Fix: `eps_of(q, role)` and
   `stop()` on names absent from the table; read inside the function or name the constant
   `EPS_TABLE`.
10. **`scm_run` resume**: predicted resume-by-file; actual the cache key is `name` alone:
    a finished `dir/name.rds` is returned whatever `times`, `pin`, `SETTING` or `spec` are,
    and `name_times.rds` is overwritten with the *new* times first, so the disk record
    disagrees with the returned run. Rerunning refine_case.R with another `SCALE` into the
    same `DIR` returns the old `level0` silently. Fix: compare `x$node_times` (already saved)
    with `times` and rerun or `stop()` on mismatch; write `_times.rds` only when running.
11. **`ATOL`**: predicted an absolute tolerance; actual a multiplier,
    `ode_tol_abs = ATOL * TOL` (so `SETTING`'s "1e-4" means 1e-8). Makes editing `SETTING`
    wrong by a factor of TOL. Fix: rename `ATOL_PER_TOL`, or pass the absolute value.
12. **`SHARE`, `SPLIT`**: no prediction possible; actual `ode_soil_substep_max_uptake` and
    `ode_split_sign_changes`. Fix: name the env vars after the control fields.
13. **`spells_of(first)`**: predicted `list(open, end, t50, t90)`; actual
    `list(edges, ending, b1, t50, t90, shut)`: one edge vector with a logical "is an end" flag,
    `b1` (the first spell end, used as the early-phase boundary throughout `spacing_of`) with
    no comment, and `shut`, a step function that is 1 when closed, read back as
    `open <- sp$shut(gm) < 0.5`. The opening threshold `rate > 0.01` is an absolute,
    regime-dependent literal. Fix: `first_end`, return `open` (not its negation), name the
    threshold.
14. **`PASSES`** (4): predicted a cap on refinement levels; actual a cap on `length(history)`,
    which counts pass 1, so at most three refining runs, and the level can reach 9.
15. **`spacing_of`**: predicted spacing in days over time; actual returns a scalar-only
    closure in years (`100 / 365`), called through `vapply`; before `b1` the cap is
    `b1 / 12`, not the comment's 100 d.
16. **`TIMES`**: predicted a comma list; actual the path of an `.rds` of times.
17. **refine_case.R, unknown CASE**: predicted an error naming the case; actual
    `spec$trait` is NULL and `strsplit` fails with "non-character argument".
18. **`SPECS`**: predicted to carry `seed`; actual `seed = "31"` and `lib` are appended for
    every case on line 16.

### Hits that carry a hazard

- **`refine_schedule`'s `pars`**: a second parameter construction beside refine_run.R's,
  built from `strategy_default` (lma 0.198) without `trait_matrix(LMA0, "lma")`, with the
  trait parsing duplicated. Harmless today: `reserve_time` reads `storage_relaxation_offset`,
  `a_st3`, `a_dG2`, none set by the hyper-parameterisation (verified). It breaks the day
  `reserve_time` reads a derived trait. AGENTS: "No parallel near-copy of an existing ...
  path". Fix: refine_run.R saves `p$strategies[[1]]$pars` in `out$stand`; read it from
  `first`.
- **`HORIZON <- 107 * 40 / 108`**: long_drought.R has `107 * LIFETIME / 108` with
  `LIFETIME` from env; setting `LIFETIME` desynchronises the schedule's horizon from the
  run's patch lifetime. AGENTS: "no passing a count that can disagree with its source of
  truth". Fix: `107 * LIFETIME / 108` (long_drought.R is already sourced first).
- **`env_num`**: unset vars become `NA` silently (e.g. `HMAX` unset sets
  `ode_step_size_max <- NA`). `TOL` has a second default ("1e-4") in refine_run.R besides
  `SETTING`.
- **`save`** masks `base::save` inside the script.
- **refine.R is not self-contained**: `refine_schedule` needs `scm_base_parameters` (plant
  loaded by the caller sourcing long_drought.R first); nothing says so.

## Comment findings (AGENTS Code style)

Banned single words (`frozen`/`mutant`/`live`/`resident`, `flush`, `contract`, `surface`,
`oracle`), issue tags, `§`: none in comments — checked all 22 comment lines. (`"resident"`
appears only as a data value in `eps_of`.)

Longer than two lines without a silent-failure hazard:
- refine.R 1-8 (8 lines; the only API doc, and three of its statements are false, below).
- refine.R 15-18 (4 lines; exists to decode `READ` and `UNSEEN_*`).
- refine.R 79-82 (4 lines, `schedule_of`).
- refine_run.R 1-4 (4 lines; exists to decode env names `PIN`, `FIRST`).
The one genuine silent-failure hazard in this code (missing `spec$lib`, miss 1) has no
comment.

Names that needed a comment to decode (rename instead):
- `READ` -> `ESTIMATE_RATIO_MIN` (design: `r_min`); `UNSEEN_REPLAY`/`UNSEEN_PAIR` ->
  `UNESTIMATED_REPLAY`/`UNESTIMATED_PAIR`, and the `0.11 + 0.22` sums are only mapped to
  "tolerance bias" and "short spells" by word order.
- `PIN` -> `STEPS_FROM` ("an earlier run whose steps this one replays"); `FIRST` ->
  `RECORD_ESTABLISHMENT`.
- `nodes_of(half = )` -> `replay = TRUE` or `every_other`.
- `reserve_time`'s comment "o ln(a_st3 a_dG2)" decodes the formula and drops the `365`.
- No comment and no obvious meaning: `b1`, `shut`, `panels` (comments say "spell"), `held`,
  `SHARE`, `SPLIT`, `TRAIT_REL`, `HORIZON`'s `107 / 108`.

Borderline: refine.R line 2 points at `docs/design-refine-schedule.md` (not a `§` reference
or process history, but a doc pointer in a code comment).

False against the body:
- refine.R header: "each later pass doubles every count, so the run before it is its
  estimate" — jumps of x2, x4 or x8 (miss 4).
- refine.R header: return list omits `costs` (miss 5); `spec` omits `lib` (miss 1).
- refine.R header: "Quantities are ln J and the elasticities" — three are dropped and one is
  a semi-elasticity (miss 8).
- `grade`: "Twice the density over the t_r before each spell end, falling to 1 by 1.4 t_r" —
  the body is 2 only up to 0.95 t_r, then linear to 1 at 1.4 t_r.
- `schedule_of`, `nodes_of`: "an interval count per spell", "each spell that holds two or
  more intervals" — counts are per panel between breakpoints; breakpoints stop at t90, so the
  last panel spans every spell after t90 under one count.
- `spacing_of`: "a cap of 100 d until t50" — before `b1` the cap is `b1 / 12`; the 90-d base
  spacing is unmentioned (incomplete rather than false).

## Design mismatches (design-refine-schedule.md, "The algorithm" and "The tool")

Matches: first run (forward, 100 even introductions); breakpoints at 0, edges up to t90,
horizon; one / even+2 counts; nesting by 2^k; pass 1 replay on own steps, `/3`; r_min 0.82,
u 0.33 / 0.16, jump target 0.9; stop at bound < eps; doubled-pair estimate `/(4^j - 1)` with
no replay; spell ends taken once; `answer` from the last run; `history` fields (level, nodes,
answer, estimate, worst bound); `costs` forward/sweep; `status` converged | unconverged;
`extrapolated` = Q - e. Acknowledged unbuilt and absent: curvatures, `where`, distance from
theta_0, invaders' spell ends, the stall boundary, later runs on the fixed schedule.

Mismatches:
1. Signature: design `refine_schedule(p)`; code `refine_schedule(spec, dir, scale = 1)` with a
   harness-specific `spec` (needs `lib`, miss 1) and `scale`; the design says scale 1 is
   canonical, yet refine_case.R makes `SCALE` a required positional argument.
2. Jump: design "j the fewest doublings whose predicted bound ... is under 0.9", unbounded;
   code caps j at 3 and proceeds at 3 when the target is not met.
3. Grading: design "raised to 2 over t_r before each spell end"; code holds 2 only to
   0.95 t_r and ramps to 1 at 1.4 t_r.
4. Interval counts: design "each spell's interval count"; code counts per panel, and after t90
   one panel covers all remaining spells.
5. Quantities: design/OBJECTIVES give eps_q for every elasticity, with `S_D`, `a_f3` at 0.01;
   code drops `S_D`, `a_f3`, `recruitment_decay` from the stop test, and uses resident eps
   only.
6. `fit$schedule`: design "breakpoints, counts at the final level, node times, t_r, ages" —
   code matches, but this is a summary that cannot seed the design's "fix the schedule" step
   (miss 6); the design's own next step needs `panels`.
7. `fit$estimate`: design says it carries "its bound"; code has a separate `bound` field (the
   design's own "Built so far" line lists `bound` separately — internal to the doc).
8. u_q: design subscripts it per quantity; code uses one scalar for all (values agree).
9. Not in the design: resume from `dir` keyed by run name (miss 10), and the raw-parameter
   fractional trait perturbation (miss 2).
10. "after four passes": code counts pass 1 among the four, so at most three refining runs;
    the design's wording allows either reading.

## Counts

- Predictions: 53 checked, 18 misses, 35 hits (5 hits with hazards). Weakened (bodies seen in
  the grep): `grade`, `reserve_time`, `env_num`, `cpu`, `save`; none of them is a miss.
- Comment findings: 0 banned words (22 comment lines checked), 4 over-length blocks, 11 names
  needing decoding, 6 false or incomplete comments, 1 borderline doc pointer.
- Design mismatches: 10 (15 design statements checked as matching).
