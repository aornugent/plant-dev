# C. plant PLANT-106 to 110, and phylloptim PHYLLOPTIM-17 to 19

Read from `git log`/`git diff` on origin, the docs cited, and saved run data (no runs).
"Loop" means `harness/schedule/refine.R` plus `refine_case.R`. libS is the build the loop's
constants were measured on.

## Verdicts

| branch | +/− (commits) | new names | gain, measured | used by the loop | verdict |
|---|---|---|---|---|---|
| PLANT-106 | +442/−3 (5) | `control_window()`; `SCM$invaded`, `SCM$offspring_produced_at_ode_times`; `Species::offspring_production_per_fecundity` | none the loop draws on (below) | **no** | **DROP**; carry the getter into the group-2 port if that port wants T(t) from C++ |
| PLANT-107 | +57/−15 (1) | none | avoids the walk path (23% of a forward) when crowns cross; the sort costs nothing measurable | yes, in every birth-date field build | **KEEP** |
| PLANT-108 | +2031/−1927 (5); species.h +106/−53, references 1837 rows | `for_each_interval_crown`, `crowns_per_interval`, `for_each_crown_between_nodes`, `add_crown`, `crown` | the square law and an honest estimate from a coarser run; the bank's references rest on both | yes, every loop run (`node_density_in_birth_date`) | **KEEP**, unless the drop test below passes; fold its 3 renaming commits into the first |
| PLANT-109 | +118/−28 (3) | `NodeSchedule::add_entry`, `Patch::{set,get}_recorded_birth_dates` | none: the thinning it enables was measured and turned down | no; 110 does not use it | **DROP** |
| PLANT-110 | +422/−1 (6) | `diagnose_scm()` | the error estimate is superseded; the distance from the grid's run is the R6 report | no | **DROP from group 1**; rework its ~30 lines of distance and failures into group 2 (as `stack-split.md` already says) |
| PHYLLOPTIM-17 | +4138/−644 (10); #17 itself +98/−137 (2) | none (`collar_root_tol` and `tol` args removed) | replay noise in ln J 1.9e-8 → 8.5e-15 | yes (libS) | **KEEP**; see the caveats below |
| PHYLLOPTIM-18 | +108/−2 (1) | none | sweeps refused at 1e-4 on long drought and ld-105 now run | yes (libS) | **KEEP** |
| PHYLLOPTIM-19 | +232/−30 (1) | none | every long-drought record refused at 3e-4; a wrong row (0.053, against −0.83 by difference) | yes (libS) | **KEEP** |

## PLANT-106: the window's factors

- **Where the loop's weights came from.** `refine_case.R` reads `dev/window/rule_A/weight_<w>.rds`.
  These files were written on 2 Oct at 13:55 by `harness/window_rule.R` (commit fa9b114). That
  script applies rule A, 1/clamp(R/0.1, 0.01, 1), to a 54-node pilot at 1e-3. The pilot takes the
  union of the stand, lma×0.5 and lma×2 (`rule_A.log`). On long drought, dry and episodic the
  lma×2 walk raised, so those files hold the stand and lma×0.5 only. `control_window()` was first
  committed on 7 Oct (c6546c94). **So the loop's weights come from the earlier harness rule, not
  from `control_window()`.** The loop sets only PLANT-100's `ode_tol_factor_times/values`.
  `stack-split.md` says the loop "uses the window's factors (106)". That is wrong: the loop uses
  PLANT-100's fields.
- **The window values hardly matter.** `control_window()` and the harness differ by up to e^2.46 in
  episodic's factors. Even so, every entry stays within 0.004ε of the harness-weighted runs, and
  P1–P3 hold on all five records (`measurements/window-pilot/prereg.txt`, Results). The union adds
  little to the stand: on long drought the factor first exceeds 1 at t = 22.50, and the stand's
  share left falls to 0.1 at 22.60 (`rule_A.log`, `window_rule_A.log`).
- **The getter duplicates something the loop already has.** `stand_run(records = TRUE)` already
  computes the share left, `remaining`, from stored states. That is the quantity
  `offspring_produced_at_ode_times` computes in C++. The loop reads only t50 and t90 from it. W10
  ("read from the same pass's record, so no separate pilot", `design-schedule-building.md`) can be
  met in the loop with a few lines over that record. It needs no pilot, no walks and no
  `invaded` flag.
- **Keeping it makes the group-2 port harder:** a second, pilot-based way to set the same PLANT-100
  fields would sit beside the loop's own record.
- **Cost of dropping it:** no numerics change, because the branch adds names and returns read-only
  values. There is nothing to re-bless and no loop constant to re-measure. Conflicts are small:
  110's tests append after 106's in `test-support.R`, and species.h has nearby context.

## PLANT-107: the sort

- §16 (`grid-dynamics.md`) measured when crowns cross. Pairs swap height only at 429 uniform or
  494 graded introductions or more: on 20% of builds on long-wet and 79% on long drought. When
  they do, the pre-107 build walks every node at every height, which costs 23% of a forward.
  Sorting costs 0.114 against 0.113–0.117 ms per row.
- The loop's runs hold 127–434 nodes (`refine2/notes.md`, R20), packed into the first window. From
  level 1 on, the early spacing is finer than u429's. That crowns cross there is inferred, not
  measured.
- 108's crown prefix is built on this sort. If 108 is dropped, 107 still applies to the lumped
  field, which is the case it was written for. The sort changes bits only where crowns cross,
  through the order of summation.

## PLANT-108: the spread

The user suspects it is redundant. The evidence on each side:

**Against the spread (it buys no accuracy)**
- *Single runs are less accurate.* At u108 the largest error is 2.72ε spread against 0.70ε lumped
  on long drought, and 3.31ε against 1.29ε on long-wet (§16). At u215 it is 0.71 against 0.48
  (lumped/prereg.md, prior table).
- *On placed grids that reach ε it changes nothing.* On pA and pA2, lumped and spread agree within
  0.084ε at the same rows, and the pA→pA2 estimate reads 0.52 on both
  (`design-schedule-building.md`, "The crown spread (PLANT-108) can be deleted").
- *On graded nodes it does not help.* Companions read 0.65 with the spread against 0.71–0.80
  without (§16).
- *Cost.* It adds 2–6% to the sweep per row (§16) and 10.8% in one timing. On FF16's birth-date
  coordinate at its default schedule, the raw error is 9–25× lumped's (handover, item 6).
- *It gets in the way of higher-order sums.* Keeping it makes any higher-order sum over birth date
  harder (for example, the founders' Simpson rule, `synthesis.md`). The light no longer follows the
  node weights, so the rule has to be built twice, once in the weights and once as quadratic
  crowns (`summing/notes.md`, "Why the light does not follow the rule in libS").

**For the spread (it makes a run report its own error)**
- *Uniform ladders.* With the spread they follow the square law: ratios 3.78 and 3.92, none
  negative, companions 0.95 and 0.98. Lumped ratios run 6.6–8.5 with negatives, and the lumped
  108+215 extrapolation misses by 0.87–1.10ε (§16).
- *Root-law placed grids, long drought, p108→p215.* Recomputed here from
  `schedtest/lumped/errors_lumped.rds`: the invader's read is 1.06 with the spread (76% of
  quantities covered) against 0.30 lumped (0% covered). The resident's is 0.69 against 0.50.
- *The bank's references are uniform u215/u429 (u857) extrapolations* (`evaluate.R`
  `reference()`, `refine/lib.R` `ref_ladder`). Those extrapolations are honest only on the square
  law, which only the spread gives on uniform nodes. The edge-aligned ladders' honest estimates
  (ratios 3.7–4.2, `breakpoints.md`) and "order 2 for every quantity" (`error-structure.md` §1)
  were also all measured with the spread.
- *The stress test of the representation* (`schedtest/exact/prereg.md`, `logs/score.log`) put the
  exact integral of each interval's light in place of the eight crowns. The change moves each
  quantity by at most 0.081ε at u108, 0.007ε at u215 and 0.001ε at u429. Ratios (3.94 against
  3.93), companions (0.98 both) and cost (±2%) are unchanged. **So the eight crowns are a
  converged quadrature of the interval, and exact light buys nothing.** Lumped is the
  representation that differs: up to 0.96ε at d108 and 0.45ε at u215 (lumped_default/scores.md,
  lumped/score).
- **Net:** the 9–10 Oct "can be deleted" claim was made on grids where neither build had an
  honest estimate. The loop now stands on its estimate, and every measurement of an honest
  estimate used the spread.

**What dropping it would change for the loop**
- Every birth-date number moves, so every constant measured on libS has to be measured again on
  a lumped build:
  - r_min = 0.82, the lowest per-case median read on five cases (`review/profile.md`);
  - u_q's 0.22ε for short spells and the pair's 0.08ε for step changes (the 0.11ε tolerance
    bias probably carries over);
  - refine2's R20 outcomes.
- The spread-built references can stay, because both representations converge to the same
  limit.
- Which way r_min moves is unknown, because the two earlier measurements disagree. Graded nodes
  read 0.71–0.80 lumped against 0.65 spread; root-law placed nodes read 0.30–0.50 lumped against
  0.69–1.06 spread. Both are near or below 0.82. A lower r_min widens every bound and adds passes.
- **The drop test:** run round 5's five cases (run plus replay) and refine2's five loops on
  `PLANT-107` without 108. Drop the spread only if the per-case median read stays at 0.82 or above
  and coverage holds. This costs about 2× round 5's CPU.
- If it is dropped: revert the 1837-row `reference-gradient.tsv` re-bless and the FF16 guard's
  numbers, and no conflicts are expected (109 and 110 do not touch species.h).

## PLANT-109: invaders walked at a subset

- The user decided that the full walk stays (handover, row 137). The rules it enables were
  measured: rule b moves `recruitment_decay` by 0.74ε, and the shared thinned schedule misses one
  entry by 0.43ε on long drought.
- The loop runs no invaders. `diagnose_scm` walks each run's full introductions.
- A full walk has the run's node count, so the old positional match of splits to nodes gives the
  same blocks. Dropping the branch changes no number.
- **Keeping it makes the walk harder:** it adds state (`recorded_birth_dates`, copied through
  `rebind_from`), a lookup that matches doubles exactly, and empty schedule entries, all for a
  feature that was turned down.
- Re-add it if the "shared thinned schedule" (handover: "promising") is built.

## PLANT-110: `diagnose_scm`

- **Superseded by the loop:**
  - the node error from separate runs at every other and every fourth introduction. Those runs
    each choose their own steps, which mixes time error into node error, and cost about 0.75 of a
    run. The loop's pinned replay costs 0.51–0.66 of a run, and its doubled pair needs no extra
    run (`design-refine-schedule.md`, steps 3–5);
  - the `ratio` check;
  - the rule that a use takes the grid's error while within the distance. Under the loop, each use
    reports its own replay estimate (*Then fix the schedule*).
- **Survives:**
  - the distance from the grid's run, |ln J − ln J₀| against d* = 0.5. d* is calibrated on a09
    (transferred at 0.19, misread at 0.73–1.11; `design-grid-controller.md`, item 8);
  - each invader's ln(θ′/θ);
  - failures returned as rows.

  OBJECTIVES asks for the distance in θ against the grid's radius. The ln J form is a stand-in
  until the radius is measured.
- None of it affects numerics, and nothing above 110 depends on it.

## phylloptim

- **PHYLLOPTIM-17 is two PRs in one.** Its base is 8 commits of `ad/reverse-mode`'s 0.9.0
  (+4040/−507) that are not on `master`. Issue #17 proper is 6b6f152 and 300d229.
  - 6b6f152 stops every root-find at roundoff: a replay's noise in ln J goes from 1.9e-8 to
    8.5e-15 (commit message; handover 3.2). Pinned replays and the loop's replay estimate depend
    on that.
  - 300d229 fixes a check that could never fire. No run changes.
  - Cut `tests/cpp/probe_preaccumulation.cpp` and `probe_tape_regions.cpp` (563 lines, not in
    `all`, added in base commit fd8d1fa). They are investigation probes, not tests.
- **18 and 19 fix refusals** that the derivative path raised where the forward answers
  (`error-modes.md` F; table rows a04_proxy, c05, a09). They also fix one wrong row. The loop runs
  at 1e-4 on long drought, where 18's case occurs. All three branches are in libS: dropping any of
  them changes the loop's numerics or brings its refusals back.
- **A pin mismatch to fix:** at PLANT-110, plant's DESCRIPTION says `phylloptim (== 0.9.1)`
  (LinkingTo and Remotes). libS was built with a local edit to `== 0.9.3` (`summing/notes.md`,
  Step 0). The pin to 0.9.3 belongs in the plant branch that group 2 stacks on. Without it, the
  stack as pushed builds a library that is not libS.
