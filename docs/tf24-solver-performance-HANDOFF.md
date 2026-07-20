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
2. Read the **current** docs (see Part 2 "Document map"): the live design
   `docs/oracle-consultation-event-aware{,-response}.md` and the round-6 verdict
   `docs/oracle-consultation-tf24-recharacterized{,-response}.md`. The
   `oracle-consultation-multirate-*` rounds and `tf24-multirate-*` docs are
   **superseded/historical** — read only for the audit trail, do not build from them.
3. Confirm branch state matches Part 2 (`git log --oneline -3` in all three
   repos). If a PR for the branch has merged, restart the branch from the
   default branch (see the process rules in the task brief).
4. Rebuild plant if you changed headers: `pkgload::load_all` recompiles.
5. Re-run the current baseline (Part 2's "current measurement" script) to
   confirm nothing regressed before building anything new.
6. **Confirm with the user before starting any tangential build.**

---

# PART 2 — STATE & NEXT STEPS (rewritten each session)

*Last updated: 2026-07-20. Forcing clip shipped (#21) + Stage-1 classifier gate
run: verdict INTRINSIC (the event stepper is NOT built).*

## Gate result (2026-07-20) — the event stepper is dead; the frontier is the mesh/J

Build-order #1 (forcing-kink clip) shipped: bit-identical off, offspring
preserved, cost-neutral, small reject reduction; only ~2 % of accepted steps land
on forcing features — confirming forcing is a minor step driver.

Build-order #2 (the classifier gate) is **done and decisive: INTRINSIC.** The
shadow-monitor + per-cohort branch-signature instrument (odelia `step_monitor`,
plant `tf24_solve_diag`, bit-identical off) ran the full bank at converged tol.
Across all 5 scenarios (20–70 yr, wet and dry): the hypothesized event surfaces
are **never approached** (soil clamps/runoff never fire; leaf-shutdown margin
never below 4.66 — shutdown is at 0; argmax collapsed-interval never fires;
≥99.8 % of cohort solves take the smooth GSS branch), and the ~30 % rejection
waste **does not co-locate** with the discrete events that do fire (median 2 %
within ±1 step). Step size is weakly predicted only by *continuous* structure
(GSS interval width / soil wetness, ρ≈0.3–0.4). **The kill question is answered:
the 70–98 % collapse is intrinsic fast structure, not removable events.** So
spec §4a–4e (dense output, event location, active-set, transition handlers) are
**not built** — they would buy ~nothing. Full write-up:
`docs/tf24-classifier-gate-result.md`. Next: the proximity
governor is optional (small expected win, since rejections don't co-locate);
the real work is the **coupling-weighted mesh + J** (§7 below), and the one
cohort-layer lever the data point at is the **GSS/argmax smoothness** (the TF24f
tracked-control variant that deletes the argmax).

## Where we are (one paragraph)

Seven Oracle rounds + direct measurement on the real coupled patch have **settled
the verdict: the time-integrator is not the lever.** No block decomposition
(multirate/MRI, collocation, implicit-on-soil/IMEX/RODAS) beats global explicit
RK at converged `J`; all were built and measured, all lose or are refuted. The
step is **accuracy-limited by isolated non-smoothness in the cohort layer**, not
soil stiffness. The **one forward pathway** is an **event-aware global explicit
RK** (step-to-event on the same solver) plus work on the **member mesh and the
functional `J`** — the real accuracy frontier. Two correctness items sit outside
the perf work: a **reverse-mode gradient bug** (filed) and a **multi-block
non-finite failure** (diagnosed H1/overflow, not stiffness).

## Repo state (exact)

| repo | branch | HEAD |
|---|---|---|
| plant-dev (meta) | `claude/tf24-multi-rate-stepper-n5audm` | `b878b17` |
| plant | `claude/tf24-multi-rate-stepper-n5audm` | `64e1e729` |
| odelia | `claude/tf24-multirate-engine` | `5d19a24` |

## What is built (all bit-identical when off; kept as documented diagnostics)

- **MRI** (`ode_method="mri"`): partition works (cuts cohort evals ~7.6×) but each
  soil micro-step re-pays the O(N) coupling → slower than rkck. Engine: `odelia`
  `mri.hpp`; plant partition hooks on `Patch`.
- **Collocation** (`control$n_collocation_nodes`): ~3× cost win but 25–279% error
  on evolved stands (the evolved measure defeats blind subsampling).
- **IMEX** (`ode_method="imex"`, RODAS4 + block-FD Jacobian): measured 20–50×
  worse (the deficit was later shown to be RODAS order-reduction from a noisy
  FD-Jacobian through the argmax; either way, not the lever). Kept as a diagnostic.
- **R-C (correctness, keep):** a shut-down TF24 leaf draws no water — removes
  phantom uptake + fixes a dead-drought AD-gradient bug (`leaf_model.cpp`,
  `test-tf24-shutdown.R`).
- **R-D (experiment, CONFIRMED DEAD → revert pending):** soil log-depletion chart
  ζ=ln(θ−θ_res) at plant `fc0dd2bb`. Verified neutral (the accuracy wall is
  cohort-layer, a soil-chart reshape cannot touch it). `git revert fc0dd2bb`
  applies cleanly — see Next Actions #1.
- **Benchmark bank + instrumentation:** `scripts/tf24-benchmarks/` (6 canonical
  hard rainfall sequences as `data/*.rds` + generator + `event_sizing.R` +
  `RESULTS.md`); odelia `step_diag` step-attempt log (off by default).
- **Forcing-kink clip (#21, shipped):** odelia `has_clip_times` + `clip_forcing`
  control; plant `clip_time_after` / `extrinsic_drivers_next_node_after`. Clips
  trial steps to rainfall feature knots. Bit-identical off; cost-neutral.
- **Stage-1 classifier instrument (#22, shipped; the GATE):** odelia
  `step_monitor` (per-accepted-step margins + branch signatures, `step_diag`
  storage + `has_step_monitor` trait) and plant `Patch::step_monitor` /
  `tf24_solve_diag` per-cohort branch sink / `TF24_Environment::soil_event_margins`.
  Bit-identical off. Verdict INTRINSIC (see "Gate result" above);
  `scripts/tf24-benchmarks/classifier_{capture,analyze}.R`.

## Measured facts that anchor the plan

- **Event sizing (E1) across the bank:** ~27–35% of step attempts **rejected**
  (rejection-bisection overhead); **min h ≈ 1.4e-8–5e-8·T** scattered collapse;
  forcing kinks explain only 2–31% (cluster in dry gaps); **member insertions
  explain ~0** (already step boundaries); **70–98% unattributed → dry-end
  state-dependent crossings** (leaf-shutdown boundary, argmax bound, θ_res clamp).
- **Multi-block failure:** multispecies (4 spp) goes non-finite at t=5.745 yr with
  the step **growing** (h up to ~0.25 yr) → **not** coupled-mode stiffness (H2);
  signature is H1 large-step overshoot / density overflow (`exp(log_density)→Inf`).
- **`J` is ~10× hypersensitive** (23% inter-scheme spread) — validate in J-units.

## The forward pathway — event-aware integrator (Oracle round-7 build order)

**Authoritative implementation spec: `docs/tf24-event-aware-spec.md`** (verified
against the real odelia↔plant↔TF24 coupling; system-design ledger + staged build +
codesign split + acceptance vs `BASELINE.md`). Design summary below; build from the
spec.

Full design rationale: `docs/oracle-consultation-event-aware{,-response}.md`.
Design = step-to-event on the same global explicit RK; the localizer and the
removable-vs-intrinsic **classifier are one instrument.**

1. **Forcing-kink step clipping** — clip trial steps to the known rainfall-kink
   table. ~5 lines, zero risk, removes the 2–31% kink share. Ship first.
2. **Shadow-monitor + branch-signature run (THE GATE).** Per accepted step, log all
   cheap event functions (heavy-member shutdown margin, clamp margin θ−θ_res,
   argmax-bound margin, kink proximity) **+ an integer branch signature from inside
   each per-cohort solve** (0 extra solves). Sign/signature flips time-stamp every
   crossing incl. un-hypothesized ones. Attribution + a smooth-arc refinement test
   (poly fit vs discontinuity) splits the 70–98% residual into event-attributable
   vs intrinsic. **Decides whether the full build pays off.**
3. **Proximity governor** — cap the trial step at ~1.2× time-to-nearest-event
   (from logged margins + drift) → converts rejection bisection (O(N)×5–15 probes)
   into one dense-output root solve. Targets the ~30% rejection overhead. Also the
   likely cure for the multi-block H1 overshoot.
4. **Dense-output event location + hot restart** (full stage recompute, never reuse
   FSAL across an event) for the shutdown threshold; **clamp active-set** (pin/
   release, not hysteresis); **tracked-p (TF24f)** to delete the argmax-bound class.
5. **Member mesh + functional (the real frontier).** Add a **coupling-weighted
   (ρ·|c|) refinement indicator** (free — the full-M byproducts exist every step);
   re-run the M-refinement certification of `J`. Reconsider `J`'s conditioning
   (reformulation may beat any numerics — a model-side call).

## Next actions (in order)

1. **[code cleanup] Revert R-D** (`git revert fc0dd2bb` on plant — clean),
   rebuild, confirm rkck bit-identical. Confirmed-dead machinery; needs sign-off.
2. **[code-review pass]** Run the `code-review`/`simplify` lens over the retained
   experimental surface. Keep IMEX (per decision) and R-C; assess whether MRI /
   collocation / `mri_use_split` still earn their place now the frame is retired,
   under the abstraction principle. Bit-identical-off is what licenses pruning.
3. **[build] DONE.** #1 (kink clipping) shipped; #2 (classifier gate) run →
   **INTRINSIC** (see "Gate result" above). The event-location stepper is not
   built. Remaining forward options, in order: (a) **coupling-weighted (ρ·|c|)
   mesh refinement + J re-certification** (§7 / build-order #5 — the real
   frontier); (b) optionally the **proximity governor** for the reject fraction
   (cheap but small expected win — rejections don't co-locate); (c) **TF24f
   tracked-p** to delete the argmax and reduce the continuous cohort-layer
   stiffness the gate identified.
4. **[correctness, separate branch] Gradient bug (plant#60):** verify Oracle E4 on
   `claude/odelia-ad-tape-reverse-496fuf` — adjoint dJ/dθ vs true FD that
   **re-optimizes the argmax**, on a real transpiring patch state. Owned there.
5. **[correctness] Multi-block:** confirm the proximity governor (or a density
   guard) cures the multispecies non-finite; definitive H2 eigenvalue check only
   if it doesn't.

## Document map (status)

**Current / authoritative**
- `tf24-solver-performance-HANDOFF.md` — this file (the build plan).
- `tf24-event-aware-spec.md` — **the implementation spec** for the forward pathway
  (verified coupling map, staged build, codesign split, acceptance criteria).
- `scripts/tf24-benchmarks/BASELINE.md` — the frozen numbers to beat.
- `oracle-consultation-event-aware{,-response}.md` — the live design rationale.
- `oracle-consultation-tf24-recharacterized{,-response}.md` — the round-6 verdict
  (frame retired) and corrected system description.
- `scripts/tf24-benchmarks/` (`RESULTS.md`, bank, harness) — canonical benchmark.
- `oracle-consultation-guide.md` — how to frame Oracle consults (general).
- plant#60 — the reverse-mode gradient bug (tracked on GitHub).

**Superseded / historical** (kept for the audit trail; do NOT build from these)
- `oracle-consultation-multirate-{update,response,followon,followon-response,collocation,collocation-response,verdict}.md`
  — Oracle rounds 1–5, the block-decomposition line, retired by round 6.
- `tf24-multirate-recharacterization.md` — the round-5-era recharacterization
  (its conclusion is folded into the round-6 consult).
- `tf24-multirate-engine-port-spec.md`, `tf24-multirate-implementation-plan.md` —
  the MRI/decomposition build plan. **Retired approach** — banner added.
- `tf24-multirate-forward-track.md`, `tf24-multirate-factoring-probe.md`,
  `tf24-multirate-real-patch-results.md`, `tf24-rodas-multirate.md`,
  `tf24-reformulations-evaluation.md` — historical analysis from the decomposition
  effort.

**Adjacent workstream (separate, live):** the `ad-*.md` set + `docs/README.md`
cover the reverse-mode AD infrastructure; plant#60 lives at that boundary.

## Key files (quick map)

- Engine: `odelia/inst/include/odelia/` — `mri.hpp`, `ode_step_rodas.hpp` (+
  `ode_step_imex.hpp`, `ode_jacobian.hpp` `BlockFdJacobian`), `step_diag.hpp`,
  `ode_solver_internal.hpp` (`Method` dispatch + step log).
- Patch / partition / R1 flow: `plant/inst/include/plant/patch.h`,
  `models/tf24_environment.h`.
- Collocation: `plant/inst/include/plant/species.h`, `individual.h`.
- Control surface: `plant/inst/include/plant/control.h`, `src/control.cpp`,
  `inst/RcppR6_classes.yml` (`ode_method`, `n_collocation_nodes`, `mri_use_split`);
  `scm.h` (`scm_ode_method`).
- Diagnostics: `plant/src/mri_diag.cpp`; odelia `src/step_diag.cpp`.
- R-C: `plant/src/leaf_model.cpp`, `tests/testthat/test-tf24-shutdown.R`.
