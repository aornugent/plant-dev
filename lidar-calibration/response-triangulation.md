# Oracle responses — two framings (law-space, map-space) and their triangulation

*Responses to the two elicitations that passed the classifier: **v6** (law-space — a family of
distributions `μ_θ`, cheap mean, expensive draws, nonlinear `H`, mixture over a scalar index `s`) and
**v7** (map-space — a deterministic map `F(θ,c)` swept over known conditions `c`, reverse-mode gradient,
discretization). Recorded 2026-07-18. Hypotheses to test, not verdicts (guide §7). Each proposes its own
full-fidelity discriminating experiment; run those before building.*

> The two framings each saw only **half** the system, because we split it: v6 carried the latent mixture
> (no swept conditions); v7 carried the swept conditions (no mixture). Their apparent disagreement about
> where the leverage lives is therefore an artifact of our two inputs, not a genuine fork. Read the
> triangulation at the end — the convergences are the trustworthy signal; the "s vs c" divergence tells us
> the real move is to combine both axes.

## Response A — law-space framing (to v6), recorded

**Verdict.** `g(θ)=E[H(X)]` is the right integral, but the implicit "start from `H(m)` and correct it" is
wrong: with well-separated components `m(θ)` is a *phantom point no draw resembles*, so every expansion
anchored there is vacuous. Load-bearing fact: **expectation is linear in the law, not in the state.** The
mixture gives `g(θ)=∫ g(θ,s) w(s) ds` **exactly**, confining all of `H`'s nonlinearity to *within-component*
fluctuations (small). Scheme: cheap componentwise skeleton `Σ_j w_j H(m(θ,s_j))` + post-stratified /
control-variate MC whose variance is only the *within*-component variance, amortized across `θ` by fitting
the small smooth residual on the manifold. Caveat: if the law of `H(X)` is itself multimodal, `g` is
"between the modes" of `H(X)` just as `m` is between modes of `X` — so the **primary deliverable is the
mixture law of `H(X)`**, `g` a derived scalar.

- **§1 Formalization.** (A) state-space/perturbative (`X=m+δ`, expand `H`) is the wrong framing here — `‖δ‖`
  ~ mode separation, no mass near `m`, and the expansion must hold across an inter-mode gap `H` may not even
  be defined on. (B) law-space/linear-functional: `μ_θ` primary; `m=⟨id,μ_θ⟩` and `g=⟨H,μ_θ⟩` are both
  *linear* functionals; the mixture is a linear decomposition, so `g(θ)=∫g(θ,s)w(s)ds` holds with **no
  smoothness of `H` across the gap required**. Distribution: pushforward `H_#μ_θ=Σ_j w_j H_#μ_{θ,j}`. (B)
  survives in non-vector-space settings; (A) doesn't.
- **§2 Bias.** Exact `C²` remainder identity; taking expectations kills the linear term (the only thing the
  mean buys). Generic bound `|bias|≤(L/2)E‖X−m‖²` is "correct and useless" — by law of total variance
  `E‖X−m‖²=σ_w²+σ_b²`, `σ_b²`=O(sep²) and `L` must hold across the empty gap. Usable hierarchical split:
  `g−H(m)=Δ_b` (between, **computed exactly from cheap means, subtractable for free**) `+` within (small if
  concentrated); per component `g_s−H(m_s)=½tr(D²H(m_s)C_s)+r_s`, local constants. Sign uncontrolled unless
  `H` globally convex/concave.
- **§3 Minimal information.** To 2nd order, beyond all the means `g` needs **one scalar per component**:
  `τ_j=tr(D²H(m_j)C_j)` (curvature-weighted within-variance). Necessity: means-only leaves `C_j` free →
  irreducible worst-case error `½Σw_j L_j R_j²`. Draws (or a validated fluctuation model) necessary iff that
  exceeds `ε`; the **paired residual `E[H(X)−H(m_S)]` estimates the within term exactly, to all orders** —
  you never need `τ_j` explicitly. Cheap escape to *test*: **index jitter** — if `X≈m(θ,s+η)`, `C_s` is
  rank-one along the cheaply-known `∂_s m`, and `τ_j` reduces to second `s`-differences of the scalar map
  `s↦H(m(θ,s))` with one scalar `Var(η)` calibrated once and reused across the family.
- **§4 Scheme.** Skeleton (no draws) `Σ_j w_j H(m(θ,s_j))` (Gauss quadrature in `s`; gradient via AD of
  `H`). Correction (all draws): (a) stratified w/ Neyman allocation if the sampler can condition on `s`; (b)
  post-stratified `Σ_j w_j mean_j[H(X)]` if `s` recoverable (separation → exponentially small
  misassignment); (c) control-variate w/ plug-in classification otherwise. MC variance = **within**-variance
  only. Amortize: fit `c(θ)=g−ĝ₀−correction` (small, smooth) by GP on the manifold. Distribution: mixture of
  shifted within-stratum residual laws. Speedup ≈ `(σ²_tot/σ²_within)×(n_θ/κ_d)`. Loses only if
  within-variance dominates **and** `c` rough in `θ`.
- **§5 Missing / bends.** The global mean should appear **nowhere** in the estimator — and `H(m)` may be
  **ill-posed** (mixtures of valid states need not be valid states; `H` in the gap can "return silent
  garbage or fail to converge"). Ask *why* the mean is unrepresentative: often the components are **group
  translates of a template (phase/shift/permutation)** and `m` is an orbit-average, structurally washed out;
  then the `s`-decomposition is a **deconvolution**, and the analysis should live in **quotient (registered)
  coordinates** where the law may become unimodal and mean-based surrogates revive — "the most likely hidden
  change of variables," with index jitter its infinitesimal version. Verify: mixture-of-laws vs
  *superposition* (confirm on draws); `w(s)`/mode-count θ-independence (watch mode collisions); `H` smooth at
  the within-scale (if threshold/tail, delta corrections die but measure-level machinery survives).
- **§6 Experiment.** "Coupled residual" at two manifold-separated `θ` (~200 + ~100 draws), full `μ_θ`, real
  `H`: classify to nearest component mean (record margins), pair `H(X)` with `H(m_j(θ))`, form `R`. Stakes:
  **P1** `Var(R)/Var(H(X))≤0.2` (kill >0.5 → within dominates); **P2** margins ≥5σ, misassign <1% (kill →
  "well separated" false, framing revisited); **P3** curvature explains within-bias; **P4** residual
  transfers across `θ`; **P5** gradients; **P6** distribution KS. Full fidelity non-negotiable — a
  Gaussianized/single-mode proxy forces the variance ratio to 0 or 1 and validates the very shortcut the
  real mixture kills.
- **Ranking:** mixture+cheap means ≫ well-separatedness > θ-manifold > draws (few, irreducible) >
  componentwise `∂m/∂θ` > `H(m)` (diagnostic only). **Net: don't correct `H(m)` — replace it.**

## Response B — map-space framing (to v7), recorded

**Two framing settlements first.** (1) **The estimand is ambiguous:** there are two maps — `F_R` (computed
under discretization rule `R`) and `F_*` (intended — the continuum limit if `R` is numerical, *or* an
average over admissible discretizations if the elements are a latent physical/representational DOF). The
gradient is exact *about `F_R`* (internal consistency, not fidelity to `F_*`). Because `H` is nonlinear,
`H(smooth u)` differs from the placement-average by a **Jensen gap whose sign depends on local curvature** —
"exactly the mechanism by which simplified proxies reverse conclusions." Until you declare whether `R` is
refinable numerics or an irreducible latent variable, "accuracy" and "θ-sensitivity" are undefined. (2)
**The manifold is a gauge:** compensation means some tangent directions are *null directions* of `F`; measure
sensitivity only in intrinsic coordinates (`J_i=(∂F/∂θ)T`). Part of the "diffuse" character may be an
artifact of probing gauge directions; the conditions where compensation *fails* are the informative ones.

- **§1 Where the θ-info lives.** Whiten and stack tangent Jacobians `J=[Σ_i^{-1/2}J_i]`; SVD `J=UΣVᵀ`. Right
  singular vectors above the floor = identifiable θ-combinations, rest flat. Left singular vectors un-stacked
  by condition = **matched filters** `f_k(c_i)` — the across-`c` pattern carrying direction `k`; diffuse →
  each is a broad smooth *contrast between regimes*. Concentrated-vs-thin is an empirical readout:
  per-condition leverages `h_i` and the greedy cumulative `log det M(S)` (submodular → greedy near-optimal);
  a knee → designed sub-sweep suffices, near-linear growth → info genuinely thin, large `N` is doing
  *statistical averaging* (cost model changes). `V,Σ` are shared globally → a **sketch at `O(p′)` conditions**
  finds the geometry without all `N` Jacobians.
- **§2 Cheapest computation.** (a) **Linearize in θ first** (weak sensitivity ⇒ small curvature; test
  `κ=‖F−F−JTδ‖/‖JTδ‖≲0.15`; then the whole sweep is the tangent map at `θ₀`). (b) Reduce `c` (functional PCA
  / active subspace), interpolate rather than enumerate (accuracy only at the known points). (c) **Check if
  the adjoint gives `∂F/∂c` for free** (contract adjoint state against `∂residual/∂c`) → gradient-enhanced
  surrogate, dividing sample complexity. (d) Turn the biased `H(smooth u)` into a **control variate**
  (cheap-biased on all `N`, accurate on a subsample; bias removed by pairing, only correlation matters).
  (e) **Stop at the floor `σ_R`** (MLMC/multifidelity if a refinement ladder exists). Frontier: steep
  surrogate leg then a plateau at `σ_R` only refinement/reseeding can lower.
- **§3 Right variables.** θ → intrinsic coords + eigen-rotate by `M` (identifiable combos; logs if the gauge
  is multiplicative). Output → solve `S_sig w=λ S_nui w` for projections that are θ-informative **and**
  discretization-robust; prefer integrals/moments/feature-locations over granular structure; compute
  contrasts under a *shared* discretization. `c` → active coordinates, align/warp the driving series if
  phase matters.
- **§4 Discretization dependence.** Split the perturbation into refinement-convergent (numerics →
  Richardson) and reseed-persistent (latent → average, residual irreducible). θ-error
  `Δθ=(JᵀJ)^{-1}Jᵀε`: idiosyncratic part **washes out** over the sweep; the **systematic across-`c` part
  does not** and biases θ by its projection onto the matched filters — report `Δθ_alias`. Remedies: **pair
  everything** (fix `R` across θ-contrasts — CRN — which the reverse-mode gradient already does, so it may be
  *more* trustworthy than FD across independently-discretized runs); refine+extrapolate; if the persistent
  part aligns with the filters, **θ may be confounded with the discretization law** (not identifiable
  without pinning the law independently — a modeling decision). Traps: θ-dependent placement → adjoint
  mesh-motion artifacts; element-count quantization → `F_R` is a **staircase** (AD differentiates the smooth
  branch and misses the jumps; FD garbage; both "agree" misleadingly) — saved only by **dithering**
  (quantization phases decorrelate across the `c`-set, so *aggregates* stay smooth).
- **§5 Missing.** Free `∂F/∂c`; effective θ-dim possibly `<p′` (factor through a sufficient statistic
  `φ(θ)`, quotient again); dithering; the discretization law as a confounded quasi-parameter; global low-rank
  `J_i≈U(c_i)SVᵀ` (licenses sketching); tell — elements on the profile's own axis ⇒ `R` is quadrature
  (convergent); elements in an embedding space the profile doesn't parameterize ⇒ latent-variable reading.
- **§6 Experiment** (~55–70 full-pipeline evals, no proxies): reduce `c`; 14 medoids + 4 extremes; `F,∂F/∂θ`
  at `θ₀` (18); repeat at 6 under refined `R₂` and reseeded `R₁′` (12); `θ₀±δ` at 4 along two tangents incl.
  the compensated one, paired (16); a 7-pt 1-D θ-scan for staircase (7); one matched `c`-pair at equal `z`
  (2). **P1** spectrum sloppy (≤2 combos above floor); **P2** paired θ-contrasts stable across `R` while
  unpaired are floor-dominated (else discretization is θ-entangled — stop, model `R`); **P3** `κ≤0.15`;
  **P4** greedy info-curve has a knee (~20% of conditions carry ≥80%).
- **Ranking:** the discretization×nonlinear-`H` (defines estimand+floor) ≫ diffuse across-`c` signal
  (matched filters, pairing) > cheap exact gradient (tangent map, sketching; exact about `F_R` only) >
  smoothness+known `c`-set > manifold gauge > small `p`. Incidental: nominal dims of `c,y`; reverse-mode per
  se — *except* the open question of free `∂F/∂c`.

## Triangulation and audit — the point of running two framings

### The divergence is an artifact of our split, not a real fork
v6 supplied the latent mixture (patch-age `s`) and no swept conditions; v7 supplied the swept conditions `c`
and no mixture. So `#1` says the leverage is the *component* structure and `#2` says it is the *across-`c`*
structure — because that is what each was handed. **The real object is a mixture over latent patch-age `s`
at each swept condition `c`.** The synthesis neither could reach: the θ-signal lives in **how the
between-component structure varies across the swept conditions** — `#1`'s between/within split computed at
each `c`, then `#2`'s matched-filter/leverage geometry applied across `c`.

### Strong convergences (trust these — two independent framings, and some triple with our data)
1. **Never anchor on the global mean.** `#1`: it's a phantom point, possibly off-domain ("silent garbage").
   `#2`: it's a gauge direction, largely null; global `∂m/∂θ` incidental. Both: *replace*, don't correct.
2. **The operator bias has no fixed sign and is curvature-driven.** `#1` (segment-curvature integral),
   `#2` (Jensen gap, sign = local curvature) — and this triples with our adversarially-killed
   "no-fixed-sign" claim and the DART homogenization result.
3. **Exploit a linearity + few expensive evals + control variate + manifold amortization.** `#1` (linear in
   the law; control-variate residual; GP on the manifold). `#2` (linear in θ; biased-eval control variate;
   surrogate on the manifold). Same shape, different variable.
4. **Hunt for a hidden symmetry to quotient.** `#1`: components as group translates (phase/shift/orbit) →
   registered coordinates where the law may become unimodal. `#2`: the manifold gauge, and effective θ-dim
   `< p′` → quotient to a sufficient statistic `φ(θ)`. **This is the deepest shared insight and it is not in
   our literature corpus or the earlier point-process response** — the leading candidate for a real advance.
5. **The discriminating experiment must be full-fidelity, no proxy.** Both insist, independently — `#1`
   notes a proxy "validates exactly the shortcut the real mixture kills." Direct convergence with our
   updated guide §7 (faithful, not cheap).

### Textbook vs breakthrough (against the literature companion)
- `#1`'s scheme is, at core, the **ED first-moment + ANOVA/stratification + Rao–Blackwell + control
  variate** — largely textbook, cleanly executed; the sharpening ("replace, don't correct"; the quotient) is
  the value. Notably it reaches the **same within/between + control-variate scheme via law-space linearity,
  with no point-process apparatus** — so that scheme is now triply-derived (point-process response,
  law-space response, ANOVA), and the earlier round's factorial-moment/Palm machinery is confirmed as
  *framing-induced decoration*, not the substance.
- `#2` is **sloppy-models + active-subspace + optimal experimental design + MLMC + CRN** — largely textbook
  UQ, sharply assembled; the genuinely non-obvious bits are the **estimand ambiguity (`F_R` vs `F_*`)**, the
  **discretization-law-as-confounded-quasi-parameter** (θ non-identifiable if entangled with the
  representation choice), and the **staircase/dithering** footgun (AD and FD "agree misleadingly").
- Neither is the "transfer from an unexpected field" the point-process response first appeared to be — and
  the reason is instructive: that appearance was itself framing-induced.

### Contamination audit
- `#1` leans on **well-separated components** — which we asserted, but which our own TF24 run shows is only
  *age-dependent* (a spike at young ages, bimodal only at maturity). `#1` correctly made separation a
  **falsifiable prediction (P2)** rather than assuming it — good discipline — but its post-stratification
  degrades where separation fails (young stands, overlapping cohorts).
- `#2` leans on the **diffuse/sloppy signal**, which we asserted from "individually we can't determine
  much." `#2` correctly made it **P1** (test the spectrum) rather than assuming, and independently surfaced
  the **estimand ambiguity we left in the framing** ("H needs a discretization u doesn't fix" — we never said
  whether numerical or latent). Both responses turning our planted premises into tests, not assumptions, is
  the healthiest possible sign.

### The decisive first measurement (faithful, §7) — and it is the same in both
Both converge on measuring one fork before building anything: **is the θ-signal concentrated and structured
(between-component / across-condition — cheap wins) or thin and idiosyncratic (within-component — draws
required)?** `#1`'s P1 (`Var(R)/Var(H)≤0.2`) and `#2`'s P4 (info-curve knee) are the same question in the two
variables. Run it on the **full system** (full `μ_θ`, real `H`, real `F`) — which simultaneously tests our
two asserted premises (separation, sloppiness). This is the faithful discriminating experiment to run first.

### Net
Framing-independent and safe to build on: **replace the mean, don't correct it; exploit the between/across
structure with control variates + manifold amortization; and hunt for the quotient/symmetry that may
collapse the difficulty.** The `s`-vs-`c` "disagreement" is our own doing and points to the next elicitation
if we run one: a single framing carrying **both** axes — a mixture over a latent index *within* a sweep over
known conditions — so an Oracle can address the combined object we actually have.
