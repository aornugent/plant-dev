# Review: the built refine loop (`harness/schedule/refine.R`, `refine_run.R`, `refine_case.R`)

Assembled from four passes: a blind clean sheet (`clean-sheet.md`), a cold read with
predictions written before bodies (`cold-read.md`, 18 misses in 53), a correctness hunt with
executions on saved runs (`correctness.md`, F1–F15), and lenses 2–4 (`lenses-2-4.md`).

## Verdict: approve with changes

The documented path is correct, and it reproduces the evidence the design rests on:
- **Run setting:** a forward run of `refine_run.R` on round 5's G5 dry nodes gives round 5's J to
  every digit, with the same steps.
- **Schedule:** fed round 5's inputs, `schedule_of`/`nodes_of` reproduce G5 and its replay node
  for node on all five cases.
- **Loop:** with the run backend mocked by the saved runs, the loop asks for exactly the saved node
  times and reproduces every saved `fit.rds`. Signs, units and the /3 and /(4^k − 1) divisors are
  right, and ε matches the scoring's on all 47 shared quantities.
- **Nesting:** at scales 1 and 0.5, levels 0–3, every level contains the one below and the replay
  lies inside level 0.

What must change lies around that path: ways to fail or to go silently wrong that the five cases
never hit, a quantity set that differs from the evidence's, and TF24's facts spread over the
code. The canonical configuration (scale 1, first-run inputs) has never been run end to end; it
differs from round 5's layout only in its inputs (spell edges shift a median 0.3–0.6 d, and b1 by
about 9.5 d on the two episodic cases).

## Triage: 3

It becomes plant's public tool for converged runs, and its fit object is the API.

## Ledger

`docs/design-refine-schedule.md` (R1–R6, the algorithm, G1–G6, "What survives deletion",
"What a strategy supplies") and AGENTS.md's code rules.

Design doc check: the commitment's "kept true by structure" holds for even counts (the count
rule cannot produce an odd count above 1) and for the unseen term (one bound expression), but
nesting is kept by arithmetic plus `round(S, 10)`, not by structure (Keeper). Nouns not on the
doc's survives-deletion list: `MARGIN` and the per-pass jump cap of three levels, the runner
`refine_run.R`, and the excluded-quantity list.

## Clean sheet

About 150 lines in eight parts, the same structure as the code. It differs in four places:
- the replay's nodes are taken by index from the run's own times (`i %% 2 == 0`), not
  recomputed;
- one estimate formula, (Qc − Qf)/(4^j − 1), serves the replay as j = 1;
- the fit is rebuilt from the run files on disk, so resuming needs no extra code;
- one runner, `run_record.R` with the establishment record added, not two near-copies.

## Prediction record (Lens 1, 18 misses in 53)

The misses that change behaviour:
1. `spec` silently needs `lib`; without it a different, unoptimised plant loads with no error.
   A missing `seed` falls back to the regime's.
2. `trait` multiplies one raw parameter after the strategy is built, so `lma=0.25` leaves the
   seven parameters TF24 derives from lma at lma 0.32's values. This matches round 5's runner
   and the parameters it built, so the evidence is consistent; it is not what plant's own
   trait moves do.
3. `MARGIN` is not the acceptance threshold; it only sets how many levels a pass jumps.
4. A pass jumps one to three levels, not "doubles every count", with a silent cap at three.
5. A finished run file is reused whatever its times, scale or settings.
6. `quantities` drops `S_D`, `a_f3` and `recruitment_decay`, which OBJECTIVES gives ε = 0.01.
7. `fit$schedule` is a summary that cannot be fed back to `nodes_of`, so later runs cannot use
   the kept schedule.
8. `ATOL` multiplies `TOL`.

## Decisions reopened

- **D1:** chose doubling on reject with the rejected run as the estimate, over √ rescaling with a
  replay each pass. Settled by R5 and G6.
- **D2:** chose spell ends read once from the first run, over re-reading them each pass. Settled
  by nesting, and R21: level 1's own ends sat within 2.5 d.
- **D3:** chose a new runner, over extending `harness/run_record.R`. UNSETTLED → Q1.
- **D4:** chose TF24's facts written into refine.R, over one place a strategy supplies them.
  Against the design's own "What a strategy supplies" → S2.
- **D5:** chose copies of `eps_of`/`quantities`, over a shared file. UNSETTLED → Q2.

## Change simulation

- **The port into plant** → the schedule functions carry over; the records do not:
  `refine_run.R` decodes `store_trajectory()` rows by hand-computed state offsets to recover
  the establishment rate and T(t). **Leaky.**
- **Another strategy** → `grade`, `reserve_time`, `spacing_of`'s constants, `READ`/`UNSEEN_*`,
  `eps_of`, the excluded quantities, `SETTING`, and the runner's TF24 controls: eight sites that
  must agree. **Shotgun.**

## What must always be true

Every estimate is a difference between nested schedules: replay ⊂ run, level k ⊂ level k + 1.
Kept true by: convention (equal shares plus rounding). It held on every case and level tested.

## Structural findings

1. **A run is reused by name only (F1)** — makes rerunning a case at another scale, trait or
   record silently return the old runs, because the file name is the whole key. Simpler: keep the
   request (times, setting, pin) in the run file and reuse only on an exact match.
2. **TF24's facts are in eight places (D4, Lens 3)** — makes the design's "FF16, K93 and TF24f
   keep working" a shotgun edit. Simpler: one strategy table (grade, reserve time, spacing
   constants, unseen terms, ε source, excluded quantities); the loop reads only that.
3. **R3 does not hold (F2, F4)** — one failed run, a NaN quantity, establishment that never
   closes, or T(t) that never reaches 0.5 aborts the refinement with nothing saved. Simpler: a
   failed or non-finite pass ends the loop with `status = "failed"` and the last complete pass;
   missing ages fall back to the horizon.
4. **The returned schedule cannot be reused (cold read 7)** — blocks the design's next step
   (later runs on the kept schedule) because `panels` are dropped. Simpler: return the schedule
   object and its level; node times are derived by `nodes_of`.
5. **Nothing caps the cost (F6)** — three jumps of up to three levels each reach level 9, about
   96k nodes on dry. Simpler: cap the total level.
6. **The quantity set differs from the evidence's (F3)** — `rooting_depth_max` is stopped on but
   was set aside as a model kink, and r_min and u_q were never measured on it.

## Minor findings

- F7: the pair's step-noise allowance is 0.05ε; R21 measured up to 0.19ε, 0.077ε in the bound.
- F8: in spells under about 1 d a node can be placed outside the spell (grid cells of 0.36 d).
- F9: `HORIZON` hard-codes a 40-y lifetime.
- F10: the gradient's refusal flag is dropped.
- F12: the first run costs 0.09–0.13 of a scale-1 run, not 0.09.
- F13: `grade` is 2 only up to 0.95 t_r.
- F14: the stall boundary is neither built nor listed as not built.
- F15 and the cold read: `READ`/`UNSEEN_*` need comments to decode; four comments run past two
  lines; `rm` and `save` shadow base functions; "per spell" means per panel; `refine_schedule`
  rebuilds the strategy's parameters by a second path.

## Questions with defaults

- **Q1.** Why a new runner rather than `run_record.R` with PIN, the remaining-share record and
  the libS events added? Default: one runner (AGENTS: no parallel near-copy). It touches every
  script that calls `run_record.R`, so it rides the move of the harness to libS.
- **Q2.** Why copies of `eps_of`/`quantities` rather than one shared file? Default: one file both
  source.
- **Q3.** Should trait moves re-derive TF24's lma-dependent parameters, as plant's own moves do?
  Default: no, until the references are rebuilt the same way; the evidence and round 5 use raw
  moves.
- **Q4.** Should the canonical configuration be run end to end before the port? Default: yes, five
  cases at scale 1 (about 40 min of CPU), since its inputs differ from round 5's.

## Applied

In `refine.R`, `refine_run.R` and `refine_case.R`, checked by `review_code/mock2.R` (the loop on
the saved runs: every case asks for exactly the saved node times, reproduces every answer and
converges at level 1; worst bounds rise by 0.03 with the larger pair allowance) and a stub runner:
- **S1:** a run is reused only when its stored request (times, setting, base run) is identical.
- **S3:** a failed run, a refused gradient or a non-finite quantity ends the loop with
  `status = "failed"`, its `error`, and the last complete pass. A first run with no offspring fails
  with that message. A record that never closes is one spell to the horizon, and missing ages
  fall back to the horizon.
- **S4:** the fit returns the schedule object and its level, so later runs can use it.
- **S5:** no level above 4.
- **S6:** `rooting_depth_max` left out with the other quantities the constants were not measured on.
- **F7:** the pair's allowance is 0.11 + 0.08.
- **F8:** mass points are clamped to their panel, so no node falls outside its spell.
- **F9:** the horizon follows `LIFETIME`.
- **F10:** the refusal is kept and checked.
- **F11:** the spec's five fields are required.
- **Nesting:** checked where each run is requested.
- **Strategy parameters:** t_r now reads the first run's own parameters, so the second
  parameter-building path is gone.
- **Names and comments:** `READ`/`UNSEEN_*`/`MARGIN` renamed (`MIN_ESTIMATE_RATIO`,
  `UNESTIMATED_*`, `PREDICTED_BOUND_MAX`); comments corrected (grade, per panel, header).

Not applied (questions above): S2 (one strategy table) waits for a second strategy; Q1 (one
runner) rides the move of the harness to libS; Q2, Q3 and Q4 as defaulted.
