# Landing the trusting-curie stack

**Status.** This is the state of every piece of work from the `trusting-curie` branch, as of
2026-10-22. PR and issue states were read with `gh` that day. The verdicts come from the
residual review of 2026-10-19: `docs/prs/residual.md`, `residual-A.md`, `residual-B.md` and
`measurements.md`. Those files are on the tag `archive/trusting-curie` and are not copied here.
Items marked **action: user** are outward-facing, such as opening, closing or commenting on a PR
or issue. They wait for the user.

## 1. Open PRs

**plant.** One stack over `develop`, merged bottom up:

| PR | branch | what |
|---|---|---|
| plant#94 | PLANT-93 → develop | Integrate establishment exactly on the birth-date coordinate |
| plant#113 | PLANT-97 → PLANT-93 | Add a week to the storage pool's relaxation time (closes #97 and #98) |
| plant#114 | PLANT-107 → PLANT-97 | Sort crossed crowns before summing the light |
| plant#115 | PLANT-105 → PLANT-107 | Substep TF24's soil so runs need not stop each day (odelia 0.8.1) |
| plant#116 | PLANT-95 → PLANT-105 | Differentiate TF24 fitness, invaders included (odelia 0.9.0) |
| plant#118 | PLANT-117 → PLANT-95 | Differentiate a trait along the trade-off it was built along, by default (closes #117) |

**odelia.** odelia#57 (ODELIA-55 → master) substeps a System's stiff part. odelia#60 (ODELIA-59
→ ODELIA-55) hands each rate evaluation its slot of the step's row. It replaces odelia#58, which
was closed on 2026-10-20.

**phylloptim.** phylloptim#21 (PHYLLOPTIM-18 → master) differentiates the leaf wherever its solve
answers (closes phylloptim#18 and #19). It stands alone.

**Merge order.**
- phylloptim#21 and odelia#57 come first, in either order.
- odelia#57 comes before plant#115, which links odelia 0.8.1.
- odelia#60 comes before plant#116, which needs odelia 0.9.0.
- plant merges bottom up: #94, #113, #114, #115, #116, #118.
- PLANT-97 (#113) must land before the invader work (#116). Without it, an invader's storage
  pool overshoots beyond about ×1.0001 of the resident's lma (`residual.md`, *Order*).

**Later work stacked on top.** odelia#62, plant#122 and phylloptim#23 (all ODELIA-66) rename the
reverse-mode API. They were opened after the tag.

## 2. Verdicts from the residual review

**Measured reasons.** Each verdict comes from the review's measured reasons, and the
predictions were written down before the runs (`measurements.md`).

**Landed as open PRs:**
- *Exact counts* (PLANT-93, #94). A shift of the introductions by a quarter of their spacing
  moves J by 0.22ε, against 1.45ε with point samples.
- *The storage relaxation offset* (PLANT-97 + 98, #113). Thrown stages fall from 759 to 149,
  then to 0. It is a declared model change (TF24 v12): J moves by +2.0–2.7%.
- *The crown sort* (PLANT-107, #114). It avoids a walk over every node that costs 23% of a
  forward, and the sort itself costs nothing measurable.
- *Soil substeps* (PLANT-105 with ODELIA-55, #115 and odelia#57). A gradient run costs 0.63 of
  the coupled run, and the substeps cure the stiff-soil blow-up.
- *TF24 fitness, as resident and as invader* (PR A in `residual-A.md`). This is plant#116 with
  odelia#60, redesigned since the review. Invaders now read the field by slot and time instead
  of copying the resident's row (`docs/design-invader-environment.md`).
- *PHYLLOPTIM-18 and 19, and 17's bisection refusal* (phylloptim#21). These fix gradient
  refusals at `1e-4` on long drought, and one gradient row that read 0.053 where the true value
  is −0.83.

**LAND, with no PR yet: the per-state tolerance factors and `control_tf24()`.** This is PR B in
`residual-A.md`.
- *odelia B0.* Take commit 30f9a7b. A System fills one positive factor per component at the start
  of a step. `adjust_step_size` scales each component's error level by its factor under both the
  GSL max rule and Hairer's RMS rule. It applies at the outer error test only. A System without
  factors steps bit for bit as before.
- *plant B.* PLANT-100 without `ode_tol_factor_accumulator`, plus PLANT-104. That gives
  `ode_tol_factor_soil`, the `_times/_values` schedule and `ode_tol_factor_max`, and
  `control_tf24(tol = 1e-4)`, which also sets the absolute tolerance, the 15-day cap and the soil
  share. It stacks on PLANT-105.
- *Measured (M1, on the substepped soil).* The factors save a quarter to a third of a gradient
  run, and accuracy is unchanged against a `1e-5` reference.
- *Still to do.* M1 ran on odelia 0.5.0 under GSL's max-norm rule. odelia now defaults to
  Hairer's RMS norm, so B0 must be re-timed on one case under that rule before it opens. The soil
  factor and the time schedule were not measured separately. **action: user** (opening the PRs).

**HOLD, then LAND last: the scheduling algorithm.** This is `harness/schedule/refine.R`
(`docs/schedule/refine.md`), plus about 30 lines of PLANT-110's `diagnose_scm`: each run's
distance from the grid's run, the invaders' ln(θ′/θ), and failures. `residual-B.md` §3 lists four
steps before it opens.

**DROP:**
- *Splits at sign changes* (PLANT-102 and 103, odelia's split commits, ODELIA-54). They buy no
  blow-up protection, because the soil substeps cure the blow-up, and they buy no accuracy at ε:
  at most 0.07ε in the answer.
- *PLANT-99, walking a recorded run without repeating it.* The saving is 68 s per resident,
  which is 10.2% of a gradient run with one invader and about 2.4% across ten invaders. It holds
  about 114 MB per run (M3). plant#116 now reaches the same end another way: a resident run that
  kept its states feeds the first invasion without a replay.
- *Root-finds to roundoff and the newborn's height* (PHYLLOPTIM-17 6b6f152, 631bbab3). On
  phylloptim 0.10 the replay noise is already 4.0e-13 rms in `ln J`, under the 1e-12 bar. No
  gate can see it.
- *PLANT-101.* Without splits it saves one leaf solve per species, under 1% at 108 nodes.
- *PLANT-96.* The soil substeps supersede it.
- *PLANT-106 (`control_window()`) and PLANT-109 (subset walks).* Nothing uses them. Upstream has
  nothing like them.
- *PLANT-110,* apart from the part that moves to the scheduling PR.
- *The averaged establishment gate.* The design says it will not land.
- *Step diagnostics* (which component set the step's size, how each attempt ended). These are
  diagnostics only, and the binding component is a max-norm notion. One option is to expose
  odelia's `n_rejections` per run in PR B.
- *Upstream has it already:* PLANT-95's scalar templating, census gradient and sweep referees
  (upstream #648, #657), and ODELIA-53's caller's scalar, recording and walks (odelia 0.7–0.8).

**Left to the user: the spread** (PLANT-108). It puts node error on the square law, so a coarser
run estimates the error honestly. It also makes FF16 9–25× worse at FF16's default schedule.
The drop test is in `stack-split.md`.

## 3. Unlanded commits and branches

All of these are on the aornugent forks. None is in any PR.

- **plant b3a3362 and 6613dd2** (on `establishment-window` only, 15 ahead of `develop`). They
  average TF24's establishment gate over a declared window, and re-capture the gradient
  reference for it. Their verdict is DROP. *Question:* does PLANT-93's exact establishment
  (plant#94) make the gate's averaging unnecessary? If it does, close #92 with that reason.
  **action: user**.
- **plant 7a0631d and 5321593, with odelia 2e172e3 and be3e2cb.** These are the step
  diagnostics. Their verdict is DROP as built (see above). Nothing is lost if they stay on their
  branches.
- **plant 16f2148** replays a program at other parameters by its times. It is a test only, and
  upstream's `program_within` covers it. DROP.
- **plant bb1d8a8** referees offspring production on its own scale. The review put this lesson
  into PR A's tests. *Check* that plant#116's fitness test referees each row on its own scale.
  If it does, drop the commit.
- **`PLANT-110`** (64 ahead of `develop`, 10 behind; identical to
  `archive/stack-2026-10-18/PLANT-110`). This is the whole pre-review chain, PLANT-96 to 110:
  `control_window`, `ode_splits`, `ode_tol_factor_*`, `ode_step_attempts` and soil-alone
  stepping. Only the tolerance factors and `control_tf24()` (LAND, §2) and `diagnose_scm`'s 30
  lines (HOLD) are worth taking. Port them fresh onto the landed stack; do not rebase the chain.
  Soil-alone stepping became ODELIA-55's substeps (#115).
- **`state-weights`** (plant and odelia) is the source of PR B's tolerance factors. Take odelia
  30f9a7b from it, then delete the branch.
- **`sign-changes`** (plant and odelia) and **`archive/sign-changes-incumbent`** hold the first
  build of the splits. They follow the splits' DROP.
- **`ark-soil` and odelia `ark-step`** hold the implicit soil chain, which was retired when the
  soil stepped on its own matched it (0.98 of its member evaluations). DROP.

Deleting any of these branches is the user's call. **action: user**.

## 4. Issues to close or annotate

**action: user** for each.

- **Close: plant#92** (averaged gate), **#96** (superseded by the soil substeps), **#100**
  (noise of 4e-13, below any gate), **#101** (under 1% without splits), **#106** and **#109**
  (unused), and **phylloptim#17** (DROP, apart from the bisection refusal, which ships in
  phylloptim#21).
- **Close or annotate: plant#99.** M3 dropped it, but plant#116 removes the replay of the first
  invasion. If #116 resolves #99, close it with #116.
- **Annotate: plant#110.** About 30 lines survive into the scheduling PR. The rest is dropped.
- **Annotate: plant#108.** It is waiting for the user's decision on the spread.
- **Close: plant#102 and #103, and odelia#53 and #54 (the splits).** Close them once the splits'
  DROP is confirmed (see *Unsure*).
- **Annotate: plant#104.** It lands in PR B, together with the tolerance factors.
- **Comment on odelia#57.** It does not say why the substep trigger is C. The rationale is
  `docs/prs/v2/trigger.md` on the tag:
  - the error estimate over-reads rather than under-reads (a median estimate/true of 6.2 at
    K = 10);
  - why substepping costs at small K;
  - the trigger, and what it deletes (`subsystem_weakly_coupled()` and the tuned fraction).

  Post a condensed version as a comment.

## 5. Links that need the tag kept

The tag `archive/trusting-curie` is on `origin`. It is the only ref that reaches the plant-dev
commits these links name. Deleting it, or deleting `claude/trusting-curie-4i9n3l` without the
tag, breaks them once GitHub prunes the commits.

- **17 links pinned to 2902d2b and 2cd5220.** 15 are figures:
  - plant#113: 3;
  - plant#114: 4;
  - plant#115: 2;
  - plant#116: 2;
  - phylloptim#21: 2;
  - odelia#57: 2, pinned to 2cd5220.

  The other 2 are plant#113's `offset-run.R` and `offset-run.csv`. Each figure's script, data
  and `notes.md` (the source of every number) sit beside it under `docs/prs/v2/` on the tag.
- **phylloptim#21's unpinned path.** It cites `docs/prs/v2/figures/phylloptim-21/` as a bare
  path, which is not on main. Edit the comment to pin it to 2902d2b. **action: user**.
- **plant#118's design link.** It cites plant-dev's `docs/design-trait-gradients.md`, which is
  restored at that path. plant#116 and odelia#60 rest on `docs/design-invader-environment.md`,
  which is restored beside it.

## Unsure

- **The splits: settled as DROP.** `residual.md` and `residual-B.md` put the splits on HOLD
  pending an 18-run measurement, and no record of that measurement exists. But the user's
  decisions of 19 October drop them: they buy ≤ 0.07ε in the refine loop's answer, and their
  reproducibility gain was measured before the soil substeps (`design-grid-controller.md`,
  *The user's decisions*; `schedule/time-axis.md`). Closing #102, #103 and odelia#53 and #54 is
  still **action: user**.
- **Whether plant#116 supersedes PLANT-99 and closes #99.** This is inferred from #116's text,
  not tested.
