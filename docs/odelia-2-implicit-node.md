# odelia design #2 — the implicit-node primitive (P1a)

Second component of the odelia design journey (`design.md` P1a). Under the system-design skill, grounded
in the existing `supplied_derivative` (the injection Kernel) + forward-mode (`FReal`) + the plant#52 FD
seam it replaces.

## Triage: 3
odelia public API; the load-bearing name — witnessed by leaf `ci` (N1), leaf collar optimum (N3), birth
height, breakpoints, and (later) the fixed-point BVP. Consumers: plant's TF24/TF24f + regnans.

## Requirements ledger
- **R-auto — the IFT partials are formed by the engine from a templated residual, never hand-written.**
  *Witness (v1 clunk):* `tf24_strategy.cpp:508–688` is ~150 ln of **central-FD** partials
  (`leaf_profit_at_fixed_collar` ×2·|fields| leaf re-solves per node per step); `leaf_model.cpp:890`
  (`dprofit_droot_collar_psi`) is a **hand-assembled IFT**; `height_seed` a hand IFT. Every one is a
  silent-gradient-bug site (the scarce resource). Target: **0** hand partials; the model declares `F`.
- **R-nonest — first-order reverse-through-solve without nesting the outer tape** (the odelia#36
  sidestep). *Quantity:* the inner solve iterates data-dependently (golden-section, TOMS748) — taping it
  is impossible; the partials must enter as constants at the operating point.
- **R1 — no tape machinery on the model surface.** *Witness:* the FD seam's `supplied_derivative`
  calls, the `shouldRecord()` pair-filter, the `xad::adj` type test all live in `tf24_strategy.cpp`
  today. Target: the model supplies a scalar-generic residual + a `double` solver; **it never calls
  `supplied_derivative`, never names the tape**.
- **R-sign — the IFT denominator is sign-definite, asserted at registration** (a non-invertible `∂F/∂y`
  is a modelling error caught loudly, not a silent NaN). N1: `A′·umol_to_mol+gc·inv_atm>0`; N3: `dG/dq<0`.
- **R-check — each registered node self-verifies** IFT-vs-FD at init (Gate-0 oracle).
- **R-2nd (reserved, not built) — a slot for higher-order partials** (`∂²`) for the Phase-3 BVP
  eigenvalue path; additive, not implemented now (no HVP until needed).

**Scarce resource:** *hand-written-adjoint correctness.* This primitive's entire purpose is to move the
inner-solve adjoint from hand-written (FD/IFT, ~150 ln + `dprofit`) to **engine-formed + self-checked**,
collapsing N sites to one.

## The floor
**Keep `supplied_derivative` + hand-computed partials** (v1). *Fails R-auto, R1:* the partials stay
hand-written FD/IFT in plant (the ~150-line seam, the hand `dprofit`), and the model calls the tape
Kernel directly — the clunk and the leak intact. `supplied_derivative` is the right *low-level*
mechanism (it survives, below), but exposing it to the model, with hand partials, is the floor's failure.

## Candidates
- **A [first thought]** (move 6, Pólya): a first-class **implicit-node** — `register_implicit(F, solver,
  outputs)`. The engine solves `F=0` in `double` (untaped), forms `∂F/∂y, ∂F/∂p` by **forward-mode
  (`FReal<double>`) over the templated `F`** at the operating point (exact, no FD), solves the small
  dense system `dy/dp = −(∂F/∂y)⁻¹ ∂F/∂p` (doubles), asserts the sign of `det ∂F/∂y`, and injects `dy/dp`
  as the partials through the existing `supplied_derivative`. Self-checks IFT-vs-FD at init. *Pays*
  R-auto (model gives `F`, engine gives partials), R1 (no tape call in the model), R-nonest
  (partials are doubles at the operating point — no outer-tape nesting), R-sign, R-check. *Costs:* one
  new name; the forward-mode-over-`F` pass. *Wins when* ≥2 inner solves share the shape — they do (N1,
  N3, birth height, breakpoints, BVP).
- **B** (move 3, move the boundary): keep `supplied_derivative`, add only an `ift_partials(F, y*, p)`
  **helper** the model calls, then the model calls `supplied_derivative` itself. *Pays* R-auto (partials
  automated) but **fails R1** — the model still orchestrates (solve → partials → inject) and names the
  tape. Lighter by one name, leakier by the whole orchestration.
- **C** (move 5, optimize the common case): automate only the **scalar (1×1) IFT** (leaf `ci`, birth
  height, breakpoints — all scalar), keep hand partials for the dense KKT/BVP. *Fails* on names: the
  dense case (Phase-3 BVP) then needs a *second* mechanism; and the leaf optimum `q*` is scalar too, so
  the scalar case already covers every v1 leaf need — the dense case is the same solve at `L>1`, not a
  different one. Splitting buys nothing.

**Winner: A.** Eliminations: **B** fails R1 (model orchestrates + names the tape — the leak persists);
**C** splits one mechanism into two on a size distinction the linear algebra doesn't respect (`L=1` is
the `L>1` solve); **the floor** is the v1 clunk. A is the least design that pays R-auto+R1: it *reuses*
`supplied_derivative` as its internal Kernel and *adds* only the partial-formation the seam did by hand.

## The commitment
**A model declares an inner solve as a scalar-generic residual `F(y; p)=0` plus a `double` solver and its
active outputs; the engine owns the solve, the exact IFT partials, the sign assertion, the injection, and
the self-check. The model computes no partial and never names the tape.**

**Kept true by structure:** `register_implicit(F, solver, outputs)` takes a *templated callable* `F` and
output handles — **it has no `partials` parameter** (unlike raw `supplied_derivative`). So "hand a
partial" is *inexpressible* at the model boundary; `supplied_derivative` demotes to an odelia-internal
Kernel the node calls, not a model-facing function. The residual is templated (the leaf's
`assim_colimited_ad`/`hydraulic_cost_ad` already are), so `∂F` is formed by forward-mode over the *same*
code the double solve runs — value and derivative cannot diverge.

## Kill question
**Assumption whose falsity makes this unnecessary:** *the inner-solve residuals are available as
scalar-generic closed forms the engine can forward-differentiate* (so `∂F/∂y, ∂F/∂p` need no hand rule).

**Verdict: survives.** The leaf residuals are already templated closed forms in `leaf_model.cpp`
(`assim_colimited_ad<T>`, `hydraulic_cost_ad<T>`, `:16`,`:24`); the `ci` residual `A(ci)−gc(ca−ci)` and
the collar `G(q)=dW/dq` are compositions of them; `height_seed`'s residual is `mass_live_given_height−ω`,
templated. So forward-mode over `F` is well-defined for every witnessed node. Where a residual reads the
coupling field or soil, those are `StateView` reads (odelia #1 / deepening-3), themselves exact — no hand
rule anywhere.

## What survives deletion
- **`register_implicit` / the implicit-node** → R-auto + R1 (the model's whole inner-solve surface).
- **`supplied_derivative`** → retained as the **internal** injection Kernel (R-nonest: doubles at the
  operating point, no outer nesting). It stops being model-facing.
- **The forward-mode partial former** (`FReal<double>` over `F`) → R-auto (exact `∂F`, no FD).
- **The sign assertion + the IFT-vs-FD self-check** → R-sign + R-check (the scarce resource, defended).
- **Deleted:** the ~150-line TF24 FD seam + `leaf_profit_at_fixed_collar`; `dprofit_droot_collar_psi`;
  the `height_seed` hand IFT; the `shouldRecord()` pair-filter (the node handles inactive inputs). **Not
  built:** the `∂²` higher-order path (reserved registration slot only — Phase 3).

## What this settles
- Every inner solve is one registered node; the inner iteration is never taped (R-nonest).
- The hand-adjoint count for the whole plant family drops to **two engine sites** — the scan transpose
  (odelia #1) and this node's dense solve — each self-checked; **zero** in strategies.
- N1/N3 (odelia #1's leaf) are two `register_implicit` calls; birth height and each breakpoint are more;
  the reduced gradient `G(q)` composes N1 + the field reads with no hand IFT.

## What this makes hard
- **A residual with no scalar-generic form** (a black-box library solve whose residual isn't
  differentiable code): the engine can't form `∂F`. *Cope:* fall back to raw `supplied_derivative` with a
  hand partial for that one site (the escape hatch stays, just not model-facing by default) — and log it
  as a hand-adjoint site.
- **Second-order through the node** (BVP eigenvalue): needs the reserved `∂²` slot + the nested
  `adj⟨fwd⟩` (`directional_derivative` already exists for it). *Cope:* Phase 3 fills the reserved slot;
  the first-order callback is kept nestable (it composes `FReal` over the residual, which nests).

## Kill condition
A witnessed inner solve appears whose residual is genuinely non-differentiable code (not just iterative)
→ that site uses the raw-`supplied_derivative` escape hatch with a logged hand partial; the primitive
stays for the rest. (No such site exists among the four strategies + regnans today.)

## The design (interface + flow)

```cpp
// odelia — the model-facing registration (no partials parameter; no tape naming)
template <class S, class Residual, class Solver>
S register_implicit(Residual F,          // F(y, p...) -> residual, scalar-generic (templated)
                    Solver   solve,       // double: returns y* solving F(y*, p)=0 (golden/TOMS748/…)
                    std::vector<S*> p,    // the active inputs F depends on (params, state, field reads)
                    SignHint denom_sign); // asserted: sign(det ∂F/∂y)  (N1 >0, N3 <0)

// internally (odelia Kernel — the only tape-aware code):
//   double y0 = solve(value(p)...);                    // untaped inner solve
//   Jyy = d F/dy, Jyp[i] = d F/dp_i   by FReal<double> over F at (y0, value(p))   // exact, no FD
//   dydp = - solve_dense(Jyy, Jyp);                    // the IFT, doubles
//   return supplied_derivative(getActive(), y0, p, dydp);   // inject; first-order, no nesting
// init-time self-check: |dydp - central_FD(solve, p)| < tol  (Gate-0 oracle)
```

**What a strategy declares (leaf `ci`, N1):**
```cpp
// residual: stomatal supply = biochemical demand (both already templated in leaf_model)
auto F_ci = [&](auto ci){ return A_colim(ci) * umol_to_mol - gc(psi_stem, q) * (ca - ci) * inv_atm; };
S ci = register_implicit<S>(F_ci, /*double solver*/ ci_toms748, {&params..., &A_read}, SignHint::Pos);
```
The reduced gradient `G(q)=dW/dq` for the collar (N3) composes `A_colim(ci(q))` (this node) − `cost(ψ_stem(q))`;
base TF24 wraps `G` in a second `register_implicit` (root `G=0`, `SignHint::Neg`); TF24f integrates `k·G`
as an ODE-state rate (no root). No hand IFT anywhere — `dprofit_droot_collar_psi` deletes.

**Data flow (reverse sweep):** the outer tape reaches the node's injected leaf; `supplied_derivative`'s
`CheckpointCallback` fires, distributing `ȳ · dy/dp_i` to each input slot — the inner iteration is never
on the tape (R-nonest). The `dy/dp` were formed once, forward-mode, at the operating point.

**Boundary with odelia #1:** a residual that reads the coupling field (`A`) or soil (`u`) gets them as
exact `StateView` reads; the node's `∂F/∂p` then includes those field sensitivities automatically. The
scan (odelia #1) and this node are the two — and only two — tape-aware Kernels the plant family needs.
