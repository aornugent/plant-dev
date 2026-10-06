# Batch: the step that holds a sign change is the unit of treatment

## Triage: 3 — it threads odelia's stepper, recording and sweep and plant's rates, the incumbent's ~1.7k lines drew "rethink the orchestration", and every pass will depend on the unit of treatment.

## Requirements ledger
R1–R13 as the ledger states them, with three readings:
- R1 at OBJECTIVES' 0.01 floor: plain's worst moves at 1e-4 are a_dG1 1.05, storage_relaxation_offset 0.98, a_dG2 0.91 ε/3; the ledger's d_I 1.261 uses its unfloored ε (0.00047), 0.06 floored. (Challenged upward: does the floor apply to R1? Default: yes; this design passes either way.)
- R7: invaders walk the cut steps too, so an invader's crossings that fall in them get the shorter steps. (Question: enough, or must invaders be treated wherever they cross? Default: as today.)
- R8 states its bar per pass; this design is +8.4% forward (bar 6.0) and +5.2% sweep (bar 7.3). (Question: is the bar a run's total? Default: yes, scored on a resident gradient run.)

Scarce resource: about one row per step that holds a sign change. R8's bar (+6.0% forward, +7.3% sweep) is 1.2–1.5 rows for each of those 726 steps in 14 845, so the treatment must buy R2's ≥1.7× cut in lma's chord spread (0.56 ε → under 0.33 ε) with about a row of work per crossing step, in the least code (R9).

## The floor
Plain at the tol where R1–R2 pass. Steps around crossings shrink as √tol (5.3, 1.66, 1.02 days at 1e-3, 1e-4, 3e-5) and plain's nudge sd falls 5× (lma) to 15–22× (storage traits) from 1e-4 to 1e-5, so R2 needs tol ≈ 4.8e-5 [inferred]: +12% rows on every pass. The measured remedy, 1e-5, costs +41%. **Fails R8:** +12% against the bar's 6.9% on a resident gradient run.

## Candidates
The move bites on code, not runtime: the incumbent's 0.38 ms per split node step is its 26 node ratings at 15 µs, all rating work, and its reads and end rating are already per step. Per item, it pays orchestration in every pass.
- **A [first thought], batch the incumbent's per-item costs.** Keep per-node cuts; locate each from ratings at shared fractions ¼, ½, ¾. Location is ~9.5 of 26 ratings: the forward saves ≤ 1.5%, the sweep pays ~1% back, and the leaf's C⁰ class-switch kink in P (median 0.26 days before an upward crossing, in crossing steps of median 0.86 days) breaks location on a quartic. Wins when every crossing must be cut exactly.
- **B, batch at the step.** 9247 node-step items become 726 step decisions: a step across which any node's net production changes sign is taken again as m = 2 equal steps, and every pass sees ordinary rows. Pays for R1–R2 by halving the crossing steps; costs whole rows (latency granularity: a median 7 of 59 nodes cross in a cut step). Wins when two rows per crossing step buy R1–R2, as measured.

The move does not lead back to the per-node cut. No batch is exact, since nodes cross at their own times and only a node's own cut puts its kink on a piece boundary; but R1–R2 ask for stability, not exactness.

**Winner: B.** A keeps ~800 lines (R9) for under 0.5% of a run (R8). B beats the floor on R8: 6.1% against 12% of a resident gradient run.

## The commitment
A sign change is treated by its step, never by its node: an accepted step across which a node's net production changes sign is taken again as m equal steps, and every pass sees only rows.

Kept true by: the treatment's only output is step ends in the recorded program. `solved_row` gains no field and the System no per-node rating entry, so no pass can express a per-node treatment.

## Kill question
Assumption whose falsity makes this unnecessary: a global tol tight enough for R1–R2 costs more than R8's bar.
Verdict: **survives.** The ledger's remedy (1e-5) costs +41%, and the incumbent at matched stability is 0.77 of it; my inferred 4.8e-5 still costs +12% on every pass. What would kill B instead, halving the crossing steps cutting the spread too little, was tested: R2 0.558 → 0.249 ε (bar 0.333).

Consistency: B spends two rows per crossing step in the forward (one discarded, one added) and one in each later pass: 6.1% of a resident gradient run against the bar's 6.9%, 5.7% of a seven-pass run against 3.6%. m = 3 would cost a resident run +11%, so B holds only at m = 2, where the data puts it.

## What survives deletion
- `sign_values(out)` on the System (Patch: each node's net production) → R1–R2: which steps to cut.
- `sign_value_aux()` on TF24's strategy → R12: the model names its kink.
- `CutsAtSignChanges` (odelia concept) → R10, R12: FF16 compiles no detection; odelia sees values, not nodes.
- `sign_values_in` (the readings where `dydt_in` was taken, refreshed beside it) → R1–R2: a step's end is compared with its start.
- `cut_sign_change_steps` (odelia control) / `ode_cut_sign_change_steps` (plant) → R10: 1 leaves every run bit for bit.
- `step_outcomes::cut` → no guarantee dropped: every attempt stays counted, and `accepted + accepted_at_minimum` still counts rows.
- `sign_changes_cut` / `ode_sign_changes_cut` (per node, cut steps where it changed sign) → R11.

Deleted: stage readings for pairs (ends only, as the spike ran), plant's `NamesSignValue` (a requires clause instead), the slowest-crossing record (no ledger line).

## What this settles
- Not built: location, the dense output, field reads, per-node pieces, records and taped pieces, the sweep's implicit-function cut, plant's per-node rating path, the tangent walks' refusal, the invaders' opt-out; four detection rules become one.
- Cannot occur on a frozen mesh: a choice that jumps. R3's jump is zero (a replay's noise, 8.5e-15); R4 is the existing sweep of a pinned program (1.6e-5 from a central difference); J′ = J because invaders walk the same rows.
- One decision per step, made once by the forward, serves every pass and every θ of a local analysis; R6 gains no failure path, since a cut step is shorter than one already accepted.

## What this makes hard
- **Exactness.** The kink's error shrinks, does not vanish, and its residue is a draw, not a leading term: B's spreads are 1.3–5× the incumbent's (a_dG1 0.43 against 0.17; R2 0.25 against 0.05 ε). Gradients at 3e-4, chords below r = 1e-2 or a tighter ε need more, where the incumbent could spend its margin on 3e-4's 1.2× fewer steps.
- **The radius.** m = 4 gives 0.160 ε, not half of 0.249: past m = 2 the residue is set by crossings that leave the cut steps at ±r [inferred: 24% of crossings have no cut step on their nearer side; ~650 change step at r = 1e-2]. Cope: also cut the crossing steps' 330 uncut neighbours (+2.2% rows) [untested].
- **Invader passes pay rows:** +5.7% of a seven-pass run against the incumbent's +3.6%.

## Kill condition
A requirement that each crossing be cut exactly, as gradients at 3e-4, chords below r = 1e-2 or an ε tightened ~2× would impose: B's rows then exceed the per-node cut's 1.2–1.5 per crossing step. Hand off to A, the per-node cut with its per-step costs batched.

## The design
**odelia (~65 lines, ~60 of test).** `CutsAtSignChanges<System>`: `cs.sign_values(out)` writes one value per kink after every evaluation. `Step::step` reads the end's values; `SolverInternal` keeps `sign_values_in` beside `dydt_in` at its three sites. In `SolverInternal::step`, an attempt that passes the error test and the state check, and whose end readings differ in sign from `sign_values_in` in any entry, counts as `cut` and is taken again from its start as `cut_sign_change_steps` equal steps, each pushed as an accepted row; once they are, `sign_changes_cut[i]` counts each entry that changed. A sub-step that throws or fails the state check pops the attempt's rows and rejects it as today; the next proposal is the attempt's. `step_to` and `step_by` (replays, walks) never cut. Tests: a toy kink's step becomes m rows; m = 1 and replays are bit for bit; the sweep matches central differences.

**plant (~45 lines, generated glue, ~40 of test).** TF24's `sign_value_aux()`; `Patch::sign_values`; `Control::ode_cut_sign_change_steps` (default 1); `SCM` reports `ode_sign_changes_cut` and a `cut` attempt count. Tests: TF24 at 2 cuts every crossing step and replays bit for bit; FF16's guard bit for bit.

**Cost, from counts.** Halving the 726 crossing steps adds 4.9% rows and 5.2% leaf solves to every replay, sweep and walk (rp_h1 → rp_h2); the forward also discards one attempt per crossing step: +8.4%. Resident gradient run +6.1% (incumbent 6.9%); seven passes +5.7% (incumbent 3.6%).

**Size.** ~110 hand-written lines against the incumbent's ~790. It deletes ~550 of the incumbent's ~600 odelia code lines (the split, its pieces, dense output, reads, taping, records and concepts) and ~150 of its ~190 in plant, keeping #100 (roundoff leaf solves) and #101 (the newborn seated unrated).

**Measured** (lib_rr, reverse mode, the driver's programs at 1e-4 and its six nudges; largest move from the 1e-4 run in ε/3, floored ε):

| | plain | B, m = 2 | incumbent (§11, §17, §18) |
|---|---|---|---|
| a_dG1 | 1.05 | 0.43 | 0.17 |
| storage_relaxation_offset | 0.98 | 0.36 | |
| a_dG2 | 0.91 | 0.33 | 0.14 |
| TF24_cost_scale | 0.90 | 0.32 | |
| lma | 0.48 | 0.13 | 0.06 |
| d_I, unfloored | 1.26 | 0.37 | 0.28 |
| R2: lma second difference at 1e-2, spread / mean − (−43.45) | 0.558 / −0.40 ε | 0.249 / −0.02 ε | 0.05 ε / within 0.015 ε |
| R4: sweep − central difference in lma, half-width 1e-6 | | 1.6e-5 | 2.7e-4 |
| the same at half-width 1e-3 (smoothness) | 3.1e-3 | −7.8e-4 | |
| ln J − ln J* | +3.5e-5 | −1.0e-5 (m = 4: −1.9e-6) | +3.4e-6 |

## Spike files
In `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/design/spikes/batch/`:
- `nudge_scaling.R` (`.log`): plain's nudge sd from 1e-4 to 1e-5 (`docs/measurements/nudges`) falls 15–22× for the storage traits and 3–6× for lma-like traits, for 1.43× the steps.
- `crossing_steps.R` (`.log`): steps that hold a sign change (median 0.86 days, error ratio 0.48 against 0.13 overall) and their neighbours shrink as √tol.
- `cluster_rows.R` (`.log`): the 726 crossing steps lie in 153 runs; a median 7 of 59 nodes cross per crossing step; 76% of crossings have a crossing step on their nearer side.
- `toy_cut.R` (`.log`): on a kinked pool, cutting the crossing steps in two shrinks a gradient's nudge spread 1.9× where the parameter moves the crossing and 3.8× where it does not (m = 4: 5.7×, 15×).
- `make_programs.R`: the driver's seven programs (`dev/events/runs/g_<tol>.rds`) with their crossing steps (`slq_<tol>.rds`) cut into m = 1, 2, 4.
- `run_grad.sh`, `chain3.sh`, `arms*.txt`: 14 reverse-mode gradient runs and 27 forwards on `lib_rr` through `harness/run_record.R`; outputs in `runs/`.
- `analyze.R` (`analyze.log`): over seven tolerances plain's largest move is 1.05 ε/3 (a_dG1) against B's 0.43, a median ratio of 3.2 over 23 traits; R2's spread is 0.558, 0.249 and 0.160 ε at m = 1, 2, 4.
- `r4_check.R` (`r4_check.log`): B's sweep lies 1.6e-5 from a central difference of half-width 1e-6, and 7.8e-4 from one of half-width 1e-3, where plain's lies 3.1e-3.
- `prereg.txt`: predictions written before the runs, and outcomes: P1–P2's split by trait class missed, the median held; P3 and P4 held.
