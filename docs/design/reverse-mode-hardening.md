# Reverse-mode hardening: specification and handoff

**Read this first, build in the order given, and do not reorder without reading the gates.**

The reverse-mode census gradient is correct where it answers and has thirteen known defects. All
thirteen are root-caused and each one's reachability is measured. This document is the specification
for closing them and the handoff for the session that does it.

Reading: `plant` at `cdf3f0c9`, `odelia` and `phylloptim` as installed. Every number here was measured
on that tree unless marked *(corpus)*, meaning it comes from `docs/reports/00`–`09` or
`plant/notes/gradient-development-record.md`.

**Phases 0 and 1 have landed in the working tree, and Phase 2's instruments with them. All of it is
uncommitted.** Start by reading §3 for what each phase did and what it deliberately did not do.
**The Phase 3 gate is now satisfied** — its two numbers are in §3's Phase 2 and §6. What remains in
Phase 2 is the two detectors that change which states answer, and they are listed there.

---

## 1. State of the tree

| | |
|---|---|
| what works | one species or many, birth-date coordinate, wet to moderately dry, interior optimum only |
| cost | **14.6× the forward run**, flat across L = 2/10/30/60; extrapolates to ~520 s at century scale against the cost memo's measured 463 s |
| where it stops | first non-interior operating point anywhere in the trajectory — refusal is metric-level and total, and since Phase 1 it is *returned* rather than thrown |
| what refuses | `pinned-dry-root-crit` under drought or any seasonal amplitude ≥ 0.5; `shade-death` at leaf temp 45 °C; `infeasible-bracket` on an inverted interval |
| what is silent | seven of the thirteen defects below; five of the seven are closed by Phases 0 and 1 |

**Build with the working tree, never the installed package.** The installed `plant` segfaults inside
`census_trait_gradient_tf24`. Load with `library(odelia)` then `pkgload::load_all("plant")`.

---

## 2. The thirteen defects

Ordered by severity, which is not the order of the work — see §3 for that.

**Status** marks what Phases 0 and 1 have closed in the working tree; everything unmarked is open.

| # | defect | status | root cause | reachable at | silent |
|---|---|---|---|---|---|
| 1 | FD probe crosses a feasibility boundary | **closed** | one entry point serves two consumers; `evaluate_root_collar_psi` clamps by design for the acclimating FD, wrongly for a frozen-collar partial | **production drought** — guaranteed at any pin | yes |
| 2 | no amplification ceiling | open | the guard tests the curvature's **sign**; the divergence is in its **magnitude** | `stem_c` 2.68 → 0.6 — **4.5×, a search reaches this** | yes |
| 3 | forward tangent non-finite | **closed** | boundary node carries `log(birth_rate·pr_estab) = −Inf`; the tangent works in `ℓ` where the sweep works in `n` | any stand where establishment fails | yes |
| 4 | clamp severs a row | counted, not yet refused | the floor clamps at the **read**; the field stores values to 1e-117 underneath | `k_I` 0.5 → 40 — **80×** | yes |
| 5 | ambiguous exact zeros | **closed** | three correct zeros, three different causes, no way to say which | every run | yes |
| 6 | non-finite input poisons the value | **closed** | the graft guards its derivatives, not its inputs | latent; widens with the pinned branch | yes |
| 7 | ghost cohort | **closed** | `check_birth_dates_distinct()` is called on the seeding path, never the scheduled one | any duplicated schedule time | yes |
| 8 | refusal misnamed | half — names split, cause split open | one tag covers a dry plant and a broken parameterisation; `GSS_tol_abs` has two defaults | `root_psi_crit` below `root_zero_E` | partly |
| 9 | pinned refusal | half — arm named, bounds still discarded | the bounds are locals, discarded; `PinnedDry` never said which arm | **production drought** | no |
| 10 | raw error escapes | **closed** | no refusal channel exists in C++ | every failure above | wrongly |
| 11 | forward run dies | upstream | real, and **already largely fixed** upstream *(corpus: #599 went 17/40 → 5/40)* | did not fire in 14 runs | no |
| 12 | resource | other branch | the forward `O(K·N)` field build, inherited by the sweep's replay | every multi-species run | no |
| 13 | build provenance | open | header changes move no `.cpp` timestamp; storage-class flags must pair | any rebuild | varies |

**Two of these need no work here.** #11 is upstream and mostly closed. #12 is a forward-model cost shape
with the running-sums reduction already in flight on another branch — the reverse RHS is *sub*-linear in
species (0.0130 / 0.0232 / 0.0352 s at 1/2/3 species).

---

## 3. Build order

**Each phase makes the next observable. The gates are not optional.**

### Phase 0 — unconditional, no design needed — **LANDED, uncommitted**

All four are in the working tree of `plant` and `phylloptim`. No regression: the same 7 pre-existing
failures before and after, every pass count identical, and the gradient structure tier clean at 165
assertions. Each was checked live rather than assumed.

1. **Call `check_birth_dates_distinct()` on the scheduled path.** Done — `patch.h`,
   `introduce_new_nodes`. The guard's message now names the repeated time. Fixes #7.
   *Live:* a schedule carrying 0.5 twice now stops, naming `0.500000`, where the same schedule with
   distinct times runs. That it was **silent** before is not re-measured here — it rests on the two
   pre-existing call sites both being seeding/resume paths, and on §7's bit-identity measurement.
2. **Test the graft's inputs for finiteness** in `record_with_derivatives`, beside the existing
   derivative test. Done — `tf24_strategy.h`. Fixes #6.
   **No liveness evidence.** Nothing in the suite reaches a non-finite graft *input*; the defect was
   found by reading, and the containment that has kept it latent is a Boost throw one level down,
   which is defect #10. Treat this as an unexercised guard until Phase 2's counters can say otherwise.
3. **Split `GSS_tol_abs`** into a solver tolerance and a degeneracy threshold. Done —
   `phylloptim::Leaf` now carries `collar_interval_min_width` for `prepare_collar_solve`'s
   interval-collapsed test, and `GSS_tol_abs` keeps only the off-path single-layer optimisers.
   Half of #8. **The split is behaviour-preserving on purpose** — the full constructor initialises
   the new member from the old argument, so all 576 golden operating points are bit-identical, and
   **the value is a Phase 2/3 decision, not a Phase 0 one** (§6.4).
   *Also removed:* `TF24_Strategy`'s five dead tolerance members — `newton_tol_abs`, `GSS_tol_abs`,
   `vulnerability_curve_ncontrol`, `ci_abs_tol`, `ci_niter`. Every one was declared, copied through
   the rebind, and never read; four shadowed a `control.*` of the same name that *is* read, at a
   different default (`ci_abs_tol` 1e-6 against the control's 1e-3, `GSS_tol_abs` 1e-3 against 1e-1).
   A reader would take the tighter number for the one in force. `newton_tol_abs` had no live
   counterpart anywhere in the package.
4. **Seed the forward tangent in `n`, not `ℓ`,** at the boundary node. Done —
   `node.h`, `compute_initial_conditions`. Fixes #3 — and this **restores the reference** in the only
   regime where nothing can currently check the sweep.
   *Live, and it reproduces §7's figure:* at a boundary density of exactly zero the forward RHS
   Jacobian was **594/1089 = 54.5% non-finite** and is now **0/1089**, with the log density's value
   unchanged at −Inf either way. The mechanism is that `log()` reaches −Inf from an exact zero
   through 0/0, so it recorded a NaN derivative beside a correct value.

### Phase 1 — the status channel — **LANDED, uncommitted**

```
census_trait_gradient  ->  { gradient[m][t], status[m][t], refusal[m] }

status := answered
        | zero(slack | structural | UNDECLARED)
        | refused(reason, species, node, step_first, step_last)
```

Fixes #5 and #10. Built as `plant/inst/include/plant/gradient_status.h` — `gradient_status`,
`gradient_refusal` and `census_gradient`, the last being the pair the sweep returns so that a bare
row of numbers is not expressible.

**A fourth zero kind, `zero-undeclared`, is not in the original grammar and is the point of the
change.** An exact zero is the signature of a missing accumulator far more often than of a true
insensitivity, so resolving every zero into *slack* or *structural* would replace one ambiguity with a
confident wrong answer. A zero with no declared reason is marked as a finding instead.

**How refusal travels.** The fifteen `util::stop("TF24 gradient: …")` sites throw `gradient_refusal`
instead. The block loop in `patch.h` catches it to attach the species and node — the leaf knows the
reason and not which plant — and `census_trait_gradient` catches it to attach the recorded-step range
and turn it into a status. `util::stop` is kept for a *caller* error (an unknown metric index, the
wrong coordinate): those are not refusals and must still be errors.

**A refusal ends the arithmetic and not the loop.** The narrowing the sweep does per segment is
bookkeeping the width restoration at the tail depends on, so it runs on every segment whether or not
there is still a gradient to compute. Returning early there leaves the patch narrowed and the object
no longer repeatable.

**The declaration is keyed by name, not by position.** `ad_parameter_zero_classes()` derives from
`ad_parameter_names()` by name, so it cannot become a third positional list of 47 paired by index with
no guard. It is consulted only where the number is exactly zero, which is what keeps it honest as the
census grows: a parameter that becomes live stops being zero and its declaration is never read.

*Live, all four measured on a run:*

| | |
|---|---|
| wet stand | every entry `answered`, no refusal |
| drought (constant rain 0.25, L = 10) | every entry `refused` and `NaN`, naming **species 1, node 79, steps 283–305** — where before a raw error reached the R prompt with no localisation at all |
| zeros at shipped defaults | 132 answered, 6 `zero-slack` (`psi_crit`, `root_psi_crit`), 3 `zero-structural` (`a_f3`), **0 undeclared** — exactly §7's three columns and no others |
| `rooting_depth_max` = 10 m | that column goes exactly zero and comes back **`zero-undeclared`**, so the state-dependent zero is visible rather than passing as an answer |

**One finding, and it is now guarded.** The ladder already carried an R-side declared-zero taxonomy
with the same two classes and the same members. Two statements of one list is the drift shape this
corpus keeps finding defects in, so `test-gradient-ladder-declared-zero.R` now requires the shipped
C++ declaration and the fixture's list to agree in both directions. **Fault-injected:** removing
`a_f3`'s declaration in C++ takes `zero-structural` from 6 to 0 and fails three assertions.

### Phase 2 — detectors, which are also the instruments — **PART LANDED**

**Landed: the instruments and their two numbers. Not landed: items 5 and 6, the two detectors that
change which states answer.**

The counters live on `TF24_Strategy` and are read off the *live* system, never `r_patch()` — that is a
snapshot the run copies out. They are deliberately outside `rebind_from`, because a block copies the
strategy per unit and discards it, so carrying the tally across would count the sweep's copies as well
as the run. R reads them with `census_operating_point_counts_tf24()`, `census_clamp_counts_tf24()` and
their `_names_` / `_clear_` companions; `test-gradient-incidence.R` pins both.

**§6.3 is measured. The classification tally, per run:**

| driver | solves | interior | pinned-dry-root-crit | gradient |
|---|---|---|---|---|
| default, lifetime 60 | 1,309,513 | **100%** | 0 | answered |
| constant rain 2.0, L = 10 | 361,220 | **100%** | 0 | answered |
| constant rain 0.25, L = 10 | 216,014 | 99.71% | **629 — 0.29%** | **refused** |

**Read the last row as the case for Phase 3.** Three tenths of one percent of the operating points
make every metric's gradient undefined, because refusal is metric-level and total. It also bounds
§6.2 from the other side: the cost of answering the pinned branch is that fraction times one analytic
bound row with no re-solve, so the rise §6.2 warns of is real in sign and very small in size.

**And it is not recoverable any other way.** The refusal message names the *first* non-interior point
and nothing about how many followed it, so before this counter there was no route to the share at all.

**§4's clamp incidence, for the one site instrumented — the light floor, which is defect #4's own
site.** Swept against `k_I`, holding everything else:

| `k_I` | 0.5 (shipped) | 5 | 20 | 40 | 80 |
|---|---|---|---|---|---|
| light floor fires | **0%** | 0% | 0% | **7.5%** | 11.5% |

That reproduces §7's "binds at `k_I ≈ 40`, 80× shipped" from an instrument rather than from a probe,
and both halves are asserted: a counter that never fires and one that always fires are equally
uninformative.

**What is left in Phase 2, and why it was not taken here.**

- **Item 5 (#1, FD arm branch-crossing)** and **item 6 (#2, the amplification ceiling)** both *add
  refusals*, so they narrow the answered set. They are correctness improvements and they change which
  states answer, so they want their own change with their own before/after incidence — which the
  counters above now make measurable.
- **Item 6 carries a structural half that is worth separating from its value.** The present guard
  refuses the whole leaf when the curvature is unusable, where the profit row is valid at a fold and
  only the uptake rows cease to exist. Refusing them as a pair throws away a surviving metric for
  nothing. That needs the two output kinds to be refusable independently, which is a larger change
  than a ceiling.
- **Item 7 is one clamp site of fifteen.** The other fourteen — the soil potential ceiling and
  residual floor, the conductivity clamp, the infiltration and rainfall `max(0, ·)`, the collar clamp
  of #1, the leaf-temperature clamp, the root vulnerability integral's ceiling — take the same
  `clamp_site` enum and the same counter; none is instrumented yet.
- **Item 8 (#8's cause and arm split) — LANDED.** `PinnedDry` is now `PinnedDryRootCrit` and
  `PinnedDryRootPsiCrit`, decided by a `DryBoundArm` recorded **where the `min` is taken**, because a
  `min` is the one operation that destroys what the consumer needs afterwards. The inverted-interval
  exit is now `InfeasibleBracket` rather than `HydraulicShutdown`: that is reporting the branch taken,
  which is free at the point of decision and unrecoverable after it — whether it is a dry soil or a
  parameterisation the model cannot represent is now a question the counter can answer instead of one
  the tag has to assume. The arm is reset beside the classification at the top of
  `prepare_collar_solve`, because it is written *later* than the kind is and would otherwise leave the
  previous plant's arm beside this plant's kind.

  *Measured, and it settles which bound row Phase 3 actually needs:* on the refusing run **all 629 dry
  pins are `pinned-dry-root-crit` and none is on the constant arm**. That confirms §7's "#9 — the
  arms" on a larger sample and with an independent instrument, and it means `bound_row(DryRootCrit)`
  is the one that matters while `DryRootPsiCrit`'s trivial `−1` row is **unreachable at shipped
  defaults** — so §5's demand for a deliberately-lowered fixture is not optional, it is the only way
  that arm is ever exercised. The 576-point golden grid agrees: zero on that arm at both
  temperatures, and bit-identical through the split.

### Phase 2 — the original specification

5. **#1 detection:** compare `operating_point_kind()` and the returned collar across each FD arm; on a
   change, `refused(branch_crossed, …)`.
6. **#2:** the amplification ceiling on `|s|/|Π_pp|` — refuse the uptake rows, **emit the profit row
   regardless**, it is valid at a fold.
7. **#4:** an incidence counter at each of the fifteen clamp sites.
8. **#8, second half:** widen `OperatingPointKind` so X splits by cause and K splits by arm.

> **GATE.** Do not start Phase 3 until the Phase-2 counters have run on a production trajectory. They
> produce the three numbers §6 lists as unknown, and two Phase-3 decisions depend on them.

### Phase 3 — answer the pinned branch

9. **`profit_at_fixed_collar`** (§4.1). **This is item zero of Phase 3 and nothing else in it is safe
   first.** — **LANDED**, and it closed #1 with it.

   `Leaf::profit_at_fixed_collar(collar)` returns `{profit, uptake, feasible}` with no clamp and no
   projection, and **does not evaluate** an infeasible collar. `seat_at` in `record_leaf_outputs` now
   goes through it, so **the feasibility flag is the detection** — which is a better instrument than
   Phase 2 item 5's proposed comparison of `operating_point_kind()` across arms, because it is the
   condition itself rather than a proxy for it.

   *Measured, and it reproduces §7's figure to four significant figures.* At ψ_soil 5.0 the collar is
   held 2.6e-07 off the wet bound while a 1e-3 step in `root_b` moves that bound by 2.3e-06 — so one
   arm crosses. The clamped route silently reseats and returns `dprofit/droot_b` = **184.699**, against
   **0.00564** for the same difference well inside the interval. Both finite; a factor of 33,000 apart.

   *Incidence of the change:* no new refusals on either run that previously answered. The refusing
   drought run now stops at the crossing (node 78) rather than at the interior gate (node 79).
10. **Euler-derived accessors** (§4.2), checked by the identity in §5. — **LANDED.**
    `Leaf::stem_curve_integral_dstem_b(psi)` returns `(G − ψG′)/b` with **no spline rebuild**, and is
    bound to R alongside `stem_curve_integral` and `_deriv` so the homogeneity it rests on can be
    refereed from outside C++. `phylloptim/tests/testthat/test-stem-curve.R` (92 assertions) carries
    three checks at scales 0.75, 1.0 and 1.4: a scaled spline reproduces a **rebuilt** one to 4.4e-16
    in value, the Euler identity holds to **1.9e-16**, and the row agrees with a **rebuilt central
    difference** to **6.7e-09**. `stem_c` is untouched and keeps rebuild-and-difference.
11. **`bound_row(Wet)`**, then **`bound_row(DryRootCrit)`** (§4.3).
12. **The `proportion_of_conductivity_kernel` overload** (§4.4), closing the zero-flux pieces.
13. **The branch-dependent graft mask** (§4.5), then `Determined`.
14. **The parity test** (§5) as the acceptance gate.

### Do not

- **Do not delete the interior gate** at `gradient.hpp:1162`. It is correct, and it currently does
  double duty — it also keeps the FD probes away from the feasibility discontinuity. Removing it before
  §4.1 lands makes #1 a production path.
- **Do not answer `HydraulicShutdown` before #8's cause split.** The same tag covers a dry plant and a
  parameterisation the model cannot represent; answering it as it stands returns a trait error as though
  it were drought.
- **Do not mollify the feasibility branches.** They are model, not artefact *(corpus: report 06 §7 —
  a pinned plant is drought; report 05 §5.3 — mollifying establishment would be actively harmful)*.
- **Do not keep `SolverRefused` or `NonFiniteGradient` answerable.** No plant is described.

---

## 4. Specifications

### 4.1 `profit_at_fixed_collar` — required before any pinned work

Each FD arm in `record_leaf_outputs:1236–1258` reads back three quantities after `seat_at`:

```cpp
seat_at(radiation_value, psi_value, kmax_value);
  p_up    = leaf.profit_;                            // frozen-collar PROFIT partial
  m_up    = leaf.dprofit_droot_collar_psi(collar);   // ARGMAX channel
  u_up[i] = leaf.soil_consumption_[i];               // frozen-collar UPTAKE partial
```

`seat_at` calls `evaluate_root_collar_psi`, which re-runs `prepare_collar_solve` at the perturbed state
and clamps: `opt_root_psi = min(max(target, bound_a), bound_b)` (`leaf_model.hpp:2279`). The bound rows
of §4.3 replace only the **middle** read. The other two still clamp — and at a pin the collar *is* the
bound, so the clamp fires on essentially every arm.

Split the two consumers:

```cpp
// Unchanged. Re-runs feasibility and CLAMPS. For the acclimating variant's own centred difference.
double evaluate_root_collar_psi(double target);

// New. Caller has established feasibility and wants a partial at a FROZEN collar.
// No clamp, no projection.
struct FixedCollarEval { double profit; std::vector<double> uptake; bool feasible; };
FixedCollarEval profit_at_fixed_collar(double collar) const;
```

`feasible = false` when the held collar lies outside the perturbed `[bound_a, bound_b]`. **Do not
evaluate anyway** — below the wet bound the profit algebra runs on a negative conductance and returns a
plausible number. The caller refuses the row when either arm reports infeasible.

### 4.2 The stem curve: one identity, two accessors

`eval_stem_curve` returns `scale · Ĝ(u/scale)` with `scale = stem_b / stem_b_spline_`. So with `s` the
scale and `Ĝ` the base spline:

```
G(ψ; b) = s·Ĝ(ψ/s)          homogeneous of degree 1 in (ψ, b)
```

Two exact consequences:

```
∂G/∂ψ = Ĝ'(ψ/s)            == stem_curve_integral_deriv(ψ)          [leaf_model.hpp:598]
∂G/∂b = (G(ψ) − ψ·G'(ψ))/b  Euler — needs NO spline rebuild
```

`stem_curve_integral_deriv` returns `Ĝ'(ψ/s)` with no visible `1/s`. That is correct: differentiating
`s·Ĝ(ψ/s)` gives `s·Ĝ'·(1/s)`. **`stem_c` has no such identity** — the header refuses it at
`perturb_stem_b` — so `stem_c` keeps the rebuild-and-difference treatment, which is also what report 05
§7.6 requires.

### 4.3 The bound rows

Both bounds are roots of residuals the leaf already evaluates:

```
bound_a = root_zero_E : root of  E_column_zero(x, ψ)                  [leaf_model.hpp:922]
root_crit             : root of  E_column(x, ψ, psi_crit)             [leaf_model.hpp:921]
                                 = E_up(x,ψ) − κ·[G(psi_crit) − G(x)]
```

`∂bound/∂u = −(∂R/∂u)/(∂R/∂x)`. For `root_crit`:

| term | expression | source |
|---|---|---|
| `∂R/∂x` | `∂E_up/∂x + κ·G'(x)` | `dE_from_soil_dpsi_collar:872` + §4.2 |
| `∂R/∂ψ_j` | `∂E_up/∂ψ_j` | `dE_from_soil_dpsi_soil:901` |
| `∂R/∂rc_k` | `Σ_i ∂E_i/∂rc_k` | `duptake_droot_carbon`, `roots.hpp:756` |
| `∂R/∂κ` | `−[G(psi_crit) − G(x)]` | `stem_curve_integral` |
| `∂R/∂psi_crit` | `−κ·G'(psi_crit)` | §4.2 |
| `∂R/∂stem_b` | `−κ·[∂G/∂b(psi_crit) − ∂G/∂b(x)]` | Euler |
| `∂R/∂stem_c` | differenced with rebuild | no identity |

`bound_a` is the same on `R₀(x) = E_up(x,ψ)`, with `∂R₀/∂x = ∂E_up/∂x` and **no stem terms at all.**

```cpp
struct BoundRow {                      // leaf's declared input order, name-driven
  double d_dpsi_soil[L], d_droot_carbon[L];
  double d_dkappa, d_dpsi_crit, d_dstem_b, d_dstem_c;
  double residual_slope;               // ∂R/∂x — the IFT denominator AND the guard
  bool   finite;
};
BoundRow bound_row(WhichBound) const;  // Wet | DryRootCrit | DryRootPsiCrit
```

`DryRootPsiCrit` is zeros except its own parameter `= −1` and `residual_slope = 1`.

**`∂R/∂x = ∂E_up/∂x + κ·G'(x)` is a sum of two strictly positive terms**, so the denominator cannot
change sign. It can approach zero in deep drought, so guard on the amplification, not the sign — the
same ruling as #2, one level down. `residual_slope` is returned so the consumer can do this without
recomputing.

**Convention, enforced on the producing side.** Name-driven from the leaf's own input list, with a hard
stop on a name that cannot be mapped — never positional. Units are the leaf's: ψ in positive MPa, uptake
in mol, flux derivatives in kg, so the caller applies the existing `to_mol_flux` exactly where it does
today. Intensive, per unit leaf area; the leaf cannot check this, so assert it caller-side.

### 4.4 The seven pieces

| piece | operating point defined by | rows |
|---|---|---|
| Interior | `∂Π/∂p = 0` | envelope + IFT — **already built** |
| PinnedWet | `p = bound_a` | `∂bound_a/∂u` |
| `PinnedDryRootPsiCrit` | `p = root_psi_crit` | exactly `(0,…,0,−1)` — **unreachable at shipped defaults** |
| `PinnedDryRootCrit` | `p = root_crit` | `∂root_crit/∂u` — **every dry pin measured is this one** |
| Determined | `p = ½(bound_a + bound_b)` | ½ of both, then `find_psi_stem_from_psi_root` (§4.6) |
| HydraulicShutdown | stem at `psi_crit`, zero flux | env rows **exactly zero**; trait rows closed form |
| ShadeDeath | `ci = Γ*`, zero flux | as above |
| *(Prescribed — TF24f)* | an ODE state | free from the adjoint |
| SolverRefused, NonFiniteGradient | no plant described | **refuse** |

Pinned rows: `w = λ_Π·marginal + s`, `ū = v̄ᵀ∂f/∂u + w·∂B/∂u`. The multiplier `marginal` is already
computed at `tf24_strategy.h:1013` and discarded at 1338.

Zero-flux rows: `profit = −R_d − C(psi_crit)` reads neither soil nor light, so every environment and
uptake row is exactly zero. `∂C/∂psi_crit` needs no derivation — `hydraulic_cost_TF_kernel` is
scalar-templated (`leaf_model.hpp:1039`) and the file already does this at four sites:

```cpp
AD ps_ad = psi_crit;  xad::derivative(ps_ad) = 1.0;
const double C_prime = xad::derivative(hydraulic_cost_TF_kernel(ps_ad));
```

For `stem_b`/`stem_c` through `C`, add the overload the file's own precedent uses
(`assim_colimited_kernel(T ci, T vcmax, …)`):

```cpp
template <typename T> T proportion_of_conductivity_kernel(T psi, T b, T c) const;
```

### 4.5 The graft mask is branch-dependent

`lt_zero_at_interior` (`tf24_strategy.h:1208`) becomes a function of the classification:

| piece | `psi_crit` | `root_psi_crit` | env rows | uptake rows |
|---|---|---|---|---|
| Interior | 0 (slack) | 0 (slack) | envelope | IFT on `∂Π/∂p` |
| PinnedWet | 0 | 0 (slack) | `∂Π/∂u + ν·∂B/∂u` | `∂E/∂u\|_p + (∂E/∂p)·∂B/∂u` |
| `PinnedDryRootCrit` | **live** `−κG'(psi_crit)/R_x` | 0 | as above | as above |
| `PinnedDryRootPsiCrit` | 0 | **live** `−1` | as above | as above |
| Determined | live via both | live via `bound_b` | via `∂p/∂u` | via `∂p/∂u` |
| Shutdown / ShadeDeath | **live** `−C'(psi_crit)` | 0 | **exactly 0** | **exactly 0** |

### 4.6 `find_psi_stem_from_psi_root`, needed by `Determined`

`ψ_stem = G⁻¹(w)`, `w = E_up(p,ψ)/κ + G(p)`:

```
∂ψ_stem/∂• = stem_curve_integral_inverse_deriv(w) · ∂w/∂•
∂w/∂p = (1/κ)·∂E_up/∂p + G'(p)      ∂w/∂ψ_j = (1/κ)·∂E_up/∂ψ_j
∂w/∂κ = −E_up/κ²                     ∂w/∂b   = ∂G/∂b(p)
```

This chain is already assembled inline at `leaf_model.hpp:2405–2406`. Lift it to an accessor.

---

## 5. Verification

**Four rungs, ordered by what each can fail without a reference gradient.**

1. **Euler.** `ψ·G'(ψ) + b·∂G/∂b = G(ψ)` to round-off, everywhere on the spline's domain. An identity —
   fails only if the scaling convention is misread, which is the plausible mistake.
2. **Transpose identity.** `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` over the bound rows for random `v, u`. No reference, no
   differencing. It already holds to `1.4e-14` over 294 operating points for the existing node.
3. **IFT vs rebuilt difference.** Per input family, against a central difference of `find_root_psi` with
   the strategy rebuilt at `fit_step = 1e-3`. The only check that can referee `stem_c`.
4. **Parity — the acceptance gate.** *For every state the forward model returns a number for, the
   reverse returns a row or names a violated constraint.* Sweep a driver across the regimes; require
   `stand_gradient` to answer wherever `run_scm` answered.

**Fault injections, each of which must be caught:**

| injection | expected | run? |
|---|---|---|
| drop `κ·G'(x)` from `∂R/∂x` | rung 3 fails, rung 1 passes | not yet |
| swap the two dry arms | rung 3 fails on the constant arm | not yet |
| omit the `1/b` in Euler | rung 1 fails immediately | **run — rung 1 goes to 1.8–4.2 relative** |
| return `Ĝ'(ψ/s)·(1/s)` for `∂G/∂ψ` | ~~rung 1 fails~~ **rung 1 is exactly blind; rung 3 catches it at 40–47×, and only at a non-unit scale** | **run** |

**The last row was wrong in the specification, in two ways, and both matter.**

*Rung 1 cannot see it.* `∂G/∂b` is built from `G'`, so an error in `G'` cancels out of
`ψG' + b·(G − ψG')/b = G`. Injected, rung 1 reads **exactly 0.00e+00** while rung 3 reads **47×**.
An identity assembled from the quantity it is meant to check is not a check on it.

*And it is unreachable on a fresh leaf.* `stem_b == stem_b_spline_` on any newly built leaf, so the
scale is exactly 1.0 and dividing by it is the identity — the misreading is **invisible** until
something has moved `stem_b` without rebuilding. Injected, the same fault reads 3.4e-09 (clean) at
scale 1.000 and 47× at scale 0.750. **Every fixture testing the stem curve must perturb `stem_b`
first**, and `phylloptim/tests/testthat/test-stem-curve.R` does.

**Non-vacuity.** A fixture must be asserted to pin, and to pin on the arm under test. `root_crit` binds
100% of production states, so the default fixture tests only that arm — **a second fixture with
`root_psi_crit` deliberately lowered is required** to exercise the constant arm at all.

---

## 6. Unknown — measure, do not assume

Four numbers gate decisions and none is derivable.

1. **The amplification ceiling's value** (#2). Sizing it needs a sweep of `p` across the whole feasible
   interval at states a trait search reaches — a sample about solved operating points cannot falsify a
   fold, because the second-order condition already forces `Π_pp ≤ 0` there.
2. **Cost after Phase 3.** It will **rise**, not fall: pinned points are not differenced today, they
   throw, so answering them adds work. Bounded by (pinned fraction) × (one analytic bound row, no
   re-solve) against a 14.6× baseline. This is a kill condition for the phase. **The pinned fraction
   is now measured at 0.29% on a refusing run**, so the bound is small — but the *ceiling* still has
   to be checked against a run, because that fraction is one driver's.
3. ~~**Clamp and classification incidence.**~~ **Measured — see Phase 2 above.** Classification: a
   refusing production run is **99.71% interior and 0.29% pinned-dry**, and that 0.29% costs the whole
   gradient. Clamp: the light floor fires **0% at shipped `k_I` and 7.5% at `k_I` = 40**. Fourteen
   clamp sites still carry no counter.
4. **What `collar_interval_min_width` should be.** Phase 0 split the name; the value is still the
   `1e-1` `plant::Control` delivers. Below that width `prepare_collar_solve` stops optimising and
   substitutes the interval's midpoint, which is what decides whether a state is reported as
   `Determined` rather than optimised — a classification decision taken on a width, which is the same
   hazard as classifying on a residual, one level out.

   **`Determined` has zero incidence on `phylloptim`'s 576-point golden grid**, at either leaf
   temperature: 198 interior / 42 pinned (24 wet, 18 dry) / 48 shutdown at 25 °C, and 160 / 80 (all
   wet) / 48 at 40 °C. So that grid cannot referee this threshold at all, and warming moves points
   between branches without ever producing one. A production trajectory is the only instrument.

   **Measured, at the leaf's default traits over a uniform soil profile:** the feasible interval's
   width falls monotonically as the soil dries — 3.30 at 0.01 MPa, 2.58 at 1, 1.26 at 3, 0.261 at 5 —
   crosses **1e-1 at ψ_soil = 5.50**, and is still **3.1e-3 at 5.84**, against the plant's own limit
   of 5.870. So the two candidate values disagree over roughly **the last 0.37 MPa before hydraulic
   shutdown**, 18 of 43 states sampled in that band. That is precisely the regime Phase 3 exists to
   open, so **do not set this before Phase 2's counters run**: tightening it moves states out of
   `Determined` and into the optimised branch, which changes results and needs a
   `scientific_version` bump and a re-bless.

---

## 7. Evidence

Compressed to what justifies a decision. Each is reproducible by §8.

**#1 — the FD probe.** Perturbing `root_b` by 1e-3 and holding the collar, exactly as the sweep does:
`dprofit/droot_b` reads **184.7** at ψ_soil 3.96 against 0.003 at both neighbours, and
`184.7 × 2h = 1.440` — exactly the feasibility discontinuity `leaf_model.hpp:2162` documents. At a pin
the collar is `bound_a + 1e-6·width` while a 1e-3 trait step moves the bound by 1.3e-4: a ratio of
**159–197**, so clamping is structural, not incidental.

**#2 — the fold.** Sweeping `p` across the whole interval at 240 points: `Π_pp` strictly negative at
every soil potential 0.5–5.5 with min abs 0.67, and strictly negative across `beta2` 0.2–6 and `stem_b`
3.9–10. At **`stem_c` = 0.6**, 8.7% of the interval has `Π_pp ≥ 0` and min abs = 0. `stem_c ≥ 5` and
`stem_b ≤ 2` fail the solve outright.

**#3 — the tangent.** `pr_estab == 0` ⟺ boundary `log_density = −Inf` ⟺ **50.2% of the forward RHS
Jacobian non-finite**, 6 configurations of 6, no exceptions. Every rate reading the light field is
non-finite; every rate not reading it is clean. Blocks, field values, field slopes and the reduction
adjoint are all finite. Not light: `k_I = 1.5` gives minimum light **0.054**, three times darker than a
failing case, with zero non-finite entries.

**#4 — the floor.** Binds at `k_I ≈ 40`; the field then stores 1.1e-17 and, denser, **5.1e-117**, while
the read clamps at 1e-4.

**#5 — the zeros.** Three per species. `a_f3` occurs only in `fecundity_dt`'s denominator and no census
metric reads fecundity; `psi_crit`/`root_psi_crit` are complementary slackness;
`rooting_depth_max` is zero at 0.30 m (saturated) and 10 m (non-binding), live between.

**#7 — the ghost.** A duplicated schedule time adds a node whose census, offspring, all 65 field knots
and soil state are **bit-identical** to the clean run, where a genuinely distinct extra node moves them
by ~3e-07.

**#9 — the arms.** `root_crit` binds **100% of 297 recorded states** across three drivers spanning
ψ_soil 0.01–4.23 MPa. `root_psi_crit` never binds at shipped defaults.

**#12 — the scaling.** Reverse RHS at 1/2/3 species: 0.0130 / 0.0232 / 0.0352 s — sub-linear.
`boundary_condition_adjoint` is 25–32% of it at every species count.

**Regime boundary.** Under constant forcing the gradient refuses from ψ_soil ≈ 4 MPa, against the
plant's own limit of 5.87. Under a seasonal driver there is no terminal-state threshold at all: at
amplitude 1.0 the profile finishes at 0.17 MPa — saturated — and still refuses, because the pin happened
in a trough the run recovered from. **Nothing about a completed run predicts whether its gradient
exists.**

---

## 8. Reproducing the measurements

```r
library(odelia); pkgload::load_all("plant")     # never the installed package

p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- 10
tr <- c(lma=0.0825, hmat=5.13, k_I=0.5, a_l1=5.44, a_l2=0.306)
p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                    hyperpar = TF24_hyperpar, birth_rate = list(1.10))
env <- Environment("TF24"); env$set_soil_water_state(rep(0.428*0.5, 5))
env$extrinsic_drivers_set_constant("rainfall", 0.25)      # refuses at L=10
scm <- run_scm(p, env, ctrl = Control(node_density_in_birth_date = TRUE))
stand_gradient(scm)
```

- **Soil potential from moisture:** `psi = 1.78e3 * (max(theta,1e-2)/0.428)^(-6.57) / 1e6`. The header
  comments these constants "not currently being used"; they are — `psi_from_soil_moist` and its inverse
  both read them. Ceiling `soil_psi_max_ = 1e3` MPa binds nowhere in range.
- **Leaf-level probes:** `leaf_model(traits=)`, `set_drivers`, `find_root_psi(wettest, psi, 0|1)`,
  `evaluate_root_collar_psi`, `dprofit_droot_collar_psi`. Trait fields are `stem_b`/`stem_c`, **not**
  `b`/`c` — R's partial matching silently resolves `tr$b` to `beta2`.
- **Ladder instruments:** `ladder_rhs_state_jacobian_forward_tf24`,
  `ladder_block_jacobian_forward_tf24`, `ladder_field_knots_tf24`,
  `ladder_light_reduction_adjoint_tf24`, `ladder_trajectory_tangent_tf24` (returns
  `list(value, tangent)`), `ladder_rhs_adjoint_timing_tf24` (per-phase breakdown).
- **Patch state layout:** 8 rows per node — `height, mortality, fecundity, area_hw, mass_hw, storage,
  offspring, log_density` — then 9 environment rows: 5 soil layers, then cumulative rain, infiltration,
  drainage, uptake.
- **Classification is not exposed to R.** Read it from the refusal message, which names the kind. That
  is why Phase 2's counters are the only route to incidence.

### The build and test loop, as it actually behaves here

- **Rebuild at `-O2` explicitly.** `pkgbuild::compile_dll()` appends `-O0` after any user flags.
  `R_MAKEVARS_USER=<file> Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'` with the file holding
  `CXX20FLAGS = -O2 -DNDEBUG -g0`. Confirm one compile line ends at `-O2` with no trailing `-O0`.
- **A `phylloptim` header edit is invisible to `plant` until `phylloptim` is reinstalled.** `plant`
  compiles against the *installed* library's headers via `LinkingTo`, not against the working tree, and
  no `.cpp` timestamp moves — so the build succeeds and runs the old model. `rm -f src/*.o src/*.so` in
  both, reinstall `phylloptim`, then rebuild `plant`. This is defect #13 met in practice.
- **`phylloptim`'s C++ suite needs `make -C tests/cpp CXX=g++`** — the Makefile's default reaches for a
  `clang++-12` that is not installed here.
- **`phylloptim`'s own R suite has pre-existing failures too**, measured against a stashed baseline:
  `test-gradient.R` (1 fail, 1 error), `test-gradient-batch.R` (4 errors), `test-surface.R` (1 fail).
  Its C++ `test_leaf` also aborts at HEAD. `test-golden.R`, `test-cost.R` and
  `test-temperature-response.R` are clean.
- **Seven test failures pre-exist at `cdf3f0c9`** and are not a signal: `test-strategy-tf24.R::Defaults`,
  `test-strategy-tf24f.R::Defaults`, and five in `test-leaf.r` (`Basic functions`, `Medlyn stomatal
  model`, `psi_stem_to_ci supply=demand solve`). `phylloptim`'s own `test_leaf` also aborts at HEAD on a
  single-potential series resistance of zero. **Establish the baseline before attributing anything.**
- **When attributing a failure, stash with `git -C <repo> stash`.** The shell's working directory
  persists between commands, so a bare `cd repo && git stash` followed by another `git stash` stashes
  the *first* repo twice and leaves the second untouched — which produces a "baseline" that still
  carries the change under test, and it agrees with itself perfectly.

---

## 9. Corpus corrections

Carry these forward; they change what a reader would do.

- **Report 09 §10's "first segment is never swept" does not reproduce at `cdf3f0c9`.** Sweep and
  trajectory tangent agree to ≤2.7e-09 with first introductions at 0.0 through 1.0, including 104
  recorded steps below the first event. The structural point survives: nothing asserts the segment
  ranges partition the recording.
- **Report 09 §12's inverted cost premise is stale.** 14.6× flat, not 162×.
- **The parameter count is 47, not the 44 every report states** *(report 09 §12 already flags this)*.
- **The development record's mode-3 discriminator is wrong.** It says "the rates that read `growth`";
  the soil rows are non-finite and read no growth. The discriminator is the light field.
- **`tf24_environment.h:62–63`** annotates `a_psi`/`n_psi` as "not currently being used". They are.
