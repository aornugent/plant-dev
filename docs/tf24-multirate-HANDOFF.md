# TF24 Solver Performance — Session Handoff

> **Two-part document.** Part 1 (**PERSISTENT HEADER**) is authoritative and
> carries across every handoff — treat it as the constitution for this line of
> work, edit it only to correct a stated fact. Part 2 (**STATE & NEXT STEPS**)
> is rewritten each session. Read Part 1 in full before touching anything;
> it exists so context-loss does not reset the project to first principles.

---

# PART 1 — PERSISTENT HEADER (authoritative; rebuild context from this)

## 1. The overarching goal (DX-first)

Make the **TF24 soil-water / plant SCM faster in the forward direction and
stable in the reverse (AD) direction**, over the scenarios that actually matter:
**long horizons (~70 yr), dynamic and realistic rainfall (including multi-year
droughts and monsoonal bursts), and multi-species assemblies.** "Faster" and
"stable" are only meaningful *at the accuracy the downstream science needs* —
which is the accuracy at which the **offspring-production output and the
reverse-mode gradient (J) are converged**, not the tightest tolerance the
integrator can be pushed to.

This is a **developer-experience (DX) goal, not a benchmark-chasing goal.** The
win we want is a system that a scientist can run over hard scenarios without it
failing, stalling on step count, or drifting in reverse — and that a developer
can read and reason about. A 2× speedup bought with machinery that makes the
code unreadable is a loss, not a win.

## 2. odelia codesign

The numerical engine lives in **`odelia`** (a header-only C++ ODE library:
`Solver<System>`, steppers `rkck`/`rodas`/`mri`, XAD-based record→replay reverse
AD). `plant` is the client (the TF24 SCM). The working relationship is
**codesign**:

- New solver capability is **built and validated inside odelia first**, against
  cheap toy systems / demos where correctness is obvious, *then* wired into the
  real `plant` patch. Do not prototype engine features inside plant.
- plant consumes odelia as a normal dependency: **`library(odelia)`** (installed
  package), and **`pkgload::load_all()`** for plant itself.
- Keep the engine general and the client-specific glue in plant. A hook that
  only TF24 needs is a *trait the engine offers*, with the TF24 logic on the
  plant side.

## 3. How we work: system-design + code-review skills, every time

Before any non-trivial change, **invoke the `system-design` skill**; before
committing, **invoke the `code-review` skill.** These are not ceremony — they
are the guardrails that this project has repeatedly needed.

**The abstraction principle (the reviewer's north star), verbatim intent:**

> Prefer abstractions that *reduce* complexity, and push back on overbuilding.
> Abstractions for abstraction's sake make the DX hard. Great design picks
> boundaries that make the code dead simple to understand and reason about;
> having too many named objects works against that principle.

Concretely: **every new name (class, method, trait, config key, term) must pay
for a specific requirement.** If a reader must learn more than one or two
decisions before the rest of the code follows, it is overbuilt. The
`system-design` skill's floor-first procedure (dumbest thing that meets the
ledger wins unless a cited number kills it) is the default. "None found — the
floor was the design" is a good outcome.

## 4. Hard-won lessons (the traps this project has actually fallen into)

These are paid-for in wasted sessions. Do not relearn them.

1. **Measure the REAL coupled patch, never a surrogate.** The multirate effort
   was driven by a linear-relaxation *surrogate* canopy (#43) whose coupling was
   a free mean of θ. The real coupling — uptake `a_ℓ(θ) = Σ_j ρ_j c_ℓ(cohort_j,
   θ)` — is an **O(N) sum over per-cohort hydraulic solves**, state-dependent,
   and is *the dominant cost*. Every conclusion from the surrogate was wrong for
   the real system. Use `Solver<Patch<TF24,TF24_Environment>>` and the
   `patch_rhs_calls` / `mri_fast_rate_calls` counters (`plant/src/mri_diag.cpp`).

2. **The real stiffness is root uptake near θ_res, NOT drainage.** Drainage
   (`K(θ)`, exp≈16) and matric potential (`ψ(θ)`, exp≈−6.57) *look* stiff but
   soften-tests show they are not the step-limiter. The genuinely hard region is
   **the driest layer where cohorts are drawing water near residual θ** —
   `|J_full|` there is 50–291× the hydrology-only Jacobian. #43 measured
   hydrology-only and so missed this entirely.

3. **Layer-averaged / stand-averaged metrics mislead.** A metric averaged over
   5 soil layers or over a benign single-species run hides the one driest, stiff
   layer / the rare hard drought window. Always look at the worst layer and
   deliberately construct hard scenarios (multi-year drought, `gen_extreme`).

4. **Validate in J-units, not θ-units.** The reverse-mode gradient is ~10×
   hypersensitive relative to the forward state. A reformulation that is
   "neutral" on offspring output can still move J. Check the gradient, not just
   the trajectory.

5. **RODAS needs an AD Jacobian hook the patch does not have.** `method="rodas"`
   requires `Jacobian<System>` → a `rebind<U>()` on the System so the engine can
   run forward-AD for the Jacobian. The double-only `Patch` has no `rebind`, so
   **RODAS cannot run on the real coupled patch at all** (not just in reverse).
   Any implicit-stepper plan must first give the patch a templated rebind, or
   confine the implicit solve to a sub-block that has one.

6. **Don't over-generalize from an easy run to "solved" or "impossible".** Both
   directions have burned us: benign runs → "not stiff" (false); one slow MRI
   run → "steppers can't help" (too strong). State the scenario every number was
   measured on.

## 5. Security / process constraints (verbatim, non-negotiable)

- Develop on branch **`claude/tf24-multi-rate-stepper-n5audm`** (both `plant-dev`
  meta and `plant` submodule) and **`claude/tf24-multirate-engine`** (odelia).
- **Push ONLY to `aornugent/*` forks. NEVER push to `traitecoevo/*`.**
- Commit trailers:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01BvyqPT8pVL7bCZvWqmhZHM`.
- **Never** put the model identifier in commits, PRs, code, or comments.
- git config: `user.email noreply@anthropic.com`, `user.name Claude`.
- Load odelia via `library(odelia)`; load plant via `pkgload::load_all`.
- **Production must be bit-identical when `ode_method != "mri"`.** This is the
  invariant that makes all the experimental machinery safe to carry.
- **Do NOT create PRs unless the user explicitly asks.**

## 6. How to rebuild context from scratch (do this first, every new session)

1. Read this whole file (Part 1 + Part 2).
2. Read, in order: `docs/tf24-multirate-recharacterization.md` (why the
   surrogate misled + what actually stresses RK), then the Oracle consults
   (`docs/oracle-consultation-multirate-*.md`, `-verdict.md`).
3. Confirm branch state matches Part 2 (`git log --oneline -3` in all three
   repos). If a PR for the branch has merged, restart the branch from the
   default branch (see the process rules in the task brief).
4. Rebuild plant if you changed headers: `pkgload::load_all` recompiles.
5. Re-run the current baseline (Part 2's "current measurement" script) to
   confirm nothing regressed before building anything new.
6. **Confirm with the user before starting any tangential build.**

---

# PART 2 — STATE & NEXT STEPS (rewritten each session)

*Last updated: 2026-07-19.*

## Repo state (exact)

| repo | branch | HEAD | note |
|---|---|---|---|
| plant-dev (meta) | `claude/tf24-multi-rate-stepper-n5audm` | (this commit) | submodule bumped to plant `fc0dd2bb` |
| plant | `claude/tf24-multi-rate-stepper-n5audm` | `fc0dd2bb` | R-D integrated as **verification experiment** (tests not ported); revert if verification confirms neutral |
| odelia | `claude/tf24-multirate-engine` | `cd95f59` | `[slow\|fast]` layout; mutating hooks; runtime `mri_split()` |

## What is built and working

- **`method="mri"` runs on the real coupled patch** and is **bit-identical when
  off**. The multirate *partition* works: it cuts cohort/slow evaluations
  **~7.6×**. odelia MRI is fully wired (`mri.hpp`, `ode_step_mri_impl.hpp`);
  plant supplies the partition hooks on `Patch` (`slow_size/fast_size/
  coupling_size()=0/aggregate/freeze_slow/fast_rates/slow_rates`, `mri_split()`).
- **Collocation** (reduce the O(N) uptake sum to `m` nodes) is wired via
  `control$n_collocation_nodes` (0 = full N). In the stiff regime it gives a
  **~3× cost win** but with **25% / 279% accuracy errors** on evolved stands.
- **R-C (integrated, correctness fix):** a shut-down TF24 leaf now draws no
  water (`leaf_model.cpp`), removing phantom uptake and fixing a
  dead-drought-gradient AD bug. Test `test-tf24-shutdown.R` passes. **Necessary
  but NOT sufficient** for the accuracy walls.
- **R-D (soil log-depletion chart ζ=ln(θ−θ_res)):** integrated at `fc0dd2bb` as
  an **experiment only** (tests not ported). Verification pending — see below.

## Current understanding (corrected)

The **stepper is not the main lever.** The dominant, reducible cost is the
**per-RHS O(N) cohort physiology**, which every ODE method pays equally;
multirate re-pays it *more often* per macro-step, so each fast eval being O(N)
means MRI is slower than global rkck *unless the uptake is made cheap*. The two
remaining accuracy walls (25% / 279%) are **in the cohort layer**
(macro-grid cohort under-resolution + a shutdown boundary in cohort space) — so
**R-D (a soil-chart change) and RODAS (a soil-stepper) cannot touch them.**

- **R-D:** predicted **neutral** (it reshapes the soil chart, not the cohort
  layer). Verification running this session — see "Pending" for the discriminator.
- **RODAS vs ROS:** RODAS **cannot run on the coupled patch** (no `rebind`, see
  Lesson 5). The branch's "RODAS 5–10×" was on a *cheap-prescribed-uptake soil
  block*, not the coupled patch.
- **IMEX** (implicit soil block via RODAS4 + block-FD Jacobian, explicit
  cohorts, single global step) — **BUILT and MEASURED (2026-07-19): it loses
  decisively.** On a 3 yr drought it is *correct* (converges to rkck's offspring)
  but 20–50× more RHS evals and 56–145× slower, and the ratio **grows** as
  tolerance tightens (21.7× at 1e-4 → 52.2× at 1e-5) — i.e. it takes *more,
  smaller* steps than rkck, not fewer. Implicit-on-soil bought negative step
  enlargement. This is the direct proof (on the real coupled patch) of what the
  Oracle could only argue on a surrogate: **the step is accuracy-limited, not
  stability-limited; soil stiffness is not the lever.** IMEX left in as a
  documented diagnostic (`ode_method="imex"`, bit-identical off), like `mri`.
  - *Why an exact Jacobian won't rescue it:* the 20–50× is ~8–20× more accepted
    steps (only ~2.5× is Jacobian FD inflation). Those extra steps come from the
    **explicitly-integrated cohort layer** (identical to rkck), which no
    soil-block Jacobian touches. Confirmed against `claude/odelia-ad-tape-
    reverse-496fuf`: TF24 deliberately has **no `rebind`** and the Leaf stays
    `double` (design 4.3), its θ-sensitivity supplied by an envelope-theorem FD
    seam — so RODAS's full AD Jacobian cannot run on TF24 regardless, and
    templating the leaf is both rejected-by-design and unable to close the gap.

## Pending (finish these first)

1. **R-D verification** (`scratchpad/stiffrerun.R`, 15 yr single-species
   drought, rkck vs mri m=0/20/40). **Discriminator:** does full-N mri (m=0)
   stay **~25% off rkck**? If yes → R-D is neutral (errors are cohort-layer,
   confirming the diagnosis) → **keep R-D only if it earns its place, else
   revert it** (it is currently just an experiment adding named machinery —
   `theta_from_zeta`/`zeta_from_theta`, ζ init, chart conversions — that must
   pay for itself under the abstraction principle).
   **RESULT (measured, 15 yr single-species multi-yr drought, R-D build):**
   ```
   rkck    : off=5.553e-05  rhs=173907  353s  (baseline)
   mri m=0 : off=6.873e-05  off.rel=2.38e-01  fast=327771  634s  speedup=0.56x
   mri m=20: off=2.201e-04  off.rel=2.96e+00  fast=329199  113s  speedup=3.13x
   mri m=40: off=1.200e-04  off.rel=1.16e+00  fast=328281  180s  speedup=1.96x
   ```
   **Full-N mri (m=0) is already 23.8% off rkck AND 0.56× (slower) — before any
   collocation.** So the 24% error is intrinsic to the MRI macro-grid (fixed
   daily step + sub-cycling under-resolves the **cohort** layer), NOT the soil
   chart and NOT collocation. A soil-chart reshape (R-D) cannot close a
   cohort-layer gap → **R-D does not earn its place → REVERT** (default action,
   pending user confirmation). Collocation errors (m=20: 296%, m=40: 116%)
   compound this; the 3.13×/1.96× "speedups" are meaningless at that accuracy.
   *Caveat: this isolates the error as cohort-layer; it does not directly measure
   R-D's effect on the 10×-hypersensitive gradient (a with/without-R-D rkck
   comparison would — cheap to run if the user wants certainty before reverting).*

## Oracle round 6 verdict (2026-07-19) — the frame is retired

Full statement + response: `docs/oracle-consultation-tf24-recharacterized{,-response}.md`.

- **The fast/slow (x,u) block axis is wrong.** No block decomposition beats global explicit RK at
  converged J (round-5 lower bound stands). The surviving decomposition is **temporal**:
  **piecewise-smooth arcs separated by located events** — hybrid-systems treatment of the *same*
  global explicit RK (step-to-event, restart, full order per arc). Leverage: **event functions are
  decoupled from the O(M) RHS** (threshold crossing = scalar test on (ξ_j,u), 0 solves; forcing kink =
  table lookup; argmax-bound flip = 1 solve). Skewed ρ is now an **ally** — only the few heavy members'
  crossings are controller-visible, so the event set is small. Closes the gap to the bound; does not
  beat it. Deletes the h_min wall.
- **Our IMEX payload was confounded.** The 20–50× (growing with tol) is **order reduction of RODAS4
  fed a noisy FD-Jacobian taken through the fixed-iteration bracketing search** (~2× per tol-decade;
  we measured 2.4×), NOT proof the collapse is outside u. It *does* firmly kill implicit-u AND the
  FD-Jacobian-through-member-solves route. The x-relocation instead rests on the **24% frozen-x error**
  (cleanest datum) and the scattered-10⁻⁹-step pattern.
- **GRADIENT LANDMINE (top priority, correctness):** the "settled fact" that the adjoint gets ∂c/∂u by
  envelope-FD **at fixed p\*** is **wrong** — the envelope theorem covers only outputs *stationary* in
  p, and the coupling co-output c (uptake/E_up) is **non-stationary**. True `dc/du = ∂c/∂u|_p* +
  ∂c/∂p·∂p*/∂u`; the seam drops the 2nd term, into a J that amplifies 10×, and it **evades validation
  if the FD reference also freezes p\***. Fix: `∂p*/∂u = −P_pu/P_pp` (IFT), `∂c/∂p` one extra eval.
  **Status: the cheap forward proxy (standalone leaf, `find_` vs `evaluate_root_collar_psi`) was
  INCONCLUSIVE** — the standalone operating point is degenerate (E_up≈1e-13; results flip with GSS
  tol). The decisive test is at the **adjoint level on the reverse-mode branch**
  (`claude/odelia-ad-tape-reverse-496fuf`): dJ/dθ adjoint vs true-FD-**with-reoptimization** on a real
  transpiring patch state (Oracle E4). Do this before trusting any reverse-mode gradient.
- **Frontier is the member mesh + the functional, not the integrator:** the insertion schedule refines
  for x(t) but J hangs on ∫c·ρ → add a **coupling-weighted (ρ·|c|) refinement indicator** (free — the
  full-M byproducts exist every step) and re-run the M-refinement certification. Attacks the 24% and
  the 23% inter-scheme spread at root. And J is ~barely-observable-sensitive — reformulating it may
  beat any numerics.

## Event sizing (Oracle round-6 E1) — measured 2026-07-19

Canonical benchmark bank in `scripts/tf24-benchmarks/` (6 hard rainfall sequences
committed as `data/*.rds`; `generate_bank.R`, `event_sizing.R`, `RESULTS.md`).
odelia `step_diag` logs every step attempt. Findings:
- **~27–35% of step attempts are rejected** (rejection-bisection localisation
  overhead — 1 in 3 O(M) RHS evals discarded), uniform across sequences.
- **min h ≈ 1.4e-8–5e-8 · T** scattered collapse (confirms isolated non-smoothness).
- **Forcing kinks explain a minority** (2–31%, tracks rain frequency); small steps
  cluster **in dry gaps, away from rain**.
- **Member insertions explain ~0** — the SCM already makes them step boundaries.
- **70–98% unattributed → the dry-end state-dependent crossings** (leaf-shutdown
  boundary, argmax bound, θ_res clamp). Splitting this residual into
  removable-events vs intrinsic is the open measurement (Oracle E3).
- **Multispecies (4 spp) fails NON-FINITE** at the highest reject frac (0.35) — a
  genuine instability, not a slowdown.
- Draft consult on event-aware integrator design: `docs/oracle-consultation-event-aware.md`
  (domain-clean, ready to send).

## Oracle round-7 verdict (2026-07-19) — event-aware design + build order

Full: `docs/oracle-consultation-event-aware{,-response}.md`. The design is
**step-to-event on the same global explicit RK**, with the localizer and the
removable-vs-intrinsic **classifier built as one instrument**. Build order:
1. **Forcing-kink step clipping — today** (clip trial steps to the known rainfall
   kink table; removes the measured 4–31% kink share; ~5-line change).
2. **Shadow-monitor + branch-signature logging run — the classifier (gate).** Log,
   per accepted step, all cheap event functions (heavy-member threshold `g_j`,
   clamp margins `θ−θ_res`, argmax-bound margins, kink proximity) **+ an integer
   branch signature from inside each per-cohort solve** (0 extra solves). Sign/
   signature flips time-stamp every crossing incl. un-hypothesized ones (branches
   inside the leaf solve). Attribution + a smooth-arc refinement test (poly fit vs
   discontinuity) splits residual into event-attributable vs intrinsic. **Go/no-go
   for the full build.**
3. **Proximity governor** — cap trial step at ~1.2× time-to-nearest-event (from
   logged margins + drift) → converts rejection bisection (O(M)×5–15 probes) into
   one dense-output root solve. Kills most of the ~30% rejection overhead.
4. **Dense-output event location + hot restart** (full stage recompute, never reuse
   FSAL across an event) for the shutdown threshold; **clamp active-set** (pin/
   release, not hysteresis); **tracked-p (TF24f)** to delete the argmax-bound class.
5. **Q3 multi-block afternoon** before scaling multispecies: distinguish H1
   (undetected crossing — governor cures), H2 (coupled-mode instability, `h·|λ|` at
   explicit boundary — needs stiff treatment of θ along the shared-soil axis; note
   "implicit refuted" was single-species only!), H3 (clamp sliding-mode chatter).
   Cheap first cut: the failure's h-trajectory (smooth collapse→H2, jump→H1,
   oscillation→H3).
6. **Back to the member mesh + J** (still the real frontier: mesh refined for x(t)
   but J = ∫c·ρ; and J's 10× conditioning).

## Concrete next steps (in priority order)

0. **[NEW, top priority] Verify the gradient landmine (Oracle E4)** on
   `claude/odelia-ad-tape-reverse-496fuf`: compare dJ/dθ from the adjoint vs a
   true finite difference that **re-optimizes the argmax** (not the frozen-p\*
   FD), on ≥2 θ-components over a real transpiring patch state. A gap = the
   dropped `∂c/∂p·∂p*/∂u` term → the reverse-mode gradient is first-order wrong on
   the coupling channel. Cheap forward proxy was inconclusive (degenerate leaf).
0b. **Event-sizing (Oracle E1/E2), this branch, no build:** instrument one run to
   log each step's distance to the nearest event surface (forcing kink, heavy-
   member threshold, argmax-bound flip, insertion, clamp); partition
   smallest-decile/rejected steps into event-attributable vs intrinsic. E2 =
   five-line time-kink-alignment A/B to bound the forcing-kink share.
1. **Revert R-D** (result in): the accuracy wall is confirmed cohort-layer, so
   the soil-chart machinery buys nothing on the walls that matter. Optionally run
   the with/without-R-D rkck gradient comparison first if certainty is wanted.
2. **Code-review pruning pass over current changes** (invoke `code-review`).
   Candidates for deletion under the abstraction principle: R-D machinery if
   neutral; any collocation surface if the accuracy walls prove fatal; confirm
   every partition hook on `Patch` pays for a requirement. The bit-identical-off
   invariant is what lets us prune aggressively.
3. **Attack the two accuracy walls directly** (they are the real blocker, and
   they are cohort-layer):
   - boundary-aware collocation (place nodes to resolve the shutdown boundary in
     cohort space, not a blind subsample of the measure);
   - macro-grid cohort-resolution control (the under-resolution source).
4. ~~Explore IMEX~~ **DONE — IMEX measured, loses 20–50× (see above).** The
   integrator is not the lever. The remaining levers are on the **RHS-evaluation
   cost / cohort layer**: batched/SoA cohort physiology, setup-cache reuse of the
   θ-dependent per-cohort prep, or removing the cohort-layer control kink
   (event-handling the collar-ψ argmax / the TF24f tracked control).
5. **Oracle consult (in progress 2026-07-19):** with the implicit stepper now
   measured, the consult is no longer "does a decomposition help" (answered: no)
   but **"given accuracy-limited steps, complex state-dependent O(N) coupling, a
   cohort-layer accuracy wall that defeats collocation, and evolved mature stands
   that frustrate quadrature — where is the real leverage, given the genuine
   fast/slow split in the state?"** Build a complete, accurate system description
   first (see `docs/oracle-consultation-*` and the recharacterization doc).

## Key files (quick map)

- Engine: `odelia/inst/include/odelia/mri.hpp`, `ode_step_mri_impl.hpp`.
- Patch hooks / partition / R1 flow: `plant/inst/include/plant/patch.h`,
  `plant/inst/include/plant/models/tf24_environment.h`.
- Collocation: `plant/inst/include/plant/species.h`,
  `individual.h` (`consumption_given_height`).
- Control surface: `plant/inst/include/plant/control.h`, `src/control.cpp`,
  `inst/RcppR6_classes.yml` (`ode_method`, `n_collocation_nodes`,
  `mri_use_split`); `scm.h` (`scm_ode_method`).
- Diagnostics: `plant/src/mri_diag.cpp` (RHS + fast-eval counters).
- R-C: `plant/src/leaf_model.cpp`, `tests/testthat/test-tf24-shutdown.R`.
- Scratch benches: `scratchpad/stiffrerun.R`, `stiffcompare.R`, `colloc_rc.R`,
  `rd_rodas_bench.R`, `extreme.R`, `longhorizon.R`.
