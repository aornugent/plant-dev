# Deepening #1 — the leaf inner-solve residuals (P1a instances)

Concretises target #1: the exact `F(y;p)=0` and sign-definite denominator for each genuine inner solve
in the TF24 leaf, so the FD `supplied_derivative` seam (`tf24_strategy.cpp:508–688`, ~150 ln) can be
deleted in favour of registered implicit-node primitives whose adjoints are machine-checked. Anchors:
`leaf_model.cpp`.

## The nesting, read off the exact analytic gradient (`dprofit_droot_collar_psi:890`)

The outer decision variable is `q = root-collar potential`. At a given `q`, the operating point is built
in three steps (`:896–897`, `:929–946`):

1. **Transport → `ψ_stem`** (`find_psi_stem_from_psi_root(−q)`): `ψ_stem = P(E_stem)`,
   `E_stem = E_up(−q)/k_max + S(q)`, with `S=transpiration_from_psi`, `P=psi_from_transpiration` (both
   C² splines) and `E_up` the soil→collar uptake (target #3).
2. **Stomatal `ci` root** (`psi_stem_to_ci(ψ_stem, q)`): a numerical root (`ci_niter`, `ci_abs_tol`).
3. **Profit + optimum**: `W(q) = A(ci(q)) − hydraulic_cost_TF(ψ_stem(q))`; base TF24 maximises `W` by
   golden section (`find_root_collar_psi:798`), i.e. solves `G(q)=dW/dq=0`.

Only steps 2 and 3 are genuine inner solves. Step 1 is a **closed-form spline composition**, not a root.

## The three components, made precise

### N1 — stomatal `ci` (a scalar-IFT node)
Residual (stomatal-supply = biochemical-demand, `:886`, `:925`):

    g(ci; ψ_stem, q) = A(ci)·umol_to_mol − gc(ψ_stem,q)·(ca − ci)·inv_atm = 0

- `A(ci) = assim_colimited` — the co-limitation **quadratic mean** of Rubisco- and electron-transport-
  limited rates (`:16` `assim_colimited_ad`): `ar = vcmax(ci−Γ*)/(ci+km)`, `ae = (et/4)(ci−Γ*)/(ci+2Γ*)`,
  `A = (s − √(s²−4·curv·ar·ae))/(2·curv) − R_d`, `s=ar+ae`. Closed-form in `ci` (the "quartic" is the
  algebraic degree of `g=0` once the √ and the linear supply term combine).
- `gc = gc_const·transpiration(ψ_stem,q)` (stomatal conductance supply).
- **Denominator (sign-definite):** `dg/dci = A′(ci)·umol_to_mol + gc·inv_atm > 0` — `A′>0` (assimilation
  rises with `ci`) and `gc>0`. Strictly positive ⇒ the IFT node denominator never vanishes. This is the
  assertion registered with the node.
- The IFT gives `dci/dψ_stem` and `dci/dq|_expl` (`:926–927`) — today hand-derived; under P1a these are
  the node's automatic reverse rule.

### N2 — transport `ψ_stem` (NOT an inner solve; a closed-form composition + breakpoint)
`ψ_stem = P(E_up(−q)/k_max + S(q))`. Its derivative is the analytic spline chain
`dψ_stem/dq = P′(E_stem)·(−E_up′(−q)/k_max + S′(q))` (`:944–946`). So N2 needs **no implicit node** — it
is a `StateView`/coupling read whose derivative is the spline `.deriv()`. The **only** subtlety is the
soil-layer-crossing kink: `E_up′` (`dE_from_soil_dpsi_collar`) returns NaN at a branch boundary and the
code falls back to a central difference (`:947–952`). Under the new engine that boundary is a
**breakpoint node** (target #3), so the fallback disappears — the Leibniz jump is exact.

### N3 — the optimum `q*` (a scalar-IFT node; base TF24 only)
Residual `G(q) = dW/dq = A′(ci)·dci/dq − C′(ψ_stem)·dψ_stem/dq = 0` (`C=hydraulic_cost_TF`).
- **Denominator (sign-definite):** `dG/dq < 0` at the maximiser (concavity of `W` in `q`). Registered
  as the node's sign assertion; if the profit landscape is flat/non-concave the node refuses rather
  than returning a spurious optimum.
- **Envelope:** at `q*`, `G=0`, so `dW/dq*·(dq*/dθ) = 0` — base TF24 has **no collar-ψ channel**
  (matches `seam_collar_psi_input()==nullptr`, `tf24_strategy.h:260`). `ρ`'s stationarity emerges
  through the IFT channel; no envelope theorem is *applied* by hand.
- **TF24f:** `q` is a tracked ODE state (rate `k·G`), so N3 is **not solved** — `G(q)` is only
  *evaluated* (the same reduced gradient), and the collar channel is non-zero (target #5).

## The reduced gradient `G(q)=dW/dq` is the single shared object
N1 (its denominator) + the N2 spline chain + `A′`,`C′` (forward-AD of the closed-form algebra, `:902–909`)
assemble `G(q)`. Base TF24 finds its root (N3); TF24f integrates `k·G`. **One expression, both variants**
— exactly the design's item 5. The FD seam's per-field/height/light/soil-ψ central differences
(`tf24_strategy.cpp:587–643`) all collapse into: seed `θ` (and the state/coupling reads) at the tape
inputs, let the two IFT nodes (N1, N3) + the closed-form composition carry the derivative. `∂W/∂θ` at
fixed `q*` (the envelope partial the FD seam computes) becomes a taped composition; no `2·|fields|` leaf
re-solves per node per step.

## What deletes / lands where
| current (plant#52) | fate | replacement |
|---|---|---|
| `tf24_strategy.cpp:508–688` FD `supplied_derivative` seam (~150 ln) | **delete** | N1 + N3 P1a nodes + closed-form `G(q)` |
| `leaf_profit_at_fixed_collar` (`tf24_strategy.cpp:280`, the FD engine) | **delete** | the taped reduced gradient |
| `psi_stem_to_ci` numerical root | **wrap** | N1 implicit-node (untaped double solve + IFT adjoint) |
| `find_root_collar_psi` golden section (`:798`) | **wrap** | N3 implicit-node (base TF24); evaluated-only for TF24f |
| `dprofit_droot_collar_psi` (`:890`, hand IFT) | **delete** | falls out of N1+N3 automatically |

Each node ships the IFT-vs-FD self-check (design §engine-primitives): N1 verified against a central FD of
`psi_stem_to_ci`; N3 against a central FD of the golden-section optimum — both at Gate-0 (single leaf,
clean FD), the trustworthy oracle.

## Nested-solve inventory (running, for the whole engine)
- **N1 (ci root)** — scalar IFT, denominator `A′·umol_to_mol + gc·inv_atm > 0`.
- **N3 (q\* optimum)** — scalar IFT, denominator `dG/dq < 0`.
- (N2 transport, birth-height `lift_birth_height`, and the soil breakpoints are *not* iterative solves —
  closed-form/IFT-at-a-root/Leibniz respectively.)
That is **two** genuine inner solves in the leaf, both scalar, both sign-definite — far from the ~150-line
FD seam's apparent complexity.
