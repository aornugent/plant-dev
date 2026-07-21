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

*Last updated: 2026-07-21 (session 2). Prior session consolidated the record into a
domain-clean **fundamentals** elicitation → TWO Oracles → **correction/addendum** → fresh
Oracle's falsification ladder; the big reframe stands: the forward problem RELOCATED from
the time-stepper (at its floor for the norm it is given) to the MEASURE (member-mesh) axis.
**This session ran the ladder to the bottom.** (1) Fixed the RK45-cache OOM by slimming the
cache to the field a replay reads (plant `b2f70dfa`); the 12-yr ghost that OOM'd now peaks
1.14 GB. (2) **Validated the ghost (rung 1):** frozen-field error is O(mass fraction), →0 as
ρ→0 — an exact rare-invasion / marginal-member probe. (3) **Killed WR (rung 5):** built a
contraction probe (plant `0015c9fd`), measured κ≈10 ≫ 1 uniformly — plain/windowed/damped
Picard diverges (the known ~10× coupling amplification). (4) **Goal-oriented placement
(rung 2) does not fund:** J does not converge under node-count refinement for ANY placement
family (survival-flip discontinuity) — nothing to place toward. Filed **odelia#47** (L3
replay should store only the recomputable field, per the slim-cache precedent).*

***The forward-numerics frontier has now resolved to a conclusion:*** *the time-stepper is at
its floor, WR is expansive, and placement cannot certify a functional that is discontinuous
under the refinement. The residual measure-axis error IS J's intrinsic discontinuity (a
moment of a measure with an absorbing weight boundary), whose fix is **item B — model-side
mollification of the survival entry**, exactly as both fundamentals Oracles predicted. What
remains numerics-actionable: **rung 3** (certified survival crossings via ghost bisection,
+ the rainfall-as-locator test) — which would quantify the discontinuity to inform the
mollification width — and a cheap DX side-win (the production default schedule is badly
placed; uniform is 3–35× closer).*

***ORACLE UPDATE — WRITTEN and committed this session*** *(`docs/oracle-consultation-fundamentals-v2.md`,
plant-dev `c5f0b65`). Follows the user's guidance: concrete + comprehensive, no conclusions, no
proposed remedies, no directed questions (consult-guide Q&A format dropped; budget spent on
characterisation). Domain-clean (grep gate clean; only "reservoir" — the deliberate general rendering
of the small block — matches). Supersedes the earlier fundamentals elicitation + addendum: errata
folded in; adds §9 with this session's three new results (9a zero-feedback probe O(weight fraction),
9b self-consistency contraction κ≈10, 9c J non-convergence under mesh refinement). It is a REVIEW
ARTIFACT — nothing has been sent to any Oracle.*

## ▶ NEXT SESSION — start here (the frontier is the measure axis, not the stepper)

1. **Read Part 1 in full**, then this Part 2.
2. **The current authority docs (read these):** `docs/tf24-two-oracle-synthesis.md`
   (the two responses compared), `docs/tf24-correction-response-triage.md` (the ladder +
   status), and the four result docs below. Verbatim Oracle responses:
   `docs/oracle-consultation-fundamentals-response-{fresh,ongoing}.md` and
   `docs/oracle-consultation-correction-response-fresh.md`. The elicitation +
   correction sent out: `docs/oracle-consultation-fundamentals{,-correction}.md`
   (both domain-clean — keep them that way; the classifier trips on soil/cohort/rain/
   leaf/etc.).
3. **What is settled this session (do not relitigate):**
   - **The measure axis carries the dominant *reproducible* error, not the time axis.**
     The production run uses a *fixed* insertion schedule that is **~6× from mesh-converged**
     (J 2.15e-6 fixed vs 3.4e-7 refined on one sequence); even two *refined* meshes differ
     ~2.3%. Fixed uniform densification is **not asymptotic** (Richardson order p≈0.2,
     negative extrapolant — `docs/tf24-richardson-result.md`): placement, not count,
     converges the measure. So a *certificate* for J needs adaptive/goal-oriented placement,
     not the >15-min refiner. The tol-band "production at loose edge" check is **unresolved**
     (confounded by the unconverged mesh; redo on a converged measure).
   - **Forcing spline knots (fresh Oracle's top stone): real but minor.** A step crossing a
     C² daily knot rejects +12–36 pp more (size-controlled), but only **1.3–3.9 pp of the
     ~30% rejection** is knot-attributable. Not a frontier-reopener
     (`docs/tf24-node-distance-result.md`). Corrected the elicitation's §4 error (forcing is
     a C² cubic spline, not piecewise-linear).
   - **The error norm is an extreme value over a growing member block (item D,
     confirmed).** 192–345 distinct components attain `rmax` among rejects (entropy
     0.77–0.83); members dominate over reservoirs (~70/30); consecutive churn 0.23–0.28
     (drifts, not memoryless → nothing for a serial predictor, explains the PI failure).
     `docs/tf24-argmax-churn-result.md`.
   - **The J-weighted-norm lever is real but modest.** The norm-weight join
     (`docs/tf24-norm-weight-join-result.md`): the `rmax`-attaining member is J-marginal
     (<10% species weight) on 50–69% of member-limited steps — but the distance-to-removal
     split shows **⅓–½ of those marginal setters are *dying*** (`d(log ρ)/dt < −1`,
     heading to the `ρ→0` boundary = survival bits that must keep full weight). Net cleanly-
     reclaimable ≈ **10–20% of accepted steps**, gated by a survival guard band. Worth a
     prototype only if that's judged worth the machinery; the architectural stone (WR) likely
     beats it.
   - **`J`'s inter-mesh spread is BOTH diffuse and survival-bits** (`docs/tf24-deltaJ-decomp-result.md`,
     first cut on an unconverged pair): median relative per-lineage error 0.53 (diffuse) with
     a 1532× spike (a survival flip). Clean separation needs a *both-converged* mesh pair.

4. **The frontier / build order (fresh Oracle's falsification ladder, cheapest-first —
   `docs/tf24-correction-response-triage.md`):**
   - **Cheap rungs DONE:** knots (minor), churn (confirmed), Richardson (fixed family
     non-asymptotic → certificate needs goal-oriented placement), norm-weight join +
     ldr split (modest lever).
   - **The unlock — DONE and VALIDATED (2026-07-21):** **ghost members = `run_mutant`.**
     The OOM was the RK45 cache storing a full `Environment` (incl. the light spline's
     adaptive builder + band workspace, both replay-unused) per sub-step. Fixed by caching
     only the field a replay reads — light knots + soil state, `EnvStepRecord` (plant
     `b2f70dfa`, bit-identical, `test-mutant.R` green). 12-yr ghost now peaks **1.14 GB**
     (was OOM). **Item 1 validated:** frozen-field error is O(mass fraction), →0 as ρ→0
     (relJ 63→0.42→0.036→0.003 as probe mass 0.39→0.06→0.006→0.0006); `J_real→J_ghost` as
     mass→0. The ghost is an exact rare-invasion / marginal-member probe. **3 yr is
     pre-reproductive (J~1e-15); use ≥12 yr** (J~2.7e-7). Result +
     scripts: `docs/tf24-ghost-validate-result.md`, `scripts/tf24-benchmarks/ghost_{validate,massfrac}.R`.
   - **Rung 5 (WR contraction) — RUN and KILLED (2026-07-21).** Built the probe (plant
     `0015c9fd`: `record_uptake` + `sweep_soil` + `overwrite_cached_soil`, off by default,
     bit-identical, `test-mutant` green) and measured the Picard contraction of
     `a→u→members→a` on saved fields. **κ ≈ 10 ≫ 1**, uniform across δ and across all six
     2-yr windows (δ=0 round-trip sanity 1.1%). Plain/windowed/damped WR **diverges** — it is
     the same ~10× coupling amplification already on record (members respond enormously near
     `u_min`, the 50–291× region). Only Anderson/Newton–Krylov on the small `a(t)+s` fixed
     point could work, which abandons WR's cheap-Picard appeal. Retired as posed. Full result:
     `docs/tf24-wr-contraction-result.md`. Probe hooks kept as documented diagnostics.
   - **Rung 2 (goal-oriented placement) — RUN and does NOT fund (2026-07-21).** Tested across
     the measure-stressing bank scenarios (extended_drought, dry_to_wet, long_horizon,
     whiplash). (i) The Oracle's hierarchical-surplus indicator is **anti-correlated** with
     the J-error (Spearman −0.56…−0.86); error sits ~100% at small τ_ins (J's mass), not at
     surplus peaks. (ii) g-mass placement doesn't robustly beat uniform (loses on the deep
     long_horizon mesh). (iii) **Schedule-neutral convergence: J does not converge under
     node-count refinement for ANY family** — successive deltas grow, families disagree
     9–45% at 4×. This is the **survival-flip discontinuity** (refining moves which members
     cross ρ→0), not a placement problem — nothing to place *toward*. Routes to **item B
     (J mollification, model-side)** as the real measure-axis requirement, exactly as both
     fundamentals Oracles said. Cheap DX side-win: the production **default schedule is badly
     placed** (whiplash 847% off); plain uniform is 3–35× closer at matched count. Full
     result: `docs/tf24-goal-placement-result.md`; scripts `goal_placement_{predict,test,converge}.R`.
   - **Surviving ladder (NOT run — user paused here this session):** rung 3 (certified survival
     crossings via ghost bisection in `τ_ins`), paired with the **rainfall-as-locator test**
     (drought windows in the known forcing should predict the lineage-ages carrying survival
     crossings → free bracket). This would quantify the discontinuity to inform item B's
     mollification width. **Item B (J mollification)** is the identified measure-axis requirement
     but is a model-side decision (survival-margin window width), not numerics. The user chose to
     **pause after the Oracle update** rather than run rung 3 — the forward-numerics frontier is
     already resolved to a conclusion. Rung 3 is the clean head of the queue for next session.
   - **Model-side, logged not built:** Newton-on-`g` / the bordered-fold locator for the
     gradient seam (plant#60, updated this session with the exact `{F=0, ∂F/∂r=0}` system);
     J mollification; multi-block NaN-guard/growth-clip.
   - **E4 / adjoint correctness (task #23)** still the one un-run high-value correctness test.

5. **Rebuild env only to run code:** `R CMD INSTALL --no-docs --no-byte-compile odelia`;
   then `rm -f plant/src/*.o plant/src/*.so` and `options(pkg.build_extra_flags=FALSE);
   pkgload::load_all("plant", export_all=TRUE)`. The **norm-weight-join instrument** is built
   (odelia `step_monitor` hook gained an `rmax_index` arg; plant `Patch::step_monitor` appends
   the attaining member's ρ, weight-fraction, and `d(log ρ)/dt`) — **bit-identical off,
   verified rel=0**. `step_argmax_*` log (which component sets `rmax` per attempt) also built.

Still standing independently: the **pruning sign-off** (task #20) and the
**multispecies-capture** harness fix.

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
`docs/tf24-classifier-gate-result.md`. A stress battery (whole-profile drydown,
TF24f, multispecies) confirmed INTRINSIC holds at the dry extreme and surfaced two
findings: (i) **leaf shutdown is nearly unreachable by construction** — it keys on
the wettest accessible layer and even 12 yr zero rain can't dry the profile to
psi_crit; the stand dies of carbon starvation from the drying topsoil while a wet
deep layer persists (`docs/tf24-soil-profile-eco.md`, task #24); (ii) **TF24f is
too fragile to run on hard sequences** — the tracked-ψ control leaves the feasible
leaf-solve domain at the default `k_acclim=1` (**filed plant#61**), so the
"delete the argmax via TF24f" lever needs a feasibility guard first. Next: the
proximity governor is optional (small expected win, since rejections don't
co-locate); the real work is the **coupling-weighted mesh + J** (§7 below).
Remaining battery gap: multispecies capture (harness birth-rate API mismatch).
Filed: **plant#61** (TF24f tracked-ψ leaves the feasible domain at default k_acclim)
and **plant#62** (leaf shutdown nearly unreachable — wettest-layer keying). Oracle
consult written as a deep neutral characterisation (no directed questions):
**`docs/oracle-consultation-intrinsic-characterisation.md`** — the classifier is
the Oracle's own E1/build-#2 and its result *refutes* the round-6/7 event-program
bet (collapse is intrinsic/broadband, not removable events; enrichment lift ≈0.8–1.0).

## Where we are (one paragraph)

Seven Oracle rounds + direct measurement settled that the **time-integrator is not
the lever** (no block decomposition beats global explicit RK at converged `J`). The
round-6/7 verdict then proposed one forward pathway — an **event-aware** global
explicit RK (step-to-event) — gated on a classifier (build-#2 / E1) that would
first prove the step-collapse is made of **removable events**. **We built that gate
and it refuted the premise:** the collapse is **intrinsic/broadband**, not
event-attributable (enrichment lift ≈0.8–1.0; event surfaces fire <0.5%; the
dominant hypothesised event is unreachable *by construction*; the argmax-bound
event never fires; the one control-smoothing remedy, tracked-`p`/TF24f, is
numerically infeasible as posed → plant#61). So **§4a–4e of the event spec are not
built.** The forcing clip (#21) shipped anyway (free). The remaining forward
frontier is the **member mesh + functional `J`** (§7). A deep-characterisation
consult reporting all this is written and awaiting the Oracle. Two correctness
items sit outside the perf work: the **reverse-mode gradient bug** (plant#60, E4,
task #23) and the **multi-block non-finite failure** (diagnosed H1/overflow).

## Repo state (exact)

| repo | branch | HEAD |
|---|---|---|
| plant-dev (meta) | `claude/tf24-multi-rate-stepper-n5audm` | `c5f0b65`+ (v2 Oracle draft + this update) |
| plant | `claude/tf24-multi-rate-stepper-n5audm` | `0015c9fd` (slim cache + WR contraction probe) |
| odelia | `claude/tf24-multirate-engine` | `2f78191` (unchanged this session; odelia#47 filed on GitHub) |

All three clean and pushed to `aornugent/*`. Open PRs: none (do not open without explicit
ask). Issues filed: **odelia#47** this session (L3 replay: record only the recomputable
field, per the slim-cache precedent); **plant#61** (TF24f tracked-ψ leaves the feasible
leaf-solve domain at default `k_acclim`) and **plant#62** (leaf shutdown near-unreachable —
wettest-layer keying) in the prior session.

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
- **R-D (experiment, CONFIRMED DEAD — REVERTED #19):** soil log-depletion chart
  ζ=ln(θ−θ_res). Verified neutral and reverted; production byte-identical to the
  pre-R-D state. Done.
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

- **Classifier gate (E1 / build-#2), the current authority — supersedes the earlier
  event-sizing interpretation.** ~27–35% of step attempts rejected; min h
  ≈1e-8–1e-9·T scattered. The earlier read ("70–98% unattributed → dry-end
  state-dependent crossings: shutdown/argmax/θ_res") was a **hypothesis; the gate
  refuted it.** Measured across 5 bank scenarios + drydown (all bit-identical
  monitored): rejections co-locate with an event-surface flip only **2–4% (median
  2%)** of the time; the member solve is **≥99.7% the single smooth branch**;
  switch-off fires **<0.5%** and its margin never reaches 0 (unreachable by
  construction, plant#62); the **argmax-bound (degenerate-interval) event never
  fires (0)**; clamps/runoff never fire. Enrichment `P(event|hard)/P(event|easy)
  ≈ 0.8–1.0` → **collapse is intrinsic/broadband.** The only (weak) continuous
  predictor of step size is the **argmax feasible-interval width** (Spearman
  ρ≈0.24–0.42) and, collinearly, soil-depletion margins (ρ≈0.4). Full write-up:
  `docs/tf24-classifier-gate-result.md`.
- **Multi-block failure:** multispecies (4 spp) goes non-finite at t=5.745 yr with
  the step **growing** (h up to ~0.25 yr) → **not** coupled-mode stiffness (H2);
  signature is H1 large-step overshoot / density overflow (`exp(log_density)→Inf`).
  (Classifier multispecies capture is still blocked on a harness birth-rate API
  fix — a remaining gap.)
- **`J` is ~10× hypersensitive** (23% inter-scheme spread) — validate in J-units.

## The forward pathway — event-aware integrator (Oracle round-7 build order) — ⚠ LARGELY RETIRED BY ITS OWN GATE

**Status:** step 1 shipped (clip); step 2 (the gate) ran and **refuted** the premise
of steps 3–4 → **steps 4a–4e are not built** (see the gate result above; the spec
`docs/tf24-event-aware-spec.md §3` now carries the INTRINSIC verdict inline). Step 3
(proximity governor) is optional and low-value (rejections don't co-locate, so it
has little to grip). **Step 5 (member mesh + `J`) is the surviving frontier.** The
build order is kept below for the audit trail; do **not** build 4a–4e without a new
Oracle mandate that overturns the gate.

**Spec (now historical for §4, live for §7): `docs/tf24-event-aware-spec.md`**
(verified coupling map; system-design ledger; codesign split; acceptance vs
`BASELINE.md`).

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

0. **[gated on the Oracle] Receive + triage the response** — see the "▶ NEXT
   SESSION" block at the top: save it dated, then reduce every claim to the cheapest
   falsifiable test (raw classifier data lets you test attribution/geometry reframes
   for free) and run it before building. This is the head of the queue.
1. **[frontier, most likely next build] Coupling-weighted (ρ·|c|) mesh refinement +
   `J` re-certification** (§7 / event build-order step 5 — the surviving frontier).
   The insertion schedule resolves `x(t)` but `J` depends on `∫c·ρ`; add a `ρ·|c|`
   refinement indicator (free — the full-M byproducts exist every step) and re-run
   the M-refinement certification of `J`. Attacks the 24%-class error + 23%
   inter-scheme spread at the root. **Do this unless the Oracle redirects.**
2. **[correctness, separate branch] Gradient bug (plant#60 / E4):** the one prior
   Oracle item not yet tested. Verify on `claude/odelia-ad-tape-reverse-496fuf` —
   adjoint dJ/dθ vs a true FD that **re-optimizes the argmax**, on a real transpiring
   patch state (the envelope-at-fixed-p* recipe may drop `(∂c/∂p)(∂p*/∂u)`). Task #23.
3. **[code-review sign-off] Pruning pass (task #20):** deletion of MRI / collocation /
   `mri_use_split` — analysis done, physical deletion **awaiting user sign-off**.
   Keep IMEX + R-C. Bit-identical-off licenses it. Now *more* justified: the frame is
   fully retired by the gate.
4. **[coverage gap] Multispecies classifier capture** — fix the `add_strategies`
   birth-rate API mismatch in `classifier_battery.R` (needs per-species birth rate;
   `rep(1,n)` did not satisfy it — check `add_strategies` signature), then capture the
   R3 failure case through the monitor. Also the natural place to confirm whether the
   multi-block H1 blow-up co-locates with any event.
5. **[optional, low-value] Proximity governor** — only if a reject-fraction win is
   wanted; expected small since rejections don't co-locate with event surfaces.

## Document map (status)

**Current / authoritative**
- `tf24-solver-performance-HANDOFF.md` — this file (the build plan).
- **This session's ladder results (2026-07-21):**
  `tf24-ghost-validate-result.md` (rung 1: ghost = `run_mutant` validated as an exact
  marginal-member probe; slim-cache fix, memory numbers),
  `tf24-wr-contraction-result.md` (rung 5: WR killed, κ≈10), and
  `tf24-goal-placement-result.md` (rung 2: goal-oriented placement does not fund; J
  non-convergent under refinement = survival-flip discontinuity → item B). odelia#47
  (L3 replay slim-record) filed on GitHub.
- `oracle-consultation-fundamentals-v2.md` — **the current Oracle characterisation (this session's
  update; supersedes `-fundamentals.md` + its correction).** Self-contained, domain-clean,
  no directed questions, no proposed remedies; §9 folds in ghost probe / WR κ≈10 / placement
  non-convergence. A review artifact — not sent.
- `oracle-consultation-fundamentals.md` — **the consolidated fresh-Oracle elicitation** (zero prior
  context, domain-clean, no question/no proposed remedy): the complete system + discretisation +
  correctness reference + the full measured record of every approximation tried and why it resisted
  (decomposition/MRI/RODAS/IMEX, member-reduction, tracked-control, events, inner-tolerance, PI
  controller, reformulations). Consolidates all prior rounds; the intended fresh-Oracle send.
- `oracle-consultation-intrinsic-characterisation{,-response}.md` — the deep neutral
  characterisation consult **and the Oracle's response** (the noise-floor hypothesis).
- `tf24-noise-floor-E1-E2-result.md` — **the E1/E2 triage of that response (current
  authority on the inner-search question):** source floor confirmed, solver-level
  mechanism refuted, F1 ill-posed (corner optimum), J-bifurcation finding.
- `tf24-classifier-gate-result.md` — the gate measurement + verdict (INTRINSIC) and
  the stress battery. The reason the event program is retired.
- `tf24-soil-profile-eco.md` — the shutdown-reachability mechanism (plant#62).
- `oracle-consultation-guide.md` — how to frame consults + **§7 test-before-build**
  (apply to the incoming response).
- `scripts/tf24-benchmarks/` — the bank, harness, `BASELINE.md` (frozen numbers),
  `classifier_{capture,battery,analyze}.R`, and `results/classifier_raw/` (saved
  per-step monitor data for free offline re-attribution).
- `tf24-event-aware-spec.md` — the event-integrator spec; **§4 retired by the gate**
  (verdict recorded inline in §3), §7 (mesh/`J`) still live. Reference, not a plan.
- plant#60 — reverse-mode gradient bug (E4, out of scope: reverse mode not in play);
  plant#61/#62 — filed prior session; odelia#47 — filed this session.

**Context, superseded by the gate**
- `oracle-consultation-event-aware{,-response}.md` — the round-7 design that
  proposed the event program; its own gate (build-#2) refuted its premise.
- `oracle-consultation-tf24-recharacterized{,-response}.md` — the round-6 verdict
  (block decomposition retired) + corrected system description. Still correct on
  the negative results; superseded on the event program.

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
