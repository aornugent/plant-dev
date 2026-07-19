# HANDOFF — live state and next steps

*Rewritten each session. **Read [`AGENTS.md`](./AGENTS.md) first** — it is the persistent header (the goal,
the plant-grounding discipline, the Oracle method, the classifier lessons, and the order to read things in).
This file assumes no prior knowledge and tells you exactly where we are and what to do next.*

**Last updated:** 2026-07-19 · **Branch:** `claude/oracle-consultation-patterns-26x6ea` (all work pushed; no
PR opened) · **Working dir:** `/home/user/plant-dev`, materials in `lidar-calibration/`.

## What this project is (one paragraph)

We want to **calibrate the `plant` model's trait parameters from raw lidar** sampled across a landscape
(`AGENTS.md`, pillar 1). We have not yet written calibration code. The work so far is *foundational*: pin the
right representation, use **Oracle consultations** (a powerful external reasoner, framed as a domain-clean
numerical problem) to find non-obvious structure, verify the supporting literature, and ground everything in
what `plant` actually produces. `foundation.md` is the anchor; this file is the live state.

## The arc so far (what happened, and why)

- **Framing for the Oracle took many iterations** — a domain-leak classifier rejects anything reading as
  ecology/biology *or* statistical inference. The register that passes is deterministic numerical-methods
  (see `AGENTS.md`, "The Oracle classifier"). Two framings passed: a **law-space** one (a family of
  distributions `μ_θ`, cheap mean, expensive draws, nonlinear `H`, compute `E[H]`) and a **map-space** one
  (a deterministic map `F(θ,c)` with a reverse-mode gradient, swept over known conditions `c`).
- **Two responses came back and were triangulated** (`response-pointprocess.md`, `response-triangulation.md`).
  Trustworthy convergences (two independent framings agreeing): (i) never anchor on the global mean — it is a
  phantom point / gauge direction, possibly off-domain; (ii) the observation-operator bias has **no fixed
  sign** and is curvature-driven (occlusion) — triple-confirmed with a killed claim and the DART result;
  (iii) exploit a linearity + a control variate (the cheap biased evaluation) + amortization across the trait
  manifold; (iv) **the deepest shared lead: hunt for a symmetry/quotient that collapses the parameter
  space.** The elegant point-process machinery in the first response was *framing-induced*, not fundamental.
- **Literature verified** (`literature.md`, `sources.md`) — two anchors read in full: **Eckes-Shephard et
  al. 2025** (nine vegetation-demographic models: a biomass snapshot does **not** identify demographic rates
  — similar biomass from compensating over-growth / under-mortality; the recommended fix is *structure over
  the recovery trajectory*, e.g. self-thinning, + lidar) and **Chambers et al. 2013** (Central Amazon: the
  mosaic self-averages only **above ~10 ha**; one hectare is a "sawtooth"; plot sampling misses **9–17% of
  mortality** in the large-disturbance tail).
- **Models censused + prior art found** (`models.md`) — ~18 models in three families (cohort/demographic;
  IBM/gap; lidar RT operators). **Fischer, Maréchaux & Chave 2019 is prior art for our exact problem:** the
  TROLL IBM + airborne lidar + **rejection ABC** to calibrate crown allometry (20 000 sims, best 200; summary
  statistics = size + canopy-height distributions), walling at summary-statistic choice / well-posedness. Our
  intended edge over their brute-force route: plant's **cheap deterministic mean + AD gradients**, the
  **quotient/manifold** structure, and the **swept-conditions** framing for the transferable manifold they
  call for.
- **Foundation anchored** (`foundation.md`): the representation is *a mixture over latent patch-age at each
  swept condition; traits shared across the landscape; a nonlinear lidar operator that needs a scene the
  size-density does not fix.* Grounded in a real TF24 run (continuous, strongly multimodal size-density; no
  positions).
- **Second elicitation drafted and ready** (`elicitation-quotients.md`): unifies the three under-explored
  threads — **observation operator, transferable trait manifold, emergent phenomena** — as one
  *dimension-collapse* problem (the effective dimension of `θ` in a composed map `F = H∘S`, and where
  dimension collapses: `H`'s null-space, `S`'s image being low-dimensional, `θ`'s low rank). Deliberately
  general, not narrowed to any one quotient. It passed the CLEAN gate.

## Where we are right now

- `elicitation-quotients.md` is **written, CLEAN, and ready to send — but not yet sent.** It is the immediate
  next action.
- `plant` was **built in the previous session** for the grounding run, but a **fresh session starts without
  it** — you must rebuild before any measurement (see `AGENTS.md`, pillar 2).
- Literature verification is **complete** (both anchors [A] verified).
- The decision on further consultation: this one further elicitation (the quotient/dimension-collapse
  question) is warranted; beyond it the bottleneck is **measurement**, not more hypotheses.

## Concrete next steps (in order)

1. **Send `elicitation-quotients.md` to the Oracle.** Record the response verbatim (or faithfully condensed)
   as `response-quotients.md`; **triangulate it against `response-triangulation.md` #2** (same map-space
   register — convergences are especially informative); audit for contamination (which planted premises did
   it inherit? did it turn them into falsifiable predictions?).
2. **Rebuild plant, then run the decisive measurements** (all on the *full coupled system*, no proxies):
   - build: `R CMD INSTALL odelia` → `cd plant && make` → `library(odelia); pkgload::load_all("plant")`.
   - **concentrated-vs-diffuse** — is the trait signal *between* patch-ages (cheap methods win) or *within*
     (needs many expensive draws)? (`foundation.md`, "decisive first experiment").
   - **quotient check** — do age-resolved size-densities collapse under a shift/scale (self-thinning); is
     `rank(∂F/∂θ) < p` across conditions? (tests the quotient candidates the elicitation is about).
   - **estimand check** — refine vs reseed the scene: is the representation gap *numerics* or a *latent
     variable*?
3. **Optional — spatial patterning.** The user offered a "jump-start" on spatial-patterning-from-inter-patch-
   coupling as one candidate emergent quotient; fold it in as *one instance* of the general frame (do not let
   it narrow the frame). Not yet provided.
4. **Optional — model census by hand**, organised by whether each model exposes a cheap deterministic mean vs
   only a stochastic sampler, and its lidar-fusion track record (the methods-focused research did not map
   this).

## Cautions / loose ends

- **Faithful, not cheap, tests** (`guide.md` §7): every Oracle claim and every candidate quotient must be
  tested on the full coupled system before you build on it — a cheap test on a decoupled proxy has reversed
  conclusions here (TF24 multirate).
- **Do not narrow the quotient** to a single type; keep the general frame.
- Raw deep-research journals are **session-ephemeral** — already salvaged into `sources.md` / `literature.md`.
- Papers integrated so far: Eckes-Shephard 2025, Chambers 2013, Fischer 2019, Hill 2017. If the user sends
  more, verify by local text extraction (`fitz`/PyMuPDF — the Read tool's PDF renderer is unavailable here)
  and tier them in `literature.md` / `sources.md`.
- No PR opened; the branch carries the full arc.
