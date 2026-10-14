# U: a use's distance from its grid (round 4)

Builds item 8's *A use's distance from its grid* (`docs/design-grid-controller.md`) on
plant's `PLANT-110`, from F's finding that θ₀'s check transfers at d = 0.19 and misreads
at 0.73–1.11 (`../F/notes.md`). Worktree `scratchpad/dev/schedtest/U_src/plant`, library
`scratchpad/dev/schedtest/libU` (libS: odelia `ODELIA-55` cb4d262, phylloptim 0.9.3).

## Design (system-design, Tier 2, lean)

**Triage: 2.** A new argument and return field on an exported function regnans calls;
reversible while the stack is unmerged.

**Ledger**
- R1: a use (a run at θ replaying θ₀'s committed schedule) reports d = |ln J(θ) − ln J(θ₀)|
  and whether d ≤ d*, d* = 0.5 for now (F: holds at 0.19, misreads at 0.73–1.11).
- R2: ln J(θ₀) and its error estimate come from the run that built the grid, one source.
- R3: the use replays the grid exactly: at θ = θ₀ it repeats the grid's run bit for bit.
- R4: only doubles cross the R boundary.
- R5 (R8): every run, a use too, reports its error estimate, its distance and its failures
  as rows, never a throw.
- R6: a use costs one run (+ its walks and sweeps), not the find's three (the coarser two
  cost ~0.75 of the run again); T = T_find + 2 T_use counts on it.

Scarce resource: names a regnans caller must learn; the runtime constraint is R6.

**What "the grid" is today.** `Parameters` carrying `node_schedule_times` with
`ode_times`, `ode_step_sizes`, `ode_soil_input_slopes`, `ode_soil_substep_ends`: `run_scm`
replays such parameters exactly (`test-scm.R`, "a replay of the program ... repeats the run
bit for bit", including at another `lma`). `diagnose_scm()` (PLANT-110) ran the stand
freely and discarded the run, so it built no grid a use could replay, and ln J(θ₀) with its
`error` lived only in its `quantities`.

**Floor:** no plant code; regnans subtracts `log(sum(use$offspring_production))` from the
find's `quantities`. Fails R3 (diagnose_scm returns no schedule to replay) and R5 (a use
run by hand throws, and reports no walks or error).

**Candidates**
- A [first thought] (extend the existing function): `diagnose_scm(..., grid = NULL,
  distance_limit = 0.5)`; a find returns `parameters` (p with its run's schedule); a use
  is the same call given the find's diagnosis, runs once on its schedule and returns a
  `grid_distance` row. Pays R1–R6 through the existing run/walk/sweep/failure code. New
  names: `grid`, `distance_limit`, `grid_distance`, `parameters`. Wins when uses are
  diagnosed like finds, which R8 asks.
- B (separate verb): `diagnose_use(p, grid, ...)`. Either a near-copy of diagnose_scm's
  run/walk/sweep/failure machinery (AGENTS.md: never) or a factored core plus two
  wrappers; +1 exported name over A for the same rows. Wins if a use's report diverged
  from a find's; nothing in the ledger says it does.
- C (move the state): carry ln J(θ₀) and its error in `Parameters` (C++ fields) beside
  the schedule, so the grid is one object. A second copy of the find's `quantities`
  (R2 fails), stored derived state, and a C++/RcppR6 change for two doubles. Wins if
  grids are saved and reloaded apart from their diagnosis; no such consumer today.

Winner A. B costs a name or a copy for nothing R1–R6 asks; C breaks R2.

**Commitment:** a grid is a find's diagnosis: its `parameters` hold the schedule a use
replays and its `quantities` hold ln J(θ₀) and its error, and a use reads both from it.
Kept true by: `grid` takes the whole diagnosis (no argument takes ln J(θ₀) on its own),
and a use returns `parameters = NULL`, so a use cannot serve as a grid and be measured
against itself (`diagnose_scm()` refuses it).

**Kill question:** would regnans rather hold the schedule itself and only ask plant for
ln J? Then `grid` would be `Parameters` and ln J(θ₀) a second argument (R2 fails). Survives.

**Deletion pass:** `grid` (R3), `distance_limit` (R1, "for now" means it moves),
`grid_distance$within` (R1 asks plant to report it), `$value`/`$error` (R2: the use
carries them), `parameters` (R3: no grid without it). A `limit` column was dropped: the
caller passed it.

**What this makes hard:** a use's per-quantity errors. A use reports the grid's error of
ln J only; carrying each elasticity's error across would need the use's invaders matched
to the grid's, which change with the resident. Cope: read the find's `quantities` while
`within`.

**Kill condition:** a measured radius per quantity (R6) rather than one d* on ln J; then
`grid_distance` grows per-quantity rows, still in this one place.

## Built

(see below)
