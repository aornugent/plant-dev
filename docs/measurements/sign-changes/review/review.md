# The review of the rebuilt split

Under the code-review skill, of odelia `ODELIA-53` and `ODELIA-54`, plant
`PLANT-100` to `PLANT-103` and phylloptim `PHYLLOPTIM-17`, as rebuilt in
`design-sign-changes.md` §8. The clean sheet (`clean_sheet.md`) and the cold
read (`predictions.md`) were each made by an agent blind to the diff: the first
from `requirement.md` and the base commits, the second from `surface.md`, the
declarations and their comments, before reading any body.

## Verdict: approve with changes
## Triage: 3 — the odelia–plant boundary: a concept, its hooks and the row's record

Both changes are made: the comments the cold read misread, on their branches;
and the walk (structural finding 2), on `ODELIA-53` `c14ebfd`, `ODELIA-54`
`9144d99`, `PLANT-102` `a2cb3df2` and `PLANT-103` `ae675637`.

## Ledger (design doc §8, issues odelia#53, #54, plant#100–#103, phylloptim#17)

R1 gradients reproducible under ±5% of `tol` (ε/3); R2 curvatures stable at
r = 1e-2; R3 no jump above 1e-8 in ln J on a frozen mesh; R4 the sweep is the
derivative of the run's own map; R7 J′ = J to the bit on the diagonal; R8 the
forward at most +6%, the sweep +7.3%; R9 the least code; R12 odelia never says
"node". Decided: plant owns the split and odelia the step's numerics; off by
default and bit for bit when off; TF24 alone.

Design doc check: the commitment is kept true by structure. odelia's types say
block; plant alone maps blocks to nodes; the sweep's hook is a compile-time
requirement. New nouns against §8's vocabulary: none outside it.

## Clean sheet

After the five stages, each crossing node's block is integrated again in pieces
by the step's tableau. A break is where the evaluation that starts the next
piece reads P = 0. The field is the Lagrange interpolant of the step's own stage
reads, exact at the abscissae. The row keeps breaks, slopes and leaf points. A
walk integrates the invader's node of the same index in pieces at the recorded
breaks, with its own rates; the sweep moves each break by the implicit function.
About 235 lines, estimated.

Gap, against the stack's ~410 lines of code in odelia and ~300 hand-written in
plant:
1. *The field.* Five builds on the dense output, read by the quartic through
   them, over the stage reads' interpolant. Settled by R4's measured cure: the
   five samples hold ln J within 2.4e-9 of a field built at every evaluation.
   Explicit stages are first-order values of the state, so the stage reads hold
   the field to O(h²) between the abscissae (unmeasured). The sketch's gain, no
   jump as a break leaves a step, the stack meets within R3 (+4.9e-11 measured).
2. *The break.* The zero of P on the dense output, over the zero of P where the
   next piece starts. Settled by R8: each locate iterate costs one node
   evaluation, not a piece of six. The sketch's reason, a misfit flipping the
   next piece's first reading across the switch, needs a hard switch, and TF24's
   positive part is smooth. It stays a candidate for R2's untraced residue,
   which falls like 1/r, as kinks in J(θ) would.
3. *The walk.* The run's correction carried onto the invader, over the
   invader's own node integrated in pieces at the recorded breaks. R7 and R3
   cannot tell them apart: both give J′ = J on the diagonal and fixed breaks off
   it. The bank could (structural finding 2). The sketch was right, and the
   stack now takes its walk.
4. *The record.* The stack kept each block's state before the split, for the
   carry; it now keeps the field's five samples instead, which the walk reads.
   The sketch kept neither, its field coming from the stage reads.

## Prediction record (39 elements, 11 misses)

Each miss's comment now says what the body does (odelia `237915b`, plant
`4f8f7a2b`, `abf3eba8` and `9ea3c9e9`, phylloptim `300d229`, before the walk
changed).
1. `sample_fractions`, `Control::ode_split_sign_changes`: predicted the field
   built from the dense output at each u; actual: built at five fractions and
   read between them on the quartic through the five.
2. `splits_by_block`, `SCM$ode_splits` "by node": actual by position at the step.
   With several species an introduction in one shifts the later species'
   positions, so an entry sums different nodes.
3. `node_rates_in_field` "in the field supplied, not built": actual writes the
   environment's time, knots and state, every species' newborn birth date, the
   node's state, and the boundary node's rates when the node is the newest.
4. `Patch::take_recorded_splits` "every species laid out as the run's one":
   actual matches by node count; a species with another count walks unsplit,
   silently. (Still so after the walk changed.)
5. `sign_changes` "once or as a pair": actual one where the ends differ (a
   triple reads as one), a pair only next to a reading that crosses or lies
   within 2% of zero; it accepts the 64th iterate and may evaluate and find
   nothing.
6. `SolverInternal::split` "Cash–Karp only": actual returns silently under any
   other method.
7. `SCM$ode_splits` after an invasion: predicted the walk's own splits; actual
   read 0, the walk carrying and counting nothing (it now counts the node steps
   it splits). `run_mutant` drops a several-species run's splits silently.
8. `integrate_pieces`: an unstated precondition, `split_at` ascending inside
   (0, 1).
9. `split_block::solved`: five evaluations for the piece from the start, six for
   each other.

## Decisions reopened

- D1: plant orchestrates through a handed `taken_step`, over odelia driving
  blocks by callbacks. Settled by the user's decision and R12.
- D2: the whole end evaluated again after the System evaluated, over reusing the
  unsplit end's rates. Settled by R4: the next step's first rates are f at the
  split end, and a split node's state moves every node's field.
- D3: the field sampled five times a split step, over a build per node
  evaluation. Settled by R8, measured: 2% of the split's cost in the profile.
- D4: a walk carries the run's correction onto every invader with the run's node
  count, over the invader's own node in pieces at the run's breaks. R7 and R3
  hold for both; OBJECTIVES' *never fails* settles it against the stack.
  Changed: the walk integrates in pieces.
- D5: a run of several species drops its splits for walks silently, over
  reporting it. Unsettled: Q1.
- D6: `split()` does nothing outside Cash–Karp, silently, over refusing.
  Unsettled: structural finding 1, which `ark-step` makes reachable.

## Change simulation

| next change (the spec) | edit sites | class |
|---|---|---|
| item 5, the soil on its own | `sample_field` reads every component, the soil's too, through `taken_step::dense_state`, the members' Cash–Karp step; `SplitsSignChanges` names Cash–Karp's `taken_step` | leaky: the multirate step must serve the whole state's dense output, the soil's from its inner steps |
| item 6, node rule D | a block is a node and nothing counts nodes; the split builds the field five times a split step, and a walk now integrates every split node in pieces | one place |
| item 6, the invader's own sparser introductions | `take_recorded_splits` finds the invader's copy of a run's node by position where the invader has the run's node count; a thinned invader matches none and walks unsplit, silently | leaky |
| item 7, the window's weight and the 15-day cap | splits run after the error estimate keeps a step, whatever set its size | one place |
| item 8, R8's diagnostics | the per-node counts are there, walks' included | one place |
| ARK for the constant record (`ark-step`, `ark-soil`) | `split()` runs only under Cash–Karp and returns silently otherwise | leaky: a run asking for both splits nothing, with every number finite |
| several resident species (regnans's assembly) | `run_mutant` drops the blocks and samples of a run of several species, and `take_recorded_splits`'s layout match assumes one | leaky: two sites encode one resident species |
| invaders split at their own crossings | the walk's pieces read the run's recorded samples; its own sign changes would be found in them and moved in its sweep, as `split_as_recorded` does for a non-zero slope; odelia must hand the walk every step, not only those the run split | leaky: odelia's walk and plant's walk split; not planned |
| the acceptance suite | the switch is a Control field; the split's own tests are in odelia and `test-scm.R` | one place |

## What must always be true

The sweep tapes the map the forward took, a walk's included. Kept true by
structure: one plant body (`sample_field`, `node_value_at`, `split_node`) at
either scalar; the forward's sign changes and solved values replayed in order,
their count checked; a walk's row recording the blocks it split. One convention
is left: `split_sign_changes` returns true wherever it moved the System's state,
which plant ties to whether it sampled.

## Structural findings

1. Splits stop silently outside Cash–Karp. This makes merging `ark-step` and
   `ark-soil` with the split riskier, because a run asking for ARK and splits
   splits nothing with every number finite. With that merge, plant refuses
   `ode_split_sign_changes` under any `ode_method` but rkck where Control is
   checked. (Plant has no `ode_method` on this base.)
2. A walk carried the run's split correction, the run's move in each of the
   node's components, onto every invader laid out as the run. This made walking
   an invader far from the run (OBJECTIVES' ×0.5–×2) fail, because the run's
   move landed on a state of another scale, and a walk's fixed steps never
   refuse an invalid state. At lma × 2 on long-wet the invader holds ~1e-8 of
   storage where the run's moves reach 3e-4; 55 of 466 moves left it below
   zero, and its density overflowed at year 6.49. Long drought failed alike
   (27.73). Episodic's walk fails at 2.96 with or without splits, on a 27-day
   step past its pools' stability limit, and runs under a 15-day cap (D4,
   `d4.log`). The alternative, now built: the invader's own node integrated
   in pieces at the run's breaks, held, in the run's five recorded field
   samples. The carry and `state_before_split` go; the row keeps the samples;
   a walk's row records the blocks it split.

## Questions with defaults

Q1: why drop a several-species run's splits for a walk silently? Default if
unanswered: keep dropping them, and report it with R8's diagnostics when they
are built.
