# One vocabulary

**The live plan.** Everything else in this directory is either the rules
(`principles.md`) or a record of work that has landed.

## The objective

The competition field build and the node-introduction gradient are the two paths a
maintainer has to read, and they are overbuilt. Not slow, and not wrong: the ladder
holds them and the numbers are right. **They cost too much to read**, and every
change to them is priced at that cost.

Measured, by counting the invented words a reader must learn to follow one call end
to end -- a type, function, member or alias whose meaning cannot be guessed from
general C++, ODE or ecology knowledge:

| | competition field | introduction gradient |
|---|---|---|
| coined names | **78** | **66** |
| files to open, once, to a leaf | 8 | 10 |
| deepest call chain | 13 frames | 13 frames |
| names with exactly one call site | 19 | 12 |

Seven names are shared, so the union is **137 distinct coined names across 20 files
in two repositories.** That is the number this document exists to bring down.

⚠️ **Rank by names removed, not by lines.** A deletion that removes no word from a
reader's head has not made the path easier to read. The four items below are ordered
by how many words each retires.

## What is necessary, so nothing here proposes deleting it

About a third of the vocabulary encodes something the model forces. It is listed so
that a later pass does not price it as residue:

* **The canopy math** -- `Q`, `q`, `Q_and_q`, `eta_c`, `pow_eta`. Yokozawa's profile
  and its vertical derivative. `Q_and_q` earns its own name by taking both from one
  `u^eta`.
* **`competition_split` and the two-stage build.** It breaks a real fixed point --
  the field depends on the boundary node, which depends on the field -- *and* it
  keeps the build out of quadratic time. Two jobs, both real.
* **The slot protocol** -- `for_each_active`, `visit_active`, `release_slot`,
  `release`. `release`'s counter is the only thing in the tree that can say "this
  System holds an active value the walk does not reach".
* **`update_dependent_aux`** -- the dispatch point, and the only writer of the two
  cached auxiliaries. Inlining it makes `compute_competition` read a stale
  `area_leaf`.
* **`check_state_layout`** -- the only enforcement of a slot-order claim about fifty
  readers make.
* **The recording protocol** -- `apply_insertion`, `junction`, `be_at_step`,
  `step_adjoint`, `adjoint_rows`.

---

## 1. One concept, six spellings: a quantity and its vertical derivative

The competition path carries one thing -- a value and its slope in height -- and
spells it six ways:

| spelling | site |
|---|---|
| `std::pair`'s `.first` / `.second` | `plant/inst/include/plant/node.h:276` |
| `tot` / `tot_slope` | `species.h:86` |
| `f_h1` / `s_h1` | `species.h:87` |
| `y` / `m` | `patch.h:995`, `resource_spline.h:199` |
| `Q` / `q` | `canopy_shape.h:169` |
| `"light_availability"` / `"slope"` | `resource_spline.h:155` |

Five files, and the reader learns the pairing five times. **One named type with two
named members, used at all six sites.** It is the highest-value change on this list
because it is the quantity the path is *about*: every frame of the 13 carries it,
and today every frame renames it.

⚠️ **The type has to reach the AD boundary.** `Q_and_q` is on the hot path and its
out-parameters exist so a taped copy is not made; the replacement must keep that,
which means a struct of two scalars taken by reference, not a returned pair. Check
tape statements either side, not wall time.

## 2. One event, five names

The widening -- a species gaining a node -- is named five times across two layers:

| name | layer | site |
|---|---|---|
| `introduction` | plant, the schedule | `patch.h:138` |
| `insertion` | odelia, the map | `ode_interface.hpp:530`, `insertion_rows` |
| `junction` | odelia, the recording | `ode_interface.hpp:171` |
| `segment` | the sweep's range | `census_gradient.h:46` |
| `stop` | the descent's split | `ode_solver.hpp:308` |

`segment` and `stop` are ranges rather than the event, so they are not duplicates.
**`introduction`, `insertion` and `junction` are one event named three times**, and
a reader crossing the plant/odelia boundary has to hold all three and the mapping
between them.

The word that survives should be the one the *model* uses: a schedule introduces a
species. `junction` is the recording's word for the same thing and was coined to
distinguish an authored fact from an inferred one -- that distinction is real, but it
is a property of the row, not a different event.

## 3. `compute_environment` means three different things in one call chain

| frame | site | what it does |
|---|---|---|
| `Patch::compute_environment` | `patch.h:966` | the three-stage ordering that breaks the fixed point |
| `TF24_Environment::compute_environment` | `tf24_environment.h:770` | a one-line forward to `build_extinction_field` |
| `ResourceSpline::compute_environment` | `resource_spline.h:46` | lay out knots, call the functor once, install |

A reader following one call meets the same identifier at three frames doing three
unrelated jobs. The middle one is a pure forwarder and is the obvious first casualty;
the other two want names that say which is the ordering and which is the knot loop.

## 4. Names with no caller

Free, and each removes a word:

| name | site | reached from |
|---|---|---|
| `Patch::introduction_jacobian` | `patch.h:1392` | the ladder oracle only -- no library caller at all |
| `Solver::solve_adjoint`, 4-arg ranged overload | `ode_solver.hpp:290` | **zero** production callers; one odelia R test |
| `quadrature_abscissae` | `species.h:327` | an R error diagnostic, off the field path |

⚠️ **Oracle-only is not dead.** `introduction_jacobian` is what the ladder checks the
transpose against, so removing it removes a check. Price the check before the
function: the question is whether the ladder still has a reference for that map
without it.

---

## Two smaller ones, recorded so they are not rediscovered

* **`recorded_step` versus `step_record`** (`ode_interface.hpp:165` and `:190`) --
  the same two words swapped, differing by inheritance. Hostile to a reader and to
  grep.
* **`refusal` / `recorded_refusal` / `why` / `reason`** -- one identifier is both a
  free function (`scm.h:36`) and a `shared_ptr` member (`tf24_strategy.h:1096`), and
  the thing it holds is `why` at one site and `reason` at the next.

## What the census also found, which is not vocabulary

**`one-program.md`'s substitution landed and the representation it replaced did
not.** `recorded_step::junction` is authored where the width changes; `inserted` and
`ran_from()` are still there, and `ran_from()` exists to pick between them:

```cpp
const state_type<System>& ran_from() const {
  return inserted.empty() ? state : inserted;
}
```

That is steps 4 and 6 of that document's landing order, which it says are one
increment and cannot land apart. **What blocks them is one fixture**, not the
restructure: the insertion transpose sits behind `if (lo < hi)`, so on a fixture
introducing at t = 0 a skipped transpose is unobservable, and `ladder_stand_resumed`
is the only fixture where that range carries steps. A second fixture is small, and it
is what makes the restructure safe to attempt.

## The rule this list is an instance of

**A codebase adds names well and retires them poorly.** Every item above is a second
spelling that outlived its first: a pair renamed per file, an event renamed per
layer, a verb reused per class, a function whose caller went. None of them was wrong
when written.

So the check that generalises is not "is this dead" -- `subtraction-targets.md`
already asks that -- but **"is the thing this replaced still here?"** Ask it at the
end of every increment, and it is cheap; ask it a year later and it is this document.
