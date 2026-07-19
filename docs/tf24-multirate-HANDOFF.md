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
- **IMEX** (implicit soil block, explicit cohorts, single global step, no
  sub-cycle) is the **promising untried architecture** — it avoids re-paying the
  O(N) uptake every micro-step while still handling any genuine soil stiffness.

## Pending (finish these first)

1. **R-D verification** (`scratchpad/stiffrerun.R`, 15 yr single-species
   drought, rkck vs mri m=0/20/40). **Discriminator:** does full-N mri (m=0)
   stay **~25% off rkck**? If yes → R-D is neutral (errors are cohort-layer,
   confirming the diagnosis) → **keep R-D only if it earns its place, else
   revert it** (it is currently just an experiment adding named machinery —
   `theta_from_zeta`/`zeta_from_theta`, ζ init, chart conversions — that must
   pay for itself under the abstraction principle).
   *Result: <PENDING — fill in from the current run>.*

## Concrete next steps (in priority order)

1. **Read the R-D result and keep-or-revert.** Default expectation: revert (it
   adds names for no accuracy win on the walls that matter).
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
4. **Explore IMEX** (the untried architecture) — but only after confirming there
   is genuine soil stiffness worth an implicit soil solve; if the stiffness is
   entirely in cohort uptake, IMEX on the soil block won't help either, and the
   answer is "reduce RHS cost" (batched/SoA cohort physiology, setup-cache
   reuse), not a new integrator.
5. **Draft an Oracle consult on the mixed result** (partition works but each
   eval is O(N); collocation trades cost for accuracy; walls are cohort-layer) —
   to pressure-test whether any integrator-side lever remains, or whether the
   whole effort should pivot to RHS-cost reduction.

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
