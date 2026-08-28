# One program

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

## One state per instruction -- REFUTED, and the spec is smaller for it

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
6. **Schedule/record split**: `NodeSchedule`'s merge dissolves.
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

# What de-risking found before a line was written

Three read-only sweeps, run before the build. Two killed claims this spec had
made; the rest are constraints worth having in one place.

## The two mechanisms that would have broken the row form

Section I chose a field over a row and priced two objections. One of them --
the recorded stage address -- **was deleted by step 6**, and the comment on
`push_inserted` still cites it. The other is worse than it looked:

⚠️ **A repeated time at a junction is SILENTLY DELETED.**
`NodeSchedule::distribute_ode_steps` skips any recorded step whose time is
bit-identical to `time_introduction()` or `time_end()`. An SCM insertion happens
exactly at an interval boundary, so *both* copies of a duplicated time are
dropped and the instruction never reaches the solver. No error, no trace.

⚠️ **The first and last instruction cannot be a junction.** `r_set_ode_steps`
requires `times.front() == 0.0` and `times.back() == max_time` **bit-exactly**.

Inside an interval a duplicate is no better: the NaN copy becomes
`step_to(t)` from `t`, which `set_time_max` permits, yielding a **zero-size
accepted step** and a recorded row; a sized copy advances the state by `h` while
assigning the clock back to `t`, desynchronising the two silently.

**So the flag-on-the-instruction form is not a preference. It is the only form
that does not corrupt the schedule.**

## What the R surface pins

* `parameters.ode_times` / `ode_step_sizes` are read at exactly one place,
  `make_node_schedule`. `Parameters::validate()` never looks at them.
* **The flag never reaches R.** `refine_schedule` writes only `.time` and
  `.step_size` into `Parameters`, so the field list is unchanged -- which matters
  because `scripts/refined-century.rds` is a whole serialised `Parameters` and a
  missing field is `Index out of bounds`, not a warning.
* `test-strategy-ff16.R:232` pins `length(ode_times) == 276`; `test-scm.R:424`
  pins `length(traj) == length(grid)`. **A junction as a row breaks these two
  first.**
* `Solver::history` and `SCM::history` are **not** residue: plant calls
  `set_collect(false)` and never re-enables, but the lorenz and leaf_thermal
  examples read odelia's through R, and `run_scm(collect = TRUE)`'s entire return
  value is built from plant's. `collect` gates nothing but those snapshots.

## What the tests actually guard

⚠️ **`test-gradient-ladder-identity.R` is blind to a junction-transpose error by
construction.** Every assertion in it compares the sweep to *itself* -- two
sweeps, a metric permutation, a split against the whole -- so a uniformly wrong
junction is uniformly wrong on both sides and all three blocks pass. The file
that reads like the decomposition test does not check the decomposition's
arithmetic.

**The guard rail is one file plus the captured reference:**

| | what it checks |
|---|---|
| `test-gradient-ladder-rung5.R:144-182` | the whole junction Jacobian, entry by entry, forward tangent vs the reverse transpose, at **1e-12**, at every widening |
| `test-gradient-ladder-reference.R:90-135` | five regimes against `reference/reference-gradient.tsv` -- the only instrument sharing no arithmetic with the sweep |
| `test-gradient-ladder-first-segment.R:66-97` | the lambda the walk *ends* holding, i.e. the composition of every junction transpose |

And a structural blind spot to respect: the insertion transpose is followed by
`if (lo < hi)`, so **on any fixture that introduces at t = 0 the range below the
first widening is empty and a skipped transpose there is unobservable.**
`ladder_stand_resumed` is the only fixture in the suite where that range carries
steps, which is exactly what `first-segment.R` exists for.

## `extra_splits` as an identity junction: five constraints

1. `expect_identical(split, whole)` -- the transpose must be **bit**-exact and add
   exactly zero to `parameter_adjoint`. Today no arithmetic runs at a split at all.
2. `expect_gt(ranges, unsplit_ranges)` -- a split must still increment the range
   count, and `swept` counts only ranges with `lo < hi`.
3. A split landing *on* a widening must stay a no-op -- today the `sort` +
   `std::unique` dedup does that.
4. The filters differ by one character: insertions use `at >= k_first`, splits use
   `at > k_first`. Unifying them changes `ranges` on `ladder_stand_resumed`, which
   `first-segment.R:56` pins as `n_widening + 1`.
5. Split points cross from R 1-based; `gradient_ladder.cpp` refuses `s < 1`.

## One claim in this spec was wrong about a deletion

`Solver::step()` is **live**, not dead. It is R-exposed through
`solver_interface.hpp`'s `Solver_step_impl` -> `Solver_step` ->
`lorenz-interface.R`, and the lorenz and leaf_thermal examples call it. This spec
listed it as residue on the strength of a grep for `\.step()` and `solver.step`,
which does not match `->step()`. The compiler caught it on the first install.

⚠️ **A member function reached through a pointer needs a grep that matches `->`.**
Every other name in the residue table above was checked by its bare identifier,
which does match both.

## Free subtractions this turned up

* **The last row index used as an address.** `sweep_range` passes its loop index
  `k` to `step_adjoint`, which re-derives `prev_steps.at(step).solved` from it --
  assuming `rec` spans that very `prev_steps`, which nothing checks. `sweep_range`
  already holds `rec[k]`, so `rec[k].solved` is the same object without the index
  or the assumption. This is the survivor of step 6's address removal.
* ~~`solve_adjoint`'s `!rec[hi].inserted.empty()` guard is unreachable-false.~~
  **Wrong, and it matters.** `stops` merges the junctions the run recorded with
  the cuts a caller asked for, and a cut's row has no recorded wider state -- so
  testing that state is exactly how a cut got to be free. The de-risking pass
  reached its conclusion from `insertion_rows` alone. The guard now reads the flag
  and says so.
* `state_at_segment`'s header comment is **stale**: it says no record holds the
  widened state, and `rec[start].inserted` holds exactly it.
* `apply_insertion`'s fallback path does not size `out` where the member path
  does -- latent, unreachable today.
* `man/run_scm.Rd` still documents `use_ode_times` and an `ode_step_sizes`
  argument that `run_scm` no longer takes.
