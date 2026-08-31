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

Steps 0-3 landed: `recorded_step` carries `{time, step_size, junction}`, the flag is
authored where the width changes, and the executor is one call at 12 lines where it
was 30. **Steps 4 and 6 are outstanding and are one increment**, and until they land
the substitution is paid for twice:

```cpp
bool junction = false;                  // authored, ode_interface.hpp:171
state_type<System> inserted;            // a whole state vector, at 169 of 3,381 rows
const state_type<System>& ran_from() const {
  return inserted.empty() ? state : inserted;   // picks which half is live
}
```

`ran_from()` is a function whose only job is to choose between two spellings of one
fact. That is the shape `principles.md` names: a value deciding which half of a type
is live means there are two types.

⚠️ **What blocks it is one fixture, not the restructure.** The insertion transpose
sits behind `if (lo < hi)`, so on any fixture introducing at t = 0 a skipped
transpose is unobservable, and `ladder_stand_resumed` is the only fixture where that
range carries steps. `one-program.md` says a restructure of the range arithmetic
should not go in against one fixture, and it is right. **A second fixture is small,
and it is the whole of what stands in front of the last increment.**

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

**2b. One widening event, three names across two layers.** `introduction` (plant's
schedule, `patch.h:138`), `insertion` (odelia's map, `ode_interface.hpp:530`),
`junction` (the recording, `:171`). `segment` and `stop` are ranges rather than the
event, so they are not duplicates. A reader crossing the boundary holds all three and
the mapping between them.

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

1. **A second fixture that introduces after t = 0 with steps in the range** (1).
   Small, and it is what stands in front of `one-program`'s last increment -- which
   is the only structural item on this list.
2. **`one-program` steps 4 and 6**, once that fixture exists: `inserted` and
   `ran_from()` go, and the substitution stops being paid for twice.
3. **The value/slope pair as one type** (2a). Bounded, mechanical, five files, and it
   is the quantity every frame carries.
4. **The counters** (3a). Five signals × four layers, and none of them reaches the
   product. The largest threading item in either path.
5. **The three names with no caller.** Free.
6. **One word for the widening event** (2b), across the plant/odelia boundary.
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
* `unification.md` **5** (built once per step, constant across the sweep), **6** (two
  recordings of one run), **9** (four caches), **10** (smaller pairs).
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
