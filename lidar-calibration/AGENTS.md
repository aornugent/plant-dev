# lidar-calibration — authoritative header (read first, every session)

> **This header persists across hand-offs.** The *live state and concrete next steps* live in
> **[`HANDOFF.md`](./HANDOFF.md)**, rewritten each session. Change this file only when the project's goal,
> grounding discipline, or method changes — not for routine state updates.

## Rebuild context from scratch — before any work

A prior session built deep context here and will lose it at the window boundary. If you are starting fresh,
reconstruct it in this order, and **do not begin work until you have read 1–3**:

1. **[`HANDOFF.md`](./HANDOFF.md)** — the live state and the concrete next steps.
2. **[`foundation.md`](./foundation.md)** — the anchor: the representation, what is settled, the hazards, the
   decisive experiment.
3. **This file (below)** — the three pillars, the Oracle-classifier lessons, and the working practice.
4. **[`guide.md`](./guide.md)** — how to consult the Oracle. Read before writing any elicitation.
5. As needed: `elicitation*.md` (what we have sent), `response-pointprocess.md` + `response-triangulation.md`
   (what came back + our audits), `literature.md` / `models.md` / `sources.md` (evidence, prior art,
   bibliography).

## The three pillars (enshrined — do not drift from these)

**1. Overarching goal.** Calibrate **plant**'s trait parameters against **raw lidar sampled across a
landscape** — turn cheap, abundant, *static structural* observations into constraints on a mechanistic,
*dynamical*, size-structured model, so we **read process off pattern**. The load-bearing insight: a
mechanistic model earns its keep **across the swept ensemble, not per-sample** — sweep it over parameters,
rainfall, environment and demand it reproduce the statistical pattern across many observations with varied,
*known* conditions (the particle-accelerator picture: no single collision measures the standard model).
Individual footprints are near-uninformative; the constraint lives in the response *across* conditions.

**2. Plant grounding.** **Never reason about the system in the abstract without grounding it in a real plant
run.** This project has already been burned by clean-looking framings that were wrong about what plant
actually produces (e.g. the size-density is a *continuous* density, strongly *multimodal* per patch-age, with
*no* horizontal positions — learned only by running it, and it reshaped the whole formulation). Before
trusting any abstraction, build plant and check it against a real TF24 run. Build (in-session):
`R CMD INSTALL odelia`, then `cd plant && make`, then `library(odelia); pkgload::load_all("plant")`; a
minimal grounding script and its findings are recorded in `foundation.md`. Repo-root `AGENTS.md` has the
workspace rules.

**3. Oracle elicitation as a core, recurring method.** Consulting a powerful external reasoner ("the Oracle")
is a **primary, repeated tool** here — not a one-off — used to find reframes and breakthroughs that are not
obvious through the domain lens but present themselves in the *general numerical representation* of the goal.
Every elicitation is domain-clean, standalone, and in the register that passes the classifier (below). The
Oracle is a **hypothesis generator arbitrated by faithful measurement, never an authority** (`guide.md` §7):
record every response, audit it for contamination, and **triangulate** independent framings — convergences
are the trustworthy signal, divergences localize the fork.

## Materials (index)

| file | what it is |
|---|---|
| `HANDOFF.md` | **Live state + concrete next steps.** Rewritten each session. Read first. |
| `foundation.md` | **The anchor.** Representation, settled findings, hazards, decisive experiment, next actions. |
| `guide.md` | How to consult the Oracle — framing practice, hard-won. Read before writing any elicitation. |
| `elicitation.md` | First domain-clean elicitation (v7 map-space register that passes). |
| `elicitation-quotients.md` | Second elicitation (map-space): effective dimension of a composed map + the structures that collapse it — observation-operator / trait-manifold / emergent quotients as one problem. |
| `response-pointprocess.md` | First Oracle response (point-process framing) + our framing audit. |
| `response-triangulation.md` | Two responses (law-space, map-space) + the triangulation and contamination audit. |
| `literature.md` | Research digest, tiered by verification. |
| `models.md` | Census of existing models (cohort/demographic, IBM/gap, lidar RT operators) + the prior art. |
| `sources.md` | Annotated bibliography (titles + URLs + DOIs) to bootstrap further literature search. |

## The Oracle classifier — what passes, what trips (hard-won this project)

The Oracle is fronted by a **domain-leak classifier** that rejects a statement if it recognizes it as
belonging to a specific applied domain (ecology/biology) **or** to statistical inference. Getting past it
took many iterations; the register is narrow.

**What PASSES** — the *deterministic scientific-computing / numerical-methods* register, exactly the tone of
the demo-branch consults. Opens "A numerical-methods question. No application context is needed or given."
Objects are maps, operators, gradients, discretizations, IVPs. Parameters `θ` are things you
**differentiate**, never *infer*. **Essentially zero probability/stochastic vocabulary and zero inference
vocabulary.** (v6 — a static family of distributions with a cheap mean + expensive draws + `E[H]` — passed;
v7 and the quotient elicitation — a deterministic map `F(θ,c)` with a reverse-mode gradient — passed most
cleanly.)

**What TRIPS it** (data points from this project):
1. **Inference vocabulary** — infer, estimate, likelihood, posterior, prior, Bayesian, identifiability,
   calibrate, fit, recover, invert. *(v3 tripped.)*
2. **A stochastic-generative / population / process narrative** — "a generator run forward in time from an
   empty state, reset at random times, elements that develop, realizations, ensemble." A dynamical process
   with resets reads as mathematical biology **regardless of the nouns**. *(v5 tripped.)* Telling the *story*
   of the mechanism reintroduces the domain — describe objects by the *operations available on them*.
3. **Domain nouns** — tree/forest/canopy/light/lidar/patch/disturbance/trait/size/soil/… *(v1, v2 tripped.)*
4. **A representation that also leads** — "a law on finite point sets with an intensity" drew, inevitably,
   point-process calculus. Not a classifier trip, but a framing lead (`guide.md` §1); leave the object
   *unspecified* and ask which formalization fits.

**The recipe that works:**
- Strip domain nouns to zero; strip inference vocabulary to zero; **strip the generative/process story.**
- Describe objects by the operations available — what is cheap to compute, what you can sample, what maps to
  the observable, what the couplings are — not by a mechanism narrative.
- **Hold the calibration purpose off-page** (the demo consults compute gradients *for* an optimization they
  never name): pose the forward/sensitivity/computation question; leave "recover `θ`" unstated.
- **Run a grep gate before sending**, over the draft, for: domain nouns · solution-method names · inference
  words · stochastic/probability words · process/temporal words. All should be empty. Idioms are false
  positives ("stands alone", "for instance", "stand-in", "prior thread") — reword them anyway.
- When in doubt about tone, re-read the demo-branch consults or `guide.md`; match their register.

## Working practice

- The Oracle is a hypothesis generator arbitrated by the prototype-and-measure loop, not an authority
  (`guide.md` §7). Never act on a claim — or a candidate quotient — without a **faithful** falsifiable test:
  the *full coupled system*, never a simplified proxy (a cheap test on a decoupled proxy has reversed
  conclusions here — the TF24 multirate lesson; `guide.md` §7).
- Every elicitation is domain-clean and standalone; every response is recorded (verbatim or faithfully
  condensed) with an audit; convergences across independent framings are the trustworthy signal.
- Audit every response for **contamination**: which of your asserted premises did it inherit? A good response
  turns premises into falsifiable predictions rather than assuming them.
- The demo branch `claude/multirate-stepper-review-r6dpwn` holds the original worked example of this whole
  practice (its `docs/oracle-consultation-*.md`) — the reference register and cadence.
