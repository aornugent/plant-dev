# Census gradients through the growing SCM: geometric compression

**What.** How `plant` takes correct reverse-mode gradients of **census functionals** —
stand-level moments of the size distribution (offspring production, biomass, basal area,
LAI) — with respect to strategy trait parameters, through the growing multi-cohort K93
Solve-by-Characteristics-Method (SCM).

**The design in one sentence.** Discretise the density-transport term `∂ₓg` with the
**same neighbour-difference operator that the competition quadrature already uses**, so
its two appearances in the discrete model become the *same expression* and their
parameter-derivatives cancel on the reverse-mode tape — turning an `O(1)` census-gradient
error into a machine-exact gradient.

This is gated behind `control$node_geometric_compression` (default `FALSE`) and applies
to the forward-mode-instantiable strategies (K93 today). The rest of this document is the
derivation of why that is the correct and sufficient form.

---

## 1. The functionals and the failure

Every census/fitness output the SCM produces is a **moment** of the size density `n(x,t)`:

```
M = ∫ φ(x) n(x, T) dx           (and time-integrated variants)
```

with `φ` chosen per output (φ = 1 for number, φ = mass(x) for biomass, and the
competition/light field is itself a moment). These are the quantities we differentiate
with respect to traits `θ` (`b_0`, `b_1`, `k_I`, …).

Reverse-mode AD of `M` through the SCM was **internally consistent** — forward-JVP equal
to reverse-VJP to machine precision, values bit-identical to the primal run — and yet
disagreed with a converged central finite difference of the model-as-run by an **`O(1)`
factor** on any functional that reads the compression term `∂ₓg`. The disagreement did
not shrink with the finite-difference step; it was not a step-size artifact. The
signature, on the Gate-1 harness (`size_sum` over a two-cohort K93 stand):

| parameter | reverse-mode AD | converged FD | status |
|-----------|-----------------|--------------|--------|
| `b_0`     | 318.7           | 319.4        | ~0.2% (fine) |
| `k_I`     | **−27.1**       | **0.144**    | wrong sign, ~190× |

The error was concentrated **entirely in one term** — the coupling/compression `∂ₓg` — and
in the parameters that reach the census only through it (the coupling parameters such as
`k_I`). Parameters that move the trajectory directly (`b_0`, `b_1`) were already close.

## 2. The system

The resident stand is the McKendrick–von Foerster transport (conservation) law, solved by
the method of characteristics:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, E; θ) · n ] = − r(x, E; θ) · n ,        x > x_b
```

- `x` is size (height); `n` the density over `x`; `g` the growth rate (characteristic
  velocity); `r` the mortality rate.
- **Coupling field** `E` — the light/competition environment — is a one-sided aggregate
  of the whole distribution: `E(z) = ψ(∫_{x ≥ z} κ(z,x;θ) n(x) dx)`. Only taller
  individuals shade a given height, and the crown kernel `κ` vanishes on the diagonal
  (`κ(z,z) = 0`). `g` and `r` read `E`, so the stand shades itself.

**Discretisation (the SCM).** The distribution is a set of characteristics `xᵢ(t)`, each
advected by `dxᵢ/dt = g(xᵢ, E(xᵢ))` and carrying a **log-density** `ℓᵢ` that obeys

```
dℓᵢ/dt = − ∂ₓg − r                       (the density-transport ODE)
```

New characteristics enter at the birth boundary `x_b` on an adaptive schedule, so the set
grows over the run. Moments are evaluated by **trapezoidal quadrature over the
characteristics**: e.g. the competition integral is `Σ (xᵢ − xᵢ₊₁)(fᵢ + fᵢ₊₁)/2`, a sum
whose weights are the **cohort spacings** `Δxᵢ = xᵢ − xᵢ₊₁`.

The compression term `∂ₓg` (the spatial derivative of the velocity) is the only piece of
the transport ODE that is not a closed-form rate; historically it was read from a
one-sided finite-difference stencil of `g` about each cohort's own height.

## 3. Diagnosis: the conservation pair

`∂ₓg` enters the discrete model **twice**, through two different objects:

1. **Explicitly**, in the transport ODE `dℓᵢ/dt = −∂ₓg − r`.
2. **Implicitly**, in the quadrature weights. The spacings evolve as velocity differences,
   `d(Δxᵢ)/dt = g(xᵢ) − g(xᵢ₊₁)`, which is `∂ₓg · Δxᵢ` to leading order.

These two copies are the *same continuous quantity*. They cancel exactly in the **conserved
mass per cohort** `mᵢ = e^{ℓᵢ} · Δxᵢ`, which obeys the transport-free law `dmᵢ/dt = −r·mᵢ`.
And integrating the PDE by parts confirms the continuum truth: for any moment,

```
dM/dt = ∫ (φ'g − φr) n dx + boundary flux            — ∂ₓg does not appear.
```

**So the physics every functional measures is transport-free.** `∂ₓg` is on the tape only
because we chose to transport a *pointwise log-density* whose ODE carries it; it
contributes nothing to the moments themselves.

The bug follows immediately. The two copies of `∂ₓg` were discretised by **different
operators** — a finite-difference stencil about each cohort's own height (in the ℓ-ODE)
versus a neighbour spacing (in the quadrature geometry). Their *values* nearly agree, so
the primal is fine and the cancellation `dmᵢ/dt = −r·mᵢ` holds numerically. But their
**parameter-derivatives** are computed by two unrelated expressions, so `∂(∂ₓg)/∂θ` does
**not** cancel on the reverse tape. The residual is the `O(1)` census-gradient error, and
it is largest for parameters (like `k_I`) whose only route to the census is through the
coupling that `∂ₓg` carries.

This also explains why the earlier fix — keeping the stencil value on the trajectory and
injecting an *analytic* `∂ₓg` derivative by forward-over-reverse — could not close the gap.
It made the two derivatives *more* different, not identical; a value/derivative seam is
the gradient of a different model than the one the primal runs, and it lies by an amount
no local conditioning trick removes (see §7).

## 4. The solution: geometric compression

Make the two copies of `∂ₓg` **literally the same discrete operator**. Discretise the
transport-ODE compression with the neighbour difference of the growth rate over the same
cohort spacings the quadrature uses:

```
        g(x_{i-1}) − g(x_{i+1})
∂ₓg  =  ───────────────────────        (interior; one-sided at the boundaries)
        x_{i-1} − x_{i+1}
```

Now the `∂ₓg` in `dℓᵢ/dt` and the `∂ₓg` implicit in the evolving spacings are the *same
expression in the same variables*. Their parameter-derivatives are therefore identical by
construction, cancel exactly on the reverse tape, and the census gradient collapses to the
transport-free continuum truth of §3 — to machine precision, for every parameter class.

This is not an approximation that happens to work; it is the unique local change that
restores the cancellation the continuum guarantees. Any operator that is *not* the
quadrature's own leaves two distinct expressions on the tape and reopens the `O(1)` gap.

**It stays a valid characteristic method.** The neighbour difference is computed on the
characteristics themselves (a Lagrangian quantity), so it introduces no Eulerian numerical
diffusion; the sharp advection of cohort positions that the SCM depends on is preserved.

## 5. Implementation

The compression is inherently a **multi-cohort** quantity (it needs neighbours), so it is
computed where the neighbour list lives — `Species::compute_rates` — not per-cohort in
`Node`.

- **`Control::node_geometric_compression`** (`bool`, default `false`). Registered through
  RcppR6 so it is settable from R as `Control(node_geometric_compression = TRUE)`.
- **`Node::compute_rates`** — for a forward-mode-instantiable (`rebind`) strategy with the
  flag on, seeds `log_density_dt = 0`; `Species` fills it in. With the flag off, and always
  for non-`rebind` strategies, it keeps the finite-difference stencil path unchanged.
- **`Species::compute_rates`** — after the per-node rates, and only when the flag is on for
  a `rebind` strategy, sets each cohort's `log_density_dt = −∂ₓg − r` from the neighbour
  difference above. Cohorts are ordered tallest-to-shortest, so height decreases with
  index and the difference quotient is sign-correct for interior (centred) and boundary
  (one-sided) cohorts alike. A **lone cohort** (`n < 2`) has no neighbours and no
  meaningful spatial gradient of `g`; its transport term is left at zero — a transient,
  start-of-run state with negligible weight in any accumulated census.

**Scope.** The change applies to strategies whose whole rate path is instantiable at a
forward tangent type (`template<class U> using rebind`) — **K93 today**. FF16/TF24/TF24f
keep the stencil: their differentiated metrics (mutant fitness) do not route through
`∂ₓg` (mixed-Jacobian argument, `ad-implementation.md` §15), so geometric compression
offers them nothing and changing their trajectories would be pure regression risk. When
their rate paths are ported to be forward-mode-instantiable, they inherit the same
Species-level operator with no per-strategy work.

## 6. Why opt-in

Geometric compression is a *different discretisation of the same PDE* than the upwind
finite-difference stencil, so enabling it moves the forward trajectory very slightly —
measured **~0.2%** on K93 offspring production (0.075325 → 0.075453). The upwind stencil
is the published K93 model's numerics. Changing a published model's output silently is not
something to do by default, so the flag is **off** by default:

- **Ordinary simulations** reproduce the published model bit-for-bit. The full test suite
  is green with the flag off, including the K93 "offspring production is unchanged"
  regression snapshots.
- **Differentiable runs** enable the flag. Their forward is then the geometric model, and
  the reverse gradient is self-consistent with *that* forward — which is the whole point:
  the gradient must be the derivative of the trajectory actually run.

**Kill condition / retrofit trigger.** If the geometric forward is later adopted as the
canonical K93 numerics (e.g. it is judged the better discretisation on its own merits, or
a caller wants gradients without a flag), flip the default to `TRUE` and re-baseline the
K93 snapshots. Nothing else changes; the code path is already the production one when the
flag is on.

## 7. Verification

With the flag on, the Gate-1 harness gradient matches the converged finite difference of
the model-as-run to machine precision, across both parameter classes:

| parameter | reverse-mode AD | converged FD | relative error |
|-----------|-----------------|--------------|----------------|
| `b_0`     | 317.883         | 317.883      | 1.1e-9 |
| `b_1`     | −516.881        | −516.881     | 1.7e-9 |
| `k_I`     | 2.045e-6        | 2.045e-6     | 2.8e-4 |
| `height_0`| 4.09588         | 4.09589      | 2.7e-6 |

`cosine(ad, fd) = 1.000000` over the full parameter vector (contrast the pre-fix
`0.970`, dominated by the `k_I` blow-up). The near-machine (not exactly machine) entries
are parameters with near-zero census sensitivity (`c_0 ≈ 3e-9`), i.e. noise floor.

Note that `k_I`'s *sensitivity itself* is ~2e-6 under geometric compression, versus 0.144
under the stencil: these are genuinely different dynamical systems with different
sensitivities, and the AD agreeing with FD **on the model it runs** is exactly what
correctness means. The flag-off path reproduces the old (inconsistent) numbers; the
flag-on path is machine-exact. Both are checked in the harness.

Acceptance battery (all passing): JVP = VJP per primitive; reverse vs converged FD at the
FD floor for both parameter classes; full `plant` test suite green with the flag off;
`Control` defaults and node ODE-rate tests updated for the new field.

## 8. Alternatives, and why this is the right form

Two other designs were carried far enough to price. Both are recorded here so the choice is
legible, not to reopen it.

- **Conserved-number state (the design-optimal alternative).** Transport log-**number**
  `L` with `dL/dt = −r` and make every field and moment a number-weighted sum, so `∂ₓg` is
  never a state-carrying quantity and *cannot* appear on the tape. This is the cleanest
  endpoint — transport-free by construction, robust, and it deletes the compression
  apparatus entirely rather than balancing a cancelling pair. It is **not required for
  correct gradients**, and it costs a core migration: reinterpreting the demographic state
  across `Node`/`Species`/strategy initial conditions, re-deriving birth as a number influx
  at the boundary, changing the field aggregation, and re-baselining serialization and the
  RcppR6 surface. Geometric compression buys the same gradient correctness with a local,
  reversible change. If the cancelling-pair fragility (a difference of two `O(1/Δx)` terms
  is one or two digits less precise than a directly conserved quantity, and is silently
  re-breakable if the two discretisations ever drift apart) becomes a problem, the
  conserved-number reparameterisation is the retrofit.

- **Keep the model, differentiate non-pointwise (rejected).** Get the current model's
  gradient from the full self-consistent finite difference (which *does* cancel, but costs
  `O(|θ|)` solves) or a continuous adjoint (which is the derivative of a slightly different,
  optimise-then-discretise model). A cheap probe of the tempting middle option —
  keep the stencil *value* on the forward and inject a well-conditioned geometric
  *derivative* on the reverse — confirmed the general obstruction: it reproduces the
  geometric model's gradient against a *shifted* finite-difference reference, i.e. it is
  the gradient of a different model than the one the primal runs. There is no
  forward-pristine free lunch: a well-conditioned derivative injected onto a pristine value
  is the derivative of a different model. Well-conditioned gradients require the model
  change, and geometric compression is the minimal one.

---

*The problem statements posed to the external reasoner during this investigation are not
retained; the transferable lesson — how to frame such a consultation so it surfaces
structure you cannot see — is distilled in [`oracle-consultation-guide.md`](./oracle-consultation-guide.md).*
