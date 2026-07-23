# Deepening #3 — the two-way soil↔leaf coupling (the `StateView.u()` surface)

Concretises target #3: how the per-layer sink `σ_L(θ)` feeds the soil ODE while the leaf reads `ψ(θ)`,
such that the ~150 lines of hand-built per-layer uptake partials
(`tf24_strategy.cpp:537–686`) and the hand IFT `dsoil_consumption_dpsi_collar_perlayer` become
automatic. Anchors: `leaf_model.cpp::E_from_Soil_to_Root_Collar:399`, `tf24_environment.h`.

## The loop, both directions

**Down (soil → leaf):** soil state `θ_i` → `ψ_soil[i] = psi_from_soil_moist(θ_i)` (closed form,
`tf24_environment.h:302`, `a_psi(θ/θ_sat)^{−n}`). The leaf reads `ψ_soil` in `E_from_Soil_to_Root_Collar`
to build per-layer uptake `E_i` and the aggregate supply `E_up = Σ_i E_i`.

**Up (leaf → soil):** `E_i = soil_consumption_[i]` becomes the per-layer sink `resource_depletion[i]` in
the soil balance `dθ_i/dt = (in − K(θ_i) − E_i)/dz` (`tf24_environment.h:274`), and
`evapotranspiration_dt` reads `soil_consumption_active_[i]` (`tf24_strategy.cpp:59–65`).

Both couplings are **low-rank** (`L ≤ 5` layers) and read only a scalar per layer — exactly the
`StateView.u()` accessor the design posits.

## The per-layer uptake `E_i` — an antiderivative difference (the γ node + Leibniz)

`E_from_Soil_to_Root_Collar` sums three branches per layer (`:441–547`):
1. **equal potentials** `|P_x_r − ψ_soil[i]| < 1e-8`: `E_i = −grav·inv_area/r_R` (measure-zero).
2. **gravity-balanced** `|(ψ_soil[i] − P_x_r) − grav[i]| < 1e-8`: `E_i = 0` (measure-zero).
3. **general** (the workhorse): mean root conductivity over `[P_src_min, P_src_max]` computed from the
   **pre-integrated curve** `G(m) = ∫_0^m f_r(s) ds`, `f_r(ψ)=exp(−(|ψ|/b_root)^{c_root})`
   (`root_vuln_integral_from_psi`, `:487`). `mean = (G(−P_src_min) − G(−hi_neg))/(P_src_max − P_src_min)`.

`f_r` is a Weibull-type survival; its antiderivative `G` is an **incomplete-gamma** form — the design's
`γ(s,x)` node (P1c). The mean-conductivity is `(G(a) − G(b))/(a−b)`: an **antiderivative difference**.

### Why this makes the hand partials automatic
- `d E_i / d ψ_soil[i]` and `d E_i / d P_x_r` are **Leibniz derivatives** of the antiderivative
  difference: `dG/d(endpoint) = f_r(endpoint)` (exact, no FD). The `γ` node supplies `G`, `∂G/∂x`
  (elementary), and `∂G/∂s` (digamma-series) — so both partials fall out.
- The **layer-crossing kink** (`P_x_r` passes `ψ_soil[i]`, where branch 3 → branch 1/2 and
  `dE_from_soil_dpsi_collar` returns NaN, `:935–938`) is a **breakpoint node**: the Leibniz jump term is
  exact, replacing the ~3×-undershooting FD the hand code avoided (`tf24_strategy.cpp:657–663`).

This is why `dsoil_consumption_dpsi_collar_perlayer` (the analytic per-layer hand IFT) and the
central-FD uptake partials both **delete**: the antiderivative-difference form differentiates itself.

## The `StateView.u()` surface (proposed)

    template <class S> struct AuxView {
      S psi_soil(int layer) const;     // = psi_from_soil_moist(theta[layer]); the DOWN read
      int n_layers() const;            // L <= 5
    };
    // leaf inner solve consumes psi_soil(layer); returns per-layer E_i.
    // engine scatters E_i back as the soil sink and into evapotranspiration_dt (the UP write).

The model author writes only: `ψ_soil` as a closed form of `θ`; `E_i` via the `γ`-node
antiderivative difference; the aggregate `E_up`. The engine owns: seeding `θ`/`ψ_soil` at tape inputs,
the breakpoint at layer crossings, and scattering `E_i` to both consumers. The
`soil_consumption_active_` `supplied_derivative` vector (`tf24_strategy.cpp:677–686`) — one
`supplied_derivative` per layer carrying the `(θ, soil-ψ)` partials — is **replaced** by the taped
antiderivative-difference reads: the water-limited feedback is differentiated structurally, not by a
hand-assembled partial list.

## Transient vs fixed-point use of `u`
- **Transient march:** `θ` is integrated state; `u()=ψ_soil(θ)` is a live taped read; `E_i` scatters to
  the sink. The soil block is the multirate sub-cycle (E2 verdict: multirate + kink-split, no chart);
  its adjoint is free (tape-as-run).
- **Fixed point (BVP):** the `L` steady-`u` equations are `dθ_i/dt = 0`, i.e. `in − K(θ_i) − E_i = 0` —
  `L` algebraic unknowns solved with the profile (design §second-numerics-layer). The **same** `γ`-node
  `E_i` closed form serves both; the sink-quadrature states aggregate `Σ E_i` over the profile.

## What deletes / lands where
| current (plant#52) | fate | replacement |
|---|---|---|
| `tf24_strategy.cpp:537–686` per-layer FD uptake partials + `supplied_derivative` per layer | **delete** | Leibniz derivatives of the `γ`-node antiderivative difference |
| `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` (hand IFT) | **delete** | automatic `dE_i/dP_x_r = f_r` (Leibniz) + breakpoint at layer crossings |
| `soil_consumption_active_` marshalling (`tf24_strategy.h:442`) | **delete** | `StateView.u()` read + engine scatter |
| `root_vuln_integral_from_psi` spline | **replace** | the `γ(s,x)` node (P1c), analytic `∂/∂x`,`∂/∂s` |

## Nested-solve inventory update
Soil coupling adds **no new iterative inner solve** — the per-layer `E_i` is a closed-form
antiderivative difference (γ node), and the only "operations that are derivatives" are the Leibniz
endpoint terms (breakpoint nodes at layer crossings). The soil block's own time integration is the
multirate sub-cycle (forward-only track), not a solve on the gradient path.
