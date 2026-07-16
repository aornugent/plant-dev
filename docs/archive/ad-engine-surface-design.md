# The odelia AD-engine surface — design (second pass)

Status: design, second pass. First pass fleshed out the surface; this pass folds in the broader
TF24 consult, the soil-subsystem (numerical-methods) consult, and the three-fork closure. Follows
the system-design skill. The commitment is unchanged; the numerics layer is not.

## v2 — what the consults changed (read this first)

1. **Two numerics layers over one model layer — the biggest structural change.** The gradients are
   wanted in two regimes (both required):
   - **Transient** (finite-horizon distribution moments, non-settled): the **time-marching reverse
     sweep** already designed — checkpoint per accepted step, re-record, sweep. No shortcut object
     exists (the trajectory hasn't settled).
   - **Fixed point** (regnans selection/equilibrium): the **Lagrangian trajectory has *no* fixed
     point** — members are inserted and never removed, so `N` grows monotonically and the state never
     repeats. The steady object is the **Eulerian profile**, which the separable kernel collapses to
     a **tiny two-point BVP** (dimension ~4 + L: flux `F(x)=g·n`, the three suffix-integral states
     `B_p`, the sink-quadrature states, and `L` algebraic steady-`u` unknowns). Its gradient is an
     **IFT adjoint of the BVP residual** plus a standard **eigenvalue-perturbation identity** for the
     dominant-mode growth rate — tens of residual evaluations per gradient, vs a 10³–10⁵-step march
     per FD sample. Same Layer-M closed forms; a **second, thin numerics layer**. This is the "one
     engine, both regimes" answer and the design payoff of the representation-agnostic model surface.
2. **Soil "stiffness" is a multirate problem, not RODAS.** The cost is the **N/L amplifier** (the ≤5
   soil states force all ~10²–10³ cohorts to tiny steps on the shared global step). Fix: **sub-cycle
   the small block** (multirate) + **split steps at recorded forcing kinks** (free) + a
   **desingularizing coordinate** for the near-boundary excursion (a chart). RODAS/implicit does *not*
   help (the collapse is accuracy-driven, measured). **Keep `u` explicit on the recorded schedule**;
   the implicit-`u` stage is retired to a **validation-gated fallback** (refine tol, confirm the
   *gradient* converges; build the implicit node only if it drifts). The multirate adjoint is free —
   tape the scheme as run (fits checkpointed record/replay).
3. **Second-order, revised.** Still **no general HVP** in the transient regime (last round's
   decision holds). BUT the fixed-point eigenvalue gradient needs **one nested `adj⟨fwd⟩` sweep** and
   **second-order partials on the tiny BVP residual path** — so the residual-path nodes (`γ`, the
   scalar-IFTs) must expose second-order partials (`∂²γ/∂s²`, differentiated-IFT). Low-dimensional,
   applied once per gradient; this is the "limited nesting XAD supports," not general HVP.
4. **Three forks closed (engine deltas, all Layer-K, none touching the model surface):** the scan
   grows a **near-diagonal direct band** (the recombination `A=Σ a_p B_p` has alternating-sign
   cancellation near the diagonal that compensated summation can't fix; `δ` defaults to 0 + a
   debug exactness check); `γ(s,x)` becomes a **Layer-K node** with registered `∂/∂x`, `∂/∂s`
   (series + digamma), optional `∂²/∂s²`, FD-validated at init; **pinning is a frozen active set**
   (during a pinned interval `∂u/∂θ=0` is the *exact* sensitivity, not an approximation — trivial
   node, stiffness vanishes; record/replay the set; smooth-floor is a model-side declared option).
5. **The inner solve: one reduced-gradient `G(q)=dW/dq` serves both variants.** `v,w` as scalar-IFT
   nodes (`v_•=−b_•/b_v`, `w_•=−e_•/e_w`, sign-definite by monotonicity); solved-`q` = a third
   scalar-IFT root of `G=0` (`dG/dq<0` by concavity), tracked-`q` = an ODE state with rate `k·G`.
   No envelope theorem is ever *applied* — `ρ`'s stationarity emerges through the IFT channel; `σ`'s
   non-stationary terms are carried automatically. Inner tolerance set for `σ` (first-order), not
   `ρ` (second-order). **Solved-vs-tracked changes the fixed-point eigenvalue** (different
   linearization) — a per-model science decision at registration.
6. **Top transient risk: schedule-timing sensitivity.** Depletion-episode timing moves with `θ`;
   the frozen schedule drops it, and this system is depletion-dominated, so the dropped term is
   likely larger here than in a stability-limited system. Measure before trusting frozen-schedule
   gradients near depletion (F2).

## Triage: 3
odelia's public API (a module boundary with external consumers — `plant`'s four strategies and the
cross-package `regnans` stiff consumer), expensive to reverse once models depend on it. Full
procedure; Oracle support substitutes for the blind clean-sheet.

## Requirements ledger
- **R1 — a model reads as science.** A strategy author writes only scalar-generic pointwise closed
  forms + declarations; zero XAD/tape vocabulary, zero hand-written derivative/adjoint code.
  *Quantity:* today ~13 plant headers include XAD; `node.h::growth_rate_gradient` is ~70 lines of
  forward-over-reverse plumbing; the TF24 leaf seam is ~150 lines of hand-rolled FD-adjoint. Target:
  **0** XAD tokens in strategy files; both blocks deleted from plant.
- **R2 — one transport-gradient path for all strategies.** `dg/dh` (the density-transport term)
  needs no per-strategy AD work. *Quantity:* today correct only for K93 (the one forward-mode-
  instantiable strategy); FF16/TF24/TF24f defer. Target: all four, no per-strategy transport code.
- **R3 — correct, performant, composable gradients.** Match FD-of-the-model-as-run to its plateau;
  O(1) forward-equivalents per gradient (flat in |θ|); survive one nesting (HVP) where the primitive
  allows. *Quantity:* |θ| ≈ 5–20, N ≈ 10²–10³, k ≈ 17, steps 10³–10⁵.
- **R4 — the soil-class subsystem resolvable performantly in *both* forward and reverse under
  realistic (rapid/intermittent) forcing.** *Solution-verb stripped (decision, this round):* "a
  differentiable RODAS stepper" was a mechanism wearing requirement clothes — RODAS is **not** the
  goal and, by the QSS measurement, an implicit stepper likely does **not** cut the plant step count
  (the collapse is accuracy-driven, not stability-driven). The real outcome is the low-dimensional
  strongly-forced subsystem being cheap and correct in forward and reverse. **This is now a separate
  targeted Oracle consult** (`oracle-consultation-soil-subsystem.md`), not assumed to be solved by
  implicit integration. The **implicit-node primitive stays regardless** — it is witnessed by the
  leaf optimum, the constraint, the breakpoint, and regnans' fixed point, none of which is stiffness.
  The RODAS **stepper** is **out of engine scope** unless the targeted consult concludes implicit
  integration is the right resolution.
- **R5 — double path bit-identical, or documented minimal change.** The mass chart is exact only with
  the neighbour-secant compression (geometric compression, the measured ~0.2% K93 forward shift) — a
  documented change for gradient runs, accepted per `ad-census-gradients.md`.
- **R6 — one engine, many models.** K93/FF16/TF24/TF24f now; regnans later.
  *Resolved (v2):* regnans is a workflow/selection consumer over plant, not a new ODE system — so the
  transport core is plant-family-specific and regnans is served by the R7 fixed-point layer.
- **R7 — gradients in *both* regimes (v2, first-class):** finite-horizon distribution moments along a
  *non-settled* trajectory (transient), **and** selection/growth-rate gradients at the demographic
  *steady state* (fixed point). *Quantity:* both requested many times in an outer loop; the fixed
  point has **no Lagrangian representation** (N grows monotonically), so it needs a distinct steady
  (Eulerian-profile BVP) numerics layer. Neither regime subsumes the other.

**Scarce resource:** *hand-written-adjoint correctness.* Every place a human writes a reverse rule
(a transpose, an IFT, a scan adjoint) is a **silent** gradient-bug site — value-exact, passes every
double test, wrong only in the gradient (the failure mode that bit this project repeatedly). The
design is measured by how few such sites exist and how each is machine-checked, and — jointly — by
model-author working memory (R1). Minimise the count of tape-aware sites; make each self-verifying.

## The floor
Keep the current heterogeneous seam kit (`supplied_derivative` + `directional_derivative` + `slope`
+ `smooth_positive`), incrementally cleaned (the earlier five containment moves). **Fails R2**
(dg/dh stays K93-only; FF16/TF24 need unbuilt per-strategy forward-instantiable ports) and **R4**
(no reverse RODAS; odelia#36 blocked), and only partially meets R1 (the leaf seam + node.h block
remain in plant). Insufficient now that R2 and R4 are in scope.

## Candidates
- **A [first thought]** (move 6, Pólya-with-witnesses): the three-primitive engine — **scan-coupling**
  (owns the field + its exact spatial derivative), **implicit-node** (owns every inner solve),
  **canonical-state + charts-as-views** (owns the transported variable) — model = scalar-generic
  science + declarations. *Commitment:* all tape-aware code is those primitives; the model never
  names the tape nor evolves a chart variable. *Pays* R1/R2/R6 (dg/dh via scan+mass-chart, uniform;
  no per-strategy AD) and R4 (RODAS = an implicit-node instance). *Costs:* 3 primitive concepts + the
  canonical-state machinery + a plant rewrite. *Wins when* several models share the engine and the
  hand-adjoint count must shrink.
- **B** (move 3, move the boundary to the PDE): the engine owns the *whole* method of characteristics;
  the model declares only continuum operators (`g, r, κ, Ψ, H`, influx, reductions) and the engine
  chooses the discretisation. *Commitment:* the model is continuum physics; **all** discretisation is
  engine. *Pays* R1/R2 maximally. *Costs:* one blessed discretisation for everyone; a model needing a
  bespoke scheme is stuck; `TransportGeometry` becomes a policy object now. *Wins when* every target
  model shares one discretisation.
- **C** (move 5, minimal engine): build only the **implicit-node** primitive + adopt the two exact
  identities (**scan** coupling, **mass chart**); keep the existing System contract otherwise; do
  **not** build the chart/canonical-state abstraction. *Commitment:* one implicit-node + two
  identities; no chart layer. *Pays* R2 (dg/dh via mass-chart+scan) and R4 (RODAS via implicit-node)
  with the fewest new names; R1 only partially (representation stays partly model-side). *Wins when*
  the chart abstraction's generality isn't yet witnessed by a second transported variable.

**Winner: A, minus B's premature generality — i.e. A with C's restraint on the chart policy.**
Eliminations: **B** over-commits — "one discretisation for everyone" fails R6's open question
(regnans may not be a characteristic solver), and `TransportGeometry`-as-policy-object generalises
over one witnessed discretisation, which the skill forbids. **C** underpays R1 — leaving
representation model-side keeps some chart/compression reasoning in plant, and the ~70-line node.h
block does not fully delete. A adopts the three primitives (each witnessed ≥2×: scan = light+soil
coupling; implicit-node = leaf-optimum + constraint + breakpoint + RODAS stage; charts = mass vs
density vs log-density) but treats **charts-as-views as a fixed plant-family choice, not a
policy-object** — `TransportGeometry` is a single hard-coded pairing (neighbour-secant ↔ log-mass)
until a second discretisation witnesses the need to abstract it.

## The commitment
**A model contributes only scalar-generic pointwise closed forms and declarations; every tape-aware
operation — the coupling field and its spatial derivative, every inner solve, and the
transported-state bookkeeping — is an engine-owned primitive with a machine-checked adjoint.**

**Kept true by structure:** the model translation unit (a) does not include `<XAD/…>` — it is
templated on an opaque scalar `S` and calls only engine views/primitives; and (b) declares *rates,
residuals, and kernel factors*, never `d(chart-variable)/dt` and never a transpose. So the three
silent-bug classes — a hand-written stencil/adjoint on the tape, raw `xad::value` arithmetic, and
wrong-chart compression — are **inexpressible in model code**. The two hand-written adjoints that
remain (the scan transpose, the implicit-node IFT) live once each in the engine and each ships a
dot-product self-check (⟨Jv,u⟩=⟨vᵀ,Jᵀu⟩ via the existing `compute_jvp`).

## Kill question
**Assumption whose falsity makes this unnecessary:** the target models share the method-of-
characteristics structure the engine hard-codes — ordered non-crossing particles, a low-rank
separable kernel, mass-conserving transport. *Argued from the ledger:* the four plant strategies all
use the shared `CanopyShape` kernel and the same SCM transport, so the assumption holds for the
witnessed consumers (R6). It is **uncertain for regnans** (R6 challenge) — if regnans is a generic
stiff ODE rather than a characteristic solver, only the *engine-generic* pieces serve it
(implicit-node, tape lifecycle, the `value()` firewall), not the transport core. **Verdict:
survives for the plant family; the transport-core's reuse beyond plant is the open fork** — but note
the implicit-node primitive (which is what R4/regnans need) is exactly the engine-generic piece, so
R4 is served regardless.

## What survives deletion
- **scan-coupling primitive** → R2 (dg/dh field + `∂A/∂z` exactly, no reconstruction), R1 (no spline
  in plant), R3 (O(N) sweep).
- **implicit-node primitive** → R2 (the leaf/constraint/breakpoint seams), R4 (the RODAS stage), R1
  (deletes the ~150-line FD-adjoint from plant). The single most load-bearing name.
- **canonical-state + charts-as-views** → R1/R2 (compression ceases to exist in the model; `dg/dh`
  becomes engine geometry). Kept, but as a fixed pairing, not a policy object.
- **`value()` firewall (`decide`/`diagnostic`)** → R1 (retires the `to_passive`-scatter + the
  value-keyed-cache silent-bug class).
- **the dot-product self-check harness** → the scarce resource directly (every hand adjoint checked).
- **Deleted / not built:** `TransportGeometry` as a policy object (one witness); a bespoke
  per-strategy transport-derivative path (the scan+mass-chart replaces it); the interpolator *on the
  coupling path* (the exact scan replaces it — it survives only if a genuine sub-grid continuous
  field read is witnessed that the closed-form aggregate can't serve); full nested-tape RODAS
  (odelia#36 Phase 2 — the IFT callback gives first-order reverse without it).

## What this settles
- No strategy file contains AD code; `node.h::growth_rate_gradient` and the TF24 FD seam are deleted.
- `dg/dh` correctness is uniform across strategies with zero per-strategy work (R2).
- Reverse-mode RODAS is "register the stage as an implicit node" — no nested-tape unblocking needed
  for first order.
- The silent-wrong-gradient bug class is reduced to two engine sites, each dot-product-checked.

## What this makes hard
- **A model that genuinely needs a chart-variable rate** (a source per unit density, say) must use a
  narrow escape hatch (`register_chart_rate`, engine supplies the pullback) — first-class but rarely
  used; if it becomes common the charts-as-views framing is wrong.
- **Second-order (HVP) through the implicit node** needs the nested tape (odelia#36) the first-order
  IFT callback avoids — deferred; the callback is kept scalar-generic so it can be nested later.
- **A non-characteristic or non-separable-kernel model** gets only the engine-generic primitives, not
  the transport core (the kill-question fork).
- **The migration is large** — a plant rewrite onto the new surface, staged brick by brick (scan,
  then mass chart, then implicit-node, then charts), each landing behind the bit-identity guard.

## Kill condition
A second transported variable / discretisation appears (remeshing, a conserved-number model, a
non-characteristic consumer) → promote `TransportGeometry` to the policy object candidate B wanted.
Or: chart-variable rates become common → the charts-as-views framing loses, and rates-on-charts
becomes the model surface.

---

## The odelia surface (first pass — illustrative signatures)

Three layers (Oracle's M/N/K, adopted): **Model** (author, scalar-generic, pure) · **Numerics**
(engine, scalar-generic) · **Kernels** (engine, the only XAD-aware code).

### Model-facing surface — what a strategy implements
Everything templated on an opaque scalar `S`; no XAD include.

```cpp
template <class S> struct MyStrategy {
  using value_type = S;
  template <class U> using rebind = MyStrategy<U>;      // scalar remould (exists today)

  // Pointwise science — closed forms, no loops over particles, no solves, no tape.
  S velocity (S x, S A, const Pars<S>&) const;          // g
  S loss     (S x, S A, const Pars<S>&) const;          // r
  S influx_mass(S S_b, const Pars<S>&) const;           // boundary law, author's chart

  // Coupling as SEPARATED factors (engine builds the field from these; §scan).
  std::array<S,R> kernel_a(double z, const Pars<S>&) const;   // a_p(z)   (R = separation rank)
  std::array<S,R> kernel_b(S x, const Pars<S>&) const;        // b_p(x)
  S kernel_direct(double z, S x, const Pars<S>&) const;       // κ(z,x) — engine self-checks a·b vs this
  S sample_map(S A) const { return exp(-A); }                 // Ψ

  // Inner solves as RESIDUALS (engine differentiates by IFT; §implicit-node). Optional per strategy.
  ImplicitNode operating_point() const;   // {residual J_q/c, double solver, outputs ρ,σ}
  // Breakpoint integral: antiderivative F + branch residual h (engine does Leibniz).

  // Declarations (passive data, not code):
  //   requested output moments φ; solved-vs-tracked per decision var; positivity policy for u;
  //   smoothing scales; the stiff index set (IMEX); the TransportGeometry tag.
};
```

The strategy reads state through an engine **view**, never a raw state vector:

```cpp
template <class S> struct StateView {          // all accessors exact, taped, closed-form
  S x(int i), mass(int i), density(int i), log_density(int i), spacing(int i);
  S A(int i), S_field(int i), dA_dz(int i);    // exact scan reads + ∂A/∂z
  const AuxView<S>& u() const;
};
```

### Engine primitives (Kernels — the only XAD-aware code)
1. **scan-coupling.** Input: `{a_p(z), b_p(x)}` + masses; forward = descending suffix scans →
   `A(xᵢ)` and `∂A/∂z = Σ a_p′(z)B_p`; reverse = mirrored prefix scans. Compensated (Neumaier)
   summation. Registered as one vectorized external function (tape sees O(N), not O(Nk) scalar
   nodes). Init-time self-check: `Σ a_p(z)b_p(x)` vs `kernel_direct`. Ships the ⟨Jv,u⟩ dot-product
   test.
2. **implicit-node.** Register `(F(y;p), untaped double solver, outputs)`. Forward: solve at
   `double`, register active outputs. Adjoint: form `∂F/∂y, ∂F/∂p` by `fwd<double>` over the
   templated residual, small dense solve, increment input adjoints. Sign-definite-denominator
   assertion at registration. **Four instances:** operating-point KKT (→ two scalar IFTs here),
   constraint root, breakpoint `ξ*`, **RODAS implicit stage.** The `fwd<double>` callback gives
   first-order reverse-through-implicit **without** nested tapes (sidesteps odelia#36).
3. **canonical transport + charts.** Engine-owned state `(xᵢ, log mᵢ, u, accumulators)`; the
   `StateView` charts are taped bijections. Author declares physics; the engine forms the
   spacing/compression geometry (never handed to the model). `TransportGeometry` = the fixed
   (neighbour-secant ↔ log-mass) pairing.
4. **stepper.** Explicit RKCK + implicit RODAS behind one `Step` interface; **IMEX** split by the
   model's stiff index set (implicit on the m-dim sub-block, explicit remainder). RODAS stage = an
   implicit-node instance → reverse-mode for free.
5. **tape lifecycle.** Schedule record/replay; **checkpointed re-record** (per-step sub-tape,
   discarded after sweep); vector adjoints for the moment vector.
6. **`value()` firewall.** `decide(expr)` (predicate; on pass 2 replays the recorded decision) and
   `diagnostic(expr)` (dead to the tape). Raw `xad::value` banned in Model + Numerics (grep-enforced).
7. **verification harness.** Frozen-schedule FD (T1), tangent cross-check, per-edge adjoint probes,
   and the mass/moment conservation invariants as standing gradient tests.

### How each hard component lands
- **dg/dh (C1/C2):** deleted — mass chart makes it vanish from the rate; the scan gives `∂A/∂z`
  exactly where any variant needs it. Uniform across strategies (R2).
- **coupling field (C3):** the scan; C¹ by the kernel's double diagonal zero, so the moving-query
  derivative is kept, not frozen.
- **leaf optimum + constraint (C4/C5):** two scalar implicit-node instances; ρ (envelope) and σ
  (non-stationary) fall out as taped compositions.
- **tracked optimum (C6):** the decision variable becomes an ODE state; its rate reuses the same
  registered residual.
- **breakpoint integral (C7):** closed-form antiderivative + `ξ*` as an implicit node (Leibniz jump
  term automatic).
- **stiff auxiliary (C8):** implicit-node RODAS stage on the IMEX sub-block — **for robustness near
  the singular boundary, not for step-size** (see the uncertainty below).
- **growing dimension (C9):** engine transport core + active-birth registry.

---

## Open uncertainties — surfaced early for the Oracle

1. **The soil-subsystem resolution problem — RESOLVED into a separate targeted consult (decision).**
   RODAS is not the goal; the goal is the low-dimensional strongly-forced subsystem being performant
   and correct in forward *and* reverse under realistic forcing. My measurement (accuracy-driven step
   collapse, not stability-stiffness) says implicit integration probably does not cut the cost, so we
   do **not** presuppose it. Framed openly in `oracle-consultation-soil-subsystem.md`. The engine
   keeps the implicit-node primitive (justified elsewhere) but the RODAS stepper is out of scope
   pending that consult.
2. **Does regnans fit the transport structure (R6)? — RESOLVED.** regnans is a *workflow* over
   plant ("assemble communities… iterate demography to equilibrium, compute selection gradients"),
   not a new ODE system. Consequences: (a) the transport core is plant-family-specific (confirmed —
   no external transport witness); (b) regnans is **not** an independent "general stiff capability"
   witness for R4 — so RODAS's justification narrows to the implicit-node primitive plus plant's own
   (accuracy-driven, questionable) stiffness; (c) regnans differentiates through a demographic
   **fixed point**, which is another implicit-solve → it **reinforces the implicit-node primitive**
   (equilibrium/selection gradients) and the R3 performance requirement (many gradient calls in an
   outer loop). Net: the implicit-node primitive is now witnessed by leaf-optimum + constraint +
   breakpoint + **demographic-equilibrium (regnans)**; the RODAS *stepper* specifically has lost its
   external witness and is deferred behind the primitive (build the primitive; make the RODAS stage
   one future instance, gated on a genuine stiff witness).
3. **Kernel separability is per-canopy-mode — RESOLVED (decision).** Exact separable scan for the
   default `(1−(z/x)^η)²`; **the interpolator is retained as the general fallback** for non-separable
   modes (`FlatTopSoftBox`, …). The exact path is an optimisation gated on separability, not a
   universal replacement — so the interpolator does not fully leave the codebase.
4. **The special-function derivative.** The breakpoint antiderivative's shape parameter `c` is a
   differentiated trait, so `∂γ(s,x)/∂s` (digamma-series) is needed. **Question:** implement it in the
   engine's antiderivative surface, or FD that one channel? (Low-stakes; still open.)
5. **Second-order (HVP) — RESOLVED: deferred (decision).** Not needed until needed. The `fwd<double>`
   implicit-node callback is first-order only; we do **not** pay to keep it nestable now. Retrofit
   trigger: an HVP/curvature consumer (a future regnans optimiser) appears → revisit odelia#36's
   nested tapes then.
6. **Charts-as-views generality.** One witnessed discretisation (log-mass). Kept as a fixed pairing;
   `TransportGeometry` promoted to a policy object only on a second witness. Note the desingularizing
   soil coordinate (v2 item 2) is now a **second chart witness** — so the chart concept earns its
   keep, though `TransportGeometry`-as-policy still waits for a second *transport* discretisation.
7. **The eigenvalue functional's honesty conditions (fixed-point regime).** `dλ/dθ` is non-smooth at
   a spectral-gap closure and at a marginally-active pinned set — genuine non-differentiabilities of
   the science, not numerics. The engine must **monitor the gap and active-set stability and refuse**
   (say so) rather than average through. Open: where in the θ-region do these bite (F5)?

---

## Second numerics layer — the fixed-point / equilibrium module

Model layer (Layer M) unchanged. A new, thin numerics layer beside the time-marcher:

- **The steady Eulerian-profile BVP** (dimension ~4 + L): `dF/dx = −(r/g)·F`, `dB_p/dx = −b_p·F/g`
  (`A = Σ_p a_p B_p`), sink-quadrature states, and `L` algebraic steady-`u` equations; `F(x_b)` from
  the influx law, `B_p→0` at the top. Solved by collocation/shooting in milliseconds. Its gradient is
  the **IFT adjoint of the collocation residual** (transpose of the collocation Jacobian) — reusing
  the same registered Layer-M closed forms and scalar-IFT nodes that the march uses.
- **The dominant-eigenvalue gradient:** Arnoldi for the right/left eigenvectors of the linearized
  operator `A=∂F/∂X` (local + rank-(3+L), so matvecs are O(grid)); then
  `dλ/dθ = ∇_θφ − F_θᵀ A⁻ᵀ ∇_Xφ` with `φ = yᵀ(∂F/∂X)x` — one **`adj⟨fwd⟩` nested sweep** (low-dim) for
  `∇φ` and one transposed Krylov solve. Tens of residual evals per gradient.
- **Alternative, if the code already truncates negligible-mass members:** the renewal/shift-map fixed
  point `Φ_cycle∘shift` has a genuine fixed point; its IFT adjoint's matvec is *exactly one reverse
  sweep over one recorded cycle* — i.e. it **consumes the transient engine's step-VJP as its matvec**
  (one engine, both regimes). Build the BVP (route ii) preferentially — it's exact for the
  equilibrium-as-defined with no schedule/pinning path-dependence — and keep the renewal route as the
  minimal-change fallback.
- **Validate the equilibrium gradient against FD of the residual-solved equilibrium, never against a
  re-march** (the march is contaminated by incomplete convergence + pinning path-dependence).

---

## Validation plan — test before build, cheapest first (all plain-`double`, no tape)

**Soil / multirate (from the numerical-methods consult):**
- **E2 (start here):** offline soil-block microscopy through recorded excursions — original vs
  desingularized coordinate vs kink-split; identifies the singular exponent `a`, measures the
  coordinate payoff. Pure R, no build. *(Also checks the one caveat: `K(θ)` and `ψ(θ)` may not share
  one envelope → one chart may only partly desingularize.)*
- **E1:** down-weight the soil components in the SCM error norm; does the step count recover? Resolves
  the confound in my QSS measurement — is soil the cause (→ multirate wins) or do cohorts need the
  small steps anyway? One control tweak.
- **E3:** kink audit — rejected steps / step minima vs recorded rainfall knots under variable forcing.
- **E4:** multirate prototype, values then gradients (the real build; last).

**Fixed-point regime (from the TF24 consult):**
- **F1 (highest leverage):** bin one converged marched state to a profile, evaluate the BVP residual
  on it — small residual ⇒ the Eulerian object matches the march and the whole fixed-point route is
  live; then solve the BVP from scratch and compare. Hours, no AD.
- **F3:** validate the whole fixed-point `dλ/dθ` with FD matvecs + the eigen-perturbation formula
  (zero AD) vs FD-of-λ across re-solved equilibria — tests the math object before any tape work.
- **F2:** size the frozen-schedule (transient) error — base-θ-schedule FD vs re-adapted FD on a
  depletion-timing θ-component. The dropped term.
- **F4:** adjoint conditioning through a depletion episode (forward-JVP vs reverse-VJP over one
  window) — transposed amplification near the singular boundary.
- **F5:** spectral-gap + active-set stability scans across the θ-region — flags genuine
  non-differentiabilities the engine must refuse rather than paper over.

Recommended order: **E2 + F1** first (both pure-`double`, no build, and each de-risks the largest
design bet in its regime — the desingularizing chart, and the entire BVP route).
