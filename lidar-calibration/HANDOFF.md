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
- **Second elicitation sent and answered** (`elicitation-quotients.md` → `response-quotients.md`): unified the
  three under-explored threads — **observation operator, transferable trait manifold, emergent phenomena** —
  as one *dimension-collapse* problem (the effective dimension of `θ` in a composed map `F = H∘S`, and where
  dimension collapses: `H`'s null-space, `S`'s image being low-dimensional, `θ`'s low rank). It passed the
  CLEAN gate. The response is the **deepest so far** and subsumes/deepens map-space response #2; triangulated
  and audited. Durable, genuinely-new contributions (all hypotheses to arbitrate by measurement):
  - **`J_i = G_i Z_i`** — split each condition's Jacobian into the *excited* bundle `Z_i=(∂S/∂θ)T` (θ→state,
    costs solves) and the *heard* bundle `G_i=H′(u_i)` (state→output, **solve-free iff `H′` is cheap**). It
    separates the three collapses a single θ→output SVD conflates, and lives at the state (`u`) level —
    invisible from `(θ,y)` pairs.
  - **the "spoken-never-heard" class `k_S−k_eff`** — trait directions excited in the state but that the lidar
    operator cannot hear (the operator-null-space collapse, thread 1), now an isolated measurable quantity.
  - **the impersonation diagnostic `τ`** — whether θ moves the state *along* the `c`-swept manifold (`τ≈1` ⇒ θ
    is a condition-shift, **confounded with `c` → calibration ill-posed**) or opens fresh directions
    (`τ≈0` ⇒ easy). A *free* well-posedness check we did not have.
  - **framing correction:** the three collapses form a **filtration `p′→ρ_S→ρ_F`, not an additive sum** — it
    corrected our own "decomposition by source" premise as ill-posed for overlapping losses.
  - **the one caveat that gates affordability:** the "nearly free" economics assume `G=H′(u)` is **solve-free**
    — true for a cheap analytic/summary `H` (e.g. a canopy-height-distribution functional), **false** for a
    full radiative-transfer render (DART/LESS), whose Jacobian is itself expensive. This is now the first
    thing to check (see next steps).

## Where we are right now

- **Both elicitations are sent and answered.** All three Oracle responses are recorded, triangulated, and
  audited (`response-pointprocess.md`, `response-triangulation.md`, `response-quotients.md`). **The
  hypothesis-generation phase is complete; from here the bottleneck is measurement, not more consults.**
- **The decisive fork for the next phase is the `H′`-cost caveat** in `response-quotients.md`: the whole
  "nearly free attribution" scheme is affordable *iff* the lidar operator's Jacobian `G=H′(u)` is solve-free.
  That is unknown for our operator and must be established first — it decides which version of the A/B/C/D
  experiment we can even run.
- `plant` was **built in a previous session** for the grounding run, but a **fresh session starts without
  it** — you must rebuild before any measurement (see `AGENTS.md`, pillar 2).
- Literature verification is **complete** (both anchors [A] verified).
- **This is a phase boundary.** Starting the plant measurements is a new, larger phase of work — confirm the
  direction with the user before diving in (they flagged the phase change explicitly).

## Concrete next steps (in order)

*All measurements on the **full coupled system**, no proxies (`guide.md` §7). Rebuild plant first:*
`R CMD INSTALL odelia` → `cd plant && make` → `library(odelia); pkgload::load_all("plant")`.

1. **The `H′`-cost / differentiability check — the gate.** For the observation operator we will actually use,
   establish whether `G = H′(u)` is solve-free (cheap analytic/summary `H`, e.g. a canopy-height-distribution
   functional → the whole scheme is nearly free as advertised) or expensive (full scene render, DART/LESS → `G`
   is costly and the cost model must change: emulate `H`, or restrict to a cheap `H`-surrogate for attribution).
   This gates everything below; it is the binding assumption our elicitation smuggled in.
2. **The concentrated-vs-diffuse test** — is the trait signal *between* patch-ages / across-`c` (cheap methods
   win) or *within* a patch-age (needs many expensive draws)? (`foundation.md`, "decisive first experiment").
3. **The A/B/C/D discriminating experiment** (`response-quotients.md` §7; ~55–75 solve-equivalents, full
   `H∘S`). Flagship decisions: **P2** (does a *spoken-never-heard* direction exist — the operator collapse) and
   **P5** (impersonation `τ` — is calibration well-posed against `c`). This subsumes the earlier **quotient
   check** (do age-resolved size-densities superpose under shift/scale — self-thinning; is `rank(∂F/∂θ) < p`
   across conditions?) and the **estimand check** (refine vs reseed the scene: numerics or a latent variable?).
4. Only then build: age-resolved skeleton + control-variate correction + manifold amortization, swept over
   known conditions, with paired (CRN) gradients.
5. **Optional — spatial patterning.** The user offered a "jump-start" on spatial-patterning-from-inter-patch-
   coupling as one candidate emergent quotient; fold it in as *one instance* of the general frame (`τ` and the
   coupling-collapse tests of §4 are where it lands). Not yet provided.
6. **Optional — model census by hand**, organised by whether each model exposes a cheap deterministic mean vs
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
