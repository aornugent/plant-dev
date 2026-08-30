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

⚠️ **Three of the TWELVE `tests/cpp/probe_*.cpp` no longer compile** —
`probe_curve_order`, `probe_curve_tables` and `probe_slope_rules`, 356 lines. The
Makefile builds them from no target, so nothing noticed. A probe that does not
compile is not a measurement anyone can repeat.

Re-checked: the other nine build clean. The three fail for two reasons, both a
signature that moved under them -- `cumulative_vulnerability_integral` grew a seventh
out-parameter, and the `odelia::spline` namespace no longer exists. Six orphan
binaries with no source also sit in that directory.

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
   ├─ (gone: ✱C — both are fields of the returned census_gradient)
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

~~**✱ D — the refusal channel, three times in one function.**~~ DONE. One
value, cleared once and polled twice. Entry 4.

~~**✱ E — the Patch is deep-copied per recording**~~ **STALE for entry 3's reason:**
the active System is now built once per constant-width range and once per widening,
not once per recorded step.

~~**✱ F — a splice into a flat vector that the one caller immediately unsplices.**~~
DONE. Entry 7 — the splice is the transpose's, not the reduction's, and this
pointed at 6 through a renumbering.

**✱ G — `trait_adjoint` is not an adjoint when it is created.** It is seeded with
the direct term, for a stated and good reason, and the name says none of it.

**✱ H — five words for one idea.** `insertion`, `widening`, `piece`, `segment` and
`with_insertions` all describe the same thing: a place where the state got wider.
`sweep.hpp` uses *piece*, `scm.h` uses *segment* (`census_gradient::segments`,
`segment_base_state`), the function is named `over_insertions`, and the failure
mode is called a widening. A reader has to discover that these are one concept.

Four of the five are gone since: *insertion* absorbed `with_insertions`, *stop*
absorbed `split` (`extra_splits` → `extra_stops`), and *piece* went with
`sweep.hpp`'s collapse. *widening* survives in comments only, so `segment` -- in
plant's diagnostic -- is the one word left, not a pair.

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
               │        ├─ collar_at   → implicit_value  (the collar's own residual)
               │        │    marginal_at → marginal_assembled, at FReal<AReal>   ✱ M
               │        └─ outputs_at
               │           ├─ profit_at → implicit_value ×2  (sigma, ci)
               │           │    each with a forward tangent for its own slope
               │           └─ E_from_soil_at   (the quadrature)
               ├─ resource_depletion  ← a local, produced and drained here   ✱ N
               └─ env.compute_rates(resource_depletion)
```

**✱ J — nine allocations per recording, and they have to be there.** Reusing them
across recordings is the stale-slot hazard; see "Checked and rejected".

**✱ K — a `{step, stage}` pair threaded six layers to index a nested vector**, and
it picks up a second argument on the way. See entry 20.

**✱ L — the three-arity load calls the two-arity load.** So a recorded step loads
the state twice as far as the reader is concerned: once to announce the stage,
once to set the values.

~~**✱ M — a nested scalar, still, in the other order.**~~ **STALE, and the shape it
prices is gone.** `xad::fwd`, `FReal` and `fwd<` return zero hits across
`leaf_model.hpp`, `roots.hpp` and `gradient.hpp`; `marginal_assembled` is templated on
plain `T` and its own comment says there is no order above `T` in the marginal. The
11.6%-of-gradient cost below described a construction that no longer exists. What it was: The second TAPE is gone with
`collar_condition`: the collar's residual now composes on plant's own tape. But
`marginal_assembled` takes its two kernel slopes with `xad::fwd<T>::active_type`,
so at the gradient it runs at `FReal<AReal<double>>` -- a tangent above the
adjoint, whose value AND derivative both record onto plant's tape, and which is
then swept once per metric. Measured at 11.6% of the gradient and about 60% of
increment 2's cost; `one-program.md` has the profile. The nesting was not removed,
it was inverted and inlined, and it does not grep as what it is.

~~**✱ N — `resource_depletion` is a Patch member used as a per-call scratch**,
reserved, filled, and cleared at the end of `compute_rates`, with
`//todo do we need to clear this every step?` beside the clear. In a function on
the recording path, a member whose lifecycle carries a question mark is state that
a reader cannot reason about locally.~~ DONE, as a local.

`one-reverse-pass.md`'s constraint table lists this under what `derivs` writing
into the System generates -- "a produced-then-drained buffer has no scope" -- and
says not to cut there. That is right about `Internals`'s rates and auxs, and
**wrong about this one**: it was cleared at the end of the call that filled it, so
it was already scoped to that call and only its capacity outlived it. A local
gets the same capacity from one small reserve per rate evaluation, answers the
TODO by construction, and makes the exception path safe rather than guarded --
a refusal thrown between the fill and the clear used to leave active values on a
Patch across a tape reset, which is why `for_each_active` had to visit it.
Deleting it from that walk is the tell that the member was the problem: the walk
existed to cover a window a local does not have.

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
| ~~`collar_condition` and `against` — the second-order pass~~ gone | 48 |
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

`d2E_from_soil_dpsi_collar_dpsi_soil`, `dE_from_soil_droot_carbon`,
`dE_from_soil_droot_curve`, `d2uptake_dpsi_dpsi_soil`,
`d2uptake_dpsi_droot_curve`, `duptake_droot_curve_by_layer`.

⚠️ **Three have come off this list and the reasons differ.**
`d2E_from_soil_dpsi_collar2` now has a LIVE production consumer --
`Leaf::marginal_collar_slope` reads it, and the gradient runs that. `duptake_droot_carbon`
and `duptake_droot_curve_impl` have shipped-header consumers that are themselves dead
(`bound_row`, entry 15), so they are compiled-but-unreachable rather than unreferenced.

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
`implicit_value` for the stem potential, the intercellular CO2, both bounds and
now the collar itself, `record_with_derivatives` under all of them, plus
`to_passive`, `seed_direction` and `derivative_along`.

⚠️ **The nested-scalar half of this no longer applies.** `collar_condition` is gone,
and with it the only consumer of `directional_adjoint_scalar`,
`directional_adjoint_tape`, `seed_inner_direction`, `directional_adjoint` and
`CarriesDirectionUnderAdjoint` -- all five are deleted, and so is
`implicit_value`'s second correction, which no production call site could reach.
What phylloptim still needs from odelia is the implicit-node surface alone.

⚠️ **So the implicit-node surface stays public.** It is not
internals of the sweep to be folded into a single entry point — they are used
inside someone else's recording, by a package that has no solver, no recording and
no sweep. A revision that hides them behind "transpose a recorded run" strands the
leaf.


## Targets

### 1. odelia offers a kit, not a reverse pass — so SCM is the assembly

**`scm.h`'s gradient surface is 210 code lines, 30% of the class** (was 247/34%),
split almost evenly between product and oracle. `census_trait_gradient` alone fell
102 -> 66. Five of the twenty odelia names plant used to reach for are now named
zero times: `scratch_tape`, `advance_over_insertions`, `solve_adjoint_over_insertions`,
`insertion_rows` and `step_adjoint`.

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

### 2. ~~The recording is incomplete on purpose~~ PREMISE FALSE

**The record now carries the widened state as a field.** `step_record` holds
`inserted` beside `state` and reports `ran_from()`, and `insertion_rows` reads a
recorded flag instead of scanning for a width that grew -- in the words this entry
asked for: *"an inference can be wrong where a recorded fact cannot"*. Of the six-row
table below, `insertion_steps`, `with_insertions` and the piece arithmetic are all
gone. What survives is `state_at_segment` (oracle-only), `restore_on_exit` (which
entry 4 flags as load-bearing on the NORMAL return) and `be_at_step`'s width check.

What it was, and the reasoning that got it fixed:

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
`active_system` held for a range of constant width, and every recording releases
its members' slots before clearing the tape. Worth 3 to 4 per cent, all of it the
allocation; the release itself is 8 ms of a 108 s gradient. What stands here is the
first paragraph -- the System still owns the values a recording writes, which is
why anything has to be released at all, and that is `one-reverse-pass.md`'s step 9.

### 4. ~~One fact, three representations: the refusal channel~~ DONE

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

**The lean shape is one refusal, returned**, and that is what landed. The latch
already survives the places a return cannot reach, so the exception was the
redundant half. It took with it the exception type, both catches, the `refused`
bool, one of the two NaN-fill sites and one of the two shared pointers. The header
is renamed for the value it holds rather than deleted, because `census_gradient`
lives in it.

⚠️ **The severity did not survive counting, and `restore_on_exit` did.** Both
consumers not-a-number every row on either escape, so the profit row the latch
spared is discarded one frame later and there is no severity for a field to carry
— `one-reverse-pass.md` step 4 has the count. And `restore_on_exit` is
load-bearing on the NORMAL return: the descent leaves the System at the lowest
range's width, and its destructor is the only thing that puts it back.

~~⚠️ **Three of `refusal`'s five fields are never written.**~~ DONE. `node`,
`step_first` and `step_last` are gone, and so are the two assertions that pinned
them: three `expect_equal(..., -1)` in a branch no parity driver reaches, and an
`expect_gte(step_last, step_first)` comparing -1 with -1. **The species is now
always known**, because every refusal is recorded on the species whose strategy
holds it.

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

~~**One of them is in the hot path, and that is the part worth acting on.**~~ DONE.
`clamp_counts()` built a fresh `std::vector<std::size_t>` — copying the leaf's tally
and folding the supply's into it — and `record_leaf_outputs` called it **twice per
call**: once as `clamps_before`, once inside `note_leaf_clamps`.

`record_leaf_outputs` runs once per differentiated leaf evaluation. The fixture
reports 2,333,500 placements, but those are counted in `solve_leaf` rather than
here, so the two are not proven equal — they are the same path and the same
order, which puts this at **millions of vector allocations and copies inside the
production gradient, for a number no product path reads.** The exact multiple
wants measuring before anyone quotes it.

What the delta buys is stated in `clamp_sites.h`: the leaf solves in double on
both paths, so which path a clamp fired on is a question of when, and the answer
comes from a difference taken across `record_leaf_outputs`.

**What went was the heap, not the bracket.** `Leaf::clamp_count(site)` already
summed the leaf's tally and the supply model's for one site, and had no caller
anywhere in the tree; reading site by site puts the whole tally on the stack — four
`size_t` — for the same numbers and the same attribution.

⚠️ **Bracketing the whole gradient instead, which this entry suggested, is wrong.**
It reads as free because the difference accumulates into a per-site total, so the
per-placement granularity is not in the answer. But `solve_leaf` also runs inside a
differentiated rate evaluation, and today it sits OUTSIDE the per-placement bracket,
so its clamps are attributed forward. A bracket around the whole gradient moves them
into the differentiated bucket: a silent change to a diagnostic, dressed as an
allocation win. `unification.md` 4 carries the same refusal for the counter merge.

⚠️ **The counters themselves are worth keeping.** `placements()` says so in its own
comment: a record that engages and one that quietly does not produce the same
numbers, so the count is the only thing that tells them apart. The target is the
threading and the granularity, not the instrument.

### 6. ~~A result that carries how it was computed, and pays for it twice~~ DONE

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

**DONE, and neither of the two shapes above is what landed.** The diagnosis holds
exactly -- `c.excl` on that path is computed and unreachable, and `close` then
reduces from scratch -- but the remedy was better than a variant. The unordered
path *does* have a split; it only appeared not to because it was doing a second
job. `abscissa_of` negates height, so the node list is ascending in abscissa
precisely while the heights decrease, and the fallback's whole task is to restore
that order:

```cpp
if (control().node_density_in_birth_date || scan.decreasing) {
  return reduce_competition(height, {});
}
return reduce_competition(height, ascending_by_abscissa());
```

One reduction, two ways to name the order, and the sort is over positions rather
than over nodes -- so the fallback evaluates no contribution to decide the order,
and a `thread_local` vector of active values left a shipped header with it. All
three booleans are gone: `closes` is `closes_on(f_h1)` written once, `from_loop`
is unnecessary because a default split closes to `{0, 0}`, and `unordered` has
nothing to say once there is one producer of the shape. `excl` is derived
(`without_boundary()`). The double pass is not fixed; **it is unrepresentable.**

See `unification.md` 3 for what the wider framing got wrong: the prefix producer
cannot feed a shared sample loop, so "one reduction, three producers" is two
producers sharing a loop and a third sharing only the shape.

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

`sweep.hpp` is **87 lines, 50 of them code, behind two entry points, and both are
oracle-only.** Re-checked: `advance_over_insertions` is gone entirely and
`program_from` has replaced it; both it and `state_at_segment` are reached only from
the four oracles, which are themselves reached only from `gradient_ladder.cpp`.
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

### 9. ~~The recording's pieces are a domain object that is not one~~ DONE

Overtaken rather than fixed as proposed: the piece concept was **deleted** rather
than made a container. `sweep.hpp` is two functions and 50 code lines,
`insertion_steps` has zero references tree-wide, and lines 99, 146 and 259 do not
exist. The ⚠️ below still stands -- no `state_segments(rec)` exists.

What it was:

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

`plant/src/gradient_ladder.cpp` is **783 code lines behind 34 `Rcpp::export` entry
points**, of which **30 are referenced only from `tests/`** and the other four also
from the umbrella repo's `scripts/`, which is instrumentation rather than product.
None is referenced from `plant/R/` or `plant/inst/`. They are
compiled into `plant.so` and named in `RcppExports` so the ladder can reach them.
By contrast the **seven** exports in `census_gradient.cpp` are all read by
`plant/R/stand_gradient.R`, which is what a product surface looks like.

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

### 12. `closed_form.hpp` — spared once, then deleted, and the difference is the point

123 code lines reached only from `test_leaf.cpp`, which is what put it on this
list. It came off again the first time: `PLAN.md` §9 was an open item carrying
measured speedups (10.8x for the power-law route, 47x for the explicit beta2
form), a design decision that reads "one Newton step is deliberate, do not improve
it", and a question still open on the realised speedup. "Not wired in" meant not
yet.

⚠️ **Tests-only reachability does not distinguish dead from unfinished**, and this
is the case that shows it. The check that separates them is whether a plan item
still carries open work, not whether the code has a caller.

**Then the plan item went, and the file with it.** §9 was a speed study *for the
finite-difference gradient*: something that solves the leaf approximately is worth
having when a gradient re-solves it 112 times per observation, and worth nothing
when the derivative is supplied. Step 1 of `one-reverse-pass.md` removed that
caller, so the open question was answered by deletion rather than by measurement --
which is what §IV of that document predicted, in those words, before it happened.

**The rule this leaves is the one above with its second half attached.** Ask whether
a plan item still carries open work, and then ask what that item is FOR. An open
question about a thing whose only consumer is being deleted is not open work; it is
work that stops existing on the same commit.

### 13. The 993 long comment blocks

Mechanical trimming would delete the one paragraph that was load-bearing. This is
a per-file reviewable pass, and the hazard blocks are not part of it.

⚠️ **`test_leaf.cpp` has a sharper version of this that is not about length: four
comment blocks sit nowhere near the test they describe.** "The supply's SECOND
collar derivative", "The two coincidences the supply refused every derivative at",
"What the operating point's condition IS" and "The three invariants that were
stated and never checked" each name exactly one test and each sits tens or hundreds
of lines above it, separated by other tests. They were already adrift before step 1
and each is still true, so they are a move rather than a trim -- which is why they
were left where they were rather than folded into a commit about deleting something
else. Four blocks that named the deleted row product went with it.

### 14. Smaller things reading turned up

- ~~**`with_insertions` copies the whole recording to patch a handful of entries.**~~
  DONE. The record carries the inserted state as a field, so nothing is copied and
  nothing is inferred.
- ~~**`inserted_state` both mutates and reports**~~ -- DONE as
  `one-reverse-pass.md`'s step 3c, and the entry was wrong about which half to
  remove. **Four of its five callers want the report**; the one that discards it is
  an oracle. So the analogy to the leaf's `E_from_soil_at` -- three of four callers
  discarding the split -- is this shape upside down, and the mutation is the
  primitive rather than the defect. What went was the allocation in the one
  discarding caller, the name (`apply_insertion`, a verb, so the widening is in the
  name and not in a comment under it), and the guard.

  ⚠️ **The mutation is why a sweep cannot share one rebound System per width, and
  that cost a segfault to learn.** Transposing this map leaves the System it ran on
  WIDER, so one rebound System handed to both the insertion at a range's top and
  the steps in it reads past the end of every state the descent then loads: ten of
  eighteen ladder files died and the rest returned NaN. It was written here as one of three
  "smaller things" and was not a step in the cut, which is how it was walked into.
  The check that would have caught it was there and asked the wrong System: the
  batch's width was compared against the System the descent positions rather than
  the rebound copy the recordings are taken on, which differ by exactly the
  mistake. It now asks the rebound one, and the rebind for a range is done by the
  function whose width it is, so the sharing cannot be written.
- **`step_adjoint` copies the state half at the active scalar** — `y0(x, x + size)`
  — which is one tape slot, operation and statement per entry, once per recorded
  step. **Priced and rejected**: 1,361 slots, statements and operations a recording,
  about 0.15%, against widening the signature of `ode::derivs`, which declares the
  state and the rates as one `StateType`. `one-reverse-pass.md` carries the price.
### 15. ~~Hand-rolled root-curve derivatives with no production consumer~~ DONE

The objective's own target, and it took two readings to size because its
reachability changed under it.

A four-function chain computed d(uptake)/d(a root-curve parameter) in closed form
— Euler's identity and the incomplete gamma's shape series. The first reading
called it 159 lines reached only from `test_leaf.cpp`. The re-check found the
line numbers stale, the chain nearer 134 lines, and one member of it —
`duptake_droot_curve_impl` — with a shipped-header caller after all,
`Leaf::bound_row`, reached from `gradient.hpp`. That caller was itself dead: the
`follow` block it sat in was only ever passed `nullptr`.

**Step 1 settled it by deleting `gradient.hpp` entirely**, and with it the last
route into the block. What went, once nothing outside tests reached any of it:
`bound_row` (136) and `BoundRow` (24); `dE_from_soil_droot_curve`,
`duptake_droot_curve`, `duptake_droot_curve_impl`, `duptake_droot_curve_by_layer`,
`d2uptake_dpsi_droot_curve`, `layer_mean_dtrait`, `SupplyCurveTrait`; the
second-order supply rows `duptake_dpsi_soil`, `duptake_droot_carbon`,
`d2uptake_dpsi_dpsi_soil` and their three `Leaf` wrappers; and `at_equal_potentials`,
whose five callers were all of them.

⚠️ **Two things this entry said were wrong, and both are the same mistake.**
`CurveReads` and `root_vuln_integral_dtrait` were grouped with the chain and are
**production** — they reach the live uptake path through `curve_reads_at` and
`cumulative_lift`, not through any `*droot_curve*` function. Reading a name for
its shape rather than tracing its callers is what put them here. Deleting a symbol
because it *looks* like the family beside it is the failure this list exists to
avoid.

⚠️ **Deleting the family orphaned two more behind it**, which nothing warned about
because both are private: `layer_mean_dtrait_dbound`, whose only caller was
`d2uptake_dpsi_droot_curve`, and `root_vuln_integrand_dtrait_dpsi` behind that.
A deletion set computed once is a snapshot; the second round is not optional.

**And one comment was falsified rather than orphaned.** `duptake_dpsi` and
`d2uptake_dpsi2` both promised NaN "where a layer's potential equals the collar,
because the mean conductivity is 0/0 there". The layer-mean rewrite made the mean
an average, so nothing refuses there — and a test asserts the value is finite at
exactly that point. Both now state what holds. A comment that survives the code it
described is worse than one that goes with it.

### 16. ~~Seven row types that outlived the row layer~~ DONE

Each appeared exactly once in the tree — its own declaration. Nothing constructed
one, returned one, or named one as a parameter, including inside `leaf_model.hpp`
itself: `UptakeRows`, `PhotoTraitRows`, `CollarRows`, `HydraulicCostRow`, and
`TransportTraitRows` with the `TransportTrait` enum beside it. About 135 lines,
mostly one contiguous band. They were the row layer's vocabulary, and the commit
that deleted the layer left them behind.

Two of the original seven had already gone by the time this was re-checked, which
is the entry's own small lesson: a list of dead things decays, and the count is
worth re-taking rather than quoting.

⚠️ **`grep -c` was wrong on one of them and would have kept it.** `TransportTrait`
returns two hits, and the second is `TransportTraitRows` — a substring of the name,
one line below. The word-boundary count is one. Whenever a name is a prefix of its
neighbour, an unanchored count reports it as live.

### 17. ~~`leaf_solved_points` is two objects wearing one type~~ DONE, as a cursor

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

**The flag is gone, and so is the store.** `leaf_solved_points` is now a CURSOR over
the list the solver hands over for the evaluation about to run: `storing` and
`loading`, at most one open, `end()` nulling both. The points themselves are
`step_record::solved` — they are part of what the run did, so they live beside the
times, the sizes and the states rather than in a second recording keyed the same way
in the other package. That took `kept[step][stage]`, its resize arithmetic and
`clear_solved_choices` with it. Which handle is open is the CONSTNESS of what was
handed over, so no mode is stored anywhere.

⚠️ **Two types would have been WORSE, and the one caller of both halves is why.**
`solve_leaf` calls them unconditionally — "place what was kept, or search; then keep
what you have" — and is correct in either pass with no branch. Splitting the type
forces that caller to learn the mode in order to hold the right half, which puts
back, at the one site that had managed without it, exactly what this removes. The
guide's scattered-boolean example still applies; the answer to "which half is live"
is which handle is open, not which type you were given.

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

**DONE.** They are `census_gradient::segments` and `census_gradient::at_first_state`.
The two members went, and so did **six clear/zero statements** (two in `reset()`,
two at the top of the gradient, two on the post-sweep refusal path) and both
`// [[Rcpp::export]]` accessors.

The zeroing did not move — it disappeared. The two values are written only on the
path that has a sweep to describe, so a refused metric leaves them at their
defaults instead of being cleared back to them. **A value written only where it is
meaningful cannot need zeroing.**

⚠️ **This was not cosmetic, and there is a receipt.** For one day the count and the
refusal disagreed: `c9aa4bed` found two refusal representations with the zeroing
attached to only one, so a refusal arriving by latch produced an all-NaN gradient
beside a live range count. A later session read that count as a regression in the
sweep and blocked a merge on it. A field beside `why` in the returned struct cannot
be reached by a caller that used a different entry point, and cannot disagree with
the verdict it is reported with. Written up in `one-program.md`.

### 20. ~~A stage address threaded six layers to reach a vector index~~ DONE

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

DONE. The address is now the extent of one rate evaluation, opened and closed by
`ode::derivs` through a scope, so the six frames are three and the two overloads of
`set_ode_state` are one. `TF24_Strategy::begin_stage` is still a forwarder to
`leaf_points`, and the two concepts both remain — each now answering its own
question rather than one routing for the other.

**And in the end there is no address**, which is this entry's complaint answered
rather than relocated. A walk hands over the list of values for the evaluation about
to run; `recorded_stage`, `Patch::recording` and the step-index parameter of both
walks do not exist. See `unification.md` 2 and entry 17.

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


### 21. Nine aux slots the differentiated path writes and nobody reads

`TF24_Strategy::compute_rates` writes seven leaf readings into `Internals::auxs` per
cohort per RK stage, plus `root_mass`, plus `area_sapwood` behind a flag. Traced
every reader of every cached index: **no rate reads them and no census metric reads
them** -- TF24's three metrics all read `vars.state(...)`, never `vars.aux(...)`.

⚠️ **But "dead" is right for only three of them, and the check that separates them is
an R one.** `plant/R/TF24_plot_diagnostics.R` is `@export`ed and plots four straight
off the tidied species table: `opt_psi_stem`, `opt_root_psi`, `profit`,
`stom_cond_CO2`. Those earn their keep through a product function.

**Genuinely unread anywhere but tests: `transpiration`, `E_up_`, `assimilation`.**
Plus `root_mass`, which is not even in a test -- zero references in `plant/R/`,
`plant/inst/`, `scripts/` or `regnans/`.

⚠️ **The cost is smaller than it looks and the entry should say so.** `leaf` is the
`double` Leaf, so `set_aux(idx, leaf.opt_psi_stem_)` constructs an `S` from a double:
passive, no tape slot, no recorded operation. What it costs is `auxs` entries copied
by every `rebind_from` and walked by `for_each_active` on every release pass.

### 22. Two parameters plant declares, exports and never wires

**`use_energy_balance`.** Declared on `TF24_Pars`, serialised to R, listed in
`undifferentiable` and in `ad_parameter_fields` -- and **never written to
`phylloptim::Leaf::use_energy_balance_`**. The only assignment to that field in plant
is the R field setter on a bare `plant::Leaf`. So the Penman-Monteith path can never
be on from a TF24 strategy or an SCM run.

**`pars.d`.** The same, and worse: `Leaf::d_` keeps its own default of `0.05`, which
happens to equal `pars.d`'s, so changing it from R changes nothing **and looks like it
worked**.

⚠️ **Each leaves a false comment behind.** `leaf_model.hpp` says the leaf's gate exists
"so TF24 (via pars.use_energy_balance) ... can turn PM on", and that `d` is "set from
pars.d in prepare_strategy". Neither is true.

⚠️ **`wind_speed_` is NOT this.** Plant does write it, from a real extrinsic driver. It
is inert one step further down: `wind_speed_` and `d_` form `ra_`, and `ra_`'s only
readers are inside the PM path that `use_energy_balance_` gates off. The driver is
plumbed end to end and its product discarded.

⚠️ **And the templated surface has no energy-balance term at all**, so wiring the gate
later would silently omit the `T_leaf(E)` channel from every recorded row. Whoever
wires it owns that.

### 23. A shipped gradient path whose one caller passes nulls

`Leaf::bound_row` (98 code lines), `Leaf::BoundRow` (24) and `gradient.hpp`'s
`FollowBound` are compiled into the package and unreachable. `bound_row` is called
only from `solved_row`'s `if (follow != nullptr)` block, and `solved_row`'s only
caller -- `gradient_fd` -- passes `nullptr, nullptr`. The `stay != nullptr` re-solve
loop beside it is dead for the same reason.

This is the entry that unblocks 15: `duptake_droot_curve_impl` and
`duptake_droot_carbon` are reachable only through here, and `at_equal_potentials`
survives only for the second-order supply-row family this is the last consumer of.

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
