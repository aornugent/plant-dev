# One idea, one spelling

A code review of the reverse-mode branch across the three packages, read as a
single pull request by someone meeting it cold. It looks only at shipped code --
headers and the R layer -- and only for **fragmentation**: a thing this branch
built more than once, in more than one vocabulary, or in more than one place.

`subtraction-targets.md` asks whether a thing earns its keep. This asks a
narrower question with a sharper answer: **is this thing here twice?** Where a
target below extends one of that document's, it says so and does not restate it.
Comments and tests are out of scope by instruction; the one exception is a test
that decides whether shipped code can go, and it is named where it does.

## The rules these were found by

Four, and each one is a question about a pair.

1. **Two spellings of one fact.** Not two copies of one function -- two
   *vocabularies* for one idea, so that a reader has to discover they are the
   same. The tell is a translation layer between them.
2. **Two mechanisms answering one question.** A question a domain asks once
   ("when did this happen", "could this row be recorded", "which branch am I on")
   answered by two unrelated pieces of machinery, chosen by position in the code
   rather than by anything about the question.
3. **Built per step where it changes per sweep.** Anything constructed inside a
   loop whose inputs are constant across the loop. This is where unification and
   speed are the same edit.
4. **A parameter that exists for one caller.** A signature widened to serve a
   consumer that is not the product, so every reader of the signature learns a
   concept the product does not use.

Ordered by what a reader pays, not by diff size. Entries 1 to 4 each remove a
whole vocabulary; 5 to 8 remove a mechanism; 9 onward are local.

---

## 1. The leaf's derivatives are computed twice, by two unrelated methods

**The largest thing in this tree, and it is not on the subtraction list.**
`subtraction-targets.md` records the R/C++ pair as out of scope. There is a
third, and it is the one this branch built.

| | where | how | product for |
|---|---|---|---|
| `.gradient_ift` / `.gradient_fd` | `R/gradient.R` | finite differences + IFT | the reference |
| `gradient::at` / `gradient::batch` | `phylloptim/gradient.hpp`, ~1,050 new lines | a transcription of the above | phylloptim's `leaf_gradient_batch()` |
| `collar_at` / `outputs_at` / `profit_at` / `bound_at` | `phylloptim/leaf_model.hpp`, 263 lines | implicit nodes on the caller's tape | plant's stand gradient |

The third computes the same derivatives exactly, in one recording, and the second
computes them by differencing the model 2 x (17 + 2L) times with a
decade-shrinking retry loop around each difference.

**What the second one costs a reader.** `held_row`, `solved_row`,
`collar_response`, `differenced_curvature`, `Scratch`, `set_one`, the `only`
parameter threaded through both `apply` overloads, `perturb_root_carbon`,
`takes_shortcut`, `step_for`, `collar_step`, `rounded`, `FollowBound`, `Branch`,
`branch_here`, `BasePoint`, `base_point`, `Method`, and the `par_ref` block
decode that exists because a difference addresses an input *by index* where a
tape addresses it *by pointer*. That is nineteen names for a job the tape does
with none of them.

`rounded()` is the shape of the whole problem: a `volatile` round-trip whose only
purpose is to defeat fused multiply-add so that C++ matches R bit for bit. It is
a mechanism that exists because the same quantity is computed twice.

**The taped path already computes every output the FD path reports.** `profit_at`
derives `sigma` (which is `psi_stem`), `ci`, `J`, `A` and `cost` on its way to
profit, and `gc` is proportional to the flux it already has. The five fixed
outputs of `output_table` -- `A`, `gc`, `psi_stem`, `collar`, `profit` -- are all
live values inside one call that currently returns two of them. Returning them
turns `gradient::at` into: place the point, record once, sweep once per output.

**The referee question is already settled, and settled in this direction.**
`tests/cpp/test_leaf_gradient.cpp` referees the taped path against a difference
of the forward model at a held collar, and says in its own header why:

> those compared two derivations of one model, and agreed whenever both were
> wrong the same way

Twenty-nine tests that checked one derivation against another were deleted for
that reason. So nothing referees the taped path against `gradient.hpp`, and the
project has already rejected the idea that anything should. **The assurance
unified; the shipped code did not.**

**What this subsumes.** `subtraction-targets.md` 15 (159 lines of hand-rolled
root-curve derivatives) and the 256 lines of closed-form derivative functions
beside it exist to *supply rows to a difference*. So do `CurveReads` and half of
`roots.hpp`'s `d...` family. They are not separately dead -- they are the second
method's parts, and they go when it does.

⚠️ **One real gap.** `E_from_soil_at` refuses the single-potential supply path at
an active scalar, and `par_resistance` is that path's parameter -- `inputs.hpp`
says the read declines it and a difference answers instead. So either the active
arm gains the single-potential form, or one difference survives for one
parameter. Everything else is on the tape today.

⚠️ **Scope.** `par_table`, `output_table` and `Result` are R's contract and stay
exactly as they are; this changes how the numbers are produced, not what is
reported. `closed_form.hpp` is a separate open item (`subtraction-targets.md` 12)
and is untouched.

---

## 2. ~~Six ways to load a state, two concepts to route one address~~ DONE

Extends `subtraction-targets.md` 20, which names the threading. The unification
is one level up: **the address is a scope, and it is being passed as an
argument.**

```
set_ode_state(it)                       odelia, no clock
set_ode_state(it, time)                  the ordinary load
set_ode_state(it, time, at)              the same load, announcing a stage
set_state_and_boundary(it, time)         the same load, plus the second condition
set_recorded_state(y, time)              reshape, then the above
cohort_reads / set_cohort_reads          the ladder's injection (entry 8)
block_inputs / set_block_inputs          the ladder's pack (entry 8)
```

Two concepts existed to carry `at` down: `RecordsChoices` in odelia's
`internal::set_ode_state`, and `KeepsSolvedChoices` in `Patch::set_ode_state`.
The three-arity load's whole body is `if constexpr (KeepsSolvedChoices) { for
species: strategy->begin_stage(at, recording); }` followed by a call to the
two-arity load. `TF24_Strategy::begin_stage` is a pure forwarder to
`leaf_points`. So a reader follows the address through six frames, two concepts
and three definitions of one verb to reach `kept[step][stage]`.

**The address is not a property of the load. It is the extent of one rate
evaluation** -- which is exactly what `ode::derivs` is. Opening it there:

```cpp
template <typename T, typename StateType>
void derivs(T& obj, const StateType& y, StateType& dydt, double time,
            recorded_stage at) {
  if constexpr (RecordsChoices<T>) { obj.begin_stage(at); }
  internal::set_ode_state(obj, y, time);
  obj.ode_rates(dydt.begin());
  if constexpr (RecordsChoices<T>) { obj.end_stage(); }
}
```

DONE, and further than this entry asked: **there is no address left to route.** The
scope is an object's lifetime, so the "opened here, closed there" invariant that
spanned two Patch members closes however the evaluation leaves; the three-arity
`set_ode_state` went, one definition and one call site; and then the address itself
went, because a walk that hands the System the LIST OF VALUES for the evaluation
about to run has nothing to look a slot up by. `recorded_stage` no longer exists,
and neither does the step-index parameter of either walk.

⚠️ **The intermediate claim that one of the two concepts goes was wrong twice
over.** For one round both remained with separate jobs. In the end odelia's is
`SolvesForValues` (store, load, end) and plant's `KeepsSolvedChoices` asks the same
of a strategy, so there are still two — but neither routes for the other, which is
what the address had really been costing.

**The flag does not belong on the store — and it does not belong on the Patch
either.** `begin_stage(at, keeping)` collected `Patch::recording`: written twice (a
setter called once from `SCM::run`, forced false in `assign_from`), read at exactly
one site, and correct only if the caller set it to agree with the solver's
`set_keep_states`. All true, and the diagnosis of "it varies per RUN" is right. The
store is the wrong home for it: the store is a `shared_ptr` deliberately shared
between the run's patch and the rebound one, because that share is how the sweep
reads what the run wrote — so a flag on it is one flag for BOTH HOLDERS, and
`assign_from` setting it false reaches through the share to the patch that did the
recording.

⚠️ **It belongs nowhere, and that is the finding.** "Is this the pass that fills the
record?" is a property of the PASS, not of any object either package holds, and the
walk that steps is the only thing that knows it. So nothing stores it: it arrives on
the address, from `Step::step`, taken from `keep_states_` — one flag for the whole
recording, because the states and the choices are one recording. `Patch::recording`
is gone with its setter, its `SCM::run` line and its `assign_from` clear, and the
pairing nothing validated is unstateable rather than merely unlikely. The proposal
was:

```cpp
patch.set_recording(x)  ->  for species: leaf_points->fill(x)   // once per run
begin_stage(at)                                                 // per evaluation
```

All three of the things that was to remove are gone, by a different route: the
public mutable bool does not exist, both `begin_stage` signatures lost the
argument, and there is one flag rather than a pair to validate.

**And it did unblock the recorder/player split, which folded in with it** —
`subtraction-targets.md` 17. With the pass arriving per call, `filling` stops being
state at all.

---

## 3. ~~The trapezium reduction is written three times~~ DONE, and the framing was half wrong

Extends `subtraction-targets.md` 6, which names the wasted double reduction. The
duplication is wider than the waste.

| | `species.h` | when |
|---|---|---|
| `compute_competition_and_slope_split` | 591 | one height, ordered walk |
| `field_splits` | 483 | a whole height set, prefix sums |
| `compute_competition_and_slope_unordered` | 688 | one height, sorted view |

**What was right.** All three decided whether the boundary interval closes, and
that rule was written out three times — `n == 1 || birth_date || f_h1 > 0`,
`size() == 1 || birth_date || f_h1 > 0`, and `size() == 1 || f_h1 > 0`, where the
third has dropped the `birth_date` arm. Three spellings, one of them different,
and no compiler can tell you. `close_competition_and_slope` then dispatched on
three booleans `competition_split` carried to work out which of the three had
produced the value it was handed.

The third spelling turns out **not** to be a difference: the sorted producer runs
only under `!birth_date && !scan.decreasing`, so that arm is false wherever it
runs. Worth knowing, because it is the difference this entry was most worried
about, and it was never a defect — only an invitation to one.

**What was wrong: "one reduction over that sequence, three producers of it".**
The prefix form does not produce a sequence a shared reduction consumes. It
produces the sum, by re-association over three running moment sums, which is the
whole reason it is linear in nodes plus heights where the walk is their product.
Forcing it through a common sample loop would delete exactly the thing this
entry's own warning says must survive. **Two producers share the loop; the third
shares only the result shape and the closing rule, and that is all it can
share.**

**What landed, which is neither of the two shapes this entry proposed.** It
proposed "two shapes, or a variant". The better answer was to notice that the
sorted producer *does* have a split, and the reason it appeared not to was that
it was doing more than reduce:

`abscissa_of` returns `birth_date ? introduction_time : -height`, and the
negation is there so that **the node list is ascending in abscissa exactly while
the heights decrease** — introduction times ascend by construction. So the sorted
fallback is not another reduction over a different sequence. It is the same
reduction over the order restored, and restoring the order is all it has to do:

* `reduce_competition(height, order)` is the one loop. `order` names the ascending
  order where the list is not in it and is empty where it is.
* `ascending_by_abscissa()` sorts **positions**, not nodes. The abscissae are
  doubles, so no contribution is evaluated to build the order, and the widths the
  reduction forms from it stay positions. This also took a `thread_local` vector
  of active values out of a shipped header — its comment claimed no element
  outlived the call, and every element outlived it until the next call cleared it.
* `closes_on(f_h1)` is the rule, once.
* `from_loop` and `unordered` are gone: a default split closes to `{0, 0}`, which
  is what the short paths returned.
* `excl` is gone, derived as `without_boundary()`. `subtraction-targets.md` 6's
  O(n log n) double pass is now unrepresentable rather than merely absent.

⚠️ **The prefix form is not an optimisation to fold away.** It is linear in nodes
plus heights where the walk is their product, and inside a recording the
operation count *is* the tape. It survives untouched, and its arithmetic is
unchanged by any of the above — which is why this entry buys **no measurable
time** on the hot path. Its value is the vocabulary.

⚠️ **The reordering had no test.** The ladder's crossed fixture is birth-date
coordinate, where the list ascends by construction, and the R `heights` setter
refuses a crossing outright — so nothing reached the path at all. The check added
with the change is permutation invariance, written through the state vector
because that is the only door left. With the reordering disabled it fails at seven
of eight query heights and understates competition by 62%.

**Refused: caching the order beside the scan.** `HeightScan` already answers "is
the list usable", so it could answer "and here is a usable order" and turn 65
sorts per field build into one. That gain is on the fallback path, which is
already quadratic; the cost is widening the one cache in this file whose
staleness silently reintroduces #571, and whose freshness audit would then have to
cover a vector as well as a scalar. Not worth it.

---

## 4. ~~Two mechanisms for "which pass was this"~~ REFUSED; the allocation is gone

Extends `subtraction-targets.md` 5. The finding there is the threading and the
granularity. The unification is that **plant and phylloptim each define a
`clamp_counter`, they are different shapes, and a translation layer joins them.**

```cpp
// phylloptim/clamp_sites.hpp
struct clamp_counter { shared_ptr<vector<size_t>> counts; };

// plant/clamp_sites.h
struct clamp_counter { vector<size_t> forward;
                       shared_ptr<vector<size_t>> differentiated; };
```

Both answer "how often did this site bind, and on which pass". plant answers the
second half **by the scalar** -- `if constexpr (std::is_same_v<S, double>)`,
written identically in `TF24_Strategy::note_clamp` and
`TF24_Environment::note_clamp`. phylloptim cannot, because the leaf solves in
double on both paths, so plant answers it for the leaf's sites **by differencing
across time**:

```cpp
const std::vector<std::size_t> clamps_before = leaf.clamp_counts();
...
note_leaf_clamps(clamps_before);        // on the throwing exit as well
```

`clamp_counts()` allocates a fresh vector and folds the supply model's tally into
it. It runs twice per `record_leaf_outputs`, which runs once per differentiated
leaf evaluation -- the fixture reports 2,333,500 placements on the same path.
**Millions of vector allocations inside the production gradient to answer a
question the other mechanism answers with an `if constexpr`.**

⚠️ **The merge is REFUSED, and the allocation went without it.** One counter with
a `bool differentiating` set by the recording would replace plant's
`if constexpr (is_same_v<S, double>)` — a compile-time fact about the scalar
— with runtime state, in order to match phylloptim, which cannot use the
scalar because the leaf solves in double on both paths. **These are not one idea
spelled twice.** They answer the same question about two different situations: a
scalar known at compile time, and a scope known only at runtime. Merging them
drags the better shape down to the worse one, which is the opposite of what a
unification is for.

**What was actually costing something was the allocation, and it is gone.**
`Leaf::clamp_count(site)` already summed the leaf's tally and the supply model's
for one site, and had no caller anywhere in the tree; reading site by site puts
the whole tally on the stack. Same numbers, same attribution, no heap. The
per-iteration bounds guard became a `static_assert` that the leaf's sites are the
last of plant's.

⚠️ **And do not widen the bracket instead**, which is what
`subtraction-targets.md` 5 suggests. `solve_leaf` also runs inside a
differentiated rate evaluation, and today it sits OUTSIDE the per-placement
bracket, so its clamps are attributed forward. A bracket around the whole
gradient moves them to the differentiated bucket — a silent change to a
diagnostic, dressed as an allocation win.

---

## 5. Built once per step, constant for the whole sweep

Extends `subtraction-targets.md` 3, and sharpens it: the entry names the deep
copy. There are **three** things rebuilt per recording, and two of them are
cheap to fix without touching `derivs`.

`state_and_parameter_adjoints` opens with

```cpp
auto active_system = system.template rebind_from<scalar>();
const std::vector<scalar*> parameters = active_system.ad_parameters();
```

and runs 3,381 times per sweep on the century fixture.

**(a) The rebind: 7.0 s, 6% of the gradient.** Measured, and the exclusive time
is the light interpolant being reconstructed.

⚠️ **TRIED NAIVELY, FAILED, THEN MEASURED.** Lifting the System once per
constant-width range and changing nothing else gave adjoints of order 1e13
against an expected 1.3. The reason is a property of the AD library, stated in
the paragraph that attempt proposed removing: *assigning from an expression keeps
the slot the target already had.* So rewriting a member does not refresh its
slot, and `clearAll()` returns the slot counter to zero -- so the write goes
through a slot the next recording reissues.

`odelia/tests/standalone/probe_tape_reset.cpp` is that behaviour on twenty lines
of model, away from plant, with the four resets side by side. Run it: `make
probe_tape_reset && ./probe_tape_reset B 6 grow`.

**The reset is not one thing, and this is the finding.** Three of them, measured
at 10,000 recorded temporaries per recording, over 3,400 recordings:

| reset | correct? | 1,000 / 2,000 / 3,400 recordings | memory at 3,400 |
|---|---|---|---|
| rebuild + `clearAll` | yes | -- | flat |
| carry + `clearAll` | **no, silently** | -- | flat |
| carry + `newRecording` | yes | 6.29 s / 25.6 s / 73.7 s | 272 MB |
| carry + de-register + `clearAll` | yes | 0.105 s / 0.210 s / 0.357 s | 280 KB |

`newRecording()` never rewinds the slot counter, so it fixes the correctness --
and it stops doing the other job `clearAll()` was doing. `unregisterVariable`
reclaims a slot only if it is the last one handed out, and a `std::vector` of
active values destroys front-to-back, so a model evaluation leaks nearly every
slot it allocates. `initDerivatives()` zero-fills `0..maxDerivative_` on every
recording, so the k-th recording pays O(k x leak): **4x per doubling, measured.**
plant's recording allocates on the order of 10^6 actives, which puts that arm at
tens of GB and hours of zero-filling. Not viable.

**De-registering first is, and it is linear.** Move-assigning a fresh temporary
swaps slots, so the temporary carries the old one away and its destructor
releases it, and no statement is recorded:

```cpp
x = xad::AReal<double>(xad::value(x));   // back to unregistered, cleanly
```

Done to every active member and then `clearAll()`, the slot layout is
byte-identical to the rebuild arm and the memory is flat -- the object is reused,
the slots are fresh. It buys the 7 s because the profile's exclusive time is
`std::_Construct<hermite_interpolator>` and its Span vectors: *allocation*, which
reuse skips, not slot bookkeeping, which this still pays.

⚠️ **The order is load-bearing and the wrong way round is a landmine.**
`clearAll()` first and de-register second leaves the adjoints right in the
shipped build while underflowing the live-variable counter to zero -- and with
`XAD_TAPE_REUSE_SLOTS` compiled in, which is one commented-out line in
`XAD/Config.hpp`, the freed slots are reissued and the answers go wrong. Reset
the members, then the tape.

⚠️ **Re-registering cannot substitute for de-registering.** `Tape::registerInput`
is guarded by `if (!inp.shouldRecord())`, so on a member that already holds a
slot it does nothing at all.

**Landed, and measured.** A-B-A in one session, the century fixture (3,378 steps,
state 1,361 wide), `stand_gradient` twice per build:

| build | gradient |
|---|---|
| rebound once per range | 109.52 s, 109.70 s |
| rebound per recording | 112.94 s, 113.15 s |
| rebound once per range, again | 107.87 s, 107.88 s |

Bit-identical answers in all six runs. **So it is 3 to 4 per cent, not the 6 the
profile suggested**, and the gap is worth writing down: what the hoist removes is
the allocation, and what it adds is a walk of about fifteen hundred move
assignments and destructor calls per recording -- five million over the sweep. The
interpolant's values are rewritten by the field build either way; only its storage
is reused.

⚠️ **Judge the surface against that number and not against the 7 s.** The
enumeration is ten classes of the model saying what they hold, and 3 per cent is a
thin return on it. What is arguably worth more than the time is the check: the
requirement used to be a rule no signature could state and nothing could test,
and it is now one number that failed four times while this was written.

**The version that asks the model for nothing exists, and it is unaffordable.**
`XAD_TAPE_REUSE_SLOTS` is a compile-time option of the vendored library,
commented out in `XAD/Config.hpp`. With it on, a freed slot is reclaimed whatever
order it was freed in, so `newRecording()` can replace the per-recording
`clearAll()` without the slot leak that makes that quadratic -- and a carried
System is then correct with **no release, no enumeration and nothing asked of
plant at all.** Verified: the ladder passes with the release entirely disabled,
673 assertions, bit-identical.

Measured on the century fixture, same session:

| configuration | gradient |
|---|---|
| rebind per recording | 112.9 s, 113.2 s |
| rebind per range, release, clear | 107.9 s, 109.7 s |
| the same plus slot reuse | 149.9 s, 150.2 s |
| slot reuse, `newRecording`, no release | 276.4 s, 276.9 s |

**Slot reuse costs 38 per cent before anything is done with it**, and dropping the
clear on top of it costs another 126 s. The reason is the shape of this model
rather than of the option: a recording registers and unregisters on the order of
10^5 to 10^6 values, and each one now has to be threaded through the reuse
ranges, where `clearAll()` did that bookkeeping by throwing the counter away.

So the two properties pull against each other: slot reuse buys correctness for a
carried System and charges 38 per cent for the bookkeeping that buys it.

⚠️ **"There is no version of this that stays inside odelia" stood here, and it was
wrong the way the first attempt was wrong** -- it named a limit that is a property
of the reset chosen rather than of the library. The tape's slot counters live on a
sub-recording held in a stack, and folding a nested recording restores the
enclosing frame's counter along with the statement, operation and derivative
arrays. So slots issued before a nest are never reissued by it, and
`initDerivatives()` then zero-fills only from the nest's own start -- which is the
property whose absence makes `newRecording()` quadratic. A System registered once
per range and each recording taken as a nested one is correct with no release, no
ordering rule, and the model's walk happening twice per range instead of 3,400
times.

**Measured, and it is not worth having.** The nested arm is flat -- 0.43 s and 180
bytes over 3,400 recordings, against 36.9 s and 272 MB for `newRecording()` -- and
needs no patch, because putting the whole descent inside one `CheckpointCallback`
makes `prevMax_` valid. But **the release it would replace costs 8 ms**: 5.1 million
member-releases at 1.6 ns each against a 108 s gradient. And nesting does not remove
the model's enumeration, which was the only reason to want it: slots issued inside
the first nest are reissued by the second, so every long-lived active member must
still be registered before the first nest. `one-reverse-pass.md` III has the table
and the three disciplines nesting adds.

So this entry closes where it began: release, then clear, per recording -- and the
per-recording rebind it replaces is worth 3 to 4 per cent, all of it allocation.

**(b) `ad_parameters()` walks the table with a string comparison per entry.**
`TF24_Pars::has_column(name)` is a linear scan over the seventeen
`undifferentiable` entries comparing `string_view`s. `ad_parameters()` calls it
once per table entry -- sixty of them -- and allocates a vector. `Patch` does
that per species and concatenates. Everything in the predicate is `constexpr`, so
a good optimiser may fold the whole scan; whether it does is not something a
reader can tell, and it does not need to be a question. `column_count` is already
computed at compile time by exactly this loop, so the column table can be too:

```cpp
static constexpr std::array<member_ptr, column_count> ad_parameter_columns = ...;
```

and `ad_parameters()` becomes a copy of forty-four addresses with no predicate.

**(c) The parameter layout is fixed for the whole sweep**, and is being rebuilt
beside a System it belongs to. Both (a) and (c) have the same fix and it is a
signature, not a redesign: **the sweep owns the active System and its parameter
list for the sweep's lifetime, and the transpose takes them.**

```cpp
state_and_parameter_adjoints(tape, active_system, parameters, state, ...)
```

`solve_adjoint_over_insertions` already owns a tape for the walk; it can own
these the same way, and `step_adjoint` passes them through.

⚠️ **What has to be true for that, stated as a check rather than a hope.** The
guarantee the per-recording rebind buys is that every active scalar arrives
holding no tape slot. Hoisting it replaces that with: every active member the
recording writes is *rewritten* by the state load before it is read. That is
true of the ones the profile names -- the interpolant's values and slopes are
overwritten wholesale by `set_data` on every field build, `competition_capture`
is reassigned per build, `resource_depletion` is cleared and refilled, `Internals`
states come from the load and rates from `compute_rates`. It is an audit, not a
guess, and it is the audit that decides whether this is a signature change or a
`derivs` rewrite. The narrow form is available either way: hoist the rebind and
reset by loading the state.

---

## 6. Two recordings of one run, and a member for a product plant does not use

**`Solver` keeps the run twice.** `history` is a `std::vector<System>` -- a whole
Patch per accepted step -- and `collect` is set **true in the constructor**.
`prev_steps` is the `step_record` list the sweep reads. Both are on by default or
opt-in per run, both are "what the run did", and they were built five years
apart. `history` is still read by R, so this is not a deletion; it is a question
worth asking once, in one place, rather than a reader discovering two answers.

**`Solver` also carries `active_solver` and `tape` as public members**, and
nothing in plant or phylloptim touches either. Their only consumers are odelia's
own `solver_interface.hpp` (which lazily builds `active_solver` through a free
function and stores it back on the double Solver) and `calibration.hpp`. Because
of them:

* `Solver` needs a hand-written copy constructor and assignment operator, with a
  comment explaining that the implicit ones are unavailable only because of the
  `unique_ptr<Tape>` member;
* `rebound_system<S, U, bool>` needs its false specialisation and its "harmless
  placeholder" branch so that `Solver` can be class-instantiated for a System
  that cannot rebind;
* every reader of `Solver` meets an L1/L2/L3 vocabulary (`set_schedule`, `run`,
  `replay_schedule_`) that belongs to a different product.

Move both into the holder that wants them -- the calibration driver already is
one -- and the copy constructor, the assignment operator and one arm of
`rebound_system` go with them. `ode_jacobian.hpp` still needs `rebound_system`,
so the template stays; the placeholder no longer has to.

---

## 7. A test-only parameter threaded into the production sweep

`census_trait_gradient(extra_stops, which_metrics)` is reached from
`census_gradient.cpp` with `{}` and from `gradient_ladder.cpp:1061` with real
values. It threads into `solve_adjoint_over_insertions`, where it becomes:

```cpp
std::vector<std::size_t> cuts;
for (const std::size_t s : extra_stops) { if (s > lower && s < upper_end) ... }
std::sort(cuts.begin(), cuts.end());
std::size_t upper = upper_end;
for (std::size_t c = cuts.size(); c-- > 0;) { solver.solve_adjoint(...); ... }
```

inside the hot walk, plus the `swept` return value's "which is not the segment
count -- an empty lowest segment is swept zero times, and a split adds one"
caveat, which exists only because of it.

⚠️ **The property it checks is real and the parameter is NOT redundant, which
this entry had wrong.** A ranged entry point does not replace it: what the identity
rung compares is one *product* call taking a different internal route against one
that does not, and the range form gives the ladder that only if the census seeding
and the accumulator are duplicated there. `one-reverse-pass.md` step 0 caught this;
the ranged form now exists as `Solver::solve_adjoint(lambda, p, k_first, k_last)`
and `extra_splits` still stands, so what is left of this entry is the fifteen lines
inside the walk and the qualification on `swept`, not the parameter.

This is `subtraction-targets.md` 8's finding from the other side: there the
oracle entry points are test-only; here a *product* entry point has a test-only
half.

---

## 8. The ladder's injection API lives in the production headers

Extends `subtraction-targets.md` 10, which sizes `gradient_ladder.cpp`. The cost
is not only that file. To let it inject a state and read a block Jacobian,
production headers carry a **fifth** state vocabulary:

| | where | reader |
|---|---|---|
| `block_input_size`, `block_output_size`, `block_inputs`, `set_block_inputs` | `individual.h` | `gradient_ladder.cpp` |
| `n_cohort_reads`, `cohort_reads`, `set_cohort_reads` | `tf24_environment.h` | the above |
| `knot_values`, `knot_slopes`, `set_knot_data` | `resource_spline.h` | the above |

And it is not only surface. `set_cohort_reads` writes soil potentials *directly*,
which is why `get_soil_water_potential_state()` is a cache keyed on the state's
passive value with a validity flag, rather than a quantity derived where the
state is set (entry 9). **The ladder's injection point is the reason a hot-path
read in the forward model has a staleness scan.**

Whether the block rung earns its keep is `subtraction-targets.md` 10's study.
What this entry adds is the price: a state vocabulary, three accessors on the
interpolant, and the shape of a cache in the model everything reads.

---

## 9. Four caches, four shapes — the drivers DONE, the potentials REFUSED

`subtraction-targets.md` 18 names two of these. There are four, and the two it
does not name are the ones in the hottest code.

| | key | value | shape |
|---|---|---|---|
| `MultiLayerRoots::CurveCache` | `(b, c, resolution)` | two splines | thread_local store, linear scan, bound 32 |
| `Leaf::StemCurveCache` | `(b, c, resolution)` | two splines | the same, spelled again |
| `Leaf::curve_reads_` / `CurveReads` | one double | seven doubles | member vector, linear scan, cleared on state change |
| `TF24_Environment::psi_soil_` | a validity flag | the potentials | member + flag; the value key is already gone |
| ~~the seven driver caches~~ | the time | one double each | DONE: one record, one time, a flag per driver |

The first two are one type written twice, as that entry says. The last two are
something else: **they are derived quantities wearing a cache's clothes.**

⚠️ **Half of the potentials item was already done, and the other half is a LOSS.**
`psi_soil_cache_state_` and the per-read staleness scan (a `to_passive` compare per
layer per read) went in plant `c50e3a2b`; what is left is the values and one flag.
Deriving them at the load does not save that flag's cost, it adds work: the derive
is lazy and CONDITIONAL today, so a patch with no cohort reading the potentials
never pays it, where deriving at the load pays `soil_number_of_depths` ACTIVE
writes on all six loads a step. And the flag could not go anyway, because it has a
second reader — `set_cohort_reads` marks INJECTED potentials valid, and a derive at
the load would quietly replace them, taking the ladder's injections with them.

**The seven drivers are DONE: fourteen members are one record**, holding the
values, the one time they were read at, and a flag per driver. The name comes from
a table indexed by an enum rather than a literal at the call site, so a memo cannot
be keyed on one name and read under another, and a driver is added as one
enumerator plus one getter.

⚠️ **But NOT "refreshed where the time is set", and "seven comparisons become
none" is withdrawn.** `Drivers::evaluate` does `drivers.at(name)`, which raises for
a driver that was never set, and raises again for a time outside a variable
driver's control points — so refreshing seven to serve one raises on an environment
that only ever reads one of them. The comment on the getters said exactly that, and
was right. What the record buys is the member count and the shape, not arithmetic.

It also closed a hole nothing was watching: `assign_from` carries `time` through
the base assignment and did not touch the caches, so an assignment into a live
environment read fresh at the new time while holding the old environment's
values.

⚠️ **Two comments in that file described the value-keying after it had been
deleted**, which is how this entry came to be planned against a mechanism that was
already gone. Both are corrected. The lesson is the one at the top of
`principles.md`: where a document disagrees with the code, the disagreement is the
finding.

⚠️ **The 32-entry bound on the curve stores is load-bearing** (that entry says
why). One `keyed_store<Key, Value, N>` keeps it in one place instead of two.

---

## 10. Smaller unifications, each a pair

* **`E_from_soil_at` reports a split three of its four callers throw away.** It
  opens with `per_layer.assign(supply_n_layers(), T(0.0))` -- n active-scalar
  constructions -- and `profit_at` and both `bound_at` arms immediately discard
  it. Two entry points: the total, which is the primitive, and the split, for the
  one caller that reads it. This was read as the same shape as `inserted_state` in
  `subtraction-targets.md` 14, and it is the shape *inverted*: there four of five
  callers want the report, so the mutation is the primitive and the split is not
  the question. Count the callers before borrowing the remedy.

* **`census_metric` holds a `std::function` for three capture-free lambdas.**
  So `metrics_of<P>()` heap-allocates three type-erased objects on every call --
  seven call sites in `scm.h`, three of them inside a recording (`reduce`, and
  both tangent replays). A function pointer and a
  `static constexpr std::array` returned by reference removes the allocation, the
  indirect call, and most of `census_trait_gradient`'s thirty-line name lookup
  (`subtraction-targets.md` marks that hotspot A).

* **`Node::survival_individual()` is written twice**, once as the accessor
  `offspring_dt_dfecundity_rate` reads and once as a local inside
  `compute_rates` -- including the non-finite squash. The local should be the
  call.

* **`compute_environment_excl_capturing` and `compute_environment_closing` both
  open by stamping every species' boundary node birth date.** Two loops, one
  fact, and the second is a no-op if the first ran. It belongs to
  `compute_environment`, above both.

* ~~**`advance_over_insertions` computes a state it never uses.**~~ DONE. The map is
  `apply_insertion` and the report is what its other four callers want, so what went
  was the allocation and not the argument: both buffers are held across the walk
  rather than built per insertion. `one-reverse-pass.md` step 3c has why the report
  stayed.

* ~~**`adjoint_segments = n_metric * solve_adjoint_over_insertions(...)`.**~~ DONE.
  The sweep is shared across metrics -- that is the whole point of the batch -- so
  multiplying its range count by the metric count reported something no walk did.
  The multiplier is gone from the code and from the expectation in
  `test-gradient-ladder-first-segment.R` that carried it, and the count itself has
  since moved onto the returned `census_gradient` as `segments`
  (`subtraction-targets.md` 19).

* ~~**`refusal` carries three fields nothing writes.**~~ DONE, with the other half
  of `subtraction-targets.md` 4. `node`, `step_first` and `step_last` are gone and
  so is the exception, so a value no longer becomes an exception and a value again
  two frames later. **The severity the exception looked like it encoded is read by
  nothing** — both consumers not-a-number every row on either escape, which is
  why one latched value replaced two mechanisms rather than one value with a field.
  `one-reverse-pass.md` step 4 has the count.

---

## Read, and not a target

* **`scratch_tape`'s copy constructor that drops the tape** is right, and reads
  like an oversight. Two holders recording on one tape would each clear the
  other's recording, and the foreign-tape check cannot fire because the tape is
  not foreign. Leave it.

* **The two build phases of the light field are not a double reduction.**
  `compute_environment_closing` reuses `competition_capture`, so the second pass
  closes one trapezium per knot per species rather than re-reducing. The ordering
  removes a fixed point that iterating would only attenuate. It earns its keep.

* **The interpolant holding `y` and `m` beside the spans they built** is not
  stored-derived state: those two vectors *are* the environment's cohort reads,
  and `set_data` is what a build hands over. The order-3/order-5 split is
  likewise not a setting to collapse -- the comment's tape argument is correct.

* **`Step`'s per-recording locals** (`y0`, six rate vectors, the stage vector),
  already checked and rejected in `subtraction-targets.md`. Confirmed here: they
  are the stale-slot hazard, and resetting reused ones costs what constructing
  them costs.

---

## Landing order

Subtraction before scaffolding, and each increment lands on its own.

**First, because they cost nothing to get wrong and unblock the rest.**

1. Entry 7 -- drop `extra_splits`. Two signatures, fifteen lines, no behaviour.
2. Entry 10's six items. Each is local and independently checkable.
3. Entry 5(b) -- the constexpr column table. One `static constexpr` array; the
   existing `static_assert` on `column_count` already guards it.

**Then the mechanisms, in this order because each makes the next smaller.**

4. ~~Entry 9 -- derive the potentials and the drivers at the load.~~ The
   drivers are DONE as one record and the potentials are REFUSED; see the entry.
   ⚠️ The claim that it "takes one of the two reasons entry 8's injection API
   exists with it" is backwards: the injection is the SECOND READER that keeps
   the flag alive, and a derive at the load would overwrite what it injects.
5. ~~Entry 4 -- one clamp counter.~~ The per-placement allocation is DONE and the
   counter merge is REFUSED; see the entry. It was the sharpest speed item on
   this list that is not entry 5.
6. ~~Entry 2 -- the address as a scope, then the fill flag onto the store.~~ DONE,
   and the flag went further than the store: nothing stores it. It arrives on the
   address from the walk that steps. `subtraction-targets.md` 17 folded in with it,
   because a mode that is not stored cannot outlive the slot it described -- and it
   landed as two pointers rather than the two types that entry proposed.
7. Entry 5(a)(c) -- hoist the active System and the parameter list into the
   sweep, after the audit the entry names. 6% of the gradient.
8. Entry 6 -- move `active_solver` and `tape` out of `Solver`.

**Then the two that are redesigns rather than edits.**

9. Entry 3 -- one reduction, three producers. Touches the hottest forward path,
   so it wants the control `subtraction-targets.md` describes: the same file,
   both sides, interleaved in one session.
10. Entry 1 -- one differentiable leaf. The largest, the last, and the only one
    that needs a decision before it needs code: whether phylloptim's
    `leaf_gradient_batch()` is reimplemented on the tape, or the FD path stays as
    a second product with the duplication written down and accepted.

## What this does not measure

Nothing here was timed. The figures quoted -- 7.0 s of rebind, 2,333,500
placements, 6% of the gradient -- are `subtraction-targets.md`'s and are repeated
rather than re-measured. Every claim about *count* (call sites, readers,
allocations per call) is read off the current tree. Any claim about *speed* needs
the control that document sets out, and entries 3, 4, 5 and 9 are the four where
that matters.
