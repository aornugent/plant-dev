# Round 4: open discovery (14 October)

You have room to find what nobody asked for. The lead has run three rounds of designs
proposed from the top; this round is yours to choose. Question what we hold true, mine
the data we already have, and look for inversions and positive-sum drops: something we
pay for that buys nothing, or one change that pays twice.

The last finding shows why. Long drought ran in a legacy setting (no soil substeps, no
splits) that every other record had dropped. Turning them on cured a silent gradient
blow-up **and** halved long drought's runtime, which cut T by 20% over the ten cases.
Nobody had looked, because the setting was inherited.

## The goal

Plant TF24's schedule-building algorithm: the node birth dates (introductions) and the
ODE controller, chosen so that reverse mode gives stable `ln J` and elasticities for
residents and invaders on any rainfall record. Read `/home/user/plant-dev/OBJECTIVES.md`
(accuracy ε per quantity; reproducible, continuous, predictable, never fails; shared
grid; performant at matched error; diagnosed). The measure here is
T = T_find + 2·T_use in CPU s (the committed schedule's run is used three times: find
plus two uses), subject to passing C1–C5 on every case:
C1 every |error| ≤ ε; C2 every error over ε/2 has |estimate| over ε/4; C3 80% of
quantities over ε/3 read within ×2 with the right sign; C5 every |estimate| ≤ ε.

## Where things stand (real runs, ten cases: five training, five held-out)

- Incumbent **a09** (`any/a09_late.R`, described in `round3/CONTEXT.md`): pilot →
  graded spacing with edges as nodes → check by ratio 1.6 plus bisection fill → estimate
  move/(1 − s) → commit coarse unless an estimate exceeds ε; no edges after b = 25;
  tolerance 1e-4. **T 5609 training, 12916 all ten, 10/10 pass** (long drought now in the
  proper setting).
- **a10** (a09 + short shut gaps merged after b = 10 in the committed run only):
  5385 / 12277, 10/10 (−4 to −5%).
- **a11** (check refined before 25 only): about −1%. **3e-4 tolerance**: about −10%, 9/10
  in the legacy setting (ld-102 failed C3 on unevenly shared tolerance error); being
  rerun in the proper setting now.
- The full record of rounds 1–3: `localised.md` (bottom sections are newest),
  `loc/prereg.md` (every prediction and result), `round3/{A,B,C,D}` (agents' work),
  `round3/D/notes.md` (the gradient blow-up's root cause: stiff top soil under explicit
  steps during heavy rain; cured by the soil's own substeps).
- Design docs: `docs/design-schedule-building.md`, `docs/map-schedule-building.md`
  (the levels L4 analysis → L0 rate evaluation), `docs/geometry.md`,
  `docs/grid-dynamics.md`, `docs/design-grid-controller.md`.

## Assumptions we have held (a starting list, not a boundary)

1. A schedule is built once per θ and used unchanged; the error estimate comes from a
   second, finer **full gradient run** (the check costs 1.3–1.5 committed runs).
2. The pilot is a separate, discarded run.
3. Every edge (where establishment opens or shuts) is a node; edges are 53–88% of nodes.
4. Error is estimated by comparing two schedules (Richardson-like), never from inside
   one run (e.g. the ODE's own error estimates, adjoint-weighted residuals, the two
   halves of a run, symmetry across seeds).
5. Every quantity must meet its ε, and all quantities share one schedule.
6. One tolerance for the whole run, shaped only by the window weight; 1e-4 is about right.
7. The run settings (WEIGHT_SOIL=10, WEIGHT_MAX=100, HMAX=15, ATOL=1e-4, SHARE=0.1,
   splits, the rule-A window weight) are right because they were tuned once.
8. The committed answer is the coarse run's raw value (not extrapolated or blended).
9. T counts CPU by a rows model (`run_cost`); real CPU is what matters.
10. Birth dates on the birth-date coordinate, nodes chosen per case; invaders walk the
    resident's grid.
11. The check must shrink every error-carrying interval by about one factor.
12. Long-drought-type records are the hard case; wet records are easy.

Drop any of these, invert them, or find one we never wrote down.

## The data you can mine

- `RUNS=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/`
  (639 runs). Each `readRDS` gives `$node_times`, `$stand$J`, `$stand$gradient`,
  `$stand$elasticity`, `$stand$times` (accepted step times), `$stand$sizes`,
  `$stand$splits`, `$stand$rows`, `$stand$cpu`, `$stand$nodes` (per-node data). Names:
  `val_<alg>_<c|f>_<case>` (committed/check runs), `ref_*` (references), `probe_*`,
  `loc_G*` (adjoint maps via `adjmap/lib.R`'s `run()`), `lat_*` (lattice runs).
- `.../scratchpad/dev/schedtest/placed2/runs/` (297 runs: pilots, lattice library),
  `.../node_rule/ladder/runs/`, `.../pf_nodes/runs/`.
- Schedules: `.../schedtest/loc/` (`loc_<alg>_<c|f>_<case>.rds`).
- Scorer: `harness/schedule/score_any.R ALG.R` scores an algorithm on the five training
  cases in seconds from a model of error (`anyscore.R`: `quantities()`, `eps_vec()`,
  `reference()`, `run_cost()`, `pilot_edges()`, `case_of()`); `STRESS=5` while
  exploring. Its blind spot: it models each elasticity's error per time band, so it
  cannot see sign-mixed error inside a band (agent C, round 3).
- Real-run scoring: `docs/measurements/schedule-search/loc/val.R TAG CASE...`
  (`ALG=../any/a09_late.R R=1.6 BG=90`; set `ALG` to your algorithm file for its shrink).

## Real runs

`/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/one.sh NAME REGIME VAR=value ...`
runs `adj_run.R` (read its header for env: TIMES, TOL, SPLIT, SHARE, WEIGHT, SEED,
TRAIT_REL, LIB, PIN, FORWARD, MODE, ...). one.sh defaults to the proper setting
(SHARE=0.1, SPLIT=1, TOL=3e-5): keep it, pass `LIB=.../schedtest/adjmap/lib19`, and copy
a case's exact line from `loc/jobs_a09.txt` (drop its `SHARE= SPLIT=0` for long-drought
records). A gradient run takes 1–3 min CPU. It skips a NAME already done, so prefix
yours with your letter (`E_`, `F_`, `G_`). Budget: **at most 10 real runs each, one at a
time**; the machine has 4 cores shared with the lead's runs and the other agents.

## Rules

- Pre-register each prediction (a line in your notes) before you run or score it.
- Scripts and notes in `docs/measurements/schedule-search/round4/<your letter>/`; run
  outputs under `.../scratchpad/dev/schedtest/<your letter>_out/`, never in the repo.
  Do not commit or push; the lead will.
- Do not change library code. If you find a defect, report it with evidence; if a fix
  is small, describe it.
- Report: what you looked at and why, what surprised you, what you tried with the
  numbers, what failed, and the one or two findings worth acting on, with the predicted
  effect on T and on the objectives, and the risk.
