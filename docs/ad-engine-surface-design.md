# The odelia AD-engine surface — design (first pass)

Status: design, first pass. Fleshes out the odelia surface for the reverse-mode engine the
consultation and testing converged on. Follows the system-design skill; open uncertainties are
surfaced at the end for the Oracle rather than resolved here.

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
- **R4 — a differentiable implicit (RODAS) stepper.** A general odelia capability, not plant-only
  (regnans stiff trait dynamics; odelia#35). *Quantity + challenge upward:* the plant-soil stiffness
  that motivated this is, on measurement, **accuracy-driven not stability-driven** (see the QSS
  test), so an implicit stepper likely does **not** reduce plant's step count — R4's plant payoff is
  uncertain. Its solid payoffs are (a) a general stiff capability for other consumers and (b) the
  implicit-solve *primitive* it forces, which R2/R5 reuse. **Confirm R4 is wanted for the capability,
  not the plant-stiffness number.**
- **R5 — double path bit-identical, or documented minimal change.** The mass chart is exact only with
  the neighbour-secant compression (geometric compression, the measured ~0.2% K93 forward shift) — a
  documented change for gradient runs, accepted per `ad-census-gradients.md`.
- **R6 — one engine, many models.** K93/FF16/TF24/TF24f now; regnans later.
  *Challenge upward:* does regnans share the method-of-characteristics structure (ordered
  non-crossing particles, low-rank kernel, mass-conserving transport), or is it a generic stiff ODE
  system? This decides how much of the engine is shared vs plant-family-specific.

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

1. **The stiffness justification is weaker than the roadmap assumes.** Measured: plant-soil step
   collapse is **accuracy-driven** (tiny steps at *low* θ, far from equilibrium, corr(log dt, log ρ)
   = −0.91; every stiff step is a transient), **not** stability-stiffness. So implicit RODAS likely
   does **not** cut plant's step count, and QSS is invalid exactly where the cost is. **Question:** is
   there residual value in reverse-RODAS *for plant* (robustness near the θ→residual singularity?), or
   is R4 justified only by the general capability (regnans) and by forcing the implicit-node
   primitive? If the latter, IMEX/RODAS is a general-odelia feature, not a plant-stiffness fix — which
   changes how hard we push it.
2. **Does regnans fit the transport structure (R6)?** Determines whether the transport core is
   shared or plant-family-specific, hence how much of the engine is truly general.
3. **Kernel separability is per-canopy-mode.** Exact rank-3 for the default `(1−(z/x)^η)²`; the
   `FlatTopSoftBox` and other modes differ. **Question:** does the scan primitive need a
   non-separable fallback (a dense O(Nk) or the retained interpolator) for those modes, or do we
   restrict the exact path to the separable kernels and keep the interpolator as the general fallback?
4. **The special-function derivative.** The breakpoint antiderivative's shape parameter `c` is a
   differentiated trait, so `∂γ(s,x)/∂s` (digamma-series) is needed. **Question:** implement it in the
   engine's antiderivative surface, or FD that one channel?
5. **Second-order composability vs first-order cost.** The `fwd<double>` implicit-node callback avoids
   nested tapes for first order; HVP needs odelia#36's nested types. **Question:** design the callback
   scalar-generic for later nesting now (small cost), or defer entirely until an HVP consumer is
   witnessed?
6. **Charts-as-views generality.** One witnessed discretisation (log-mass). Kept as a fixed pairing;
   `TransportGeometry` promoted to a policy object only on a second witness. **Question:** is a
   conserved-number or remeshing variant close enough on the roadmap to justify the abstraction now?
