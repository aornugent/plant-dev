# The TF24 leaf as a single differentiable node

> **Read `00-tf24-dependency-map.md` §6 alongside this.** On the production path the
> collar operating point is a stationary interior maximum (`|∂Π/∂p| ~ 1e-5 … 1e-7` at tight
> tolerance) and the envelope theorem holds to 0.006–0.9% on `d(profit)/dψ`, so this
> report's premise is the right one. What replaces its **Newton polish** is not a
> correction to the geometry but a cheaper construction: report 00 §6.2 collapses the five
> flux adjoints onto one scalar, divides once by `Π_pp`, and takes one gradient of
> `∂Π/∂p` — no root-find at all. The polish figure quoted below (4.541e-10) is a toy
> measurement and is not a production number.
>
> **The branch census below undercounts, and that stands.** It enumerates five early exits
> from `prepare_collar_solve` plus an uncounted sixth case pinned at `bound_b`. The
> zero-flux `psi_upstream >= psi_stem` branch is none of those — it is a jump *inside* the
> objective evaluation, which exit instrumentation cannot see. Its incidence is zero on a
> production run and the jump across it is exactly `R_d`. `../tf24-correctness.md` P0.5 is
> the full manifest.
>
> **`Π_pp` is measured** (`scripts/curvature_probe.R`): negative at 52 of 52 states over
> the argmax's whole feasible domain, `|Π_pp|` from 0.1723 to 15.61, so the single divide
> in §6.2 amplifies a flux adjoint by at most 5.8×. The same sweep finds 15 of those 52
> states with the operating point **pinned at a bound** — every one at `psi_soil ≥ 1.5 MPa`
> and `height ≥ 2 m`, outside the default driver's range but inside the stress banks'. The
> leaf node is therefore two branches and a selector on `|∂Π/∂p|`, and this report's
> section 1 already has the right shape for the bound branch: pinned means `p*` *is* the
> bound, so its derivative is the bound's derivative, analytic and exact.
>
> **Four sub-claims falsified by building the node (Phase 3, wave 2). The conclusions stand; these
> four do not.** Evidence in `../archive/implementation-notes.md`, *Phase 3, wave 2*.
>
> **§6.8's input table is incomplete.** Five inputs are missing: `root_b`, `root_c`,
> `root_psi_crit`, `beta_R_H` and `beta_R_V`. The last two are the only multiplicative scale on the
> root resistance network, so under the declared table a strategy varying either would have got
> **exactly zero** — this design's worst failure mode. What blunts it is that `beta_R_H` and
> `beta_R_V` are **not user-seedable**, so the hazard does not bite through them; `root_b` and
> `root_c` are, and it does. The boundary is wider and its shape is unchanged: four of the five
> factor through §6.3's waist pair at the same tolerance as the classic directions, and the fifth,
> `root_psi_crit`, sets `bound_b`, so it belongs to §6.7's bound branch rather than to the flux and
> is live only where the point is pinned — zero at the production driver, where every such row is
> NaN in any case.
>
> **§6.3 understates by four orders, and the construction is not a fit.** `a` and `b` are exact
> partials of `R` in two variables, so any direction identifies `a` once `b` is known; the quoted
> 2.6e-04 … 9.2e-04 is the fitting procedure's own noise, not the waist's residual. Measured over
> `2n + 1` directions the residual is 8.3e-09 … 2.6e-08.
>
> **§6.6's sign holds only under a drying-magnitude convention** the section never states.
>
> **§6.9's stationarity identity cannot discriminate a wrong `Π_pp`**, and this is a limitation of
> the invariant the report offers as a gate. `dp*/du` is formed *from* `Π_pp`, so it cancels out of
> `∂R/∂u + Π_pp · dp*/du` and the identity passes for the wrong reason. It is not a hypothetical: a
> real 2% error in the published curvature survived it, with the identity reading 4.54e-10
> **bit-for-bit the same before and after the fix**.
>
> **§6.4's premise is false in the tree (Phase 3, wave 3).** The section says the vulnerability
> interpolant's control points are fixed at construction and the parameter is carried by the values.
> `build_cumulative_vulnerability_integral` sets `psi_max = b*log(100)^(1/c)` and
> `step = psi_max/resolution` under a `psi <= psi_max` loop bound, so the knot **count** steps between
> 100 and 101 as `b` or `root_b` moves by 1e-6 relative. Held grid against moving grid:
> `dR/d(root_b)` 3.541221 against 168.3776 (47x), `d(profit)/d(root_b)` -2.2215 against -290.86
> (131x), `d(bound_a)/d(root_b)` 1.68651 against 17279.08 (10245x) — invisible at wet states, growing
> with drying. The ruling is to hold the grid and let the values carry the parameter, which is the
> arrangement §6.4 describes; **the forward model still carries the discontinuity**, and that is the
> owner's. Evidence in `../archive/implementation-notes.md`, *Phase 3, wave 3*.
>
> **The polish mostly does not converge, and that qualifies P2.6 rather than this report (Phase 3,
> wave 4).** `Leaf::polish_root_collar_psi` carries `R_tol = 1e-11` and `max_iter = 5`, and at
> production `Control()` **75.3% of 2 206 526 solves exhaust the cap** rather than reaching the
> tolerance, exiting at `|R|` up to 9.9986e-07 against a mean 2.07e-12 for the 24.7% that converge;
> zero pinned, zero non-finite, so every non-converged solve is a cap exhaustion. So P2.6's recorded
> bracket-independence to 1.044e-09 holds on the quarter that converge, and the rest return wherever
> five Newton steps reached from wherever golden section stopped. It shows up as a **derivative**
> problem and not a value problem: the spread of one step's `y_end` over 1e-5 input displacements is
> 1.141e-03 at production against 1.586e-10 at `GSS_tol_abs = 1e-6`, where the true derivative is
> 9.21e-08. `max_iter = 20` takes the one-step non-smooth spread from 7.820e-05 to 8.626e-08 and the
> exhausted fraction to 5.05%, and **tightening the bracket instead reaches the same floor from an
> independent direction**, which makes it a mechanism. It moves forward numbers — offspring
> 42.411799695604159 over 4 644 steps at cap 20 against 42.179817344974609 over 4 798 — so it is the
> owner's and was not taken. Evidence in `../archive/implementation-notes.md`, *Phase 3, wave 4*.
>
> **The cap change was taken, and the census that sized it was larger than wave 4 could see (Phase
> 3, wave 5).** Measured on the production tree rather than through a script hardcoded to a
> different worktree, the cap was exhausted on **80.92% of 7 353 330 polished solves** — mean `|R|`
> at exit 2.4088e-08, max 1.0019e-06 — not 75.3% of 2 206 526. At `max_iter = 20` it is **1.586%**,
> with 98.41% converging, so §6.5's polish now does what the section says it does and **P2.6's
> bracket-independence holds on 98.41% rather than 19.08%**. `scientific_version` is 5 and TF24's
> forward numbers moved by 0.55%; FF16 and K93 are bit-identical, which attributes the shift to the
> leaf. **What this report's own gate could not see is the whole of it**: `leaf_jac_gate.cpp`'s
> internal census reads 484 solves and **0 exhausted** at its four hand-built states, and every
> invariant in it is bit-identical before and after the change.
>
> **§6.8's rows were built and then thrown away, and no gate this report offers could have found
> it (Phase 3, wave 5).** `TF24_Strategy::graft_leaf_outputs` assembled its graft input vector from
> only the state-dependent `2n + 3` of `Leaf::inputs()` and then `row.resize(x.size())` truncated
> all **15** parameter rows away — so P3.3's rows, gated at 4e-10 against a central difference of
> the whole leaf solve, were computed correctly and discarded, and eleven trait columns of the
> whole-run gradient read **exactly zero** for two waves. §6.9's identities are clean throughout,
> the finiteness gate is 0 non-finite rows at every state, and **a finite difference of the block
> cannot referee it either**: the graft is `value + Σ partial_i * (x_i - to_passive(x_i))`, so the
> block's forward value is deliberately independent of a grafted input and the difference is
> identically zero on those columns whether the rows are present or not. That is §6.9's lesson one
> level up — a grafted row is refereed against the leaf's own difference and against nothing else.
> Nine of the eleven columns are now nonzero; `psi_crit` and `root_psi_crit` remain exactly 0
> **because the leaf's own rows are 0 there**, which is §6.7's bound branch and not a hole. Two
> claims about it are corrected: `rho` and `a_bio` are **not** an omission of any size — adjoint
> and central difference both read 0 at the leaf — and the `psi_crit` pinned-state gap is real and
> upstream of the graft, its adjoint reading 0 against a whole-solve −2.39e-04 and −8.25e-04.
> Evidence in `../archive/implementation-notes.md`, *Phase 3, wave 5*.

## 1. The proposal

Everywhere else in plant, a rate is a closed-form function of state and traits. In
TF24 it is not: the plant **chooses** its operating point. `Leaf::find_root_collar_psi`
maximises carbon profit over the root-collar water potential, within a feasibility
interval the soil sets. Differentiating a choice is a different problem from
differentiating an expression, and it has to be treated as one.

The tempting approach — make the `Leaf` scalar-templated so the tape records the
search along with everything else — is wrong twice over.

**It computes the wrong derivative.** `util::golden_section_max` shrinks its bracket by
a fixed ratio per iteration and returns the bracket's midpoint. The iteration count
depends only on the bracket width and the tolerance; the objective enters only through
the comparison that picks which half to keep. So for a fixed comparison pattern the
returned argmax is an exact affine function of the bracket endpoints and is
**independent of the objective's values**. A tape recording the search yields the
derivative of the bracket, not of the argmax. The objective's sensitivity is
structurally absent from it (section 5).

**It puts an active scalar somewhere it cannot safely go.** `Leaf` holds four
interpolators on a fixed 100-knot grid, roughly thirty loose `double` members with no
boundary between parameters and per-solve scratch, two caches keyed on exact `double`
comparison, a QAG integrator, a nested root-find and the golden-section search. Each
is a separate correctness question under an active scalar, and a mistake in any of
them is a wrong gradient rather than a compile error. One class of mistake is already
known: a hand-written value-graft whose lambda has a deduced return type hands the
tape references to expression-template temporaries that die on return, and the reverse
sweep then dereferences reused stack memory — a segfault arbitrarily far from its
cause, invisible to valgrind because the storage is stack.

**The proposal: leave `Leaf` entirely `double`, and give the tape one node whose local
Jacobian is supplied.**

The optimisation structure is what makes this cheap, and most of the work turns out
to be unnecessary:

- **`profit_` is the objective evaluated at its own maximiser.** By the envelope
  theorem `d(profit)/d(theta)` is the partial derivative at *fixed* operating point —
  the argmax's motion contributes nothing. This is the entire carbon channel:
  assimilation, net mass production, all four growth rates, the mortality argument.
  **No argmax derivative is needed for any of it.**
- **`soil_consumption_` is a different matter.** It is set as a side effect at the
  operating point, so it is a consumer of the argmax rather than the objective, and
  the envelope theorem says nothing about it. Here `d(q*)/d(theta)` is genuinely
  required, and the implicit function theorem applied to the stationarity condition
  supplies it.
- **At a boundary optimum both are simpler.** When the argmax is pinned to the
  feasibility bound, `q*` *is* the bound, so its derivative is the bound's derivative
  — analytic, and exact.
- **The selector between the two is free.** Whether the argmax sits on a bracket
  endpoint is a comparison already available where the search returns.

Those are the only four facts needed. Nothing inside `Leaf` is differentiated; the
node relates its inputs to its outputs and the tape sees a small dense block.

**One further step is not optional, and it is the most actionable finding here.**
`golden_section_max` returns the midpoint of a bracket it has narrowed to `tol`, so
`q*` carries an error of up to `tol/2` — and that error enters the derivative through
the point at which the implicit function theorem is linearised. Measured, with the
decomposition otherwise identical: at `tol = 1e-12` the gradient is wrong by 5.8e-06,
and **at TF24's production `GSS_tol_abs = 1e-3` it is wrong by 3.5%.** Newton-polishing
`q*` to a stationary point before using it gives **4.5e-10 at every tolerance tested**,
matching an exact root-find. Tightening the search instead does not work: the error
plateaus at 6e-6 and stops responding.

So the node must polish. It is cheap — one to three Newton steps from within `tol/2` of
the root — and develop already has the exact first derivative it needs
(`dprofit_droot_collar_psi`). Section 7.2 gives the measurements and section 6.1 the
placement.

**Measured, and this is what makes it practical:** across 4 372 101 leaf solves at
production settings, **every one is a strictly interior optimum**. All five of the
solver's early exits have zero incidence and the narrowest feasibility bracket
observed is 1 342 times the tolerance that would collapse it. The boundary branch is
reachable, but it needs a twentyfold rainfall reduction (section 4). So the interior
treatment is the production path and the boundary treatment is insurance.

**Scope.** Six output rows are needed for a census or R0 functional: `profit_` and the
five `soil_consumption_` layers. The leaf's other five outputs reach auxiliary slots
only (section 3.3). The input side is the arguments to `set_physiology` that carry
derivatives, plus whichever of TF24's 51 declared differentiation targets reach the
leaf (section 6.2).

**What this does not fix**, and both matter: ~~TF24's growth gate is a hard un-smoothed
switch immediately downstream of `profit_`~~ — **corrected against the tree: it is smoothed
inline.** `TF24_Strategy::compute_rates` forms
`Ppos = 0.5 (P + sqrt(P^2 + storage_prod_eps^2))` at `storage_prod_eps = 1e-4`, times a
logistic reserve gate, which is what replaced the hard `net > 0` cutoff; report 00 §4.3
records it. This report's C1 attributes four `smooth_positive` sites to plant, and that
helper exists at **no** site in plant's headers — the four are the AD branch's, and the
claim was carried across to a develop-tree conclusion. TF24's one remaining hard
`net > 0` gate is inside `establishment_probability`, which sets the boundary node's
density rather than any cohort's growth rate. And one of develop's derivative helpers
falls back to a finite difference at a layer kink. Section 8.

---

## 2. Why the leaf, specifically

`TF24_Strategy::net_mass_production_dt` runs the hydraulic optimisation once per
cohort per Runge-Kutta stage. At production settings — `max_patch_lifetime = 105.32`,
141 cohorts, mean-light shading — that is **4 372 101 leaf solves** (measured), in a
53.1 s forward run, over 2 829 accepted ODE steps. **That count and that step count
predate the NSC storage state**; report 01 §2 gives develop's own counts, where the
same structural ratio projects about 8 M solves. The ratio is what this report uses and
it is unaffected: two solves per cohort per stage.

A leaf solve taken off the tape records approximately **1 600 operations, independent
of the number of solver iterations**. At XAD's 12 bytes per operation:

    4 372 101 solves x 19.2 kB  ~=  84 GB          (projected)

against a whole-run tape of roughly 220 GB on the same tree (490 GB on develop's counts,
report 01 §2). So the leaf is a large fraction of the
recording without being all of it, and shrinking it alone does not make a production
gradient possible. Report 1 bounds peak memory; this report is about correctness and
containment, with size as a secondary benefit.

---

## 3. State at develop

### 3.1 The call path

```
TF24_Strategy::compute_rates(environment, vars)                 tf24_strategy.cpp:151
  net_mass_production_dt(environment, height, area_leaf_, height_inverse)
    ... allometry, root mass distribution over soil layers ...
    optimise_at(radiation):                                     tf24_strategy.cpp:401
        leaf.set_physiology(area_leaf_, mass_root_prop_, pars.rho, pars.a_bio,
                            radiation, psi_soil, soil_depths_,
                            leaf_specific_conductance_max, atm_vpd, ca,
                            sapwood_volume_per_leaf_area, leaf_temp,
                            atm_o2_kpa, atm_kpa)
        solve_leaf()  ->  leaf.find_root_collar_psi()
    the shading model decides how many times optimise_at runs:
        CrownCentre  1 solve at the crown-centre light
        MeanLight    1 solve at the leaf-area-weighted mean light  (TF24's default)
        DeepCrown    one solve per Gauss-Kronrod abscissa (rule 21)
    assimilation_ = leaf.profit_ * area_leaf_ * 60*60*12*365/1e6
    return net_mass_production_dt_A(assimilation_, respiration_, turnover_)
```

and the solve itself:

```
find_root_collar_psi()
  if (!prepare_collar_solve(bound_a, bound_b)) return;   // operating point already set
  opt_root_psi = util::golden_section_max(
      [](double bound) { psi_stem = find_psi_stem_from_psi_root(-bound, psi_soil_inverted_);
                         return profit_psi_stem_TF(psi_stem, bound); },
      bound_a, bound_b, GSS_tol_abs);
  opt_psi_stem_    = find_psi_stem_from_psi_root(-opt_root_psi, psi_soil_inverted_);
  root_collar_psi_ = -opt_root_psi;
  profit_          = profit_psi_stem_TF(opt_psi_stem_, opt_root_psi);
```

### 3.2 Six ways the operating point gets set

`prepare_collar_solve` returns `false` — meaning it has set the operating point itself
and no search runs — on five conditions:

| | condition | action |
|---|---|---|
| **E1** | `-wettest_soil_layer >= psi_crit` | `set_shutdown_state(-psi_crit)` |
| **E2** | `E_column(-psi_crit, psi_soil_inverted_, psi_crit) < 0` | `set_shutdown_state(-root_psi_crit)` |
| **E3** | `-root_crit >= psi_crit` | `set_shutdown_state(root_crit)` |
| **E4** | `assim_max_ < 0` | operating point at `root_zero_E`, zero transpiration |
| **E5** | `abs(bound_b - bound_a) <= GSS_tol_abs` | collapsed interval, use the midpoint |

There is a sixth case, and it is the one that matters most for this proposal because
it is **not** an early exit: the search runs normally and returns an argmax sitting on
the bracket endpoint `bound_b = max(-root_crit, -root_psi_crit)`, the root-hydraulic
ceiling. The envelope-theorem argument holds at an interior optimum and does not hold
there. Section 4 counts all six.

### 3.3 Which leaf outputs are load-bearing

`compute_rates` reads the leaf as follows:

| leaf member | destination | needs a derivative? |
|---|---|---|
| `profit_` | `assimilation_` -> `net_mass_production_dt_` -> height, fecundity, area_heartwood, mass_heartwood rates and the mortality argument | **yes** |
| `soil_consumption_[i]` | `evapotranspiration_dt(area_leaf_, i)` -> `vars.set_consumption_rate(i, ...)` -> `Patch::resource_depletion` -> soil rates | **yes** |
| `opt_psi_stem_` | `vars.set_aux(aux_idx_opt_psi_stem, ...)` | no — auxiliary only |
| `root_collar_psi_` | `vars.set_aux(aux_idx_opt_root_psi, ...)` | no |
| `transpiration_` | `vars.set_aux(aux_idx_transpiration, ...)` | no |
| `E_up_` | `vars.set_aux(aux_idx_E_up, ...)` | no |
| `stom_cond_CO2_` | `vars.set_aux(aux_idx_stom_cond_CO2, ...)` | no |

**Six output rows carry the rates: `profit_`, and `soil_consumption_` for each of the
five soil layers.** The other five outputs reach auxiliary slots and need derivatives
only if a functional reads them. `test-strategy-tf24.R`'s E-conservation test reads
`E_up_` through the auxiliary path, so a functional built on that would need a seventh
row.

### 3.4 Derivative machinery develop already has

develop contains hand-built exact derivatives of the leaf, added for TF24f's
acclimation tracking:

- `Leaf::dprofit_droot_collar_psi(opt_root_psi)` — forward-mode AD for the analytic
  photosynthesis and cost algebra, the implicit function theorem at the
  `psi_stem_to_ci` root-find, and analytic spline derivatives via
  `Interpolator::deriv` for the smooth transport. One branch is not analytic: when
  `dE_from_soil_dpsi_collar` returns NaN at a branch kink it falls back to a `1e-6` central
  difference on the transport, which is C2's subject and whose incidence is uncounted. It
  also reads `psi_soil_inverted_`, which only `prepare_collar_solve` refreshes, so a caller
  that changes the soil and calls it directly differentiates against a stale vector.
- `Leaf::dE_from_soil_dpsi_collar(P_x_r, psi_soil)` — analytic
  `d(E_up_)/d(collar potential)`, where the integral's derivative collapses to the
  analytic slope of the pre-integrated vulnerability curve.
- `Leaf::evaluate_root_collar_psi` and `Leaf::profit_at_collar_psi` — evaluate the leaf
  at a *given* collar potential rather than optimising it, which is the entry point a
  supplied Jacobian needs.

So the pattern is already present in develop for one input direction. This proposal
extends it to the full input set and routes it onto the tape.

### 3.5 A defect in the shutdown path

`Leaf::set_shutdown_state` sets three members:

```cpp
void Leaf::set_shutdown_state(double root_collar) {
  root_collar_psi_ = root_collar;
  opt_psi_stem_ = psi_crit;
  profit_ = -R_d_ - hydraulic_cost_TF(psi_crit);
}
```

It does not clear `soil_consumption_`. `set_physiology` calls
`soil_consumption_.resize(soil_number_of_depths_, 0.0)`, and `std::vector::resize`
does not modify existing elements, so at an unchanged layer count the previous values
persist. The `Leaf` is shared through the strategy's `shared_ptr` across every cohort
of the species, so **a cohort taking a shutdown exit contributes the previous
cohort's water draw to `resource_depletion`.** That is a forward-model defect, not
only a gradient one: the uptake is stale and independent of the shut-down plant's own
soil moisture.

**And a shutdown exit is not required for it.** The same `resize` leaves every layer *below*
`max_soil_layer` untouched on an ordinary solve, so a shallow-rooted cohort following a deeper one
carries that cohort's deep-layer uptake with no branch taken at all — 33.78% of production records
(report 01 §5, `../tf24-correctness.md` P0.1), against zero incidence for this section's shutdown
route. `../archive/build-plan.md` M7 measures the consequence for the reverse pass: restoring a leaf's inputs
and its stored operating point reproduces every output bit-for-bit at 8 of 9 states, and the ninth is
this defect. So P0.1 and P0.2 are one fault with two entrances, and P0.1's is the one the production
driver uses.

The fix is two lines in `set_shutdown_state` — `soil_consumption_.assign(n, 0.0)` and
`E_up_ = 0.0`. Section 4 establishes the blast radius: unreachable on the production driver, 199
occurrences in 330 021 solves at a twentyfold rainfall reduction. (**Landed as P0.2**,
`aornugent/plant#66`; `../tf24-correctness.md` and `../archive/implementation-notes.md` carry it. This report
describes develop `141dc8df`, where the defect is still present.)

---

## 4. Measured incidence of every branch

> **Re-measured in Phase 3 and this section's zero holds: 0 pinned of 7 353 330**, against its own 0 of
> 4 372 101, with a dry arm returning 990 724 to prove the counter alive. So P3.2's interior envelope
> case is what production solves need and the bound branch is insurance. Two caveats on the agreement.
> The Phase 3 census classifies on the polish's own control flow and counts a guard (`pinned_step_outside`)
> that did not exist when this table was taken, so **the two zeros are not the same measurement** even
> though they agree. And it found a class this table has no column for: **80.9% of production solves
> exhaust five Newton steps with `|R|` up to 1.0019e-06**, which is the number to budget §6's envelope row
> against rather than the 1e-13 P2.6's own sample reports.
>
> The rest of this note is the question as it stood, retained because it is why the measurement was taken.
>
> **This section's zero pinned-solve count was unverified against the current leaf, and P3.2's shape
> depends on it.** The census below predates **P0.1, P0.2 and P0.12**, all three of which changed what
> the leaf computes, and nobody has re-measured since. A Phase 2 probe assembling a `Leaf` from
> `TF24_Strategy`'s own defaults — `beta_R_H = 3.4e2`, `root_b = 3.898`, `root_c = 2.680`,
> `g1_TF24 = 7.5`, `a_r1 = 0.07` — found **every** state pinned at the wet bound across `psi_soil`
> 0.015–0.17 and heights 1, 5, 10 and 20 m, with `|R|` of 0.06 to 1.6.
>
> The two disagree and the hand-assembled leaf is the more likely error — `PPFD = 900` passed as
> absorbed radiation is the prime suspect, since the model forms `radiation = k_I · max(L, 1e-4) · PPFD`
> and both factors are below one. But this census is an instrumented count on the real SCM at a leaf
> that no longer exists. **If the pinned regime is in fact common at the production driver, §6's bound
> branch stops being insurance and becomes the path, and the envelope row's argmax machinery is not what
> most solves need.** One instrumented production run settles it, and it is owed before P3.2. That no
> `Leaf` is reachable from a `TF24_Strategy` or an `Individual` through RcppR6 is why this is a question
> rather than a measurement, and is worth fixing on its own account.
>
> **§6.5's polish is built as P2.6 and came out better than predicted**: `|R|` at the returned point is
> **9.587e-09** against the 1.6e-08..4.7e-07 forecast here, the polished point is bracket-independent to
> 1.044e-09, and with golden section loosened to `1e-1` the polish **costs less than nothing** — the
> nine profit evaluations the loosened search no longer does more than cover the two extra `dprofit`
> calls. §7.2's plateau reappeared in a second place: `R_tol = 1e-11` is below `R`'s own resolution,
> because the `ci` root-find inside it carries `ci_abs_tol = 1e-6`.

Counters were added to the five exits and the boundary case in a worktree on develop
at `96941d3b`. Runs used `scm_base_parameters("TF24", "TF24_Env")` with
`add_strategies(p0, trait_matrix(0.1978791, "lma"))`, default `Environment("TF24")`,
`Control()`, `refine_schedule = FALSE`. The instrumentation is preserved as
`docs/reports/leaf-branch-census.patch`.

One obstacle was recorded here, and it has since been shown to be branch-local: develop's plant
failing to compile against the installed odelia, because `odelia/ode_util.hpp` called `xad::value`
without including XAD. Report 01 §11.1 compiled plant-develop clean against `854a8e18` — the header
now includes XAD — so the `-include XAD/XAD.hpp` workaround this section describes is not needed, and
§10's item asking for the include is closed.

| configuration | solves | E1 | E2 | E3 | E4 | E5 | pinned at bound_a | pinned at bound_b | min bracket |
|---|---|---|---|---|---|---|---|---|---|
| **life 105.32, mean-light, default rain** | **4 372 101** | 0 | 0 | 0 | 0 | 0 | 0 | **0** | 1.342 |
| life 20, rain 1 | 1 400 715 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.381 |
| life 20, rain 0.5 | 2 563 713 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.057 |
| life 20, rain 0.2 | 2 750 871 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.016 |
| life 20, rain 0.1 | 343 779 | 0 | 0 | 0 | 0 | 0 | 0 | **267** | 0.876 |
| life 20, rain 0.05 | 330 021 | 0 | **199** | 0 | 0 | 0 | 0 | **110 984** | 0.716 |
| life 5, mean-light | 577 791 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.798 |
| life 5, deep-crown | 6 038 487 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.811 |
| life 5, deep-crown, rain 0.1 | 2 826 369 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1.109 |

**On the production driver every solve is a strictly interior optimum.** All five
exits are unvisited across 4.37 million solves, and the narrowest bracket is 1.342
against `GSS_tol_abs = 1e-3` — E5 is not merely unreached, it is three orders of
magnitude away.

**The boundary regime is real but needs severe drought, and it is not one of the
documented exits.** A fivefold rainfall reduction changes nothing. At tenfold, 267 of
343 779 solves (0.08%) return an argmax pinned at `bound_b`. At twentyfold, 110 984 of
330 021 (33.6%), plus 199 hits on E2. The first thing to appear is the case nobody was
counting.

**Deep-crown does not change the picture and costs 10.5x.** At life 5 it runs
6 038 487 solves against mean-light's 577 791, and produces zero boundary cases even
at rainfall 0.1.

**Two caveats.** The rainfall 0.1 and 0.05 runs collapse to roughly 280 accepted ODE
steps from 2 153, so the stand is largely dying and the 33.6% is computed over a small
and unrepresentative population — the *existence* of the regime is established, its
frequency under a realistic drought driver is not. And `min bracket` declines
monotonically with drying (1.38 to 0.72), so the trend does point at E5 eventually,
far past where the model produces anything.

---

## 5. Why the search must not be taped

```cpp
double golden_section_max(Function f, double ax, double bx, double tol) {
  const double gr = (std::sqrt(5.0) + 1.0) / 2.0;
  double a = ax, b = bx;
  double c = b - (b - a) / gr;
  double d = a + (b - a) / gr;
  double fc = f(c), fd = f(d);
  while (std::abs(b - a) > tol) {
    if (fc > fd) { b = d; d = c; fd = fc; c = b - (b - a) / gr; fc = f(c); }
    else         { a = c; c = d; fc = fd; d = a + (b - a) / gr; fd = f(d); }
  }
  return (a + b) / 2.0;
}
```

The iteration count is fixed by `(bx - ax)` and `tol` alone, since the bracket shrinks
by `1/gr` each pass regardless of the objective. The objective enters only through
`fc > fd`, which selects which sub-bracket survives. The return value is the midpoint
of a bracket reached by golden-ratio subdivisions of the original.

So **for a fixed comparison pattern the argmax is an exact affine function of
`(ax, bx)` and does not depend on the objective's values at all.** Taping through the
search gives `d(bracket)/d(theta)` pushed through that affine map. That is a real
quantity and it is not the derivative of the argmax.

This also means a comment in `optimize.h` states the wrong reason for a correct
choice. It says `brent_fmin`'s parabolic step makes the argmax non-smooth in its
inputs, and that the collar solver uses golden section because the demographic
growth-rate gradient needs the argmax to vary smoothly with plant state. Golden
section's argmax is not smooth either — it is a staircase in the objective and affine
in the bracket. What it actually gives is a comparison pattern that is *locally
constant*, so across a finite-difference step of `node_gradient_eps = 1e-6` the
pattern usually does not change and the argmax moves affinely with a bracket that
itself moves smoothly. That is the property `Node::growth_rate_gradient` relies on.
The distinction matters because the stated reason invites a reader to treat the argmax
as differentiable by composition, which is exactly the mistake this section rules out.

---

## 6. The node

The leaf stays `double`. Golden section, the two bracket root-finds, the `ci` root-find, the
four interpolants and both caches are never taped and never audited for active-scalar
safety. At its solved operating point the leaf contracts its own two output adjoints onto its
inputs, and the cohort's tape carries them on from there.

Two adjoints arrive — one scalar on profit, one per soil layer on uptake — and leave as
contributions to the soil potentials, the geometry and light inputs, and the traits. What follows is
the partial derivative of each output with respect to each input, which is what that contraction
sums over; they are the leaf's own state, not a value it returns.

### 6.1 Carbon is an envelope row

`profit_` is `profit_psi_stem_TF` evaluated at its own maximiser, so `dΠ/dp = 0` there and

```
contribution += lambda_Pi * dPi/du        at frozen p*, for every input u
```

with no argmax derivative anywhere. Measured: `dΠ/d(vcmax_25)` at a frozen operating point
equals a central difference of the whole solve to every printed digit at six of six
production states.

### 6.2 Water is not, and five rows collapse to one scalar

`E_i` consumes `p*` rather than being stationary in it, so it carries the argmax's motion.
Two properties make that cheap.

**The explicit part is sparse.** `E_i` reads its own layer's potential and the collar, so
`∂E_i/∂ψ_j` is diagonal. Root mass enters through `r_R`, whose vertical component is a
cumulative sum down the column, so `∂E_i/∂(root mass_j)` is lower triangular. And
`∂E_i/∂area_leaf = −E_i/area_leaf` **exactly**, because `1/area_leaf` is a single factor and
the resistances contain no leaf area. That is an internal identity rather than a model
channel: report 00 §4.2 shows the factor cancels downstream, so the soil sees uptake with no
leaf-area dependence.

**The argmax part is rank one.** Every layer shares one `p*`, so

```
s_k  = sum_i  lambda_E,i * dE_i/dp           one number per cohort
mu_k = - s_k / Pi_pp                         one divide, from dPi/dp = 0
contribution += mu_k * grad R                R = dPi/dp
```

`Π_pp = ∂R/∂p` is negative at every state sampled, running from −1.09 at a five-layer
seedling to −198 at a twenty-layer canopy tree. It scales with the layer count, because more
layers mean more conductance and a sharper optimum, so a value quoted without its layer count
means nothing.

### 6.3 The waist: `grad R` is two scalars

`R` reads the soil potentials, the per-layer root masses and the leaf area **only** through
the soil-to-collar flux `E_up` and its derivative with respect to the collar potential. So
for every one of those `2n + 1` directions

```
dR/du  =  a * dE_up/du  +  b * d(dE_up/dr)/du
```

with `a` and `b` two scalars shared across all of them and both `E_up` derivatives closed
form. A joint fit over 41 directions — twenty potentials, twenty root masses, leaf area —
under one shared pair leaves a relative residual of 2.6e-04 to 9.2e-04.

**`b` is closed form** in intermediates `R` already computes:

```
b = - ( A'(ci) * dci/dpsi_stem  -  C'(psi_stem) ) * P'(E_psistem) / kappa
```

It agrees with the joint fit to 1.04% and 0.16%, and pinning it there while refitting `a`
leaves the residual unchanged.

**`a = ∂R/∂E_up` is recovered from one additional pair of residual evaluations** on the
reverse pass, in a single soil-potential direction. One direction suffices because the
potential family is rank one — its unscaled second singular value is 1.3e-05 to 2.0e-05 of
the first, and the `b` channel is a millionth of the potential response there. Recovered from
each of twenty layers in turn, the values agree to 0.00129%, 0.00036% and 8.4e-05% at the
three states measured, so using more than one layer is a consistency check rather than a
cost.

The pair belongs to a `Leaf`, hence to a species. At identical soil, two species give `a` of
−1.79e+05 against −1.51e+05 for a sapling and −9.11e+05 against −7.66e+05 for a tree.

### 6.4 The remaining input directions

Radiation, the leaf-specific conductance and the leaf's own parameters are parameter
derivatives of two short algebraic functions and of two interpolants:

- `assim_colimited_ad` and `hydraulic_cost_ad` are already templated on their scalar in
  develop, so `A′`, `C′` and their parameter derivatives come from them directly.
- The transpiration and root-vulnerability interpolants are built once per `Leaf` from `b`,
  `c`, `root_b` and `root_c` over a hundred control points. Their positions are constant and
  their values carry the parameter — the same arrangement report 03 gives the light
  interpolant.

`κ` is the one input the waist does not absorb alone: it appears inside `E_ψstem` and again as
a multiplier in the stomatal conductance, so it carries one extra explicit term.

### 6.5 The polish, which the envelope row requires

The envelope row is valid where `dΠ/dp = 0`. Golden section at production tolerance returns a
point where `|R|` is 8.8e-05 to 1.2e-03; Newton on `R` takes it to 1.6e-08 to 4.7e-07. The
displacement moves `profit_` at second order — which is why §6.1's measurement is exact at
either point — and `soil_consumption_` at first order. So the polish is a prerequisite, and
it is a forward-model change that needs a baseline re-bless.

The forward model therefore runs golden section only far enough to enter the Newton basin.
At the measured production bracket, reaching `1e-3` costs seventeen profit evaluations and
reaching `1e-1` costs eight; Newton's derivative is `Π_pp`, which the bundle already holds.

### 6.6 The uniform direction, computed from what breaks the symmetry

Report 00's physical reading gives the reason: uptake is driven by a difference of potentials
while conductivity depends on absolute tension, so a uniform translation of the water column
is a near symmetry and the flux response along it is a small residue — four to nine percent
of the collar's own response. It is computed from the term that breaks the symmetry, never by
subtracting the collar's response from one.

For the uptake, the only translation-breaking term is the cumulative root-vulnerability
integral over an interval whose endpoints both slide:

```
dE_i/dd = E_i * (r_H,i / r_R,i) * ( f_r(|P_min,i|) - f_r(|P_max,i|) ) / integral_i
```

exact to 0.002–0.012% against a difference along the translation, at every layer of every
state measured. Every factor is already computed in the forward pass, plus two evaluations of
the vulnerability curve.

For the stem, `psi_from_transpiration` and `transpiration_from_psi` are inverses, so
`P(S(x)) = x` and the leading term is exactly one:

```
dpsi_stem/dd = 1 + P'(E_psistem)*(dE_up/dd)/kappa + S'(p)*[ P'(E_psistem) - P'(S(p)) ]
```

exact to better than 5e-06. The second correction dominates, and its sign is the opposite of
the collar's: the stem falls 1.28 to 2.97 times as fast as the soil, because the same flux
through a less conductive xylem needs a steeper gradient.

### 6.7 The bound case

`p*` is the argmax over `[bound_a, bound_b]`, both from root-finds — `bound_a` where soil
uptake is zero, `bound_b` the drier of the stem's and the root's critical potentials. When
`p*` is interior the bounds enter no row. When the polish leaves the bracket, `p*` **is** the
bound and `dp*/du = d(bound)/du`: `root_psi_crit` is closed form in `root_b` and `root_c`,
and `root_crit` carries its own implicit-function term. Section 4 measures the incidence —
zero at the production driver, and a third of solves at a twentyfold rainfall reduction.

### 6.8 The inputs, and how the bundle scales

| input | count |
|---|---|
| radiation | 1 |
| soil water potential, per layer | `n` |
| `area_leaf` | 1 |
| root mass, per layer | `n` |
| leaf-specific conductance | 1 |
| the leaf's own parameters — `vcmax_25`, `jmax_25`, `a`, `curv_fact_elec_trans`, `curv_fact_colim`, `b`, `c`, `psi_crit`, `beta2`, `g1_TF24`, plus `rho` and `a_bio` | 12 |

`sapwood_volume_per_leaf_area` is passed to `set_physiology`, stored, and read nowhere, so it
is not an input.

Outputs are `profit_` and one uptake per layer that has root mass. That arity is
state-dependent: `max_soil_layer` is the deepest layer with nonzero root mass, so it follows
the rooting depth, and any size assertion has to read it rather than the layer count.

**The bundle does not grow with the trait count.** A trait outside the leaf reaches it only
through the geometry and light inputs, and the cohort's own tape supplies those. **Nor does it
grow with the layer count** in the expensive direction: the `2n + 1` potential, root-mass and
leaf-area directions cost the two scalars of §6.3 however large `n` is.

### 6.9 Verification without a finite difference

A re-run finite difference of the whole solve is the amplified route. It resolves the collar's
response to about four digits, and the residue being checked is four to nine percent of that
response, so it cannot measure the quantity it would be verifying — a disagreement there
reports the reference, not the scheme. Three exact invariants do the job, and none is a
difference of large numbers:

- **Stationarity.** `R(p*(u), u) = 0` identically in every input, so
  `∂R/∂u + Π_pp · dp*/du = 0`. The bundle supplies both terms, so it checks itself at any
  state, in a unit test, with no differencing.
- **Continuity.** `ψ_stem` is defined by inverting the transpiration relation, so `E_up` from
  the soil side is identically `κ(S(ψ_stem) − S(p))` from the stem side. Two different
  interpolant chains compute the same number, so their derivatives must agree — which checks
  the interpolant derivative chain, the one part with no other oracle.
- **The waist.** The joint residual over all `2n + 1` directions under one shared pair of
  coefficients, which is also how a bad recovery of `a` announces itself.

---

## 7. Evidence

The construction in section 6 was exercised in a standalone system with plant's
coupling structure and none of its physiology (`scratchpad/cohort_toy.cpp`, described
in report 1 section 7). The inner solve was implemented twice: as a plain implicit
root-find, and as a fixed-tolerance golden-section maximisation over a soil-dependent
bracket, with the envelope theorem for the objective, the implicit function theorem
for the side output, and the boundary branch.

**This is a toy.** It establishes that the envelope / IFT / boundary decomposition is
arithmetically correct and how large its residuals are. It establishes nothing about
TF24's leaf physiology.

### 7.1 The two branches

| leaf treatment | interior | boundary | cohort vs whole-run tape | AD vs FD |
|---|---|---|---|---|
| implicit root-find | — | — | 1.4e-14 | **4.5e-10** |
| argmax, all interior | 1 200 | 0 | 8.1e-15 | 1.1e-05 |
| argmax, bound at 0.60 | 1 200 | 0 | 1.4e-14 | 4.0e-06 |
| argmax, bound at 0.30 | 1 183 | 17 | 7.5e-15 | 2.9e-06 |
| argmax, bound at 0.10 | 0 | 1 200 | 9.8e-15 | **3.1e-10** |

**The boundary branch is exact; the interior branch is not.** Fully at the bound, AD
matches FD to 3.1e-10, because `q*` is then an analytic function of the bound. Fully
interior, 1.1e-05. A run mixing the two (17 boundary of 1 200) does not degrade, so
the selector composes and there is no catastrophe at the switch.

### 7.2 The interior residual, and why it closes

The interior branch's discrepancy is entirely the accuracy of `q*` **as a linearisation
point**. Sweeping the search tolerance, with and without a Newton polish of `q*` before
the implicit function theorem is applied:

| search tolerance | unpolished | polished | ratio |
|---|---|---|---|
| **1e-3** (TF24's `GSS_tol_abs`) | **3.48e-02** | **4.54e-10** | 7.7e7 |
| 1e-4 | 1.41e-02 | 4.54e-10 | 3.1e7 |
| 1e-6 | 2.09e-04 | 3.44e-10 | 6.1e5 |
| 1e-9 | 1.11e-05 | 4.54e-10 | 2.4e4 |
| 1e-12 | 5.81e-06 | 4.54e-10 | 1.3e4 |

Polished, the argmax branch matches the plain root-find reference (4.542e-10) to three
digits at every tolerance, and the search tolerance stops mattering. Unpolished, the
error is **3.5% at the tolerance TF24 actually uses**, and tightening the search does
not rescue it — it plateaus near 6e-6.

Two candidates were eliminated by direct test rather than argument. The envelope
application is **not** implicated: carrying `q*`'s own derivative into `profit_` instead
of evaluating at the passive argmax changes nothing (5.812e-06 either way), and combining
that with the polish gives the same 4.541e-10. And it is not `implicit_value`'s
finite-difference probe scale: the polish leaves that probe untouched and still recovers
exactness.

**The transferable rule:** a search's stopping tolerance is not the accuracy of a
derivative built on its answer. An argmax consumed by anything other than the objective
must be polished to a stationary point before it is used as a linearisation point, and
the required accuracy is set by the derivative, not by the value.

This also characterises develop's demographic transport term.
`Node::growth_rate_gradient` finite-differences the growth rate at
`node_gradient_eps = 1e-6`, and the growth rate depends on `q*`, which moves in steps of
order `GSS_tol_abs = 1e-3`. The stencil is stable only because the comparison pattern is
locally constant across a 1e-6 height perturbation, so `q*` moves affinely with its
bracket — which means the quantity that stencil differentiates is the bracket-affine
surrogate rather than the true optimum. That is consistent with the code working and
with section 5's analysis, and it is worth knowing before anyone tightens or loosens
either tolerance.

---

## 8. Constraints

**C1. TF24's growth gate is a hard un-smoothed switch, immediately downstream of
`profit_`.**

```cpp
if (net_mass_production_dt_ > 0) { ...growth, fecundity, heartwood... }
else                             { ...all four rates set to 0.0... }
```

`smooth_positive` is applied at two sites in `ff16_strategy.h` and two in
`k93_strategy.h` on the AD branch, and at none in either tree for TF24. So at the
carbon compensation point four of TF24's five rates have a derivative discontinuity,
and the leaf node's `profit_` Jacobian is multiplied by zero on one side of it. This
proposal neither causes nor fixes it, but any finite-difference verification of a TF24
gradient will straddle it if the step crosses the gate for any cohort. The incidence
should be counted the way section 4 counts the leaf branches before it is designed
around.

**C2. `dE_from_soil_dpsi_collar` falls back to a central difference.** It returns NaN
when any layer sits on a branch kink — `P_x_r == psi_soil[i]`, the gravity-balance
point, or `P_x_r == 0` — and `dprofit_droot_collar_psi` then substitutes a central
difference. That fallback would sit inside the supplied Jacobian, which is precisely
where a numerical derivative of an active quantity should not be. It needs a decision
rather than inheritance, and the kink incidence should be counted.

It reaches further than the Jacobian's own rows. `R` is `dprofit_droot_collar_psi`, so
`dψ_stem/dp` is one of the intermediates §6.3's closed form for `b` is built from — meaning that
where the fallback fires, `b` is closed form in a differenced quantity rather than an analytic one.
Nothing measured has hit it, and the incidence is still uncounted, so this is the one place the
word *closed form* in §6.3 is conditional.

**C3. Two caches must be handled, as in report 1.** `photo_temp_cached_` persists
across cohorts on a key of `(leaf_temp_, atm_o2_kpa_)` while caching `vcmax_` and
`jmax_`, which depend on `pars.vcmax_25` and `pars.jmax_25` — both declared entries of
`TF24_AD_FIELDS`. The key is a proper subset of the dependencies. Under this proposal
the `Leaf` stays `double`, so the cache cannot poison a tape; but if either parameter
is a seeded target, the value the node linearises about must correspond to the seeded
value, and a stale cache breaks that.

**C4. The shutdown-state defect of section 3.5.** Reachable only under drought, but it
is on the path this node replaces, and it should be fixed on develop independently of
any AD work.

**C5. `Leaf` has no boundary between parameters and per-solve scratch.** Roughly thirty
loose doubles, five vectors and four interpolators, interleaved, with nothing marking
which are transient. This proposal reduces the consequence — nothing needs auditing
for active-scalar safety — but §6.8's input list was assembled by reading
`set_physiology`'s signature and would silently become incomplete if that signature
grew — and one entry has already been found dead that way (`sapwood_volume_per_leaf_area`,
stored and never read). Report 1 section 11 step 4 proposes giving those fields an explicit boundary,
which would make the input list derivable rather than maintained.

**C6. Only mean-light and crown-centre are covered.** TF24's deep-crown assembly
raises a stop on the AD branch's active path. Under this proposal deep-crown is one operating
point per crown quadrature node — 21 rather than one — and §6's bundle applies per node, so the
cost is 21 times the boundary rather than 21 times a dense Jacobian: `waist_b` is closed form
per node and `waist_a` is one residual pair per node. Mechanical, still 21 times the work, and
still not covered by section 7's evidence. Mean-light is the default and is what every number in
this report was taken on.

---

## 9. What this asks of a Strategy author

The engine's contract does not change: a Strategy implements `compute_rates` and gets a
gradient. But a Strategy containing an inner solve has obligations that no compiler
checks, and TF24 currently meets some of them by accident. Stated as guidance, each
rule with the construct that motivates it:

**1. Return the solution, expose the residual, never expose the search.** For a
quantity defined implicitly the differentiable object is the defining equation. A
search's output is determined by comparisons, so differentiating through it yields
something that is not the derivative of the solution (section 5). `implicit_value`
takes a residual for this reason.

**2. Know which of your outputs are load-bearing.** Only the outputs that reach rates
need derivative rows. TF24 has seven leaf outputs and two of them matter (section 3.3).
Establishing that turned a twelve-row problem into a six-row one.

**3. An objective at its own optimum is free; its other consumers are not.** The
envelope theorem covers `profit_` completely and covers `soil_consumption_` not at all,
and the measured cost of getting that wrong is 4 to 12% (section 7). The question to
ask of every output of an optimisation is whether it *is* the objective or merely reads
the argument that maximised it.

**4. A feasibility bound is part of the model, so its derivative is part of the
answer.** When the optimum sits on a constraint, the constraint's sensitivity *is* the
sensitivity. That branch is exact and cheaper than the interior one, which is the
opposite of what one might expect.

**5. Every early exit sets an operating point — set all of it.** `set_shutdown_state`
sets three members and leaves a fourth stale, and because the object is shared the
stale value belongs to a different plant (section 3.5). An exit that writes a partial
state is a cross-cohort channel.

**6. A guard that returns NaN and falls back to a finite difference is a severance in
disguise.** C2. The fallback is invisible in the value and wrong in the derivative.

**7. Count your branches before designing around them.** Five exits were documented as
four, the sixth case was not documented at all, and it is the only one that appears.
All six turned out to have zero incidence on the production driver, which converted a
suspected blocker into a two-line branch. A counter behind an environment variable is
cheap and it is the difference between designing for the model and designing for a
worry.

**8. Say whether a switch is a kink you mean.** C1's gate may be exactly the intended
biology — a plant with negative carbon balance does not grow. The point is that it
should be a recorded decision rather than an artefact of writing an `if`.

---

## 10. Implementation order

**The live work list is `../archive/build-plan.md` §5–§6; this is the report's own reading, kept as its
conclusion.** Two of the steps below have since landed on `aornugent/plant#66` as Phase 0: step 3
(`set_shutdown_state`, as P0.2), and step 5 is moot — report 01 §11.1 found `ode_util.hpp` already
includes XAD at the `854a8e18` baseline, so no include is owed.

1. **Land the section 4 counters behind an environment-variable gate.** They are cheap,
   they converted a suspected blocker into a measured non-event, and they are the
   mechanism for C1's and C2's incidence questions.
2. **Polish the collar argmax** (§6.5), and loosen golden section to the Newton basin
   with it. At `GSS_tol_abs = 1e-3` this is the difference between a 3.5% error and an
   exact derivative, so it is a prerequisite rather than a refinement. It changes
   `soil_consumption_` at first order in the displacement, so it needs a baseline
   re-bless.
3. **Fix `set_shutdown_state`** on develop (section 3.5). A forward-model correctness
   fix, independent of AD.
4. **Extend `photo_temp_cached_`'s key** to include `vcmax_25` and `jmax_25`.
5. **Add the `xad::value` include to `odelia/ode_util.hpp`** so develop's plant builds
   against the installed odelia without a workaround.
6. **Build the node for the interior branch only**, with the boundary branch raising a
   loud stop. Section 4 says the production driver never reaches it, so this is a usable
   intermediate state and the stop makes the untested path unreachable rather than
   silently wrong. Order within it: the envelope row (§6.1) and the explicit flux rows
   (§6.2), then `b` from its closed form and `a` recovered (§6.3), then the two
   translation-defect terms (§6.6). §6.9's three invariants gate each step.
7. **Add the boundary branch** and verify against a deliberately dried driver where
   section 4 shows it fires.
8. **Count C1's gate crossings and C2's kink incidence**, then decide whether either
   needs treatment.

---

## 11. What would falsify this

- **`profit_` is not always the objective at its own maximiser.** Any code path that
  sets `profit_` other than by evaluating `profit_psi_stem_TF` at the returned argmax
  breaks the envelope argument there. `set_shutdown_state` is one such path — it sets
  `profit_` directly. Section 4 says it is unreached in production; the enumeration
  should be completed rather than assumed.
- **Polishing does not recover exactness on the real leaf.** Section 7.2 establishes it
  on a toy objective with an analytic second derivative. TF24's objective is a composition
  through `find_psi_stem_from_psi_root`, so its stationarity condition is more expensive
  to Newton on, and whether two or three steps suffice is unmeasured.
- **The waist does not hold where it has not been measured.** §6.3's joint fit is at five
  and twenty layers, at three interior states, for two species. A state where the operating
  point sits near a bound, or where a layer crosses the equal-potentials branch, is
  untested — and there the two `E_up` derivatives are the first things to lose smoothness.
- **`a` recovered from one direction disagrees with `a` recovered from another.** §6.3
  measures the spread at 1e-05 or below over twenty layers. A state where it is not flat
  means the potential family is no longer rank one, and the second coefficient is then
  live in a direction the recovery assumes it is not.
- **The supplied Jacobian disagrees with a whole-tape recording of the same solve.**
  Record one leaf solve operation by operation at short lifetime, where the tape fits,
  and compare row by row. This is the direct test and it needs no full SCM run.
- **The counters show nonzero exit incidence on a realistic drought driver.** Section
  4's drought runs are degenerate — 280 steps from 2 153. A driver that dries the stand
  without killing it would settle whether the boundary branch is a corner case or a
  regime.
