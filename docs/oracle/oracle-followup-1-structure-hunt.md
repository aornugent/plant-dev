# Follow-up A (deepened): the hard case, fully specified — where is the exploitable structure?

Your first response mapped the components and gave correct treatments. This follow-up narrows to
the **single hardest case, fully specified with concrete closed forms**, and asks one thing: given
the actual structure written out below, is there an analytical collapse, an exact factorization, a
change of variables, or a reduced state that removes a component — or the problem — rather than
merely differentiating it correctly? We are hunting for structure we cannot see. Rank whatever you
find by how much machinery it removes; "nothing beyond the generic treatment" is a fine answer for
any piece.

**Scope (deliberately narrowed).** Only the **fully self-consistent** regime: the population
generates the field it reads, so every field value carries the state-derivatives of the whole
population. The reductions are **several distribution moments at once** (a vector output). The instance
carries all the hard machinery at once: an embedded within-step operating-point solve, a stiff
low-dimensional auxiliary subsystem, and a breakpoint integral — plus the density-transport
compression term in its clean neighbour-secant form. There is no frozen-background case here.

Symbols follow the original statement (`xᵢ, ℓᵢ`, mass `mᵢ = exp(ℓᵢ)Δxᵢ`, field `S`, kernel `κ`,
aggregate `A`, operating point `(q,v)`, response `ρ`, co-output `σ`, auxiliary state `u`).

---

## 1. The system, written out

### 1.1 State and transport

Per characteristic `i`: a positive coordinate `xᵢ`, a log-density `ℓᵢ`, and two scalar accumulators
(an integrated loss and an integrated production). The coupling is a scalar aggregate the population
builds and reads:

```
A(z) = Σ_{j : xⱼ ≥ z} κ(z, xⱼ; θ) · mⱼ ,        mⱼ = exp(ℓⱼ)·Δxⱼ
```

The rates at characteristic `i` read the aggregate at the point's own coordinate, `Aᵢ = A(xᵢ)`
(equivalently the contraction `Sᵢ = exp(−Aᵢ) ∈ (0,1]`; the rates below use `Aᵢ` linearly, so either
form is faithful).

```
dxᵢ/dt = g(xᵢ, Aᵢ; θ)
dℓᵢ/dt = −( Cᵢ + r(xᵢ, Aᵢ; θ) )
Cᵢ = ( g_{i+1} − g_{i−1} ) / ( x_{i+1} − x_{i−1} )      (neighbour secant; one-sided at ends)
```

`Cᵢ` is the density-transport (compression) term in its clean form. Insertions add characteristics
at a moving boundary on a frozen schedule; `N` grows from `O(1)` to `10²–10³`.

### 1.2 The kernel is exactly low-rank separable

```
κ(z, x; θ) = c_k · x² · (1 − (z/x)^η)²  for z ≤ x, else 0 ,      c_k, η parameters.
```

Expanding, `κ(z,x) = c_k[ x² − 2 z^η x^{2−η} + z^{2η} x^{2−2η} ]` — an **exact rank-3 separable
kernel**: `κ(z,x) = Σ_{p=1}^{3} a_p(z)·b_p(x)`. Hence the aggregate is three one-sided cumulative
sums over the ordered population:

```
A(z) = Σ_{p=1}^{3} a_p(z) · B_p(z) ,   B_p(z) = Σ_{j : xⱼ ≥ z} b_p(xⱼ)·mⱼ .
```

`κ` is smooth, nonnegative, defined for `x ≥ z`, with a **double zero on the diagonal**:
`κ(z,z)=0` *and* `κ_z(z,z)=0` (verified for the form above, any `η>0`). Consequently `A(z)` and
`S(z)` are **C¹** across every particle coordinate, so the query-direction derivative of the field
is continuous everywhere and a source entering at the boundary is field-silent (it contributes only
to its own read, where the double zero kills the term). The ordering `x₁<…<x_N` never changes, so
the `B_p` are suffix-sums of stable membership sets.

### 1.3 The rates (concrete)

```
g(x, A) = smooth₊( x·(β₀ − β₁ ln x − β₂ A) )          (velocity; smooth₊(y)=½(y+√(y²+ε²)))
r(x, A) = smooth₊( −γ₀ + γ₁ A )                        (loss)
p(x, A) = δ₀ · κ_a x² · exp(−δ₁ A)                     (production accumulator rate)
```

The smooth₊ replaces a hard positive-part; its corner is small. The field enters the rates linearly
through `A` (and exponentially in `p`).

### 1.4 The operating point (the embedded solve)

One ingredient of the rates in the hard instance — the response `ρᵢ` — is the value at the optimum
of a within-step objective:

```
ρᵢ = J(q*, v*; xᵢ, Sᵢ, u; θ) ,
   q* = argmax_q J(q, v(q); …)        smooth, concave over the feasible range, unique interior
                                       optimum: ∂J/∂q = 0 there
   v*  solves c(v; q, …) = 0          a monotone supply = demand balance, unique root: ∂J/∂v ≠ 0
```

`J` is a smooth saturating gain (a smooth minimum of two saturating terms) minus a rising cost. The
constraint `c(v; q)=0` is **algebraic, not transcendental**: it is a rational balance that clears to
a low-degree polynomial in `v` (a quadratic per branch; the smooth-min coupling the two branches
raises the combined equation to a **quartic**), solved iteratively only for branch-robustness. The
optimum over `q` sits **strictly above** the `v`-solve (the quantity fixing `v` is held constant
inside it), so the two are cleanly nested, not simultaneous. The operating point is **static within
the time step** (a fast equilibrium), reused. A second output at the same point, `σᵢ` (a flux), is
**not** stationary in `q` (`∂σ/∂q ≠ 0` at the optimum); `σᵢ` is the population-side sink that drives
the auxiliary subsystem. Two regimes: `q` solved to the optimum each step, or `q` carried as a slow
relaxing ODE state (`dq/dt = a·∂J/∂q`, evaluated off the optimum).

### 1.5 The auxiliary subsystem

```
du_ℓ/dt = ( s_ℓ − w_ℓ(u) − σ_ℓ ) / τ_ℓ ,   ℓ = 1..L ,  L ≈ 1–5
```

`s_ℓ` is a source, `w_ℓ(u) = W·(u/u_sat)^p` a state-dependent loss with a **large exponent** `p ≈ 16`,
and `σ_ℓ` the population-aggregated sink for component `ℓ`. `u_ℓ ≥ 0` (enforced by a reset). The
large `p` makes the local relaxation time `τ ∝ 1/w′(u) ∝ u^{1−p}` **short when `u` is high and
divergent as `u` depletes**. This is a genuinely stiff fast/slow split — and its QSS-eliminability is
**regime-dependent, measured**: on realistic runs `u` sits within ~1% of its instantaneous
equilibrium **~90% of the time** (relaxation ≪ the timescale on which the sink drifts), but a
minority **~10% of steps are real fast transients** where `u` lags equilibrium by order one or more
(deep-depletion episodes, where `τ` has blown up); the adaptive integrator resolves those with
sharply reduced steps (the stiffness). So a pure quasi-steady closure is accurate for the bulk but
drops that ~10%. `u` feeds back into the operating point and the rates.

### 1.6 The breakpoint integral

`σ` (and the operating point's cost) are built from `I = Σ_ℓ ∫ f_ℓ(ξ; u, q; θ) dξ`, piecewise in `ξ`,
where the active branch switches at a threshold `ξ*` solving a monotone `h(ξ*; u, q; θ) = 0`. The
integrand is an `exp(−(ξ/b)^c)`-type form with a **closed-form antiderivative** (a lower-incomplete-
gamma function), and `I` is in fact **already evaluated analytically** by differences of that
antiderivative — not by quadrature. The branches are individually smooth; `I` is continuous but its
derivative has a jump term at `ξ*`. So the only remaining difficulty here is the moving,
state-dependent branch point `ξ*`, not the integration.

### 1.7 Reductions and parameters

Several distribution moments simultaneously: `M_φ = Σᵢ φ(xᵢ)·mᵢ` for `φ ∈ {1, x², x^a, …}`, plus
time-integrated `∫ Σᵢ p(xᵢ,Aᵢ)·mᵢ dt`. Differentiate the whole vector w.r.t. all parameters
`θ = (β₀,β₁,β₂, γ₀,γ₁, δ₀,δ₁, c_k, η, and the operating-point/auxiliary parameters)` and initial
conditions — **full feedback**: the field, the operating point, and `u` all respond to `θ`, and each
characteristic influences and is influenced by the others through `A`. Under `r=0, σ=0` total mass `Σmᵢ` is
conserved; and integrating the moment by parts, `dM_φ/dt = Σ(φ′g − φr)mᵢ + boundary` contains no
compression term.

---

## 2. Structural features (flat; any may be load-bearing or incidental)

1. The kernel is **exactly rank-3 separable**; the aggregate is three one-sided cumulative sums over
   a stable ordering.
2. The kernel has a **double diagonal zero** (`κ(z,z)=κ_z(z,z)=0`), so the field is **C¹** across
   particle coordinates and the query-direction derivative is continuous.
3. Field reads occur **only** at the ordered `{xᵢ}` and the boundary — the neighbour-secant
   compression needs no sub-grid value. (One variant reads `S` at sub-grid points spanning each
   characteristic; even there the value is the same separable aggregate, closed-form at any query.)
4. The field enters the rates **linearly** through `A` (`g`, `r`) and log-linearly (`p`).
5. Per-characteristic mass obeys `dmᵢ/dt = −r·mᵢ` in the mass chart — a positive exponential of a
   path integral; moments are transport-free (§1.7 identity).
6. The operating point: `J` concave with a unique interior optimum; `c` an **algebraic** balance
   (a quartic under the smooth-min), not transcendental, cleanly nested below the `q`-optimum; the
   solve is **static within a step**; one output stationary (`ρ`), one not (`σ`).
7. The auxiliary subsystem is **low-dimensional** with a large-exponent loss (`∝ u^p`, `p≈16`):
   fast when full, relaxation diverging as it depletes. **Measured**: ~90% of steps near
   equilibrium, ~10% genuine fast transients — so quasi-steady elimination is regime-split.
8. The breakpoint integrand has a **closed-form antiderivative** (incomplete-gamma) and is already
   integrated analytically; the threshold `ξ*` solves a **monotone** scalar equation.
9. Multivariable output (a vector of moments), many parameters, full feedback.

---

## 3. The ask

Given the system fully written out:

- Where does the structure permit an **analytical collapse** rather than a correct-but-mechanical
  treatment — a closed form, an exact factorization (the kernel is already exactly separable; does
  that propagate through the aggregate, the field, and its adjoint to remove the reconstruction and
  the coupling difficulty?), a change of variables, or a reduced/eliminated state?
- Is there a **single representation** — of the transported state, the field, the operating point, or
  the auxiliary subsystem — in which several components collapse at once? You already identified the
  mass chart on the state axis; is there an equally load-bearing one elsewhere, and do they compose?
- If you had to name the **one change with the largest structural payoff** that we have not made,
  what is it, and what does it cost?
- Please challenge the framing — including whether the transported variable, the aggregate, or the
  operating-point variables are the right objects at all.

For anything you propose, name a cheap discriminating test that would confirm the structure holds in
this instance; we test before building.
