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

⚠️ **One consequence of fact 2, and the part of it that turned out NOT to be
forced.** A solved value is determined by the state and the time it was found at, so
the natural key for it is the state. It cannot be: the reverse walk visits the rate
evaluations of a recording in a different order from the forward run, and at an
active scalar a derivative can move behind an unchanged value -- the hazard
`psi_soil_` is commented for. So the record is held BY POSITION IN THE SCHEDULE
instead. That substitution is forced.

What was not forced is the conclusion this document drew from it: that the position
must therefore be threaded to the model as a KEY it looks its own slot up by. Four
of the five things listed here as consequences came from that, not from the
substitution -- and all four went when the walk started handing the values over
instead:

* ~~The address has to reach the store from the stepper.~~ It does not. The walk
  hands over the list; there is no address and no lookup.
* The forward and reverse walks agree on the numbering, and that IS forced -- but
  it is now odelia's own row index rather than an agreement between two packages.
  Stage 0 has no slot at all, so "a walk that jumps into the middle cannot trust
  it" is structural.
* ~~A rejected attempt and its retry must write the same slot.~~ A rejected attempt
  writes scratch and only an accepted step's scratch is committed.
* ~~A replay from a state the trajectory never held has to throw the record away.~~
  It is handed no list, so it loads nothing. `clear_solved_choices` and
  `state_moved` are both gone.
* A stepper that hands over no list gets no record, which is still why RODAS keeps
  and places nothing -- now visible in what it passes rather than silent.

**And what is NOT forced is where "is this the pass that fills the record?" lives.**
It is a property of the pass; the walk is the only thing that knows it; and it was
stored on the model in a public mutable bool hand-matched to the solver's own flag.
It is now the CONSTNESS of what the walk hands over, so it is not stored anywhere at
all.

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
// One map, transposed: recorded once on `tape`, swept once per seed. The active
// System and its parameter list are the caller's, built once per sweep.
template <class System, class Map>
void transpose(adjoint_tape<double>& tape, System& active,
               const std::vector<active_scalar<double>*>& parameters,
               std::span<const double> state, const adjoint_rows& out_adjoint,
               Map&& f, adjoint_rows& state_adjoint, adjoint_rows& parameter_adjoint);

// A recorded run, transposed from its last row to its first.
template <class Solver>
void transpose_recording(Solver& solver, std::span<const step_record<...>> rec,
                         adjoint_rows& lambda, adjoint_rows& parameter_adjoint);
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

What plant names from odelia afterwards: `adjoint_rows`, `step_record`,
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

## III. One tape discipline, so the active System has one home

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
* `active_system`'s destructor runs inside that scope, so its three-way branch on
  which tape is running collapses;
* `scratch_tape` goes -- its odd copy semantics existed only because `Step` held
  one and `Step` is copyable;
* `recording_tape()` goes from `Step` and from `SolverInternal`, two forwarders of
  one member;
* `state_and_parameter_adjoints` and `rates_adjoint` stop taking a tape beside the
  active System that already holds one, so a caller cannot pair a System with
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
| a buffer produced by one call and drained by another has no scope | so `leaf_profit_` and `competition_capture` are members |

⚠️ **One of the three this row used to name did not belong to it.**
`resource_depletion` was filled and cleared inside one `compute_rates`, so it was
already scoped to that call and only its capacity outlived it -- a local, and step
7 made it one. The row is true of buffers that span two calls, and the test is
whether the drain is in the same call as the fill.

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
the other direction. The severity the two mechanisms look like they encode is
read by nothing; step 4 has the count.

One latched refusal, returned, and: the exception class goes, the unwinding
through a live tape stops existing, and `refusal`'s three never-written fields go
with the mechanism that was going to fill them.

The buffers are smaller and local. `competition_capture` stops being a member the
moment the two field builds are one function, which they nearly are already.

---

## The boundary, stated once

| package | owns |
|---|---|
| odelia | the recording; the transpose of a map; the transpose of a recording; the implicit-node primitives and the nested scalar; the scalars and the tape |
| phylloptim | a leaf that solves in double and answers at any scalar, with its derivative supplied where it solved |
| plant | what a census metric is; which rows to sweep; the direct term the accumulator starts at; what refuses a row; the seeding callable; the schedule |

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

**3c -- the insertion's map says what it does, and the width belongs to the walk.**
DONE, and **not** as this step predicted. It expected two named operations, a pure
map and a mutation. Counting the consumers says the mutation is the map: five
callers, and **four of them want the wider state reported** -- the driver's
transpose, `state_at_segment`, `introduction_jacobian` and the ladder's standalone
widening transpose. One discards it, `advance_over_insertions`, and it is an oracle.
`subtraction-targets.md` 14 filed this beside the leaf's `E_from_soil_at`, where
three of four callers throw the split away; here the ratio is the other way up, so
the analogy was backwards and the report is the primitive.

What was actually wrong was the name and the guard.

* **`inserted_state` was a noun phrase for a mutation**, which is why an eight-line
  comment existed to decode it and why the comment did not work -- it had been read,
  and quoted, in the session that then shared the active System. It is
  **`apply_insertion(time, x, y)`**: a verb, and the fact it leaves the System
  holding the wider state is now in the name rather than under it.
* **The width check asked the wrong System.** `sweep_range` compared the seed batch
  against the System the descent positions rather than the active copy the
  recordings are taken on -- and those differ by exactly one thing, something having
  widened it. The one case worth catching was the one it could not see. It now
  asks the System it rebound.
* **The rebind for a range is done by the function whose width it is**, which is
  what makes that divergence impossible rather than merely reported: `sweep_range`
  takes the tape and rebinds, where it used to be handed the rebound System. A
  caller cannot hand it a widened one, so the hazard is unstateable rather than
  warned against, and the ⚠️ that warned against it is gone.
* `advance_over_insertions` holds its two buffers across the walk instead of
  allocating both per insertion, which is what 14's discarded vector was.

⚠️ **The sharing is priced and rejected, and so is the pure map.** Sharing one
rebound System across the insertion and the range below is worth 169 Patch deep
copies a sweep, at
about 2 ms each -- 7.0 s over the 3,381 rebinds measured when the rebind was per
recording: **0.35 s of a 108 s gradient, 0.3%.** Every way of buying it costs more
than it is worth.

* *Narrow it with the ordinary load.* `be_at_step` reshapes, and `reshape_to`
  rebuilds the environment and the rates when it moves -- a whole rate evaluation, at
  the adjoint scalar, pushing about a megabyte of statements that the next clear
  throws away. 169 of those is dearer than the copies it saves.
* *The map pops the nodes it pushed*, which would make it pure in shape and is
  already written inline in `introduction_jacobian` between its tangent columns. It
  fails on the oracles: two callers **harvest the mutation** -- `state_at_segment`
  wants both halves and `advance_over_insertions` only the mutation -- and a pure
  map needs a second spelling of "an insertion happened" for them. `advance_over_insertions`
  exists to traverse *the map the adjoint transposes*, so giving it a different
  spelling weakens the reference it is there to be -- and calling both pushes the
  nodes twice.
* *An inverse on the System interface* is a public way to change width whose only
  callers would be the walk, and a second thing to keep the exact inverse of the
  first.

So the rebind per width is not a sharing someone missed: **it is the narrowing,
and it is the cheapest one available.** What made it read as an oversight was a
name that hid the widening, and that is what changed.

⚠️ **And the count is a floor, not a shape.** Three checks, so nobody looks for a
reorganisation that is not there.

* **Each width is visited exactly once.** Widths only grow along a recording and
  the descent runs it once, so each width is one contiguous run of rows. There is
  no reuse to cache and no ordering that visits fewer: 170 range rebinds is the
  floor.
* **The widening always comes first.** An adjoint has to pass THROUGH the insertion
  to become narrow, so the recording that widens the System is always taken
  immediately before the range that must run narrower than it. The two cannot be
  swapped and the widening cannot be deferred.
* **Composition does not reduce it.** Recording insertion-then-step as one map
  moves which rebind sits at which width and still leaves two, because the composed
  recording must START narrow while the rest of its range runs wide -- and it
  destroys the adjoint seam at an insertion row, which `extra_stops`, the identity
  rung and `census_gradient::at_first_state` all read.

**The one recording in the driver that is not forced** is the insertion's, and only
by asserting its Jacobian instead of recording it: if a new node's initial state
reads the traits and the time but not the old state, then the narrow adjoint is a
TRUNCATION of the wide one plus the new rows' parameter term, and 169 recordings and
169 rebinds go. Refused on both counts. It puts a model claim inside the sweep --
"an insertion is an injection whose new rows do not read the old state" -- where the
design's trustworthiness comes from recording `derivs`, the call the forward pass
makes, so a transpose cannot drift from the model; and it is worth about 0.3% of
tape volume, since an insertion recording is a state load plus an `ode_state`
read-back at roughly two statements an entry, 169 x ~2,700 against 3,381 x ~28,000.

**The count of STEP recordings is not a choice either.** Fact 4 puts a checkpoint at
every step. Merging pairs of steps into one recording halves the registrations
(1,361 x 1,690, about 2% of the ~10^8 slot allocations, so roughly 0.7% of the
gradient), leaves the zero-fill total unchanged -- half as many `initDerivatives`,
each twice as large -- doubles peak tape from about 35 MB to 70 MB a recording, and
removes the per-step adjoint the ladder checks. Not worth it.

**4 -- one refusal, latched, returned.** DONE, and **without the severity**,
which is the finding. Counting the readers says there is nothing to carry: **both
consumers not-a-number every row on either escape.** `census_trait_gradient`
ORed the throw and the latch into one `refused` bool and wrote an all-NaN row per
metric; `ladder_rhs_adjoint_tf24` NaNs every state and trait entry. The profit row
the latch went to the trouble of sparing is discarded one frame later, and
`test-gradient-ladder-sweep.R` had already measured why -- *"on this census nothing
would be spared"*, because TF24 has no water-independent metric. So what the two
mechanisms differ in is not what they answer but how much work is wasted after the
answer is decided, and the reason string already says which output refused.

The leaf's own `util::stop` is recorded rather than rethrown: every output takes
the value its double solve fixed and carries no row, which is what a refusal costs
at the other three sites, and the sweep runs on to the poll.

Gone: `gradient_refusal`, both throws, both catches, the `refused` bool, the
`all_seeds`/`all_direct` pair that existed only to survive a `try`, `n_metric`,
one of the two NaN-fill sites, one of the two shared pointers, and the four
hand-written loops over species that read and cleared them.
`gradient_refusal.h` is `census_gradient.h`, named for what it holds; `patch.h`
included it and used nothing from it. **The species is now always known**, because
every refusal is recorded on the species whose strategy holds it -- it was -1 on
the throw path.

⚠️ **Two claims this step made that the code contradicts.**

* **`restore_on_exit` does not lose its reason.** The descent calls
  `be_at_step(system, rec, hi)` per range with `hi` decreasing, so on the NORMAL
  return the System sits at the LOWEST range's width and the destructor is the only
  thing that puts it back. It stays exactly as it is, its `catch (...)` included,
  because `util::stop` still unwinds through the sweep -- from odelia's own length
  checks and from `implicit_value`.
* **`tape_guard` does not exist**; it is `tape_scope`, and its deactivation is
  load-bearing on every normal return rather than only on a throw, because XAD
  refuses a second `activate()` while one is held.

⚠️ **The price, so nobody finds it as a regression.** A refusal used to abandon the
gradient at the first bad leaf and now runs to the end of the sweep. One reached
while forming the census seeds still costs the sweep nothing -- it is polled before
the descent starts -- and once latched the leaf stops recording rows, so a refusal
mid-descent costs less than a whole gradient. If that ever matters, the shape is a
System predicate the walk polls per range, **not** an exception.

**5 -- the per-placement allocation off the heap; fourteen driver caches into
one.** DONE, and **neither half by the mechanism this step named.** The two
things it wanted -- the allocation and the member count -- both landed. The two
mechanisms it proposed to get them are both refused, each on evidence in the
code.

Allocation and copies are 11.8% of the gradient and this was the sharpest known
contributor inside it: `clamp_counts()` folded the leaf's tally and the supply
model's into a fresh vector, twice per `record_leaf_outputs`. None of it is tape
work, so it appears under no XAD symbol. `Leaf::clamp_count(site)` already
summed the two for one site and **had no caller anywhere in the tree**, so
reading site by site puts the tally on the stack -- four `size_t` -- for the
same numbers. The per-iteration bounds guard became a `static_assert` that the
leaf's sites are the last of plant's, which is the hazard a reader would
actually hit.

The seven `*_cache_` doubles and their seven `*_cache_time_` partners are one
record: the values, the one time they were read at, and a flag per driver.
Fourteen members to one, and a driver is now one enumerator plus one getter. It
also closed a hole nothing was watching: `assign_from` carries `time` through
the base assignment and left the caches alone, so an assignment into a live
environment read fresh at the new time while holding the old environment's
values.

⚠️ **The counter merge is refused.** `unification.md` 4 would replace plant's
`if constexpr (is_same_v<S, double>)` -- a compile-time fact about the scalar --
with a runtime flag, to match phylloptim, which cannot use the scalar because
the leaf solves in double on both paths. The two are not one idea spelled twice:
they answer the same question about a scalar known at compile time and a scope
known only at runtime, and merging them drags the better shape down to the
worse. And widening the delta's bracket to the whole gradient, which
`subtraction-targets.md` 5 suggests instead, silently moves `solve_leaf`'s
clamps during a differentiated evaluation from the forward bucket to the
differentiated one.

⚠️ **Refreshing the drivers where the time is set is refused, and the comment
that said so was right.** `Drivers::evaluate` does `drivers.at(name)`, which
raises for a driver that was never set, and raises again for a time outside a
variable driver's control points -- so refreshing seven to serve one raises on
an environment that only ever reads one. **"Seven comparisons become none" is
withdrawn**: it needed the eager form. The win is the member count and the
shape.

⚠️ **Deriving the potentials at the load is refused, and half of that item was
already done.** `psi_soil_cache_state_` and its `to_passive` compare per layer
per read went in plant `c50e3a2b`; what is left is the values and one flag.
Deriving at the load is a LOSS rather than a saving: the derive is lazy and
conditional today, so an empty patch never pays it, where deriving at the load
would pay `soil_number_of_depths` ACTIVE writes on all six loads a step. And the
flag has a second reader -- `set_cohort_reads` marks INJECTED potentials valid,
so a derive at the load would quietly replace them and the ladder's injections
with them.

**6 -- the record carries what a step solved for, and hands it over.** DONE, and
it went three rounds past what this step asked for. Read the rounds in order,
because each one only became visible after the one before it landed.

**Round 3, which is where it ended.** The record is `step_record::solved`: what a
step's five stages solved for, in the order they solved for it. FIVE, not six --
the sixth evaluation a step makes is the FSAL one at the state it ends at, which a
sweep re-derives rather than reads, so there is no slot for it. The walk hands the
System the list for the evaluation about to run, and **whether that is to be
written or read is the CONSTNESS of what it hands over**, so no mode is stored
anywhere. Nothing is threaded: `recorded_stage`, `enum class pass`,
`RecordsChoices`, `begin_stage`/`end_stage`, plant's `kept[step][stage]` and its
resize arithmetic, `clear_solved_choices` with both its call sites, the
`state_moved` parameter that existed only to reach it, and the step-index
parameter of BOTH walks are all gone -- the last of those existed only to build
the address.

Measured against a same-session control on the century fixture: forward 30.87 s
against 30.86 s, gradient 104.26 s against 103.23 s -- inside the noise of one run
each -- and **placements identical at 2,333,500**, which is the number that says
the record engages at exactly the same solves rather than merely passing the
suite.

⚠️ **The aux vector is the wrong home, and this is the reason to write down.**
`Internals::auxs` mixes the two kinds: `competition_effect` and `height_inverse`
are functions of the state and MUST be recomputed at the adjoint scalar, so
loading a recorded aux vector wholesale writes them as passive doubles and severs
the tape through them. Restricting the load to some slots needs a list of which
auxs are supplied, which is a new concept. Only values a rate evaluation cannot
recompute belong in the record.

⚠️ **Running off the end of a loaded list is a FAULT**, not a fall back to solving.
The run made one entry per solve at that evaluation, so a pass asking for more
disagrees with the record it was handed. Loading from an absent list still returns
nothing, which is a forward run that kept no record. The fallback that remains is
for the four operating-point kinds settled by feasibility rather than by a search
-- the state determines those, so there is nothing to store and re-reaching them
is free.

**Rounds 1 and 2, kept because the reasoning is what got to round 3.** The fill
flag stays where it is, and that half is refused.

**First, the guard, because there was none.** `leaf_solved_points::placements()`
carries its own reason to exist -- a record that engages and one that quietly does
not are the same green suite -- and nothing read it. It crossed to R and only two
profiling scripts looked. Nor could anything else see it: `place_solved_point`
increments `collar_solves` deliberately, so the operating-point tallies that ARE
asserted on are invariant to whether a point was placed or searched. The recruit
test already called the export at two lifetimes and discarded the field; it now
asserts the count is past the step count, and it passed before the refactor and
after it.

**Then the scope.** The address was carried into a System as a third argument to
its loader, which made the extent of one rate evaluation a property of a load --
and put the open in `Patch::set_ode_state` and the close in `Patch::ode_rates`,
with nothing relating them, so a throw out of the rates left it open. The extent
of one rate evaluation is `derivs`, so `derivs` opens and closes it through a scope
whose destructor is the close. `internal::set_ode_state`'s four-parameter overload
goes, plant's third load arity goes, and `RecordsChoices` becomes
`RecordsChoices`, asking for the two members that bound the extent rather than for
a loader arity. **The whole migration was one call site and one definition.**

⚠️ **The concept was briefly `AddressesChoices` and that name did not survive
reading.** It named the mechanism -- handing over an address -- rather than what
the System does with it. `Replayable` was considered and fails a sharper test: it
reads TRUE for `LotkaVolterra`, which has `set_recorded_state` and is perfectly
replayable, where this concept must be false for it. Replayable is a coarser
property this is one ingredient of. `RecordsChoices` is what the System does, and
is already the tree's vocabulary.

⚠️ **It does not delete one of the two concepts.** Both remain and each has its own
job: odelia's asks whether a System addresses an evaluation, plant's asks whether a
strategy keeps a choice, and plant's has three uses beyond the load. A load arity
went, not a concept.

**And then the flag, which is where the interesting part was.** It does not belong
on the store: the store is a `shared_ptr` deliberately shared between the run's
patch and the rebound one -- that share is how the sweep reads what the run wrote
-- so a flag on it is one flag for BOTH HOLDERS, and `assign_from` setting it false
reaches through the share to the patch that did the recording. It also does not
belong on the Patch, which is where it was.

**It belongs nowhere, because it is not a property of anything the model holds.**
"Is this the pass that fills the record?" is a property of the PASS, and the walk
that steps is the only thing that knows. So it is not stored at all: it arrives on
the address, from `Step::step`, taken from `keep_states_` -- one flag for the whole
recording, because the states and the choices ARE one recording. `Patch::recording`
is gone with its setter, its line in `SCM::run` and its clear in `assign_from`, and
the pairing that had to be kept true by hand and that nothing validated is
unstateable rather than merely unlikely.

That is `subtraction-targets.md` 20's own complaint answered -- *"the address says
WHERE and a mutable public flag four frames up says WHAT TO DO THERE"* -- by putting
the two in one value rather than by relocating the flag.

**`subtraction-targets.md` 17 folded in with it, and NOT as two types.** With the
pass arriving per call, `filling` stops being state: the store holds two slot
pointers, `keeping` and `placing`, at most one open, and `end_stage()` nulls both,
so nothing outlives the slot it described. Two types would have been worse, and
`solve_leaf` is why: it calls both halves unconditionally, reads as "place what was
kept, or search; then keep what you have", and is correct in either pass with no
branch. Splitting the type forces that one caller to learn the mode in order to
hold the right half.

⚠️ **And a gap this turned up.** `ode_step_rodas.hpp` calls only the unaddressed
`derivs`, at every one of its stages, so a System run under `Method::rodas` opens no
stage at all: it records no choices and places none. Harmless today because RODAS
has no consumer in the product, and worth knowing before it gains one.

**7 -- one reduction, three producers.** DONE, and **as two producers sharing a
loop and a third sharing only the shape** -- the entry's framing was half wrong,
and `unification.md` 3 now says which half.

> **This step's cost model was aimed at the wrong producer.** The paragraph below
> describes the walk, which is quadratic in knots x cohorts. TF24 does not take
> the walk: the smooth profile has three moments, so the field build takes the
> prefix form, which is linear and whose arithmetic this step does not touch. The
> statement count on the hot path is therefore **unchanged by design**, and the
> A/B below is a control on a claim of no change rather than a search for a win.
>
> ~~A taped reduction, so mechanic 1 decides its cost: the trapezium accumulates
> over nodes, and every named active intermediate in that loop is a statement and a
> slot, multiplied by knots x cohorts x stages.~~ True of the walk, which serves the
> accessors and the fallback. Inside a recording the operation count IS the tape,
> and that part stands.

What the model forced, and it is one fact: **`abscissa_of` returns `birth_date ?
introduction_time : -height`, so the node list is ascending in abscissa exactly
while the heights decrease** -- introduction times ascend by construction. The
negation is there for that. So the sorted fallback was never a second reduction
over a different sequence; it was the same reduction over the order restored,
plus a second job it should not have had.

* `reduce_competition(height, order)` is the loop, once. `order` names the
  ascending order where the list is not in it and is empty where it is. The early
  exit stays with the decreasing heights, which is the fact that justifies it.
* `ascending_by_abscissa()` sorts **positions**. The abscissae are doubles, so
  the order costs no contribution evaluation, and a `thread_local` vector of
  active values left a shipped header with the change -- its comment claimed no
  element outlived the call, and every element outlived it until the next call.
* `closes_on(f_h1)` is the closing rule, once instead of three times.
* `competition_split` loses `from_loop`, `unordered`, and `excl`: a default split
  closes to `{0, 0}`, which is what the short paths returned, and `excl` is
  `without_boundary()`. `x1` becomes `double`, which it always was.
* `subtraction-targets.md` 6's double reduction is **unrepresentable**, not fixed.
* `height_max()` reads the cached scan instead of walking the heights beside it,
  and the scan is handed back by reference.
* `resource_depletion` is a local (✱O), which is the step's third increment and
  the one the constraint table said not to cut. See below for why that row was
  right in general and wrong about this member.

⚠️ **One semantic change, deliberately not reverted.** The walk checked
finiteness on every node *after* the first; the sorted producer checked all of
them, and the prefix producer checks all of them via `scale[i]`. The merged
reduction checks all, so a non-finite contribution on the first node now raises
where it used to propagate a NaN. That is a strengthening rather than a drop, and
it makes the three producers agree on what they refuse -- but it is a change, and
nothing in the suite depended on the old behaviour.

**Two claims measured rather than argued** (`odelia/tests/standalone/probe_trapezium.cpp`):

| | statements | operations |
|---|---|---|
| a width from two position-valued actives | 0 | 0 |
| a struct with one active, returned by value, per read | 1 | 1 |
| the same struct by const reference | 0 | 0 |

The first killed my own case for `x1`: an active assigned from a double takes no
slot and records nothing, so the type change is honesty and one fewer value in the
release walk, **not a saving**. The second is why the scan is a reference.

**The control**, because AGENTS.md asks for one on any claim about speed and the
claim here is that there is none. `scripts/profile-stand-gradient.R`, century
fixture, both sides interleaved in one session, two rounds:

| | forward (s) | gradient (s) | placements |
|---|---|---|---|
| this step | 30.79, 30.64 | 102.82, 102.55 | 2,333,500 |
| before it | 30.74, 30.79 | 103.96, 102.52 | 2,333,500 |

**No measurable change, which is the predicted result.** The old side's own
gradient spread is 1.44 s against 0.55 s between the means, and its second run is
the fastest of the four -- so there is no direction to report. Placements are
identical on every run, which is the number saying the reduction engages at the
same solves rather than merely passing the suite.

⚠️ **The reordering had no test, and the ladder cannot give it one.**
`ladder_control()` is birth-date coordinate, where the list ascends by
construction, and the R `heights` setter refuses a crossing outright -- so nothing
in 75 files reached the path. The check is permutation invariance over the same
sample set, written through the state vector because that is the only door left.
Disabling the reordering fails it at seven of eight query heights and understates
competition by **62%**.

**Refused: skipping the structurally-zero crown evaluation.** In `field_splits`
the node below the query height contributes an exact `{0, 0}` -- `Q_and_q` returns
a hard zero above the crown -- so its evaluation could be skipped. It is about
three statements against roughly 290,000 per rate evaluation: 0.04%, for a branch
in the hottest loop. No.

**Refused: caching the ascending order beside the scan.** It would turn 65 sorts
per field build into one, on the fallback path, which is already quadratic. The
cost is widening the one cache in this file whose staleness silently reintroduces
#571. No.

**8 -- delete the leaf's second and third derivative methods**, and the
single-potential supply path with them. After step 1 this is a deletion, not a
redesign.

> **This is also where tape volume is decided, which the plan did not say before.**
> `record_leaf_outputs` is 32.3% of the gradient against `solve_leaf` at 6.4%:
> recording the leaf's outputs costs five times solving it, and one rate
> evaluation's recording is 5.79 MB of which the leaf is most. So this is the
> largest line-count item AND the doorway to the largest tape item -- but they are
> different work. Deleting the unused methods removes no statements from the
> recording; what would is the taped surface `outputs_at` and `profit_at` build,
> read with mechanic 1 in hand. Do the deletion first and measure the recording size
> either side, because the expectation is that it does NOT move -- worth knowing
> rather than assuming.
>
> The leaf carries its own nested tape at 2.3%: `collar_condition` records and
> sweeps a `directional_adjoint_tape<double>` per placement, inside plant's
> recording. They do not collide because XAD keys the active tape per scalar type,
> which is what makes the design legal and is stated nowhere in the code.

**9 -- endgame: `derivs` returns.** Four models, fifteen files, the R layer. Not
before the eight above have made it smaller.

> What this buys on the tape, so the endgame is not oversold: the System would hold
> no recorded value, so nothing would need releasing and the active copy could be
> built once per sweep rather than once per width. That is the 3.0% rebind share
> and the 8 ms release -- **not a large number.** What it buys is the removal of a
> hazard class: a member read before it is written is an unregistered input to the
> recorded function, and mechanic 5 makes that silent. The case for step 9 is
> correctness, and the plan should stop implying it is speed.

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
---

# Where the flow stands

The same product call as `subtraction-targets.md`'s walk, read again after steps
0, 1, 2 and 3b. Marks are the hotspots that remain; the ones that went are listed
after it.

```
R  census_trait_gradient_tf24                                census_gradient.cpp
│
└─ SCM::census_trait_gradient                                    scm.h, 102 lines
   ├─ resolve which_metrics -> rows      30 lines against a constexpr table   ✱A
   ├─ store_trajectory()                 MAY RE-RUN THE MODEL                ✱B
   ├─ (gone: ✱C — both are fields of the returned census_gradient)
   ├─ for species: *uptake_rows_unavailable = false                           ✱D
   │
   ├─ try census_state_and_trait_rows()                                  scm.h
   │  │  tape(false)                     ← TAPE 1 OF 2, and it is plant's     ✱E
   │  │  active_system{patch, tape}      ← rebind 1 of about 340
   │  └─ state_and_parameter_adjoints(active, state, all_rows(3), reduce, …)
   │     ├─ tape_scope{active.tape()} ; active.release()   + the count check
   │     ├─ in = state ++ parameters     the splice its caller undoes         ✱F
   │     └─ vector_jacobian_product
   │        ├─ clearAll ; registerInputs ; newRecording
   │        ├─ record: one census over every cohort
   │        └─ for m in 3: clearDerivatives ; seed ; computeAdjoints ; read   ✱G
   │  catch (gradient_refusal) -> NaN rows, return              ESCAPE 1
   │
   ├─ seeds = all_seeds.select(rows) ; trait_adjoint = all_direct.select(rows)
   │
   ├─ try solve_adjoint_over_insertions                       sweep.hpp, 85 lines
   │  │  stops = insertion_rows(rec) ++ extra_splits                         ✱H
   │  │  tape(false)                     ← TAPE 2 OF 2, odelia's
   │  │  tape_scope{tape}                ← ONE activation for the whole descent
   │  │  restore_on_exit{system}         the width on exit is a promise
   │  ├─ for stop j = last .. 0:
   │  │  ├─ Solver::solve_adjoint(tape, rec, lambda, param, at, upper)
   │  │  │  └─ active_system{system, tape}        ← one per width
   │  │  │     for k = upper .. at+1:
   │  │  │       Step::step_adjoint(active, k, …)
   │  │  │       └─ state_and_parameter_adjoints(active, rec[k-1].ran_from(), …)
   │  │  │          └─ release ; splice ; vjp -> 6 x ode::derivs
   │  │  ├─ be_at_step(system, rec, at)
   │  │  └─ active_system{system, tape}   ← A SECOND AT THAT WIDTH  ✱I
   │  │     state_and_parameter_adjoints(active, rec[at].state, insert, …)
   │  catch (gradient_refusal) -> refused = true                ESCAPE 2
   │
   ├─ if (!refused) for species: poll *uptake_rows_unavailable   ESCAPE 3     ✱D
   ├─ assemble census_gradient {gradient, why}
   └─ be_at_step(live, rec, last)
```

One recorded step, the level below, unchanged from the first walk:

```
6 x ode::derivs(active_system, stage, rate[i], t, {step, i})
├─ solved_scope{obj, rec.solved[i-1]}     const & ⇒ load, & ⇒ store   ✱K done
│  └─ for species: strategy->load_solved(list[i])   ✱L done: no address
└─ internal::set_ode_state(obj, y, t)         the ordinary load
   then Patch::compute_rates
      ├─ Strategy::compute_rates
      │  ├─ solve_leaf() -> place_solved_point(leaf_points->next())
      │  └─ record_leaf_outputs                                    phylloptim
      │     ├─ leaf_clamps() twice -- a fixed array, on the stack          ✱M done
      │     ├─ collar_condition -- a second tape, tangent under adjoint       ✱N
      │     └─ collar_at, outputs_at -> implicit_root, implicit_value x2
      ├─ resource_depletion    a local, produced and drained here             ✱O
      └─ env.compute_rates(resource_depletion)
```

## What the first walk marked and this one does not

* **The Patch deep-copied per recording.** 3,381 rebinds became about 340: one per
  width, plus one per insertion, plus the census. Worth 3 to 4 per cent.
* **Three routes to `state_and_parameter_adjoints`.** Two now, and both hand it a
  `active_system` that carries its own tape, so a System cannot arrive beside
  another System's tape or another tape's parameters.
* **The tape activated and deactivated per recording**, about 7,000 times a
  gradient. Once per descent.
* **`insertion`, `widening`, `piece`, `segment`, `with_insertions`.** The code
  words are `insertion_rows`, `inserted`, `ran_from` and `stops`. *piece* is gone;
  *widening* survives only in comments and *segment* only in plant's diagnostic.
* **The width inference and the shrink refusal.** The record says where the
  insertions were.

## What this walk adds that the first did not have

* **✱G — one recording, swept three times.** `clearDerivatives()` marks the whole
  derivative array for zero-filling and `computeAdjoints()` walks every statement,
  once per metric, 3,378 times over. The tape is templated on its derivative width
  (`Tape<Real, N>`, `DerivativesTraits<T, N>::type = Vec<T, N>`) and
  `probe_width.cpp` already instantiates N of 2, 3 and 4. Three directions would
  be one zero-fill and one statement walk instead of three. The arithmetic per
  operation is the same; what changes is the number of passes over two large
  arrays, which is where a sweep's time goes. ⚠️ N is compile-time, so a
  single-metric call would pay for three directions, and the scalar type changes
  wherever the model is instantiated. Measure before believing it.
* **✱I — two rebinds at one width, and the second one is the narrowing.** The
  insertion transpose rebinds at row `at` and the range below rebinds the same
  System at that width again, because applying the insertion widens what it ran on.
  About 169 extra Patch deep copies a sweep, roughly 0.35 s. **Step 3c priced every
  way of sharing them and rejected all of them**; what changed instead is that the
  map's name says it widens and `sweep_range` rebinds for itself, so the mistake
  is a named refusal rather than unmapped memory.

## What section II closed

The transpose takes its own recording, so ✱F -- the flat `state ++ parameters`
vector its one caller immediately undid -- is gone, along with the copy loop that
wrote the parameters back out of it, the `n_seed x (n_state + n_parameter)`
scatter, and the seam between the two halves. **The state is registered as this
recording's own inputs and the parameters where they sit on the System**, so
nothing splits an adjoint by position and nothing can slice past the state into a
parameter value. Every `evaluate` lambda kept its signature, because the buffer it
is handed is now exactly the state it always assumed.

An overload taking a double System rather than a rebound one makes the tape and
the rebind where a single recording is wanted, so ✱E is gone too: plant's census
names neither, and there is one tape per gradient rather than two. `vector_jacobian_product`
keeps its flat shape for the ladder's block Jacobian and has no production caller
left, which puts it on `subtraction-targets.md` 8's oracle-only list beside
`rates_adjoint`.

What plant still names from odelia in the product path: `adjoint_rows`,
`recorded_step`, `step_record`, `recorded_stage`, `be_at_step`, `active_scalar`,
`state_and_parameter_adjoints`, `solve_adjoint_over_insertions`. **Eight, and no
tape, no rebound System and no scalar's tape_type among them** -- against twenty
at the cold read. The five oracle names beside them (`advance_over_insertions`,
`state_at_segment`, `tangent_scalar`, `seed_direction`, `derivative_along`) are the
tangent and difference references, and `subtraction-targets.md` 8 is where they
are counted.

⚠️ **Two things this section proposed and did not get, and both are decisions
rather than oversights.**

* **The rename to `transpose` / `transpose_recording` is declined.**
  `state_and_parameter_adjoints` says what it produces and needs no comment to
  decode, which is the test the style guide sets. Renaming it would churn two
  packages, five test fixtures and every cross-reference in these documents for no
  reader gain, and `transpose` alone does not say transpose of what.
* ~~**`adjoint_segments` and `adjoint_at_first_state` are still members**~~ DONE.
  They are `census_gradient::segments` and `census_gradient::at_first_state`
  (`subtraction-targets.md` 19), and the `n_metric` multiplier below went with
  them. Six clear/zero statements and two Rcpp accessors went too.

## What collapsing the two sweeps closed

`solve_adjoint_over_insertions` is gone -- not renamed. The driver is two overloads
of `Solver::solve_adjoint`, one over the whole recording and one over a range, with
the old constant-width body a private `sweep_range` the first calls per stretch.

**A member rather than a free function, and that was forced rather than chosen.**
`Solver` exposes `get_system_ref()` and `recording()` but not `step_adjoint`, which
is the internal's. A free driver would have needed a public per-step forwarder --
the opposite of collapsing. `be_at_step` and `insertion_rows` moved to
`ode_interface.hpp`, which is where a recording's readers belong anyway.

**Graceful without a conditional in the driver.** `insertion_rows` compiles for any
System, so for one whose width never moves it returns empty, `stops` is empty, and
the function is one rebind and one descent -- the constant-width body exactly. The
only `if constexpr` is inside a new generic `ode::inserted_state`, and it states a
domain fact rather than a fallback: a System whose width never changes inserts
nothing, so the state passes through.

⚠️ **That satisfied the comment which blocked it rather than deleting it.**
`ode_interface.hpp` claimed both `set_recorded_state` and `inserted_state` are "as
mandatory as ode_size() for a System a sweep is asked to walk". Half true, and the
half matters: a System replayed from a recording must be loadable from a recorded
state, so the first is universal and `LotkaVolterra` gained it in three lines; the
second is asked for only where the width changed. The comment now says which is
which.

What it bought beyond the name:

* **odelia's whole-recording sweep works for any recordable System**, where before
  only `plant::Patch` had the two members it called directly. An entry point one
  consumer's type can use is not an entry point, and that was the real reason plant
  read as the assembler.
* odelia's own Lotka-Volterra test now exercises the driver plant runs, instead of
  the constant-width inner loop it could previously reach. Same assertions, more
  of the product under them.
* `sweep.hpp` went from 247 lines to 100, and what is left has **no production
  consumer at all** -- `subtraction-targets.md` 8, sharpened.
* plant's product path lost the walk's name and the recording with it. **Four
  reverse-mode names remain: `adjoint_rows`, `state_and_parameter_adjoints`,
  `active_scalar`, `recorded_stage`** -- against twenty at the cold read. Read as a
  sentence: here is my map, at this scalar, for these rate evaluations; here are the
  rows in and out.

⚠️ **It did not buy `extra_splits`, and an earlier draft of this document said it
would.** The identity rung compares one product call taking a different internal
route against one that does not; a range parameter gives the ladder that only if the
census seeding and the accumulator are duplicated there. `unification.md` 7 is
corrected to match.

## What step 5 closed

**✱M is gone.** The leaf's clamp sites are read one at a time into a fixed array,
so the two folded vectors a differentiated leaf evaluation allocated are off the
heap. The bracket, the attribution and the numbers are what they were.

**Fourteen driver caches are one record**, which is the member count step 5
promised, arrived at without the eager refresh it proposed. ✱O was step 7's, and
step 7 took it: `resource_depletion` is a local, so the TODO beside its clear is
answered by construction and `Patch::for_each_active` no longer visits it.

## What one refusal closed

**✱D is gone, and ESCAPE 1 and ESCAPE 2 with it.** The channel that appeared three
times in one function -- cleared at the top, caught twice, polled once -- is one
value, cleared once and polled twice, and both polls are the same call.
`census_gradient` is assembled at one place instead of two, and the width a refused
row is filled to is the patch's own rather than an accumulator that may never have
been built.

✱C is now **closed** too: `adjoint_segments` and `adjoint_at_first_state` became
fields of the returned value (`subtraction-targets.md` 19), so the refusal path no
longer zeroes them by hand -- it never writes them. Closed together with the
`n_metric` multiplier, as predicted, because both touched the same write sites.

## What step 7 closed

**✱O is gone**, and it is the only marker on the walk above that this step owns.
`resource_depletion` is a local, so the TODO beside its clear is answered by
construction and `Patch::for_each_active` has one fewer member to reach. The rest
of the step is below the walk: the field build happens inside `derivs`, which the
walk enters at one line.

**`competition_split` no longer carries how it was computed** -- three booleans
down to one, `excl` derived, `x1` a position again -- so
`close_competition_and_slope` has no dispatch left. It tests `closes` and returns.
That is `subtraction-targets.md` 6 and `unification.md` 3, both closed.

**One producer of the split, two ways to order the nodes.** The sorted fallback is
`ascending_by_abscissa()` and nothing else; the reduction is written once. The
prefix producer is untouched, which is why there is no time in it.

⚠️ **What it did not close.** ✱A, ✱B and ✱C all stand, and none of them is in a
reduction. ✱N -- the leaf's second tape under the adjoint -- is step 8's.

⚠️ **What it revealed.** The reordering path had no test in 75 files, and the two
doors that could have given it one are shut: the ladder is birth-date coordinate,
and the R `heights` setter refuses a crossing. A path reachable only from a
trajectory needs a check written through the state vector, and that is now the
third assertion in this branch that had to be built before the thing it guards
could be trusted.

## The ladder has absorbed one of the defects

~~`adjoint_segments = n_metric * solve_adjoint_over_insertions(...)`~~ DONE. It
multiplied a range count by a metric count, which `unification.md` 10 names. Why
nobody noticed: `test-gradient-ladder-first-segment.R` asserted
`expect_equal(ranges, (n_widening + 1) * counts$metrics)` -- the expectation carried
the same multiplier, while the comment above it stated the model correctly ("one
range per width ... one MORE than the number of widenings"). The check agreed with
the code and disagreed with its own prose, so the multiplier had to come out of
both at once, and it did. **An expectation that agrees with the code and disagrees
with its own comment is the finding** -- the prose was right and the assertion was
the copy of the bug.
---

# What the tape costs, and the mechanics behind it

Read this before touching anything on the recording path. Every claim here is
either read out of the vendored source or measured on the century fixture, and the
ones that were guessed and then measured are marked.

## Where the time goes

Century fixture, ode_size 1361, 169 nodes, 3,381 steps, 6.0 rate evaluations a
step, 3 metrics. Forward run 32.5 s, gradient 115.4 s, **ratio 3.6**. Self time as
a share of the gradient:

| | share | what it is |
|---|---|---|
| tape bookkeeping | **30.3%** | `AReal` construct/destruct, `pushAll`, `pushLhs`, `registerVariable`, `unregisterVariable` |
| sweeping | **28.4%** | `computeAdjointsToImpl` and the operations walk |
| model arithmetic | 18.4% | `exp`, `log`, `pow` and the model's own work |
| allocation and copies | 11.8% | `ChunkContainer` growth, `malloc`/`free`, `memcpy` |
| memory fills | 7.9% | mostly a stepper resize (fixed), then `initDerivatives` |
| rebinding | **3.0%** | `rebind_from`, `assign_from`, the interpolant's spans |

**Bookkeeping exceeds the sweep, and all of it is on the recording side.** The
model's own arithmetic is less than either. `std::max` inside
`registerVariableAtEnd`'s high-water-mark update is 3.2% on its own -- ninth in the
whole profile -- which says slot allocation happens on the order of 10^8 times a
gradient.

⚠️ **That 3% does not reconcile with the number of rebinds, so do not spend it.**
The sweep takes about 340 -- one per width, one per insertion, one for the census --
and one measured 2 ms when the rebind was per recording, which is 0.7 s and not
3.45 s. The rest of the bucket is almost certainly the interpolant work every FIELD
BUILD does, which is per rate evaluation and is model work rather than rebinding.
Nobody has separated the two; anyone planning against this row should.

⚠️ **Lifting is 3%.** Three increments went into the rebind, the reset protocol and
the tape discipline. They were worth doing for correctness and for the vocabulary,
and the release walk itself is 8 ms of 115 s. They were never worth doing for
speed, and the plan implied otherwise for a long time.

Recording is 2.0x sweeping (`derivs` 62.9% inclusive against `sweep_each_seed`
31.2%). Inside recording, `record_leaf_outputs` is 32.3% against `solve_leaf` at
6.4%: **recording the leaf's outputs costs five times solving the leaf.** That is
where tape volume is decided, and it is step 8's territory rather than the driver's.

## The mechanics that decide that volume

1. **One assignment is one statement, whatever the expression's size.** XAD is
   expression-templated, so `y = a*b + c*d` is one statement carrying four
   operations. But **a named active intermediate is its own slot and its own
   statement**: `S t = a*b; y = t + c` costs two of each where `y = a*b + c` costs
   one. Accumulating into a named active with `+=` costs a statement per term.
2. **A slot is issued on the FIRST assignment to an active and kept afterwards.**
   `operator=` reads `if (slot_ == INVALID_SLOT) slot_ = registerVariable();`, so
   re-assigning an already-slotted value pushes a statement without allocating.
   This is also why a member surviving a tape clear writes through a recycled
   number: the slot is kept, and the clear reissued it.
3. **Assigning a plain double to a registered active pushes a statement with NO
   operations**, which on the sweep zeroes that adjoint and propagates nothing. So
   `active_member = 0.0` severs a dependency and costs a statement to do it.
4. **`unregisterVariable` decrements the live count unconditionally but rewinds the
   slot counter only for the last-issued slot.** A `std::vector` of actives destroys
   front to back, so it returns every live count and almost no slot. That is why
   the release check against zero is exact, and why `newRecording()` alone grows
   without bound. Measured on eight slots freed front to back: seven leaked and the
   live count still came back to zero -- **`release()`'s check is a count of live
   values, not a map of which slots are free.**

   And a rewind to a mark IS reachable with nothing but the public API, by
   unregistering in reverse issue order: measured at 1.85 ns a slot, 0.37 ms for
   200,000, so roughly 0.2 s over a gradient's 10^8 allocations -- against
   `clearAll()`, which is O(1) and free. ⚠️ **The rebind is a shape problem and not a
   slot problem**, so no rewind removes it: slot hygiene already costs 8 ms, and
   neither `clearAll()` nor a nested recording changes a width.
5. **`registerInput` is a no-op on an already-slotted value** (`if
   (!inp.shouldRecord())`). Release before register, or a stale slot is kept in
   silence. On a value that needs one it issues a slot AND pushes an empty
   statement, so registering a step's 1,361 state entries is 1,361 statements
   before the model runs -- load-bearing, and about a twentieth of a recording.
6. **`derivative()` non-const lazily registers** an unregistered value rather than
   raising, and triggers `initDerivatives`, which zero-fills the derivative array
   to the recording's high-water mark. That happens once per seed.
7. **The sweep walks every statement from the recording's end back to
   `statementStartPos_ - 1`, once per seed.** There is no cheap re-seed. Measured:
   `computeAdjointsToImpl` 28.5%, `initDerivatives` 2.9%, `clearDerivatives` one
   sample -- it only sets a flag.
8. **`Tape<Real, N>` carries N adjoint directions in one walk**, with
   `DerivativesTraits<T,N>::type = Vec<T,N>`, and `probe_width.cpp` already
   instantiates N of 2, 3 and 4. **N is a DEFAULTED TEMPLATE ARGUMENT on the
   interface odelia already uses** -- `template <class T, std::size_t N = 1> struct
   adj` in `XAD/Interface.hpp` -- and `active_scalar<T>` is `xad::adj<T>::active_type`,
   so it is the N of 1 today and three directions is `xad::adj<T, 3>` on one line of
   `ode_interface.hpp`. Not new machinery: a typedef and a rebuild. Three metrics in one walk would collapse three
   statement walks into one while leaving the multiply-adds unchanged, so the
   ceiling is the walk machinery -- of the 28.4% sweep, roughly 16% is walking and
   12% is arithmetic. ⚠️ N is compile-time, so a one-metric call would pay for
   three directions, the derivative array triples, and the scalar type changes
   everywhere the model is instantiated, including under phylloptim's nested
   forward-over-adjoint tape.
9. **Nesting is reserved to checkpoint callbacks** by `prevMax_`; see III.
10. **A statement can be written by hand, into any slots, in any order.**
    `pushAll(multipliers, slots, n)` then `pushLhs(slot)` records "this slot's
    adjoint distributes these multipliers into those slots", visited in the order
    they were pushed, and no `AReal` arithmetic has to happen at all. Above it,
    `insertCallback` + `getAndResetOutputAdjoint` + `incrementAdjoint` stops the
    sweep at a marker with every adjoint above it already accumulated and hands the
    tape over for arbitrary hand-written propagation. Both run in
    `odelia/tests/standalone/probe_slot_control.cpp`.

    ⚠️ **AND A CALLBACK IS CONSUMED BY THE SWEEP THAT PASSES IT.**
    `computeAdjointsTo` calls `resetTo(end - 1)` at each checkpoint, which
    truncates the statements above the marker and erases the checkpoint from the
    list. Measured: four statements before the first sweep and two after the
    second, the first seed right and the second **zero**, the callback run once over
    two sweeps. Our recordings are swept once per census metric, so **checkpoint
    callbacks are unavailable to this gradient until the sweep is one walk for every
    metric.** Mechanic 8 is a precondition for any of this, not an alternative to
    it.

11. **What is observable.** `getNumVariables()`, `getNumOperations()`,
    `getNumStatements()` and `getMemory()` are public. `printStatus()` prints the
    rest -- `maxDerivative_`, `iDerivative_`, the derivative allocation -- but its
    only call site is commented out in `Tape.cpp`, so it is unreachable. One rate
    evaluation's recording measures **5,788,272 bytes** at this width, which is
    4,253 bytes per ODE entry; a whole step's recording is six of those.

## Candidates this exposes, with their prices

⚠️ **Two of these were priced and REJECTED. The prices are here so nobody pays
them twice.**

* **The stepper's named accumulator -- OPEN, and the reason it was closed was
  wrong.** `Step::stage_state` builds `S combination = b[0]*k[0][q];` then
  `combination += b[m]*k[m][q]` per stage. Per state entry per recording that is 21
  statements and 4 slots where single expressions would be 7 and 0 -- **28,581
  statements a recording against about 9,500**, each pushed once and walked three
  times, worth roughly 1.3% of the gradient.

  This was rejected on the grounds that the sum is runtime-length, so a single
  expression would need the Cash-Karp tableau unrolled into five hand-written cases.
  **That is not so.** A fold over `std::make_index_sequence` unrolls the LOOP and
  leaves the tableau a table, with the stage index a template parameter:

  ```cpp
  [&]<std::size_t... M>(std::index_sequence<M...>) -> S {
    return ((b[M] * k[M][q]) + ...);
  }(std::make_index_sequence<I>{})
  ```

  about six lines, and `whole_step`'s stage loop becomes the same fold. `step_end`
  has the shape one line away, where a named `combination` costs a slot and a
  statement that the inlined expression costs neither.

  The order the adjoints accumulate in changes -- `(h*c1)*adj` and `c1*(h*adj)` are
  not the same double -- so gradient numbers can move in their last bits. The
  forward values cannot: C++ associates left to right exactly as `+=` does.

  **And that costs no re-bless, which is the thing worth knowing before starting.**
  The ladder is built so last-bit movement is not a re-bless. Its `expect_identical`
  checks compare two ROUTES in one build -- a sweep against itself repeated, a split
  against a whole, a permuted metric order, one metric alone against the same metric
  in a batch -- and stay exact under any change applied uniformly to every route,
  which an edit inside `stage_state` is. Its numeric thresholds are multiples of
  `ladder_forward_floor()`, the fixture's own measured arithmetic floor, rather than
  literals; and `reference-gradient.tsv` is compared at `pmax(3 * spread, 2e-3)`,
  three times the reference's own Richardson spread with a 2e-3 relative floor.
  phylloptim's bit-exact golden file is a forward quantity and is untouched.

  So the obstacle is the code, and the code is a fold.

* **`whole_step`'s `y0` copy -- rejected.** `const std::vector<scalar> y0(x, x +
  size)` copies the registered inputs at the active scalar, and copying a slotted
  `AReal` with a tape active allocates a new slot and records a copy statement:
  1,361 slots, statements and operations a recording for a vector identical to the
  inputs, about 0.15%. It is rejected because `ode::derivs(obj, y, dydt, time)`
  declares `y` and `dydt` as the SAME `StateType`, so handing it a span of the
  inputs while `dydt` stays a vector means widening the signature of the most-used
  template in the library.

* **`XAD_REDUCED_MEMORY`.** Selects `OperationsContainer` (separate multiplier and
  slot arrays) over `OperationsContainerPaired` (interleaved pairs). The profile
  puts 13.7% in the paired container -- `for_each` 5.7%, `append_n` 4.4%,
  `std::pair`'s constructor 3.6% -- so the split form may sweep faster even though
  the library documents it as a memory win at a slight cost. One A/B decides it.
  ⚠️ ABI-affecting: it must be set in odelia, plant and phylloptim together, the
  way the storage-class flags are.
