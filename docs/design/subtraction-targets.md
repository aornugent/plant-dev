# What is left to subtract

A log, not a proposal. Each target below names something the reverse-mode work
built or left behind, the evidence that it is not earning its keep, and what
would break if it went. Targets are removed from this file when they land.

`recording-and-sweep.md` item 11 is one of them, quantified here rather than
restated.

## The rules these were found by

Six, and none of them is a line count. Each entry below names the one it failed.

1. **A thing earns its keep by having a consumer that is not itself.** Tests are a
   consumer, but a surface reachable only from tests is held up by the thing it
   is meant to check. A taxonomy whose reader was deleted is not a taxonomy, and
   neither is a compile-time check whose stated reason no longer exists.
2. **One fact, one representation.** A fact spelled three ways costs a reader
   three times, and the spellings drift.
3. **A layer earns its keep by hiding a decision.** One that repeats its
   arguments and hands them on is reader load without compression. A wrapper with
   one caller is not a boundary.
4. **Prefer returns to mutations, and derive rather than sync** -- but never
   re-derive what the producer already knew and discarded.
5. **A boolean that records how a value was computed means the domain wants a
   structure.** So does one that decides which half of a type is live: that is
   two types.
6. **Question anything threaded through layers.** A signal passed through four
   frames to reach one reader has a shorter path.

Ordered by leverage: entries 1 to 7 question a design decision, 8 onward are
residue and instrumentation. What none of them are is large diffs -- the three
sharpest cost a reader most and a line count nothing.

## The measurement

Line counts split into code and comment, by what the file is for. `main` is
`master` for odelia and phylloptim and `develop` for plant.

| range | code | comment |
|---|---|---|
| odelia `main → ad/v3-forward` | +2,889 | +1,117 |
| phylloptim `main → ad/v3-forward` | +10,872 | +5,182 |
| plant `main → ad/v3-forward` | +9,578 | +4,405 |
| **`ad/v3-forward → leaf worktree`** | **−4,020** | **−1,339** |

Shipped code alone — headers and the R layer, excluding tests and docs — is
**+8,448** against main, and the leaf worktree returns **−855** of it. Test code
is **+13,788**, so most of the branch's growth is assurance rather than model.
The leaf worktree is the only net-negative range.

Comment density, shipped code: odelia 0.37 comment lines per code line, plant
0.32, **phylloptim 0.91**. `leaf_model.hpp` carries 2,231 code lines against
2,374 of comment.

The branch's net **+19,416** code lines, by what they are for:

| | lines | share |
|---|---|---|
| shipped model | +5,449 | 28.1% |
| tests outside the ladder | +5,258 | 27.1% |
| ladder tests and helpers | +3,075 | 15.8% |
| generated | +1,848 | 9.5% |
| ladder reference data | +1,805 | 9.3% |
| notes and docs | +1,626 | 8.4% |
| ladder `.so` surface (test-only) | +793 | 4.1% |
| probes nothing builds | +547 | 2.8% |

**The model is 28% of what reverse mode added; assurance is 56%.** That is not by
itself wrong, and item 11 is the study that decides it. What is wrong is measuring
this work in lines at all: the cost a reader pays is in concepts and indirection,
and the targets below are ranked by that instead.

⚠️ **Three of the five `tests/cpp/probe_*.cpp` no longer compile** —
`probe_curve_order`, `probe_curve_tables` and `probe_slope_rules`, 356 lines. The
Makefile builds them from no target, so nothing noticed. A probe that does not
compile is not a measurement anyone can repeat.

## The comments this branch wrote

2,151 blocks, 10,317 lines. 862 are two lines or fewer. 296 are longer and spell
out a silent-failure hazard, which the style rule exempts and which are the
best-earned lines in the tree. **993 are longer and are not hazards, at 5,652
lines**; trimming those to two lines each recovers about 3,666.

Named violations: 45 section banners, 56 process-history lines, 12 borrowed
mechanism words, 7 decorative nouns. Fifteen banners were branch-authored and are
gone; the other thirty are on main and stay until main is in scope.
## The control flow, and where it is confusing

One product call, `census_trait_gradient`, end to end. Five files, two packages.
Vocabulary a cold reader must acquire is in brackets; the marks are the hotspots.

```
R  census_trait_gradient_tf24                                  census_gradient.cpp
│
└─ SCM::census_trait_gradient                                             scm.h
   ├─ require_birth_date_coordinate                       [guard, 1 of 2 regimes]
   ├─ resolve which_metrics -> rows        30 lines of name->index    ✱ A
   │     [census_metric, metrics_of]
   ├─ store_trajectory()                   MAY RE-RUN THE MODEL       ✱ B
   │     [trajectory, step_record]
   ├─ adjoint_segments = 0 ; adjoint_at_first_state.clear()           ✱ C
   ├─ for species: *uptake_rows_unavailable = false                   ✱ D
   │
   ├─ try census_state_and_trait_rows()  ──────────────────┐          ✱ D
   │  │    [census_rows, adjoint_rows]                        │
   │  └─ state_and_parameter_adjoints                 adjoint.hpp
   │     ├─ rebind_from<active>          whole Patch copy            ✱ E
   │     ├─ splice state ++ parameters                               ✱ F
   │     └─ vector_jacobian_product      tape lifecycle, sweep/seed
   │  catch (gradient_refusal) -> NaN rows, return  ◄──────┘   ESCAPE 1
   │
   ├─ seeds = all_seeds.select(rows) ; trait_adjoint = all_direct.select(rows)
   │     the accumulator STARTS at the direct term                   ✱ G
   │
   ├─ try solve_adjoint_over_insertions                        sweep.hpp
   │  │    [insertion, widening, piece, segment, with_insertions]    ✱ H
   │  ├─ insertion_steps(rec)            infer introductions from widths
   │  ├─ with_insertions = copy of all 3,381 records
   │  ├─ for piece, highest first:
   │  │  └─ Solver::solve_adjoint                          ode_solver.hpp
   │  │     └─ for step, backwards:
   │  │        └─ Step::step_adjoint                        ode_step.hpp
   │  │           └─ state_and_parameter_adjoints  (again)  ✱ E again, per step
   │  └─ at each widening: state_and_parameter_adjoints over inserted_state
   │  catch (gradient_refusal) -> refused = true              ESCAPE 2
   │
   ├─ if (!refused) for species: poll *uptake_rows_unavailable ESCAPE 3   ✱ D
   ├─ assemble census_gradient {gradient, why}      [refusal, census_gradient]
   └─ be_at_step(live, rec, last)        restore the borrowed width
```

**✱ A — a name lookup where an index would do.** Thirty lines resolving metric
names against `metrics_of<patch_type>()`, on every call, before anything runs.

**✱ B — a getter that may re-run the model.** `store_trajectory()` repeats the run
unless `record_trajectory` kept the states. Nothing in the name says a gradient
call can cost a second simulation.

**✱ C — two return values that would not fit in the return type.** See entry 18.

**✱ D — the refusal channel, three times in one function.** Cleared at the top,
caught twice, polled once. Entry 3.

**✱ E — the Patch is deep-copied per recording**, and this call reaches
`state_and_parameter_adjoints` by three different routes. Entry 2.

**✱ F — a splice into a flat vector that the one caller immediately unsplices.**
Entry 6.

**✱ G — `trait_adjoint` is not an adjoint when it is created.** It is seeded with
the direct term, for a stated and good reason, and the name says none of it.

**✱ H — five words for one idea.** `insertion`, `widening`, `piece`, `segment` and
`with_insertions` all describe the same thing: a place where the state got wider.
`sweep.hpp` uses *piece*, `scm.h` uses *segment* (`adjoint_segments`,
`segment_base_state`), the function is named `over_insertions`, and the failure
mode is called a widening. A reader has to discover that these are one concept.

### One step's recording, the level below

What happens between `step_adjoint` and the leaf. Six stages, three tapes, two
packages.

```
Step::step_adjoint                                          ode_step.hpp
└─ state_and_parameter_adjoints ─ rebind Patch ─ splice ─ vector_jacobian_product
   └─ whole_step(active_system, x, y_end)              one recording
      ├─ y0(x, x+size)                        n_state active copies
      ├─ rate(6, vector(size)) ; stage(size)  9 allocations, deliberate  ✱ J
      └─ six times:  ode::derivs(active_system, stage, rate[i], t, {step,i})
         └─ internal::set_ode_state(obj, y, t, at)   if constexpr RecordsChoices
            └─ Patch::set_ode_state(it, t, at)       if constexpr KeepsSolvedChoices
               ├─ for species: strategy->begin_stage(at, recording)      ✱ K
               │    └─ leaf_points->begin_stage(at, keeping)
               │         └─ kept[at.step][at.stage]        ← the destination
               └─ Patch::set_ode_state(it, t)   ← the ordinary load, 3rd arity  ✱ L
         then obj.ode_rates(dydt)
            └─ Patch::compute_rates
               ├─ for species: Species::compute_rates
               │  └─ for node: Strategy::compute_rates
               │     ├─ solve_leaf() ─ place_solved_point(leaf_points->next())
               │     └─ record_leaf_outputs                    phylloptim
               │        ├─ collar_condition   ── A SECOND TAPE ──          ✱ M
               │        │    directional_adjoint_tape<double>, thread_local
               │        │    record + sweep, nested inside this recording
               │        ├─ collar_at   → implicit_root   (row supplied)
               │        └─ outputs_at
               │           ├─ profit_at → implicit_value ×2  (sigma, ci)
               │           │    each with a forward tangent for its own slope
               │           └─ E_from_soil_at   (the quadrature)
               ├─ resource_depletion  ← a member used as a local, with a TODO  ✱ N
               └─ env.compute_rates(resource_depletion)
```

**✱ J — nine allocations per recording, and they have to be there.** Reusing them
across recordings is the stale-slot hazard; see "Checked and rejected".

**✱ K — a `{step, stage}` pair threaded six layers to index a nested vector**, and
it picks up a second argument on the way. See entry 20.

**✱ L — the three-arity load calls the two-arity load.** So a recorded step loads
the state twice as far as the reader is concerned: once to announce the stage,
once to set the values.

**✱ M — a second tape, of a different scalar type, nested inside the first.**
`collar_condition` builds a `directional_adjoint_tape<double>` — the tangent-
under-adjoint scalar — records the whole profit chain on it and sweeps it, once
per placement, while plant's `adjoint_tape<double>` is mid-recording. They do not
collide because XAD keys the active tape by scalar type. Nothing states that
invariant; it is what makes the design legal, and it is discoverable only by
knowing XAD.

**✱ N — `resource_depletion` is a Patch member used as a per-call scratch**,
reserved, filled, and cleared at the end of `compute_rates`, with
`//todo do we need to clear this every step?` beside the clear. In a function on
the recording path, a member whose lifecycle carries a question mark is state that
a reader cannot reason about locally.

### What the leaf actually costs

`record_leaf_outputs` is seven lines in the diagram above. phylloptim is +10,872
code lines against main. Both are true, and the gap is worth writing down because
it is the question anyone reviewing this will ask.

The +10,872 splits: **~6,694 tests, ~2,986 shipped headers, ~913 shipped R layer,
~700 generated, ~229 docs.** Inside the headers, the entire gradient surface is
**726 code lines**:

| | code lines |
|---|---|
| the differentiable surface — `collar_at`, `outputs_at`, `profit_at`, `bound_at`, `stem_integral_at`, `E_from_soil_at` | **263** |
| hand-rolled root-curve derivatives | 124 |
| input/output plumbing — `ProfitInputs`, `LeafInputs`, `SupplyValues`, `SupplyAt` | 101 |
| caching — two curve stores and `CurveReads` | 89 |
| operating-point record — `SolvedPoint`, `place_solved_point` | 58 |
| `collar_condition` and `against` — the second-order pass | 48 |
| orphaned row types | 43 |

**So `record_leaf_outputs` reaches 263 code lines of differentiable model.** The
rest of the header growth is the model being re-templated on the scalar — a
`double f(double)` becoming a `template <class S> S f(const S&)` — and that is the
objective working, not overbuild. It shows as a large diff because every signature
changed; it costs a reader nothing, because it is the same model.

**One part of it is genuine overbuild, and it is the part the objective named.**
The leaf carries its derivative machinery twice. Nine closed-form derivative
functions — **256 code lines, three of them second derivatives** — have no shipped
consumer at all:

`d2E_from_soil_dpsi_collar2`, `d2E_from_soil_dpsi_collar_dpsi_soil`,
`dE_from_soil_droot_carbon`, `dE_from_soil_droot_curve`,
`d2uptake_dpsi_dpsi_soil`, `d2uptake_dpsi_droot_curve`,
`duptake_droot_curve_by_layer`, `duptake_droot_curve_impl`,
`duptake_droot_carbon`.

The row layer consumed them. It is deleted. They are reachable now only from
`test_leaf.cpp`, and several only through each other — a chain whose head is
test-only. Entry 15 covers the root-curve branch of this; the rest is the same
finding, wider.

### What a native reverse pass must not strand

odelia's reverse-mode surface has **two consumers with different needs**, and
entry 1's single entry point serves only one of them.

**plant wants a top-level call**: transpose a recorded run. Pieces, widenings,
per-step transposes and the tape lifecycle are all below it.

**phylloptim wants a primitive**: put a value the leaf solved onto whatever tape is
already recording. It never touches the sweep. Per placement it uses
`implicit_value` twice (the stem potential and the intercellular CO2),
`implicit_root` once (the collar), `record_with_derivatives` under both, plus
`to_passive`, `seed_direction` and `derivative_along` — and, for
`collar_condition`, the nested scalar: `directional_adjoint_tape`,
`seed_inner_direction`, `directional_adjoint`.

⚠️ **So the implicit-node surface and the nested scalar stay public.** They are not
internals of the sweep to be folded into a single entry point — they are used
inside someone else's recording, by a package that has no solver, no recording and
no sweep. A revision that hides them behind "transpose a recorded run" strands the
leaf.


## Targets

### 1. odelia offers a kit, not a reverse pass — so SCM is the assembly

**`scm.h`'s gradient surface is 247 code lines, 34% of the class**, split almost
evenly between product and oracle:

| | lines | |
|---|---|---|
| `census_trait_gradient` | 102 | product |
| `census_state_and_trait_rows` | 22 | product |
| `census_trait_tangent` | 38 | oracle |
| `census_trait_difference` | 34 | oracle |
| `replay_initial_state` | 31 | oracle |
| `segment_base_state` | 10 | oracle |
| `census_initial_state_replay` | 10 | oracle |

The size is a symptom. **Plant names twenty odelia reverse-mode concepts
directly, and they span every level of the stack** — `adjoint_rows` (17 mentions),
`derivative_along` (15), `seed_direction` (11), `recorded_step` (8),
`be_at_step` (5), `active_scalar` (4), `state_at_segment`, `scratch_tape`,
`state_and_parameter_adjoints`, `advance_over_insertions`,
`solve_adjoint_over_insertions`, `vector_jacobian_product`, `rates_adjoint`,
`record_report`, `implicit_value` and the rest.

Those are not one API used well. They are the whole-trajectory sweep, one
recording's transpose, the tape lifecycle, one right-hand-side transpose, three
state loaders and the row container — **four levels of the same library, reached
into from one caller.** odelia has no entry point that says "transpose a recorded
run", so plant assembles one out of parts, and `census_trait_gradient` is that
assembly written out.

**What a native reverse pass would take.** The caller's genuine inputs are a
solver holding a resolved recording, a function that produces the outputs, and
which output rows to sweep. Everything between is odelia's: the pieces, the
widening transposes, the per-step transposes, the tape lifecycle, and putting the
System back at the width it borrowed.

Then `census_trait_gradient` is: resolve metric names, take the trajectory, clear
the refusal latch, call it, poll the latch, assemble the answer. The pieces, the
tape, the loaders and the restoration all stop being plant's business.

**What must stay in plant, and why the boundary is there.** What a census metric
is, which ones to sweep, the direct term the accumulator starts at, and the
refusal semantics are model questions. odelia cannot own them and should not try.
The seeding function is plant's too — but it is a callable, which is exactly what
crosses a boundary cleanly.

**This subsumes several entries below.** Entry 19's smuggled members become return
values. The width restoration at the tail stops being a thing plant remembers to
do. The vocabulary leak in entry 9 — `piece` in odelia, `segment` in plant —
stops crossing at all. And entries 7 and 8 become questions about odelia's
internals rather than about its interface.

### 2. The recording is incomplete on purpose, and `sweep.hpp` exists to work around it

The largest design decision reverse mode made, and the one worth re-opening.

A run records 3,381 step states. It does **not** record the 169 states an
introduction produced — `sweep.hpp` says so directly: *"The widened state between
a widening and the step after it is what no record holds, so it is rebuilt
here."* Measured on the century fixture: **170 constant-width pieces**, state
width climbing 9 to 1,361.

Everything in `sweep.hpp` is downstream of that omission:

| machinery | why it exists |
|---|---|
| `insertion_steps` | find the gaps, by scanning widths |
| the piece arithmetic, three times | walk around the gaps |
| `with_insertions` | a full copy of all 3,381 records, to patch 169 of them |
| `state_at_segment` | rebuild the state no record holds |
| `restore_on_exit` | the descent narrows across gaps, so a throw leaves the wrong width |
| `be_at_step`'s width check | catch a reconstruction that disagrees |

**Record the 169 states and all of it goes.** They average well under the final
width; against a recording already holding 3,381 states the increase is a few per
cent. The sweep then becomes one backward loop over the record, transposing
whatever map produced each entry, and the widths are simply what the record says
rather than something to infer, reconstruct and check.

**The deeper point is where the fact went.** `insertion_steps` recovers the
introductions by scanning for a width that grew — *"an insertion is the only thing
that widens a state during a run, so the record says where they happened without
being told."* But the forward pass **was** told: it introduced the cohort. It knew
the step, the species and the map, and it discarded all three. The sweep then
re-infers them from a side effect, and has to refuse a width that shrinks because
an inference can be wrong where a recorded fact cannot.

Deriving instead of syncing is right when the fact is genuinely redundant. Here
the producer knew it and threw it away.

⚠️ **What this is not.** It is not a case for a fixed-width state. Allocating every
cohort at t=0 would roughly double both the forward run and the sweep, because
both scale with width — the varying width earns its keep. The claim is only that
the *record* of it should be complete.

### 3. The System owns mutable derived state, so it is deep-copied 3,381 times a sweep

`state_and_parameter_adjoints` opens with

```cpp
auto active_system = system.template rebind_from<scalar>();
```

and it is called from `step_adjoint`, once per recorded step. On the century
fixture that is **3,381 full copies of the Patch per sweep** — every species,
every node, and the environment's light interpolant with it.

**Measured: 7.0 s of stacks pass through `rebind_from`, about 6% of the
gradient.** Arm A spends 7.2 s, so this is the branch's design rather than
anything the leaf work introduced. The exclusive time is where you would expect:
`std::_Construct<hermite_interpolator>` at 1.05 s plus its `Span` vectors, which
is the light field being rebuilt per step.

**Why it has to be rebuilt is the design question.** `compute_rates` does not
return rates; it writes them into `Internals` members. So after a recording the
Patch holds active scalars carrying tape slots, and `adjoint.hpp` states the
consequence exactly: clearing the tape returns the slot counter to zero, a scalar
still holding the last recording's slot is handed the same number as something
else in this one, and their adjoints add together. A fresh rebind guarantees every
scalar arrives passive.

So the deep copy is not defensive — it is the only reset available, because the
System owns state the recording writes.

**The parsimonious shape is a `derivs` that returns rather than stores.** If
nothing on the System held a recorded value, the active System would be immutable
during a recording, hold no slots, and be built once per sweep instead of once per
step. That is "prefer pure functions, returns over mutations" applied to the one
place in this design where it is worth 7 s.

**The same call pays a second time.** `Patch::ad_parameters()` walks every
species and every strategy to build a `std::vector<value_type*>`, and
`state_and_parameter_adjoints` calls it per recording as well -- so the parameter
layout, which is fixed for the whole sweep, is rebuilt 3,381 times beside the
System it belongs to.

⚠️ It is a large change: `Internals` is read far beyond `derivs` — census metrics
read `auxs`, and the R layer reads both. The narrow form is to reset the active
System's recorded members rather than rebuild the whole object, which keeps the
guarantee and pays for a fraction of the copy.

**The narrow form has landed, and so has the parameter list.** Both come off one
`lifted_system` held for a range of constant width, and every recording releases
its members' slots before clearing the tape. Worth 3 to 4 per cent, all of it the
allocation; the release itself is 8 ms of a 108 s gradient. What stands here is the
first paragraph -- the System still owns the values a recording writes, which is
why anything has to be released at all, and that is `one-reverse-pass.md`'s step 9.

### 4. One fact, three representations: the refusal channel

The sharpest thing reverse mode added, and the one that costs a reader most.
"This row could not be recorded" is represented three ways:

| representation | where | shape |
|---|---|---|
| `record_report{whole, at, why}` | odelia `implicit_node.hpp` | returned value |
| `gradient_refusal` | plant `gradient_refusal.h`, 52 lines | **thrown exception** |
| `*uptake_rows_unavailable`, `*uptake_rows_reason` | plant `tf24_strategy.h` | **two latched `shared_ptr`s** |

The exception is thrown at two sites, both inside `record_leaf_outputs`, and
caught at two sites in `scm.h` — where it is immediately unpacked into
`struct refusal`, a plain value type declared **in the same header as the
exception**. So a value becomes an exception and becomes a value again two frames
later.

**What it unwinds through is the problem.** `record_leaf_outputs` runs inside
`derivs`, inside `whole_step`, inside `vector_jacobian_product` — with a tape
active and a recording open — then out through `state_and_parameter_adjoints`,
`step_adjoint`, `solve_adjoint` and `solve_adjoint_over_insertions` before plant
catches it. It crosses odelia's entire sweep stack, and odelia carries two RAII
guards to survive it: `tape_guard`, which deactivates the tape on any exit, and
`restore_on_exit` in `sweep.hpp`, whose comment is
*"THE WIDTH ON EXIT IS A PROMISE, AND A THROW IS AN EXIT."*

**The latch is shared state for the same reason.** `uptake_rows_unavailable` and
`uptake_rows_reason` are `shared_ptr`, copied in `assign_from` so the double
strategy and its rebound active copy see one flag. A returned value would need no
sharing; the `shared_ptr` is the tell that the channel is wrong.

Why two escapes at all: an exception costs every output, the latch costs only the
water rows and lets profit survive by the envelope theorem. That distinction is
real. It is a **severity**, and it is encoded as two mechanisms instead of one
value with a scope.

**The lean shape is one refusal, returned.** The latch already survives the places
a return cannot reach, so the exception is the redundant half — and removing it
takes with it a header, an exception type, the unwinding through a live tape, and
most of `restore_on_exit`'s reason for existing.

⚠️ **Three of `refusal`'s five fields are never written.** `node`, `step_first` and
`step_last` are declared `-1` and nothing assigns them; `species` is set at one
site. All five cross to R in `census_gradient_to_r`, so a caller inspecting a
refusal is handed three fields that are permanently `-1` and look like
information. The header's comment describes the mechanism that would fill them —
*"the leaf knows the reason, the block loop knows which plant, the sweep knows
which steps ... filled in by the frames that know"* — as though it exists.

### 5. Diagnostic counters threaded through the production stack

Five counters — `recorded_rates`, `clamp_counts`, `operating_point_counts`,
`leaf_placements`, `boundary_condition_evaluations` — each carry a member, an
accessor at every layer they pass through, a clear method, and an R export. **All
of them reach R only through `gradient_ladder.cpp`**, which is test-only surface.
None is read by `census_gradient.cpp` or by `R/`.

`recorded_rates` is the pass-through case: it is a member on `Step`, forwarded by
`ode_solver_internal.hpp` as a getter and a clearer, forwarded again by
`ode_solver.hpp`, then renamed by `scm.h` to `boundary_condition_evaluations()`
before it is exported. Four layers, each repeating the same method with the same
argument, and a rename at the top so a reader has to learn both names.

**One of them is in the hot path, and that is the part worth acting on.**
`clamp_counts()` builds a fresh `std::vector<std::size_t>` — it copies the leaf's
tally and folds the supply's into it — and `record_leaf_outputs` calls it
**twice per call**: once as `clamps_before`, once inside `note_leaf_clamps`, on
the throwing exit as well as the normal one.

`record_leaf_outputs` runs once per differentiated leaf evaluation. The fixture
reports 2,333,500 placements, but those are counted in `solve_leaf` rather than
here, so the two are not proven equal — they are the same path and the same
order, which puts this at **millions of vector allocations and copies inside the
production gradient, for a number no product path reads.** The exact multiple
wants measuring before anyone quotes it.

What the delta buys is stated in `clamp_sites.h`: the leaf solves in double on
both paths, so which path a clamp fired on is a question of when, and the answer
comes from a difference taken across `record_leaf_outputs`. But the difference
accumulates into a **per-site total** — the per-placement granularity is not in
the answer. Bracketing the whole gradient gives the same per-site attribution for
two calls instead of 4.7 million.

⚠️ **The counters themselves are worth keeping.** `placements()` says so in its own
comment: a record that engages and one that quietly does not produce the same
numbers, so the count is the only thing that tells them apart. The target is the
threading and the granularity, not the instrument.

### 6. A result that carries how it was computed, and pays for it twice

`competition_split` is what a species' light reduction hands back, and three of
its members are not the answer:

```cpp
bool closes{false};      // whether the closing trapezium is taken at all
bool from_loop{false};   // false when a short path returned before the loop
bool unordered{false};   // the sorted-view fallback, which splits no further
```

They record **which branch produced the value**, so that
`close_competition_and_slope` can decide what to do with it. One of those
decisions is to do the work again:

```cpp
// in compute_competition_and_slope_split
if (!birth_date && !scan.decreasing) {
  c.unordered = true;
  c.excl = compute_competition_and_slope_unordered(height, false);   // full reduction
  return c;
}

// in close_competition_and_slope
if (c.unordered) {
  return compute_competition_and_slope_unordered(height, true);      // full reduction again
}
if (!c.from_loop) { return c.excl; }                                 // never reached from above
```

`compute_competition_and_slope_unordered` evaluates every node at the height,
builds a `(abscissa, f, slope)` vector, **sorts it**, and reduces. Running it
twice differs only in whether the boundary node is included — and the first
result, `c.excl`, is unreachable on that path because `close` tests `unordered`
first. **The excluding reduction is computed and thrown away, then the including
one is computed from scratch: an O(n log n) pass wasted per query.**

The cause is one return type serving two cases that are not the same shape. The
ordered path genuinely has a split — the comment earns it: holding the partial
reduction lets the field with the boundary interval be formed from the field
without it in one operation. The unordered path **has no split at all**, so it
fills the same struct with a finished answer and a flag saying so.

Two shapes, or a variant, and nothing is computed twice and the three booleans
have nothing left to say.

⚠️ **Reachability.** The reverse pass requires the birth-date coordinate, so
`!birth_date` is false there and this branch does not fire on a gradient. It fires
on ordinary runs of the models that do not use that coordinate, which is where
`compute_competition_and_slope` is hottest.

### 7. `vector_jacobian_product` is a boundary that hides nothing — DONE

The transpose takes its own recording. It registers the state as this recording's
own inputs and the parameters where they sit on the System, so the flat vector,
the copy loop that wrote the parameters back out of it, the `n_seed x (n_state +
n_parameter)` scatter and the seam between the two halves are all gone -- and with
them the hazard `ode_step.hpp` warned about, that slicing past the state reads
parameter values as state. The seed-and-sweep loop the two shared is one internal
helper. `vector_jacobian_product` keeps its flat shape for the one thing that
wants it, the ladder's block Jacobian, and therefore joins entry 8's list.

What it was:

`state_and_parameter_adjoints` calls it, and that is the only production call —
the other is `gradient_ladder.cpp:312`, test-only. Of its five arguments, three
pass straight through (the tape, the seeds, the callable). The layer's entire
contribution is to splice and unsplice:

```cpp
std::vector<double> in(state);                 // state ++ parameters, per recording
for (const scalar* p : parameters) in.push_back(util::to_passive(*p));
...
adjoint_rows in_adjoint;
vector_jacobian_product(tape, in, output_adjoints, record, in_adjoint);
state_adjoint.assign(n_seed, n_state);         // and scatter the answer back out
for (m) { copy(row.begin(), row.begin()+n_state, state_adjoint[m].begin());
          for (p) parameter_adjoint[m][p] += row[n_state + p]; }
```

The splice exists because the inner function insists on **one flat input vector**.
Nothing else wants that shape: its one production caller immediately un-flattens
the answer. The tape registers inputs individually in any case, so the flat vector
is ceremony — paid once per recording, which is 3,381 times a sweep, as an
`n_state + n_parameter` build and an `n_seed x (n_state + n_parameter)` scatter.

A boundary earns its keep by hiding a decision. This one hides a concatenation.
Merged, the tape lifecycle registers the state and the parameters as what they
are, sweeps once per seed, and reads each adjoint into the batch it belongs to —
and `in`, `in_adjoint`, the copy loop and one function's guards all go.

### 8. odelia's sweep header has no production consumer left — SHARPENED

`sweep.hpp` is **100 lines behind two entry points, and both are oracle-only.**
`solve_adjoint_over_insertions` became `Solver::solve_adjoint`, which also absorbed
the constant-width inner loop, and `be_at_step` and `insertion_rows` moved to
`ode_interface.hpp` where a recording's readers live. What remains --
`state_at_segment` and `advance_over_insertions` -- is reached only from
`census_trait_tangent`, `replay_initial_state`, `segment_base_state` and
`census_initial_state_replay`, all of which are the ladder's references.

So the question this entry asked has a cleaner answer than it expected: the header
is not half oracle, it is entirely oracle, and it goes where the four oracles go.

What it was, when it was 300 lines behind five entry points:

| entry point | consumer | product |
|---|---|---|
| `solve_adjoint_over_insertions` | `census_trait_gradient` | yes |
| `be_at_step` | both sides | yes |
| `advance_over_insertions` | `census_trait_tangent`, `replay_initial_state` | **oracle only** |
| `state_at_segment` | `segment_base_state`, `replay_initial_state` | **oracle only** |
| `rates_adjoint` (`adjoint.hpp`) | plant's `rhs_adjoint` | **oracle only** |
| `vector_jacobian_product` (`adjoint.hpp`) | the ladder's block Jacobian | **oracle only** |

`rates_adjoint` and `vector_jacobian_product` are the sharpest: both are public
odelia API, and its
one caller is `gradient_ladder.cpp:71`, which is test-only surface in another
package. The production sweep does not go through it at all — `solve_adjoint`
reaches `step_adjoint`, which records a whole six-stage step rather than one rate
evaluation.

plant's side splits the same way. `SCM`'s public gradient family is
`census_trait_gradient` and `census_state_and_trait_rows` on the product side,
against `census_trait_difference`, `census_trait_tangent`,
`census_initial_state_replay` and `segment_base_state` on the oracle side — which
is item 11's "four oracles in `scm.h`'s public interface", confirmed here by
reachability rather than by the comment that claims it.

**So the ladder's cost is not only in plant.** It reaches into odelia's public
headers, and the two packages hold up each other's assurance.

### 9. The recording's pieces are a domain object that is not one

This is the symptom of the split above, and it is worth fixing whatever happens to
the oracles.

A recording of m insertions has m + 1 pieces of constant width. That fact is
re-derived at **three** sites in `sweep.hpp` — lines 99, 146 and 259.
`n_piece = steps.size() + 1` is written twice, the `piece_last` lambda is written
twice with an identical body, and the paragraph explaining the scheme —
*"One piece per width, lowest first: piece j runs from the insertion below it to
the one above, and the outermost two reach the recording's ends"* — appears
**verbatim twice**.

`insertion_steps` carries a comment arguing against making it a structure:
*"Derived where it is used rather than built into a container: two subtractions
read more easily than a vector of pairs whose endpoints are shared between
neighbours."* The code has since falsified that. Two subtractions became two
lambdas, a count, and a duplicated paragraph, at three sites.

`pieces(rec)` returning `[first, last]` ranges removes all of it, and the
off-by-one lives in one place. Two of the three derivations are in the
oracle-only functions, which is why it went unnoticed.

⚠️ **`recording-and-sweep.md` item 9 says `state_segments(rec)` "already *is* that
resolution, computed once by the driver".** No such function exists in plant. The
item's premise is stale, and anyone starting from it will look for a thing that
was never built.

### 10. The ladder's shipped surface

`plant/src/gradient_ladder.cpp` is 797 code lines behind **28 `Rcpp::export`
entry points, every one of which is referenced only from `tests/`.** They are
compiled into `plant.so` and named in `RcppExports` so the ladder can reach them.
By contrast the four exports in `census_gradient.cpp` are all read by `R/` or
`inst/`, which is what a product surface looks like.

This is the number `recording-and-sweep.md` item 11 asked for: not where the
instrumentation lives, but how much of it is still earning its keep. The study it
sets out — for each ladder file, what would fail if the assertion were deleted,
and is there a cheaper referee for the same defect class — now has a size.

⚠️ **Three of these assertions have caught real defects**, and item 11 names them:
`declared-zero` in both directions, `identity`'s bit-for-bit split, and
`recruit`'s inflow boundary. A rung that is *more sensitive than the end-to-end
check at a seam* is not a candidate. Rungs that only localise a failure the
end-to-end check already catches are.

### 11. The role taxonomy, left behind by the row layer — DONE

In `phylloptim/inst/include/phylloptim/inputs.hpp`:

- `input_role(int, int)` has **no callers anywhere** — one mention in a comment
  and its own definition.
- `parameter_role(int)` is read by one `static_assert` and nothing else.
- `InputRole` and `par_entry::role` exist to serve those two.

The `static_assert` says why it is there: *"`rows_at` defaults every row to NA and
the recording refuses a non-finite derivative by name, so an unclaimed input fails
safe."* **`rows_at` is gone** — it went with the row layer, and now appears only in
three comments, in `inputs.hpp` twice and `gradient.hpp` once. `input_role` was
last touched by `2ba6f98`, the deletion commit itself.

So the check guards a mechanism that no longer exists, and the classification it
checks has no reader. `par_entry`'s name field stays: `par_table` is read by
`leaf_model.hpp`, and `n_pars`, `par_ref`, `OutputRole`, `OutputValues` and
`n_outputs` all have real consumers.

Removed: `InputRole`, `parameter_role`, `input_role`, the `static_assert` and the
`role` field. `par_entry` went with them -- one `string_view` in a struct is a
`string_view` -- so `par_table` is now `std::array<std::string_view, 16>`. The two
comments still citing `rows_at` are corrected. `test_leaf` 1114/0.

### 12. `closed_form.hpp` — checked, and it is not a target

123 code lines reached only from `test_leaf.cpp`, which is what put it on this
list. It comes off again: `PLAN.md` §9 is an open item carrying measured speedups
(10.8x for the power-law route, 47x for the explicit beta2 form), a design
decision that reads "one Newton step is deliberate, do not improve it", and a
question still open on the realised speedup. "Not wired in" means not yet.

⚠️ **Tests-only reachability does not distinguish dead from unfinished**, and this
is the case that shows it. The check that separates them is whether a plan item
still carries open work, not whether the code has a caller.

### 13. The 993 long comment blocks

Mechanical trimming would delete the one paragraph that was load-bearing. This is
a per-file reviewable pass, and the hazard blocks are not part of it.

### 14. Smaller things reading turned up

- **`with_insertions` copies the whole recording to patch a handful of entries.**
  `solve_adjoint_over_insertions` builds `std::vector<record>` from the entire
  recording so it can overwrite the `steps.size()` entries an insertion widened.
  A century run is 3,381 records each holding a state vector; the number that
  changes is the insertion count.
- **`inserted_state` both mutates and reports.** It sets the system's state, pushes
  the nodes, and writes the widened state to an out-parameter.
  `advance_over_insertions` wants only the mutation and allocates an
  `ode_size()`-wide vector to throw the report away. Same shape as the leaf's
  `E_from_soil_at`, where three of four callers discard the per-layer split.
- **`step_adjoint` copies the state half at the active scalar** — `y0(x, x + size)`
  — which is one tape slot, operation and statement per entry, once per recorded
  step. Real, and small: about half a per cent of a step's recording, against the
  leaf's 273 statements per placement across 169 nodes.
### 15. Hand-rolled root-curve derivatives with no production consumer

The objective's own target, still standing. A four-function chain computes
d(uptake)/d(a root-curve parameter) in closed form — Euler's identity and the
incomplete gamma's shape series, per the comment:

| function | lines | file |
|---|---|---|
| `dE_from_soil_droot_curve` | 21 | `leaf_model.hpp:1395` |
| `duptake_droot_curve_by_layer` | 12 | `roots.hpp:1090` |
| `d2uptake_dpsi_droot_curve` | 68 | `roots.hpp:1263` |
| `duptake_droot_curve_impl` | 58 | `roots.hpp:1017` |

**159 lines, and the only thing that reaches them is `test_leaf.cpp`.** The row
layer was their consumer and it is deleted. The `SupplyCurveTrait` alias exists to
give the top of the chain a parameter type and has no other use.

The distinction that matters, since `roots.hpp` is full of `d...` functions:
`dE_from_soil_dpsi_collar`, `duptake_dpsi`, `d2uptake_dpsi2` and
`dE_from_soil_dpsi_soil` **are production** — the wet bound's slope reads the
first, and `CurveReads` reads `root_vuln_integral_dtrait`. Only the root-curve
branch is orphaned.

### 16. Seven row types that outlived the row layer

Each of these appears exactly once in the tree — its own declaration. Nothing
constructs one, returns one, or names one as a parameter, including inside
`leaf_model.hpp` itself:

`UptakeRows` (33), `PhotoTraitRows` (47), `CollarRows` (21), `CostTraitRows` (17),
`ConditionCurvature` (16), `HydraulicCostRow` (13), `TransportTraitRows` (5), and
the `TransportTrait` enum beside them.

**152 lines, in one contiguous band at `leaf_model.hpp:1143-1306`** plus
`HydraulicCostRow` at 1715. They are the row layer's vocabulary, and `2ba6f98`
deleted the layer without them.

### 17. `leaf_solved_points` is two objects wearing one type

The record of operating points a run's leaf solves found carries five pieces of
state — `kept`, `slot`, `solved`, `placed` and `filling` — and `filling` decides
which half of the interface does anything:

```cpp
Leaf::SolvedPoint next() {
  if (filling || slot == nullptr || solved >= slot->size()) return Leaf::SolvedPoint();
  ...
}
void keep(const Leaf::SolvedPoint& point) {
  if (filling && slot != nullptr) slot->push_back(point);
}
```

`keep()` does nothing unless filling; `next()` does nothing if filling. So the
type is a recorder and a player fused by a boolean, and every caller of either
half is relying on a mode it did not set. `end_stage()` clears `slot` and `solved`
and leaves `filling` alone, so the two can disagree.

Two types make the halves unavailable to the wrong caller and delete the flag,
the branch in `next()` and the branch in `keep()`. It is the guide's own
scattered-boolean example, one level up: the fix is not a `ReplayMode` enum, it is
that a recorder has no `next()`.

⚠️ **The count is the only thing that can tell a record engaging from one quietly
not**, per `placements()`'s own comment: every number a placement produces is the
number a search produces. Whatever replaces this keeps that counter.

### 18. Two curve stores, written twice

`MultiLayerRoots` and `Leaf` each carry a per-thread store of built vulnerability
curves, and they are the same object:

| | roots.hpp | leaf_model.hpp |
|---|---|---|
| cache entry | `CurveCache` | `StemCurveCache` |
| bound | `curve_cache_size = 32` | `curve_cache_size = 32` |
| store | `static ... curve_store()` | `static ... stem_curve_store()` |
| member | `curve_cache_` | `stem_curve_cache_` |
| lookup | linear scan on `(b, c, resolution)` | linear scan on `(b, c, resolution)` |

Both are `thread_local shared_ptr<vector<Entry>>` returned from a static, both are
keyed on the same three doubles, both carry the same reasoning in reworded
comments — *"the key determines the value completely ... rebinding to another
scalar does, per cohort per stage, rebuilt the curve every time"* — and one of
them points at the other: *"The root curve keeps its own beside its splines, in
`roots_`."*

One `curve_store<Entry>` serves both. Both copies are this branch's, so this is
ours to fix rather than main's.

⚠️ **The bound is load-bearing and easy to lose.** 32 is not arbitrary: past the
pairs a perturbation loop visits, an entry is never read again, so an unbounded
store is a leak rather than a hit. Whatever replaces these keeps the bound and
keeps it in one place instead of two.

### 19. Two return values smuggled out on the object

`census_trait_gradient` returns `census_gradient`. It also produces two other
things and has nowhere to put them, so they are members:

```
scm.h:414   size_t adjoint_segments = 0;
scm.h:420   std::vector<std::vector<double>> adjoint_at_first_state;
```

Each is written in **four places** — cleared in `reset()`, cleared again at the
top of the gradient, set inside the `try`, cleared once more in the `catch` — and
read in exactly one: `gradient_ladder.cpp`, which is test-only surface.

For a cold reader this is the worst kind of confusion, because it is
indistinguishable from the good kind. You meet `adjoint_segments = 0` at the top
of a function that returns something else, and nothing local tells you whether it
is lifecycle state, a cache, or an output. Finding out means reading the rest of
the file and then both export files.

Both belong in `census_gradient`, where the caller that wants them can read them
off the value — and eight write sites and two members go with the move.

### 20. A stage address threaded six layers to reach a vector index

`Step::step_adjoint` forms `recorded_stage{step, i}` and hands it to `derivs`. It
arrives, six frames later, as two subscripts:

```
derivs(sys, y, dydt, t, at)
  internal::set_ode_state(obj, y, t, at)      if constexpr (RecordsChoices<T>)
    Patch::set_ode_state(it, t, at)           if constexpr (KeepsSolvedChoices<S>)
      strategy->begin_stage(at, recording)    ← the mode flag joins here
        leaf_points->begin_stage(at, keeping)
          kept[at.step][at.stage]
```

Two concepts exist to route it, two overloads of `set_ode_state` exist to carry
it, and `TF24_Strategy::begin_stage` is a pure forwarder to `leaf_points`.

**The flag it collects mid-journey is the worse half.** `Patch::recording` is a
public `bool` with a setter, defaulting false, forced false in `assign_from`, and
read only here. Whether it is correct depends on which pass the caller is running,
nothing validates it, and its two states select which half of `leaf_solved_points`
is live — entry 17. So the address says *where* and a mutable public flag four
frames up says *what to do there*, and neither is checked against the other.

The destination is a slot in a nested vector. A record that knows the stage it is
being asked about needs the address; it does not need six frames to receive it,
and it certainly does not need the mode to arrive separately.

⚠️ **`set_ode_state` has three arities across sixteen definitions**, and plant adds
`set_recorded_state` and `set_state_and_boundary` beside them. Six spellings of
"load the state", two of them selected by concept. That is the vocabulary a
maintainer has to hold before reading a single rate evaluation.


## Checked and rejected

**Reusing the adjoint step's stage scratch.** `Step` keeps `k` and `ytmp` as
members so the forward step allocates nothing, and its tape is a member "reused by
every step a sweep walks". `step_adjoint` allocates its equivalents — `y0`, six
rate vectors and a stage vector — fresh on every recording, which looks like the
same optimisation waiting to be applied.

⚠️ **It is not.** Active scalars held across a tape clear are exactly the hazard
`adjoint.hpp` documents: clearing returns the slot counter to zero, so a scalar
still holding the last recording's slot is handed the same number as something
else in this one and their adjoints add together. The locals are deliberate, and
resetting reused ones to passive costs a write per element — which is what
constructing them already does.

The reason is stated in `adjoint.hpp` and paid for in `ode_step.hpp`, which is why
it reads as an oversight at the site.


## Noted, out of scope

**The trait gradient is written twice, in two languages, under a bit-for-bit
contract.** `gradient.hpp` describes itself as a transcription of `R/gradient.R`,
and the agreement costs a `volatile`-based `rounded()` to defeat fused
multiply-add plus a rule that every difference names its halves first, because C++
does not sequence `f(a) - f(b)` and R does. Both files are on main. It is the
largest remaining instance of the pattern the leaf work removed, and it is listed
here so that it is not rediscovered a third time.

## How these were found, and two ways that do not work

Both failed lenses were tried on this tree and produced confident nonsense.

**Counting uses outside the defining file reports normal structure as dead.** In
header-only code most helpers are file-local by design, so the count is zero for
functions that are doing exactly what they should. Run across the three packages
it produced 29, 56 and 85 candidates, nearly all of them false.

**A name's absence from a count is not death.** `InputRole` scored zero external
uses and is load-bearing inside its own file. The finding above needed the
*consumer chain* traced instead: who reads the thing that reads it, and does that
reader still exist.

What worked: public surface reachable only from tests, and a taxonomy whose reader
was deleted. Both are questions about consumers rather than about counts.

## What is left open

- The forward model runs about 2.9% slower on this branch than on
  `ad/v3-forward`, reproducibly, and nothing explains it. Per-thread curve stores
  were the first hypothesis and are ruled out: reference-count symbols total
  0.05 s across a whole profile.
- `tests/cpp/golden/operating_points.tsv` is stale against two deliberate
  refinements and must be re-blessed on macOS/arm64. The blast radius is measured
  and the cause bisected; regenerating anywhere else moves the failure to the
  platform the file came from.
