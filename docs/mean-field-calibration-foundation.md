# Calibrating plant from lidar — the foundation we build from

*Consolidation of the whole investigation (literature sweep + two Oracle framings + a grounding TF24 run)
around one representation. Domain-full and internal — not an Oracle missive. Companions:
[`oracle-consultation-guide.md`](./oracle-consultation-guide.md) (practice, updated this round),
[`oracle-consultation-mean-field-calibration.md`](./oracle-consultation-mean-field-calibration.md) (the
domain-clean elicitation, v7), [`-response.md`](./oracle-consultation-mean-field-calibration-response.md) and
[`-triangulation.md`](./oracle-consultation-mean-field-calibration-triangulation.md) (the responses),
[`mean-field-calibration-literature.md`](./mean-field-calibration-literature.md) (the research digest).*

## The representation

**Goal.** Calibrate plant's trait parameters against raw lidar sampled across a landscape — turning cheap,
abundant, static structural observations into constraints on a mechanistic, dynamical, size-structured
model, so we read *process* off *pattern*. Individual observations determine little; the constraint emerges
across the ensemble, the way a standard model is measured across many collisions of varied, known
characteristics (the accelerator picture).

**The object, mapped abstract ↔ plant:**

| abstract | plant / lidar |
|---|---|
| universal parameters `θ` on a low-dim manifold | trait trade-offs (lma, wood density, hmat, hydraulics…) on the economics/allometric manifold — shared across the landscape |
| known, swept conditions `c` | rainfall scenarios + site/environment — known per observation, varied across the landscape |
| latent index `s` at each `c` | patch age (time since disturbance) — the disturbance mosaic, unobserved per stand |
| cheap deterministic mean `m(θ,s,c)` | the SCM size-density at a given patch age (deterministic) |
| expensive realization | an individual-based stochastic stand |
| nonlinear operator `H` | the lidar / radiative-transfer observation operator (DART/LESS/GEDI) |
| the representation gap (discretization `H` needs, the mean doesn't fix) | turning a size-density into an explicit 3-D scene: allometry + crown geometry + a horizontal placement plant does not carry |

**The one-line structure (the synthesis the two split framings implied but neither reached):** a *mixture
over latent patch-age at each swept condition*; the trait signal lives in **how the between-patch-age
structure varies across the swept conditions**, not in any single stand.

## What is settled (convergent across both Oracle framings; some triple with data)

1. **Never anchor on the global mean — replace it, don't correct it.** The metapopulation mean is a phantom
   point no stand resembles (our TF24 run: bimodal canopy+understory at maturity), a gauge/null direction,
   and possibly *off-domain* (a mixture of valid states need not be a valid state — `H` there can return
   garbage). Use the age-resolved single-patch densities plant already produces, not their average.
2. **The observation-operator bias has no fixed sign and is curvature-driven.** `H(mean) ≠ mean over
   realizations`; the gap's sign is set by `H`'s local curvature (occlusion, for lidar). Corroborated three
   ways: both Oracle responses, our adversarially-killed "no-fixed-sign" claim, and the DART
   homogenized-field result.
3. **Exploit the linearity + control variate + manifold amortization.** Expectation is linear in the law
   (mixture decomposition exact) and the response is near-linear in `θ` on the manifold (tangent map). The
   cheap biased evaluation (`H` on the mean/coarse field) is a *control variate*: correct it with a few
   expensive full realizations; fit the small smooth residual across the trait manifold so a few draws serve
   the whole family. MC/expensive cost then pays only the *within*-component variance, not the total.
4. **The trait signal is diffuse per-condition and structured across conditions.** No single stand pins `θ`;
   the information is the across-`c` pattern (matched filters / between-component contrasts). This is the
   accelerator, and it is why the model earns its keep only when swept.
5. **Pair everything (common random numbers / shared discretization).** plant's reverse-mode AD gradient
   already fixes the discretization across θ-contrasts, so it is likely *more* trustworthy for the
   trait-sensitivity structure than finite differences across independently built scenes.
6. **The discriminating test must be full-fidelity, never a simplified proxy** (guide §7, updated this
   round). Both Oracles insist; a Gaussianized/single-mode/decoupled proxy validates exactly the shortcut
   the real system kills — the TF24 multirate reversal, again.

## The candidate breakthrough — to check, not assume

Both framings independently reached the same deep move: **a hidden symmetry to quotient.** If patch-age
components are near-translates or rescalings of a template (self-similar growth), or if the trait manifold
is a gauge with effective dimension below `p`, then in *registered / quotient coordinates* the law may
become unimodal and low-dimensional, and the difficulty partly dissolves — even mean-based surrogates could
revive. **This is the highest-value lead and it is decidable from our own model:** regress the size-density
shape at different patch ages against a template (do they superpose after a shift/scale?), and check whether
`rank(∂F/∂θ)` across conditions is below `p`. It is an empirical check, not another consult.

## Load-bearing hazards (mostly from the map-space framing)

- **Estimand ambiguity.** Is the representation gap (the scene `H` needs) *refinable numerics* (a
  discretization → converges under refinement) or an *irreducible latent variable* (a real placement the
  data reflect)? The two demand different treatments; decide it empirically (refine vs reseed the scene at
  fixed resolution and see which part shrinks).
- **Trait–representation confound.** If the systematic part of the scene-construction error aligns with the
  trait matched-filters, `θ` is confounded with the scene/closure choice and is *not identifiable* without
  pinning that choice independently. Watch for it.
- **Staircase/dithering.** If the number of individuals quantizes with `θ`, the map is a staircase: AD
  differentiates the smooth branch and misses the jumps, FD is garbage — both can "agree" misleadingly.
  Aggregates across many conditions dither the quantization smooth; test per-condition continuity and
  aggregate gradient-consistency separately.

## The decisive first experiment (faithful; run before building)

Both framings converge on measuring one fork, on the **full** system (real plant realizations, real `H`,
real scenes): **is the trait signal concentrated and structured (between-patch-age / across-condition →
cheap methods win) or thin and idiosyncratic (within-patch-age → many expensive draws required)?**
Operationally: classify realizations to patch-age components, pair `H(realization)` with `H(age-density)`,
form residuals, and read `Var(residual)/Var(H)`; alongside, sweep a few conditions and check whether a
greedy information curve has a knee (a designed sub-sweep suffices) or grows linearly (the landscape's size
is doing statistical averaging). This simultaneously tests the two premises we asserted — component
**separation** (only true at maturity per our TF24 run) and signal **diffuseness** — which both Oracles
correctly demoted to falsifiable predictions rather than assumptions.

## Literature anchors, tiered by verification

- **[A] confirmed (first workflow, adversarial 3-vote):** the mean is an incomplete summary — identifiability
  can require second-order structure the mean discards (a clean 1/2/4-parameter precedent); mean-based
  inference degrades in the small-count regime (the single-realization analogue); mean-field is exact only
  in the long-interaction-range limit. These underpin settled-point 1.
- **[A] verified verbatim (full text read):** the nine-VDM demography benchmark (Eckes-Shephard et al.,
  *New Phytologist* 2025, 248:2722–2749, 10.1111/nph.70643; open access) — nine models captured mature-forest
  carbon but *"showed compensating effects between overestimated growth and underestimated mortality rates,"*
  so *"similar biomass pools across models result from compensatory interactions between gross growth fluxes
  and turnover times"*: a biomass snapshot does **not** identify demographic rates, and growth + mortality are
  the *"critical calibration targets."* Its recommended fix corroborates our synthesis — constrain the rates
  with **structure over the recovery trajectory**: self-thinning / mass–density relationships (which
  *"implicitly integrate forest structure observations with forest growth rates"*) and **lidar 3-D structure
  benchmarked against ED** (Ma et al.; GEDI). The self-thinning line is itself a scaling relation — a concrete
  candidate for the registered/quotient coordinate flagged above.
- **[A] verified verbatim (full text read):** the Central Amazon steady-state mosaic (Chambers et al., *PNAS*
  2013, 110(10):3949–3954, 10.1073/pnas.1202894110) — old-growth is *"a mosaic of patches in different
  successional stages, with the fraction of the landscape in any particular state relatively constant over
  large… spatial scales,"* and *"the size distribution and return frequency of disturbance events, and
  subsequent recovery processes, determine… the spatial scale over which this… steady state develops."*
  Concretely, for this site: hectare-scale biomass is a *"sawtooth time series"* (a single hectare does not
  recover the landscape mean); *"plots larger than 10 ha would provide the greatest sensitivity"* for trend
  detection; and plot-based sampling misses *"9.1–16.9% of tree mortality"* by under-sampling large
  disturbance events (raising the site mortality rate 1.02% → ~1.20% y⁻¹). Built by fusing field plots + a
  remote-sensing disturbance PDF + individual-based simulation. This is the one **quantitative** answer to the
  support / self-averaging question (what is a "patch", what window) that neither Oracle framing supplied:
  self-averaging only above ~10 ha here, with a heavy large-disturbance tail that small footprints miss.
- **Framing-induced, discount:** the elegant point-process / factorial-moment machinery from the first
  Oracle round was an artifact of a leading representation; the law-space response reaches the *same*
  within/between control-variate scheme with no point processes.

## Decision on further consultation

**No further elicitation.** The unified frame's content is the composition of the two responses (we can
derive it); the deep shared insight (quotient) is decidable from our own model; the remaining unknowns are
empirical. The bottleneck is measurement, not hypotheses — the prototype-and-measure loop is now the arbiter.

## Next actions (measurement, in order)

1. **The concentrated-vs-diffuse test** above, on real patches through a real `H` — decides which whole
   family of methods applies.
2. **The quotient check** — do age-resolved densities superpose under shift/scale; is `rank(∂F/∂θ)` < `p`.
3. **The estimand check** — refine vs reseed the scene; classify the representation gap as numerics or latent.
4. Only then build: age-resolved skeleton + control-variate correction + manifold amortization, swept over
   known conditions, with paired (CRN) gradients.
