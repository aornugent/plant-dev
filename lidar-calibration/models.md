# Existing models — a census of the landscape (and the prior art)

Compiled from the whole investigation. **Caveat:** the deep-research run was *methods*-focused (mean-field
vs stochastic, observation operators, identifiability), so models surfaced incidentally — this is a working
compilation, not a systematic census. Roughly **~18 distinct forest / vegetation and observation-operator
models** appeared, in three families, plus the statistical machinery.

## A. Cohort / demographic / structured ("plant-like", often mean-field) models

| model | what it is | relevance |
|---|---|---|
| **plant** (Falster et al. 2016, *Methods Ecol Evol* 7:136) | size- and patch-structured; deterministic SCM **and** a stochastic finite-patch runner | our target |
| **Ecosystem Demography** — ED (Moorcroft, Hurtt & Pacala 2001), ED2, **ED v3.0** (Ma et al. 2022/2023) | SAS PDEs = the *first moment* of a stochastic gap model; run with spaceborne lidar | the closest lineage; already fused with lidar |
| **FATES** (Fisher et al.) | demographic module inside CLM/ESMs; 200+ params | identifiability at scale |
| **LPJ-GUESS** | cohort DGVM | TSPM class |
| **SEIB-DGVM** (Sato et al. 2007) | individual-based DGVM | from Fischer 2019 |
| **SAL / size-age-location** (Kohyama) | patch-age × within-patch size distribution | explicit space-for-ensemble |
| **PPA** (Purves et al. 2008; Strigul et al. 2008) | perfect-plasticity canopy/cohort approximation | analytic mean-field canopy |
| **Integral Projection Models** | size-structured demography | related class |

*(The nine VDMs benchmarked in Eckes-Shephard et al. 2025 are a set drawn from this family — see `literature.md`.)*

## B. Individual-based / gap models (IBMs) — the "realization" side

| model | what it is | relevance |
|---|---|---|
| **TROLL** (Maréchaux & Chave 2017) | physiology-based, fully spatially explicit tropical-forest IBM | **the prior-art precedent — see below** |
| **FORMIND** (Fischer et al.; Rödig et al. 2017) | process-based IBM; assimilation via allometry | IBM-as-data-integrator |
| **SORTIE** (Pacala et al.; the LES/SORTIE family) | neighbourhood-competition IBM | discrete-individual competition |
| **Forest gap models — JABOWA** (Botkin 1972), **FORET** (Shugart) | the founding stochastic gap-model lineage | what ED approximates as a mean |
| **SILVA 2.2** (Biber et al. 2000; Pretzsch 1995) | distance-dependent single-tree *forestry* growth simulator | used by Hill et al. 2017 (below) |
| Chambers et al. 2013 IBM | individual-based sim + remote-sensing disturbance PDF | the Central Amazon mosaic (see `foundation.md`) |

## C. Observation operators / radiative transfer (structure → lidar) — this is `H`, not a forest model

- **DART** — Discrete Anisotropic Radiative Transfer (3-D); source of the *homogenization-biases-the-waveform* result.
- **LESS** — LargE-Scale remote sensing data and image Simulation framework (3-D RT).
- **librat** — Monte-Carlo ray-tracing RT.
- **GEDI waveform simulator** — ALS → large-footprint waveform forward operator.

## D. Statistical / process frameworks (the mean-field ↔ stochastic + calibration machinery)

Spatial moment equations (Bolker & Pacala; Dieckmann & Law; Murrell) · linear-noise / system-size expansion
(van Kampen) · ABC / synthetic likelihood / neural SBI / pattern-oriented modelling. Point-process /
factorial-moment calculus surfaced only as a *framing-induced* artifact (see `response-pointprocess.md`).

---

## Prior art — Fischer, Maréchaux & Chave (2019) is essentially our problem, already attempted

**Fischer FJ, Maréchaux I, Chave J (2019). "Improving plant allometry by fusing forest models and remote
sensing." *New Phytologist* 223:1159–1165. doi:10.1111/nph.15810** (Tansley insight.)

They calibrate **crown-allometry parameters of the TROLL IBM** by fusing **ground data + airborne laser
scanning (ALS)** through **rejection Approximate Bayesian Computation**: 20,000 simulations, posterior = the
best 200, summary statistics = tree diameter-size distributions + ALS-derived canopy-height distributions;
adding ALS *considerably narrows* the crown-allometry posterior. They flag the central hazard as **the
choice of summary statistics / ABC well-posedness** ("when summary statistics are well chosen, a pattern…
[otherwise] inference methods such as ABC are not well posed"), and point to **emulators** and compute as
the way forward. IBMs are proposed as *data integrators* whose ALS-constrained posteriors become priors for
DGVMs.

**What this means for us.** The paradigm — forest IBM + lidar + data-model fusion — is established, not
novel; so our contribution has to be in *how*, not *whether*. Precisely where our foundation differs from
this brute-force route:
- they run ABC on a **full IBM** (20 000 sims); we have plant's **cheap deterministic mean + AD gradients**,
  which is exactly the cheap-model / expensive-sampler asymmetry our foundation exploits (control variates,
  manifold amortization) to avoid 20 000 blind simulations;
- they hit the **summary-statistic / well-posedness** wall — which is our matched-filter / "where does the
  trait signal live" question, and the **quotient/registration** move (self-thinning as a candidate
  coordinate) is aimed straight at it;
- they calibrate a **handful of allometry parameters at one site**; the accelerator framing (sweep over
  known conditions `c`) is the route to the broader, transferable trait manifold they call for.

So Fischer 2019 both **validates the direction** and **sets the bar**: rejection-ABC-on-a-full-IBM is the
baseline our efficient, mean-field-anchored approach must beat.

## The other new paper — a LiDAR + single-tree-simulator workflow

**Hill S, Latifi H, Heurich M, Müller J (2017). "Individual-tree- and stand-based development following
natural disturbance in a heterogeneously structured forest: A LiDAR-based approach."** Bavarian Forest NP;
post-disturbance (bark beetle / windthrow) regeneration. LiDAR individual-tree detection initializes the
**SILVA 2.2** distance-dependent single-tree growth simulator to project development. Relevance: a concrete
*lidar → individual trees → simulate* pipeline for a **disturbance/succession** setting — i.e. the
patch-age axis observed through lidar — though with an empirical forestry growth model rather than a
process-based demographic one.

---

*Not a complete survey. If a systematic model census is wanted (by biome, by structure class, by whether
they expose a deterministic mean vs only a stochastic sampler, by lidar-fusion track record), that is a
worthwhile by-hand literature pass — flagged as a possible next step, not done here.*
