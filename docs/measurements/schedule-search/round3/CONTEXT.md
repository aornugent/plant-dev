# Round 3: what is known now (13 October)

Read `harness/schedule/BRIEF.md` and `BRIEF_ANY.md` first for the mechanisms and the
scorer; `docs/measurements/schedule-search/localised.md` holds every result below; the
objectives are `OBJECTIVES.md`. This file adds what the last day of real runs settled.

## The goal and the cost

T = T_find + 2·T_use in CPU s. An algorithm commits a schedule and an error estimate
for every quantity (ln J and the elasticities); it passes a case when C1 every
|error| ≤ ε; C2 every error over ε/2 has |estimate| over ε/4; C3 80% of quantities over
ε/3 are read within ×2 with the right sign; C5 every |estimate| ≤ ε.
`score_any.R ALG.R` scores any algorithm on the five training cases (seconds, no
simulation); `docs/measurements/schedule-search/loc/val.R` scores real runs.

## The incumbent: a09 (`docs/measurements/schedule-search/any/a09_late.R`)

Real runs at tolerance 1e-4, ten cases (five training, five held-out): ten of ten pass,
every median estimate/error 0.87–1.17. T 6699 on the training five (a04_proxy scored
8384 at 3e-5; c05_graded 9572 real). Its parts:
1. From the pilot: edges, b1, a spacing graded by the pilot's offspring (founders' layer
   b1/24, rest of the window b1/12, background 90 d widening where offspring is low).
2. The check refines that spacing by R = 1.6, and also bisects each interval wider than
   half its target that lies in a gap the ratio gives no new node. Estimate move/(1 − s),
   s the pilot proxy's shrink (offspring^0.6 · h³).
3. Both runs leave out every edge after b = 25.
4. Commit the coarse run if every estimate is under ε, else the check run.

Where T goes: the committed schedule, run three times (find plus two uses), is 66–70% of
T; the check 30–34%. The check costs 1.30–1.53 committed runs.

## Settled since BRIEF_ANY

- **A non-nested check is honest only where it shrinks every interval that carries
  error by about the same factor.** a04 (ratio check only) failed dry without season:
  312 edges leave most gaps too short for a 1.6 ratio to refine, so the background
  shrank 0.53–0.59 against the founders' 0.41, and the proxy put 85% of the error
  before b1 where a four-run fit puts ~25%. Some quantities carry opposite-sign error in
  regions that shrink differently; no single s reads them. a05 (the bisection fill)
  fixed it.
- **Edges are 53–88% of committed nodes.** Edges after 25 can go (moves ≤ 0.08ε).
  Spanning shut gaps under 10 d with one interval (a spell keeps its start edge) costs
  ≤ 0.10ε for 11–24% of rows, but a check built across merged spans refines less of
  some quantities' error than its spacing says (long drought read 0.65; dry's root_P50
  0.3), so a07 (merging + a05) passes ten of ten only with thin margin (T 6216 training)
  and a08 fails one. The merge's own error is small; the check's honesty is what breaks.
- **Error per interval rises toward each open spell's closing edge** (0.5–0.9 of median
  in a spell's first quarter, 1.1–2.7 in its second half; all five training cases).
- **Tolerance 3e-4 is reopened:** the probe that ruled it out failed on a phylloptim
  refusal fixed today, not on accuracy. CPU 0.73–0.78 of 3e-5 (1e-4: 0.84–0.88); its
  largest move on dry 0.32ε, which a node-only check cannot see. a09 at 3e-4 is running.
- **A floor:** the committed answer is close to the scorer's range (intervals ≤ 100 d
  before 20, b1/12 in the founders' window, 280 d after 20; edges as nodes); widest-legal
  schedules are only 4–7% cheaper and err 0.94–2.42ε.

## Rules for this round

- Work on the scorer and on saved runs: real runs are queued by the lead, not by you.
  Saved runs: `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/
  scratchpad/dev/schedtest/adjmap/runs/` (`val_<tag>_<c|f>_<case>.rds`, map runs
  `loc_G*`/`G0` via `adjmap/lib.R`'s `run()`), schedules in `schedtest/loc/`.
- Keep the machine light: three real runs are using three of four cores. Run R one
  process at a time, `STRESS=5` on the scorer while exploring.
- Pre-register each prediction (a line in your report) before you score it.
- Put scripts in `docs/measurements/schedule-search/round3/<your-letter>/`. Do not
  commit or push; the lead will.
- Report: what you tried, the numbers, what failed and why, and the one or two designs
  you would spend real runs on, with the predicted T and the risk.
