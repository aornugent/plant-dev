# Follow-on: reduced-member coupling degrades on the *evolved* member set — is member-reduction the right lever?

A numerical-methods question. No application context is needed or given. This **follows three prior
rounds** on the same IVP (two problem rounds plus the cost-structure round whose strategy we then built).
The settled facts are restated inline so this stands alone. Since the last round we have **built** the
recommended scheme and run it on the real system, and one new measurement **qualifies a pillar the last
round's strategy rests on** (the "m ≈ 15–20 members suffice" result). We would rather you **re-rank the
levers from the structure** than defend the member-reduction pillar. If the data say we are reducing
along the wrong axis, say so.

## Settled from prior rounds (treat as established; do not re-litigate)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an **adaptive embedded explicit RK** with a
local-error controller; `10³–10⁵` accepted steps at a single global step size. `y` splits into a **large
block `x ∈ ℝ^M`** (`M ≈ 50–800`) and a **small block `u ∈ ℝ^L`, `L ≤ 5`**, two-way coupled. Downstream
we take **reverse-mode gradients** (a tape recording every RK stage) of a scalar functional `J` w.r.t. a
small `θ`; the gradient must match a finite difference of the solver as run.

- The step-controller collapse is **accuracy-driven, not stability-driven**, localised to `u`'s
  excursions toward a lower bound `u_min` where a cheap closed-form part of `u̇` is near-singular
  (`∂/∂u` spans orders of magnitude; non-Lipschitz at the bound → a clamp) and where a **kinked,
  piecewise-smooth time-inhomogeneity** `b(·,t)` drives rapid excursions (`corr(logΔt, logd) = −0.91`).
- **QSS reduction of `u`** and **A-stable/implicit stepping** are both refuted as step-enlargers
  (measured). **Held/slow-refreshed coupling** is refuted: the true fast Jacobian of `u` includes the
  coupling's `u`-dependence, so the coupling must live **inside** the fast dynamics.
- Cost structure. Each member `j = 1..M` carries a scalar **control `p_j`**. The coupling and rates are

  ```
  p_j*   = argmax_p P(p ; x_j, u, s(x)),   fixed-iteration derivative-free bracketing search
  ẋ_j    = g(x_j, u, s, p_j*)
  a_ℓ(x,u) = Σ_{j=1}^M ρ_j · c_ℓ(ξ_j, u, p_j),  ℓ = 1..L      (the coupling)
  u̇_ℓ    = b_ℓ(u,t) + [inter-component transfer in u] − a_ℓ(x,u)
  ```

  `ξ_j` is an **ordered scalar member coordinate** (a component of `x_j`), `ρ_j ≥ 0` a per-member weight;
  `a` is a **density-weighted quadrature** `∫ c(ξ,u,p(ξ)) ρ(ξ) dξ` over that coordinate. `s(x)` is a
  cheap aggregate (cost flat in `M`). Measured per-member cost (consistent units): `u`-dependent
  **setup ≈ 11**; one objective eval (setup done) **≈ 4.6**; full **argmax ≈ 21**. `∂P/∂p` is available
  **exactly** (IFT). The coupling is an **O(`M`) byproduct** of the member solves; no separate cheap route.
- Prior round's **endorsed strategy** (which we built): keep the multirate skeleton; make the fast RHS
  cheap by three moves — **(i) reduce the coupling to `m ≈ 15–20` members** ("Probe B"); **(ii) promote
  each control `p_j` from an argmax to a slow tracked state `ṗ_j = k·∂P/∂p`** (removes the fragile inner
  search from the fast loop); **(iii) pay the `u`-dependent setup once per micro stage.** Moves (ii)–(iii)
  stand. This round is about **move (i)**.

## What we have built since (new settled facts)

- **The multirate scheme runs on the real system and resolves the step-collapse.** Macro grid = the kink
  grid of `b(·,t)`; per macro step we **freeze the whole large block** `x` (coordinates `ξ_j`, weights
  `ρ_j`, controls `p_j`), **sub-cycle `u`** with the adaptive RK reading `a(x,u)` from the frozen `x` at
  each micro step, then advance `x` across the macro step. At the macro grid it is **stable and accurate
  where a fixed-step global explicit blows up**; the forward solution matches a tight single-rate
  reference to **≈ 0.5 %**. So the original problem (the accuracy-driven collapse) is handled by the
  skeleton itself, independent of how cheap the fast RHS is.
- **The near-singular part of `u̇` has an exact flow map.** The stiff piece is a per-component self-loss
  `−κ(u_ℓ)`, `κ(u) = c·u^q`, `q ≈ 16`, with a closed-form, positivity-preserving recession
  `u_ℓ(Δt) = [u_ℓ^{1−q} + (q−1)c·Δt]^{−1/(q−1)}`, floored at `u_min`. The split
  `{exact recession} ∘ {gentle remainder: b + transfer − a}` reproduces `u̇` and **removes the stiffness
  from the sub-cycle** (the remainder is non-stiff → large micro steps). Built and validated in isolation
  (a low-order Rosenbrock on the remainder matches an adaptive black-box inner); **not yet composed with
  the member solves in the live sub-cycle.**

So the fast-block cost is a **product of two independently reducible factors**:

```
sub-cycle cost per macro step  ≈  (# micro steps of u)  ×  (cost of one a-evaluation ≈ O(M) member solves)
```

- **Lever 1 — fewer micro steps:** the exact-flow split removes the stiff self-loss → the remainder
  sub-cycle takes far fewer, larger micro steps. Exact physics; no accuracy knob.
- **Lever 2 — cheaper per micro step:** reduce the coupling quadrature from `M` to `m` members (move (i)).
  This is the one carrying an accuracy approximation — and the one the new probe undercuts.

**We have not yet measured `# micro steps` in the live composition**, so which factor dominates the
cost — hence which lever carries the win — is open.

## The new information (the payload — it qualifies Probe B)

Prior "Probe B" measured member-reduction on a **prescribed, smooth** member distribution (coordinates
`ξ_j` uniform in a transformed variable, weights `ρ_j` a smooth analytic profile) and found `a` recon-
structed from `m ≈ 15–20` members to **< 0.5 %** (≈ O(`m⁻²`), trapezoidal). The new probes re-measure on
the member set the system **actually produces**, and on the functional.

**Probe C — reduced-member accuracy on the *evolved* member set.** The member set is **not** free sample
points: `{ξ_j, ρ_j}` are part of `y`, advanced by the dynamics and by an **adaptive member-insertion/
refinement schedule that places members to resolve the large-block solution `x(t)`** — *not* the coupling
integrand `c·ρ`. Truth = the full-`M` coupling at the evolved state.

- **Early / near-uniform member set:** ≈ Probe B (sub-1 % by `m ≈ 20`).
- **Mature member set** (after long integration; `M ≈ 90`), reduced by uniform member-index subsampling:
  `m = 20 → 38 %` error in `a` (and in the resulting `u`); `m = 40 → 22 %`; `m = 80 → 0.8 %`. Convergence
  is still ≈ O(`m⁻²`) but the **constant is ~10² larger** than Probe B — sub-1 % needs `m` near `M`.
- **Cause identified:** the evolved weight profile `ρ(ξ)` is **highly skewed** (mass concentrated in a few
  members) and the `ξ_j` are placed for `x(t)`, not for `c·ρ`; uniform-index subsampling misses the mass.
  Interpolating `ρ` onto synthetic coordinates was **worse** (and produced NaNs where `ρ_j → 0`, i.e.
  `log ρ_j → −∞`); subsampling the members' **own** `(ξ_j, ρ_j)` was better but still `m ≈ M` for sub-1 %.

**Probe D — functional sensitivity.** `J` (a time-integral of a member-weighted rate, the reverse-mode
target) is **hypersensitive to the coupling accuracy**: at `m = 80` (coupling/`u` error 0.8 %) the error
in `J` is **≈ 9 %** — a ~10× amplification. Even a near-exact reduced-member coupling yields a large
functional error, and `J` is exactly what the gradient must reproduce.

## Structural features — any may be load-bearing or incidental; we do not know which

The exact-flow self-loss of `u` and its closed-form recession; the clamp at `u_min`; the near-singular
`∂/∂u` there; the kinked `b(·,t)`; the global shared step size (now overlaid by a fixed macro grid on the
kinks); the two-way coupling; `a` as an O(`M`) byproduct with no cheap route; the **member set placed by
an adaptive schedule that resolves `x(t)`, not `c·ρ`**; the **skewed, evolving weight profile `ρ`**; the
smoothness of `c` and of `p*` in the member coordinate (holds for prescribed sets — Probe B); the ~10²
gap between prescribed and evolved member sets (Probe C); the ~10× functional amplification of coupling
error (Probe D); the tracked-control option (`ṗ_j = k·∂P/∂p`); the exact cheap `∂P/∂p`; `L ≤ 5`; the
large-block rates `ẋ_j` needing all `M` member solves regardless of the coupling; the reverse-mode tape
whose cost tracks accepted steps; the fact that `# micro steps` under the exact-flow split is unmeasured.

## Facts an answer can rely on

- `a(x,u)` is only obtainable via the member solves and is nonlinearly, non-separably `u`-dependent
  (frozen/low-order-in-`u` surrogate refuted in prior rounds).
- The exact-flow split of `u̇` reproduces the dynamics exactly and is positivity-preserving; it reduces
  `# micro steps` but does nothing to the O(`M`) per-evaluation cost.
- Reduced-member quadrature reduces the per-evaluation cost O(`M`)→O(`m`) but, on the evolved member set,
  needs `m ≈ M` for sub-1 % (Probe C), and `J` amplifies its residual error ~10× (Probe D).
- The `ẋ_j` require all `M` member solves regardless of how `u` is advanced — common to every scheme, not
  the target.
- A **full-`M`** coupling evaluation is available at every macro-stage boundary (the frozen `x` is there);
  only the **per-micro-step** coupling is where O(`M`) hurts.
- A documented, controlled change of discretisation is acceptable if the forward solution and the
  reverse-mode gradient stay correct. An implicit/Rosenbrock micro-integrator is available for any sub-block.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Is member-count reduction the right lever at all?** It underpinned the prior strategy, but on the
   evolved member set it degrades ~10² (Probe C) and `J` amplifies its error ~10× (Probe D). Given the
   members are adaptively placed for `x(t)` (not for `c·ρ`), `ρ` is skewed and evolving, and the target
   functional is hypersensitive — name the lever/decomposition you would actually choose.
2. **Which lever should carry the win, given `# micro steps` is unmeasured?** If the exact-flow split
   (Lever 1) shrinks `# micro steps` enough, an **exact** O(`M`) coupling per micro step may already be
   cheap — making Lever 2's accuracy risk unnecessary. What is the cheap experiment that decides whether
   Lever 1 alone suffices before we invest in Lever 2?
3. **Does the ~10× functional amplification (Probe D) forbid approximate coupling on the gradient path?**
   Or is there a correction that keeps the micro RHS cheap yet the functional/gradient exact-to-O(macro)
   — e.g. anchor the reduced-member coupling with a per-macro-stage full-`M` evaluation and carry the
   constant defect `Δ = a_full − a_reduced` across the leg (`Δ` constant in `u` → fast Jacobian untouched)?
4. **If reduced-member quadrature survives:** what placement/quadrature suits a *skewed, adaptively-placed*
   member set whose coordinates resolve a different function (`x(t)`) than the one integrated (`c·ρ`)?
   Reuse the members' own weights; importance-place by `|c·ρ|`; a defect-corrected small `m`; something else?
5. Which measured fact is **load-bearing** for the achievable cost, and which is incidental?
6. **What are we missing?** Is there a structural simplification, a hidden cost, or an assumption the data
   quietly contradict — including whether the multirate skeleton is still the right frame now that the
   step-collapse is already resolved by it and only the per-step cost remains?
7. A **cheap discriminating experiment** for whatever strategy you judge best — before we build it.
