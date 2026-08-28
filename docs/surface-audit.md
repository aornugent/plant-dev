# The reverse-mode surface

**What it is for.** One question: for each census metric, `d(metric)/d(trait)`
over a stand trajectory. Everything else is vocabulary for asking that once, or a
referee answering it independently.

**What generates every name in it.** Two decisions, both forced by the problem:

1. **Do not tape the leaf's solve** — recording a root-find differentiates the
   solver's iterations, not the model. So the derivative is supplied and the
   implicit function theorem is invoked by hand.
2. **Do not tape the whole trajectory** — so each step is re-run from its
   recorded state to be recorded.

There is no simpler design behind those: taping everything differentiates a
solver *and* runs out of memory. The structure is right. What has been wrong is
naming and duplication.

---

# The finding class that matters, learned late

I ran three passes looking for **one fact written in several places** — counts,
layouts, orderings. That found real defects and fixed fifteen of them. It was
blind to the more valuable class:

> **Two types holding one idea, with a function converting between them.**

`ad_role` and `gradient_status::Kind` held the same three ideas in different
words, with `ad_role_has_column` and `ad_role_zero_kind` between them — both the
identity dressed as a translation. A reader of the parameter table had to learn
twelve names to understand six. **No line count and no "same fact twice" search
could see it**, because nothing was written twice: two *different* vocabularies
were each written once.

**The detector is the converter.** A function whose body maps one enum onto
another is the signature. That, plus comparing enums by their value sets, is how
the remaining targets below were found — and it should have been the first search,
not the last.

A second shape, same family: **one enum carrying two questions.** `ad_role`
answered both "does this have a column" and "what does a zero in it mean", which
is exactly why two extractor functions existed.

---

# Next consolidation targets

Ranked by cognitive load removed. All three are the class above, found by the
detector rather than by counting.

## T1 — `Status` is a worse copy of `OperatingPointKind`, and it is the one on the R path

`Status{Interior, Pinned, NoGradient, Error}` is **inferred numerically**:

    const bool usable = std::isfinite(H) && H < 0.0 && std::isfinite(resid);
    out.stationarity = usable ? std::abs(resid / H) : infinity;
    out.status = !usable ? Status::NoGradient
                 : (out.stationarity > s.stationarity_tol ? Status::Pinned
                                                          : Status::Interior);

`OperatingPointKind` records **the branch the solve actually took** — exactly, no
tolerance. And `Rows`' own comment says the inferred one is wrong on a case the
exact one gets right:

> *"`Status` derives its own classification from the curvature's sign and the
> residual's size, which cannot separate a stationary point from the hard 0.0 the
> no-flow state returns: that reads as stationary, and the curvature taken off the
> same sentinel confirms it."*

So one question, two answers, and the tolerance-dependent answer is the one
`at()`/`batch()` report to R.

**Also two questions in one enum:** `Status::Error` is "did this row's call
succeed", a different axis from "what kind of point is this". Same shape as
`ad_role`.

**The move:** read the kind off `OperatingPointKind`; make the call's success its
own flag; delete `stationarity_tol` from the classification path if nothing else
needs it. ⚠️ R-visible — `Status`' strings cross the boundary.

## T2 — `DryBoundArm` and `WhichBound` overlap, with the converter in plain sight

`WhichBound{Wet, DryRootCrit, DryRootPsiCrit}` — which bound a pinned point is on.
`DryBoundArm{None, RootCrit, RootPsiCrit}` — which limit won the dry bound,
recorded where the `min` is taken.

`DryBoundArm::RootCrit` and `WhichBound::DryRootCrit` are the same fact.
`far_bound(Branch)` is the converter: `br.arm == DryBoundArm::RootPsiCrit ? ... : ...`.

⚠️ **Subtler than `ad_role`, so check before cutting.** The two differ in *when*
they are known: `DryBoundArm` is recorded during the solve, before it is known
whether the point is pinned at all; `WhichBound` describes the outcome. That may
be a real distinction rather than a duplicate. The test is whether any state has a
`DryBoundArm` that its `WhichBound` cannot express.

## T3 — two Weibull curves, their parameter roles enumerated twice

`TransportTrait{Conductance, Position, Steepness}` (leaf_model, the stem's) and
`CurveTrait{Position, Steepness}` (roots, the root's). Position and Steepness mean
the same thing about a different curve.

This is the `stem_b`/`root_b` story once more: two curves of the same family, and
the *roles* of their parameters written out twice. One `CurveTrait{Position,
Steepness}` shared, with the transport's conductance beside it rather than inside
it, would say it once. Modest, and self-contained within phylloptim.

## Still open from earlier, and both still worth doing

**T4 — plant's `b`, `c`, `g1_TF24` should be the leaf's names.** `phylloptim`'s own
comment records that the unmarked `b`/`c` put `lambda ~ psi^3.02` into a manuscript
draft where it should have been `psi^0.64`. plant still has them. Making the
fourteen names agree deletes `PLANT_TF24_LEAF_PARAMETER`'s third argument and makes
a rename on either side a compile error. **Breaking: R-facing.**

**T5 — a shut collar has no name for which exit placed it.** Three exits place it
at three different potentials; `OperatingPointKind::HydraulicShutdown` records none
of them. A pinned collar has `WhichBound`. That hole is what the `placement`
vocabulary is working around, and the same comment records it already caused a
wrong declared zero. Naming the exit is the fix.

**T6 — `zero_slack` is declared on both sides of the boundary.** plant declares it
on exactly `psi_crit` and `root_psi_crit`; `InputRole::Slack` is assigned to
exactly those two. The leaf owns which of its inputs are limits, so plant should
derive it from `leaf_par` rather than restate it.

**T7 — `eta`'s refusal may be unnecessary.** Its comment calls a recorded row "a
silently wrong zero" because `u^eta*log(u)` is `0*(-inf)` at `u = 0`. But
`lim(u->0+) u^eta ln u = 0`, so zero is the correct derivative there. Testable
with the ladder; a behaviour change if the comment is wrong.

---

# What has landed

Twenty-one commits. Every one verified against baseline before the next started,
and **no number moved anywhere.**

## Concept duplication removed

| | |
|---|---|
| `ad_role` + two identity-converters deleted; the table declares a `gradient_status::Kind` | `plant@44c9bd08` |
| `refused` and `unread` merged — nothing distinguished them | same |
| `Channel` → `InputRole`, `Role` → `OutputRole`, named for the one question they answer | `phylloptim@70e198e` |
| odelia's two contradictory tape disciplines split into `sweep.hpp` and `calibration.hpp` | `odelia@0efd4d8` |

## Facts that were written twice, now derived

`field_count` from the table; `CLAMP_SITE_COUNT` from phylloptim's own count;
`Internals`' three sizes from its vectors; `trait_adjoint_size` from a compile-time
count; the input layout from one `decode()`; the trait order from `par_table` via
`inputs.hpp`; a refused row's reason from the input it is about; the column filter
from one predicate.

## Dead weight removed

`transport_census.h` (−139); the `unanswered` machinery (−35); `ResourceSpline`'s
five parameters that selected nothing, and the `rescale` flag threaded through
seven signatures to reach the one function that discarded it; four includes that
named nothing the file used.

## Metaphors replaced

`waist` → `supply` (its own comment already said "total uptake"); `graft` →
`record` (the function was always `record_with_derivatives`); `seat` → `placement`
(`place_solved_point` was already the verb).

## Boundaries moved

Twelve test-only Rcpp exports out of `census_gradient.cpp` (18 → 6); the census
fold named per level — `census_value`, `census_integral`, `census_sum`.

## Where estimates were wrong

Four claims of mine were overturned by execution, and the pattern is uniform:
**every over-claim was a line-count target; every real defect was a fact written
in more than one place, or an idea named more than once.**

| claimed | actually |
|---|---|
| `scalar_functional`, `sum_of_squares` dead | both live, reaching shipped R |
| `clamp_sites` one enum spelled twice, −98 | correctly layered; real defect was a hand-maintained count, **+3** |
| `trait_without_species()` dead | live, in the "Unknown trait" hint |
| `Species::growth_rate_gradient` is the live operator | its only caller was the instrumentation now deleted |

Two changes grew the code and were still right — the layout decoder and the
input vocabulary, +65 lines each, buying a checkable trait order and a
compiler-checked partition of the inputs. Two shrank it and were wrong.
**Lines were the wrong meter throughout.**

## What was declined, and why

- **A unified refusal type across the three packages.** The premise was wrong: the eight mechanisms are
  partitioned by consumer, `NoRow` is a private work-list between two phylloptim
  functions, and the NA→refusal conversion was already single-sited in odelia.
- **A row view for the leaf boundary.** Its real content was the message rebuild, which the per-input
  reason covered. There was no view to build.
- **An `ad_column` struct bundling name, pointer and zero-meaning.** Once the table was one `constexpr` array, all three
  projections filtered it with one predicate; misalignment was already impossible.
- **The family `if`/`else` → `switch`.** Measured longer: each case needs its own
  guard and `break` where the chain falls through once.
- **Deriving `state_size()` from `state_names()`.** Would have put a six-string
  allocation in `Node::ode_size()`, called per node per step. Guarded instead.
- **`Rows::kind`, `gradient_status::Kind`.** Both read through an object whose type
  disambiguates them.

## What is confirmed to be earning its keep

Probed for excess and found none: `ode_state` at five levels is a **fold with
iterator threading** — one pass, no intermediates. `census` at four levels was
three distinct operations. `solve_adjoint` looked like a thin middle layer but has
direct callers in `test-step-adjoint-recording.R`, where "composition over a split
is associative" is checked. `rows_at`'s 423 lines are ~165 of genuine case analysis
of a constrained optimum plus ~155 of per-family arithmetic. The two census
evaluations are at different states.

**The excess in this surface was never in the runtime path. It was in the reader's.**

---

# Verification

Every change in this campaign was held to: **the numbers must not move.**

| suite | baseline |
|---|---|
| plant, non-ladder | 3265 / 8 / 3 / 13 |
| plant, ladder | 679 / 0 / 0 / 5 |
| phylloptim `test_leaf` | 2421 checks, 0 failures |
| phylloptim `test_golden --cross-platform` | 223 of 576 beyond tolerance |
| phylloptim R | 1435 / 5 / 1 |
| odelia R | 415 / 0 / 3 |
| odelia standalone guard (`CXX=g++`) | passes |

plant's non-ladder count is the AGENTS.md baseline plus three assertions added for
`check_state_layout`'s new size check. Six files fail for reasons predating this
work; a differing count is new.

Build order after any header edit, from AGENTS.md: reinstall `phylloptim` and
`odelia` with `R CMD INSTALL --no-multiarch --preclean`, `rm -f plant/src/*.o
plant/src/*.so`, then `compile_dll(".", debug = FALSE)`.

---

# Part II — Reference

Evidence for everything above: the end-to-end walk, the fifteen chunks, and what
each was found to contain. Written so someone with no prior context can locate
what a claim refers to and check it. Line numbers drift; file and symbol names do
not.

## The walk

### Forward — the run being differentiated

| # | where | what happens |
|---|---|---|
| F1 | `SCM::run()` | adaptive pass. Records `states`, `times`, `step_sizes`, `widenings` (introductions), `trajectory`. This is the only pass that chooses step sizes. |
| F2 | `Step::step()` | six-stage RK. `Patch::compute_rates` → `Species` → `Node` → `Individual::compute_rates` → `TF24_Strategy` rates. |
| F3 | `TF24_Strategy` rates | the leaf solve: phylloptim's `Leaf` root-finds **in double, off tape**. |
| F4 | `record_leaf_outputs` (`tf24_strategy.h:1199`) | reads supplied rows from phylloptim and grafts the solved point onto scalar `S`. The seam between "solved elsewhere" and "differentiable here". |
| F5 | environment | canopy light (`canopy_shape.h`, interpolant) and soil (`resource_spline.h`) close the feedback. |

### Back — the sweep

| # | where | what happens |
|---|---|---|
| B1 | `stand_gradient()` (`R/stand_gradient.R`) | resolve metric and trait names, refuse unknowns, assemble the answer. |
| B2 | `census_trait_gradient_tf24` (`src/census_gradient.cpp`) | names in, `Rcpp::List` out. |
| B3 | `SCM::census_trait_gradient` (`scm.h:1040`) | the orchestrator: seed, sweep, add the direct term, classify exact zeros, read the latch, restore the width. |
| B4 | `census_state_and_trait_rows` (`scm.h:897`) | **the seed**. One recording over (state, traits) at the final time gives both `d census/d state` (what the sweep is seeded with) and `d census/d trait` (the direct term no sweep produces). |
| B5 | `solve_adjoint_over_widenings` (odelia `gradient.hpp`) | cut the recording into one segment per state width, highest first; transpose `widened_state` at each boundary. |
| B6 | `Solver::solve_adjoint` (`ode_solver.hpp:276`) | walk `k` from `k_last` down to `k_first`. |
| B7 | `Step::step_adjoint` (`ode_step.hpp:218`) | **one recording of the whole six-stage step**, swept once per metric. |
| B8 | `state_and_parameter_adjoints` → `vector_jacobian_product` (`adjoint.hpp`) | the record-once/sweep-many primitive. Re-enters F2–F4 at the active scalar. |
| B9 | `record_with_derivatives` / `implicit_root` (`implicit_node.hpp`) | at F4, rows are *supplied* rather than recorded. |

**The load-bearing fact:** B8 re-enters the forward model, so F2–F4 are walked
twice — once in double, once at the active scalar — and every seam in the forward
path is also a seam in the sweep.

---

## Chunks

Ordered by expected waste, not by position in the walk.

| id | extent | ~lines | status |
|---|---|---|---|
| C1 | R boundary + answer shape: `stand_gradient.R`, `census_gradient.cpp`, `gradient_status.h` | 520 | walked |
| C2 | parameter/column vocabulary: `ad_parameter*` across Strategy/Patch/SCM | 200 | walked |
| C3 | census definition + seed: `census.h`, `census_over`, `metrics_of`, B4 | 250 | walked — clean |
| C4 | the referee set: 4 oracles + `gradient_ladder.cpp` + ladder helper | 2800 | walked |
| C5 | odelia sweep vocabulary: `adjoint.hpp` + widening half of `gradient.hpp` | 700 | walked |
| C6 | odelia example/calibration path: `compute_jacobian` and friends | 200 | walked |
| C7 | the graft: `implicit_node.hpp` | 196 | walked |
| C8 | the leaf graft: `record_leaf_outputs` | 220 | walked |
| C9 | phylloptim row layer — broken into C9a–C9j below | 5800 | broken down |
| C10 | **feasibility and refusal, end to end** (cross-cutting) | — | walked |
| C11 | environment feedbacks: canopy, soil, interpolant, `clamp_sites` | 600 | walked |
| C12 | widening machinery in plant: `widened_state`, `set_recorded_state`, `push_nodes` | 300 | walked — justified |

### Coverage

Measured over the whole diff, shipped code only (no `man/`, no generated
`RcppExports`/`RcppR6`, no docs, no tests): **23,395 changed lines**.
C1–C12 account for **94%**. The residue is three small chunks plus peripheral:

| id | extent | ~lines |
|---|---|---|
| C13 | state layout and index vocabulary — **walked** | 150 |
| C14 | the scalar-template sweep across the other models — **walked** | 113 |
| C15 | odelia's non-adjoint solver core — **walked, and it is outside the surface** | 441 |
| — | peripheral and already-deleted: `optimize.h` (151, gone), `R/scm_support.R`, `R/benchmark.R`, `R/tidy_outputs.R`, `individual_runner` | 250 |

`odelia/gradient.hpp` (505) is split between C5 and C6, and `scm.h` (954) between
C2, C3 and C4 — so those two files are counted once but read twice.

---

## C1 — the R boundary and the shape of the answer

**Purpose.** Resolve names, refuse unknowns, and hand back numbers that cannot be
read without their status.

**Findings.**

- **`stand_gradient_unanswered()` returns `character(0)`.** An exported,
  documented R function whose body is a constant. It drags along
  `trait_without_species()`, the `asked_by_name` branch, the `unanswered`
  computation and the `unanswered` field of the returned list — machinery for a
  set that is empty by construction. Its own doc says so: *"Every leaf trait the
  strategy declares as differentiable now has one, so this set is empty."*
  Live interface, dead body.
- **14 Rcpp exports in `census_gradient.cpp`, of which ~9 are instrumentation:**
  `census_operating_point_counts`, `_names`, `_clear`, `census_clamp_counts`,
  `census_clamp_counts_differentiated`, `census_clamp_names`,
  `census_curvature_margin`, plus `census_trait_difference` and
  `census_trait_gradient_split`. (`census_adjoint_segments` and
  `census_adjoint_at_first_state` are **gone** — their values are fields of the
  returned `census_gradient`, per `docs/design/subtraction-targets.md` 19.) Only `census_tf24`,
  `census_metric_names_tf24`, `census_trait_names_tf24`,
  `census_trait_gradient_tf24` and `gradient_control_tf24` serve
  `stand_gradient()`.
- `gradient_status.h` bundles three unrelated things in 85 lines: the `Kind`
  enum, the `gradient_refusal` exception, the `census_gradient` struct. It is
  also a third status vocabulary beside phylloptim's two (see C10).

**Resolved.** Nothing outside the tests calls any of the eleven. Checked one by
one: every caller is a `tests/testthat/test-gradient*` file (plus generated
`RcppExports.R`). So eleven of fourteen exports in this file are test
instrumentation living in the shipped R namespace.

## C2 — the parameter and column vocabulary

**Purpose.** Name the model's differentiable inputs so the sweep can write values
into them, label the columns it returns, and say what an exact zero means.

**Findings.**

- The base is sound: one `ad_parameter_table()`, 62 entries of
  `{value*, name, role, leaf_par}`, with a `sizeof` assert catching an unlisted
  member.
- **`ad_parameter{&x, ...}` takes an instance member's address.** That one
  character makes the table per-object and heap-allocated, which forces:
  - `static constexpr size_t field_count = 62` — a hand-maintained count, whose
    assert fires blaming *the table* when what you forgot was the count. The file
    admits it at line 887: *"field_count is a literal, so it is what a new member
    gets added without."*
  - the rule *"take them once per gradient evaluation and hold them for the run"*
    (`tf24_strategy.h:559`);
  - `trait_adjoint_size()` allocating a 62-pointer vector per species to return a
    count, on 6+ call sites per gradient.

  A **member pointer** (`&TF24_Pars::x`) makes the table `constexpr`, derives the
  count, and deletes all three. The 62 author-written lines do not change — only
  the macro body.
- **8 functions across 4 layers keep 3 positionally-aligned vectors in step:**
  Strategy `ad_parameters` / `ad_parameter_names` / `ad_parameter_zero_classes`;
  Patch `ad_parameters` / `trait_adjoint_names` / `trait_adjoint_zero_classes` /
  `trait_adjoint_size`; and SCM walking the species by hand again at
  `scm.h:941`.
- **The filter is spelled twice.** `ad_role_has_column(p.role)` in two of them; a
  `switch` that `break`s without pushing in the third. Disagree and the three
  vectors get different lengths, and every consumer indexes by position.
- **`patch.h:1236` states an invariant its own consumer breaks:** *"A patch
  answers for this rather than each caller walking the species, because a caller
  that walks it itself is free to walk it differently."* `scm.h:941` walks it
  itself.

**Fix.** Make the *column* the unit — one entry carrying name, pointer and
zero-kind — concatenated once into a Patch member. 8 functions → 2, ~80 lines,
and positional misalignment stops being expressible.

## C4 — the referee set

**Purpose.** Answer the same question independently, so the sweep can be checked.

**Findings.** `census_trait_gradient` is the answer. `census_trait_difference`,
`census_trait_tangent`, `census_initial_state_tangent` and
`census_initial_state_replay` are oracles for it — all four in `scm.h`'s public
interface and exported to R. `census_trait_tangent`'s only caller is
`gradient_ladder.cpp:491`.

A ladder needs referees; that is not the complaint. The complaint is that a
reader of `scm.h` meets six derivative entry points to find the one that ships.

**Open.** Can the four move behind the ladder's own boundary without losing the
checks? They have four different signatures, so a single unified entry point
would be a fat interface — the move is about *where they live*, not merging them.

## C5 — odelia's sweep vocabulary

**Purpose.** Record once, sweep many. Cut a recording whose state width changes
into fixed-width segments and transpose the map at each boundary.

**Findings.** This is the healthiest chunk; `adjoint_rows` in particular earns its
keep (one width per batch makes a ragged seed inexpressible). Smaller notes:

- `rates_adjoint` has one caller; `state_at_segment` has one; `tape_guard` and
  `state_segment` are internal. Not waste — but they are interface, and interface
  is read even when it is not called.
- `state_segments` is called with two different types — `recorded_widening` and
  `recorded_insertion` — and compiles for both because each has `.after_step`.
  Checked: they do mean the same thing, so this is duck typing rather than a
  defect. But it exposes a smaller one: **two structs for one event.**
  `recorded_widening{after_step, event}` and
  `recorded_insertion{what, after_step, time}` differ only by a `time` that
  `insertions_of()` derives by looking up the recording. One struct with the time
  filled in at construction would do, and `insertions_of` — plus every signature
  that threads both — would go.

## C6 — odelia's example and calibration path

**Purpose.** Differentiate a solver+functional for calibration — odelia's own
examples (Lorenz, canopy, leaf_thermal).

**Findings.** Consumers checked symbol by symbol: **plant 0, phylloptim 0.** And
it disagrees with C5 about the tape, which `gradient.hpp` spends 20 lines
explaining:

> *"NOT cleared, and the asymmetry with adjoint.hpp is the point… The cost is a
> leak bounded by what the System owns rather than by what the recording writes:
> the variable count climbs by the System's live scalars per call."*

Path A caches a lifted System on the solver, so it cannot clear the tape, so it
carries a documented unbounded slot leak. **The cached System is the sole reason
that leak exists, and nothing plant runs touches this path.** Splitting the file
makes the discipline a property of the header rather than a comment asking the
reader to track which regime they are in.

~~`scalar_functional` and `sum_of_squares` have zero callers anywhere.~~
**Wrong — corrected.** Both are live. `sum_of_squares` is called by
`least_squares::operator()` in this same file; `least_squares` is built by
`least_squares_from_r` (`solver_interface.hpp:140`) and reaches
`Solver_value_and_gradient` (called from `R/lorenz-interface.R:125`) and
`LeafSolver_value_and_gradient` (exercised five times in
`test-example-leaf-ad.R`). `scalar_functional`'s only user is `compute_gradient`,
which is heavily live; inlining it saves ~2 lines and costs a named type its
explanation, so it stays.

## C7 — the graft

**Purpose.** Put a value whose derivative is known by other means onto the tape,
and refuse a point where the implicit function theorem does not apply.

**Findings.** Three entry points, **three different refusal policies**:
`record_with_derivatives` reports, `implicit_root` reports, `implicit_value`
*stops*. The file argues the asymmetry (a caller of the first two already has
another use for the value; a caller of the third has nothing else). The argument
holds — but it means the same header answers "no derivative here" two ways.

`implicit_value` also contains its own double central difference and its own
tape deactivate/reactivate bracket.

**Resolved — and it goes the other way.** `implicit_value` *is* on plant's path:
`tf24_strategy.h:852`. So the stopping policy is live, and C10's count stands.
This makes the header's asymmetry load-bearing rather than vestigial: two of the
three entry points report and one stops, all three reachable from a stand
gradient.

## C8 — the leaf graft

**Purpose.** Turn phylloptim's row read into tape edges, once per solved leaf.

This is the densest chunk in the walk: ~220 lines carrying **two refusal
mechanisms at once**.

**Findings.**

- `throw gradient_refusal(...)` when the objective loses a row — unwinds to
  `census_trait_gradient`'s `catch`.
- `lose_uptake_rows(...)` when an ordinary output loses one — sets
  `*uptake_rows_unavailable`, a `shared_ptr<bool>` on the strategy, read back
  ~200 lines later in `scm.h:1105`. It must be out of band because the value
  still has to flow: the patch water balance needs the number even with no row.
- A `missing()` closure that rebuilds the message, because *"the row layer names
  an input whose row it refused, but a number can also arrive non-finite from a
  channel that reported no refusal"* — i.e. the row layer's own message is not
  sufficient, so the graft re-derives what went wrong.
- A `reads_point` pre-pass over all outputs before the point can be formed, then
  `point_whole`/`point_why` carried alongside.
- A clamp-count delta bracket taken around the row read, including on the
  throwing exit.
- The curvature floor, applied only for `Interior`.

**Open.** How much of this survives if the row layer had a single feasibility
channel (C9/C10)? The `missing()` rebuild and the `point_whole` carry both exist
because the row layer's refusal is not trustworthy on its own.

## C10 — feasibility and refusal, end to end

**The spine of the spaghetti.** One question — "is there a derivative here" —
answered by **eight mechanisms across three packages**:

| package | mechanism |
|---|---|
| phylloptim | `Status` enum (4) |
| phylloptim | `NoRow` enum (4) |
| phylloptim | NaN / `NA_REAL` sentinels (13 sites) |
| phylloptim | `throw` / `util::stop` (11 sites in `gradient.hpp`) |
| phylloptim | an exact-`0.0` sentinel |
| odelia | `graft_report{whole, at, why}` |
| odelia | `util::stop` (`implicit_value`) |
| plant | `gradient_refusal` exception + `gradient_status::Kind` (5) + the `uptake_rows_unavailable` latch |

And **four enums classify one physical point**: phylloptim's `Status` (4),
`OperatingPointKind` (12), `WhichBound` (3), `DryBoundArm` (3) — with
`pinned_bound()` existing purely to convert between two of them.

This is the largest available reduction and the only one that is a *design* job
rather than a deletion. C8's complexity is downstream of it.

---

## Parked by decision

- **∂g/∂h** — left for legacy compatibility (2026-08-23). For the record:
  `plant/gradient.h`'s 151 lines of finite-difference machinery reach production
  only through R wrappers named `test_*` and `r_growth_rate_gradient`
  (*"Wrapper to growth_rate_gradient for testing"*). `Individual::
  growth_rate_gradient` (FD on a probe copy) and `Species::growth_rate_gradient`
  (`(g[i] − g[i+1])/dh`, a neighbour difference) are **different operators
  sharing a name**; report 00 §4.4 records that these two correlate at 0.05 on
  TF24 with opposite signs over most of the grid, and only the second is live.
  Worth a rename whenever the file is next open.
- **QK/QAG quadrature controller** — left separate by earlier decision. The
  adaptive rule is R-only; the model uses fixed Gauss–Kronrod.

## Cross-package duplication (not tied to one chunk)

- ~~**`clamp_sites` is one enum spelled twice**, with incompatible counter
  shapes.~~ **Both halves of that were wrong; the real defect was smaller and
  worse.** The enums are correctly layered — plant numbers eleven ecological sites
  from 0 and appends phylloptim's leaf block at `CLAMP_LEAF_FIRST`; phylloptim
  cannot name a soil-moisture floor. And the counters are *not* the same
  accounting: plant's `forward`/`differentiated` split **is** the information —
  which path the clamp fired on — and phylloptim structurally cannot produce it,
  because the leaf solves in `double` on both paths. Unifying them would have
  meant giving phylloptim a caller-supplied size and a tally it never writes.

  What was actually duplicated: the four leaf name strings, spelled in both files,
  and **`CLAMP_SITE_COUNT` fixed at 15 by hand-listing phylloptim's four sites.**
  That second one is a silent-drop hazard — add a fifth leaf site in phylloptim
  and `scm.h`'s `if (at >= CLAMP_SITE_COUNT) break;` discards it with nothing
  said. Fixed by deriving the width:
  `CLAMP_SITE_COUNT = CLAMP_LEAF_FIRST + phylloptim::CLAMP_SITE_COUNT`, and
  delegating the leaf block's names. **+14/−11 in one file**, values verified
  unchanged (15, 11, all fifteen strings byte-identical).
- **`transport_census.h`** (119 lines, 3 call sites, all in `species.h`) is
  instrumentation behind `PLANT_TRANSPORT_CENSUS`, by its own header comment. The
  question it answers is recorded in report 00 §4.4. It also collides in name
  with `census.h`, which is model code.


---

## C9 broken down

Too big to walk as one chunk: `gradient.hpp` is 2,918 lines today, `leaf_model.hpp`
5,173, `roots.hpp` 1,439. Split by seam, with the line ranges as they stand:

| id | extent | ~lines | first read |
|---|---|---|---|
| C9a | naming and indexing tables — `par_table`, `output_table`, `par_of`/`output_of`, the layer-variable offsets (`par_PPFD`, `par_psi_soil_first`, `par_root_carbon_first`, `n_pars_total`, `out_uptake_first`) | 230 | looks healthy — consolidated to `constexpr` arrays last campaign |
| C9b | output vocabulary and feasibility — `Role`, `point_channel`, `OutputValues`, `outputs`, `outputs_at`, `Status`, `status_name`, `NoRow` | 120 | **this is C10's phylloptim half** |
| C9c | driver and parameter application — `Drivers`, `par_value`, `check_pars`, `Settings`, `Result`, two `apply()` overloads, `perturb_root_carbon`, `Scratch`, `set_one`, `takes_shortcut`, `step_for`, `rounded` | 400 | where the positional-argument problem lives |
| C9d | point classification — `Branch`, `branch_here`, `BasePoint`, `base_point`, `collar_step`, `differenced_curvature`, `collar_channel`, plus `OperatingPointKind`(12), `WhichBound`(3), `DryBoundArm`(3), `pinned_bound`, `far_bound` | 160 | four enums for one point |
| C9e | **the per-family row quintuples** — carbon, waist, transport, slack, bound, shut | 715 | **largest single opportunity, see below** |
| C9f | assembly — `held_row`, `held_row_or_stop`, `FollowBound`, `solved_row`, `gradient_ift`, `gradient_fd`, `at`, `batch`, `RowRequest`, `Rows`, `rows_at` (423 lines alone), `rows_differenced`, `differenced_bound` | 1010 | the dispatcher |
| C9g | profit environment rows — `ProfitEnvDerivatives`, `profit_env_rows_here`, `profit_env_derivatives` | 180 | |
| C9h | `leaf_model.hpp` — splines and the `stem_b` rescaling, the two supply paths (`SupplyKind`), photosynthesis/temperature/energy balance, the operating point and `condition_slope`, the solve, the memo caches | 5173 | the model itself |
| C9i | `roots.hpp` — `RootNetwork`, `root_network_from_carbon` (two overloads), `MultiLayerRoots` | 1439 | |
| C9j | `vulnerability.hpp` — Weibull curves, the analytic integral derivatives | 278 | |

### C9e — one shape written four times

Four families of input each get their own hand-written set of the same five
things:

| | `_side(par)` | `XRows` struct | `_rows_apply` | gather | project |
|---|---|---|---|---|---|
| carbon | 1511 | 1532 | 1578 | — | `carbon_profit` 1539, `carbon_marginal` 1554 |
| waist | 1609 | 1620 | 1664 | `waist_supply` 1680 | `waist_supply_of` 1730, `waist_row` 1775 |
| transport | 1824 | 1861 | 1835 | `transport_gather` 1872 | `transport_row` 1883 |
| slack | 1809 | — | — | — | — |
| bound | — | (`Leaf::BoundRow`) | — | — | `bound_dpoint` 1954 |
| shut | — | — | `shut_row_covers` 2148 | — | `shut_row` 2052 |

**19 functions and structs for four instances of one concept:** a family of
inputs, whether a request needs it, how to gather it, how to project one row. The
signatures differ only in which extra flag they thread — `n_layers`, `single`,
`shut`, `seated`, a `TransportTrait&` out-parameter. This is precisely the shape
AGENTS.md's style guide names as a default to unlearn (*"a per-item special case
where a mechanism scales"*).

**The partition — checked, and it fails safe.** `carbon_side`, `waist_side`,
`transport_side` and `slack_side` between them claim 15 of `par_table`'s 16
entries. **`par_resistance` is claimed by none of them.** Traced through:

- `check_pars` accepts it on the multi-layer path (it is in range and below
  `par_root_carbon_first`), so nothing there stops the request;
- `rows_at` initialises rows to `util::na_value`, **not zero**, so an unclaimed
  input comes back NA and plant's graft refuses it. It does not silently become
  an exact zero, which is the failure this whole design exists to prevent;
- it is excluded by convention in two unconnected places: `R/gradient.R:680`
  (`if (single) nms else setdiff(nms, "resistance")`) and TF24's own list of 14
  leaf parameters, which stops at `n_traits = par_kmax` and so reaches neither
  `kmax` nor `resistance`.

So: not a live defect, and the NA default is the right call. But **the rule lives
in R while plant calls `rows_at` directly**, and the partition is still four
predicates with nothing asserting they cover the space. A single
`family_of(par) -> enum` makes it total by construction and makes `resistance`
a named case instead of a fallthrough.


---

## The theme that runs through all of them

**A list, and a hand-maintained count or layout mirroring it.** Every instance is
a place two spellings can disagree while both compile, and in every instance the
disagreement produces plausible numbers rather than an error:

| where | the list | its hand-maintained mirror |
|---|---|---|
| C2 | `ad_parameter_table()`, 62 entries | `static constexpr size_t field_count = 62` |
| C13 | `state_names()` / `aux_names()` | `static size_t state_size()` / `aux_size()`, each with a *"update this when the length changes"* comment |
| C13 | `Internals`' four vectors | `state_size`, `aux_size`, `resource_size` fields |
| C9c | the parameter-index layout | decoded independently in **seven** functions |
| C9c | `par_table`'s first 14 entries | `set_traits`' 14 positional parameters |

Fixing them is the same move each time: derive, or make the layout one function.

## C3 — census definition and seed: clean

`census.h` is 58 lines and does what it should. `census_metric{name, of}` pairs a
name with its kernel so they cannot be listed apart; `census_metric_names()` reads
the names off the metrics; the `Censusable` concept is asserted at the call site
rather than the definition, so a model nothing censuses owes nothing. TF24's
`census_metrics()` reads `Internals` by cached index. Nothing to do here.

One measured question rather than a finding: `census_metric::of` is a
`std::function`, so every metric evaluation is an indirect call that cannot
inline — and the census is evaluated per cohort per species, on the tape, inside
`census_state_and_trait_rows`. Worth timing before assuming it matters.

## C9a — naming and indexing tables: healthy

`constexpr` arrays plus `par_of`/`output_of`, every named constant derived from
the list. This was consolidated last campaign and it held.

## C9b — output vocabulary and feasibility: well-factored

`role_of` and `point_channel` are each written once, and `point_channel` carries
the one warning that matters — *"THE OBJECTIVE'S ZERO IS NOT A PROPERTY OF BEING
THE OBJECTIVE. It is the interior stationarity condition"* — with the pinned case
handled rather than assumed. `outputs_at` establishes feasibility **before**
evaluating, which the comment correctly calls a requirement rather than an
economy. `rounded()`'s volatile store is justified by measurement (28% of
2,000,000 triples differ under FMA contraction).

## C9c — the parameter layout, decoded seven times

**The strongest single finding in phylloptim.** The index layout is
`[0, n_pars)` traits, then `par_PPFD`, then `n_layers` soil potentials, then
`n_layers` root carbons. That arithmetic is re-derived independently in:

| where | line |
|---|---|
| `par_value` | 505 |
| `set_one` | 779 |
| `step_for` | 453 |
| `check_pars` | 546 |
| `waist_side` | 1615 |
| `waist_supply_of` | 1752 |
| `bound_dpoint` | 1968 |

`par_value` and `set_one` are **the same four-way cascade statement for
statement**, differing only in what they do at each leaf — read a value, or apply
a perturbation. Every one of the seven computes `layer = par - par_psi_soil_first`
and compares against `n_layers` by hand.

One function fixes all seven and C9e with them:

    struct par_ref { enum { Trait, PPFD, SoilPotential, RootCarbon } kind; int index; };
    par_ref decode(int par, int n_layers);

Then each of the seven is a `switch` on `.kind`, the partition is total by
construction, and C9e's four `_side` predicates become derived rather than
written. **This is the same finding C9e reached from the other direction.**

Two smaller items in the same chunk:

- **`set_traits` takes 14 positional doubles** and `apply()` spells the order out
  by hand. It is guarded only by each argument being written `theta[par_NAME]`, so
  a reader has to match 14 names to 14 positions; nothing checks it. `par_table`'s
  own comment says the first `n_traits` *are* these arguments in this order — an
  agreement asserted in prose.
- **`set_physiology` takes 10 positional arguments and is called twice**, in the
  two arms of `apply`'s `if (single)`, with **nine of the ten identical**. Build
  the network into a local and there is one call.

## C9e — one shape written four times

Detailed under "C9 broken down" above. The point to carry forward: the four
`_side` predicates are the same partition `C9c`'s seven decoders re-derive, so
One change collapsed both: the layout became `decode()` and the channel became a
field on the table entry.

## C9h — the two supply paths: good

`leaf_model.hpp` is 5,173 lines, but the `SupplyKind` split is well done: *"The
four points where the two paths differ. Everything else in the solve is
supply-agnostic."* Four `switch` dispatches, everything else shared. Two entry
points rather than a settable tag, both clearing the solved state. That is the
right shape.

## C9i — `roots.hpp`

`root_network_from_carbon` has two overloads; the second is a four-line
convenience wrapper *"for tests and standalone callers"*. `layer_thickness` is
correctly extracted with its reason recorded (two callers must agree or every
vertical resistance gains a silent squared factor). Little waste visible.

## C11 — environment feedbacks

- **`ResourceSpline` threads five parameters that select nothing.** Its own
  comment: *"The refinement arguments no longer select anything: the knot
  positions are the fixed fractions times height_max. They are still taken
  because the R constructor and the model environments pass them."* The proof is
  in the signature — `void setup(double, size_t, size_t, bool)`, four unnamed
  parameters, all discarded — plus a discarded `bool` on
  `compute_environment`. This is residue from deleting `adaptive_interpolator.h`:
  the machinery went, the tuning knobs stayed, and they are still passed from R.
- **`extrinsic_drivers.h` is the pattern to copy.** 18 lines, one `using`
  alias to `odelia::drivers::Drivers`, and a comment recording that a duplicate
  class *"class for class and statement for statement"* was removed. This is
  exactly what `clamp_sites` should become.
- `Environment` carries five `extrinsic_drivers_*` methods that forward to
  `Drivers`' own shorter-named ones. A pass-through layer, though the flat names
  are probably what the R binding needs.
- Interpolation is confirmed single-homed: `ResourceSpline` wraps
  `odelia::interpolator::hermite_interpolator<S>`.

## C12 — the widening machinery: justified

Five state-writing entry points — `set_ode_state` ×2, `set_recorded_state` ×2,
`widened_state`. I expected this to be two orthogonal flags spelled as five
signatures. It is not: the doc comments name three genuinely different semantics
(nothing completes the state on the plain loader; the inflow condition's second
evaluation on the recorded one; what an inner solve chose on the staged one), and
the fourth is a *reconciliation* whose idempotence is what lets a walk re-run over
a recording. Leave it.

## C13 — state layout and index vocabulary

- **`HEIGHT_INDEX`, `MORTALITY_INDEX`, `FECUNDITY_INDEX` are `#define`s** in a
  header included nearly everywhere. They cannot be scoped, namespaced or shadowed
  and they leak into every translation unit. `inline constexpr int` costs nothing
  and behaves.
- **`Internals<S>` stores three counts its own vectors already know** —
  `state_size == states.size()`, `aux_size == auxs.size()`,
  `resource_size == consumption_rates.size()` — and has **two resize entry
  points** (`resize` for states/rates/auxs, `resize_consumption_rates` for the
  fourth), so the four vectors are not resized together.
- **`state_size()` / `aux_size()` on `Strategy` are hand-maintained counts** of
  `state_names()` / `aux_names()`, each carrying the comment *"update this when
  the length of state_names changes"*. Same defect class as C2's `field_count`.
- `check_state_layout` is the good part, now reached from FF16 and K93 too.

## C14 — the scalar-template sweep

Mostly mechanical (`Internals` → `Internals<double>`, `TF24_Strategy` →
`TF24_Strategy<double>`), but two things ride along inside it that are not:

- **`scientific_version` goes 1 → 2 on FF16 and K93**, with a measured
  behavioural change: offspring production 16.884586 → 17.172004 on the
  birth-date coordinate, **+1.70%**, unchanged on the height coordinate. That is
  a model change filed under a template sweep.
- K93's `compute_competition` switches `canopy_shape.Q(...)` to
  `canopy_shape.leaf_area_above(...)`.

The four `.cpp` shims are ~40 lines of pure `<double>` threading. A
`using TF24_Strategy_d = TF24_Strategy<double>` per model would collapse them —
and would shrink the generated bindings too, where the fully-spelled form appears
far more often.

## C15 — odelia's non-adjoint solver core: outside the surface

`ode_jacobian.hpp` (116) → used only by `ode_step_rodas.hpp`;
`ode_linalg.hpp` (105) → likewise; `ode_step_rodas.hpp` (220) → used only by
`ode_solver_internal.hpp`. **441 lines forming one chain for the stiff (Rodas)
stepper, and `Rodas` appears nowhere in plant at all.** Legitimate odelia
capability, no gradient-surface role — record it as out of scope rather than as
waste.

**Correction to the chunk table:** `ode_util.hpp` (159) does not belong here. It
is the shared vocabulary — `to_passive` alone is used in 14 plant files,
`check_length` in 13 — so it belongs with C5.

### And a duplication it exposed

**`plant/util.h` (253 lines) and `odelia/ode_util.hpp` (159) declare nine
same-named helpers each:** `is_finite`, `check_length`, `identical`,
`almost_equal`, `is_sorted`, `is_decreasing`, `warning`, `to_string`,
`format_double`. Two `util` namespaces, in packages where plant already depends on
odelia — the same situation `extrinsic_drivers.h` resolved with a one-line alias
and recorded as *"a second copy of it here, class for class and statement for
statement, which could only ever agree with this one by being edited twice."*

---


---

