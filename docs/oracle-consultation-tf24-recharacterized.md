# Follow-on: the decomposition's cheap block is not where cost or accuracy live — is the fast/slow axis wrong?

A numerical-methods question. No application context is needed or given. This **follows five prior
rounds** on the same IVP (two problem rounds, a cost-structure round, a collocation round, and a
verdict round). The settled facts are restated inline so this stands alone. Since the last round we
**built** the recommended decomposition on the real, fully-evolving system — and also built a
single-step implicit variant — and the measurements **relocate both the dominant cost and the
accuracy limit to the large block the decomposition freezes**, and **refute the prior localisation of
the step-collapse to the small block**. We would rather you **re-derive the right axis from the
structure** than refine the existing decomposition. If the data say the fast/slow split is on the
wrong object, say so.

Prior rounds were framed thinly enough that we pursued dead ends; this statement keeps the full
structure. Two features earlier rounds under-described are foregrounded here only to the extent of
being *present* — a second coupling channel, and a moving interior threshold in the integrand — and
are then listed flat with everything else for you to rank.

## Settled from prior rounds (treat as established; do not re-litigate)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an **adaptive embedded explicit RK** with a
local-error controller; `10³–10⁵` accepted steps at a single global step size. `y` splits into a
**large block `x ∈ ℝ^M`** (`M ≈ 50–800`, and multiplying further when several independent large
blocks share the small block) and a **small block `u ∈ ℝ^L`, `L ≤ 5`**. Downstream we take
**reverse-mode gradients** (a tape recording every RK stage) of a scalar functional `J` w.r.t. a small
`θ`; the gradient must match a finite difference of the solver as run.

**Two coupling channels, of different cost and character:**

```
p_j*     = argmax_p P(p ; x_j, u, s(x)),   fixed-iteration derivative-free bracketing search
ẋ_j      = g(x_j, u, s(x), p_j*)                                   j = 1..M
a_ℓ(x,u) = Σ_{j=1}^M ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1..L          (channel 1: x → u, expensive)
u̇_ℓ      = b_ℓ(u,t) + [inter-component transfer in u] − a_ℓ(x,u)
s(x)     = cheap low-dimensional aggregate of the whole large block (channel 2: x → x)
```

- **Channel 1 (`a`, x→u): expensive, `u`-dependent, an O(`M`) byproduct.** `ξ_j` is an **ordered
  scalar member coordinate** (a component of `x_j`); `ρ_j ≥ 0` a per-member weight; `a` is a
  **density-weighted quadrature** `∫ c(ξ,u,p(ξ)) ρ(ξ) dξ`. Each `c_ℓ(ξ_j,u,p_j*)` is a **byproduct of
  the same per-member solve** that yields `ẋ_j`, so obtaining `a` costs the full O(`M`) solve set, and
  `a` at a new `u` (`x` held) still requires re-running the `M` solves.
- **Channel 2 (`s(x)`, x→x): cheap, size-only.** The large-block rates `ẋ_j` read a single
  low-dimensional aggregate of the whole large block (cost flat in `M`); it is an all-to-all coupling
  *among the members* through a cheap summary, carrying no `u`-dependence. In the decomposition it is
  frozen once per macro leg.
- **The inner control `p_j*` is an argmax**, solved by a **deliberately fixed-iteration** derivative-
  free bracketing search (not Newton/Brent) so that `p_j*` is a *smooth, fixed-iteration* function of
  its inputs — required because the tape differentiates through it. `∂P/∂p` is available **exactly**
  (IFT).
- **Per-member cost (consistent units):** `u`-dependent setup ≈ 11 (measured cacheable per leg, not
  per `u`); one objective eval (setup done) ≈ 4.6; full argmax ≈ 21. The `ẋ_j` require **all `M`**
  member solves regardless of how `u` is advanced — a floor common to every scheme.
- **The step-controller collapse is accuracy-driven, not stability-driven** (`corr(logΔt,logd) =
  −0.91`); global explicit RK reaches a **converged `J` at modest tolerance and cost**, and only fails
  ~3 decades past `J`-convergence at a near-kink wall (cleared by shrinking `h_min` → a resolution
  limit, not a stability limit).
- **`J` is ~10× hypersensitive:** a coupling error of `x`% shows up as ~`10x`% in `J`, with ~23%
  spread between independently-converged schemes at large `M`. Approximate schemes must be judged in
  **`J`-units, not `u`-units**.
- **Refuted as step-enlargers (measured, prior rounds):** QSS reduction of `u`; held/slow-refreshed
  coupling (the true fast Jacobian of `u` includes `a`'s `u`-dependence, so `a` must live inside the
  fast dynamics).
- **The adjoint of the inner solve is not available by differentiating the RHS.** Because the inner
  argmax is fixed-iteration-for-smoothness and the member solve is not built at the tape's scalar
  type, `∂c/∂u` for the adjoint is supplied by an **envelope-theorem finite difference at fixed
  `p_j*`** (at the argmax `∂P/∂p* = 0`, so `p*`'s motion contributes nothing to first order). **A full
  forward-mode Jacobian of `f` in the tape scalar cannot be formed** — the per-member solve is
  deliberately not an AD citizen.

## What we built since, and measured on the real *evolving* system (the payload; some of it refutes the above)

All numbers are on the **full coupled system with the large block evolving** (members inserted/refined
on an adaptive schedule during the run) under a realistic kinked `b(·,t)` — **not** a surrogate and
**not** a frozen-large-block window. Prior rounds' quantitative claims were largely measured on frozen
`x` windows or a reduced surrogate; that is the gap this round closes.

1. **Making the small block implicit makes it *worse* — refuting the localisation of the collapse to
   `u`.** We built a single-step linearly-implicit (Rosenbrock/RODAS4) method with the Jacobian
   **restricted to the small block `u`** (finite-differenced through the full RHS, so `a`'s
   `u`-dependence is captured), explicit on `x`, one global step. On a representative episode:
   | tol | explicit RK: RHS-evals / wall | implicit-`u`: RHS-evals / wall | ratio |
   |---|---|---|---|
   | 1e-4 | 4 629 / 8 s | 100 557 / 452 s | 21.7× more evals (correct: `J`-err 3.6e-2) |
   | 1e-5 | 8 859 / 15 s | 462 641 / 2180 s | 52.2× more evals (correct: `J`-err 1.7e-3) |
   It is *accurate* but takes **more, smaller** steps, and the deficit **grows** as tolerance tightens
   (21.7×→52.2×). ~8–20× of that is more accepted steps (only ~2.5× is Jacobian-FD inflation). **An
   implicit treatment of `u` buys negative step enlargement** → the accuracy-driven collapse is **not
   localised to `u`**; the step-limiting non-smoothness lives in the **large block `x`** (the argmax
   control kink in `u`, member-insertion/refinement events, and the moving threshold below).

2. **Reformulating the small block's coordinate is neutral; the accuracy limit is in resolving `x` on
   the macro grid.** Re-charting `u` to remove its near-singular self-loss (`u ← ln(u−u_min)`) leaves
   `J` unchanged. And the decomposition at **full** coupling (no member reduction) is already **~24%
   off** the tight single-rate reference on an evolved large block — before any approximation — an
   error intrinsic to advancing `x` across the macro step, not to `u` or the coupling.

3. **The decomposition's mechanics work but it does not beat global RK on the evolving system.** The
   macro/micro partition cuts *large-block* evaluations ~7.6×, but each micro step of `u` re-pays the
   O(`M`) coupling, so the sub-cycle is **slower** than global RK unless the coupling is reduced — and
   the reduction is what fails next.

4. **Member-reduction of the coupling degrades ~10²–10³ on the *evolved* member set** (confirms and
   extends the prior "Probe C" at full scale). Truth = full-`M` coupling at the evolved state.
   Reducing to `m` by subsampling the evolved members: `m=20 → ~296%`, `m=40 → ~116%` error, vs
   `< 0.5%` at `m ≈ 15–20` on a prescribed/frozen set. The evolved weight profile `ρ(ξ)` is **highly
   skewed** (mass in a few members; many have `ρ_j → 0`, `log ρ_j → −∞`), the `ξ_j` are placed by the
   schedule to resolve `x(t)` **not** the integrand `c·ρ`, and `c(ξ,·)` develops **interior kinks**
   from the threshold in (5) — so subsampling misses the mass and straddles the kinks.

## Structural features — any may be load-bearing or incidental; we do not know which

The two coupling channels (`a`: x→u, expensive, `u`-dependent, O(`M`) byproduct; `s(x)`: x→x, cheap,
size-only, `u`-independent); the inner argmax control `p_j*` (fixed-iteration for tape-smoothness;
exact `∂P/∂p`); a **moving interior threshold in the integrand**: `c_ℓ(ξ,u,·)` is smooth on one side
of a boundary in the `(ξ,u)` plane and identically zero on the other (a member "switches off"), the
boundary moves with `u`, and different members cross it as `u` evolves — so the integrand `c·ρ` has
state-dependent interior kinks; the **skewed, evolving weight profile `ρ`**; the member set placed by
an adaptive schedule that resolves `x(t)`, not `c·ρ`; the near-singular closed-form self-loss of `u`
at `u_min` (exponent `q ≈ 16`) with a positivity-preserving clamp; the kinked `b(·,t)`; a **timescale
separation of ~10²–10³** between `u` (fast, forced by `b`) and `x` (slow) — yet the isolated
non-smoothnesses (argmax kink, insertion events, threshold crossings) force the controller to steps
~`10⁻⁹` of the horizon at scattered points; the single global step size; the large-block rates `ẋ_j`
needing all `M` solves regardless; the per-member setup (≈11) cacheable per leg; the argmax not an AD
citizen (adjoint via envelope-FD at fixed `p*`; no forward Jacobian of `f`); the ~10× amplification of
coupling error into `J` and ~23% inter-scheme spread; the fact that global explicit RK already reaches
converged `J` cheaply and only fails past it at a resolution wall; that all prior favourable
measurements were on frozen-`x` windows.

## Facts an answer can rely on

- `a(x,u)` is only obtainable via the `M` member solves; nonlinearly, non-separably `u`-dependent
  (frozen/low-order-in-`u` surrogate refuted).
- The `ẋ_j` require all `M` member solves regardless of how `u` is advanced — common to every scheme.
- An implicit treatment of `u` is measured **20–50× worse** than global explicit RK, worsening with
  tolerance; a full-`M` decomposition is ~24% off truth on an evolved `x` before any reduction.
- Member-reduction of the coupling is `<0.5%` on a prescribed/frozen set but `25–279%` on the evolved
  set; `J` amplifies coupling error ~10×.
- A full-`M` evaluation of **both** channels is available free at every macro-stage boundary (the
  frozen `x` is present).
- No forward-mode Jacobian of `f` is available (the inner solve is not differentiable at the tape
  scalar); finite-difference / envelope-FD are the only routes to `∂a/∂u`. The reverse-mode adjoint
  cost tracks accepted steps.
- A documented, controlled change of discretisation is acceptable if the forward solution and the
  reverse-mode gradient stay correct.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Given that both the dominant cost (all `M` member solves) and the accuracy limit (the step
   collapse) live in the large block `x` that the decomposition freezes — while the small block `u`
   the decomposition sub-cycles is cheap and, measured, not the limiter — is a fast/slow split on this
   `(x,u)` axis the right frame at all?** If a decomposition can still beat global explicit RK at
   converged `J`, name it, the **block it acts on**, and the structural property it exploits that we
   have missed. If not, say so.
2. **Is the accuracy-limiting non-smoothness in `x` removable or intrinsic?** It comprises the argmax
   control kink (in `u`), the adaptive member-insertion/refinement events, and the moving interior
   threshold where members switch off. Which of these is a *representational* artefact (an event to be
   handled, a control to be tracked as a differential state rather than an argmax, a boundary to be
   split at) versus *genuine* fast solution structure any same-order method must resolve? What cheap
   measurement separates them?
3. **Do the two channels' different characters offer any leverage** — e.g. large implicit/exponential
   steps on the slow large block while the cheap small block rides along — or does the "all `M` solves
   per step" floor foreclose any large-block-side integrator gain, making constant-factor per-solve
   reduction the only remaining lever?
4. **Does the ~10× `J`-amplification, combined with the skewed evolving `ρ` and the interior kinks,
   forbid *any* approximate-`x` scheme on the gradient path** — or is there a defect-corrected/anchored
   form (a full-`M` evaluation is free at macro boundaries) whose `J`-error stays in budget on the
   evolved set?
5. Which measured fact is **load-bearing** for the verdict, and which is incidental?
6. **What are we missing?** A structural simplification, a hidden cost, or an assumption in our framing
   — that the member mesh must be resolved to its current schedule tolerance, that `J` must be taken as
   given rather than reformulated to be less sensitive, that the inner solve must stay non-differentiable,
   that a single global step size is required — that the data quietly contradict.
7. A **cheap discriminating experiment** for whatever strategy you judge best — before we build it.
