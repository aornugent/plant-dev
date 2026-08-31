# The two paths a maintainer reads

**Delivered, bar one item.** Read the next two sections. Everything from "The
objective" down is the record of how each item closed, kept because it says why a
shape is what it is.

## Where this got to

The competition field build and the node-introduction gradient cost too much to read.
Seven of the eight items below are closed. What that bought:

| | |
|---|---|
| **the representation** | a junction is a row of its own, so `inserted`, `ran_from()`, `pending`, the head instruction's junction bit and `solve_adjoint`'s whole stop-list-and-range arithmetic are gone. `one-program` is fully landed |
| **the schedule** | holds introductions -- `{time, species}` in a sorted vector walked by a cursor -- where it held one event per species-time pair and rebuilt the grouping twice. Ten names out, −250 lines |
| **the value/slope pair** | one type, `with_slope<T>`, where seventeen spellings crossed thirteen frames |
| **the widening event** | two words, one per package: `insertion` in odelia, `introduction` in plant, with the boundary in one line. `junction`, `widening` and `segment` gone |
| **the counters** | stay, and the comment justifying them was the thing that was wrong |
| **the ladder's surface** | one self-justifying loop out at −198 lines; the rest stays because the member is the only route past a private |
| **the three free names** | there were none |

Both records are closed on everything this objective reached: `subtraction-targets.md`
is 16 of 24 closed, `unification.md` 6 of 10, and every remaining entry in either is
named at the end of this document as out of reach.

Every increment was verified against the same three numbers, unchanged throughout
except where a test was added or removed and the delta was predicted first: **odelia
346/0, plant's gradient ladder 554/0 over fifteen files, plant's non-ladder suite
3330/0.**

## What is left

**One item from this objective**, and it is item 7 below:
`compute_environment` means three things in one call chain -- the ordering that breaks
the fixed point (`patch.h`), a one-line forward (`tf24_environment.h`), and the knot
loop (`resource_spline.h`). The forward is the obvious first casualty. It was left
deliberately, not blocked.

**One entry still on this objective's theme**, `unification.md` 7: `extra_stops`, a
test-only parameter in a production signature. It is the last survivor of lens 4's
cause, and odelia's ranged `solve_adjoint` overload already gives the same split check
without it -- so the shape of the answer is likely "delete the parameter, keep the
check", but that has not been tested.

**Ordinary subtraction, not vocabulary**, in `subtraction-targets.md`: 22 (two
parameters declared, exported and never wired), 18 (two curve stores written twice),
21 (nine aux slots the differentiated path writes and nobody reads), and 14's last
sub-item (`step_adjoint` copies the state half at the active scalar). Each is
self-contained and none needs this document.

**Priced and refused, or not a change:** 3 (the System's deep copy), 8 (`sweep.hpp`,
sharpened rather than actionable), 1 (the residue in `scm.h`'s gradient surface).
`unification.md` 1 finishes in `one-order.md`, which is landed bar a memo of three; 5
and 10 there are small pairs.

**A separate axis this objective never touched: the prose and the test suite.**
`subtraction-targets.md` **13** is now audited rather than estimated -- 28 named comment
violations with the surviving fact written out for each, and the finding that two of
AGENTS.md's own rules ban this domain's vocabulary. **25** is new and is the test
suite. ⚠️ **It opens with two live holes rather than anything to subtract**: a ladder
bound that admits the defect its test exists to catch
(`test-gradient-ladder-rung4.R`, the `abs(ratio - 1) < 0.5` in "a trait is one input
read by every cohort"), and a gate block that cannot execute while the suite is green
(`test-gradient-parity.R`, the `if (r$refused)` arm). Both are verified.

The list above is the whole of what is open across both records, so an absence from it
is closure rather than an oversight -- the counts at the head of
`subtraction-targets.md` and `unification.md` are the check. `one-order.md`'s memo of
three unbuilt items is the one thing recorded elsewhere; it is named at the end of this
document.

## A loop worth keeping

Three things made a 68-site change tractable against 20-minute package builds, and a
new session should set them up before starting:

* **A private R library** (`R_LIBS` prepended, `PLANT_TEST_LIB` for the runner), so
  another session installing odelia cannot move the headers under a measurement.
  AGENTS.md hazard 4.
* **A syntax-only loop.** One TU that includes plant's competition path and explicitly
  instantiates it at TF24 for both `double` and the tangent scalar, compiled with
  `-fsyntax-only`. Thirty seconds, and it finds every member-access error a rename
  causes. It cannot check FF16 or K93, which carry no AD surface and whose explicit
  instantiation demands members the package never instantiates -- the package build
  covers those.
* **Standalone probes** for anything about the tape or the walk.
  `odelia/tests/standalone/probe_visit_active.cpp` is twenty lines and settled a
  question two documents had argued in prose.

---

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

**2a. ~~A quantity and its vertical derivative, spelled six ways.~~ DONE**, and it
was seventeen, not six. `plant::with_slope<T>` with members `value` and `slope` now
carries it: 32 anonymous `std::pair` declarations, 36 `.first`/`.second` reads and the
four named members `tot`/`tot_slope`/`f_h1`/`s_h1`, across nine files and three
strategies.

⚠️ **The caveat above was wrong on both halves.** `Q_and_q` has no out-parameters --
it returns `std::pair<S, S>` by value and always has. The comment it was remembering
belongs to **`crown_moments`**, forty-five lines away, and is the real constraint
worth carrying: *"a returned array of active values copies each one, which with a
tape active is a recorded operation apiece."* A two-member struct returned by value
costs what the pair cost, so there was nothing to avoid.

⚠️ **The sign convention turns over, and nothing said so.** `Q_and_q`'s second member
is `q = -dQ/dz`; all three strategies then return `-(scale * Qq.second)`, so
everything above them carries the *signed* derivative -- which is what
`build_extinction_field`'s `m[k] = -(m[k] * E)` chain rule requires. Six sites said
"slope" and none said which. It is on the type now, once.

**What did not move, and why:**

* **`Q_and_q` keeps `Q` and `q`.** They are the model's names for two quantities it
  takes from one `u^eta`, and forcing them into a generic value-and-slope would hide
  the flip the strategies make on purpose. The list below already said it earns its
  name.
* **`y`/`m` stay parallel arrays**, at four sites. `resource_spline.h:41` gives the
  reason -- the reduction "is linear in the nodes plus the knots and quadratic only if
  it is asked per knot" -- and `tf24_environment.h`'s `cohort_reads` flattens the knot
  pair into `[values..., slopes...]` as a **wire format** whose order indexes recorded
  blocks. Array-of-structs would change the serialisation.
* **`"light_availability"`/`"slope"` stay.** They are R matrix column names, read by
  string in nine test files, `tidy_outputs.R` and `FF16_report.Rmd`. And
  `r_compute_competition_and_slope`'s value-then-slope order is an unnamed positional
  contract in R. Renaming members is free; reordering is not.

⚠️ **The rename would have dropped four active scalars off the tape audit in
silence**, and this is the finding worth keeping. `visit_active` opens a `std::pair`
by looking for `.first` and `.second`, and its own comment says a shape it does not
list "IS SKIPPED, NOT REFUSED". A struct named `{value, slope}` matches no branch.
Measured, not reasoned about -- `odelia/tests/standalone/probe_visit_active.cpp`:

```
  std::pair<double,double>        0   <-- no longer opened
  struct {value, slope}           0   <-- skipped, no error
  the same with for_each_active   2
  for_each_active over an unnamed 0   <-- skipped one level down
  double[2]                       1   <-- matches the POINTER branch
```

So `with_slope` declares `for_each_active`, and `competition_split` hands over the
pairs rather than their members. The probe also shows a raw C array reaching only its
first element; no active raw array is on a walk today, so that one is recorded and not
chased.

### Where this surface lives, and what asking moved

`visit_active` and `active_system::release` are odelia's -- the walk and the audit.
`for_each_active` is odelia's contract with **eleven of its thirteen implementations
in plant**; phylloptim has none, being forward-mode and tapeless. `with_slope` is
plant's, correctly: a competition value and its height slope is plant's model
vocabulary, and odelia's own value-and-slope is knot *arrays* (`nodes_and_data`,
`interpolator::y`/`m`), a different shape with a different owner.

**The `std::pair` arm of `visit_active` is gone.** It was not merely dead -- it was
never reachable. At the plant commit that introduced every `visit_active` call, not
one of the ten argument lists was a pair, and the frame that became
`competition_split` already handed over `tot, tot_slope, f_h1, s_h1` as four separate
scalars so it would not need the arm. odelia wrote it to keep a capability the same
commit's callers had already stopped using. The one route by which it could have gone
live is closed: `strategy.h`'s two `std::map` members would yield pairs if iterated,
and no `for_each_active` hands them over.

⚠️ **There is no compile-time refusal to add here, and this is worth writing down
because it looks like there is.** The obvious fix -- refuse a class that declares
nothing -- would break the build: `FF16_Strategy`, `K93_Strategy`, `FF16_Environment`
and `K93_Environment` declare no `for_each_active` and are skipped **correctly**,
being non-templated and `double`-only. From inside the template a class holding
actives and a class holding none are the same shape. What reports a miss is
`active_system::release`, counting slots the walk did not reach -- a guard reporting a
number, which is the form this codebase already prefers.

⚠️ **And those four skips rest on a fact nothing asserts.** They are safe only while
FF16 and K93 stay `double`-only. Template either on `S` and both become live wrong
answers with every number finite, and `release()`'s count is the only thing that would
say so. Not a defect today; a tripwire with no wire.

**Net +5 lines of code**, plus a forty-line header that is mostly the two paragraphs
above. Seventeen spellings became one name and the sign got written down; lines were
never the metric.

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

**3a. ~~Five diagnostic counters, each threaded through every layer it
crosses.~~ CLOSED, and the surface stays.** Held to this lens's own test -- can the
ladder reach what it needs from outside the production headers? -- four of the five
answer no, and the fifth already reaches directly.

* **`recorded_rates` / `boundary_condition_evaluations`: no route.** `SCM::solver`
  is private, and so are `Solver::solver` and `SolverInternal::stepper`. Three
  barriers, and opening any of them widens the production interface to narrow it
  somewhere else. The two names are also not one number under two labels: the plant
  one asserts the boundary is evaluated once per rate evaluation, which is the claim
  `test-gradient-ladder-first-range.R` pins with `expect_equal(counts$evaluations,
  stages * steps)`. They never coexist in one R session -- `recorded_rates` reaches R
  from odelia's tests only, the other from plant's only.
* **`clamp_counts`: no, in substance.** The accessor does a saturating subtraction --
  the leaf keeps one tally across both scalar paths, so the forward share is the total
  less the measured sweep share -- and folds two owners onto one row. That is
  knowledge about how the tallies are kept, which is the product's, not the test's.
* **`operating_point_counts`: reachable, but the live read is the only uniform one**
  (below).
* **`leaf_placements`: already direct.** `gradient_ladder.cpp` sums it off
  `r_patch()` itself, which is the shape the others would take.

⚠️ **The comment that justified the threading was half wrong, and it is the finding
worth keeping.** `scm.h` said `r_patch()` "is a snapshot the run copies out and whose
counters are whatever they were when it was taken". Verified:
`Species::strategy_ptr() const` returns the `shared_ptr` **by value**, so a copied
`Patch` shares one strategy with the live one and every strategy-owned tally
*aliases* -- which is why the ladder already reads `leaf_placements()` straight off
`r_patch()`. But `environment_type environment;` is a `Patch` member by value, so
that half is a real copy, and a sweep advances the live one afterwards through
`be_at_step`'s `compute_environment`.

So reading the live system is right for a narrower reason than the comment gave: it
is the one rule that covers both halves. The comment now says that, and sits beside
what it describes -- it was two functions above it.

**Three things did go:**

* `clear_operating_point_counts` is **`clear_diagnostics`**. It clears five tallies --
  operating points, the strategy's clamps on both paths, the leaf's and its root
  model's, the curvature margin, the environment's -- and two tests depend on the
  bundling, so the bundling is right and the name was a lie by omission.
* `add_environment_clamps` is **private**. It was `public static` with both callers
  inside the class.
* The misplaced comment moved to the function it describes.

**No lines came out of the product, and that is the answer.** The threading is what
the assurance layer needs and the product is the only place it can be reached from.

**3b. A test-only parameter threaded into the production sweep.** `extra_stops` is
`{}` from the product and real only from the ladder. `unification.md` 7.

# 4. The assurance surface inside the production surface -- CLOSED

Counted: `gradient_ladder.cpp` was **783 code lines behind 34 `Rcpp::export` entry
points, 30 referenced only from `tests/`**, and the record's figures were exact. Held
to this lens's own test -- can the ladder reach what it needs from outside the
production headers? -- most of it stays, and one closed loop came out.

**4a. One self-justifying loop, and it was the whole of what was free.**
`Patch::assign_from` -> `ladder_rebind_matches_assign_tf24` -> `test-rebind-assign.R`,
and nothing else: the only caller of the product member is the export that verifies
it, whose only caller is the test. Its declaration claimed a production use -- "it is
assigned before every recording rather than once per step" -- so it was checked rather
than taken: odelia's `Rebindable` concept requires only `rebind_from<U>()`, odelia's
headers never name `assign_from`, and the strategy's and environment's `assign_from`
are different methods called by their own `rebind_from`. The two docs mentioning it are
historical, recording a flag whose clear used to live there, so no plan item wanted it.

**−198 lines**, and the drift the test caught becomes *unstateable* rather than
checked: with one route to another scalar there is nothing left to disagree. Also out:
`Patch::node_count`, whose one caller sat beside `locate()`'s identical walk.

**4b. The eleven injection members stay -- movable, but not a win.**
`unification.md` 8's members all pass the access test: `TF24_Environment` has no
`private:` at all, so the ladder could poke `light_availability` and `psi_soil_`
itself. But the cost the entry attributes to them does not move with them. The
`psi_soil_valid_` latch exists so injected potentials survive a read, and a ladder that
sets the flag itself still needs the flag and still needs the staleness scan on the hot
path. That cost is bought by removing the block rung, which is a question about whether
the rung earns its keep, not about surface.

**4c. Already done.** The two values no longer ride on the object: they are fields of
the `census_gradient` return (`ranges`, `at_first_state`), set by one call and read off
the value. And `at_first_state` has since become *product* surface, read by
`census_gradient.cpp`.

**What stays, and why it is not indirection.** All thirteen `SCM::*` ladder members:
`SCM::solver` and `SCM::patch` are private and `r_patch()` is const, so no expression
from outside reaches them. `Patch::introduction_jacobian`: its body needs
`species[i].remove_newest_node()`, and `Patch::species` is private with only a const
`at_species`. `Patch::apply_insertion`'s four-argument form: the production overload
requires it.

⚠️ **Two bugs of this objective's own making, found here.** The `segments` -> `ranges`
rename checked plant's `tests/` and `src/` and not `scripts/`, so
`profile-stand-gradient.R` and `profile-stand-reverse.R` were left reading
`counts$segments` -- `NULL`. The reverse script had a three-way fallback whose other
two arms named things that no longer exist, with a `tryCatch` turning all of it into a
silent `NA`. **A rename is not done when the package compiles.**

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

## ~~Free, and each removes a word~~ NONE OF THE THREE WAS FREE

Grepped, which is what "free" was supposed to mean. Each fails for a different reason,
and the list was the cheapest item on the plan.

| name | site | what it is actually reached from |
|---|---|---|
| `Patch::introduction_jacobian` | `patch.h:239`, `:1393` | live: `gradient_ladder.cpp:824` -> `ladder_introduction_jacobian_tf24` -> `test-gradient-ladder-rung5.R:172`. Oracle-only, and the warning below was already there |
| `Solver::solve_adjoint`, 4-arg ranged | `ode_solver.hpp:290` | **it is the implementation.** The whole-recording overload at `:393` delegates to it, and `scm.h:1056` calls that. "Zero production callers" is false transitively |
| `quadrature_abscissae` | `species.h:330` | `species.h:983` -> `refinement_error_by_node()` -> `scm.h:690` inside `refine_schedule`, which `run_scm(refine_schedule = TRUE)` reaches. A production path, not an R diagnostic |

⚠️ **Oracle-only is not dead.** `introduction_jacobian` is what the ladder checks the
transpose against. Price the check before the function. That caveat was written here
and was right; the other two rows had no caveat and needed one.

**The lesson is the one already in `principles.md`, arriving on its author.** "'Free'
means unreferenced, and unreferenced means grepped. A plan's cheapest items are the
ones its author did not verify." Three rows, one grep each, three wrong -- and the
cheapness is what stopped anyone checking.

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
3. ~~**The value/slope pair as one type**~~ **DONE** (2a). Seventeen spellings, not
   six, and the caveat guarding it was wrong twice over.
4. ~~**The counters**~~ **CLOSED, surface stays** (3a). Four of five have no route
   out of the production headers and the fifth already reaches directly; what was
   wrong was the comment saying why.
5. ~~**The three names with no caller.**~~ **CLOSED -- there were none.** One is a
   live oracle, one is the sweep's own implementation, one is on the schedule
   refinement path. See the table above.
6. ~~**One word for the widening event**~~ **DONE** (2b) -- two words, one per package, with the boundary in one line.
7. **`compute_environment`'s three meanings** (2c) -- at minimum, the forwarder.
8. ~~**The ladder's surface**~~ **CLOSED** (4a–4c). Mostly the surface stays, as
   predicted; one self-justifying loop came out at −198 lines, and 4c was already
   done.

## Also open, and not reached by this objective

**Named once, in "What is left" at the top of this file**, together with the item
this objective still owes. There were two lists of the same open entries here and they
had already drifted -- this one called `unification.md` 9 open after it resolved, said
item 1 had not taken 6 when item 2 had, and omitted four entries that were open. Two
lists that can disagree is the thing this whole document is about.

`one-order.md`'s memo is the one addition: the height family, `pushAll`'s block form,
and widening the transpose identity past four of twelve kinds. Recorded and unbuilt.

## The rule this list is an instance of

**A codebase adds names well and retires them poorly.** Every item in lens 2 is a
second spelling that outlived its first; every item in lenses 3 and 4 is a need that
outlived the reason it was threaded. None was wrong when written.

So the check that generalises is not "is this dead" -- `subtraction-targets.md`
already asks that -- but **"is the thing this replaced still here?"**, and **"does the
product's interface carry this, or only the test's?"** Both are cheap at the end of an
increment and expensive a year later.
