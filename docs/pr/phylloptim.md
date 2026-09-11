# phylloptim

**Base** `traitecoevo/phylloptim:master` · **Head** `aornugent/phylloptim:ad/V4-reverse-tf24`
**Tag on merge** `v0.9.0` · **Needs** odelia `v0.5.0` tagged first

## Title

Supply exact derivative rows for the leaf solve

## Body

The leaf picks its operating point by root-finding for the root-collar
water potential that maximises gain net of hydraulic risk. A consumer
differentiating this model had to record that search, which
differentiates the solver: the answer it gets is the sensitivity of
wherever those iterations stopped, and depends on the starting guess and
the convergence tolerance.

`Leaf` is now templated on its scalar and supplies the derivative of the
operating point directly, from the implicit function theorem at the
converged point. The path is `supply_draw_at()` for the soil draw and
its collar response in one walk, `collar_at()` for the potential, then
`outputs_at()` for profit and uptake. `operating_point_kind()` reports
which of four residuals pinned the point; where no derivative exists the
call throws instead of returning a plausible number.
`vulnerability_curve_ncontrol` defaults to 400, not 100, so every
caller's numbers move.

Closes #

## First comment

`leaf_model.hpp` (+1622) and `roots.hpp` (+443) carry this, plus three small new
files. Four mechanisms are worth reading closely.

### The solve, and what replaces recording it

The operating point is the root-collar water potential at which marginal carbon
gain equals marginal water cost. `phylloptim` finds it by root-finding on the
marginal-profit function, in plain `double`, off any tape. That is unchanged and
is not differentiated.

Previously a consumer put the trait on its tape and ran the root-find live, so
the reverse walk carried a derivative back through every iteration. What comes
out is the sensitivity of *where that particular sequence of iterations stopped*,
a function of the starting guess, the tolerance and the iteration count. It
converges as the tolerance tightens; at any finite tolerance it is not the
model's derivative, and its error belongs to the solver's settings.

The implicit function theorem gives it directly. With `F(p*, θ) = 0` defining the
point:

```
    dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ        evaluated at p*
```

Both partials are of the residual, a closed form, so neither needs anything the
solver did. The remaining error is the residual's own distance from zero,
measured at 1.6 parts in a thousand million million of the answer.

### Which residual, decided by which branch exited

```
   prepare_collar_solve()              kind := Unsolved
        │                              a forgotten branch then reports
        │                              "unclassified", not the last plant's answer
        ▼
   root-find over collar psi           plain double, off the tape
        │
        ├──► Interior             stationarity of profit
        ├──► BoundaryWet          uptake balance at the wet bound
        ├──► BoundaryCrit         stem continuity at psi_crit
        ├──► BoundaryRootCrit     the root's own critical potential
        └──► HydraulicShutdown / ShadeDeath
                   │
                   └─ marginal profit returns a literal 0.0 here
        │
        ▼
   supply_draw_at(collar, supply)      one walk: per-layer uptake,
        │                              total flux, collar conductance
        ▼
   collar_at(draw, pars, curvature)    the implicit_value node
        │                              (absent entirely at S == double)
        ▼
   outputs_at(...)  ──►  LeafOutputs<S>{ profit, uptake[] }
```

The kind is written by the branch taken and never inferred afterwards from the
numbers, and the reason is specific. `dprofit_at_collar_psi` returns a literal
`0.0` on its shutdown exit (`:4021`), *before* setting the feasibility flag. A
`|dprofit| ≈ 0 ⇒ interior` test therefore reads a shut leaf as a stationary
point. Worse, `marginal_collar_slope` differences that same sentinel and returns
a curvature of zero, so a second diagnostic confirms the first. Twelve sites
write the kind and `test_operating_point_kind_is_written_by_every_path`
(`test_leaf.cpp:816`) holds them to it.

One residual is answered per kind, but there is only one formula. Fiacco's
statement needs no branch:

```
    dΠ*/du  =  ∂Π̂/∂u|_p  −  Σⱼ μⱼ ∂cⱼ/∂u|_p
```

At an interior optimum every multiplier is zero and this collapses to the
envelope theorem. At a bound the multiplier is exactly the correction the
envelope theorem omits.

### Why the draw is a single walk

`supply_draw_at` (`:1253`) returns per-layer uptake, total flux and collar
conductance from one pass. The soil layers are strictly parallel:

```
    E_i = (T_collar − psi_soil[i] − grav_head[i]) / r_R_i
```

Nothing couples them but the shared scalar `T_collar`, so `dE_up/dT_collar` is a
sum of per-layer quotient-rule terms and falls out of the same loop that
accumulates the draw. Forming it afterwards means walking every layer again to
produce numbers the first walk already had, and two spellings that must agree bit
for bit.

Two scalar choices inside `SupplyDraw`. The collar is stored **passive** whatever
the caller hands in: this is the supply at a *point*, and where the point itself
moves is the supplied row's business — taking it live records the search that
placed it. The per-layer collar slopes are supplied at `double`, because each
draw already carries its own rows and the only missing channel is the collar
moving.

At a hydraulic shutdown there is no draw at all, and not because it would be
zero. The collar is held at the stem's critical potential, past where the uptake
model answers: the integral is exactly zero and `E_up` is not a number. Asking
costs a stop. Every consumer reads zero at that kind anyway.

### `kernel_slope_at` supplies second derivatives

This one is easy to skim and worth not skimming. `kernel_slope_at` (`:5573`)
returns a kernel's *slope* as a value, carrying rows that are the kernel's
*mixed second partials*.

```cpp
  using inner = odelia::ode::tangent_scalar<double>;      // both levels
  constexpr std::size_t n_dir = 1 + sizeof...(Args);      // sit at double
  using outer = typename xad::fwd<inner, n_dir>::active_type;
```

Direction `d` of argument `d` is seeded to 1 at the outer level, giving `n_dir`
independent directions. Then the inner level of the **first** argument alone is
seeded (`seed_direction(xad::value(lift[0]), 1.0)`). The kernel is evaluated
once. Then:

```
    slope    = derivative_along(value(y))          =  ∂K/∂x
    row[r]   = derivative_along(derivative(y)[r])  =  ∂²K/∂x ∂argᵣ
```

So one evaluation at `n_dir` directions yields a first derivative and every
second derivative it needs, with nothing recorded at either level because both
are `double`. `record_with_derivatives` then attaches the lot as one tape
statement.

The alternative is an active scalar nested inside another, which `tangent.hpp:36`
refuses at compile time. The leaf's `dA/dci` and `dC/dsigma` were once taken that
way and cost 521 tape statements against the 17 of the kernel they differentiate.

At `S == double` the outer level is skipped entirely and only the inner tangent
runs, which matters because that is the path placing every operating point —
2.3 million of them in a century-scale stand run.

### A missing `for_each_active` costs four columns, silently

`odelia`'s `visit_active` dispatches on `for_each_active`, then container, then
pointer, and falls off the end doing nothing for an aggregate matching none.
`PhotoCapacity` is an input to the `ci` residual's `implicit_value` (`:5760`):

```cpp
  template <class F>
  void for_each_active(F&& f) const {
    f(vcmax); f(transport); f(curvature); f(respiration);
  }
```

Remove that member and the four photosynthetic rows never arrive. Four trait
columns read exact zero, every number stays finite, nothing is raised.
`SupplyDraw` and `leaf_pars` have the same exposure, which is why the warning
sits at the declaration and not at the call site.

### The vulnerability curves

Both take their value from a pre-integrated table and their derivatives from the
closed form. The value comes from the table because the solve itself ran on the
table; the table's own slope is a property of the fit, not of the curve, and the
two differ.

One implementation serves both curves. Written twice, one copy picks up the chain
rule through the shape parameter and the other keeps a partial at fixed scale.
The result is finite, plausible and wrong, and nothing in the output says so.

### `single_potential`

Answers the same methods against one soil water potential instead of a layered
network. Every model this one is compared against — Medlyn, least-cost,
Cowan–Farquhar — is formulated that way, so comparing them under a multi-layer
root network compares two things at once.

### Reading order

1. `clamp_sites.hpp`, `vulnerability.hpp` — 144 lines of vocabulary.
2. `roots.hpp:357-383` — `SupplyAt`, `CollarConductance`; then `uptake_impl` at `:811`.
3. `leaf_model.hpp:1199-1253` — `LeafOutputs`, `SupplyDraw`, `supply_draw_at`.
4. `leaf_model.hpp:2023-2082` — `outputs_at`, `collar_at`, `bound_at`. The derivative surface.
5. `leaf_model.hpp:5573` — `kernel_slope_at`.
6. `closed_form_rows.hpp` — 73 lines, and it reads better once the rest is in place.

### What to check it against

| claim | where |
|---|---|
| A point is classified by the exit taken, never by the numbers | `:4021` returns a literal `0.0` before setting `feasible` |
| Every path out of the solve writes its own rates | `test_leaf.cpp:816`. The documented gap is `:2431` — `optimise()` on the stem route leaves `Unsolved`, so `collar_at` throws instead of misreporting |
| The draw and the collar it was taken at are the same point | `check_draw`, `:1331`, an exact `!=` |
| One tape statement per attachment, whatever the row count | `implicit_node.hpp:57` |
| A supplied row cannot be refereed by differencing the step that consumes it | the block's forward value does not depend on a recorded input, so differencing gives identically zero on exactly those columns whether the row is right, wrong or absent |

### File inventory

| file | lines | what it is |
|---|---|---|
| `leaf_model.hpp` | +1622 | `Leaf<S>`, `leaf_pars<S>`, `SupplyDraw`, `PhotoCapacity`, `LeafOutputs`, `OperatingPointKind` |
| `roots.hpp` | +443 | `SupplyAt`, `CollarConductance`, the merged uptake walk |
| `gradient.hpp` | +113 | the `par_*` enumeration moves here; `n_theta` replaces `n_pars` |
| `vulnerability.hpp` | +76 | `weibull_b_from_P50`, `vulnerability_derivatives_at` |
| `closed_form_rows.hpp` | 73 | new |
| `clamp_sites.hpp` | 68 | new |
