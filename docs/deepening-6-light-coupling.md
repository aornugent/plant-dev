# Deepening #6 — the resident light-environment coupling (K93/FF16), and dg/dh

Concretises target #6 of [`engine-deepening-targets.md`](./engine-deepening-targets.md), **resident
path only** (the active, self-shaded field; mutant deferred). This is P1b's primary witness and the
gate for P2a (K93) / P2b (FF16). It is also where **dg/dh** lives, so that is resolved here too.
Anchors are plant#52.

## 1. What the resident coupling computes today

A cohort of size `x_i` (height) with competition-effect `m_i = m(x_i)` casts shade at query height `z`:

    contribution_i(z) = m(x_i) · Q(z / x_i),   Q(u) = (1 − u^η)²  for u<1, else 0     (canopy_shape.h:155)
    m(x) = (π/4)·x²                for K93 (size_to_basal_area; k93_strategy.h:236)
    m(x) = area_leaf(x)            for FF16/TF24 (competition_effect)

The **cumulative shaded quantity** above `z` is the trapezoid integral over the (tallest-first ordered)
cohort population (`species.h::compute_competition:212`), and the field the model reads is the
Beer–Lambert map of it:

    L(z) = Σ_i  n_i · m(x_i) · Q(z/x_i)          (n_i = trapezoid-weighted cohort density)
    E(z) = exp(−k_I · L(z))                      ("competition"/openness, get_environment_at_height)

K93 then inverts it locally: `cumulative_basal_area = −log(E)/k_I = L(z)` (`k93_strategy.h:187`). Two
distinct read shapes over the *same* field:
- **K93** — a **single point read** at the plant's own height `z=x_i`.
- **FF16** — a **crown integral** over `z ∈ [z_base, H]` (sub-grid reads; the quadrature composition is
  target #2).

**No inner solve anywhere on this path.** `E=exp(−k_I·L)` and its inverse `−log(E)/k_I` are closed-form
maps (`Ψ = sample_map`, `Ψ⁻¹` closed form). Item #6 contributes zero implicit-node instances — the only
"operation that is a derivative" is `∂L/∂z`, owned by the scan.

## 2. The exact rank-3 separable factorisation (the P1b input)

Expand `Q(z/x) = (1 − (z/x)^η)² = 1 − 2 z^η x^{−η} + z^{2η} x^{−2η}`. Then

    κ(z,x) = m(x)·Q(z/x) = Σ_{p=1}^{3} a_p(z) · b_p(x)

with, exactly,

| p | a_p(z)      | a_p′(z)              | b_p(x)              |
|---|-------------|----------------------|---------------------|
| 1 | 1           | 0                    | m(x)                |
| 2 | −2 z^η      | −2η z^{η−1}          | m(x)·x^{−η}         |
| 3 | z^{2η}      | 2η z^{2η−1}          | m(x)·x^{−2η}        |

The field and its moving-query slope are then **suffix scans** over the tallest-first order (so "taller
than z" is a running prefix):

    B_p(z) = Σ_{x_i > z} n_i b_p(x_i)          (three descending scans)
    L(z)      = Σ_p a_p(z)  · B_p(z)           ← point read (K93) or integrand (FF16)
    ∂L/∂z     = Σ_p a_p′(z) · B_p(z)           ← the moving-query slope, EXACT

This is precisely the P1b `scan-coupling` primitive: model supplies `kernel_a(z)={1,−2z^η,z^{2η}}`,
`kernel_b(x)=m(x)·{1,x^{−η},x^{−2η}}`, and `kernel_direct(z,x)=m(x)Q(z/x)` for the init-time
`Σ a_p b_p == κ` self-check. `m(x)` is the only per-strategy difference (K93 `(π/4)x²`; FF16/TF24
`area_leaf(x)`), and it is a scalar-generic closed form — no XAD, no scan awareness in the model.

**C¹ double-diagonal zero (why the moving-query slope is safe):** at `z=x`, `Q(1)=0` and
`Q′(1)=2(1−1)(−η)=0`, so `κ(x,x)=0` **and** `κ_z(x,x)=0`. Both the contribution and its z-slope vanish
smoothly as the query passes a cohort height, so `∂L/∂z` is continuous across every crossing — the scan
can deliver it directly, with no special-casing at the diagonal.

**Near-diagonal band `δ`:** the recombination `L=Σ_p a_p B_p` sums three terms that individually grow as
`z^{2η}` (η up to 12) but cancel to the `O((x−z)²)` double-zero near the diagonal — catastrophic
cancellation that Neumaier summation cannot recover. Fix (Layer-K, invisible to the model): for source
cohorts within a band `|x−z|<δ·x`, evaluate `κ(z,x)` directly from `kernel_direct` instead of via the
recombined scan; `δ` defaults 0 (off) with a debug assertion that banded and unbanded `L` agree to
tolerance, so the hazard is caught the moment η or the population makes it bite.

## 3. dg/dh (the McKendrick density-transport term) — resolved here

`dℓ/dt = −∂ₓg − μ` (`node.h:184`). `∂ₓg` is the **total** size-derivative of the growth velocity, and
because `g` reads the light at the plant's own height, by the chain rule

    ∂ₓg = ∂g/∂h|_E  +  ∂g/∂E · (∂L/∂z at z=h) · (dE/dL)          [dE/dL = −k_I·E]

Every piece is now closed-form or a scan read: `∂g/∂h|_E` and `∂g/∂E` are model closed forms; `∂L/∂z` is
the exact scan slope from §2; `dE/dL` is the Beer–Lambert derivative. **No FD stencil, no
forward-over-reverse, no detached-secant surrogate.**

### What this deletes
The whole `node.h::growth_rate_gradient` machinery (~70 ln active block, `:274–363`):
- the **FD/upwind value stencil** (`gradient_fd`/`gradient_richardson`),
- the **forward-over-reverse injection** (`rebind<Fwd>`, `strat_fwd`, `Individual<strat_fwd_t,…>`),
- the **owned-secant `dE/dh` with its θ-sensitivity DETACHED** (`value_type(xad::value(dEdh))` — the
  frozen surrogate that existed only because the eps≪Δx secant was an ill-conditioned FD; the exact
  scan slope has no such artifact, so it is taped live),
- the `dgdh − value(dgdh) + fd_value` value/derivative **splice**.

### The stability tension, and how the mass chart resolves it
`node.h:247` keeps the FD value because the *exact centred* `∂ₓg`, fed into `dℓ/dt`, is numerically
unstable on the coarse cohort grid (drives density transport out of bounds once cohorts shade; the
analytic trajectory only stays bounded with a ~6% clamp change). The resolution is **not** to feed the
exact `∂ₓg` into a log-density rate at all:

- In the **transport-log-mass chart** (`λ = ℓ + log Δx`, `dλ/dt = −r`) the compression term `∂ₓg`
  **does not appear in the rate**. It is carried instead by the evolving cohort spacing `Δx`, whose
  update is the **neighbour secant** the geometric-compression block already computes
  (`species.h:277`: `dgdh = (g_lo − g_hi)/(h_lo − h_hi)`).
- `species.h:261` already observes the key fact: the `∂ₓg` in the ODE and the `∂ₓg` implicit in the
  quadrature spacing are the **same discrete operator**, so their θ-derivatives cancel on the tape. The
  mass chart *formalises* this: the density reconstruction and the transport share one
  `TransportGeometry` (the neighbour-secant ↔ log-mass pairing), so the cancellation is structural, not
  a coincidence to be re-verified per strategy.
- **Forward trajectory** stays stable (uses the neighbour-secant compression — the documented ~0.2% K93
  shift, opt-in for gradient runs, `R5`). **Gradient** is exact (chart rate has no `∂ₓg` to
  differentiate; the exact `∂L/∂z` enters only where `g` genuinely reads the local light slope).

So dg/dh needs **zero per-strategy AD code** (R2): the density-transport term is deleted from the model
rate by the chart, and the one place a rate reads the light slope gets the exact scan value.

### Number vs density in node.h today (bears on the mass chart)
A close scan of `node.h` for what representation the transported demographic variable takes:
- **Density is the only transported state.** `log_density`/`density` (`:139,141`, `density=exp(log_density)`,
  `:98`) is the McKendrick density `n(x)`. It weights competition (`compute_competition = density ·
  individual.compute_competition`, `:382`) and consumption (`consumption_rate = individual.consumption_rate
  · density`, `:127`).
- **The only "number" state is an output accumulator**, not a transported quantity:
  `offspring_produced_survival_weighted` (+`_dt`, `:199`), rate `= fecundity · survival · pr_patch ratio` —
  a cumulative lifetime count read by `weighted_fecundity`/R0, integrated *along* a characteristic, never
  redistributed across size.
- **Number appears implicitly at birth:** the density IC is `log(birth_rate·pr_estab/g)` (`:227`), i.e.
  `density = (number flux)/velocity`, so the boundary **flux** `F = g·n = birth_rate·pr_estab` is the
  natural boundary quantity — but it is *never carried as a state*.

**Consequence for P1e:** there is **no existing transported number/mass** to co-opt — the mass chart
`λ = ℓ + logΔx` (and the flux `F=g·n` the fixed-point BVP integrates) is genuinely new machinery the
charts-as-views layer must synthesize. But the birth IC confirms the chart *aligns with the existing
boundary law*: `influx_mass(S_b) ↔ birth_rate·pr_estab` and the `/g` in the IC is exactly the
density↔flux conversion the chart owns. So the chart is new code, not a reinterpretation — and F1's
`n=S/g` steady profile is the same `density = flux/velocity` relation this IC already encodes.

## 4. Model-facing surface (what the strategy author writes)

    template <class S> struct K93 {                    // FF16/TF24 identical but m(x)=area_leaf(x)
      std::array<S,3> kernel_a(double z, const Pars<S>&) const {           // a_p(z)
        S ze = pow_eta(S(z)); return { S(1), -2*ze, ze*ze };
      }
      std::array<S,3> kernel_b(S x, const Pars<S>&) const {                // b_p(x)
        S m = competition_effect(x), xe = pow_eta(x);
        return { m, m/xe, m/(xe*xe) };
      }
      S kernel_direct(double z, S x, const Pars<S>&) const {               // κ self-check
        return competition_effect(x) * Q(S(z)/x);
      }
      S sample_map(S L) const { return exp(-k_I * L); }                    // Ψ (Beer–Lambert)
      S velocity(S x, S A, const Pars<S>&) const;                          // g reads A = L(x) via view
    };

The strategy reads `A(x)=L(x)` and, where its rate needs it, `dA_dz(x)=∂L/∂z` through the `StateView`
(P1e) — never the interpolator, never a secant. `node.h::growth_rate_gradient` is gone; there is no
`growth_rate_given_height` FD probe.

### Deletes / replaces (resident path)
| current (plant#52) | fate | replacement |
|---|---|---|
| `node.h::growth_rate_gradient` active block (~70 ln) | **delete** | §3: chart deletes `∂ₓg`; scan gives `∂L/∂z` |
| `species.h` geometric-compression loop (`:267–282`) | **absorb** | the chart's `TransportGeometry` (neighbour-secant ↔ log-mass) |
| interpolator on the coupling path (`get_environment_at_height`) | **replace** | the exact scan read `L(z)` (interpolator retained only for `FlatTopSoftBox`, non-separable `leaf_area_above`) |
| frozen moving-query derivative (`get_environment_slope_at_height`, detached) | **delete** | exact `∂L/∂z = Σ a_p′ B_p`, taped live |

## 5. Open sub-questions (carry into build / a targeted test)
- **Does the mass chart fully remove the stability problem?** §3 argues the exact `∂ₓg` never enters a
  rate, so the instability that motivated the FD stencil cannot recur — but this must be *shown*: bin a
  K93 run in the log-mass chart and confirm the forward trajectory stays bounded with the exact
  identities (no clamp inflation) and the gradient matches frozen-schedule FD. (A Phase-1 P1e test,
  cheap; adjacent to F1's transport-faithfulness result which already showed `∂g/∂h` is reproduced to
  8.6e-6.)
- **FlatTopSoftBox** has a non-separable `leaf_area_above` (a smoothstep, `canopy_shape.h:190`); it keeps
  the interpolator fallback. Confirm the scan/interpolator switch is a per-`ShadingModel` decision at
  strategy setup, not a runtime branch on the hot path.
- **`η` general (non-specialised) case:** `a_p(z)` uses `z^η`; for the specialised η∈{1,2,4,8,10,12} the
  multiply chains are exact/bit-identical, but a general η routes through `std::pow` — confirm the scan's
  `a_p`/`a_p′` use the same `pow_eta` path so bit-identity holds where it held before.
- **Crown integral (FF16)** reads `L(z)` at multiple in-crown `z`: that composition (quadrature-through
  vs breakpoint at cohort tops) is target #2, but note here that the reads are all the *same* three
  `B_p` scans evaluated at different `z` — so FF16 adds no new scan, only more `a_p(z)` evaluations.
