# Oracle response — dimension-collapse (to `elicitation-quotients.md`)

*Response to the second (map-space) elicitation. Recorded verbatim (lightly reformatted), 2026-07-19.
Hypotheses to test, not verdicts (`guide.md` §7). This is the deepest response so far; it **subsumes and
deepens** the map-space response in `response-triangulation.md` (#2). Read the triangulation + audit at the
end — including one caveat that decides whether the whole scheme is affordable for us.*

## Response (verbatim)

**Three re-derivations up front, because the six questions inherit their answers from them.**

**(1) The decomposition lives in state space, in the pairing of two bundles you almost already own.** Per
condition, `J_i = G_i Z_i` with `Z_i = (∂S/∂θ)T ∈ ℝ^{n×p′}` (the *excited* subspace — what θ can say into the
state; `T` a tangent basis of the θ-manifold) and `G_i = H′(u_i) ∈ ℝ^{m×n}` (whose row space is the *heard*
subspace). The naive rank of `J_i` conflates the three collapses; the two factors separate them. And they are
asymmetrically priced: `u_i` is a free byproduct of every solve; `G_i` costs *no solve* (`H` known, `u_i` in
hand); the adjoint `λ = G_iᵀw` is computed inside every reverse pass; **only `Z_i` costs solves** (`p′`
linearized, or paired secants `S(θ₀±δt_k, c_i)`). This is the "structure not apparent from parameters or
output alone": visible only at the `u`-level, and nearly free there.

**(2) The decomposition is a filtration, not a sum of three independent numbers.** The composition fixes the
order `p′ → ρ_S(i)=rank_ε Z_i → ρ_F(i)=rank_ε J_i`. S-loss `= p′−ρ_S`; H-loss `= ρ_S−ρ_F` *measured only on
excited directions*. Directions S never excites and H would also kill are unobservable and correctly excluded
— asking for their attribution is ill-posed; the filtration handles it. Caveat: the S-vs-H split depends on
the state-space norm (declare it — solver energy norm or per-component standardization — and check robustness
under one alternative); the composite `ρ_F` does not.

**(3) The primary estimand is the sweep-level spectrum, and it is a spectrum, not an integer.** Stack
`𝕁 = [J_i]` over a sketch of conditions; its ε-rank `k_eff`, against a floor from solver-tolerance jitter
(re-solve one condition at tightened tolerance; the Jacobian movement sets ε), is "the effective number of
θ-directions across the swept c." Per-condition ranks are diagnostics. Sloppy spectra ⇒ the answer is `d(ε)`;
report the knee.

**§1 Effective dimension, decomposed.** `k_S = rank_ε[Z_1;…;Z_M]`, `k_eff = rank_ε[J_1;…;J_N]`. Since
`J_i v = 0` whenever `Z_i v = 0`, heard ⊆ spoken, and bookkeeping is exact: `p′−k_S` = silent in the state at
every condition (S-loss, incl. any gauge realized in S); **`k_S−k_eff` = spoken somewhere but heard nowhere**
(H-loss on the excited bundle — the flagship, invisible from `(θ,y)` pairs); `k_eff` = survives. Granular: per
right singular vector `v`, speak `s_v(i)=‖Z_i v‖`, hear `h_v(i)=‖J_i v‖`, transmission
`t_v(i)=‖G_i Z_i v‖ / (σ_max(G_i|_{range Z_i})‖Z_i v‖) ∈[0,1]`. `h_v` free from the Jacobians; `s_v,t_v` at
4–6 conditions (~5·p′ linearized solves).

**§2 Detecting the bottleneck Ψ without positing its form.** The snapshot cloud `{u_i}` is free; neighbouring
conditions give free secants ≈ c-tangents. Estimate intrinsic dim `r̂` (two-NN, CV local PCA) and linear
ε-rank `R̂` (POD). Three regimes: `r̂≈R̂` small → linear bottleneck, POD scores *are* Ψ; `r̂≪R̂` → curved
low-dim manifold, poor linear width (the transport/phase symptom) → nonlinear Ψ (diffusion maps / LTSA) or
quotient candidate transforms first (per-component shifts, phases, permutations — dictated by the assembly)
then re-test linear width; `r̂≈R̂≈n_eff` large → no bottleneck, reject the feature. Validation is functional:
a **closure test** (predict held-out state entries and `y` from Ψ̂ by NN regression; residual at floor ⇒ it
factors) and **matched-bottleneck pairs** (two `(θ,c)` with equal Ψ̂ must give equal `y`; one pair = 2 solves,
the sharpest single check). If S factors, `h=H∘ι` is `m×r` — operator collapse becomes small and explicit,
surrogates/updates move to Ψ-space, conditioning improves (the better-posed variables).

**§3 Symmetries without assuming the group.** (a) θ-side, no group ansatz: the right-null space of stacked
`𝕁` is a candidate invariant distribution; test integrability by continuation (predictor along the null,
Gauss–Newton corrector holding `F` fixed at 2–3 conditions; `F` constant along finite arcs + a
two-direction bracket test ⇒ a genuine global quotient, not local rank deficiency). (b) Continuous state-side
invariance of `H`: linear-in-generator search — minimize `Σ_i‖G_i A u_i‖²` over a structured generator class
(block/phase/index actions), a zero-solve least-squares null-space, verified at finite `t` by `H(e^{tA}u_i)`;
and test whether S is equivariant by comparing `Z_i v_gauge` against `A u_i` (does θ-compensation push the
state along the orbit H kills? — localizes the gauge by stage). (c) Discrete symmetries are Jacobian-blind:
permutation of like components is the prime suspect — apply to stored states, evaluate `H`, zero solves;
discrete fibers create θ-multimodality, not dimension reduction.

**§4 Collapse from the coupling.** (i) **Slaving:** a few random-seed linearized solves (Arnoldi); a spectral
gap ⇒ a slow manifold counting collective coordinates. (ii) **Separability (free):** reshape each column of
`Z_i` into (component × internal-dof); rapid singular decay ⇒ θ-response ≈ shared internal pattern ⊗
loading-over-components, the loading being the collective coordinate. (iii) **Aggregate listening (free):** FD
`H` on stored states, one component vs the symmetric aggregate; if `y` responds only to aggregates,
collectivity is `H`'s null structure, not the dynamics. (i)/(ii) reduce Ψ; (iii) reduces `h` — same `k_eff`,
different right variables.

**§5 What is shared across c.** θ-side: eigen-spectrum of the average projector `P̄=(1/N)Σ V_iV_iᵀ` over
per-condition active subspaces — eigenvalues near 1 = shared core, interior = itinerant fringe; scalar tell
`max_i ρ_F(i)` vs `k_eff` (equal ⇒ one condition sees everything; gap ⇒ the sweep is what makes θ visible).
State-side: ambient principal angles across conditions (all `range Z_i` in the same `ℝ^n`, no transport).
Diagnose the mode: smoothly rotating subspaces (→ Grassmann interpolation) vs regime-switching (→ cluster
conditions, spend design points at boundaries — the one place to override the few-evaluations preference).

**§6 What you may be missing — the impersonation question.** Project θ-tangents `Z_i` onto the tangent space
of the c-swept state manifold (from neighbour snapshots, free); tangential fraction
`τ_i = ‖Π_i Z_i‖²_F/‖Z_i‖²_F`. **`τ≈1` ⇒ θ moves the state *along* the manifold the sweep already traces — θ
acts as a condition-shift, confounded with c-uncertainty; `τ≈0` ⇒ θ opens fresh directions, identifiability
is structurally easy.** Also: the metric-dependence of source attribution; the discrete-fiber blindness of
all Jacobian machinery; effective dimension as `d(ε)` not an integer; and the framing correction that the
three collapses compose *additively* — they don't, it's a filtration, and demanding independent numbers for
overlapping losses is the assumption the structure quietly contradicts. Finally, if `k_eff = p′`, the
collapse lens is wrong for this map and the effort belongs in conditioning and scaling.

**§7 Discriminating experiment (~55–75 solve-equivalents, full `H∘S`).** 12 medoids + 4 extremes in c (free).
**A** (composite & sharing): `F,∂F/∂θ` at θ₀ across all 16 + one tolerance-tightened re-solve for the ε-floor
(17–18 solves). **B** (attribution): `Z_i` at 5 spread conditions (~20 solves) → filtration, `t_v`, gauge
localization (`‖Z_i v_gauge‖` vs `‖G_i Z_i v_gauge‖`), separability reshape, generator search, discrete tests
(0 solves). **C** (bottleneck): 8 θ-perturbed solves → `r̂` vs `R̂`, closure test, one matched-bottleneck pair
(2). **D** (globalization): continuation along a stacked-null direction, 3 predictor–corrector steps at 2
conditions (~10). Predictions: **P1** `max_i ρ_F(i) < k_eff < p′` (both strict) — genuine collapse, no single
condition sees all; **P2 (flagship)** a *spoken-never-heard* direction exists (`s_v` bounded away from 0 on
≥half the sketch, `h_v≈0` everywhere) — the composite collapse invisible from θ or y; **P3** shared losses
die at H, c-dependent losses die at S, and the gauge is realized in S (`‖Z_i v_gauge‖/‖Z_i‖<0.05`); **P4**
`r̂ ≤ (eff c-dim + p′)` and `r̂ < R̂/3` (curved bottleneck, poor linear width; quotienting the assembly's
transforms at least halves `R̂`); **P5** partial impersonation `τ∈[0.3,0.7]`; **P6 (zero solves)** if like
components exist, `H` is exactly permutation-invariant on stored states ⇒ discrete θ-fibers.

**Feature ranking.** Load-bearing: (1) **access to internals** — the free state, the free adjoint inside
every reverse pass, solve-free `H′` actions (without these attribution is unaffordable; with them nearly
free); (2) the known large c-set (snapshot scaffolding, free c-secants, stacked-vs-per-condition contrast);
(3) the θ-manifold constraint (quotient first or it contaminates every rank count; seed for symmetry
detection); (4) smoothness (stable subspaces, principal angles, continuation); (5) solve expense (shapes
design, no structural conclusion). Incidental: the nominal dimension of `u`; the many-to-one-ness of `H` *per
se* (only `ker H′` on the excited bundle + the discrete part matter, differently); the low-rank-`∂F/∂θ`
suspicion (the composition, i.e. the filtration, was always the real question); the AD flavor — except that
reverse mode's free adjoint is a genuine perk to exploit.

---

## Triangulation and audit

**This subsumes and deepens the map-space response (#2).** #2 whitened the Jacobians and did an SVD to get
matched filters and a sloppy spectrum at the θ/output level. This response goes to the **state level**:
`J_i = G_i Z_i` factors the *same* Jacobian into the **excited** (`Z`, θ→state) and **heard** (`G=H′(u)`,
state→output) bundles, which separates the three collapses that #2's single SVD conflated. Same register, so
the **convergences are strong signal**: a sloppy *spectrum* reported at its knee (not an integer); quotient
the θ-manifold first (right-null space); shared-vs-c-dependent by the average projector / principal angles;
one faithful full-`H∘S` experiment with falsifiable predictions. Where they diverge, this one is simply
deeper.

**Genuinely new (not in #2, our foundation, or the literature corpus):**
1. **The `J = G·Z` state-space factorization, nearly free.** The attribution we feared was expensive is
   almost costless because it lives at the `u`-level: the state is a free byproduct, the adjoint is computed
   inside every reverse pass, and `G = H′(u)` needs no solve. Only `Z` (the S-Jacobian) costs solves.
2. **The "spoken-never-heard" class (`k_S − k_eff`)** — directions θ excites in the state but the observation
   operator cannot hear. This *is* thread 1 (the operator's null-space collapse), now an isolated, measurable
   quantity invisible from `(θ,y)` pairs. Flagship prediction P2.
3. **The impersonation diagnostic `τ`** — whether θ moves the state *along* the c-swept manifold (θ ≈ a
   condition-shift, **confounded with c** → calibration ill-posed) or opens fresh directions (easy). This is
   a decisive, *free* well-posedness check we did not have; arguably the single most consequential idea.
4. **"Filtration, not a sum"** — a direct correction to *our own framing*: we asked for "decomposition by
   source" as if the three collapses added independently. They don't; demanding independent numbers for
   overlapping losses is ill-posed. (Plus the equivariance test that localizes the gauge by stage.)

**Contamination audit — clean, and self-correcting.** The response did *not* inherit our premises blindly:
it corrected the additive-decomposition assumption (→ filtration); turned "S's image may be low-dimensional"
into a *detection method with an explicit reject branch* (P4, `r̂≈R̂` large ⇒ no bottleneck); and demoted our
"H is many-to-one" to *per se incidental* (only `ker H′` on the excited bundle + the discrete fibers matter).
That is exactly the healthy pattern — premises turned into tests.

**The one caveat that decides affordability for us — CHECK BEFORE BUILDING.** The entire "nearly free"
economics rests on **`G = H′(u)` being solve-free** — true only if the observation operator is *cheap and
differentiable independent of the expensive S-solve*. For our operator that is the open question: a lidar
**radiative-transfer** operator (DART/LESS) is itself an expensive black-box simulator whose Jacobian is
**not** free, and even finite-differencing `H` on a stored state (which §4-iii and the discrete tests rely
on) costs many `H`-evaluations. So the first faithful check is not P1–P6 but: **how cheap, and how
differentiable, is the actual observation operator?** If `H` is a cheap analytic/summary map (e.g. a
canopy-height-distribution functional), the whole scheme is nearly free as advertised; if `H` is a full
scene render, `G` is expensive and the cost model must change (emulate `H`, or restrict to a cheap
`H`-surrogate for the attribution). This is the binding assumption our elicitation smuggled in ("H is known"
+ "probes cost a solve" were in tension), and the Oracle resolved it in favor of a cheap `H`.

**Textbook vs breakthrough.** The individual tools are standard model-reduction / active-subspace /
manifold-learning / continuation (POD, two-NN intrinsic dimension, principal angles, Arnoldi slow manifolds,
Gauss–Newton continuation). The *synthesis* — the `G·Z` factorization exploiting our specific free-state /
free-adjoint / solve-free-`H′` asymmetry, the spoken-never-heard class, and the impersonation test — is the
non-obvious, high-value part, and it is exactly the "present in the general numerical representation, not the
domain lens" outcome we were after.

## Next action

Run the A/B/C/D experiment on plant with a real (or cheap-surrogate) `H` — **preceded by the `H′`-cost
check** above, which decides whether the free-attribution economics apply. The flagship decisions are P2
(is there a spoken-never-heard direction — the operator collapse) and P5 (impersonation — is calibration
even well-posed against c). Everything is a faithful full-`H∘S` test; nothing is a proxy. Map the abstract
objects: `S` = the plant SCM (state `u` = the size-density / cohorts); `θ` = traits on the manifold; `c` =
rainfall/environment; `H` = the lidar operator; `Ψ` = the candidate emergent coordinate (self-thinning /
mosaic order parameter); the θ-manifold gauge = the trait trade-offs.
