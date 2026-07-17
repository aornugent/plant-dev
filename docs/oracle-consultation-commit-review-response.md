# Oracle response — commit review: breadth + depth

*Response to [`oracle-consultation-commit-review.md`](./oracle-consultation-commit-review.md). Recorded
2026-07-17. Hypotheses to test, not verdicts (guide §7); the top footgun (B3 gradient-reduction bias)
is the discriminating experiment to run before building.*

---

## Verdict

**The factorization stands; nothing in the data demands a reframe.** The triple `(MRI multirate) ×
(tracked controls) × (member collocation)` is right — each factor is forced by a measurement. But **two
of the three factors are under-collapsed**, and one conceptual clarification pays for itself. Build what
we converged on, with three amendments (refinements, not redesigns).

## B1 — collapse the control block from m states to ~1 (the biggest win)

Quadrature resolution and control-state resolution are **different requirements the current design
accidentally couples.** `p*(x;u,s)` is nearly flat in the member coordinate (measured near-invariance),
so the m tracked trajectories are highly redundant.
- **Rung 1 (maximal):** one tracked scalar `p̄` with `ṗ̄ = k·Σ_n ω_n G(p̄; x̂_n,u,ŝ)` (`G=∂P/∂p`),
  per-node controls recovered by **one closed-form Newton correction**
  `p̂_n = clamp(p̄ − G(p̄;x̂_n,u,ŝ)/P_pp(p̄;x̂_n,u,ŝ))` — smooth, exact to O(δp²), taped as elementary
  arithmetic using the **exact `P_pp`** we already have. Fast state `(u, p̄) ∈ ℝ^{L+1}`.
- **Rung 2:** low-order polynomial control field `p̂(x)=Σ_{r≤3} π_r φ_r(x)`, coefficients as tracked
  states (Galerkin-projected gradient flow).
- **Fallback:** per-node states (current design), only where `P_pp` degenerates — near the bound, where
  we already clamp.
- **Buys:** smaller stiff system + Jacobian, fewer tape entries, and **`m` becomes a pure quadrature
  knob** (raise at the singular end without adding dynamics). **Costs:** a degeneracy guard on `1/P_pp`
  (switch node to fallback below a floor — a pass-1 recorded decision, replayed passive).
- **Size it with one offline measurement:** the spread `max_n|p*_n − p̄*|` and the `P_pp` margin along
  recorded excursions.

## B2 — the k-relaxation is a regularized index-1 DAE; pin k, keep the DAE as escape hatch

`ṗ̂ = k·G` at `k→∞` is the semi-explicit index-1 DAE `u̇ = b−a, 0 = G(p̂;·)`. Because each `G_n` depends
only on its own `p̂_n`, the algebraic Jacobian is **diagonal** → a linearly-implicit stage eliminates it
by m scalar divisions + an L×L Schur solve, essentially free (ROS34PW2 handles it natively). **But ship
the tracked variant:** (i) lag error at the knee (~2e-4) is an order below quadrature error (0.5%) — not
the bottleneck; (ii) the DAE reinstates the instantaneous-argmax's near-kink in `u` at the bound (the
ill-conditioning that made Probe A's Newton diverge) — the relaxation is quietly smoothing it, so the
tracked model is **better-posed exactly where it's hardest**; (iii) the DAE needs active-set switching at
the bound. **k-selection policy: fix k at the measured knee, never adapt** (cranking k buys lag ∝ 1/k
only until quadrature dominates — already true — while stiffening `p̂` for nothing). If argmax-exactness
is ever demanded, switch variants; don't turn the knob.

## B3 — quadrature is ~2× from optimal, and it hides the one gradient bias validation can't see

- **Piecewise-Chebyshev (barycentric)** instead of piecewise-linear → **spectral per piece, m≈8–12**
  total, same weight construction `W_n=Σ_j ℓ_n(x_j)w_j` (active in `x_j`, built once per leg).
- **Free anchored defect correction:** the full-M aggregate is computed anyway at each macro stage (the
  `ẋ_j` need all M solves); record `Δ = a_full(u_stage) − a_colloc(u_stage)` and use
  `a := a_colloc(u) + Δ` across the leg. Both active on tape; `Δ` constant in `u` → fast Jacobian
  untouched; residual becomes the *variation* of quadrature error over the leg, not its absolute size.
- **Interior regime-boundary kinks** (near-singular end) interact with node identity (crossing `x*(u)`
  moves at micro rate; nodes fixed per leg). In preference order: **(a) smooth the regime switch at a
  declared scale in the member model** (one-line, restores high-order quadrature everywhere, no new
  machinery); (b) fixed nodes + pass-1 clustering in the crossing corridor (reduced local order); (c)
  active splits at `x*` with mapped nodes (exact Leibniz, but makes node positions micro-rate-active).
- **The footgun this section exists to flag:** *1e-8 adjoint-vs-FD certifies consistency, not reduction
  accuracy.* The gradient of the m-member scheme can differ from the gradient of the full-M scheme by
  **more than the values differ** — differentiating a kink-crossing quadrature error is exactly where.
  **Add gradient-vs-m and gradient-vs-k Richardson checks against a full-M / small-lag reference.** An
  outer optimizer will find and exploit any systematic reduction bias; measure it before it does.

## B4 — dead candidates + ranking

Dead: tensor/separable structure in `u` (non-separable; the micro path is 1-D in a ≤5-D box —
tabulation wasteful); slow-manifold view (= the B2 DAE limit); desingularization is a *micro-integrator
refinement* (fewer steps, Lipschitz tape near the bound) not a reframe. **Underused leverage, ranked:**
(1) `p*` near-invariance (B1); (2) member-coordinate smoothness beyond linear + free full-M anchor (B3);
(3) the exact `∂²P/∂p²` (powers B1's correction, B2's Schur, the micro Jacobian). Incidental: kinked
forcing (handled by grid alignment + splits), `s(x)`, u→x direction, exact L/M, global shared step.

## D4 — method choices + references

- **MRI table:** MRI-GARK-ERK33a workhorse, ERK45a if slow-order sweeps justify (Sandu, SINUM 2019; MIS
  lineage Wensch–Knoth–Galant, BIT 2009; H-Tol adaptivity Fish & Reynolds; ARKODE MRIStep as diff-test
  oracle). Fast-block local stiffness puts **no** constraint on the table — the infinitesimal
  formulation makes the inner a black box. Resist decoupled-implicit MRI (slow block is nonstiff).
- **Micro-stepper:** **ROS34PW2** (Rang & Angermann ~2005) — Rosenbrock-W, L-stable, stiffly accurate,
  valid for semi-explicit index-1 DAEs; covers the tracked variant, the B2 DAE variant, and the stiff
  wet end, with an embedded pair for pass-1 control. ROS3PRw (Rang ~2015) if order-reduction shows. The
  W-property's real payoff: **the Jacobian may be approximate → recorded passive on the tape**. Assemble
  `J` with arrow structure `[[∂(b−a)/∂u, −W·∂c/∂p̂],[k·∂G/∂u, k·diag(P_pp)]]`; eliminate the diagonal
  `p̂`-block scalar-wise, solve the L×L Schur; store pass-1 factorization pieces so pass-2 adjoint is
  transposed backsolves with recorded matrices (no refactorization). Refresh `J` every micro step near
  the bound, per-leg elsewhere.
- **Events at the bound:** **projected gradient flow** (touch: `p̂_n` hits bound with outward drive;
  pinned: rate zeroed; release: `G_n(bound)` crosses inward). Locate on Rosenbrock dense output, pass-1
  bracket (passive) + pass-2 active scalar-IFT root so the substep length is active. Adjoint Leibniz:
  `dt* = −(g_y·dy + g_θ·dθ)/(g_t + g_y·f)`; deposits `(f⁺−f⁻)ᵀλ·t̄*` automatically once the substep
  length is an active root. **Guard transversality** (pass-1 assert `|dg/dt|` not small — grazing makes
  the IFT divide-by-zero and the adjoint blow up silently). State bound `u_min`: desingularized coord for
  approach + event/active-set for contact (complementary).

## D5 — elegant vs naive

Node placement/weights per-leg, pass-1, piecewise-Chebyshev barycentric; monitor `Σ|W_n|/|ΣW_n|`
(Lebesgue proxy — strongly negative weights amplify solve noise in aggregate + adjoint). Use the free
full-M comparison each macro stage as the m/split refinement signal. **k fixed at the knee** (adaptive k
= schedule-contract headache for zero benefit). Setup cache **identity-keyed per (leg,node)** — heavy
part depends on `(x̂_n,ŝ)`, frozen per leg; invalidate on leg advance; never value-keyed. Checkpoints:
canonical state at macro boundaries; per leg store micro grid, event brackets, factorization pieces, all
micro states (kB/episode) → pass-2 re-record is solve-free, divergence-proof. **Align member-insertion
to macro boundaries** (mid-leg insertion desyncs frozen `W_n` from the population the slow stage sees).

## D6 — footguns not yet on our list

1. **Reduction bias in gradients** (B3) — the most likely quiet failure; Richardson-in-(m,k) gradient
   checks are the insurance.
2. **Kink-crossing quadrature error whose u-derivative oscillates** even when the value converges —
   symptom: gradient-vs-m slower than value-vs-m; cure: model-level smoothing of the switch.
3. **Clamp chattering** near-degenerate `P_pp` — touch/release storms; add a pass-1 hysteresis band
   (replayed passive).
4. **Grazing events** near the singular end — transversality guard must be a hard pass-1 assertion.
5. **Two clocks** — kinks in absolute t, forcing polynomials in leg-normalized τ; a micro step must
   never straddle a recorded kink (Rosenbrock order collapses; tape differentiates across the kink).
6. **`1/P_pp` divisions** (B1, B2) — sign-definiteness assertions + recorded hybrid-switch to per-node
   (pass-1 data, never a pass-2 value-dependent branch).
7. **Argmax-off-tape at init** — finite bracketing accuracy + relaxation transient → O(e^{−kt})
   initialization layer; irrelevant at our T, one doc line so it isn't discovered in a small-T unit test.

## Net + our next action

Build the converged design with three amendments: **B1** (collapse control block — biggest win, one
measurement to size), **B3** (piecewise-Chebyshev + full-M anchor — halves m, closes the unvalidated
gradient channel), **B2** (pin k, DAE documented as escape). Everything else is execution detail.

**Discriminating experiment (run first, guide §7):** the **B3 gradient-reduction-bias check** — it is
the "single most likely way this design quietly misleads," and it is a genuine gap in E4 (which
certified adjoint = FD at *fixed* m, not gradient-of-reduced ≈ gradient-of-full). **B1 sizing** (spread
of `p*` + `P_pp` margin) is the build-time measurement on the real cohorts.

## B3 footgun measured (2026-07-17) — `scripts/tf24-multirate/e4_bias_test.R` — CONFIRMED, and the cure works

Extended the E4 surrogate with an interior member-coordinate regime boundary whose crossing **moves
with `u`** (members shut off as the soil aggregate drops), and measured the adjoint's self-consistency
(adjoint vs frozen-record FD of the *m*-scheme) as `m` refines, hard switch vs smoothed:

| variant | adj vs FD (m = 8 → 64) |
|---|---|
| no kink (smooth coupling) | ~1e-9 throughout |
| **hard moving kink** | **4.5e-3 → 4e-4** |
| **smoothed kink (width 0.1 = cure a)** | **~1e-9 restored** |

The hard kink degrades adjoint-vs-FD by **5–6 orders** — the m-scheme is **non-differentiable at the
moving crossing**, so its own adjoint stops matching its own FD. This is precisely the failure a
"1e-8 adjoint=FD on the *smooth* surrogate" check (our E4) does not catch until the real model's
layer-shutdown boundaries bite. **Model-level smoothing of the regime switch (the Oracle's cure a)
fully restores consistency (~1e-9).**

**Consequences for the build (now locked):**
1. **Smooth every member-coordinate regime switch at a declared scale** (leaf layer-shutdown / uptake
   on-off) — a one-line model-side change; it restores high-order quadrature *and* a differentiable tape
   everywhere, and needs no new machinery. This is a **prerequisite**, not an optimisation.
2. Keep the harness's **adjoint-vs-FD self-consistency check on a kink-carrying surrogate** (not just a
   smooth one) as the standing regression gate, plus the gradient-vs-`m`/`k` Richardson checks against a
   full-M / small-lag reference on representative runs.

With this, the commit review is discharged: the design stands, the three amendments (B1 control-block
collapse, B2 pin-k-DAE-escape, B3 spectral quadrature + full-M anchor) are adopted, and the top footgun
is measured with its cure in hand. Nothing further gates the #2 build.

## H0 (envelope identity) checked — does NOT hold for TF24; both models supported without it

The Oracle's H0 (if the coupling byproduct `c_ℓ = ∂P/∂u_ℓ` at the optimum, then `a = ∇_u V`,
`V = Σ_j max_p P`, and the fast dynamics never reference `p*`) would be the one option that removes
`p*` entirely and unifies TF24 (argmax) and TF24f (tracked). **Checked — it does not hold for TF24, on
structure:** the quantity fed into the soil balance is the **water flux** `E` (`resource_depletion`, a
volume rate in `θ̇ = (in − drain − E)/dz`), whereas `∂P/∂u_ℓ` is a **marginal carbon profit**. Different
physical quantities / units; `E` is a constraint flux, not the gradient of the carbon objective. The
optimal-stomatal relation links `E` to `∂P/∂ψ_soil` only through the hydraulic supply function and a
shadow price `λ` — a model-specific relationship that would *reintroduce* `λ`/supply algebra, not
eliminate `p*`. (`h0_envelope_check.R`; a clean empirical ratio couldn't be shown because a transpiring
*standalone* leaf config isn't reachable through the R Leaf interface — the structural argument settles
it regardless.)

**Consequence — H0 is not needed to support both TF24 and TF24f.** The m-member collocation fast
subsystem already supports both by construction; they differ only in how the control is obtained at the
m collocation nodes: **TF24 re-optimises** the argmax there (option H2/H3 territory if kept exact),
**TF24f tracks** it (`dq/dt=k·dprofit`). E2/E3 measured that the two agree (tracked reproduces the
re-optimised/QSS soil trajectory to <1e-3). So "support both" is a property of the architecture, not of
H0. The envelope theorem still earns its keep on the **reverse** side (differentiating through the
optimised leaf, the `∂p*/∂input` terms drop by stationarity — which is *why* tracked and argmax gradients
agree to first order and why the adjoint is robust). If a future strategy's coupling were a carbon-flux
(so `c = ∂P/∂u`), H0 would apply and unify — worth a one-line check per new model.
