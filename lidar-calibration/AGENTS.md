# lidar-calibration — objective, materials, and the Oracle classifier

## Objective (enshrined)

**Calibrate plant's trait parameters against raw lidar sampled across a landscape** — turn cheap, abundant,
*static structural* observations into constraints on a mechanistic, *dynamical*, size-structured model, so
we read **process off pattern**. plant is rare in carrying detailed size-and-patch dynamics; the hard part
is that we have no easy way to parameterise it.

The load-bearing insight (do not lose it): **a mechanistic model earns its keep across the ensemble, not
per-sample.** Its value is that you can *sweep* it — over parameters, rainfall, environment — and demand it
reproduce the statistical pattern across many observations with varied, known conditions. Individual lidar
footprints are near-uninformative (a single hectare is a "sawtooth", not the mean); the constraint on the
trait parameters lives in the response *across* the swept conditions. This is the particle-accelerator
picture: no single collision measures the standard model; the pattern across thousands of varied collisions
does.

**`foundation.md` is the anchor — start there.** It holds the full representation (a mixture over latent
patch-age at each swept condition, traits shared across the landscape, a nonlinear lidar operator that needs
a scene the size-density does not fix), what is settled, the hazards, the decisive first experiment, and the
ordered next actions (all measurement — plant is buildable in-session).

## Materials (index)

| file | what it is |
|---|---|
| `foundation.md` | **The anchor.** Representation, settled findings, hazards, decisive experiment, next actions. Read first. |
| `guide.md` | How to consult the Oracle — framing practice, hard-won. Read before writing any elicitation. |
| `elicitation.md` | The current domain-clean problem statement to send the Oracle (the v7 register that passes). |
| `response-pointprocess.md` | The first Oracle response (point-process framing) + our framing audit. |
| `response-triangulation.md` | Two responses (law-space, map-space) + the triangulation and contamination audit. |
| `literature.md` | Research digest, tiered by verification. |
| `sources.md` | Annotated bibliography (titles + URLs + DOIs) to bootstrap further literature search. |

## The Oracle classifier — what passes, what trips (hard-won this project)

The Oracle is fronted by a **domain-leak classifier** that rejects a statement if it recognizes it as
belonging to a specific applied domain (ecology/biology) **or** to statistical inference. Getting past it
took many iterations; the register is narrow.

**What PASSES** — the *deterministic scientific-computing / numerical-methods* register, exactly the tone of
the demo-branch consults. Opens "A numerical-methods question. No application context is needed or given."
Objects are maps, operators, gradients, discretizations, IVPs. Parameters `θ` are things you
**differentiate**, never *infer*. **Essentially zero probability/stochastic vocabulary and zero inference
vocabulary.** (This session: v6 — a static family of distributions with a cheap mean + expensive draws +
`E[H]` — passed; v7 — a deterministic map `F(θ,c)` with a reverse-mode gradient, swept over conditions —
passed most cleanly.)

**What TRIPS it** (this session's data points):
1. **Inference vocabulary** — infer, estimate, likelihood, posterior, prior, Bayesian, identifiability,
   calibrate, fit, recover, invert. *(v3 tripped.)*
2. **A stochastic-generative / population / process narrative** — "a generator run forward in time from an
   empty state, reset at random times, elements that develop, realizations, ensemble." A dynamical process
   with resets reads as mathematical biology **regardless of the nouns**. *(v5 tripped.)* **Telling the story
   of the mechanism reintroduces the domain** — describe objects by the *operations available on them*, not
   by narrating how they are generated.
3. **Domain nouns** — tree/forest/canopy/light/lidar/patch/disturbance/trait/size/soil/… *(v1, v2 tripped.)*
4. **A representation that also leads** — "a law on finite point sets with an intensity" drew, inevitably,
   point-process calculus. Not strictly a classifier trip, but a framing lead (see `guide.md` §1); leaving
   the object *unspecified* and asking which formalization fits is safer and more open.

**The recipe that works:**
- Strip domain nouns to zero; strip inference vocabulary to zero; **strip the generative/process story.**
- Describe objects by the operations available — what is cheap to compute, what you can sample, what maps to
  the observable, what the couplings are — not by a mechanism narrative.
- **Hold the calibration purpose off-page.** The demo consults compute forward solutions and gradients *for*
  an optimization they never name; do the same — pose the forward/sensitivity/computation question, leave
  "recover `θ`" unstated.
- **Run a grep gate before sending**, over the draft, for: domain nouns · solution-method names ·
  inference words · stochastic/probability words · process/temporal words. All should be empty. Idioms are
  false positives ("stands alone", "for instance", "stand-in", "prior thread") — reword them anyway to keep
  the gate strict.
- When in doubt about tone, re-read the demo-branch consults or `guide.md`; match their register.

## Working practice

- The Oracle is a **hypothesis generator**, arbitrated by the prototype-and-measure loop — not an authority
  (`guide.md` §7). Never act on a claim without a **faithful** falsifiable test: the *full coupled system*,
  never a simplified proxy (a cheap test on a decoupled proxy has reversed conclusions here — the TF24
  multirate lesson).
- Every elicitation is domain-clean and standalone; every response is recorded verbatim (or faithfully
  condensed) with an audit; **convergences across independent framings are the trustworthy signal**,
  divergences localize the fork.
- Audit every response for **contamination**: which of your asserted premises did it inherit? A good response
  turns your premises into falsifiable predictions rather than assuming them.
- plant builds in-session: `R CMD INSTALL odelia`, then `cd plant && make`, then
  `library(odelia); pkgload::load_all("plant")`. See the repo-root `AGENTS.md` for the workspace rules.
