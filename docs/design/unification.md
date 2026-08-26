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

## 2. Six ways to load a state, two concepts to route one address

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

Two concepts exist to carry `at` down: `RecordsChoices` in odelia's
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
  if constexpr (AddressesChoices<T>) { obj.begin_stage(at); }
  internal::set_ode_state(obj, y, time);
  obj.ode_rates(dydt.begin());
  if constexpr (AddressesChoices<T>) { obj.end_stage(); }
}
```

deletes the three-arity `set_ode_state` in both packages, one of the two
concepts, and the "opened here, closed there" invariant that currently spans two
Patch members and is checked by nothing. It also makes the scope an object's
lifetime if anyone wants it to be, which the current shape cannot be.

**The flag arriving separately is the worse half, and it is cheaper to fix than
the address.** `begin_stage(at, keeping)` collects `Patch::recording` -- a public
`bool`, written twice (a setter called once from `SCM::run`, forced false in
`assign_from`), read at exactly one site, and correct only if the caller set it
to agree with the solver's `set_keep_states`. It does not vary per stage. It
varies per *run*. So it belongs on the store, set once:

```cpp
patch.set_recording(x)  ->  for species: leaf_points->fill(x)   // once per run
begin_stage(at)                                                 // per evaluation
```

That removes a public mutable bool from `Patch`, one argument from three
signatures, and the pairing that nothing validates. It is also the precondition
for splitting the recorder from the player (`subtraction-targets.md` 17): once
`fill` is set once per run rather than per stage, `end_stage()` can no longer
leave the two disagreeing.

---

## 3. The trapezium reduction is written three times

Extends `subtraction-targets.md` 6, which names the wasted double reduction. The
duplication is wider than the waste.

| | `species.h` | when |
|---|---|---|
| `compute_competition_and_slope_split` | 591 | one height, ordered walk |
| `field_splits` | 483 | a whole height set, prefix sums |
| `compute_competition_and_slope_unordered` | 688 | one height, sorted view |

All three integrate `n_k f(z; state_k)` over the same grid by the same trapezium
rule. All three then decide whether the boundary interval closes, and **that rule
is written out three times** -- `n == 1 || birth_date || f_h1 > 0` at line 583,
`size() == 1 || birth_date || f_h1 > 0` at 636, and `size() == 1 || f_h1 > 0` at
727, where the third has silently dropped the `birth_date` arm because on its
path that arm is unreachable. Three spellings, one of them different, and no
compiler can tell you.

`close_competition_and_slope` then dispatches on the three booleans
`competition_split` carries to work out which of the three produced the value it
was handed.

**What they actually differ in is the SEQUENCE, not the reduction.** Each
produces the same thing: a list of `(abscissa, f, slope)` in ascending abscissa,
optionally truncated where the support ends. The walk produces it in place; the
prefix form produces it once for many heights; the sorted form produces it out of
order and sorts. One reduction over that sequence, three producers of it, and:

* the `closes` rule lands once,
* the three booleans have nothing left to say,
* `subtraction-targets.md` 6's O(n log n) double pass cannot happen, because the
  unordered producer feeds the same reduction as the others instead of returning
  a finished answer with a flag saying so,
* `field_splits`'s fallback (`!scan.decreasing || n_moments == 0`, which calls
  the per-height split in a loop) stops being a dispatch between two
  implementations and becomes a choice of producer.

⚠️ **The prefix form is not an optimisation to fold away.** It is linear in nodes
plus heights where the walk is their product, and inside a recording the
operation count *is* the tape. It has to survive as a producer.

---

## 4. Two mechanisms for "which pass was this", and one of them is in the hot path

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

**One counter, and the pass is a property of the pass.** phylloptim's counter
gains the two halves and a `bool differentiating` that the recording sets; plant
keeps its site enum (which already extends phylloptim's by offset) and drops its
own struct. Then `note()` writes to the right half wherever it is called, and
`clamp_counts()`, `clamp_count()`, `note_leaf_clamps`, `clamps_before` and both
copies of the `is_same_v` branch all go -- along with the per-placement
allocation.

The flag is the one new thing, and it is one bit set by the frame that knows,
where today the same fact is inferred twice by two different methods.

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

**What this costs to land** is the enumeration: every active member of the Patch,
reached once. That is the same audit this entry used to describe as reassurance,
and it is now load-bearing -- a member left out is a wrong number rather than a
missing one, and it is wrong only once two recordings differ in shape.

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
signature, not a redesign: **the sweep owns the lifted System and its parameter
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

`census_trait_gradient(extra_splits, which_metrics)` is reached from
`census_gradient.cpp` with `{}` and from `gradient_ladder.cpp:1061` with real
values. It threads into `solve_adjoint_over_insertions`, where it becomes:

```cpp
std::vector<std::size_t> cuts;
for (const std::size_t s : extra_splits) { if (s > lower && s < upper_end) ... }
std::sort(cuts.begin(), cuts.end());
std::size_t upper = upper_end;
for (std::size_t c = cuts.size(); c-- > 0;) { solver.solve_adjoint(...); ... }
```

inside the hot walk, plus the `swept` return value's "which is not the segment
count -- an empty lowest segment is swept zero times, and a split adds one"
caveat, which exists only because of it.

**The property it checks is real and the parameter is redundant.**
`Solver::solve_adjoint(rec, lambda, parameter_adjoint, k_first, k_last)` is
already public and already takes an explicit range, so a ladder rung composing
two sub-ranges and comparing bit for bit needs nothing new. Removing
`extra_splits` takes a parameter off two public signatures, fifteen lines out of
the sweep, and the qualification off `swept`.

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

## 9. Four caches, four shapes, and two of them are not caches

`subtraction-targets.md` 18 names two of these. There are four, and the two it
does not name are the ones in the hottest code.

| | key | value | shape |
|---|---|---|---|
| `MultiLayerRoots::CurveCache` | `(b, c, resolution)` | two splines | thread_local store, linear scan, bound 32 |
| `Leaf::StemCurveCache` | `(b, c, resolution)` | two splines | the same, spelled again |
| `Leaf::curve_reads_` / `CurveReads` | one double | seven doubles | member vector, linear scan, cleared on state change |
| `TF24_Environment::psi_soil_cache_` | the state, by passive value | the potentials | member + `_state_` key + `_valid_` flag |
| the seven driver caches | the time | one double each | 14 members + a string-keyed miss path |

The first two are one type written twice, as that entry says. The last two are
something else: **they are derived quantities wearing a cache's clothes.**

`psi_soil_cache_` is invalidated by `set_ode_state` on every load, so it never
hits across rate evaluations -- it hits only for the many cohorts reading it
*within* one evaluation. That is not a cache, it is a quantity that should be
computed where the state is written. Doing that deletes `psi_soil_cache_state_`,
`psi_soil_cache_valid_`, the per-read staleness scan (a `to_passive` compare per
layer per read), and one of the two reasons the flag exists.

The seven drivers are the same shape at seven times the size: `ppfd_cache_`,
`atm_vpd_cache_`, `ca_cache_`, `leaf_temp_cache_`, `atm_o2_kpa_cache_`,
`atm_kpa_cache_`, `wind_speed_cache_`, each with a `_cache_time_` beside it, and
a `cached_driver_(name, val, time)` helper that does a **string-keyed driver
lookup** on a miss. Fourteen members and seven time comparisons per cohort per
stage, for seven numbers that are all functions of the same time. One record
refreshed where the time is set: fourteen members become one, seven comparisons
become none, and the string names leave the hot path.

⚠️ **The comment on `psi_soil_cache_` states the hazard correctly and the
invalidation is what handles it** -- "keyed on that state by value, which cannot
see a changed derivative behind an unchanged value". Deriving at the load keeps
that property by construction rather than by a flag two other methods also
write.

⚠️ **The 32-entry bound on the curve stores is load-bearing** (that entry says
why). One `keyed_store<Key, Value, N>` keeps it in one place instead of two.

---

## 10. Smaller unifications, each a pair

* **`E_from_soil_at` reports a split three of its four callers throw away.** It
  opens with `per_layer.assign(supply_n_layers(), T(0.0))` -- n active-scalar
  constructions -- and `profit_at` and both `bound_at` arms immediately discard
  it. Two entry points: the total, which is the primitive, and the split, for the
  one caller that reads it. Same shape as `inserted_state` in
  `subtraction-targets.md` 14.

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

* **`advance_over_insertions` computes a state it never uses.** `sys.inserted_state(...,
  before.begin(), after)` fills `after`, then `forward.set_state_from_system()`
  reads the mutation instead. The local is the report half of the same
  mutate-and-report shape as the entry above.

* **`adjoint_segments = n_metric * solve_adjoint_over_insertions(...)`.** The
  sweep is shared across metrics -- that is the whole point of the batch -- so
  multiplying its range count by the metric count reports something no walk did.
  Whatever the diagnostic is for, it is the sweep's own number.

* **`refusal` carries three fields nothing writes.** `node`, `step_first` and
  `step_last` are `-1` for ever and all three cross to R. Named here because they
  are the *other* half of `subtraction-targets.md` 4: the exception's `site`
  member and the plain `refusal` value type are declared in the same header, so a
  value becomes an exception and becomes a value again two frames later, and three
  of the value's fields are the mechanism that was never built.

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

4. Entry 9 -- derive the potentials and the drivers at the load. Removes two
   flags, a key vector, a staleness scan and thirteen members, and takes one of
   the two reasons entry 8's injection API exists with it.
5. Entry 4 -- one clamp counter. Deletes the per-placement allocation from the
   production gradient, which is the sharpest speed item on this list that is
   not entry 5.
6. Entry 2 -- the address as a scope, then the fill flag onto the store. This is
   the precondition for `subtraction-targets.md` 17 (the recorder and the player),
   so it lands before that rather than beside it.
7. Entry 5(a)(c) -- hoist the lifted System and the parameter list into the
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
