# The two paths a maintainer reads

**The live plan.** Everything else in this directory is the rules (`principles.md`)
or the record.

## The objective

The competition field build and the node-introduction gradient are the two paths
anyone changing this code has to read, and they are overbuilt. Not slow and not
wrong -- the ladder holds them and the numbers are right. **They cost too much to
read**, and every change to them is priced at that cost.

Four lenses. The first is structural and the deepest -- it *removes* names rather
than renaming them. The last explains much of the second.

---

# 1. The representation: a trajectory is a composition of maps

`one-program.md` is this objective, stated structurally, and it is the one document
here with outstanding work. The domain is an ordered sequence of operations -- step,
or junction. The code models it as an ordered sequence of *states* with a field
hinting at where a junction was, and **`sweep.hpp`, `NodeSchedule` and the piecewise
sweep are all downstream of that one substitution.**

**LANDED.** `recorded_step` is `instruction`, carrying `{time, step_size, kind}`,
and a junction is a row of its own holding the state its map produced. The
substitution stopped being paid for twice. What went:

```cpp
state_type<System> inserted;            // a second state, on 169 of 3,381 rows
const state_type<System>& ran_from() const {
  return inserted.empty() ? state : inserted;   // picked which half was live
}
const bool pending = from_segment == 0 && rec[start].junction;   // scm.h
```

`ran_from()` was a function whose only job was to choose between two spellings of one
fact, and `pending` a bool recording how much of one instruction someone else had
already run. Both are the shape `principles.md` names. With `solve_adjoint`'s
`stops`, `lo`, `hi`, its two ternaries and `if (lo < hi)`, they are gone.

⚠️ **One part of the spec was deferred, and item 2 took it.** `schedule()` filters
junction rows, which is what let the per-interval replay stand unchanged while the
row landed; `distribute_ode_steps` then went with the schedule rewrite, so there is
one recording again. What is still open is `Parameters` holding the program as two
parallel vectors -- the shape `instruction` exists to refuse.

⚠️ **Two claims here were wrong, and the second reorders the list.**

The transpose does *not* sit behind `if (lo < hi)`. It runs at
`ode_solver.hpp:367`, above that guard and independently of it, under its own
condition (`j < stops.size() && rec[hi].junction`); what `lo < hi` skips is the
**step sweep** of an empty range. What is
actually thin is downstream: where a junction sits at the range's first row nothing
below it is swept, so that transpose's output reaches a caller only as
`at_first_state`, which one test reads.

And **the second fixture cannot be built.** Steps below the first widening are only
a check if cohorts are alive there: on bare ground that state is the environment
alone, and its census sensitivity is twelve orders below the state one range up, so
a walk that skipped those steps reads as a walk that took them. Cohorts there need a
seeded state consuming the schedule's early entries -- which is
`ladder_stand_resumed`'s own mechanism, so any second fixture is that one
re-parameterised. Built and measured one: same widening count, same position, only a
narrower start. It was deleted rather than kept.

**So de-risking comes from the split identity instead** (`extra_stops`, already
there): the adjoint is the same whether or not the descent is cut, which is exactly
an index-arithmetic check and does not depend on a fixture's shape.

# 2. One concept, many names

Counted: an invented word is a type, function, member or alias whose meaning cannot
be guessed from general C++, ODE or ecology knowledge.

| | competition field | introduction gradient |
|---|---|---|
| coined names | **78** | **66** |
| files to open, once, to a leaf | 8 | 10 |
| deepest call chain | 13 frames | 13 frames |
| names with exactly one call site | 19 | 12 |

Seven are shared, so the union is **137 across 20 files in two repositories.**

**2a. A quantity and its vertical derivative, spelled six ways.** `.first`/`.second`
(`node.h:276`), `tot`/`tot_slope` (`species.h:86`), `f_h1`/`s_h1` (`:87`), `y`/`m`
(`patch.h:995`, `resource_spline.h:199`), `Q`/`q` (`canopy_shape.h:169`),
`"light_availability"`/`"slope"` (`resource_spline.h:155`). Five files, and it is the
quantity the whole path is *about*: every one of the 13 frames carries it and every
frame renames it. **One named type with two named members, at all six sites.**

⚠️ It has to reach the AD boundary. `Q_and_q`'s out-parameters exist so no taped copy
is made; the replacement is a struct of two scalars taken by reference, not a
returned pair. Check tape statements either side, not wall time.

**2b. ~~One widening event, three names across two layers.~~ DONE.** It was
`introduction` (plant's schedule), `insertion` (odelia's map), `junction` (the
recording) and `widening` (the prose everywhere). Now **two, one per package**:
`insertion` is odelia's word for the map and for the row that applies it;
`introduction` is plant's word for the scheduled event; and the boundary is one line
in `r_store_trajectory`, which reads `rec[i].insertion` and reports it as
`introduction`. `widening` survives only as a verb -- "the run widened", "a widening
System" -- which is English about the state, not a name for the event.

⚠️ **And this entry got one thing wrong**, which is worth keeping because the error
is the general one. It said *"`segment` and `stop` are ranges rather than the event,
so they are not duplicates"* -- true, and it stopped there. They are not duplicates
of the *event*; `segment` and `range` were duplicates **of each other**, one idea for
the span between two insertions, spelled both ways inside odelia and crossing into
plant's R surface as `segments`. The tell was sitting in the tests, which read the
field into a differently-named variable:

```r
unsplit_ranges <- unsplit$segments      # the translation layer, written by hand
ranges         <- counts$segments
```

`range` is now the only spelling: `state_at_range`, `range_base_state`, `from_range`,
and `ranges` in the R return. **Checking whether a name duplicates the thing you are
looking at will not find the pair that duplicates each other.**

**2e. ~~One grouping, derived three times.~~ DONE.** The domain is "a sorted
sequence of introduction times, each naming a set of species", and the schedule now
holds exactly that: `struct introduction { double time; std::vector<size_t> species; }`
in a sorted vector, walked by a position rather than consumed as a copy.

`set_times` groups once, where it used to flatten to one event per (species, time)
and throw the grouping away. `SCM::run_next`'s `while (true)` drain loop, which
re-derived it by walking equal times off a back-filled sentinel, is six lines of
straight code. `Patch::introduced_at` still derives it a third time, but the two
representations now agree on species order, where the schedule was the patch's
reverse.

Gone with the flattening: `NodeScheduleEvent` and the `NodeSchedule::Event`
typedef; the `queue` that was a consumable copy of `events`; `Event::times`, always a
two-element vector used as a pair; `Event::steps`; `time_introduction()`;
`species_index_raw`, which reported the same number as `species_index` counted from
zero instead of one; `distribute_ode_steps`; and both list iterator typedefs. Ten
names, and with them an R class carrying five actives.

`time_end` survives, on the schedule rather than on every event, because it always
was "the next introduction's time, or `max_time`" and now says so once. And which
recorded steps fall inside an interval is arithmetic at the point of use
(`program_within`) rather than a copy made per interval on `reset()`, so there is
nothing left that can be stale.

⚠️ **The argument for the `std::list` is already void**, which is what makes this
cheap. `add_time` takes an insertion-point iterator, threaded to it through
`set_times`, and overwrites it on the next line:

```cpp
NodeSchedule::add_time(double time, size_t species_index, events_iterator it) {
  Event e(time, species_index);
  it = events.begin();          // node_schedule.cpp:306 -- the hint, discarded
  while (it != events.end() && time > it->time_introduction()) { ++it; }
```

So every insert was already a scan from the front, and `next_event()` returned by
value, so no iterator escaped the class.

**Landed at −30 hand-written lines and −209 generated**, against a −85/−95 estimate:
the hand-written half came out smaller because `program_within`, the grouping insert
and the duplicate guard are new code. Lines were never the point -- ten names were.

Two things it turned up that the pricing did not:

* **`r_set_max_time` read `events.back()` on an empty list.** `make_node_schedule`
  and `node_schedule_default` both call it on a freshly built schedule, before any
  time is set, so every `SCM` construction in the package ran that. Now guarded on
  emptiness.
* **A species introduced twice at one time is refused where it happens.** It used to
  reach `check_birth_dates_distinct` as a duplicate birth date, one layer away from
  the schedule that allowed it.

**2c. `compute_environment` means three things in one call chain.** The ordering that
breaks the fixed point (`patch.h:966`), a one-line forward (`tf24_environment.h:770`),
and the knot loop (`resource_spline.h:46`). The forward is the obvious first casualty.

**2d. Two smaller ones.** `recorded_step` versus `step_record` -- the same two words
swapped, differing by inheritance, hostile to grep. And `refusal` is a free function
(`scm.h:36`) *and* a member (`tf24_strategy.h:1096`), holding a thing called `why` at
one site and `reason` at the next.

# 3. Signals threaded to reach one reader

**3a. Five diagnostic counters, each threaded through every layer it crosses.**
`recorded_rates`, `clamp_counts`, `operating_point_counts`, `leaf_placements`,
`boundary_condition_evaluations` -- a member, an accessor at each layer, a clear
method and an R export apiece. `recorded_rates` is a member on `Step`, forwarded by
`ode_solver_internal.hpp`, forwarded again by `ode_solver.hpp`, then **renamed** by
`scm.h` before export, so a reader learns two names for one number crossing four
layers. `subtraction-targets.md` 5 has the full accounting.

**3b. A test-only parameter threaded into the production sweep.** `extra_stops` is
`{}` from the product and real only from the ladder. `unification.md` 7.

# 4. The assurance surface inside the production surface

**4a.** `plant/src/gradient_ladder.cpp` is **783 code lines behind 34 `Rcpp::export`
entry points, 30 of them referenced only from `tests/`** -- `subtraction-targets.md` 10.

**4b. Production headers carry a fifth state vocabulary** so the ladder can inject a
state and read a block Jacobian -- `unification.md` 8.

**4c. Two return values with nowhere to go**, so they ride on the object:
`adjoint_segments` and `adjoint_at_first_state` at `scm.h:414` and `:420` --
`subtraction-targets.md` 19.

---

## The cause, stated once

**The assurance layer's needs are carried in the production interfaces of both
paths.** Every counter in 3a reaches R only through a test-only file. The parameter
in 3b is `{}` in the product. The fifth vocabulary in 4b exists so a test can inject.

That is also where a large share of lens 2 came from: a name coined for the ladder,
living in a production header, is a name the next reader of the product must learn.
**Names are the symptom; this is the cause worth fixing.**

⚠️ **The ladder is not the problem and must not be weakened.** It is the only thing
that holds these paths, and it has caught real defects. The question is not whether
it checks, but whether the product's interface has to carry what it checks *with*.
The test is: can the ladder reach what it needs from outside the production headers?
Where the answer is no, the surface stays and the entry closes.

## What the model forces, so nothing here proposes deleting it

* **The canopy math** -- `Q`, `q`, `Q_and_q`, `eta_c`, `pow_eta`. `Q_and_q` earns its
  name by taking both from one `u^eta`.
* **`competition_split` and the two-stage build.** It breaks a real fixed point --
  the field depends on the boundary node, which depends on the field -- *and* keeps
  the build out of quadratic time.
* **The slot protocol** -- `for_each_active`, `visit_active`, `release_slot`,
  `release`. `release`'s counter is the only thing that can say "this System holds an
  active value the walk does not reach".
* **`update_dependent_aux`** -- the dispatch point, and the only writer of the two
  cached auxiliaries.
* **`check_state_layout`** -- the only enforcement of a slot-order claim about fifty
  readers make.
* **The recording protocol** -- `apply_insertion`, `junction`, `be_at_step`,
  `step_adjoint`, `adjoint_rows`.

## Free, and each removes a word

| name | site | reached from |
|---|---|---|
| `Patch::introduction_jacobian` | `patch.h:1392` | the ladder oracle only -- no library caller |
| `Solver::solve_adjoint`, 4-arg ranged | `ode_solver.hpp:290` | **zero** production callers; one odelia R test |
| `quadrature_abscissae` | `species.h:327` | an R error diagnostic, off the field path |

⚠️ **Oracle-only is not dead.** `introduction_jacobian` is what the ladder checks the
transpose against. Price the check before the function.

## Order

Ranked by words removed from a reader's head, not by lines.

1. ~~**`one-program` steps 4 and 6**~~ **DONE.** A junction is a row; the doubled
   representation and the range arithmetic went with it. It deferred part (c), which
   item 2 then took. **Still open from it:** `Parameters` holds the program as
   `ode_times` and `ode_step_sizes`, two parallel vectors -- the shape `instruction`
   exists to refuse, and the last place the program is spelled the old way.
2. ~~**The introduction schedule, grouped once instead of derived three times**~~
   **DONE** (2e). It took item 1's part (c) with it: `distribute_ode_steps` is gone,
   so the per-interval copy of the recording is gone, and `program_within` computes
   an interval's replay where it is used. `unification.md` **6** is closed.
3. **The value/slope pair as one type** (2a). Bounded, mechanical, five files, and it
   is the quantity every frame carries.
4. **The counters** (3a). Five signals × four layers, and none of them reaches the
   product. The largest threading item in either path.
5. **The three names with no caller.** Free.
6. ~~**One word for the widening event**~~ **DONE** (2b) -- two words, one per package, with the boundary in one line.
7. **`compute_environment`'s three meanings** (2c) -- at minimum, the forwarder.
8. **The ladder's surface** (4a–4c), gated on the test above. The largest item and
   the one most likely to end in "the surface stays".

## Also open, and not reached by this objective

Left in the record rather than pulled forward, so nobody reads their absence here as
closure. Each is real; none of them is what makes these two paths hard to read.

* `subtraction-targets.md` **1** (residue: `scm.h`'s gradient surface, already down
  from 247 lines to 210), **3** (the System's deep copy -- priced, largely refused),
  **13** (993 long comment blocks -- a per-file reviewable pass), **18** (two curve
  stores written twice).
* `unification.md` **5** (built once per step, constant across the sweep), **9**
  (four caches), **10** (smaller pairs). **6** (two recordings of one run) is reached
  by item 1 but was not taken by it -- see that item.
* `one-order.md`'s memo: the height family, `pushAll`'s block form, and widening the
  transpose identity past four of twelve kinds.

## The rule this list is an instance of

**A codebase adds names well and retires them poorly.** Every item in lens 2 is a
second spelling that outlived its first; every item in lenses 3 and 4 is a need that
outlived the reason it was threaded. None was wrong when written.

So the check that generalises is not "is this dead" -- `subtraction-targets.md`
already asks that -- but **"is the thing this replaced still here?"**, and **"does the
product's interface carry this, or only the test's?"** Both are cheap at the end of an
increment and expensive a year later.
