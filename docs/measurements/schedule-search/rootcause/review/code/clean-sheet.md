# Clean sheet: refine_schedule, from the design alone

Written blind to the implementation, from `docs/design-refine-schedule.md` (its
"Built as / Built so far" lines ignored), `AGENTS.md` and `OBJECTIVES.md`. Backend read: the
TF24 runner (`adj_run_nk.R`: forward, sweep, `PIN` replays another run's steps), and
`harness/run_record.R` (`creation_record` recovers the establishment rate per accepted step).

## Parts, about 150 lines of R

1. **`run_stand(dir, name, times, pin = NULL, forward = FALSE)`, ~25 lines.** Writes `times`,
   shells out to the runner, returns the rds. Resumable by construction: if `dir/name.rds`
   exists with `finished` and its `node_times` and setting equal the request, it is read, not
   rerun. Stores nothing itself; the run files are the record. One runner: add
   `creation_record` (and the per-node offspring) to the runner script rather than use
   `run_record.R` for the first run and `adj_run_nk.R` for the rest.
2. **`quantities(run)`, ~5 lines.** `c(lnJ = log(J), elasticity)`, named, so fine and coarse
   align by name, never by position.
3. **`first_schedule(first)`, ~35 lines.** Spells are `rle(rate > 0)` over the creation record;
   breakpoints are 0, every spell edge up to t90, and the horizon. T(t) from cumulative
   offspring by birth date; t_r = o·ln(a_st3·a_dG2) from the traits. The density is a table of
   its cumulative C(t) on a fine grid, graded by the offspring curve and ×2 over t_r before each
   spell end. Returns `list(breaks, density, k = 0)`. Built once; the loop never reassigns
   `breaks` or `density`, only passes a level, so spell ends cannot move between passes.
4. **`node_times(s, k)`, ~20 lines, the only constructor of introductions.** Per segment, mass
   m = ΔC; n = 1 if m ≤ 1, else 2·⌈m/2⌉ + 2; a spell's n times 2^k, a gap's held at 1. Nodes at
   C⁻¹(C(b) + (0:(n−1))·m/n). Returns `data.frame(t, i, n)`. Counts are never stored, so an odd
   count above 1 cannot be expressed. Nesting is exact in floating point: level k evaluates
   (2i)/(2n), which rounds to the same double as i/n.
5. **The replay mask, 1 line:** `keep <- nt$i %% 2 == 0`. With n even, odd i are exactly the
   interior nodes whose removal merges every pair, spell ends kept; n = 1 has no i = 1. The
   replay runs `nt$t[keep]` pinned to the fine run's file, so its nodes are a subset by
   indexing, never by a tolerance match.
6. **`estimate(fine, coarse, j, replay)` and `bound(est)`, ~12 lines.** One formula for both
   passes, e = (Q_c − Q_f)/(4^j − 1): the replay is j = 1, so its /3 is not a special case.
   `bound` = |e|/r_min + u·ε, with u = 0.33 if `est$replay` else 0.16, read inside `bound`;
   `bound` is the only comparison against ε anywhere, so the unseen term cannot be skipped.
7. **`refine_schedule(p, dir)`, ~40 lines.** First run (forward, 100 even nodes) →
   `first_schedule` → pass 1: fine at level 0, tol 1e-4, plus its replay → while some bound
   ≥ ε_q and passes < 4: j = fewest with max_q(|e_q|/4^j/r_min/ε_q) + 0.16 < 0.9, `coarse <-
   fine`, run level k + j, `estimate(fine, coarse, j, replay = FALSE)`. A full run is only ever
   the answer or the next pass's coarse run, so no run is only a check.
8. **The fit, ~15 lines,** a pure function of the run files: `answer` (last run), `estimate`
   (e, bound, Q − e as `extrapolated`), `schedule` (breaks, derived counts and times, t_r, ages),
   `history` (one row per pass, rebuilt from files, not appended), `costs`, `status`.

Stored: the run files, `(breaks, density, k)`, and per strategy r_min = 0.82, u (0.33, 0.16)
and the ε table, in one list (what a strategy supplies). Derived: counts, times, the mask, j,
estimates, bounds, history, status.

## Decisions an implementer must make

1. **Where loop state lives.** Run files under fixed names (`first`, `pass1`, `pass1-replay`,
   `pass2`…), the fit rebuilt from them, against holding state in memory and a final save.
   Files win: a crash costs one run, not the stack.
2. **Gaps under doubling.** Hold a gap at one interval, against doubling every count as the
   design literally says. Doubling is less code, but a gap's mass is 0, so C⁻¹ collapses every
   node onto the gap's start.
3. **j.** Fewest doublings to a predicted 0.9ε, against always j = 1. j = 1 is one line and
   G5 still holds; the formula saves a pass only when e is far over ε, and needs a cap (2^j nodes).
4. **Density representation.** A tabulated cumulative inverted with `approx`, against a closed
   form; the table is simplest and handles t_r ramps that overlap.
5. **One runner script or two.** One, with the creation record added; two is a near-copy.

## Failure modes to test

- **Spells:** constant rain (no gap: one spell [0, horizon], stall unplaced and reported);
  a spell open at t = 0 or still open at t90 or the horizon (duplicate breakpoint); two edges
  inside one step (zero-width spell); a one-step zero inside a spell (spurious gap); NA rows
  of the creation record (no open node); a count of exactly 1 versus just over 1.
- **Construction:** for k = 0..4, `node_times(s, k−1)$t ⊂ node_times(s, k)$t` with `identical`
  doubles; the mask drops Σn/2 nodes and keeps every breakpoint; every spell's n even or 1.
- **Resumability:** kill mid-run (rds without `finished`) and rerun; a dir from other traits or
  rain must be refused, not reused; a replay whose pinned base was rerun is stale; rerunning a
  converged dir runs nothing and returns an identical fit.
- **Missing quantities:** a sweep refusal or NA elasticity makes the bound NA, which must read
  as not converged (`isTRUE(all(...))`), and makes j undefined; a run that throws is recorded as
  a failure, never a crash (R3); names absent from one run; e = 0 exactly (j = 1).
- **Cap:** a case that never meets ε returns the finest run as `unconverged` after four passes.
