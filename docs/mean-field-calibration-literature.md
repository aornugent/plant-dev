# Calibration problem — applied-domain research companion

**Purpose.** Applied-domain (forest demography + remote sensing + inference) literature digest for the
problem posed, register-neutrally, in [`oracle-consultation-mean-field-calibration.md`](./oracle-consultation-mean-field-calibration.md).
**This document is deliberately domain-full and is NOT the Oracle missive** — it exists so that, when the
Oracle responds, we can tell a textbook answer from a genuine breakthrough, and so we do not spend effort
testing a mechanism the field already knows to fail (guide §7).

**Provenance & confidence.** Deep-research fan-out: 23 primary sources, 112 extracted claims, top 25 sent to
3-vote adversarial verification. The run was **cut short by a session limit** (resets 07:30 UTC) and the
synthesis step did not run, so claims are tiered:

- **[A] Confirmed** — survived 3-vote adversarial verification (3-0; one 2-0). 14 claims.
- **[C] Refuted** — killed by verification (0-3). 3 claims. *Recorded deliberately: "plausible but wrong" is
  exactly what we must not carry into the consult or its follow-up.*
- **[U] Unverified** — extracted from primary sources with direct quotes, but the verifier errored before
  voting (session limit). Credible leads, not checked.
- **[L] Lead** — surfaced by a fetch agent, not put through verification; headline only.

Resumable from cache after the reset (only the ~26 failed verify votes + synthesis re-run; everything else
replays free): `Workflow({scriptPath: ".../deep-research-wf_427601ce-c90.js", resumeFromRunId: "wf_427601ce-c90"})`.

---

## The single most useful finding

**Our consult's central object is how this model class is *defined*, not an analogy we imposed.** The
Ecosystem Demography lineage that `plant` follows *derives* its deterministic size-and-age-structured PDE as
the **first moment (ensemble mean) of a stochastic individual gap model**, valid as the number of
realizations → ∞, by **Taylor-expanding the nonlinear per-capita growth/mortality about the age-conditional
mean resource and dropping second- and higher-order terms** — i.e. it *is* the closure `E[g(r)] ≈ g(E[r])`.
[A] And `plant` itself ships **both** computations our black-box formulation assumes: a stochastic
finite-patch sampler and a deterministic mean-field mode. [U] So "cheap conditional mean vs expensive full
sampler," and the `H(E[x])` vs `E[H(x)]` bias, are the model's own construction — not our invention.

## Thread 1 — Is the mean sufficient, or is θ only identifiable via realization structure? (Q1)

The strongest corroboration of the missive. The literature has a sharp, quantitative answer:

- The first spatial moment is **not closed** — its dynamics carry flux terms in the second moment (pair
  density); mean-field = imposing `C(ξ) = N²`. The mean suffices **only when the pair density factorizes**.
  [A] (Bolker & Pacala 1999; Murrell/Dieckmann/Law 2004)
- **Identifiability can strictly require the second moment.** Clean worked case: a deterministic (mean-only)
  model identifies **1 of 4** parameters; mean+variance → **2**; mean+variance+autocorrelation → **4/4**.
  There are explicit parameter directions that leave the mean exactly unchanged but move the variance —
  non-identifiable from the mean, identifiable once fluctuations are modeled. [A] (arXiv:1104.1274)
- Mean-field / mesoscopic inference produces **large estimation errors in the low-count / small-system
  regime** — the direct analogue of a **single finite realization** (our window ≈ one unit). One parameter
  non-identifiable macroscopically becomes identifiable mesoscopically; and because the true mean of a
  nonlinear process ≠ the deterministic solution, **stochasticity can be exploited even when only the mean
  is observed**. [A] (PMC4957800) — a direct `E[H] ≠ H[E]` instance.
- Mean-field is asymptotically exact **as the interaction range `L → ∞`**, error `O(L^{-(n+1)d})`. [A]
  (PMC1568924) — the opposite end: long-range coupling ⇒ the mean is fine.

**Refuted — do not carry:**
- "Mean-field must be replaced by ≥2nd-order closure to correctly capture dynamics" — **killed (0-3)** as
  overgeneral; the defensible statement is the narrow one above. [C]
- "Mean-field valid specifically when competition/dispersal neighbourhoods are large / movement high" —
  **killed (0-3)** as phrased; note the *concept* survives via the `L→∞` result from a different source. [C]
- "Mean-field **systematically overestimates** density (fixed-sign bias)" — **killed (0-3)**. **Do not
  assume the `H(E) − E(H)` bias has a fixed sign.** [C]

→ *Scoring the Oracle:* if it "discovers" that some θ-directions need second-order/realization structure,
that is **textbook** (hold it to the 1/2/4-parameter precedent). What is open is *which* directions, for
*our* structure.

## Thread 2 — Space-for-ensemble / self-averaging (Q2)

- **Patch age is the sufficient statistic** that licenses replacing a spatial average over the disturbance
  mosaic with an expectation over patch ages: time-since-disturbance accounts for most across-gap variation,
  and the state is the density *conditional on patch age* (von Foerster age equation). [A] (Moorcroft ED)
- Landscape quantities = single-patch trajectories **averaged over the patch-age distribution `P(a)`** under
  an island model (∞ patches, shared seed rain + disturbance). [U] (`plant` methods paper) — this is our
  `M = ∫ m·w(τ) dτ`.
- The **averaging scale** (effective decorrelation length) is set by the **disturbance event-size
  distribution, return frequency, and recovery/succession kinetics**. [U] (shifting-mosaic steady state)
- Documented **failure mode:** a naive single-plot mean-field that **omits the disturbance-age dimension**
  under-predicts biomass; retaining size-AND-age structure recovers the mean. [U] (ED, San Carlos)

→ *Scoring:* patch-age-as-sufficient-statistic is **textbook**. What quantitatively sets the decorrelation
length — and whether it is **estimable from the data themselves** (our Q2) — is stated only qualitatively:
genuinely open.

## Thread 3 — Simulation-based inference (under-covered; verification truncated)

- **Synthetic likelihood** (Wood 2010, Nature): reduce noisy/near-chaotic dynamics to phase-insensitive
  summary statistics, then simulate to build a likelihood. [L] Canonical for the "compare summaries, not raw
  realizations" move (our Q5).
- ABC / neural posterior estimation / pattern-oriented modelling were surfaced but not verified this run.
  [L]

→ Thin here **because verification was cut off**, not because the field is absent. Flag for the resume.

## Thread 4 — Observation operator (structure → lidar) and the `H(E)` vs `E(H)` bias — the likely frontier

- Ma et al. 2023 (the paper shared): couples GEDI + ICESat-2 canopy-height retrievals to mechanistic
  demographic modeling for AGB stocks/fluxes. [L] (research.fs.usda.gov/treesearch/66090)
- `plant` is **spatially implicit within patches** (vertical structure only; no horizontal point process),
  so to drive a nonlinear lidar / radiative-transfer operator the **horizontal arrangement must be invented
  externally** — the model supplies a height/size distribution per unit ground area, not a 3-D scene. [U]
  (`plant` methods paper) — **this is exactly our "representation gap," and it is a real property of the
  model, not a framing choice.**

→ *Scoring:* the `H(E[x])` vs `E[H(x)]` bias for structure→lidar, and how to choose or marginalize the
invented placement, is the **least-addressed thread in the corpus.** That silence is itself signal: **a
crisp Oracle result on Q3 (representation gap + operator nonlinearity) is the most likely place for a
genuinely novel contribution**; a "self-averaging / patch-age / use-2nd-moments" answer is the field's
standard toolkit.

## Thread 5 — Identifiability confound: demography vs disturbance (Q4)

- **Empirically demonstrated equifinality:** matching a mature-forest biomass snapshot does **not** identify
  demographic rates — across **nine** vegetation-demographic models, similar bulk biomass arises from
  **compensating** errors (growth over-, mortality/turnover under-estimated). [L] (nph.70643)
- Bayesian calibration of a size-structured (PPA-style) forest model with an **explicit equifinality
  demonstration** — the same equilibrium from different demographic combinations. [L] (PMC10318622)

→ *Scoring:* the growth/mortality (and demography/disturbance) confound is **textbook/empirical**. The
*cure* — what extra observable breaks it — is open, and connects to Thread 1 (do fluctuations/2nd moments
break it?) and Thread 4 (does the operator see what the marginal cannot?).

---

## Net read for the consult

1. **Framing validated.** Every load-bearing premise of the missive is a documented property of this model
   class: model = first moment via `g(E[r])`; both a cheap mean and an expensive sampler exist; landscape =
   patch-age average; spatially-implicit ⇒ representation gap; the demographic confound is real.
2. **Two questions already have textbook answers we can hold the Oracle to:** Q1 (the mean can be
   insufficient; second moments can restore identifiability — with a quantitative precedent) and Q4 (the
   confound is empirically real).
3. **The frontier is Q3** — the nonlinear observation operator and the representation gap. The corpus is
   nearly silent there. Concentrate scoring (and any second missive) on it.
4. **Do-not-carry:** the `H(E) − E(H)` bias has **no guaranteed sign**; "always use ≥2nd-order closure" is
   an overgeneralization. Both were adversarially killed.

**Next:** resume the workflow after 07:30 UTC to finish verification (the unverified Thread 2–5 claims) and
run synthesis; then, if useful, a second missive that varies the *descriptive emphasis* — foregrounding the
representation gap / operator (Q3) vs the sufficiency question (Q1) — never the method.

## Later-run harvest (partial re-run 2026-07-18; cache-miss, stopped mid-verify)

The resume missed cache and ran fresh, then was stopped. It **completed all 23 fetches across all five
threads** (~110 claims) but its **verify phase only reached Thread 1** (26 confirm / 1 refute) before being
stopped — independently reproducing the first run's Thread-1 confirmations (pipeline-stability signal). So
the Thread 2–5 additions below are **[U] extracted from primary sources with direct quotes, not
adversarially verified.** This is most of what a fresh run would have given us, minus verification of the
new leads.

**New refutation → do-not-carry.** "Long-range dispersal/interaction drives spatial systems to mean-field
behaviour": the *core* is textbook (well-mixed / `L→∞` limit) but the vote **refuted it for overreach** — the
same source documents mean-field **failing in transients, near extinction thresholds, and in cyclic
dynamics**. Treat "long-range ⇒ mean adequate" as a stationary / near-equilibrium statement only. [C]

**Thread 2 — self-averaging, now quantified (Q2).** Central Amazon old-growth: a **single hectare does NOT
recover the landscape ensemble mean; plots must exceed ~10 ha** to be a reliable estimator; shifting-mosaic
steady state emerges only at large scale. Plus an operator bias: **plot sampling omits 9–17% of tree
mortality** by under-sampling large gap events. [U] Also Levin & Paine (joint patch size×age frequency
distribution) and Kohyama SAL (patch-age × within-patch size; two-scale density dependence). [U]

**Thread 3 — SBI toolkit (methods for Q1/Q5).** Wood synthetic likelihood (phase-insensitive summaries →
simulate → Gaussian likelihood → MCMC). Neural SBI: ABC has a curse of dimensionality and **does not
amortize across observations**; neural density estimators do. Rejection-ABC on a real IBM **diagnosed
practical non-identifiability** (7 unconstrained params: 3 correlated, 4 insensitive) and did **structural
module selection**. Pattern-oriented modelling (Grimm): **multiple weak patterns jointly defeat
equifinality** ("right pattern for wrong reasons"). Summary-statistic choice is the critical bias–variance
design; **no SBI method dominates** across problems. [U]

**Thread 4 — observation operator, the frontier (Q3), now with an empirical anchor.** **DART 3-D radiative
transfer: replacing the true spatially heterogeneous foliage field with a homogenized (constant) FAVD
substantially biases the simulated spaceborne-lidar waveform**, whereas voxelizing to 1 m barely changes it
*provided the real heterogeneity is retained* — so the bias is in the **horizontal heterogeneity the mean
discards**, not in discretization. A measured `H(E[x]) ≠ E[H(x)]` for exactly our operator. The **GEDI
waveform simulator** is a validated forward operator (ALS→waveform, bias <0.22 m) whose fidelity is
**conditional on input point density**. Ma et al. (ED v3.0): operator = modeled vertical structure → canopy
height; fine-scale heterogeneity affects **fluxes, not just stocks**. [U]

**Thread 5 — identifiability confound (Q4).** Nine-VDM benchmark: a single aggregate target (biomass)
permits **compensating parameter errors** (explicit equifinality). Bayesian calibration of a size-structured
model: parameter-level equifinality, yet the **emergent qualitative outcome (competitive dominance) and its
controlling process were identifiable** even when the rates were not — *what is identifiable is the outcome,
not the rates.* FATES: identifiability **capped by structural error, not just parameter uncertainty.**
Size-abundance slope across 160k FIA plots: **the slope is a transient of disturbance-recovery position, not
a fixed demographic signature** — the demography/disturbance confound at continental scale (R²=0.20 even
with age+disturbance+height predictors). [U]

**`plant`, from a dedicated source — confirms the black-box framing.** The *same* size-and-patch-structured
model is solvable **either deterministically (mean-field, method of characteristics) or stochastically**;
`N(H|x,a)` obeys a McKendrick–von Foerster PDE; the patch-age distribution comes from the disturbance
regime; landscape = single-patch trajectory scaled by `P(a)` (explicit space-for-ensemble). [U] Independent
corroboration that the two computations the missive assumes are real and exact-by-construction.

**Updated net read.** Threads 3/4/5 are now populated (from primary sources, unverified). The **frontier Q3
has an empirical anchor**: the representation gap is real *and measurable* (DART). That cuts both ways for
scoring the Oracle — a purely textbook answer on Q3 would cite this class of "homogenization biases the
signal" result; a genuine breakthrough must go past *diagnosing* the bias to **cheaply correcting or
marginalizing it** (a low-order operator correction, a control variate on the mean, an emulator) without
paying for the full stochastic render at every θ.

## Sources (23 primary)

Mean-field ↔ stochastic / moment closure: journals.uchicago.edu/doi/10.1086/303199 (Bolker & Pacala 1999);
user.iiasa.ac.at/~dieckman/reprints/MurrellEtal2004.pdf; pmc.ncbi.nlm.nih.gov/articles/PMC1568924;
pmc.ncbi.nlm.nih.gov/articles/PMC4957800; arxiv.org/pdf/1104.1274;
researchgate.net/publication/221692207.
Space-for-ensemble / ED / mosaic: esajournals.onlinelibrary.wiley.com/doi/abs/10.1890/0012-9615(2001)071[0557:AMFSVD]2.0.CO;2
(Moorcroft ED); besjournals.onlinelibrary.wiley.com/doi/full/10.1111/2041-210X.12525 (`plant`);
pnas.org/doi/10.1073/pnas.71.7.2744 (Levin & Paine 1974); pnas.org/doi/10.1073/pnas.1202894110;
esj-journals.onlinelibrary.wiley.com/doi/10.1007/s11284-005-0046-9 (SAL).
SBI: nature.com/articles/nature09319 (Wood 2010); sciencedirect.com/science/article/pii/S0304380015002173;
sciencedirect.com/science/article/abs/pii/S1364815223002918.
Observation operators / remote sensing: research.fs.usda.gov/treesearch/66090 (Ma et al. 2023);
agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2018EA000506; spj.science.org/doi/10.34133/remotesensing.0737;
gmd.copernicus.org/articles/12/4133/2019; onlinelibrary.wiley.com/doi/10.1111/geb.70102.
Identifiability / equifinality / traits: nph.onlinelibrary.wiley.com/doi/10.1111/nph.70643;
pmc.ncbi.nlm.nih.gov/articles/PMC10318622; nature.com/articles/nature09319; science.org/doi/10.1126/science.1116681;
pnas.org/doi/10.1073/pnas.1912789117.
