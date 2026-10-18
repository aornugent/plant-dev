# What we built since develop, split into two PR groups

Surveyed on origin (aornugent forks), 2026-10-18. The plant stack is one chain of 64 commits over
`develop` (95256cf3), PLANT-93 → PLANT-110, each branch on the one before; odelia's ODELIA-53 →
55 is 31 commits over `master`; phylloptim's PHYLLOPTIM-17 → 19 is 9 commits over `master`. Open
PRs today: only plant#94 (PLANT-93 → develop). The refine loop's evidence ran on libS: the chain
through PLANT-110, PHYLLOPTIM-19 (0.9.3) and the rain substeps now in PLANT-105.

## Group 1: plant optimisations (and the odelia and phylloptim work they need)

Each stays one PR per issue, stacked in the order below. Nothing here knows about node schedules
beyond representing them.

| branch | what it does |
|---|---|
| phylloptim PHYLLOPTIM-17, 18, 19 | root-finds stop at roundoff; a bisection that spends its budget is refused; the root curve and a determined collar are differentiated (0.9.0 → 0.9.3) |
| odelia ODELIA-53, 54, 55 | runs at the caller's scalar and their recording; walks of recorded rows; per-component tolerance factors; splits at sign changes, forward and sweep; a subsystem stepped alone, with substeps at its forcing's knots (0.5.0) |
| PLANT-93 | establishment integrated exactly on the birth-date coordinate (plant#94) |
| PLANT-95 | the model at the caller's scalar; the stand's census gradient by trait; offspring-production sweeps; invaders in the recorded field; pinned replays of a run's rows |
| PLANT-97, 98 | the storage pool: relaxation time and stage guard |
| PLANT-99 | walk a recorded run without repeating it |
| PLANT-100 | tolerance factors for soil, accumulators and a schedule, with a bound; the newborn's height to roundoff |
| PLANT-101 | the field built without the newborn's rates |
| PLANT-102, 103 | each node's step split where net production changes sign; its sweep |
| PLANT-104 | `control_tf24()`, TF24's step control in one preset |
| PLANT-105 | TF24's soil stepped alone where the plants draw little of its water; substeps at the rain's knots |
| PLANT-106 | the window's tolerance factors from a pilot run and its invaders' walks (`control_window()`) |
| PLANT-107 | crossed crowns summed tallest first |
| PLANT-108 | each birth-date interval's leaf area spread between its nodes (re-blesses the references) |
| PLANT-109 | invaders walked at a subset of the run's introductions |

## Group 2: the scheduling algorithm

One PR (or two, stacked) on top of PLANT-109:

- **Port `refine_schedule` into plant**, from `harness/schedule/refine.R`:
  - the first run's establishment rate and T(t) become records of the run itself, instead of being
    decoded from stored states;
  - `stand_run`, the schedule functions and the loop become plant R functions with tests;
  - the C++ `SCM::refine_schedule` and the `run_scm(refine_schedule =)` argument are replaced;
    logpile's `refine_schedule` key changes with it (its request fingerprints change).
- **PLANT-110's diagnostics** (`diagnose_scm`):
  - its node-error estimate from runs at every other and every fourth introduction is superseded
    by the loop's replay and doubled-pair estimates;
  - its distance from the run that built the grid is the design's R6 diagnostic.
  - So PLANT-110 moves out of group 1 and is reworked into this PR.

## Not in either group

- **PLANT-96** ("land on a pulse of nothing"): a side branch off PLANT-95, not in the chain.
- **The averaged establishment gate** (b3a33626, 6613dd24, the current plant-dev submodule
  pointer): an experiment off the chain.
- **The many `ad/*`, `feat/*` and `fix/*` branches and their open PRs** on the three forks: older
  work, untouched.

## Dependencies that fix the order

- The loop's constants (r_min 0.82, u_q) were measured on libS. That library includes PLANT-108's
  spread, PLANT-105's soil substeps and PHYLLOPTIM-19, so group 2 sits on group 1, not beside it.
- The loop's run setting uses group 1's controls: tolerance factors and their bound (PLANT-100),
  splits (102), the soil alone (105) and the window's factors (106). It also uses PLANT-95's
  pinned replays and gradients, and PLANT-93's exact counts.
