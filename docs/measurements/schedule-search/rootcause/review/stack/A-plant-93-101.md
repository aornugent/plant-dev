# A. plant PLANT-93 → 101, PLANT-96, the averaged gate

Read from `git log`/`git diff` on origin (2026-10-18); no builds or runs. "Final" is
`harness/schedule/refine.R` + `refine_case.R`. Line counts are +/−. Default verdict: DROP.

## Summary

| branch | +/− | used by final | verdict |
|---|---|---|---|
| PLANT-93 exact counts | 625/403 | yes: `establishment_weights`, `interval_establishment` (refine.R:50–52) | **KEEP** |
| PLANT-95 (19 commits) | 23 433/7 378 | yes: gradient, pinned replays, offspring row | **SHRINK** (table below) |
| PLANT-97 storage offset (TF24 v12) | 2 003/1 819 (24 in the model) | yes: every run; t_r and the 15-d cap rest on it | **KEEP, as a declared model PR** |
| PLANT-98 stage guard out | 754/771 (−22 in the model) | yes: every run | **KEEP** (or merge into 97, so the reference is blessed once) |
| PLANT-99 walk the recorded run | 202/56 | no (only invasions use it) | **KEEP for invaders**; cut `SCM$runs` |
| PLANT-100 tolerance factors, bound, roundoff | 414/14 | yes: `ode_tol_factor_soil/times/values/max` | **SHRINK**: cut `ode_tol_factor_accumulator`; roundoff commit follows PHYLLOPTIM-17 |
| PLANT-101 field without newborn rates | 57/38 | yes: every evaluation | **KEEP** |
| PLANT-96 zero pulses as targets (side) | 193/27 | no | **DROP** |
| averaged gate b3a33626/6613dd24 (side) | 573/101 + 1 912/1 351 ref | no | **DROP** |

## Per branch

**PLANT-93** (`bae2dd9a`). Each birth-date interval carries its exact establishment E and first
moment M as states. The node's density state goes (`Species$log_densities_state` removed), and C++
`refine_schedule()` now raises an error.
*Bought:* point samples move J by up to 1.45ε when the introductions shift by a quarter spacing,
against 0.22ε with exact counts (design-schedule-building.md, "Exact counts stay"). That is
OBJECTIVES' reproducibility test. It also removed the cause of the 0.04–0.05× under-read in the
old estimate (field-adjoint-map.md, "the establishment gate"). *Dependents:* everything above it:
5a37615e, PLANT-101, 108's spread (`interval_shares`), the loop's records. *Verdict:* KEEP.
Dropping it loses the 1.45ε → 0.22ε reproducibility.

**PLANT-95**, judged commit by commit:

| commit | piece | +/− | needed by | verdict |
|---|---|---|---|---|
| 61af9238 | model at the caller's scalar; Hermite light field in u = h/h_max; **TF24 v11** (`R_d_25`, root curve as (P50, c), `vulnerability_curve_ncontrol` 400) | 7398/3051 | `census_trait_gradient_tf24` (refine.R:59) needs the active scalar | KEEP. Name v11's three model changes in the upstream PR; they sit inside a templating commit |
| b46c224b | one schedule row per instant | 316/235 | `apply_insertion`, pinned walks | KEEP |
| 45692c0f | census gradient: `stand_gradient`, `stand_census`, `_state_adjoint`, `gradient_control`, `_refused`, `_compare`, `census_*_tf24` | 926/0 | the loop's elasticities | KEEP |
| e36f6859 | sweep referees: `src/gradient_ladder.cpp` (1067 lines, 24 `ladder_*` exports, all test-only) + 14 test files + reference tsv + **`overstorey_staging/` demo (391)** | 9043/0 | regression net, not the loop; it found PLANT-108's unset boundary node (handover.md:137) | SHRINK: delete `overstorey_staging/`, which nothing later touches. Ladder exports compiled into the shipped .so break AGENTS' "no demo code in the .so"; moving them out is a later subtraction, not a rebase |
| 46b64768, 3ed7df2c, b34b420d, f1ece07b | bindings; delete odelia copies (−729); suite follows; NEWS/guide, six scripts gone | — | required by 61af9238 | KEEP |
| 1b851995 | test: a program replayed by its times | 34/0 | pins the loop's replay mode | KEEP |
| 5cf9e937 | `error_index`/`error_ratio` per row | 7/0 | PLANT-100's test (test-scm.R:449); the soil-binding measurements | KEEP |
| a6b92a19 | `SCM$ode_step_attempts` | 135/1 (mostly generated) | the failure tally behind 98's 149 → 0; five harness drivers | KEEP (OBJECTIVES "Diagnosed: its failures") |
| 19a51aa3, 4f8d9ad5 | offspring production as a census row and sweep seed; its referee | 260/102 | `census_trait_gradient_tf24(scm, "offspring_production")` | KEEP |
| 5a37615e | suite and reference follow PLANT-93 | 2126/1527 | PLANT-93 | KEEP (it is 93's test fallout) |
| f3550290, b737a9b5, 25e21a70 | invaders in the recorded field; one entry map; exact invasion; refuse an unreached entry | 639/624 | OBJECTIVES invaders; PLANT-99/102/103/106/109; the window weight files (built from invader walks, `harness/window_rule.R`) | KEEP. b737a9b5 is net −90 lines and fixes a 5e-9 ulp amplification |
| 77cf5bbd | inflow before an event at an introduction (a model rule; moves harvest-at-introduction 0.22–0.54%) | 24/25 | only events, which neither final nor OBJECTIVES use; b737a9b5's single map rests on it | KEEP (net −1). Dropping it means rewriting b737a9b5 |
| 4d147107 | a pinned run is one walk of rows | 128/98 | the loop's pinned replays (refine.R:34–35) | KEEP |

No piece of PLANT-95 is removable scaffolding except the demo (`overstorey_staging/`). The test-only
C++ in the .so is the one structural debt.

**PLANT-97** (`b4b5febf`, `storage_relaxation_offset` = 7 d, a gradient column; TF24 v12).
*Bought:* thrown attempts 759 → 149 on the long-drought stand; invaders at lma ×1.001–×1.05 (height) and to ×1.2
(birth date) run on the resident's steps (archive/scope-imex-stepper.md §3, *Result*). *Moves the model:* J +2.0/+2.6/+2.7%
at 108/215/429 nodes, dJ/dlma −168.6 → −196.0, height pins −24%.
*Is it a model change that belongs here?* It is a model change, chosen for a numerical reason:
7 d makes explicit steps stable to about 26 d. The user decided it ("Decided: A", same §). So it
belongs upstream as its own science PR with the v12 note, not slipped through as numerics.
It must stay below the loop, though, because two of the final configuration's constants are
derived from it:
- **t_r.** After P < 0 the rate is −drain·r/(1 + (drain/S_max)·o). A seedling has drain/S_max of
  order hours⁻¹, so dr/dt ≈ −r/o: every seedling's reserve decays with e-fold time o, whatever its
  size. Reserves fall from a_st3 to the hazard's e-fold point 1/a_dG2 in t_r = o·ln(a_st3·a_dG2)
  = 19.4 d (evidence/notes.md, Round 5). With o = 0 (v11) that time is S_max/drain: hours, and
  set by size. So t_r would not exist as a parameter expression, and the grade's width would have
  no first-run-free predictor.
- R17 measured the width at 0.74–1.10 × t_r. R18 doubled o and the width rose ×2.2–2.4, but the
  profile turned into a hump 0.6 t_r before the end. So `grade()`'s shape constants (0.95, 1.4,
  0.45, height 2) hold at o = 7 d only. If upstream changes o, t_r follows by formula and the
  shape must be re-measured.
- **The 15-day cap** is 2.16·τ_s, where Cash–Karp's fourth stage goes negative
  (grid-dynamics.md §8, "Root cause"). It protects walks only because τ_eff ≥ τ_s.

*Verdict:* KEEP, re-labelled as a model PR. Dropping it changes every TF24 number, re-blesses
every reference, re-measures t_r, the grade and the cap, and puts back invader throws.

**PLANT-98** (`7dbd87c3`). Removes the stage guard and `storage_domain_tol`; a negative pool at a
step's end is still refused. *Bought:* throws 149 → 0 and invaders lma ×0.7–×2 run. J moves
1.2e-6 at 1e-4 (commit message). *Verdict:* KEEP, since it is a deletion. Merging it into 97
saves one recapture of `reference-gradient.tsv` (1438 lines of churn).

**PLANT-99** (`457f08bb`). A recorded run keeps each evaluation's field in `built`; adds
`SCM$runs`. *Bought:* the first invasion takes 139 s against 300 s (grid-dynamics.md §3), about
12% of a both-roles gradient run. *Price paid by the loop today:* `record_trajectory` now also
keeps fields, +130 MB resident at u108 (7.4 kB a step). The loop records every run and invades
none. *Dependents:* PLANT-102 moves the `built` loop; 109 edits the comment. *Verdict:* KEEP for
OBJECTIVES' invaders. Cut `SCM$runs`, a public counter that exists only for test-mutant.R:215:
dropping it removes about 70 generated lines, at the cost of a small conflict in 110's
regenerated bindings.

**PLANT-100.**
- 812248f5 and 858340b0 add `ode_tol_factor_soil/_times/_values/_max` and
  `Patch$tolerance_factors`. *Bought:* soil ×10 with rule A, the 15-d cap and a bound of 100 saves
  33.7/33.1/30.6% of a gradient run, and every gradient stays finite (grid-dynamics.md §8,
  "Bounded at 100"). All four are in refine_case.R.
- `ode_tol_factor_accumulator` has no measured use: "the flux accumulators never bind at
  atol ≥ 1e-4" (perf-step-controller.md:162), and final leaves it at 1. Cut it (about 30 lines;
  the snapshots in 100 and 105 move).
- 631bbab3 (TF24 v13) is the plant side of PHYLLOPTIM-17: `height_seed` takes phylloptim's
  roundoff uniroot. *Bought:* replay noise 2.7e-8 → 8.5e-15 in ln J (§18, *Finished*). That noise
  is already ≪ ε for J and for curvatures at r = 1e-2: 2.7e-8/1e-4 ≈ 3e-4 against ε = 1.17 (§17,
  §19). *Cost:* 1.12× a replay, mostly phylloptim's.
- Verdict: the same as PHYLLOPTIM-17's. Its only measured use was resolving split choices by
  bisection. If it goes, ln J moves 1.5e-6, so the loop constants stand. One test-scm.R pin and
  the version snapshot are re-blessed.

**PLANT-101** (`df844b46`). *Bought:* drops a leaf solve nothing read, 39% of a split's part
evaluation, bit for bit (§18, *Finished*). *Verdict:* KEEP.

**PLANT-96** (`855f64ee`, off 95). Zero pulses become step targets. *Bought:* on the fixture with
500 pulses, a run is 12% faster and a sweep 50% faster. But PLANT-105's 6dfa29fb substeps the soil
at the rain's knots "so ... callers pass none", and final passes no pulses
(`events(events_default(p))`). *Verdict:* DROP. Close #96; nothing depends on it.

**Averaged establishment gate** (b3a33626, 6613dd24). Sits on the pre-rebase PLANT-95 (`bb1d8a8a`),
so it has no exact counts and no offset. TF24 v12 there; v14 when ported.
*Bought on that base:* the fixed-grid dJ/dlma second difference is +6.9 against −10768, and J
+0.5%. *But:*
- design-shared-sign-changes.md R8 says "the averaged gate will not land";
- ported onto the stack (round4/AG/notes.md §1, 9 conflict sites), the edge mechanism stays
  at about 70% of its size, a09's pair fails C3 on dry, and lib19 references cannot score it
  (up to 2.6ε);
- invaders' walks were never ported.

*Verdict:* DROP. *Cost:* the plant-dev submodule pointer is 6613dd24 today. Move it to the chain
head and archive `origin/establishment-window`.

## Costs of these verdicts

- No KEEP changes numerics. The SHRINKs below have no effect on numerics:
  - deleting `overstorey_staging/`;
  - cutting `SCM$runs` and the accumulator factor (bit-identical at their defaults).
- Each of those SHRINKs is an amend in its owning branch, then `rebase --update-refs`. The
  conflicts are only in regenerated bindings and snapshots (PLANT-100, 105, 110).
- Re-measurement would be needed only if PLANT-97 were dropped or its o changed: t_r, the grade,
  the 15-d cap, every reference.
- Dropping 631bbab3 with PHYLLOPTIM-17 moves ln J by 1.5e-6, well below what the 0.82 and 0.33ε
  constants resolve.
