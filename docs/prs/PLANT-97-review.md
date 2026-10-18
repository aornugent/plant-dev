# Review: PLANT-97, TF24's storage pool (offset in, stage guard out)

Self-review under `.claude/skills/code-review` (Tier 2), of branch `PLANT-97` on plant
`develop` (bd09645d). Lens 1 is weakened: I ported the change, so I had read the bodies
before writing predictions. Its misses are a lower bound.

## Verdict: approve with changes (applied)
## Triage: 2 — one model change in one header, its bindings and tests; no persisted
format or public API changes shape (a new list field is tolerated on old saved objects).

## Ledger (reconstructed from aornugent/plant#97, #98 and the brief)
- R1. An explicit step does not overshoot a seedling's storage pool, so an invader
  walked on the resident's steps runs over `lma` x0.7 to x2.
- R2. The model change is declared: one parameter, a version bump, and a zero
  offset gives v11's rates.
- R3. No committed state has a pool below zero (the guarantee the guard served).
- R4. References that move are re-blessed in the same PR, with the reason.

## Clean sheet
One parameter `o`; the storage rate divided by `1 + o (charge + drain)/S_max`; `o < 0`
refused; the stage check deleted, because the step-end check (`non_negative_states()`)
already exists; version bump; regenerated bindings; tests for the rate's form, finite
rates below empty and the invader range; re-blessed pins. About 25 lines of model.
— Gap: the diff also fixes one stale line in `scripts/capture-reference-gradient.R`
(it called `census_metric_names_tf24()` without the run, broken since #658). R4 pays
for it: the reference cannot be recaptured without it.

## Prediction record
- `storage_domain_tol` removal: predicted a stage check would survive at an exact
  zero; actual: no stage check at all, the step end alone is checked. Not a miss of
  the code, a miss of the old comment on `non_negative_states()`'s neighbour, which
  the diff rewrites.
No other misses — checked 4 (`storage_relaxation_offset`, its gradient column,
`scientific_version`, the `prepare_strategy` refusal).

## Decisions reopened
- D1: chose a model change (a divisor on the rate) over a solver change (an implicit
  pool) — settled by R1: an implicit ESDIRK stage takes a draining pool below zero
  past `h lambda` = 3.1, a step of 0.8–6 d for a seedling, so invaders would still
  fail (`docs/archive/scope-imex-stepper.md` §3, "B is not pursued").
- D2: chose a parameter with a gradient column over a hard-coded constant — settled
  by R2 (zero must reproduce v11's rates, testably) and by the downstream use of
  `t_r = o ln(a_st3 a_dG2)` as a parameter expression.
- D3: chose deleting the stage guard over keeping it at a looser tolerance — settled
  by R3: the step-end check keeps the guarantee on every path (adaptive: reject;
  pinned: subdivide; walk: fail), and the error estimate rejects an overshooting
  stage because its rates stay finite.
- D4: chose one PR for #97 and #98 over two — settled by R4: the reference is
  recaptured once instead of twice (the archived pair churned it by 3622 and 1438 diff lines).
- D5: chose to re-bless the whole-run reference over leaving the rung red — settled
  by R4. The moves are the model's (30 new rows; 91 of 1380 rows move by more than
  1e-3 of scale, mostly theta and omega on the drought and seasonal stands, with
  converged step ladders), not the instrument's.

## Change simulation
- A different default offset: edit the default in `TF24_Pars`, the two Defaults
  tests, bump the version, re-accept the snapshot and the pins. Leaky, but the
  leak is every model change's (pins and snapshot), not this diff's.
- Another bounded state: add its name to `non_negative_states()`. One-place.

## What must always be true
A committed TF24 state never holds a pool below zero, and for any offset >= 0 the
rate is >= 0 at an empty pool and <= 0 at a full one.   Kept by: structure (the
step-end check in `Patch::ode_state_valid()` on every stepping path; the divisor is
>= 1 because `prepare_strategy()` refuses a negative offset).

## Structural findings
None.

## Minor findings (applied)
1. Two new C++ comments ran past 80 columns and one used three lines where two
   say it; reflowed. Checked every touched comment against AGENTS.md's rules: no
   issue tags in new comments, no banners, no metaphor words.
2. The version comment said "zero is v11", which is false where the stage check
   fired; it now says a zero offset gives v11's rates and names the guard's removal.
3. The bounds test still said "the rate refuses a negative pool"; it now names the
   step-end refusal. The archived branch had left this stale.
4. The TF24 invasion-identity test still described hundreds of thrown stages; it
   now describes the step-end refusal, and its step guard (189 steps at v12) was
   lowered from 250 to 150 with the v12 count recorded beside the v11 table.

## Questions with defaults
- Q1. Should the invader-range test also pin the height coordinate? Default: no.
  On this fixture height-coordinate invaders fail at v11 and v12 alike on a leaf
  solve or an overflowing density, which this PR does not address.
