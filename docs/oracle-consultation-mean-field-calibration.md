# Calibrating a first-moment (ensemble-mean) model against finite single realizations seen through a nonlinear operator

A statistical inverse-problem / calibration question. No application context is needed or given; every
object is stated in neutral mathematical terms and the problem stands alone (assume none of any prior
thread). We want the **formulation** — how to pose the inference — and we would rather you **re-derive it
from the structure** than accept the decomposition we happen to describe. We may be carrying the wrong
comparison object; say so if the structure points that way.

## The generative process (the "truth" that produced the data)

A domain is a union of disjoint **cells**. Each cell independently undergoes **reset events** at the epochs
of a renewal process with hazard `h(a)` (`a` = time since that cell's last reset); a reset empties the cell.
Between resets a cell evolves **deterministically**.

State of one cell of age `a`: a density `n(x, a)` over a scalar internal coordinate `x ∈ [x0, ∞)`, obeying a
transport equation

```
∂_a n + ∂_x( g(x, E; θ, ε) · n ) = − μ(x, E; θ, ε) · n ,     n(x, 0) = 0 (empty at reset),
```

with a boundary influx of new members at `x = x0` at rate `β(·; θ, ε)`. The dynamics couple **nonlocally and
nonlinearly** through a scalar field: the value a member at coordinate `x` experiences is

```
E(x) = Φ( ∫_{x' > x} k(x'; θ) · n(x') dx' ) ,     Φ monotone decreasing  (e.g. Φ(z) = e^{−z}),
```

i.e. every member is affected only by the **aggregate of all members above it in `x`**. There is **no
spatial (horizontal) coordinate** — interaction is mean-field within a cell. `g` and `μ` depend on `x`
through `E(x)`.

Parameters split into three kinds:

- **`θ ∈ ℝ^p`, `p` small — global, shared by every cell**; the object we want. Its components are constrained
  to a known low-dimensional manifold (a change in one is compensated by others).
- **`ε` — a per-cell latent modifier** (low-dimensional) that perturbs the dynamics (e.g. a multiplier on the
  influx `β` or on the field `E`), drawn i.i.d. across cells from an **unknown** distribution `π_ε`.
- **`a` — the cell's age since last reset**, latent per cell, distributed as the stationary renewal-age
  density `p(a) ∝ exp(−∫_0^a h)` (hazard family also possibly unknown).

**Finite size.** A real cell holds **finitely many discrete members**; `n` is the many-member-density
idealization. The realized configuration is a point set `{x_i}` whose expected density is `n`, carrying
demographic/sampling fluctuations of order `1/√N` about `n`.

## The model we hold (what is cheap to compute)

For any `(θ, ε)`, a deterministic solver returns the whole single-cell trajectory `a ↦ n(x, a; θ, ε)` and
hence the reset-age-averaged density

```
N̄(x; θ, ε) = ∫ n(x, a; θ, ε) · p(a) da .
```

This is the model's **first moment**: for a given global `θ` and a given local `ε` it gives the mean density
(age-resolved and age-averaged). It does **not** return (i) the distribution of realizations at fixed
`(θ, ε, a)` — the finite-`N` demographic fluctuations — nor (ii) the across-cell distribution, which would
require `π_ε` and the hazard. `N̄` (and the trajectory `n(x,a)`) and their gradients in `(θ, ε)` are cheap
and exact.

## The observations (what the instrument returns)

Each sampled cell `k` returns a signal

```
y_k = H( C_k ) + η_k ,
```

where `C_k` is the cell's **explicit realized configuration** — the finite point set `{x_i}`, together with
**2-D/3-D spatial positions** the model does not carry — `H` is a **known, nonlinear, many-to-one forward
operator** from a configuration to a fixed-length signal (a profile/vector), and `η_k` is measurement noise.
Two facts about `H`: it is defined on **explicit spatial realizations, not on a density** (it needs actual
members placed in space), and it is **expensive** (a simulator). We observe `{y_k}` over `K` cells; each cell
has its own latent `(a_k, ε_k, N_k)` and spatial arrangement, none of which we observe.

## The representation gap (the core of the difficulty)

The observation operator's domain (**explicit spatial configurations**) is strictly richer than the model's
output (**a 1-D density over `x`**). To predict `y` from the model one must supply degrees of freedom the
model does not carry: a **sampling law** (density → a finite point set) and a **spatial-placement law**
(a horizontal point process). The signal `y` may be sensitive to those supplied choices to an unknown degree
— possibly comparable to its sensitivity to `θ`. Calibration must bridge this gap, not merely add noise on
top of a matching prediction.

## What we want

Infer the **global `θ`** (and as much of `π_ε` and the hazard as necessary) from `{y_k}`. The model gives a
single ensemble-mean density `N̄(θ, ε)`; the data are many **finite, phase- and nuisance-heterogeneous
realizations, each pushed through a nonlinear operator**. It is not obvious what to compare to what, at what
spatial support, or how to integrate out the per-cell latents.

## Facts an answer can rely on / constraints

- `N̄(x; θ, ε)`, the trajectory `n(x, a; θ, ε)`, and their gradients in `(θ, ε)` are cheap and exact.
- The **full stochastic generative process can be simulated** at any `θ` (drawing `a, ε, N`, producing an
  explicit configuration `C`) — but this is **expensive**, and `H` on top of it more so.
- `H` is known and evaluable but nonlinear, many-to-one, and costly; there is **no cheap inverse**.
- We can generate **synthetic data at a known `θ*`** and require any proposed method to recover `θ*` (a twin
  experiment). This is our correctness reference; for real data it becomes held-out predictive fit.
- The **window / support** that constitutes one observed "cell" is **ours to choose**. The hazard family and
  `π_ε` family may be treated as parametric unknowns to co-infer.
- **Soft preference (not a hard constraint):** a formulation that keeps the cheap deterministic core (`N̄`,
  and gradients) doing most of the work — calling the expensive full simulator and `H` sparingly — is more
  valuable than one that requires simulating the full stochastic process and `H` at every `θ`. But if the
  right move discards that preference, say so.

## Structural features — any may be load-bearing or incidental; we do not know which

The model returns only the **first moment**; the **two distinct averages** baked into it (mean-field
coupling within a cell; ensemble average over reset-age); the model also exposes the **age-resolved**
trajectory `n(x,a)`, not only its average; the **nonlinearity of the coupling** (mean density ≠ density of
the mean); the **latent per-cell age `a`** under an unknown hazard; the **latent per-cell modifier `ε`** under
unknown `π_ε`; **finite-`N` demographic noise**; the **nonlinear, realization-only, expensive operator `H`**
(so `H`-of-the-mean ≠ mean-of-`H`); the **representation gap** (the model carries no horizontal coordinate or
finite sample, both of which `H` needs); the **free choice of window/support**; a possible **confound between
`θ` and the latent distributions** (`p(a)`, `π_ε`) that may reproduce the same marginal; the asymmetry that
**`N̄` is cheap while the full simulator and `H` are expensive**; the availability of **cheap gradients** of
the deterministic core.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **What is the correct object to compare?** Is matching the model's first moment `N̄(θ)` to a suitable
   **aggregate of `{y_k}`** the right move, or does identifying `θ` genuinely require the **distribution over
   realizations** the model does not directly provide? If the latter, is that difficulty **intrinsic** (`θ`
   is identifiable only through second-order/realization structure the mean field discards) or
   **representational** (there is a cheap route to what's needed from the same deterministic core plus `H`)?

2. **Support / self-averaging.** Is there a spatial support (window ≫ some correlation length) on which a
   **spatial average of the data self-averages to the ensemble mean**, collapsing the problem to
   mean-vs-mean and dissolving the need to "define a cell" — and if so, what sets that length and how would
   we estimate it from the data themselves? At the opposite extreme (window ≈ one cell), what is the correct
   likelihood for a **single finite realization**?

3. **Where does the nonlinear operator go, and how is the representation gap closed?** Quantify the bias of
   **`H(N̄)`** (push the mean density through `H`, after some canonical placement) versus **`E[H(C)]`**
   (sample configurations, place them, render, average). When is commuting `H` with the expectation
   acceptable? Given `H` is expensive, what is the **cheapest correct** construction (a low-order correction
   to `H(N̄)`, a control variate using `N̄`, an emulator of `H`), and how should the un-modeled
   sampling/placement laws be chosen or marginalized so that `y`'s sensitivity to them does not masquerade as
   sensitivity to `θ`?

4. **Latent phase and nuisance.** Marginalize `(a, ε)` into a per-cell mixture, or infer them as per-cell
   latents (the model gives `n(x,a)` age-resolved, which makes per-cell age inference feasible)? Is `θ`
   **identifiable** against an unknown hazard and unknown `π_ε`, and what is the precise confound to watch —
   which combinations of `θ` and the latent distributions are observationally equivalent?

5. **Which statistics carry `θ`?** Because the model cannot reproduce horizontal spatial texture, should
   spatial/second-order statistics of the data be **excluded** from the discrepancy, or do they carry
   information about `(a, ε)` that **indirectly** helps identify `θ`? Name the summary you would actually fit
   (marginal-`x` distribution; its moments/quantiles; cross-cell variance; spatial autocorrelation of `y`)
   and why.

6. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts.

7. A **cheap discriminating experiment** — ideally carrying your own falsifiable prediction — to run before
   building anything.
