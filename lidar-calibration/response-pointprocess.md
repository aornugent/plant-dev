# Oracle response — computing E[H] under cheap-mean / expensive-sample access

*Response to [`elicitation.md`](./elicitation.md)
(the v4 pure-numerical elicitation). Recorded verbatim (lightly reformatted), dated 2026-07-18. Hypotheses
to test, not verdicts (guide §7).*

> **Read the framing audit (below the response) first.** Much of this response's distinctive machinery is
> downstream of representational choices we planted in the elicitation, so parts answer the question we
> posed rather than the problem we have. The response is internally sound; the concern is our framing.

## Response (verbatim)

### Verdict on the framing first
`g(θ) = E[H(X)]` is the right object. `D(θ) = H(m(θ)) − g(θ)` is not — it is undefined until a lift is
chosen, so it is a property of the triple `(H, μ_θ, lift)`, not of `(H, μ_θ)`. Two other parts of the
framing deserve rejection or repair:

1. **Wrong calculus.** `H` does not extend to densities, so Taylor expansion in a Fréchet sense is the wrong
   tool. The native derivative on point sets is the add-one-point difference
   `D_u H(ξ) = H(ξ∪{u}) − H(ξ)`, with `D²_{u,v}H(ξ) = H(ξ∪{u,v}) − H(ξ∪{u}) − H(ξ∪{v}) + H(ξ)`. The natural
   expansion of `E[H]` is then in factorial moment measures `α_k(θ)` (the point-process analogue of moments;
   `α_1 = m`), pairing `D^k H` against `α_k`. This dissolves the "H isn't defined on m" objection: you never
   evaluate `H` on a density, only on configurations.
2. **Wrong expansion point.** Expanding around the global mean of a mixture is a category error:
   `m(θ) = ∫ w(s) m(θ,s) ds` may resemble no realization at all (mean of a multimodal law). The expansion
   point should be the conditional means `m(θ,s)`, with the `s`-average taken outside `H`.
3. **A wording/formula mismatch worth resolving.** You say "superposition" but write
   `μ_θ = ∫ μ_{θ,s} w(s) ds`, which is a mixture of laws. Both give additive intensity, but they differ
   completely for `g`: a mixture gives `g(θ) = ∫ w(s) E[H | s] ds` and a between-`s` variance term; a true
   superposition (union of independent components) gives additive cumulants and no Jensen gap over `s` — and
   if the components are many, sparse, and independent, Grigelionis/Le Cam-type bounds certify cheaply that
   `μ_θ` is nearly Poisson with intensity `m`, in which case the mean-based surrogate is provably accurate
   with no samples at all. One look at the sampler settles which case you are in. I proceed with the mixture
   reading (it matches the formula) and flag the variant where it matters.

### 1. The defect
Fix a reference process `R(m)` — a genuine point process with intensity `m`, not a single lifted
configuration (see §4). Define the honest defect `D_R(θ) = E_{Y∼R}[H(Y)] − g(θ)`. Two exact anchor facts:

- If `H` is additive, `H(ξ) = c + Σ_{u∈ξ} h(u)` (equivalently `D²H ≡ 0`), then `g(θ) = c + ∫ h dm(θ)`
  exactly. All bias is a second-difference-and-higher phenomenon.
- If `R` is Poisson with intensity `m` and the component actually is Poisson, `D_R = 0` in all orders
  (Slivnyak–Mecke: Poisson is the unique process whose reduced Palm law equals its law; equivalently
  `α_k = m^{⊗k}` for all `k`).

The leading term, for `R = Poisson(m)`:

```
D_Poi(θ) ≈ −½ ∫∫ K₂(u,v) [α₂(θ; du,dv) − m(du)m(dv)],   K₂(u,v) = E[D²_{u,v}H(·)]
```

i.e. (H's curvature kernel) contracted against (pair-correlation excess over Poisson), with remainder
controlled by third differences × third factorial-moment excess. Sanity check: `H(ξ) = |ξ|²` gives
`D² ≡ 2` and the formula returns exactly `Var N − E N`, the over/under-dispersion. Rigorous versions of this
bound are exactly what Stein's method for Poisson process approximation (Barbour–Brown) provides, with the
discrepancy measured by Palm distances.

Computable negligibility conditions, each cheap in the relevant currency: (a) H nearly additive on the
support — probe `K₂` by adding/removing/jittering points on lifted configurations, costing only extra
`H`-evals; (b) components nearly Poisson at second order — per-component count dispersion index
`Var(N|s)/E(N|s) ≈ 1` and pair correlation `≈ 1`, estimable from a handful of samples because each sample
carries `O(N²)` pairs; (c) in the true-superposition reading, the Le Cam/Grigelionis certificate computed
entirely from the cheap component means. The product of (a)-magnitude and (b)-magnitude bounds `|D_R|`; if
either is small you may stop sampling.

Crucially, under the mixture the excess splits:

```
α₂ − m⊗m = ∫ w(s) [α₂,s − m_s⊗m_s] ds   +   [∫ w m_s⊗m_s ds − m̄⊗m̄]
             (within-component: sample-only)      (between-component: CHEAP, exact, ⪰ 0)
```

The second term — often dominant when components are well separated — costs nothing. Only within-component
non-Poissonianity is genuinely sample-side.

### 2. Minimal information
The exact ledger: `g(θ)` is the pairing of `H`'s difference tensors `{D^k H}` with the factorial-moment
sequence `{α_k(θ)}` (the factorial-moment expansion; for `H(ξ) = z^{|ξ|}` it reduces to the classical PGF
expansion). So the minimal extra information beyond `m` is not whole moment measures but a few contractions:
`κ_k(θ) = (1/k!)⟨D^k H, α_k − α_k^{ref}⟩`, `k = 2` (rarely 3) — a handful of scalars per output dimension.
These are (i) partly cheap (the between-`s` part above), (ii) sample-efficient where sample-only (pair
statistics are U-statistics: few configurations suffice), and (iii) typically smooth in `(θ,s)`, hence
amortizable across the family. That is why few expensive samples can suffice: you are estimating a small,
smooth, low-dimensional correction, not `g` itself.

Two structural shortcuts worth probing for: if `H` factors through `q` linear statistics,
`H(ξ) = φ(⟨f₁,ξ⟩,…,⟨f_q,ξ⟩)`, the minimal information collapses to the `q×q` within-component covariance
excess and the delta method gives `D` in closed form (`½ tr(∇²φ · Σ_s)`), with within-component CLTs handing
you the law of `H` nearly for free. And if `H` is well approximated in the exp-linear algebra
(`Σ_j c_j exp⟨f_j,·⟩`), then under Poisson components everything is closed-form via the generating functional
(`E exp⟨f,X⟩ = exp∫(e^f−1)dm`) — the Cox structure makes `g` cheap outright, samples correcting only the
residual.

### 3. Cheapest scheme
Be explicit about currency: `H`-evals cost the same on any input; expensive samples carry an acquisition
premium. The surrogate loop spends only `H`-evals; the correction loop spends both.

1. **Level 0 (surrogate).** `ĝ(θ) = ∫ w(s) E_{Y∼R_s(θ)}[H(Y)] ds`, with `R_s` = the maximum-entropy process
   matching all cheap facts about component `s` (default Poisson(`m(θ,s)`); count-conditioned if the count
   is known to be deterministic). Estimate with QMC over `s`, a modest lift-replicate count `K`, and common
   random numbers across θ by transporting points via inverse-CDF along `m(θ,s)` — this makes `ĝ` smooth in
   `θ` and reusable across the whole family.
2. **Level 1 (correction).** At `n` design points `θ_j` (space-filling in `ℝ^p`, `p` small), draw `M_j`
   expensive samples, record or infer each sample's `s`, and form
   `Δ̂(θ_j) = M⁻¹ Σ_i [H(X_i) − ĝ(θ_j, s_i)]`. This is a conditional control variate / post-stratification:
   the between-`s` variance (cheaply known, often dominant) is removed exactly; only within-component
   fluctuation remains. Fit `Δ(θ)` with a GP or low-order polynomial — it is small and smooth because it is
   a pure second-order defect.
3. **Output.** `g̃ = ĝ + Δ̃`. Gradient: `∂ĝ/∂θ` exactly via the Margulis–Russo/Mecke perturbation formula
   for Poisson functionals, `∂_θ E[H(Poi(m_θ))] = ∫ E[D_u H(Y)] ∂_θ m_θ(du)` (implemented per draw by signed
   insertion of a point sampled ∝ `|∂m/∂θ|`), or pathwise through the coupled transport if `H` is a.e.
   differentiable in positions; plus `∂Δ̃/∂θ` from the fit, validated by CRN finite differences of the true
   sampler at one `θ_j` if it accepts seeds. Law of `H(X)`: mixture over `s` of the surrogate pushforward
   laws (this captures multimodality cheaply, since between-`s` spread is exact), with per-stratum mean shift
   `Δ̂_s` and a variance rescale by the sampled/surrogate variance ratio estimated at the design points;
   within-component Gaussianization is legitimate when `H` is a smooth statistic of many points, checkable
   from the same samples. Tails beyond a couple of moments genuinely require samples in proportion to the
   resolution wanted.

**Frontier.** Error² ≈ interpolation error of `Δ` (for analytic `Δ` on a compact in `ℝ^p`, `n` grows
polylogarithmically in `1/ε`) + `E_s Var(H|s) / (nM)` + a cheap-loop term you drive down with `H`-evals.
Against naive per-query MC the gain factor is roughly `(#θ-queries) × Var(H)/E_s Var(H|s)` — the family is
paid for once, and the cheaply-known between-component variance is never paid for at all. Reuse each
expensive sample maximally: one `H`-eval, plus free harvesting of `N`, pair statistics, and the `s`-label;
add/remove probes of `K₂` can share the same configurations. If `H`-evals themselves bind, fit an emulator
of `H` on summary features using the lift ensemble and validate on the samples. Failure mode to state
honestly: if probes show large `K₂` and strongly non-Poisson components and `Δ(θ)` rough (e.g. `H` has count
thresholds), the smooth-correction premise fails; fall back to fitting a richer generative reference
(count-law- and pair-correlation-matched, smooth in `θ`) or to plain stratified MC — stratification on the
cheap `ĝ(θ,s)` is a guaranteed variance reduction regardless.

### 4. The lift
The lift is not a nuisance parameter; it is a model choice for the moments `m` does not determine. A single
deterministic lift (quadrature points at density quantiles) makes three characteristic errors: it quantizes
the count, so `H∘L` jumps as `round(mass(θ))` crosses integers — poison for `∂g/∂θ`; it is super-uniform,
i.e. its pair structure has negative excess, biasing the curvature term with a definite (and wrong) sign
when `μ` has shot noise; and it aliases `H`'s fluctuation response into a single arbitrary configuration.
Sensitivity between two lifts with equal intensity is exactly the §1 pairing: `K₂` against the difference of
their pair structures, plus (count sensitivity of `H`) × (difference of count laws).

Prescription: use a randomized lift = a bona fide reference process, chosen as the max-ent process
consistent with everything cheap, and average over it; couple its randomness across `(θ, s)` for smoothness;
and report the lift-ensemble spread of `H` as a diagnostic — it is a cheap lower bound on the information gap
of §2, and if `H` is invariant across lifts matching `(m, count law, pair correlation)`, you have
empirically verified that those summaries pin `g`.

### 5. What you are missing / quiet contradictions
Beyond the three verdict items: (i) the setup's claim that "nothing beyond the mean is available except
through samples" is contradicted by its own superposition bullet — the family `{m(θ,s), w}` carries the full
between-component covariance (indeed all between-component moments) for free; exploit it before spending a
sample. (ii) Draw the ledger of what `m` actually carries: you say the mean is "a density over the attribute"
and that it "does not carry positions and count." If `m` truly carries no positional information, the
spatial arrangement is 100% sample-side; then the reference process must borrow a positional law fitted from
pooled samples (assumed smooth across `(θ,s)` — verify), and this, not the nonlinearity of `H`, may dominate
the budget. (iii) The clean change of variables is densities → factorial moments / generating functionals,
Fréchet derivatives → add-point differences, and Palm calculus as the exact language for "distance from
Poisson." (iv) Decomposing around a mean is the right move only conditionally on `s` and only relative to a
declared reference process; around the global `m` it is wrong whenever the cheap Jensen gap
`∫ w H-surrogate(m_s) − H-surrogate(m̄)` is non-negligible — compute that first, it costs only `H`-evals.

### Ranking the given structure
1. Superposition/mixture with cheap `m(θ,s)` — most load-bearing: conditional expansion point, exact
   between-component ANOVA (for `g` and the law of `H`), stratified control variates, cheap multimodality.
2. `H` reads count and positions — load-bearing as a pointer: it locates the sample-only information (count
   law, spatial pair structure) and warns the attribute-marginal mean may carry no positions.
3. Finiteness of samples — defines the irreducible channel: within-component dispersion and pair-correlation
   excess, contracted with `K₂`.
4. `∂m/∂θ` — load-bearing for gradients (Mecke formula) and for coupling lifts smoothly across `θ`;
   incidental to the bias itself.
5. Ground-truth MC — methodologically necessary (fitting `Δ`, validation), but not structural; every scheme
   uses it identically.

*(The response closes by asking what `H` actually is — does it factor through linear statistics? is it
count-continuous? — and whether the sampler exposes `s` and accepts seeds; those three bits specialize the
scheme.)*

---

## Framing audit — did we elicit correctly?

**Short answer: partly. The response is internally sound (the `H=|ξ|²` sanity check verifies numerically;
Slivnyak–Mecke, Mecke/Margulis–Russo, Grigelionis/Le Cam, Barbour–Brown are all real and correctly used).
The concern is not the math — it is that the response's most distinctive machinery is manufactured by three
representational choices we planted.**

**Contamination 1 — "H is not defined on the mean; it needs a lift" is false for our operator.**
Radiative-transfer operators take a homogenized density field as input — our own research recorded one run
on a homogenized foliage field and *measured* the resulting bias. So `H(m)` is computable, just biased; the
object is the bias `E[H]−H(m)`, well-defined with no lift. Asserting "needs a lift" manufactured all of §4
and made the Oracle *open by correcting us* ("`D` is undefined until a lift is chosen"). That correction is a
symptom of our premise, not a discovery. The honest primitive: `H(m)` is a computable biased surrogate;
quantify and correct the bias.

**Contamination 2 — we put the whole problem on point-process rails.** Defining `𝒳` as finite point sets
with positions and `m` as the intensity made point-process calculus (factorial moments, Palm, Poisson
approximation, Mecke) the only natural toolbox; any competent reasoner lands there. That is a legitimate
representation but a *leading choice at the representational level* — the same error as naming a method, one
layer down. A field/density framing of the same observable would likely have returned homogenization/UQ
machinery. We sent one framing and got its canonical answer; we have not triangulated (guide §6).

**Contamination 3 — the mixture/superposition ambiguity was ours.** We wrote "superposition" but the formula
was a mixture, and never fixed whether `μ_θ` is the law of one observation or of an aggregate. The Oracle
correctly made this the central branch, with the sharp consequence that a superposition of many sparse
independent components is nearly Poisson (mean suffices, no samples). The answer swinging entirely on a
distinction we left ambiguous shows it was load-bearing and ours to resolve.

**Deliberate scope limit (not contamination):** we sent the forward problem (`compute E[H]`); the goal is
the inverse (recover θ / read dynamics off a snapshot). The response is machinery for the forward map, a
means, not an answer to the goal.

### What survives the audit (framing-robust — keep)
- **The decisive quantity is `H`'s non-additivity.** If `H` is additive (`D²H≡0`), `g = c + ∫h dm` exactly —
  the mean suffices, no samples, no defect, no lift. For lidar this non-additivity *is occlusion*.
  Representation-independent, and cheap to measure.
- **Expand per-component (per-patch-age), not around the global mean** — mixing multimodal per-age laws into
  one mean and pushing it through `H` is a category error. Validates keeping plant's age-resolved means.
- **Between-component (between-age) variation is free** from plant's per-age means; only within-age is
  sample-side.

### What is framing-dependent (hold until the representation is checked)
- The lift-ensemble machinery (§4) — largely moot if `H(m)` is computable-but-biased (our case).
- "Nearly Poisson ⇒ mean suffices with no samples" — hinges on the point-process reading and on positions
  being near-Poisson (often clustered/regular — check).
- The factorial-moment / Palm program as *the* method — it is the answer to the framing we chose, not
  established as the right object for the real problem.

### Cheapest test — and it dodges the contamination
Measure how non-additive the actual observation operator is: take a realized scene, add/remove one element,
and see how far the signal departs from the sum of individual contributions (the occlusion/saturation
level). Weak → the mean is a good surrogate and most of this response is unnecessary. Strong → a correction
is genuinely needed, and *then* the representation question (point process vs field) decides which machinery.
Run this before adopting anything above.

### Consequence for the next elicitation
(a) Drop "H not defined on m" — state that `H(m)` is computable but biased, and make the bias the object.
(b) Resolve mixture vs aggregate explicitly. (c) Consider a *second, field-based* framing of the same
observable, to triangulate against this point-process answer — trust the mechanism only where the two
framings converge.
