# Identifying shared parameters when the model returns only a conditional mean, and the data are single realizations seen through a nonlinear operator

A parameter-inference question. No application context is needed or given, and the generating mechanism is
described **only through the computations it exposes** — deliberately at a level that names neither an
application nor a solution method. We want you to choose the method, and would rather you re-derive the
right approach from the structure than accept any decomposition we imply. It is self-contained (assume none
of any prior thread). If we are comparing the wrong objects, say so.

## The objects

**A generative law producing a spatial field.** For a shared parameter `θ` there is a stochastic mechanism
that fills a spatial domain. The domain is partitioned into **units**. Each unit is returned to a fixed
baseline (the empty state) at random times — resets may be correlated across nearby units — and between its
resets it generates a **configuration**: a finite set of **items**, each carrying a scalar attribute value
and a position inside the unit's extent. Two kinds of parameter, plus one latent per unit:

- `θ ∈ ℝ^p`, `p` small — **shared by every unit**; the object we want. Its components lie on a known
  low-dimensional manifold (a change in one is offset by others).
- `ε` — **fixed within a unit, drawn independently across units** from an unknown law `π_ε` (low-dimensional).
- `τ` — the unit's **elapsed time since its last reset**, latent per unit, distributed as `w(τ)` (the
  reset-time law family is itself uncertain).

**The mechanism, given only through what it exposes.** We do not describe the internal dynamics. Two
computations, and only these two, are available:

1. **A conditional mean — cheap and differentiable.** `m(x; θ, ε, τ)` = the expected density over the scalar
   attribute `x` of the items in a unit at `(θ, ε, τ)` — a curve, not a configuration. `m` and its gradients
   in `(θ, ε)` are cheap and exact. The phase-average `M(x; θ, ε) = ∫ m(x; θ, ε, τ) w(τ) dτ` is available
   too; the field-average additionally integrates `M` over `π_ε`.
2. **A full sampler — expensive.** Draw an actual configuration `C ~ L(θ, ε, τ)` (items, attributes,
   positions). Everything about the law beyond its mean `m` — the count distribution, the spatial
   arrangement, all higher structure — is reachable only this way, and it is costly.

**A nonlinear observation map.** A known map `H` sends a **full configuration** to a fixed-length signal:
`y = H(C) + noise`. `H` is nonlinear, many-to-one, and expensive (a simulator). It is defined on
configurations — it needs the items' actual positions and count — **not** on the mean curve `m`.

**The data.** Signals from **chosen windows** of the field: `{ y_k }_{k=1..K}`, each `y_k = H(C_k) + noise`,
where `C_k` is the realized configuration inside window `k`. A window's geometry is **ours to choose**, and a
window may cover a fraction of one unit, one whole unit, or several units — we do not observe the unit
boundaries, nor `(ε_k, τ_k)`, nor the counts or positions. All units share the same `θ`.

## The representation gap

`H`'s input space (finite configurations: counts + positions + attributes) is strictly richer than what the
cheap computation returns (the attribute-density curve `m`). To predict a signal from `m` one must **supply
degrees of freedom the mean does not carry** — a rule turning a density into a finite item set, and a rule
placing those items in space. The signal `y` may depend on those supplied rules as strongly as on `θ`. A
calibration must bridge this gap, not merely add observation noise onto a matching prediction.

## What we want

Recover the shared `θ` (and as much of `π_ε` and `w(τ)` as necessary) from `{y_k}`. The tension: the cheap
side of the model returns a **single conditional-mean curve**, while the data are **many single
realizations, each a nonlinear functional of one finite draw at latent nuisance settings**, gathered over
windows whose relation to the reset units is ours to set. It is not obvious what to compare to what, over
what spatial support, or how to account for the latents and the representation gap.

## Facts an answer can rely on / constraints

- `m(x; θ, ε, τ)`, its phase-average `M`, and their gradients in `(θ, ε)` are cheap and exact.
- The full sampler and `H` are available at any `(θ, ε, τ)` but **expensive**; there is no cheap inverse of
  `H`.
- The internal dynamics is deterministic at the level of the mean and has the qualitative properties listed
  under structural features. **If some further property of it is decisive, name the property and how the
  answer forks on it.**
- We can generate a **synthetic field at a known `θ*`** (full sampler + `H`) and require any method to
  recover `θ*` — the correctness reference; on real data it becomes held-out predictive agreement.
- The observation **window/support is ours to choose**; the families for `w(τ)` and `π_ε` may be treated as
  parametric unknowns to co-infer.
- **Soft preference, not a constraint:** a method that lets the cheap conditional mean do most of the work
  and calls the expensive sampler / `H` sparingly is worth more than one that runs the full sampler at every
  `θ`. If the right move discards this preference, say so.

## Structural features — any may be load-bearing or incidental; we do not know which

The model exposes **only the conditional mean** cheaply (all else needs the expensive sampler); the mean is
available **phase-resolved** (`m(·,τ)`), not only phase-averaged; with `τ` the mean **relaxes toward a limit
set by the mechanism's internal coupling** (units at large `τ` resemble one another); items interact **only
through an aggregate** (so the mean is self-consistent without positions, while a single realization is
not); parameters split **shared (`θ`) vs fixed-per-unit (`ε`)**; the latent phase `τ` under an uncertain
reset law; the **representation gap** (mean = a curve; `H` needs counts + positions); the **nonlinearity of
`H`** (so `H` of the mean ≠ mean of `H`); **finite-count fluctuations** within a single configuration; a
spatial **correlation length** in the field, set jointly by the spatial correlation of resets and the range
of the coupling; the **misalignment** between the reset unit and the freely-chosen observation window; a
possible **confound** between `θ` and the latent laws `(w, π_ε)` that reproduces the same observed marginal;
the **cheap-mean / expensive-everything-else** asymmetry.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **What is the correct object to compare?** Is matching the conditional mean to a suitable aggregate of
   `{y_k}` right, or does identifying `θ` genuinely require structure of the full law that the mean discards
   (reachable only via the expensive sampler)? If the latter, is that **intrinsic** (`θ` is identifiable
   only through higher-order / single-realization structure) or **representational** (a cheap route exists
   from the mean plus `H`)?

2. **Support and aggregation.** Is there a window scale on which a **spatial aggregate of the data coincides
   with the conditional-mean prediction** — dissolving the need to define a reset "unit" at all — and what
   sets that scale, estimable from the data themselves? At the opposite extreme (window ≈ one unit or less),
   what is the correct discrepancy / likelihood for a **single finite realization**?

3. **The nonlinear operator and the representation gap.** Quantify the bias of `H(mean)` (push the mean
   through `H` under some canonical count / placement) versus the **average of `H(realizations)`**. When is
   interchanging `H` with the average acceptable? Given `H` is expensive, what is the **cheapest correct**
   construction, and how should the un-modeled count / placement rules be chosen or integrated out so that
   `y`'s sensitivity to them is not mistaken for sensitivity to `θ`?

4. **Latent phase and per-unit heterogeneity.** Integrate `(τ, ε)` out into a per-window mixture, or infer
   them per unit (the phase-resolved mean makes per-unit `τ` inference feasible)? Is `θ` **identifiable**
   against an uncertain reset law `w(τ)` and an uncertain `π_ε`, and what is the precise confound — which
   combinations of `θ` and `(w, π_ε)` are observationally equivalent?

5. **Which features of the data carry `θ`?** Because the cheap model cannot reproduce spatial arrangement,
   should spatial / higher-order statistics of the data be **excluded** from the discrepancy, or do they
   carry information about `(τ, ε)` that helps identify `θ` indirectly? Name the statistic you would actually
   fit (the attribute marginal; its moments / quantiles; across-window variance; spatial autocorrelation of
   `y`).

6. **What are we missing?** A hidden invariant, a change of variables, or an assumption above that the
   structure quietly contradicts — including whether the conditional mean is even the right state variable
   to be reasoning about.

7. A **cheap discriminating experiment** — carrying your own falsifiable prediction — to run before building
   anything.
