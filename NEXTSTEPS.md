# Next steps: make the reverse-mode gradient agree with its design

This document is the plan of record for the reverse-mode gradient. It tells you
what to build, in which order, and how to check each step. It is written in
Simplified Technical English (ASD-STE100). Section 12 lists the deviations.

The gradient is correct in structure. It is too slow to use, and four of its
columns are wrong. It is too slow because the implementation repeats work that
the design does one time. This document removes the repetition and the four wrong
columns. It does not change the design.

---

## 1. The stop, which outranks each cost task

**Recorded 2026-08-03. The adjoint disagrees with a forward tangent and with a
converged finite difference on two of three census metrics. The two references
agree with each other.** At `max_patch_lifetime = 2`, trait `lma`:

| metric | tangent | adjoint | central difference (1e-5) |
|---|---|---|---|
| `leaf_area` | −6.70320364069075 | −6.7018609913628 | −6.89018062193 |
| `mass_above_ground` | −5.00502106067521 | **+1.1236103034985** | −5.18146726765 |
| `area_stem` | −0.00178853862026 | **−0.117481756163** | −0.00183969234031 |

`mass_above_ground` has the wrong sign. `area_stem` is 65 times too large. The
finite difference is stable at steps 1e-4, 1e-5 and 1e-6. It agrees with the
tangent on all three metrics to 2.8 percent to 3.5 percent. `leaf_area` agrees to
2.00e-4, which is three orders above the 1.2e-10 replay noise.

The shape of the failure puts the cause in the seed and not in the sweep. The
sweep is shared between the metrics. A defect in the sweep moves all three
metrics.

Task 5 gives one cause. Task 5 explains `mass_above_ground` and it does not
explain `area_stem` or `k_I`. Therefore at least one more cause exists. Keep the
tangent referee until each metric agrees.

**A separate finding of the same measurement.** The tangent and the finite
difference differ by about 3 percent at each step size. Therefore the difference
is not truncation. `rebind_from` carries `height_0`, `area_leaf_0` and `eta_c` as
values, because `prepare_strategy` and `height_seed` refuse an active scalar. Both
AD paths lose `d(height_0)/d(trait)`. Only the finite difference has it. The
absent `odelia::implicit_value` for `height_seed` is therefore a bias of about 3
percent for `lma` and about 0.09 percent for `k_I`.

**Do not build a cost task before the two columns are explained.** A faster wrong
gradient has no value.

---

## 2. Conditions before you start

Do all four of these before Task 1.

1. Merge `origin/develop` into the AD branch `p3/wave5`. Done on
   `p3/wave5-develop` at `d3392ea3`, not yet pushed and not yet merged back.
2. Merge `origin/master` into the odelia branch `p3/odelia-integration`. Done at
   odelia `a3bcf58`.
3. Land plant #590 in `develop`. Then merge `develop` again.
4. Make the new reference data. Task 0 tells you how.

**WARNING: Compute the merge base again after each fetch. Do not reuse an earlier
value. `git merge-base p3/wave5 origin/develop` returned `141dc8df` before the
fetch and `a307198d` after it, because the fetch moved `develop` forward. A diff
from the old base shows 47 files, and the true upstream change is 24 files. The
old base makes you hunt for fixes that the branch already has.**

**WARNING: The branch deleted `src/tf24_strategy.cpp` and one upstream commit
changed it. Read `git diff <base>..origin/develop -- src/tf24_strategy.cpp` in
full. Then find each change in `inst/include/plant/models/tf24_strategy.h`. Write
one line for each change. If you keep only one side of a modify/delete conflict,
you lose a correctness fix and no test fails.**

For the merge at `d3392ea3` this check was done and all eight upstream changes
were already in the templated header, so no code moved. Two other fixes were
absent and were transplanted by hand: the rates-on-read change in `patch.h`, and
the sort guard in `Species::consumption_rate` for an inverted height grid.

---

## 3. Technical names in this document

| Name | Meaning |
|---|---|
| the block | `Individual::compute_rates` at the active scalar, recorded one time for one cohort at one Runge-Kutta stage |
| the bundle | the local Jacobian of the leaf at its operating point, with one row for each output |
| the graft | `value + sum_i partial_i * (x_i - to_passive(x_i))`, which is zero in value |
| the seed | the output adjoints that start one reverse sweep |
| the census | a sum of one quantity over the size distribution |
| birth date | the time when the solver introduced a cohort |
| the tabulation | a 100-knot table of the cumulative vulnerability integral |

---

## 4. The measurements that set the order

Each number below is measured. Section 11 gives the values that are calculated
from them. A number moves to a different machine only if it is a count or a
ratio.

**Measurement A, plant `dad51118`, odelia `3bb2e46`, TF24, one species,
`max_patch_lifetime = 3`, 8 nodes, `ode_size = 73`, 140 accepted steps, 5 soil
layers, `GSS_tol_abs = 1e-1`, `-O2 -DNDEBUG -g0`, one Xeon at 2.80 GHz.**

| Quantity | Value |
|---|---|
| `Leaf::input_adjoints` calls | 144 072 |
| `input_adjoints` calls for each block | 10.64 |
| `dprofit_droot_collar_psi` calls for each `input_adjoints` call | 35.0 |
| root-finds for each `input_adjoints` call | 100.0 |
| tabulation rebuilds for each `input_adjoints` call | 2.0007 |
| share of the reverse pass inside `input_adjoints` | **98.16 percent** |
| gradient wall clock | 292.35 s, this machine only |

**Measurement B, the same tree at production.** `max_patch_lifetime = 105.32`,
`lma`, 141 nodes, 1 137 states, 4 644 accepted steps: **2 995 s**, peak memory
**0.262 GiB** against a 2 GB limit.

**Measurement C, one leaf call with a general seed against six calls with unit
seeds.** Four states, 28 inputs, two interior and two pinned. The largest relative
difference is **4.4e-16**. No entry of 112 is above 1e-14. The ratio of the times
is **5.97 to 6.11**.

**Measurement D, the tabulation.** One 100-knot tabulation costs **121.2 us**. One
closed-form value costs **0.074 us**. One value with `d/da` and `d/dx` on a reused
tape costs **0.68 us**. A new tape for each call costs **34.8 us**. Therefore the
bundle needs a tape that lives longer than one call.

**Measurement E, the four hydraulic columns are wrong.** The tabulation builder
sets `psi_max = b * log(100)^(1/c)` and `step = psi_max / resolution`, under a loop
bound of `psi <= psi_max`. Therefore the knot **count** steps between 100 and 101
when `b` or `root_b` moves by 1e-6 relative. Held grid against moving grid:

| quantity | held grid | moving grid | ratio |
|---|---|---|---|
| `dR/d(root_b)` | 3.541221 | 168.3776 | 47 |
| `d(profit)/d(root_b)` | −2.2215 | −290.86 | 131 |
| `d(bound_a)/d(root_b)` | 1.68651 | 17279.08 | 10 245 |

**Measurement F, trait masking.** A spike on `p3/trait-mask` (`5fb631a1`,
`1a06e4c5`) gave **6.68 times** for `traits = "lma"` at lifetime 0.2, and
**1.00 times** when all four hydraulic rows were requested. Therefore the whole
saving is those four rows. The forward run stayed bit-identical at
`42.411799695604159` over 4 644 accepted steps.

**What the measurements mean for the order.** Today everything outside
`input_adjoints` can give 2 percent at the most. After Task 1 and Task 2,
`input_adjoints` is about 30 times cheaper. Then the work outside it is about a
third of the total. Therefore Task 9 is forbidden now and useful later. Read
Section 10 before you do work outside `input_adjoints`.

---

## 5. Task 0: make the new reference data

Do this task after #590 lands. Do not do it before.

#590 changes the coordinate of the size distribution. TF24 offspring production
moves from 42.14 to 400.9. Each earlier reference number is then wrong.

1. Check out the branch `p3/tangent-referee`.
2. Run `scripts/tangent-reference-driver.R` on the merged tree.
3. Write the new `scripts/tangent-reference.csv`.
4. Make sure the header records the plant commit, the odelia commit, the lifetime,
   the node count, the step count and the `Control` values.

**WARNING: If you make the reference data before #590 lands, the reference refutes
correct code. The old file records its own plant commit. Use that record to see
the difference.**

The forward tangent costs more than 20 times a `double` run at production.
Therefore use it at a short lifetime.

**What the tangent cannot check.** `graft_leaf_outputs` runs for the forward type
and the reverse type. Both read the same `double` rows from
`Leaf::input_adjoints`. Therefore a wrong row cancels between them. Use the gate
in Task 1 for those rows.

---

## 6. Tasks that correct the gradient

### Task 1: give the leaf one bundle

Type: cost. Factor: about 5.3. It also removes a hazard, so do it first.

**Why.** `Leaf::input_adjoints` computes the full local Jacobian of the leaf. Only
five quantities in the function use the seed: `uptake_dm` at line 1617,
`s_adjoint` at lines 1670 to 1673, `mu` at line 1854, `w` at line 1840, and the
sums that write the result. Each of the five is linear in the seed. All other work
is independent of the seed.

`TF24_Strategy::graft_leaf_outputs` calls the function `1 + max_soil_layer` times,
one time for each output row. Therefore the code computes one Jacobian
`1 + max_soil_layer` times. `max_soil_layer` follows the rooting depth
`min(height, 1.5)`. Therefore the count is 4 to 6 for seedlings and 12 for a
mature stand, and per-block cost is not a constant of the model.

**Steps.**

1. Add `void Leaf::output_rows(std::vector<std::vector<double>>& rows)` to
   `inst/include/plant/leaf_model.h`.
2. Move the body of `input_adjoints` into `output_rows`. Keep the order of the
   statements. Do not move a statement that reads leaf state.
3. Change `dE_dm` to an `n` x `n` matrix. Line 1617 of `src/leaf_model.cpp` is the
   only seed contraction inside a loop that is independent of the seed. Do not
   scale the matrix. Line 1619 scales `dEup_dm` after the loop.
4. Put the branch on `collar_pinned_` above the row loop. Write two row loops. Do
   not put the branch inside one row loop.
5. Write the seed as a literal value in each row: use `(q == j + 1 ? 1.0 : 0.0)`.
   Do not remove a multiplication because one factor is zero.
6. Keep `input_adjoints`. Make it a contraction over `rows`.
7. Change `graft_leaf_outputs` to call `output_rows` one time. Graft each row.
8. Mask `Leaf::bound_partials` in the same way, or the pinned branch pays the cost
   again. It carries its own loop over the same four parameters.

**Compute the rows during the record step. Do not compute them later.** A lazy
form is possible and it is not safe here. `Individual::log_density_rate` calls
`growth_rate_gradient`, which copies the individual, shares the strategy and
therefore the leaf, and solves the leaf again at `height − 1e-6`. Therefore a
Jacobian computed after the record step reads the operating point of the probe and
not the operating point of the graft. An eager bundle cannot have this defect.
The graft also works for the forward type, and a tape callback does not, so an
eager bundle keeps the tangent referee of Task 0.

**WARNING: `layer_flux_partials` gives NaN at a branch kink. Today the profit row
computes `0.0 * NaN`, which is NaN. If you remove the multiplication, the result
becomes 0.0. This change is silent, and a test that uses `==` accepts it.**

**How to check.** Compare the bit pattern of each value. Do not use `==`.

1. Record `input_adjoints(1.0, 0, v0)` and `input_adjoints(0.0, e_j, v_j+1)` on the
   old build.
2. Call `output_rows(rows)` on the new build at the same leaf state.
3. Make sure each `rows[q][i]` has the same bit pattern as `v_q[i]`.
4. Make sure the leaf state after one `output_rows` call has the same bit pattern
   as the leaf state after `1 + n` old calls. Compare `ci_`, `profit_`, `E_up_`,
   `soil_consumption_`, `opt_psi_stem_`, `root_collar_psi_`, `PPFD_`,
   `leaf_specific_conductance_max_`, `collar_pinned_`, the 15 parameter members,
   `psi_soil_`, `vcmax_`, `R_d_`, `jmax_` and `electron_transport_`.
5. Do the check at three states: an interior operating point, a pinned operating
   point, and a state where `layer_flux_partials` gives NaN.
6. Do the check on a block that has two grafts. A block with one graft passes even
   when the operating point is wrong.

**WARNING: A finite difference of the block cannot check these rows. The graft is
zero in value for each grafted input. Therefore the value of the block does not
change when a row is wrong. Eleven trait columns read exactly zero for two waves
of work for this reason. The rows of the leaf are the only referee.**

### Task 2: build the tabulation only when a hydraulic row is wanted

Type: cost. Factor: about 5.7. Two lines of code.

**Why.** `Leaf::input_adjoints` builds two tabulations on each call, at lines 1689
and 1691. `Leaf::bound_partials` builds two more, at lines 1456 and 1458. Only
`set_parameter` reads them, and only for `b`, `c`, `root_b` and `root_c`.
Measurement A gives 2.0007 rebuilds for each call. Therefore they run always.

**Steps.**

1. Put the two calls in each function under one condition. The condition is
   `par_wanted(PAR_B) || par_wanted(PAR_C) || par_wanted(PAR_ROOT_B) ||
   par_wanted(PAR_ROOT_C)`.
2. This set is the set that `rebuilds_transport` gives. Do not write a second
   list.

**How to check.** The tabulation count for a run that wants no hydraulic row must
be 0. Each row must keep its bit pattern.

### Task 3: mask the parameters of the leaf

Type: cost. Factor: 6.68 measured, for a trait that is not a leaf parameter.

**Why.** The leaf differentiates all 15 of its parameters on each call. Only 11 of
the 44 registered traits are leaf parameters. `lma` is not one of them: it reaches
the leaf through `area_leaf`, which is a state input, so the graft supplies its
row. Therefore a gradient for `lma` needs no parameter row at all.

`ad_parameters()` has 44 entries and it does not include `vcmax_25` or `jmax_25`.
The graft term of those two is zero by structure. Therefore the code computes 2
analytic partials and 4 residual pairs for no result on each call today.

**Steps.**

1. Make the requested trait set reach C++. Today `stand_gradient(scm, traits =)`
   subsets a matrix in R and `census_trait_gradient_tf24` takes one argument.
2. Add a trailing argument `const std::vector<bool>& par_active` to `output_rows`.
   An empty vector means all parameters are active.
3. Build the vector one time in `graft_leaf_outputs`. Test each parameter name
   from `Leaf::inputs()` against the names from
   `TF24_Strategy::ad_parameter_names()`.
4. Extend the guard at line 1794 of `src/leaf_model.cpp` with `|| !par_active[k]`.
   Add the same guard to the seven analytic partials at lines 1743 to 1792.
5. Mask `Leaf::bound_partials` in the same way.

**WARNING: A masked row must be absent and never zero. A row of exactly zero reads
as an answer. This is the worst failure mode of the design. Poison a masked row
with NaN. Compact `x` and the row so the NaN cannot enter arithmetic. Refuse an
absent column by name at the boundary.**

**WARNING: Take the mask from the registration list `ad_parameter_names()`. Do not
take the mask from an opinion about which parameters are important. A parameter
that is registered and masked gives a gradient row of exactly zero, and nothing
reports it.**

Read `Patch::cohort_block_adjoint` first. Make sure that no other code path
registers a smaller set of parameters. If another path exists, pass the mask from
the place that chooses the targets.

**How to check.** Set every entry of `par_active` to true. Each row must keep the
bit pattern from Task 1. Then request a masked row and make sure the code refuses
it by name.

### Task 4: put the transport algebra in closed form

Type: **correctness**. Measurement E shows the four hydraulic columns are wrong
now.

**Why.** `b`, `c`, `root_b` and `root_c` get their rows from a central difference
across a grid whose knot count changes with the parameter. The errors are 47, 131
and 10 245 times. Task 2 and Task 3 make those columns cheap to skip. They do not
make them correct. Only this task does.

The object in the tabulation is the lower incomplete gamma function. With
`a = 1/c` and `X = (m/b)^c`:

```
integral from 0 to m of exp(-(s/b)^c) ds = (b/c) * gamma(1/c, X)
```

`odelia::incomplete_gamma<S>(a, x)` computes this as a series of elementary
operations. Therefore a tape reads the value, `d/dx` and `d/da` from the same
code. It agrees with the tabulation to 1.42e-15 for the stem and 1.67e-15 for the
root, over 4 001 points. The endpoint derivative `dG/dm = exp(-(m/b)^c)` is
recovered to 9.0e-14 and 2.3e-13. `dG/db` and `dG/dc` match a central difference
of the closed form with a clean plateau in all 16 cases.

**Why closed form and not a cache.** The forward solve makes many queries for each
solve, so a 100-evaluation build is spread over them and the table is correct
there. The derivative path makes `n + 2` = 7 queries and then discards the table.
Therefore it pays 100 evaluations to answer 7. A cache makes a wrong structure
cheap. It does not remove it.

**Build it in two stages.**

- **Stage A. No new baseline.** The reverse path uses the closed form. The forward
  tabulation keeps `boost::math::tgamma_lower`. The forward model is
  bit-identical, because no code on the `double` path changes.
- **Stage B. With a new baseline.** The forward tabulation is built from
  `incomplete_gamma`, so one definition remains. This moves the offspring value
  and the accepted step count. It needs the owner and a `scientific_version`
  change.

**WARNING: The series gives NaN for `x` above about 700. This is unreachable here
by construction, because `X(psi_max) = log(100)` for any `b` and `c`, so
`x <= 4.605`. Write an assertion. Do not rely on the argument.**

Use a tape that lives longer than one call. Measurement D gives 34.8 us for a new
tape against 0.68 us for a reused one. `Patch::cohort_block_adjoint` already holds
one as `block_state::tape`. Follow it. No active value may outlive a recording,
because `clearAll()` returns the slot counter to zero.

**Read this before you scope the task.** `psi_from_transpiration` is the inverse of
the same integral. If the derivative path reads it, it needs
`odelia::implicit_value` on its residual, and then `dpsi/dG = 1 / G'(psi) =
exp((psi/b)^c)`. `find_psi_stem_from_psi_root` reads it, and that function is part
of the `double` forward solve. Therefore it may not be on the derivative path at
all. Check. Do not assume either answer.

**How to check.** Compare all 15 rows against the differenced rows at
production-like states, with the difference step swept and a plateau required.
Check the four hydraulic rows against the closed form's own AD as well. That is
the only reference that does not cross the knot-count step. **Do not use the
stationarity identity of report 02 section 6.9 as a reference.** `dp*/du` is formed
from `Pi_pp`, so it cancels, and a real 2 percent error in `Pi_pp` passed that
identity with the same bits before and after the fix.

### Task 5: add the direct trait term of the census

Type: **correctness**. One cause of the stop in Section 1.

**Why.** The gradient of the census has two terms:

```
d(census)/d(trait) = d(census)/d(trait) at fixed state
                   + integral of the adjoint over the trajectory
```

`SCM::census_state_adjoint` registers only the ODE state as an input. Therefore the
run gives the second term and not the first. The first term is not zero. Each
metric reads the strategy directly. `area_leaf` reads `a_l1` and `a_l2`.
`mass_leaf` reads `lma`. `mass_sapwood` and `mass_bark` read `rho`.

**Steps.**

1. Register the parameters from `ad_parameters()` as inputs of
   `census_state_adjoint`, with the ODE state.
2. Return the trait columns beside the state columns.
3. Add the trait columns to `trait_adjoint` before the sweep starts.
4. Move `clear_trait_adjoint()` to a point before the seed is taken. Today it runs
   after the seed and it removes the term.

**How to check.** Compare against the tangent from Task 0. Use `lma`, which
reaches the census through `mass_leaf`. Use `k_I`, which does not reach the census
algebra, and make sure its result does not change.

This task explains `mass_above_ground`. It does not explain `area_stem`, whose
inputs are functions of `area_leaf` only, and it does not explain `k_I`. Continue
to look for the second cause. Section 9 gives the places to look.

### Task 6: assert that the sweep covers the trajectory

Type: correctness. Small.

**Why.** `SCM::census_trait_gradient` builds the segment list from the width
changes between recorded states. It then sweeps from `boundary[0]` up. Nothing
asserts that `boundary[0]` is 0. Nothing asserts that the segments join. If
`boundary` is empty, the loop body never runs, and the function returns a row of
exactly zero with nothing raised.

**Steps.** Assert that the swept segments cover every recorded step. Refuse an
empty segment list. Do not return a zero row.

### Task 7: give the competition adjoint the unordered path, or refuse it clearly

Type: correctness. Check whether #590 removes the need.

**Why.** `Species::compute_competition_and_slope_adjoint` raises `util::stop` when
the node heights are not descending. The forward path has
`compute_competition_unordered` for exactly that state, because reserve-gated
growth lets cohorts cross. Therefore the forward model runs and the adjoint stops.

Under #590 the abscissa is the introduction time, which cannot invert. Therefore
this path is unreachable on the birth-date coordinate. Check that first. If the
height coordinate stays supported, write the transpose. Do not leave a `stop` on a
path the forward model survives.

**The same defect has a second instance, and this one is silent.**
`Species::consumption_rate_adjoint` is no longer the transpose of
`Species::consumption_rate`. The forward function now sorts the node grid when the
heights invert. The adjoint still transposes the unsorted trapezium. Therefore the
two disagree on an inverted grid, and nothing raises an error: the gradient is
finite and wrong. This is the one place where the upstream fix and the reverse-mode
surface are not independent of each other. Make the adjoint read the same sorted
order that the forward function uses, or refuse the state as Task 7 refuses it.

---

## 7. Tasks that #590 requires

### Task 8: move the reductions to the birth-date abscissa

**Why.** #590 carries the size distribution as a density in birth date. The two
resource integrals then use the introduction time as the abscissa. The reductions
of the AD branch still use height. #590 cannot change them, because they do not
exist in `develop`.

**Steps.** Change the abscissa in each of these to `Species::abscissa_of`:

1. `Species::census`
2. `Species::consumption_rate_adjoint`
3. `Species::compute_competition_and_slope_adjoint`
4. the census seed in `SCM::census_state_adjoint`

**Result.** The quadrature weights become constants, because the introduction time
is fixed at birth and it is passive. Therefore the weight derivative term is
exactly zero. Report 00 section 6.3 gives it as `h_bar_k += sum_i U_bar_i n_k
c_ki d(w_k)/d(h_k)`. Remove it. Report 00 section 8 item 3 names it as the term a
person is most likely to forget.

**WARNING: `Node::growth_rate_at_birth()` is a `double`. The code sets it from
`individual.rate(HEIGHT_INDEX)` at birth. It depends on the traits, on the light
field and on the soil. Therefore it carries a derivative, and the `double` type
removes that derivative.**

Today only `Species::height_jacobian()` reads it, and only R reporting code reads
`height_jacobian`. Therefore the gradient is safe today. It stays safe only while
this condition holds:

- The census integrates over birth date and it never divides by the Jacobian.

The condition is correct mathematics, because the Jacobian cancels. Keep it true.
Do not put a metric that reads `height_jacobian` on the gradient path.

### Task 9: remove the transport seed

**Why.** With a density in birth date, `log_density_dt` is `-mortality` alone. The
block already gives the mortality rate as an output. Therefore the transport
output repeats an output that exists.

**Steps.**

1. Remove the transport output from `Individual::block_outputs`.
2. Add the transport seed to `seeds.rate[MORTALITY_INDEX]` with a minus sign.
3. Delete `Patch::transport_adjoint` and `seeds.transport`.

**Result.** The block has 11 outputs and not 12. Report 01 section 1 step (a) gives
`lambda_g` for each cohort. That seed has no source now. The order of the seeds
becomes less strict, because no seed reads a neighbour.

This also removes the second leaf solve from each block, because
`growth_rate_gradient` no longer runs. Therefore the calls in Task 1 fall from
about 10.64 for each block to about 5.3 before Task 1 is applied.

---

## 8. Tasks for cost, after Task 1 and Task 3

Do these after Task 1 and Task 3. Before those tasks they give 2 percent at the
most. After them, the work outside `input_adjoints` is about a third of the total.

### Task 10: sweep one recording with many seeds

Type: cost. Factor: 3.0 for three metrics. Do it last of the cost tasks.

**Why.** `SCM::census_trait_gradient` runs one complete reverse pass for each
census metric. The expensive part of a pass is the record step and not the sweep
step. Therefore the code records the same block three times. It also runs
`widen_over_introductions` and the stage rebuild three times.

**Steps.**

1. Add a seeds-plural form of `odelia::ode::vector_jacobian_product`. Record one
   time. Then, for each seed set: clear the derivatives, set the output adjoints,
   call `computeAdjoints()`, read the input adjoints.
2. Use `getPosition()` and `clearDerivativesAfter()`. XAD gives both. Note that
   `vector_jacobian_product` calls `clearAll()` and `newRecording()` on entry
   today, which destroys the recording this task must reuse.
3. Carry `K` columns through `Solver::solve_adjoint` and `Step::step_adjoint`.
4. Carry `K` columns through `Patch::ode_rates_adjoint` and
   `Patch::cohort_block_adjoint`. Record one time and sweep `K` times.
5. Make `trait_adjoint` hold `K` accumulators. Run `widen_over_introductions` one
   time.
6. Remove the metric loop from `census_trait_gradient`.

**WARNING: The narrowing between segments must apply to all `K` columns. Check per
column. `Patch::ode_state` is species-major, so the per-species newcomer list is
shared between the columns.**

**WARNING: This task changes signatures in odelia. odelia calls such a change
`cross-package` and `breaking`.**

**How to check.** Each column bitwise equal to the single-seed sweep for that
metric. Linearity makes exact agreement the expectation and not a tolerance.

### Task 11: reuse the leaf operating point

Type: cost. Memory: about 101 kB of transient scratch.

**Why.** `ode::derivs` at stage `i` solves every cohort's leaf to build the stage
rate. `cohort_block_adjoint` at stage `i` then solves the same leaf again at the
same inputs. Both loops are inside one `step_adjoint` call. Therefore the
operating points do not cross a step boundary. Six stages by 141 cohorts by about
15 doubles is about 101 kB.

`scripts/aux_round_trip.R` measured that restoring the inputs and the stored
operating point reproduces 14 leaf outputs bit-identically at 8 of 9 states. The
ninth state was P0.1, which is fixed.

**WARNING: This is exact restoration and not a warm start. Report 01 constraint C7
forbids a warm start. The difference is that a restored operating point is the one
the forward pass computed, and a warm start is a guess. Keep the round-trip probe
as the gate that tells them apart.**

### Task 12: cache the six stage fields inside a step

Type: cost. Memory: about 7 kB.

**Why.** The rebuild loop calls `stage_state(i, y, h)` and then `ode::derivs`,
which builds the field at stage `i`. `sweep_stages` then calls
`stage_state(i, y, h)` again and `set_ode_state_and_field` at the same stage
state. Six fields at about 140 doubles is about 7 kB. `aux` is already held for
each stage in this way, so the pattern exists.

Use `Patch::has_recorded_field`, `record_stage` and `replay_step`. They are hooks
with empty bodies today and this is their purpose.

### Task 13: store the stage rates, and do not rebuild them

Type: cost. Factor: about 1.5. Memory: about 724 MB. **Optional.**

**Why.** The last repeated work is the six `ode::derivs` for each step. To avoid
it you must hold `k1` to `k6` without computing them, which means storing them,
and then storing the operating points as well.

```
stage rates       6 x 1137 doubles for each step
operating points  6 x 141 x about 15 doubles for each step
                  = about 156 kB for each step, 724 MB for 4 644 steps
```

**The exchange is linear and there is no better interior point.** A window of `W`
steps with a forward re-run to refill costs one forward step for each step
refilled, which is what the rebuild costs now. Therefore a window buys nothing and
the saving comes only from `W = N`.

Measurement B gives a peak of 0.262 GiB against a 2 GB limit. At `W = N` the peak
is about 1.0 GiB. Build it as a bounded window with recompute as the fallback, so
a longer lifetime or a second species degrades to the present behaviour and not to
an allocation failure.

Report 01 section 1 chose rebuild over store because "storage is independent of
the stage count". That reasoning was correct and it was taken before peak memory
was measured. That is why it can be revisited.

---

## 9. What remains open

Each item below blocks something. Do not treat the list as background.

- **The second cause of the stop in Section 1.** Task 5 explains one column.
  `area_stem` and `k_I` need another cause. Both wrong metrics run through the
  mass and area cascade. `leaf_area` does not. Look at what
  `set_ode_state` refreshes through `update_dependent_aux` and what the cascade
  reads that the reload leaves stale. That is P0.1's class, one level up.
- **The parameter half of `grad(dPi/dp)` is the design's one unbuilt expression.**
  Report 00 section 10 calls it "the single new piece of code the whole design
  needs" and ordered it last. The implementation put a per-parameter central
  difference in its place, and that stand-in is the cost centre. Task 4 supplies
  the transport part. The rest is a derivation. Its conditioning has never been
  measured.
- **Interior production-like leaf states stop inside `input_adjoints`**, through
  `util::stop` in `Leaf::psi_stem_to_ci` when TOMS748 fails to bracket. Therefore
  no gate in this document can be seeded at a state that is both interior and
  production-like. This is a hole under every gate. Fix it before you trust one.
- **Two dry leaf states crashed** inside the solve during the linearity harness,
  before `input_adjoints` was reached. The cause is not known. It is not the
  `util::stop` above.
- **There is no cost gate anywhere.** Nothing asserts that a block costs what it
  was measured to cost. That is how a factor of 300 sat behind a green suite for
  three waves. **Land each task in this document with a cost gate.**
- **`Patch::block_recording_size` and `block_sweeps` are not exported to R**, so
  the instrument for the worst failure mode needs a C++ harness to read. Export
  them.
- **`Species::set_birth_state` is called by no test**, and report 01 constraint C6
  says the reverse pass must restore `pr_patch_survival_at_birth`, which divides
  the fecundity rate.
- **`beta_R_H` and `beta_R_V` have no row**, so a strategy that varies either reads
  exactly zero. Neither is user-seedable today, which is what stops this from
  biting.
- **`psi_crit` and `root_psi_crit` read zero except when pinned.** The pinned gap
  is unexplained: the adjoint reads 0 against a whole-solve difference of
  −2.39e-04.
- **`Patch::cache_ode_step`, `cache_RK45_step` and `load_ode_step` have no caller**
  in either repository, and they are the two known `test-mutant.R` errors.
- **An opportunity, not scoped.** `census_trait_gradient` differentiates the census
  at one patch age. The quantity an ecologist wants is the disturbance-weighted
  integral over patch ages. For an adjoint that is the same single sweep: inject
  `rho(t) d(census)/dy` as a source at each step instead of seeding one time. The
  trait accumulation does not change. Therefore a time-integrated census gradient
  costs the same as a terminal one, where a finite difference pays again at every
  age. `Patch` already carries the weighting.

---

## 10. Work you must not do now

Do not do this work for speed. Measurement A shows it gives 2 percent at the most
on the present build. Read Section 8 first: after Task 1 and Task 3 some of it
becomes worth doing.

1. Do not hoist `dpsi_from_soil_moist_dtheta` out of the cohort loop for speed.
2. Do not change `Species::height_max()` to use the height scan for speed.
3. Do not move the loop-invariant scalar in `consumption_rate_adjoint` for speed.

Correct the calls to `ad_parameters()` at `individual.h:182`, `individual.h:195`,
`individual.h:213` and `patch.h:1479` for a different reason. The comment on
`ad_parameters()` says to call it one time for each gradient and not one time for
each block. The code does not obey its own comment.

---

## 11. What each task gives

Each factor below is calculated from a measurement in Section 4. **No composed
total has been measured.** Composition is where this project's predictions have
failed. Measure each step.

| Task | Factor | Moves forward numbers? |
|---|---|---|
| 1, bundle | about 5.3 | no |
| 2, tabulation guard | about 5.7 for a hydraulic row | no |
| 3, mask | 6.68 measured, for a non-leaf trait | no |
| 4, closed form, stage A | removes the tabulation from the reverse path | no |
| 4, closed form, stage B | — | **yes**, needs the owner |
| 9, transport seed | about 2 | #590 moves them, not this task |
| 10, many seeds | 3.0 | no |
| 11 and 12 | about 1.2 together | no |
| 13, stored stage rates | about 1.5 | no |

Only stage B of Task 4 needs a new forward baseline. #590 needs one, and Task 0
makes it. Each other task is a change of structure or a term that is absent, so
each gate is bitwise equality against the build before it.

**The pattern to remember.** Each large finding of this wave was an idea the
project had already designed, built, or named as owed, and had not wired in:
`odelia::incomplete_gamma`, `odelia::ode::supplied_derivative`,
`odelia::implicit_value`, the operating-point round trip, `set_birth_state`, the
recorded-field hooks, the trait selection. The design was not wrong. A deferred
item took a placeholder, and no document priced the placeholder. **Price the
placeholder.**

---

## 12. Deviations from ASD-STE100

ASD-STE100 permits Technical Names and Technical Verbs. This document uses these
as Technical Names: the names of C++ types, functions, members, files, branches
and commits; `adjoint`, `gradient`, `Jacobian`, `tangent`, `seed`, `sweep`,
`tape`, `cohort`, `census`, `abscissa`, `quadrature`, `trapezium`, `scalar`,
`coordinate`, `mortality`, `trait`, `tabulation` and `birth date`. Section 3
defines the terms this project uses in a special way.

Two other deviations:

1. Some sentences in Section 6 and Section 8 are longer than 20 words. The
   mathematics needs them.
2. The tables use noun phrases and not sentences.
