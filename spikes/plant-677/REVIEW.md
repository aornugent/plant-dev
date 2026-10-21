# Review of the plant-677 spikes, before they become PRs

Scope: plant patches 0001–0015 on plant#679 (14 files, +543 −58) and odelia
patches 0001–0012 on odelia `1e0f0f0` (8 files, +348 −75).

## Verdict: approve with changes. Triage: 3

They change odelia's public surface (`record_with_derivatives`,
`hermite_spline`, `active_system`, `solve_adjoint`) and the boundary between
plant and odelia. Two parts should be redesigned before they land: the crown,
and how a spline read is recorded. Two should be deleted. The rest can land
nearly as written.

## Ledger (reconstructed from the issue and the brief)

- R1. Cut the cost of the FF16 gradient over all trait columns and several
  metrics, relative to the forward run.
- R2. Values identical; gradients equal up to rounding.
- R3. Low maintenance. Generic mechanisms live in odelia. Hand-written
  derivatives only for small closed-form kernels, and only through an odelia
  primitive.
- R4. No parallel near-copy of an existing path; no dead code.

## Leave-one-out at lifetime 60

Each row switches off one mechanism in the final build (F2: 1,803M
instructions at one metric, 2,694M at five) and counts what comes back.

| mechanism | 1 metric | 5 metrics |
| --- | --- | --- |
| crown integral as one statement with supplied rows | +19% | +31% |
| 12-byte operations (`XAD_REDUCED_MEMORY`) | +11% | +10% |
| one active System per descent | +7% | +5% |
| seed basis | 0 | +11% |
| field reduction as supplied rows | +2% | +6% |
| excluded field built only below the boundary node | +1% | +1% |

These account for about 0.7G of the 3.6G instructions removed since B at one
metric. The remainder is copies of active values that are no longer recorded,
which the history (plant 0001–0007 and 0013, odelia 0004–0006) puts at about
40% at lifetime 8. That has no one-line switch.

## Clean sheet

A subagent that saw only R1–R4 and the profiling facts proposed:

1. Remove copy statements.
2. `record_statement(value, operands, partials)`.
3. An active `hermite_spline` read recorded as one statement over its span's
   four knot values and slopes, with the span coefficients passive.
4. The crown folded to one statement per node. The forward and active passes
   run the same integrand, with the leaf kernel returning `value_with_slope`.
5. One active System per width.
6. Seed rows that are scalar multiples of an earlier row are not swept.

It would not build field-reduction rows, threading, or a general seed basis.

Gap between the sketch and the diff:

- a second, active-only crown function (finding 1);
- rows assembled by callers while the spline keeps active coefficients
  (finding 2);
- field-reduction rows (finding 3);
- `read_below` threaded through the environments (finding 4);
- Gram–Schmidt over seeds (Q1).

The diff's one active System per *descent* beats the sketch's per width: a
node is introduced at almost every step, so per width is per step.

## Prediction record

Weakened: the reviewer wrote these bodies, so the misses below are a lower
bound.

- `knot_built(x, k, read_below)`: predicted "knot k has been built"; actual
  "knot k is at or below `read_below`, so the build should compute it".
- `FF16_Strategy::assimilation_deep_crown_rows(...) -> bool`: predicted
  "returns the crown's rows"; actual "records the crown as one statement into
  `out`, or returns false and leaves `out` alone so the caller records it the
  old way".
- `seed_basis::expand_into(from, into)`: predicted "writes the rebuilt rows";
  actual "adds them, so `lambda` has to be zeroed first and
  `parameter_adjoint` must not be".
- `derivs(obj, StateType&& y, ...)`: an overload with the same name as the
  copying form, which moves the state out of `y`; a caller passing an
  expiring vector gets different slot semantics with no sign at the call.

## Decisions reopened

- D1: a second crown function for the active scalar, over one function for
  both scalars with the rows behind `if constexpr`. UNSETTLED → finding 1.
- D2: callers build knot rows from `read_linear` while the spline stores
  active span coefficients, over an active read that records one statement
  over the knots and coefficients held in double. UNSETTLED → finding 2.
- D3: the field reduction as supplied rows, over the recorded reduction. Worth
  2% / 6%, at about 150 lines, including a second copy of `Q_and_q_times`'s
  arithmetic. UNSETTLED → Q2.
- D4: `read_below` threaded through `Patch`, three environments,
  `ResourceSpline` and `build_extinction_field`, over not cutting the build.
  Worth 1%. UNSETTLED → finding 4.
- D5: modified Gram–Schmidt with a tolerance and a triangular solve, over
  detecting rows that are multiples of one earlier row. The only dependence
  observed, at 1, 2 and 4 species, is a pair proportional through the birth
  rate. UNSETTLED → Q1.

## Change simulation

- **The crown rule or the leaf rate changes** (QK21 to QK15, or a new leaf
  kernel). Edit `assimilation_deep_crown`, `assimilation_deep_crown_rows` and
  the hand-written partials, and keep the first two equal bit for bit:
  shotgun. After finding 1, one function and its partials: one place.
- **`Patch` gains a member a rebound patch must carry.** Edit
  `Patch::rebind_from` and `Patch::assign_from`, which must agree: shotgun.
  After finding 5: one place.
- **A fourth environment type.** It must forward `read_below`: leaky. After
  finding 4: nothing to forward.
- **XAD is upgraded.** Re-apply the `OperationsContainer::copy_into` edit and
  the `Config.hpp` define: leaky. Proposing `copy_into` to XAD upstream makes
  it one-place.

## What must always be true

A value recorded with supplied rows equals, bit for bit, what the forward run
computes at that point, and its rows are the partials of that computation.

Kept by convention: the guard script and the finite-difference gradient
tests. Comments such as "rounded as `Q_and_q_times` rounds them" and "in the
recorded loop's order" are where the convention lives. A structural form
exists for the first half: one function computes the value at both scalars
(finding 1).

The second invariant: after a sweep, the derivative array holds only what the
`read` callback zeroes. Kept by convention in two callers of
`sweep_each_seed` (finding 6).

## Structural findings

1. **The crown exists twice.** `assimilation_deep_crown` integrates through
   `QK::integrate` at double. `assimilation_deep_crown_rows` re-implements the
   same 21-point sum at the active scalar, and must reproduce it bit for bit.
   That makes any change to the crown rule or the leaf rate a two-site edit
   whose disagreement shows only as a guard failure. Simpler: one loop over
   `crown_fractions`/`crown_weights` at both scalars. It reads the spline
   through the same call, adds the value, and, under
   `if constexpr (CarriesAdjoint<S>)`, adds the partials and records once. The
   double run then pays nothing extra and `QK::integrate` leaves this path.
   Value identity becomes structural.
2. **Span coefficients are active, and every reader works around it.** With
   crown rows on the knots, the coefficients are recorded and never read: 256
   dead statements per field build. odelia 0003 (slope read at its value) and
   0006 (one statement per coefficient) exist only to make that recording
   cheaper. Simpler: hold the coefficients in double whenever the knot data is
   active, and record an active read as one statement over the span's four
   knot values and slopes. The weights are those `read_linear` already
   computes. 0003 and 0006 can then be deleted, and the dead statements go
   away for every model, TF24 included. `read_linear` stays as the one
   primitive the crown uses.
3. **The field reduction is written twice.** `split_with_rows` duplicates the
   reduction in `field_splits_nodes`, and
   `FF16_Strategy::competition_and_slope_rows` duplicates
   `CanopyShape::Q_and_q_times`. Both must agree bit for bit, for 2% at one
   metric and 6% at five. Delete 0014, whose own measurement was neutral at
   one metric. Keep 0011 only if it can take finding 1's form, one function at
   both scalars; otherwise drop it (Q2).
4. **`read_below` buys 1%.** It adds a parameter to
   `ResourceSpline::compute_environment`, `build_extinction_field`, the
   three environments and `Patch`, plus `knot_built`, whose name misleads.
   What it saves is the sums and extinction of the knots above the boundary
   node in the excluded field, 1% of the gradient. Delete it.
5. **`assign_from` and `rebind_from` each list what a rebound patch takes from
   its source.** Simpler: `rebind_from` builds the structure (strategies,
   parameters, an empty patch) and then calls `assign_from(*this)`. One list,
   and `assign_from` is exercised on every rebind.
6. **`sweep_each_seed` relies on each `read` to zero what it reads.** One
   forgotten zero turns every later seed's row into a running sum, silently.
   Simpler: `sweep_each_seed` takes the input scalars and zeroes them after
   `read(m)`. Or, if the measured saving of clearing once per walk is small,
   go back to clearing per seed. 0001 bundled it with the 12-byte operations,
   so it has not been measured alone.

## Minor findings

- `derivs(obj, StateType&& y, ...)` and `internal::set_ode_state_moving` exist
  for one call site, `Step::step_adjoint`. Passing
  `std::make_move_iterator(stage.begin())` to the existing `set_ode_state`
  there needs no new overloads.
- `state_and_parameter_adjoints` now accepts `evaluate` in two calling
  conventions (`if constexpr (requires ...)`). One convention, the vector
  form, is enough once `rates_adjoint` is changed to match.
- `record_with_derivatives` has two overloads: rows as structs, and parallel
  arrays. `implicit_value` is the struct form's only caller left in odelia.
  Move it to the parallel arrays and delete the struct overload with
  `internal::record_rows`'s lambdas.

## Questions with defaults

- Q1: why a general basis over rows that are multiples of one earlier row?
  Default if unanswered: the pairwise test, about 20 lines, the same 1e-14
  tolerance and no triangular solve.
- Q2: does 0011 earn 6% at five metrics as a second implementation of the
  reduction? Default if unanswered: drop it with 0014.

## Proposed PRs, in order

Subtraction first; each PR is one change and states its leave-one-out effect.

| PR | repo | change | from |
| --- | --- | --- | --- |
| 1 | plant | Record no copies on the active rate path | 0001–0007 copy parts, 0008 (above-crown zero, height scan), 0013 |
| 2 | odelia | 12-byte operations; copy a statement's operations without `memmove` | 0001 (12-byte operations), 0002 |
| 3 | odelia | Active spline reads over knot data; coefficients in double | redesign of 0003, 0005–0008 (finding 2) |
| 4 | odelia | `record_with_derivatives` on parallel arrays, one pass | 0009, 0010; struct overload removed |
| 5 | plant | The crown integral as one statement, one function at both scalars | redesign of 0009, 0010, 0012 (finding 1) |
| 6 | odelia + plant | One active System per descent; `rebind_from` through `assign_from` | odelia 0011, plant 0015 (finding 5) |
| 7 | odelia | Sweep seed rows that are multiples of another once | 0012, simplified (Q1) |

Not carried forward: `read_below` (finding 4), 0014, and 0011 unless Q2 says
otherwise. The single clear per walk follows finding 6.
