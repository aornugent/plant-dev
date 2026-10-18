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
