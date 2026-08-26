# One reverse pass

What this machinery would be if it had been written knowing there is one product.
`unification.md` finds the places one idea is spelled twice. This asks the prior
question -- what shape is forced -- and then says where to cut.

Two permissions changed the answer: **the calibration path can go**, and
**phylloptim's gradient can be cut to what plant requires**. They do not add
items to the list. They move the hardest item to the bottom of the effort and the
top of the value, because most of what `unification.md` proposed *redesigning*
turns out to be something to *delete*.

## There is one product

`census_trait_gradient`. Everything else in the reverse-mode surface of all three
packages is a referee, an oracle, or a second product that is now being retired.
Ten of the entries below follow from taking that seriously.

## Five facts, from the model rather than the code

Nothing here is a design decision. These are what TF24 is, and every shape below
is forced by one of them.

1. The state's **width grows at scheduled introductions** -- scheduled, not
   triggered, so an insertion's time carries no derivative.
2. One rate evaluation is **expensive and not a closed form of the state**: it
   contains an inner root-find whose branch a later pass must replay rather than
   re-derive.
3. That root-find's derivative is **supplied**, by the implicit function theorem,
   not recorded.
4. Reverse mode over the trajectory needs the state at **every accepted step**.
   The recording is a checkpoint at every step because there is no cheaper
   checkpointing scheme for a right-hand side this expensive.
5. **Only doubles cross to R.** Active scalars live and die inside one call.

Fact 4 makes the recording the central object. Facts 1 and 2 say what a row of it
has to carry. Fact 3 says the leaf's derivative crosses a package boundary as
data. Fact 5 says where every conversion is.

---

## I. An insertion is a row, and the record already knows how to say so

A run records 3,381 rows and none of them is one of the 169 states an
introduction produced. Everything in `sweep.hpp` is downstream of that:
`insertion_steps` infers where the introductions were by scanning for a width
that grew, `with_insertions` copies all 3,381 rows to patch 169 of them,
`state_at_segment` rebuilds one, the piece arithmetic walks around the gaps at
three sites, `restore_on_exit` exists because the descent narrows across them,
and the shrink refusal exists because an inference can be wrong where a recorded
fact cannot.

**The record already carries the discriminator.** `recorded_step`'s own comment
says a NaN size is "a time with no size known, which is a grid point rather than
a recorded step", and row 0 uses exactly that -- the state the run started from,
which no step reached. A widened state is the same thing: a state at a time that
no step reached.

So the change is one push, at the one place the width changes:

```cpp
// SCM::run_next_impl
sys.introduce_nodes(ret, e.time_introduction());
solver.set_state_from_system();
solver.push_inserted();                  // <- what the introduction just reached
```

The species does not need recording: `inserted_state` already looks the
introduction up from the schedule by time, which is what lets the sweep ask for
it knowing only a recorded time.

⚠️ **It lands as a field on a row, not as a row of its own, and the reason is
what a shared time costs.** An insertion happens at the time the step below it
reached, so a row for it would put two rows at one time -- and that sequence is
read by `times()`, by `schedule()`, and through `refine_schedule` by
`parameters.ode_times`, which crosses to R, is validated as sorted, and is binned
into intervals by the pinned replay. It is also what the recorded stage address
counts: the forward run addresses a rate evaluation by `prev_steps.size()`, so an
extra row shifts every address above it and the replay has to shift with it. The
field form gets the whole collapse below with none of that: row counts, times,
sizes, schedules and stage addresses are all exactly what they were.

So `step_record` gains `inserted`, empty at every row no insertion followed, and
`ran_from()` names the one thing a reader needs from the pair -- the state the
step above ran from.

Then the walk is one loop with one branch, and it is the same branch in both
directions:

```
backward   for k = last .. 1
             isnan(rec[k].step_size) ?  transpose the insertion  :  transpose step k
forward     for k = 1 .. last
             isnan(rec[k].step_size) ?  apply the insertion      :  step by rec[k].step_size
```

Gone: `with_insertions` (a copy of all 3,381 rows to patch 169 of them), the
width inference and the shrink refusal it needed, `n_piece`, `piece_first`,
`piece_last` (each written twice), the scheme paragraph that appears verbatim
twice, and the nested `cuts` loop behind `extra_splits` -- a split is now one
more stop on one loop. *piece* and *with_insertions* have nothing left to name.

What stays, and should: `be_at_step`, because a narrowing descent has to put the
System somewhere; `restore_on_exit`, because the descent still narrows and a
throw is still an exit until the refusal is a return value; and the forward walk,
which the tangent reference runs.

This also settles two of `unification.md`'s and `subtraction-targets.md`'s
entries by removing their subject: target 9's off-by-one at three sites, and
target 8's two oracle-only entry points (the tangent reference runs the forward
arm of the loop above).

⚠️ **The one thing to check before it lands.** `SolverInternal::schedule()` is
read by `refine_schedule` into `parameters.ode_times` / `ode_step_sizes`, which
cross to R and drive the pinned replay in `run_next`. Insertion rows appear there
as a repeated time with a NaN size. The replay's `advance_recorded` needs the
same branch -- which is the unification, not a special case -- but the R-side
consumers of `ode_times` want reading first.

---

## II. Two entry points, one written in terms of the other

`subtraction-targets.md` 1 says odelia offers a kit and SCM is the assembly.
Once the record is complete, the kit has an obvious shape and it is small.

```cpp
// One map, transposed: recorded once on `tape`, swept once per seed. The lifted
// System and its parameter list are the caller's, built once per sweep.
template <class System, class Map>
void transpose(adjoint_tape<double>& tape, System& active,
               const std::vector<active_scalar<double>*>& parameters,
               std::span<const double> state, const row_batch& out_adjoint,
               Map&& f, row_batch& state_adjoint, row_batch& parameter_adjoint);

// A recorded run, transposed from its last row to its first.
template <class Solver>
void transpose_recording(Solver& solver, std::span<const step_record<...>> rec,
                         row_batch& lambda, row_batch& parameter_adjoint);
```

`transpose` is `state_and_parameter_adjoints` with `vector_jacobian_product`
merged into it -- `unification.md`'s target 7 found that the boundary's whole
contribution was a concatenation its one caller immediately undid -- and with the
System and parameter list hoisted out (target 5). `transpose_recording` is the
loop in I.

**The three maps a stand gradient transposes then reach one function by one
route.** They are the census reduction, the step, and the insertion; today they
reach `state_and_parameter_adjoints` by three different routes, which is
`subtraction-targets.md`'s hotspot E.

What plant names from odelia afterwards: `row_batch`, `step_record`,
`recording()`, `set_keep_states()`, `transpose`, `transpose_recording`,
`active_scalar`, `adjoint_tape`, `to_passive`. **Nine names at one level**,
against twenty across four. `rates_adjoint`, `one_row`,
`vector_jacobian_product`, `insertion_steps`, `state_at_segment` and
`advance_over_insertions` become internal or cease.

And `census_trait_gradient` becomes what target 1 says it should be: resolve the
metric names, take the recording, seed from the census rows, call the walk, poll
the refusal, assemble. The pieces, the tape, the loaders and the width
restoration stop being plant's business, and `adjoint_segments` /
`adjoint_at_first_state` become fields of the returned value (target 19) because
there is now a return type they fit in.

---

## III. One tape discipline, so the lifted System has one home

`sweep.hpp`'s own header said there were two disciplines and neither was safe in
the other's place. Remove calibration and there is one -- and then "the walk owns
the active System" is not an optimisation, it is the only place it could live.

### What the library provides, read from its source

The reset is not one thing, and which one is chosen decides whether a System can
be carried at all. All four are the vendored tape's own:

| reset | slot counter | a carried System |
|---|---|---|
| `clearAll()` | discards the sub-recording; back to 0 | writes through recycled numbers, **silently wrong** |
| `newRecording()` | never rewinds | correct, and grows without bound |
| `endNestedRecording()` | restores the enclosing sub-recording's | correct, and bounded |
| `resetTo(pos)` | untouched | wrong, and the manual says so |

The counters live on a `SubRecording` held in a stack, not on the tape
(`XAD/Tape.hpp`), which is why `clearAll()` returns them to zero by discarding the
stack and pushing a fresh frame. `newRecording()` clears the statements and raises
the high-water mark without touching the counter, so every slot it has issued stays
issued; the cost is that `initDerivatives()` then zero-fills from zero on every
recording, and a recording of this model leaks slots faster than that can be paid
for. A nested recording is the same protection with the memory given back: it
starts from a copy of the frame, and folding it restores the enclosing frame's
counter along with the statement, operation and derivative arrays, so
`initDerivatives()` fills only from the nest's own start.

⚠️ **Our defect is in the manual, under a function we do not call.** `resetTo`'s
entry reads: *"If variables registered after the given position are used again
after a call to `resetTo`, the behaviour is undefined, as their slot in the tape is
no longer valid."* That is the whole of it. `clearAll()` discards strictly more and
carries no such warning, which is why the hazard had to be found by measurement.

⚠️ **Nested recordings are reserved to checkpoint callbacks, and by the code rather
than by the documentation.** `newNestedRecording()` opens with
`derivatives_.resize(currentRec_->prevMax_)`, and `prevMax_` is `slot_type(-1)`
except between the two lines of `computeAdjointsTo` that bracket a callback. On any
other frame that asks a `std::vector` for four billion elements. So the mark-rewind
is reachable only from inside `insertCallback`'s callback, or by patching the
vendored library to fall back to `maxDerivative_`.

### Where the reset belongs

Not in a step the model executes. The invariant is **every active value the System
holds is unregistered on entry to a recording**, and it belongs at the one place a
recording begins -- which is where the tape is cleared. Stated there, it is two
adjacent lines rather than a rule about ordering; stated anywhere else, the ordering
is a rule, and reversed it is silently wrong wherever the library is built to reuse
freed slots.

What the model contributes is one sentence about itself: **here are my active
values.** That is what `for_each_active` is. It is not a tape concept and should not
read as one -- `ad_parameters()` is the same sentence about a subset, and the two
are the model's only two answers to "what do you hold".

⚠️ **The enumeration is not new, and that is the answer to the objection against
it.** A class already names its members in `assign_from`, and forgetting one there
is the same defect in a worse form: the rebound copy silently holds a default, and
nothing counts. `for_each_active` is checked.

What is worth fixing is that the model currently writes a *procedure* where it
should write a *list*. Ten bodies decide separately how to walk a scalar, a vector,
a pair, a nested vector of structs and a sub-object -- so `patch.h` carries a
two-deep loop over `competition_capture` and `species.h` writes `f(...)` seven
times. One helper in odelia takes the decision:

```cpp
// Every active value among the members handed in, whatever shape they arrive in:
// a scalar, a container of them, a pair, or an object that answers for_each_active.
// A member the visitor cannot be called with is skipped, so a class lists what it
// holds and does not have to say which of them carry a derivative.
template <class F, class T> void visit_active(F& f, T& x);
```

Then every class writes one line and no traversal:

```cpp
void for_each_active(F&& f) { visit_active(f, states, rates, auxs, consumption_rates); }
void for_each_active(F&& f) { visit_active(f, vars, water_flux, psi_soil_, light_availability); }
void for_each_active(F&& f) { visit_active(f, parameters, environment, species,
                                           resource_depletion, competition_capture); }
```

**Skipping what the visitor cannot be called with is the point, not a convenience.**
It means a class may list a `double` member at no cost, so the author is never
deciding which of their members carry a derivative -- which is the judgment that
makes forgetting one likely. Adding a member becomes one word beside the others.

### One tape, held once

Two tapes were doing this job: `Step` held one as a member for the step transposes
and `solve_adjoint_over_insertions` built another for the insertion transposes. Only
one tape per scalar type can be active, so they alternated -- which is why the tape
was activated and deactivated once per recording, about seven thousand times a
gradient, and why the release had to run in a scope of its own that deactivated
before the product activated again.

The walk owns the tape and holds it active for the whole descent. Then:

* activation is once per walk, not once per recording;
* the release is one line where the recording begins, with no scope;
* `lifted_system`'s destructor runs inside that scope, so its three-way branch on
  which tape is running collapses;
* `scratch_tape` goes -- its odd copy semantics existed only because `Step` held
  one and `Step` is copyable;
* `recording_tape()` goes from `Step` and from `SolverInternal`, two forwarders of
  one member;
* `state_and_parameter_adjoints` and `rates_adjoint` stop taking a tape beside the
  lifted System that already holds one, so a caller cannot pair a System with
  another tape.

`tape_scope` replaces `tape_guard`: it activates only if nothing else holds the
tape and deactivates only where it activated, so a walk holding one across many
recordings can contain anything that needs it active. One name for one name, and
four hand-rolled activation dances go.

### The mark-rewind, measured and rejected

Both remaining resets were built as toys on the vendored library, away from plant,
at 3,400 recordings of 10,000 temporaries each. The nested arm needs no patch: put
the whole descent inside one `CheckpointCallback` and `prevMax_` is valid for its
duration, which is what makes `ScopedNestedRecording` legal.

| reset | correct | wall, 3,400 recordings | slot counter | tape memory |
|---|---|---|---|---|
| nested, inside one checkpoint callback | yes | 0.43 s | 15 → 15 | 180 B → 180 B |
| `newRecording()` between recordings | yes | 36.9 s | 10,008 → 34.0 M | 272 MB |
| `resetTo()` between recordings | yes | 37.1 s | 10,011 → 34.0 M | 272 MB |
| nested, outside a checkpoint callback | **no** | 19.3 s for three | -- | 34 GB |

The last row is worth stating plainly because it is worse than a crash: it does not
throw on a large machine, it resizes `derivatives_` to 4.29e9 doubles, takes 32 GiB,
and returns wrong answers from the second recording on. Under a 4 GB address-space
limit it presents as `std::bad_alloc` from the `ScopedNestedRecording` constructor.

**And the release it would replace costs 8 ms.** 1,500 members released over 3,400
recordings is 5.1 million releases at 1.6 ns each -- against a gradient of about
108 s. So the 5 s that carrying the System saves is the allocation it avoids, not
the release, and the release is free.

⚠️ **Nesting does not remove what the model has to promise, which was the whole
reason to want it.** Slots issued *inside* the first nest are handed back out by the
second, so every long-lived active member must be registered before the first nest
-- measured both ways, and the unregistered arm is wrong by no clean factor. On top
of that the nested form needs the descent wrapped in a callback whose reason a
reader cannot see, an explicit zeroing of the pre-nest slots' adjoints before every
sweep (`clearDerivatives()` reaches only from the nest's own start, and without it
recording k returns k times the answer), and no `registerInput` inside a nest --
which is what `vector_jacobian_product` does on every recording. Same promise from
plant, three new disciplines, no time saved.

**So: release, then clear, per recording, at the one place a recording begins.** The
mechanism was right and the placement was wrong. What is left to improve is not the
reset but what the model has to write to answer it.

## IV. The leaf has one supply path, and therefore one derivative method

plant names `SupplyKind` nowhere, `single_potential` nowhere, `uptake_at`
nowhere. So once calibration goes:

* `single_potential.hpp` (236) goes, and with it `supply_kind_`,
  `par_resistance`, and **the whole `if constexpr (double) ... else stop()`
  branch inside `E_from_soil_at`**, which becomes one line. `unification.md`
  entry 1 flagged one real gap against unifying the two derivative methods --
  that the single-potential path has no active arm. **The gap does not exist once
  calibration goes.** Nothing needs a difference.
* `gradient.hpp` (1,255) reduces to nothing plant reads. `inputs.hpp` (339)
  reduces to what still names the boundary. `closed_form.hpp` (223) was an open
  speed study *for the FD path* -- with no FD path it is answered by deletion,
  and `subtraction-targets.md` 12's "not wired in means not yet" becomes "not
  ever". `R/gradient.R` (991), `R/gradient-batch.R` (373), `src/gradient.cpp`
  (238), and the `volatile`-based `rounded()` whose only job was to make C++
  match R bit for bit.
* The namespace `phylloptim::gradient` stops existing. `Drivers` is a bundle of
  driving values and belongs in `phylloptim`, not in a gradient namespace.
* `ad_parameter::leaf_par` -- the `int` carrying the leaf's own index for
  fourteen of plant's parameters, "so a trait cannot be registered for the
  gradient here and forgotten where the leaf's rows are asked for" -- **has no
  reader anywhere.** The rows it guarded are gone. So
  `PLANT_TF24_LEAF_PARAMETER` collapses into `PLANT_TF24_AD_PARAMETER`, and
  plant's only compile-time dependency on phylloptim's parameter indices goes
  with the macro.

**`unification.md`'s hardest item became its easiest.** There is no
reimplementation: the taped path is already the product, already refereed against
a difference of the forward model, and the other two spellings have no consumer
once calibration goes.

---

## The knot, and where not to cut it

One decision generates four of the mechanisms on both lists: **`derivs` writes
into the System instead of returning.**

| it generates | which is |
|---|---|
| the System holds recorded active values | so it is rebound per recording (III) |
| a refusal has no return path | so it is thrown, through a live tape and odelia's whole stack |
| a latched flag needs to outlive the copy that set it | so it is two `shared_ptr`s |
| a produced-then-drained buffer has no scope | so `resource_depletion`, `leaf_profit_`, `competition_capture` are members |

**Do not cut there, and the reason is a count.** `Internals`'s rates, auxs and
consumption rates are read across about fifteen files, four models and the R
export layer. And odelia's interface is *already* return-shaped at the top --
`ode_rates(it)` writes into the solver's buffer -- so the storing is an internal
staging area between production and drain, not something the interface asks for.
That makes it the endgame: real, correctly diagnosed, and not an increment. III
takes most of its value without it.

**Cut at the refusal instead.** `record_leaf_outputs` discovers a refusal below a
void interface, so a latch is the right mechanism for it and the exception is the
redundant half -- `subtraction-targets.md` 4's conclusion, arrived at here from
the other direction. What the two mechanisms actually encode is a **severity**:
one costs every output, the other costs the water rows and lets profit survive by
the envelope theorem. That is a field, not a second mechanism.

One latched refusal carrying a severity, and: `gradient_refusal.h` goes,
`restore_on_exit` loses its reason, `tape_guard`'s exception path stops being
load-bearing, the unwinding through a live tape stops existing, and `refusal`'s
three never-written fields go with the mechanism that was going to fill them.

The buffers are smaller and local. `competition_capture` stops being a member the
moment the two field builds are one function, which they nearly are already.

---

## The boundary, stated once

| package | owns |
|---|---|
| odelia | the recording; the transpose of a map; the transpose of a recording; the implicit-node primitives and the nested scalar; the scalars and the tape |
| phylloptim | a leaf that solves in double and answers at any scalar, with its derivative supplied where it solved |
| plant | what a census metric is; which rows to sweep; the direct term the accumulator starts at; refusal severity; the seeding callable; the schedule |

The implicit-node surface and the nested scalar stay **public**, for the reason
`subtraction-targets.md` gives: phylloptim uses them inside someone else's
recording and has no solver, no recording and no sweep. Folding them behind
"transpose a recorded run" strands the leaf.

---

## The cut, sequenced

Subtraction first. Each step lands on its own and makes the next one smaller.

**0 -- behaviour-preserving, and provable in an afternoon.**
Delete `leaf_par` and collapse the two macros into one. Delete
`leaf_row_settings()` (already unreachable). Turn `census_metric`'s
`std::function` into a function pointer and `census_metrics()` into the
`static constexpr` table its neighbour `ad_parameter_fields` already is. Read
`survival_individual()` where `Node::compute_rates` recomputes it. Hoist the
birth-date stamp out of both field builds into the one call that makes them.

⚠️ **Two items this list first put here do not belong here**, and both for the
same reason: free depended on an assumption the tree contradicts.

* `single_potential.hpp` is configured by `src/gradient.cpp` -- the finite
  difference product -- through `supply_kind_name() == "single"`, and exercised
  by `test_leaf.cpp`. It is not unreferenced; it is the supply model the
  calibration path fits. So it goes in step 8, with the product it belongs to,
  and it takes fourteen two-way `switch (supply_kind_)` statements in
  `leaf_model.hpp` with it.
* `extra_splits` is what `census_trait_gradient_split_tf24` passes, and the
  identity rung's bit-for-bit split is one of the three assertions that have
  caught a real defect. `Solver::solve_adjoint`'s explicit range does not cover
  it: the rung needs the *whole* gradient split, census seeding and accumulator
  included, so removing the parameter today would mean duplicating the driver in
  the ladder. It goes in step 2, where a split becomes a range on one loop and
  the rung can be two calls.

**1 -- remove the calibration path.** The largest deletion in the plan and the
one with no design work in it. It is also what makes step 3 a single discipline
rather than a choice between two.

**2 -- complete the record, then collapse the sweep.** Two commits, in that
order: the push in `run_next` first, because the sweep must give bit-identical
numbers across it and that is provable on its own; then `sweep.hpp` collapses
into the walk.

**3 -- odelia's two entry points.** Merge the splice.

**3b -- the reset in place of the rebuild.** Its own increment, and a plant one:
enumerate the Patch's active members and de-register them where the rebind is
today. `probe_tape_reset` is the mechanism; the ladder is the check; the fixture
that caught the naive attempt catches this one too.

**4 -- one refusal, latched, carrying a severity.**

**5 -- one clamp counter; derive the potentials and the drivers at the load.**
(`unification.md` 4 and 9.) Removes the per-placement vector allocation from the
production gradient and thirteen members from the environment.

**6 -- the address as a scope; the fill flag onto the store.**
(`unification.md` 2.) Then the recorder and the player can be two types
(`subtraction-targets.md` 17), which is why this precedes that rather than
accompanying it.

**7 -- one reduction, three producers.** (`unification.md` 3.) The hottest
forward path, so it wants the interleaved control.

**8 -- delete the leaf's second and third derivative methods**, and the
single-potential supply path with them. After step 1 this is a deletion, not a
redesign.

**9 -- endgame: `derivs` returns.** Four models, fifteen files, the R layer. Not
before the eight above have made it smaller.

## What this does not decide

* Whether RODAS stays. It has no consumer in the product and it is not this
  branch's code.
* Whether the ladder's rungs earn their keep -- `subtraction-targets.md` 10's
  study. Nothing above deletes an assertion. Steps 2 and 3 change what some
  rungs reach for, and the four oracles on `SCM`'s public interface can move to
  free function templates the ladder includes without losing a check.
* `Solver::history` -- a whole System per accepted step, beside the record that
  replaced it. Two answers to "what did the run do", both live, one of them read
  by R.
* Whether `parameters.ode_times` can carry insertion rows, which is step 2's one
  real risk.
