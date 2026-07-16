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
population. The reductions are **several census moments at once** (a vector output). The instance
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

`κ` is smooth, nonnegative, `κ(z,z)=0`, defined for `x ≥ z`. The ordering `x₁<…<x_N` never changes,
so the `B_p` are suffix-sums of stable membership sets.

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

`J` is a saturating gain (a smooth co-limitation — a soft-min of two saturating terms) minus a rising
cost. The operating point is **static within the time step** (a fast equilibrium), reused. A second
output at the same point, `σᵢ` (a flux), is **not** stationary in `q` (`∂σ/∂q ≠ 0` at the optimum);
`σᵢ` is the population-side sink that drives the auxiliary subsystem. Two regimes: `q` solved to the
optimum each step, or `q` carried as a slow relaxing ODE state (`dq/dt = a·∂J/∂q`, evaluated off the
optimum).

### 1.5 The auxiliary subsystem

```
du_ℓ/dt = ( inflow − drainage_ℓ(u) − σ_ℓ ) / depth_ℓ ,   ℓ = 1..L ,  L ≈ 1–5
```

`σ_ℓ` is the population-aggregated sink at level `ℓ` (a sum over characteristics of their `σ`
contribution). `u_ℓ ≥ 0` is required (enforced by resets); `drainage_ℓ` and the conductivity in the
operating point diverge as `u_ℓ → 0` (the stiffness). `u` feeds back into the operating point and the
rates.

### 1.6 The breakpoint integral

`σ` (and the operating point's cost) are built from `I = Σ_ℓ ∫ f_ℓ(ξ; u, q; θ) dξ`, piecewise in `ξ`,
where the active branch switches at a threshold `ξ*` solving a monotone `h(ξ*; u, q; θ) = 0`. The
branches are individually smooth; `I` is continuous but its derivative has a jump term at `ξ*`.

### 1.7 Reductions and parameters

Several census moments simultaneously: `M_φ = Σᵢ φ(xᵢ)·mᵢ` for `φ ∈ {1, x², x^a, …}`, plus
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
2. Field reads occur **only** at the ordered `{xᵢ}` and the boundary — the compression's neighbour
   secant needs no sub-grid field value, so nothing reads the field away from the population points.
3. The field enters the rates **linearly** through `A` (`g`, `r`) and log-linearly (`p`).
4. Per-characteristic mass obeys `dmᵢ/dt = −r·mᵢ` in the mass chart — a positive exponential of a
   path integral; moments are transport-free (§1.7 identity).
5. The operating point: `J` concave with a unique interior optimum; `c` monotone with a unique root;
   the solve is **static within a step**; one output stationary (`ρ`), one not (`σ`).
6. The auxiliary subsystem is **low-dimensional** and its natural timescale is fast relative to the
   transport (the source of stiffness); each `du_ℓ/dt` is a scalar balance.
7. The breakpoint threshold `ξ*` solves a **monotone** scalar equation; branches individually smooth.
8. Multivariable output (a vector of moments), many parameters, full feedback.

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
