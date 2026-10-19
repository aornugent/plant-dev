# Residual B: the splits, phylloptim 17–19, the scheduling algorithm, and two drops

Read with git and the docs only, against the refreshed bases: plant develop bd09645d, odelia
master 1e0f0f0 (0.8.0), phylloptim master d216a17 (0.10.3), and the three landed branches
(plant 77e15141, b23b2d67, 1e8e8fa4 and odelia b707d21, each off develop or master). Nothing
was built or run. Cherry-picks were tried with `git merge-tree` only.

"The bank" is the 6 October bank of `design-sign-changes.md` §9 (108 uniform nodes, soil
coupled, a stop at every rain knot, tol 1e-4). "libNS" is the loop's shipping build: PLANT-110
with PLANT-108 reverted (soil substepped, rain substeps, splits on, window factors).

## Verdicts

| piece | upstream has | verdict |
|---|---|---|
| Splits: PLANT-102 + 103, odelia's six split commits + ODELIA-54 | nothing. It has the parts a rewrite would use: `implicit_value`, `step_record`, and (on the landed ODELIA-55) `integrate_substeps` | **HOLD.** The run below decides it. If any of its gates fails, **LAND** as one odelia PR and one plant PR |
| PHYLLOPTIM-17 base (8 commits, 0.9.0) | all of it, as #136 (0.10.0) | **DROP.** Already upstream |
| PHYLLOPTIM-17 6b6f152 (root-finds stop at roundoff) | partly. 0.10 polishes a pinned bound to 1e-15 (`polish_bracket_bound`). It still stops brackets at 1e-4, the collar at 1e-12 and ci at 1e-10 | **HOLD**, probably DROP. Measure the replay noise on 0.10 first |
| PHYLLOPTIM-17 300d229 (refuse a bisection that spends its budget) | no: `uniroot` still tests `it > max_iterations` | **LAND**, folded into the phylloptim PR |
| PHYLLOPTIM-18 6ea53c6 (root curve past its dry end) | no | **LAND** |
| PHYLLOPTIM-19 29982dc (differentiate a determined collar) | no: `Determined` is still refused | **LAND**. Its finite-difference test must pass on 0.10, which has no roundoff brackets |
| Scheduling algorithm (`harness/schedule/refine.R` + PLANT-110's ~30 lines) | a different algorithm: C++ `SCM::refine_schedule` | **HOLD.** Four steps first (§3). Then **LAND** as plant's last PR |
| PLANT-106 `control_window()` | nothing like it | **DROP** (confirmed) |
| PLANT-109 subset walks | nothing like it | **DROP** (confirmed) |

## 1. Splits at net-production sign changes

**What they do.** TF24 reads net production P through a smooth positive part with η = 1e-4
kg/yr. At the step's scale, every crossing of P = 0 is a kink, so a step that spans one makes an
error of h²·a·ψ(u*), where u* is the crossing's place in the step. ψ averages to zero, so J is
unharmed. Its derivative in θ is a staircase, though: it jumps each time a crossing passes a
weighted Cash–Karp stage. A knob nudge reshuffles every u*, so gradients and curvatures carry
noise that does not fall with the knob at its order (`design-sign-changes.md` §1). A split
re-integrates each node whose P changes sign inside an accepted step. The node is integrated in
pieces meeting at the zero, in the field sampled at five fractions of the step. The sweep moves
each zero with the parameters by `implicit_value` (PLANT-103, ODELIA-54). A walk splits an
invader's own nodes at the run's zeros.

**Upstream.** Nothing in plant develop or odelia 0.8 locates, splits or records a sign change.
The delta is the whole mechanism. What changed under it:
- *odelia.* The six split commits (1d7d986…d0d59d5, +494/−41 in `inst/`) and ODELIA-54 (+12/−4)
  sit on ODELIA-53's fork-base recording (on #58). Upstream has since rebuilt recording as #59,
  #70–#78:
  - `step_record` names its method;
  - Cash–Karp and Dormand–Prince live in `ode_step_rkck.hpp` and `ode_step_dopri.hpp`;
  - Hairer's rule is the default.

  The split's diff conflicts in all five headers it touches, so it is a rewrite, not a rebase.
  The rewrite is smaller than the original. The landed ODELIA-55 (b707d21) already has
  `integrate_substeps` and `take_substep`, which integrate a block in pieces with the step's
  tableau. What remains:
  - the `SplitsSignChanges` hook after a taken step;
  - Cash–Karp's dense output at the five fractions;
  - the one bracket rule;
  - the split block in the row, and its count;
  - the sweep through a split row (ODELIA-54).
- *plant.* PLANT-102/103 (+370 lines in `inst/include`) conflict in `patch.h`, `scm.h`,
  `species.h` and `control.h`, because upstream rewrote all four in #648/#657/#661. The walk in
  pieces must be rebuilt on upstream's `run_mutant`.
- *The controller.* The landed PLANT-105 links odelia 0.8.1 and asks for GSL's rule
  (fd02255d). The splits' step sequences are therefore the ones measured, and Hairer's rule does
  not enter.

**What they buy, as measured.** Every number below comes from the coupled soil with knot stops,
before soil substeps (7–8 Oct) and rain substeps (14 Oct):

| gain | plain → split | where |
|---|---|---|
| R1, gradients under a ×1.05 tol nudge | worst resident entry 0.52ε (9 of 49 past ε/6) → 0.14ε (none) | the bank, G5 (unfloored ε, so stricter) |
| the same, as jitter | rms 0.08–0.13 → 0.02–0.04 | the bank, `round3/A/splits.R` |
| R2, curvature of `lma` by second differences, spread over three tols | r = 1e-2: 0.56ε → 0.05ε; r = 3e-2: 0.10ε → 0.002ε | long drought, 108 uniform (`grid-dynamics.md` §17) |
| a curvature chord against the second difference | 0.16 apart → 0.001 | §19 |
| `ln J` | 3–13× nearer the reference, but every error is ≤ 0.003ε | the bank, G4 |
| the loop's answer at one tol | a09 with splits on against off: ≤ 0.07ε | lib19, long drought (`loc/prereg.md`, R1) |
| cost | forward +5.4%, sweep +7.3%; in the loop +2.9–3.5% CPU | §18 *Finished*; lib19 |

**What is no longer theirs.** D2 credited the splits with curing the 33ε reverse-pass blow-up.
Agent D then traced that blow-up to the stiff top soil layer: Cash–Karp rode its stability
limit, which made the forward map transiently chaotic. A split run blew up too, worse: a10s
with splits reached 2186 (`round3/D/notes.md`, *Root cause*). Soil substeps cure it. So the
splits buy **no blow-up protection and no accuracy at ε** (≤ 0.07ε in the answer, ≤ 0.003ε in
`ln J`). What they still buy is **R1 and R2: reproducible gradients and stable curvatures under
the controller's incidental choices**, on the net-production staircase.

**Why the final configuration might differ, both ways (inferred):**
- *Longer steps make plain worse.* Soil substeps and rain substeps take long drought from
  15 376 steps to 6 370 at 108 nodes (`PLANT-105.md`). The riser is proportional to h·a, so plain's
  staircase should grow, not shrink.
- *More nodes make it smaller.* The loop's schedules hold 194–267 graded nodes against the bank's
  108 uniform, which spreads the risers over more nodes.
- *The split costs more, relatively.* Its cost is fixed per node step split: about 85 crossings
  per node over 40 years, nearly independent of tol. The forward fell from 145 s to 60 s, so the
  split's share rises from 5.4% toward about 8–9%.
- *Splits alone do not make the final configuration reproducible.* On libNS with splits on,
  dry-lma125's ×1.05 nudge moves TF24_cost_scale by 0.42ε (`frontier.md`, F14). That direction
  is the hydraulic one: the leaves switch to the hydraulic bound inside a step (`localised.md`,
  agent JT). The splits do not cut there.

**The measurement that settles it.** It needs no build, because libNS carries
`ode_split_sign_changes` as a Control field.
- *Runs:*
  - each of the five canonical cases plus dry-lma125, on the s1 schedules from `refine/ns`;
  - splits off at tol 1e-4 and 1.05e-4, and splits on at 1.05e-4: 18 gradient runs, about 2
    CPU-hours at R22's timings;
  - `lma`'s second difference at r = 1e-2, on episodic-lma and ld104-p50125, at tol
    {0.95, 1, 1.05}e-4, splits on and off: 24 forwards.
- *Drop the splits only if, with them off:*
  - no quantity outside the hydraulic direction (TF24_cost_scale, stem_c,
    storage_relaxation_offset) moves by more than ε/3 under the nudge on any case;
  - the curvature's spread stays under ε/3;
  - the loop's bound still covers every quantity against the reference ladders.

  The same runs then re-score the loop's constants without splits, so a drop needs no further
  round.
- *Otherwise land them.* The split is the cheapest measured cure. Halving the crossing steps
  costs +9.7–13.5% of a forward. Global stops cost 2.9–3.3×. A tighter tol needs 1e-5 at +41%,
  and the split at 1e-4 costs 0.77 of plain at matched stability. The closed-form correction B
  (about 250 lines, 0.9%) was never measured on TF24.

**Smallest form, if it lands.**
- *odelia PR:* "split a block's step at its sign changes, forward and sweep". It holds the hook,
  the dense output, the bracket rule, the row's split blocks and their count, and the sweep. It
  builds on the landed ODELIA-55, without ODELIA-53's foundations.
- *plant PR:* PLANT-102 with 103 folded in. 102 alone cannot give a gradient, because the sweep
  refuses a split row. It needs PLANT-100/104 only for the preset, so the split should go into
  `control_tf24()`. Fix in place:
  - `field_samples`' hard-coded 5 should come from odelia's sample fractions;
  - the model-version snapshot belongs in this PR;
  - a run under any method but Cash–Karp would split nothing, silently. Upstream odelia can now
    record dopri, so this is reachable once plant offers a method. Refuse it through the concept.

## 2. phylloptim: PHYLLOPTIM-17, 18, 19 against master d216a17 (0.10.3)

Branch PHYLLOPTIM-17 is the 0.9.0 base plus 6b6f152 and 300d229. Branch 18 adds 6ea53c6, and 19
adds 29982dc.

| commit | what it does | in 0.10.3? | applies? (`merge-tree`) | measured gain | verdict |
|---|---|---|---|---|---|
| 0.9.0 base (8 commits) | the leaf at the caller's scalar, supplied derivative rows | **yes**, as #136 (b019e5d, 0.10.0), and evolved since (+657/−178 in headers past 378b083). The probe file the C review wanted cut, `probe_tape_regions.cpp`, shipped with it | — | — | DROP: upstream |
| 6b6f152 | every root-find stops at roundoff; removes `collar_root_tol` and the `tol` arguments | partly. #136 polishes a pinned bound to 1e-15 (`polish_bracket_bound`, about 45 lines), the case where 1e-4 put rows 100× off. Brackets stay at 1e-4, the interior collar at 1e-12, ci at 1e-10 | conflicts in `leaf_model.hpp` | on the 0.9.0 base, replay noise in `ln J` fell from 2.7e-8 to 8.5e-15, for 1.12× a replay; `ln J` moved by −1.5e-6 (`grid-dynamics.md` §18). Not measured on 0.10, where the pinned bound is already exact | HOLD |
| 300d229 | `uniroot`'s budget test `>` → `>=` (boost never exceeds it, so the refusal could not fire) | **no**: `uniroot.hpp:34` still has `>`, on the Medlyn ci path | conflicts with the comment only | none: no finished run refuses | LAND, folded in |
| 6ea53c6 | rows past the root curve's dry end: G at the last knot on the tangent, G(∞) past the cap, none at the floor | **no**: `closed_form_rows.hpp` has no dry-end case | **headers apply cleanly**; DESCRIPTION/NEWS conflict | sweeps refused at 1e-4 on long drought and ld-105 now run; the cap binds 2189 times on 1e-4's steps (`error-modes.md` F) | LAND |
| 29982dc | a determined collar carries the mean of its two bounds' rows, and the stem sits at psi_crit with no response | **no**: `collar_at` refuses `Determined` (header map, line 74) | conflicts in `leaf_model.hpp`; its prerequisites are upstream (`dry_bound_is_root_limit_`, `bound_at`, odelia's `record_with_derivatives`) | every long-drought record refused at 3e-4; a wrong row fixed (profit in root_P50 0.053, against −0.83 by difference); golden byte-identical | LAND |

**What 6b6f152 still buys.** Very little that the objectives read:
- the loop's estimates are differences at ε scale (ε = 0.025 in `ln J`), 1e6 times the noise;
- the sweep differentiates each root by the implicit function theorem, not through its iterates.

The noise matters to finite-difference tests and to gates read below 1e-8, such as "J moves by at
most 1e-8 as a sign change passes". The C review says pinned replays depend on it; that holds
only for those sub-1e-8 readings.

On 0.10 the remaining sources are ci at 1e-10 (the guide's table: 5.4e-10 against a converged
solve) and the interior collar at 1e-12. Taking ci to roundoff costs about +9% a solve on that
same table, so the +12% would stay.

*The measurement:* on develop with 0.10.3, repeat the `tight.log` probe: `ln J` on one pinned
replay at `lma`·(1 + k·1e-12), k = −8…8, and the rms off a line. That is 17 replays. DROP if the
rms is under 1e-12, or if no consumer reading below 1e-8 can be named. If it lands, delete
`polish_bracket_bound`, since a bracket at roundoff subsumes it.

**A coupling for 29982dc.** On the 0.9.3 base its bounds came from root-finds at roundoff. On
0.10, bound_a (the zero-flux root) and the continuity bound are placed at 1e-4. The forward's
midpoint then moves with the iterates, while the rows differentiate the roots. That is the
mismatch #136 fixed for pinned bounds, where rows came out 100× off. `test_leaf`'s
finite-difference check at the two determined fixtures decides it. If it misses, polish both
bounds in the collapsed-interval branch, as #136 polishes a pinned one. That costs nothing on
the normal path.

**Smallest form.** One phylloptim PR on master, "differentiate the leaf where its forward
answers". It holds 6ea53c6 and 29982dc (plus the polish if the check needs it), with 300d229's
one-character fix. Version 0.10.4. The `uniroot_smooth` history comment that 300d229 deletes is
upstream's call.

plant pins phylloptim == 0.10.2 (develop), and the libS stack pinned 0.9.1 while its library was
built with 0.9.3. The pin moves in the first plant PR that needs these rows: the scheduling port,
or any long-drought gradient at 1e-4.

## 3. The scheduling algorithm

**What it does.** A schedule is spell edges (breakpoints), a density between them, and a level
k that doubles every count.
- *Density.* It is graded by the offspring curve, with ages taken from T(t). It is raised to 2
  over t_r = o·ln(a_st3·a_dG2) before each spell end.
- *Even counts.* Each spell holds an even number of intervals, so removing every other interior
  node leaves a coarser schedule of the same kind.
- *The estimate.* A pinned replay on that coarser schedule, on the run's own steps, gives the
  run's error estimate e = (Q_removed − Q)/3 for `ln J` and 47 elasticities.
- *The stop.* The run is accepted when every |e|/r_min + u_q < ε_q. Otherwise the next level
  doubles every count, and the rejected run becomes its estimate, with no replay.

Then the schedule is fixed for the local analysis. Each later run reports its own replay
estimate, and its distance from the run that built the schedule (`design-refine-schedule.md`;
code `harness/schedule/refine.R`, 162 lines).

**Upstream's equivalent.** `SCM::refine_schedule()` (`scm.h:1198`), reached through
`run_scm(refine_schedule = TRUE)`, with `schedule_eps` and `schedule_nsteps` in Control. logpile
carries it as a request key (`fingerprint.R`, `manifest.R`, `solver.R`). Each pass runs, flags
nodes whose `refinement_error_by_node` exceeds `schedule_eps`, and bisects the interval below
each. It refuses only the absorbing top layer, and it works on either coordinate for every
strategy.

On TF24 it measures the wrong thing (`diag-nested-grid.md`, plant 6613dd24, tol 1e-3):
- the competition term, normalised by leaf area, sets the indicator on 106 of 106 nodes;
- it flags nodes that carry 2.7e-10 of J.

From the default 108 nodes on long drought, it took six runs (962 CPU s, 7.3 forwards) to stop
at 178 nodes with J 1.3% low (about 0.5ε in `ln J`). Its error was not monotone and it reported
no estimate (`perf-adjoint.md`). It estimates nothing for gradients. The loop is a replacement
algorithm, not a delta on it.

**What the loop gains, measured** (`refine2/notes.md`, `frontier.md`, `epi.md`):

| | result |
|---|---|
| canonical, five cases, libNS (R23) | every case accepts at pass 1; worst error 0.20–0.53ε over all 47 quantities; the bound covers 47 of 47, with ≥ 0.18ε to spare |
| eight libNS cases, three of them held out (frontier) | 8 of 8 accept at pass 1; 375 of 376 quantities covered. The one miss is tolerance error: dry-lma125's TF24_cost_scale moves 0.42ε under a 5% nudge |
| K1, reporting Q − e with bound 0.5\|e\| + u (same runs, no cost) | worst error 0.03–0.20ε on libNS (dry-lma125 0.58, the same tolerance miss); 1.8–11× smaller than K0 |
| cost | first run + run + replay = 1.12–1.31× round 5's hand-tuned E6 run + replay (libS, under load); the first run is 4–6% |
| reject behaviour (R20, from half scale) | no false accept; a reject costs about one more run (1.56–1.74× in total) |

**What it rests on, among the residual pieces:**
- *Gradients:* `census_trait_gradient_tf24` / `stand_gradient`. Upstream #648/#657, so no
  residual piece is needed.
- *Pinned replays:*
  - `ode_times` + `ode_step_sizes` are upstream;
  - the soil's `ode_soil_input_slopes` and `ode_soil_substep_ends` are the landed PLANT-105
    (1e8e8fa4);
  - the replay's node subset needs nothing further.
- *Establishment records:* the first run's establishment rate and T(t) are computed in R from
  `store_trajectory` (upstream) and `establishment_weights` (landed PLANT-93). The port can keep
  them in R in about 20 lines. Nothing needs PLANT-106's C++ getter.
- *t_r:* it is a property of the storage pool's offset, which is the landed PLANT-97.
- *Controls:* `refine_case.R` sets six fields by hand that equal `control_tf24(1e-4)` (PLANT-104,
  residual A), plus PLANT-100's tolerance factors from rule-A weight files (residual A). u_q's
  tolerance allowance (0.11ε) was measured with those factors on, so the port waits for PLANT-100
  or re-measures u_q.
- *Splits:* the constants were measured with splits on. §1's run decides whether they stay.
- *phylloptim 18 and 19:* the loop hits their refusals on long drought at 1e-4 and at 3e-4.
- *Not needed:* walks (PLANT-99) until invaders' spell ends are built; PLANT-106, 108 and 109.

**PLANT-110's remnant** (about 30 lines of `diagnose_scm`): what remains after the loop
supersedes the node-error part:
- a use's distance from its grid, |ln J − ln J₀| against d* = 0.5. d* is calibrated on a09:
  θ₀'s estimate transferred at d = 0.19 and misread at 0.73–1.11 (`design-grid-controller.md`,
  item 8);
- each invader's ln(θ′/θ) for every parameter it moves;
- failures returned as rows instead of thrown.

These become the fit's `distance` and `failures`, and a use's report. OBJECTIVES asks for the
distance in θ against the grid's radius. The ln J form stands in until the radius is measured.

**How it would land.** One plant PR, the last in the series. It replaces the C++
`SCM::refine_schedule`, `refinement_error_by_node`,
`r_compute_competition_effect_error_by_node_for_species_i`, `collect_refinement_errors`,
`schedule_eps` and `schedule_nsteps` with an R `refine_schedule(p, env, ctrl)` that returns the
fit (`answer`, `estimate`, `bound`, `schedule`, `level`, `history`, `costs`, `status`,
`distance`, `failures`). `run_scm(refine_schedule =)` goes, and logpile's key and fingerprints
change with it. The PR subtracts the C++ loop, its three error members and two Control fields, and adds about
200 lines of R.

**The HOLD:**
1. *Adopt K1 in the harness.* Report Q − e and stop on 0.5|e| + u. This deletes
   MIN_ESTIMATE_RATIO, whose 0.82 failed on libNS (medians 0.61–0.65 on three of four cases;
   `epi.md`). No runs are needed (`frontier.md`, *What I recommend*).
2. *Fix the tolerance allowance.* dry-lma125 carries 0.6ε of tolerance error at 1e-4 against
   the 0.11ε that u_q allows. Either the time axis supplies an estimate, or the port flags the
   case. A port should not claim the bound where it is known to miss.
3. *Measure one head-to-head on one base.* develop's `run_scm(refine_schedule = TRUE)` at its
   default `schedule_eps`, on the five canonical cases at the loop's controls, followed by its
   gradient run. Score it against the same reference ladders, with CPU, worst error and whether
   any estimate exists. The comparison above mixes bases and tolerances (6613dd24 at 1e-3
   against libNS at 1e-4). Maintainers need the three numbers from one base.
4. *Decide the scope for FF16, K93, TF24f and the height coordinate.* The loop's constants (ε
   table, u_q, r_min) exist for TF24 on birth date only. The height coordinate is develop's
   default, and `benchmark.R` calls `run_scm(p, refine_schedule = TRUE)`.

   Two choices:
   - the strategy supplies "one spell, no grading", and the caller supplies ε until FF16's
     constants are measured;
   - the loop serves birth-date TF24 and the C++ loop stays for the rest. That keeps two
     refiners, so it is the weaker choice.

   This is a maintainer decision to put in the PR.

## 4. PLANT-106 and PLANT-109: DROP confirmed against upstream

- **PLANT-106** (`control_window()`, `SCM$invaded`, `offspring_produced_at_ode_times`,
  `Species::offspring_production_per_fecundity`): none of these names exist in develop. The loop
  never used the function: its weights came from `harness/window_rule.R` on 2 Oct, five days
  before c6546c94.

  Upstream's `store_trajectory` plus the landed `establishment_weights` give T(t) in R, as
  `stand_run(records = TRUE)` already does. The getter would duplicate that, so nothing needs to
  be carried. Dropping it changes no number.
- **PLANT-109** (`NodeSchedule::add_entry`, `Patch::{set,get}_recorded_birth_dates`): develop has
  neither. Upstream's `run_mutant` walks at the resident's recorded field with its own node
  layout. The thinning rules the branch enabled were measured and turned down: 0.74ε and 0.43ε.
  The user kept the full walk, and nothing calls it. Re-add it only if the shared thinned
  schedule is built.

## For maintainers: the LAND items

**phylloptim: differentiate the leaf where its forward answers** (6ea53c6, 29982dc, 300d229)
- *Problem.* The forward returns an operating point that the derivative path refuses:
  - past the root curve's dry end, where the forward reads the table's tangent or its cap;
  - at a determined collar, where a collapsed interval sets the midpoint.

  plant's TF24 gradient then fails on whole climates: every long-drought record at 3e-4, and
  long drought and ld-105 at 1e-4. Where the determined case was patched by continuity, one row
  came out wrong with no warning.
- *Mechanism.* The rows are those of what the forward returns:
  - past the dry end, the tangent at the last knot, G(∞)'s partials past the cap, and no row at
    the floor;
  - at a determined collar, the mean of its two bounds' rows, with the stem at psi_crit and no
    collar response.
- *Three numbers.*
  - Long-drought refusals at 3e-4 go from every record to none.
  - The profit row in root_P50 goes from 0.053 to the solve's −0.83 by difference.
  - The golden and primitives outputs stay byte-identical: no forward value moves.
- *Cost.* +108 and +232 lines, mostly tests (`test_leaf`, `test_transpose`), and one character
  in `uniroot`. On 0.10, polishing the determined bounds may be needed (see §2). It runs only on
  the collapsed path.

**Conditional, once its HOLD clears: splits at sign changes** (odelia + plant)
- *Problem.* Every crossing of net production through zero is a kink that Cash–Karp's stages
  sample. A 5% tolerance nudge moved gradients by up to 0.52ε, and second-difference curvatures
  by 0.56ε at r = 1e-2. Both exceed OBJECTIVES' ε/3.
- *Mechanism.* After each accepted step, each node whose net production changes sign is
  integrated again in pieces that meet at the zero. The pieces are found on the step's dense
  output, in the field sampled at five fractions. The sweep moves each zero by the implicit
  function theorem.
- *Three numbers* (the bank and §17, to be re-read on the final configuration):
  - worst nudge move 0.52ε → 0.14ε;
  - curvature spread 0.56ε → 0.05ε;
  - forward +5.4%, sweep +7.3%.
- *Cost.* About 500 lines in odelia (less, on the landed ODELIA-55's substeps) and about 400 in
  plant. A rewrite onto odelia 0.8's recording, not a rebase.

**Conditional, once its HOLD clears: a schedule that reports its own error** (plant, last)
- *Problem.* `refine_schedule` bisects on a competition indicator, normalised by leaf area, that
  does not track J. On TF24 it stopped after 7.3 forwards with `ln J` about 0.5ε off. It reports
  no estimate, and none for any gradient.
- *Mechanism.* Nested schedules: breakpoints at spell edges, a density graded by the offspring
  curve and by t_r, and even counts. A pinned replay with every other node removed estimates
  each quantity's error on the run's own steps. A reject doubles every count, so the rejected run
  is the next estimate.
- *Three numbers* (libNS; item 3 above adds the head-to-head):
  - 8 of 8 cases accept at pass 1;
  - 375 of 376 quantities lie within their bound;
  - worst error 0.03–0.20ε with K1, at 1.12–1.31× a hand-tuned schedule's run + replay.
- *Cost.* About 200 lines of R. The C++ loop, its three error members and two Control fields are removed. logpile's
  request key and fingerprints change.
