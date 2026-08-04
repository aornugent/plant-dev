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

**Diagnosed 2026-08-04. Three separate causes, and Task 6 is none of them.**

1. **The seed is aliased for every metric except the first.** Task 15. This explains
   `mass_above_ground`, `area_stem`, and why `leaf_area` is right: `leaf_area` is row 0
   of `tf24_census`, and only row 0 is sound.
2. **The traits of the field build reach no accumulator.** Task 16. This explains
   `k_I`.
3. **The direct term of the census is absent.** Task 6. This is real and it is
   masked by cause 1. **It explains none of the three numbers above**:
   `d(mass_above_ground)/d(lma)` at fixed state is the `leaf_area` census value,
   `+1.9636` at this configuration, so adding it makes the adjoint more negative and
   not `+1.12`, and it is exactly zero for both `leaf_area` and `area_stem`.

Keep the tangent referee until each metric agrees.

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

Do all five of these before Task 1.

1. Merge `origin/develop` into the AD branch `p3/wave5`. **Done and pushed.**
   `p3/wave5` is at `d3392ea3`.
2. Merge `origin/master` into the odelia branch `p3/odelia-integration`. Done at
   odelia `a3bcf58`.
3. Merge plant #590. It landed upstream at `53d0a200`, "Integrate by age instead of
   height - opt-in flag (#590)". The fork's `develop` is not synced, so fetch it from the
   upstream repository directly. The fresh merge base is `7b5012c2`. Six files conflict;
   two of them are generated and must be regenerated, not merged.
4. Make the new reference data. Task 0 tells you how.
5. Add the guard of Task 0b, which decides which leaf states a gate may use.

**The merge keeps the branch's forward numbers and not the numbers that #585
blessed.** Each of the 39 changes of `7b5012c2` that can move a forward number is
present at `d3392ea3`, so no fix was lost. The branch had most of them already by an
earlier route, and the merge supplied the two that were absent: `rate_environment`
with `cached_environment_index` in place of `environment_ptr`, and the `std::is_sorted`
guard in `Species::consumption_rate`. Therefore the two sets of numbers are two
configurations and not two roundings: 16.88459 against 16.88950 is 4.9e-3 across a
1.7e-3 band, and 307 accepted steps against 293.

**What is bounded and not attributed.** The remaining difference is the branch's own
work, most plausibly the active-scalar templating and the fused light reduction, which
change the knot and slope computation. **Nobody has measured which commit moves it.**
Do not state a cause for it in a document until someone does.

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

## 2b. The reverse gradient runs on the birth-date coordinate only

**Decided 2026-08-04.** #590 adds `Control::node_density_in_birth_date` and
`src/control.cpp` sets it **false**, so the height coordinate stays the forward
default. **The reverse-mode gradient supports the birth-date coordinate only. Every
reverse-mode entry point refuses the height coordinate with an error.**

Refuse at the entry points, not deep in a reduction: `SCM::census_trait_gradient`,
`SCM::census_state_adjoint`, `Patch::cohort_block_adjoint`,
`Patch::introduction_adjoint` and `stand_gradient`. A refusal below those reaches a
caller that has already paid for a recording.

What this buys, and each item is a task that gets smaller:

- **Task 8 needs no transpose.** The introduction time cannot invert, so the
  `util::stop` in `Species::compute_competition_and_slope_adjoint` is unreachable.
  It becomes a correct assertion instead of a defect.
- **Task 9 has one coordinate to serve, not two.** No flag reading inside a reduction.
- **Task 10 may delete `Patch::transport_adjoint` and `seeds.transport` outright.**
- **The second leaf solve goes away by the coordinate change itself**, because
  `log_density_dt` is `-mortality` and `growth_rate_gradient` no longer runs.

What it costs:

- **The forward model keeps both coordinates**, so the forward references at the
  default flag stay valid and no wholesale re-blessing is needed.
- **Every gradient measurement must be taken again with the flag on.** Measurements A
  to G and the stop of Section 1 were taken on the height coordinate, which the
  gradient no longer supports. Their ratios are likely to carry; their absolute
  numbers are not gradient references any more. Task 0 owns re-taking them.

---

## 3. Two names that are not the name of a symbol

Each other term in this document is either the name of a C++ symbol or a standard
term of automatic differentiation. Section 12 lists them.

- **the block** — `Individual::compute_rates` at the active scalar, recorded one
  time for one cohort at one Runge-Kutta stage. It is the unit of the reverse pass.
- **the graft** — `value + sum_i partial_i * (x_i - to_passive(x_i))`. It is zero in
  value, and that property is why a finite difference of a block cannot see it.

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
| rebuilds of the 100-knot vulnerability table for each call | 2.0007 |
| share of the reverse pass inside `input_adjoints` | **98.16 percent** |
| gradient wall clock | 292.35 s, this machine only |

**Measurement B, the same tree at production.** `max_patch_lifetime = 105.32`,
`lma`, 141 nodes, 1 137 states, 4 644 accepted steps: **2 995 s**, peak memory
**0.262 GiB** against a 2 GB limit.

**Measurement C, one leaf call with a general seed against six calls with unit
seeds.** Four states, 28 inputs, two interior and two pinned. The largest relative
difference is **4.4e-16**. No entry of 112 is above 1e-14. The ratio of the times
is **5.97 to 6.11**.

**Measurement D, the tabulation.** The tabulation is the 100-knot table of the
cumulative vulnerability integral that `build_cumulative_vulnerability_integral`
writes. One build costs **121.2 us**. One closed-form value costs **0.074 us**. One
value with `d/da` and `d/dx` on a reused tape costs **0.68 us**. A new tape for each
call costs **34.8 us**. Task 5 takes the two derivatives by hand instead, so no tape
enters the leaf; these figures are what that choice avoids.

**Measurement E, the four hydraulic columns are wrong.** The tabulation builder
sets `psi_max = b * log(100)^(1/c)` and `step = psi_max / resolution`, under a loop
bound of `psi <= psi_max`. Therefore the knot **count** steps between 100 and 101
when `b` or `root_b` moves by 1e-6 relative. Held grid against moving grid:

| quantity | held grid | moving grid | ratio |
|---|---|---|---|
| `dR/d(root_b)` | 3.541221 | 168.3776 | 47 |
| `d(profit)/d(root_b)` | −2.2215 | −290.86 | 131 |
| `d(bound_a)/d(root_b)` | 1.68651 | 17279.08 | 10 245 |

**Measurement F, masking the parameter rows.** A spike on `p3/trait-mask`
(`5fb631a1`) gave **6.68 times** for `traits = "lma"` at lifetime 0.2, and
**1.00 times** when all four hydraulic rows were requested. Therefore the whole
saving is those four rows.

**Measurement G, guarding the tabulation.** A second spike (`1a06e4c5`) put the four
`build_cumulative_vulnerability_integral` calls under the condition that a hydraulic
row is wanted. Pinned at lifetime 0.2 it gave **5.71 times** for `traits = "lma"`
(3.455 s to 0.605 s) and **1.005 times** for all 44 traits. Both spikes left the
forward run bit-identical at `42.411799695604159` over 4 644 accepted steps.

**F and G are two different changes and their figures are not comparable.** F skips
whole parameter rows; G skips only the tabulation those rows need. Do not read
either as a general speedup: both are near 1.00 when a hydraulic row is requested.

**What the measurements mean for the order, and this is the one place it is
stated.** `input_adjoints` is 98.16 percent of the reverse pass, so **everything
outside it can give 2 percent at the most today**. Tasks 1 to 5 all act inside it
and together make it roughly 30 times cheaper. **Then the work outside it is about a
third of the total, and the same tasks become worth doing.** That is the whole reason
Section 8 exists and the whole reason Section 10 forbids its work for now.

---

## 5. Prepare the tree, the guard and the reference data

### Task 0: make the new reference data

Do this task after #590 lands. Do not do it before.

**Take every reference with `node_density_in_birth_date = TRUE`**, because Section 2b
scopes the gradient to that coordinate. TF24 offspring production is expected to move to
about 400 there; that is an expectation and not a measurement.

**The forward references at the default flag are unaffected** and stay as `METHOD.md`
section 5 records them. They remain the cross-model tripwire.

1. Check out the branch `p3/tangent-referee`.
2. Run `scripts/tangent-reference-driver.R` on the merged tree.
3. Write the new `scripts/tangent-reference.csv`.
4. Make sure the header records the plant commit, the odelia commit, the lifetime,
   the node count, the step count and the `Control` values.

**WARNING: a reference must record the flag.** Two configurations now differ in nothing
a commit hash can show. A number without `node_density_in_birth_date` beside it cannot be
checked against anything.

**Re-take the gradient measurements here.** Measurement A's calls for each block, the
share inside `input_adjoints`, and the stop table of Section 1 were all measured on the
height coordinate. Expect Measurement A's 10.64 to fall to about 5.3 on the birth-date
coordinate before any task is applied, because `growth_rate_gradient` no longer runs.

The forward tangent costs more than 20 times a `double` run at production.
Therefore use it at a short lifetime.

**What the tangent cannot check.** `graft_leaf_outputs` runs for the forward type
and the reverse type. Both read the same `double` rows from
`Leaf::input_adjoints`. Therefore a wrong row cancels between them. Use the gate
in Task 1 for those rows.

### Task 0b: give `input_adjoints` the guard its two callers have

Type: correctness. Small. Do it before any gate, because it decides which leaf
states a gate may be seeded at.

**Why.** `Leaf::psi_stem_to_ci` gives TOMS748 the bracket
`[gamma * umol_per_mol_to_Pa, ca_]`. Boost refuses same-sign endpoints. Two
conditions on the leaf make the endpoints agree in sign:

- `assim_max_ < 0`. The upper endpoint is `assim_colimited(ca_)`, which is
  `assim_max_` itself.
- `psi_stem < psi_upstream`. Then `stom_cond_CO2` is negative, which turns the
  supply term over and lifts the lower endpoint above zero.

Each condition means a leaf that does not produce. Therefore the failing states are
the shutdown states, and `Leaf::prepare_collar_solve` exits early on each of them
through `set_shutdown_state`.

`Leaf::set_leaf_states_rates_from_psi_stem` tests both conditions and substitutes
`ci_ = gamma * umol_per_mol_to_Pa` with zero flux. `dprofit_droot_collar_psi` tests
`psi >= psi_stem` only and returns 0. `Leaf::input_adjoints` tests neither: its call
is bare. **The hole is a missing guard and not a bracket that is too narrow.** In
the `assim_max_` mode no root exists in the domain at all, so a wider bracket cannot
help.

**Steps.**

1. Extend the guard inside `psi_stem_to_ci`, which today refuses only
   `!std::isfinite(stom_cond_CO2_fixed)`. Refuse a negative conductance and a
   negative `assim_max_` in the same place, and return
   `gamma * umol_per_mol_to_Pa`. This makes the contract of the function agree with
   the answer its forward caller already substitutes, and it covers each call site
   at one time.
2. Add the `assim_max_` condition to `dprofit_droot_collar_psi`, which carries half
   of the guard now.
3. Make `set_parameter` and the PPFD block compute `assim_max_` again. See the
   warning below.

**WARNING: `assim_max_` is stale under each finite difference of the leaf.** It is
assigned in one place, the last line of `set_physiology`. `set_parameter` computes
`vcmax_`, `R_d_`, `jmax_` and `electron_transport_` again and does not compute
`assim_max_`. The PPFD block computes only `electron_transport_`. Therefore each
displacement of `vcmax_25`, `jmax_25`, `a`, `curv_fact_elec_trans` or `PPFD_` leaves
the guard reading the value before the step while the endpoint reads the value after
it. Near `assim_max_ = 0` a step of `|keep| * 1e-6` makes the guard admit a state
that does not bracket.

**A silent disagreement in the same place, which is worse than the stop.** On the
`-wettest_soil_layer >= psi_crit` branch of `prepare_collar_solve`,
`set_shutdown_state` puts `psi_stem` and the collar potential both at `psi_crit`.
The conductance is then exactly 0, the bracket is valid, and `psi_stem_to_ci`
returns the `ci` at which assimilation is zero. The forward path reports
`gamma * umol_per_mol_to_Pa` for that same state. Therefore the two paths disagree
on a reachable state and nothing raises an error. Step 1 removes this as well.

**How to check.** Seed `input_adjoints` at each of the four early-exit branches of
`prepare_collar_solve` and require a finite result. Then require that `ci` from the
guarded path has the same bit pattern as `ci_` from
`set_leaf_states_rates_from_psi_stem` at each of those states. An interior state
must keep every row bit-identical, because the guard cannot fire there.

**What this changes for the gates in this document.** An interior operating point
excludes both conditions by construction: `prepare_collar_solve` has already passed
`assim_max_ >= 0`, and an interior collar potential has `E_up_ > 0`, therefore
`psi_stem > p`, therefore a positive conductance. The `bound_a` pin has a
conductance of exactly 0 and still brackets. **Therefore an interior,
producing state is the safe class to seed a gate at, and a shutdown or dry state is
the class that needs this task.** Say which class a gate is seeded at.

**`scratch/leaf_jac_gate.cpp` calls `psi_stem_to_ci` directly** before it calls
`input_adjoints`. Seeded at a shutdown state it stops on its own line. Step 1 fixes
this too, because the guard moves into the function.

---

## 6. Tasks that correct the gradient

**The build order is not the number order.** The numbers name the tasks; this list
orders them, and each departure has a reason that was checked against the code.

1. **Task 15 first, before every other correctness task.** It is the cause of two of
   the three wrong metrics, and until it is fixed no other seed defect can be measured:
   a second sweep reads aliased values whatever else is right.
2. **Task 16 next**, because it is the only cause of `k_I` and it is independent of
   everything else.
3. **Task 3's plumbing before Task 2.** Task 2's condition is written with
   `par_wanted`, which does not exist. `leaf_model.cpp` has `rebuilds_transport` and
   no notion of a parameter being wanted. Task 3 builds that notion.
4. **Task 1 before Task 2 and before Task 3's leaf half**, because both edit
   `output_rows`, which Task 1 creates.
5. **Task 5 before Task 4.** `reaches_operating_point` excludes only `psi_crit`,
   `root_psi_crit`, `rho` and `a_bio`, so `b`, `c`, `root_b` and `root_c` are among
   Task 4's eleven parameters. Task 4's gate is the central difference it replaces,
   and Measurement E shows that difference is wrong by 47 to 10 245 times for those
   four. **Four of Task 4's eleven rows would be gated against a poisoned
   reference.**
6. **Task 0b before every gate**, and its own gate must expect the pinned rows to
   move. At the `bound_a` pin `psi_stem` equals the collar potential, so the forward
   guard `psi_upstream >= psi_stem` fires and the forward path reports
   `gamma * umol_per_mol_to_Pa` while `input_adjoints` runs the root-find. The two
   disagree there today. Making them agree changes the pinned rows, so **Task 1's
   bitwise baseline must be taken after Task 0b, not before.**
7. **Take Measurement A again after Task 10.** Every factor in Section 11 is quoted
   against 10.64 `input_adjoints` calls for each block, and Task 10 removes the second
   leaf solve.

**The derivation of Task 4 is not a packet's work.** Eleven mixed second derivatives,
including the implicit-function term of the `ci` root-find, is design. A packet may
not make a design choice. Write the eleven expressions first; then a packet
transcribes and gates them.

### Task 15: give each recording its own active values

Type: **correctness**. It is the largest cause of the stop in Section 1.

**Why.** `SCM::census_state_adjoint` builds the active twin one time,
`auto active = patch.template rebind_from<scalar>();`, and then calls
`odelia::ode::vector_jacobian_product` one time for each metric.
`vector_jacobian_product` starts with `tape.clearAll()`, which returns the tape's
derivative-slot counter to zero. Therefore every active value inside `active` — the
`Internals<scalar>` states, rates and auxs of each node, `new_node`, the knot values of
the spline, the cached `HeightScan` — carries a slot from recording `m` into recording
`m + 1`, where that slot now means something else. **The first metric is sound and each
later metric reads aliased storage.**

Two places in this code already state the rule this breaks.
`Patch::cohort_block_adjoint` says "No active value does: `clearAll()` returns the
tape's slot counter to zero, so a value outliving a recording aliases", and builds a
fresh active strategy for each cohort. `Step::step_adjoint` says "an input carrying a
slot from the previous recording registers as a variable with no dependencies, and its
adjoint sweeps to zero". `census_state_adjoint` is the one place that keeps the value
across recordings.

**Measured, and this is the evidence that ranks it first.** `tf24_census` is
`{leaf_area, mass_above_ground, area_stem}`, so `leaf_area` is row 0. Against a central
difference of the same reduction R computes: `leaf_area` agrees to 2e-5 on both the
height and the `log_density` columns; `mass_above_ground` reads `-0.0077` where the
reference is `+1.2396`; `area_stem` is 52 times too large on height and 283 times too
large on `log_density`; and the heartwood columns of both later rows are **exactly
zero** against a reference of `4.2743`. Rows 1 and 2 correlate with row 0 at 0.04 to
0.17, so this is aliased storage and not a scale error. The census **values** agree to
1e-12, so the forward reduction is sound.

**This also predicts the magnitudes.** `area_stem` is
`theta * (1 + a_b1) * area_leaf + area_heartwood` with `theta = 2.14e-4`, so its true
seed is about 2.5e-4 of `leaf_area`'s. A seed contaminated at `leaf_area` scale is then
about 50 to 300 times too large, which brackets the 65 times of Section 1. For
`mass_above_ground` the contamination is comparable to its own size, which flips a sign
instead of inflating a magnitude.

**Steps.** Build the active twin inside the reduction, so each recording gets values
with no slot from the previous one. Do not move `clearAll` and do not keep the twin.

**Task 11 is the same fix done properly.** Recording one time and re-sweeping with
`clearDerivativesAfter()` removes the repeated recording and the aliasing together.
Task 15 is the small correct fix that unblocks measurement now; Task 11 supersedes it.

**How to check.** The single decisive test is cheap: reorder `tf24_census` to put
`area_stem` first and rebuild. Under aliasing `area_stem` becomes exact and `leaf_area`
becomes wrong. Under any cause that belongs to the metric, `area_stem` stays wrong.
Then, with the fix in, require all three rows to agree with the central difference of
the R reduction.

### Task 16: carry the traits of the field build into the accumulator

Type: **correctness**. It is the only cause of `k_I`.

**Why.** `trait_adjoint` is written in two places, `Patch::cohort_block_adjoint` and
`Patch::introduction_adjoint`. **The field build is in neither.** The block takes the
field as `cohort_reads` inputs, and the transpose of the field itself runs through
`Patch::light_knot_adjoint` into `Species::compute_competition_and_slope_adjoint`,
which returns `node_size_adjoints{height, area_leaf, log_density}` — a structure with
no trait slot. `allometry_adjoint` then scatters it into height and `log_density` only.

`k_I` enters the model **only** through
`TF24_Strategy::compute_competition(z, area_leaf_, height_inverse)`, which is
`pars.k_I * area_leaf_ * canopy_shape.Q(z * height_inverse)`. That is inside the field
build. Therefore its adjoint has nowhere to go and is dropped whole, for every metric,
including the metric whose seed is exact.

**The same loss applies to `eta`**, through `canopy_shape`, and partly to `a_l1` and
`a_l2`, which the field build reads again.

**Steps.** Give `node_size_adjoints` a trait accumulator, or return the trait
contribution beside it, and scatter it into `trait_adjoint` from `light_knot_adjoint`.

**How to check.** Take the gradient for `leaf_area` only, whose seed Task 15 makes
exact, and compare the `k_I` column against a central difference. Before the fix the
adjoint reads zero or near zero and the difference does not.

### Task 1: compute the rows of the leaf one time

Type: cost, and it also removes a hazard, so do it first.

**Why.** `Leaf::input_adjoints` computes the full local Jacobian of the leaf. Only
five quantities in the function use the seed: `uptake_dm`, `s_adjoint`, the interior
branch's `mu`, the pinned branch's `w`, and the sums that write the result. Each of
the five is linear in the seed. All other work is independent of the seed. Verified by
reading every use of `lambda_profit` and `lambda_uptake`; the list is complete, and
`mu` is not independent, being `-s_adjoint / Pi_pp`.

**The list names what varies with the seed. It does not name what you must lift, and
the second set is the saving.** Six blocks are seed-free and move the leaf, so each has
to run above the row loop:

1. `Pi_pp`, being `dR_dcollar_at(p, 1e-6)`, which is three `dprofit_droot_collar_psi`
   calls.
2. The parameter difference loop, up to 11 parameters by 2 sides, of which 4 rebuild
   the interpolants.
3. `dR_dflux_from_layer`.
4. The PPFD residual pair, with its step `h = PPFD_ * 1e-6`.
5. The conductance residual pair, with its step `h = kappa * 1e-6`.
6. On the pinned branch, `dprofit_droot_collar_psi(p)` and `bound_partials`.

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
3. Change `dE_dm` to an `n` by `n` matrix **indexed by the `(j, i)` pair of the
   existing double loop, with only the `i >= j` triangle written and read** — `n(n+1)/2`
   live entries. It is a function of the pair because `q` and `fx.num[i]` both depend on
   `j` and `i`. "An `n` by `n` matrix" alone permits a shape that compiles and is wrong.
   The `uptake_dm` accumulation inside the root-mass loop is the only seed contraction in
   a loop that is otherwise independent of the seed. `d2E_dm` is not contracted, so keep
   one matrix only. **Do not scale the matrix**: the loop scales `dEup_dm` and
   `dslope_dm` by `kg_per_mol_h2o` after it closes, and `uptake_dm` reads the raw value.
4. Put the branch on `collar_pinned_` above the row loop. Write two row loops. Do
   not put the branch inside one row loop.
5. Write the seed as a literal value in each row: use `(q == j + 1 ? 1.0 : 0.0)`.
   Do not remove a multiplication because one factor is zero.
6. Keep `input_adjoints`. Make it a contraction over `rows`. **After step 7 nothing in
   the model calls it and no test calls it**; the two harnesses in `scratch/` do.
   **The contraction does not have the old bit pattern**, because it re-associates the
   sum and adds terms that are exactly zero, so a `-0.0` entry becomes `+0.0`. Decide
   whether the harnesses need the old bits before you write it.
7. Change `graft_leaf_outputs` to call `output_rows` one time. Graft each row.
   **`rows.size()` is `1 + max_soil_layer`, not `1 + soil_consumption_.size()`.**
   `graft_leaf_outputs` loops to `n_layer`, which is the larger, and takes a flat path
   above `max_soil_layer`. Getting this wrong reads past the end of a live vector.

**WARNING: the parameter columns are written with `=` and not `+=`.**
`input_adjoints[i_par0 + k] = ...` assigns. A row loop must keep that assignment inside
each row, or every row but the last loses its parameter columns and reads exactly zero
— the failure mode the last warning of this task describes.

**WARNING: `mu * (R_pm[0] - R_pm[1]) / (2.0 * h)` may not be hoisted as a quotient.**
Hoisting `diff / (2h)` and multiplying by `mu` in the row re-associates and moves bits.
Lift the raw pair and the step; keep the whole expression inside the row loop. **This is
the one place where a reasonable reading of these steps silently fails this task's own
gate.**

**Keep the order of the calls that move the leaf, and not the order of the
statements.** The two are different instructions and only the first is satisfiable
together with step 4: the original interleaves pure writes with state-perturbing
evaluators, and bundling requires each perturbing call to run before any row is
written. A write touches no leaf state, so a write may move. The perturbing calls may
not: `psi_stem_to_ci`, `E_from_Soil_to_Root_Collar`, `layer_flux_partials`, the
parameter loop, `dR_dcollar_at`, `dR_dflux_from_layer`, the PPFD pair, the conductance
pair. Read step 2's rule as "do not move a statement whose value depends on a leaf
member that a later statement writes"; read literally it forbids the change, because
almost every statement reads leaf state.

**`uptake_dm` may be separated from the loop that carries it.** Its terms are disjoint
from `dEup_dm`'s and `dslope_dm`'s, so a `j`-then-`i` loop with `i` ascending from `j`
gives the same bits.
`Leaf::bound_partials` is **not** part of this task. It has no seed dependence, so
it has nothing to bundle. What it needs is the mask, which is Task 3.

**Compute the rows during the record step. Do not compute them later.** A lazy
form is possible and it is not safe here. `Individual::log_density_rate` calls
`growth_rate_gradient`, which copies the individual, shares the strategy and
therefore the leaf, and solves the leaf again at `height − 1e-6`. Therefore a
Jacobian computed after the record step reads the operating point of the probe and
not the operating point of the graft. Rows computed during the record step cannot
have this defect. The graft also works for the forward type, and a tape callback
does not, so computing them during the record step keeps the tangent referee of
Task 0.

**WARNING: `layer_flux_partials` gives NaN at a branch kink. Today the profit row
computes `0.0 * NaN`, which is NaN. If you remove the multiplication, the result
becomes 0.0. This change is silent, and a test that uses `==` accepts it.** Keep the
multiplication, so the gate of this task compares like with like. **The NaN itself is
a defect and Section 9 owns it.** Do not try to fix it here: this task must be
bit-identical, and that fix is not.

**WARNING: the old code does not restore `PPFD_`, so its rows are not the rows of one
Jacobian.** The PPFD residual pair restores by accumulating arithmetic and not by
assignment:

```
h = PPFD_ * 1e-6;  PPFD_ += h;  PPFD_ -= 2h;  PPFD_ += h;
```

`fl(fl(fl(P + h) - 2h) + h)` is not `P`. It returns at `PPFD = 900`, 1000 and 800, and
it drifts one unit in the last place at 1500, 1200 and 1e-3. Therefore the old code
takes row 0 at `P`, row 1 at `P` plus one step, row 2 at `P` plus two steps, and so on.
Measured at `PPFD = 1500`: **40 of 810 entries disagree, to 2.087e-06 relative**, in the
columns that read `PPFD_` or its step — `PPFD`, `jmax_25`, `a`,
`curv_fact_elec_trans`, `leaf_specific_conductance_max`. `electron_transport_` hides it,
because it rounds back to the same double.

**Therefore this task removes a defect and its gradient rows move.** Every other member
is restored by assignment and is exact, so `PPFD_` is the only one.

**How to check. Compare the bit pattern of each value; do not use `==`.**

1. Record `input_adjoints(1.0, 0, v0)` and `input_adjoints(0.0, e_j, v_j+1)` on the old
   build, **each from a leaf freshly seated at the same state — one old call per row, not
   `1 + n` calls in sequence.** A sequence drifts `PPFD_`, so it is not a reference.
2. Call `output_rows(rows)` on the new build at that state.
3. Require each `rows[q][i]` to have the bit pattern of `v_q[i]`.
4. Require the leaf state after one `output_rows` call to have the bit pattern of the
   leaf state after **one** `input_adjoints` call. Compare `ci_`, `profit_`, `E_up_`,
   `soil_consumption_`, `opt_psi_stem_`, `root_collar_psi_`, `PPFD_`,
   `leaf_specific_conductance_max_`, `collar_pinned_`, the 15 parameter members,
   `psi_soil_`, `vcmax_`, `R_d_`, `jmax_`, `electron_transport_` and `assim_max_`.
   **Do not compare against `1 + n` calls: that gate cannot pass wherever `PPFD_` fails
   to return.**
5. Do the check at four states: an interior operating point, a pinned one, a state where
   `layer_flux_partials` gives NaN, and **an interior state at a `PPFD` that does not
   round back, 1500 being one.** The fourth is what makes the drift visible.
6. Do the check on a block that has two grafts. A block with one graft passes even when
   the operating point is wrong.

**Measured on a dry run of these steps**, at `d3392ea3`: 642 of 642 row entries
bit-identical at an interior, a pinned and a kink state; all 168 entries of the kink
state NaN on both builds, which is the evidence that `0.0 * NaN` was not simplified
away; and 0 of 46 members differing against one old call at every state, including
`PPFD = 1500`. `scratch/leaf_jac_gate.cpp` does not fit this gate — it checks
invariants and never records a row — so a new harness is needed and it links standalone
without an R build.

**WARNING: A finite difference of the block cannot check these rows. The graft is
zero in value for each grafted input. Therefore the value of the block does not
change when a row is wrong. Eleven trait columns read exactly zero for two waves
of work for this reason. The rows of the leaf are the only referee.**

### Task 2: build the tabulation only when a hydraulic row is wanted

Type: cost. Two lines of code, **after Task 3's plumbing exists**. `par_wanted` is
not in the tree today; Task 3 builds it. Section 6 gives the order.

**Read both of Measurement G's figures.** The saving is the whole of the tabulation cost,
and the tabulation is wanted whenever any of `b`, `c`, `root_b` or `root_c` is requested.
Therefore this task makes a single non-leaf trait fast and does nothing for a run that
asks for every trait. Task 5 is what makes the hydraulic rows themselves cheap.

**Why.** `Leaf::input_adjoints` calls `build_cumulative_vulnerability_integral`
twice on every call, once for the stem curve and once for the root curve, and
`Leaf::bound_partials` calls it twice more. Only `set_parameter` reads the knots,
and only for `b`, `c`, `root_b` and `root_c`. Measurement A gives 2.0007 rebuilds
for each call. Therefore they run always.

**Steps.**

**`Leaf::bound_partials` has two more builder calls that Measurement A's 2.0007 does
not count**, and they run unconditionally on the pinned branch. Guard those too, and its
own 4-parameter difference loop belongs to Task 3's mask.

1. Put the two calls in each function under one condition. The condition is
   `par_wanted(PAR_B) || par_wanted(PAR_C) || par_wanted(PAR_ROOT_B) ||
   par_wanted(PAR_ROOT_C)`.
2. This set is the set that `rebuilds_transport` gives. Do not write a second
   list.

**How to check.** The tabulation count for a run that wants no hydraulic row must
be 0. Each row must keep its bit pattern.

### Task 3: mask the parameters of the leaf

Type: cost.

**Why.** The leaf differentiates all 15 of its parameters on each call. `lma` is not
one of them: it reaches the leaf through `area_leaf`, which is a state input, so the
graft supplies its row. Therefore a gradient for `lma` needs no parameter row at all.

**Counted from the code.** 13 of the 15 leaf parameters are in
`ad_parameter_names()`; the two that are not are `vcmax_25` and `jmax_25`, whose graft
term is zero by structure, so the code computes 2 analytic partials and 4 evaluations
of `dprofit_droot_collar_psi` for no result on every call. Of the 13, nine also pass
`reaches_operating_point`. **An earlier form of this task said 11, and that number
reproduces from nothing.** Therefore the registration list alone removes 2 of 15, and
every larger saving comes from the set the caller asked for.

**Steps.**

1. Make the requested trait set reach C++. Today `stand_gradient(scm, traits =)`
   subsets a matrix in R and `census_trait_gradient_tf24` takes one argument. The
   signature changes in `R/stand_gradient.R`, `src/census_gradient.cpp` and
   `SCM::census_trait_gradient`. **`inst/RcppR6_classes.yml` does not change**:
   `census_trait_gradient_tf24` is a free `Rcpp::export`, so `make attributes` alone
   regenerates `src/RcppExports.cpp` and `R/RcppExports.R`. `make RcppR6` should
   produce no diff.
2. Add a trailing argument `const std::vector<bool>& par_active` to `output_rows`,
   always of length 15 and indexed by the parameter loop's `k`. **An empty vector must
   not mean "all active"**: that is a capability flag on an argument, and it leaves
   `par_active[k]` undefined for the default. Pass all-true instead.
3. Build the vector one time in `graft_leaf_outputs`. Test each parameter name
   from `Leaf::inputs()` against the names from
   `TF24_Strategy::ad_parameter_names()`.
4. Extend the `reaches_operating_point(k)` guard on the parameter loop with
   `|| !par_active[k]`. Add the same guard to the seven analytic partials that
   `forward_derivative` supplies above that loop.
5. Mask `Leaf::bound_partials` in the same way, with one exception. **Guard only the
   writes, never the early `return`.** `bound_partials` returns early when
   `p_bound == -root_psi_crit`, and that `return` encodes that no other input moves
   the bound. Guarding the block would fall through and compute a full set of rows,
   changing every other column. `out[i_kappa]` sits inside the same branch as
   `out[i_par0 + PAR_PSI_CRIT]` and is a state column, so it must not be masked with
   it.

**Put the marker on the output column and not on the row.** The failure this guards
against is a gradient column that reads as an answer. A row is read by nothing except
the two `graft` calls in `graft_leaf_outputs`, so a marker there is invisible to the
consumer that matters. Therefore:

1. Do not write a masked parameter at all. `dprofit_dpar[k]`, `dR_dpar[k]` and
   `dE_dpar[k]` keep their initialised zero, and `graft` multiplies that zero by a
   term that is zero in value. The leaf then contributes nothing to that trait.
2. Make `Patch::clear_trait_adjoint` seed a masked trait's accumulator with NaN, so
   the column that reaches R cannot be read as a number.
3. **Do not poison the row and do not compact `x`.** Both were in an earlier form of
   this task. Compaction needs a change to `graft`'s loop that no step authorises, it
   drops the `util::check_length` guarantee, and it puts a second NaN in the rows that
   cannot be told apart from the kink NaN of Task 1.

**WARNING: masking a leaf parameter does not zero that trait's column. It makes the
column understated and finite, which is worse than zero, because zero looks
suspicious.** The 44 entries of `ad_parameters()` all stay in the block's input
vector, and `rho`, `b`, `c` and `a_bio` also reach `compute_rates` through equations
outside the leaf. Only the marker of step 2 catches this.

**WARNING: `Patch::cohort_block_adjoint` never resets `block_workspace`.** It builds
`strategy_template` under `if (!block_workspace)` and nothing invalidates it.
Therefore a mask set after the first block never reaches the leaf, and two
`stand_gradient` calls on one `scm` with different trait sets silently reuse the first
mask. Add a reset and call it where the targets are chosen.
`Patch::introduction_adjoint` does not have this defect, because it rebinds on each
call.

**Take the mask's names from `ad_parameter_names()` and its width from what the
caller asked for.** The registration list is the authority on which names exist; it is
not the authority on which the caller wants. A name that is not in the registration
list must be refused, not masked.

**No other path registers a smaller parameter set.** `cohort_block_adjoint` and
`Patch::introduction_adjoint` both use the full 44 in the same species-major order, and
`trait_adjoint_size()` sums over species. Therefore `ad_parameters()` must not shrink,
or the trait-adjoint layout and `census_trait_names_tf24` drift apart.

**How to check.** Set every entry of `par_active` to true. Each row must keep the
bit pattern from Task 1. Then request a masked row and make sure the code refuses
it by name.

### Task 4: derive the mixed second derivative, and delete the residual pairs

Type: cost, and it is the one expression the design has always named as owed.

**Why.** Each of the 11 parameter rows that reach the operating point takes a two-sided
central difference of `dprofit_droot_collar_psi`. That is 22 of the 35 residual evaluations
in Measurement A. Each one stands in for `d2(profit)/dp d(parameter)`, which report 00
calls "the single new piece of code the whole design needs" and orders **last**. The
implementation shipped a difference in its place, and no document priced the placeholder.

**This is a hand derivation and no automatic route exists.** `dprofit_droot_collar_psi` is
`double(double)` and is not templated. `odelia::ode::forward_derivative` fixes
`xad::fwd<double>` with a `double` to `double` signature. The leaf stays `double` and hands
back numbers, so `d2(profit)/dp d(parameter)` is one more chain rule on a `double`
expression. It must include the implicit-function term of the `ci` root-find.

**Steps.**

1. Write `d2(profit)/dp d(parameter)` for each of the 11 parameters, following the chain
   `dprofit_droot_collar_psi` already writes for `d(profit)/dp`.
2. Replace the `R_pm` central-difference pair in the parameter loop with the closed
   form.
3. Keep the difference under a build flag or in the test only, as the reference for step 4.

**How to check.** Each closed-form row against the difference it replaces, with the
difference step swept and a plateau required. **Report 00 records that the conditioning of
this expression has never been measured.** Measure it: if a row is ill-conditioned, say so
rather than reporting the value.

Task 5 and this task are not substitutes. This one removes the residual pairs. Task 5
removes the tabulations. Measurement A shows both are present.

### Task 5: put the transport algebra in closed form

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

**WARNING: `odelia::incomplete_gamma` is not in either repository.** It is on the
odelia branch `claude/odelia-ad-tape-reverse-496fuf` at `f359830`, "incomplete
gamma: exact Weibull antiderivative (P1c)", which is an ancestor of neither `master`
nor `p3/odelia-integration`. It was built in Phase 1 and never landed. The agreement
figures below come from that commit's own tests. **Land the header first, or this
task has no subject.**

The function computes `gamma(a, x)` by the everywhere-convergent series

```
gamma(a, x) = x^a e^-x * sum over n >= 0 of x^n / (a (a+1) ... (a+n))
```

in elementary operations. It agrees with the tabulation to 1.42e-15 for the stem and
1.67e-15 for the root, over 4 001 points. The endpoint derivative
`dG/dm = exp(-(m/b)^c)` is recovered to 9.0e-14 and 2.3e-13. `dG/db` and `dG/dc`
match a central difference of the closed form with a clean plateau in all 16 cases.

**Take the two derivatives by hand. Do not put a tape inside the leaf.** The leaf is
`double` and gives back rows of numbers, and that is what lets the graft serve the
forward type and keeps the tangent referee. A tape inside the leaf needs
`block_state::tape` threaded from `Patch::cohort_block_adjoint` through `Strategy`,
which is a cross-cutting change for a result that three lines of algebra give:

```
G(m)      = (b/c) * gamma(a, X),   a = 1/c,   X = (m/b)^c
dgamma/dx = x^(a-1) e^-x                     the integrand, exact, no series
dgamma/da = log(x) * gamma(a, x)
            + x^a e^-x * sum over n of (-term_n * sum over k <= n of 1/(a+k))
```

The third line is the same loop as the value with one more accumulator, because
`term_n` is `x^n` over the product of `(a+k)`, so `d(term_n)/da` is
`-term_n * sum of 1/(a+k)`. Then the chain rule to the parameters, using
`dX/db = -c X / b` and `dX/dc = X log(m/b)` and `da/dc = -1/c^2`:

```
dG/dm = exp(-(m/b)^c)
dG/db = gamma/c - X * dgamma/dx
dG/dc = -(b/c^2) * gamma + (b/c) * (X log(m/b) * dgamma/dx - dgamma/da / c^2)
```

**`b` and `root_b` need only `dgamma/dx`, which is closed form.** Only `c` and
`root_c` reach the series derivative. Therefore two of the four wrong columns need
no new series code at all.

This route is also cheaper than the tape. Measurement D's 0.68 us is a reused tape;
the value alone is 0.074 us, and the three quantities share one loop.

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

**Scope this task as two packets, because its size is not known yet.** The first
answers the question below and writes no production code. The second implements what
the answer allows.

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

### Task 6: add the direct trait term of the census

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

**This task explains none of the three metrics of Section 1.** Task 15 and Task 16
do. The direct term is real and absent, and its size is checkable: after Task 15, the
residual on `mass_above_ground` for `lma` should be exactly the `leaf_area` census
value, `+1.9636` at the configuration of Section 1. Do this task after Task 15, or its
gate reads aliased storage.

### Task 7: assert that the sweep covers the trajectory

Type: correctness. Small.

**Why.** `SCM::census_trait_gradient` builds the segment list from the width
changes between recorded states. It then sweeps from `boundary[0]` up. Nothing
asserts that `boundary[0]` is 0. Nothing asserts that the segments join. If
`boundary` is empty, the loop body never runs, and the function returns a row of
exactly zero with nothing raised.

**Steps.** Assert that the swept segments cover every recorded step. Refuse an
empty segment list. Do not return a zero row.

### Task 8: give the competition adjoint the unordered path, or refuse it clearly

Type: correctness, and Section 2b shrinks it to its second instance.

**Why.** `Species::compute_competition_and_slope_adjoint` raises `util::stop` when
the node heights are not descending. The forward path has
`compute_competition_unordered` for exactly that state, because reserve-gated
growth lets cohorts cross. Therefore the forward model runs and the adjoint stops.

**Section 2b resolves this task without a transpose.** The gradient runs on the
birth-date coordinate only, where the abscissa is the introduction time and cannot
invert. Therefore the `stop` is unreachable and it becomes a correct assertion. Keep it,
and give it a message that names the coordinate. An earlier form of this task asked for
the unordered transpose; do not write one.

**The same defect has a second instance, and this one is silent.**
`Species::consumption_rate_adjoint` is no longer the transpose of
`Species::consumption_rate`. The forward function now sorts the node grid when the
heights invert. The adjoint still transposes the unsorted trapezium. Therefore the
two disagree on an inverted grid, and nothing raises an error: the gradient is
finite and wrong. This is the one place where the upstream fix and the reverse-mode
surface are not independent of each other. **This instance survives Section 2b**, because sorting is about the grid the forward
function builds and not about which abscissa names it. Make the adjoint read the same
sorted order the forward function uses.

---

## 7. Tasks that #590 requires

### Task 9: move the reductions to the birth-date abscissa

**Why.** #590 carries the size distribution as a density in birth date. The two
resource integrals then use the introduction time as the abscissa. The reductions of the
AD branch still use height. #590 cannot change them, because they do not exist in
`develop`.

**#590 already supplies the machinery, so do not build it.** It adds
`Species::abscissa_of(node, bool birth_date)`, `Species::quadrature_abscissa(node)`
which reads the flag, `Species::density_in_birth_date()`,
`Species::birth_dates_are_distinct()` and `Species::set_new_node_birth_date(time)`.

**WARNING: `abscissa_of` returns `birth_date ? n.introduction_time() : -n.height()`.**
The height branch is negated, so the forward integrals were rewritten around an
ascending abscissa in both coordinates. The AD reductions transpose the descending one.
Under Section 2b only the birth-date branch has to be served, and it is already
ascending — but **do not carry the old descending order across; the transpose must match
the order the forward function now uses.**

**Steps.** Change the abscissa in each of these to `Species::quadrature_abscissa`:

1. `Species::census`
2. `Species::consumption_rate_adjoint`
3. `Species::compute_competition_and_slope_adjoint`
4. the census seed in `SCM::census_state_adjoint`

**Result.** The quadrature weights become constants, because the introduction time is
fixed at birth and it is passive. Therefore the weight derivative term is exactly zero.
Section 2b is what makes this an outright deletion and not a branch. Report 00 section 6.3 gives it as `h_bar_k += sum_i U_bar_i n_k
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

### Task 10: remove the transport seed

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

Do these after Tasks 1 to 5. Section 4 gives the reason: before those tasks this
work is inside the 2 percent, and after them it is about a third of the total.

### Task 11: sweep one recording with many seeds

Type: cost, **and it supersedes Task 15**. Do it last of the cost tasks, because it is
the only one that changes odelia. Recording one time and re-sweeping removes both the
repeated recording and the aliasing Task 15 patches.

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

### Task 12: reuse the leaf operating point

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

### Task 13: cache the six stage fields inside a step

Type: cost. Memory: about 7 kB.

**Why.** The rebuild loop calls `stage_state(i, y, h)` and then `ode::derivs`,
which builds the field at stage `i`. `sweep_stages` then calls
`stage_state(i, y, h)` again and `set_ode_state_and_field` at the same stage
state. Six fields at about 140 doubles is about 7 kB. `aux` is already held for
each stage in this way, so the pattern exists.

Use `Patch::has_recorded_field`, `record_stage` and `replay_step`. They are hooks
with empty bodies today and this is their purpose.

### Task 14: store the stage rates, and do not rebuild them

Type: cost. Memory: about 724 MB. **Optional.**

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

- **A branch kink makes the whole gradient NaN, and nothing falls back.**
  `Leaf::layer_flux_partials` returns with every entry NaN when any layer meets one of
  three conditions: equal potentials, gravity balance, or a collar potential within
  1e-8 of zero. No caller of it tests for that. The NaN reaches the row, and `graft`
  computes `partial * (x - to_passive(x))`, whose second factor is exactly zero in
  value, so `NaN * 0.0` puts NaN in the **value** of `leaf_profit_` and therefore in
  `net_mass_production_dt`. **The plain `double` run is safe**, because
  `graft_leaf_outputs` is called under `if constexpr (!std::is_same_v<S, double>)`.
  **Both AD paths are not**, so one kink in one cohort makes the gradient and the
  tangent referee NaN together. `Leaf::dE_from_soil_dpsi_collar` says its NaN means
  "the caller falls back to finite differences", and on the graft path no such fallback
  exists. Decide what a row holds at a kink before Task 1 fixes its bit patterns in
  place. Also check whether the `bound_a` pin meets the equal-potential condition by
  construction, which would make this reachable on every pinned block.
- **The environment columns of the census seed are exactly zero in all three rows.**
  `n_b = birth_rate * pr_estab / g` is evaluated in the field, which depends on the soil
  state, so a non-zero column is expected. This is a fourth candidate and it is not
  confirmed. It is too small at lifetime 2 to spoil the `leaf_area` row. Discriminating
  it needs a difference of the census against a perturbed environment state, which R
  does not expose today.
- **The conditioning of `grad(dPi/dp)` has never been measured.** Task 4 builds the
  expression. Report 00 section 9 lists "whether `grad(dPi/dp)` is well conditioned
  anywhere" as inferred and not measured, so Task 4 must measure it and not only
  agree with the difference it replaces.
- **A relative `lma` step of 2e-7 flips a 105-year stand between alive and
  identically zero.** Measured: several arms of a pinned central difference return
  census metrics at underflow and run 42 s instead of 112 s. Therefore **no re-run
  finite difference can referee this gradient at production**, and the forward
  tangent of Task 0 is the only referee. The collapse is a forward-model
  discontinuity and it is the owner's. Diagnose it: the 42 s against 112 s wall
  clock is the cheap discriminator.
- **`scripts/v4-census-gradient.R` and `scripts/v4-reference.R` perturb
  `pars[["lma"]]` directly**, which does not compute the derived strategy quantities
  again. The correct route is `add_strategies(p, trait_matrix(v, "lma"))`. Any figure
  taken through those scripts is suspect. `scripts/v4-reference.rds` belongs to
  polish cap 5 with an unpinned base and **must not be used**.
- **Two dry leaf states crashed** inside the solve during the linearity harness,
  before `input_adjoints` was reached. Task 0b explains the states that stop inside
  `input_adjoints`, and these two are a different site. The candidates are the
  `util::stop` calls in `Leaf::prepare_collar_solve` and `Leaf::profit_at_collar_psi`.
  A run is needed to say which.
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

Do not do this work for speed **on the present build** — Section 4 says why, and
Section 8 is where the same work becomes worth doing.

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

**This table is the one home for these factors.** A task's own section states what it
does and how to check it, and not its size.

| Task | Factor | Source | What it removes | Moves forward numbers? |
|---|---|---|---|---|
| 1, `output_rows` | about 5.3 | calculated from A and C | repeated Jacobian builds | no, and it moves gradient rows to 2.1e-6 by removing the `PPFD_` drift |
| 2, tabulation guard | 5.71 for a non-leaf trait, 1.005 for all 44 | **measured, G** | tabulations, when no hydraulic row is wanted | no |
| 3, mask | 6.68 for a non-leaf trait, 1.00 for all four hydraulic rows | **measured, F** | whole parameter rows nobody asked for | no |
| 4, mixed second derivative | 22 of 35 residual evaluations | counted, A | the residual pairs | no |
| 5, closed form, stage A | 121 us to 0.68 us per evaluation | **measured, D** | the tabulation cost itself | no |
| 5, closed form, stage B | — | — | the second definition of `G` | **yes**, needs the owner |
| 10, transport seed | about 2 | calculated from A | the second leaf solve per block | #590 moves them, not this task |
| 11, many seeds | 3.0 | counted: three metrics, three sweeps | repeated recordings per metric | no |
| 12 and 13 | about 1.2 together | calculated | repeated leaf solves and field builds | no |
| 14, stored stage rates | about 1.5 | calculated | the stage rebuild | no |

**Task 4 and Task 5 attack different halves of one call, and Measurement A shows both
halves are present.** Task 4 removes the 22 residual evaluations. Task 5 removes the two
tabulations, and the eight more that a hydraulic row adds. A plan that builds only one of
them leaves the other in place.

Only stage B of Task 5 needs a new forward baseline. #590 needs one, and Task 0
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
