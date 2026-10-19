# PLANT-95 / ODELIA-53 review (code-review skill, Tier 2)

Diffs: plant `PLANT-95` against `PLANT-97` (b23b2d67); odelia `ODELIA-53` against master
(1e0f0f0). Reviewed by the author after writing it, so Lens 1 is weakened: the bodies were
read before the predictions, and its misses are a lower bound.

## Verdict: approve with changes (applied)
## Triage: 2 — a feature in headers both packages already have; odelia gains one defaulted parameter

## Ledger (reconstructed from residual-A.md items 2, 3, 5, 14 and the brief)
- R1. TF24 offers each species' net reproduction ratio and offspring production to
  `stand_gradient()`, refereed (`differentiable_fitness`; S_D a column).
- R2. A TF24 invader stands in the recorded resident field and solves its own leaf operating
  points; its sweep loads those, not the resident's. Two invaders run together.
- R3. `run_mutant()` refuses what its replay would skip: a harvest or climate extreme in the
  resident's run, an invader introduction the resident never made.
- R4. TF24 has a constant-birth-rate gradient column, as FF16 has, so the resident's
  equilibrium birth rate is found by Newton on `d ln J/d b` and an invader is differentiated
  there.
- R5. No resident number moves.

## Clean sheet
odelia: let the recording walk hand stages a mutable copy of each row (one flag, ~10 lines).
plant: the flag on in `run_mutant`; `Patch::store_solved` stands in a field the row already
holds; TF24 sets the fitness flag, drops S_D from `no_gradient`, copies FF16's birth-rate
column; two checks in `run_mutant`. — Gap: one odelia member (`seeded_row_`) the sketch did
not have, settled below (D2).

## Prediction record
- `advance_recorded(rec, bool seed = false)`: predicted "loads the row, or with seed stores
  into a copy"; actual the same. Hit.
- `Patch::store_solved`: predicted "always writes to the slot"; actual it now also stands in a
  field when the row it is handed already holds one. Miss — the name says store and the body
  also reads. Kept, because the comment beside it says so and odelia's contract for a seeded
  walk is exactly "read what is there, store the rest"; renaming would mean renaming odelia's
  `SolvesForValues` hook. Recorded rather than fixed.
- `TF24_Strategy::birth_rate_at`, `has_birth_rate_column`, `ad_column_count`: predicted as
  FF16's; actual the same. Hits.
- `run_mutant` refusals: predicted "refuse before anything is overwritten"; actual both run
  before `parameters = p`. Hit.
Checked 6; 1 miss.

## Decisions reopened
- D1: chose an opt-in flag on `advance_recorded` over making every recording walk seeded.
  Settled by residual-A (odelia A0: "an opt-in walk, not a change of meaning") and by plant's
  pinned referees and odelia's own replay tests, which load by design.
- D2: chose a persistent `seeded_row_` in odelia over seeding `solved_scratch_` directly.
  Settled: the patch keeps standing in the last row's field across an insertion (patch.h,
  `end_solved` comment), and `push_step` moves the scratch into the record, which would leave
  that pointer on an emptied field. The copy into the record is the cost upstream's replay
  already pays when states are kept.
- D3: chose to keep the existing between-row field rule (the last loaded field persists to the
  insertion at its instant) over installing `introduction_fields` in the forward walk too.
  Settled by R5: the forward walk's numbers, FF16's invasions included, stay as they were
  (test-ff16-mutant-gradient.R, test-mutant.R pass unchanged).
- D4: chose to copy FF16's birth-rate column into TF24 over hoisting it into the shared
  `Strategy` base. UNSETTLED → Q1.
- D5: chose to restrict the census ladder's declared-zero checks to census rows over keeping
  every metric there. Settled: those checks state why a census column is zero (a_f3 reaches no
  census metric); with fitness rows a_f3 and S_D are live by design, and their rows are
  refereed in test-tf24-fitness-gradient.R.

## Change simulation
- Applying events in the invasion replay (b737a9b5's port): remove the event refusal in
  `run_mutant`, map the actions in `Patch::apply_insertion`. One-place.
- A third model offering a birth-rate column (K93): nine edits mirroring FF16's and TF24's
  (member, three accessors, `ad_parameters`, names, `assign_from`, `for_each_active`,
  `prepare_strategy`). Shotgun, but on a speculative axis → Q1.

## What must always be true
An invader's rate evaluation stands in the resident's field taken at the same instant, and
what the invader solves there is what its sweep loads. Kept true by: structure (the seeded row
carries both; `compute_environment` refuses a field whose time differs in any bit).

## Structural findings
None open. Applied during review:
1. The fitness-flag and birth-rate comments ran to three and five lines, past AGENTS' two-line
   rule; cut to two each.
2. `ladder_replay_floor` compares the tangent's whole metric vector with `result$value`; a
   census-only shared gradient broke that pairing. The shared gradient keeps every metric, and
   only the two class checks select the census rows.

## Questions with defaults
- Q1: why copy the birth-rate column rather than hoist it into `Strategy`? Default if
  unanswered: leave the copy in this PR (the base is double-only and FF16 would move too) and
  hoist it in a follow-up subtraction PR once a reviewer agrees.
