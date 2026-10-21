We profiled the FF16 reverse pass on top of #679 and odelia#78 and brought it down from 15 to 5 times the forward run for one metric, and from 27 to 7 times for all five metrics. That is one species at lifetime 60, birth-date coordinate, lma 0.0825, default `hmat` (the issue used 3), and all 32 columns. In seconds, against a 0.038 s run, one metric went from 0.56 s to 0.19 s and five metrics from 1.04 s to 0.27 s (medians of interleaved runs, Linux x86-64).

Values are unchanged. Gradients differ from #679's by at most 2.3e-12 relative at lifetime 8 and 2.7e-13 at lifetime 30. The plant and odelia test files fail the same tests before and after.

The work is spikes, in [aornugent/plant-dev `spikes/plant-677`](https://github.com/aornugent/plant-dev/tree/claude/pensive-johnson-ip4lx3/spikes/plant-677), and will come back as the PRs listed at the end. The rest of this comment explains each change.

## Where the changes act

The reverse pass records one RK step at a time and sweeps it once per metric. On the fixture, one step's tape went from 253,900 statements and 671k operations to 53,502 statements and 168k operations.

```
for each range of steps at one state width      [4] one active Patch for the whole pass
  for each step, last first:
    record the step's six rate evaluations:
      load the stage state                      [1] moved into the System
      build the light field
        reduce the nodes to 65 knot sums        [6] one statement per knot
        knot sums -> Hermite spline
      for each node:
        crown integral, 21 spline reads         [2] one statement per node
        growth, mortality, fecundity rates      [1] no copies or repeated work
      write the rates
    sweep the tape                              [3] 12-byte operations
                                                [5] once per independent metric seed
```

Each change was then switched off on its own in the final build and the gradient's instructions counted again (callgrind, inside `census_trait_gradient_ff16`). With everything on, the gradient is 1,803M instructions for one metric and 2,694M for five, against 375M for the run:

| switched off | 1 metric | 5 metrics |
| --- | --- | --- |
| [2] the crown integral as one statement | +19% | +31% |
| [3] 12-byte tape operations | +11% | +10% |
| [4] one active `Patch` for the whole pass | +7% | +5% |
| [5] one sweep per independent metric seed | 0 | +11% |
| [6] the field reduction as one statement per knot | +2% | +6% |

Together these explain about a fifth of the reduction at one metric. The rest is [1], which has no single switch. Measured as it was added, [1] took one metric from 14.5x to 8.7x at lifetime 8.

## [1] Copies of active values

Constructing an `xad::AReal` from another records a statement. The FF16 rate path made many of these without anything looking like a copy:

```cpp
const S A_lf = area_leaf_;          // a statement
const S& A_lf = area_leaf_;         // nothing recorded
```

The sources were arguments taken by value (kernel arguments, `CanopyShape` arguments, `Node::height()`), named intermediates, temporaries copied into `Internals`, and three accessors returning a parameter by value (`dmass_leaf_darea_leaf` returned `lma`, `dmass_root_darea_leaf` returned `a_r1`, `mortality_growth_independent_dt` returned `d_I`). Taking them by `const S&` and moving temporaries into place removes the statements without changing any value. At 91 nodes this took copies from 7,180 to about 1,800 per rate evaluation.

Two pieces of work were repeated. `fraction_allocation_growth` recomputed the reproduction fraction `compute_rates` already held, and `area_heartwood_dt` recomputed the sapwood area the production worker had returned.

The stage state is also moved into the System. odelia's `derivs` gains an overload taking the stage vector by rvalue, and `hermite_spline::set_data` takes its knot vectors by value, so a caller that is done with them moves them in.

The crown was the largest case. In #679 each of its 21 quadrature points records the point's height, the shape `q(z/h, z)`, the spline read, the leaf rate and the product: about 26 statements. The points sit at `z = h * s_j` for fixed fractions `s_j`, and with `dz = h ds` the shape term `q(z/h, z) dz` becomes `2 eta (1 - s^eta) s^(eta - 1) ds`, a function of `s_j` alone. It folds into the quadrature weight. `FF16_Strategy` now holds `crown_fractions` and `crown_weights`, built once from the Gauss-Kronrod rule, and a point records the read at `h * s_j` and the accumulation: two statements.

## [2] The crown integral as one statement

Even at two statements per point, a crown is 42 statements and its reads are swept once per metric. Every read is linear in four numbers, the value and slope at the two knots of its span, with Hermite basis weights that depend only on where the point falls. odelia's `hermite_spline::read_linear(u)` returns the read's value and slope, its span, and those four weights.

`FF16_Strategy::assimilation_deep_crown_rows` uses this to compute, in double:

- the integral `A = Σ_j w_j a_p1 E_j / (E_j + a_p2)`;
- its partials with respect to each knot value and slope, gathered per knot, since neighbouring points often share one;
- its partials with respect to `a_p1`, `a_p2`, height (through the read positions), the canopy top, and leaf area.

It then records `area_leaf * A` once, with those partials as the statement's operations, through odelia's `record_with_derivatives`. The hand-written part is the leaf rate's derivative, `d/dE [a_p1 E / (E + a_p2)] = a_p1 a_p2 / (E + a_p2)^2`.

The value is computed in the same order as the recorded loop, so it is identical bit for bit. The partials move adjoints at rounding level. If a point falls outside the spline's interior the function returns false and the crown is recorded as before.

A crown is now one statement with about 75 operations, one row per knot value or slope it reads. Recording costs about what the 42 statements did, because XAD records efficiently. The saving is in the sweep, which is why [2] is worth more at five metrics.

## [3] 12-byte tape operations

XAD stores each recorded operation as a multiplier and a slot index. Its `XAD_REDUCED_MEMORY` option keeps them in two arrays, 12 bytes per operation against a padded 16, and the sweep is limited by streaming that array. The define is set in odelia's vendored `XAD/Config.hpp`, so plant and odelia agree on the layout.

Two smaller odelia changes sit beside it:

- XAD copied each statement's operations with `std::uninitialized_copy_n`, which compiles to a `memmove` call per statement. A switch over the usual counts of one to four replaced it.
- An active spline read recorded its slope term against all three coefficients with a partial of exactly zero; it is now taken in double.

## [4] One active `Patch` for the whole pass

`Solver::solve_adjoint` splits the recording into ranges of constant state width. Each range rebinds an active `Patch` from the double one, and so does each node introduction between ranges. With `node_density_in_birth_date` a node is introduced at almost every step, 118 times in 146 steps here. So each step paid for two rebinds, each about 540k instructions: `Parameters` validation, a node schedule built again, a field build in `reset()`, and every node constructed afresh.

The pass now holds one `active_system`, and `active_system::reseat(passive)` brings it to the double patch's width before each range and each introduction. For plant that is `Patch::assign_from`, which removes or adds nodes at the newest end and copies the birth records, the state and the environment, at about 69k instructions. Rebinds fall from 237 to 2. A System without `assign_from` is rebound as before.

## [5] One sweep per independent metric seed

The reverse pass is linear in its seed. If one metric's seed is a combination of others', its adjoints are the same combination of theirs, for the state rows and the parameter rows. `solve_adjoint` now picks a basis of the seed rows, sweeps only those, and rebuilds the rest at the end. A row is left out only if its residual against the rows before it is below 1e-14 of its norm.

FF16 has such a pair. `offspring_production` is the fitness integral weighted by the birth rate at each node's introduction, and `net_reproduction_ratio` is the same integral with weights of one. At a constant birth rate their seeds are proportional, so each species needs one sweep for both. That is 4 sweeps for 5 metrics with one species, and 7 for 11 with four species, where it saves 20%.

## [6] The field reduction as one statement per knot

`Species::field_splits` reduces the nodes to three running moment sums. Each knot's competition is those sums weighted by `z^(k eta)`, plus a correction for the interval its height crosses. The weighted sum is now recorded as one statement per knot, with rows on the moment sums and the height. That is worth 2% at one metric and 6% at five.

## Cost per column

The issue times one metric and one column and finds finite differences cheaper below about 12 traits. The reverse pass gives every column for the same price, so its cost is shared over all of them. One-sided differences cost at least one run per column and give every metric from each run.

| | columns | reverse pass / run | runs per column |
| --- | --- | --- | --- |
| FF16, #679, 5 metrics | 32 | 27x | 0.84 |
| FF16, now, 1 metric | 32 | 5x | 0.15 |
| FF16, now, 5 metrics | 32 | 7x | 0.22 |
| TF24, #679, 1 metric, lifetime 2 | 48 | 3x | 0.06 |

Finite differences now come out ahead only below five to seven traits. Most of a TF24 run is `solve_leaf`, which the reverse pass loads from the recording without solving again, so TF24's pass was already a small multiple of its run. FF16's run has no such step: every operation in its rates is recorded.

## How we measured

The ratio was counted in instructions, with callgrind collecting only inside `census_trait_gradient_ff16`. Wall clock varied too much between runs to separate one change from the next, so it was used only to confirm, in interleaved runs. Measurements are at lifetime 60. At lifetime 8 the seedling's height averages 82% of the canopy top over the run, and changes that depend on canopy structure barely show.

Each build was checked against the previous one before its numbers were read: values identical, counts of finite and bit-identical gradient entries, the largest relative change, and any entry that had dropped to zero. Both test suites ran on both builds and their failure sets were compared.

Most changes came from reading the tape. `tools/live*.cpp` records one rate evaluation, walks it backwards from the rates, and marks every statement as read or dead and whether it depends on parameters alone. It also lists each statement's operands by kind: parameter, state, spline knot or intermediate. The copies in [1] showed up as one-operand statements. The repeated work showed up as identical operand lists within one node. Three further cases were recorded but never read:

- a height above a crown, recorded as zero times active factors;
- the height scan copying every node's height;
- the field built in full for a boundary node that reads it only below its own height.

## What did not help

| tried | result |
| --- | --- |
| Vector adjoints, `AReal<double, 5>`, one sweep for five metrics | 1.5x slower than five scalar sweeps |
| One backward walk carrying five adjoints per slot | The same time as five sweeps; each update is a scattered load and store either way |
| Preaccumulating the crown on a local tape | Exact; costs about what it saves below three metrics |
| `XAD_TAPE_REUSE_SLOTS` | Recording 64% slower |
| Skipping zero multipliers in the sweep | Sweep 5.5% faster, recording 5.6% slower |
| Moving rates out of `Internals` on write-out | Not done: a later reader would get a value with no derivative, and nothing would report it |
| Registering only the requested traits | 3.5% at one metric, 5.6% at five |
| The boundary interval's competition as rows | Sweep 6% faster per metric, recording 4% slower |

## What is left

Recording is now about 3.9 times the double evaluation and 80% of a one-metric gradient. About 30 points of that is XAD's per-statement bookkeeping: each operation is written to a stack buffer, then copied into the tape. The RK stage combinations are also recorded, although they are fixed linear algebra. Each is an estimated 5–8%.

A step's recording reads only the recorded forward state, never the adjoint, so steps could be recorded on other threads ahead of the sweep. Recording one step tape on 4 threads ran 2.8–3.1 times faster than serially. That needs thread-local XAD tapes, which cost 7–10% more instructions on one thread.

On the question in the issue, the route that worked is the second one: compute each cohort's value and partials in double and record one statement. Preaccumulating on a local tape cost about what it saved. We did not try source transformation.

## How it will land

A review of the spikes (`REVIEW.md`) changes two things before they become PRs.

`assimilation_deep_crown_rows` is a second implementation of `assimilation_deep_crown`, kept equal to it by hand. It will become one loop over `crown_fractions` at both scalars, with the partials and the recording compiled in only for the active scalar.

The spline keeps its span coefficients active although, after [2], nothing reads them: 256 dead statements per field build. It will store them in double and record an active read as one statement over the span's four knot values and slopes. Two of the odelia changes in [3] then become unnecessary.

The cut to the field built for the boundary node threads a parameter through three environments for 1%, and will be dropped.

The PRs, in order:

1. plant: no copies or repeated work on the active rate path [1].
2. odelia: 12-byte operations and no `memmove` per statement [3].
3. odelia: active spline reads over the knot data.
4. odelia: `record_with_derivatives` taking rows as two arrays.
5. plant: the crown integral as one statement [2].
6. odelia and plant: one active System for the whole pass [4].
7. odelia: one sweep per independent metric seed [5].
8. plant: the field reduction as one statement per knot [6], if it can take the same one-function form as the crown.
