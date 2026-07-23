# Deepening #2, #4, #5 — crown quadrature, early-exit classification, TF24f in the BVP

The remaining three targets. Shorter than #1/#3/#6 because each resolves to a classification rather than
new machinery. Anchors: `tf24_strategy.cpp`, `leaf_model.cpp`, `tf24f_strategy.cpp`.

## #2 — crown quadrature composition: **Kind C (quadrature-through), no breakpoints**

Three shading models (`tf24_strategy.cpp:414–485`):
- **CrownCentre** (`:425`): one leaf solve at a **single point read** `light(H·η_c)`. `single_solve`.
- **MeanLight** (TF24 default, `:430`): the leaf-area-weighted mean openness
  `∫₀^H light(z)·q(z) dz` (one QK integral over the scan field), **then one** leaf solve at that mean.
  `single_solve`. Bounds are **fixed doubles** (`:438` note: `S(height_d)`, no plant-height derivative
  entangled in the bounds), so the integral is a plain reduction; the self-shading derivative rides the
  active `get_environment_at_height(z)` reads inside.
- **DeepCrown** (`:452`): `single_solve=false` — a leaf solve at **each** quadrature node `z_i`, then
  each leaf output (profit, transpiration, per-layer uptake, …) is `q(z_i)`-weighted and integrated.

**Verdict:** the crown integral is a **taped reduction over fixed double bounds (Kind C)** — *not*
breakpoint nodes. Justification: both the crown weight `q(z/H)` and the light field `L(z)` are **C¹**
(the same double-diagonal zero `κ(x,x)=κ_z(x,x)=0` from #6; `q` also vanishes smoothly at `z=H`), so no
integrand kink crosses the quadrature. The only membership changes in the whole light path — source
cohorts entering/leaving the "taller than z" set — live in the **scan** (P1b) and are already C¹ by the
double-zero. So **no breakpoint fires on the crown integral.**

Composition onto the primitives:
- **MeanLight/CrownCentre:** one scan-based reduction (the mean openness / point read) + **one**
  reduced-gradient leaf solve (N1/N3 from #1). Cheap; this is the resident TF24 path Gate-0 exercises.
- **DeepCrown:** a `q`-weighted reduction of **per-node** reduced gradients — each node an N1/N3
  instance. Structurally identical, just `nn×` the leaf work. This **removes the current
  `util::stop("deep-crown seam not implemented")`** (`tf24_strategy.cpp:512`): with the reduced-gradient
  nodes there is nothing special about active DeepCrown — it is a reduction of node evaluations.

Adds **no new inner solve** beyond the per-node N1/N3 already counted.

## #4 — early-exit classification: **`decide()` predicates (Kind A), pending a C⁰ check**

The leaf shut-down early-exits (`prepare_collar_solve` returns false → `set_shutdown_state`,
`leaf_model.cpp:705–740`):
1. wettest soil layer drier than `ψ_crit` (`:705`) — no transpiration;
2. `E_column(−ψ_crit) < 0` (`:710`) — soil cannot supply the demanded flux;
3. continuity root would need collar drier than `ψ_crit`;
4. `assim_max` (at `ci=ca`) `< 0` — no positive assimilation.

Each selects between **the optimised branch** and **the shut-down closed form**
`profit = −R_d − hydraulic_cost_TF(ψ_crit)` (`:673`).

**Gate-0 measured (2026-07-16, `scripts/gate0-b-leaf-earlyexit.R`) — profit is NOT C⁰ across the
shut-down boundary.** Sweeping soil moisture across the transition (5 layers together, height 5 m) and
refining the step to `1e-7` in `θ`, profit **jumps ≈1.46 in a single step** — from a bit-identical
shut-down floor (`−8.3846`, `psi_stem` pinned at `psi_crit=7.085`) up to the first feasible optimum
(`−6.93`). It does not shrink with the step (a true discontinuity, not a sub-grid cliff). My earlier
"collapses continuously" assumption was **wrong**: the shut-down floor sits strictly *below* the
marginal feasible optimum, so losing all feasible transpiration is a discrete worsening — a genuine
**hydraulic-failure cliff** in the fitness landscape.

**Corrected verdict — `decide()` for the gradient, but a true discontinuity, NOT a continuous kink:**
- For the transient reverse-mode gradient **at a fixed operating point**, the branch is selected and
  replayed (Kind A `decide()`): a given cohort at a given time sits on *one* side, and that side's
  profit is smooth, so its one-sided derivative is exact. The boundary is measure-zero in `θ`, so it is
  not normally hit.
- **But it is a jump, not a smooth kink**, so **no Leibniz/breakpoint term applies** — there is no
  finite jump-slope to add; the derivative is *undefined at the boundary*. Treating it as a continuous
  breakpoint would be a silent gradient bug in the opposite direction from the one first feared.
- **Consequence for the fixed-point / selection regime (regnans):** the fitness landscape contains these
  hydraulic-failure cliffs, so `dλ/dθ` is genuinely non-differentiable where an equilibrium sits on
  one — an **honesty-condition refuse point** (design uncertainty 7), to be monitored like the
  spectral-gap closure, not averaged through. Which of the four early-exits produces the cliff (the
  measurement drove all layers together; `E_column<0` is the prime suspect) is worth isolating before
  the fixed-point layer is built.

Two other manifest entries, already understood:
- `smooth_positive` growth/mortality clamps (`k93_strategy.h:242`, TF24) — **Kind C** documented
  subgradients (the corner is smoothed; eps sets the radius).
- the birth `g>0 ? log(birth·estab/g) : log(0)` (`node.h:227`) — a genuine kink but at `density→0`
  (the newborn boundary, measure-zero, zero downstream weight); a `decide()` recorded in the manifest.

## #5 — TF24f tracked-`q` in the fixed-point BVP: **+1 pinned state, a new eigenvalue**

TF24f appends `opt_root_psi_state = q` with rate `dq/dt = k_acclim·G(q)` (gradient ascent,
`tf24f_strategy.cpp:44`; `G=dprofit_dq`, the same reduced gradient as #1's N3).

**At the demographic steady state**, every rate including `dq/dt = 0`, so `k·G(q)=0 ⟹ G(q)=0 ⟹ q=q*` —
exactly base-TF24's optimum (N3's residual). So **the steady profile is identical to TF24's**: the extra
BVP unknown `q(x)` is pinned by `G(q)=0`, degenerate with the solved case. Dimension: **+1 algebraic
steady-`u`-type equation** per profile point, but it adds no new *profile shape*.

**The difference is in the spectrum, not the profile** — this is the "solved-vs-tracked changes the
eigenvalue" claim made concrete:
- **Solved (TF24):** `q=q*(state)` is slaved algebraically — an infinitely-fast mode, not a dynamical
  eigenvalue.
- **Tracked (TF24f):** the linearised `dq/dt = k·G(q)` contributes a **finite relaxation eigenvalue
  `k·(dG/dq)`** to `∂F/∂X`, and since `dG/dq < 0` (N3 concavity) it is a **stable** mode (rate
  `k·dG/dq < 0`). It couples into growth/fecundity through the operating point, so the **dominant
  demographic eigenvalue `λ` and `dλ/dθ` differ** between the two — genuinely, because the population's
  response to perturbation is mediated by the slow `q`-relaxation when `k` is finite (TF24 is the
  `k→∞` limit).

**Consequences for the engine:**
- The reduced gradient `G(q)` is registered once (N1 + closed-form composition); base TF24 roots it
  (N3), TF24f integrates `k·G` and — at the fixed point — pins `q` by the *same* `G=0`. One object,
  three uses (root, ODE rate, BVP pin).
- The eigenvalue module (`adj⟨fwd⟩` sweep + Krylov, design §second-numerics-layer) must include the
  `q`-relaxation row/column for TF24f; `dG/dq` is the diagonal entry (from N3's denominator, already
  computed).
- **Honesty condition (design uncertainty 7):** at a marginally-active pinned set or a spectral-gap
  closure `dλ/dθ` is non-smooth — genuine science non-differentiability; the module monitors the gap and
  the `q`-relaxation eigenvalue and **refuses** rather than averaging through.

Adds **no new inner solve**: `G(q)=0` is N3 reused; the eigenvalue is a linear-algebra sweep, not a
Newton solve.

## Running nested-solve inventory (complete)
Across all six targets, the genuine iterative inner solves the engine must own as implicit-node
primitives are exactly:
- **N1** — leaf stomatal `ci` root; denominator `A′·umol_to_mol + gc·inv_atm > 0`.
- **N3** — leaf collar optimum `q*` (base TF24); denominator `dG/dq < 0`; reused as the TF24f BVP pin.
- **birth height** `lift_birth_height` — IFT at an existing root (one Newton step), not iterative on the
  gap.
Everything else — the light scan (#6), the transport spline composition N2 (#1), the soil
antiderivative-difference `E_i` (#3), the crown quadrature (#2) — is closed-form / Leibniz / reduction,
carrying **no** hand-written adjoint. Two sign-definite scalar IFTs is the whole tape-aware solve
surface for the plant family. That is the design's "scarce resource minimised" claim, now itemised.
