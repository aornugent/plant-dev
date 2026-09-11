# phylloptim

**Base** `traitecoevo/phylloptim:master` · **Head** `aornugent/phylloptim:ad/V4-reverse-tf24`
**Tag on merge** `v0.9.0` · **Needs** odelia `v0.5.0` tagged first

## Title

Supply exact derivative rows for the leaf solve

## Body

The leaf picks its operating point by root-finding for the root-collar
water potential that maximises gain net of hydraulic risk. A consumer
differentiating this model had to record that search, which
differentiates the solver rather than the model: the answer depends on
the starting guess and the convergence tolerance.

`Leaf` is now templated on its scalar and supplies the derivative of the
operating point directly, from the implicit function theorem at the
converged point. The path is `supply_draw_at()` for the soil draw and
its collar response in one walk, `collar_at()` for the potential, then
`outputs_at()` for profit and uptake. `operating_point_kind()` reports
which of four residuals pinned the point; where no derivative exists the
call throws rather than returning a plausible number.
`vulnerability_curve_ncontrol` defaults to 400 rather than 100, so every
caller's numbers move.

Closes #

## First comment

Two files carry this — `leaf_model.hpp` (+1622) and `roots.hpp` (+443) — plus
three small new ones. Nothing is deleted. The walkthrough is the change.

### The solve, and where the derivative comes from

The leaf's operating point is the root-collar water potential at which marginal
carbon gain equals marginal water cost. `phylloptim` finds it by root-finding on
the marginal-profit function, in plain `double`, off any tape. That has not
changed and is not differentiated.

What changed is what happens next. Previously a consumer put the trait on its
tape and ran the root-find with the tape live, so the reverse walk carried a
derivative back through every iteration. That differentiates the solver: the
answer is the sensitivity of *wherever this particular sequence of iterations
stopped*, which depends on the starting guess, the tolerance and the iteration
count. It converges as the tolerance tightens, but at any finite tolerance it is
not the right answer, and its error is a property of the solver's settings
rather than of the model.

Now the leaf hands the derivative over instead, from the implicit function
theorem at the converged point. With the point `p*` defined by `F(p*, θ) = 0`:

```
    dp*/dθ  =  −(∂F/∂p)⁻¹ ∂F/∂θ        evaluated at p*
```

Both partials are of the residual, which is a closed form, so neither needs
anything the solver did. The error is then the residual's own distance from
zero — measured at 1.6 parts in a thousand million million of the answer.

### The path a consumer walks

```
   prepare_collar_solve()          resets kind to Unsolved, so a forgotten
        │                          branch reports "unclassified" rather than
        │                          the previous plant's answer
        ▼
   root-find over collar psi       plain double, off the tape
        │
        ▼
   which branch exited? ─────┬──► Interior            stationarity
        │                    ├──► BoundaryWet         uptake balance
        │                    ├──► BoundaryCrit        stem continuity at psi_crit
        │                    ├──► BoundaryRootCrit    root's own critical potential
        │                    └──► HydraulicShutdown / ShadeDeath
        │                              │                marginal profit returns a
        │                              │                HARD 0.0 here
        ▼                              ▼
   supply_draw_at(collar, supply)   no draw — collar is held past where
        │   ONE walk:                the uptake model answers at all;
        │   • per-layer uptake       asking costs a stop, not a wrong row
        │   • total flux
        │   • collar conductance
        ▼
   collar_at(draw, pars, curvature)      forms the implicit_value node
        │                                (skipped entirely at S == double)
        ▼
   outputs_at(collar, draw, pars)   ──►  LeafOutputs<S>{ profit, uptake[] }
```

**The kind is written by the branch that was taken, never inferred afterwards
from the numbers.** This is the sharpest thing in the diff to review.
`dprofit_at_collar_psi` returns a literal `0.0` on its shutdown exit
(`leaf_model.hpp:4021`), *before* setting the feasibility flag. So a
`|dprofit| ≈ 0 ⇒ interior` test reads a shut leaf as a stationary point — and
`marginal_collar_slope`, differencing that same sentinel, returns a curvature of
zero and agrees. Two diagnostics confirm each other and both are wrong. Twelve
sites write the kind; `test_operating_point_kind_is_written_by_every_path`
(`test_leaf.cpp:816`) holds them to it.

### Why the draw is one walk

`supply_draw_at` (`:1253`) returns the per-layer uptake, the total flux and the
collar conductance from a single pass over the soil layers. The comment at
`roots.hpp:712` gives the reason: *"THE COLLAR RESPONSE COMES OUT OF THE SAME
WALK OR NOT AT ALL... a second walk forming them again is a second spelling that
has to agree bit for bit."*

The layers are strictly parallel. Each contributes

```
    E_i = (T_collar − psi_soil[i] − grav_head[i]) / r_R_i
```

and they are coupled only through the shared scalar `T_collar`, so
`dE_up/dT_collar` is a plain sum of per-layer quotient-rule terms — which is why
it costs nothing to produce alongside the draw and would cost a whole second
walk to produce after it.

Two deliberate scalar choices inside `SupplyDraw`. The collar it was taken at is
stored **passive** whatever the caller hands in: this is the supply at a *point*,
and where the point itself moves is the supplied row's business — taking it live
would record the search that placed it. And the per-layer collar slopes are
supplied at `double`, because the draws already carry their own rows and what is
missing is only the channel through the collar moving.

### How a kernel's slope is taken without nesting scalars

`kernel_slope_at` (`:5573`) needs `dA/dci` and similar, at whatever scalar the
caller holds. The obvious route — an active scalar nested inside another — is a
compile error in odelia, and for a measured reason: the leaf's `dA/dci` and
`dC/dsigma` were once taken that way and cost 521 tape statements against the 17
of the kernel they differentiate.

Instead it builds `xad::fwd<tangent_scalar<double>, n_dir>` — **both levels at
`double`**, so nothing is recorded. The inner direction turns the value into a
slope; the outer walk yields one row per argument. Those rows go to
`record_with_derivatives`, which puts them on the consumer's tape as one
statement. The slope cannot disagree with the function, because it *is* a tangent
through it. At `S == double` the outer walk is skipped and only the inner level
runs.

This is why the kernels take the scalars they read rather than the twenty-slot
parameter pack: the cost is `n_dir` × the kernel's arithmetic.

### The hazard worth reviewing hardest

`odelia`'s `visit_active` dispatches on `for_each_active`, then container, then
pointer — and **falls off the end doing nothing** for an aggregate that matches
none of them. `PhotoCapacity` is an input to the `ci` residual's `implicit_value`
(`:5760`):

```cpp
  template <class F>
  void for_each_active(F&& f) const {
    f(vcmax); f(transport); f(curvature); f(respiration);
  }
```

Delete that member and the four photosynthetic rows never arrive. Four trait
columns read exact zero, every number stays finite, nothing is raised. The same
shape applies to `SupplyDraw` and `leaf_pars`: adding a member to any of the
three and not visiting it is a silent wrong answer, which is why the comment sits
at the declaration rather than at the call.

### The rest

**`vulnerability.hpp` and `closed_form_rows.hpp`.** Both curves take their value
from a pre-integrated table and their derivatives from the closed form. The value
is the table's because the solve ran on the table; the table's own slope is a
property of the fit rather than of the curve, so the two differ. One
implementation serves both curves, because written twice one copy picks up the
chain rule through the shape parameter and the other keeps a partial at fixed
scale — finite, plausible, wrong, and nothing reports it.

**`single_potential.hpp`.** Answers the same methods against one soil water
potential rather than a layered network. It exists because every model this one
is compared against is formulated that way, and comparing them under a
multi-layer root network compares two things at once.

**`clamp_sites.hpp`.** A tally of where values were clamped, on the principle
that *what is counted is not a defect: it is the distance from one.*

### Reading order

1. `clamp_sites.hpp`, `vulnerability.hpp` — 144 lines of small vocabulary.
2. `roots.hpp:357-383` — `SupplyAt`, `CollarConductance`; then `uptake_impl` at `:811`.
3. `leaf_model.hpp:1199-1253` — `LeafOutputs`, `SupplyDraw`, `supply_draw_at`.
4. `leaf_model.hpp:2023-2082` — `outputs_at`, `collar_at`, `bound_at`. The derivative surface.
5. `leaf_model.hpp:5573` — `kernel_slope_at`.
6. `closed_form_rows.hpp` last — 73 lines, and it reads better once the rest is in place.

### What to check it against

| claim | where |
|---|---|
| A point is classified by the exit taken, never by the numbers | `:4021` returns a literal `0.0` before setting `feasible` |
| Every path out of the solve writes its own rates | `test_leaf.cpp:816`. The one gap is documented at `:2431` — `optimise()` on the stem route leaves `Unsolved`, so `collar_at` throws rather than misreports |
| The draw and the collar it was taken at are the same point | `check_draw`, `:1331`, an exact `!=` |
| One tape statement per attachment, not one per row | `implicit_node.hpp:57` |
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
