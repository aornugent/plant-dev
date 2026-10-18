# Brief for the three investigations (epi-adG208's under-read, the slowdown, the frontier)

The user's principles apply (Laziness Protocol, Subtract Before You Add, Minimize Reader Load,
Foundational Thinking, Model the Domain), and so does AGENTS.md's code style. The goal is
OBJECTIVES.md. Pre-register predictions before each run, in your notes file, as the earlier
rounds did (`rootcause/refine2/notes.md`, `rootcause/evidence/notes.md`). The systematic-debugging
skill is `.claude/skills/systematic-debugging/SKILL.md`.

## The algorithm and its state
- Design: docs/design-refine-schedule.md. Code: harness/schedule/refine.R (`refine_schedule`,
  `stand_run` in memory), harness/schedule/quantities.R, harness/schedule/refine_case.R (the five
  cases' control and driver: `PLANT_LIB=<lib> Rscript harness/schedule/refine_case.R CASE OUT [SCALE]`).
- Evidence so far: rootcause/refine2/notes.md (R20 half-scale loops, R21 epi-adG208's under-read and
  the three refuted hypotheses, R22 the canonical scale-1 loops on libS), rootcause/review/profile.md
  (where a run's time goes: sweep 66–71% of a run, 75–77% of a replay), rootcause/evidence/notes.md
  (rounds 1–5).
- Scoring against references: rootcause/refine2/score_s1.R (uses refine/lib.R's ref_ladder, Q, EPS).

## Libraries
- libS (the build every measurement so far used, with the spread):
  /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/libS
- libNS (the new baseline: the same stack WITHOUT the spread, PLANT-108 reverted; the user decided to
  drop it): /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ns/libNS.
  It is ready when ns/install.log ends with "exit 0". Source: scratchpad/dev/ns/plant (branch no-spread).
- The coordinator is re-running the five canonical loops on libNS (fits in
  scratchpad/refine/ns/<case>.rds) to re-measure the bound's constants; use those fits rather than
  repeating them.
- Measure on libNS unless a comparison with round 5 needs libS.

## Shared machine
Four cores. The coordinator uses two for the canonical loops; each investigation runs at most ONE
SCM process at a time. CPU times under load: compare A against B interleaved under the same load,
and report how they were taken. Saved round 5 and half-scale runs, with full run files:
scratchpad/deep/rootcause/evidence/r5/runs and scratchpad/refine/s05/<case>/. Do not commit, push
or edit harness/schedule/*.R; prototype in your own scratch directory and report the diffs you
recommend.
