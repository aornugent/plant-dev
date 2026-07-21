# Why TF24 offspring production doesn't converge when you add cohorts — and what actually fixes it

*For plant maintainers. 2026-07-21. This is the concrete, plant-side statement of a
result worked out through a series of numerical experiments (the abstract write-ups are
`tf24-v2-T1-arnoldi-result.md`, `tf24-v2-T5a-emergent-skewness-result.md`,
`tf24-v2-T3-common-field-decomp-result.md`, reconciled in `tf24-v2-reconciliation.md`).
You do not need those to act on this one.*

---

## The problem, in one sentence

When you refine the TF24 cohort-introduction schedule (introduce more cohorts over the
patch's life), **offspring production keeps moving and doesn't settle** — e.g. on
`intense_storms` it falls from `2.7e-7` to `8.5e-8` when the schedule goes from 94 to
~140 cohorts, and on `whiplash` from `2.1e-6` to `3.3e-7`. Two different refined
schedules disagree by 9–45%. The production default schedule is a **bad universal
starting point** — plain uniform-in-time cohorts land 3–35× closer to a refined answer
on every benchmark rainfall scenario.

The obvious worry was that **offspring production is intrinsically discontinuous** — a
cohort sitting exactly on the survival knife-edge (its density heading to zero) flips in
or out as the mesh moves, so no schedule can converge it, and the only fix would be to
**change the model** (smooth the survival/reproduction transition). **That worry is
wrong.** The experiments below show the non-convergence is a *numerical* problem with a
*numerical* fix, and the survival knife-edge is a red herring for the offspring total.

## The real cause: the soil-water trajectory is under-resolved, and plants are hypersensitive to it

TF24 couples cohorts to a 5-layer soil-water column. Every cohort draws water (root
uptake); the total uptake summed over all cohorts is what drives soil moisture down;
soil moisture then sets every cohort's growth and reproduction. It's a tight feedback
loop, and it has one dangerous property we already knew: **near the dry limit (soil
moisture near residual), plant response to water is enormously sensitive** — the coupled
sensitivity there is 50–291× the soil-hydrology-only sensitivity.

Here is what actually happens when you add cohorts:

1. More cohorts compute the **total water uptake** more accurately.
2. That shifts the **soil-water trajectory** the whole stand experiences.
3. Because growth is hypersensitive to soil water, that shift — amplified ~10× through
   the uptake feedback — **moves everyone's growth and reproduction**, and hence the
   offspring total.

So the offspring number moves not because you're sampling reproduction better, but
because you're changing the **shared soil-water environment** that every cohort lives in.
The default schedule computes that environment too coarsely; refining fixes the
environment, and the offspring total chases it.

## The evidence (three experiments, each ruling something out)

**1. The offspring integral itself is already converged at the default schedule.**
Freeze the soil-water trajectory from the default run, then drop in a ~1.5× denser set
of cohorts *without letting them feed back*. Offspring changes by **~0%** (6e-10 on
intense_storms, 2e-9 on whiplash). → **It is not a "we need more cohorts to sample
reproduction" problem.** The reproduction quadrature is fine.

**2. Letting the denser cohorts feed back into soil water is the entire effect.** Same
denser cohort set, now self-consistent (they draw water and reshape soil moisture):
offspring drops **69–84%** — i.e. **100% of the non-convergence** is this soil-water
feedback shift, on both scenarios.

**3. The shift is spread across the productive (early) cohorts, not a single dying
cohort on the survival edge.** The per-cohort change is diffuse — the three largest-
changing points carry only 2–3% of the total change — and it sits where most offspring
comes from (early-introduced cohorts), **not** as a spike at a cohort crossing the
survival threshold. → **The survival knife-edge does not drive the offspring error.**
(There *is* a cohort whose *relative* error is huge near the survival threshold, but it
carries almost no offspring, so it's invisible in the total.)

Two supporting facts:
- **There is no dominant cohort to worry about.** The heaviest single cohort carries only
  ~1.6% of offspring, and that halves every time you double the schedule — the population
  is well spread and refines cleanly. (An earlier idea that a few dominant cohorts needed
  special "splitting" treatment was based on a misreading — there are no such cohorts.)
- **The coupled soil-water/plant system has a genuine, stable limiting answer.** We
  measured how strongly the loop amplifies a disturbance to the water-uptake field across
  all its independent modes; it never approaches the runaway threshold. The converged
  offspring number *exists* — refinement is chasing a real target, not a mirage.

## What this means for you

- **Do not change the survival/reproduction model to fix convergence.** The offspring
  total is a well-posed number; no smoothing of the survival transition is needed for it.
  (If you want the *per-cohort gradient* near the survival edge to be smooth for other
  reasons, that's a separate question — but it is not what's blocking offspring
  convergence.)
- **The convergence problem is the cohort schedule under-resolving the soil-water
  uptake.** To converge offspring, you need a schedule that resolves the **water-uptake
  field over time**, not one that puts cohorts where reproduction is densest.
- **This is exactly why the current refinement heuristic doesn't help.** It flags cohorts
  by their contribution to reproduction — but reproduction is already resolved
  (experiment 1). The error lives in the soil-water field. Refining by reproduction
  chases the wrong signal (it actively anti-correlated with the true error in earlier
  tests). **The refinement criterion should target where adding a cohort most changes the
  total water uptake / soil-water trajectory.**

## A separate, orthogonal opportunity (speed, not accuracy)

While measuring the above we found the member (cohort) block is integrated on the
soil-water column's *fast* timescale. Offspring is insensitive to soil-water wiggles
faster than about **weekly** (removing all sub-2-day soil-water texture changes offspring
by ≤3%; it only bends at the weekly scale). But the shared time step is sub-daily
(~0.1–0.25 day), so every cohort is re-solved 30–100× more often than offspring needs.
If the soil-water column is sub-stepped on its own fast clock while cohorts advance on a
weekly-ish macro step, the number of (expensive) full-cohort solves could drop 10–100×.
This needs a cheap way to refresh the water uptake as soil moisture changes within a
macro step — pursued separately (see `tf24-v2-T4-filtered-field-result.md` and the
Newton-on-uptake prototype).

## Where the numbers/scripts live

- `scripts/tf24-benchmarks/common_field_decomp.R` — experiments 1 & 2 (freeze vs feed
  back), plus the diffuse-vs-spike geometry (experiment 3).
- `scripts/tf24-benchmarks/emergent_skewness.R` — no-dominant-cohort / clean refinement.
- `scripts/tf24-benchmarks/arnoldi_spectrum.R` — the coupled system has a stable limit.
- `scripts/tf24-benchmarks/filtered_field_probe.R` — the weekly-timescale speed finding.
- Benchmark rainfall scenarios: `scripts/tf24-benchmarks/data/*.rds` (intense_storms,
  whiplash, extended_drought, dry_to_wet, long_horizon, drydown, multispecies).

## Caveats (honest scope)

- Measured on `intense_storms` (12 yr) and `whiplash` (16 yr); the "denser" mesh was
  ~1.5× (snapping cohort times to the solver's step grid collapsed some). The direction
  and 100%-field-shift split are unambiguous; the exact convergence *rate* of the
  soil-water field wasn't sized (would need a clean N→2N→4N field study).
- The light/canopy environment was held at the default run's values in the freeze/feed-
  back test; the feedback isolated here is specifically the **soil-water** loop (which is
  the one carrying the hypersensitivity and the amplification).
