# One program

> **Spec, partly landed.** Steps 0-3 are done and 5 and 7 are refused; **steps 4 and
> 6 are outstanding and are one increment.** What blocks them is one fixture, not the
> restructure -- see the end of `two-paths.md`.
>
> The measurements taken while this was written are in `measurements.md`.

A trajectory is a composition of maps. The code models it as a list of steps with
a field that hints at the maps, and every piece of machinery in `sweep.hpp`,
`NodeSchedule` and the piecewise sweep is downstream of that one substitution.

This is the spec. `one-reverse-pass.md` section I is its ancestor: it proposed
"an insertion is a row", priced two objections, and took the field form. One of
those objections has since been deleted, and the other turns out to be avoidable
without a row at all.

## The one substitution

| | |
|---|---|
| the domain | an ordered sequence of operations: step, or junction |
| the code | an ordered sequence of *states*, with `inserted` marking where a junction was |

## The instruction, and why it is not a variant

`recorded_step` already pairs a time and a size in one object, and its comment
already gives the reason -- "a replay adding sizes does not land where the run
landed... Two vectors side by side can also be paired across different runs; one
cannot." That is the argument for a program instruction, already written.

It gains **one bool**:

```cpp
// One instruction: apply the System's junction if this is one, then reach `time`
// -- by `step_size` where a run pinned it, or by whatever the controller chooses
// where it did not. A NaN size with no junction is a grid point: a time no step
// reached, which is what row 0 is.
struct recorded_step {
  double time;
  double step_size;
  bool   junction = false;
};
```

⚠️ **The junction is the START of an instruction, not a row of its own.** That is
what avoids section I's remaining objection: no two rows share a time, so
`times()`, `schedule()`, `parameters.ode_times` and the sorted validation are all
untouched, and there is nothing to filter. A junction that introduces three
species is still one instruction, because the schedule names a set.

**Not a variant, and not a third field.** Three kinds would need more than one
bit; these are two -- step, and step-preceded-by-a-junction -- because a junction
never stands alone in this model: the schedule puts every introduction at the
start of an interval that steps.

## The verbs

```cpp
program run(const program& plan);   // execute; return the program actually run
std::size_t solve_adjoint(...);     // execute the reversed program
```

Two, not the three sketched earlier: a `keep_at` parameter would be a third
spelling of `set_keep_states`, which already exists. What the program *unlocks*
is selective keeping -- choose which instruction boundaries hold states and
re-execute sub-programs for the rest, which is checkpointing -- and that has no
consumer today, so it is a door and not a feature.

**Record and replay stop being special.** A plan is a program whose sizes are not
all pinned; a program is a plan with nothing left to choose. So:

* `run(plan)` returns a finer program: the adaptive controller emits what it chose.
* Replay is `run(program)` -- the same verb.
* **The spec property is a fixed point: `run(run(plan)) == run(plan)`**, bit for
  bit, which is exactly what pairing time with size exists to guarantee.

## Why `inserted` survives, and what would remove it

Not irreducibility. A junction's output is a state **between two rows** -- row k's
state is what step k reached, row k+1's is what step k+1 reached, and the junction
sits between them. No row owns it, so it rides on row k as a second field.

Two things say it is not irreducible. `state_at_segment` already recomputes it by
re-applying the map, and checks only its *size* against the stored one -- two
routes to one value. And recomputing costs one extra positioning plus one map per
range, about 0.25 s of a 108 s gradient.

**What actually blocks a row of its own is that `schedule()` slices the record.**
The replay schedule and the trajectory are one object, so any record row becomes a
schedule entry, and a junction row is a repeated time that
`distribute_ode_steps` silently deletes. Separate them and a junction is a row
with one state, `inserted` and `ran_from()` both go, and every row means one thing.

⚠️ **So the plan's order was right and my reasoning about it was not: 6 unlocks 4,
and neither lands alone.** What 4+6 needs beyond the filter is a restructure of
`solve_adjoint`: today it precomputes ranges of step indices, and with junction
rows in the record a range boundary is no longer a step index -- the loop wants to
dispatch per instruction and rebind where the width changes. That is the shape the
spec's own three verbs describe, and it is its own increment. Two things make it
safe to attempt: step 1 removed the last row-index address, so shifting indices no
longer moves anything a System reads, and `ode_times` turns out to be strongly
guarded (the measurement above).

⚠️ **What it needs first.** De-risking found the blind spot: the insertion
transpose sits behind `if (lo < hi)`, so on any fixture introducing at t = 0 a
skipped transpose is unobservable, and `ladder_stand_resumed` is the only fixture
where that range carries steps. A restructure of the range arithmetic should not
go in against one fixture.

## One state per instruction -- REFUTED as first written

This spec first claimed the row could hold one state, the pre-junction one being a
projection of the post-junction one. **Three findings kill it, and they are worth
keeping because each one is a reason:**

1. **Not a prefix.** The state is species-major and a node is appended to the end
   of *its* species, so the added entries sit in the **interior** of the flat
   vector. The before-state is an index selection, not a truncation.
2. **A vector is not what the reverse pass needs.** `be_at_step` must *load* the
   before-state so the System stands at the narrow width with a consistent
   environment and boundary node (`reshape_to` -> `set_state_and_boundary` ->
   `compute_environment` -> `compute_boundary_nodes`). Projecting a vector does
   not give you that.
3. **The before-ADJOINT is not a projection at all.** The introduced node is a copy
   of `new_node`, whose initial conditions were computed against the current
   environment -- so **the new rows read the old state**. Asserting otherwise would
   put a model claim inside the sweep, which `one-reverse-pass.md` already priced
   (~0.3% of tape volume) and refused.

**So both states stay, and both are already recorded.** `inserted` and `ran_from()`
stay. The flag replaces the *discriminator*, not the storage -- which is a much
smaller change than this spec first claimed.

What the flag still buys, and it is worth having:

* `insertion_rows` becomes a read of an authored fact rather than
  `!inserted.empty()`, so **the junction structure is known on a non-recording
  run** -- today `push_inserted` returns early when `!keep_states_`, so it is not.
* `solve_adjoint`'s stop guard reads the flag rather than the recorded state,
  which is the same fact without needing states.
* The executor can interleave junctions, which is what collapses `sweep.hpp`.

## Where the leverage is: the executor already exists

`sweep.hpp::advance_over_insertions` is the interleaved executor, written as a
segment loop:

```
for each segment:
  segment_steps = { (time, NaN) } ++ rec[first+1 .. last]   // a synthetic head row
  advance_recorded(segment_steps)
  apply_insertion(sys, rec[last].time, ...)
  set_state_from_system()
```

It manufactures a fake grid-point row per segment because the program cannot say
"junction". Its own comment states the target: *"A recording row is a schedule row
plus its state, so the schedule is read off it rather than built beside it."*

**With the flag, that whole function is `advance_recorded(rec)`.** And note the
asymmetry it reveals: odelia *already* executes junctions on the reverse pass and
in the forward replay. Only the original forward run does not -- SCM widens the
System behind the solver's back and then tells it. That asymmetry is the defect.

### What `push_inserted` was for

Exactly that. The width change happens outside the solver (`sys.introduce_nodes`
then `solver.set_state_from_system()`), so the solver never sees the junction and
has to be *told* where one was. Make the junction an instruction the solver
executes and `push_inserted` has nothing to announce; the resize is part of
executing it.

It also has a defect the flag fixes: `push_inserted` returns early when
`!keep_states_`, so **today the junction structure is only known on a recording
run.** A flag on the instruction is known on every run.

### Does partitioning duplicate the introduction schedule?

Today, yes, and that is the duplication to remove: `reshape_to` consults
`node_schedule_times` (times) while `insertion_rows` consults the record
(`inserted` non-empty). Two sources for one fact.

With the flag there is one source and a clean split of ownership, which the code
already states at `be_at_step` -- "which insertions had happened by then is
derived from the schedule it was driven by, not handed to it":

* **odelia owns WHEN**: the flag on the instruction.
* **plant owns WHAT**: which species, derived from its own schedule.

So a partition is a *view* of the program, not a second copy of the schedule.

## Residue this takes with it

| | |
|---|---|
| `step_record::inserted`, `ran_from()` | replaced by the flag and a projection |
| `push_inserted` (Solver and SolverInternal) | the junction is executed, not announced |
| `insertion_rows` | a filter on the flag -- and correct on non-recording runs |
| all of `sweep.hpp` (`state_at_segment`, `advance_over_insertions`) | `subtraction-targets.md` 8's subject |
| `stops`, `n_piece`, `piece_first`, `piece_last`, highest-first | a partition of the program |
| `extra_splits` | **a junction whose map is the identity**; `unification.md` 7 dissolves |
| `NodeSchedule::distribute_ode_steps`, `using_ode_steps()` | one program, not two halves merged at run time |
| `SCM::run_next` | dead; `run_mutant` is a hard `util::stop` |
| `Solver::history`, `get_history*`, `collect` | `unification.md` 6, pending the R-consumer map |
| `Species::growth_rate_gradient(size_t)`, `Node::growth_rate()`, `Node::mortality_rate()` | dead cluster found while tracing the boundary node |

`advance_adaptive` / `_fixed` / `_euler` stay as **plan generators** -- they are
R-exposed on odelia's Solver, plant's OdeRunner and the leaf_thermal example, so
the surface keeps working; they become thin wrappers that build a plan and run it.

## What this does not change, so it is not oversold

* **The junction's transpose is irreducible.** It is the model's, not the code's.
* **The per-width rebind is worth ~0.3%, not the 6% this spec first claimed.**
  One `rebind_from` is ~2 ms; the descent does ~340 (170 range + 169 insertion + 1
  census) and only the 169 insertion rebinds are avoidable -- 0.35 s of a 108 s
  gradient. The 7.0 s / 6% figure in `unification.md` 5(a) is the *forward* path's
  `rebind_from` including the light-interpolant rebuild, not the sweep's per-range
  rebind. **There is no speed prize here.** The prize is vocabulary.
* **`derivs` writing into the System is a separate thread** -- the 32.3% the leaf
  spends being recorded. This spec shares its root cause and touches none of it.
* The three-phase field build stays; the circularity is real.
* `restore_on_exit` stays until a refusal is a return value.

## Landing order

Each lands alone and makes the next smaller. 0--2 are provably behaviour-identical.

0. ~~**Free deletions**~~ **DONE.** `SCM::run_next` and the `sync_patch` parameter
   it was the only caller for, plus the dead node cluster. `Solver::step()` was
   *not* dead -- see above.
1. ~~**The flag exists**~~ **DONE**, set before the `keep_states_` check. Same
   commit took the last row index used as an address.
2. ~~**`insertion_rows` reads the flag**~~ **DONE**, and it is step 1's check:
   set the flag never and `first-segment.R` fails at once with a width mismatch,
   ten passes becoming four.
3. ~~**The executor**~~ **DONE.** `advance_recorded` applies the System's map
   after a junction row; `advance_over_insertions` is a program build and one
   call, 30 lines to 12. Verified by breaking it -- with the map never applied,
   rung5 fails 33 assertions. The stop guard reads the flag too.
4. **Delete `inserted` and `ran_from()`**; the pre-junction state is a projection.
5. ~~`extra_splits` becomes identity junctions~~ **REFUSED.** A cut is free
   today: its row carries no recorded wider state, so the stop guard falls
   through and no map is transposed there. An identity junction replaces that
   with a recorded map on the tape, and
   `test-gradient-ladder-identity.R` asks for `expect_identical(split, whole)` --
   bit-exact. Paying tape volume and risking exactness to move a test-only
   parameter from a signature onto a row is a worse trade than the parameter.
6. **Schedule/record split.** ⚠️ **Cannot land before 4, and is not merely
   vacuous without it -- it is wrong.** `junction` currently sits on a *step* row
   (the row a junction followed), so filtering `schedule()` on it drops 169 real
   steps. Measured: 9 failures and 5 errors across `test-scm.R`,
   `test-strategy-ff16.R` and `test-ode-euler.R`, with `ode_times[c(10, 100)]`
   reading 3.7, 55.1 against a blessed 0.0, 4.2. **4 and 6 are one increment.**
7. ~~Plan the widths~~ **dropped**: worth 0.3%, and the three ways to share a
   rebound System across the insertion transpose and the range below it were each
   priced higher than the saving. `apply_insertion` widens the System it records
   on, so the two cannot share one.

## Open risks

| | risk | resolved by |
|---|---|---|
| R1 | anything depending on `insertion_rows` being empty on a non-recording run | grep at step 2 |
| R2 | `refine_schedule`'s round trip through `parameters.ode_times` | R-surface map |
| R3 | a stored `Parameters` (`scripts/refined-century.rds`) becoming unreadable | R-surface map |
| R4 | `sweep_range`'s width-mismatch refusal | sweep-mechanics map |
| R5 | **who drives the junction** -- today SCM introduces then tells the solver; the executor inverts it | mitigated: `apply_insertion` is already odelia's CPO and the reverse already calls it |

⚠️ **The measurement rule for this work.** A same-source, same-core, byte-identical
A/B on the century fixture reproduced a **2%** gradient gap between two installed
copies; a fresh copy of the slow tree was fast. So wall-clock deltas below ~3% are
not admissible here. Verify by **counted** numbers -- tape statements, placements,
row counts, rate evaluations -- and treat a timing as a sanity check, never as
evidence.


---

**The measurements behind this spec, and the root causes chased while it was
written, are in [`measurements.md`](measurements.md).** History: read them for a
number's provenance, not for outstanding work.
