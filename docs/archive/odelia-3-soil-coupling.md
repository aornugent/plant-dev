# odelia design #3 — the soil↔leaf coupling (the γ node; soil as active state)

Third component of the odelia design journey (`design.md` P1c + the soil half of deepening-3). Under the
system-design skill, grounded in the v1 soil seam (`tf24_strategy.cpp` uptake partials,
`leaf_model.cpp::E_from_Soil_to_Root_Collar`, `tf24_environment.h` retention curve + `psi_soil_cache_`).

**The unifying insight.** The v1 soil coupling has the *same* clunk as the light coupling (odelia #1),
one channel over: the soil vulnerability antiderivative `root_vuln_integral_from_psi` is **another
sampled spline over a closed form** (an incomplete gamma). Oracle R2 — "an exact object, no sampled
differencing" — applies here too: the **scan** was the exact light field; the **γ node** is the exact
soil antiderivative. Same move, second channel.

## Triage: 3
odelia public API; the γ node is P1c, witnessed by the soil uptake + (later) the fixed-point BVP. The
soil coupling is TF24/TF24f + regnans.

## Requirements ledger
- **R-γ-exact — the per-layer uptake `E_i` and its derivatives are exact, from a closed-form
  antiderivative, never a sampled spline.** *Witness (v1):* `root_vuln_integral_from_psi` is a fixed-knot
  spline of `G(m)=∫₀^m exp(−(|ψ|/b)^c) ds` read by `.eval()`/`.deriv()` (sampled, its slope ripple-prone
  exactly like the light interpolator). Target: the γ node computes `G` exactly (a lower incomplete
  gamma under `u=(s/b)^c`).
- **R-uptake-auto — `d(E_i)/d(θ, collar, traits)` flows automatically, no hand partial.** *Witness:*
  `tf24_strategy.cpp:540–606` builds per-layer FD partials (`up_p/up_m`, `uptake_partials`) +
  `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` (a *hand analytic* per-layer collar derivative,
  written because "a straight FD straddles layer-crossing kinks and undershoots ~3×"). Both are
  hand-written adjoints — the scarce resource. Target: `E_i` a templated closed form; derivatives by
  ordinary tape + breakpoint nodes at the layer kinks.
- **R-nohazard — no `mutable` active cache keyed on exact `double` compare.** *Witness:* `psi_soil_cache_`
  is `mutable std::vector<S>` invalidated by `psi_soil_cache_state_[i] != vars.state(i)` (Q8 tape-poison).
- **R1 — no tape machinery on the model surface.** *Witness:* the `soil_consumption_active_`
  `supplied_derivative` vector + the `shouldRecord()` pair-filter live in `tf24_strategy.cpp`.
- **R-state — soil is bidirectional active ODE state, not a field.** *Quantity:* `TF24_Environment` carries
  `ode_size = soil_number_of_depths + 4` (`L ≤ 5`); FF16/K93 carry 0. Coupling is inside the ODE
  (`compute_rates(resource_depletion)`): cohorts → `resource_depletion` → soil → `ψ(θ)` → leaf → uptake →
  `resource_depletion`. Resident: active. Mutant: frozen L3 (deferred).
- **R-multirate (cross-ref, not this component)** — the `L≤5` soil states must not force the global step
  (E2's N/L amplifier); the multirate sub-cycle is an odelia *stepper* capability, forward-only track,
  adjoint free (tape-as-run). Noted below; not the coupling's design.

**Scarce resource:** *hand-written-adjoint correctness* — the v1 soil channel has **two** hand adjoints
(the FD uptake partials and `dsoil_consumption_dpsi_collar_perlayer`), the latter admittedly ~3×-biased
where FD hit the layer kinks. This component drives that to **zero** in the model.

## The floor
**Keep the v1 soil seam** (FD uptake partials + `soil_consumption_active_` + the `root_vuln_integral`
spline + the `psi_soil_cache_`). *Fails R-γ-exact, R-uptake-auto, R-nohazard, R1* — it is the clunk: a
sampled antiderivative, two hand adjoints, a tape-poison cache, and a model-side injection vector.

## Candidates
- **A [first thought]** (move 6, Pólya): the **γ node** (exact incomplete-gamma antiderivative, P1c) +
  `E_from_Soil_to_Root_Collar` rewritten as a **scalar-generic closed form over it**; soil is ordinary
  active ODE state read through `StateView.u()` (odelia #1); the per-layer flux `E_i = (G(a)−G(b))/(a−b)`
  differentiates by **ordinary tape**, with **breakpoint nodes** (register_implicit, odelia #2) at the
  layer-crossing kinks `|θ_ℓ − P_collar|`. *Pays* all: R-γ-exact (γ node), R-uptake-auto (tape +
  breakpoints — no hand partial), R-nohazard (no cache; recompute `ψ(θ)`, cheap), R1 (no
  `supplied_derivative`, no `xad` in the model), R-state (active ODE state). *Costs:* one new odelia
  Kernel (the γ node); composes #1 (`u()`) + #2 (breakpoints).
- **B** (keep the spline, auto-differentiate it): drop the FD partials, but keep `root_vuln_integral` as
  the fixed-knot spline and auto-form `d(E_i)` by taping through `.eval()/.deriv()`. *Fails R-γ-exact* —
  the spline is the sampled reconstruction Oracle R2 rejects, and its `.deriv()` is a sampled slope
  (the same ripple the light interpolator had). Removes the FD hand partial (good) but keeps the sampled
  antiderivative (the actual R2 failure).
- **C** (γ node, but keep the uptake injected): use the exact γ for now-exact *hand* partials, still
  injected via `soil_consumption_active_`/`supplied_derivative`. *Fails R1* — the model still orchestrates
  the injection and names the tape; the leak persists even with exact partials.

**Winner: A.** Eliminations: **B** keeps the sampled spline (R-γ-exact — the whole point, per the light
lesson); **C** keeps the model-side injection (R1 — the leak). A is the least design: one new Kernel (γ),
the rest composes #1 + #2, and the uptake becomes ordinary differentiable code.

## The commitment
**The soil coupling is ordinary active ODE state plus exact closed-form reads: the per-layer uptake is a
scalar-generic closed form over the exact γ-node antiderivative, its derivatives carried by the ordinary
tape and breakpoint nodes at the layer kinks. The model declares `ψ(θ)` and `E_i(ψ, collar)` — never a
partial, never a cache, never the tape.**

**Kept true by structure:** the γ node is an odelia Kernel exposing `G`, `∂G/∂x`, `∂G/∂s` (P1c);
`E_from_Soil_to_Root_Collar` is templated on `S` and calls it, so `d(E_i)` is the derivative of the
*same* code the value runs — no separate spline, no `.deriv()`. Soil is read through
`const StateView<S>::u()` (read-only) — there is **no `soil_consumption_active_` handle and no
`psi_soil_cache_`** in the model; `supplied_derivative` never appears. The layer-crossing branches are
`register_implicit` breakpoints (odelia #2), so the Leibniz jump is exact and the ~3×-biased hand
`dsoil_consumption_dpsi_collar_perlayer` deletes.

## Kill question
**Assumption whose falsity makes the γ node unnecessary:** *the soil vulnerability antiderivative is a
closed-form special function the node can serve exactly.*

**Verdict: survives.** `f_r(ψ) = exp(−(|ψ|/b)^c)`; `G(m)=∫₀^m f_r` under `u=(s/b)^c` is the **lower
incomplete gamma** `γ(1/c, (m/b)^c)·(b/c)` — exactly the P1c node. And `c` is a *differentiated trait*, so
`∂G/∂c` needs the digamma-series `∂γ/∂s` — which is precisely what P1c specifies. The soil uptake is the
witness that makes the γ node's `∂/∂s` load-bearing, not speculative.

## What survives deletion
- **The γ node** (`G, ∂/∂x, ∂/∂s`; `∂²/∂s²` reserved for the BVP) → R-γ-exact; retires the
  `root_vuln_integral` spline.
- **`StateView.u()`** (soil-state read, from odelia #1) → R-state/R1.
- **Breakpoint nodes at layer crossings** (register_implicit instances, from odelia #2) → R-uptake-auto
  (the exact Leibniz jump; deletes `dsoil_consumption_dpsi_collar_perlayer`).
- **Deleted:** the FD uptake-partial seam (`up_p/up_m`, `uptake_partials`), `soil_consumption_active_`,
  `dsoil_consumption_dpsi_collar_perlayer`, `psi_soil_cache_` (+`_state_`), the `root_vuln_integral`
  spline. **Not built:** the γ `∂²/∂s²` (reserved — Phase 3); RODAS (E2 dropped it).

## What this settles
- The soil channel adds **zero** new hand adjoints (its two v1 hand adjoints delete); `d(uptake)/d(θ,
  collar, traits)` is automatic (γ node + tape + breakpoints).
- No `supplied_derivative`, no `xad`, no `mutable<S>` cache in the soil model surface (R1, R-nohazard).
- The γ node is shared with the light-adjacent incomplete-gamma reads and the BVP — one special-function
  Kernel, self-checked (Richardson-FD-vs-analytic at init).

## What this makes hard
- **A vulnerability curve that is not the Weibull/incomplete-gamma form** (a tabulated retention curve):
  the γ node doesn't serve it. *Cope:* that curve uses the interpolator fallback (as the non-separable
  light mode does) — a per-model choice at setup, not a hot-path branch. No such curve exists in
  TF24/TF24f today.
- **Resident soil stiffness at long horizons** (the coupled `log_density`↔canopy + soil loop): the
  coupling is correct but the fixed-schedule replay can drift. *Cope:* the multirate sub-cycle
  (cross-ref) + the `tf24_stiffness_drift` gate; the coupling design here is orthogonal to the stepper.

## Kill condition
A witnessed soil model uses a non-incomplete-gamma vulnerability curve → that model uses the interpolator
fallback; the γ node stays for the Weibull-form strategies (all of TF24/TF24f today).

## The design (interface + flow)

```cpp
// odelia Kernel — the exact incomplete-gamma antiderivative (P1c)
template <class S> struct GammaNode {
  S     G   (S m, S s) const;   // ∫₀^m exp(−(·)^c) ds  == lower incomplete gamma; s carries the shape (1/c)
  S     dGdx(S m, S s) const;   // = f_r(m)  (elementary; the Leibniz endpoint derivative)
  S     dGds(S m, S s) const;   // series + digamma (the differentiated-trait channel)
  // ∂²/∂s² reserved (BVP). Richardson-FD-vs-analytic self-check at init.
};
```

**What a strategy declares (soil uptake, now scalar-generic — the leaf's `E_from_Soil` becomes this):**
```cpp
// per soil layer ℓ, at collar potential q (from the leaf inner solve, odelia #2):
//   mean conductivity over [a,b] = (G(a) − G(b)) / (a − b)      a,b from clamp(ψ_soil[ℓ], q)
//   E_ℓ = flux(mean_cond, grav[ℓ], r_R[ℓ])                       a closed form
// θ read via view.u(ℓ); q from register_implicit (N3); the |θ_ℓ − q| branch is a breakpoint node.
S psi_soil(int l, const StateView<S>& v) const { return a_psi * pow(v.u(l)/theta_sat, -n_psi); }
S uptake  (int l, S q, const StateView<S>& v) const;   // = (G(a)-G(b))/(a-b) · … via GammaNode
```

**Data flow (resident gradient).** Soil `θ` is active ODE state; `ψ(θ)` is a taped closed-form read (no
cache); the leaf inner solve (odelia #2) gives the collar `q`; `uptake` reads `ψ`, `q`, and `GammaNode`,
returning `E_ℓ` whose `∂/∂θ` and `∂/∂q` flow by ordinary tape (Leibniz endpoints are `dGdx=f_r`), with a
breakpoint node where `q` crosses a layer's `ψ`. `E_ℓ` scatters into `resource_depletion` (the soil sink)
— the two-way coupling is now entirely on the tape, no injection vector. `dq/dθ` composes through the
implicit-node (odelia #2).

**The multirate cross-reference (stepper, not coupling).** The `L≤5` soil block is sub-cycled within the
SCM macro-step (E2: kink-split at recorded rainfall knots; the desingularizing chart *dropped*). odelia
records the soil sub-schedule (an L1-refinement) and replays it fixed; the adjoint is free (tape-as-run,
checkpoint at macro steps). This is the forward-only track that keeps resident TF24 in scope and lifts
the long-horizon stiffness wall; it composes with this coupling design without changing it.

**The two coupling channels, unified.** Light (odelia #1, the scan) and soil (this, the γ node) are the
same v2 move — an exact closed-form object replacing a sampled spline (Oracle R2). With both, the resident
TF24 coupling carries **no sampled reconstruction, no hand adjoint, no `xad` in plant** on either channel
— the whole point of v2.
