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
  destroys the adjoint seam at an insertion row, which `extra_splits`, the identity
  rung and `adjoint_at_first_state` all read.

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

**4 -- one refusal, latched, carrying a severity.**

**5 -- one clamp counter; derive the potentials and the drivers at the load.**
(`unification.md` 4 and 9.) Removes the per-placement vector allocation from the
production gradient and thirteen members from the environment.

> Allocation and copies are 11.8% of the gradient and this is the sharpest known
> contributor inside it: `clamp_counts()` builds a fresh vector twice per
> `record_leaf_outputs`, on a path the fixture runs 2,333,500 times. Note what it is
> NOT -- none of that is tape work, so it will not appear under any XAD symbol.
> `psi_soil_` and the seven driver caches are read per cohort per stage and their
> values are active, so deriving them at the load turns a per-read staleness compare
> into one write. Check that the derived values are written ONCE per load: writing
> an active twice costs a statement each time (mechanic 1).

**6 -- the address as a scope; the fill flag onto the store.**
(`unification.md` 2.) Then the recorder and the player can be two types
(`subtraction-targets.md` 17), which is why this precedes that rather than
accompanying it.

**7 -- one reduction, three producers.** (`unification.md` 3.) The hottest
forward path, so it wants the interleaved control.

> A taped reduction, so mechanic 1 decides its cost: the trapezium accumulates over
> nodes, and every named active intermediate in that loop is a statement and a slot,
> multiplied by knots x cohorts x stages. Inside a recording the operation count IS
> the tape, so the producer emitting fewer statements wins twice -- once on the push
> and again on every seed's walk.

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
   ├─ adjoint_segments = 0 ; adjoint_at_first_state.clear()                   ✱C
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
└─ internal::set_ode_state(obj, y, t, at)     if constexpr RecordsChoices     ✱K
   └─ Patch::set_ode_state(it, t, at)         if constexpr KeepsSolvedChoices
      ├─ for species: strategy->begin_stage(at, recording)
      └─ Patch::set_ode_state(it, t)          the ordinary load, 3rd arity    ✱L
   then Patch::compute_rates
      ├─ Strategy::compute_rates
      │  ├─ solve_leaf() -> place_solved_point(leaf_points->next())
      │  └─ record_leaf_outputs                                    phylloptim
      │     ├─ clamp_counts() twice -- a fresh vector per placement           ✱M
      │     ├─ collar_condition -- a second tape, tangent under adjoint       ✱N
      │     └─ collar_at, outputs_at -> implicit_root, implicit_value x2
      ├─ resource_depletion    a member used as a per-call scratch            ✱O
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
* **`adjoint_segments` and `adjoint_at_first_state` are still members**, not
  fields of the returned value. That is `subtraction-targets.md` 19 and it wants
  doing with the `n_metric` multiplier below, in one change, because the fix and
  the move touch the same four write sites.

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

## The ladder has absorbed one of the defects

`adjoint_segments = n_metric * solve_adjoint_over_insertions(...)` multiplies a
range count by a metric count, which `unification.md` 10 names. What it did not
know is why nobody noticed: `test-gradient-ladder-first-segment.R` asserts
`expect_equal(ranges, (n_widening + 1) * counts$metrics)` -- the expectation
carries the same multiplier, while the comment above it states the model correctly
("one range per width ... one MORE than the number of widenings"). So the check
agrees with the code and disagrees with its own prose, and removing the multiplier
has to remove it from both places at once.
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
