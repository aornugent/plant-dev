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

# The detector

⚠️ **Counting does not find the defect that matters.** Three passes looking for
one fact written in several places — counts, layouts, orderings — found and fixed
fifteen real defects and were blind to the more valuable class:

> **Two types holding one idea, with a function converting between them.**

`ad_role` and `gradient_status::Kind` held the same three ideas in different
words, with `ad_role_has_column` and `ad_role_zero_kind` between them — both the
identity dressed as a translation. A reader of the parameter table had to learn
twelve names to understand six. No line count and no "same fact twice" search can
see it, because nothing is written twice: two *different* vocabularies are each
written once.

**The detector is the converter.** A function whose body maps one enum onto
another is the signature. That, plus comparing enums by their value sets, is what
found every target below.

A second shape, same family: **one enum carrying two questions.** `ad_role`
answered both "does this have a column" and "what does a zero in it mean", which
is exactly why two extractor functions existed.

⚠️ **Lines are the wrong meter.** Every over-claim in this campaign was a
line-count target and every real defect was a fact written twice or an idea named
twice. Two changes that grew the code were right — the layout decoder and the
input vocabulary, +65 lines each, buying a checkable trait order and a
compiler-checked partition of the inputs. Two that shrank it were wrong. Four
claims were overturned by execution: `scalar_functional`/`sum_of_squares` claimed
dead were live and reaching shipped R; `clamp_sites` claimed one enum spelled
twice was correctly layered, and the real defect was a hand-maintained count, at
**+3** lines; `trait_without_species()` claimed dead is live in the "Unknown
trait" hint; `Species::growth_rate_gradient` claimed the live operator had one
caller, the instrumentation since deleted.

**The excess in this surface was never in the runtime path. It was in the
reader's.**

---

# Still open

## T1 — `Status` is a worse copy of `OperatingPointKind`, and it is the one on the R path

`Status{Interior, Pinned, NoGradient, Error, Prescribed, Clamped}`
(`phylloptim/gradient.hpp:318`) is **inferred numerically**:

    out.status = !usable ? Status::NoGradient
                 : (out.stationarity > s.stationarity_tol ? Status::Pinned
                                                          : Status::Interior);

`OperatingPointKind{Unsolved, Interior, BoundarySoil, BoundaryCrit,
BoundaryRootCrit, Determined, HydraulicShutdown, ShadeDeath, Prescribed}` records
**the branch the solve actually took** — exactly, no tolerance. And the case the
inference cannot reach is named in the file itself (`gradient.hpp:196`):

> *"Both routes return a hard 0.0 SENTINEL on their shut-down and
> reversed-gradient exits, and a bare zero is indistinguishable from a stationary
> point."*

`stationarity = |resid / H|` taken off that sentinel reads as stationary and the
curvature confirms it, so a shut point classifies as `Interior`. One question,
two answers, and the tolerance-dependent answer is the one `at()`/`batch()`
report to R.

**Also two questions in one enum:** `Status::Error` is "did this row's call
succeed", a different axis from "what kind of point is this". Same shape as
`ad_role`.

**The move:** read the kind off `OperatingPointKind`; make the call's success its
own flag; delete `stationarity_tol` from the classification path if nothing else
needs it. ⚠️ R-visible — `Status`' strings cross the boundary, and
`R/stand_gradient.R` documents `"interior"`, `"pinned"`, `"no-gradient"` and
`"clamped"` in its `@return`.

## T5 — a shut collar has no name for which exit placed it

Two shut-down exits place the collar at different potentials;
`OperatingPointKind::HydraulicShutdown` records neither. `leaf_model.hpp:493`
notes the consequence from the other side: at both exits the Farquhar block still
holds its `Tair` baseline, so the reported `R_d_` there is 36% low against the
temperature the point is actually at. The `placement` count is what the ladder
uses to work around the hole. Naming the exit is the fix.

⚠️ The comparison this target originally drew — that a *pinned* collar has
`WhichBound` while a shut one has nothing — no longer holds: `WhichBound` and
`DryBoundArm` are gone.

## C4 — four referees share `scm.h`'s public interface with the one that ships

`census_trait_gradient` is the answer. `census_trait_difference`,
`census_trait_tangent`, `census_initial_state_tangent` and
`census_initial_state_replay` are oracles for it — all four in `scm.h`'s public
interface and exported to R.

A ladder needs referees; that is not the complaint. The complaint is that a
reader of `scm.h` meets five derivative entry points to find the one that ships.
Can the four move behind the ladder's own boundary without losing the checks?
They have four different signatures, so a single unified entry point would be a
fat interface — the move is about *where they live*, not merging them.

## C10 — one question, still several answers

"Is there a derivative here" is the spine, and it is the only remaining item that
is a *design* job rather than a deletion. It has shrunk a long way — `NoRow`,
`WhichBound`, `DryBoundArm` and `pinned_bound` are gone, and four enums
classifying one physical point are down to two (T1) — but the mechanisms that
remain still answer it in different registers:

| package | mechanism |
|---|---|
| phylloptim | `Status` (6 values), reported to R as strings |
| phylloptim | NaN / `NA_REAL` sentinels, and an exact-`0.0` sentinel at a no-flow point |
| phylloptim | `throw` / `util::stop` |
| odelia | `record_report{whole, at, why}` |
| odelia | `util::stop` from `implicit_value` |
| odelia | `AdjointRangeError` from `sweep_range` |
| plant | `refusal{reason, species}` on the strategy, set from a typed `catch` |

⚠️ **The incidence of a classification is not recoverable from the refusal.**
`record_leaf_outputs` keeps `operating_point_counts` for exactly this reason, and
says so: *"the classification is decided by the branch taken and then overwritten
by the next plant, so without a tally the only route to its incidence is a refusal
message -- which reports the FIRST non-interior point and nothing about how many
followed it or what kinds they were."* A single feasibility channel that carried
the count would delete the tally.

## Smaller, self-contained

- **`Individual::growth_rate_gradient` and `Species::growth_rate_gradient` are
  different operators sharing a name.** The first is a finite difference on a
  probe copy; the second is `(g[i] − g[i+1])/dh`, a neighbour difference. They
  correlate at 0.05 on TF24 with opposite signs over most of the grid, and only
  the second is live. Worth a rename whenever the file is next open.

---

# Closed, and not to be re-proposed

## Landed

Twenty-one commits, every one verified against baseline before the next started,
and **no number moved anywhere.**

| | |
|---|---|
| `ad_role` + two identity-converters deleted; the table declares the zero-meaning directly | `plant@44c9bd08` |
| `refused` and `unread` merged — nothing distinguished them | same |
| `Channel` → `InputRole`, `Role` → `OutputRole`, named for the one question they answer | `phylloptim@70e198e` |
| odelia's two contradictory tape disciplines split — `sweep.hpp` holds the descent's | `odelia@0efd4d8` |

Since then, and verifiable in the tree rather than the log: `DryBoundArm`,
`WhichBound`, `pinned_bound`, `far_bound`, `NoRow`, `TransportTrait` and
`CurveTrait` are gone; `zero_slack` is no longer declared on both sides of the
boundary; plant's `b`, `c` and `g1_TF24` now carry the leaf's names
(`stem_P50`/`stem_c`, `root_P50`/`root_c`, `TF24_cost_scale`), so a rename on
either side is a compile error; `implicit_root` is gone and every kind closes on
its residual through `implicit_value`; `stand_gradient_unanswered()` is gone with
the `unanswered` machinery behind it; `gradient_status.h`, `gradient_refusal` and
`gradient_status::Kind` no longer exist — plant refuses with one
`refusal{reason, species}` recorded on the strategy; the row layer's `Rows`,
`rows_at`, the `missing()` message rebuild, the `point_whole`/`point_why` carry
and the `uptake_rows_unavailable` latch are all gone; and
`census_gradient.cpp`'s Rcpp exports are down from 14 to 7.

**Facts that were written twice, now derived.** `field_count` from
`ad_parameter_fields.size()` — the table is `constexpr` over a member pointer
(`ad_parameter{&TF24_Pars::x, #x}`) rather than per-object over an instance
address, which deleted the hand-maintained count, the "take them once per
gradient evaluation and hold them for the run" rule, and the per-species pointer
vector that `trait_adjoint_size()` used to allocate just to return a number
(it is now `species.size() * T::ad_column_count`, with `column_count` itself
derived from the table and a `static_assert` that the differentiable and
undifferentiable lists partition it). `CLAMP_SITE_COUNT` from
`CLAMP_LEAF_FIRST + phylloptim::CLAMP_SITE_COUNT`; `Internals`' three sizes from
its vectors; the input layout from one `decode()`; the trait order from
`par_table` via `inputs.hpp`; a refused row's reason from the input it is about;
the column filter from one predicate.

**Dead weight removed.** `transport_census.h`; the `unanswered` machinery;
`ResourceSpline`'s five parameters that selected nothing, and the `rescale` flag
threaded through seven signatures to reach the one function that discarded it;
`scalar_functional` and `sum_of_squares` with the calibration path that held
them; four includes that named nothing the file used.

**Metaphors replaced.** `waist` → `supply` (its own comment already said "total
uptake"); `graft` → `record` (the function was always
`record_with_derivatives`); `seat` → `placement` (`place_solved_point` was
already the verb).

**Boundaries moved.** Twelve test-only Rcpp exports out of
`census_gradient.cpp`; the census fold named per level — `census_value`,
`census_integral`, `census_sum`.

## Declined, with the reason

- **A unified refusal type across the three packages.** The premise was wrong:
  the mechanisms are partitioned by consumer, `NoRow` was a private work-list
  between two phylloptim functions, and the NA→refusal conversion was already
  single-sited in odelia.
- **A row view for the leaf boundary.** Its real content was the message rebuild,
  which the per-input reason covered. There was no view to build.
- **An `ad_column` struct bundling name, pointer and zero-meaning.** Once the
  table was one `constexpr` array, all three projections filtered it with one
  predicate; misalignment was already impossible.
- **The family `if`/`else` → `switch`.** Measured longer: each case needs its own
  guard and `break` where the chain falls through once.
- **Deriving `state_size()` from `state_names()`.** Would have put a six-string
  allocation in `Node::ode_size()`, called per node per step. Guarded instead.
- **`Rows::kind` and `gradient_status::Kind` merged.** Both read through an object
  whose type disambiguates them.
- **Unifying plant's and phylloptim's clamp counters.** plant's
  `forward`/`differentiated` split *is* the information — which path the clamp
  fired on — and phylloptim structurally cannot produce it, because the leaf
  solves in `double` on both paths.
- **Making `eta` differentiable.** `u^eta*log(u)` is `0*(-inf)` at `u = 0`, and
  although `lim(u->0+) u^eta ln u = 0`, `TF24_Strategy` declares `eta`
  undifferentiable and the branch whose only product was that row is gone
  (`canopy_shape.h:283`).
- **∂g/∂h**, left for legacy compatibility (2026-08-23), and the **QK/QAG
  quadrature controller**, left separate by earlier decision — the adaptive rule
  is R-only and the model uses fixed Gauss–Kronrod.

## Probed for excess and found to be earning its keep

`ode_state` at five levels is a **fold with iterator threading** — one pass, no
intermediates. `census` at four levels was three distinct operations.
`solve_adjoint` looked like a thin middle layer but has direct callers in
`test-step-adjoint-recording.R`, where "composition over a split is associative"
is checked. The two census evaluations are at different states. odelia's
`adjoint_rows` earns its keep outright: one width per batch makes a ragged seed
inexpressible.

---

# Reference — the walk

Line numbers drift; file and symbol names do not.

## Forward — the run being differentiated

| # | where | what happens |
|---|---|---|
| F1 | `SCM::run()` | adaptive pass. Records `states`, `times`, `step_sizes`, the widenings at introductions, `trajectory`. The only pass that chooses step sizes. |
| F2 | `Step::step()` | six-stage RK. `Patch::compute_rates` → `Species` → `Node` → `Individual::compute_rates` → `TF24_Strategy` rates. |
| F3 | `TF24_Strategy` rates | the leaf solve: phylloptim's `Leaf` root-finds **in double, off tape**. |
| F4 | `TF24_Strategy::record_leaf_outputs` | reads supplied rows from phylloptim and records the solved point at scalar `S`. The seam between "solved elsewhere" and "differentiable here". |
| F5 | environment | canopy light (`canopy_shape.h`, the interpolant) and soil (`resource_spline.h`) close the feedback. |

## Back — the sweep

| # | where | what happens |
|---|---|---|
| B1 | `stand_gradient()` (`plant/R/stand_gradient.R`) | resolve metric and trait names, refuse unknowns, assemble the answer. |
| B2 | `census_trait_gradient_tf24` (`plant/src/census_gradient.cpp`) | names in, `Rcpp::List` out. |
| B3 | `SCM::census_trait_gradient` | the orchestrator: seed, sweep, add the direct term, classify exact zeros, read the latch, restore the width. |
| B4 | `SCM::census_state_and_trait_rows` | **the seed**. One recording over (state, traits) at the final time gives both `d census/d state` (what the sweep is seeded with) and `d census/d trait` (the direct term no sweep produces). |
| B5 | `Solver::solve_adjoint` (`odelia/ode_solver.hpp`) | one range per state width, highest first, narrowing across each introduction; returns the range count. `sweep.hpp` holds the per-range state and System replay. |
| B6 | `Step::step_adjoint` (`odelia/ode_step.hpp`) | **one recording of the whole six-stage step**, swept once per metric. |
| B7 | `state_and_parameter_adjoints` → `vector_jacobian_product` (`odelia/adjoint.hpp`) | the record-once/sweep-many primitive. Re-enters F2–F4 at the active scalar. |
| B8 | `record_with_derivatives` / `implicit_value` (`odelia/implicit_node.hpp`) | at F4, rows are *supplied* rather than recorded. |

**The load-bearing fact:** B7 re-enters the forward model, so F2–F4 are walked
twice — once in double, once at the active scalar — and every seam in the forward
path is also a seam in the sweep.

---

# Coverage

The campaign walked fifteen chunks covering **94% of 23,395 changed lines** of
shipped code (no `man/`, no generated `RcppExports`/`RcppR6`, no docs, no tests).
Chunks found clean or justified, and not worth re-walking: census definition and
seed; the naming and indexing tables; the output vocabulary; the two supply paths;
state layout and index vocabulary; the scalar-template sweep across the other
models; plant's widening machinery (`widened_state`, `set_recorded_state`,
`push_nodes`). odelia's non-adjoint solver core was walked and is outside the
surface.

⚠️ **Not walked:** `R/scm_support.R`, `R/benchmark.R`, `R/tidy_outputs.R`,
`individual_runner`, and `vulnerability.hpp`'s analytic integral derivatives.

**The discipline every change was held to: the numbers must not move.** The
baselines live in `AGENTS.md` rather than here, because a figure copied into a
second place is the defect this document is about. `docs/design/measurements.md`
holds the measurements behind the claims above.
