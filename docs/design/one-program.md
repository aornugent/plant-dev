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


---

# Closed: the `adjoint_segments` scare, and the two real defects under it

Recorded because the wrong conclusion was written down first and held for a while.
**There was no regression.** The pilot is exonerated, and it was never measured.

## The measurement was confounded, and the arms were not what they were labelled

The comparison read `adjoint_segments` as 0 before the pilot and 169 on it. Neither
arm was what its name said:

| directory | holds | built |
|---|---|---|
| `lib-copyB` | **plant only** | 08-28 10:02 |
| `lib-pilot` | **odelia only** | 08-28 15:23 |

Each arm therefore took its other half from the shared user library, whose plant
was built **08-27 11:56** -- a day and about thirty commits before the pilot. And
odelia's sweep is header-only: it compiles *into* plant. So the "pilot" arm ran
yesterday's sweep with the pilot's `odelia.so` linked beside it, and the pilot's own
plant (`plant/src/plant.so`, 15:27) was never installed anywhere the run could
reach it -- the profile scripts use `library(plant)`, deliberately, not `load_all`.

Both arms were pre-pilot plants a day apart. This is AGENTS.md hazard 4 exactly:
*a number taken across a swap is unattributable, and nothing announces the swap.*

## What actually moved the count: `c9aa4bed`, a day before the pilot

`c9aa4bed` *"One refusal, latched and returned; the exception goes"* (08-27 16:30)
sits inside the window between the two arms. Before it there were two ways to
refuse, and **the zeroing was attached to only one of them**: the removed lines are

```
-  } catch (gradient_refusal& e) {
-    why = e.site;
-    adjoint_segments = 0;
```

beside a second, *unthrown* route that set `why` from a latch and left the count
standing. So a refusal arriving by latch produced the all-NaN gradient **and** a
live range count. `c9aa4bed` collapsed the two representations into one latch and
put the zeroing on the unified path, and the count began agreeing with the refusal
beside it.

169 was the old bookkeeping, not new work. The fix predates the pilot.

## Confirmed on a properly paired library

One gradient call, in one process, with plant **and** odelia both built from the
pilot (`lib-pair-pilot`):

```
segments     0
metrics      3
  metric 1: 47/47 non-finite | refusal: TF24 gradient: the leaf's profit curvature
            at this operating point is 34.414226, against a floor of 0.001000 (sp 1)
```

The pilot reports **0**, the same as the newer pre-pilot plant. The pilot's merge is
not blocked.

End to end through `scripts/profile-stand-gradient.R` on that same paired library,
with the refusal now printed:

```
forward_s          31.91
gradient_s        108.56
ratio                3.4
rate_evaluations   20286
placements       2333500
swept_ranges           0
refusal            ... is 34.414226, which is not negative -- the profit is convex
                   here ... No curvature floor admits this point
```

`swept_ranges 0` agrees with the refusal beside it, which is the property target 19
buys.

⚠️ **The 185.7 s and 189.7 s in the table above are unattributable and must not be
carried forward.** They were taken on the mispaired arms. The paired figure is
108.6 s at a ratio of 3.4, and it is still the cost of a discarded sweep, so it is
a ceiling on the reverse pass rather than a measurement of one. **Every timing in
the cost model needs retaking on a fixture that answers** -- which is the one thing
this whole episode leaves open.

## The two defects that were real

**1. The century profiling fixture has been refusing all along, silently.** On all
three metrics, all 47 columns non-finite. The scripts printed timings, counts and
`swept_ranges` and never the refusal, so every number in the cost model is the price
of a full sweep whose result is discarded. The shares are still valid -- the refusal
is latched and polled after the sweep completes, so the work is real -- but the
fixture is not producing a gradient, and nothing said so. Fixed: the ladder's counts
call now returns the refusal and both profile scripts print it.

**1b. And it is not the refusal it appeared to be.** The guard is

```cpp
if (!(condition.slope < 0.0) || std::abs(condition.slope) < curvature_floor())
```

-- two limbs, one `refuse()` call, and one sentence naming the floor for both. The
century point has `slope = +34.414226`, which is **four orders of magnitude above**
the floor: the magnitude limb passes comfortably and it is the **sign** limb that
fires. The point is genuinely convex. Reading "34.414226, against a floor of
0.001000" as a magnitude failure is the natural reading and the wrong one, and it
is what sent this session looking at the floor and at the sweep instead of at the
model. **Two facts sharing one representation, and the reader pays.** Split, so the
convex case says it is convex and adds that no floor admits it.

This also contradicts a measurement the code states as its own justification.
`src/control.cpp` argues the floor from a 5625-state sweep in which "every one of
the 1351 interior points had a strictly negative curvature". The magnitude half of
that holds and is what the number rests on; the **sign** half does not -- the sweep
was over static leaf states in a named box, and a stand integrated for 105 years
reaches operating points outside it. Recorded there, beside the claim. **The sign
limb is live, not defensive**, which is exactly why it needs its own sentence.

---

# Root cause: the gradient's curvature is wrong, and the model is fine

Found with the systematic-debugging discipline. **Two hypotheses were formed and
both were wrong before the third held**, which is the part worth recording -- each
was killed by a measurement rather than by an argument.

## The measurements, in order

| # | hypothesis / question | verdict | how |
|---|---|---|---|
| 1 | `implicit_value`'s nested second derivative is wrong | **REFUTED**, exact to 1.2e-16 | new nested case in `odelia/tests/standalone/probe_implicit_tangent.cpp` |
| — | is it a regression? | **no** -- the sign limb has existed since the guard's first commit (`63235c78`, 08-11); the fixture's traits never changed | git archaeology |
| — | why did nothing catch it? | the verification convention was bit-identity, and **`identical(NaN, NaN)` is TRUE in R** -- every check compared one all-NaN gradient against another | archaeology |
| — | where is it? | NOT the final state; all 2,829,445 operating points in the run are `interior` | `ladder_rhs_adjoint_tf24`, 0.01 s |
| — | why does the margin look healthy? | `note_curvature` records `std::abs(...)`, so the min margin is 2.66 and the sign is discarded | code read |
| 2 | the collar solve returned a MINIMUM (a non-monotone marginal, three roots, TOMS748 landing on the upward crossing) | **REFUTED** | a probe dry of every returned root, over 2,829,445 interior solves: the marginal was found rising **zero** times |
| 3 | the nested-AD curvature disagrees with the marginal the solve rooted | **CONFIRMED** | below |

Hypothesis 2 was reasoned from a true premise -- an interior collar is reached only
on a bracket the marginal crosses downward, so a converged root with a positive
slope has to mean non-monotonicity -- and the *premise about the slope* was what
turned out to be false. **The reasoning was sound and the input was wrong**, which is
the failure mode a measurement catches and an argument does not.

## The confirmation

At the offending point on the century stand, collar x = 1.7984860121573381:

```
dprofit(x - h) = +1.7105919821513993e-05   (feasible)
dprofit(x + h) = -1.7544804400415615e-05   (feasible)
dprofit(x)     = -1e-06                    (a root)
                                  h = 1.798e-06

centred difference of the marginal  =  -9.6333037865457243
plant's collar_condition().slope    = +34.414225767561035
```

The marginal is **positive** wet of the collar and **negative** dry of it: it crosses
**downward**. The collar is a genuine interior **maximum**, its curvature is
**negative**, and the collar solve is correct.

**So the forward model is not wrong.** `Leaf::collar_condition` -- which differentiates
`Leaf::profit_at` twice in a nested forward-over-reverse scalar -- returns the wrong
**sign** and about 3.6x the wrong **magnitude**. The gradient refuses a perfectly good
operating point because it divides by a curvature it computed incorrectly.

This is the better of the two outcomes: **no model result changes**, and fixing it
makes the century fixture answer for the first time in its existence.

## What is being done about it

* **`CollarCondition::marginal`** -- the FIRST derivative the curvature is taken
  from, which the same sweep already computes and nothing was reading. At an
  interior point the solve put the collar where the marginal is zero, so this must
  be ~0; if it is not, `profit_at` is not the function the solve rooted and its
  second derivative is the curvature of something else. **Free, and it is the one
  check this derivation could not make about itself.** Its accessor,
  `odelia::ode::plain_adjoint`, is one `value` away from `directional_adjoint` and
  is named rather than written inline for that reason.
* **`Leaf::nonmonotone_collars`** -- kept even though hypothesis 2 was refuted,
  because it is what establishes the solve's innocence, and it would catch the
  failure it was written for if that ever does happen. One extra marginal
  evaluation per interior solve.

## Still open

Which factor of `profit_at`'s composition loses the curvature. `implicit_value` is
exonerated by measurement, so the fault is in what `profit_at` freezes around it:
every `to_passive(...)`, explicit `<double>`, and plain `double` local removes a
quantity's dependence on the collar, which is harmless for a first derivative when
the frozen value is the true partial at the point and can be fatal for a second.
The candidates are the flux inside the ci residual's denominator, the stem
potential's transport response, and any spline lookup whose second derivative is
piecewise where its first is not.

## Why the ladder never saw it

Every first-order check passes: the ladder referees gradients against forward
tangents and finite differences, and the curvature is not a gradient -- it is an
intermediate the interior derivation divides by. A wrong curvature does not perturb
a first derivative, it **refuses** it, and a refused metric is all-NaN, which
`identical()` cannot tell from another all-NaN. So the one fixture that exercises
this had no way to report it.

---

# The rearchitecture: differentiate the residual, not the objective

## What is fundamental

The leaf chooses a collar potential `p` maximising profit `π(p; θ)`. The optimum
satisfies `M(p*, θ) = 0` with `M = ∂π/∂p`. Differentiating an argmax **forces** the
implicit function theorem:

    dp*/dθ = −(∂M/∂θ) / (∂M/∂p)

so `∂M/∂p` — the curvature — is required, not incidental. Two consequences the code
already half-knows: **π's own row needs no curvature** (envelope theorem, `∂π/∂p = 0`
at `p*`), and **anything reading `p*` does** — the water outputs, hence
`resource_depletion`, hence dy/dt. Re-expressing consumers to avoid it is
**impossible**: the envelope theorem does not extend past the optimal value.

## The insight

`∂M/∂p` and `∂M/∂θ` are **first derivatives of M**. The code obtains them by
differentiating **π twice**. M already exists as a first-class function —
`dprofit_at_collar_psi` — and every other closure in this model differentiates its
own residual once: `bound_at` does, and `implicit_value(y*, dFdy, F)` *is* that
pattern, used for sigma, ci and both bounds.

**The interior point is the only place in the model that reaches for a second
derivative, and only because it differentiates the objective instead of the
condition.** `collar_condition`'s comment -- *"THIS IS THE ONE DERIVATIVE THAT
CROSSES A BOUNDARY AS A NUMBER, and it crosses because reverse mode cannot nest a
tangent above its own scalar"* -- describes a problem that exists **solely** as a
consequence of that choice.

## What the second derivative actually costs today

Not a nested scalar. **A parallel, hand-written second-order model with one consumer
and no referee.** `profit_at`'s entire p-side residual curvature comes from exactly
two frozen-`double` Taylor coefficients:

* `leaf_model.hpp:4557` -- `0.5 * d.d2psi * step * step`, the stem integral's psi
  curvature. Line `:4556` deliberately contributes **zero** curvature, so this one
  coefficient carries all of it. **No referee anywhere in the tree.**
* `roots.hpp:1598` -- `c.integrand_deriv`, the root flux curvature. Its sibling
  `c.deriv` (`:1595`) is the **interpolant's** slope while this is the **closed
  form's**, so the lift's first and second coefficients belong to two different
  functions.

The one tested closed-form second derivative that could referee the second --
`d2E_from_soil_dpsi_collar2`, checked against a difference to 1e-5 in
`test_leaf.cpp` -- **is called only from tests and never from production.**

⚠️ **And the probe that "exonerated" `implicit_value` proved less than claimed.** Its
residual `y^3 - p` has **F_pp = 0 and F_yp = 0**, so it verified only the
`F_yy * y'^2` term. It says nothing about whether those two surrogate lifts deliver
the right `F_pp` -- the term the collar curvature rests on. Retracted as over-broad;
the probe needs a residual with `F_pp != 0` and `F_yp != 0`.

## Measured: the AD curvature is right in general

On a 0.5-year stand at the default floor, at every interior point:

```
curv AD=-2.661353615  diff=-2.661353618  | marginal AD=-1.08e-14  solve=-5.11e-15
curv AD=-3.773735305  diff=-3.773735302  | marginal AD=-5.83e-15  solve=-9.33e-15
```

Nine significant figures, and both marginals ~1e-14 -- confirming algebraically what
the audit derived: **(A) and (B) are the same function to first order.** That stand's
gradient ANSWERS: 71 segments, 0/47 non-finite, no refusal, in 2.91 s.

**So the century failure is state-specific, not systemic.** The prime suspects are the
two branches keyed on passive values inside the flux:

* `roots.hpp:1540` -- `else if (std::is_same_v<T, double> && std::abs((collar_at -
  soil_at) - grav_head_z_[i]) < 1e-8)`. **The double path snaps that layer's flux to
  zero and the active path does not**, by explicit design: *"Left in place at double
  because the forward model's numbers are the snapped ones."* Where it fires the two
  paths are different functions and every derivative of them differs.
* `roots.hpp:1497` -- the equal-potentials arm is a **first-order-only lift**, so its
  curvature reads as exactly zero.

## The sentinel is not a barrier

`dprofit_at_collar_psi` returns an exact `0.0` where the collar is shut down or the
ci solve is infeasible. Asked whether anything depends on it: **two lines, both in
`differenced_curvature` (`gradient.hpp:625-626`)**, and its own comment says why --
*"the `feasible` out-parameter that would distinguish it is not carried through the R
binding."* The solve itself never reads the sentinel; it checks `ok_lo`/`ok_hi`
**before** the pin tests. A tree-wide grep for any other exact-zero test on a
marginal finds none.

So the sentinel's only value-consumer is the finite-difference referee for a second
derivative, and it exists in that form only because a bool could not cross an R
binding. **Under this rearchitecture both go.** It is not an obstacle; it is a
consequence of the thing being removed.

## What A subtracts

* **A whole scalar type and its vocabulary**: `directional_adjoint_scalar`,
  `directional_adjoint_tape`, `seed_inner_direction`, `directional_adjoint`,
  `plain_adjoint`, `CarriesDirectionUnderAdjoint`. odelia's scalars drop from three
  to two, and `xad::fwd_adj` stops being needed at all.
* **`implicit_value`'s second correction** -- the `if constexpr (SecondOrder<S>)`
  block, the `SecondOrder` concept, the second `record_with_derivatives`, and the
  paragraph explaining first-order-right/second-order-wrong.
* **The shadow second-order model**: both Taylor coefficients above, plus
  `ConditionCurvature`, the `condition_collar_slope` hand formula,
  `differenced_curvature`, `collar_step`, `shrink_decades`, and the sentinel logic.
* **The threaded `CollarCondition`** -- `collar_at`'s comment says an interior point
  is *"the only kind whose condition is a second derivative, so it is the only one
  whose gradient had to be taken in forward mode and handed over"*. Under A every
  kind's condition is first order, so the struct threaded through
  `collar_condition` -> `record_leaf_outputs` -> `collar_at` -> `outputs_at` goes.
* **The leaf's `static thread_local` tape** -- module state on a hot path.

## What A unlocks

* **The seam goes.** The leaf's derivative stops crossing as a number and composes on
  the caller's tape like every other closure. The interior point stops being special.
* **A failure class becomes unrepresentable.** `to_passive(...)` at an operating point
  is *correct* for a first derivative. Every defect in this document requires a
  second derivative of a first-order-correct assembly.
* **Performance twice over**: a nested `fwd_adj` scalar carries a dual value and a
  dual tape payload per operation, roughly 2x first order; and the per-operating-point
  tape (once measured at 89 s of a 217 s gradient) is replaced by the live one.

## Designed from the start

**M is the model's function and π is derived from it.** Today π is primary and M is a
hand-written sibling -- which is why M exists twice, at two scalars, in two
implementations, and why the two disagree. Under A: the solve roots M at `double`, the
gradient differentiates M once, π's row is the envelope theorem, and every closure in
the leaf is identical in shape. *One fact, one representation.*

"Inevitable" is the test and it passes: an argmax closed by a first-order condition
points at differentiating **the condition**. Differentiating the objective twice is
the decision that created everything above.

**The honest cost.** Templating M means templating its nested ci and psi_stem
root-finds -- real work, but `profit_at` already proves it achievable, doing exactly
that for sigma and ci. And the ladder is the referee: 673 assertions in 45 s.

---

# The root cause, localised to one point in 2,829,445

Threshold raised to a relative gap of 0.5, century stand, every interior point
compared against a centred difference of the solve's own marginal. **One
disagreement:**

```
rel=4.57  curv AD=34.41422577  diff=-9.633303787
marginal AD=-1.454809563e-06   solve=-1.454809794e-06
d(x-h)=1.710591982e-05(1)  d(x+h)=-1.75448044e-05(1)
x=1.798486012   nearest_soil=5.606982123e-08
```

Three facts, and together they name the culprit.

**1. The two marginals agree to seven significant figures.** `profit_at` and
`dprofit_at_collar_psi` are the same function, and its FIRST derivative is right
even at this point. This **rules out `roots.hpp:1540`'s `is_same_v<T,double>`
gravity snap**: a different-function defect moves the first derivative too, and it
does not move. The scalar-gated branch is a real defect and is NOT this one.

**2. Only the second derivative diverges** -- 4.6x relative, sign flipped.

**3. `nearest_soil = 5.6e-08`.** This is the single state in 2.8 million where the
collar nearly coincides with a soil layer's potential. It sits just OUTSIDE the 1e-8
equal-potentials threshold, so that arm does not fire and the general branch runs
with a near-degenerate flux numerator.

So: same function, correct first derivative, wrong second derivative, at a
near-degeneracy in the root/soil flux. That is `roots.hpp:1598`'s second-order
Taylor surrogate `c.integrand_deriv` -- whose sibling first coefficient `c.deriv`
(`:1595`) is the **interpolant's** slope while it is the **closed form's**. Two
different functions supplying the two coefficients of one lift, which is precisely
what blows up near a degeneracy.

## What this does to the options

**It is now evidence for A rather than taste.** The first-order path is demonstrably
correct at the exact point where the second-order path fails. A is built on the half
that works and deletes the half that fails -- and the surrogate is only needed
because something takes a second derivative of it.

Ranked by what the evidence supports:

1. **A -- differentiate the residual once.** Deletes the surrogate, the nested
   scalar, and the failure mode. Measured support: first derivatives correct to 7-14
   digits everywhere including the offending point.
2. **Fix `roots.hpp:1598`** so both coefficients of the lift come from the same
   function. Small, targeted, and leaves the shadow second-order model in place with
   still no referee.
3. **Guard the near-degenerate configuration.** Treats the symptom; the surrogate
   stays wrong wherever else it is stressed.

`roots.hpp:1540` and `canopy_shape.h:284` are separate, real defects found on the
way. The second is fixed; the first is a derivative of `1/r_R` against a
locally-constant forward function, and its value gap is discarded at the plant
boundary.

## The instrument, and its price

`PLANT_COMPARE_COLLAR_CURVATURE` compares the AD curvature against a centred
difference at every interior point and prints only disagreements above 0.5. It costs
a leaf copy and two marginal evaluations apiece -- the century gradient goes from
108 s to 708 s -- so it stays environment-gated. It is the check that turns "the
curvature is wrong somewhere" into one line of output, and there was no way to ask
that question before.

---

# UNBLOCKED: the century fixture answers

```
forward_s     36.22
gradient_s   391.46
segments        169
metric 1: 0/47 non-finite | refusal: NONE
metric 2: 0/47 non-finite | refusal: NONE
metric 3: 0/47 non-finite | refusal: NONE
```

**The first real gradient this fixture has ever produced.** And `segments = 169` is the
number that opened this whole investigation as a supposed regression -- it was the
honest count all along, never reported because the gradient always refused.

## The chain, end to end

1. The layer's mean conductivity is a **divided difference** of a TABULATED cumulative
   curve: `span / (G(max) - G(min))`.
2. At one operating point of 2,829,445 the collar came within **5.6e-08** of a soil
   layer's potential, so that span is 5.6e-08 and the denominator differences two
   nearly-equal table reads.
3. The VALUE survives it (~4e-10). Every derivative divides by the span again:
   `duptake_dpsi` carries ~0.7%, and the AD curvature -- which differentiates the value
   path TWICE -- carries ~0.13 relative.
4. The corrupted marginal is what the collar solve roots, so it returned a **MINIMUM**
   of profit.
5. plant's guard refused to divide by a positive curvature -- **correctly** -- and
   refusal is metric-level, so 3 metrics x 47 columns went not-a-number.

One cohort at one instant, and the whole census lost.

## The fix, and why this form

Below the crossover the mean of the integrand over the interval is its **midpoint
value**, to O(span^2). Written as ARITHMETIC from the curve's own closed form -- one
exp and one pow -- so AD supplies every order and both trait rows exactly. No
differencing, no cancellation, and no lift whose value comes from a tabulation while
its coefficients come from two other functions.

`vulnerability_curve_at<T>` is that closed form at any scalar and the double
`vulnerability_curve` delegates to it: **one definition**. It is the cumulative
INTEGRAL that needs tabulating, and differencing that integral is what caused all of
this.

Applied to both paths, because they have different consumers and I got it wrong the
first time: `duptake_dpsi_impl` feeds the marginal and therefore the SOLVE, while the
templated `uptake` is what plant's curvature is differentiated through. Fixing only
the first moved the operating point and left it convex.

## The threshold is measured, not chosen

`test_leaf`'s "the mean conductivity" table differences the two forms across eleven
decades of span and finds a clean V bottoming at ~1e-11:

| span | rel gap | regime |
|---|---|---|
| 1e-2 | 5.751e-07 | midpoint truncation, span^2 |
| 1e-4 | 5.700e-11 | |
| **1e-5** | **9.763e-12** | **crossover** |
| 1e-7 | 4.102e-10 | difference cancellation, 1/span |
| 1e-11 | 1.370e-05 | |

## What the session's wrong turns were worth

Three hypotheses died by measurement, and the last two died because **the instrument
was the thing at fault**:

* a finite difference at 1e-6 straddles a 5.6e-08 feature by 32x, and at 1e-8 and
  below is swamped by the marginal's own ~1e-6 noise divided by the step. Refined
  across three steps it read -9.63, +166, -10588. **It never converged, so it was
  never evidence** -- and a probe built on the same step size reported zero exceptions
  in 2.8 million.
* the two analytic routes agreed with each other because they **share the corrupted
  input**, not because they were right. Agreement between routes is only evidence when
  the routes are independent, and these were not.

The rule this leaves: near a coincidence like this, **no finite difference is a
referee**, and two routes agreeing prove nothing until you have checked what they
share.


---

# All three sites, and the referee the region can actually have

`d2uptake_dpsi2` had the worst of the three cancellations, because `quotient_d2T` is
built ON `quotient_dT` -- so the numerator that already spent one order of the span
spends another. Fixed the same way, which completes the set:

| site | consumer | fixed |
|---|---|---|
| templated `uptake` | what plant's curvature is differentiated through | yes |
| `duptake_dpsi_impl` | the marginal, and therefore the SOLVE | yes |
| `d2uptake_dpsi2` | `marginal_collar_slope()`, the second analytic route | yes |

**And all three now read ONE definition of the curve.** `duptake_dpsi_impl`'s midpoint
reads had been taking the CLAMPED TABLE while the other two read the function;
`vulnerability_curve_at<T>` and `vulnerability_curve_slope_at<T>` are that one
definition, with the double versions delegating. `f''` comes from a tangent through the
same closed form rather than a hand-derived sibling that could drift.

That was the original defect stated exactly: a lift whose value came from a tabulation
and whose two coefficients came from two other functions.

## The referee, which is continuity rather than a difference

A difference cannot check this region -- that is *why* the midpoint form exists -- so
the new check sweeps the collar onto a layer's potential across the crossover and
requires the sequence to stay smooth and finite:

```
span       dE/dT                  d2E/dT2
5.0e-03    7.68627512125918e-06   -2.7085922002691e-08
1.0e-05    7.68640995784061e-06   -2.69753108270189e-08   <- crossover
5.0e-06    7.68641009250731e-06   -2.69615862470371e-08
5.0e-08    7.68641022596688e-06   -2.69614732344725e-08
```

No jump at the switch; worst step-to-step change 1.4e-05 and 3.8e-03, the latter at the
crossover itself and being the divided difference's own error there. Before this the
sweep went to noise below ~1e-07.

## Where it lands

```
forward_s  32.15   gradient_s  112.16   ratio 3.5
segments   169     0/47 non-finite      refusal: NONE
```

odelia 346, ladder 673, non-ladder 3295, test_leaf 1121 -- all at baseline. **And the
plan's cost model finally has numbers taken on a fixture that answers**, which every
figure before this was not.

---

# The helper, and where increment 2 actually starts

## Seven copies of one mean

Every derivative of the uptake is a MEAN over the layer's suction interval -- the
conductivity curve for the resistance, one of its trait derivatives for a trait row.
Seven callers each formed their own as `integral / span`, each "replicated bit-for-bit
from uptake_impl" in their own words, and each inheriting the same cancellation.

They now read `layer_mean`, `layer_mean_dtrait`, `layer_mean_dbound`,
`layer_mean_dtrait_dbound`, `layer_mean_dbound2` and `layer_mean_dbound_mixed`, and
**not one of them builds an integral any more**. `layer_integral` -- the replicated
construction -- exists once.

Writing them in means is what removes the span from the algebra: `k*span/integral` is
`k/mean`, `-k*span*dinteg/integral^2` is `-k*mean_d/mean^2`, and the second
derivatives are the quotient rule on those. The span was what the accuracy was being
spent on, and it is gone from every formula.

Two further collapses fell out: the choice of accessor past the knots (issue #1's,
"and NOT the conductivity read") is made in one place instead of at each caller, and
`integrand_dtrait_kernel<T>` gives the trait curve's value and its psi-slope from one
expression.

## Two of my own errors, and the check that caught them

⚠️ **The midpoint limits are f'/2, f''/3 and f''/6. I first wrote the last two as
f''/4.** The continuity sweep could not see it -- those terms contribute little to
dE/dT at the state it walks -- so it needed a check that compares the two forms
directly. They meet at 5.4e-06, 8.8e-05 and 2.0e-06, which is what confirms the
constants: an f''/4 would bottom out near 25%.

⚠️ **And that check found a second error: ONE threshold was wrong for two of three
quantities.** The divided difference divides by the span once for the mean, twice for
its bound derivative and three times for the second, so each degrades a decade or more
earlier than the last:

| span | d/dbound | d2/dbound2 | mixed |
|---|---|---|---|
| 5.0e-03 | 5.131e-04 | 4.653e-04 | **6.032e-07** |
| 5.0e-04 | 5.133e-05 | **1.595e-06** | 8.811e-05 |
| 5.0e-05 | **5.436e-06** | 2.948e-02 | 5.897e-02 |

A single 1e-5 left both second derivatives on the degraded form across a band two and
three decades wide. Now 1e-5, 5e-4 and 5e-3, each measured.

**The lesson repeats the session's:** a quantity whose referee cannot discriminate an
error is a quantity with no referee. The continuity test was real and passed; it was
simply blind to this, and only a direct comparison of the two forms could see it.

## Where increment 2 starts, and why not here

`implicit_value<S>(p*, dM/dp, M)` needs M evaluated with ACTIVE PARAMETERS. M contains
`dE_up/dp`, which is `duptake_dpsi`, which is `double`-only. So increment 2's enabling
step is templating the supply's collar derivative:

1. generalise `uptake`'s `G_integral` lift -- it is a local lambda capturing eight
   pieces of per-loop context (`use_integral_cache`, `collar_at`, `soil_at`,
   `G_at_T_collar`, the layer index, `at_scalar`, `root_b0`, `root_c0`)
2. template `layer_integral`, `layer_mean` and `layer_mean_dbound` on it
3. template `duptake_dpsi_impl`, which is now four lines of arithmetic over those
4. build M at scalar S in `leaf_model`, and rewire `collar_at`
5. delete `CollarCondition`, `collar_condition`, `plain_adjoint` and plant's threading

**The helper is what makes 1-3 tractable**: the enabling step went from seven
scattered rewrites to three functions, because no caller forms an integral any more.

And there is a referee waiting for it: `d(duptake_dpsi)/dT` taken at a tangent must
equal `d2uptake_dpsi2` -- two independent routes to one number, which is the only kind
of check this region admits.

⚠️ **Also still unrefereed, and the reason increment 2 is worth doing beyond
tidiness:** `cond.gradient` is `dM/dtheta = d2(profit)/dp dtheta`, the same
second-order class as the curvature, from the same nested pass, and nothing checks it.
Only the curvature has been measured. Under increment 2 it comes from `implicit_value`
recording M's own tape -- first order, and refereeable.

---

# Increment 2: what landed, and the one closed form that blocks the rest

## Three of the five steps subtracted before writing any code

The scoped plan was: generalise the `G_integral` lift, template the layer-mean
helpers, template `duptake_dpsi_impl`, build M at scalar S, rewire `collar_at`.

**Steps 1-3 turned out to be unnecessary.** Inside `implicit_value(p*, dM/dp, F)`, F
is called with the collar PASSIVE and only the parameters active -- so `duptake_dpsi`
never needs templating on the collar. What is needed is `dE_up/dp` carrying its
PARAMETER derivatives, and the model already computes those in closed form:
`d2uptake_dpsi_droot_curve`, `d2uptake_dpsi_dpsi_soil`, and `duptake_droot_carbon`'s
mixed term -- all tested, none with a production consumer.

Two more fell out while reading: **`transpiration` IS `flux`** by the T1 residual
(`kmax*(G(sigma) - G(collar)) - flux = 0`), which `profit_at` already builds at S, so
no lift for it; and `LeafInputs::rebind_from<double>()` already exists, so the passive
inputs for `dM/dp` come from the active ones with no new mapping.

## What landed

**odelia: the theorem reports, and the policy belongs to the caller.** `implicit_root`
and `implicit_value` are the same theorem -- the header says "the two differ only in
whether the row is supplied or taped, and both take the slope". They also differed in
what a degenerate slope does, and that difference is real: a BOUND's value IS what the
equation defines, so a missing row is a structural zero nothing can detect and it must
stop; an INTERIOR optimum is still the point it was, and an output the envelope
theorem spares does not read the collar at all, so it can report. That is now
`implicit_value_reported` (the theorem) plus `implicit_value` (it, and the stop), with
the choice made at the call site instead of by which name you reach for.

**phylloptim: the marginal reads its inputs.** `marginal_assembled` reached for the
leaf's MEMBERS -- kmax, the stem parameters, and the kernels' vcmax/jmax/curvature/
respiration through their one-argument overloads. At double that is the same
arithmetic; at an active scalar it is a silent zero in every parameter it touches.
Verified as a no-op where it must be: the closed slope still matches a difference to
the identical **2.560e-09**.

## The one thing that blocks the rest

Building M at an active scalar needs `d(dE_up/dp)/d(theta)` for EVERY active input.
The model has it for traits, soil potentials and layer carbon. **It does not have it
for the two resistance inputs** -- `r_R_H_min` and `r_R_V_sum`, which are what plant
actually makes active, having mapped carbon onto them on its own side.

They are mechanical from `r_R = k/g + V` and
`dE_i/dT = (r_R - num * dr_dT)/r_R^2`, and they can be refereed against a difference
in the fast harness. But they are hand algebra of exactly the kind that produced two
wrong constants in this session's previous increment -- both caught only because a
direct referee was built first. So the order is: **write the referee, then the
algebra**, not the other way round.

## What deleting the interior case's `implicit_root` will take with it

`implicit_root` has exactly ONE caller in the tree: `collar_at`'s Interior case. When
that moves onto a taped residual, the following go with it -- `implicit_root`,
`CollarCondition`, `Leaf::collar_condition`, `odelia::ode::plain_adjoint`, and the
threading of a condition struct through `record_leaf_outputs` -> `collar_at` ->
`outputs_at` in plant.

⚠️ And the reason it is worth doing is not tidiness. `cond.gradient` is
`d2(profit)/dp dtheta` -- the same second-order class as the curvature, from the same
nested pass over an assembly whose second-order content nothing referees. Only the
curvature was ever measured, and it was wrong. Under the taped residual that quantity
becomes first order and refereeable.

---

# Increment 2 done: one form for every collar closure

```
Interior                   -> implicit_value_reported(p*, marginal_collar_slope(), marginal_at)
PinnedWet, ShadeDeath      -> bound_at -> implicit_value
PinnedDryRootCrit          -> bound_at -> implicit_value
PinnedDryRootPsiCrit       -> the bound IS the trait
HydraulicShutdown          -> does not move
```

`collar_at` had one case that did not look like the others. The bounds each closed on
a residual; the interior point called `implicit_root` with rows handed over as
NUMBERS -- because those rows needed a second derivative of the profit, which is the
thing this session found wrong.

## Deleted

* `odelia::implicit_root` -- the supplied-row form. One consumer in the family, and it
  is gone.
* `odelia::ode::plain_adjoint` -- its only use was inside the nested pass.
* `Leaf::CollarCondition` and `Leaf::collar_condition` -- the struct and the pass that
  filled it.
* the condition threaded through `record_leaf_outputs` -> `collar_at` -> `outputs_at`
  in plant: one fewer parameter on two calls, one fewer type to learn.
* one of the refusal message's two readings of the marginal. It carried both because
  the question was whether they agreed; they do, and the assembly that made them
  differ is gone.

odelia's R tests are RETARGETED, not deleted: the same theorem reached through a
residual whose derivatives ARE the two slopes and whose value at the root is zero, so
every expectation survives -- the quotient, the chain through the root, the fold
reported rather than thrown, and a non-finite row refused after the quotient.

## Added, and why each is the smaller thing

* `implicit_value_reported` -- the theorem, returning its report. `implicit_value` is
  it plus the stop. The two forms differed in what a degenerate slope does and that
  difference is REAL: a bound's value IS what the equation defines, an interior
  optimum is still the point it was. The policy moves to the call site.
* `duptake_dpsi_at<T>` -- the supply's collar derivative at any scalar, four lines
  over the shared layer means. The marginal needs it; nothing else could supply it.
* `collar_coords_at<S>` -- the flux, the stem potential and the intercellular CO2,
  built ONCE and read by both `profit_at` and `marginal_at`, which would otherwise
  carry the same two implicit closures apiece.

## The referee came before the algebra

Twice this session an error survived because the check could not discriminate it. So
the templated supply derivative was refereed two ways before anything was wired to it:

* against the double form it replaces: **gap exactly 0.000e+00**, bit-identical
* against `d2E_from_soil_dpsi_collar2`, computed by an entirely different route:
  **7.327e-15**

## And one lean failure of my own, found by reading rather than timing

The helper made every caller read `layer_mean` and then `layer_mean_dbound`, and the
second formed the integral AGAIN -- four table reads per layer where there had been
two, and two passes of lifts on the active path where one will do. The mean is now
passed. Cleaner and slower is not the trade.

⚠️ **No timing is claimed from today.** The machine is under a load average of 13 from
another user's jobs and a forward pass that runs in 32 s clean took 53 s. This was
found in the call graph, not on a clock.

## What plant gained

The guard now tests the SAME slope the closure divides by. It used to read
`condition.slope` from one pass while the closure divided by it and took its parameter
rows -- `d2(profit)/dp dtheta`, the same second-order class as the curvature that came
back positive at an interior maximum -- from the same unrefereed place. Those rows are
now taped from the condition itself.

---

# The two forms collapse, and the gradient's cost, measured

## `implicit_value_reported` goes, and the `point` channel with it

I added it earlier the same day, arguing the policy belonged to the caller: a BOUND
must stop, since its value IS what the equation defines and a missing row would be a
structural zero nothing could detect, while an INTERIOR optimum could carry on and say
so, because the envelope theorem spares the objective. Both statements are true of the
theorem. **Neither is true of the consumer**, and reading the consumer is what settled
it:

* the report was filled by ONE of `collar_at`'s five arms;
* it was read in exactly ONE place, where plant turned it into `refuse(...)`;
* which is what the catch around the throws already does, at the same metric-level
  grain.

Two mechanisms, one outcome. Deleted: the function, `LeafOutputs::point`, the
out-parameter on `collar_at` and `outputs_at`'s signature, and plant's branch. What is
left is one theorem with one way to fail, and `collar_at` is finally one shape for all
five kinds with nothing threaded through it but the inputs.

The R harness catches the throw and reports it back, so every expectation survives.

## The gradient costs a third more, and that is measured rather than guessed

Both arms built from source, INTERLEAVED in one session, three pairs:

| rep | forward before -> after | gradient before -> after | ratio | load |
|---|---|---|---|---|
| 1 | 41.71 -> 39.98 | 140.45 -> 179.64 | 1.28 | 10.4 / 8.9 |
| 2 | 35.14 -> 39.63 | 131.89 -> 186.05 | 1.41 | 12.4 / 12.0 |
| 3 | 39.40 -> 32.94 | 109.66 -> 144.11 | 1.31 | 2.7 / 1.2 |

**+33% on the gradient, and nothing on the forward** (mean ratio 0.98). The ratio holds
across loads from 1.2 to 12.4, which is the whole reason for interleaving -- the
absolute numbers move by 60% between reps and the ratio does not. Both arms answer
identically: 169 segments, all three metrics, no refusal.

**Where it goes.** The old interior closure took ONE nested pass over `profit_at` and
read three things off it. The new one evaluates `marginal_at` at the active scalar,
which builds the operating point's coordinates again and then does a full per-layer
supply-derivative pass -- work the old path got implicitly from differentiating the
flux twice on a tape it was already paying for.

**What it buys**, so the trade is on the table rather than implied:

* `dM/dtheta` is first order and refereeable. It was `d2(profit)/dp dtheta` from a
  nested pass, the same class as the curvature that came back positive at an interior
  maximum, and NOTHING checked it.
* one closure form for all five kinds, and five concepts gone -- `implicit_root`,
  `plain_adjoint`, `CollarCondition`, `collar_condition`, `point`.

**Where to look if the third is wanted back**: `collar_at` builds the coordinates for
`marginal_at`, then `outputs_at` builds them again for `profit_at`, per node per step.
They are at different collars -- one is the residual's variable, the other the placed
value -- so they cannot simply be shared, but that is where the duplicated work is.

---

# The gradient's third: root cause

The +33% was real, and it is one function. Found with the four-phase discipline;
what it cost to find was two profiles and one grep, because the counted numbers
ruled out most of the space before any timing was read.

## What the counts ruled out first

Both arms profiled back-to-back in one session at 250 Hz, arm A the pre-increment-2
commits and arm B increment 2, each verified by grepping its INSTALLED headers
rather than by the directory it sat in:

| | arm A | arm B |
|---|---|---|
| forward | 37.06 s | 34.82 s |
| gradient | 118.04 s | **154.34 s** |
| rate evaluations | 20,286 | 20,286 |
| placements | 2,333,500 | 2,333,500 |
| swept ranges | 169 | 169 |
| metrics | 3 | 3 |

**Every counted number is identical, so it is not more calls -- it is more work per
call.** And the forward is unchanged, so it is the recording path. Sample totals
reconcile with the wall clock to under 1% on both arms, which is what says the
profiles are of the thing that was timed.

## What the profile says, and what it eliminates

Self time, arm A -> arm B, in samples:

| | A | B | delta |
|---|---|---|---|
| `computeAdjointsToImpl` + its lambda | 6,826 | 11,440 | +4,614 |
| `OperationsContainerPaired::for_each` | 2,140 | 2,813 | +673 |
| `append_n` | 1,454 | 1,987 | +533 |
| `unregisterVariable` | 1,113 | 1,652 | +539 |
| `std::max` (the slot high-water mark) | 995 | 1,498 | +503 |
| `memset` + `__fill_a1` (`initDerivatives`) | 859 | 1,840 | +981 |

Those sum to about 8,500 against a total delta of 8,523. **Essentially all of the
regression is XAD bookkeeping -- writing the tape and walking it -- and none of it
is the model's arithmetic**, which got CHEAPER: `uptake_impl` 5,285 -> 4,544,
`duptake_dpsi_impl` 2,799 -> 2,385, `toms748_solve` 8,498 -> 8,001. That eliminates
the double-precision path, the midpoint work and the layer means in one reading.

## The cause: a tangent above the adjoint, on plant's tape

`marginal_assembled` is **11.6% of the whole profile, about 22 s, and does not
exist in arm A at all** -- roughly 60% of the regression in one function.

`leaf_model.hpp:1197` is `using TT = typename xad::fwd<T>::active_type`. At the
gradient `T` is `active_scalar<double>`, so **TT is `FReal<AReal<double>>`: a
tangent wrapping an adjoint.** Every operation on it carries a value and a
derivative, both of which are `AReal<double>`, so **both halves record onto
plant's tape** -- which is then swept once per census metric, three times.

Three kernels and thirteen `lift`s run at that scalar per interior placement,
2,333,500 of them. The focused profile settles what they spend it on: inside
`marginal_assembled`, `exp_inline` is about 148 samples and everything else is
`registerVariable`, `std::max`, `pushLhs`, `append_n` and `BinaryExpr`. **The
arithmetic is a rounding error; the cost is the tape.**

Beside it: `collar_coords_at` at 3,484 samples is the SECOND coordinate build at
the active scalar, and `duptake_dpsi_at` at 811 is the extra active per-layer walk.
Those are the rest of the delta.

⚠️ **Increment 2 did not delete the nested scalar. It deleted odelia's NAMED one
and rebuilt the opposite nesting by hand in the hot path.** `directional_adjoint_scalar`
was `AReal<FReal<double>>`, adjoint outside; this is `FReal<AReal<double>>`, tangent
outside. It does not grep as what it is, because it is spelled
`xad::fwd<T>::active_type` at the use site. And `ode_interface.hpp` claimed beside
the deleted alias that *"no tangent scalar wraps an adjoint one"* -- which the
family had been doing, per placement, since increment 2 landed.

## The second defect, which is free

`marginal_collar_slope(in.profit.rebind_from<double>())` is evaluated **twice per
interior placement with identical arguments**: `tf24_strategy.h:1352` for the
curvature guard, `leaf_model.hpp:4882` as the closure's `dFdy`. The comment above
the first says *"⚠️ THE SAME NUMBER THE CLOSURE DIVIDES BY"* -- so the code states
the identity and then computes it a second time. It is double-precision work, so
it is a small share of the regression; it is still two sources for one fact, and
the guard's agreement with the divisor is today a coincidence of construction
rather than something that cannot be otherwise.

## What is NOT available, priced so nobody pays for it twice

* **Dropping the tangent's value half.** Only `xad::derivative(...)` is read off
  the three kernels, so the value looks discardable. It is not: forward mode forms
  the derivative FROM the values, and those values carry the parameter rows, so
  their statements are load-bearing.
* **A closed form for `A'` and `C'`.** That is the hand-written second-order
  sibling this whole increment removed, and the one that produced two wrong
  constants earlier in this session. Not that.
* **Sharing the two coordinate builds.** They are at the same collar VALUE and a
  different derivative structure -- `marginal_at` needs the collar passive for the
  theorem, `profit_at` needs it active. Same numbers, genuinely different
  recordings.

## What is available

1. **Sweep once for three metrics** (`one-reverse-pass.md` mechanic 8, `xad::adj<T, 3>`).
   The regression is amplified threefold by being walked once per metric, and the
   sweep is the larger half of it. This was a standing item; increment 2 has
   roughly doubled what it is worth.
2. **The duplicated slope**, above.
3. **Accept it.** What the third bought is stated in the previous section and has
   not changed: `dM/dtheta` is first order and refereeable where it was an
   unrefereed second-order pass, and five concepts are gone.

---

# Against ad/v3-forward: two regressions, not one

The remembered figure was right. Three arms, interleaved, two reps agreeing within
0.5%, on a quiet machine, every arm identified by grepping its INSTALLED headers:

| arm | forward | gradient |
|---|---|---|
| `ad/v3-forward` (odelia 03a14a9, phylloptim edde81f, plant 68a4fcc3) | 30.68 / 30.74 | 103.27 / 103.44 |
| the midpoint era, before the helper | 35.02 / 34.97 | 109.67 / 109.81 |
| HEAD | 32.50 / 32.62 | 142.96 / 143.40 |

`evaluations` 20,286 and `placements` 2,333,500 on **all three**, so the trajectory
never moved and the arms are doing the same work.

⚠️ **The confound this looked like it had, and does not.** The v3 arm REFUSES on this
fixture -- it predates the midpoint form -- so its gradient could have been cheap
because it did less. It is not: v3 already carries the latched refusal rather than the
exception, and a latched refusal skips only the final `record_with_derivatives` per
non-objective output. `collar_at` and `outputs_at` run in full either way. Both arms
sweep the whole recording.

**+38.6% on the gradient, in two independent pieces.**

## Piece one: the midpoint era, +6.2% gradient and +14% forward

The forward is the cleaner signal, because it carries no tape. Profiled both ends:
7,940 samples against 8,496, **+556 ≈ +2.2 s**, agreeing with the clock.

| | v3 | HEAD | delta |
|---|---|---|---|
| `use_midpoint_mean` | **did not exist** | 113 self | **+113** |
| `root_vuln_integral_at` (cum) | 619 | 782 | +163 |
| `uptake_impl` (cum) | 1,112 | 1,291 | +179 |
| `duptake_dpsi_impl` (cum) | 1,342 | 1,580 | +238 |

**`use_midpoint_mean` alone is a fifth of the forward regression.** It is inlined and
it is two comparisons -- and it runs at **ten call sites, per layer, per evaluation**,
tens of millions of times, to select a branch that fires at ONE operating point in
2,829,445. The rest is the restructured mean path reading the curve more often.

**The defect is not the correction, it is where the question is asked.** The span is a
property of the layer and the collar, fixed for one evaluation of the supply; the
regime it selects is asked once per QUANTITY per layer per evaluation instead. And
there are three thresholds, so there are three regimes, not one -- which is a
structure the loop should carry, not a predicate each caller re-derives.

The layer-mean helper later returned about half of it (35.0 -> 32.5), by removing the
second integral each caller formed.

## Piece two: increment 2, +30.6% gradient

`marginal_assembled` at `FReal<AReal<double>>`, recorded on plant's tape and walked
once per metric. Rooted causally in the section above.

## And the escape that is measured shut

`one-reverse-pass.md` mechanic 8 -- three metrics in one walk at `xad::adj<T,3>` --
is the lever this regression makes look attractive, and **it was already measured and
it is not there**: odelia `828cd83` reports width three at **1.15x to 0.97x**, from 15%
slower to 3% faster, decided only by whether the derivative array still fits in cache
at three times the size. The walk is shared; the scatter is N times the bytes. Both
places that proposed it now carry the number.

---

# Redesign: where the leaf's derivative is taken

Written after both regressions were root-caused, because the two of them name the
same mistake from opposite ends.

## What is fundamental

Nothing here is a design decision.

1. The leaf solves an argmax in double: `p* = argmax pi(p; theta)`, closed by
   `M(p*, theta) = 0` with `M = dpi/dp`.
2. Differentiating an argmax forces the implicit function theorem, so
   `dp*/dtheta = -(dM/dtheta) / (dM/dp)`. **Both ingredients are FIRST derivatives
   of M**, and M is a function the model already has.
3. Everything the stand reads from the leaf except profit reads `p*`, so it needs
   `dp*/dtheta`. Profit's own row is the envelope theorem and needs no curvature.
4. A layer's mean conductivity is an integral over its suction interval, and which
   evaluation of it is stable depends on the interval's WIDTH. That is numerical
   analysis, not a choice.
5. plant's tape is large -- 5.79 MB per rate evaluation -- and is walked once per
   census metric. **Anything recorded on it is paid for three times**, and the
   escape from that is measured shut (mechanic 8, 1.15x-0.97x).

## The mistake, which is one mistake wearing two faces

Both regressions are the same error: **a decision taken where it is used rather
than where it is decided, and paid for on the hottest path available.**

* Fact 4 says the regime depends on the span. The code asks "is the span small?"
  at ten sites, per layer, per evaluation -- tens of millions of times -- for a
  branch that fires once in 2,829,445. **The span is decided once per layer; the
  question is asked once per quantity.**
* Fact 5 says plant's tape is the expensive place. Increment 2 put M's entire
  evaluation there, including a tangent above the adjoint, to obtain **one row per
  parameter**. Everything else recorded is scaffolding for that row.

## The two-by-two that names it

The deleted `implicit_root` path and increment 2 differ in TWO ways at once, and
the plan has been treating them as one:

| | rows from d2(pi)/dp dtheta | rows from dM/dtheta |
|---|---|---|
| **crossing as numbers** | `implicit_root`. Measured WRONG at one point in 2.8M. | **not tried** |
| **recorded on plant's tape** | not tried | increment 2. Correct, +30.6%. |

**What was wrong with `implicit_root` was never that rows crossed as numbers. It
was that the numbers were a second derivative of a first-order-correct assembly,
which nothing refereed.** Increment 2 fixed the quantity and, in the same move,
threw away the cheap mechanism -- because the two were spelled by one function
name. The empty cell is the one the facts point at.

## The three moves

**1. The regime is a property of the layer, so the layer carries it.**
The supply loop already forms `lo`, `hi` and `span` per layer. It should form the
regime there too and hand it down, instead of ten callers each re-deriving it from
two thresholds and a comparison. There are THREE measured thresholds -- the divided
difference divides by the span once for the mean, twice for its bound derivative
and three times for the second -- so there are three regimes, and three regimes in
a value is a structure where three booleans recomputed at ten sites is a smell.
`competition_split` is the precedent: the same move removed three booleans and made
a double reduction unrepresentable.

Worth: `use_midpoint_mean` is 1.3% of the forward and a fifth of that regression,
plus whatever the repeated `to_passive` costs on the active path, which is not the
same number.

**2. M's rows are taken on the leaf's own tape, and cross as numbers.**
One recording of M at `active_scalar<double>` with the parameters registered, swept
ONCE, gives every `dM/dtheta` in one pass. plant then records `p*` against those
rows -- which is `record_with_derivatives`, the primitive `implicit_value` already
ends in.

This keeps every property increment 2 bought: the rows are first order, they come
from AD over M rather than hand algebra, and they are refereeable against a
difference of M. What it drops is M's statements from the tape that is walked three
times.

⚠️ **This is the architecture's own stated boundary, which increment 2 crossed.**
`one-reverse-pass.md` fact 3: *"That root-find's derivative is SUPPLIED, by the
implicit function theorem, not recorded."* The leaf is a submodel with its own
solve; its derivative is data at the package boundary. Increment 2 made it a
composition instead, and the 30.6% is what that costs.

⚠️ **Predicted, not measured.** `collar_condition` was a comparable per-placement
nested record-and-sweep and cost 2.3% of the gradient. The two things this replaces
-- `marginal_assembled` at 11.6% and the second `collar_coords_at` at 7.3% -- are
about 19%. So the expectation is that most of increment 2's cost comes back and the
correctness stays. **That expectation is the thing to measure first**, on the fast
harness, before any of it is wired in: record M on a private tape at one interior
point and compare its rows against a difference of M, and its cost against the
current path.

⚠️ **What it does NOT extend to.** Supplying rows is right for the collar because
the collar is ONE output: one sweep against three walks of all of M. The leaf's
other outputs are profit plus one per layer, so supplying their rows costs
`1 + n_layer` sweeps against three walks, and that is not obviously a win. The
boundary is "one output whose residual is expensive", and it should stay a measured
boundary rather than become a rule.

**3. The slope is what the solve found, and is read rather than recomputed.**
`marginal_collar_slope` is evaluated twice per interior placement with identical
arguments, under a comment saying it is the same number. It is `dM/dp` at `p*` --
a property of the operating point, like `p*` itself, and the record already carries
what the solve found.

## Residue this takes with it

| | |
|---|---|
| `ConditionCurvature`, `CostTraitRows` | declared in `leaf_model.hpp` and named nowhere else -- the deleted second-order pass's row types |
| `condition_collar_slope` | survives in two comments describing a function that is gone |
| the second-order branches of `cumulative_lift` and `stem_integral_at` | reachable only through `marginal_assembled`'s `TT`; if move 2 changes what that is, `SecondOrder` and both branches go |
| `SupplyCurveTrait` and the root-curve derivative chain | `subtraction-targets.md` 15, unblocked once nothing needs a second-order supply row |

## Landing order

Subtraction first, then the move that makes the next one smaller.

0. The two orphaned structs and the stale comment. Free.
1. Move 3 -- the slope read once. Small, and it makes move 2's `dM/dp` argument a
   read rather than a call.
2. Move 1 -- the layer's regime as a value. Independent of the tape entirely, and
   it is the forward regression.
3. Move 2 -- M's rows on the leaf's own tape. **Referee first**: the rows against a
   difference of M in `test_leaf`, and the cost on the fast harness, BEFORE wiring.
   That order is not a preference; it is what the last two increments cost when it
   was the other way round.

## What would falsify this

Move 2 rests on a prediction. If a private recording of M costs more than about 5%
of the gradient -- if the per-placement tape cycle dominates, as it nearly did for
`newRecording()` -- then supplying the rows is not cheaper than composing them, and
the honest answer is that increment 2's cost is the price of its correctness and the
plan should say so instead of looking for an escape.

⚠️ **`SecondOrder` is a proxy that is already false in one direction.** It reads
`derivative_type != double`, which is a test for "carries a second derivative" only
by accident: at `AReal<double, 3>` the derivative type is `Vec<double,3>` and the
concept answers TRUE for a scalar carrying three FIRST derivatives, silently
enabling both second-order branches. Nothing instantiates that width today, and the
concept should say what it means before anything does.

---

# Measured: what a placement costs, and what is actually making this hard

`probe_leaf_tape` counts what one leaf placement writes to the tape it is recorded
on, at 1, 3 and 5 soil layers. The century fixture is **5** (`soil_number_of_depths`
defaults to 5 and nothing in the script overrides it). Everything below is that
probe or the XAD source, not a profile and not an argument.

## One placement, at the interior point

| | statements | operations |
|---|---|---|
| `collar_at` | 812 | 1,070 |
| ...`collar_coords_at` | 117 | |
| ...`duptake_dpsi_at` | 101 | |
| ...**`marginal_assembled`** | **592** | |
| `outputs_at` | 245 | 399 |
| **one placement** | **1,057** | **1,469** |

**The collar residual is 77% of the leaf's tape, and it produces ONE number.**
`outputs_at`, which produces everything plant actually reads -- profit and one draw
per layer -- is 245.

| | |
|---|---|
| record one placement (marginal, on a live tape) | 28.2 us |
| sweep it once | 1.80 us |
| clear + release + register, on a reused tape | **0.14 us** |
| **record : sweep** | **16 : 1** |

⚠️ **Recording dominates sweeping sixteen to one, and that overturns the plan's
standing assumption.** Every proposal that moves tape from one place to another --
a private tape, a dense block, three metrics in one walk -- is arguing about the
*sweep*, which is a sixteenth of the cost. **What matters is what gets recorded at
all.**

⚠️ **And the tape CYCLE is free while the tape is not.** Clearing, releasing and
re-registering is 0.14 us, so a per-placement recording cycle is not what made
`collar_condition` cost 2.3%. But constructing a `Tape` reserves **192 MiB** of
chunks (`ChunkContainer.hpp:41`, `OperationsContainerPaired.hpp:37`, one chunk each
at construction), so a private tape must be a held member reused across placements,
never one built per placement.

## What is making this hard, in one mechanism

The leaf's value is defined BY a derivative: `p*` is where `M = dpi/dp` vanishes.
So the stand's gradient needs derivative information one order above the model's own
definition. The code assembles M in closed form except for two ingredients --
`dA/dci` and `dC/dsigma` -- which it takes with a forward tangent one order above
the working scalar.

**At the gradient that tangent sits above an adjoint, and that is where the cost
is.** Measured, the same three kernels at the same point:

| | statements |
|---|---|
| the three kernels at the working scalar `A` | **31** |
| the same three at `TT = FReal<A>` | **566** |
| | **18.3x** |

Not 2x. `FReal` holds its value and its derivative as separate members and assigns
each separately, so **XAD's expression templates cannot fuse across the nesting**:
one recorded statement at `A` becomes a statement for the value plus one per link of
the derivative chain. Per kernel: electron transport 197, colimited assimilation
288, hydraulic cost 81.

That is the whole of increment 2's regression, and it also says what the deleted
`collar_condition` really cost -- **the same nesting**, on a private tape swept once
rather than on plant's swept three times.

## Landed: a dual whose derivative is structurally zero

`J0` was built at `TT` from four `lift(...)` arguments -- value set, direction zero
-- so its tangent half is identically zero and carries no information, while
costing 197 recorded statements. Evaluated at `T` and lifted it is the same `TT`:

| | statements |
|---|---|
| one placement, before | 1,057 |
| **one placement, after** | **861** |

**-18.5% of the leaf's tape, provably information-free.** `test_leaf` 1127/0 with an
identical checksum, and `test_golden` identical to the digit (the forward model does
not reach this path).

## What is left, ranked by measurement

1. **`dC/dsigma` in closed form** -- 81 statements at TT. `C = scale*(1-f(sigma))^beta`,
   so `dC/dsigma = -scale*beta*(1-f)^(beta-1) * f'(sigma)`, and `f'` already exists as
   `vulnerability_curve_slope_at<T>`. Small, and the pieces are in the tree.
2. **`dA/dci` in closed form** -- 288 statements at TT, the largest single item left
   and the only real algebra. First order, and refereeable against the tangent it
   replaces to machine precision in the fast harness.
3. **M's rows on a private, REUSED tape** -- worth about 8%: it saves two of three
   sweeps of 77% of the tape, and nothing of the recording.

1 and 2 together would take a placement from 861 to roughly 500 -- **half the leaf's
tape, in both recording and sweeping** -- against `record_leaf_outputs` at 32.3% of
the gradient.

⚠️ **The precedent for 1 and 2 is in this package and it is not the algebra that
failed.** `vulnerability_curve_slope_at<T>` is a closed-form FIRST derivative
refereed against its own curve. What failed earlier in this session was a
second-order surrogate with no referee. Same word, different order, and the referee
is what separates them -- so write it first.

## Refuted, with the measurement that refutes each

* **A dense block for every output.** The leaf hands plant 6 outputs; a block is
  6 x 31 = 186 statements against 1,057 recorded, which looks like 5.7x. It loses:
  the rows still have to come from a recording of the leaf, and reading six outputs
  off one tape costs **six sweeps** where composing on plant's costs **three walks**.
  28.2 + 6(1.8) = 39 us against 28.2 + 3(1.8) = 34 us.
* **Three metrics in one walk** (`xad::adj<T,3>`). Measured at 1.15x-0.97x in odelia
  `828cd83`, and the reason is now visible from the source: the statement and
  operation arrays are width-independent, while `derivatives_` is N times the bytes
  and every statement copies and zeroes a whole `Vec<T,N>`. ⚠️ It may also no longer
  compile: odelia's local `adjoint_is_zero` dispatches non-floating-point adjoints to
  `.value()`/`.derivative()`, which `Vec` does not have.
* **The per-placement tape cycle as the reason to avoid a private tape.** 0.14 us.
  It was never the cycle; it was the nesting.

## Two things the XAD source says that the plan should have known

* **`record_with_derivatives` is written in the shape that costs the most.** Its
  loop is `out += d_i * (x_i - passive(x_i))` per row, and `+=` on an active is a
  full recorded assignment -- so **n rows cost n statements and 2n operations**. The
  same information as ONE statement with n operations, either as a single expression
  or as `pushAll(multipliers, slots, n)` followed by `pushLhs`. Nothing in the tree
  supplies more than one row today, so this has never mattered; it decides the cost
  of anything that supplies many.
* **`initDerivatives` zero-fills the whole derivative array, per seed, sized by the
  high-water SLOT mark rather than the live count.** So plant's tape pays a full
  memset three times per recording, and it scales with how many slots a recording
  ever issued. That is the `memset` + `__fill_a1` term that rose by 981 samples in
  the regression, and it is a second reason the leaf's slot count matters beyond the
  statements themselves.

---

# The clean cut: the leaf's state dependence is rank two

## First, the J0 fix, measured

Four interleaved pairs on a quiet machine, forward unchanged at 32.6 s:

| rep | before | after |
|---|---|---|
| 1 | 143.44 | 132.55 |
| 2 | 143.55 | 131.44 |
| 3 | 142.72 | 131.52 |
| 4 | 143.32 | 132.05 |

**143.3 -> 131.9 s, -7.9%**, spread under 0.6% within each arm. An 18.5% cut in the
leaf's tape is 7.9% of the whole gradient, which is the multiplier to carry: the leaf
is about a third of it.

## What the reports establish, and it is not a tape question

Recovered from the superproject at `5d49947^` -- `docs/reports/02` and `05` and `07`.

**The whole state reaches the leaf through ONE scalar at a held operating point, and
TWO at the condition.** Report 02 (3.2a):

> At a **fixed** operating point the whole soil state reaches the leaf through
> **total uptake at the collar** -- one number, whatever the layer count.

Report 05 (7.3):

> The state enters sigma and x **only through E_up**, and dE_up/dp enters directly
> [...] So R = F(E_up, dE_up/dp; p, phi) **identically**, and rank two is a chain
> rule through a two-dimensional intermediate.

Verified out of sample -- recovering the leaf-area scaling, each soil potential and
each layer's root mass independently -- **to 2.4e-09**. This is measured, not
asserted, and it is measured on the model rather than on the code.

## What follows, in three lines

With `m = -1/Pi_pp`, `a = dR/dsigma`, `b = dR/dV = G(sigma)`:

```
dPi*/du   = dPi/du|_p                    = (dPi/dE_up) * dE_up/du     <- ONE multiply
dp*/du    = m * ( a * dE_up/du + b * dS/du )
dE_i/du   = dE_i/du|_p + (dE_i/dp) * dp*/du
```

**Every u-dependence on the right is the SUPPLY model's own Jacobian** --
`dE_up/du`, `dS/du`, `dE_i/du` -- which is Ohm's law over a tabulated integral, and
which report 07 (6) gives in closed form. Everything else is a handful of DOUBLE
coefficients evaluated once per placement.

⚠️ **So nothing in the gas-exchange model needs to be templated on the tape's scalar
at all.** Not profit, not the colimitation, not the cost, not the concentration
solve, not the stem integral. The leaf solves in double -- which is what the implicit
function theorem has been saying the whole time -- and hands over values with rows.

## What that subtracts

| |
|---|
| `collar_at<S>`, `outputs_at<S>`, `profit_at<S>`, `marginal_at<S>`, `collar_coords_at<S>` |
| `marginal_assembled<T>` and its tangent above the adjoint |
| `duptake_dpsi_at<T>`, `layer_mean_at<T>`, `layer_integral_at<T>`, `cumulative_lift<T>`, `cumulative_deriv_lift<T>` |
| `implicit_value` at an active scalar for sigma, ci and both bounds |
| `SecondOrder` and both branches it selects |
| the whole `if constexpr (std::is_same_v<S, double>)` split that runs through the leaf |

Measured, per placement: **861 recorded statements become a graft of at most
6 x 31 = 186 operations** -- and, written as one statement per output rather than the
`+=` loop `record_with_derivatives` uses today, **6 statements**.

## Why the code does not already do this

Report 02 (4) states the rule and the code took half of it:

> **Record everything whose operations you can afford to record. Supply rows only
> where recording is impossible -- an opaque solver -- or unaffordable -- the whole
> trajectory.**

861 statements x 2,333,500 placements is 2 x 10^9 recorded statements a gradient.
That is the "unaffordable" clause, and it was never applied.

## The check that needs no reference, and it has passed before

Report 02 (3.4):

> The identity a correct transpose must satisfy is `&lt;v, J u&gt; = &lt;J^T v, u&gt;` for
> arbitrary `v` and `u`. An implementation of exactly the construction above [...]
> satisfies that identity to **1.4e-14 over 294 operating points**, five orders below
> the solve's own floor.
>
> The identity is **the** check on this node, because it needs no reference gradient
> and no differencing.

**So this is not a new design. It is one that existed, was refereed by an identity
that cannot be fooled, and was replaced by recording.**

## The one thing that must not be assumed

Report 05 (7.0): the envelope theorem holds at kind **S** -- an interior stationary
maximum -- **and nowhere else**. At a pinned optimum profit reacquires the term
(`w = Pi_bar * dPi/dp + s`), and at an exogenous point there is no optimisation at
all.

> **The objective's p-channel must be a number that is supplied, not an identity that
> is assumed** -- zero at S, nu at K, and whatever the substitution gives at X.

That is the design constraint the interface has to carry, and it is the reason the
five kinds exist rather than one.

## What to prove before writing any of it

In this order, because the last two increments cost what they cost by taking it in
the other one.

1. **The rank-two claim on THIS model.** The reports measured it on an earlier tree.
   Recover the leaf-area scaling and one soil potential independently through
   `(E_up, S)` and require 1e-8.
2. **The coefficients against the tangent they replace.** `a`, `b`, `Pi_pp` from the
   closed forms in report 07 (5) and (12.3), against `marginal_assembled` at a
   nested scalar, in `test_leaf`.
3. **The dot-product identity**, which is the check that needs no reference.

⚠️ **And one hazard this session measured directly.** `util::to_passive` strips
EVERY layer, so at a nested scalar it removes the inner direction as well as the
outer. A probe recording `outputs_at` at `AReal<FReal<double>>` -- adjoint above
tangent, which costs 261 statements against 245 at the plain adjoint, so the nesting
itself is nearly free there -- read `d2(profit)/dp d(vcmax)` as **exactly zero**
against a differenced 2.97e-03, because every `implicit_value` correction is built as
`x - to_passive(x)` and the inner tangent goes with the strip. **Any route that keeps
a nested scalar has to reckon with that; the rank-two route does not have one.**
