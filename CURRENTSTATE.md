# Current state: what the code does, and where it departs from the design

This is the register of **fact about the implementation**. It is the third of three documents and
they divide as follows:

- `docs/reports/00`–`07` state the mathematics, the ecology and the structure. They name no code and
  they do not track progress. They are true or they are wrong; they are never out of date.
- **This document** states what the code does today, where that differs from the reports, and what
  has been measured. It goes out of date on every commit, and that is its purpose.
- `NEXTSTEPS.md` states what to build, in what order, and how to check it.

If a claim here disagrees with a report, one of them is wrong and the disagreement is the finding.
If a claim here disagrees with the code, this document is wrong.

**Written in plain English rather than in the Simplified Technical English `NEXTSTEPS.md` uses.** A
register of defects needs to state exactly what is wrong with what, and STE's restricted vocabulary
costs more precision here than it buys clarity.

## Provenance

Every claim below is stated against:

| | commit | branch |
|---|---|---|
| superproject | `459e262` | `claude/odelia-ad-tape-reverse-496fuf` |
| `plant` | `66029469` — `600e3ebd` (`v1.2.1-427`) plus the census abscissa fix | — |
| `odelia` | `a3bcf58` | `p3/odelia-integration` |
| `logpile` | `cdef780f` | `main` |

**A claim about code decays and mathematics does not.** So each entry below says how it was
established: **read** from the source, **measured** with a configuration attached, or **inferred**
and needing a named check. An entry with none of those is not yet a finding.

**And a comment is never evidence of behaviour.** Four times in this project a comment describing a
hazard has been recorded as evidence *of* that hazard, when the comment sat above the guard that
removed it. Read the guard.

---

## 1. The contract between the algebra and the code

Report 05 §2 names its quantities without naming the code. This is the mapping.

### State

| Report 05 | Code |
|---|---|
| $h_k$ | `HEIGHT_INDEX` |
| $\ell_k = \log n_k$ | `Node::log_density` — **not** an `Individual` state slot, with `log_density_dt` and `set_log_density_rate` beside it |
| $b_k$ | `introduction_time()` |
| $m^{\mathrm{hw}}_k,\ a^{\mathrm{hw}}_k$ | `state_idx_mass_heartwood`, `state_idx_area_heartwood`, cached from the `state_names()` map. `MASS_HEARTWOOD_INDEX` and `AREA_HEARTWOOD_INDEX` are **FF16's** macros, not TF24's |
| $r_k$ | `state_idx_storage`, addressed as the heartwood pair is |
| $\theta_j$ | `Environment::vars.state(j)` — **not what the recorded step reads** |
| $\psi_j$ | `get_soil_water_potential_state()`, seated in `psi_soil_cache_` — this is what `cohort_reads` pushes |
| $y$ | `Patch::ode_state` |

Only `HEIGHT_INDEX`, `MORTALITY_INDEX` and `FECUNDITY_INDEX` exist as macros.

### Intermediaries

| Report 05 | Code |
|---|---|
| $A_k$ | `area_leaf` |
| $E^{\mathrm{comp}}(z)$ | `compute_competition` |
| $p^\star_k$ | `opt_psi_stem_`, `root_collar_psi_` |
| $\Pi_k$ | `Leaf::profit_` |
| $U_{kj}$ | `soil_consumption_` |
| $\kappa_k$ | `leaf_specific_conductance_max_` |
| $c^{\mathrm{i}}_k$ | `ci_` |
| $G(\cdot)$ | `build_cumulative_vulnerability_integral` |
| $g_k,\ \mu_k$ | `rate(HEIGHT_INDEX)`, `rate(MORTALITY_INDEX)` |
| $\tilde Q(\nu)$ | `CanopyShape::Q` |
| $\eta,\ k_I$ | `pars.eta`, `pars.k_I` |
| $\mathcal{C}$ | `Species::census` |
| $\varphi$ | `ad_parameters()`, $P = 44$ per species |
| $x_k$ | `Species::abscissa_of` |
| $s,\ m$ of §7.2 | `s_adjoint`, `mu`; the divisor $\Pi_{pp}$ is `dR_dcollar_at` |
| $\partial B/\partial u$ of §7.4 | `Leaf::bound_partials` |
| the §8 construction | `TF24_Strategy::graft` |

### The reverse pass, in call order

Report 05 §3 and §4 describe six hops the reports do not name. A reader cannot get from the algebra
to the code without them:

`Solver::solve_adjoint` (`ode_solver.hpp:268`) → `SolverInternal::step_adjoint`
(`ode_solver_internal.hpp:51`) → `Step::step_adjoint` (`ode_step.hpp:259`) →
`sweep_stages` / `stage_state` / `stage_row` (`:224`, `:195`, `:184`) → `Patch::ode_rates_adjoint`
(`patch.h:1747`) → `Patch::cohort_block_adjoint` (`patch.h:1478`).

### The two accumulators, and what they forbid

**Read, by exhaustive search of the superproject for `trait_adjoint`:** there are exactly two
accumulating sites — `Patch::cohort_block_adjoint` (`patch.h:1582`) and
`Patch::introduction_adjoint` (`patch.h:1684`). Everything else is a declaration, a sizer, a clear,
a read, or scratch. Both are reachable in every run.

**There is no third accumulator hiding behind an adjacent struct.** `node_size_adjoints` and
`node_uptake_adjoints` (`node.h:14-26`) have three members each — `area_leaf`, `height`,
`log_density`, and the uptake triple — and **no parameter member**. So nothing in either reduction
transpose can route to a trait row, however correct its arithmetic.

This single structural fact is the cause of four separate report-05 departures (§3.1 items 2 and
11 below). They are one defect with four symptoms, not four defects.

---

## 2. Departures from report 05, in dependency order

The order is a dependency order, not a priority order. Fixing an item before the item it depends on
produces wrong values in a new channel with no signal saying which of the two defects produced
them.

| | departure | report | how established |
|---|---|---|---|
| 1 | An active copy outlives a cleared tape, so every functional after the first reads unrelated storage | §9.1 | measured; mechanism read |
| 2 | The field reduction has no parameter accumulator, so four parameters lose their field-build channel | §6.1 | read |
| 3 | The census direct term is not registered | §9 | read |
| 4 | No guard on the intercellular-CO₂ bracket at a non-producing individual | §7.5 | read |
| 5 | A non-finite supplied derivative at a branch kink corrupts the value | §8 | read; one instance derived |
| 6 | The transport derivative is the spline's, not the closed form | §7.6 | read — **cost, not correctness** |
| 7 | The parameter half of $\Pi_{pu}$ is differenced; conditioning unmeasured | §7.3 | read |
| 8 | The consumption adjoint is not the transpose of a sorted forward grid | §6.2 | read |
| 9 | The seed height's derivative is imposed zero, and no reference exists to referee a fix | §10.1 | read; consequence measured |
| 10 | The light reduction is not the transpose of its forward function on the birth-date coordinate — four discrepancies | §6.1 | read |
| 11 | The water reduction's parameter half and the initial-condition term are absent | §10 | read |
| 12 | The bound is the maximum of two magnitudes and one can never win, so the root-critical branch is dead | §7.3 | read |
| 13 | Two census quadratures took the wrong abscissa. **The C++ half is FIXED at `66029469`; the R half is outstanding** | §9 | read; error measured at about 4 percent — a defect in the objective |

**Item 8 precedes item 2, and item 10 precedes item 2.** Item 2 adds parameter rows to reduction
transposes; items 8 and 10 are those transposes not matching their forward functions. Extend a
transpose only after it is a transpose.

**Item 12 precedes item 7 and precedes report 07 §3.** A correct constrained row evaluated at a
bound past the root grid is a correct derivative of an extrapolated wrong-way flux, so building the
selector before fixing the sign would validate the new branch and lock the poisoning in. It is one
line.

**Item 13 precedes all of them**, because it is a defect in the quantity being differentiated. **And
it is two paths, on opposite sides of the R boundary — of which the C++ one is now closed.**

> **`Species::census` is fixed at `66029469`.** It integrates over `quadrature_abscissa()` rather than
> `height()`, which corrects the measure on the birth-date coordinate and removes the ordering hazard
> there at the same time, since birth dates cannot invert. Gated two ways against a build of the
> parent commit: the **height** coordinate is unchanged to every printed digit — leaf area
> 4.1526002307, above-ground mass 12.3501592205, stem area 0.0041602088 — and the **birth-date**
> coordinate moves, leaf area 12.8932796075 to 3.5059067337. Offspring is unchanged in both arms, so
> the reproduction integral is undisturbed. Configuration
> `scripts/measure/census-abscissa-gate.R`, lifetime 20, `lma = 0.0825`, `hmat = 5`, birth rate 20.
> `test-scm.R` passes 140 of 140.
>
> **The height coordinate keeps the ordering hazard**, because its abscissa is $-h$, which is monotone
> only while the heights are. That coordinate is out of the gradient's scope and still wants the
> sorted-view treatment the two reductions already apply.
>
> **`integrate_over_size_distribution` in `plant/R/tidy_outputs.R` is unfixed** and carries both halves
> of the defect. It is the path a user's output takes. The guard status across the four quadratures
over the size distribution:

| quadrature | guards a non-monotone grid? |
|---|---|
| `Species::compute_competition_unordered` | **yes** — falls back to a sorted view |
| `Species::consumption_rate` | **yes** — sorts |
| `Species::census` (C++) | **no**, and it does not branch on the coordinate either |
| `integrate_over_size_distribution` (`plant/R/tidy_outputs.R`) | **no** — `trapezium` on whatever order the tidy frame carries |

**Read:** the R helper calls `-trapezium(.data$height, density * .x)` inside a `reframe` over grouped
rows, and there is **no sort anywhere in that file.** It is the path a user's output goes through.

**Measured, and this is the first size this defect has had.** From a dry start at
$\theta = 0.10$ — a legitimate initial condition — heights invert in **57 of 99 steps**, with up to
**18 inversions in one step**, while the stand produces **525 offspring**, so this is a live stand and
not a degenerate one. Integrating the final state as-ordered against height-sorted:

| census | as-ordered | height-sorted | error |
|---|---|---|---|
| $\sum w n h$ | 22.997032 | 22.130695 | **+3.91 %** |
| $\sum w n A_{\text{leaf}}$ | 4.2544257 | 4.0929236 | **+3.95 %** |
| $\sum w n m^{\mathrm{hw}}$ | 9.1955007 | 8.8415611 | **+4.00 %** |

**Same cohorts, same densities, only the row order differs.** So it is pure quadrature error in the
objective, before any derivative exists. Reports 05 §9 and 06 §8 call this the chain's first link and
the least guarded; the number on this stand is about **4 percent**.

**And the sorted fallback demonstrably works where it is applied:** the C++ light profile from the
same run is monotone in 99 of 99 steps.

**And on the birth-date coordinate the wrong-order grid is the second defect, not the first. The
first is the wrong measure.** Three reads settle it:

1. **`Species::census` integrates over `height()` and never consults the coordinate.** An exhaustive
   search of its body for `abscissa_of` and `quadrature_abscissa` returns **zero** hits.
2. **`abscissa_of` returns `introduction_time()` on the birth-date branch** and `-height()` otherwise.
3. **The boundary condition omits the growth-rate divisor on the birth-date branch and includes it on
   the height branch**, verbatim in `Node::compute_initial_conditions`:
   `set_log_density(log(birth_rate * pr_estab))` against
   `set_log_density(g > 0 ? log(birth_rate * pr_estab / g) : log(0.0))`.

Read (3) with (1): **the $1/g$ factor is exactly what makes the height-coordinate density a density
with respect to height.** Without it, the birth-date density is a density with respect to *birth
date*. So integrating it over height applies the wrong measure, and the two differ by the Jacobian
$\lvert \mathrm{d}h/\mathrm{d}\tau \rvert$ — which is the transport term reports 04 and 05 §5.1
discuss. **Sorting by height fixes the cancellation and leaves this error untouched.**

**The right fix is to integrate over the abscissa, and it closes both defects at once.** On the
birth-date coordinate the abscissa is monotone **by construction** — nodes are introduced in time
order and nothing can reorder a germination date — so a trapezium over it needs no ordering guard at
all. On the height coordinate the abscissa is $-h$, which is monotone only when the heights are, so
the guard is still owed *there*; that is the coordinate the gradient does not support.

**So the measured 4 percent is a lower bound on the birth-date coordinate.** It was obtained by
re-sorting one state, which holds the measure fixed, so it sizes the ordering error alone. The
measure error is separate and unmeasured.


**This dry-start configuration is the fixture Task M8 needs.** It inverts heavily and stays alive, so
it does not require hunting for a crossed state at default settings.


### Item 1: the aliasing, and what makes it certain

**Read.** `SCM::census_state_adjoint` hoists `auto active = patch.template rebind_from<scalar>();`
out of the per-metric `vector_jacobian_product` loop. `vector_jacobian_product` calls `clearAll()`
and `newRecording()` on entry (`gradient.hpp:178-185`). `clearAll()` pushes a fresh `SubRecording`
whose `iDerivative_` is value-initialised while a surviving `AReal` keeps its old slot
(`odelia/src/Tape.cpp:106-119`, `XAD/Tape.hpp:266-300`).

**The same hazard is documented twice in the tree, by code that defends against it:**

- `Patch::cohort_block_adjoint` — "The tape and the buffers persist. No active value does:
  `clearAll()` returns the tape's slot counter to zero, so a value outliving a recording aliases."
  It builds a fresh active individual and environment per cohort.
- `Step::step_adjoint`, non-`AdjointRates` branch — "an input carrying a slot from the previous
  recording registers as a variable with no dependencies, and its adjoint sweeps to zero." **That
  is the signature of the exactly-zero heartwood columns**, so the mechanism predicts the observed
  shape and not merely the observed error.

**Consequence for the plan:** record-once-sweep-many is **not expressible through the present API**,
because the driver clears the tape on entry. The shared driver changes first.

**Three refinements from a dry run, and the first changes where the fix goes.**

- **A record-once-sweep-many primitive already exists in the same header.** `compute_jacobian`
  (`gradient.hpp`) wraps `xad::computeJacobian`, which registers inputs once and produces every
  codomain row from **one** recording. `census_state_adjoint` does not use it — it reinvents a
  weaker per-row loop around `vector_jacobian_product`. So the minimal change is either to route the
  census through the existing primitive, or to add a sibling that separates *record* from *sweep* so
  the sweep can run F times without a clear between. Both are additions to the shared driver rather
  than call-site edits in `plant`, but the first is much smaller than designing the economy from
  scratch.
- **The waste is quadratic in the metric count, not linear.** `reduce` computes **all** metric
  outputs on every call while only one seed is non-zero, and the driver is called once per metric.
  So the wasted forward work scales like $F^2$ metric evaluations. "F recordings" undercounts it.
- **The aliasing fix is not one line, and the two in-tree precedents show why.**
  `Patch::cohort_block_adjoint` builds a **passive** template once, while no tape is active so it
  holds no slots, and then constructs a **fresh active object from that template inside the innermost
  loop.** `Step::step_adjoint` keeps its rebound twin outside the loop and is safe only because it is
  never mutated — it serves purely as a source of passive parameters, and what it rebuilds per stage
  is the set of actual tape inputs. **`census_state_adjoint`'s copy matches neither:** it is built
  once, outside the loop, and then *mutated in place* through `set_ode_state` each iteration — the
  pattern both precedents exist to avoid. The fix is at minimum "reconstruct from a pristine,
  never-tape-touched copy per iteration", and **whether that is sufficient is unresolved**: it
  depends on `set_ode_state` overwriting every active-typed field the census subsequently reads,
  which has not been read. **And it is a separate change from the economy** — reconstructing per
  iteration fixes correctness while still paying one record per metric.

**One earlier attribution is superseded.** This was recorded as a stale-aux-slot hypothesis. The
mechanism above is read, and it predicts the zero columns. Treat the aliasing as established.

### Item 2: which four parameters, and the trace that settles it

**Read.** `Species::compute_competition_and_slope_adjoint` writes through a `node_size_adjoints*`
with no parameter member, so the reduction's parameter terms reach no accumulator. The four:

- **`k_I`** — **incompleteness, not a zero.** `net_mass_production_dt` contains
  `radiation_at = [&](S light) { return pars.k_I * std::max(light, S(0.0001)) * PPFD; }` inside the
  recorded step, with `pars.k_I` seated from the step's parameter segment. So the cohort-step term
  is non-zero and the accumulator receives it; only the field-build contribution is missing.
- **`eta`** — **no row at all**, because it is absent from `ad_parameters()`, excluded there because
  $u^{k}\log u$ is not a number at a base of zero. Closing item 2 gives it nothing until it is
  registered, which is separate work — and registering it makes the ground-knot defect of §4 live.
- **`a_l1`, `a_l2`** — **same shape as `k_I`.** `Patch::allometry_adjoint` (`patch.h:1735-1740`)
  folds `sizes[k].area_leaf` onto height through `darea_leaf_dheight()` alone, which is the chain
  $\partial A/\partial h$ and **not** the explicit $\partial A/\partial a_{l1}$,
  $\partial A/\partial a_{l2}$ at fixed height.

**This last was contested and is now settled.** One trace held that the allometric pair arrives
through the size-space adjoint and is therefore complete; the line-level trace above holds that it
does not. The census diagnosis settles it independently: `k_I` enters *only* through the field
build, and **the same loss applies to `eta` and to the `a_l1`/`a_l2` copy inside the field build.**
So the gap is four parameters wide. The check that would close the question beyond doubt is the
`a_l1` column against a central difference, and it has not been run.

**Both right-hand sides are already computed as intermediate products inside the existing
transpose.** What is missing is a summation, not a derivative.

### Item 10: the four discrepancies

**Read.** `Species::compute_competition_and_slope_adjoint` builds its trapezium widths from node
**heights**, unconditionally, and writes `out[upper].height += edge; out[k].height -= edge;`, while
the forward reduction integrates over `abscissa_of` — `introduction_time()` on the birth-date
branch. So:

1. the trapezium **widths** are built from heights on the birth-date branch;
2. the weight-derivative term is carried live where the forward function has no such dependence;
3. the closing boundary trapezium drops its `|| birth_date` condition;
4. the `!scan.decreasing` stop tests height ordering with no coordinate condition, so **it fires
   where the forward runs.**

`consumption_rate_adjoint` has the same defects.

**And one channel is transposed nowhere: `A0 → n_b → A`** — the boundary condition evaluated in the
boundary-excluded field.

**Status.** `node_density_in_birth_date` defaults to **`false`** (`control.cpp:34`), so these are
latent in production SCM and live only under the opt-in — **which is the coordinate this gradient is
scoped to.** They are pre-work for the gradient, not a defect in the forward model.

### Items also worth stating as read

- **`Species::consumption_rate` now sorts** when the abscissa order inverts; `consumption_rate_adjoint`
  still transposes the unsorted trapezium. The light transpose **refuses** (`species.h:997`), which
  is the right behaviour and the precedent worth generalising.
- **`SCM::census_state_adjoint` registers only $y$ as an input**, so the direct term has nowhere to
  land. `Patch::introduction_adjoint` is the pattern for fixing it: append `ad_parameters()` to the
  input vector (`patch.h:1626-1636`) and assign them back inside the recorded lambda **before** the
  state (`patch.h:1650-1655`, whose ordering comment applies verbatim — `area_leaf(height)` reads
  `lma`).
- **The last narrowed vector is discarded.** `census_trait_gradient` sweeps `[boundary[j], k_last]`
  and after `j == 0` assigns `lambda = narrowed;` and never reads it again (`scm.h:704-712`). That
  vector is $\bar y(0)$.
- **`Leaf::translation_partials` exists and is unreachable from the shipped model.** Signature:
  `void translation_partials(std::vector<double>& dE_dd, double& dpsistem_dd)`. It writes the
  per-layer uptake sensitivity and the stem-potential sensitivity **to a uniform drying of soil and
  collar together, computed directly rather than by differencing** — exactly what report 05 §7.3
  says the near-cancellation requires. It needs a `Leaf` that has already solved, since it refreshes
  the soil potentials and calls the per-layer flux partials internally.

  **It is not called by nothing — it is called from one place, and that place is not the model.**
  `plant/scratch/leaf_jac_gate.cpp` is a standalone `main()` compiled by hand against plant's
  sources: outside `src/`, no Rcpp export, in no test, unreachable from R.

  **And that harness performs the wrong version of the check.** It perturbs the soil potentials
  along the uniform-drying direction and compares against a central difference — but it compares the
  **joint** prediction $a\,\partial E/\partial u + b\,\partial(\partial E/\partial r)/\partial u$
  against a difference of the residual. **That is precisely the residual report 05 §7.3 proves cannot
  detect an error in $b$**, because a compensating pair fits every row. A prototype of the right
  fixture exists, wired to the one comparison that cannot falsify the claim.

  In the shipped path: $b$ = `dR_dflux_slope`, closed form as
  $-\texttt{dprofit\_dpsistem}\cdot P'/\kappa$; $a$ = `dR_dflux` via `dR_dflux_from_layer` at a
  two-sided difference of $10^{-6}$. **$b$ is never checked against anything along the drying
  direction.**

- **One cohort's block can be materialised without new production code.**
  `plant/scratch/wire_gates.cpp` exports `block_vjp(obj, species_index, node_index, out_adjoint)`,
  which builds the block as `Patch::cohort_block_adjoint` does and returns the full input-adjoint
  vector for a given output adjoint. Twelve calls with unit basis vectors assemble the
  $12 \times 130$ Jacobian by rows. It is `sourceCpp`-only — nothing exposes the block through
  `RcppR6_classes.yml` or the R surface. **Hazard: the output-adjoint vector must have length at
  least 12, or the call overruns and corrupts the heap.**

- **`Species::census` never branches on the coordinate.** It builds its grid from node **heights**,
  descending-reversed, with no sort check, whatever `node_density_in_birth_date` is set to — while
  `consumption_rate_by_node` does guard a non-monotone grid by sorting. **So departure 13 is
  coordinate-independent**, and it is live in the gradient's own scope rather than latent there.
  Both orders are observable from R (`heights` and `node_times` are active bindings), and the
  per-node census value is readable, so **a sorted-against-as-built comparison is an R-level probe
  and needs no C++ change.**

- **Relative reserve is not exposed anywhere.** It is a local inside `compute_rates`, and
  `storage_capacity`, `mass_sapwood` and `area_sapwood` are all unbound in `RcppR6_classes.yml` —
  `TF24_Strategy`'s R surface carries no methods at all. Absolute `storage` *is* readable as a
  state. So the distribution the reserve gate's width turns on costs either **re-deriving the
  capacity formula in R**, which is a reimplementation and not a read, or **a one-line auxiliary
  output in C++.** The second is preferable and it is a code change, however small.

- **`k_I \cdot \mathrm{LAI}$ is directly callable and needs nothing new.** Since the crown shape is
  1 at the ground, `Species::compute_competition(0)` sums density times $k_I$ times leaf area over
  every node — which *is* $k_I\,\mathrm{LAI}$ exactly. It is bound as a method.
- **`odelia::ode::supplied_derivative` is used nowhere in `plant`.** Report 05 §8 contrasts it with
  the live construction; it is a facility, not a mechanism in play. `HermiteInterpolator::graft` is
  the third instance and it is live, on the census's path through the light field.
- **`prepare_strategy` cannot be instantiated at an active scalar** (`tf24_strategy.h:1682-1694`
  `static_assert`). `rebind_from` (`:565-605`) copies the derived quantities at their `double`
  values, and `set_block_inputs` (`individual.h:207-224`) never calls `prepare_strategy` or
  `refresh_indices`. So every parameter-to-derived-quantity edge is a tape constant. `h_0` is
  `double` **by declaration** (`:611`, `:625`, and `height_seed()` returns `double` for every `S` at
  `:1616`); `eta_c` and `area_leaf_0` are `S` and passive only by *value*, so they are the tractable
  pair if item 9 is ever attacked.
- **There is no assembled forward tangent at the SCM level, but the machinery to build one exists
  and is load-bearing.** No `jacobian_vector_product` and no forward driver exists in `scm.h`;
  `forward_derivative` appears only inside `Leaf` as a local device. **What is missing is a driver,
  not infrastructure.** `odelia`'s `ode_jacobian.hpp` implements a real forward-mode facility:
  `Jacobian<System>` builds a twin system at `xad::fwd<value_type>::active_type` through
  `rebind_from`, seeds one state coordinate's tangent at a time, and reads the derivative back — and
  the Rosenbrock stepper uses it today for its exact Jacobian. The double-to-active lift is proven
  in production at `Patch::rebind_from` and at `SCM::census_state_adjoint`. So the tangent scalar
  and the lift are both live; what does not exist is a whole-run driver that seeds a tangent and
  carries it through `SCM::run()`.

- **A second term enters passively on every path, and it was not on report 05 §10.1's list.**
  `Node::compute_initial_conditions` assigns `birth_growth_rate = odelia::util::to_passive(g)` at
  **every** node birth, on both coordinates — a code-level severance rather than a comment. And
  `Species::height_jacobian()` returns `std::vector<double>`, so it is always passive, and it is
  consumed as a plain divisor when building the birth-date log density. **Whether that channel
  reaches any census row is unresolved**, and it needs the same algebraic check the waist needs: it
  may be provably inert because it enters only as a structural quadrature weight, or it may be a
  second imposed zero beside the seed height. Report 05 §10.1 names the seed height as *the*
  imposed-zero term. **It may not be the only one, and until this is settled that section's claim is
  narrower than it reads.**
- **The water channel from cohorts into the soil state carries no derivative.**
  `patch.h:1101-1104` is `resource_depletion.push_back(odelia::util::to_passive(resource_consumed /
  area));`, with an in-place comment that the environment's store is `Internals<double>`.
- **`dpsi_from_soil_moist_dtheta` is correct term for term** (`tf24_environment.h:609-619`): zero
  below the residual floor, zero above the potential cap, $-n_\psi\psi/\theta$ between, drawing
  $n_\psi$ from the same per-layer accessor as the forward. It is restored by hand in
  `Patch::cohort_block_adjoint` (`patch.h:1578-1582`). **`Patch::introduction_adjoint` does not
  multiply by it**, so a newcomer's dependence on soil moisture is identically zero.

---

## 3. The operating point: thirteen terminations, a fourteenth, and five kinds of point

Report 05 §7.0 gives five kinds of point. The code distinguishes thirteen terminations in
`collar_class`, plus one that is not in the enumeration at all. The mapping:

| kind | terminations |
|---|---|
| **S** interior stationary | `COLLAR_INTERIOR`, `COLLAR_EXHAUSTED` — the cap is the same object with a displaced linearisation point, error $\lvert R\rvert/\lvert\Pi_{pp}\rvert$, so carry the bar rather than a branch |
| **K** constrained | `COLLAR_BOUND_A`, `COLLAR_BOUND_B`, `COLLAR_BOUND_STEP` |
| **B** substituted feasible | `E4`, `E5` |
| **X** exogenous | `E1`, `E2`, `E3` — **one function of $u$ for every output carrying a rate**; all three route through `set_shutdown_state`, which writes the same `profit_` and the same zeroed uptake, differing only in `root_collar_psi_`, which reaches an aux slot. Plus TF24f |
| **N** no derivative | `COLLAR_BOUND_CURVATURE`, `COLLAR_R_NONFINITE` |

So five of the thirteen collapse.

**The fourteenth case is on the good path.** `dprofit_droot_collar_psi` returns a hard sentinel
`0.0` when `psi >= psi_stem` or `psi_stem` is non-finite (`:1081-1083`) — its own comment records
the state as reproduced at $\theta = 0.005$–$0.03$ under 1 m/yr rainfall. The polish's convergence
test is `!std::isfinite(R) || std::abs(R) <= R_tol` (`:930`), which cannot distinguish a sentinel
zero from stationarity, so it records **`COLLAR_INTERIOR`**. Class S as the code detects it
therefore contains a subclass where the leaf is in a no-flow or infeasible state, profit is not
stationary, and $\Pi_{pp} = 0$ by the same sentinel.

**In the shutdown case that is a division by an exact zero.** `E1` to `E5` all return `false` from
`prepare_collar_solve`, which **clears** `collar_pinned_` (`:740`), and `graft_leaf_outputs` runs
unconditionally at an active scalar with no test of how the solve terminated. So every X and B case
takes the **interior** branch. At `E1` the whole soil is drier than the critical potential, so both
evaluations inside `dR_dcollar_at(p, 1e-6)` return the sentinel, $\Pi_{pp} = 0$ exactly, and
$m = -s/0$ with $s$ generically non-zero. **A selector comparing $\lvert R\rvert$ cannot detect
this, because $R$ *is* zero there.**

**The pinned flag covers four classes and `bound_partials` attributes by proximity.**
`polish_root_collar_psi:984-987` sets `collar_pinned_` for `BOUND_A`, `BOUND_B`, `BOUND_STEP` and
`BOUND_CURVATURE`; the last two fire on a rejected Newton step or a non-negative curvature
(`:968-971`). `bound_partials` then uses
`const bool at_bound_a = (p - bound_a) < (bound_b - p);` (`:1401-1403`), so for those two classes
$\partial B/\partial u$ is the derivative of a bound the point is not on.

**TF24f never pins.** `tf24f_strategy.h:148,183-199` uses `prepare_collar_solve` and
`profit_at_collar_psi` and never calls `polish_root_collar_psi`, while `prepare_collar_solve:740`
clears the flag. Its operating point is a tracked ODE state clamped into `[bound_a, bound_b]`
(`:1032`). It inherits `net_mass_production_dt`, hence `graft_leaf_outputs` and `input_adjoints`, so
it takes the interior branch and divides by a differenced $\Pi_{pp}$ with no defining relation
there.

**Item 12's dead branch, read.** `bound_b = std::max(-root_crit, -root_psi_crit)`
(`leaf_model.cpp:807`). `root_crit` comes from `find_root_psi`, searching
`[-psi_crit, wettest_soil_layer]` — both non-positive — so `-root_crit` is **positive**. And
`root_psi_crit` is a positive magnitude, 5.8703 at defaults, so `-root_psi_crit` is negative and
**can never win the max.** The clamp the comment at `:656` describes never fires and the early
return at `:1406-1409` is unreachable. Consequences: `PAR_ROOT_PSI_CRIT` has **no derivative row
anywhere** — `:1407` is its only write site and `reaches_operating_point` excludes it (`:1729`) —
and the golden-section search probes collar magnitudes to $\psi_{\text{crit}} = 7.0855$, past the
root integral's last knot at 6.8918.

**No finiteness test anywhere in `input_adjoints`.** `layer_flux_partials` assigns NaN to every
entry up front and fills in ascending order, so layers **before** the offender hold real values and
layers from the offender onward are NaN. The NaN enters the sums, reaches the argmax multiplier, and
`graft` writes it onto the tape.

**A derived, guaranteed NaN.** `layer_flux_partials` refuses when
$\lvert(\psi_i - p) - g_{z,i}\rvert < 10^{-8}$ — per-layer zero flux — and `bound_a` is the collar
potential of zero **total** uptake. For a plant rooted in one layer these are the same quantity, so
the condition holds identically. `max_soil_layer` is the deepest layer carrying root mass and layer
thickness is $1.5/5 = 0.30$ m, so any plant under 0.30 m is single-layer. **Whether recruits fall
below 0.30 m is unmeasured and is the cheapest open check on this list.**

**One refuted sub-claim, recorded because the reasoning is instructive.** It was held that a
non-finite moisture is laundered into a physical state, because `std::min(NaN, 1000)` returns 1000.
It does not: `std::min(a,b)` is `b < a ? b : a`, and `1000 < NaN` is false, so **NaN propagates**.
The forward returns NaN and `set_physiology`'s finiteness check catches it. The laundering hazard is
real in shape and absent here.

---

## 4. The light field

**Read.** Three shading modes in `TF24_Strategy::net_mass_production_dt`; the default is
`ShadingModel::MeanLight`. `DeepCrown` is guarded by `if constexpr (std::is_same_v<S, double>)` with
a `util::stop` in its `else`, so **it raises on the active path** — which confirms report 02's
constraint C6 from the code.

- `CrownCentre`: `optimise_at(radiation_at(environment.get_environment_at_height(height * eta_c)))`
  — one query. The interpolant is `odelia::hermite_interpolator`, cubic per span with local support,
  so an interior query loads `y[i], y[i+1], m[i], m[i+1]` — **four** non-zeros. Two in the linear
  end-extension; zero above `spline.max()`, where the query returns 1.0.
- `MeanLight`: `optimise_at(radiation_at(function_integrator.integrate(f, S(0.0), height)))` with
  `f` calling `compute_average_light_environment` — which queries the field, not a surrogate.
  `quadrature::QK(control.function_integration_rule)`, defaulting to **21** points.

**`graft_leaf_outputs`** supplies a row over `2*max_soil_layer + 3 + n_leaf_parameter_inputs` = 28
inputs at five rooted layers, with 15 leaf parameters, and pushes the parameter tail explicitly.
**`max_soil_layer` is not the layer count** but the number of layers carrying non-zero root mass,
recomputed per call (`leaf_model.cpp:278-281`), so the row length varies within a run and `graft`'s
length check is what refuses a mismatch.

**Report 03 §1's central claim is discharged and the plan should stop carrying it as owed.** Its
premise is that the field's slope is the one quantity `plant` cannot supply for a crown integral
whose domain moves. It is supplied structurally: `QK::integrate` takes its bounds as the **active**
scalar and forms `center` and `half_length` on it (`qk.h:70-72`), so every abscissa carries the
affine map on the tape; and `hermite_interpolator`'s read at an active position returns
`graft(value_at(up), slope_at(up), u, up)` (`hermite_interpolator.hpp:113`, `:165`). The Leibniz
boundary term is absorbed because the rule is *mapped* rather than truncated, and abscissae are
strictly interior, so the crown integral touches neither the ground singularity nor the cap.
**Nothing on the physiology path needs to call `slope()`.**

**Report 03 §1b's normalised coordinate does not exist in the code.** `rebuild_spline` lays knots at
`knot_fractions_[k] * to_passive(height_max)` and `get_value_at_height` queries at **absolute**
height, so neither $1/H_{\max}$ nor $-z/H_{\max}^2$ appears anywhere in the query path. Since
$u_k = k/64$ is exact, `x.back()` equals `height_max` bitwise and the rebuild guard is false only
while `height_max` is bit-unchanged — so **the grid is relaid essentially every stage** and the
position channel is re-formed and re-dropped every stage. The correct statement is that the field is
held on an **absolute** grid whose positions are an affine, passive function of an active
`height_max`.

**Twelve of twenty-four regimes are $C^1$ joins, and four of them the reports treat as hazards that
are not:** the crown-top cutoff, a species' above-canopy exit, the cap (where $A(H_{\max}) = 0$
exactly) and the boundary-interval switch. Value *and* slope vanish exactly at each, so dropping the
branch indicator's derivative is **exact**.

**Both clamps sit on one lever.** $\tilde Q(0) = 1$ for every $\eta$, so the field's minimum is at
the ground knot and equals $\exp(-k_I\,\mathrm{LAI})$. The $10^{-4}$ floor binds when
$k_I\,\mathrm{LAI} \ge \ln 10^4 = 9.2103$.

**Measured, and the hazard is real: the floor is reached between $k_I = 3.0$ and $k_I = 3.5$**, six
to seven times the baseline of 0.5. Configuration `scripts/measure/kI-lai-invariance.R`, lifetime
30, `lma = 0.0825`, `add_strategies` route, against the certified pairing:

> **Caveat on this configuration, added after the fact.** It sets `lma` and leaves `hmat` at its
> default, which produces about **3 offspring** where the reference configuration produces 445. The
> leaf-area index it reports is plausible, but the stand is far sparser than the reference. **The
> sweep should be re-taken at `hmat = 5`** before the crossing point is quoted as a property of the
> model rather than of this fixture. The qualitative finding — that the product rises close to
> proportionally with $k_I$ and does reach the floor — is unlikely to reverse, because it is driven
> by the arithmetic of the exponential and not by stand density.

| $k_I$ | $k_I\,\mathrm{LAI}$ | implied LAI | |
|---|---|---|---|
| 0.5 | 1.8498 | 3.6995 | |
| 1.0 | 3.8386 | 3.8386 | |
| 2.0 | 7.1862 | 3.5931 | |
| 3.0 | 8.8580 | 2.9527 | |
| 3.5 | 11.3054 | 3.2301 | **floor binds** |
| 6.0 | 17.4539 | 2.9090 | **floor binds** |

**The earlier fixed-LAI estimate of $k_I \ge 2.562$ is optimistic and is superseded.** It held
$\mathrm{LAI} = 3.595$ fixed while varying $k_I$. Self-shading does suppress equilibrium leaf area as
extinction rises — from about 3.8 to about 2.9 — so the true threshold is **higher** than the
fixed-LAI arithmetic predicts, by roughly a fifth to a third. The suppression is real but nowhere near
enough to cancel: $k_I\,\mathrm{LAI}$ rises close to proportionally with $k_I$.

**So an ascent or calibration run walking $k_I$ upward does reach the severed region**, and it needs
an excursion of six- to sevenfold rather than fivefold. A dry run reading a single arm concluded the
opposite — that self-shading cancels and the floor is unreachable — from one measurement compared
against a *computed* baseline rather than a measured one. **And the first version of this probe could
not have failed:** `k_I` lives at `pars$k_I`, and assigning `strategy$k_I` silently creates an R list
element the C++ side never reads, so every arm returned the same number to four decimals with
identical step counts. That reads as "self-shading exactly cancels" and means "nothing was varied."
The script now asserts the parameter took and refuses to report an all-arms-identical result. The monotonicity guard is
on the same lever: at the ground knot $m_0 = -L\,A'(0) = 0$ exactly for $\eta > 1$, so the first
span undershoots when $m_1 h > 3(y_1 - y_0)$ — live precisely where a recruit bunch sits inside the
first span, whose width is $H_{\max}/64 \approx 0.28$ m at production. It cannot reach below zero
while $y_0 = 0.166$; it can once $y_0 \sim 10^{-4}$. **`k_I` is registered and free.** $\eta$ is
**not** a lever: it reshapes the profile and leaves $A(0)$ untouched.

**One clamp is dead code.** $\int_0^H q\,dz = Q(0) - Q(H) = 1$, so the crown mean of already-floored
values is at least $10^{-4}$ identically: the outer `max(light, 1e-4)` in `radiation_at` **can never
bind under `MeanLight`.** It binds only where the argument is a single point query.

**A third canopy model reaches the wrong pair.** `PPA` routes to `leaf_above_deep`, so `Q_and_q`
returns the smooth Yokozawa pair while FF16's environment builds a **stepped** profile — the slope
of a field the model does not use. And `Q_and_q_dheight` **throws** for `FlatTopSoftBox`, whose
forward field builds happily, so that model's transpose cannot run although $\partial q/\partial H$
is one line.

**The ground knot at $\eta \le 1$ is a value defect in plain `double`.**
$q(z \to 0) = 2\eta z^{\eta-1}/H^{\eta}$ has limit $0$ for $\eta > 1$, $2/H$ at $\eta = 1$, and
$+\infty$ below. The code implements the first two by an exact comparison and returns $0$ for the
third. $\partial/\partial\eta$ of the ground-knot slope does not exist at $\eta = 1$, where the
guard hard-codes zero. **Latent only because $\eta$ is absent from `ad_parameters()`.**

---

## 5. The soil

### The moisture axis, which every incidence claim about the soil is a claim about

Defaults `a_psi = 1.78e3` Pa, `n_psi = 6.57`, `theta_sat = 0.428`, `K_sat = 163.0411`.
$\psi(\theta) = a(\theta/\theta_{\text{sat}})^{-n}/10^6$ MPa;
$K = K_{\text{sat}}(\theta/\theta_{\text{sat}})^{2n+3}$, exponent 16.14.

| $\theta$ | $\theta/\theta_{\text{sat}}$ | $\psi$ (MPa) | what |
|---|---|---|---|
| 0.428 | 1.000 | 0.00178 | saturation; infiltration bracket exactly 0 at `a_infil = 1` |
| 0.392 | 0.917 | 0.0045 | runoff halves infiltration |
| 0.309 | 0.723 | 0.015 | **default driver minimum $\psi$** |
| 0.214 | 0.500 | 0.169 | **default driver maximum $\psi$ — and the initial state** |
| 0.1535 | 0.359 | 1.5 | report 00's bound-pinned threshold |
| 0.1336 | 0.312 | 3.74 | deepest drydown ever measured |
| 0.1215 | 0.283 | 6.895 | **root vulnerability grid ends** |
| 0.1212 | 0.283 | 7.085 | stem critical potential — shutdown if the **wettest** layer is here |
| 0.1178 | 0.275 | 7.45 | the linear extrapolant crosses zero |
| 0.0571 | 0.133 | 1000 | `soil_psi_max_` cap binds |
| 0.0100 | 0.023 | 9.31e7 | residual floor — always capped first, so **invisible** |

$K$ at $\theta = 0.214$ is $2.26\times10^{-3}$ m/yr against rainfall of order 1 m/yr, so **the
drainage cascade is a thousandth of the forcing.** At $\theta = 0.1215$ it is $2.4\times10^{-7}$;
at the floor, $7.6\times10^{-25}$.

**So "incidence zero for the soil clamps" is the statement that the soil never moved.** The driver's
entire range is $\theta$ within about $\pm 25$ percent of its initial value, and the initial state
*is* the maximum potential.

### The cap is a runaway, and five comments are wrong about it

**Read.** `set_extrapolate(true)` disables the *error*, not the extrapolation. `odelia basic_spline`
uses natural boundary conditions (`m_b[0] = m_b[n-1] = 0`, `spline.hpp:281-287`), so right
extrapolation is `((m_b[n-1])h + m_c[n-1])h + y` — **exactly linear**, with slope $f'(x_{\text{end}})$
and `m_c[n-1]` set to the slope at the last knot (`spline.hpp:321`, `:407`).

- `root_vuln_from_psi` extrapolates linearly **negative** past 7.45 MPa. The comment at `:446-449`
  is correct about this.
- `root_vuln_integral_from_psi` extrapolates with slope $f_r(6.895) = 0.01 > 0$, so **the integral
  keeps growing past its grid rather than clamping to its last value.** Therefore
  $r_R^H = r_R^{H,\min}\cdot\text{span}/\text{integral}$ **saturates** at $100\,r_R^{H,\min}$ — mean
  root conductance never falls below 1 percent however dry the layer. Then
  $E_i = (\psi_i - p - g_z)/(\text{area}\cdot r_R)$ has a numerator growing linearly in
  $\lvert\psi_i\rvert$ over a bounded denominator: $E_i$ grows **linearly and negative**.

So a capped layer is a **plant-to-soil sink of order the cap's own magnitude**, not "uptake ~0".
Comments `:497-501`, `:1973`, `:2013`, `:1194` and `:452-456` are all wrong about this.

**Every net is the wrong net.** The flux is finite, so the post-loop `isfinite(E_up_)` check
passes. $E^{\mathrm{up}}$ is a sum over layers, so a positive total hides it. A negative depletion
makes the layer's rate positive, so the positivity guard permits it. Raising `soil_psi_max_` makes
it worse linearly.

**Magnitude unestablished.** Whether the saturated $r_R^H$ dominates the vertical term decides
whether the wrong-way flux is ten times a healthy layer's uptake or a tenth of it. **The measurement
that settles it is $\min_i$ `soil_consumption_` and $\max_i$ `psi_soil` over a real rainfall
series**, and $E^{\mathrm{up}}$'s sign cannot substitute for it.

**Per-layer $E_i < 0$ was filed unreached on the evidence that $E^{\mathrm{up}} < 0$ never occurs.
$E^{\mathrm{up}}$ is the sum.** A layered root system's normal state is per-layer negatives inside a
positive total, so the statistic cannot see the phenomenon. $\min_i E_i$ was never measured.

**No soil parameter has a derivative row.** `K_sat`, `a_psi`, `n_psi`, `soil_moist_sat`,
`soil_moist_residual`, `soil_psi_max_`, `a_infil`, `b_infil` are plain `double` members of
`TF24_Environment` (`:298-320`), absent from both `TF24_Pars::field_ptrs()` and `ad_parameters()`.
**The `static_assert` at `tf24_strategy.h:147-149` cannot catch this**, because they are not strategy
members. With per-layer vectors that is $4n$ unaskable parameters. `root_depth_shape_eta` has no row
either, and `rooting_depth_max` has one that is exactly zero for every plant under 1.5 m — and **no
consistency guard against the soil column's depth**, so pushing it past the depth makes distributed
root mass silently vanish.

---

## 6. The cohort, the census boundary, and the R surface

**The reserve deficit freezes.** `storage` is the already-clamped
`std::max(vars.state(...), S(0.0))` (`tf24_strategy.h:958`) and `floor_gate` is built from that same
value (`:1014`), so $S<0$ gives `floor_gate` $= 0/(0+\texttt{gate\_ref}) = 0$ exactly and `dS/dt`
$= 0$ on the deficit arm. **Report 00 §9b's mechanism — that the deficit drains at full rate — is
wrong.** Its conclusion that the consequence is bounded survives.

**The reserve gate's own numbers.** $G(0) = 1/(1+e^{(0-0.1)/-0.1}) = \mathbf{0.2689}$, so a plant
with empty reserves grows at 27 percent of its production rate; the comment beside it says the gate
is "~0 at low relative reserves". `storage_gate_width = 0.1` centred at $a_{st2} = 0.1$ on
$r \in [0,1]$ occupies **40 percent of the domain**, with $\mathrm{d}G/\mathrm{d}r \approx 2$ through
the band, 0.18 at $r = 0.5$ and $1.2\times10^{-3}$ at $r = 1$. **It was never measured against the
spread of $r$, and the distribution of $r$ appears nowhere in the corpus.** By contrast
`storage_prod_eps = 1e-4` *was* sized against the spread of $|P|$ and its derivative is bounded.

**Establishment needs no smoothing.** `establishment_probability` returns
$P^2/(P^2+k^2)\cdot\text{decay}$ above threshold and $0$ below, with
$k = a_{d0}a_0 = 1.209\times10^{-5}$. Both value and first derivative tend to zero as $P \to 0^+$,
so it is $C^1$ and the `else 0` arm is its correct extension. The biology's transition scale is
**8.3 times narrower** than `storage_prod_eps`, so the proposed mollification would widen a
transition the model already resolves. **Report 00 §10 item 4 closes with no forward change.** The
derivative peaks at $0.65/k \approx 5.4\times10^{4}$ at $P = k/\sqrt3$.

**`g > 0 ? log(·) : log(0)` is dead code**, since $P_{\text{pos}} \ge \varepsilon/2$ and
$G \ge 0.269$ make height growth strictly positive always — which also closes one of report 04's
three routes to a zero-width transport interval. And **the `size() < 2` water switch no longer
exists** in the form report 00 §10 item 3 lists: `consumption_rate` guards `size() == 0` and always
includes the boundary node, reducing that item to the light floor alone.

**Eight trait rows are exactly zero through birth size and nothing declares it** — `omega`, `lma`,
`a_l1`, `a_l2`, `rho`, `theta`, `a_r1`, `a_b1` — on every metric, through both `pr_estab`, which
reads `area_leaf_0` explicitly, and $\ell(\text{birth})$. **Report 00 §7 files $h_0$ under *Solved*,
"a trait reaches birth size through it". No trait reaches birth size today.**

**`Patch::introduction_adjoint` records `set_ode_state_and_field` followed by
`introduce_new_node()`** (`patch.h:1657-1660`), so newcomer rows are a function of the
pre-introduction state. Its input vector is `state_before` **plus** the traits (`:1631-1640`) and
both halves are used: `lambda_before[j] += in_adjoint[j]` (`:1681`) and
`trait_adjoint[p] += in_adjoint[...]` (`:1684`). The narrowing is **interleaved**: newcomers sit at
the end of each species' node block, so every later species and the environment shift by one node
stride (`:1610-1611`).

**The widening replay is required and was omitted from report 05 until this rewrite.**
`SCM::widen_over_introductions` (`scm.h:723-742`), called at `:702` per metric and again at `:717`
to leave the system repeatable, plus boundary discovery at `:673-688`.

**An empty segment list returns exact zeros for every metric and nothing is thrown.** The loop is
`for (j = boundary.size(); j-- > 0;)`, so with no width change it never runs, `solve_adjoint` is
never called, and `ret.push_back(live.trait_adjoint)` returns the freshly cleared accumulator. The
only guard is on `states.size() < 2`. **At the R boundary that is indistinguishable from a genuinely
insensitive stand.**

**Four more solver-adjoint states, read.** A mutant run is **silently biased rather than refused**:
`compute_environment` returns early on `is_mutant_run`, so no boundary node and no field build, and
`light_knot_adjoint` returns immediately — the rows are finite and the light channel is simply
missing. Two introductions with no accepted step between them are **recorded as one**, because both
carry the same environment time. The same species introduced twice at one time is a **hard stop** on
a length check. And a fixed-step Euler run is **refused with the wrong message**: `step_euler` never
calls `record_ode_step`, so the step-size list grows while the trajectory does not, and the refusal
names neither Euler nor recording.

**A two-species stand silently returns species 1's columns twice.** `census_trait_names_tf24`
concatenates each species' `ad_parameter_names()` with **no species prefix**, so a two-species run
yields 88 columns with all 44 names duplicated. Character indexing of a matrix with duplicated
`dimnames` resolves each name to its **first** match, so `gradient[metrics, traits]` returns species
1's column for every named trait and the unknown-trait validation cannot see it. **Every gate in the
tree adds exactly one strategy**, which is why nothing catches it.

**A zero and an absence are handled differently, and only one correctly.** An unknown trait is
refused by name. A registered trait reaching nothing comes back as a number: three rows return at
$10^{-18}$ to $10^{-22}$ — round-off, which the reference itself labels "no response" — and the R
surface reports them as gradient entries.

---

## 7. The measurement register

Every figure the reports rely on, with its configuration. **A measurement without a configuration is
not a measurement.**

### Load-bearing: cited by reports 05–07 and carrying an argument

| what it establishes | figure | configuration |
|---|---|---|
| the two coordinates are different functions | `d(leaf_area)/d(lma)` differs by a quarter; `d(mass_above_ground)/d(lma)` **changes sign** | birth-date against height, same stand |
| ~~the mean-light bias, and its demographic amplification~~ **— superseded below** | lifetime offspring 8.276245764 against 2.483491938 for `deep-crown` — 3.33x | `max_patch_lifetime = 20`, one trait, one species. **Not production**, and the ratio does not carry to the reference configuration |
| the mean-light bias at the reference configuration | offspring **445.37** mean-light, **369.31** deep-crown, **537.95** crown-centre — **ratio 1.206**, crown-centre over deep-crown 1.457 | `lma = 0.0825`, `hmat = 5`, lifetime 20, birth rate 20, 5 layers; 11 s, 143 s, 8 s |
| the **per-plant** carbon bias, which this register said was unmeasured | profit ratio, mean-light over deep-crown, against focal height in a 20 m canopy at 6 m2/m2: **1.0000** from 0.5 to 12 m, 1.0020 at 16 m, 1.0376 at 18 m, **1.2829 at 20 m**, 1.2745 at 21 m, 1.0347 at 25 m, 1.0038 at 30 m | leaf submodel aggregated over a crown as the production path does, k_I*LAI = 3 |
| which plants the averaging misrepresents | at $\eta = 12$, $\tilde Q(u) = (1-u^{12})^2$: **86.7 percent** of crown leaf area in the top 20 percent of height, **99.95 percent** above $0.5H$ | arithmetic from the shape function |
| the transport closed forms are sound | agree with an independent high-precision integral and with central differences of it to better than **1e-23** | $c \in [0.4, 12]$, $m/b \in [0.075, 8]$ — the best-established derivation in the corpus |
| the waist is ill-conditioned in the direction the ecology cares about | second singular value **1.3e-5** of the first; drying response amplified **15 to 26×**; $b$ validated only to 1.04 percent and 0.16 percent against a noisy joint fit | report 02 §6.3, five states |
| `k_I` is live and short | **3.041 percent** low, direction known (negative missing channel, so the row is too large) | the reference csv |
| birth size is imposed to zero | about **3 percent** for `lma` | — |
| no reference can referee it | a relative step of **2e-7** in `lma` moves a mature stand between alive and identically zero | production |
| the record-once economy's precondition is violated | see the nine-row table below | |
| ~~the light row is under half full, bounded by the rule~~ **— demoted, see below** | maximum 78 of 130 columns, mean 58.7 (45.1 percent); structurally-zero fraction 55 percent | default `MeanLight`, **height coordinate only**, `function_integration_rule = 21`, field evaluated twice per step |
| the dominant's height adjoint is short | by about **87 percent** of that adjoint | knot positions passive. **Whether it shrinks with knot density has never been checked** |
| a registered trait reaching nothing returns a number | three rows at **1e-18 to 1e-22** | the reference labels them "no response" |

### The census seed table — item 1's evidence

**Measured** on `lib-wave5`, TF24 `lma = 0.0825`, `max_patch_lifetime = 2`, 81 nodes. Seed =
`stand_census_state_adjoint`; reference = central finite difference of the R reduction.

| row | column family | seed | reference | verdict |
|---|---|---|---|---|
| `leaf_area` | height | 1.30938 | 1.30935 | OK, 2.0e-5 |
| `leaf_area` | log density | 1.96365 | 1.96361 | OK, 2.0e-5 |
| `leaf_area` | heartwood | 0 | 0 | OK |
| `mass_above_ground` | height | −0.00772733 | 1.23956 | **wrong** |
| `mass_above_ground` | heartwood mass | 0 exactly | 4.27433 | **wrong** |
| `mass_above_ground` | log density | 1.29198 | 1.60910 | **wrong** |
| `area_stem` | height | 0.0172196 | 0.000328112 | **wrong** |
| `area_stem` | heartwood area | 0 exactly | 4.27433 | **wrong** |
| `area_stem` | log density | 0.149298 | 0.000527624 | **wrong** |

Census **values** agree with R to 1e-12 (1.963643 / 1.609104 / 0.0005276328), so the forward
reduction is sound and only rows 2 and 3 of the derivative are broken. Rows 2 and 3 are
**uncorrelated** with row 1 (correlation 0.04 to 0.17), so this is garbage rather than a scale
error. Environment columns are exactly 0 in all rows.

**And the missing direct term explains none of it.** $\partial(\text{mass\_above\_ground})/\partial
\text{lma}$ at fixed state is $\sum w n A_l$ — the `leaf_area` census value, $+1.9636$. Adding it
makes the adjoint 1.96 **more** negative, not $+1.12$. It is exactly 0 for `leaf_area` and for
`area_stem`.

**The 33 of 52.** *"33 of the 52 columns nonzero in row 1 are exactly zero in row 2"* — Task 6 dry
run, worktree at `d3392ea3`, `scripts/stand-gradient-smoke.R` at lifetime 2. **This figure was
withdrawn as fabricated and the withdrawal was wrong**: it was measured, and the search that
withdrew it covered `docs/` and `logpile/` but not the dry-run notes. It is the signature
`Step::step_adjoint`'s own comment predicts.

### The tangent reference table

`plant/scripts/tangent-reference.csv` on branch `p3/tangent-referee` at `6b0a49fb`, header recording
plant `1a06e4c5`, `max_patch_lifetime 2`, eight `node_schedule_times`, `ode_size 73`, 110 accepted
steps, `Control` defaults with no non-default fields.

| metric | tangent | adjoint | central difference (1e-5) |
|---|---|---|---|
| `leaf_area` | −6.70320364069075 | −6.7018609913628 | −6.89018062193 |
| `mass_above_ground` | −5.00502106067521 | **+1.1236103034985** | −5.18146726765 |
| `area_stem` | −0.00178853862026 | **−0.117481756163** | −0.00183969234031 |

`-0.117482 / -0.0017885` is **65.68**, so "65 times" is right and "180 times" was wrong.

**Every number here is on the height coordinate**, which the gradient no longer supports, so they
are **not gradient references any more.** And `1a06e4c5` is not an ancestor of `d3392ea3` — they
differ by `7b5012c2`, the forward-model correctness merge, which touches the census, the field build
and the leaf. **Do not compare across it.** The `-14906.6` re-reading is a different model, not a
failed reproduction.

### Task evidence — expires when its task lands

| figure | what it motivates | configuration |
|---|---|---|
| **A**: 2.0007 rebuilds per recorded cohort | the tabulation and caching tasks | plant `dad51118`, odelia `3bb2e46`, TF24, one species, birth-date coordinate. **Re-take after the tabulation task** |
| **B**: 0.262 GiB at one species; `max_patch_lifetime = 105.32` | the memory ceiling; the ceiling sits between one species and two | production. The two-species figures are **arithmetic from the code's sizes, not measured** |
| **C**: one leaf call with a general seed against six with unit seeds | the seed-matrix economy | — |
| **D**: 0.68 µs, a reused tape | the tabulation's cost | — |
| **E** | **retired — does not reproduce.** The grid is captured before any perturbation and held | — |
| **F**: 6.68× | masking the parameter rows. The cost is not in the sweep | `p3/trait-mask` |
| **G**: four figures | guarding the tabulation | `1a06e4c5` |
| 22 of 30 evaluations of `dprofit_droot_collar_psi` | replacing the differenced $\Pi_{pu}$ | interior path; 11 parameters passing `reaches_operating_point`, two sides each, against 2 in `dR_dcollar_at`, 2 in `dR_dflux_from_layer`, 2 for radiation, 2 for conductance. **30 is a maximum, not an invariant** — a parameter at exactly zero is skipped (`:1798-1800`) |
| waist residual 8.3e-9 to 2.6e-8 | the rank-two factorisation | report 02 §6.3. An earlier 2.6e-04 was the fitting procedure's own noise |
| benign $\lvert m\rvert$ = 5.8× | the amplification ceiling the fold guard needs | report 00 §7 |
| held grid reproduces the closed form to 5.1e-9; held against moving differs by at most 8 percent | that the knot-count defect does not exist | **not** the 47/131/10245× figures, which were a justification comment and never a measurement |
| knot gap 1.891e+01 | the grid is relaid every stage | report 03 |
| $\Pi_{pp} < 0$ at 52 of 52 states | nothing — **the sample is conditioned on the conclusion**, since a solved optimum satisfies the second-order condition by construction | differenced about the solved operating point |

### Incidence figures — properties of one driver, not of the model

| figure | what it counts |
|---|---|
| 13.96 percent $S \le 0$; 14.04 percent $P \le 0$ | the frozen cohort. **These are the same set by algebra, on any driver** — the difference is a measure-zero transient |
| 23.1 percent | boundary evaluations on the closed establishment arm |
| 80.9 percent of production solves | the iteration cap, **before the cap was raised** — exiting at $\lvert R\rvert$ up to 1.0e-06 where the envelope row is budgeted against 1e-13. The most common non-clean exit, and its error budget has never been set |
| 110 984 | `bound_b` pins, first appearing at the same rainfall arm as `E2` |
| 1.381 → 0.716 | the minimum bracket, falling monotonically with rainfall |

### What no measurement covers at all

- **No plant in this corpus has ever been run in shade.** Ground-level transmittance median 0.9997 —
  an open woodland.
- **The drought claim is REFUTED, and the refutation is measured.** This register said soil potential
  is never drier than 0.170 MPa, which *is* the initial condition — correctly identified, and the
  claim built on it is false. **The model dries well past it under its own dynamics.** At the
  reference configuration — `lma = 0.0825`, `hmat = 5`, birth rate 20, lifetime 20, this pairing —
  the mature stand settles at:

  | layer | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | $\theta$ | 0.1545 | 0.1429 | 0.1429 | 0.1429 | 0.1429 |
  | $\psi$ (MPa) | 1.4355 | 2.4060 | 2.4065 | 2.4055 | 2.4062 |

  Reported independently as reaching 2.46 MPa and settling at 1.38 to 2.37, with 4.54 MPa at half
  rainfall and 5.21 MPa at a twentieth. **Reproduced here to 0.04 percent on offspring** — 445.57
  against 445.37 — so it is the same configuration on the same tree.

  **The consequence outruns the correction.** The leaf's optimum stops being interior at about
  1.34 MPa, so **the mature stand's own equilibrium sits past the transition this corpus treated as
  unvisited.** The five kinds of operating point are not segments of a drydown the driver never
  performs. The driver performs it.

  **Two failed refutations of this were mine, and both failed the same way.** I measured the soil at
  birth rate 1 and at birth rate 20, read 0.029 to 0.034 MPa — wetter than the initial state — and
  nearly recorded the finding as not reproducing. Both runs left `hmat` at its default and produced
  **2.98 offspring against 445**. An almost-empty stand does not transpire, so the probe could not
  have dried the soil whatever the model does. **Offspring production is the tell: check it before
  trusting any soil reading.**
- So **an incidence figure is a property of the driver it was taken on** — but "the axis never moved"
  is now specific to **light**, and is no longer true of water. The five operating-point
  cases are consecutive segments of a drydown the driver never performs.

### Open checks, cheapest first

1. **Do recruits fall below 0.30 m?** Settles whether §3's derived NaN is reachable. One run.
2. **`COLLAR_BOUND_CURVATURE`'s incidence.** It has a census slot and fires on nothing else. **The
   single number the whole curvature question turns on.**
3. **$\min_i$ `soil_consumption_` and $\max_i$ `psi_soil` over a real rainfall series.** Settles §5's
   magnitude and $\min_i E_i$ together.
4. **The `a_l1` column against a central difference.** Closes item 2's contested trace beyond doubt.
5. **The sentinel guard's firing count.** §3's fourteenth case has no counter.
6. **A curvature sweep across the whole feasible interval at dry states**, not about solved points.
7. **The distribution of relative reserve $r$ across a stand.** The one number the reserve gate's
   width turns on.
8. **Per-plant carbon bias under `deep-crown`, forward, at a handful of states.** Affordable, and it
   separates the 3.33 from the quantity it is quoted as.

### Demoted to unverified

**The 78-of-130 column census cites no script, and its structural twin is already retired for exactly
that.** A search of `plant/scripts/` and `plant/scratch/` finds nothing that computes a column
census — `wire-gates.R` mentions non-zero adjoints in a comment and computes no such thing. The
retired "36 of 44 non-zero direct columns" below failed the same way, in the same corpus, and this
figure sat in the load-bearing table while its sibling sat in the retired list.

**So do not cite 78 of 130.** The *structural* bound stands on its own — a fixed $n$-point rule
touches at most $n$ spans of an interpolant with local support, and `function_integration_rule`
defaults to 21, which is a read — so "the row's width is bounded by the rule and not by the canopy"
survives as an argument. The measured occupancy does not, and it was on the wrong coordinate anyway.
Re-take it with a committed script, on the birth-date coordinate, per METHOD §9.4 row 7.

### Retired

- **Measurement E** — does not reproduce.
- **"36 of 44 non-zero direct columns"** — corresponds to no measurement anywhere, including the
  dry-run notes. If wanted, it must be taken: count the non-zero direct columns in a run and cite
  the log.
- **"a magnitude wrong by 180 times"** — it is 65.68.
- **47, 131 and 10 245 times** — a justification comment, not a measurement.
- **`TF24_Environment::compute_rates_adjoint`** — report 05 prescribed reading it. **It does not
  exist.**
