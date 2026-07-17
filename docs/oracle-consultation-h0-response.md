# Oracle response — H0: when does a flux coupling collapse the control out of the fast system?

*Response to [`oracle-consultation-h0-missive.md`](./oracle-consultation-h0-missive.md). Recorded
verbatim (lightly reformatted). Dated 2026-07-17. Hypotheses to test, not verdicts (guide §7); the
response names its own discriminating measurement — the shadow-price (`λ_j`) spread across members — as
"the one cheap measurement that could still change the build." This thread is **orthogonal to the
committed multirate build**, which the response confirms stands regardless.*

---

## A flux collapses exactly when it has a conjugate price — the characterization, the legitimate rewrite, and the two-minute triage

Your diagnosis is correct and the instinct behind it is almost the theorem. The sharp discriminator is
not quite "marginal vs. primal flux" — it is: the fed-back byproduct must equal the `u`-gradient of the
member's Lagrangian at the KKT point, up to a known, member-independent matrix field `K(u)`. A primal
flux satisfies that exactly when it possesses a conjugate price in the problem — when the stock couples
to the inner problem through a shared price channel in which the objective is affine, with the flux as
the coefficient. Your system fails this because `u` enters through a member-local constraint, so the
marginal picks up the shadow-price-weighted supply sensitivity `λ_j·∂e/∂u` — different information from
the flux, related to it only through the solve itself.

### 1. The characterization

Per member: `V_j(u) = max_p P(p; x_j, u, s)` s.t. `g(p; x_j, u, s) = 0`, multipliers `λ_j`. The
constrained envelope theorem gives

```
∇_u V_j = ∂P/∂u + λ_jᵀ ∂g/∂u        (at the KKT point)
```

Collapse target: `a = Σ_j c_j = K(u)·∇_u V` with `K` known, p- and member-independent. (Demand it per
member, `c_j = K∇_uV_j`; aggregate-only collapse via cancellation across members is not robust as the
population `{x_j, w_j}` evolves, and is untestable.)

Constructive form (sufficient, and necessary for robust collapse): after moving any purely-`u` term into
`b`, the `u`-dependence of each member's Lagrangian factors through one shared channel `φ(u) ∈ ℝ^d`, in
which it is affine with the fed-back byproduct as coefficient:

```
L_j(p, λ; u) = B_j(p, λ; x_j, s) − φ(u)ᵀ E_j(p; x_j, s)
⇒  ∇_u V_j = −Dφ(u)ᵀ E_j*      ⇒   a = Σ_j E_j* = −(Dφ)⁻ᵀ ∇_u V
```

so `K = −(Dφ)⁻ᵀ`, requiring `Dφ` invertible (monotone price map) over the reachable stock set. Why
affinity is forced: `K` member-independent means `∂_u L_j` must be linear in `E_j` with a shared
coefficient across the whole realizable range of fluxes the population sweeps — and linearity of the
`u`-gradient in `E` integrates back to exactly the bilinear pairing. Any nonlinear-in-`E` stock cost
gives `∇_uV_j` as a nonlinear image of `E_j`, and a sum of nonlinear images cannot be inverted to the
sum of fluxes without per-member information — the aggregation step is what makes bilinearity necessary,
not just convenient. Two harmless generalizations: member-dependent scalar exposures
(`P_j = B_j − ε_j φᵀE_j`) collapse onto the extracted flux `ε_jE_j`, which is what a conservation
balance feeds back anyway; and `u` may enter constraints if it does so through the same `φ` and the
byproduct is defined as `∂L/∂φ` (a Lagrangian marginal), not a primal output.

So, answering your Q1 list directly: separability of `P` in `u` is neither necessary nor sufficient;
potential/gradient structure is the consequence, not the condition; and Legendre duality enters not as
an alternative condition but as the model-level rewrite (§3). The condition is the conjugate pairing,
full stop.

### 2. What the collapse buys — with one correction to my own H0 framing

Three things, and it's worth being precise because one of them I overstated. (i) **Structure.** With
tracked controls the joint system becomes a generalized gradient flow of one extended potential
`𝒱(u, p̂) = Σ_j P_j(p̂_j; u)`: `u̇ = b + K∂_u𝒱`, `p̂̇ = k∂_p𝒱`. The Jacobian's off-diagonal coupling
blocks are mutual transposes up to the mobilities → symmetrizable, real spectrum, no oscillatory
coupling stiffness, and a Lyapunov-type energy monitor for free when `b` has a potential. (ii) **The
anti-plateau property — the deep computational prize.** Your plateau came from deleting `∂a/∂u` from the
fast Jacobian. Under collapse, any smooth surrogate of the scalar `V̂` (or evaluation along any smooth
control representation) yields a fast system whose coupling Jacobian is `K∇²V̂` — the feedback is
approximated, never deleted; surrogate error perturbs the potential, not the structure. Surrogating one
scalar field is also vastly easier than surrogating the L-vector `a`. (iii) **Accuracy — corrected.**
The second-order insensitivity attaches to the value and to gradients of smooth representations, not to
the flux evaluated at an approximate control: `E(p̃)` has O(δ) error, same as always. But
`V̂(u) := ΣP(p̃(u), u)` has O(δ²) error, and because `∂P/∂p = O(δ)` at `p̃`, the representation's own
derivative error is suppressed to O(δ·δ′) in `∇V̂`. **Operational rule under collapse: build a smooth
`V̂`, then differentiate it — never approximate the flux directly.** That rule is what would have
retired the micro-rate control apparatus; it is exactly what a constraint-flux coupling cannot offer.

### 3. Q2 — shadow-price coordinates, and the legitimate rewrite

When the pairing holds, the coordinate change is optional (keep `u`; the gradient structure is the
payoff), but note the unification: the price map is typically steep where the stock depletes — marginal
value diverging at the bound — so `w = φ(u)` tends to be the desingularizing coordinate recommended
earlier. One transformation, two problems. Tape contracts improve outright: `φ`, `K`, `∂P/∂u` are
closed forms; implicit nodes leave the micro loop entirely.

When it fails (your case), the transform cannot manufacture it. Carrying `μ = ∇_uV` as the fast state
requires inverting a population-dependent map every micro step — an implicit node coupled to all
members, tape-hostile — and the transform degenerates wherever `V` loses curvature, which is typically
near the bound: it relocates the singularity to the worst place. Don't.

The legitimate route is a **model-level dualization**: replace the member-local hard balance
`e(w; q, u) = 0` with a shared, stock-dependent tariff `−φ(u)ᵀE` in the objective. This is exact only if
the member-local shadow price is genuinely a function of `u` alone — generically false. But: your
measured near-invariance of `p*` across members makes near-invariance of `λ_j` plausible, and that opens
two graded options. **(a)** If `λ_j(u) ≈ λ̄(u)` tightly, adopt the priced model as a documented change —
collapse by construction, arguably better physics (transport through a shared medium is a price). **(b)**
Otherwise, a **defect/control-variate hybrid**: `a(u) = K̄(u)∇_uV(u) + r(u)`, with `K̄` fit per leg from
`λ̄`, the gradient part evaluated at the micro rate (cheap, structure-carrying) and the residual `r`
refreshed at the macro rate. The plateau caveat applies with full force: this is sound only if `r`
carries little of `∂a/∂u` — measure the fraction of the coupling Jacobian captured by `K̄∇²V` along
recorded excursions before trusting it; if that fraction is not large, (b) is frozen-coupling redux and
must be dropped.

### 4. Q3 — the triage, in minutes not an afternoon

1. **Symbol audit (static):** does `u` appear in any inner constraint while the byproduct is a primal
   output? → exact collapse fails (your case). If `u` appears only in the objective, continue.
2. **The identity — the affinity probe (no re-solves):** fix one member's `(x_j, u, s)`; sample `p`
   across its feasible range; compute the pairs `(E(p), ∂P/∂u(p))` — both closed-form. Collapse ⇔
   `∂P/∂u` is affine in `E` with p-independent slope: regress, reject on curvature or residual. A dozen
   gradient evaluations.
3. **Member invariance:** repeat at 3–5 members at the same `u` — the slope `−Dφᵀ` must be
   member-independent; repeat at 2–3 stock levels to map `K(u)`.
4. **Definiteness:** `Dφ` invertible and sign-definite over the reachable box (licenses `K⁻ᵀ` and the
   gradient-flow qualities).
5. **If step 1 failed (constraint coupling):** compute the `λ_j` spread across members at fixed `u`,
   normalized by the constraint's u-sensitivity. Tight → options 3(a)/(b) above, gated by the
   residual-Jacobian measurement.

Steps 1–4 are the standing pre-build check for every new member model; step 2 is the single identity you
asked for.

### 5. Design guideline, and what survives regardless

Forward-looking, this is a **coupling-design rule:** when the science permits, pose stock–population
interactions as shared tariffs bilinearly paired with the conserved flux — the collapse then holds by
construction, the fast system is a gradient flow, the price coordinate desingularizes the bound, and the
entire control apparatus drops out of the micro loop. When it doesn't hold — as here — you lose the
forward collapse but keep, unconditionally: envelope smoothness in the adjoint (stationarity of the
value channel is independent of the flux channel, so what you already rely on is safe), second-order
tolerance for every stationary output, and the hybrid of §3(b) as a measured option. For your current
system the one cheap measurement that could still change the build is the `λ_j` spread; everything else
stands as committed.

---

## Our reading / next action

**The verdict for TF24 is unchanged: exact collapse fails — but now we know precisely why, and what
would have to be true instead.** Triage step 1 confirms our structural diagnosis on sight: in TF24 the
stock `u = ψ_soil` enters a **member-local** constraint (each cohort's soil→collar hydraulic supply
function), and the fed-back byproduct is a **primal water flux** (`resource_depletion` / the
`soil_consumption_[ℓ]` per layer), not a Lagrangian marginal. So the marginal carries the
shadow-price-weighted supply sensitivity `λ_j·∂e/∂u`, which is different information from the flux — no
member-independent `K(u)` exists, and the collapse does not hold. This matches the earlier structural
finding (`oracle-consultation-commit-review-response.md`, H0 section) and the R4 deferral
(`tf24-reformulations-evaluation.md`).

**Three things in this response are genuinely new versus that earlier finding:**

1. **The recognition condition is now exact and testable.** Not "marginal vs. primal flux" (our
   heuristic) but **conjugate pairing**: the Lagrangian's `u`-dependence must factor through one shared
   channel `φ(u)` in which it is *affine* with the flux as coefficient (a **bilinear tariff**
   `−φ(u)ᵀE`), giving `K = −(Dφ)⁻ᵀ`. Affinity is *necessary* for robust aggregate collapse (a sum of
   nonlinear-in-`E` images can't be inverted to the sum of fluxes without per-member info). The
   **affinity probe** (step 2) is the one identity to run per new member model — a dozen closed-form
   gradient evals, no re-solves.

2. **A self-correction on the accuracy claim we had banked.** The O(δ²) second-order insensitivity
   attaches to the **value `V̂`** and to **gradients of smooth control representations** — *not* to the
   **flux `E(p̃)`** at an approximate control, which is O(δ) like always. The operational rule under
   collapse is therefore: **build a smooth `V̂`, then differentiate it; never approximate the flux
   directly.** For TF24 this is moot (no collapse), but it corrects the reasoning in the h0-missive and
   is the load-bearing rule for any future collapsing model.

3. **Two graded fallbacks that don't require exact collapse**, both keyed to the *measured*
   near-invariance of `p*` across cohorts (commit-review): **(3a)** a priced model (shared tariff) as a
   documented change *if* `λ_j(u) ≈ λ̄(u)` tightly; **(3b)** a control-variate hybrid
   `a = K̄(u)∇_uV + r`, gradient part at the micro rate, residual `r` at the macro rate — **gated** by
   measuring how much of `∂a/∂u` the `K̄∇²V` term captures (else it is frozen-coupling redux and must be
   dropped, per the plateau result).

**Mapping to the real system (the symbols):**

| neutral | TF24 |
|---|---|
| control `p` | collar water potential `q` (`root_collar_psi`) |
| stock `u` | soil state `ψ_soil` / `θ` per layer (`L ≤ 5`) |
| flux byproduct `E` / `a` | water uptake `resource_depletion` (`soil_consumption_[ℓ]`) |
| objective marginal `∂P/∂u` | marginal carbon profit `dprofit/dψ_soil` |
| shadow price `λ_j` | value of soil water to cohort `j` ≈ `(∂P_j/∂ψ)/(∂E_j/∂ψ)` |
| would-be channel `φ(u)` | the soil→collar hydraulic supply — **member-local**, hence no collapse |

**Connection to the reformulation menu.** This response is the theory under R4
(`tf24-reformulations-evaluation.md`): R4 (dissipative/gradient structure) needs `a = ∇_uV` (H0) and was
deferred — this confirms *why* and hands us the exact pre-build test. R1 (exact drainage recession) and
R5 (batch the `m` solves) are orthogonal and stand. §5's coupling-design rule is the forward-looking
note: a future member model *posed* in the marginal-coupled (tariff) form would drop the control
apparatus by construction — worth designing toward on purpose, and cheap to check per model.

**What stands regardless (no change to committed work):** envelope smoothness in the adjoint (already
relied on — it is *why* tracked and argmax gradients agree to first order); second-order tolerance for
stationary outputs; and the committed build — the m-collocation `(L+m)` fast subsystem with tracked
controls (TF24f) — which never depended on H0.

**Next action (guide §7 — the one cheap measurement).** Run the **`λ_j`-spread triage** (step 5): at a
fixed soil state, for real transpiring cohorts, finite-difference `profit_` and `soil_consumption_[ℓ]`
w.r.t. `ψ_soil[ℓ]` **per cohort**, form `λ_{j,ℓ} = (∂P_j/∂ψ_ℓ)/(∂E_{j,ℓ}/∂ψ_ℓ)`, and measure its spread
across cohorts `j` (mapped across 2–3 soil levels for `K(u)`). This sidesteps the prior
`h0_envelope_check.R` obstacle (no transpiring *standalone* leaf reachable through the R interface) by
measuring at the **patch level with real cohorts** — the same vehicle E2/E3 used. Outcome:
- **tight spread** → 3(a)/(b) become live candidates (3b then gated by the residual-Jacobian fraction);
- **wide spread** → the flux is genuinely member-specific, 3(a)/(b) are out, and the H0 thread closes
  with data — the committed tracked-control build is the answer, full stop.

## E-H0 measured (2026-07-17) — `scripts/tf24-multirate/eH0_lambda_spread.R` — λ_j is member-dependent; H0 thread closes

Triage step 5 on the real solver. Vehicle: a real 8-cohort stand (heights 14→0.7 m) with its **frozen
canopy light** (openness 1.00 → 0.36 down the profile); per-cohort leaf objective `P_j` (`profit_`) and
water flux `E_j` (`E_up_`) read from `Individual$compute_rates(env)`; `λ_j = (∂P_j/∂θ)/(∂E_j/∂θ)` by
central FD in a uniform soil-moisture perturbation, mapped across four soil levels. This sidesteps the
`h0_envelope_check.R` obstacle (standalone leaves are degenerate — negative profit, invariant to light,
re-confirmed here) by measuring at the patch level with real transpiring cohorts.

| θ | λ̄ (price of water) | CV across cohorts | max/min | n solved |
|--:|--:|--:|--:|--:|
| 0.34 (wet) | 3.04e5 | 35.6% | 2.40 | 8 |
| 0.26 | 3.31e5 | **60.0%** | **4.14** | 8 |
| 0.20 | 3.50e5 | 43.2% | 2.98 | 8 |
| 0.16 (dry, near-singular) | 6.61e5 | **20.0%** | **1.64** | 8 |

**The spread is systematic, not noise:** at every θ, `λ_j` is **monotone in cohort height** — taller,
better-lit cohorts value water 2–4× more than shaded ones (the light gradient sets the marginal
water-use efficiency). So a single shared price `λ̄(θ)` would **misprice shaded vs. canopy cohorts by up
to ~4×** in the wet/mid regime. Two secondary facts land in the scheme's favour but don't overturn this:
(i) the spread **tightens toward the dry, near-singular bound** (CV 20%, max/min 1.64 at θ=0.16) — the
price is most uniform exactly where the fast difficulty concentrates; (ii) `λ̄(θ)` **rises as the soil
dries** and steepens at the dry end — the price map `K(u) ~ 1/λ̄` behaving as the Oracle predicted
("steep where the stock depletes").

**Verdict — the measurement does not change the build.**
- **3(a) priced/tariff model (single shared `φ(θ)`): not licensed.** The systematic, light-ordered 2–4×
  spread across cohorts is exactly the "member-local shadow price" the response warned is generically
  false; adopting one `λ̄(θ)` would distort the carbon economy of understory vs. canopy cohorts.
- **3(b) control-variate hybrid `a = K̄∇_uV + r`: not outright killed, but unpromising and un-adopted.**
  Because the spread is *structured* (height-ordered), the residual `r` carries real, member-specific
  structure — not the small noise the hybrid needs to refresh `r` only at the macro rate. The response's
  gate (the fraction of `∂a/∂u` captured by `K̄∇²V`) would have to be measured to be sure, but the
  systematic spread argues against it, and it buys nothing the committed design lacks.
- **The one narrow opening:** near the dry bound (θ ≲ 0.16) the price is uniform enough (max/min 1.64)
  that a *dry-regime-local* tariff could plausibly pay — a small, optional refinement, not a build
  change, and only where uptake is already collapsing.

**Net:** the H0 exact collapse remains inapplicable to TF24 (confirmed structurally *and* now
empirically), and the graded fallbacks it opened are not worth adopting — the flux is genuinely
member-specific. **The committed tracked-control (TF24f) + m-collocation build is the answer**, and the
H0 thread closes with data. Envelope smoothness in the adjoint (the thing we actually rely on) is
untouched. For the *reformulation* question, this steers away from an H0-style priced rewrite and toward
the mechanistically-interpretable numerical reformulations (R1 exact drainage recession; TF24f finite
acclimation; the B3 layer-shutdown smoothing) — see [`tf24-reformulations-evaluation.md`].
