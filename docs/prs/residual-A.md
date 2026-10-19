# Residual A: the gradient and replay machinery, and the step control

Scope: plant PLANT-95 (commit by commit), 99, 100, 101, 104, 107 and odelia ODELIA-53 (commit by
commit), from `archive/stack-2026-10-18/*`, read against plant develop `bd09645d` and odelia
master `1e0f0f0`. Read-only: `git show`/`git diff`/`git grep` and plant-dev docs. Nothing was
built or run.

## The short answer

- Upstream already took most of this slice. `#648` is PLANT-95's first eight commits (61af9238 …
  f1ece07b) without PLANT-93: `git diff f1ece07b 8657b3ae` is 28 files, +946/−844. The rest is
  PLANT-93's fallout and later polish. That covers the scalar templating, TF24 v11, the census
  gradient, the sweep referees (with `gradient_ladder.cpp` and `overstorey_staging/`), the bindings
  and the guide. `#657` adds FF16 and `#658` adds FF16's fitness and the invader sweep. odelia
  0.7–0.8 (`#59`, `#70`, `#71`, `#73`, `#75`, `#76`) covers ODELIA-53's caller's scalar,
  recording, transpose, row walks and the carried k1.
- Three things are still missing upstream, and OBJECTIVES' quantities need them:
  1. **TF24 declares no fitness.** `stand_gradient()` gives TF24's census only
     (`test-tf24-mutant-gradient.R`: "TF24 declares no fitness").
  2. **A TF24 invader is evaluated at the resident's leaf operating points.** The replay loads
     the resident's row, and `solve_leaf` then calls `leaf.replay_operating_point(recorded.collar,
     …)` (`tf24_strategy.h:2516`) instead of solving. So the number reported is not the invader's
     fitness. An invader community of two species fails with `expected 2, received 1`.
  3. **No per-component tolerance factors** in odelia or plant. These are the step control's
     −31–34% of a gradient run.
- Upstream's invasion replay also gets two things wrong without saying so. OBJECTIVES' records do
  not hit either, but the replay should refuse both:
  - **It applies no events.** `advance_recorded` maps an insertion row through
    `Patch::apply_insertion` (`patch.h:2032`), which introduces nodes and nothing else, so a
    harvest or climate extreme never reaches the invader. An identical invader's `ln J′ − ln J` is
    +0.69 under a 50% harvest and +1.3 under a lethal extreme (deck.tex, *Events were skipped*,
    measured on the stack before b737a9b5).
  - **It drops invader introductions.** `introduced_at` (`patch.h:1963`) matches only the
    resident's insertion times. An invader introduced anywhere else is never introduced, and no
    error is raised.

## Verdicts

"Base" says where each number was measured; † marks a base that upstream has since changed.

| piece | upstream equivalent | delta left | measured gain (base) | verdict |
|---|---|---|---|---|
| **PLANT-95** 61af9238 scalar templating, TF24 v11 | `#648` (TF24/TF24f), `#657` (FF16), `#659` (K93 body) | none | — | DROP |
| b46c224b one schedule row per instant | `#648` | none | — | DROP |
| 45692c0f census gradient | `#648` `stand_gradient`/`stand_census`/`_state_adjoint`/`gradient_control`/`_refused`/`_compare`; `#657` | none | — | DROP |
| e36f6859 sweep referees | `#648` ships them all, the 1067-line test-only `gradient_ladder.cpp` in the .so and `overstorey_staging/` included | none for us; the debt is upstream's now | — | DROP (offer upstream a subtraction PR later) |
| 46b64768, 3ed7df2c, b34b420d, f1ece07b | `#648` | none | — | DROP |
| 1b851995 program replayed by its times (test only) | odelia `#73` and plant's `program_within` replay a grid by its times | a 34-line test that leans on PLANT-97/98's storage refusal | — | DROP (fold into the PLANT-97 PR if wanted) |
| 5cf9e937 binding component per row | none | `error_index`/`error_ratio` | diagnostic only. It is a max-norm notion; odelia now defaults to Hairer's RMS norm | DROP |
| a6b92a19 attempt outcomes | odelia keeps a cumulative `n_rejections` (`ode_solver_internal.hpp:305`), which plant does not expose | per-run, per-outcome tally | the 759 → 149 → 0 throw tallies behind PLANT-97/98 (†) | DROP as built; optionally expose `n_rejections` per run in PR B (OBJECTIVES "Diagnosed: its failures") |
| 19a51aa3, 4f8d9ad5 offspring production as seed, its referee | `#658`: `stand_metrics()` with `"<i>.offspring_production"`/`net_reproduction_ratio` for any strategy with `differentiable_fitness` | TF24 does not set the flag, and S_D sits in TF24's `no_gradient` table | sweep vs tangent 2.1e-8 at worst over 22 traits, bound 3e-4 (4f8d9ad5 †) | **LAND in PR A** |
| 5a37615e suite follows exact counts | — | PLANT-93's fallout | — | belongs to PLANT-93 (landed) |
| f3550290 invaders in the recorded field | `#658`: an invasion keeps states on request, the sweep stands in the resident's field, `introduction_fields` covers insertions and the first rates after them, odelia `#71` records loaded rows | the invader's **own** leaf operating points | identical invader exact; resident+mutant together bit-identical to the mutant alone (fails upstream); invader sweep vs central difference 1e-7, 1e-10 for hmat and k_I (†) | **LAND in PR A** (with odelia A0) |
| 77cf5bbd inflow from before an event at an introduction | none | a model rule for events at introductions | moves harvest-at-introduction fitness 0.22–0.54% | DROP (events are outside OBJECTIVES) |
| b737a9b5 one map per entry, events in the replay, light recorded as knot data | partly: upstream records slopes and the canopy top but restores through heights (`resource_spline.h:126`, u = h/top) | events in the replay; the ulp-exact light | +0.69/+1.3 → 0 in `ln J′ − ln J` with events; 5e-9 in a log density from the ulp | DROP the port; **refuse** an invasion of a run with a harvest or climate extreme (PR A, ~5 lines) |
| 4d147107 a pinned run is one walk of rows | upstream still steps pinned runs interval by interval (`program_within`) | a refactor | bit-identical | DROP |
| 25e21a70 refuse an entry a walk never reaches | none: upstream drops the introduction and keeps going | the refusal | correctness | **LAND in PR A** as a ~10-line check in `run_mutant` |
| **PLANT-99** walk a recorded run without repeating it | upstream re-runs the resident pinned when `resident_recording` is empty (`scm.h:1059`), even after a recorded run | keep each evaluation's field in `built` beside the states | first invasion 300 → 139 s, ~12% of a both-roles gradient run; +7.4 kB/step held (PLANT-98 base, coupled soil †) | HOLD (M3) |
| **PLANT-100** 812248f5, 858340b0 tolerance factors and their bound | none (odelia's `OdeControl` has scalar tolerances only) | `ode_tol_factor_soil/_times/_values/_max`, environment-supplied positions | 33.7/33.1/30.6% of a gradient run; resident's worst distance to 1e-5 falls 0.187/0.092/0.181ε → 0.056/0.062/0.078ε; unbounded, 0 of 50 gradients on episodic, bounded 50 of 50 (coupled soil, GSL, 3e-5 †) | **LAND as PR B after M1**; cut `ode_tol_factor_accumulator` |
| 631bbab3 newborn height to roundoff | none; phylloptim d216a17's `uniroot` takes a tolerance | needs PHYLLOPTIM-17 | replay noise 2.7e-8 → 8.5e-15 in `ln J`, ≪ ε = 0.025; costs 1.12× a replay | DROP (follows PHYLLOPTIM-17) |
| **PLANT-101** field without the newborn's rates | none: `compute_boundary_node` still computes the rates (`species.h:143`) | needs PLANT-93: upstream's birth-date density is `birth_rate * pr_estab`, which needs those rates | 39% of a **split** part evaluation; without splits, one leaf solve per species out of N+2, under 1% at 108 nodes | DROP, or fold into the split PR if PLANT-102 lands |
| **PLANT-104** `control_tf24` | none | an R preset | none in numbers; names one setting | **LAND inside PR B**: default `tol` 1e-4, plus the soil share; the split only if PLANT-102 lands |
| **PLANT-107** crossed crowns tallest first | upstream walks every node when crowns cross (`species.h:723`) | needs PLANT-93's per-node weights; upstream's trapezium pairs neighbours and cannot be sorted | avoids a walk costing 23% of a forward; crowns cross on 20% (long-wet) to 79% (long drought) of builds at ≥429 uniform introductions; the sort costs 0.114 against 0.113–0.117 ms/row (§16 †) | **LAND** stacked on PLANT-93 |
| **ODELIA-53** 297753b, ff71c8d, d720398 caller's scalar | `#59` (`to_passive`, `AdjointRangeError`, `active_scalar`, tangent), `#60` (`value_with_slope`) | none | — | DROP |
| 6fd01c7, d040766, acc4274, 030dd73 record and transpose | `#59`, `#70`, `#75`, `#76` | none | — | DROP |
| d32b353 Hermite into 0.5.0 | `#60` `hermite_spline`; plant reads it (`#649`) | none; our header is dead and clashes with `interpolator.hpp` | — | DROP |
| 2e172e3 binding component, be3e2cb attempt outcomes | `n_rejections` only | see a6b92a19 | — | DROP (see above) |
| 29205f0 a walk stores its own rows over a copy of the recorded one | none: a replay hands each stage the recorded row **const**, and the stage loads it (`ode_solver_internal.hpp:230–245`) | the seeded, writable walk | what makes the invader solve its own leaf | **LAND as odelia A0** (~30 lines and a test) |
| a05f5c2 walk rows, repeat each recorded evaluation | `advance_recorded` over programs and recordings, `be_at_step`, `k1_time` (`#71`); plant's `introduction_fields` (`#658`) covers the insertion evaluations | the `at_state` slot | — | DROP |
| 30f9a7b per-component tolerance factors | none | a concept and a factor per component | see PLANT-100 | **LAND as odelia B0**: scale `D0` in both norms, gsl's max (`ode_control.hpp:139`) and hairer's RMS (`:187`), at the outer error test only, not the subsystem's inner substep control (`ode_step_rkck.hpp:522`) |

## The smallest set OBJECTIVES still needs

OBJECTIVES asks for `ln J`, its elasticities and curvatures, for residents and invaders, on TF24.
On refreshed upstream, the resident's census gradient exists and the rest is two pairs of PRs.
Upstream's invasion replay and sweep already do the rest: the resident's field recorded and
loaded, the carried k1, the insertion fields, `store_trajectory`'s refusal.

**PR A: differentiate a TF24 species' fitness, as a resident and as an invader.** It needs one
odelia PR first.
- *odelia A0: let a replay store its own solves over a copy of each recorded row.* The walk
  over a recording copies `rec[k].solved` into the scratch row and hands the stages that copy as
  writable. The System then reads what the row holds and stores what it solves itself, and the
  replay's recording keeps both. The const-row walk stays as it is for the pinned referees, so
  this is an opt-in walk, not a change of meaning. One test: a widening system that solves for
  values replays a recording and stores its own values beside the recorded ones. Patch bump.
- *plant A:*
  1. `TF24_Strategy::differentiable_fitness = true`. Take S_D out of `no_gradient`: it multiplies
     offspring production, which is now a metric.
  2. In an invasion, `Patch::store_solved` stands in a field the seeded row already holds, and the
     strategies store their own operating points. `run_mutant` walks the recording with A0's walk.
  3. Two refusals in `run_mutant`:
     - a resident run with a harvest or climate extreme;
     - an invader introduction the resident never made.
  4. Tests:
     - `test-tf24-fitness-gradient.R`: resident offspring production and net reproduction ratio
       against a pinned central difference, each row refereed on its own scale (4f8d9ad5's
       lesson: offspring production sits 4e-7 below leaf area);
     - an identical invader returns the resident's fitness exactly;
     - a resident and a mutant together run, and the mutant's fitness is its fitness invading
       alone;
     - an invader at lma ×0.9 matches a central difference of invasions against the same
       recording;
     - both refusals fire.
  - Sizes, from the archived diffs: odelia about 30 lines in headers plus a test; plant about
    40 lines in headers plus about 200 of tests.
  - It depends on PLANT-97/98 (the storage pool) for invaders beyond about ×1.0001: upstream's
    invader overshoots its pools at lma × (1+1e-4) (scope-imex-stepper.md §1 table). So land it
    after PLANT-97, or test it inside that range.
  - The harness's `census_trait_gradient_tf24(scm, "offspring_production")` becomes
    `stand_gradient(scm, metrics = "1.offspring_production")`.

**PR B: TF24's step control.** It needs one odelia PR first.
- *odelia B0:* `ScalesStateTolerances`: a System fills one positive factor per component at a
  step's start, held across retries. `adjust_step_size` multiplies each component's error level
  by its factor under both rules. A System without factors steps bit for bit as before. Taken
  from 30f9a7b and extended to the hairer branch, which did not exist when it was written.
- *plant B:* PLANT-100 without the accumulator factor, plus PLANT-104.
  - `ode_tol_factor_soil` (the environment names its soil layers' positions; on PLANT-105 that
    is the soil subsystem) and the `_times/_values` schedule;
  - `ode_tol_factor_max`, applied after the product;
  - `control_tf24(tol = 1e-4)`, which sets those, the absolute tolerance at 1e-4 of the relative,
    the 15-day cap and the soil share;
  - defaults reproduce every run bit for bit.
- Stacked on PLANT-105 (landed), since the soil's positions come from its subsystem.

**Not needed for OBJECTIVES:**
- PLANT-99: one forward saved per resident;
- PLANT-101 and PLANT-107: speed in the field build, after PLANT-93;
- the rest of the event and pinned-row work;
- the roundoff seed height;
- the step diagnostics.

## Measurements to name

- **M1, before PR B: the factors on the substepped soil.** The 31–34% was measured with the soil
  coupled, under GSL's rule, at 3e-5 (grid-dynamics.md §8). PLANT-105 now substeps the soil, and
  the loop runs at 1e-4.
  - Setup: four arms on PLANT-105-land with odelia B0, long drought and episodic, 108 uniform,
    `tol` 1e-4, at share 0 and at share 0.1: defaults; soil ×10 with the bound at 100; rule A; both.
  - Measure each arm's gradient-run time, and its five elasticities against the 1e-5 reference.
  - LAND if the soil factor and rule A together still save at least 15% at under ε/3 drift.
    Otherwise land the schedule and the bound alone.
  - Earlier evidence that the soil factor still binds: soil-alone's gates G4/G6 ran on top of it
    (design-soil-alone.md).
- **M2, inside PR A's tests, not a gate:** the invader's sweep against a central difference at
  lma ×0.9 and ×1.1 on upstream's invasion path.
- **M3, before PLANT-99:** re-time the first invasion against a both-roles gradient run on the
  refreshed base, where the forward is about 78 s (PLANT-105.md). Land it only if it saves at
  least 10%.

## For maintainers

**PR A: a TF24 invader's fitness, and its gradient.**
- *Problem.* An invader of a TF24 stand should optimise its own leaf in the resident's light and
  water. Today it takes the resident's root-collar water potential at every rate evaluation
  (`load_solved` → `replay_operating_point`), so the fitness reported for a different trait is
  the resident's leaf on the invader's body. A two-species invader community fails outright.
  TF24 also offers no fitness metric to `stand_gradient()`.
- *Mechanism.* The replay copies each recorded row and lets the invader write its own leaf
  solves into the copy beside the resident's field (odelia A0). The sweep then loads the
  invader's own solves in the resident's field. TF24 sets `differentiable_fitness`, as FF16
  does since `#658`.
- *Three numbers,* measured on the archived stack, to be re-measured by the PR's tests:
  - a resident and a mutant run together, and the mutant's fitness is bit-identical to its
    fitness invading alone (fails upstream);
  - the invader's sweep matches a central difference of invasions to 1e-7 (1e-10 in hmat and
    k_I);
  - offspring production's sweep matches the tangent to 2.1e-8 over 22 traits.
- *Cost.* About 30 header lines in odelia and about 40 in plant. A recorded invasion also holds
  one extra copy of each row, which upstream's recorded replays already pay. No resident number
  moves.

**PR B: TF24's step control.**
- *Problem.* A TF24 gradient run spends its steps where they cannot move `J`:
  - the soil layers hold every step to the plants' tolerance;
  - from t ≈ 25 of 40 at most 6% of `J` is still to be earned, yet 34–38% of the steps come
    after it (grid-dynamics.md §8).
- *Mechanism.*
  - A factor per state component multiplies its error level: one for the soil, and one by time
    from a schedule.
  - A bound keeps the soil's own error test in force: unbounded, an accepted step can carry a
    soil stage to the 1000 MPa ceiling.
  - `control_tf24()` names the setting once.
- *Three numbers* (coupled soil, before upstream's PLANT-105; M1 re-measures them):
  - 30.6–33.7% of a gradient run saved on three records;
  - the resident's worst distance to the 1e-5 reference falls from 0.18ε to 0.06–0.08ε;
  - episodic gradients go from 0 of 50 unbounded to 50 of 50 bounded.
- *Cost.* About 50 lines in odelia and about 120 in plant by hand, plus snapshot fields. Every
  default run is bit-identical.

**PLANT-107: crossed crowns summed tallest first** (after PLANT-93).
- *Problem.* On the birth-date coordinate, once two cohorts cross in height, the field build
  walks every node at every knot.
- *Mechanism.* Sort the nodes by height and take the same prefix. Each node adds an exact zero
  below its height, so only the order of summation changes, and only where crowns cross.
- *Three numbers:*
  - the walk costs 23% of a forward;
  - crowns cross on 20–79% of builds at 429+ introductions;
  - the sort costs 0.114 against 0.113–0.117 ms per row.
- *Cost.* +57/−15 and one test.
