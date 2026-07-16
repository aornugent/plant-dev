# Engine design — deepening targets (from abstract to concrete, per component)

The [v2 surface design](./ad-engine-surface-design.md) commits the *shape* (three engine primitives,
one model layer, two numerics layers). Before Phase 1/2 can be built, each component TF24/TF24f/K93/FF16
actually needs must be pinned down to residuals, factors, and sign conditions. This is that punch-list —
the places where "an engine primitive handles it" is not yet specific enough to implement. Code anchors
are to the plant#52 tip.

Each item states: **the concrete unknown**, **the code it must reproduce/delete**, and **the primitive
it lands on**.

## 1. The three leaf inner-solve residuals (P1a instances)
**Unknown:** the exact `F(y;p)=0` and its sign-definite denominator for each of:
- (a) **co-limitation `ci`** — `assim_colimited` (`leaf_model.cpp:16` `assim_colimited_ad`); the `v,w`
  scalar-IFT nodes (`v_•=−b_•/b_v`, `w_•=−e_•/e_w`), monotone ⇒ sign-definite.
- (b) **continuity collar root** — soil supply `E_from_Soil_to_Root_Collar(P_x_r)` = transpiration
  demand; 1-D root on collar potential (`leaf_model.cpp:642`).
- (c) **base-TF24 optimum `q*`** — `G(q)=dW/dq=0`, `W=assim(ci(q))−hydraulic_cost_TF(ψ_stem(q))`,
  `dG/dq<0` by concavity (`find_root_collar_psi` golden-section, `:798`; exact `dprofit_droot_collar_psi`,
  `:879`).

**Deletes:** the FD `supplied_derivative` seam (`tf24_strategy.cpp:508–688`, ~150 ln).
**Lands on:** P1a implicit-node ×3. Each ships IFT-vs-FD self-check.

## 2. Crown quadrature composition
**Unknown:** the `optimise_at` loop over crown light points (`tf24_strategy.cpp:~446–492`, QK
Gauss-Kronrod) integrates per-point reduced-gradients. Does it stay **quadrature-through (Kind C)** — a
taped reduction over fixed nodes — or do the light points that cross cohort tops become **breakpoint
nodes**? Interaction with the `single_solve` (mean-light) vs deep-crown seam (currently `util::stop` on
active deep-crown, `:512`).
**Lands on:** Layer-N reduction + possibly a P1a breakpoint per crossing.

## 3. Two-way soil↔leaf coupling — the `StateView.u()` surface
**Unknown:** concretely how the per-layer sink `σ_L(θ)` (`soil_consumption_active_`,
`evapotranspiration_dt`) feeds the soil ODE while the leaf reads `ψ(θ)` (`psi_from_soil_moist`), such
that the 150 lines of hand-built per-layer uptake partials become automatic. The exact `u()` accessor
signature and how the aggregated low-rank sink enters both the transient march and the BVP's
sink-quadrature states.
**Deletes:** `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` + the uptake-partial loop.
**Lands on:** `StateView.u()` + the breakpoint/Leibniz node for the piecewise `E_from_Soil_to_Root_Collar`.

## 4. Early-exits: `decide()` predicates vs genuine kinks
**Unknown:** each leaf shut-down early-exit (`set_shutdown_state`, `prepare_collar_solve` returns,
`leaf_model.cpp:705–740`) — is it a **Kind-A `decide()`** (a feasibility branch whose choice is replayed
on pass 2, zero derivative contribution) or a **genuine kink** (a `C⁰` corner in `profit(q)` that the
gradient must see via a breakpoint)? Classify all of them; a misclassification is a silent gradient bug.
**Lands on:** `decide()` firewall (P1d) or a breakpoint node (P1a).

## 5. TF24f tracked-`q` in the fixed-point BVP
**Unknown:** make "solved-vs-tracked changes the eigenvalue" concrete — how the tracked
`opt_root_psi_state` (ODE rate `k_acclim·G`, `tf24f_strategy.cpp:44`) enters the Eulerian steady-profile
BVP: an extra algebraic steady-`u` unknown (`k·G=0 ⇒ G=0`, collapsing to the solved case at steady
state?) or an extra profile state. Its effect on the linearised operator `∂F/∂X` whose dominant
eigenvalue regnans differentiates.
**Lands on:** the second numerics layer (fixed-point module).

## 6. K93/FF16 light-environment coupling — P1b's primary witness *(added this round)*
**The most foundational item: the gate for P2a (K93) and P2b (FF16).**
**Unknown:**
- The exact **separable factors** `{a_p(z), b_p(x)}` for the `CanopyShape` kernel
  `κ(z,x)=c_k·x²(1−(z/x)^η)²` expanded to **rank-3**, and how descending suffix scans `B_p` reproduce
  plant's `get_environment_at_height` — for K93 (a **single point read** at the plant's own height,
  `k93_strategy.h:186`) and FF16 (a **crown integral over `z`**, a sub-grid field read).
- **Resident vs mutant**: resident light is active (self-shading, on-tape); mutant reads a recorded
  `double`. One P1b primitive must serve both without the `shouldRecord()` pair-filter living in the
  model.
- **The C3 fork, resolved concretely**: today the moving-query `∂A/∂z` is **frozen** inside
  `get_environment_at_height` (§15 Gate 1; the ~17× spline-ripple that motivated it). P1b delivers
  `∂A/∂z` **exactly** off the separable field, so the freeze should retire entirely — safe by the C¹
  double-diagonal zero `κ(z,z)=κ_z(z,z)=0`. Confirm it is the *same* path for K93's point read and
  FF16's crown integral.
- The **near-diagonal direct band** `δ`: the recombination `A=Σ_p a_p B_p` has alternating-sign
  cancellation near the diagonal that Neumaier summation can't fix; `δ` defaults 0 + a debug exactness
  check vs the unexpanded `κ`.

**Deletes:** the interpolator *on the coupling path* (retained only for non-separable `FlatTopSoftBox`);
`node.h::growth_rate_gradient`'s frozen-query dependence.
**Lands on:** P1b scan-coupling + P1e canonical-state charts (the `∂A/∂z` read is a `StateView`
accessor).

---

**Suggested order to deepen:** 6 → 1 → 3 (the P1b/P1a/StateView spine, which K93 then TF24 land on),
then 2, 4, 5 (composition + classification + the fixed-point detail). Item 6 first because it unblocks
the fastest visible win (P2a, K93 on the clean engine).
