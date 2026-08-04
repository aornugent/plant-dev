# Next steps: make the reverse-mode gradient agree with its design

This document tells you what to build next, in which order, and how to check each
step. It is written in Simplified Technical English (ASD-STE100). Section 9 lists
the deviations from that standard.

The gradient is correct in structure and too slow to use. It is too slow because
the implementation repeats work that the design does one time. This document
removes the repetition. It does not change the design.

---

## 1. Conditions before you start

Do all four of these before you start Task 1.

1. Merge `origin/develop` into the AD branch. The branch is `p3/wave5`. The
   merge has 18 conflicts. One conflict is a modify/delete conflict on
   `src/tf24_strategy.cpp`.
2. Merge `origin/master` into the odelia branch `p3/odelia-integration`.
3. Land plant #590 in `develop`. Then merge `develop` again.
4. Make the new reference data. Section 4 tells you how.

**WARNING: The branch deleted `src/tf24_strategy.cpp`. The upstream commit
changed it. Move each upstream change into
`inst/include/plant/models/tf24_strategy.h` by hand. Write one line for each
change in the commit message. If you keep only one side, you lose a correctness
fix and no test fails.**

---

## 2. Technical names in this document

| Name | Meaning |
|---|---|
| the block | `Individual::compute_rates` at the active scalar, recorded one time for one cohort at one Runge-Kutta stage |
| the bundle | the local Jacobian of the leaf at its operating point, with one row for each output |
| the graft | `value + sum_i partial_i * (x_i - to_passive(x_i))`, which is zero in value |
| the seed | the output adjoints that start one reverse sweep |
| the census | a sum of one quantity over the size distribution |
| birth date | the time when the solver introduced a cohort |

---

## 3. The measurement that sets the order

One gradient call was measured. `Leaf::input_adjoints` used **98.16 percent** of
the reverse pass. The configuration was: plant `dad51118`, odelia `3bb2e46`,
TF24, one species, `max_patch_lifetime = 3`, 8 nodes, `ode_size = 73`, 140
accepted steps, 5 soil layers, `GSS_tol_abs = 1e-1`, `-O2 -DNDEBUG -g0`.

| Quantity | Value | Type |
|---|---|---|
| `input_adjoints` calls | 144 072 | measured |
| `input_adjoints` for each block | 10.64 | measured |
| `dprofit_droot_collar_psi` for each `input_adjoints` call | 35.0 | measured |
| root-finds for each `input_adjoints` call | 100.0 | measured |
| vulnerability-integral rebuilds for each call | 2.0007 | measured |
| share of the reverse pass | 98.16 percent | measured |
| gradient wall clock | 292.35 s | measured, this machine only |

The counts are integers and they move to a different machine. The wall clock does
not move to a different machine.

Everything outside `input_adjoints` can give you 2 percent at the most. Do not
spend time on it. Task 1 and Task 2 are inside `input_adjoints`.

---

## 4. Task 0: make the new reference data

Do this task after #590 lands. Do not do it before.

#590 changes the coordinate of the size distribution. TF24 offspring production
moves from 42.14 to 400.9. Each earlier reference number is then wrong.

1. Check out the branch `p3/tangent-referee`.
2. Run `scripts/tangent-reference-driver.R` on the merged tree.
3. Write the new `scripts/tangent-reference.csv`.
4. Make sure the header of the file records the plant commit, the odelia commit,
   the lifetime, the node count, the step count and the `Control` values.

**WARNING: If you make the reference data before #590 lands, the reference
refutes correct code. The old file records its own plant commit. Use that record
to see the difference.**

The forward tangent is the referee for the reverse gradient. Two census metrics
disagree with the tangent today: `mass_above_ground` and `area_stem`. Task 3 is
one cause. Task 3 is not the only cause, because `k_I` also disagrees and Task 3
cannot explain that. Keep the tangent referee for this reason.

---

## 5. The tasks, in order

### Task 1: give the leaf one bundle

**Why.** `Leaf::input_adjoints` computes the full local Jacobian of the leaf.
Only five quantities in the function use the seed: `uptake_dm`, `s_adjoint`,
`mu`, `w`, and the sums that write the result. Each of the five is linear in the
seed. All other work is independent of the seed.

`TF24_Strategy::graft_leaf_outputs` calls the function `1 + max_soil_layer`
times, one time for each output row. Therefore the code computes one Jacobian
`1 + max_soil_layer` times.

**Steps.**

1. Add `void Leaf::output_rows(std::vector<std::vector<double>>& rows)` to
   `inst/include/plant/leaf_model.h`.
2. Move the body of `input_adjoints` into `output_rows`. Keep the order of the
   statements. Do not move a statement that reads leaf state.
3. Change `dE_dm` to an `n` x `n` matrix. Line 1617 of `src/leaf_model.cpp` is
   the only seed contraction inside a loop that is independent of the seed. Do
   not scale the matrix. Line 1619 scales `dEup_dm` after the loop.
4. Put the branch on `collar_pinned_` above the row loop. Write two row loops.
   Do not put the branch inside one row loop.
5. Write the seed as a literal value in each row: use `(q == j + 1 ? 1.0 : 0.0)`.
   Do not remove a multiplication because one factor is zero.
6. Keep `input_adjoints`. Make it a contraction over `rows`.
7. Change `graft_leaf_outputs` to call `output_rows` one time. Graft each row.

**WARNING: `layer_flux_partials` gives NaN at a branch kink. Today the profit row
computes `0.0 * NaN`, which is NaN. If you remove the multiplication, the result
becomes 0.0. This change is silent and a test that uses `==` accepts it.**

**How to check.** Compare the bit pattern of each value. Do not use `==`, because
`==` accepts a change from NaN to 0.0.

1. Record `input_adjoints(1.0, 0, v0)` and `input_adjoints(0.0, e_j, v_j+1)` on
   the old build.
2. Call `output_rows(rows)` on the new build at the same leaf state.
3. Make sure each `rows[q][i]` has the same bit pattern as `v_q[i]`.
4. Make sure the leaf state after one `output_rows` call has the same bit pattern
   as the leaf state after `1 + n` old calls. Compare `ci_`, `profit_`, `E_up_`,
   `soil_consumption_`, `opt_psi_stem_`, `root_collar_psi_`, `PPFD_`,
   `leaf_specific_conductance_max_`, `collar_pinned_`, the 15 parameter members,
   `psi_soil_`, `vcmax_`, `R_d_`, `jmax_` and `electron_transport_`.
5. Do the check at three states: an interior operating point, a pinned operating
   point, and a state where `layer_flux_partials` gives NaN.

**WARNING: A finite difference of the block cannot check these rows. The graft is
zero in value for each grafted input. Therefore the value of the block does not
change when a row is wrong. Eleven trait columns read exactly zero for two waves
of work for this reason. The rows of the leaf are the only referee.**

**Result.** `input_adjoints` calls for each block go from 10.64 to about 2. This
is a calculated value, not a measured value.

---

### Task 2: mask the parameters of the leaf

**Why.** The leaf differentiates all 15 of its parameters on each call.
`ad_parameters()` has 44 entries and it does not include `vcmax_25` or
`jmax_25`. The graft term of those two is zero by structure. Therefore the code
computes 2 analytic partials and 4 residual pairs for no result on each call.

**Steps.**

1. Add a trailing argument `const std::vector<bool>& par_active` to
   `output_rows`. An empty vector means all parameters are active.
2. Build the vector one time in `graft_leaf_outputs`. Test each parameter name
   from `Leaf::inputs()` against the names from
   `TF24_Strategy::ad_parameter_names()`.
3. Extend the guard at line 1794 of `src/leaf_model.cpp`. Add
   `|| !par_active[k]`.
4. Add the same guard to the seven analytic partials at lines 1743 to 1792.
5. Leave a masked entry at exactly `0.0`.

**WARNING: Take the mask from the registration list `ad_parameter_names()`. Do
not take the mask from an opinion about which parameters are important. A
parameter that is registered and masked gives a gradient row of exactly zero, and
nothing reports it.**

Read `Patch::cohort_block_adjoint` before you build this task. Make sure that no
other code path registers a smaller set of parameters. If another path exists,
pass the mask from the place that chooses the targets.

**How to check.** Set every entry of `par_active` to true. Then each row must have
the same bit pattern as the row from Task 1.

---

### Task 3: add the direct trait term of the census

**Why.** The gradient of the census has two terms:

```
d(census)/d(trait) = d(census)/d(trait) at fixed state
                   + integral of the adjoint over the trajectory
```

`SCM::census_state_adjoint` registers only the ODE state as an input. Therefore
the run gives the second term and not the first. The first term is not zero. Each
metric reads the strategy directly. `area_leaf` reads `a_l1` and `a_l2`.
`mass_leaf` reads `lma`. `mass_sapwood` and `mass_bark` read `rho`.

**Steps.**

1. Register the parameters from `ad_parameters()` as inputs of
   `census_state_adjoint`, together with the ODE state.
2. Return the trait columns beside the state columns.
3. Add the trait columns to `trait_adjoint` before the sweep starts.
4. Move `clear_trait_adjoint()` to a point before the seed is taken. Today it
   runs after the seed and it removes the term.

**How to check.** Compare against the forward tangent from Task 0. Use `lma`,
which reaches the census through `mass_leaf`. Use `k_I`, which does not reach the
census algebra. The `k_I` result must not change.

---

### Task 4: move the reductions to the birth-date abscissa

**Why.** #590 carries the size distribution as a density in birth date. The two
resource integrals then use introduction time as the abscissa. The reductions of
the AD branch still use height. #590 cannot change them, because they do not
exist in `develop`.

**Steps.** Change the abscissa in each of these to `Species::abscissa_of`:

1. `Species::census`
2. `Species::consumption_rate_adjoint`
3. `Species::compute_competition_and_slope_adjoint`
4. the census seed in `SCM::census_state_adjoint`

**Result.** The quadrature weights become constants. Introduction time is fixed
at birth and it is passive. Therefore the weight derivative term is exactly zero.
Report 00 section 6.3 gives that term as `h_bar_k += sum_i U_bar_i n_k c_ki
d(w_k)/d(h_k)`. Remove it. Report 00 section 8 item 3 names it as the term that a
person is most likely to forget.

**WARNING: `Node::growth_rate_at_birth()` is a `double`. The code sets it from
`individual.rate(HEIGHT_INDEX)` at birth. It depends on the traits, on the light
field and on the soil. Therefore it carries a derivative and the `double` type
removes that derivative.**

Today only `Species::height_jacobian()` reads it, and only R reporting code reads
`height_jacobian`. Therefore the gradient is safe today. The gradient stays safe
only while this condition holds:

- The census integrates over birth date and it never divides by the Jacobian.

This condition is correct mathematics. The Jacobian cancels. Keep the condition
true. Do not put a metric that reads `height_jacobian` on the gradient path.

---

### Task 5: remove the transport seed

**Why.** With a density in birth date, `log_density_dt` is `-mortality` alone.
The block already gives the mortality rate as an output. Therefore the transport
output repeats an output that exists.

**Steps.**

1. Remove the transport output from `Individual::block_outputs`.
2. Add the transport seed to `seeds.rate[MORTALITY_INDEX]` with a minus sign.
3. Delete `Patch::transport_adjoint`.
4. Delete `seeds.transport`.

**Result.** The block has 11 outputs and not 12. Report 01 section 1 step (a)
gives `lambda_g` for each cohort. That seed has no source now. The forced order of
the seeds becomes less strict, because no seed reads a neighbour.

**How to check.** The gradient must agree with the forward tangent from Task 0 to
the same accuracy as before this task.

---

### Task 6: sweep one recording with many seeds

**Why.** `SCM::census_trait_gradient` runs one complete reverse pass for each
census metric. Three metrics give three passes. The expensive part of a pass is
the record step and not the sweep step. Therefore the code records the same block
three times.

**Steps.**

1. Add a seeds-plural form of `odelia::ode::vector_jacobian_product`. Record one
   time. Then, for each seed set: clear the derivatives, set the output adjoints,
   call `computeAdjoints()`, and read the input adjoints.
2. Use `getPosition()` and `clearDerivativesAfter()`. XAD gives both.
3. Carry M columns of lambda through `Solver::solve_adjoint` and
   `Step::step_adjoint`.
4. Carry M columns through `Patch::ode_rates_adjoint` and
   `Patch::cohort_block_adjoint`.
5. Remove the metric loop from `census_trait_gradient`.

**WARNING: This task changes signatures in odelia. odelia calls such a change
`cross-package` and `breaking`. Do this task last.**

**Result.** Blocks recorded go from 13 536 to 4 512 for three metrics. This is a
calculated value.

---

### Task 7: correct the design documents

Add a banner to each document below. State what #590 changed. Do not delete the
old text.

| Document | What to record |
|---|---|
| `docs/reports/04-demographic-transport-term.md` | The compression term is gone. The report has no subject on the birth-date path. |
| `docs/reports/10-density-transport-and-carried-physiology.md` | The same. |
| `docs/reports/00-tf24-dependency-map.md` | Sections 4.4 and 4.6 change. The weight derivative term of section 6.3 is zero. |
| `docs/reports/01-cohort-granular-reverse-sweep.md` | Step (a) of section 1 loses `lambda_g`. Section 3.1 loses one of its two boundary terms. Constraint C6 has a second example, `birth_growth_rate`. |
| `docs/reports/02-leaf-implicit-node.md` | Section 6.8 becomes one bundle for each operating point. |

A blocker that outlived its fix crossed four documents one time before. Write the
banner in the same commit as the code.

---

## 6. Work that you must not do

Do not do this work. The measurement in Section 3 shows that it gives 2 percent
at the most.

1. Do not hoist `dpsi_from_soil_moist_dtheta` out of the cohort loop for speed.
2. Do not change `Species::height_max()` to use the height scan for speed.
3. Do not move the loop-invariant scalar in `consumption_rate_adjoint` for speed.

Correct the calls to `ad_parameters()` at `individual.h:182`, `individual.h:195`,
`individual.h:213` and `patch.h:1479` for one different reason. The comment on
`ad_parameters()` says to call it one time for each gradient and not one time for
each block. The code does not obey its own comment.

---

## 7. Rules for each build and each measurement

1. Build with `-O2`. Put `CXX20FLAGS = -O2 -DNDEBUG -g0` in a Makevars file. Pass
   the file with `R_MAKEVARS_USER`. Use `debug = FALSE`.
2. `pkgbuild::compile_dll()` adds `-UNDEBUG -g -O0` after your flags. The last
   `-O` flag wins. Read the compile log. Make sure one compile line ends at `-O2`
   and has no `-O0` after it.
3. Install odelia from the submodule. Do not use `pkgload::load_all` for odelia.
4. **The odelia in the system library is old. Its headers have no
   `solve_adjoint`.** Install odelia into a new library. Then read the installed
   header and find `solve_adjoint`. Do this check before you build plant.
5. Run `rm -f src/*.o src/*.so` if the load gives `undefined symbol`.
6. Load with `library(plant)`. Then run
   `attach(asNamespace("plant"), name = "plant-internals")`. Without the second
   line you get about 117 errors of the form `could not find function "SCM"`.
7. To change a trait, use `add_strategies(p, trait_matrix(v, "lma"))`. Do not
   write to `pars[["lma"]]`. A direct write does not compute the derived values
   again.
8. Run `test-strategy-ff16-reference-comparison.R` when a number moves. It is the
   bit-identity check for the scalar template work. If its reference numbers
   change, report the change. Do not accept the new numbers.

---

## 8. What each task gives you

| Task | Factor | Type | Moves forward numbers? |
|---|---|---|---|
| 1, bundle | about 5.3 | calculated | no |
| 2, mask | 1.2 or more | calculated | no |
| 5, transport seed | about 2 | calculated | #590 moves them, not this task |
| 6, many seeds | 3.0 | calculated | no |

Tasks 1, 5 and 6 together give about 32. The gradient took 12 hours for 44
traits. Therefore the gradient takes about 20 minutes. This is a calculated
value. Measure it.

Each task is a change of structure or one term that is absent. No task changes a
tolerance. No task changes a stencil. Therefore no task needs a new forward
baseline. #590 needs a new forward baseline, and Task 0 makes it.

---

## 9. Deviations from ASD-STE100

ASD-STE100 permits Technical Names and Technical Verbs. This document uses these
as Technical Names: the names of C++ types, functions, members, files, branches
and commits; `adjoint`, `gradient`, `Jacobian`, `tangent`, `seed`, `sweep`,
`tape`, `cohort`, `census`, `abscissa`, `quadrature`, `trapezium`, `scalar`,
`coordinate`, `mortality`, `trait` and `birth date`. Section 2 defines the terms
that this project uses in a special way.

Two other deviations:

1. Some sentences in Section 5 are longer than 20 words. The mathematics needs
   them.
2. The tables use noun phrases and not sentences.
