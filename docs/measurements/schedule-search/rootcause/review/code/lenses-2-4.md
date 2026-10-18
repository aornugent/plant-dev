# Lenses 2–4 on the built loop (coordinator's pass)

Read by the author of the code, so this pass is not cold; Lens 1 is a separate agent.
Ledger: `docs/design-refine-schedule.md` (R1–R6, the algorithm, "What a strategy supplies",
"What survives deletion") and AGENTS.md's code rules.

## Lens 2: decisions reopened

- **D1. Doubling every count on a reject, the rejected run as the estimate, over √ rescaling with
  a replay each pass.** Settled by R5 and G6: a 1.5× run that is not nested needs its own replay,
  ≈ 2.4 against 2.0 run units (R20).
- **D2. Spell ends read once from the first run, over re-reading them each pass.** Settled: nesting
  needs fixed breakpoints, and level 1's own ends sat within 2.5 d of them (R21).
- **D3. A new runner `refine_run.R`, over extending `harness/run_record.R`.** run_record.R is the
  repository's one-run script: TIMES, FORWARD, WEIGHT*, HMAX, SPLIT, SHARE, TRAIT_REL and a
  `creation_record` that refine_run.R copies line for line. It lacks PIN and always passes the
  rain's knots as pulses (task: move the harness to libS without them). UNSETTLED → Q1, default:
  add PIN, the remaining-share record and the libS events to run_record.R and delete
  refine_run.R (AGENTS: no parallel near-copy).
- **D4. TF24's facts written into refine.R, over one place a strategy supplies them.** The design
  lists what a strategy supplies (breakpoints from a run's record, its grading, its ε table, its
  u_q). The code holds them in six places: `grade`, `reserve_time`, `spacing_of`'s nine numbers,
  `READ`/`UNSEEN_*`, `eps_of` (reads eps.csv's resident rows), and `quantities`' excluded traits.
  Not settled by a ledger line for TF24 alone; settled against the design's own "What a strategy
  supplies" → structural finding S2.
- **D5. `eps_of` and `quantities` copied from `harness/schedule/evaluate.R`, over sourcing them.**
  evaluate.R sources the lattice and the stored-run apparatus, so sourcing it drags that in.
  UNSETTLED → Q2, default: move the two functions into a small file both source.

## Lens 3: change simulation

1. **The port into plant (planned: "It replaces, in one change ... in plant").**
   - Pure functions over a run's records (`spells_of`, `spacing_of`, `schedule_of`, `nodes_of`,
     the loop's arithmetic) carry over unchanged if plant returns the same records.
   - The records are the leak: `refine_run.R` rebuilds the establishment rate and T(t) by
     decoding `store_trajectory()` rows with hand-computed state offsets (`per`, `held`,
     `at_e`, `at_o`). In plant these must be native records of the run, or every change to the
     node state layout breaks them silently.
   - The run boundary (Rscript + env vars + files) disappears; resumability by file name goes
     with it.
   - Classification: leaky (the state-layout decoding must be known about).
2. **Another strategy (design: FF16, K93, TF24f keep working).** Edit sites: `grade` and
   `reserve_time` (TF24 storage parameters), `spacing_of` (offspring-curve constants tuned on
   TF24), `UNSEEN_*` and `READ` (measured on TF24), `eps_of` (resident TF24 rows of eps.csv),
   `quantities`' exclusions, `SETTING` (TF24's soil weights and share), and `refine_run.R`'s
   TF24 strategy and soil controls. Eight sites that must agree: shotgun.

## Lens 4: what must always be true

Every estimate is a difference between nested schedules: the replay's nodes are a subset of its
run's, and each level's nodes contain the level below's.

Kept true by: convention. `nodes_of` derives every level from the same panels by equal shares, so
nesting holds by arithmetic, and `round(S, 10)` hides last-bit differences between
`seq(0, 1, length.out = n + 1)` and `seq(0, 1, length.out = 2n + 1)`. Nothing checks it at
runtime; a collapse under rounding or an `approx` tie would make a level drop a node of the one
below, and the estimate would then include a schedule change it does not model. Structural
option: build level k + 1 as level k's nodes plus each interval's mass midpoint, or assert the
subset where each run is launched (one `stopifnot` per run).
