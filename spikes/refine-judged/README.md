# The refine loop under two judged sets

What `refine_schedule` (`harness/schedule/refine.R`) costs when it judges {ln J, g} instead of
{ln J, ~46 resident elasticities}. Only the judged set changes: schedule, replay, stop rule,
constants (0.5, u_q 0.22/0.08, 0.9, four passes, level ≤ 4) are as built.

## Stack and setup

- odelia 0.9.0 `8b7b934`, phylloptim 0.11.0 `ef75769`, plant `ODELIA-66` `00cf3a99`
  (2.0.0.9002), built -O2 into a private library (`build.sh`).
- Cases dry, episodic-lma, epi-adG208, long-wet (`validation.md`), at refine_case.R's setting
  (1e-4, the record's weights, soil factor 10, 15-day cap).
- g is the invader's elasticity d ln R'/d ln θ' at θ' = θ: `run_mutant(p)` on the run's own
  recording, then the reverse sweep of `1.offspring_production`. Its coarse value comes from
  the same walk and sweep on the level-0 replay (or the rejected run of a doubled pair), as
  `refine.md` § Next describes. ε for g is eps.csv's invader rows (floor 0.01). All 46 traits
  are judged; `birth_rate` (a new column on this stack), `S_D`, `a_f3`, `recruitment_decay`,
  `rooting_depth_max` are left out, as for the elasticities.
- The balance F = ln J − ln b: b is an input here (birth_rate 1, no balancing), so F's error
  is ln J's error. It is judged as ln J.
- References: the held-out recipe, u429 + (u429 − u215)/3 at 3e-5, every quantity. Their own
  move, the worst per group in ε: dry 0.02/0.11/0.09 (ln J/elasticities/g), epi-adG208
  0.06/0.15/0.06, episodic-lma 0.03/0.26/0.13, long-wet 0.02/0.05/0.07. Errors under ~0.2ε are
  at the reference's floor. True errors include the 1e-4 tolerance's own error.
- Every run takes the forward, the resident sweep, and the invader walk and sweep, each timed
  apart. Each set's loop is replayed from one cache of runs by level, charged only what it
  needs (A: forward + sweep; B: forward + walk + walk sweep; both: the first run). Runs are
  deterministic, so a level both sets visit is one run. CPU is per process on a shared
  16-core machine (load 7–10).

## Adaptations to the stack

- `record_trajectory`/`store_trajectory()` are `keep_states`/`store_recording()`.
- The fitness metric is `1.offspring_production`; `census_trait_names_tf24` now includes
  `1.birth_rate`.
- **The harness's replay breaks on this stack.** `refine.R` builds the SCM with
  `events(events_default(p))`; given events, `make_node_schedule` installs `p$ode_times` as a
  grid and drops the recorded sizes and substeps (`scm_utils.h`), so the replay throws "would
  substep the System's subsystem, which a grid of times cannot" at the first substepped step.
  The driver passes `events()` (empty), which takes the parameters path and keeps them.
  `harness/schedule/refine.R` needs the same one-line change.

## Results

Scale 1 is the canonical setting; 0.5 and 0.25 shrink every density to see where each judged
set would let the schedule go coarser. Errors are the worst true error of the corrected answer
Q − e against the reference, in ε; "uncovered" counts quantities whose true error exceeds their
bound 0.5|e| + u_q (judged or not).

| case | scale | set | status | level | passes | nodes | runs | CPU min | wall min | lnJ err | elast. err | g err | uncovered (elast./g) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dry | 1 | lnJ+elast. | converged | 0 | 1 | 230 | 3 | 9.3 | 9.5 | 0.01 | 0.13 | 0.04 | 0 / 0 |
| dry | 1 | lnJ+g | converged | 0 | 1 | 230 | 3 | 11.5 | 11.6 | 0.01 | 0.13 | 0.04 | 0 / 0 |
| dry | 0.5 | lnJ+elast. | converged | 0 | 1 | 167 | 3 | 7.7 | 7.8 | 0.17 | 1.22 | 0.29 | 11 / 1 |
| dry | 0.5 | lnJ+g | converged | 0 | 1 | 167 | 3 | 9.0 | 9.1 | 0.17 | 1.22 | 0.29 | 11 / 1 |
| dry | 0.25 | lnJ+elast. | converged | 0 | 1 | 111 | 3 | 5.0 | 5.1 | 4.79 | 11.01 | 2.74 | 38 / 40 |
| dry | 0.25 | lnJ+g | converged | 0 | 1 | 111 | 3 | 5.6 | 5.8 | 4.79 | 11.01 | 2.74 | 38 / 40 |
| episodic-lma | 1 | lnJ+elast. | converged | 0 | 1 | 207 | 3 | 7.2 | 7.3 | 0.03 | 0.21 | 0.08 | 0 / 0 |
| episodic-lma | 1 | lnJ+g | converged | 0 | 1 | 207 | 3 | 8.7 | 8.8 | 0.03 | 0.21 | 0.08 | 0 / 0 |
| episodic-lma | 0.5 | lnJ+elast. | converged | 0 | 1 | 129 | 3 | 5.3 | 5.4 | 0.18 | 0.47 | 0.28 | 1 / 0 |
| episodic-lma | 0.5 | lnJ+g | converged | 0 | 1 | 129 | 3 | 6.1 | 6.2 | 0.18 | 0.47 | 0.28 | 1 / 0 |
| episodic-lma | 0.25 | lnJ+elast. | converged | 0 | 1 | 85 | 3 | 3.4 | 3.5 | 0.97 | 2.48 | 1.52 | 38 / 22 |
| episodic-lma | 0.25 | lnJ+g | converged | 1 | 2 | 144 | 4 | 7.0 | 7.1 | 0.06 | 0.24 | 0.15 | 2 / 0 |
| epi-adG208 | 1 | lnJ+elast. | converged | 0 | 1 | 194 | 3 | 7.7 | 7.8 | 0.03 | 0.35 | 0.09 | 0 / 0 |
| epi-adG208 | 1 | lnJ+g | converged | 0 | 1 | 194 | 3 | 9.2 | 9.3 | 0.03 | 0.35 | 0.09 | 0 / 0 |
| epi-adG208 | 0.5 | lnJ+elast. | converged | 0 | 1 | 131 | 3 | 5.9 | 6.0 | 0.22 | 0.97 | 0.18 | 4 / 0 |
| epi-adG208 | 0.5 | lnJ+g | converged | 0 | 1 | 131 | 3 | 6.5 | 6.6 | 0.22 | 0.97 | 0.18 | 4 / 0 |
| epi-adG208 | 0.25 | lnJ+elast. | converged | 1 | 2 | 148 | 4 | 6.9 | 7.0 | 0.05 | 0.77 | 0.26 | 22 / 1 |
| epi-adG208 | 0.25 | lnJ+g | converged | 0 | 1 | 89 | 3 | 4.7 | 4.8 | 1.71 | 3.16 | 1.30 | 23 / 32 |
| long-wet | 1 | lnJ+elast. | converged | 0 | 1 | 223 | 3 | 12.6 | 12.7 | 0.00 | 0.09 | 0.10 | 0 / 0 |
| long-wet | 1 | lnJ+g | converged | 0 | 1 | 223 | 3 | 16.2 | 16.3 | 0.00 | 0.09 | 0.10 | 0 / 0 |
| long-wet | 0.5 | lnJ+elast. | converged | 0 | 1 | 152 | 3 | 9.3 | 9.4 | 0.09 | 0.36 | 2.19 | 0 / 26 |
| long-wet | 0.5 | lnJ+g | converged | 1 | 2 | 257 | 4 | 19.0 | 19.1 | 0.01 | 0.13 | 0.12 | 0 / 0 |
| long-wet | 0.25 | lnJ+elast. | converged | 0 | 1 | 113 | 3 | 7.3 | 7.4 | 0.81 | 1.67 | 7.47 | 18 / 32 |
| long-wet | 0.25 | lnJ+g | converged | 2 | 2 | 311 | 4 | 18.9 | 19.0 | 0.00 | 0.07 | 0.21 | 0 / 0 |

"runs" counts the first run, level 0, its replay and each doubled level.

**Cost per run, in forwards F of the level-0 run** (F = 81–126 s): first run 0.35–0.44;
resident sweep 2.0–2.5; invader walk 0.5–0.9 and its sweep 2.0–2.7. On the replay: forward
0.42–0.54, resident sweep 1.5–1.6, invader walk 0.43–0.55 and sweep 1.46–1.65. So g's
certificate on the replay is 1.9–2.2 F, not § Next's 1.3 F, and a pass 1 (run plus replay,
first run aside) judging g costs 5.9–7.3 F against 5.1–5.6 F for the elasticities.

## Reading

**At scale 1, {ln J, g} saves nothing.** Both sets stop at level 0 after one pass on every
case, on the same 194–230 nodes, so the schedule, passes and runs are identical. Neither set
binds near ε (worst bounds 0.31–0.50 for A, 0.28–0.37 for B; u_q's 0.22 is most of B's), and
{ln J, g} costs 1.2–1.3× the CPU because the invader's walk and sweep cost more than the
resident's sweep. The graded spell-end layer and the even-plus-two counts are in the density,
not the judged set, and no second pass happens at scale 1 on these four cases.

**g, not the elasticities, is the harder quantity, and only on long-wet.** Coarsening the
schedule shows which quantity binds first. On dry, episodic-lma and epi-adG208 the two sets
take the same or similar schedules. On long-wet, judging the elasticities accepts level 0 at
scale 0.5 and 0.25 with g 2.2ε and 7.5ε off (26 and 32 of 46 uncovered); judging g rejects
those runs and refines to 257–311 nodes, where every quantity is within 0.21ε. So removing the
elasticities from the judged set does not remove nodes; adding g can add them.

**Below scale 1 the stop is not safe for either set.** dry at 0.25 and 0.5, and epi-adG208
at 0.25, accept runs up to 11ε off (ln J 4.8ε on dry at 0.25), with the replay reading
−0.2 to 0.5 of the error. `refine.md` records this ("below scale 1 the estimate can read
low"); it is a property of the replay on a coarse schedule, not of the judged set.

**What the elasticities keep unjudged.** On {ln J, g}'s schedule at scale 1 they are within
0.09–0.35ε (the reference's own move is 0.05–0.26ε), every one covered by its own bound. At
scale 0.5, where the schedule is still {ln J, g}'s choice, they reach 0.47–1.22ε (dry 1.22,
epi-adG208 0.97). So on a canonical schedule they come free; they are not guaranteed.

## Does g's certificate on the replay behave?

The estimate e of g against the run's true error Q − ref, per case (set B's final pass):

| case | scale | worst run err (ε) | read (slope of e on err) | corr | covered |
|---|---|---|---|---|---|
| dry | 1 | 0.14 | 0.87 | 0.99 | 46/46 |
| episodic-lma | 1 | 0.29 | 0.98 | 0.99 | 46/46 |
| epi-adG208 | 1 | 0.15 | 0.98 | 0.95 | 46/46 |
| long-wet | 1 | 0.15 | 1.55 | 0.93 | 46/46 |
| dry | 0.5 | 0.60 | 0.56 | 0.69 | 45/46 |
| episodic-lma | 0.5 | 1.01 | 0.92 | 0.99 | 46/46 |
| epi-adG208 | 0.5 | 0.48 | 0.74 | 0.94 | 46/46 |
| long-wet | 0.5 (level 1) | 0.24 | 0.51 | 0.91 | 46/46 |
| episodic-lma | 0.25 (level 1) | 0.64 | 1.00 | 1.00 | 46/46 |
| long-wet | 0.25 (level 2) | 0.10 | 3.25 | 0.90 | 46/46 |
| epi-adG208 | 0.25 | 1.65 | 0.33 | 0.92 | 14/46 |
| dry | 0.25 | 2.57 | −0.18 | −0.71 | 6/46 |

Yes, wherever the replay works for ln J and the elasticities. At scale 1 it reads 0.87–1.55 of
g's error with correlation 0.93–0.99, and the bound covers all 184 g's; it reads as well as the
elasticities' estimate does (0.43–1.12, corr 0.77–0.98) and better on epi-adG208. It also
caught long-wet's g error at coarse scales that the elasticities missed. It fails where the
others fail, at dry and epi-adG208 at 0.25, and on the same runs. At scale 1 the true errors
are near the references' own move, so the read is measured on errors of 0.1–0.3ε; the coarse
cases are the stronger test of the estimate. The constants 0.5 and u_q were not re-fitted for g.

## Files

- `refine_judged.R`: the driver (the harness's `stand_run` on this stack plus the invader,
  and the loop over a cache of runs by level); `cases.R`; `reference.R` (one rung);
  `score.R`, `summary.R`; `jobs.sh` (at most five runs at once); `build.sh`.
- `results.rds`: per case, scale and set: status, level, passes, nodes, runs, CPU, wall, and
  each quantity's error, raw error, estimate and bound. `results-runs.rds`: every run's
  quantities and timed parts, reference rungs included. Recordings are not kept.
