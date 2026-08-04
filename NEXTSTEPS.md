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

**WARNING: the `mass_above_ground` entry of this table is not reproducible and its
configuration is not recorded.** A dry run on `d3392ea3` at the same lifetime, through
`scripts/stand-gradient-smoke.R`, reads `-14906.6` where this table records `+1.1236`.
The `leaf_area` entry does reproduce, to 1.9e-6. Both numbers are consistent with the
aliasing of Task 15, which corrupts every metric after the first in a way that depends on
what took the freed slot — so **treat the sign and the magnitude of rows 2 and 3 of this
table as evidence that they are wrong, and not as values to reproduce.** Task 15 first,
then measure again.

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
accepted.** Each of the 39 changes of `7b5012c2` that can move a forward number is
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

- **Task 8 still needs the transpose. An earlier form of this section said the coordinate
  change made it unreachable, and the code says the opposite.** The stop is
  `if (!scan.decreasing) util::stop(...)` — a test on **height** ordering with no coordinate
  condition. The forward twin diverts only when `!birth_date && !scan.decreasing`, because
  "the birth-date grid is monotone whatever the heights do". **So on this coordinate the
  forward integrates happily over inverted heights and the adjoint stops.** The coordinate
  change makes that state more common, not unreachable.
- **Task 9 has one coordinate to serve, not two.** No flag reading inside a reduction.
- **Task 10 may delete `seeds.transport` outright.** There is no `Patch::transport_adjoint`
  — `git log --all -S` finds it on no branch.
- **The second leaf solve goes away by the coordinate change itself**, because
  `log_density_dt` is `-mortality` and `growth_rate_gradient` no longer runs.

**One consequence that is easy to miss.** On this coordinate the quadrature abscissa is
the introduction time, so **the introduction schedule and the quadrature grid are the
same object**. Refining the schedule changes the abscissa the resource integrals are
taken over. Under the height coordinate the two were separate concerns. Therefore a
converged schedule is a precondition for any reference number here, and not a
housekeeping task.

What it costs:

- **The forward model keeps both coordinates**, so the forward references at the
  default flag stay valid and no wholesale update of the reference numbers is
  needed.
- **Every gradient measurement must be taken again with the flag on.** Measurements A
  to G and the stop of Section 1 were taken on the height coordinate, which the
  gradient no longer supports. Their ratios are likely to carry; their absolute
  numbers are not gradient references any more. Task 0 owns re-taking them.

---

## 3. Two terms this document uses in a particular sense

Each other term in this document is either the name of a C++ symbol or a standard
term of automatic differentiation. Section 12 lists them.

- **the recorded cohort step** — `Individual::compute_rates` at the active scalar
  type, recorded one time for one cohort at one Runge-Kutta stage. It is the unit of
  the reverse pass.
- **the supplied derivative** — `value + sum_i partial_i * (x_i - to_passive(x_i))`.
  odelia calls this `odelia::ode::supplied_derivative`. It is zero in value, and that
  property is why a finite difference of a recorded cohort step cannot see it.

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
| `input_adjoints` calls for each recorded cohort step | 10.64 — **do not use, see below** |
| `dprofit_droot_collar_psi` calls for each `input_adjoints` call | 35.0 |
| root-finds for each `input_adjoints` call | 100.0 |
| rebuilds of the 100-knot vulnerability table for each call | 2.0007 |
| share of the reverse pass inside `input_adjoints` | **98.16 percent** |
| gradient wall clock | 292.35 s, this machine only |

**Measurement A has been re-taken on the birth-date coordinate**, same configuration, and it
reproduces the step count exactly (139 to 140 accepted steps, 8 nodes, `ode_size = 73`).

| Quantity | Value |
|---|---|
| `Leaf::input_adjoints` calls | 81 468 |
| for each accepted step | 543.1 |
| for each cohort-step | 74.81 |
| for each cohort-stage | 12.47 |
| for each cohort-stage-metric | 4.16 |
| share of the reverse pass inside `input_adjoints` | **99.2 percent**, 119 of 120 stack samples |

**The share did not fall. It rose.** So the ceiling on everything outside `input_adjoints` is
**0.8 percent** on the birth-date coordinate too, and #590 did not relax it.

**"10.64 for each recorded cohort step" is unreproducible and must not be quoted.**
144 072 / 10.64 = 13 541 and no product of that configuration's step, node and stage counts
equals 13 541. Any restatement of a per-step count must carry its denominator, as the four
rows above do. The 4.16 figure is the one the code explains: `graft_leaf_outputs` calls
`input_adjoints` `1 + max_soil_layer` times, and at lifetime 3 most cohorts root to one or
two layers.

**Wall clock cannot give the coordinate ratio on a shared machine.** The same arm ran in
138.00 s, 241.50 s and 305.25 s. Per recorded step the birth-date coordinate is between
**1.8 and 3.2 times cheaper**, which is at least the expected halving. Do not quote a figure.

**And the two coordinates are visibly different functions**, which is Task 0's warning made
concrete: `d(leaf_area)/d(lma)` is -24.302 on height and -30.443 on birth date, and
`d(mass_above_ground)/d(lma)` **changes sign**, +0.602 against -10.484.

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
stated.** `input_adjoints` is 98.16 percent of the reverse pass on the height coordinate and
**99.2 percent on the birth-date coordinate**, so **everything outside it can give 0.8 percent
at the most today**. Tasks 1 to 5 all act inside it
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

**Re-take the gradient measurements here.** ~~Measurement A's calls for each recorded cohort
step and the share inside `input_adjoints`~~ — **both re-taken; see Section 4.** The share is
99.2 percent, not lower. **The stop table of Section 1 was measured on the height coordinate
and has not been re-taken.**

The prediction that the count would halve was wrong in its factor: `growth_rate_gradient`
adds **one** further active `compute_rates` for each cohort-stage at the default
(`node_gradient_richardson = FALSE`), so about 1.5 times, not 2. The height-coordinate count
was not measured, so "did the count halve" is unanswered as a count.

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

1. **Task 17 first.** It is the only thing that stops a wrong gradient being returned
   silently on the coordinate the design targets, and it does not depend on anything.
   Task 21 follows it immediately, because Task 17 breaks every reverse-mode test.
2. **Task 15 next, before every other correctness task.** It is the cause of two of
   the three wrong metrics, and until it is fixed no other seed defect can be measured:
   a second sweep reads aliased values whatever else is right.
3. **Task 16 next**, because it is the only cause of `k_I` and it is independent of
   everything else.
4. **Task 3's plumbing before Task 2.** Task 2's condition is written with
   `par_wanted`, which does not exist. `leaf_model.cpp` has `rebuilds_transport` and
   no notion of a parameter being wanted. Task 3 builds that notion.
5. **Task 1 before Task 2 and before Task 3's leaf half**, because both edit
   `output_rows`, which Task 1 creates.
6. ~~**Task 5 before Task 4.**~~ **Void: the reason has no basis in the code.** It rested on
   Measurement E, and both `input_adjoints` and `bound_partials` already hold the knot grid
   across their difference loops, so those four rows are not gated against a poisoned
   reference. **Tasks 2, 4 and 5 should instead be re-issued as one design task — the
   second-order jet of the leaf's profit map — whose first deliverable is a kink policy.**
   See the head of Task 4.
7. **Task 0b before every gate**, and its own gate must expect the pinned rows to
   move. At the `bound_a` pin `psi_stem` equals the collar potential, so the forward
   guard `psi_upstream >= psi_stem` fires and the forward path reports
   `gamma * umol_per_mol_to_Pa` while `input_adjoints` runs the root-find. The two
   disagree there today. Making them agree changes the pinned rows, so **Task 1's
   bitwise baseline must be taken after Task 0b, not before.**
8. **Take Measurement A again after Task 10.** Every factor in Section 11 is quoted
   against a per-step call count that Section 4 now shows is unreproducible, and Task 10
   removes the second leaf solve. Re-quote them against **74.81 for each cohort-step**, with
   the denominator stated.

**The derivation of Task 4 is not a packet's work.** Eleven mixed second derivatives,
including the implicit-function term of the `ci` root-find, is design. A packet may
not make a design choice. Write the eleven expressions first; then a packet
transcribes and gates them.

### Task 22: restore the light field's geometry channel, or price its absence

Type: **correctness**, and it is **smaller than this plan claimed**. It was called "the
largest single defect this plan has found". A dry run measured it and it is not.

**Why.** The light field's knot positions are `u_k * height_max`. They are held as
`double`: `ResourceSpline::set_fixed_value` takes
`const double top = odelia::util::to_passive(height_max)` under the comment "Knot
positions are the interpolant's grid and stay double, so a position built from an active
`height_max` is read at its value." So `height_max` reaches the field's **values** and not
its **positions**, and `Species::height_max()` is the tallest cohort's height, a state
variable.

**Report 03 appears to contradict itself about this, and the earlier ruling in this task
was backwards.** Its section 1b says the channel "disappears" and arrives instead as
ordinary chain-rule terms. Its head correction says the channel is dropped and measures the
gap at 1.891e+01.

**This task previously read: "The code settles it: the positions are passive, so section 1b
is wrong and the head is right." That is wrong.** Passive knot positions do **not** imply a
lost channel. Section 1b's chain-rule reading is the correct mathematics: with the grid
frozen, the assembled transpose over the knot values equals the exact `dL/d(height)` at
fixed query height, up to interpolation error only. A dry run measured that error at
**5.0e-04 relative at the production knot count K = 65** — the order C1 assumed, not the
order the head correction reports.

**Read the caveat before you rely on the number.** It was measured on a **1-D model problem
in Python**, not in plant: exact knot data, a smooth competition profile, no light floor, no
boundary node, one perturbed cohort. It establishes the mechanism and the order of magnitude.
It does not reproduce or refute the 1.891e+01, and **the 1.891e+01 remains unexplained and
must not be scheduled against.** The leading hypothesis is that the probe that produced it
added `dI/dz_q * u_q` without the compensating `L'(z_q) * u_q`, which would make it an
artefact. Settling it means re-taking that measurement with the moving-grid variant's
`dy_q/dH` written out in full.

What the frozen grid does lose is a **discretisation** term, not a channel: the knots move
with `height_max` and the transpose does not see them move. That is bounded by interpolation
error and it converges with `K`.

**This survives the coordinate change.** Section 2b moves the density's abscissa to birth
date. The light field is still indexed on height, and `height_max` is still the tallest
cohort's height, so the severance is untouched.

**Three parts, and they are one channel.**

1. **Measure the convergence.** ~~Never measured.~~ **Measured: 5.0e-04 relative at
   K = 65.** It converges, so C1's choice is defensible and its cost is bounded. Report the
   table across `K` anyway, because the bound is the whole defence. **A second dry run located the channel in the code, by
   sweeping the difference step over every node's height row at one step of `h = 0.02`.**
   Seven of eight nodes show a V — falling to 1e-6 to 2e-5 and turning up at 1e-9 — which is
   a correct transpose against a reference at its cancellation limit. **Node 1 is flat at
   5.4e-04 across seven decades, in both absolute and relative regimes, and node 1 is the
   node that sets `height_max`.** Structurally consistent: `light_knot_adjoints` carries
   `value` and `slope` and no position term.

   That figure is a **per-step** price at `h = 0.02`. Whether it accumulates to the
   1.891e+01 over a trajectory was not measured. The alternative hypothesis the sweep could
   not exclude is the transport term's displaced second evaluation, which is also
   height-directional; the discriminator is a re-run with the field pinned to a fixed grid
   well above the tallest cohort. **Do not restate 1.891e+01 as this task's error.**
2. **Normalise the coordinate — now optional, not required.** With the error at 5.0e-04
   this is cleanliness and convergence rate, not correctness. Build part 3 first. C1's ruling is a choice and a
   choice whose price was mis-estimated by four orders is a choice to revisit. There is a fix
   that needs no active grid, and report 03 section 1b describes it: **hold the grid at the
   fixed fractions `u_k` in a normalised coordinate, and query the field at
   `nu = z / height_max`.** Then the knot positions are literally constant, `height_max`
   enters only through the query argument, and its derivative is ordinary arithmetic:
   `dF/d(height_max) = (dF/d nu) * (-z / height_max^2)`. Exact, and no spline grid becomes
   active.

   Section 1b describes this as though it were built. **It is not.** `ResourceSpline` lays
   its knots at `to_passive(height_max)` and queries at absolute height, in both
   `set_fixed_value` and `rebuild_spline`. So section 1b states the design and the head
   states the tree, and both are right about different things.

   **A third bit-equality cache lives here.** `rebuild_spline` rebuilds only when
   `spline.size() != knot_fractions_.size() || spline.max() != height_max`. That is an exact
   comparison on an active value, in the same family as Task 23's. Under normalisation the
   condition disappears, because the grid stops depending on `height_max` at all.
3. **Add the field's own Leibniz term.** Report 03 section 1b and report 01 section 3 both
   require it: the reduction's lower limit is `height_0`, so the field carries
   `integrand(height_0) * d(height_0)/d(trait)`. It is closed form and it belongs with the
   knot adjoints in `Patch::light_knot_adjoint`, not inside a recorded cohort step. **This
   is a different object from Section 1's 3 percent bias**, which is the factor
   `d(height_0)/d(trait)` itself; this is the term that factor multiplies.

**How to check.** A difference in `height_max` against the assembled adjoint, and the
knot-density convergence as a table rather than a single number.

### Task 23: ~~invalidate the soil-potential cache~~ — **retired, do not build this**

**The cache is sound and the hazard was recorded backwards.** `psi_soil_cache_state_` is
`std::vector<double>` compared against `vars.state(i)`, and `vars` is `Internals<double>`: the
key is `double` by design and the code says so. `psi_from_soil_moist` returns `double` from
`double` constants, so the cached `S` is built from a passive value and **no derivative flows
through the soil potential at all**, cached or not.

**And the hazard is inverted.** The key is compared against the quantity that produced the
cached value, so a finite-difference perturbation changes the key's bits and **forces a miss** —
the safe direction. `NaN != NaN` misses too, and the floor at `soil_moist_residual = 1e-2`
removes the only `-0.0 == 0.0` case. **There is no false-hit path.** Report 00 section 8 item 10
describes a real hazard and names the wrong cache: the one keyed on something other than the
perturbed quantity is `photo_temp_cached_`.

**Therefore this does not block Task 0 or Task 4**, and an earlier form said it did. **Task 0b's
stale `assim_max_` is the live instance of this class.**

What survives is not a cache defect: the soil state is not differentiable in this environment,
which is the fact Section 9's "environment columns of the census seed are exactly zero" entry is
circling.

**Why.** C1 names two caches. Task 20 fixes `photo_temp_cached_`. The second is
`psi_soil_cache_`, whose key is **an exact `double` comparison on the soil state**. Report
00 section 8 item 10 states the consequence independently: a cache keyed on bit-equality is
a hazard for anything that perturbs state slightly, **including a finite difference of the
gradient this plan verifies against**. Report 01 section 11 asks for it to be re-read
against the resident path, where the soil state is active at every stage.

**Steps.** Audit the invalidation under an active soil state. Use the pattern the branch
already uses: mark the cache stale under
`if constexpr (!std::is_same_v<S, double>)`. Gate that every stage recomputes the
potential.

**This blocks Task 0 and Task 4**, whose references are finite differences.

### Task 24: hold the step size, and read the stored one

Type: correctness. Small, and its failure is silent.

**Why.** Report 05 section 4: the step size was chosen by the adaptive controller, so
differentiating it differentiates the controller and not the model. It must be a recorded
constant on the reverse pass, **and therefore the recorded trajectory must store it rather
than recompute it.**

**A dry run established all three properties, more strongly than this task asks.** It is
**stored, not recomputed**: `SolverInternal::prev_steps` is written once for each accepted step
and `get_step_sizes()` returns `std::vector<double>`. (`ode_step_record` is **plant's**, at
`patch.h:31`, not odelia's — this plan said otherwise.) The reverse pass **reads the stored
one**: `Solver::solve_adjoint` takes `const std::vector<double> h = step_sizes()` and passes
`h[k]` as a `double`. And **no step size reaches an active type on either path**: in the
generic branch the stage states are computed in `value_type` and lifted afterwards, so `h`
never enters a recording, and the forward tangent's `advance_fixed_steps` and
`replay_schedule_` are `double` too.

**Steps.** So this is now a gate and not a change. Assert per step that the stored size is
finite and positive and closes `[t[k-1], t[k]]` to 1e-8 relative — which is what moves if a
caller re-derives a size or the record and the times fall out of step. Mirror it in R: the
first stored entry is **NaN**, because no step reached the initial time, and a recomputed size
could not have a NaN first entry, so the NaN is the signature of a stored record.

**The honest limit:** a `static_assert` at one call site is a type witness, not a `requires`
clause on the callee. The real guarantee is that `get_step_sizes()` is **declared**
`std::vector<double>`, so drift is a compile error at every use. Task 7 asserts that the
segments cover every recorded step, which is a different requirement.

### Task 25: gate that the trait adjoint accumulates

Type: correctness. Report 01 constraint C4, whose failure is a plausible constant factor.

**Why.** C4: trait-adjoint accumulation is untested in plant, and the recorded signature of
its failure is a gradient that is **41 to 51 percent** of the reference with the correct
sign. One trait is a single input read by every cohort at every stage, so the accumulation
is the only thing making the sum right. Report 01 section 6.2 records that the knot
accumulator has the same shape and the same silent failure.

**Steps.** Compare a two-cohort gradient against the sum of its own per-cohort
contributions, per trait and per knot. Task 16 adds an accumulator; this gates that
accumulation happens.

### Task 26: generalise the stage recursion to the whole tableau

Type: correctness. Report 01 constraint C2's remaining gap.

**C2's premise is stale: the general form is already built.** `Step::sweep_stages` runs
`const double* const b = stage_row(i); for (int m = 0; m < i; ++m) { for (q) lambda_k[m][q]
+= h * b[m] * lambda_stage[q]; }` — the full Cash-Karp row, one accumulation per
predecessor, not three special cases. An earlier form of this task presented the defect as
present.

**What survives is C2's falsifier, which is a gate and not a change.** C2 records that this
failure has no measured signature, so nothing would announce a regression.

**The premise is stale in two places, not one.** The *forward* rebuild is general too:
`Step::stage_state` computes a sum over every earlier stage, with `i == 1` split out only to
keep `step()`'s grouping `b21 * h * k1` bit for bit. Both halves of the stage recursion are
already general.

**Steps.** Add the comparison — one step's state adjoint against a finite difference of one
step on the full tableau, at the birth-date coordinate. Change no code unless the gate fails.

**A dry run ran it, and the tableau passes: the reverse arithmetic transposes `step()` to
1e-8 or better on six of seven state families.** The seventh is the height row of the tallest
cohort, which is Task 22's channel and not the tableau — the tableau is shared by every
family. **Sweep the difference step; do not take one.** The first reading of this gate printed
FAIL at 6.5e-03 because it used an absolute step of 1e-7 against states as small as 4.3e-06 —
a 2 percent perturbation. A correct transpose shows a **V**; a dropped term shows a **flat**
row whose plateau is the term's size.

### Task 27: land the permutation gate for the leaf's purity

Type: correctness of the instruments. Report 01 constraint C7's executable form.

**Why.** The whole recorded-cohort-step design rests on the leaf's outputs depending on its
inputs and on nothing else — no order dependence, no carried state. C7 records that this
property **has no structural defence**, and that `docs/tf24-correctness.md` P0.10 is its
executable form: permute a census of production states and require every leaf output to be
bit-identical. **It is the only check a reordering can fail and a re-run cannot.**

**Steps.** Land that harness. It is the companion to Task 12's round-trip probe.

**A dry run wrote and ran it, and it passes: `FAIL 0, PASS 326`, in 1.58 s.** No leaf output
was non-bit-identical under any permutation. It covers a 36-state census of production
`(height, psi_soil, PPFD)` — heights 0.3/1/5/20 m, `psi_soil` 0.05/0.5/1.5, PPFD 150/900/1800
— comparing twelve outputs by `identical()` over four arms: natural order against a fresh
`Leaf` for each state; six seeded random permutations; reverse order; and a re-solve of one
state immediately after every other state, which is the arm that catches a cache keyed on a
proper subset of its dependencies. Anti-vacuity checks ran first: all 36 profits finite and
more than 18 distinct.

**It is cheaper than this task said: it needs no C++ at all.** `Leaf` is fully R-bound, so the
harness is pure R.

**Two scope limits, stated plainly.** This is `Leaf`'s purity, not `Individual::compute_rates`'
purity, which is what C7 states — `Leaf` is where all four known carriers lived, so it is the
right first target, but a carrier in `TF24_Strategy` or `Internals` outside `Leaf` would not be
seen. And **the `photo_temp_cached_` arm is close to vacuous**: the census holds `leaf_temp` and
`atm_o2_kpa` fixed at 25 and 21, so that cache's key is constant across the whole census.
Varying leaf temperature is the obvious extension and it was not run.

### Task 17: refuse the height coordinate at every reverse-mode entry point

Type: **correctness**, and it is urgent because the wrong answer is silent.

**Why.** Section 2b scopes the gradient to the birth-date coordinate. Nothing enforces
it. **Measured on the merged tree at `node_density_in_birth_date = TRUE`, the gradient
returns a finite, plausible, wrong number:** `sum(abs)` of the census state adjoint is
1.404 against 3.516 at the default. It does not raise.
`Species::compute_competition_and_slope_adjoint` still forms its width from heights and
exits on `h0 < height`; `consumption_rate_adjoint` mirrors only the height branch of
`consumption_rate`. So the reductions transpose one coordinate while the forward model
integrates the other.

This is the failure `METHOD.md` section 1 calls worse than an exact zero: every entry
finite, every sign plausible, nothing in its shape asking to be looked at.

**Steps.** Refuse when `!density_in_birth_date()` in `SCM::census_trait_gradient`,
`SCM::census_state_adjoint`, `Patch::cohort_block_adjoint`,
`Patch::introduction_adjoint` and `stand_gradient`. Refuse at those five and nowhere
below them: a refusal inside a reduction reaches a caller that has already paid for a
recording. Name the coordinate in the message.

**Also refuse a non-distinct birth date.** Under this coordinate `x_k = b_k` is the
quadrature abscissa, so two cohorts sharing a birth date give a zero-width trapezium.
#590 supplies `Species::birth_dates_are_distinct()` and
`Patch::check_birth_dates_distinct()`. Use them; do not write a third check.

**Do this before Task 9, not after.** Task 9 makes the reductions correct on this
coordinate. Until then the refusal is the only thing between a user and a wrong number,
and it is worth landing on its own.

### Task 18: register `eta`

Type: correctness. Small, and the recorded reason for its absence is wrong.

**Why.** `eta` is absent from `ad_parameters()`. The comment gives the reason as
`CanopyShape::Qp`, where the exponent reaches a base of 0 and the recorded derivative
`u^k * log(u)` is NaN. **`CanopyShape::Qp` is called only by FF16.** TF24 reaches
`Q_and_q`, `q_from_height`, `Q_from_height` and `Q`. So the recorded reason names a
function this model never calls.

The hazard is real in the functions TF24 does call: `Q(u) = (1 - u^eta)^2` gives
`dQ/d(eta)` a factor `u^eta * log(u)`, which is NaN at `u = 0`. But #590 added a
`z <= 0` limit branch to `q_from_height`, which is a guard at exactly that endpoint.

**The guard already exists, in the one place that covers every caller.**
**A dry run confirmed this against the code**, so this task reduces to registering
`&pars.eta` and correcting the comment: `CanopyShape::Qp` is called nowhere but
`ff16_strategy.cpp:513`, and `Q`, `Q_and_q` and `q` all route through `pow_eta`.
`CanopyShape::pow_eta` returns `S(0.0)` when `to_passive(u) <= 0.0` for a non-`double` `S`,
under a comment naming this exact hazard. `Q`, `Q_and_q` and `q` all route through it. **So
an earlier form of this task asked for work that is done, by a better mechanism than it
proposed.**

**Steps.** Add `&pars.eta` to `ad_parameters()`. Correct the `ad_parameter_names()` comment:
it blames `CanopyShape::Qp`, which only FF16 calls, and the guard it says is missing is in
`pow_eta`. Where a function must be named, `CanopyShape::Q` is meant, not
`TF24_Strategy::Q`, which is the root-depth profile with a different exponent.

**`eta` also needs Task 16**, because `CanopyShape` is inside the field build, so its
row has nowhere to go until the field build has a parameter accumulator.

**How to check.** `dQ/d(eta)` against a central difference at `u` in the interior, and a
finite result at `u = 0` and `u = 1`.

### Task 19: refuse a parameter that reaches nothing, by name

Type: correctness. It closes the gap between absent and zero.

**Why.** **Eleven** registered-looking parameters reach no equation on this path, and an absent
column is indistinguishable from a zero column at the boundary. An earlier form said twelve;
`ad_parameter_names()`'s own comment carries the same ambiguity.

**Two names belong at the `Leaf` boundary, not the strategy's.** `beta_R_H` and `beta_R_V` are
plain `double` members of `TF24_Strategy`, not `S` members of `TF24_Pars`, so they sit outside
`field_ptrs()` and **no registration alone can give them a row**; that needs moving them into
`TF24_Pars` and into `leaf_parameter_slots`. They are settable through `Leaf$new` from R and read
exactly zero, so refuse them there.

**Two of the eleven are read, and the conclusion holds while the stated reason does not.** `S_D`
is read by `Species::net_reproduction_ratio_by_node_weighted`, and `a_p1`/`a_p2` by
`assimilation_leaf` — but only through `to_passive` reporting paths, and `assimilation()`'s call
site is commented out and headed "not in use for TF24". Write "read only through `to_passive`",
because **if a census metric is ever built on offspring production, `S_D` gains a live row and
the refusal becomes wrong.**

**`p_50` is out of scope by decision, not by defect.** The gradient is taken through the
low-level parameters `b` and `c`, which `TF24_Pars` derives from `p_50` in its own
default initialisers. So `p_50` is read once at construction and a value set afterwards
reaches nothing. **Do not add a row for it.** A gradient with respect to `p_50` would
mean differentiating the derivation, and this design differentiates `b` and `c`
directly.

The others reach nothing for a plainer reason: `a_p1` and `a_p2` belong to the
light-response curve the Farquhar leaf replaced, and `beta1`, `S_D`,
`var_sapwood_volume_cost`, `nmass_l`, `nmass_s`, `nmass_b`, `nmass_r` and `dmass_dN` are
declared, carried, and read by nothing here.

**Steps.** Refuse each of these by name at the boundary, with a message saying why. Do
not register them and do not return a zero column.

**`p_50` deserves a separate report to the owner.** It is settable from R, it is the
trait an ecologist would set, and setting it changes nothing in the forward model
either. That is a forward-model defect and it is not this plan's to fix.

### Task 20: let `vcmax_25` and `jmax_25` register

Type: correctness. A cache key, not a derivative.

**WARNING: the recorded reason is false and this task is two list entries.** The comment on
`ad_parameter_names()` blames `Leaf::photo_temp_cached_`'s key. **The derivative machinery for
both already exists and runs**: `leaf_parameter_address` maps both, both are in
`Leaf::inputs()`, `dprofit_dpar[PAR_VCMAX_25]` and `[PAR_JMAX_25]` are computed **analytically**
by `forward_derivative`, and `graft_leaf_outputs` grafts the rows. They land on unregistered
members and are discarded.

**So: add two entries to `ad_parameters()` and two strings to `ad_parameter_names()`.** 44
becomes 46 consistently in both, and `trait_adjoint_size()` and `census_trait_names_tf24` follow,
because those two lists are the single authority.

**The cache key is still wrong and it is a separate, latent defect.** It is unreachable today:
`Leaf` is `double` throughout, `pars.vcmax_25` reaches it at construction only, and the one
writer afterwards — `Leaf::set_parameter` — recomputes `vcmax_`, `R_d_`, `jmax_` and
`electron_transport_` by hand without consulting the cache. Fix the key, and correct the comment.

**`jmax_25` is not derived from `vcmax_25` on the production route.** The 1.64 ratio is a C++
initialiser artefact; `make_TF24_hyperpar` takes both as independent inputs. So it is no
constraint for Task 28's `J`, and registration is required either way.

**Steps.** Put `vcmax_25` and `jmax_25` in the cache key, or invalidate the cache when
either is written. Then register both. Check `Leaf::set_parameter`, which recomputes
`vcmax_`, `R_d_`, `jmax_` and `electron_transport_` by hand and is the reason the
difference path works today; the registered path must reach the same state.

**How to check.** The row for each against a central difference of the whole solve, and
`assim_max_` recomputed — see Task 0b's warning, which is the same staleness one level
down.

### Task 21: move the reverse-mode tests to the birth-date coordinate

Type: correctness of the instruments, not of the model.

**Why.** Every existing reverse-mode test runs at the default `Control()`, which is the
height coordinate. Task 17 refuses that coordinate. **Therefore Task 17 breaks every one
of them, and the breakage is correct.**

By `ORCHESTRATOR.md` section 7 this is the middle row of the three kinds: the assertion
can no longer express what it tested, so **migrate the test and check first whether a
capability went with it.** Do not delete an assertion and do not accept a new number for
one.

**Steps.** Set `node_density_in_birth_date = TRUE` in each reverse-mode test's
`Control`. Take each new reference from the migrated test itself, on a converged
schedule. For any assertion that cannot be expressed on this coordinate, say which
capability it covered and report it rather than removing it.

**Count them before you start**, so the arithmetic is checkable afterwards.

### Task 15: give each recording its own active values

Type: **correctness**. It is the largest cause of the stop in Section 1.

**Why.** `SCM::census_state_adjoint` builds the copy at the active type one time,
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

**`METHOD.md` section 3 already forbids this, and the code does it anyway.** The
standing hazard is recorded there with the same measured signature: the first recording
correct, the later ones with most rows exactly zero and a few spuriously large, nothing
thrown.

**The loop here is the loop over functionals, not the loop over cohorts, and that
distinction matters because only one of the two is broken.**
`Patch::cohort_block_adjoint` loops over cohorts and copies a never-recorded template for
each one, which is correct; `Patch::introduction_adjoint` builds its copy at the active
type fresh on each call, which is also correct. `census_state_adjoint` loops over
functionals and builds one copy above the loop. **It is the only remaining site.** The
two signatures are indistinguishable from the numbers alone, so name the loop whenever
you record one.

**It is pre-existing, and that is settled without a build.** A second dry run reproduced
the same signature — 33 of the 52 columns non-zero in row 0 are exactly zero in row 1,
with a few spuriously large — against a **prebuilt library with no code change**.

**Steps.** Build the copy at the active type inside the reduction, so each recording
gets values with no slot from the previous one. Do not move `clearAll` and do not keep
the copy.

**Task 11 is the same fix done properly.** Recording one time and re-sweeping with
`clearDerivativesAfter()` removes the repeated recording and the aliasing together.
Task 15 is the small correct fix that unblocks measurement now; Task 11 supersedes it.

**How to check.** The single decisive test is cheap: reorder `tf24_census` to put
`area_stem` first and rebuild. Under aliasing `area_stem` becomes exact and `leaf_area`
becomes wrong. Under any cause that belongs to the metric, `area_stem` stays wrong.

**The accumulation gate this task specified cannot fail, and the reason is sharper than "it
is built out of the thing it tests".** C4's failure is a **missing accumulation**, and a
missing term is missing from **both sides** of "a two-cohort gradient against the sum of its
own per-cohort contributions", because both sides come out of the same accumulator. A gate can
see a missing term only if the reference does not share the accumulator. Two arms that do not:

- **Arm A — the R finite difference.** All rows of `census_state_adjoint` against central
  differences of the census reduction **recomputed in R from TF24's written-out equations** at
  fixed state, over every `height`, `log_density`, `area_heartwood` and `mass_heartwood`
  column. This is the only reference available that does not share the accumulator. Include an
  explicit non-zero assertion and a count of the comparisons actually made, so it cannot pass
  by skipping.
- **Arm B — repeatability.** Two successive `census_trait_gradient_tf24` calls must be
  `identical()`. This catches the failure that actually produces a constant factor: an
  accumulator not cleared between passes, so every row is a running total.

**What neither arm catches, and do not paper over it.** A term absent from the accumulation
altogether. Report 05 section 4 says phi-bar has 6M contributions and (4.1) is the only place
they enter, so nothing internal can count them. The only reference that can is a finite
difference of the whole solve with respect to a trait, which Section 9 records as unavailable
at production. **So Task 25's real gate is Task 0's forward tangent.** The two arms above are
what can be run without it. That is a scope limit, not a pass.

### Task 16: carry the traits of the field build into the accumulator

Type: **correctness**. It is the only cause of `k_I`.

**Why.** `trait_adjoint` is written in two places, `Patch::cohort_block_adjoint` and
`Patch::introduction_adjoint`. **The field build is in neither.** The recorded cohort
step takes the field as `cohort_reads` inputs, and the transpose of the field itself
runs through `Patch::light_knot_adjoint` into
`Species::compute_competition_and_slope_adjoint`, which returns
`node_size_adjoints{height, area_leaf, log_density}` — a structure with no trait slot.
`allometry_adjoint` then scatters it into height and `log_density` only.

`k_I` enters the model **only** through
`TF24_Strategy::compute_competition(z, area_leaf_, height_inverse)`, which is
`pars.k_I * area_leaf_ * canopy_shape.Q(z * height_inverse)`. That is inside the field
build. Therefore its adjoint has nowhere to go and is dropped whole, for every metric,
including the metric whose seed is exact.

**The same loss applies to `eta`**, through `canopy_shape`. ~~and partly to `a_l1` and
`a_l2`~~ — **not to those two.** A dry run established that `a_l1` and `a_l2` arrive through
the **size-space adjoint**, which already works. This task's reach is **one row and one
conditional**, and it does **nothing** for the soil retention parameters, which report 07
section 2 wrongly groups with it: those are `double` members of the environment and appear in
no parameter list.

**And every row this task adds is zero on an invasion gradient** (`is_mutant_run`), because a
mutant does not contribute to the field it reads. That is a limit on the task's value, not an
argument against it — the resident gradient is the one that needs it.

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
mature stand, and the cost of a recorded cohort step is not a constant of the model.

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
7. Change `graft_leaf_outputs` to call `output_rows` one time. Supply each row as a
   derivative.
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
not the operating point of the supplied derivative. Rows computed during the record
step cannot have this defect. The supplied derivative also works for the forward type,
and a tape callback does not, so computing them during the record step keeps the
tangent referee of Task 0.

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
6. Do the check on a recorded cohort step that has two supplied derivatives. A recorded
   cohort step with one supplied derivative passes even when the operating point is
   wrong.

**Measured on a dry run of these steps**, at `d3392ea3`: 642 of 642 row entries
bit-identical at an interior, a pinned and a kink state; all 168 entries of the kink
state NaN on both builds, which is the evidence that `0.0 * NaN` was not simplified
away; and 0 of 46 members differing against one old call at every state, including
`PPFD = 1500`. `scratch/leaf_jac_gate.cpp` does not fit this gate — it checks
invariants and never records a row — so a new harness is needed and it links standalone
without an R build.

**WARNING: A finite difference of the recorded cohort step cannot check these rows. The
supplied derivative is zero in value for each supplied input. Therefore the value of the
recorded cohort step does not change when a row is wrong. Eleven trait columns read
exactly zero for two waves of work for this reason. The rows of the leaf are the only
referee.**

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
supplied derivative gives its row. Therefore a gradient for `lma` needs no parameter
row at all.

**This task contradicts report 01 section 4.2, and the contradiction is resolved in
report 01's favour about its own subject.** Section 4.2 says a reverse sweep's cost is flat
in the number of targets, because one sweep yields every trait adjoint together. That is
true of the sweep. Measurement F is 6.68 times because the cost is not in the sweep: it is
in the leaf's supplied derivatives, which report 01 treats as a boundary rather than as a
cost, as its own head banner concedes. **This task is motivated by Measurement F and G and
by no reference document.**

**Counted from the code.** 13 of the 15 leaf parameters are in `ad_parameter_names()`;
the two that are not are `vcmax_25` and `jmax_25`, whose supplied-derivative term is
zero by structure, so the code computes 2 analytic partials and 4 evaluations of
`dprofit_droot_collar_psi` for no result on every call. Of the 13, nine also pass
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
   the bound. Guarding the whole branch would fall through and compute a full set of
   partial derivatives,
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
suspicious.** The 44 entries of `ad_parameters()` all stay in the input vector of the
recorded cohort step, and `rho`, `b`, `c` and `a_bio` also reach `compute_rates` through
equations outside the leaf. Only the marker of step 2 catches this.

**WARNING: `Patch::cohort_block_adjoint` never resets `block_workspace`.** It builds
`strategy_template` under `if (!block_workspace)` and nothing invalidates it.
Therefore a mask set after the first recorded cohort step never reaches the leaf, and two
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
difference step swept and a plateau required. **Add report 02 section 6.9's waist
residual** over all `2n+1` directions under one shared coefficient pair; it is the one
invariant of section 6.9 that this task can use, and the plan dropped all three when it
refused the stationarity identity. **Report 00 records that the conditioning of
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

**On the series' range, and an earlier form of this task was wrong in both directions.** The
series does overflow in double precision for large `x`: `Sigma` goes to infinity while
`e^-x` underflows, and the value is NaN. That is a true fact about the series and it is
**unreachable here**, because `build_cumulative_vulnerability_integral` sets
`psi_max = b * pow(log(1/0.01), 1/c)`, so `X = (psi_max/b)^c = log(100)` identically for
every `b` and `c` and `x <= 4.605`. The warning further down states that correctly. **Write
the assertion it asks for; do not add an argument switch this model cannot reach.**

**This task makes the four columns derivatives. Task 28 makes them answerable.** The closed
forms remove the knot-count discontinuity; `psi_crit` being registered beside `b` and `c`
means the row still answers a counterfactual that cannot happen. Both are needed.

**Take the two derivatives by hand. Do not put a tape inside the leaf.** The leaf is
`double` and gives back rows of numbers, and that is what lets the supplied derivative
serve the forward type and keeps the tangent referee. A tape inside the leaf needs
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
the only reference that does not cross the knot-count step. **Add report 02 section 6.9's continuity invariant to this gate.** `E_up` computed from
the soil side is identically `kappa * (S(psi_stem) - S(p))` computed from the stem side.
Two different interpolant chains produce the same number, so their derivatives must agree
— and that is **the only reference for the interpolant derivative chain**, which is
exactly what this task rewrites. State it as an exact identity, not a tolerance.

**Do not use the
stationarity identity of report 02 section 6.9 as a reference.** `dp*/du` is formed
from `Pi_pp`, so it cancels, and a real 2 percent error in `Pi_pp` passed that
identity with the same bits before and after the fix.

### Task 28: report the vulnerability curve in its own parameterisation

Type: **correctness**, and it is the half of the hydraulic columns that closed forms do not
fix.

**Why.** `TF24_Pars` derives `psi_crit` from `b` and `c`:
`psi_crit = b * power(log(1/0.05), 1/c)`, and `root_psi_crit` from `root_b` and `root_c` the
same way. **All six are in `ad_parameters()`.** Therefore the gradient's `d/db` is taken with
`psi_crit` held fixed — and `psi_crit` is not an independent property of a plant, it is
defined by the curve that `b` and `c` describe. **No plant can be perturbed that way, so the
number answers a question nobody can ask.**

This is the functional-independence precondition of report 05 section 8 failing one level
up, in `ad_parameters()` rather than in the leaf's input list. It is also the likely reason
Section 9 records `psi_crit` and `root_psi_crit` reading zero except when pinned.

**The ecology sets the right output.** A vulnerability curve has two degrees of freedom per
organ: where it sits and how steep it is. An ecologist fits those two to measured data.
Reporting three gradient entries per organ for a two-parameter curve is over-parameterised,
and the third answers a counterfactual that does not exist.

**Decided 2026-08-04: the C++ derivation is the one that counts.** Reverse-mode drivers
interface with `TF24_Pars` directly and not through `make_TF24_hyperpar`. So `J` is built
from the member initialisers, and Task 28's instruction to keep it beside
`ad_parameters()` is the right pairing after all.

**And that ruling settles which relations are constraints, because at the `TF24_Pars` level
the initialisers are defaults.** They run once, at construction, from other defaults; after
that every member is independently settable. So the test is not "does an initialiser
reference another member" but **"is the derived quantity definitionally a function of the
others, or merely conventionally equal to one?"**

| relation | verdict |
|---|---|
| `psi_crit = b * (log 20)^(1/c)` | **constraint.** There is no vulnerability curve with an independent critical potential |
| `root_psi_crit = root_b * (log 20)^(1/root_c)` | **constraint**, same reason |
| `c` from `p_50` | **default.** A fitted trade-off, not a definition — two curves can share a `p_50` and differ in steepness |
| `jmax_25 = 1.64 * vcmax_25` | **default.** A convention |
| `r_b = 2 * r_s` | **default.** Its own comment says "assumed" |

**Therefore `J` has exactly two constraint relations, the free hydraulic set is
`{b, c, root_b, root_c}`, and the two organs are symmetric — two degrees of freedom each,
which is what report 06 section 7 says the ecology requires.** An earlier reading made the
stem a one-parameter family through `p_50`; that follows only if the `c`-from-`p_50`
trade-off is treated as binding, and under this ruling it is not.

**`p_50` stays refused, and the ruling makes the reason sharper.** A gradient with respect
to `p_50` would be the derivative of a model in which setting `p_50` re-derives `c`, `b`
and `psi_crit`. **No such model is implemented** — the initialiser has already run — so a
pulled-back `p_50` column would be a correct derivative of something that does not exist.
Task 19 refuses it and Task 28 does not offer it. Report 07 section 3's suggestion that the
pullback recovers `p_50` for free is withdrawn: it recovers a number, and the number
describes an unimplemented model.

**`K_s`'s incomplete row is resolved by the ruling.** On the C++ path `K_s` reaches only
`leaf_specific_conductance_max` and does not set `p_50`, so the row is complete. The
incompleteness was an artefact of the R route.

**Do not remove anything from `ad_parameters()`. Build the pullback instead.** An earlier
form of this task said to remove `psi_crit` and `root_psi_crit` and let them follow by the
chain rule. Report 07 section 3 gives a better form of the same idea: **keep every internal
parameter registered, and put the parameterisation in a small matrix.**

Let `phi` be the free parameters and `varphi = Phi(phi)` the derivation the initialisers
write. Then `grad_phi(C) = J^T grad_varphi(C)` with `J = d(Phi)/d(phi)`, applied one time
after the sweep. Nothing in the adjoint changes.

**Steps.**

1. Write `J` as a function beside `ad_parameters()`, so the two cannot drift.
2. Report the gradient in the free parameterisation: two entries for each organ's
   vulnerability curve, not three.
3. Gate each entry of `J` against a central difference of `Phi` itself. That is cheap,
   because `Phi` is `double` arithmetic with no model in it. **A `J` that disagrees with the
   derivation is a silently wrong answer.**

**What this buys, and it is why the pullback beats the removal.** `p_50` becomes free
instead of skipped: `d(C)/d(p_50)` is three multiplications against rows the sweep already
produced. Task 19 keeps refusing it *as a registered parameter* and the answer comes back
anyway. And any other parameterisation — a trait-spectrum axis, a calibration's free vector,
a fixed ratio imposed or relaxed — is a different `J` against the same gradient, with no
second sweep. Report 07 section 3 lists them.

**`jmax_25` is derived too**, `jmax_25 = 1.64 * vcmax_25`. It belongs in `J`, which may make
part of Task 20 unnecessary. Read report 07 section 3 before starting Task 20.

**WARNING: removing an entry from `ad_parameters()` changes the trait-adjoint layout.**
`trait_adjoint_size()` sums over species and `census_trait_names_tf24` must agree with it.
Task 3's warning applies: the list is the authority on the layout.

**How to check.** Gate each entry of `J` against a central difference of the derivation itself.
Measured to 5e-10 relative or better on every entry of the C++ graph, and it needs no build.

**The identity is the right gate, and the ruling above is what makes it right.** The
post-task `b` row must equal the pre-task `b` row plus the `psi_crit` row times
`psi_crit / b` — the derivative **holding `c` fixed**, which is legitimate because `c` is
free under this ruling. Measured: `d(psi_crit)/db = psi_crit/b = 2.736305999004` against a
central difference of `2.736305999119`.

**Gate the four columns and nothing else.** `J` is 44 rows by 4 hydraulic columns plus the
identity on every other registered parameter. A rank check on `J` is still required, because
a rank-deficient `J` makes the residual of report 07 section 3 meaningless.

**WARNING: `make_TF24_hyperpar` derives these quantities differently and is not the
authority here.** It computes `c` as `B_c1 * exp(-B_c2 * p_50)` — 2.04 at defaults against
the initialiser's 1.09 — and derives `p_50` from `K_s`. **A run built through
`add_strategies(p, trait_matrix(...))` therefore has a strategy the reverse-mode driver's
`J` does not describe.** Under the ruling, reverse-mode drivers do not use that route. **Say
so at the boundary: refuse a gradient request on a strategy built through the hyperparameter
path**, or the two derivations silently disagree in the answer. The disagreement itself is a
forward-model defect and it belongs to the owner.

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
4. **Add the seed's trait columns to `trait_adjoint` immediately after
   `clear_trait_adjoint()`, inside the per-metric loop.**

**WARNING: do not move `clear_trait_adjoint()`.** An earlier form of this task said it
runs after the seed and removes the term. It does not. `clear_trait_adjoint()` runs at
the top of the per-metric loop on `live`, and the seed is taken above the loop by
`census_state_adjoint`, which is `const` and works on `patch` — the snapshot the run
copies out — and then on a second copy, `active`. Neither is `live`, and
`census_state_adjoint` writes no accumulator at all: `Patch::trait_adjoint` is written
only in `cohort_block_adjoint` and `introduction_adjoint`. **Moving the clear above the
seed takes it out of the per-metric loop, and then the accumulator sums all three metrics
into one row.** The current position is correct.

**How to check.** Compare against the tangent from Task 0, on the birth-date
coordinate. Use `lma`, which reaches the census through `mass_leaf`.

**WARNING: `k_I` is not a control for this task.** An earlier form said `k_I` does not
reach the census algebra, so its result must not change. `k_I` is indeed absent from the
metric functors, but `census_state_adjoint`'s recording calls
`active.set_ode_state(x, time())`, which rebuilds the boundary node, and
`Species::census` reads `new_node.get_density()`, which is
`birth_rate * pr_estab / g` — a physiology evaluation through the light field, which
reads `k_I`. **Measured: 36 of the 44 columns take a non-zero direct term, not the four
the algebra names.** That is not a double count, because the final boundary node is not
ODE state and `introduction_adjoint` covers earlier introductions only. There is no
trait that is guaranteed unchanged, so use the tangent and not a control.

**Measured on a dry run, for the one metric whose seed is sound.** `leaf_area`'s direct
term is `a_l1` `-0.2583`, `a_l2` `+2.1914` — both inside `area_leaf` — and `lma`
`+5.3168e-04`, which is small and non-zero for the right reason: `area_leaf` does not
read `lma`, and that entry comes from the boundary node.

**This task explains none of the three metrics of Section 1.** Task 15 and Task 16 do.

**One premise of Section 1 was wrong and the conclusion survives.** `area_stem`'s inputs
are not functions of `area_leaf` only: `area_sapwood` reads `pars.theta` and `area_bark`
reads `pars.a_b1` and `pars.theta`, so `area_stem` does take direct terms — for `theta`
and `a_b1`, not for `lma`. Its `lma` column still does not move from this task. The direct term is real and absent, and its size is checkable: after Task 15, the
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

**Both instances of this task dissolve into Task 9, and an earlier form said the second one
survives.** `Species::consumption_rate` opens with
`if (control().node_density_in_birth_date) { ... return util::trapezium(times, rates); }` and
**returns before the `std::is_sorted` / `std::sort` block entirely** — the sort exists only on
the height branch. So on the birth-date coordinate there is no sorted forward grid for the
adjoint to fail to mirror.

And once the light transpose reads the introduction time, nothing in it needs descending
heights: the width *is* the abscissa, the `h_max` test is order-free, and the integrand's own
height dependence through `compute_competition_and_slope_partials` is a per-node scatter. **So
the `stop` becomes genuinely removable — for the reason below, applied through Task 9.**

**WARNING: an earlier form of this task said Section 2b made the `stop` unreachable. That
was wrong, in the direction that costs most.** The stop is `if (!scan.decreasing)
util::stop("The competition adjoint needs the node heights in decreasing order; the
sorted-view reduction has no transpose here")`. **It tests height ordering and takes no
coordinate argument.** The forward guards with `if (!birth_date && !scan.decreasing) return
compute_competition_and_slope_unordered(...)`, whose comment says the birth-date grid stays
monotone whatever the heights do.

Therefore on the birth-date coordinate the forward proceeds and the adjoint stops — and that
is the coordinate the gradient is scoped to. Reserve-gated growth makes crossing common, so
the state is reachable in ordinary use.

**Write the transpose.** Either transpose the ordered birth-date reduction the forward runs
there, in which case the heights' order is irrelevant to it, or make the guard
coordinate-aware so it refuses only where the forward refuses. **Do not leave a `stop` on a
path the forward model survives.**

**Two further divergences from the forward function that Task 9 does not name.** The adjoint
lacks the forward's `if (scan.decreasing && h0 < height) break`, and its boundary condition
is `size() == 1 || f_h1 > 0` where the forward's is `size() == 1 || birth_date || f1 > 0`.
Both must move with the abscissa.

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

### Task 9a: `Species::census` is wrong on the birth-date coordinate by 12 to 15 times

Type: **forward-model correctness, and it is not reverse-mode work.** Highest priority here.

**Measured on the unmodified tree at `600e3ebd`**, TF24, `lma = 0.0825`,
`max_patch_lifetime = 20`, 98 nodes on identical `node_times` in both coordinates:
`stand_census` leaf area reads **55.098** on the birth-date coordinate against an R reduction
over birth date of **3.559** — a factor of **12.33**. Mass above ground: 15.48 times.

**Why.** `Species::census` builds its grid from `new_node.height()` and `it->height()`
**unconditionally** while the state is a density in birth date, so it computes
`integral of n_b dh` — a growth-rate-weighted moment of no ecological meaning. `cpp_leaf_area`
equals the R height-reduction *exactly* on both coordinates, which is the proof.

**This is a forward defect on the #590 path.** Task 9 lists `Species::census` among four
reverse-mode substitutions; it is the one that is wrong before any adjoint runs.

**Steps.** Give it the abscissa `quadrature_abscissa` supplies.
**How to check.** The R reduction over the same abscissa, which is what measured the 12.33.

### Task 9: move the reductions to the birth-date abscissa

**Three edit sites, not four, and step 2 is more than a substitution.**
`SCM::census_state_adjoint` differentiates by tape, so it follows `Species::census`
automatically and is not an edit site. Moving `consumption_rate_adjoint` **reverses its slot
mapping**: the forward's birth-date branch appends `new_node` last, while the adjoint puts the
boundary node in slot 0 and reverses the interior, so the boundary moves to slot `n-1`.

**The transpose gains an exactly-zero row that must be asserted, not discovered.** With a
passive abscissa, `consumption_rate_adjoint`'s abscissa channel has no counterpart and
`out[k].height` receives nothing from that reduction. That is correct — height reaches the
adjoint through the recorded cohort step — but `METHOD.md` section 1 requires an exactly-zero
row to be deliberate.

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
recorded cohort step already gives the mortality rate as an output. Therefore the
transport output repeats an output that exists.

**Steps.**

1. Remove the transport output from `Individual::block_outputs`.
2. Add the transport seed to `seeds.rate[MORTALITY_INDEX]` with a minus sign.
3. Delete `seeds.transport`, a `block_seeds` member written in `Patch::ode_rates_adjoint`.
   **Three further sites an earlier form missed**: `block_output_size()` becomes
   `state_size() + n_resources()`; `Patch::cohort_block_adjoint` has **two** places, the
   `check_length` on `seeds.transport` and `out_adjoint.assign(n_state + 1 + n_resource, ...)`
   with its offsets; and **`scripts/wire-gates.R::transport_block_gate` changes meaning without
   failing** — its `rep(0, 12)` seed becomes merely over-long while `row <- n_strategy_states + 1L`
   then seeds the first consumption output and is compared against a transport difference.
   **There is no `Patch::transport_adjoint`**; an earlier form of this step named one and it
   exists on no branch. Find the write site, not a function.

**WARNING: this task inverts a standing warning in `METHOD.md` section 6**, which records
that `block_vjp`'s output-adjoint seed is length 12 for TF24 and that a length-11 seed
reliably corrupts the heap. After this task 11 is correct. **Update that warning in the same
change.** Both numbers are configuration-dependent: the count is
`state_size + 1 + n_resources`, so 12 holds at five soil layers only.

**Result.** The recorded cohort step has 11 outputs and not 12. Report 01 section 1 step
(a) gives `lambda_g` for each cohort. That seed has no source now. The order of the
seeds becomes less strict, because no seed reads a neighbour.

This also removes the second leaf solve from each recorded cohort step, because
`growth_rate_gradient` no longer runs. Therefore the calls in Task 1 fall from
about 10.64 for each recorded cohort step to about 5.3 before Task 1 is applied.
**Both numbers are withdrawn — see Section 4. The measured share on the birth-date
coordinate is 99.2 percent, so this section's ceiling is 0.8 percent, not 2.**

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
step. Therefore the code records the same cohort step three times. It also runs
`widen_over_introductions` and the stage rebuild three times.

**Steps.**

1. Add a seeds-plural form of `odelia::ode::vector_jacobian_product`. Record one
   time. Then, for each seed set: clear the derivatives, set the output adjoints,
   call `computeAdjoints()`, read the input adjoints.
2. Use `getPosition()` and **`clearDerivatives()`**. Note that
   `vector_jacobian_product` calls `clearAll()` and `newRecording()` on entry
   today, which destroys the recording this task must reuse.

   **WARNING: do not use `clearDerivativesAfter()` between columns.** It truncates the
   tape rather than zeroing the derivative slots, so column `c` would return the sum of
   columns 0 to `c`. The columns would all be wrong and all plausible. `clearDerivatives()`
   zeroes and keeps the recording, which is what re-sweeping needs.
3. Carry `K` columns through `Solver::solve_adjoint` and `Step::step_adjoint`, **and also
   `SolverInternal::step_adjoint` and `Step::sweep_stages`, which this task did not name.**
   **You need a new concept** — `AdjointRatesColumns`, being `AdjointRates` plus
   `ode_rates_adjoint_columns`. Without one, `step_adjoint` silently takes the singular hook
   in a loop and sums every column's trait contributions into one row. Add
   `static_assert(AdjointRatesColumns<patch_type>)` at the call site and print the concept's
   value before anything is compared, or the failure is silent.
4. Carry `K` columns through `Patch::cohort_block_adjoint` and
   **`Patch::introduction_adjoint`**, which this task did not name and which silently sums
   the metrics into one row without them. Record one time and sweep `K` times.

   **The diff is smaller than this task implies. Only those two hold recordings.**
   `soil_adjoint`, `offspring_adjoint`, `light_knot_adjoint` and `allometry_adjoint` are
   closed-form transposes with column-independent coefficients and no tape, so **leave them
   singular** and loop them for each column: it costs nothing. A dry run wrote the whole task
   at 289 insertions in odelia over 5 headers, every signature change additive, and 429 in
   plant, of which the one genuinely breaking member is `Patch::trait_adjoint` becoming
   `K` rows.
5. Make `trait_adjoint` hold `K` accumulators. Run `widen_over_introductions` one
   time.
6. Remove the metric loop from `census_trait_gradient`.

**WARNING: The narrowing between segments must apply to all `K` columns. Check per
column. `Patch::ode_state` is species-major, so the per-species newcomer list is
shared between the columns.**

**WARNING: This task changes signatures in odelia. odelia calls such a change
`cross-package` and `breaking`.**

**How to check.** This task's original gate — "each column bitwise equal to the single-seed
sweep for that metric" — is **worse than vacuous. It is inverted.** The single-seed sweep for
metric `m > 0` **is the aliased one**, so bitwise agreement demands reproducing the aliasing
and only the broken implementation passes.

Three arms. **None discriminates alone, and that is the point.**

**Arm A — external correctness.** All `K` rows of `census_state_adjoint` against central
differences of the census reduction **recomputed in R from TF24's written-out equations** at
fixed state, over every `height`, `log_density`, `area_heartwood` and `mass_heartwood` column.
The reference never touches the tape, so no arrangement of recordings can make it pass — only
a correct Jacobian can. This is `test-census.R`'s G4 extended from `leaf_area`, the one metric
the aliasing leaves correct, to all three rows. Under aliasing rows 1 and 2 fail by 50 to 300
times with 33 of 52 columns exactly zero. Include a non-zero assertion and a count of
comparisons made, so it cannot pass by skipping. **A dry run reached 854 assertions passed and
7 failed before its session limit cut the run, and could not attribute the 7. So the decisive
correctness result is unconfirmed: 854 of 861 is encouraging and is not a pass. Re-run this
file first.**

**Arm B — bitwise, relocated to one step.** At the census level bitwise is inverted; **at one
step there is no aliasing to reproduce**, because `step_adjoint`'s per-stage recordings were
already fresh for each stage. So the bitwise comparison is recoverable there, it is not
vacuous, and it exercises the whole column plumbing. A dry run passed it: state and trait
bitwise identical on every column, `max|diff| 0.000e+00`, columns distinct, trait rows
distinct.

**Arm C — cost, structural.** No gradient *value* distinguishes "one recording, `K` sweeps"
from "`K` recordings, `K` sweeps". The quantity that moves is the recording count, which is
why Section 9 asks for `block_records`. A dry run measured 48 records against 144 for `K`
singular sweeps, with sweeps at 144 either way — 48 being 8 cohorts by 6 stages, exactly
`1/K`.

**Arm A cannot see whether the record was shared. Arm C cannot see a wrong number. Arm B
cannot see rows 1 and 2 of the census.** The triple discriminates; no member does. Linearity
makes exact agreement the expectation and not a tolerance in arms A and B.

### Task 12: reuse the leaf operating point

Type: cost. Memory: **zero incremental**. Build this one; do not build 13; defer 14.

**Why.** `ode::derivs` at stage `i` solves every cohort's leaf to build the stage
rate. `cohort_block_adjoint` at stage `i` then solves the same leaf again at the
same inputs. Both loops are inside one `step_adjoint` call. Therefore the
operating points do not cross a step boundary.

**The memory is already spent, so this task costs none.** odelia's `step_adjoint`, on the
`AdjointRates` branch plant takes, already runs `aux.assign(6, state_type(system.aux_size()))`,
fills each stage with `system.ode_aux(...)` in the rebuild loop, and hands it back with
`system.set_ode_aux(...)` before `ode_rates_adjoint`. This task reads storage that exists.
The aux carrying the operating point is **11 doubles for each cohort**, not 15
(`TF24_Strategy::aux_names()`), plus `environment.aux_size()` = 5 for each stage.

**A dry run measured the population this converts: 15 120 of 46 624 leaf solves in one
gradient, 32.4 percent.** Priced at the probe's own per-call figures — 10.2 us for a search
and 1.0 us for an evaluation — the saving is about **0.14 s of a 138 to 305 s gradient**.
That is 0.05 to 0.1 percent. Re-price it after Tasks 1 to 5 and do not expect more before
then.

**This task is not correct as written. Two things are owed.**

1. **Carry `collar_pinned_` in the stored operating point.** `collar_pinned_` is set true
   only in `polish_root_collar_psi`, which only `find_root_collar_psi` reaches.
   `evaluate_root_collar_psi` goes through `prepare_collar_solve`, which sets it **false**,
   and nothing sets it back. `Leaf::input_adjoints` **branches on it** — the pinned branch is
   the one where the envelope theorem fails at a bound and the profit term reappears through
   `Leaf::bound_partials`. So restoring the point without its classification makes the
   adjoint take the interior branch at cohorts whose forward solve was pinned. A dry run
   measured the consequence: **120 of 132 gradient entries differ, worst 1.134e-08, on the
   `root_c` column.** That is a missing term, not float reordering. Storing it needs a new
   aux slot, which changes `aux_size()` and what R sees.
2. **Add `collar_pinned_` to `scripts/aux_round_trip.R`'s compared set** and require a
   **bit-identical gradient** as the gate.

**WARNING: This is exact restoration and not a warm start. Report 01 constraint C7
forbids a warm start. The difference is that a restored operating point is the one
the forward pass computed, and a warm start is a guess.**

**WARNING: the round-trip probe cannot tell them apart today.** Its 14 compared quantities
are all leaf values and `collar_pinned_` is not among them, so its restoration arms pass 9
of 9 while the gradient moves at 1e-8.

**Two corrections to what this task claimed the probe measured.** The probe's arms are: A1
restore after an intervening solve, **9 of 9**; A3 one evaluation at the stored point, **9 of
9**; A2 a fresh leaf with no carried caches, **8 of 9**. This task read A2's figure as
restoration's. Restoration is 9 of 9. And **A2's ninth state is not fixed** at `600e3ebd`:
soil layers 3 to 5 keep the previous cohort's uptake across `set_physiology`, reproducibly,
which a dry run could not reconcile with `src/leaf_model.cpp:328`
(`soil_consumption_.assign(soil_number_of_depths_, 0.0);`, unconditional as read). **Resolve
that before Task 1 fixes row bit patterns in place**, because report 01 section 5 makes
cohort-order independence a precondition of the whole reverse sweep.

### Task 13: ~~cache the six stage fields inside a step~~ — **retired, do not build this**

The duplication is real: the rebuild loop's `ode::derivs` builds the field at stage `i`, and
`sweep_stages` then calls `set_ode_state_and_field` at the same stage state. Five reasons not
to remove it this way.

1. **The named hooks cannot reach it.** `record_stage` and `has_recorded_field` are consulted
   only by the indexed `ode::derivs(system, y, dydt, time, index)` — the rebuild loop. The
   second build is `sweep_stages`'s own direct `set_ode_state_and_field` call, which has no
   hook. Removing it needs an odelia change this task did not price.
2. **The indexed overload covers stages 1 to 5 only.** Stage 0 takes the unindexed overload,
   so at most 5 of 6 builds are reachable.
3. **7 kB is really about 29 MB.** `record_stage` is called from the forward `step()`, so a
   field recorded through it crosses the step boundary and must be held for every accepted
   step: 6 x 130 x 8 B x 4 644. The 7 kB figure is true only of a cache built and discarded
   inside one `step_adjoint`, which these hooks do not give.
4. **It would zero the field's derivative.** The `Replayable` concept documents that
   `has_recorded_field() == true` means the recorded values are reused as fixed doubles.
5. **plant already has a per-stage field cache** for mutant runs — `cache_RK45_step(int)`,
   `environment_history`, `environment_cache`, `set_ode_state(It, int index)`,
   `rate_environment()` — and it stores a whole environment for each stage. Any future
   attempt starts there, not from the empty hooks.

**And report 07 section 1's closing bullet does not delete this task, because it is about a
different object.** It says the field-to-cohort coupling is assemblable analytically from
stored heights. That is `dR/d(Lambda)`, the transpose weights. Task 13's object is `Lambda`
itself, whose **values** the leaf still needs: its scalar is
`pars.k_I * std::max(light, S(0.0001)) * PPFD`, so the coupling carries `k_I` (a live
registered row), `PPFD` (an extrinsic driver), and a **floor at 1e-4 that branches on the
field value itself** — which makes the assembly circular without `Lambda`. Report 07 is right
about its own object and mis-aimed at this one.

The deciding reason is neither: **the ceiling is 0.8 percent.**

### Task 14: store the stage rates, and do not rebuild them

Type: cost. Memory: **about 600 MB**. **Deferred — do not build before Tasks 1 to 5.**

**Why.** The last repeated work is the six `ode::derivs` for each step. To avoid
it you must hold `k1` to `k6` without computing them, which means storing them,
and then storing the operating points as well.

```
stage rates       6 x 1137 doubles for each step
operating points  6 x 141 x 11 doubles for each step, plus 5 for the environment
                  = 6 x 16 158 doubles = about 129 kB for each step
                  = about 600 MB for 4 644 steps
```

**This task subsumes Tasks 12 and 13.** With `k1` to `k6` stored the rebuild loop runs no
`derivs`, so neither its leaf solves nor its field builds happen. The sweep-side solve
remains and needs an operating point, which this task stores anyway. So Task 12 is the free
half of this one and Task 13 is a proper subset of it.

**The exchange is linear and it is uniform, so a window buys its pro-rata share.** Memory for
each step and time for each step both scale with the same cohort count, so saving-per-byte is
flat across the run and no subset of steps is a better buy than any other. There is no
interior optimum in **which** steps to store. **This task previously read "a window buys
nothing and the saving comes only from `W = N`". That reads as a threshold and there is
none.** The interior point that does exist is in **what** you store: the operating points are
81 percent of the 129 kB and the stage rates are 19 percent — but storing rates alone does
**not** let you skip the rebuild, because `sweep_stages` needs each stage's aux and the
trajectory holds no stage aux.

**The deeper reason a window cannot beat the rebuild, which this task did not state.**
Checkpointing pays only when a refill must re-run from a distant checkpoint.
`Patch::record_ode_step` stores **every** accepted step's start state and
`Solver::solve_adjoint` passes `states[k-1]` to `step_adjoint`, so each rebuild is already
one step's six `derivs`. The recompute is already minimal and already local. There is nothing
to amortise.

**The ceiling sits between one species and two.** Measurement B gives 0.262 GiB at one
species. At `W = N` this adds 600 MB, so 0.86 GiB and 2.3x headroom. Two species roughly
doubles the cohort count, so both terms double: about 1.7 GiB against 2 GB, **15 percent
headroom** — and a longer lifetime multiplies the step count linearly with no cap. So this is
affordable exactly at the configuration already measured and nowhere past it. Build it as a
bounded window with recompute as the fallback, and expect the fallback to be the common case.

**These figures are arithmetic from the code's sizes, not measured. Measurement B has not
been re-taken.**

Report 01 section 1 chose rebuild over store because "storage is independent of
the stage count". That reasoning was correct and it was taken before peak memory
was measured. That is why it can be revisited.

---

## 9. What remains open

Each item below blocks something. Do not treat the list as background.

- **A branch kink makes the whole gradient NaN, and nothing falls back.**
  `Leaf::layer_flux_partials` returns with every entry NaN when any layer meets one of
  three conditions: equal potentials, gravity balance, or a collar potential within 1e-8
  of zero. No caller of it tests for that. The NaN reaches the row, and `graft` computes
  `partial * (x - to_passive(x))`, whose second factor is exactly zero in value, so
  `NaN * 0.0` puts NaN in the **value** of `leaf_profit_` and therefore in
  `net_mass_production_dt`. **The plain `double` run is safe**, because
  `graft_leaf_outputs` is called under `if constexpr (!std::is_same_v<S, double>)`.
  **Both AD paths are not**, so one kink in one cohort makes the gradient and the
  tangent referee NaN together. `Leaf::dE_from_soil_dpsi_collar` says its NaN means "the
  caller falls back to finite differences", and on the supplied-derivative path no such
  fallback exists. Decide what a row holds at a kink before Task 1 fixes its bit
  patterns in place. Also check whether the `bound_a` pin meets the equal-potential
  condition by construction, which would make this reachable on every pinned recorded
  cohort step.
- **`schedule_eps` alone refines nothing.** `refine_schedule` is off by default: six runs at
  `schedule_eps` 1e-3, 1e-4 and 1e-5 gave 98 nodes and identical values. **Any plan reaching a
  converged schedule through `schedule_eps` silently runs the default**, and Section 2b makes
  convergence a precondition. Drive `refine_schedule` and confirm by node count.
- **Neither offspring number is converged, and the coordinate move is a real change in the
  answer.** The census *is* coordinate-invariant in exact arithmetic —
  `Node::compute_initial_conditions` carries `n_b = n_h * g` at birth and nowhere else — and
  two discretisations on the same 98 nodes agree to **5.3 percent** for leaf area and 11 percent
  for mass. Offspring moves by 12.3 times, and the cause is grid conditioning: on the height
  coordinate 37 nodes sit within 0.02 m of each other at 17.53 m, so the trapezium has
  near-zero widths where the density is largest. Understorey light is 15 to 18 percent brighter
  on the birth-date grid, and **cohorts the height quadrature shades to death survive and
  reproduce** — fecundity 4.40 against 2.03e-07 at one node. So 395.45 is a better-resolved
  answer to the same question, not an artefact. **Which is right is not established.**
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
- **`test-census.R`'s G4 checks the census seed for `leaf_area` only**, which is metric
  0 — the one metric the aliasing of Task 15 leaves correct. Therefore it is a gate that
  cannot fail for the two broken metrics. Extend it to all three.
- **There is no cost gate anywhere.** Nothing asserts that a recorded cohort step costs
  what it was measured to cost. That is how a factor of 300 sat behind a green suite for
  three waves. **Land each task in this document with a cost gate.**
- **`Patch::block_recording_size` and `block_sweeps` are not exported to R**, so
  the instrument for the worst failure mode needs a C++ harness to read. Export
  them. **And neither is sufficient**: neither is a *recording count*, which is the quantity
  Task 11 moves, so export a **`block_records`** counter beside them. **Read them from the
  live patch.** `SCM::r_patch()` is a snapshot whose accumulators are zero, so a cost gate
  reading it could not fail; add **`SCM::r_live_patch()`**.
- **A default `Control()` makes a one-step finite difference unusable, and this is a trap
  every gate in this document can fall into.** `scripts/v3-driver.R` documents it: at
  `GSS_tol_abs = 1e-1` one step's `y_end` is not Lipschitz at the difference step, and
  `node_gradient_eps` multiplies the growth rate's irreproducibility by a million. A dry run's
  first gate script used the defaults and **would have produced a confident false alarm.**
  Pin every finite-difference gate to v3-driver's values — `GSS_tol_abs = 1e-6`,
  `node_gradient_eps = 1e-3` — and put the reason in the script's header.
- **`Species::set_birth_state` is called by no test**, and report 01 constraint C6
  says the reverse pass must restore `pr_patch_survival_at_birth`, which divides
  the fecundity rate.
- **`beta_R_H` and `beta_R_V` have no row**, so a strategy that varies either reads
  exactly zero. Neither is user-seedable today, which is what stops this from
  biting.
- **`psi_crit`'s interior zero is correct; the defect is the shutdown branch.** An earlier
  form recorded the zero as unexplained. On an interior optimum `psi_crit` appears only as a
  bracket endpoint the optimum satisfies strictly, so the derivative is zero **exactly, by
  complementary slackness**, and `reaches_operating_point`'s exclusion is right. A genuinely
  pinned collar does get a row, from `bound_partials`.
  **`set_shutdown_state` is where it breaks.** It puts `psi_crit` directly into
  `profit_ = -R_d_ - hydraulic_cost_TF(psi_crit)` while `prepare_collar_solve` has already
  cleared `collar_pinned_ = false`, so `input_adjoints` takes the interior branch and the row
  stays zero although the profit genuinely depends on it. **Worse: in shutdown the whole interior
  parameter block is evaluated at a stale linearisation point**, because `set_shutdown_state`
  never goes through `profit_psi_stem_TF`, so `ci`, `psi_stem`, `supply_share` and `Pi_pp` are
  whatever the last real solve left. Shutdown needs a third branch: it is a pin to `psi_crit`,
  and neither the envelope argument nor `bound_partials` applies — the latter raises when
  `prepare_collar_solve` returned false.
  Whether the recorded −2.39e-04 arm was in shutdown or at `bound_b` is not established. Log
  `collar_pinned_` and `prepare_collar_solve`'s return at the perturbed arm to discriminate.
- **~~`K_s`'s row is incomplete~~ — resolved by the ruling in Task 28.** On the C++ path
  `K_s` reaches only `leaf_specific_conductance_max`, so its row is complete. The
  incompleteness existed only on the `make_TF24_hyperpar` route, where `K_s` also sets
  `p_50`. **What remains is the boundary refusal**: a strategy built through the
  hyperparameter path has a derivation the reverse-mode `J` does not describe.
- **`Patch::cache_ode_step`, `cache_RK45_step` and `load_ode_step` have no caller**
  in either repository, and they are the two known `test-mutant.R` errors.
- **The light field reaches each cohort through one number, and 126 of 130 columns are
  structurally zero.** Report 07 section 1: mean-light mode queries the field at
  `height * eta_c` only, and a cubic Hermite query reads four knots. The sweep does not pay
  for the zeros; the scatter of `in_adjoint` does, at 130 entries per cohort per stage where
  four are live. Not in any measurement.
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
each recorded cohort step. The code does not obey its own comment.

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
| 10, transport seed | about 2 | calculated from A | the second leaf solve for each recorded cohort step | #590 moves them, not this task |
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
and commits; `adjoint`, `derivative`, `gradient`, `Jacobian`, `tangent`, `seed`,
`sweep`, `tape`, `cohort`, `stage`, `census`, `reference`, `abscissa`, `quadrature`,
`trapezium`, `scalar`, `coordinate`, `mortality`, `trait`, `tabulation` and
`birth date`. Section 3 defines the two terms this document uses in a particular
sense: `the recorded cohort step` and `the supplied derivative`.

Two other deviations:

1. Some sentences in Section 6 and Section 8 are longer than 20 words. The
   mathematics needs them.
2. The tables use noun phrases and not sentences.
