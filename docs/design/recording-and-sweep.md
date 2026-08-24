# The recording, and the sweep over it

One of two tracks split out of the reverse-mode redesign. This one is a **pure
refactor**: its whole claim is that no number moves. The other track,
`gradient-columns.md`, deliberately changes the answer. They meet only inside
`census_trait_gradient`, at different lines, and their risk profiles are opposite
— which is the reason they are apart. A bit-for-bit claim is only clean against
an unchanged column set, so this track lands first.

## Triage: 3 — odelia is published and `Solver`'s accessors are R-visible

## The rule both tracks serve

Two refusals sit under this surface and neither is a preference. **Do not tape
the leaf's solve** — recording a root-find differentiates the solver's iterations,
not the model. **Do not tape the whole trajectory** — it does not fit. Together
they force record-and-replay, and a replayed model asks one question at every
seam:

> **What did the run know here, and where is it written down?**

Every duplication below is the same answer: a fact the run knew, dropped, and
reconstructed downstream. The rule is **record the fact where it is known,
project it where it is needed, never re-derive it.**

## Requirements ledger

**R1 — one representation of a recorded trajectory.** Today: `SolverInternal`
holds `vector<step_record{time, step_size, state}>` privately; `get_times()`,
`get_step_sizes()` and `recorded_state(k)` project it into correspondents; plant
re-bundles them into `ode_step_record{time, step_size, state}`, an identical
struct, re-checking a pairing that was never broken; four call sites destructure
that again into `(states, times)`.

**R2 — the sweep reads one source.** `Solver::solve_adjoint` takes `states` as an
argument *and* reads `times()`/`step_sizes()` off itself. A length check is what
keeps them agreeing.

**R3 — a widening carries when it happened.** `recorded_widening` is constructed
at exactly one site (`scm.h:581`) where the time is already in hand;
`insertions_of` then recovers it at four sites.

**R4 — the partition is checked once and cannot be skipped.** `state_segments`
validates that the widenings cover the recording — its comment calls that check
the reason the shape exists — and it re-runs per call, while `be_at_step` can be
reached without it.

**R5 — no number moves.** Bit for bit. plant 3283/0/0/13 and 679/0/0/5,
phylloptim 2421 checks + 223 golden + 1455/0/0/1, odelia 408/0/0/3.

**R6 — quantities.** 117 recorded steps. `ode_size` ≈ 5 × cohorts × species, so a
kept trajectory is on the order of hundreds of KB. **152 `advance_*` call sites**,
so any per-call forward-API change is expensive. `set_keep_states` and
`keeps_states` have **exactly one caller each**.

**Scarce resource.** Not CPU (`row_batch` already collapsed the per-metric cost)
and not memory (R6). It is **places where two spellings of one fact can disagree
while both compile** — the class every defect in this campaign actually belonged
to, and every one produced a plausible finite number rather than an error.

## The floor

Fix only the disagreement paths: `solve_adjoint` takes times and sizes as
arguments instead of reading its own, and the widening stores its time where it is
built. Pays R2 and R3 in a few lines.

**Fails R1 and R4.** The projection chain survives entire, and the partition check
stays both re-run and skippable. Worth having, and not enough — but it is the
right thing to keep if the candidates below are judged too invasive.

## Candidates

**A [first thought] — move 6, Pólya with witnesses. Expose the record.**
`span<const step_record>` off the solver; `ode_step_record`, the re-bundle,
`recorded_times()` and the four unpackings all deleted.
Commitment: the record the solver kept is the record every consumer reads.
Pays R1, R2, R4. Costs: `step_record::state` is documented *"empty unless this
run was asked to keep them"*, so the span can carry entries a sweep cannot use,
and `keep_states_` remains a bool whose truth is "the states are populated" —
data and flag able to disagree. plant reads it back through `keeps_states()`,
which is a round trip: plant sets the flag, then asks the solver what it set.
Wins when every consumer wants the same triple.

**B — move 3, move the system boundary. The recording is an object, and having
one is what recording means.** `record_into(&rec)` replaces
`set_keep_states(bool)` — one setter, so the 152 `advance_*` sites are untouched.
Commitment: a recording is a thing you hold, not a mode the solver is in.
Pays R1–R4 **and deletes the flag entirely**: `set_keep_states`, `keeps_states`,
`keep_states_`, the *"empty unless asked"* caveat on `step_record::state`, and the
`prev_steps.size() == 1 && ...state.empty()` special case at line 219 all go,
because the question they answer becomes "do you have one".
Wins when a flag and the data it describes can disagree — they can, and one of
them is read back across a package boundary to decide whether to re-run the model.

**C — move 4, trade storage for compute. Store no states; replay for them.**
Keep `(time, step_size)` and the widenings, and recover any state by replaying
forward from t0 — the classic adjoint-checkpointing design.
Commitment: states are derived, not stored.
Pays the memory R6 prices at hundreds of KB. Costs a replay per state access,
so the sweep is quadratic in steps without a checkpoint schedule on top.
Wins when memory is the binding constraint.

## Pick by arithmetic

**Winner: B.**

- **C is eliminated on R6.** It spends the resource that is scarce (a replay is a
  model evaluation) to save the one that is not (hundreds of KB). Priced here so
  that its absence is a decision rather than an oversight — and it is the right
  design the moment R6's memory line changes.
- **A is dominated by B.** They pay the same rows; B additionally deletes a flag
  that can disagree with its own data, and does so by removing a question rather
  than answering it. A's cost — a span whose entries may be unusable — is exactly
  what B's commitment makes unrepresentable.
- **The floor is beaten** but stays the fallback: it is the subset of B that
  touches no interface.

## The commitment

**A recording is an object, and having one is what recording means.**

Kept true by structure:

- `step_record::state` loses its *"unless"*: a recording that exists has states,
  so there is no populated-or-not to test.
- the accessor *is* the object, so there is nothing to project and nothing to
  re-bundle.
- the widening carries its time from the site that records it, so
  `recorded_widening` and `insertions_of` have nothing left to do.
- pairing the solver's records with the model's insertions happens in one
  constructor, which is where the partition is checked — so an unvalidated
  pairing is not a thing the sweep can be handed.
- the sweep reads that object and nothing else for times and sizes, so R2's
  length check has nothing left to compare.

## Kill question

*The assumption whose falsity makes this unnecessary:* that every consumer of a
recording wants the same triple.

It is false as stated — the R boundary wants times as a bare vector of doubles,
and the adaptive controller wants the last time and nothing else. So the
assumption has to be narrowed to **every *sweep* consumer wants the triple**, and
that holds exactly: all four plant call sites unpack precisely `(states, times)`.
`times()` and `step_sizes()` therefore survive as *boundary projections*, named as
such, rather than as internal accessors the sweep goes through. **Survives, in the
narrowed form.**

## What this makes hard

A caller wanting only times must either use the boundary projection or hold a
recording it does not need. Coped with by keeping the two projections for R, which
takes vectors of doubles anyway.

And a long non-gradient run must now decide. Today it gets no states because the
flag defaults false; under B it gets none because it passes no recording. That is
the same outcome reached by a different question, so nothing regresses — but the
decision becomes explicit at one site instead of implicit in a default.

## What this does NOT solve

**There are two recordings, and only one of them becomes an object.**
`SCM::record_trajectory` drives both `solver.set_keep_states(...)` (states at
accepted steps) and `patch.recording` (the strategy's per-stage choices, read at
`patch.h:1152`). They must agree for a sweep to be right: record states without
choices and the replay re-derives a discretisation the run never took, with every
number finite — which is the silent-wrong-answer path `RecordsChoices` exists to
close. Today that invariant is two adjacent assignments in one function and
nothing else.

B makes the states half an object. The choices half lives inside the strategy, per
node per stage, and moving it is a much larger change. So the honest scope here is
**both driven from one call**, not both becoming one object. Recorded so the
remaining hole is named rather than implied.

## Kill condition

R6's memory line changes — very long runs, or cohort counts that make a kept
trajectory large. That hands off to C, checkpoint-and-replay, and nothing else in
this design has to move.

## Increments

1. **The floor**, on its own: the widening stores its time; `solve_adjoint` takes
   times and sizes rather than reading its own. Deletes `insertions_of` and one
   length check. Numbers identical.
2. **B**: `record_into()` replaces the flag; `step_record` is exposed as the
   recording; `ode_step_record`, `recorded_times()`, the re-bundle and the four
   unpackings deleted.
3. **The pairing view**: solver records + model insertions in one validated
   construction, absorbing `state_segments`' check. The five loose-array
   signatures collapse to it.
4. **Row 5 of the old ledger**: `history`/`collect`/`get_history_*`, the
   `vector<System>` recorder that `least_squares` copies whole Systems out of to
   read state vectors. R-facing and breaking — not mine to land.
